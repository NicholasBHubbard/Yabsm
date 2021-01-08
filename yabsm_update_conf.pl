#!/usr/bin/env perl

# Author: Nicholas Hubbard
# Email:  nhub73@keemail.me
# WWW:    https://github.com/NicholasBHubbard/yabsm

use strict;
use warnings;
use 5.010;

               ####################################
               #         GRAB USER SETTINGS       #
               ####################################

open (my $fh, '<:encoding(UTF-8)', '/etc/yabsmrc')
  or die 'failed to open file /etc/yabsmrc: $!';

my @lines = grep { m/^\s/ } readline $fh;

close $fh;

say @lines;
