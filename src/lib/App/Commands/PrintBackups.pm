#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Print the names of all user defined backups separated by newlines.

package App::Commands::PrintBackups;

use strict;
use warnings;
use 5.010;

use App::Base;
use App::Config;

sub die_usage {
    die "usage: yabsm print-backups\n";
}

sub main {

    if (@_) { die_usage() }

    my $config_ref = App::Config::read_config();

    my @all_backups = App::Base::all_backups($config_ref);

    say for @all_backups;

    return;
}

1;
