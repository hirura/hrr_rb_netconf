# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/server/error/rpc_errorable'

module HrrRbNetconf
  class Server
    class Error
      class UnknownAttribute < Error
        include RpcErrorable

        TAG      = 'unknown-attribute'
        TYPE     = ['rpc', 'protocol', 'application']
        SEVERITY = ['error']
        INFO     = ['bad-attribute', 'bad-element']
      end
    end
  end
end
