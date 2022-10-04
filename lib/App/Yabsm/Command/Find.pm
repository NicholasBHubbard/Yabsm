#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Provides functionality for finding snapshots via a snapshot finding DSL.
#
#  See t/Yabsm/Snapshot.pm for this libraries tests.

use strict;
use warnings;
use v5.16.3;

package App::Yabsm::Command::Find;

use App::Yabsm::Tools qw( :ALL );
use App::Yabsm::Config::Query qw ( :ALL );
use App::Yabsm::Config::Parser qw(parse_config_or_die);
use App::Yabsm::Backup::SSH;
use App::Yabsm::Snapshot qw(nums_to_snapshot_name
                            snapshot_name_nums
                            current_time_snapshot_name
                            sort_snapshots
                            is_snapshot_name
                            snapshots_eq
                            snapshot_newer
                            snapshot_older
                            snapshot_newer_or_eq
                            snapshot_older_or_eq
                           );

use Feature::Compat::Try;
use Net::OpenSSH;
use Time::Piece;
use File::Basename qw(basename);
use Carp qw(confess);
use POSIX ();

use Parser::MGC;
use base qw(Parser::MGC);

sub usage {
    arg_count_or_die(0, 0, @_);
    return 'usage: yabsm <find|f> [--help] [<SNAP|SSH_BACKUP|LOCAL_BACKUP> <QUERY>]'."\n";
}

sub help {
    @_ == 0 or die usage();
    my $usage = usage();
    $usage =~ s/\s+$//;
    print <<"END_HELP";
$usage

see the section "Finding Snapshots" in 'man yabsm' for a detailed explanation on
how to find snapshots and backups.

examples:
    yabsm find home_snap back-10-hours
    yabsm f root_ssh_backup newest
    yabsm f home_local_backup oldest
    yabsm f home_snap 'between b-10-mins 15:45'
    yabsm f root_snap 'after back-2-days'
    yabsm f root_local_backup 'before b-14-d'
END_HELP
}

                 ####################################
                 #               MAIN               #
                 ####################################

sub main {

    if (@_ == 1) {
        shift =~ /^(-h|--help)$/ or die usage();
        help();
    }

    elsif (@_ == 2) {

        my $thing = shift;
        my $query = shift;

        my $config_ref = parse_config_or_die();

        unless (snap_exists($thing, $config_ref) || ssh_backup_exists($thing, $config_ref) || local_backup_exists($thing, $config_ref)) {
            die "yabsm: error: no such snap, ssh_backup, or local_backup named '$thing'\n";
        }

        my @snapshots = answer_query($thing, parse_query_or_die($query), $config_ref);

        say for @snapshots;
    }

    else {
        die usage()
    }
}

                 ####################################
                 #           QUERY ANSWERING        #
                 ####################################

