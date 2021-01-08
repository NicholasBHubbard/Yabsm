#!/usr/bin/env perl

# Author: Nicholas Hubbard
# Email:  nhub73@keemail.me
# WWW:    https://github.com/NicholasBHubbard/yabsm

use strict;
use warnings;
use 5.010;

=pod

=head1 DESCRIPTION

This script is used for taking and deleting a single snapshot.

Snapshot names look something like this: 'day=2021_01_31,time=15:30'.

Exactly five arguments must be given:
1: subvolume to be snapshotted
2: root snapshot directory (typically /.snapshots)
3: the yabsm name of the subvolume being snapshotted (ex: 'root' for '/')
4: the timeframe for the snapshot (hourly, daily, etc). 
6: the number of snapshots the user wants to keep for this subvolume/timeframe.

This script should not be used by the end user.

=cut

               ####################################
               #       GRAB INPUT PARAMETERS      #
               ####################################

my $subvol_to_snapshot_arg = $ARGV[0];
my $snap_root_dir_arg      = $ARGV[1];
my $yabsm_subvol_name_arg  = $ARGV[2];
my $timeframe_arg          = $ARGV[3]; 
my $snaps_to_keep_arg      = $ARGV[4];

               ####################################
               #               MAIN               #
               ####################################

delete_earliest_snapshot(); 
take_new_snapshot();

               ####################################
               #          SNAPSHOT CREATION       #
               ####################################

sub take_new_snapshot {

  system('btrfs subvolume snapshot '
         . $subvol_to_snapshot_arg . ' '
         . $snap_root_dir_arg . '/'
         . $yabsm_subvol_name_arg . '/'
         . $timeframe_arg . '/'
         . create_snapshot_name());
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

sub delete_earliest_snapshot {

  opendir(DIR,"${snap_root_dir_arg}/${yabsm_subvol_name_arg}/$timeframe_arg");

  my @snaps = grep(/^[^\.]/, readdir DIR); # exclude dot files

  closedir DIR;

  return if scalar(@snaps) < $snaps_to_keep_arg; 

  my $earliest_snap = $snaps[0];
  foreach my $snap (@snaps) {
    $earliest_snap = $snap
      if snapshot_lt($snap,$earliest_snap);
  }

  system('btrfs subvolume delete '
         . $snap_root_dir_arg . '/'
         . $yabsm_subvol_name_arg . '/'
         . $timeframe_arg . '/'
         . $earliest_snap);
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
  elsif (@tail1 == 0 && @tail2 == 0) { # array args are always equal length.
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
