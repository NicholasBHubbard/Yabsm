#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Print all the cronjob strings to stdout that would be written to
#  /etc/crontab if the update-crontab command was used.

package App::Commands::PrintCrons;

use strict;
use warnings;
use 5.010;

use App::Base;
use App::Config;

use Carp;

sub die_usage {
    die "usage: yabsm print-crons\n";
}

sub main {

    if (@_) { die_usage() }

    my $config_ref = App::Config::read_config();

    my @crons = App::Base::generate_cron_strings($config_ref);

    say for @crons;

    return;
}

1;
