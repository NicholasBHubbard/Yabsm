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
use Schedule::Cron;

use lib::relative 'lib';

use Yabsm::Base;
use Yabsm::Config;

my $usage = "usage: yabsmd <start|stop|restart|status>\n";
my $yabsmd_pid_file = '/run/yabsmd.pid';
  
main(@ARGV);

sub main {
    my $cmd = shift or die $usage;
    
    shift and die $usage;

    if    ($cmd eq 'start')   { yabsmd_start()   }
    elsif ($cmd eq 'stop')    { yabsmd_stop()    }
    elsif ($cmd eq 'restart') { yabsmd_restart() }
    elsif ($cmd eq 'status')  { yabsmd_status()  }
    else                      { die $usage       }
}

sub yabsmd_pid {

    # If there is a running instance of yabsmd return its pid
    # otherwise return 0.

    my $pid_file_pid;
    if (open my $fh, '<', $yabsmd_pid_file) {
        chomp($pid_file_pid = <$fh>);
        close $fh;
    }

    my $pgrep_pid = `pgrep ^yabsmd | tr -d '\n'`;

    my $is_running = $pid_file_pid && $pgrep_pid && $pid_file_pid eq $pgrep_pid;

    return $is_running ? $pgrep_pid : 0;
}

sub cleanup_and_exit {

    # Used as signal handler for default terminating signals. 
    
    if (my $yabsmd_pid = yabsmd_pid()) {
        unlink $yabsmd_pid_file;
        kill 'KILL', $yabsmd_pid;
    }
    
    else {
        confess "yabsmd: internal error: can not find a running instance of yabsmd";
    }
}

sub yabsmd_start {

    # There can only ever be one running instance of yabsmd.
    if (my $yabsmd_pid = yabsmd_pid()) {
        die "yabsmd: error: yabsmd is already running as pid $yabsmd_pid\n"
    }

    # Daemons ignore SIGHUP.
    $SIG{HUP}    = 'IGNORE';

    # Yabsmd will exit gracefully on any signal that has a
    # default disposition to core dump or terminate.
    $SIG{ABRT}   = \&cleanup_and_exit;
    $SIG{ALRM}   = \&cleanup_and_exit;
    $SIG{BUS}    = \&cleanup_and_exit;
    $SIG{FPE}    = \&cleanup_and_exit;
    $SIG{ILL}    = \&cleanup_and_exit;
    $SIG{INT}    = \&cleanup_and_exit;
    $SIG{IO}     = \&cleanup_and_exit;
    $SIG{KILL}   = \&cleanup_and_exit;
    $SIG{PIPE}   = \&cleanup_and_exit;
    $SIG{PROF}   = \&cleanup_and_exit;
    $SIG{PWR}    = \&cleanup_and_exit;
    $SIG{QUIT}   = \&cleanup_and_exit;
    $SIG{SEGV}   = \&cleanup_and_exit;
    $SIG{STKFLT} = \&cleanup_and_exit;
    $SIG{SYS}    = \&cleanup_and_exit;
    $SIG{TERM}   = \&cleanup_and_exit;
    $SIG{TRAP}   = \&cleanup_and_exit;
    $SIG{USR1}   = \&cleanup_and_exit;
    $SIG{USR2}   = \&cleanup_and_exit;
    $SIG{VTALRM} = \&cleanup_and_exit;
    $SIG{XCPU}   = \&cleanup_and_exit;
    $SIG{XFSZ}   = \&cleanup_and_exit;

    # Program will die with relevant error messages if config is invalid.
    my $config_ref = Yabsm::Config::read_config();

    # Shedule::Cron takes care of the entire underlying mechanism for
    # running a cron daemon.
    my $cron_scheduler = Schedule::Cron->new(
        sub { confess "yabsmd: internal error: default cron dispatcher invoked" }
        , processprefix => 'yabsmd'
    );

    Yabsm::Base::schedule_snapshots($config_ref, $cron_scheduler);
    Yabsm::Base::schedule_backups($config_ref, $cron_scheduler);

    my $pid = $cron_scheduler->run(detach => 1, pid_file => $yabsmd_pid_file);

    say "yabsmd started as pid $pid";
}

sub yabsmd_stop {
    if (my $pid = yabsmd_pid()) {
        say "Stopping yabsmd process running as pid $pid";
        kill 'TERM', $pid;
    }
    else {
        say STDERR "no running instance of yabsmd";
    }
}

sub yabsmd_restart {
    yabsmd_stop();
    sleep 1;
    yabsmd_start();
}

sub yabsmd_status {
    if (my $pid = yabsmd_pid()) {
        say "yabsmd is running as pid $pid";
    }
    else {
        say STDERR "no running instance of yabsmd";
    }
}
