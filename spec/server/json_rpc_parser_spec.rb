require 'spec_helper'

module Blix::Server
  
  describe JsonRpcParser do
    
    before (:all) do
      @parser = JsonRpcParser.new
    end
    
    describe "requests" do
      
      it "should parse a message with no parameters" do
        data = %Q/{"jsonrpc": "2.0", "method": "subtract", "params": [], "id": 123}/
        request = @parser.parse_request(data)
        request.method.should == "subtract"
        request.parameters.should == {}
        request.id.should == 123
        request.data.should == data
      end
      
      it "should raise exception if invalid json" do
        data = %Q/{{rubbish/
        lambda{@parser.parse_request(data)}.should raise_error ParseError
      end
      
      it "should raise exception if method missing" do
        data = %Q/{"jsonrpc": "2.0",  "params": [], "id": 123}/
        lambda{@parser.parse_request(data)}.should raise_error ParseError
      end
      
      it "should raise exception if id missing" do
        data = %Q/{"jsonrpc": "2.0", "method": "subtract", "params": []}/
        lambda{@parser.parse_request(data)}.should raise_error ParseError
      end
      
      it "should parse a message with some parameters" do
        data = %Q/{"jsonrpc": "2.0", "method": "subtract", "params": {"subtrahend": 23, "minuend": 42}, "id": 3}/
        request = @parser.parse_request(data)
        request.method.should == "subtract"
        request.parameters.should == {:subtrahend=>23,:minuend=> 42}
        request.id.should == 3
        request.data.should == data
      end
    end # parse request
    
    describe "errors" do
      
      it "should format the error message" do
        error = ErrorMessage.new
        error.id          = 123
        error.code        = 999
        error.description = "bad error"
        result = @parser.format_error(error)
        ck = Crack::JSON.parse result
        ck.should == {"id"=>nil, "jsonrpc"=>"2.0", "error"=>{"code"=>999, "message"=>"bad error"}}
      end
    end
    
    describe "notifications" do
      # notification is the same as a request but has no id member.
      it "should format the notification" do
        signal = "hello"
        value  = 567
        result = @parser.format_notification(signal,value)
        ck = Crack::JSON.parse result
        ck.should == {"method"=>"hello", "params"=>{"item"=>567}, "jsonrpc"=>"2.0"}
      end
    end
    
    describe "results" do
      
      it "should parse a simple result" do
        response = ResponseMessage.new
        response.id = 765
        response.value = 333
        response.method = "calculate"
        result = @parser.format_response(response)
        ck = Crack::JSON.parse result
        ck.should == {"id"=>765, "jsonrpc"=>"2.0", "result"=>333}
      end
    end
    
  end
end