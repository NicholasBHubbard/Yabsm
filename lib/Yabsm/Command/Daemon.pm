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
use Yabsm::Config::Parser 'parse_config_or_die';
use Yabsm::Snap;
use Yabsm::Backup::SSH;
use Yabsm::Backup::Local;

use Schedule::Cron;
use Log::Log4perl;
use POSIX ();

use Carp 'confess';

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

    die q(yabsm: error: permission denied)."\n" unless i_am_root();
 
    # There can only ever be one running instance of yabsmd.
    if (my $yabsmd_pid = yabsmd_pid()) {
        die "yabsm: error: yabsmd is already running as pid $yabsmd_pid\n";
    }

    have_prerequisites_or_die();
    my $config_ref = parse_config_or_die();
    my ($yabsm_uid, $yabsm_gid) = create_yabsm_user_and_group($config_ref);
    install_signal_handlers();
    init_log4perl();
    create_runtime_dirs($config_ref);

    open my $pid_fh, '>', '/run/yabsmd.pid'
      or die q(yabsm: internal error: cannot not open file '/run/yabsmd.pid' for writing)."\n";
    close $pid_fh;
    chown $yabsm_uid, $yabsm_gid, '/run/yabsmd.pid';
    chmod 0644, '/run/yabsmd.pid';

    POSIX::setuid($yabsm_uid);
    POSIX::setgid($yabsm_gid);

    create_yabsm_user_ssh_key(0, $config_ref);

    my $pid = create_cron_scheduler($config_ref)->run(detach => 1, pid_file => '/run/yabsmd.pid');
    
    say "started yabsmd as pid $pid";
    
    return $pid;
}

sub yabsmd_stop {

    # Stop the yabsm daemon if it is running and exit.

    arg_count_or_die(0, 0, @_);

    die q(yabsm: error: permission denied)."\n" unless i_am_root();
    
    if (my $pid = yabsmd_pid()) {
        if (kill 'TERM', $pid) {
            say "terminated yabsmd process running as pid $pid";
            return $pid;
        }
        else {
            die "yabsm: error: cannot terminate yabsmd process running as pid $pid\n";
        }
    }
    else { die "no running instance of yabsmd\n" }
}

