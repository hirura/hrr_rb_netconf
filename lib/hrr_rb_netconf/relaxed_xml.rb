# coding: utf-8
# vim: et ts=2 sw=2

require 'rexml/document'

module HrrRbNetconf
  class RelaxedXML < REXML::Document
    include REXML

    # brought from REXML::Document#add
    def add( child )
      if child.kind_of? XMLDecl
        if @children[0].kind_of? XMLDecl
          @children[0] = child
        else
          @children.unshift child
        end
        child.parent = self
      elsif child.kind_of? DocType
        insert_before_index = @children.find_index { |x|
          x.kind_of?(Element) || x.kind_of?(DocType)
        }
        if insert_before_index
          if @children[ insert_before_index ].kind_of? DocType
            @children[ insert_before_index ] = child
          else
            @children[ insert_before_index-1, 0 ] = child
          end
        else
          @children << child
        end
        child.parent = self
      else
        # brought from REXML::Parent#add
        object = child
        object.parent = self
        @children << object
        object
      end
    end
    alias :<< :add

    # brought from REXML::Element#add_element
    def add_element(arg=nil, arg2=nil)
      element, attrs = arg, arg2
      raise "First argument must be either an element name, or an Element object" if element.nil?
      el = @elements.add(element)
      attrs.each do |key, value|
        el.attributes[key]=value
      end       if attrs.kind_of? Hash
      el
    end
  end
end
