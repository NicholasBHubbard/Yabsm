#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

package Yabsm::TakeSnap;

use strict;
use warnings;
use 5.010;

use lib '..';
use Base;
use Yabsmrc;

sub die_usage {
    say 'Usage: yabsm take-snap <SUBVOL> <QUERY>';
    exit 1;
}

sub main {

    die "yabsm: error: permission denied\n" if $<;

    my $subvol    = shift // die_usage();
    my $timeframe = shift // die_usage();

    if (@_) { die_usage() }

    my $config_ref = Yabsmrc::read_config();

    if (not Base::is_subvol($config_ref, $subvol)) {
	die "yabsm: error: no such defined subvol '$subvol'\n";
    }

    if (not Base::is_subvol_timeframe($timeframe)) {
	die "yabsm: error: '$timeframe' is not a subvol timeframe\n";
    }

    if (not Base::timeframe_want($config_ref, $subvol, $timeframe)) {
	die "yabsm: error: subvol '$subvol' is not taking '$timeframe' snapshots\n";
    }

    Base::initialize_directories($config_ref);

    Base::take_new_snapshot($config_ref, $subvol, $timeframe);
    Base::delete_old_snapshots($config_ref, $subvol, $timeframe);

    return;
}

1;
