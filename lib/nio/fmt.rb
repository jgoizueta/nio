# Formatting numbers as text

# Copyright (C) 2003-2005, Javier Goizueta <javier@goizueta.info>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.


require 'nio/tools'

require 'nio/repdec'

require 'nio/rtnlzr'

require 'rational'

require 'bigdecimal'

module Nio
  
  # positional notation, unformatted numeric literal: used as intermediate form
  class NeutralNum 
    include StateEquivalent
    def initialize(s='',d='',p=nil,r=nil,dgs=DigitsDef.base(10), inexact=false, round=:inf)
      set s,d,p,r,dgs,dgs, inexact, round
    end
    attr_reader :sign, :digits, :dec_pos, :rep_pos, :special, :inexact, :rounding
    attr_writer :sign, :digits, :dec_pos, :rep_pos, :special, :inexact, :rounding
    
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
    
    # check for special numbers (which have only special and sign attributes)
    def special?
      special != nil
    end
    
    # check for special numbers (which have only special and sign attributes)
    def inexact?
      @inexact
    end
    
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
    
    def round!(n, mode=:fix, dir=nil)
      dir ||= rounding
      trimLeadZeros
      if n==:exact
        return unless @inexact
        n = @digits.size
      end
      
      n += @dec_pos if mode==:fix
      n = [n,@digits.size].min if @inexact

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
         
         (n+1...@digits.length).each do |i|
           if dig_value(i)>0
             dv = :hi
             break
           end        
         end
          
          dv = :hi if dv==:tie && @rep_pos<=n                  
        end
      end
      
      if dv==:hi
        adj = +1
      elsif dv==:tie
        if dir==:inf # towards nearest +/-infinity
          adj = +1
        elsif dir==:even # to nearest even digit (IEEE unbiased rounding)
          adj = +1 if (dig_value(n-1)%2)!=0
        elsif dir==:zero # towards zero
          adj=0
      #  elsif dir==:odd 
      #    adj = +1 unless (dig_value(n-1)%2)!=0
        end
      end    
      
      if n>@digits.length
        (@digits.length...n).each do |i|
          @digits << dig_char(dig_value(i))
          @rep_pos += 1
        end
      end
      
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
      
      if n<0
        @digits = ""  
      else
        @digits = @digits[0...n]  
      end
      @rep_pos = @digits.length

      if prefix!=''
        @digits = prefix + @digits
        @dec_pos += prefix.length
        @rep_pos += prefix.length
      end
      
      
    end
    
    def round(n, mode=:fix, dir=nil)
      dir ||= rounding
      nn = dup
      nn.round!(n,mode,dir)
      return nn
    end
    
    def trimTrailZeros()    
      i = @digits.length
      while i>0 && dig_value(i-1)==0
        i -= 1    
      end
      if @rep_pos>=i
        @digits = @digits[0...i]
        @rep_pos = i
      end
      
      if @digits==''
        @digits = dig_char(0) # '0'
        @rep_pos = 1
        @dec_pos = 1
      end
      
    end
    
    def trimLeadZeros()
      i = 0
      while i<@digits.length && dig_value(i)==0
        i += 1
      end
      @digits = @digits[i...@digits.length]
      @dec_pos -= i
      @rep_pos -= i
      
      if @digits==''
        @digits = dig_char(0) # '0'
        @rep_pos = 1
        @dec_pos = 1
      end
      
    end
    
    def trimZeros()    
      trimLeadZeros
      trimTrailZeros
    end
    
    protected
    
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
    
    def dig_char(v)
      c = ''
      if v!=nil && v>=0 && v<@base
        c = @dgs.digit_char(v).chr
      end
      c
    end
    
  end
  
  class NeutralNum
    public
    def to_RepDec
      n = RepDec.new(@base)
      if special?
        
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
  
  class RepDec
    public
    def to_NeutralNum(base_dgs=nil)
      num = NeutralNum.new
      if !ip.is_a?(Integer)
        
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
  
  # A Fmt object defines a numeric format.
  #
  # The formatting aspects managed by Fmt are:
  # * mode and precision
  #   - #mode() and #orec() set the main paramters
  #   - see also #show_all_digits(), #approx_mode(), #insignificant_digits(),
  #     #sci_digits() and #show_plus()
  # * separators
  #   - see #sep() and #grouping()
  # * field justfification
  #   - #width() and the shortcut #pad0s()
  # * numerical base
  #   - #base()
  # * repeating numerals 
  #   - #rep()
  #
  # Note that for every aspect there are also corresponding _mutator_
  # methos (its name ending with a bang) that modify an object in place,
  # instead of returning an altered copy.
  #
  # This class also contains class methods for numeric conversion:
  # * Fmt.convert
  # and for default and other predefined formats:
  # * Fmt.default / Fmt.default=
  # * Fmt.[] / Fmt.[]=
  #
  # The actual formatted reading and writting if performed by
  # * #nio_write() (Nio::Formattable#nio_write)
  # * #nio_read() (Nio::Formattable::ClassMethods#nio_read)
  # Finally numerical objects can be rounded according to a format:
  # * #nio_round() (Nio::Formattable#nio_round)
  class Fmt
    include StateEquivalent
    
    class Error < StandardError # :nodoc:
    end
    class InvalidOption < Error # :nodoc:
    end
    class InvalidFormat < Error # :nodoc:
    end
    
    @@default_rounding_mode = :even
    def initialize()
      
      @dec_sep = '.'
      @grp_sep = ','
      @grp = []
      
      @ndig = :exact
      @mode=:gen
      @round=Fmt.default_rounding_mode
      @all_digits = false
      @approx = :only_sig
      @non_sig = '' # marker for insignificant digits of inexact values e.g. '#','0'
      @sci_format = 1 # number of integral digits in the mantissa: -1 for all
      
      @show_plus = false
      @plus_symbol = nil
      @minus_symbol = nil
      @show_exp_plus = false
      
      @rep_begin = '<'
      @rep_end   = '>'
      @rep_auto  = '...'
      @rep_n  = 2
      @rep_in   = true
      
      @width = 0
      @fill_char = ' '
      @adjust=:right
      
      @base_radix = 10
      @base_uppercase = true
      @base_digits = DigitsDef.base(@base_radix, !@base_uppercase)
      @show_base = false
      @base_indicators = { 2=>'b', 8=>'o', 10=>'', 16=>'h', 0=>'r'} # 0: generic (used with radix)
      @base_prefix = false
      
      @nan_txt = 'NAN'
      @inf_txt = 'Infinity'
      
      yield self if block_given?  
    end
    
    # Defines the separators used in numerals. This is relevant to
    # both input and output. 
    # 
    # The first argument is the radix point separator (usually
    # a point or a comma; by default it is a point.)
    #
    # The second argument is the group separator.
    #
    # Finally, the third argument is an array that defines the groups
    # of digits to separate.
    # By default it's [], which means that no grouping will be produced on output
    # (but the group separator defined will be ignored in input.)
    # To produce the common thousands separation a value of [3] must be passed,
    # which means that groups of 3 digits are used.
    def sep(dec_sep,grp_sep=nil,grp=nil)
      dup.sep!(dec_sep,grp_sep,grp)
    end
    # This is the mutator version of #sep().
    def sep!(dec_sep,grp_sep=nil,grp=nil)
      set! :dec_sep=>dec_sep, :grp_sep=>grp_sep, :grp=>grp
    end
    
    # This defines the grouping of digits (which can also be defined in #sep()
    def grouping(grp=[3],grp_sep=nil)
      dup.grouping!(grp,grp_sep)
    end
    # This is the mutator version of #grouping().
    def grouping!(grp=[3],grp_sep=nil)
      set! :grp_sep=>grp_sep, :grp=>grp
    end
    
    # This is a shortcut to return a new default Fmt object 
    # and define the separators as with #sep().
    def Fmt.sep(dec_sep,grp_sep=nil,grp=nil)
      Fmt.default.sep(dec_sep,grp_sep,grp)
    end
    # This is a shortcut to return a new default Fmt object 
    # and define the grouping as with #grouping().
    def Fmt.grouping(grp=[3],grp_sep=nil)
      Fmt.default.grouping(grp,grp_sep)
    end
    
    # Define the formatting mode. There are two fixed parameters:
    # - <tt>mode</tt> (only relevant for output)
    #   [<tt>:gen</tt>]
    #      (general) chooses automatically the shortes format
    #   [<tt>:fix</tt>]
    #      (fixed precision) is a simple format with a fixed number of digits
    #      after the point
    #   [<tt>:sig</tt>]
    #      (significance precision) is like :fix but using significant digits
    #   [<tt>:sci</tt>]
    #      (scientific) is the exponential form 1.234E2
    # - <tt>precision</tt> (number of digits or :exact, only used for output)
    #   [<tt>exact</tt>]
    #      means that as many digits as necessary to unambiguosly define the
    #      value are used; this is the default.
    #
    # Other paramters can be passed in a hash after <tt>precision</tt>
    # - <tt>:round</tt> rounding mode applied to conversions
    #   (this is relevant for both input and output). It must be one of:
    #   [<tt>:inf</tt>]
    #     rounds to nearest with ties toward infinite; 
    #       1.5 is rounded to 2, -1.5 to -2
    #   [<tt>:zero</tt>]
    #     rounds to nearest with ties toward zero; 
    #       1.5 is rounded to 1, -1.5 to 2
    #   [<tt>:even</tt>]
    #     rounds to the nearest with ties toward an even digit;
    #       1.5 rounds to 2, 2.5 to 2
    # - <tt>:approx</tt> approximate mode
    #   [<tt>:only_sig</tt>]
    #     (the default) treats the value as an approximation and only
    #     significant digits (those that cannot take an arbitrary value without
    #     changing the specified value) are shown.
    #   [<tt>:exact</tt>]
    #     the value is interpreted as exact, there's no distinction between
    #     significant and insignificant digits.
    #   [<tt>:simplify</tt>]
    #     the value is simplified, if possible to a simpler (rational) value.
    # - <tt>:show_all_digits</tt> if true, this forces to show digits that 
    #   would otherwise not be shown in the <tt>:gen</tt> format: trailing
    #   zeros of exact types or non-signficative digits of inexact types.
    # - <tt>:nonsignficative_digits</tt> assigns a character to display
    #   insignificant digits, # by default
    def mode(mode,precision=nil,options={})
      dup.mode!(mode,precision,options)
    end
    # This is the mutator version of #mode().
    def mode!(mode,precision=nil,options={})
      set! options.merge(:mode=>mode, :ndig=>precision)
    end
    
    # Defines the formatting mode like #mode() but using a different
    # order of the first two parameters parameters, which is useful
    # to change the precision only. Refer to #mode().
    def prec(precision,mode=nil, options={})
      dup.prec! precision, mode, options
    end  
    # This is the mutator version of #prec().
    def prec!(precision,mode=:gen, options={})
      set! options.merge(:mode=>mode, :ndig=>precision)
    end
    
    # This is a shortcut to return a new default Fmt object 
    # and define the formatting mode as with #mode()
    def Fmt.mode(mode,ndig=nil,options={})
      Fmt.default.mode(mode,ndig,options)
    end
    # This is a shortcut to return a new default Fmt object 
    # and define the formatting mode as with #prec()
    def Fmt.prec(ndig,mode=nil,options={})
      Fmt.default.prec(ndig,mode,options)
    end
    
    # Rounding mode used when not specified otherwise
    def Fmt.default_rounding_mode
      @@default_rounding_mode
    end
    # The default rounding can be changed here; it starts with the value :even.
    # See the rounding modes available in the description of method #mode().
    def Fmt.default_rounding_mode=(m)
      @@default_rounding_mode=m
      Fmt.default = Fmt.default.round(m)
    end
    
    # This controls the display of the digits that are not necessary
    # to specify the value unambiguosly (e.g. trailing zeros).
    # 
    # The true (default) value forces the display of the requested number of digits
    # and false will display only necessary digits.
    def show_all_digits(ad=true)
      dup.show_all_digits! ad
    end
    # This is the mutator version of #show_all_digits().
    def show_all_digits!(ad=true)
      set! :all_digits=>ad
    end
    # This defines the approximate mode (:only_sig, :exact, :simplify)
    # just like the last parameter of #mode()
    def approx_mode(mode)
      dup.approx_mode! mode
    end
    # This is the mutator version of #approx_mode().
    def approx_mode!(mode)
      set! :approx=>mode
    end
    # Defines a character to stand for insignificant digits when
    # a specific number of digits has been requested greater than then
    # number of significant digits (for approximate types).
    def insignificant_digits(ch='#')
      dup.insignificant_digits! ch
    end
    # This is the mutator version of #insignificant_digits().
    def insignificant_digits!(ch='#')
      ch ||= ''
      set! :non_sig=>ch
    end
    # Defines the number of significan digits before the radix separator
    # in scientific notation. A negative value will set all significant digits
    # before the radix separator. The special value <tt>:eng</tt> activates
    # _engineering_ mode, in which the exponents are multiples of 3.
    #
    # For example:
    #   0.1234.nio_write(Fmt.mode(:sci,4).sci_digits(0)    ->  0.1234E0
    #   0.1234.nio_write(Fmt.mode(:sci,4).sci_digits(3)    ->  123.4E-3
    #   0.1234.nio_write(Fmt.mode(:sci,4).sci_digits(-1)   ->  1234.E-4
    #   0.1234.nio_write(Fmt.mode(:sci,4).sci_digits(:eng) ->  123.4E-3
    def sci_digits(n=-1)
      dup.sci_digits! n
    end
    # This is the mutator version of #sci_digits().
    def sci_digits!(n=-1)
      set! :sci_format=>n
    end
    
    # This is a shortcut to return a new default Fmt object 
    # and define show_all_digits
    def Fmt.show_all_digits(v=true)
      Fmt.default.show_all_digits(v)
    end
    # This is a shortcut to return a new default Fmt object 
    # and define approx_mode
    def Fmt.approx_mode(v)
      Fmt.default.approx_mode(v)
    end
    # This is a shortcut to return a new default Fmt object 
    # and define insignificant digits
    def Fmt.insignificant_digits(v='#')
      Fmt.default.insignificant_digits(v)
    end
    # This is a shortcut to return a new default Fmt object 
    # and define sci_digits
    def Fmt.sci_digits(v=-1)
      Fmt.default.sci_digits(v)
    end
    
    # Controls the display of the sign for positive numbers
    def show_plus(sp=true)
      dup.show_plus! sp
    end
    # This is the mutator version of #show_plus().
    def show_plus!(sp=true)
      set! :show_plus=>sp
      set! :plus_symbol=>sp if sp.kind_of?(String)
      self
    end

    # Controls the display of the sign for positive exponents
    def show_exp_plus(sp=true)
      dup.show_exp_plus! sp
    end
    # This is the mutator version of #show_exp_plus().
    def show_exp_plus!(sp=true)
      set! :show_exp_plus=>sp
      set! :plus_symbol=>sp if sp.kind_of?(String)
      self
    end

    # This is a shortcut to return a new default Fmt object 
    # and define show_plus
    def Fmt.show_plus(v=true)
      Fmt.default.show_plus(v)
    end
    
    # This is a shortcut to return a new default Fmt object 
    # and define show_exp_plus
    def Fmt.show_exp_plus(v=true)
      Fmt.default.show_exp_plus(v)
    end
    
    
    # Defines the handling and notation for repeating numerals. The parameters
    # can be passed in order or in a hash:
    # [<tt>:begin</tt>] is the beginning delimiter of repeating section (<)
    # [<tt>:end</tt>] is the ending delimiter of repeating section (<)
    # [<tt>:suffix</tt>] is the suffix used to indicate a implicit repeating decimal
    # [<tt>:rep</tt>]
    #    if this parameter is greater than zero, on output the repeating section
    #    is repeated the indicated number of times followed by the suffix; 
    #    otherwise the delimited notation is used.
    # [<tt>:read</tt>]
    #    (true/false) determines if repeating decimals are
    #    recognized on input (true)
    def rep(*params)
      dup.rep!(*params)
    end
    # This is the mutator version of #rep().
    def rep!(*params)  
      
      params << {} if params.size==0
      if params[0].kind_of?(Hash)
        params = params[0]
      else  
        begch,endch,autoch,rep,read = *params  
        params = {:begin=>begch,:end=>endch,:suffix=>autoch,:nreps=>rep,:read=>read}
      end
      
      set! params
    end
    
    # This is a shortcut to return a new default Fmt object 
    # and define the repeating decimals mode as with #rep()
    def Fmt.rep(*params)
      Fmt.default.rep(*params)
    end
    
    # Sets the justificaton width, mode and fill character
    #
    # The mode accepts these values:
    # [<tt>:right</tt>] (the default) justifies to the right (adds padding at the left)
    # [<tt>:left</tt>] justifies to the left (adds padding to the right)
    # [<tt>:internal</tt>] like :right, but the sign is kept to the left, outside the padding.
    # [<tt>:center</tt>] centers the number in the field
    def width(w,adj=nil,ch=nil)
      dup.width! w,adj,ch
    end
    # This is the mutator version of #width().
    def width!(w,adj=nil,ch=nil)
      set! :width=>w, :adjust=>adj, :fill_char=>ch
    end
    # Defines the justification (as #width()) with the given
    # width, internal mode and filling with zeros.
    #
    # Note that if you also use grouping separators, the filling 0s
    # will not be separated.
    def pad0s(w)
      dup.pad0s! w
    end
    # This is the mutator version of #pad0s().
    def pad0s!(w)
      width! w, :internal, '0'
    end
    # This is a shortcut to create a new Fmt object and define the width
    # parameters as with #widht()
    def Fmt.width(w,adj=nil,ch=nil)
      Fmt.default.width(w,adj,ch)
    end
    # This is a shortcut to create a new Fmt object and define numeric
    # padding as with #pad0s()
    def Fmt.pad0s(w)
      Fmt.default.pad0s(w)
    end
    
    # defines the numerical base; the second parameters forces the use
    # of uppercase letters for bases greater than 10.
    def base(b, uppercase=nil)
      dup.base! b, uppercase
    end
    # This is the mutator version of #base().
    def base!(b, uppercase=nil)
      set! :base_radix=>b, :base_uppercase=>uppercase
    end
    # This is a shortcut to create a new Fmt object and define the base
    def Fmt.base(b, uppercase=nil)
      Fmt.default.base(b, uppercase)
    end
    # returns the exponent char used with the specified base
    def get_exp_char(base) # :nodoc:
      base ||= @base_radix
      base<=10 ? 'E' : '^'
    end
    
    # returns the base
    def get_base # :nodoc:
      @base_radix
    end
    # returns the digit characters used for a base
    def get_base_digits(b=nil) # :nodoc:
      (b.nil? || b==@base_radix) ? @base_digits : DigitsDef.base(b,!@base_uppercase)
    end
    # returns true if uppercase digits are used
    def get_base_uppercase? # :nodoc:
      @base_uppercase
    end
    
    # returns the formatting mode
    def get_mode # :nodoc:
      @mode
    end
    # returns the precision (number of digits)
    def get_ndig # :nodoc:
      @ndig
    end
    # return the show_all_digits state
    def get_all_digits? # :nodoc:
      @all_digits
    end
    # returns the approximate mode
    def get_approx # :nodoc:
      @approx
    end
    
    # returns the rounding mode
    def get_round # :nodoc:
      @round
    end
    
    # Method used internally to format a neutral numeral
    def nio_write_formatted(neutral) # :nodoc:
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
          if @ndig.kind_of?(Numeric) && @ndig>0 && @mode==:fix
            str << @dec_sep << zero*@ndig
          end
        else
          
          neutral.trimLeadZeros
          actual_mode = @mode
          trim_trail_zeros = !@all_digits # false

          integral_digits = @sci_format
          if integral_digits == :eng
            integral_digits = 1
            while (neutral.dec_pos - integral_digits).modulo(3) != 0
              integral_digits += 1
            end
          elsif integral_digits==:all || integral_digits < 0
            if neutral.inexact? && @non_sig!='' && @ndig.kind_of?(Numeric)
              integral_digits = @ndig
            else
              integral_digits = neutral.digits.length
            end
          end
          exp = neutral.dec_pos - integral_digits
              
          case actual_mode
            when :gen # general (automatic)
              # @ndig means significant digits
              actual_mode = :sig
              actual_mode = :sci if use_scientific?(neutral, exp)
              trim_trail_zeros = !@all_digits # true
          end
          
          case actual_mode  
            when :fix, :sig #, :gen
                            
              if @show_plus || neutral.sign!='+'
                str << ({'-'=>@minus_symbol, '+'=>@plus_symbol}[neutral.sign] || neutral.sign)
              end

              if @show_base && @base_prefix
                b_prefix = @base_indicators[neutral.base]
                str << b_prefix if b_prefix
              end
              
              if @ndig==:exact
                neutral.sign = '+'
                str << neutral.to_RepDec.getS(@rep_n, getRepDecOpt(neutral.base))
              else
                #zero = get_base_digits.digit_char(0).chr
                ns_digits = ''
                
                nd = neutral.digits.length
                if actual_mode==:fix
                  nd -= neutral.dec_pos
                end
                if neutral.inexact? && @ndig>nd # assert no rep-dec.
                  ns_digits = @non_sig*(@ndig-nd)
                end
                
                digits = neutral.digits + ns_digits
                if neutral.dec_pos<=0
                  str << zero+@dec_sep+zero*(-neutral.dec_pos) + digits
                elsif neutral.dec_pos >= digits.length 
                  str << group(digits + zero*(neutral.dec_pos-digits.length))
                else
                  str << group(digits[0...neutral.dec_pos]) + @dec_sep + digits[neutral.dec_pos..-1]
                end
              end

              #str = str.chomp(zero).chomp(@dec_sep) if trim_trail_zeros && str.include?(@dec_sep)
              if trim_trail_zeros && str.include?(@dec_sep) &&  str[-@rep_auto.size..-1]!=@rep_auto
                str.chop! while str[-1]==zero[0]
                str.chomp!(@dec_sep)
                #puts str
              end
              
                
            when :sci
              
              if @show_plus || neutral.sign!='+'
                str << ({'-'=>@minus_symbol, '+'=>@plus_symbol}[neutral.sign] || neutral.sign)
              end

              if @show_base && @base_prefix
                b_prefix = @base_indicators[neutral.base]
                str << b_prefix if b_prefix
              end
              
              #zero = get_base_digits.digit_char(0).chr
              if @ndig==:exact
                neutral.sign = '+'
                neutral.dec_pos-=exp
                str << neutral.to_RepDec.getS(@rep_n, getRepDecOpt(neutral.base))  
              else
                ns_digits = ''
                
                nd = neutral.digits.length
                if actual_mode==:fix
                  nd -= neutral.dec_pos
                end
                if neutral.inexact? && @ndig>nd # assert no rep-dec.
                  ns_digits = @non_sig*(@ndig-nd)
                end
                
                digits = neutral.digits + ns_digits
                str << ((integral_digits<1) ? zero : digits[0...integral_digits])
                str << @dec_sep
                str << digits[integral_digits...@ndig]
                pad_right =(@ndig+1-str.length) 
                str << zero*pad_right if pad_right>0 && !neutral.inexact? # maybe we didn't have enought digits
              end

              #str = str.chomp(zero).chomp(@dec_sep) if trim_trail_zeros && str.include?(@dec_sep)
              if trim_trail_zeros && str.include?(@dec_sep) &&  str[-@rep_auto.size..-1]!=@rep_auto
                str.chop! while str[-1]==zero[0]
                str.chomp!(@dec_sep)
                #puts str
              end
              
              str << get_exp_char(neutral.base)
              if @show_exp_plus || exp<0
                str << (exp<0 ? (@minus_symbol || '-') : (@plus_symbol || '+'))
              end
              str << exp.abs.to_s
                  
          end
          
        end
      end
      
      if @show_base && !@base_prefix
        b_prefix = @base_indicators[neutral.base]
        str << b_prefix if b_prefix
      end
      
      
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
      
      return str
    end
    
    # round a neutral numeral according to the format options
    def round!(neutral) # :nodoc:
      neutral.round! @ndig, @mode, @round
    end
    
    @@sci_fmt = nil
    
    def nio_read_formatted(txt) # :nodoc:
      txt = txt.dup
      num = nil
       
      base = nil
      
      base ||= get_base
     
      zero = get_base_digits(base).digit_char(0).chr 
      txt.tr!(@non_sig,zero) # we don't simply remove it because it may be before the radix point 
      
      exp = 0
      x_char = get_exp_char(base)
      
      exp_i = txt.index(x_char)
      exp_i = txt.index(x_char.downcase) if exp_i===nil
      if exp_i!=nil
        exp = txt[exp_i+1...txt.length].to_i
        txt = txt[0...exp_i] 
      end    
      

      opt = getRepDecOpt(base)
      if @rep_in
        #raise InvalidFormat,"Invalid numerical base" if base!=10
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
    
          
    @@fmts = {
      :def=>Fmt.new.freeze
    }
    # Returns the current default format.
    def self.default
      d = self[:def]
      if block_given?
        d = d.dup
        yield d
      end
      d
    end
    # Defines the current default format.
    def self.default=(fmt)
      self[:def] = fmt
    end
    # Assigns a format to a name in the formats repository.
    def self.[]=(tag,fmt_def)
      @@fmts[tag.to_sym]=fmt_def.freeze
    end
    # Retrieves a named format from the repository.
    def self.[](tag)
      @@fmts[tag.to_sym]
    end
        
    protected
    
    @@valid_properties = nil
    ALIAS_PROPERTIES = {
      :show_all_digits=>:all_digits,
      :rounding_mode=>:round,
      :approx_mode=>:approx,
      :sci_digits=>:sci_format,
      :non_signitificative_digits=>:non_sig,
      :begin=>:rep_begin,
      :end=>:rep_end,
      :suffix=>:rep_auto,
      :nreps=>:rep_n,
      :read=>:rep_in
    }
    def set!(properties={}) # :nodoc:

     
     @@valid_properties ||= instance_variables.collect{|v| v[1..-1].to_sym}
     
     
     properties.each do |k,v|
       al = ALIAS_PROPERTIES[k]
       if al
         properties[al] = v
         properties.delete k
       elsif !@@valid_properties.include?(k)
         raise InvalidOption, "Invalid option: #{k}"
       end
     end
        
     
     if properties[:grp_sep].nil? && !properties[:dec_sep].nil? && properties[:dec_sep]!=@dec_sep && properties[:dec_sep]==@grp_sep    
       properties[:grp_sep] = properties[:dec_sep]=='.' ? ',' : '.'    
     end
     
     if properties[:all_digits].nil? && (properties[:ndig] || properties[:mode])
        ndig = properties[:ndig] || @ndig
        mode = properties[:mode] || @mode
        properties[:all_digits] = ndig!=:exact && mode!=:gen   
     end
     
     if !properties[:all_digits].nil? && properties[:non_sig].nil?
       properties[:non_sig] = '' unless properties[:all_digits]
     elsif !properties[:non_sig].nil? && properties[:all_digits].nil?
       properties[:all_digits] = true if properties[:non_sig]!=''
     end
     
     if !properties[:base_radix].nil? || !properties[:base_uppercase].nil?
        base = properties[:base_radix] || @base_radix
        uppercase = properties[:base_uppercase] || @base_uppercase
        properties[:base_digits] = DigitsDef.base(base, !uppercase)
     end
     
     
     properties.each do |k,v|
       instance_variable_set "@#{k}", v unless v.nil?
     end
     
     self 
    end
    
    def set(properties={}) # :nodoc:
      self.dup.set!(properties)
    end
    
    def use_scientific?(neutral,exp) # :nodoc:
      nd = @ndig.kind_of?(Numeric) ? @ndig : [neutral.digits.length,10].max
      if @@sci_fmt==:hp
        puts "  #{nd} ndpos=#{neutral.dec_pos} ndlen=#{neutral.digits.length}"
        neutral.dec_pos>nd || ([neutral.digits.length,nd].min-neutral.dec_pos)>nd
      else
        exp<-4 || exp>=nd 
      end
    end
    
    def getRepDecOpt(base=nil) # :nodoc:
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
    
    def group(digits) # :nodoc:
      RepDec.group_digits(digits, getRepDecOpt)
    end
    
  end
  
  # This is a mix-in module to add formatting capabilities no numerical classes.
  # A class that includes this module should provide the methods
  # nio_write_neutral(fmt):: an instance method to write the value to
  #                          a neutral numeral. The format is passed so that
  #                          the base, for example, is available.
  # nio_read_neutral(neutral):: a class method to create a value from a neutral
  #                             numeral.
  module Formattable
    
    # This is the method available in all formattable objects
    # to format the value into a text string according
    # to the optional format passed.
    def nio_write(fmt=Fmt.default)
      neutral = nio_write_neutral(fmt)
      fmt.nio_write_formatted(neutral)
    end
    
    module ClassMethods
      # This is the method available in all formattable clases
      # to read a formatted value from a text string into 
      # a value the class, according to the optional format passed.
      def nio_read(txt,fmt=Fmt.default)
        neutral = fmt.nio_read_formatted(txt)
        nio_read_neutral neutral      
      end
    end
    
    # Round a formattable object according to the rounding mode and
    # precision of a format.
    def nio_round(fmt=Fmt.default)
      neutral = nio_write_neutral(fmt)
      fmt.round! neutral
      self.class.nio_read_neutral neutral      
    end
    
    def self.append_features(mod) # :nodoc:
      super
      mod.extend ClassMethods
    end
      
  end
  
  Fmt[:comma] = Fmt.sep(',','.')
  Fmt[:comma_th] = Fmt.sep(',','.',[3])
  Fmt[:dot] = Fmt.sep('.',',')
  Fmt[:dot_th] = Fmt.sep('.',',',[3])
  Fmt[:code] = Fmt.new.prec(20) # don't use :exact to avoid repeating numerals
  
  class Fmt
    # Intermediate conversion format for simplified conversion
    CONV_FMT = Fmt.prec(:exact).rep('<','>','...',0).approx_mode(:simplify)
    # Intermediate conversion format for exact conversion
    CONV_FMT_STRICT = Fmt.prec(:exact).rep('<','>','...',0).approx_mode(:exact)
    # Numerical conversion: converts the quantity +x+ to an object
    # of class +type+.
    #
    # The third parameter is the kind of conversion:
    # [<tt>:approx</tt>]
    #     Tries to find an approximate simpler value if possible for inexact
    #     numeric types. This is the default. This is slower in general and
    #     may take some seconds in some cases.
    # [<tt>:exact</tt>]
    #     Performs a conversion as exact as possible.
    # The third parameter is true for approximate
    # conversion (inexact values are simplified if possible) and false
    # for conversions as exact as possible.
    def Fmt.convert(x, type, mode=:approx)
      fmt = mode==:approx ? CONV_FMT : CONV_FMT_STRICT
      # return x.prec(type)
      if !(x.is_a?(type))
        # return type.nio_read(x.nio_write(fmt),fmt)
        
        x = x.nio_write_neutral(fmt)
        x = type.nio_read_neutral(x)
        
      end
      x
    end
  end
  
  module_function
  
  def nio_float_to_bigdecimal(x,prec) # :nodoc:
    if prec.nil?
      x = Fmt.convert(x,BigDecimal,:approx)          
    elsif prec==:exact
      x = Fmt.convert(x,BigDecimal,:exact) 
    else
      x = BigDecimal(x.nio_write(Nio::Fmt.new.prec(prec,:sig)))
    end
    x
  end
    
  
  module Clinger # :nodoc: all
  module_function

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
  
  def ratio_float(u,v,k,round_mode,beta=Float::RADIX,n=Float::MANT_DIG)
    q,r = u.divmod(v)
    v_r = v-r
    z = Math.ldexp(q,k)
    if r<v_r
      z
    elsif r>v_r
      nextfloat z
    elsif (round_mode==:even && q.even?) || (round_mode==:zero)
      z
    else
      nextfloat z
    end
  end
  
  # valid only for non-negative x
  def nextfloat(x)
    f,e = Math.frexp(x)  
    e = Float::MIN_EXP if f==0
    e = [Float::MIN_EXP,e].max
    dx = Math.ldexp(1,e-Float::MANT_DIG) #Math.ldexp(Math.ldexp(1.0,-Float::MANT_DIG),e)  
    if f==(1.0 - Math.ldexp(1,-Float::MANT_DIG))
      x + dx*2
    else
      x + dx
    end
  end

  # valid only for non-negative x
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
  
  end
  
  module BurgerDybvig # :nodoc: all
  module_function

  def float_to_digits(v,f,e,round_mode,min_e,p,b,_B)
   
   case round_mode
     when :even
       roundl = roundh = f.even?
     when :inf
       roundl = true
       roundh = false
     when :zero
       roundl = false
       roundh = true
     else
       # here we don't assume any rounding in the floating point numbers
       # the result is valid for any rounding but may produce more digits
       # than stricly necessary for specifica rounding modes.
       roundl = false
       roundh = false
   end
    
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
  
  def float_to_digits_max(v,f,e,round_mode,min_e,p,b,_B)
   
   case round_mode
     when :even
       roundl = roundh = f.even?
     when :inf
       roundl = true
       roundh = false
     when :zero
       roundl = false
       roundh = true
     else
       # here we don't assume any rounding in the floating point numbers
       # the result is valid for any rounding but may produce more digits
       # than stricly necessary for specifica rounding modes.
       roundl = false
       roundh = false
   end
    
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
  
  end
    
