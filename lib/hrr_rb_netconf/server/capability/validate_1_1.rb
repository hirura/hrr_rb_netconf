# coding: utf-8
# vim: et ts=2 sw=2

module HrrRbNetconf
  class Server
    class Capability
      class Validate_1_1 < Capability
        ID = 'urn:ietf:params:netconf:capability:validate:1.1'
        DEPENDENCIES = []
        IF_FEATURES  = ['validate']

        oper_proc('validate'){ |server, session, datastore, input_e|
          datastore.run 'validate', input_e
          '<ok />'
        }

        model 'edit-config', ['test-option'],                        'leaf',     'type' => 'enumeration', 'enum' => ['test-then-set', 'set', 'test-only'], 'default' => 'test-then-set'
        model 'validate',    ['source'],                             'container'
        model 'validate',    ['source', 'config-source'],            'choice',   'mandatory' => true
        model 'validate',    ['source', 'config-source', 'running'], 'leaf',     'type' => 'empty'
        model 'validate',    ['source', 'config-source', 'config'],  'leaf',     'type' => 'anyxml'
      end
    end
  end
end
