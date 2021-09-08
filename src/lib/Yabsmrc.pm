#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  This package exists to provide the read_config() function.
#
#  read_config() returns a 3D hash formatted where the first dimension keys
#  are 'subvols', 'backups', and 'misc'. The 'subvols' and 'backups' keys
#  associate to other hashes that associate subvol/backup names to their
#  settings. A key is made in the 'subvols' and 'backups' hashes for each
#  'define_subvol' and 'define_backup' block in the config file. All other
#  settings outside these blocks go into the toplevel 'misc' hash.
#
#  If the config file has any errors they will printed to STDERR and the
#  program will exit with code 1.
#
#  See Yabsmrc.t for the testing of this package.

package Yabsmrc;

use strict;
use warnings;
use 5.010;

sub read_config {

    my $file = shift // '/etc/yabsmrc';

    open(my $fh, '<', $file) or die "[!] Error: failed to open file '$file'\n";

    my @errors; # passed around to collect config errors

    my %config; # this is returned

    while (my $line = <$fh>) {

	next if $line =~ /^\s*$/; # skip blank lines
	next if $line =~ /^\s*#/; # skip comment lines

	$line =~ s/#.*//;         # remove end of line comments
	$line =~ s/^\s*//;        # remove leading whitespace
	$line =~ s/\s*$//;        # remove trailing whitespace

	if (_is_define_subvol_header($line)) {
	    my $subvol_name = _parse_subvol_name($line);
	    _process_define_subvol_block($fh, \%config, \@errors, $subvol_name);
	    next;
	}

	if (_is_define_backup_header($line)) {
	    my $backup_name = _parse_backup_name($line);
	    _process_define_backup_block($fh, \%config, \@errors, $backup_name);
	    next;
	}

	if (_is_misc_setting($line)) {
	    my ($key, $val) = split /\s*=\s*/, $line, 2;
	    $config{misc}{$key} = $val;
	    next;
	}

	die "[!] Parse Error (line $.): cannot parse '$line'\n";
    }

    close $fh;

    # Static error checking

    # report_invalid_backups

    # We found errors. Print their messages and die.
    if (@errors) {
	say STDERR for @errors;
	exit 1;
    }
    # No errors. All good.
    else { 
	return wantarray ? %config : \%config;
    }
}

