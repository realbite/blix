module Blix
  def Blix.dump(item)
    puts "[Blix::dump] class=#{item.class}/#{item}"
    item.instance_variables.each do |v|
      next if v.to_sym == "@rec".to_sym
      newval=item.instance_variable_get(v.to_sym)
      puts "[dump] #{item.class} #{v}/ #{newval.class} / #{newval.to_s}"
    end
  end
end