# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/server/error/rpc_errorable'

module HrrRbNetconf
  class Server
    class Error
      class ResourceDenied < Error
        include RpcErrorable

        TAG      = 'resource-denied'
        TYPE     = ['transport', 'rpc', 'protocol', 'application']
        SEVERITY = ['error']
        INFO     = []
      end
    end
  end
end
