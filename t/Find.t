#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Testing for the Yabsm::Command::Find library.

use strict;
use warnings;
use v5.16.3;

use App::Yabsm::Command::Find;

use Test::More 'no_plan';
use Test::Exception;

use Time::Piece;

                 ####################################
                 #               TESTS              #
                 ####################################

{
    my $n = 'n_units_ago_snapshot_name';
    my $f = \&App::Yabsm::Command::Find::n_units_ago_snapshot_name;

    my $t = localtime;
    my ($yr, $mon, $day, $hr, $min) = ($t->year, $t->mon, $t->mday, $t->hour, $t->min);
    my $tp_obj = Time::Piece->strptime("$yr/$mon/$day/$hr/$min", '%Y/%m/%d/%H/%M');

    my $this_t = $tp_obj - (10 * 60);
    ($yr, $mon, $day, $hr, $min) =
      map { sprintf '%02d', $_ } ($this_t->year, $this_t->mon, $this_t->mday, $this_t->hour, $this_t->min);

    is($f->(10,'minutes'), "yabsm-${yr}_${mon}_${day}_$hr:$min", "$n - correct 10 minutes ago");
    is($f->(10,'mins'), "yabsm-${yr}_${mon}_${day}_$hr:$min", "$n - accepts 'mins' abbreviation");
    is($f->(10,'m'), "yabsm-${yr}_${mon}_${day}_$hr:$min", "$n - accepts 10 'm' abbreviation");

    $this_t = $tp_obj - (10 * 3600);
    ($yr, $mon, $day, $hr, $min) =
      map { sprintf '%02d', $_ } ($this_t->year, $this_t->mon, $this_t->mday, $this_t->hour, $this_t->min);

    is($f->(10, 'hours'), "yabsm-${yr}_${mon}_${day}_$hr:$min", "$n - correct 10 hours ago");
    is($f->(10, 'hrs'), "yabsm-${yr}_${mon}_${day}_$hr:$min", "$n - accepts 'hrs' abbreviation");
    is($f->(10, 'h'), "yabsm-${yr}_${mon}_${day}_$hr:$min", "$n - accepts 'h' abbreviation");

    $this_t = $tp_obj - (10 * 86400);
    ($yr, $mon, $day, $hr, $min) =
      map { sprintf '%02d', $_ } ($this_t->year, $this_t->mon, $this_t->mday, $this_t->hour, $this_t->min);

    is($f->(10, 'days'), "yabsm-${yr}_${mon}_${day}_$hr:$min", "$n - correct 10 days ago");
    is($f->(10, 'd'), "yabsm-${yr}_${mon}_${day}_$hr:$min", "$n - accepts 'd' abbreviation");

    throws_ok { $f->(10, 'quux') } qr/'quux' is not a valid time unit/, "$n - rejects invalid time unit";
    throws_ok { $f->(0, 'days') } qr/'0' is not a positive integer/, "$n - rejects non-positive integer";
    throws_ok { $f->('quux', 'days') } qr/'quux' is not a positive integer/, "$n - rejects invalid amount";
}

