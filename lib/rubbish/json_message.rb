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
        
        
        def raw
          @json
        end
        
        def to_message
          to_json
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
