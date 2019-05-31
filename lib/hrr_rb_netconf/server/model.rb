# coding: utf-8
# vim: et ts=2 sw=2

require 'rexml/document'
require 'hrr_rb_netconf/server/error'
require 'hrr_rb_netconf/server/model/node'

module HrrRbNetconf
  class Server
    class Model
      def initialize operation
        @operation = operation
        @tree = Node.new operation, 'root', {}
      end

      def add_recursively node, path, stmt, options
        name = path.shift
        case path.size
        when 0
          node.children.push Node.new name, stmt, options
        else
          child_node = node.children.find{|n| name == n.name}
          add_recursively child_node, path, stmt, options
        end
      end

      def add path, stmt, options
        if path.size > 0
          add_recursively @tree, path.dup, stmt, options
        end
      end

      def validate_recursively node, xml_e, parent_xml_e: nil, validated: []
        case node.stmt
        when 'root', 'container'
          case xml_e
          when nil
            true
          else
            node.children.all?{ |c|
              case c.stmt
              when 'container'
                validated.push c.name
                validate_recursively c, xml_e.elements[c.name]
              when 'leaf'
                validated.push c.name
                if xml_e.elements[c.name].nil? && c.options['default'].nil?
                  true
                else
                  validate_recursively c, xml_e.elements[c.name], parent_xml_e: xml_e
                end
              when 'choice'
                validate_recursively c, xml_e, validated: validated
              else
                raise Error['unknown-element'].new('application', 'error', info: {'bad-element' => "#{c.name}: #{c.stmt}"}, 'message' => 'Not implemented')
              end
            }
          end && (xml_e.elements.to_a.map{|e| e.name} - validated).empty?
        when 'leaf'
          case node.options['type']
          when 'empty'
            xml_e != nil && xml_e.has_text?.!
          when 'enumeration'
            if xml_e == nil && node.options['default']
              parent_xml_e.add_element(node.name).text = node.options['default']
            else
              xml_e != nil && node.options['enum'].include?(xml_e.text)
            end
          when 'anyxml'
            xml_e != nil && (REXML::Document.new(xml_e.text) rescue false)
          when 'inet:uri'
            xml_e != nil
            raise Error['unknown-element'].new('application', 'error', info: {'bad-element' => "#{node.name}: #{node.stmt}"}, 'message' => 'Not implemented: type inet:uri')
          when 'integer'
            if xml_e == nil && node.options['default']
              parent_xml_e.add_element(node.name).text = node.options['default']
            else
              value = (Integer(xml_e.text) rescue false)
              if node.options['range']
                min, max = node.options['range']
                xml_e != nil && value && min <= value && value <= max
              else
                xml_e != nil && value
              end
            end
          when 'string'
            if xml_e == nil && node.options['default']
              parent_xml_e.add_element(node.name).text = node.options['default']
            else
              xml_e != nil && xml_e.has_text?
            end
          end
        when 'choice'
          if node.options['mandatory']
            node.children.any?{ |c|
              validated.push c.name
              validate_recursively c, xml_e.elements[c.name]
            }
          else
            node.children.empty? || node.children.any?{ |c|
              validated.push c.name
              validate_recursively c, xml_e.elements[c.name]
            }
          end
        else
          raise Error['unknown-element'].new('application', 'error', info: {'bad-element' => "#{c.name}: #{c.stmt}"}, 'message' => 'Not implemented')
        end
      end

      def validate input_e
        validate_recursively @tree, input_e
      end
    end
  end
end
