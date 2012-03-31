require 'zmq'
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
    class ZmqServer < BaseServer
      
      # create a server passing the handler object and a hash of options.
      # the handler object gets its 'process'method called with the message
      # and the resulting message is passed back to the response queue
      #
      #  handler, object with 'process' method to process requests
      #

      def setup(opts)
        @zmq = ZMQ::Context.new(1)
        @responder = @zmq.socket(ZMQ::REP)
        @responder.bind("tcp://*:7301")
        @notifier  = @zmq.socket(ZMQ::PUB)
        @notifier.bind("tcp://*:7302")
        @_run = true
      end
      
      def closedown
        @responder.setsockopt(ZMQ::LINGER,0)
        @notifier.setsockopt(ZMQ::LINGER,0)
        @responder.close
        @notifier.close
        @zmq.close
        exit
      end
      
      # enter a loop just listening for requests and passing them on to the
      # handler and returning the response if there is one.
      def listen(&block)
        while @_run do
          request   = @responder.recv #(ZMQ::NOBLOCK)
          if request
            response  = block && block.call(request)
            @responder.send( response )
          end
        end
      end
      
      def send_notification(msg)
        @notifier.send(msg)
      end
      
    end #ZmqServer
  end
end #Blix
