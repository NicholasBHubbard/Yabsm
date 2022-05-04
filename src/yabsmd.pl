#!/usr/bin/env perl

use strict;
use warnings;
use v5.16.3;

use English;

use File::Basename qw/dirname/;
use Carp;
use Daemon::Control;
use IO::Socket::UNIX;
use Algorithm::Cron;

use lib::relative 'lib';

use Yabsm::Base;
use Yabsm::Config;

exit Daemon::Control->new(
    name         => 'yabsmd',
    lsb_desc     => 'BTRFS snapshot daemon',
    lsb_start    => &yabsmd_start,
    lsb_stop     => &yabsmd_stop,
    user         => 'root',
    group        => 'root',
    path         => dirname(__FILE__),
    fork         => 2,
    stdout_file  => '/var/log/yabsmd',
    stderr_file  => '/var/log/yabsmd',
    resource_dir => '/run/yabsmd'
)->run;

sub yabsmd_start {

    $SIG{TERM} = \&yabsmd_stop;
    $SIG{INT}  = \&yabsmd_stop;
    $SIG{HUP}  = \&yabsmd_stop;

    my $config_ref = Yabsm::Config::read_config();

    unlink '/run/yabsmd/yabsmd.socket' if -e '/run/yabsmd/yabsmd.socket';
    
    my $socket = IO::Socket::UNIX->new(
        Local    => '/run/yabsmd/yabsmd.socket',
        Type     => SOCK_STREAM,
        Listen   => 1,
        Timeout  => 3,
        Blocking => 0
    ) or confess "yabsmd: internal error: could not create UNIX socket - $@";

    while (1) {

        if (my $conn = $socket->accept) {
            $conn->autoflush(1);
            while (my $data = <$conn>) {
                chomp $data;
                if ($data eq 'RELOAD_CONFIG') {
                    $config_ref = Yabsm::Config::read_config();
                    $conn->send("1\n");
                }
                else {
                    $conn->send("0\n");
                }
            }
            close $conn;
        }
        else {
            
        }
    }
}

sub yabsmd_stop {

    print "foo";

    exit 0;
}
