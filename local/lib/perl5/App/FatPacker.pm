package App::FatPacker;

use strict;
use warnings FATAL => 'all';
use 5.008001;
use Getopt::Long;
use Cwd qw(cwd);
use File::Find qw(find);
use File::Spec::Functions qw(
  catdir splitpath splitdir catpath rel2abs abs2rel
);
use File::Spec::Unix;
use File::Copy qw(copy);
use File::Path qw(mkpath rmtree);
use B qw(perlstring);

our $VERSION = '0.010008'; # v0.10.8

$VERSION = eval $VERSION;

sub call_parser {
  my $self = shift;
  my ($args, $options) = @_;

  local *ARGV = [ @{$args} ];
  $self->{option_parser}->getoptions(@$options);

  return [ @ARGV ];
}

sub lines_of {
  map +(chomp,$_)[1], do { local @ARGV = ($_[0]); <> };
}

sub stripspace {
  my ($text) = @_;
  $text =~ /^(\s+)/ && $text =~ s/^$1//mg;
  $text;
}

sub import {
  $_[1] && $_[1] eq '-run_script'
    and return shift->new->run_script;
}

sub new {
  bless {
    option_parser => Getopt::Long::Parser->new(
      config => [ qw(require_order pass_through bundling no_auto_abbrev) ]
    ),
  }, $_[0];
}

sub run_script {
  my ($self, $args) = @_;
  my @args = $args ? @$args : @ARGV;
  (my $cmd = shift @args || 'help') =~ s/-/_/g;

  if (my $meth = $self->can("script_command_${cmd}")) {
    $self->$meth(\@args);
  } else {
    die "No such command ${cmd}";
  }
}

sub script_command_help {
  print "Try `perldoc fatpack` for how to use me\n";
}

sub script_command_pack {
  my ($self, $args) = @_;

  my @modules = split /\r?\n/, $self->trace(args => $args);
  my @packlists = $self->packlists_containing(\@modules);

  my $base = catdir(cwd, 'fatlib');
  $self->packlists_to_tree($base, \@packlists);

  my $file = shift @$args;
  print $self->fatpack_file($file);
}

sub script_command_trace {
  my ($self, $args) = @_;

  $args = $self->call_parser($args => [
    'to=s' => \my $file,
    'to-stderr' => \my $to_stderr,
    'use=s' => \my @additional_use
  ]);

  die "Can't use to and to-stderr on same call" if $file && $to_stderr;

  $file ||= 'fatpacker.trace';

  if (!$to_stderr and -e $file) {
    unlink $file or die "Couldn't remove old trace file: $!";
  }
  my $arg = do {
    if ($to_stderr) {
      ">&STDERR"
    } elsif ($file) {
      ">>${file}"
    }
  };

  $self->trace(
    use => \@additional_use,
    args => $args,
    output => $arg,
  );
}

sub trace {
  my ($self, %opts) = @_;

  my $output = $opts{output};
  my $trace_opts = join ',', $output||'>&STDOUT', @{$opts{use}||[]};

  local $ENV{PERL5OPT} = join ' ',
    ($ENV{PERL5OPT}||()), '-MApp::FatPacker::Trace='.$trace_opts;

  my @args = @{$opts{args}||[]};

  if ($output) {
    # user specified output target, JFDI
    system $^X, @args;
    return;
  } else {
    # no output target specified, slurp
    open my $out_fh, "$^X @args |";
    return do { local $/; <$out_fh> };
  }
}

sub script_command_packlists_for {
  my ($self, $args) = @_;
  foreach my $pl ($self->packlists_containing($args)) {
    print "${pl}\n";
  }
}

sub packlists_containing {
  my ($self, $targets) = @_;
  my @targets;
  {
    local @INC = ('lib', @INC);
    foreach my $t (@$targets) {
      unless (eval { require $t; 1}) {
        warn "Failed to load ${t}: $@\n"
            ."Make sure you're not missing a packlist as a result\n";
        next;
      }
      push @targets, $t;
    }
  }
  my @search = grep -d $_, map catdir($_, 'auto'), @INC;
  my %pack_rev;
  find({
    no_chdir => 1,
    wanted => sub {
      return unless /[\\\/]\.packlist$/ && -f $_;
      $pack_rev{$_} = $File::Find::name for lines_of $File::Find::name;
    },
  }, @search);
  my %found; @found{map +($pack_rev{Cwd::abs_path($INC{$_})}||()), @targets} = ();
  sort keys %found;
}

