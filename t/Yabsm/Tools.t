#!/usr/bin/env/perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Testing for the Yabsm::Tools library.

use strict;
use warnings;
use v5.16.3;

use Yabsm::Tools;

use Test::More 'no_plan';
use Test::Exception;

use File::Basename;
use Time::Piece;
use File::Temp 'tempdir';

                 ####################################
                 #             OPTIONS              #
                 ####################################

use Getopt::Long qw/:config no_ignore_case no_auto_abbrev/;

my $usage = <<'END_USAGE';
Usage: plx BaseNew.t [arguments]

Arguments:
  -h or --help   Print help (this message) and exit
  -b <dir>       Test btrfs specific side effect in <dir>,
                 which must be a directory residing on a
                 btrfs subvolume.
END_USAGE

my $HELP;
my $BTRFS_DIR;

GetOptions('b=s' => \$BTRFS_DIR, 'help|h' => \$HELP) or die $usage;

print $usage and exit 0 if $HELP;

                 ####################################
                 #         TEST INFRASTRUCTURE      #
                 ####################################

my $THIS_DIR = dirname(__FILE__);

if (defined $BTRFS_DIR) {

    # User specified a btrfs dir with the -b flag

    die "BaseNew.t: error: $BTRFS_DIR does not reside on a btrfs filesystem\n"
      unless is_btrfs_dir($BTRFS_DIR);

    die "BaseNew.t: error: we do not have read+write permissions on $BTRFS_DIR\n"
      unless -r $BTRFS_DIR && -w $BTRFS_DIR;

    $BTRFS_DIR = tempdir('BaseNew.t-XXXXXX', CLEANUP => 1, DIR => $BTRFS_DIR);
}

my %TEST_CONFIG = ( subvols => { foo => { mountpoint => '/' }
                               , bar => { mountpoint => '/home' }
                               }
                  , snaps   => { foo_snap => { subvol => 'foo'
                                             , dir    =>  "$THIS_DIR/tmp"
                                             , timeframes => '5minute,hourly,daily,weekly,monthly'
                                             , '5minute_keep' => 36
                                             , hourly_keep => 48
                                             , daily_keep => 365
                                             , weekly_keep => 56
                                             , monthly_keep => 12
                                             , daily_time => '23:59'
                                             , weekly_day => 'wednesday'
                                             , weekly_time => '00:00'
                                             , monthly_day => 31
                                             , monthly_time => '23:59'
                                             }
                               , bar_snap => { subvol => 'bar'
                                             , dir    => "$THIS_DIR/tmp"
                                             , timeframes => '5minute'
                                             , '5minute_keep' => '24'
                                             }
                               }
                  , ssh_backups => { foo_ssh_backup => { subvol => 'foo'
                                                       , ssh_dest => 'localhost'
                                                       , dir    => "$THIS_DIR/tmp"
                                                       , timeframes => 'daily'
                                                       , daily_time => '23:59'
                                                       , daily_keep => 14
                                                       }
                                   , bar_ssh_backup => { subvol => 'bar'
                                                       , ssh_dest => 'localhost'
                                                       , dir => "$THIS_DIR/tmp"
                                                       , timeframes => 'hourly,daily'
                                                       , hourly_keep => 24
                                                       , daily_keep => 14
                                                       , daily_time => '23:59'
                                                       }
                                   }
                  , local_backups => { foo_local_backup => { subvol => 'foo'
                                                           , dir    => "$THIS_DIR/tmp"
                                                           , timeframes => 'daily'
                                                           , daily_time => '23:59'
                                                           , daily_keep => 14
                                                           }
                                     , bar_local_backup => { subvol => 'bar'
                                                           , dir    => "$THIS_DIR/tmp"
                                                           , timeframes => 'weekly'
                                                           , weekly_keep => 56
                                                           , weekly_day => 'monday'
                                                           , weekly_time => '00:00'
                                                           }
                                     }
                  );

                 ####################################
                 #               TESTS              #
                 ####################################

