# coding: utf-8
# vim: et ts=2 sw=2

module HrrRbNetconf
  class Server
    class Capability
      class WritableRunning_1_0 < Capability
        ID = 'urn:ietf:params:netconf:capability:writable-running:1.0'
        DEPENDENCIES = []
        IF_FEATURES  = ['writable-running']

        def define_capability
          model 'edit-config', ['target', 'config-target', 'running'], 'leaf', 'type' => 'empty'
          model 'copy-config', ['target', 'config-target', 'running'], 'leaf', 'type' => 'empty'
        end
      end
    end
  end
end
