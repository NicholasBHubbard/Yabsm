#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Provides functions for querying the Yabsm configuration hash that is produced
#  by Yabsm::Config::Parser::parse_config_or_die().

use strict;
use warnings;
use v5.16.3;

package App::Yabsm::Config::Query;

use App::Yabsm::Tools qw(arg_count_or_die);

use Carp qw(confess);

use Exporter qw(import);
our @EXPORT_OK = qw(is_timeframe
                    is_timeframe_or_die
                    is_weekday
                    is_weekday_or_die
                    time_hour
                    time_minute
                    yabsm_dir
                    yabsm_user_home
                    subvol_exists
                    subvol_exists_or_die
                    snap_exists
                    snap_exists_or_die
                    ssh_backup_exists
                    ssh_backup_exists_or_die
                    local_backup_exists
                    local_backup_exists_or_die
                    backup_exists
                    backup_exists_or_die
                    all_subvols
                    all_snaps
                    all_ssh_backups
                    all_local_backups
                    subvol_mountpoint
                    snap_subvol
                    snap_mountpoint
                    snap_dest
                    snap_dir
                    snap_timeframes
                    ssh_backup_subvol
                    ssh_backup_mountpoint
                    ssh_backup_dir
                    ssh_backup_timeframes
                    ssh_backup_ssh_dest
                    local_backup_subvol
                    local_backup_mountpoint
                    local_backup_dir
                    local_backup_timeframes
                    all_snaps_of_subvol
                    all_ssh_backups_of_subvol
                    all_local_backups_of_subvol
                    snap_wants_timeframe
                    snap_wants_timeframe_or_die
                    ssh_backup_wants_timeframe
                    ssh_backup_wants_timeframe_or_die
                    local_backup_wants_timeframe
                    local_backup_wants_timeframe_or_die
                    snap_timeframe_keep
                    snap_5minute_keep
                    snap_hourly_keep
                    snap_daily_keep
                    snap_daily_times
                    snap_weekly_keep
                    snap_weekly_time
                    snap_weekly_day
                    snap_monthly_keep
                    snap_monthly_time
                    snap_monthly_day
                    ssh_backup_timeframe_keep
                    ssh_backup_5minute_keep
                    ssh_backup_hourly_keep
                    ssh_backup_daily_keep
                    ssh_backup_daily_times
                    ssh_backup_weekly_keep
                    ssh_backup_weekly_time
                    ssh_backup_weekly_day
                    ssh_backup_monthly_keep
                    ssh_backup_monthly_time
                    ssh_backup_monthly_day
                    local_backup_timeframe_keep
                    local_backup_5minute_keep
                    local_backup_hourly_keep
                    local_backup_daily_keep
                    local_backup_daily_times
                    local_backup_weekly_keep
                    local_backup_weekly_time
                    local_backup_weekly_day
                    local_backup_monthly_keep
                    local_backup_monthly_time
                    local_backup_monthly_day
                   );
our %EXPORT_TAGS = ( ALL => [ @EXPORT_OK ] );

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub is_timeframe {

    # Return 1 if given a valid timeframe and return 0 otherwise.

    arg_count_or_die(1, 1, @_);

    return 0+(shift =~ /^(5minute|hourly|daily|weekly|monthly)$/);
}

sub is_timeframe_or_die {

    # Wrapper around &is_timeframe that Carp::Confess's if it returns false.

    arg_count_or_die(1, 1, @_);

    my $tframe = shift;

    unless ( is_timeframe($tframe) ) {
        confess("yabsm: internal error: no such timeframe '$tframe'");
    }

    return 1;
}

sub is_weekday {

    # Return 1 if given a valid week day and return 0 otherwise.

    arg_count_or_die(1, 1, @_);

    return 0+(shift =~ /^(monday|tuesday|wednesday|thursday|friday|saturday|sunday)$/);
}

sub is_weekday_or_die {

    # Wrapper around &is_weekday that Carp::Confess's if it returns false.

    arg_count_or_die(1, 1, @_);

    my $weekday = shift;

    unless ( is_weekday($weekday) ) {
        confess("yabsm: internal error: no such weekday '$weekday'");
    }

    return 1;
}

