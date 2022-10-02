#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Provides the &do_local_backup subroutine, which performs a single local_backup
#  This is a top-level subroutine that is directly scheduled to be run by the
#  daemon.

use strict;
use warnings;
use v5.16.3;

package App::Yabsm::Backup::Local;

use App::Yabsm::Backup::Generic qw(take_tmp_snapshot
                                   take_bootstrap_snapshot
                                   the_local_bootstrap_snapshot
                                   bootstrap_lock_file
                                   create_bootstrap_lock_file
                                  );
use App::Yabsm::Snapshot qw(delete_snapshot sort_snapshots is_snapshot_name);
use App::Yabsm::Tools qw( :ALL );
use App::Yabsm::Config::Query qw( :ALL );

use File::Basename qw(basename);

use Exporter qw(import);
our @EXPORT_OK = qw(do_local_backup
                    do_local_backup_bootstrap
                    maybe_do_local_backup_bootstrap
                    the_remote_bootstrap_snapshot
                   );

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub do_local_backup {

    # Perform a $tframe local_backup for $local_backup.

    arg_count_or_die(3, 3, @_);

    my $local_backup = shift;
    my $tframe       = shift;
    my $config_ref   = shift;

    # We can't perform a backup if the bootstrap process is currently being
    # performed.
    if (bootstrap_lock_file($local_backup, 'local', $config_ref)) {
        return undef;
    }

    my $backup_dir = local_backup_dir($local_backup, $tframe, $config_ref);

    unless (is_btrfs_dir($backup_dir) && -r $backup_dir) {
        my $username = getpwuid $<;
        die "yabsm: error: '$backup_dir' is not a directory residing on a btrfs filesystem that is readable by user '$username'\n";
    }

    my $tmp_snapshot       = take_tmp_snapshot($local_backup, 'local', $tframe, $config_ref);
    my $bootstrap_snapshot = maybe_do_local_backup_bootstrap($local_backup, $config_ref);

    system_or_die("sudo -n btrfs send -p '$bootstrap_snapshot' '$tmp_snapshot' | sudo -n btrfs receive '$backup_dir' >/dev/null 2>&1");

    # @backups is sorted from newest to oldest
    my @backups = sort_snapshots(do {
        opendir my $dh, $backup_dir or confess("yabsm: internal error: cannot opendir '$backup_dir'");
        my @backups = grep { is_snapshot_name($_) } readdir($dh);
        closedir $dh;
        map { $_ = "$backup_dir/$_" } @backups;
        \@backups;
    });
    my $num_backups = scalar @backups;
    my $to_keep     = local_backup_timeframe_keep($local_backup, $tframe, $config_ref);

    # There is 1 more backup than should be kept because we just performed a
    # backup.
    if ($num_backups == $to_keep + 1) {
        my $oldest = pop @backups;
        delete_snapshot($oldest);
    }
    # We have not reached the backup quota yet so we don't delete anything.
    elsif ($num_backups <= $to_keep) {
        ;
    }
    # User changed their settings to keep less backups than they were keeping
    # prior.
    else {
        for (; $num_backups > $to_keep; $num_backups--) {
            my $oldest = pop @backups;
            delete_snapshot($oldest);
        }
    }

    return "$backup_dir/" . basename($tmp_snapshot);
}

sub do_local_backup_bootstrap {

    # Perform the bootstrap phase of an incremental backup for $local_backup.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    if (bootstrap_lock_file($local_backup, 'local', $config_ref)) {
        return undef;
    }

    # The lock file will be deleted when $lock_fh goes out of scope (uses File::Temp).
    my $lock_fh = create_bootstrap_lock_file($local_backup, 'local', $config_ref);

    if (my $local_boot_snap = the_local_bootstrap_snapshot($local_backup, 'local', $config_ref)) {
        delete_snapshot($local_boot_snap);
    }
    if (my $remote_boot_snap = the_remote_bootstrap_snapshot($local_backup, $config_ref)) {
        delete_snapshot($remote_boot_snap);
    }

    my $local_boot_snap = take_bootstrap_snapshot($local_backup, 'local', $config_ref);

    my $backup_dir_base = local_backup_dir($local_backup, undef, $config_ref);

    system_or_die("sudo -n btrfs send '$local_boot_snap' | sudo -n btrfs receive '$backup_dir_base' >/dev/null 2>&1");

    return $local_boot_snap;
}

sub maybe_do_local_backup_bootstrap {

    # Like &do_local_backup_bootstrap but only perform the bootstrap if it hasn't
    # been performed yet.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    my $local_boot_snap  = the_local_bootstrap_snapshot($local_backup, 'local', $config_ref);
    my $remote_boot_snap = the_remote_bootstrap_snapshot($local_backup, $config_ref);

    unless ($local_boot_snap && $remote_boot_snap) {
        $local_boot_snap = do_local_backup_bootstrap($local_backup, $config_ref);
    }

    return $local_boot_snap;
}

sub the_remote_bootstrap_snapshot {

    # Return the remote bootstrap snapshot for $local_backup if it exists and
    # return undef otherwise. Die if we find multiple bootstrap snapshots.

    arg_count_or_die(2, 2, @_);

    my $local_backup = shift;
    my $config_ref   = shift;

    my $backup_dir_base = local_backup_dir($local_backup, undef, $config_ref);

    unless (-d $backup_dir_base && -r $backup_dir_base) {
        my $username = getpwuid $<;
        die "yabsm: error: no directory '$backup_dir_base' that is readable by user '$username'\n";
    }

    opendir my $dh, $backup_dir_base or confess("yabsm: internal error: cannot opendir '$backup_dir_base'");
    my @boot_snaps = grep { is_snapshot_name($_, ONLY_BOOTSTRAP => 1) } readdir($dh);
    closedir $dh;

    map { $_ = "$backup_dir_base/$_" } @boot_snaps;

    if (0 == @boot_snaps) {
        return undef;
    }
    elsif (1 == @boot_snaps) {
        return $boot_snaps[0];
    }
    else {
        die "yabsm: error: found multiple remote bootstrap snapshots for local_backup '$local_backup' in '$backup_dir_base'\n";
    }
}

1;
