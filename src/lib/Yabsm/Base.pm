#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  Core library of Yabsm. The $config_ref variable that is passed
#
#  See Base.t for the testing of this library.

#  The $config_ref variable that is passed around this library is
#  created by the read_config() subroutine from the Yabsm::Config
#  library.
#
#  All the subroutines are annoted to communicate if the subrouting
#  has a unit test in Base.t, and if the function is pure. If the
#  function is pure it means it has no effects on any external state
#  whether that be a global variable or the filesystem. A pure
#  subroutine also always produces the same output if given the same
#  input.

package Yabsm::Base;

use strict;
use warnings;
use 5.010;

use Time::Piece;
use Net::OpenSSH;
use List::Util qw(any);
use File::Copy qw(move);
use File::Path qw(make_path);
use Carp;

sub all_snapshots_of { # No test. Is not pure.

    # Read filesystem to gather the snapshots for a given subvolume or
    # backup. Can optionally pass timeframe arguments to only get
    # snapshots of certain timeframes. Passing timeframe arguments is only
    # relevant when gathering the snapshots of a subvol.

    my $config_ref = shift // confess;
    my $subject    = shift // confess;
    my @timeframes = @_;

    my @all_snaps; # return this

    if (is_subvol($config_ref, $subject)) {
	
	my $subvol = $subject;

	# default to all timeframes
	if (not @timeframes) {
	    @timeframes = qw(5minute hourly midnight monthly);
	}
	
	foreach my $tf (@timeframes) {
	    
	    my $snap_dir = local_snap_dir($config_ref, $subvol, $tf);
	    
	    if (-d $snap_dir) {
		push @all_snaps, glob "$snap_dir/*"; 
	    }
	}
    }

    elsif (is_local_backup($config_ref, $subject)) {

	my $backup = $subject;

	my $backup_dir = $config_ref->{backups}{$backup}{backup_dir};

	@all_snaps = glob "$backup_dir/*";
    }

    elsif (is_remote_backup($config_ref, $subject)) {
	
	my $backup = $subject;

	my $remote_host = $config_ref->{backups}{$backup}{host};
	
	my $backup_dir  = $config_ref->{backups}{$backup}{backup_dir};

	my $ssh = new_ssh_connection($remote_host);
	
	# prepend paths with host name
	@all_snaps = map { chomp; $_ = "$remote_host:$_" } $ssh->capture("ls -d $backup_dir/*");
    }
    
    else { confess }
    
    # return the snapshots sorted
    my $snaps_sorted_ref = sort_snaps(\@all_snaps);

    return wantarray ? @$snaps_sorted_ref : $snaps_sorted_ref;
}

sub initialize_directories { # No test. Is not pure.

    # This subroutine is called everytime the yabsm script is run
    # (unless using --help or --check-config flags). This subroutine
    # allows us to be assured that all needed directories have been
    # created.

    my $config_ref = shift // confess;

    my $yabsm_root_dir = $config_ref->{misc}{yabsm_snapshot_dir};

    if (not -d $yabsm_root_dir) {
	make_path($yabsm_root_dir);
    }

    # .tmp dir holds tmp snaps for backups
    if (not -d $yabsm_root_dir . '/.tmp') {
	make_path($yabsm_root_dir . '/.tmp');
    }

    foreach my $subvol (all_subvols($config_ref)) {

	my $subvol_dir = "$yabsm_root_dir/$subvol";

	if (not -d $subvol_dir) {
	    make_path($subvol_dir);
	}

	my $_5minute_want = $config_ref->{subvols}{$subvol}{_5minute_want};
	my $hourly_want   = $config_ref->{subvols}{$subvol}{hourly_want};
	my $midnight_want = $config_ref->{subvols}{$subvol}{midnight_want};
	my $monthly_want  = $config_ref->{subvols}{$subvol}{monthly_want};

	
	if ($_5minute_want eq 'yes' && not -d "$subvol_dir/5minute") {
	    make_path("$subvol_dir/5minute");
	}

	if ($hourly_want eq 'yes' && not -d "$subvol_dir/hourly") {
	    make_path("$subvol_dir/hourly");
	}

	if ($midnight_want eq 'yes' && not -d "$subvol_dir/midnight") {
	    make_path("$subvol_dir/midnight");
	}

	if ($monthly_want eq 'yes' && not -d "$subvol_dir/monthly") {
	    make_path("$subvol_dir/monthly");
	}

	# backup bootstrap snapshot dirs
	foreach my $backup (all_backups_of_subvol($config_ref, $subvol)) {
	    if (not -d "$subvol_dir/.backups/$backup/bootstrap-snap") {
		make_path("$subvol_dir/.backups/$backup/bootstrap-snap");
	    }
	}
    }
    
    return;
}

