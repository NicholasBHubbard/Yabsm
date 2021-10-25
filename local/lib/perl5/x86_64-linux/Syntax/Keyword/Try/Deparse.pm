#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2021 -- leonerd@leonerd.org.uk

package Syntax::Keyword::Try::Deparse 0.26;

use v5.14;
use warnings;

use B qw( opnumber );

require B::Deparse;

use constant {
   OP_CUSTOM  => opnumber('custom'),
   OP_ENTER   => opnumber('enter'),
   OP_LINESEQ => opnumber('lineseq'),
};

=head1 NAME

C<Syntax::Keyword::Try::Deparse> - L<B::Deparse> support for L<Syntax::Keyword::Try>

=head1 DESCRIPTION

Loading this module will apply some hacks onto L<B::Deparse> that attempts to
provide deparse support for code which uses the syntax provided by
L<Syntax::Keyword::Try>.

=cut

my $orig_pp_leave;
{
   no warnings 'redefine';
   no strict 'refs';
   $orig_pp_leave = *{"B::Deparse::pp_leave"}{CODE};
   *{"B::Deparse::pp_leave"} = \&pp_leave;
}

sub pp_leave
{
   my $self = shift;
   my ( $op ) = @_;

   my $enter = $op->first;
   $enter->type == OP_ENTER or
      return $self->$orig_pp_leave( @_ );

   my $body = $enter->sibling;
   my $first = $body->first;

   my $finally = "";

   if( $body->type == OP_LINESEQ and $first->name eq "pushfinally" ) {
      my $finally_cv = $first->sv;
      $finally = "\nfinally " . $self->deparse_sub( $finally_cv ) . "\cK";

      $first = $first->sibling;
      $first = $first->sibling while $first and $first->name eq "lineseq";

      # Jump over a scope op
      if( $first->type == 0 ) {
         $body  = $first;
         $first = $first->first;
      }
   }

   if( $first->type == OP_CUSTOM and $first->name eq "catch" ) {
      # This is a try/catch block
      shift;
      return $self->deparse( $body, @_ ) . $finally;
   }
   elsif( length $finally ) {
      # Body is the remaining siblings. We'll have to do them all together
      my $try = B::Deparse::scopeop( 1, $self, $body, 0 );

      return "try {\n\t$try\n\b}" . $finally;
   }

   return $orig_pp_leave->($self, @_);
}

sub B::Deparse::pp_catch
{
   my $self = shift;
   my ( $op ) = @_;

   my $tryop   = $op->first;
   my $catchop = $op->first->sibling;

   my $try = $self->pp_leave($tryop, 0);

   # skip the OP_SCOPE and dive into the OP_LINESEQ inside
   #
   # TODO: Try to detect the `catch my $e` variable, though that will be hard
   # to dishtinguish from actual code that really does that
   my $catch = $self->deparse($catchop->first, 0);

   return "try {\n\t$try\n\b}\ncatch {\n\t$catch\n\b}\cK";
}

=head1 TODO

Correctly handle typed dispatch cases
(C<catch($var isa CLASS)>, C<catch($var =~ m/pattern/)>)

=cut

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
