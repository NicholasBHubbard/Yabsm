#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  This package exists to provide the read_config() function.
#
#  read_config() returns a 3D hash formatted where the first dimension
#  keys are 'subvols', 'backups', and 'misc'. The 'subvols' and
#  'backups' keys associate to other hashes that associate
#  subvol/backup names to a hash of their settings. A key is made in
#  the 'subvols' and 'backups' hashes for each 'define_subvol' and
#  'define_backup' block in the config file. All other settings
#  outside these blocks go into the toplevel 'misc' hash.
#
#  If the config file has any errors they will printed to STDERR and
#  the program will exit with code 1.
#
#  See Yabsmrc.t for the testing of this package.

package Yabsm::Config;

use strict;
use warnings;
use 5.010;

use List::Util 'any';

sub read_config {

    # Read config reads a yabsm configuration file and returns a config hash
    # that has

    my $file = shift // '/etc/yabsmrc';

    open(my $fh, '<', $file) or die "[!] Error: failed to open file '$file'\n";

    # %config will be returned.
    my %config; 

    while (<$fh>) {

	next if /^\s*$/; # skip blank lines
	next if /^\s*#/; # skip comment lines

	s/#.*//;         # remove eol comments
	s/\s+$//;        # remove trailing whitespace

	if (/^define_subvol\s+(\S+)\s+{$/) {
	    my $subvol = $1;

	    if (not $subvol =~ /^[a-zA-Z]/) {
		die "[!] Parse Error (line $.): invalid subvol name '$subvol' does not start with alphabetic character\n";
	    }
	    else {
		$config{subvols}{$subvol} = undef;
	    }

	    # parse define_subvol block
	    while (1) {
		
		$_ = <$fh>;

		if (not defined $_) {
		    die "[!] Parse Error: reached end of file\n";
		}

		next if /^\s*$/; # skip blank lines
		next if /^\s*#/; # skip comment lines
		
		s/#.*//;         # remove eol comments
		s/\s+//g;        # remove all whitespace

		last if /^}$/;   # terminate on closing brace

		my ($key, $val) = split /=/, $_, 2;

		if (not defined $key || not defined $val) {
		    die "[!] Parse Error (line $.): cannot parse '$_'\n";
		}

		# perl hash keys cant start with numbers.
		$key = '_5minute' if $key eq '5minute';
		
		$config{subvols}{$subvol}{$key} = $val;
	    } 
	}

	elsif (/^define_backup\s+(\S+)\s+{$/) {
	    my $backup = $1;

	    if (not $backup =~ /^[a-zA-Z]/) {
		die "[!] Parse Error (line $.): invalid backup name '$backup' does not start with alphabetic character\n";
	    }
	    else {
		$config{backups}{$backup} = undef;
	    }

	    # parse define_backup block
	    while (1) {

		$_ = <$fh>;

		if (not defined $_) {
		    die "[!] Parse Error: reached end of file\n";
		}

		next if /^\s*$/; # skip blank lines
		next if /^\s*#/; # skip comment lines
		
		s/#.*//;         # remove eol comments
		s/\s+//g;        # remove all whitespace
		
		last if /^}$/;   # terminate on closing brace

		my ($key, $val) = split /=/, $_, 2;

		if (not defined $key || not defined $val) {
		    die "[!] Parse Error (line $.): cannot parse '$_'\n";
		}

		$config{backups}{$backup}{$key} = $val;
	    } 
	}

	else { # misc setting

	    s/#.*//g; # remove eol comments
	    s/\s+//g; # remove all whitespace

	    my ($key, $val) = split /=/, $_, 2;

	    if (not defined $key || not defined $val) {
		die "[!] Parse Error (line $.): cannot parse '$_'\n";
	    }

	    $config{misc}{$key} = $val;
	}
    }

    close $fh;

    # Static error checking
    my @errors = _check_config(\%config);

    # We found errors. Print their messages and die.
    if (@errors) {
	# say STDERR $_ for @errors;
	die join "\n", @errors;
    }
    
    # No errors. All good.
    return wantarray ? %config : \%config;
}

