# palava | machine [![[version]](https://badge.fury.io/rb/palava_machine.svg)](https://badge.fury.io/rb/palava_machine)  [![[travis]](https://travis-ci.org/palavatv/palava-machine.svg)](https://travis-ci.org/palavatv/palava-machine)

[palava.tv](https://palava.tv) is a cost-free, simple to use, secure, and open source platform for video calls, built on top of the [WebRTC](https://webrtc.org/) technology.

This repository contains an alternative implementation of the palava.tv signaling backend. There is an overview of all parts of palava.tv at [palavatv/palava](https://github.com/palavatv/palava).

## Descripiton

PalavaMachine is a WebRTC signaling server. Signaling describes the process of finding other peers and exchange information about how to establish a media connection. It works together with the [palava-client](https://github.com/palavatv/palava-client).

The server is implemented in [EventMachine](https://github.com/eventmachine/eventmachine/) and [Redis PubSub](https://redis.io/topics/pubsub) and communication to the clients is done via WebSockets.

**This application is currently not part of the palava.tv stack**

It was replaced by the Elixir-based [signaltower](https://github.com/palavatv/signaltower/), which uses the same protocol. Although this project is currently not actively worked on, it still functions as a drop-in replacement for the SignalTower and might also be developed further at some point.

## Installation & Usage

Make sure you have redis(https://redis.io/download) installed, then install the [palava_machine gem](https://rubygems.org/gems/palava_machine):

    $ gem install palava_machine

To start the server on port 4233, run:

    $ palava-machine

### Daemonized Version

The PalavaMachine can be started as a daemon process for production usage:

    $ palava-machine-daemon start

Stop it with

    $ palava-machine-daemon stop

### Configure using Environment Variables

You can set the address of the redis server via environment variable. The default is 'localhost:6379'.

    $ export PALAVA_REDIS="some_ip:some_port"
    $ bin/palava-machine

### Specs

To run the test suite use

    $ rspec

## Credits

AGPLv3. Part of the [palava project](https://palava.tv).

    Copyright (C) 2014-2020 palava e. V.  contact@palava.tv

    Copyright (C) 2013 Jan Lelis          hi@ruby.consulting
    Copyright (C) 2013 Marius Melzer      marius@rasumi.net
    Copyright (C) 2013 Stephan Thamm      stephan@innovailable.eu
    Copyright (C) 2013 Kilian Ulbrich     kilian@innovailable.eu

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
