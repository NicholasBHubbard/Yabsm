#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT
#
#  A valid remote backup config is setup so the root user can connect
#  to the remote host and run btrfs with sudo without having to enter
#  any passwords.

package App::Commands::TestRemoteBackupConfig;

use strict;
use warnings;
use v5.16.3;

# located using lib::relative in yabsm.pl
use App::Base;
use App::Config;

sub die_usage {
    die "usage: yabsm test-remote-backup <BACKUP>\n";
}

sub main {

    die "yabsm: error: permission denied\n" if $<;

    my $backup = shift // die_usage();

    die_usage() if @_;

    my $config_ref = App::Config::read_config();

    if (not App::Base::is_backup($config_ref, $backup)) {
	die "yabsm: error: no such defined backup '$backup'\n";
    }

    if (App::Base::is_local_backup($config_ref, $backup)) {
	die "yabsm: error: backup '$backup' is a local backup\n";
    }

    # new_ssh_connection() will kill the program if a passwordless
    # connection cannot be established.
    my $ssh = App::Base::new_ssh_connection( $config_ref->{backups}{$backup}{host} );

    # make sure user can use btrfs with non-interactive sudo
    if (my $out = $ssh->capture('sudo -n btrfs --help 2>&1 1>/dev/null')) {
        die "$out\n";
    }

    # make sure user has read/write permissions on the remote backup_dir
    my $backup_dir = $config_ref->{backups}{$backup}{backup_dir};

    my $backup_dir_exists =
      . "if ! [ -d $backup_dir ]; then ";
      . qq(echo -n "yabsm: error: no such directory '$backup_dir' at host '$host'"; fi);
    
    if (my $out = $ssh->capture( $backup_dir_exists )) {
        die "$out\n";
    }

    say 'all good';

    return;
}

1;
