#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT
#
#  yabsm is a btrfs snapshot manager.

use strict;
use warnings;
use 5.010;

sub usage {
    print <<END_USAGE;
Usage: yabsm [OPTION] [arg...]

  Use exactly one option

  --find, -f <?SUBVOL/BACKUP> <?QUERY>    Find a snapshot of SUBVOL/BACKUP using
                                          QUERY. If the SUBVOL/BACKUP or QUERY
                                          args are omitted then the user (you)
                                          will be prompted for them.

  --check-config, -c <?CONFIG>            Check CONFIG for errors. If CONFIG is
                                          not specified check /etc/yabsmrc. If
                                          errors are present print their 
                                          messages to stdout and exist with non
                                          zero status, else print 'all good' to
                                          stdout.

  --update-crontab, -u                    Update cronjobs in /etc/crontab, based
                                          off settings specified in 
                                          /etc/yabsmrc.

  --print-crons, -C                       Display the cronjob strings that would
                                          be written to /etc/crontab if the
                                          --update-crontab option were used.

  --take-snap, -s <SUBVOL> <TIMEFRAME>    Take a new snapshot of SUBVOL for the
                                          TIMEFRAME category. It is not
                                          recommended to use this option
                                          manually.

  --do-backup, -b <BACKUP>                Perform an incremental backup of
                                          BACKUP. It is not recommended to use
                                          this option manually.

  --bootstrap-backup, -k <BACKUP>         Perform the boostrap phase of the
                                          btrfs incremental backup process for
                                          BACKUP.

  --test-remote-backup <BACKUP>           Test that BACKUP has been properly
                                          configured. For BACKUP to be properly
                                          configured yabsm should be able to
                                          connect the remote host and run the 
                                          btrfs command as root without having
                                          to enter any passwords.

  --help, -h                              Print help (this message) and exit.

  Please see 'man yabsm' for more detailed information about yabsm.
END_USAGE
}

use FindBin '$Bin';
use lib "$Bin/lib";

use Yabsm::Base;
use Yabsm::Config;

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);

my @TAKE_SNAPSHOT;
my $UPDATE_CRONTAB;
my $DO_BACKUP;
my $BACKUP_BOOTSTRAP;
my $PRINT_CRONSTRINGS;
my $TEST_REMOTE_BACKUP;
my @FIND;
my @CHECK_CONFIG;
my $HELP;

GetOptions( 'take-snap|s=s{2}'        => \@TAKE_SNAPSHOT
	  , 'find|f=s{0,2}'           => \@FIND
	  , 'update-crontab|u'        => \$UPDATE_CRONTAB
	  , 'check-config|c=s{0,1}'   => \@CHECK_CONFIG
	  , 'do-backup|b=s'           => \$DO_BACKUP
	  , 'bootstrap-backup|k=s'    => \$BACKUP_BOOTSTRAP
          , 'test-remote-backup=s'    => \$TEST_REMOTE_BACKUP
	  , 'print-crons|C'           => \$PRINT_CRONSTRINGS
	  , 'help|h'                  => \$HELP
	  );

if ($HELP) {
    usage();
    exit 0;
}

if (@CHECK_CONFIG) {

    my $config_path = pop @CHECK_CONFIG || '/etc/yabsmrc';

    # read_config() will kill program if the config has errors
    Yabsm::Config::read_config($config_path);

    say 'all good';

    exit 0;
}

if ($UPDATE_CRONTAB) {

    die "[!] Permission Error: must be root to update /etc/crontab\n" if $<;

    # read_config() will kill program if the config has errors
    my $config_ref = Yabsm::Config::read_config('/etc/yabsmrc');

    Yabsm::Base::update_etc_crontab($config_ref);

    exit 0;
}

if (@TAKE_SNAPSHOT) {

    die "[!] Permission Error: must be root to take a new snapshot\n" if $<;

    # --take-snap option takes two string args. We can be sure
    # that both args are defined as Getopt::Long will kill the program
    # if they are not.

    my ($subvol, $timeframe) = @TAKE_SNAPSHOT;

    my $config_ref = Yabsm::Config::read_config('/etc/yabsmrc');
    
    initialize_directories($config_ref);

    if (not Yabsm::Base::is_subvol($config_ref, $subvol)) {
	die "[!] Error: no such defined subvol '$subvol'\n"
    }

    if ($config_ref->{subvols}{$subvol}{"${timeframe}_want"} eq 'no') {
	die "[!] Error: subvol '$subvol' is not taking '$timeframe' snapshots\n";
    }

    Yabsm::Base::take_new_snapshot($config_ref, $subvol, $timeframe);
    Yabsm::Base::delete_old_snapshots($config_ref, $subvol, $timeframe);

    exit 0;
}

