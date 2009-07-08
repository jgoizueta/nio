require 'nio/tools'
module Nio


# Replace RepDec, NeutralNum
# doesn't handle IO, so RepDec::Opt is not here (Nio handles IO), except max_d that must be moved elsewere
# a separate RepDec module may persit to handle text IO of Numerals (recognize repetitions, etc.)

# Represents a rendition of an numerical value in a positional system.
# It is format-neutral (doesn't include or handles actual representation)
# It handles numeric conversions and repeating digits.
class Numeral
  # @sign, @digits (array or integers),@radix,  @rep_pos, @pnt_pos (scale),:=>:nan, :inf (as Flt)

  # determine interpretation of pnt_pos/scale
  # conversions: Integer, Rational, DecNum, BinNum

end # Numeral


end # Nio