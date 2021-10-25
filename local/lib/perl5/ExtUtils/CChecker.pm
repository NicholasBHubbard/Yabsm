#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2010-2021 -- leonerd@leonerd.org.uk

package ExtUtils::CChecker;

use v5;
use strict;
use warnings;

our $VERSION = '0.11';

use Carp;

use ExtUtils::CBuilder;

=head1 NAME

C<ExtUtils::CChecker> - configure-time utilities for using C headers,
libraries, or OS features

=head1 SYNOPSIS

   use Module::Build;
   use ExtUtils::CChecker;

   my $cc = ExtUtils::CChecker->new;

   $cc->assert_compile_run(
      diag => "no PF_MOONLASER",
      source => <<'EOF' );
   #include <stdio.h>
   #include <sys/socket.h>
   int main(int argc, char *argv[]) {
     printf("PF_MOONLASER is %d\n", PF_MOONLASER);
     return 0;
   }
   EOF

   Module::Build->new(
     ...
   )->create_build_script;

=head1 DESCRIPTION

Often Perl modules are written to wrap functionality found in existing C
headers, libraries, or to use OS-specific features. It is useful in the
F<Build.PL> or F<Makefile.PL> file to check for the existance of these
requirements before attempting to actually build the module.

Objects in this class provide an extension around L<ExtUtils::CBuilder> to
simplify the creation of a F<.c> file, compiling, linking and running it, to
test if a certain feature is present.

It may also be necessary to search for the correct library to link against,
or for the right include directories to find header files in. This class also
provides assistance here.

=cut

=head1 CONSTRUCTOR

=cut

=head2 new

   $cc = ExtUtils::CChecker->new( %args )

Returns a new instance of a C<ExtUtils::CChecker> object. Takes the following
named parameters:

=over 4

=item defines_to => PATH

If given, defined symbols will be written to a C preprocessor F<.h> file of
the given name, instead of by adding extra C<-DI<SYMBOL>> arguments to the
compiler flags.

=item quiet => BOOL

If given, sets the C<quiet> option to the underlying C<ExtUtils::CBuilder>
instance. If absent, defaults to enabled. To disable quietness, i.e. to print
more verbosely, pass a defined-but-false value, such as C<0>.

=item config => HASH

If given, passed through as the configuration of the underlying
C<ExtUtils::CBuilder> instance.

=back

=cut

sub new
{
   my $class = shift;
   my %args = @_;

   my $quiet = 1;
   $quiet = 0 if defined $args{quiet} and !$args{quiet};

   my $cb = ExtUtils::CBuilder->new(
      quiet  => $quiet,
      config => $args{config},
   );

   return bless {
      cb  => $cb,
      seq => 0,

      defines_to => $args{defines_to},

      include_dirs         => [],
      extra_compiler_flags => [],
      extra_linker_flags   => [],
   }, $class;
}

=head1 METHODS

=cut

=head2 include_dirs

   $dirs = $cc->include_dirs

Returns the currently-configured include directories in an ARRAY reference.

=cut

sub include_dirs
{
   my $self = shift;
   # clone it just so caller can't modify ours
   return [ @{ $self->{include_dirs} } ];
}

=head2 extra_compiler_flags

   $flags = $cc->extra_compiler_flags

Returns the currently-configured extra compiler flags in an ARRAY reference.

=cut

sub extra_compiler_flags
{
   my $self = shift;
   # clone it just so caller can't modify ours
   return [ @{ $self->{extra_compiler_flags} } ];
}

=head2 extra_linker_flags

   $flags = $cc->extra_linker_flags

Returns the currently-configured extra linker flags in an ARRAY reference.

=cut

sub extra_linker_flags
{
   my $self = shift;
   # clone it just so caller can't modify ours
   return [ @{ $self->{extra_linker_flags} } ];
}

=head2 push_include_dirs

   $cc->push_include_dirs( @dirs )

