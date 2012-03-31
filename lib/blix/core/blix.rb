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
  
  # convert a class name to lowercase format
  def self.dasherize(str)
    str.gsub(/([a-z])([A-Z])/, '\1_\2' ).downcase.split('::')[-1]
  end
  
  
  # 
  def Blix.get_attribute_hash(obj,name,list)
    hash = {:_type=>name}
    list.each do |name|
      hash[name] = Blix.get_instance_var(obj,name)
    end
    hash
  end
  
  # set all instance variables in the object that are in the
  # list using the names in the list and the values in the
  # hash. This sets values directly avoiding the accessor
  # methods.
  def Blix.set_all_instance_vars(obj,list,values)
    list.each do |name|
      Blix.set_instance_var(obj,name,values[name.to_s]) if values.include?(name.to_s)
    end
  end
  
  # get the named instance variable in the object to the given
  # value. Use the accessor if there is one otherwise set the
  # value directly.
  def Blix.get_instance_var(obj,name)
    getter = name.to_sym
    if obj.respond_to? getter
      obj.send(getter)
    else
      obj.instance_variable_get( "@#{name}".to_sym)
    end
  end
  
  # set the named instance variable in the object to the given
  # value. Use the accessor if there is one otherwise set the
  # value directly.
  def Blix.set_instance_var(obj,name,value)
    setter = "#{name}=".to_sym
    if obj.respond_to? setter
      obj.send(setter,value)
    else
      obj.instance_variable_set( "@#{name}".to_sym, value)
    end
  end
  
    
end #Blix
