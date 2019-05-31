# coding: utf-8
# vim: et ts=2 sw=2

require 'socket'
require 'logger'
require 'rexml/document'

begin
  require 'hrr_rb_netconf'
rescue LoadError
  $:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
  require 'hrr_rb_netconf'
end

class SessionlessDatabase
  def initialize
    @xml_doc = REXML::Document.new('<original />')
    @content = ''
  end

  def get
    @xml_doc.root.deep_clone
  end

  def get_config
    @xml_doc.root.deep_clone
  end

  def edit input_e
    @xml_doc = REXML::Document.new
    @xml_doc.add input_e
  end
end


logger = Logger.new STDOUT
logger.level = Logger::INFO
logger.level = Logger::DEBUG
HrrRbNetconf::Logger.initialize logger


db = SessionlessDatabase.new

datastore = HrrRbNetconf::Server::Datastore.new(db)
datastore.oper_proc('get'){ |db, input_e|
  db.get
}
datastore.oper_proc('get-config'){ |db, input_e|
  db.get_config
}
datastore.oper_proc('edit-config'){ |db, input_e|
  config_e = input_e.elements['config'].elements[1]
  db.edit config_e
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


server = TCPServer.new 10830
netconf_server = HrrRbNetconf::Server.new datastore
loop do
  Thread.new(server.accept) do |io|
    begin
      netconf_server.start_session io
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
