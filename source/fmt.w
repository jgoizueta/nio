% fmt.w -- numeric formatting
%
% Copyright (C) 2003-2005, Javier Goizueta <javier@@goizueta.info>
%
% This program is free software; you can redistribute it and/or
% modify it under the terms of the GNU General Public License
% as published by the Free Software Foundation; either version 2
% of the License, or (at your option) any later version.

% ===========================================================================
\documentclass[a4paper,oneside,english]{article}
\usepackage[english,read]{nwprog}
% ===========================================================================


% ===========================================================================
%\input{nwprogen.tex}
% ===========================================================================

\isodate

\newcommand{\ProgTitle}{Numeric Formatting}
\newcommand{\ProgAuth}{Javier Goizueta} 
\newcommand{\ProgDate}{\today} 
\newcommand{\ProgVer}{1.0}
\newcommand{\ProgSource}{\ttfamily\bfseries fmt.w}

\title{\ProgTitle}
\author{\ProgAuth} 
\date{\ProgDate}

% ===========================================================================

\lng{ruby}

%@r·%   this is the nuweb escape character (183) which is a centered dot in iso-8859-latin1

\begin{document}

% TO FIX: if a neutral has empty digits it is 0 and should be formatted accordingly

\section{Formatting Numbers As Text}

These Ruby classes handle formatting options for number of classes such 
as \cd{Integer}, \cd{Rational}, \cd{Float}, \cd{BigDecimal}. 

·o lib/nio/fmt.rb
·{# Formatting numbers as text
·<License·>
·<references·>
module Nio
  ·<Nio classes·>
  module_function
  ·<Nio functions·>  
  ·<Nio private functions·>  
end
·<definitions·>
·}

·o test/test_fmt.rb
·{
·<License·>
#require File.dirname(__FILE__) + '/test_helper.rb'
require 'test/unit'
require 'nio/rtnlzr'
require 'nio/repdec'
require 'nio/fmt'
include Nio
require 'yaml'
·<Auxiliar methods for testing·>
class TestFmt < Test::Unit::TestCase

  def setup
    ·<Tests setup·>
  end
  
  ·<Tests·> 

end
·}

·d License
·{·%
# Copyright (C) 2003-2005, Javier Goizueta <javier@goizueta.info>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
·}

\section{Neutral Text Format}

We'll define a neutral format to handle numerics in text form. This will be independent
of formatting details and will handle positional notations in arbitrary bases, and 
infinite digit repetitions (so that rational numbers can be exactly represented).

The significant digits of the number will be kept in a text string, indepedently of the
decimal position. So this is effectively a floating point notation, and we can handle
floating point numbers representation efficiently, not having to store innecesary digits.

Note: NeutralNum and RepDec maybe should be merged into a single class.
If that class uses the NeutralNum of not storing the integer part,
but storing only digits, some things would be simplified.

I've added an {\emph inexact} flag to distinguish numerals
that have been generated from limited precision numeric
types, such as floating point.

·d Nio classes
·{·%
# positional notation, unformatted numeric literal: used as intermediate form
class NeutralNum 
  include StateEquivalent
  def initialize(s='',d='',p=nil,r=nil,dgs=DigitsDef.base(10), inexact=false, round=:inf)
    set s,d,p,r,dgs,dgs, inexact, round
  end
  attr_reader :sign, :digits, :dec_pos, :rep_pos, :special, :inexact, :rounding
  attr_writer :sign, :digits, :dec_pos, :rep_pos, :special, :inexact, :rounding
  ·<class NeutralNum·>
  protected
  ·<NeutralNum protected·>
end
·| NeutralNum ·}

·d references
·{·%
require 'nio/tools'
·}


We'll add some handy methods to set values. We'll have some special values
(recognized by a symbol stored in \cd{@special}) to store infinities and
indeterminate numbers.
·D class NeutralNum
·{·%
# set number
def set(s,d,p=nil,r=nil,dgs=DigitsDef.base(10),inexact=false,rounding=:inf,normalize=true)
  @sign = s # sign: '+','-',''
  @digits = d # digits string
  @dec_pos = p==nil ? d.length : p # position of decimal point: 0=before first digit...
  @rep_pos = r==nil ? d.length : r # first repeated digit (0=first digit...)
  @dgs = dgs
  @base = @dgs.radix
  @inexact = inexact
  @special = nil
  @rounding = rounding
  trimZeros unless inexact  
  self
end
# set infinite (:inf) and invalid (:nan) numbers
def set_special(s,sgn='') # :inf, :nan
  @special = s
  @sign = sgn
  self
end
·| set set_special ·}  

·D class NeutralNum
·{·%
def base
  @base
end
def base_digits
  @dgs
end
def base_digits=(dd)
  @dgs = dd
  @base = @dgs.radix
end
def base=(b)
  @dgs = DigitsDef.base(b)
  @base=@dgs.radix
end
·}  


This value will indicate a special number; in that case the only valid attributes
are \cd{special} and \cd{sign}.

·d class NeutralNum
·{·%
# check for special numbers (which have only special and sign attributes)
def special?
  special != nil
end
·| special? ·}

·d class NeutralNum
·{·%
# check for special numbers (which have only special and sign attributes)
def inexact?
  @inexact
end
·| inexact? ·}


A \cd{dup} method will be provided to deep-copy objects of this class.
·d class NeutralNum
·{·%
def dup
  n = NeutralNum.new
  if special?
    n.set_special @special.dup, @sign.dup
  else
    #n.set @sign.dup, @digits.dup, @dec_pos.dup, @rep_pos.dup, @dgs.dup
    # in Ruby 1.6.8 Float,BigNum,Fixnum doesn't respond to dup
    n.set @sign.dup, @digits.dup, @dec_pos, @rep_pos, @dgs.dup, @inexact, @rounding
  end
  return n 
end
·| dup ·}

We will add a method to check for null values.

·d class NeutralNum
·{·%
def zero?
  z = false
  if !special
    if digits==''
      z = true
    else
      z = true
      for i in (0...@digits.length)
        if dig_value(i)!=0
          z = false
          break
        end
      end
    end
  end
  z
end
·| zero? ·}


\subsection{Rounding}

This method will handle in-place rounding of neutral numerals.
The parameters are the number of digits to round to, 
the rounding mode and the direction of rounding.
For \cd{:exact} rounding, all available digits are preserved
and rounding is only necessary, in the last digit for
inexact quantities, that may have been flagged as needing
a round-up of the last digit by having the value \cd{:roundup}
in the \cd{inexact} property.

·d class NeutralNum
·{·%
def round!(n, mode=:fix, dir=nil)
  dir ||= rounding
  trimLeadZeros
  if n==:exact
    return unless @inexact
    n = @digits.size
  end
  ·<NeutralNum\#round·>
end
·| round! ·}

