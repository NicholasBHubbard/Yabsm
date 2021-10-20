#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Perform the bootstrap phase of an incremental backup.

package App::Commands::BackupBootstrap;

use strict;
use warnings;
use 5.010;

use App::Base;
use App::Config;

sub die_usage {
    die "usage: yabsm bootstrap-backup <BACKUP>\n";
}

sub main {

    die "error: permission denied\n" if $<;

    my $backup = shift // die_usage();

    if (@_) { die_usage() }

    my $config_ref = App::Config::read_config();

    if (not App::Base::is_backup($config_ref, $backup)) {
	die "error: no such defined backup '$backup'\n";
    }

    App::Base::initialize_directories($config_ref);

    App::Base::do_backup_bootstrap($config_ref, $backup);

    return;
}

1;
