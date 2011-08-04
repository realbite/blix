# multiplex multiple blocking requests across a single communication channel
#
# C. Andrews 26/8/2010

 module Blix
   
   # store information about a request
   class Request
     attr_accessor :reference, :message_id, :time, :waiting, :response
     
     def Request.queue
       @queue ||= []
     end
     
     def Request.find(id)
       @queue.each{|i| return i if i.message_id == id}
       nil
     end
     
     def Request.delete(obj)
       @queue.delete obj
     end
     
     # create a new request
     def initialize
       @reference  = nil
       @time       = Time.now
       @message_id = "#{@time.to_i}#{rand(9999)}"
       @waiting    = true
       @response   = nil
       Request.queue << self
     end
     
     def delete
       Request.delete(self)
     end
     
     def inspect
       "<Request> id=#{@message_id} waiting=#{@waiting}"
     end
   end
   
 end