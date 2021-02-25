#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  This script is for displaying and providing access to existing snapshots.

use strict;
use warnings;
use 5.010;

use Carp qw( croak );

say for all_snapshot_locations();

                 ####################################
                 #          YABSMRC READING         #
                 ####################################

sub all_snapshot_locations_1 {

    open (my $yabsmrc, '<', '/etc/yabsmrc')
      or die '[!] could not open /etc/yabsmrc';
    
    my $snapshot_root_dir;
    my @yabsm_subvols; # Names not paths.

    while (<$yabsmrc>) {
	$snapshot_root_dir = $1 if /snapshot_directory=(\S+)/;

	push @yabsm_subvols, $1 if /I_want_to_snap_this_subvol=([^,]+)/;
    }

    close $yabsmrc;

    my @categories = ('hourly','daily','midnight','monthly');

    # Heart of the algorithm. We need to combine our array of 
    foreach my $subv (@yabsm_subvols) { # $subv is a name not a a path.
	map { $cat = "$snapshot_root_dir/$cat" } @yabsm_subvols;

    }


     
}

sub create_snapshot_dir_paths {
    
}

sub all_snapshot_locations {
    my @subvols_being_snapped = subvols_being_snapped();
    my $snapshot_root_dir     = snapshot_root_dir();
    my @subvols_snapshot_dirs =
      map { $_ = "$snapshot_root_dir/$_/" } @subvols_being_snapped;

    my @sol;
    foreach my $category ('hourly','daily','midnight','monthly') {
	foreach (@subvols_snapshot_dirs) {
	    push @sol, ($_ . $category . '/');
	}
    }
    return grep { -e $_ } @sol;
}			    

sub subvols_being_snapped {
    my @subvols;
    open (my $fh, '<', '/etc/yabsmrc');
    while (<$fh>) {
	push @subvols, $1 if (/I_want_to_snap_this_subvol=([^,]+)/);
    }
    close $fh;
    return @subvols;
}

sub snapshot_root_dir {
    open (my $fh, '<', '/etc/yabsmrc');
    while (<$fh>) {
	close $fh and return $1 if (/snapshot_directory=(\S+)/);
    }
}

