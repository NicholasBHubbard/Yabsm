#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

package Yabsm::TestRemoteBackupYabsmrc;

use strict;
use warnings;
use 5.010;

use lib '..';
use Base;
use Yabsmrc;

sub die_usage {
    say 'Usage: yabsm test-remote-backup <BACKUP>';
    exit 1;
}

sub main {

    die "yabsm: error: permission denied\n" if $<;

    my $backup = shift // die_usage();

    if (@_) { die_usage() }

    my $config_ref = Yabsmrc::read_config();

    if (not Base::is_backup($config_ref, $backup)) {
	die "yabsm: error: no such defined backup '$backup'\n";
    }

    if (Base::is_local_backup($config_ref, $backup)) {
	die "yabsm: error: backup '$backup' is a local backup\n";
    }

    # we know that $backup is a remote backup

    # The program will die if the remote backup is not configure
    # properly.
    Base::test_remote_backup_config($config_ref, $backup);

    say 'all good';

    return;
}

1;
