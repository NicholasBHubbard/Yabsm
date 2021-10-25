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

# located using lib::relative in yabsm.pl
use App::Base;

use Carp;

use Array::Utils 'array_minus';

use Parser::MGC;
use base 'Parser::MGC';

my %regex = ( path      => qr/\/\S*/
            , name      => qr/[a-zA-Z]\w*/
            , whole_num => qr/\d+/
            , nat_num   => qr/[1-9]\d*/
            , comment   => qr/#.*/
            , ident     => qr/[\w-]+/
            );

sub read_config {

    my $file = shift // '/etc/yabsmrc';

    my $parser = __PACKAGE__->new( toplevel => 'p'
                                 , patterns => { comment => $regex{comment}
                                               , ident   => $regex{ident}
                                               }
                                 );

    my $config_ref = $parser->from_file($file);

    my @errors = ();

    push @errors, missing_required_settings($config_ref);
    push @errors, invalid_backup_settings($config_ref);

    # not neccesary due to parser semantics
    # push @errors, invalid_subvol_settings($config_ref);

    if (@errors) {
        die ((join "\n", @errors) . "\n");
    }

    return $config_ref;
}

sub p {

    my $self = shift // confess App::Base::missing_arg();

    my %config;

    $self->sequence_of( sub {
        $self->commit;
        $self->any_of(
            sub {
                $self->token_kw( 'subvol' );
                $self->commit;
                my $name = $self->maybe_expect( $regex{name} );
                $name // $self->fail('expected alphanumeric sequence starting with letter');
                my $kvs  = $self->scope_of('{', 'subvol_def_p', '}');
                $config{subvols}{$name} = $kvs;
            },
            sub {                     
                $self->token_kw( 'backup' );
                $self->commit;
                my $name = $self->maybe_expect( $regex{name} );
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

    my @keywords = subvol_keywords();

    my %kvs; # return this
    my $k;
    my $v;

    $self->sequence_of( sub {
        $self->commit;
        $k = $self->token_kw( @keywords );
        $self->maybe_expect( '=' ) // $self->fail("expected literal '='");
        if ($k eq 'mountpoint') {
            $v = $self->maybe_expect( $regex{path} );
            $v // $self->fail('expected file path');
        }
        elsif ($k =~ /_want$/) {
            $v = $self->maybe( sub { $self->token_kw( 'yes', 'no' ) } );
            $v // $self->fail( q(expected 'yes' or 'no') );
        }
        elsif ($k =~ /_keep$/) {
            $v = $self->maybe_expect( $regex{whole_num} );
            $v // $self->fail('expected whole number');
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

    my @keywords = backup_keywords();

    my %kvs; # return this
    my $k;
    my $v;

    $self->sequence_of( sub {
        $self->commit;
        $k = $self->token_kw( @keywords );
        $self->maybe_expect( '=' ) // $self->fail("expected literal '='");
        if ($k eq 'remote') {
            $v = $self->maybe( sub { $self->token_kw( 'yes', 'no' ) } );
            $v // $self->fail( q(expected 'yes' or 'no') );
        }
        elsif ($k eq 'timeframe') {
            $v = $self->token_kw( 'hourly', 'midnight', 'monthly' );
        }
        elsif ($k eq 'backup_dir') {
            $v = $self->maybe_expect( $regex{path} );
            $v // $self->fail('expected file path');
        }
        elsif ($k eq 'keep') {
            $v = $self->maybe_expect( $regex{nat_num} );
            $v // $self->fail('expected natural number');
        }
        elsif ($k eq 'host') {
            $v = $self->maybe_expect( $regex{name} );
            $v // $self->fail('expected alphanumeric sequence starting with a letter');
        }
        elsif ($k eq 'subvol') {
            # We check that $v is a defined subvol later
            $v = $self->maybe_expect( $regex{name} );
            $v // $self->fail('expected alphanumeric sequence starting with a letter');
        }
        else {
            confess "internal error: no such backup setting '$k'";
        }

        $kvs{ $k } = $v;
    });

    return \%kvs;
}

sub missing_required_settings {

    # Return error messages for every required setting
    # that is not defined.

    my $config_ref = shift // confess App::Base::missing_arg();

    my @err_msgs = ();

    for my $subvol (App::Base::all_subvols($config_ref)) {
        my @required = subvol_keywords();
        my @defined  = keys %{ $config_ref->{subvols}{$subvol} };
        my @missing  = array_minus( @required, @defined );
        push @err_msgs, "config error: subvol '$subvol' missing required setting '$_'" for @missing;
    }

    for my $backup (App::Base::all_backups($config_ref)) {
        my @required = backup_keywords();
        my @defined  = keys %{ $config_ref->{backups}{$backup} };

        # only remote backups require a 'host' setting
        my $remote = $config_ref->{backups}{$backup}{remote} // 'no';
        if ($remote eq 'no') { 
            @required = grep { $_ ne 'host' } @required;
        }

        my @missing = array_minus( @required, @defined );
        push @err_msgs, "config error: backup '$backup' missing required setting '$_'" for @missing;
    }

    # all misc settings are required at this time
    for my $misc (misc_keywords()) {
        if (not exists $config_ref->{misc}{$misc}) {
            push @err_msgs, "config error: missing setting '$misc'";
        }
    }

    return @err_msgs;
}

sub invalid_backup_settings {

    my $config_ref = shift // confess App::Base::missing_arg();

    my @err_msgs = ();

    # check that 'subvol' settings are actually defined subvols.
    for my $backup (App::Base::all_backups($config_ref)) {
        my $subvol = $config_ref->{backups}{$backup}{subvol};
        unless (grep { $subvol eq $_ } App::Base::all_subvols($config_ref)) {
            push @err_msgs, "config error: backup '$backup' backing up non existent subvol '$subvol'"
          }
    }
    
    return @err_msgs;
}

sub subvol_keywords {
    return qw(mountpoint 5minute_want 5minute_keep hourly_want hourly_keep midnight_want midnight_keep monthly_want monthly_keep);
}

sub backup_keywords {
    return qw(remote host subvol backup_dir timeframe keep);
}

sub misc_keywords {
    return qw(yabsm_dir);
}

1;
