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

# We expect Yabsm.pm to be in the same directory
use FindBin '$Bin';
use lib "$Bin";
use Yabsm;

# Only use this on arrays of strings.
use experimental 'smartmatch';

                 ####################################
                 #               TESTS              #
                 ####################################

test_all_snapshots();
sub test_all_snapshots {

    # In order to run this test you must have a yabsm subvolume called 'root'

    my $want_dump = 0;

    my @tframes = ('hourly', 'daily', 'midnight', 'monthly');

    my   @all_snaps;
    push @all_snaps, glob "/.snapshots/yabsm/root/$_/*" for @tframes;

    my @solution = Yabsm::sort_snapshots(\@all_snaps);

    my @output = Yabsm::all_snapshots('root');

    if ($want_dump) { print Dumper @output }

    ok (@output ~~ @solution, 'all_snapshots()' );
}

test_all_subvols();
sub test_all_subvols {

    # This test runs on a system that only has a 'root' subvolume.

    my $want_dump = 0;

    my $output = join "", Yabsm::all_subvols();

    if ($want_dump) { print Dumper $output }

    ok ( $output eq 'root', 'all_subvols()' );
}

test_sort_snapshots();
sub test_sort_snapshots {

    my $want_dump = 0;

    my @unsorted = ('day=2024_03_12,time=00:00',
		    'day=2022_03_12,time=00:00',
		    'day=2025_03_12,time=00:00',
		    'day=2021_03_12,time=00:00',
		    'day=2020_03_12,time=00:00',
		    'day=2023_03_12,time=00:00'
		   );

    my @solution = ('day=2025_03_12,time=00:00',
		    'day=2024_03_12,time=00:00',
		    'day=2023_03_12,time=00:00',
		    'day=2022_03_12,time=00:00',
		    'day=2021_03_12,time=00:00',
		    'day=2020_03_12,time=00:00'
		   );

    my @output = Yabsm::sort_snapshots(\@unsorted);

    if ($want_dump) { print Dumper @output }

    ok ( @output ~~ @solution, 'sort_snapshots()' );
}

test_snap_later();
sub test_snap_later {

    my $want_dump = 0;

    my $snap1 = '/some/path/day=2020_04_12,time=00:00';
    my $snap2 = 'day=2020_03_12,time=00:00';
    
    my $output = Yabsm::snap_later($snap1,$snap2); 

    if ($want_dump) { print Dumper $output }

    ok ( $output, 'snap_later()' );
}

test_snap_later_or_eq();
sub test_snap_later_or_eq {

    my $want_dump = 0;

    my $snap1 = 'day=2020_03_13,time=00:00';
    my $snap2 = 'day=2020_03_13,time=00:00';
    my $snap3 = 'day=2020_03_12,time=00:00';
    
    my $cond1 = Yabsm::snap_later_or_eq($snap1, $snap2);
    my $cond2 = Yabsm::snap_later_or_eq($snap2, $snap3);

    if ($want_dump) {
	print Dumper $cond1;
	print Dumper $cond2;
    }

    ok ( $cond1 && $cond2, 'snap_later_or_eq()' );
}

test_snap_earlier();
sub test_snap_earlier {

    my $want_dump = 0;

    my $snap1 = '/some/path/day=2020_03_12,time=00:00';
    my $snap2 = 'day=2021_03_12,time=00:00';
    
    my $output = Yabsm::snap_earlier($snap1,$snap2);

    if ($want_dump) { print Dumper $output }

    ok ( $output, 'snap_earlier()' );
}

test_snap_earlier_or_eq();
sub test_snap_earlier_or_eq {

    my $want_dump = 0;

    my $snap1 = 'day=2020_03_12,time=00:00';
    my $snap2 = 'day=2020_03_12,time=00:00';
    my $snap3 = 'day=2020_03_13,time=00:00';
    
    my $cond1 = Yabsm::snap_earlier_or_eq($snap1, $snap2);
    my $cond2 = Yabsm::snap_earlier_or_eq($snap2, $snap3);

    if ($want_dump) {
	print Dumper $cond1;
	print Dumper $cond2;
    }

    ok ( $cond1 && $cond2, 'snap_earlier_or_eq()' );
}

