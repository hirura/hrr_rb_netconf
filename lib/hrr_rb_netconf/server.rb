# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/logger'
require 'hrr_rb_netconf/server/error'

module HrrRbNetconf
  class Server
    def initialize
      @logger = Logger.new self.class.name
    end
  end
end
