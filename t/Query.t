#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Testing for the Yabsm::Config::Query library.

use strict;
use warnings;
use v5.16.3;

use App::Yabsm::Config::Query;

use Test::More 'no_plan';
use Test::Exception;

# Note that all foo_thing's have a maximum timeframes value.
my %TEST_CONFIG = ( yabsm_dir => '/.snapshots/yabsm/'
                  , subvols => { foo => { mountpoint => '/' }
                               , bar => { mountpoint => '/' }
                               , baz => { mountpoint => '/' }
                               }
                  , snaps   => { foo_snap => { subvol => 'foo'
                                             , timeframes => '5minute,hourly,daily,weekly,monthly'
                                             , '5minute_keep' => 36
                                             , hourly_keep => 48
                                             , daily_keep => 365
                                             , weekly_keep => 56
                                             , monthly_keep => 12
                                             , daily_times => '23:59,12:30,12:30'
                                             , weekly_day => 'wednesday'
                                             , weekly_time => '00:00'
                                             , monthly_day => 31
                                             , monthly_time => '23:59'
                                             }
                               , bar_snap => { subvol => 'bar'
                                             , timeframes => '5minute'
                                             , '5minute_keep' => '24'
                                             }
                               , baz_snap => { subvol => 'baz'
                                             , timeframes => 'hourly'
                                             , hourly_keep => '24'
                                             }
                               }
                  , ssh_backups => { foo_ssh_backup => { subvol => 'foo'
                                                       , ssh_dest => 'localhost'
                                                       , dir    => '/foo'
                                                       , timeframes => '5minute,hourly,daily,weekly,monthly'
                                                       , '5minute_keep' => 36
                                                       , hourly_keep => 48
                                                       , daily_keep => 365
                                                       , weekly_keep => 56
                                                       , monthly_keep => 12
                                                       , daily_times => '23:59,12:30,12:30'
                                                       , weekly_day => 'wednesday'
                                                       , weekly_time => '00:00'
                                                       , monthly_day => 31
                                                       , monthly_time => '23:59'
                                                       }
                                   , bar_ssh_backup => { subvol => 'bar'
                                                       , ssh_dest => 'localhost'
                                                       , dir => '/bar'
                                                       , timeframes => 'hourly'
                                                       , hourly_keep => 14
                                                       }

                                   , baz_ssh_backup => { subvol => 'baz'
                                                       , ssh_dest => 'localhost'
                                                       , dir => '/baz'
                                                       , timeframes => 'daily'
                                                       , daily_keep => 14
                                                       , daily_times => '23:59'
                                                       }
                                   }
                  , local_backups => { foo_local_backup => { subvol => 'foo'
                                                           , dir    => '/foo'
                                                           , timeframes => '5minute,hourly,daily,weekly,monthly'
                                                           , '5minute_keep' => 36
                                                           , hourly_keep => 48
                                                           , daily_keep => 365
                                                           , weekly_keep => 56
                                                           , monthly_keep => 12
                                                           , daily_times => '23:59,12:30,12:30'
                                                           , weekly_day => 'wednesday'
                                                           , weekly_time => '00:00'
                                                           , monthly_day => 31
                                                           , monthly_time => '23:59'
                                                           }
                                     , bar_local_backup => { subvol => 'bar'
                                                           , dir    => '/bar'
                                                           , timeframes => 'weekly'
                                                           , weekly_keep => 56
                                                           , weekly_day => 'monday'
                                                           , weekly_time => '00:00'
                                                           }

                                     , baz_local_backup => { subvol => 'baz'
                                                           , dir    => '/baz'
                                                           , timeframes => 'monthly'
                                                           , monthly_keep => 12
                                                           , monthly_day => '30'
                                                           , monthly_time => '00:00'
                                                           }
                                     }
                  );

                 ####################################
                 #               TESTS              #
                 ####################################

{
    my $n = 'subvol_exists';
    my $f = \&App::Yabsm::Config::Query::subvol_exists;

    is($f->('foo', \%TEST_CONFIG), 1, "$n - 1 when subvol exists");
    is($f->('quux', \%TEST_CONFIG), 0, "$n - 0 when subvol doesn't exist");
}

{
    my $n = 'subvol_exists_or_die';
    my $f = \&App::Yabsm::Config::Query::subvol_exists_or_die;

    is($f->('foo', \%TEST_CONFIG), 1, "$n - 1 when subvol exists");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no subvol named 'quux'/, "$n - dies if subvol doesn't exist";
}

{
    my $n = 'snap_exists';
    my $f = \&App::Yabsm::Config::Query::snap_exists;

    is($f->('foo_snap', \%TEST_CONFIG), 1, "$n - 1 when snap exists");
    is($f->('quux', \%TEST_CONFIG), 0, "$n - 0 when snap doesn't exist");
}

{
    my $n = 'snap_exists_or_die';
    my $f = \&App::Yabsm::Config::Query::snap_exists_or_die;

    is($f->('foo_snap', \%TEST_CONFIG), 1, "$n - 1 when snap exists");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies if snap doesn't exist";
}

