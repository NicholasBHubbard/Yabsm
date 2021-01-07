#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;

               ####################################
               #          INPUT PARAMETERS        #
               ####################################

my $subvol_to_snapshot = $ARGV[0];
my $snapshot_dir       = $ARGV[1];
my $inner_dir          = $ARGV[2]; # hourly, daily, monthly, or yearly.
my $date_format        = $ARGV[3];

               ####################################
               #      SET UP DATE VARIABLES       #
               ####################################

my ($min, $hr, $day, $mon0, $yr0) = (localtime())[1..5];

my $mon = $mon0 + 1;   # month count starts at zero. 
my $yr  = $yr0 + 1900; # year represents years since 1900. 

               ####################################
               #  SUBROUTINES FOR BEAUTIFICATION  #
               ####################################

sub Pad {
  my $input = $_[0];
  if ($input < 10) {
    return '0' . $input;
  } else {
    return $input;
  }
}

sub Make_Snapshot_Name {
  my $date_format_input = $_[0];
  if ($date_format_input =~ 'mm/dd/yyyy')
    { return
      'day='.Pad($mon).'_'.Pad($day).'_'.Pad($yr).',time='.Pad($hr).':'.Pad($min);
    }
  elsif ($date_format_input =~ 'dd/mm/yyyy')
    { return
      'day='.Pad($day).'_'.Pad($mon).'_'.Pad($yr).',time='.Pad($hr).':'.Pad($min);
    }
  else {
    die "$date_format_input is not a valid date format";
  }
}

               ####################################
               #              EXECUTE             #
               ####################################

system('btrfs subvolume snapshot '
       . $subvol_to_snapshot . ' '
       . $snapshot_dir . '/'
       . $inner_dir . '/'
       . Make_Snapshot_Name($date_format));
