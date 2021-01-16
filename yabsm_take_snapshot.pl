#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  This script is used for taking and deleting a single snapshot.
#  
#  Snapshot names look something like this: 'day=2021_01_31,time=15:30'.
#
#  Exactly five arguments are required:
#  1: '--subv' subvolume to be snapshotted.
#  2: '--snapdir' root snapshot directory (typically /.snapshots).
#  3: '--subvname' the yabsm name of the subvolume being snapshotted.
#  4: '--timeframe' the timeframe for the snapshot (hourly, daily, etc). 
#  5: '--keeping' the number of snapshots to keep for the subvolume/timeframe.
#
#  This script is not meant to be used by the end user.

use strict;
use warnings;
use 5.010;

use Getopt::Long;

                 ####################################
                 #     PROCESS INPUT PARAMETERS     #
                 ####################################

my $SUBVOL_MOUNTPOINT_ARG;
my $SNAPSHOT_ROOT_DIR_ARG;
my $YABSM_SUBVOL_NAME_ARG;
my $TIMEFRAME_ARG;
my $SNAPS_TO_KEEP_ARG;

GetOptions ('mntpoint=s'  => \$SUBVOL_MOUNTPOINT_ARG,
            'snapdir=s'   => \$SNAPSHOT_ROOT_DIR_ARG,
            'subvname=s'  => \$YABSM_SUBVOL_NAME_ARG,
            'timeframe=s' => \$TIMEFRAME_ARG,
            'keeping=i'   => \$SNAPS_TO_KEEP_ARG);

foreach my $arg ($SUBVOL_MOUNTPOINT_ARG,
                 $SNAPSHOT_ROOT_DIR_ARG,
                 $YABSM_SUBVOL_NAME_ARG,
                 $TIMEFRAME_ARG,
                 $SNAPS_TO_KEEP_ARG) {
    die 'required: {--mntpoint, --snapdir, --subvname, --timeframe, --keeping}'
      if ! defined $arg;
}

my $WORKING_DIR =
  "${SNAPSHOT_ROOT_DIR_ARG}/${YABSM_SUBVOL_NAME_ARG}/$TIMEFRAME_ARG";

                 ####################################
                 #               MAIN               #
                 ####################################

delete_appropriate_snapshots(); 
take_new_snapshot();

                 ####################################
                 #          SNAPSHOT CREATION       #
                 ####################################

sub take_new_snapshot {
    
    system('btrfs subvolume snapshot -r '
           . $SUBVOL_MOUNTPOINT_ARG . ' '
           . $WORKING_DIR . '/'
           . create_snapshot_name()) == 0 # system() returns exit status
             or die "unable to create new snapshot in \"${WORKING_DIR}\"";
    return;
}

sub create_snapshot_name { 
    
    my ($min, $hr, $day, $mon, $yr) =
      map { sprintf '%02d', $_ }(localtime)[1..5];
    
    $mon++;      # month count starts at zero. 
    $yr += 1900; # year represents years since 1900. 
    
    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

                 ####################################
                 #        SNAPSHOT DELETION         #
                 ####################################

sub delete_appropriate_snapshots {
    
    opendir(my $dh, $WORKING_DIR)
      or die "failed to open directory $WORKING_DIR: $!";
    
    my @existing_snaps = grep(/^[^\.]/, readdir $dh); # exclude dot files
    
    closedir $dh;
    
    my $num_snaps = scalar @existing_snaps;
    
    if ($num_snaps < $SNAPS_TO_KEEP_ARG) { # don't delete any snapshots
        return; 
    } 
    elsif ($num_snaps > $SNAPS_TO_KEEP_ARG) { # user changed prefs to keep less
        
        for (my $i = 0; $i <= $num_snaps - $SNAPS_TO_KEEP_ARG; $i++) {
            
            my $snap_to_delete = earliest_snap(\@existing_snaps);
            
            delete_snapshot($snap_to_delete);
            
            @existing_snaps = grep $_ ne $snap_to_delete, @existing_snaps;
        }
    } 
    else { # delete just one snapshot.
        delete_snapshot(earliest_snap(\@existing_snaps)); 
    }
    return;
}

sub delete_snapshot {
    
    system('btrfs subvolume delete '
           . $WORKING_DIR . '/'
           . $_[0]) == 0 # system() returns exit status
             or die "failed to delete subvolume \"${WORKING_DIR}/$_[0]\"";
    return;
}

sub earliest_snap {
    
    my $earliest_snap = @{$_[0]}[0]; 
    
    foreach my $snap (@{$_[0]}) {
        $earliest_snap = $_ if snapshot_lt($snap,$earliest_snap);
    }
    return $earliest_snap;
}

sub snapshot_lt { 
    return lexically_lt(snap_name_to_lex_ord_nums($_[0]),
                        snap_name_to_lex_ord_nums($_[1]));
}

sub lexically_lt {
    
    my ($head1, @tail1) = @{$_[0]};
    my ($head2, @tail2) = @{$_[1]};
    
    if ($head1 > $head2) {
        return 0;
    }
    elsif ($head1 < $head2) {
        return 1;
    }
    elsif (@tail1 == 0 && @tail2 == 0) { # array args must be equal length
        return 0;
    }
    else {
        return lexically_lt(\@tail1,\@tail2);
    }
}

sub snap_name_to_lex_ord_nums {
    
    my ($yr, $mon, $day, $hr, $min) = $_[0] =~ m/([0-9]+)/g;
    
    return [$yr,$mon,$day,$hr,$min];
}
