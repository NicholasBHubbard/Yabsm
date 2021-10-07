#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Print the names of all subvols's defined in /etc/yabsmrc.

package Yabsm::PrintSubvols;

use strict;
use warnings;
use 5.010;

use lib '..';
use Base;
use Yabsmrc;

sub die_usage {
    say 'Usage: yabsm print-subvols';
    exit 1;
}

sub main {

    if (@_) { die_usage() }

    my $config_ref = Yabsmrc::read_config();

    my @all_subvols = Base::all_subvols($config_ref);

    say for @all_subvols;

    return;
}

1;
