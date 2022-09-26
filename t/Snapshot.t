#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Testing for the Yabsm::Snapshot library.

use strict;
use warnings;
use v5.16.3;

use App::Yabsm::Snapshot;
use App::Yabsm::Tools qw( :ALL );

use Test::More 'no_plan';
use Test::Exception;

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use File::Temp 'tempdir';
use Time::Piece;

my $USAGE = <<'END_USAGE';
Usage: Snapshot.t [arguments]

Arguments:
  -h or --help   Print help (this message) and exit
  -s <dir>       Use <dir> as subvolume to be snapshotted and used for
                 running btrfs related tests.
END_USAGE

my $HELP;
my $BTRFS_SUBVOLUME;

GetOptions( 's=s' => \$BTRFS_SUBVOLUME
          , 'h|help' => \$HELP
          );

print $USAGE and exit 0 if $HELP;

my $BTRFS_DIR;

if ($BTRFS_SUBVOLUME) {

    unless (0 == $<) {
        die "Snapshot.t: You must be root to run btrfs dependent tests\n";
    }

    unless (is_btrfs_subvolume($BTRFS_SUBVOLUME)) {
        die "Snapshot.t: '$BTRFS_SUBVOLUME' is not a btrfs subvolume\n";
    }

    $BTRFS_DIR = tempdir( 'yabsm-Snapshot.t-tmpXXXXXX', DIR => $BTRFS_SUBVOLUME, CLEANUP => 1 );
}

                 ####################################
                 #               TESTS              #
                 ####################################

{
    my $n = 'is_snapshot_name';
    my $f = \&App::Yabsm::Snapshot::is_snapshot_name;

    is($f->('yabsm-2020_05_13_23:59'), 1, "$n - succeeds with 1");
    is($f->('foo'), 0, "$n - fails with 0");
    is($f->('/home/yabsm-2020_05_31_23:59'), 0, "$n - rejects file path");
    is($f->('yabsm-2020_05_13_24:59'), 0, "$n - rejects time out of range");
    is($f->('/home/yabsm-2020_04_31_23:59'), 0, "$n - understands month days");
    is($f->('yabsm-2020_02_29_23:59'), 1, "$n - understands leap years");
    is($f->('yabsm-2021_02_29_23:59'), 0, "$n - understands leap years");
    is($f->('.BOOTSTRAP-yabsm-2021_05_13_23:59'), 0, "$n - rejects bootstrap by default");

    is($f->('.BOOTSTRAP-yabsm-2021_05_13_23:59', ALLOW_BOOTSTRAP => 1), 1, "$n - optionally allow bootstrap");
    is($f->('yabsm-2021_05_13_23:59', ALLOW_BOOTSTRAP => 1), 1, "$n - optionally allow bootstrap 2");
    is($f->('yabsm-2021_05_13_23:59', ONLY_BOOTSTRAP => 1), 0, "$n - optionally only allow bootstrap");
    is($f->('.BOOTSTRAP-yabsm-2021_05_13_23:59', ONLY_BOOTSTRAP => 1), 1, "$n - optionally only allow bootstrap");
    is($f->('yabsm-2021_05_13_23:59', ALLOW_BOOTSTRAP => 1, ONLY_BOOTSTRAP => 1), 0, "$n - ONLY_BOOTSTRAP overrides ALLOW_BOOTSTRAP");
}

{
    my $n = 'is_snapshot_name_or_die';
    my $f = \&App::Yabsm::Snapshot::is_snapshot_name_or_die;

    lives_and { is $f->('yabsm-2020_05_13_23:59'), 1 } "$n - succeeds with 1";
    lives_and { is $f->('.BOOTSTRAP-yabsm-2020_05_13_23:59', ALLOW_BOOTSTRAP => 1), 1 } "$n - accepts .BOOTSTRAP prefix";
    throws_ok { $f->('quux') } qr/'quux' is not a valid yabsm snapshot name/, "$n - dies if invalid snapshot name";
    throws_ok { $f->('.BOOTSTRAP-yabsm-2020_05_13_23:59') } qr/'.BOOTSTRAP-yabsm-2020_05_13_23:59' is not a valid yabsm snapshot name/, "$n - optionally reject .BOOTSTRAP prefix";
    throws_ok { $f->('yabsm-2020_12_32_23:59') } qr/'yabsm-2020_12_32_23:59' is not a valid yabsm snapshot name/, "$n - dies if invalid snapshot name";
}

