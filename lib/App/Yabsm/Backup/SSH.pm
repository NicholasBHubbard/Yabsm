#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Provides the &do_ssh_backup subroutine, which performs a single
#  ssh_backup. This is a top-level subroutine that is directly scheduled to be
#  run by the daemon.

use strict;
use warnings;
use v5.16.3;

package App::Yabsm::Backup::SSH;

use App::Yabsm::Tools qw( :ALL );
use App::Yabsm::Config::Query qw( :ALL );
use App::Yabsm::Snapshot qw(delete_snapshot
                            sort_snapshots
                            is_snapshot_name
                           );
use App::Yabsm::Backup::Generic qw(take_bootstrap_snapshot
                                   the_local_bootstrap_snapshot
                                   take_tmp_snapshot
                                   bootstrap_lock_file
                                   create_bootstrap_lock_file
                                  );

use Net::OpenSSH;
use Carp qw(confess);
use File::Basename qw(basename);

use Exporter 'import';
our @EXPORT_OK = qw(do_ssh_backup
                    do_ssh_backup_bootstrap
                    maybe_do_ssh_backup_bootstrap
                    the_remote_bootstrap_snapshot
                    new_ssh_conn
                    ssh_system_or_die
                    check_ssh_backup_config_or_die
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

    # We can't do a backup if the bootstrap process is currently being performed.
    if (bootstrap_lock_file($ssh_backup, 'ssh', $config_ref)) {
        return undef;
    }

    $ssh //= new_ssh_conn($ssh_backup, $config_ref);

    check_ssh_backup_config_or_die($ssh, $ssh_backup, $config_ref);

    my $tmp_snapshot       = take_tmp_snapshot($ssh_backup, 'ssh', $tframe, $config_ref);
    my $bootstrap_snapshot = maybe_do_ssh_backup_bootstrap($ssh, $ssh_backup, $config_ref);
    my $backup_dir         = ssh_backup_dir($ssh_backup, $tframe, $config_ref);
    my $backup_dir_base    = ssh_backup_dir($ssh_backup, undef, $config_ref);

    ssh_system_or_die(
        $ssh,
        # This is why we need the remote user to have write permission on the
        # backup dir
        "if ! [ -d '$backup_dir' ]; then mkdir '$backup_dir'; fi"
    );

    ssh_system_or_die(
        $ssh,
        {stdin_file => ['-|', "sudo -n btrfs send -p '$bootstrap_snapshot' '$tmp_snapshot'"]},
        "sudo -n btrfs receive '$backup_dir'"
    );

    # The tmp snapshot is irrelevant now
    delete_snapshot($tmp_snapshot);

    # Delete old backups

    my @remote_backups = grep { is_snapshot_name($_) } ssh_system_or_die($ssh, "ls -1 '$backup_dir'");
    map { chomp $_ ; $_ = "$backup_dir/$_" } @remote_backups;
    # sorted from newest to oldest
    @remote_backups = sort_snapshots(\@remote_backups);

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

sub do_ssh_backup_bootstrap {

    # Perform the bootstrap phase of an incremental backup for $ssh_backup.

    arg_count_or_die(3, 3, @_);

    my $ssh        = shift;
    my $ssh_backup = shift;
    my $config_ref = shift;

    if (bootstrap_lock_file($ssh_backup, 'ssh', $config_ref)) {
        return undef;
    }

    # The lock file will be deleted when $lock_fh goes out of scope (uses File::Temp).
    my $lock_fh = create_bootstrap_lock_file($ssh_backup, 'ssh', $config_ref);

    $ssh //= new_ssh_conn($ssh_backup, $config_ref);

    if (my $local_boot_snap = the_local_bootstrap_snapshot($ssh_backup, 'ssh', $config_ref)) {
        delete_snapshot($local_boot_snap);
    }
    if (my $remote_boot_snap = the_remote_bootstrap_snapshot($ssh, $ssh_backup, $config_ref)) {
        ssh_system_or_die($ssh, "sudo -n btrfs subvolume delete '$remote_boot_snap'");
    }

    my $local_boot_snap = take_bootstrap_snapshot($ssh_backup, 'ssh', $config_ref);

    my $remote_backup_dir = ssh_backup_dir($ssh_backup, undef, $config_ref);

    ssh_system_or_die(
        $ssh,
        {stdin_file => ['-|', "sudo -n btrfs send '$local_boot_snap'"]},
        "sudo -n btrfs receive '$remote_backup_dir'"
    );

    return $local_boot_snap;
}

sub maybe_do_ssh_backup_bootstrap {

    # Like &do_ssh_backup_bootstrap but only perform the bootstrap if it hasn't
    # been performed yet.

    arg_count_or_die(3, 3, @_);

    my $ssh        = shift;
    my $ssh_backup = shift;
    my $config_ref = shift;

    $ssh //= new_ssh_conn($ssh_backup, $config_ref);

    my $local_boot_snap  = the_local_bootstrap_snapshot($ssh_backup, 'ssh', $config_ref);
    my $remote_boot_snap = the_remote_bootstrap_snapshot($ssh, $ssh_backup, $config_ref);

    unless ($local_boot_snap && $remote_boot_snap) {
        $local_boot_snap = do_ssh_backup_bootstrap($ssh, $ssh_backup, $config_ref);
    }

    return $local_boot_snap;
}

sub the_remote_bootstrap_snapshot {

    # Return the remote bootstrap snapshot for $ssh_backup if it exists and
    # return undef otherwise. Die if we find multiple bootstrap snapshots.

    arg_count_or_die(3, 3, @_);

    my $ssh        = shift;
    my $ssh_backup = shift;
    my $config_ref = shift;

    $ssh //= new_ssh_conn($ssh_backup, $config_ref);

    my $remote_backup_dir = ssh_backup_dir($ssh_backup, undef, $config_ref);
    my @boot_snaps = grep { is_snapshot_name($_, ONLY_BOOTSTRAP => 1) } ssh_system_or_die($ssh, "ls -1 -a '$remote_backup_dir'");
    map { chomp $_ ; $_ = "$remote_backup_dir/$_" } @boot_snaps;

    if (0 == @boot_snaps) {
        return undef;
    }
    elsif (1 == @boot_snaps) {
        return $boot_snaps[0];
    }
    else {
        my $ssh_dest = ssh_backup_ssh_dest($ssh_backup, $config_ref);
        die "yabsm: ssh error: $ssh_dest: found multiple remote bootstrap snapshots in '$remote_backup_dir'\n";
    }
}

sub new_ssh_conn {

    # Return a Net::OpenSSH connection object to $ssh_backup's ssh destination or
    # die if a connection cannot be established.

    arg_count_or_die(2, 2, @_);

    my $ssh_backup = shift;
    my $config_ref = shift;

    my $home_dir = (getpwuid $<)[7]
      or die q(yabsm: error: user ').scalar(getpwuid $<).q(' does not have a home directory to hold SSH keys);

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
        batch_mode   => 1, # Key based auth only
        ctl_dir      => '/tmp',
        remote_shell => 'sh',
    );

    if ($ssh->error) {
        die "yabsm: ssh error: $ssh_dest: cannot establish SSH connection: ".$ssh->error."\n";
    }

    return $ssh;
}

