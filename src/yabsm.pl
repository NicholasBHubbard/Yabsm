#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm

use strict;
use warnings;
use 5.010;

sub usage {
    print <<END_USAGE;
Usage: yabsm [OPTION]

  --take-snap, -s <SUBVOL> <TIMEFRAME>    take a new snapshot

  --find, -f <?SUBVOL> <?QUERY>           find a snapshot of SUBVOL using QUERY

  --update-crontab, -u                    update cronjobs in /etc/crontab, based
                                          off settings specified in /etc/yabsmrc

  --check-config, -c                      check /etc/yabsmrc for errors. If
                                          errors are present print their info
                                          to stdout. Exit with code 0 in either
                                          case.

  --help, -h                              print help (this message) and exit

  Please see 'man yabsm' for more detailed information about yabsm.
END_USAGE
}

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);

# Import Yabsm.pm
use FindBin '$Bin';
use lib "$Bin/lib";
use Yabsm;

my @YABSM_TAKE_SNAPSHOT;
my $UPDATE_CRONTAB;
my @YABSM_FIND;
my $CHECK_CONFIG;
my $HELP;

GetOptions( 'take-snap|s=s{2}' => \@YABSM_TAKE_SNAPSHOT
	  , 'find|f=s{0,2}'    => \@YABSM_FIND
	  , 'update-crontab|u' => \$UPDATE_CRONTAB
	  , 'check-config|c'   => \$CHECK_CONFIG
	  , 'help|h'           => \$HELP
	  );

if ($HELP) {
    usage();
    exit 0;
}

if ($CHECK_CONFIG) {
    my %CONFIG = Yabsm::yabsmrc_to_hash('/etc/yabsmrc');  
    Yabsm::die_if_invalid_config(\%CONFIG);
    exit 0;
}

# TODO: change this to /etc/yabsmrc for production
my %CONFIG = Yabsm::yabsmrc_to_hash('/etc/yabsmrc');
Yabsm::die_if_invalid_config(\%CONFIG);

if ($UPDATE_CRONTAB) {

    die "[!] Error: must be root to update /etc/crontab\n" if $<;

    update_etc_crontab(\%CONFIG);

    exit 0;
}

if (@YABSM_TAKE_SNAPSHOT) {

    die "[!] Error: must be root to take a new snapshot\n" if $<;

    # --take-snapshot option takes two string args. We can be sure
    # that both args are defined as Getopt::Long will kill the program
    # if they are not.
    my ($subvol, $timeframe) = @YABSM_TAKE_SNAPSHOT;
    
    if (not is_subvol(\%CONFIG, $subvol)) {
	die "[!] Error: \"$subvol\" is not a yabsm subvolume\n";
    }

    if (not is_timeframe($timeframe)) {
	die "[!] Error: \"$timeframe\" is not a valid timeframe\n";
    }

    Yabsm::take_new_snapshot(\%CONFIG, $subvol, $timeframe);
    Yabsm::delete_appropiate_snapshots(\%CONFIG, $subvol, $timeframe);

    exit 0;
}


if (@YABSM_FIND) {

    # these variables may or may not be defined.
    my ($arg1, $arg2) = @YABSM_FIND;

    # the following logic exists to set the $subvol and $query variables
    my ($subvol, $query);

    if ($arg1) {
	if (Yabsm::is_subvol(\%CONFIG, $arg1)) {
	    $subvol = $arg1;
	}
	elsif (Yabsm::is_valid_query($arg1)) {
	    $query = $arg1;
	}
	else {
	    die "[!] Error: \"$arg1\" is neither a subvolume or query\n";
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
	    die "[!] Error: \"$arg2\" is neither a subvolume or query\n";
	}
    }

    if (not defined $subvol) {
	$subvol = Yabsm::ask_for_subvolume(\%CONFIG);
    }

    if (not defined $query) {
	$query = Yabsm::ask_for_query();
    }

    # $subvol and $query are properly set at this point
    my $snapshot_path = Yabsm::answer_query(\%CONFIG, $subvol, $query);

    say $snapshot_path;

    exit 0;
}

# no options were passed
usage();
exit 1;
