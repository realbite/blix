require 'crack'
require 'json'

module Blix
  
  # this is a parser to parse and format json rpc messages.
  #
  class JsonRpcParser < AbstractParser
    
    
    def format_request(request)
      {"jsonrpc"=>"2.0", "method"=>request.method, "params"=>request.parameters, "id"=>request.id }.to_blix_json
    end
    
    # decode the message into request message format. Convert all objects to objects 
    # that are recognised on the server.
    #
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
          myparameters[key.to_sym] = convert_to_class value
        elsif value.kind_of? Array
          myparameters[key.to_sym] = convert_to_class value
        else
          myparameters[key.to_sym] = convert_to_class value
        end
      end
      obj.parameters = myparameters
      obj
    end
    
    # format a response message into data
    #
    def format_response(message)
      if message.error?
        error={"code"=>message.code, "message"=>message.description}
        {"jsonrpc"=>"2.0", "error"=>error, "id"=>message.id }.to_json
      else
        {"jsonrpc"=>"2.0", "result"=>message.value, "id"=>message.id }.to_blix_json
      end
    end
    
    # parse response data into a response message
    #
    def parse_response(json)
      begin
        ck = Crack::JSON.parse json
      rescue Crack::ParseError
        raise ParseError
      end
      
      obj = ResponseMessage.new
      obj.data        = json
      obj.id          = ck["id"]
      error           = ck["error"]
      if error
        obj.set_error
        obj.code        = error["code"]
        obj.description = error["message"]
      else
        obj.value       = convert_to_class ck["result"]
      end
      obj
    end
    
    
    # format a notification into a json-rpc string
    def format_notification(message)
      hash = {:item=>message.value}
      {"jsonrpc"=>"2.0", "method"=>message.signal, "params"=>hash }.to_blix_json
    end
    
    # parse notification data
    def parse_notification(json)
      begin
        ck = Crack::JSON.parse json
      rescue Crack::ParseError
        raise ParseError
      end
      
      params    = ck["params"]
      
      obj = NotificationMessage.new
      obj.data        = json
      obj.signal     = ck["method"]
      value   = params && params["item"]
      
      obj.value = convert_to_class value
      obj
    end
    
    def convert_to_class( hash)
      if hash.kind_of? Hash
        
        klass   = singular hash.keys.first # the name of the class
        values  = hash.values.first
        
        if klass == 'value'
          klass_info = [String]
        elsif klass=='datetime'
          klass_info = [Time]
        elsif klass=='date'
          klass_info = [Date]
        elsif klass=='base64Binary'
          klass_info = [String]
        elsif klass=='decimal'
          klass_info = [BigDecimal]
        elsif klass[-3,3] == "_id" # aggregation class
          klass = klass[0..-4]
          raise ParseError,"#{klass} is not Valid!" unless klass_info = valid_klass[klass.downcase.to_sym]
          puts "aggregation #{klass}: id:#{values}(#{values.class})" if $DEBUG
          id    = values
          return  defined?( DataMapper) ? klass_info[0].get(id) : klass_info[0].find(id)
        else
          raise ParseError,"#{klass} is not Valid!" unless klass_info = valid_klass[klass.downcase.to_sym]
        end
        
        if values.kind_of? Array
          values.map do |av|
            if false #av.kind_of? Hash
              convert_to_class(av)
            else
              convert_to_class({klass=>av})
              # values.map{ |av| convert_to_class({klass=>av})}
            end
            # 
          end
        elsif values.kind_of? Hash
          if ((defined? ActiveRecord) && ( klass_info[0].superclass == ActiveRecord::Base )) ||
           ((defined? DataMapper) && ( klass_info[0].included_modules.index( DataMapper::Resource) ))
            myclass = klass_info[0].new
            puts "[convert] class=#{myclass.class.name}, values=#{values.inspect}" if $DEBUG
          else
            myclass = klass_info[0].allocate
          end
          values.each do |k,v|
            method = "#{k.downcase}=".to_sym
            # we will trust the server and accept that values are valid
            c_val = convert_to_class(v)
            if myclass.respond_to? method
              # first try to assign the value via a method
              myclass.send method, c_val
            else
              # otherwise set an instance with this value
              attr = "@#{k.downcase}".to_sym
              myclass.instance_variable_set attr, c_val
            end
          end
          # rationalize this value if neccessary
          myclass = myclass.blix_rationalize if myclass.respond_to? :blix_rationalize
          myclass
        elsif  values.kind_of? NilClass
          nil
        else
          if klass=='datetime'
            values # crack converts the time!
          elsif klass=='date'
            #Date.parse(values)
            values # crack converts the date!
          elsif klass=="base64Binary"
            Base64.decode64(values)
          elsif klass=="decimal"
            BigDecimal.new(values)
          else
            from_binary_data values
          end
          #raise ParseError, "inner values has class=#{values.class.name}\n#{values.inspect}" # inner value must be either a Hash or an array of Hashes
        end
      elsif hash.kind_of? Array
        hash.map{|i| convert_to_class(i)}
      else
        hash
      end
    end
    
    # convert plural class names to singular... if there are class names that end in 's'
    # then we will have to code in an exception for this class.
    def singular(txt)
      parts =  txt.split('_')
      
      if (parts.length>1) && (parts[-1]=="array")
        return parts[0..-2].join('_')
      end
      
      return txt[0..-2] if txt[-1].chr == 's'
      txt
    end
    
    def array?(txt)
     (parts.length>1) && (parts[-1]=="array")
    end
    
    #
    #
    #
    
    #      def something
    #        begin
    #          @message=Message::Request.parse(message)
    #        rescue Exception=>e
    #          dump
    #          @message=nil
    #        end
    #        response = Message::Response.new
    #        
    #        if @message
    #          # handle message with custom handler if available
    #          if @service && @service.respond_to?( @message.method_name.to_sym )
    #            begin
    #              # convert the parameters to arguments
    #              args = ServerMethod.as_args @message.method_name, @message.parameters
    #              response.data = @service.send @message.method_name.to_sym, *args
    #            rescue Exception=>e
    #              dump
    #              response = Message::Error.new
    #              response.id = @message.id
    #              response.code = 200
    #              response.description = e.to_s
    #            end
    #            # otherwise try to handle with standard crud  
    #          elsif @message.crud?
    #            begin
    #              response.data = @message.crud_execute
    #            rescue Exception=>e
    #              dump
    #              response = Message::Error.new
    #              response.id = @message.id
    #              response.code = 400
    #              response.description = e.to_s
    #            end
    #            # otherwise we cannot handle this message  
    #          elsif @message.method_name == "echo"
    #            v = @message.parameters[:item]
    #            puts "[echo] #{v}(#{v.class})"
    #            response.data = v
    #            #puts "... #{response.to_message}"
    #          else
    #            response = Message::Error.new
    #            response.id = @message.id
    #            response.code = 400
    #            response.description = "invalid method call:#{@message.method_name}" 
    #          end
    #        else
    #          e = Message::Error.new
    #          e.id = nil
    #          e.code = 100
    #          e.description = "invalid message formatting"
    #          e.method = "not defined"
    #          return e # no message
    #        end
    #        response.method = @message.method_name
    #        response.id     = @message.id
    #        response
    #      end
    #      
    #      
    #      def crud_execute
    #        raise ParseError unless crud?
    #        raise ParseError unless klass_info = VALID_KLASS[@klass]
    #        
    #        #------------------------------------------------
    #        # dataMapper has its own way for CRUD operations
    #        if defined? DataMapper
    #          case action
    #            when :all
    #            #raise ParseError, klass_info.join(',') unless klass_info.index(:all)
    #            klass_info[0].all
    #            when :get
    #            #raise ParseError unless klass_info.index(:get) FIXME
    #            if key = parameters[:id]
    #              klass_info[0].get(key ) rescue raise( ParseError,"id:#{key} not found")
    #            elsif key = parameters[:code]
    #              klass_info[0].first(:code=>key ) rescue raise( ParseError,"code:#{key} not found") 
    #            elsif key = parameters[:name]
    #              klass_info[0].first(:name=>key ) rescue raise( ParseError ,"name:#{key} not found") 
    #            else
    #              raise ParseError, "no valid key was supplied"
    #            end
    #            
    #            when :delete
    #            #raise ParseError unless klass_info.index(:delete) FIXME
    #            if key = parameters[:id]
    #              local_item = klass_info[0].get(key )  rescue raise( ParseError,"id:#{key} not found")
    #            elsif key = parameters[:code]
    #              local_item = klass_info[0].first(:code=>key ) rescue( raise ParseError,"code:#{key} not found") 
    #            elsif key = parameters[:name]
    #              local_item = klass_info[0].first(:name=>key ) rescue raise( ParseError ,"name:#{key} not found") 
    #            else
    #              raise ParseError, "no valid key was supplied"
    #            end
    #            updated_list = local_item.containers #FIXME
    #            if local_item.destroy
    #              Server.notify(Blix::Signal::ITEM_DELETE,local_item) 
    #              updated_list.each do  |o|
    #                o.reload
    #                Server.notify(Blix::Signal::ITEM_UPDATE,o) 
    #              end
    #            else
    #              raise ParseError, "error deleting item"
    #            end
    #            
    #            
    #            when :create
    #            #raise ParseError unless klass_info.index(:create) FIXME
    #            if  new_item = parameters[:create_item]
    #            else
    #              raise ParseError, "no valid create item was supplied"
    #            end
    #            if new_item.save
    #              Server.notify(Blix::Signal::ITEM_CREATE,new_item) 
    #              new_item
    #            else
    #              raise ParseError, "error creating item"
    #            end
    #            when :update
    #            #raise ParseError unless klass_info.index(:update) FIXME
    #            if
    #              new_item = parameters[:update_item]
    #            else
    #              raise ParseError, "no valid update item was supplied"
    #            end
    #            local_item = klass_info[0].get(new_item.id)
    #            local_item.assign_attributes new_item.attributes
    #            if local_item.save
    #              Server.notify(Blix::Signal::ITEM_UPDATE,local_item) 
    #              local_item
    #            else
    #              raise ParseError, "error updating item"
    #            end
    #          else
    #            raise ParseError
    #          end
    #          #-----------------------------------------------  
    #          # and ActiveRecord has its own way of course....  
    #        else
    #          case action
    #            when :all
    #            #raise ParseError, klass_info.join(',') unless klass_info.index(:all)
    #            klass_info[0].all
    #            when :get
    #            #raise ParseError unless klass_info.index(:get) FIXME
    #            if key = parameters[:id]
    #              klass_info[0].find(key ) rescue raise( ParseError,"id:#{key} not found")
    #            elsif key = parameters[:code]
    #              klass_info[0].find_by_code(key ) rescue raise( ParseError,"code:#{key} not found") 
    #            elsif key = parameters[:name]
    #              klass_info[0].find_by_name(key ) rescue raise( ParseError ,"name:#{key} not found") 
    #            else
    #              raise ParseError, "no valid key was supplied"
    #            end
    #            
    #            when :delete
    #            #raise ParseError unless klass_info.index(:delete) FIXME
    #            if key = parameters[:id]
    #              local_item = klass_info[0].find(key ) rescue raise( ParseError,"id:#{key} not found")
    #            elsif key = parameters[:code]
    #              local_item = klass_info[0].find_by_code(key ) rescue( raise ParseError,"code:#{key} not found") 
    #            elsif key = parameters[:name]
    #              local_item = klass_info[0].find_by_name(key ) rescue raise( ParseError ,"name:#{key} not found") 
    #            else
    #              raise ParseError, "no valid key was supplied"
    #            end
    #            updated_list = local_item.containers
    #            local_item.destroy
    #            Server.notify(Blix::Signal::ITEM_DELETE,local_item) 
    #            updated_list.each do  |o|
    #              o.reload
    #              Server.notify(Blix::Signal::ITEM_UPDATE,o) 
    #            end
    #            true
    #            
    #            when :create
    #            #raise ParseError unless klass_info.index(:create) FIXME
    #            if
    #              new_item = parameters[:create_item]
    #            else
    #              raise ParseError, "no valid create item was supplied"
    #            end
    #            new_item.save!
    #            new_item.reload # get id
    #            Server.notify(Blix::Signal::ITEM_CREATE,new_item) 
    #            new_item
    #            
    #            when :update
    #            #raise ParseError unless klass_info.index(:update) FIXME
    #            if
    #              new_item = parameters[:update_item]
    #            else
    #              raise ParseError, "no valid update item was supplied"
    #            end
    #            local_item = klass_info[0].find(new_item.id)
    #            local_item.assign_attributes new_item.attributes
    #            local_item.save!
    #            Server.notify(Blix::Signal::ITEM_UPDATE,local_item) 
    #            local_item
    #          else
    #            raise ParseError
    #          end
    #        end
    #      end
    #      
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
  
end #Blix
