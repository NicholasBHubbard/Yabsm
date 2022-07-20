#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  This module exists to provide the read_config() subroutine that is
#  used to create the $config_ref variable that is passed around the
#  rest of yabsm constantly. See t/Config.t for this modules testing.

package Yabsm::Config;

use strict;
use warnings;
use v5.16.3;

# located using lib::relative in yabsm.pl
use lib::relative '..';
use Yabsm::Base;

use Carp;
use Array::Utils 'array_minus';
use Log::Log4perl 'get_logger';

use Parser::MGC;
use base 'Parser::MGC';
use Regexp::Common 'net';

use Feature::Compat::Try;

                 ####################################
                 #              EXPORTED            #
                 ####################################

use Exporter 'import';
our @EXPORT_OK = qw( parse_config_or_die );

sub parse_config_or_die {

    # Attempt to parse $file into a yabsm configuration data
    # structure.

    my $file = shift // '/etc/yabsmd.conf';

    # Initialize the Parser::MGC parser object
    my $parser = __PACKAGE__->new( toplevel => 'config_parser'
                                 , patterns => { comment => &grammar->{comment}
                                               , ws      => &grammar->{whitespace}
                                               }
                                 );

    # Config errors exit with status 2
    use constant EXIT_STATUS => 2;

    my $config_ref = do {
        try { $parser->from_file($file) }
        catch ($e) { print "yabsm: config error: $e" ; exit EXIT_STATUS }
    };

    my ($config_valid, @error_msgs) = check_config($config_ref);

    if ($config_valid) {
        return wantarray ? %{ $config_ref } : $config_ref;
    }
    else {
        say STDERR $_ for @error_msgs;
        exit EXIT_STATUS; # config errors exit with status 2
    }
}

                 ####################################
                 #              GRAMMAR             #
                 ####################################

sub grammar {

    # Return a hash of all the atomic grammar elements of the
    # yabsm config language.

    my %grammar = (
        name          => qr/[a-zA-Z][-_a-zA-Z0-9]*/,
        subvol        => qr/[a-zA-Z][-_a-zA-Z0-9]*/,
        dir           => qr/\/[a-zA-Z0-9._:\-\/]*/,
        mountpoint    => qr/\/[a-zA-Z0-9._:\-\/]*/,
        # timeframes example: hourly,monthly,daily
        timeframes    => qr/((5minute|hourly|daily|weekly|monthly),)+(5minute|hourly|daily|weekly|monthly)|(5minute|hourly|daily|weekly|monthly)/,
        ssh_dest      => qr/[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)@($RE{net}{IPv4}{strict}|$RE{net}{IPv6})/,
        opening_brace => qr/{/,
        closing_brace => qr/}/,
        equals_sign   => qr/=/,
        comment       => qr/[\s\t]*#.*/,
        whitespace    => qr/[\s\t\n]+/,
        timeframe_sub_grammar => {
            #keep
            '5minute_keep' => qr/[1-9][0-9]*/,
            hourly_keep    => qr/[1-9][0-9]*/,
            daily_keep     => qr/[1-9][0-9]*/,
            weekly_keep    => qr/[1-9][0-9]*/,
            monthly_keep   => qr/[1-9][0-9]*/,
            #time
            daily_time     => qr/(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]/,
            weekly_time    => qr/(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]/,
            monthly_time   => qr/(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]/,
            #day
            weekly_day     => qr/[1-7]|monday|tuesday|wednesday|thursday|friday|saturday|sunday/,
            monthly_day    => qr/3[01]|[12][0-9]|[1-9]/ # 1-31
        }
    );

    return wantarray ? %grammar : \%grammar;
}

sub subvol_settings_grammar {
    my %grammar = grammar();
    my %subvol_settings_grammar = (
        mountpoint => $grammar{mountpoint}
    );
    return wantarray ? %subvol_settings_grammar : \%subvol_settings_grammar;
}

sub snap_settings_grammar {
    my $include_tf_sub_grammar = shift // 1;
    my %grammar = grammar();
    my %timeframe_sub_grammar =
      $include_tf_sub_grammar ? %{ $grammar{timeframe_sub_grammar} } : ();
    my %snap_settings_grammar = (
        subvol     => $grammar{subvol},
        dir        => $grammar{dir},
        timeframes => $grammar{timeframes},
        %timeframe_sub_grammar
    );
    return wantarray ? %snap_settings_grammar : \%snap_settings_grammar;
}

sub ssh_backup_settings_grammar {
    my $include_tf_sub_grammar = shift // 1;
    my %grammar = grammar();
    my %timeframe_sub_grammar =
      $include_tf_sub_grammar ? %{ $grammar{timeframe_sub_grammar} } : ();
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
    my $include_tf_sub_grammar = shift // 1;
    my %grammar = grammar();
    my %timeframe_sub_grammar =
      $include_tf_sub_grammar ? %{ $grammar{timeframe_sub_grammar} } : ();
    my %local_backup_settings_grammar = (
        subvol     => $grammar{subvol},
        dir        => $grammar{dir},
        timeframes => $grammar{timeframes},
        %timeframe_sub_grammar
    );
    return wantarray ? %local_backup_settings_grammar : \%local_backup_settings_grammar;
}