{
    my $n = 'parse_query_or_die';
    my $f = \&App::Yabsm::Command::Find::parse_query_or_die;

    my $t = localtime;
    my ($yr, $mon, $day) = map { sprintf '%02d', $_ } $t->year, $t->mon, $t->mday;

    lives_and { is_deeply $f->('all'),   { type => 'all' } } "$n - parses 'all'";
    lives_and { is_deeply $f->('newest'), { type => 'newest'} } "$n - parses 'newest'";
    lives_and { is_deeply $f->('oldest'), { type => 'oldest'} } "$n - parses 'oldest'";

    lives_and { is_deeply $f->('2020_5_13_23:59'), { type => 'closest', target => 'yabsm-2020_05_13_23:59' } } "$n - parses 'yr_mon_day_hr_min'";
    lives_and { is_deeply $f->('2020_05_13'), { type => 'closest', target => 'yabsm-2020_05_13_00:00'} } "$n - parses 'yr_mon_day'";
    lives_and { is_deeply $f->('5_13_2:30'), { type => 'closest', target => "yabsm-${yr}_05_13_02:30" } } "$n - parses 'mon_day_hr:min'";
    lives_and { is_deeply $f->('5_13_23'), { type => 'closest', target => "yabsm-${yr}_05_13_23:00" } } "$n - parses 'mon_day_hr'";
    lives_and { is_deeply $f->('5_13'), { type => 'closest', target => "yabsm-${yr}_05_13_00:00" } } "$n - parses 'mon_day'";
    lives_and { is_deeply $f->('13_1:40'), { type => 'closest', target => "yabsm-${yr}_${mon}_13_01:40" } } "$n - parses 'day_hr:min'";
    lives_and { is_deeply $f->('23:59'), { type => 'closest', target => "yabsm-${yr}_${mon}_${day}_23:59" } } "$n - parses 'hr:min'";

    lives_and { is_deeply $f->('back-10-m'), { type => 'closest', target => App::Yabsm::Command::Find::n_units_ago_snapshot_name(10, 'm') } } "$n - basic relative target";
    lives_and { is_deeply $f->('b-10-m'), { type => 'closest', target => App::Yabsm::Command::Find::n_units_ago_snapshot_name(10, 'm') } } "$n - relative with 'b' abbreviation";

    lives_and { is_deeply $f->('before 2020_5_13_23:59'), { type => 'before', target => 'yabsm-2020_05_13_23:59'} } "$n - parses before query";
    lives_and { is_deeply $f->('before b-10-h'), { type => 'before', target => App::Yabsm::Command::Find::n_units_ago_snapshot_name(10,'hours') } } "$n - parses before query";

    lives_and { is_deeply $f->('after 2020_5_13_23:59'), { type => 'after', target => 'yabsm-2020_05_13_23:59'} } "$n - parses after query";
    lives_and { is_deeply $f->('after b-10-h'), { type => 'after', target => App::Yabsm::Command::Find::n_units_ago_snapshot_name(10,'hours') } } "$n - parses after query";

    lives_and { is_deeply $f->('between b-10-h 2020_5_13_23:59'), { type => 'between', target1 => App::Yabsm::Command::Find::n_units_ago_snapshot_name(10,'hours'), target2 => 'yabsm-2020_05_13_23:59' } } "$n - parses between query";

    throws_ok { $f->('quux') } qr/expected <time-abbreviation> or one of 'all', 'newest', 'oldest', 'before', 'after', 'between'/, "$n - rejects invalid query";

    throws_ok { $f->('1999_5_13_23:59') } qr/expected <time-abbreviation> or one of 'all', 'newest', 'oldest', 'before', 'after', 'between'/, "$n - rejects invalid year";
    throws_ok { $f->('2020_13_30_23:59') } qr/expected <time-abbreviation> or one of 'all', 'newest', 'oldest', 'before', 'after', 'between'/, "$n - rejects invalid month";
    throws_ok { $f->('2020_05_32_23:59') } qr/expected <time-abbreviation> or one of 'all', 'newest', 'oldest', 'before', 'after', 'between'/, "$n - rejects invalid day";
    throws_ok { $f->('2020_5_13_24:59') } qr/expected <time-abbreviation> or one of 'all', 'newest', 'oldest', 'before', 'after', 'between'/, "$n - rejects invalid hour";
    throws_ok { $f->('2020_13_32_23:60') } qr/expected <time-abbreviation> or one of 'all', 'newest', 'oldest', 'before', 'after', 'between'/, "$n - rejects invalid minute";

    throws_ok { $f->('b-10-m b-10-m') } qr/Expected end of input/, "$n - rejects extra input";
    throws_ok { $f->('all b-10-m') } qr/Expected end of input/, "$n - all rejects extra input";
    throws_ok { $f->('newest b-10-m') } qr/Expected end of input/, "$n - newest rejects extra input";
    throws_ok { $f->('oldest b-10-m') } qr/Expected end of input/, "$n - oldest rejects extra input";
    throws_ok { $f->('before b-10-m b-10-m') } qr/Expected end of input/, "$n - before rejects extra input";
    throws_ok { $f->('after b-10-m b-10-m') } qr/Expected end of input/, "$n - after rejects extra input";
    throws_ok { $f->('between b-10-m b-10-m b-10-m') } qr/Expected end of input/, "$n - between rejects extra input";

    throws_ok { $f->('before foo') } qr/expected time abbreviation/, "$n - before dies expecting time abbreviation";
    throws_ok { $f->('after foo') } qr/expected time abbreviation/, "$n - after dies expecting time abbreviation";
    throws_ok { $f->('between b-10-m foo') } qr/expected time abbreviation/, "$n - between dies expecting time abbreviation";
    throws_ok { $f->('between foo b-10-m') } qr/expected time abbreviation/, "$n - between dies expecting time abbreviation";
}

{
    my $n = 'answer_newest_query';
    my $f = \&App::Yabsm::Command::Find::answer_newest_query;

    my @snapshots = ('/foo/yabsm-2023_05_13_23:59', '/foo/yabsm-2022_05_13_23:59', '/foo/yabsm-2021_05_13_23:59', '/foo/yabsm-2020_05_13_23:59', '/foo/yabsm-2019_05_13_23:59',  '/foo/yabsm-2018_05_13_23:59');

    is_deeply [$f->(\@snapshots)], ['/foo/yabsm-2023_05_13_23:59'], "$n - returns newest snapshot";
    is_deeply [$f->([])], [undef], "$n - returns undef if empty list";
}

{
    my $n = 'answer_oldest_query';
    my $f = \&App::Yabsm::Command::Find::answer_oldest_query;

    my @snapshots = ('/foo/yabsm-2023_05_13_23:59', '/foo/yabsm-2022_05_13_23:59', '/foo/yabsm-2021_05_13_23:59', '/foo/yabsm-2020_05_13_23:59', '/foo/yabsm-2019_05_13_23:59',  '/foo/yabsm-2018_05_13_23:59');

    is_deeply [$f->(\@snapshots)], ['/foo/yabsm-2018_05_13_23:59'], "$n - returns oldest snapshot";
    is_deeply [$f->([])], [undef], "$n - returns undef if empty list";
}

