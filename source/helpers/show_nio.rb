  require 'rubygems'
  require 'nio'
  require 'nio/sugar'
  include Nio

  x = Math.sqrt(2)+100
  
  # writing  
  puts x.nio_write
  puts x.nio_write(Fmt.mode(:fix,4))
  puts x.nio_write(Fmt.mode(:sig,4))
  puts x.nio_write(Fmt.mode(:sci,4))
  puts x.nio_write(Fmt.mode(:gen,4)) 
  puts (1e7*x).nio_write(Fmt.mode(:gen,4))  
  puts (1e7*x).nio_write(Fmt.mode(:gen,4).show_plus)   
  puts x.nio_write(Fmt.mode(:gen,:exact))
  x *= 1111
  fmt = Fmt.mode(:fix,4)
  puts x.nio_write(fmt.sep(','))
  puts x.nio_write(fmt.sep(',','.',[3]))
  puts x.nio_write(fmt.sep(',',' ',[2,3]))
  fmt = Fmt.mode(:fix,2)
  puts 11.2.nio_write(fmt.width(8))
  puts 11.2.nio_write(fmt.width(8,:right,'*'))
  puts 11.2.nio_write(fmt.width(8,:right,'*').show_plus)
  puts 11.2.nio_write(fmt.width(8,:internal,'*').show_plus)
  puts 11.2.nio_write(fmt.width(8,:left,'*'))
  puts 11.2.nio_write(fmt.width(8,:center,'*'))
  puts 11.2.nio_write(fmt.pad0s(8))
  puts BigDec(11.2).nio_write(fmt.pad0s(8))
  puts Rational(112,10).nio_write(fmt.pad0s(8))
  puts 112.nio_write(fmt.pad0s(8))
  puts 34222223344.nio_write(fmt.base(16))
  puts x.nio_write(Fmt.base(16))
  puts x.nio_write(Fmt.mode(:fix,4).base(2))
  puts 1.234333E-23.nio_write(Fmt.base(2).prec(20))

  # notation alternatives
  puts Fmt << x
  puts Fmt.mode(:fix,4) << x
  
  puts Fmt.write(x)
  puts Fmt.mode(:fix,4).write(4)
  
  # reading
  puts Float.nio_read('0.1')
  puts BigDecimal.nio_read('0.1') 
  puts Rational.nio_read('0.1')  
  puts Integer.nio_read('0.1')   
  
  puts Float.nio_read('0,1',Fmt.sep(','))
  puts Float.nio_read('122.344,1',Fmt.sep(','))
  puts Float.nio_read('122,344.1',Fmt.sep('.'))
  
  # notation alternatives
  puts Fmt.read(Float,'0.1')
  puts Fmt.sep(',').read(Float,'0,1')
  
  puts Fmt >> [Float, '0.1']
  puts Fmt.sep(',') >> [Float, '0,1']
  
  # Fmt.<< Float, '0.1'
  # Fmt.sep(',').<< Float, '0,1'
  
  # Float << '0.1'
  # Float << ['0,1',Fmt.sep(',')]_
  

  x = 2.0/3
  fmt = Fmt.mode(:fix,20)
  puts x.nio_write(fmt) 
  # we're dealing with an approximate numerical type, Float and
  # we're trying to show more than the internal precision of the type
  # we can use a placeholder for the insignificant positions:
  puts x.nio_write(fmt.insignificant_digits('#')) 
  # or we can treat the type as it was exactly defined
  puts x.nio_write(fmt.approx_mode(:exact)) 


  # conversions
  puts Nio.convert(1.0/3, Rational)
  puts Nio.convert(1.0/3, Rational, :exact)
  puts Nio.convert(1.0/3, BigDecimal)
  puts Nio.convert(1.0/3, BigDecimal, :exact)
  puts Nio.convert(Rational(1,3), Float)
  puts Nio.convert(Rational(1,3), BigDecimal)
  puts Nio.convert(BigDecimal('1')/3, Rational)
  puts Nio.convert(BigDecimal('1')/3, Rational, :exact)
  puts Nio.convert(BigDecimal('1')/3, Float)
  puts Nio.convert(BigDecimal('1')/3, Float, :exact)
 
  puts Nio.convert(2.0/3, Rational)
  puts Nio.convert(2.0/3, Rational, :exact)
  puts Nio.convert(2.0/3, BigDecimal)
  puts Nio.convert(2.0/3, BigDecimal, :exact)
  puts Nio.convert(Rational(2,3), Float)
  puts Nio.convert(Rational(2,3), BigDecimal)
  puts Nio.convert(BigDecimal('2')/3, Rational)
  puts Nio.convert(BigDecimal('2')/3, Rational, :exact)
  puts Nio.convert(2.0/3, BigDecimal)
  puts Nio.convert(2.0/3, BigDecimal, :exact)
  puts Nio.convert(BigDecimal('2')/3, Float)
