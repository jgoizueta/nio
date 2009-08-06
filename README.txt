=Description

Nio (Numeric input/output) is a Ruby package for text-formatted input/output
and conversion of scalar numeric types.

This library formats numbers as text numerals and reads them back into numeric
objects. The numeric types Integer Rational, BigDecimal and Float are supported.
The numeral format is controlled with Nio::Fmt objects. Conversion between
the numerical types is also provided.

Nio offers low level services; formats supported are only positional notation and
types are only scalar.
This means that composite types such as Complex are not supported
an that fraction notation (X/Y) is not supported for rationals;
those are higher level services that could be implemented using Nio
but are not the subject of this package.

The implementation of Nio is pure Ruby, and not specially fast; but it is complete and accurate.

Nio has some interesting features, though:

* Correctly rounded conversions of all supported types to and from
  positional numerals in any base.
* Handling of digit repetitions (repeating decimals or, in general, <i>repeating numerals</i>).
  With this method rational numbers can be represented exactly as numerals.
* Discrimitation of significant digits of the representation of Float in any base.
  (insignificant digits are those that can take any value without altering the Float value they specify.)

All definitions are inside the module Nio that acts as a namespace, and methods added
to classes outside of Nio have names that begin with the prefix <tt>nio_</tt>.

Limitations:
*  The current version does not support UTF-8 or other multi-byte encodings (digits and separators must be one-byte characters).
*  This code is not very fast, since it is implemented in pure Ruby (no C extensions are used).
*  Error handling needs to improve also in future versions, specially on input and format parameters checking.

=Installation

The easiest way to install Nio is using gems:

  gem install --remote nio

==Downloads

The latest version of Nio and its source code can be downloaded form
* http://rubyforge.org/project/showfiles.php?group_id=4445

