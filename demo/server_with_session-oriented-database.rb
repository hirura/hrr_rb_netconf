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

class SessionOrientedDatabase
  class DatabaseSession
    def initialize db, session_id
      @db = db
      @session_id = session_id
    end

    def lock
      # Dummy method
    end

    def unlock
      # Dummy method
    end

    def close
      # Dummy method
    end

    def get
      @db.get
    end

    def get_config
      @db.get_config
    end

    def edit input_e
      @db.edit input_e
    end
  end

  def initialize
    @xml_doc = REXML::Document.new('<original />')
    @content = ''
  end

  def new_session session_id
    DatabaseSession.new self, session_id
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
logger.level = Logger::DEBUG


db = SessionOrientedDatabase.new

datastore = HrrRbNetconf::Server::Datastore.new(db, logger: logger){ |db, session, oper_handler|
  begin
    logger.debug { "begin DB session" }
    db_session = db.new_session session.session_id
    dummy_arg = 'dummy_arg'
    oper_handler.start db_session, dummy_arg
  ensure
    logger.debug { "close DB in ensure" }
    db_session.close rescue nil
  end
}
datastore.oper_proc('get'){ |db_session, dummy_arg, input_e|
  db_session.get
}
datastore.oper_proc('get-config'){ |db_session, dummy_arg, input_e|
  db_session.get_config
}
datastore.oper_proc('edit-config'){ |db_session, dummy_arg, input_e|
  config_e = input_e.elements['config'].elements[1]
  db_session.edit config_e
}
datastore.oper_proc('close-session'){ |db_session, dummy_arg, input_e|
  begin
    db_session.close
  rescue => e
    raise HrrRbNetconf::Server::Error['operation-failed'].new('application', 'error', message: e.message, logger: logger)
  end
}
datastore.oper_proc('lock'){ |db_session, dummy_arg, input_e|
  begin
    db_session.lock
  rescue => e
    raise HrrRbNetconf::Server::Error['resource-denied'].new('application', 'error', message: e.message, logger: logger)
  end
}
datastore.oper_proc('unlock'){ |db_session, dummy_arg, input_e|
  db_session.unlock rescue nil
}


server = TCPServer.new 10830
netconf_server = HrrRbNetconf::Server.new datastore, logger: logger
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
