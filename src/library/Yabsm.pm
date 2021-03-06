#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  Functions used in yabsm-show.pl.

package Yabsm;

use strict;
use warnings;

use Time::Piece;
use Time::Seconds;

                 ####################################
                 #             GATHERING            #
                 ####################################

sub all_snapshots {

    my ($yabsm_subvol, $timeframe) = @_;

    # First figure out our target directory. '/.snapshots/yabsm/home'

    open (my $yabsmrc, '<', '/etc/yabsmrc')
      or die '[!] failed to open file /etc/yabsmrc';

    # $target_dir should look like '/.snapshots/yabsm/home'
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

    return glob "$target_dir/*";
}
    
                 ####################################
                 #           DATA CONVERSION        #
                 ####################################

sub snap_to_nums {

    # This works with both a full path and just a snap name.

    my $snap = shift;

    return $snap =~ m{day=(\d{4})_(\d{2})_(\d{2}),time=(\d{2}):(\d{2})};
}

sub nums_to_snap {

    my ($yr, $mon, $day, $hr, $min) = map { sprintf '%02d', $_ } @_;

    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

sub snap_to_time_obj {

    my $snap = shift;

    my ($yr, $mon, $day, $hr, $min) = snap_to_nums($snap);

    return Time::Piece->strptime("$yr/$mon/$day/$hr/$min",'%Y/%m/%d/%H/%M');
}

sub time_obj_to_snap {

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

    my @snap_nums1 = snap_to_nums(shift);
    my @snap_nums2 = snap_to_nums(shift);

    # Take the lexical order. We know the arrays are equal length.
    for (my $i = 0; $i < scalar @snap_nums1; $i++) {

	return 1 if $snap_nums1[$i] > $snap_nums2[$i]; 
	return 0 if $snap_nums1[$i] < $snap_nums2[$i];
    }
    return 0; # The arrays must have been equivalent.
}

sub snap_earlier { 

    my @snap_nums1 = snap_to_nums(shift);
    my @snap_nums2 = snap_to_nums(shift);

    # Take the lexical order. We know the arrays are equal length.
    for (my $i = 0; $i < scalar @snap_nums1; $i++) {

	return 1 if $snap_nums1[$i] < $snap_nums2[$i]; 
	return 0 if $snap_nums1[$i] > $snap_nums2[$i];
    }
    return 0; # The arrays must have been equivalent.
}

sub snap_equal { 

    my @snap_nums1 = snap_to_nums(shift);
    my @snap_nums2 = snap_to_nums(shift);

    for (my $i = 0; $i < scalar @snap_nums1; $i++) {

	return 0 if $snap_nums1[$i] != $snap_nums2[$i];
    }
    return 1;
}

sub latest_snap {

    my @snapshots = {$_[0]};

    # Shift out a snapshot to get things rolling.
    my $latest_snap = shift @snapshots;
    
    foreach my $snap (@snapshots) {
        $latest_snap = $snap if snap_later($snap, $latest_snap);
    }
    return $latest_snap;
}

sub earliest_snap {

    my @snapshots = @{$_[0]};

    # Shift out a snapshot to get things rolling.
    my $earliest_snap = shift @snapshots;
    
    foreach my $snap (@snapshots) {
        $earliest_snap = $snap if snap_earlier($snap, $earliest_snap);
    }
    return $earliest_snap;
}

sub sort_snapshots {

    # Sort an array of snapshots from newest to latest with quicksort algorithm.

    my @snapshots = @{$_[0]};

    # base case
    if (scalar @snapshots < 1) { return @snapshots }

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

sub add_n_hours {

    my ($snap, $n) = @_;

    my $time_obj = snap_to_time_obj($snap);

    for (my $i = 0; $i < $n; $i++) {

	$time_obj += ONE_HOUR;
    }
    return time_obj_to_snap($time_obj);
}
      
sub subtract_n_hours {

    my ($snap, $n) = @_;

    my $time_obj = snap_to_time_obj($snap);

    for (my $i = 0; $i < $n; $i++) {

	$time_obj -= ONE_HOUR;
    }
    return time_obj_to_snap($time_obj);
}
      
sub add_n_minutes {

    my ($snap, $n) = @_;

    my $time_obj = snap_to_time_obj($snap) + ($n * 60);

    return time_obj_to_snap($time_obj);
}

sub subtract_n_minutes {

    my ($snap, $n) = @_;

    my $time_obj = snap_to_time_obj($snap) - ($n * 60);

    return time_obj_to_snap($time_obj);
}

1;
