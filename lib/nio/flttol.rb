# Floating point tolerance
#--
# Copyright (C) 2003-2005, Javier Goizueta <javier@goizueta.info>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#++
#
# Author::    Javier Goizueta (mailto:javier@goizueta.info)
# Copyright:: Copyright (c) 2002-2004 Javier Goizueta
# License::   Distributes under the GPL license
#
# This module provides a numeric tolerance class for Float and BigDecimal.

require 'bigdecimal'
require 'bigdecimal/math' if RUBY_VERSION>='1.8.1'
require 'nio/tools'


class Float  
  unless const_defined?(:RADIX) # old Ruby versions didn't have this
    # Base of the Float representation
    RADIX = 2
    
    x = 1.0
    _bits_ = 0
    while 1!=x+1
      _bits_ += 1
      x /= 2
    end
    if ((1.0+2*x)-1.0)>2*x
      _bits_ -= 1
    end
              
    # Number of RADIX-base digits of precision in a Float
    MANT_DIG = _bits_
    # Number of decimal digits that can be stored in a Float and recovered
    DIG = ((MANT_DIG-1)*Math.log(RADIX)/Math.log(10)).floor
    # Smallest value that added to 1.0 produces something different from 1.0
    EPSILON = Math.ldexp(*Math.frexp(1).collect{|e| e.kind_of?(Integer) ? e-(MANT_DIG-1) : e})
  end
  # Decimal precision required to represent a Float and be able to recover its value  
  DECIMAL_DIG = (MANT_DIG*Math.log(RADIX)/Math.log(10)).ceil+1
end

# :stopdoc:
# A problem has been detected with Float#to_i() in some Ruby versiones
# (it has been found in Ruby 1.8.4 compiled for x86_64_linux|)
# This problem makes to_i produce an incorrect sign on some cases.
# Here we try to detect the problem and apply a quick patch,
# although this will slow down the method.
if 4.611686018427388e+018.to_i < 0
  class Float
    alias _to_i to_i
    def to_i
      neg = (self < 0)
      i = _to_i
      i_neg = (i < 0)
      i = -i if neg != i_neg
      i
    end
  end  
end
# :startdoc:


