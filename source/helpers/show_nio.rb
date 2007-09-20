  require 'rubygems'
  require 'nio'
  require 'nio/sugar'
  include Nio

  x = Math.sqrt(2)+100
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
  

  puts Float.nio_read('0.1')
  puts BigDecimal.nio_read('0.1') 
  puts Rational.nio_read('0.1')  
  puts Integer.nio_read('0.1')   
  
  puts Float.nio_read('0,1',Fmt.sep(','))
  puts Float.nio_read('122.344,1',Fmt.sep(','))
  puts Float.nio_read('122,344.1',Fmt.sep('.'))

  x = 2.0/3
  fmt = Fmt.mode(:fix,20)
  puts x.nio_write(fmt) 
  # we're dealing with an approximate numerical type, Float and
  # we're trying to show more than the internal precision of the type
  # we can use a placeholder for the insignificant positions:
  puts x.nio_write(fmt.insignificant_digits('#')) 
  # or we can treat the type as it was exactly defined
  puts x.nio_write(fmt.approx_mode(:exact)) 

