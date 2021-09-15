#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  Core library of Yabsm.
#
#  See Yabsm.t for the testing of this library.

package Yabsm::Base;

use strict;
use warnings;
use 5.010;

use File::Copy 'move';
use Time::Piece;
use List::Util 'any';
use Net::OpenSSH;

sub initialize_directories { # No test. Is not pure.

    # This subroutine is called everytime the yabsm script is run
    # (unless using --help or --check-config flag). This subroutine
    # allows us to be assured that all needed directories have been
    # created.

    my ($config_ref) = @_;

    my $yabsm_root_dir = $config_ref->{misc}{snapshot_dir} . '/yabsm';

    if (not -d $yabsm_root_dir) {
	mkdir $yabsm_root_dir;
    }

    # .tmp dir holds tmp snaps for backups
    if (not -d $yabsm_root_dir . '/.tmp') {
	mkdir $yabsm_root_dir . '/.tmp';
    }

    foreach my $subvol (all_subvols($config_ref)) {

	my $subvol_dir = "$yabsm_root_dir/$subvol";

	if (not -d $subvol_dir) {
	    mkdir $subvol_dir;
	}

	# .cache can hold a snapshot to be the parent of an incremental backup
	if (not -d "$subvol_dir/.cache") {
	    mkdir "$subvol_dir/.cache";
	}

	my $_5minute_want = $config_ref->{subvols}{$subvol}{_5minute_want};
	my $hourly_want   = $config_ref->{subvols}{$subvol}{hourly_want};
	my $midnight_want = $config_ref->{subvols}{$subvol}{midnight_want};
	my $monthly_want  = $config_ref->{subvols}{$subvol}{monthly_want};

	
	if ($_5minute_want eq 'yes' && not -d "$subvol_dir/5minute") {
	    mkdir "$subvol_dir/5minute";
	}

	if ($hourly_want eq 'yes' && not -d "$subvol_dir/hourly") {
	    mkdir "$subvol_dir/hourly";
	}

	if ($midnight_want eq 'yes' && not -d "$subvol_dir/midnight") {
	    mkdir "$subvol_dir/midnight";
	}

	if ($monthly_want eq 'yes' && not -d "$subvol_dir/monthly") {
	    mkdir "$subvol_dir/monthly";
	}
    }
    
    return;
}

                 ####################################
                 #          USER INTERACTION        #
                 ####################################

sub ask_user_for_subvolume { # No test. Is not pure.

    # Prompt user to select one of their defined subvols. Used for the
    # --find option when the user doesn't explicitly pass the
    # subvol on the command line.

    my ($config_ref) = @_;

    my @all_subvols = all_subvols($config_ref);

    # Initialize the integer to subvol-name hash.
    my %int_subvol_hash;
    for (my $i = 0; $i <= $#all_subvols; $i++) {
	$int_subvol_hash{ $i + 1 } = $all_subvols[$i];
    }

    my $subvol;

    while (not defined $subvol) {

	# print prompt to stdout.
	say 'select subvolume:';
	for (my $i = 1; $i <= keys %int_subvol_hash; $i++) {
	
	    my $int = $i;
	    my $subvol = $int_subvol_hash{ $int };
	    
	    # After every 4 subvolumes print a newline. This prevents
	    # a user with say 20 subvolumes from having them all
	    # printed as a giant string on one line.
	    if ($i % 4 == 0) {
		print "$int -> $subvol\n";
	    }
	    else {
		print "$int -> $subvol" . ' 'x4;
	    }
	}
	print "\n>>> ";
	
	# process input
	my $input = <STDIN>;
	$input =~ s/\s//g; 
	
	exit 0 if $input =~ /^q(uit)?$/;
	
	if (exists $int_subvol_hash{ $input }) { # success
	    $subvol = $int_subvol_hash{ $input };
	}
	
	else {
	    print "No option '$input'! Try again!\n\n";
	}
    }

    return $subvol;
}

