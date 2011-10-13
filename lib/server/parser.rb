
module Blix
  module Server
    
    class ParseError < StandardError; end
    
    # Handler is is the base class for all Handlers. Subclass the Handler to implement a
    # specific rpc format. The following methods must be reimplemented in your subclasses
    # to convert to and from data in the rpc format to a standard format.
    #
    #   parse_request(data)               # create a RequestMessage object from rpc data
    #   format_response(message)          # create rpc data from response message
    #   format_error(message)             # create rpc data from error message
    #   format_notification(signal,value) # create rpc data from notification
    
    class Parser
      
      #---------------------------------------------------------------------------------
      # the following methods must be reimplemented in your subclasses
      
      # parse a message string and return a RequestMessage object.
      # reimplement this method 
      def parse_request(data)
        raise "please implement parse_request(data) in your subclass "
      end
      
      # format a response message into data
      # reimplement this method
      def format_response(message)
        raise "please implement format_response(message) in your subclass "
      end
      
      # format an error message into data
      # reimplement this method
      def format_error(message)
        raise "please implement format_error(message) in your subclass "
      end
      
      # format an error message into data
      # reimplement this method
      def format_notification(signal,value)
        raise "please implement format_notification(signal,value) in your subclass "
      end
      
      #-------------------------------------------------------------------------------
      
      # store a list of valid klasses that can be used with this parser here
      def valid_klass
        @valid_klass ||= Blix::ValidKlassList.new
      end
      
      # dump information to stdout as an  aid to debugging.
      def dump
        puts "#{Time.now} --------------------------------------------"
        puts $!
        puts $@
        puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        puts @request && @request.raw
        puts "--------------------------------------------------------"
      end
      
            
      # decode the message and either perform standard processing or pass on
      # to custom handlers if available.
#      def call(data)
#        
#        # see if the method can be understood.
#        begin
#          @request = parse_request(data)
#        rescue Exception=>e
#          dump
#          e             = ErrorMessage.new
#          e.id          = nil
#          e.code        = 100
#          e.description = "invalid request formatting"
#          e.method      = "not defined"
#          return  format_error(e)
#        end
#        
#        response = Message::Response.new
#        
#        # handle message with custom handler if available
#        if @service && @service.respond_to?( @request.method_name.to_sym )
#          begin
#            # convert the parameters to arguments
#            args = ServerMethod.as_args @request.method_name, @request.parameters
#            response.data = @service.send @request.method_name.to_sym, *args
#          rescue Exception=>e
#            dump
#            response = Message::Error.new
#            response.id = @request.id
#            response.code = 200
#            response.description = e.to_s
#          end
#          
#          # otherwise try to handle with standard crud  
#        elsif @request.crud?
#          begin
#            response.data = @request.crud_execute
#          rescue Exception=>e
#            dump
#            response = Message::Error.new
#            response.id = @request.id
#            response.code = 400
#            response.description = e.to_s
#          end
#          # otherwise we cannot handle this message  
#        elsif @request.method_name == "echo"
#          v = @request.parameters[:item]
#          puts "[echo] #{v}(#{v.class})"
#          response.data = v
#          #puts "... #{response.to_message}"
#        else
#          response = Message::Error.new
#          response.id = @request.id
#          response.code = 400
#          response.description = "invalid method call:#{@request.method_name}" 
#        end
#        response.method = @request.method_name
#        response.id     = @request.id
#        response
#      end
#      
#      
#      
#      if value.kind_of? Hash
#        @handler.notify(signal,value)
#      else
#        @handler.notify(signal,{:item=>value})
#      end
      
    end #Parser
    
  end #Server
end #Blix
