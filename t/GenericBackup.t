#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Testing for the the Yabsm::Backup::Generic library.

use strict;
use warnings;
use v5.16.3;

use Yabsm::Backup::Generic;
use Yabsm::Snapshot;

use Yabsm::Tools qw( :ALL );

use Test::More 'no_plan';
use Test::Exception;

use File::Temp 'tempdir';

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);

my $USAGE = <<'END_USAGE';
Usage: Generic.t -s <dir>

Arguments:
  -h or --help   Print help (this message) and exit.
  -s <dir>       Use <dir> as subvolume to be snapshotted and used for
                 running btrfs related tests.
END_USAGE

GetOptions( 's=s'    => \my $BTRFS_SUBVOLUME
          , 'h|help' => \my $HELP
          );

print $USAGE and exit 0 if $HELP;

my $CAN_DO_BTRFS_TESTS;
my $BTRFS_TMP_DIR;
if (defined $BTRFS_SUBVOLUME) {
    unless (i_am_root()) {
        die "Must be root to run btrfs specific tests\n";
    }
    unless (is_btrfs_subvolume($BTRFS_SUBVOLUME)) {
        die "'$BTRFS_SUBVOLUME' is not a btrfs subvolume\n";
    }
    $BTRFS_TMP_DIR = tempdir( 'yabsm-Generic.tXXXXXX', DIR => $BTRFS_SUBVOLUME, CLEANUP => 1 );
    $CAN_DO_BTRFS_TESTS = 1;
}

                 ####################################
                 #               TESTS              #
                 ####################################

{
    my $n = 'is_backup_type_or_die';
    my $f = \&Yabsm::Backup::Generic::is_backup_type_or_die;

    lives_and { is $f->('ssh'), 1 } "$n - 1 if passed 'ssh'";
    lives_and { is $f->('local'), 1 } "$n - 1 if passed 'local'";
    throws_ok { $f->('quux') } qr/'quux' is not 'ssh' or 'local'/, "$n - dies if not 'ssh' or 'local'";
}

{
    my $n = 'is_bootstrap_snapshot_name';
    my $f = \&Yabsm::Backup::Generic::is_bootstrap_snapshot_name;

    is($f->('.BOOTSTRAP-yabsm-2020_05_13_23:59'), 1, "$n - returns 1 if valid");
    is($f->('quux'), 0, "$n - returns 0 if invalid");
    is($f->('yabsm-2020_05_13_23:59'), 0, "$n - rejects regular yabsm snapshot name");
}

{
    my $n = 'is_bootstrap_snapshot_name_or_die';
    my $f = \&Yabsm::Backup::Generic::is_bootstrap_snapshot_name_or_die;

    lives_and { is $f->('.BOOTSTRAP-yabsm-2020_05_13_23:59'), 1 } "$n - returns 1 if valid";
    throws_ok { $f->('quux') } qr/'quux' is not a valid yabsm bootstrap snapshot name/, "$n - dies if not a yabsm bootstrap snapshot name";
}

