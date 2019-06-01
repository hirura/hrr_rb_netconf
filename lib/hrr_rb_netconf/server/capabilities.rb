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
        filtered_by_features = @caps.select{ |k, v| if @features.nil? then true else (v.if_features - @features).empty? end }
        capabilities_h = filtered_by_features.values.group_by{ |c| c.keyword }.map{ |k, cs|
          cs.map{ |c|
            remote_capabilities.lazy.map{ |rc| c.negotiate rc }.select{ |nc| nc }.first
          }.compact.max
        }.compact.inject({}){ |a, c|
          a.merge({c.uri => c})
        }
        features = if @features.nil? then nil else @features.dup end
        Capabilities.new features, capabilities_h
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
        @caps.select{ |k, v| if @features.nil? then true else (v.if_features - @features).empty? end }.map{ |k, v| v.id }
      end

      def list_loadable
        filtered_by_features = @caps.select{ |k, v| if @features.nil? then true else (v.if_features - @features).empty? end }
        @filtered_by_dependencies = filtered_by_features.select{ |k, v| v.dependencies.all?{ |d| filtered_by_features.has_key? d } }
        tsort.map{ |k| @filtered_by_dependencies[k].id }
      end

      def each_loadable
        filtered_by_features = @caps.select{ |k, v| if @features.nil? then true else (v.if_features - @features).empty? end }
        @filtered_by_dependencies = filtered_by_features.select{ |k, v| v.dependencies.all?{ |d| filtered_by_features.has_key? d } }
        tsort.each do|k|
          yield @filtered_by_dependencies[k]
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
