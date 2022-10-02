#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Functions needed for both SSH and local backups.

use strict;
use warnings;
use v5.16.3;

package App::Yabsm::Backup::Generic;

use App::Yabsm::Tools qw( :ALL );
use App::Yabsm::Config::Query qw( :ALL );

use App::Yabsm::Snapshot qw(take_snapshot
                            delete_snapshot
                            current_time_snapshot_name
                            is_snapshot_name
                           );

use Carp q(confess);
use File::Temp;
use File::Basename qw(basename);
use Feature::Compat::Try;

use Exporter 'import';
our @EXPORT_OK = qw(take_tmp_snapshot
                    tmp_snapshot_dir
                    take_bootstrap_snapshot
                    maybe_take_bootstrap_snapshot
                    bootstrap_snapshot_dir
                    the_local_bootstrap_snapshot
                    bootstrap_lock_file
                    create_bootstrap_lock_file
                    is_backup_type_or_die
                   );

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub take_tmp_snapshot {

    # Take a tmp snapshot for $backup. The tmp snapshot is the snapshot that is
    # actually replicated in an incremental backup with 'btrfs send -p'.

    arg_count_or_die(4, 4, @_);

    my $backup      = shift;
    my $backup_type = shift;
    my $tframe      = shift;
    my $config_ref  = shift;

    my $tmp_snapshot_dir = tmp_snapshot_dir(
        $backup,
        $backup_type,
        $tframe,
        $config_ref,
        DIE_UNLESS_EXISTS => 1
    );

    # Remove any old tmp snapshots that were never deleted because of a failed
    # incremental backup attempt.
    opendir my $dh, $tmp_snapshot_dir or confess("yabsm: internal error: cannot opendir '$tmp_snapshot_dir'");
    my @tmp_snapshots = grep { is_snapshot_name($_, ALLOW_BOOTSTRAP => 0) } readdir($dh);
    closedir $dh;
    map { $_ = "$tmp_snapshot_dir/$_" } @tmp_snapshots;

    # The old tmp snapshot may be in the process of being sent which will cause
    # the deletion to fail. In this case we can just ignore the failure.
    for (@tmp_snapshots) {
        try {
            delete_snapshot($_);
        }
        catch ($e) {
            ; # do nothing
        }
    }

    my $mountpoint;

    if ($backup_type eq 'ssh')   {
        $mountpoint = ssh_backup_mountpoint($backup, $config_ref);
    }
    elsif ($backup_type eq 'local') {
        $mountpoint = local_backup_mountpoint($backup, $config_ref);
    }
    else { is_backup_type_or_die($backup_type) }

    return take_snapshot($mountpoint, $tmp_snapshot_dir);
}

sub tmp_snapshot_dir {

    # Return path to $backup's tmp snapshot directory. If passed
    # 'DIE_UNLESS_EXISTS => 1' # then die unless the directory exists and is
    # readable+writable for the current user.

    arg_count_or_die(4, 6, @_);

    my $backup      = shift;
    my $backup_type = shift;
    my $tframe      = shift;
    my $config_ref  = shift;
    my %die_unless_exists = (DIE_UNLESS_EXISTS => 0, @_);

    is_timeframe_or_die($tframe);

    if ($backup_type eq 'ssh') {
        ssh_backup_exists_or_die($backup, $config_ref);
    }
    elsif ($backup_type eq 'ssh') {
        local_backup_exists_or_die($backup, $config_ref);
    }
    else { is_backup_type_or_die($backup_type) }

    my $tmp_snapshot_dir = yabsm_dir($config_ref) . "/.yabsm-var/${backup_type}_backups/$backup/tmp-snapshot/$tframe";

    if ($die_unless_exists{DIE_UNLESS_EXISTS}) {
        unless (-d $tmp_snapshot_dir && -r $tmp_snapshot_dir) {
            my $username = getpwuid $<;
            die "yabsm: error: no directory '$tmp_snapshot_dir' that is readable by user '$username'. This directory should have been initialized when the daemon started.\n";
        }
    }

    return $tmp_snapshot_dir;
}

sub take_bootstrap_snapshot {

    # Take a btrfs bootstrap snapshot of $backup and return its path.
    # If there is already a bootstrap snapshot for $backup then delete
    # it and take a new one.

    arg_count_or_die(3, 3, @_);

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

    if (my $bootstrap_snapshot = the_local_bootstrap_snapshot($backup, $backup_type, $config_ref)) {
        delete_snapshot($bootstrap_snapshot);
    }

    my $bootstrap_dir = bootstrap_snapshot_dir($backup, $backup_type, $config_ref, DIE_UNLESS_EXISTS => 1);
    my $snapshot_name = '.BOOTSTRAP-' . current_time_snapshot_name();

    return take_snapshot($mountpoint, $bootstrap_dir, $snapshot_name);
}

