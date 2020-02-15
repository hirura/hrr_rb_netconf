# coding: utf-8
# vim: et ts=2 sw=2

module HrrRbNetconf
  class Server
    class Filter
      @subclass_list = Array.new

      class << self
        def inherited klass
          @subclass_list.push klass if @subclass_list
        end

        def [] key
          __subclass_list__(__method__).find{ |klass| klass::TYPE == key }
        end

        def list
          __subclass_list__(__method__).map{ |klass| klass::TYPE }
        end

        def __subclass_list__ method_name
          send(:method_missing, method_name) unless @subclass_list
          @subclass_list
        end

        def filter raw_output_e, input_e
          filter_e = input_e.elements['filter']
          if filter_e
            filter_type = filter_e.attributes['type'] || 'subtree'
            if self[filter_type]
              self[filter_type].filter raw_output_e, filter_e
            else
              raise Error['bad-attribute'].new('protocol', 'error', info: {'bad-attribute' => filter_type, 'bad-element' => 'filter'})
            end
          else
            raw_output_e
          end
        end

        private :__subclass_list__
      end
    end
  end
end

require 'hrr_rb_netconf/server/filter/subtree'
require 'hrr_rb_netconf/server/filter/xpath'
