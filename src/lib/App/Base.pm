#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  The core module of Yabsm.
#
#  See t/Base.t for this modules tests.
#
#  The $config_ref variable that is passed around many of this modules
#  subroutines is created by the read_config() subroutine from the
#  App::Config module.
#
#  App::Config::read_config() ensures that the config it produces is
#  valid, therefore functions in this library do need to worry about
#  edge cases caused by an erroneus config.
#
#  All the subroutines are annoted to communicate if the subroutine
#  has a unit test in Base.t, and if the function is pure. If the
#  function is pure it means it has no effects on any external state
#  whether that be a global variable or the filesystem, and always
#  produces the same output given the same input.
#
#  Just because a function doesn't have a unit test does not mean it
#  has not been informally tested.
#
#  An error message prefixed with 'internal error' is an error for a
#  scenario that should never occur unless a bug is present.

package App::Base;

use strict;
use warnings;
use 5.010;

use Net::OpenSSH;
use Time::Piece;
use Carp;
use List::Util qw(any);
use File::Copy qw(copy move);
use File::Path qw(make_path); # make_path() behaves like 'mkdir --parents'

sub take_new_snapshot { # No test. Is not pure.

    # take a single $timeframe snapshot of $subvol. Used for yabsm's
    # 'take-snap' command.

    my $config_ref = shift // confess missing_arg();
    my $subvol     = shift // confess missing_arg();
    my $timeframe  = shift // confess missing_arg();

    my $mountpoint = $config_ref->{subvols}{$subvol}{mountpoint};

    my $snap_dir = local_snap_dir($config_ref, $subvol, $timeframe);

    my $snap_name = current_time_snapstring();

    system("btrfs subvol snapshot -r $mountpoint $snap_dir/$snap_name");

    return;
}

sub delete_old_snapshots { # No test. Is not pure.
    
    # delete old snapshot(s) based off $subvol's ${timeframe}_keep
    # setting defined in the users config. This function should be
    # called directly after take_new_snapshot().

    my $config_ref = shift // confess missing_arg();
    my $subvol     = shift // confess missing_arg();
    my $timeframe  = shift // confess missing_arg();

    my $existing_snaps_ref = all_snapshots($config_ref, $subvol, $timeframe);

    my $num_snaps = scalar @$existing_snaps_ref;

    my $num_to_keep = $config_ref->{subvols}{$subvol}{"${timeframe}_keep"};

    # There is 1 more snapshot than should be kept because we just
    # took a snapshot.
    if ($num_snaps == $num_to_keep + 1) { 

	# pop takes from the end of the array. This is the oldest snap
	# because they are sorted newest to oldest.
	my $oldest_snap = pop @$existing_snaps_ref;

	system("btrfs subvol delete $oldest_snap");

	return;
    }

    # We haven't reached the snapshot quota yet so we don't delete anything.
    elsif ($num_snaps <= $num_to_keep) { return } 

    # User changed their settings to keep less snapshots than they
    # were keeping prior. 
    else { 
	
	while ($num_snaps > $num_to_keep) {

	    # pop mutates $existing_snaps_ref, and thus is not idempotent.
            my $oldest_snap = pop @$existing_snaps_ref;
            
	    system("btrfs subvol delete $oldest_snap");

	    $num_snaps--;
	} 

	return;
    }
}

sub do_backup { # No test. Is not pure.

    # Determine if $backup is local or remote and dispatch the
    # corresponding do_backup_* subroutine.

    my $config_ref = shift // confess missing_arg();
    my $backup     = shift // confess missing_arg();

    if (is_local_backup($config_ref, $backup)) {
	do_backup_local($config_ref, $backup);
    }

    elsif (is_remote_backup($config_ref, $backup)) {
	do_backup_ssh($config_ref, $backup);
    }

    else {
	confess "internal error: no such defined backup '$backup'";
    }

    return;
}

sub do_backup_local { # No test. Is not pure.

    # Perform a single incremental btrfs backup of $backup, or in the
    # case that the bootstrap process has not yet happened we call
    # do_backup_bootstrap_local() and return. See btrfs documentation
    # on incremental backups for more information.

    my $config_ref = shift // confess missing_arg();
    my $backup     = shift // confess missing_arg();

    my $backup_dir = $config_ref->{backups}{$backup}{backup_dir};

    # bootstrap dir should have one snap
    my $bootstrap_snap = [glob bootstrap_snap_dir($config_ref, $backup) . '/*']->[0];

    # we have not already bootstrapped
    if (not defined $bootstrap_snap) {
	do_backup_bootstrap_local($config_ref, $backup);
	return;
    }

    # do incremental backup
	
    my $subvol = $config_ref->{backups}{$backup}{subvol};

    my $mountpoint = $config_ref->{subvols}{$subvol}{mountpoint};
    
    my $tmp_snap = local_snap_dir($config_ref, '.tmp/') . current_time_snapstring();
    
    system("btrfs subvol snapshot -r $mountpoint $tmp_snap");
    
    system("btrfs send -p $bootstrap_snap $tmp_snap | btrfs receive $backup_dir");

    system("btrfs subvol delete $tmp_snap");

    delete_old_backups_local($config_ref, $backup);

    return;
}


