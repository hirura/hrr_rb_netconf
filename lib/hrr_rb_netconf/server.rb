# coding: utf-8
# vim: et ts=2 sw=2

require 'thread'
require 'hrr_rb_netconf/logger'
require 'hrr_rb_netconf/server/error'
require 'hrr_rb_netconf/server/errors'
require 'hrr_rb_netconf/server/session'

module HrrRbNetconf
  class Server
    SESSION_ID_UNALLOCATED = "UNALLOCATED"
    SESSION_ID_MIN = 1
    SESSION_ID_MAX = 2**32 - 1
    SESSION_ID_MODULO = SESSION_ID_MAX - SESSION_ID_MIN + 1

    def initialize
      @logger = Logger.new self.class.name
      @mutex = Mutex.new
      @sessions = Hash.new
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
          @sessions[session_id] = Session.new self, session_id, io
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
        @mutex.synchronize do
          delete_session session_id
        end
      end
    end
  end
end