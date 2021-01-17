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

use Cwd qw(cwd);
use File::Copy qw(move);

if (getpwuid($<) ne 'root') {
    die "error: must be run by root user $!";
}

my $WORKING_DIR = cwd;

chown 0, 0,
  "${WORKING_DIR}/yabsm_update_conf.pl",
  "${WORKING_DIR}/yabsm_take_snapshot.pl",
  "${WORKING_DIR}/yabsm.pl",
  "${WORKING_DIR}/yabsmrc";

chmod 0774, 
  "${WORKING_DIR}/yabsm_update_conf.pl",
  "${WORKING_DIR}/yabsm_take_snapshot.pl",
  "${WORKING_DIR}/yabsm.pl";

chmod 0664, "${WORKING_DIR}/yabsmrc";

move "${WORKING_DIR}/yabsm_take_snapshot.pl", "/usr/local/sbin/yabsm-take-snapshot";
move "${WORKING_DIR}/yabsm_update_conf.pl", "/usr/local/sbin/yabsm-update-conf";
move "${WORKING_DIR}/yabsm_update_conf.pl", "/usr/sbin/yabsm";
move "${WORKING_DIR}/yabsmrc", "/etc/yabsmrc";

print "success! \n";
print "Please proceed to edit \"/etc/yabsmrc/\" to your liking and then run \"yabsm --update\" \n";

system("rm -rf $WORKING_DIR");
