#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT
#
#  A valid remote backup config is setup so the root user can connect
#  to the remote host and run btrfs with sudo without having to enter
#  any passwords.

package App::Commands::TestRemoteBackupConfig;

use strict;
use warnings;
use v5.16.3;

# located using lib::relative in yabsm.pl
use App::Base;
use App::Config;

sub die_usage {
    die "usage: yabsm test-remote-backup <BACKUP>\n";
}

sub main {

    die "error: permission denied\n" if $<;

    my $backup = shift // die_usage();

    die_usage() if @_;

    my $config_ref = App::Config::read_config();

    if (not App::Base::is_backup($config_ref, $backup)) {
	die "error: no such defined backup '$backup'\n";
    }

    if (App::Base::is_local_backup($config_ref, $backup)) {
	die "error: backup '$backup' is a local backup\n";
    }

    # new_ssh_connection() will kill the program if a passwordless
    # connection cannot be established.
    my $ssh = App::Base::new_ssh_connection();

    if (my $out = $ssh->system('sudo -n btrfs --help 2>&1 1>/dev/null')) {
        die "$out\n";
    }

    say 'all good';

    return;
}

1;
