#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  This script parses /etc/yabsmrc, checks for errors, and then writes the
#  appropriate cronjobs to /etc/crontab. The cronjobs will call the
#  /usr/local/sbin/yabsm-take-snapshot script.

die "Permission denied\n" if ($<);

use strict;
use warnings;
use 5.010;

use File::Copy 'move';

                 ####################################
                 #             GLOBALS              #
                 ####################################

my %YABSMRC_HASH = yabsmrc_to_hash(); 

my $YABSM_ROOT_DIR = $YABSMRC_HASH{'snapshot_directory'} . '/yabsm';

my @SUBVOLS_TO_SNAP = @{$YABSMRC_HASH{'I_want_to_snap_this_subvol'}};

                 ####################################
                 #               MAIN               #
                 ####################################

check_config_for_errors();

# Directories only need to be initialized the first time this script is run. 
initialize_directories() unless -d $YABSM_ROOT_DIR; 

write_cronjobs();

say 'success!';

                 ####################################
                 #      PROCESS CONFIG INTO HASH    #
                 ####################################

sub yabsmrc_to_hash {
    
    open (my $yabsmrc, '<', '/etc/yabsmrc')
      or die '[!] failed to open file /etc/yabsmrc';
    
    my %yabsmrc_hash;
    
    while (<$yabsmrc>) {
        
        next if /^[^a-zA-Z]/;

	$_ =~ s/\s//g; 
        
        my ($key, $val) = split /=/;

        # The 'I_want_to_snap_this_subvol' key points to an array of strings
	# like ('home,/home', 'root,/'). 
        if ($key eq 'I_want_to_snap_this_subvol') { 
            push @{$yabsmrc_hash{$key}}, $val; 
        }

	# All other keys point to a single value
        else {
            $yabsmrc_hash{$key} = $val;
        }
    }

    close $yabsmrc;

    return %yabsmrc_hash;
}

                 ####################################
                 #      CHECK CONFIG FOR ERRORS     #
                 ####################################

sub check_config_for_errors {
    
    if (! -d $YABSMRC_HASH{'snapshot_directory'}) {
	my $snap_dir = $YABSMRC_HASH{'snapshot_directory'};
	die "[!] could not find directory \"$snap_dir\"\n";
    }

    foreach (@SUBVOLS_TO_SNAP) {
        
	# We don't care about the path.
        my ($subv_name, undef) = split /,/;

        my @settings = my ($hourly_want,   $hourly_take, $hourly_keep,
			   $daily_want,    $daily_take,  $daily_keep,
			   $midnight_want, $midnight_keep,
			   $monthly_want,  $monthly_keep) 
	  = settings_for_subvol($subv_name);
        
        die "[!] missing a required setting for $subv_name\n"
	     if grep { not defined } @settings;
        
        die "[!] max value for ${subv_name}_hourly_take is 60\n"
          if ($hourly_take > 60);
        
        die "[!] max value for ${subv_name}_daily_take is 24\n"
          if ($daily_take > 24);
        
        die "[!] ${subv_name}_hourly_want must equal \"yes\" or \"no\"\n"
          unless ($hourly_want eq 'yes' || $hourly_want eq 'no');

        die "[!] ${subv_name}_hourly_want must equal \"yes\" or \"no\"\n"
          unless ($daily_want eq 'yes' || $daily_want eq 'no');

        die "[!] ${subv_name}_midnight_want must equal \"yes\" or \"no\"\n"
          unless ($midnight_want eq 'yes' || $midnight_want eq 'no');
        
        die "[!] ${subv_name}_monthly_want must equal \"yes\" or \"no\"\n"
          unless ($monthly_want eq 'yes' || $monthly_want eq 'no');
    }
    return;
}

                 ####################################
                 #           WRITE CRONJOBS         #
                 ####################################

sub write_cronjobs {
    
    # Write the cronjobs to '/etc/crontab'

    open (my $etc_crontab, '<', '/etc/crontab')
      or die "[!] failed to open /etc/crontab\n";

    open (my $tmp, '>', '/tmp/yabsm-update-tmp')
      or die "[!] failed to open tmp file at /tmp/yabsm-update-tmp\n";

    # Copy all lines from /etc/crontab into the tmp file, excluding the existing
    # yabsm cronjobs.
    while (<$etc_crontab>) {

	next if /yabsm-take-snapshot/;

	print $tmp $_;
    }

    # If there is text on the last line of the file then we must append a
    # newline or else that text will prepend our first cronjob.
    print $tmp "\n"; 

    # Now append the cronjob strings to $tmp file.
    say $tmp $_ for create_all_cronjob_strings();

    close $etc_crontab;
    close $tmp;

    move '/tmp/yabsm-update-tmp', '/etc/crontab';

    return;
} 

