#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Perform a single incremental backup. If the bootstrap phase has not 
#  been completed then perform then perform the bootstrap instead.

package App::Commands::IncrementalBackup;

use strict;
use warnings;
use 5.010;

use App::Base;
use App::Config;

sub die_usage {
    die "usage: yabsm incremental-bootstrap <BACKUP>\n";
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

    # do_backup() will perform the bootstrap phase if needed
    App::Base::do_backup($config_ref, $backup);

    return;
}

1;
