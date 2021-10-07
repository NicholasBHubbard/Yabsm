#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Print all the cronjob strings to stdout that would be written to
#  /etc/crontab if the update-crontab command was used.

package Yabsm::PrintCrons;

use strict;
use warnings;
use 5.010;

use lib '..';
use Base;
use Yabsmrc;

use Carp;

sub die_usage {
    say 'Usage: yabsm print-crons';
    exit 1;
}

sub main {

    if (@_) { die_usage() }

    my $config_ref = Yabsmrc::read_config();

    my @crons = Base::generate_cron_strings($config_ref);

    say for @crons;

    return;
}

1;
