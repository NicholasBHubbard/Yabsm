#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  Testing for Config.pm.

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

print "Testing that all the valid configs ...\n";
for my $config (glob './configs/valid/*') {
    lives_ok { Yabsm::Config::read_config($config) } $config;
}

print "\nTesting that all the invalid configs ...\n";
for my $config (glob './configs/invalid/*') {
    dies_ok { Yabsm::Config::read_config($config) }
}
