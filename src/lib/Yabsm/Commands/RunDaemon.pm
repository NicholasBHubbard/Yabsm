#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

# Start the Yabsm daemon.

use strict;
use warnings;
use v5.16.3;

# located using lib::relative in yabsm.pl
use Yabsm::Config;

sub die_usage {
    die "usage: yabsm daemon <start/stop/restart/status>\n"
}

sub main {

    die "yabsm: error: permission denied\n" if $<;

    my $config_ref = Yabsm::Config::read_config();

    
}
