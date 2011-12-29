require 'bunny'

module Blix
  module Client
    class DummyConnection < Connection
      
      # perform initialisation here and then listen for notifications
      #
      def setup(opts)
        $BLIX_REQUEST    ||= Queue.new
        $BLIX_NOTIFY     ||= Queue.new
        $BLIX_RESPONSE   ||= Queue.new
        $BLIX_REQUEST.clear
        $BLIX_NOTIFY.clear
        $BLIX_RESPONSE.clear
        puts "QQQQQQQQQQQQQ #{$BLIX_REQUEST.inspect}"
        raise "please setup Dummy server" unless $BLIX_REQUEST.kind_of? Queue
      end
      
      # perform a RPC request
      #
      def send_request(data)
        
        if $DEBUG
          puts "[request]data--------------"
          puts data
          puts "--------------------------" 
        end
        
        $BLIX_REQUEST.push(data)
        $BLIX_RESPONSE.pop
      end
      
      
      
      # listen for notifications and send out signals from the engine
      def listen
        while true
          do_handle($BLIX_NOTIFY.pop )
        end
      end
      
    end #class
  end
end