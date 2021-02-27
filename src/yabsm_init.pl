#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  This script will be run just after the user clones the github repository, and
#  can then be discarded.

die "Permission denied\n" if ($<);

use strict;
use warnings;
use 5.010;

use Cwd 'abs_path';
use File::Copy 'move';

sub dir_holding_yabsm_scripts {

    my $abs_path = abs_path($0);

    $abs_path =~ s/\/[^\/]+$//;

    return $abs_path;
}

# Should be '/home/user/yabsm/src' (because they just cloned the repo)
my $DIR_TO_YABSM_SCRIPTS = dir_holding_yabsm_scripts();

chown 0, 0,
  "$DIR_TO_YABSM_SCRIPTS/yabsm-take-snapshot",
  "$DIR_TO_YABSM_SCRIPTS/yabsm-update",
  "$DIR_TO_YABSM_SCRIPTS/yabsmrc";

chmod 774, "$DIR_TO_YABSM_SCRIPTS/yabsm-take-snapshot";
chmod 775, "$DIR_TO_YABSM_SCRIPTS/yabsm-update",
chmod 664, "$DIR_TO_YABSM_SCRIPTS/yabsmrc";

move "$DIR_TO_YABSM_SCRIPTS/yabsm_take_snapshot.pl", "/usr/local/sbin/yabsm-take-snapshot";
move "$DIR_TO_YABSM_SCRIPTS/yabsm_update_conf.pl", "/usr/local/sbin/yabsm-update";
move "$DIR_TO_YABSM_SCRIPTS/yabsmrc", "/etc/yabsmrc";

say "success!";