sub answer_query {

    # Return a subset of all the snapshots/backups of $thing that satisfy
    # $query.

    arg_count_or_die(3, 3, @_);

    my $thing      = shift;
    my %query      = %{+shift};
    my $config_ref = shift;

    my @snapshots;

    if (snap_exists($thing, $config_ref)) {
        for my $tframe (snap_timeframes($thing, $config_ref)) {
            my $dir = snap_dest($thing, $tframe, $config_ref);
            unless (-r $dir) {
                die "yabsm: error: do not have read permission on '$dir'\n";
            }
            opendir my $dh, $dir or confess "yabsm: internal error: could not opendir '$dir'";
            push @snapshots, map { $_ = "$dir/$_" } grep { is_snapshot_name($_) } readdir($dh);
            closedir $dh;
        }
    }

    elsif (ssh_backup_exists($thing, $config_ref)) {

        die 'yabsm: error: permission denied'."\n" unless i_am_root();

        my $yabsm_uid = getpwnam('yabsm') or die q(yabsm: error: no user named 'yabsm')."\n";

        POSIX::setuid($yabsm_uid);

        my $ssh = App::Yabsm::Backup::SSH::new_ssh_conn($thing, $config_ref);

        my $ssh_dest = ssh_backup_ssh_dest($thing, $config_ref);

        if ($ssh->error) {
            die "yabsm: ssh error: $ssh_dest: ".$ssh->error."\n";
        }
        for my $tframe (ssh_backup_timeframes($thing, $config_ref)) {
            my $dir  = ssh_backup_dir($thing, $tframe, $config_ref);
            unless ($ssh->system("[ -r '$dir' ]")) {
                die "yabsm: ssh error: $ssh_dest: remote user does not have read permission on '$dir'\n";
            }
            push @snapshots, grep { chomp $_; is_snapshot_name($_) } App::Yabsm::Backup::SSH::ssh_system_or_die($ssh, "ls -1 '$dir'");
            map { $_ = "$dir/$_" } @snapshots;
        }
    }

    elsif (local_backup_exists($thing, $config_ref)) {
        for my $tframe (local_backup_timeframes($thing, $config_ref)) {
            my $dir = local_backup_dir($thing, $tframe, $config_ref);
            unless (-r $dir) {
                die "yabsm: error: do not have read permission on '$dir'\n";
            }
            opendir my $dh, $dir or confess "yabsm: internal error: could not opendir '$dir'";
            push @snapshots, map { $_ = "$dir/$_" } grep { is_snapshot_name($_) } readdir($dh);
            closedir $dh;
        }
    }

    else {
        die "yabsm: internal error: no such snap, ssh_backup, or local_backup named '$thing'";
    }

    @snapshots = sort_snapshots(\@snapshots);

    if ($query{type} eq 'all') {
        ;
    }

    elsif ($query{type} eq 'newest') {
        @snapshots = answer_newest_query(\@snapshots);
    }

    elsif ($query{type} eq 'oldest') {
        @snapshots = answer_oldest_query(\@snapshots);
    }

    elsif ($query{type} eq 'after') {
        @snapshots = answer_after_query($query{target}, \@snapshots);
    }

    elsif ($query{type} eq 'before') {
        @snapshots = answer_before_query($query{target}, \@snapshots);
    }

    elsif ($query{type} eq 'between') {
        @snapshots = answer_between_query($query{target1}, $query{target2}, \@snapshots);
    }

    elsif ($query{type} eq 'closest') {
        @snapshots = answer_closest_query($query{target}, \@snapshots);
    }

    else {
        confess("yabsm: internal error: no such query type $query{type}");
    }

    return wantarray ? @snapshots : \@snapshots;
}

sub answer_newest_query {

    # Return the newest snapshot in @snapshots. Because @snapshots is assumed to
    # be sorted from newest to oldest we know the newest snapshot is the first
    # snapshot in @snapshots.

    arg_count_or_die(1, 1, @_);

    my @newest;

    push @newest, shift->[0];

    return wantarray ? @newest : \@newest;
}

sub answer_oldest_query {

    # Return the oldest snapshot in @snapshots. Because @snapshots is assumed to
    # be sorted from newest to oldest we know the oldest snapshot is the last
    # snapshot in @snapshots.

    arg_count_or_die(1, 1, @_);

    my @oldest;

    push @oldest, shift->[-1];

    return wantarray ? @oldest : \@oldest;
}

sub answer_after_query {

    # Return all snapshots in @snapshots that are newer than the target snapshot
    # $target. This subroutine assumes that @snapshots is sorted from newest to
    # oldest.

    arg_count_or_die(2, 2, @_);

    my $target    = shift;
    my @snapshots = @{+shift};

    my @after;

    foreach my $this_snapshot (@snapshots) {
        if (snapshot_newer($this_snapshot, $target)) {
            push @after, $this_snapshot;
        }
        else {
            last;
        }
    }

    return wantarray ? @after : \@after;
}