test_n_units_ago();
sub test_n_units_ago {

    my $want_dump = 0;

    # Test all the the unit string possibilities. Not dying means success here.
    my $test0 = Yabsm::n_units_ago(1, 'min');
    my $test1 = Yabsm::n_units_ago(1, 'mins');
    my $test2 = Yabsm::n_units_ago(1, 'hr');
    my $test3 = Yabsm::n_units_ago(1, 'hrs');
    my $test4 = Yabsm::n_units_ago(1, 'hour');
    my $test5 = Yabsm::n_units_ago(1, 'hours');
    my $test6 = Yabsm::n_units_ago(1, 'day');
    my $test7 = Yabsm::n_units_ago(1, 'days');

    # Test that the arithmetic works

    my $t = localtime();
    my $mins_ago  = Yabsm::time_piece_obj_to_snap($t - (120 * 60));
    my $hours_ago = Yabsm::time_piece_obj_to_snap($t - (2 * 3600));
    my $days_ago  = Yabsm::time_piece_obj_to_snap($t - (2 * 86400));

    my $min         = Yabsm::n_units_ago(120, 'min');
    my $min_correct = $min eq $mins_ago;

    my $hr          = Yabsm::n_units_ago(2, 'hr');
    my $hr_correct  = $hr eq $hours_ago;

    my $day         = Yabsm::n_units_ago(2, 'day');
    my $day_correct = $day eq $days_ago;

    if ($want_dump) {
	print "MINUTE\n";
	print Dumper $min;
	print "HOUR\n";
	print Dumper $hr;
	print "DAY\n";
	print Dumper $day;
    }

    ok ($min_correct && $hr_correct && $day_correct, 'n_units_ago()');
}

test_nums_to_snap();
sub test_nums_to_snap {

    my $want_dump = 0;

    my $output = Yabsm::nums_to_snap(2020, 3, 2, 23, 15);

    if ($want_dump) { print Dumper $output }

    ok( $output eq 'day=2020_03_02,time=23:15', 'nums_to_snap()' );
}

test_snap_to_nums();
sub test_snap_to_nums {

    my $want_dump = 0;

    my $time = 'day=2020_03_02,time=23:15';

    my @output = Yabsm::snap_to_nums($time);

    if ($want_dump) { print Dumper @output }

    my @solution = ('2020','03','02','23','15');

    ok ( @output ~~ @solution, 'snap_to_nums()' );
}

test_snap_to_time_piece_obj();
sub test_snap_to_time_piece_obj {
    
    my $want_dump = 0;

    my $time = 'day=2020_03_02,time=23:15';

    my $time_piece_obj = Yabsm::snap_to_time_piece_obj($time);

    my $output = $time_piece_obj->year;

    if ($want_dump) { print Dumper $output }

    ok ( $output eq '2020', 'snap_to_time_piece_obj()' );
}

test_time_piece_obj_to_snap();
sub test_time_piece_obj_to_snap {

    my $want_dump = 0;

    my $time_piece_obj =
      Time::Piece->strptime("2020/3/06/12/0",'%Y/%m/%d/%H/%M');

    my $output = Yabsm::time_piece_obj_to_snap($time_piece_obj);

    if ($want_dump) { print Dumper $output }

    ok ( $output eq  'day=2020_03_06,time=12:00', 'time_piece_obj_to_snap()' );
}

test_snap_n_units_ago();
sub test_snap_n_units_ago {

    my $want_dump = 0;

    my $t0 = Yabsm::n_units_ago(0,  'hr');
    my $t1 = Yabsm::n_units_ago(10, 'hr');
    my $t2 = Yabsm::n_units_ago(20, 'hr');
    my $t3 = Yabsm::n_units_ago(30, 'hr');
    my $t4 = Yabsm::n_units_ago(40, 'hr');
    my $t5 = Yabsm::n_units_ago(50, 'hr');

    my @all_snaps = ($t0, $t1, $t2, $t3, $t4, $t5);

    my $output = Yabsm::snap_n_units_ago(34, 'hr', \@all_snaps);

    if ($want_dump) { print Dumper $output }

    ok ( $output eq $t4, 'snap_n_units_ago()' );
}

test_valid_query();
sub test_valid_query {

    # these should all be true
    my $t0 = Yabsm::valid_query('b 4 m');
    my $t1 = Yabsm::valid_query('back 4 m');
    my $t2 = Yabsm::valid_query('back    4 min');
    my $t3 = Yabsm::valid_query('back  400   mins');
    my $t4 = Yabsm::valid_query('b 400 h');
    my $t5 = Yabsm::valid_query('b 400 hr');
    my $t6 = Yabsm::valid_query('b   400   hrs');
    my $t7 = Yabsm::valid_query('b 400 hour');
    my $t8 = Yabsm::valid_query('b 400 hours');

    # these should all be false
    my $f0 = Yabsm::valid_query('');
    my $f1 = Yabsm::valid_query('someting 4 min');
    my $f2 = Yabsm::valid_query('b 4 units');
    my $f3 = Yabsm::valid_query('back 4 minss');
    my $f4 = Yabsm::valid_query('back units');
    my $f5 = Yabsm::valid_query('back m');

    my $trues  = ($t0 && $t2 && $t4 && $t5 && $t6 && $t7 && $t8);
    my $falses = ! ($f0 || $f1 || $f2 || $f3 || $f4 || $f5);

    ok ( $trues && $falses, 'valid_query()' );
}

test_is_subvol();
sub test_is_subvol {

    # This test only succeeds if you have a subvol called 'root'

    my $t = Yabsm::is_subvol('root');
    my $f = Yabsm::is_subvol('anything');

    ok ( $t && ! $f, 'is_subvol()' );
}
