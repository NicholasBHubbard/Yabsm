#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Provides functionality for Yabsm configuration parsing using the
#  Parser::MGC library. Tests for the parser are located at
#  src/t/Config.t.
#
#  This parser produces a multi-dimensional hash data structure with
#  the following skeleton:
#
#  %config = ( yabsm_dir     => '/.snapshots/yabsm'
#
#              subvols       => { foo => { mountpoint=/foo_dir }
#                               , bar => { mountpoint=/bar_dir }
#                               , ...
#                               },
#              snaps         => { foo_snap => { key=val, ... }
#                               , bar_snap => { key=val, ... }
#                               , ...
#                               },
#              ssh_backups   => { foo_ssh_backup => { key=val, ... }
#                               , bar_ssh_backup => { key=val, ... }
#                               ,  ...
#                               },
#              local_backups => { foo_local_backup => { key=val, ... }
#                               , bar_local_backup => { key=val, ... }
#                               , ...
#                               }
#            );

use strict;
use warnings;
use v5.16.3;

package App::Yabsm::Config::Parser;

use App::Yabsm::Tools qw(arg_count_or_die);

use Carp qw(confess);
use Array::Utils qw(array_minus);
use Regexp::Common qw(net);
use Feature::Compat::Try;

use Parser::MGC;
use base 'Parser::MGC';

                 ####################################
                 #              EXPORTED            #
                 ####################################

use Exporter qw(import);
our @EXPORT_OK = qw(parse_config_or_die);

