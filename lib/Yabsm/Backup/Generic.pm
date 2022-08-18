#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Functions needed for both SSH and local backups.

use strict;
use warnings;
use v5.16.3;

package Yabsm::Backup::Generic;

use Yabsm::Tools qw( :ALL );
use Yabsm::Config::Query qw( :ALL );

use Yabsm::Snapshot qw( take_snapshot 
                        delete_snapshot
                        current_time_snapshot_name
                      );

use Log::Log4perl 'get_logger';
use File::Basename 'basename';

use Exporter 'import';
our @EXPORT_OK = qw( take_bootstrap_snapshot 
                     maybe_take_bootstrap_snapshot 
                     backup_bootstrap_snapshot 
                     bootstrap_snapshot_dir 
                     is_bootstrap_snapshot 
                     is_bootstrap_snapshot_or_die 
                     is_bootstrap_snapshot_name 
                     is_bootstrap_snapshot_name_or_die 
                     tmp_snapshot_dir 
                     take_tmp_snapshot 
                     is_backup_type_or_die 
                   );

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub take_bootstrap_snapshot { # Is tested

    # Take a btrfs bootstrap snapshot of $backup and return its path.
    # If there is already a bootstrap snapshot for $backup then delete
    # it and take a new one.

    3 == @_ or die_arg_count(3, 3, @_);

    my $backup      = shift;
    my $backup_type = shift;
    my $config_ref  = shift;

    my $mountpoint;

    if ($backup_type eq 'ssh') {
        $mountpoint = ssh_backup_mountpoint($backup, $config_ref);
    }
    elsif ($backup_type eq 'local') {
        $mountpoint = local_backup_mountpoint($backup, $config_ref);
    }
    else { is_backup_type_or_die($backup_type) }
    
    if (my $bootstrap_snapshot = backup_bootstrap_snapshot($backup, $backup_type, $config_ref)) {
        delete_snapshot($bootstrap_snapshot);
    }
    
    my $bootstrap_dir = bootstrap_snapshot_dir($backup, $backup_type, $config_ref);

    my $snapshot_name = '.BOOTSTRAP-' . current_time_snapshot_name();
    
    return take_snapshot($mountpoint, $bootstrap_dir, $snapshot_name);
}

sub maybe_take_bootstrap_snapshot { # Not tested

    # If $backup does not already have a bootstrap snapshot then take
    # a bootstrap snapshot and return its path. Otherwise return the
    # path of the existing bootstrap snapshot.
    
    3 == @_ or die_arg_count(3, 3, @_);

    my $backup      = shift;
    my $backup_type = shift;
    my $config_ref  = shift;
    
    if (my $bbs = backup_bootstrap_snapshot($backup, $backup_type, $config_ref)) {
        return $bbs;
    }

    return take_bootstrap_snapshot($backup, $backup_type, $config_ref);
}

sub backup_bootstrap_snapshot { # Is tested

    # If the backup $backup has a bootstrap snapshot return its path
    # and otherwise return undef.

    3 == @_ or die_arg_count(3, 3, @_);

    my $backup      = shift;
    my $backup_type = shift;
    my $config_ref  = shift;

    is_backup_type_or_die($backup_type);
    backup_exists_or_die($backup, $config_ref);

    my $bootstrap_dir = bootstrap_snapshot_dir($backup, $backup_type, $config_ref);

    is_btrfs_dir_or_die($bootstrap_dir);

    opendir my $dh, $bootstrap_dir or get_logger->logconfess("yabsm: internal error: cannot opendir '$bootstrap_dir'");
    my @boot_snapshots = map { $_ = "$bootstrap_dir/$_" } grep { $_ !~ /^(\.\.|\.)$/ } readdir($dh);
    closedir $dh;

    if (0 == @boot_snapshots) {
        return undef;
    }
    elsif (1 < @boot_snapshots) {
        get_logger->logconfess("yabsm: internal error: found multiple files in '$bootstrap_dir': " . map { $_ = q('$_') } @boot_snapshots);
    }
    else {
        my $bootstrap_snapshot = shift @boot_snapshots;
        is_bootstrap_snapshot_or_die($bootstrap_snapshot);
        return $bootstrap_snapshot;
    }
}

