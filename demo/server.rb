# coding: utf-8
# vim: et ts=2 sw=2

require 'socket'
require 'logger'

begin
  require 'hrr_rb_netconf'
rescue LoadError
  $:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
  require 'hrr_rb_netconf'
end


class MyLoggerFormatter < ::Logger::Formatter
  def call severity, time, progname, msg
    "%s, [%s#%d.%x] %5s -- %s: %s\n" % [severity[0..0], format_datetime(time), Process.pid, Thread.current.object_id, severity, progname, msg2str(msg)]
  end
end


logger = Logger.new STDOUT
logger.level = Logger::DEBUG
logger.formatter = MyLoggerFormatter.new

datastore = HrrRbNetconf::Server::Datastore.new('dummy', logger: logger){ |db, session, oper_handler|
  begin
    logger.debug { "begin DB session" }
    oper_handler.start db
  ensure
    logger.debug { "close DB in ensure" }
  end
}
datastore.oper_proc('get'){ |datastore, input_e|
  '<a xmlns="dummy"><b/></a>'
}
datastore.oper_proc('close-session'){ |datastore, input_e|
  '<ok/>'
}
datastore.oper_proc('kill-session'){ |datastore, input_e|
  '<ok/>'
}

netconf_server = HrrRbNetconf::Server.new datastore, logger: logger

server = TCPServer.new 10830
loop do
  Thread.new(server.accept) do |io|
    begin
      netconf_server.start_session io
    rescue => e
      logger.error { [e.backtrace[0], ": ", e.message, " (", e.class.to_s, ")\n\t", e.backtrace[1..-1].join("\n\t")].join }
    ensure
      begin
        io.close
      rescue => e
        logger.error { [e.backtrace[0], ": ", e.message, " (", e.class.to_s, ")\n\t", e.backtrace[1..-1].join("\n\t")].join }
      end
    end
  end
end
