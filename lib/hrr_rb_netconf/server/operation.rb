# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/logger'
require 'hrr_rb_netconf/server/operation/base'
require 'hrr_rb_netconf/server/operation/model'
require 'hrr_rb_netconf/server/filter'

module HrrRbNetconf
  class Server
    class Operation
      def initialize server, session, datastore_session
        @logger = Logger.new self.class.name
        @server = server
        @session = session
        @datastore_session = datastore_session
        @models = Hash.new
        @operations = Hash.new
        @to_close = false
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

        raw_output = @datastore_session.run(input_e.name, input_e)

        case input_e.name
        when 'close-session'
          @session.close
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
        rpc_reply_e = xml_doc.clone
        rpc_reply_e.name = "rpc-reply"
        rpc_reply_e.add output_e
        rpc_reply_e
      end
    end
  end
end
