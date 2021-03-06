#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  Testing for Yabsm.pm

use strict;
use warnings;
use 5.010;

use Test::More 'no_plan';

use FindBin '$Bin';
use lib "$Bin";
use Yabsm;

use Time::Piece;
use Time::Seconds;

                 ####################################
                 #               TESTS              #
                 ####################################

test_all_snapshots();
sub test_all_snapshots {

    # In order to run this test you must have yabsm configured to be taking
    # snapshots of a subvolume called 'root', and your snapshot root directory
    # must be '/.snapshots'.
    
    my @yabsm_all_snapshots = Yabsm::all_snapshots('root', 'hourly');

    my @ls_all_snapshots = `ls /.snapshots/yabsm/root/hourly/`;

    ok (
	scalar @yabsm_all_snapshots == scalar @ls_all_snapshots,
	'all_snapshots()'
       );
}
 
test_snap_later();
sub test_snap_later {

    my $snap1 = '/some/path/day=2021_03_12,time=00:00';
    my $snap2 = 'day=2020_03_12,time=00:00';
    
    ok ( Yabsm::snap_later($snap1,$snap2), 'snap_later()' );
}

test_snap_earlier();
sub test_snap_earlier {

    my $snap1 = '/some/path/day=2020_03_12,time=00:00';
    my $snap2 = 'day=2021_03_12,time=00:00';
    
    ok ( Yabsm::snap_earlier($snap1,$snap2), 'snap_earlier()' );
}

test_snap_equal();
sub test_snap_equal {

    my $snap1 = '/some/path/day=2020_03_12,time=00:00';
    my $snap2 = 'day=2020_03_12,time=00:00';
    
    ok ( Yabsm::snap_equal($snap1, $snap2), 'snap_equal()' );
}

sub test_latest_snap {

    my @snaps = ('day=2023_03_12,time=00:00',
		 'day=2024_03_12,time=00:00',
		 'day=2022_03_12,time=00:00',
		 'day=2020_03_12,time=00:00',
		 'day=2021_03_12,time=00:00'
		);

    my $earliest_snap = Yabsm::earliest_snap(\@snaps);

    ok ( $earliest_snap eq 'day=2024_03_12,time=00:00', 'earliest_snap()');
}

test_earliest_snap();
sub test_earliest_snap {

    my @snaps = ('day=2024_03_12,time=00:00',
		 'day=2023_03_12,time=00:00',
		 'day=2022_03_12,time=00:00',
		 'day=2020_03_12,time=00:00',
		 'day=2021_03_12,time=00:00'
		);

    my $earliest_snap = Yabsm::earliest_snap(\@snaps);

    ok ( $earliest_snap eq 'day=2020_03_12,time=00:00', 'earliest_snap()' );
}

test_sort_snapshots();
sub test_sort_snapshots {

    my @unsorted = ('day=2024_03_12,time=00:00',
		    'day=2022_03_12,time=00:00',
		    'day=2021_03_12,time=00:00',
		    'day=2020_03_12,time=00:00',
		    'day=2023_03_12,time=00:00'
		   );

    my @solution = (
		    'day=2024_03_12,time=00:00',
		    'day=2023_03_12,time=00:00',
		    'day=2022_03_12,time=00:00',
		    'day=2021_03_12,time=00:00',
		    'day=2020_03_12,time=00:00'
		   );

    my @sorted = Yabsm::sort_snapshots(\@unsorted);

    my $no_diff = 1;
    for (my $i = 0; $i < scalar @sorted; $i++) {
      $no_diff = 0 if $solution[$i] ne $sorted[$i];
    }
    ok ($no_diff, 'sort_snapshots()');
}

test_nums_to_snap();
sub test_nums_to_snap {

    my $t = Yabsm::nums_to_snap(2020, 3, 2, 23, 15);

    ok( $t eq 'day=2020_03_02,time=23:15', 'nums_to_snap()' );
}

test_snap_to_nums();
sub test_snap_to_nums {

    my $time = 'day=2020_03_02,time=23:15';

    my @nums = Yabsm::snap_to_nums($time);

    my @solution = ('2020','03','02','23','15');

    my $no_diff = 1;
    for (my $i = 0; $i < scalar @nums; $i++) {
	$no_diff = 0 if $solution[$i] ne $nums[$i];
    }
    ok ( $no_diff, 'snap_to_nums()' );
}

test_snap_to_time_obj();
sub test_snap_to_time_obj {
    
    my $time = 'day=2020_03_02,time=23:15';

    my $time_obj = Yabsm::snap_to_time_obj($time);

    $time_obj += ONE_YEAR;

    my $yr = $time_obj->year;

    ok ( $yr eq '2021', 'snap_to_time_obj()')
    
}

test_time_obj_to_snap();
sub test_time_obj_to_snap {

    my $time_obj =
      Time::Piece->strptime("2020/3/06/12/0",'%Y/%m/%d/%H/%M');

    my $time = Yabsm::time_obj_to_snap($time_obj);

    ok ($time eq  'day=2020_03_06,time=12:00', 'time_obj_to_snap()');
}

test_add_n_hours();
sub test_add_n_hours {

    my $t0 = 'day=2020_12_31,time=23:00';

    my $t1 = Yabsm::add_n_hours($t0, 26);

    ok ($t1 eq  'day=2021_01_02,time=01:00', 'add_n_hours()');
}

test_add_n_minutes();
sub test_add_n_minutes {

    my $t0 = 'day=2020_12_31,time=23:00';

    my $t1 = Yabsm::add_n_minutes($t0, 70);

    ok ($t1 eq  'day=2021_01_01,time=00:10', 'add_n_minutes()');
}

test_subtract_n_hours();
sub test_subtract_n_hours {

    my $t0 = 'day=2021_01_02,time=01:00';

    my $t1 = Yabsm::subtract_n_hours($t0, 26);

    ok ($t1 eq 'day=2020_12_31,time=23:00','subtract_n_hours()');
}

test_subtract_n_minutes();
sub test_subtract_n_minutes {

    my $t0 = 'day=2021_01_01,time=00:10';

    my $t1 = Yabsm::subtract_n_minutes($t0, 70);

    ok ($t1 eq 'day=2020_12_31,time=23:00', 'subtract_n_minutes()');
}
