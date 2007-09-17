=Description

Nio (Numeric input/output) is a Ruby package
for formatting and conversion of scalar
numeric types.

It handles formatting and conversion for the
types Integer, Rational, BigDecimal and Float and
adds some utilities.

Nio offers low level services; formatting is only in positional
notation and for scalar types.
(It does not handle composite types such as Complex,
or fraction notation for rationals; those are higher level
services that could be implemented using Nio).

The implementaion of Nio is pure Ruby, and not specially fast;
it is complete and accurate, though.

Nio has some interesting features:

* Correctly rounded conversions of all types to and from
  positional numerals in any base.
* Handling of digit repetitions (repeating decimals or, in general, repeating numerals).
* Discrimitation of significative digits of the representation of Float in any base.
  (nonsignificative digits are those that can take any value without altering the
   Float value they specify.)

Limitations:
*  UTF-8 and shift encodings are not currently
   fully supported.

=Notes: 
  * BigDec() is a handy convenience to define BigDecimals;
    It allows shortcuts such as BigDec(1) rather than the
    more verbose BigDecimal('1').
    It may be used also with Float arguments, e.g.
      BigDec(0.5)
    This is a questionable use (it has been avoided in Python)
    but is allowed here becouse BigDec purpose is shortcut  
    (BigDecimal() on the other hand should probably not accept Floats)
    Users must be aware of the problems and the implementation:
    Currently BigDec(x) for float x doesn't try to convert the
    exact value of x (than can be achieved with BigDec(0.1,:exact)
    but tries instead to produce a simple value  --which defines x--
    The problem arise by the mismatch of the radices of Float and
    BigDecimal (for Float is normally 2)  
    take for example BigDec(0.1)
    the implementaion of BigDec produces 0.1E0
    this means that the number 0.10000000000000001 cannot 
    be defined by BigDec(x) with any Float becaose it is parsed
    to the same Float as x. The only way to define it is 
    BigDec('0.10000000000000001')


=Documentation

See the Nio::Fmt for the formatting API; see also lib/nio/sugar.rb for some shortcuts.
The classes Nio::Tolerance and Nio::BigTolerance handle floating point tolerances;
they can be defined with Nio.Tol() and Nio.BigTol() too.
The functions BigDec() is a shortcut to define/convert BigDecimals.

=Examples of use
  require 'nio'
  require 'nio/sugar'
  include Nio
  x = Math.sqrt(2.0)
  x.nio_write => ...
  x.nio_write(Fmt.prec(20))
  ...etc see :sci, :fix, :gen, width options, base opticos, etc et.


=Exact and aproximate values
 
Float and BigDecimal are approximate in the sense that 
a given value within the range of this types, (defined either 
by an expression or as result of a computation) may no be
exactly represented and has to be substituted by the closest possible value.
With Float, which generally is a binary floating point, there's an
additional mismatch with the notation (decimal) used for input and 
output.

For the following examples we assume that Float is an IEEE754 Double precision
binary type (i.e. Float::RADIX==2 && Float::MANT_DIG==53) which is the 
common case (in all Ruby platforms I know of, at least).

  0.1.nio_write(Fmt.prec(:exact)) -> 0.1

well, that seems pretty clear... but let's complicate things a little:
  
  0.1.nio_write(Fmt.prec(:exact).show_all_digits(true)) -> 0.10000000000000001

Mmmm where does that last one came from? Now we're seem a little more exactly what
the actual value stored in the Float (the closest Float to 0.1) looks like.
Why didn't see the second one in the
first try? We requested "exact" precision! We didn't get it because it is not needed
to specify exactly the inner value of Float(1.0); when whe convert 0.1 and round it to
the nearest Float we get the same value than when we use 0.10000000000000001. 
since we didn't request to see "all digits", we got as few as possible.

  0.1.nio_write(Fmt.prec(:exact).approx_mode(:exact)) -> 0.1000000000000000055511151231257827021181583404541015625

Hey! Where did all that stuff came from? Now we're really seeing the "exact" value of Float. (We told the conversion
to consider the Float an exactly defined value, rather than an approximation to some other value).
But, why didn't we get all those digits when we asked for "all digits". Because most are not significative;
the default "approx_mode" is to consider Float an approximate value and show only significative digits.
We define unsignificative digits as those that can be replace by any other digit without altering the Float
value when the number is rounded to the nearest float. By looking at our example we see that the 17 first digits
(just before the 555111...) must be significative: they cannot take an arbitrary value without altering the Float.
In fact all have well specified values except the last one that can be either 0 or 1 (but no other value). The next
digits (first unsignificative, a 5) can be replaced by any other digit d (from 0 to 9) and the expression
0.10000000000000000d would still be rounded to Float(0.1)


=Repeating Numerals

The common term is "repeating decimals" or "recurring decimal", but since Nio support them for any base, we'll
call then repeating numerals.

  Rational(1,3).nio_write -> 0.333...
 
We usually see that way of writing the decimal expansion of 1/3, but that doesn't seem very accurate for
a conversion library, or is it?

  Rational.nio_read('0.333...') -> Rational(1,3)

It work the other way! In fact the seemingly loose 0.333... was an exact representation for Nio.

All Rational numbers can be expressed as a repeating numeral in any base. Repeating numerals may have an infinite
number of digits, but from some point on they're just repetitions of the same (finite) sequence of digits.

By default Nio expresses that kind repetition by showing repeating three times the repeating sequence and adding
an ellipsis (three points, rather). This allow Nio to recognize the repeating sequence on input.
We can use a more economical notation by just marking the repeating sequence, rather thar repeating it and adding
a suffix:
  Rational(1,3).nio_write(Fmt.new.rep(:rep=>0)) -> 0.<3>
We just requested for 0 as the number of repetitions (the default is 2) and got the sequence delimited by <> 
(we can change those characters; even use just a left separator). This is shorter and would allow to show the
number better with special typography (e.g. a bar over the repeated digits, a different color, etc.)






    