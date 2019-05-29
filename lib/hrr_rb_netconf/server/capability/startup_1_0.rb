# coding: utf-8
# vim: et ts=2 sw=2

module HrrRbNetconf
  class Server
    class Capability
      class Startup_1_0 < Capability
        ID = 'urn:ietf:params:netconf:capability:startup:1.0'
        DEPENDENCIES = []
        IF_FEATURES  = ['startup']
      end
    end
  end
end