sub ask_user_for_query { # No test. Is not pure.

    # Prompt user for query. Used for the --find option when the user
    # doesn't explicitly pass their query on the command line.

    my $query;

    while (not defined $query) {

	print "enter query:\n>>> ";
	
	my $input = <STDIN>;
	$input =~ s/^\s+|\s+$//g; # remove whitespace from both ends
	
	exit 0 if $input =~ /^q(uit)?$/;
	
	if (is_valid_query($input)) { # success
	    $query = $input;
	}  
	
	else {
	    print "'$input' is not a valid query! Try again!\n\n";
	}
    }

    return $query;
}

                 ####################################
                 #           CONFIG GATHERING       #
                 ####################################

sub all_snapshots_of { # No test. Is not pure. TODO DOCUMENT

    # Read filesystem to gather all the snapshots for a given
    # subvolume and return them sorted from newest to oldest. 

    my ($config_ref, $subvol, @timeframes) = @_;

    # default to all timeframes
    if (not @timeframes) {
	@timeframes = qw(5minute hourly midnight monthly);
    }

    my @all_snaps; 

    foreach my $tf (@timeframes) {

	my $snap_dir = local_snapshot_dir($config_ref, $subvol, $tf);

	if (-d $snap_dir) {
	    push @all_snaps, glob "$snap_dir/*"; 
	}
    }
    
    my $snaps_sorted_ref = sort_snapshots(\@all_snaps);

    return wantarray ? @$snaps_sorted_ref : $snaps_sorted_ref;
}

sub local_snapshot_dir { # Has test. Is pure.

    # Return the local directory path for yabsm snapshots. The $subvol
    # and $timeframe arguments are optional.

    my ($config_ref, $subvol, $timeframe) = @_;

    my $snap_dir = $config_ref->{misc}{snapshot_dir} . '/yabsm';

    $snap_dir .= "/$subvol" if defined $subvol;

    $snap_dir .= "/$timeframe" if defined $timeframe;

    return $snap_dir;
}

                 ####################################
                 #            SNAPSTRINGS           #
                 ####################################

