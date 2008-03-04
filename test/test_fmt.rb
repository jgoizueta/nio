

# Copyright (C) 2003-2005, Javier Goizueta <javier@goizueta.info>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

#require File.dirname(__FILE__) + '/test_helper.rb'
require 'test/unit'
require 'nio/rtnlzr'
require 'nio/repdec'
require 'nio/fmt'
include Nio
require 'yaml'

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

class TestFmt < Test::Unit::TestCase

  def setup
    
        $data = YAML.load(File.read(File.join(File.dirname(__FILE__) ,'data.yaml'))).collect{|x| [x].pack('H*').unpack('E')[0]}
        $data << MIN_N
        $data << MAX_D
        $data << MIN_D
    
  end

  def teardown
    
        Fmt.default = Fmt.new
    
  end
  
  
    def test_basic_fmt
      # test correct rounding: 1.448997445238699 -> 6525704354437805*2^-52
      assert_equal Rational(6525704354437805,4503599627370496), Float.nio_read('1.448997445238699').nio_xr
      
      assert_equal "0",0.0.nio_write    
      assert_equal "0",0.nio_write    
      assert_equal "0",BigDecimal('0').nio_write    
      assert_equal "0",Rational(0,1).nio_write    

      assert_equal "123456789",123456789.0.nio_write    
      assert_equal "123456789",123456789.nio_write    
      assert_equal "123456789",BigDecimal('123456789').nio_write    
      assert_equal "123456789",Rational(123456789,1).nio_write    
      assert_equal "123456789.25",123456789.25.nio_write    
      assert_equal "123456789.25",BigDecimal('123456789.25').nio_write    
      assert_equal "123456789.25",(Rational(123456789)+Rational(1,4)).nio_write    
    end
  
    def test_basic_fmt_float

      assert_equal 2,Float::RADIX
      assert_equal 53,Float::MANT_DIG
          
      fmt = Fmt.new {|f|
        f.rep! '[','','...',0,true  
        f.width! 20,:right,'*'
      }
      fmt.sep! '.',',',[3]    
      
      assert_equal "0.1",0.1.nio_write
      assert_equal "0.10000000000000001",0.1.nio_write(Fmt.mode(:gen,:exact).show_all_digits)
      assert_equal "0.10000000000000001",0.1.nio_write(Fmt.mode(:gen,:exact).show_all_digits(true))
      assert_equal "0.10000000000000001",0.1.nio_write(Fmt.mode(:gen,:exact,:show_all_digits=>true))
      assert_equal "0.1000000000000000055511151231257827021181583404541015625",0.1.nio_write(Fmt.mode(:gen,:exact,:approx=>:exact))
      
      
      assert_equal "******643,454,333.32",fmt.nio_write_formatted(fmt.nio_read_formatted("643,454,333.32"))        
      assert_equal "******643.454.333,32",fmt.sep(',').nio_write_formatted(fmt.nio_read_formatted("643,454,333.32"))        
      fmt.pad0s! 10
      num = fmt.nio_read_formatted("0.3333...")
      assert_equal "0000000.[3",fmt.nio_write_formatted(num)
      fmt.mode! :fix, 3
      assert_equal "000000.333",fmt.nio_write_formatted(num)
      num = fmt.nio_read_formatted("-0.666...")  
      fmt.prec! :exact
      fmt.sep! ',','.'
      assert_equal "-000000,[6",fmt.nio_write_formatted(num)
      fmt.width! 20,:center,'*'
      fmt.mode! :fix,3
      assert_equal "*******-0,667*******",fmt.nio_write_formatted(num)
      num = fmt.nio_read_formatted("0,5555")  
      fmt.prec! :exact
      assert_equal "*******0,5555*******",fmt.nio_write_formatted(num)

      Fmt.default = Fmt[:comma_th]
      x = Float.nio_read("11123,2343")
      assert_equal 11123.2343,x
      assert_equal "11.123,2343", x.nio_write
      assert_equal "11123,2343", x.nio_write(Fmt[:comma])
      
      x = Float.nio_read("-1234,5678901234e-33")
      # assert_equal -1.2345678901234e-030, x
      assert_equal "-1,2345678901234E-30", x.nio_write()
      assert_equal "-0,0000000000000000000000000000012346",x.nio_write(Fmt[:comma].mode(:sig,5))

      assert_equal "0,333...", 
                   (1.0/3).nio_write(Fmt.prec(:exact).show_all_digits(true).approx_mode(:simplify))
                   
      fmt = Fmt.default
      if RUBY_VERSION>='1.9.0'
        assert_raises RuntimeError do fmt.prec! 4 end
      else
        assert_raises TypeError do fmt.prec! 4 end
      end
      fmt = Fmt.default {|f| f.prec! 4 }
      assert_equal "1,235", 1.23456.nio_write(fmt)
      assert_equal "1,23456", 1.23456.nio_write()
                         
      Fmt.default = Fmt.new
      assert_equal '11123.2343', 11123.2343.nio_write
    end
  
    def test_tol_fmt_float
      tol = Tolerance.new.decimals(12,:sig)
      fmt = Fmt.prec(12,:sig)
      $data.each do |x|
         assert tol.equals?(x, Float.nio_read(x.nio_write(fmt),fmt)), "out of tolerance: #{x.inspect} #{Float.nio_read(x.nio_write(fmt),fmt)}"
         assert tol.equals?(-x, Float.nio_read((-x).nio_write(fmt),fmt)), "out of tolerance: #{(-x).inspect} #{Float.nio_read((-x).nio_write(fmt),fmt)}"
      end
    end
  
    def test_BigDec
      assert_equal "0",BigDec(0).nio_write        
      fmt = Fmt.mode(:gen,:exact)
      assert_equal "0",BigDec(0).nio_write(fmt)
      $data.each do |x|
        x = BigDecimal(x.to_s)
        assert_equal x,BigDecimal.nio_read(x.nio_write(fmt),fmt)
      end
      assert_equal "1E500",BigDec('1E500').nio_write        
      assert_equal "1E-500",BigDec('1E-500').nio_write        
      assert_equal "-1E500",BigDec('-1E500').nio_write        
      assert_equal "-1E-500",BigDec('-1E-500').nio_write            
    end
  
    def test_Rational
      assert_equal "0",Rational(0,1).nio_write        
      fmt = Fmt.mode(:gen,:exact)
      assert_equal "0",Rational(0,1).nio_write(fmt)
      $data.each do |x|
        x = x.nio_xr # nio_r
        assert_equal x,Rational.nio_read(x.nio_write(fmt),fmt)
      end    
    end
  
    def test_float_bases
      nfmt2 = Fmt[:comma].base(2).prec(:exact)
      nfmt8 = Fmt[:comma].base(8).prec(:exact)
      nfmt10 = Fmt[:comma].base(10).prec(:exact)
      nfmt16 = Fmt[:comma].base(16).prec(:exact)
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
  
    def rational_bases
        assert_equal "0.0001100110011...", (Rational(1)/10).nio_write(Fmt.new.base(2))
    end
  
    def test_big_decimal_bases
      
      assert_equal "0.1999A",(BigDec(1)/10).nio_write(Fmt.new.base(16).prec(5))
      assert_equal "0.1999...",(BigDec(1)/10).nio_write(Fmt.mode(:gen,:exact,:round=>:inf,:approx=>:simplify).base(16))
      
      nfmt2 = Fmt[:comma].base(2).prec(:exact)
      nfmt8 = Fmt[:comma].base(8).prec(:exact)
      nfmt10 = Fmt[:comma].base(10).prec(:exact)
      nfmt16 = Fmt[:comma].base(16).prec(:exact)
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
  
    def test_exact_all_float
      #fmt = Fmt.prec(:exact).show_all_digits(true).approx_mode(:exact)
      fmt = Fmt.mode(:gen,:exact,:round=>:inf,:approx=>:exact)
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
  
    def test_float_nonsig
      
      assert_equal "100.000000000000000#####", 100.0.nio_write(Fmt.prec(20,:fix).insignificant_digits('#'))

      fmt = Fmt.mode(:sci,20).insignificant_digits('#').sci_digits(1)
      assert_equal "3.3333333333333331###E-1", (1.0/3).nio_write(fmt)
      assert_equal "3.3333333333333335###E6", (1E7/3).nio_write(fmt)
      assert_equal "3.3333333333333334###E-8", (1E-7/3).nio_write(fmt)
      assert_equal "3.3333333333333333333E-1",  Rational(1,3).nio_write(fmt)
      assert_equal "3.3333333333333331###E-1", (1.0/3).nio_write(fmt.dup.sci_digits(1))
      assert_equal "33333333333333331###.E-20", (1.0/3).nio_write(fmt.dup.sci_digits(-1))
      assert_equal "33333333333333333333.E-20", (Rational(1,3)).nio_write(fmt.dup.sci_digits(-1))

      fmt.sci_digits! :eng
      assert_equal "333.33333333333331###E-3", (1.0/3).nio_write(fmt)
      assert_equal "3.3333333333333335###E6", (1E7/3).nio_write(fmt)
      assert_equal "33.333333333333334###E-9",(1E-7/3).nio_write(fmt)
      
      fmt = Fmt[:comma].mode(:sci,20).insignificant_digits('#').sci_digits(0)
      assert_equal "0,33333333333333331###E0",(1.0/3).nio_write(fmt)
      assert_equal "0,33333333333333335###E7",(1E7/3).nio_write(fmt)
      assert_equal "0,33333333333333334###E-7",(1E-7/3).nio_write(fmt)
      
      fmt = Fmt.mode(:sci,20).insignificant_digits('#').sci_digits(0)
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
      x = Float.nio_read('1E23',Fmt.prec(:exact,:gen,:round=>:even))
      assert_equal "1E23",x.nio_write(Fmt.prec(:exact,:gen,:round=>:zero))
      assert_equal "9.999999999999999E22",x.nio_write(Fmt.prec(:exact,:gen,:round=>:inf))
      assert_equal "1E23",x.nio_write(Fmt.prec(:exact,:gen,:round=>:even))    

      x = Float.nio_read('1E23',Fmt.prec(:exact,:gen,:round=>:zero))
      assert_equal "1E23",x.nio_write(Fmt.prec(:exact,:gen,:round=>:zero))
      assert_equal "9.999999999999999E22",x.nio_write(Fmt.prec(:exact,:gen,:round=>:inf))
      assert_equal "1E23",x.nio_write(Fmt.prec(:exact,:gen,:round=>:even))    

      x = Float.nio_read('1E23',Fmt.prec(:exact,:gen,:round=>:inf))
      assert_equal "1E23",x.nio_write(Fmt.prec(:exact,:gen,:round=>:inf))
      assert_equal "1.0000000000000001E23",x.nio_write(Fmt.prec(:exact,:gen,:round=>:zero))
      assert_equal "1.0000000000000001E23",x.nio_write(Fmt.prec(:exact,:gen,:round=>:even))    

      x = Float.nio_read('-1E23',Fmt.prec(:exact,:gen,:round=>:even))
      assert_equal "-1E23",x.nio_write(Fmt.prec(:exact,:gen,:round=>:zero))
      assert_equal "-9.999999999999999E22",x.nio_write(Fmt.prec(:exact,:gen,:round=>:inf))
      assert_equal "-1E23",x.nio_write(Fmt.prec(:exact,:gen,:round=>:even))    

      x = Float.nio_read('-1E23',Fmt.prec(:exact,:gen,:round=>:zero))
      assert_equal "-1E23",x.nio_write(Fmt.prec(:exact,:gen,:round=>:zero))
      assert_equal "-9.999999999999999E22",x.nio_write(Fmt.prec(:exact,:gen,:round=>:inf))
      assert_equal "-1E23",x.nio_write(Fmt.prec(:exact,:gen,:round=>:even))    

      x = Float.nio_read('-1E23',Fmt.prec(:exact,:gen,:round=>:inf))
      assert_equal "-1E23",x.nio_write(Fmt.prec(:exact,:gen,:round=>:inf))
      assert_equal "-1.0000000000000001E23",x.nio_write(Fmt.prec(:exact,:gen,:round=>:zero))
      assert_equal "-1.0000000000000001E23",x.nio_write(Fmt.prec(:exact,:gen,:round=>:even))    
      
      # note: for 64.1 there's only one closest Float; 
      #   but it can be univocally expressed in decimal either as 64.09999999999999 or 64.1
      x = Float.nio_read('64.1',Fmt.prec(:exact,:gen,:round=>:even))
      assert_equal "64.09999999999999",x.nio_write(Fmt.prec(:exact,:gen).show_all_digits(true))
      assert_equal "64.1",x.nio_write(Fmt.prec(:exact,:gen))
      
      # to do:  exact conversion of Rational(32095022417, 54517) should throw and exception
      #         (unless RepDec.max_d is greater than 27300 or so)
      
      
    end
  
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
  
    def test_conversions
      x_txt = '1.234567890123456'
      x_d = BigDecimal.nio_read(x_txt)
      x_f = Float.nio_read(x_txt)
      assert_equal 1.234567890123456, x_f
      assert_equal BigDecimal(x_txt), x_d
      assert_equal Fmt.convert(x_d,Float,:exact), x_f
      assert_equal Fmt.convert(x_d,Float,:approx), x_f
      
      x_d = BigDec(355)/226
      x_f = Float(355)/226
      assert_equal Fmt.convert(x_d,Float,:exact), x_f
      assert_equal Fmt.convert(x_d,Float,:approx), x_f
      
    end
    
    def test_sign
      assert_equal '1.23', 1.23.nio_write
      assert_equal '+1.23', 1.23.nio_write(Fmt.show_plus)
      assert_equal ' 1.23', 1.23.nio_write(Fmt.show_plus(' '))
      assert_equal '-1.23', -1.23.nio_write
      assert_equal '-1.23', -1.23.nio_write(Fmt.show_plus)
      assert_equal '1.23E5', 1.23E5.nio_write(Fmt.mode(:sci))
      assert_equal '-1.23E5', -1.23E5.nio_write(Fmt.mode(:sci))
      assert_equal '1.23E-5', 1.23E-5.nio_write(Fmt.mode(:sci))
      assert_equal '-1.23E-5', -1.23E-5.nio_write(Fmt.mode(:sci))
      assert_equal '+1.23E5', 1.23E5.nio_write(Fmt.mode(:sci).show_plus)
      assert_equal '-1.23E5', -1.23E5.nio_write(Fmt.mode(:sci).show_plus)
      assert_equal ' 1.23E5', 1.23E5.nio_write(Fmt.mode(:sci).show_plus(' '))
      assert_equal '-1.23E5', -1.23E5.nio_write(Fmt.mode(:sci).show_plus(' '))
      assert_equal '1.23E+5', 1.23E5.nio_write(Fmt.mode(:sci).show_exp_plus)
      assert_equal '-1.23E+5', -1.23E5.nio_write(Fmt.mode(:sci).show_exp_plus)
      assert_equal '1.23E 5', 1.23E5.nio_write(Fmt.mode(:sci).show_exp_plus(' '))
      assert_equal '-1.23E 5', -1.23E5.nio_write(Fmt.mode(:sci).show_exp_plus(' '))
      assert_equal '1.23E-5', 1.23E-5.nio_write(Fmt.mode(:sci).show_exp_plus(' '))
      assert_equal '-1.23E-5', -1.23E-5.nio_write(Fmt.mode(:sci).show_exp_plus(' '))
      assert_equal ' 1.23E-5', 1.23E-5.nio_write(Fmt.mode(:sci).show_exp_plus(' ').show_plus)
      assert_equal '-1.23E-5', -1.23E-5.nio_write(Fmt.mode(:sci).show_exp_plus(' ').show_plus)
      assert_equal ' 1.23E 5', 1.23E5.nio_write(Fmt.mode(:sci).show_exp_plus(' ').show_plus)
      assert_equal '-1.23E 5', -1.23E5.nio_write(Fmt.mode(:sci).show_exp_plus(' ').show_plus)
      assert_equal '+1.23E-5', 1.23E-5.nio_write(Fmt.mode(:sci).show_exp_plus.show_plus)
      assert_equal '-1.23E-5', -1.23E-5.nio_write(Fmt.mode(:sci).show_exp_plus.show_plus)
      assert_equal '+1.23E+5', 1.23E5.nio_write(Fmt.mode(:sci).show_exp_plus.show_plus)
      assert_equal '-1.23E+5', -1.23E5.nio_write(Fmt.mode(:sci).show_exp_plus.show_plus)
    end
      
   

end
