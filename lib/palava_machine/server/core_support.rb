module PalavaMachine
  class Server
    module CoreSupport
      def ws_open_announce(ws)
        manager.announce_connection(ws)
      end

      def ws_message_parse(ws, message)
        connection_id = manager.connections.get_connection_id(ws) or raise MessageError.new(ws), 'unknown connection'
        ClientMessage.new(message, connection_id)
      end

      def ws_message_action(ws, event)
        manager.debug "#{event.connection_id} <#{event.name}>"
        manager.public_send(event.name, event.connection_id, *event.arguments)
      end

      def ws_close_unannounce(ws)
        manager.unannounce_connection(ws)
      end

      def em_init_pm
        manager.info "Starting RTC Socket Server on port #{options[:port]}"
        manager.initialize_in_em
      end

      def send_error(ws, e)
        ws.send_text({
          event: 'error',
          message: e.message
        }.to_json) # TODO deactivate message in production?
      end

      def stop!(timeout = options[:shutdown_timeout])
        manager.warn "Stopping Machine"
        if timeout.to_i == 0
          manager.shutdown!
          EM.stop
        else
          EM.add_timer(0) do
            manager.announce_shutdown(timeout)
            manager.shutdown!(timeout)
            EM.stop
          end
        end
      end

    end
  end
end