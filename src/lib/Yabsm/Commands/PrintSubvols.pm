#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Print the names of all user defined subvols separated by newlines.

package Yabsm::Commands::PrintSubvols;

use strict;
use warnings;
use v5.16.3;

# located using lib::relative in yabsm.pl
use Yabsm::Base;
use Yabsm::Config;

sub die_usage {
    die "usage: yabsm print-subvols\n";
}

sub main {

    die_usage() if @_;

    my $config_ref = Yabsm::Config::read_config();

    my @all_subvols = Yabsm::Base::all_subvols($config_ref);

    say for @all_subvols;

    return;
}

1;