sub local_snap_dir { # Has test. Is pure.

    # Return the local directory path for yabsm snapshots. The $subvol
    # and $timeframe arguments are optional. Note that this function
    # does not check that $subvol and $timeframe are valid.

    my $config_ref = shift // confess;
    my $subvol     = shift; # optional
    my $timeframe  = shift; # optional

    my $yabsm_dir = $config_ref->{misc}{yabsm_snapshot_dir};

    if (defined $subvol) {
	$yabsm_dir .= "/$subvol";
	if (defined $timeframe) { 
	    $yabsm_dir .= "/$timeframe";
	}
    }

    return $yabsm_dir;
}

sub bootstrap_snap_dir { # Has test. Is pure.

    # Return the path the the directory holding the bootstrap snapshot
    # for $backup. The bootstrap snapshot is vital for incremental backups.

    my $config_ref = shift // confess;
    my $backup     = shift // confess;

    my $subvol = $config_ref->{backups}{$backup}{subvol};

    my $yabsm_dir = $config_ref->{misc}{yabsm_snapshot_dir};

    return "$yabsm_dir/$subvol/.backups/$backup/bootstrap-snap";
}

sub is_snapstring { # Has test. Is pure.

    # Return 1 iff $snapstring is a valid snapstring. Note that this
    # sub works on absolute paths as well as plain snapstrings.

    my $snapstring = shift // confess;

    return $snapstring =~ /day=\d{4}_\d{2}_\d{2},time=\d{2}:\d{2}$/;
}

