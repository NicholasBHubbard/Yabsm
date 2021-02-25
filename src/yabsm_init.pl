#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  This script initializes YABSM. The ownership of all YABSM executables is
#  changed to the root user, and permissions are set to 0774. The scripts are
#  placed in  '/usr/local/sbin/yabsm-take-snapshot',
#  '/usr/local/sbin/yabsm-take-snapshot', and  '/usr/local/sbin/yabsm'.

die "Permission denied\n" if ($<);

use strict;
use warnings;
use 5.010;

use Cwd 'abs_path';
use File::Copy qw(move);

sub get_dir_with_yabsm_scripts {
    my $abs_path = abs_path($0);
    $abs_path =~ s/\/[^\/]+$//;
    return $abs_path;
}

my $DIR_TO_YABSM_SCRIPTS = get_dir_with_yabsm_scripts();

move "${DIR_TO_YABSM_SCRIPTS}/yabsm_take_snapshot.pl", "/usr/local/sbin/yabsm-take-snapshot";
move "${DIR_TO_YABSM_SCRIPTS}/yabsm_update_conf.pl", "/usr/local/sbin/yabsm-update";
move "${DIR_TO_YABSM_SCRIPTS}/yabsmrc", "/etc/yabsmrc";

chown 0, 0,
  "/usr/local/sbin/yabsm-update",
  "/usr/local/sbin/yabsm-take-snapshot",
  "/etc/yabsmrc";

chmod 755, "/usr/local/sbin/yabsm-update",

chmod 744, "/usr/local/sbin/yabsm-take-snapshot";

chmod 644, "/etc/yabsmrc";

print "success!\n";