The possible modes are:
\begin{itemize}
\item \cd{:fix}; this will use the specifiend number of fixed decimal
digits. A negative number of digits is allowed to round to digits
of the integral part of the number. (maybe should be called :abs ?)
\item \cd{:sig}; in this mode, a number of significant digits are used.
\end{itemize}; any other mode is treated as \cd{:sig}.
The rounding directions define how to handle ties: number which are
equally near from either the lower and upper integers.
\begin{itemize}
\item \cd{:inf}; ties are rounded towards the nearest infinite (that
of the sign of the number).
\item \cd{:even}; ties are rounded towards the nearest even number 
(banker's rounding).
\end{itemize}

A method will be added for non-mutable operation:

·d class NeutralNum
·{·%
def round(n, mode=:fix, dir=nil)
  dir ||= rounding
  nn = dup
  nn.round!(n,mode,dir)
  return nn
end
·| round! ·}


We will adjust \cd{n} so that \cd{@digits} will need to be
truncated at the position \cd{n-1}. Then repetitions will be nulled,
since we have rounded to a finite number of digits.

·d NeutralNum\#round
·{·%
n += @dec_pos if mode==:fix
n = [n,@digits.size].min if @inexact
·<Adjust the last digit \cd{n-1}·>
if n<0
  @digits = ""  
else
  @digits = @digits[0...n]  
end
@rep_pos = @digits.length
·<Add prefix from adjustment·>
·}

The tedious part is resolving ties and adjusting digits which may carry on
additions beyond the stored digits and so may need to add prefix digits that we
we'll finally add.

First we must check if adjustment is needed; we'll keep the quantity that
must be added to the last digit in \cd{adj}, and use \cd{dv} to determine
what kind of final digit we have: low, hi or just-in-the-middle (a tie).
·d Adjust the last digit \cd{n-1}
·{·%
adj = 0
dv = :tie
if @inexact && n==@digits.size
  dv = @inexact==:roundup ? :hi : :lo
else
  v = dig_value(n)
  v2 = 2*v
  if v2 < @base # v<((@base+1)/2)
    dv = :lo
  elsif v2 > @base # v>(@base/2)
    dv = :hi
  else
   ·<Look at trailing digits and try to resolve the tie·> 
    dv = :hi if dv==:tie && @rep_pos<=n                  
  end
end
·}
Note in the previous fragment that we use the funny addition of a unit to
the base (\cd{(@base+1)/2}) so that this also works for odd bases (which
in all probability will never be used). 
Also note that if we had a tie and the tie digit (which we know its non-zero)
is repeated then we don't really have a tie!

We must look further when the digit we look at is midway (a 5 in decimal base).

·d Look at trailing digits and try to resolve the tie
·{·%
(n+1...@digits.length).each do |i|
  if dig_value(i)>0
    dv = :hi
    break
  end        
end
·}

Now that we have examined the digits, the adjust value can be computed.

·d Adjust the last digit \cd{n-1}
·{·%
if dv==:hi
  adj = +1
elsif dv==:tie
  if dir==:inf # towards nearest +/-infinity
    adj = +1
  elsif dir==:even # banker's rule
    adj = +1 if (dig_value(n-1)%2)!=0
  elsif dir==:zero # towards zero
    # adj=0
  else #:odd 
    adj = +1 unless (dig_value(n-1)%2)!=0
  end
end    
·}

Before adjusting the digits we will add stored digits if necessary, so that
all rounded digits are actually kept (and are not inplicitly derived from
repetitions); remember that we are going to get rid of repetitions.
We are using a function that computes digit values, even for those digits
that are not stored; that's why we must keep \cd{@rep\_pos} meaningful and synchronized
with \cd{@digits}.

·d Adjust the last digit \cd{n-1}
·{·%
if n>@digits.length
  (@digits.length...n).each do |i|
    @digits << dig_char(dig_value(i))
    @rep_pos += 1
  end
end
·}

Finally we can do the actual adjustment, adding the value and handling carries.
A \cd{prefix} variable will be use to store carries beyond the stored digits.

·d Adjust the last digit \cd{n-1}
·{·%
prefix = ''
i = n-1
while adj!=0
  v = dig_value(i)
  v += adj
  adj = 0
  if v<0
    v += @base
    adj = -1
  elsif v>=@base
    v -= @base
    adj = +1
  end
  if i<0
    prefix = dig_char(v)+prefix 
  elsif i<@digits.length
    @digits[i] = dig_char(v)
  end
  i += -1
end 
·}

And we must not forget to add those prefix digits...

·d Add prefix from adjustment
·{·%
if prefix!=''
  @digits = prefix + @digits
  @dec_pos += prefix.length
  @rep_pos += prefix.length
end
·}

\subsubsection{Digit values}

We need methods to retrieve digit values (even those not stored) and also to 
get digit characters from values.

·d NeutralNum protected
·{·%
def dig_value(i)
  v = 0
  if i>=@rep_pos 
    i -= @digits.length
    i %= @digits.length - @rep_pos if @rep_pos<@digits.length
    i += @rep_pos
  end        
  if i>=0 && i<@digits.length
    v = @dgs.digit_value(@digits[i]) #digcode_value(@digits[i])
  end
  return v>=0 && v<@base ? v : nil
end
#def digcode_value(c)
#  v = c-?0
#  if v>9
#    v = 10 + c.chr.downcase[0] - ?a
#  end
#  v
#  @dgs.digit_value(c)
#end
·| dig_value ·}

·d NeutralNum protected
·{·%
def dig_char(v)
  c = ''
  if v!=nil && v>=0 && v<@base
    c = @dgs.digit_char(v).chr
  end
  c
end
·| dig_char ·}


\subsection{Removing unnecessary zeros}

·d class NeutralNum
·{·%
def trimTrailZeros()    
  i = @digits.length
  while i>0 && dig_value(i-1)==0
    i -= 1    
  end
  if @rep_pos>=i
    @digits = @digits[0...i]
    @rep_pos = i
  end
  ·<Check for empty digits·>
end
·| trimTrailZeros ·}

·d class NeutralNum
·{·%
def trimLeadZeros()
  i = 0
  while i<@digits.length && dig_value(i)==0
    i += 1
  end
  @digits = @digits[i...@digits.length]
  @dec_pos -= i
  @rep_pos -= i
  ·<Check for empty digits·>
end
·| trimLeadZeros ·}
·d class NeutralNum
·{·%
def trimZeros()    
  trimLeadZeros
  trimTrailZeros
end
·| trimZeros ·}

·d Check for empty digits
·{·%
if @digits==''
  @digits = dig_char(0) # '0'
  @rep_pos = 1
  @dec_pos = 1
end
·}


\subsection{RepDec conversion}
We will use the \cd{Repdec} module to handle digit repetitions.
·d references
·{·%
require 'nio/repdec'
·}
So, we will add methods to convert between \cd{RepDec} and \cd{NeutralNum} objects.

\subsubsection{NeutralNum to RepDec}

First we add a method to \cd{NeutralNum} for conversion to \cd{RepDec}.
We will normalize the built object because for RepDec it is convenient
to have \verb|rep_i==nil| for non-repeating numbers (or final empty
repeated-section markers will be employed when converting to text.)

·d Nio classes
·{·%
class NeutralNum
  public
  def to_RepDec
    n = RepDec.new(@base)
    if special?
      ·<Handle special NeutralNum to RepDec conversion·>
    else
      if dec_pos<=0
        n.ip = 0
        n.d =  text_to_digits(dig_char(0)*(-dec_pos) + digits)
      elsif dec_pos >= digits.length
        n.ip = digits.to_i(@base)        
        if rep_pos<dec_pos          
          i=0
          (dec_pos-digits.length).times do
            n.ip *= @base
            n.ip += @dgs.digit_value(digits[rep_pos+i]) if rep_pos+i<digits.length
            i += 1
            i=0 if i>=digits.length-rep_pos
          end
          n.d = []
          while i<digits.length-rep_pos
            n.d << @dgs.digit_value(digits[rep_pos+i])
            i += 1
          end
          new_rep_pos = n.d.size + dec_pos
          n.d += text_to_digits(digits[rep_pos..-1])
          self.rep_pos = new_rep_pos
        else
          n.ip *= @base**(dec_pos-digits.length)
          n.d = []
        end
      else
        n.ip = digits[0...dec_pos].to_i(@base)
        n.d = text_to_digits(digits[dec_pos..-1])
        if rep_pos<dec_pos 
          new_rep_pos = n.d.size + dec_pos
          n.d += text_to_digits(digits[rep_pos..-1])
          self.rep_pos = new_rep_pos
          puts "--rep_pos=#{rep_pos}"
        end        
      end
      n.sign = -1 if sign=='-'
      n.rep_i = rep_pos - dec_pos     
    end
    n.normalize!(!inexact) # keep trailing zeros for inexact numbers
    return n
  end
  protected
  def text_to_digits(txt)
    #txt.split('').collect{|c| @dgs.digit_value(c)}    
    ds = []
    txt.each_byte{|b| ds << @dgs.digit_value(b)}
    ds
  end
end
·| to_RepDec text_to_digits ·}

·d Handle special NeutralNum to RepDec conversion
·{·%
case special
  when :nan
    n.ip = :indeterminate
  when :inf
    if sign=='-'
      n.ip = :posinfinity
    else
      n.ip  :neginfinity
    end
  else
    n = nil
end
·}

\subsubsection{RepDec to NeutralNum}

·d Nio classes
·{·%
class RepDec
  public
  def to_NeutralNum(base_dgs=nil)
    num = NeutralNum.new
    if !ip.is_a?(Integer)
      ·<Handle special RepDec to NeutralNum conversion·>    
    else
      base_dgs ||= DigitsDef.base(@radix)
      # assert base_dgs.radix == @radix
      signch = sign<0 ? '-' : '+'
      decimals = ip.to_s(@radix)
      dec_pos = decimals.length
      d.each {|dig| decimals << base_dgs.digit_char(dig) }
      rep_pos = rep_i==nil ? decimals.length : dec_pos + rep_i
      num.set signch, decimals, dec_pos, rep_pos, base_dgs
    end
    return num
 end
end
·| to_NeutralNum ·}

·d Handle special RepDec to NeutralNum conversion
·{·%
case ip
  when :indeterminate
    num.set_special :nan
  when :posinfinity
    num.set_special :inf,'+'
  when :neginfinity
    num.set_special :inf,'-'
  else
    num = nil
end
·}

\section{Formatting options}

The class \cd{Fmt} (numeric formatting) will handle the 
details of formating numbers. It represents a particular format.

·d Nio classes
·{·%
# Fmt defines a numeric format
#
# The aspects managed by Fmt are:
# * separators (see #sep and #grouping)
# * mode and precision #prec(), #mode(), #sci_digits , ...
# * repeating numerasl 
# * field justfification
class Fmt
  include StateEquivalent
  def initialize()
    ·<Initialize Fmt·>  
  end
  ·<class Fmt·>
  protected
  ·<Fmt protected·>
end
·| NeutralNum ·}

\subsection{Format aspects}

The default format corresponds to the format used in
ruby for numerals (\cd{to\_s}); which is a plain english format.
We will handle these aspects:

Separators: decimal separator and grouping separators; 
\cd{@grp} is an array of integers. If empty no grouping is
performed on output (but any grouping is admitted from input
if \cd{@grp\_sep} is a valid character). Otherwise it should
be a series of values that indicate the number of digits in
each group, beginning from the decimal point (decimal digits
are not grouped), and with the last value repeating indefinetely.
So, for the usual thousands separator we would define
this variable as \cd{[3]}.

·d Initialize Fmt
·{·%
@dec_sep = '.'
@grp_sep = ','
@grp = []
·}

·d class Fmt
·{·%
# Defines the separators used in numerals. This is relevant to
# both input and output. 
# 
# The first argument is the radix point separator (usually
# a point or a comma; by default it is a point.)
#
# The second argument is the group separator. It defaults
# at comma or point (whatever is not used for the radix point).
#
# Finally, the third argument is an array, [3] by default that
# defines the groups of digits to separate.
def sep(dec_sep,grp_sep=nil,grp=[])
  @dec_sep = dec_sep
  grp_sep ||= @dec_sep=='.' ? ',' : '.'
  @grp_sep = grp_sep
  @grp = grp
  return self
end
·}

·d class Fmt
·{·%
# This defines the grouping of digits (which can also be defined in #sep)
def grouping(grp=[3],grp_sep=nil)
  grp_sep ||= @dec_sep=='.' ? ',' : '.'
  @grp = grp
  @grp_sep = grp_sep
  return self
end
·}

To simplify the creation of new format objects we will provide constructors
for each aspect:

·d class Fmt
·{·%
# This is a shortcut to create a new Fmt object and define the separators.
def Fmt.sep(dec_sep,grp_sep=nil,grp=[])
  Fmt.new.sep(dec_sep,grp_sep,grp)
end
# This is a shortcut to create a new Fmt object and define the grouping.
def Fmt.grouping(grp=[3],grp_sep=nil)
  Fmt.new.grouping(grp,grp_sep)
end
·}

% To do: more clear and complete explanation

Precision: number of digits, rounding mode and presentation format.
An \cd{:exact} value for the number of digits will format the numbers 
so that its exact value can be recovered from the output.
For rational numbers a repeating decimal expansion will be used;
for floating point enough digits will be output so that the original
value can be obtained (using correct rounding), unless
the \cd{:simplify} mode is uded

The mode value \cd{:fix} is for simple $nnn.nn$ formats with the specified 
number of decimal digits, \cd{:sig} is the same but with the specified
significant digits. The value \cd{:sci} is for scientific (exponential) 
form and \cd{:gen} is the general (automatic) format.
In the \cd{:sci} and \cd{:gen} modes, \cd{ndec} is the number
of significant digits.

There are two kind of numerical quantities: exact (as \cd{Integer} or \cd{Rational})
and inexact or approximate (as \cd{Float} or \cd{BigDecimal}) which has a limited
precision (but variable in the case of \cd{BigDecimal}).
For exact values, the \cd{all\_digits} option simply shows trailing zeros
for explicit precision.
Inexact values have additional output options when the output base is
different from the internal base: the \cd{approx} mode can either
be \cd{:exact} (and then the value is interpreted as the exact specified value),
\cd{:only\_sig} (the value is interpreted as an approximation to an unknown value
and only significant digits of the approximation are shown) or \cd{:simplify}
and the approximate value is converted if possible to a simpler exact value).
For the \cd{:approx} mode, if \cd{all\_digits} is not active, the minimum
number of digits necessary to recover unambiguosly the value are generated.


The default format has changed from generic using 10 significative digits to
generic with {\em exact} precision, i.e. showing all digits necessary to
define the value.

·d Initialize Fmt
·{·%
@ndec = :exact
@mode=:gen
@round=:inf
@all_digits = false
@approx = :only_sig
@non_sig = '' # marker for non-significant digits of inexact values e.g. '#','0'
@sci_format = 1 # number of integral digits in the mantissa: -1 for all
·}

·d class Fmt
·{·%
# Define the formatting mode using these parameters:
# - mode (only relevant for output)
#   :gen:: (general) chooses automatically the shortes format
#   :fix:: (fixed precision) is a simple format with a fixed number of digits after the point
#   :sig:: (significative precision) is like :fix but using significative digits
#   :sci:: (scientific) is the exponential form 1.234E2
# - precision (number of digits or :exact, onle relevant for output)
#   :exact:: means that as many digits as necessary to unambiguosly define the
#            value are used; this is the default.
# - rounding mode applied to conversions (this is relevant for both input and output)
#   :inf:: rounds towards infinite (the default) 0.5 is rounded to 1
#   :inf_neg:: rounds towards -infinite means truncation
#   :even:: rounds to the nearest even digit 0.5 rounds to 0, 1.5 to 2
# - approximate mode
#   :only_sig:: (the default) treats the value as an approximation and only
#               significative digits (those that cannot take an arbitrary value without changing the specified value)
#               are shown.
#   :exact::    the value is interpreted as exact, there's no distinction between significative and unsignificative digits.
#   :simplify:: the value is simplified, if possible to a simpler (rational) value.
def mode(mode,ndec=:exact,round=:inf,all_dig=nil,apprx=:only_sig)
  @mode = mode
  @ndec = ndec
  @round = round
  if all_dig.nil?
    @all_digits = ndec!=:exact && mode!=:gen
  else
    @all_digits = all_dig
  end
  @approx = apprx
  self
end
·}

