# coding: utf-8
# vim: et ts=2 sw=2

require 'date'
require 'thread'
require 'hrr_rb_relaxed_xml'
require 'hrr_rb_netconf/loggable'
require 'hrr_rb_netconf/server/error'
require 'hrr_rb_netconf/server/errors'
require 'hrr_rb_netconf/server/datastore'
require 'hrr_rb_netconf/server/capabilities'
require 'hrr_rb_netconf/server/session'
require 'hrr_rb_netconf/server/notification_event'
require 'hrr_rb_netconf/server/notification_streams'

module HrrRbNetconf
  class Server
    include Loggable

    SESSION_ID_UNALLOCATED = "UNALLOCATED"
    SESSION_ID_MIN = 1
    SESSION_ID_MAX = 2**32 - 1
    SESSION_ID_MODULO = SESSION_ID_MAX - SESSION_ID_MIN + 1

    def initialize datastore, capabilities: nil, strict_capabilities: false, enable_filter: true, logger: nil
      self.logger = logger
      @datastore = datastore
      @capabilities = capabilities || Capabilities.new(logger: logger)
      @strict_capabilities = strict_capabilities
      @enable_filter = enable_filter
      @mutex = Mutex.new
      @sessions = Hash.new
      @locks = Hash.new
      @lock_mutex = Mutex.new
      @last_session_id = SESSION_ID_MIN - 1
      @notification_streams = NotificationStreams.new
    end

    def allocate_session_id
      session_id = (SESSION_ID_MODULO).times.lazy.map{ |idx| (@last_session_id + 1 + idx - SESSION_ID_MIN) % SESSION_ID_MODULO + SESSION_ID_MIN }.reject{ |sid| @sessions.has_key? sid }.first
      unless session_id
        log_error { "Failed allocating Session ID" }
        raise "Failed allocating Session ID"
      end
      @last_session_id = session_id
    end

    def delete_session session_id
      if @sessions.has_key? session_id
        @sessions.delete session_id
      end
    end

    def start_session io
      log_info { "Start session" }
      session_id = SESSION_ID_UNALLOCATED
      begin
        @mutex.synchronize do
          session_id = allocate_session_id
          log_info { "Session ID: #{session_id}" }
          @sessions[session_id] = Session.new self, @capabilities, @datastore, session_id, io, @strict_capabilities, @enable_filter, logger: logger
        end
        @sessions[session_id].start
      rescue => e
        log_error { [e.backtrace[0], ": ", e.message, " (", e.class.to_s, ")\n\t", e.backtrace[1..-1].join("\n\t")].join }
      ensure
        @lock_mutex.synchronize do
          @locks.delete_if{ |tgt, sid| sid == session_id }
        end
        @mutex.synchronize do
          delete_session session_id
        end
        log_info { "Session closed: Session ID: #{session_id}" }
      end
    end

    def close_session session_id
      log_info { "Close session: Session ID: #{session_id}" }
      @sessions[session_id].close
    end

    def lock target, session_id
      log_info { "Lock: Target: #{target}, Session ID: #{session_id}" }
      @lock_mutex.synchronize do
        if @locks.has_key? target
          log_info { "Lock failed, lock is already held by session-id: #{@locks[target]}" }
          raise Error['lock-denied'].new('protocol', 'error', info: {'session-id' => @locks[target].to_s}, message: 'Lock failed, lock is already held', logger: logger)
        else
          @locks[target] = session_id
        end
      end
    end

    def unlock target, session_id
      log_info { "Unlock: Target: #{target}, Session ID: #{session_id}" }
      @lock_mutex.synchronize do
        if @locks.has_key? target
          if @locks[target] == session_id
            @locks.delete target
          else
            log_info { "Unlock failed, lock is held by session-id: #{@locks[target]}" }
            raise Error['operation-failed'].new('protocol', 'error', logger: logger)
          end
        else
          log_info { "Unlock failed, lock is not held" }
          raise Error['operation-failed'].new('protocol', 'error', logger: logger)
        end
      end
    end

    def notification_stream stream, replay_support: false, &blk
      @notification_streams.update stream, blk, replay_support
    end

    def has_notification_stream? stream
      @notification_streams.has_stream? stream
    end

    def notification_stream_support_replay? stream
      @notification_streams.stream_support_replay? stream
    end

    def event_match_stream? event_xml, stream
      @notification_streams.event_match_stream? event_xml, stream
    end

    def send_notification arg1, arg2=nil
      event_xml = NotificationEvent.new(arg1, arg2).to_xml
      matched_streams = @notification_streams.matched_streams event_xml
      log_info { "Send notification" }
      log_debug { "Event time: #{event_xml.elements['eventTime'].text}, Event: #{event_xml.elements.to_a}" }
      @sessions.each{ |session_id, session|
        session.filter_and_send_notification matched_streams, event_xml
      }
      log_info { "Send notification done" }
    end
  end
end