{
    my $n = 'ssh_backup_exists';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_exists;

    is($f->('foo_ssh_backup', \%TEST_CONFIG), 1, "$n - 1 when ssh_backup exists");
    is($f->('quux', \%TEST_CONFIG), 0, "$n - 0 when ssh_backup doesn't exist");
}

{
    my $n = 'ssh_backup_exists_or_die';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_exists_or_die;

    is($f->('foo_ssh_backup', \%TEST_CONFIG), 1, "$n - 1 when ssh_backup exists");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies if ssh_backup doesn't exist";
}

{
    my $n = 'local_backup_exists';
    my $f = \&App::Yabsm::Config::Query::local_backup_exists;

    is($f->('foo_local_backup', \%TEST_CONFIG), 1, "$n - 1 when local_backup exists");
    is($f->('quux', \%TEST_CONFIG), 0, "$n - 0 when local_backup doesn't exist");
}

{
    my $n = 'local_backup_exists_or_die';
    my $f = \&App::Yabsm::Config::Query::local_backup_exists_or_die;

    is($f->('foo_local_backup', \%TEST_CONFIG), 1, "$n - 1 when local_backup exists");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies if local_backup doesn't exist";
}

{
    my $n = 'backup_exists';
    my $f = \&App::Yabsm::Config::Query::backup_exists;
    is($f->('foo_ssh_backup', \%TEST_CONFIG), 1, "$n - 1 if given ssh_backup");
    is($f->('foo_local_backup', \%TEST_CONFIG), 1, "$n - 1 if given local_backup");
    is($f->('quux', \%TEST_CONFIG), 0, "$n - 0 if given neither ssh_backup or local_backup");
}

{
    my $n = 'backup_exists_or_die';
    my $f = \&App::Yabsm::Config::Query::backup_exists_or_die;

    is($f->('foo_ssh_backup', \%TEST_CONFIG), 1, "$n - 1 if given ssh_backup");
    is($f->('foo_local_backup', \%TEST_CONFIG), 1, "$n - 1 if given local_backup");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup or local_backup named 'quux'/, "$n - dies if neither ssh_backup or local_backup";
}

{
    my $n = 'all_subvols';
    my $f = \&App::Yabsm::Config::Query::all_subvols;

    is_deeply([ $f->(\%TEST_CONFIG) ], ['bar','baz','foo'], "$n -  correct subvol name list");
}

{
    my $n = 'all_snaps';
    my $f = \&App::Yabsm::Config::Query::all_snaps;

    my @arr = $f->(\%TEST_CONFIG);

    is_deeply([ $f->(\%TEST_CONFIG) ], ['bar_snap','baz_snap','foo_snap'], "$n -  correct snap name list");
}

{
    my $n = 'all_ssh_backups';
    my $f = \&App::Yabsm::Config::Query::all_ssh_backups;

    is_deeply([ $f->(\%TEST_CONFIG) ], ['bar_ssh_backup', 'baz_ssh_backup','foo_ssh_backup'], "$n -  correct ssh_backup name list");
}

{
    my $n = 'all_local_backups';
    my $f = \&App::Yabsm::Config::Query::all_local_backups;

    is_deeply([ $f->(\%TEST_CONFIG) ], ['bar_local_backup', 'baz_local_backup','foo_local_backup'], "$n -  correct local_backup name list");
}

{
    my $n = 'subvol_mountpoint';
    my $f = \&App::Yabsm::Config::Query::subvol_mountpoint;

    is($f->('foo', \%TEST_CONFIG), '/', "$n - got correct mountpoint");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no subvol named 'quux'/, "$n - dies if non-existent subvol";
}

{
    my $n = 'all_snaps_of_subvol';
    my $f = \&App::Yabsm::Config::Query::all_snaps_of_subvol;

    is_deeply([ $f->('foo', \%TEST_CONFIG) ], [ 'foo_snap' ], "$n -  correct snap list");
}

{
    my $n = 'all_ssh_backups_of_subvol';
    my $f = \&App::Yabsm::Config::Query::all_ssh_backups_of_subvol;

    is_deeply([ $f->('foo', \%TEST_CONFIG) ], [ 'foo_ssh_backup' ], "$n -  correct ssh_backup list");
}

{
    my $n = 'all_local_backups_of_subvol';
    my $f = \&App::Yabsm::Config::Query::all_local_backups_of_subvol;

    is_deeply([ $f->('foo', \%TEST_CONFIG) ], [ 'foo_local_backup' ], "$n -  correct local_backup list");
}

{
    my $n = 'snap_subvol';
    my $f = \&App::Yabsm::Config::Query::snap_subvol;

    is($f->('foo_snap', \%TEST_CONFIG), 'foo', "$n - correct subvol");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies on non-existent snap"
}

{
    my $n = 'snap_mountpoint';
    my $f = \&App::Yabsm::Config::Query::snap_mountpoint;

    is($f->('foo_snap', \%TEST_CONFIG), '/', "$n - correct mountpoint");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies on non-existent snap"
}

