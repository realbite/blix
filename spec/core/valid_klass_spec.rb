require 'spec_helper.rb'

module Blix
  
  class Foo; end
    
  describe ValidKlass do
    
    it "should be created with no methods" do
      v = nil
      lambda{ v = ValidKlass.new(:foo, Foo) }.should_not raise_error
      v.name.should == :foo
      v.klass.should == Foo
      v.methods.should == []
    end
    
    it "should be created with methods" do
      v = ValidKlass.new(:foo, Foo, :one, :two)
      v.name.should == :foo
      v.klass.should == Foo
      v.methods.should == [:one,:two]
    end
    
    it "should convert names and methods to symbols" do
      v = ValidKlass.new("foo", Foo, "one", "two")
      v.name.should == :foo
      v.klass.should == Foo
      v.methods.should == [:one,:two]
    end
  end
  
  describe ValidKlassList do
    
    before (:each) do
      @list = ValidKlassList.new
    end
    
    it "should be empty" do
      @list.length.should == 0
    end
    
    it "should insert a klass" do
      @list << ValidKlass.new(:foo, Foo, :one, :two)
      @list.length.should == 1
      @list[:foo].klass.should == Foo
    end
    
    it "should accept multiple classes" do
      @list << ValidKlass.new(:string, String, :one, :two)
      @list << ValidKlass.new(:integer, Integer, :one, :two)
      @list << ValidKlass.new(:float, Float, :one, :two)
      @list.length.should == 3
    end
  end
end