# coding: utf-8
# vim: et ts=2 sw=2

module HrrRbNetconf
  class Server
    class Error < StandardError
      @subclass_list = Array.new

      class << self
        def inherited klass
          @subclass_list.push klass if @subclass_list
        end

        def [] key
          __subclass_list__(__method__).find{ |klass| klass::TAG == key }
        end

        def list
          __subclass_list__(__method__).map{ |klass| klass::TAG }
        end

        def __subclass_list__ method_name
          send(:method_missing, method_name) unless @subclass_list
          @subclass_list
        end

        private :__subclass_list__
      end
    end
  end
end

require 'hrr_rb_netconf/server/error/in_use'
require 'hrr_rb_netconf/server/error/invalid_value'
require 'hrr_rb_netconf/server/error/too_big'
require 'hrr_rb_netconf/server/error/missing_attribute'
require 'hrr_rb_netconf/server/error/bad_attribute'
require 'hrr_rb_netconf/server/error/unknown_attribute'
require 'hrr_rb_netconf/server/error/missing_element'
require 'hrr_rb_netconf/server/error/bad_element'
require 'hrr_rb_netconf/server/error/unknown_element'
require 'hrr_rb_netconf/server/error/unknown_namespace'
require 'hrr_rb_netconf/server/error/access_denied'
require 'hrr_rb_netconf/server/error/lock_denied'
require 'hrr_rb_netconf/server/error/resource_denied'
require 'hrr_rb_netconf/server/error/rollback_failed'
require 'hrr_rb_netconf/server/error/data_exists'
require 'hrr_rb_netconf/server/error/data_missing'
require 'hrr_rb_netconf/server/error/operation_not_supported'
require 'hrr_rb_netconf/server/error/operation_failed'
require 'hrr_rb_netconf/server/error/partial_operation'
require 'hrr_rb_netconf/server/error/malformed_message'
