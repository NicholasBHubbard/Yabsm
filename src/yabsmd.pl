#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  This is the yabsm daemon that takes snapshots and performs
#  backups at scheduled times based off the /etc/yabsmd.conf
#  configuration file.

use strict;
use warnings;
use v5.16.3;

use Carp;
use File::Path;
use Try::Tiny;
use Schedule::Cron;

use lib::relative 'lib';

use Yabsm::Base;
use Yabsm::Config;

die "yabsm: error: permission denied\n" if $<;

my $usage = "usage: yabsmd <start|stop|restart|status>\n";

my $resource_dir = '/run/yabsmd';
my $pid_file     = "$resource_dir/yabsmd.pid";
my $socket_path  = "$resource_dir/yabsmd.socket";

my $log_dir      = '/var/log/yabsmd';
my $std_log      = "$log_dir/yabsmd-std.log";
my $err_log      = "$log_dir/yabsmd-err.log";

open STDOUT, '>>', $std_log;
open STDERR, '>>', $err_log;

# Main

die $usage unless $#ARGV == 0 && $ARGV[0] =~ /^(start|stop|restart|status)$/;

$ARGV[0] eq 'start'   && yabsmd_start();
$ARGV[0] eq 'stop'    && yabsmd_stop();
$ARGV[0] eq 'restart' && yabsmd_restart();
$ARGV[0] eq 'status'  && yabsmd_status();

# Implementation

sub yabsmd_start {

    say "starting yabsmd ...";

    # It is customary for daemons to restart on SIGHUP.
    $SIG{HUP}  = \&yabsmd_restart;
    
    # Every signal that has a default disposition of Core or Term
    # will exit gracefully.
    $SIG{ABRT}   = \&yabsmd_stop;
    $SIG{ALRM}   = \&yabsmd_stop;
    $SIG{BUS}    = \&yabsmd_stop;
    $SIG{EMT}    = \&yabsmd_stop;
    $SIG{FPE}    = \&yabsmd_stop;
    $SIG{ILL}    = \&yabsmd_stop;
    $SIG{INT}    = \&yabsmd_stop;
    $SIG{IO}     = \&yabsmd_stop;
    $SIG{KILL}   = \&yabsmd_stop;
    $SIG{LOST}   = \&yabsmd_stop;
    $SIG{PIPE}   = \&yabsmd_stop;
    $SIG{PROF}   = \&yabsmd_stop;
    $SIG{PWR}    = \&yabsmd_stop;
    $SIG{QUIT}   = \&yabsmd_stop;
    $SIG{SEGV}   = \&yabsmd_stop;
    $SIG{STKFLT} = \&yabsmd_stop;
    $SIG{SYS}    = \&yabsmd_stop;
    $SIG{TERM}   = \&yabsmd_stop;
    $SIG{TRAP}   = \&yabsmd_stop;
    $SIG{USR1}   = \&yabsmd_stop;
    $SIG{USR2}   = \&yabsmd_stop;
    $SIG{VTALRM} = \&yabsmd_stop;
    $SIG{XCPU}   = \&yabsmd_stop;
    $SIG{XFSZ}   = \&yabsmd_stop;
    
    # Program will die with relevant error messages if config is invalid.
    my $config_ref = Yabsm::Config::read_config();

    rmtree $resource_dir if -d $resource_dir;
    mkdir $resource_dir;

    open my $fh, '>', $pid_file or die "yabsmd: error: failed to open file '$pid_file'\n";
    say $fh $$;
    close $fh;
    chmod 0644, $pid_file;

    # Shedule::Cron takes care of the entire underlying mechanism for
    # running a cron daemon.
    my $cron_scheduler = Schedule::Cron->new(
        sub { confess "yabsmd: internal error: default cron dispatcher invoked" }
    );

    Yabsm::Base::schedule_snapshots($config_ref, $cron_scheduler);
    Yabsm::Base::schedule_backups($config_ref, $cron_scheduler);

    $cron_scheduler->run();
}

sub yabsmd_stop {
    say "stopping yabsmd ...";
    rmtree $resource_dir if -d $resource_dir;
    exit 0;
}

sub yabsmd_restart {
    say "restarting yabsmd ...";
    yabsmd_stop();
    yabsmd_start();
}

sub yabsmd_status {
    if (-d $resource_dir) {
        open my $fh, '<', $pid_file or die "yabsmd: error: failed to open file '$pid_file'\n";
        my $pid = <$fh>;
        close $fh;
        say "yabsmd is running as pid $pid";
        exit 0;
    }
    else {
        say "yabsmd is not running";
        exit 1;
    }
}
