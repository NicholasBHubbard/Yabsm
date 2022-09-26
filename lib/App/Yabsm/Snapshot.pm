#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Provides functions for taking and cycling snapshots based off of
#  the user config.
#
#  See t/Snapshot.t for this libraries tests.

use strict;
use warnings;
use v5.16.3;

package App::Yabsm::Snapshot;

use App::Yabsm::Tools qw( :ALL );
use App::Yabsm::Config::Query qw( :ALL );

use Carp qw(confess);
use File::Basename qw(basename);
use Time::Piece;

use Exporter qw(import);
our @EXPORT_OK = qw(take_snapshot
                    delete_snapshot
                    is_snapshot_name
                    is_snapshot_name_or_die
                    is_bootstrap_snapshot_name
                    is_yabsm_snapshot
                    is_yabsm_snapshot_or_die
                    snapshot_name_nums
                    nums_to_snapshot_name
                    current_time_snapshot_name
                    sort_snapshots
                    cmp_snapshots
                    snapshots_eq
                    snapshot_newer
                    snapshot_older
                    snapshot_newer_or_eq
                    snapshot_older_or_eq
                   );

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub take_snapshot {

    # This is the lowest level function for taking a snapshot. Given the path to
    # a btrfs subvolume ($subvolume) and the destination path for the snapshot
    # ($dest), takes a snapshot of $subvolume, names it after the current time
    # (or an inputted name), and places it in $dest. Returns the path of the new
    # snapshot.
    #
    # Performs sanity checking and dies unless $subvolume is a btrfs subvolume,
    # $dest is a directory residing on a btrfs filesystem, and the current user
    # can call the btrfs program using sudo without the need for password
    # authentication.

    arg_count_or_die(2, 3, @_);

    my $subvolume     = shift;
    my $dest          = shift;
    my $snapshot_name = shift // current_time_snapshot_name();

    is_btrfs_subvolume_or_die($subvolume);
    is_btrfs_dir_or_die($dest);
    is_snapshot_name_or_die($snapshot_name, ALLOW_BOOTSTRAP => 1);
    have_sudo_access_to_btrfs_or_die();

    my $snapshot = "$dest/" . $snapshot_name;

    system_or_die('sudo', '-n', 'btrfs', 'subvolume', 'snapshot', '-r', $subvolume, $snapshot);

    return $snapshot;
}

sub delete_snapshot {

    # This is the lowest level function for deleting a snapshot. Takes the path
    # to a yabsm snapshot ($snapshot), deletes it and returns it back.
    #
    # Performs sanity checking and dies unless $snapshot is a yabsm snapshot,
    # and the current user can call the btrfs program with sudo without the need
    # for password authentication.

    arg_count_or_die(1, 1, @_);

    my $snapshot = shift;

    is_yabsm_snapshot_or_die($snapshot);
    have_sudo_access_to_btrfs_or_die();

    system_or_die('sudo', '-n', 'btrfs', 'subvolume', 'delete', $snapshot);

    return $snapshot;
}

sub is_snapshot_name {

    # Return 1 if passed a valid yabsm snapshot name and return 0 otherwise. Does
    # checking to ensure that the denoted date is a valid date.
    #
    # Optionally pass 'ALLOW_BOOTSTRAP => 1' to accept bootstrap snapshot names
    # and 'ONLY_BOOTSTRAP => 1' to only accept bootstrap snapshot names.
    #
    # It is important to note that this function rejects directory paths even if
    # their basename is a valid snapshot name.

    arg_count_or_die(1, 5, @_);

    my $snapshot_name = shift;
    my %opts = (ALLOW_BOOTSTRAP => 0, ONLY_BOOTSTRAP  => 0, @_);

    my $rx = do {
        my $base = 'yabsm-(\d{4})_(\d{2})_(\d{2})_(\d{2}):(\d{2})';
        my $prefix = '';
        if ($opts{ALLOW_BOOTSTRAP}) {
            $prefix = '(?:\.BOOTSTRAP-)?';
        }
        if ($opts{ONLY_BOOTSTRAP}) {
            $prefix = '(?:\.BOOTSTRAP-)';
        }
        qr/^$prefix$base$/;
    };

    return 0 unless my @date_nums = $snapshot_name =~ $rx;

    return 0 unless nums_denote_valid_date(@date_nums);

    return 1;
}

sub is_snapshot_name_or_die {

    # Wrapper around &is_snapshot_name that will Carp::confess if it returns
    # false.

    arg_count_or_die(1, 5, @_);

    unless (is_snapshot_name(@_)) {
        confess q(yabsm: internal error: ').shift(@_).q(' is not a valid yabsm snapshot name);
    }

    return 1;
}

sub is_yabsm_snapshot {

    # Return 1 if $snapshot is a yabsm snapshot (including bootstrap) and return
    # 0 otherwise.

    my $snapshot = shift;

    return is_btrfs_subvolume($snapshot) && is_snapshot_name(basename($snapshot), ALLOW_BOOTSTRAP => 1);
}

