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

sub yabsmrc_to_hash { # no test
    
    # Read /etc/yabsmrc into a hash of key value pairs. Every setting
    # in /etc/yabsmrc has the form key=val, so we can naturally split
    # every line on the '=' sign. All in the hash simple scalar values
    # except for the 'subvols' key which associated to an array of
    # strings that represent the names of the subvolumes that the user
    # defined with the 'define_subvol' option.

    my ($yabsmrc_abs_path) = @_;

    open (my $yabsmrc, '<', $yabsmrc_abs_path)
      or die "[!] Error: failed to open file \"$yabsmrc_abs_path\"\n";
    
    my %yabsmrc_hash;
    
    while (<$yabsmrc>) {
        
        next if /^[#\s]/;

	# remove whitespace and end of line comments
	s/\s|#.*//g; 
        
        my ($key, $val) = split /=/;

        # The 'subvols' key holds an array of all names of the users subvolumes 
        if ($key eq 'define_subvol') { 

	    push @{$yabsmrc_hash{subvols}}, $val;
        }

	# All other keys associate to a single scalar value
        else {
            $yabsmrc_hash{$key} = $val;
        }
    }

    close $yabsmrc;

    return wantarray ? %yabsmrc_hash : \%yabsmrc_hash;
}

sub die_if_invalid_config { # no test
    
    # Comprehensively analyze the config hash produced by
    # yabsmrc_to_hash(). If errors exist print their messages to
    # STDERR and then die.

    my ($config_ref) = @_;

    # make a copy of the config to avoid modifying the actual config
    my %tmp_config = %$config_ref;

    my @errors;

    # check snapshot_directory
    my $snapshot_directory = $tmp_config{snapshot_directory}; 
    if (not defined $snapshot_directory) {
	push @errors, "[!] Config Error: missing required setting: \"snapshot_directory\"\n";
    }
    elsif (not -d $snapshot_directory) {
	push @errors, "[!] Config Error: could not find directory \"$snapshot_directory\"\n";
    }

    # for each defined subvolume
    foreach my $subv_name (@{$tmp_config{subvols}}) {

	# check this subvolumes timeframe settings
	my $subv_path      = $tmp_config{"${subv_name}_path"};
	my $hourly_want    = $tmp_config{"${subv_name}_hourly_want"};
	my $hourly_take    = $tmp_config{"${subv_name}_hourly_take"};
	my $hourly_keep    = $tmp_config{"${subv_name}_hourly_keep"};
	my $daily_want     = $tmp_config{"${subv_name}_daily_want"};
	my $daily_take     = $tmp_config{"${subv_name}_daily_take"};
	my $daily_keep     = $tmp_config{"${subv_name}_daily_keep"};
	my $midnight_want  = $tmp_config{"${subv_name}_midnight_want"};
	my $midnight_keep  = $tmp_config{"${subv_name}_midnight_keep"};
	my $monthly_want   = $tmp_config{"${subv_name}_monthly_want"};
	my $monthly_keep   = $tmp_config{"${subv_name}_monthly_keep"};

	# Deleting these values is important because later we can make
	# sure that we have processed every valid option, by asserting
	# that our hash has no more keys. Any left over keys must be
	# erroneous.
	delete $tmp_config{"${subv_name}_path"};
	delete $tmp_config{"${subv_name}_hourly_want"};
	delete $tmp_config{"${subv_name}_hourly_take"};
	delete $tmp_config{"${subv_name}_hourly_keep"};
	delete $tmp_config{"${subv_name}_daily_want"};
	delete $tmp_config{"${subv_name}_daily_take"};
	delete $tmp_config{"${subv_name}_daily_keep"};
	delete $tmp_config{"${subv_name}_midnight_want"};
	delete $tmp_config{"${subv_name}_midnight_keep"};
	delete $tmp_config{"${subv_name}_monthly_want"};
	delete $tmp_config{"${subv_name}_monthly_keep"};
        
	# subvolume names must start with alphabetical character
	if (not $subv_name =~ /^[a-zA-Z]/) {
	    push @errors, "[!] Config Error: invalid subvolume name \"$subv_name\" starts with non-alphabetical character\n";
	}

	# check that this subvolumes path is defined and is actually a
	# directory
	if (not defined $subv_path) {
	    push @errors, "[!] Config Error: missing required setting \"${subv_name}_path\"\n"
	}
	elsif (not -d $subv_path) {
	    push @errors, "[!] Config Error: could not find directory \"$subv_path\"\n"
	}
	else {} # all good



	
	if (not defined $hourly_want) {
	    push @errors, "[!] Config Error: missing required setting \"${subv_name}_hourly_want\"\n"
	}
	elsif (not ($hourly_want eq 'yes' || $hourly_want eq 'no')) {
	    push @errors, "[!] Config Error: ${subv_name}_hourly_want must be either \"yes\" or \"no\"\n";
	}
	else {} # all good




	if (not defined $hourly_take) {
	    push @errors, "[!] Config Error: missing required setting \"${subv_name}_hourly_take\"\n";
	}
	elsif (not ($hourly_take =~ /^\d+$/ && $hourly_take <= 60)) {
	    push @errors, "[!] Config Error: value for ${subv_name}_hourly_take must be an integer between 0 and 60\n";
	}
	else {} # all good

        


	if (not defined $hourly_keep) {
	    push @errors, "[!] Config Error: missing required setting \"${subv_name}_hourly_keep\"\n";
	}
	elsif (not ($hourly_keep =~ /^\d+$/)) {
	    push @errors, "[!] Config Error: value for ${subv_name}_hourly_keep must be a positive integer\n";
	}
	else {} # all good




	if (not defined $daily_want) {
	    push @errors, "[!] Config Error: missing required setting \"${subv_name}_daily_want\"\n";
	}
	elsif (not ($daily_want eq 'yes' || $daily_want eq 'no')) {
	    push @errors, "[!] Config Error: ${subv_name}_hourly_want must be either \"yes\" or \"no\"\n";
	}
	else {} # all good


	

	if (not defined $daily_take) {
	    push @errors, "[!] Config Error: missing required setting \"${subv_name}_daily_take\"\n";
	}
	elsif (not ($daily_take =~ /^\d+$/ && $daily_take <= 24)) {
	    push @errors, "[!] Config Error: value for ${subv_name}_daily_take must be an integer between 0 and 24\n";
	}
	else {} # all good
        



	if (not defined $daily_keep) {
	    push @errors, "[!] Config Error: missing required setting \"${subv_name}_daily_keep\"\n";
	}
	elsif (not ($daily_keep =~ /^\d+$/)) {
	    push @errors, "[!] Config Error: value for ${subv_name}_daily_keep must be a positive integer\n";
	}
	else {} # all good




	if (not defined $midnight_want) {
	    push @errors, "[!] Config Error: missing required setting \"${subv_name}_midnight_want\"\n";
	}
	elsif (not ($midnight_want eq 'yes' || $midnight_want eq 'no')) {
	    push @errors, "[!] Config Error: ${subv_name}_midnight_want must be either \"yes\" or \"no\"\n";
	}
	else {} # all good




	if (not defined $midnight_keep) {
	    push @errors, "[!] Config Error: missing required setting \"${subv_name}_midnight_keep\"\n";
	}
	elsif (not ($midnight_keep =~ /^\d+$/)) {
	    push @errors, "[!] Config Error: value for ${subv_name}_midnight_keep must be a positive integer\n";
	}
	else {} # all good




	if (not defined $monthly_want) {
	    push @errors, "[!] Config Error: missing required setting \"${subv_name}_monthly_want\"\n";
	}
	elsif (not ($monthly_want eq 'yes' || $monthly_want eq 'no')) {
	    push @errors, "[!] Config Error: ${subv_name}_monthly_want must be either \"yes\" or \"no\"\n";
	}
	else {} # all good




	if (not defined $monthly_keep) {
	    push @errors, "[!] Config Error: missing required setting \"${subv_name}_monthly_keep\"\n";
	}
	elsif (not ($monthly_keep =~ /^\d+$/)) {
	    push @errors, "[!] Config Error: value for ${subv_name}_monthly_keep must be a positive integer\n";
	}
	else {} # all good

    } # end of loop

    # delete non timeframe related keys
    delete $tmp_config{snapshot_directory};  
    delete $tmp_config{subvols};

    # Any key still not deleted must be erroneous
    foreach my $key (keys %tmp_config) {
	push @errors, "[!] Config Error: unknown setting \"$key\"\n";
    }

    if (@errors) {
	print STDERR for @errors;
	exit 1;
    }

    # all good
    return;
}

sub initialize_yabsm_directories { # no test

    my ($config_ref) = @_;

    my $yabsm_root_dir = $config_ref->{snapshot_directory} . "/yabsm";

    mkdir $yabsm_root_dir if not -d $yabsm_root_dir;

    foreach my $subv_name (@{$config_ref->{subvols}}) {

	my $subv_dir = "$yabsm_root_dir/$subv_name";

	if (not -d $subv_dir) {
	    mkdir $subv_dir;
	}

	my $hourly_want   = $config_ref->{"${subv_name}_hourly_want"};
	my $daily_want    = $config_ref->{"${subv_name}_daily_want"};
	my $midnight_want = $config_ref->{"${subv_name}_midnight_want"};
	my $monthly_want  = $config_ref->{"${subv_name}_monthly_want"};

	if ($hourly_want eq 'yes' && not -d "$subv_dir/hourly") {
	    mkdir "$subv_dir/hourly";
	}
	
	if ($daily_want eq 'yes' && not -d "$subv_dir/daily") {
	    mkdir "$subv_dir/daily";
	}

	if ($midnight_want eq 'yes' && not -d "$subv_dir/midnight") {
	    mkdir "$subv_dir/midnight";
	}

	if ($monthly_want eq 'yes' && not -d "$subv_dir/monthly") {
	    mkdir "$subv_dir/monthly";
	}
    }
    
    return;
}

sub target_dir { # has test 

    # return path to the directory of a given subvolume. Likely
    # returns a string like '/.snapshots/yabsm/root'

    my ($config_ref, $subvol) = @_;

    my $snapshot_root_dir = $config_ref->{snapshot_directory};
    
    return "$snapshot_root_dir/yabsm/$subvol";
}

                 ####################################
                 #          USER INTERACTION        #
                 ####################################

sub ask_for_subvolume { # no test

    # Prompt user to select their desired subvolume. Used for the
    # --find option when the user doesn't explicitly pass the
    # subvolume on the command line.

    my ($config_ref) = @_;

    # sort the subvol names so they are displayed in alphabetical order.
    my @all_subvols = sort { $a cmp $b } @{$config_ref->{subvols}};

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
	print "No option \"$input\"! Try again!\n\n";
	ask_for_subvolume($config_ref);
    }
}

