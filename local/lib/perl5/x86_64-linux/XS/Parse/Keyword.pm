#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2021 -- leonerd@leonerd.org.uk

package XS::Parse::Keyword 0.21;

use v5.14;
use warnings;

require XSLoader;
XSLoader::load( __PACKAGE__, our $VERSION );

=head1 NAME

C<XS::Parse::Keyword> - XS functions to assist in parsing keyword syntax

=head1 DESCRIPTION

This module provides some XS functions to assist in writing syntax modules
that provide new perl-visible syntax, primarily for authors of keyword plugins
using the C<PL_keyword_plugin> hook mechanism. It is unlikely to be of much
use to anyone else; and highly unlikely to be any use when writing perl code
using these. Unless you are writing a keyword plugin using XS, this module is
not for you.

This module is also currently experimental, and the design is still evolving
and subject to change. Later versions may break ABI compatibility, requiring
changes or at least a rebuild of any module that depends on it.

=cut

=head1 XS FUNCTIONS

=head2 boot_xs_parse_keyword

   void boot_xs_parse_keyword(double ver);

Call this function from your C<BOOT> section in order to initialise the module
and parsing hooks.

I<ver> should either be 0 or a decimal number for the module version
requirement; e.g.

   boot_xs_parse_keyword(0.14);

=head2 register_xs_parse_keyword

   void register_xs_parse_keyword(const char *keyword,
     const struct XSParseKeywordHooks *hooks, void *hookdata);

This function installs a set of parsing hooks to be associated with the given
keyword. Such a keyword will then be handled automatically by a keyword parser
installed by C<XS::Parse::Keyword> itself.

=cut

=head1 PARSE HOOKS

The C<XSParseKeywordHooks> structure provides the following hook stages, which
are invoked in the given order.

=head2 flags

The following flags are defined:

=over 4

=item C<XPK_FLAG_EXPR>

The parse or build function is expected to return C<KEYWORD_PLUGIN_EXPR>.

=item C<XPK_FLAG_STMT>

The parse or build function is expected to return C<KEYWORD_PLUGIN_STMT>.

These two flags are largely for the benefit of giving static information at
registration time to assist static parsing or other related tasks to know what
kind of grammatical element this keyword will produce.

=item C<XPK_FLAG_AUTOSEMI>

The syntax forms a complete statement, which should be followed by a statement
separator semicolon (C<;>). This semicolon is optional at the end of a block.

The semicolon, if present, will be consumed automatically.

=back

=head2 The C<permit> Stage

   const char *permit_hintkey;
   bool (*permit) (pTHX_ void *hookdata);

Called by the installed keyword parser hook which is used to handle keywords
registered by L</register_xs_parse_keyword>.

As a shortcut for the common case, the C<permit_hintkey> may point to a string
to look up from the hints hash. If the given key name is not found in the
hints hash then the keyword is not permitted. If the key is present then the
C<permit> function is invoked as normal.

If not rejected by a hint key that was not found in the hints hash, the
function part of the stage is called next and should inspect whether the
keyword is permitted at this time perhaps by inspecting other lexical clues,
and return true only if the keyword is permitted.

Both the string and the function are optional. Either or both may be present.
If neither is present then the keyword is always permitted - which is likely
not what you wanted to do.

=head2 The C<check> Stage

   void (*check)(pTHX_ void *hookdata);

Invoked once the keyword has been permitted. If present, this hook function
can check the surrounding lexical context, state, or other information and
throw an exception if it is unhappy that the keyword should apply in this
position.

=head2 The C<parse> Stage

This stage is invoked once the keyword has been checked, and actually
parses the incoming text into an optree. It is implemented by calling the
B<first> of the following function pointers which is not NULL. The invoked
function may optionally build an optree to represent the parsed syntax, and
place it into the variable addressed by C<out>. If it does not, then a simple
C<OP_NULL> will be constructed in its place.

C<lex_read_space()> is called both before and after this stage is invoked, so
in many simple cases the hook function itself does not need to bother with it.

   int (*parse)(pTHX_ OP **out, void *hookdata);

If present, this should consume text from the parser buffer by invoking
C<lex_*> or C<parse_*> functions and eventually return a C<KEYWORD_PLUGIN_*>
result value.

This is the most generic and powerful of the options, but requires the most
amount of implementation work.

   int (*build)(pTHX_ OP **out, XSParseKeywordPiece *args[], size_t nargs, void *hookdata);

If C<parse> is not present, this is called instead after parsing a sequence of
arguments, of types given by the I<pieces> field; which should be a zero-
terminated array of piece types.

This alternative is somewhat less generic and powerful than providing C<parse>
yourself, but involves much less parsing work and is shorter and easier to
implement.

   int (*build1)(pTHX_ OP **out, XSParseKeywordPiece *arg0, void *hookdata);

