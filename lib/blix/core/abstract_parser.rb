
module Blix
    
    class ParseError < StandardError; end
    
    # Handler is is the base class for all Handlers. Subclass the Handler to implement a
    # specific rpc format. The following methods must be reimplemented in your subclasses
    # to convert to and from data in the rpc format to a standard format.
    #
    #   parse_request(data)               # create a RequestMessage object from rpc data
    #   format_response(message)          # create rpc data from response message
    #   format_error(message)             # create rpc data from error message
    #   format_notification(signal,value) # create rpc data from notification
    
    class AbstractParser
      
      #---------------------------------------------------------------------------------
      # the following methods must be reimplemented in your subclasses
      
      # parse a message string and return a RequestMessage object.
      # reimplement this method 
      def parse_request(data)
        raise "please implement parse_request(data) in your subclass "
      end
      
      # parse a message string and return a RequestMessage object.
      # reimplement this method 
      def parse_response(data)
        raise "please implement parse_response(data) in your subclass "
      end
      
      # parse a message string and return a RequestMessage object.
      # reimplement this method 
      def parse_notification(data)
        raise "please implement parse_notification(data) in your subclass "
      end
      
      # format a response message into data
      # reimplement this method
      def format_request(message)
        raise "please implement format_request(message) in your subclass "
      end
      
      # format a response message into data
      # reimplement this method
      def format_response(message)
        raise "please implement format_response(message) in your subclass "
      end
      
            
      # format an error message into data
      # reimplement this method
      def format_notification(message)
        raise "please implement format_notification(message) in your subclass "
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
      
            
      
      
    end #Parser

end #Blix