sub create_all_cronjob_strings {
    
    my @all_cron_strings; # This will be returned

    # Remember that these strings are 'name,path' for example 'home,/home'
    foreach (@SUBVOLS_TO_SNAP) {

        my ($subv_name, $mntpoint) = split /,/;

	# Every yabsm subvolume is required to have a value for these fields
        my ($hourly_want,   $hourly_take, $hourly_keep,
            $daily_want,    $daily_take,  $daily_keep,
            $midnight_want, $midnight_keep,
            $monthly_want,  $monthly_keep) = settings_for_subvol($subv_name); 
        
        my $hourly_cron   = ( '*/' . int(60 / $hourly_take) # Max is every minute
			    . ' * * * * root'
			    . ' /usr/local/sbin/yabsm-take-snapshot'
			    . ' --timeframe hourly'
			    . " --subvname $subv_name"
			    . " --subvmntpoint $mntpoint"
			    . " --snapdir $YABSM_ROOT_DIR"
			    . " --keeping $hourly_keep"
			    ) if $hourly_want eq 'yes';
        
        my $daily_cron    = ( '0 */' . int(24 / $daily_take) # Max is every hour
                            . ' * * * root'
			    . ' /usr/local/sbin/yabsm-take-snapshot'
			    . ' --timeframe daily'
                            . " --subvname $subv_name"
                            . " --subvmntpoint $mntpoint"
			    . " --snapdir $YABSM_ROOT_DIR"
                            . " --keeping $daily_keep"
			    ) if $daily_want eq 'yes';
        
	# Every night just before midnight. This makes the the date the day of.
        my $midnight_cron = ( '58 23 * * * root' 
                            . ' /usr/local/sbin/yabsm-take-snapshot'
			    . ' --timeframe midnight'
                            . " --subvname $subv_name"
                            . " --subvmntpoint $mntpoint"
			    . " --snapdir $YABSM_ROOT_DIR"
			    . " --keeping $midnight_keep"
			    ) if $midnight_want eq 'yes';
        
        my $monthly_cron  = ( '0 0 1 * * root' # First of every month
			    . ' /usr/local/sbin/yabsm-take-snapshot'
			    . ' --timeframe monthly'
                            . " --subvname $subv_name"
                            . " --subvmntpoint $mntpoint"
			    . " --snapdir $YABSM_ROOT_DIR"
                            . " --keeping $monthly_keep"
			    ) if $monthly_want eq 'yes';

	# Any of the cron strings may be undefined.
        push @all_cron_strings, grep { defined } ($hourly_cron,
						  $daily_cron,
						  $midnight_cron,
						  $monthly_cron);
    }
    return @all_cron_strings;
}

                 ####################################
                 #   HELPER FOR GATHERING SETTINGS  #
                 ####################################

sub settings_for_subvol {
    
    my $subv_name = shift;
    
    # All of these values are required to be specified
    my $hourly_want   = $YABSMRC_HASH{"${subv_name}_hourly_want"};
    my $hourly_take   = $YABSMRC_HASH{"${subv_name}_hourly_take"};
    my $hourly_keep   = $YABSMRC_HASH{"${subv_name}_hourly_keep"};

    my $daily_want    = $YABSMRC_HASH{"${subv_name}_daily_want"};
    my $daily_take    = $YABSMRC_HASH{"${subv_name}_daily_take"};
    my $daily_keep    = $YABSMRC_HASH{"${subv_name}_daily_keep"};

    my $midnight_want = $YABSMRC_HASH{"${subv_name}_midnight_want"};
    my $midnight_keep = $YABSMRC_HASH{"${subv_name}_midnight_keep"};

    my $monthly_want  = $YABSMRC_HASH{"${subv_name}_monthly_want"};
    my $monthly_keep  = $YABSMRC_HASH{"${subv_name}_monthly_keep"};
    
    return ($hourly_want,   $hourly_take, $hourly_keep,
            $daily_want,    $daily_take,  $daily_keep,
            $midnight_want, $midnight_keep,
            $monthly_want,  $monthly_keep);
}

                 ####################################
                 #         CREATE DIRECTORIES       #
                 ####################################

sub initialize_directories {

    # This subroutine is only necessary the first time this script is run.

    foreach (@SUBVOLS_TO_SNAP) {

        my ($subv_name, undef) = split /,/;

        mkdir $YABSM_ROOT_DIR; # /.snapshots/yabsm

        mkdir "$YABSM_ROOT_DIR/$subv_name";
        mkdir "$YABSM_ROOT_DIR/$subv_name/hourly";
        mkdir "$YABSM_ROOT_DIR/$subv_name/daily";

        mkdir "$YABSM_ROOT_DIR/$subv_name/midnight"
          if ($YABSMRC_HASH{"${subv_name}_midnight_want"} eq 'yes');
        
        mkdir "$YABSM_ROOT_DIR/$subv_name/monthly"
          if ($YABSMRC_HASH{"${subv_name}_monthly_want"} eq 'yes');
    }
    return;
}
