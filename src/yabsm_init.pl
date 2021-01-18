#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  This script initializes YABSM. The ownership of all YABSM executables is
#  changed to the root user. FINISH THIS LATER

use strict;
use warnings;
use 5.010;

use Cwd 'abs_path';
use File::Copy qw(move);

if (getpwuid($<) ne 'root') {
    die "error: must be run by root user $!";
}

sub get_working_dir {
    my $abs_path = abs_path($0);
    $abs_path =~ s/\/[^\/]+$//;
    return $abs_path;
}

my $WORKING_DIR = get_working_dir();

move "${WORKING_DIR}/yabsm_take_snapshot.pl", "/usr/local/sbin/yabsm-take-snapshot";
move "${WORKING_DIR}/yabsm_update_conf.pl", "/usr/local/sbin/yabsm-update-conf";
move "${WORKING_DIR}/yabsm.pl", "/usr/sbin/yabsm";
move "${WORKING_DIR}/yabsmrc", "/etc/yabsmrc";

chmod 0774, 
  "/usr/local/sbin/yabsm-update-conf",
  "/usr/local/sbin/yabsm-take-snapshot",
  "/usr/sbin/yabsm";

chmod 0664, "$/etc/yabsmrc";

chown 0, 0,
  "/usr/local/sbin/yabsm-update-conf",
  "/usr/local/sbin/yabsm-take-snapshot",
  "/usr/sbin/yabsm.pl",
  "/etc/yabsmrc";

print "success!\n";