sub parse_config_or_die {

    # Attempt to parse $file into a yabsm configuration data structure.

    arg_count_or_die(0, 1, @_);

    my $file = shift // '/etc/yabsm.conf';

    -f $file or die "yabsm: config error: no such file '$file'\n";
    -r $file or die "yabsm: config error: can not read file '$file'\n";

    # Initialize the Parser::MGC parser object
    my $parser = __PACKAGE__->new( toplevel => 'config_parser'
                                 , patterns => { comment => &grammar->{comment}
                                               , ws      => &grammar->{whitespace}
                                               }
                                 );

    my $config_ref = do {
        try { $parser->from_file($file) }
        catch ($e) { $e =~ s/\s+$// ; die "yabsm: config error: $e\n" }
    };

    my ($config_valid, @error_msgs) = check_config($config_ref);

    if ($config_valid) {
        return wantarray ? %{ $config_ref} : $config_ref;
    }
    else {
        my $error_msg = join '', map { $_ = "$_\n" } @error_msgs;
        die $error_msg;
    }
}

                 ####################################
                 #              GRAMMAR             #
                 ####################################

sub grammar {

    # Return a hash of all the atomic grammar elements of the yabsm config
    # language.

    arg_count_or_die(0, 0, @_);

    my %grammar = (
        name          => qr/[a-zA-Z][-_a-zA-Z0-9]*/,
        subvol        => qr/[a-zA-Z][-_a-zA-Z0-9]*/,
        dir           => qr/\/[a-zA-Z0-9._:\-\/]*/,
        mountpoint    => qr/\/[a-zA-Z0-9._:\-\/]*/,
        # timeframes example: hourly,monthly,daily
        timeframes    => qr/((5minute|hourly|daily|weekly|monthly),)+(5minute|hourly|daily|weekly|monthly)|(5minute|hourly|daily|weekly|monthly)/,
        ssh_dest      => qr/([a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)@)?(([A-Za-z][A-Za-z0-9_-]*)|$RE{net}{IPv4}{strict}|$RE{net}{IPv6})/,
        opening_brace => qr/{/,
        closing_brace => qr/}/,
        equals_sign   => qr/=/,
        comment       => qr/[\s\t]*#.*/,
        whitespace    => qr/[\s\t\n]+/,
        timeframe_sub_grammar => {

            '5minute_keep' => qr/[1-9][0-9]*/,
            hourly_keep    => qr/[1-9][0-9]*/,
            daily_keep     => qr/[1-9][0-9]*/,
            weekly_keep    => qr/[1-9][0-9]*/,
            monthly_keep   => qr/[1-9][0-9]*/,

            # comma seperated hh:mm's
            daily_times    => qr/(((0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]),)+((0[0-9]|1[0-9]|2[0-3]):[0-5][0-9])|(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]/,

            # hh:mm
            weekly_time    => qr/(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]/,
            monthly_time   => qr/(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]/,

            weekly_day     => qr/[1-7]|monday|tuesday|wednesday|thursday|friday|saturday|sunday/,
            monthly_day    => qr/3[01]|[12][0-9]|[1-9]/ # 1-31
        }
    );

    return wantarray ? %grammar : \%grammar;
}

sub grammar_msg {

    # Return a hash that associates grammar non-terminals to a linguistic
    # description of their expected value. Used for generating meaningful error
    # messages.

    arg_count_or_die(0, 0, @_);

    my %grammar_msg = (
        name           => 'thing name',
        subvol         => 'subvol name',
        dir            => 'absolute path',
        mountpoint     => 'absolute path',
        timeframes     => 'comma separated timeframes',
        ssh_dest       => 'SSH destination',
        opening_brace  => q('{'}),
        closing_brace  => q('}'),
        equals_sign    => q('='),
        comment        => 'comment',
        whitespace     => 'whitespace',
        #keep
        '5minute_keep' => 'positive integer',
        hourly_keep    => 'positive integer',
        daily_keep     => 'positive integer',
        weekly_keep    => 'positive integer',
        monthly_keep   => 'positive integer',
        #time
        daily_times    => q(comma seperated list of times in 'hh:mm' form'),
        weekly_time    => q(time in 'hh:mm' form),
        monthly_time   => q(time in 'hh:mm' form),
        #day
        weekly_day     => 'week day',
        monthly_day    => 'month day'
    );

    return wantarray ? %grammar_msg : \%grammar_msg;
}

sub subvol_settings_grammar {

    # Return a hash of a subvols key=val grammar.

    arg_count_or_die(0, 0, @_);

    my %grammar = grammar();

    my %subvol_settings_grammar = (
        mountpoint => $grammar{mountpoint}
    );

    return wantarray ? %subvol_settings_grammar : \%subvol_settings_grammar;
}

sub snap_settings_grammar {

    # Return a hash of a snaps key=val grammar. Optionally takes a false value
    # to exclude the timeframe subgrammar from the returned grammar.

    arg_count_or_die(0, 1, @_);

    my $include_tf = shift // 1;

    my %grammar = grammar();

    my %timeframe_sub_grammar =
      $include_tf ? %{ $grammar{timeframe_sub_grammar} } : ();

    my %snap_settings_grammar = (
        subvol     => $grammar{subvol},
        timeframes => $grammar{timeframes},
        %timeframe_sub_grammar
    );

    return wantarray ? %snap_settings_grammar : \%snap_settings_grammar;
}

sub ssh_backup_settings_grammar {

    # Return a hash of a ssh_backups key=val grammar. Optionally takes a false
    # value to exclude the timeframe subgrammar from the returned grammar.

    arg_count_or_die(0, 1, @_);

    my $include_tf = shift // 1;

    my %grammar = grammar();

    my %timeframe_sub_grammar =
      $include_tf ? %{ $grammar{timeframe_sub_grammar} } : ();

    my %ssh_backup_settings_grammar = (
        subvol     => $grammar{subvol},
        ssh_dest   => $grammar{ssh_dest},
        dir        => $grammar{dir},
        timeframes => $grammar{timeframes},
        %timeframe_sub_grammar
    );

    return wantarray ? %ssh_backup_settings_grammar : \%ssh_backup_settings_grammar;
}

sub local_backup_settings_grammar {

    # Return a hash of a local_backups key=val grammar. Optionally takes a false
    # value to exclude the timeframe subgrammar from the returned grammar.

    arg_count_or_die(0, 1, @_);

    my $include_tf = shift // 1;

    my %grammar = grammar();

    my %timeframe_sub_grammar =
      $include_tf ? %{ $grammar{timeframe_sub_grammar} } : ();

    my %local_backup_settings_grammar = (
        subvol     => $grammar{subvol},
        dir        => $grammar{dir},
        timeframes => $grammar{timeframes},
        %timeframe_sub_grammar
    );

    return wantarray ? %local_backup_settings_grammar : \%local_backup_settings_grammar;
}

                 ####################################
                 #              PARSER              #
                 ####################################

sub config_parser {

    # Top level parser

    arg_count_or_die(1, 1, @_);

    my $self = shift;

    # return this
    my %config;

    # Define the parser

    my %grammar = grammar();

    $self->sequence_of( sub {
        $self->commit;
        $self->any_of(
            sub {
                $self->expect( 'yabsm_dir' );
                $self->commit;
                exists $config{yabsm_dir} and $self->fail('yabsm_dir is already defined');
                $self->maybe_expect('=') // $self->fail(q(expected '='));
                my $dir = $self->maybe_expect($grammar{dir}) // $self->fail(grammar_msg->{dir});
                $config{yabsm_dir} = $dir;
            },
            sub {
                $self->expect( 'subvol' );
                $self->commit;
                my $name = $self->maybe_expect( $grammar{name} );
                $name // $self->fail('expected subvol name');
                exists $config{subvols}{$name}       and $self->fail("already have a subvol named '$name'");
                exists $config{snaps}{$name}         and $self->fail("already have a snap named '$name'");
                exists $config{ssh_backups}{$name}   and $self->fail("already have a ssh_backup named '$name'");
                exists $config{local_backups}{$name} and $self->fail("already have a local_backup named '$name'");
                my $kvs = $self->scope_of('{', 'subvol_settings_parser' ,'}');
                $config{subvols}{$name} = $kvs;
            },
            sub {
                $self->expect( 'snap' );
                $self->commit;
                my $name = $self->maybe_expect( $grammar{name} );
                $name // $self->fail('expected snap name');
                exists $config{subvols}{$name}       and $self->fail("already have a subvol named '$name'");
                exists $config{snaps}{$name}         and $self->fail("already have a snap named '$name'");
                exists $config{ssh_backups}{$name}   and $self->fail("already have a ssh_backup named '$name'");
                exists $config{local_backups}{$name} and $self->fail("already have a local_backup named '$name'");
                my $kvs = $self->scope_of('{', 'snap_settings_parser', '}');
                $config{snaps}{$name} = $kvs;
            },
            sub {
                $self->expect( 'ssh_backup' );
                $self->commit;
                my $name = $self->maybe_expect( $grammar{name} );
                $name // $self->fail('expected ssh_backup name');
                exists $config{subvols}{$name}       and $self->fail("already have a subvol named '$name'");
                exists $config{snaps}{$name}         and $self->fail("already have a snap named '$name'");
                exists $config{ssh_backups}{$name}   and $self->fail("already have a ssh_backup named '$name'");
                exists $config{local_backups}{$name} and $self->fail("already have a local_backup named '$name'");
                my $kvs = $self->scope_of('{', 'ssh_backup_settings_parser', '}');
                $config{ssh_backups}{$name} = $kvs;
            },
            sub {
                $self->expect( 'local_backup' );
                $self->commit;
                my $name = $self->maybe_expect( $grammar{name} );
                $name // $self->fail('expected local_backup name');
                exists $config{subvols}{$name}       and $self->fail("already have a subvol named '$name'");
                exists $config{snaps}{$name}         and $self->fail("already have a snap named '$name'");
                exists $config{ssh_backups}{$name}   and $self->fail("already have a ssh_backup named '$name'");
                exists $config{local_backups}{$name} and $self->fail("already have a local_backup named '$name'");
                my $kvs = $self->scope_of('{', 'local_backup_settings_parser', '}');
                $config{local_backups}{$name} = $kvs;
            },
            sub {
                $self->commit;
                $self->skip_ws; # skip_ws also skips comments
                $self->fail(q(expected one of 'subvol', 'snap', 'ssh_backup', or 'local_backup'));
            }
        );
    });

    return wantarray ? %config : \%config;
}

sub settings_parser {

    # Abstract method that parses a sequence of key=val pairs based off of the
    # input grammar %grammar. The arg $type is simply a string that is either
    # 'subvol', 'snap', 'ssh_backup', or 'local_backup' and is only used for
    # error message generation. This method should be called from a wrapper
    # method.

    arg_count_or_die(3, 3, @_);

    my $self    = shift;
    my $type    = shift;
    my $grammar = shift;

    my @settings = keys %{ $grammar };
    my $setting_regex = join '|', @settings;

    # return this
    my %kvs;

    $self->sequence_of( sub {
        $self->commit;

        my $setting = $self->maybe_expect( qr/$setting_regex/ )
          // $self->fail("expected a $type setting");

        $self->maybe_expect('=') // $self->fail('expected "="');

        my $value = $self->maybe_expect($grammar->{$setting})
          // $self->fail('expected ' . grammar_msg->{$setting});

        $kvs{$setting} = $value;
    });

    return wantarray ? %kvs : \%kvs;
}

sub subvol_settings_parser {
    arg_count_or_die(1, 1, @_);
    my $self = shift;
    my $subvol_settings_grammar = subvol_settings_grammar();
    $self->settings_parser('subvol', $subvol_settings_grammar);
}

sub snap_settings_parser {
    arg_count_or_die(1, 1, @_);
    my $self = shift;
    my $snap_settings_grammar = snap_settings_grammar();
    $self->settings_parser('snap', $snap_settings_grammar);
}

sub ssh_backup_settings_parser {
    arg_count_or_die(1, 1, @_);
    my $self = shift;
    my $ssh_backup_settings_grammar = ssh_backup_settings_grammar();
    $self->settings_parser('ssh_backup', $ssh_backup_settings_grammar);
}

sub local_backup_settings_parser {
    arg_count_or_die(1, 1, @_);
    my $self = shift;
    my $local_backup_settings_grammar = local_backup_settings_grammar();
    $self->settings_parser('local_backup', $local_backup_settings_grammar);
}

                 ####################################
                 #          ERROR ANALYSIS          #
                 ####################################

sub check_config {

    # Ensure that $config_ref references a valid yabsm configuration.  If the
    # config is valid return a list containing only the value 1, otherwise
    # return multiple values where the first value is 0 and the rest of the
    # values are the corresponding error messages.

    arg_count_or_die(1, 1, @_);

    my $config_ref = shift;

    my @error_msgs;

    unless ($config_ref->{yabsm_dir}) {
        push @error_msgs, q(yabsm: config error: missing required setting 'yabsm_dir');
    }

    unless ($config_ref->{snaps} || $config_ref->{ssh_backups} || $config_ref->{local_backups}) {
        push @error_msgs, 'yabsm: config error: no defined snaps, ssh_backups, or local_backups';
    }

    push @error_msgs, snap_errors($config_ref);
    push @error_msgs, ssh_backup_errors($config_ref);
    push @error_msgs, local_backup_errors($config_ref);

    if (@error_msgs) {
        return (0, @error_msgs);
    }
    else {
        return (1);
    }
}

sub snap_errors {

    # Ensure that all the snaps defined in the config referenced by $config_ref
    # are not missing required snap settings and are snapshotting a defined
    # subvol.

    arg_count_or_die(1, 1, @_);

    my $config_ref = shift;

    # return this
    my @error_msgs;

    # Base required settings. Passing 0 to snap_settings_grammar excludes
    # timeframe settings from the returned hash.
    my @base_required_settings = keys %{ snap_settings_grammar(0) };

    foreach my $snap (keys %{ $config_ref->{snaps} }) {

        # Make sure that the subvol being snapped exists
        my $subvol = $config_ref->{snaps}{$snap}{subvol};
        if (defined $subvol) {
            unless (grep { $subvol eq $_ } keys %{ $config_ref->{subvols} }) {
                push @error_msgs, "yabsm: config error: snap '$snap' is snapshotting up a non-existent subvol '$subvol'";
            }
        }

        # Make sure all required settings are defined
        my @required_settings = @base_required_settings;
        my $timeframes = $config_ref->{snaps}{$snap}{timeframes};
        if (defined $timeframes) {
            push @required_settings, required_timeframe_settings($timeframes);
        }
        my @defined_settings = keys %{ $config_ref->{snaps}{$snap} };
        my @missing_settings = array_minus(@required_settings, @defined_settings);
        foreach my $missing (@missing_settings) {
            push @error_msgs, "yabsm: config error: snap '$snap' missing required setting '$missing'";
        }
    }

    return wantarray ? @error_msgs : \@error_msgs;
}

sub ssh_backup_errors {

    # Ensure that all the ssh_backups defined in the config referenced by
    # $config_ref are not missing required ssh_backup settings and are backing
    # up a defined subvol.

    arg_count_or_die(1, 1, @_);

    my $config_ref = shift;

    # return this
    my @error_msgs;

    # Base required settings. Passing 0 to ssh_backup_settings_grammar excludes
    # timeframe settings from the returned hash.
    my @base_required_settings = keys %{ ssh_backup_settings_grammar(0) };

    foreach my $ssh_backup (keys %{ $config_ref->{ssh_backups} }) {

        # Make sure that the subvol being backed up exists
        my $subvol = $config_ref->{ssh_backups}{$ssh_backup}{subvol};
        if (defined $subvol) {
            unless (grep { $subvol eq $_ } keys %{ $config_ref->{subvols} }) {
                push @error_msgs, "yabsm: config error: ssh_backup '$ssh_backup' is backing up a non-existent subvol '$subvol'";
            }
        }

        # Make sure all required settings are defined
        my @required_settings = @base_required_settings;
        my $timeframes = $config_ref->{ssh_backups}{$ssh_backup}{timeframes};
        if (defined $timeframes) {
            push @required_settings, required_timeframe_settings($timeframes);
        }
        my @defined_settings = keys %{ $config_ref->{ssh_backups}{$ssh_backup} };
        my @missing_settings = array_minus(@required_settings, @defined_settings);
        foreach my $missing (@missing_settings) {
            push @error_msgs, "yabsm: config error: ssh_backup '$ssh_backup' missing required setting '$missing'";
        }
    }

    return wantarray ? @error_msgs : \@error_msgs;
}

sub local_backup_errors {

    # Ensure that all the local_backups defined in the config referenced by
    # $config_ref are not missing required local_backup settings and are backing
    # up a defined subvol

    arg_count_or_die(1, 1, @_);

    my $config_ref = shift;

    # return this
    my @error_msgs;

    # Base required settings. Passing 0 to local_backup_settings_grammar
    # excludes timeframe settings from the returned hash.
    my @base_required_settings = keys %{ local_backup_settings_grammar(0) };

    foreach my $local_backup (keys %{ $config_ref->{local_backups} }) {

        # Make sure that the subvol being backed up exists
        my $subvol = $config_ref->{local_backups}{$local_backup}{subvol};
        if (defined $subvol) {
            unless (grep { $subvol eq $_ } keys %{ $config_ref->{subvols} }) {
                push @error_msgs, "yabsm: config error: local_backup '$local_backup' is backing up a non-existent subvol '$subvol'";
            }
        }

        # Make sure all required settings are defined
        my @required_settings = @base_required_settings;
        my $timeframes = $config_ref->{local_backups}{$local_backup}{timeframes};
        if (defined $timeframes) {
            push @required_settings, required_timeframe_settings($timeframes);
        }
        my @defined_settings = keys %{ $config_ref->{local_backups}{$local_backup} };
        my @missing_settings = array_minus(@required_settings, @defined_settings);
        foreach my $missing (@missing_settings) {
            push @error_msgs, "yabsm: config error: local_backup '$local_backup' missing required setting '$missing'";
        }
    }

    return wantarray ? @error_msgs : \@error_msgs;
}

sub required_timeframe_settings {

    # Given a timeframes value like 'hourly,daily,monthly' returns a list of
    # required settings. This subroutine is used to dynamically determine what
    # settings are required for certain config entities.

    arg_count_or_die(1, 1, @_);

    my $tframes = shift;

    my @timeframes = split ',', $tframes;

    # return this
    my @required;

    foreach my $tframe (@timeframes) {
        if    ($tframe eq '5minute') { push @required, qw(5minute_keep) }
        elsif ($tframe eq 'hourly')  { push @required, qw(hourly_keep) }
        elsif ($tframe eq 'daily')   { push @required, qw(daily_keep daily_times) }
        elsif ($tframe eq 'weekly')  { push @required, qw(weekly_keep weekly_time weekly_day) }
        elsif ($tframe eq 'monthly') { push @required, qw(monthly_keep monthly_time monthly_day) }
        else {
            confess("yabsm: internal error: no such timeframe '$tframe'");
        }
    }

    return @required;
}

1;
