require_relative 'version'

require 'securerandom'

module PalavaMachine
  class SocketStore
    include Enumerable

    def initialize(connections = {})
      @connections = connections.dup
    end

    def register_connection(ws)
      @connections[ws] = SecureRandom.uuid
    end

    def unregister_connection(ws)
      @connections.delete(ws)
    end

    def get_connection_id(ws)
      @connections[ws]
    end

    def get_connection(id)
      @connections.key(id)
    end
    alias [] get_connection

    def each(&block)
      @connections.each(&block)
    end

    def sockets
      @connections.keys
    end

    def ids
      @connections.values
    end

    def dup
      SocketStore.new(@connections) # TODO verify (shallow)
    end
  end
end