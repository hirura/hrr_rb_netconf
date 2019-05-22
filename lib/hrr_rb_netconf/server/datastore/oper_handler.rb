# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/logger'

module HrrRbNetconf
  class Server
    class Datastore
      class OperHandler
        def initialize
          @logger = Logger.new self.class.name
        end

        def start *args
          @logger.info { "Starting OperHandler" }
          @logger.debug { "args: #{args.inspect}" }
          @args = args
          Fiber.yield
          @logger.info { "Exiting OperHandler" }
        end

        def run oper, input
          @logger.debug { "run with oper, input: #{oper.inspect}, #{input.inspect}" }
          oper.call(*(@args + [input]))
        end
      end
    end
  end
end