{
    my $n = 'answer_after_query';
    my $f = \&App::Yabsm::Command::Find::answer_after_query;

    my @snapshots = ('/foo/yabsm-2023_05_13_23:59', '/foo/yabsm-2022_05_13_23:59', '/foo/yabsm-2021_05_13_23:59', '/foo/yabsm-2020_05_13_23:59', '/foo/yabsm-2019_05_13_23:59',  '/foo/yabsm-2018_05_13_23:59');

    is_deeply [$f->('yabsm-2020_05_13_23:59',\@snapshots)], ['/foo/yabsm-2023_05_13_23:59', '/foo/yabsm-2022_05_13_23:59', '/foo/yabsm-2021_05_13_23:59'] , "$n - returns snapshots after target";
    is_deeply [$f->('yabsm-2024_05_13_23:59', \@snapshots)], [], "$n - returns empty list if no snapshots newer";
}

{
    my $n = 'answer_before_query';
    my $f = \&App::Yabsm::Command::Find::answer_before_query;

    my @snapshots = ('/foo/yabsm-2023_05_13_23:59', '/foo/yabsm-2022_05_13_23:59', '/foo/yabsm-2021_05_13_23:59', '/foo/yabsm-2020_05_13_23:59', '/foo/yabsm-2019_05_13_23:59',  '/foo/yabsm-2018_05_13_23:59');

    is_deeply [$f->('yabsm-2020_05_13_23:59',\@snapshots)], ['/foo/yabsm-2019_05_13_23:59', '/foo/yabsm-2018_05_13_23:59'] , "$n - returns snapshots before target";
    is_deeply [$f->('yabsm-2017_05_13_23:59', \@snapshots)], [], "$n - returns empty list if no snapshots older";
}

{
    my $n = 'answer_between_query';
    my $f = \&App::Yabsm::Command::Find::answer_between_query;

    my @snapshots = ('/foo/yabsm-2023_05_13_23:59', '/foo/yabsm-2022_05_13_23:59', '/foo/yabsm-2021_05_13_23:59', '/foo/yabsm-2020_05_13_23:59', '/foo/yabsm-2019_05_13_23:59',  '/foo/yabsm-2018_05_13_23:59');

    is_deeply [$f->('yabsm-2022_05_13_23:59', 'yabsm-2020_05_13_23:59', \@snapshots)], ['/foo/yabsm-2022_05_13_23:59', '/foo/yabsm-2021_05_13_23:59', '/foo/yabsm-2020_05_13_23:59'] , "$n - returns snapshots between targets";

    is_deeply [$f->('yabsm-2020_05_13_23:59', 'yabsm-2022_05_13_23:59', \@snapshots)], ['/foo/yabsm-2022_05_13_23:59', '/foo/yabsm-2021_05_13_23:59', '/foo/yabsm-2020_05_13_23:59'] , "$n - target snapshot order doesn't matter";
    is_deeply [$f->('yabsm-2027_05_13_23:59', 'yabsm-2028_05_13_23:59', \@snapshots)], [] , "$n - returns empty list if no snapshots between";
}

{
    my $n = 'answer_closest_query';
    my $f = \&App::Yabsm::Command::Find::answer_closest_query;

    my @snapshots = ('/foo/yabsm-2023_05_13_23:59', '/foo/yabsm-2020_05_13_23:59', '/foo/yabsm-2019_05_13_23:59', '/foo/yabsm-2017_05_13_23:59');

    is_deeply [$f->('yabsm-2020_05_13_23:59', \@snapshots)], ['/foo/yabsm-2020_05_13_23:59'], "$n - returns exact match";
    is_deeply [$f->('yabsm-2022_05_13_23:59', \@snapshots)], ['/foo/yabsm-2023_05_13_23:59'], "$n - returns closer when newer";
    is_deeply [$f->('yabsm-2021_05_13_23:59', \@snapshots)], ['/foo/yabsm-2020_05_13_23:59'], "$n - returns closer when older";
    is_deeply [$f->('yabsm-2018_05_13_23:59', \@snapshots)], ['/foo/yabsm-2019_05_13_23:59'], "$n - returns newer when equidistant";
    is_deeply [$f->('yabsm-2024_05_13_23:59', \@snapshots)], ['/foo/yabsm-2023_05_13_23:59'], "$n - returns newest when newer than all";
    is_deeply [$f->('yabsm-2016_05_13_23:59', \@snapshots)], ['/foo/yabsm-2017_05_13_23:59'], "$n - returns oldest when older than all";
    is_deeply [$f->('yabsm-2018_05_13_23:59', [])], [], "$n - empty list if no snapshots";
}

1;
