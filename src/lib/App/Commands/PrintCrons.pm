#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Print all the cronjob strings to stdout, separated by newlines,
#  that would be written to /etc/crontab if the update-crontab command
#  was used.

package App::Commands::PrintCrons;

use strict;
use warnings;
use v5.16.3;

# located using lib::relative in yabsm.pl
use App::Base;
use App::Config;

use Carp;

sub die_usage {
    die "usage: yabsm print-crons\n";
}

sub main {

    die_usage() if @_;

    my $config_ref = App::Config::read_config();

    my @crons = App::Base::generate_cron_strings($config_ref);

    say for @crons;

    return;
}

1;
