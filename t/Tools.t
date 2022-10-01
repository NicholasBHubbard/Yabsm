#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Testing for the Yabsm::Tools library.

use strict;
use warnings;
use v5.16.3;

use App::Yabsm::Tools;

use Test::More 'no_plan';
use Test::Exception;

                 ####################################
                 #               TESTS              #
                 ####################################

{
    my $n = 'arg_count_or_die';
    my $f = \&App::Yabsm::Tools::arg_count_or_die;

    lives_ok { $f->(1,2,73,37) } "$n - lives if correct number of args";
    throws_ok { $f->(1,1,73,37) } qr/called 'main::__ANON__' with 2 args but it expects 1 arg/, "$n - dies with single number range";
    lives_ok { $f->(1,1,73) } "$n - lives if specific arg num";
    throws_ok { $f->(1,2,73,37,42) } qr/called 'main::__ANON__' with 3 args but it expects 1-2 args/, "$n - dies with bounded range";
    lives_ok { $f->('_', '2', 73,37)} "$n - accepts less or equal to N args when first arg is '_'";
    throws_ok { $f->('_', '2', 73,37,3) } qr/called 'main::__ANON__' with 3 args but it expects 0-2 args/, "$n - dies if more than N args";
    lives_ok { $f->(2,'_',73,37) } "$n - accepts at least N args when second arg is '_'";
    lives_ok { $f->(2,'_',73,37,42) } "$n - accepts at greater than N args when second arg is '_'";
    throws_ok { $f->(2,'_',73) } qr/called 'main::__ANON__' with 1 args but it expects at least 2 args/, "$n - dies if not at least N args";
    lives_ok { $f->('_','_') } "$n - allows any number of args when both args eq '_'";
}

{
    my $n = 'nums_denote_valid_date';
    my $f = \&App::Yabsm::Tools::nums_denote_valid_date;

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
    my $f = \&App::Yabsm::Tools::nums_denote_valid_date_or_die;

    is($f->(2020,5,13,23,59), 1, "$n - succeeds if valid date");
    throws_ok { $f->(0,5,13,23,59) } qr/'0_5_13_23:59' does not denote a valid yr_mon_day_hr:min date/, "$n - dies if invalid date";
}

{
    my $n = 'system_or_die';
    my $f = \&App::Yabsm::Tools::system_or_die;

    lives_and { is $f->('true'), 1 } "$n - succeeds if command succeeds";
    throws_ok { $f->('false') } qr/yabsm: internal error: system command 'false' exited with non-zero status/, "$n - dies if command fails";
}

1;