sub _check_config {

    # comprehensively check the $config_ref hash. All errors that are found
    # are pushed to the @errors array.

    my ($config_ref) = @_;

    # return this
    my @errors; 

    # check all defined subvols
    foreach my $subvol (keys %{$config_ref->{subvols}}) {

	# we will confirm that all of these settings have been defined.
	my @required_settings = qw(mountpoint 5minute_want 5minute_keep hourly_want hourly_keep midnight_want midnight_keep monthly_want monthly_keep);

	# go through all of the settings for $subvol
	while (my ($key, $val) = each %{$config_ref->{subvols}{$subvol}}) {

	    if ($key eq 'mountpoint') {
		@required_settings = grep { $_ ne $key } @required_settings;
		if (not -d $val) {
		    push @errors, "[!] Config Error: subvol '$subvol': no such directory '$val'"
		}
	    }

	    # *_want setting
	    elsif ($key =~ /^(5minute|hourly|midnight|monthly)_want$/) {
		@required_settings = grep { $_ ne $key } @required_settings;
		if (not ($val eq 'yes' || $val eq 'no')) {
		    push @errors, "[!] Config Error: subvol '$subvol': value for '$key' does not equal yes or no";
		}
	    }

	    # *_keep setting
	    elsif ($key =~ /^(5minute|hourly|midnight|monthly)_keep$/) {
		@required_settings = grep { $_ ne $key } @required_settings;
		if (not $val =~ /^\d+$/) {
		    push @errors, "[!] Config Error: subvol '$subvol': value for '$key' is not an integer greater or equal to 0";
		}
	    }

	    else {
		push @errors, "[!] Config Error: subvol '$subvol': '$key' is not a valid subvol setting";
	    }
	} # end of while each loop
	
	# are we missing required settings?
	if (@required_settings) {
	    for (@required_settings) {
		push @errors, "[!] Config Error: subvol '$subvol': missing required setting '$_'";
	    }
	} 
    } # end of outer loop

    # check backups
    foreach my $backup (keys %{$config_ref->{backups}}) {

	my @required_settings = qw(subvol path keep);
	
	# go through all of the settings for $backup
	while (my ($key, $val) = each %{$config_ref->{backups}{$backup}}) {

	    if ($key eq 'subvol') {
		if (not any { $val eq $_ } keys %{$config_ref->{subvols}}) {
		    push @errors, "[!] Config Error: backup '$backup': no defined subvol '$val'";
		}
		@required_settings = grep { $_ ne $key } @required_settings;
	    }

	    elsif ($key eq 'path') {
		# TODO figure out how to validate backup path
		@required_settings = grep { $_ ne $key } @required_settings;
	    }

	    elsif ($key eq 'keep') {
		if (not ($val =~ /^\d+$/ && $val > 0)) {
		    push @errors, "[!] Config Error: backup '$backup': '$key' is not a positive integer";
		}
		@required_settings = grep { $_ ne $key } @required_settings;
	    }

	    else {
		push @errors, "[!] Config Error: backup '$backup': '$key' is not a valid backup setting";
	    }
	} #end of inner loop

	# missing one or more required settings
	if (@required_settings) {
	    for (@required_settings) {
		push @errors, "[!] Config Error: backup '$backup': missing required setting '$_'";
	    }
	} 
    } # end of outer loop

    # check misc settings
    my @required_misc_settings = qw(snapshot_dir);
    while (my ($key, $val) = each %{$config_ref->{misc}}) {
	
	if ($key eq 'snapshot_dir') {
	    if (not -d $val) {
		push @errors, "[!] Config Error: '$key': no such directory '$val'";
	    }
	    @required_misc_settings =
	      grep { $_ ne $key } @required_misc_settings;
	}
    }
    
    if (@required_misc_settings) {
	for (@required_misc_settings) {
	    push @errors, "[!] Config Error: missing required setting '$_'";
	}
    } 

    return wantarray ? @errors : \@errors;
}

1;
