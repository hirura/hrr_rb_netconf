# coding: utf-8
# vim: et ts=2 sw=2

module HrrRbNetconf
  class Server
    class NotificationStream
      attr_reader :blk

      def initialize blk, replay_support
        @blk = blk
        @replay_support = replay_support
      end

      def match? event_xml
        if @blk.call(event_xml)
          true
        else
          false
        end
      end

      def support_replay?
        @replay_support
      end
    end
  end
end
