# encoding: utf-8

require 'fileutils'
require 'redis'
require 'json'

require_relative 'vendor/web_socket' # TODO this lib is not compat with Ruby 2.0

describe 'uvc-server-rtc' do
  SPEC_PROTOCOL_VERSION = '1.0.0'
  BASE_DIR         = File.dirname(__FILE__) + '/../'
  REDIS_DB         = 7
  UUID             = /\A\w{8}-\w{4}-\w{4}-\w{4}-\w{12}\z/
  SERVER_PROCESSES = []

  def create_socket_server(port, shutdown_timeout = 0)
    ruby_pid = fork do
      FileUtils.cd(BASE_DIR)
      puts        "bin/palava-machine #{port} #{REDIS_DB} 127.0.0.1 #{shutdown_timeout}"
      pid = spawn "bin/palava-machine #{port} #{REDIS_DB} 127.0.0.1 #{shutdown_timeout}"
      trap(:TERM){ Process.kill(:TERM, pid) }
      Process.waitpid(pid)
    end
    SERVER_PROCESSES << ruby_pid
    sleep 1.2
    ruby_pid
  end

  after :all do
    SERVER_PROCESSES.each{ |pid| Process.kill(:TERM, pid) }
  end

  class Client
    def initialize(port = 4233, sub_protocol = "palava.#{SPEC_PROTOCOL_VERSION.to_f}")
      @socket   =  WebSocket.new("ws://127.0.0.1:#{port}", sub_protocol: sub_protocol)
      @received = []
      receive!
    end

    def receive!
      Thread.new do
        while data = @socket.receive
          @received << data
        end
      end
    end

    def send_raw_message(message)
      @socket.send(message)
    end

    def send_message(message)
      send_raw_message(JSON.dump(message))
    end

    def received_messages(sleep_for = 0.1)
      sleep sleep_for
      @received
    end

    def last_json_message(sleep_for = 0.01)
      sleep sleep_for
      raise "no messages received, yet (try increasing sleep time)" if @received.empty?
      JSON.parse @received.last
    end
  end

  before :all do
    create_socket_server(4233)
  end

  let(:client1){   Client.new(4233) }
  let(:client2){   Client.new(4233) }
  let(:client3){   Client.new(4233) }
  let(:client4){   Client.new(4233) }

  before do
    @redis = Redis.new db: REDIS_DB
    @redis.flushdb
  end

  describe 'handshake' do
    it 'will return error if no protocol given' do
      c = Client.new(4233, nil)
      c.send_message(event: 'info')
      c.last_json_message.should == {
        "event"   => "error",
        "message" => "incompatible sub-protocol: ",
      }
    end

    it 'will return error if prefix is not "palava."' do
      c = Client.new(4233, "palaba.#{SPEC_PROTOCOL_VERSION.to_f}")
      c.send_message(event: 'info')
      c.last_json_message.should == {
        "event"   => "error",
        "message" => "incompatible sub-protocol: palaba.#{SPEC_PROTOCOL_VERSION.to_f}",
      }
    end

    it 'will return error if wrong minor version given' do
      c = Client.new(4233, 'palava.0.0')
      c.send_message(event: 'info')
      c.last_json_message.should == {
        "event"   => "error",
        "message" => "incompatible sub-protocol: palava.0.0",
      }
    end
  end

  describe 'server info' do
    it 'returns information event' do
      client1.send_message(event: 'info')
      client1.last_json_message['event'].should == "info"
    end

    it 'shows the current protocol version' do
      client1.send_message(event: 'info')
      client1.last_json_message['protocol_version'].should == SPEC_PROTOCOL_VERSION
    end
  end

  describe 'join_room' do
    context 'valid' do
      it 'sends event "joined_room" to new peer' do
        client1.send_message(
          event: 'join_room',
          room_id: 'test_room',
        )

        client1.last_json_message["event"].should == 'joined_room'
      end

      it 'joined_room: contains own_id uuid' do
        client1.send_message( event: 'join_room', room_id: 'test_room' )
        client1.last_json_message["own_id"].should =~ UUID
      end

      it 'joined_room: contains other peers in room with statuses' do
        client1.send_message(event: 'join_room', room_id: 'test_room')
        client1_id  = client1.last_json_message['own_id']
        client1.last_json_message(0)["peers"].should == []
        client1.send_message(event: 'update_status', status: { name: 'max' })

        client2.send_message(event: 'join_room', room_id: 'test_room')
        client2_id = client2.last_json_message['own_id']
        client2.last_json_message(0)["peers"].should == [
          { "peer_id" => client1_id, "status" => { "name" => "max" } },
        ]

        client3.send_message(event: 'join_room', room_id: 'test_room')
        client3.last_json_message["peers"].map(&:to_a).sort.should == [
          { "peer_id" => client1_id, "status" => { "name" => "max" } },
          { "peer_id" => client2_id, "status" => {} },
        ].map(&:to_a).sort
      end

      it 'sends event "new_peer" to every other peer containing the peer id of the new peer' do
        client1.send_message(event: 'join_room', room_id: 'test_room')
        client1_id  = client1.last_json_message['own_id']

        client2.send_message(event: 'join_room', room_id: 'test_room')
        client2_id = client2.last_json_message['own_id']
        client1.last_json_message.should == { "event" => "new_peer", "peer_id" => client2_id }

        client3.send_message(event: 'join_room', room_id: 'test_room')
        client3_id = client3.last_json_message['own_id']
        client1.last_json_message.should == { "event" => "new_peer", "peer_id" => client3_id }
        client2.last_json_message.should == { "event" => "new_peer", "peer_id" => client3_id }
      end

      it "sends 'new peer' which contains the peers' status if given" do
        client1.send_message(event: 'join_room', room_id: 'test_room')
        client1_id  = client1.last_json_message['own_id']

        client2.send_message(event: 'join_room', room_id: 'test_room', status: { name: 'Manfred', user_agent: 'firefox' })
        client2_id = client2.last_json_message['own_id']
        client1.last_json_message.should == { "event" => "new_peer", "peer_id" => client2_id, "status" => { "name" => "Manfred", "user_agent" => "firefox" } }
      end

      it 'is not possible to join two rooms at the same time' do
        client1.send_message(event: 'join_room', room_id: 'test_room')
        client1.send_message(event: 'join_room', room_id: 'test_room2')
        client1_id  = client1.last_json_message.should == {
          "event" => "error",
          "message" => 'already joined another room',
        }
      end

      it 'works across multiple web socket servers' do
        create_socket_server(4234)
        client_from_other_server = Client.new(4234)

        client1.send_message(event: 'join_room', room_id: 'test_room')
        client1_id  = client1.last_json_message['own_id']

        client_from_other_server.send_message(event: 'join_room', room_id: 'test_room')
        client_from_other_server_id = client_from_other_server.last_json_message['own_id']

        client_from_other_server.last_json_message['event'].should == "joined_room"
        client1.last_json_message['event'].should   == "new_peer"
        client1.last_json_message['peer_id'].should == client_from_other_server_id
      end
    end

    context 'invalid' do
      it 'needs a room_id' do
        client1.send_message(
          event: 'join_room',
        )

        client1.last_json_message.should == {
          "event"   => "error",
          "message" => "no room id given",
        }
      end

      it 'room_id must be less than 51 chars' do
        client1.send_message(
          event: 'join_room',
          room_id: "c"*51,
        )

        client1.last_json_message.should == {
          "event"   => "error",
          "message" => "room id too long",
        }
      end
    end
  end

  describe 'leave_room' do
    it 'sends event "peer_left" to other peers including the peer_id of the left peer' do
      client1.send_message(event: 'join_room', room_id: 'test_room')
      client1_id = client1.last_json_message['own_id']
      client2.send_message(event: 'join_room', room_id: 'test_room')
      client2_id = client2.last_json_message['own_id']
      client3.send_message(event: 'join_room', room_id: 'test_room')
      client3_id = client3.last_json_message['own_id']

      client2.send_message(event: 'leave_room')
      client1.last_json_message.should == { "event" =>  "peer_left", "sender_id" => client2_id }
      client3.last_json_message.should == { "event" =>  "peer_left", "sender_id" => client2_id }

      client1.send_message(event: 'leave_room')
      client3.last_json_message.should == { "event" =>  "peer_left", "sender_id" => client1_id }
    end

    it 'connections do not leave traces after being closed' do
      client1.send_message(event: 'join_room', room_id: 'test_room')
      client1.send_message(event: 'leave_room', room_id: 'test_room')
      client1.last_json_message

      @redis.keys('store:connection:room:*').should == []
    end

    it 'rooms do not leave traces after being deserted' do
      client1.send_message(event: 'join_room', room_id: 'test_room')
      client1.send_message(event: 'leave_room', room_id: 'test_room')
      client1.last_json_message

      @redis.keys('store:room:*').should == []
    end

    # CURRENTLY IGNORED BY DESIGN
    # it 'returns an error if currently not in any room' do
    #   client1.send_message(event: 'leave_room')
    #   client1.last_json_message.should == { "event" => "error", "message" => "currently not in any room" }
    # end
  end

  describe 'update status' do
    it 'sends "peer_updated_status message to all peers in room' do
      client1.send_message(event: 'join_room', room_id: 'test_room')
      client1_id = client1.last_json_message['own_id']
      client2.send_message(event: 'join_room', room_id: 'test_room')
      client2_id = client2.last_json_message['own_id']
      client1.send_message(event: 'update_status', status: { name: 'John Doe' })

      peer_updated_status_message = {
        'event' => 'peer_updated_status',
        'status' => {'name' => 'John Doe'},
        'sender_id' => client1_id
      }
      client1.last_json_message.should == peer_updated_status_message
      client2.last_json_message.should == peer_updated_status_message
    end

    it 'does not accept statusses with blank names' do
      client1.send_message(event: 'join_room', room_id: 'test_room')

      client1.send_message(event: 'update_status', status: { name: '' })
      client1.last_json_message.should == { "event" => "error", "message" => "blank name not allowed" }

      client1.send_message(event: 'update_status', status: { name: '    ' })
      client1.last_json_message.should == { "event" => "error", "message" => "blank name not allowed" }
    end

    it 'does not choke on empty status, ignores it' do # TODO really ignore
      client1.send_message(event: 'join_room', room_id: 'test_room')

      client1.send_message(event: 'update_status', status: {})
      client1.last_json_message['event'].should_not == "error"
    end

    it 'does not accept statusses with names > 50' do
      client1.send_message(event: 'join_room', room_id: 'test_room')

      client1.send_message(event: 'update_status', status: { name: '123456789012345678901234567890123456789012345678901' })
      client1.last_json_message.should == { "event" => "error", "message" => "name too long" }
    end

    it '"sanitizes" non-ascii names' do
      client1.send_message(event: 'join_room', room_id: 'test_room')

      client1.send_message(event: 'update_status', status: { name: '✈✈' })
      client1.last_json_message['status'].should == {'name' => '**'}
    end

    context 'user agent' do
      it 'accepts "firefox" as value' do
        client1.send_message(event: 'join_room', room_id: 'test_room')

        client1.send_message(event: 'update_status', status: { name: '123', user_agent: 'firefox' })
        client1.last_json_message['status']['user_agent'].should == 'firefox'
      end

      it 'does not accept non-whitelisted strings' do
        client1.send_message(event: 'join_room', room_id: 'test_room')

        client1.send_message(event: 'update_status', status: { name: '123', user_agent: 'firedonkey' })
        client1.last_json_message.should == { "event" => "error", "message" => "unknown user agent" }
      end
    end
  end

  describe 'statistics' do
    it 'statistics about one room and one user work' do
      client1.send_message(event: 'join_room', room_id: 'test_room')
      client1.send_message(event: 'leave_room', room_id: 'test_room')
      client1.last_json_message

      keys = @redis.keys('store:stats:room_peaks:*')
      keys.should_not == []

      peaks = @redis.hgetall keys[0]
      peaks.should == { "1" => "1" }
    end

    it 'statistics about one room should work after a user left and another one joins' do
      client1.send_message(event: 'join_room', room_id: 'test_room')
      client2.send_message(event: 'join_room', room_id: 'test_room')
      client2.send_message(event: 'leave_room', room_id: 'test_room')
      client3.send_message(event: 'join_room', room_id: 'test_room')
      client3.send_message(event: 'leave_room', room_id: 'test_room')
      client1.send_message(event: 'leave_room', room_id: 'test_room')
      client1.last_json_message(1)

      keys = @redis.keys('store:stats:room_peaks:*')
      keys.should_not == []

      peaks = @redis.hgetall keys[0]
      peaks.should == { "2" => "1" }
    end

    it 'statistics work for multiple rooms' do
      client1.send_message(event: 'join_room', room_id: 'test_room')
      client1.send_message(event: 'leave_room', room_id: 'test_room')

      client2.send_message(event: 'join_room', room_id: 'test_room')
      client2.send_message(event: 'leave_room', room_id: 'test_room')

      client3.send_message(event: 'join_room', room_id: 'test_room')
      client4.send_message(event: 'join_room', room_id: 'test_room')
      client4.send_message(event: 'leave_room', room_id: 'test_room')
      client3.send_message(event: 'leave_room', room_id: 'test_room')

      client1.last_json_message(1)
      client2.last_json_message(1)
      client3.last_json_message(1)

      keys = @redis.keys('store:stats:room_peaks:*')
      keys.should_not == []

      peaks = @redis.hgetall keys[0]
      peaks.should == { "1" => "2", "2" => "1" }
    end

    # unable to simulate time with timecop because rtc server is in another ruby instance

    it 'connection time works with one client' do
      client1.send_message(event: 'join_room', room_id: 'test_room')
      client1.send_message(event: 'leave_room', room_id: 'test_room')
      client1.last_json_message

      keys = @redis.keys('store:stats:connection_time:*')
      keys.should_not == []

      peaks = @redis.hgetall keys[0]
      peaks.should == { "0" => "1" }
    end

    it 'connection time works with two clients' do
      client1.send_message(event: 'join_room', room_id: 'test_room')
      client2.send_message(event: 'join_room', room_id: 'test_room')
      client2.send_message(event: 'leave_room', room_id: 'test_room')
      client1.send_message(event: 'leave_room', room_id: 'test_room')
      client1.last_json_message(1)

      keys = @redis.keys('store:stats:connection_time:*')
      keys.should_not == []

      peaks = @redis.hgetall keys[0]
      peaks.should == { "0" => "2" }
    end
  end

  describe 'send_to_peer' do
    it 'sends payload to other peer and includes sender_id' do
      client1.send_message(event: 'join_room', room_id: 'test_room')
      client1_id = client1.last_json_message['own_id']
      client2.send_message(event: 'join_room', room_id: 'test_room')
      client2_id = client2.last_json_message['own_id']

      payload = { "event" => "offer" }
      client1.send_message(event: 'send_to_peer', peer_id: client2_id, data: payload)
      client2.last_json_message.should == payload.merge("sender_id" => client1_id)
    end

    it 'does not send payload if peer is not in same room and returns error' do
      client1.send_message(event: 'join_room', room_id: 'test_room')
      client1_id = client1.last_json_message(0.5)['own_id']
      client2.send_message(event: 'join_room', room_id: 'other_room')
      client2_id = client2.last_json_message(0.5)['own_id']

      payload = { "event" => "offer" }
      client1.send_message(event: 'send_to_peer', peer_id: client2_id, data: payload)
      client2.last_json_message(0.5)['event'].should_not == "payload"
      client1.last_json_message.should == { "event" => "error", "message" => "unknown peer" }
    end

    it 'does not send payload if event is unknown' do
      client1.send_message(event: 'join_room', room_id: 'test_room')
      client1_id = client1.last_json_message['own_id']
      client2.send_message(event: 'join_room', room_id: 'test_room')
      client2_id = client2.last_json_message['own_id']

      expect{
        payload = { "event" => "unknown" }
        client1.send_message(event: 'send_to_peer', peer_id: client2_id, data: payload)
        client1.last_json_message.should == { "event" => "error", "message" => "event not allowed" }

        payload = { "event" => "eile" }
        client1.send_message(event: 'send_to_peer', peer_id: client2_id, data: payload)
        client1.last_json_message.should == { "event" => "error", "message" => "event not allowed" }

        payload = { }
        client1.send_message(event: 'send_to_peer', peer_id: client2_id, data: payload)
        client1.last_json_message.should == { "event" => "error", "message" => "event not allowed" }

        payload = "raw"
        client1.send_message(event: 'send_to_peer', peer_id: client2_id, data: payload)
        client1.last_json_message(0.2).should == { "event" => "error", "message" => "cannot send raw data" }
     }.to_not change{ client2.received_messages.size }
    end

    it 'returns error if not in any room' do
      payload = { "event" => "offer" }
      client1.send_message(event: 'send_to_peer', peer_id: "50fa50ab-116c-4f83-b0a8-10f267aeab1b", data: payload)
      client1.last_json_message(0.1).should == { "event" => "error", "message" => "currently not in any room" }
    end
  end

  describe 'shutdown' do
    it 'sends a shutdown message to all connected peers' do
      pid = create_socket_server(4235, seconds = 1)
      client1 = Client.new(4235)
      client2 = Client.new(4235)
      Process.kill :TERM, pid
      client1.last_json_message.should == {
        "event" => "shutdown",
        "seconds" => seconds,
      }
      client1.last_json_message.should == client2.last_json_message
    end
  end

  describe 'general invalid message' do
    it 'returns an error for non-json' do
      client1.send_raw_message "<iaeiae"

      client1.last_json_message.should == {
        "event"   => "error",
        "message" => "invalid message",
      }
    end

    it 'returns an error for unknown events' do
      client1.send_message(
        event: 'unknown123',
      )

      client1.last_json_message(0.2).should == {
        "event"   => "error",
        "message" => "unknown event",
      }
    end
  end
end
