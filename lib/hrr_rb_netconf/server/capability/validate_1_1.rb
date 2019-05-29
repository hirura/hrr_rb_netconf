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
      end
    end
  end
end
