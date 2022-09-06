#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Testing for Yabsm::Command::Daemon.

use strict;
use warnings;
use v5.16.3;

use Yabsm::Command::Daemon;

use Test::More;
use Test::Exception;
use Yabsm::Snap;
use Yabsm::Tools qw( :ALL );

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use File::Temp 'tempdir';

my $USAGE = <<'END_USAGE';
Usage: Daemon.t [arguments]

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

have_prerequisites() or plan skip_all => q(Don't have OS prerequisites);

defined $BTRFS_SUBVOLUME or plan skip_all => 'Failed to provide btrfs subvolume';

is_btrfs_subvolume($BTRFS_SUBVOLUME) or plan skip_all => q('$BTRFS_SUBVOLUME' is not a btrfs subvolume);

i_am_root() or plan skip_all => 'Must be root user';

my $BTRFS_DIR = tempdir( 'yabsm-Daemon.t-tmpXXXXXX', DIR => $BTRFS_SUBVOLUME, CLEANUP => 1 );

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
                 #                TESTS             #
                 ####################################

my $n;
my $f;

$n = 'create_yabsm_user';
$f = \&Yabsm::Command::Daemon::create_yabsm_user;
SKIP: {
    skip q(User 'yabsm' already exists), 1 if 0 == system('id yabsm >/dev/null 2>&1');
    lives_and { $f->(\%TEST_CONFIG); ok (0 == system('id yabsm >/dev/null 2>&1') && 'L' eq (split ' ', `passwd -S yabsm`)[1]) } "$n - creates 'yabsm' user";
    system('userdel -r yabsm >/dev/null');
}

done_testing();

1;
