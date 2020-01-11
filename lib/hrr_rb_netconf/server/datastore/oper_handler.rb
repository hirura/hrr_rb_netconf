# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/loggable'

module HrrRbNetconf
  class Server
    class Datastore
      class OperHandler
        include Loggable

        def initialize logger: nil
          self.logger = logger
        end

        def start *args
          log_info { "Starting OperHandler" }
          log_debug { "args: #{args.inspect}" }
          @args = args
          Fiber.yield
          log_info { "Exiting OperHandler" }
        end

        def run oper, input
          log_debug { "run with oper, input: #{oper.inspect}, #{input.inspect}" }
          oper.call(*(@args + [input]))
        end
      end
    end
  end
end
