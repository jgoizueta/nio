# Rationalization of floating point numbers.
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
# Copyright:: Copyright (c) 2002-2004 Javier Goizueta & Joe Horn
# License::   Distributes under the GPL license
#
# This file provides conversion from floating point numbers
# to rational numbers.
# Algorithms by Joe Horn are used.
#
# The rational approximation algorithms are implemented in the class Nio::Rtnlzr
# and there's an interface to the chosen algorithms through:
# * Float#nio_r
# * BigDecimal#nio_r
# There's also exact rationalization implemented in:
# * Float#nio_xr
# * BigDecimal#nio_r


require 'nio/tools'

require 'nio/flttol'

require 'rational'

require 'bigdecimal'


class Float
  # Conversion to Rational preserving the exact value of the number.
  def nio_xr
    return Rational(self.to_i,1) if self.modulo(1)==0
    if !self.finite?
      return Rational(0,0) if self.nan?
      return self<0 ? Rational(-1,0) : Rational(1,0)
    end
    
    f,e = Math.frexp(self)
        
    if e < Float::MIN_EXP
       bits = e+Float::MANT_DIG-Float::MIN_EXP
    else
       bits = [Float::MANT_DIG,e].max  
       #return Rational(self.to_i,1) if bits<e
    end      
      p = Math.ldexp(f,bits)
      e = bits - e
      if e<Float::MAX_EXP
        q = Math.ldexp(1,e)
      else
        q = Float::RADIX**e
      end
    return Rational(p.to_i,q.to_i)
  end
end

class BigDecimal
  # Conversion to Rational preserving the exact value of the number.
  def nio_xr
    s,f,b,e = split
    p = f.to_i
    p = -p if s<0
    e = f.size-e
    if e<0
      p *= b**(-e)
      e = 0
    end
    q = b**(e)
    return Rational(p,q)
  end
end

class Integer
  
  def nio_xr
    return Rational(self,1)
  end
end

class Rational
  
  def nio_xr
    return self
  end
  
  # helper method to return both the numerator and denominator
  def nio_num_den
    return [numerator,denominator]
  end
end


class Float
  # Conversion to Rational. The optional argument must be one of:
  # - a Nio::Tolerance that defines the admisible tolerance;
  #   in that case, the smallest denominator rational within the
  #   tolerance will be found (which may take a long time for
  #   small tolerances.)
  # - an integer that defines a maximum value for the denominator.
  #   in which case, the best approximation with that maximum 
  #   denominator will be returned.
  def nio_r(tol = Nio::Tolerance.big_epsilon)
    case tol
      when Integer
        Rational(*Nio::Rtnlzr.max_denominator(self,tol,Float))
      else
        Rational(*Nio::Rtnlzr.new(Nio::Tol(tol)).rationalize(self))      
    end
  end
end

class BigDecimal
  # Conversion to Rational. The optional argument must be one of:
  # - a Nio::BigTolerance that defines the admisible tolerance;
  #   in that case, the smallest denominator rational within the
  #   tolerance will be found (which may take a long time for
  #   small tolerances.)
  # - an integer that defines a maximum value for the denominator.
  #   in which case, the best approximation with that maximum 
  #   denominator will be returned.
  def nio_r(tol = nil)
    tol ||= BigTolerance.decimals([precs[0],Float::DIG].max,:sig)
    case tol
      when Integer
        Rational(*Nio::Rtnlzr.max_denominator(self,tol,BigDecimal))
      else
        Rational(*Nio::Rtnlzr.new(Nio::BigTol(tol)).rationalize(self))
    end
  end
end