sub weekday_number {

    # Return the number associated with $weekday which is a string representation
    # of a weekday. Monday is considered the first day of the week.

    arg_count_or_die(1, 1, @_);

    my $weekday = shift;

    is_weekday_or_die($weekday);

    $weekday eq 'monday'    and return 1;
    $weekday eq 'tuesday'   and return 2;
    $weekday eq 'wednesday' and return 3;
    $weekday eq 'thursday'  and return 4;
    $weekday eq 'friday'    and return 5;
    $weekday eq 'saturday'  and return 6;
    $weekday eq 'sunday'    and return 7;
}

sub is_time {

    # Return 1 if passed a valid 'hh:mm' time and return 0 otherwise.

    arg_count_or_die(1, 1, @_);

    my ($hr, $min) = shift =~ /^(\d\d):(\d\d)$/
      or return 0;

    $hr  >= 0 && $hr  <= 23 or return 0;
    $min >= 0 && $min <= 59 or return 0;

    return 1;
}

sub is_time_or_die {

    # Wrapper around &is_time that Carp::Confess's if it returns false.

    arg_count_or_die(1, 1, @_);

    my $time = shift;

    unless ( is_time($time) ) {
        confess("yabsm: internal error: '$time' is not a valid 'hh:mm' time");
    }

    return 1;
}

sub time_hour {

    # Return the hour of a 'hh:mm' time.

    arg_count_or_die(1, 1, @_);

    my $time = shift;

    is_time_or_die($time);

    my ($hr) = $time =~ /^(\d\d):\d\d$/;

    return 0+$hr;
}

sub time_minute {

    # Return the minute of a 'hh:mm' time.

    arg_count_or_die(1, 1, @_);

    my $time = shift;

    is_time_or_die($time);

    my ($min) = $time =~ /^\d\d:(\d\d)$/;

    return 0+$min;
}

sub yabsm_dir {

    # Return the users yabsm_dir without trailing /'s.

    arg_count_or_die(1, 1, @_);

    my $config_ref = shift;

    return $config_ref->{yabsm_dir} =~ s/\/+$//r;
}

sub yabsm_user_home {

    # Return the yabsm users home directory.

    arg_count_or_die(1, 1, @_);

    return yabsm_dir( shift ) . '/.yabsm-var/yabsm-user-home';
}

sub subvol_exists {

    # Return 1 if $subvol is a subvol defined in $config_ref and return 0
    # otherwise.

    arg_count_or_die(2, 2, @_);

    my $subvol     = shift;
    my $config_ref = shift;

    return 0+(exists $config_ref->{subvols}{$subvol});
}

sub subvol_exists_or_die {

    # Wrapper around &subvol_exists that Carp::Confess's if it returns false.

    arg_count_or_die(2, 2, @_);

    my $subvol     = shift;
    my $config_ref = shift;

    unless ( subvol_exists($subvol, $config_ref) ) {
        confess("yabsm: internal error: no subvol named '$subvol'");
    }

    return 1;
}

sub snap_exists {

    # Return 1 if $snap is a snap defined in $config_ref and return 0 otherwise.

    arg_count_or_die(2, 2, @_);

    my $snap     = shift;
    my $config_ref = shift;

    return 0+(exists $config_ref->{snaps}{$snap});
}

sub snap_exists_or_die {

    # Wrapper around &snap_exists that Carp::Confess's if it returns false.

    arg_count_or_die(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    unless ( snap_exists($snap, $config_ref) ) {
        confess("yabsm: internal error: no snap named '$snap'");
    }

    return 1;
}

sub ssh_backup_exists {

    # Return 1 if $ssh_backup is a ssh_backup defined in $config_ref and return 0
    # otherwise.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    return 0+(exists $config_ref->{ssh_backups}{$ssh_backup});
}

sub ssh_backup_exists_or_die {

    # Wrapper around &ssh_backup_exists that Carp::Confess's if it returns false.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    unless ( ssh_backup_exists($ssh_backup, $config_ref) ) {
        confess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    return 1;
}

sub local_backup_exists {

    # Return 1 if $local_backup is a lcoal_backup defined in $config_ref and
    # return 0 otherwise.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    return 0+(exists $config_ref->{local_backups}{$local_backup});
}

sub local_backup_exists_or_die {

    # Wrapper around &local_backup_exists that Carp::Confess's if it returns
    # false.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    unless ( local_backup_exists($local_backup, $config_ref) ) {
        confess("yabsm: internal error: no local_backup named '$local_backup'");
    }

    return 1;
}

