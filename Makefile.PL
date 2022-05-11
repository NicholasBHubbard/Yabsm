#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Generic Perl application Makefile.

use strict;
use warnings;
use v5.16.3;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'yabsm',
    AUTHOR       => 'Nicholas Hubbard <nicholashubbard@posteo.net',
    VERSION_FROM => 'src/yabsm.pl',
    LICENSE      => 'MIT',
    EXE_FILES    => [
        'src/yabsm.pl'
    ],
    PREREQ_PM    => {
        'lib::relative' => '1.000',
        'Array::Utils'  => '0.5',
        'List::Util'    => '1.33',
        'Net::OpenSSH'  => '0.80',
        'Parser::MGC'   => '0.19',
    },
    TEST_REQUIRES => {
        'Test::Exception' => '0.43'
    }
);
