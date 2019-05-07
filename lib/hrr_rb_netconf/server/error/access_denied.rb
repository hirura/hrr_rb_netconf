# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/server/error/rpc_errorable'

module HrrRbNetconf
  class Server
    class Error
      class AccessDenied < Error
        include RpcErrorable

        TAG      = 'access-denied'
        TYPE     = ['protocol', 'application']
        SEVERITY = ['error']
        INFO     = []
      end
    end
  end
end
