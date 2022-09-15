#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Functions for performing btrfs incremental backups over SSH.
#
#  To run these tests you must have a user on the system named 'yabsm' that has
#  the root users SSH key added to their ~/.ssh/authorized_hosts file.

use strict;
use warnings;
use v5.16.3;

package Yabsm::Backup::SSH;

use Yabsm::Tools qw( :ALL );
use Yabsm::Config::Query qw( :ALL );
use Yabsm::Snapshot qw(delete_snapshot sort_snapshots is_snapshot_name);
use Yabsm::Backup::Generic qw(maybe_take_bootstrap_snapshot take_tmp_snapshot);

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

sub do_ssh_backup {

    # Perform a $tframe ssh_backup for $ssh_backup.

    arg_count_or_die(4, 4, @_);

    my $ssh        = shift;
    my $ssh_backup = shift;
    my $tframe     = shift;
    my $config_ref = shift;

    $ssh //= new_ssh_conn($ssh_backup, $config_ref);

    check_ssh_backup_config_or_die($ssh, $ssh_backup, $config_ref);

    my $backup_dir         = ssh_backup_dir($ssh_backup, $tframe, $config_ref);
    my $backup_dir_base    = ssh_backup_dir($ssh_backup, undef, $config_ref);
    my $bootstrap_snapshot = maybe_do_ssh_backup_bootstrap($ssh, $ssh_backup, 0, $config_ref);
    my $tmp_snapshot       = take_tmp_snapshot($ssh_backup, 'ssh', $config_ref);

    ssh_system_or_die(
        $ssh,
        "if ! [ -d '$backup_dir' ]; then mkdir -p '$backup_dir'; fi"
    );

    ssh_system_or_die(
        $ssh,
        {stdin_file => ['-|', "sudo -n btrfs send -p '$bootstrap_snapshot' '$tmp_snapshot'"]},
        "sudo -n btrfs receive '$backup_dir'"
    );
    delete_snapshot($tmp_snapshot);

    # Delete old backups

    my @remote_backups = sort_snapshots([ map { "$backup_dir/$_" } grep { chomp $_ ; is_snapshot_name($_, 0) } ssh_system_or_die($ssh, "ls -1 '$backup_dir'")]);
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

sub maybe_do_ssh_backup_bootstrap {

    # If the $ssh_backup has not been bootstrapped then perform the bootstrap and
    # return the path to the local bootstrap snapshot.

    arg_count_or_die(4, 4, @_);

    my $ssh        = shift;
    my $ssh_backup = shift;
    my $check_ssh  = shift;
    my $config_ref = shift;

    $ssh //= new_ssh_conn($ssh_backup, $config_ref);

    if ($check_ssh) {
        check_ssh_backup_config_or_die($ssh, $ssh_backup, $config_ref);
    }

    my $local_boot_snapshot = maybe_take_bootstrap_snapshot($ssh_backup, 'ssh', $config_ref);

    my $backup_dir_base = ssh_backup_dir($ssh_backup, undef, $config_ref);

    my @remote_boot_snapshots =
      map { $_ = "$backup_dir_base/$_" } grep { chomp $_ ; /^\.BOOTSTRAP/ and is_snapshot_name($_, 1) } ssh_system_or_die($ssh, "ls -1 -a '$backup_dir_base'");

    if (0 == @remote_boot_snapshots) {
        ssh_system_or_die(
            $ssh,
            {stdin_file => ['-|', "sudo -n btrfs send '$local_boot_snapshot'"]},
            "sudo -n btrfs receive '$backup_dir_base'"
        );
    }
    elsif (1 == @remote_boot_snapshots) {
        my $remote_boot_snapshot = $remote_boot_snapshots[0];
        unless (basename($local_boot_snapshot eq basename($remote_boot_snapshot))) {
            my $host = $ssh->get_host;
            die "yabsm: ssh error: $host: remote bootstrap snapshot '$remote_boot_snapshot' has different basename than local bootstrap snapshot '$local_boot_snapshot'\n";
        }
    }
    else {
        my $host = $ssh->get_host;
        die "yabsm: ssh error: $host: found multiple bootstrap snapshots in '$backup_dir_base'";
    }


    return $local_boot_snapshot;
}

sub new_ssh_conn {

    # Return a Net::OpenSSH connection object to $ssh_backup's ssh destination or
    # die if a connection cannot be established.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    my $home_dir = (getpwuid $<)[7]
      or die q(yabsm: error: user ') . scalar(getpwuid $<) . q(' does not have a home directory to hold SSH keys);

    my $pub_key  = "$home_dir/.ssh/id_ed25519.pub";
    my $priv_key = "$home_dir/.ssh/id_ed25519";

    unless (-f $pub_key) {
        my $username = getpwuid $<;
        die "yabsm: error: cannot not find '$username' users SSH public SSH key '$pub_key'\n";
    }

    unless (-f $priv_key) {
        my $username = getpwuid $<;
        die "yabsm: error: cannot not find '$username' users private SSH key '$priv_key'\n";
    }

    my $ssh_dest = ssh_backup_ssh_dest($ssh_backup, $config_ref);

    my $ssh = Net::OpenSSH->new(
        $ssh_dest,
        master_opts  => [ '-q' ], # quiet
        batch_mode   => 1, # Don't even try asking for a password
        ctl_dir      => '/tmp',
        remote_shell => 'sh',
        timeout      => 5,
        kill_ssh_on_timeout => 1
    );

    if ($ssh->error) {
        die "yabsm: ssh error: $ssh_dest: cannot establish SSH connection: ".$ssh->error."\n";
    }

    return $ssh;
}

sub ssh_system_or_die {

    # Like Net::OpenSSH::capture but logdie if the command fails.

    arg_count_or_die(2, 3, @_);

    my $ssh  = shift;
    my %opts = ref $_[0] eq 'HASH' ? %{ shift() } : ();
    my $cmd  = shift;

    wantarray ? my @out = $ssh->capture(\%opts, $cmd) : my $out = $ssh->capture(\%opts, $cmd);

    if ($ssh->error) {
        my $host = $ssh->get_host;
        confess "yabsm: ssh error: $host: remote command '$cmd' failed: ".$ssh->error;
    }

    return wantarray ? @out : $out;
}

sub check_ssh_backup_config_or_die {

    # Ensure that the $ssh_backup's ssh destination server is configured
    # properly and die with useful errors if not.

    arg_count_or_die(3, 3, @_);

    my $ssh        = shift;
    my $ssh_backup = shift;
    my $config_ref = shift;

    $ssh //= new_ssh_conn($ssh_backup, $config_ref);

    my $backup_dir  = ssh_backup_dir($ssh_backup, undef, $config_ref);
    my $ssh_dest    = ssh_backup_ssh_dest($ssh_backup, $config_ref);

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

if ! which btrfs; then
   HAVE_BTRFS=false
   add_error "btrfs-progs not in '\$(whoami)'s path"
fi

if [ "\$HAVE_BTRFS" = true ] && ! sudo -n btrfs --help; then
    add_error "user '\$(whoami)' does not have root sudo access to btrfs-progs"
fi

if ! [ -d '$backup_dir' ] || ! [ -r '$backup_dir' ] || ! [ -w '$backup_dir' ]; then
    add_error "no directory named '$backup_dir' that is readable+writable to user '\$(whoami)'"
else
    if [ "\$HAVE_BTRFS" = true ] && ! btrfs property list '$backup_dir'; then
        add_error "'$backup_dir' is not a directory residing on a btrfs filesystem"
    fi
fi

if [ -n '\$ERRORS' ]; then
    1>&2 printf %s "\$ERRORS"
    exit 1
else
    exit 0
fi
));

    if ($stderr) {
        die "$stderr\n";
    }

    return 1;
}

1;
