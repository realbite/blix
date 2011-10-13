# The template for a server. Derive your servers from this class and override the constructor.

module Blix
  module Server
    class GeneralServer
      private_class_method :new
      
      #-------------------------------------------------------------------------------
      # reimplement the following methods in your subclasses
      #
      
      # listen for rpc calls and service them. reimplement this function to
      # provide your functionality and call do_handle(message) to
      # process the call
      def listen(opts)
        raise  "please reimplement listen(opts) method in your subclass"
      end
      
      # send a notification message - reimplement this function to provide
      # the functionality.
      def send_notification(data)
        raise  "please reimplement send_notification(data) method in your subclass"
      end
      
      #-------------------------------------------------------------------------------
      
      # start a new server instance
      def self.start(parser,handler, opts={})
        new(parser,handler, opts)
      end
      
      # initialize the server - here you should listen for
      # rpc calls and call the handler to process the messages.
      # return the message returned from the handler as the response.
      def initialize(parser,handler, opts)
        raise ArgumentError,"invalid parser"  unless parser.kind_of? Parser
        raise ArgumentError,"invalid handler" unless handler.kind_of? Handler
        @parser  = parser
        @handler = handler
        @handler.set_server(self)
        listen(opts)
      end
      
      def parser
        @parser
      end
      
      def handler
        @handler
      end
      
      # send a notification
      def notify(signal,value)
        raise "require a parser to send a notification!" unless parser
        data = parser.format_notification(signal,value)
        puts "server notifying [#{signal}] - #{value}"
        send_notification(data)
      end
      
      # pass off a message to the handler and return the response data. nil
      # if there is not to be a response.
      def do_handle(data)
        
        request = nil
        
        begin
          request = parser.parse_request(data)
        rescue Exception=>e
          dump
          error             = ErrorMessage.new
          error.id          = nil
          error.code        = 100
          error.description = "invalid request formatting"
          error.method      = "not defined"
          return  parser.format_error(error)
        end
        
        response = ResponseMessage.new
        
        # handle message with custom handler if available
        if handler.respond_to?( request.method_name.to_sym )
          begin
            # convert the parameters to arguments
            args = ServerMethod.as_args request.method_name, request.parameters
            response.data = handler.send request.method_name.to_sym, *args
            
          rescue Exception=>e
            dump
            error             = Message::Error.new
            error.id          = request.id
            error.code        = 200
            error.description = e.to_s
            error.method      = request.method
            return  parser.format_error(error)
          end
          response.method = request.method
          response.id     = request.id
          parser.format_response(response)
          
        end
      end
      
      
    end
  end
end