module Nio
  
  
  # This class provides conversion of fractions 
  # (as approximate floating point numbers)
  # to rational numbers.
  class Rtnlzr
    include StateEquivalent

    # Create Rationalizator with given tolerance.
    def initialize(tol=Tolerance.new)
      @tol = tol
    end

    # Rationalization method that finds the fraction with
    # smallest denominator fraction within the tolerance distance
    # of an approximate (floating point) number.
    #
    # It uses the algorithm which has been found most efficient, rationalize_Knuth.
    def rationalize(x)
      rationalize_Knuth(x)
    end
    
    # This algorithm is derived from exercise 39 of 4.5.3 in 
    # "The Art of Computer Programming", by Donald E. Knuth.
    def rationalize_Knuth(x)
      

      num_tol = @tol.kind_of?(Numeric)
      if !num_tol && @tol.zero?(x)
        # num,den = x.nio_xr.nio_num_den
        num,den = 0,1
      else
        negans=false
        if x<0
          negans = true
          x = -x
        end
        dx = num_tol ? @tol : @tol.get_value(x)
        
        
          x = x.nio_xr
          dx = dx.nio_xr
          xp,xq = (x-dx).nio_num_den
          yp,yq = (x+dx).nio_num_den
          
            a = []
            fin,odd = false,false
            while !fin && xp!=0 && yp!=0
              odd = !odd
              xp,xq = xq,xp
              ax = xp.div(xq)
              xp -= ax*xq

              yp,yq = yq,yp
              ay = yp.div(yq)
              yp -= ay*yq

              if ax!=ay
                fin = true
                ax,xp,xq = ay,yp,yq if odd
              end
              a << ax # .to_i
            end
            a[-1] += 1 if xp!=0 && a.size>0
            p,q = 1,0
            (1..a.size).each{|i| p,q=q+p*a[-i],p}
            num,den = q,p
         
        
        num = -num if negans
      end
      return num,den
      
             
    end
    # This is algorithm PDQ2 by Joe Horn.
    def rationalize_Horn(x)
      

      num_tol = @tol.kind_of?(Numeric)
      if !num_tol && @tol.zero?(x)
        # num,den = x.nio_xr.nio_num_den
        num,den = 0,1
      else
        negans=false
        if x<0
          negans = true
          x = -x
        end
        dx = num_tol ? @tol : @tol.get_value(x)
        
        
        z,t = x,dx # renaming

        a,b = t.nio_xr.nio_num_den
        n0,d0 = (n,d = z.nio_xr.nio_num_den)
        cn,x,pn,cd,y,pd,lo,hi,mid,q,r = 1,1,0,0,0,1,0,1,1,0,0
        begin
          q,r = n.divmod(d)
          x = q*cn+pn
          y = q*cd+pd
          pn = cn
          cn = x
          pd = cd
          cd = y
          n,d = d,r
        end until b*(n0*y-d0*x).abs <= a*d0*y
        
        if q>1
          hi = q
          begin
            mid = (lo+hi).div(2)
            x = cn-pn*mid
            y = cd-pd*mid
            if b*(n0*y-d0*x).abs <= a*d0*y
              lo = mid
            else
              hi = mid
            end
          end until hi-lo <= 1 
          x = cn - pn*lo
          y = cd - pd*lo    
        end 
         
        num,den = x,y # renaming
         
        
        num = -num if negans
      end
      return num,den
      
             
    end
    # This is from a RPL program by Tony Hutchins (PDR6).
    def rationalize_HornHutchins(x)
      

      num_tol = @tol.kind_of?(Numeric)
      if !num_tol && @tol.zero?(x)
        # num,den = x.nio_xr.nio_num_den
        num,den = 0,1
      else
        negans=false
        if x<0
          negans = true
          x = -x
        end
        dx = num_tol ? @tol : @tol.get_value(x)
        
        
        z,t = x,dx # renaming

        a,b = t.nio_xr.nio_num_den
        n0,d0 = (n,d = z.nio_xr.nio_num_den)
        cn,x,pn,cd,y,pd,lo,hi,mid,q,r = 1,1,0,0,0,1,0,1,1,0,0
        begin
          q,r = n.divmod(d)
          x = q*cn+pn
          y = q*cd+pd
          pn = cn
          cn = x
          pd = cd
          cd = y
          n,d = d,r
        end until b*(n0*y-d0*x).abs <= a*d0*y
        
        if q>1
          hi = q
          begin
            mid = (lo+hi).div(2)
            x = cn-pn*mid
            y = cd-pd*mid
            if b*(n0*y-d0*x).abs <= a*d0*y
              lo = mid
            else
              hi = mid
            end
          end until hi-lo <= 1 
          x = cn - pn*lo
          y = cd - pd*lo    
        end 
         
        num,den = x,y # renaming
         
        
        num = -num if negans
      end
      return num,den
      
             
    end
  end
  
  # Best fraction given maximum denominator
  # Algorithm Copyright (c) 1991 by Joseph K. Horn.
  #
  # The implementation of this method uses floating point
  # arithmetic which limits the magnitude and precision of the results, specially
  # using Float values.
  def Rtnlzr.max_denominator(f, max_den=1000000000, num_class=nil)
    return nil if max_den<1
    num_class ||= f.class
    return mth.ip(f),1 if mth.fp(f)==0

    one = 1.prec(num_class)
    
      sign = f<0
      f = -f if sign

      a,b,c = 0,1,f
      while b<max_den and c!=0
        cc = one/c
        a,b,c = b, mth.ip(cc)*b+a, mth.fp(cc)
      end

    
      if b>max_den
        b -= a*mth.ceil((b-max_den)/Float(a))
      end
      

      f1,f2 = [a,b].collect{|x| mth.abs(mth.rnd(x*f)/x.prec(num_class)-f)}

      a = f1>f2 ? b : a

      num,den = mth.rnd(a*f).to_i,a
      den = 1 if mth.abs(den)<1
      
      num = -num if sign

    return num,den
  end
  
  class Rtnlzr
    private
    #Auxiliary floating-point functions
    module Mth # :nodoc:
      def self.fp(x)
        # y =x.modulo(1); return x<0 ? -y : y;
        x-ip(x)
      end

      def self.ip(x)
        # x.to_i.to_f
        (x<0 ? x.ceil : x.floor).to_i
      end

      def self.rnd(x)
        #x.round.to_i
        x.round
      end

      def self.abs(x)
        x.abs
      end

      def self.ceil(x)
        x.ceil.to_i
      end    
    end
    def self.mth; Mth; end
  end
  
  module_function
  
end