{
    my $n = 'snap_dest';
    my $f = \&App::Yabsm::Config::Query::snap_dest;

    is($f->('foo_snap', '5minute', \%TEST_CONFIG), '/.snapshots/yabsm/foo_snap/5minute', "$n - correct dir with timeframe");
    is($f->('foo_snap', undef, \%TEST_CONFIG), '/.snapshots/yabsm/foo_snap', "$n - correct dir without timeframe");
    throws_ok { $f->('quux', '5minute', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies if non-existent snap";
    throws_ok { $f->('foo_snap', 'quux', \%TEST_CONFIG) } qr/no such timeframe 'quux'/, "$n - dies if non-existent timeframe";
}

{
    my $n = 'snap_timeframes';
    my $f = \&App::Yabsm::Config::Query::snap_timeframes;

    is_deeply([ $f->('foo_snap', \%TEST_CONFIG) ], [ '5minute', 'daily', 'hourly', 'monthly', 'weekly' ], "$n - correct timeframes comma seperated");
    is_deeply([ $f->('bar_snap',  \%TEST_CONFIG )], [ '5minute' ], "$n - correct timeframes single timeframes");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies on non-existent snap"
}

{
    my $n = 'ssh_backup_subvol';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_subvol;

    is($f->('foo_ssh_backup', \%TEST_CONFIG), 'foo', "$n - correct subvol");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies on non-existent ssh_backup";
}

{
    my $n = 'ssh_backup_mountpoint';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_mountpoint;

    is($f->('foo_ssh_backup', \%TEST_CONFIG), '/', "$n - correct mountpoint");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies on non-existent ssh_backup"
}

{
    my $n = 'ssh_backup_dir';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_dir;

    is($f->('foo_ssh_backup', 'hourly', \%TEST_CONFIG), '/foo/hourly', "$n - correct dir with timeframe");
    is($f->('foo_ssh_backup', undef, \%TEST_CONFIG), '/foo', "$n - correct dir without timeframe");
    throws_ok { $f->('quux', 'hourly', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies on non-existent ssh_backup";
    throws_ok { $f->('foo_ssh_backup', 'quux', \%TEST_CONFIG) } qr/no such timeframe 'quux'/, "$n - dies on non-existent ssh_backup";
}

{
    my $n = 'ssh_backup_timeframes';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_timeframes;

    is_deeply([ $f->('foo_ssh_backup', \%TEST_CONFIG) ], [ '5minute', 'daily', 'hourly', 'monthly', 'weekly' ], "$n - correct timeframes comma seperated");
    is_deeply([ $f->('bar_ssh_backup', \%TEST_CONFIG) ], [ 'hourly' ], "$n - correct timeframes single timeframes");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies on non-existent ssh_backup";
}

{
    my $n = 'ssh_backup_ssh_dest';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_ssh_dest;

    is($f->('foo_ssh_backup', \%TEST_CONFIG), 'localhost', "$n - correct ssh_dest");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies on non-existent ssh_backup";
}

{
    my $n = 'local_backup_subvol';
    my $f = \&App::Yabsm::Config::Query::local_backup_subvol;

    is($f->('foo_local_backup', \%TEST_CONFIG), 'foo', "$n - correct subvol");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies on non-existent local_backup";
}

{
    my $n = 'local_backup_dir';
    my $f = \&App::Yabsm::Config::Query::local_backup_dir;

    is($f->('foo_local_backup', 'hourly', \%TEST_CONFIG), '/foo/hourly', "$n - correct dir with timeframe");
    is($f->('foo_local_backup', undef, \%TEST_CONFIG), '/foo', "$n - correct dir without timeframe");
    throws_ok { $f->('quux', 'hourly', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies on non-existent local_backup";
    throws_ok { $f->('foo_local_backup', 'quux', \%TEST_CONFIG) } qr/no such timeframe 'quux'/, "$n - dies on non-existent ssh_backup";
}

{
    my $n = 'local_backup_mountpoint';
    my $f = \&App::Yabsm::Config::Query::local_backup_mountpoint;

    is($f->('foo_local_backup', \%TEST_CONFIG), '/', "$n - correct mountpoint");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies on non-existent local_backup"
}

{
    my $n = 'local_backup_timeframes';
    my $f = \&App::Yabsm::Config::Query::local_backup_timeframes;

    is_deeply([ $f->('foo_local_backup', \%TEST_CONFIG) ], [ '5minute', 'daily', 'hourly', 'monthly', 'weekly' ], "$n - correct timeframes comma seperated");
    is_deeply([ $f->('bar_local_backup', \%TEST_CONFIG) ], [ 'weekly' ], "$n - correct timeframes single timeframes");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies on non-existent local_backup";
}

{
    my $n = 'snap_wants_timeframe';
    my $f = \&App::Yabsm::Config::Query::snap_wants_timeframe;

    is($f->('foo_snap', 'hourly', \%TEST_CONFIG), 1, "$n - succeeds when does want");
    is($f->('bar_snap', 'hourly', \%TEST_CONFIG), 0, "$n - fails when doesn't want");
    throws_ok { $f->('quux', 'daily', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n dies on non-existent snap";
    throws_ok { $f->('foo_snap', 'quux', \%TEST_CONFIG) } qr/no such timeframe 'quux'/, "$n dies on invalid timeframe";
}

{
    my $n = 'snap_wants_timeframe_or_die';
    my $f = \&App::Yabsm::Config::Query::snap_wants_timeframe_or_die;

    is($f->('foo_snap', 'hourly', \%TEST_CONFIG), 1, "$n - succeeds when does want");
    throws_ok { $f->('bar_snap', 'hourly', \%TEST_CONFIG) } qr/snap 'bar_snap' is not taking hourly snapshots/, "$n - dies if doesn't want"
}

{
    my $n = 'ssh_backup_wants_timeframe';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_wants_timeframe;

    is($f->('foo_ssh_backup', 'daily', \%TEST_CONFIG), 1, "$n - succeeds when does want");
    is($f->('bar_ssh_backup', 'monthly', \%TEST_CONFIG), 0, "$n - fails when does want");
    throws_ok { $f->('quux', 'daily', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n dies on non-existent ssh_backup";
    throws_ok { $f->('foo_ssh_backup', 'quux', \%TEST_CONFIG) } qr/no such timeframe 'quux'/, "$n dies on invalid timeframe";
}

{
    my $n = 'ssh_backup_wants_timeframe_or_die';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_wants_timeframe_or_die;

    is($f->('foo_ssh_backup', 'daily', \%TEST_CONFIG), 1, "$n - succeeds when does want");
    throws_ok { $f->('bar_ssh_backup', 'monthly', \%TEST_CONFIG) } qr/ssh_backup 'bar_ssh_backup' is not taking monthly backups/, "$n - dies when does want";
}

{
    my $n = 'local_backup_wants_timeframe';
    my $f = \&App::Yabsm::Config::Query::local_backup_wants_timeframe;

    is($f->('foo_local_backup', 'daily', \%TEST_CONFIG), 1, "$n - succeeds when does want");
    is($f->('bar_local_backup', 'monthly', \%TEST_CONFIG), 0, "$n - fails when does want");
    throws_ok { $f->('quux', 'daily', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n dies on non-existent local_backup";
    throws_ok { $f->('foo_local_backup', 'quux', \%TEST_CONFIG) } qr/no such timeframe 'quux'/, "$n dies on invalid timeframe";
}

{
    my $n = 'local_backup_wants_timeframe_or_die';
    my $f = \&App::Yabsm::Config::Query::local_backup_wants_timeframe_or_die;

    is($f->('foo_local_backup', 'daily', \%TEST_CONFIG), 1, "$n - succeeds when does want");
    throws_ok { $f->('bar_local_backup', 'monthly', \%TEST_CONFIG) } qr/local_backup 'bar_local_backup' is not taking monthly backups/, "$n - dies when does want";
}

{
    my $n = 'snap_timeframe_keep';
    my $f = \&App::Yabsm::Config::Query::snap_timeframe_keep;

    is($f->('foo_snap', '5minute', \%TEST_CONFIG), 36, "$n - got correct 5minute_keep value");
    is($f->('foo_snap', 'hourly', \%TEST_CONFIG), 48, "$n - got correct hourly_keep value");
    is($f->('foo_snap', 'daily', \%TEST_CONFIG), 365, "$n - got correct daily_keep value");
    is($f->('foo_snap', 'weekly', \%TEST_CONFIG), 56, "$n - got correct weekly_keep value");
    is($f->('foo_snap', 'monthly', \%TEST_CONFIG), 12, "$n - got correct monthly_keep value");
    throws_ok { $f->('quux', '5minute', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies if non-existent snap";
    throws_ok { $f->('foo_snap', 'quux', \%TEST_CONFIG) } qr/no such timeframe 'quux'/, "$n - dies if non-existent timeframe";
}

{
    my $n = 'snap_5minute_keep';
    my $f = \&App::Yabsm::Config::Query::snap_5minute_keep;

    is($f->('foo_snap', \%TEST_CONFIG), 36, "$n - got correct 5minute_keep value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies if non-existent snap";
    throws_ok { $f->('baz_snap', \%TEST_CONFIG) } qr/snap 'baz_snap' is not taking 5minute snapshots/, "$n - dies if not taking 5minute snapshots";
}

{
    my $n = 'snap_hourly_keep';
    my $f = \&App::Yabsm::Config::Query::snap_hourly_keep;

    is($f->('foo_snap', \%TEST_CONFIG), 48, "$n - got correct hourly_keep value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies if non-existent snap";
    throws_ok { $f->('bar_snap', \%TEST_CONFIG) } qr/snap 'bar_snap' is not taking hourly snapshots/, "$n - dies if not taking hourly snapshots";
}

{
    my $n = 'snap_daily_keep';
    my $f = \&App::Yabsm::Config::Query::snap_daily_keep;

    is($f->('foo_snap', \%TEST_CONFIG), 365, "$n - got correct daily_keep value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies if non-existent snap";
    throws_ok { $f->('bar_snap', \%TEST_CONFIG) } qr/snap 'bar_snap' is not taking daily snapshots/, "$n - dies if not taking daily snapshots";
}

{
    my $n = 'snap_daily_times';
    my $f = \&App::Yabsm::Config::Query::snap_daily_times;

    is_deeply([$f->('foo_snap', \%TEST_CONFIG)], ['12:30','23:59'], "$n - got correct daily_times values (removed dups)");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies if non-existent snap";
    throws_ok { $f->('bar_snap', \%TEST_CONFIG) } qr/snap 'bar_snap' is not taking daily snapshots/, "$n - dies if not taking daily snapshots";
}

{
    my $n = 'snap_weekly_keep';
    my $f = \&App::Yabsm::Config::Query::snap_weekly_keep;

    is($f->('foo_snap', \%TEST_CONFIG), 56, "$n - got correct weekly_keep value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies if non-existent snap";
    throws_ok { $f->('bar_snap', \%TEST_CONFIG) } qr/snap 'bar_snap' is not taking weekly snapshots/, "$n - dies if not taking weekly snapshots";
}

{
    my $n = 'snap_weekly_time';
    my $f = \&App::Yabsm::Config::Query::snap_weekly_time;

    is($f->('foo_snap', \%TEST_CONFIG), '00:00', "$n - got correct weekly_time value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies if non-existent snap";
    throws_ok { $f->('bar_snap', \%TEST_CONFIG) } qr/snap 'bar_snap' is not taking weekly snapshots/, "$n - dies if not taking weekly snapshots";
}

{
    my $n = 'snap_weekly_day';
    my $f = \&App::Yabsm::Config::Query::snap_weekly_day;

    is($f->('foo_snap', \%TEST_CONFIG), 'wednesday', "$n - got correct weekly_day value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies if non-existent snap";
    throws_ok { $f->('bar_snap', \%TEST_CONFIG) } qr/snap 'bar_snap' is not taking weekly snapshots/, "$n - dies if not taking weekly snapshots";
}

{
    my $n = 'snap_monthly_keep';
    my $f = \&App::Yabsm::Config::Query::snap_monthly_keep;

    is($f->('foo_snap', \%TEST_CONFIG), 12, "$n - got correct monthly_keep value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies if non-existent snap";
    throws_ok { $f->('bar_snap', \%TEST_CONFIG) } qr/snap 'bar_snap' is not taking monthly snapshots/, "$n - dies if not taking monthly snapshots";
}

{
    my $n = 'snap_monthly_time';
    my $f = \&App::Yabsm::Config::Query::snap_monthly_time;

    is($f->('foo_snap', \%TEST_CONFIG), '23:59', "$n - got correct monthly_time value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies if non-existent snap";
    throws_ok { $f->('bar_snap', \%TEST_CONFIG) } qr/snap 'bar_snap' is not taking monthly snapshots/, "$n - dies if not taking monthly snapshots";
}

{
    my $n = 'snap_monthly_day';
    my $f = \&App::Yabsm::Config::Query::snap_monthly_day;

    is($f->('foo_snap', \%TEST_CONFIG), 31, "$n - got correct monthly_day value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no snap named 'quux'/, "$n - dies if non-existent snap";
    throws_ok { $f->('bar_snap', \%TEST_CONFIG) } qr/snap 'bar_snap' is not taking monthly snapshots/, "$n - dies if not taking monthly snapshots";
}

{
    my $n = 'ssh_backup_timeframe_keep';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_timeframe_keep;

    is($f->('foo_ssh_backup', '5minute', \%TEST_CONFIG), 36, "$n - got correct 5minute_keep value");
    is($f->('foo_ssh_backup', 'hourly', \%TEST_CONFIG), 48, "$n - got correct hourly_keep value");
    is($f->('foo_ssh_backup', 'daily', \%TEST_CONFIG), 365, "$n - got correct daily_keep value");
    is($f->('foo_ssh_backup', 'weekly', \%TEST_CONFIG), 56, "$n - got correct weekly_keep value");
    is($f->('foo_ssh_backup', 'monthly', \%TEST_CONFIG), 12, "$n - got correct monthly_keep value");
    throws_ok { $f->('quux', '5minute', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies if non-existent ssh_backup";
    throws_ok { $f->('foo_ssh_backup', 'quux', \%TEST_CONFIG) } qr/no such timeframe 'quux'/, "$n - dies if non-existent timeframe";
}

{
    my $n = 'ssh_backup_5minute_keep';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_5minute_keep;

    is($f->('foo_ssh_backup', \%TEST_CONFIG), 36, "$n - got correct 5minute_keep value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies if non-existent ssh_backup";
    throws_ok { $f->('baz_ssh_backup', \%TEST_CONFIG) } qr/ssh_backup 'baz_ssh_backup' is not taking 5minute backups/, "$n - dies if not taking 5minute backups";
}

{
    my $n = 'ssh_backup_hourly_keep';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_hourly_keep;

    is($f->('foo_ssh_backup', \%TEST_CONFIG), 48, "$n - got correct hourly_keep value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies if non-existent ssh_backup";
    throws_ok { $f->('baz_ssh_backup', \%TEST_CONFIG) } qr/ssh_backup 'baz_ssh_backup' is not taking hourly backups/, "$n - dies if not taking hourly backups";
}

{
    my $n = 'ssh_backup_daily_keep';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_daily_keep;

    is($f->('foo_ssh_backup', \%TEST_CONFIG), 365, "$n - got correct daily_keep value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies if non-existent ssh_backup";
    throws_ok { $f->('bar_ssh_backup', \%TEST_CONFIG) } qr/ssh_backup 'bar_ssh_backup' is not taking daily backups/, "$n - dies if not taking daily backups";
}

{
    my $n = 'ssh_backup_daily_times';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_daily_times;

    is_deeply([$f->('foo_ssh_backup', \%TEST_CONFIG)], ['12:30', '23:59'], "$n - got correct daily_times value (remove dups)");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies if non-existent ssh_backup";
    throws_ok { $f->('bar_ssh_backup', \%TEST_CONFIG) } qr/ssh_backup 'bar_ssh_backup' is not taking daily backups/, "$n - dies if not taking daily backups";
}

{
    my $n = 'ssh_backup_weekly_keep';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_weekly_keep;

    is($f->('foo_ssh_backup', \%TEST_CONFIG), 56, "$n - got correct weekly_keep value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies if non-existent ssh_backup";
    throws_ok { $f->('bar_ssh_backup', \%TEST_CONFIG) } qr/ssh_backup 'bar_ssh_backup' is not taking weekly backups/, "$n - dies if not taking weekly backups";
}

{
    my $n = 'ssh_backup_weekly_time';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_weekly_time;

    is($f->('foo_ssh_backup', \%TEST_CONFIG), '00:00', "$n - got correct weekly_time value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies if non-existent ssh_backup";
    throws_ok { $f->('bar_ssh_backup', \%TEST_CONFIG) } qr/ssh_backup 'bar_ssh_backup' is not taking weekly backups/, "$n - dies if not taking weekly backups";
}

{
    my $n = 'ssh_backup_weekly_day';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_weekly_day;

    is($f->('foo_ssh_backup', \%TEST_CONFIG), 'wednesday', "$n - got correct weekly_day value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies if non-existent ssh_backup";
    throws_ok { $f->('bar_ssh_backup', \%TEST_CONFIG) } qr/ssh_backup 'bar_ssh_backup' is not taking weekly backups/, "$n - dies if not taking weekly backups";
}

{
    my $n = 'ssh_backup_monthly_keep';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_monthly_keep;

    is($f->('foo_ssh_backup', \%TEST_CONFIG), 12, "$n - got correct monthly_keep value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies if non-existent ssh_backup";
    throws_ok { $f->('bar_ssh_backup', \%TEST_CONFIG) } qr/ssh_backup 'bar_ssh_backup' is not taking monthly backups/, "$n - dies if not taking monthly backups";
}

{
    my $n = 'ssh_backup_monthly_time';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_monthly_time;

    is($f->('foo_ssh_backup', \%TEST_CONFIG), '23:59', "$n - got correct monthly_time value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies if non-existent ssh_backup";
    throws_ok { $f->('bar_ssh_backup', \%TEST_CONFIG) } qr/ssh_backup 'bar_ssh_backup' is not taking monthly backups/, "$n - dies if not taking monthly backups";
}

{
    my $n = 'ssh_backup_monthly_day';
    my $f = \&App::Yabsm::Config::Query::ssh_backup_monthly_day;

    is($f->('foo_ssh_backup', \%TEST_CONFIG), 31, "$n - got correct monthly_day value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no ssh_backup named 'quux'/, "$n - dies if non-existent ssh_backup";
    throws_ok { $f->('bar_ssh_backup', \%TEST_CONFIG) } qr/ssh_backup 'bar_ssh_backup' is not taking monthly backups/, "$n - dies if not taking monthly backups";
}

{
    my $n = 'local_backup_timeframe_keep';
    my $f = \&App::Yabsm::Config::Query::local_backup_timeframe_keep;

    is($f->('foo_local_backup', '5minute', \%TEST_CONFIG), 36, "$n - got correct 5minute_keep value");
    is($f->('foo_local_backup', 'hourly', \%TEST_CONFIG), 48, "$n - got correct hourly_keep value");
    is($f->('foo_local_backup', 'daily', \%TEST_CONFIG), 365, "$n - got correct daily_keep value");
    is($f->('foo_local_backup', 'weekly', \%TEST_CONFIG), 56, "$n - got correct weekly_keep value");
    is($f->('foo_local_backup', 'monthly', \%TEST_CONFIG), 12, "$n - got correct monthly_keep value");
    throws_ok { $f->('quux', '5minute', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies if non-existent local_backup";
    throws_ok { $f->('foo_local_backup', 'quux', \%TEST_CONFIG) } qr/no such timeframe 'quux'/, "$n - dies if non-existent timeframe";
}

{
    my $n = 'local_backup_5minute_keep';
    my $f = \&App::Yabsm::Config::Query::local_backup_5minute_keep;

    is($f->('foo_local_backup', \%TEST_CONFIG), 36, "$n - got correct 5minute_keep value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies if non-existent local_backup";
    throws_ok { $f->('baz_local_backup', \%TEST_CONFIG) } qr/local_backup 'baz_local_backup' is not taking 5minute backups/, "$n - dies if not taking 5minute backups";
}

{
    my $n = 'local_backup_hourly_keep';
    my $f = \&App::Yabsm::Config::Query::local_backup_hourly_keep;

    is($f->('foo_local_backup', \%TEST_CONFIG), 48, "$n - got correct hourly_keep value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies if non-existent local_backup";
    throws_ok { $f->('baz_local_backup', \%TEST_CONFIG) } qr/local_backup 'baz_local_backup' is not taking hourly backups/, "$n - dies if not taking hourly backups";
}

{
    my $n = 'local_backup_daily_keep';
    my $f = \&App::Yabsm::Config::Query::local_backup_daily_keep;

    is($f->('foo_local_backup', \%TEST_CONFIG), 365, "$n - got correct daily_keep value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies if non-existent local_backup";
    throws_ok { $f->('bar_local_backup', \%TEST_CONFIG) } qr/local_backup 'bar_local_backup' is not taking daily backups/, "$n - dies if not taking daily backups";
}

{
    my $n = 'local_backup_daily_times';
    my $f = \&App::Yabsm::Config::Query::local_backup_daily_times;

    is_deeply([$f->('foo_local_backup', \%TEST_CONFIG)], ['12:30','23:59'], "$n - got correct daily_times value (removes dups)");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies if non-existent local_backup";
    throws_ok { $f->('bar_local_backup', \%TEST_CONFIG) } qr/local_backup 'bar_local_backup' is not taking daily backups/, "$n - dies if not taking daily backups";
}

{
    my $n = 'local_backup_weekly_keep';
    my $f = \&App::Yabsm::Config::Query::local_backup_weekly_keep;

    is($f->('foo_local_backup', \%TEST_CONFIG), 56, "$n - got correct weekly_keep value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies if non-existent local_backup";
    throws_ok { $f->('baz_local_backup', \%TEST_CONFIG) } qr/local_backup 'baz_local_backup' is not taking weekly backups/, "$n - dies if not taking weekly backups";
}

{
    my $n = 'local_backup_weekly_time';
    my $f = \&App::Yabsm::Config::Query::local_backup_weekly_time;

    is($f->('foo_local_backup', \%TEST_CONFIG), '00:00', "$n - got correct weekly_time value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies if non-existent local_backup";
    throws_ok { $f->('baz_local_backup', \%TEST_CONFIG) } qr/local_backup 'baz_local_backup' is not taking weekly backups/, "$n - dies if not taking weekly backups";
}

{
    my $n = 'local_backup_weekly_day';
    my $f = \&App::Yabsm::Config::Query::local_backup_weekly_day;

    is($f->('foo_local_backup', \%TEST_CONFIG), 'wednesday', "$n - got correct weekly_day value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies if non-existent local_backup";
    throws_ok { $f->('baz_local_backup', \%TEST_CONFIG) } qr/local_backup 'baz_local_backup' is not taking weekly backups/, "$n - dies if not taking weekly backups";
}

{
    my $n = 'local_backup_monthly_keep';
    my $f = \&App::Yabsm::Config::Query::local_backup_monthly_keep;

    is($f->('foo_local_backup', \%TEST_CONFIG), 12, "$n - got correct monthly_keep value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies if non-existent local_backup";
    throws_ok { $f->('bar_local_backup', \%TEST_CONFIG) } qr/local_backup 'bar_local_backup' is not taking monthly backups/, "$n - dies if not taking monthly backups";
}

{
    my $n = 'local_backup_monthly_time';
    my $f = \&App::Yabsm::Config::Query::local_backup_monthly_time;

    is($f->('foo_local_backup', \%TEST_CONFIG), '23:59', "$n - got correct monthly_time value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies if non-existent local_backup";
    throws_ok { $f->('bar_local_backup', \%TEST_CONFIG) } qr/local_backup 'bar_local_backup' is not taking monthly backups/, "$n - dies if not taking monthly backups";
}

{
    my $n = 'local_backup_monthly_day';
    my $f = \&App::Yabsm::Config::Query::local_backup_monthly_day;

    is($f->('foo_local_backup', \%TEST_CONFIG), 31, "$n - got correct monthly_day value");
    throws_ok { $f->('quux', \%TEST_CONFIG) } qr/no local_backup named 'quux'/, "$n - dies if non-existent local_backup";
    throws_ok { $f->('bar_local_backup', \%TEST_CONFIG) } qr/local_backup 'bar_local_backup' is not taking monthly backups/, "$n - dies if not taking monthly backups";
}

{
    my $n = 'is_timeframe';
    my $f = \&App::Yabsm::Config::Query::is_timeframe;

    is($f->('5minute'), 1, "$n - accepts '5minute'");
    is($f->('hourly'), 1, "$n - accepts 'hourly'");
    is($f->('daily'), 1, "$n - accepts 'daily'");
    is($f->('weekly'), 1, "$n - accepts 'weekly'");
    is($f->('monthly'), 1, "$n - accepts 'monthly'");
    is($f->('Hourly'), 0, "$n - rejects if not lowercased");
    is($f->('quux'), 0, "$n - rejects invalid timeframe");
}

{
    my $n = 'is_timeframe_or_die';
    my $f = \&App::Yabsm::Config::Query::is_timeframe_or_die;

    is($f->('5minute'), 1, "$n - accepts '5minute'");
    is($f->('hourly'), 1, "$n - accepts 'hourly'");
    is($f->('daily'), 1, "$n - accepts 'daily'");
    is($f->('weekly'), 1, "$n - accepts 'weekly'");
    is($f->('monthly'), 1, "$n - accepts 'monthly'");
    throws_ok { $f->('quux') } qr/no such timeframe 'quux'/, "$n - dies if invalid timeframe";
}

{
    my $n = 'yabsm_dir';
    my $f = \&App::Yabsm::Config::Query::yabsm_dir;

    # In the test config this value equals /.snapshots/yabsm/ (note
    # the trailing '/').
    is($f->(\%TEST_CONFIG), '/.snapshots/yabsm', "$n - returns correct yabsm_dir without trailing /");
}

{
    my $n = 'yabsm_user_home';
    my $f = \&App::Yabsm::Config::Query::yabsm_user_home;

    is $f->(\%TEST_CONFIG), '/.snapshots/yabsm/.yabsm-var/yabsm-user-home', "$n - returns correct yabsm user home";
}

{
    my $n = 'is_weekday';
    my $f = \&App::Yabsm::Config::Query::is_weekday;

    is($f->('monday'), 1, "$n - accepts 'monday'");
    is($f->('tuesday'), 1, "$n - accepts 'tuesday'");
    is($f->('wednesday'), 1, "$n - accepts 'wednesday'");
    is($f->('thursday'), 1, "$n - accepts 'thursday'");
    is($f->('friday'), 1, "$n - accepts 'friday'");
    is($f->('saturday'), 1, "$n - accepts 'saturday'");
    is($f->('sunday'), 1, "$n - accepts 'sunday'");
    is($f->('Sunday'), 0, "$n - rejects if not lowercased");
    is($f->('quux'), 0, "$n - rejects invalid weekday");
}

{
    my $n = 'is_weekday_or_die';
    my $f = \&App::Yabsm::Config::Query::is_weekday_or_die;

    is($f->('monday'), 1, "$n - accepts 'monday'");
    is($f->('tuesday'), 1, "$n - accepts 'tuesday'");
    is($f->('wednesday'), 1, "$n - accepts 'wednesday'");
    is($f->('thursday'), 1, "$n - accepts 'thursday'");
    is($f->('friday'), 1, "$n - accepts 'friday'");
    is($f->('saturday'), 1, "$n - accepts 'saturday'");
    is($f->('sunday'), 1, "$n - accepts 'sunday'");
    throws_ok { $f->('SUNDAY') } qr/no such weekday 'SUNDAY'/, "$n - dies if not lowercase";
    throws_ok { $f->('quux') } qr/no such weekday 'quux'/, "$n - dies if invalid weekday";
}

{
    my $n = 'weekday_number';
    my $f = \&App::Yabsm::Config::Query::weekday_number;

    is $f->('monday'), 1, "$n - monday first day of week";
    is $f->('tuesday'), 2, "$n - tuesday second day of week";
    is $f->('wednesday'), 3, "$n - wednesday third day of week";
    is $f->('thursday'), 4, "$n - thursday fourth day of week";
    is $f->('friday'), 5, "$n - friday fifth day of week";
    is $f->('saturday'), 6, "$n - saturday sixth day of week";
    is $f->('sunday'), 7, "$n - sunday seventh day of week";
    throws_ok { $f->('quux') } qr/no such weekday 'quux'/, "$n - dies if invalid weekday";
}

{
    my $n = 'is_time';
    my $f = \&App::Yabsm::Config::Query::is_time;

    is $f->('23:59'), 1, "$n - accepts valid time";
    is $f->('23-59'), 0, "$n - rejects if not colon seperated";
    is $f->('00:00'), 1, "$n - accepts 00:00";
    is $f->('24:30'), 0, "$n - reject hour out of range";
    is $f->('12:60'), 0, "$n - rejects minute out of range";
}

{
    my $n = 'is_time_or_die';
    my $f = \&App::Yabsm::Config::Query::is_time_or_die;

    is $f->('23:59'), 1, "$n - accepts valid time";
    throws_ok { $f->('quux') } qr/'quux' is not a valid 'hh:mm' time/, "$n - dies if invalid time";
}

{
    my $n = 'time_hour';
    my $f = \&App::Yabsm::Config::Query::time_hour;

    is $f->('23:59'), 23, "$n - return correct hour";
    throws_ok { $f->('quux') } qr/'quux' is not a valid 'hh:mm' time/, "$n - dies if invalid time";
}

{
    my $n = 'time_minute';
    my $f = \&App::Yabsm::Config::Query::time_minute;

    is $f->('23:59'), 59, "$n - return correct minute";
    throws_ok { $f->('quux') } qr/'quux' is not a valid 'hh:mm' time/, "$n - dies if invalid time";
}

1;
