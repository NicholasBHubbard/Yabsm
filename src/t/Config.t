#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT
#
#  Testing for the Config.pm library.

use strict;
use warnings;
use v5.16.3;

use Test::More 'no_plan';
use Test::Exception;
use Time::Piece;
use List::Util 'shuffle';

# Import Config.pm
use FindBin '$Bin';
use lib "$Bin/../lib";

# Module to test
use Yabsm::Config;

print "Testing that all the valid configs parse successfully ...\n";
for my $config_file (glob './configs/valid/*') {
    lives_ok { Yabsm::Config::read_config($config_file) } $config_file;
}

print "\nTesting that all the invalid configs kill the program ...\n";
for my $config_file (glob './configs/invalid/*') {
    dies_ok { Yabsm::Config::read_config($config_file) } $config_file;
}

print "\nTesting read_config() returns correct data structure\n";
my $file_str = <<'EOF';
yabsm_dir=/.snapshots/yabsm

subvol root {
    mountpoint=/

    5minute_want=no

    hourly_want=yes
    hourly_keep=24

    daily_want=no

    weekly_want=yes
    weekly_day=tuesday
    weekly_time=23:59
    weekly_keep=7

    monthly_want=yes
    monthly_time=12:30
    monthly_keep=12
}

subvol home {
    mountpoint=/home

    5minute_want=yes
    5minute_keep=12

    hourly_want=no

    daily_want=yes
    daily_time=23:59
    daily_keep=14

    weekly_want=no

    monthly_want=no
}

backup rootBackup {
    subvol=root
    remote=no
    backup_dir=/
    keep=100
    timeframe=weekly
    day=friday
    time=23:59
}

backup homeBackup {
    subvol=home
    remote=yes
    host=foohost
    backup_dir=/home
    timeframe=hourly
    keep=12
}
EOF

my %t_conf = ( misc    => { yabsm_dir => '/.snapshots/yabsm' } 

             , subvols => { root => { mountpoint   => '/'
                                    , '5minute_want' => 'no'
                                    , hourly_want => 'yes'
                                    , hourly_keep => '24'
                                    , daily_want => 'no'
                                    , weekly_want => 'yes'
                                    , weekly_day => 'tuesday'
                                    , weekly_time => '23:59'
                                    , weekly_keep => '7'
                                    , monthly_want => 'yes'
                                    , monthly_time  => '12:30'
                                    , monthly_keep => '12'
                                    } 

                          , home => { mountpoint   => '/home'
                                    , '5minute_want' => 'yes'
                                    , '5minute_keep' => '12'
                                    , hourly_want => 'no'
                                    , daily_want => 'yes'
                                    , daily_time => '23:59'
                                    , daily_keep => '14'
                                    , weekly_want => 'no'
                                    , monthly_want => 'no'
                                    } 
                          }

             , backups => { rootBackup => { subvol => 'root'
                                          , remote => 'no'
                                          , backup_dir => '/'
                                          , keep => '100'
                                          , timeframe => 'weekly'
                                          , day => 'friday'
                                          , time => '23:59'
                                          }

                          , homeBackup => { remote => 'yes'
                                          , host => 'foohost'
                                          , subvol => 'home'
                                          , backup_dir => '/home'
                                          , timeframe => 'hourly'
                                          , keep => '12'
                                          }
                          }
             );


my $tmp_file = '/tmp/yabsm_tmp_conf';
`echo '$file_str' > $tmp_file`;
my $config_ref = Yabsm::Config::read_config($tmp_file);
`rm $tmp_file`;

is_deeply($config_ref, \%t_conf, 'data structure layout');
