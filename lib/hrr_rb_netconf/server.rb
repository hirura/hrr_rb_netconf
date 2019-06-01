# coding: utf-8
# vim: et ts=2 sw=2

require 'thread'
require 'hrr_rb_netconf/logger'
require 'hrr_rb_netconf/server/error'
require 'hrr_rb_netconf/server/errors'
require 'hrr_rb_netconf/server/datastore'
require 'hrr_rb_netconf/server/capabilities'
require 'hrr_rb_netconf/server/session'

module HrrRbNetconf
  class Server
    SESSION_ID_UNALLOCATED = "UNALLOCATED"
    SESSION_ID_MIN = 1
    SESSION_ID_MAX = 2**32 - 1
    SESSION_ID_MODULO = SESSION_ID_MAX - SESSION_ID_MIN + 1

    def initialize datastore, capabilities: nil, strict_capabilities: false
      @logger = Logger.new self.class.name
      @datastore = datastore
      @capabilities = capabilities || Capabilities.new
      @strict_capabilities = strict_capabilities
      @mutex = Mutex.new
      @sessions = Hash.new
      @locks = Hash.new
      @lock_mutex = Mutex.new
      @last_session_id = SESSION_ID_MIN - 1
    end

    def allocate_session_id
      session_id = (SESSION_ID_MODULO).times.lazy.map{ |idx| (@last_session_id + 1 + idx - SESSION_ID_MIN) % SESSION_ID_MODULO + SESSION_ID_MIN }.reject{ |sid| @sessions.has_key? sid }.first
      unless session_id
        @logger.error { "Failed allocating Session ID" }
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
      @logger.info { "Starting session" }
      session_id = SESSION_ID_UNALLOCATED
      begin
        @mutex.synchronize do
          session_id = allocate_session_id
          @logger.info { "Session ID: #{session_id}" }
          @sessions[session_id] = Session.new self, @capabilities, @datastore, session_id, io, @strict_capabilities
        end
        t = Thread.new {
          @sessions[session_id].start
        }
        @logger.info { "Session started: Session ID: #{session_id}" }
        t.join
      rescue => e
        @logger.error { "Session terminated: Session ID: #{session_id}" }
        raise
      else
        @logger.info { "Session closed: Session ID: #{session_id}" }
      ensure
        @lock_mutex.synchronize do
          @locks.delete_if{ |tgt, sid| sid == session_id }
        end
        @mutex.synchronize do
          delete_session session_id
        end
      end
    end

    def close_session session_id
      @logger.info { "Close session: Session ID: #{session_id}" }
      @sessions[session_id].close
    end

    def lock target, session_id
      @logger.info { "Lock: Target: #{target}, Session ID: #{session_id}" }
      @lock_mutex.synchronize do
        if @locks.has_key? target
          @logger.info { "Lock failed, lock is already held by session-id: #{@locks[target]}" }
          raise Error['lock-denied'].new('protocol', 'error', info: {'session-id' => @locks[target].to_s}, message: 'Lock failed, lock is already held')
        else
          @locks[target] = session_id
        end
      end
    end

    def unlock target, session_id
      @logger.info { "Unlock: Target: #{target}, Session ID: #{session_id}" }
      @lock_mutex.synchronize do
        if @locks.has_key? target
          if @locks[target] == session_id
            @locks.delete target
          else
            @logger.info { "Unlock failed, lock is held by session-id: #{@locks[target]}" }
            raise Error['operation-failed'].new('protocol', 'error')
          end
        else
          @logger.info { "Unlock failed, lock is not held" }
          raise Error['operation-failed'].new('protocol', 'error')
        end
      end
    end
  end
end