sub do_backup_ssh { # No test. Is not pure.

    # Perform a single incremental btrfs backup of $backup over ssh,
    # or in the case that the bootstrap process has not yet happened
    # we call do_backup_bootstrap_ssh() and return. See btrfs
    # documentation on incremental backups for more information.

    my $config_ref = shift // confess missing_arg();
    my $backup     = shift // confess missing_arg();

    my $remote_backup_dir = $config_ref->{backups}{$backup}{backup_dir};

    # bootstrap dir should have one snap
    my $bootstrap_snap =
      [glob bootstrap_snap_dir($config_ref, $backup) . '/*']->[0];

    # we have not already bootstrapped
    if (not defined $bootstrap_snap) {
	do_backup_bootstrap_ssh($config_ref, $backup);
	return;
    }

    # do incremental backup
	
    my $subvol = $config_ref->{backups}{$backup}{subvol};
    
    my $remote_host = $config_ref->{backups}{$backup}{host};

    my $ssh = new_ssh_connection($remote_host);

    my $mountpoint = $config_ref->{subvols}{$subvol}{mountpoint};
    
    my $tmp_snap = local_yabsm_dir($config_ref, '.tmp/') . current_time_snapstring();
	
    system("btrfs subvol snapshot -r $mountpoint $tmp_snap");
	
    # send an incremental backup over ssh
    $ssh->system({stdin_file => ['-|', "btrfs send -p $bootstrap_snap $tmp_snap"]}
		                , "sudo -n btrfs receive $remote_backup_dir");
	
    system("btrfs subvol delete $tmp_snap");
	
    delete_old_backups_ssh($config_ref, $ssh, $backup);

    return;
}

sub do_backup_bootstrap { # No test. Is not pure.

    # Determine if $backup is local or remote and dispatch the
    # corresponding do_backup_bootstrap* subroutine.

    my $config_ref = shift // confess missing_arg();
    my $backup     = shift // confess missing_arg();

    if (is_local_backup($config_ref, $backup)) {
	do_backup_bootstrap_local($config_ref, $backup);
    }

    elsif (is_remote_backup($config_ref, $backup)) {
	do_backup_bootstrap_ssh($config_ref, $backup);
    }

    else {
	confess "internal error: no such user defined backup '$backup'";
    }

    return;
}

sub do_backup_bootstrap_local { # No test. Is not pure.

    # Perform bootstrap phase of a btrfs incremental backup. To
    # bootstrap a backup we create a new snapshot and place it in the
    # subvol being snapped's backup bootstrap dir (for example
    # /.snapshots/yabsm/home/backups/homeBackup/bootstrap-snap/), and
    # then btrfs send/receive the bootstrap snap.

    my $config_ref = shift // confess missing_arg();
    my $backup     = shift // confess missing_arg();

    my $bootstrap_snap_dir = bootstrap_snap_dir($config_ref, $backup);

    # delete old bootstrap snap
    system("btrfs subvol delete $_") for glob "$bootstrap_snap_dir/*";

    my $bootstrap_snap = "$bootstrap_snap_dir/" . current_time_snapstring();

    my $subvol = $config_ref->{backups}{$backup}{subvol};

    my $mountpoint = $config_ref->{subvols}{$subvol}{mountpoint};

    my $backup_dir = $config_ref->{backups}{$backup}{backup_dir};
    
    system("btrfs subvol snapshot -r $mountpoint $$bootstrap_snap");

    system("btrfs subvol send $bootstrap_snap | btrfs receive $backup_dir");

    # neccesary because the user may be redoing the bootstrap phase
    # and therefore may end up with an extra backup.
    delete_old_backups_local($config_ref, $backup);
}

sub do_backup_bootstrap_ssh { # No test. Is not pure.

    # Perform bootstrap phase of a btrfs incremental backup. To
    # bootstrap a backup we create a new snapshot and place it in the
    # subvol being snapped's backup bootstrap dir (for example
    # /.snapshots/yabsm/home/backups/homeBackup/bootstrap-snap/), and
    # then btrfs send/receive the bootstrap snap over ssh.

    my $config_ref = shift // confess missing_arg();
    my $backup     = shift // confess missing_arg();

    my $remote_host = $config_ref->{backups}{$backup}{host};

    my $ssh = new_ssh_connection($remote_host);

    my $bootstrap_snap_dir = bootstrap_snap_dir($config_ref, $backup);

    my $bootstrap_snap = "$bootstrap_snap_dir/" . current_time_snapstring();

    # delete old bootstrap snap
    system("btrfs subvol delete $_") for glob "$bootstrap_snap_dir/*";

    my $subvol = $config_ref->{backups}{$backup}{subvol};

    my $mountpoint = $config_ref->{subvols}{$subvol}{mountpoint};
    
    system("btrfs subvol snapshot -r $mountpoint $bootstrap_snap");

    my $remote_backup_dir = $config_ref->{backups}{$backup}{backup_dir};

    # create $remote_backup_dir if it does not exist.
    $ssh->system( "if [ ! -d \"$remote_backup_dir\" ];"
		. "then mkdir -p $remote_backup_dir; fi"
		);

    # send the bootstrap backup to remote host
    $ssh->system({stdin_file => ['-|', "btrfs send $bootstrap_snap"]}
		, "sudo -n btrfs receive $remote_backup_dir"
	        );

    # neccesary because the user may be redoing the bootstrap phase
    # and will therefore end up with an extra backup.
    delete_old_backups_ssh($config_ref, $ssh, $backup);
}

