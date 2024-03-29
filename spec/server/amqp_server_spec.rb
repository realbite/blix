require 'spec_helper'
require 'core/json_rpc_parser'
require ''
module Blix::Server
  
  describe AmqpServer do
    
#    describe "create the server" do
#      it "should start running with default handler" do
#        lambda{
#          Thread.new do
#            parser = Blix::JsonRpcParser.new
#            handler = Handler.new
#            AmqpServer.create(parser,handler,:host=>$EXCHANGE_HOST)
#            AmqpServer.start
#          end
#        }.should_not raise_error
#      end
#    end
    
    describe "simple client calls" do
      before(:all) do
        @thread = Thread.new do
          parser = Blix::JsonRpcParser.new
          handler = EchoHandler.new
          AmqpServer.create(parser,handler,:host=>$EXCHANGE_HOST)
          AmqpServer.start
        end
      end
      
      it "should echo simple value" do
        parser   = Blix::JsonRpcParser.new
        @server  = Blix::Client::AmqpConnection.create(parser,:host=>$EXCHANGE_HOST)
        @server.echo("hello").should == "hello"
      end
      
      after(:all) do
        Thread.kill(@thread)
      end
    end
    
  end
  
end