·d class Fmt
·{·%
# Defines the formatting mode (like #mode) using a different
# order of parameters, which is useful to change the precision only
def prec(ndec,mode=:gen,round=:inf,all_dig=nil,apprx=:only_sig)
  @mode = mode
  @ndec = ndec
  @round = round
  if all_dig.nil?
    @all_digits = ndec!=:exact && mode!=:gen
  else
    @all_digits = all_dig
  end
  @approx = :apprx
  self
end
·}

·d class Fmt
·{·%
# This is a shortcut to create a new Fmt object and define the formatting mode.
def Fmt.mode(mode,ndec=:exact,round=:inf,all_dig=nil,apprx=:only_sig)
  Fmt.new.mode(mode,ndec,round,all_dig,apprx)
end
# This is a shortcut to create a new Fmt object and define the precision.
def Fmt.prec(ndec,mode=:gen,round=:inf,all_dig=nil,apprx=:only_sig)
  Fmt.new.prec(ndec,mode,round,all_dig,apprx)
end
·}

Show all digits: for exact types, the requested number
of decimals will be output (otherwise less digits may be output
because trailing zeroes are not shown), for inexact types and
exact precision,
also all significant digits will be output, rather than only those
necessary.

Non-significative-digits sets a symbol to stand for
non-significative digits o inexact values. Showing non-significative
digits with an special character implies showing all digits.

Scientific format digits sets the number of integral digits to be
shown.

·d class Fmt
·{·%
# This controls the display of the digits that are not necessary
# to specify the value unambiguosly (e.g. trailing zeros).
# 
# The true value forces the display of the requested number of digits
# and false will display only necessary digits.
def show_all_digits(ad=true)
  @all_digits = ad
  @non_sig = '' unless @all_digits
  self
end
# This defines the approximate mode (:only_sig, :exact, :simplify)
# just like the last parameter of #mode()
def approx_mode(mode)
  @approx=mode
  self
end
# Defines a character to stand for unsignificative digits when
# a specific number of digits has been requested greater than then
# number of significative digits (for approximate types).
def non_significative_digits(ch='#')
  @non_sig = ch
  @non_sig ||= ''
  @all_digits = true if @non_sig!=''
  self
end
# Defines the number of significan digits before the radix separator
# in scientific notation. A negative value will set all significant digits
# before the radix separator.
#
# For example:
#   0.1234.nio_write(NFmt.mode(:sci,4).sci_digits(0) ->  0.1234E0
#   0.1234.nio_write(NFmt.mode(:sci,4).sci_digits(3) ->  123.4E-3
#   0.1234.nio_write(NFmt.mode(:sci,4).sci_digits(-1) -> 1234.E-4
def sci_digits(n=-1)
  @sci_format = n
  self
end
·}


This value forces the presentation of $+$ for positive numbers.

·d Initialize Fmt
·{·%
@show_plus = false
·}

·d class Fmt
·{·%
# Controls the display of the sign for positive numbers
def show_plus(sp=true)
  @show_plus = sp
  self
end
·}

This determines how to handle repeating decimals.
Repeating decimals are recognized on input if \cd{@rep\_in}
is \cd{true}. Originally this was defaulted to \cd{false}
and was used also to simplify inexact (floating-point) types
on \cd{:exact} conversion. Now the default is \cd{true} and
this is used only for input recognition. Rationals in 
exact mode always use repeating decimal on output, so they
should recognize it on input. And additional flag \cd{@rep\_aprx} has 
been added to force floating-point types to use repeating
decimals on \cd{:exact} conversion as a way to simplify
its value under conversion (conversion is then approximate).

If \cd{@rep\_n} is 0, the repeated
digits will be delimited with \cd{@rep\_begin} and
\cd{@rep\_end}. If a value higher than 0 is used, that
indicates the minimum number of times to output the
repeated section that will be followd by the \cd{@rep\_auto}
text string. Both the delimiters and the suffix are admitted
when reading repeating decimals. The ending delimiter may be
an empty string; both delimiters must be single characters.

The initial value for \cd{@rep\_n} was originally 0 but is has been
changed to 2 becaouse as a default it seems more natural.

·d Initialize Fmt
·{·%
@rep_begin = '<'
@rep_end   = '>'
@rep_auto  = '...'
@rep_n  = 2
@rep_in   = true
·}

·d class Fmt
·{·%
# Defines the handling and notation for repeating numerals. The parameters
# are passed in a hash.
# :autoch:: is the suffix used to indicate a implicit repeating decimal (...)
# :begch:: is the beginning delimiter of repeating section (<)
# :endch:: is the ending delimiter of repeating section (>)
# :read:: (true/false) determines if repeating decimals are recognized on input (true)
# :rep:: if this parameter is greater than zero, on output the repeating section
#        is repeated the indicated number of times followed by the suffix; 
#        otherwise the delimited notation is used.
def rep(*params)
  ·<extract rep parameters·>
  ·<default rep parameters values·>
  @rep_begin=begch
  @rep_end = endch
  @rep_auto = autoch
  @rep_n = rep
  @rep_in = read
  self
end
·}

·d class Fmt
·{·%
def Fmt.rep(*params)
  Fmt.new.rep(*params)
end
·}

The \cd{rep} method now has too many parameters so we will accept
separated parameters for compatibility with existing code, but also
will accept named parameters in a hash.
·d extract rep parameters
·{·%
params << {} if params.size==0
if params[0].kind_of?(Hash)
  params = params[0]
  begch = params[':begch']
  endch = params[':endch']
  autoch = params[':autoch']
  rep = params[':rep']
  read = params[':read']
else
  begch,endch,autoch,rep,read = *params
end
·}

·d default rep parameters values
·{·%
begch ||= '<'
endch ||= '>'
autoch ||= '...'
rep ||= 0
read = true if read.nil?
·}


These values are used for output and allow the 
justification of the number in a field of specified minimum width.

·d Initialize Fmt
·{·%
@width = 0
@fill_char = ' '
@adjust=:right
·}

·d class Fmt
·{·%
# Sets the justificaton width (number of characters),
# mode (:right, :left, :center or :internal, which is 
# like left but with the sign...) and filling character.
def width(w,adj=:right,ch=' ')
  @width = w
  @fill_char = ch
  @adjust=adj
  self
end
# Defines the justification (as #width()) with the given
# width, internal mode and filling with zeros.
def pad0s(w)
  @width = w
  @fill_char = '0'
  @adjust=:internal
  self
end
# This is a shortcut to create a new Fmt object and define the width
def Fmt.width(w,adj=:right,ch=' ')
  Fmt.new.width(w,adj,ch)
end
# This is a shortcut to create a new Fmt object and define 0-padded field
def Fmt.pad0s(w)
  Fmt.new.pad0s(w)
end
·}


These values permit using different number basis.

·d Initialize Fmt
·{·%
@base_radix = 10
@base_uppercase = true
@base_digits = DigitsDef.base(@base_radix, !@base_uppercase)
@show_base = false
@base_indicators = { 2=>'b', 8=>'o', 10=>'', 16=>'h', 0=>'r'} # 0: generic (used with radix)
@base_prefix = false
·}

To do: allow prefix/suffix for base indicators and generic radix
%  hff FFh #hFF FFr16

·d class Fmt
·{·%
# defines the numerical base; the second parameters forces the use
# of uppercase letters for bases greater than 10.
def base(b, uppercase=true)
  @base_radix = b
  @base_uppercase = uppercase
  @base_digits = DigitsDef.base(@base_radix, !@base_uppercase)
  self
end
# This is a shortcut to create a new Fmt object and define the base
def Fmt.base(b, uppercase=true)
  Fmt.new.base(b, uppercase)
end
# returns the exponent char used with the specified base
def get_exp_char(base)
  base ||= @base_radix
  base<=10 ? 'E' : '^'
end
·}


The base radix needs some special treatment: its the only formatting
detail that's in \cd{NeutralNum} (which is not neutral at that).
Because of that we'll need to know the base of a format specification.

·d class Fmt
·{·%
# returns the base
def get_base
  @base_radix
end
# returns the digit characters used for a base
def get_base_digits(b=nil)
  (b.nil? || b==@base_radix) ? @base_digits : DigitsDef.base(b,!@base_uppercase)
end
# returns true if uppercase digits are used
def get_base_uppercase? # :nodoc:
  @base_uppercase
end
·}

Well, after all we need to access know other formatting details as well...

·d class Fmt
·{·%
# returns the formatting mode
def get_mode
  @mode
end
# returns the precision (number of digits)
def get_ndig
  @ndec
end
# return the show_all_digits state
def get_all_digits?
  @all_digits
end
# returns the approximate mode
def get_approx
  @approx
end
·}


·d class Fmt
·{·%
# returns the rounding mode
def get_round
  @round
end
·}



Finally, these are the representations of the special values.

·d Initialize Fmt
·{·%
@nan_txt = 'NAN'
@inf_txt = 'Infinity'
·}

\subsection{Formatting to and from Neutral Numerals}

Class \cd{Fmt} will handling reading formatted values into 
neutral numerals and writing neutral numerals into formatted text.
This way, to provide formatting for a numeric class we'll need
to add only translation to and from the neutral format.

\subsubsection{Write formatted}

·d class Fmt
·{·%
# Method used internally to format a neutral numeral
def nio_write_formatted(neutral)
  str = ''     
  if neutral.special?
    str << neutral.sign
    case neutral.special
      when :inf
        str << @inf_txt
      when :nan
        str << @nan_txt
    end    
  else
    zero = get_base_digits(neutral.base).digit_char(0).chr 
    neutral = neutral.dup
    round! neutral
    if neutral.zero?
      str << neutral.sign if neutral.sign=='-' # show - if number was <0 before rounding
      str << zero
      if @ndec.kind_of?(Numeric) && @ndec>0 && @mode==:fix
        str << @dec_sep << zero*@ndec
      end
    else
      ·<Format neutral·>
    end
  end
  ·<show base suffix·>
  ·<Adjust field width and justify·>
  return str
end
·}

·d class Fmt
·{·%
# round a neutral numeral according to the format options
def round!(neutral)
  neutral.round! @ndec, @mode, @round
end
·}

First we'll determine which kind of format to apply.

·d Format neutral
·{·%
neutral.trimLeadZeros
actual_mode = @mode
trim_trail_zeros = !@all_digits # false
·<compute scientific notation exponent·>    
case actual_mode
  when :gen # general (automatic)
    # @ndec means significant digits
    actual_mode = :sig
    actual_mode = :sci if use_scientific?(neutral, exp)
    trim_trail_zeros = !@all_digits # true
end
·}

We'll use a 
variable \cd{@@sci\_fmt} to choose when to apply scientific notation in the general format;
the alternatives are the traditional C (printf) style and that used in HP calculators.

·d class Fmt
·{·%
@@sci_fmt = nil
·}

·d Fmt protected
·{·%
def use_scientific?(neutral,exp) # :nodoc:
  nd = @ndec.kind_of?(Numeric) ? @ndec : neutral.digits.length
  if @@sci_fmt==:hp
    # revisar, no funciona bien    
    neutral.dec_pos>nd || ([neutral.digits.length,nd].min-neutral.dec_pos)>nd
  else
    exp<-4 || exp>=nd 
  end
end
·}

Now we know which format to apply and proceed.

·d Format neutral
·{·%
case actual_mode  
  when :fix, :sig #, :gen
    ·<Format neutral :fix·>  
  when :sci
    ·<Format neutral :sci·>    
end
·}

·d compute scientific notation exponent 
·{·%
integral_digits = @sci_format
if integral_digits == :eng
  integral_digits = 1
  while (neutral.dec_pos - integral_digits).modulo(3) != 0
    integral_digits += 1
  end
elsif integral_digits==:all || integral_digits < 0
  if neutral.inexact? && @non_sig!='' && @ndec.kind_of?(Numeric)
    integral_digits = @ndec
  else
    integral_digits = neutral.digits.length
  end
end
exp = neutral.dec_pos - integral_digits
·}

