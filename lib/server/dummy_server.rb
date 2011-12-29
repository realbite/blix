require 'core/signals'
require 'thread'

#####################################################################################################
# this module is to allow REST like calls to be made via the amqp protocol on resources.
#
# FORMAT OF CALL
# 
# routing-key     = name of sevice eg demipos.till.add_order ( REST type format )
# reply-to        = name of (temporary queue) to recieve reply
# header[:method] = :get|:post|:put:delete
# body            = data in json format
#
# the conversation takes place via an AMQP TOPIC Exchange
#
# PROCEDURE
#
# - client creates  reply queue ( exclusive and auto-delete)
# - client publishes message on exchange
# - client waits for response (synchronous??) or sets up hook(asynchronos ???????
#
# - server subscribes to queue (exclusive )
# - server reads message / extracts parameters / processes call
# - server publishes response in json format in queue retrieved from reply-to field
# - server sets header[:status] 
# - server sets header[:message] 
#
#
#
#
# C. Andrews
# 18/06/2010
#
##################################################################################################### 

module Blix
  module Server
    class DummyServer < AbstractServer
      
      # create a server passing the handler object and a hash of options.
      # the handler object gets its 'process'method called with the message
      # and the resulting message is passed back to the response queue
      #
      #  handler, object with 'process' method to process requests
      #
      #  :host     => 'localhost', the host of the AMQP broker
      #  :response => 'responses', the response exchange name
      #  :request  => 'requests'   the request exchange name
      #  :notify   => 'notify'     the notifications exchange name
      
      
      def setup(opts)
        puts "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        $BLIX_REQUEST    ||= Queue.new
        $BLIX_NOTIFY     ||= Queue.new
        $BLIX_RESPONSE   ||= Queue.new
        $BLIX_REQUEST.clear
        $BLIX_NOTIFY.clear
        $BLIX_RESPONSE.clear
      end
      
      # enter a loop just listening for requests and passing them on to the
      # handler and returning the response if there is one.
      def listen
        while true
          data        = $BLIX_REQUEST.pop
          response    = do_handle(body)
          if response
            puts "[DummyServer] response: data=#{data}, options=#{options}" if $DEBUG
            $BLIX_RESPONSE.push(data)
          end
        end
     end 
      
      # send a raw message to the notification exchange
      def send_notification(msg)
        $BLIX_NOTIFY.push(msg)
        puts "[DummyServer] notify: message=#{msg}" if $DEBUG
      end
      
    end #DummyServer
  end
end #Blix