sub is_yabsm_snapshot_or_die {

    # Wrapper around is_yabsm_snapshot_name() that Carp::Confess's if it returns
    # false.

    my $snapshot = shift;

    unless ( is_btrfs_subvolume($snapshot) ) {
        confess("yabsm: internal error: '$snapshot' is not a btrfs subvolume");
    }

    unless ( is_snapshot_name(basename($snapshot), ALLOW_BOOTSTRAP => 1) ) {
        confess("yabsm: internal error: '$snapshot' does not have a valid yabsm snapshot name");
    }

    return 1;
}

sub snapshot_name_nums {

    # Take a snapshot name and return a list containing, in order, the
    # corresponding year, month, day, hour, and minute. Kill program if
    # $snapshot_name is not a valid yabsm snapshot name.

    arg_count_or_die(1, 1, @_);

    my $snapshot_name = shift;

    is_snapshot_name_or_die($snapshot_name, ALLOW_BOOTSTRAP => 1);

    my ($yr, $mon, $day, $hr, $min) = map { 0 + $_ } $snapshot_name =~ /^yabsm-(\d{4})_(\d{2})_(\d{2})_(\d{2}):(\d{2})$/;

    return ($yr, $mon, $day, $hr, $min);
}

sub nums_to_snapshot_name {

    # Take 5 integer arguments representing in order the year, month,
    # day, hour, and minute and return a snapshot name of the
    # corresponding time.

    arg_count_or_die(5, 5, @_);

    my ($yr, $mon, $day, $hr, $min) = map { sprintf '%02d', $_ } @_;

    nums_denote_valid_date_or_die($yr, $mon, $day, $hr, $min);

    my $snapshot_name = "yabsm-${yr}_${mon}_${day}_$hr:$min";

    return $snapshot_name;
}

sub current_time_snapshot_name {

    # Return a snapshot name corresponding to the current time.

    arg_count_or_die(0, 0, @_);

    my $t = localtime();

    return nums_to_snapshot_name($t->year, $t->mon, $t->mday, $t->hour, $t->min);
}

sub sort_snapshots {

    # Takes a reference to an array of snapshots and returns a list of the
    # snapshots sorted from newest to oldest. This function works with both
    # paths to snapshots and plain snapshots names.
    #
    # If called in list context returns list of sorted snapshots. If called in
    # scalar context returns a reference to the list of sorted snapshots.

    arg_count_or_die(1, 1, @_);

    my @sorted = sort { cmp_snapshots($a, $b) } @{ +shift };

    return wantarray ? @sorted : \@sorted;
}

sub cmp_snapshots {

    # Compare two yabsm snapshots based off their times. Works with both a path
    # to a snapshot and just a snapshot name.
    #
    # Return -1 if $snapshot1 is newer than $snapshot2
    # Return 1  if $snapshot1 is older than $snapshot2
    # Return 0  if $snapshot1 and $snapshot2 are the same

    arg_count_or_die(2, 2, @_);

    my $snapshot1 = shift;
    my $snapshot2 = shift;

    my @nums1 = snapshot_name_nums(basename($snapshot1));
    my @nums2 = snapshot_name_nums(basename($snapshot2));

    for (my $i = 0; $i <= $#nums1; $i++) {
        return -1 if $nums1[$i] > $nums2[$i];
        return 1  if $nums1[$i] < $nums2[$i];
    }

    return 0;
}

sub snapshots_eq {

    # Return 1 if $snapshot1 and $snapshot2 denote the same time and return 0
    # otherwise.

    arg_count_or_die(2, 2, @_);

    my $snapshot1 = shift;
    my $snapshot2 = shift;

    return 0+(0 == cmp_snapshots($snapshot1, $snapshot2));
}

sub snapshot_newer {

    # Return 1 if $snapshot1 is newer than $snapshot2 and return 0 otherwise.

    arg_count_or_die(2, 2, @_);

    my $snapshot1 = shift;
    my $snapshot2 = shift;

    return 0+(-1 == cmp_snapshots($snapshot1, $snapshot2));
}

sub snapshot_older {

    # Return 1 if $snapshot1 is older than $snapshot2 and return 0 otherwise.

    arg_count_or_die(2, 2, @_);

    my $snapshot1 = shift;
    my $snapshot2 = shift;

    return 0+(1 == cmp_snapshots($snapshot1, $snapshot2));
}

sub snapshot_newer_or_eq {

    # Return 1 if $snapshot1 is newer or equal to $snapshot2 and return 0
    # otherwise.

    arg_count_or_die(2, 2, @_);

    my $snapshot1 = shift;
    my $snapshot2 = shift;

    return 0+(cmp_snapshots($snapshot1, $snapshot2) <= 0);
}

sub snapshot_older_or_eq {

    # Return 1 if $snapshot1 is newer or equal to $snapshot2 and return 0
    # otherwise.

    arg_count_or_die(2, 2, @_);

    my $snapshot1 = shift;
    my $snapshot2 = shift;

    return 0+(cmp_snapshots($snapshot1, $snapshot2) >= 0);
}

1;
