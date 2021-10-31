#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Perform a single incremental backup. If the bootstrap phase has not 
#  been completed then perform then perform the bootstrap instead.

package Yabsm::Commands::IncrementalBackup;

use strict;
use warnings;
use v5.16.3;

# located using lib::relative in yabsm.pl
use Yabsm::Base;
use Yabsm::Config;

sub die_usage {
    die "usage: yabsm incremental-bootstrap <BACKUP>\n";
}

sub main {

    die "yabsm: error: permission denied\n" if $<;

    my $backup = shift // die_usage();

    die_usage() if @_;

    my $config_ref = Yabsm::Config::read_config();

    if (not Yabsm::Base::is_backup($config_ref, $backup)) {
	die "yabsm: error: no such defined backup '$backup'\n";
    }

    # do_backup() will perform the bootstrap phase if needed
    Yabsm::Base::do_backup($config_ref, $backup);

    return;
}

1;