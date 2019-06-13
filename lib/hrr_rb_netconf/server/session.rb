# coding: utf-8
# vim: et ts=2 sw=2

require 'thread'
require 'rexml/document'
require 'hrr_rb_relaxed_xml'
require 'hrr_rb_netconf/logger'
require 'hrr_rb_netconf/server/capability'
require 'hrr_rb_netconf/server/operation'

module HrrRbNetconf
  class Server
    class Session
      attr_reader :session_id

      def initialize server, capabilities, datastore, session_id, io, strict_capabilities
        @logger = Logger.new self.class.name
        @server = server
        @local_capabilities = capabilities
        @remote_capabilities = Array.new
        @datastore = datastore
        @session_id = session_id
        @io_r, @io_w = case io
                       when IO
                         [io, io]
                       when Array
                         [io[0], io[1]]
                       else
                         raise ArgumentError, "io must be an instance of IO or Array"
                       end
        @strict_capabilities = strict_capabilities
        @closed = false
        @notification_enabled = false
        @operation_mutex = Mutex.new
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
        begin
          @io_r.close_read
        rescue
        end
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
        @local_capabilities.list_loadable.each{ |c|
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
        @capabilities = @local_capabilities.negotiate @remote_capabilities
        @logger.info { "Negotiated capabilities: #{@capabilities.list_loadable}" }
        unless @capabilities.list_loadable.any?{ |c| /^urn:ietf:params:netconf:base:\d+\.\d+$/ =~ c }
          @logger.error { "No base NETCONF capability negotiated" }
          raise  "No base NETCONF capability negotiated"
        end
      end

      def initialize_sender_and_receiver
        base_capability = @capabilities.list_loadable.select{ |c| /^urn:ietf:params:netconf:base:\d+\.\d+$/ =~ c }.sort.last
        @logger.info { "Base NETCONF capability: #{base_capability}" }
        @sender   = Capability[base_capability]::Sender.new   @io_w
        @receiver = Capability[base_capability]::Receiver.new @io_r
      end

      def operation_loop
        datastore_session = @datastore.new_session self
        operation = Operation.new self, @capabilities, datastore_session, @strict_capabilities

        begin
          loop do
            break if closed?
            begin
              received_message = @receiver.receive_message
              break unless received_message
              @operation_mutex.lock
              rpc_reply_e = operation.run received_message
            rescue Error => e
              if received_message
                rpc_reply_e = received_message.clone
                rpc_reply_e.name = "rpc-reply"
              else
                rpc_reply_e = REXML::Element.new("rpc-reply")
                rpc_reply_e.add_namespace("urn:ietf:params:xml:ns:netconf:base:1.0")
              end
              rpc_reply_e.add e.to_rpc_error
            rescue => e
              @logger.error { e.message }
              raise
            ensure
              begin
                if rpc_reply_e
                  begin
                    @sender.send_message rpc_reply_e
                  rescue IOError
                    break
                  end
                end
              ensure
                @operation_mutex.unlock if @operation_mutex.locked?
              end
            end
          end
        ensure
          datastore_session.close rescue nil
          @io_w.close_write rescue nil
        end
        @logger.info { "Exit operation_loop" }
      end

      def close_other session_id
        @server.close_session session_id
      end

      def lock target
        @server.lock target, @session_id
      end

      def unlock target
        @server.unlock target, @session_id
      end

      def create_subscription #startTime, stopTime
        @notification_enabled = true
      end

      def terminate_subscription
        @notification_enabled = false
      end

      def notification_enabled?
        @notification_enabled
      end

      def send_notification event_xml
        @operation_mutex.synchronize do
          #event_e = filter(event_xml)
          event_e = event_xml
          notif_e = REXML::Element.new("notification")
          notif_e.add_namespace("urn:ietf:params:xml:ns:netconf:notification:1.0")
          event_e.elements.each{ |e|
            notif_e.add e
          }
          begin
            @sender.send_message notif_e
          rescue IOError => e
            @logger.warn { "Failed sending notification: #{e.message}" }
          end
        end
      end

      def notification_replay events
        Thread.new do
          events.each{ |arg1, arg2|
            if arg2
              event_time_e = begin
                               case arg1
                               when REXML::Element
                                 event_time = DateTime.rfc3339(arg1.txt).rfc3339
                               else
                                 event_time = DateTime.rfc3339(arg1).rfc3339
                               end
                               e = REXML::Element.new('eventTime')
                               e.text = event_time
                               e
                             end
              event_e = case arg2
                        when REXML::Document
                          arg2.root.deep_clone
                        when REXML::Element
                          arg2.deep_clone
                        else
                          REXML::Document.new(arg2, {:ignore_whitespace_nodes => :all}).root
                        end
              event_xml = HrrRbRelaxedXML::Document.new
              event_xml.add event_time_e
              event_xml.add event_e
            else
              event_xml = case arg1
                          when HrrRbRelaxedXML::Document
                            arg1
                          else
                            HrrRbRelaxedXML::Document.new(arg2, {:ignore_whitespace_nodes => :all})
                          end
              event_time = event_xml.elements['eventTime'].text
              event_xml.elements['eventTime'].text = DateTime.rfc3339(event_time).rfc3339
            end
            send_notification event_xml
          }
        end
      end
    end
  end
end
