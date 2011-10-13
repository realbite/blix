module Blix::Server
  
  class Message
    attr_accessor  :method
    attr_accessor  :id
    
  end
  
  # represent an error message
  #
  
  class ErrorMessage < Message
    attr_accessor :code, :description
  end
  
  # represent a message received by the server
  #
  
  class RequestMessage < Message
    attr_accessor  :data
    attr_accessor  :parameters
  end
  
  # represent a message to be sent as a response from the server
  #
  
  class ResponseMessage < Message
    attr_accessor  :value
  end
  
end