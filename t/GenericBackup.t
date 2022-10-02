#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Testing for the the Yabsm::Backup::Generic library.

use strict;
use warnings;
use v5.16.3;

use App::Yabsm::Backup::Generic;
use App::Yabsm::Snapshot;

use App::Yabsm::Tools qw( :ALL );

use Test::More;
use Test::Exception;

use File::Basename 'basename';
use File::Temp 'tempdir';
use File::Path;

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);

my $USAGE = <<'END_USAGE';
Usage: GenericBackup.t -s <dir>

Arguments:
  -h or --help   Print help (this message) and exit.
  -s <dir>       Use <dir> as subvolume to be snapshotted and used for
                 running btrfs related tests.
END_USAGE

GetOptions( 's=s'    => \my $BTRFS_SUBVOLUME
          , 'h|help' => \my $HELP
          );

print $USAGE and exit 0 if $HELP;

have_prerequisites() or plan skip_all => 'Missing OS prerequisites';

i_am_root() or plan skip_all => 'Must be root user';

defined $BTRFS_SUBVOLUME or plan skip_all => 'Failed to provide btrfs subvolume';

is_btrfs_subvolume($BTRFS_SUBVOLUME) or plan skip_all => "'$BTRFS_SUBVOLUME' is not a btrfs subvolume";

my $BTRFS_DIR = tempdir( 'yabsm-GenericBackup.t-tmpXXXXXX', DIR => $BTRFS_SUBVOLUME, CLEANUP => 1 );

                 ####################################
                 #             TEST CONFIG          #
                 ####################################

my %TEST_CONFIG = ( yabsm_dir => $BTRFS_DIR
                  , subvols => { foo => { mountpoint => $BTRFS_SUBVOLUME } }
                  , ssh_backups => { foo_ssh_backup => { subvol         => 'foo'
                                                       , ssh_dest       => 'yabsm-test@localhost'
                                                       , dir            => '/bar'
                                                       , timeframes     => '5minute'
                                                       , '5minute_keep' => 12
                                                       }
                                   }
                  , local_backups => { foo_local_backup => { subvol         => 'foo'
                                                           , dir            => '/baz'
                                                           , timeframes     => '5minute'
                                                           , '5minute_keep' => 12
                                                           }
                                     }
                  );

                 ####################################
                 #               TESTS              #
                 ####################################

{
    my $n = 'is_backup_type_or_die';
    my $f = \&App::Yabsm::Backup::Generic::is_backup_type_or_die;

    lives_and { is $f->('ssh'), 1 } "$n - 1 if passed 'ssh'";
    lives_and { is $f->('local'), 1 } "$n - 1 if passed 'local'";
    throws_ok { $f->('quux') } qr/'quux' is not 'ssh' or 'local'/, "$n - dies if not 'ssh' or 'local'";
}

# BOOTSTRAP SNAPSHOT TESTS
{
    my $n = 'bootstrap_snapshot_dir';
    my $f = \&App::Yabsm::Backup::Generic::bootstrap_snapshot_dir;

    my $expected_bootstrap_dir = "$BTRFS_DIR/.yabsm-var/ssh_backups/foo_ssh_backup/bootstrap-snapshot";

    lives_and { is $f->('foo_ssh_backup', 'ssh', \%TEST_CONFIG), $expected_bootstrap_dir } "$n - returns correct bootstrap dir";
    throws_ok { $f->('foo_ssh_backup', 'ssh', \%TEST_CONFIG, DIE_UNLESS_EXISTS => 1) } qr/no directory '$expected_bootstrap_dir' that is readable by user 'root'/, "$n - if DIE_UNLESS_EXISTS dies if bootstrap dir doesn't exist";
    make_path_or_die($expected_bootstrap_dir);
    lives_and { is $f->('foo_ssh_backup', 'ssh', \%TEST_CONFIG, DIE_UNLESS_EXISTS => 1), $expected_bootstrap_dir} "$n - returns correct directory if dir exists and DIE_UNLESS_EXISTS";

    $expected_bootstrap_dir = "$BTRFS_DIR/.yabsm-var/local_backups/foo_local_backup/bootstrap-snapshot";
    make_path_or_die($expected_bootstrap_dir);
    lives_and { is $f->('foo_local_backup', 'local', \%TEST_CONFIG, DIE_UNLESS_EXISTS => 1), $expected_bootstrap_dir } "$n - returns correct directory for local_backup";
    throws_ok { $f->('foo_ssh_backup', 'quux', \%TEST_CONFIG) } qr/'quux' is not 'ssh' or 'local'/, "$n - dies if invalid backup type";
}

