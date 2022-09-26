#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Testing for the the Yabsm::Backup::SSH library.

use strict;
use warnings;
use v5.16.3;

use App::Yabsm::Backup::Local;

use App::Yabsm::Tools qw( :ALL );
use App::Yabsm::Snapshot;
use App::Yabsm::Backup::Generic;
use App::Yabsm::Config::Query;

use Test::More;
use Test::Exception;

use Net::OpenSSH;
use File::Temp 'tempdir';
use File::Basename qw(dirname basename);

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);

my $USAGE = <<'END_USAGE';
Usage: LocalBackup.t -s <dir>

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

my $BACKUP_DIR      = App::Yabsm::Config::Query::local_backup_dir('foo_local_backup', '5minute', \%TEST_CONFIG);
my $BACKUP_DIR_BASE = dirname($BACKUP_DIR);
my $BOOTSTRAP_DIR   = App::Yabsm::Backup::Generic::bootstrap_snapshot_dir('foo_local_backup','local',\%TEST_CONFIG);
my $TMP_DIR         = App::Yabsm::Backup::Generic::tmp_snapshot_dir('foo_local_backup','local','5minute',\%TEST_CONFIG);
my $BACKUP          = "$BACKUP_DIR/" . App::Yabsm::Snapshot::current_time_snapshot_name();

make_path_or_die($BACKUP_DIR);
make_path_or_die($BOOTSTRAP_DIR);
make_path_or_die($TMP_DIR);

                 ####################################
                 #              TESTS               #
                 ####################################

my $n;
my $f;

my $lock_file = App::Yabsm::Backup::Generic::create_bootstrap_lock_file('foo_local_backup', 'local', \%TEST_CONFIG);

$n = 'do_local_backup_bootstrap';
$f = \&App::Yabsm::Backup::Local::do_local_backup_bootstrap;

lives_and { is $f->('foo_local_backup', \%TEST_CONFIG), undef } "$n - returns undef if bootstrap lock file exists";

unlink $lock_file;

my $expected_boot_snap = "$BOOTSTRAP_DIR/.BOOTSTRAP-".App::Yabsm::Snapshot::current_time_snapshot_name();

lives_and { is $f->('foo_local_backup', \%TEST_CONFIG), $expected_boot_snap } "$n - performs successful bootstrap";

$n = 'the_remote_bootstrap_snapshot';
$f = \&App::Yabsm::Backup::Local::the_remote_bootstrap_snapshot;

lives_and { is $f->('foo_local_backup', \%TEST_CONFIG), "$BACKUP_DIR_BASE/".basename($expected_boot_snap) } "$n - returns correct remote boot snap";

$n = 'maybe_do_local_backup_bootstrap';
$f = \&App::Yabsm::Backup::Local::maybe_do_local_backup_bootstrap;

sleep 60;
lives_and { is $f->('foo_local_backup', \%TEST_CONFIG), $expected_boot_snap } "$n - doesn't redo bootstrap";

$n = 'do_local_backup';
$f = \&App::Yabsm::Backup::Local::do_local_backup;

my $expected_backup = "$BACKUP_DIR/".App::Yabsm::Snapshot::current_time_snapshot_name();
lives_and { is $f->('foo_local_backup', '5minute', \%TEST_CONFIG), $expected_backup } "$n - performs backup";

done_testing();

                 ####################################
                 #              CLEANUP             #
                 ####################################

sub cleanup_snapshots {

    opendir(my $dh, $BACKUP_DIR_BASE) if -d $BACKUP_DIR_BASE;
    if ($dh) {
        for (map { $_ = "$BACKUP_DIR_BASE/$_" } grep { $_ !~ /^(\.\.|\.)$/ } readdir($dh) ) {
            if (is_btrfs_subvolume($_)) {
                App::Yabsm::Snapshot::delete_snapshot($_)
            }
        }
    }

    opendir($dh, $BOOTSTRAP_DIR) if -d $BOOTSTRAP_DIR;
    if ($dh) {
        for (map { $_ = "$BOOTSTRAP_DIR/$_" } grep { $_ !~ /^(\.\.|\.)$/ } readdir($dh) ) {
            if (is_btrfs_subvolume($_)) {
                App::Yabsm::Snapshot::delete_snapshot($_)
            }
        }
    }

    opendir($dh, $TMP_DIR) if -d $TMP_DIR;
    if ($dh) {
        for (map { $_ = "$TMP_DIR/$_" } grep { $_ !~ /^(\.\.|\.)$/ } readdir($dh) ) {
            if (is_btrfs_subvolume($_)) {
                App::Yabsm::Snapshot::delete_snapshot($_)
            }
        }
    }

    opendir($dh, $BACKUP_DIR) if -d $BACKUP_DIR;
    if ($dh) {
        for (map { $_ = "$BACKUP_DIR/$_" } grep { $_ !~ /^(\.\.|\.)$/ } readdir($dh) ) {
            if (is_btrfs_subvolume($_)) {
                App::Yabsm::Snapshot::delete_snapshot($_)
            }
        }
    }

    closedir $dh if $dh;
}

cleanup_snapshots();

1;
