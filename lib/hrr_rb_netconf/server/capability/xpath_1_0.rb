# coding: utf-8
# vim: et ts=2 sw=2

module HrrRbNetconf
  class Server
    class Capability
      class Xpath_1_0 < Capability
        ID = 'urn:ietf:params:netconf:capability:xpath:1.0'
        DEPENDENCIES = []
        IF_FEATURES  = ['xpath']
      end
    end
  end
end
