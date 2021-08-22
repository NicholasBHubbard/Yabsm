#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm

use strict;
use warnings;
use 5.010;

sub usage {
    print <<END_USAGE;
Usage: yabsm [OPTIONS] ...

  --take-snap, -s <SUBVOL> <TIMEFRAME>    take a new snapshot

  --find, -f <QUERY>                      find a snapshot based on QUERY

  --upd-conf, -u                          update cronjobs in /etc/crontab, based
                                          off settings specified in /etc/yabsmrc

  --quiet, -q                             suppress output

  --help, -h                              print help (this message) and exit

  Run 'man yabsm' for more help with yabsm
END_USAGE
}

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);

# Import Yabsm.pm
use FindBin '$Bin';
use lib "$Bin/lib";
use Yabsm;

# @YABSM_TAKE_SNAPSHOT is an array because the --take-snap option
# takes two args. See the documentation of Getopt::Long for more
# information on multi-arg options.
my @YABSM_TAKE_SNAPSHOT;
my $YABSM_UPDATE;
my @YABSM_FIND;
my $HELP;
my $QUIET;

GetOptions( 'take-snap|s=s{2}' => \@YABSM_TAKE_SNAPSHOT
	  , 'update|u'         => \$YABSM_UPDATE
	  , 'find|f=s{0,2}'    => \@YABSM_FIND
	  , 'quiet|q'          => \$QUIET
	  , 'help|h'           => \$HELP
	  );

if ($HELP) {
    usage();
    exit 0;
}

# TODO: change this to /etc/yabsmrc for production
my %CONFIG = Yabsm::yabsmrc_to_hash('../yabsmrc');
Yabsm::die_if_invalid_config(\%CONFIG);

if (@YABSM_TAKE_SNAPSHOT) {

    # --take-snapshot option takes two string args
    my ($subvol, $timeframe) = @YABSM_TAKE_SNAPSHOT;
    
    if (not is_subvol(\%CONFIG, $subvol)) {
	die "[!] Error: \"$subvol\" does not exist\n";
    }

    if (not $timeframe) {
	die "[!] Error: \"$timeframe\" is not a valid timeframe";
    }
}


if (@YABSM_FIND) {

    my ($subvol, $query);

    # these variables may or may not be defined
    my ($arg1, $arg2) = @YABSM_FIND;

    if ($arg1) {
	if (Yabsm::is_subvol(\%CONFIG, $arg1)) {
	    $subvol = $arg1;
	}
	elsif (Yabsm::is_valid_query($arg1)) {
	    $query = $arg1;
	}
	else {
	    die "[!] Error: \"$arg1\" is neither a subvolume or query";
	}
    }
    
    if ($arg2) {
	if (Yabsm::is_subvol(\%CONFIG, $arg2)) {
	    $subvol = $arg2;
	}
	elsif (Yabsm::is_valid_query($arg2)) {
	    $query = $arg2;
	}
	else {
	    die "[!] Error: \"$arg2\" is neither a subvolume or query";
	}
    }

    if (not defined $subvol) {
	$subvol = Yabsm::ask_for_subvolume(\%CONFIG);
    }

    if (not defined $query) {
	$query = Yabsm::ask_for_query();
    }

    my $all_snaps_ref = Yabsm::get_all_snapshots_of(\%CONFIG, $subvol);

    my $snapshot_path = Yabsm::answer_query($all_snaps_ref, $query);

    say $snapshot_path;
}
