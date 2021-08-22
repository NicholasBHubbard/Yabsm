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

use File::Copy 'move';
use Time::Piece;
use List::Util 'any';
use Carp;

                 ####################################
                 #            YABSMRC IO            #
                 ####################################

sub yabsmrc_to_hash {
    
    # Read /etc/yabsmrc into a hash of key value pairs. This function
    # is used to create the config hash that is passed constantly
    # around the program.

    my ($yabsmrc_absolute_path) = @_;

    open (my $yabsmrc, '<', $yabsmrc_absolute_path)
      or croak "[!] Error: failed to open file \"$yabsmrc_absolute_path\"\n";
    
    my %yabsmrc_hash;
    
    while (<$yabsmrc>) {
        
        next if /^[#|\s]/;

	s/\s//g; 
        
        my ($key, $val) = split /=/;

        # The 'yabsm_subvols' key holds a hash of subvolume names
        # to paths.
        if ($key eq 'define_subvol') { 

	    my ($subv_name, $path) = split /,/, $val, 2;

	    $yabsmrc_hash{yabsm_subvols}{$subv_name} = $path;
        }

	# All other keys point to a single value
        else {
            $yabsmrc_hash{$key} = $val;
        }
    }

    close $yabsmrc;

    return wantarray ? %yabsmrc_hash : \%yabsmrc_hash;
}

sub die_if_invalid_config { # no test
    
    my ($config_ref) = @_;

    if (not -d $config_ref->{snapshot_directory}) {
	my $snap_dir = $config_ref->{snapshot_directory};
	croak "[!] Error: could not find directory \"$snap_dir\"\n";
    }

    # for each yabsm subvolume
    foreach my $subv_name (keys %{$config_ref->{yabsm_subvols}}) {
        
	my $subv_path = $config_ref->{yabsm_subvols}{$subv_name};
	
	croak "[!] Error: the subvolume \"$subv_name\" does not associate with a path\n"
	  if not defined $subv_path;
	
	croak "[!] Error: could not find directory \"$subv_path\"\n"
	  if not -d $subv_path;

	my $hourly_want = $config_ref->{"${subv_name}_hourly_want"};
	my $hourly_take = $config_ref->{"${subv_name}_hourly_take"};
	my $hourly_keep = $config_ref->{"${subv_name}_hourly_keep"};

	my $daily_want = $config_ref->{"${subv_name}_daily_want"};
	my $daily_take = $config_ref->{"${subv_name}_daily_take"};
	my $daily_keep = $config_ref->{"${subv_name}_daily_keep"};

	my $midnight_want = $config_ref->{"${subv_name}_midnight_want"};
	my $midnight_keep = $config_ref->{"${subv_name}_midnight_keep"};

	my $monthly_want = $config_ref->{"${subv_name}_monthly_want"};
	my $monthly_keep = $config_ref->{"${subv_name}_monthly_keep"};

	my @subv_settings = ( $hourly_want,   $hourly_take, $hourly_keep
			    , $daily_want,    $daily_take,  $daily_keep
		            , $midnight_want, $midnight_keep
		            , $monthly_want,  $monthly_keep
		            );

        croak "[!] Error: missing at least one required setting for \"$subv_name\"\n"
	     if grep { not defined } @subv_settings;

        croak "[!] Error: value for ${subv_name}_hourly_take must be an integer between 0 and 60\n"
          if ($hourly_take > 60 || $hourly_take < 0);
        
        croak "[!] Error: value for ${subv_name}_daily_take is must be an integer between 0 and 24\n"
          if ($daily_take > 24 || $daily_take < 0);
        
        croak "[!] Error: ${subv_name}_hourly_want must be either \"yes\" or \"no\"\n"
          unless ($hourly_want eq 'yes' || $hourly_want eq 'no');

        croak "[!] Error: ${subv_name}_hourly_want must be either \"yes\" or \"no\"\n"
          unless ($daily_want eq 'yes' || $daily_want eq 'no');

        croak "[!] Error: ${subv_name}_midnight_want must be either \"yes\" or \"no\"\n"
          unless ($midnight_want eq 'yes' || $midnight_want eq 'no');
        
        croak "[!] Error: ${subv_name}_monthly_want must be either \"yes\" or \"no\"\n"
          unless ($monthly_want eq 'yes' || $monthly_want eq 'no');
    }

    return;
}

sub initialize_directories { # no test

    my ($config_ref) = @_;

    my $yabsm_root_dir = $config_ref->{snapshot_dir} . "/yabsm";

    mkdir $yabsm_root_dir;

    foreach my $subv_name (keys %{$config_ref->{yabsm_subvols}}) {

        mkdir "$yabsm_root_dir/$subv_name";
	
        mkdir "$yabsm_root_dir/$subv_name/hourly"
          if ($config_ref->{"${subv_name}_hourly_want"} eq 'yes');

        mkdir "$yabsm_root_dir/$subv_name/daily"
          if ($config_ref->{"${subv_name}_daily_want"} eq 'yes');

        mkdir "$yabsm_root_dir/$subv_name/midnight"
          if ($config_ref->{"${subv_name}_midnight_want"} eq 'yes');
        
        mkdir "$yabsm_root_dir/$subv_name/monthly"
          if ($config_ref->{"${subv_name}_monthly_want"} eq 'yes');
    }

    return;
}

sub target_dir { # has test 

    # return path to the directory of a given subvolume and timeframe.

    my ($config_ref, $yabsm_subvol, $timeframe) = @_;

    my $snapshot_root_dir = $config_ref->{snapshot_directory};

    return "$snapshot_root_dir/yabsm/$yabsm_subvol/$timeframe";
}

                 ####################################
                 #          USER INTERACTION        #
                 ####################################

sub ask_for_subvolume { # no test

    # Prompt user to select their desired subvolume. Used for --find
    # option. 

    my ($config_ref) = @_;

    # sort the subvol names so they are displayed in alphabetical order.
    my @all_subvols = sort { $a cmp $b } all_yabsm_subvols($config_ref);

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
    $input =~ s/\s//g; 

    exit 0 if $input =~ /^q(uit)?$/;

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
    $input =~ s/^\s+|[\s]+$//g; # remove whitespace from both ends

    exit 0 if $input =~ /^q(uit)?$/;

    if (is_valid_query($input)) { return $input }  

    else {
	print "\"$input\" is not a valid query! Try again!\n\n";
	return ask_for_query();
    }
}

                 ####################################
                 #           DATA GATHERING         #
                 ####################################

# TODO (make this function work without reading /etc/yabsmrc)
sub get_all_snapshots_of { # no test

    # Read filesystem to gather all the snapshots (paths) for a given
    # subvolume and return them sorted from newest to oldest.

    my ($config_ref, $yabsm_subvol) = @_;

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
    my $all_snaps_sorted_ref = sort_snapshots(\@all_snaps);

    return wantarray ? @$all_snaps_sorted_ref : $all_snaps_sorted_ref;
}

sub all_yabsm_subvols { # no test

    my ($config_ref) = @_;

    return keys %{$config_ref->{yabsm_subvols}};
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

sub sort_snapshots { # has test

    # return a sorted version of the inputted array ref of
    # snapshots. Sorted from newest to oldest. Works with either full
    # paths or just snapstrings.

    my ($snaps_ref) = @_;

    my @sorted_snaps = sort { compare_snapshots($a, $b) } @$snaps_ref;

    return wantarray ? @sorted_snaps : \@sorted_snaps;
}

sub compare_snapshots { # has test

    # Return 1 if $snap1 is newer than $snap2.
    # Return -1 if $snap1 is older than $snap2
    # Return 0 if $snap1 and $snap2 are the same. 
    # Works with either full paths or just snapstrings.

    my ($snap1, $snap2) = @_;

    my @snap1_nums = snapstring_to_nums($snap1);
    my @snap2_nums = snapstring_to_nums($snap2);

    for (my $i = 0; $i < scalar @snap1_nums; $i++) {

	return 1  if $snap1_nums[$i] < $snap2_nums[$i];
	return -1 if $snap1_nums[$i] > $snap2_nums[$i];
    }

    # Must be the same
    return 0;
}

                 ####################################
                 #          TIME ARITHMETIC         #
                 ####################################

sub n_units_ago { # has test

    # Subtract $n minutes, hours, or days from the current
    # time. Returns a snapstring.

    my ($n, $unit) = @_;

    my $seconds_per_unit;

    if    ($unit =~ /^(m|mins|minutes)$/) { $seconds_per_unit = 60    }
    elsif ($unit =~ /^(h|hrs|hours)$/   ) { $seconds_per_unit = 3600  }
    elsif ($unit =~ /^(d|days)$/        ) { $seconds_per_unit = 86400 }
    else  { croak "\"$unit\" is an invalid time unit" }

    my $time_piece_obj = snapstring_to_time_piece_obj(current_time_string());

    $time_piece_obj -= ($n * $seconds_per_unit);

    return time_piece_obj_to_snapstring($time_piece_obj);
}

                 ####################################
                 #          FIND ONE SNAPSHOT       #
                 ####################################

sub snap_closest_to { # has test

    # return the snapshot from @all_snaps that is closest to $target_snap

    my ($target_snap, $all_snaps_ref) = @_;

    foreach my $snap (@$all_snaps_ref) {

	my $cmp = compare_snapshots($snap, $target_snap);

	return $snap if $cmp == 0 || $cmp == 1;
    }

    warn "WARNING: couldn't find a snapshot close to \"$target_snap\""
       . "instead returning the oldest snapshot on the system";

    return @$all_snaps_ref[-1];
}

                 ####################################
                 #           QUERY ANSWERING        #
                 ####################################

sub answer_query { # no test

    # This function takes a query and an array (ref) of all the snapshots
    # and returns the desired snapshot. It is expected that a $query has
    # already been proven valid.

    my ($all_snaps_ref, $query) = @_;

    my $snap_to_return;

    if (is_literal_time($query)) {

	my @nums = $query =~ m/^(\d{4})([-\s_\/])(\d{1,2})\2(\d{1,2})\2(\d{1,2})\2(\d{1,2})$/;

	@nums = grep { $_ ne $2 } @nums;

	my $nums_as_snapstring = nums_to_snapstring(@nums);

	$snap_to_return = snap_closest_to($nums_as_snapstring, $all_snaps_ref);
    }

    elsif (is_relative_query($query)) {

	my (undef, $n, $units) = split /[- ]/, $query;

	my $n_units_ago = n_units_ago($n, $units);

	$snap_to_return = snap_closest_to($n_units_ago, $all_snaps_ref);
    }
    
    return $snap_to_return;
}

                 ####################################
                 #    YABSM-FIND QUERY VALIDATION   #
                 ####################################

sub is_valid_query { # has test

    # Return 1 iff $query is either a time like '2020-02-13-12-30' or
    # it is a relative time like 'back 40 mins'. 

    my ($query) = @_;

    if    (is_literal_time($query))   { return 1 }
    elsif (is_relative_query($query)) { return 1 }
    else  { return 0 }
}

sub is_literal_time { # has test

    # Return 1 iff $query is a time string like '2020-5-13-12-30'.

    my ($query) = @_;

    return $query =~ /^\d{4}([- ])\d{1,2}\1\d{1,2}\1\d{1,2}\1\d{1,2}$/;
}

sub is_relative_query { # has test

    # Return 1 iff $query is a syntactically valid relative query.
    # Relative queries take the form of mode-amount-unit.
    # At this time the only mode field is 'back'.
    # The amount field must be a positive integer.
    # The unit field must be a time unit like minutes, hours, or days.

    my ($query) = @_;

    my ($mode, $amount, $unit) = split /[- ]/, $query;

    return 0 if any { not defined } ($mode, $amount, $unit);

    my $mode_correct = $mode =~ /^b(ack)?$/;

    my $amount_correct = $amount =~ /^[0-9]+$/;

    my $unit_correct = any { $_ eq $unit } qw/m mins minutes h hrs hours d days/;

    return $mode_correct && $amount_correct && $unit_correct;
}

sub is_subvol { # has test

    # Return 1 iff $subvol is the name of a yabsm subvolume.

    my ($config_ref, $subvol) = @_;

    return exists $config_ref->{yabsm_subvols}{$subvol};
}

                 ####################################
                 #           SNAPSHOT IO            #
                 ####################################

sub take_new_snapshot { # no test

    # take a single read-only snapshot.

    my ($config_ref, $yabsm_subvol, $timeframe) = @_;

    my $snapshot_dir = target_dir($config_ref, $yabsm_subvol, $timeframe);

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
