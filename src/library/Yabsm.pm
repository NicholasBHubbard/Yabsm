#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  Functions used in yabsm-show.pl.

package Yabsm;

use strict;
use warnings;

use feature 'switch';

use Time::Piece;

use 5.010;

                 ####################################
                 #           DATA GATHERING         #
                 ####################################

sub all_snapshots { # has test

    # Gather all the snapshots (paths) for a given subvolume and timeframe.

    my ($yabsm_subvol, $timeframe) = @_;

    open (my $yabsmrc, '<', '/etc/yabsmrc')
      or die '[!] failed to open file /etc/yabsmrc';

    # First find the $target_dir. It should look like '/.snapshots/yabsm/home'.
    my $target_dir;
    while (<$yabsmrc>) {
        
        next if /^[^a-zA-Z]/;

	$_ =~ s/[\s\n]//g;

	my ($key, $val) = split /=/;
	
	if ($key eq 'snapshot_directory') {

	    $target_dir = "$val/yabsm/$yabsm_subvol/$timeframe";
	}
    }

    close $yabsmrc;

    my @all_snaps = glob "$target_dir/*";

    # The snapshots will be returned ordered from newest to oldest.
    return sort_snapshots(\@all_snaps);
}

sub all_subvols { # has test

    # Read /etc/yabsmrc and return an array of all the subvolumes being snapped.
    
    open (my $yabsmrc, '<', '/etc/yabsmrc')
      or die '[!] failed to open file /etc/yabsmrc';
    
    my @subvols;
    
    while (<$yabsmrc>) {
        
        next if /^[^a-zA-Z]/;

	$_ =~ s/[\s\n]//g; 
        
        my ($key, $val) = split /=/;

	if ($key eq 'I_want_to_snap_this_subvol') {
	    my ($subv_name, undef) = split /,/, $val;
	    push @subvols, $subv_name;
	}
    }

    close $yabsmrc;

    return @subvols;
}

sub ask_for_subvolume {

    # Prompt user to enter their desired subvolume. For convenience they only
    # need to enter a corresponding integer instead of the full timeframe.

    my @all_subvols = sort { $a cmp $b } all_subvols();

    # No need to prompt if there is only 1 subvolume.
    return $all_subvols[0] if scalar @all_subvols == 1;

    # Initialize the integer to subvolume hash.
    my %int_subvol_hash;
    for (my $i = 0; $i < scalar @all_subvols; $i++) {
	$int_subvol_hash{ $i + 1 } = $all_subvols[$i];
    }

    # Print prompt to screen.
    say 'enter subvolume';
    my $i = 1;
    while (my ($key, $val) = each %int_subvol_hash) {

	# After every 4 subvolumes print a newline. This prevents a user with
	# say 20 subvolumes from having them all printed as a giant string on
	# one line.
	if ($i % 4 == 0) {
	    print "$key -> $val\n";
	}
	else {
	    print "$key -> $val     ";
	}
	$i++
    }
    print "\n>>> ";

    my $input = <STDIN>;
    $input =~ s/[\s\n]//g; 

    if (defined $int_subvol_hash{ $input }) {
	return $int_subvol_hash{ $input };
    }

    else {
	print "$input is not valid! Try again!\n\n";
	return ask_for_subvolume();
    }
}

sub ask_for_timeframe {

    # Prompt user to enter their desired timeframe. For convenience they only
    # need to enter a corresponding integer instead of the full timeframe.

    my %int_timeframe_hash = ( 1 => 'hourly',
			       2 => 'daily',
			       3 => 'midnight',
			       4 => 'monthly' );

    say 'enter timeframe:';
    say '1 -> hourly     2 -> daily     3 -> midnight     4 -> monthly';
    print '>>> ';

    my $input = <STDIN>;
    $input =~ s/[\s\n]//g; 

    if (defined $int_timeframe_hash{ $input }) { 
	return $int_timeframe_hash{ $input };
    }

    else {
	print "$input is not valid! Try again!\n\n";
	return ask_for_timeframe();
    }
}

                 ####################################
                 #           DATA CONVERSION        #
                 ####################################

sub snap_to_nums {

    # Take a snapshot name and return an array containing, in order, the year,
    # month, day, hour, and minute. This works with both a full path or just a 
    # snapshot name.

    my $snap = shift;

    my @nums = $snap =~ m/day=(\d{4})_(\d{2})_(\d{2}),time=(\d{2}):(\d{2})/;

    return @nums;
}

