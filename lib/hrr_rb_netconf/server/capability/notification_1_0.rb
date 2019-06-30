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
        IF_FEATURES  = ['notification']

        oper_proc('create-subscription'){ |session, datastore, input_e|
          logger = Logger.new HrrRbNetconf::Server::Capability::Notification_1_0
          stream_e = input_e.elements['stream']
          unless stream_e
            logger.debug { "create-subscription doesn't have stream, so use NETCONF stream" }
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
            logger.error { "Not available stream: #{stream}" }
            raise Error['bad-element'].new('protocol', 'error', info: {'bad-element' => 'stream'})
          end
          if start_time.nil? && stop_time
            logger.error { "startTime element doesn't exist, but stopTime does" }
            raise Error['missing-element'].new('protocol', 'error', info: {'bad-element' => 'startTime'})
          end
          if start_time && stop_time && (start_time > stop_time)
            logger.error { "stopTime is earlier than startTime" }
            raise Error['bad-element'].new('protocol', 'error', info: {'bad-element' => 'stopTime'})
          end
          if start_time && (start_time > DateTime.now)
            logger.error { "startTime is later than current time" }
            raise Error['bad-element'].new('protocol', 'error', info: {'bad-element' => 'startTime'})
          end
          begin
            events = datastore.run('create-subscription', input_e)
          rescue Error
            raise
          rescue => e
            logger.error { "Exception in datastore.run('create-subscription', input_e): #{e.message}" }
            raise Error['operation-failed'].new('application', 'error')
          end
          begin
            if start_time
              session.notification_replay stream, start_time, stop_time, events
            end
          rescue Error
            raise
          rescue => e
            logger.error { "Exception in session.notification_replay: #{e.message}" }
            raise Error['operation-failed'].new('protocol', 'error')
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