end

class Float
  include Nio::Formattable
  def self.nio_read_neutral(neutral)   
    x = nil
    
    honor_rounding = true
    
    if neutral.special?
      case neutral.special
        when :nan
          x = 0.0/0.0
        when :inf
          x = (neutral.sign=='-' ? -1.0 : +1.0)/0.0
      end
    elsif neutral.rep_pos<neutral.digits.length  
      
      x,y = neutral.to_RepDec.getQ
      x = Float(x)/y
      
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
       
       f = neutral.digits.to_i(neutral.base)
       e = neutral.dec_pos-neutral.digits.length

       rounding = neutral.rounding
       
       x = Nio::Clinger::algM(f,e,rounding,neutral.base,Float::RADIX,Float::MANT_DIG,Float::MIN_EXP-Float::MANT_DIG,Float::MAX_EXP-Float::MANT_DIG)
       x = -x if neutral.sign=='-'
       
      else
       
       f = neutral.digits.to_i(neutral.base)
       e = neutral.dec_pos-neutral.digits.length

       rounding = neutral.rounding
       
       x = Nio::Clinger::algM(f,e,rounding,neutral.base,Float::RADIX,Float::MANT_DIG,Float::MIN_EXP-Float::MANT_DIG,Float::MAX_EXP-Float::MANT_DIG)
       x = -x if neutral.sign=='-'
       
      end
    end
     
    return x
  end
  def nio_write_neutral(fmt)
    neutral = Nio::NeutralNum.new
    x = self
    
    if x.nan?
      neutral.set_special(:nan)
    elsif x.infinite?
      neutral.set_special(:inf, x<0 ? '-' : '+')
    else
      converted = false
      if fmt.get_ndig==:exact && fmt.get_approx==:simplify
        
        if x!=0
          q = x.nio_r(Nio::Tolerance.decimals(Float::DIG,:sig))
          if q!=0
            neutral = q.nio_write_neutral(fmt)
            converted = true if neutral.digits.length<=Float::DIG
          end
        end
        
      elsif fmt.get_approx==:exact
        neutral = x.nio_xr.nio_write_neutral(fmt)
        converted = true
      end
      if !converted  
        if fmt.get_base==10 && false
          txt = format "%.*e",Float::DECIMAL_DIG-1,x # note that spec. e output precision+1 significant digits
          
          sign = '+'    
          if txt[0,1]=='-'
            sign = '-'
            txt = txt[1...txt.length]
          end
          exp = 0
          x_char = fmt.get_exp_char(fmt.get_base)

          exp_i = txt.index(x_char)
          exp_i = txt.index(x_char.downcase) if exp_i===nil
          if exp_i!=nil
            exp = txt[exp_i+1...txt.length].to_i
            txt = txt[0...exp_i] 
          end    
          
          dec_pos = txt.index '.'
          if dec_pos==nil
            dec_pos = txt.length 
          else
            txt[dec_pos]=''
          end
          dec_pos += exp
          neutral.set sign, txt, dec_pos, nil, fmt.get_base_digits(10), true, fmt.get_round
          
          converted = true
        end
      end
      if !converted
        
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

        rounding = fmt.get_round
        
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
        
      end
    end
         
    return neutral
  end  
