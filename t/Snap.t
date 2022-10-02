#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Testing for the Yabsm::Snap library.

use strict;
use warnings;
use v5.16.3;

use App::Yabsm::Snap;

use Test::More;
use Test::Exception;

use App::Yabsm::Tools qw( :ALL );
use App::Yabsm::Snapshot qw(current_time_snapshot_name);

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use File::Temp 'tempdir';

my $USAGE = <<'END_USAGE';
Usage: Snapshot.t [arguments]

Arguments:
  -h or --help   Print help (this message) and exit
  -s <dir>       Use <dir> as subvolume to be snapshotted and used for
                 running btrfs related tests.
END_USAGE

                 ####################################
                 #         ENSURE ENVIRONMENT       #
                 ####################################

my $HELP;
my $BTRFS_SUBVOLUME;

GetOptions( 's=s' => \$BTRFS_SUBVOLUME
          , 'h|help' => \$HELP
          );

print $USAGE and exit 0 if $HELP;

have_prerequisites() or plan skip_all => 'Missing OS prerequisites';

defined $BTRFS_SUBVOLUME or plan skip_all => 'Failed to provide btrfs subvolume';

is_btrfs_subvolume($BTRFS_SUBVOLUME) or plan skip_all => q('$BTRFS_SUBVOLUME' is not a btrfs subvolume);

i_am_root() or plan skip_all => 'Must be root user';

my $BTRFS_DIR = tempdir( 'yabsm-Snap.t-tmpXXXXXX', DIR => $BTRFS_SUBVOLUME, CLEANUP => 1 );

                 ####################################
                 #            TEST CONFIG           #
                 ####################################

my %TEST_CONFIG = ( yabsm_dir => $BTRFS_DIR
                  , subvols   => { foo => { mountpoint => $BTRFS_SUBVOLUME } }
                  , snaps     => { foo_snap => { subvol => 'foo'
                                               , timeframes => '5minute'
                                               , '5minute_keep' => 2
                                               }
                                 }
                  );

                 ####################################
                 #               TESTS              #
                 ####################################

my $n = 'do_snap';
my $f = \&App::Yabsm::Snap::do_snap;

my $SNAP_DIR = "$BTRFS_DIR/foo_snap/5minute";
my $SNAP = "$SNAP_DIR/" . current_time_snapshot_name();

throws_ok { $f->('foo_snap', '5minute', \%TEST_CONFIG) } qr/'$SNAP_DIR' is not a directory residing on a btrfs filesystem/, "$n - dies snapshot destination doesn't exist";

make_path_or_die("$BTRFS_DIR/foo_snap/5minute");

lives_and { is $f->('foo_snap', '5minute', \%TEST_CONFIG), $SNAP } "$n - takes snapshot";

cleanup_snapshots();

App::Yabsm::Snapshot::take_snapshot($BTRFS_SUBVOLUME, $SNAP_DIR, 'yabsm-2020_05_13_23:59');
App::Yabsm::Snapshot::take_snapshot($BTRFS_SUBVOLUME, $SNAP_DIR, 'yabsm-1999_05_13_23:59');
App::Yabsm::Snapshot::take_snapshot($BTRFS_SUBVOLUME, $SNAP_DIR, 'yabsm-1998_05_13_23:59');

lives_and { $f->('foo_snap', '5minute', \%TEST_CONFIG); is_deeply [App::Yabsm::Snapshot::sort_snapshots([glob "$SNAP_DIR/*"])], [$SNAP, "$SNAP_DIR/yabsm-2020_05_13_23:59"] } "$n - deletes old snapshots";

done_testing();

                 ####################################
                 #              CLEANUP             #
                 ####################################

sub cleanup_snapshots {

    opendir(my $dh, $SNAP_DIR) if -d $SNAP_DIR;
    if ($dh) {
        for (map { $_ = "$SNAP_DIR/$_" } grep { $_ !~ /^(\.\.|\.)$/ } readdir($dh) ) {
            App::Yabsm::Snapshot::delete_snapshot($_);
        }
    }

    closedir $dh if $dh;
}

cleanup_snapshots();

1;