sub script_command_tree {
  my ($self, $args) = @_;
  my $base = catdir(cwd,'fatlib');
  $self->packlists_to_tree($base, $args);
}

sub packlists_to_tree {
  my ($self, $where, $packlists) = @_;
  rmtree $where;
  mkpath $where;
  foreach my $pl (@$packlists) {
    my ($vol, $dirs, $file) = splitpath $pl;
    my @dir_parts = splitdir $dirs;
    my $pack_base;
    PART: foreach my $p (0 .. $#dir_parts) {
      if ($dir_parts[$p] eq 'auto') {
        # $p-2 normally since it's <wanted path>/$Config{archname}/auto but
        # if the last bit is a number it's $Config{archname}/$version/auto
        # so use $p-3 in that case
        my $version_lib = 0+!!($dir_parts[$p-1] =~ /^[0-9.]+$/);
        $pack_base = catpath $vol, catdir @dir_parts[0..$p-(2+$version_lib)];
        last PART;
      }
    }
    die "Couldn't figure out base path of packlist ${pl}" unless $pack_base;
    foreach my $source (lines_of $pl) {
      # there is presumably a better way to do "is this under this base?"
      # but if so, it's not obvious to me in File::Spec
      next unless substr($source,0,length $pack_base) eq $pack_base;
      my $target = rel2abs( abs2rel($source, $pack_base), $where );
      my $target_dir = catpath((splitpath $target)[0,1]);
      mkpath $target_dir;
      copy $source => $target;
    }
  }
}

sub script_command_file {
  my ($self, $args) = @_;
  my $file = shift @$args;
  print $self->fatpack_file($file);
}

sub fatpack_file {
  my ($self, $file) = @_;

  my $shebang = "";
  my $script = "";
  if ( defined $file and -r $file ) {
    ($shebang, $script) = $self->load_main_script($file);
  }

  my @dirs = $self->collect_dirs();
  my %files;
  $self->collect_files($_, \%files) for @dirs;

  return join "\n", $shebang, $self->fatpack_code(\%files), $script;
}

# This method can be overload in sub classes
# For example to skip POD
sub load_file {
  my ($self, $file) = @_;
  my $content = do {
    local (@ARGV, $/) = ($file);
    <>
  };
  close ARGV;
  return $content;
}

sub collect_dirs {
  my ($self) = @_;
  my $cwd = cwd;
  return grep -d, map rel2abs($_, $cwd), ('lib','fatlib');
}

sub collect_files {
  my ($self, $dir, $files) = @_;
  find(sub {
    return unless -f $_;
    !/\.pm$/ and warn "File ${File::Find::name} isn't a .pm file - can't pack this -- if you hoped we were going to, things may not be what you expected later\n" and return;
    $files->{File::Spec::Unix->abs2rel($File::Find::name,$dir)} =
      $self->load_file($File::Find::name);
  }, $dir);
}

sub load_main_script {
  my ($self, $file) = @_;
  open my $fh, "<", $file or die("Can't read $file: $!");
  my $shebang = <$fh>;
  my $script = join "", <$fh>;
  close $fh;
  unless ( index($shebang, '#!') == 0 ) {
    $script = $shebang . $script;
    $shebang = "";
  }
  return ($shebang, $script);
}

sub fatpack_start {
  return stripspace <<'  END_START';
    # This chunk of stuff was generated by App::FatPacker. To find the original
    # file's code, look for the end of this BEGIN block or the string 'FATPACK'
    BEGIN {
    my %fatpacked;
  END_START
}

sub fatpack_end {
  return stripspace <<'  END_END';
    s/^  //mg for values %fatpacked;

    my $class = 'FatPacked::'.(0+\%fatpacked);
    no strict 'refs';
    *{"${class}::files"} = sub { keys %{$_[0]} };

    if ($] < 5.008) {
      *{"${class}::INC"} = sub {
        if (my $fat = $_[0]{$_[1]}) {
          my $pos = 0;
          my $last = length $fat;
          return (sub {
            return 0 if $pos == $last;
            my $next = (1 + index $fat, "\n", $pos) || $last;
            $_ .= substr $fat, $pos, $next - $pos;
            $pos = $next;
            return 1;
          });
        }
      };
    }

    else {
      *{"${class}::INC"} = sub {
        if (my $fat = $_[0]{$_[1]}) {
          open my $fh, '<', \$fat
            or die "FatPacker error loading $_[1] (could be a perl installation issue?)";
          return $fh;
        }
        return;
      };
    }

    unshift @INC, bless \%fatpacked, $class;
  } # END OF FATPACK CODE
  END_END
}

