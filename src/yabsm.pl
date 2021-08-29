#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm

use strict;
use warnings;
use 5.010;

sub usage {
    print <<END_USAGE;
Usage: yabsm [OPTION] [arg...]

  --take-snap, -s <SUBVOL> <CATEGORY>     take a new snapshot

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
my @CHECK_CONFIG;
my $HELP;

GetOptions( 'take-snap|s=s{2}'    => \@YABSM_TAKE_SNAPSHOT
	  , 'find|f=s{0,2}'       => \@YABSM_FIND
	  , 'update-crontab|u'    => \$UPDATE_CRONTAB
	  , 'check-config|c{0,1}' => \@CHECK_CONFIG
	  , 'help|h'              => \$HELP
	  );

if ($HELP) {
    usage();
    exit 0;
}

if (@CHECK_CONFIG) {

    # The user can optionally pass the absolute path to a config. If
    # no path is given we just check '/etc/yabsmrc'.
    my ($config_path) = @CHECK_CONFIG;

    my $config_ref;

    if ($config_path) {
	$config_ref = Yabsm::yabsmrc_to_hash($config_path);  
    }
    else {
	$config_ref = Yabsm::yabsmrc_to_hash('/etc/yabsmrc');  
    }

    Yabsm::die_if_invalid_config($config_ref);

    exit 0;
}

my $CONFIG_REF = Yabsm::yabsmrc_to_hash();
Yabsm::die_if_invalid_config($CONFIG_REF);

if ($UPDATE_CRONTAB) {

    die "[!] Error: must be root to update /etc/crontab\n" if $<;

    Yabsm::initialize_yabsm_directories($CONFIG_REF);
    Yabsm::update_etc_crontab($CONFIG_REF);

    exit 0;
}

if (@YABSM_TAKE_SNAPSHOT) {

    die "[!] Error: must be root to take a new snapshot\n" if $<;

    # --take-snapshot option takes two string args. We can be sure
    # that both args are defined as Getopt::Long will kill the program
    # if they are not.
    my ($subvol, $timeframe) = @YABSM_TAKE_SNAPSHOT;

    if (not Yabsm::is_subvol($CONFIG_REF, $subvol)) {
	die "[!] Error: \"$subvol\" is not a yabsm subvolume\n";
    }

    if (not Yabsm::is_timeframe($timeframe)) {
	die "[!] Error: \"$timeframe\" is not a valid timeframe\n";
    }

    Yabsm::initialize_yabsm_directories($CONFIG_REF);
    Yabsm::take_new_snapshot($CONFIG_REF, $subvol, $timeframe);
    Yabsm::delete_appropriate_snapshots($CONFIG_REF, $subvol, $timeframe);

    exit 0;
}


if (@YABSM_FIND) {

    # these variables may or may not be defined.
    my ($arg1, $arg2) = @YABSM_FIND;

    # the following logic exists to set the $subvol and $query variables
    my ($subvol, $query);

    if ($arg1) {
	if (Yabsm::is_subvol($CONFIG_REF, $arg1)) {
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
	if (Yabsm::is_subvol($CONFIG_REF, $arg2)) {
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
	$subvol = Yabsm::ask_for_subvolume($CONFIG_REF);
    }

    if (not defined $query) {
	$query = Yabsm::ask_for_query();
    }

    # $subvol and $query are properly set at this point
    my $snapshot_path = Yabsm::answer_query($CONFIG_REF, $subvol, $query);

    say $snapshot_path;

    exit 0;
}

# no options were passed
usage();
exit 1;