{
    my $n;
    my $f;

    my $bootstrap_dir = App::Yabsm::Backup::Generic::bootstrap_snapshot_dir('foo_local_backup', 'local', \%TEST_CONFIG);

    $n = 'the_local_bootstrap_snapshot';
    $f = \&App::Yabsm::Backup::Generic::the_local_bootstrap_snapshot;

    lives_and { is $f->('foo_local_backup', 'local', \%TEST_CONFIG), undef } "$n - returns undef if there is no bootstrap snapshot";

    $n = 'take_bootstrap_snapshot';
    $f = \&App::Yabsm::Backup::Generic::take_bootstrap_snapshot;

    my $bootstrap_snapshot = $bootstrap_dir . '/.BOOTSTRAP-' . App::Yabsm::Snapshot::current_time_snapshot_name();

    lives_and { is $f->('foo_local_backup', 'local', \%TEST_CONFIG), $bootstrap_snapshot } "$n - takes bootstrap snapshot";
    sleep 60;
    $bootstrap_snapshot = $bootstrap_dir . '/.BOOTSTRAP-' . App::Yabsm::Snapshot::current_time_snapshot_name();
    lives_and { is $f->('foo_local_backup', 'local', \%TEST_CONFIG), $bootstrap_snapshot } "$n - takes second bootstrap snapshot";

    opendir my $dh, $bootstrap_dir or die "error: cannot opendir '$bootstrap_dir'\n";
    my @boot_snaps = grep { App::Yabsm::Snapshot::is_snapshot_name($_, ONLY_BOOTSTRAP => 1) } readdir($dh);
    closedir $dh;

    ok(1 == @boot_snaps && $boot_snaps[0] eq basename($bootstrap_snapshot), "$n - taking second bootstrap snapshot deletes the old bootstrap snapshot");

    $n = 'the_local_bootstrap_snapshot';
    $f = \&App::Yabsm::Backup::Generic::the_local_bootstrap_snapshot;

    lives_and { is $f->('foo_local_backup', 'local', \%TEST_CONFIG), $bootstrap_snapshot } "$n - return the bootstrap snapshot";

    sleep 60;

    $n = 'maybe_take_bootstrap_snapshot';
    $f = \&App::Yabsm::Backup::Generic::maybe_take_bootstrap_snapshot;

    lives_and { is $f->('foo_local_backup', 'local', \%TEST_CONFIG), $bootstrap_snapshot } "$n - doesn't take bootstrap snapshot if it already exists";

    App::Yabsm::Snapshot::delete_snapshot($bootstrap_snapshot);

    $n = 'bootstrap_lock_file';
    $f = \&App::Yabsm::Backup::Generic::bootstrap_lock_file;

    lives_and { is $f->('foo_local_backup', 'local', \%TEST_CONFIG), undef } "$n - returns undef in no lock file exists";

    $n = 'create_bootstrap_lock_file';
    $f = \&App::Yabsm::Backup::Generic::create_bootstrap_lock_file;

    lives_and {
        my $lock_fh = $f->('foo_local_backup', 'local', \%TEST_CONFIG);
        ok $lock_fh->filename =~ /BOOTSTRAP-LOCK/;
        throws_ok { $f->('foo_local_backup', 'local', \%TEST_CONFIG) } qr/local_backup 'foo_local_backup' is already locked out of performing a bootstrap/, "$n - dies if bootstrap lock already exists";
        $n = 'bootstrap_lock_file';
        $f = \&App::Yabsm::Backup::Generic::bootstrap_lock_file;
        lives_and { ok $f->('foo_local_backup', 'local', \%TEST_CONFIG) =~ /BOOTSTRAP-LOCK/ } "$n - returns correct lock file";
    } "$n - bootstrap lock file functions";
}

# TMP SNAPSHOT TESTS
{
    my $n;
    my $f;

    $n = 'tmp_snapshot_dir';
    $f = \&App::Yabsm::Backup::Generic::tmp_snapshot_dir;

    my $tmp_snapshot_dir = "$BTRFS_DIR/.yabsm-var/local_backups/foo_local_backup/tmp-snapshot/5minute";
    lives_and { $f->('foo_local_backup', 'local', '5minute', \%TEST_CONFIG), $tmp_snapshot_dir } "$n - returns path even if tmp dir doesn't exist";
    throws_ok { $f->('foo_local_backup', 'local', '5minute', \%TEST_CONFIG, DIE_UNLESS_EXISTS=>1) } qr/no directory '$tmp_snapshot_dir'/, "$n - dies if tmp dir doesn't exist and DIE_UNLESS_EXISTS";

    $n = 'take_tmp_snapshot';
    $f = \&App::Yabsm::Backup::Generic::take_tmp_snapshot;

    throws_ok { $f->('foo_local_backup', 'local', '5minute', \%TEST_CONFIG) } qr/no directory '$tmp_snapshot_dir'/, "$n - dies if tmp dir doesn't exist";

    make_path_or_die($tmp_snapshot_dir);

    $n = 'tmp_snapshot_dir';
    $f = \&App::Yabsm::Backup::Generic::tmp_snapshot_dir;

    lives_and { is $f->('foo_local_backup', 'local', '5minute', \%TEST_CONFIG, DIE_UNLESS_EXISTS=>1), $tmp_snapshot_dir } "$n - lives and returns correct dir if it exists and DIE_UNLESS_EXISTS";

    $n = 'take_tmp_snapshot';
    $f = \&App::Yabsm::Backup::Generic::take_tmp_snapshot;

    my $tmp_snapshot = "$tmp_snapshot_dir/".App::Yabsm::Snapshot::current_time_snapshot_name();
    lives_and { is $f->('foo_local_backup', 'local', '5minute', \%TEST_CONFIG), $tmp_snapshot } "$n - takes tmp snapshot";

    sleep 60;

    $tmp_snapshot = "$tmp_snapshot_dir/".App::Yabsm::Snapshot::current_time_snapshot_name();

    lives_and { is $f->('foo_local_backup', 'local', '5minute', \%TEST_CONFIG), $tmp_snapshot } "$n - takes tmp snapshot even if one exists";

    opendir my $dh, $tmp_snapshot_dir or die "error: cannot opendir '$tmp_snapshot_dir'\n";
    my @tmp_snaps = grep { App::Yabsm::Snapshot::is_snapshot_name($_) } readdir($dh);
    map { $_ = "$tmp_snapshot_dir/$_" } @tmp_snaps;
    closedir $dh;

    ok (1 == @tmp_snaps, "$n - deletes old tmp snapshot");

    App::Yabsm::Snapshot::delete_snapshot($_) for @tmp_snaps;
}

done_testing();

1;
