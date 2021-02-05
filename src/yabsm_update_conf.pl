#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  This script parses the '/etc/yabsmrc', checks for errors, and then writes the
#  appropriate cronjobs to '/etc/crontab'. The cronjobs will call the
#  '/usr/sbin/yabsm-take-snapshot' script.

use strict;
use warnings;
use 5.010;

use Scalar::Util qw(looks_like_number);
use File::Copy qw(move);

                 ####################################
                 #               MAIN               #
                 ####################################

my %YABSMRC_HASH = yabsmrc_to_hash(); # make settings global

check_valid_config();
create_directories(); 
write_cronjobs();
print "success!\n";

                 ####################################
                 #         PARSE CONFIG FILE        #
                 ####################################

sub yabsmrc_to_hash {
    
    open my $fh, '<:encoding(UTF-8)', '/etc/yabsmrc'
      or die 'failed to open file \"/etc/yabsmrc\": $!';
    
    my %yabsmrc_hash;
    
    foreach my $line (<$fh>) {
        
        next if ($line =~ /^[^a-zA-Z]/);
        
        my ($key, $val) = split /=/, $line;
        
        chomp $val; # $val is appended with newline
        
        if ($key eq 'I_want_to_snap_this_subvol') { 
            push @{$yabsmrc_hash{$key}}, $val; # creating an array
        }
        else {
            $yabsmrc_hash{$key} = $val;
        }
    }
    close $fh;
    return %yabsmrc_hash;
}

                 ####################################
                 #           WRITE CRONJOBS         #
                 ####################################

sub write_cronjobs {
    
    my $crontab_file = '/etc/crontab';
    my $tmp_file = '/tmp/yabsm_tmp';
    
    open (my $fh_crontab, '<', $crontab_file)
      or die "failed to open file \"/etc/crontab\"";
    open (my $fh_tmp, '>', $tmp_file)
      or die "failed to open tmp file at \"/tmp/yabsm_tmp\" $!";

    foreach (<$fh_crontab>) {
        if ($_ =~ /yabsm-take-snapshot/) {
	    print $fh_tmp " \n"; 
        }
        else {
            print $fh_tmp $_;
        }
    }

    my @cron_strings = create_all_cronjob_strings();
    foreach (@cron_strings) {
        print $fh_tmp "$_ \n";
    }

    close $fh_crontab;
    close $fh_tmp;
    move $tmp_file, $crontab_file or die $!;
    return;
} 

sub create_all_cronjob_strings {
    
    my @all_cron_strings;

    my @subvols_to_snap = @{$YABSMRC_HASH{'I_want_to_snap_this_subvol'}};

    my $snapshot_dir = $YABSMRC_HASH{'snapshot_directory'}; 

    foreach (@subvols_to_snap) {

        my ($subv_name, $mountpoint) = split /,/, $_;
        
        my ($hourly_take, $hourly_keep,
            $daily_take, $daily_keep,
            $midnight_want, $midnight_keep,
            $monthly_want, $monthly_keep) = gather_settings_for($subv_name); 
        
        my $hourly_cron = ('*/' . int(60 / $hourly_take)
                           . ' * * * * root /usr/local/sbin/yabsm-take-snapshot'
                           . " --mntpoint $mountpoint --snapdir $snapshot_dir"
                           . " --subvname $subv_name --timeframe hourly"
                           . " --keeping $hourly_keep");
        
        my $daily_cron = ('0 */' . int(24 / $daily_take)
                          . ' * * * root /usr/local/sbin/yabsm-take-snapshot'
                          . " --mntpoint $mountpoint --snapdir $snapshot_dir"
                          . " --subvname $subv_name --timeframe daily"
                          . " --keeping $daily_keep");
        
        my $midnight_cron = ('0 0 * * * root'
                             . ' /usr/local/sbin/yabsm-take-snapshot'
                             . " --mntpoint $mountpoint --snapdir $snapshot_dir"
                             . " --subvname $subv_name --timeframe midnight"
                             . " --keeping $midnight_keep")
          unless $midnight_want eq 'no';
        
        my $monthly_cron = ('0 0 1 * * root /usr/local/sbin/yabsm-take-snapshot'
                            . " --mntpoint $mountpoint --snapdir $snapshot_dir"
                            . " --subvname $subv_name --timeframe monthly"
                            . " --keeping $monthly_keep")
          unless $monthly_want eq 'no';

        push @all_cron_strings, grep { defined } ($hourly_cron,
                                                  $daily_cron,
                                                  $midnight_cron,
                                                  $monthly_cron);
    }
    return @all_cron_strings;
}

                 ####################################
                 #      CHECK CONFIG FOR ERRORS     #
                 ####################################

