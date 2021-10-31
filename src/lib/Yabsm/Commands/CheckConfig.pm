#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Check if a config file is a valid yabsmrc file. If no config file
#  argument is passed then check /etc/yabsmrc. If the config is
#  erroneous print all errors to stderr and exit with nonzero status.
#  Else print 'all good' to stdout.

package Yabsm::Commands::CheckConfig;

use strict;
use warnings;
use v5.16.3;

# located using lib::relative in yabsm.pl
use Yabsm::Config;

sub die_usage {
    die "usage: yabsm check-config <?FILE>\n";
}

sub main {

    my $file = shift // '/etc/yabsm.conf';

    die_usage() if @_;

    # read_config() will kill the program with error
    # messages if the config is erroneous.
    Yabsm::Config::read_config( $file );

    say 'all good';

    return;
}

1;
