#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  TODO

package Yabsm::Backup::Generic;

use Yabsm::Tools qw( :ALL );
use Yabsm::Config::Query qw( :ALL );

use Yabsm::Snapshot qw( take_snapshot_or_die 
                        delete_snapshot_or_die
                        current_time_snapshot_name
                      );

use Log::Log4perl 'get_logger';
use File::Basename 'basename';

use Exporter 'import';
our @EXPORT_OK = qw( take_bootstrap_snapshot
                     backup_bootstrap_snapshot
                     bootstrap_snapshot_dir
                     is_bootstrap_snapshot
                     is_bootstrap_snapshot_or_die
                     is_bootstrap_snapshot_name
                     is_bootstrap_snapshot_name_or_die
                     is_backup_type_or_die
                   );

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub take_bootstrap_snapshot { # Is tested

    # Take a btrfs bootstrap snapshot of $backup and return its path.

    3 == @_ or die_arg_count(3, 3, @_);

    my $backup      = shift;
    my $backup_type = shift;
    my $config_ref  = shift;
    
    is_backup_type_or_die($backup_type);

    my $bootstrap_dir = bootstrap_snapshot_dir($backup, $backup_type, $config_ref);

    my $mountpoint;

    if ($backup_type eq 'ssh') {
        $mountpoint = ssh_backup_mountpoint($backup, $config_ref);
    }
    if ($backup_type eq 'local') {
        $mountpoint = local_backup_mountpoint($backup, $config_ref);
    }

    my $snapshot_name = '.BOOTSTRAP-' . current_time_snapshot_name();
    
    return take_snapshot_or_die($mountpoint, $bootstrap_dir, $snapshot_name);
}

sub backup_bootstrap_snapshot { # Is tested

    # If the backup $backup has a bootstrap snapshot return its path
    # and otherwise return undef.

    my $backup      = shift;
    my $backup_type = shift;
    my $config_ref  = shift;

    is_backup_type_or_die($backup_type);
    backup_exists_or_die($backup, $config_ref);

    my $bootstrap_dir = bootstrap_snapshot_dir($backup, $backup_type, $config_ref);

    is_btrfs_dir_or_die($bootstrap_dir);

    opendir my $dh, $bootstrap_dir
      or get_logger->logconfess("yabsm: internal error: cannot opendir '$bootstrap_dir'");

    my @boot_snapshots = map { $_ = "$bootstrap_dir/$_" } grep { $_ !~ /^(\.\.|\.)$/ } readdir($dh);

    closedir $dh;

    if (0 == @boot_snapshots) {
        return undef;
    }
    elsif (1 == @boot_snapshots) {
        my $bootstrap_snapshot = shift @boot_snapshots;
        is_bootstrap_snapshot_or_die($bootstrap_snapshot);
        return $bootstrap_snapshot;
    }
    else {
        get_logger->logconfess("yabsm: internal error: found multiple items in '$bootstrap_dir': " . map { $_ = q('$bootstrap_dir/$_') } @boot_snapshots);
    }
}

sub bootstrap_snapshot_dir { # Is tested

    # Return the path to $ssh_backup's bootstrap snapshot directory.

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

sub is_bootstrap_snapshot_or_die { # Not tested

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
