# PalavaMachine

## Description

PalavaMachine is a WebRTC signaling server. Signaling describes the process of finding other peers and exchange information about how to establish a media connection.

The server is implemented in [EventMachine](http://rubyeventmachine.com/) and [Redis PubSub](http://redis.io/topics/pubsub) and communication to the clients is done via WebSockets. See it in action at [palava.tv.](https://palava.tv)

## What can I do with it?

*This is a pre-release for interested Ruby/JS/WebRTC developers*. If you are unsure, what to use this gem for, you'll just need to wait. We'll soon put a more detailed instructions on our [blog](https://blog.palava.tv).

## Installation & Usage

Make sure you have redis(http://redis.io/download) installed, then clone this repository and run

  $ bundle install

Start the server with

  $ bin/palava-machine

Alternatively, download the [palava_machine gem](http://rubygems.org/gems/palava_machine) from rubygems.org:

  $ gem install palava_machine

And run:

  $ palava-machine

### Deamonized Version

The PalavaMachine can be started as a daemon process for production usage:

  $ palava-machine-daemon start

Stop it with

  $ palava-machine-daemon stop

### Specs

To run the test suite use

  $ rspec

## Credits

Open Source License information following soon!

(c) 2013 Jan Lelis,      jan@signaling.io
(c) 2013 Marius Melzer,  marius@signaling.io
(c) 2013 Stephan Thamm,  thammi@chaossource.net
(c) 2013 Kilian Ulbrich, kilian@innovailable.eu

Part of the [palava project](https://blog.palava.tv)
