# coding: utf-8
# vim: et ts=2 sw=2

require 'rexml/document'
require 'hrr_rb_netconf/logger'

module HrrRbNetconf
  class Server
    class Capability
      class Base_1_0 < Capability
        ID = 'urn:ietf:params:netconf:base:1.0'

        class Sender
          def initialize io_w
            @logger = Logger.new self.class.name
            @io_w = io_w
            @formatter = REXML::Formatters::Pretty.new(2)
            @formatter.compact = true
          end

          def send_message msg
            buf = String.new
            case msg
            when String
              begin
                @formatter.write(REXML::Document.new(msg, {:ignore_whitespace_nodes => :all}).root, buf)
              rescue => e
                @logger.error { "Invalid sending message: #{msg.inspect}: #{e.message}" }
                raise "Invalid sending message: #{msg.inspect}: #{e.message}"
              end
            when REXML::Document
              @formatter.write(msg.root, buf)
            when REXML::Element
              @formatter.write(msg, buf)
            else
              @logger.error { "Unexpected sending message: #{msg.inspect}" }
              raise ArgumentError, "Unexpected sending message: #{msg.inspect}"
            end
            @logger.debug { "Sending message: #{buf.inspect}" }
            @io_w.write "#{buf}\n]]>]]>\n"
          end
        end

        class Receiver
          def initialize io_r
            @logger = Logger.new self.class.name
            @io_r = io_r
          end

          def receive_message
            buf = String.new
            loop do
              buf << @io_r.read(1)
              if buf[-6..-1] == ']]>]]>'
                break
              end
            end
            @logger.debug { "Received message: #{buf[0..-7].inspect}" }
            begin
              received_msg = REXML::Document.new(buf[0..-7], {:ignore_whitespace_nodes => :all}).root
              validate_received_msg received_msg
              received_msg
            rescue => e
              info = "Invalid received message: #{e.message.split("\n").first}: #{buf[0..-7].inspect}"
              @logger.info { info }
              raise info
            end
          end

          def validate_received_msg received_msg
            unless received_msg
              raise "No valid root tag interpreted"
            end
            unless "rpc" == received_msg.name
              raise "Invalid message: expected #{"rpc".inspect}, but got #{received_msg.name.inspect}"
            end
            unless "urn:ietf:params:xml:ns:netconf:base:1.0" == received_msg.namespace
              raise "Invalid namespace: expected #{"urn:ietf:params:xml:ns:netconf:base:1.0".inspect}, but got #{received_msg.namespace.inspect}"
            end
          end
        end
      end
    end
  end
end
