# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/server/error/rpc_errorable'

module HrrRbNetconf
  class Server
    class Error
      class OperationFailed < Error
        include RpcErrorable

        TAG      = 'operation-failed'
        TYPE     = ['rpc', 'protocol', 'application']
        SEVERITY = ['error']
        INFO     = []
      end
    end
  end
end
