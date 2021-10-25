package lib::relative;

use strict;
use warnings;
use Cwd ();
use File::Basename ();
use File::Spec ();
use lib ();

our $VERSION = '1.000';

sub import {
  my ($class, @paths) = @_;
  my $file = (caller)[1];
  my $dir = -e $file ? File::Basename::dirname(Cwd::abs_path $file) : Cwd::getcwd;
  lib->import(map { File::Spec->file_name_is_absolute($_) ? $_ : File::Spec->catdir($dir, $_) } @paths);
}

1;

=head1 NAME

lib::relative - Add paths relative to the current file to @INC

=head1 SYNOPSIS

  # Path is relative to this file, not current working directory
  use lib::relative 'path/to/lib';
  use lib::relative '../../lib';
  
  # Add two lib paths, as in lib.pm
  use lib::relative 'foo', 'bar';
  
  # Absolute paths are passed through unchanged
  use lib::relative 'foo/baz', '/path/to/lib';
  
  # Equivalent code using core modules
  use Cwd ();
  use File::Basename ();
  use File::Spec ();
  use lib File::Spec->catdir(File::Basename::dirname(Cwd::abs_path __FILE__), 'path/to/lib');

=head1 DESCRIPTION

Adding a path to L<@INC|perlvar/"@INC"> to load modules from a local directory
may seem simple, but has a few common pitfalls to be aware of. Directly adding
a relative path to C<@INC> means that any later code that changes the current
working directory will change where modules are loaded from. This applies to
the C<.> path that used to be in C<@INC> by default until perl 5.26.0, or a
relative path added in code like C<use lib 'path/to/lib'>, and may be a
vulnerability if such a location is not supposed to be writable. Additionally,
the commonly used L<FindBin> module relies on interpreter state and the path to
the original script invoked by the perl interpreter, sometimes requiring
workarounds in uncommon cases like generated or embedded code. This module
proposes a more straightforward method: take a path relative to the
L<current file|perldata/"Special Literals">, absolutize it, and add it to
C<@INC>.

If this module is already available to be loaded, it can be used as with
L<lib>.pm, passing relative paths, which will be absolutized relative to the
current file then passed on to L<lib>. Multiple arguments will be separately
absolutized, and absolute paths will be passed on unchanged.

For cases where this module cannot be loaded beforehand, the last section of
the L</"SYNOPSIS"> can be copy-pasted into a file to perform the same task.

=head1 CAVEATS

Due to C<__FILE__> possibly being a path relative to the current working
directory, be sure to use C<lib::relative> or the equivalent code from
L</"SYNOPSIS"> as early as possible in the file. If a C<chdir> occurs before
this code, it will add the incorrect directory path.

All file paths are expected to be in a format appropriate to the current
operating system, e.g. C<..\\foo\\bar> on Windows. L<File::Spec/"catdir"> can
be used to form directory paths portably.

=head1 BUGS

Report any issues on the public bugtracker.

=head1 AUTHOR

Dan Book <dbook@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2017 by Dan Book.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=head1 SEE ALSO

L<lib>, L<FindBin>, L<Dir::Self>
