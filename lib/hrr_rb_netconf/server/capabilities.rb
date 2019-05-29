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
          @caps = Capability.list.inject([]){ |a, b| a + [[b, Capability[b].new]] }.to_h
        else
          @caps = capabilities_h
        end
      end

      def negotiate remote_capabilities
        capabilities_h = (@caps.keys & remote_capabilities).map{ |k| [k, @caps[k]] }.to_h
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
        filtered_by_dependencies = filtered_by_features.select{ |k, v| v.dependencies.all?{ |d| filtered_by_features.has_key? d } }
        each_node = lambda {|&b| filtered_by_dependencies.each_key(&b) }
        each_child = lambda {|n, &b| filtered_by_dependencies[n].dependencies.each(&b) }
        TSort.tsort(each_node, each_child)
      end

      def each_loadable
        list_loadable.each do |c|
          yield @caps[c]
        end
      end
    end
  end
end
