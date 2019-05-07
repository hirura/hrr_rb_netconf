# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/server/error/rpc_errorable'

module HrrRbNetconf
  class Server
    class Error
      class UnknownElement < Error
        include RpcErrorable

        TAG      = 'unknown-element'
        TYPE     = ['protocol', 'application']
        SEVERITY = ['error']
        INFO     = ['bad-element']
      end
    end
  end
end