sub backup_exists {

    # Return 1 if $backup is either an ssh_backup or a local_backup and return 0
    # otherwise.

    arg_count_or_die(2, 2, @_);

    my $backup     = shift;
    my $config_ref = shift;

    return 1 if ssh_backup_exists($backup, $config_ref);
    return local_backup_exists($backup, $config_ref);
}

sub backup_exists_or_die {

    # Wrapper around &backup_exists that Carp::Confess's if it returns false.

    arg_count_or_die(2, 2, @_);

    my $backup     = shift;
    my $config_ref = shift;

    unless ( backup_exists($backup, $config_ref) ) {
        confess("yabsm: internal error: no ssh_backup or local_backup named '$backup'");
    }

    return 1;
}

sub all_subvols {

    # Return a list of all the subvol names defined in $config_ref.

    arg_count_or_die(1, 1, @_);

    my $config_ref = shift;

    my @subvols = sort keys %{ $config_ref->{subvols} };

    return @subvols;
}

sub all_snaps {

    # Return a list of all the snap names defined in $config_ref.

    arg_count_or_die(1, 1, @_);

    my $config_ref = shift;

    my @snaps = sort keys %{ $config_ref->{snaps} };

    return @snaps;
}

sub all_ssh_backups {

    # Return a list of all the ssh_backup names defined in $config_ref.

    arg_count_or_die(1, 1, @_);

    my $config_ref = shift;

    my @ssh_backups = sort keys %{ $config_ref->{ssh_backups} };

    return @ssh_backups;
}

sub all_local_backups {

    # Return a list of all the local_backup names defined in $config_ref.

    arg_count_or_die(1, 1, @_);

    my $config_ref = shift;

    my @all_local_backups = sort keys %{ $config_ref->{local_backups} };

    return @all_local_backups;
}

sub subvol_mountpoint {

    # Return the the subvol $subvol's mountpoint value.

    arg_count_or_die(2, 2, @_);

    my $subvol     = shift;
    my $config_ref = shift;

    subvol_exists_or_die($subvol, $config_ref);

    return $config_ref->{subvols}{$subvol}{mountpoint};
}

sub snap_subvol {

    # Return the name of the subvol that $snap is snapshotting.

    arg_count_or_die(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);

    return $config_ref->{snaps}{$snap}{subvol};
}

sub snap_mountpoint {

    # Return the mountpoint of the subvol that $snap is snapshotting.

    arg_count_or_die(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);

    my $subvol = snap_subvol($snap, $config_ref);

    return subvol_mountpoint($subvol, $config_ref);
}

sub snap_dest {

    # Return $snap's destination. Optionally pass a timeframe via the $tframe
    # value to append "/$tframe" to the returned dir.

    arg_count_or_die(3, 3, @_);

    my $snap       = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);

    my $dest = yabsm_dir($config_ref) . "/$snap";

    if ($tframe) {
        snap_wants_timeframe_or_die($snap, $tframe, $config_ref);
        return "$dest/$tframe";
    }
    else {
        return $dest;
    }
}

sub snap_timeframes {

    # Return a list of $snap's timeframes.

    arg_count_or_die(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);

    return sort split ',', $config_ref->{snaps}{$snap}{timeframes};
}

sub ssh_backup_subvol {

    # Return the name of the subvol that $ssh_backup is backing up.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);

    return $config_ref->{ssh_backups}{$ssh_backup}{subvol};
}

sub ssh_backup_mountpoint {

    # Return the mountpoint of the subvol that $ssh_backup is backing up.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);

    my $subvol = ssh_backup_subvol($ssh_backup, $config_ref);

    return subvol_mountpoint($subvol, $config_ref);
}

sub ssh_backup_dir {

    # Return $ssh_backup's ssh_backup dir value. Optionally pass a timeframe via
    # the $tframe value to append "/$tframe" to the returned dir.

    arg_count_or_die(3, 3, @_);

    my $ssh_backup = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);

    my $dir = $config_ref->{ssh_backups}{$ssh_backup}{dir} =~ s/\/+$//r;

    if ($tframe) {
        ssh_backup_wants_timeframe_or_die($ssh_backup, $tframe, $config_ref);
        return "$dir/$tframe";
    }
    else {
        return $dir;
    }
}

sub ssh_backup_timeframes {

    # Return a list of $ssh_backups's timeframes.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);

    return sort split ',', $config_ref->{ssh_backups}{$ssh_backup}{timeframes};
}

