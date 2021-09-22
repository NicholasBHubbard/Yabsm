#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT
#
#  Testing for the Config.pm library.

use strict;
use warnings;
use 5.010;

use Test::More 'no_plan';
use Test::Exception;
use Time::Piece;
use List::Util 'shuffle';

# Import Yabsm.pm
use FindBin '$Bin';
use lib "$Bin/../lib";

# Module to test
use Yabsm::Config;

print "Testing that all the valid configs parse successfully ...\n";
for my $config (glob './configs/valid/*') {
    lives_ok { Yabsm::Config::read_config($config) } $config;
}

print "\nTesting that all the invalid configs kill the program ...\n";
for my $config (glob './configs/invalid/*') {
    dies_ok { Yabsm::Config::read_config($config) } $config;
}