sub ssh_system_or_die {

    # Like Net::OpenSSH::capture but die if the command fails.

    arg_count_or_die(2, 3, @_);

    my $ssh  = shift;
    my %opts = ref $_[0] eq 'HASH' ? %{ shift() } : ();
    my $cmd  = shift;

    wantarray ? my @out = $ssh->capture(\%opts, $cmd) : my $out = $ssh->capture(\%opts, $cmd);

    if ($ssh->error) {
        my $host = $ssh->get_host;
        die "yabsm: ssh error: $host: remote command '$cmd' failed:".$ssh->error."\n";
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

    my $remote_backup_dir = ssh_backup_dir($ssh_backup, undef, $config_ref);
    my $ssh_dest          = ssh_backup_ssh_dest($ssh_backup, $config_ref);

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
   add_error "btrfs-progs not in '\$(whoami)'s path"
fi

if [ "\$HAVE_BTRFS" = true ] && ! sudo -n btrfs --help >/dev/null 2>&1; then
    add_error "user '\$(whoami)' does not have root sudo access to btrfs-progs"
fi

if ! [ -d '$remote_backup_dir' ] || ! [ -r '$remote_backup_dir' ] || ! [ -w '$remote_backup_dir' ]; then
    add_error "no directory '$remote_backup_dir' that is readable+writable by user '\$(whoami)'"
else
    if [ "\$HAVE_BTRFS" = true ] && ! btrfs property list '$remote_backup_dir' >/dev/null 2>&1; then
        add_error "'$remote_backup_dir' is not a directory residing on a btrfs filesystem"
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
