

# Copyright (C) 2003-2005, Javier Goizueta <javier@goizueta.info>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

#require File.dirname(__FILE__) + '/test_helper.rb'
require 'test/unit'

require 'nio/repdec'
include Nio
require 'yaml'

class TestRepdec < Test::Unit::TestCase

  def setup
    
  end

  
    def test_basic_repdec
      r = RepDec.new
      assert_equal "2.<3>", r.setQ(7,3).getS(0)
      assert_equal [7, 3], r.setQ(7,3).getQ

      assert_equal "1.<3>", r.setS("1.<3>").getS(0)
      assert_equal [4, 3], r.setS("1.<3>").getQ

      assert_equal "254.34212<678>", r.setS("254.34212<678>").getS(0)
      assert_equal [4234796411, 16650000], r.setS("254.34212<678>").getQ

      assert_equal "254.34212<678>", r.setS("254.34212678678...").getS(0)
      assert_equal [4234796411, 16650000], r.setS("254.34212678678...").getQ

      assert_equal "254.34212<678>", r.setS("254.34212678678678678...").getS(0)
      assert_equal [4234796411, 16650000], r.setS("254.34212678678678678...").getQ

      assert_equal "0.<3>", r.setS("0.3333333...").getS(0)
      assert_equal [1, 3], r.setS("0.3333333...").getQ

      assert_equal "-7.2<14>", r.setS("-7.2141414...").getS(0)
      assert_equal [-3571, 495], r.setS("-7.2141414...").getQ

      assert_equal "-7.21414...", r.setS("-7.2141414...").getS(1)
      assert_equal [-3571, 495], r.setS("-7.2141414...").getQ

      assert_equal "1.<234545>", r.setS("1.234545234545...").getS(0)
      assert_equal [1234544, 999999], r.setS("1.234545234545...").getQ

      assert_equal "1.234545234545...", r.setS("1.234545234545...").getS(1)
      assert_equal [1234544, 999999], r.setS("1.234545234545...").getQ

      assert_equal "1.23454523<45>", r.setS("1.23454523454545...").getS(0)
      assert_equal [678999879, 550000000], r.setS("1.23454523454545...").getQ

      assert_equal "1.23454523454545...", r.setS("1.23454523454545...").getS(1)
      assert_equal [678999879, 550000000], r.setS("1.23454523454545...").getQ

      assert_equal "0.<9>", r.setS(".<9>").getS(0)
      assert_equal [1, 1], r.setS(".<9>").getQ

      assert_equal "0.1<9>", r.setS("0.1999999...",RepDec::DEF_OPT.dup.set_digits(DigitsDef.base(16))).getS(0)
      assert_equal [1, 10], r.setS("0.1999999...",RepDec::DEF_OPT.dup.set_digits(DigitsDef.base(16))).getQ

      assert_equal "Infinity", r.setQ(10,0).getS(0)
      assert_equal [1, 0], r.setQ(10,0).getQ

      assert_equal "-Infinity", r.setQ(-10,0).getS(0)
      assert_equal [-1, 0], r.setQ(-10,0).getQ

      assert_equal "NaN", r.setQ(0,0).getS(0)
      assert_equal [0, 0], r.setQ(0,0).getQ

      assert_equal "NaN", r.setS("NaN").getS(0)
      assert_equal [0, 0], r.setS("NaN").getQ

      assert_equal "Infinity", r.setS("Infinity").getS(0)
      assert_equal [1, 0], r.setS("Infinity").getQ

      assert_equal "-Infinity", r.setS("-Infinity").getS(0)
      assert_equal [-1, 0], r.setS("-Infinity").getQ    
    end
   
end
 