sub maybe_take_bootstrap_snapshot {

    # If $backup does not already have a bootstrap snapshot then take
    # a bootstrap snapshot and return its path. Otherwise return the
    # path of the existing bootstrap snapshot.

    arg_count_or_die(3, 3, @_);

    my $backup      = shift;
    my $backup_type = shift;
    my $config_ref  = shift;

    if (my $boot_snap = the_local_bootstrap_snapshot($backup, $backup_type, $config_ref)) {
        return $boot_snap;
    }

    return take_bootstrap_snapshot($backup, $backup_type, $config_ref);
}

sub bootstrap_snapshot_dir {

    # Return the path to $ssh_backup's bootstrap snapshot directory.
    # Logdie if the bootstrap snapshot directory does not exist.

    arg_count_or_die(3, 5, @_);

    my $backup      = shift;
    my $backup_type = shift;
    my $config_ref  = shift;
    my %or_die      = (DIE_UNLESS_EXISTS => 0, @_);

    is_backup_type_or_die($backup_type);

    if ($backup_type eq 'ssh') {
        ssh_backup_exists_or_die($backup, $config_ref);
    }
    if ($backup_type eq 'local') {
        local_backup_exists_or_die($backup, $config_ref);
    }

    my $bootstrap_dir = yabsm_dir($config_ref) . "/.yabsm-var/${backup_type}_backups/$backup/bootstrap-snapshot";

    if ($or_die{DIE_UNLESS_EXISTS}) {
        unless (-d $bootstrap_dir && -r $bootstrap_dir) {
            my  $username = getpwuid $<;
            die "yabsm: error: no directory '$bootstrap_dir' that is readable by user '$username'. This directory should have been initialized when the daemon started.\n";
        }
    }

    return $bootstrap_dir;
}

sub the_local_bootstrap_snapshot {

    # Return the local bootstrap snapshot for $backup if it exists and return
    # undef otherwise. Die if there are multiple bootstrap snapshots.

    arg_count_or_die(3, 3, @_);

    my $backup      = shift;
    my $backup_type = shift;
    my $config_ref  = shift;

    my $bootstrap_dir = bootstrap_snapshot_dir(
        $backup,
        $backup_type,
        $config_ref,
        DIE_UNLESS_EXISTS => 1
    );

    opendir my $dh, $bootstrap_dir or confess "yabsm: internal error: cannot opendir '$bootstrap_dir'";
    my @boot_snaps = grep { is_snapshot_name($_, ONLY_BOOTSTRAP => 1) } readdir($dh);
    map { $_ = "$bootstrap_dir/$_" } @boot_snaps;
    close $dh;

    if (0 == @boot_snaps) {
        return undef;
    }
    elsif (1 == @boot_snaps) {
        return $boot_snaps[0];
    }
    else {
        die "yabsm: error: found multiple local bootstrap snapshots for ${backup_type}_backup '$backup' in '$bootstrap_dir'\n";
    }
}

sub bootstrap_lock_file {

    # Return the path to the BOOTSTRAP-LOCK for $backup if it exists and return
    # undef otherwise.

    arg_count_or_die(3, 3, @_);

    my $backup      = shift;
    my $backup_type = shift;
    my $config_ref  = shift;

    my $rx = qr/yabsm-${backup_type}_backup_${backup}_BOOTSTRAP-LOCK/;

    my $lock_file = [ grep /$rx/, glob('/tmp/*') ]->[0];

    return $lock_file;
}

sub create_bootstrap_lock_file {

    # Create the bootstrap lock file for $backup. This function should be called
    # when performing the bootstrap phase of an incremental backup after checking
    # to make sure a lock file doesn't already exist. If a lock file already
    # exists we die, so check beforehand!

    arg_count_or_die(3, 3, @_);

    my $backup      = shift;
    my $backup_type = shift;
    my $config_ref  = shift;

    backup_exists_or_die($backup, $config_ref);
    is_backup_type_or_die($backup_type);

    if (my $existing_lock_file = bootstrap_lock_file($backup, $backup_type, $config_ref)) {
        die "yabsm: error: ${backup_type}_backup '$backup' is already locked out of performing a bootstrap. This was determined by the existence of '$existing_lock_file'\n";
    }

    # The file will be deleted when $tmp_fh is destroyed.
    my $tmp_fh = File::Temp->new(
        TEMPLATE => "yabsm-${backup_type}_backup_${backup}_BOOTSTRAP-LOCKXXXX",
        DIR      => '/tmp',
        UNLINK   => 1
    );

    return $tmp_fh;
}

sub is_backup_type_or_die {

    # Logdie unless $backup_type equals 'ssh' or 'local'.

    arg_count_or_die(1, 1, @_);

    my $backup_type = shift;

    unless ( $backup_type =~ /^(ssh|local)$/ ) {
        confess("yabsm: internal error: '$backup_type' is not 'ssh' or 'local'");
    }

    return 1;
}

1;
