#  Author:    Nicholas Hubbard
#  Copyright: Nicholas Hubbard
#  License:   GPL_3
#  WWW:       https://github.com/NicholasBHubbard/Yabsm

#  This module contains the program's &main subroutine, and the developers
#  manual.

use strict;
use warnings;
use v5.34.0;

package App::Yabsm;

our $VERSION = '3.150.1';

use App::Yabsm::Command::Daemon;
use App::Yabsm::Command::Config;
use App::Yabsm::Command::Find;

sub usage {
    return <<'END_USAGE';
usage: yabsm [--help] [--version] [<COMMAND> <ARGS>]

See '$ man yabsm' for a detailed overview.

Commands:

  <daemon|d> [--help] [start] [stop] [restart] [status] [init]

  <config|c> [--help] [check ?file] [ssh-check <SSH_BACKUP>] [ssh-key]
             [yabsm-user-home] [yabsm_dir] [subvols] [snaps] [ssh_backups]
             [local_backups] [backups]

  <find|f>   [--help] [<SNAP|SSH_BACKUP|LOCAL_BACKUP> <QUERY>]

END_USAGE
}

sub main {

    # This is the toplevel subroutine of Yabsm. It is invoked directly from
    # bin/yabsm with @ARGV as its args.

    my $cmd = shift @_ or die usage();

    my @args = @_;

    if ($cmd =~ /^(-h|--help)$/) { print usage() and exit 0 }
    if ($cmd eq '--version')     { say $VERSION  and exit 0 }

    # Provide user with command abbreviations
    if    ($cmd eq 'd') { $cmd = 'daemon' }
    elsif ($cmd eq 'c') { $cmd = 'config' }
    elsif ($cmd eq 'f') { $cmd = 'find'   }

    # All 3 subcommands have their own &main
    if    ($cmd eq 'daemon') { $cmd = \&App::Yabsm::Command::Daemon::main }
    elsif ($cmd eq 'config') { $cmd = \&App::Yabsm::Command::Config::main }
    elsif ($cmd eq 'find'  ) { $cmd = \&App::Yabsm::Command::Find::main   }
    else {
        die usage();
    }

    $cmd->(@args);

    exit 0;
}

1;

__END__

=pod

This is the developers manual for Yabsm. The user manual can be found
L<here|https://metacpan.org/dist/App-Yabsm/view/bin/yabsm>.

=head1 Developers

=head3 Dependencies

=over 4

=item *

Perl >= 5.34.0

=item *

OpenSSH (client)

=item *

btrfs-progs

=item *

sudo

=back

=head3 Packaging

Yabsm is distributed as a App::FatPacker fatpacked script. This means that for
all packaging purposes it has zero CPAN dependencies. The test suite however
depends on Test::Exception, so it will be needed if you want to run the test
suite at install time (which should not be necessary).

This distribution includes the App::Yabsm module (this file). This module is not
necessary for yabsm to run (due to fatpacking), so it should be removed from
packages.

Yabsm runs as a cron-style daemon that is meant to be started at boot time. An
example sysvinit-style init script is provided in C</examples/rc.yabsmd>, and an
example systemd service is provided in C</examples/yabsmd.service>.

An example configuration is provided in C</examples/yabsm.conf.example>. It
would be helpful to the user if this file was installed to
C</etc/yabsm.conf.example>.

=head3 Versioning

Yabsm uses a semantic versioning scheme (MAJOR.MINOR.PATCH). The MAJOR version
is upgraded if we make any change that breaks backwards compatibility. The MINOR
version is upgraded if functionality is added that does not break backwards
compatibility. The PATCH version is upgraded if there is a bug fix, or an
upgrade is made to one of the fatpacked CPAN dependencies.

=head3 Releasing to CPAN

Here are the general steps for a CPAN release of App::Yabsm. This should be done
from L<Yabsm's git repo|https://github.com/NicholasBHubbard/yabsm>.

=over 4

=item *

Make sure the C<$VERSION> variable is updated in C</lib/App/Yabsm.pm>.

=item *

Make sure C</Changes> lists all relevant changes since the previous version, and
denotes todays date next to the version to be released.

=item *

Make sure C</cpanfile> lists all dependencies (with specific versions) that
need to be fatpacked.

=item *

Install all the modules in C</cpanfile>: C<$ cpanm --install-deps .>

=item *

Fatpack C<bin/yabsm-unpacked> with App::FatPacker: C<$ fatpack pack bin/yabsm-unpacked E<gt> bin/yabsm>.

=item *

Make the dist: C<$ perl Makefile.PL; make; make test; make dist>.

=item *

Carefully examine the dist to make sure everything looks ok.

=item *

Upload to CPAN: C<$ cpan-upload -u $PAUSE_USERNAME App-Yabsm-$VERSION.tar.gz>.

=back

=head1 Author

Nicholas Hubbard <nicholashubbard@posteo.net>

=head1 Copyright

Copyright (c) 2022-2023 by Nicholas Hubbard (nicholashubbard@posteo.net)

=head1 License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with App-Yabsm. If not, see http://www.gnu.org/licenses/.

=cut
