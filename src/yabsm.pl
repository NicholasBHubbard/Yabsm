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

  --find, -f <?SUBVOL> <?QUERY>           find a snapshot of SUBVOL using QUERY

  --update-crontab, -u                    update cronjobs in /etc/crontab, based
                                          off settings specified in /etc/yabsmrc

  --check-config, -c                      check /etc/yabsmrc for errors. If
                                          errors are present print their info
                                          to stdout. Exit with code 0 in either
                                          case.

  --help, -h                              print help (this message) and exit

  Please see 'man yabsm' for detailed information about yabsm.
END_USAGE
}

use FindBin '$Bin';
use lib "$Bin/lib";

use Yabsm::Base;
use Yabsm::Config;

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);

use Data::Dumper;

my @TAKE_SNAPSHOT;
my $UPDATE_CRONTAB;
my $DO_BACKUP;
my $BACKUP_BOOTSTRAP;
my $PRINT_CRONSTRINGS;
my @FIND;
my @CHECK_CONFIG;
my $HELP;

GetOptions( 'take-snap|s=s{2}'      => \@TAKE_SNAPSHOT
	  , 'find|f=s{0,2}'         => \@FIND
	  , 'update-crontab|u'      => \$UPDATE_CRONTAB
	  , 'check-config|c=s{0,1}' => \@CHECK_CONFIG
	  , 'do-backup|b=s'         => \$DO_BACKUP
	  , 'bootstrap-backup|k=s'  => \$BACKUP_BOOTSTRAP
	  , 'crons|C'               => \$PRINT_CRONSTRINGS
	  , 'help|h'                => \$HELP
	  );

if ($HELP) {
    usage();
    exit 0;
}

if (@CHECK_CONFIG) {

    my $config_path = pop @CHECK_CONFIG || '/etc/yabsmrc';

    Yabsm::Config::read_config($config_path);

    say 'all good';

    exit 0;
}

my $CONFIG_REF = Yabsm::Config::read_config('/etc/yabsmrc');
Yabsm::Base::initialize_directories($CONFIG_REF);

if ($UPDATE_CRONTAB) {

    die "[!] Permission Error: must be root to update /etc/crontab\n" if $<;

    Yabsm::Base::update_etc_crontab($CONFIG_REF);

    exit 0;
}

if (@TAKE_SNAPSHOT) {

    die "[!] Permission Error: must be root to take a new snapshot\n" if $<;

    # --take-snap option takes two string args. We can be sure
    # that both args are defined as Getopt::Long will kill the program
    # if they are not.

    my ($subvol, $timeframe) = @TAKE_SNAPSHOT;

    if (not Yabsm::Base::is_subvol($CONFIG_REF, $subvol)) {
	die "[!] Error: no such defined subvol '$subvol'\n"
    }

    if ($CONFIG_REF->{subvols}{$subvol}{"${timeframe}_want"} eq 'no') {
	die "[!] Error: subvol '$subvol' is not taking '$timeframe' snapshots\n";
    }

    Yabsm::Base::take_new_snapshot($CONFIG_REF, $subvol, $timeframe);
    Yabsm::Base::delete_old_snapshots($CONFIG_REF, $subvol, $timeframe);

    exit 0;
}

if (@FIND) {

    # these variables may or may not be defined.
    my ($arg1, $arg2) = @FIND;

    # the following logic exists to set the $subvol and $query variables
    my ($subvol, $query);

    if ($arg1) {
	if (Yabsm::Base::is_subvol($CONFIG_REF, $arg1)) {
	    $subvol = $arg1;
	}
	elsif (Yabsm::Base::is_valid_query($arg1)) {
	    $query = $arg1;
	}
	else {
	    die "[!] Error: '$arg1' is neither a subvolume or query\n";
	}
    }
    
    if ($arg2) {
	if (Yabsm::Base::is_subvol($CONFIG_REF, $arg2)) {
	    $subvol = $arg2;
	}
	elsif (Yabsm::Base::is_valid_query($arg2)) {
	    $query = $arg2;
	}
	else {
	    die "[!] Error: '$arg2' is neither a subvolume or query\n";
	}
    }

    if (not defined $subvol) {
	$subvol = Yabsm::Base::ask_user_for_subvolume($CONFIG_REF);
    }

    if (not defined $query) {
	$query = Yabsm::Base::ask_user_for_query();
    }

    # $subvol and $query are properly set at this point
    my @snaps = Yabsm::Base::answer_query($CONFIG_REF, $subvol, $query);

    say for @snaps;

    exit 0;
}

if ($PRINT_CRONSTRINGS) {

    my @cron_strings = Yabsm::Base::generate_cron_strings($CONFIG_REF);

    say for @cron_strings;

    exit 0;
}

if ($BACKUP_BOOTSTRAP) {

    die "[!] Permission Error: must be root to perform backup\n" if $<;

    # option takes backup arg
    my $backup = $BACKUP_BOOTSTRAP;

    if (not Yabsm::Base::is_backup($CONFIG_REF, $backup)) {
	die "[!] Error: no such defined backup '$backup'\n";
    }
    
    Yabsm::Base::do_backup_bootstrap($CONFIG_REF, $backup);

    exit 0;
}

if ($DO_BACKUP) {

    die "[!] Permission Error: must be root to perform backup\n" if $<;

    my $backup = $DO_BACKUP;

    if (not Yabsm::Base::is_backup($CONFIG_REF, $backup)) {
	die "[!] Error: no such defined backup '$backup'\n";
    }

    Yabsm::Base::do_backup($CONFIG_REF, $backup);

    exit 0;
}

# no options were passed
usage();
exit 1;