·d Format neutral :fix
·{·%
str << neutral.sign if @show_plus || neutral.sign!='+'
·<show base prefix·>
if @ndec==:exact
  neutral.sign = '+'
  str << neutral.to_RepDec.getS(@rep_n, getRepDecOpt(neutral.base))
else
  #zero = get_base_digits.digit_char(0).chr
  ns_digits = ''
  ·<compute non-significant digits filler·>
  digits = neutral.digits + ns_digits
  if neutral.dec_pos<=0
    str << zero+@dec_sep+zero*(-neutral.dec_pos) + digits
  elsif neutral.dec_pos >= digits.length 
    str << group(digits + zero*(neutral.dec_pos-digits.length))
  else
    str << group(digits[0...neutral.dec_pos]) + @dec_sep + digits[neutral.dec_pos..-1]
  end
end
·<handle trailing zeros·>
·}

·d compute non-significant digits filler
·{·%
nd = neutral.digits.length
if actual_mode==:fix
  nd -= neutral.dec_pos
end
if neutral.inexact? && @ndec>nd # assert no rep-dec.
  ns_digits = @non_sig*(@ndec-nd)
end
·}


·d handle trailing zeros
·{·%
#str = str.chomp(zero).chomp(@dec_sep) if trim_trail_zeros && str.include?(@dec_sep)
if trim_trail_zeros && str.include?(@dec_sep) &&  str[-@rep_auto.size..-1]!=@rep_auto
  str.chop! while str[-1]==zero[0]
  str.chomp!(@dec_sep)
  #puts str
end
·}

·d show base prefix
·{·%
if @show_base && @base_prefix
  b_prefix = @base_indicators[neutral.base]
  str << b_prefix if b_prefix
end
·}

Esto no funciona bien: produce errores...

·d show base suffix
·{·%
if @show_base && !@base_prefix
  b_prefix = @base_indicators[neutral.base]
  str << b_prefix if b_prefix
end
·}

\begin{verbatim}
# to do: mantissa options:
# 1/base <= m < base (0 integral digits)
# 1 <= m < base (1 integral digits)
# m integer
\end{verbatim}

·d Format neutral :sci
·{·%
str << neutral.sign if @show_plus || neutral.sign!='+'
·<show base prefix·>
#zero = get_base_digits.digit_char(0).chr
if @ndec==:exact
  neutral.sign = '+'
  neutral.dec_pos-=exp
  str << neutral.to_RepDec.getS(@rep_n, getRepDecOpt(neutral.base))  
else
  ns_digits = ''
  ·<compute non-significant digits filler·>
  digits = neutral.digits + ns_digits
  str << ((integral_digits<1) ? zero : digits[0...integral_digits])
  str << @dec_sep
  str << digits[integral_digits...@ndec]
  pad_right =(@ndec+1-str.length) 
  str << zero*pad_right if pad_right>0 && !neutral.inexact? # maybe we didn't have enought digits
end
·<handle trailing zeros·>
str << get_exp_char(neutral.base)
str << exp.to_s
·}


There is one thing in which neutral numerals are not really neutral:
they are already in some specific numeric base.
This poses some problems: do we require neutral writers to 
use the desired base?, do we require neutral readers to admit any base?
do we do base conversion of neutrals?


·d Adjust field width and justify
·{·%
if @width>0 && @fill_char!=''
  l = @width - str.length
  if l>0
    case @adjust
      when :internal
        sign = ''
        if str[0,1]=='+' || str[0,1]=='-' 
          sign = str[0,1]
          str = str[1...str.length]
        end
        str = sign + @fill_char*l + str
      when :center
        str = @fill_char*(l/2) + str + @fill_char*(l-l/2)
      when :right
        str = @fill_char*l + str
      when :left
        str = str + @fill_char*l
    end
  end    
end
·}


\subsubsection{Read formatted}


·d class Fmt
·{·%
def nio_read_formatted(txt)
  txt = txt.dup
  num = nil
   
  base = nil
  ·<Extract base from txt·>
  base ||= get_base
 
  zero = get_base_digits(base).digit_char(0).chr 
  txt.tr!(@non_sig,zero) # we don't simply remove it because it may be before the radix point 
  
  exp = 0
  x_char = get_exp_char(base)
  ·<Extract exponent from txt·>

  opt = getRepDecOpt(base)
  if @rep_in
    #raise NumFormatError,"Invalid numerical base" if base!=10
    rd = RepDec.new # get_base not necessary: setS sets it from options
    rd.setS txt, opt
    num = rd.to_NeutralNum(opt.digits)
  else
    # to do: use RepDec.parse; then build NeutralNum directly
    opt.set_delim '',''
    opt.set_suffix ''
    rd = RepDec.new # get_base not necessary: setS sets it from options
    rd.setS txt, opt
    num = rd.to_NeutralNum(opt.digits)
  end
  num.rounding = get_round
  num.dec_pos += exp
  return num
end
·}

·d Extract exponent from txt
·{·%
exp_i = txt.index(x_char)
exp_i = txt.index(x_char.downcase) if exp_i===nil
if exp_i!=nil
  exp = txt[exp_i+1...txt.length].to_i
  txt = txt[0...exp_i] 
end    
·}

To do: extract base indicator from txt (prefix or suffix)
and set \cd{base} accordingly.
·d Extract base from txt ·{·}


\subsection{Auxiliar functions}

We need to interoperate with \cd{RepDec}. 
The next method will generate\cd{RepDec} options 
using the formatting definitions.

·d Fmt protected
·{·%
def getRepDecOpt(base=nil)
  rd_opt = RepDec::Opt.new
  rd_opt.begin_rep = @rep_begin
  rd_opt.end_rep = @rep_end
  rd_opt.auto_rep = @rep_auto
  rd_opt.dec_sep = @dec_sep
  rd_opt.grp_sep = @grp_sep
  rd_opt.grp = @grp
  rd_opt.inf_txt = @inf_txt
  rd_opt.nan_txt = @nan_txt    
  rd_opt.set_digits(get_base_digits(base))
#  if base && (base != get_base_digits.radix)
#    rd_opt.set_digits(get_base_digits(base))
#  else
#    rd_opt.set_digits get_base_digits
#  end
  return rd_opt
end
·}

We need to group digits, but that functionality is already
available in \cd{RepDec}.

·d Fmt protected
·{·%
def group(digits)
  RepDec.group_digits(digits, getRepDecOpt)
end
·}

\section{Formatting Functions}

To facilitate the addition of formatting capabilities
to numerical classes, we'll define a mix-in module \c{Formattable}
.

·d Nio classes
·{·%
# This is a mix-in module to add formatting capabilities no numerical classes.
# A class that includes this module should provide the methods
# nio_write_neutral(fmt):: an instance method to write the value to
#                          a neutral numeral. The format is passed so that
#                          the base, for example, is available.
# nio_read_neutral(neutral):: a class method to create a value from a neutral
#                             numeral.
module Formattable
  ·<Formattable mix-in·>  
end
·}

We will add also a repository of common formats; this was originally done
in the same module as \cd{Formattable}; I've moved it now to \cd{Fmt}.

·d Nio classes
·{·%
class Fmt
  ·<Formats Repository·>  
end
·}



\subsection{Formattable mix-in}

Numerical classes such as \cd{Float} will need to \cd{include} this
module that provides both an instance method and a class method to the class
to perform formatting.
The numerical class, in turn, will have to implement another two methods
(also one instance and another class-based) to convert to and from 
neutral numerals.

This will be an instance method in the numeric class to convert the number
to formatted text; the numeric class must provide
the instance method \cd{nio\_write\_neutral}; this method is passed the 
format as a parameter because some information about the destination
format, such as the base, may be needed.


·d Formattable mix-in
·{·%
def nio_write(fmt=Fmt.default)
  neutral = nio_write_neutral(fmt)
  fmt.nio_write_formatted(neutral)
end
·}


Now we'll provide a class method to the including numerical class;
for that we'll use an inner module \cd{ClassMethods}.
The method \cd{nio\_read} will convert formatted text to a numerical object;
the numerical class must provide the class method \cd{read\_neutral}.
·d Formattable mix-in
·{·%
module ClassMethods
  def nio_read(txt,fmt=Fmt.default)
    neutral = fmt.nio_read_formatted(txt)
    nio_read_neutral neutral      
  end
end
·}


We'll add a method to round a number using a given format's rounding options.
·d Formattable mix-in
·{·%
def nio_round(fmt=Fmt.default)
  neutral = nio_write_neutral(fmt)
  fmt.round! neutral
  self.class.nio_read_neutral neutral      
end
·}


Finally we need some trickery to add the class method to the numerical class.
  
·d Formattable mix-in
·{·%
def self.append_features(mod)
  super
  mod.extend ClassMethods
end
·}
  
When we add the mixing to a class such as \cd{Float} and implement the needed
methods we can read and write formatted values like this:
·d scratch
·{·%
x = Float.nio_read(txt,fmt)
txt = x.nio_write(fmt)
·}

If we have a number \cd{y} we can read another of the same type like this:
·d scratch
·{·%
z = y.class.nio_read(txt,fmt)
·}


\subsection{Formats Repository}

Class \cd{Fmt} will also act as a namespace to 
mantain a formats repository:

·d Formats Repository
·{      
@@fmts = {
   ·<Predefined Formats·>
   :def=>Fmt.new.freeze #default format
}
def self.default
  get(:def)
end
def self.default=(fmt)
  define(:def,fmt)
end
def self.define(tag,fmt_def)
  @@fmts[tag]=fmt_def.freeze
end
def self.get(tag)
  @@fmts[tag]
end
·}

To do: distinguish locale-variant aspects, have locale repository that applies
only those aspects.