sub current_time_snapstring { # No test. Is not pure.
    
    # This function is used be used to create a snapstring name
    # of the current time.
    
    my ($min, $hr, $day, $mon, $yr) =
      map { sprintf '%02d', $_ } (localtime)[1..5]; 
    
    $mon++;      # month count starts at zero. 
    $yr += 1900; # year represents years since 1900. 
    
    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

sub immediate_to_snapstring { # TODO no test.

    # Resolve an immediate to a snapstring. An immediate is either a
    # literal time, relative time, newest time, or oldest time.

    my ($all_snaps_ref, $imm) = @_;

    if (is_literal_time($imm)) {
	return literal_time_to_snapstring($imm);
    }
    if (is_relative_time($imm)) {
	return relative_time_to_snapstring($imm);
    }
    if (is_newest_time($imm)) {
	return newest_snap($all_snaps_ref);
    }
    if (is_oldest_time($imm)) {
	return oldest_snap($all_snaps_ref);
    }

    # should never happen because input has already been cleansed. 
    die "[!] Internal Error: '$imm' is not an immediate";
}

sub literal_time_to_snapstring { # Has test. Is pure.

    # resolve a literal time to a snapstring

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

    die "[!] Internal Error: '$lit_time' is not a valid literal time";
}

sub relative_time_to_snapstring { # Has test. Is not pure.

    # resolve a relative time to a snapstring. Relative times have the
    # form 'back-amount-unit'.

    my ($rel_time) = @_;

    my (undef, $amount, $unit) = split '-', $rel_time, 3;

    my $n_units_ago_snapstring = n_units_ago_snapstring($amount, $unit);

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
    # that aligns with the format used in current_time_snapstring() which
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
    for (my $i = 0; $i <= $#snap1_nums; $i++) {

	return -1 if $snap1_nums[$i] > $snap2_nums[$i];
	return 1  if $snap1_nums[$i] < $snap2_nums[$i];
    }

    # Must be the same
    return 0;
}

                 ####################################
                 #        TODO NAME THIS SECTION #
                 ####################################

sub n_units_ago_snapstring { # Has test. Is not pure.

    # Subtract $n minutes, hours, or days from the current
    # time. Returns a snapstring.

    my ($n, $unit) = @_;

    # Can only add/subtract by seconds with Time::Piece objects.

    my $seconds_per_unit;

    if    ($unit =~ /^(m|mins|minutes)$/) { $seconds_per_unit = 60    }
    elsif ($unit =~ /^(h|hrs|hours)$/   ) { $seconds_per_unit = 3600  }
    elsif ($unit =~ /^(d|days)$/        ) { $seconds_per_unit = 86400 }
    else  { die "\"$unit\" is not a valid time unit" }

    my $current_time = current_time_snapstring();

    my $time_piece_obj = snapstring_to_time_piece_obj($current_time);

    $time_piece_obj -= ($n * $seconds_per_unit);

    return time_piece_obj_to_snapstring($time_piece_obj);
}

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

    # Return all the snapshots that are newer than $target_snap.
    # Remember that $all_snaps_ref is sorted newest to oldest.

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

    # Return all the snapshots that are older than $target_snap.
    # Remember that $all_snaps_ref is sorted newest to oldest.

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
    # and $target_snap2. Remember that $all_snaps_ref is sorted
    # newest to oldest.

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

    # Find the snaps between (inclusive) $newer and $older. Remember
    # that $all_snaps_ref is sorted newest to oldest.

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

sub newest_snap { # Has test. Is pure. # TODO WORKS WITH CONFIG. DOCUMENT!

    # this works because the snapshots are always sorted newest to oldest

    my ($ref, $subvol) = @_;

    my $newest_snap;

    if (ref($ref) eq 'ARRAY') {
	$newest_snap = $ref->[0]
    }

    else {
	my $all_snaps_ref = all_snapshots_of($ref, $subvol);
	$newest_snap = $all_snaps_ref->[0];
    }

    return $newest_snap;
}

sub oldest_snap { # Has test. Is pure.

    # this works because the snapshots are always sorted newest to oldest

    my ($ref, $subvol) = @_;

    my $oldest_snap;

    if (ref($ref) eq 'ARRAY') {
	$oldest_snap = $ref->[-1];
    }

    else {
	my $all_snaps_ref = all_snapshots_of($ref, $subvol);
	$oldest_snap = $ref->[-1];
    }

    return $oldest_snap;
}

sub answer_query { # TODO no test

    # This function answers $query to find the appropiate snapshot(s)
    # of $subvol. 

    my ($config_ref, $subvol, $query) = @_;

    my $all_snaps_ref = all_snapshots_of($config_ref, $subvol);

    my @snaps_to_return;

    if (is_immediate($query)) {

	my $target = immediate_to_snapstring($all_snaps_ref, $query); 

	my $snap = snap_closest_to($all_snaps_ref, $target);

	push @snaps_to_return, $snap;
    }

    elsif (is_newer_query($query)) {

	my (undef, $immediate) = split /\s/, $query, 2;

	my $target = immediate_to_snapstring($all_snaps_ref, $immediate);

	@snaps_to_return = snaps_newer($all_snaps_ref, $target);
    }

    elsif (is_older_query($query)) {

	my (undef, $immediate) = split /\s/, $query, 2;

	my $target = immediate_to_snapstring($all_snaps_ref, $immediate);

	@snaps_to_return = snaps_older($all_snaps_ref, $target);
    }

    elsif (is_between_query($query)) {

	my (undef, $imm1, $imm2) = split /\s/, $query, 3;

	my $target1 = immediate_to_snapstring($all_snaps_ref, $imm1);

	my $target2 = immediate_to_snapstring($all_snaps_ref, $imm2);

	@snaps_to_return = snaps_between($all_snaps_ref, $target1, $target2);
    }

    else {
	die "[!] Internal Error: '$query' is not a valid query";
    }

    return wantarray ? @snaps_to_return : \@snaps_to_return;
}

                 ####################################
                 #          QUERY DIAGNOSIS         #
                 ####################################

sub is_valid_query { # Has test. Is pure.

    my ($query) = @_;

    if (is_immediate($query))     { return 1 }
    if (is_newer_query($query))   { return 1 }
    if (is_older_query($query))   { return 1 }
    if (is_between_query($query)) { return 1 }

    return 0;
}

sub is_immediate { # Has test. Is pure.

    # An immediate is either a literal time or a relative time.

    my ($imm) = @_;
    
    return is_newest_time($imm)
        || is_oldest_time($imm)
        || is_literal_time($imm)
        || is_relative_time($imm);
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

sub is_newest_time { # Has test. Is pure.
    
    # Return 1 iff $query equals 'newest'.

    my ($query) = @_;

    return $query eq 'newest';
}

sub is_oldest_time { # Has test. Is pure.
    
    # Return 1 iff $query equals 'oldest'.

    my ($query) = @_;

    return $query eq 'oldest';
}

sub is_between_query { # TODO no test

    # Return 1 iff $query is a syntactically valid 'after' query.

    my ($query) = @_;

    my ($keyword, $imm1, $imm2) = split /\s/, $query, 3;

    return 0 if any { not defined } ($keyword, $imm1, $imm2);

    my $keyword_correct = $keyword =~ /^bet(ween)?$/;

    my $imm1_correct = is_immediate($imm1);

    my $imm2_correct = is_immediate($imm2);

    return $keyword_correct && $imm1_correct && $imm2_correct;
}

                 ####################################
                 #         CONFIG QUESTIONS         #
                 ####################################

sub all_subvols { # Has test. Is pure.

    # Return an array of the names of every user defined subvolume.

    my ($config_ref) = @_;

    my @subvols = sort keys %{$config_ref->{subvols}};

    return wantarray ? @subvols : \@subvols;
}

sub all_backups { # TODO no test.

    # Return an array of the names of every user defined backup

    my ($config_ref) = @_;

    my @backups = sort keys %{$config_ref->{backups}};

    return wantarray ? @backups : \@backups;
}

sub all_timeframes { # TODO no test

    # an array of all valid timeframes

    my @tframes = qw(5minute hourly midnight monthly);

    return wantarray ? @tframes : \@tframes;
}

sub is_subvol { # Has test. Is pure.

    # Return 1 iff $subvol is the name of a defined yabsm subvolume.
    
    my ($config_ref, $subvol) = @_;
    
    return any { $_ eq $subvol } all_subvols($config_ref);
}

sub is_backup { # TODO no test

    my ($config_ref, $backup) = @_;
    
    return any { $_ eq $backup } all_backups($config_ref);
}

sub is_timeframe { # Has test. Is pure.

    # Return 1 iff $tframe is a valid timeframe

    my ($tframe) = @_;

    return any { $_ eq $tframe } all_timeframes();
}

                 ####################################
                 #             CRONJOBS             #
                 ####################################

sub update_etc_crontab { # No test. Is not pure.
    
    # Write cronjobs to '/etc/crontab'

    my ($config_ref) = @_;

    open (my $etc_crontab_fh, '<', '/etc/crontab')
      or die "[!] Error: failed to open file '/etc/crontab'\n";

    open (my $tmp_fh, '>', '/tmp/yabsm-update-tmp')
      or die "[!] Error: failed to open tmp file '/tmp/yabsm-update-tmp'\n";

    # Copy all lines from /etc/crontab into the tmp file, excluding
    # the existing yabsm cronjobs.
    while (<$etc_crontab_fh>) {

	s/\s+$//; # strip trailing whitespace

	next if /yabsm --take-snap/;

	say $tmp_fh $_;
    }

    # If there is text on the last line of the file then we must append a
    # newline or else that text will prepend our first cronjob.
    # print $tmp_fh "\n"; 

    # Now append the cronjob strings to $tmp file.
    my @cron_strings = generate_cron_strings($config_ref);

    say $tmp_fh $_ for @cron_strings;

    close $etc_crontab_fh;
    close $tmp_fh;

    move '/tmp/yabsm-update-tmp', '/etc/crontab';

    return;
} 

sub generate_cron_strings { # No test. Is pure.

    # Use the users config to generate all the cron strings for taking
    # snapshots and performing backups.
    
    my ($config_ref) = @_;

    my @cron_strings;

    foreach my $subvol (all_subvols($config_ref)) {

	my $_5minute_want = $config_ref->{subvols}{$subvol}{_5minute_want};
	my $hourly_want   = $config_ref->{subvols}{$subvol}{hourly_want};
	my $midnight_want = $config_ref->{subvols}{$subvol}{midnight_want};
	my $monthly_want  = $config_ref->{subvols}{$subvol}{monthly_want};
        
        my $_5minute_cron = ( '*/5 * * * * root' # every 5 minutes
			    . " yabsm --take-snap $subvol 5minute"
			    ) if $_5minute_want eq 'yes';
        
        my $hourly_cron   = ( '0 */1 * * * root' # beginning of every hour
			    . " yabsm --take-snap $subvol hourly"
			    ) if $hourly_want eq 'yes';
        
        my $midnight_cron = ( '59 23 * * * root' # 11:59 every night
                            . " yabsm --take-snap $subvol midnight"
			    ) if $midnight_want eq 'yes';
        
        my $monthly_cron  = ( '0 0 1 * * root' # First day of every month
			    . " yabsm --take-snap $subvol monthly"
			    ) if $monthly_want eq 'yes';

        push @cron_strings, grep { defined } ($_5minute_cron, $hourly_cron, $midnight_cron, $monthly_cron);
    }

    return wantarray ? @cron_strings : \@cron_strings;
}

                 ####################################
                 #              BACKUPS             #
                 ####################################

sub do_incremental_backup { # TODO DOCUMENT

    my ($config_ref, $backup) = @_;
    
    my $is_remote = $config_ref->{backups}{$backup}{remote} eq 'yes';

    if ($is_remote) {
	do_backup_ssh($config_ref, $backup);
    }

    else {
	do_backup_local($config_ref, $backup);
    }
}

sub do_backup_bootstrap {# TODO DOCUMENT

    my ($config_ref, $backup) = @_;

    my $is_remote = $config_ref->{backups}{$backup}{remote} eq 'yes';

    if ($is_remote) {
	bootstrap_backup_ssh($config_ref, $backup);
    }

    else {
	bootstrap_backup_local($config_ref, $backup);
    }
}

sub bootstrap_backup_ssh { # TODO DOCUMENT

    my ($config_ref, $backup) = @_;

    my $subvol = $config_ref->{backups}{$backup}{subvol};

    my $cache_dir = local_snapshot_dir($config_ref, $subvol, '.cache');

    # delete old cache snap. In a loop in case there are multiple.
    for my $old_cache_snap (glob "$cache_dir/*") {
	system("btrfs subvol delete $old_cache_snap");
    }

    my $mountpoint = $config_ref->{subvols}{$subvol}{mountpoint};
    
    my $cache_snap = $cache_dir . '/' . current_time_snapstring();
    
    system("btrfs subvol snapshot -r $mountpoint $cache_snap");

    my $remote_backup_dir = $config_ref->{backups}{$backup}{backup_dir};

    my $ssh = Net::OpenSSH->new($config_ref->{backups}{$backup}{host}
			       , batch_mode => 1
			       );

    # send an incremental backup over ssh
    $ssh->system({stdin_file => ['-|', "btrfs send $cache_snap"]}
		, "sudo -n btrfs receive $remote_backup_dir"
	        );

}

sub do_backup_ssh { # No test. Is not pure. # TODO document

    # Perform a single incremental backup over ssh. Assume that
    # bootstrapping has already happened.
    
    my ($config_ref, $backup) = @_;

    # the subvol that is being backed up
    my $subvol = $config_ref->{backups}{$backup}{subvol};

    my $ssh_host = $config_ref->{backups}{$backup}{host};

    my $remote_backup_dir =
      $config_ref->{backups}{$backup}{backup_dir};

    my $ssh = Net::OpenSSH->new($ssh_host, batch_mode => 1);

    my $cached_snap =
      (glob local_snapshot_dir($config_ref, $subvol, '.cache') . '/*')[0];

    if (not defined $cached_snap) {
	die "[!] Internal Error: no cached snapshot for subvol '$subvol'";
    }

    my $tmp_snap =
      local_snapshot_dir($config_ref) . '/.tmp/' . current_time_snapstring();

    my $mountpoint = $config_ref->{subvols}{$subvol}{mountpoint};
	
    system("btrfs subvol snapshot -r $mountpoint $tmp_snap");
    
    # send an incremental backup over ssh
    $ssh->system({stdin_file => ['-|', "btrfs send -p $cached_snap $tmp_snap"]}
		, "sudo -n btrfs receive $remote_backup_dir"
		);

    system("btrfs subvol delete $tmp_snap");
	
    delete_old_backups_ssh($ssh, $config_ref, $backup);

    return;
}

sub delete_old_backups_ssh { # TODO DOCUMENT

    # Delete old backup snapshot(s) based off $backup's
    # $keep setting defined in the users config. This
    # function should be called after do_backup_ssh;

    my ($ssh, $config_ref, $backup) = @_;

    my $subvol = $config_ref->{backups}{$backup}{subvol};

    my ($ssh_host, $backup_path) =
      split /:/, $config_ref->{backups}{$backup}{path}, 2;

    $backup_path .= "/yabsm/$subvol";

    my @existing_backups = sort_snapshots($ssh->capture("ls $backup_path"));

    my $num_backups = scalar @existing_backups;

    my $num_to_keep = $config_ref->{backups}{$backup}{keep};

    # The most common case is there is 1 more backup than should be
    # kept because we just performed a backup.
    if ($num_backups == $num_to_keep + 1) {

	# pop takes from the end of the array. This is the oldest backup
	# because they are sorted newest to oldest.
	my $oldest_backup = $backup_path . pop @existing_backups;

	$ssh->system("sudo -n btrfs subvol delete $oldest_backup");

	return;
    }

    # We haven't reached the backup quota yet so we don't delete anything.
    elsif ($num_backups <= $num_to_keep) { return } 

    # User changed their settings to keep less backups than they
    # were keeping prior. 
    else { 
	
	while ($num_backups > $num_to_keep) {

	    # note that pop mutates existing_snaps
	    my $oldest_backup = $backup_path . pop @existing_backups;
            
	    $ssh->system("sudo -n btrfs subvolume delete $oldest_backup");

	    $num_backups--;
	} 

	return;
    }
}

sub take_new_snapshot { # No test. Is not pure.

    # take a single $timeframe read-only snapshot of $subvol.

    my ($config_ref, $subvol, $timeframe) = @_;

    my $mountpoint = $config_ref->{subvols}{$subvol}{mountpoint};

    my $snap_dir = local_snapshot_dir($config_ref, $subvol, $timeframe);

    my $snapshot_name = current_time_snapstring();

    system( 'btrfs subvol snapshot -r '
	  . $mountpoint
	  . " $snap_dir/$snapshot_name"
	  ); 

    return 1;
}

sub delete_old_snapshots { # No test. Is not pure.
    
    # Delete old snapshot(s) based off $subvol's $timeframe_keep
    # setting defined in the users config. This function should be
    # called after take_new_snapshot().

    my ($config_ref, $subvol, $timeframe) = @_;

    # these snaps are sorted from newest to oldest
    my $existing_snaps_ref = all_snapshots_of($config_ref, $subvol, $timeframe);

    my $num_snaps = scalar @$existing_snaps_ref;

    my $num_to_keep = $config_ref->{subvols}{$subvol}{"${timeframe}_keep"};

    # The most common case is there is 1 more snapshot than should be
    # kept because we just took a snapshot.
    if ($num_snaps == $num_to_keep + 1) { 

	# pop takes from the end of the array. This is the oldest snap
	# because they are sorted newest to oldest.
	my $oldest_snap = pop @$existing_snaps_ref;

	system("btrfs subvolume delete $oldest_snap");

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
            
	    system("btrfs subvolume delete $oldest_snap");

	    $num_snaps--;
	} 

	return;
    }
}

1;
