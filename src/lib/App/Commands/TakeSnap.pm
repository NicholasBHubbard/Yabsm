#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Take a single readonly TIMEFRAME snapshot for a user defined SUBVOL
#  then delete the appropiate snapshot(s). If the number of existing
#  snapshots is yet to exceed the number of snapshots to be kept then
#  no snapshots are deleted. If there is one more existing snapshot
#  then what should be be kept (the most common scenario because we
#  just took a snapshot) then we delete the oldest existing
#  snapshot. The final scenario is that the user changed their config
#  to keep less snapshots than they were keeping prior in which case
#  we repeatedly delete the oldest snapshot until the number of
#  existing snapshots is equal to the number of snapshots that should
#  be kept.

package App::Commands::TakeSnap;

use strict;
use warnings;
use 5.010;

use App::Base;
use App::Config;

sub die_usage {
    die "usage: yabsm take-snap <SUBVOL> <TIMEFRAME>\n";
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