{
    my $n = 'snapshot_name_nums';
    my $f = \&App::Yabsm::Snapshot::snapshot_name_nums;

    is_deeply([ $f->('yabsm-2020_05_13_23:59') ], [2020,5,13,23,59], "$n - produces correct number list");
    throws_ok { $f->('yabsm-2020_5_13_23:59') } qr/'yabsm-2020_5_13_23:59' is not a valid yabsm snapshot name/, "$n - dies if passed invalid snapshot name";
}

{
    my $n = 'nums_to_snapshot_name';
    my $f = \&App::Yabsm::Snapshot::nums_to_snapshot_name;

    is($f->(2020, 5, 13, 1, 5), 'yabsm-2020_05_13_01:05', "$n - produces snapshot name");
    throws_ok { $f->(2020, 13, 13, 1, 5) } qr/'2020_13_13_01:05' does not denote a valid yr_mon_day_hr:min date/, "$n - dies if invalid snapshot name";
}

{
    my $n = 'current_time_snapshot_name';
    my $f = \&App::Yabsm::Snapshot::current_time_snapshot_name;

    my $t = localtime();

    my ($yr, $mon, $day, $hr, $min) =
      map { sprintf '%02d', $_ } ($t->year, $t->mon, $t->mday, $t->hour, $t->min);

    is($f->(), "yabsm-${yr}_${mon}_${day}_$hr:$min", "$n - produces snapshot name for current time")
}

{
    my $n = 'cmp_snapshots';
    my $f = \&App::Yabsm::Snapshot::cmp_snapshots;

    my $snap1 = 'yabsm-2022_05_14_10:30';
    my $snap2 = 'yabsm-2022_05_13_10:30';

    is($f->($snap1, $snap2), -1, "$n - return -1 if \$snap1 newer than \$snap2");
    is($f->($snap2, $snap1), 1, "$n - return -1 if \$snap1 older than \$snap2");
    is($f->($snap1, $snap1), 0, "$n - return 0 if \$snap1 same as \$snap2");
    is($f->("/foo/$snap1", $snap1), 0, "$n - accepts path to snapshot");

    throws_ok { $f->('quux', $snap1) } qr/'quux' is not a valid yabsm snapshot name/, "$n - dies if invalid snapshot";
}

{
    my $n = 'sort_snapshots';
    my $f = \&App::Yabsm::Snapshot::sort_snapshots;

    my @snaps        = ('yabsm-2022_05_13_10:30', 'yabsm-2022_05_13_11:30', 'yabsm-2022_05_13_09:30');
    my @snaps_sorted = ('yabsm-2022_05_13_11:30', 'yabsm-2022_05_13_10:30', 'yabsm-2022_05_13_09:30');

    is_deeply([$f->(\@snaps)], \@snaps_sorted, "$n - successfully sorted plain snapshot names");
    my $snaps_ref = $f->(\@snaps);
    is_deeply($snaps_ref, [@snaps_sorted], "$n - returns ref in scalar context");

    @snaps        = map { $_ = "/foo/$_" } @snaps;
    @snaps_sorted = map { $_ = "/foo/$_" } @snaps_sorted;

    is_deeply([$f->(\@snaps)], \@snaps_sorted, "$n - accepts path to snapshot");
    throws_ok { $f->(['quux',@snaps]) } qr/'quux' is not a valid yabsm snapshot name/, "$n - dies if invalid snapshot";
}

{
    my $n = 'snapshots_eq';
    my $f = \&App::Yabsm::Snapshot::snapshots_eq;

    my $snap1 = 'yabsm-2022_05_13_23:59';
    my $snap2 = 'yabsm-2021_05_13_23:59';

    is $f->($snap1, $snap1), 1, "$n - true if snapshots equal";
    is $f->($snap1, $snap2), 0, "$n - false if snapshots not equal";
}

{
    my $n = 'snapshot_newer';
    my $f = \&App::Yabsm::Snapshot::snapshot_newer;

    my $snap1 = 'yabsm-2022_05_13_23:59';
    my $snap2 = 'yabsm-2021_05_13_23:59';

    is $f->($snap1, $snap2), 1, "$n - true if snapshot newer";
    is $f->($snap2, $snap1), 0, "$n - false if snapshot older";
    is $f->($snap1, $snap1), 0, "$n - false if snapshots equal";
}