sub ssh_backup_ssh_dest {

    # Return $ssh_backup's ssh_dest value.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);

    return $config_ref->{ssh_backups}{$ssh_backup}{ssh_dest};
}

sub local_backup_subvol {

    # Return the name of the subvol that $local_backup is backing up.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    local_backup_exists_or_die($local_backup, $config_ref);

    return $config_ref->{local_backups}{$local_backup}{subvol};
}

sub local_backup_mountpoint {

    # Return the mountpoint of the subvol that $local_backup is backing up.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    local_backup_exists_or_die($local_backup, $config_ref);

    my $subvol = local_backup_subvol($local_backup, $config_ref);

    return subvol_mountpoint($subvol, $config_ref);
}

sub local_backup_dir {

    # Return $local_backup's local_backup dir value. Optionally pass a timeframe
    # via the $tframe value to append "/$tframe" to the returned dir.

    arg_count_or_die(3, 3, @_);

    my $local_backup = shift;
    my $tframe       = shift;
    my $config_ref   = shift;

    local_backup_exists_or_die($local_backup, $config_ref);

    my $dir = $config_ref->{local_backups}{$local_backup}{dir} =~ s/\/+$//r;

    if ($tframe) {
        local_backup_wants_timeframe_or_die($local_backup, $tframe, $config_ref);
        return "$dir/$tframe";
    }
    else {
        return $dir;
    }
}

sub local_backup_timeframes {

    # Return a list of $local_backups's timeframes.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    local_backup_exists_or_die($local_backup, $config_ref);

    return sort split ',', $config_ref->{local_backups}{$local_backup}{timeframes};
}

sub all_snaps_of_subvol {

    # Return a list of all the snaps in $config_ref that are snapshotting
    # $subvol.

    arg_count_or_die(2, 2, @_);

    my $subvol     = shift;
    my $config_ref = shift;

    my @snaps;

    for my $snap ( all_snaps($config_ref) ) {
        push @snaps, $snap
          if ($subvol eq $config_ref->{snaps}{$snap}{subvol});
    }

    return sort @snaps;
}

sub all_ssh_backups_of_subvol {

    # Return a list of all the ssh_backups in $config_ref that are backing up
    # $subvol.

    arg_count_or_die(2, 2, @_);

    my $subvol     = shift;
    my $config_ref = shift;

    my @ssh_backups;

    for my $ssh_backup ( all_ssh_backups($config_ref) ) {
        push @ssh_backups, $ssh_backup
          if ($subvol eq $config_ref->{ssh_backups}{$ssh_backup}{subvol});
    }

    return sort @ssh_backups;
}

sub all_local_backups_of_subvol {

    # Return a list of all the local_backups in $config_ref that are backing up
    # $subvol.

    arg_count_or_die(2, 2, @_);

    my $subvol     = shift;
    my $config_ref = shift;

    my @local_backups;

    for my $local_backup ( all_local_backups($config_ref) ) {
        push @local_backups, $local_backup
          if ($subvol eq $config_ref->{local_backups}{$local_backup}{subvol});
    }

    return sort @local_backups;
}

sub snap_wants_timeframe {

    # Return 1 if the snap $snap wants snapshots in timeframe $tframe and return
    # 0 otherwise;

    arg_count_or_die(3, 3, @_);

    my $snap       = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);
    is_timeframe_or_die($tframe);

    return 1 if grep { $tframe eq $_ } snap_timeframes($snap, $config_ref);
    return 0;
}

sub snap_wants_timeframe_or_die {

    # Wrapper around &snap_wants_timeframe that Carp::Confess's if it returns
    # false.

    arg_count_or_die(3, 3, @_);

    my $snap       = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    unless ( snap_wants_timeframe($snap, $tframe, $config_ref) ) {
        confess("yabsm: internal error: snap '$snap' is not taking $tframe snapshots");
    }

    return 1;
}

sub ssh_backup_wants_timeframe {

    # Return 1 if the ssh_backup $ssh_backup wants backups in timeframe $tframe
    # and return 0 otherwise.

    arg_count_or_die(3, 3, @_);

    my $ssh_backup = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);
    is_timeframe_or_die($tframe);

    return 1 if grep { $tframe eq $_ } ssh_backup_timeframes($ssh_backup, $config_ref);
    return 0;
}

