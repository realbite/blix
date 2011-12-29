require 'spec_helper'
require 'core/make_json'
require 'core/json_rpc_parser2'

class TestStorage
  attr_accessor :name, :value, :id
  #make_json :one, :two, :id
  
  def self.get(id)
    
  end
  
  def to_json(*a)
    {:_type=>"store", :id=>id, :name=>name, :value=>value}.to_json(*a)
  end
end

class TestNotStorage
  attr_accessor :one, :two, :three
  make_json :one, :two
  
  def to_json(*a)
    {:_type=>"no_store",  :name=>name, :value=>value}.to_json(*a)
  end
end

module Blix
  
  describe JsonRpcParser2 do
    
    before (:all) do
      @parser = JsonRpcParser2.new
      @parser.valid_klass[:store] = ValidKlass.new(:store,TestStorage,:id,:name,:value)
      @parser.valid_klass[:no_store] = ValidKlass.new(:no_store,TestNotStorage,:name,:value)
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
      
      it "should do a round trip format/parse" do
        message = RequestMessage.new
        message.method = "mymethod"
        message.parameters = {:name=>"betty",:age=>43}
        message.id = 523
        data1    = @parser.format_request(message)
        message2 = @parser.parse_request(data1)
        data2    = @parser.format_request(message2)
        data2.should == data1
      end
    end # parse request
    
    describe "errors" do
      
      it "should format the error message" do
        error = ResponseMessage.new
        error.set_error
        error.id          = 123
        error.code        = 999
        error.description = "bad error"
        result = @parser.format_response(error)
        ck = Crack::JSON.parse result
        ck.should == {"id"=>123, "jsonrpc"=>"2.0", "error"=>{"code"=>999, "message"=>"bad error"}}
      end
      
      it "should parse error data" do
        data = %Q/{"id":123, "jsonrpc":"2.0", "error":{"code":999, "message":"bad error"}}/
        response = @parser.parse_response(data)
        response.should be_error
        response.id.should == 123
        response.code.should == 999
        response.description.should == "bad error"
      end
      
      it "should do a round trip format/parse" do
        message = ResponseMessage.new
        message.set_error
        message.code = 666
        message.description = "my error"
        message.id = 523
        data1    = @parser.format_response(message)
        message2 = @parser.parse_response(data1)
        message2.should be_error
        data2    = @parser.format_response(message2)
        data2.should == data1
      end
    end
    
    describe "notifications" do
      # notification is the same as a request but has no id member.
      it "should format the notification" do
        message = NotificationMessage.new
        message.signal = "hello"
        message.value = 567
        result = @parser.format_notification(message)
        ck = Crack::JSON.parse result
        ck.should == {"method"=>"hello", "params"=>{"item"=>567}, "jsonrpc"=>"2.0"}
      end
      
      it "should do a round trip format/parse" do
        message = NotificationMessage.new
        message.signal = "hello"
        message.value = 12345
        data1    = @parser.format_notification(message)
        message2 = @parser.parse_notification(data1)
        data2    = @parser.format_notification(message2)
        data2.should == data1
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
      
      it "should do a round trip format/parse" do
        message = ResponseMessage.new
        message.value = 333
        message.method = "calculate"
        message.id = 523
        data1    = @parser.format_response(message)
        message2 = @parser.parse_response(data1)
        message2.should_not be_error
        data2    = @parser.format_response(message2)
        data2.should == data1
      end
    end
    
    
    
    describe "convert simple classes to json" do
      
      
      it "should convert a storage class" do
        o = TestStorage.new
        o.name = nil
        o.value = 333
        o.id = 999
        json = {:item=>o}.to_json
        ck = Crack::JSON.parse json
        ck.should == {"item"=>{"_type"=>"store","name"=>nil, "id"=>999, "value"=>333}}
        item=@parser.convert_to_class(ck["item"])
        puts item.inspect
        json2 = {:item=>item}.to_json
        json2.should == json
      end
    end
    
  end
end