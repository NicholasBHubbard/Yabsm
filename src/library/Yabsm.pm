#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  Functions used in yabsm-show.pl.
#
#  Do not forget that we always expect the snapshots to be sorted from newest to
#  oldest. The test script for this library is thrown away when the user
#  installs Yabsm.

package Yabsm;

use strict;
use warnings;
use 5.010;

use Time::Piece;
use Carp;

                 ####################################
                 #          USER INTERACTION        #
                 ####################################

sub ask_for_subvolume { # no test

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

    # Print prompt to stdout.
    say 'select subvolume';
    for (my $i = 1; $i <= scalar keys %int_subvol_hash; $i++) {

	my $key = $i;
	my $val = $int_subvol_hash{ $key };

	# After every N subvolumes print a newline. This prevents a user with
	# say 20 subvolumes from having them all printed as a giant string on
	# one line.
	if ($i % 4 == 0) {
	    print "$key -> $val\n";
	}
	else {
	    print "$key -> $val     ";
	}
    }
    print "\n>>> ";

    my $input = <STDIN>;
    $input =~ s/[\s]//g; 

    if (defined $int_subvol_hash{ $input }) {
	return $int_subvol_hash{ $input };
    }

    else {
	print "\"$input\" is not valid subvolume! Try again!\n\n";
	return ask_for_subvolume();
    }
}

sub ask_for_query { # no test

    # Prompt user for query

    print "enter query:\n>>> ";

    my $input = <STDIN>;
    $input =~ s/^\s+|[\s]+$//g; # trim both ends

    if ($input eq 'help') { help() }

    if (is_valid_query($input)) { return $input }  

    else {
	print "\"$input\" is not a valid query! Try again!\n\n";
	return ask_for_query();
    }
}

                 ####################################
                 #           DATA GATHERING         #
                 ####################################

sub all_snapshots { # has test

    # Gather all the snapshots (paths) for a given subvolume 
    # and return them sorted from newest to oldest.

    my $yabsm_subvol = $_[0];

    open (my $yabsmrc, '<', '/etc/yabsmrc')
      or die '[!] failed to open file /etc/yabsmrc';

    # Find our target directory. It should look like '/.snapshots/yabsm/home'
    my $target_dir;

    while (<$yabsmrc>) {
        
        next if /^[^a-zA-Z]/;
	
	$_ =~ s/\s//g;
	
	my ($key, $val) = split /=/;
	
	if ($key eq 'snapshot_directory') {

	    $target_dir = "$val/yabsm/$yabsm_subvol";

	    last;
	}
    }

    close $yabsmrc;

    my @all_snaps; # return this

    for my $tf (('hourly', 'daily', 'midnight', 'monthly')) {
	push @all_snaps, glob "$target_dir/$tf/*"; 
    }
    
    # The snapshots will be returned sorted from newest to oldest.
    return sort_snapshots(\@all_snaps);
}

sub all_subvols { # has test

    # Read /etc/yabsmrc and return an array of all the subvolumes being snapped.
    
    open (my $yabsmrc, '<', '/etc/yabsmrc')
      or die '[!] failed to open file /etc/yabsmrc';
    
    my @subvols;
    
    while (<$yabsmrc>) {
        
        next if /^[^a-zA-Z]/;

	$_ =~ s/\s//g; 
        
        my ($key, $val) = split /=/;

	if ($key eq 'I_want_to_snap_this_subvol') {
	    my ($subv_name, undef) = split /,/, $val;
	    push @subvols, $subv_name;
	}
    }

    close $yabsmrc;

    return @subvols;
}

                 ####################################
                 #           DATA CONVERSION        #
                 ####################################

sub snap_to_nums { # has test

    # Take a snapshot name and return an array containing, in order, the year,
    # month, day, hour, and minute. This works with both a full path or just a 
    # snapshot name.

    my $snap = shift;

    my @nums = $snap =~ m/day=(\d{4})_(\d{2})_(\d{2}),time=(\d{2}):(\d{2})/;

    return @nums;
}

