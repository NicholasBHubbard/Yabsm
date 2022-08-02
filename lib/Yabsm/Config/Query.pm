#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Provides functions for querying the Yabsm configuration hash that
#  is produced with Yabsm::Config::Parser::parse_config_or_die().

#  Note that all subroutines assume they are passed a valid
#  configuration.  We can make this assumption because the only
#  function that can produce a config (Yabsm::Config::Parser::parse_config_or_die)
#  is designed so it can only produce a valid config (excluding OS
#  level misconfigurations).
#
#  See t/Yabsm/Config/Query.t for this libraries tests.

package Yabsm::Config::Query;

use strict;
use warnings;
use v5.16.3;

use Yabsm::Tools qw(die_arg_count);

use Log::Log4perl 'get_logger';

use Exporter 'import';
our @EXPORT_OK = qw(
    subvol_exists
    snap_exists
    ssh_backup_exists
    local_backup_exists
    all_subvols
    all_snaps
    all_ssh_backups
    all_local_backups
    subvol_mountpoint
    snap_subvol
    snap_dir
    snap_timeframes
    ssh_backup_subvol
    ssh_backup_dir
    ssh_backup_timeframes
    ssh_backup_ssh_dest
    local_backup_subvol
    local_backup_dir
    local_backup_timeframes
    all_snaps_of_subvol
    all_ssh_backups_of_subvol
    all_local_backups_of_subvol
    snap_wants_timeframe
    ssh_backup_wants_timeframe
    local_backup_wants_timeframe
    snap_5minute_keep
    snap_hourly_keep
    snap_daily_keep
    snap_daily_time
    snap_weekly_keep
    snap_weekly_time
    snap_weekly_day
    snap_monthly_keep
    snap_monthly_time
    snap_monthly_day
    ssh_backup_5minute_keep
    ssh_backup_hourly_keep
    ssh_backup_daily_keep
    ssh_backup_daily_time
    ssh_backup_weekly_keep
    ssh_backup_weekly_time
    ssh_backup_weekly_day
    ssh_backup_monthly_keep
    ssh_backup_monthly_time
    ssh_backup_monthly_day
    local_backup_5minute_keep
    local_backup_hourly_keep
    local_backup_daily_keep
    local_backup_daily_time
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

sub subvol_exists { # Is tested

    # Return 1 if $subvol is a subvol defined in $config_ref and
    # return 0 otherwise.

    2 == @_ or die_arg_count(2, 2, @_);

    my $subvol     = shift;
    my $config_ref = shift;

    return 0+(exists $config_ref->{subvols}{$subvol});
}

sub snap_exists { # Is tested

    # Return 1 if $snap is a snap defined in $config_ref and
    # return 0 otherwise.

    2 == @_ or die_arg_count(2, 2, @_);

    my $snap     = shift;
    my $config_ref = shift;

    return 0+(exists $config_ref->{snaps}{$snap});
}

sub ssh_backup_exists { # Is tested

    # Return 1 if $ssh_backup is a ssh_backup defined in $config_ref
    # and return 0 otherwise.

    2 == @_ or die_arg_count(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    return 0+(exists $config_ref->{ssh_backups}{$ssh_backup});
}

sub local_backup_exists { # Is tested

    # Return 1 if $local_backup is a lcoal_backup defined in
    # $config_ref and return 0 otherwise.

    2 == @_ or die_arg_count(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    return 0+(exists $config_ref->{local_backups}{$local_backup});
}

sub all_subvols { # Is tested

    # Return a list of all the subvol names defined in $config_ref.

    1 == @_ or die_arg_count(1, 1, @_);

    my $config_ref = shift;

    return sort keys $config_ref->{subvols};
}

sub all_snaps { # Is tested

    # Return a list of all the snap names defined in $config_ref.

    1 == @_ or die_arg_count(1, 1, @_);

    my $config_ref = shift;

    return sort keys $config_ref->{snaps};
}

sub all_ssh_backups { # Is tested

    # Return a list of all the ssh_backup names defined in
    # $config_ref.

    1 == @_ or die_arg_count(1, 1, @_);

    my $config_ref = shift;

    return sort keys $config_ref->{ssh_backups};
}

sub all_local_backups { # Is tested

    # Return a list of all the local_backup names defined in
    # $config_ref.

    1 == @_ or die_arg_count(1, 1, @_);

    my $config_ref = shift;

    return sort keys $config_ref->{local_backups};
}

sub subvol_mountpoint { # Is tested

    # Return the the subvol $subvol's mountpoint value. If there is no
    # subvol named $subvol then logdie because things have gone
    # haywire.

    2 == @_ or die_arg_count(2, 2, @_);

    my $subvol     = shift;
    my $config_ref = shift;

    unless ( subvol_exists($subvol, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no subvol named '$subvol'");
    }

    return $config_ref->{subvols}{$subvol}{mountpoint};
}

sub snap_subvol { # Is tested

    # Return the name of the subvol that $snap is snapshotting. If
    # there is no snap named $snap then logdie because things have
    # gone haywire.

    2 == @_ or die_arg_count(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    unless ( snap_exists($snap, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no snap named '$snap'");
    }

    return $config_ref->{snaps}{$snap}{subvol};
}

sub snap_dir { # Is tested

    # Return $snap's dir value. If there is no snap named $snap then
    # logdie because things have gone haywire.

    2 == @_ or die_arg_count(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    unless ( snap_exists($snap, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no snap named '$snap'");
    }

    return $config_ref->{snaps}{$snap}{dir};
}

sub snap_timeframes { # No test

    # Return a list of $snap's timeframes. If there is no snap named
    # $snap then logdie because things have gone haywire.

    2 == @_ or die_arg_count(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    unless ( snap_exists($snap, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no snap named '$snap'");
    }

    return sort split ',', $config_ref->{snaps}{$snap}{timeframes};
}

sub ssh_backup_subvol { # Is tested

    # Return the name of the subvol that $ssh_backup is backing up.
    # If there is no ssh_backup named $ssh_backup then logdie because
    # things have gone haywire.

    2 == @_ or die_arg_count(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    unless ( ssh_backup_exists($ssh_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    return $config_ref->{ssh_backups}{$ssh_backup}{subvol};
}

sub ssh_backup_dir { # Is tested

    # Return $ssh_backup's ssh_backup dir value. If there is no
    # ssh_backup named $ssh_backup then logdie because things have
    # gone haywire.

    2 == @_ or die_arg_count(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    unless ( ssh_backup_exists($ssh_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    return $config_ref->{ssh_backups}{$ssh_backup}{dir};
}

sub ssh_backup_timeframes { # Is tested

    # Return a list of $ssh_backups's timeframes. If there is no
    # ssh_backup named $ssh_backup then logdie because things have
    # gone haywire.

    2 == @_ or die_arg_count(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    unless ( ssh_backup_exists($ssh_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    return sort split ',', $config_ref->{ssh_backups}{$ssh_backup}{timeframes};
}

sub ssh_backup_ssh_dest { # Is tested

    # Return $ssh_backup's ssh_dest value. If there is no ssh_backup
    # named $ssh_backup then logdie because things have gone haywire.

    2 == @_ or die_arg_count(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    unless ( ssh_backup_exists($ssh_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    return $config_ref->{ssh_backups}{$ssh_backup}{ssh_dest};
}

sub local_backup_subvol { # Is tested

    # Return the name of the subvol that $local_backup is backing up.
    # If there is no local_backup named $local_backup then logdie
    # because things have gone haywire.

    2 == @_ or die_arg_count(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    unless ( local_backup_exists($local_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no local_backup named '$local_backup'");
    }

    return $config_ref->{local_backups}{$local_backup}{subvol};
}

sub local_backup_dir { # Is tested

    # Return $local_backup's local_backup dir value. If there is no
    # local_backup named $local_backup then logdie because things have
    # gone haywire.

    2 == @_ or die_arg_count(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    unless ( local_backup_exists($local_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no local_backup named '$local_backup'");
    }

    return $config_ref->{local_backups}{$local_backup}{dir};
}

sub local_backup_timeframes { # Is tested

    # Return a list of $local_backups's timeframes. If there is no
    # local_backup named $local_backup then logdie because things have
    # gone haywire.

    2 == @_ or die_arg_count(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    unless ( local_backup_exists($local_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no local_backup named '$local_backup'");
    }

    return sort split ',', $config_ref->{local_backups}{$local_backup}{timeframes};
}

sub all_snaps_of_subvol { # Is tested

    # Return a list of all the snaps in $config_ref that
    # are snapshotting $subvol.

    2 == @_ or die_arg_count(2, 2, @_);

    my $subvol     = shift;
    my $config_ref = shift;

    my @snaps;

    for my $snap ( all_snaps($config_ref) ) {
        push @snaps, $snap
          if ($subvol eq $config_ref->{snaps}{$snap}{subvol});
    }

    return sort @snaps;
}

sub all_ssh_backups_of_subvol { # Is tested

    # Return a list of all the ssh_backups in $config_ref that
    # are backing up $subvol.

    2 == @_ or die_arg_count(2, 2, @_);

    my $subvol     = shift;
    my $config_ref = shift;

    my @ssh_backups;

    for my $ssh_backup ( all_ssh_backups($config_ref) ) {
        push @ssh_backups, $ssh_backup
          if ($subvol eq $config_ref->{ssh_backups}{$ssh_backup}{subvol});
    }

    return sort @ssh_backups;
}

sub all_local_backups_of_subvol { # Is tested

    # Return a list of all the local_backups in $config_ref that
    # are backing up $subvol.

    2 == @_ or die_arg_count(2, 2, @_);

    my $subvol     = shift;
    my $config_ref = shift;

    my @local_backups;

    for my $local_backup ( all_local_backups($config_ref) ) {
        push @local_backups, $local_backup
          if ($subvol eq $config_ref->{local_backups}{$local_backup}{subvol});
    }

    return sort @local_backups;
}

sub snap_wants_timeframe { # Is tested

    # Return 1 if the snap $snap wants snapshots in timeframe $tframe
    # and return 0 otherwise;

    3 == @_ or die_arg_count(3, 3, @_);

    my $snap       = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    unless ( snap_exists($snap, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no snap named '$snap'");
    }

    unless ( is_timeframe($tframe) ) {
        get_logger->logconfess("yabsm: internal error: no such timeframe '$tframe'");
    }

    return 1 if grep { $tframe eq $_ } snap_timeframes($snap, $config_ref);
    return 0;
}

sub ssh_backup_wants_timeframe { # Is tested

    # Return 1 if the ssh_backup $ssh_backup wants backups in
    # timeframe $tframe and return 0 otherwise.

    3 == @_ or die_arg_count(3, 3, @_);

    my $ssh_backup = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    unless ( ssh_backup_exists($ssh_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    unless ( is_timeframe($tframe) ) {
        get_logger->logconfess("yabsm: internal error: no such timeframe '$tframe'");
    }

    return 1 if grep { $tframe eq $_ } ssh_backup_timeframes($ssh_backup, $config_ref);
    return 0;
}

sub local_backup_wants_timeframe { # Is tested

    # Return 1 if the local_backup $local_backup wants backups in
    # timeframe $tframe and return 0 otherwise.

    3 == @_ or die_arg_count(3, 3, @_);

    my $local_backup = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    unless ( local_backup_exists($local_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no local_backup named '$local_backup'");
    }

    unless ( is_timeframe($tframe) ) {
        get_logger->logconfess("yabsm: internal error: no such timeframe '$tframe'");
    }

    return 1 if grep { $tframe eq $_ } local_backup_timeframes($local_backup, $config_ref);
    return 0;
}

sub snap_timeframe_keep { # Is tested

    # Return snap $snap's ${tframe}_keep value.

    3 == @_ or die_arg_count(3, 3, @_);

    my $snap       = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    if    ($tframe eq '5minute') { return snap_5minute_keep($snap, $config_ref) }
    elsif ($tframe eq 'hourly')  { return snap_hourly_keep($snap, $config_ref)  }
    elsif ($tframe eq 'daily')   { return snap_daily_keep($snap, $config_ref)   }
    elsif ($tframe eq 'weekly')  { return snap_weekly_keep($snap, $config_ref)  }
    elsif ($tframe eq 'monthly') { return snap_monthly_keep($snap, $config_ref) }
    else {
        get_logger->logconfess("yabsm: internal error: no such timeframe '$tframe'");
    }
}

sub snap_5minute_keep { # Is tested

    # Return snap $snap's 5minute_keep value. Logdie if $snap is not
    # a defined snap or is not taking 5minute snapshots.

    2 == @_ or die_arg_count(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    unless( snap_exists($snap, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no snap named '$snap'");
    }

    unless ( snap_wants_timeframe($snap, '5minute', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: snap '$snap' is not taking 5minute snapshots");
    }

    return $config_ref->{snaps}{$snap}{'5minute_keep'};
}

sub snap_hourly_keep { # Is tested

    # Return snap $snap's hourly_keep value. Logdie if $snap is not
    # a defined snap or is not taking hourly snapshots.

    2 == @_ or die_arg_count(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    unless( snap_exists($snap, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no snap named '$snap'");
    }

    unless ( snap_wants_timeframe($snap, 'hourly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: snap '$snap' is not taking hourly snapshots");
    }

    return $config_ref->{snaps}{$snap}{hourly_keep};
}

sub snap_daily_keep { # Is tested

    # Return snap $snap's daily_keep value. Logdie if $snap is not
    # a defined snap or is not taking daily snapshots.

    2 == @_ or die_arg_count(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    unless( snap_exists($snap, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no snap named '$snap'");
    }

    unless ( snap_wants_timeframe($snap, 'daily', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: snap '$snap' is not taking daily snapshots");
    }

    return $config_ref->{snaps}{$snap}{daily_keep};
}

sub snap_daily_time { # Is tested

    # Return snap $snap's daily_time value. Logdie if $snap is not
    # a defined snap or is not taking daily snapshots.

    2 == @_ or die_arg_count(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    unless( snap_exists($snap, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no snap named '$snap'");
    }

    unless ( snap_wants_timeframe($snap, 'daily', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: snap '$snap' is not taking daily snapshots");
    }

    return $config_ref->{snaps}{$snap}{daily_time};
}

sub snap_weekly_keep { # Is tested

    # Return snap $snap's weekly_keep value. Logdie if $snap is not
    # a defined snap or is not taking weekly snapshots.

    2 == @_ or die_arg_count(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    unless( snap_exists($snap, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no snap named '$snap'");
    }

    unless ( snap_wants_timeframe($snap, 'weekly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: snap '$snap' is not taking weekly snapshots");
    }

    return $config_ref->{snaps}{$snap}{weekly_keep};
}

sub snap_weekly_time { # Is tested

    # Return snap $snap's weekly_time value. Logdie if $snap is not
    # a defined snap or is not taking weekly snapshots.

    2 == @_ or die_arg_count(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    unless( snap_exists($snap, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no snap named '$snap'");
    }

    unless ( snap_wants_timeframe($snap, 'weekly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: snap '$snap' is not taking weekly snapshots");
    }

    return $config_ref->{snaps}{$snap}{weekly_time};
}

sub snap_weekly_day { # Is tested

    # Return snap $snap's weekly_day value. Logdie if $snap is not
    # a defined snap or is not taking weekly snapshots.

    2 == @_ or die_arg_count(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    unless( snap_exists($snap, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no snap named '$snap'");
    }

    unless ( snap_wants_timeframe($snap, 'weekly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: snap '$snap' is not taking weekly snapshots");
    }

    return $config_ref->{snaps}{$snap}{weekly_day};
}

sub snap_monthly_keep { # Is tested

    # Return snap $snap's monthly_keep value. Logdie if $snap is not
    # a defined snap or is not taking monthly snapshots.

    2 == @_ or die_arg_count(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    unless( snap_exists($snap, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no snap named '$snap'");
    }

    unless ( snap_wants_timeframe($snap, 'monthly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: snap '$snap' is not taking monthly snapshots");
    }

    return $config_ref->{snaps}{$snap}{monthly_keep};
}

sub snap_monthly_time { # Is tested

    # Return snap $snap's monthly_time value. Logdie if $snap is not a
    # defined snap or is not taking monthly snapshots.

    2 == @_ or die_arg_count(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    unless( snap_exists($snap, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no snap named '$snap'");
    }

    unless ( snap_wants_timeframe($snap, 'monthly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: snap '$snap' is not taking monthly snapshots");
    }

    return $config_ref->{snaps}{$snap}{monthly_time};
}

sub snap_monthly_day { # Is tested

    # Return snap $snap's monthly_day value. Logdie if $snap is not a
    # a defined snap or is not taking monthly snapshots.

    2 == @_ or die_arg_count(2, 2, @_);

    my $snap       = shift;
    my $config_ref = shift;

    unless( snap_exists($snap, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no snap named '$snap'");
    }

    unless ( snap_wants_timeframe($snap, 'monthly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: snap '$snap' is not taking monthly snapshots");
    }

    return $config_ref->{snaps}{$snap}{monthly_day};
}

sub ssh_backup_timeframe_keep { # Not tested

    # Return ssh_backup $ssh_backup's ${tframe}_keep value.

    3 == @_ or die_arg_count(3, 3, @_);

    my $ssh_backup = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    if    ($tframe eq '5minute') { return ssh_backup_5minute_keep($ssh_backup, $config_ref) }
    elsif ($tframe eq 'hourly')  { return ssh_backup_hourly_keep($ssh_backup, $config_ref)  }
    elsif ($tframe eq 'daily')   { return ssh_backup_daily_keep($ssh_backup, $config_ref)   }
    elsif ($tframe eq 'weekly')  { return ssh_backup_weekly_keep($ssh_backup, $config_ref)  }
    elsif ($tframe eq 'monthly') { return ssh_backup_monthly_keep($ssh_backup, $config_ref) }
    else {
        get_logger->logconfess("yabsm: internal error: no such timeframe '$tframe'");
    }
}

sub ssh_backup_5minute_keep { # Is tested

    # Return ssh_backup $ssh_backup's 5minute_keep value. Logdie if
    # $ssh_backup is not a defined ssh_backup or is not taking 5minute
    # backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    unless( ssh_backup_exists($ssh_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    unless ( ssh_backup_wants_timeframe($ssh_backup, '5minute', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: ssh_backup '$ssh_backup' is not taking 5minute backups");
    }

    return $config_ref->{ssh_backups}{$ssh_backup}{'5minute_keep'};
}

sub ssh_backup_hourly_keep { # Is tested

    # Return ssh_backup $ssh_backup's hourly_keep value. Logdie if
    # $ssh_backup is not a defined ssh_backup or is not taking hourly
    # backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    unless( ssh_backup_exists($ssh_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    unless ( ssh_backup_wants_timeframe($ssh_backup, 'hourly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: ssh_backup '$ssh_backup' is not taking hourly backups");
    }

    return $config_ref->{ssh_backups}{$ssh_backup}{hourly_keep};
}

sub ssh_backup_daily_keep { # Is tested

    # Return ssh_backup $ssh_backup's daily_keep value. Logdie if
    # $ssh_backup is not a defined ssh_backup or is not taking daily
    # backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    unless( ssh_backup_exists($ssh_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    unless ( ssh_backup_wants_timeframe($ssh_backup, 'daily', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: ssh_backup '$ssh_backup' is not taking daily backups");
    }

    return $config_ref->{ssh_backups}{$ssh_backup}{daily_keep};
}

sub ssh_backup_daily_time { # Is tested

    # Return ssh_backup $ssh_backup's daily_time value. Logdie if
    # $ssh_backup is not a defined ssh_backup or is not taking daily
    # backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    unless( ssh_backup_exists($ssh_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    unless ( ssh_backup_wants_timeframe($ssh_backup, 'daily', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: ssh_backup '$ssh_backup' is not taking daily backups");
    }

    return $config_ref->{ssh_backups}{$ssh_backup}{daily_time};
}

sub ssh_backup_weekly_keep { # Is tested

    # Return ssh_backup $ssh_backup's weekly_keep value. Logdie if
    # $ssh_backup is not a defined ssh_backup or is not taking weekly
    # backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    unless( ssh_backup_exists($ssh_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    unless ( ssh_backup_wants_timeframe($ssh_backup, 'weekly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: ssh_backup '$ssh_backup' is not taking weekly backups");
    }

    return $config_ref->{ssh_backups}{$ssh_backup}{weekly_keep};
}

sub ssh_backup_weekly_time { # Is tested

    # Return ssh_backup $ssh_backup's weekly_time value. Logdie if
    # $ssh_backup is not a defined ssh_backup or is not taking weekly
    # backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    unless( ssh_backup_exists($ssh_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    unless ( ssh_backup_wants_timeframe($ssh_backup, 'weekly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: ssh_backup '$ssh_backup' is not taking weekly backups");
    }

    return $config_ref->{ssh_backups}{$ssh_backup}{weekly_time};
}

sub ssh_backup_weekly_day { # Is tested

    # Return ssh_backup $ssh_backup's weekly_day value. Logdie if
    # $ssh_backup is not a defined ssh_backup or is not taking weekly
    # backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    unless( ssh_backup_exists($ssh_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    unless ( ssh_backup_wants_timeframe($ssh_backup, 'weekly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: ssh_backup '$ssh_backup' is not taking weekly backups");
    }

    return $config_ref->{ssh_backups}{$ssh_backup}{weekly_day};
}

sub ssh_backup_monthly_keep { # Is tested

    # Return ssh_backup $ssh_backup's monthly_keep value. Logdie if
    # $ssh_backup is not a defined ssh_backup or is not taking monthly
    # backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    unless( ssh_backup_exists($ssh_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    unless ( ssh_backup_wants_timeframe($ssh_backup, 'monthly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: ssh_backup '$ssh_backup' is not taking monthly backups");
    }

    return $config_ref->{ssh_backups}{$ssh_backup}{monthly_keep};
}

sub ssh_backup_monthly_time { # Is tested

    # Return ssh_backup $ssh_backup's monthly_time value. Logdie if
    # $ssh_backup is not a defined ssh_backup or is not taking monthly
    # backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    unless( ssh_backup_exists($ssh_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    unless ( ssh_backup_wants_timeframe($ssh_backup, 'monthly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: ssh_backup '$ssh_backup' is not taking monthly backups");
    }

    return $config_ref->{ssh_backups}{$ssh_backup}{monthly_time};
}

sub ssh_backup_monthly_day { # Is tested

    # Return ssh_backup $ssh_backup's monthly_day value. Logdie if
    # $ssh_backup is not a a defined ssh_backup or is not taking
    # monthly backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    unless( ssh_backup_exists($ssh_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no ssh_backup named '$ssh_backup'");
    }

    unless ( ssh_backup_wants_timeframe($ssh_backup, 'monthly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: ssh_backup '$ssh_backup' is not taking monthly backups");
    }

    return $config_ref->{ssh_backups}{$ssh_backup}{monthly_day};
}

sub local_backup_timeframe_keep { # Not tested

    # Return local_backup $local_backup's ${tframe}_keep value.

    3 == @_ or die_arg_count(3, 3, @_);

    my $local_backup = shift;
    my $tframe       = shift;
    my $config_ref   = shift;

    if    ($tframe eq '5minute') { return local_backup_5minute_keep($local_backup, $config_ref) }
    elsif ($tframe eq 'hourly')  { return local_backup_hourly_keep($local_backup, $config_ref)  }
    elsif ($tframe eq 'daily')   { return local_backup_daily_keep($local_backup, $config_ref)   }
    elsif ($tframe eq 'weekly')  { return local_backup_weekly_keep($local_backup, $config_ref)  }
    elsif ($tframe eq 'monthly') { return local_backup_monthly_keep($local_backup, $config_ref) }
    else {
        get_logger->logconfess("yabsm: internal error: no such timeframe '$tframe'");
    }
}

sub local_backup_5minute_keep { # Is tested

    # Return local_backup $local_backup's 5minute_keep value. Logdie
    # if $local_backup is not a defined local_backup or is not taking
    # 5minute backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    unless( local_backup_exists($local_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no local_backup named '$local_backup'");
    }

    unless ( local_backup_wants_timeframe($local_backup, '5minute', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: local_backup '$local_backup' is not taking 5minute backups");
    }

    return $config_ref->{local_backups}{$local_backup}{'5minute_keep'};
}

sub local_backup_hourly_keep { # Is tested

    # Return local_backup $local_backup's hourly_keep value. Logdie if
    # $local_backup is not a defined local_backup or is not taking
    # hourly backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    unless( local_backup_exists($local_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no local_backup named '$local_backup'");
    }

    unless ( local_backup_wants_timeframe($local_backup, 'hourly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: local_backup '$local_backup' is not taking hourly backups");
    }

    return $config_ref->{local_backups}{$local_backup}{hourly_keep};
}

sub local_backup_daily_keep { # Is tested

    # Return local_backup $local_backup's daily_keep value. Logdie if
    # $local_backup is not a defined local_backup or is not taking
    # daily backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    unless( local_backup_exists($local_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no local_backup named '$local_backup'");
    }

    unless ( local_backup_wants_timeframe($local_backup, 'daily', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: local_backup '$local_backup' is not taking daily backups");
    }

    return $config_ref->{local_backups}{$local_backup}{daily_keep};
}

sub local_backup_daily_time { # Is tested

    # Return local_backup $local_backup's daily_time value. Logdie if
    # $local_backup is not a defined local_backup or is not taking
    # daily backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    unless( local_backup_exists($local_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no local_backup named '$local_backup'");
    }

    unless ( local_backup_wants_timeframe($local_backup, 'daily', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: local_backup '$local_backup' is not taking daily backups");
    }

    return $config_ref->{local_backups}{$local_backup}{daily_time};
}

sub local_backup_weekly_keep { # Is tested

    # Return local_backup $local_backup's weekly_keep value. Logdie if
    # $local_backup is not a defined local_backup or is not taking
    # weekly backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    unless( local_backup_exists($local_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no local_backup named '$local_backup'");
    }

    unless ( local_backup_wants_timeframe($local_backup, 'weekly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: local_backup '$local_backup' is not taking weekly backups");
    }

    return $config_ref->{local_backups}{$local_backup}{weekly_keep};
}

sub local_backup_weekly_time { # Is tested

    # Return local_backup $local_backup's weekly_time value. Logdie if
    # $local_backup is not a defined local_backup or is not taking
    # weekly backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    unless( local_backup_exists($local_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no local_backup named '$local_backup'");
    }

    unless ( local_backup_wants_timeframe($local_backup, 'weekly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: local_backup '$local_backup' is not taking weekly backups");
    }

    return $config_ref->{local_backups}{$local_backup}{weekly_time};
}

sub local_backup_weekly_day { # Is tested

    # Return local_backup $local_backup's weekly_day value. Logdie if
    # $local_backup is not a defined local_backup or is not taking
    # weekly backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    unless( local_backup_exists($local_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no local_backup named '$local_backup'");
    }

    unless ( local_backup_wants_timeframe($local_backup, 'weekly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: local_backup '$local_backup' is not taking weekly backups");
    }

    return $config_ref->{local_backups}{$local_backup}{weekly_day};
}

sub local_backup_monthly_keep { # Is tested

    # Return local_backup $local_backup's monthly_keep value. Logdie
    # if $local_backup is not a defined local_backup or is not taking
    # monthly backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    unless( local_backup_exists($local_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no local_backup named '$local_backup'");
    }

    unless ( local_backup_wants_timeframe($local_backup, 'monthly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: local_backup '$local_backup' is not taking monthly backups");
    }

    return $config_ref->{local_backups}{$local_backup}{monthly_keep};
}

sub local_backup_monthly_time { # Is tested

    # Return local_backup $local_backup's monthly_time value. Logdie
    # if $local_backup is not a defined local_backup or is not taking
    # monthly backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    unless( local_backup_exists($local_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no local_backup named '$local_backup'");
    }

    unless ( local_backup_wants_timeframe($local_backup, 'monthly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: local_backup '$local_backup' is not taking monthly backups");
    }

    return $config_ref->{local_backups}{$local_backup}{monthly_time};
}

sub local_backup_monthly_day { # Is tested

    # Return local_backup $local_backup's monthly_day value. Logdie if
    # $local_backup is not a a defined local_backup or is not taking
    # monthly backups.

    2 == @_ or die_arg_count(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    unless( local_backup_exists($local_backup, $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: no local_backup named '$local_backup'");
    }

    unless ( local_backup_wants_timeframe($local_backup, 'monthly', $config_ref) ) {
        get_logger->logconfess("yabsm: internal error: local_backup '$local_backup' is not taking monthly backups");
    }

    return $config_ref->{local_backups}{$local_backup}{monthly_day};
}

sub is_timeframe { # No test

    # Return 1 if given a valid timeframe and return 0 otherwise.

    1 == @_ or die_arg_count(1, 1, @_);

    return shift =~ /^(5minute|hourly|daily|weekly|monthly)$/;
}

sub is_weekday { # No test

    # Return 1 if given a valid week day and return 0 otherwise.

    1 == @_ or die_arg_count(1, 1, @_);

    return shift =~ /^(monday|tuesday|wednesday|thursday|friday|saturday|sunday)$/;
}

1;
