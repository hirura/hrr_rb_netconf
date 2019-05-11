# coding: utf-8
# vim: et ts=2 sw=2

require 'rexml/document'
require 'hrr_rb_netconf/logger'
require 'hrr_rb_netconf/server/capability'

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
        @capabilities = Array.new
        @local_capabilities = Capability.list
        @remote_capabilities = Array.new
      end

      def start
        exchange_hello
        negotiate_capabilities
        initialize_sender_and_receiver
      end

      def exchange_hello
        send_hello
        receive_hello
      end

      def send_hello
        @logger.info { "Local capabilities: #{@local_capabilities}" }
        xml_doc = REXML::Document.new
        hello_e = xml_doc.add_element 'hello'
        hello_e.add_namespace('urn:ietf:params:xml:ns:netconf:base:1.0')
        capabilities_e = hello_e.add_element 'capabilities'
        @local_capabilities.each{ |c|
          capability_e = capabilities_e.add_element 'capability'
          capability_e.text = c
        }
        session_id_e = hello_e.add_element 'session-id'
        session_id_e.text = @session_id.to_s

        buf = String.new
        formatter = REXML::Formatters::Pretty.new(2)
        formatter.compact = true
        formatter.write(xml_doc, buf)
        @logger.debug { "Sending hello message: #{buf.inspect}" }
        @io_w.write "#{buf}\n]]>]]>\n"
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

      def negotiate_capabilities
        (@local_capabilities & @remote_capabilities).each{ |c| @capabilities.push c }
        @logger.info { "Negotiated capabilities: #{@capabilities}" }
        unless @capabilities.any?{ |c| /^urn:ietf:params:netconf:base:\d+\.\d+$/ =~ c }
          @logger.error { "No base NETCONF capability negotiated" }
          raise  "No base NETCONF capability negotiated"
        end
      end

      def initialize_sender_and_receiver
        base_capability = @capabilities.select{ |c| /^urn:ietf:params:netconf:base:\d+\.\d+$/ =~ c }.sort.last
        @logger.info { "Base NETCONF capability: #{base_capability}" }
        @sender   = Capability[base_capability]::Sender.new   @io_w
        @receiver = Capability[base_capability]::Receiver.new @io_r
      end
    end
  end
end
