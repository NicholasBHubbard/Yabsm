#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  TODO

package App::Commands::UpdateEtcCrontab;

use strict;
use warnings;
use v5.16.3;

# located using lib::relative in yabsm.pl
use App::Base;
use App::Config;

sub die_usage {
    die "usage: yabsm update-crontab\n";
}

sub main {

    die "error: permission denied\n" if $<;

    die_usage() if @_;

    my $config_ref = App::Config::read_config();

    App::Base::update_etc_crontab($config_ref);

    return;
}

1;