sub current_time_snapstring { # No test. Is not pure.
    
    # This function is used be used to create a snapstring name
    # of the current time.
    
    my ($min, $hr, $day, $mon, $yr) =
      map { sprintf '%02d', $_ } (localtime)[1..5]; 
    
    $mon++;      # month count starts at zero. 
    $yr += 1900; # year represents years since 1900. 
    
    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

sub n_units_ago_snapstring { # Has test. Is not pure.

    # Subtract $n minutes, hours, or days from the current
    # time. Returns a snapstring.

    my $n    = shift // confess;
    my $unit = shift // confess;

    # Can only add/subtract by seconds with Time::Piece objects.

    my $seconds_per_unit;

    if    ($unit =~ /^(m|mins|minutes)$/) { $seconds_per_unit = 60    }
    elsif ($unit =~ /^(h|hrs|hours)$/   ) { $seconds_per_unit = 3600  }
    elsif ($unit =~ /^(d|days)$/        ) { $seconds_per_unit = 86400 }
    else  { confess "\"$unit\" is not a valid time unit" }

    my $current_time = current_time_snapstring();

    my $time_piece_obj = snapstring_to_time_piece_obj($current_time);

    $time_piece_obj -= ($n * $seconds_per_unit);

    return time_piece_obj_to_snapstring($time_piece_obj);
}

sub immediate_to_snapstring { # No test. Is pure. 

    # Resolve an immediate to a snapstring. An immediate is either a
    # literal time, relative time, newest time, or oldest time.

    my $all_snaps_ref = shift // confess;
    my $imm           = shift // confess;

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
    confess "[!] Internal Error: '$imm' is not an immediate";
}

sub literal_time_to_snapstring { # Has test. Is pure.

    # resolve a literal time to a snapstring

    my $lit_time = shift // confess;

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

    confess "[!] Internal Error: '$lit_time' is not a valid literal time";
}

sub relative_time_to_snapstring { # Has test. Is not pure.

    # resolve a relative time to a snapstring. Relative times have the
    # form 'back-amount-unit'.

    my $rel_time = shift // confess;

    my (undef, $amount, $unit) = split '-', $rel_time, 3;

    my $n_units_ago_snapstring = n_units_ago_snapstring($amount, $unit);

    return $n_units_ago_snapstring; 
}

sub snapstring_to_nums { # Has test. Is pure.

    # Take a snapshot name string and return an array containing in
    # order the year, month, day, hour, and minute. This works with
    # both a full path and just a snapshot name string.

    my $snap = shift // confess;

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

    my $snap = shift // confess;

    my ($yr, $mon, $day, $hr, $min) = snapstring_to_nums($snap);

    return Time::Piece->strptime("$yr/$mon/$day/$hr/$min",'%Y/%m/%d/%H/%M');
}

sub time_piece_obj_to_snapstring { # Has test. Is pure.

    # Turn a Time::Piece object into a snapshot name string.

    my $time_piece_obj = shift // confess;

    my $yr  = $time_piece_obj->year;
    my $mon = $time_piece_obj->mon;
    my $day = $time_piece_obj->mday;
    my $hr  = $time_piece_obj->hour;
    my $min = $time_piece_obj->min;

    return nums_to_snapstring($yr, $mon, $day, $hr, $min);
}

sub sort_snaps { # Has test. Is pure.

    # Return a sorted version of the inputted array ref of
    # snapshots. Sorted from newest to oldest. Works with full
    # paths and plain snapstrings.

    my $snaps_ref = shift // confess;

    my @sorted_snaps = sort { cmp_snaps($a, $b) } @$snaps_ref;

    return wantarray ? @sorted_snaps : \@sorted_snaps;
}

sub cmp_snaps { # Has test. Is pure.

    # Return -1 if $snap1 is newer than $snap2.
    # Return 1 if $snap1 is older than $snap2
    # Return 0 if $snap1 and $snap2 are the same. 
    # Works with both full paths and plain snapstrings.

    my $snap1 = shift // confess;
    my $snap2 = shift // confess;

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

sub ask_user_for_subvol_or_backup { # No test. Is not pure.

    # Prompt user to select one of their defined subvols or
    # backups. Used for the --find option when the user doesn't
    # explicitly pass their subvol/backup on the command line.

    my $config_ref = shift // confess;

    my $int = 1;
    my %int_subvol_hash = map { $int++ => $_ } all_subvols($config_ref);
    my %int_backup_hash = map { $int++ => $_ } all_backups($config_ref);

    my $selection; # return this
    
    while (not defined $selection) {

	# prompt user
	my $int = 1;
	my $iter;
	for ($iter = 1; $iter <= keys %int_subvol_hash; $iter++) {
	    my $subvol = $int_subvol_hash{ $int };
	    if ($iter == 1)       { print "Subvols:\n"              }
	    if ($iter % 3 == 0)   { print "$int -> $subvol\n"       }
	    else                  { print "$int -> $subvol" . ' 'x4 }
	    $int++;
	}
	for ($iter = 1; $iter <= keys %int_backup_hash; $iter++) {
	    my $backup = $int_backup_hash{ $int };
	    if ($iter == 1)       { print "\nBackups:\n"              }
	    if ($iter % 3 == 0)   { print "$int -> $backup\n"       }
	    else                  { print "$int -> $backup" . ' 'x4 }
	    $int++;
	}
	if ($iter % 3 == 0) { print '>>> '   }
	else                { print "\n>>> " }

	# process input
	my $input = <STDIN>;
	my $cleansed = $input =~ s/\s+//gr; # no whitespace
	
	exit 0 if $cleansed =~ /^q(uit)?$/;
	
	if (exists $int_subvol_hash{ $cleansed }) { # success
	    $selection = $int_subvol_hash{ $cleansed };
	}
	elsif (exists $int_backup_hash{ $cleansed }) { # success
	    $selection = $int_backup_hash{ $cleansed };
	}
	else {
	    print "No option '$input'! Try again!\n\n";
	}
    }

    return $selection;
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

sub snap_closest_to { # Has test. Is pure.

    # Return the snapshot from $all_snaps_ref that is closest to
    # $target_snap. $all_snaps_ref is sorted from newest to oldest.

    my $all_snaps_ref = shift // confess;
    my $target_snap   = shift // confess;

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

    my $target_snap = shift // confess;
    my $snap1       = shift // confess;
    my $snap2       = shift // confess;

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

    my $all_snaps_ref = shift // confess;
    my $target_snap   = shift // confess;

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

    my $all_snaps_ref = shift // confess;
    my $target_snap   = shift // confess;

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

    my $all_snaps_ref = shift // confess;
    my $target_snap1  = shift // confess;
    my $target_snap2  = shift // confess;

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

		else {
		    push @snaps_between, $this_snap;
		}
	    }
	    
	    last;
	}
    }

    return wantarray ? @snaps_between : \@snaps_between;
}

