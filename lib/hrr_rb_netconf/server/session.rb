# coding: utf-8
# vim: et ts=2 sw=2

require 'time'
require 'date'
require 'thread'
require 'monitor'
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
        @monitor = Monitor.new
        @subscribed_streams = Hash.new
        @subscribed_streams_stop_time = Hash.new
        @notification_replay_thread = nil
        @subscription_termination_thread = nil
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
        @io_r.close_read rescue nil
        @notification_replay_thread.exit if @notification_replay_thread rescue nil
        @notification_termination_thread.exit if @notification_termination_thread rescue nil
        @logger.info { "Closed" }
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
            rescue Error => e
              rpc_reply_e = REXML::Element.new("rpc-reply")
              rpc_reply_e.add_namespace("urn:ietf:params:xml:ns:netconf:base:1.0")
              rpc_reply_e.add e.to_rpc_error
            rescue => e
              @logger.error { e.message }
              raise
            end
            @monitor.synchronize do
              begin
                rpc_reply_e = operation.run received_message
              rescue Error => e
                rpc_reply_e = received_message.clone
                rpc_reply_e.name = "rpc-reply"
                rpc_reply_e.add e.to_rpc_error
              rescue => e
                @logger.error { e.message }
                raise
              ensure
                begin
                  @sender.send_message rpc_reply_e if rpc_reply_e
                rescue IOError
                  break
                end
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

      def subscription_creatable? stream
        @logger.info { "Check subscription for stream: #{stream}" }
        if ! @server.has_notification_stream? stream
          @logger.error { "Server doesn't have notification stream: #{stream}" }
          false
        elsif @subscribed_streams.has_key? stream
          @logger.error { "Session already has subscription for stream: #{stream}" }
          false
        else
          @logger.info { "Subscription creatable for stream: #{stream}" }
          true
        end
      end

      def create_subscription stream, start_time, stop_time
        @logger.info { "Create subscription for stream: #{stream}" }
        @subscribed_streams[stream] = true
        start_notification_termination_thread stream, start_time, stop_time if stop_time
        @logger.info { "Create subscription done for stream: #{stream}" }
      end

      def terminate_subscription stream
        @logger.info { "Terminate subscription for stream: #{stream}" }
        @subscribed_streams.delete stream
        @logger.info { "Terminate subscription done for stream: #{stream}" }
      end

      def notification_replay stream, start_time, stop_time, events
        if @server.notification_stream_support_replay? stream
          start_notification_replay_thread stream, start_time, stop_time, events
        else
          @logger.error { "Notification replay is not supported by stream: #{stream}" }
          raise Error['operation-failed'].new('protocol', 'error')
        end
      end

      def stream_subscribed? stream
        @subscribed_streams.has_key? stream
      end

      def start_notification_replay_thread stream, start_time, stop_time, events
        @notification_replay_thread = Thread.new do
          @logger.info { "Notification replay start for stream: #{stream}" }
          begin
            @monitor.synchronize do
              unless events.respond_to? :each
                @logger.error { "Argument `events' doesn't respond to :each method: #{events}" }
              else
                begin
                  events.each{ |arg1, arg2|
                    event_xml = NotificationEvent.new(arg1, arg2).to_xml
                    if @server.event_match_stream? event_xml, stream
                      if start_time
                        event_time = DateTime.rfc3339(event_xml.elements['eventTime'].text)
                        if start_time < event_time
                          if stop_time.nil? || event_time < stop_time
                            send_notification event_xml
                          end
                        end
                      end
                    end
                  }
                rescue => e
                  @logger.error { "Got an exception during processing replay: #{e.message}" }
                end
              end
              send_replay_complete stream
            end
          ensure
            @logger.info { "Notification replay completed for stream: #{stream}" }
          end
        end
      end

      def start_notification_termination_thread stream, start_time, stop_time
        @notification_termination_thread = Thread.new do
          @logger.info { "Notification termination thread start for stream: #{stream}" }
          begin
            loop do
              now = DateTime.now
              if now.to_time < stop_time.to_time
                sleep_time = ((stop_time.to_time - now.to_time) / 2.0).ceil
                @logger.debug { "Notification termination thread for stream: #{stream}: sleep [sec]: #{sleep_time}" }
                sleep sleep_time
              else
                @logger.info { "Notification termination thread terminates subscription for stream: #{stream}" }
                @monitor.synchronize do
                  terminate_subscription stream
                  send_notification_complete stream
                end
                break
              end
            end
          ensure
            @logger.info { "Notification termination completed for stream: #{stream}" }
          end
        end
      end

      def send_notification event_e
        @monitor.synchronize do
          notif_e = REXML::Element.new("notification")
          notif_e.add_namespace("urn:ietf:params:xml:ns:netconf:notification:1.0")
          event_e.elements.each{ |e|
            notif_e.add e.deep_clone
          }
          begin
            @sender.send_message notif_e
          rescue IOError => e
            @logger.warn { "Failed sending notification: #{e.message}" }
          end
        end
      end

      def filter_and_send_notification matched_streams, event_xml
        unless (matched_streams & @subscribed_streams.keys).empty?
          #event_e = filter(event_xml)
          event_e = event_xml
          send_notification event_e
        end
      end

      def send_replay_complete stream
        event_xml = HrrRbRelaxedXML::Document.new
        event_time_e = event_xml.add_element('eventTime')
        event_time_e.text = DateTime.now.rfc3339
        event_e = event_xml.add_element("replayComplete")
        send_notification event_xml
      end

      def send_notification_complete stream
        event_xml = HrrRbRelaxedXML::Document.new
        event_time_e = event_xml.add_element('eventTime')
        event_time_e.text = DateTime.now.rfc3339
        event_e = event_xml.add_element("notificationComplete")
        send_notification event_xml
      end
    end
  end
end
