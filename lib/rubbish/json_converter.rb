require 'bigdecimal'

module Blix
    class JsonConverter
      
      def initialize(klasses=nil)
        @valid_klasses = klasses
      end
      
      # valid klasses define mappings between attribute names in the json
      # and actual Ruby classes to instantiate
      def valid_klasses
        @valid_klasses
      end
      
      def convert_to_class( hash)
        if hash.kind_of? Hash
          
          klass   = singular hash.keys.first # the name of the class
          values  = hash.values.first
          
          if klass == 'value'
            klass_info = [String]
          elsif klass=='datetime'
            klass_info = [Time]
          elsif klass=='date'
            klass_info = [Date]
          elsif klass=='base64Binary'
            klass_info = [String]
          elsif klass=='decimal'
            klass_info = [BigDecimal]
          elsif klass[-3,3] == "_id" # aggregation class
            klass = klass[0..-4]
            raise ParseException,"#{klass} is not Valid!" unless klass_info = valid_klasses[klass.downcase.to_sym]
            puts "aggregation #{klass}: id:#{values}(#{values.class})" if $DEBUG
            id    = values
            return  defined?( DataMapper) ? klass_info[0].get(id) : klass_info[0].find(id)
          else
            raise ParseException,"#{klass} is not Valid!" unless klass_info = valid_klasses[klass.downcase.to_sym]
          end
          
          if values.kind_of? Array
            values.map do |av|
              if false #av.kind_of? Hash
                convert_to_class(av)
              else
                convert_to_class({klass=>av})
                # values.map{ |av| convert_to_class({klass=>av})}
              end
              # 
            end
          elsif values.kind_of? Hash
            if ((defined? ActiveRecord) && ( klass_info[0].superclass == ActiveRecord::Base )) ||
             ((defined? DataMapper) && ( klass_info[0].included_modules.index( DataMapper::Resource) ))
              myclass = klass_info[0].new
              puts "[convert] class=#{myclass.class.name}, values=#{values.inspect}" if $DEBUG
            else
              myclass = klass_info[0].allocate
            end
            values.each do |k,v|
              method = "#{k.downcase}=".to_sym
              # we will trust the server and accept that values are valid
              c_val = convert_to_class(v)
              if myclass.respond_to? method
                # first try to assign the value via a method
                myclass.send method, c_val
              else
                # otherwise set an instance with this value
                attr = "@#{k.downcase}".to_sym
                myclass.instance_variable_set attr, c_val
              end
            end
            # rationalize this value if neccessary
            myclass = myclass.blix_rationalize if myclass.respond_to? :blix_rationalize
            myclass
          elsif  values.kind_of? NilClass
            nil
          else
            if klass=='datetime'
              values # crack converts the time!
            elsif klass=='date'
              #Date.parse(values)
              values # crack converts the date!
            elsif klass=="base64Binary"
              Base64.decode64(values)
            elsif klass=="decimal"
              BigDecimal.new(values)
            else
              from_binary_data values
            end
            #raise ParseException, "inner values has class=#{values.class.name}\n#{values.inspect}" # inner value must be either a Hash or an array of Hashes
          end
        elsif hash.kind_of? Array
          hash.map{|i| convert_to_class(i)}
        else
          hash
        end
      end
      
      # convert plural class names to singular... if there are class names that end in 's'
      # then we will have to code in an exception for this class.
      def singular(txt)
        parts =  txt.split('_')
        
        if (parts.length>1) && (parts[-1]=="array")
          return parts[0..-2].join('_')
        end
        
        return txt[0..-2] if txt[-1].chr == 's'
        txt
      end
      
      def array?(txt)
       (parts.length>1) && (parts[-1]=="array")
      end
  end
end

