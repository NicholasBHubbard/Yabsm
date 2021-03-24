#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  Script for quickly finding a snapshot. The heavy lifting is done by
#  the Yabsm.pm library.

die "[!] Missing dependency \"xclip\"\n" unless `which xclip 2>/dev/null`;

use strict;
use warnings;
use 5.010;

# use FindBin '$Bin';
# use lib "$Bin/library";

use lib '/usr/local/lib/yabsm/Yabsm.pm';

use Yabsm;

                 ####################################
                 #   DETERMINE SUBVOLUME AND QUERY  #
                 ####################################

my $subvol;
my $query;

# All of this (overly complicated) logic is designed to provide the user the 
# option to enter their subvolume or query from the command line, without the
# order in which they do so mattering.

if (defined $ARGV[0]) {
    if (Yabsm::is_subvol($ARGV[0])) {
	$subvol = $ARGV[0];
    }
    elsif (Yabsm::is_valid_query($ARGV[0])) {
	$query = $ARGV[0];
    }
    else { die "[!] invalid argument \"$ARGV[0]\"\n" }
}

if (defined $ARGV[1]) {
    if (Yabsm::is_subvol($ARGV[1])) {
	$subvol = $ARGV[1]
    }
    elsif (Yabsm::is_valid_query($ARGV[1])) {
	$query = $ARGV[1]
    }
    else { die "[!] invalid argument \"$ARGV[1]\"\n" }
}

if (not defined $subvol) {
    $subvol = Yabsm::ask_for_subvolume();
}

if (not defined $query) {
    $query = Yabsm::ask_for_query();
}

                 ####################################
                 #                MAIN              #
                 ####################################

my @all_snaps = Yabsm::all_snapshots($subvol);

my $snap_path = Yabsm::answer_query($query, \@all_snaps);

system "echo -n 'cd $snap_path' | xclip -selection clipboard";

say "successfully copied \"cd\" command to clipboard";