# This module contains some constructor-like module functions
# to help with the creation of tolerances and big-decimals.
#
# =BigDec
#   BigDec(x) -> a BigDecimal
#   BigDec(x,precision) -> a BigDecimal
#   BigDec(x,:exact) -> a BigDecimal
# This is a shortcut to define a BigDecimal without using quotes
# and a general conversion to BigDecimal method. 
#
# The second parameter can be :exact to try for an exact conversion
#
# Conversions from Float have issues that should be understood; :exact
# conversion will use the exact internal value of the Float, and when
# no precision is specified, a value as simple as possible expressed as
# a fraction will be used.
#
# =Tol
#  Tol(x) -> a Tolerance
# This module function will convert its argument to a Noi::Tolerance
# or a Noi::BigTolerance depending on its argument;
#
# Values of type Tolerance,Float,Integer (for Tolerance) or
# BigTolerance,BigDecimal (for BigTolerance) are accepted.
#
# =BigTol
#  BigTol(x) -> a BigTolerance
# This module function will convert its argument to a Noi::BigTolerance
#
# Values of type BigTolerance or Numeric are accepted.
module Nio
  
  # This class represents floating point tolerances for Float numbers
  # and allows comparison within the specified tolerance.
  class Tolerance
    include StateEquivalent
    
    # The numeric class this tolerance applies to.
    def num_class
      Float
    end
    
    # The tolerance mode is either :abs (absolute) :rel (relative) or :sig (significant).
    # The last parameter is a flag to specify decimal mode for the :sig mode
    def initialize(t=0.0, mode=:abs, decmode=false)
      set t, mode, decmode
    end
    
    
    #This initializes a Tolerance with a given number of decimals
    def decimals(d, mode=:abs, rounded=true)
      
      @mode = mode
      @decimal_mode = true
      @d = (d<=0 || d>Float::DIG) ? Float::DIG : d
      @t = 10**(-@d)
      @t *= 0.5 if rounded
      
      self
    end
    
    #This initializes a Tolerance with a number of significant decimal digits
    def sig_decimals(d, rounded=true)
      decimals d, :sig, rounded
    end
    
    #Initialize with a multiple of the internal floating-point precision.
    def epsilon(times_epsilon=1, mode=:sig)
      set Float::EPSILON*times_epsilon, mode
    end
    
    # As #epsilon but using a somewhat bigger (about twice) precision that
    # assures associative multiplication.
    def big_epsilon(n=1, mode=:sig)
      t = Math.ldexp(0.5*n,3-Float::MANT_DIG) # n*(2*Float::EPSILON/(1-0.5*Float::EPSILON)**2)
      set t, mode
    end
    
    # Initialize with a relative fraction
    def fraction(f)
      set f, :rel
    end
    # Initialize with a percentage
    def percent(x)
      fraction x/100.0
    end
    # Initialize with a per-mille value
    def permille(x)
      fraction x/1000.0
    end
    

    #Shortcut notation for get_value
    def [](x)
      return x.nil? ? @t : get_value(x)
    end
    #Return tolerance relative to a magnitude
    def get_value(x)  
      rel(x)
    end
    #Essential equality within tolerance
    def equals?(x,y)
      
      case @mode
        when :sig
          
          if @decimal_mode
            begin
              x_exp = Math.log10(x.abs)
              #x_exp = x_exp.finite? ? x_exp.ceil : 0
              x_exp = x_exp.finite? ? x_exp.floor+1 : 0
            rescue
              x_exp = 0
            end
            begin 
              y_exp = Math.log10(y.abs)
              #y_exp = y_exp.finite? ? y_exp.ceil : 0
              y_exp = y_exp.finite? ? y_exp.floor+1 : 0
            rescue
              y_exp = 0
            end
            (y-x).abs <= @t*(10**([x_exp,y_exp].min-@@dec_ref_exp))
          else
            z,x_exp = Math.frexp(x)
            z,y_exp = Math.frexp(y)
            (y-x).abs <= Math.ldexp(@t,[x_exp,y_exp].min-@@ref_exp) # (y-x).abs <= @t*(2**([x_exp,y_exp].min-@@ref_exp))
          end
          
        when :rel
          
          (y-x).abs <= @t*([x.abs,y.abs].min) #reference value is 1
          
        when :abs
          (x-y).abs<@t
      end
             
    end
    #Approximate equality within tolerance
    def aprx_equals?(x,y)
      
      case @mode
        when :sig
          
          if @decimal_mode
            begin
              x_exp = Math.log10(x.abs)
              #x_exp = x_exp.finite? ? x_exp.ceil : 0
              x_exp = x_exp.finite? ? x_exp.floor+1 : 0
            rescue
              x_exp = 0
            end
            begin 
              y_exp = Math.log10(y.abs)
              #y_exp = y_exp.finite? ? y_exp.ceil : 0
              y_exp = y_exp.finite? ? y_exp.floor+1 : 0
            rescue
              y_exp = 0
            end
            (y-x).abs <= @t*(10**([x_exp,y_exp].max-@@dec_ref_exp))
          else
            z,x_exp = Math.frexp(x)
            z,y_exp = Math.frexp(y)
            (y-x).abs <= Math.ldexp(@t,[x_exp,y_exp].max-@@ref_exp) # (y-x).abs <= @t*(2**([x_exp,y_exp].max-@@ref_exp))
          end
          
        when :rel
          
          (y-x).abs <= @t*([x.abs,y.abs].max) #reference value is 1
          
        when :abs
          (x-y).abs<=@t    
      end
             
    end
    #Comparison within tolerance  
    def greater_than?(x,y)
      less_than?(y,x)
    end
    #Comparison within tolerance  
    def less_than?(x,y)
     
     case @mode
       when :sig
         
         if @decimal_mode
           begin
             x_exp = Math.log10(x.abs)
             #x_exp = x_exp.finite? ? x_exp.ceil : 0
             x_exp = x_exp.finite? ? x_exp.floor+1 : 0
           rescue
             x_exp = 0
           end
           begin 
             y_exp = Math.log10(y.abs)
             #y_exp = y_exp.finite? ? y_exp.ceil : 0
             y_exp = y_exp.finite? ? y_exp.floor+1 : 0
           rescue
             y_exp = 0
           end
           y-x > @t*(10**([x_exp,y_exp].max-@@dec_ref_exp))
         else
           z,x_exp = Math.frexp(x)
           z,y_exp = Math.frexp(y)
           y-x > Math.ldexp(@t,[x_exp,y_exp].max-@@ref_exp) # y-x > @t*(2**([x_exp,y_exp].max-@@ref_exp))
         end
         
       when :rel
         
         y-x > @t*([x.abs,y.abs].max) #reference value is 1
         
       when :abs
         x-y<@t
     end
        
    end
    #Comparison within tolerance  
    def zero?(x,compared_with=nil)
      compared_with.nil? ? x.abs<@t : x.abs<rel(compared_with)
    end

    
    # Returns true if the argument is approximately an integer
    def apprx_i?(x)
      equals?(x,x.round)
    end
    # If the argument is close to an integer it rounds it
    # and returns it as an object of the specified class (by default, Integer)
    def apprx_i(x,result=Integer)
      r = x.round
      return equals?(x,r) ? r.prec(result) : x
    end
      
    
    # Returns the magnitude of the tolerance
    def magnitude
      @t
    end
    # Returns the number of decimal digits of the tolerance
    def num_decimals  
      @d
    end
    # Returns true for decimal-mode tolerance
    def decimal?
      @decimal_mode
    end
    # Returns the mode (:abs, :rel, :sig) of the tolerance
    def mode
      @mode
    end
    
    
    private
    
    def set(t=0.0, mode=:abs, decmode=false)
      
      @t = t==0 ? Float::EPSILON : t.abs
      @t = 0.5 if @t > 0.5
      @mode = mode
      @t = Float::EPSILON if @mode!=:abs && @t<Float::EPSILON
      @decimal_mode = decmode
      @d = @t==0 ? 0 : (-Math.log10(2*@t).floor).to_i
      
      self
    end
    
    @@ref_exp = 1 # Math.frexp(1)[1] => tol. relative to [1,2)
    
    @@dec_ref_exp = 0 # tol. relative to [0.1,1)
    
    def rel(x)
      r = @t
      case @mode
        when :sig
          if @decimal_mode
            d = x==0 ? 0 : (Math.log10(x.abs).floor+1).to_i
            r = @t*(10**(d-@@dec_ref_exp))
          else
            x,exp = Math.frexp(x)
            r = Math.ldexp(@t,exp-@@ref_exp)
          end
        when :rel
          r = @t*x.abs
      end
      r
    end  
    
  end
  
  def Tolerance.decimals(d=0, mode=:abs,rounded=true)
    Tolerance.new.decimals(d,mode,rounded)
  end
  def Tolerance.sig_decimals(d=0, mode=:abs,rounded=true)
    Tolerance.new.sig_decimals(d,rounded)
  end
  def Tolerance.epsilon(n=1, mode=:sig)
    Tolerance.new.epsilon(n, mode)
  end
  def Tolerance.big_epsilon(n=1, mode=:sig)
    Tolerance.new.big_epsilon(n, mode)
  end
  def Tolerance.fraction(f)
    Tolerance.new.fraction(f)
  end
  def Tolerance.percent(p)
    Tolerance.new.percent(p)
  end
  def Tolerance.permille(p)
    Tolerance.new.permille(p)
  end
  
  # This class represents floating point tolerances for BigDecimal numbers
  # and allows comparison within the specified tolerance.
  class BigTolerance
    include StateEquivalent  
    module BgMth # :nodoc:
      extend BigMath if ::RUBY_VERSION>='1.8.1'
    end

    # The numeric class this tolerance applies to.
    def num_class
      BigDecimal
    end

    #The tolerance mode is either :abs (absolute) :rel (relative) or :sig
    def initialize(t=BigDecimal('0'), mode=:abs, decmode=false)
      set t, mode, decmode
    end
    
    
    #This initializes a BigTolerance with a given number of decimals
    def decimals(d, mode=:abs, rounded=true)
      
      @mode = mode
      @decimal_mode = true
      @d = d==0 ? 16 : d
      if rounded
        @t = BigDecimal("0.5E#{-d}") # HALF*(BigDecimal(10)**(-d))
      else
        @t = BigDecimal("1E#{-d}") # BigDecimal(10)**(-d)
      end
      @ref_exp = BigDecimal('0.1').exponent # reference for significative mode: [0.1,1)
      
      self
    end
    
    #This initializes a BigTolerance with a number of significative decimal digits
    def sig_decimals(d, rounded=true)
      decimals d, :sig, rounded
    end
    
    def fraction(f)
      set f, :rel
    end
    def percent(x)
      fraction x*BigDecimal('0.01')
    end
    def permille(x)
      fraction x*BigDecimal('0.001')
    end
    

    #Shortcut notation for get_value
    def [](x)
      return x.nil? ? @t : get_value(x)
    end
    #Return tolerance relative to a magnitude
    def get_value(x)  
      rel(x)
    end
    #Essential equality within tolerance
    def equals?(x,y)
      
      case @mode
        when :sig
          
          x_exp = x.exponent
          y_exp = y.exponent  
          (y-x).abs <= @t*BigDecimal("1E#{[x_exp,y_exp].min-@ref_exp}")
          
        when :rel
          
          (y-x).abs <= @t*([x.abs,y.abs].min) #reference value is 1
          
        when :abs
          (x-y).abs<@t
      end
             
    end
    #Approximate equality within tolerance
    def aprx_equals?(x,y)
      
      case @mode
        when :sig
          
          x_exp = x.exponent
          y_exp = y.exponent  
          (y-x).abs <= @t*BigDecimal("1E#{[x_exp,y_exp].max-@ref_exp}")
          
        when :rel
          
          (y-x).abs <= @t*([x.abs,y.abs].max) #reference value is 1
          
        when :abs
          (x-y).abs<=@t
      end
             
    end
    #Comparison within tolerance
    def greater_than?(x,y)
      less_than?(y,x)
    end
    #Comparison within tolerance
    def less_than?(x,y)
     
     case @mode
       when :sig
         
         x_exp = x.exponent
         y_exp = y.exponent  
         y-x > @t*BigDecimal("1E#{[x_exp,y_exp].max-@ref_exp}")
         
       when :rel
         
         y-x > @t*([x.abs,y.abs].max) #reference value is 1
         
       when :abs
         x-y<@t
     end
        
    end
    #Comparison within tolerance
    def zero?(x,compared_with=nil)
      compared_with.nil? ? x.abs<@t : x.abs<rel(compared_with)
    end

    
    # Returns true if the argument is approximately an integer
    def apprx_i?(x)
      equals?(x,x.round)
    end
    # If the argument is close to an integer it rounds it
    # and returns it as an object of the specified class (by default, Integer)
    def apprx_i(x,result=Integer)
      r = x.round
      return equals?(x,r) ? r.prec(result) : x
    end
      
    
    # Returns the magnitude of the tolerance
    def magnitude
      @t
    end
    # Returns the number of decimal digits of the tolerance
    def num_decimals  
      @d
    end
    # Returns true for decimal-mode tolerance
    def decimal?
      @decimal_mode
    end
    # Returns the mode (:abs, :rel, :sig) of the tolerance
    def mode
      @mode
    end
    
    
    private
    
    HALF = BigDecimal('0.5')
    
    def set(t=BigDecimal('0'), mode=:abs, decmode=false)
      
      @t = t
      @t = HALF if @t > HALF
      raise TypeError,"El valor de tolerancia debe ser de tipo BigDecimal" if @t.class!=BigDecimal
      @mode = mode
      @decimal_mode = decmode
      @d = @t.zero? ? 0 : -(@t*2).exponent+1
      @ref_exp = BigDecimal('1').exponent # reference for significative mode: [1,10)
      
      self
    end
    
    def rel(x)
      r = @t
      case @mode
        when :sig
          d = x==0 ? 0 : x.exponent
          r = @t*BigDecimal("1E#{d-@ref_exp}")
        when :rel
          r = @t*x.abs
      end
      r
    end  
    
  end
  
  def BigTolerance.decimals(d=0, mode=:abs)
    BigTolerance.new.decimals(d,mode)
  end
  def BigTolerance.sig_decimals(d=0, mode=:abs)
    BigTolerance.new.sig_decimals(d)
  end
  def BigTolerance.fraction(f)
    BigTolerance.new.fraction(f)
  end
  def BigTolerance.percent(p)
    BigTolerance.new.percent(p)
  end
  def BigTolerance.permille(p)
    BigTolerance.new.permille(p)
  end
  
  module_function
  
  #  Tol(x) -> a Tolerance
  # This module function will convert its argument to a Noi::Tolerance
  # or a Noi::BigTolerance depending on its argument;
  #
  # Values of type Tolerance,Float,Integer (for Tolerance) or
  # BigTolerance,BigDecimal (for BigTolerance) are accepted.
  def Tol(x) # :doc:
    case x
      when Tolerance
        x
      when BigTolerance
        x
      when BigDecimal
        BigTolerance.new(x)
      when Float
        Tolerance.new(x)
      when Integer
        Tolerance.sig_decimals(x)
      else # e.g. Rational
        x 
    end
  end

  #  BigTol(x) -> a BigTolerance
  # This module function will convert its argument to a Noi::BigTolerance
  #
  # Values of type BigTolerance or Numeric are accepted.
  def BigTol(x) # :doc:
    case x
      when BigTolerance
        x
      when Integer
        BigTolerance.sig_decimals(x)
      when Rational
        x
      else
        BigTolerance.new(BigDec(x))
    end
  end
  
    #   BigDec(x) -> a BigDecimal
    #   BigDec(x,precision) -> a BigDecimal
    #   BigDec(x,:exact) -> a BigDecimal
    # This is a shortcut to define a BigDecimal without using quotes
    # and a general conversion to BigDecimal method. 
    #
    # The second parameter can be :exact to try for an exact conversion
    #
    # Conversions from Float have issues that should be understood; :exact
    # conversion will use the exact internal value of the Float, and when
    # no precision is specified, a value as simple as possible expressed as
    # a fraction will be used.
    def BigDec(x,prec=nil) # :doc:
      if x.respond_to?(:to_str)
        x = BigDecimal(x.to_str, prec||0)
      else
        case x
          when Integer
          x = BigDecimal(x.to_s)
        when Rational
          if prec && prec!=:exact
            x = BigDecimal.new(x.numerator.to_s).div(x.denominator,prec)
          else
            x = BigDecimal.new(x.numerator.to_s)/BigDecimal.new(x.denominator.to_s)
          end
        when BigDecimal
        when Float
          x = nio_float_to_bigdecimal(x,prec)
        end
      end
      x
    end  
  
end
