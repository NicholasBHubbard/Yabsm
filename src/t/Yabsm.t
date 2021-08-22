#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  Testing for Yabsm.pm.

use strict;
use warnings;
use 5.010;

use Test::More 'no_plan';
use Data::Dumper 'Dumper';
use Time::Piece;
use List::Util 'shuffle';

# Import Yabsm.pm
use FindBin '$Bin';
use lib "$Bin/../lib";
use Yabsm;

# Only use this to compare arrays of strings for equality.
use experimental 'smartmatch';

                 ####################################
                 #            GENERATORS            #
                 ####################################

sub gen_random_config {

    my @possible_subvols = shuffle ('root,/', 'home,/home', 'etc,/etc',
				    'var,/var', 'tmp,/tmp', 'mnt,/mnt');

    my %subvols =
      map { split /,/ } @possible_subvols[0 .. int(rand(@possible_subvols))];

    # generate the random config
    my %config = ( 'yabsm_subvols' => \%subvols
		 , 'snapshot_directory' => '/.snapshots'
		 );
    
    # dynamically add config entries for each subvolume.
    foreach (keys %subvols) {

	my ($subv_name, $path) = split /,/;

	# generate random config values

	my $hourly_want   = yes_or_no();
	my $hourly_take   = int(rand(13));
	my $hourly_keep   = int(rand(1000));

	my $daily_want    = yes_or_no();
	my $daily_take    = int(rand(25));
	my $daily_keep    = int(rand(1000));

	my $midnight_want = yes_or_no();
	my $midnight_keep = int(rand(1000));

	my $monthly_want  = yes_or_no();
	my $monthly_keep  = int(rand(1000));

	# add entries to the config

	$config{"${subv_name}_hourly_want"} = $hourly_want;
	$config{"${subv_name}_hourly_take"} = $hourly_take;
	$config{"${subv_name}_hourly_keep"} = $hourly_keep;

	$config{"${subv_name}_daily_want"} = $daily_want;
	$config{"${subv_name}_daily_take"} = $daily_take;
	$config{"${subv_name}_daily_keep"} = $daily_keep;

	$config{"${subv_name}_midnight_want"} = $midnight_want;
	$config{"${subv_name}_midnight_keep"} = $midnight_keep;

	$config{"${subv_name}_monthly_want"} = $monthly_want;
	$config{"${subv_name}_monthly_keep"} = $monthly_keep;
    }

    return wantarray ? %config : \%config;
}
  
sub gen_n_random_snap_paths {

    # Return a sorted array of $n random snapstrings.

    my ($n) = @_;

    # these potential paths align with the example config. They will
    # chosen at random, and combined with a random snapsting to help
    # generate random snapshots.
    my @potential_paths = ( '/.snapshots/yabsm/root/daily/'
			  , '/.snapshots/yabsm/root/midnight/'
			  , '/.snapshots/yabsm/root/monthly/'
			  
			  , '/.snapshots/yabsm/home/hourly/'
			  , '/.snapshots/yabsm/home/daily/'
			  , '/.snapshots/yabsm/home/midnight/'
			  , '/.snapshots/yabsm/home/monthly/'
			  
			  , '/.snapshots/yabsm/etc/hourly/'
			  , '/.snapshots/yabsm/etc/midnight/'
			  );

    my @snaps;

    for (my $i = 0; $i < $n; $i++) {

	# small year range so other fields can be tested.
	my $yr = 2020 + int(rand(5));

	my $mon = 1 + int(rand(12));

	# no need to worry about invalid days, it isn't relevant
	my $day = 1 + int(rand(30));

	my $hr = 1 + int(rand(24));

	my $min = int(rand(60));

	my $snapstring = Yabsm::nums_to_snapstring($yr, $mon, $day, $hr, $min);

	my $path = $potential_paths[ rand @potential_paths ];

	push @snaps, "${path}$snapstring";
    }

    return wantarray ? @snaps : \@snaps;
}

sub yes_or_no {

    # randomly return either the string 'yes' or 'no'

    my $rand = int(rand(2));

    if ($rand == 1) { return 'yes' }
    else            { return 'no'  }
}

                 ####################################
                 #               TESTS              #
                 ####################################

test_compare_snapshots();
sub test_compare_snapshots {
    
    my $oldest  = '/.snapshots/yabsm/home/midnight/day=2020_01_07,time=15:30';

    # same times but different paths
    my $middle1 = '/.snapshots/yabsm/root/daily/day=2020_02_07,time=15:30';
    my $middle2 = '/.snapshots/yabsm/home/midnight/day=2020_02_07,time=15:30';

    my $newest  = '/.snapshots/yabsm/root/daily/day=2020_03_07,time=15:30';

    # should be -1
    my $t1 = Yabsm::compare_snapshots($newest, $middle1);

    # should be -1
    my $t2 = Yabsm::compare_snapshots($newest, $oldest);

    # should be -1
    my $t3 = Yabsm::compare_snapshots($middle1, $oldest);

    # should be 1
    my $t4 = Yabsm::compare_snapshots($oldest, $middle1);

    # should be 1
    my $t5 = Yabsm::compare_snapshots($oldest, $newest);

    # should be 0
    my $t6 = Yabsm::compare_snapshots($middle1, $middle2);

    # should be 0
    my $t7 = Yabsm::compare_snapshots($middle2, $middle1);

    my $sum = $t1 + $t2 + $t3 + $t4 + $t5 + $t6 + $t7;;

    ok( $sum == -1, 'compare_snapshots()' );
}

