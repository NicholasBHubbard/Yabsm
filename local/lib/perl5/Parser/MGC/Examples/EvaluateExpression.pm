package Parser::MGC::Examples::EvaluateExpression;

=head1 NAME

C<Parser::MGC::Examples::EvaluateExpression> - an example parser to evaluate simple numerical expressions

=head1 DESCRIPTION

This evaluator-parser takes simple mathematical expressions involving the four
basic arithmetic operators (+, -, *, /) applied to integers, and returns the
numerical result. It handles operator precedence, with * and / having a higher
level than + and -, and copes with parentheses.

Operator precedence is implemented by using two different parsing functions to
handle the two different precedence levels.

=cut

=head2 Boilerplate

We start off by declaring a package and subclassing L<Parser::MGC>.

   package ExprParser;
   use base qw( Parser::MGC );

   use strict;
   use warnings;

=head2 parse

The topmost parsing function, C<parse>, handles the outermost level of
operator precedence, the + and - operators. It first parses a single term from
the input by callling C<parse_term> to obtain its value.

It then uses the C<any_of> structure-forming method to look for either a + or -
operator which would indicate another term will follow it. If it finds either
of these, it parses the next term from after the operator by another call to
C<parse_term> and then adds or subtracts the value of it from the running
total.

The C<any_of> call itself is used as the conditional expression of a C<while>
loop, to ensure it gets called multiple times. Whenever another term has been
parsed, the body function returns a true value, to indicate that the while
loop should be invoked again. Only when there are no more + or - operators,
indicating no more terms, does the body return false, causing the while loop
to stop.

This continues until there are no more + or - operators, when the overall
total value is returned to the caller.

=cut

=pod

   sub parse
   {
      my $self = shift;

      my $val = $self->parse_term

      1 while $self->any_of(
         sub { $self->expect( "+" ); $val += $self->parse_term; 1 },
         sub { $self->expect( "-" ); $val -= $self->parse_term; 1 },
         sub { 0 },
      );

      return $val;
   }

=cut

=pod

This function recognises input matching the following EBNF grammar:

   EXPR = TERM { ( '+' | '-' ) TERM };

=cut

=head2 parse_term

Called by C<parse>, the next function is C<parse_term> which has a similar
structure. This function implements the next level of operator precedence, of
the * and / operators. In a similar fashion to the previous function, this one
parses a single factor from the input by calling C<parse_factor>, and then
looks for * or / operators, multiplying or dividing the value by the next
factor it expects to find after those. This continues until there are no more
* or / operators, when the overall product is returned.

=cut

=pod

   sub parse_term
   {
      my $self = shift;

      my $val = $self->parse_factor;

      1 while $self->any_of(
         sub { $self->expect( "*" ); $val *= $self->parse_factor; 1 },
         sub { $self->expect( "/" ); $val /= $self->parse_factor; 1 },
         sub { 0 },
      );

      return $val;
   }

=cut

=pod

This function recognises input matching the following EBNF grammar:

   TERM = FACTOR { ( '*' | '/' ) FACTOR };

=cut

=head2 parse_factor

Finally, the innermost C<parse_factor> function is called by C<parse_term> to
parse out the actual numerical values. This is also the point at which the
grammar can recurse, recognising a parenthesized expression. It uses an
C<any_of> with two alternative function bodies, to cover these two cases.

The first case, to handle a parenthesized sub-expression, consists of a call
to C<scope_of>. This call would expect to find a C<(> symbol to indicate the
parenthesized expression. If it finds one, it will recurse back to the
toplevel C<parse> method to obtain its value, then expects the final C<)>
symbol. The value of this factor is then the value of the sub-expression
contained within the parentheses.

