module Blix
  
  
  # store details here about valid classes and the default methods that can be used on them.
  # members can be added thus:
  #
  #  list = ValidKlassList.new
  #  list << ValidKlass.new(:foo, Foo, :one, :two)
  #
  
  
  
  class ValidKlassList
    def [](name)
      list[name.to_sym]
    end
    
    def []=(name,value)
      list[name.to_sym] = value
    end
    
    # add a valid klass to the list
    def <<(value)
      raise ArgumentError unless value.kind_of?(ValidKlass)
      list[value.name] = value
    end
    
    def list
      @list ||= {}
    end
    
    def length
      list.length
    end
  end
  
  class ValidKlass
    attr_reader :name, :klass, :methods, :factory
    
    def name=(val)
      @name = val.to_sym
    end
    
    def initialize(name,klass,*methods,&factory)
      @name = name.to_sym                      # the name in the protocol
      @klass = klass
      @factory = factory                          # generate a new object.
      @methods = methods.map{|i| i.to_sym}
    end
    
    def methods?
      @methods && (@methods.length > 0)
    end
    
    
  end
  
end