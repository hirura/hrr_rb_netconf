# coding: utf-8
# vim: et ts=2 sw=2

require 'rexml/document'

module HrrRbNetconf
  class Server
    class Capability
      class Notification_1_0 < Capability
        ID = 'urn:ietf:params:netconf:capability:notification:1.0'
        DEPENDENCIES = []
        IF_FEATURES  = ['notification']

        def define_capability
          oper_proc('create-subscription'){ |session, datastore, input_e|
            stream_e = input_e.elements['stream']
            unless stream_e
              log_debug { "create-subscription doesn't have stream, so use NETCONF stream" }
              stream_e = input_e.add_element('stream')
              stream_e.text = 'NETCONF'
            end
            stream = stream_e.text
            start_time_e = input_e.elements['startTime']
            start_time = unless start_time_e
                           nil
                         else
                           DateTime.rfc3339(start_time_e.text)
                         end
            stop_time_e = input_e.elements['stopTime']
            stop_time = unless stop_time_e
                          nil
                        else
                          DateTime.rfc3339(stop_time_e.text)
                        end
            if ! session.subscription_creatable? stream
              log_error { "Not available stream: #{stream}" }
              raise Error['bad-element'].new('protocol', 'error', info: {'bad-element' => 'stream'}, logger: logger)
            end
            if start_time.nil? && stop_time
              log_error { "startTime element doesn't exist, but stopTime does" }
              raise Error['missing-element'].new('protocol', 'error', info: {'bad-element' => 'startTime'}, logger: logger)
            end
            if start_time && stop_time && (start_time > stop_time)
              log_error { "stopTime is earlier than startTime" }
              raise Error['bad-element'].new('protocol', 'error', info: {'bad-element' => 'stopTime'}, logger: logger)
            end
            if start_time && (start_time > DateTime.now)
              log_error { "startTime is later than current time" }
              raise Error['bad-element'].new('protocol', 'error', info: {'bad-element' => 'startTime'}, logger: logger)
            end
            begin
              events = datastore.run('create-subscription', input_e)
            rescue Error
              raise
            rescue => e
              log_error { "Exception in datastore.run('create-subscription', input_e): #{e.message}" }
              raise Error['operation-failed'].new('application', 'error', logger: logger)
            end
            begin
              if start_time
                session.notification_replay stream, start_time, stop_time, events
              end
            rescue Error
              raise
            rescue => e
              log_error { "Exception in session.notification_replay: #{e.message}" }
              raise Error['operation-failed'].new('protocol', 'error', logger: logger)
            end
            session.create_subscription stream, start_time, stop_time
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
end
