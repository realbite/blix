require 'spec_helper'
require 'core/json_rpc_parser'


module Blix::Server
  
  describe DummyServer do
    
#    describe "create the server" do
#      it "should start running with default handler" do
#        lambda{
#          Thread.new do
#            parser = Blix::JsonRpcParser.new
#            handler = EchoHandler.new
#            DummyServer.create(parser,handler)
#            DummyServer.start
#          end
#        }.should_not raise_error
#      end
#    end
    
    describe "simple client calls" do
      before(:all) do
        @thread = Thread.new do
          parser = Blix::JsonRpcParser.new
          handler = Handler.new
            DummyServer.create(parser,handler)
            DummyServer.start
        end
      end
      
      
      it "should echo simple value" do
        parser   = Blix::JsonRpcParser.new
        @server  = Blix::Client::DummyConnection.create(parser)
        @server.echo("hello").should == "hello"
      end
      
      
      after(:all) do
        Thread.kill(@thread)
      end
    end
    
  end
  
end