class Module
  
  def server_proxy_method(*args)
    args.each do |method|
      str = "def #{method.to_s}(*args) Blix::Client::Connection.instance.proxy_method(self,:#{method.to_s},*args) end"
      class_eval str  
    end
  end
  
  def server_proxy_class_method(*args)
    args.each do |method|
      str = "def self.#{method.to_s}(*args) Blix::Client::Connection.instance.proxy_class_method(self,:#{method.to_s},*args) end"
      class_eval str  
    end
  end
end