sub grammar_msg {

    # Return a hash that associates grammar elements to their
    # linguistic descriptions.

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
        daily_time     => 'time in "hh:mm" form',
        weekly_time    => 'time in "hh:mm" form',
        monthly_time   => 'time in "hh:mm" form',
        #day
        weekly_day     => 'week day',
        monthly_day    => 'month day'
    );

    return wantarray ? %grammar_msg : \%grammar_msg;
}

                 ####################################
                 #              PARSER              #
                 ####################################

sub config_parser {

    my $self = shift // Yabsm::Base::missing_arg();

    # return this
    my %config;

    # parse

    my %grammar = grammar();

    $self->sequence_of( sub {
        $self->commit;
        $self->any_of(
            sub {
                $self->expect( 'subvol' );
                $self->commit;
                my $name = $self->maybe_expect( $grammar{name} );
                $name // $self->fail('expected subvol name');
                my $kvs = $self->scope_of('{', 'subvol_settings_parser' ,'}');
                delete $config{subvols}{$name}; # allow overwrites
                $config{subvols}{$name} = $kvs;
            },
            sub {
                $self->expect( 'snap' );
                $self->commit;
                my $name = $self->maybe_expect( $grammar{name} );
                $name // $self->fail('expected snap name');
                my $kvs = $self->scope_of('{', 'snap_settings_parser', '}');
                delete $config{snaps}{$name}; # allow overwrites
                $config{snaps}{$name} = $kvs;
            },
            sub {
                $self->expect( 'ssh_backup' );
                $self->commit;
                my $name = $self->maybe_expect( $grammar{name} );
                $name // $self->fail('expected ssh_backup name');
                my $kvs = $self->scope_of('{', 'ssh_backup_settings_parser', '}');
                delete $config{ssh_backups}{$name}; # allow overwrites
                $config{ssh_backups}{$name} = $kvs;
            },
            sub {
                $self->expect( 'local_backup' );
                $self->commit;
                my $name = $self->maybe_expect( $grammar{name} );
                $name // $self->fail('expected local_backup name');
                my $kvs = $self->scope_of('{', 'local_backup_settings_parser', '}');
                delete $config{local_backups}{$name}; # allow overwrites
                $config{local_backups}{$name} = $kvs;
            },
            sub {
                $self->commit;
                $self->skip_ws; # fwiw skip_ws also skips comments
                $self->fail(q(expected one of 'subvol', 'snap', 'ssh_backup', or 'local_backup'));
            }
        );
    });

    return wantarray ? %config : \%config;
}

sub settings_parser {

    # Abstract method that parses a sequence of key=val pairs
    # based off of a given grammar (%grammar). The arg $type
    # is simply a string that is either 'subvol', 'snap',
    # 'ssh_backup', or 'local_backup' and is used for error
    # message purposes. This method is not called directly but
    # instead called from the wrapper parsers 'subvol_settings_parser'
    # 'snap_settings_parser', 'ssh_backup_settings_parser', and
    # 'local_backup_settings_parser'.

    my $self    = shift;
    my $type    = shift;
    my %grammar = %{ +shift };

    my @settings = keys %grammar;
    my $setting_rx = join '|', @settings;

    # return this
    my %kvs;

    $self->sequence_of( sub {
        $self->commit;

        my $setting = $self->maybe_expect( qr/$setting_rx/ )
          // $self->fail("expected a $type setting");

        $self->maybe_expect('=') // $self->fail('expected "="');

        my $value = $self->maybe_expect($grammar{$setting})
          // $self->fail('expected ' . grammar_msg->{$setting});

        $kvs{$setting} = $value;
    });

    return wantarray ? %kvs : \%kvs;
}

sub subvol_settings_parser {
    my $self = shift;
    my $subvol_settings_grammar = subvol_settings_grammar();
    $self->settings_parser('subvol', $subvol_settings_grammar);
}

sub snap_settings_parser {
    my $self = shift;
    my $snap_settings_grammar = snap_settings_grammar();
    $self->settings_parser('snap', $snap_settings_grammar);
}

sub ssh_backup_settings_parser {
    my $self = shift;
    my $ssh_backup_settings_grammar = ssh_backup_settings_grammar();
    $self->settings_parser('ssh_backup', $ssh_backup_settings_grammar);
}

sub local_backup_settings_parser {
    my $self = shift;
    my $local_backup_settings_grammar = local_backup_settings_grammar();
    $self->settings_parser('local_backup', $local_backup_settings_grammar);
}

                 ####################################
                 #          ERROR ANALYSIS          #
                 ####################################

