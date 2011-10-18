# convert method call arguments to and from 
# hash arguments as defined here.
# CA 12/07/2010
module Blix
  
  class Handler
    
  end
  
  class ServerMethod
    
    attr_accessor :parameters
    attr_accessor :crud_methods
    
    CRUD_METHODS = [:all, :get, :create, :update, :delete]
    
    def ServerMethod.list
      @list ||= {}
    end
    
    def ServerMethod.clear
      @list = {}
    end
    
    # check to see if this method has been registered. If the name is a crud method then
    # check to see if this has been registered.
    def ServerMethod.find(name)
      id = name.to_sym
      item = list[id]
      if item
        item.parameters
        # check for crud format
      else
        method_name = name.to_s
        parts =  method_name.split('_')
        action = nil
        klass = nil
        if (parts.length > 1)
          action =  parts.last.to_sym
          klass =  parts[0..-2].join('_').downcase.to_sym
        end
        is_crud    = klass && action && CRUD_METHODS.index(action)
        if is_crud
          item = list["%_#{klass}".to_sym]
          if item && item.crud_methods.index(action)
            case action
              when :all
                item.parameters
              when :get
                item.parameters + [:id] 
              when :create
                item.parameters + [:item]
              when :update
                item.parameters + [:item]
              when :delete
                item.parameters + [:id] 
              else
                item.parameters
            end
          else
            raise ArgumentError, "method:#{name} not defined as ServerMethod"
          end
        else
          raise ArgumentError, "method:#{name} not defined as ServerMethod"
        end
      end
    end
    
    # register a resource to allow certain crud methods.
    def self.crud(resource,*args)
      id = "%_#{resource}".to_sym
      list = []
      raise ArgumentError, "missing CRUD method(s) " unless args.length > 0
      args.each do |a|
        raise ArgumentError,"invalid CRUD method" unless CRUD_METHODS.index(a.to_sym)
        list << a.to_sym
      end
      o = new(id)
      o.crud_methods = list
      o
    end
    
    def initialize(method,*args)
      name = method.to_sym
      @parameters = args
      @crud_methods = []
      ServerMethod.list[name] = self
    end
    
    def ServerMethod.as_hash(name,*args)
      parameters = find(name)
      if args.length > parameters.length
        raise ArgumentError, "too many arguments for method:#{name} - #{args.length} for #{parameters.length}"
      end
      hash = {}
      args.each_with_index do |p,i|
        hash[parameters[i]] = p
      end
      hash
    end
    
    def ServerMethod.as_args(name,hash={})
      parameters = find(name)
      args = []
      parameters.each_with_index do |id,i|
        args[i] = hash[id] if  hash[id]
      end
      args
    end
    
    def to_s
      str = "(#{parameters.join(',')})"
    end
    
  end
  
  
end # Blix

class Module
  # if there is a simple relationship between the server call and a call on a class then
  # we can use this shortcut.
  # within the ServiceHandler Class ...
  #
  # server_method_forward :server_method_name, :class_name_to_call, :method_name_to_call, {map_from=>map_to,....}
  #
  # where :server_method_name is the name of the method at the server interface eg: :cash_drawer_open
  #       :class_name_to_call is the name of the internal Class and this must be defined as a VALID_CLASS
  #       :method_name_to_call is the internal method name
  #       mappings will convert an id type parameter into a class object by doing 'find' on the class.
  #            eg: {user_id => :user} will convert the parameter user_id into a User object. the 'from'
  #            name must also be registered as a VALID_KLASS.
  #
  def server_method_forward( name, klass_name, method, mappings={})
    raise ArgumentError,"#{klass_name} is not registered as a VALID_KLASS!!" unless klass_info = Blix::VALID_KLASS[klass_name]
    klass = klass_info[0]
    info = Blix::ServerMethod.find name 
    map_string = ""
    find_method = defined?( DataMapper) ? 'get' : 'find' 
    mappings.each do |from,to|
      idx = info.parameters.index from
      raise ArgumentError,"method #{name} does not have a parameter: #{from}" unless idx
      raise ArgumentError,"#{to} is not registered as a VALID_KLASS!!" unless klass_info = Blix::VALID_KLASS[to]
      str = <<-EOF
         args[#{idx}] = #{klass_info[0]}.#{find_method} args[#{idx}]
         raise ArgumentError,"#{klass_info[0]} not found id=\#{args[#{idx}]}" unless args[#{idx}]
      EOF
      map_string << str
    end
    str= <<-EOF
        def #{name}(*args)
          item = #{klass}.#{find_method} args[0]
          raise ArgumentError,"#{name} not found id=\#{args[0]}" unless item
          #{map_string}
          item.#{method}( *args[1..-1] )        
        end
    EOF
    module_eval str
  end
end
