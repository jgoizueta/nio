
#require File.dirname(__FILE__) + '/test_helper.rb'
require 'test/unit'

require 'nio/repdec'
include Nio
require 'yaml'


class SEclass
  include StateEquivalent
  def initialize(a,b)
    @a = a
    @b = b
  end
end


class TestTools < Test::Unit::TestCase

  def setup
    
  end

  
  def test_StateEquivalent
    x = SEclass.new(11,22)
    y = SEclass.new(11,22)
    z = SEclass.new(11,23)
    xx = x
    assert_equal(true,x==xx)
    assert_equal(true,x==y)
    assert_equal(false,x==z)
    assert_equal(x.hash,xx.hash)
    assert_equal(x.hash,y.hash)
    assert_equal(false,x.hash==z.hash)
  end
   
end
 