sub ssh_backup_wants_timeframe_or_die {

    # Wrapper around &ssh_backup_wants_timeframe that Carp::Confess's if it
    # returns false.

    arg_count_or_die(3, 3, @_);

    my $ssh_backup = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    unless ( ssh_backup_wants_timeframe($ssh_backup, $tframe, $config_ref) ) {
        confess("yabsm: internal error: ssh_backup '$ssh_backup' is not taking $tframe backups");
    }

    return 1;
}

sub local_backup_wants_timeframe {

    # Return 1 if the local_backup $local_backup wants backups in timeframe
    # $tframe and return 0 otherwise.

    arg_count_or_die(3, 3, @_);

    my $local_backup = shift;
    my $tframe       = shift;
    my $config_ref   = shift;

    local_backup_exists_or_die($local_backup, $config_ref);

    is_timeframe_or_die($tframe);

    return 1 if grep { $tframe eq $_ } local_backup_timeframes($local_backup, $config_ref);
    return 0;
}

sub local_backup_wants_timeframe_or_die {

    # Wrapper around &local_backup_wants_timeframe that Carp::Confess's if it
    # returns false.

    arg_count_or_die(3, 3, @_);

    my $local_backup = shift;
    my $tframe       = shift;
    my $config_ref   = shift;

    unless ( local_backup_wants_timeframe($local_backup, $tframe, $config_ref) ) {
        confess("yabsm: internal error: local_backup '$local_backup' is not taking $tframe backups");
    }

    return 1;
}

sub snap_timeframe_keep {

    # Return snap $snap's ${tframe}_keep value.

    arg_count_or_die(3, 3, @_);

    my $snap       = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);
    is_timeframe_or_die($tframe);

    $tframe eq '5minute' and return snap_5minute_keep($snap, $config_ref);
    $tframe eq 'hourly'  and return snap_hourly_keep($snap, $config_ref);
    $tframe eq 'daily'   and return snap_daily_keep($snap, $config_ref);
    $tframe eq 'weekly'  and return snap_weekly_keep($snap, $config_ref);
    $tframe eq 'monthly' and return snap_monthly_keep($snap, $config_ref);
}

sub snap_5minute_keep {

    # Return snap $snap's 5minute_keep value.

    arg_count_or_die(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);
    snap_wants_timeframe_or_die($snap, '5minute', $config_ref);

    return $config_ref->{snaps}{$snap}{'5minute_keep'};
}

sub snap_hourly_keep {

    # Return snap $snap's hourly_keep value.

    arg_count_or_die(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);
    snap_wants_timeframe_or_die($snap, 'hourly', $config_ref);

    return $config_ref->{snaps}{$snap}{hourly_keep};
}

sub snap_daily_keep {

    # Return snap $snap's daily_keep value.

    arg_count_or_die(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);
    snap_wants_timeframe_or_die($snap, 'daily', $config_ref);

    return $config_ref->{snaps}{$snap}{daily_keep};
}

sub snap_daily_times {

    # Return a list of snap $snap's daily_times values.

    arg_count_or_die(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);
    snap_wants_timeframe_or_die($snap, 'daily', $config_ref);

    my @times = split ',', $config_ref->{snaps}{$snap}{daily_times};

    # removes duplicates
    @times = sort keys %{{ map { $_ => 1 } @times }};

    return @times
}

sub snap_weekly_keep {

    # Return snap $snap's weekly_keep value.

    arg_count_or_die(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);
    snap_wants_timeframe_or_die($snap, 'weekly', $config_ref);

    return $config_ref->{snaps}{$snap}{weekly_keep};
}

sub snap_weekly_time {

    # Return snap $snap's weekly_time value.

    arg_count_or_die(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);
    snap_wants_timeframe_or_die($snap, 'weekly', $config_ref);

    return $config_ref->{snaps}{$snap}{weekly_time};
}

sub snap_weekly_day {

    # Return snap $snap's weekly_day value.

    arg_count_or_die(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);
    snap_wants_timeframe_or_die($snap, 'weekly', $config_ref);

    return $config_ref->{snaps}{$snap}{weekly_day};
}

sub snap_monthly_keep {

    # Return snap $snap's monthly_keep value.

    arg_count_or_die(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);
    snap_wants_timeframe_or_die($snap, 'monthly', $config_ref);

    return $config_ref->{snaps}{$snap}{monthly_keep};
}

