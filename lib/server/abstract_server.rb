# The template for a server. Derive your servers from this class and override the constructor.

module Blix
  module Server
    class AbstractServer
      private_class_method :new
      
      @@instance = nil # share the instance amoung subclasses
      
      #-------------------------------------------------------------------------------
      # reimplement the following methods in your subclasses
      #
      def setup(opts)
        raise  "please reimplement setup(opts) method in your subclass"
      end
      
      # listen for rpc calls and service them. reimplement this function to
      # provide your functionality and call do_handle(message) to
      # process the call
      def listen
        raise  "please reimplement listen() method in your subclass"
      end
      
      # send a notification message - reimplement this function to provide
      # the functionality.
      def send_notification(data)
        raise  "please reimplement send_notification(data) method in your subclass"
      end
      
      #-------------------------------------------------------------------------------
      
      def self.create(parser,handler, opts={})
        raise "server already created" if @@instance
        @@instance = new(parser,handler, opts)
      end
      
      
      # start a new server instance
      def self.start
        raise "please create server first" unless @@instance
        @@instance.listen
      end
      
      def self.instance
        @@instance
      end
      
      def self.notify(signal,value=nil)
        instance && instance.notify(signal,value)
      end
      
      # initialize the server - here you should listen for
      # rpc calls and call the handler to process the messages.
      # return the message returned from the handler as the response.
      def initialize(parser,handler, opts)
        raise ArgumentError,"invalid parser"  unless parser.kind_of? AbstractParser
        raise ArgumentError,"invalid handler" unless handler.kind_of? Handler
        @parser  = parser
        @handler = handler
        @handler.set_server(self)
        @handler.set_parser(@parser)
        @info    = opts[:info]
        @logger_info  = opts[:info_logger] ||opts[:logger]
        @logger_error = opts[:error_logger] || opts[:logger]
        setup(opts)
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
        message = NotificationMessage.new
        message.signal = signal
        message.value  = value
        data = parser.format_notification(message)
        puts "#{Time.now}  notification  [ #{signal} ] #{value.class}:#{value.id if value.respond_to?(:id)}" if @info
        log_info "notification  [ #{signal} ] #{value.class}:#{value.id if value.respond_to?(:id)}" 
        send_notification(data)
      end
      
      # pass off a message to the handler and return the response data. nil
      # if there is not to be a response.
      def do_handle(data)
        
        request = nil
        
        begin
          request = parser.parse_request(data)
        rescue Exception=>e
          dump(data)
          error             = ResponseMessage.new
          error.set_error
          error.id          = nil
          error.code        = 100
          error.description = "invalid request formatting"
          error.method      = "not defined"
          return  parser.format_response(error)
        end
        
        response   = ResponseMessage.new
        start_time = Time.now
        # handle message with custom handler if available
        if handler.respond_to?( request.method.to_sym )
          begin
            # convert the parameters to arguments
            args           = ServerMethod.as_args request.method, request.parameters
            response.value = handler.send request.method.to_sym, *args
            
          rescue Exception=>e
            dump(request.data)
            error             = ResponseMessage.new
            error.set_error
            error.id          = request.id
            error.code        = 200
            error.description = e.to_s
            error.method      = request.method
            return  parser.format_response(error)
          end
          response.method = request.method
          response.id     = request.id
          
          time_diff = Time.now - start_time
          puts "#{Time.now}  #{"%6.3f" % (time_diff*1000)} ms  [ #{request.method} ]" if @info
          log_info "#{"%6.3f" % (time_diff*1000)} ms  [ #{request.method} ]"
          parser.format_response(response)
        else
          error             = ResponseMessage.new
          error.set_error
          error.id          = request.id
          error.code        = 150
          error.description = "Method not found (#{request.method})"
          error.method      = request.method
          return  parser.format_response(error)
        end
      end
      
      # dump information to stdout as an  aid to debugging.
      def dump(data=nil)
          str =  "#{Time.now} --------------------------------------------\n"
          str << $!.to_s
          str << "\n"
          str << $@.to_s
          str << "\n"
          str << "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
          str << data || "no data available"
          str << "\n"
          str << "--------------------------------------------------------"
        puts str if @info
        log_error str
      end
      
      def log_info(str)
        if @logger_info
          @logger_info.info str
        end
      end
      
      def log_error(str)
        if @logger_error
          @logger_error.error str
        end
      end
    end
  end
end