# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/logger'

module HrrRbNetconf
  class Server
    class Session
      def initialize session_id, io
        @logger = Logger.new self.class.name
        @session_id = session_id
        @io_r, @io_w = case io
                       when IO
                         [io, io]
                       when Array
                         [io[0], io[1]]
                       else
                         raise ArgumentError, "io must be an instance of IO or Array"
                       end
      end

      def start
      end
    end
  end
end
