# coding: utf-8
# vim: et ts=2 sw=2

module HrrRbNetconf
  class Server
    class Model
      class Node
        attr_reader :capability, :name, :stmt, :options, :children
        def initialize capability, name, stmt, options
          @capability = capability
          @name = name
          @stmt = stmt
          @options = options
          @children = Array.new
        end
      end
    end
  end
end
