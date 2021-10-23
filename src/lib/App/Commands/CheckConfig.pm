#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Check if a config file is a valid yabsmrc file. If no config file
#  argument is passed then check /etc/yabsmrc. If the config is
#  erroneous print all errors to stderr and exit with nonzero status.
#  Else print 'all good' to stdout.

package App::Commands::CheckConfig;

use strict;
use warnings;
use 5.010;

use App::Config;

sub die_usage {
    die "usage: yabsm check-config <?FILE>\n";
}

sub main {

    my $path = shift // '/etc/yabsmrc';

    if (@_) { die_usage() }

    # read_config() will kill the program with error
    # messages if the config is erroneous.
    App::Config::read_config( $path );

    say 'all good';

    return;
}

1;
