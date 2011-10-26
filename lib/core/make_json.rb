require "base64"
require 'date'
require 'time'
require 'bigdecimal'
require 'flt'
require 'json'
#
# convert ruby objects to json by defining the attributes to be converted.b There must be an
# method defined on the class for each of the attributes.
#
# eg:
#
# class User
#    make_json :id, :name, :number
# end
#
# here the User class must have methods 'id', 'name' and 'number' defined to allow 
# make_json access to the relevant values. The json element will be named after the attribute.
#
# (c) C. Andrews  13/07/2010
# 
# version 0.7
# version 0.8  23/7/2010 ( add json functionality)
# version 0.9.1  26/7/2010 (merge versions and change names)

class Module
  
  def make_json(*args)
    @_xml_readers = args
    include MakeJsonMethods
    extend  MakeJsonClassMethods
  end
  
  def blix_readers
    @_xml_readers
  end
  
  def convert_id_to_klass(name,attr,klass)
    name  = name.to_s
    attr  = attr.to_s #GetXML.dasherize(klass.name)
    ext   = name.sub( attr + '_', '')
    str = %Q{
        def #{name}=(val)
          @#{attr} = val && #{klass}.find(val)
        end
        def #{name}
          @#{attr}  && @#{attr}.#{ext}
        end
      }
    module_eval str
  end
end

# use to indicate that string should be encoded as base64
class BinaryData < String
  def to_json(*a)
    "{\"base64Binary\":\"#{Base64.encode64(self)}\"}"
  end
end 

class String
  def quote
    '"' + self + '"'
  end 
  
  def to_json(*a)
    quote
  end
end

class Time
  def to_json(*a)
    {"datetime"=>self.xmlschema}.to_json(*a)
  end
end

class Date
  def to_json(*a)
    {"date"=>self.to_s}.to_json(*a)
  end
end

class BigDecimal
  def to_json(*a)
    {"decimal"=>self.to_s}.to_json(*a)
  end
end

class ObjectLinkId
  
  def initialize(klass,val)
    @id   = val
    @name = Blix.dasherize(klass.name) + "_id"
  end
  
  def to_json(*a)
    {@name=>@id}.to_json(*a)
  end
  
  def to_i
    @id
  end
  
  def inspect
    "#{to_i}"
  end
  
  def to_s
    inspect
  end
end


class Hash
  def to_blix_json
    str = "{ "
    sep = ""
    self.each do |key,value|
      str = str + sep + key.to_s.quote + ":"
      sep  = " ,"
      if value.kind_of? Array
        str = str + "["
        inner_json = value.map do |x|
          if x.class.blix_readers 
            x.values_to_json
          else
            x.to_json
          end
          end.join(',')
          str = str + inner_json  + "]"
        elsif value.kind_of? Hash
          str += value.to_blix_json
        elsif value.class.blix_readers 
          str += value.values_to_json
        else
          str += value.to_json
        end
      end
      str +=" }"
    end
  end #Hash
  
  
  module MakeJsonMethods
    
    # generate xml depending on the class of the value
    def MakeJsonMethods.generate_by_class(builder,name,value, show_tag=true)
      if (value.kind_of? BigDecimal) || (value.kind_of? DecNum)
        builder.tag! name, value.to_s, :type=>"decimal"
      elsif value.kind_of? Integer
        builder.tag! name, value.to_s, :type=>"integer"
      elsif value.kind_of? Float
        builder.tag! name, value.to_s, :type=>"float"
      elsif value.kind_of? BinaryData
        builder.tag!( name, :type=>"base64Binary"){
          builder << Base64.encode64(value)
        }
      elsif value.kind_of? String
        builder.tag! name, value
      elsif value.kind_of? FalseClass
        builder.tag! name, "false", :type=>"boolean"
      elsif value.kind_of?  TrueClass
        builder.tag! name, "true", :type=>"boolean"
      elsif value.kind_of?  Time
        builder.tag! name,value.utc, :type=>"datetime"
      elsif value.kind_of?  Date
        builder.tag! name,value.to_s, :type=>"date"  
      elsif value.kind_of? Array
        builder.tag! name  do #,:type=>"array"  do
          value.get_xml(builder)
        end
      elsif value.kind_of? NilClass
        builder.tag! name, "", :nil=>"true"
      else
        if show_tag
          builder.tag! name do
            value.get_xml(builder)
          end
        else
          value.get_xml(builder)
        end
      end
    end
    
    
    # this gets included in classes that define get_xml
    #    def get_xml(builder=nil)
    #      
    #      mybuilder =  builder || Builder::XmlMarkup.new(:indent =>2)
    #      mybuilder.instruct! unless builder
    #      
    #      mybuilder.tag! name = GetXML::dasherize(self.class.name) do
    #        type=nil
    #        self.class.blix_readers.each do |name|
    #          value = self.send name.to_sym
    #          GetXML.generate_by_class(mybuilder,name,value)
    #        end
    #      end
    #    end
    
    # use this for top level objects and for non persistent
    # objects.
    def values_to_json(*a)
      hash = {}
      self.class.blix_readers.each do |name|
        value = self.send name.to_sym
        hash[name.to_s]= Blix.from_binary_data value
      end
      spec = {Blix.dasherize(self.class.name)=>hash}
      spec.to_json(*a)
    end
    
    def to_json(*a)
      is_persistent_object = self.class.blix_readers.include? :id
      if (is_persistent_object )
        # just pass the reference id of the object
        blix_id = ObjectLinkId.new(self.class,id) 
        blix_id.to_json(*a)
      else
        # print out all the values of the object
        values_to_json(*a)
      end
    end
    
  end
  
  module MakeJsonClassMethods
    
    def self.json_create(values)
      obj = new
      self.class.blix_readers.each do |name|
        obj.send "#{name}=", values[name]
      end
    end

  end #module
