#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  TODO

package Yabsm::Backup;

use strict;
use warnings;
use v5.16.3;

use Carp 'confess';

use Net::OpenSSH;
use File::Basename 'basename';

use Yabsm::Config::Query qw( :ALL );
use Yabsm::Snapshot qw(take_snapshot
                       delete_snapshot
                       is_yabsm_snapshot_or_die
                       current_time_snapshot_name
                      );

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub do_bootstrap_ssh { # Not tested

    # TODO

    arg_count_or_die(3, 3, @_);

    my $ssh_backup = shift;
    my $ssh        = shift;
    my $config_ref = shift;

    my $bootstrap_snapshot = take_bootstrap_snapshot($ssh_backup, $config_ref);

    my $backup_dir = ssh_backup_dir($ssh_backup, $config_ref);

    $ssh->system({stdin_file => ['-|', "sudo -n btrfs send '$bootstrap_snapshot'"]}, "sudo -n btrfs receieve '$backup_dir'");

    $ssh->error and get_logger->logdie("Remote btrfs command failed: " . $ssh->error);

    return $bootstrap_snapshot;
}

sub take_bootstrap_snapshot { # Is tested

    # Create a bootstrap snapshot and return its path.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    my $bootstrap_dir = bootstrap_snapshot_dir($ssh_backup, $config_ref);

    unless (-d $bootstrap_dir) {
        get_logger->logconfess("yabsm: internal error: bootstrap directory '$bootstrap_dir' does not exist");
    }

    # Delete the old bootstrap snapshot if it exists
    if (my $bootstrap_snapshot = bootstrap_snapshot($ssh_backup, $config_ref)) {
        delete_snapshot($bootstrap_snapshot);
    }

    my $btrfs_subvolume = subvol_mountpoint(ssh_backup_subvol($ssh_backup, $config_ref), $config_ref);

    return take_snapshot($btrfs_subvolume, $bootstrap_dir, '.BOOTSTRAP-' . current_time_snapshot_name());
}

sub maybe_take_bootstrap_snapshot { # Not tested

    # TODO

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);

    unless (bootstrap_snapshot($ssh_backup, $config_ref)) {
        return take_bootstrap_snapshot($ssh_backup, $config_ref);
    }

    return 0;
}

sub bootstrap_snapshot_dir { # Not tested

    # Return the path to $ssh_backup's bootstrap snapshot directory.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    ssh_backup_exists_or_die($ssh_backup, $config_ref);

    return yabsm_dir($config_ref) . "/.yabsm-var/ssh_backups/$ssh_backup/bootstrap-snap";
}

sub bootstrap_snapshot { # Not tested

    # If $subvol has a bootstrap snap return its path, otherwise
    # return 0.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    my $bootstrap_dir = bootstrap_snapshot_dir($ssh_backup, $config_ref);

    my @bootstrap_snapshot = glob "$bootstrap_dir/.BOOTSTRAP-yabsm-*";

    unless (@bootstrap_snapshot <= 1) {
        get_logger->logconfess("yabsm: internal error: multiple bootstrap snapshots found in '$bootstrap_dir'");
    }

    if (my $bootstrap_snapshot = $bootstrap_snapshot[0]) {
        is_bootstrap_snapshot_or_die($bootstrap_snapshot);
        return $bootstrap_snapshot;
    }

    return 0;
}

sub maybe_do_bootstrap { # Not tested

    # TODO

    arg_count_or_die(3, 3, @_);

    my $ssh_backup = shift;
    my $ssh        = shift;
    my $config_ref = shift;

    unless (bootstrap_snapshot($ssh_backup, $config_ref)) {
        return do_bootstrap($ssh_backup, $ssh, $config_ref);
    }

    return 0;
}

sub ssh_backup_connection { # Not tested

    # TODO

    arg_count_or_die(2, 2, @_);

    my $ssh_backup;
    my $config_ref;

    my $ssh_dest = ssh_backup_ssh_dest($ssh_backup, $config_ref);

    my $ssh = Net::OpenSSH->new( $ssh_dest
                               , batch_mode => 1
                               , kill_ssh_on_timeout => 1
                               , timeout => 5
                               );
    
    $ssh->error and get_logger->logdie("yabsm: error: could not establish ssh connection to '$ssh_dest': " . $ssh->error);

    return $ssh;
}

1;
