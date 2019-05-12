# coding: utf-8
# vim: et ts=2 sw=2

require 'rexml/document'

module HrrRbNetconf
  class Server
    class Error < StandardError
      module RpcErrorable
        def initialize type, severity, info: nil, app_tag: nil, path: nil, message: nil
          @logger   = Logger.new self.class.name

          @tag      = self.class::TAG
          @type     = type
          @severity = severity
          @info     = info
          @app_tag  = app_tag
          @path     = path
          @message  = message

          validate
        end

        def validate
          validate_type
          validate_severity
          validate_info
          validate_app_tag
          validate_path
          validate_message
        end

        def validate_type
          unless self.class::TYPE.include? @type
            raise ArgumentError.new "error-type arg must be one of #{self.class::TYPE}, but given #{@type}"
          end
        end

        def validate_severity
          unless self.class::SEVERITY.include? @severity
            raise ArgumentError.new "error-severity arg must be one of #{self.class::SEVERITY}, but given #{@severity}"
          end
        end

        def validate_info
          unless self.class::INFO.empty?
            unless @info.kind_of? Hash
              raise ArgumentError.new "error-info arg must be a kind of Hash, but given #{@info.class}"
            end
            unless self.class::INFO.all?{ |e| @info[e] }
              raise ArgumentError.new "error-info arg must contain #{self.class::INFO} as keys, but given #{@info}"
            end
          end
        end

        def validate_app_tag
          # Pass
        end

        def validate_path
          if @path
            case @path
            when Hash
              unless @path['value']
                raise ArgumentError.new "error-path arg must contain 'value' key if Hash"
              end
            end
          end
        end

        def validate_message
          if @message
            case @message
            when Hash
              unless @message['value']
                raise ArgumentError.new "error-message arg must contain \"value\" key if Hash"
              end
              unless @message.fetch('attributes', {}).keys.include?('xml:lang')
                @logger.warn { "error-message arg does not contain \"xml:lang\" attribute, so assuming \"en\"" }
              end
            else
              @logger.warn { "error-message arg does not contain \"xml:lang\" attribute, so assuming \"en\"" }
            end
          end
        end

        def to_rpc_error
          xml_doc = REXML::Document.new
          rpc_error_e = xml_doc.add_element 'rpc-error'
          tag_e = rpc_error_e.add_element 'error-tag'
          tag_e.text = @tag
          type_e = rpc_error_e.add_element 'error-type'
          type_e.text = @type
          severity_e = rpc_error_e.add_element 'error-severity'
          severity_e.text = @severity
          if @info
            info_e = rpc_error_e.add_element 'error-info'
            case @info
            when Hash
              @info.each{ |k, v|
                child_e = info_e.add_element k
                child_e.text = v
              }
            else
              info_e.text = @info
            end
          end
          if @app_tag
            app_tag_e = rpc_error_e.add_element 'error-app-tag'
            app_tag_e.text = @app_tag
          end
          if @path
            path_e = rpc_error_e.add_element 'error-path'
            case @path
            when Hash
              path_e.add_attributes @path['attributes']
              path_e.text = @path['value']
            else
              path_e.text = @path
            end
          end
          if @message
            message_e = rpc_error_e.add_element 'error-message'
            message_e.add_attribute 'xml:lang', 'en'
            case @message
            when Hash
              message_e.add_attributes @message['attributes']
              message_e.text = @message['value']
            else
              message_e.text = @message
            end
          end
          xml_doc.root
        end
      end
    end
  end
end
