#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Testing for the the Yabsm::Backup::SSH library.

use strict;
use warnings;
use v5.16.3;

use Yabsm::Backup::SSH;

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
Usage: SSH.t -s <dir>

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

my $SSH = Net::OpenSSH->new( 'yabsm-test@localhost' );

$SSH->error and plan skip_all => q(Could not connect to 'yabsm-test@localhost': ) . $SSH->error;

$SSH->system('sudo -n btrfs --help 1>/dev/null 2>&1')
  or plan skip_all => q(User 'yabsm-test' does not have sudo access to btrfs);

my $BTRFS_DIR = tempdir( 'yabsm-SSH.t-tmpXXXXXX', DIR => $BTRFS_SUBVOLUME, CLEANUP => 1 );

                 ####################################
                 #            TEST CONFIG           #
                 ####################################

my %TEST_CONFIG = ( yabsm_dir   => "$BTRFS_DIR"
                  , subvols     => { foo            => { mountpoint     => $BTRFS_SUBVOLUME } }
                  , ssh_backups => { foo_ssh_backup => { subvol         => 'foo'
                                                       , ssh_dest       => 'yabsm-test@localhost'
                                                       , dir            => "$BTRFS_DIR/foo_ssh_backup"
                                                       , timeframes     => '5minute'
                                                       , '5minute_keep' => 1
                                                       }
                                   }
                  );

my $BACKUP_DIR      = Yabsm::Config::Query::ssh_backup_dir('foo_ssh_backup', '5minute', \%TEST_CONFIG);
my $BACKUP_DIR_BASE = Yabsm::Config::Query::ssh_backup_dir('foo_ssh_backup', undef, \%TEST_CONFIG);
my $BACKUP          = "$BACKUP_DIR/" . Yabsm::Snapshot::current_time_snapshot_name();
my $BOOTSTRAP_DIR   = Yabsm::Backup::Generic::bootstrap_snapshot_dir('foo_ssh_backup','ssh',\%TEST_CONFIG);
my $TMP_DIR         = Yabsm::Backup::Generic::tmp_snapshot_dir('foo_ssh_backup','ssh',\%TEST_CONFIG);

                 ####################################
                 #               TESTS              #
                 ####################################

my $n;
my $f;

$n = 'new_ssh_conn';
$f = \&Yabsm::Backup::SSH::new_ssh_conn;
throws_ok { $f->('quux', 1, \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies if non-existent ssh_backup";

$n = 'ssh_system_or_die';
$f = \&Yabsm::Backup::SSH::ssh_system_or_die;
lives_and { is $f->($SSH, 'echo foo'), "foo\n" } "$n - returns correct output in scalar context";
lives_and { is_deeply [$f->($SSH, 'echo foo; echo bar')], ["foo\n","bar\n"] } "$n - returns correct output in list context";
throws_ok { $f->($SSH, 'false') } qr/remote command 'false' failed/, "$n - dies if command fails";

$n = 'check_ssh_backup_config_or_die';
$f = \&Yabsm::Backup::SSH::check_ssh_backup_config_or_die;
# throws_ok { $f->($SSH, 'foo_ssh_backup', \%TEST_CONFIG) } qr/could not find directory '$BACKUP_DIR_BASE'/, "$n - dies unless backup dir exists";
throws_ok { $f->($SSH, 'foo_ssh_backup', \%TEST_CONFIG) } qr/no directory named '$BACKUP_DIR_BASE' that is readable\+writable to user 'yabsm-test'/, "$n - dies unless backup dir exists";
make_path_or_die($BACKUP_DIR_BASE);
throws_ok { $f->($SSH, 'foo_ssh_backup', \%TEST_CONFIG) } qr/no directory named '$BACKUP_DIR_BASE' that is readable\+writable to user 'yabsm-test'/, "$n - dies unless backup dir is readable and writable by remote user";
system_or_die(qq(chown -R yabsm-test '$BTRFS_DIR'));
lives_and { is $f->($SSH, 'foo_ssh_backup', \%TEST_CONFIG), 1 } "$n - lives if properly configured";

$n = 'do_ssh_backup';
$f = \&Yabsm::Backup::SSH::do_ssh_backup;
throws_ok { $f->($SSH, 'foo_ssh_backup', 'monthly', \%TEST_CONFIG) } qr/ssh_backup 'foo_ssh_backup' is not taking monthly backups/, "$n - dies if not taking tframe backups";
throws_ok { $f->($SSH, 'foo_ssh_backup', '5minute', \%TEST_CONFIG) } qr/'$BOOTSTRAP_DIR' is not a directory residing on a btrfs filesystem/, "$n - dies if bootstrap dir doesn't exist";
make_path_or_die($BOOTSTRAP_DIR);
throws_ok { $f->($SSH, 'foo_ssh_backup', '5minute', \%TEST_CONFIG) } qr/'$TMP_DIR' is not a directory residing on a btrfs filesystem/, "$n - dies if tmp dir doesn't exist";
make_path_or_die($TMP_DIR);
lives_and { is $f->($SSH, 'foo_ssh_backup', '5minute', \%TEST_CONFIG), $BACKUP } "$n - performs succesfull backup";

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