sub ask_for_query { # no test

    # Prompt user for query. Used for the --find option when the user
    # doesn't explicitly pass their query on the command line.

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

sub get_all_snapshots_of { # no test

    # Read filesystem to gather all the snapshots for a given
    # subvolume and return them sorted from newest to oldest.

    my ($config_ref, $subvol) = @_;

    # Find our target directory. It should look like '/.snapshots/yabsm/home'
    my $target_dir = target_dir($config_ref, $subvol);

    my @all_snaps; 
    for my $tf ('hourly', 'daily', 'midnight', 'monthly') {
	if (-d "$target_dir/$tf/") {
	    push @all_snaps, glob "$target_dir/$tf/*"; 
	}
    }
    
    my $snaps_sorted_ref = sort_snapshots(\@all_snaps);

    return wantarray ? @$snaps_sorted_ref : $snaps_sorted_ref;
}

sub all_subvols { # has test

    # Return an array of the yabsm names of every subvolume that the
    # user wants to snapshot. These are all the values for the
    # 'define_subvol' field the users /etc/yabsmrc.

    my ($config_ref) = @_;

    my $subvols_ref = $config_ref->{subvols};

    return wantarray ? @$subvols_ref : $subvols_ref;
}

                 ####################################
                 #      SNAPSTRING CONVERSIONS      #
                 ####################################

sub snapstring_to_nums { # has test

    # Take a snapshot name string and return an array containing in
    # order the year, month, day, hour, and minute. This works with
    # both a full path and just a snapshot name string.

    my ($snap) = @_;

    my @nums = $snap =~ /day=(\d{4})_(\d{2})_(\d{2}),time=(\d{2}):(\d{2})$/;

    return wantarray ? @nums : \@nums;
}

sub nums_to_snapstring { # has test

    # Take 5 integer arguments representing in order the year, month,
    # day, hour, and minute and then return a snapshot name string
    # that aligns with the format used in current_time_string() which
    # is the function used to create snapshot names in the first place.

    my ($yr, $mon, $day, $hr, $min) = map { sprintf '%02d', $_ } @_;

    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

sub snapstring_to_time_piece_obj { # has test

    # Turn a snapshot name string into a Time::Peice object. This is
    # useful because we can do time arithmetic like adding hours or
    # minutes on the object.

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

    # lexicographic order
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

    # Can only add/subtract by seconds with Time::Piece objects.

    my $seconds_per_unit;

    if    ($unit =~ /^(m|mins|minutes)$/) { $seconds_per_unit = 60    }
    elsif ($unit =~ /^(h|hrs|hours)$/   ) { $seconds_per_unit = 3600  }
    elsif ($unit =~ /^(d|days)$/        ) { $seconds_per_unit = 86400 }
    else  { croak "\"$unit\" is an invalid time unit\n" }

    my $current_time = current_time_string();

    my $time_piece_obj = snapstring_to_time_piece_obj($current_time);

    $time_piece_obj -= ($n * $seconds_per_unit);

    return time_piece_obj_to_snapstring($time_piece_obj);
}

                 ####################################
                 #          FIND ONE SNAPSHOT       #
                 ####################################

sub snap_closest_to { # has test

    # return the snapshot from $all_snaps_ref that is closest to
    # $target_snap. Note that we expect that $all_snaps_ref is a ref
    # to a sorted array of snapshots. It does not matter if these
    # snapshots are full paths or just snapstrings.

    my ($all_snaps_ref, $target_snap) = @_;

    foreach my $snap (@$all_snaps_ref) {
	
	my $cmp = compare_snapshots($snap, $target_snap);
	
	return $snap if $cmp == 0 || $cmp == 1;
    }
    
    warn "[!] WARNING: couldn't find a snapshot close to \"$target_snap\", instead returning the oldest snapshot\n";
    
    return @$all_snaps_ref[-1];
}

                 ####################################
                 #              QUERIES             #
                 ####################################

sub answer_query { # no test

    # This function answers $query to find the appropiate snapshot
    # of $subvol.

    my ($config_ref, $subvol, $query) = @_;

    # snapshots are sorted from newest to oldest
    my $all_snaps_ref = get_all_snapshots_of($config_ref, $subvol);

    my $snap_to_return;

    if (is_literal_time($query)) {

	my @nums = $query =~ m/^(\d{4})([- ])(\d{1,2})\2(\d{1,2})\2(\d{1,2})\2(\d{1,2})$/;

	# remove the delimiter '[- ]' in the above regexp.
	@nums = grep { $_ ne $2 } @nums;

	my $nums_as_snapstring = nums_to_snapstring(@nums);

	$snap_to_return = snap_closest_to($all_snaps_ref, $nums_as_snapstring);
    }

    elsif (is_relative_time($query)) {

	my (undef, $n, $units) = split /[- ]/, $query;

	my $n_units_ago = n_units_ago($n, $units);

	$snap_to_return = snap_closest_to($all_snaps_ref, $n_units_ago);
    }
    
    return $snap_to_return;
}

sub is_valid_query { # has test

    # Return 1 iff $query is either a literal time like
    # '2020-02-13-12-30' or it is a relative time like 'back-40-mins'.

    my ($query) = @_;

    if    (is_literal_time($query))  { return 1 }
    elsif (is_relative_time($query)) { return 1 }
    else  { return 0 }
}

sub is_literal_time { # has test

    # Return 1 iff $query is a literal time string like
    # '2020-5-13-12-30'.

    my ($query) = @_;

    return $query =~ /^\d{4}([- ])\d{1,2}\1\d{1,2}\1\d{1,2}\1\d{1,2}$/;
}

sub is_relative_time { # has test

    # Return 1 iff $query is a syntactically valid relative time.
    # Relative queries take the form of 'mode-amount-unit'.
    # At this time the only valid mode field is 'back'.
    # The amount field must be a positive integer.
    # The unit field must be a time unit like minutes, hours, or days.

    my ($query) = @_;

    my ($mode, $amount, $unit) = split /[- ]/, $query, 3;

    return 0 if any { not defined } ($mode, $amount, $unit);

    my $mode_correct = $mode =~ /^(b|back)$/;

    my $amount_correct = $amount =~ /^[0-9]+$/;
    
    my $unit_correct = any { $_ eq $unit } qw/m mins minutes h hrs hours d days/;
    
    return $mode_correct && $amount_correct && $unit_correct;
}

sub is_subvol { # has test

    # Return 1 iff $subvol is the name of a defined yabsm subvolume.
    
    my ($config_ref, $subvol) = @_;
    
    return any { $_ eq $subvol } @{$config_ref->{subvols}};
}

sub is_timeframe { # has test

    # Return 1 iff $timeframe is a valid timeframe

    my ($tframe) = @_;

    return any { $_ eq $tframe } qw/hourly daily midnight monthly/;
}

                 ####################################
                 #             CRONJOBS             #
                 ####################################

sub update_etc_crontab { # no test
    
    # Write cronjobs to '/etc/crontab'

    my ($config_ref) = @_;

    open (my $etc_crontab, '<', '/etc/crontab')
      or die "[!] Error: failed to open /etc/crontab\n";

    open (my $tmp, '>', '/tmp/yabsm-update-tmp')
      or die "[!] Error: failed to open tmp file at /tmp/yabsm-update-tmp\n";

    # Copy all lines from /etc/crontab into the tmp file, excluding the existing
    # yabsm cronjobs.
    while (<$etc_crontab>) {

	next if /yabsm --take-snap/;

	print $tmp $_;
    }

    # If there is text on the last line of the file then we must append a
    # newline or else that text will prepend our first cronjob.
    print $tmp "\n"; 

    # Now append the cronjob strings to $tmp file.
    my @cron_strings = generate_cron_strings($config_ref);

    say $tmp $_ for @cron_strings;

    close $etc_crontab;
    close $tmp;

    move '/tmp/yabsm-update-tmp', '/etc/crontab';

    return;
} 

sub generate_cron_strings { # no test

    # Generate all the cron strings by reading the users config settings
    
    my ($config_ref) = @_;

    my @cron_strings; # This will be returned

    # Remember that these strings are 'name,path' for example 'home,/home'
    foreach my $subv_name (@{$config_ref->{subvols}}) {

	# Every yabsm subvolume is required to have a value for these fields
	my $hourly_want = $config_ref->{"${subv_name}_hourly_want"};
	my $hourly_take = $config_ref->{"${subv_name}_hourly_take"};

	my $daily_want = $config_ref->{"${subv_name}_daily_want"};
	my $daily_take = $config_ref->{"${subv_name}_daily_take"};

	my $midnight_want = $config_ref->{"${subv_name}_midnight_want"};

	my $monthly_want = $config_ref->{"${subv_name}_monthly_want"};
        
        my $hourly_cron   = ( '*/' . int(60 / $hourly_take) # Max is every minute
			    . ' * * * * root'
			    . ' /usr/local/bin/yabsm'
			    . " --take-snap $subv_name hourly"
			    ) if $hourly_want eq 'yes';
        
        my $daily_cron    = ( '0 */' . int(24 / $daily_take) # Max is every hour
                            . ' * * * root'
			    . ' /usr/local/bin/yabsm'
			    . " --take-snap $subv_name daily"
			    ) if $daily_want eq 'yes';
        
	# Every night just before midnight. Note that the date is the day of.
        my $midnight_cron = ( '59 23 * * * root' 
                            . ' /usr/local/bin/yabsm'
			    . " --take-snap $subv_name midnight"
			    ) if $midnight_want eq 'yes';
        
        my $monthly_cron  = ( '0 0 1 * * root' # First of every month
			    . ' /usr/local/bin/yabsm'
			    . " --take-snap $subv_name monthly"
			    ) if $monthly_want eq 'yes';

	# Any of the cron strings may be undefined.
        push @cron_strings, grep { defined } ($hourly_cron,
					      $daily_cron,
					      $midnight_cron,
					      $monthly_cron);
    }

    return wantarray ? @cron_strings : \@cron_strings;
}

                 ####################################
                 #           SNAPSHOT IO            #
                 ####################################

sub take_new_snapshot { # no test

    # take a single read-only snapshot.

    my ($config_ref, $subvol, $timeframe) = @_;

    my $mountpoint = $config_ref->{"${subvol}_path"};

    my $target_dir = target_dir($config_ref, $subvol);

    my $snapshot_name = current_time_string();

    system( 'btrfs subvolume snapshot -r '
	  . $mountpoint
	  . " $target_dir/$timeframe/$snapshot_name"
	  ); 

    return;
}

sub current_time_string { # no test
    
    # This function is used be used to create a snapstring name
    # of the current time.
    
    my ($min, $hr, $day, $mon, $yr) =
      map { sprintf '%02d', $_ } (localtime)[1..5]; 
    
    $mon++;      # month count starts at zero. 
    $yr += 1900; # year represents years since 1900. 
    
    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

sub delete_appropriate_snapshots { # no test
    
    # Delete snapshot(s) based off $subvol_$timeframe_keep setting
    # defined in the users config. This function should be called
    # after take_new_snapshot().

    my ($config_ref, $subvol, $timeframe) = @_;

    # these snaps are sorted from newest to oldest
    my $existing_snaps_ref = get_all_snapshots_of($config_ref, $subvol);

    my $target_dir = target_dir($config_ref, $subvol);

    my $num_snaps = scalar @$existing_snaps_ref;

    my $num_to_keep = $config_ref->{"${subvol}_${timeframe}_keep"};

    # The most common case is there is 1 more snapshot than what should be
    # kept because we just took a snapshot.
    if ($num_snaps == $num_to_keep + 1) { 

	# pop takes from the end of the array
	my $oldest_snap = pop @$existing_snaps_ref;

	system("btrfs subvolume delete $target_dir/$timeframe/$oldest_snap");

	return;
    }

    # We haven't reached the snapshot quota yet so we don't delete anything.
    elsif ($num_snaps <= $num_to_keep) { return } 

    # User changed their settings to keep less snapshots than they
    # were keeping prior. 
    else { 
	
	while ($num_snaps > $num_to_keep) {

	    # note that pop mutates existing_snaps
            my $oldest_snap = pop @$existing_snaps_ref;
            
	    system("btrfs subvolume delete $target_dir/$timeframe/$oldest_snap");

	    $num_snaps--;
	} 
    }

    return;
}

1;