Adds more include directories

=cut

sub push_include_dirs
{
   my $self = shift;
   push @{ $self->{include_dirs} }, @_;
}

=head2 push_extra_compiler_flags

   $cc->push_extra_compiler_flags( @flags )

Adds more compiler flags

=cut

sub push_extra_compiler_flags
{
   my $self = shift;
   push @{ $self->{extra_compiler_flags} }, @_;
}

=head2 push_extra_linker_flags

   $cc->push_extra_linker_flags( @flags )

Adds more linker flags

=cut

sub push_extra_linker_flags
{
   my $self = shift;
   push @{ $self->{extra_linker_flags} }, @_;
}

sub cbuilder
{
   my $self = shift;
   return $self->{cb};
}

sub compile
{
   my $self = shift;
   my %args = @_;

   $args{include_dirs} = [ map { defined $_ ? @$_ : () } $self->{include_dirs}, $args{include_dirs} ];
   $args{extra_compiler_flags} = [ map { defined $_ ? @$_ : () } $self->{extra_compiler_flags}, $args{extra_compiler_flags} ];

   $self->cbuilder->compile( %args );
}

sub link_executable
{
   my $self = shift;
   my %args = @_;

   $args{extra_linker_flags} = [ map { defined $_ ? @$_ : () } $self->{extra_linker_flags}, $args{extra_linker_flags} ];

   $self->cbuilder->link_executable( %args );
}

sub fail
{
   my $self = shift;
   my ( $diag ) = @_;

   my $message = defined $diag ? "OS unsupported - $diag\n" : "OS unsupported\n";
   die $message;
}

sub define
{
   my $self = shift;
   my ( $symbol ) = @_;

   if( $self->{defines_to} ) {
      unless( $self->{defines_fh} ) {
         open $self->{defines_fh}, ">", $self->{defines_to} or croak "Cannot open $self->{defines_to} for writing - $!";
         $self->{defines_fh}->autoflush(1);
      }

      $self->{defines_fh}->print( "#define $symbol /**/\n" );
   }
   else {
      $self->push_extra_compiler_flags( "-D$symbol" );
   }
}

=head2 try_compile_run

   $success = $cc->try_compile_run( %args )

   $success = $cc->try_compile_run( $source )

Try to compile, link, and execute a C program whose source is given. Returns
true if the program compiled and linked, and exited successfully. Returns
false if any of these steps fail.

Takes the following named arguments. If a single argument is given, that is
taken as the source string.

=over 4

=item source => STRING

The source code of the C program to try compiling, building, and running.

=item extra_compiler_flags => ARRAY

Optional. If specified, pass extra flags to the compiler.

=item extra_linker_flags => ARRAY

Optional. If specified, pass extra flags to the linker.

=item define => STRING

Optional. If specified, then the named symbol will be defined if the program
ran successfully. This will either on the C compiler commandline (by passing
an option C<-DI<SYMBOL>>), or in the C<defines_to> file.

=back

=cut

sub try_compile_run
{
   my $self = shift;
   my %args = ( @_ == 1 ) ? ( source => $_[0] ) : @_;

   defined $args{source} or croak "Expected 'source'";

   my $seq = $self->{seq}++;

   my $test_source = "test-$$-$seq.c";

   open( my $test_source_fh, "> $test_source" ) or die "Cannot write $test_source - $!";

   print $test_source_fh $args{source};

   close $test_source_fh;

   my %compile_args = (
      source => $test_source,
   );

   $compile_args{include_dirs} = $args{include_dirs} if exists $args{include_dirs};
   $compile_args{extra_compiler_flags} = $args{extra_compiler_flags} if exists $args{extra_compiler_flags};

   my $test_obj = eval { $self->compile( %compile_args ) };

   unlink $test_source;

   if( not defined $test_obj ) {
      return 0;
   }

   my %link_args = (
      objects => $test_obj,
   );

   $link_args{extra_linker_flags} = $args{extra_linker_flags} if exists $args{extra_linker_flags};

   my $test_exe = eval { $self->link_executable( %link_args ) };

   unlink $test_obj;

   if( not defined $test_exe ) {
      return 0;
   }

   if( system( "./$test_exe" ) != 0 ) {
      unlink $test_exe;
      return 0;
   }

   unlink $test_exe;

   $self->define( $args{define} ) if defined $args{define};

   return 1;
}

