require_relative 'version'

require 'json'

module PalavaMachine
  class ClientMessage
    RULES = {
      info:          [],
      join_room:     [:room_id, :status],
      leave_room:    [],
      send_to_peer:  [:peer_id, :data],
      update_status: [:status],
    }

    def initialize(message, connection_id = nil)
      begin
        @_data = JSON.parse(message)
      rescue # TODO find exact json error to catch
        raise MessageParsingError, 'invalid message'
      end

      raise MessageParsingError, 'invalid message: not a hash' unless @_data.instance_of?(Hash)
      @connection_id = connection_id
    end

    def [](w)
      @_data[w]
    end

    def valid?
      RULES.keys.include?(name) or raise MessageParsingError, 'unknown event'
    end

    def name
      @name ||= @_data['event'] && @_data['event'].to_sym or raise(MessageParsingError, 'no event given')
    end

    def connection_id
      @connection_id or raise MessageParsingError, 'connection id used but not set'
    end

    def arguments
      valid? && RULES[name].map{ |data_key| @_data[data_key.to_s] }
    end
  end
end