{
    my $n = 'die_arg_count';
    my $f = \&Yabsm::BaseNew::die_arg_count;

    throws_ok { $f->(1,1,73,37) } qr/passed 2 args but takes 1 arg/, "$n - dies with single number range";
    throws_ok { $f->(1,2,73,37,42) } qr/passed 3 args but takes 1-2 args/, "$n - dies with bounded range";
    throws_ok { $f->(2,1,73,37,42) } qr/passed 3 args but takes 1-2 args/, "$n - swaps upper lower ranges";
    throws_ok { $f->(1,1,73) } qr/called die_arg_count\(\) but arg count is in range/, "$n - detects valid arg range";
}

{
    my $n = 'is_snapshot_name';
    my $f = \&Yabsm::BaseNew::is_snapshot_name;

    is($f->('day=2020_05_13,time=23:59'), 1, "$n - expected true");
    is($f->('foo'), 0, "$n - expected false");
    is($f->('/home/day=2020_05_13,time=23:59'), 0, "$n - rejects file path");
    is($f->('day=2020_05_13,time=24:59'), 0, "$n - rejects time out of range")
}

{
    my $n = 'nums_to_snapshot_name';
    my $f = \&Yabsm::BaseNew::nums_to_snapshot_name;

    is($f->(2020, 5, 13, 1, 5), 'day=2020_05_13,time=01:05', "$n - produces snapshot name");
    throws_ok { $f->(2020, 13, 13, 1, 5) } qr/generated snapshot name with an invalid date/, "$n - dies if given invalid date";
}

{
    my $n = 'current_time_snapshot_name';
    my $f = \&Yabsm::BaseNew::current_time_snapshot_name;

    my $t = localtime();

    my ($yr, $mon, $day, $hr, $min) =
      map { sprintf '%02d', $_ } ($t->year, $t->mon, $t->mday, $t->hour, $t->min);

    is($f->(), "day=${yr}_${mon}_${day},time=$hr:$min", "$n - produces snapshot name for current time")
}

{
    my $n = 'snapshot_name_nums';
    my $f = \&Yabsm::BaseNew::snapshot_name_nums;

    is_deeply([ $f->('day=2020_05_13,time=23:59') ], [2020,5,13,23,59], "$n - produces correct number list");
    throws_ok { $f->('day=2020_5_13,time=23:59') } qr/passed invalid snapshot name/, "$n - dies if passed invalid snapshot name";
}

{
    my $n = 'all_subvols';
    my $f = \&Yabsm::BaseNew::all_subvols;

    is_deeply([ $f->(\%TEST_CONFIG) ], ['bar','foo'], "$n - returns correct subvol name list");
}

{
    my $n = 'all_snaps';
    my $f = \&Yabsm::BaseNew::all_snaps;

    my @arr = $f->(\%TEST_CONFIG);

    is_deeply([ $f->(\%TEST_CONFIG) ], ['bar_snap','foo_snap'], "$n - returns correct snap name list");
}

{
    my $n = 'all_ssh_backups';
    my $f = \&Yabsm::BaseNew::all_ssh_backups;

    is_deeply([ $f->(\%TEST_CONFIG) ], ['bar_ssh_backup', 'foo_ssh_backup'], "$n - returns correct ssh_backup name list");
}

{
    my $n = 'all_local_backups';
    my $f = \&Yabsm::BaseNew::all_local_backups;

    is_deeply([ $f->(\%TEST_CONFIG) ], ['bar_local_backup', 'foo_local_backup'], "$n - returns correct local_backup name list");
}

{
    my $n = 'all_snaps_of_subvol';
    my $f = \&Yabsm::BaseNew::all_snaps_of_subvol;

    is_deeply([ $f->('foo', \%TEST_CONFIG) ], [ 'foo_snap' ], "$n - returns correct snap list");
}

{
    my $n = 'all_ssh_backups_of_subvol';
    my $f = \&Yabsm::BaseNew::all_ssh_backups_of_subvol;

    is_deeply([ $f->('foo', \%TEST_CONFIG) ], [ 'foo_ssh_backup' ], "$n - returns correct ssh_backup list");
}

{
    my $n = 'all_local_backups_of_subvol';
    my $f = \&Yabsm::BaseNew::all_local_backups_of_subvol;

    is_deeply([ $f->('foo', \%TEST_CONFIG) ], [ 'foo_local_backup' ], "$n - returns correct local_backup list");
}

1;