=head2 assert_compile_run

   $cc->assert_compile_run( %args )

Calls C<try_compile_run>. If it fails, die with an C<OS unsupported> message.
Useful to call from F<Build.PL> or F<Makefile.PL>.

Takes one extra optional argument:

=over 4

=item diag => STRING

If present, this string will be appended to the failure message if one is
generated. It may provide more useful information to the user on why the OS is
unsupported.

=back

=cut

sub assert_compile_run
{
   my $self = shift;
   my %args = @_;

   my $diag = delete $args{diag};
   $self->try_compile_run( %args ) or $self->fail( $diag );
}

=head2 try_find_cflags_for

   $success = $cc->try_find_cflags_for( %args )

I<Since version 0.11.>

Try to compile, link and execute the given source, using extra compiler flags.

When a usable combination is found, the flags are stored in the object for use
in further compile operations, or returned by C<extra_compiler_flags>. The
method then returns true.

If no usable combination is found, it returns false.

Takes the following extra arguments:

=over 4

=item source => STRING

Source code to compile

=item cflags => ARRAY of ARRAYs

Gives a list of sets of flags. Each set of flags should be strings in its own
array reference.

=item define => STRING

Optional. If specified, then the named symbol will be defined if the program
ran successfully.

=back

=cut

sub try_find_cflags_for
{
   my $self = shift;
   my %args = @_;

   ref( my $cflags = $args{cflags} ) eq "ARRAY" or croak "Expected 'cflags' as ARRAY ref";

   foreach my $f ( @$cflags ) {
      ref $f eq "ARRAY" or croak "Expected 'cflags' element as ARRAY ref";

      $self->try_compile_run( %args, extra_compiler_flags => $f ) or next;

      $self->push_extra_compiler_flags( @$f );

      return 1;
   }

   return 0;
}

=head2 try_find_include_dirs_for

   $success = $cc->try_find_include_dirs_for( %args )

Try to compile, link and execute the given source, using extra include
directories.

When a usable combination is found, the directories required are stored in the
object for use in further compile operations, or returned by C<include_dirs>.
The method then returns true.

If no a usable combination is found, it returns false.

Takes the following arguments:

=over 4

=item source => STRING

Source code to compile

=item dirs => ARRAY of ARRAYs

Gives a list of sets of dirs. Each set of dirs should be strings in its own
array reference.

=item define => STRING

Optional. If specified, then the named symbol will be defined if the program
ran successfully. This will either on the C compiler commandline (by passing
an option C<-DI<SYMBOL>>), or in the C<defines_to> file.

=back

=cut

sub try_find_include_dirs_for
{
   my $self = shift;
   my %args = @_;

   ref( my $dirs = $args{dirs} ) eq "ARRAY" or croak "Expected 'dirs' as ARRAY ref";

   foreach my $d ( @$dirs ) {
      ref $d eq "ARRAY" or croak "Expected 'dirs' element as ARRAY ref";

      $self->try_compile_run( %args, include_dirs => $d ) or next;

      $self->push_include_dirs( @$d );

      return 1;
   }

   return 0;
}

=head2 try_find_libs_for

   $success = $cc->try_find_libs_for( %args )

Try to compile, link and execute the given source, when linked against a
given set of extra libraries.

When a usable combination is found, the libraries required are stored in the
object for use in further link operations, or returned by
C<extra_linker_flags>. The method then returns true.

If no usable combination is found, it returns false.

