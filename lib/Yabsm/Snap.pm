#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  TODO

use strict;
use warnings;
use v5.16.3;

package Yabsm::Snap;

use Yabsm::Snapshot qw(take_snapshot delete_snapshot sort_snapshots);
use Yabsm::Config::Query qw ( :ALL );

use Exporter 'import';
our @EXPORT_OK = qw(do_snap);

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub do_snap { # Not tested

    # TODO

    my $snap       = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    snap_wants_timeframe_or_die($snap, $tframe, $config_ref);

    my $mountpoint = snap_mountpoint($snap, $config_ref);
    my $snap_dest  = snap_dest();

    my $snapshot = take_snapshot($mountpoint, $snap_dest);

    my @snaps     = sort_snapshots([ glob "$snap_dest/*" ]);
    my $num_snaps = scalar @snaps;
    my $to_keep   = snap_timeframe_keep($snap, $tframe, $config_ref);

    # There is 1 more snap than should be kept because we just performed a snap.
    if ($num_snaps == $to_keep + 1) {
        my $oldest = pop @snaps;
        snapshot_delete($oldest);
    }
    # We havent reached the quota yet so we don't delete anything
    elsif ($num_snaps <= $to_keep) {
        ;
    }
    # User changed their settings to keep less snaps than they were keeping
    # prior.
    else {
        for (; $num_snaps > $to_keep; $num_snaps--) {
            my $oldest = pop @snaps;
            delete_snapshot($oldest);
        }
    }

    return $snapshot;
}

1;
