#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm

use strict;
use warnings;
use 5.010;

# Import Yabsm module. 
use FindBin '$Bin';
use lib "$Bin/library";
use Yabsm;

                 ####################################
                 #                MAIN              #
                 ####################################

my $subvol    = Yabsm::ask_for_subvolume();
my $timeframe = Yabsm::ask_for_timeframe();

my @all_snaps = Yabsm::all_snapshots($subvol, $timeframe);

print "enter search query:\n>>> ";
my $query = <STDIN>;
$query =~ s/^\s+|\s+$//g; # trim trailing and leading whitespace

Yabsm::diagnose_query(Yabsm::test_valid_query($query));
my @snapshots = Yabsm::answer_query(\@all_snaps, $query);

Yabsm::print_the_snapshots();

say 'successfully copied the cd command to your clipboard';
