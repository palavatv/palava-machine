module PalavaMachine
  class Server
    module ServerInfo
      def ws_message_action(ws, event)
        if event.name == :info
          send_server_info(ws)
        else
          super(ws, event)
        end
      end

      def send_server_info(ws)
        ws.send_text({
          event: 'info',
          protocol_version: PalavaMachine::PROTOCOL_VERSION,
        }.to_json)
      end
    end
  end
end