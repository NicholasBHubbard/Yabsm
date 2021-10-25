#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2010-2021 -- leonerd@leonerd.org.uk

package Parser::MGC 0.19;

use v5.14;
use warnings;

use Carp;
use Feature::Compat::Try;

use File::Slurp::Tiny qw( read_file );
use Scalar::Util qw( blessed );

=head1 NAME

C<Parser::MGC> - build simple recursive-descent parsers

=head1 SYNOPSIS

   package My::Grammar::Parser;
   use base qw( Parser::MGC );

   sub parse
   {
      my $self = shift;

      $self->sequence_of( sub {
         $self->any_of(
            sub { $self->token_int },
            sub { $self->token_string },
            sub { \$self->token_ident },
            sub { $self->scope_of( "(", \&parse, ")" ) }
         );
      } );
   }

   my $parser = My::Grammar::Parser->new;

   my $tree = $parser->from_file( $ARGV[0] );

   ...

=head1 DESCRIPTION

This base class provides a low-level framework for building recursive-descent
parsers that consume a given input string from left to right, returning a
parse structure. It takes its name from the C<m//gc> regexps used to implement
the token parsing behaviour.

It provides a number of token-parsing methods, which each extract a
grammatical token from the string. It also provides wrapping methods that can
be used to build up a possibly-recursive grammar structure, by applying a
structure around other parts of parsing code.

=head2 Backtracking

Each method, both token and structural, atomically either consumes a prefix of
the string and returns its result, or fails and consumes nothing. This makes
it simple to implement grammars that require backtracking.

Several structure-forming methods have some form of "optional" behaviour; they
can optionally consume some amount of input or take some particular choice,
but if the code invoked inside that subsequently fails, the structure can
backtrack and take some different behaviour. This is usually what is required
when testing whether the structure of the input string matches some part of
the grammar that is optional, or has multiple choices.

However, once the choice of grammar has been made, it is often useful to be
able to fix on that one choice, thus making subsequent failures propagate up
rather than taking that alternative behaviour. Control of this backtracking
is given by the C<commit> method; and careful use of this method is one of the
key advantages that C<Parser::MGC> has over more simple parsing using single
regexps alone.

=cut

=head1 CONSTRUCTOR

=cut

=head2 new

   $parser = Parser::MGC->new( %args )

Returns a new instance of a C<Parser::MGC> object. This must be called on a
subclass that provides method of the name provided as C<toplevel>, by default
called C<parse>.

Takes the following named arguments

=over 8

=item toplevel => STRING

Name of the toplevel method to use to start the parse from. If not supplied,
will try to use a method called C<parse>.

=item patterns => HASH

