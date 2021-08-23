#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  This script parses /etc/yabsmrc, checks for errors, and then writes the
#  appropriate cronjobs to /etc/crontab. The cronjobs will call the
#  /usr/local/sbin/yabsm-take-snapshot script.

die "Permission denied\n" if $<;

use strict;
use warnings;
use 5.010;

use File::Copy 'move';

                 ####################################
                 #             GLOBALS              #
                 ####################################

my %YABSMRC_HASH = yabsmrc_to_hash(); 

my $YABSM_ROOT_DIR = $YABSMRC_HASH{'snapshot_directory'} . '/yabsm';

my @SUBVOLS_TO_SNAP = @{$YABSMRC_HASH{'I_want_to_snap_this_subvol'}};

                 ####################################
                 #               MAIN               #
                 ####################################

check_config_for_errors();

# Directories only need to be initialized the first time this script is run. 
initialize_directories() unless -d $YABSM_ROOT_DIR; 

write_cronjobs();

say 'success!';

                 ####################################
                 #           WRITE CRONJOBS         #
                 ####################################

sub write_cronjobs {
    
    # Write the cronjobs to '/etc/crontab'

    open (my $etc_crontab, '<', '/etc/crontab')
      or die "[!] Error: failed to open /etc/crontab\n";

    open (my $tmp, '>', '/tmp/yabsm-update-tmp')
      or die "[!] Error: failed to open tmp file at /tmp/yabsm-update-tmp\n";

    # Copy all lines from /etc/crontab into the tmp file, excluding the existing
    # yabsm cronjobs.
    while (<$etc_crontab>) {

	next if /yabsm-take-snapshot/;

	print $tmp $_;
    }

    # If there is text on the last line of the file then we must append a
    # newline or else that text will prepend our first cronjob.
    print $tmp "\n"; 

    # Now append the cronjob strings to $tmp file.
    say $tmp $_ for create_all_cronjob_strings();

    close $etc_crontab;
    close $tmp;

    move '/tmp/yabsm-update-tmp', '/etc/crontab';

    return;
} 

