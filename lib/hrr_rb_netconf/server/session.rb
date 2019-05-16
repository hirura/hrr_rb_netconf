# coding: utf-8
# vim: et ts=2 sw=2

require 'rexml/document'
require 'hrr_rb_netconf/logger'
require 'hrr_rb_netconf/server/capability'
require 'hrr_rb_netconf/server/filter'

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
        @closed = false
        @capabilities = Array.new
        @local_capabilities = Capability.list
        @remote_capabilities = Array.new
      end

      def start
        begin
          exchange_hello
          negotiate_capabilities
          initialize_sender_and_receiver
          operation_loop
        rescue
          raise
        ensure
          close
        end
      end

      def close
        @logger.info { "Being closed" }
        @closed = true
        @io_r.close
      end

      def closed?
        @closed
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

      def operation_loop
        loop do
          if closed?
            break
          end

          begin
            received_message = @receiver.receive_message
          rescue Error => e
            rpc_reply_e = REXML::Element.new("rpc-reply")
            rpc_reply_e.add_namespace("urn:ietf:params:xml:ns:netconf:base:1.0")
            rpc_reply_e.add e.to_rpc_error
            begin
              @sender.send_message rpc_reply_e
            rescue IOError
              break
            end
            next
          end

          if received_message.nil?
            break
          end

          message_id = received_message.attributes['message-id']
          unless message_id
            rpc_reply_e = received_message.clone
            rpc_reply_e.name = "rpc-reply"
            rpc_reply_e.add Error['missing-attribute'].new('rpc', 'error', info: {'bad-attribute' => 'message-id', 'bad-element' => 'rpc'}).to_rpc_error
            begin
              @sender.send_message rpc_reply_e
            rescue IOError
              break
            end
            next
          end

          begin
            input_e = received_message.elements[1]
            raw_output = @server.datastore_operation(input_e)
            case input_e.name
            when 'kill-session'
              @server.close_session Integer(input_e.elements['session-id'].text)
            end
            raw_output_e = case raw_output
                           when String
                             REXML::Document.new(raw_output, {:ignore_whitespace_nodes => :all}).root
                           when REXML::Document
                             raw_output.root
                           when REXML::Element
                             raw_output
                           else
                             raise "Unexpected output: #{raw_output.inspect}"
                           end
            output_e = Filter.filter(raw_output_e, input_e)
            rpc_reply_e = received_message.clone
            rpc_reply_e.name = "rpc-reply"
            rpc_reply_e.add output_e
            begin
              @sender.send_message rpc_reply_e
            rescue IOError
              break
            end
          rescue Error => e
            rpc_reply_e = received_message.clone
            rpc_reply_e.name = "rpc-reply"
            rpc_reply_e.add e.to_rpc_error
            begin
              @sender.send_message rpc_reply_e
            rescue IOError
              break
            end
          rescue => e
            @logger.error { e.message }
            raise
          ensure
            case input_e.name
            when 'close-session'
              break
            end
          end
        end
        @logger.info { "Exit operation_loop" }
      end
    end
  end
end
