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

die "yabsmd: error: permission denied\n" if $<;

my $yabsmd_pid_file = '/run/yabsmd.pid';

sub cleanup_and_exit {
    if (-r $yabsmd_pid_file) {
        open my $fh, '<', $yabsmd_pid_file;
        my $yabsmd_pid = <$fh>;
        close $fh;
        unlink $yabsmd_pid_file;
        kill 'KILL', $yabsmd_pid;
    }
    else {
        confess "yabsmd: internal error: cannot read $yabsmd_pid_file";
    }
}

sub main {
    
    # pid file is used as a lock to ensure theres only
    # one running instance of yabsmd.
    if (-f $yabsmd_pid_file) {
        die "yabsmd: error: there is already a running instance of yabsmd\n"
    }

    # Daemons ignore SIGHUP.
    $SIG{HUP}    = 'IGNORE';
    
    # Yabsmd will exit gracefully on any signal that has a
    # default disposition of core dump or terminate.
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
    
    $cron_scheduler->run(detach => 1, pid_file => $yabsmd_pid_file);
}

main();
