# PalavaMachine

[palava.tv](https://palava.tv) is simplistic video communication with your friends and colleagues from within your web browser. It is build on top of the [WebRTC](https://webrtc.org/) technology. No registration or browser plugin required.

Please see the [palava repository](https://github.com/palavatv/palava) for an overview of palava and report issues there.

PalavaMachine is a WebRTC signaling server. Signaling describes the process of finding other peers and exchange information about how to establish a media connection. It works together with the [palava-client](https://github.com/palavatv/palava-client).

The server is implemented in [EventMachine](http://rubyeventmachine.com/) and [Redis PubSub](http://redis.io/topics/pubsub) and communication to the clients is done via WebSockets. See it in action at [palava.tv.](https://palava.tv)

**This application is not part of the palava stack anymore.**

It was replaced by [SignalTower](https://github.com/farao/signaltower/), which is written in Elixir and uses the same protocol. Although this project is currently not actively worked on, it still functions as a drop-in replacement for the SignalTower and might also be developed further at some point.

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

AGPLv3. Part of the [palava project](https://palava.tv).

    Copyright (C) 2013 Jan Lelis          mail@janlelis.de
    Copyright (C) 2013 Marius Melzer      marius@rasumi.net
    Copyright (C) 2013 Stephan Thamm      stephan@innovailable.eu
    Copyright (C) 2013 Kilian Ulbrich     kilian@innovailable.eu
    Copyright (C) 2014 palava e. V.       contact@palava.tv

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public
    License along with this program. If not, see
    <http://www.gnu.org/licenses/>.
