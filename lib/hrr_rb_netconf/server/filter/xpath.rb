# coding: utf-8
# vim: et ts=2 sw=2

require 'rexml/document'

module HrrRbNetconf
  class Server
    class Filter
      class Xpath < Filter
        TYPE = 'xpath'

        class << self
          def filter raw_output_e, filter_e
            xpath = filter_e.attributes['select']
            unless xpath
              raise Error['missing-attribute'].new('protocol', 'error', info: {'bad-attribute' => 'select', 'bad-element' => 'filter'})
            end
            raw_output_xml_doc = REXML::Document.new 
            raw_output_xml_doc.add raw_output_e.deep_clone
            selected_element_xpaths = []
            output_xml_doc = REXML::Document.new 
            raw_output_xml_doc.each_element(xpath){ |e|
              ctx_output_e = add_ancestors_recursively selected_element_xpaths, output_xml_doc, e
              e.children.each{ |c|
                case c
                when REXML::Parent
                  ctx_output_e.add c.deep_clone
                else
                  ctx_output_e.add c.clone
                end
              }
            }
            output_xml_doc.root
          end

          def add_elem selected_element_xpaths, output_e, raw_output_e
            xpath, elem = selected_element_xpaths.find{ |xpath, elem| xpath == raw_output_e.xpath }
            unless xpath
              child_output_e = output_e.add raw_output_e.clone
              selected_element_xpaths.push [raw_output_e.xpath, child_output_e]
              child_output_e
            else
              elem
            end
          end

          def add_ancestors_recursively selected_element_xpaths, output_e, raw_output_e
            if raw_output_e == raw_output_e.root_node
              output_e
            else
              parent_e = add_ancestors_recursively selected_element_xpaths, output_e, raw_output_e.parent
              add_elem selected_element_xpaths, parent_e, raw_output_e
            end
          end
        end
      end
    end
  end
end
