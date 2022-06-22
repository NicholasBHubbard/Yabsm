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
use Log::Log4perl 'get_logger';

use lib::relative 'lib';

use Yabsm::Base;
use Yabsm::Config;

main(@ARGV);

sub main {

    my $usage = "usage: yabsmd <start|stop|restart|status>\n";

    my $cmd = shift or die $usage;

    shift and die $usage;

    Log::Log4perl::init(do {
    my $log_config = q(
log4perl.category.Yabsm.Base       = ALL, Logfile
log4perl.appender.Logfile          = Log::Log4perl::Appender::File
log4perl.appender.Logfile.filename = /var/log/yabsmd.log
log4perl.appender.Logfile.mode     = append
log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Logfile.layout.ConversionPattern = %d [%M]: %m{chomp}%n
);
    \$log_config;
});

    if    ($cmd eq 'start')   { yabsmd_start()   }
    elsif ($cmd eq 'stop')    { yabsmd_stop()    }
    elsif ($cmd eq 'restart') { yabsmd_restart() }
    elsif ($cmd eq 'status')  { yabsmd_status()  }
    else                      { die $usage       }
}

sub yabsmd_pid {

    # If there is a running instance of yabsmd return its pid
    # otherwise return 0.

    my $pgrep_pid = `pgrep ^yabsmd | tr -d '\n'`;

    my $pid_file_pid;
    if (open my $fh, '<', '/run/yabsmd.pid') {
        chomp($pid_file_pid = <$fh>);
        close $fh;
    }

    my $is_running = $pid_file_pid && $pgrep_pid && $pid_file_pid eq $pgrep_pid;

    return $is_running ? $pgrep_pid : 0;
}

sub cleanup_and_exit {

    # Used as signal handler for default terminating signals.

    if (my $yabsmd_pid = yabsmd_pid()) {
        unlink '/run/yabsmd.pid';
        kill 'KILL', $yabsmd_pid;
    }

    else {
        get_logger->logconfess("yabsmd: internal error: can not find a running instance of yabsmd");
    }
}

sub yabsmd_start {

    die "yabsmd: error: permission denied\n" if $<;

    # There can only ever be one running instance of yabsmd.
    if (my $yabsmd_pid = yabsmd_pid()) {
        die "yabsmd: error: yabsmd is already running as pid $yabsmd_pid\n";
    }

    # Daemons should restart on a SIGHUP.
    $SIG{HUP}    = \&yabsmd_restart;

    # Yabsmd will exit gracefully on any signal that has a
    # default action of terminate or dump.
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
        sub { get_logger->logconfess("yabsmd: internal error: default cron dispatcher invoked") }
        , processprefix => 'yabsmd'
    );

    # Schedule the snapshots and backups based off the users config.
    Yabsm::Base::schedule_snapshots($config_ref, $cron_scheduler);
    Yabsm::Base::schedule_backups($config_ref, $cron_scheduler);

    my $pid = $cron_scheduler->run(detach => 1, pid_file => '/run/yabsmd.pid');

    say "yabsmd started as pid $pid";
}

sub yabsmd_stop {

    die "yabsmd: error: permission denied\n" if $<;

    if (my $pid = yabsmd_pid()) {
        say "Stopping yabsmd process running as pid $pid";
        kill 'TERM', $pid;
    }
    else {
        say STDERR "no running instance of yabsmd";
    }
}

sub yabsmd_restart {

    die "yabsmd: error: permission denied\n" if $<;

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
