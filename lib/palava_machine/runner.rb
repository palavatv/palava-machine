require_relative 'version'
require_relative 'manager'
require_relative 'server'

require 'local_port'


module PalavaMachine::Runner

  BANNER = <<BANNER

  ###    #     #       #    #   #    #
  #  #  # #    #      # #   #   #   # #
  ###  #   #   #     #   #   # #   #   #
  #    # # #   #     # # #   # #   # # #
  #   #     #  ###  #     #   #   #     #

BANNER

  CliOptions = Struct.new(
    :port,
    :db,
    :address,
    :shutdown_timeout,
    :redis_address,
    :mongo_address
  ) do
    def initialize(*argv)
      self.port             = (argv[0] || 4233).to_i
      self.db               = (argv[1] ||    0).to_i
      self.address          = argv[2]  || "0.0.0.0"
      self.shutdown_timeout = (argv[3] || 3).to_i
      self.redis_address    = argv[4]  || 'localhost:6379'
      self.mongo_address    = argv[5]  || 'localhost:27017'
    end
  end

  class << self
    def run(cli_options = {})
      puts BANNER

      PalavaMachine::Server.new(
        PalavaMachine::Manager.new(extract_manager_options(cli_options)),
        extract_server_options(cli_options),
      ).run
    end

    def parse_cli_options(argv = ARGV)
      CliOptions.new(*argv)
    end

    def extract_server_options(cli_options)
      {
        host: cli_options.address,
        port: LocalPort.next_free_one(cli_options.port),
        shutdown_timeout: cli_options.shutdown_timeout,
      }
    end

    def extract_manager_options(cli_options)
      {
        db: cli_options.db,
      }
    end
  end
end
