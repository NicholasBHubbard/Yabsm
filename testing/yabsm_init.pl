#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm

use strict;
use warnings;
use 5.010;

use Cwd qw(cwd);
use File::Copy qw(move);

if (getpwuid($<) ne 'root') {
    die "error: must be run by root user $!";
}

my $WORKING_DIR = cwd;

chown 0, 0,
  "${WORKING_DIR}/yabsm_update_conf.pl",
  "${WORKING_DIR}/yabsm_take_snapshot.pl";
chmod 0774, 
  "${WORKING_DIR}/yabsm_update_conf.pl",
  "${WORKING_DIR}/yabsm_take_snapshot.pl";