sub answer_before_query {

    # Return all snapshots in @snapshots that are older than the target snapshot
    # $target. This subroutine assumes that @snapshots is sorted from newest to
    # oldest.

    arg_count_or_die(2, 2, @_);

    my $target    = shift;
    my @snapshots = @{+shift};

    my @before;

    for (my $i = $#snapshots; $i >= 0; $i--) {
        my $this_snapshot = $snapshots[$i];
        if (snapshot_older($this_snapshot, $target)) {
            unshift @before, $this_snapshot;
        }
        else {
            last;
        }
    }

    return wantarray ? @before : \@before;
}

sub answer_between_query {

    # Return all snapshots in @snapshots that are between $newer and $older
    # (inclusive). This subroutine assumes that @snapshots is sorted from newest
    # to oldest.

    arg_count_or_die(3, 3, @_);

    my $newer     = shift;
    my $older     = shift;
    my @snapshots = @{+shift};

    ($newer, $older) = ($older, $newer) if snapshot_newer($older, $newer);

    my @between;

    for (my $i = 0; $i <= $#snapshots; $i++) {
        if (snapshot_older_or_eq($snapshots[$i], $newer)) {
            for (my $j = $i; $j <= $#snapshots; $j++) {
                my $this_snapshot = $snapshots[$j];
                if (snapshot_newer_or_eq($this_snapshot, $older)) {
                    push @between, $this_snapshot;
                }
                else {
                    last;
                }
            }
            last;
        }
    }

    return wantarray ? @between : \@between;
}

sub answer_closest_query {

    # Return the snapshot in @snapshots that is closest to the snapshot $target.
    # This subroutine assumes that @snapshots is sorted from newest to oldest.

    arg_count_or_die(2, 2, @_);

    my $target    = shift;
    my @snapshots = @{+shift};

    my @closest;

    for (my $i = 0; $i <= $#snapshots; $i++) {
        my $this_snapshot = $snapshots[$i];
        if (snapshot_older_or_eq($this_snapshot, $target)) {
            if (snapshots_eq($this_snapshot, $target)) {
                @closest = ($this_snapshot);
            }
            elsif ($i == 0) {
                @closest = ($this_snapshot);
            }
            else {
                my $last_snapshot = $snapshots[$i - 1];
                my $target_epoch = Time::Piece->strptime(join('/', snapshot_name_nums(basename($target))), '%Y/%m/%d/%H/%M')->epoch;
                my $this_epoch = Time::Piece->strptime(join('/', snapshot_name_nums(basename($this_snapshot))), '%Y/%m/%d/%H/%M')->epoch;
                my $last_epoch = Time::Piece->strptime(join('/', snapshot_name_nums(basename($last_snapshot))), '%Y/%m/%d/%H/%M')->epoch;
                my $last_target_diff = abs($last_epoch - $target_epoch);
                my $this_target_diff = abs($this_epoch - $target_epoch);
                if ($last_target_diff <= $this_target_diff) {
                    @closest = ($last_snapshot);
                }
                else {
                    @closest = ($this_snapshot);
                }
            }
            last;
        }
        elsif ($i == $#snapshots) {
            @closest = ($this_snapshot);
        }
    }

    return wantarray ? @closest : \@closest;
}

                 ####################################
                 #            QUERY PARSER          #
                 ####################################

sub parse_query_or_die {

    # Parse $query into a query production or die with a useful error message
    # about about what is wrong with the query.

    arg_count_or_die(1, 1, @_);

    my $query = shift =~ s/^\s+|\s+$//gr;

    my $query_parser = __PACKAGE__->new( toplevel => 'query_parser' );

    my $query_production = do {
        try { $query_parser->from_string($query) }
        catch ($e) {
            $e =~ s/on line \d+ //g;
            die "yabsm: query error: $e";
        }
    };

    return $query_production;
}

