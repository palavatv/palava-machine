module PalavaMachine
  class Server
    class HandshakeError < StandardError; end

    module VerifyHandshake
      def ws_open(ws, handshake)
        verify_handshake(handshake)
        super(ws, handshake)
      rescue HandshakeError => e
        manager.error "HandshakeError for #{ws.hash}\n#{e.inspect}"
        send_error(ws, e)
        ws.close 4242
      end

      def verify_handshake(handshake)
        # Other: Access properties on the EM::WebSocket::Handshake object, e.g. path, query_string, origin, headers
        if handshake.headers['Sec-WebSocket-Protocol'] != PalavaMachine.protocol_identifier
          raise HandshakeError, "incompatible sub-protocol: #{ handshake.headers['Sec-WebSocket-Protocol'] }"
        end
      end
    end
  end
end