require 'spec_helper'

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

    
  end
  
end