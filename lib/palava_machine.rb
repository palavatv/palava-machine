require_relative 'palava_machine/version' unless defined? PalavaMachine::VERSION

module PalavaMachine
  class MessageParsingError < StandardError; end

  class MessageError < StandardError
    attr_reader :ws

    def initialize(ws)
      @ws = ws
    end
  end
end
