#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Testing for the Yabsm::Tools library.

use strict;
use warnings;
use v5.16.3;

use Yabsm::Tools;

use Test::More 'no_plan';
use Test::Exception;

                 ####################################
                 #               TESTS              #
                 ####################################

{
    my $n = 'die_arg_count';
    my $f = \&Yabsm::Tools::die_arg_count;

    throws_ok { $f->(1,1,73,37) } qr/passed 2 args but takes 1 arg/, "$n - dies with single number range";
    throws_ok { $f->(1,2,73,37,42) } qr/passed 3 args but takes 1-2 args/, "$n - dies with bounded range";
    throws_ok { $f->(2,1,73,37,42) } qr/passed 3 args but takes 1-2 args/, "$n - swaps upper lower ranges";
    throws_ok { $f->(1,1,73) } qr/called die_arg_count\(\) but arg count is in range/, "$n - detects valid arg range";
}

{
    my $n = 'nums_denote_valid_date';
    my $f = \&Yabsm::Tools::nums_denote_valid_date;

    is($f->(2020,5,13,23,59), 1, "$n - succeeds if valid date");
    is($f->(0,5,13,23,59), 0, "$n - fails if invalid year");
    is($f->(2020,13,13,23,59), 0, "$n - fails if invalid month");
    is($f->(2020,5,32,23,59), 0, "$n - fails if invalid month day");
    is($f->(2020,5,13,24,59), 0, "$n - fails if invalid hour");
    is($f->(2020,5,13,23,60), 0, "$n - fails if invalid minute");
    is($f->(2020,4,31,23,59), 0, "$n - understands number of days in different months");
    is($f->(2019,2,29,23,59), 0, "$n - understands non leap year february");
    is($f->(2020,2,29,23,59), 1, "$n - understands leap year february");
}

{
    my $n = 'nums_denote_valid_date_or_die';
    my $f = \&Yabsm::Tools::nums_denote_valid_date_or_die;

    is($f->(2020,5,13,23,59), 1, "$n - succeeds if valid date");
    throws_ok { $f->(0,5,13,23,59) } qr/'0_5_13_23:59' does not denote a valid yr_mon_day_hr:min date/, "$n - dies if invalid date";
}
1;
