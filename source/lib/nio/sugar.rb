# This file provides some syntactic sugar for the Nio module.
# Some methods here: #to_r(), #to_xr, may collide with methods in other
# libraries.
#
# This non mondule-function is equivalent to +Nio::Fmt.convert+
#   Nio.convert(x, type, arpx=true)
# There's also a module-function synonim useful for including the Nio namespace:
#   Nio.nio_convert(x, type, aprx=true)
# (the convert() method seems too likely for name collisions)
# Some aliases for nio_write and nio_read:
#   fmt << x      ->  x.nio_write(fmt)
#   fmt.write(x)  ->  x.nio_write(fmt)
#   Fmt << x      ->  x.nio_write()
#   Fmt.write(x)  ->  x.nio_write()
#   fmt >> [cls,txt] -> cls.nio_read(txt, fmt)
#   fmt.read(cls,txt) -> cls.nio_read(txt, fmt)
#   Fmt >> [cls,txt] -> cls.nio_read(txt)
#   Fmt.read(cls,txt) -> cls.nio_read(txt)
# Also methods #to_r and #to_xr are added to Float,BigDecimal, etc. as
# synonims for #nio_r, #nio_xr

require 'nio/rtnlzr'
require 'nio/fmt'

# This is not a module function: this provides a shorthand access to Nio::Fmt.convert
def Nio.convert(x, type, mode=:approx)
  Nio::Fmt.convert x, type, mode
end

module Nio
  module_function
  # This module function can be used after <tt>import Nio</tt>
  def nio_convert(x, type, mode=:approx)
    Nio::Fmt.convert x, type, mode
  end
  # :stopdoc:
  class Fmt
    def <<(x)
      x.nio_write(self)
    end
    def write(x)
      x.nio_write(self)
    end
    def Fmt.<<(x)
      x.nio_write
    end
    def Fmt.write(x)
      x.nio_write
    end
    def >>(cls_txt)
      cls,txt = cls_txt
      cls.nio_read(txt,self)
    end
    def read(cls,txt)
      cls.nio_read(txt,self)
    end
    def Fmt.>>(cls_txt)
      cls,txt = cls_txt
      cls.nio_read(txt)
    end
    def Fmt.read(cls,txt)
      cls.nio_read(txt)
    end
  end
  # :startdoc:
end

# to be considered: for cls in [Float,BigDecimal,Integer,Rational]
# def cls.<<(txt_fmt); txt,fmt=txt_fmt; cls.nio_read(txt,fmt); end
