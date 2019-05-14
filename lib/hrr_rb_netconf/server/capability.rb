# coding: utf-8
# vim: et ts=2 sw=2

module HrrRbNetconf
  class Server
    class Capability
      @subclass_list = Array.new

      class << self
        def inherited klass
          @subclass_list.push klass if @subclass_list
        end

        def [] key
          __subclass_list__(__method__).find{ |klass| klass::ID == key }
        end

        def list
          __subclass_list__(__method__).map{ |klass| klass::ID }
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

require 'hrr_rb_netconf/server/capability/base_1_0'
require 'hrr_rb_netconf/server/capability/base_1_1'
require 'hrr_rb_netconf/server/capability/writable_running_1_0'
require 'hrr_rb_netconf/server/capability/candidate_1_0'
require 'hrr_rb_netconf/server/capability/confirmed_commit_1_0'
require 'hrr_rb_netconf/server/capability/confirmed_commit_1_1'
require 'hrr_rb_netconf/server/capability/rollback_on_error_1_0'
require 'hrr_rb_netconf/server/capability/startup_1_0'
require 'hrr_rb_netconf/server/capability/validate_1_0'
require 'hrr_rb_netconf/server/capability/validate_1_1'
require 'hrr_rb_netconf/server/capability/xpath_1_0'
