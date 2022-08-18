#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Functions for performing btrfs incremental backups over SSH.

use strict;
use warnings;
use v5.16.3;

package Yabsm::Backup::SSH;

use Yabsm::Snapshot qw(take_snapshot delete_snapshot sort_snapshots);
use Yabsm::Backup::Generic qw(maybe_take_bootstrap_snapshot take_tmp_snapshot);
use Yabsm::Tools 'die_arg_count';
use Yabsm::Config::Query qw( :ALL );

use Net::OpenSSH;
use Log::Log4perl 'get_logger';
use File::Basename qw(basename dirname);

use Exporter 'import';
our @EXPORT_OK = qw( ssh_backup_do_backup
                     new_ssh_conn
                     ssh_system_or_die
                   );

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub ssh_backup_do_backup { # Is tested

    # Perform a $tframe ssh_backup for $ssh_backup.
    #
    # In order to be able to perform the backup the remote user must have sudo
    # access to btrfs-progs, and read+write permission on the remote backup dir.

    4 == @_ or die_arg_count(4, 4, @_);

    my $ssh        = shift;
    my $ssh_backup = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    my $backup_dir         = ssh_backup_dir($ssh_backup, $tframe, $config_ref);
    my $backup_dir_base    = dirname($backup_dir); # without $tframe
    my $bootstrap_snapshot = maybe_take_bootstrap_snapshot($ssh_backup, 'ssh', $config_ref);
    my $tmp_snapshot       = take_tmp_snapshot($ssh_backup, 'ssh', $config_ref);

    ssh_system_or_die( $ssh, "[ -d '$backup_dir_base' ] && [ -r '$backup_dir_base' ] && [ -w '$backup_dir_base' ]");
    ssh_system_or_die( $ssh, "mkdir '$backup_dir' >/dev/null 2>&1");
    ssh_system_or_die( $ssh
                     , {stdin_file => ['-|', "sudo -n btrfs send -p '$bootstrap_snapshot' '$tmp_snapshot'"]}
                     , "sudo -n btrfs receive '$backup_dir' >/dev/null 2>&1"
                     );
    delete_snapshot($tmp_snapshot);

    # Delete old backups

    my @remote_backups = sort_snapshots([ ssh_system_or_die($ssh, "ls '$backup_dir'")]);
    my $num_backups    = scalar @remote_backups;
    my $to_keep        = ssh_backup_timeframe_keep($ssh_backup, $tframe, $config_ref);

    # There is 1 more backup than should be kept because we just performed a
    # backup.
    if ($num_backups == $to_keep + 1) {
        my $oldest = pop @remote_backups;
        ssh_system_or_die($ssh, "sudo -n btrfs subvol delete '$oldest'");
    }
    # We havent reached the backup quota yet so we don't delete anything
    elsif ($num_backups <= $to_keep) {
        ;
    }
    # User changed their settings to keep less backups than they
    # were keeping prior.
    else {
        for (; $num_backups > $to_keep; $num_backups--) {
            my $oldest = pop @remote_backups;
            ssh_system_or_die($ssh, "sudo -n btrfs subvol delete '$oldest'");
        }
    }

    return "$backup_dir/" . basename($tmp_snapshot);
}

sub new_ssh_conn { # Is tested

    # Return a Net::OpenSSH connection object to $ssh_backup's ssh destination.
    # If a connection cannot be established logdie if $or_die and otherwise
    # return undef.

    3 == @_ or die_arg_count(3, 3, @_);

    my $ssh_backup = shift;
    my $or_die     = shift;
    my $config_ref = shift;

    my $ssh_dest = ssh_backup_ssh_dest($ssh_backup, $config_ref);

    my $ssh = Net::OpenSSH->new(
        $ssh_dest,
        batch_mode => 1, # Don't even try asking for a password
        timeout    => 5,
        kill_ssh_on_timeout => 1
    );

    ! $ssh->error and return $ssh;
    ! $or_die     and return undef;

    get_logger->logdie("yabsm: ssh error: cannot establish SSH connection to '$ssh_dest': ".$ssh->error);
}

sub ssh_system_or_die { # Is tested

    # Like Net::OpenSSH::capture but logdie if the command fails.

    2 == @_ || 3 == @_ or die_arg_count(2, 3, @_);

    my $ssh  = shift;
    my %opts = ref $_[0] eq 'HASH' ? %{ shift() } : ();
    my $cmd  = shift;

    wantarray ? my @out = $ssh->capture(\%opts, $cmd) : my $out = $ssh->capture(\%opts, $cmd);

    if ($ssh->error) {
        my $user = $ssh->get_user;
        my $host = $ssh->get_host;
        get_logger->logdie("yabsm: ssh error: remote command '$cmd' failed at '$user\@$host': ".$ssh->error."\n");
    }

    return wantarray ? @out : $out;
}

1;
