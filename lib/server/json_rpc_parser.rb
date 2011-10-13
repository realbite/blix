require 'crack'
require 'json'

module Blix
  module Server
    
    # this is a handler to parse and format json rpc messages.
    class JsonRpcParser < Parser
      
      # setup the json converter with the valid classes
      def initialize
        super
        @converter = Blix::Conversion::JsonConverter.new(valid_klass)
      end
      
      # the json converter object
      def json_converter
        @converter
      end
      
      # decode the message into request message format. Convert all objects to objects 
      # that are recognised on the server.
      
      def parse_request(json)
        begin
          ck = Crack::JSON.parse json
        rescue Crack::ParseError
          raise ParseError
        end
        
        obj = RequestMessage.new
        obj.data        = json
        obj.method      = ck["method"]
        parameters      = ck["params"]
        obj.id          = ck["id"]
        
        raise ParseError,"method missing" unless obj.method
        raise ParseError,"id missing"     unless obj.id
        
        myparameters = {}
        # convert any compound parameter values to local
        # classes if possible.
        parameters && parameters.each do |key,value|
          if value.kind_of? Hash
            myparameters[key.to_sym] = json_converter.convert_to_class value
          elsif value.kind_of? Array
            myparameters[key.to_sym] = json_converter.convert_to_class value
          else
            myparameters[key.to_sym] = json_converter.convert_to_class value
          end
        end
        obj.parameters = myparameters
        obj
      end
      
      # format a response message into data
      def format_response(message)
        {"jsonrpc"=>"2.0", "result"=>message.value, "id"=>message.id }.to_blix_json
      end
      
      # format an error message into  a json-rpc string
      def format_error(message)
        error={"code"=>message.code, "message"=>message.description}
        {"jsonrpc"=>"2.0", "error"=>error, "id"=>@id }.to_json
      end
      
      # format a notification into a json-rpc string
      def format_notification(signal,value)
        if value.kind_of? Hash
          hash = value
        else
          hash = {:item=>value}
        end
        {"jsonrpc"=>"2.0", "method"=>signal, "params"=>hash }.to_blix_json
      end
      
      #
      #
      #
      
      def something
        begin
          @message=Message::Request.parse(message)
        rescue Exception=>e
          dump
          @message=nil
        end
        response = Message::Response.new
        
        if @message
          # handle message with custom handler if available
          if @service && @service.respond_to?( @message.method_name.to_sym )
            begin
              # convert the parameters to arguments
              args = ServerMethod.as_args @message.method_name, @message.parameters
              response.data = @service.send @message.method_name.to_sym, *args
            rescue Exception=>e
              dump
              response = Message::Error.new
              response.id = @message.id
              response.code = 200
              response.description = e.to_s
            end
            # otherwise try to handle with standard crud  
          elsif @message.crud?
            begin
              response.data = @message.crud_execute
            rescue Exception=>e
              dump
              response = Message::Error.new
              response.id = @message.id
              response.code = 400
              response.description = e.to_s
            end
            # otherwise we cannot handle this message  
          elsif @message.method_name == "echo"
            v = @message.parameters[:item]
            puts "[echo] #{v}(#{v.class})"
            response.data = v
            #puts "... #{response.to_message}"
          else
            response = Message::Error.new
            response.id = @message.id
            response.code = 400
            response.description = "invalid method call:#{@message.method_name}" 
          end
        else
          e = Message::Error.new
          e.id = nil
          e.code = 100
          e.description = "invalid message formatting"
          e.method = "not defined"
          return e # no message
        end
        response.method = @message.method_name
        response.id     = @message.id
        response
      end
      
            
      def crud_execute
        raise ParseException unless crud?
        raise ParseException unless klass_info = VALID_KLASS[@klass]
        
        #------------------------------------------------
        # dataMapper has its own way for CRUD operations
        if defined? DataMapper
          case action
            when :all
            #raise ParseException, klass_info.join(',') unless klass_info.index(:all)
            klass_info[0].all
            when :get
            #raise ParseException unless klass_info.index(:get) FIXME
            if key = parameters[:id]
              klass_info[0].get(key ) rescue raise( ParseException,"id:#{key} not found")
            elsif key = parameters[:code]
              klass_info[0].first(:code=>key ) rescue raise( ParseException,"code:#{key} not found") 
            elsif key = parameters[:name]
              klass_info[0].first(:name=>key ) rescue raise( ParseException ,"name:#{key} not found") 
            else
              raise ParseException, "no valid key was supplied"
            end
            
            when :delete
            #raise ParseException unless klass_info.index(:delete) FIXME
            if key = parameters[:id]
              local_item = klass_info[0].get(key )  rescue raise( ParseException,"id:#{key} not found")
            elsif key = parameters[:code]
              local_item = klass_info[0].first(:code=>key ) rescue( raise ParseException,"code:#{key} not found") 
            elsif key = parameters[:name]
              local_item = klass_info[0].first(:name=>key ) rescue raise( ParseException ,"name:#{key} not found") 
            else
              raise ParseException, "no valid key was supplied"
            end
            updated_list = local_item.containers #FIXME
            if local_item.destroy
              Server.notify(Blix::Signal::ITEM_DELETE,local_item) 
              updated_list.each do  |o|
                o.reload
                Server.notify(Blix::Signal::ITEM_UPDATE,o) 
              end
            else
              raise ParseException, "error deleting item"
            end
            
            
            when :create
            #raise ParseException unless klass_info.index(:create) FIXME
            if  new_item = parameters[:create_item]
            else
              raise ParseException, "no valid create item was supplied"
            end
            if new_item.save
              Server.notify(Blix::Signal::ITEM_CREATE,new_item) 
              new_item
            else
              raise ParseException, "error creating item"
            end
            when :update
            #raise ParseException unless klass_info.index(:update) FIXME
            if
              new_item = parameters[:update_item]
            else
              raise ParseException, "no valid update item was supplied"
            end
            local_item = klass_info[0].get(new_item.id)
            local_item.assign_attributes new_item.attributes
            if local_item.save
              Server.notify(Blix::Signal::ITEM_UPDATE,local_item) 
              local_item
            else
              raise ParseException, "error updating item"
            end
          else
            raise ParseException
          end
          #-----------------------------------------------  
          # and ActiveRecord has its own way of course....  
        else
          case action
            when :all
            #raise ParseException, klass_info.join(',') unless klass_info.index(:all)
            klass_info[0].all
            when :get
            #raise ParseException unless klass_info.index(:get) FIXME
            if key = parameters[:id]
              klass_info[0].find(key ) rescue raise( ParseException,"id:#{key} not found")
            elsif key = parameters[:code]
              klass_info[0].find_by_code(key ) rescue raise( ParseException,"code:#{key} not found") 
            elsif key = parameters[:name]
              klass_info[0].find_by_name(key ) rescue raise( ParseException ,"name:#{key} not found") 
            else
              raise ParseException, "no valid key was supplied"
            end
            
            when :delete
            #raise ParseException unless klass_info.index(:delete) FIXME
            if key = parameters[:id]
              local_item = klass_info[0].find(key ) rescue raise( ParseException,"id:#{key} not found")
            elsif key = parameters[:code]
              local_item = klass_info[0].find_by_code(key ) rescue( raise ParseException,"code:#{key} not found") 
            elsif key = parameters[:name]
              local_item = klass_info[0].find_by_name(key ) rescue raise( ParseException ,"name:#{key} not found") 
            else
              raise ParseException, "no valid key was supplied"
            end
            updated_list = local_item.containers
            local_item.destroy
            Server.notify(Blix::Signal::ITEM_DELETE,local_item) 
            updated_list.each do  |o|
              o.reload
              Server.notify(Blix::Signal::ITEM_UPDATE,o) 
            end
            true
            
            when :create
            #raise ParseException unless klass_info.index(:create) FIXME
            if
              new_item = parameters[:create_item]
            else
              raise ParseException, "no valid create item was supplied"
            end
            new_item.save!
            new_item.reload # get id
            Server.notify(Blix::Signal::ITEM_CREATE,new_item) 
            new_item
            
            when :update
            #raise ParseException unless klass_info.index(:update) FIXME
            if
              new_item = parameters[:update_item]
            else
              raise ParseException, "no valid update item was supplied"
            end
            local_item = klass_info[0].find(new_item.id)
            local_item.assign_attributes new_item.attributes
            local_item.save!
            Server.notify(Blix::Signal::ITEM_UPDATE,local_item) 
            local_item
          else
            raise ParseException
          end
        end
      end
      
      # send a notification
      #      def notify(signal,value)
      #        return unless @handler
      #        if value.kind_of? Hash
      #          @handler.notify(signal,value)
      #        else
      #          @handler.notify(signal,{:item=>value})
      #        end
      #      end
      
    end #Handler
    
  end #Server
end #Blix