If neither C<parse> nor C<build> are present, this is called as a simpler
variant of C<build> when only a single argument is required. It takes its type
from the C<piece1> field instead.

=cut

=head1 PIECES AND PIECE TYPES

When using the C<build> or C<build1> alternatives for the C<parse> phase, the
actual syntax is parsed automatically by this module, according to the
specification given by the I<pieces> or I<piece1> field. The result of that
parsing step is placed into the I<args> or I<arg0> parameter to the invoked
function, using a C<struct> type consisting of the following fields:

   typedef struct
      union {
         OP *op;
         CV *cv;
         SV *sv;
         int i;
         struct {
            SV *name;
            SV *value;
         } attr;
         PADOFFSET padix;
         struct XSParseInfixInfo *infix;
      };
      int line;
   } XSParseKeywordPiece;

Which field of the anonymous union is set depends on the type of the piece.
The I<line> field contains the line number of the source file where parsing of
that piece began.

Some piece types are "atomic", whose definition is self-contained. Others are
structural, defined in terms of inner pieces. Together these form an entire
tree-shaped definition of the syntax that the keyword expects to find.

Atomic types generally provide exactly one argument into the list of I<args>
(with the exception of literal matches, which do not provide anything).
Structural types may provide an initial argument themselves, followed by a
list of the values of each sub-piece they contained inside them. Thus, while
the data structure defining the syntax shape is a tree, the argument values it
parses into is passed as a flat array to the C<build> function.

Some structural types need to be able to determine whether or not syntax
relating some optional part of them is present in the incoming source text. In
this case, the pieces relating to those optional parts must support "probing".
This ability is also noted below.

The type of each piece should be one of the following macro values.

=head2 XPK_BLOCK

I<atomic, can probe, emits op.>

   XPK_BLOCK

A brace-delimited block of code is expected, passed as an optree in the I<op>
field. This will be parsed as a block within the current function scope.

