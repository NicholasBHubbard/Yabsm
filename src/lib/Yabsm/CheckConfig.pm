#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

package Yabsm::CheckYabsmrc;

use strict;
use warnings;
use 5.010;

use lib '..';
use Yabsmrc;

sub die_usage {
    say 'Usage: yabsm check-config <?FILE>';
    exit 1;
}

sub main {

    my $config_path = shift // '/etc/yabsmrc';

    if (@_) { die_usage() }

    # read_config() will kill the program with error
    # messages if the config is erroneous.
    Yabsmrc::read_config($config_path);

    say 'all good';

    return;
}

1;
