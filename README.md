# HrrRbNetconf

[![Build Status](https://travis-ci.org/hirura/hrr_rb_netconf.svg?branch=master)](https://travis-ci.org/hirura/hrr_rb_netconf)

hrr_rb_netconf is a pure Ruby NETCONF server implementation.

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Contributing](#contributing)
- [Code of Conduct](#code-of-conduct)
- [License](#license)

## Installation

TODO

## Usage

### Writing standard SSH server

#### Requiring `hrr_rb_netconf` library

First of all, `hrr_rb_netconf` library needs to be loaded.

```ruby
require 'hrr_rb_netconf'
```

#### Starting server application

A NETCONF server with hrr_rb_netconf can be started on an IO. In this example 10830 port is used as service port, and the connection is NOT encrypted. To run a NETCONF server on secure transport, it is required to use some library that provide secure transport like [hrr_rb_ssh](https://github.com/hirura/hrr_rb_ssh).

```ruby
datastore = HrrRbNetconf::Server::Datastore.new('dummy')
netconf_server = HrrRbNetconf::Server.new datastore
server = TCPServer.new 10830
loop do
  Thread.new(server.accept) do |io|
    begin
      netconf_server.start_session io
    ensure
      io.close
    end
  end
end
```

Where, the `datastore` variable is an instance of `HrrRbNetconf::Server::Datastore`.

#### Logging

The library provides logging functionality. To enable logging of the library, initialize `HrrRbNetconf::Logger` class.

```ruby
HrrRbNetconf::Logger.initialize logger
```

Where, the `logger` variable can be an instance of standard Logger class or user-defined logger class. What `HrrRbNetconf::Logger` class requires for `logger` variable is that the `logger` instance responds to `#fatal`, `#error`, `#warn`, `#info` and `#debug`.

For instance, `logger` variable can be prepared like below.

```ruby
logger = Logger.new STDOUT
logger.level = Logger::INFO
```

To disable logging, you can un-initialize `HrrRbNetconf::Logger`.

```ruby
HrrRbNetconf::Logger.uninitialize
```

#### Handling datastore operations

An NETCONF server provides a service with interacting datastore. When instantiating a HrrRbNetconf::Server, it takes an instance of HrrRbNetconf::Server::Datastore as an argument. It is possible datastore instance to have operation definitions.

```ruby
datastore = HrrRbNetconf::Server::Datastore.new('dummy')
datastore.oper_proc('get'){ |datastore, input_e|
  "<root>#{datastore}</root>"
}
```

When a NETCONF server receives "get" RPC operation, the datastore returns the above `"<root>#{datastore}</root>"` string, where `#{datastore}` will be `"dummy"` string that is passed at the instantiation of the datastore instance.

When to use a datastore that requires per-session access, the Datastore class can take a block that is called evetytime a session is started.

```ruby
datastore = HrrRbNetconf::Server::Datastore.new('dummy'){ |db, session, oper_handler|
  begin
    db_session = db.some_method_to_start_session
    oper_handler.start db_session, 'dummy1', 'dummy2'
  ensure
    db_session.some_method_to_close_db_session
  end
}
datastore.oper_proc('get'){ |db_session, dummy1, dummy2, input_e|
  "<root>#{db_session.some_method_to_get}</root>"
}
```

In this case, the first argument of `oper_proc('get')` block is db_session, the second is `'dummy2'`, and the last is RPC input.

### Demo

The `demo/server.rb` shows a good example on how to use the library.

## Supported Capabilities

The following capabilities are currently supported. (Actually, just sending the capabilities in `hello` for now.)

- urn:ietf:params:netconf:base:1.0
- urn:ietf:params:netconf:base:1.1
- urn:ietf:params:netconf:capability:candidate:1.0
- urn:ietf:params:netconf:capability:confirmed-commit:1.0
- urn:ietf:params:netconf:capability:confirmed-commit:1.1
- urn:ietf:params:netconf:capability:rollback-on-error:1.0
- urn:ietf:params:netconf:capability:startup:1.0
- urn:ietf:params:netconf:capability:validate:1.0
- urn:ietf:params:netconf:capability:validate:1.1
- urn:ietf:params:netconf:capability:writable-running:1.0
- urn:ietf:params:netconf:capability:xpath:1.0

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/hrr_rb_netconf. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the HrrRbNetconf project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/hirura/hrr_rb_netconf/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [Apache License 2.0](https://opensource.org/licenses/Apache-2.0).
