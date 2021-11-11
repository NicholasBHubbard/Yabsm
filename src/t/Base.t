#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT
#
#  Testing for the Yabsm.pm library.

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

# Module to test
use Yabsm::Base;

                 ####################################
                 #            GENERATORS            #
                 ####################################

sub gen_random_config {

    my %config; 

    # misc settings
    $config{misc}{yabsm_dir} = '/.snapshots/yabsm';

    # subvols
    my @possible_subvols = shuffle ('root', 'home', 'etc', 'var', 'tmp', 'mnt');
    my @possible_mountpoints = shuffle ('/', '/home', '/etc', '/var', '/tmp', '/mnt');
    my @subvols = @possible_subvols[0 .. int(rand(@possible_subvols))];

    # dynamically add config entries for each subvolume.
    foreach my $subvol (@subvols) {

	# generate random config values

	my $mountpoint = pop @possible_mountpoints;

	my $_5minute_want = yes_or_no();
	my $_5minute_keep = 1 + int(rand(1000));

	my $hourly_want   = yes_or_no();
	my $hourly_keep   = 1 + int(rand(1000));

	my $midnight_want = yes_or_no();
	my $midnight_keep = 1 + int(rand(1000));

	my $weekly_want = yes_or_no();
	my $weekly_keep = 1 + int(rand(1000));
	my $weekly_day  = rand_day_of_week();

	my $monthly_want  = yes_or_no();
	my $monthly_keep  = 1 + int(rand(1000));

	# add entries to the config

	$config{subvols}{$subvol}{mountpoint} = $mountpoint;

	$config{subvols}{$subvol}{'5minute_want'} = $_5minute_want;
	$config{subvols}{$subvol}{'5minute_keep'} = $_5minute_keep;

	$config{subvols}{$subvol}{hourly_want} = $hourly_want;
	$config{subvols}{$subvol}{hourly_keep} = $hourly_keep;

	$config{subvols}{$subvol}{midnight_want} = $midnight_want;
	$config{subvols}{$subvol}{midnight_keep} = $midnight_keep;

	$config{subvols}{$subvol}{weekly_want} = $weekly_want;
	$config{subvols}{$subvol}{weekly_keep} = $weekly_keep;
	$config{subvols}{$subvol}{weekly_day} = $weekly_day;

	$config{subvols}{$subvol}{monthly_want} = $monthly_want;
	$config{subvols}{$subvol}{monthly_keep} = $monthly_keep;
    }

    # backups
    foreach my $subvol (@subvols) {

	my $backup = $subvol . 'Backup';

	$config{backups}{$backup}{subvol} = $subvol;

	$config{backups}{$backup}{backup_dir} = '/whatever';

	$config{backups}{$backup}{remote} = yes_or_no();

	if ($config{backups}{$backup}{remote} eq 'yes') {
	    $config{backups}{$backup}{host} = 'whatever';
	}

	$config{backups}{$backup}{timeframe} = rand_backup_timeframe();

	$config{backups}{$backup}{keep} = 1 + int(rand(1000));
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

	my $snapstring = Yabsm::Base::nums_to_snapstring($yr, $mon, $day, $hr, $min);

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

sub rand_backup_timeframe {

    # randomly return a backup timeframe

    my $rand = int(rand(4));

    if    ($rand == 1) { return 'hourly'   }
    elsif ($rand == 2) { return 'midnight' }
    elsif ($rand == 3) { return 'weekly'   }
    else               { return 'monthly'  }
}

sub rand_day_of_week {

    # randomly return a backup timeframe

    my $rand = int(rand(5));

    if    ($rand == 1) { return '5minute'  }
    elsif ($rand == 2) { return 'hourly'   }
    elsif ($rand == 3) { return 'midnight' }
    elsif ($rand == 4) { return 'weekly'   }
    else               { return 'monthly'  }
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
    my $t1 = Yabsm::Base::cmp_snaps($newest, $middle1);

    # should be -1
    my $t2 = Yabsm::Base::cmp_snaps($newest, $oldest);

    # should be -1
    my $t3 = Yabsm::Base::cmp_snaps($middle1, $oldest);

    # should be 1
    my $t4 = Yabsm::Base::cmp_snaps($oldest, $middle1);

    # should be 1
    my $t5 = Yabsm::Base::cmp_snaps($oldest, $newest);

    # should be 0
    my $t6 = Yabsm::Base::cmp_snaps($middle1, $middle2);

    # should be 0
    my $t7 = Yabsm::Base::cmp_snaps($middle2, $middle1);

    my $sum = $t1 + $t2 + $t3 + $t4 + $t5 + $t6 + $t7;;

    ok( $sum == -1, 'cmp_snaps()' );
}

test_sort_snaps();
sub test_sort_snaps {

    # TEST 1

    my @rand_snaps1 = gen_n_random_snap_paths(15);

    my @sorted_snaps1 = Yabsm::Base::sort_snaps(\@rand_snaps1);

    my $correct = 1;
    for my $i (0 .. $#sorted_snaps1 - 1) {

	my $this_snap = $sorted_snaps1[$i];
	my $next_snap = $sorted_snaps1[$i+1];

	my $cmp = Yabsm::Base::cmp_snaps($this_snap, $next_snap);

	# if $this_snap is newer than $next_snap
	if ($cmp == 1) { $correct = 0 }
    }
    
    ok( $correct, 'sort_snaps()' );
}

test_n_units_ago_snapstring();
sub test_n_units_ago_snapstring {

    my $t = localtime();

    my $mins_ago  = Yabsm::Base::time_piece_obj_to_snapstring($t - (120 * 60));
    my $hours_ago = Yabsm::Base::time_piece_obj_to_snapstring($t - (2 * 3600));
    my $days_ago  = Yabsm::Base::time_piece_obj_to_snapstring($t - (2 * 86400));

    my $min         = Yabsm::Base::n_units_ago_snapstring(120, 'minutes');
    my $min_correct = $min eq $mins_ago;

    my $hr          = Yabsm::Base::n_units_ago_snapstring(2, 'hours');
    my $hr_correct  = $hr eq $hours_ago;

    my $day         = Yabsm::Base::n_units_ago_snapstring(2, 'days');
    my $day_correct = $day eq $days_ago;

    ok ( $min_correct && $hr_correct && $day_correct, 'n_units_ago_snapstring()' );
}

test_nums_to_snapstring();
sub test_nums_to_snapstring {

    my $output = Yabsm::Base::nums_to_snapstring(2020, 3, 2, 23, 15);

    ok( $output eq 'day=2020_03_02,time=23:15', 'nums_to_snapstring()' );
}

test_snapstring_to_nums();
sub test_snapstring_to_nums {

    my $time = 'day=2020_03_02,time=23:15';

    my @got = Yabsm::Base::snapstring_to_nums($time);

    my @expected = ('2020','03','02','23','15');

    is_deeply ( \@got, \@expected, 'snapstring_to_nums()' );
}

test_snapstring_to_time_piece_obj();
sub test_snapstring_to_time_piece_obj {
    
    my $time = 'day=2020_03_02,time=23:15';

    my $time_piece_obj = Yabsm::Base::snapstring_to_time_piece_obj($time);

    my $output = $time_piece_obj->year;

    ok ( $output eq '2020', 'snapstring_to_time_piece_obj()' );
}

test_time_piece_obj_to_snapstring();
sub test_time_piece_obj_to_snapstring {

    my $time_piece_obj =
      Time::Piece->strptime('2020/3/06/12/0','%Y/%m/%d/%H/%M');

    my $output = Yabsm::Base::time_piece_obj_to_snapstring($time_piece_obj);

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
    my $out1  = Yabsm::Base::literal_time_to_snapstring($form1);
    my $t1    = $out1 eq $sol1;

    # yr-mon-day
    my $form2 = '2023-12-25';
    my $sol2  = 'day=2023_12_25,time=00:00';
    my $out2  = Yabsm::Base::literal_time_to_snapstring($form2);
    my $t2    = $out2 eq $sol2;

    # mon-day-hr
    my $form3 = '1-2-3';
    my $sol3  = "day=${cur_yr}_01_02,time=03:00";
    my $out3  = Yabsm::Base::literal_time_to_snapstring($form3);
    my $t3    = $out3 eq $sol3;

    # mon-day-hr-min
    my $form4 = '12-25-3-30';
    my $sol4  = "day=${cur_yr}_12_25,time=03:30";
    my $out4  = Yabsm::Base::literal_time_to_snapstring($form4);
    my $t4    = $out4 eq $sol4;
    
    # mon-day
    my $form5 = '12-25';
    my $sol5  = "day=${cur_yr}_12_25,time=00:00";
    my $out5  = Yabsm::Base::literal_time_to_snapstring($form5);
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
    my $out1 = Yabsm::Base::relative_time_to_snapstring($rel1);
    my $out2 = Yabsm::Base::relative_time_to_snapstring($rel2);
    my $out3 = Yabsm::Base::relative_time_to_snapstring($rel3);

    my $t = localtime();
    my $sol1  = Yabsm::Base::time_piece_obj_to_snapstring($t - (4 * 60));
    my $sol2  = Yabsm::Base::time_piece_obj_to_snapstring($t - (4 * 3600));
    my $sol3  = Yabsm::Base::time_piece_obj_to_snapstring($t - (4 * 86400));

    my $t1 = $out1 = $sol1;
    my $t2 = $out2 = $sol2;
    my $t3 = $out3 = $sol3;
    
    my $correct = $t1 && $t2 && $t3;

    ok ( $correct, 'relative_time_to_snapstring()' );
}

test_snap_closer();
sub test_snap_closer {

    my $target = 'day=2020_08_24,time=10:30';
    my $snap1  = 'day=2020_08_24,time=10:35';
    my $snap2  = 'day=2020_08_24,time=10:24';
    my $snap3  = 'day=2020_08_24,time=10:25';

    # TEST 1

    my $output1 = Yabsm::Base::snap_closer($target, $snap1, $snap2);

    my $correct1 = $output1 eq $snap1;

    # TEST 2

    my $output2 = Yabsm::Base::snap_closer($target, $target, $snap1);

    my $correct2 = $target eq $output2;

    # TEST 3

    my $output3 = Yabsm::Base::snap_closer($target, $snap1, $target);

    my $correct3 = $target eq $output3;

    # TEST 4

    my $output4 = Yabsm::Base::snap_closer($target, $snap1, $snap3);

    my $correct4 = $output4 eq $snap1;

    # TEST 5

    my $output5 = Yabsm::Base::snap_closer($target, $snap3, $snap1);

    my $correct5 = $output5 eq $snap3;


    ok ( $correct1 && $correct2 && $correct3 && $correct4 && $correct5
	 , 'snap_closer()' );
}

test_snap_closest_to();
sub test_snap_closest_to {

    my $t0 = Yabsm::Base::n_units_ago_snapstring(0,  'hours');
    my $t1 = Yabsm::Base::n_units_ago_snapstring(10, 'hours');
    my $t2 = Yabsm::Base::n_units_ago_snapstring(20, 'hours');
    my $t3 = Yabsm::Base::n_units_ago_snapstring(30, 'hours');
    my $t4 = Yabsm::Base::n_units_ago_snapstring(40, 'hours');
    my $t5 = Yabsm::Base::n_units_ago_snapstring(50, 'hours');

    my @all_snaps = ($t0, $t1, $t2, $t3, $t4, $t5);

    # TEST 1
    my $target1 = Yabsm::Base::n_units_ago_snapstring(34, 'hours');

    my $output1 = Yabsm::Base::snap_closest_to(\@all_snaps, $target1);

    my $correct1 = $output1 eq $t3;


    # TEST 2

    my $target2 = Yabsm::Base::n_units_ago_snapstring(36, 'hours');

    my $output2 = Yabsm::Base::snap_closest_to(\@all_snaps, $target2);

    my $correct2 = $output2 eq $t4;

    # TEST 3

    # equidistant. Should return the newer one
    my $target3 = Yabsm::Base::n_units_ago_snapstring(35, 'hours');

    my $output3 = Yabsm::Base::snap_closest_to(\@all_snaps, $target3);

    my $correct3 = $output3 eq $t3;

    # TEST 4

    # equal to one of the snaps
    my $output4 = Yabsm::Base::snap_closest_to(\@all_snaps, $t3);

    my $correct4 = $output4 eq $t3;

    ok ( $correct1 && $correct2 && $correct3 && $correct4, 'snap_closest_to()' );
}

test_snaps_newer_than();
sub test_snaps_newer_than {

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

    my @snaps_newer1 = Yabsm::Base::snaps_newer_than(\@all_snaps, $t5);

    # note that $t5 is excluded
    my @solution1 = ($t1, $t2, $t3, $t4);

    my $test1 = @snaps_newer1 ~~ @solution1; 

    # TEST 2

    my $target2 = 'day=3000_08_24,time=00:00';

    my @snaps_newer2 = Yabsm::Base::snaps_newer_than(\@all_snaps, $target2);

    my @solution2 = ();

    my $test2 = @snaps_newer2 ~~ @solution2;


    # TEST 3

    my @all_snaps_empty = ();

    my @snaps_newer3 = Yabsm::Base::snaps_newer_than(\@all_snaps_empty, $t4);

    my @solution3 = ();

    my $test3 = @snaps_newer3 ~~ @solution3;

    ok ( $test1 && $test2 && $test3, 'snaps_newer_than()' );
}

test_snaps_older_than();
sub test_snaps_older_than {

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

    my @snaps_older1 = Yabsm::Base::snaps_older_than(\@all_snaps, $t5);

    # note that $t5 is excluded
    my @solution1 = ($t6, $t7);

    my $test1 = @snaps_older1 ~~ @solution1; 

    # TEST 2

    my $target2 = 'day=1999_08_24,time=00:00'; 

    my @snaps_older2 = Yabsm::Base::snaps_older_than(\@all_snaps, $target2);

    my @solution2 = ();

    my $test2 = @snaps_older2 ~~ @solution2;

    # TEST 3

    my @all_snaps_empty = ();

    my @snaps_older3 = Yabsm::Base::snaps_older_than(\@all_snaps_empty, $t4);

    my @solution3 = ();

    my $test3 = @snaps_older3 ~~ @solution3;

    ok ( $test1 && $test2 && $test3, 'snaps_older_than()' );
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
    my @t1_snaps_between1 = Yabsm::Base::snaps_between(\@all_snaps, $t2, $t5);
    my @t1_snaps_between2 = Yabsm::Base::snaps_between(\@all_snaps, $t5, $t2);
    my @t1_solution = ($t2, $t3, $t4, $t5);

    my $test1 = @t1_snaps_between1 ~~ @t1_solution
             && @t1_snaps_between2 ~~ @t1_solution;

    # TEST 2

    my $t2_bound1 = 'day=2025_08_24,time=11:30';
    my $t2_bound2 = 'day=2021_08_24,time=11:30';

    my @t2_snaps_between = Yabsm::Base::snaps_between(\@all_snaps, $t2_bound1, $t2_bound2);
    my @t2_solution = ($t3, $t4, $t5);

    my $test2 = @t2_snaps_between ~~ @t2_solution;

    # TEST 3

    my $t3_bound1 = 'day=2028_08_24,time=11:30';
    my $t3_bound2 = 'day=2027_08_24,time=11:30';

    my @t3_snaps_between = Yabsm::Base::snaps_between(\@all_snaps, $t3_bound1, $t3_bound2);
    my @t3_solution = ();

    my $test3 = @t3_snaps_between ~~ @t3_solution;

    ok ( $test1 && $test2 && $test3, 'snaps_between()' );
} 

test_newest_snap();
sub test_newest_snap {

    # only tests the case that $ref is an array ref

    my $t1 = 'day=2026_08_24,time=00:00';
    my $t2 = 'day=2025_08_24,time=00:00';
    my $t3 = 'day=2024_08_24,time=00:00';
    
    # sorted from newest to oldest
    my @all_snaps = ($t1, $t2, $t3);

    my $newest = Yabsm::Base::newest_snap(\@all_snaps);

    my $correct = $newest eq 'day=2026_08_24,time=00:00';

    ok ( $correct, 'newest_snap()' );
}

test_oldest_snap();
sub test_oldest_snap {

    # only tests the case that $ref is an array ref

    my $t1 = 'day=2026_08_24,time=00:00';
    my $t2 = 'day=2025_08_24,time=00:00';
    my $t3 = 'day=2024_08_24,time=00:00';
    
    # sorted from newest to oldest
    my @all_snaps = ($t1, $t2, $t3);

    my $oldest = Yabsm::Base::oldest_snap(\@all_snaps);

    my $correct = $oldest eq 'day=2024_08_24,time=00:00';

    ok ( $correct, 'oldest_snap()' );
}

test_all_subvols();
sub test_all_subvols {

    my %config = gen_random_config();

    my @got = Yabsm::Base::all_subvols(\%config);

    my @expected = sort keys %{$config{subvols}};

    is_deeply ( \@got, \@expected, 'all_subvols()' );
}

test_all_backups();
sub test_all_backups {

    my %config = gen_random_config();

    my @got = Yabsm::Base::all_backups(\%config);

    my @expected = sort keys %{$config{backups}};

    is_deeply ( \@got, \@expected, 'all_backups()' );
}

test_all_backups_of_subvol();
sub test_all_backups_of_subvol {

    my %config = gen_random_config();

    my $subvol = [Yabsm::Base::all_subvols(\%config)]->[0];

    my @expected = ();
    foreach my $backup (Yabsm::Base::all_backups(\%config)) {
	if ($config{backups}{$backup}{subvol} eq $subvol) {
	    push @expected, $backup;
	}
    }

    my @got = Yabsm::Base::all_backups_of_subvol(\%config, $subvol);

    is_deeply ( \@got, \@expected, 'all_backups_of_subvol()' );
}

test_is_literal_time();
sub test_is_literal_time {

    # these should all be true
    my $t0 = Yabsm::Base::is_literal_time('2020-12-25-15-05');
    my $t1 = Yabsm::Base::is_literal_time('2020-12-25-5-3');
    my $t2 = Yabsm::Base::is_literal_time('12-25-5-3');
    my $t3 = Yabsm::Base::is_literal_time('12-25-3');
    my $t4 = Yabsm::Base::is_literal_time('12-25');
    my $t5 = Yabsm::Base::is_literal_time('1-2');

    # these should all be false
    my $f0 = Yabsm::Base::is_literal_time('');
    my $f1 = Yabsm::Base::is_literal_time(' 2020-12-25-15-30');
    my $f2 = Yabsm::Base::is_literal_time('2020-12-25-5-3 ');
    my $f3 = Yabsm::Base::is_literal_time('12');
    my $f4 = Yabsm::Base::is_literal_time('20202-12-25-3-04');
    my $f5 = Yabsm::Base::is_literal_time('20-12-25-12-30');
    my $f6 = Yabsm::Base::is_literal_time('2020-123-25-12-30');

    my $trues = $t0 && $t1 && $t2 && $t3 && $t4 && $t5;
    my $falses = not ($f0 || $f1 || $f2 || $f3 || $f4 || $f5);

    ok ( $trues && $falses, 'is_literal_time()' );
}

test_is_relative_time();
sub test_is_relative_time {

    # these should all be true
    my $t0 = Yabsm::Base::is_relative_time('back-10-m');
    my $t1 = Yabsm::Base::is_relative_time('b-10-mins');
    my $t2 = Yabsm::Base::is_relative_time('b-10-minutes');
    my $t3 = Yabsm::Base::is_relative_time('b-10000-h');
    my $t4 = Yabsm::Base::is_relative_time('b-10000-hrs');
    my $t5 = Yabsm::Base::is_relative_time('b-1-hours');
    my $t6 = Yabsm::Base::is_relative_time('back-1-hours');
    my $t7 = Yabsm::Base::is_relative_time('back-4-d');
    my $t8 = Yabsm::Base::is_relative_time('b-4-days');

    # these should all be false
    my $f0 = Yabsm::Base::is_relative_time('');
    my $f1 = Yabsm::Base::is_relative_time(' back-10-m');
    my $f2 = Yabsm::Base::is_relative_time('b-10-mins ');
    my $f3 = Yabsm::Base::is_relative_time('b-10-minutess');
    my $f4 = Yabsm::Base::is_relative_time('back 3 h');
    my $f5 = Yabsm::Base::is_relative_time('b-10-d b-10-d');
    my $f6 = Yabsm::Base::is_relative_time('b-10-dayss');
    my $f7 = Yabsm::Base::is_relative_time('back-1-v');
    my $f8 = Yabsm::Base::is_relative_time('ba-4-d');
    my $f9 = Yabsm::Base::is_relative_time('4-h');

    my $trues = $t0 && $t1 && $t2 && $t3 && $t4 && $t5 && $t6 && $t7 && $t8;
    my $falses = not ($f0 || $f1 || $f2 || $f3 || $f4 || $f5
		   || $f6 || $f7 || $f8 || $f9);

    ok ( $trues && $falses, 'is_relative_time()' );
}

test_is_immediate();
sub test_is_immediate {

    # these should all be true
    my $t0 = Yabsm::Base::is_immediate('2020-12-25-08-30');
    my $t1 = Yabsm::Base::is_immediate('b-45-m');
    my $t2 = Yabsm::Base::is_immediate('12-30');
    my $t3 = Yabsm::Base::is_immediate('back-12-days');

    # these should all be false
    my $f0 = Yabsm::Base::is_immediate('before b-5-d'); 
    my $f1 = Yabsm::Base::is_immediate(''); 
    my $f2 = Yabsm::Base::is_immediate(' b-5-d '); 
    my $f3 = Yabsm::Base::is_immediate('back-4-WRONG'); 

    my $trues = $t0 && $t1 && $t2 && $t3;
    my $falses = not ($f0 || $f1 || $f2 || $f3);

    ok ( $trues && $falses, 'is_immediate()' );
}

test_is_newer_than_query();
sub test_is_newer_than_query {

    # these should all be true
    my $t0 = Yabsm::Base::is_newer_than_query('newer b-45-m');
    my $t1 = Yabsm::Base::is_newer_than_query('newer 12-30');
    my $t2 = Yabsm::Base::is_newer_than_query('after b-45-m');
    my $t3 = Yabsm::Base::is_newer_than_query('after 12-30');
    my $t4 = Yabsm::Base::is_newer_than_query('aft 12-30');
    
    # these should all be false
    my $f0 = Yabsm::Base::is_newer_than_query('newer b-5-d 12-30'); 
    my $f1 = Yabsm::Base::is_newer_than_query('newer b-WRONG-d'); 
    my $f2 = Yabsm::Base::is_newer_than_query('new b-5-d'); 
    my $f3 = Yabsm::Base::is_newer_than_query(''); 
    my $f4 = Yabsm::Base::is_newer_than_query(' newer b-6-h'); 
    my $f5 = Yabsm::Base::is_newer_than_query('newer b-6-h '); 
    my $f6 = Yabsm::Base::is_newer_than_query(' after b-6-h'); 
    my $f7 = Yabsm::Base::is_newer_than_query('after b-6-h '); 

    my $trues = $t0 && $t1 && $t2 && $t3 && $t4;
    my $falses = not ($f0 || $f1 || $f2 || $f3 || $f4 || $f5 || $f6 || $f7);

    ok ( $trues && $falses, 'is_newer_than_query()' );
}

test_is_older_than_query();
sub test_is_older_than_query {

    # these should all be true
    my $t0 = Yabsm::Base::is_older_than_query('older b-45-m');
    my $t1 = Yabsm::Base::is_older_than_query('older 12-30');
    my $t2 = Yabsm::Base::is_older_than_query('before b-45-m');
    my $t3 = Yabsm::Base::is_older_than_query('before 12-30');
    my $t4 = Yabsm::Base::is_older_than_query('bef 12-30');
    
    # these should all be false
    my $f0 = Yabsm::Base::is_older_than_query('older b-5-d 12-30'); 
    my $f1 = Yabsm::Base::is_older_than_query('older b-WRONG-d'); 
    my $f2 = Yabsm::Base::is_older_than_query('old b-5-d'); 
    my $f3 = Yabsm::Base::is_older_than_query(''); 
    my $f4 = Yabsm::Base::is_older_than_query(' older b-6-h'); 
    my $f5 = Yabsm::Base::is_older_than_query('older b-6-h '); 
    my $f6 = Yabsm::Base::is_older_than_query(' before b-6-h'); 
    my $f7 = Yabsm::Base::is_older_than_query('before b-6-h '); 

    my $trues = $t0 && $t1 && $t2 && $t3 && $t4;
    my $falses = not ($f0 || $f1 || $f2 || $f3 || $f4 || $f5 || $f6 || $f7);

    ok ( $trues && $falses, 'is_older_than_query()' );
}

test_is_between_query();
sub test_is_between_query {
    
    # these should all be true
    my $t1 = Yabsm::Base::is_between_query('between b-4-d b-5-d');
    my $t2 = Yabsm::Base::is_between_query('bet b-4-d b-5-d');
    my $t3 = Yabsm::Base::is_between_query('bet 12-25 2020-12-25');
    my $t4 = Yabsm::Base::is_between_query('bet 12-24 b-5-m');
    my $t5 = Yabsm::Base::is_between_query('bet 12-24 b-5-m');
    my $t6 = Yabsm::Base::is_between_query('bet b-2-d b-5-d');

    my $f1 = Yabsm::Base::is_between_query('');
    my $f2 = Yabsm::Base::is_between_query('bet b-WRONG-d b-5-d');
    my $f3 = Yabsm::Base::is_between_query('bet 12-25 WRONG');
    my $f4 = Yabsm::Base::is_between_query(' bet 12-24 b-5-m');
    my $f5 = Yabsm::Base::is_between_query('bet 12-24 b-5-m ');
    my $f6 = Yabsm::Base::is_between_query(' bet 12-24 b-5-m');
    my $f7 = Yabsm::Base::is_between_query('betw 12-24 b-5-m');

    my $trues = $t1 && $t2 && $t3 && $t4 && $t5 && $t6;
    my $falses = not ($f1 || $f2 || $f3 || $f4 || $f5 || $f6 || $f7);

    ok ( $trues && $falses, 'is_between_query()' );
}

test_is_valid_query();
sub test_is_valid_query {

    # these should all be true
    my $t0 = Yabsm::Base::is_valid_query('b-4-h');
    my $t1 = Yabsm::Base::is_valid_query('2020-12-25-0-0');
    my $t2 = Yabsm::Base::is_valid_query('back-80-days');
    my $t3 = Yabsm::Base::is_valid_query('newer b-52-m');
    my $t4 = Yabsm::Base::is_valid_query('newer 12-25');
    my $t5 = Yabsm::Base::is_valid_query('older b-8-mins');
    my $t6 = Yabsm::Base::is_valid_query('older b-8-mins');
    my $t7 = Yabsm::Base::is_valid_query('between 8-30 2021-12-25');
    my $t8 = Yabsm::Base::is_valid_query('between 2021-12-25 8-30');
    my $t9 = Yabsm::Base::is_valid_query('bet 12-25 b-5-d');
    my $t10 = Yabsm::Base::is_valid_query('oldest');
    my $t11 = Yabsm::Base::is_valid_query('newest');
    my $t12 = Yabsm::Base::is_valid_query('before b-8-mins');
    my $t13 = Yabsm::Base::is_valid_query('after b-8-mins');

    # these should all be false
    my $f0 = Yabsm::Base::is_valid_query('');
    my $f1 = Yabsm::Base::is_valid_query('before WRONG');
    my $f2 = Yabsm::Base::is_valid_query('after WRONG');
    my $f3 = Yabsm::Base::is_valid_query('back 90 mins');
    my $f4 = Yabsm::Base::is_valid_query('between b-2-d WRONG');
    my $f5 = Yabsm::Base::is_valid_query('bet WRONG b-2-d');
    my $f6 = Yabsm::Base::is_valid_query('2021 10 12');
    my $f7 = Yabsm::Base::is_valid_query(' b-4-d');
    my $f8 = Yabsm::Base::is_valid_query('b-4-d ');
    my $f9 = Yabsm::Base::is_valid_query('newest b-4-4');
    my $f10 = Yabsm::Base::is_valid_query('oldest 12-25');
    my $f11 = Yabsm::Base::is_valid_query('before after b-8-h');

    my $trues = ($t0 && $t2 && $t4 && $t5 && $t6
	      && $t7 && $t8 && $t9 && $t10 && $t11 && $t12 && $t13);

    my $falses = not ($f0 || $f1 || $f2 || $f3  || $f4 || $f5 || $f6
		   || $f7 || $f8 || $f9 || $f10 || $f11);

    ok ( $trues && $falses, 'is_valid_query()' );
}

test_is_subvol();
sub test_is_subvol {

    my %config = gen_random_config();

    my @all_subvols = Yabsm::Base::all_subvols(\%config);

    my $t1 = 1;
    foreach my $subvol (@all_subvols) {
	$t1 = 0 unless Yabsm::Base::is_subvol(\%config, $subvol);
    }

    my $f1 = 1;
    $f1 = 0 if Yabsm::Base::is_subvol(\%config, 'this is not a subvol');

    ok ( $t1 && $f1, 'is_subvol()' );
}

test_is_backup();
sub test_is_backup {
    
    my %config = gen_random_config();

    my @all_backups = Yabsm::Base::all_backups(\%config);

    my $t1 = 1;
    foreach my $backup (@all_backups) {
	$t1 = 0 unless Yabsm::Base::is_backup(\%config, $backup);
    }

    my $f1 = 1;
    $f1 = 0 if Yabsm::Base::is_backup(\%config, 'this is not a backup');

    ok ( $t1 && $f1, 'is_backup()' );
}

test_is_subject();
sub test_is_subject {

    my %config = gen_random_config();

    my @all_subvols = Yabsm::Base::all_subvols(\%config);
    my @all_backups = Yabsm::Base::all_backups(\%config);

    my @all_subjects = (@all_subvols, @all_backups);

    my $correct = 1;
    for my $subject (@all_subjects) {
	$correct = 0 if not Yabsm::Base::is_subject(\%config, $subject);
    }

    $correct = 0 if Yabsm::Base::is_subject(\%config, 'not a subject');

    ok ( $correct, 'is_subject()' );
}

test_is_local_backup();
sub test_is_local_backup {

    my %config = gen_random_config();

    my @all_backups = Yabsm::Base::all_backups(\%config);

    my $correct = 1;
    for my $backup (@all_backups) {
	if ($config{backups}{$backup}{remote} eq 'no') {
	    $correct = 0 unless Yabsm::Base::is_local_backup(\%config, $backup);
	}
	else {
	    $correct = 0 if Yabsm::Base::is_local_backup(\%config, $backup); 
	}
    }

    $correct = 0 if Yabsm::Base::is_local_backup(\%config, 'not a backup'); 

    ok ( $correct, 'is_local_backup()' );
}

test_is_remote_backup();
sub test_is_remote_backup {

    my %config = gen_random_config();

    my @all_backups = Yabsm::Base::all_backups(\%config);

    my $correct = 1;
    for my $backup (@all_backups) {
	if ($config{backups}{$backup}{remote} eq 'yes') {
	    $correct = 0 unless Yabsm::Base::is_remote_backup(\%config, $backup);
	}
	else {
	    $correct = 0 if Yabsm::Base::is_remote_backup(\%config, $backup); 
	}
    }

    $correct = 0 if Yabsm::Base::is_remote_backup(\%config, 'not a backup'); 

    ok ( $correct, 'is_remote_backup()' );
}

test_is_valid_time();
sub test_is_valid_time{

    my $t1 = Yabsm::Base::is_valid_time('0:0');
    my $t2 = Yabsm::Base::is_valid_time('00:00');
    my $t3 = Yabsm::Base::is_valid_time('23:59');
    my $t4 = Yabsm::Base::is_valid_time('6:30');
    my $t5 = Yabsm::Base::is_valid_time('12:3');

    my $f1 = Yabsm::Base::is_valid_time('');
    my $f2 = Yabsm::Base::is_valid_time(' ');
    my $f3 = Yabsm::Base::is_valid_time('24:0');
    my $f4 = Yabsm::Base::is_valid_time('0:60');
    my $f5 = Yabsm::Base::is_valid_time('120:60');

    my $trues = $t1 && $t2 && $t3 && $t4 && $t5;
    my $falses = not( $f1 || $f2 || $f3 || $f4 || $f5);

    ok ( $trues && $falses, 'is_valid_time()' );
}

test_is_snapstring();
sub test_is_snapstring {

    my $t1 = Yabsm::Base::is_snapstring('/some/path/day=2020_12_25,time=10:40');
    my $t2 = Yabsm::Base::is_snapstring('day=2020_12_25,time=10:40');
    my $t3 = Yabsm::Base::is_snapstring('day=8459_34_98,time=67:90');
    my $t4 = Yabsm::Base::is_snapstring('  day=2020_12_25,time=12:30');

    my $f1 = Yabsm::Base::is_snapstring('');
    my $f2 = Yabsm::Base::is_snapstring(' ');
    my $f3 = Yabsm::Base::is_snapstring('da=2020_12_25,time=10:30');
    my $f4 = Yabsm::Base::is_snapstring('/some/path/day=202_12_25,time=10:40');
    my $f5 = Yabsm::Base::is_snapstring('day=2020_1_25,time=10:40');
    my $f6 = Yabsm::Base::is_snapstring('day=2020_12_2,time=10:40');
    my $f7 = Yabsm::Base::is_snapstring('day=2020_12_25,time=1:40');
    my $f8 = Yabsm::Base::is_snapstring('day=2020_12_25,time=10:4');
    my $f9 = Yabsm::Base::is_snapstring('day=2020_12_25,time=12:30   ');

    my $trues = $t1 && $t2 && $t3 && $t4;

    my $falses = not ($f1 || $f2 || $f3 || $f4 || $f5 || $f6 || $f7 || $f8 || $f9);

    ok ( $trues && $falses, 'is_snapstring()')
}

test_current_time_snapstring();
sub test_current_time_snapstring {

    my $ct = Yabsm::Base::current_time_snapstring();

    my $test = $ct =~ /^day=\d{4}_\d{2}_\d{2},time=\d{2}:\d{2}$/;

    ok ( $test, 'current_time_snapstring()' );
}

test_local_yabsm_dir();
sub test_local_yabsm_dir {

    my %config = gen_random_config();

    my $snapshot_root_dir = $config{misc}{yabsm_dir};

    my $subvol = [Yabsm::Base::all_subvols(\%config)]->[0];

    # TEST 1

    my $output1 = Yabsm::Base::local_yabsm_dir(\%config);

    my $solution1 = "$snapshot_root_dir";

    my $correct1 = $output1 eq $solution1;

    # TEST 2

    my $output2 = Yabsm::Base::local_yabsm_dir(\%config, $subvol);

    my $solution2 = "$snapshot_root_dir/$subvol";

    my $correct2 = $output2 eq $solution2;

    # TEST 3

    my $output3 = Yabsm::Base::local_yabsm_dir(\%config, $subvol, '5minute');

    my $solution3 = "$snapshot_root_dir/$subvol/5minute";

    my $correct3 = $output3 eq $solution3;

    ok ( $correct1 && $correct2 && $correct3, 'local_yabsm_dir()' );
}

test_is_day_of_week();
sub test_is_day_of_week {

    my $t1 = Yabsm::Base::is_day_of_week('monday');
    my $t2 = Yabsm::Base::is_day_of_week('tuesday');
    my $t3 = Yabsm::Base::is_day_of_week('wednesday');
    my $t4 = Yabsm::Base::is_day_of_week('thursday');
    my $t5 = Yabsm::Base::is_day_of_week('friday');
    my $t6 = Yabsm::Base::is_day_of_week('saturday');
    my $t7 = Yabsm::Base::is_day_of_week('sunday');

    my $f1  = Yabsm::Base::is_day_of_week('mon');
    my $f2  = Yabsm::Base::is_day_of_week('tue');
    my $f3  = Yabsm::Base::is_day_of_week('wed');
    my $f4  = Yabsm::Base::is_day_of_week('thu');
    my $f5  = Yabsm::Base::is_day_of_week('fri');
    my $f6  = Yabsm::Base::is_day_of_week('sat');
    my $f7  = Yabsm::Base::is_day_of_week('MONDAY');
    my $f8  = Yabsm::Base::is_day_of_week('Monday');
    my $f9  = Yabsm::Base::is_day_of_week('mOnday');
    my $f10 = Yabsm::Base::is_day_of_week('moNday');
    my $f11 = Yabsm::Base::is_day_of_week(' monday');
    my $f12 = Yabsm::Base::is_day_of_week('monday ');
    my $f13 = Yabsm::Base::is_day_of_week(' monday ');
    my $f14 = Yabsm::Base::is_day_of_week('mondays');

    my $trues =  $t1 && $t2 && $t3 && $t4 && $t5 && $t6 && $t7;

    my $falses = not( $f1 || $f2 || $f3 || $f4 || $f5 || $f6 || $f7 ||
                      $f8 || $f9 || $f10 || $f11 || $f12 || $f13 || $f14);

    ok ( $trues && $falses, 'is_day_of_week()' );
}

test_day_of_week_num();
sub test_day_of_week_num {

    my $t1 = 1 == Yabsm::Base::day_of_week_num('monday');
    my $t2 = 2 == Yabsm::Base::day_of_week_num('tuesday');
    my $t3 = 3 == Yabsm::Base::day_of_week_num('wednesday');
    my $t4 = 4 == Yabsm::Base::day_of_week_num('thursday');
    my $t5 = 5 == Yabsm::Base::day_of_week_num('friday');
    my $t6 = 6 == Yabsm::Base::day_of_week_num('saturday');
    my $t7 = 7 == Yabsm::Base::day_of_week_num('sunday');

    my $correct =  $t1 && $t2 && $t3 && $t4 && $t5 && $t6 && $t7;

    ok ( $correct, 'day_of_week_num()' );
}

test_all_timeframes();
sub test_all_timeframes {

    my @expected = qw(5minute hourly midnight weekly monthly);

    my @got = Yabsm::Base::all_timeframes();

    is_deeply ( \@got, \@expected, 'all_timeframes()' );
}

test_is_subvol_timeframe();
sub test_is_subvol_timeframe {

    my $t1 = Yabsm::Base::is_timeframe('5minute');
    my $t2 = Yabsm::Base::is_timeframe('hourly');
    my $t3 = Yabsm::Base::is_timeframe('midnight');
    my $t4 = Yabsm::Base::is_timeframe('weekly');
    my $t5 = Yabsm::Base::is_timeframe('monthly');

    my $f1 = Yabsm::Base::is_timeframe('_5minute');
    my $f2 = Yabsm::Base::is_timeframe('');
    my $f3 = Yabsm::Base::is_timeframe(' ');
    my $f4 = Yabsm::Base::is_timeframe('not a timeframe');
    my $f5 = Yabsm::Base::is_timeframe(' hourly');
    my $f6 = Yabsm::Base::is_timeframe('hourly ');
    my $f7 = Yabsm::Base::is_timeframe(' hourly ');
    my $f8 = Yabsm::Base::is_timeframe('HOURLY');

    my $trues = $t1 && $t2 && $t3 && $t4 && $t5;
    my $falses = not($f1 || $f2 || $f3 || $f4 || $f5 || $f6 || $f7 || $f8);

    ok ( $trues && $falses, 'is_timeframe()' );
}

test_timeframe_want();
sub test_timeframe_want {

    my $config_ref = gen_random_config();

    my $t = 1;
    for my $subvol (Yabsm::Base::all_subvols($config_ref)) {
        for my $tframe (Yabsm::Base::all_timeframes()) {
            if ('yes' eq $config_ref->{subvols}{$subvol}{"${tframe}_want"}) {
                $t = 0 unless Yabsm::Base::timeframe_want($config_ref, $subvol, $tframe);
            }
            else {
                $t = 0 if Yabsm::Base::timeframe_want($config_ref, $subvol, $tframe);
            }
        }
    }

    ok ( $t, 'timeframe_want()' );
}

test_subvols_timeframes();
sub test_subvols_timeframes {

    my $config_ref = gen_random_config();

    my $t = 1;
    for my $subvol (Yabsm::Base::all_subvols($config_ref)) {

        my @subvols_timeframes = Yabsm::Base::subvols_timeframes($config_ref, $subvol);

        for my $tf (@subvols_timeframes) {
            $t = 0 if not 'yes' eq $config_ref->{subvols}{$subvol}{"${tf}_want"};
        }
    }

    ok ( $t, 'subvols_timeframes()' );
}

test_bootstrap_snap_dir();
sub test_bootstrap_snap_dir {
    
    my %config = gen_random_config();

    my $yabsm_dir = $config{misc}{yabsm_dir};

    my $backup = [Yabsm::Base::all_backups(\%config)]->[0];

    my $subvol = $config{backups}{$backup}{subvol};

    my $got = Yabsm::Base::bootstrap_snap_dir(\%config, $backup);

    my $expected = "$yabsm_dir/.cache/$subvol/backups/$backup/bootstrap-snap";

    is ( $got, $expected, 'bootstrap_snap_dir()' );
}
