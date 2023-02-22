use strict;
use warnings;

use v5.34.0;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'App::Yabsm',
    AUTHOR       => 'Nicholas Hubbard <nicholashubbard@posteo.net>',
    ABSTRACT     => 'a btrfs snapshot and backup management system',
    LICENSE      => 'gpl_3',
    VERSION_FROM => 'bin/yabsm',
    MIN_PERL_VERSION => '5.34.0',

    EXE_FILES => [
        'bin/yabsm'
    ],

    test => {
        TESTS => 't/*.t'
    },

    # Thanks App::FatPacker!
    PREREQ_PM => {},

    TEST_REQUIRES => {
        'Test::Exception' => 0,
    },

    META_MERGE => {
        resources => {
            repository  => 'https://github.com/NicholasBHubbard/Yabsm',
            bugtracker  => 'https://github.com/NicholasBHubbard/Yabsm/issues',
        },
    },
);
