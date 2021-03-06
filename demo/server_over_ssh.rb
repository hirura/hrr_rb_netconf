# coding: utf-8
# vim: et ts=2 sw=2

require 'socket'
require 'logger'
require 'rexml/document'

begin
  require 'hrr_rb_ssh'
rescue LoadError
  STDERR.puts "Faild require 'hrr_rb_ssh' gem. Please install it with 'gem install hrr_rb_ssh'."
  exit(1)
end

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


db = '<root />'

datastore = HrrRbNetconf::Server::Datastore.new(db, logger: logger)
datastore.oper_proc('get'){ |db, input_e|
  db
}
datastore.oper_proc('get-config'){ |db, input_e|
  db
}
datastore.oper_proc('edit-config'){ |db, input_e|
  config_e = input_e.elements['config'].elements[1].to_s
  db = config_e
}
datastore.oper_proc('close-session'){ |db, input_e|
  # pass
}
datastore.oper_proc('lock'){ |db, input_e|
  # pass
}
datastore.oper_proc('unlock'){ |db, input_e|
  # pass
}

netconf_server = HrrRbNetconf::Server.new datastore, logger: logger


auth_password = HrrRbSsh::Authentication::Authenticator.new { |context|
  true # accept any user and password
}
conn_subsys = HrrRbSsh::Connection::RequestHandler.new { |context|
  context.chain_proc { |chain|
    case context.subsystem_name
    when 'netconf'
      begin
        netconf_server.start_session context.io
        exitstatus = 0
      rescue => e
        logger.error([e.backtrace[0], ": ", e.message, " (", e.class.to_s, ")\n\t", e.backtrace[1..-1].join("\n\t")].join)
        exitstatus = 1
      end
    else
      exitstatus = 0
    end
    exitstatus
  }
}

options = {}
options['authentication_password_authenticator'] = auth_password
options['connection_channel_request_subsystem']  = conn_subsys



server = TCPServer.new 10830
loop do
  Thread.new(server.accept) do |io|
    begin
      ssh_server = HrrRbSsh::Server.new options
      ssh_server.start io
    rescue => e
      logger.error { [e.backtrace[0], ": ", e.message, " (", e.class.to_s, ")\n\t", e.backtrace[1..-1].join("\n\t")].join }
    ensure
      begin
        io.close
      rescue
      end
    end
  end
end
