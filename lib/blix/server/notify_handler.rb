# the handler must respond to any rpc methods that can be 
# requested from the server. Derive your custom handler
# from Handler and define your custom methods.


module Blix::Server
  module NotifyHandlerMethods
    def notify(signal,val)
      puts "notify #{signal.inspect}:#{val.inspect}" if $DEBUG
      AbstractServer.notify(signal,val)
      true
    end
    
    def self.included(mod)
      Blix::ServerMethod.new(:notify,:signal,:item)
    end
  end
end

module Blix::Server
  class NotifyHandler < Handler
    include NotifyHandlerMethods
  end
end