# make an json RPC call via amqp. Classes are converted to json usinf the to_json method which must be defined
# for all classes. The response will again be converted into a class using the classname defines in
# VALID_KLASS.
#
#  server calls can be made either via the 'request' method where the parameters are in the form
#  of a hash... or can be made via the method_missing mechanism where the paramters are passed as
#  standard arguments list.
#
#  The ServerMethod class is used to convert method parameters from a standard argument list to a hash. 
#  for this to work the methods must first be registered with this class along with their parameters.
#
#  This class is a Singleton class - only one connection can exist at a time.
# (c) C. Andrews 14/07/2010
#
require 'rubygems'
require 'crack'
require 'bunny'
#require '../core/json_basics'
require 'monitor'
require 'observer'
#require 'rationalize'
#require 'core/signals'
#require 'core/valid_class'
#require 'core/conversions'
module Blix
  
  def self.to_binary_data(data)
    if RUBY_VERSION >= "1.9"
      data.force_encoding("ascii-8bit")
    else
      data
    end
  end
  
  def self.from_binary_data(data)
    if (RUBY_VERSION >= "1.9") && (data.class == String)
      data.force_encoding("utf-8")
    else
      data
    end
  end
  
  
  
  module Client
    
    class Connection < Monitor
      
      include Observable
      
      private_class_method :new
      
      def self.instance
        @_instance
      end
      
      #-----------------------------------------------------------------------------------
      #
      # general crud methods
      #
      #-----------------------------------------------------------------------------------
      def find_all(klass)
        class_name  = GetXML.dasherize(klass.name)
        method_name = "#{class_name}_all"
        request(method_name)
      end
      
      def update_item(new)
        class_name  = GetXML.dasherize(new.class.name)
        method_name = "#{class_name}_update"
        request(method_name, {:update_item=>new})
      end  
      
      def delete_item(old)
        class_name  = GetXML.dasherize(old.class.name)
        method_name = "#{class_name}_delete"
        request(method_name, {:id=>old.id})
      end
      
      def create_item(new)
        class_name  = GetXML.dasherize(new.class.name)
        method_name = "#{class_name}_create"
        request(method_name, {:create_item=>new})
      end
      
      #    def createItemFromHash(klass,hash)
      #      class_name  = GetXML.dasherize(klass.name)
      #      method_name = "#{class_name}_create"
      #      request(method_name, {:create_item=>{class_name=>hash}})
      #    end
      
      def proxy_method(obj,method,*args)
        class_name  = GetXML.dasherize(obj.class.name)
        method_name = "#{class_name}_#{method}"
        args.unshift(obj.id)
        hash = Blix::ServerMethod.as_hash(method_name, *args)
        
        puts "proxy method=>#{method_name}/#{args.inspect}/#{hash.inspect}" if $DEBUG
        request(method_name,hash)
      end
      
      
      
      #-----------------------------------------------------------------------------------
      
      def self.create(opts={})
        raise "Connection already created !!!" if @_instance
        @_instance = new(opts)
      end
      
      def initialize(opts={})
        super()
        @_prefix    = opts[:prefix]   || 'std'
        @host       = opts[:host]     || 'localhost'
        @x_response = opts[:response] || (@_prefix + '.responses')
        @x_request  = opts[:request]  || (@_prefix + '.requests')
        @x_notify   = opts[:notify]   || (@_prefix + '.notify')
        
        
        
        @interface   = Bunny.new(:host=>@host,:logging => false)
        @interface.start
        @out_exch    = @interface.exchange(@x_request) # outgoing exchange for publishing request
        @in_exch     = @interface.exchange(@x_response) 
        @reply_to    = "client.tmp.#{::Kernel.rand(999_999_999_999)}" #FIXME
        @in_queue    = @interface.queue(@reply_to, :auto_delete=>true, :exclusive=>true)
        @in_queue.bind(@in_exch, :key => @reply_to) # queue to read reply from    
        @_outgoing = ''
        @_incoming = ''
        #response_listen
      end 
      
      def method_missing(name,*args)
        begin
          hash = Blix::ServerMethod.as_hash(name, *args)
          request(name,hash)
        rescue ArgumentError
          super
        end
      end
      
      def request(method,parameters={})
        synchronize do
          do_rationalize( do_request(method,parameters) )
        end
      end
      
      def parse_json(json)
        begin
          ck = Crack::JSON.parse json
        rescue
          raise ParseException, json
        end
        raise ParseException, ck unless ck.key? "result"
        raise ParseException, ck unless ck.key? "id"
        obj_hash    = ck["result"]
        Blix.convert_to_class obj_hash
      end
      #-----------------------------------------------------------------------------------
      #  
      #  response listener
      #
      def response_listen
        Thread.new do 
          AMQP.start(:host => @host) do
            response_x    = MQ.direct(@x_response)
            MQ.queue(@reply_to, :auto_delete => true, :exclusive=>true).bind(response_x, :key => @reply_to).subscribe do |header,body|
              message_id = header.message_id || ( header.headers && header.headers[:message_id])
              puts "[response_listen] - received response id=#{message_id}"
              if message_id
                request = Request.find(message_id)
                if request
                  # pass the result on to the main thread
                  request.waiting  = false
                  request.response = Blix.from_binary_data(body)
                else
                  puts "[response_listen] request <#{message_id}> not found in queue !!"
                end
              else
                puts "[response_listen] !!!missing message_id  field ....."
                p    header
              end
            end 
          end 
        end 
      end #def
      
      #-----------------------------------------------------------------------------------
      #  
      #  notifications listener
      #
      
      #retrieve raw amqp notification messages
      def amqp_listen
        @listener      =  "client.#{::Kernel.rand(999_999_999_999)}"
        Thread.new(self) do 
          AMQP.start(:host => @host) do
            notify   = MQ.fanout(@x_notify)
            MQ.queue(@listener, :auto_delete => true).bind(notify).subscribe{ |msg| yield msg }
          end   
        end
      end
      
      # listen for notifications and send out signals from the engine
      def listen
        amqp_listen do |msg|
          
          begin
            ck = Crack::JSON.parse msg
          rescue
            raise ParseException, msg
          end
          
          if $DEBUG
            puts "---------------------------------"
            puts "Client::Connection received message=>#{msg}"
            puts ck.inspect
            puts "---------------------------------"
          end
          
          signal  = ck["method"]
          args    = ck["params"]
          
          case signal
            when Blix::Signal::ITEM_UPDATE
            new = Blix.convert_to_class( args["item"])
            notify(Blix::Signal::ITEM_UPDATE,do_rationalize(new))
            
            when Blix::Signal::ITEM_DELETE
            old = Blix.convert_to_class( args["item"])
            notify(Blix::Signal::ITEM_DELETE,old)
            do_delete(old)
            
            when Blix::Signal::ITEM_CREATE
            new = Blix.convert_to_class( args["item"])
            notify(Blix::Signal::ITEM_CREATE,do_rationalize(new))
          else
            myparameters = {}
            # convert any compond parameter values to local
            # classes if possible.
            if args && (args.kind_of? Hash)
              args.each do |key,value|
                if value.kind_of? Hash
                  myparameters[key.to_sym] = Blix.convert_to_class value
                elsif value.kind_of? Array
                  myparameters[key.to_sym] = Blix.convert_to_class value
                else
                  myparameters[key.to_sym] = Blix.convert_to_class value
                end
              end
            end
            notify(signal,do_rationalize( myparameters ) )
          end
        end
      end
      
      #-----------------------------------------------------------------------------------
      #protected
      
      # inform oberservers of the signal
      def notify(signal,*args)
        details = args.join('/')
        puts "Client::Connection::notify (start) [#{signal}] < #{ details }>" if $DEBUG
        changed
        notify_observers(signal,*args) rescue puts "Client::Connection[notify] #{$!}\n#{$@}"
        puts "Client::Connection::notify (end) [#{signal}] }" if $DEBUG
      end
      
      # for obects with a key value ensure that only one instance of an object with the 
      # given key value exists on the system.
      def do_rationalize(o)
        if o.respond_to? :blix_rationalize
          o.blix_rationalize
        else
          o
        end
      end
      
      # delete the local instance of an object if it is deleted on the server
      #
      def do_delete(o)
        if o.class.respond_to? :blix_unrationalize
          o.blix_unrationalize
        else
          o
        end
      end
      
      
      # perform a RPC request
      #
      def do_request(method,parameters={})
        json = {"jsonrpc"=>"2.0", "method"=>method, "params"=>parameters, "id"=>123 }.to_blix_json
        if $DEBUG
          puts "[request]json--------------"
          puts json
          puts "--------------------------" 
        end
        
        outgoing = Blix.to_binary_data(json)
        options = {}
        req     = Request.new # register this request
        
        options[:key]          = ""
        options[:reply_to]     = @reply_to
        options[:content_type] = "text/xml"
        options[:message_id]   = req.message_id
        @out_exch.publish(outgoing, options )
        
        
        #        while req.waiting do
        #          sleep(0.1 )
        #          puts "waiting #{req.inspect}"
        #        end
        #        
        # wait for the incoming message
        #FIXME timeout
        #incoming = req.response
        #Request.delete( req )
        
        incoming = nil
        while (!incoming)
          msg = @in_queue.pop
          payload = msg[:payload]
          incoming = payload unless payload == :queue_empty
        end
        
        #        
        if $DEBUG
          puts "[request]response json-----"
          puts incoming
          puts "--------------------------" 
        end
        
        # convert the xml to a ruby object
        begin
          parse_json incoming
        rescue
          puts incoming
          raise
        end
      end
      
    end # Connection
  end #Client
end #Blix