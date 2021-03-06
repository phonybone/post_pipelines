class Integer
  # print self in comma-separated format (eg 32,344)
  def to_s_nice(sep=',')
    return to_s if self.abs < 10000;
    n=self<0 ? -self : self
    t=Array.new
    d=n/1000
    while n>1000
      d=n/1000
      r=n%1000
      barf=sprintf "%03d",r
      t<<barf
      n=d
    end
    t<<d.to_s
    str=self<0? '-':''
    str+=t.reverse.join(sep)
  end

end

class Numeric
  def percent_of(other,format="%.2f%%")
    sprintf format, self.to_f/other.to_f*100.0
  end
end

puts "#{__FILE__} checking in"
