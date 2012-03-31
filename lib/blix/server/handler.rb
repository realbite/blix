# the handler must respond to any rpc methods that can be 
# requested from the server. Derive your custom handler
# from Handler and define your custom methods.

module Blix::Server
  class Handler
    # store a pointer pack to the server here for notification calls
    def set_server(server)
      @server = server
    end
    
    # store a pointer here to the parser cause it might come in use
    def set_parser(parser)
      @parser = parser
    end
    
    # a pointer to the parser
    def parser
      @parser
    end
    
    # a pointer to the server
    def server
      @server
    end
    
    # and a shortcut to the valid_klass
    def valid_klass
      @parser.valid_klass
    end
  end
end
