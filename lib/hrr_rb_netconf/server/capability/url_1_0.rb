# coding: utf-8
# vim: et ts=2 sw=2

require 'uri'

module HrrRbNetconf
  class Server
    class Capability
      class Url_1_0 < Capability
        ID = 'urn:ietf:params:netconf:capability:url:1.0'
        QUERIES = {'scheme' => ['http', 'ftp', 'file']}
        DEPENDENCIES = []
        IF_FEATURES  = []

        model 'edit-config',   ['edit-content', 'url'],            'leaf', 'type' => 'string', 'validation' => proc { |cap, node| cap.queries['scheme'].any?{|s| s == URI.parse(node.text).scheme} }
        model 'copy-config',   ['target', 'config-target', 'url'], 'leaf', 'type' => 'string'
        model 'copy-config',   ['source', 'config-source', 'url'], 'leaf', 'type' => 'string'
        model 'delete-config', ['target', 'config-target', 'url'], 'leaf', 'type' => 'string'
        model 'validate',      ['source', 'config-source', 'url'], 'leaf', 'type' => 'string'
      end
    end
  end
end
