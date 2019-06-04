# coding: utf-8
# vim: et ts=2 sw=2

require 'uri'

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

      class << self
        def oper_procs
          @oper_procs || {}
        end

        def oper_proc oper_name, &blk
          @oper_procs ||= Hash.new
          @oper_procs[oper_name] = blk
        end

        def models
          @models || []
        end

        def model oper_name, path, stmt=nil, attrs={}
          @models ||= Array.new
          @models.push [oper_name, path, stmt, attrs]
        end

        private :oper_proc, :model
      end

      attr_accessor :if_features, :dependencies, :queries

      def initialize id=nil
        @id           = id || self.class::ID
        @queries      = (self.class::QUERIES rescue {})
        @if_features  = (self.class::IF_FEATURES rescue [])
        @dependencies = (self.class::DEPENDENCIES rescue [])
        @oper_procs   = self.class.oper_procs.dup
        @models       = (self.class.models rescue [])
        @uri_proc     = Proc.new { |id| id.split('?').first }
        @keyword_proc = Proc.new { |id| id.split('?').first.match(/^((?:.+(?:\/|:))+.+)(?:\/|:)(.+)$/)[1] }
        @version_proc = Proc.new { |id| id.split('?').first.match(/^((?:.+(?:\/|:))+.+)(?:\/|:)(.+)$/)[2] }
        @decode_queries_proc = Proc.new { |qs_s| URI.decode_www_form(qs_s).inject({}){|a,(k,v)| a.merge({k=>(v.split(','))})} }
        @encode_queries_proc = Proc.new { |qs_h| URI.encode_www_form(qs_h.map{|k,v| [k, v.join(',')]}) }
      end

      def oper_procs
        @oper_procs
      end

      def oper_proc oper_name, &blk
        if blk
          @oper_procs[oper_name] = blk
        end
        @oper_procs[oper_name]
      end

      def models
        @models
      end

      def model oper_name, path, stmt=nil, attrs={}
        @models.push [oper_name, path, stmt, attrs]
      end

      def id
        if @queries.empty?
          @id
        else
          [@id, @encode_queries_proc.call(@queries)].join('?')
        end
      end

      def uri
        @uri_proc.call id
      end

      def keyword
        @keyword_proc.call id
      end

      def version
        @version_proc.call id
      end

      def uri_proc &blk
        if blk
          @uri_proc = blk
        else
          raise ArgumentError, "block not given"
        end
      end

      def keyword_proc &blk
        if blk
          @keyword_proc = blk
        else
          raise ArgumentError, "block not given"
        end
      end

      def version_proc &blk
        if blk
          @version_proc = blk
        else
          raise ArgumentError, "block not given"
        end
      end

      def decode_queries_proc &blk
        if blk
          @decode_queries_proc = blk
        else
          raise ArgumentError, "block not given"
        end
      end

      def encode_queries_proc &blk
        if blk
          @encode_queries_proc = blk
        else
          raise ArgumentError, "block not given"
        end
      end

      def negotiate other_id
        other_keyword = @keyword_proc.call(other_id)
        unless keyword == other_keyword
          nil
        else
          other_version = @version_proc.call(other_id)
          case version <=> other_version
          when 0
            c = self.dup
            c.queries = negotiate_queries(other_id)
            c
          else
            nil
          end
        end
      end

      def negotiate_queries other_id
        other_queries = @decode_queries_proc.call((other_id.split('?') + [''])[1])
        queries.inject({}){ |a, (k, v)|
          if other_queries.has_key?(k)
            values = v & other_queries[k]
            if values.empty?
              a
            else
              a.merge({k => values})
            end
          else
            a
          end
        }
      end

      include Comparable

      def <=> other
        unless keyword == other.keyword
          nil
        else
          version <=> other.version
        end
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
require 'hrr_rb_netconf/server/capability/url_1_0'
require 'hrr_rb_netconf/server/capability/xpath_1_0'
require 'hrr_rb_netconf/server/capability/notification_1_0'