The source code uses nuweb (a {<i>literate programming system</i>}[http://en.wikipedia.org/wiki/Literate_programming]) to generate
the Ruby code for Nio. For more details you can download the nuweb source code package, <tt>nio-source</tt>
and the documented source package, <tt>nio-source-pdf</tt>, which contains PDF files.


=Documentation

For a general introduction and some details, read on below.

* See the the API to the Nio::Fmt object for all the <b>formatting options</b>.
* For <b>type conversions</b> see Fmt.convert().
* For some notational <b>shortcuts</b> see nio/sugar.rb[link:files/lib/nio/sugar_rb.html].
* To *extend* the formatting to other types see the documentation for the module Nio::Formattable.

=Basic use

First we must require the library; we request also the optional nio/sugar.rb for convenient notational shortcuts,
and include the module Nio to avoid writing too many Nio::s.

  require 'rubygems'
  require 'nio'
  require 'nio/sugar'
  include Nio

Let's define a nice number to do some tests:

  x = Math.sqrt(2)+100

=== Writing

Now let's try the formatted output:

  puts x.nio_write                                          -> 101.41421356237309
  puts x.nio_write(Fmt.mode(:fix,4))                        -> 101.4142
  puts x.nio_write(Fmt.mode(:sig,4))                        -> 101.4
  puts x.nio_write(Fmt.mode(:sci,4))                        -> 1.014E2
  puts x.nio_write(Fmt.mode(:gen,4))                        -> 101.4
  puts (1e7*x).nio_write(Fmt.mode(:gen,4))                  -> 1.014E9
  puts (1e7*x).nio_write(Fmt.mode(:gen,4).show_plus)        -> +1.014E9
  puts x.nio_write(Fmt.mode(:gen,:exact))                   -> 101.41421356237309

We've seen some formatting modes:
* <tt>:fix</tt> (similar to F in C printf or in Fortran) which shows a number of
  _fixed_ decimals (4 in the example).
* <tt>:sig</tt> is just like :fix, but the number of decimals specified means
  significant digits.
* <tt>:sci</tt> (similar to E in C printf or in Fortran) is for scientific
  or exponential notation.
* <tt>:gen</tt> (similar to G in C printf or in Fortran) is the general notational
  (which also the default), the number of decimals is for significant digits, and
  :sig is used if possible; if it would be too long it uses :sci instead.
In one example above we used <tt>show_plus</tt> to force the display of the sign.
And in the last line we used <tt>:exact</tt> for the number of digits, (which
is also the default), and this adjust automatically the number of digits to
show the value _exactly_, meaning that if we convert the numeral back to a
numeric object of the original type, the same exact value will be produced.

Now let's see some other formatting aspects. The separators can be defined:

  x *= 1111
  fmt = Fmt.mode(:fix,4)
  puts x.nio_write(fmt.sep(','))                            -> 112671,1913
  puts x.nio_write(fmt.sep(',','.',[3]))                    -> 112.671,1913
  puts x.nio_write(fmt.sep(',',' ',[2,3]))                  -> 1 126 71,1913

The number can be adjusted in a field of specific width:

fmt = Fmt.mode(:fix,2)
  puts 11.2.nio_write(fmt.width(8))                         ->    11.20
  puts 11.2.nio_write(fmt.width(8,:right,'*'))              -> ***11.20
  puts 11.2.nio_write(fmt.width(8,:right,'*').show_plus)    -> **+11.20
  puts 11.2.nio_write(fmt.width(8,:internal,'*').show_plus) -> +**11.20
  puts 11.2.nio_write(fmt.width(8,:left,'*'))               -> 11.20***
  puts 11.2.nio_write(fmt.width(8,:center,'*'))             -> *11.20**
  puts 11.2.nio_write(fmt.pad0s(8))                         -> 00011.20
  puts Rational(112,10).nio_write(fmt.pad0s(8))             -> 00011.20
  puts 112.nio_write(fmt.pad0s(8))                          -> 00112.00

The numerical base does not need to be 10:

  puts 34222223344.nio_write(fmt.base(16))                  -> 7f7cdaff0.00
  puts x.nio_write(Fmt.base(16))                            -> 1b81f.30F6ED22C
  puts x.nio_write(Fmt.mode(:fix,4).base(2))                -> 11011100000011111.0011
  puts 1.234333E-23.nio_write(Fmt.base(2).prec(20))         -> 1.1101110110000010011E-77

The sugar module give us some alternatives for the writing notation:

  puts Fmt << x                                             -> 112671.1912677965
  puts Fmt.mode(:fix,4) << x                                -> 112671.1913

  puts Fmt.write(x)                                         -> 112671.1912677965
  puts Fmt.mode(:fix,4).write(4)                            -> 4.0000

===Reading

To read a numeral we must specify the numeric class we want to convert it to:

  puts Float.nio_read('0.1')                                -> 0.1
  puts BigDecimal.nio_read('0.1')                           -> 0.1E0
  puts Rational.nio_read('0.1')                             -> 1/10
  puts Integer.nio_read('0.1')                              -> 0

A format can also be specified, although some aspects (such as the precision)
will be ignored.

  puts Float.nio_read('0,1',Fmt.sep(','))                   -> 0.1
  puts Float.nio_read('122.344,1',Fmt.sep(','))             -> 122344.1
  puts Float.nio_read('122,344.1',Fmt.sep('.'))             -> 122344.1

There are also some sweet alternatives for reading:

  puts Fmt.read(Float,'0.1')                                -> 0.1
  puts Fmt.sep(',').read(Float,'0,1')                       -> 0.1

  puts Fmt >> [Float, '0.1']                                -> 0.1
  puts Fmt.sep(',') >> [Float, '0,1']                       -> 0.1

===Floating point

Now let's see something trickier; we will use the floating point result
of dividing 2 by 3 and will use a format with 20 fixed digits:

  x = 2.0/3
  fmt = Fmt.mode(:fix,20)

  puts x.nio_write(fmt)                                     -> 0.66666666666666663

If you count the digits you will find only 17. Where are the other 3?

Here we're dealing with an approximate numerical type, Float, that has a limited
internal precision and we asked for a higher precision on the output, which we
didn't get. Nio refuses to show non-significant digits.

We can use a placeholder for the digits so that Nio shows us something rather than
just ignoring the digits:

  puts x.nio_write(fmt.insignificant_digits('#'))           -> 0.66666666666666663###

Nio is hiding those digits because it assumes that the Float value is an approximation,
but we can force it to actually compute the mathematical _exact_ value of the Float:

  puts x.nio_write(fmt.approx_mode(:exact))                 -> 0.66666666666666662966

===Default format

The default format Fmt.default is used when no format is specified;
it can be changed by assigning to it:

  Fmt.default = Fmt.default.sep(',')
  puts 1.23456.nio_write              -> 1,23456
  puts 1.23456.nio_write(Fmt.prec(3)) -> 1,23

But note that Fmt.new doesn't use the current default (it's
the hard-wired value at which Fmt.default starts):

  puts 1.23456.nio_write(Fmt.new.prec(3)) -> 1.23

There are also other named prefined formats:

  puts 123456.78.nio_write(Fmt[:dot]) -> 123456.78
  puts 123456.78.nio_write(Fmt[:dot_th]) -> 123,456.78
  puts 123456.78.nio_write(Fmt[:comma]) -> 123456,78
  puts 123456.78.nio_write(Fmt[:code]) -> 123456,78

The <tt>_th</tt> indicates that thousands separators are used;
the :code format is intended for programming languages such as Ruby, C, SQL, etc.
These formats can be changed by assigning to them, and also other named formats
can be defined:

  Fmt[:code] = Fmt.new.prec(1)
  puts 123456.78.nio_write(Fmt[:code]) -> 123456.8
  Fmt[:locale_money] = Fmt.sep(',','.',[3]).prec(:fix,2)
  puts 123456.78.nio_write(Fmt[:locale_money]) -> 123.456,78

===Conversions

Nio can also convert values between numerical types, e.g. from Float to Rational:

  puts Nio.convert(2.0/3, Rational)                     -> 2/3
  puts Nio.convert(2.0/3, Rational, :exact)             -> 6004799503160661/9007199254740992

The default (approximate) conversions assumes that the value is inexact and tries to find
a nice simple value near it. When we request <tt>:exact</tt> conversion the actual internal value
of the floating point number is preserved.

Let's see some more examples:

  puts Nio.convert(2.0/3, BigDecimal)                   -> 0.666666666666666666666667E0
  puts Nio.convert(2.0/3, BigDecimal, :exact)           -> 0.66666666666666662965923251249478198587894439697265625E0
  puts Nio.convert(Rational(2,3), Float)                -> 0.666666666666667
  puts Nio.convert(Rational(2,3), BigDecimal)           -> 0.666666666666666666666667E0
  puts Nio.convert(BigDecimal('2')/3, Rational)         -> 2/3
  puts Nio.convert(BigDecimal('2')/3, Rational, :exact) -> 666666666666666666666667/1000000000000000000000000
  puts Nio.convert(2.0/3, BigDecimal)                   -> 0.666666666666666666666667E0
  puts Nio.convert(2.0/3, BigDecimal, :exact)           -> 0.66666666666666662965923251249478198587894439697265625E0
  puts Nio.convert(BigDecimal('2')/3, Float)            -> 0.666666666666667
  puts Nio.convert(BigDecimal('2')/3, Float, :exact)    -> 0.666666666666667



=Details

===Defining formats

Say you want a numeric format based on the current default but with some aspects
changed, e.g. using comma as the decimal separator and with only 3 digits
of precision, we could do:

  fmt = Fmt.default
  fmt = fmt.sep(',')
  fmt = fmt.prec(3)

That wasn't very nice. Fmt is a mutable class and have methods to modify
its state that end with a bang. We can use them to make this look better,
but note that we must create a copy of the default format before we
modify it:

  fmt = Fmt.default.dup
  fmt.sep! ','
  fmt.prec! 3

Note that we had to make a duplicate of the default format in
order to modify it or we would have got an error
(if you want to modify the default format
you have to assign to it).

Now we can simplify this a little by passing a block to Fmt.default:

  fmt = Fmt.default { |f|
    f.sep! ','
    f.prec! 3
  }

But there's a more concise way to define the format by avoiding
the bang-methods and chaining all modifications:

  fmt = Fmt.default.sep(',').prec(3)

Or even (using shortcut methods such as Fmt.sep or Fmt.prec):

  fmt = Fmt.sep(',').prec(3)

If we don't want to base the new format on the current default, but use
the initial default instead, we would substitute new for default above,
except in the last case which always uses the default.
For example:

  fmt = Fmt.new { |f|
    f.sep! ','
    f.prec! 3
  }

  fmt = Fmt.new.sep(',').prec(3)

If a particular case needs a format similar to fmt but with some modification
we would use, for example:

  puts 0.1234567.nio_write(fmt.prec(5))  -> 0.12346
  puts 0.1234567.nio_write(fmt)              -> 0.123

We can use the constructor Fmt() instead of Fmt.default, and pass options to it:

  fmt = Fmt(:ndig=>3, :dec_sep=>',')
  fmt = Fmt(:ndig=>3) { |f|  f.sep! ',' }

And the [] operator can be used not only to access predefined formats, but also to
set individual properties easily, either applied to Fmt or to a format object:

  fmt = Fmt[:dec_sep=>','].prec(3)[:all_digits=>true]

Note that Fmt[...] is simply equivalent to Fmt(...).

===Exact and aproximate values

Float and BigDecimal are approximate in the sense that
a given value within the range of these types, (defined either
by an expression or as result of a computation) may no be
exactly represented and has to be substituted by the closest possible value.
With Float, which generally is a binary floating point, there's an
additional mismatch with the notation (decimal) used for input and
output.

For the following examples we assume that Float is an IEEE754 double precision
binary type (i.e. <tt>Float::RADIX==2 && Float::MANT_DIG==53</tt>) which is the
common case (in all Ruby platforms I know of, at least).

  0.1.nio_write(Fmt.prec(:exact)) -> 0.1

Well, that seems pretty clear... but let's complicate things a little:

  0.1.nio_write(Fmt.prec(:exact).show_all_digits) -> 0.10000000000000001

Mmmm where does that last one came from? Now we're seen a little more exactly what
the actual value stored in the Float (the closest Float to 0.1) looks like.

But why didn't we see the second one-digit in the first try?
We requested "exact" precision!

Well, we didn't get it because it is not needed to specify exactly the inner value
of Float(1.0); when we convert 0.1 and round it to the nearest Float we get the
same value as when we use 0.10000000000000001.
Since we didn't request to see "all digits", we got only as few as possible.

  0.1.nio_write(Fmt.prec(:exact).approx_mode(:exact)) -> 0.1000000000000000055511151231257827021181583404541015625

Hey! Where did all that stuff came from? Now we're really seeing the "exact" value of Float.
(We asked the conversion method to consider the Float an exactly defined value,
rather than an approximation to some other value).
But, why didn't we get all those digits when we asked for "all digits"?.

Because most are not significant;
the default "approx_mode" is to consider Float an approximate value and show only significant digits.
We define insignificant digits as those that can be replaced by any other digit without altering the Float
value when the number is rounded to the nearest float. By looking at our example we see that the 17 first digits
(just before the 555111...) must be significant: they cannot take an arbitrary value without altering the Float.
In fact all have well specified values except the last one that can be either 0 or 1 (but no other value). The next
digits (first insignificant, a 5) can be replaced by any other digit * (from 0 to 9) and the expression
0.10000000000000000* would still be rounded to Float(0.1)


===Insignificance

So, let's summarize the situation about inexact numbers: When the approximate mode of a format is <tt>:only_sig</tt>,
the digits of inexact (i.e. floating point) numbers are classified as significant or insignificant.
The latter are only shown if the property <tt>:all_digits</tt> is true
(which it is by default for <tt>:fix</tt>)
but since they are not meaningful they use a special character that by default is empty. You can
define that character to see where they are:
  puts 0.1.nio_write(Fmt.mode(:fix,20).insignificant_digits('#'))   -> 0.10000000000000001###

If we hadn't use the special character we would'nt even seen those digits:

  puts 0.1.nio_write(Fmt.mode(:fix,20))                             -> 0.10000000000000001

When the aproximate mode is defined as :exact, there's no distinction between significant or insignificant
digits, the number is taken as exactly defined and all digits are shown with their value.

  puts 0.1.nio_write(Fmt.mode(:fix,20,:approx_mode=>:exact)         -> 0.10000000000000000555

===Repeating Numerals

The common term is <b>repeating decimal</b> or <b>recurring decimal</b>, but since Nio support them for any base,
we'll call them <i>repeating numerals</i>.

  Rational(1,3).nio_write -> 0.333...

We usually find that notation for the decimal expansion of 1/3 in texts, but that doesn't seem very accurate for
a conversion library, or is it?

  Rational.nio_read('0.333...') -> Rational(1,3)

It works the other way! In fact the seemingly loose 0.333... was an exact representation for Nio.

All Rational numbers can be expressed as a repeating numeral in any base. Repeating numerals may have an infinite
number of digits, but from some point on they're just repetitions of the same (finite) sequence of digits.

By default Nio expresses that kind of repetition by appending two repetitions of the repeating sequence
after it and adding the ellipsis (so the repeated sequence appears three times, and, by the way Nio
uses three points rather than a real ellipsis characters).
This allow Nio to recognize the repeating sequence on input.
We can use a more economical notation by just marking the repeating sequence, rather than repeating it:
  Rational(1,3).nio_write(Fmt.rep(:nreps=>0)) -> 0.<3>
We just requested for 0 as the number of repetitions (the default is 2) and got the sequence delimited by <>
(we can change those characters; we can even use just a left separator).
This is shorter and would allow to show the number better with special typography
(e.g. a bar over the repeated digits, a different color, etc.)

===Rounding

Rounding is performed on both input and output.
When a value is formatted for output the number is rounded to the number of digits
that has been specified.

But also when a value must be read from text rounding it is necessary to choose the nearest
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
on the Ruby code (such as 0.1 or 1E23) they are parsed and converted to Floating point values
by the Ruby interpreter which must apply some kind of rounding when the expression to be parsed
is equidistant from two Float values.
All the Ruby implementations I have tried have IEEE754 Double Float
(<tt>Float::RADIX==2 && Float::MANT_DIG==53</tt>)
and floating point literals seem to be rounded according to the round-to-even rule, so that
is the initial default rounding mode.

====Examples

We assume the common implementation of float (<tt>Float::RADIX==2 && Float::MANT_DIG==53</tt>) here.
In that case, we can use the value 1E23, which is equidistant from two Floats
to check which kind of roundig does the interpreter use.
If it's round-to-even (the common case) we'll have:
  1E23 == Float.nio_read('1E23',Nio::Fmt.mode(:gen,:exact,:round=>:even) --> true
  1E23 == Float.nio_read('1E23',Nio::Fmt.mode(:gen,:exact,:round=>:zero) --> true
But if rounding is to infinity the previous check will be false and this will hold:
  1E23 == Float.nio_read('1E23',Nio::Fmt.mode(:gen,:exact,:round=>:inf) --> true
(Well, with this example we can't really distinguish :even from :zero, but :zero is most probably not used)

Now, if we're using the same default rounding for Nio we will have:
  1E23.nio_write == "1E23" --> true
Which will make you feel warm and fuzzy. But if the system rounding is different
we will get one of these ugly values:
   fmt_inf = Nio::Fmt.mode(:gen,:exact,:round=>:inf)
   fmt_even = Nio::Fmt.mode(:gen,:exact,:round=>:even)
   Float.nio_read('1E23',fmt_inf).nio_write(fmt_even) -> "1.0000000000000001E23"
   Float.nio_read('1E23',fmt_even).nio_write(fmt_inf) -> "9.999999999999999E22"

If the Ruby interpreter doesn't support any of the roundings of Nio, or if it doesn't correctly
round, the best solution would be to avoid using Float literals and use Float#nio_read instead.

===Conversions

Accurate conversion between numerical types can be performed with Nio.convert.
It takes three arguments: the value to convert, the class to convert it to (Float, BigDecimal,
Flt::Num, Integer or Rational) and the conversion mode, either :exact, which is..., well, quite exact,
and :approx which tries to find a simpler value (e.g. 0.1 rather than 0.10000000000000001...)
within the accuray of the original value.
The :approx mode may be pretty slow in some cases.

   Nio.convert(0.1,BigDecimal,:exact)    -> 0.1000000000 0000000555 1115123125 ...
   Nio.convert(0.1,BigDecimal,:approx)   -> 0.1

We can check out the accuracy of the conversions:

    Nio.convert(BigDecimal('1.234567890123456'),Float)==1.234567890123456   -> true
    Nio.convert(BigDecimal('355')/226,Float)==(355.0/226)                   -> true

Thay may not look very impressive, but is much more accurate than BigDecimal#to_f
(at least in Ruby versions up to 1.8.6, mswin32 (specially) and linux) for which:

     BigDecimal('1.234567890123456').to_f == 1.234567890123456  -> false
     (BigDecimal('355')/226).to_f == (355.0/226.0)              -> false

=License

This code is free to use under the terms of the GNU GENERAL PUBLIC LICENSE.

=Contact

Nio has been developed by Javier Goizueta (mailto:javier@goizueta.info).

You can contact me through Rubyforge:http://rubyforge.org/sendmessage.php?touser=25432


=More Information

* <b>What Every Computer Scientist Should Know About Floating-Point Arithmetic</b>
  David Goldberg
  - http://docs.sun.com/source/806-3568/ncg_goldberg.html

* <b>How to Read Floating Point Numbers Accurately</b>
  William D. Clinger
  - http://citeseer.ist.psu.edu/224562.html

* <b>Printing Floating-Point Numbers Quickly and Accurately</b>
  Robert G. Burger & R. Kent Dybvig
  - http://www.cs.indiana.edu/~burger/FP-Printing-PLDI96.pdf

* <b>Repeating Decimal</b>
  - http://mathworld.wolfram.com/RepeatingDecimal.html
  - http://en.wikipedia.org/wiki/Recurring_decimal

* For <b>floating point rationalization algorithms</b>, see my commented
  source code for the  <tt>rntlzr</tt> module from Nio,
  which you can download in PDF here:
  - http://perso.wanadoo.es/jgoizueta/dev/goi/rtnlzr.pdf
