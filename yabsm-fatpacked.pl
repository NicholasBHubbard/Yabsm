#!/usr/bin/env perl

# This chunk of stuff was generated by App::FatPacker. To find the original
# file's code, look for the end of this BEGIN block or the string 'FATPACK'
BEGIN {
my %fatpacked;

$fatpacked{"Yabsm.pm"} = '#line '.(1+__LINE__).' "'.__FILE__."\"\n".<<'YABSM';
  package Yabsm;use strict;use warnings;use 5.010;use File::Copy 'move';use Time::Piece;use List::Util 'any';use Carp;sub yabsmrc_to_hash {my ($yabsmrc_abs_path)=@_;open (my$yabsmrc,'<',$yabsmrc_abs_path)or die "[!] Error: failed to open file \"$yabsmrc_abs_path\"\n";my%yabsmrc_hash;while (<$yabsmrc>){next if /^[#\s]/;s/\s|#.*//g;my ($key,$val)=split /=/;if ($key eq 'define_subvol'){push @{$yabsmrc_hash{subvols}},$val}else {$yabsmrc_hash{$key}=$val}}close$yabsmrc;return wantarray ? %yabsmrc_hash : \%yabsmrc_hash}sub die_if_invalid_config {my ($config_ref)=@_;my%tmp_config=%$config_ref;my@errors;my$snapshot_directory=$tmp_config{snapshot_directory};if (not defined$snapshot_directory){push@errors,"[!] Config Error: missing required setting: \"snapshot_directory\"\n"}elsif (not -d $snapshot_directory){push@errors,"[!] Config Error: could not find directory \"$snapshot_directory\"\n"}for my$subv_name (@{$tmp_config{subvols}}){my$subv_path=$tmp_config{"${subv_name}_path"};my$hourly_want=$tmp_config{"${subv_name}_hourly_want"};my$hourly_take=$tmp_config{"${subv_name}_hourly_take"};my$hourly_keep=$tmp_config{"${subv_name}_hourly_keep"};my$daily_want=$tmp_config{"${subv_name}_daily_want"};my$daily_take=$tmp_config{"${subv_name}_daily_take"};my$daily_keep=$tmp_config{"${subv_name}_daily_keep"};my$midnight_want=$tmp_config{"${subv_name}_midnight_want"};my$midnight_keep=$tmp_config{"${subv_name}_midnight_keep"};my$monthly_want=$tmp_config{"${subv_name}_monthly_want"};my$monthly_keep=$tmp_config{"${subv_name}_monthly_keep"};delete$tmp_config{"${subv_name}_path"};delete$tmp_config{"${subv_name}_hourly_want"};delete$tmp_config{"${subv_name}_hourly_take"};delete$tmp_config{"${subv_name}_hourly_keep"};delete$tmp_config{"${subv_name}_daily_want"};delete$tmp_config{"${subv_name}_daily_take"};delete$tmp_config{"${subv_name}_daily_keep"};delete$tmp_config{"${subv_name}_midnight_want"};delete$tmp_config{"${subv_name}_midnight_keep"};delete$tmp_config{"${subv_name}_monthly_want"};delete$tmp_config{"${subv_name}_monthly_keep"};if (not $subv_name =~ /^[a-zA-Z]/){push@errors,"[!] Config Error: invalid subvolume name \"$subv_name\" starts with non-alphabetical character\n"}if (not defined$subv_path){push@errors,"[!] Config Error: missing required setting \"${subv_name}_path\"\n"}elsif (not -d $subv_path){push@errors,"[!] Config Error: could not find directory \"$subv_path\"\n"}else {}if (not defined$hourly_want){push@errors,"[!] Config Error: missing required setting \"${subv_name}_hourly_want\"\n"}elsif (not ($hourly_want eq 'yes' || $hourly_want eq 'no')){push@errors,"[!] Config Error: ${subv_name}_hourly_want must be either \"yes\" or \"no\"\n"}else {}if (not defined$hourly_take){push@errors,"[!] Config Error: missing required setting \"${subv_name}_hourly_take\"\n"}elsif (not ($hourly_take =~ /^\d+$/ && $hourly_take <= 60)){push@errors,"[!] Config Error: value for ${subv_name}_hourly_take must be an integer between 0 and 60\n"}else {}if (not defined$hourly_keep){push@errors,"[!] Config Error: missing required setting \"${subv_name}_hourly_keep\"\n"}elsif (not ($hourly_keep =~ /^\d+$/)){push@errors,"[!] Config Error: value for ${subv_name}_hourly_keep must be a positive integer\n"}else {}if (not defined$daily_want){push@errors,"[!] Config Error: missing required setting \"${subv_name}_daily_want\"\n"}elsif (not ($daily_want eq 'yes' || $daily_want eq 'no')){push@errors,"[!] Config Error: ${subv_name}_hourly_want must be either \"yes\" or \"no\"\n"}else {}if (not defined$daily_take){push@errors,"[!] Config Error: missing required setting \"${subv_name}_daily_take\"\n"}elsif (not ($daily_take =~ /^\d+$/ && $daily_take <= 24)){push@errors,"[!] Config Error: value for ${subv_name}_daily_take must be an integer between 0 and 24\n"}else {}if (not defined$daily_keep){push@errors,"[!] Config Error: missing required setting \"${subv_name}_daily_keep\"\n"}elsif (not ($daily_keep =~ /^\d+$/)){push@errors,"[!] Config Error: value for ${subv_name}_daily_keep must be a positive integer\n"}else {}if (not defined$midnight_want){push@errors,"[!] Config Error: missing required setting \"${subv_name}_midnight_want\"\n"}elsif (not ($midnight_want eq 'yes' || $midnight_want eq 'no')){push@errors,"[!] Config Error: ${subv_name}_midnight_want must be either \"yes\" or \"no\"\n"}else {}if (not defined$midnight_keep){push@errors,"[!] Config Error: missing required setting \"${subv_name}_midnight_keep\"\n"}elsif (not ($midnight_keep =~ /^\d+$/)){push@errors,"[!] Config Error: value for ${subv_name}_midnight_keep must be a positive integer\n"}else {}if (not defined$monthly_want){push@errors,"[!] Config Error: missing required setting \"${subv_name}_monthly_want\"\n"}elsif (not ($monthly_want eq 'yes' || $monthly_want eq 'no')){push@errors,"[!] Config Error: ${subv_name}_monthly_want must be either \"yes\" or \"no\"\n"}else {}if (not defined$monthly_keep){push@errors,"[!] Config Error: missing required setting \"${subv_name}_monthly_keep\"\n"}elsif (not ($monthly_keep =~ /^\d+$/)){push@errors,"[!] Config Error: value for ${subv_name}_monthly_keep must be a positive integer\n"}else {}}delete$tmp_config{snapshot_directory};delete$tmp_config{subvols};for my$key (keys%tmp_config){push@errors,"[!] Config Error: unknown setting \"$key\"\n"}if (@errors){print STDERR for@errors;exit 1}return}sub initialize_directories {my ($config_ref)=@_;my$yabsm_root_dir=$config_ref->{snapshot_dir}."/yabsm";mkdir$yabsm_root_dir;for my$subv_name (keys %{$config_ref->{yabsm_subvols}}){mkdir "$yabsm_root_dir/$subv_name";mkdir "$yabsm_root_dir/$subv_name/hourly" if ($config_ref->{"${subv_name}_hourly_want"}eq 'yes');mkdir "$yabsm_root_dir/$subv_name/daily" if ($config_ref->{"${subv_name}_daily_want"}eq 'yes');mkdir "$yabsm_root_dir/$subv_name/midnight" if ($config_ref->{"${subv_name}_midnight_want"}eq 'yes');mkdir "$yabsm_root_dir/$subv_name/monthly" if ($config_ref->{"${subv_name}_monthly_want"}eq 'yes')}return}sub target_dir {my ($config_ref,$subvol)=@_;my$snapshot_root_dir=$config_ref->{snapshot_directory};return "$snapshot_root_dir/yabsm/$subvol"}sub ask_for_subvolume {my ($config_ref)=@_;my@all_subvols=sort {$a cmp $b}@{$config_ref->{subvols}};return$all_subvols[0]if scalar@all_subvols==1;my%int_subvol_hash;for (my$i=0;$i < scalar@all_subvols;$i++){$int_subvol_hash{$i + 1 }=$all_subvols[$i]}say 'select subvolume:';for (my$i=1;$i <= scalar keys%int_subvol_hash;$i++){my$key=$i;my$val=$int_subvol_hash{$key };if ($i % 4==0){print "$key -> $val\n"}else {print "$key -> $val     "}}print "\n>>> ";my$input=<STDIN>;$input =~ s/\s//g;exit 0 if$input =~ /^q(uit)?$/;if (defined$int_subvol_hash{$input }){return$int_subvol_hash{$input }}else {print "No option \"$input\"! Try again!\n\n";ask_for_subvolume($config_ref)}}sub ask_for_query {print "enter query:\n>>> ";my$input=<STDIN>;$input =~ s/^\s+|[\s]+$//g;exit 0 if$input =~ /^q(uit)?$/;if (is_valid_query($input)){return$input}else {print "\"$input\" is not a valid query! Try again!\n\n";return ask_for_query()}}sub get_all_snapshots_of {my ($config_ref,$subvol)=@_;my$target_dir=target_dir($config_ref,$subvol);my@all_snaps;for my$tf ('hourly','daily','midnight','monthly'){if (-d "$target_dir/$tf/"){push@all_snaps,glob "$target_dir/$tf/*"}}my$snaps_sorted_ref=sort_snapshots(\@all_snaps);return wantarray ? @$snaps_sorted_ref : $snaps_sorted_ref}sub all_subvols {my ($config_ref)=@_;my$subvols_ref=$config_ref->{subvols};return wantarray ? @$subvols_ref : $subvols_ref}sub snapstring_to_nums {my ($snap)=@_;my@nums=$snap =~ /day=(\d{4})_(\d{2})_(\d{2}),time=(\d{2}):(\d{2})$/;return wantarray ? @nums : \@nums}sub nums_to_snapstring {my ($yr,$mon,$day,$hr,$min)=map {sprintf '%02d',$_}@_;return "day=${yr}_${mon}_${day},time=${hr}:$min"}sub snapstring_to_time_piece_obj {my ($snap)=@_;my ($yr,$mon,$day,$hr,$min)=snapstring_to_nums($snap);return Time::Piece->strptime("$yr/$mon/$day/$hr/$min",'%Y/%m/%d/%H/%M')}sub time_piece_obj_to_snapstring {my ($time_piece_obj)=@_;my$yr=$time_piece_obj->year;my$mon=$time_piece_obj->mon;my$day=$time_piece_obj->mday;my$hr=$time_piece_obj->hour;my$min=$time_piece_obj->min;return nums_to_snapstring($yr,$mon,$day,$hr,$min)}sub sort_snapshots {my ($snaps_ref)=@_;my@sorted_snaps=sort {compare_snapshots($a,$b)}@$snaps_ref;return wantarray ? @sorted_snaps : \@sorted_snaps}sub compare_snapshots {my ($snap1,$snap2)=@_;my@snap1_nums=snapstring_to_nums($snap1);my@snap2_nums=snapstring_to_nums($snap2);for (my$i=0;$i < scalar@snap1_nums;$i++){return 1 if$snap1_nums[$i]< $snap2_nums[$i];return -1 if$snap1_nums[$i]> $snap2_nums[$i]}return 0}sub n_units_ago {my ($n,$unit)=@_;my$seconds_per_unit;if ($unit =~ /^(m|mins|minutes)$/){$seconds_per_unit=60}elsif ($unit =~ /^(h|hrs|hours)$/){$seconds_per_unit=3600}elsif ($unit =~ /^(d|days)$/){$seconds_per_unit=86400}else {croak "\"$unit\" is an invalid time unit\n"}my$current_time=current_time_string();my$time_piece_obj=snapstring_to_time_piece_obj($current_time);$time_piece_obj -= ($n * $seconds_per_unit);return time_piece_obj_to_snapstring($time_piece_obj)}sub snap_closest_to {my ($all_snaps_ref,$target_snap)=@_;for my$snap (@$all_snaps_ref){my$cmp=compare_snapshots($snap,$target_snap);return$snap if$cmp==0 || $cmp==1}warn "[!] WARNING: couldn't find a snapshot close to \"$target_snap\", instead returning the oldest snapshot\n";return @$all_snaps_ref[-1]}sub answer_query {my ($config_ref,$subvol,$query)=@_;my$all_snaps_ref=get_all_snapshots_of($config_ref,$subvol);my$snap_to_return;if (is_literal_time($query)){my@nums=$query =~ m/^(\d{4})([- ])(\d{1,2})\2(\d{1,2})\2(\d{1,2})\2(\d{1,2})$/;@nums=grep {$_ ne $2}@nums;my$nums_as_snapstring=nums_to_snapstring(@nums);$snap_to_return=snap_closest_to($all_snaps_ref,$nums_as_snapstring)}elsif (is_relative_time($query)){my (undef,$n,$units)=split /[- ]/,$query;my$n_units_ago=n_units_ago($n,$units);$snap_to_return=snap_closest_to($n_units_ago,$all_snaps_ref)}return$snap_to_return}sub is_valid_query {my ($query)=@_;if (is_literal_time($query)){return 1}elsif (is_relative_time($query)){return 1}else {return 0}}sub is_literal_time {my ($query)=@_;return$query =~ /^\d{4}([- ])\d{1,2}\1\d{1,2}\1\d{1,2}\1\d{1,2}$/}sub is_relative_time {my ($query)=@_;my ($mode,$amount,$unit)=split /[- ]/,$query,3;return 0 if any {not defined}($mode,$amount,$unit);my$mode_correct=$mode =~ /^(b|back)$/;my$amount_correct=$amount =~ /^[0-9]+$/;my$unit_correct=any {$_ eq $unit}qw/m mins minutes h hrs hours d days/;return$mode_correct && $amount_correct && $unit_correct}sub is_subvol {my ($config_ref,$subvol)=@_;return any {$_ eq $subvol}@{$config_ref->{subvols}}}sub is_timeframe {my ($tframe)=@_;return any {$_ eq $tframe}qw/hourly daily midnight monthly/}sub update_etc_crontab {my ($config_ref)=@_;open (my$etc_crontab,'<','/etc/crontab')or die "[!] Error: failed to open /etc/crontab\n";open (my$tmp,'>','/tmp/yabsm-update-tmp')or die "[!] Error: failed to open tmp file at /tmp/yabsm-update-tmp\n";while (<$etc_crontab>){next if /yabsm --take-snap/;print$tmp $_}print$tmp "\n";my@cron_strings=generate_cron_strings($config_ref);say$tmp $_ for@cron_strings;close$etc_crontab;close$tmp;move '/tmp/yabsm-update-tmp','/etc/crontab';return}sub generate_cron_strings {my ($config_ref)=@_;my@cron_strings;for my$subv_name (@{$config_ref->{subvols}}){my$hourly_want=$config_ref->{"${subv_name}_hourly_want"};my$hourly_take=$config_ref->{"${subv_name}_hourly_take"};my$daily_want=$config_ref->{"${subv_name}_daily_want"};my$daily_take=$config_ref->{"${subv_name}_daily_take"};my$midnight_want=$config_ref->{"${subv_name}_midnight_want"};my$monthly_want=$config_ref->{"${subv_name}_monthly_want"};my$hourly_cron=('*/' .int(60 / $hourly_take).' * * * * root' .' /usr/local/bin/yabsm' ." --take-snap $subv_name hourly")if$hourly_want eq 'yes';my$daily_cron=('0 */' .int(24 / $daily_take).' * * * root' .' /usr/local/bin/yabsm' ." --take-snap $subv_name daily")if$daily_want eq 'yes';my$midnight_cron=('59 23 * * * root' .' /usr/local/bin/yabsm' ." --take-snap $subv_name midnight")if$midnight_want eq 'yes';my$monthly_cron=('0 0 1 * * root' .' /usr/local/bin/yabsm' ." --take-snap $subv_name monthly")if$monthly_want eq 'yes';push@cron_strings,grep {defined}($hourly_cron,$daily_cron,$midnight_cron,$monthly_cron)}return wantarray ? @cron_strings : \@cron_strings}sub take_new_snapshot {my ($config_ref,$subvol,$timeframe)=@_;my$target_dir=target_dir($config_ref,$subvol);my$snapshot_name=current_time_string();system("btrfs subvolume snapshot -r $target_dir/$timeframe/$snapshot_name");return}sub current_time_string {my ($min,$hr,$day,$mon,$yr)=map {sprintf '%02d',$_}(localtime)[1..5];$mon++;$yr += 1900;return "day=${yr}_${mon}_${day},time=${hr}:$min"}sub delete_appropriate_snapshots {my ($config_ref,$subvol,$timeframe)=@_;my$existing_snaps_ref=get_all_snapshots_of($config_ref,$subvol);my$target_dir=target_dir($config_ref,$subvol);my$num_snaps=scalar @$existing_snaps_ref;my$num_to_keep=$config_ref->{"${subvol}_${timeframe}_keep"};if ($num_snaps==$num_to_keep + 1){my$oldest_snap=pop @$existing_snaps_ref;system("btrfs subvolume delete $target_dir/$timeframe/$oldest_snap");return}elsif ($num_snaps <= $num_to_keep){return}else {while ($num_snaps > $num_to_keep){my$oldest_snap=pop @$existing_snaps_ref;system("btrfs subvolume delete $target_dir/$timeframe/$oldest_snap");$num_snaps--}}return}1;
YABSM

s/^  //mg for values %fatpacked;

my $class = 'FatPacked::'.(0+\%fatpacked);
no strict 'refs';
*{"${class}::files"} = sub { keys %{$_[0]} };

if ($] < 5.008) {
  *{"${class}::INC"} = sub {
    if (my $fat = $_[0]{$_[1]}) {
      my $pos = 0;
      my $last = length $fat;
      return (sub {
        return 0 if $pos == $last;
        my $next = (1 + index $fat, "\n", $pos) || $last;
        $_ .= substr $fat, $pos, $next - $pos;
        $pos = $next;
        return 1;
      });
    }
  };
}

else {
  *{"${class}::INC"} = sub {
    if (my $fat = $_[0]{$_[1]}) {
      open my $fh, '<', \$fat
        or die "FatPacker error loading $_[1] (could be a perl installation issue?)";
      return $fh;
    }
    return;
  };
}

unshift @INC, bless \%fatpacked, $class;
  } # END OF FATPACK CODE


#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm

use strict;
use warnings;
use 5.010;

sub usage {
    print <<END_USAGE;
Usage: yabsm [OPTION]

  --take-snap, -s <SUBVOL> <TIMEFRAME>    take a new snapshot

  --find, -f <?SUBVOL> <?QUERY>           find a snapshot of SUBVOL using QUERY

  --update-crontab, -u                    update cronjobs in /etc/crontab, based
                                          off settings specified in /etc/yabsmrc

  --check-config, -c                      check /etc/yabsmrc for errors. If
                                          errors are present print their info
                                          to stdout. Exit with code 0 in either
                                          case.

  --help, -h                              print help (this message) and exit

  Please see 'man yabsm' for more detailed information about yabsm.
END_USAGE
}

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);

# Import Yabsm.pm
use FindBin '$Bin';
use lib "$Bin/lib";
use Yabsm;

my @YABSM_TAKE_SNAPSHOT;
my $UPDATE_CRONTAB;
my @YABSM_FIND;
my $CHECK_CONFIG;
my $HELP;

GetOptions( 'take-snap|s=s{2}' => \@YABSM_TAKE_SNAPSHOT
	  , 'find|f=s{0,2}'    => \@YABSM_FIND
	  , 'update-crontab|u' => \$UPDATE_CRONTAB
	  , 'check-config|c'   => \$CHECK_CONFIG
	  , 'help|h'           => \$HELP
	  );

if ($HELP) {
    usage();
    exit 0;
}

if ($CHECK_CONFIG) {
    my %CONFIG = Yabsm::yabsmrc_to_hash('/etc/yabsmrc');  
    Yabsm::die_if_invalid_config(\%CONFIG);
    exit 0;
}

# TODO: change this to /etc/yabsmrc for production
my %CONFIG = Yabsm::yabsmrc_to_hash('/etc/yabsmrc');
Yabsm::die_if_invalid_config(\%CONFIG);

if ($UPDATE_CRONTAB) {

    die "[!] Error: must be root to update /etc/crontab\n" if $<;

    update_etc_crontab(\%CONFIG);

    exit 0;
}

if (@YABSM_TAKE_SNAPSHOT) {

    die "[!] Error: must be root to take a new snapshot\n" if $<;

    # --take-snapshot option takes two string args. We can be sure
    # that both args are defined as Getopt::Long will kill the program
    # if they are not.
    my ($subvol, $timeframe) = @YABSM_TAKE_SNAPSHOT;
    
    if (not is_subvol(\%CONFIG, $subvol)) {
	die "[!] Error: \"$subvol\" is not a yabsm subvolume\n";
    }

    if (not is_timeframe($timeframe)) {
	die "[!] Error: \"$timeframe\" is not a valid timeframe\n";
    }

    Yabsm::take_new_snapshot(\%CONFIG, $subvol, $timeframe);
    Yabsm::delete_appropiate_snapshots(\%CONFIG, $subvol, $timeframe);

    exit 0;
}


if (@YABSM_FIND) {

    # these variables may or may not be defined.
    my ($arg1, $arg2) = @YABSM_FIND;

    # the following logic exists to set the $subvol and $query variables
    my ($subvol, $query);

    if ($arg1) {
	if (Yabsm::is_subvol(\%CONFIG, $arg1)) {
	    $subvol = $arg1;
	}
	elsif (Yabsm::is_valid_query($arg1)) {
	    $query = $arg1;
	}
	else {
	    die "[!] Error: \"$arg1\" is neither a subvolume or query\n";
	}
    }
    
    if ($arg2) {
	if (Yabsm::is_subvol(\%CONFIG, $arg2)) {
	    $subvol = $arg2;
	}
	elsif (Yabsm::is_valid_query($arg2)) {
	    $query = $arg2;
	}
	else {
	    die "[!] Error: \"$arg2\" is neither a subvolume or query\n";
	}
    }

    if (not defined $subvol) {
	$subvol = Yabsm::ask_for_subvolume(\%CONFIG);
    }

    if (not defined $query) {
	$query = Yabsm::ask_for_query();
    }

    # $subvol and $query are properly set at this point
    my $snapshot_path = Yabsm::answer_query(\%CONFIG, $subvol, $query);

    say $snapshot_path;

    exit 0;
}

# no options were passed
usage();
exit 1;