Takes the following arguments:

=over 4

=item source => STRING

Source code to compile

=item libs => ARRAY of STRINGs

Gives a list of sets of libraries. Each set of libraries should be
space-separated.

=item define => STRING

Optional. If specified, then the named symbol will be defined if the program
ran successfully. This will either on the C compiler commandline (by passing
an option C<-DI<SYMBOL>>), or in the C<defines_to> file.

=back

=cut

sub try_find_libs_for
{
   my $self = shift;
   my %args = @_;

   ref( my $libs = $args{libs} ) eq "ARRAY" or croak "Expected 'libs' as ARRAY ref";

   foreach my $l ( @$libs ) {
      my @extra_linker_flags = map { "-l$_" } split m/\s+/, $l;

      $self->try_compile_run( %args, extra_linker_flags => \@extra_linker_flags ) or next;

      $self->push_extra_linker_flags( @extra_linker_flags );

      return 1;
   }

   return 0;
}

=head2 find_cflags_for

   $cc->find_cflags_for( %args )

=head2 find_include_dirs_for

   $cc->find_include_dirs_for( %args )

=head2 find_libs_for

   $cc->find_libs_for( %args )

Calls C<try_find_cflags_for>, C<try_find_include_dirs_for> or
C<try_find_libs_for> respectively. If it fails, die with an
C<OS unsupported> message.

Each method takes one extra optional argument:

=over 4

=item diag => STRING

If present, this string will be appended to the failure message if one is
generated. It may provide more useful information to the user on why the OS is
unsupported.

=back

=cut

foreach ( qw( find_cflags_for find_libs_for find_include_dirs_for ) ) {
   my $trymethod = "try_$_";

   my $code = sub {
      my $self = shift;
      my %args = @_;

      my $diag = delete $args{diag};
      $self->$trymethod( %args ) or $self->fail( $diag );
   };

   no strict 'refs';
   *$_ = $code;
}

=head2 extend_module_build

   $cc->extend_module_build( $build )

I<Since version 0.11.>

Sets the appropriate arguments into the given L<Module::Build> instance.

=cut

sub extend_module_build
{
   my $self = shift;
   my ( $build ) = @_;

   foreach my $key (qw( include_dirs extra_compiler_flags extra_linker_flags )) {
      my @vals = @{ $self->$key } or next;

      push @vals, @{ $build->$key };

      # Module::Build ->include_dirs wants an ARRAYref
      $build->$key( $key eq "include_dirs" ? [ @vals ] : @vals );
   }
}

=head2 new_module_build

   $mb = $cc->new_module_build( %args )

Construct and return a new L<Module::Build> object, preconfigured with the
C<include_dirs>, C<extra_compiler_flags> and C<extra_linker_flags> options
that have been configured on this object, by the above methods.

This is provided as a simple shortcut for the common use case, that a
F<Build.PL> file is using the C<ExtUtils::CChecker> object to detect the
required arguments to pass.

=cut

sub new_module_build
{
   my $self = shift;
   my %args = @_;

   require Module::Build;
   my $build = Module::Build->new( %args );

   $self->extend_module_build( $build );

   return $build;
}

=head1 EXAMPLES

=head2 Socket Libraries

Some operating systems provide the BSD sockets API in their primary F<libc>.
Others keep it in a separate library which should be linked against. The
following example demonstrates how this would be handled.

   use ExtUtils::CChecker;

   my $cc = ExtUtils::CChecker->new;

   $cc->find_libs_for(
      diag => "no socket()",
      libs => [ "", "socket nsl" ],
      source => q[
   #include <sys/socket.h>
   int main(int argc, char *argv) {
     int fd = socket(PF_INET, SOCK_STREAM, 0);
     if(fd < 0)
       return 1;
     return 0;
   }
   ] );

   $cc->new_module_build(
      module_name => "Your::Name::Here",
      requires => {
         'IO::Socket' => 0,
      },
      ...
   )->create_build_script;

