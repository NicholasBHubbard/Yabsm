#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Implementation of the Yabsm daemon.

use strict;
use warnings;
use v5.16.3;

package Yabsm::Command::Daemon;

use Yabsm::Tools qw( :ALL );
use Yabsm::Config::Query qw( :ALL );
use Yabsm::Snap;
use Yabsm::Backup::SSH;
use Yabsm::Backup::Local;
use Yabsm::Config::Parser 'parse_config_or_die';

use Schedule::Cron;
use Log::Log4perl;

use Carp 'confess';
use POSIX;

                 ####################################
                 #               MAIN               #
                 ####################################

sub main {

    my $usage = 'usage: yabsm daemon <start|stop|restart|status>'."\n";

    my $cmd = shift or die $usage;
    @_ and die $usage;

    if    ($cmd eq 'start'  ) { yabsmd_start()   }
    elsif ($cmd eq 'stop'   ) { yabsmd_stop()    }
    elsif ($cmd eq 'restart') { yabsmd_restart() }
    elsif ($cmd eq 'status' ) { yabsmd_status()  }
    else {
        die $usage;
    }

    exit 0;
}

                 ####################################
                 #              DAEMON              #
                 ####################################

sub yabsmd_start {

    # Start the yabsm daemon.

    arg_count_or_die(0, 0, @_);

    die "yabsm: error: permission denied\n" unless i_am_root();
    
    # There can only ever be one running instance of yabsmd.
    if (my $yabsmd_pid = yabsmd_pid()) {
        die "yabsm: error: yabsmd is already running as pid $yabsmd_pid\n";
    }

    have_prerequisites_or_die();

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

    # Restart the daemon on a SIGHUP.
    $SIG{HUP}    = \&yabsmd_restart;

    # Gracefully exit on any signal that has a default action of terminate or
    # dump.
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

    my $config_ref = parse_config_or_die();

    initialize_runtime_environment($config_ref);

    my $yabsm_uid = getpwnam('yabsm');
    my $yabsm_gid = getgrnam('yabsm');

    open my $fh, '>', '/run/yabsmd.pid'
      or die q(yabsm: internal error: could not create file '/run/yabsmd.pid');
    close $fh;
    chown $yabsm_uid, $yabsm_gid, '/run/yabsmd.pid';
    chmod 0644, '/run/yabsmd.pid';

    POSIX::setuid($yabsm_uid);
    POSIX::setgid($yabsm_gid);

    my $pid = create_cron_scheduler($config_ref)->run(detach => 1, pid_file => '/run/yabsmd.pid');
    
    say $pid;

    return $pid;
}

sub yabsmd_stop {

    # Stop the yabsm daemon if it is running and exit.

    arg_count_or_die(0, 0, @_);

    die "yabsm: error: permission denied\n" unless i_am_root();
    
    if (my $pid = yabsmd_pid()) {
        say "Stopping yabsmd process running as pid $pid";
        unless (kill 'TERM', $pid) {
            die "yabsm: error: couldn't kill yabsmd process running as pid $pid";
        }
        return 1;
    }
    else { die "no running instance of yabsmd\n" }
}

sub yabsmd_restart {

    # Restart the yabsm daemon if it is running and exit.

    arg_count_or_die(0, 0, @_);

    die "yabsm: error: permission denied\n" unless i_am_root();

    yabsmd_stop();
    
    sleep 1;

    yabsmd_start();
}

sub yabsmd_status {

    # If the yabsm daemon is running print its pid.

    arg_count_or_die(0, 0, @_);

    if (my $pid = yabsmd_pid()) {
        say $pid;
        return 1;
    }
    else {
        die "no running instance of yabsmd\n";
    }
}

                 ####################################
                 #              HELPERS             #
                 ####################################

