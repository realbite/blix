######################################################################################
#
# this extension ensures that there is only one version of an object class with
# the given key attribute
#
#
#  C. Andrews 30/6/2009
#
######################################################################################
include ObjectSpace

class Module
  
  def rationalize_attr(attr)
    @_lookup_store={}
    
    str = %Q{
        
           def self.key
             "#{attr}".to_sym
           end
           
           def self.key_attribute
             "@#{attr}".to_sym
           end
        }   
    
    
    class << self
      alias_method         :old_new , :new
      include RationalizeClassMethods
    end
    private_class_method :old_new
    module_eval (str)
    include RationalizeMethods
  end
  
  
  def forward_rationalize
    
    #    str = <<-EODEF
    #       
    #      def rationalize
    #    
    #         instance_variables.each do |v|
    #             value = instance_variable_get(v.to_sym)
    #             if value.respond_to?(:rationalize)
    #                 self.instance_variable_set(v.to_sym,value.send(:rationalize) )
    #             end
    #         end 
    #         self
    #      end
    #         
    #  EODEF
    #    #module_eval (str)
    include ForwardRationalizeMethods
  end
  
end #class module

module RationalizeClassMethods
  
  
  def new(*args)
    obj = old_new(*args) 
    id =  obj.instance_variable_get(key_attribute)
    raise "please set #{key} in initialize" unless id
    result = @_lookup_store[id] 
    if result
      return result
      raise "#{key}:#{id} already exists"
    else
      result = obj
      @_lookup_store[id] = result
    end
    result
  end
  
  def [](id)
    if obj = @_lookup_store[id]
      obj
    else
      each_object(self) do |obj|
        found_id = obj.instance_variable_get(key_attribute)
        if found_id == id
          @_lookup_store[id]=obj
          return obj
        end
      end
      db_find(id) # look in database here if db_find is overloaded
    end
  end
  
  
  def blix_rationalize(o)
    id = o.instance_variable_get(key_attribute)
    if olditem = self.[](id)
      o.instance_variables.each do |var|
        olditem.instance_variable_set(var.to_sym, o.instance_variable_get(var.to_sym))
      end
      olditem
    else
     (@_lookup_store[id]=o)
    end   
  end    
  
  def blix_unrationalize(o)
    id = o.instance_variable_get(key_attribute)
    @_lookup_store.delete(id)
  end
  
  # look on the server for the value
  def db_find(id)
    return unless id
    classname = GetXML.dasherize self.name
    puts "finding /#{key}=>#{id}(#{id.class.name})/ for #{classname} ( list=/#{self.list.inspect}/)" if $DEBUG
    val = Blix::Client::Connection.instance.request( "#{classname}_get", {key=>id} ) rescue nil
    val.blix_rationalize
  end
  
  def length
    @_lookup_store.length
  end
  
  def items
    @_lookup_store
  end
  
  def list
    @_lookup_store.values
  end  
  
  def find(idx)
    idx && self.[](idx)
  end
  
  def cache_find(idx)
    find(idx)
  end
  
  def inherited(subcls)
    subcls.instance_variable_set(:@_lookup_store,{})
  end  
  
  def raw_new(*args)
    o=old_new(*args)
  end
end

module RationalizeMethods 
  def blix_rationalize
    instance_variables.each do |v|
      value = instance_variable_get(v.to_sym)
      if value.respond_to?(:blix_rationalize)
        self.instance_variable_set(v.to_sym,value.send(:blix_rationalize) )
      end
    end 
    self.class.blix_rationalize(self)
  end
  
  def blix_unrationalize
    self.class.blix_unrationalize(self)
  end
end

module ForwardRationalizeMethods
  def blix_rationalize
    instance_variables.each do |v|
      value = instance_variable_get(v.to_sym)
      if value.respond_to?(:blix_rationalize)
        self.instance_variable_set(v.to_sym,value.send(:blix_rationalize) )
      end
    end 
    self
  end
end

class Array
  def blix_rationalize
    self.each_with_index do |value,idx|
      if value.respond_to?(:blix_rationalize)
        self[idx]= value.send(:blix_rationalize) 
      end
    end
  end
end

class Hash
  def blix_rationalize
    out = self.class.new
    self.each do |key,value|
      if value.respond_to?(:blix_rationalize)
        value = value.send(:blix_rationalize) 
      end
      if key.respond_to?(:blix_rationalize)
        key = key.send(:blix_rationalize) 
      end
      out[key]=value
    end
    out
  end
end

class NilClass
  def blix_rationalize
    nil
  end
end

class TestLookup
  attr_accessor :code, :name
  
  rationalize_attr(:code)
  
  def initialize(code,name)
    @code,@name=code,name
  end
  
end