test_sort_snapshots();
sub test_sort_snapshots {

    my @rand_snaps = gen_n_random_snap_paths(15);

    my @sorted_snaps = Yabsm::sort_snapshots(\@rand_snaps);

    my $is_sorted = 1;

    for my $i (0 .. $#sorted_snaps - 1) {

	my $this_snap = $sorted_snaps[$i];
	my $next_snap = $sorted_snaps[$i+1];

	my $cmp = Yabsm::compare_snapshots($this_snap, $next_snap);

	# if $this_snap is newer than $next_snap
	if ($cmp == 1) { $is_sorted = 0 }
    }
    
    ok( $is_sorted, 'sort_snapshots()' );
}

test_n_units_ago();
sub test_n_units_ago {

    my $t = localtime();

    my $mins_ago  = Yabsm::time_piece_obj_to_snapstring($t - (120 * 60));
    my $hours_ago = Yabsm::time_piece_obj_to_snapstring($t - (2 * 3600));
    my $days_ago  = Yabsm::time_piece_obj_to_snapstring($t - (2 * 86400));

    my $min         = Yabsm::n_units_ago(120, 'minutes');
    my $min_correct = $min eq $mins_ago;

    my $hr          = Yabsm::n_units_ago(2, 'hours');
    my $hr_correct  = $hr eq $hours_ago;

    my $day         = Yabsm::n_units_ago(2, 'days');
    my $day_correct = $day eq $days_ago;

    ok ( $min_correct && $hr_correct && $day_correct, 'n_units_ago()' );
}

test_nums_to_snapstring();
sub test_nums_to_snapstring {

    my $output = Yabsm::nums_to_snapstring(2020, 3, 2, 23, 15);

    ok( $output eq 'day=2020_03_02,time=23:15', 'nums_to_snapstring()' );
}

test_snapstring_to_nums();
sub test_snapstring_to_nums {

    my $time = 'day=2020_03_02,time=23:15';

    my @output = Yabsm::snapstring_to_nums($time);

    my @solution = ('2020','03','02','23','15');

    ok ( @output ~~ @solution, 'snapstring_to_nums()' );
}

test_snapstring_to_time_piece_obj();
sub test_snapstring_to_time_piece_obj {
    
    my $time = 'day=2020_03_02,time=23:15';

    my $time_piece_obj = Yabsm::snapstring_to_time_piece_obj($time);

    my $output = $time_piece_obj->year;

    ok ( $output eq '2020', 'snapstring_to_time_piece_obj()' );
}

test_time_piece_obj_to_snapstring();
sub test_time_piece_obj_to_snapstring {

    my $time_piece_obj =
      Time::Piece->strptime('2020/3/06/12/0','%Y/%m/%d/%H/%M');

    my $output = Yabsm::time_piece_obj_to_snapstring($time_piece_obj);

    ok ( $output eq 'day=2020_03_06,time=12:00'
       , 'time_piece_obj_to_snapstring()' );
}

test_snap_closest_to();
sub test_snap_closest_to {

    my $target = Yabsm::n_units_ago(34, 'hours');

    my $t0 = Yabsm::n_units_ago(0,  'hours');
    my $t1 = Yabsm::n_units_ago(10, 'hours');
    my $t2 = Yabsm::n_units_ago(20, 'hours');
    my $t3 = Yabsm::n_units_ago(30, 'hours');
    my $t4 = Yabsm::n_units_ago(40, 'hours');
    my $t5 = Yabsm::n_units_ago(50, 'hours');

    my @all_snaps = ($t0, $t1, $t2, $t3, $t4, $t5);

    my $output = Yabsm::snap_closest_to($target, \@all_snaps);

    ok ( $output eq $t4, 'snap_closest_to()' );
}