sub create_cron_scheduler {

    # Return a Schedule::Cron object that schedules every snap, ssh_backup, and
    # local_backup that is defined in the users config.

    arg_count_or_die(1, 1, @_);

    my $config_ref = shift;

    my $cron_scheduler = Schedule::Cron->new(
        sub { confess("yabsm: internal error: default Schedule::Cron dispatcher invoked") }
        , processprefix => 'yabsmd'
    );

    for my $snap (all_snaps($config_ref)) {
        if (snap_wants_timeframe($snap, '5minute', $config_ref)) {
            $cron_scheduler->add_entry(
                '*/5 * * * *',
                sub { with_error_catch_log(\&Yabsm::Snap::do_snap, $snap, '5minute', $config_ref) }
            );
        }
        if (snap_wants_timeframe($snap, 'hourly', $config_ref)) {
            $cron_scheduler->add_entry(
                '0 */1 * * *',
                sub { with_error_catch_log(\&Yabsm::Snap::do_snap, $snap, 'hourly', $config_ref) }
            );
        }
        if (snap_wants_timeframe($snap, 'daily', $config_ref)) {
            my $time = snap_daily_time($snap, $config_ref);
            my $hr   = time_hour($time);
            my $min  = time_minute($time);
            $cron_scheduler->add_entry(
                "$min $hr * * *",
                sub { with_error_catch_log(\&Yabsm::Snap::do_snap, $snap, 'daily', $config_ref) }
            );
        }
        if (snap_wants_timeframe($snap, 'weekly', $config_ref)) {
            my $time = snap_weekly_time($snap, $config_ref);
            my $hr   = time_hour($time);
            my $min  = time_minute($time);
            my $day  = weekday_number(snap_weekly_day($snap, $config_ref));
            $cron_scheduler->add_entry(
                "$min $hr * * $day",
                sub { with_error_catch_log(\&Yabsm::Snap::do_snap, $snap, 'weekly', $config_ref) }
            );
        }
        if (snap_wants_timeframe($snap, 'monthly', $config_ref)) {
            my $time = snap_monthly_time($snap, $config_ref);
            my $hr   = time_hour($time);
            my $min  = time_minute($time);
            my $day  = snap_monthly_day($snap, $config_ref);
            $cron_scheduler->add_entry(
                "$min $hr $day * *",
                sub { with_error_catch_log(\&Yabsm::Snap::do_snap, $snap, 'monthly', $config_ref) }
            );
        }
    }

    for my $ssh_backup (all_ssh_backups($config_ref)) {
        if (ssh_backup_wants_timeframe($ssh_backup, '5minute', $config_ref)) {
            $cron_scheduler->add_entry(
                '*/5 * * * *',
                sub { with_error_catch_log(\&Yabsm::Backup::SSH::do_ssh_backup, undef, $ssh_backup, '5minute', $config_ref) }
            );
        }
        if (ssh_backup_wants_timeframe($ssh_backup, 'hourly', $config_ref)) {
            $cron_scheduler->add_entry(
                '0 */1 * * *',
                sub { with_error_catch_log(\&Yabsm::Backup::SSH::do_ssh_backup, undef, $ssh_backup, 'hourly', $config_ref) }
            );
        }
        if (ssh_backup_wants_timeframe($ssh_backup, 'daily', $config_ref)) {
            my $time = ssh_backup_daily_time($ssh_backup, $config_ref);
            my $hr   = time_hour($time);
            my $min  = time_minute($time);
            $cron_scheduler->add_entry(
                "$min $hr * * *",
                sub { with_error_catch_log(\&Yabsm::Backup::SSH::do_ssh_backup, undef, $ssh_backup, 'daily', $config_ref) }
            );
        }
        if (ssh_backup_wants_timeframe($ssh_backup, 'weekly', $config_ref)) {
            my $time = ssh_backup_weekly_time($ssh_backup, $config_ref);
            my $hr   = time_hour($time);
            my $min  = time_minute($time);
            my $day  = weekday_number(ssh_backup_weekly_day($ssh_backup, $config_ref));
            $cron_scheduler->add_entry(
                "$min $hr * * $day",
                sub { with_error_catch_log(\&Yabsm::Backup::SSH::do_ssh_backup, undef, $ssh_backup, 'weekly', $config_ref) }
            );
        }
        if (ssh_backup_wants_timeframe($ssh_backup, 'monthly', $config_ref)) {
            my $time = ssh_backup_monthly_time($ssh_backup, $config_ref);
            my $hr   = time_hour($time);
            my $min  = time_minute($time);
            my $day  = ssh_backup_monthly_day($ssh_backup, $config_ref);
            $cron_scheduler->add_entry(
                "$min $hr $day * *",
                sub { with_error_catch_log(\&Yabsm::Backup::SSH::do_ssh_backup, undef, $ssh_backup, 'monthly', $config_ref) }
            );
        }
    }

    for my $local_backup (all_local_backups($config_ref)) {
        if (local_backup_wants_timeframe($local_backup, '5minute', $config_ref)) {
            $cron_scheduler->add_entry(
                '*/5 * * * *',
                sub { with_error_catch_log(\&Yabsm::Backup::Local::do_local_backup, $local_backup, '5minute', $config_ref) }
            );
        }
        if (local_backup_wants_timeframe($local_backup, 'hourly', $config_ref)) {
            $cron_scheduler->add_entry(
                '0 */1 * * *',
                sub { with_error_catch_log(\&Yabsm::Backup::Local::do_local_backup, $local_backup, 'hourly', $config_ref) }
            );
        }
        if (local_backup_wants_timeframe($local_backup, 'daily', $config_ref)) {
            my $time = local_backup_daily_time($local_backup, $config_ref);
            my $hr   = time_hour($time);
            my $min  = time_minute($time);
            $cron_scheduler->add_entry(
                "$min $hr * * *",
                sub { with_error_catch_log(\&Yabsm::Backup::Local::do_local_backup, $local_backup, 'daily', $config_ref) }
            );
        }
        if (local_backup_wants_timeframe($local_backup, 'weekly', $config_ref)) {
            my $time = local_backup_weekly_time($local_backup, $config_ref);
            my $hr   = time_hour($time);
            my $min  = time_minute($time);
            my $day  = weekday_number(local_backup_weekly_day($local_backup, $config_ref));
            $cron_scheduler->add_entry(
                "$min $hr * * $day",
                sub { with_error_catch_log(\&Yabsm::Backup::Local::do_local_backup, $local_backup, 'weekly', $config_ref) }
            );
        }
        if (local_backup_wants_timeframe($local_backup, 'monthly', $config_ref)) {
            my $time = local_backup_monthly_time($local_backup, $config_ref);
            my $hr   = time_hour($time);
            my $min  = time_minute($time);
            my $day  = local_backup_monthly_day($local_backup, $config_ref);
            $cron_scheduler->add_entry(
                "$min $hr $day * *",
                sub { with_error_catch_log(\&Yabsm::Backup::Local::do_local_backup, $local_backup, 'monthly', $config_ref) }
            );
        }
    }

    return $cron_scheduler;
}

