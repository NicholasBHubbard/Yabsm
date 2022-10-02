#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Testing for the the Yabsm::Backup::SSH library.

use strict;
use warnings;
use v5.16.3;

use App::Yabsm::Backup::SSH;

use App::Yabsm::Tools qw( :ALL );
use App::Yabsm::Snapshot;
use App::Yabsm::Backup::Generic;
use App::Yabsm::Config::Query;

use Test::More;
use Test::Exception;

use Net::OpenSSH;
use File::Temp qw(tempdir);
use File::Basename qw(basename dirname);

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);

my $USAGE = <<'END_USAGE';
Usage: SSHBackup.t -s <dir>

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

i_am_root() or plan skip_all => 'Must be root user';

defined $BTRFS_SUBVOLUME or plan skip_all => 'Failed to provide btrfs subvolume';

is_btrfs_subvolume($BTRFS_SUBVOLUME) or plan skip_all => "'$BTRFS_SUBVOLUME' is not a btrfs subvolume";

getpwnam('yabsm') or plan skip_all => q(no such user 'yabsm');

my $SSH = Net::OpenSSH->new( 'yabsm@localhost', remote_shell => 'sh', batch_mode => 1 );

$SSH->error and plan skip_all => q(root user could not connect to 'yabsm@localhost': ) . $SSH->error;

$SSH->system('sudo -n btrfs --help 1>/dev/null 2>&1')
  or plan skip_all => q(User 'yabsm' does not have sudo access to btrfs);

my $BTRFS_DIR = tempdir( 'yabsm-SSH.t-tmpXXXXXX', DIR => $BTRFS_SUBVOLUME, CLEANUP => 1 );

                 ####################################
                 #            TEST CONFIG           #
                 ####################################

my %TEST_CONFIG = ( yabsm_dir   => $BTRFS_DIR
                  , subvols     => { foo            => { mountpoint     => $BTRFS_SUBVOLUME } }
                  , ssh_backups => { foo_ssh_backup => { subvol         => 'foo'
                                                       , ssh_dest       => 'yabsm@localhost'
                                                       , dir            => "$BTRFS_DIR/foo_ssh_backup"
                                                       , timeframes     => '5minute'
                                                       , '5minute_keep' => 1
                                                       }
                                   }
                  );

my $BACKUP_DIR      = App::Yabsm::Config::Query::ssh_backup_dir('foo_ssh_backup', '5minute', \%TEST_CONFIG);
my $BACKUP_DIR_BASE = App::Yabsm::Config::Query::ssh_backup_dir('foo_ssh_backup', undef, \%TEST_CONFIG);
my $BACKUP          = "$BACKUP_DIR/" . App::Yabsm::Snapshot::current_time_snapshot_name();
my $BOOTSTRAP_DIR   = App::Yabsm::Backup::Generic::bootstrap_snapshot_dir('foo_ssh_backup','ssh',\%TEST_CONFIG);
my $TMP_DIR         = App::Yabsm::Backup::Generic::tmp_snapshot_dir('foo_ssh_backup','ssh','5minute',\%TEST_CONFIG);

                 ####################################
                 #               TESTS              #
                 ####################################

my $n;
my $f;

$n = 'new_ssh_conn';
$f = \&App::Yabsm::Backup::SSH::new_ssh_conn;
throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies if non-existent ssh_backup";

$n = 'ssh_system_or_die';
$f = \&App::Yabsm::Backup::SSH::ssh_system_or_die;
lives_and { is $f->($SSH, 'echo foo'), "foo\n" } "$n - returns correct output in scalar context";
lives_and { is_deeply [$f->($SSH, 'echo foo; echo bar')], ["foo\n","bar\n"] } "$n - returns correct output in list context";
throws_ok { $f->($SSH, 'false') } qr/remote command 'false' failed/, "$n - dies if command fails";

$n = 'check_ssh_backup_config_or_die';
$f = \&App::Yabsm::Backup::SSH::check_ssh_backup_config_or_die;
throws_ok { $f->($SSH, 'foo_ssh_backup', \%TEST_CONFIG) } qr/no directory '$BACKUP_DIR_BASE' that is readable\+writable by user 'yabsm'/, "$n - dies unless backup dir exists";
make_path_or_die($BACKUP_DIR_BASE);
throws_ok { $f->($SSH, 'foo_ssh_backup', \%TEST_CONFIG) } qr/no directory '$BACKUP_DIR_BASE' that is readable\+writable by user 'yabsm'/, "$n - dies unless backup dir is readable and writable by remote user";
system_or_die(qq(chown -R yabsm '$BTRFS_DIR'));
lives_and { is $f->($SSH, 'foo_ssh_backup', \%TEST_CONFIG), 1 } "$n - lives if properly configured";

$n = 'the_remote_bootstrap_snapshot';
$f = \&App::Yabsm::Backup::SSH::the_remote_bootstrap_snapshot;
lives_and { is $f->($SSH, 'foo_ssh_backup', \%TEST_CONFIG), undef } "$n - returns undef if no remote boot snap";

$n = 'do_ssh_backup';
$f = \&App::Yabsm::Backup::SSH::do_ssh_backup;
throws_ok { $f->($SSH, 'foo_ssh_backup', '5minute', \%TEST_CONFIG) } qr/no directory '$TMP_DIR' that is readable by user/, "$n - dies if tmp dir doesn't exist";
make_path_or_die($TMP_DIR);
throws_ok { $f->($SSH, 'foo_ssh_backup', '5minute', \%TEST_CONFIG) } qr/no directory '$BOOTSTRAP_DIR' that is readable by user/, "$n - dies if bootstrap dir doesn't exist";
make_path_or_die($BOOTSTRAP_DIR);
lives_ok { $f->($SSH, 'foo_ssh_backup', '5minute', \%TEST_CONFIG) } "$n - performs successful bootstrap";
my $lock_file = App::Yabsm::Backup::Generic::create_bootstrap_lock_file('foo_ssh_backup', 'ssh', \%TEST_CONFIG);
lives_and { is $f->($SSH, 'foo_ssh_backup', '5minute', \%TEST_CONFIG), undef } "$n - returns undef if bootstrap lock file exists";

$n = 'do_ssh_backup_bootstrap';
$f = \&App::Yabsm::Backup::SSH::do_ssh_backup_bootstrap;
lives_and { is $f->($SSH, 'foo_ssh_backup', \%TEST_CONFIG), undef } "$n - returns undef if lock file exists";
unlink $lock_file;
sleep 60;
my $got_boot_snap;
my $expected_boot_snap = "$BOOTSTRAP_DIR/.BOOTSTRAP-".App::Yabsm::Snapshot::current_time_snapshot_name();
lives_ok { $got_boot_snap = $f->($SSH, 'foo_ssh_backup', \%TEST_CONFIG) } "$n - performs another successful bootstrap";
is $got_boot_snap, $expected_boot_snap, "$n - replaces old bootstrap snapshot";

$n = 'the_remote_bootstrap_snapshot';
$f = \&App::Yabsm::Backup::SSH::the_remote_bootstrap_snapshot;
lives_and { is $f->($SSH, 'foo_ssh_backup', \%TEST_CONFIG), "$BACKUP_DIR_BASE/".basename($expected_boot_snap) } "$n - returns correct remote boot snap";

$n = 'maybe_do_ssh_backup_bootstrap';
$f = \&App::Yabsm::Backup::SSH::maybe_do_ssh_backup_bootstrap;
sleep 60;
lives_and { is $f->($SSH, 'foo_ssh_backup', \%TEST_CONFIG), $expected_boot_snap } "$n - doesn't do bootstrap if already done";

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
