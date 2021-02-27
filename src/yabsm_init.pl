#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  This script will be run just after the user clones the github repository, and
#  can then be discarded. Please note that we have to move the scripts before we
#  modify ownership and permissions, otherwise those settings are lost when the
#  files are moved.

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

my $SCRIPTS_TARGET_DIR = '/usr/local/sbin';

move "$DIR_TO_YABSM_SCRIPTS/yabsm_take_snapshot.pl", "$SCRIPTS_TARGET_DIR/yabsm-take-snapshot";
move "$DIR_TO_YABSM_SCRIPTS/yabsm_update_conf.pl", "$SCRIPTS_TARGET_DIR/yabsm-update";

move "$DIR_TO_YABSM_SCRIPTS/yabsmrc", "/etc/yabsmrc";

# chown 0, 0,
#   "$SCRIPTS_TARGET_DIR/yabsm-take-snapshot",
#   "$SCRIPTS_TARGET_DIR/yabsm-update",
#   "/etc/yabsmrc";

# chmod 774, "$SCRIPTS_TARGET_DIR/yabsm-take-snapshot";
# chmod 775, "$SCRIPTS_TARGET_DIR/yabsm-update";
# chmod 664, '/etc/yabsmrc';

say 'success!';
