require 'bunny'

module Blix
  module Client
    class AmqpConnection < Connection
      
      # perform initialisation here and then listen for notifications
      #
      def setup(opts)
        @opts       = opts
        @_prefix    = opts[:prefix]   || 'std'
        @host       = opts[:host]     || 'localhost'
        @x_response = opts[:response] || (@_prefix + '.responses')
        @x_request  = opts[:request]  || (@_prefix + '.requests')
        @x_notify   = opts[:notify]   || (@_prefix + '.notify')
        @timeout    = opts[:timeout]  || 10
        
        @interface   = Bunny.new(:host=>@host,:logging => false)
        #puts self.inspect
        #puts @interface.inspect
        @interface.start
        @out_exch    = @interface.exchange(@x_request) # outgoing exchange for publishing request
        @in_exch     = @interface.exchange(@x_response) 
        @reply_to    = "client.tmp.#{::Kernel.rand(999_999_999_999)}" #FIXME
        @in_queue    = @interface.queue(@reply_to, :auto_delete=>true, :exclusive=>true)
        @in_queue.bind(@in_exch, :key => @reply_to) # queue to read reply from    
        @_outgoing     = ''
        @_incoming     = ''
        @response_hash = {}
      end
      
      # perform a RPC request
      #
      def send_request(data)

        outgoing = Blix.to_binary_data(data)
        incoming = nil
        id      = "#{Time.now.to_i}#{rand(9999)}"
        options = {}
        options[:key]          = ""
        options[:reply_to]     = @reply_to
        options[:content_type] = "text/xml"
        options[:message_id]   = id
        
        if $DEBUG
          puts "[request:#{id}]data--------------"
          puts data
          puts "--------------------------" 
        end
        
        @out_exch.publish(data, options )
        @response_hash[id] = nil
        timeout = Time.now
        
        while (!incoming)
          
          if @response_hash[id]
            incoming = @response_hash[id]
            @response_hash.delete id
            break
          end
          
          msg     = @in_queue.pop
          header  = msg[:header]
          payload = msg[:payload]
          
          unless payload == :queue_empty
            message_id = header.message_id
            if message_id == id
              incoming = payload
              @response_hash.delete id
              break
            else
              @response_hash[message_id] = payload if @response_hash.has_key?(message_id)
            end
          end
          raise TimeoutError if (Time.now - timeout) > @timeout
          do_sleep
        end
        #        
        if $DEBUG
          puts "[request:#{id}]response data-----"
          puts incoming
          puts "--------------------------" 
        end
        incoming
      end
      
      def do_sleep
        sleep 0.01
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