sub newest_snap { # Has test. Is not pure.

    # $ref can be either a hash ref to the users config or an array
    # ref of snapshots. We can return the first element in the snapshot
    # array because it will always be sorted from newest to oldest.
    # Only the scenario of $ref being a snapshot array ref is tested.

    my $ref    = shift // confess;
    my $subvol = shift; # only needed if passing $config_ref

    my $newest_snap;

    if (ref($ref) eq 'ARRAY') {
	$newest_snap = $ref->[0]
    }

    elsif (ref($ref) eq 'HASH') {
	my $all_snaps_ref = all_snapshots_of($ref, $subvol);
	$newest_snap = $all_snaps_ref->[0];
    }

    else { confess }

    return $newest_snap;
}

sub oldest_snap { # Has test. Is not pure.

    # $ref can be either a hash ref to the users config or an array
    # ref of snapshots. We can return the last element in the snapshot
    # array because it will always be sorted from newest to oldest.
    # Only the scenario of $ref being a snapshot array ref is tested.
    
    my $ref    = shift // confess;
    my $subvol = shift; # only needed if passing $config_ref

    my $oldest_snap;

    if (ref($ref) eq 'ARRAY') {
	$oldest_snap = $ref->[-1];
    }

    elsif (ref($ref) eq 'HASH') {
	my $all_snaps_ref = all_snapshots_of($ref, $subvol);
	$oldest_snap = $all_snaps_ref->[-1];
    }

    else { confess }

    return $oldest_snap;
}

sub answer_query { # No test. Is not pure.

    # Answers $query to find the appropiate snapshot(s) of
    # $subject. We $subject can either be a subvol or a backup. We
    # expect that $query has already been validated.

    my $config_ref = shift // confess;
    my $subject    = shift // confess;
    my $query      = shift // confess;

    my $all_snaps_ref = all_snapshots_of($config_ref, $subject);

    my @snaps_to_return;

    if (is_immediate($query)) {

	my $target = immediate_to_snapstring($all_snaps_ref, $query); 

	my $snap = snap_closest_to($all_snaps_ref, $target);

	# return just one snap
	push @snaps_to_return, $snap;
    }

    elsif (is_all_query($query)) {
	# return all the snaps
	@snaps_to_return = @$all_snaps_ref;
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
	confess "[!] Internal Error: '$query' is not a valid query";
    }

    return wantarray ? @snaps_to_return : \@snaps_to_return;
}

sub is_valid_query { # Has test. Is pure.

    my $query = shift // confess;

    if (is_immediate($query))     { return 1 }
    if (is_all_query($query))     { return 1 }
    if (is_newer_query($query))   { return 1 }
    if (is_older_query($query))   { return 1 }
    if (is_between_query($query)) { return 1 }

    return 0;
}

