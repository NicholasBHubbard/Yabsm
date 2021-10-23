#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  TODO

package App::Commands::UpdateEtcCrontab;

use strict;
use warnings;
use 5.010;

use App::Base;
use App::Config;

sub die_usage {
    die "usage: yabsm update-crontab\n";
}

sub main {

    die "error: permission denied\n" if $<;

    if (@_) { die_usage() }

    my $config_ref = App::Config::read_config();

    App::Base::update_etc_crontab($config_ref);

    return;
}

1;
