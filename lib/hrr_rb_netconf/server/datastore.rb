# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/loggable'
require 'hrr_rb_netconf/server/datastore/session'

module HrrRbNetconf
  class Server
    class Datastore
      include Loggable

      def initialize database, logger: nil, &blk
        self.logger = logger
        @database = database
        @oper_procs = Hash.new
        @session_proc = blk
      end

      def oper_proc oper_name, &oper_proc
        if oper_proc
          @oper_procs[oper_name] = oper_proc
          log_info { "Operation registered: #{oper_name}" }
        end
        @oper_procs[oper_name]
      end

      def new_session session
        Session.new @database, @oper_procs, @session_proc, session, logger: logger
      end
    end
  end
end