sub is_immediate { # Has test. Is pure.

    # An immediate is either a literal time or a relative time.

    my $imm = shift // confess;
    
    return is_newest_time($imm)
        || is_oldest_time($imm)
        || is_literal_time($imm)
        || is_relative_time($imm);
}

sub is_literal_time { # Has test. Is pure.

    # Literal times can come in one of 5 different forms. 

    my $lit_time = shift // confess;

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

    my $query = shift // confess;

    my ($back, $amount, $unit) = split '-', $query, 3;

    return 0 if any { not defined } ($back, $amount, $unit);

    my $back_correct = $back =~ /^b(ack)?$/;

    my $amount_correct = $amount =~ /^\d+$/;
    
    my $unit_correct = any { $_ eq $unit } qw/minutes mins m hours hrs h days d/;
    
    return $back_correct && $amount_correct && $unit_correct;
}

sub is_newer_query { # Has test. Is pure.

    # Return 1 iff $query is a syntactically valid 'newer' query.
    # A newer query can have either the keyword 'newer' or 'after'.

    my $query = shift // confess;

    my ($keyword, $imm) = split /\s/, $query, 2;

    return 0 if any { not defined } ($keyword, $imm);

    my $keyword_correct = $keyword =~ /^(newer|after)$/;

    my $imm_correct = is_immediate($imm);

    return $keyword_correct && $imm_correct;
}

sub is_older_query { # Has test. Is pure.

    # Return 1 iff $query is a syntactically valid 'older' query.
    # A older query can have either the keyword 'older' or 'before'.

    my $query = shift // confess;

    my ($keyword, $imm) = split /\s/, $query, 2;

    return 0 if any { not defined } ($keyword, $imm);

    my $keyword_correct = $keyword =~ /^(older|before)$/;

    my $imm_correct = is_immediate($imm);

    return $keyword_correct && $imm_correct;
}

sub is_all_query { # Has test. Is pure.

    # return 1 iff $query equals 'all'.

    my $query = shift // confess;

    return $query eq 'all';
}

sub is_newest_time { # Has test. Is pure.
    
    # Return 1 iff $query equals 'newest'.

    my $query = shift // confess;

    return $query eq 'newest';
}

sub is_oldest_time { # Has test. Is pure.
    
    # Return 1 iff $query equals 'oldest'.

    my $query = shift // confess;

    return $query eq 'oldest';
}

sub is_between_query { # Has test. Is pure.

    # Return 1 iff $query is a syntactically valid 'after' query.

    my $query = shift // confess;

    my ($keyword, $imm1, $imm2) = split /\s/, $query, 3;

    return 0 if any { not defined } ($keyword, $imm1, $imm2);

    my $keyword_correct = $keyword =~ /^bet(ween)?$/;

    my $imm1_correct = is_immediate($imm1);

    my $imm2_correct = is_immediate($imm2);

    return $keyword_correct && $imm1_correct && $imm2_correct;
}

sub all_subvols { # Has test. Is pure.

    # Return an array of the names of every user defined subvolume.

    my $config_ref = shift // confess;

    my @subvols = sort keys %{$config_ref->{subvols}};

    return wantarray ? @subvols : \@subvols;
}

sub all_backups { # Has test. Is pure.

    # Return an array of the names of every user defined backup

    my $config_ref = shift // confess;

    my @backups = sort keys %{$config_ref->{backups}};

    return wantarray ? @backups : \@backups;
}

sub all_backups_of_subvol { # Has test. Is pure.

    # Return an array of all the backups that are backing up $subvol.

    my $config_ref = shift // confess;
    my $subvol     = shift // confess;

    my @backups = ();

    foreach my $backup (all_backups($config_ref)) {

	my $backup_subvol = $config_ref->{backups}{$backup}{subvol};

	push @backups, $backup if $subvol eq $backup_subvol;
    }

    return wantarray ? @backups : \@backups;
}