sub fatpack_code {
  my ($self, $files) = @_;
  my @segments = map {
    (my $stub = $_) =~ s/\.pm$//;
    my $name = uc join '_', split '/', $stub;
    my $data = $files->{$_}; $data =~ s/^/  /mg; $data =~ s/(?<!\n)\z/\n/;
    '$fatpacked{'.perlstring($_).qq!} = '#line '.(1+__LINE__).' "'.__FILE__."\\"\\n".<<'${name}';\n!
    .qq!${data}${name}\n!;
  } sort keys %$files;

  return join "\n", $self->fatpack_start, @segments, $self->fatpack_end;
}

=encoding UTF-8

=head1 NAME

App::FatPacker - pack your dependencies onto your script file

=head1 SYNOPSIS

  $ fatpack pack myscript.pl >myscript.packed.pl

Or, with more step-by-step control:

  $ fatpack trace myscript.pl
  $ fatpack packlists-for `cat fatpacker.trace` >packlists
  $ fatpack tree `cat packlists`
  $ fatpack file myscript.pl >myscript.packed.pl

Each command is designed to be simple and self-contained so that you can modify
the input/output of each step as needed. See the documentation for the
L<fatpack> script itself for more information.

The programmatic API for this code is not yet fully decided, hence the 0.x
release version. Expect that to be cleaned up for 1.0.

=head1 CAVEATS

As dependency module code is copied into the resulting file as text, only
pure-perl dependencies can be packed, not compiled XS code.

The currently-installed dependencies to pack are found via F<.packlist> files,
which are generally only included in non-core distributions that were installed
by a CPAN installer. This is a feature; see L<fatpack/packlists-for> for
details. (a notable exception to this is FreeBSD, which, since its packaging
system is designed to work equivalently to a source install, does preserve
the packlist files)

=head1 SEE ALSO

L<article for Perl Advent 2012|http://www.perladvent.org/2012/2012-12-14.html>

L<pp> - PAR Packager, a much more complex architecture-dependent packer that
can pack compiled code and even a Perl interpreter

=head1 SUPPORT

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=App-FatPacker>
(or L<bug-App-FatPacker@rt.cpan.org|mailto:bug-App-FatPacker@rt.cpan.org>).

You can normally also obtain assistance on irc, in #toolchain on irc.perl.org.

=head1 AUTHOR

Matt S. Trout (mst) <mst@shadowcat.co.uk>

=head2 CONTRIBUTORS

miyagawa - Tatsuhiko Miyagawa (cpan:MIYAGAWA) <miyagawa@bulknews.net>

tokuhirom - MATSUNO★Tokuhiro (cpan:TOKUHIROM) <tokuhirom@gmail.com>

dg - David Leadbeater (cpan:DGL) <dgl@dgl.cx>

gugod - 劉康民 (cpan:GUGOD) <gugod@cpan.org>

t0m - Tomas Doran (cpan:BOBTFISH) <bobtfish@bobtfish.net>

sawyer - Sawyer X (cpan:XSAWYERX) <xsawyerx@cpan.org>

ether - Karen Etheridge (cpan:ETHER) <ether@cpan.org>

Mithaldu - Christian Walde (cpan:MITHALDU) <walde.christian@googlemail.com>

dolmen - Olivier Mengué (cpan:DOLMEN) <dolmen@cpan.org>

djerius - Diab Jerius (cpan:DJERIUS) <djerius@cpan.org>

haarg - Graham Knop (cpan:HAARG) <haarg@haarg.org>

grinnz - Dan Book (cpan:DBOOK) <dbook@cpan.org>

Many more people are probably owed thanks for ideas. Yet
another doc nit to fix.

=head1 COPYRIGHT

Copyright (c) 2010 the App::FatPacker L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.

=cut

1;

