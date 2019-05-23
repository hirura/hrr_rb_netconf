# coding: utf-8
# vim: et ts=2 sw=2

require 'rexml/document'

module HrrRbNetconf
  class Server
    class Filter
      class Subtree < Filter
        TYPE = 'subtree'

        class << self
          def filter raw_output_e, filter_e
            selected_element_xpaths = []
            output_xml_doc = REXML::Document.new 
            subtree_e = filter_e.elements[1]
            filter_recursively(selected_element_xpaths, output_xml_doc, raw_output_e, subtree_e)
            output_xml_doc.root
          end

          def content_match_nodes_match_all? content_match_nodes, raw_output_e
            content_match_nodes.all?{ |child_filter_e|
              child_filter_attributes = child_filter_e.attributes.to_a.reject{ |attr| (attr.prefix =='' && attr.name == 'xmlns') || attr.prefix == 'xmlns' }
              raw_output_e.elements.to_a.any?{ |child_raw_output_e|
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

          def add_elem selected_element_xpaths, output_e, raw_output_e, output_e_duplicated
            if output_e_duplicated
              xpath, elem = selected_element_xpaths.find{ |xpath, elem| xpath == raw_output_e.xpath }
              unless xpath
                child_output_e = output_e.add raw_output_e.clone
                selected_element_xpaths.push [raw_output_e.xpath, child_output_e]
                [child_output_e, false]
              else
                [elem, true]
              end
            else
              child_output_e = output_e.add raw_output_e.clone
              selected_element_xpaths.push [raw_output_e.xpath, child_output_e]
              [child_output_e, false]
            end
          end

          def filter_recursively selected_element_xpaths, output_e, raw_output_e, filter_e, options={}
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
                      # Containment Nodes
                      if filter_e.elements.to_a.select{ |c| c.has_text? }.empty?
                        child_output_e, child_output_e_duplicated = add_elem selected_element_xpaths, output_e, raw_output_e, options['output_e_duplicated']
                        raw_output_e.each_element{ |child_raw_output_e|
                          filter_e.elements.to_a.select{ |c| c.name == child_raw_output_e.name && (c.namespace == "" || c.namespace == child_raw_output_e.namespace) }.each{ |child_filter_e|
                              unless child_output_e_duplicated
                                if selected_element_xpaths.any?{ |xpath, elem| xpath == child_raw_output_e.xpath }
                                  child_output_e_duplicated = true
                                end
                              end
                            filter_recursively selected_element_xpaths, child_output_e, child_raw_output_e, child_filter_e, {'namespace' => filter_namespace, 'output_e_duplicated' => child_output_e_duplicated}
                          }
                        }
                      # Content Match Nodes
                      else
                        content_match_nodes = filter_e.elements.to_a.select{ |c| c.has_text? }
                        not_content_match_nodes = filter_e.elements.to_a.reject{ |c| c.has_text? }
                        if content_match_nodes_match_all? content_match_nodes, raw_output_e
                          child_output_e, child_output_e_duplicated = add_elem selected_element_xpaths, output_e, raw_output_e, options['output_e_duplicated']
                          if not_content_match_nodes.empty?
                            raw_output_e.each_element{ |child_raw_output_e|
                              child_filter_e = filter_e.elements.to_a.find{ |c| (c.namespace == "" || child_raw_output_e.namespace == c.namespace) && child_raw_output_e.name == c.name }
                              if child_filter_e
                                filter_recursively selected_element_xpaths, child_output_e, child_raw_output_e, child_filter_e, {'namespace' => filter_namespace, 'output_e_duplicated' => child_output_e_duplicated}
                              else
                                filter_recursively selected_element_xpaths, child_output_e, child_raw_output_e, child_filter_e, {'namespace' => filter_namespace, 'in_filter' => true, 'output_e_duplicated' => child_output_e_duplicated}
                              end
                            }
                          else
                            raw_output_e.each_element{ |child_raw_output_e|
                              child_filter_e = filter_e.elements.to_a.find{ |c| (c.namespace == "" || child_raw_output_e.namespace == c.namespace) && child_raw_output_e.name == c.name }
                              filter_recursively selected_element_xpaths, child_output_e, child_raw_output_e, child_filter_e, {'namespace' => filter_namespace, 'output_e_duplicated' => child_output_e_duplicated}
                            }
                          end
                        else
                        end
                      end
                    else
                      child_output_e, child_output_e_duplicated = add_elem selected_element_xpaths, output_e, raw_output_e, options['output_e_duplicated']
                      if raw_output_e.has_text?
                        child_output_e.text = raw_output_e.text
                      else
                        raw_output_e.each_element{ |child_raw_output_e|
                          filter_recursively selected_element_xpaths, child_output_e, child_raw_output_e, nil, {'namespace' => filter_namespace, 'in_filter' => true, 'output_e_duplicated' => child_output_e_duplicated}
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
                child_output_e, child_output_e_duplicated = add_elem selected_element_xpaths, output_e, raw_output_e, options['output_e_duplicated']
                if raw_output_e.has_text?
                  child_output_e.text = raw_output_e.text
                end
                raw_output_e.each_element{ |child_raw_output_e|
                  filter_recursively selected_element_xpaths, child_output_e, child_raw_output_e, filter_e, {'namespace' => filter_namespace, 'in_filter' => true, 'outout_e_duplicated' => child_output_e_duplicated}
                }
              end
            end
          end
        end
      end
    end
  end
end
