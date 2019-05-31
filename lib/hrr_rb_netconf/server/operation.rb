# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/logger'
require 'hrr_rb_netconf/server/model'
require 'hrr_rb_netconf/server/filter'

module HrrRbNetconf
  class Server
    class Operation
      def initialize server, session, capabilities, datastore_session
        @logger = Logger.new self.class.name
        @server = server
        @session = session
        @capabilities = capabilities
        @datastore_session = datastore_session
        @models = Hash.new
        @oper_procs = Hash.new

        load_capabilities
      end

      def load_capabilities
        @capabilities.each_loadable{ |c|
          c.oper_procs.each{ |k, v|
            @oper_procs[k] = v
          }
          c.models.each{ |m|
            oper_name, path, stmt, options = m
            @models[oper_name] ||= Model.new oper_name
            @models[oper_name].add path, stmt, options
          }
        }
      end

      def validate input_e
        oper_name = input_e.name
        model = @models[oper_name]
        if model
          model.validate input_e
        else
          false
        end
      end

      def run xml_doc
        unless xml_doc.root.name == 'rpc'
          @logger.error { "Invalid root tag: must be rpc, but got #{xml_doc.root.name}" }
          raise Error['operation-not-supported'].new('protocol', 'error')
        end

        message_id = xml_doc.attributes['message-id']
        unless message_id
          raise Error['missing-attribute'].new('rpc', 'error', info: {'bad-attribute' => 'message-id', 'bad-element' => 'rpc'})
        end

        input_e = xml_doc.elements[1]

        unless @oper_procs.has_key? input_e.name
          raise Error['operation-not-supported'].new('protocol', 'error')
        end

        unless validate input_e
          raise Error['operation-not-supported'].new('application', 'error')
        end

        raw_output = @oper_procs[input_e.name].call(@session, @datastore_session, input_e)

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
        rpc_reply_e = xml_doc.clone
        rpc_reply_e.name = "rpc-reply"
        rpc_reply_e.add output_e
        rpc_reply_e
      end
    end
  end
end
