# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/logger'

module HrrRbNetconf
  class Server
    class Datastore
      def initialize datastore
        @logger = Logger.new self.class.name
        @datastore = datastore
        @operation_procs = Hash.new
      end

      def operation_proc oper_name, &oper_proc
        if oper_proc
          @operation_procs[oper_name] = oper_proc
          @logger.info { "Operation registered: #{oper_name}" }
        end
        @operation_procs[oper_name]
      end
    end
  end
end
