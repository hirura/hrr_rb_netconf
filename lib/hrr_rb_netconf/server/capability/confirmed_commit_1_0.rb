# coding: utf-8
# vim: et ts=2 sw=2

module HrrRbNetconf
  class Server
    class Capability
      class ConfirmedCommit_1_0 < Capability
        ID = 'urn:ietf:params:netconf:capability:confirmed-commit:1.0'
        DEPENDENCIES = ['urn:ietf:params:netconf:capability:candidate:1.0']
        IF_FEATURES  = ['candidate', 'confirmed-commit']

        def define_capability
          model 'commit', ['confirmed'],       'leaf', 'type' => 'empty'
          model 'commit', ['confirm-timeout'], 'leaf', 'type' => 'integer', 'range' => [1, 2**32-1], 'default' => '600'
        end
      end
    end
  end
end
