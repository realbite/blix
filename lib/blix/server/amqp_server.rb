require 'amqp'
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
    class AmqpServer < BaseServer
      
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
        @_prefix    = opts[:prefix]   || 'std'
        @host       = opts[:host]     || 'localhost'
        @x_response = opts[:response] || (@_prefix + '.responses')
        @x_request  = opts[:request]  || (@_prefix + '.requests')
        @x_notify   = opts[:notify]   || (@_prefix + '.notify')
        @server_q   = "server.#{@_prefix}.requests"
        @notify_queue = Queue.new
      end
      
      # enter a loop just listening for requests and passing them on to the
      # handler and returning the response if there is one.
      def listen2
        
        EM.run do
          AMQP.connect(:host => @host) do |connection |
            puts "Connected to AMQP broker. Running #{AMQP::VERSION} version of the gem..."
            channel  = AMQP::Channel.new(connection)
            exchange = channel.direct(@x_request)
            reply    = channel.direct(@x_response)
            queue    = channel.queue(@server_q)
            notify   = channel.fanout(@x_notify)
            
            puts "request xchange =#{@x_request}"
            puts "reply   xchange =#{@x_response}"
            puts "server  queue   =#{@server_q}"
            
            # listen for rpc requests on the server queue
            #
            queue.bind( exchange).subscribe do |header,body|
              
              # extract the headers and create a transport for this
              # client. the reply_to field may be in the application
              # headers field so check for it there also.
              
              reply_to   = header.reply_to   || ( header.headers && header.headers[:reply_to])
              message_id = header.message_id || ( header.headers && header.headers[:message_id])
              
              if reply_to && message_id
                # process the call
                response              = do_handle(body)
                
                # publish the reply only if there is a response
                
                if response
                  options = {}
                  options[:key]        = reply_to
                  options[:message_id] = message_id
                  data                 = Blix.to_binary_data(response)
                  
                  puts "[AmqpServer] response: data=#{data}, options=#{options}" if $DEBUG
                  
                  reply.publish(data, options )
                end
              else
                puts "missing reply-to /message_id  field ....."
                pp header
              end
            end #subscribe
            
            # send any notifications that are waiting.
            while !@notify_queue.empty?
              message = @notify_queue.pop
              channel.fanout(@x_notify).publish(Blix.to_binary_data(message))
              puts "[AmqpServer] notify: message=#{msg}" if $DEBUG
            end
          end #connection
        end # EM
        
      end 
      
      # enter a loop just listening for requests and passing them on to the
      # handler and returning the response if there is one.
      def listen(&block)
        AMQP.start(:host => @host) do
          exchange = MQ.direct(@x_request)
          reply    = MQ.direct(@x_response)
          queue    = MQ.queue(@server_q)
          notify   = MQ.fanout(@x_notify)
          
          puts "request xchange =#{@x_request}"
          puts "reply   xchange =#{@x_response}"
          puts "server  queue   =#{@server_q}"
          
          @do_notify = proc do |msg|
            notify.publish(Blix.to_binary_data(msg))
            puts "[AmqpServer] notify: message=#{msg}" if $DEBUG
          end
          
          queue.bind( exchange).subscribe do |header,body|
            
            # extract the headers and create a transport for this
            # client. the reply_to field may be in the application
            # headers field so check for it there also.
            
            reply_to   = header.reply_to   || ( header.headers && header.headers[:reply_to])
            message_id = header.message_id || ( header.headers && header.headers[:message_id])
            
            if reply_to && message_id
              # process the call
              response              = block && block.call(body)
              
              # publish the reply only if there is a response
              
              if response
                options = {}
                options[:key]        = reply_to
                options[:message_id] = message_id
                data                 = Blix.to_binary_data(response)
                
                puts "[AmqpServer] response: data=#{data}, options=#{options}" if $DEBUG
                
                reply.publish(data, options )
              end
            else
              puts "missing reply-to /message_id  field .....#{header.inspect}"
            end
          end
          
#          # send any notifications that are waiting.
#          while !@notify_queue.empty?
#            message = @notify_queue.pop
#            channel.fanout(@x_notify).publish(Blix.to_binary_data(message))
#            puts "[AmqpServer] notify: message=#{msg}" if $DEBUG
#          end
        end
        
      end 
      
      # send a raw message to the notification exchange
      def send_notification(msg)
        EM.next_tick do
          @do_notify.call(msg)
        end
      end
      
      # send a raw message to the notification exchange
      def send_notification2(msg)
        raise "please start server first before notify !!" unless @x_notify
        puts "[AmqpServer] notify: message=#{msg}" if $DEBUG
        MQ.fanout(@x_notify).publish(Blix.to_binary_data(msg))
      end
    end #AmqpServer
  end
end #Blix
