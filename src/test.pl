#!/usr/bin/env perl

use strict;
use warnings;
use v5.16.3;

use Array::Utils 'array_minus';

my @def = qw ( hourly_want
               midnight_want
               hourly_keep
               mountpoint
               monthly_keep
               5minute_want
               weekly_want
               monthly_want
               weekly_keep
               weekly_day
             );

my @req = qw(mountpoint 5minute_want hourly_want midnight_want weekly_want monthly_want);

 if (my @missing = array_minus(@req, @def)) {
     say for @missing;
 }
