require 'rubygems'
require 'crack/json'
require 'core/conversions'
module Blix
  module Server
    module Message
      
      
      #-------------------------------------------------------------------------------
      # represent a request message
      #
      class Request 
        
        attr_reader    :method_name, :action, :klass
        attr_accessor  :parameters,  :json, :id
        
        # create a new request object my parsing json.
        def self.parse(json)
          
          begin
            ck = Crack::JSON.parse json
          rescue
            raise ParseException
          end
          
          obj = Request.new
          obj.method_name = ck["method"]
          parameters      = ck["params"]
          obj.id          = ck["id"]
          
          raise ParseException,"method missing" unless obj.method_name
          raise ParseException,"id missing"     unless obj.id
          
          myparameters = {}
          # convert any compond parameter values to local
          # classes if possible.
          parameters && parameters.each do |key,value|
            if value.kind_of? Hash
              myparameters[key.to_sym] = Blix.convert_to_class value
            elsif value.kind_of? Array
              myparameters[key.to_sym] = Blix.convert_to_class value
            else
              myparameters[key.to_sym] = Blix.convert_to_class value
            end
          end
          obj.parameters = myparameters
          obj.json = json
          obj
        end
        
        # methods take the form of 'resource'_'action'.. here we return
        # the action verb.
        def method_name=(name)
          @method_name = name
          if @method_name
            parts =  @method_name.split('_')
            if (parts.length > 1)
              @action =  parts.last.to_sym
              @klass =  parts[0..-2].join('_').downcase.to_sym
            else
              @action = nil
              @klass = nil
            end
          end
        end
        
        # normal CRUD methods have an action of :get, :create, :update
        # or :delete.  identify if this method is a CRUD method
        def crud?
          @action && [:get,:delete,:create,:update,:all].index( @action)
        end
        
        # perform the CRUD operation
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
              if
                new_item = parameters[:create_item]
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
        
        def raw
          @json
        end
        
        def to_message
          to_json
        end     
      end
      
      #-------------------------------------------------------------------------------
      # represent a Response message
      class Response
        attr_accessor :data, :method, :id
        
        def to_json(*a)
          {"jsonrpc"=>"2.0", "result"=>@data, "id"=>@id }.to_blix_json
        end
        
        def to_message
          to_json
        end
        
      end
      
      #-------------------------------------------------------------------------------
      # represent an Error message
      class Error
        attr_accessor :code, :description, :method, :id
        
        def to_json(*a)
          error={"code"=>@code, "message"=>@description}
          {"jsonrpc"=>"2.0", "error"=>error, "id"=>@id }.to_json(*a)
        end
        
        def to_message
          to_json
        end
        
      end
      
      #-------------------------------------------------------------------------------
      # represent a Notification message
      class Notification
        def initialize( signal,*args)
          @signal = signal
          @args = args
        end
        
        def to_json(*a)
          {"jsonrpc"=>"2.0", "method"=>@signal, "params"=>@args[0] }.to_blix_json
        end
        
        def to_message
          to_json
        end
        
        def send
          Server.send_notification(to_json)
        end
      end
    end
    
  end
end #Blix

if defined? DataMapper
  module DataMapper
    module Resource
      
      def assign_attributes(hash)
        hash.delete "updated_at"
        hash.delete "created_at"
        hash.each do |key,value|
          self[key] = value
        end
      end
      
      def containers
        arr=[]
        self.class.relationships.each do |name,type|
          if type.kind_of?( DataMapper::Associations::ManyToOne::Relationship)
            val = self.send(name)
            arr << val if val
          end
        end
        arr.flatten
      end
    end
  end
end

if defined? ActiveRecord
  class ActiveRecord::Base
    def assign_attributes(hash)
      hash.delete "updated_at"
      hash.delete "created_at"
      hash.each do |key,value|
        self[key] = value
      end
    end
    
    def containers
      arr=[]
      self.class.reflect_on_all_associations.each do |assoc|
        if assoc.macro.to_s =~/belongs/
          val = self.send(assoc.name)
          arr << val if val
        end
      end
      arr.flatten
    end
  end
end
