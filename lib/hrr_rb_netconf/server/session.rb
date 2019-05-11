# coding: utf-8
# vim: et ts=2 sw=2

require 'rexml/document'
require 'hrr_rb_netconf/logger'

module HrrRbNetconf
  class Server
    class Session
      def initialize server, session_id, io
        @logger = Logger.new self.class.name
        @server = server
        @session_id = session_id
        @io_r, @io_w = case io
                       when IO
                         [io, io]
                       when Array
                         [io[0], io[1]]
                       else
                         raise ArgumentError, "io must be an instance of IO or Array"
                       end
        @remote_capabilities = Array.new
      end

      def start
        exchange_hello
      end

      def exchange_hello
        #send_hello
        receive_hello
      end

      def receive_hello
        buf = String.new
        loop do
          buf += @io_r.read(1)
          if buf[-6..-1] == ']]>]]>'
            break
          end
        end
        @logger.debug { "Received hello message: #{buf[0..-7].inspect}" }
        remote_capabilities_xml_doc = REXML::Document.new(buf[0..-7], {:ignore_whitespace_nodes => :all})
        remote_capabilities_xml_doc.each_element('/hello/capabilities/capability'){ |c| @remote_capabilities.push c.text }
        @logger.info { "Remote capabilities: #{@remote_capabilities}" }
      end
    end
  end
end
