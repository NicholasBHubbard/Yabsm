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
use File::Temp 'tempfile';

# Import Config.pm
use FindBin '$Bin';
use lib "$Bin/../lib";

# Module to test
use Yabsm::Config 'parse_config_or_die';

# Change to directory of this test script.
use Cwd 'chdir';
use File::Basename qw(basename dirname);
chdir dirname $0;

# Test that all valid configs are accepted.
foreach my $config (glob "test-configs/valid/*") {
    lives_ok { parse_config_or_die($config) } 'should succeed: ' . basename($config);
}

# Test that all invalid configs are rejected.
foreach my $config (glob "test-configs/invalid/*") {
    dies_ok { parse_config_or_die($config) } 'should fail: ' . basename($config);
}

# Test that correct data structure is produced
my $config = <<'END_CONFIG';
# Example config
subvol home {
    mountpoint=/home
}
subvol root {
    mountpoint=/
}
snap home_snap {
    subvol=home
    dir=/.snapshots/yabsm/home
    timeframes=5minute,hourly,daily,weekly,monthly
    daily_time=23:59
    weekly_day=wednesday
    weekly_time=00:00
    monthly_day=31
    monthly_time=23:59
    5minute_keep=36
    hourly_keep=48
    daily_keep=365
    weekly_keep=56
    monthly_keep=12

}
snap root_snap {
    subvol=root
    dir=/.snapshots/yabsm/root
    timeframes=hourly,daily
    hourly_keep=72
    daily_time=07:03
    daily_keep=14
}
ssh_backup root_my_server {
    subvol=root
    ssh_dest=nick@192.168.1.37
    dir=/backups/btrfs/yabsm/desktop_root
    timeframes=5minute,hourly
    5minute_keep=24
    hourly_keep=24
}
local_backup home_external_drive {
    subvol=home
    dir=/mnt/backup_drive/yabsm/desktop_home
    timeframes=hourly
    hourly_keep=48
}
END_CONFIG

my %expected_config = (
    subvols => {
        root => {
            'mountpoint' => '/'
        },
        home => {
            'mountpoint' => '/home'
        }
    },
    local_backups => {
        home_external_drive => {
            subvol => 'home',
            hourly_keep => '48',
            timeframes => 'hourly',
            dir => '/mnt/backup_drive/yabsm/desktop_home'
        }
    },
    ssh_backups => {
        root_my_server => {
            '5minute_keep' => '24',
            subvol => 'root',
            hourly_keep => '24',
            ssh_dest => 'nick@192.168.1.37',
            timeframes => '5minute,hourly',
            dir => '/backups/btrfs/yabsm/desktop_root'
        }
    },
    snaps => {
        home_snap => {
            monthly_day => '31',
            subvol => 'home',
            daily_time => '23:59',
            hourly_keep => '48',
            monthly_time => '23:59',
            monthly_keep => '12',
            dir => '/.snapshots/yabsm/home',
            '5minute_keep' => '36',
            daily_keep => '365',
            weekly_keep => '56',
            timeframes => '5minute,hourly,daily,weekly,monthly',
            weekly_day => 'wednesday',
            weekly_time => '00:00'
        },
        root_snap => {
            daily_keep => '14',
            subvol => 'root',
            daily_time => '07:03',
            hourly_keep => '72',
            timeframes => 'hourly,daily',
            dir => '/.snapshots/yabsm/root'
        }
    }
);

my ($tmp_fh, $tmp_file) = tempfile( DIR => '/tmp', UNLINK => 1 );
print $tmp_fh $config;
close $tmp_fh;

my $got_config_ref = parse_config_or_die($tmp_file);

is_deeply( $got_config_ref, \%expected_config, 'parse production');

1;
