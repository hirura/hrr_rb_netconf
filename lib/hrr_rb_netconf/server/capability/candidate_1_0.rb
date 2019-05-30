# coding: utf-8
# vim: et ts=2 sw=2

module HrrRbNetconf
  class Server
    class Capability
      class Candidate_1_0 < Capability
        ID = 'urn:ietf:params:netconf:capability:candidate:1.0'
        DEPENDENCIES = []
        IF_FEATURES  = ['candidate']

        oper_proc('commit'){ |server, session, datastore, input_e|
          datastore.run 'commit', input_e
          '<ok />'
        }

        oper_proc('discard-changes'){ |server, session, datastore, input_e|
          datastore.run 'discard-changes', input_e
          '<ok />'
        }

        model 'get-config',      ['source', 'config-source', 'candidate'], 'leaf', 'type' => 'empty'
        model 'edit-config',     ['target', 'config-target', 'candidate'], 'leaf', 'type' => 'empty'
        model 'copy-config',     ['source', 'config-source', 'candidate'], 'leaf', 'type' => 'empty'
        model 'copy-config',     ['target', 'config-target', 'candidate'], 'leaf', 'type' => 'empty'
        model 'validate',        ['source', 'config-source', 'candidate'], 'leaf', 'type' => 'empty'
        model 'lock',            ['target', 'config-target', 'candidate'], 'leaf', 'type' => 'empty'
        model 'unlock',          ['target', 'config-target', 'candidate'], 'leaf', 'type' => 'empty'
        model 'commit',          []
        model 'discard-changes', []
      end
    end
  end
end
