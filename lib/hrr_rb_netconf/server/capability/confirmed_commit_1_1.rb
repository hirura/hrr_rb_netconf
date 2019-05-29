# coding: utf-8
# vim: et ts=2 sw=2

module HrrRbNetconf
  class Server
    class Capability
      class ConfirmedCommit_1_1 < Capability
        ID = 'urn:ietf:params:netconf:capability:confirmed-commit:1.1'
        DEPENDENCIES = ['urn:ietf:params:netconf:capability:candidate:1.0']
        IF_FEATURES  = ['candidate', 'confirmed-commit']

        oper_proc('cancel-commit'){ |server, session, datastore, input_e|
          datastore.run 'cancel-commit', input_e
          '<ok />'
        }
      end
    end
  end
end
