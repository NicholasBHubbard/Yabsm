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

sub yabsmrc_to_hash { # No test. Is not pure.
    
    # Take an absolute path to a config file and parse the file into a
    # config hash. This function will make invalid yabsm
    # configurations, so after using this function it is neccesary to
    # call 'die_if_invalid_config()' on the config this function
    # returns.

    my ($yabsmrc_abs_path) = @_;

    if (not defined $yabsmrc_abs_path) {
	$yabsmrc_abs_path = '/etc/yabsmrc';
    }

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

sub die_if_invalid_config { # No test. Is not pure.
    
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

sub initialize_yabsm_directories { # No test. Is not pure.

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

sub target_dir { # Has test. Is pure.

    # return path to the directory of a given subvolume. Likely
    # returns a string like '/.snapshots/yabsm/root'

    my ($config_ref, $subvol) = @_;

    my $snapshot_root_dir = $config_ref->{snapshot_directory};
    
    return "$snapshot_root_dir/yabsm/$subvol";
}

                 ####################################
                 #          USER INTERACTION        #
                 ####################################

sub ask_for_subvolume { # No test. Is not pure.

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

sub ask_for_query { # No test. Is not pure.

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

sub get_all_snapshots_of { # No test. Is not pure.

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

sub all_subvols { # Has test. Is pure.

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

sub snapstring_to_nums { # Has test. Is pure.

    # Take a snapshot name string and return an array containing in
    # order the year, month, day, hour, and minute. This works with
    # both a full path and just a snapshot name string.

    my ($snap) = @_;

    my @nums = $snap =~ /day=(\d{4})_(\d{2})_(\d{2}),time=(\d{2}):(\d{2})$/;

    return wantarray ? @nums : \@nums;
}

sub nums_to_snapstring { # Has test. Is pure.

    # Take 5 integer arguments representing in order the year, month,
    # day, hour, and minute and then return a snapshot name string
    # that aligns with the format used in current_time_string() which
    # is the function used to create snapshot names in the first place.

    my ($yr, $mon, $day, $hr, $min) = map { sprintf '%02d', $_ } @_;

    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

sub snapstring_to_time_piece_obj { # Has test. Is pure.

    # Turn a snapshot name string into a Time::Peice object. This is
    # useful because we can do time arithmetic like adding hours or
    # minutes on the object.

    my ($snap) = @_;

    my ($yr, $mon, $day, $hr, $min) = snapstring_to_nums($snap);

    return Time::Piece->strptime("$yr/$mon/$day/$hr/$min",'%Y/%m/%d/%H/%M');
}

sub time_piece_obj_to_snapstring { # Has test. Is pure.

    # Turn a Time::Piece object into a snapshot name string.

    my ($time_piece_obj) = @_;

    my $yr  = $time_piece_obj->year;
    my $mon = $time_piece_obj->mon;
    my $day = $time_piece_obj->mday;
    my $hr  = $time_piece_obj->hour;
    my $min = $time_piece_obj->min;

    return nums_to_snapstring($yr, $mon, $day, $hr, $min);
}

sub immediate_to_snapstring {

    # resolve an immediate to a snapstring

    my ($imm) = @_;

    if (is_literal_time($imm)) {
	return literal_time_to_snapstring($imm);
    }
    elsif (is_relative_time($imm)) {
	return relative_time_to_snapstring($imm);
    }
    else {
	croak "[!] Internal Error: \"$imm\" is not an immediate";
    }
}

sub literal_time_to_snapstring { # TODO no test

    my ($lit_time) = @_;

    # literal time forms
    my $yr_mon_day_hr_min = '^(\d{4})-(\d{1,2})-(\d{1,2})-(\d{1,2})-(\d{1,2})$';
    my $yr_mon_day        = '^(\d{4})-(\d{1,2})-(\d{1,2})$';
    my $mon_day           = '^(\d{1,2})-(\d{1,2})$';
    my $mon_day_hr        = '^(\d{1,2})-(\d{1,2})-(\d{1,2})$';
    my $mon_day_hr_min    = '^(\d{1,2})-(\d{1,2})-(\d{1,2})-(\d{1,2})$';

    if ($lit_time =~ /$yr_mon_day_hr_min/) {
	return nums_to_snapstring($1, $2, $3, $4, $5);
    }

    if ($lit_time =~ /$yr_mon_day/) {
	return nums_to_snapstring($1, $2, $3, 0, 0);
    }

    if ($lit_time =~ /$mon_day/) {
	my $t = localtime;
	return nums_to_snapstring($t->year, $1, $2, 0, 0);
    }

    if ($lit_time =~ /$mon_day_hr/) {
	my $t = localtime;
	return nums_to_snapstring($t->year, $1, $2, $3, 0);
    }

    if ($lit_time =~ /$mon_day_hr_min/) {
	my $t = localtime;
	return nums_to_snapstring($t->year, $1, $2, $3, $4);
    }

    croak "[!] Internal Error: $lit_time is not a valid literal time";
}

sub relative_time_to_snapstring { # TODO no test

    # resolve a relative time to a snapstring

    my ($rel_time) = @_;

    my (undef, $amount, $unit) = split '-', $rel_time, 3;

    my $n_units_ago_snapstring = n_units_ago($amount, $unit);

    return $n_units_ago_snapstring; 
}

sub snapstring_to_nums { # Has test. Is pure.

    # Take a snapshot name string and return an array containing in
    # order the year, month, day, hour, and minute. This works with
    # both a full path and just a snapshot name string.

    my ($snap) = @_;

    my @nums = $snap =~ /day=(\d{4})_(\d{2})_(\d{2}),time=(\d{2}):(\d{2})$/;

    return wantarray ? @nums : \@nums;
}

sub nums_to_snapstring { # Has test. Is pure.

    # Take 5 integer arguments representing in order the year, month,
    # day, hour, and minute and then return a snapshot name string
    # that aligns with the format used in current_time_string() which
    # is the function used to create snapshot names in the first place.

    my ($yr, $mon, $day, $hr, $min) = map { sprintf '%02d', $_ } @_;

    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

sub snapstring_to_time_piece_obj { # Has test. Is pure.

    # Turn a snapshot name string into a Time::Peice object. This is
    # useful because we can do time arithmetic like adding hours or
    # minutes on the object.

    my ($snap) = @_;

    my ($yr, $mon, $day, $hr, $min) = snapstring_to_nums($snap);

    return Time::Piece->strptime("$yr/$mon/$day/$hr/$min",'%Y/%m/%d/%H/%M');
}

sub time_piece_obj_to_snapstring { # Has test. Is pure.

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

sub sort_snapshots { # Has test. Is pure.

    # return a sorted version of the inputted array ref of
    # snapshots. Sorted from newest to oldest. Works with either full
    # paths or just snapstrings.

    my ($snaps_ref) = @_;

    my @sorted_snaps = sort { cmp_snaps($a, $b) } @$snaps_ref;

    return wantarray ? @sorted_snaps : \@sorted_snaps;
}

sub cmp_snaps { # Has test. Is pure.

    # Return -1 if $snap1 is newer than $snap2.
    # Return 1 if $snap1 is older than $snap2
    # Return 0 if $snap1 and $snap2 are the same. 
    # Works with either full paths or just snapstrings.

    my ($snap1, $snap2) = @_;

    my @snap1_nums = snapstring_to_nums($snap1);
    my @snap2_nums = snapstring_to_nums($snap2);

    # lexicographic order
    for (my $i = 0; $i < scalar @snap1_nums; $i++) {

	return -1 if $snap1_nums[$i] > $snap2_nums[$i];
	return 1  if $snap1_nums[$i] < $snap2_nums[$i];
    }

    # Must be the same
    return 0;
}

                 ####################################
                 #          TIME ARITHMETIC         #
                 ####################################

sub n_units_ago { # Has test. Is pure.

    # Subtract $n minutes, hours, or days from the current
    # time. Returns a snapstring.

    my ($n, $unit) = @_;

    # Can only add/subtract by seconds with Time::Piece objects.

    my $seconds_per_unit;

    if    ($unit =~ /^(m|mins|minutes)$/) { $seconds_per_unit = 60    }
    elsif ($unit =~ /^(h|hrs|hours)$/   ) { $seconds_per_unit = 3600  }
    elsif ($unit =~ /^(d|days)$/        ) { $seconds_per_unit = 86400 }
    else  { croak "\"$unit\" is not a valid time unit" }

    my $current_time = current_time_string();

    my $time_piece_obj = snapstring_to_time_piece_obj($current_time);

    $time_piece_obj -= ($n * $seconds_per_unit);

    return time_piece_obj_to_snapstring($time_piece_obj);
}

                 ####################################
                 #         SNAPSHOT FILTERING       #
                 ####################################

sub snap_closest_to { # Has test. Is pure.

    # return the snapshot from $all_snaps_ref that is closest to
    # $target_snap. $all_snaps_ref is sorted from newest to oldest.

    my ($all_snaps_ref, $target_snap) = @_;

    # this is returned
    my $snap;

    for (my $i = 0; $i <= $#{ $all_snaps_ref }; $i++) {
	
	my $this_snap = $all_snaps_ref->[$i];

	my $cmp = cmp_snaps($this_snap, $target_snap);
	
	if ($cmp == 0) {
	    $snap = $this_snap;
	    last;
	}

	if ($cmp == 1) {
	    if ($i == 0) {
		$snap = $this_snap;
	    }
	    else {
		my $prev_snap = $all_snaps_ref->[$i-1];
		$snap = snap_closer($target_snap, $prev_snap, $this_snap);
	    }
	    last;
	}
    }

    if (not defined $snap) {
	$snap = oldest_snap($all_snaps_ref);
    }
    
    return $snap;
}

sub snap_closer { # Has test. Is pure.

    # Return either $snap1 or $snap2, depending on which is closer to
    # $target_snap. If they are equidistant return $snap1.

    my ($target_snap, $snap1, $snap2) = @_;

    my $target_epoch = snapstring_to_time_piece_obj($target_snap)->epoch;
    my $snap1_epoch  = snapstring_to_time_piece_obj($snap1)->epoch;
    my $snap2_epoch  = snapstring_to_time_piece_obj($snap2)->epoch;

    my $v1 = abs($target_epoch - $snap1_epoch);
    my $v2 = abs($target_epoch - $snap2_epoch);

    if ($v1 <= $v2) { return $snap1 }
    else            { return $snap2 }
}

sub snaps_newer { # Has test. Is pure.

    my ($all_snaps_ref, $target_snap) = @_;

    my @snaps_newer = ();

    for (my $i = 0; $i <= $#{ $all_snaps_ref }; $i++) {

	my $this_snap = $all_snaps_ref->[$i];

	my $cmp = cmp_snaps($this_snap, $target_snap);  

	# if this snap is newer than the target
	if ($cmp == -1) {
	    push @snaps_newer, $this_snap;
	}
	else { last }
    }

    return wantarray ? @snaps_newer : \@snaps_newer;
}

sub snaps_older { # Has test. Is pure.

    my ($all_snaps_ref, $target_snap) = @_;

    my @snaps_older = ();
    
    my $last_idx = $#{ $all_snaps_ref };

    for (my $i = 0; $i <= $last_idx; $i++) {

	my $this_snap = $all_snaps_ref->[$i];

	my $cmp = cmp_snaps($this_snap, $target_snap);  

	# if this snap is older than the target
	if ($cmp == 1) {
	    @snaps_older = @{ $all_snaps_ref }[$i .. $last_idx];
	    last;
	}
    }

    return wantarray ? @snaps_older : \@snaps_older;
}

sub snaps_between { # Has test. Is pure.

    # Return all of the snapshots between (inclusive) $target_snap1
    # and $target_snap2. $all_snapshots_ref references an array of
    # snapshots sorted from newest to oldest.

    my ($all_snaps_ref, $target_snap1, $target_snap2) = @_;

    # figure out which target snap is newer/older.

    my $older;
    my $newer;

    if (-1 == cmp_snaps($target_snap1, $target_snap2)) {
	$newer = $target_snap1; 
	$older = $target_snap2;
    }
    else {
	$newer = $target_snap2; 
	$older = $target_snap1;
    }

    # find the snaps between (inclusive) $newer and $older

    my @snaps_between = ();

    my $last_idx = $#{ $all_snaps_ref };

    for (my $i = 0; $i <= $last_idx; $i++) {

	my $this_snap = $all_snaps_ref->[$i];

	my $cmp = cmp_snaps($this_snap, $newer);

	# if this snap is older or equal to the newer target
	if ($cmp == 1 || $cmp == 0) {

	    # between (inclusive)
	    push @snaps_between, $this_snap if $cmp == 0;
	    
	    for (my $j = $i+1; $j <= $last_idx; $j++) {

		my $this_snap = $all_snaps_ref->[$j];

		my $cmp = cmp_snaps($this_snap, $older);

		# if this snap is older than or equal to the older target
		if ($cmp == 1 || $cmp == 0) {

		    # between (inclusive)
		    push @snaps_between, $this_snap if $cmp == 0;

		    # Were done. The outer loop will also be broken.
		    last;
		}

		# else
		push @snaps_between, $this_snap;
	    }
	    
	    last;
	}
    }

    return wantarray ? @snaps_between : \@snaps_between;
}

sub newest_snap { # Has test. Is pure.

    # this works because the snapshots are always sorted newest to oldest

    my ($all_snaps_ref) = @_;

    return $all_snaps_ref->[0];
}

sub oldest_snap { # Has test. Is pure.

    # this works because the snapshots are always sorted newest to oldest

    my ($all_snaps_ref) = @_;

    return $all_snaps_ref->[-1];
}

                 ####################################
                 #              QUERIES             #
                 ####################################

sub answer_query { # TODO no test

    # This function answers $query to find the appropiate snapshot(s)
    # of $subvol. 

    my ($config_ref, $subvol, $query) = @_;

    # snapshots are sorted from newest to oldest
    my $all_snaps_ref = get_all_snapshots_of($config_ref, $subvol);

    my @snaps_to_return = ();

    if (is_literal_time($query)) {

	my $target = literal_time_to_snapstring($all_snaps_ref, $query);

	my $snap = snap_closest_to($all_snaps_ref, $target); 

	push @snaps_to_return, $snap;
    }

    elsif (is_relative_time($query)) {

	my $target = relative_time_to_snaptring($query);

	my $snap = snap_closest_to($all_snaps_ref, $target);

	push @snaps_to_return, $snap;
    }

    elsif (is_newer_query($query)) {

	my (undef, $immediate) = split /\s/, $query, 2;

	my $target = immediate_to_snapstring($immediate);

	@snaps_to_return = snaps_newer($all_snaps_ref, $target);
    }

    elsif (is_older_query($query)) {

	my (undef, $immediate) = split /\s/, $query, 2;

	my $target = immediate_to_snapstring($immediate);

	@snaps_to_return = snaps_older($all_snaps_ref, $target);
    }

    elsif (is_newest_query($query)) {

	my $snap = newest_snap($all_snaps_ref);

	push @snaps_to_return, $snap;
    }

    elsif (is_oldest_query($query)) {

	my $snap = oldest_snap($all_snaps_ref);

	push @snaps_to_return, $snap;
    }

    else {
	croak "[!] Internal Error: \"$query\" is not a valid query";
    }

    return wantarray ? @snaps_to_return : \@snaps_to_return;
}

sub is_valid_query { # Has test. Is pure.

    my ($query) = @_;

    if    (is_immediate($query))     { return 1 }
    elsif (is_newer_query($query))   { return 1 }
    elsif (is_older_query($query))   { return 1 }
    elsif (is_newest_query($query))  { return 1 }
    elsif (is_oldest_query($query))  { return 1 }
    elsif (is_between_query($query)) { return 1 }
    else  { return 0 }
}

sub is_immediate { # Has test. Is pure.

    # An immediate is either a literal time or a relative time.

    my ($imm) = @_;
    
    return is_literal_time($imm) || is_relative_time($imm);
}

sub is_literal_time { # Has test. Is pure.

    # Literal times can come in one of 5 different forms. 

    my ($lit_time) = @_;

    # yr-mon-day-hr-min
    my $re1 = '^\d{4}-\d{1,2}-\d{1,2}-\d{1,2}-\d{1,2}$';
    # yr-mon-day
    my $re2 = '^\d{4}-\d{1,2}-\d{1,2}$';
    # mon-day
    my $re3 = '^\d{1,2}-\d{1,2}$';
    # mon-day-hr
    my $re4 = '^\d{1,2}-\d{1,2}-\d{1,2}$';
    # mon-day-hr-min
    my $re5 = '^\d{1,2}-\d{1,2}-\d{1,2}-\d{1,2}$';

    return any { $lit_time =~ /$_/ } ($re1, $re2, $re3, $re4, $re5);
}

sub is_relative_time { # Has test. Is pure.

    # Return 1 iff $query is a syntactically valid relative time.
    # Relative queries take the form of 'back-amount-unit'.
    # 'back' can be abbreviated to b.
    # The amount field must be a whole number.
    # The unit field must be a time unit like minutes, hours, or days.

    my ($query) = @_;

    my ($back, $amount, $unit) = split '-', $query, 3;

    return 0 if any { not defined } ($back, $amount, $unit);

    my $back_correct = $back =~ /^b(ack)?$/;

    my $amount_correct = $amount =~ /^\d+$/;
    
    my $unit_correct = any { $_ eq $unit } qw/minutes mins m hours hrs h days d/;
    
    return $back_correct && $amount_correct && $unit_correct;
}

sub is_newer_query { # Has test. Is pure.

    # Return 1 iff $query is a syntactically valid 'newer' query.

    my ($query) = @_;

    my ($keyword, $imm) = split /\s/, $query, 2;

    return 0 if any { not defined } ($keyword, $imm);

    my $keyword_correct = $keyword =~ /^newer$/;

    my $imm_correct = is_immediate($imm);

    return $keyword_correct && $imm_correct;
}

sub is_older_query { # Has test. Is pure.

    # Return 1 iff $query is a syntactically valid 'older' query.

    my ($query) = @_;

    my ($keyword, $imm) = split /\s/, $query, 2;

    return 0 if any { not defined } ($keyword, $imm);

    my $keyword_correct = $keyword =~ /^older$/;

    my $imm_correct = is_immediate($imm);

    return $keyword_correct && $imm_correct;
}

sub is_newest_query { # Has test. Is pure.
    
    # Return 1 iff $query is a syntactically valid 'newest' query.

    my ($query) = @_;

    return $query =~ /^newest$/;
}

sub is_oldest_query { # Has test. Is pure.
    
    # Return 1 iff $query is a syntactically valid 'oldest' query.

    my ($query) = @_;

    return $query =~ /^oldest$/;
}

sub is_between_query { # TODO no test

    # Return 1 iff $query is a syntactically valid 'after' query.

    my ($query) = @_;

    my ($keyword, $imm1, $imm2) = split ' ', $query, 3;

    return 0 if any { not defined } ($keyword, $imm1, $imm2);

    my $keyword_correct = $keyword =~ /^bet(ween)?$/;

    my $imm1_correct = is_immediate($imm1);

    my $imm2_correct = is_immediate($imm2);

    return $keyword_correct && $imm1_correct && $imm2_correct;
}

sub is_subvol { # Has test. Is pure.

    # Return 1 iff $subvol is the name of a defined yabsm subvolume.
    
    my ($config_ref, $subvol) = @_;
    
    return any { $_ eq $subvol } @{$config_ref->{subvols}};
}

sub is_timeframe { # Has test. Is pure.

    # Return 1 iff $timeframe is a valid timeframe

    my ($tframe) = @_;

    return any { $_ eq $tframe } qw/hourly daily midnight monthly/;
}

                 ####################################
                 #             CRONJOBS             #
                 ####################################

sub update_etc_crontab { # No test. Is not pure.
    
    # Write cronjobs to '/etc/crontab'

    my ($config_ref) = @_;

    open (my $etc_crontab_fh, '<', '/etc/crontab')
      or die "[!] Error: failed to open /etc/crontab\n";

    open (my $tmp_fh, '>', '/tmp/yabsm-update-tmp')
      or die "[!] Error: failed to open tmp file at /tmp/yabsm-update-tmp\n";

    # Copy all lines from /etc/crontab into the tmp file, excluding the existing
    # yabsm cronjobs.
    while (<$etc_crontab_fh>) {

	next if /yabsm --take-snap/;

	print $tmp_fh $_;
    }

    # If there is text on the last line of the file then we must append a
    # newline or else that text will prepend our first cronjob.
    print $tmp_fh "\n"; 

    # Now append the cronjob strings to $tmp file.
    my @cron_strings = generate_cron_strings($config_ref);

    say $tmp_fh $_ for @cron_strings;

    close $etc_crontab_fh;
    close $tmp_fh;

    move '/tmp/yabsm-update-tmp', '/etc/crontab';

    return;
} 

sub generate_cron_strings { # no test. Is pure.

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

sub take_new_snapshot { # No test. Is not pure.

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

sub current_time_string { # No test. Is not pure.
    
    # This function is used be used to create a snapstring name
    # of the current time.
    
    my ($min, $hr, $day, $mon, $yr) =
      map { sprintf '%02d', $_ } (localtime)[1..5]; 
    
    $mon++;      # month count starts at zero. 
    $yr += 1900; # year represents years since 1900. 
    
    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

sub delete_appropriate_snapshots { # No test. Is not pure.
    
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
