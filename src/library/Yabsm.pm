#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  Core library of Yabsm.
#
#  The array of @existing_snaps that is passed around this library is
#  ALWAYS expected to be sorted from newest snapshot to oldest
#  snapshot.
#
#  See Yabsm.t for the testing of this library.

package Yabsm;

use strict;
use warnings;
use 5.010;

use Time::Piece;
use Carp;

                 ####################################
                 #              CONFIG              #
                 ####################################

sub yabsmrc_to_hash {
    
    open (my $yabsmrc, '<', '/etc/yabsmrc')
      or die '[!] failed to open file /etc/yabsmrc';
    
    my %yabsmrc_hash;
    
    while (<$yabsmrc>) {
        
        next if /^[#|\s]/;

	# strip off whitespace 
	s/\s//g; 
        
        my ($key, $val) = split /=/;

        # The 'yabsm_subvols' key associates to an array of strings
	# like ('home,/home', 'root,/').
        if ($key eq 'define_subvol') { 
            push @{$yabsmrc_hash{yabsm_subvols}}, $val; 
        }

	# All other keys point to a single value
        else {
            $yabsmrc_hash{$key} = $val;
        }
    }

    close $yabsmrc;

    return wantarray ? %yabsmrc_hash : \%yabsmrc_hash;
}

sub target_dir {

    # return path to the directory of a given subvolume and timeframe.

    my ($config_ref, $yabsm_subvol, $timeframe) = @_;

    my $snapshot_root_dir = $config_ref->{snapshot_directory};

    return "$snapshot_root_dir/yabsm/$yabsm_subvol/$timeframe";
}

                 ####################################
                 #          USER INTERACTION        #
                 ####################################

sub ask_for_subvolume { # no test

    # Prompt user to enter their desired subvolume. For convenience they only
    # need to enter a corresponding integer instead of the full timeframe.

    # sort the subvol names so they are displayed in alphabetical order.
    my @all_subvols = sort { $a cmp $b } all_yabsm_subvols();

    # No need to prompt if there is only 1 subvolume.
    return $all_subvols[0] if scalar @all_subvols == 1;

    # Initialize the integer to subvolume hash.
    my %int_subvol_hash;
    for (my $i = 0; $i < scalar @all_subvols; $i++) {
	$int_subvol_hash{ $i + 1 } = $all_subvols[$i];
    }

    # Print prompt to stdout.
    say 'select subvolume:';
    for (my $i = 1; $i <= scalar keys %int_subvol_hash; $i++) {

	my $key = $i;
	my $val = $int_subvol_hash{ $key };

	# After every 4 subvolumes print a newline. This prevents a user with
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

                 ####################################
                 #           DATA CONVERSION        #
                 ####################################

sub snapstring_to_nums { # has test

    # Take a snapshot name string and return an array containing, in
    # order, the year, month, day, hour, and minute. This works with
    # both a full path or just a snapshot name.

    my ($snap) = @_;

    my @nums = $snap =~ m/day=(\d{4})_(\d{2})_(\d{2}),time=(\d{2}):(\d{2})/;

    return wantarray ? @nums : \@nums;
}

sub nums_to_snapstring { # has test

    # Take 5 integer arguments representing, in order, the year,
    # month, day, hour, and minute then return a snapshot name string
    # that aligns with the format used in current_time_string().

    my ($yr, $mon, $day, $hr, $min) = map { sprintf '%02d', $_ } @_;

    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

sub snapstring_to_time_piece_obj { # has test

    # Turn a snapshot name string into a Time::Peice object. This is
    # useful because we can do time arithmetic (like adding hours or
    # minutes) on the object.

    my ($snap) = @_;

    my ($yr, $mon, $day, $hr, $min) = snapstring_to_nums($snap);

    return Time::Piece->strptime("$yr/$mon/$day/$hr/$min",'%Y/%m/%d/%H/%M');
}

sub time_piece_obj_to_snapstring { # has test

    # Turn a Time::Piece object into a snapshot name string.

    my ($time_piece_obj) = @_;

    my $yr  = $time_piece_obj->year;
    my $mon = $time_piece_obj->mon;
    my $day = $time_piece_obj->mday;
    my $hr  = $time_piece_obj->hour;
    my $min = $time_piece_obj->min;

    return nums_to_snapstring($yr, $mon, $day, $hr, $min);
}

                 ####################################
                 #         SNAPSHOT ORDERING        #
                 ####################################

sub sort_snapshots { # no test

    # return a sorted version of the inputted array ref of
    # snapshots. Sorted from newest to oldest. Works with either full
    # paths or just snapstrings. 

    my ($snaps_ref) = @_;

    my @sorted_snaps = sort { -compare_snaps($a, $b) } @$snaps_ref;

    return wantarray ? @sorted_snaps : \@sorted_snaps;
}

sub compare_snaps { # no test

    # return 1 if $snap1 is newer than $snap2, -1 if $snap2 is newer
    # than $snap1 and 0 if they are the same.

    my ($snap1, $snap2) = @_;

    my @snap1_nums = snapstring_to_nums($snap1);
    my @snap2_nums = snapstring_to_nums($snap2);

    for (my $i = 0; $i < scalar @snap1_nums; $i++) {

	return 1  if $snap1_nums[$i] > $snap2_nums[$i];
	return -1 if $snap1_nums[$i] < $snap2_nums[$i];
    }

    return 0;
}

                 ####################################
                 #          TIME ARITHMETIC         #
                 ####################################

sub n_units_ago { # has test

    # Subtract $n minutes, hours, or days from the current
    # time. Returns a snapstring.

    my ($n, $unit) = @_;

    my $seconds;

    if    ($unit =~ /^(m|mins?)$/)       { $seconds = 60    }
    elsif ($unit =~ /^(h|(hr|hour)s?)$/) { $seconds = 3600  }
    elsif ($unit =~ /^(d|days?)$/)       { $seconds = 86400 }
    else  { croak "\"$unit\" is an invalid time unit" }

    my $time_piece_obj = snapstring_to_time_piece_obj(current_time_string());

    $time_piece_obj -= ($n * $seconds);

    return time_piece_obj_to_snapstring($time_piece_obj);
}

                 ####################################
                 #          FIND ONE SNAPSHOT       #
                 ####################################

sub snap_closest_to { # has test

    # return the snapshot from @all_snaps that is closest to $target_snap

    my ($target_snap, $all_snaps_ref) = @_;

    my $closest;

    for my $snap (@$all_snaps_ref) {

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

    my ($query, $all_snaps_ref) = @_;

    my $return_snap;

    if (is_time($query)) {

	my @nums = $query =~ m/^(\d{4})([-\s_\/])(\d{1,2})\2(\d{1,2})\2(\d{1,2})\2(\d{1,2})$/;

	@nums = grep { $_ ne $2 } @nums;

	my $nums_as_snapstring = nums_to_snapstring(@nums);

	$return_snap = snap_closest_to($nums_as_snapstring, $all_snaps_ref);
    }

    elsif (is_relative_query($query)) {

	my (undef, $n, $units) = split /[-\s_\/]/, $query;

	my $n_units_ago = n_units_ago($n, $units);

	$return_snap = snap_closest_to($n_units_ago, $all_snaps_ref);
    }
    
    return $return_snap;
}

                 ####################################
                 #    SNAPSHOT QUERY VALIDATION     #
                 ####################################

sub is_valid_query { # has test

    # Return 1 iff $query is either a time like '2020-02-13-12-30' or
    # it is a relative time like 'back 40 mins'. 

    my ($query) = @_;

    if    (is_time($query))           { return 1 }
    elsif (is_relative_query($query)) { return 1 }
    else  { return 0 }
}

sub is_time { # has test

    # Return 1 iff $query is a time string like '2020-5-13-12-30'.

    my ($query) = @_;

    return $query =~ /^\d{4}([-\s_\/])\d{1,2}\1\d{1,2}\1\d{1,2}\1\d{1,2}$/;
}

sub is_relative_query { # has test

    # Return 1 iff $query is a relative time like 'back 4 hours'.

    my ($query) = @_;

    return
      $query =~ /^b(ack)?([-\s_\/])\d+\2(m$|mins?$|h$|hrs?$|hours?$|d$|days?$)/;
}

sub is_subvol { # has test

    # Return 1 iff $subvol is the name of a yabsm subvolume.

    my ($subvol, $config_ref) = @_;

    my $all_subvols_ref = %$config_ref{yabsm_subvols};

    foreach my $subv (@$all_subvols_ref) {
	return 1 if $subvol eq $subv;
    }

    return 0;
}

                 ####################################
                 #         SNAPSHOT CREATION        #
                 ####################################

sub take_new_snapshot { # no test

    # take a single read-only snapshot.

    my ($snapshot_dir) = @_;

    my $snapshot_name = current_time_string();

    system("btrfs subvolume snapshot -r $snapshot_dir/$snapshot_name"); 

    return;
}

sub current_time_string { # no test
    
    # This function should be used to create a snapshot string name of
    # the current time.
    
    my ($min, $hr, $day, $mon, $yr) =
      map { sprintf '%02d', $_ } (localtime)[1..5]; 
    
    $mon++;      # month count starts at zero. 
    $yr += 1900; # year represents years since 1900. 
    
    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

                 ####################################
                 #         SNAPSHOT DELETION        #
                 ####################################

sub delete_appropriate_snapshots { # no test
    
    my ($config_ref, $existing_snaps_ref, $yabsm_subvol, $timeframe) = @_;

    my $target_dir = target_dir($config_ref, $yabsm_subvol, $timeframe);

    my $num_snaps = scalar @$existing_snaps_ref;

    my $num_to_keep = %$config_ref{"${timeframe}_${yabsm_subvol}_keep"};

    # The most common case is there is 1 more snapshot than what should be
    # kept because we just took a snapshot.
    if ($num_snaps == $num_to_keep + 1) { 

	my $oldest_snap = pop @$existing_snaps_ref;

	system("btrfs subvolume delete $target_dir/$oldest_snap");

	return;
    }

    # We haven't reached the snapshot quota yet so we don't delete anything.
    elsif ($num_snaps <= $num_to_keep) { return } 

    # User changed their settings to keep less snapshots. 
    else { 
	
	while ($num_snaps > $num_to_keep) {

	    # note that pop mutates existing_snaps
            my $oldest_snap = pop @$existing_snaps_ref;
            
	    system("btrfs subvolume delete $target_dir/$oldest_snap");

	    $num_snaps--;
	} 
    }
    return;
}

1;