If the first case fails, because it does not find that leading C<(> symbol,
the second case is attempted instead. This handles an actual integer constant.
This case is simply a call to the C<token_int> method of the underlying class,
which recognises various string forms of integer constants, returning their
numerical value.

=cut

=pod

   sub parse_factor
   {
      my $self = shift;

      $self->any_of(
         sub { $self->scope_of( "(", sub { $self->parse }, ")" ) },
         sub { $self->token_int },
      );
   }

=cut

=pod

This function recognises input matching the following EBNF grammar:

   FACTOR = '(' EXPR ')'
          | integer

=cut

=head1 EXAMPLES OF OPERATION

=head2 A single integer

The simplest form of operation of this parser is when it is given a single
integer value as its input; for example C<"15">.

 INPUT:    15
 POSITION: ^

The outermost call to C<parse> will call C<parse_term>, which in turn calls
C<parse_factor>.

 INPUT:    15
 POSITION  ^
 CALLS:    parse
            => parse_term
             => parse_factor

The C<any_of> inside C<parse_factor> will first attempt to find a
parenthesized sub-expression by using C<scope_of>, but this will fail because
it does not start with an open parenthesis symbol. The C<any_of> will then
attempt the second case, calling C<token_int> which will succeed at obtaining
an integer value from the input stream, consuming it by advancing the stream
position. The value of 15 is then returned by C<parse_factor> back to
C<parse_term> where it is stored in the C<$val> lexical.

 INPUT:    15
 POSITION:   ^
 CALLS:    parse
            => parse_term -- $val = 15

At this point, the C<any_of> inside C<parse_term> will attempt to find a * or
/ operator, but both will fail because there is none, causing the final
alternative function to be invoked, which stops the C<while> loop executing.
The value of 15 is then returned to the outer caller, C<parse>. A similar
process happens there, where it fails to find a + or - operator, and thus the
final value of 15 is returned as the result of the entire parsing operation.

 INPUT:    15
 OUTPUT:   15

=head2 A simple sum of two integers

Next lets consider a case that actually requires some real parsing, such as an
expression requesting the sum of two values; C<"6 + 9">.

 INPUT:    6 + 9
 POSITION: ^

This parsing operation starts the same as the previous; with C<parse> calling
C<parse_term> which in turn calls C<parse_factor>.

 INPUT:    6 + 9
 POSITION: ^
 CALLS:    parse
            => parse_term
             => parse_factor

As before, the C<any_of> inside C<parse_factor> first attempts and fails to
find a parenthesized sub-expression and so tries C<token_int> instead. As
before this obtains an integer value from the stream and advances the
position. This value is again returned to C<parse_term>. As before, the
C<any_of> attempts but fails to find a * or / operator so the value gets
returned to C<parse> to be stored in C<$val>.

 INPUT:    6 + 9
 POSITION:  ^
 CALLS:    parse -- $val = 6

This time, the C<any_of> in the outer C<parse> method attempts to find a +
operator and succeeds, because there is one at the next position in the
stream. This causes the first case to continue, making another call to
C<parse_term>.

 INPUT:    6 + 9
 POSITION:    ^
 CALLS:    parse -- $val = 6
            => parse_term

This call to C<parse_term> proceeds much like the first, eventually returning
the value 9 by consuming it from the input stream. This value is added to
C<$val> by the code inside the C<any_of> call.

 INPUT:    6 + 9
 POSITION:      ^
 CALLS:    parse -- $val = 15

C<parse> then calls C<any_of> a second time, which attempts to find another
operator. This time there is none, so it returns false, which stops the
C<while> loop and the value is returned as the final result of the operation.

 INPUT:    6 + 9
 OUTPUT:   15

=head2 Operator precedence

The two kinds of operators (+ and - vs * and /) are split across two different
method calls to allow them to implement precedence; to say that some of the
operators bind more tightly than others. Those operators that are implemented
in more inwardly-nested functions bind tighter than the ones implemented
further out.

To see this in operation consider an expression that mixes the two kinds of
operators, such as C<"15 - 2 * 3">

 INPUT:    15 - 2 * 3
 POSITION: ^

The parsing operation starts by calling down from C<parse> all the way to
C<token_int> which extracts the first integer, 15, from the stream and returns
it all the way up to C<parse> as before:

 INPUT:    15 - 2 * 3
 POSITION:   ^
 CALLS:    parse -- $val = 15

As before, the C<parse> function looks for a * or - operator by its C<any_of>
test, and finds this time the - operator, which then causes it to call
C<parse_term> to parse its value:

 INPUT:    15 - 2 * 3
 POSITION:     ^
 CALLS:    parse -- $val = 15
            => parse_term

Again, C<parse_term> starts by calling C<parse_factor> which extracts the next
integer from the stream and returns it. C<parse_factor> temporarily stores
that in its own C<$val> lexical (which remember, is a lexical variable local
to that call, so is distinct from the one in C<parse>).

 INPUT:    15 - 2 * 3
 POSITION:       ^
 CALLS:    parse -- $val = 15
            => parse_term -- $val = 2

This time, when C<parse_term> attempts its own C<any_of> test to look for a *
or / operator, it manages to find one. By a process similar to the way that
the outer C<parse> method forms a sum of terms, C<parse_term> forms a product
of factors by calling down to C<parse_factor> and accumulating the result.
Here it will call C<parse_factor> again, which returns the value 3. This gets
multiplied into C<$var>.

 INPUT:    15 - 2 * 3
 POSITION:           ^
 CALLS:    parse -- $val = 15
            => parse_term -- $val = 6

C<parse_term> will try again to look for a * or / operator, but this time
fails to find one, and so returns its final result, 6, back to C<parse>, which
then subtracts it from its own C<$val>.

 INPUT:    15 - 2 * 3
 POSITION:           ^
 CALLS:    parse -- $val = 9

The outer C<parse> call similarly fails to find any more + or - operators and
so returns the final result of the parsing operation.

 INPUT:    15 - 2 * 3
 OUTPUT:   9

By implementing the * and / operators separately in a different piece of logic
inside the one that implements the + and - operators, we have ensured that
they operate more greedily. That is, that they bind tighter, consuming their
values first, before the outer + and - operators. This is the way that
operator precedence is implemented.

=head2 Parentheses

This grammar, like many others, provides a way for expressions to override the
usual operator precedence by supplying a sub-expression in parentheses. The
expression inside those parentheses is parsed in the usual way, and then its
result stands in place of the entire parenthesized part, overriding whatever
rules might have governed the order between those operators inside it and
those outside.

In this parser we implement this as a recursive call, where one possibility
of the innermost part (the C<parse_factor> function or the C<FACTOR> EBNF
rule) is to recurse back to the outermost thing, inside parentheses. This
example examines what happens to the input string C<"(15 - 2) * 3">.

 INPUT:    (15 - 2) * 3
 POSITION: ^

As with all the other examples the parsing operation starts by C<parse>
calling C<parse_term> which calls C<parse_factor>. This time, the first case
within the C<any_of> in C<parse_factor> does successfully manage to find an
open parenthesis, so consumes it. It then stores the close parenthesis pattern
as the end-of-scope marker, and makes a recursive call back to the parse
method again.

 INPUT:    (15 - 2) * 3
 POSITION:  ^
 CALLS:    parse
            => parse_term
             => parse_factor
              => parse                 EOS = ")"

The operation of the inner call to C<parse> proceeds much like the first few
examples, calling down through C<parse_term> to C<parse_factor> to obtain
the 15.

 INPUT:    (15 - 2) * 3
 POSITION:    ^
 CALLS:    parse
            => parse_term
             => parse_factor
              => parse -- $val = 15    EOS = ")"

Similar to previous examples, this then finds the - operator, and parses
another term to subtract from it.

 INPUT:    (15 - 2) * 3
 POSITION:        ^
 CALLS:    parse
            => parse_term
             => parse_factor
              => parse -- $val = 13    EOS = ")"

At this point, the C<any_of> test in the inner call to C<parse> tries again to
look for a + or - operator, and this time fails because it believes it is at
the end of the input. It isn't really at the end of the string, of course, but
it believes it to be at the end because of the "end-of-scope" pattern that the
call to C<scope_of> established. This pretends that the input has finished
whenever the next part of the input matches the end-of-scope pattern.

Because this inner call to C<parse> now believes it has got to the end of its
input, it returns its final answer back to the caller, which in this case was
the C<scope_of> call that C<parse_factor> made. As the C<scope_of> call
returns, it consumes the input matching the end-of-scope pattern. This return
value is then stored by C<parse_term>.

 INPUT:    (15 - 2) * 3
 POSITION:         ^
 CALLS:    parse
            => parse_term -- $val = 13

At this point, C<parse_term> proceeds as before, finding and extracting the *
operator and calling C<parse_factor> a second time, multiplying them together
and returning that to the outer C<parse> call.

 INPUT:    (15 - 2) * 3
 POSITION:             ^
 CALLS:    parse -- $val = 39

At this point C<parse> fails to extract any more operators because it is at
the (real) end of input, so returns the final answer.

 INPUT:    (15 - 2) * 3
 OUTPUT:   39