sub check_valid_config {
    
    my @subvols_to_check = @{$YABSMRC_HASH{'I_want_to_snap_this_subvol'}};
    
    my $snapshot_dir = $YABSMRC_HASH{'snapshot_directory'};

    die "$snapshot_dir does not exist" unless (-d $snapshot_dir);

    foreach (@subvols_to_check) {
        
        die ("parse error on \"I_want_to_snap_this_subvol=$_\":\n"
             . 'space on the right hand side of of the equals sign')
          if $_ =~ ' ';

        my ($subv_name, undef) = split /,/, $_;
        
        my @settings = my ($hourly_take, $hourly_keep,
                           $daily_take, $daily_keep,
                           $midnight_want, $midnight_keep,
                           $monthly_want, $monthly_keep) 
          = gather_settings_for($subv_name);
        
        die ("\"$subv_name\" is missing one of these required settings:\n"
             . "${subv_name}_hourly_take   | ${subv_name}_hourly_keep\n"
             . "${subv_name}_daily_take    | ${subv_name}_daily_keep\n"
             . "${subv_name}_midnight_want | ${subv_name}_midnight_keep \n"
             . "${subv_name}_monthly_want  | ${subv_name}_monthly_keep\n $!")
          if grep { ! defined } @settings;
        
        die ("found a negative value for a \"$subv_name\" setting")
          if grep { looks_like_number $_ and $_ < 0 } @settings;

        die ("max value for \"${subv_name}_hourly_take\" is '60'")
          if ($hourly_take > 60);
        
        die ("max value for \"${subv_name}_daily_take\" is '24'")
          if ($daily_take > 24);
        
        die ("value for \"${subv_name}_midnight_want\""
             . " must be \"yes\" or \"no\"")
          unless ($midnight_want eq 'yes' || $midnight_want eq 'no');
        
        die ("value for \"${subv_name}_monthly_want\""
             . " must be \"yes\" or \"no\"")
          unless ($monthly_want eq 'yes' || $monthly_want eq 'no');
    }
    return;
}

                 ####################################
                 #         CREATE DIRECTORIES       #
                 ####################################
 
sub create_directories {

    my @subvols_being_snapped = @{$YABSMRC_HASH{'I_want_to_snap_this_subvol'}};

    my $snapshot_dir = $YABSMRC_HASH{'snapshot_directory'};

    foreach (@subvols_being_snapped) {

        my ($subv_name, undef) = split /,/, $_;

        # if dir exists mkdir does not do anything
        mkdir "${snapshot_dir}/$subv_name";
        mkdir "${snapshot_dir}/${subv_name}/hourly";
        mkdir "${snapshot_dir}/${subv_name}/daily";

        mkdir "${snapshot_dir}/${subv_name}/midnight"
          if ($YABSMRC_HASH{"${subv_name}_midnight_want"} eq 'yes');
        
        mkdir "${snapshot_dir}/${subv_name}/monthly"
          if ($YABSMRC_HASH{"${subv_name}_monthly_want"} eq 'yes');
        }
    return:
    }

                 ####################################
                 #              HELPERS             #
                 ####################################

sub gather_settings_for {
    
    my $subv_name = shift;
    
    my $hourly_take   = $YABSMRC_HASH{"${subv_name}_hourly_take"};
    my $hourly_keep   = $YABSMRC_HASH{"${subv_name}_hourly_keep"};
    my $daily_take    = $YABSMRC_HASH{"${subv_name}_daily_take"};
    my $daily_keep    = $YABSMRC_HASH{"${subv_name}_daily_keep"};
    my $midnight_want = $YABSMRC_HASH{"${subv_name}_midnight_want"};
    my $midnight_keep = $YABSMRC_HASH{"${subv_name}_midnight_keep"};
    my $monthly_want  = $YABSMRC_HASH{"${subv_name}_monthly_want"};
    my $monthly_keep  = $YABSMRC_HASH{"${subv_name}_monthly_keep"};
    
    return ($hourly_take, $hourly_keep,
            $daily_take, $daily_keep,
            $midnight_want, $midnight_keep,
            $monthly_want, $monthly_keep);
}
