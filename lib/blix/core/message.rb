module Blix
  
  # the base class for messages
  #
  class AbstractMessage
    attr_accessor  :method # should be in string format
    attr_accessor  :id     # should be an integer
    attr_accessor  :data   # the raw message data
  end
  
    
  # represent a request message received by the server
  #
  #
  class RequestMessage < AbstractMessage
    attr_accessor  :parameters # should be a hash of named parameters and values.
  end
  
  # represent a message to be sent as a response from the server. This can either
  # be a success response or an error response.
  #
  class ResponseMessage < AbstractMessage
    attr_accessor  :value              # for success
    attr_accessor  :code, :description # for error
    
    def set_error(state=true)
      @error = state
    end
    
    def error?
      !!@error
    end
  end
  
  #
  # represent a notification message received by the server
  #
  #
  class NotificationMessage < AbstractMessage
    attr_accessor  :signal
    attr_accessor  :value  
  end
end