sub initialize_runtime_environment {

    # Create all the directories needed for every snap, ssh_backup, and
    # local_backup. Create a locked user named 'yabsm', and add a sudoer rule to
    # grant this user root access to btrfs. Finally switch the processes uid and
    # gid to the new yabsm user.

    arg_count_or_die(1, 1, @_);

    my $config_ref = shift;

    i_am_root_or_die();

    my $yabsm_dir = yabsm_dir($config_ref);

    for my $snap (all_snaps($config_ref)) {
        for my $tframe (snap_timeframes($snap, $config_ref)) {
            make_path_or_die(snap_dest($snap, $tframe, $config_ref));
        }
    }

    for my $ssh_backup (all_ssh_backups($config_ref)) {
        make_path_or_die(Yabsm::Backup::Generic::bootstrap_snapshot_dir($ssh_backup, 'ssh', $config_ref));
        make_path_or_die(Yabsm::Backup::Generic::tmp_snapshot_dir($ssh_backup, 'ssh', $config_ref));
    }

    for my $local_backup (all_local_backups($config_ref)) {
        make_path_or_die(Yabsm::Backup::Generic::bootstrap_snapshot_dir($local_backup, 'local', $config_ref));
        make_path_or_die(Yabsm::Backup::Generic::tmp_snapshot_dir($local_backup, 'local', $config_ref));
        for my $tframe (local_backup_timeframes($local_backup, $config_ref)) {
            make_path_or_die(local_backup_dir($local_backup, $tframe, $config_ref));
        }
    }
    
    create_yabsm_user($config_ref);
    add_btrfs_sudoer_rule();
    
    return 1;
}

sub yabsm_user_home {

    # Return the yabsm users home directory.

    arg_count_or_die(1, 1, @_);

    return yabsm_dir( shift ) . '/.yabsm-var/yabsm-user-home';
}

sub create_yabsm_user {

    # Create a locked user on the host system named 'yabsm' or die.
    # If there is already a locked user named 'yabsm' then just
    # peacefully return 1.

    arg_count_or_die(1, 1, @_);

    my $config_ref = shift;

    i_am_root_or_die();

    # if yabsm user already exists
    if (0 == system('id yabsm >/dev/null 2>&1')) {

        # make sure the yabsm user is locked
        unless ('L' eq (split ' ', `passwd -S yabsm`)[1]) {
            confess(q(yabsm: error: found non-locked user named 'yabsm'));
        }
        
        return 1;
    }

    system_or_die('useradd', '-m', '-d', yabsm_user_home($config_ref), '-k', '/dev/null', 'yabsm');
    system_or_die('passwd', '-l', 'yabsm');
    
    return 1;
}

sub add_btrfs_sudoer_rule {

    # Add sudoer rule to grant $user sudo access to btrfs-progs.

    arg_count_or_die(0, 1, @_);

    my $user = shift // 'yabsm';

    i_am_root_or_die();

    my $sudoer_rule_file = "/etc/sudoers.d/$user-btrfs";

    unless (-f $sudoer_rule_file) {

        my $btrfs_bin = `which btrfs 2>/dev/null`
          or confess('yabsm: internal error: btrfs command not in root users path');

        my $sudoer_rule = "$user ALL=(root) NOPASSWD: $btrfs_bin\n";

        open my $fh, '>', $sudoer_rule_file
          or confess("yabsm: internal error: root user could not open '$sudoer_rule_file' for writing");

        print $fh $sudoer_rule;

        close $fh;
    }

    return $sudoer_rule_file;
}

sub yabsmd_pid {

    # If there is a running instance of yabsmd return its pid and otherwise
    # return 0.

    arg_count_or_die(0, 0, @_);

    chomp (my $pgrep_pid = `pgrep ^yabsmd`);

    my $pid_file_pid;
    if (open my $fh, '<', '/run/yabsmd.pid') {
        chomp($pid_file_pid = <$fh>);
        close $fh;
    }

    my $is_running = $pid_file_pid && $pgrep_pid && $pid_file_pid eq $pgrep_pid;

    return $is_running ? $pgrep_pid : 0;
}

sub cleanup_and_exit {

    # Used as signal handler for all default terminating signals.

    if (my $yabsmd_pid = yabsmd_pid()) {
        unlink '/run/yabsmd.pid';
        kill 'KILL', $yabsmd_pid;
    }
}

1;
