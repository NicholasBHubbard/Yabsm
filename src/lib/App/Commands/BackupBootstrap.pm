#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Perform the bootstrap phase of a btrfs incremental backup.

package App::Commands::BackupBootstrap;

use strict;
use warnings;
use v5.16.3;

# located using lib::relative in yabsm.pl
use App::Base;
use App::Config;

sub die_usage {
    die "usage: yabsm bootstrap-backup <BACKUP>\n";
}

sub main {

    die "yabsm: error: permission denied\n" if $<;

    my $backup = shift // die_usage();

    die_usage() if @_;

    my $config_ref = App::Config::read_config();

    if (not App::Base::is_backup($config_ref, $backup)) {
	die "yabsm: error: no such defined backup '$backup'\n";
    }

    App::Base::initialize_directories($config_ref);

    App::Base::do_backup_bootstrap($config_ref, $backup);

    return;
}

1;
