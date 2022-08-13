#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Provides functions for taking and cycling snapshots based off of
#  the user config.
#
#  See t/Yabsm/Snapshot.pm for this libraries tests.

package Yabsm::Snapshot;

use strict;
use warnings;
use v5.16.3;

use Yabsm::Tools qw( :ALL );
use Yabsm::Config::Query qw( :ALL );

use Log::Log4perl qw(get_logger);
use File::Basename qw(basename);
use Time::Piece;

use Exporter 'import';
our @EXPORT_OK = qw( take_snapshot_or_die
                     delete_snapshot_or_die
                     is_snapshot_name
                     is_snapshot_name_or_die
                     is_yabsm_snapshot
                     is_yabsm_snapshot_or_die
                     snapshot_name_nums_or_die
                     nums_to_snapshot_name_or_die
                     current_time_snapshot_name
                     sort_snapshots
                     cmp_snapshots
                   );

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub take_snapshot_or_die { # Is tested

    # This is the lowest level function for taking a snapshot. Given
    # the path to a btrfs subvolume ($subvolume) and the destination
    # path for the snapshot ($dest), takes a snapshot of $subvolume,
    # names it after the current time (or an inputted name), and
    # places it in $dest. Returns the path of the new snapshot.
    #
    # Performs sanity checking and dies unless $subvolume is a btrfs
    # subvolume, $dest is a directory residing on a btrfs filesystem,
    # and the current user can call the btrfs program using sudo
    # without the need for password authentication.

    2 == @_ || 3 == @_ or die_arg_count(2, 3, @_);

    my $subvolume     = shift;
    my $dest          = shift;
    my $snapshot_name = shift // current_time_snapshot_name();

    is_btrfs_subvolume_or_die($subvolume);
    is_btrfs_dir_or_die($dest);
    have_sudo_access_to_btrfs_or_die();

    my $snapshot = "$dest/" . $snapshot_name;

    system_or_die("sudo -n btrfs subvolume snapshot -r '$subvolume' '$snapshot' >/dev/null 2>&1");

    return $snapshot;
}

sub delete_snapshot_or_die { # Is tested

    # This is the lowest level function for deleting a snapshot. Takes
    # the path to a yabsm snapshot ($snapshot), deletes it and returns
    # it back.
    #
    # Performs sanity checking and dies unless $snapshot is a yabsm
    # snapshot, and the current user can call the btrfs program with
    # sudo without the need for password authentication.

    1 == @_ or die_arg_count(1, 1, @_);

    my $snapshot = shift;

    is_yabsm_snapshot_or_die($snapshot);
    have_sudo_access_to_btrfs_or_die();

    system_or_die("sudo -n btrfs subvol delete '$snapshot' >/dev/null 2>&1");

    return $snapshot;
}

sub is_snapshot_name { # Is tested

    # Return 1 if passed a valid yabsm snapshot name and return 0
    # otherwise. Does checking to ensure that the denoted date is
    # valid.
    #
    # It is important to note that this function rejects directory
    # paths even if their basename is a valid yabsm snapshot name.

    1 == @_ or die_arg_count(1, 1, @_);

    return 0 unless my (undef, @date_nums) = shift =~ /^(\.BOOTSTRAP-)?yabsm-(\d{4})_(\d{2})_(\d{2})_(\d{2}):(\d{2})$/;

    return 0 unless nums_denote_valid_date(@date_nums);

    return 1;
}

sub is_snapshot_name_or_die { # Is tested

    # Like &is_snapshot_name but logdie if $snapshot_name is not a
    # valid yabsm snapshot name.

    1 == @_ or die_arg_count(1, 1, @_);

    my $snapshot_name = shift;

    my (undef, @date_nums) = $snapshot_name =~ /^(\.BOOTSTRAP-)?yabsm-(\d{4})_(\d{2})_(\d{2})_(\d{2}):(\d{2})$/
      or get_logger->logconfess("yabsm: internal error: '$snapshot_name' is not a valid yabsm snapshot name");

    nums_denote_valid_date_or_die(@date_nums);

    return 1;
}

