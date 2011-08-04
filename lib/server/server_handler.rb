require 'server/json_message'
require 'core/valid_class'

module Blix
  module Server
    #-----------------------------------------------------------------------------------------
    class Handler
      
      # pass the custom service handler
      def initialize(service=nil)
        @service = service
      end
      
      # dump information to stdout as an  aid to debugging.
      def dump
        puts "#{Time.now} --------------------------------------------"
        puts $!
        puts $@
        puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        puts @message && @message.raw
        puts "--------------------------------------------------------"
      end
      
      # decode the message and either perform standard processing or pass on
      # to custom handlers if available.
      def process(message)
        
        begin
          @message=Message::Request.parse(message)
        rescue Exception=>e
          dump
          @message=nil
        end
        response = Message::Response.new
        
        if @message
          # handle message with custom handler if available
          if @service && @service.respond_to?( @message.method_name.to_sym )
            begin
              # convert the parameters to arguments
              args = ServerMethod.as_args @message.method_name, @message.parameters
              response.data = @service.send @message.method_name.to_sym, *args
            rescue Exception=>e
              dump
              response = Message::Error.new
              response.id = @message.id
              response.code = 200
              response.description = e.to_s
            end
            # otherwise try to handle with standard crud  
          elsif @message.crud?
            begin
              response.data = @message.crud_execute
            rescue Exception=>e
              dump
              response = Message::Error.new
              response.id = @message.id
              response.code = 400
              response.description = e.to_s
            end
            # otherwise we cannot handle this message  
          elsif @message.method_name == "echo"
            v = @message.parameters[:item]
            puts "[echo] #{v}(#{v.class})"
            response.data = v
            #puts "... #{response.to_message}"
          else
            response = Message::Error.new
            response.id = @message.id
            response.code = 400
            response.description = "invalid method call:#{@message.method_name}" 
          end
        else
          e = Message::Error.new
          e.id = nil
          e.code = 100
          e.description = "invalid message formatting"
          e.method = "not defined"
          return e # no message
        end
        response.method = @message.method_name
        response.id     = @message.id
        response
      end
      
      def notify(signal,*args)
        str = args.join('/')
        puts "server notifying [#{signal}] - #{str}"
        message = Message::Notification.new(signal,*args) 
        message.send
      end
      
    end #Handler
    
  end #Server
end #Blix
