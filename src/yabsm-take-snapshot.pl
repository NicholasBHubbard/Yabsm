#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  This script is used for taking and deleting a single snapshot. The only time
#  more than one snapshot is deleted is when the user changes their preferences
#  to keep less snapshots than they were keeping prior.
#  
#  Remember that snapshot names are formatted like: 'day=yyyy_mm_dd,time=hh_mm'
#
#  Exactly five command line arguments are required:
#  1: --subvmmtpoint -> 'home' would be mounted at /home, 'root' would be /
#  2: --subvname     -> the yabsm name of the subvolume to snapshot
#  3: --snapdir      -> yabsm snapshot directory, typically /.snapshots/yabsm
#  4: --timeframe    -> can be one of: (hourly, daily, midnight, monthly)
#  5: --keeping      -> number of snapshots being kept in this timeframe
#
#  This script is not meant to be used by the end user.

die "Permission denied\n" if $<;

use strict;
use warnings;
use 5.010;

use Getopt::Long qw(:config no_auto_abbrev);

                 ####################################
                 #      PROCESS INPUT PARAMETERS    #
                 ####################################

my $TIMEFRAME_ARG;
my $SUBVOL_NAME_ARG;
my $SUBVOL_MOUNTPOINT_ARG;
my $YABSM_ROOT_DIR_ARG;  
my $SNAPS_TO_KEEP_ARG;

GetOptions ('timeframe=s'    => \$TIMEFRAME_ARG,
            'subvname=s'     => \$SUBVOL_NAME_ARG,
	    'subvmntpoint=s' => \$SUBVOL_MOUNTPOINT_ARG,
            'snapdir=s'      => \$YABSM_ROOT_DIR_ARG,
            'keeping=i'      => \$SNAPS_TO_KEEP_ARG);

# All of the above options must be defined.
foreach ($TIMEFRAME_ARG,
	 $SUBVOL_NAME_ARG,
	 $SUBVOL_MOUNTPOINT_ARG,
	 $YABSM_ROOT_DIR_ARG,
	 $SNAPS_TO_KEEP_ARG) {
    die '[!] missing one of: { --timeframe, --subvname,'
                           . ' --subvmntpoint, --snapdir,'
	                   . " --keeping }\n"
			   if not defined;
}

                 ####################################
                 #           SETUP GLOBALS          #
                 ####################################

# $TARGET_DIRECTORY looks like '/.snapshots/yabsm/home/midnight'.
my $TARGET_DIRECTORY =
  "${YABSM_ROOT_DIR_ARG}/${SUBVOL_NAME_ARG}/$TIMEFRAME_ARG";

# An array of strings like 'day=yyyy_mm_dd,time=hh:mm'. We grep off the actual
# snap names from the full paths. This variable is used as our interface to keep
# track of how we have managed the snapshots.
my @EXISTING_SNAPS =
  grep { $_ = $1 if /([^\/]+$)/ } glob "$TARGET_DIRECTORY/*";

                 ####################################
                 #               MAIN               #
                 ####################################

take_new_snapshot();

# We will only delete more than 1 snapshot if the user changed their
# settings to keep less snapshots than they were previously.
delete_appropriate_snapshots(); 