end

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

class Integer
  include Nio::Formattable
  def self.nio_read_neutral(neutral)   
    x = nil
    
    if neutral.special?
      raise Nio::InvalidFormat,"Invalid integer numeral"
    elsif neutral.rep_pos<neutral.digits.length  
      return Rational.nio_read_neutral(neutral).to_i
    else
      digits = neutral.digits
      
      if neutral.dec_pos <= 0
        digits = '0'
      elsif neutral.dec_pos <= digits.length
        digits = digits[0...neutral.dec_pos]
      else
        digits = digits + '0'*(neutral.dec_pos-digits.length)  
      end
      
      x = digits.to_i(neutral.base)
    # this was formely needed because we didn't adust the digits
    #  if neutral.dec_pos != neutral.digits.length
    #    # with rational included, negative powers of ten are rational numbers
    #    x = (x*((neutral.base)**(neutral.dec_pos-neutral.digits.length))).to_i   
    #  end
      x = -x if neutral.sign=='-'
    end
     
    return x
  end
  def nio_write_neutral(fmt)
    neutral = Nio::NeutralNum.new
    x = self
    
    sign = x<0 ? '-' : '+'
    txt = x.abs.to_s(fmt.get_base)
    dec_pos = rep_pos = txt.length  
    neutral.set sign, txt, dec_pos, nil, fmt.get_base_digits, false ,fmt.get_round
         
    return neutral
  end
