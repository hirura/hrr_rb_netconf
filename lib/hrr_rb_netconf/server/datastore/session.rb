# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/logger'
require 'hrr_rb_netconf/server/datastore/oper_handler'

module HrrRbNetconf
  class Server
    class Datastore
      class Session
        def initialize database, oper_procs, session_proc, session
          @logger = Logger.new self.class.name
          @database = database
          @oper_procs = oper_procs
          @session_proc = session_proc
          @session = session

          if @session_proc
            @oper_handler = OperHandler.new
            @oper_thread = Fiber.new do |session|
              @session_proc.call @database, session, @oper_handler
            end
            @oper_thread.resume(session)
          end
        end

        def close
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
          unless @oper_procs.has_key? oper_name
            raise Error['operation-not-supported'].new('protocol', 'error')
          end
          if @oper_thread
            @oper_handler.run @oper_procs[oper_name], input
          else
            @oper_procs[oper_name].call @database, input
          end
        end
      end
    end
  end
end
