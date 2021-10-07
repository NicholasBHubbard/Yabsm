#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

package Yabsm::UpdateEtcCrontab;

use strict;
use warnings;
use 5.010;

use lib '..';
use Base;
use Yabsmrc;

sub die_usage {
    say 'Usage: yabsm update-crontab';
    exit 1;
}

sub main {

    if (@_) { die_usage() }

    my $config_ref = Yabsmrc::read_config();

    Base::update_etc_crontab($config_ref);

    return;
}

1;