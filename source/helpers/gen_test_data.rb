
require 'yaml'
data = []

def add(x)
  data << [x].pack('E').unpack('H*')[0].upcase
end

100.times do
   x = rand   
   x *= rand(1000) if rand<0.5
   x /= rand(1000) if rand<0.5
   x *= rand(9999) if rand<0.5
   x /= rand(9999) if rand<0.5
   x = -x if rand<0.5   
   puts x
   add x if x.finite? and !x.nan?
 end
 add 1.0/3
 add 0.1
 File.open('data.yaml','w') { |out| out << data.to_yaml }
