#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Testing for the Yabsm::Config::Parser library.

use strict;
use warnings;
use v5.16.3;

use App::Yabsm::Config::Parser qw(parse_config_or_die);

use Test::More 'no_plan';
use Test::Exception;
use File::Temp 'tempfile';

# Change to directory of this test script. Needed to find the test configs.
use File::Basename qw(basename dirname);
chdir(dirname(__FILE__));

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
yabsm_dir=/.snapshots/yabsm
subvol home {
    mountpoint=/home
}
subvol root {
    mountpoint=/
}
snap home_snap {
    subvol=home
    timeframes=5minute,hourly,daily,weekly,monthly
    daily_times=23:59,12:30
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
    timeframes=hourly,daily
    hourly_keep=72
    daily_times=07:03
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
    yabsm_dir => '/.snapshots/yabsm',
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
            daily_times => '23:59,12:30',
            hourly_keep => '48',
            monthly_time => '23:59',
            monthly_keep => '12',
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
            daily_times => '07:03',
            hourly_keep => '72',
            timeframes => 'hourly,daily'
        }
    }
);

my ($tmp_fh, $tmp_file) = tempfile( DIR => '/tmp', UNLINK => 1 );
print $tmp_fh $config;
close $tmp_fh;

my $got_config_ref = parse_config_or_die($tmp_file);

lives_and { is_deeply $got_config_ref, \%expected_config } 'parse production';

1;
