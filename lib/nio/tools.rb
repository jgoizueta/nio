# Common Utilities

# Copyright (C) 2003-2005, Javier Goizueta <javier@goizueta.info>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.


#require 'rubygems'



module Nio
  
  module StateEquivalent
    def ==(obj); test_equal(obj); end
    def eql?(obj); test_equal(obj); end
    def ===(obj); test_equal(obj); end
    def hash
      h = 0
      self.instance_variables.each do |var|
        v = self.instance_eval var.to_s
        h ^= v.hash unless v.nil?
      end
      h
    end

    private
    def test_equal(obj)
      return false unless self.class == obj.class
      (self.instance_variables + obj.instance_variables).uniq.each do |var|
        v1 = self.instance_eval var.to_s
        v2 = obj.instance_eval var.to_s
        return false unless v1 == v2
      end
      true
    end
  end
  
  module_function
  
end