Keys in this hash should map to quoted regexp (C<qr//>) references, to
override the default patterns used to match tokens. See C<PATTERNS> below

=item accept_0o_oct => BOOL

If true, the C<token_int> method will also accept integers with a C<0o> prefix
as octal.

=back

=cut

=head1 PATTERNS

The following pattern names are recognised. They may be passed to the
constructor in the C<patterns> hash, or provided as a class method under the
name C<pattern_I<name>>.

=over 4

=item * ws

Pattern used to skip whitespace between tokens. Defaults to C</[\s\n\t]+/>

=item * comment

Pattern used to skip comments between tokens. Undefined by default.

=item * int

Pattern used to parse an integer by C<token_int>. Defaults to
C</-?(?:0x[[:xdigit:]]+|[[:digit:]]+)/>. If C<accept_0o_oct> is given, then
this will be expanded to match C</0o[0-7]+/> as well.

=item * float

Pattern used to parse a floating-point number by C<token_float>. Defaults to
C</-?(?:\d*\.\d+|\d+\.)(?:e-?\d+)?|-?\d+e-?\d+/i>.

=item * ident

Pattern used to parse an identifier by C<token_ident>. Defaults to
C</[[:alpha:]_]\w*/>

=item * string_delim

Pattern used to delimit a string by C<token_string>. Defaults to C</["']/>.

=back

=cut

my @patterns = qw(
   ws
   comment
   int
   float
   ident
   string_delim
);

use constant pattern_ws      => qr/[\s\n\t]+/;
use constant pattern_comment => undef;
use constant pattern_int     => qr/-?(?:0x[[:xdigit:]]+|[[:digit:]]+)/;
use constant pattern_float   => qr/-?(?:\d*\.\d+|\d+\.)(?:e-?\d+)?|-?\d+e-?\d+/i;
use constant pattern_ident   => qr/[[:alpha:]_]\w*/;
use constant pattern_string_delim => qr/["']/;

sub new
{
   my $class = shift;
   my %args = @_;

   my $toplevel = $args{toplevel} || "parse";

   $class->can( $toplevel ) or
      croak "Expected to be a subclass that can ->$toplevel";

   my $self = bless {
      toplevel => $toplevel,
      patterns => {},
      scope_level => 0,
   }, $class;

   $self->{patterns}{$_} = $args{patterns}{$_} || $self->${\"pattern_$_"} for @patterns;

   if( $args{accept_0o_oct} ) {
      $self->{patterns}{int} = qr/0o[0-7]+|$self->{patterns}{int}/;
   }

   if( defined $self->{patterns}{comment} ) {
      $self->{patterns}{_skip} = qr/$self->{patterns}{ws}|$self->{patterns}{comment}/;
   }
   else {
      $self->{patterns}{_skip} = $self->{patterns}{ws};
   }

   return $self;
}

=head1 METHODS

=cut

=head2 from_string

   $result = $parser->from_string( $str )

Parse the given literal string and return the result from the toplevel method.

=cut

sub from_string
{
   my $self = shift;
   my ( $str ) = @_;

   $self->{str} = $str;

   pos $self->{str} = 0;

   my $toplevel = $self->{toplevel};
   my $result = $self->$toplevel;

   $self->at_eos or
      $self->fail( "Expected end of input" );

   return $result;
}

=head2 from_file

   $result = $parser->from_file( $file, %opts )

Parse the given file, which may be a pathname in a string, or an opened IO
handle, and return the result from the toplevel method.

The following options are recognised:

=over 8

=item binmode => STRING

If set, applies the given binmode to the filehandle before reading. Typically
this can be used to set the encoding of the file.

   $parser->from_file( $file, binmode => ":encoding(UTF-8)" )

=back

=cut

sub from_file
{
   my $self = shift;
   my ( $file, %opts ) = @_;

   defined $file or croak "Expected a filename to ->from_file";

   $self->{filename} = $file;

   $self->from_string( ref $file ?
      do { local $/; binmode $file, $opts{binmode} if $opts{binmode}; <$file> } :
      ( read_file $file, binmode => $opts{binmode} ) );
}

=head2 from_reader

   $result = $parser->from_reader( \&reader )

I<Since version 0.05.>

Parse the input which is read by the C<reader> function. This function will be
called in scalar context to generate portions of string to parse, being passed
the C<$parser> object. The function should return C<undef> when it has no more
string to return.

   $reader->( $parser )

Note that because it is not generally possible to detect exactly when more
input may be required due to failed regexp parsing, the reader function is
only invoked during searching for skippable whitespace. This makes it suitable
for reading lines of a file in the common case where lines are considered as
skippable whitespace, or for reading lines of input interactively from a
user. It cannot be used in all cases (for example, reading fixed-size buffers
from a file) because two successive invocations may split a single token
across the buffer boundaries, and cause parse failures.

=cut

sub from_reader
{
   my $self = shift;
   my ( $reader ) = @_;

   local $self->{reader} = $reader;

   $self->{str} = "";
   pos $self->{str} = 0;

   my $result = $self->parse;

   $self->at_eos or
      $self->fail( "Expected end of input" );

   return $result;
}

=head2 pos

   $pos = $parser->pos

I<Since version 0.09.>

Returns the current parse position, as a character offset from the beginning
of the file or string.

=cut

sub pos
{
   my $self = shift;
   return pos $self->{str};
}

=head2 take

   $str = $parser->take( $len )

I<Since version 0.16.>

Returns the next C<$len> characters directly from the input, prior to any
whitespace or comment skipping. This does I<not> take account of any
end-of-scope marker that may be pending. It is intended for use by parsers of
partially-binary protocols, or other situations in which it would be incorrect
for the end-of-scope marker to take effect at this time.

=cut

sub take
{
   my $self = shift;
   my ( $len ) = @_;

   my $start = pos( $self->{str} );

   pos( $self->{str} ) += $len;

   return substr( $self->{str}, $start, $len );
}

=head2 where

   ( $lineno, $col, $text ) = $parser->where

Returns the current parse position, as a line and column number, and
the entire current line of text. The first line is numbered 1, and the first
column is numbered 0.

=cut

sub where
{
   my $self = shift;
   my ( $pos ) = @_;

   defined $pos or $pos = pos $self->{str};

   my $str = $self->{str};

   my $sol = $pos;
   $sol-- if $sol > 0 and substr( $str, $sol, 1 ) =~ m/^[\r\n]$/;
   $sol-- while $sol > 0 and substr( $str, $sol-1, 1 ) !~ m/^[\r\n]$/;

   my $eol = $pos;
   $eol++ while $eol < length($str) and substr( $str, $eol, 1 ) !~ m/^[\r\n]$/;

   my $line = substr( $str, $sol, $eol - $sol );

   my $col = $pos - $sol;
   my $lineno = ( () = substr( $str, 0, $pos ) =~ m/\n/g ) + 1;

   return ( $lineno, $col, $line );
}

=head2 fail

=head2 fail_from

   $parser->fail( $message )

   $parser->fail_from( $pos, $message )

I<C<fail_from> since version 0.09.>

Aborts the current parse attempt with the given message string. The failure
message will include the line and column position, and the line of input that
failed at the current parse position (C<fail>), or a position earlier obtained
using the C<pos> method (C<fail_from>).

This failure will propagate up to the inner-most structure parsing method that
has not been committed; or will cause the entire parser to fail if there are
no further options to take.

=cut

sub fail
{
   my $self = shift;
   my ( $message ) = @_;
   $self->fail_from( $self->pos, $message );
}

sub fail_from
{
   my $self = shift;
   my ( $pos, $message ) = @_;
   die Parser::MGC::Failure->new( $message, $self, $pos );
}

sub _isa_failure { blessed $_[0] and $_[0]->isa( "Parser::MGC::Failure" ) }

=head2 at_eos

   $eos = $parser->at_eos

Returns true if the input string is at the end of the string.

=cut

sub at_eos
{
   my $self = shift;

   # Save pos() before skipping ws so we don't break the substring_before method
   my $pos = pos $self->{str};

   $self->skip_ws;

   my $at_eos;
   if( pos( $self->{str} ) >= length $self->{str} ) {
      $at_eos = 1;
   }
   elsif( defined $self->{endofscope} ) {
      $at_eos = $self->{str} =~ m/\G$self->{endofscope}/;
   }
   else {
      $at_eos = 0;
   }

   pos( $self->{str} ) = $pos;

   return $at_eos;
}

=head2 scope_level

   $level = $parser->scope_level

I<Since version 0.05.>

Returns the number of nested C<scope_of> calls that have been made.

=cut

sub scope_level
{
   my $self = shift;
   return $self->{scope_level};
}

=head1 STRUCTURE-FORMING METHODS

The following methods may be used to build a grammatical structure out of the
defined basic token-parsing methods. Each takes at least one code reference,
which will be passed the actual C<$parser> object as its first argument.

Anywhere that a code reference is expected also permits a plain string giving
the name of a method to invoke. This is sufficient in many simple cases, such
as

   $self->any_of(
      'token_int',
      'token_string',
      ...
   );

=cut

=head2 maybe

   $ret = $parser->maybe( $code )

Attempts to execute the given C<$code> in scalar context, and returns what it
returned, accepting that it might fail. C<$code> may either be a CODE
reference or a method name given as a string.

If the code fails (either by calling C<fail> itself, or by propagating a
failure from another method it invoked) before it has invoked C<commit>, then
none of the input string will be consumed; the current parsing position will
be restored. C<undef> will be returned in this case.

If it calls C<commit> then any subsequent failure will be propagated to the
caller, rather than returning C<undef>.

This may be considered to be similar to the C<?> regexp qualifier.

   sub parse_declaration
   {
      my $self = shift;

      [ $self->parse_type,
        $self->token_ident,
        $self->maybe( sub {
           $self->expect( "=" );
           $self->parse_expression
        } ),
      ];
   }

=cut

sub maybe
{
   my $self = shift;
   my ( $code ) = @_;

   my $pos = pos $self->{str};

   my $committed = 0;
   local $self->{committer} = sub { $committed++ };

   try {
      return $self->$code;
   }
   catch ( $e ) {
      pos($self->{str}) = $pos;

      die $e if $committed or not _isa_failure( $e );
      return undef;
   }
}

=head2 scope_of

   $ret = $parser->scope_of( $start, $code, $stop )

Expects to find the C<$start> pattern, then attempts to execute the given
C<$code>, then expects to find the C<$stop> pattern. Returns whatever the
code returned. C<$code> may either be a CODE reference of a method name given
as a string.

While the code is being executed, the C<$stop> pattern will be used by the
token parsing methods as an end-of-scope marker; causing them to raise a
failure if called at the end of a scope.

   sub parse_block
   {
      my $self = shift;

      $self->scope_of( "{", 'parse_statements', "}" );
   }

If the C<$start> pattern is undefined, it is presumed the caller has already
checked for this. This is useful when the stop pattern needs to be calculated
based on the start pattern.

   sub parse_bracketed
   {
      my $self = shift;

      my $delim = $self->expect( qr/[\(\[\<\{]/ );
      $delim =~ tr/([<{/)]>}/;

      $self->scope_of( undef, 'parse_body', $delim );
   }

This method does not have any optional parts to it; any failures are
immediately propagated to the caller.

=cut

sub scope_of
{
   my $self = shift;
   $self->_scope_of( 0, @_ );
}

sub _scope_of
{
   my $self = shift;
   my ( $commit_if_started, $start, $code, $stop ) = @_;

   ref $stop or $stop = qr/\Q$stop/;

   $self->expect( $start ) if defined $start;

   $self->commit if $commit_if_started;

   local $self->{endofscope} = $stop;
   local $self->{scope_level} = $self->{scope_level} + 1;

   my $ret = $self->$code;

   $self->expect( $stop );

   return $ret;
}

=head2 committed_scope_of

   $ret = $parser->committed_scope_of( $start, $code, $stop )

I<Since version 0.16.>

A variant of L</scope_of> that calls L</commit> after a successful match of
the start pattern. This is usually what you want if using C<scope_of> from
within an C<any_of> choice, if no other alternative following this one could
possibly match if the start pattern has.

=cut

sub committed_scope_of
{
   my $self = shift;
   $self->_scope_of( 1, @_ );
}

=head2 list_of

   $ret = $parser->list_of( $sep, $code )

Expects to find a list of instances of something parsed by C<$code>,
separated by the C<$sep> pattern. Returns an ARRAY ref containing a list of
the return values from the C<$code>. A single trailing delimiter is allowed,
and does not affect the return value. C<$code> may either be a CODE reference
or a method name given as a string. It is called in list context, and whatever
values it returns are appended to the eventual result - similar to perl's
C<map>.

This method does not consider it an error if the returned list is empty; that
is, that the scope ended before any item instances were parsed from it.

   sub parse_numbers
   {
      my $self = shift;

      $self->list_of( ",", 'token_int' );
   }

If the code fails (either by invoking C<fail> itself, or by propagating a
failure from another method it invoked) before it has invoked C<commit> on a
particular item, then the item is aborted and the parsing position will be
restored to the beginning of that failed item. The list of results from
previous successful attempts will be returned.

If it calls C<commit> within an item then any subsequent failure for that item
will cause the entire C<list_of> to fail, propagating that to the caller.

=cut

sub list_of
{
   my $self = shift;
   my ( $sep, $code ) = @_;

   ref $sep or $sep = qr/\Q$sep/ if defined $sep;

   my $committed;
   local $self->{committer} = sub { $committed++ };

   my @ret;

   while( !$self->at_eos ) {
      $committed = 0;
      my $pos = pos $self->{str};

      try {
         push @ret, $self->$code;
         next;
      }
      catch ( $e ) {
         pos($self->{str}) = $pos;
         die $e if $committed or not _isa_failure( $e );

         last;
      }
   }
   continue {
      if( defined $sep ) {
         $self->skip_ws;
         $self->{str} =~ m/\G$sep/gc or last;
      }
   }

   return \@ret;
}

=head2 sequence_of

   $ret = $parser->sequence_of( $code )

A shortcut for calling C<list_of> with an empty string as separator; expects
to find at least one instance of something parsed by C<$code>, separated only
by skipped whitespace.

This may be considered to be similar to the C<+> or C<*> regexp qualifiers.

   sub parse_statements
   {
      my $self = shift;

      $self->sequence_of( 'parse_statement' );
   }

The interaction of failures in the code and the C<commit> method is identical
to that of C<list_of>.

=cut

sub sequence_of
{
   my $self = shift;
   my ( $code ) = @_;

   $self->list_of( undef, $code );
}

=head2 any_of

   $ret = $parser->any_of( @codes )

I<Since version 0.06.>

Expects that one of the given code instances can parse something from the
input, returning what it returned. Each code instance may indicate a failure
to parse by calling the C<fail> method or otherwise propagating a failure.
Each code instance may either be a CODE reference or a method name given as a
string.

This may be considered to be similar to the C<|> regexp operator for forming
alternations of possible parse trees.

   sub parse_statement
   {
      my $self = shift;

      $self->any_of(
         sub { $self->parse_declaration; $self->expect(";") },
         sub { $self->parse_expression; $self->expect(";") },
         sub { $self->parse_block },
      );
   }

If the code for a given choice fails (either by invoking C<fail> itself, or by
propagating a failure from another method it invoked) before it has invoked
C<commit> itself, then the parsing position restored and the next choice will
be attempted.

If it calls C<commit> then any subsequent failure for that choice will cause
the entire C<any_of> to fail, propagating that to the caller and no further
choices will be attempted.

If none of the choices match then a simple failure message is printed:

   Found nothing parseable

As this is unlikely to be helpful to users, a better message can be provided
by the final choice instead. Don't forget to C<commit> before printing the
failure message, or it won't count.

   $self->any_of(
      'token_int',
      'token_string',
      ...,

      sub { $self->commit; $self->fail( "Expected an int or string" ) }
   );

=cut

sub any_of
{
   my $self = shift;

   while( @_ ) {
      my $code = shift;
      my $pos = pos $self->{str};

      my $committed = 0;
      local $self->{committer} = sub { $committed++ };

      try {
         return $self->$code;
      }
      catch ( $e ) {
         pos( $self->{str} ) = $pos;

         die $e if $committed or not _isa_failure( $e );
      }
   }

   $self->fail( "Found nothing parseable" );
}

sub one_of {
   croak "Parser::MGC->one_of is deprecated; use ->any_of instead";
}

=head2 commit

   $parser->commit

Calling this method will cancel the backtracking behaviour of the innermost
C<maybe>, C<list_of>, C<sequence_of>, or C<any_of> structure forming method.
That is, if later code then calls C<fail>, the exception will be propagated
out of C<maybe>, no further list items will be attempted by C<list_of> or
C<sequence_of>, and no further code blocks will be attempted by C<any_of>.

Typically this will be called once the grammatical structure alter has been
determined, ensuring that any further failures are raised as real exceptions,
rather than by attempting other alternatives.

 sub parse_statement
 {
    my $self = shift;

    $self->any_of(
       ...
       sub {
          $self->scope_of( "{",
             sub { $self->commit; $self->parse_statements; },
          "}" ),
       },
    );
 }

Though in this common pattern, L</committed_scope_of> may be used instead.

=cut

sub commit
{
   my $self = shift;
   if( $self->{committer} ) {
      $self->{committer}->();
   }
   else {
      croak "Cannot commit except within a backtrack-able structure";
   }
}

=head1 TOKEN PARSING METHODS

The following methods attempt to consume some part of the input string, to be
used as part of the parsing process.

=cut

sub skip_ws
{
   my $self = shift;

   my $pattern = $self->{patterns}{_skip};

   {
      1 while $self->{str} =~ m/\G$pattern/gc;

      return if pos( $self->{str} ) < length $self->{str};

      return unless $self->{reader};

      my $more = $self->{reader}->( $self );
      if( defined $more ) {
         my $pos = pos( $self->{str} );
         $self->{str} .= $more;
         pos( $self->{str} ) = $pos;

         redo;
      }

      undef $self->{reader};
      return;
   }
}

=head2 expect

   $str = $parser->expect( $literal )

   $str = $parser->expect( qr/pattern/ )

   @groups = $parser->expect( qr/pattern/ )

Expects to find a literal string or regexp pattern match, and consumes it.
In scalar context, this method returns the string that was captured. In list
context it returns the matching substring and the contents of any subgroups
contained in the pattern.

This method will raise a parse error (by calling C<fail>) if the regexp fails
to match. Note that if the pattern could match an empty string (such as for
example C<qr/\d*/>), the pattern will always match, even if it has to match an
empty string. This method will not consider a failure if the regexp matches
with zero-width.

=head2 maybe_expect

   $str = $parser->maybe_expect( ... )

   @groups = $parser->maybe_expect( ... )

I<Since version 0.10.>

A convenient shortcut equivalent to calling C<expect> within C<maybe>, but
implemented more efficiently, avoiding the exception-handling set up by
C<maybe>. Returns C<undef> or an empty list if the match fails.

=cut

sub maybe_expect
{
   my $self = shift;
   my ( $expect ) = @_;

   ref $expect or $expect = qr/\Q$expect/;

   $self->skip_ws;
   $self->{str} =~ m/\G$expect/gc or return;

   return substr( $self->{str}, $-[0], $+[0]-$-[0] ) if !wantarray;
   return map { defined $-[$_] ? substr( $self->{str}, $-[$_], $+[$_]-$-[$_] ) : undef } 0 .. $#+;
}

sub expect
{
   my $self = shift;
   my ( $expect ) = @_;

   ref $expect or $expect = qr/\Q$expect/;

   if( wantarray ) {
      my @ret = $self->maybe_expect( $expect ) or
         $self->fail( "Expected $expect" );
      return @ret;
   }
   else {
      defined( my $ret = $self->maybe_expect( $expect ) ) or
         $self->fail( "Expected $expect" );
      return $ret;
   }
}

=head2 substring_before

   $str = $parser->substring_before( $literal )

   $str = $parser->substring_before( qr/pattern/ )

I<Since version 0.06.>

Expects to possibly find a literal string or regexp pattern match. If it finds
such, consume all the input text before but excluding this match, and return
it. If it fails to find a match before the end of the current scope, consumes
all the input text until the end of scope and return it.

This method does not consume the part of input that matches, only the text
before it. It is not considered a failure if the substring before this match
is empty. If a non-empty match is required, use the C<fail> method:

   sub token_nonempty_part
   {
      my $self = shift;

      my $str = $parser->substring_before( "," );
      length $str or $self->fail( "Expected a string fragment before ," );

      return $str;
   }

Note that unlike most of the other token parsing methods, this method does not
consume either leading or trailing whitespace around the substring. It is
expected that this method would be used as part a parser to read quoted
strings, or similar cases where whitespace should be preserved.

=cut

sub substring_before
{
   my $self = shift;
   my ( $expect ) = @_;

   ref $expect or $expect = qr/\Q$expect/;

   my $endre = ( defined $self->{endofscope} ) ?
      qr/$expect|$self->{endofscope}/ :
      $expect;

   # NO skip_ws

   my $start = pos $self->{str};
   my $end;
   if( $self->{str} =~ m/\G(?s:.*?)($endre)/ ) {
      $end = $-[1];
   }
   else {
      $end = length $self->{str};
   }

   return $self->take( $end - $start );
}

=head2 generic_token

   $val = $parser->generic_token( $name, $re, $convert )

I<Since version 0.08.>

Expects to find a token matching the precompiled regexp C<$re>. If provided,
the C<$convert> CODE reference can be used to convert the string into a more
convenient form. C<$name> is used in the failure message if the pattern fails
to match.

If provided, the C<$convert> function will be passed the parser and the
matching substring; the value it returns is returned from C<generic_token>.

   $convert->( $parser, $substr )

If not provided, the substring will be returned as it stands.

This method is mostly provided for subclasses to define their own token types.
For example:

   sub token_hex
   {
      my $self = shift;
      $self->generic_token( hex => qr/[0-9A-F]{2}h/, sub { hex $_[1] } );
   }

=cut

sub generic_token
{
   my $self = shift;
   my ( $name, $re, $convert ) = @_;

   $self->fail( "Expected $name" ) if $self->at_eos;

   $self->skip_ws;
   $self->{str} =~ m/\G$re/gc or
      $self->fail( "Expected $name" );

   my $match = substr( $self->{str}, $-[0], $+[0] - $-[0] );

   return $convert ? $convert->( $self, $match ) : $match;
}

sub _token_generic
{
   my $self = shift;
   my %args = @_;

   my $name    = $args{name};
   my $re      = $args{pattern} ? $self->{patterns}{ $args{pattern} } : $args{re};
   my $convert = $args{convert};

   $self->generic_token( $name, $re, $convert );
}

=head2 token_int

   $int = $parser->token_int

Expects to find an integer in decimal, octal or hexadecimal notation, and
consumes it. Negative integers, preceeded by C<->, are also recognised.

=cut

sub token_int
{
   my $self = shift;
   $self->_token_generic(
      name => "int",

      pattern => "int",
      convert => sub {
         my $int = $_[1];
         my $sign = ( $int =~ s/^-// ) ? -1 : 1;

         $int =~ s/^0o/0/;

         return $sign * oct $int if $int =~ m/^0/;
         return $sign * $int;
      },
   );
}

=head2 token_float

   $float = $parser->token_float

I<Since version 0.04.>

Expects to find a number expressed in floating-point notation; a sequence of
digits possibly prefixed by C<->, possibly containing a decimal point,
possibly followed by an exponent specified by C<e> followed by an integer. The
numerical value is then returned.

=cut

sub token_float
{
   my $self = shift;
   $self->_token_generic(
      name => "float",

      pattern => "float",
      convert => sub { $_[1] + 0 },
   );
}

=head2 token_number

   $number = $parser->token_number

I<Since version 0.09.>

Expects to find a number expressed in either of the above forms.

=cut

sub token_number
{
   my $self = shift;
   $self->any_of( \&token_float, \&token_int );
}

=head2 token_string

   $str = $parser->token_string

Expects to find a quoted string, and consumes it. The string should be quoted
using C<"> or C<'> quote marks.

The content of the quoted string can contain character escapes similar to
those accepted by C or Perl. Specifically, the following forms are recognised:

   \a               Bell ("alert")
   \b               Backspace
   \e               Escape
   \f               Form feed
   \n               Newline
   \r               Return
   \t               Horizontal Tab
   \0, \012         Octal character
   \x34, \x{5678}   Hexadecimal character

C's C<\v> for vertical tab is not supported as it is rarely used in practice
and it collides with Perl's C<\v> regexp escape. Perl's C<\c> for forming other
control characters is also not supported.

=cut

my %escapes = (
   a => "\a",
   b => "\b",
   e => "\e",
   f => "\f",
   n => "\n",
   r => "\r",
   t => "\t",
);

sub token_string
{
   my $self = shift;

   $self->fail( "Expected string" ) if $self->at_eos;

   my $pos = pos $self->{str};

   $self->skip_ws;
   $self->{str} =~ m/\G($self->{patterns}{string_delim})/gc or
      $self->fail( "Expected string delimiter" );

   my $delim = $1;

   $self->{str} =~ m/
      \G(
         (?:
            \\[0-7]{1,3}     # octal escape
           |\\x[0-9A-F]{2}   # 2-digit hex escape
           |\\x\{[0-9A-F]+\} # {}-delimited hex escape
           |\\.              # symbolic escape
           |[^\\$delim]+     # plain chunk
         )*?
      )$delim/gcix or
         pos($self->{str}) = $pos, $self->fail( "Expected contents of string" );

   my $string = $1;

   $string =~ s<\\(?:([0-7]{1,3})|x([0-9A-F]{2})|x\{([0-9A-F]+)\}|(.))>
               [defined $1 ? chr oct $1 :
                defined $2 ? chr hex $2 :
                defined $3 ? chr hex $3 :
                             exists $escapes{$4} ? $escapes{$4} : $4]egi;

   return $string;
}

=head2 token_ident

   $ident = $parser->token_ident

Expects to find an identifier, and consumes it.

=cut

sub token_ident
{
   my $self = shift;
   $self->_token_generic(
      name => "ident",

      pattern => "ident",
   );
}

=head2 token_kw

   $keyword = $parser->token_kw( @keywords )

Expects to find a keyword, and consumes it. A keyword is defined as an
identifier which is exactly one of the literal values passed in.

=cut

sub token_kw
{
   my $self = shift;
   my @acceptable = @_;

   $self->skip_ws;

   my $pos = pos $self->{str};

   defined( my $kw = $self->token_ident ) or
      return undef;

   grep { $_ eq $kw } @acceptable or
      pos($self->{str}) = $pos, $self->fail( "Expected any of ".join( ", ", @acceptable ) );

   return $kw;
}

package # hide from indexer
   Parser::MGC::Failure;

sub new
{
   my $class = shift;
   my $self = bless {}, $class;
   @{$self}{qw( message parser pos )} = @_;
   return $self;
}

use overload '""' => "STRING";
sub STRING
{
   my $self = shift;

   my $parser = $self->{parser};
   my ( $linenum, $col, $text ) = $parser->where( $self->{pos} );

   # Column number only counts characters. There may be tabs in there.
   # Rather than trying to calculate the visual column number, just print the
   # indentation as it stands.

   my $indent = substr( $text, 0, $col );
   $indent =~ s/[^ \t]/ /g; # blank out all the non-whitespace

   my $filename = $parser->{filename};
   my $in_file = ( defined $filename and !ref $filename )
                    ? "in $filename " : "";

   return "$self->{message} ${in_file}on line $linenum at:\n" . 
          "$text\n" . 
          "$indent^\n";
}

# Provide fallback operators for cmp, eq, etc...
use overload fallback => 1;

=head1 EXAMPLES

=head2 Accumulating Results Using Variables

Although the structure-forming methods all return a value, obtained from their
nested parsing code, it can sometimes be more convenient to use a variable to
accumulate a result in instead. For example, consider the following parser
method, designed to parse a set of C<name: "value"> assignments, such as might
be found in a configuration file, or YAML/JSON-style mapping value.

   sub parse_dict
   {
      my $self = shift;

      my %ret;
      $self->list_of( ",", sub {
         my $key = $self->token_ident;
         exists $ret{$key} and $self->fail( "Already have a mapping for '$key'" );

         $self->expect( ":" );

         $ret{$key} = $self->parse_value;
      } );

      return \%ret
   }

Instead of using the return value from C<list_of>, this method accumulates
values in the C<%ret> hash, eventually returning a reference to it as its
result. Because of this, it can perform some error checking while it parses;
namely, rejecting duplicate keys.

=head1 TODO

=over 4

=item *

Make unescaping of string constants more customisable. Possibly consider
instead a C<parse_string_generic> using a loop over C<substring_before>.

=item *

Easy ability for subclasses to define more token types as methods. Perhaps
provide a class method such as

   __PACKAGE__->has_token( hex => qr/[0-9A-F]+/i, sub { hex $_[1] } );

=item *

Investigate how well C<from_reader> can cope with buffer splitting across
other tokens than simply skippable whitespace

=back

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
