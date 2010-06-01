$: << "." unless $:.include?(".") # for Ruby 1.9.2
require 'test/unit'
require File.dirname(__FILE__) + '/../lib/nio'
require File.dirname(__FILE__) + '/../lib/nio/sugar'
require 'yaml'

module PrepareData

    @@data = []

    def self.add(x)
      @@data << [x].pack('E').unpack('H*')[0].upcase
    end

    def self.init
      unless File.exist?('test/data.yaml')
        100.times do
           x = rand   
           x *= rand(1000) if rand<0.5
           x /= rand(1000) if rand<0.5
           x *= rand(9999) if rand<0.5
           x /= rand(9999) if rand<0.5
           x = -x if rand<0.5   
           #puts x
           add x
         end
         add 1.0/3
         add 0.1
         File.open('test/data.yaml','w') { |out| out << @@data.to_yaml }
       end
    end
end

PrepareData.init

def BigDec(x)
  BigDecimal.new(x.to_s)
end