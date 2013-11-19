require_relative 'version'
require_relative '../palava_machine'
require_relative 'client_message'

require_relative 'server/core_events'
require_relative 'server/core_support'
require_relative 'server/verify_handshake'
require_relative 'server/server_info'

require 'em-websocket'


module PalavaMachine
  class Server
    DEFAULT_FEATURES = [
      CoreSupport,
      CoreEvents,
#      VerifyHandshake,
      ServerInfo,
    ]

    attr_reader :manager, :features, :options

    def ws_open(ws, handshake)  end
    def ws_message(ws, message) end
    def ws_error(ws, error)     end
    def ws_close(ws, close)     end
    def em_init()               end
    def em_error(e)             end
    def em_sigterm()            end
    def em_sigint()             end

    def initialize(given_manager, given_options)
      include_features(given_options.delete(:features))
      @manager = given_manager
      @options = given_options
    end

    def run
      EM.run{
        em_init
        trap(:TERM){ em_sigterm }
        trap(:INT){ em_sigint }

        EM::WebSocket.run(options){ |ws|
          ws.onopen{ |handshake|  ws_open(ws, handshake) }
          ws.onmessage{ |message| ws_message(ws, message) }
          ws.onclose{ |why|       ws_close(ws, why) }
          ws.onerror{ |error|     ws_error(ws, error) }
          EM.error_handler{ |e|   em_error(e) }
        }
      }
    end


    private


    def include_features(given_features)
      @features = given_features || DEFAULT_FEATURES
      @features.each{ |f| self.singleton_class.send(:include, f) }
    end
  end
end
