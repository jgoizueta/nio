% rntlzr.w -- Conversion of float point to rational numbers
%
% Copyright (C) 2003-2005, Javier Goizueta <javier@@goizueta.info>
%
% This program is free software; you can redistribute it and/or
% modify it under the terms of the GNU General Public License
% as published by the Free Software Foundation; either version 2
% of the License, or (at your option) any later version.

% ===========================================================================
\documentclass[a4paper,oneside,english]{article}
\usepackage[english,charter]{nwprog}
% ===========================================================================


% ===========================================================================
%\input{nwprogen.tex}
% ===========================================================================

\isodate

\newcommand{\ProgTitle}{Rationalizer}
\newcommand{\ProgAuth}{Javier Goizueta}
\newcommand{\ProgDate}{\today}
\newcommand{\ProgVer}{1.0}
\newcommand{\ProgSource}{\ttfamily\bfseries rtnlzr.w}

\title{\ProgTitle}
\author{\ProgAuth}
\date{\ProgDate}

% ===========================================================================
\newcommand{\rtitle}[1]{``{#1}''\newline}
\newcommand{\rauthor}[1]{{#1}\newline}
\newcommand{\rurl}[2][]{#1{\tt #2}\newline}
\newcommand{\rlocal}[1]{local file: {\tt #1}\newline}
\newcommand{\rsubtitle}[1]{{#1}\newline}
\newcommand{\rpub}[1]{{#1}\newline} %published
\newcommand{\red}[1]{{#1}\newline} %editor/edited by
\newcommand{\risbn}[1]{ISBN: {#1}\newline}

\lng{ruby}

%@r~%  The ASCII tilde is used as the nuweb escape character

\begin{document}

\section{Introduction}


This module converts floating point numbers to fractions efficiently.

\section{Rationalization of floating point numbers}

To find rational aproximations we use algorithms by Joe Horn
adaptad from his RPL programs.

~o lib/nio/rtnlzr.rb
~{# Rationalization of floating point numbers.
#--
~<License~>
#++
~<rdoc commentary for rntlzr.rb~>
~<Required Modules~>
~<definitions~>
~<classes~>
module Nio
  ~<Nio definitions~>
  ~<Nio classes~>
  module_function
  ~<Nio functions~>
end
~}

~o test/test_rtnlzr.rb
~{
~<License~>
require 'test/unit'

require 'nio/rtnlzr'
require 'nio/sugar'
include Nio
require 'yaml'
require 'flt'
require 'flt/float'
require 'flt/math'
require 'flt/bigdecimal'
require 'bigdecimal/math'

~<Rtnlzr tests support~>

class TestRtnlzr < Test::Unit::TestCase

  def setup
    ~<Tests setup~>
  end

  ~<Tests~>

end
~}

~d Rtnlzr tests support
~{~%
require 'bigdecimal/math'

module BgMth
  extend BigMath
end
~}

~d Required Modules
~{~%
require 'nio/tools'
~}

~d Required Modules
~{~%
require 'flt/tolerance'
~}

\section{Floating point to exact fraction conversion}

These utility functions return fractions that yield the
exact value of floating point numbers; this is trivial
(since floating point numbers have finite precision)
and doesn't produce simple fractions.

\subsection{Float}

This implementation does not always yield the smallest possible
fraction, but is efficient. It is based
in the definition of \verb|Math.frexp| and \verb|ldexp|,
and also relies on the fact that \verb|Float#to_i| converts big integers;
in particular big powers of the Float radix to their exact integer value (so we use
\verb|Math.frexp| rather than \verb|Integer#**| when possible.)


~d definitions
~{~%
class Float
  ~<rdoc commentary for Float\#nio\_xr~>
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
~}

Here's alternative implementation for binary floating point that
yields smallest fractions when possible and is almost as fast:

~d scratch
~{~%
class Float
  def nio_xr
    p,q = self,1
    while p.modulo(1) != 0
      p *= 2.0
      q <<= 1 # q *= 2
    end
    return Rational(p.to_i,q)
  end
end
~}

An a here's a shorter implementation relying on the semantics of the power operator, but
which is somewhat slow:

~d scratch
~{~%
class Float
  def nio_xr
    f,e = Math.frexp(self)
    f = Math.ldexp(f, Float::MANT_DIG)
    e -= Float::MANT_DIG
    return Rational( f.to_i*(Float::RADIX**e.to_i), 1)
  end
end
~}

\subsection{BigDecimal}


~d definitions
~{~%
class BigDecimal
  ~<rdoc commentary for BigDecimal\#nio\_xr~>
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
~}

\subsection{Flt}


~d definitions
~{~%
class Flt::Num
  ~<rdoc commentary for Flt\#nio\_xr~>
  def nio_xr
    to_r
  end
end
~}


\subsection{Integer}

~d definitions
~{~%
class Integer
  ~<rdoc commentary for Integer\#nio\_r~>
  def nio_xr
    return Rational(self,1)
  end
end
~}

\subsection{Rational}

~d definitions
~{~%
class Rational
  ~<rdoc commentary for Rational\#nio\_r~>
  def nio_xr
    return self
  end

  # helper method to return both the numerator and denominator
  def nio_num_den
    return [numerator,denominator]
  end
end
~}

\section{Rationalizer object}

Here is the \cd{Rtnlzr} class that encapsulates the rationalization
algorithm. It contains several rationalization approaches that has been
tested; the most efficient one is them \cd{rationalize} method.

~d Nio classes
~{~%
~<rdoc commentary for Rtnlzr~>
class Rtnlzr
  include StateEquivalent

  # Create Rationalizator with given tolerance.
  def initialize(tol=Flt.Tolerance(:epsilon))
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
    ~<Smallest-Denominator Rationalization by Donald Knuth and Javier Goizueta~>
  end
  # This is algorithm PDQ2 by Joe Horn.
  def rationalize_Horn(x)
    ~<Smallest-Denominator Rationalization by Joe Horn~>
  end
  # This is from a RPL program by Tony Hutchins (PDR6).
  def rationalize_HornHutchins(x)
    ~<Smallest-Denominator Rationalization by Joe Horn and Tony Hutchins~>
  end
end
~}

This is the generic structure of our rationalization methods:

~d Rationalization Procedure
~{~%
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
  dx = num_tol ? @tol : @tol.value(x)

  ~1

  num = -num if negans
end
return num,den
~}

\subsection{Rationalization algorithms}


Simple rationalization algorithm not currently included in the Rtnlzr class:

~d Simple Rationalization by Joe Horn
~{~%
~<Rationalization Procedure~(~<Simple Rationalization by Joe Horn Procedure~>~)~>
~}

Smallest denominator rationalization procedure by Joe Horn.

~d Smallest-Denominator Rationalization by Joe Horn
~{~%
~<Rationalization Procedure~(~<Smallest-Denominator Rationalization by Joe Horn Procedure~>~)~>
~}

Smallest denominator rationalization procedure by Joe Horn and Tony Hutchins; this
is the most efficient method as implemented in RPL.

~d Smallest-Denominator Rationalization by Joe Horn and Tony Hutchins
~{~%
~<Rationalization Procedure~(~<Smallest-Denominator Rationalization by Joe Horn Procedure~>~)~>
~}

Smallest denominator rationalization based on exercise 39 of \cite[\S 4.5.3]{Knuth}.
This has been found the most efficient method (except for large tolerances)
as implemented in Ruby.

~d Smallest-Denominator Rationalization by Donald Knuth and Javier Goizueta
~{~%
~<Rationalization Procedure~(~<Smallest-Denominator Rationalization by Donald Knuth and Javier Goizueta Procedure~>~)~>
~}

A  small modification of this algorthm has been used in tests, but is not currenly included
in class Rtnlzr.

~d Smallest-Denominator Rationalization by Donald Knuth and Javier Goizueta B
~{~%
~<Rationalization Procedure~(~<Smallest-Denominator Rationalization by Donald Knuth and Javier Goizueta B Procedure~>~)~>
~}

\subsection{Implementation of the algorithms}


~d Smallest-Denominator Rationalization by Joe Horn Procedure
~{~<Rationalization by Joe Horn Procedure~(~<Extra Rationalization Step by Joe Horn~>~)~>~}


~d Simple Rationalization by Joe Horn Procedure
~{~<Rationalization by Joe Horn Procedure~>~}

~d Rationalization by Joe Horn Procedure
~{~%
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
~1
num,den = x,y # renaming
~}

~d Extra Rationalization Step by Joe Horn
~{~%
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
~}


Tony Hutchins has come up with PDR6, an improvement over PDQ2;
though benchmarking does not show any speed improvement under Ruby.

~d Smallest-Denominator Rationalization by Joe Horn and Tony Hutchins Procedure
~{~%
a,b = dx.nio_xr.nio_num_den
n,d = x.nio_xr.nio_num_den
pc,ce = n,-d
pc,cd = 1,0
t = a*b
begin
  tt = (-pe).div(ce)
  pd,cd = cd,pd+tt*cd
  pe,ce = ce,pe+tt*ce
end until b*ce.abs <= t*cd
tt = t * (pe<0 ? -1 : (pe>0 ? +1 : 0))
tt = (tt*d+b*ce).div(tt*pd+b*pe)
num,den = (n*cd-ce-(n*pd-pe)*tt)/d, tt/(cd-tt*pd)
~}

Here's the rationalization procedure based on the exercise by Knuth.
We need first to calculate the limits (x-dx, x+dx)
 of the range where we'll look for the rational number.
If we compute them using floating point and then convert then to fractions this method is
always more efficient than the other procedures implemented here, but it may be
less accurate. We can achieve perfect accuracy as the other methods by doing the
substraction and addition with rationals, but then this method becomes less efficient than
the others for a low number of iterations (low precision required).

~d Smallest-Denominator Rationalization by Donald Knuth and Javier Goizueta Procedure
~{~%
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
~}


La siguiente variante realiza una iteración menos si xq<xp y una iteración más
si xq>xp.

~d Smallest-Denominator Rationalization by Donald Knuth and Javier Goizueta B Procedure
~{~%
  x = x.nio_xr
  dx = dx.nio_xr
  xq,xp = (x-dx).nio_num_den
  yq,yp = (x+dx).nio_num_den

    a = []
    fin,odd = false,true
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
    num,den = p,q
~}


\subsection{Maximum denominator algorithm}

This is a method by Joseph K. Horn that finds
the best possible fraction given a maximum denominator. It computes
continued fractions by a fast recursion formula, then make a single
calculated jump backwards to the best possible fraction before
the specified maximum denominator.
He traces back the algorithm to ``Textbook of Algebra'' by G. Chrystal, 1st
edition in 1889, in Part II, Chapter 32.

This algorithm was implementd in the User-RPL program \cd{DEC2FRAC},
which I have adapted here for Ruby.

As this is a different approach, which uses no tolerance value, but
instead needs a maximum denominator, I'll add it as a class-method.
Note thas this method operates on floating point quantities
(rather than integers as the other methods here do)
and requires \cd{ceil}, \cd{floor}, \cd{abs}
and \cd{round} on the floating point type (so it is applicable to
\cd{Float} and \cd{BigDecimal}).
As only the denominator is computed first, and then the numerator
is computed using floating point math, this limits the magnitude
and precision of the numerator. The precision of the
floating point type may also make this method to miss the best
approximation and yield something worse (with a lower denominator).
For example, the fraction $39/329$ if correctly approximated with
a denominator not greater than $200$
as $23/194$ using \cd{BigDecimal}. But the accumulated
error when using \cd{Float} make the method return $16/135$.


~D Nio classes
~{~%
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

  cast = (num_class==BigDecimal) ? lambda{|x| BigDecimal.new(x.to_s) } : lambda{|x| num_class.Num(x) }

  one = cast.call(1)

   sign = f<0
   f = -f if sign

   a,b,c = 0,1,f
   while b<max_den and c!=0
     cc = one/c
     a,b,c = b, mth.ip(cc)*b+a, mth.fp(cc)
   end


   if b>max_den
     b -= a*mth.ceil(cast.call(b-max_den)/a)
   end


   f1,f2 = [a,b].collect{|x| mth.abs(cast.call(mth.rnd(x*f))/x-f)}

   a = f1>f2 ? b : a

   num,den = mth.rnd(a*f).to_i,a
   den = 1 if mth.abs(den)<1

   num = -num if sign

  return num,den
end
~}

To simplifly the code I've defined this, RPL-like, functions:
~D Nio classes
~{~%
class Rtnlzr
  private
  #Auxiliary floating-point functions
  module Mth # :nodoc:
    def self.fp(x)
      # y =x.modulo(1); return x<0 ? -y : y;
      x-ip(x)
    end

    def self.ip(x)
      # Note that ceil, floor return an Integer for Float and Flt::Num, but not for BigDecimal
      (x<0 ? x.ceil : x.floor).to_i
    end

    def self.rnd(x)
      # Note that round returns an Integer for Float and Flt::Num, but not for BigDecimal
      x.round.to_i
    end

    def self.abs(x)
      x.abs
    end

    def self.ceil(x)
      # Note that ceil returns an Integer for Float and Flt::Num, but not for BigDecimal
      x.ceil.to_i
    end
  end
  def self.mth; Mth; end
end
~}


\subsection{Float to Rational conversion}


Having added \cd{Rtnlzr.max\_denominator}, I'll use
it if the parameter to \cd{nio\_r} is not a \cd{Tolerance}.

~d Required Modules
~{~%
require 'rational'
~}

~d classes
~{~%
class Float
  ~<rdoc commentary for Float\#nio\_r~>
  def nio_r(tol = Flt.Tolerance(:big_epsilon))
    case tol
      when Integer
        Rational(*Nio::Rtnlzr.max_denominator(self,tol,Float))
      else
        Rational(*Nio::Rtnlzr.new(tol).rationalize(self))
    end
  end
end
~}



\subsection{BigDecimal to Rational conversion}

~d Required Modules
~{~%
require 'bigdecimal'
~}

~d classes
~{~%
class BigDecimal
  ~<rdoc commentary for BigDecimal\#nio\_r~>
  def nio_r(tol = nil)
    tol ||= Flt.Tolerance([precs[0],Float::DIG].max,:sig_decimals)
    case tol
      when Integer
        Rational(*Nio::Rtnlzr.max_denominator(self,tol,BigDecimal))
      else
        Rational(*Nio::Rtnlzr.new(tol).rationalize(self))
    end
  end
end
~}

\subsection{Flt to Rational conversion}

~d Required Modules
~{~%
require 'flt'
~}

~d classes
~{~%
class Flt::Num
  ~<rdoc commentary for Flt\#nio\_r~>
  def nio_r(tol = nil)
    tol ||= Flt.Tolerance(Rational(1,2),:ulps)
    case tol
      when Integer
        Rational(*Nio::Rtnlzr.max_denominator(self,tol,num_class))
      else
        Rational(*Nio::Rtnlzr.new(tol).rationalize(self))
    end
  end
end
~}


\section{rdoc documentation}

~d rdoc commentary for rntlzr.rb
~{#
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
~}

~d rdoc commentary for Rtnlzr
~{# This class provides conversion of fractions
# (as approximate floating point numbers)
# to rational numbers.~}

~d rdoc commentary for nio\_r
~{# Conversion to Rational. The optional argument must be one of:
# - a Nio::~1 that defines the admisible tolerance;
#   in that case, the smallest denominator rational within the
#   tolerance will be found (which may take a long time for
#   small tolerances.)
# - an integer that defines a maximum value for the denominator.
#   in which case, the best approximation with that maximum
#   denominator will be returned.~}

~d rdoc commentary for BigDecimal\#nio\_xr ~{~<rdoc commentary for nio\_xr~>~}
~d rdoc commentary for Float\#nio\_xr ~{~<rdoc commentary for nio\_xr~>~}
~d rdoc commentary for Integer\#nio\_xr ~{~<rdoc commentary for nio\_xr~>~}
~d rdoc commentary for Rational\#nio\_xr ~{~<rdoc commentary for nio\_xr~>~}

~d rdoc commentary for nio\_xr
~{# Conversion to Rational preserving the exact value of the number.~}


The constructor methods are module functions with capitalized names that need to
be documented apart.

~d Nio constructor methods rdoc
~{
# This module contains some constructor-like module functions
# to help with the creation of tolerances and big-decimals.
#
# =BigDec
~<rdoc for BigDec~>
#
~}

\section{Patch}

In some Ruby implementations there's a bug in \verb|Float#to_i| which
produces incorrect results. This has been detected in Ruby 1.8.4
compiled for \verb|x86_64_linux|.
Here we'll try to detect the problem and apply a quick patch. The resulting
method will be slower but will produce correct results.


\section{Tests}

\subsection{Test data}


We'll load the data for the tests in a global variable.

~d Tests setup
~{~%
    $data = YAML.load(File.read(File.join(File.dirname(__FILE__) ,'data.yaml'))).collect{|x| [x].pack('H*').unpack('E')[0]}
~}


\subsection{Test methods}

~D Tests
~{~%
  def test_basic_rtnlzr
    # basic Rtnlzr tests
    r = Rtnlzr.new
    assert_equal [13,10], r.rationalize(1.3)
    assert_equal [13,10], Rtnlzr.max_denominator(1.3,10)
    assert_equal [13,10], Rtnlzr.max_denominator(BigDecimal('1.3'),10)
    assert_equal [1,3], Rtnlzr.max_denominator(1.0/3,10)
    assert_equal [1,3], Rtnlzr.max_denominator(BigDecimal('1')/3,10)
    assert_equal [13,10], Rtnlzr.max_denominator(Flt.DecNum('1.3'),10)
    assert_equal [1,3], Rtnlzr.max_denominator(Flt.DecNum('1')/3,10)

    # basic tests of Float#nio_r
    assert_equal Rational(1,3), (1.0/3.0).nio_r
    assert_equal Rational(2,3), (2.0/3.0).nio_r
    assert_equal Rational(1237,1234), (1237.0/1234.0).nio_r
    assert_equal Rational(89,217), (89.0/217.0).nio_r

    # rationalization of Floats using a tolerance
    t = Flt.Tolerance(1e-15/2,:floating)
    assert_equal Rational(540429, 12500),43.23432.nio_r(t)
    assert_equal Rational(6636649, 206596193),0.032123772.nio_r(t)
    assert_equal Rational(280943, 2500000), 0.1123772.nio_r(t)
    assert_equal Rational(39152929, 12500), 3132.23432.nio_r(t)
    assert_equal Rational(24166771439, 104063), 232232.123223432.nio_r(t)
    assert_equal Rational(792766404965, 637), 1244531247.98273123.nio_r(t)
    #$data.each do |x|
    #  assert t.equals?(x, x.nio_r(t).to_f), "out of tolerance: #{x.inspect} #{x.nio_r(t).inspect}"
    #end

    # rationalization with maximum denominator
    assert_equal Rational(9441014047197, 7586), (1244531247.98273123.nio_r(10000))
    assert_equal Rational(11747130449709, 9439), BigDecimal('1244531247.982731230').nio_r(10000)
    assert_equal Rational(11747130449709, 9439), Flt.DecNum('1244531247.982731230').nio_r(10000)


    # approximate a value in [0.671,0.672];
    #  Float
    assert_equal [43,64], Rtnlzr.new(Flt.Tolerance(0.0005)).rationalize(0.6715)
    assert_equal [43,64], Rtnlzr.new(Rational(5,10000)).rationalize(0.6715)
    # BinNum
    assert_equal [43,64], Rtnlzr.new(Flt.Tolerance(Flt.BinNum('0.0005'))).rationalize(Flt::BinNum('0.6715'))
    assert_equal [43,64], Rtnlzr.new(Flt.Tolerance(Rational(5,10000))).rationalize(Flt::BinNum('0.6715'))
    #  BigDecimal
    assert_equal [43,64], Rtnlzr.new(Flt.Tolerance('0.0005')).rationalize(BigDecimal('0.6715'))
    assert_equal [43,64], Rtnlzr.new(Rational(5,10000)).rationalize(BigDecimal('0.6715'))
    # DecNum
    assert_equal [43,64], Rtnlzr.new(Flt.Tolerance(Flt.DecNum('0.0005'))).rationalize(Flt::DecNum('0.6715'))
    assert_equal [43,64], Rtnlzr.new(Flt.Tolerance(Rational(5,10000))).rationalize(Flt::DecNum('0.6715'))
    #
    assert_equal Rational(43,64), 0.6715.nio_r(0.0005)
    assert_equal Rational(43,64), 0.6715.nio_r(Rational(5,10000))
    assert_equal Rational(47,70), 0.6715.nio_r(70)
    assert_equal Rational(45,67), 0.6715.nio_r(69)
    assert_equal Rational(2,3), 0.6715.nio_r(10)

    # some PI tests
    assert_equal Rational(899125804609,286200632530), BgMth.PI(64).nio_r(Flt.Tolerance(Flt.DecNum('261E-24')))
    assert_equal Rational(899125804609,286200632530), BgMth.PI(64).nio_r(Flt.Tolerance(Flt.DecNum('261E-24')))
    assert_equal Rational(899125804609,286200632530), BgMth.PI(64).nio_r(Flt.DecNum('261E-24'))
    assert_equal Rational(899125804609,286200632530), BgMth.PI(64).nio_r(261E-24)

    assert_equal Rational(899125804609,286200632530), Flt::DecNum::Math.pi(64).nio_r(Flt.Tolerance(Flt.DecNum('261E-24')))
    assert_equal Rational(899125804609,286200632530), Flt::DecNum::Math.pi(64).nio_r(Flt.Tolerance(Flt.DecNum('261E-24')))
    assert_equal Rational(899125804609,286200632530), Flt::DecNum::Math.pi(64).nio_r(Flt.DecNum('261E-24'))
    assert_equal Rational(899125804609,286200632530), Flt::DecNum::Math.pi(64).nio_r(261E-24)

    # DecNum tests
    #t = Flt.Tolerance(Flt.DecNum('1e-15'),:floating)
    t = Flt.Tolerance(20,:sig_decimals)
    $data.each do |x|
      x = Flt.BinNum(x).to_decimal_exact
      q = x.nio_r(t)
      assert t.eq?(x, Flt.DecNum(q)), "out of tolerance: #{x.inspect} #{Flt.DecNum(q)}"
    end

    # Flt tests
    #t = Flt.Tolerance(Flt.DecNum('1e-15'),:floating)
    t = Flt.Tolerance(20,:sig_decimals)
    $data.each do |x|
      x = Flt.BinNum(x)
      q = x.nio_r(t)
      assert t.eq?(x, Flt.BinNum(q)), "out of tolerance: #{x.inspect} #{Flt.BinNum(q)}"
    end


  end
~}

~D Tests
~{~%
    def test_compare_algorithms
      r = Rtnlzr.new(Flt.Tolerance(1e-5,:floating))
      ($data + $data.collect{|x| -x}).each do |x|
        q1 = r.rationalize_Knuth(x)
        q2 = r.rationalize_Horn(x)
        q3 = r.rationalize_HornHutchins(x)
        #q4 = r.rationalize_KnuthB(x)
        q1 = [-q1[0],-q1[1]] if q1[1] < 0
        q2 = [-q2[0],-q2[1]] if q2[1] < 0
        q3 = [-q3[0],-q3[1]] if q3[1] < 0
        assert_equal q1, q2
        assert_equal q1, q3
        #assert_equal q1, q4
      end
      r = Rtnlzr.new(Flt.Tolerance(:epsilon))
      ($data + $data.collect{|x| -x}).each do |x|
        q1 = r.rationalize_Knuth(x)
        q2 = r.rationalize_Horn(x)
        q3 = r.rationalize_HornHutchins(x)
        q1 = [-q1[0],-q1[1]] if q1[1] < 0
        q2 = [-q2[0],-q2[1]] if q2[1] < 0
        q3 = [-q3[0],-q3[1]] if q3[1] < 0
        #q4 = r.rationalize_KnuthB(x)
        assert_equal q1, q2
        assert_equal q1, q3
        #assert_equal q1, q4
      end

    end
~}



% -------------------------------------------------------------------------------------
\section{Indices}


\subsection{Files}
~f

\subsection{Macros}
~m

\subsection{Identifiers}
~u

\begin{thebibliography}{Rtnlzr}

\bibitem[Knuth]{Knuth}
   \rtitle{The Art of Computer Programming 2d ed. Vol.2}
   \rsubtitle{Seminumerical Algorithms}
   \rauthor{Donald E. Knuth}
   \rpub{1981}
   \red{Addison-Wesley}
   \risbn{0-201-03822-6}

\end{thebibliography}

\end{document}