sub is_yabsm_snapshot { # Is tested

    # Return 1 if $snapshot is a yabsm snapshot and return 0
    # otherwise.

    1 == @_ or die_arg_count(1, 1, @_);

    my $snapshot = shift;

    return is_snapshot_name(basename($snapshot)) && is_btrfs_subvolume($snapshot)
}

sub is_yabsm_snapshot_or_die { # Is tested

    # Wrapper around is_yabsm_snapshot_name() that logdies if it
    # returns false.

    1 == @_ or die_arg_count(1, 1, @_);

    my $snapshot = shift;

    unless ( is_btrfs_subvolume($snapshot) ) {
        get_logger->logconfess("yabsm: internal error: '$snapshot' is not a btrfs subvolume");
    }

    unless ( is_snapshot_name(basename($snapshot)) ) {
        get_logger->logconfess("yabsm: internal error: '$snapshot' does not have a valid yabsm snapshot name");
    }

    return 1;
}

sub snapshot_name_nums_or_die { # Is tested

    # Take a snapshot name and return a list containing, in order, the
    # corresponding year, month, day, hour, and minute. Kill program
    # if $snapshot_name is not a valid yabsm snapshot name.

    1 == @_ or die_arg_count(1, 1, @_);

    my $snapshot_name = shift;

    is_snapshot_name_or_die($snapshot_name);

    my ($yr, $mon, $day, $hr, $min) = map { 0 + $_ } $snapshot_name =~ /^yabsm-(\d{4})_(\d{2})_(\d{2})_(\d{2}):(\d{2})$/;

    return ($yr, $mon, $day, $hr, $min);
}

sub nums_to_snapshot_name_or_die { # Is tested

    # Take 5 integer arguments representing in order the year, month,
    # day, hour, and minute and return a snapshot name of the
    # corresponding time.

    5 == @_ or die_arg_count(5, 5, @_);

    my ($yr, $mon, $day, $hr, $min) = map { sprintf '%02d', $_ } @_;

    my $snapshot_name = "yabsm-${yr}_${mon}_${day}_$hr:$min";

    is_snapshot_name_or_die($snapshot_name);

    return $snapshot_name;
}

sub current_time_snapshot_name { # Is tested

    # Return a snapshot name corresponding to the current time.

    0 == @_ or die_arg_count(0, 0, @_);

    my $t = localtime();

    return nums_to_snapshot_name_or_die($t->year, $t->mon, $t->mday, $t->hour, $t->min);
}

sub sort_snapshots { # Is tested

    # Takes a reference to an array of snapshots and returns a list
    # of the snapshots sorted from newest to oldest. This function
    # works with both paths to snapshots and plain snapshots names.
    #
    # If called in list context returns list of sorted snapshots. If
    # called in scalar context returns a reference to the list of
    # sorted snapshots.

    1 == @_ or die_arg_count(1, 1, @_);

    my @sorted = sort { cmp_snapshots($a, $b) } @{ +shift };

    return wantarray ? @sorted : \@sorted;
}

sub cmp_snapshots { # Is tested

    # Compare two yabsm snapshots based off their times. Works with
    # both a path to a snapshot and just a snapshot name.
    #
    # Return -1 if $snapshot1 is newer than $snapshot2
    # Return 1  if $snapshot1 is older than $snapshot2
    # Return 0  if $snapshot1 and $snapshot2 are the same

    2 == @_ or die_arg_count(2, 2, @_);

    my $snapshot1 = shift;
    my $snapshot2 = shift;

    my @nums1 = snapshot_name_nums_or_die(basename $snapshot1);
    my @nums2 = snapshot_name_nums_or_die(basename $snapshot2);

    for (my $i = 0; $i <= $#nums1; $i++) {
        return -1 if $nums1[$i] > $nums2[$i];
        return 1  if $nums1[$i] < $nums2[$i];
    }

    return 0;
}

1;
