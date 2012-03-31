require 'spec_helper'
require 'blix/json_rpc_parser'

module Blix::Client
  
  describe AmqpConnection do
    
    describe "create the client" do
      it "should start running with default handler" do
        lambda{
          parser = Blix::JsonRpcParser.new
          AmqpConnection.create(parser,:host=>$EXCHANGE_HOST)
        }.should_not raise_error
      end
    end
    
    it "should share the instance between the connection and its superclass" do
      parser = Blix::JsonRpcParser.new
      connection = AmqpConnection.create(parser,:host=>$EXCHANGE_HOST)
      AmqpConnection.instance.should == Connection.instance
      AmqpConnection.instance.should == connection
      Connection.instance.should == connection
    end
    
    it "should timeout" do
      t = Time.now
      lambda{AmqpConnection.instance.send_request("request here")}.should raise_error TimeoutError
      diff = Time.now - t
      diff.should > 10
    end
    
  end
  
end