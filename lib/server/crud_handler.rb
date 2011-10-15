# the handler must respond to any rpc methods that can be 
# requested from the server. Derive your custom handler
# from Handler and define your custom methods.


module Blix::Server
  module CrudHandlerMethods
    
    # define the respond_to? method to recognise crud methods
    def respond_to?(name, include_private = false)
      method_name = name.to_s
      parts =  method_name.split('_')
      action = nil
      klass = nil
      if (parts.length > 1)
        action =  parts.last.to_sym
        klass =  parts[0..-2].join('_').downcase.to_sym
      end
      is_crud    = action && [:get,:delete,:create,:update,:all].index(action)
      klass_info = klass && valid_klass[klass]
      is_crud    = is_crud && klass_info
      if is_crud
        true
      else
        super
      end
    end
    
    # perform a crud method if applicable
    def method_missing(name,*args)
      # analyse the method name to see if it is in crud format
      # ie resource_action format.
      method_name = name.to_s
      parts =  method_name.split('_')
      action = nil
      klass = nil
      if (parts.length > 1)
        action =  parts.last.to_sym
        klass =  parts[0..-2].join('_').downcase.to_sym
      end
      is_crud    = action && [:get,:delete,:create,:update,:all].index(action)
      klass_info = klass && valid_klass[klass]
      is_crud    = is_crud && klass_info
      if is_crud
        
        klass = klass_info[0]
        case action
          when :all
          #raise ParseException, klass_info.join(',') unless klass_info.index(:all)
          klass.all
          
          when :get
          
          key = args[0]
          #raise ParseException unless klass_info.index(:get) FIXME
          if key 
            klass.get(key ) rescue raise( ParseException,"id:#{key} not found")
          else
            raise ParseException, "no valid key was supplied"
          end
          
          when :delete
          #raise ParseException unless klass_info.index(:delete) FIXME
          key = args[0]
          if key
            local_item = klass.get(key )  rescue raise( ParseException,"id:#{key} not found")
          else
            raise ParseException, "no valid key was supplied"
          end
          
          if local_item.destroy
            true
          else
            raise ParseException, "error deleting item"
          end
          
          
          when :create
          #raise ParseException unless klass_info.index(:create) FIXME
          new_item = args[0]
          raise ParseException, "no valid create item was supplied" unless new_item
          
          if new_item.save
            new_item
          else
            raise ParseException, "error creating item"
          end
          
          when :update
          #raise ParseException unless klass_info.index(:update) FIXME
          new_item = args[0]
          raise ParseException, "no valid update item was supplied" unless new_item
          
          local_item = klass.get(new_item.id)
          assign_attributes(local_item, new_item)
          if local_item.save
            local_item
          else
            raise ParseException, "error updating item"
          end
        end
      else # is_crud
        super
      end
    end #def
    
    def assign_attributes(old,new)
      hash = new.attributes
      hash.delete "updated_at"
      hash.delete "created_at"
      hash.each do |key,value|
        old[key] = value
      end
    end
    
    def self.included(mod)
      # monkey patch ServerMethod to recognise crud methods.
      
    end
    
    
  end
end

module Blix::Server
  class CrudHandler < Handler
    include CrudHandlerMethods
  end
end