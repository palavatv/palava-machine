module PalavaMachine
  VERSION          = "1.0.1"
  PROTOCOL_VERSION = "1.0.0"

  def self.protocol_identifier
    'palava.%s' % PROTOCOL_VERSION.to_f
  end
end
