require 'spec_helper.rb'


# the rationalize helpers ensure that there is only one copy
# of an object in memory at a given time.An Object is identified
# by its id property.
module Blix
  
  class Foo
     attr_accessor :id, :name, :alias  ,:foo
     rationalize_attr :id
  end
    
  class Bar
    attr_accessor :id, :name, :alias 
  end
  
  class Forward
    attr_accessor :id, :name, :alias  ,:foo
    
    forward_rationalize
  end
  
  describe "rationalize" do
    
    before(:each) do
      Foo.items.clear
    end
    
    it "should not rationalize object with no id " do
      f = Foo.new
      f.name = "aaa"
      f.alias = "bbb"
      lambda{f.blix_rationalize}.should_not raise_error
      Foo.length.should == 0
    end
    
    it "should rationalize object with  id " do
      f = Foo.new
      f.name = "aaa"
      f.alias = "bbb"
      f.id = 123
      lambda{f.blix_rationalize}.should_not raise_error
      Foo.length.should == 1
      Foo.find(123).should == f
      Foo.find(123).object_id.should == f.object_id
    end
    
    it "should overwrite memory values if same id is rationalized" do
      f = Foo.new
      f.name = "aaa"
      f.alias = "bbb"
      f.id = 123
      f.blix_rationalize
      
      g = Foo.new
      g.name = "cccc"
      g.alias = "dddd"
      g.id = 123
      
      obj = g.blix_rationalize
      Foo.length.should == 1
      h = Foo.find(123)
      h.object_id.should == f.object_id
      h.name.should == "cccc"
      h.alias.should == "dddd"
      obj.object_id.should == f.object_id
    end
    
    it "should not do anything for a normal object" do
      f = Bar.new
      f.name = "aaa"
      f.alias = "bbb"
      f.id = 123
      lambda{f.blix_rationalize}.should raise_error
      
      lambda{Bar.list}.should raise_error
    end
    
    
    
    it "should forward the rationalize methods if specified" do
      level3 = Foo.new
      level3.name = "333"
      level3.alias = "three"
      level3.id = 333

      level2 = Foo.new
      level2.name = "222"
      level2.alias = "two"
      level2.id = 222
      
      level1 = Forward.new
      level1.foo = level2
      level1.name = "111"
      level1.alias = "one"
      level1.id = 111
      
      level1.blix_rationalize
      Foo.length.should == 1
      
      
      level2b = Foo.new
      level2b.name = "is"
      level2b.alias = "two"
      level2b.id = 222
      
      level1b = Forward.new
      level1b.foo = level2
      level1b.name = "new"
      level1b.alias = "one"
      level1b.id = 111
      
      level1b.blix_rationalize
      Foo.length.should == 1
      
      #Foo.find(111).name.should == "new"
      #Foo.find(111).object_id.should == level1.object_id
      Foo.find(222).name.should == "222"
      Foo.find(222).object_id.should == level2.object_id
      
      level1c = Forward.new
      level1c.foo = level3
      level1c.name = "xxx"
      level1c.alias = "yyy"
      level1c.id = 111
      
      level1c.blix_rationalize
      Foo.length.should == 2
      
      Foo.find(333).name.should == "333"
      Foo.find(333).object_id.should == level3.object_id
      
    end
  end
end