{
    my $n = 'bootstrap_snapshot_dir';
    my $f = \&Yabsm::Backup::Generic::bootstrap_snapshot_dir;

    my %test_config = ( yabsm_dir => '/foo'
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
    is($f->('foo_ssh_backup', 'ssh', \%test_config), '/foo/.yabsm-var/ssh_backups/foo_ssh_backup/bootstrap-snapshot', "$n - returns correct directory for ssh_backup");
    is($f->('foo_local_backup', 'local', \%test_config), '/foo/.yabsm-var/local_backups/foo_local_backup/bootstrap-snapshot', "$n - returns correct directory for local_backup");
    throws_ok { $f->('foo_ssh_backup', 'quux', \%test_config) } qr/'quux' is not 'ssh' or 'local'/, "$n - dies if invalid backup type";
}

{
    my $n = 'tmp_snapshot_dir';
    my $f = \&Yabsm::Backup::Generic::tmp_snapshot_dir;

    my %test_config = ( yabsm_dir => '/foo'
                      , subvols => { foo => { mountpoint => '/' } }
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
    is($f->('foo_ssh_backup', 'ssh', \%test_config), '/foo/.yabsm-var/ssh_backups/foo_ssh_backup/tmp-snapshot', "$n - returns correct directory for ssh_backup");
    is($f->('foo_local_backup', 'local', \%test_config), '/foo/.yabsm-var/local_backups/foo_local_backup/tmp-snapshot', "$n - returns correct directory for local_backup");
    throws_ok { $f->('foo_ssh_backup', 'quux', \%test_config) } qr/'quux' is not 'ssh' or 'local'/, "$n - dies if invalid backup type";
}


SKIP: {
    skip 'btrfs dependent tests - no subvolume provided via -s flag', 11 unless $CAN_DO_BTRFS_TESTS;

    # We only need %TEST_CONFIG for btrfs specific tests
    my %test_config = ( yabsm_dir   => "$BTRFS_TMP_DIR"
                      , subvols     => { foo            => { mountpoint     => '/' } }
                      , local_backups => { foo_local_backup => { subvol         => 'foo'
                                                               , dir            => "$BTRFS_TMP_DIR/local"
                                                               , timeframes     => '5minute'
                                                               , '5minute_keep' => 12
                                                               }
                                         }
                      );

    my $bootstrap_dir = Yabsm::Backup::Generic::bootstrap_snapshot_dir('foo_local_backup', 'local', \%test_config);
    my $bootstrap_snapshot = "$bootstrap_dir/". '.BOOTSTRAP-' . Yabsm::Snapshot::current_time_snapshot_name();

    my $tmp_snapshot_dir = Yabsm::Backup::Generic::tmp_snapshot_dir('foo_local_backup', 'local', \%test_config);
    my $tmp_snapshot = "$tmp_snapshot_dir/". Yabsm::Snapshot::current_time_snapshot_name();

    my $n;
    my $f;

    $n = 'backup_bootstrap_snapshot';
    $f = \&Yabsm::Backup::Generic::backup_bootstrap_snapshot;
    throws_ok { $f->('foo_local_backup', 'local', \%test_config) } qr/'$bootstrap_dir' is not a directory residing on a btrfs filesystem/, "$n - dies if bootstrap dir does not exist";

    $n = 'take_bootstrap_snapshot';
    $f = \&Yabsm::Backup::Generic::take_bootstrap_snapshot;
    throws_ok { $f->('foo_local_backup', 'local', \%test_config) } qr/'$bootstrap_dir' is not a directory residing on a btrfs filesystem/, "$n - dies if bootstrap directory doesn't exist";

    $n = 'take_tmp_snapshot';
    $f = \&Yabsm::Backup::Generic::take_tmp_snapshot;
    throws_ok { $f->('foo_local_backup', 'local', \%test_config) } qr/cannot opendir '$tmp_snapshot_dir'/, "$n - dies if bootstrap directory doesn't exist";

    make_path_or_die($bootstrap_dir);
    make_path_or_die($tmp_snapshot_dir);

    lives_and { is $f->('foo_local_backup', 'local', \%test_config), $tmp_snapshot } "$n - takes a tmp snapshot";
    Yabsm::Snapshot::delete_snapshot($tmp_snapshot);

    $n = 'backup_bootstrap_snapshot';
    $f = \&Yabsm::Backup::Generic::backup_bootstrap_snapshot;
    is($f->('foo_local_backup', 'local', \%test_config), undef, "$n - returns undef if no bootstrap snapshot");

    $n = 'take_bootstrap_snapshot';
    $f = \&Yabsm::Backup::Generic::take_bootstrap_snapshot;
    lives_and { is $f->('foo_local_backup', 'local', \%test_config), $bootstrap_snapshot } "$n - takes bootstrap snapshot";

    $n = 'backup_bootstrap_snapshot';
    $f = \&Yabsm::Backup::Generic::backup_bootstrap_snapshot;
    is($f->('foo_local_backup', 'local', \%test_config), $bootstrap_snapshot, "$n - returns bootstrap snapshot");

    open my $fh, '>', "$bootstrap_dir/foo";
    print $fh 'foo';
    close $fh;

    throws_ok { $f->('foo_local_backup', 'local', \%test_config) } qr/found multiple files in '$bootstrap_dir'/, "$n - dies if more than one bootstrap snapshot";

    $n = 'is_bootstrap_snapshot';
    $f = \&Yabsm::Backup::Generic::is_bootstrap_snapshot;
    is($f->($bootstrap_snapshot), 1, "$n - succeeds if a bootstrap snapshot");
    is($f->("$bootstrap_dir/foo"), 0, "$n - fails if not a bootstrap snapshot");

    $n = 'is_bootstrap_snapshot_or_die';
    $f = \&Yabsm::Backup::Generic::is_bootstrap_snapshot_or_die;
    lives_and { $f->($bootstrap_snapshot), 1 } "$n - succeeds if a bootstrap snapshot";
    throws_ok { $f->("$bootstrap_dir/.BOOTSTRAP-yabsm-2020_04_14_23:59") } qr/'$bootstrap_dir\/\.BOOTSTRAP-yabsm-2020_04_14_23:59' is not a btrfs subvolume/, "$n - dies if not a bootstrap snapshot";
    throws_ok { $f->('quux') } qr/'quux' is not a valid yabsm bootstrap snapshot name/, "$n - dies if not a valid bootstrap snapshot name";

    unlink "$bootstrap_dir/foo";

    Yabsm::Snapshot::delete_snapshot($bootstrap_snapshot);
}
