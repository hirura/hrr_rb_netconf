# coding: utf-8
# vim: et ts=2 sw=2

module HrrRbNetconf
  class Server
    class Capability
      class Validate_1_0 < Capability
        ID = 'urn:ietf:params:netconf:capability:validate:1.0'
        DEPENDENCIES = []
        IF_FEATURES  = ['validate']

        def define_capability
          oper_proc('validate'){ |session, datastore, input_e|
            datastore.run 'validate', input_e
            '<ok />'
          }

          model 'validate',    ['source'],                             'container'
          model 'validate',    ['source', 'config-source'],            'choice',   'mandatory' => true
          model 'validate',    ['source', 'config-source', 'running'], 'leaf',     'type' => 'empty'
          model 'validate',    ['source', 'config-source', 'config'],  'leaf',     'type' => 'anyxml'
        end
      end
    end
  end
end
