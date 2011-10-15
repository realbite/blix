require 'spec_helper'

module Blix
  
  describe ServerMethod do
    
    before(:each) do
      ServerMethod.clear
    end
    
    it "should be not able to add a server method with no name" do
      lambda{ServerMethod.new()}.should raise_error
      lambda{ServerMethod.new(nil)}.should raise_error
    end
    
    it "should be able to add a server method with no parameters" do
      ServerMethod.new(:foo)
      ServerMethod.list.count.should == 1
      ServerMethod.find(:foo).should_not == nil
    end
    
    it "should be able to add a server method with one parameters" do
      ServerMethod.new(:foo, :one)
      ServerMethod.list.count.should == 1
      ServerMethod.find(:foo).should_not == nil
    end
    
    it "should be able to add a server method with several parameters" do
      ServerMethod.new(:foo, :one, :two, :three)
      ServerMethod.list.count.should == 1
      ServerMethod.find(:foo).should_not == nil
    end
    
    it "should convert hashes to arguments" do
      ServerMethod.new(:foo_0)
      ServerMethod.new(:foo_1, :one)
      ServerMethod.new(:foo_3, :one, :two, :three)
      
      ServerMethod.as_args(:foo_0,{}).should == []
      ServerMethod.as_args(:foo_1,{:one=>77}).should == [77]
      ServerMethod.as_args(:foo_3,{:one=>77,:two=>44, :three=>"hello"}).should == [77,44,"hello"]
      ServerMethod.as_args(:foo_3,{:three=>"hello",:one=>77,:two=>44}).should == [77,44,"hello"]
    end
    
    it "should raise error if too few arguments" do
      pending "it may be valid to have optional parameters missing"
      ServerMethod.new(:foo_0)
      ServerMethod.new(:foo_1, :one)
      ServerMethod.new(:foo_3, :one, :two, :three)
      
      lambda{ServerMethod.as_args(:foo_1)}.should raise_error ArgumentError
      lambda{ServerMethod.as_args(:foo_3)}.should raise_error ArgumentError
      lambda{ServerMethod.as_args(:foo_3,:one=>1)}.should raise_error ArgumentError
      lambda{ServerMethod.as_args(:foo_3,:one=>1,:two=>"ww")}.should raise_error ArgumentError
      
    end
    
    it "should be able to register a crud resource" do
      ServerMethod.crud(:user, :all, :get, :delete, :create, :update)
      ServerMethod.list.count.should == 1
      ServerMethod.crud(:guest, :delete, :create, :update)
      ServerMethod.list.count.should == 2
    end
    
    it "should reject invalid or missing crud methods" do
      lambda{ServerMethod.crud(:user, :all, :get, :foo, :create, :update)}.should raise_error ArgumentError
      lambda{ServerMethod.crud(:user)}.should raise_error ArgumentError
      ServerMethod.list.count.should == 0
    end
    
    it "should validate a registered crud method" do
      ServerMethod.crud(:guest, :delete, :create, :update)
      lambda{ServerMethod.find(:guest_all)}.should raise_error
      lambda{ServerMethod.find(:guest_get)}.should raise_error
      lambda{ServerMethod.find(:guest_delete)}.should_not raise_error
      lambda{ServerMethod.find(:guest_create)}.should_not raise_error
      lambda{ServerMethod.find(:guest_update)}.should_not raise_error
      lambda{ServerMethod.find(:guest_xxxx)}.should raise_error
      lambda{ServerMethod.find(:user_create)}.should raise_error
    end
  end
end