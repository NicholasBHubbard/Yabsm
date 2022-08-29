#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Functions for performing btrfs incremental backups over SSH.

use strict;
use warnings;
use v5.16.3;

package Yabsm::Backup::SSH;

use Yabsm::Snapshot qw(delete_snapshot sort_snapshots is_snapshot_name);
use Yabsm::Backup::Generic qw(maybe_take_bootstrap_snapshot take_tmp_snapshot);
use Yabsm::Tools 'arg_count_or_die';
use Yabsm::Config::Query qw( :ALL );

use Net::OpenSSH;
use File::Basename qw(basename);

use Carp qw(confess);

use Exporter 'import';
our @EXPORT_OK = qw(do_ssh_backup
                    new_ssh_conn
                    check_ssh_backup_config_or_die
                    ssh_system_or_die
                   );

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub do_ssh_backup { # Is tested

    # Perform a $tframe ssh_backup for $ssh_backup.
    #
    # In order to be able to perform the backup the remote user must have sudo
    # access to btrfs-progs, and read+write permission on the remote backup dir.

    arg_count_or_die(4, 4, @_);

    my $ssh        = shift;
    my $ssh_backup = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    $ssh //= new_ssh_conn($ssh_backup, 0, $config_ref) // return undef;

    check_ssh_backup_config_or_die($ssh, $ssh_backup, $config_ref);

    my $backup_dir         = ssh_backup_dir($ssh_backup, $tframe, $config_ref);
    my $backup_dir_base    = ssh_backup_dir($ssh_backup, undef, $config_ref);
    my $bootstrap_snapshot = maybe_take_bootstrap_snapshot($ssh_backup, 'ssh', $config_ref);
    my $tmp_snapshot       = take_tmp_snapshot($ssh_backup, 'ssh', $config_ref);

    ssh_system_or_die( $ssh, "mkdir '$backup_dir' >/dev/null 2>&1");
    ssh_system_or_die( $ssh
                     , {stdin_file => ['-|', "sudo -n btrfs send -p '$bootstrap_snapshot' '$tmp_snapshot'"]}
                     , "sudo -n btrfs receive '$backup_dir' >/dev/null 2>&1"
                     );
    delete_snapshot($tmp_snapshot);

    # Delete old backups

    my @remote_backups = sort_snapshots([ map { $_ = "$backup_dir/$_" } grep { is_snapshot_name($_, 0) } ssh_system_or_die($ssh, "ls '$backup_dir'")]);
    my $num_backups    = scalar @remote_backups;
    my $to_keep        = ssh_backup_timeframe_keep($ssh_backup, $tframe, $config_ref);

    # There is 1 more backup than should be kept because we just performed a
    # backup.
    if ($num_backups == $to_keep + 1) {
        my $oldest = pop @remote_backups;
        ssh_system_or_die($ssh, "sudo -n btrfs subvolume delete '$oldest'");
    }
    # We havent reached the backup quota yet so we don't delete anything
    elsif ($num_backups <= $to_keep) {
        ;
    }
    # User changed their settings to keep less backups than they were keeping
    # prior.
    else {
        for (; $num_backups > $to_keep; $num_backups--) {
            my $oldest = pop @remote_backups;
            ssh_system_or_die($ssh, "sudo -n btrfs subvolume delete '$oldest'");
        }
    }

    return "$backup_dir/" . basename($tmp_snapshot);
}

sub new_ssh_conn { # Is tested

    # Return a Net::OpenSSH connection object to $ssh_backup's ssh destination.
    # If a connection cannot be established logdie if $or_die and otherwise
    # return undef.

    arg_count_or_die(3, 3, @_);

    my $ssh_backup = shift;
    my $or_die     = shift;
    my $config_ref = shift;

    my $ssh_dest = ssh_backup_ssh_dest($ssh_backup, $config_ref);

    my $ssh = Net::OpenSSH->new(
        $ssh_dest,
        batch_mode   => 1, # Don't even try asking for a password
        remote_shell => 'sh',
        timeout      => 5,
        kill_ssh_on_timeout => 1
    );

    ! $ssh->error and return $ssh;
    ! $or_die     and return undef;

    die "yabsm: ssh error: $ssh_dest: cannot establish SSH connection: ".$ssh->error."\n";
}

sub ssh_system_or_die { # Is tested

    # Like Net::OpenSSH::capture but logdie if the command fails.

    arg_count_or_die(2, 3, @_);

    my $ssh  = shift;
    my %opts = ref $_[0] eq 'HASH' ? %{ shift() } : ();
    my $cmd  = shift;

    wantarray ? my @out = $ssh->capture(\%opts, $cmd) : my $out = $ssh->capture(\%opts, $cmd);

    if ($ssh->error) {
        my $user = $ssh->get_user;
        my $host = $ssh->get_host;
        confess "yabsm: ssh error: $user\@$host: remote command '$cmd' failed: ".$ssh->error;
    }

    return wantarray ? @out : $out;
}

sub check_ssh_backup_config_or_die { # Is tested

    # Ensure that the $ssh_backup's ssh destination server is configured
    # properly and die with useful errors if not.

    arg_count_or_die(3, 3, @_);

    my $ssh        = shift;
    my $ssh_backup = shift;
    my $config_ref = shift;

    $ssh //= new_ssh_conn($ssh_backup, 1, $config_ref);

    my $backup_dir  = ssh_backup_dir($ssh_backup, undef, $config_ref);
    my $ssh_dest    = ssh_backup_ssh_dest($ssh_backup, $config_ref);
    my $remote_user = $ssh->get_user;

    my (undef, $stderr) = $ssh->capture2(qq(
ERRORS=''

add_error() {
    if [ -z "\$ERRORS" ]; then
        ERRORS="yabsm: ssh error: $ssh_dest: \$1"
    else
        ERRORS="\${ERRORS}\nyabsm: ssh error: $ssh_dest: \$1"
    fi
}

HAVE_BTRFS=true

if ! which btrfs >/dev/null 2>&1; then
   HAVE_BTRFS=false
   add_error "btrfs-progs not in '${remote_user}'s path"
fi

if [ "\$HAVE_BTRFS" = true ] && ! sudo -n btrfs --help >/dev/null 2>&1; then
    add_error "user '$remote_user' does not have root sudo access to btrfs-progs"
fi

if ! [ -d '$backup_dir' ] || ! [ -r '$backup_dir' ] || ! [ -w '$backup_dir' ]; then
    add_error "no directory named '$backup_dir' that is readable+writable to user '$remote_user'"
else
    if [ "\$HAVE_BTRFS" = true ] && ! btrfs property list '$backup_dir' >/dev/null 2>&1; then
        add_error "'$backup_dir' is not a directory residing on a btrfs filesystem"
    fi
fi

if [ -n '\$ERRORS' ]; then
    1>&2 echo "\$ERRORS"
    exit 1
else
    exit 0
fi
));

    chomp $stderr;

    if ($stderr) {
        die "$stderr\n";
    }

    return 1;
}

1;
