# frozen_string_literal: true

module PalavaMachine
  VERSION          = "1.0.2"
  PROTOCOL_VERSION = "1.0.0"

  def self.protocol_identifier
    'palava.%s' % PROTOCOL_VERSION.to_f
  end
end
