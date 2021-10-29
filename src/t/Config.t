#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT
#
#  Testing for the Config.pm library.

use strict;
use warnings;
use 5.010;

use Test::More 'no_plan';
use Test::Exception;
use Time::Piece;
use List::Util 'shuffle';

# Import Config.pm
use FindBin '$Bin';
use lib "$Bin/../lib";

# Module to test
use App::Config;

print "Testing that all the valid configs parse successfully ...\n";
for my $config_file (glob './configs/valid/*') {
    lives_ok { App::Config::read_config($config_file) } $config_file;
}

print "\nTesting that all the invalid configs kill the program ...\n";
for my $config_file (glob './configs/invalid/*') {
    dies_ok { App::Config::read_config($config_file) } $config_file;
}

print "\nTesting read_config() returns correct data structure\n";
my $file_str = <<'EOF';
yabsm_dir=/

subvol root {
    mountpoint=/

    5minute_want=no

    hourly_want=yes
    hourly_keep=24

    midnight_want=no

    weekly_want=yes
    weekly_keep=7
    weekly_day=tue

    monthly_want=yes
    monthly_keep=12
}

subvol home {
    mountpoint=/home

    5minute_want=yes
    5minute_keep=12

    hourly_want=no

    midnight_want=yes
    midnight_keep=14

    weekly_want=no

    monthly_want=no
}

backup rootBackup {
    subvol=root
    remote=no
    backup_dir=/
    keep=100
    timeframe=weekly
    weekly_day=friday
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

my %t_conf = ( misc    => { yabsm_dir => '/' } 

             , subvols => { root => { mountpoint   => '/'
                                    , '5minute_want' => 'no'
                                    , hourly_want => 'yes'
                                    , hourly_keep => '24'
                                    , midnight_want => 'no'
                                    , weekly_want => 'yes'
                                    , weekly_keep => '7'
                                    , weekly_day => 'tue'
                                    , monthly_want => 'yes'
                                    , monthly_keep => '12'
                                    } 

                          , home => { mountpoint   => '/home'
                                    , '5minute_want' => 'yes'
                                    , '5minute_keep' => '12'
                                    , hourly_want => 'no'
                                    , midnight_want => 'yes'
                                    , midnight_keep => '14'
                                    , weekly_want => 'no'
                                    , monthly_want => 'no'
                                    } 

                          }

             , backups => { rootBackup => { remote => 'no'
                                          , subvol => 'root'
                                          , backup_dir => '/'
                                          , keep => '100'
                                          , timeframe => 'weekly'
                                          , weekly_day => 'friday'
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
my $config_ref = App::Config::read_config($tmp_file);
`rm $tmp_file`;

is_deeply($config_ref, \%t_conf, 'data structure layout');
