# coding: utf-8
# vim: et ts=2 sw=2

require 'rexml/document'
require 'hrr_rb_netconf/logger'

module HrrRbNetconf
  class Server
    class Capability
      class Notification_1_0 < Capability
        ID = 'urn:ietf:params:netconf:capability:notification:1.0'
        DEPENDENCIES = []
        IF_FEATURES  = []

        oper_proc('create-subscription'){ |session, datastore, input_e|
          #startTime = DateTime.rfc3339(input_e.elements['startTime'].text) rescue nil
          #stopTime  = DateTime.rfc3339(input_e.elements['stopTime'].text)  rescue nil
          session.create_subscription #startTime, stopTime
          events = datastore.run('create-subscription', input_e)
          session.notification_replay events
          '<ok />'
        }

        model 'create-subscription', ['stream'],    'leaf', 'type' => 'string'
        model 'create-subscription', ['filter'],    'leaf', 'type' => 'anyxml'
        model 'create-subscription', ['startTime'], 'leaf', 'type' => 'string'
        model 'create-subscription', ['stopTime'],  'leaf', 'type' => 'string'
      end
    end
  end
end