{
    my $n = 'snapshot_older';
    my $f = \&App::Yabsm::Snapshot::snapshot_older;

    my $snap1 = 'yabsm-2022_05_13_23:59';
    my $snap2 = 'yabsm-2021_05_13_23:59';

    is $f->($snap2, $snap1), 1, "$n - true if snapshot older";
    is $f->($snap1, $snap2), 0, "$n - false if snapshot newer";
    is $f->($snap1, $snap1), 0, "$n - false if snapshots equal";
}

{
    my $n = 'snapshot_newer_or_eq';
    my $f = \&App::Yabsm::Snapshot::snapshot_newer_or_eq;

    my $snap1 = 'yabsm-2022_05_13_23:59';
    my $snap2 = 'yabsm-2021_05_13_23:59';

    is $f->($snap1, $snap2), 1, "$n - true if snapshot newer";
    is $f->($snap1, $snap1), 1, "$n - true if snapshots equal";
    is $f->($snap2, $snap1), 0, "$n - false if snapshot older";
}

{
    my $n = 'snapshot_older_or_eq';
    my $f = \&App::Yabsm::Snapshot::snapshot_older_or_eq;

    my $snap1 = 'yabsm-2022_05_13_23:59';
    my $snap2 = 'yabsm-2021_05_13_23:59';

    is $f->($snap2, $snap1), 1, "$n - true if snapshot older";
    is $f->($snap1, $snap1), 1, "$n - true if snapshots equal";
    is $f->($snap1, $snap2), 0, "$n - false if snapshot newer";
}

{
    my $n_take = 'take_snapshot';
    my $f_take = \&App::Yabsm::Snapshot::take_snapshot;

    my $n_del  = 'delete_snapshot';
    my $f_del  = \&App::Yabsm::Snapshot::delete_snapshot;
    
    my $n_is_yabsm_snap = 'is_yabsm_snapshot';
    my $f_is_yabsm_snap = \&App::Yabsm::Snapshot::is_yabsm_snapshot;

    my $n_is_yabsm_snap_od = 'is_yabsm_snapshot_or_die';
    my $f_is_yabsm_snap_od = \&App::Yabsm::Snapshot::is_yabsm_snapshot_or_die;

    my $snapshot;

  SKIP: {
        skip "$n_take, $n_del, $n_is_yabsm_snap, and $n_is_yabsm_snap_od - no btrfs subvolume passed with -s flag", 13 unless $BTRFS_SUBVOLUME;

        lives_ok { $snapshot = $f_take->($BTRFS_SUBVOLUME, $BTRFS_DIR) } "$n_take - ran without dying";
        is(is_btrfs_subvolume($snapshot), 1, "$n_take - successfully created snapshot");
        throws_ok { $f_take->('quux', $BTRFS_DIR) } qr/'quux' is not a btrfs subvolume/, "$n_del - dies if given non-existent btrfs subvolume";
        
        is($f_is_yabsm_snap->($snapshot), 1, "$n_is_yabsm_snap - returns 1 if yabsm snap");
        lives_and { is $f_is_yabsm_snap_od->($snapshot), 1 } "$n_is_yabsm_snap_od - returns 1 if yabsm snap";

        lives_ok { $f_del->($snapshot) } "$n_del - ran without dying";
        is(is_btrfs_subvolume($snapshot), 0, "$n_del - successfully deleted snapshot");
        throws_ok { $f_del->('quux') } qr/'quux' is not a btrfs subvolume/, "$n_del - dies if given non-existent snapshot";

        is($f_is_yabsm_snap->($snapshot), 0, "$n_is_yabsm_snap - returns 0 if not yabsm snap");
        throws_ok { $f_is_yabsm_snap_od->($snapshot) } qr/'$snapshot' is not a btrfs subvolume/, "$n_is_yabsm_snap_od - dies if not yabsm snapshot";

        throws_ok { $f_take->('quux', $BTRFS_DIR) } qr/'quux' is not a btrfs subvolume/, "$n_take - dies if invalid btrfs subvolume";
        throws_ok { $f_take->($BTRFS_SUBVOLUME, 'quux') } qr/'quux' is not a directory residing on a btrfs filesystem/, "$n_take - dies if target not btrfs dir";
        dies_ok { $f_take->($BTRFS_SUBVOLUME, "$BTRFS_DIR/quux") } "$n_take - dies if destination doesn't exist";
    };
}

1;
