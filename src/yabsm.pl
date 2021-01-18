#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  This is the end-user script for YABSM (yet another btrfs snapshots manager).

use strict;
use warnings;
use 5.010;

use Getopt::Long;

my $UPDATE_ARG;

GetOptions ('update' => \$UPDATE_ARG);

if ($UPDATE_ARG) {
    system('/usr/local/sbin/yabsm-update-conf');
}
else {
    say 'aborting: you did not specify any options';
}
