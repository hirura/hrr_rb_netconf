# coding: utf-8
# vim: et ts=2 sw=2

module HrrRbNetconf
  class Server
    class Capability
      class Startup_1_0 < Capability
        ID = 'urn:ietf:params:netconf:capability:startup:1.0'
        DEPENDENCIES = []
        IF_FEATURES  = ['startup']

        def define_capability
          model 'get-config',    ['source', 'config-source', 'startup'], 'leaf', 'type' => 'empty'
          model 'copy-config',   ['source', 'config-source', 'startup'], 'leaf', 'type' => 'empty'
          model 'copy-config',   ['target', 'config-target', 'startup'], 'leaf', 'type' => 'empty'
          model 'lock',          ['target', 'config-target', 'startup'], 'leaf', 'type' => 'empty'
          model 'unlock',        ['target', 'config-target', 'startup'], 'leaf', 'type' => 'empty'
          model 'validate',      ['source', 'config-source', 'startup'], 'leaf', 'type' => 'empty'
          model 'delete-config', ['target', 'config-target', 'startup'], 'leaf', 'type' => 'empty'
        end
      end
    end
  end
end
