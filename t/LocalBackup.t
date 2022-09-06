#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Testing for the the Yabsm::Backup::SSH library.

use strict;
use warnings;
use v5.16.3;

use Yabsm::Backup::Local;

use Yabsm::Tools qw( :ALL );
use Yabsm::Snapshot;
use Yabsm::Backup::Generic;
use Yabsm::Config::Query;

use Test::More;
use Test::Exception;

use Net::OpenSSH;
use File::Temp 'tempdir';
use File::Basename 'dirname';

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);

my $USAGE = <<'END_USAGE';
Usage: Local.t -s <dir>

Arguments:
  -h or --help   Print help (this message) and exit.
  -s <dir>       Use <dir> as subvolume to be snapshotted and used for
                 running btrfs related tests.
END_USAGE

GetOptions( 's=s'    => \my $BTRFS_SUBVOLUME
          , 'h|help' => \my $HELP
          );

print $USAGE and exit 0 if $HELP;


                 ####################################
                 #         ENSURE ENVIRONMENT       #
                 ####################################

have_prerequisites() or plan skip_all => 'Missing OS prerequisites';

defined $BTRFS_SUBVOLUME or plan skip_all => 'Failed to provide btrfs subvolume';

is_btrfs_subvolume($BTRFS_SUBVOLUME) or plan skip_all => q('$BTRFS_SUBVOLUME' is not a btrfs subvolume);

i_am_root() or plan skip_all => 'Must be root user';

my $BTRFS_DIR = tempdir( 'yabsm-SSH.t-tmpXXXXXX', DIR => $BTRFS_SUBVOLUME, CLEANUP => 1 );

                 ####################################
                 #            TEST CONFIG           #
                 ####################################

my %TEST_CONFIG = ( yabsm_dir   => "$BTRFS_DIR"
                  , subvols     => { foo            => { mountpoint => $BTRFS_SUBVOLUME } }
                  , local_backups => { foo_local_backup => { subvol         => 'foo'
                                                           , dir            => "$BTRFS_DIR/foo_local_backup"
                                                           , timeframes     => '5minute'
                                                           , '5minute_keep' => 1
                                                           }
                                   }
                  );

my $BACKUP_DIR      = Yabsm::Config::Query::local_backup_dir('foo_local_backup', '5minute', \%TEST_CONFIG);
my $BACKUP_DIR_BASE = dirname($BACKUP_DIR);
my $BOOTSTRAP_DIR   = Yabsm::Backup::Generic::bootstrap_snapshot_dir('foo_local_backup','local',\%TEST_CONFIG);
my $TMP_DIR         = Yabsm::Backup::Generic::tmp_snapshot_dir('foo_local_backup','local',\%TEST_CONFIG);
my $BACKUP          = "$BACKUP_DIR/" . Yabsm::Snapshot::current_time_snapshot_name();

                 ####################################
                 #              TESTS               #
                 ####################################

my $n = 'do_local_backup';
my $f = \&Yabsm::Backup::Local::do_local_backup;

throws_ok { $f->('foo_local_backup', '5minute', \%TEST_CONFIG) } qr/'$BOOTSTRAP_DIR' is not a directory residing on a btrfs filesystem/, "$n - dies if backup directory doesn't exist";
cleanup_snapshots();
make_path_or_die($BOOTSTRAP_DIR);

throws_ok { $f->('foo_local_backup', '5minute', \%TEST_CONFIG) } qr/'$TMP_DIR' is not a directory residing on a btrfs filesystem/, "$n - dies if tmp directory doesn't exist";
cleanup_snapshots();
make_path_or_die($TMP_DIR);

dies_ok { $f->('foo_local_backup', '5minute', \%TEST_CONFIG) } "$n - dies if backup_dir doesn't exist";

cleanup_snapshots();
make_path_or_die($BACKUP_DIR);
lives_and { is $f->('foo_local_backup', '5minute', \%TEST_CONFIG), $BACKUP } "$n - successfully performs backup";

done_testing();

                 ####################################
                 #              CLEANUP             #
                 ####################################

sub cleanup_snapshots {

    opendir(my $dh, $BOOTSTRAP_DIR) if -d $BOOTSTRAP_DIR;
    if ($dh) {
        for (map { $_ = "$BOOTSTRAP_DIR/$_" } grep { $_ !~ /^(\.\.|\.)$/ } readdir($dh) ) {
            Yabsm::Snapshot::delete_snapshot($_);
        }
    }

    opendir($dh, $TMP_DIR) if -d $TMP_DIR;
    if ($dh) {
        for (map { $_ = "$TMP_DIR/$_" } grep { $_ !~ /^(\.\.|\.)$/ } readdir($dh) ) {
            Yabsm::Snapshot::delete_snapshot($_);
        }
    }

    opendir($dh, $BACKUP_DIR) if -d $BACKUP_DIR;
    if ($dh) {
        for (map { $_ = "$BACKUP_DIR/$_" } grep { $_ !~ /^(\.\.|\.)$/ } readdir($dh) ) {
            Yabsm::Snapshot::delete_snapshot($_);
        }
    }

    closedir $dh if $dh;
}

cleanup_snapshots();

1;
