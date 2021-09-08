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

    my @possible_subvols = shuffle ('root', 'home', 'etc', 'var', 'tmp', 'mnt');
    my @possible_mountpoints = shuffle ('/', '/home', '/etc', '/var', '/tmp', '/mnt');

    my @subvols = @possible_subvols[0 .. int(rand(@possible_subvols))];

    # generate the random config
    my %config; 

    $config{misc}{snapshot_directory} = '/.snapshots';
    
    # dynamically add config entries for each subvolume.
    foreach my $subvol (@subvols) {

	# generate random config values

	my $mountpoint = pop @possible_mountpoints;

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

	$config{subvols}{$subvol}{mountpoint} = $mountpoint;

	$config{subvols}{$subvol}{hourly_want} = $hourly_want;
	$config{subvols}{$subvol}{hourly_take} = $hourly_take;
	$config{subvols}{$subvol}{hourly_keep} = $hourly_keep;

	$config{subvols}{$subvol}{daily_want} = $daily_want;
	$config{subvols}{$subvol}{daily_take} = $daily_take;
	$config{subvols}{$subvol}{daily_keep} = $daily_keep;

	$config{subvols}{$subvol}{midnight_want} = $midnight_want;
	$config{subvols}{$subvol}{midnight_keep} = $midnight_keep;

	$config{subvols}{$subvol}{monthly_want} = $monthly_want;
	$config{subvols}{$subvol}{monthly_keep} = $monthly_keep;
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

test_cmp_snaps();
sub test_cmp_snaps {
    
    my $oldest  = '/.snapshots/yabsm/home/midnight/day=2020_01_07,time=15:30';

    # same times but different paths
    my $middle1 = '/.snapshots/yabsm/root/daily/day=2020_02_07,time=15:30';
    my $middle2 = '/.snapshots/yabsm/home/midnight/day=2020_02_07,time=15:30';

    my $newest  = '/.snapshots/yabsm/root/daily/day=2020_03_07,time=15:30';

    # should be -1
    my $t1 = Yabsm::cmp_snaps($newest, $middle1);

    # should be -1
    my $t2 = Yabsm::cmp_snaps($newest, $oldest);

    # should be -1
    my $t3 = Yabsm::cmp_snaps($middle1, $oldest);

    # should be 1
    my $t4 = Yabsm::cmp_snaps($oldest, $middle1);

    # should be 1
    my $t5 = Yabsm::cmp_snaps($oldest, $newest);

    # should be 0
    my $t6 = Yabsm::cmp_snaps($middle1, $middle2);

    # should be 0
    my $t7 = Yabsm::cmp_snaps($middle2, $middle1);

    my $sum = $t1 + $t2 + $t3 + $t4 + $t5 + $t6 + $t7;;

    ok( $sum == -1, 'cmp_snaps()' );
}

test_sort_snapshots();
sub test_sort_snapshots {

    # TEST 1

    my @rand_snaps1 = gen_n_random_snap_paths(15);

    my @sorted_snaps1 = Yabsm::sort_snapshots(\@rand_snaps1);

    my $correct = 1;
    for my $i (0 .. $#sorted_snaps1 - 1) {

	my $this_snap = $sorted_snaps1[$i];
	my $next_snap = $sorted_snaps1[$i+1];

	my $cmp = Yabsm::cmp_snaps($this_snap, $next_snap);

	# if $this_snap is newer than $next_snap
	if ($cmp == 1) { $correct = 0 }
    }
    
    ok( $correct, 'sort_snapshots()' );
}

test_n_units_ago_snapstring();
sub test_n_units_ago_snapstring {

    my $t = localtime();

    my $mins_ago  = Yabsm::time_piece_obj_to_snapstring($t - (120 * 60));
    my $hours_ago = Yabsm::time_piece_obj_to_snapstring($t - (2 * 3600));
    my $days_ago  = Yabsm::time_piece_obj_to_snapstring($t - (2 * 86400));

    my $min         = Yabsm::n_units_ago_snapstring(120, 'minutes');
    my $min_correct = $min eq $mins_ago;

    my $hr          = Yabsm::n_units_ago_snapstring(2, 'hours');
    my $hr_correct  = $hr eq $hours_ago;

    my $day         = Yabsm::n_units_ago_snapstring(2, 'days');
    my $day_correct = $day eq $days_ago;

    ok ( $min_correct && $hr_correct && $day_correct, 'n_units_ago_snapstring()' );
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

test_literal_time_to_snapstring();
sub test_literal_time_to_snapstring {

    my $t = localtime;
    my $cur_yr = $t->year;

    # There are 5 different literal time forms

    # yr-mon-day-hr-min
    my $form1 = '2020-12-25-1-2';
    my $sol1  = 'day=2020_12_25,time=01:02';
    my $out1  = Yabsm::literal_time_to_snapstring($form1);
    my $t1    = $out1 eq $sol1;

    # yr-mon-day
    my $form2 = '2023-12-25';
    my $sol2  = 'day=2023_12_25,time=00:00';
    my $out2  = Yabsm::literal_time_to_snapstring($form2);
    my $t2    = $out2 eq $sol2;

    # mon-day-hr
    my $form3 = '1-2-3';
    my $sol3  = "day=${cur_yr}_01_02,time=03:00";
    my $out3  = Yabsm::literal_time_to_snapstring($form3);
    my $t3    = $out3 eq $sol3;

    # mon-day-hr-min
    my $form4 = '12-25-3-30';
    my $sol4  = "day=${cur_yr}_12_25,time=03:30";
    my $out4  = Yabsm::literal_time_to_snapstring($form4);
    my $t4    = $out4 eq $sol4;
    
    # mon-day
    my $form5 = '12-25';
    my $sol5  = "day=${cur_yr}_12_25,time=00:00";
    my $out5  = Yabsm::literal_time_to_snapstring($form5);
    my $t5    = $out5 eq $sol5;

    my $correct = $t1 && $t2 && $t3 && $t4 && $t5;

    ok ( $correct, 'literal_time_to_snapstring()' );
}

test_relative_time_to_snapstring();
sub test_relative_time_to_snapstring {

    my $rel1 = 'b-4-m';
    my $rel2 = 'b-4-h';
    my $rel3 = 'b-4-d';

    # n_units_ago_snapstring() is already tested so should be safe to use
    my $out1 = Yabsm::relative_time_to_snapstring($rel1);
    my $out2 = Yabsm::relative_time_to_snapstring($rel2);
    my $out3 = Yabsm::relative_time_to_snapstring($rel3);

    my $t = localtime();
    my $sol1  = Yabsm::time_piece_obj_to_snapstring($t - (4 * 60));
    my $sol2  = Yabsm::time_piece_obj_to_snapstring($t - (4 * 3600));
    my $sol3  = Yabsm::time_piece_obj_to_snapstring($t - (4 * 86400));

    my $t1 = $out1 = $sol1;
    my $t2 = $out2 = $sol2;
    my $t3 = $out3 = $sol3;
    
    my $correct = $t1 && $t2 && $t3;

    ok ( $correct, 'relative_time_to_snapstring()' );
}

test_snap_closer();
sub test_snap_closer {

    my $target = 'day=2020_08_24,time=10:30';
    my $snap1 = 'day=2020_08_24,time=10:35';
    my $snap2 = 'day=2020_08_24,time=10:24';
    my $snap3 = 'day=2020_08_24,time=10:25';

    # TEST 1

    my $output1 = Yabsm::snap_closer($target, $snap1, $snap2);

    my $correct1 = $output1 eq $snap1;

    # TEST 2

    my $output2 = Yabsm::snap_closer($target, $target, $snap1);

    my $correct2 = $target eq $output2;

    # TEST 3

    my $output3 = Yabsm::snap_closer($target, $snap1, $target);

    my $correct3 = $target eq $output3;

    # TEST 4

    my $output4 = Yabsm::snap_closer($target, $snap1, $snap3);

    my $correct4 = $output4 eq $snap1;

    # TEST 5

    my $output5 = Yabsm::snap_closer($target, $snap3, $snap1);

    my $correct5 = $output5 eq $snap3;


    ok ( $correct1 && $correct2 && $correct3 && $correct4 && $correct5
	 , 'snap_closer()' );
}

test_snap_closest_to();
sub test_snap_closest_to {

    my $t0 = Yabsm::n_units_ago_snapstring(0,  'hours');
    my $t1 = Yabsm::n_units_ago_snapstring(10, 'hours');
    my $t2 = Yabsm::n_units_ago_snapstring(20, 'hours');
    my $t3 = Yabsm::n_units_ago_snapstring(30, 'hours');
    my $t4 = Yabsm::n_units_ago_snapstring(40, 'hours');
    my $t5 = Yabsm::n_units_ago_snapstring(50, 'hours');

    my @all_snaps = ($t0, $t1, $t2, $t3, $t4, $t5);

    # TEST 1
    my $target1 = Yabsm::n_units_ago_snapstring(34, 'hours');

    my $output1 = Yabsm::snap_closest_to(\@all_snaps, $target1);

    my $correct1 = $output1 eq $t3;


    # TEST 2

    my $target2 = Yabsm::n_units_ago_snapstring(36, 'hours');

    my $output2 = Yabsm::snap_closest_to(\@all_snaps, $target2);

    my $correct2 = $output2 eq $t4;

    # TEST 3

    # equidistant. Should return the newer one
    my $target3 = Yabsm::n_units_ago_snapstring(35, 'hours');

    my $output3 = Yabsm::snap_closest_to(\@all_snaps, $target3);

    my $correct3 = $output3 eq $t3;

    # TEST 4

    # equal to one of the snaps
    my $output4 = Yabsm::snap_closest_to(\@all_snaps, $t3);

    my $correct4 = $output4 eq $t3;

    ok ( $correct1 && $correct2 && $correct3 && $correct4, 'snap_closest_to()' );
}

test_snaps_newer();
sub test_snaps_newer {

    my $t1 = 'day=2026_08_24,time=00:00';
    my $t2 = 'day=2025_08_24,time=00:00';
    my $t3 = 'day=2024_08_24,time=00:00';
    my $t4 = 'day=2023_08_24,time=00:00';
    my $t5 = 'day=2022_08_24,time=00:00';
    my $t6 = 'day=2021_08_24,time=00:00';
    my $t7 = 'day=2020_08_24,time=00:00';

    # sorted from newest to oldest
    my @all_snaps = ($t1, $t2, $t3, $t4, $t5, $t6, $t7);

    # TEST 1

    my @snaps_newer1 = Yabsm::snaps_newer(\@all_snaps, $t5);

    # note that $t5 is excluded
    my @solution1 = ($t1, $t2, $t3, $t4);

    my $test1 = @snaps_newer1 ~~ @solution1; 

    # TEST 2

    my $target2 = 'day=3000_08_24,time=00:00';

    my @snaps_newer2 = Yabsm::snaps_newer(\@all_snaps, $target2);

    my @solution2 = ();

    my $test2 = @snaps_newer2 ~~ @solution2;


    # TEST 3

    my @all_snaps_empty = ();

    my @snaps_newer3 = Yabsm::snaps_newer(\@all_snaps_empty, $t4);

    my @solution3 = ();

    my $test3 = @snaps_newer3 ~~ @solution3;

    ok ( $test1 && $test2 && $test3, 'snaps_newer()' );
}

test_snaps_older();
sub test_snaps_older {

    my $t1 = 'day=2026_08_24,time=00:00';
    my $t2 = 'day=2025_08_24,time=00:00';
    my $t3 = 'day=2024_08_24,time=00:00';
    my $t4 = 'day=2023_08_24,time=00:00';
    my $t5 = 'day=2022_08_24,time=00:00';
    my $t6 = 'day=2021_08_24,time=00:00';
    my $t7 = 'day=2020_08_24,time=00:00';

    # sorted from newest to oldest
    my @all_snaps = ($t1, $t2, $t3, $t4, $t5, $t6, $t7);

    # TEST 1

    my @snaps_older1 = Yabsm::snaps_older(\@all_snaps, $t5);

    # note that $t5 is excluded
    my @solution1 = ($t6, $t7);

    my $test1 = @snaps_older1 ~~ @solution1; 

    # TEST 2

    my $target2 = 'day=1999_08_24,time=00:00'; 

    my @snaps_older2 = Yabsm::snaps_older(\@all_snaps, $target2);

    my @solution2 = ();

    my $test2 = @snaps_older2 ~~ @solution2;

    # TEST 3

    my @all_snaps_empty = ();

    my @snaps_older3 = Yabsm::snaps_older(\@all_snaps_empty, $t4);

    my @solution3 = ();

    my $test3 = @snaps_older3 ~~ @solution3;

    ok ( $test1 && $test2 && $test3, 'snaps_older()' );
}

test_snaps_between();
sub test_snaps_between {
   
    my $t1 = 'day=2026_08_24,time=00:00';
    my $t2 = 'day=2025_08_24,time=00:00';
    my $t3 = 'day=2024_08_24,time=00:00';
    my $t4 = 'day=2023_08_24,time=00:00';
    my $t5 = 'day=2022_08_24,time=00:00';
    my $t6 = 'day=2021_08_24,time=00:00';
    my $t7 = 'day=2020_08_24,time=00:00';

    # sorted from newest to oldest
    my @all_snaps = ($t1, $t2, $t3, $t4, $t5, $t6, $t7);

    # TEST 1

    # target snaps are reversed
    my @t1_snaps_between1 = Yabsm::snaps_between(\@all_snaps, $t2, $t5);
    my @t1_snaps_between2 = Yabsm::snaps_between(\@all_snaps, $t5, $t2);
    my @t1_solution = ($t2, $t3, $t4, $t5);

    my $test1 = @t1_snaps_between1 ~~ @t1_solution
             && @t1_snaps_between2 ~~ @t1_solution;

    # TEST 2

    my $t2_bound1 = 'day=2025_08_24,time=11:30';
    my $t2_bound2 = 'day=2021_08_24,time=11:30';

    my @t2_snaps_between = Yabsm::snaps_between(\@all_snaps, $t2_bound1, $t2_bound2);
    my @t2_solution = ($t3, $t4, $t5);

    my $test2 = @t2_snaps_between ~~ @t2_solution;

    # TEST 3

    my $t3_bound1 = 'day=2028_08_24,time=11:30';
    my $t3_bound2 = 'day=2027_08_24,time=11:30';

    my @t3_snaps_between = Yabsm::snaps_between(\@all_snaps, $t3_bound1, $t3_bound2);
    my @t3_solution = ();

    my $test3 = @t3_snaps_between ~~ @t3_solution;

    ok ( $test1 && $test2 && $test3, 'snaps_between()' );
} 

test_newest_snap();
sub test_newest_snap {

    my $t1 = 'day=2026_08_24,time=00:00';
    my $t2 = 'day=2025_08_24,time=00:00';
    my $t3 = 'day=2024_08_24,time=00:00';
    
    # sorted from newest to oldest
    my @all_snaps = ($t1, $t2, $t3);

    my $newest = Yabsm::newest_snap(\@all_snaps);

    my $correct = $newest eq 'day=2026_08_24,time=00:00';

    ok ( $correct, 'newest_snap()' );
}

test_oldest_snap();
sub test_oldest_snap {

    my $t1 = 'day=2026_08_24,time=00:00';
    my $t2 = 'day=2025_08_24,time=00:00';
    my $t3 = 'day=2024_08_24,time=00:00';
    
    # sorted from newest to oldest
    my @all_snaps = ($t1, $t2, $t3);

    my $oldest = Yabsm::oldest_snap(\@all_snaps);

    my $correct = $oldest eq 'day=2024_08_24,time=00:00';

    ok ( $correct, 'oldest_snap()' );
}

test_all_subvols();
sub test_all_subvols {

    my %config = gen_random_config();

    my @subvols1 = sort keys %{$config{subvols}};

    my @subvols2 = Yabsm::all_subvols(\%config);

    ok ( @subvols1 ~~ @subvols2, 'all_subvols()' );
}

test_is_literal_time();
sub test_is_literal_time {

    # these should all be true
    my $t0 = Yabsm::is_literal_time('2020-12-25-15-05');
    my $t1 = Yabsm::is_literal_time('2020-12-25-5-3');
    my $t2 = Yabsm::is_literal_time('12-25-5-3');
    my $t3 = Yabsm::is_literal_time('12-25-3');
    my $t4 = Yabsm::is_literal_time('12-25');
    my $t5 = Yabsm::is_literal_time('1-2');

    # these should all be false
    my $f0 = Yabsm::is_literal_time('');
    my $f1 = Yabsm::is_literal_time(' 2020-12-25-15-30');
    my $f2 = Yabsm::is_literal_time('2020-12-25-5-3 ');
    my $f3 = Yabsm::is_literal_time('12');
    my $f4 = Yabsm::is_literal_time('20202-12-25-3-04');
    my $f5 = Yabsm::is_literal_time('20-12-25-12-30');
    my $f6 = Yabsm::is_literal_time('2020-123-25-12-30');

    my $trues = $t0 && $t1 && $t2 && $t3 && $t4 && $t5;
    my $falses = not ($f0 || $f1 || $f2 || $f3 || $f4 || $f5);

    ok ( $trues && $falses, 'is_literal_time()' );
}

test_is_relative_time();
sub test_is_relative_time {

    # these should all be true
    my $t0 = Yabsm::is_relative_time('back-10-m');
    my $t1 = Yabsm::is_relative_time('b-10-mins');
    my $t2 = Yabsm::is_relative_time('b-10-minutes');
    my $t3 = Yabsm::is_relative_time('b-10000-h');
    my $t4 = Yabsm::is_relative_time('b-10000-hrs');
    my $t5 = Yabsm::is_relative_time('b-1-hours');
    my $t6 = Yabsm::is_relative_time('back-1-hours');
    my $t7 = Yabsm::is_relative_time('back-4-d');
    my $t8 = Yabsm::is_relative_time('b-4-days');

    # these should all be false
    my $f0 = Yabsm::is_relative_time('');
    my $f1 = Yabsm::is_relative_time(' back-10-m');
    my $f2 = Yabsm::is_relative_time('b-10-mins ');
    my $f3 = Yabsm::is_relative_time('b-10-minutess');
    my $f4 = Yabsm::is_relative_time('back 3 h');
    my $f5 = Yabsm::is_relative_time('b-10-d b-10-d');
    my $f6 = Yabsm::is_relative_time('b-10-dayss');
    my $f7 = Yabsm::is_relative_time('back-1-v');
    my $f8 = Yabsm::is_relative_time('ba-4-d');
    my $f9 = Yabsm::is_relative_time('4-h');

    my $trues = $t0 && $t1 && $t2 && $t3 && $t4 && $t5 && $t6 && $t7 && $t8;
    my $falses = not ($f0 || $f1 || $f2 || $f3 || $f4 || $f5
		   || $f6 || $f7 || $f8 || $f9);

    ok ( $trues && $falses, 'is_relative_time()' );
}

test_is_newest_time();
sub test_is_newest_time {
    
    # this is the only valid newest query
    my $true = Yabsm::is_newest_time('newest');

    # these should all be false
    my $f0 = Yabsm::is_newest_time('');
    my $f1 = Yabsm::is_newest_time('new');
    my $f2 = Yabsm::is_newest_time('n');
    my $f3 = Yabsm::is_newest_time(' newest');
    my $f4 = Yabsm::is_newest_time('newest ');

    my $falses = not ($f0 || $f1 || $f2 || $f3 || $f4);

    ok ( $true && $falses, 'is_newest_time' );
}

test_is_oldest_time();
sub test_is_oldest_time {
    
    # this is the only valid oldest time
    my $true = Yabsm::is_oldest_time('oldest');

    # these should all be false
    my $f0 = Yabsm::is_oldest_time('');
    my $f1 = Yabsm::is_oldest_time('old');
    my $f2 = Yabsm::is_oldest_time('o');
    my $f3 = Yabsm::is_oldest_time(' oldest');
    my $f4 = Yabsm::is_oldest_time('oldest ');

    my $falses = not ($f0 || $f1 || $f2 || $f3 || $f4);

    ok ( $true && $falses, 'is_oldest_time' );
}

test_is_immediate();
sub test_is_immediate {

    # these should all be true
    my $t0 = Yabsm::is_immediate('2020-12-25-08-30');
    my $t1 = Yabsm::is_immediate('b-45-m');
    my $t2 = Yabsm::is_immediate('12-30');
    my $t3 = Yabsm::is_immediate('back-12-days');
    my $t4 = Yabsm::is_immediate('newest');
    my $t5 = Yabsm::is_immediate('oldest');

    # these should all be false
    my $f0 = Yabsm::is_immediate('before b-5-d'); 
    my $f1 = Yabsm::is_immediate(''); 
    my $f2 = Yabsm::is_immediate(' b-5-d '); 
    my $f3 = Yabsm::is_immediate('back-4-WRONG'); 

    my $trues = $t0 && $t1 && $t2 && $t3 && $t4 && $t5;
    my $falses = not ($f0 || $f1 || $f2 || $f3);

    ok ( $trues && $falses, 'is_immediate()' );
}

test_is_newer_query();
sub test_is_newer_query {

    # these should all be true
    my $t0 = Yabsm::is_newer_query('newer b-45-m');
    my $t1 = Yabsm::is_newer_query('newer 12-30');
    
    # these should all be false
    my $f0 = Yabsm::is_newer_query('newer b-5-d 12-30'); 
    my $f1 = Yabsm::is_newer_query('newer b-WRONG-d'); 
    my $f2 = Yabsm::is_newer_query('new b-5-d'); 
    my $f3 = Yabsm::is_newer_query(''); 
    my $f4 = Yabsm::is_newer_query(' newer b-6-h'); 
    my $f5 = Yabsm::is_newer_query('newer b-6-h '); 

    my $trues = $t0 && $t1;
    my $falses = not ($f0 || $f1 || $f2 || $f3 || $f4 || $f5);

    ok ( $trues && $falses, 'is_newer_query()' );
}

test_is_older_query();
sub test_is_older_query {

    # these should all be true
    my $t0 = Yabsm::is_older_query('older b-45-m');
    my $t1 = Yabsm::is_older_query('older 12-30');
    
    # these should all be false
    my $f0 = Yabsm::is_older_query('older b-5-d 12-30'); 
    my $f1 = Yabsm::is_older_query('older b-WRONG-d'); 
    my $f2 = Yabsm::is_older_query('old b-5-d'); 
    my $f3 = Yabsm::is_older_query(''); 
    my $f4 = Yabsm::is_older_query(' older b-6-h'); 
    my $f5 = Yabsm::is_older_query('older b-6-h '); 

    my $trues = $t0 && $t1;
    my $falses = not ($f0 || $f1 || $f2 || $f3 || $f4 || $f5);

    ok ( $trues && $falses, 'is_older_query()' );
}

test_is_between_query();
sub test_is_between_query {
    
    # these should all be true
    my $t1 = Yabsm::is_between_query('between b-4-d b-5-d');
    my $t2 = Yabsm::is_between_query('bet b-4-d b-5-d');
    my $t3 = Yabsm::is_between_query('bet 12-25 2020-12-25');
    my $t4 = Yabsm::is_between_query('bet 12-24 b-5-m');
    my $t5 = Yabsm::is_between_query('bet 12-24 b-5-m');
    my $t6 = Yabsm::is_between_query('bet b-2-d b-5-d');

    my $f1 = Yabsm::is_between_query('');
    my $f2 = Yabsm::is_between_query('bet b-WRONG-d b-5-d');
    my $f3 = Yabsm::is_between_query('bet 12-25 WRONG');
    my $f4 = Yabsm::is_between_query(' bet 12-24 b-5-m');
    my $f5 = Yabsm::is_between_query('bet 12-24 b-5-m ');
    my $f6 = Yabsm::is_between_query(' bet 12-24 b-5-m');
    my $f7 = Yabsm::is_between_query('betw 12-24 b-5-m');

    my $trues = $t1 && $t2 && $t3 && $t4 && $t5 && $t6;
    my $falses = not ($f1 || $f2 || $f3 || $f4 || $f5 || $f6 || $f7);

    ok ( $trues && $falses, 'is_between_query()' );
}

test_is_valid_query();
sub test_is_valid_query {

    # these should all be true
    my $t0 = Yabsm::is_valid_query('b-4-h');
    my $t1 = Yabsm::is_valid_query('2020-12-25-0-0');
    my $t2 = Yabsm::is_valid_query('back-80-days');
    my $t3 = Yabsm::is_valid_query('newer b-52-m');
    my $t4 = Yabsm::is_valid_query('newer 12-25');
    my $t5 = Yabsm::is_valid_query('older b-8-mins');
    my $t6 = Yabsm::is_valid_query('older b-8-mins');
    my $t7 = Yabsm::is_valid_query('between 8-30 2021-12-25');
    my $t8 = Yabsm::is_valid_query('between 2021-12-25 8-30');
    my $t9 = Yabsm::is_valid_query('bet 12-25 b-5-d');
    my $t10 = Yabsm::is_valid_query('oldest');
    my $t11 = Yabsm::is_valid_query('newest');

    # these should all be false
    my $f0 = Yabsm::is_valid_query('');
    my $f1 = Yabsm::is_valid_query('before WRONG');
    my $f2 = Yabsm::is_valid_query('after WRONG');
    my $f3 = Yabsm::is_valid_query('back 90 mins');
    my $f4 = Yabsm::is_valid_query('between b-2-d WRONG');
    my $f5 = Yabsm::is_valid_query('bet WRONG b-2-d');
    my $f6 = Yabsm::is_valid_query('2021 10 12');
    my $f7 = Yabsm::is_valid_query(' b-4-d');
    my $f8 = Yabsm::is_valid_query('b-4-d ');
    my $f9 = Yabsm::is_valid_query('newest b-4-4');
    my $f10 = Yabsm::is_valid_query('oldest 12-25');
    my $f11 = Yabsm::is_valid_query('before after b-8-h');

    my $trues = ($t0 && $t2 && $t4 && $t5 && $t6
	      && $t7 && $t8 && $t9 && $t10 && $t11);

    my $falses = not ($f0 || $f1 || $f2 || $f3  || $f4 || $f5 || $f6
		   || $f7 || $f8 || $f9 || $f10 || $f11);

    ok ( $trues && $falses, 'is_valid_query()' );
}

test_is_subvol();
sub test_is_subvol {

    my %config = gen_random_config();

    my @all_subvols = Yabsm::all_subvols(\%config);

    my $t1 = 1;
    foreach my $subvol (@all_subvols) {
	$t1 = 0 unless Yabsm::is_subvol(\%config, $subvol);
    }

    my $t2 = 1;
    $t2 = 0 if Yabsm::is_subvol(\%config, 'this is not a subvol');

    ok ( $t1 && $t2, 'is_subvol()' );
}

test_is_timeframe();
sub test_is_timeframe {

    my $correct_hourly   = Yabsm::is_timeframe('hourly');
    my $correct_daily    = Yabsm::is_timeframe('daily');
    my $correct_midnight = Yabsm::is_timeframe('midnight');
    my $correct_monthly  = Yabsm::is_timeframe('monthly');

    my $f0 = Yabsm::is_timeframe('');

    my $f1 = Yabsm::is_timeframe(' hourly');
    my $f2 = Yabsm::is_timeframe(' daily');
    my $f3 = Yabsm::is_timeframe(' midnight');
    my $f4 = Yabsm::is_timeframe(' monthly');

    my $f5 = Yabsm::is_timeframe('hourly ');
    my $f6 = Yabsm::is_timeframe('daily ');
    my $f7 = Yabsm::is_timeframe('midnight ');
    my $f8 = Yabsm::is_timeframe('monthly ');

    my $f9  = Yabsm::is_timeframe(' hourly ');
    my $f10 = Yabsm::is_timeframe(' daily ');
    my $f11 = Yabsm::is_timeframe(' midnight ');
    my $f12 = Yabsm::is_timeframe(' monthly ');

    my $f13 = Yabsm::is_timeframe('this is not a timeframe');

    my $trues = $correct_hourly && $correct_daily && $correct_midnight && $correct_monthly;

    my $falses = not ( $f0 || $f1 || $f2 || $f3 || $f4 || $f5 || $f6 || $f7
		    || $f9 || $f10 || $f11 || $f12 || $f13);

    ok ( $trues && $falses, 'is_timeframe()' );
}

test_current_time_snapstring();
sub test_current_time_snapstring {

    my $ct = Yabsm::current_time_snapstring();

    my $test = $ct =~ /^day=\d{4}_\d{2}_\d{2},time=\d{2}:\d{2}$/;

    ok ( $test, 'current_time_snapstring()' );
}

test_target_dir();
sub test_target_dir {

    my %config = gen_random_config();

    my $snapshot_root_dir = $config{misc}{snapshot_directory};

    my $subvol = $config{(keys %config)[rand keys %config]};

    # TEST 1

    my $output1 = Yabsm::target_dir(\%config);

    my $solution1 = "$snapshot_root_dir/yabsm";

    my $correct1 = $output1 eq $solution1;

    # TEST 2

    my $output2 = Yabsm::target_dir(\%config, $subvol);

    my $solution2 = "$snapshot_root_dir/yabsm/$subvol";

    my $correct2 = $output2 eq $solution2;

    # TEST 3

    my $output3 = Yabsm::target_dir(\%config, $subvol, 'midnight');

    my $solution3 = "$snapshot_root_dir/yabsm/$subvol/midnight";

    my $correct3 = $output3 eq $solution3;

    ok ( $correct1 && $correct2 && $correct3, 'target_dir()' );
 }