end

class Rational
  include Nio::Formattable
  def self.nio_read_neutral(neutral)   
    x = nil
    
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
     
    return x
  end
  def nio_write_neutral(fmt)
    neutral = Nio::NeutralNum.new
    x = self
    
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
         
    return neutral
  end
end

if defined? BigDecimal
class BigDecimal
  include Nio::Formattable
  def self.nio_read_neutral(neutral)   
    x = nil
    
    if neutral.special?
      case neutral.special
        when :nan
          x = BigDecimal('NaN') # BigDecimal("0")/0
        when :inf
          x = BigDecimal(neutral.sign=='-' ? '-1.0' : '+1.0')/0
      end
    elsif neutral.rep_pos<neutral.digits.length  
      
      x,y = neutral.to_RepDec.getQ
      x = BigDecimal(x.to_s)/y
      
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
     
    return x
  end
  def nio_write_neutral(fmt)
    neutral = Nio::NeutralNum.new
    x = self
    
    if x.nan?
      neutral.set_special(:nan)
    elsif x.infinite?
      neutral.set_special(:inf, x<0 ? '-' : '+')
    else  
      converted = false
      if fmt.get_ndig==:exact && fmt.get_approx==:simplify
        
        prc = [x.precs[0],20].max
        neutral = x.nio_r(Nio::BigTolerance.decimals(prc,:sig)).nio_write_neutral(fmt)
        converted = true if neutral.digits.length<prc
        
      elsif fmt.get_approx==:exact && fmt.get_base!=10
        neutral = x.nio_xr.nio_write_neutral(fmt)
        converted = true
      end
      if !converted 
        if fmt.get_base==10 
          txt = x.to_s
          
          sign = '+'    
          if txt[0,1]=='-'
            sign = '-'
            txt = txt[1...txt.length]
          end
          exp = 0
          x_char = fmt.get_exp_char(fmt.get_base)

          exp_i = txt.index(x_char)
          exp_i = txt.index(x_char.downcase) if exp_i===nil
          if exp_i!=nil
            exp = txt[exp_i+1...txt.length].to_i
            txt = txt[0...exp_i] 
          end    
          
          dec_pos = txt.index '.'
          if dec_pos==nil
            dec_pos = txt.length 
          else
            txt[dec_pos]=''
          end
          dec_pos += exp
          neutral.set sign, txt, dec_pos, nil, fmt.get_base_digits(10), true, fmt.get_round
          
          converted = true
        end
      end  
      if !converted
        
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

        rounding = fmt.get_round
        
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
        
      end
    end
         
    return neutral
  end
end
end

