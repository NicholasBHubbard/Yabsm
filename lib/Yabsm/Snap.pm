#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Provides the &do_snap subroutine.

use strict;
use warnings;
use v5.16.3;

package Yabsm::Snap;

use Yabsm::Config::Query qw ( :ALL );
use Yabsm::Snapshot qw(take_snapshot
                       delete_snapshot
                       sort_snapshots
                       is_snapshot_name
                      );

use Exporter 'import';
our @EXPORT_OK = qw(do_snap);

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub do_snap { # Is tested

    # Perform a single $tframe snap of $snap.

    my $snap       = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    my $mountpoint = snap_mountpoint($snap, $config_ref);
    my $snap_dest  = snap_dest($snap, $tframe, $config_ref);

    my $snapshot = take_snapshot($mountpoint, $snap_dest);

    my @snapshots = sort_snapshots(do {
        opendir my $dh, $snap_dest or confess("yabsm: internal error: cannot opendir '$snap_dest'");
        my @snapshots = map { $_ = "$snap_dest/$_" } grep { is_snapshot_name($_, 0) } readdir($dh);
        closedir $dh;
        \@snapshots;
    });

    my $num_snaps = scalar @snapshots;
    my $to_keep   = snap_timeframe_keep($snap, $tframe, $config_ref);

    # There is 1 more snap than should be kept because we just performed a snap.
    if ($num_snaps == $to_keep + 1) {
        my $oldest = pop @snapshots;
        delete_snapshot($oldest);
    }
    # We havent reached the quota yet so we don't delete anything
    elsif ($num_snaps <= $to_keep) {
        ;
    }
    # User changed their settings to keep less snaps than they were keeping
    # prior.
    else {
        for (; $num_snaps > $to_keep; $num_snaps--) {
            my $oldest = pop @snapshots;
            delete_snapshot($oldest);
        }
    }

    return $snapshot;
}

1;
