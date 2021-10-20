#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

package App::Commands::TestRemoteBackupYabsmrc;

use strict;
use warnings;
use 5.010;

use App::Base;
use App::Config;

sub die_usage {
    die "usage: yabsm test-remote-backup <BACKUP>\n";
}

sub main {

    die "error: permission denied\n" if $<;

    my $backup = shift // die_usage();

    if (@_) { die_usage() }

    my $config_ref = App::Config::read_config();

    if (not App::Base::is_backup($config_ref, $backup)) {
	die "error: no such defined backup '$backup'\n";
    }

    if (App::Base::is_local_backup($config_ref, $backup)) {
	die "error: backup '$backup' is a local backup\n";
    }

    # we know that $backup is a remote backup

    # The program will die if the remote backup is not configure
    # properly.
    App::Base::test_remote_backup_config($config_ref, $backup);

    say 'all good';

    return;
}

1;
