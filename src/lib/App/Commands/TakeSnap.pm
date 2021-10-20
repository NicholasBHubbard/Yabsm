#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

package App::Commands::TakeSnap;

use strict;
use warnings;
use 5.010;

use App::Base;
use App::Config;

sub die_usage {
    die "usage: yabsm take-snap <SUBVOL> <QUERY>\n";
}

sub main {

    die "error: permission denied\n" if $<;

    my $subvol    = shift // die_usage();
    my $timeframe = shift // die_usage();

    if (@_) { die_usage() }

    my $config_ref = App::Config::read_config();

    if (not App::Base::is_subvol($config_ref, $subvol)) {
	die "error: no such defined subvol '$subvol'\n";
    }

    if (not App::Base::is_subvol_timeframe($timeframe)) {
	die "error: '$timeframe' is not a subvol timeframe\n";
    }

    if (not App::Base::timeframe_want($config_ref, $subvol, $timeframe)) {
	die "error: subvol '$subvol' is not taking '$timeframe' snapshots\n";
    }

    App::Base::initialize_directories($config_ref);

    App::Base::take_new_snapshot($config_ref, $subvol, $timeframe);
    App::Base::delete_old_snapshots($config_ref, $subvol, $timeframe);

    return;
}

1;
