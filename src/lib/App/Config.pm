#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  This module exists to provide the read_config() subroutine that is
#  used to create the $config_ref variable that is passed around the
#  rest of yabsm constantly. See t/Config.t for this modules testing.

package App::Config;

use strict;
use warnings;
use v5.16.3;

use Exporter 'import';
our @EXPORT_OK 'read_config';

# located using lib::relative in yabsm.pl
use App::Base;

use Carp;
use Array::Utils 'array_minus';

use Parser::MGC;
use base 'Parser::MGC';

                 ####################################
                 #         REGEX LOOKUP TABLE       #
                 ####################################

my %regex = ( path         => qr/\/[^#\s]*/
            , subject_name => qr/[a-zA-Z][-\w]*/
            , pos_int      => qr/[1-9]\d*/
            , comment      => qr/#.*/
            , ident        => qr/[-\w]+/
            );

                 ####################################
                 #         MAIN SUBROUTINE          #
                 ####################################

sub read_config {

    my $file = shift // '/etc/yabsm.conf';

    # see documentation of Parser::MGC to see what is going on here
    my $parser = __PACKAGE__->new( toplevel => 'p'
                                 , patterns => { comment => $regex{comment}
                                               , ident   => $regex{ident}
                                               }
                                 );

    my $config_ref = $parser->from_file($file);

    my @errors = ();

    push @errors, $_ for missing_subvol_settings($config_ref);
    push @errors, $_ for missing_backup_settings($config_ref);
    push @errors, $_ for missing_misc_settings($config_ref);

    if (@errors) {
        die ((join "\n", @errors) . "\n");
    }

    return $config_ref;
}

                 ####################################
                 #              PARSER              #
                 ####################################

sub p {

    my $self = shift // confess App::Base::missing_arg();

    my %config;

    $self->sequence_of( sub {
        $self->commit;
        $self->any_of(
            sub {
                $self->token_kw( 'subvol' );
                $self->commit;
                my $name = $self->maybe_expect( $regex{subject_name} );
                $name // $self->fail('expected alphanumeric sequence starting with letter');
                my $kvs  = $self->scope_of('{', 'subvol_def_p', '}');
                $config{subvols}{$name} = $kvs;
            },
            sub {                     
                $self->token_kw( 'backup' );
                $self->commit;
                my $name = $self->maybe_expect( $regex{subject_name} );
                $name // $self->fail('expected alphanumeric sequence starting with letter');
                my $kvs  = $self->scope_of('{', 'backup_def_p', '}');
                $config{backups}{$name} = $kvs;
            },
            sub { 
                my $k = $self->token_kw( misc_keywords() );
                $self->commit;
                $self->maybe_expect( '=' ) // $self->fail("expected '='");
                my $v;
                # the only misc setting at this time is 'yabsm_dir'
                if ($k eq 'yabsm_dir') {
                    $v = $self->maybe_expect( $regex{path} );
                    $v // $self->fail('expected file path');
                }
                else {
                    confess "internal error: no such misc setting '$k'";
                }
                $config{misc}{$k} = $v;
            },
            sub {
                $self->commit;
                $self->fail('could not parse subvol, backup or misc setting');
            }
        );
    });

    return \%config;
}

sub subvol_def_p {

    my $self = shift // confess App::Base::missing_arg();

    my %kvs; # return this
    my $k;
    my $v;

    $self->sequence_of( sub {
        $self->commit;
        $k = $self->token_kw( subvol_keywords() );
        $self->maybe_expect( '=' ) // $self->fail("expected '='");
        if ($k eq 'mountpoint') {
            $v = $self->maybe_expect( $regex{path} );
            $v // $self->fail('expected file path');
        }
        elsif ($k =~ /_want$/) {
            $v = $self->maybe( sub { $self->token_kw( 'yes', 'no' ) } );
            $v // $self->fail( q(expected 'yes' or 'no') );
        }
        elsif ($k =~ /_keep$/) {
            $v = $self->maybe_expect( $regex{pos_int} );
            $v // $self->fail('expected positive integer');
        }
        elsif ($k eq 'weekly_day') {
            $v = $self->token_kw( App::Base::all_days_of_week() );
        }
        else {
            confess "internal error: no such subvol setting '$k'";
        }

        $kvs{ $k } = $v;
    });

    return \%kvs;
}

sub backup_def_p {

    my $self = shift // confess App::Base::missing_arg();

    my %kvs; # return this
    my $k;
    my $v;

    $self->sequence_of( sub {
        $self->commit;
        $k = $self->token_kw( backup_keywords() );
        $self->maybe_expect( '=' ) // $self->fail("expected '='");

        if ($k eq 'remote') {
            $v = $self->maybe( sub { $self->token_kw( 'yes', 'no' ) } );
            $v // $self->fail( q(expected 'yes' or 'no') );
        }
        elsif ($k eq 'timeframe') {
            $v = $self->token_kw( App::Base::all_backup_timeframes() );
        }
        elsif ($k eq 'backup_dir') {
            $v = $self->maybe_expect( $regex{path} );
            $v // $self->fail('expected file path');
        }
        elsif ($k eq 'keep') {
            $v = $self->maybe_expect( $regex{pos_int} );
            $v // $self->fail('expected positive integer');
        }
        elsif ($k eq 'host') {
            $v = $self->maybe_expect( $regex{subject_name} );
            $v // $self->fail('expected alphanumeric sequence starting with a letter');
        }
        elsif ($k eq 'subvol') {
            # We check that $v is a defined subvol later
            $v = $self->maybe_expect( $regex{subject_name} );
            $v // $self->fail('expected alphanumeric sequence starting with a letter');
        }
        elsif ($k eq 'weekly_day') {
            $v = $self->token_kw( App::Base::all_days_of_week() );
        }
        else {
            confess "internal error: no such backup setting '$k'";
        }

        $kvs{ $k } = $v;
    });

    return \%kvs;
}

                 ####################################
                 #       STATIC CONFIG ANALYSIS     #
                 ####################################

sub missing_subvol_settings {

    my $config_ref = shift // confess App::Base::missing_arg();

    my @err_msgs = ();

    for my $subvol (App::Base::all_subvols($config_ref)) {

        # base required settings
        my @req = qw(mountpoint 5minute_want hourly_want midnight_want weekly_want monthly_want);

        my @def = keys %{ $config_ref->{subvols}{$subvol} };

        if (my @missing = array_minus(@req, @def)) {
            push @err_msgs, "error: subvol '$subvol' missing required setting '$_'" for @missing;
        }

        else { # the base required settings are defined

            for my $tframe (App::Base::subvols_timeframes($config_ref, $subvol)) {
                if ($tframe eq '5minute') {
                    push @req, '5minute_keep';
                }
                elsif ($tframe eq 'hourly') {
                    push @req, 'hourly_keep';
                }
                elsif ($tframe eq 'midnight') {
                    push @req, 'midnight_keep';
                }
                elsif ($tframe eq 'weekly') {
                    push @req, 'weekly_keep', 'weekly_day';
                }
                elsif ($tframe eq 'monthly') {
                    push @req, 'monthly_keep';
                }
                else {
                    confess "internal error: no such timeframe '$tframe'";
                }
            }

            my @def = keys %{ $config_ref->{subvols}{$subvol} };

            if (my @missing = array_minus(@req, @def)) {
                push @err_msgs, "error: subvol '$subvol' missing required setting '$_'" for @missing;
            }
        }
    }

    return @err_msgs;
}

sub missing_backup_settings {

    my $config_ref = shift // confess App::Base::missing_arg();

    my @err_msgs = ();

    for my $backup (App::Base::all_backups($config_ref)) {

        # base required settings
        my @req = qw(remote subvol backup_dir timeframe keep);

        my @def = keys %{ $config_ref->{backups}{$backup} };

        if (my @missing = array_minus(@req, @def)) {
            push @err_msgs, "error: backup '$backup' missing required setting '$_'" for @missing;
        }

        else { # the base required settings are defined

            my $subvol = $config_ref->{backups}{$backup}{subvol};
            my $remote = $config_ref->{backups}{$backup}{remote};
            my $tframe = $config_ref->{backups}{$backup}{timeframe};

            if (not grep { $subvol eq $_ } App::Base::all_subvols($config_ref)) {
                push @err_msgs, "error: backup '$backup' backing up undefined subvol '$subvol'";
            }

            if ($remote eq 'yes') {
                push @req, 'host';
            }

            if ($tframe eq 'weekly') {
                push @req, 'weekly_day';
            }

            if (my @missing = array_minus(@req, @def)) {
                push @err_msgs, "error: backup '$backup' missing required setting '$_'" for @missing;
            }
        }
    }

    return @err_msgs;
}

sub missing_misc_settings {

    my $config_ref = shift // confess App::Base::missing_arg();

    my @err_msgs = ();

    # for now all misc settings are required
    my @req = misc_keywords();

    my @def = keys %{ $config_ref->{misc} };

    my @missing = array_minus(@req, @def);

    push @err_msgs, "error: missing misc setting '$_'" for @missing;

    return @err_msgs;
}

                 ####################################
                 #           KEYWORD ARRAYS         #
                 ####################################

sub subvol_keywords {
    return qw(mountpoint 5minute_want 5minute_keep hourly_want hourly_keep midnight_want midnight_keep weekly_want weekly_keep weekly_day monthly_want monthly_keep);
}

sub backup_keywords {
    return qw(subvol remote host keep backup_dir timeframe weekly_day);
}

sub misc_keywords {
    return qw(yabsm_dir);
}

1;
