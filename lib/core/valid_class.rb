module Blix
  
  
  # store details here about valid classes and the default methods that can be used on them.
  # members can be added thus:
  #
  # VALID_KLASS[:area] = [Area,:all]
  #
  # where the first element of the array is the Class to instantiate. The following
  # elements are the valid methods which may be used via this interface.
  class VALID_KLASS
    def self.[](name)
      list[name.to_sym]
    end
    
    def self.[]=(name,value)
      list[name.to_sym] = value
    end
    
    def self.list
      @list ||= {}
    end
  end
  
end