# coding: utf-8
# vim: et ts=2 sw=2

require 'rexml/document'
require 'hrr_rb_netconf/loggable'

module HrrRbNetconf
  class Server
    class Capability
      class Base_1_0 < Capability
        ID = 'urn:ietf:params:netconf:base:1.0'
        DEPENDENCIES = []
        IF_FEATURES  = []

        def define_capability
          oper_proc('get'){ |session, datastore, input_e|
            datastore.run 'get', input_e
          }

          oper_proc('get-config'){ |session, datastore, input_e|
            datastore.run 'get-config', input_e
          }

          oper_proc('edit-config'){ |session, datastore, input_e|
            datastore.run 'edit-config', input_e
            '<ok />'
          }

          oper_proc('copy-config'){ |session, datastore, input_e|
            datastore.run 'copy-config', input_e
            '<ok />'
          }

          oper_proc('delete-config'){ |session, datastore, input_e|
            datastore.run 'delete-config', input_e
            '<ok />'
          }

          oper_proc('lock'){ |session, datastore, input_e|
            target = input_e.elements["*[local-name()='target' and namespace-uri()='urn:ietf:params:xml:ns:netconf:base:1.0']/*[position()=1]"].name
            session.lock target
            begin
              datastore.run 'lock', input_e
              '<ok />'
            rescue
              session.unlock target
              raise
            end
          }

          oper_proc('unlock'){ |session, datastore, input_e|
            datastore.run 'unlock', input_e
            target = input_e.elements["*[local-name()='target' and namespace-uri()='urn:ietf:params:xml:ns:netconf:base:1.0']/*[position()=1]"].name
            session.unlock target
            '<ok />'
          }

          oper_proc('close-session'){ |session, datastore, input_e|
            datastore.run 'close-session', input_e
            session.close
            '<ok />'
          }

          oper_proc('kill-session'){ |session, datastore, input_e|
            session.close_other Integer(input_e.elements['session-id'].text)
            '<ok />'
          }

          model 'get',           ['filter'],                             'leaf',     'type' => 'anyxml'
          model 'get-config',    ['source'],                             'container'
          model 'get-config',    ['source', 'config-source'],            'choice',   'mandatory' => true
          model 'get-config',    ['source', 'config-source', 'running'], 'leaf',     'type' => 'empty'
          model 'get-config',    ['filter'],                             'leaf',     'type' => 'anyxml'
          model 'edit-config',   ['target'],                             'container'
          model 'edit-config',   ['target', 'config-target'],            'choice',   'mandatory' => true
          model 'edit-config',   ['default-operation'],                  'leaf',     'type' => 'enumeration', 'enum' => ['merge', 'replace', 'none'], 'default' => 'merge'
          model 'edit-config',   ['error-option'],                       'leaf',     'type' => 'enumeration', 'enum' => ['stop-on-error', 'continue-on-error', 'rollback-on-error'], 'default' => 'stop-on-error'
          model 'edit-config',   ['edit-content'],                       'choice',   'mandatory' => true
          model 'edit-config',   ['edit-content', 'config'],             'leaf',     'type' => 'anyxml'
          model 'copy-config',   ['target'],                             'container'
          model 'copy-config',   ['target', 'config-target'],            'choice',   'mandatory' => true
          model 'copy-config',   ['source'],                             'container'
          model 'copy-config',   ['source', 'config-source'],            'choice',   'mandatory' => true
          model 'copy-config',   ['source', 'config-source', 'running'], 'leaf',     'type' => 'empty'
          model 'copy-config',   ['source', 'config-source', 'config'],  'leaf',     'type' => 'anyxml'
          model 'delete-config', ['target'],                             'container'
          model 'delete-config', ['target', 'config-target'],            'choice',   'mandatory' => true
          model 'lock',          ['target'],                             'container'
          model 'lock',          ['target', 'config-target'],            'choice',   'mandatory' => true
          model 'lock',          ['target', 'config-target', 'running'], 'leaf',     'type' => 'empty'
          model 'unlock',        ['target'],                             'container'
          model 'unlock',        ['target', 'config-target'],            'choice',   'mandatory' => true
          model 'unlock',        ['target', 'config-target', 'running'], 'leaf',     'type' => 'empty'
          model 'close-session', []
          model 'kill-session',  ['session-id'],                         'leaf',     'type' => 'integer', 'range' => [1, 2**32-1]
        end

        class Sender
          include Loggable

          def initialize io_w, logger: nil
            self.logger = logger
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
                log_error { "Invalid sending message: #{msg.inspect}: #{e.message}" }
                raise "Invalid sending message: #{msg.inspect}: #{e.message}"
              end
            when REXML::Document
              @formatter.write(msg.root, buf)
            when REXML::Element
              @formatter.write(msg, buf)
            else
              log_error { "Unexpected sending message: #{msg.inspect}" }
              raise ArgumentError, "Unexpected sending message: #{msg.inspect}"
            end
            log_debug { "Sending message: #{buf.inspect}" }
            begin
              @io_w.write "#{buf}\n]]>]]>"
            rescue => e
              log_info { "Sender IO closed: #{e.class}: #{e.message}" }
              raise IOError, "Sender IO closed: #{e.class}: #{e.message}"
            end
          end
        end

        class Receiver
          include Loggable

          def initialize io_r, logger: nil
            self.logger = logger
            @io_r = io_r
          end

          def receive_message
            buf = String.new
            loop do
              begin
                tmp = @io_r.read(1)
              rescue => e
                log_info { "Receiver IO closed: #{e.class}: #{e.message}" }
                return nil
              end
              if tmp.nil?
                log_info { "Receiver IO closed" }
                return nil
              end
              buf += tmp
              if buf[-6..-1] == ']]>]]>'
                break
              end
            end
            log_debug { "Received message: #{buf[0..-7].inspect}" }
            begin
              received_msg = REXML::Document.new(buf[0..-7], {:ignore_whitespace_nodes => :all}).root
              validate_received_msg received_msg
              received_msg
            rescue => e
              info = "Invalid received message: #{e.message.split("\n").first}: #{buf[0..-7].inspect}"
              log_info { info }
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
