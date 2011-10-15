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
  
end #Blix
