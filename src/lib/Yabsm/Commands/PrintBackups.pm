#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Print the names of all user defined backups separated by newlines.

package Yabsm::Commands::PrintBackups;

use strict;
use warnings;
use v5.16.3;

# located using lib::relative in yabsm.pl
use Yabsm::Base;
use Yabsm::Config;

sub die_usage {
    die "usage: yabsm print-backups\n";
}

sub main {

    die_usage() if @_;

    my $config_ref = Yabsm::Config::read_config();

    my @all_backups = Yabsm::Base::all_backups($config_ref);

    say for @all_backups;

    return;
}

1;
