require 'bunny'

module Blix
  module Client
    class AsyncAmqpConnection < Connection
      
      # perform initialisation here and then listen for notifications
      #
      def setup(opts)
        @opts       = opts
        @_prefix    = opts[:prefix]   || 'std'
        @host       = opts[:host]     || 'localhost'
        @x_response = opts[:response] || (@_prefix + '.responses')
        @x_request  = opts[:request]  || (@_prefix + '.requests')
        @x_notify   = opts[:notify]   || (@_prefix + '.notify')
        
        @interface   = Bunny.new(:host=>@host,:logging => false)
        #puts self.inspect
        #puts @interface.inspect
        @interface.start
        @out_exch    = @interface.exchange(@x_request) # outgoing exchange for publishing request
        @in_exch     = @interface.exchange(@x_response) 
        @reply_to    = "client.tmp.#{::Kernel.rand(999_999_999_999)}" #FIXME
        @in_queue    = @interface.queue(@reply_to, :auto_delete=>true, :exclusive=>true)
        @in_queue.bind(@in_exch, :key => @reply_to) # queue to read reply from    
        @_outgoing = ''
        @_incoming = ''
      end
      
      # perform a RPC request
      #
      def send_request(data)
        
        if $DEBUG
          puts "[request]data--------------"
          puts data
          puts "--------------------------" 
        end
        
        outgoing = Blix.to_binary_data(data)
        options = {}
        
        options[:key]          = ""
        options[:reply_to]     = @reply_to
        options[:content_type] = "text/xml"
        options[:message_id]   = "#{@time.to_i}#{rand(9999)}"
        @out_exch.publish(outgoing, options )
        
        incoming = nil
        while (!incoming)
          msg = @in_queue.pop
          payload = msg[:payload]
          incoming = payload unless payload == :queue_empty
        end
        #        
        if $DEBUG
          puts "[request]response data-----"
          puts incoming
          puts "--------------------------" 
        end
        incoming
      end
      
      
      #retrieve raw amqp notification messages
      def amqp_listen
        @listener      =  "client.#{::Kernel.rand(999_999_999_999)}"
        Thread.new(self) do 
          AMQP.start(:host => @host) do
            _notify   = MQ.fanout(@x_notify)
            puts "[amqp_listen] starting listener on #{Thread.current}" if $DEBUG
            MQ.queue(@listener, :auto_delete => true).bind(_notify).subscribe{ |msg| yield msg }
          end   
        end
      end
      
      # listen for notifications and send out signals from the engine
      def listen
        amqp_listen do |msg|
          do_handle(msg)
        end
      end
      
    end #class
  end
end