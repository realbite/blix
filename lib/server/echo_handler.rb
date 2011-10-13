# the handler must respond to any rpc methods that can be 
# requested from the server. Derive your custom handler
# from Handler and define your custom methods.

module Blix::Server
  class Handler
    # store a pointer pack to the server here for notification calls
    def set_server(server)
      @server = server
    end
    
    # a pointer to the server
    def server
      @server
    end
  end
end

module Blix::Server
  module EchoHandlerMethods
    def echo(val)
      puts "echo #{val.inspect}" if $DEBUG
      val
    end
  end
end

module Blix::Server
  class EchoHandler < Handler
    include EchoHandlerMethods
  end
end