sub yabsmd_restart {

    # Restart the yabsm daemon if it is running and exit.

    arg_count_or_die(0, 0, @_);

    die q(yabsm: error: permission denied)."\n" unless i_am_root();

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
        sub { confess("yabsm: internal error: default Schedule::Cron dispatcher was invoked") }
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

sub create_runtime_dirs {

    # Create the directories needed for every snap, ssh_backup, and local_backup.
    # Create a locked user named 'yabsm', and a group named yabsm if they do not
    # already exist. Add a sudoer rule to grant the yabsm user root access to
    # btrfs.
    #
    # G

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

    return 1;
}

sub create_yabsm_user_and_group { # Not tested

    # Create a locked-user and group named 'yabsm' if they do not already exist.

    arg_count_or_die(1, 1, @_);

    my $config_ref = shift;

    i_am_root_or_die();

    unless (yabsm_user_exists()) {
        # useradd will automatically create a group named 'yabsm'.
        system_or_die('useradd', '-m', yabsm_user_home($config_ref), '-k', '/dev/null', 'yabsm');
        system_or_die('passwd', '--lock', 'yabsm');
    }

    unless (yabsm_group_exists()) {
        system_or_die('groupadd', 'yabsm');
    }

    my $yabsm_uid = getpwnam('yabsm');
    my $yabsm_gid = getgrnam('yabsm');

    return wantarray ? ($yabsm_uid, $yabsm_gid) : 1;
}

sub yabsm_user_exists { # Not tested

    # Return 1 if there exists a locked user on the system named 'yabsm'.

    arg_count_or_die(0, 0, @_);

    i_am_root_or_die();

    unless (0 == system('getent passwd yabsm >/dev/null 2>&1')) {
        return 0;
    }

    unless ('L' eq (split ' ', `passwd -S yabsm`)[1]) {
        die q(yabsm: error: found non-locked user named 'yabsm')."\n";
    }

    return 1;
}

sub yabsm_group_exists { # Not tested

    # Return 1 if there exists on the system a user and group named 'yabsm' and
    # return 0 otherwise.

    arg_count_or_die(0, 0, @_);

    i_am_root_or_die();

    return 0+(0 == system('getent group yabsm >/dev/null 2>&1'));
}

sub add_yabsm_user_btrfs_sudoer_rule { # Not tested

    # Add sudoer rule to '/etc/sudoers.d/yabsm-btrfs' to grant the 'yabsm' user
    # sudo access to btrfs-progs.

    arg_count_or_die(0, 0, @_);

    i_am_root_or_die();

    my $file = '/etc/sudoers.d/yabsm-btrfs';

    unless (-f $file) {
        my $btrfs_bin = `which btrfs 2>/dev/null`
          or confess('yabsm: internal error: btrfs-progs not in root users path');

        my $sudoer_rule = "yabsm ALL=(root) NOPASSWD $btrfs_bin";

        open my $fh, '>', $file
          or confess("yabsm: internal error: could not open '$file' for writing");

        print $fh $sudoer_rule;

        close $fh
    }

    return $file;
}

sub yabsm_user_home { # Not tested

    # Return the yabsm users home directory.

    arg_count_or_die(1, 1, @_);

    return yabsm_dir( shift ) . '/.yabsm-var/yabsm-user-home';
}

sub yabsmd_pid { # Not tested

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

    return $is_running ? $pid_file_pid : 0;
}

sub init_log4perl { # Not tested

    # TODO

    arg_count_or_die(0, 0, @_);

    i_am_root_or_die();

    my $log_file = '/var/log/yabsmd';
    
    unless (yabsm_user_exists()) {
        die q(yabsm: internal error: cannot find user named 'yabsm')."\n";
    }
    unless (yabsm_group_exists()) {
        die q(yabsm: internal error: cannot find group named 'yabsm')."\n";
    }

    open my $log_fh, '>>', $log_file
      or die "yabsm: internal error: cannot open '$log_file' for writing\n";
    close $log_fh;

    my $yabsm_uid = getpwnam('yabsm');
    my $yabsm_gid = getgrnam('yabsm');
    chown $yabsm_uid, $yabsm_gid, $log_file;
    chmod 0644, $log_file;

    Log::Log4perl::init(do {
        my $log_config = qq(
log4perl.category.Yabsm            = ALL, Logfile
log4perl.appender.Logfile          = Log::Log4perl::Appender::File
log4perl.appender.Logfile.filename = $log_file
log4perl.appender.Logfile.mode     = append
log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Logfile.layout.ConversionPattern = %d [%M]: %m{chomp}%n
);
        \$log_config;
    });

    return 1;
}

sub install_signal_handlers { # Not tested

    # Install a handler for all signals with a default action of terminate or
    # dump to ensure we remove /run/yabsmd.pid before exiting.
    #
    # Handle SIGHUP by restarting yabsmd.

    # Restart the daemon on a SIGHUP.
    $SIG{HUP}    = \&yabsmd_restart;

    # Gracefully exit on any signal that has a default action of terminate or
    # dump.
    my $cleanup_and_exit = sub {
        unlink '/run/yabsmd.pid';
        exit 0;
    };

    $SIG{ABRT}   = $cleanup_and_exit;
    $SIG{ALRM}   = $cleanup_and_exit;
    $SIG{BUS}    = $cleanup_and_exit;
    $SIG{FPE}    = $cleanup_and_exit;
    $SIG{ILL}    = $cleanup_and_exit;
    $SIG{INT}    = $cleanup_and_exit;
    $SIG{IO}     = $cleanup_and_exit;
    $SIG{KILL}   = $cleanup_and_exit;
    $SIG{PIPE}   = $cleanup_and_exit;
    $SIG{PROF}   = $cleanup_and_exit;
    $SIG{PWR}    = $cleanup_and_exit;
    $SIG{QUIT}   = $cleanup_and_exit;
    $SIG{SEGV}   = $cleanup_and_exit;
    $SIG{STKFLT} = $cleanup_and_exit;
    $SIG{SYS}    = $cleanup_and_exit;
    $SIG{TERM}   = $cleanup_and_exit;
    $SIG{TRAP}   = $cleanup_and_exit;
    $SIG{USR1}   = $cleanup_and_exit;
    $SIG{USR2}   = $cleanup_and_exit;
    $SIG{VTALRM} = $cleanup_and_exit;
    $SIG{XCPU}   = $cleanup_and_exit;
    $SIG{XFSZ}   = $cleanup_and_exit;
}

sub create_yabsm_user_ssh_key { # Not tested

    # Create an SSH key for the yabsm user if one doesn't already exist. This
    # function dies unless the processes ruid and rgid are that of the yabsm user
    # and group.
    #
    # If the $force value is false then only create the key if the users
    # configuration defines at least one ssh_backup, and if it is true then
    # create the key even if no ssh_backup's are defined.

    arg_count_or_die(2, 2, @_);
    
    my $force      = shift;
    my $config_ref = shift;

    if ($force || all_ssh_backups($config_ref)) {

        my $yabsm_uid = getpwnam('yabsm') or confess(q(yabsm: internal error: cannot find user named 'yabsm'));
        my $yabsm_gid = getgrnam('yabsm') or confess(q(yabsm: internal error: cannot find group named 'yabsm'));

        unless ($< == $yabsm_uid && $( == $yabsm_gid) {
            my $username = getpwuid $<;
            die "yabsm: error: cannot create SSH key for user 'yabsm' when running as user '$username'\n";
        }

        my $yabsm_user_home = yabsm_user_home($config_ref);

        my $ssh_dir  = "$yabsm_user_home/.ssh";
        my $priv_key = "$ssh_dir/id_ed25519";
        my $pub_key  = "$ssh_dir/id_ed25519.pub";

        unless (-f $priv_key && -f $pub_key) {
            system_or_die('ssh-keygen', '-t', 'ed25519');
            chown $yabsm_uid, $yabsm_gid, $priv_key, $pub_key;
            chmod 0600, $priv_key;
            chmod 0644, $pub_key;
        }

        return 1;
    }

    return 0;
}

1;
