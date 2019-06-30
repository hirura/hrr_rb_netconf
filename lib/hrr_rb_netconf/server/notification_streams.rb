# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/logger'
require 'hrr_rb_netconf/server/notification_stream'

module HrrRbNetconf
  class Server
    class NotificationStreams
      def initialize
        @streams = Hash.new
        @streams['NETCONF'] = NotificationStream.new(Proc.new { true }, false)
      end

      def has_stream? stream
        @streams.has_key? stream
      end

      def stream_support_replay? stream
        @streams[stream].support_replay?
      end

      def update stream, blk, replay_support
        if blk.nil? && (! @streams.has_key?( stream ))
          raise ArgumentError, "Requires block for new stream: #{stream}"
        end
        blk ||= @streams[stream].blk
        @streams[stream] = NotificationStream.new(blk, replay_support)
      end

      def matched_streams event_xml
        @streams.select{ |k, v| v.match? event_xml }.keys
      end

      def event_match_stream? event_xml, stream
        @streams[stream].match? event_xml
      end
    end
  end
end
