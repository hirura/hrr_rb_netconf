# coding: utf-8
# vim: et ts=2 sw=2

require 'tsort'
require 'hrr_rb_netconf/server/capability'

module HrrRbNetconf
  class Server
    class Capabilities
      def initialize features=nil, capabilities_h=nil
        @features = features
        unless capabilities_h
          @caps = Capability.list.inject({}){ |a, b| a.merge({b => Capability[b].new}) }
        else
          @caps = capabilities_h
        end
      end

      def negotiate remote_capabilities
        capabilities_h = (@caps.keys & remote_capabilities).inject({}){ |a, b| a.merge({b => @caps[b]}) }
        Capabilities.new @features, capabilities_h
      end

      def register_capability name, &blk
        cap = Capability.new(name)
        blk.call cap
        @caps[name] = cap
      end

      def unregister_capability name
        @caps.delete name
      end

      def list_all
        @caps.keys
      end

      def list_supported
        @caps.select{ |k, v| if @features.nil? then true else (v.if_features - @features).empty? end }.keys
      end

      def list_loadable
        filtered_by_features = @caps.select{ |k, v| if @features.nil? then true else (v.if_features - @features).empty? end }
        @filtered_by_dependencies = filtered_by_features.select{ |k, v| v.dependencies.all?{ |d| filtered_by_features.has_key? d } }
        tsort
      end

      def each_loadable
        list_loadable.each do |c|
          yield @caps[c]
        end
      end

      include TSort

      def tsort_each_node &blk
        @filtered_by_dependencies.each_key(&blk)
      end

      def tsort_each_child node, &blk
        @filtered_by_dependencies[node].dependencies.each(&blk)
      end
    end
  end
end
