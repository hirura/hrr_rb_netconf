# coding: utf-8
# vim: et ts=2 sw=2

require 'rexml/document'

module HrrRbNetconf
  class Server
    class Filter
      class Subtree < Filter
        TYPE = 'subtree'

        class << self
          def debug
            false
          end

          def filter raw_output_e, filter_e
            selected_element_xpaths = []
            output_xml_doc = REXML::Document.new 
            filter_recursively(selected_element_xpaths, output_xml_doc, raw_output_e, filter_e)
            if debug
              formatter = REXML::Formatters::Pretty.new(2)
              formatter.compact = true
              formatter.write output_xml_doc, STDOUT
              STDOUT.puts
            end
            output_xml_doc.root
          end

          def content_match_nodes_match_all? content_match_nodes, raw_output_e
            content_match_nodes.all?{ |child_filter_e|
              p 'child_filter_e', child_filter_e, child_filter_e.namespace, child_filter_e.name, child_filter_e.text if debug
              child_filter_attributes = child_filter_e.attributes.to_a.reject{ |attr| (attr.prefix =='' && attr.name == 'xmlns') || attr.prefix == 'xmlns' }
              raw_output_e.elements.to_a.any?{ |child_raw_output_e|
                p 'child_raw_output_e', child_raw_output_e, child_raw_output_e.namespace, child_raw_output_e.name, child_raw_output_e.text if debug
                (child_filter_e.namespace == "" || child_filter_e.namespace == child_raw_output_e.namespace) && child_filter_e.name == child_raw_output_e.name && child_filter_e.text == child_raw_output_e.text && (
                  child_filter_attributes.empty? || child_filter_attributes.reject{ |child_filter_attr|
                    child_raw_output_e.attributes.to_a.reject{ |attr| (attr.prefix =='' && attr.name == 'xmlns') || attr.prefix == 'xmlns' }.any?{ |child_raw_output_attr|
                      (child_filter_attr.namespace == "" || child_filter_attr.namespace == child_raw_output_attr.namespace) && child_filter_attr.name == child_raw_output_attr.name && child_filter_attr.value == child_raw_output_attr.value
                    }
                  }
                )
              }
            }
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

          def filter_recursively selected_element_xpaths, output_e, raw_output_e, filter_e, options={}
            if debug
              puts
              puts '##### start filter_recursively #####'
              p 'output_e',     [output_e,     (output_e.name rescue nil),     (output_e.namespace rescue nil),     (output_e.attributes.to_a.reject{ |attr|     (attr.prefix =='' && attr.name == 'xmlns') || attr.prefix == 'xmlns' } rescue nil)]
              p 'raw_output_e', [raw_output_e, (raw_output_e.name rescue nil), (raw_output_e.namespace rescue nil), (raw_output_e.attributes.to_a.reject{ |attr| (attr.prefix =='' && attr.name == 'xmlns') || attr.prefix == 'xmlns' } rescue nil)]
              p 'filter_e',     [filter_e,     (filter_e.name rescue nil),     (filter_e.namespace rescue nil),     (filter_e.attributes.to_a.reject{ |attr|     (attr.prefix =='' && attr.name == 'xmlns') || attr.prefix == 'xmlns' } rescue nil)]
              p 'options',      options
            end
            if filter_e
              if raw_output_e.name == filter_e.name
                # Namespace Selection
                filter_namespace = options['namespace'] || filter_e.namespace
                if filter_namespace == nil || filter_namespace == "" || raw_output_e.namespace == filter_namespace
                  # Attribute Match Expressions
                  filter_attributes = filter_e.attributes.to_a.reject{ |attr| (attr.prefix =='' && attr.name == 'xmlns') || attr.prefix == 'xmlns' }
                  if filter_attributes.empty? || filter_attributes.reject{ |filter_attr|
                    raw_output_e.attributes.to_a.reject{ |attr| (attr.prefix =='' && attr.name == 'xmlns') || attr.prefix == 'xmlns' }.any?{ |raw_output_attr|
                      filter_attr.namespace == raw_output_attr.namespace && filter_attr.name == raw_output_attr.name && filter_attr.value == raw_output_attr.value
                    }
                  }.empty?
                    if filter_e.has_elements?
                      p 'filter_e.has_elements' if debug
                      # Containment Nodes
                      if filter_e.elements.to_a.select{ |c| c.has_text? }.empty?
                        p 'Containment Nodes' if debug
                        child_output_e = add_elem selected_element_xpaths, output_e, raw_output_e
                        p "child_output_e #{child_output_e.inspect} added" if debug
                        raw_output_e.each_element{ |child_raw_output_e|
                          filter_e.elements.to_a.select{ |c| c.name == child_raw_output_e.name && (c.namespace == "" || c.namespace == child_raw_output_e.namespace) }.each{ |child_filter_e|
                            filter_recursively selected_element_xpaths, child_output_e, child_raw_output_e, child_filter_e, {'namespace' => filter_namespace}
                          }
                        }
                      # Content Match Nodes
                      else
                        p 'Content Match Nodes' if debug
                        content_match_nodes = filter_e.elements.to_a.select{ |c| c.has_text? }
                        not_content_match_nodes = filter_e.elements.to_a.reject{ |c| c.has_text? }
                        p 'content_match_nodes', content_match_nodes.map{ |c| c.to_s } if debug
                        p 'not_content_match_nodes', not_content_match_nodes.map{ |c| c.to_s } if debug
                        if content_match_nodes_match_all? content_match_nodes, raw_output_e
                          p 'content match' if debug
                          child_output_e = add_elem selected_element_xpaths, output_e, raw_output_e
                          p "child_output_e #{child_output_e.inspect} added" if debug
                          if not_content_match_nodes.empty?
                            p 'not_content_match_nodes.empty?' if debug
                            raw_output_e.each_element{ |child_raw_output_e|
                              p "child_raw_output_e: #{child_raw_output_e.to_s}" if debug
                              child_filter_e = filter_e.elements.to_a.find{ |c| (c.namespace == "" || child_raw_output_e.namespace == c.namespace) && child_raw_output_e.name == c.name }
                              p "child_filter_e: #{child_filter_e.to_s}" if debug
                              if child_filter_e
                                filter_recursively selected_element_xpaths, child_output_e, child_raw_output_e, child_filter_e, {'namespace' => filter_namespace}
                              else
                                filter_recursively selected_element_xpaths, child_output_e, child_raw_output_e, child_filter_e, {'namespace' => filter_namespace, 'in_filter' => true}
                              end
                            }
                          else
                            p 'not not_content_match_nodes.empty?' if debug
                            raw_output_e.each_element{ |child_raw_output_e|
                              p "child_raw_output_e: #{child_raw_output_e.to_s}" if debug
                              child_filter_e = filter_e.elements.to_a.find{ |c| (c.namespace == "" || child_raw_output_e.namespace == c.namespace) && child_raw_output_e.name == c.name }
                              p "child_filter_e: #{child_filter_e.to_s}" if debug
                              filter_recursively selected_element_xpaths, child_output_e, child_raw_output_e, child_filter_e, {'namespace' => filter_namespace}
                            }
                          end
                        else
                          p 'content did not match' if debug
                        end
                      end
                    else
                      p 'not filter_e.has_elements' if debug
                      child_output_e = add_elem selected_element_xpaths, output_e, raw_output_e
                      p "child_output_e #{child_output_e.inspect} added" if debug
                      if raw_output_e.has_text?
                        child_output_e.text = raw_output_e.text
                      else
                        raw_output_e.each_element{ |child_raw_output_e|
                          filter_recursively selected_element_xpaths, child_output_e, child_raw_output_e, nil, {'namespace' => filter_namespace, 'in_filter' => true}
                        }
                      end
                    end
                  end
                end
              end
            elsif options['in_filter']
              # Namespace Selection
              filter_namespace = options['namespace']
              if filter_namespace == nil || filter_namespace == "" || raw_output_e.namespace == filter_namespace
                child_output_e = add_elem selected_element_xpaths, output_e, raw_output_e
                p "child_output_e #{child_output_e.inspect} added" if debug
                if raw_output_e.has_text?
                  child_output_e.text = raw_output_e.text
                end
                raw_output_e.each_element{ |child_raw_output_e|
                  filter_recursively selected_element_xpaths, child_output_e, child_raw_output_e, filter_e, {'namespace' => filter_namespace, 'in_filter' => true}
                }
              end
            end
          end
        end
      end
    end
  end
end
