module PalavaMachine
  class Server
    module CoreEvents
      def ws_open(ws, _)
        ws_open_announce(ws)
      rescue MessageError => e
        send_error(ws, e)
        ws.close 4242
      end

      def ws_message(ws, message)
        ws_message_action(ws, ws_message_parse(ws, message))
      rescue MessageParsingError, MessageError => e
        send_error(ws, e)
      end

      def ws_close(ws, why)
        ws_close_unannounce(ws)
      rescue MessageError => e
        warn "*** Error while closing connection *** #{e.class} ***\n" + (e.message || "") + "\n  " + e.backtrace*"\n  "
      end

      def ws_error(ws, e)
        warn "*** Socket Error *** #{e.class} ***\n" + (e.message || "") + "\n  " + (e.backtrace ? e.backtrace*"\n  " : "")
        ws.close 4242
      end

      def em_init
        em_init_pm
      end

      def em_error(e)
        if e.is_a? MessageError
          send_error(e.ws, e)
        else
          raise e
        end
      end

      def em_sigterm
        stop!
      end

      def em_sigint
        stop! 0
      end
    end
  end
end