sub is_subvol { # Has test. Is pure.

    # Return 1 iff $subvol is the name of a defined yabsm subvolume.
    
    my $config_ref = shift // confess;
    my $subvol     = shift // confess;
    
    return any { $_ eq $subvol } all_subvols($config_ref);
}

sub is_backup { # Has test. Is pure.

    # Return 1 iff $backup is the name of a defined yabsm backup.

    my $config_ref = shift // confess;
    my $backup     = shift // confess;

    return any { $_ eq $backup } all_backups($config_ref);
}

sub is_local_backup { # Has test. Is pure.

    # Return 1 iff $backup is the name of a defined yabsm local backup.

    my $config_ref = shift // confess;
    my $backup     = shift // confess;

    if (is_backup($config_ref, $backup)) {
	return $config_ref->{backups}{$backup}{remote} eq 'no';
    }
    else { return 0 }
}

sub is_remote_backup { # Has test. Is pure.

    # Return 1 iff $backup is the name of a defined yabsm remote backup.

    my $config_ref = shift // confess;
    my $backup     = shift // confess;

    if (is_backup($config_ref, $backup)) {
	return $config_ref->{backups}{$backup}{remote} eq 'yes';
    }
    else { return 0 }
}

sub update_etc_crontab { # No test. Is not pure.
    
    # Write cronjobs to '/etc/crontab'

    my $config_ref = shift // confess;

    open (my $etc_crontab_fh, '<', '/etc/crontab')
      or die "[!] Error: failed to open file '/etc/crontab'\n";

    open (my $tmp_fh, '>', '/tmp/yabsm-update-tmp')
      or die "[!] Error: failed to open tmp file '/tmp/yabsm-update-tmp'\n";

    # Copy all lines from /etc/crontab into the tmp file, excluding
    # the existing yabsm cronjobs.
    while (<$etc_crontab_fh>) {

	s/\s+$//;        # strip trailing whitespace

	next if /yabsm/; # don't copy the old yabsm cronjobs

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
    
    my $config_ref = shift // confess;

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

    foreach my $backup (all_backups($config_ref)) {

	my $timeframe = $config_ref->{backups}{$backup}{timeframe};

	if ($timeframe eq 'hourly') {
	    push @cron_strings, "0 */1 * * * root yabsm --do-backup $backup";
	}

	elsif ($timeframe eq 'midnight') {
	    push @cron_strings, "59 23 * * * root yabsm --do-backup $backup";
	}

	elsif ($timeframe eq 'monthly') {
	    push @cron_strings, "0 0 1 * * root yabsm --do-backup $backup";
	}
    }

    return wantarray ? @cron_strings : \@cron_strings;
}

sub new_ssh_connection { # No test. Is not pure.

    # Create and return an ssh connection object with Net::OpenSSH.

    my $remote_host = shift // confess;

    my $ssh = Net::OpenSSH->new( $remote_host,
			       , batch_mode => 1 # Don't ask for password
			       , timeout => 15   # timeout after 15 seconds
			       , kill_ssh_on_timeout => 1
			       );

    # kill the program if we cannot establish a connection to $remote_host
    $ssh->error and 
      die "[!] Error: Couldn't establish SSH connection: " . $ssh->error . "\n";

    return $ssh;
}

sub do_backup_bootstrap_ssh { # No test. Is not pure. TODO: document

    # Perform bootstrap phase of incremental backup over ssh. To
    # bootstrap a backup we create a new snapshot and place it in the
    # subvol being snapped's backup bootstrap dir
    # (for example /.snapshots/yabsm/home/backups/homeBackup/bootstrap-snap/)
    # Please see the
    # btrfs wiki section on incremental backups for more information.

    my $config_ref = shift // confess;
    my $backup     = shift // confess;

    my $remote_host = $config_ref->{backups}{$backup}{host};

    my $ssh = new_ssh_connection($remote_host);

    my $subvol = $config_ref->{backups}{$backup}{subvol};

    my $bootstrap_snap_dir = bootstrap_snap_dir($config_ref, $backup);

    # delete old bootstrap snap
    system("btrfs subvol delete $_") for glob "$bootstrap_snap_dir/*";

    my $mountpoint = $config_ref->{subvols}{$subvol}{mountpoint};
    
    my $bootstrap_snap = "$bootstrap_snap_dir/" . current_time_snapstring();
    
    system("btrfs subvol snapshot -r $mountpoint $bootstrap_snap");

    my $remote_backup_dir = $config_ref->{backups}{$backup}{backup_dir};

    # create $remote_backup_dir if it does not exist
    $ssh->system( "if [ ! -d \"$remote_backup_dir\" ];"
		. "then mkdir -p $remote_backup_dir; fi"
		);

    # send the bootstrap backup to remote host
    $ssh->system({stdin_file => ['-|', "btrfs send $bootstrap_snap"]}
		, "sudo -n btrfs receive $remote_backup_dir"
	        );
}

sub do_backup_ssh { # No test. Is not pure. TODO: document

    my $config_ref = shift // confess;
    my $backup     = shift // confess;

    my $subvol = $config_ref->{backups}{$backup}{subvol};

    my $remote_backup_dir = $config_ref->{backups}{$backup}{backup_dir};

    my $bootstrap_snap =
      [glob (bootstrap_snap_dir($config_ref, $backup) . '/*')]->[0];

    # we have not already bootstrapped
    if (not defined $bootstrap_snap) {
	do_backup_bootstrap_ssh($config_ref, $backup);
    }
    
    # we have already bootstrapped.
    else {
	
	my $remote_host = $config_ref->{backups}{$backup}{host};

	# initialize an ssh connection object
	my $ssh = new_ssh_connection($remote_host);

	my $tmp_snap =
	  local_snap_dir($config_ref) . '/.tmp/' . current_time_snapstring();

	my $mountpoint = $config_ref->{subvols}{$subvol}{mountpoint};
	
	system("btrfs subvol snapshot -r $mountpoint $tmp_snap");
	
	# send an incremental backup over ssh
	$ssh->system(
	    {stdin_file => ['-|', "btrfs send -p $bootstrap_snap $tmp_snap"]}
		           , "sudo -n btrfs receive $remote_backup_dir"
		           );
	
	system("btrfs subvol delete $tmp_snap");
	
	delete_old_backups_ssh($config_ref, $ssh, $backup);
    }

    return;
}

sub delete_old_backups_ssh { # TODO DOCUMENT

    # Delete old backup snapshot(s) based off $backup's
    # $keep setting defined in the users config. This
    # function should be called after do_backup_ssh;

    my $config_ref = shift // confess;
    my $ssh        = shift // confess;
    my $backup     = shift // confess;

    my $remote_backup_dir = $config_ref->{backups}{$backup}{backup_dir}; 

    my @existing_backups =
      sort_snaps([$ssh->capture("ls -d $remote_backup_dir/*")]);

    my $num_backups = scalar @existing_backups;

    my $num_to_keep = $config_ref->{backups}{$backup}{keep};

    # The most common case is there is 1 more backup than should be
    # kept because we just performed a backup.
    if ($num_backups == $num_to_keep + 1) {

	# pop takes from the end of the array. This is the oldest backup
	# because they are sorted newest to oldest.
	my $oldest_backup = pop @existing_backups;

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
	    my $oldest_backup = pop @existing_backups;
            
	    $ssh->system("sudo -n btrfs subvolume delete $oldest_backup");

	    $num_backups--;
	} 

	return;
    }
}

sub take_new_snapshot { # No test. Is not pure.

    # take a single $timeframe read-only snapshot of $subvol.

    my $config_ref = shift // confess;
    my $subvol     = shift // confess;
    my $timeframe  = shift // confess;

    my $mountpoint = $config_ref->{subvols}{$subvol}{mountpoint};

    my $snap_dir = local_snap_dir($config_ref, $subvol, $timeframe);

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

    my $config_ref = shift // confess;
    my $subvol     = shift // confess;
    my $timeframe  = shift // confess;

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
