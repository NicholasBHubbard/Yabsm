#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Function for performing local btrfs incremental backups.

use strict;
use warnings;
use v5.16.3;

package Yabsm::Backup::Local;

use Yabsm::Backup::Generic qw(maybe_take_bootstrap_snapshot take_tmp_snapshot);
use Yabsm::Snapshot qw(delete_snapshot sort_snapshots is_snapshot_name);
use Yabsm::Tools qw(arg_count_or_die system_or_die);
use Yabsm::Config::Query qw( :ALL );

use File::Basename qw(basename);

use Exporter 'import';
our @EXPORT_OK = qw(do_local_backup);

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub do_local_backup { # Is tested

    # Perform a $tframe local_backup for $local_backup.

    arg_count_or_die(3, 3, @_);

    my $local_backup = shift;
    my $tframe       = shift;
    my $config_ref   = shift;

    local_backup_wants_timeframe_or_die($local_backup, $tframe, $config_ref);

    my $backup_dir         = local_backup_dir($local_backup, $tframe, $config_ref);
    my $backup_dir_base    = local_backup_dir($local_backup, undef, $config_ref);

    # The destination partition could have been unmounted
    unless (-d $backup_dir) {
        die "yabsm: error: no such directory '$backup_dir' for local_backup '$local_backup'\n";
    }

    my $bootstrap_snapshot = maybe_take_bootstrap_snapshot($local_backup, 'local', $config_ref);
    my $tmp_snapshot       = take_tmp_snapshot($local_backup, 'local', $config_ref);

    system_or_die("sudo -n btrfs send -p '$bootstrap_snapshot' '$tmp_snapshot' | sudo -n btrfs receive '$backup_dir' >/dev/null 2>&1");

    delete_snapshot($tmp_snapshot);

    my @backups = sort_snapshots(do {
        opendir my $dh, $backup_dir or confess("yabsm: internal error: cannot opendir '$backup_dir'");
        my @backups = map { $_ = "$backup_dir/$_" } grep { is_snapshot_name($_, 0) } readdir($dh);
        closedir $dh;
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
    # We havent reached the backup quota yet so we don't delete anything
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

1;