sub _is_define_subvol_header {

    my ($line) = @_;

    return $line =~ /^define_subvol\s+.+\s+\{$/; 
}

sub _is_define_backup_header {

    my ($line) = @_;

    return $line =~ /^define_backup\s+.+\s+\{$/
}

sub _parse_subvol_name {

    my ($line) = @_;

    my ($name) = $line =~ /^define_subvol\s+(.+)\s+\{$/;

    if (not $name) {
	die "[!] Parse Error (line $.): cannot parse subvol name from '$line'";
    }

    $name =~ s/\s//g;

    return $name;
}

sub _parse_backup_name {

    my ($line) = @_;
    
    my ($name) = $line =~ /^define_backup\s+(.+)\s+\{$/;
    
    if (not $name) {
	die "[!] Parse Error (line $.): cannot parse backup name from '$line'";
    }

    $name =~ s/\s//g;

    return $name;
}

sub _is_misc_setting {

    my ($line) = @_;

    my %misc_setting = map { $_ => 1 } qw(snapshot_directory);

    my ($setting, undef) = split /\s*=\s*/, $line, 2;

    return $misc_setting{ $setting };
}

sub _process_define_subvol_block {

    my ($fh, $config_ref, $errors_ref, $subvol_name)  = @_;

    while (my $line = <$fh>) {
	
	next if $line =~ /^\s*$/; # skip blank lines
	next if $line =~ /^\s*#/; # skip comment lines

	$line =~ s/#.*//;         # remove end of line comments
	$line =~ s/\s//g;         # strip all whitespace
	
	last if $line =~ /}/;    # done at } 

	my ($key, $val) = split /=/, $line, 2;

	my $valid_setting = _check_subvol_setting($errors_ref, $key, $val);
	
	if ($valid_setting) {
	    $config_ref->{subvols}{$subvol_name}{$key} = $val;
	}
    }
}

sub _process_define_backup_block {

    my ($fh, $config_ref, $errors_ref, $backup_name) = @_;

    while (my $line = <$fh>) {

	next if $line =~ /^\s*$/;  # skip blank lines
	next if $line =~ /^\s*#/;  # skip comment lines

	$line =~ s/#.*//;          # remove end of line comments
	$line =~ s/\s//g;          # strip all whitespace

	last if $line =~ /}/;     # done at }

	my ($key, $val) = split /=/, $line, 2;

	_check_backup_setting($errors_ref, $key, $val);

	$config_ref->{backups}{$backup_name}{$key} = $val;
    }
}

sub _check_subvol_setting {

    # Given a particular $key=$val pair from a 'define_subvol' block
    # check if it is erroneous, and if so push an error message to
    # $errors_ref.

    my ($errors_ref, $key, $val) = @_;

    my %valid_subvol_key = map { $_ => 1 } qw(mountpoint hourly_want hourly_take hourly_keep daily_want daily_take daily_keep midnight_want midnight_keep monthly_want monthly_keep);

    if (not $valid_subvol_key{ $key }) {
	push @$errors_ref, "[!] Config Error (line $.): invalid subvol setting '$key'";
	return 0;
    }

    # key must be valid

    if ($key =~ /_want$/) {
	if (not ($val eq 'yes' || $val eq 'no')) {
	    push @$errors_ref, "[!] Config Error (line $.): '$val' does not equal 'yes' or 'no'";
	    return 0;
	}
	else { return 1 }
    }

    if ($key =~ /_keep$/) {
	if (not $val =~ /^\d+$/) {
	    push @$errors_ref, "[!] Config Error (line $.): '$val' is not a integer greater than or equal to 0";
	    return 0;
	}
	else { return 1 }
    }

    if ($key eq 'hourly_take') {
	if (not ($val =~ /^\d+$/ && $val <= 60)) {
	    push @$errors_ref, "[!] Config Error (line $.): '$val' is not an integer between 0 and 60";
	    return 0;
	}
	else { return 1 }
    }

    if ($key eq 'daily_take') {
	if (not ($val =~ /^\d+$/ && $val <= 24)) {
	    push @$errors_ref, "[!] Config Error (line $.): '$val' is not an integer between 0 and 24";
	    return 0;
	}
	else { return 1 }
    }
}

sub _check_backup_setting {

    # Given a particular $key=$val pair from a 'define_backup' block
    # check if it is erroneous, and if so push an error message to
    # $errors_ref.

    my ($errors_ref, $key, $val) = @_;

    my %valid_backup_key = map { $_ => 1 } qw(subvol path hourly_want hourly_take hourly_keep daily_want daily_take daily_keep midnight_want midnight_keep monthly_want monthly_keep);

    if (not $valid_backup_key{ $key }) {
	push @$errors_ref, "[!] Config Error (line $.): invalid backup setting '$key'";
	return 0;
    }

    # key must be valid

    if ($key =~ /_want$/) {
	if (not ($val eq 'yes' || $val eq 'no')) {
	    push @$errors_ref, "[!] Config Error (line $.): '$val' does not equal 'yes' or 'no'";
	    return 0;
	}
	else { return 1 }
    }

    if ($key =~ /_keep$/) {
	if (not $val =~ /^\d+$/) {
	    push @$errors_ref, "[!] Config Error (line $.): '$val' is not a integer greater than or equal to 0";
	    return 0;
	}
	else { return }
    }

    if ($key eq 'hourly_take') {
	if (not ($val =~ /^\d+$/ && $val <= 60)) {
	    push @$errors_ref, "[!] Config Error (line $.): '$val' is not an integer between 0 and 60";
	    return 0;
	}
	else { return 1 }
    }

    if ($key eq 'daily_take') {
	if (not ($val =~ /^\d+$/ && $val <= 24)) {
	    push @$errors_ref, "[!] Config Error (line $.): '$val' is not an integer between 0 and 24";
	    return 0;
	}
	else { return 1 }
    }
}

1;