sub query_parser {

    # Top level parser

    arg_count_or_die(1, 1, @_);

    my $self = shift;

    # return this
    my %query;

    my $type = $self->any_of(
        sub {
            $self->expect( 'all' );
            $query{type} = 'all';
        },
        sub {
            $self->expect( 'newest' );
            $query{type} = 'newest';
        },
        sub {
            $self->expect( 'oldest' );
            $query{type} = 'oldest';
        },
        sub {
            $self->expect( 'before' );
            $self->commit;
            $self->skip_ws;
            $query{type} = 'before';
            $query{target} = $self->time_abbreviation_parser;
        },
        sub {
            $self->expect( 'after' );
            $self->commit;
            $self->skip_ws;
            $query{type} = 'after';
            $query{target} = $self->time_abbreviation_parser;
        },
        sub {
            $self->expect( 'between' );
            $self->commit;
            $self->skip_ws;
            $query{type} = 'between';
            $query{target1} = $self->time_abbreviation_parser;
            $self->commit;
            $self->skip_ws;
            $query{target2} = $self->time_abbreviation_parser;
        },
        sub {
            my $time = $self->time_abbreviation_parser;
            $query{type} = 'closest';
            $query{target} = $time;
        },
        sub {
            $self->commit;
            $self->skip_ws;
            $self->fail(q(expected <time-abbreviation> or one of 'all', 'newest', 'oldest', 'before', 'after', 'between'))
        }
    );

    return \%query;
}

sub time_abbreviation_parser {

    # A time abbreviation is either a relative time or an immediate time.

    arg_count_or_die(1, 1, @_);

    my $self = shift;

    my $snapshot_name =
      $self->any_of( 'relative_time_abbreviation_parser'
                   , 'immediate_time_abbreviation_parser'
                   , sub {
                       $self->commit;
                       $self->skip_ws;
                       $self->fail('expected time abbreviation');
                     }
                   );

    return $snapshot_name;
}

sub relative_time_abbreviation_parser {

    # A relative time comes in the form <back-AMOUNT-UNIT> where
    # AMOUNT is a positive integer and UNIT is one of 'days', 'hours',
    # or 'minutes' (or one of their abbreviations). 'back' can always
    # be abbreviated to 'b'.

    arg_count_or_die(1, 1, @_);

    my $self = shift;

    $self->expect( qr/b(ack)?/ );
    $self->expect('-');
    my $amount = $self->expect(qr/[1-9][0-9]*/);
    $self->expect('-');
    my $unit = $self->expect(qr/days|d|hours|hrs|h|minutes|mins|m/);

    return n_units_ago_snapshot_name($amount, $unit);
}

