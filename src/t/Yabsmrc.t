#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT
#
#  Testing for the Yabsmrc.pm library.

use strict;
use warnings;
use 5.010;

use Test::More 'no_plan';
use Test::Exception;
use Time::Piece;
use List::Util 'shuffle';

use lib '../lib';
use Yabsmrc;

print "Testing that all the valid configs parse successfully ...\n";
for my $config_file (glob './configs/valid/*') {
    lives_ok { Yabsmrc::read_config($config_file) } $config_file;
}

print "\nTesting that all the invalid configs kill the program ...\n";
for my $config_file (glob './configs/invalid/*') {
    dies_ok { Yabsmrc::read_config($config_file) } $config_file;
}

print "\nTesting read_config() returns correct data structure\n";
my $file_str = <<'EOF';
yabsm_dir=/

subvol root {
    mountpoint=/
    5minute_want=no
    5minute_keep=0
    hourly_want=yes
    hourly_keep=24
    midnight_want=no
    midnight_keep=0
    monthly_want=yes
    monthly_keep=12
}

subvol home {
    mountpoint=/home
    5minute_want=yes
    5minute_keep=12
    hourly_want=no
    hourly_keep=0
    midnight_want=yes
    midnight_keep=14
    monthly_want=no
    monthly_keep=5
}

backup rootBackup {
    remote=no
    subvol=root
    backup_dir=/
    timeframe=midnight
    keep=100
}

backup homeBackup {
    remote=yes
    host=foohost
    subvol=home
    backup_dir=/home
    timeframe=hourly
    keep=12
}
EOF

my %t_conf = ( misc    => { yabsm_dir => '/' } 

             , subvols => { root => { mountpoint   => '/'
                                    , '5minute_want' => 'no'
                                    , '5minute_keep' => '0'
                                    , hourly_want => 'yes'
                                    , hourly_keep => '24'
                                    , midnight_want => 'no'
                                    , midnight_keep => '0'
                                    , monthly_want => 'yes'
                                    , monthly_keep => '12'
                                    } 

                          , home => { mountpoint   => '/home'
                                    , '5minute_want' => 'yes'
                                    , '5minute_keep' => '12'
                                    , hourly_want => 'no'
                                    , hourly_keep => '0'
                                    , midnight_want => 'yes'
                                    , midnight_keep => '14'
                                    , monthly_want => 'no'
                                    , monthly_keep => '5'
                                    } 

                          }

             , backups => { rootBackup => { remote => 'no'
                                          , subvol => 'root'
                                          , backup_dir => '/'
                                          , timeframe => 'midnight'
                                          , keep => '100'
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
my $config_ref = Yabsmrc::read_config($tmp_file);
`rm $tmp_file`;

print "\ntesting correct data structure layout\n";
is_deeply($config_ref, \%t_conf, 'data structure layout');
