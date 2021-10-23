#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Print the names of all user defined subvols separated by newlines.

package App::Commands::PrintSubvols;

use strict;
use warnings;
use 5.010;

use App::Base;
use App::Config;

sub die_usage {
    die "usage: yabsm print-subvols\n";
}

sub main {

    if (@_) { die_usage() }

    my $config_ref = App::Config::read_config();

    my @all_subvols = App::Base::all_subvols($config_ref);

    say for @all_subvols;

    return;
}

1;
