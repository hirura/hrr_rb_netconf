# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/server/error'

module HrrRbNetconf
  class Server
    class Errors < StandardError
      include Enumerable

      def initialize *errors
        @errors = errors.flatten
        validate_errors
      end

      def validate_errors
        unless @errors.all?{ |e| e.kind_of? HrrRbNetconf::Server::Error }
          given = @errors.reject{ |e| e.kind_of? HrrRbNetconf::Server::Error }.map{ |e| e.class }
          raise ArgumentError.new "Wrong argument type: given #{given}, expected HrrRbNetconf::Server::Error"
        end
      end

      def each &blk
        @errors.each &blk
      end
    end
  end
end
