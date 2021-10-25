package App::FatPacker::Trace;

use strict;
use warnings FATAL => 'all';
use B ();

my $trace_file;
my %initial_inc;

sub import {
  my (undef, $file, @extras) = @_;

  $trace_file = $file || '>>fatpacker.trace';
  # For filtering out our own deps later.
  # (Not strictly required as these are core only and won't have packlists, but 
  # looks neater.)
  %initial_inc = %INC;

  # Use any extra modules specified
  eval "use $_" for @extras;

  B::minus_c;
}

CHECK {
  return unless $trace_file; # not imported

  open my $trace, $trace_file
      or die "Couldn't open $trace_file to trace to: $!";

  for my $inc (keys %INC) {
    next if exists $initial_inc{$inc};
    next unless defined($INC{$inc}) and $INC{$inc} =~ /\Q${inc}\E\Z/;
    print $trace "$inc\n";
  }
}

1;

__END__

=head1 NAME

App::FatPacker::Trace - Tracing module usage using compilation checking

=head1 SYNOPSIS

    # open STDERR for writing
    # will be like: open my $fh, '>', '&STDERR'...
    perl -MApp::FatPacker::Trace=>&STDERR myscript.pl

    # open a file for writing
    # will be like: open my $fh, '>>', 'fatpacker.trace'
    perl -MApp::FatPacker::Trace=>>fatpacker.trace myscript.pl

=head1 DESCRIPTION

This module allows tracing the modules being used by your code. It does that
using clever trickery using the C<import> method, the C<CHECK> block and
L<B>'s C<minus_c> function.

When App::FatPacker::Trace is being used, the import() method will call
C<B::minus_c> in order to set up the global compilation-only flag perl
(the interpreter) has. This will prevent any other code from being run.

Then in the C<CHECK> block which is reached at the end of the compilation
phase (see L<perlmod>), it will gather all modules that have been loaded,
using C<%INC>, and will write it to a file or to STDERR, determined by
parameters sent to the C<import> method.

=head1 METHODS

=head2 import

This method gets run when you just load L<App::FatPacker::Trace>. It will
note the current C<%INC> and will set up the output to be written to, and
raise the compilation-only flag, which will prevent anything from being
run past that point. This flag cannot be unset, so this is most easily run
from the command line as such:

    perl -MApp::FatPacker::Trace [...]

You can control the parameters to the import using an equal sign, as such:

    # send the parameter "hello"
    perl -MApp::FatPacker::Trace=hello [...]

    # send the parameter ">&STDERR"
    perl -MApp::FatPacker::Trace=>&STDERR [...]

The import method accepts a first parameter telling it which output to open
and how. These are both sent in a single parameter.

    # append to mytrace.txt
    perl -MApp::FatPacker::Trace=>>mytrace.txt myscript.pl

    # write to STDERR
    perl -MApp::FatPacker::Trace=>&STDERR myscript.pl

The import method accepts additional parameters of extra modules to load.
It will then add these modules to the trace. This is helpful if you want
to explicitly indicate additional modules to trace, even if they aren't
used in your script. Perhaps you're conditionally using them, perhaps
they're for additional features, perhaps they're loaded lazily, whatever
the reason.

    # Add Moo to the trace, even if you don't trace it in myscript.pl
    perl -MApp::FatPacker::Trace=>&STDERR,Moo myscript.pl

