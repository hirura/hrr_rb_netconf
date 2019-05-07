# coding: utf-8
# vim: et ts=2 sw=2

require 'hrr_rb_netconf/server/error/rpc_errorable'

module HrrRbNetconf
  class Server
    class Error
      class PartialOperation < Error
        include RpcErrorable

        TAG      = 'partial-operation'
        TYPE     = ['application']
        SEVERITY = ['error']
        INFO     = ['ok-element', 'err-element', 'noop-element']
      end
    end
  end
end
