# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/logger'
require 'hrr_rb_netconf/server/datastore/oper_handler'

module HrrRbNetconf
  class Server
    class Datastore
      def initialize database, &blk
        @logger = Logger.new self.class.name
        @database = database
        @oper_procs = Hash.new
        if blk
          @oper_handler = OperHandler.new
          @oper_thread = Fiber.new do |session|
            blk.call @database, session, @oper_handler if blk
          end
        end
      end

      def oper_proc oper_name, &oper_proc
        if oper_proc
          @oper_procs[oper_name] = oper_proc
          @logger.info { "Operation registered: #{oper_name}" }
        end
        @oper_procs[oper_name]
      end

      def start_session session
        if @oper_thread
          @oper_thread.resume(session)
        end
      end

      def close_session
        if @oper_thread
          while true
            begin
              @oper_thread.resume
            rescue FiberError
              break
            end
          end
        end
      end

      def run oper_name, input
        if @oper_thread
          @oper_handler.run @oper_procs[oper_name], input
        else
          @oper_procs[oper_name].call @database, input
        end
      end
    end
  end
end
