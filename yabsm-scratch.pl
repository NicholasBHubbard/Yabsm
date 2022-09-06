#!/usr/bin/env perl

use strict;
use warnings;
use v5.16.3;


my $v = '10:40';


my $rx = qr/(((0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]),)+((0[0-9]|1[0-9]|2[0-3]):[0-5][0-9])|((0[0-9]|1[0-9]|2[0-3]):[0-5][0-9])/;


if ($v =~ $rx) {
    say 'Matches';
}
else {
    say 'No match';
}
