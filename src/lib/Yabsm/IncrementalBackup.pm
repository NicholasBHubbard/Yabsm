#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

package Yabsm::IncrementalBackup;

use strict;
use warnings;
use 5.010;

use lib '..';
use Base;
use Yabsmrc;

sub die_usage {
    say 'Usage: yabsm incremental-bootstrap <BACKUP>';
    exit 1;
}

sub main {

    my $backup = shift // die_usage();

    if (@_) { die_usage() }

    my $config_ref = Yabsmrc::read_config();

    if (not Base::is_backup($config_ref, $backup)) {
	die "[!] Error: no such defined backup '$backup'\n";
    }

    Base::initialize_directories($config_ref);

    Base::do_backup($config_ref, $backup);

    return;
}

1;