sub snap_monthly_time {

    # Return snap $snap's monthly_time value.

    arg_count_or_die(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);
    snap_wants_timeframe_or_die($snap, 'monthly', $config_ref);

    return $config_ref->{snaps}{$snap}{monthly_time};
}

sub snap_monthly_day {

    # Return snap $snap's monthly_day value.

    arg_count_or_die(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    snap_exists_or_die($snap, $config_ref);
    snap_wants_timeframe_or_die($snap, 'monthly', $config_ref);

    return $config_ref->{snaps}{$snap}{monthly_day};
}

sub ssh_backup_timeframe_keep {

    # Return ssh_backup $ssh_backup's ${tframe}_keep value.

    arg_count_or_die(3, 3, @_);

    my $ssh_backup = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);
    is_timeframe_or_die($tframe);

    $tframe eq '5minute' and return ssh_backup_5minute_keep($ssh_backup, $config_ref);
    $tframe eq 'hourly'  and return ssh_backup_hourly_keep($ssh_backup, $config_ref);
    $tframe eq 'daily'   and return ssh_backup_daily_keep($ssh_backup, $config_ref);
    $tframe eq 'weekly'  and return ssh_backup_weekly_keep($ssh_backup, $config_ref);
    $tframe eq 'monthly' and return ssh_backup_monthly_keep($ssh_backup, $config_ref);
}

sub ssh_backup_5minute_keep {

    # Return ssh_backup $ssh_backup's 5minute_keep value.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);
    ssh_backup_wants_timeframe_or_die($ssh_backup, '5minute', $config_ref);

    return $config_ref->{ssh_backups}{$ssh_backup}{'5minute_keep'};
}

sub ssh_backup_hourly_keep {

    # Return ssh_backup $ssh_backup's hourly_keep value.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);
    ssh_backup_wants_timeframe_or_die($ssh_backup, 'hourly', $config_ref);

    return $config_ref->{ssh_backups}{$ssh_backup}{hourly_keep};
}

sub ssh_backup_daily_keep {

    # Return ssh_backup $ssh_backup's daily_keep value.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);
    ssh_backup_wants_timeframe_or_die($ssh_backup, 'daily', $config_ref);

    return $config_ref->{ssh_backups}{$ssh_backup}{daily_keep};
}

sub ssh_backup_daily_times {

    # Return a list of ssh_backup $ssh_backup's daily_times values.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);
    ssh_backup_wants_timeframe_or_die($ssh_backup, 'daily', $config_ref);

    my @times = split ',', $config_ref->{ssh_backups}{$ssh_backup}{daily_times};

    # removes duplicates
    @times = sort keys %{{ map { $_ => 1 } @times }};

    return @times;
}

sub ssh_backup_weekly_keep {

    # Return ssh_backup $ssh_backup's weekly_keep value.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);
    ssh_backup_wants_timeframe_or_die($ssh_backup, 'weekly', $config_ref);

    return $config_ref->{ssh_backups}{$ssh_backup}{weekly_keep};
}

sub ssh_backup_weekly_time {

    # Return ssh_backup $ssh_backup's weekly_time value.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);
    ssh_backup_wants_timeframe_or_die($ssh_backup, 'weekly', $config_ref);

    return $config_ref->{ssh_backups}{$ssh_backup}{weekly_time};
}

sub ssh_backup_weekly_day {

    # Return ssh_backup $ssh_backup's weekly_day value.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);
    ssh_backup_wants_timeframe_or_die($ssh_backup, 'weekly', $config_ref);

    return $config_ref->{ssh_backups}{$ssh_backup}{weekly_day};
}

sub ssh_backup_monthly_keep {

    # Return ssh_backup $ssh_backup's monthly_keep value.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);
    ssh_backup_wants_timeframe_or_die($ssh_backup, 'monthly', $config_ref);

    return $config_ref->{ssh_backups}{$ssh_backup}{monthly_keep};
}

sub ssh_backup_monthly_time {

    # Return ssh_backup $ssh_backup's monthly_time value.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);
    ssh_backup_wants_timeframe_or_die($ssh_backup, 'monthly', $config_ref);

    return $config_ref->{ssh_backups}{$ssh_backup}{monthly_time};
}

sub ssh_backup_monthly_day {

    # Return ssh_backup $ssh_backup's monthly_day value.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);
    ssh_backup_wants_timeframe_or_die($ssh_backup, 'monthly', $config_ref);

    return $config_ref->{ssh_backups}{$ssh_backup}{monthly_day};
}

