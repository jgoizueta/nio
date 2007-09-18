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
*  UTF-8 or other multi-byte encodings are not supported (digits and separators must be one-byte characters)
*  This code is not very fast, since it is implemented in pure Ruby (no C extensions are used).

=Installation

The easiest way to install Nio is using gems:

  gem install --remote nio

==Downloads

The latest version of Nio and its source code can be downloaded form
* rubyforge.org/project/showfiles.php?group_id=XX

The source code uses nuweb (a {<i>literate programming system</i>}[http://en.wikipedia.org/wiki/Literate_programming]) to generate
the Ruby code for Nio.


=Documentation

For a general introduction and some details, read on below.

See the the API to the Nio::Fmt object for all the formatting options.

For some notational shortcuts see nio/sugar.rb[link:files/lib/nio/sugar_rb.html].

To extend the formatting to other types see the documentation for the
module Nio::Formattable.

If you want to use the floating point tolerance see
the classes Nio::Tolerance and Nio::BigTolerance, 
which can be defined with <tt>Nio::Tol()</tt> and <tt>Nio::BigTol()</tt> too
(described in the module Nio).

The functions BigDec() is a shortcut to define/convert BigDecimals, also
described in Nio.

=Examples of use
  require 'nio'
  require 'nio/sugar'
  include Nio
  x = Math.sqrt(2.0)
  x.nio_write => ...
  x.nio_write(Fmt.prec(20))
  ...etc see :sci, :fix, :gen, width options, base opticos, etc et.


=Details

==Exact and aproximate values
 
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


==Repeating Numerals

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


==BigDec()

BigDec() is a handy convenience to define BigDecimals; it allow for example
to use BigDec(1) instead of BigDecimal('1') (I find specially tedious to type all those quotes.)
It can also be used with Float arguments, e.g.:
  BigDec(0.5)
This is a questionable use (it has been disregarded in Python Decimal)
but is allowed here because BigDec's purpose is to be a shortcut notation
(BigDecimal() on the other hand should probably not accept Floats).

Users must be aware of the problems and details of the implementation.
Currently BigDec(x) for float x doesn't try to convert the exact value of x
which can be achieved with BigDec(0.1,:exact)  but tries instead to produce
a simple value  --which defines x--
[dilemma: leav BigDec as now (simplify) o change to use default fmt conversion
a) => BigDec(1.0/3) == BigDec(Rational(1)/3)
b) => BigDec(1.0/3) == BigDec("0.3333333333333333")
in a, can we assure that NFmt.convert(BigDec(x),Float)==x ?

Since a floating point literal will, in general, convert to a Float of slightly different value,
and several distinct lieterals can convert to the same value, there will always some compromise.
Here we've chosen to simplify values so that BigDec(0.1)==BigDecimal('0.1'),
but it means that, for example, BigDecimal('0.10000000000000001') cannot be defined with BigDec(),
because Float(0.10000000000000001)==Float(0.1).

In any case using BigDec on Floats have some risks because it relies on the Ruby interpreter
to parse floating point literal, and its behaviour is not stricly specified; in the usual case
(IEEE Double Floats and round-to-even) BigDec() will behave well, but some platforms may
behave differently.

==Rounding

Rounding is performed on both input and output.
When a value is formatted for output the number is rounded to the number of digits
that has been specified.

But also when a value must be read from text rounding is necessary to choose the nearest
numeric representation (e.g. Float value).


Nio supports three rounding modes which determine how to round _ties_:
[<tt>:inf</tt>]
    round to infinity
         1.5 ->  2
        -1.5 -> -2
[<tt>:even</tt>] round to even (to the nearest even digit)
         1.5 ->  2
         2.5 ->  2
        -1.5 -> -2
        -2.5 -> -2
[<tt>:zero</tt>] round to zero
         1.5 ->  1
        -1.5 -> -1 

Rounding can be set with Nio::Fmt#mode and Nio::Fmt#prec for specific formats, and
the default rounding mode can be changed with Fmt.default_rounding_mode().

For round-trip conversions, a number should use the same rounding mode on input and output.

For Floats there's an additional issue here, because when we use floating point literals
on the Ruby code (such as 0.1 or 1E23) they are parsed and converter to Floating point values
by the Ruby interpreter which must apply some kind of rounding when the expression to be parsed
is equidistant from two Float values. 
All the Ruby implementations I have tried have IEEE754 Double Float
(<tt>Float::RADIX==2 && Float::MANT_DIG==53</tt>)
and floating point literals seem to be rounded according to the round-to-even rule, so that
is the initial default rounding mode.

===Examples

We assume the common implementation of float (<tt>Float::RADIX==2 && Float::MANT_DIG==53</tt>) here.
In that case, we can use the value 1E23, which is equidistant form two Floats
to check which kind of roundig does the interpreter use.
If it's round-to-even (the common case) we'll have:
  1E23 == Float.nio_read('1E23',Nio::Fmt.mode(:gen,:exact,:even) --> true
  1E23 == Float.nio_read('1E23',Nio::Fmt.mode(:gen,:exact,:zero) --> true
But if rounding is to infinity the previous check will be false and this will hold:
  1E23 == Float.nio_read('1E23',Nio::Fmt.mode(:gen,:exact,:inf) --> true
(Well, with this example we can't really distinguish :even from :zero, but :zero is most probably not used)

Now, if we're using the same default rounding for Nio we will have:
  1E23.nio_write == "1E23" --> true
Which will make you feel warm an fuzzy. But if the system rounding is different 
we will get one of these ugly values:
   fmt_inf = Nio::Fmt.mode(:gen,:exact,:inf)
   fmt_even = Nio::Fmt.mode(:gen,:exact,:even)
   Float.nio_read('1E23',fmt_inf).nio_write(fmt_even) -> "1.0000000000000001E23"
   Float.nio_read('1E23',fmt_even).nio_write(fmt_inf) -> "9.999999999999999E22"

If the Ruby interpreter doesn't support any of the roundings of Nio, or if it doesn't correctly
round, the best solution would be to avoid using Float literals and use Float#nio_read instead.

    