sub delete_old_backups_local { # No test. Is not pure.

    # Delete old backup snapshot(s) based off $backup's
    # $keep setting defined in the users config. This
    # function should be called directly after do_backup_local().

    my $config_ref = shift // confess missing_arg();
    my $backup     = shift // confess missing_arg();

    my $backup_dir = $config_ref->{backups}{$backup}{backup_dir};

    my @existing_backups = all_snapshots($config_ref, $backup);

    my $num_backups = scalar @existing_backups;

    my $num_to_keep = $config_ref->{backups}{$backup}{keep};

    # There is 1 more backup than should be kept because we just
    # performed a backup.
    if ($num_backups == $num_to_keep + 1) {

	# pop takes from the end of the array. This is the oldest backup
	# because they are sorted newest to oldest.
	my $oldest_backup = pop @existing_backups;

	system("btrfs subvol delete $oldest_backup");

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
            
	    system("btrfs subvol delete $oldest_backup");

	    $num_backups--;
	}

	return;
    }
}

sub delete_old_backups_ssh { # No test. Is not pure.

    # Delete old backup snapshot(s) at the remote host connected to by
    # $ssh. We know how many backups to keep based off $backup's $keep
    # setting defined in the users config. This function should be
    # called directly after do_backup_ssh().

    my $config_ref = shift // confess missing_arg();
    my $ssh        = shift // confess missing_arg();
    my $backup     = shift // confess missing_arg();

    my $remote_backup_dir = $config_ref->{backups}{$backup}{backup_dir}; 

    my @existing_backups = all_snapshots($config_ref, $backup);

    my $num_backups = scalar @existing_backups;

    my $num_to_keep = $config_ref->{backups}{$backup}{keep};

    # There is 1 more backup than should be kept because we just
    # performed a backup.
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
            
	    $ssh->system("sudo -n btrfs subvol delete $oldest_backup");

	    $num_backups--;
	} 

	return;
    }
}