sub nums_to_snap { # has test

    # Take 5 integer arguments representing, in order, the year, month, day, 
    # hour, and minute then return a snapshot name string.

    my ($yr, $mon, $day, $hr, $min) = map { sprintf '%02d', $_ } @_;

    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

sub snap_to_time_piece_obj { # has test

    # Turn a snapshot name into a Time::Peice object. This is useful because we
    # can do time arithmetic (like adding hours or minutes) on the object.

    my $snap = shift;

    my ($yr, $mon, $day, $hr, $min) = snap_to_nums($snap);

    return Time::Piece->strptime("$yr/$mon/$day/$hr/$min",'%Y/%m/%d/%H/%M');
}

sub time_piece_obj_to_snap { # has test

    # Turn a Time::Piece object into a snapshot name string.

    my $t = shift;

    my $yr  = $t->year;
    my $mon = $t->mon;
    my $day = $t->mday;
    my $hr  = $t->hour;
    my $min = $t->min;

    return nums_to_snap($yr, $mon, $day, $hr, $min);
}

                 ####################################
                 #              ORDERING            #
                 ####################################

sub sort_snapshots { # has test

    # Sort an array of snapshots from newest to oldest with quicksort algorithm.

    my @snapshots = @{$_[0]};
    
    # base case
    if (scalar @snapshots <= 1) { return @snapshots }

    # recursive case
    my @bigger;
    my @smaller;
    my $pivot = pop @snapshots;

    foreach my $snap (@snapshots) {

	if    (snap_later($snap, $pivot))   { push (@bigger,  $snap) }

	elsif (snap_earlier($snap, $pivot)) { push (@smaller, $snap) }

	else  { next } 
    }

    return sort_snapshots(\@bigger), $pivot, sort_snapshots(\@smaller);
}

sub snap_later { # has test

    # True if $snap1 is a later snapshot than $snap2.

    my $snap1 = shift;
    my $snap2 = shift;

    my @snap_nums1 = snap_to_nums($snap1);
    my @snap_nums2 = snap_to_nums($snap2);

    # Take the lexical order
    for (my $i = 0; $i < scalar @snap_nums1; $i++) {

	return 1 if $snap_nums1[$i] > $snap_nums2[$i]; 
	return 0 if $snap_nums1[$i] < $snap_nums2[$i];
    }
    return 0; # The arrays must have been equivalent.
}

sub snap_later_or_eq { # has test

    # True if $snap1 is either later or the same as $snap2.

    my $snap1 = shift;
    my $snap2 = shift;

    my @snap_nums1 = snap_to_nums($snap1);
    my @snap_nums2 = snap_to_nums($snap2);

    # Take the lexical order
    for (my $i = 0; $i < scalar @snap_nums1; $i++) {

	return 1 if $snap_nums1[$i] > $snap_nums2[$i]; 
	return 0 if $snap_nums1[$i] < $snap_nums2[$i];
    }
    return 1; # The arrays must have been equivalent.
}

sub snap_earlier { # has test

    # True if $snap1 is an earlier snapshot than $snap2.

    my $snap1 = shift;
    my $snap2 = shift;

    my @snap_nums1 = snap_to_nums($snap1);
    my @snap_nums2 = snap_to_nums($snap2);

    # Take the lexical order
    for (my $i = 0; $i < scalar @snap_nums1; $i++) {

	return 1 if $snap_nums1[$i] < $snap_nums2[$i]; 
	return 0 if $snap_nums1[$i] > $snap_nums2[$i];
    }
    return 0; # The arrays must have been equivalent.
}

sub snap_earlier_or_eq { # has test

    # True if $snap1 is either earlier or the same as $snap2.

    my $snap1 = shift;
    my $snap2 = shift;

    my @snap_nums1 = snap_to_nums($snap1);
    my @snap_nums2 = snap_to_nums($snap2);

    # Take the lexical order
    for (my $i = 0; $i < scalar @snap_nums1; $i++) {

	return 1 if $snap_nums1[$i] < $snap_nums2[$i]; 
	return 0 if $snap_nums1[$i] > $snap_nums2[$i];
    }
    return 1; # The arrays must have been equivalent.
}

                 ####################################
                 #          TIME ARITHMETIC         #
                 ####################################

sub n_units_ago { # has test

    # Subtract $n minutes, hours, or days from the current time.

    my ($n, $unit) = @_;

    my $seconds;

    if    ($unit =~ /^(m|mins?)$/)       { $seconds = 60    }
    elsif ($unit =~ /^(h|(hr|hour)s?)$/) { $seconds = 3600  }
    elsif ($unit =~ /^(d|days?)$/)       { $seconds = 86400 }
    else  { croak "\"$unit\" is an invalid time unit" }

    my $time_piece_obj = snap_to_time_piece_obj(current_time());

    $time_piece_obj -= ($n * $seconds);

    return time_piece_obj_to_snap($time_piece_obj);
}

                 ####################################
                 #          FIND ONE SNAPSHOT       #
                 ####################################

sub snap_closest_to { # has test

    my $target_snap = $_[0];
    my @all_snaps   = @{$_[1]};

    my $closest;

    for my $snap (@all_snaps) {

	if (snap_earlier_or_eq($snap, $target_snap)) {
	    $closest = $snap;
	    last;
	}
    }

    if (not defined $closest) {
	die "[!] couldn't find a snapshot close to \"$target_snap\"\n";
    }

    return $closest;
}

                 ####################################
                 #           QUERY ANSWERING        #
                 ####################################

sub answer_query { # no test

    # This function takes a query and an array (ref) of all the snapshots
    # and returns the desired snapshot. It is expected that a $query has
    # already been proven valid.

    my $query     = $_[0];
    my @all_snaps = @{$_[1]}; 

    my $return_snap;

    if (is_time($query)) {

	my @nums = $query =~ m/^(\d{4})([-\s_\/])(\d{1,2})\2(\d{1,2})\2(\d{1,2})\2(\d{1,2})$/;

	@nums = grep { $_ ne $2 } @nums;

	my $nums_as_snap = nums_to_snap(@nums);

	$return_snap = snap_closest_to($nums_as_snap, \@all_snaps);
    }

    elsif (is_relative_query($query)) {

	my (undef, $n, $units) = split /[-\s_\/]/, $query;

	my $n_units_ago = n_units_ago($n, $units);

	$return_snap = snap_closest_to($n_units_ago, \@all_snaps);
    }
    
    return $return_snap;
}

                 ####################################
                 #            VALIDATION            #
                 ####################################

sub is_valid_query { # has test

    # Return 1 iff $query is either a time like '2020-02-13-12-30' or
    # it is a relative time like 'back 40 mins'. 

    my $query = shift;

    if    (is_time($query))           { return 1 }
    elsif (is_relative_query($query)) { return 1 }
    else  { return 0 }
}

sub is_time { # has test

    # Return 1 iff $query is a time string like '2020-5-13-12-30'.

    my $query = shift;

    return $query =~ /^\d{4}([-\s_\/])\d{1,2}\1\d{1,2}\1\d{1,2}\1\d{1,2}$/;
}

sub is_relative_query { # has test

    # Return 1 iff $query is a relative time like 'back 4 hours'.

    my $query = shift;

    return
      $query =~ /^b(ack)?([-\s_\/])\d+\2(m$|mins?$|h$|hrs?$|hours?$|d$|days?$)/;
}

sub is_subvol { # has test

    # Return 1 iff $subvol is the name of a subvolume that the
    # user is taking snapshots of with Yabsm. 

    my $subvol = shift;

    my @all_subvols = all_subvols();

    for my $subv (@all_subvols) {

	return 1 if $subv eq $subvol;
    }

    return 0;
}
                 ####################################
                 #           MISCELLANEOUS          #
                 ####################################

sub current_time { # no test
    
    # This is the exact same function as create_snapshot_name() in
    # yabsm-take-snapshot.pl
    
    my ($min, $hr, $day, $mon, $yr) =
      map { sprintf '%02d', $_ } (localtime)[1..5]; 
    
    $mon++;      # month count starts at zero. 
    $yr += 1900; # year represents years since 1900. 
    
    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

1;