sub check_config {

    # Ensure that $config_ref references a valid yabsm configuration.
    # If the config is valid return a list containing only the value
    # 1, otherwise return multiple values where the first value is 0
    # and the rest of the values are the corresponding error messages.

    my $config_ref = shift;

    my @error_msgs;

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

    # Ensure that all the snaps defined in the config referenced
    # by $config_ref are not missing required snap settings and
    # they are snapping a defined subvol.

    my $config_ref = shift;

    # return this
    my @error_msgs;

    # Base required settings. Passing 0 to snap_settings_grammar
    # excludes timeframe settings from the returned hash.
    my @base_required_settings = keys snap_settings_grammar(0);

    my @subvols = keys %{ $config_ref->{subvols} };

    foreach my $snap (keys %{ $config_ref->{snaps} }) {

        # make sure the subvol being snapped exists
        my $subvol = $config_ref->{snaps}{$snap}{subvol};
        unless (grep $subvol, @subvols) {
            push @error_msgs, "yabsm: config error: snap '$snap' is snapshotting an undefined subvol '$subvol'";
        }

        # ensure that all required settings exist.
        my $timeframes = $config_ref->{snaps}{$snap}{timeframes};
        my @required_settings = (@base_required_settings, required_timeframe_settings($timeframes));
        my @defined_settings = keys $config_ref->{snaps}{$snap};
        my @missing_settings = array_minus(@required_settings, @defined_settings);
        foreach my $setting (@missing_settings) {
            push @error_msgs, "yabsm: config error: snap '$snap' is missing required setting '$setting'";
        }
    }

    return wantarray ? @error_msgs : \@error_msgs;
}

sub ssh_backup_errors {

    # Ensure that all the ssh_backups defined in the config referenced
    # by $config_ref are not missing required ssh_backup settings and
    # they are backing up a defined subvol.

    my $config_ref = shift;

    # return this
    my @error_msgs;

    # Base required settings. Passing 0 to ssh_backup_settings_grammar
    # excludes timeframe settings from the returned hash.
    my @base_required_settings = keys ssh_backup_settings_grammar(0);

    my @subvols = keys %{ $config_ref->{subvols} };

    foreach my $ssh_backup (keys %{ $config_ref->{ssh_backups} }) {

        # ensure sure the subvol being backed up exists.
        my $subvol = $config_ref->{ssh_backups}{$ssh_backup}{subvol};
        unless (grep $subvol, @subvols) {
            push @error_msgs, "yabsm: config error: ssh_backup '$ssh_backup' is backing up an undefined subvol '$subvol'";
        }

        # ensure that all required settings are defined.
        my $timeframes = $config_ref->{ssh_backups}{$ssh_backup}{timeframes};
        my @required_settings = (@base_required_settings, required_timeframe_settings($timeframes));
        my @defined_settings  = keys $config_ref->{ssh_backups}{$ssh_backup};
        my @missing_settings  = array_minus(@required_settings, @defined_settings);
        foreach my $setting (@missing_settings) {
            push @error_msgs, "yabsm: config error: ssh_backup '$ssh_backup' is missing required setting '$setting'";
        }
    }

    return wantarray ? @error_msgs : \@error_msgs;
}

sub local_backup_errors {

    # Ensure that all the local_backups defined in the config
    # referenced by $config_ref are not missing required local_backup
    # settings and they are backing up a defined subvol.

    my $config_ref = shift;

    # return this
    my @error_msgs;

    # Base required settings. Passing 0 to local_backup_settings_grammar
    # excludes timeframe settings from the returned hash.
    my @base_required_settings = keys local_backup_settings_grammar(0);

    my @subvols = keys %{ $config_ref->{subvols} };

    foreach my $local_backup (keys %{ $config_ref->{local_backups} }) {

        # make sure the subvol being backed up exists.
        my $subvol = $config_ref->{local_backups}{$local_backup}{subvol};
        unless (grep $subvol, @subvols) {
            push @error_msgs, "yabsm: config error: local_backup '$local_backup' is backing up an undefined subvol '$subvol'";
        }

        # ensure that all required settings are defined.
        my $timeframes = $config_ref->{local_backups}{$local_backup}{timeframes};
        my @required_settings = (@base_required_settings, required_timeframe_settings($timeframes));
        my @defined_settings  = keys $config_ref->{local_backups}{$local_backup};
        my @missing_settings  = array_minus(@required_settings, @defined_settings);
        foreach my $setting (@missing_settings) {
            push @error_msgs, "yabsm: config error: local_backup '$local_backup' is missing required setting '$setting'";
        }
    }

    return wantarray ? @error_msgs : \@error_msgs;
}

sub required_timeframe_settings {

    # Given a timeframes value like 'hourly,daily,monthly' returns a
    # list of required settings. This subroutine is used to
    # dynamically determine what settings are required for certain
    # config entities.

    my $timeframes_val = shift;

    my @timeframes = split ',', $timeframes_val;

    # return this
    my @required;

    foreach my $tframe (@timeframes) {
        if    ($tframe eq '5minute') { push @required, qw(5minute_keep) }
        elsif ($tframe eq 'hourly')  { push @required, qw(hourly_keep) }
        elsif ($tframe eq 'daily')   { push @required, qw(daily_keep daily_time) }
        elsif ($tframe eq 'weekly')  { push @required, qw(weekly_keep weekly_time weekly_day) }
        elsif ($tframe eq 'monthly') { push @required, qw(monthly_keep monthly_time monthly_day) }
        else {
           get_logger->logconfess("yabsm: internal error: no such timeframe '$tframe'");
        }
    }

    return @required;
}