sub local_backup_timeframe_keep {

    # Return local_backup $local_backup's ${tframe}_keep value.

    arg_count_or_die(3, 3, @_);

    my $local_backup = shift;
    my $tframe       = shift;
    my $config_ref   = shift;

    local_backup_exists_or_die($local_backup, $config_ref);
    is_timeframe_or_die($tframe);

    $tframe eq '5minute' and return local_backup_5minute_keep($local_backup, $config_ref);
    $tframe eq 'hourly'  and return local_backup_hourly_keep($local_backup, $config_ref);
    $tframe eq 'daily'   and return local_backup_daily_keep($local_backup, $config_ref);
    $tframe eq 'weekly'  and return local_backup_weekly_keep($local_backup, $config_ref);
    $tframe eq 'monthly' and return local_backup_monthly_keep($local_backup, $config_ref);
}

sub local_backup_5minute_keep {

    # Return local_backup $local_backup's 5minute_keep value.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    local_backup_exists_or_die($local_backup, $config_ref);
    local_backup_wants_timeframe_or_die($local_backup, '5minute', $config_ref);

    return $config_ref->{local_backups}{$local_backup}{'5minute_keep'};
}

sub local_backup_hourly_keep {

    # Return local_backup $local_backup's hourly_keep value.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    local_backup_exists_or_die($local_backup, $config_ref);
    local_backup_wants_timeframe_or_die($local_backup, 'hourly', $config_ref);

    return $config_ref->{local_backups}{$local_backup}{hourly_keep};
}

sub local_backup_daily_keep {

    # Return local_backup $local_backup's daily_keep value.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    local_backup_exists_or_die($local_backup, $config_ref);
    local_backup_wants_timeframe_or_die($local_backup, 'daily', $config_ref);

    return $config_ref->{local_backups}{$local_backup}{daily_keep};
}

sub local_backup_daily_times {

    # Return a list of local_backup $local_backup's daily_times values.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref = shift;

    local_backup_exists_or_die($local_backup, $config_ref);
    local_backup_wants_timeframe_or_die($local_backup, 'daily', $config_ref);

    my @times = split ',', $config_ref->{local_backups}{$local_backup}{daily_times};

    # removes duplicates
    @times = sort keys %{{ map { $_ => 1 } @times }};

    return @times;
}

sub local_backup_weekly_keep {

    # Return local_backup $local_backup's weekly_keep value.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    local_backup_exists_or_die($local_backup, $config_ref);
    local_backup_wants_timeframe_or_die($local_backup, 'weekly', $config_ref);

    return $config_ref->{local_backups}{$local_backup}{weekly_keep};
}

sub local_backup_weekly_time {

    # Return local_backup $local_backup's weekly_time value.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    local_backup_exists_or_die($local_backup, $config_ref);
    local_backup_wants_timeframe_or_die($local_backup, 'weekly', $config_ref);

    return $config_ref->{local_backups}{$local_backup}{weekly_time};
}

sub local_backup_weekly_day {

    # Return local_backup $local_backup's weekly_day value.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    local_backup_exists_or_die($local_backup, $config_ref);
    local_backup_wants_timeframe_or_die($local_backup, 'weekly', $config_ref);

    return $config_ref->{local_backups}{$local_backup}{weekly_day};
}

sub local_backup_monthly_keep {

    # Return local_backup $local_backup's monthly_keep value.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    local_backup_exists_or_die($local_backup, $config_ref);
    local_backup_wants_timeframe_or_die($local_backup, 'monthly', $config_ref);

    return $config_ref->{local_backups}{$local_backup}{monthly_keep};
}

sub local_backup_monthly_time {

    # Return local_backup $local_backup's monthly_time value.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    local_backup_exists_or_die($local_backup, $config_ref);
    local_backup_wants_timeframe_or_die($local_backup, 'monthly', $config_ref);

    return $config_ref->{local_backups}{$local_backup}{monthly_time};
}

sub local_backup_monthly_day {

    # Return local_backup $local_backup's monthly_day value.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    local_backup_exists_or_die($local_backup, $config_ref);
    local_backup_wants_timeframe_or_die($local_backup, 'monthly', $config_ref);

    return $config_ref->{local_backups}{$local_backup}{monthly_day};
}

1;