This can be probed by checking for the presence of an open-brace (C<{>)
character.

Be careful defining grammars with this because an open-brace is also a valid
character to start a term expression, for example. Given a choice between
C<XPK_BLOCK> and C<XPK_TERMEXPR>, either of them could try to consume such
code as

   { 123, 456 }

=head2 XPK_BLOCK_VOIDCTX, XPK_BLOCK_SCALARCTX, XPK_BLOCK_LISTCTX

Variants of C<XPK_BLOCK> which wrap a void, scalar or list-context scope
around the block.

=head2 XPK_PREFIXED_BLOCK

I<structural, emits op.>

   XPK_PREFIXED_BLOCK(pieces ...)

Some pieces are expected, followed by a brace-delimited block of code, which
is passed as an optree in the I<op> field. The prefix pieces are parsed first,
and their results are passed before the block itself.

The entire sequence, including the prefix items, is contained within a pair of
C<block_start()> / C<block_end()> calls. This permits the prefix pieces to
introduce new items into the lexical scope of the block - for example by the
use of C<XPK_LEXVAR_MY>.

A call to C<intro_my()> is automatically made at the end of the prefix pieces,
before the block itself is parsed, ensuring any new lexical variables are now
visible.

In addition, the following extra piece types are recognised here:

=over 4

=item XPK_SETUP

   void setup(pTHX_ void *hookdata);

   XPK_SETUP(&setup)

I<atomic, emits nothing.>

This piece type runs a function given by pointer. Typically this function may
be used to introduce new lexical state into the parser, or in some other way
have some side-effect on the parsing context of the block to be parsed.

=back

=head2 XPK_PREFIXED_BLOCK_ENTERLEAVE

A variant of C<XPK_PREFIXED_BLOCK> which additionally wraps the entire parsing
operation, including the C<block_start()>, C<block_end()> and any calls to
C<XPK_SETUP> functions, within a C<ENTER>/C<LEAVE> pair.

This should not make a difference to the standard parser pieces provided here,
but may be useful behaviour for the code in the setup function, especially if
it wishes to modify parser state and use the savestack to ensure it is
restored again when parsing has finished.

=head2 XPK_ANONSUB

I<atomic, emits op.>

A brace-delimited block of code is expected, and assembled into the body of a
new anonymous subroutine. This will be passed as a protosub CV in the I<cv>
field.

=head2 XPK_TERMEXPR

I<atomic, emits op.>

   XPK_TERMEXPR

A term expression is expected, parsed using C<parse_termexpr()>, and passed as
an optree in the I<op> field.

=head2 XPK_TERMEXPR_VOIDCTX, XPK_TERMEXPR_SCALARCTX

Variants of C<XPK_TERMEXPR> which puts the expression in void or scalar context.

=head2 XPK_LISTEXPR

I<atomic, emits op.>

   XPK_LISTEXPR

A list expression is expected, parsed using C<parse_listexpr()>, and passed as
an optree in the I<op> field.

=head2 XPK_LISTEXPR_LISTCTX

Variant of C<XPK_LISTEXPR> which puts the expression in list context.

=head2 XPK_IDENT, XPK_IDENT_OPT

I<atomic, can probe, emits sv.>

A bareword identifier name is expected, and passed as an SV containing a PV
in the I<sv> field. An identifier is not permitted to contain a double colon
(C<::>).

The C<_OPT>-suffixed version is optional; if no identifier is found then I<sv>
is set to C<NULL>.

=head2 XPK_PACKAGENAME, XPK_PACKAGENAME_OPT

I<atomic, can probe, emits sv.>

A bareword package name is expected, and passed as an SV containing a PV in
the I<sv> field. A package name is similar to an identifier, except it permits
double colons in the middle.

The C<_OPT>-suffixed version is optional; if no package name is found then
I<sv> is set to C<NULL>.

=head2 XPK_LEXVARNAME

I<atomic, emits sv.>

   XPK_LEXVARNAME(kind)

A lexical variable name is expected, and passed as an SV containing a PV in
the I<sv> field. The C<kind> argument specifies what kinds of variable are
permitted, and should be a bitmask of one or more bits from
C<XPK_LEXVAR_SCALAR>, C<XPK_LEXVAR_ARRAY> and C<XPK_LEXVAR_HASH>. A convenient
shortcut C<XPK_LEXVAR_ANY> permits all three.

=head2 XPK_ATTRIBUTES

I<atomic, emits i followed by more args.>

A list of C<:>-prefixed attributes is expected, in the same format as sub or
variable attributes. An optional leading C<:> indicates the presence of
attributes, then one or more of them are parsed. Attributes may be optionally
separated by additional C<:>s, but this is not required.

Each attribute is expected to be an identifier name, followed by an optional
value wrapped in parentheses. Whitespace is B<NOT> permitted between the name
and value, as per standard Perl parsing rules.

   :attrname
   :attrname(value)

The I<i> field indicates how many attributes were found. That number of
additional arguments are then passed, each containing two SVs in the
I<attr.name> and I<attr.value> fields. This number may be zero.

It is not an error for there to be no attributes present, or for the optional
colon to be missing. In this case I<i> will be set to zero.

=head2 XPK_VSTRING, XPK_VSTRING_OPT

I<atomic, can probe, emits sv.>

A version string is expected, of the form C<v1.234> including the leading C<v>
character. It is passed as a L<version> SV object in the I<sv> field.

The C<_OPT>-suffixed version is optional; if no version string is found then
I<sv> is set to C<NULL>.

=head2 XPK_LEXVAR_MY

I<atomic, emits padix.>

   XPK_LEXVAR_MY(kind)

A lexical variable name is expected, added to the current pad as if specified
in a C<my> expression, and passed as the pad index in the I<padix> field.

The C<kind> argument specifies what kinds of variable are permitted, as per
C<XPK_LEXVARNAME>.

=head2 XPK_COMMA, XPK_COLON, XPK_EQUALS

I<atomic, can probe, emits nothing.>

A literal character (C<,>, C<:> or C<=>) is expected. No argument value is passed.

=head2 XPK_INFIX_*

I<atomic, can probe, emits infix.>

An infix operator as recognised by L<XS::Parse::Infix>. The returned pointer
points to a structure allocated by C<XS::Parse::Infix> describing the
operator.

Various versions of the macro are provided, each using a different selection
filter to choose certain available infix operators:

   XPK_INFIX_RELATION         # any relational operator
   XPK_INFIX_EQUALITY         # an equality operator like `==` or `eq`
   XPK_INFIX_MATCH_NOSMART    # any sort of "match"-like operator, except smartmatch
   XPK_INFIX_MATCH_SMART      # XPK_INFIX_MATCH_NOSMART plus smartmatch

=head2 XPK_LITERAL

I<atomic, can probe, emits nothing.>

   XPK_LITERAL("literal")

A literal string match is expected. No argument value is passed.

This form should generally be avoided if at all possible, because it is very
easy to abuse to make syntaxes which confuse humans and code tools alike.
Generally it is best reserved just for the first component of a
C<XPK_OPTIONAL> or C<XPK_REPEATED> sequence, to provide a "secondary keyword"
that such a repeated item can look out for.

This was previously called C<XPK_STRING>, and is provided as a synonym for
back-compatibility but new code should use this new name instead.

=head2 XPK_SEQUENCE

I<structural, might support probe, emits nothing.>

   XPK_SEQUENCE(pieces ...)

A structural type which contains a number of pieces. This is normally
equivalent to simply placing the pieces in sequence inside their own
container, but it is useful inside C<XPK_CHOICE> or C<XPK_TAGGEDCHOICE>.

An C<XPK_SEQUENCE> supports probe if its first contained piece does; i.e.
is transparent to probing.

=head2 XPK_OPTIONAL

I<structural, emits i.>

   XPK_OPTIONAL(pieces ...)

A structural type which may expects to find its contained pieces, or is happy
not to. This will pass an argument whose I<i> field contains either 1 or 0,
depending whether the contents were found. The first piece type within must
support probe.

=head2 XPK_REPEATED

I<structural, emits i.>

   XPK_REPEATED(pieces ...)

A structural type which expects to find zero or more repeats of its contained
pieces. This will pass an argument whose I<i> field contains the count of the
number of repeats it found. The first piece type within must support probe.

=head2 XPK_CHOICE

I<structural, can probe, emits i.>

   XPK_CHOICE(options ...)

A structural type which expects to find one of a number of alternative
options. An ordered list of types is provided, all of which must support
probe. This will pass an argument whose I<i> field gives the index of the
first choice that was accepted. The first option takes the value 0.

As each of the options is interpreted as an alternative, not a sequence, you
should use C<XPK_SEQUENCE> if a sequence of multiple items should be
considered as a single alternative.

It is not an error if no choice matches. At that point, the I<i> field will be
set to -1.

If you require a failure message in this case, set the final choice to be of
type C<XPK_FAILURE>. This will cause an error message to be printed instead.

   XPK_FAILURE("message string")

=head2 XPK_TAGGEDCHOICE

I<structural, can probe, emits i.>

   XPK_TAGGEDCHOICE(choice, tag, ...)

A structural type similar to C<XPK_CHOICE>, except that each choice type is
followed by an element of type C<XPK_TAG> which gives an integer. It is that
integer value, rather than the positional index of the choice within the list,
which is passed in the I<i> field.

   XPK_TAG(value)

As each of the options is interpreted as an alternative, not a sequence, you
should use C<XPK_SEQUENCE> if a sequence of multiple items should be
considered as a single alternative.

=head2 XPK_COMMALIST

I<structural, might support probe, emits i.>

   XPK_COMMALIST(pieces ...)

A structural type which expects to find one or more repeats of its contained
pieces, separated by literal comma (C<,>) characters. This is somewhat similar
to C<XPK_REPEATED>, except that it needs at least one copy, needs commas
between its items, but does not require that the first contained piece support
probe (the comma itself is sufficient to indicate a repeat).

An C<XPK_COMMALIST> supports probe if its first contained piece does; i.e.
is transparent to probing.

=head2 XPK_PARENSCOPE

I<structural, can probe, emits nothing.>

   XPK_PARENSCOPE(pieces ...)

A structural type which expects to find a sequence of pieces, all contained in
parentheses as C<( ... )>. This will pass no extra arguments.

=head2 XPK_BRACKETSCOPE

I<structural, can probe, emits nothing.>

   XPK_BRACKETSCOPE(pieces ...)

A structural type which expects to find a sequence of pieces, all contained in
square brackets as C<[ ... ]>. This will pass no extra arguments.

=head2 XPK_BRACESCOPE

I<structural, can probe, emits nothing.>

   XPK_BRACESCOPE(pieces ...)

A structural type which expects to find a sequence of pieces, all contained in
braces as C<{ ... }>. This will pass no extra arguments.

Note that this is not necessary to use with C<XPK_BLOCK> or C<XPK_ANONSUB>;
those will already consume a set of braces. This is intended for special
constrained syntax that should not just accept an arbitrary block.

=head2 XPK_CHEVRONSCOPE

I<structural, can probe, emits nothing.>

   XPK_CHEVRONSCOPE(pieces ...)

A structural type which expects to find a sequence of pieces, all contained in
angle brackets as C<< < ... > >>. This will pass no extra arguments.

Remember that expressions like C<< a > b >> are valid term expressions, so the
contents of this scope shouldn't allow arbitrary expressions or the closing
bracket will be ambiguous.

=head2 XPK_PARENSCOPE_OPT, XPK_BRACKETSCOPE_OPT, XPK_BRACESCOPE_OPT, XPK_CHEVRONSCOPE_OPT

I<structural, can probe, emits i.>

   XPK_PARENSCOPE_OPT(pieces ...)
   XPK_BRACKETSCOPE_OPT(pieces ...)
   XPK_BRACESCOPE_OPT(pieces ...)
   XPK_CHEVERONSCOPE_OPT(pieces ...)

Each of the four C<XPK_...SCOPE> macros above has an optional variant, whose
name is suffixed by C<_OPT>. These pass an argument whose I<i> field is either
true or false, indicating whether the scope was found, followed by the values
from the scope itself.

This is a convenient shortcut to nesting the scope within a C<XPK_OPTIONAL>
macro.

=cut

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