sub bootstrap_snapshot_dir { # Is tested

    # Return the path to $ssh_backup's bootstrap snapshot directory.
    # Logdie if the bootstrap snapshot directory does not exist.

    3 == @_ or die_arg_count(3, 3, @_);

    my $backup      = shift;
    my $backup_type = shift;
    my $config_ref  = shift;

    is_backup_type_or_die($backup_type);

    if ($backup_type eq 'ssh') {
        ssh_backup_exists_or_die($backup, $config_ref);
    }
    if ($backup_type eq 'local') {
        local_backup_exists_or_die($backup, $config_ref);
    }

    return yabsm_dir($config_ref) . "/.yabsm-var/${backup_type}_backups/$backup/bootstrap-snapshot";
}

sub is_bootstrap_snapshot { # Is tested

    # Return 1 if $bootstrap_snapshot is a btrfs subvolume that has a
    # basename that is a valid yabsm bootstrap snapshot name.

    1 == @_ or die_arg_count(1, 1, @_);

    my $bootstrap_snapshot = shift;

    return 0 unless is_btrfs_subvolume($bootstrap_snapshot);
    return 0 unless is_bootstrap_snapshot_name(basename($bootstrap_snapshot));

    return 1;
}

sub is_bootstrap_snapshot_or_die { # Is tested

    # Wrapper around &is_bootstrap_snapshot that logdies if it returns
    # false.

    1 == @_ or die_arg_count(1, 1, @_);

    my $snapshot = shift;

    is_bootstrap_snapshot_name_or_die(basename($snapshot));
    is_btrfs_subvolume_or_die($snapshot);

    return 1;
}

sub is_bootstrap_snapshot_name { # Is tested

    # Return 1 if given a valid yabsm bootstrap snapshot name and
    # return 0 otherwise.
    #
    # Note that this function does not accept file paths.

    1 == @_ or die_arg_count(1, 1, @_);

    return 0+(shift =~ /^\.BOOTSTRAP-yabsm-\d{4}_\d{2}_\d{2}_\d{2}:\d{2}$/);
}

sub is_bootstrap_snapshot_name_or_die { # Is tested

    # Wrapper around is_bootstrap_snapshot_name that logdies if it
    # returns false.

    1 == @_ or die_arg_count(1, 1, @_);

    my $snapshot_name = shift;

    unless ( is_bootstrap_snapshot_name($snapshot_name) ) {
        get_logger->logconfess("yabsm: internal error: '$snapshot_name' is not a valid yabsm bootstrap snapshot name");
    }

    return 1;
}

sub tmp_snapshot_dir { # Is tested

    # Return path to $backup's tmp snapshot directory.

    3 == @_ or die_arg_count(3, 3, @_);

    my $backup      = shift;
    my $backup_type = shift;
    my $config_ref  = shift;

    if ($backup_type eq 'ssh') {
        ssh_backup_exists_or_die($backup, $config_ref);
    }
    elsif ($backup_type eq 'ssh') {
        local_backup_exists_or_die($backup, $config_ref);
    }
    else {
        is_backup_type_or_die($backup_type);
    }

    return yabsm_dir($config_ref) . "/.yabsm-var/${backup_type}_backups/$backup/tmp-snapshot";
}

sub take_tmp_snapshot { # Is tested

    # Take a tmp snapshot for $backup. A tmp snapshot is necessary for taking an
    # incremental backup with 'btrfs send -p'.

    3 == @_ or die_arg_count(3, 3, @_);

    my $backup      = shift;
    my $backup_type = shift;
    my $config_ref  = shift;

    my $tmp_snapshot_dir = tmp_snapshot_dir($backup, $backup_type, $config_ref);

    my $mountpoint;

    if ($backup_type eq 'ssh')   {
        $mountpoint = ssh_backup_mountpoint($backup, $config_ref);
    }
    elsif ($backup_type eq 'local') {
        $mountpoint = local_backup_mountpoint($backup, $config_ref);
    }
    else {
        is_backup_type_or_die($backup_type);
    }
    
    return take_snapshot($mountpoint, $tmp_snapshot_dir);
}

sub is_backup_type_or_die { # Is tested

    # Logdie unless $backup_type equals 'ssh' or 'local'.

    1 == @_ or die_arg_count(1, 1, @_);

    my $backup_type = shift;

    unless ( $backup_type =~ /^(ssh|local)$/ ) {
        get_logger->logconfess("yabsm: internal error: '$backup_type' is not 'ssh' or 'local'");
    }

    return 1;
}

1;
