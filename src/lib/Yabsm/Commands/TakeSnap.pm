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

package Yabsm::Commands::TakeSnap;

use strict;
use warnings;
use v5.16.3;

# located using lib::relative in yabsm.pl
use Yabsm::Base;
use Yabsm::Config;

sub die_usage {
    die "usage: yabsm take-snap <SUBVOL> <TIMEFRAME>\n";
}

sub main {

    die "yabsm: error: permission denied\n" if $<;

    my $subvol    = shift // die_usage();
    my $timeframe = shift // die_usage();

    die_usage() if @_;

    my $config_ref = Yabsm::Config::read_config();

    if (not Yabsm::Base::is_subvol($config_ref, $subvol)) {
	die "yabsm: error: no such defined subvol '$subvol'\n";
    }

    if (not Yabsm::Base::is_subvol_timeframe($timeframe)) {
	die "yabsm: error: '$timeframe' is not a subvol timeframe\n";
    }

    if (not Yabsm::Base::timeframe_want($config_ref, $subvol, $timeframe)) {
	die "yabsm: error: subvol '$subvol' is not taking '$timeframe' snapshots\n";
    }

    Yabsm::Base::take_new_snapshot($config_ref, $subvol, $timeframe);
    Yabsm::Base::delete_old_snapshots($config_ref, $subvol, $timeframe);

    return;
}

1;