By using the C<new_module_build> method, the detected C<extra_linker_flags>
value has been automatically passed into the new C<Module::Build> object.

=head2 Testing For Optional Features

Sometimes a function or ability may be optionally provided by the OS, or you
may wish your module to be useable when only partial support is provided,
without requiring it all to be present. In these cases it is traditional to
detect the presence of this optional feature in the F<Build.PL> script, and
define a symbol to declare this fact if it is found. The XS code can then use
this symbol to select between differing implementations. For example, the
F<Build.PL>:

   use ExtUtils::CChecker;

   my $cc = ExtUtils::CChecker->new;

   $cc->try_compile_run(
      define => "HAVE_MANGO",
      source => <<'EOF' );
   #include <mango.h>
   #include <unistd.h>
   int main(void) {
     if(mango() != 0)
       exit(1);
     exit(0);
   }
   EOF

   $cc->new_module_build(
      ...
   )->create_build_script;

If the C code compiles and runs successfully, and exits with a true status,
the symbol C<HAVE_MANGO> will be defined on the compiler commandline. This
allows the XS code to detect it, for example

   int
   mango()
     CODE:
   #ifdef HAVE_MANGO
       RETVAL = mango();
   #else
       croak("mango() not implemented");
   #endif
     OUTPUT:
       RETVAL

This module will then still compile even if the operating system lacks this
particular function. Trying to invoke the function at runtime will simply
throw an exception.

=head2 Linux Kernel Headers

Operating systems built on top of the F<Linux> kernel often share a looser
association with their kernel version than most other operating systems. It
may be the case that the running kernel is newer, containing more features,
than the distribution's F<libc> headers would believe. In such circumstances
it can be difficult to make use of new socket options, C<ioctl()>s, etc..
without having the constants that define them and their parameter structures,
because the relevant header files are not visible to the compiler. In this
case, there may be little choice but to pull in some of the kernel header
files, which will provide the required constants and structures.

The Linux kernel headers can be found using the F</lib/modules> directory. A
fragment in F<Build.PL> like the following, may be appropriate.

   chomp( my $uname_r = `uname -r` );

   my @dirs = (
      [],
      [ "/lib/modules/$uname_r/source/include" ],
   );

   $cc->find_include_dirs_for(
      diag => "no PF_MOONLASER",
      dirs => \@dirs,
      source => <<'EOF' );
   #include <sys/socket.h>
   #include <moon/laser.h>
   int family = PF_MOONLASER;
   struct laserwl lwl;
   int main(int argc, char *argv[]) {
     return 0;
   }
   EOF

This fragment will first try to compile the program as it stands, hoping that
the F<libc> headers will be sufficient. If it fails, it will then try
including the kernel headers, which should make the constant and structure
visible, allowing the program to compile.

=head2 Creating an C<#include> file

Sometimes, rather than setting defined symbols on the compiler commandline, it
is preferrable to have them written to a C preprocessor include (F<.h>) file.
This may be beneficial for cross-platform portability concerns, as not all C
compilers may take extra C<-D> arguments on the command line, or platforms may
have small length restrictions on the length of a command line.

   use ExtUtils::CChecker;

   my $cc = ExtUtils::CChecker->new(
      defines_to => "mymodule-config.h",
   );

   $cc->try_compile_run(
      define => "HAVE_MANGO",
      source => <<'EOF' );
   #include <mango.h>
   #include <unistd.h>
   #include "mymodule-config.h"
   int main(void) {
     if(mango() != 0)
       exit(1);
     exit(0);
   }
   EOF

Because the F<mymodule-config.h> file is written and flushed after every
define operation, it will still be useable in later C fragments to test for
features detected in earlier ones.

It is suggested not to name the file simply F<config.h>, as the core of Perl
itself has a file of that name containing its own compile-time detected
configuration. A confusion between the two could lead to surprising results.

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