sub immediate_time_abbreviation_parser {

    # An immediate time

    arg_count_or_die(1, 1, @_);

    my $self = shift;

    my $yr;
    my $mon;
    my $day;
    my $hr;
    my $min;

    my %time_regex = ( yr  => qr/2[0-9]{3}/
                     , mon => qr/[1][0-2]|0?[1-9]/
                     , day => qr/3[01]|[12][0-9]|0?[1-9]/
                     , hr  => qr/2[123]|1[0-9]|0?[0-9]/
                     , min => qr/[1-5][0-9]|0?[0-9]/
                     );

    $self->any_of(
        sub { # yr_mon_day_hr:min
            my $yr_ = $self->expect($time_regex{yr});
            $self->expect('_');
            my $mon_ = $self->expect($time_regex{mon});
            $self->expect('_');
            my $day_ = $self->expect($time_regex{day});
            $self->expect('_');
            my $hr_ = $self->expect($time_regex{hr});
            $self->expect(':');
            my $min_ = $self->expect($time_regex{min});
            $self->any_of(
                sub { $self->expect(qr/[ ]+/) },
                sub { $self->at_eos or $self->fail; }
            );

            $yr  = $yr_;
            $mon = $mon_;
            $day = $day_;
            $hr  = $hr_;
            $min = $min_;
        },

        sub { # yr_mon_day
            my $yr_ = $self->expect($time_regex{yr});
            $self->expect('_');
            my $mon_ = $self->expect($time_regex{mon});
            $self->expect('_');
            my $day_ = $self->expect($time_regex{day});
            $self->any_of(
                sub { $self->expect(qr/[ ]+/) },
                sub { $self->at_eos or $self->fail; }
            );

            $yr  = $yr_;
            $mon = $mon_;
            $day = $day_;
        },

        sub { # mon_day_hr:min
            my $mon_ = $self->expect($time_regex{mon});
            $self->expect('_');
            my $day_ = $self->expect($time_regex{day});
            $self->expect('_');
            my $hr_ = $self->expect($time_regex{hr});
            $self->expect(':');
            my $min_ = $self->expect($time_regex{min});
            $self->any_of(
                sub { $self->expect(qr/[ ]+/) },
                sub { $self->at_eos or $self->fail; }
            );

            $mon = $mon_;
            $day = $day_;
            $hr  = $hr_;
            $min = $min_;
        },

        sub { # mon_day_hr
            my $mon_ = $self->expect($time_regex{mon});
            $self->expect('_');
            my $day_ = $self->expect($time_regex{day});
            $self->expect('_');
            my $hr_ = $self->expect($time_regex{hr});
            $self->any_of(
                sub { $self->expect(qr/[ ]+/) },
                sub { $self->at_eos or $self->fail; }
            );

            $mon = $mon_;
            $day = $day_;
            $hr  = $hr_;
        },

        sub { # mon_day
            my $mon_ = $self->expect($time_regex{mon});
            $self->expect('_');
            my $day_ = $self->expect($time_regex{day});
            $self->any_of(
                sub { $self->expect(qr/[ ]+/) },
                sub { $self->at_eos or $self->fail; }
            );

            $mon = $mon_;
            $day = $day_;
        },

        sub { # day_hr:min
            my $day_ = $self->expect($time_regex{day});
            $self->expect('_');
            my $hr_ = $self->expect($time_regex{hr});
            $self->expect(':');
            my $min_ = $self->expect($time_regex{min});
            $self->any_of(
                sub { $self->expect(qr/[ ]+/) },
                sub { $self->at_eos or $self->fail; }
            );

            $day = $day_;
            $hr  = $hr_;
            $min = $min_;
        },

        sub { # hr:min
            my $hr_ = $self->expect($time_regex{hr});
            $self->expect(':');
            my $min_ = $self->expect($time_regex{min});
            $self->any_of(
                sub { $self->expect(qr/[ ]+/) },
                sub { $self->at_eos or $self->fail; }
            );

            $hr  = $hr_;
            $min = $min_;
        }
    );

    my $t = localtime;

    $yr  //= $t->year;
    $mon //= $t->mon;
    $day //= $t->mday;
    $hr  //= 0;
    $min //= 0;

    return nums_to_snapshot_name($yr, $mon, $day, $hr, $min);
}

                 ####################################
                 #           TIME FUNCTIONS         #
                 ####################################

sub n_units_ago_snapshot_name {

    # Return a snapshot name representing the time $n $unit's ago from now.

    arg_count_or_die(2, 2, @_);

    my $n    = shift;
    my $unit = shift;

    unless ($n =~ /^\d+$/ && $n > 0) {
        confess "yabsm: internal error: '$n' is not a positive integer";
    }

    my $seconds_per_unit;

    if    ($unit =~ /^(?:minutes|mins|m)$/) { $seconds_per_unit = 60    }
    elsif ($unit =~ /^(?:hours|hrs|h)$/   ) { $seconds_per_unit = 3600  }
    elsif ($unit =~ /^(?:days|d)$/        ) { $seconds_per_unit = 86400 }
    else {
        confess "yabsm: internal error: '$unit' is not a valid time unit";
    }

    my $t = localtime;

    my ($yr, $mon, $day, $hr, $min) = ($t->year, $t->mon, $t->mday, $t->hour, $t->min);

    my $tp = Time::Piece->strptime("$yr/$mon/$day/$hr/$min", '%Y/%m/%d/%H/%M');

    $tp -= $n * $seconds_per_unit;

    return nums_to_snapshot_name($tp->year, $tp->mon, $tp->mday, $tp->hour, $tp->min);
}

1;
