# coding: utf-8
# vim: et ts=2 sw=2

require 'rexml/document'
require 'hrr_rb_netconf/logger'

module HrrRbNetconf
  class Server
    class Capability
      class Base_1_1 < Capability
        ID = 'urn:ietf:params:netconf:base:1.1'
        DEPENDENCIES = []
        IF_FEATURES  = []

        oper_proc('get'){ |server, session, datastore, input_e|
          datastore.run 'get', input_e
        }

        oper_proc('get-config'){ |server, session, datastore, input_e|
          datastore.run 'get-config', input_e
        }

        oper_proc('edit-config'){ |server, session, datastore, input_e|
          datastore.run 'edit-config', input_e
          '<ok />'
        }

        oper_proc('copy-config'){ |server, session, datastore, input_e|
          datastore.run 'copy-config', input_e
          '<ok />'
        }

        oper_proc('delete-config'){ |server, session, datastore, input_e|
          datastore.run 'delete-config', input_e
          '<ok />'
        }

        oper_proc('lock'){ |server, session, datastore, input_e|
          target = input_e.elements['target'].elements[1].name
          session.lock target
          begin
            datastore.run 'lock', input_e
            '<ok />'
          rescue
            session.unlock target
            raise
          end
        }

        oper_proc('unlock'){ |server, session, datastore, input_e|
          datastore.run 'unlock', input_e
          target = input_e.elements['target'].elements[1].name
          session.unlock target
          '<ok />'
        }

        oper_proc('close-session'){ |server, session, datastore, input_e|
          datastore.run 'close-session', input_e
          session.close
          '<ok />'
        }

        oper_proc('kill-session'){ |server, session, datastore, input_e|
          server.close_session Integer(input_e.elements['session-id'].text)
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

        class Sender
          MAX_CHUNK_SIZE = 2**32 - 1

          def initialize io_w
            @logger = Logger.new self.class.name
            @io_w = io_w
            @formatter = REXML::Formatters::Pretty.new(2)
            @formatter.compact = true
          end

          def send_message msg
            raw_msg = StringIO.new
            case msg
            when String
              begin
                @formatter.write(REXML::Document.new(msg, {:ignore_whitespace_nodes => :all}).root, raw_msg)
              rescue => e
                @logger.error { "Invalid sending message: #{msg.inspect}: #{e.message}" }
                raise "Invalid sending message: #{msg.inspect}: #{e.message}"
              end
            when REXML::Document
              @formatter.write(msg.root, raw_msg)
            when REXML::Element
              @formatter.write(msg, raw_msg)
            else
              @logger.error { "Unexpected sending message: #{msg.inspect}" }
              raise ArgumentError, "Unexpected sending message: #{msg.inspect}"
            end
            @logger.debug { "Sending message: #{raw_msg.string.inspect}" }
            raw_msg.rewind
            encoded_msg = StringIO.new
            until raw_msg.eof?
              chunk_size = rand(1..MAX_CHUNK_SIZE)
              chunk_data = raw_msg.read(chunk_size)
              encoded_msg.write "\n##{chunk_data.size}\n#{chunk_data}"
            end
            encoded_msg.write "\n##\n"
            @logger.debug { "Sending encoded message: #{encoded_msg.string.inspect}" }
            begin
              @io_w.write encoded_msg.string
            rescue => e
              @logger.info { "Sender IO closed: #{e.class}: #{e.message}" }
              raise IOError, "Sender IO closed: #{e.class}: #{e.message}"
            end
          end
        end

        class Receiver
          def initialize io_r
            @logger = Logger.new self.class.name
            @io_r = io_r
          end

          def receive_message
            chunk_size = StringIO.new
            chunked_msg = StringIO.new
            decoded_msg = StringIO.new
            read_len = 1
            state = :beginning_of_msg
            until state == :end_of_msg
              begin
                buf = @io_r.read(read_len)
              rescue => e
                @logger.info { "Receiver IO closed: #{e.class}: #{e.message}" }
                return nil
              end
              if buf.nil?
                @logger.info { "Receiver IO closed" }
                return nil
              end
              chunked_msg.write buf
              case state
              when :beginning_of_msg
                if buf == "\n"
                  state = :before_chunk_size
                else
                  info = "In beginning_of_msg: expected #{"\n".inspect}, but got #{buf.inspect}: #{chunked_msg.string.inspect}"
                  @logger.info { info }
                  raise Error['malformed-message'].new("rpc", "error")
                end
              when :before_chunk_size
                if buf == "#"
                  state = :in_chunk_size
                else
                  info = "In before_chunk_size: expected #{"#".inspect}, but got #{buf.inspect}: #{chunked_msg.string.inspect}"
                  @logger.info { info }
                  raise Error['malformed-message'].new("rpc", "error")
                end
              when :in_chunk_size
                if buf =~ /[0-9]/
                  chunk_size.write buf
                elsif buf == "\n"
                  read_len = chunk_size.string.to_i
                  state = :in_chunk_data
                elsif buf == "#"
                  state = :ending_msg
                else
                  info = "In in_chunk_size: expected #{"/[0-9]/".inspect}, #{"\n".inspect}, or #{"#".inspect}, but got #{buf.inspect}: #{chunked_msg.string.inspect}"
                  @logger.info { info }
                  raise Error['malformed-message'].new("rpc", "error")
                end
              when :in_chunk_data
                chunk_size = StringIO.new
                decoded_msg.write buf
                read_len = 1
                state = :after_chunk_data
              when :after_chunk_data
                if buf == "\n"
                  state = :before_chunk_size
                else
                  info = "In after_chunk_data: expected #{"\n".inspect}, but got #{buf.inspect}: #{chunked_msg.string.inspect}"
                  @logger.info { info }
                  raise Error['malformed-message'].new("rpc", "error")
                end
              when :ending_msg
                if buf == "\n"
                  state = :end_of_msg
                else
                  info = "In ending_msg: expected #{"\n".inspect}, but got #{buf.inspect}: #{chunked_msg.string.inspect}"
                  @logger.info { info }
                  raise Error['malformed-message'].new("rpc", "error")
                end
              end
            end
            @logger.debug { "Received message: #{decoded_msg.string.inspect}" }
            begin
              received_msg = REXML::Document.new(decoded_msg.string, {:ignore_whitespace_nodes => :all}).root
              validate_received_msg received_msg
              received_msg
            rescue => e
              info = "Invalid received message: #{e.message.split("\n").first}: #{decoded_msg.string.inspect}"
              @logger.info { info }
              raise Error['malformed-message'].new("rpc", "error")
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
