require 'monitor'
require 'observer'

module Blix
  module Client
    
    class ServerError < StandardError; end  # an error ocurred on the server
    
    # Connection allows rpc calls to be made to a server and also listens
    # for notifications from the server and passes these on to any observers
    # of this class.
    class Connection < Monitor
      include Observable
      
      private_class_method :new
      
      #-------------------------------------------------------------------------------
      # reimplement the following methods in your subclasses
      #
      
      # listen for rpc calls and service them. reimplement this function to
      # provide your functionality and call do_handle(message) to
      # process the call
      def setup(opts)
        raise  "please reimplement setup(opts) method in your subclass"
      end
      
      def listen
        raise  "please reimplement listen() method in your subclass"
      end
      
      # send a rpc message - reimplement this function to provide
      # the functionality.
      def send_request(data)
        raise  "please reimplement send_request(data) method in your subclass"
      end
      
      #-------------------------------------------------------------------------------
      def Connection.instance
        @_instance
      end
      
      def Connection.create(parser,opts={})
        raise "Connection already created !!!" if @_instance
        @_instance = new(parser,opts)
      end
      
      def initialize(parser,opts)
        @parser    = parser
        setup(opts)
        listen
      end
      
      # the parser handles conversion between the raw data and the request/response
      # and notification messages
      def parser
        @parser
      end
      
      # send a request message to the server
      def request_message(message)
        data               = parser.format_request(message)
        reply              = send_request(data)
        response           = parser.parse_response(reply)
        if response.error?
          raise ServerError,"#{response.code}:#{response.description}"
        end
        response.value
      end
      
      # send a request with named parameters in hash format
      def request(method,hash={})
        request            = RequestMessage.new
        request.method     = method.to_s
        request.parameters = hash
        request.id         = 123 # not important here - could generate a random number.
        request_message(request)
      end
      
      # try to pass missing methods on as a request if possible
      def method_missing(name,*args)
        begin
          hash = Blix::ServerMethod.as_hash(name, *args)
          request(name,hash)
        rescue ArgumentError
          super
        end
      end
      
      
      # handle notification data that has been received
      def do_handle(data)
        notification = nil
        begin
          notification = parser.parse_notification(data)
          notify(notification.signal,notification.value)
        rescue 
          dump(data)
        end
      end
      
      # inform oberservers of the signal
      def notify(signal,value)
        puts "Client::Connection::notify (start) [#{signal}] < #{ value.inspect }>" if $DEBUG
        changed
        notify_observers(signal,value) rescue puts "Client::AbstractConnection[notify] #{$!}\n#{$@}"
        puts "Client::Connection::notify (end) [#{signal}] }" if $DEBUG
      end
      
      # dump information to stdout as an  aid to debugging.
      def dump(data=nil)
        puts "#{Time.now} --------------------------------------------"
        puts $!
        puts $@
        puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        puts data || "no data available"
        puts "--------------------------------------------------------"
      end
      
    end # class
  end
end