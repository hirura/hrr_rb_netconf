# coding: utf-8
# vim: et ts=2 sw=2

module HrrRbNetconf
  class Server
    class Capability
      class RollbackOnError_1_0 < Capability
        ID = 'urn:ietf:params:netconf:capability:rollback-on-error:1.0'
        DEPENDENCIES = []
        IF_FEATURES  = ['rollback-on-error']

        model 'edit-config', ['error-option'], 'leaf', 'type' => 'enumeration', 'enum' => ['stop-on-error', 'continue-on-error', 'rollback-on-error'], 'default' => 'stop-on-error'
      end
    end
  end
end
