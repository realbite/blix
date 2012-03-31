require 'zmq'

Thread.abort_on_exception = true

module Blix
  module Client
    class ZmqConnection < Connection
      
      # perform initialisation here and then listen for notifications
      #
      def setup(opts)
        @timeout    = opts[:timeout]  || 10
        @zmq        = ZMQ::Context.new(1)
        @request    = @zmq.socket(ZMQ::REQ)
        @request.connect("tcp://*:7301")
        @_run = true
      end
      
      # shutdown the connection cleanly
      def shutdown
        @_run = false
        @thread.join        #wait for thread to terminate
        @request.setsockopt(ZMQ::LINGER, 0)
        @request.close
        @zmq.close
      end
      
      # perform a RPC request
      #
      def send_request(data)
        outgoing = Blix.to_binary_data(data)
        incoming = nil
        unless @request.send(outgoing,ZMQ::NOBLOCK)
          raise "[send_request] cannot send request #{data}"
        end
        timeout = Time.now
        while (!incoming)
          incoming = @request.recv(ZMQ::NOBLOCK)
          raise TimeoutError if (Time.now - timeout) > @timeout
          do_sleep
        end
        incoming
      end
      
      def listen
        @thread = Thread.new(@zmq) do |zmq| 
          notifier  = zmq.socket(ZMQ::SUB)
          notifier.connect("tcp://*:7302")
          notifier.setsockopt(ZMQ::SUBSCRIBE, "")
          while @_run do 
            msg = notifier.recv(ZMQ::NOBLOCK)
            do_handle(msg) if msg
            #r,w,e = ZMQ.select([notifier],nil,nil,0)
            sleep(0.1)
          end
          notifier.setsockopt(ZMQ::UNSUBSCRIBE, "")
          notifier.close
        end
      end  
      
      def do_sleep
        sleep 0.01
      end
      
      
    end #class
  end
end