sub all_snapshots { # No test. Is not pure.

    # Gather all snapshots (full paths) of $subject and return them
    # sorted from newest to oldest. $subject can be any user defined
    # subvol or backup. If $subject is a subvol it may make sense to
    # only want snapshots from certain timeframes which can be passed
    # as the >=3'rd arguments.

    my $config_ref = shift // confess missing_arg();
    my $subject    = shift // confess missing_arg();
    my @timeframes = @_;

    my @all_snaps; # return this

    if (is_subvol($config_ref, $subject)) {
	
	my $subvol = $subject;

	# default to all timeframes
	if (not @timeframes) {
	    @timeframes = qw(5minute hourly midnight monthly);
	}
	
	foreach my $tf (@timeframes) {
	    
	    my $snap_dir = local_yabsm_dir($config_ref, $subvol, $tf);
	    
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
    
    # return the snapshots sorted newest to oldest
    my $snaps_sorted_ref = sort_snaps(\@all_snaps);

    return wantarray ? @$snaps_sorted_ref : $snaps_sorted_ref;
}

sub initialize_directories { # No test. Is not pure.

    # This subroutine is called before yabsm commands that work on the
    # local filesystem so the rest of the program can be sure all
    # neccesary dirs exist. Remote directories are not initialized
    # because it is too expensive to arbitrarily establish an ssh
    # connection.

    my $config_ref = shift // confess missing_arg();

    my $yabsm_root_dir = local_yabsm_dir($config_ref);

    if (not -d $yabsm_root_dir) {
	make_path($yabsm_root_dir);
    }

    # .tmp dir holds backup snapshots before they are 'btrfs send'ed
    if (not -d $yabsm_root_dir . '/.tmp') {
	make_path($yabsm_root_dir . '/.tmp');
    }

    foreach my $subvol (all_subvols($config_ref)) {

	my $subvol_dir = local_yabsm_dir($config_ref, $subvol);

	if (not -d $subvol_dir) {
	    make_path($subvol_dir);
	}

        # we enforce that the user defines all of these fields
        # to either 'yes' or 'no'.
	my $_5minute_want = $config_ref->{subvols}{$subvol}{'5minute_want'};
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

	# all the backups that are backing up $subvol
	foreach my $backup (all_backups_of_subvol($config_ref, $subvol)) {

            my $bootstrap_snap_dir = bootstrap_snap_dir($config_ref, $backup);

	    if (not -d $bootstrap_snap_dir) {
		make_path($bootstrap_snap_dir);
	    }

	    if (is_local_backup($config_ref, $backup)) {
		my $backup_dir = $config_ref->{backups}{$backup}{backup_dir};
		if (not -d $backup_dir) {
		    make_path($backup_dir);
		}
	    }

	    # if (is_remote_backup($config_ref, $backup)) {
	    #   ... too expensive to open an ssh connection arbitrarily.
            #   Any subroutine dealing with remote paths is gonna have
            #   to perform sanity checking itself.
	    # }
	}
    }
    
    return;
}

sub local_yabsm_dir { # Has test. Is pure.

    # Return the local directory path for yabsm snapshots. The $subvol
    # and $timeframe arguments are optional. Note that we do not check
    # check that $subvol and $timeframe are a valid subvol/timeframe.

    my $config_ref = shift // confess missing_arg();
    my $subvol     = shift; # optional
    my $timeframe  = shift; # optional

    my $yabsm_dir = $config_ref->{misc}{yabsm_dir};

    if (defined $subvol) {
	$yabsm_dir .= "/$subvol";
	if (defined $timeframe) { 
	    $yabsm_dir .= "/$timeframe";
	}
    }

    return $yabsm_dir;
}

sub bootstrap_snap_dir { # Has test. Is pure.

    # Return the path of the directory holding the bootstrap snapshot for
    # $backup. The bootstrap snapshot is used for btrfs incremental backups.

    my $config_ref = shift // confess missing_arg();
    my $backup     = shift // confess missing_arg();

    my $subvol = $config_ref->{backups}{$backup}{subvol};

    my $yabsm_root_dir = local_yabsm_dir($config_ref);

    return "$yabsm_root_dir/.cache/$subvol/backups/$backup/bootstrap-snap";
}

sub is_snapstring { # Has test. Is pure.

    # Return 1 iff $snapstring is a valid snapstring. Works on
    # absolute paths as well as plain snapstrings.

    my $snapstring = shift // confess missing_arg();

    return $snapstring =~ /day=\d{4}_\d{2}_\d{2},time=\d{2}:\d{2}$/;
}

sub current_time_snapstring { # No test. Is not pure.
    
    # Return a snapstring of the current time.
    
    my ($min, $hr, $day, $mon, $yr) =
      map { sprintf '%02d', $_ } (localtime)[1..5]; 
    
    $mon++;      # month count starts at zero. 
    $yr += 1900; # year represents years since 1900. 
    
    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

sub n_units_ago_snapstring { # Has test. Is not pure.

    # Return a snapstring of the time $n $unit's ago from the current
    # time. The unit can be minutes, hours or days.
   
    my $n    = shift // confess missing_arg();
    my $unit = shift // confess missing_arg();

    # Can add/subtract by seconds with Time::Piece objects.

    my $seconds_per_unit;

    if    ($unit =~ /^(minutes|mins|m)$/) { $seconds_per_unit = 60    }
    elsif ($unit =~ /^(hours|hrs|h)$/   ) { $seconds_per_unit = 3600  }
    elsif ($unit =~ /^(days|d)$/        ) { $seconds_per_unit = 86400 }
    else  { confess "internal error: '$unit' is not a valid time unit" }

    my $current_time = current_time_snapstring();

    my $time_piece_obj = snapstring_to_time_piece_obj($current_time);

    $time_piece_obj -= ($n * $seconds_per_unit);

    return time_piece_obj_to_snapstring($time_piece_obj);
}

sub is_immediate { # Has test. Is pure.

    # An immediate is either a literal time or a relative time.

    my $imm = shift // confess missing_arg();
    
    return is_literal_time($imm) || is_relative_time($imm);
}

sub is_literal_time { # Has test. Is pure.

    # Literal times can come in one of 5 different forms. 

    my $lit_time = shift // confess missing_arg();

    # yr-mon-day-hr-min
    my $re1 = qr/^\d{4}-\d{1,2}-\d{1,2}-\d{1,2}-\d{1,2}$/;
    # yr-mon-day
    my $re2 = qr/^\d{4}-\d{1,2}-\d{1,2}$/;
    # mon-day
    my $re3 = qr/^\d{1,2}-\d{1,2}$/;
    # mon-day-hr
    my $re4 = qr/^\d{1,2}-\d{1,2}-\d{1,2}$/;
    # mon-day-hr-min
    my $re5 = qr/^\d{1,2}-\d{1,2}-\d{1,2}-\d{1,2}$/;

    return any { $lit_time =~ $_ } ($re1, $re2, $re3, $re4, $re5);
}

sub is_relative_time { # Has test. Is pure.

    # Relative times take the form of 'back-amount-unit'.
    # 'back' can be abbreviated to 'b'.
    # The amount field must be a whole number.
    # The unit field must be a time unit like 'minutes', 'hours', or 'days'.

    my $rel_time = shift // confess missing_arg();

    my ($back, $amount, $unit) = split '-', $rel_time, 3;

    return 0 if any { not defined } ($back, $amount, $unit);

    my $back_correct = $back =~ /^b(ack)?$/;

    my $amount_correct = $amount =~ /^\d+$/;
    
    my $unit_correct = any { $_ eq $unit } qw(minutes mins m hours hrs h days d);
    
    return $back_correct && $amount_correct && $unit_correct;
}


sub immediate_to_snapstring { # No test. Is pure. 

    # Resolve an immediate to a snapstring.

    my $imm = shift // confess missing_arg();

    if (is_literal_time($imm)) {
	return literal_time_to_snapstring($imm);
    }

    if (is_relative_time($imm)) {
	return relative_time_to_snapstring($imm);
    }

    # input should have already been cleansed. 
    confess "internal error: '$imm' is not an immediate";
}

sub literal_time_to_snapstring { # Has test. Is pure.

    # Resolve a literal time to a snapstring.

    my $lit_time = shift // confess missing_arg();

    # literal time forms
    my $yr_mon_day_hr_min = qr/^(\d{4})-(\d{1,2})-(\d{1,2})-(\d{1,2})-(\d{1,2})$/;
    my $yr_mon_day        = qr/^(\d{4})-(\d{1,2})-(\d{1,2})$/;
    my $mon_day           = qr/^(\d{1,2})-(\d{1,2})$/;
    my $mon_day_hr        = qr/^(\d{1,2})-(\d{1,2})-(\d{1,2})$/;
    my $mon_day_hr_min    = qr/^(\d{1,2})-(\d{1,2})-(\d{1,2})-(\d{1,2})$/;

    if ($lit_time =~ $yr_mon_day_hr_min) {
	return nums_to_snapstring($1, $2, $3, $4, $5);
    }

    if ($lit_time =~ $yr_mon_day) {
	return nums_to_snapstring($1, $2, $3, 0, 0);
    }

    if ($lit_time =~ $mon_day) {
	my $t = localtime;
	return nums_to_snapstring($t->year, $1, $2, 0, 0);
    }

    if ($lit_time =~ $mon_day_hr) {
	my $t = localtime;
	return nums_to_snapstring($t->year, $1, $2, $3, 0);
    }

    if ($lit_time =~ $mon_day_hr_min) {
	my $t = localtime;
	return nums_to_snapstring($t->year, $1, $2, $3, $4);
    }

    # input should have already been cleansed. 
    confess "internal error: '$lit_time' is not a valid literal time";
}

sub relative_time_to_snapstring { # Has test. Is not pure.

    # Resolve a relative time to a snapstring.

    my $rel_time = shift // confess missing_arg();

    my (undef, $amount, $unit) = split '-', $rel_time, 3;

    my $n_units_ago_snapstring = n_units_ago_snapstring($amount, $unit);

    return $n_units_ago_snapstring; 
}

sub snapstring_to_nums { # Has test. Is pure.

    # Take a snapshot name string and return an array containing in
    # order the year, month, day, hour, and minute. This works with
    # both a full path and just a snapshot name string.

    my $snap = shift // confess missing_arg();

    my @nums = $snap =~ /day=(\d{4})_(\d{2})_(\d{2}),time=(\d{2}):(\d{2})$/;

    return wantarray ? @nums : \@nums;
}

sub nums_to_snapstring { # Has test. Is pure.

    # Take 5 integer arguments representing in order the year, month,
    # day, hour, and minute and return the corresponding snapstring.

    my ($yr, $mon, $day, $hr, $min) = map { sprintf '%02d', $_ } @_;

    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

sub snapstring_to_time_piece_obj { # Has test. Is pure.

    # Turn a snapshot name string into a Time::Peice object. This is
    # useful because we can do time arithmetic on these objects.

    my $snap = shift // confess missing_arg();

    my ($yr, $mon, $day, $hr, $min) = snapstring_to_nums($snap);

    return Time::Piece->strptime("$yr/$mon/$day/$hr/$min",'%Y/%m/%d/%H/%M');
}

sub time_piece_obj_to_snapstring { # Has test. Is pure.

    # Turn a Time::Piece object into a snapshot name string.

    my $time_piece_obj = shift // confess missing_arg();

    my $yr  = $time_piece_obj->year;
    my $mon = $time_piece_obj->mon;
    my $day = $time_piece_obj->mday;
    my $hr  = $time_piece_obj->hour;
    my $min = $time_piece_obj->min;

    return nums_to_snapstring($yr, $mon, $day, $hr, $min);
}

sub sort_snaps { # Has test. Is pure.

    # Return a sorted version of the inputted snapshot array ref.
    # The snapshots will be returned newest to oldest. Works with
    # plain snapstrings and full paths.

    my $snaps_ref = shift // confess missing_arg();

    my @sorted_snaps = sort { cmp_snaps($a, $b) } @$snaps_ref;

    return wantarray ? @sorted_snaps : \@sorted_snaps;
}

sub cmp_snaps { # Has test. Is pure.

    # Return -1 if $snap1 is newer than $snap2.
    # Return 1 if $snap1 is older than $snap2
    # Return 0 if $snap1 and $snap2 are the same. 
    # Works with both plain snapstrings and full paths.

    my $snap1 = shift // confess missing_arg();
    my $snap2 = shift // confess missing_arg();

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

sub snap_closest_to { # Has test. Is pure.

    # Return the snapshot from $all_snaps_ref that is closest to
    # $target_snap. $all_snaps_ref should be sorted from newest to
    # oldest.

    my $all_snaps_ref = shift // confess missing_arg();
    my $target_snap   = shift // confess missing_arg();

    my $snap;

    for (my $i = 0; $i <= $#{ $all_snaps_ref }; $i++) {
	
	my $this_snap = $all_snaps_ref->[$i];

	my $cmp = cmp_snaps($this_snap, $target_snap);
	
	# if $this_snap is the same as $target_snap
	if ($cmp == 0) {
	    $snap = $this_snap;
	    last;
	}

	# if $this_snap is older than $target_snap
	if ($cmp == 1) {
	    if ($i == 0) { # No previous snap. This is as close as were getting.
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

    my $target_snap = shift // confess missing_arg();
    my $snap1       = shift // confess missing_arg();
    my $snap2       = shift // confess missing_arg();

    my $target_epoch = snapstring_to_time_piece_obj($target_snap)->epoch;
    my $snap1_epoch  = snapstring_to_time_piece_obj($snap1)->epoch;
    my $snap2_epoch  = snapstring_to_time_piece_obj($snap2)->epoch;

    my $v1 = abs($target_epoch - $snap1_epoch);
    my $v2 = abs($target_epoch - $snap2_epoch);

    if ($v1 <= $v2) { return $snap1 }
    else            { return $snap2 }
}

sub snaps_newer_than { # Has test. Is pure.

    # Return all the snapshots from $all_snaps_ref that are newer than
    # $target_snap. We assume that $all_snaps_ref is sorted from
    # newest to oldest.

    my $all_snaps_ref = shift // confess missing_arg();
    my $target_snap   = shift // confess missing_arg();

    my @newer = ();

    for (my $i = 0; $i <= $#{ $all_snaps_ref }; $i++) {

	my $this_snap = $all_snaps_ref->[$i];

	my $cmp = cmp_snaps($this_snap, $target_snap);  

	# if $this_snap is newer than $target_snap
	if ($cmp == -1) {
	    push @newer, $this_snap;
	}
	else { last }
    }

    return wantarray ? @newer : \@newer;
}

sub snaps_older_than { # Has test. Is pure.

    # Return all the snapshots that are older than $target_snap.

    my $all_snaps_ref = shift // confess missing_arg();
    my $target_snap   = shift // confess missing_arg();

    my @older = ();
    
    my $last_idx = $#{ $all_snaps_ref };

    for (my $i = 0; $i <= $last_idx; $i++) {

	my $this_snap = $all_snaps_ref->[$i];

	my $cmp = cmp_snaps($this_snap, $target_snap);  

	# if $this_snap is older than $target_snap
	if ($cmp == 1) {
	    @older = @$all_snaps_ref[$i .. $last_idx];
	    last;
	}
    }

    return wantarray ? @older : \@older;
}

sub snaps_between { # Has test. Is pure.

    # Return all of the snapshots between (inclusive) $target_snap1
    # and $target_snap2. Remember that $all_snaps_ref is sorted
    # newest to oldest.

    my $all_snaps_ref = shift // confess missing_arg();
    my $target_snap1  = shift // confess missing_arg();
    my $target_snap2  = shift // confess missing_arg();

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

	# if $this_snap is older or equal to the $newer
	if ($cmp == 1 || $cmp == 0) {

	    # between (inclusive)
	    push @snaps_between, $this_snap if $cmp == 0;
	    
	    for (my $j = $i+1; $j <= $last_idx; $j++) {

		my $this_snap = $all_snaps_ref->[$j];

		my $cmp = cmp_snaps($this_snap, $older);

		# if $this_snap is older than or equal to $older
		if ($cmp == 1 || $cmp == 0) {

		    # between (inclusive)
		    push @snaps_between, $this_snap if $cmp == 0;

		    # Were done. Break the inner loop. The outer loop
		    # will be broken as well.
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

    # $ref can be either an array ref to an array of sorted snapshots,
    # or a reference to the users config. If $ref is a ref to the
    # config this is because the caller wants to get the newest
    # snapshot of some subvol/backup, and thus will require an extra
    # argument denoting the desired subvol/backup.

    my $ref    = shift // confess missing_arg();
    my $subvol = shift; # only needed if $ref is $config_ref

    my $ref_type = ref($ref);

    if ($ref_type eq 'ARRAY') {
	return $ref->[0]
    }

    if ($ref_type eq 'HASH') {
	my $all_snaps_ref = all_snapshots($ref, $subvol);
	return $all_snaps_ref->[0];
    }

    confess "internal error: '$ref' has ref type '$ref_type'";
}

sub oldest_snap { # Has test. Is not pure.

    # $ref can be either an array ref to an array of sorted snapshots,
    # or a reference to the users config. If $ref is a ref to the
    # config this is because the caller wants to get the oldest
    # snapshot of some subvol/backup, and thus will require an extra
    # argument denoting the desired subvol/backup.
    
    my $ref = shift // confess missing_arg();

    my $ref_type = ref($ref);

    if ($ref_type eq 'ARRAY') {
	return $ref->[-1];
    }

    if ($ref_type eq 'HASH') {
	my $subject = shift // confess missing_arg();
	my $all_snaps_ref = all_snapshots($ref, $subject);
	return $all_snaps_ref->[-1];
    }
    
    confess "internal error: '$ref' has ref type '$ref_type'";
}

sub answer_query { # No test. Is not pure.

    # Answers $query to find the appropiate snapshot(s) of
    # $subject. We expect that $query has already been
    # validated. $subject can either be a defined subvol or a backup.

    my $config_ref = shift // confess missing_arg();
    my $subject    = shift // confess missing_arg();
    my $query      = shift // confess missing_arg();

    my $all_snaps_ref = all_snapshots($config_ref, $subject);

    my @snaps_to_return;

    if ($query eq 'all') {
	
	# return all the snaps

	@snaps_to_return = @$all_snaps_ref;
    }

    elsif ($query eq 'newest') {

	# return just the newest snap

	my $snap = newest_snap($all_snaps_ref);

	@snaps_to_return = ($snap);
    }

    elsif ($query eq 'oldest') {

	# return just the oldest snap

	my $snap = oldest_snap($all_snaps_ref);

	@snaps_to_return = ($snap);
    }

    elsif (is_immediate($query)) {

	# return the one snap closest to the time denoted by the immediate.

	my $target = immediate_to_snapstring($query); 

	my $snap = snap_closest_to($all_snaps_ref, $target);

	@snaps_to_return = ($snap);
    }

    elsif (is_newer_than_query($query)) {

	my (undef, $imm) = split /\s/, $query, 2;

	my $target = immediate_to_snapstring($imm);

	@snaps_to_return = snaps_newer_than($all_snaps_ref, $target);
    }

    elsif (is_older_than_query($query)) {

	my (undef, $imm) = split /\s/, $query, 2;

	my $target = immediate_to_snapstring($imm);

	@snaps_to_return = snaps_older_than($all_snaps_ref, $target);
    }

    elsif (is_between_query($query)) {

	my (undef, $imm1, $imm2) = split /\s/, $query, 3;

	my $target1 = immediate_to_snapstring($imm1);

	my $target2 = immediate_to_snapstring($imm2);

	@snaps_to_return = snaps_between($all_snaps_ref, $target1, $target2);
    }

    else { # input should have already been cleansed
	confess "internal error: '$query' is not a valid query";
    }

    return wantarray ? @snaps_to_return : \@snaps_to_return;
}

sub is_valid_query { # Has test. Is pure.

    # True iff $query is a valid query. Used to validate 
    # user input query for 'yabsm --find'.

    my $query = shift // confess missing_arg();

    if ($query eq 'all')             { return 1 }
    if ($query eq 'newest')          { return 1 }
    if ($query eq 'oldest')          { return 1 }
    if (is_immediate($query))        { return 1 }
    if (is_newer_than_query($query)) { return 1 }
    if (is_older_than_query($query)) { return 1 }
    if (is_between_query($query))    { return 1 }

    return 0;
}

sub is_newer_than_query { # Has test. Is pure.

    # Return 1 iff $query is a syntactically valid newer_than query.
    # A newer_than query returns all snapshots newer than some
    # immediate.  A newer_than query can be denoted by one of the
    # keywords 'newer', 'after', or 'aft'. A newer_than query takes
    # exactly one immediate as an argument.

    my $query = shift // confess missing_arg();

    my ($keyword, $imm) = split /\s/, $query, 2;

    return 0 if any { not defined } ($keyword, $imm);

    my $keyword_correct = $keyword =~ /^(newer|after|aft)$/;

    my $imm_correct = is_immediate($imm);

    return $keyword_correct && $imm_correct;
}

sub is_older_than_query { # Has test. Is pure.

    # Return 1 iff $query is a syntactically valid older_than query.
    # An older_than query returns all snapshots older than some
    # immediate. A older_than query can be denoted by one of the
    # keywords 'older', 'before', or 'bef'. An older_than query takes
    # exactly one immediate as an argument.

    my $query = shift // confess missing_arg();

    my ($keyword, $imm) = split /\s/, $query, 2;

    return 0 if any { not defined } ($keyword, $imm);

    my $keyword_correct = $keyword =~ /^(older|before|bef)$/;

    my $imm_correct = is_immediate($imm);

    return $keyword_correct && $imm_correct;
}

sub is_between_query { # Has test. Is pure.

    # Return 1 iff $query is a syntactically valid 'between' query.
    # A between query takes two immediate arguments and returns all
    # snapshots between the two immediate times. 

    my $query = shift // confess missing_arg();

    my ($keyword, $imm1, $imm2) = split /\s/, $query, 3;

    return 0 if any { not defined } ($keyword, $imm1, $imm2);

    my $keyword_correct = $keyword =~ /^bet(ween)?$/;

    my $imm1_correct = is_immediate($imm1);

    my $imm2_correct = is_immediate($imm2);

    return $keyword_correct && $imm1_correct && $imm2_correct;
}

sub all_subvol_timeframes { # Has test. Is pure.

    # Return an array of all valid subvol timeframe categories.

    my @timeframes = qw(5minute hourly midnight monthly);

    return wantarray ? @timeframes : \@timeframes;
}

sub all_backup_timeframes { # Has test. Is pure.

    # Return an array of all valid backup timeframes.

    my @timeframes = qw(hourly midnight monthly);

    return wantarray ? @timeframes : \@timeframes;
}

sub is_subvol_timeframe { # Has test. Is pure.

    # true iff $timeframe is a valid subvol timeframe category.

    my $timeframe = shift // confess missing_arg();

    return any { $_ eq $timeframe } all_subvol_timeframes();
}

sub is_backup_timeframe { # Has test. Is pure.

    # true iff $backup is a valid backup timeframe.

    my $timeframe = shift // confess missing_arg();

    return any { $_ eq $timeframe } all_backup_timeframes();
}

sub all_subvols { # Has test. Is pure.

    # Return an array of the names of every user defined subvol.

    my $config_ref = shift // confess missing_arg();

    my @subvols = sort keys %{$config_ref->{subvols}};

    return wantarray ? @subvols : \@subvols;
}

sub all_backups { # Has test. Is pure.

    # Return an array of the names of every user defined backup.

    my $config_ref = shift // confess missing_arg();

    my @backups = sort keys %{$config_ref->{backups}};

    return wantarray ? @backups : \@backups;
}

sub all_backups_of_subvol { # Has test. Is pure.

    # Return an array of all the backups that are backing up $subvol.

    my $config_ref = shift // confess missing_arg();
    my $subvol     = shift // confess missing_arg();

    my @backups = ();

    foreach my $backup (all_backups($config_ref)) {
	
	my $this_subvol = $config_ref->{backups}{$backup}{subvol};

	if ($this_subvol eq $subvol) {
	    push @backups, $backup 
	}
    }

    return wantarray ? @backups : \@backups;
}

sub is_subject { # Has test. Is pure.

    # True iff $subject is an existing user defined subject. A subject
    # is either a subvol or backup.

    my $config_ref = shift // confess missing_arg();
    my $subject    = shift // confess missing_arg();

    my $is_subvol = is_subvol($config_ref, $subject);
    my $is_backup = is_backup($config_ref, $subject);

    return $is_subvol || $is_backup;
}

sub is_subvol { # Has test. Is pure.

    # Return 1 iff $subvol is the name of a user defined subvol.
    
    my $config_ref = shift // confess missing_arg();
    my $subvol     = shift // confess missing_arg();
    
    return any { $_ eq $subvol } all_subvols($config_ref);
}

sub is_backup { # Has test. Is pure.

    # Return 1 iff $backup is the name of a user defined backup.

    my $config_ref = shift // confess missing_arg();
    my $backup     = shift // confess missing_arg();

    return any { $_ eq $backup } all_backups($config_ref);
}

sub is_remote_backup { # Has test. Is pure.

    # Return 1 iff $backup is the name of a defined local backup. A
    # local backup is one in which the backups 'remote' field is set
    # to 'yes'.

    my $config_ref = shift // confess missing_arg();
    my $backup     = shift // confess missing_arg();

    if (is_backup($config_ref, $backup)) {
	return $config_ref->{backups}{$backup}{remote} eq 'yes';
    }

    else { return 0 }
}

sub is_local_backup { # Has test. Is pure.

    # Return 1 iff $backup is the name of a defined local backup. A
    # local backup is one in which the backups 'remote' field is set
    # to 'no'.

    my $config_ref = shift // confess missing_arg();
    my $backup     = shift // confess missing_arg();

    if (is_backup($config_ref, $backup)) {
	return $config_ref->{backups}{$backup}{remote} eq 'no';
    }

    else { return 0 }
}

sub update_etc_crontab { # No test. Is not pure.
    
    # Write cronjobs to '/etc/crontab'.

    my $config_ref = shift // confess missing_arg();

    open (my $etc_crontab_fh, '<', '/etc/crontab')
      or die "internal error: failed to open file '/etc/crontab'\n";

    open (my $tmp_fh, '>', '/tmp/yabsm-update-tmp')
      or die "internal error: failed to open tmp file '/tmp/yabsm-update-tmp'\n";

    # Copy all lines from /etc/crontab into the tmp file, excluding
    # the existing yabsm cronjobs.
    while (<$etc_crontab_fh>) {

	s/\s+$//; # strip trailing whitespace

	next if /yabsm/; # don't copy the old yabsm cronjobs

	say $tmp_fh $_;
    }

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
    
    my $config_ref = shift // confess missing_arg();

    my @crons = (); # return this

    foreach my $subvol (all_subvols($config_ref)) {

	my $_5minute_want = $config_ref->{subvols}{$subvol}{'5minute_want'};
	my $hourly_want   = $config_ref->{subvols}{$subvol}{hourly_want};
	my $midnight_want = $config_ref->{subvols}{$subvol}{midnight_want};
	my $monthly_want  = $config_ref->{subvols}{$subvol}{monthly_want};
        
        my $_5minute_cron = ( '*/5 * * * * root' # every 5 minutes
			    . " yabsm take-snap $subvol 5minute"
			    ) if $_5minute_want eq 'yes';
        
        my $hourly_cron   = ( '0 */1 * * * root' # beginning of every hour
			    . " yabsm take-snap $subvol hourly"
			    ) if $hourly_want eq 'yes';
        
        my $midnight_cron = ( '59 23 * * * root' # 11:59 every night
                            . " yabsm take-snap $subvol midnight"
			    ) if $midnight_want eq 'yes';
        
        my $monthly_cron  = ( '0 0 1 * * root' # First day of every month
			    . " yabsm take-snap $subvol monthly"
			    ) if $monthly_want eq 'yes';

        push @crons, grep { defined } ($_5minute_cron, $hourly_cron, $midnight_cron, $monthly_cron);
    }

    foreach my $backup (all_backups($config_ref)) {

	my $timeframe = $config_ref->{backups}{$backup}{timeframe};

	if ($timeframe eq 'hourly') {
	    push @crons, "0 */1 * * * root yabsm incremental-backup $backup";
	}

	elsif ($timeframe eq 'midnight') {
	    push @crons, "59 23 * * * root yabsm incremental-backup $backup";
	}

	elsif ($timeframe eq 'monthly') {
	    push @crons, "0 0 1 * * root yabsm incremental-backup $backup";
	}

	else {
	    confess "internal error: backup '$backup' has invalid timeframe '$timeframe'";
	}
    }

    return wantarray ? @crons : \@crons;
}

sub new_ssh_connection { # No test. Is not pure.

    # Create and return a Net::OpenSSH connection object. Kill the
    # program if we cannot establish a connection to $remote host.

    my $remote_host = shift // confess missing_arg();

    my $ssh = Net::OpenSSH->new( $remote_host,
			       , batch_mode => 1 # Don't try asking for password
			       , timeout => 30   # timeout after 30 seconds
			       , kill_ssh_on_timeout => 1
			       );

    $ssh->error and
      die 'error: could not establish SSH connection: ' . $ssh->error . "\n";
    
    return $ssh;
}

sub test_remote_backup_config { # No test. Is not pure.

    # Test that we can connect to $backup's remote host, and run a btrfs
    # command with sudo without needing to enter any passwords.

    my $config_ref = shift // confess missing_arg();
    my $backup     = shift // confess missing_arg();

    my $remote_host = $config_ref->{backups}{$backup}{host};

    # program will die if we cannot connect to $remote_host without a password
    my $ssh = new_ssh_connection($remote_host);

    $ssh->system('sudo -n btrfs --help 1>/dev/null')
      or die "Could run btrfs as sudo without password on host '$remote_host': " . $ssh->error . "\n";

    return;
}

sub missing_arg {
    return 'internal error: subroutine missing a required arg';
}

1;