#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

package Commands::UpdateEtcCrontab;

use strict;
use warnings;
use 5.010;

use lib '../lib';
use Base;
use Yabsmrc;

sub die_usage {
    say 'Usage: yabsm update-crontab';
    exit 1;
}

sub main {

    die "yabsm: error: permission denied\n" if $<;

    if (@_) { die_usage() }

    my $config_ref = Yabsmrc::read_config();

    Base::update_etc_crontab($config_ref);

    return;
}

1;
