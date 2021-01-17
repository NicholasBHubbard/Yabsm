#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  This is the end user script for YABSM (yet another btrfs snapshots manager).

use strict;
use warnings;
use 5.010;

use Getopt::Long;

if (getpwuid($<) ne 'root') {
    die "error: must be run by root user"; 
}

my $UPDATE;

GetOptions ('update' => \$UPDATE);

if ($UPDATE) {
    system('/usr/local/sbin/yabsm-update-conf');
}
else {
    say 'aborting: you did not specify any options';
}
