require 'crack'
require 'json'

module Blix
  
  # this is a parser to parse and format json rpc messages.
  #
  class JsonRpcParser2 < AbstractParser
    
    
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
    
    def convert_to_class( value)
      # if the value is a hash then this corresponds to a json object.
      # check in the valid classes list for a class that corresponds to 
      # the type.
      if value.kind_of? Hash
        
        _type = value["_type"]
        
        raise ParseError,"object must have _type property!" unless _type
        
        # look up the type in the valid classes and generate an  object
        
        if info=valid_klass[_type]

          # create an object or find an object. depending on whether it
          # is mutable / immutable and/or the id exists.
          
          if info.methods.include? :id
            if _id = hash["id"]
              obj = info.klass.get(_id)
            else
              obj = info.klass.new
            end
          else
            if info.factory
              info.factory.call
            elsif info.klass
              obj = info.klass.allocate
            else
              raise ParseError,"cannot create new #{_type} object"
            end
          end
          
          # convert the values to a hash to be used to initialise
          # the object
          value.each do |k,v| 
            
            next unless info.methods.include? k.to_sym
            
            method = "#{k}=".to_sym
            
            c_val = convert_to_class(v)
            
            if obj.respond_to? method
              # first try to assign the value via a method
              obj.send method, c_val
            else
              # otherwise set an instance with this value
              attr = "@#{k}".to_sym
              obj.instance_variable_set attr, c_val
            end
          end
        else
          raise ParseError,"#{_type} is not listed as Valid!"
        end
      elsif value.kind_of? Array
        value.map{|i| convert_to_class(i)}
      else
        value
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
    
        
    
  end #Handler
  
end #Blix