sub nums_to_snap {

    # Take 5 integer arguments representing, in order, the year, month, day, 
    # hour, and minute then return a snapshot name string.

    my ($yr, $mon, $day, $hr, $min) = map { sprintf '%02d', $_ } @_;

    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

sub snap_to_time_obj {

    # Turn a snapshot name into a Time::Peice object. This is useful because we
    # can do time arithmetic (like adding hours or minutes) on the object.

    my $snap = shift;

    my ($yr, $mon, $day, $hr, $min) = snap_to_nums($snap);

    return Time::Piece->strptime("$yr/$mon/$day/$hr/$min",'%Y/%m/%d/%H/%M');
}

sub time_obj_to_snap {

    # Turn a Time::Piece object into a yabsm snapshot name string.

    my $t = shift;

    my $yr  = $t->year;
    my $mon = $t->mon;
    my $day = $t->mday;
    my $hr  = $t->hour;
    my $min = $t->min;

    return nums_to_snap($yr, $mon, $day, $hr, $min);
}

                 ####################################
                 #         SNAPSHOT ORDERING        #
                 ####################################

sub snap_later { 

    # True if $snap1 is a later snapshot than $snap2.

    my $snap1 = shift;
    my $snap2 = shift;

    my @snap_nums1 = snap_to_nums($snap1);
    my @snap_nums2 = snap_to_nums($snap2);

    # Take the lexical order. We know the arrays are equal length.
    for (my $i = 0; $i < scalar @snap_nums1; $i++) {

	return 1 if $snap_nums1[$i] > $snap_nums2[$i]; 
	return 0 if $snap_nums1[$i] < $snap_nums2[$i];
    }
    return 0; # The arrays must have been equivalent.
}

sub snap_earlier { 

    # True if $snap1 is an earlier snapshot than $snap2.

    my $snap1 = shift;
    my $snap2 = shift;

    my @snap_nums1 = snap_to_nums($snap1);
    my @snap_nums2 = snap_to_nums($snap2);

    # Take the lexical order. We know the arrays are equal length.
    for (my $i = 0; $i < scalar @snap_nums1; $i++) {

	return 1 if $snap_nums1[$i] < $snap_nums2[$i]; 
	return 0 if $snap_nums1[$i] > $snap_nums2[$i];
    }
    return 0; # The arrays must have been equivalent.
}

sub snap_later_or_eq { 

    # True if $snap1 is either later or the same as $snap2.

    my $snap1 = shift;
    my $snap2 = shift;

    my @snap_nums1 = snap_to_nums($snap1);
    my @snap_nums2 = snap_to_nums($snap2);

    # Take the lexical order. We know the arrays are equal length.
    for (my $i = 0; $i < scalar @snap_nums1; $i++) {

	return 1 if $snap_nums1[$i] > $snap_nums2[$i]; 
	return 0 if $snap_nums1[$i] < $snap_nums2[$i];
    }
    return 1; # The arrays must have been equivalent.
}

sub snap_earlier_or_eq { 

    # True if $snap1 is either earlier or the same as $snap2.

    my $snap1 = shift;
    my $snap2 = shift;

    my @snap_nums1 = snap_to_nums($snap1);
    my @snap_nums2 = snap_to_nums($snap2);

    # Take the lexical order. We know the arrays are equal length.
    for (my $i = 0; $i < scalar @snap_nums1; $i++) {

	return 1 if $snap_nums1[$i] < $snap_nums2[$i]; 
	return 0 if $snap_nums1[$i] > $snap_nums2[$i];
    }
    return 1; # The arrays must have been equivalent.
}

sub snap_equal { 

    # True if $snap1 and $snap2 were taken at the same time.

    my $snap1 = shift;
    my $snap2 = shift;

    my @snap_nums1 = snap_to_nums($snap1);
    my @snap_nums2 = snap_to_nums($snap2);

    for (my $i = 0; $i < scalar @snap_nums1; $i++) {
	return 0 if $snap_nums1[$i] != $snap_nums2[$i];
    }
    return 1;
}

sub latest_snap {

    # Take an array (reference) of snapshots and return the latest one.

    my @snapshots = @{$_[0]};

    # Shift out a snapshot to get things rolling.
    my $latest_snap = shift @snapshots;
    
    foreach my $snap (@snapshots) {
        $latest_snap = $snap if snap_later($snap, $latest_snap);
    }
    return $latest_snap;
}

sub earliest_snap {

    # Take an array (reference) of snapshots and return the earliest one.

    my @snapshots = @{$_[0]};

    # Shift out a snapshot to get things rolling.
    my $earliest_snap = shift @snapshots;
    
    foreach my $snap (@snapshots) {
        $earliest_snap = $snap if snap_earlier($snap, $earliest_snap);
    }
    return $earliest_snap;
}

sub sort_snapshots {

    # Sort an array of snapshots from newest to oldest with quicksort algorithm.

    my @snapshots = @{$_[0]};

    # base case
    if (scalar @snapshots <= 1) { return @snapshots }

    # recursive case
    my @bigger;
    my @smaller;
    my $pivot = pop @snapshots;
    foreach my $snap (@snapshots) {

	if (snap_later($snap, $pivot)) {
	    push (@bigger, $snap);
	}

	else { # $snap must be earlier than $pivot
	    push (@smaller, $snap);
	}
    }
    return sort_snapshots(\@bigger), $pivot, sort_snapshots(\@smaller);
}

                 ####################################
                 #          TIME ARITHMETIC         #
                 ####################################

sub add_n_minutes {

    # Return a snapshot time string that is $n minutes later than $snap.

    my ($n, $snap) = @_;

    my $time_obj = snap_to_time_obj($snap) + ($n * 60);

    return time_obj_to_snap($time_obj);
}

sub subtract_n_minutes {

    # Return a snapshot time string that is $n minutes earlier than $snap.

    my ($n, $snap) = @_;

    my $time_obj = snap_to_time_obj($snap) - ($n * 60);

    return time_obj_to_snap($time_obj);
}

sub add_n_hours {

    # Returns a snapshot time string that is $n hours later than $snap.

    my ($n, $snap) = @_;

    # 3600 seconds in an hour
    my $time_obj = snap_to_time_obj($snap) + ($n * 3600);

    return time_obj_to_snap($time_obj);
}
      
sub subtract_n_hours {

    # Return a snapshot time string that is $n hours earlier than $snap.

    my ($n, $snap) = @_;

    # 3600 seconds in an hour
    my $time_obj = snap_to_time_obj($snap) - ($n * 3600);

    return time_obj_to_snap($time_obj);
}

sub add_n_days {

    # Return a snapshot time that is $n days later than $snap.

    my ($n, $snap) = @_;

    # 86400 seconds in a day
    my $time_obj = snap_to_time_obj($snap) + ($n * 86400);

    return time_obj_to_snap($time_obj);
}

sub subtract_n_days {

    # Return a snapshot time that is $n days earlier than $snap.

    my ($n, $snap) = @_;

    # 86400 seconds in a day
    my $time_obj = snap_to_time_obj($snap) - ($n * 86400);

    return time_obj_to_snap($time_obj);
}
      
                 ####################################
                 #             FILTERING            #
                 ####################################

sub snaps_in_last_n_units {

    # All in one filtering function. You must pass in a string saying
    # your units. This string can be one of ('min', 'hr', 'day');
    
    my $n         = $_[0];
    my $unit      = $_[1];
    my @all_snaps = @{$_[2]};

    return snaps_in_last_n_minutes($n, \@all_snaps) if $unit eq 'min';
    return snaps_in_last_n_hours  ($n, \@all_snaps) if $unit eq 'hr';
    return snaps_in_last_n_days   ($n, \@all_snaps) if $unit eq 'day';

    die "$unit is not valid unit";
}

sub snaps_in_last_n_minutes {
    
    # Filter from an array (ref) of sorted snapshots, all of the snapshots that 
    # were taken in the last $n minutes.

    my $n     = $_[0];
    my @snaps = @{$_[1]}; 

    my $n_minutes_ago = subtract_n_minutes($n, current_time());
    
    my @filtered; # return this.

    foreach my $snap (@snaps) {

	if (snap_later($snap, $n_minutes_ago)) {
	    push @filtered, $snap;
	}
	else { last }
    }

    return @filtered;
}

sub snaps_in_last_n_hours { 
    
    # Filter from an array (ref) of sorted snapshots, all of the snapshots that 
    # were taken in the last $n hours.

    my $n     = $_[0];
    my @snaps = @{$_[1]}; 

    say for @snaps;

    my $n_hours_ago = subtract_n_hours($n, current_time());
    
    my @filtered; # return this.

    foreach my $snap (@snaps) {

	if (snap_later($snap, $n_hours_ago)) {
	    push @filtered, $snap;
	}
	else { last }
    }

    return @filtered;
}

sub snaps_in_last_n_days { 
    
    # Filter from an array (ref) of sorted snapshots, all of the snapshots that 
    # were taken in the last $n days. 

    my $n     = $_[0];
    my @snaps = @{$_[1]}; 

    my $n_days_ago = subtract_n_days($n, current_time());
    
    my @filtered; # return this.

    foreach my $snap (@snaps) {

	if (snap_later($snap, $n_days_ago)) {
	    push @filtered, $snap;
	}
	else { last }
    }

    return @filtered;
}

                 ####################################
                 #              QUERIES             #
                 ####################################

sub answer_query {

    # This is the culminating function of yabsm-find.pl 

    my $query     = $_[0];
    my @all_snaps = @{$_[1]}; 

    my @query_vals = split /\s/, $query;

    # Remove leading and trailing whitespace from all the values.
    s/^\s+|\s+$//g for @query_vals;

    my @filtered; # return this

    # say 'heello' if ;
    return;
}

                 ####################################
                 #           MISCELLANEOUS          #
                 ####################################

sub current_time { 
    
    # This is the exact same function as create_snapshot_name() in
    # yabsm-take-snapshot.pl
    
    my ($min, $hr, $day, $mon, $yr) =
      map { sprintf '%02d', $_ } (localtime)[1..5]; 
    
    $mon++;      # month count starts at zero. 
    $yr += 1900; # year represents years since 1900. 
    
    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

1;

