require 'rubygems'
require 'server/server_handler'
require 'amqp'
require 'core/signals'
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
# use the client class like this
#
#  service = AMPQ::REST::Service.new("demipos.requests")
#  drawer = service.resource("cash_drawers")
#  draw = drawer.get( 123 )
#  draw.update
#  draw.destroy
#
#  service.resource("orders") do |r|
#     item = r.resource("items")
#     line = item.get(55 )
#  end
#
# C. Andrews
# 18/06/2010
#
##################################################################################################### 

module Blix
  module Server
    
    
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
    def self.start(service, opts={})
      @_prefix    = opts[:prefix]   || 'std'
      @host       = opts[:host]     || 'localhost'
      @x_response = opts[:response] || (@_prefix + '.responses')
      @x_request  = opts[:request]  || (@_prefix + '.requests')
      @x_notify   = opts[:notify]   || (@_prefix + '.notify')
      @handler    = Handler.new(service)
      @server_q   = "server.#{@_prefix}.requests"
      AMQP.start(:host => @host) do
        exchange = MQ.direct(@x_request)
        reply    = MQ.direct(@x_response)
        queue    = MQ.queue(@server_q)
        notify   = MQ.fanout(@x_notify)
        
        puts "request xchange =#{@x_request}"
        puts "reply   xchange =#{@x_response}"
        puts "server  queue   =#{@server_q}"
        
        queue.bind( exchange).subscribe do |header,body|
          # extract the headers and create a transport for this
          # client. the reply_to field may be in the application
          # headers field so check for it there also.
          start_time = Time.now
          reply_to   = header.reply_to   || ( header.headers && header.headers[:reply_to])
          message_id = header.message_id || ( header.headers && header.headers[:message_id])
          if reply_to && message_id
            # process the call
            response = @handler.process(body)
            duration1             = Time.now - start_time
            # publish the reply
            options = {}
            options[:key]        = reply_to
            options[:message_id] = message_id
            data                 = Blix.to_binary_data(response.to_message)
            duration2             = Time.now - start_time
            puts "@@@@@@@ data=#{data}, options=#{options}" if $DEBUG
            reply.publish(data, options )
            duration3             = Time.now - start_time
            puts "#{Time.now}: [#{response.method}] ( #{reply_to}.#{message_id} ) #{duration1},#{duration2},#{duration3}   seconds"
          else
            puts "missing reply-to /message_id  field ....."
            pp header
          end
        end
      end
      
    end 
    
    # send a notification
    def self.notify(signal,value)
      return unless @handler
      if value.kind_of? Hash
        @handler.notify(signal,value)
      else
        @handler.notify(signal,{:item=>value})
      end
    end
    
    # send a raw message to the notification exchange
    def self.send_notification(msg)
      raise "please start server first before notify !!" unless @x_notify
      MQ.fanout(@x_notify).publish(Blix.to_binary_data(msg))
    end
    
  end #Server
end #Blix
