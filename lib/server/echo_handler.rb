
module Blix::Server
  module EchoHandlerMethods
    def echo(val)
      puts "echo #{val.inspect}" if $DEBUG
      val
    end
    
    def self.included(mod)
      Blix::ServerMethod.new(:echo,:item)
    end
  end
end

module Blix::Server
  class EchoHandler < Handler
    include EchoHandlerMethods
  end
end