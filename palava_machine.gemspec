# -*- encoding: utf-8 -*-
name = 'palava_machine'

require File.dirname(__FILE__) + "/lib/#{name}/version"

Gem::Specification.new do |s|
  s.required_ruby_version = '~> 2.1'
  s.name        = name
  s.version     = PalavaMachine::VERSION
  s.authors     = ["Jan Lelis", "Marius Melzer", "Stephan Thamm", "Kilian Ulbrich"]
  s.email       = "contact@palava.tv"
  s.homepage    = 'https://github.com/palavatv/palava-machine'
  s.license     = 'AGPL-3.0'
  s.summary     = "Implementation of the palava protocol for WebRTC signaling"
  s.description = "A WebRTC signaling server implemented with WebSockets, EventMachine and Redis Pub-Sub"
  s.files = Dir.glob(%w[{lib,test}/**/*.rb bin/* [A-Z]*.{txt,rdoc} ext/**/*.{rb,c} features/**/*]) + %w{Rakefile palava_machine.gemspec Gemfile}
  s.extra_rdoc_files = ["README.md", "ChangeLog.md", "ProtocolChangeLog.md", "LICENSE.txt"]
  s.executables = ['palava-machine', 'palava-machine-daemon']

  s.add_dependency 'eventmachine', '~> 1.2.7'
  s.add_dependency 'em-websocket', '~> 0.5.1'

  s.add_dependency 'hiredis', '~> 0.6.3'
  s.add_dependency 'em-hiredis', '~> 0.3.1'

  s.add_dependency 'redis', '~> 4.1.3'
  s.add_dependency 'resque'
  s.add_dependency 'resque-scheduler'
  s.add_dependency 'mongo'
  s.add_dependency 'bson_ext'

  s.add_dependency 'daemons', '~> 1.3.1'
  s.add_dependency 'logger-colors'
  s.add_dependency 'local_port'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
end

