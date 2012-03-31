require 'spec_helper'
require 'core/json_rpc_parser'
require 'server/zmq_server'
require 'client/zmq_connection'
module Blix::Server
  
  describe ZmqServer do
    
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
          ZmqServer.create(parser,handler)
          ZmqServer.start
        end
      end
      
      it "should echo simple value" do
        parser   = Blix::JsonRpcParser.new
        @server  = Blix::Client::ZmqConnection.create(parser)
        @server.echo("hello").should == "hello"
      end
      
      after(:all) do
        puts "killing all threads"
        Thread.kill(@thread)
      end
    end
    
  end
  
end