if (@FIND) {

    # these args may or may not be defined.
    my ($arg1, $arg2) = @FIND;

    # the following logic exists to set the $subject and $query variables.
    my ($subject, $query);

    my $config_ref = Yabsm::Config::read_config('/etc/yabsmrc');

    if ($arg1) {
	if (Yabsm::Base::is_subvol($config_ref, $arg1) ||
	    Yabsm::Base::is_backup($config_ref, $arg1)) {
	    $subject = $arg1;
	}
	elsif (Yabsm::Base::is_valid_query($arg1)) {
	    $query = $arg1;
	}
	else {
	    die "[!] Error: '$arg1' is neither a subvolume or query\n";
	}
    }
    
    if ($arg2) {
	if (Yabsm::Base::is_subvol($config_ref, $arg2) || 
            Yabsm::Base::is_backup($config_ref, $arg2)) {
	    $subject = $arg2;
	}
	elsif (Yabsm::Base::is_valid_query($arg2)) {
	    $query = $arg2;
	}
	else {
	    die "[!] Error: '$arg2' is neither a subvolume or query\n";
	}
    }

    if (not defined $subject) {
	$subject = Yabsm::Base::ask_user_for_subvol_or_backup($config_ref);
    }

    if (not defined $query) {
	$query = Yabsm::Base::ask_user_for_query();
    }

    # $subvol and $query are properly set at this point
    my @snaps = Yabsm::Base::answer_query($config_ref, $subject, $query);

    say for @snaps;

    exit 0;
}

if ($PRINT_CRONSTRINGS) {

    my $config_ref = Yabsm::Config::read_config('/etc/yabsmrc');

    my @cron_strings = Yabsm::Base::generate_cron_strings($config_ref);

    say for @cron_strings;

    exit 0;
}

if ($TEST_REMOTE_BACKUP) {

    die "[!] Permission Error: must be root to test remote backup\n" if $<;

    my $backup = $TEST_REMOTE_BACKUP;

    my $config_ref = Yabsm::Config::read_config('/etc/yabsmrc');

    if (not Yabsm::Base::is_remote_backup($config_ref, $backup)) {
	die "[!] Error: '$backup' is not a remote backup\n";
    }

    Yabsm::Base::test_remote_backup($config_ref, $backup);

    say 'all good';

    exit 0;
}

if ($BACKUP_BOOTSTRAP) {

    die "[!] Permission Error: must be root to perform backup\n" if $<;

    my $config_ref = Yabsm::Config::read_config('/etc/yabsmrc');

    Yabsm::Base::initialize_directories($config_ref);

    # option takes backup arg
    my $backup = $BACKUP_BOOTSTRAP;

    if (Yabsm::Base::is_remote_backup($config_ref, $backup)) {
	Yabsm::Base::do_backup_bootstrap_ssh($config_ref, $backup);
    }

    elsif (Yabsm::Base::is_local_backup($config_ref, $backup)) {
	Yabsm::Base::do_backup_bootstrap_local($config_ref, $backup);
    }

    else { die "[!] Error: no such defined backup '$backup'\n" }

    exit 0;
}

if ($DO_BACKUP) {
    
    die "[!] Permission Error: must be root to perform backup\n" if $<;

    my $config_ref = Yabsm::Config::read_config('/etc/yabsmrc');

    Yabsm::Base::initialize_directories($config_ref);

    my $backup = $DO_BACKUP;
    
    if (Yabsm::Base::is_remote_backup($config_ref, $backup)) {
	Yabsm::Base::do_backup_ssh($config_ref, $backup);
    }
    
    elsif (Yabsm::Base::is_local_backup($config_ref, $backup)) {
	Yabsm::Base::do_backup_local($config_ref, $backup);
    }
    
    else { die "[!] Error: no such defined backup '$backup'\n" }
    
    exit 0;
}

# no options were passed
usage();
exit 1;
