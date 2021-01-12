#!/usr/bin/env perl

# Author: Nicholas Hubbard
# Email:  nhub73@keemail.me
# WWW:    https://github.com/NicholasBHubbard/yabsm

use strict;
use warnings;
use 5.010;

use Data::Dumper;

                 ####################################
                 #               MAIN               #
                 ####################################

my %YABSMRC_HASH = yabsmrc_to_hash();

check_valid_config();
write_cronjobs();

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
            push @{$yabsmrc_hash{$key}}, $val; # note this is an array
        }
        else {
            $yabsmrc_hash{$key} = $val;
        }
    }
    
    close $fh;
    return %yabsmrc_hash;
}

                 ####################################
                 #      CHECK CONFIG FOR ERRORS     #
                 ####################################

sub check_valid_config {
    
    my @subvols_to_check = @{$YABSMRC_HASH{'I_want_to_snap_this_subvol'}};
    
    foreach (@subvols_to_check) {
        
        my ($subv, undef) = split /,/, $_;
        
        my @settings = my ($hourly_take, $hourly_keep,
                           $daily_take, $daily_keep,
                           $midnight_want, $midnight_keep,
                           $monthly_want, $monthly_keep) 
          = grab_settings_for($subv);
        
        die ("\"$subv\" is missing one of these required settings:\n"
             . "${subv}_hourly_take   | ${subv}_hourly_keep\n${subv}_daily_take"
             . "    | ${subv}_daily_keep\n${subv}_midnight_want | "
             . "${subv}_midnight_keep \n${subv}_monthly_want "
             . " | ${subv}_monthly_keep\n $!")
          if grep { ! defined } (@settings);
        
        die ("max value for \"${subv}_hourly_take\" is '60'")
          if ($hourly_take > 60);
        
        die ("max value for \"${subv}_daily_take\" is '24'")
          if ($daily_take > 24);
        
        die ("value for \"${subv}_midnight_want\" must be \"yes\" or \"no\"")
          if ! ($midnight_want ne 'yes' xor $midnight_want ne 'no');
        
        die ("value for \"${subv}_monthly_want\" must be \"yes\" or \"no\"")
          if ! ($monthly_want ne 'yes' xor $monthly_want ne 'no');
    }
    return;
}

                 ####################################
                 #           WRITE CRONJOBS         #
                 ####################################

sub write_cronjobs {
    
    my @cronjobs;
    
    my @subvols_to_snap = @{$YABSMRC_HASH{'I_want_to_snap_this_subvol'}};
    
    foreach (@subvols_to_snap) {
        
        my ($subv_name, $mountpoint) = split /,/, $_;
        
        my @cron_strings = create_cronjob_strings_for($subv_name,$mountpoint);
    }
    return;
}

sub create_cronjob_strings_for {
    
    my $subv_name = shift;
    my $mountpoint = shift;
    
    my $snapshot_dir = $YABSMRC_HASH{'snapshot_directory'}; 
    
    my ($hourly_take, $hourly_keep,
        $daily_take, $daily_keep,
        $midnight_want, $midnight_keep,
        $monthly_want, $monthly_keep) = grab_settings_for($subv_name); 
    
    my $hourly_cron = ('*/' . int(60 / $hourly_take)
                       . ' * * * * root /root/yabsm/yabsm_take_snapshot '
                       . "--mntpoint $mountpoint --snapdir $snapshot_dir "
                       . "--subvname $subv_name --timeframe hourly "
                       . "--keeping $hourly_keep");
    
    my $daily_cron = ('0 */' . int(24 / $daily_take)
                      . ' * * * root /root/yabsm/yabsm_take_snapshot '
                      . "--mntpoint $mountpoint --snapdir $snapshot_dir "
                      . "--subvname $subv_name --timeframe daily "
                      . "--keeping $daily_keep");
    
    my $midnight_cron = ('0 0 * * * root /root/yabsm/yabsm_take_snapshot '
                         . "--mntpoint $mountpoint --snapdir $snapshot_dir "
                         . "--subvname $subv_name --timeframe midnight "
                         . "--keeping $midnight_keep")
      unless !defined $midnight_want;
    
    my $monthly_cron = ('0 0 1 * * root /rootyabsm/yabsm_take_snapshot '
                        . "--mntpoint $mountpoint --snapdir $snapshot_dir "
                        . "--subvname $subv_name --timeframe monthly "
                        . "--keeping $monthly_keep")
      unless !defined $monthly_want;
    
    return [$hourly_cron, $daily_cron, $midnight_cron, $monthly_cron];
}


                 ####################################
                 #              HELPERS             #
                 ####################################

sub grab_settings_for {
    
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

say "success";