Note that since shared objects are returned (that's the point of the repository: to share formats),
those objects should not be modified; if we want to use a variant of a common format, \cd{dup}
shoul be used:
\begin{verbatim}
  p x.nio_write Fmt.get(:es).dup.mode(:sig,5)
\end{verbatim}

\subsubsection{Common Formats}

Spanish decimal separator:
·d Predefined Formats ·{:es=>Fmt.sep(',','.').freeze,·}

Spanish decimal separator with thousands groupings:
·d Predefined Formats ·{:es_th=>Fmt.sep(',','.',[3]).freeze,·}

Internal Ruby format: plain english format:
·d Predefined Formats ·{:ruby=>Fmt.new.freeze,·}
·d Predefined Formats ·{:en=>Fmt.new.freeze,·}

With thousands separators:
·d Predefined Formats ·{:en_th=>Fmt.sep('.',',',[3]).freeze,·}

SQL format; like Ruby. (maybe should change precision?)
·d Predefined Formats ·{:sql=>Fmt.new.freeze,·}



\subsection{Numerical classes support}

\subsubsection{Float}

·d definitions
·{·%
class Float
  include Nio::Formattable
  def self.nio_read_neutral(neutral)   
    x = nil
    ·<Read Float x from neutral·> 
    return x
  end
  def nio_write_neutral(fmt)
    neutral = Nio::NeutralNum.new
    x = self
    ·<Write Float x to neutral·>     
    return neutral
  end  
end
·}

Here we add a switch to avoid using some short-cut conversions when
the rounding mode must be strictly obeyed.

·d Read Float x from neutral
·{·%
honor_rounding = true
·}


·d Read Float x from neutral
·{·%
if neutral.special?
  case neutral.special
    when :nan
      x = 0.0/0.0
    when :inf
      x = (neutral.sign=='-' ? -1.0 : +1.0)/0.0
  end
elsif neutral.rep_pos<neutral.digits.length  
  ·<Read Float from repeating decimal·>
else
  nd = neutral.base==10 ? Float::DIG : ((Float::MANT_DIG-1)*Math.log(2)/Math.log(neutral.base)).floor 
  k = neutral.dec_pos-neutral.digits.length
  if !honor_rounding && (neutral.digits.length<=nd && k.abs<=15)
    x = neutral.digits.to_i(neutral.base).to_f
    if k<0
      x /= Float(neutral.base**-k)
    else
      x *= Float(neutral.base**k)
    end
    x = -x if neutral.sign=='-'
  elsif !honor_rounding && (k>0 && (k+neutral.digits.length < 2*nd))
    j = k-neutral.digits.length
    x = neutral.digits.to_i(neutral.base).to_f * Float(neutral.base**(j))
    x *= Float(neutral.base**(k-j))
    x = -x if neutral.sign=='-'
  elsif neutral.base.modulo(Float::RADIX)==0
   ·<Read Float from conmesurable base text·>
  else
   ·<Read Float from text·>
  end
end
·}

·d Read Float from repeating decimal
·{·%
x,y = neutral.to_RepDec.getQ
x = Float(x)/y
·}

With the current implementation, rounding could not be correct
for specific precision and approx. mode \cd{:only\_sig} and
\cd{show\_all\_digits}; the \cd{:exact} approx. mode could be used
to check the digits.

·d Write Float x to neutral
·{·%
if x.nan?
  neutral.set_special(:nan)
elsif x.infinite?
  neutral.set_special(:inf, x<0 ? '-' : '+')
else
  converted = false
  if fmt.get_ndig==:exact && fmt.get_approx==:simplify
    ·<Try to convert Float to repeating decimal·>
  elsif fmt.get_approx==:exact
    neutral = x.nio_xr.nio_write_neutral(fmt)
    converted = true
  end
  if !converted  
    if fmt.get_base==10 && ·<use native float format?·>
      txt = format "%.*e",Float::DECIMAL_DIG-1,x # note that spec. e output precision+1 significant digits
      ·<Convert Floating Point Expression to Neutral·>
      converted = true
    end
  end
  if !converted
    ·<Convert Floating Point Expresion to Neutral base·>
  end
end
·}

We are not going to use the Ruby \cd{format} method so that we can avoid
outputting not-significant digits and also generate as few digits as possible
(unless the format specifies "show all digits").

·d use native float format? ·{false·}


Reading a number in the internal base or a multiple of it is easy,
but this is not yet implemented.
Sketch of method:
\begin{verbatim}
  k = neutral.base/Float::RADIX
 convert neutral to Float::RADIX by converting each digit into k digits
  neutral.round! Float::MANT_DIG, :sig
  m = neutral.digits.to_i(Float::RADIX).to_f
  e = neutral.dec_pos-neutral.digits.length
  x = Math.ldexp(m,e)
  x = -x if neutral.sign=='-'
\end{verbatim}
We'll use the general method until this is implemented:
·d Read Float from conmesurable base text
·{·<Read Float from text·>·}


Now we'll implement correct rounding.

·d Read Float from text
·{·%
f = neutral.digits.to_i(neutral.base)
e = neutral.dec_pos-neutral.digits.length
·<set rounding mode·(neutral.sign=='-'·,neutral.rounding·)·>
x = Nio::Clinger::algM(f,e,rounding,neutral.base,Float::RADIX,Float::MANT_DIG,Float::MIN_EXP-Float::MANT_DIG,Float::MAX_EXP-Float::MANT_DIG)
x = -x if neutral.sign=='-'
·}

This was the provisional, simplistic old method:

·d Read Float from text OLD
·{·%
x = neutral.digits.to_i(neutral.base).to_f
x *= Float(neutral.base)**(neutral.dec_pos-neutral.digits.length)
x = -x if neutral.sign=='-'
·}


This is Clinger's \cd{AlgorithmM} modified to handle denormalized
numbers and cope with overflow.
It is a first step to experiment with exact rounding: this
method rounds correctly but it's slow.

·d Nio private functions
·{·%
module Clinger # :nodoc: all
module_function
·<Clinger functions·>
end
·}

·d Clinger functions
·{·%
def algM(f,e,round_mode,eb=10,beta=Float::RADIX,n=Float::MANT_DIG,min_e=Float::MIN_EXP-Float::MANT_DIG,max_e=Float::MAX_EXP-Float::MANT_DIG)

  if e<0
   u,v,k = f,eb**(-e),0
  else
    u,v,k = f*(eb**e),1,0
  end
  
  loop do
     x = u.div(v)
     # overflow if k>=max_e 
     if (x>=beta**(n-1) && x<beta**n) || k==min_e || k==max_e
        return ratio_float(u,v,k,round_mode,beta,n)
     elsif x<beta**(n-1)
       u *= beta
       k -= 1
     elsif x>=beta**n
       v *= beta
       k += 1         
     end     
  end

end
·}

·d Clinger functions
·{·%
def ratio_float(u,v,k,round_mode,beta=Float::RADIX,n=Float::MANT_DIG)
  q = u.div v
  r = u-q*v
  v_r = v-r
  z = Math.ldexp(q,k)
  if r<v_r
    z
  elsif r>v_r
    nextfloat z
  elsif (round_mode==:even && q.even?) || (round_mode==:inf_neg)
    z
  else
    nextfloat z
  end
end
·}

·d Clinger functions
·{·%
def nextfloat(x)
  f,e = Math.frexp(x)  
  e = Float::MIN_EXP if f==0
  e = [Float::MIN_EXP,e].max
  dx = Math.ldexp(1,e-Float::MANT_DIG) #Math.ldexp(Math.ldexp(1.0,-Float::MANT_DIG),e)  
  x + dx
end

def prevfloat(x)
  f,e = Math.frexp(x)  
  e = Float::MIN_EXP if f==0
  e = [Float::MIN_EXP,e].max
  dx = Math.ldexp(1,e-Float::MANT_DIG) #Math.ldexp(Math.ldexp(1.0,-Float::MANT_DIG),e)  
  if e==Float::MIN_EXP || f!=0.5 #0.5==Math.ldexp(2**(bits-1),-Float::MANT_DIG)
    x - dx
  else
    x - dx/2 # x - Math.ldexp(Math.ldexp(1.0,-Float::MANT_DIG),e-1)  
  end
end
·}


·d references
·{·%
require 'nio/rtnlzr'
·}


Floating point numbers should not be converted directly to repeating
decimals due to its approximate nature. But for type conversions, 
using a simpler approximate representation can be useful.
We will try to convert to a repeating decimal within a tolerance
appropiate for Float, but we will reject the result
if too many digits are produced. That will be the case, when
the smallest denominator fraction that approximates the number within the
given tolerance produces a very long repetition (or a very long sequence before repetition).

Possible values for the tolerance are:
\begin{verbatim}
Tolerance.decimals(Float::DIG,:sig)
Tolerance.big_epsilon
Tolerance.epsilon
\end{verbatim}

·d Try to convert Float to repeating decimal
·{·%
if x!=0
  q = x.nio_r(Nio::Tolerance.decimals(Float::DIG,:sig))
  if q!=0
    neutral = q.nio_write_neutral(fmt)
    converted = true if neutral.digits.length<=Float::DIG
  end
end
·}


·d Convert Floating Point Expression to Neutral
·{·%
sign = '+'    
if txt[0,1]=='-'
  sign = '-'
  txt = txt[1...txt.length]
end
exp = 0
x_char = fmt.get_exp_char(fmt.get_base)
·<Extract exponent from txt·>
dec_pos = txt.index '.'
if dec_pos==nil
  dec_pos = txt.length 
else
  txt[dec_pos]=''
end
dec_pos += exp
neutral.set sign, txt, dec_pos, nil, fmt.get_base_digits(10), true, fmt.get_round
·}

If we have to deal with bases different from 10 we'll use an
algorithm from \cite[3]{3} by Burger and Dybvig.
We may later write a C extension using dtoa.c by David M. Gay
for decimal read/write in free and fixed form.
An interesting addition would be an option to distinguish
non-significative digits. There's also C code by Burger in free.c
for fixed format base 10.


Note that the minimum exponent here, which is the exponent of 
denormalized numbers, is the exponent that applies to the mantissa
interpreted as an integer, so we must decrement the \verb|Float::MIN_EXP|
---which applies to the mantissa interpreted with a radix point before
the first digit--- in the number of bits of the mantissa.

·d Convert Floating Point Expresion to Neutral base
·{·%
sign = x<0 ? '-' : '+'
x = -x if sign=='-'
f,e = Math.frexp(x)
if e < Float::MIN_EXP
  # denormalized number
  f = Math.ldexp(f,e-Float::MIN_EXP+Float::MANT_DIG)
  e = Float::MIN_EXP-Float::MANT_DIG
else
  # normalized number
  f = Math.ldexp(f,Float::MANT_DIG)
  e -= Float::MANT_DIG
end
f = f.to_i
inexact = true
·<set rounding mode·(sign=='-'·,fmt.get_round·)·>
if fmt.get_all_digits?
  # use as many digits as possible
  dec_pos,r,*digits = Nio::BurgerDybvig::float_to_digits_max(x,f,e,rounding,Float::MIN_EXP-Float::MANT_DIG,Float::MANT_DIG,Float::RADIX,fmt.get_base)
  inexact = :roundup if r
else
  # use as few digits as possible
  dec_pos,*digits = Nio::BurgerDybvig::float_to_digits(x,f,e,rounding,Float::MIN_EXP-Float::MANT_DIG,Float::MANT_DIG,Float::RADIX,fmt.get_base)
end
txt = ''
digits.each{|d| txt << fmt.get_base_digits.digit_char(d)}
neutral.set sign, txt, dec_pos, nil, fmt.get_base_digits, inexact, fmt.get_round
·}

·d set rounding mode
·{·%
rounding = ·2
if ·1
  if rounding == :inf_pos
    rounding = :inf_neg
  elsif rounding== :inf_neg
    rounding = :inf_pos
  end   
end
·}


Burger and Dybvig free formatting algorithm, translated directly from Scheme;
after some testing, of the three different implementations in its
paper, the second seems to be more efficient in Ruby.


·d Nio private functions
·{·%
module BurgerDybvig # :nodoc: all
module_function
·<Burger-Dybvig functions·>
end
·}

·d Burger-Dybvig functions
·{·%
def float_to_digits(v,f,e,round_mode,min_e,p,b,_B)
 ·<set rounding low and high flags·> 
    if e >= 0
      if f != exptt(b,p-1)
        be = exptt(b,e)
        r,s,m_p,m_m,k = scale(f*be*2,2,be,be,0,_B,roundl ,roundh,v)
      else
        be = exptt(b,e)
        be1 = be*b
        r,s,m_p,m_m,k = scale(f*be1*2,b*2,be1,be,0,_B,roundl ,roundh,v)
      end
    else
      if e==min_e or f != exptt(b,p-1)
        r,s,m_p,m_m,k = scale(f*2,exptt(b,-e)*2,1,1,0,_B,roundl ,roundh,v)
      else
        r,s,m_p,m_m,k = scale(f*b*2,exptt(b,1-e)*2,b,1,0,_B,roundl ,roundh,v)
      end
    end
    [k]+generate(r,s,m_p,m_m,_B,roundl ,roundh)
end
·}

The \cd{roundl} and \cd{roundh} flags indicate if the lower and upper
rounding limits are rounded to the number.
Note that we handle only non-negative numbers.

The rounding mode is the one that is used in the floating
point numbers.

·d set rounding low and high flags
·{·%
case round_mode
  when :even
    roundl = roundh = f.even?
  when :inf_pos, :inf
    roundl = true
    roundh = false
  when :inf_neg
    roundl = false
    roundh = true
  else
    # here we don't assume any rounding in the floating point numbers
    # the result is valid for any rounding
    roundl = false
    roundh = false
end
·}

·d Burger-Dybvig functions
·{·%
def scale(r,s,m_p,m_m,k,_B,low_ok ,high_ok,v)
  return scale2(r,s,m_p,m_m,k,_B,low_ok ,high_ok) if v==0
  est = (logB(_B,v)-1E-10).ceil.to_i
  if est>=0 
    fixup(r,s*exptt(_B,est),m_p,m_m,est,_B,low_ok,high_ok)
  else
    sc = exptt(_B,-est)
    fixup(r*sc,s,m_p*sc,m_m*sc,est,_B,low_ok,high_ok)
  end
end

def fixup(r,s,m_p,m_m,k,_B,low_ok,high_ok)
  if (high_ok ? (r+m_p >= s) : (r+m_p > s)) # too low?
    [r,s*_B,m_p,m_m,k+1]
  else
    [r,s,m_p,m_m,k]
  end
end
·}

Esta es la versión original iterativa: la usaremos para  el valor 0.
·d Burger-Dybvig functions
·{·%
def scale2(r,s,m_p,m_m,k,_B,low_ok ,high_ok)
  loop do
    if (high_ok ? (r+m_p >= s) : (r+m_p > s)) # k is too low
      s *= _B
      k += 1
    elsif (high_ok ? ((r+m_p)*_B<s) : ((r+m_p)*_B<=s)) # k is too high
      r *= _B
      m_p *= _B
      m_m *= _B
      k -= 1
    else
      break
    end
  end
  [r,s,m_p,m_m,k]
end
·}


·d Burger-Dybvig functions
·{·%
def generate(r,s,m_p,m_m,_B,low_ok ,high_ok)
  list = []
  loop do
    d,r = (r*_B).divmod(s)
    m_p *= _B
    m_m *= _B
    tc1 = low_ok ? (r<=m_m) : (r<m_m)
    tc2 = high_ok ? (r+m_p >= s) : (r+m_p > s)

     if not tc1
      if not tc2
        list << d
      else
        list << d+1
        break
      end
    else
      if not tc2
        list << d
        break
      else
        if r*2 < s
          list << d
          break
        else
          list << d+1
          break
        end
      end
    end
    
  end
  list
end
·}

·d Burger-Dybvig functions
·{·%
$exptt_table = Array.new(326)
(0...326).each{|i| $exptt_table[i]=10**i}
def exptt(_B, k)
  if _B==10 && k>=0 && k<326 
    $exptt_table[k]
  else
    _B**k
  end
end

$logB_table = Array.new(37)
(2...37).each{|b| $logB_table[b]=1.0/Math.log(b)}
def logB(_B, x)
  if _B>=2 && _B<37
    Math.log(x)*$logB_table[_B]
  else
    Math.log(x)/Math.log(_B)
  end
end
·}


We need an additional method \cd{even?} for numeric quantities;
we'll also add \cd{odd?} for completeness.

·d definitions
·{·%
class Numeric
  unless method_defined?(:even?)
    def even?
      self.modulo(2)==0
    end
  end
  unless method_defined?(:odd?)
    def odd?
      self.modulo(2)!=0
    end
  end
end
·}


We'll derive, from the previous method, another one to generate all 
significative digits, i.e. all digits that, if used on input, cannot
arbitrarily change its value and preserve the parsed value of the
floating point number.
This will be useful to generate a fixed number of digits or if
as many digits as possible are required.

This method returns an additional logical value that 
tells if the last digit should be rounded-up.

·d Burger-Dybvig functions
·{·%
def float_to_digits_max(v,f,e,round_mode,min_e,p,b,_B)
 ·<set rounding low and high flags·> 
    if e >= 0
      if f != exptt(b,p-1)
        be = exptt(b,e)
        r,s,m_p,m_m,k = scale(f*be*2,2,be,be,0,_B,roundl ,roundh,v)
      else
        be = exptt(b,e)
        be1 = be*b
        r,s,m_p,m_m,k = scale(f*be1*2,b*2,be1,be,0,_B,roundl ,roundh,v)
      end
    else
      if e==min_e or f != exptt(b,p-1)
        r,s,m_p,m_m,k = scale(f*2,exptt(b,-e)*2,1,1,0,_B,roundl ,roundh,v)
      else
        r,s,m_p,m_m,k = scale(f*b*2,exptt(b,1-e)*2,b,1,0,_B,roundl ,roundh,v)
      end
    end
    [k]+generate_max(r,s,m_p,m_m,_B,roundl ,roundh)
end
·}


  
·d Burger-Dybvig functions
·{·%
def generate_max(r,s,m_p,m_m,_B,low_ok ,high_ok)
  list = [false]
  loop do
    d,r = (r*_B).divmod(s)
    m_p *= _B
    m_m *= _B
    
    list << d
        
    tc1 = low_ok ? (r<=m_m) : (r<m_m)
    tc2 = high_ok ? (r+m_p >= s) : (r+m_p > s)
        
    if tc1 && tc2
      list[0] = true if r*2 >= s
      break
    end    
  end
  list
end
·}

\subsubsection{Integer}

·d definitions
·{·%
class Integer
  include Nio::Formattable
  def self.nio_read_neutral(neutral)   
    x = nil
    ·<Read Integer x from neutral·> 
    return x
  end
  def nio_write_neutral(fmt)
    neutral = Nio::NeutralNum.new
    x = self
    ·<Write Integer x to neutral·>     
    return neutral
  end
end
·}

·d Nio classes
·{·%
class NumFormatError <StandardError
end
·}


·d Read Integer x from neutral
·{·%
if neutral.special?
  raise Nio::NumFormatError,"Invalid integer numeral"
elsif neutral.rep_pos<neutral.digits.length  
  return Rational.nio_read_neutral(neutral).to_i
else
  digits = neutral.digits
  ·<adjust digits string for integer·>
  x = digits.to_i(neutral.base)
# this was formely needed because we didn't adust the digits
#  if neutral.dec_pos != neutral.digits.length
#    # with rational included, negative powers of ten are rational numbers
#    x = (x*((neutral.base)**(neutral.dec_pos-neutral.digits.length))).to_i   
#  end
  x = -x if neutral.sign=='-'
end
·}

·d adjust digits string for integer
·{·%
if neutral.dec_pos <= 0
  digits = '0'
elsif neutral.dec_pos <= digits.length
  digits = digits[0...neutral.dec_pos]
else
  digits = digits + '0'*(neutral.dec_pos-digits.length)  
end
·}


·d Write Integer x to neutral
·{·%
sign = x<0 ? '-' : '+'
txt = x.abs.to_s(fmt.get_base)
dec_pos = rep_pos = txt.length  
neutral.set sign, txt, dec_pos, nil, fmt.get_base_digits, false ,fmt.get_round
·}

\subsubsection{Rational}

·d references
·{·%
require 'rational'
·}

·d definitions
·{·%
class Rational
  include Nio::Formattable
  def self.nio_read_neutral(neutral)   
    x = nil
    ·<Read Rational x from neutral·> 
    return x
  end
  def nio_write_neutral(fmt)
    neutral = Nio::NeutralNum.new
    x = self
    ·<Write Rational x to neutral·>     
    return neutral
  end
end
·}

·d Read Rational x from neutral
·{·%
if neutral.special?
  case neutral.special
    when :nan
      x = Rational(0,0)
    when :inf
      x = Rational((neutral.sign=='-' ? -1 : +1),0)
  end
else
  x = Rational(*neutral.to_RepDec.getQ)
end
·}


·d Write Rational x to neutral
·{·%
if x.denominator==0
  if x.numerator>0    
    neutral.set_special(:inf)
  elsif x.numerator<0
    neutral.set_special(:inf,'-')
  else
    neutral.set_special(:nan)
  end
else
  if fmt.get_base==10
    rd = Nio::RepDec.new.setQ(x.numerator,x.denominator)
  else
    opt = Nio::RepDec::DEF_OPT.dup.set_digits(fmt.get_base_digits)
    rd = Nio::RepDec.new.setQ(x.numerator,x.denominator, opt)
  end
  neutral = rd.to_NeutralNum(fmt.get_base_digits)
  neutral.rounding = fmt.get_round
end
·}


\subsubsection{BigDecimal}

·d references
·{·%
require 'bigdecimal'
·}


·d definitions
·{·%
if defined? BigDecimal
class BigDecimal
  include Nio::Formattable
  def self.nio_read_neutral(neutral)   
    x = nil
    ·<Read BigDecimal x from neutral·> 
    return x
  end
  def nio_write_neutral(fmt)
    neutral = Nio::NeutralNum.new
    x = self
    ·<Write BigDecimal x to neutral·>     
    return neutral
  end
end
end
·}


·d Read BigDecimal x from neutral
·{·%
if neutral.special?
  case neutral.special
    when :nan
      x = BigDecimal('NaN') # BigDecimal("0")/0
    when :inf
      x = BigDecimal(neutral.sign=='-' ? '-1.0' : '+1.0')/0
  end
elsif neutral.rep_pos<neutral.digits.length  
  ·<Read BigDecimal from repeating decimal·>
else
  if neutral.base==10
    #x = BigDecimal(neutral.digits)
    #x *= BigDecimal("1E#{(neutral.dec_pos-neutral.digits.length)}")
    #x = -x if neutral.sign=='-'
    str = neutral.sign
    str += neutral.digits
    str += "E#{(neutral.dec_pos-neutral.digits.length)}"
    x = BigDecimal(str)
  else
    x = BigDecimal(neutral.digits.to_i(neutral.base).to_s)    
    x *= BigDecimal(neutral.base.to_s)**(neutral.dec_pos-neutral.digits.length)
    x = -x if neutral.sign=='-'
  end
end
·}

·d Read BigDecimal from repeating decimal
·{·%
x,y = neutral.to_RepDec.getQ
x = BigDecimal(x.to_s)/y
·}

·d Write BigDecimal x to neutral
·{·%
if x.nan?
  neutral.set_special(:nan)
elsif x.infinite?
  neutral.set_special(:inf, x<0 ? '-' : '+')
else  
  converted = false
  if fmt.get_ndig==:exact && fmt.get_approx==:simplify
    ·<Try to convert BigDecimal to repeating decimal·>
  elsif fmt.get_approx==:exact && fmt.get_base!=10
    neutral = x.nio_xr.nio_write_neutral(fmt)
    converted = true
  end
  if !converted 
    if fmt.get_base==10 
      txt = x.to_s
      ·<Convert Floating Point Expression to Neutral·>
    end
  end  
  if !converted
    ·<Convert BigDecimal Expression to Neutral base·>
  end
end
·}


Using the Burger-Dybvig method with BigDecimal doesn't seem to be a good
idea: BigDecimal has variable precision but we must set a fixed precision
to apply the method. If use a higher precision than the current precision
used in the number we might be ussing non-significative digits
(e.g. for $x=1/3$). But the actual precision might be very low
for conversion (e.g. for $x=0.1$) even though in decimal the 
representation is exact.
I have choosen a minimum precision of $24$, because that's what you
get for \verb|BigDecimal('1')/3|. Non exact numbers should be
computed or defined with that precision at least to avoid using
non-significative digits.

The problem with Burger-Dybvig it that it relies on the precision
of the floating type (in the gaps between consecutive numbers) to
give the shortest representation that will be parsed back to the
same number (with the fixed precision). But the representation
may convert to a diferent \cd{BigDecima} if more precision is used.

·d Convert BigDecimal Expression to Neutral base
·{·%
min_prec = 24
min_exp  = -1000
s,f,b,e = x.split
e -= f.size
sign = s<0 ? '-' : '+'
x = -x if sign=='-'
f_i = f.to_i
prc = [x.precs[0],min_prec].max
f_i *= 10**(prc-f.size)
e -= (prc-f.size)

inexact = true
·<set rounding mode·(sign=='-'·,fmt.get_round·)·>
if fmt.get_all_digits?
  # use as many digits as possible
  dec_pos,r,*digits = Nio::BurgerDybvig::float_to_digits_max(x,f_i,e,rounding,[e,min_exp].min,prc,b,fmt.get_base)
  inexact = :roundup if r
else
  # use as few digits as possible
  dec_pos,*digits = Nio::BurgerDybvig::float_to_digits(x,f_i,e,rounding,[e,min_exp].min,prc,b,fmt.get_base)
end
txt = ''
digits.each{|d| txt << fmt.get_base_digits.digit_char(d)}
neutral.set sign, txt, dec_pos, nil, fmt.get_base_digits, inexact, fmt.get_round
·}


Note: we could also use \cd{BigDecimal\#split} for conversion to neutral.

·d Alternative BigDecimal x to neutral
·{·%
if x.nan?
  neutral.set_special(:nan)
elsif x.infinite?
  neutral.set_special(:inf, x<0 ? '-' : '+')
else  
  sgn,dgs,bs,ex = split
  sgn = case sgn; when -1 then '-'; when +1 then '+'; else ''; end
  neutral.set sgn, dgs, ex, nil, fmt.get_base_digits(bs), false, fmt.get_round
end
·}


·d Try to convert BigDecimal to repeating decimal
·{·%
prc = [x.precs[0],20].max
neutral = x.nio_r(Nio::BigTolerance.decimals(prc,:sig)).nio_write_neutral(fmt)
converted = true if neutral.digits.length<prc
·}


\subsection{Numerical type conversion}

El \ex{mixing} \cd{Precision} permite la conversión de un tipo numérico a otro 
usando \cd{x.prec(type)}, por ejemplo \cd{3.prec(Float)}.
Pero no todos los tipos numéricos lo implementan de forma completa: \cd{Rational} incluye
el mixin, y \cd{BigDecimal} sólo de forma parcial.
Usando texto como formato intermedio podemos usar \cd{Fmt} para realizar la conversión
entre dos tipos que implementen \cd{Formattable}. En lugar de tratar de completar
el uso de \cd{Precision} vamos a añadir un interfaz a \cd{Fmt} para realizar estas conversiones.

·d Nio classes
·{·%
class Fmt
  # formato intermedio de conversión:
  CONV_FMT = Fmt.prec(:exact).rep('<','>','...',0).approx_mode(:simplify)
  CONV_FMT_STRICT = Fmt.prec(:exact).rep('<','>','...',0).approx_mode(:exact)
  def Fmt.convert(x, type, aprx=true)
    fmt = aprx ? CONV_FMT : CONV_FMT_STRICT
    # return x.prec(type)
    if !(x.is_a?(type))
      # return type.nio_read(x.nio_write(fmt),fmt)
      ·<save redundant neutral formatting·>
    end
    x
  end
end
·}


We'll use the lower level \cd{Formattable} implementation to save
innecessary convertion of neutral to and from text.

·d save redundant neutral formatting
·{·%
x = x.nio_write_neutral(fmt)
x = type.nio_read_neutral(x)
·}

We'll provide a special methods for conversion of a Float value to a BigDecimal
that will be used by BigDec which is defined in rtnlzr.rb

·d Nio functions
·{·%
def nio_float_to_bigdecimal(x,prec) # :nodoc:
  if prec.nil?
    x = Nio.convert(x,BigDecimal,true)          
  elsif prec==:exact
    x = Nio.convert(x,BigDecimal,false) 
  else
    x = BigDecimal(x.nio_write(Nio::Fmt.prec(prec,:sig)))
  end
  x
end
·}




\section{Tests}


·d Auxiliar methods for testing
·{·%
def neighbours(x)
  f,e = Math.frexp(x)  
  e = Float::MIN_EXP if f==0
  e = [Float::MIN_EXP,e].max
  dx = Math.ldexp(1,e-Float::MANT_DIG) #Math.ldexp(Math.ldexp(1.0,-Float::MANT_DIG),e)  
  high = x + dx
  if e==Float::MIN_EXP || f!=0.5 #0.5==Math.ldexp(2**(bits-1),-Float::MANT_DIG)
    low = x - dx
  else
    low = x - dx/2 # x - Math.ldexp(Math.ldexp(1.0,-Float::MANT_DIG),e-1)  
  end
  [low, high]  
end

def prv(x)
   neighbours(x)[0]
end
def nxt(x)
   neighbours(x)[1]
end
MIN_N = Math.ldexp(0.5,Float::MIN_EXP) # == nxt(MAX_D) == Float::MIN
MAX_D = Math.ldexp(Math.ldexp(1,Float::MANT_DIG-1)-1,Float::MIN_EXP-Float::MANT_DIG)
MIN_D = Math.ldexp(1,Float::MIN_EXP-Float::MANT_DIG);
·}

·d Tests setup
·{·%
    $data = YAML.load(File.read(File.join(File.dirname(__FILE__) ,'data.yaml'))).collect{|x| [x].pack('H*').unpack('E')[0]}
    $data << MIN_N
    $data << MAX_D
    $data << MIN_D
·}


·D Tests
·{·%
  def test_basic_fmt_float

    assert_equal 2,Float::RADIX
    assert_equal 53,Float::MANT_DIG
    
    # test correct rounding: 1.448997445238699 -> 6525704354437805*2^-52
    assert_equal Rational(6525704354437805,4503599627370496), Float.nio_read('1.448997445238699').nio_xr
    
    assert_equal "0",0.0.nio_write    
    
    fmt = Fmt.new
    fmt.rep '[','','...',0,true  
    fmt.sep '.',',',[3]    
    fmt.width(20,:right,'*')
    
    assert_equal "******643,454,333.32",fmt.nio_write_formatted(fmt.nio_read_formatted("643,454,333.32"))        
    fmt.pad0s(10)
    num = fmt.nio_read_formatted("0.3333...")
    assert_equal "0000000.[3",fmt.nio_write_formatted(num)
    fmt.mode(:fix,3)
    assert_equal "000000.333",fmt.nio_write_formatted(num)
    num = fmt.nio_read_formatted("-0.666...")  
    fmt.prec(:exact)
    fmt.sep(',','.')
    assert_equal "-000000,[6",fmt.nio_write_formatted(num)
    fmt.width(20,:center,'*')  
    fmt.mode(:fix,3)
    assert_equal "*******-0,667*******",fmt.nio_write_formatted(num)
    num = fmt.nio_read_formatted("0,5555")  
    fmt.prec(:exact)
    assert_equal "*******0,5555*******",fmt.nio_write_formatted(num)

    Fmt.default = Fmt.get(:es_th)
    x = Float.nio_read("11123,2343")
    assert_equal 11123.2343,x
    assert_equal "11.123,2343", x.nio_write
    assert_equal "11123,2343", x.nio_write(Fmt.get(:es))
    
    x = Float.nio_read("-1234,5678901234e-33")
    # assert_equal -1.2345678901234e-030, x
    assert_equal "-1,2345678901234E-30", x.nio_write()
    assert_equal "-0,0000000000000000000000000000012346",x.nio_write(Fmt.get(:es).dup.mode(:sig,5))

    assert_equal "0.333...", 
                 (1.0/3).nio_write(Fmt.prec(:exact).show_all_digits(true).approx_mode(:simplify))
                 

  end
·}

·D Tests
·{·%
  def test_tol_fmt_float
    tol = Tolerance.new.decimals(12,:sig)
    fmt = Fmt.prec(12,:sig)
    $data.each do |x|
       assert tol.equals?(x, Float.nio_read(x.nio_write(fmt),fmt))
       assert tol.equals?(-x, Float.nio_read((-x).nio_write(fmt),fmt))
    end
  end
·}

·D Tests
·{·%
  def test_BigDec
    assert_equal "0",BigDec(0).nio_write        
    fmt = Fmt.mode(:gen,:exact)
    assert_equal "0",BigDec(0).nio_write(fmt)
    $data.each do |x|
      x = BigDecimal(x.to_s)
      assert_equal x,BigDecimal.nio_read(x.nio_write(fmt),fmt)
    end
    
  end
·}

·D Tests
·{·%
  def test_Rational
    assert_equal "0",Rational(0,1).nio_write        
    fmt = Fmt.mode(:gen,:exact)
    assert_equal "0",Rational(0,1).nio_write(fmt)
    $data.each do |x|
      x = x.nio_xr # nio_r
      assert_equal x,Rational.nio_read(x.nio_write(fmt),fmt)
    end    
  end
·}

·D Tests
·{·%
  def test_float_bases
    nfmt2 = Fmt.get(:es).dup.base(2).prec(:exact)
    nfmt8 = Fmt.get(:es).dup.base(8).prec(:exact)
    nfmt10 = Fmt.get(:es).dup.base(10).prec(:exact)
    nfmt16 = Fmt.get(:es).dup.base(16).prec(:exact)
    $data.each do |x|
      assert_equal(x,Float.nio_read(x.nio_write(nfmt2),nfmt2))
      assert_equal(x,Float.nio_read(x.nio_write(nfmt8),nfmt8))
      assert_equal(x,Float.nio_read(x.nio_write(nfmt10),nfmt10))
      assert_equal(x,Float.nio_read(x.nio_write(nfmt16),nfmt16))
      assert_equal(-x,Float.nio_read((-x).nio_write(nfmt2),nfmt2))
      assert_equal(-x,Float.nio_read((-x).nio_write(nfmt8),nfmt8))
      assert_equal(-x,Float.nio_read((-x).nio_write(nfmt10),nfmt10))
      assert_equal(-x,Float.nio_read((-x).nio_write(nfmt16),nfmt16))      
    end
  end
·}

·D Tests
·{·%
  def rational_bases
      assert_equal "0.0001100110011...", (Rational(1)/10).nio_write(Fmt.new.base(2))
  end
·}

·D Tests
·{·%
  def test_big_decimal_bases
    
    assert_equal "0.1999A",(BigDec(1)/10).nio_write(Fmt.new.base(16).prec(5))
    assert_equal "0.1999...",(BigDec(1)/10).nio_write(Fmt.mode(:gen,:exact,:inf,nil,:simplify).base(16))
    
    nfmt2 = Fmt.get(:es).dup.base(2).prec(:exact)
    nfmt8 = Fmt.get(:es).dup.base(8).prec(:exact)
    nfmt10 = Fmt.get(:es).dup.base(10).prec(:exact)
    nfmt16 = Fmt.get(:es).dup.base(16).prec(:exact)
    $data.each do |x|      
      x = BigDec(x.to_s)
      xs,xdig,xb,xe = x.split
      ndig = xdig.size
      round_dig = ndig-xe
      # note that BigDecimal.nio_read produces a BigDecimal with the exact value of the text representation
      # since the representation here is only aproximate (because of the base difference), we must
      # round the results to the precision of the original number
      assert_equal(x,BigDecimal.nio_read(x.nio_write(nfmt2),nfmt2).round(round_dig))
      assert_equal(x,BigDecimal.nio_read(x.nio_write(nfmt8),nfmt8).round(round_dig))
      assert_equal(x,BigDecimal.nio_read(x.nio_write(nfmt10),nfmt10).round(round_dig))
      assert_equal(x,BigDecimal.nio_read(x.nio_write(nfmt16),nfmt16).round(round_dig))
      assert_equal(-x,BigDecimal.nio_read((-x).nio_write(nfmt2),nfmt2).round(round_dig))
      assert_equal(-x,BigDecimal.nio_read((-x).nio_write(nfmt8),nfmt8).round(round_dig))
      assert_equal(-x,BigDecimal.nio_read((-x).nio_write(nfmt10),nfmt10).round(round_dig))
      assert_equal(-x,BigDecimal.nio_read((-x).nio_write(nfmt16),nfmt16).round(round_dig))
    end    
  end
·}

·D Tests
·{·%
  def test_exact_all_float
    #fmt = Fmt.prec(:exact).show_all_digits(true).approx_mode(:exact)
    fmt = Fmt.mode(:gen,:exact,:inf,true,:exact)
    assert_equal "0.1000000000000000055511151231257827021181583404541015625",Float.nio_read('0.1',fmt).nio_write(fmt)
    assert_equal "64.099999999999994315658113919198513031005859375",Float.nio_read('64.1',fmt).nio_write(fmt)
    assert_equal '0.5',Float.nio_read('0.5',fmt).nio_write(fmt)
    assert_equal "0.333333333333333314829616256247390992939472198486328125", (1.0/3.0).nio_write(fmt)
    assert_equal "0.66666666666666662965923251249478198587894439697265625", (2.0/3.0).nio_write(fmt)
    assert_equal "-0.333333333333333314829616256247390992939472198486328125", (-1.0/3.0).nio_write(fmt)
    assert_equal "-0.66666666666666662965923251249478198587894439697265625", (-2.0/3.0).nio_write(fmt)
    assert_equal "1267650600228229401496703205376",  (2.0**100).nio_write(fmt)    
    assert_equal "0.10000000000000001942890293094023945741355419158935546875", nxt(0.1).nio_write(fmt)
    assert_equal "1023.9999999999998863131622783839702606201171875", prv(1024).nio_write(fmt)
    
    assert_equal "2.225073858507201383090232717332404064219215980462331830553327416887204434813918195854283159012511020564067339731035811005152434161553460108856012385377718821130777993532002330479610147442583636071921565046942503734208375250806650616658158948720491179968591639648500635908770118304874799780887753749949451580451605050915399856582470818645113537935804992115981085766051992433352114352390148795699609591288891602992641511063466313393663477586513029371762047325631781485664350872122828637642044846811407613911477062801689853244110024161447421618567166150540154285084716752901903161322778896729707373123334086988983175067838846926092773977972858659654941091369095406136467568702398678315290680984617210924625396728515625E-308",
                 MIN_N.nio_write(fmt)
    assert_equal "2.2250738585072008890245868760858598876504231122409594654935248025624400092282356951787758888037591552642309780950434312085877387158357291821993020294379224223559819827501242041788969571311791082261043971979604000454897391938079198936081525613113376149842043271751033627391549782731594143828136275113838604094249464942286316695429105080201815926642134996606517803095075913058719846423906068637102005108723282784678843631944515866135041223479014792369585208321597621066375401613736583044193603714778355306682834535634005074073040135602968046375918583163124224521599262546494300836851861719422417646455137135420132217031370496583210154654068035397417906022589503023501937519773030945763173210852507299305089761582519159720757232455434770912461317493580281734466552734375E-308",
                 MAX_D.nio_write(fmt)
    assert_equal "2.225073858507200394958941034839315711081630244019587100433722188237675583642553194503268618595007289964394616459051051412023043270117998255542591673498126023581185971968246077878183766819774580380287229348978296356771103136809189170558146173902184049999817014701706089569539838241444028984739501272818269238398287937541863482503350197395249647392622007205322474852963190178391854932391064931720791430455764953943127215325436859833344767109289929102154994338687742727610729450624487971196675896144263447425089844325111161570498002959146187656616550482084690619235135756396957006047593447154776156167693340095043268338435252390549256952840748419828640113148805198563919935252207510837343961185884248936392555587988206944151446491086954182492263498716056346893310546875E-308",
                 prv(MAX_D).nio_write(fmt)
    assert_equal "9.88131291682493088353137585736442744730119605228649528851171365001351014540417503730599672723271984759593129390891435461853313420711879592797549592021563756252601426380622809055691634335697964207377437272113997461446100012774818307129968774624946794546339230280063430770796148252477131182342053317113373536374079120621249863890543182984910658610913088802254960259419999083863978818160833126649049514295738029453560318710477223100269607052986944038758053621421498340666445368950667144166486387218476578691673612021202301233961950615668455463665849580996504946155275185449574931216955640746893939906729403594535543517025132110239826300978220290207572547633450191167477946719798732961988232841140527418055848553508913045817507736501283943653106689453125E-324",
                 nxt(MIN_D).nio_write(fmt)
    assert_equal "4.940656458412465441765687928682213723650598026143247644255856825006755072702087518652998363616359923797965646954457177309266567103559397963987747960107818781263007131903114045278458171678489821036887186360569987307230500063874091535649843873124733972731696151400317153853980741262385655911710266585566867681870395603106249319452715914924553293054565444011274801297099995419319894090804165633245247571478690147267801593552386115501348035264934720193790268107107491703332226844753335720832431936092382893458368060106011506169809753078342277318329247904982524730776375927247874656084778203734469699533647017972677717585125660551199131504891101451037862738167250955837389733598993664809941164205702637090279242767544565229087538682506419718265533447265625E-324",
                 MIN_D.nio_write(fmt)

  end
·}

·D Tests
·{·%
  def test_float_nonsig
    
    assert_equal "100.000000000000000#####", 100.0.nio_write(Fmt.prec(20,:fix).non_significative_digits('#'))

    fmt = Fmt.mode(:sci,20).non_significative_digits('#').sci_digits(1)
    assert_equal "3.3333333333333331###E-1", (1.0/3).nio_write(fmt)
    assert_equal "3.3333333333333335###E6", (1E7/3).nio_write(fmt)
    assert_equal "3.3333333333333334###E-8", (1E-7/3).nio_write(fmt)
    assert_equal "3.3333333333333333333E-1",  Rational(1,3).nio_write(fmt)
    assert_equal "3.3333333333333331###E-1", (1.0/3).nio_write(fmt.dup.sci_digits(1))
    assert_equal "33333333333333331###.E-20", (1.0/3).nio_write(fmt.dup.sci_digits(-1))
    assert_equal "33333333333333333333.E-20", (Rational(1,3)).nio_write(fmt.dup.sci_digits(-1))

    fmt.sci_digits :eng
    assert_equal "333.33333333333331###E-3", (1.0/3).nio_write(fmt)
    assert_equal "3.3333333333333335###E6", (1E7/3).nio_write(fmt)
    assert_equal "33.333333333333334###E-9",(1E-7/3).nio_write(fmt)
    
    fmt = Fmt.get(:es).dup.mode(:sci,20).non_significative_digits('#').sci_digits(0)    
    assert_equal "0,33333333333333331###E0",(1.0/3).nio_write(fmt)
    assert_equal "0,33333333333333335###E7",(1E7/3).nio_write(fmt)
    assert_equal "0,33333333333333334###E-7",(1E-7/3).nio_write(fmt)
    
    fmt = Fmt.mode(:sci,20).non_significative_digits('#').sci_digits(0)
    assert_equal "0.10000000000000001###E0",(1E-1).nio_write(fmt)
    assert_equal "0.50000000000000000###E0",(0.5).nio_write(fmt)
    assert_equal "0.49999999999999994###E0",prv(0.5).nio_write(fmt)
    assert_equal "0.50000000000000011###E0",nxt(0.5).nio_write(fmt)
    assert_equal "0.22250738585072014###E-307",MIN_N.nio_write(fmt)
    assert_equal "0.22250738585072009###E-307",MAX_D.nio_write(fmt)
    assert_equal "0.5###################E-323",MIN_D.nio_write(fmt)
    assert_equal "0.64000000000000000###E2",(64.0).nio_write(fmt)
    assert_equal "0.6400000000000001####E2",(nxt(64.0)).nio_write(fmt)
    assert_equal "0.6409999999999999####E2",(64.1).nio_write(fmt) 
    assert_equal "0.6412312300000001####E2",(64.123123).nio_write(fmt)
    assert_equal "0.10000000000000001###E0",(0.1).nio_write(fmt)
    assert_equal "0.6338253001141148####E30",nxt(Math.ldexp(0.5,100)).nio_write(fmt) 
    assert_equal "0.39443045261050599###E-30",nxt(Math.ldexp(0.5,-100)).nio_write(fmt)
    assert_equal "0.10##################E-322",nxt(MIN_D).nio_write(fmt)
    assert_equal "0.15##################E-322",nxt(nxt(MIN_D)).nio_write(fmt)
    
    # note: 1E23 is equidistant from 2 Floats; one or the other will be chosen based on the rounding mode
    x = Float.nio_read('1E23',Fmt.prec(:exact,:gen,:even))
    assert_equal "1E23",x.nio_write(Fmt.prec(:exact,:gen,:inf_neg))
    assert_equal "9.999999999999999E22",x.nio_write(Fmt.prec(:exact,:gen,:inf))
    assert_equal "1E23",x.nio_write(Fmt.prec(:exact,:gen,:inf_neg))    
    
    # note: for 64.1 there's only one closest Float; 
    #   but it can be univocally expressed in decimal either as 64.09999999999999 or 64.1
    x = Float.nio_read('64.1',Fmt.prec(:exact,:gen,:even))
    assert_equal "64.09999999999999",x.nio_write(Fmt.prec(:exact,:gen).show_all_digits(true))
    assert_equal "64.1",x.nio_write(Fmt.prec(:exact,:gen))
    
    # to do:  exact conversion of Rational(32095022417, 54517) should throw and exception
    #         (unless RepDec.max_d is greater than 27300 or so)
    
    
  end
·}

·D Tests
·{·%
  def test_special
    assert BigDecimal.nio_read("NaN").nan?
    assert Float.nio_read("NaN").nan?
    assert_equal "NAN", BigDec("NaN").nio_write.upcase
    assert_equal "NAN", BigDecimal.nio_read("NaN").nio_write.upcase
    assert_equal "NAN", Float.nio_read("NaN").nio_write.upcase
    assert_raises ZeroDivisionError do Rational.nio_read("NaN") end
    
    assert !BigDecimal.nio_read('Infinity').finite?
    assert !BigDecimal.nio_read('+Infinity').finite?
    assert !BigDecimal.nio_read('-Infinity').finite?
    assert !Float.nio_read('Infinity').finite?
    assert !Float.nio_read('+Infinity').finite?
    assert !Float.nio_read('-Infinity').finite?
    assert_raises ZeroDivisionError do Rational.nio_read("Infinity") end
    assert_raises ZeroDivisionError do Rational.nio_read("+Infinity") end
    assert_raises ZeroDivisionError do Rational.nio_read("-Infinity") end
    assert_equal BigDec(1)/0, BigDecimal.nio_read('Infinity')
    assert_equal BigDec(-1)/0, BigDecimal.nio_read('-Infinity')
    assert_equal '+Infinity', BigDecimal.nio_read('Infinity').nio_write
    assert_equal '+Infinity', BigDecimal.nio_read('+Infinity').nio_write
    assert_equal '-Infinity', BigDecimal.nio_read('-Infinity').nio_write
    assert_equal '+Infinity', Float.nio_read('Infinity').nio_write
    assert_equal '+Infinity', Float.nio_read('+Infinity').nio_write
    assert_equal '-Infinity', Float.nio_read('-Infinity').nio_write
    
  end
·}


\begin{thebibliography}{Rtnlzr}

\bibitem[3]{3}
   \title{Printing Floating-Point Numbers Quickly and Accurately}
   \author{Robert G. Burger, R. Kent Dybvig}

\end{thebibliography}   

% -------------------------------------------------------------------------------------
\section{Índices}


\subsection{Archivos}
·f

\subsection{Fragmentos}
·m

\subsection{Identificadores}
·u



\end{document}