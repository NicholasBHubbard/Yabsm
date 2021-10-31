#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Perform the bootstrap phase of a btrfs incremental backup.

package Yabsm::Commands::BackupBootstrap;

use strict;
use warnings;
use v5.16.3;

# located using lib::relative in yabsm.pl
use Yabsm::Base;
use Yabsm::Config;

sub die_usage {
    die "usage: yabsm bootstrap-backup <BACKUP>\n";
}

sub main {

    die "yabsm: error: permission denied\n" if $<;

    my $backup = shift // die_usage();

    die_usage() if @_;

    my $config_ref = Yabsm::Config::read_config();

    if (not Yabsm::Base::is_backup($config_ref, $backup)) {
	die "yabsm: error: no such defined backup '$backup'\n";
    }

    Yabsm::Base::do_backup_bootstrap($config_ref, $backup);

    return;
}

1;