test_is_valid_query();
sub test_is_valid_query {

    # these should all be true
    my $t0 = Yabsm::is_valid_query('b 52 m');
    my $t1 = Yabsm::is_valid_query('back-8-mins');
    my $t2 = Yabsm::is_valid_query('back 4 minutes');
    my $t3 = Yabsm::is_valid_query('back-92-h');
    my $t4 = Yabsm::is_valid_query('b-4-hrs');
    my $t5 = Yabsm::is_valid_query('b 400 hours');
    my $t6 = Yabsm::is_valid_query('2020-2-3-12-30');
    my $t7 = Yabsm::is_valid_query('2020 02 03 12 30');
    my $t8 = Yabsm::is_valid_query('b 2 d');
    my $t9 = Yabsm::is_valid_query('b 80 days ');

    # these should all be false
    my $f0 = Yabsm::is_valid_query('');
    my $f1 = Yabsm::is_valid_query('WRONG 4 mins');
    my $f2 = Yabsm::is_valid_query('b-WRONG-m');
    my $f3 = Yabsm::is_valid_query('back_90_m');
    my $f4 = Yabsm::is_valid_query('back 8');
    my $f5 = Yabsm::is_valid_query('2020-12-25-12');
    my $f6 = Yabsm::is_valid_query('202-12-25-5-13');
    my $f7 = Yabsm::is_valid_query('b 4    m');
    my $f8 = Yabsm::is_valid_query('b 4 hourss');

    my $trues  = ($t0 && $t2 && $t4 && $t5 && $t6 && $t7 && $t8 && $t9);
    my $falses = ! ($f0 || $f1 || $f2 || $f3 || $f4 || $f5 || $f6 || $f7 || $f8);

    ok ( $trues && $falses, 'is_valid_query()' );
}

test_is_subvol();
sub test_is_subvol {

    my %config = gen_random_config();

    my $subvols_ref = $config{yabsm_subvols};

    # Yabsm::is_subvol() should return true for all subvols
    my $detected = 1;
    foreach my $subv (keys %$subvols_ref) {
	$detected = 0 unless Yabsm::is_subvol(\%config, $subv);
    }

    # should fail
    my $fail = 1;
    $fail = 0 if Yabsm::is_subvol(\%config, 'this is an invalid subvol name');

    ok ( $detected && $fail, 'is_subvol()' );
}

test_is_literal_time();
sub test_is_literal_time {
    
    # These should be true
    my $t1 = Yabsm::is_literal_time('2020-12-25-13-40');
    my $t2 = Yabsm::is_literal_time('2020 12 25 13 40');
    my $t3 = Yabsm::is_literal_time('2020 1 2 3 4');
    
    # These should be false
    my $f1 = Yabsm::is_literal_time('202-12-25-12-30');
    my $f2 = Yabsm::is_literal_time('2020  12  30  12  30');
    my $f3 = Yabsm::is_literal_time('2020  12  30  12  30');

    my $trues  = ($t1 && $t2 && $t3);
    my $falses = not ($f1 || $f2 || $f3);

    ok ( $trues && $falses, 'is_literal_time()' );
}

test_is_relative_query();
sub test_is_relative_query {

    # these should all be true
    my $t0 = Yabsm::is_relative_query('b 4 m');
    my $t1 = Yabsm::is_relative_query('back-4-mins');
    my $t2 = Yabsm::is_relative_query('back 100 minutes');
    my $t3 = Yabsm::is_relative_query('b-400-h');
    my $t4 = Yabsm::is_relative_query('b-10-hrs');
    my $t5 = Yabsm::is_relative_query('b-400-hours');
    my $t6 = Yabsm::is_relative_query('b-400-d');
    my $t7 = Yabsm::is_relative_query('b 12 days');

    # these should all be false
    my $f0 = Yabsm::is_relative_query('');
    my $f1 = Yabsm::is_relative_query('WRONG 4 m');
    my $f2 = Yabsm::is_relative_query('b-WRONG-m');
    my $f3 = Yabsm::is_relative_query('b-4-WRONG');
    my $f4 = Yabsm::is_relative_query('back 5');
    my $f5 = Yabsm::is_relative_query('2020-12-25-12-20');
    my $f6 = Yabsm::is_relative_query('b -12 hours');
    my $f7 = Yabsm::is_relative_query('back  4  m');
    my $f8 = Yabsm::is_relative_query('b 4 dayss');

    my $trues  = $t0 && $t1 && $t2 && $t3 && $t4 && $t5 && $t6 && $t7;
    my $falses = not ($f0 || $f1 || $f2 || $f3 || $f4 || $f5 || $f6 || $f7 || $f8);

    ok ( $trues && $falses, 'is_relative_query()' );
}

test_current_time_string();
sub test_current_time_string {

    my $ct = Yabsm::current_time_string();

    my $test = $ct =~ /^day=\d{4}_\d{2}_\d{2},time=\d{2}:\d{2}$/;

    ok ( $test, 'current_time_string()' );
}

test_target_dir();
sub test_target_dir {

    my %config = gen_random_config();

    my $snapshot_root_dir = $config{snapshot_directory};
    my $subvol = $config{(keys %config)[rand keys %config]};

    my $target_dir = Yabsm::target_dir(\%config, $subvol, 'hourly');

    my $expected = "$snapshot_root_dir/yabsm/$subvol/hourly";

    ok ( $expected eq $target_dir, 'target_dir()' );
}
