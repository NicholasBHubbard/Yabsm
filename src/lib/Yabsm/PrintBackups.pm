#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Print the names of all backup's defined in /etc/yabsmrc.

package Yabsm::PrintBackups;

use strict;
use warnings;
use 5.010;

use lib '..';
use Base;
use Yabsmrc;

sub die_usage {
    say 'Usage: yabsm print-backups';
    exit 1;
}

sub main {

    if (@_) { die_usage() }

    my $config_ref = Yabsmrc::read_config();

    my @all_backups = Base::all_backups($config_ref);

    say for @all_backups;

    return;
}

1;
