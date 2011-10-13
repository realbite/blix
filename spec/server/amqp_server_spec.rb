require 'spec_helper'

module Blix::Server
  
  describe AmqpServer do
    
    describe "create the server" do
      it "should start running with default handler" do
        lambda{
          Thread.new do
            parser = JsonRpcParser.new
            handler = Handler.new
            AmqpServer.start(parser,handler,:host=>$EXCHANGE_HOST)
          end
        }.should_not raise_error
      end
    end
    
    describe "simple client calls" do
      before(:all) do
        @thread = Thread.new do
          parser = JsonRpcParser.new
          handler = EchoHandler.new
          AmqpServer.start(parser,handler,:host=>$EXCHANGE_HOST)
        end
      end
      
      it "should echo simple value" do
        pending
      end
      
      after(:all) do
        Thread.kill(@thread)
      end
    end
    
  end
  
end