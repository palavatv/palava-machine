require_relative 'version'
require_relative 'socket_store'

require 'em-hiredis'
require 'json'
require 'digest/sha2'
require 'time'
require 'logger'
require 'logger/colors'
require 'forwardable'


module PalavaMachine
  class Manager
    extend Forwardable


    attr_reader :connections


    def_delegators :@log, :debug, :info, :warn, :error, :fatal


    PAYLOAD_NEW_PEER = lambda { |connection_id, status = nil|
      payload = { event: 'new_peer', peer_id: connection_id }
      payload[:status] = status if status
      payload.to_json
    }

    PAYLOAD_PEER_LEFT = lambda { |connection_id| {
      event: 'peer_left',
      sender_id: connection_id,
    }.to_json }


    SCRIPT_JOIN_ROOM = <<-LUA
      local members = redis.call('smembers', KEYS[1])
      local count = 0
      for _, peer_id in pairs(members) do
        redis.call('publish', "ps:connection:" .. peer_id, ARGV[2])
        count = count + 1
      end
      redis.call('sadd', KEYS[1], ARGV[1])
      if count == 0 or tonumber(redis.call('get', KEYS[2])) <= count then
        redis.call('set', KEYS[2], count + 1)
      end
      redis.call('set', KEYS[3], ARGV[3])
      redis.call('set', KEYS[4], ARGV[4])
      return members
    LUA

    SCRIPT_LEAVE_ROOM = <<-LUA
      redis.call('hincrby', KEYS[7], math.floor((ARGV[3] - tonumber(redis.call('get', KEYS[3]))) / 60), 1) --stats
      redis.call('srem', KEYS[1], ARGV[1])
      redis.call('del', KEYS[3])
      redis.call('del', KEYS[4])
      redis.call('del', KEYS[5])

      if redis.call('scard', KEYS[1]) == 0 then -- also delete room if it is empty
        redis.call('hincrby', KEYS[6], redis.call('get', KEYS[2]), 1) --stats
        redis.call('del', KEYS[1])
        redis.call('del', KEYS[2])
      else -- tell others in room
        for _, peer_id in pairs(redis.call('smembers', KEYS[1])) do
          redis.call('publish', "ps:connection:" .. peer_id, ARGV[2])
        end
      end
    LUA


    def initialize(options = {})
      @redis_address = 'localhost:6379'
      @redis_db      = options[:db] || 0
      @connections   = SocketStore.new
      @log           = Logger.new(STDOUT)
      @log.level     = Logger::DEBUG
      @log.formatter = proc{ |level, datetime, _, msg|
        "#{datetime.strftime '%F %T'} | #{msg}\n"
      }
    end

    def initialize_in_em
      @redis      = EM::Hiredis.connect "redis://#{@redis_address}/#{@redis_db}"
      @publisher  = @redis.pubsub
      @subscriber = EM::Hiredis.connect("redis://#{@redis_address}/#{@redis_db}").pubsub # You need an extra connection for subs
      @redis.on :failed do
        @log.error 'Could not connect to Redis server'
      end
    end

    def announce_connection(ws)
      connection_id = @connections.register_connection(ws)
      info "#{connection_id} <open>"

      @subscriber.subscribe "ps:connection:#{connection_id}" do |payload|
        # debug "SUB payload #{payload} for <#{connection_id}>"
        ws.send_text(payload)
      end
    end

    def return_error(connection_id, message)
      raise MessageError.new(@connections[connection_id]), message
    end

    def unannounce_connection(ws, close_ws = false)
      if connection_id = @connections.unregister_connection(ws)
        info "#{connection_id} <close>"
        leave_room(connection_id)
        @subscriber.unsubscribe "ps:connection:#{connection_id}"
        if close_ws && ws.state != :closed # currently not used FIXME
          ws.close
        end
      end
    end

    def join_room(connection_id, room_id, status)
      return_error connection_id, 'no room id given' if !room_id || room_id.empty?
      return_error connection_id, 'room id too long' if room_id.size > 50

      @redis.get "store:connection:room:#{connection_id}" do |res|
        return_error connection_id, 'already joined another room' if res
        room_id = Digest::SHA512.hexdigest(room_id)
        info "#{connection_id} joins ##{room_id[0..10]}... #{status}"

        script_join_room(connection_id, room_id, status){ |members|
          return_error connection_id, 'room is full' unless members

          update_status_without_notifying_peers(connection_id, status){
            if members.empty?
              send_joined_room(connection_id, [])
            else
              get_statuses_for_members(members) do |members_with_statuses|
                send_joined_room(connection_id, members_with_statuses)
              end
            end
          }
        }
      end
    end

    def script_join_room(connection_id, room_id, status, &block)
      @redis.eval \
        SCRIPT_JOIN_ROOM,
        4,
        "store:room:members:#{room_id}",
        "store:room:peak_members:#{room_id}",
        "store:connection:joined:#{connection_id}",
        "store:connection:room:#{connection_id}",
        connection_id,
        PAYLOAD_NEW_PEER[connection_id, status],
        Time.now.getutc.to_i,
        room_id,
        &block
    end
    private :script_join_room

    def get_statuses_for_members(members)
      member_count = members.size
      members_with_statuses = []
      members.each { |peer_id|
        @redis.hgetall("store:connection:status:#{peer_id}") do |status_array|
          members_with_statuses << { peer_id: peer_id, status: Hash[status_array.each_slice(2).to_a] }
          yield members_with_statuses if members_with_statuses.size == member_count
        end
      }
    end
    private :get_statuses_for_members

    def send_joined_room(connection_id, members_with_statuses)
      @connections[connection_id].send_text({
        event: 'joined_room',
        own_id: connection_id,
        peers: members_with_statuses,
      }.to_json)
    end
    private :send_joined_room

    def leave_room(connection_id)
      @redis.get("store:connection:room:#{connection_id}") do |room_id|
        next unless room_id # return_error connection_id, 'currently not in any room'

        info "#{connection_id} leaves ##{room_id[0..10]}..."
        script_leave_room(connection_id, room_id)
      end
    end

    def script_leave_room(connection_id, room_id, &block)
      now = Time.now.getutc.to_i
      hour = now - now % (60 * 60)

      @redis.eval \
        SCRIPT_LEAVE_ROOM,
        7,
        "store:room:members:#{room_id}",
        "store:room:peak_members:#{room_id}",
        "store:connection:joined:#{connection_id}",
        "store:connection:room:#{connection_id}",
        "store:connection:status:#{connection_id}",
        "store:stats:room_peaks:#{hour}",
        "store:stats:connection_time:#{hour}",
        connection_id,
        PAYLOAD_PEER_LEFT[connection_id],
        now,
        &block
    end
    private :script_leave_room

    def update_status(connection_id, input_status)
      @redis.get("store:connection:room:#{connection_id}") do |room_id|
        return_error connection_id, 'currently not in any room' unless room_id

        update_status_without_notifying_peers(connection_id, input_status){
          @redis.smembers("store:room:members:#{room_id}") do |members|
            members.each { |peer_id|
              @publisher.publish "ps:connection:#{peer_id}", {
                event: 'peer_updated_status',
                status: input_status,
                sender_id: connection_id,
              }.to_json
            }
          end
        }
      end
    end

    def send_to_peer(connection_id, peer_id, data)
      unless data.instance_of? Hash
        return_error connection_id, "cannot send raw data"
      end

      @redis.get("store:connection:room:#{connection_id}") do |room_id|
        return_error connection_id, 'currently not in any room' unless room_id

        @redis.sismember("store:room:members:#{room_id}", peer_id) do |is_member|
          return_error connection_id, 'unknown peer' if is_member.nil? || is_member.zero?

          unless %w[offer answer ice_candidate].include? data['event']
            return_error connection_id, 'event not allowed'
          end

          @publisher.publish "ps:connection:#{peer_id}", (data || {}).merge("sender_id" => connection_id).to_json
        end
      end
    end

    def announce_shutdown(seconds = 0)
      warn "Announcing shutdown in #{seconds} seconds"
      @connections.sockets.each { |ws|
        ws.send_text({
          event: 'shutdown',
          seconds: seconds,
        }.to_json)
      }
    end

    def shutdown!(seconds = 0)
      sleep(seconds)
      @connections.dup.sockets.each{ |ws| ws.close(4200) } # TODO double check this one
    end


    private


    # TODO shorten
    def update_status_without_notifying_peers(connection_id, input_status, &block)
      if !input_status
        block.call
        return false
      end

      status = {}

      if input_status['name']
        if !input_status['name'] || input_status['name'] =~ /\A\s*\z/
          return_error connection_id, 'blank name not allowed'
        end

        if input_status['name'].size > 50
          return_error connection_id, 'name too long'
        end

        begin
          valid_encoding = input_status['name'] =~ /\A\p{ASCII}+\z/
        rescue Encoding::CompatibilityError
          valid_encoding = false
        end

        if !valid_encoding
          input_status['name'] = '*' * input_status['name'].size
        end

        status['name'] = input_status['name']
      end

      if input_status['user_agent']
        unless %w[firefox chrome unknown].include? input_status['user_agent']
          return_error connection_id, 'unknown user agent'
        end

        status['user_agent'] = input_status['user_agent']
      end

      unless status.empty?
        @redis.hmset "store:connection:status:#{connection_id}", *status.to_a.flatten, &block
        true
      end
    end

  end
end
