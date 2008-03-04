# repdec.rb -- Repeating Decimals (Repeating Numerals, actually)

# Copyright (C) 2003-2005, Javier Goizueta <javier@goizueta.info>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

require 'nio/tools'
module Nio
  
  class RepDecError <StandardError
  end
  
  class DigitsDef
    include StateEquivalent
    def initialize(ds='0123456789', cs=true)
      @digits = ds
      @casesens = cs
      @dncase = (ds.downcase==ds)
      @radix = @digits.size
    end
    def is_digit?(ch_code)
      ch_code = set_case(ch_code) unless @casesens
      @digits.include?(ch_code)
    end
    def digit_value(ch_code)
      ch_code = set_case(ch_code) unless @casesens
      @digits.index(ch_code.chr)
    end
    def digit_char(v)
      @digits[v]
    end
    def digit_char_safe(v)
      v>=0 && v<@radix ? @digits[v] : nil
    end
    def radix
      @radix
    end
    def DigitsDef.base(b,dncase=false,casesens=false)
      dgs = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"[0,b]
      dgs.downcase! if dncase
      DigitsDef.new(dgs,casesens)
    end
    private
    def set_case(ch_code)
      ch_code = ch_code.chr if ch_code.kind_of?(Numeric)
      @dncase ? ch_code.downcase[0] : ch_code.upcase[0]
    end
  end  
    
  
  # RepDec handles repeating decimals (repeating numerals actually)
  class RepDec
    include StateEquivalent
    
    class Opt # :nodoc:
      include StateEquivalent
      def initialize() #default options
        
        @begin_rep = '<'
        @end_rep = '>'
        
        @auto_rep = '...'
        
        @dec_sep = '.'
        @grp_sep = ','
        @grp = [] # [3] for thousands separators
        
        @inf_txt = 'Infinity'
        @nan_txt = 'NaN'
        
        @digits = DigitsDef.new
        @digits_defined = false
        
        @max_d = 5000
        
      end  
      attr_accessor :begin_rep, :end_rep, :auto_rep, :dec_sep, :grp_sep, :grp, :max_d
      attr_accessor :nan_txt, :inf_txt
      
      def set_delim(begin_d,end_d='')
        @begin_rep = begin_d
        @end_rep = end_d
        return self
      end
      def set_suffix(a)
        @auto_rep = a
        return self
      end
      def set_sep(d)
        @dec_sep = a
        return self
      end
      def set_grouping(sep,g=[])
        @grp_sep = a
        @grp = g
        return self
      end
      def set_special(nan_txt, inf_txt)
        @nan_txt = nan_txt
        @inf_txt = inf_txt
        return self
      end
      
      def set_digits(ds, dncase=false, casesens=false)
        if ds  
          @digits_defined = true
          if ds.kind_of?(DigitsDef)
            @digits = ds
          elsif ds.kind_of?(Numeric)
            @digits = DigitsDef.base(ds, dncase, casesens)
          else
            @digits = DigitsDef.new(ds,casesens)
          end
        else
          @digits = DigitsDef.new
          @digits_defined = false
        end
        self
      end
      
      attr_accessor :digits
      def digits_defined?
        @digits_defined
      end
      
    end
    
    DEF_OPT=Opt.new
    
    
    def initialize(b=10)
      setZ(b)
    end
    
    def setZ(b=10)
       @ip    = 0;
       @d     = [];
       @rep_i = nil;
       @sign  = 0;
       @radix = b;
       self
    end
    
    def setS(str, opt=DEF_OPT) 
      setZ(opt.digits_defined? ? opt.digits.radix : @radix);
      sgn,i_str,f_str,ri,detect_rep = RepDec.parse(str,opt)
      if i_str.kind_of?(Symbol)
        @ip = i_str
      else
        @ip = i_str.to_i(@radix); # this assumes conventional digits
      end
      @sign = sgn
      @rep_i = ri if ri
      f_str.each_byte{|b| @d.push opt.digits.digit_value(b)} unless f_str.nil?
      
      if detect_rep then
        
        for l in 1..(@d.length/2)
          l = @d.length/2 + 1 - l;
          if @d[-l..-1]==@d[-2*l...-l]
            
            for m in 1..l
              if l.modulo(m)==0 then
                reduce_l = true;
                for i in 2..l/m
                  if @d[-m..-1]!=@d[-i*m...-i*m+m] then
                     reduce_l = false;
                     break;
                   end
                end
                if reduce_l then
                   l = m
                   break
                end 
              end
            end
                     
            
            @rep_i = @d.length - 2*l;
            l.times { @d.pop }
            
            
            while @d.length >= 2*l && @d[-l..-1]==@d[-2*l...-l] 
              
              @rep_i = @d.length - 2*l;
              l.times { @d.pop }
              
            end
                
            break
          end
        end 
        
      end

      
      if @rep_i!=nil then
        if @d.length==@rep_i+1 && @d[@rep_i]==0 then
          @rep_i = nil;
          @d.pop;
        end  
      end
      @d.pop while @d[@d.length-1]==0
        
      self
    end
    
    def RepDec.parse(str, opt=DEF_OPT)
      sgn,i_str,f_str,ri,detect_rep = nil,nil,nil,nil,nil

      i = 0;
      l = str.length;

      detect_rep = false;

      
      i += 1 while i<str.length && str[i,1] =~/\s/
      
      
      neg = false;

      neg = true if str[i,1]=='-'
      i += 1 if str[i,1]=='-' || str[i,1]=='+'
      

      i += 1 while i<str.length && str[i,1] =~/\s/
      

      str.upcase!
      if str[i,opt.nan_txt.size]==opt.nan_txt.upcase
        i_str = :indeterminate;
      elsif str[i,opt.inf_txt.size]==opt.inf_txt.upcase
        i_str = neg ? :neginfinity : :posinfinity;
      end
      
      unless i_str
        i_str = "0";
        while i<l && str[i,1]!=opt.dec_sep
          break if str[i,opt.auto_rep.length]==opt.auto_rep && opt.auto_rep!=''
          i_str += str[i,1] if str[i,1]!=opt.grp_sep
          i += 1;
        end
        sgn = neg ? -1 : +1
        i += 1; # skip the decimal separator
      end
      
      unless i_str.kind_of?(Symbol)
        j = 0;  
        f_str = ''
        while i<l
          ch = str[i,1];
          if ch==opt.begin_rep then
            ri = j;
          elsif ch==opt.end_rep then
            i = l;
          elsif ch==opt.auto_rep[0,1] then
            detect_rep = true;
            i = l;
          else
            f_str << ch
            j += 1;
          end
          i += 1;
        end
      end
      return [sgn,i_str,f_str,ri,detect_rep]
    end
    
    def getS(nrep=0, opt=DEF_OPT)
      raise RepDecError,"Base mismatch: #{opt.digits.radix} when #{@radix} was expected." if opt.digits_defined? && @radix!=opt.digits.radix
       
       if !ip.is_a?(Integer) then
         str=opt.nan_txt if ip==:indeterminate;
         str=opt.inf_txt if ip==:posinfinity
         str='-'+opt.inf_txt if ip==:neginfinity
         return str;
       end
       
       s = "";
       s += '-' if @sign<0
       s += RepDec.group_digits(@ip.to_s(@radix),opt);
       s += opt.dec_sep if @d.length>0;
       for i in 0...@d.length
         break if nrep>0 && @rep_i==i;
         s += opt.begin_rep if i==@rep_i;
         s << opt.digits.digit_char(@d[i])
       end;
       if nrep>0 then
         if @rep_i!=nil then
            nrep += 1;
            nrep.times do
              for i in @rep_i...@d.length
               s << opt.digits.digit_char(@d[i])
              end
            end
            
            check = RepDec.new;
            check.setS s+opt.auto_rep, opt;
            #print " s=",s,"\n"
            #print " self=",self.to_s,"\n"
             while check!=self
              for i in @rep_i...@d.length
               s << opt.digits.digit_char(@d[i])
              end
              check.setS s+opt.auto_rep, opt;
            end
            
            s += opt.auto_rep;
         end
       else
         s += opt.end_rep if @rep_i!=nil;         
       end
       return s;
    end
    
    def to_s()
      getS
    end
    
    def normalize!(remove_trailing_zeros=true)
      if ip.is_a?(Integer)
        if @rep_i!=nil && @rep_i==@d.length-1 && @d[@rep_i]==(@radix-1) then
          @d.pop;
          @rep_i = nil;
          
          i = @d.length-1;
          carry = 1;
          while carry>0 && i>=0
            @d[i] += carry;
            carry = 0;
            if @d[i]>(@radix) then
              carry = 1;
              @d[i]=0;
              @d.pop if i==@d.length;
            end
            i -= 1;
          end 
          @ip += carry;
          
        end
        
        if @rep_i!=nil && @rep_i>=@d.length
          @rep_i = nil
        end
        
        if @rep_i!=nil && @rep_i>=0
          unless @d[@rep_i..-1].find {|x| x!=0}
            @d = @d[0...@rep_i]
            @rep_i = nil
          end
        end
        if @rep_i==nil && remove_trailing_zeros
          while @d[@d.length-1]==0
            @d.pop
          end
        end
        
      end
    end
    
    def copy()
      c = clone
      c.d = d.clone
      return c;
    end
    
    def ==(c)
      a = copy;
      b = c.copy;
      a.normalize!
      b.normalize!
      return a.ip==b.ip && a.d==b.d && a.rep_i==b.rep_i
    end
    
    #def !=(c)
    #  return !(self==c);
    #end
    
    # Change the maximum number of digits that RepDec objects
    # can handle.
    def RepDec.maximum_number_of_digits=(n)
      @max_d = [n,2048].max
    end
    # Return the maximum number of digits that RepDec objects
    # can handle.
    def RepDec.maximum_number_of_digits
      @max_d
    end
    
    def setQ(x,y, opt=DEF_OPT)
      @radix = opt.digits.radix if opt.digits_defined?
      xy_sign = x==0 ? 0 : x<0 ? -1 : +1;
      xy_sign = -xy_sign if y<0;
      @sign = xy_sign
      x = x.abs;
      y = y.abs;

      @d = [];
      @rep_i = nil;
      
      if y==0 then
        if x==0 then
          @ip = :indeterminate
        else
          @ip = xy_sign==-1 ? :neginfinity : :posinfinity
        end
        return self
      end
      
      k = {};
      @ip = x.div(y) #x/y;
      x -= @ip*y;
      i = 0;
      ended = false;

      max_d = opt.max_d
      while x>0 && @rep_i==nil && (max_d<=0 || i<max_d)
        @rep_i = k[x]
        if @rep_i.nil? then
          k[x] = i;
          x *= @radix
          d,x = x.divmod(y)
          @d.push d
          i += 1;  
        end
      end
      self  
    end
    
    def getQ(opt=DEF_OPT)
      raise RepDecError,"Base mismatch: #{opt.digits.radix} when #{@radix} was expected." if opt.digits_defined? && @radix!=opt.digits.radix
      
      if !ip.is_a?(Integer) then
        y = 0;
        x=0 if ip==:indeterminate;
        x=1 if ip==:posinfinity
        x=-1 if ip==:neginfinity
        return x,y;
      end if

      
      n = @d.length 
      a = @ip
      b = a
      for i in 0...n
        a*=@radix
        a+=@d[i];
        if @rep_i!=nil && i<@rep_i
          b *= @radix
          b += @d[i];
        end
      end

      x = a
      x -= b if @rep_i!=nil

      y = @radix**n
      y -= @radix**@rep_i if @rep_i!=nil

      d = Nio.gcd(x,y)
      x /= d
      y /= d
     
      x = -x if @sign<0
     
      return x,y;    
    end
    
    #protected
    
    attr_reader :d, :ip, :rep_i, :sign;
    attr_writer :d, :ip, :rep_i, :sign;
      
  end
    
  
  def RepDec.group_digits(digits, opt)
    if opt.grp_sep!=nil && opt.grp_sep!='' && opt.grp.length>0
      grouped = ''      
      i = 0
      while digits.length>0  
        l = opt.grp[i]
        l = digits.length if l>digits.length
        grouped = opt.grp_sep + grouped if grouped.length>0
        grouped = digits[-l,l] + grouped
        digits = digits[0,digits.length-l]
        i += 1 if i<opt.grp.length-1
      end
      grouped
    else
     digits
    end    
  end
  
  module_function
  
  def gcd(a,b)
    while b!=0 do
      a,b = b, a.modulo(b)
    end
    return a.abs;  
  end
  
end
