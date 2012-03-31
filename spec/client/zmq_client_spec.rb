require 'spec_helper'
require 'blix/json_rpc_parser'
require 'server/zmq_server'
require 'client/zmq_connection'

module Blix::Client
  
  describe ZmqConnection do
    
    before(:each) do
      @connection = ZmqConnection.create(Blix::JsonRpcParser.new)
    end
    
    after(:each) do
      ZmqConnection.close
    end
    
    describe "create the client" do
      it "should start running with default handler" do
        ZmqConnection.instance.should_not == nil
#        lambda{
#          parser = Blix::JsonRpcParser.new
#          ZmqConnection.create(parser)
#        }.should_not raise_error
#        ZmqConnection.close
      end
    end
    
    it "should share the instance between the connection and its superclass" do
      ZmqConnection.instance.should == Connection.instance
      ZmqConnection.instance.should == @connection
      Connection.instance.should == @connection
    end
    
    it "should timeout" do
      t = Time.now
      lambda{ZmqConnection.instance.send_request("request here")}.should raise_error TimeoutError
      diff = Time.now - t
      diff.should > 10
    end
    
  end
  
end