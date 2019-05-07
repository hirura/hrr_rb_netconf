# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/server/error/rpc_errorable'

module HrrRbNetconf
  class Server
    class Error
      class LockDenied < Error
        include RpcErrorable

        TAG      = 'lock-denied'
        TYPE     = ['protocol']
        SEVERITY = ['error']
        INFO     = ['session-id']
      end
    end
  end
end
