#!/usr/bin/env perl

# This chunk of stuff was generated by App::FatPacker. To find the original
# file's code, look for the end of this BEGIN block or the string 'FATPACK'
BEGIN {
my %fatpacked;

$fatpacked{"Yabsm/Base.pm"} = '#line '.(1+__LINE__).' "'.__FILE__."\"\n".<<'YABSM_BASE';
  package Yabsm::Base;use strict;use warnings;use 5.010;use Time::Piece;use Net::OpenSSH;use List::Util 'any';use File::Copy 'move';use File::Path 'make_path';use Carp;sub all_snapshots_of {my$config_ref=shift // croak;my$subject=shift // croak;my@timeframes=@_;my@all_snaps;if (is_subvol($config_ref,$subject)){my$subvol=$subject;if (not @timeframes){@timeframes=qw(5minute hourly midnight monthly)}for my$tf (@timeframes){my$snap_dir=local_snap_dir($config_ref,$subvol,$tf);if (-d $snap_dir){push@all_snaps,glob "$snap_dir/*"}}}elsif (is_local_backup($config_ref,$subject)){my$backup=$subject;my$backup_dir=$config_ref->{backups}{$backup}{backup_dir};@all_snaps=glob "$backup_dir/*"}elsif (is_remote_backup($config_ref,$subject)){my$backup=$subject;my$remote_host=$config_ref->{backups}{$backup}{host};my$backup_dir=$config_ref->{backups}{$backup}{backup_dir};my$ssh=new_ssh_connection($remote_host);@all_snaps=map {chomp;$_="$remote_host:$_"}$ssh->capture("ls -d $backup_dir/*")}else {croak}my$snaps_sorted_ref=sort_snaps(\@all_snaps);return wantarray ? @$snaps_sorted_ref : $snaps_sorted_ref}sub initialize_directories {my$config_ref=shift // croak;my$yabsm_root_dir=$config_ref->{misc}{yabsm_snapshot_dir};if (not -d $yabsm_root_dir){make_path($yabsm_root_dir)}if (not -d $yabsm_root_dir .'/.tmp'){make_path($yabsm_root_dir .'/.tmp')}for my$subvol (all_subvols($config_ref)){my$subvol_dir="$yabsm_root_dir/$subvol";if (not -d $subvol_dir){make_path($subvol_dir)}my$_5minute_want=$config_ref->{subvols}{$subvol}{_5minute_want};my$hourly_want=$config_ref->{subvols}{$subvol}{hourly_want};my$midnight_want=$config_ref->{subvols}{$subvol}{midnight_want};my$monthly_want=$config_ref->{subvols}{$subvol}{monthly_want};if ($_5minute_want eq 'yes' && not -d "$subvol_dir/5minute"){make_path("$subvol_dir/5minute")}if ($hourly_want eq 'yes' && not -d "$subvol_dir/hourly"){make_path("$subvol_dir/hourly")}if ($midnight_want eq 'yes' && not -d "$subvol_dir/midnight"){make_path("$subvol_dir/midnight")}if ($monthly_want eq 'yes' && not -d "$subvol_dir/monthly"){make_path("$subvol_dir/monthly")}for my$backup (all_backups_of_subvol($config_ref,$subvol)){if (not -d "$subvol_dir/.backups/$backup/bootstrap-snap"){make_path("$subvol_dir/.backups/$backup/bootstrap-snap")}}}return}sub local_snap_dir {my$config_ref=shift // croak;my$subvol=shift;my$timeframe=shift;my$yabsm_dir=$config_ref->{misc}{yabsm_snapshot_dir};if (defined$subvol){$yabsm_dir .= "/$subvol";if (defined$timeframe){$yabsm_dir .= "/$timeframe"}}return$yabsm_dir}sub bootstrap_snap_dir {my$config_ref=shift // croak;my$backup=shift // croak;my$subvol=$config_ref->{backups}{$backup}{subvol};my$yabsm_dir=$config_ref->{misc}{yabsm_snapshot_dir};return "$yabsm_dir/$subvol/.backups/$backup/bootstrap-snap"}sub is_snapstring {my ($snapstring)=@_;return$snapstring =~ /day=\d{4}_\d{2}_\d{2},time=\d{2}:\d{2}$/}sub current_time_snapstring {my ($min,$hr,$day,$mon,$yr)=map {sprintf '%02d',$_}(localtime)[1..5];$mon++;$yr += 1900;return "day=${yr}_${mon}_${day},time=${hr}:$min"}sub n_units_ago_snapstring {my$n=shift // croak;my$unit=shift // croak;my$seconds_per_unit;if ($unit =~ /^(m|mins|minutes)$/){$seconds_per_unit=60}elsif ($unit =~ /^(h|hrs|hours)$/){$seconds_per_unit=3600}elsif ($unit =~ /^(d|days)$/){$seconds_per_unit=86400}else {croak "\"$unit\" is not a valid time unit"}my$current_time=current_time_snapstring();my$time_piece_obj=snapstring_to_time_piece_obj($current_time);$time_piece_obj -= ($n * $seconds_per_unit);return time_piece_obj_to_snapstring($time_piece_obj)}sub immediate_to_snapstring {my$all_snaps_ref=shift // croak;my$imm=shift // croak;if (is_literal_time($imm)){return literal_time_to_snapstring($imm)}if (is_relative_time($imm)){return relative_time_to_snapstring($imm)}if (is_newest_time($imm)){return newest_snap($all_snaps_ref)}if (is_oldest_time($imm)){return oldest_snap($all_snaps_ref)}croak "[!] Internal Error: '$imm' is not an immediate"}sub literal_time_to_snapstring {my$lit_time=shift // croak;my$yr_mon_day_hr_min='^(\d{4})-(\d{1,2})-(\d{1,2})-(\d{1,2})-(\d{1,2})$';my$yr_mon_day='^(\d{4})-(\d{1,2})-(\d{1,2})$';my$mon_day='^(\d{1,2})-(\d{1,2})$';my$mon_day_hr='^(\d{1,2})-(\d{1,2})-(\d{1,2})$';my$mon_day_hr_min='^(\d{1,2})-(\d{1,2})-(\d{1,2})-(\d{1,2})$';if ($lit_time =~ /$yr_mon_day_hr_min/){return nums_to_snapstring($1,$2,$3,$4,$5)}if ($lit_time =~ /$yr_mon_day/){return nums_to_snapstring($1,$2,$3,0,0)}if ($lit_time =~ /$mon_day/){my$t=localtime;return nums_to_snapstring($t->year,$1,$2,0,0)}if ($lit_time =~ /$mon_day_hr/){my$t=localtime;return nums_to_snapstring($t->year,$1,$2,$3,0)}if ($lit_time =~ /$mon_day_hr_min/){my$t=localtime;return nums_to_snapstring($t->year,$1,$2,$3,$4)}croak "[!] Internal Error: '$lit_time' is not a valid literal time"}sub relative_time_to_snapstring {my$rel_time=shift // croak;my (undef,$amount,$unit)=split '-',$rel_time,3;my$n_units_ago_snapstring=n_units_ago_snapstring($amount,$unit);return$n_units_ago_snapstring}sub snapstring_to_nums {my$snap=shift // croak;my@nums=$snap =~ /day=(\d{4})_(\d{2})_(\d{2}),time=(\d{2}):(\d{2})$/;return wantarray ? @nums : \@nums}sub nums_to_snapstring {my ($yr,$mon,$day,$hr,$min)=map {sprintf '%02d',$_}@_;return "day=${yr}_${mon}_${day},time=${hr}:$min"}sub snapstring_to_time_piece_obj {my$snap=shift // croak;my ($yr,$mon,$day,$hr,$min)=snapstring_to_nums($snap);return Time::Piece->strptime("$yr/$mon/$day/$hr/$min",'%Y/%m/%d/%H/%M')}sub time_piece_obj_to_snapstring {my$time_piece_obj=shift // croak;my$yr=$time_piece_obj->year;my$mon=$time_piece_obj->mon;my$day=$time_piece_obj->mday;my$hr=$time_piece_obj->hour;my$min=$time_piece_obj->min;return nums_to_snapstring($yr,$mon,$day,$hr,$min)}sub sort_snaps {my$snaps_ref=shift // croak;my@sorted_snaps=sort {cmp_snaps($a,$b)}@$snaps_ref;return wantarray ? @sorted_snaps : \@sorted_snaps}sub cmp_snaps {my$snap1=shift // croak;my$snap2=shift // croak;my@snap1_nums=snapstring_to_nums($snap1);my@snap2_nums=snapstring_to_nums($snap2);for (my$i=0;$i <= $#snap1_nums;$i++){return -1 if$snap1_nums[$i]> $snap2_nums[$i];return 1 if$snap1_nums[$i]< $snap2_nums[$i]}return 0}sub ask_user_for_subvol_or_backup {my$config_ref=shift // croak;my$int=1;my%int_subvol_hash=map {$int++=>$_}all_subvols($config_ref);my%int_backup_hash=map {$int++=>$_}all_backups($config_ref);my$selection;while (not defined$selection){my$int=1;my$iter;for ($iter=1;$iter <= keys%int_subvol_hash;$iter++){my$subvol=$int_subvol_hash{$int };if ($iter==1){print "Subvols:\n"}if ($iter % 3==0){print "$int -> $subvol\n"}else {print "$int -> $subvol" .' 'x4}$int++}for ($iter=1;$iter <= keys%int_backup_hash;$iter++){my$backup=$int_backup_hash{$int };if ($iter==1){print "\nBackups:\n"}if ($iter % 3==0){print "$int -> $backup\n"}else {print "$int -> $backup" .' 'x4}$int++}if ($iter % 3==0){print '>>> '}else {print "\n>>> "}my$input=<STDIN>;my$cleansed=$input =~ s/\s+//gr;exit 0 if$cleansed =~ /^q(uit)?$/;if (exists$int_subvol_hash{$cleansed }){$selection=$int_subvol_hash{$cleansed }}elsif (exists$int_backup_hash{$cleansed }){$selection=$int_backup_hash{$cleansed }}else {print "No option '$input'! Try again!\n\n"}}return$selection}sub ask_user_for_query {my$query;while (not defined$query){print "enter query:\n>>> ";my$input=<STDIN>;$input =~ s/^\s+|\s+$//g;exit 0 if$input =~ /^q(uit)?$/;if (is_valid_query($input)){$query=$input}else {print "'$input' is not a valid query! Try again!\n\n"}}return$query}sub snap_closest_to {my$all_snaps_ref=shift // croak;my$target_snap=shift // croak;my$snap;for (my$i=0;$i <= $#{$all_snaps_ref};$i++){my$this_snap=$all_snaps_ref->[$i];my$cmp=cmp_snaps($this_snap,$target_snap);if ($cmp==0){$snap=$this_snap;last}if ($cmp==1){if ($i==0){$snap=$this_snap}else {my$prev_snap=$all_snaps_ref->[$i-1];$snap=snap_closer($target_snap,$prev_snap,$this_snap)}last}}if (not defined$snap){$snap=oldest_snap($all_snaps_ref)}return$snap}sub snap_closer {my$target_snap=shift // croak;my$snap1=shift // croak;my$snap2=shift // croak;my$target_epoch=snapstring_to_time_piece_obj($target_snap)->epoch;my$snap1_epoch=snapstring_to_time_piece_obj($snap1)->epoch;my$snap2_epoch=snapstring_to_time_piece_obj($snap2)->epoch;my$v1=abs($target_epoch - $snap1_epoch);my$v2=abs($target_epoch - $snap2_epoch);if ($v1 <= $v2){return$snap1}else {return$snap2}}sub snaps_newer {my$all_snaps_ref=shift // croak;my$target_snap=shift // croak;my@snaps_newer=();for (my$i=0;$i <= $#{$all_snaps_ref};$i++){my$this_snap=$all_snaps_ref->[$i];my$cmp=cmp_snaps($this_snap,$target_snap);if ($cmp==-1){push@snaps_newer,$this_snap}else {last}}return wantarray ? @snaps_newer : \@snaps_newer}sub snaps_older {my$all_snaps_ref=shift // croak;my$target_snap=shift // croak;my@snaps_older=();my$last_idx=$#{$all_snaps_ref};for (my$i=0;$i <= $last_idx;$i++){my$this_snap=$all_snaps_ref->[$i];my$cmp=cmp_snaps($this_snap,$target_snap);if ($cmp==1){@snaps_older=@{$all_snaps_ref}[$i .. $last_idx];last}}return wantarray ? @snaps_older : \@snaps_older}sub snaps_between {my$all_snaps_ref=shift // croak;my$target_snap1=shift // croak;my$target_snap2=shift // croak;my$older;my$newer;if (-1==cmp_snaps($target_snap1,$target_snap2)){$newer=$target_snap1;$older=$target_snap2}else {$newer=$target_snap2;$older=$target_snap1}my@snaps_between=();my$last_idx=$#{$all_snaps_ref};for (my$i=0;$i <= $last_idx;$i++){my$this_snap=$all_snaps_ref->[$i];my$cmp=cmp_snaps($this_snap,$newer);if ($cmp==1 || $cmp==0){push@snaps_between,$this_snap if$cmp==0;for (my$j=$i+1;$j <= $last_idx;$j++){my$this_snap=$all_snaps_ref->[$j];my$cmp=cmp_snaps($this_snap,$older);if ($cmp==1 || $cmp==0){push@snaps_between,$this_snap if$cmp==0;last}else {push@snaps_between,$this_snap}}last}}return wantarray ? @snaps_between : \@snaps_between}sub newest_snap {my$ref=shift // croak;my$subvol=shift;my$newest_snap;if (ref($ref)eq 'ARRAY'){$newest_snap=$ref->[0]}elsif (ref($ref)eq 'HASH'){my$all_snaps_ref=all_snapshots_of($ref,$subvol);$newest_snap=$all_snaps_ref->[0]}else {croak}return$newest_snap}sub oldest_snap {my$ref=shift // croak;my$subvol=shift;my$oldest_snap;if (ref($ref)eq 'ARRAY'){$oldest_snap=$ref->[-1]}elsif (ref($ref)eq 'HASH'){my$all_snaps_ref=all_snapshots_of($ref,$subvol);$oldest_snap=$all_snaps_ref->[-1]}else {croak}return$oldest_snap}sub answer_query {my$config_ref=shift // croak;my$subject=shift // croak;my$query=shift // croak;my$all_snaps_ref=all_snapshots_of($config_ref,$subject);my@snaps_to_return;if (is_immediate($query)){my$target=immediate_to_snapstring($all_snaps_ref,$query);my$snap=snap_closest_to($all_snaps_ref,$target);push@snaps_to_return,$snap}elsif (is_all_query($query)){@snaps_to_return=@$all_snaps_ref}elsif (is_newer_query($query)){my (undef,$immediate)=split /\s/,$query,2;my$target=immediate_to_snapstring($all_snaps_ref,$immediate);@snaps_to_return=snaps_newer($all_snaps_ref,$target)}elsif (is_older_query($query)){my (undef,$immediate)=split /\s/,$query,2;my$target=immediate_to_snapstring($all_snaps_ref,$immediate);@snaps_to_return=snaps_older($all_snaps_ref,$target)}elsif (is_between_query($query)){my (undef,$imm1,$imm2)=split /\s/,$query,3;my$target1=immediate_to_snapstring($all_snaps_ref,$imm1);my$target2=immediate_to_snapstring($all_snaps_ref,$imm2);@snaps_to_return=snaps_between($all_snaps_ref,$target1,$target2)}else {croak "[!] Internal Error: '$query' is not a valid query"}return wantarray ? @snaps_to_return : \@snaps_to_return}sub is_valid_query {my$query=shift // croak;if (is_immediate($query)){return 1}if (is_all_query($query)){return 1}if (is_newer_query($query)){return 1}if (is_older_query($query)){return 1}if (is_between_query($query)){return 1}return 0}sub is_immediate {my$imm=shift // croak;return is_newest_time($imm)|| is_oldest_time($imm)|| is_literal_time($imm)|| is_relative_time($imm)}sub is_literal_time {my$lit_time=shift // croak;my$re1='^\d{4}-\d{1,2}-\d{1,2}-\d{1,2}-\d{1,2}$';my$re2='^\d{4}-\d{1,2}-\d{1,2}$';my$re3='^\d{1,2}-\d{1,2}$';my$re4='^\d{1,2}-\d{1,2}-\d{1,2}$';my$re5='^\d{1,2}-\d{1,2}-\d{1,2}-\d{1,2}$';return any {$lit_time =~ /$_/}($re1,$re2,$re3,$re4,$re5)}sub is_relative_time {my$query=shift // croak;my ($back,$amount,$unit)=split '-',$query,3;return 0 if any {not defined}($back,$amount,$unit);my$back_correct=$back =~ /^b(ack)?$/;my$amount_correct=$amount =~ /^\d+$/;my$unit_correct=any {$_ eq $unit}qw/minutes mins m hours hrs h days d/;return$back_correct && $amount_correct && $unit_correct}sub is_newer_query {my$query=shift // croak;my ($keyword,$imm)=split /\s/,$query,2;return 0 if any {not defined}($keyword,$imm);my$keyword_correct=$keyword =~ /^(newer|after)$/;my$imm_correct=is_immediate($imm);return$keyword_correct && $imm_correct}sub is_older_query {my$query=shift // croak;my ($keyword,$imm)=split /\s/,$query,2;return 0 if any {not defined}($keyword,$imm);my$keyword_correct=$keyword =~ /^(older|before)$/;my$imm_correct=is_immediate($imm);return$keyword_correct && $imm_correct}sub is_all_query {my$query=shift // croak;return$query eq 'all'}sub is_newest_time {my$query=shift // croak;return$query eq 'newest'}sub is_oldest_time {my$query=shift // croak;return$query eq 'oldest'}sub is_between_query {my$query=shift // croak;my ($keyword,$imm1,$imm2)=split /\s/,$query,3;return 0 if any {not defined}($keyword,$imm1,$imm2);my$keyword_correct=$keyword =~ /^bet(ween)?$/;my$imm1_correct=is_immediate($imm1);my$imm2_correct=is_immediate($imm2);return$keyword_correct && $imm1_correct && $imm2_correct}sub all_subvols {my$config_ref=shift // croak;my@subvols=sort keys %{$config_ref->{subvols}};return wantarray ? @subvols : \@subvols}sub all_backups {my$config_ref=shift // croak;my@backups=sort keys %{$config_ref->{backups}};return wantarray ? @backups : \@backups}sub all_backups_of_subvol {my$config_ref=shift // croak;my$subvol=shift // croak;my@backups=();for my$backup (all_backups($config_ref)){my$backup_subvol=$config_ref->{backups}{$backup}{subvol};push@backups,$backup if$subvol eq $backup_subvol}return wantarray ? @backups : \@backups}sub is_subvol {my$config_ref=shift // croak;my$subvol=shift // croak;return any {$_ eq $subvol}all_subvols($config_ref)}sub is_backup {my$config_ref=shift // croak;my$backup=shift // croak;return any {$_ eq $backup}all_backups($config_ref)}sub is_local_backup {my$config_ref=shift // croak;my$backup=shift // croak;if (is_backup($config_ref,$backup)){return$config_ref->{backups}{$backup}{remote}eq 'no'}else {return 0}}sub is_remote_backup {my$config_ref=shift // croak;my$backup=shift // croak;if (is_backup($config_ref,$backup)){return$config_ref->{backups}{$backup}{remote}eq 'yes'}else {return 0}}sub update_etc_crontab {my$config_ref=shift // croak;open (my$etc_crontab_fh,'<','/etc/crontab')or die "[!] Error: failed to open file '/etc/crontab'\n";open (my$tmp_fh,'>','/tmp/yabsm-update-tmp')or die "[!] Error: failed to open tmp file '/tmp/yabsm-update-tmp'\n";while (<$etc_crontab_fh>){s/\s+$//;next if /yabsm/;say$tmp_fh $_}my@cron_strings=generate_cron_strings($config_ref);say$tmp_fh $_ for@cron_strings;close$etc_crontab_fh;close$tmp_fh;move '/tmp/yabsm-update-tmp','/etc/crontab';return}sub generate_cron_strings {my$config_ref=shift // croak;my@cron_strings;for my$subvol (all_subvols($config_ref)){my$_5minute_want=$config_ref->{subvols}{$subvol}{_5minute_want};my$hourly_want=$config_ref->{subvols}{$subvol}{hourly_want};my$midnight_want=$config_ref->{subvols}{$subvol}{midnight_want};my$monthly_want=$config_ref->{subvols}{$subvol}{monthly_want};my$_5minute_cron=('*/5 * * * * root' ." yabsm --take-snap $subvol 5minute")if$_5minute_want eq 'yes';my$hourly_cron=('0 */1 * * * root' ." yabsm --take-snap $subvol hourly")if$hourly_want eq 'yes';my$midnight_cron=('59 23 * * * root' ." yabsm --take-snap $subvol midnight")if$midnight_want eq 'yes';my$monthly_cron=('0 0 1 * * root' ." yabsm --take-snap $subvol monthly")if$monthly_want eq 'yes';push@cron_strings,grep {defined}($_5minute_cron,$hourly_cron,$midnight_cron,$monthly_cron)}for my$backup (all_backups($config_ref)){my$timeframe=$config_ref->{backups}{$backup}{timeframe};if ($timeframe eq 'hourly'){push@cron_strings,"0 */1 * * * root yabsm --do-backup $backup"}elsif ($timeframe eq 'midnight'){push@cron_strings,"59 23 * * * root yabsm --do-backup $backup"}elsif ($timeframe eq 'monthly'){push@cron_strings,"0 0 1 * * root yabsm --do-backup $backup"}}return wantarray ? @cron_strings : \@cron_strings}sub new_ssh_connection {my$remote_host=shift // croak;my$ssh=Net::OpenSSH->new($remote_host,,batch_mode=>1 ,timeout=>15 ,kill_ssh_on_timeout=>1);$ssh->error and die "[!] Error: Couldn't establish SSH connection: " .$ssh->error ."\n";return$ssh}sub do_backup_bootstrap_ssh {my$config_ref=shift // croak;my$backup=shift // croak;my$remote_host=$config_ref->{backups}{$backup}{host};my$ssh=new_ssh_connection($remote_host);my$subvol=$config_ref->{backups}{$backup}{subvol};my$bootstrap_snap_dir=bootstrap_snap_dir($config_ref,$backup);system("btrfs subvol delete $_")for glob "$bootstrap_snap_dir/*";my$mountpoint=$config_ref->{subvols}{$subvol}{mountpoint};my$bootstrap_snap="$bootstrap_snap_dir/" .current_time_snapstring();system("btrfs subvol snapshot -r $mountpoint $bootstrap_snap");my$remote_backup_dir=$config_ref->{backups}{$backup}{backup_dir};$ssh->system("if [ ! -d \"$remote_backup_dir\" ];" ."then mkdir -p $remote_backup_dir; fi");$ssh->system({stdin_file=>['-|',"btrfs send $bootstrap_snap"]},"sudo -n btrfs receive $remote_backup_dir")}sub do_backup_ssh {my$config_ref=shift // croak;my$backup=shift // croak;my$subvol=$config_ref->{backups}{$backup}{subvol};my$remote_backup_dir=$config_ref->{backups}{$backup}{backup_dir};my$bootstrap_snap=[glob (bootstrap_snap_dir($config_ref,$backup).'/*')]->[0];my$has_already_bootstrapped=is_snapstring($bootstrap_snap);if (not $has_already_bootstrapped){do_backup_bootstrap_ssh($config_ref,)}else {my$remote_host=$config_ref->{backups}{$backup}{host};my$ssh=new_ssh_connection($remote_host);my$tmp_snap=local_snap_dir($config_ref).'/.tmp/' .current_time_snapstring();my$mountpoint=$config_ref->{subvols}{$subvol}{mountpoint};system("btrfs subvol snapshot -r $mountpoint $tmp_snap");$ssh->system({stdin_file=>['-|',"btrfs send -p $bootstrap_snap $tmp_snap"]},"sudo -n btrfs receive $remote_backup_dir");system("btrfs subvol delete $tmp_snap");delete_old_backups_ssh($config_ref,$ssh,$backup)}return}sub delete_old_backups_ssh {my$config_ref=shift // croak;my$ssh=shift // croak;my$backup=shift // croak;my$subvol=$config_ref->{backups}{$backup}{subvol};my$remote_backup_dir=$config_ref->{backups}{$backup}{backup_dir};my@existing_backups=sort_snaps([$ssh->capture("ls -d $remote_backup_dir/*")]);my$num_backups=scalar@existing_backups;my$num_to_keep=$config_ref->{backups}{$backup}{keep};if ($num_backups==$num_to_keep + 1){my$oldest_backup=pop@existing_backups;$ssh->system("sudo -n btrfs subvol delete $oldest_backup");return}elsif ($num_backups <= $num_to_keep){return}else {while ($num_backups > $num_to_keep){my$oldest_backup=pop@existing_backups;$ssh->system("sudo -n btrfs subvolume delete $oldest_backup");$num_backups--}return}}sub take_new_snapshot {my$config_ref=shift // croak;my$subvol=shift // croak;my$timeframe=shift // croak;my$mountpoint=$config_ref->{subvols}{$subvol}{mountpoint};my$snap_dir=local_snap_dir($config_ref,$subvol,$timeframe);my$snapshot_name=current_time_snapstring();system('btrfs subvol snapshot -r ' .$mountpoint ." $snap_dir/$snapshot_name");return 1}sub delete_old_snapshots {my$config_ref=shift // croak;my$subvol=shift // croak;my$timeframe=shift // croak;my$existing_snaps_ref=all_snapshots_of($config_ref,$subvol,$timeframe);my$num_snaps=scalar @$existing_snaps_ref;my$num_to_keep=$config_ref->{subvols}{$subvol}{"${timeframe}_keep"};if ($num_snaps==$num_to_keep + 1){my$oldest_snap=pop @$existing_snaps_ref;system("btrfs subvolume delete $oldest_snap");return}elsif ($num_snaps <= $num_to_keep){return}else {while ($num_snaps > $num_to_keep){my$oldest_snap=pop @$existing_snaps_ref;system("btrfs subvolume delete $oldest_snap");$num_snaps--}return}}1;
YABSM_BASE

$fatpacked{"Yabsm/Config.pm"} = '#line '.(1+__LINE__).' "'.__FILE__."\"\n".<<'YABSM_CONFIG';
  package Yabsm::Config;use strict;use warnings;use 5.010;use List::Util 'any';use FindBin '$Bin';use lib "$Bin/..";use Yabsm::Base;sub read_config {my$file=shift // '/etc/yabsmrc';open(my$fh,'<',$file)or die "[!] Error: failed to open file '$file'\n";my%config;while (<$fh>){next if /^\s*$/;next if /^\s*#/;s/#.*//;s/\s+$//;if (/^define_subvol\s+(\S+)\s+{$/){my$subvol=$1;if (not $subvol =~ /^[a-zA-Z]/){die "[!] Parse Error (line $.): invalid subvol name '$subvol' does not start with alphabetic character\n"}else {$config{subvols}{$subvol}=undef}while (1){$_=<$fh>;if (not defined $_){die "[!] Parse Error: reached end of file\n"}next if /^\s*$/;next if /^\s*#/;s/#.*//;s/\s+//g;last if /^}$/;my ($key,$val)=split /=/,$_,2;if (not defined$key || not defined$val){die "[!] Parse Error (line $.): cannot parse '$_'\n"}$key =~ s/5minute/_5minute/;$config{subvols}{$subvol}{$key}=$val}}elsif (/^define_backup\s+(\S+)\s+{$/){my$backup=$1;if (not $backup =~ /^[a-zA-Z]/){die "[!] Parse Error (line $.): invalid backup name '$backup' does not start with alphabetic character\n"}else {$config{backups}{$backup}=undef}while (1){$_=<$fh>;if (not defined $_){die "[!] Parse Error: reached end of file\n"}next if /^\s*$/;next if /^\s*#/;s/#.*//;s/\s+//g;last if /^}$/;my ($key,$val)=split /=/,$_,2;if (not defined$key || not defined$val){die "[!] Parse Error (line $.): cannot parse '$_'\n"}$config{backups}{$backup}{$key}=$val}}else {s/#.*//g;s/\s+//g;my ($key,$val)=split /=/,$_,2;if (not defined$key || not defined$val){die "[!] Parse Error (line $.): cannot parse '$_'\n"}$config{misc}{$key}=$val}}close$fh;my@errors=check_config(\%config);if (@errors){my$errors=join "\n",@errors;die "$errors\n"}return wantarray ? %config : \%config}sub check_config {my ($config_ref)=@_;my@errors;for my$subvol (Yabsm::Base::all_subvols($config_ref)){my@required_settings=qw(mountpoint _5minute_want _5minute_keep hourly_want hourly_keep midnight_want midnight_keep monthly_want monthly_keep);while (my ($key,$val)=each %{$config_ref->{subvols}{$subvol}}){if ($key eq 'mountpoint'){@required_settings=grep {$_ ne $key}@required_settings;if (not -d $val){push@errors,"[!] Config Error: subvol '$subvol': no such directory '$val'"}}elsif ($key =~ /^(_5minute|hourly|midnight|monthly)_want$/){@required_settings=grep {$_ ne $key}@required_settings;if (not ($val eq 'yes' || $val eq 'no')){push@errors,"[!] Config Error: subvol '$subvol': value for '$key' does not equal yes or no"}}elsif ($key =~ /^(_5minute|hourly|midnight|monthly)_keep$/){@required_settings=grep {$_ ne $key}@required_settings;if (not $val =~ /^\d+$/){push@errors,"[!] Config Error: subvol '$subvol': value for '$key' is not an integer greater or equal to 0"}}else {push@errors,"[!] Config Error: subvol '$subvol': '$key' is not a valid subvol setting"}}if (@required_settings){for (@required_settings){push@errors,"[!] Config Error: subvol '$subvol': missing required setting '$_'"}}}for my$backup (Yabsm::Base::all_backups($config_ref)){my@required_settings=qw(subvol remote keep backup_dir timeframe);while (my ($key,$val)=each %{$config_ref->{backups}{$backup}}){if ($key eq 'subvol'){if (not Yabsm::Base::is_subvol($config_ref,$val)){push@errors,"[!] Config Error: backup '$backup': no defined subvol '$val'"}@required_settings=grep {$_ ne $key}@required_settings}elsif ($key eq 'backup_dir'){@required_settings=grep {$_ ne $key}@required_settings}elsif ($key eq 'keep'){if (not ($val =~ /^\d+$/ && $val >= 1)){push@errors,"[!] Config Error: backup '$backup': value for '$key' is not a positive integer"}@required_settings=grep {$_ ne $key}@required_settings}elsif ($key eq 'timeframe'){if (not any {$val eq $_}qw(hourly midnight monthly)){push@errors,"[!] Config Error: backup '$backup': value for '$key' is not one of (hourly, midnight, monthly)"}@required_settings=grep {$_ ne $key}@required_settings}elsif ($key eq 'remote'){@required_settings=grep {$_ ne $key}@required_settings;if ($val eq 'yes'){if (not exists$config_ref->{backups}{$backup}{host}){push@errors,"[!] Config Error: backup '$backup': remote backups require 'host' setting"}}elsif ($val eq 'no'){if (exists$config_ref->{backups}{$backup}{host}){push@errors,"[!] Config Error: backup '$backup': 'host' is not a valid setting for a non-remote backup"}}else {push@errors,"[!] Config Error: backup '$backup': value for '$key' does not equal yes or no"}}else {if (not ($key eq 'host')){push@errors,"[!] Config Error: backup '$backup': '$key' is not a valid backup setting"}}}if (@required_settings){for (@required_settings){push@errors,"[!] Config Error: backup '$backup': missing required setting '$_'"}}}my@required_misc_settings=qw(yabsm_snapshot_dir);while (my ($key,$val)=each %{$config_ref->{misc}}){if ($key eq 'yabsm_snapshot_dir'){@required_misc_settings=grep {$_ ne $key}@required_misc_settings}else {push@errors,"[!] Config Error: '$key' is not a valid setting"}}if (@required_misc_settings){for (@required_misc_settings){push@errors,"[!] Config Error: missing required misc setting '$_'"}}return wantarray ? @errors : \@errors}1;
YABSM_CONFIG

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
Usage: yabsm [OPTION] [arg...]

  --find, -f <?SUBVOL> <?QUERY>           find a snapshot of SUBVOL using QUERY

  --update-crontab, -u                    update cronjobs in /etc/crontab, based
                                          off settings specified in /etc/yabsmrc

  --check-config, -c                      check /etc/yabsmrc for errors. If
                                          errors are present print their info
                                          to stdout. Exit with code 0 in either
                                          case.

  --help, -h                              print help (this message) and exit

  Please see 'man yabsm' for detailed information about yabsm.
END_USAGE
}

use FindBin '$Bin';
use lib "$Bin/lib";

use Yabsm::Base;
use Yabsm::Config;

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);

use Data::Dumper;

my @TAKE_SNAPSHOT;
my $UPDATE_CRONTAB;
my $DO_BACKUP;
my $CONFIRM;
my $BACKUP_BOOTSTRAP;
my $PRINT_CRONSTRINGS;
my @FIND;
my @CHECK_CONFIG;
my $HELP;

GetOptions( 'take-snap|s=s{2}'        => \@TAKE_SNAPSHOT
	  , 'find|f=s{0,2}'           => \@FIND
	  , 'update-crontab|u'        => \$UPDATE_CRONTAB
	  , 'check-config|c=s{0,1}'   => \@CHECK_CONFIG
	  , 'do-backup|b=s'           => \$DO_BACKUP
	  , 'yes-i-want-to-do-this|Y' => \$CONFIRM
	  , 'bootstrap-backup|k=s'    => \$BACKUP_BOOTSTRAP
	  , 'crons|C'                 => \$PRINT_CRONSTRINGS
	  , 'help|h'                  => \$HELP
	  );

if ($HELP) {
    usage();
    exit 0;
}

if (@CHECK_CONFIG) {

    my $config_path = pop @CHECK_CONFIG || '/etc/yabsmrc';

    Yabsm::Config::read_config($config_path);

    say 'all good';

    exit 0;
}

my $CONFIG_REF = Yabsm::Config::read_config('/etc/yabsmrc');
Yabsm::Base::initialize_directories($CONFIG_REF);

if ($UPDATE_CRONTAB) {

    die "[!] Permission Error: must be root to update /etc/crontab\n" if $<;

    Yabsm::Base::update_etc_crontab($CONFIG_REF);

    exit 0;
}

if (@TAKE_SNAPSHOT) {

    die "[!] Permission Error: must be root to take a new snapshot\n" if $<;

    # --take-snap option takes two string args. We can be sure
    # that both args are defined as Getopt::Long will kill the program
    # if they are not.

    my ($subvol, $timeframe) = @TAKE_SNAPSHOT;

    if (not Yabsm::Base::is_subvol($CONFIG_REF, $subvol)) {
	die "[!] Error: no such defined subvol '$subvol'\n"
    }

    if ($CONFIG_REF->{subvols}{$subvol}{"${timeframe}_want"} eq 'no') {
	die "[!] Error: subvol '$subvol' is not taking '$timeframe' snapshots\n";
    }

    Yabsm::Base::take_new_snapshot($CONFIG_REF, $subvol, $timeframe);
    Yabsm::Base::delete_old_snapshots($CONFIG_REF, $subvol, $timeframe);

    exit 0;
}

if (@FIND) {

    # these variables may or may not be defined.
    my ($arg1, $arg2) = @FIND;

    # the following logic exists to set the $subject and $query variables.
    my ($subject, $query);

    if ($arg1) {
	if (Yabsm::Base::is_subvol($CONFIG_REF, $arg1) ||
	    Yabsm::Base::is_backup($CONFIG_REF, $arg1)) {
	    $subject = $arg1;
	}
	elsif (Yabsm::Base::is_valid_query($arg1)) {
	    $query = $arg1;
	}
	else {
	    die "[!] Error: '$arg1' is neither a subvolume or query\n";
	}
    }
    
    if ($arg2) {
	if (Yabsm::Base::is_subvol($CONFIG_REF, $arg2) || 
            Yabsm::Base::is_backup($CONFIG_REF, $arg2)) {
	    $subject = $arg2;
	}
	elsif (Yabsm::Base::is_valid_query($arg2)) {
	    $query = $arg2;
	}
	else {
	    die "[!] Error: '$arg2' is neither a subvolume or query\n";
	}
    }

    if (not defined $subject) {
	$subject = Yabsm::Base::ask_user_for_subvol_or_backup($CONFIG_REF);
    }

    if (not defined $query) {
	$query = Yabsm::Base::ask_user_for_query();
    }

    # $subvol and $query are properly set at this point
    my @snaps = Yabsm::Base::answer_query($CONFIG_REF, $subject, $query);

    say for @snaps;

    exit 0;
}

if ($PRINT_CRONSTRINGS) {

    my @cron_strings = Yabsm::Base::generate_cron_strings($CONFIG_REF);

    say for @cron_strings;

    exit 0;
}

if ($BACKUP_BOOTSTRAP) {

    die "[!] Permission Error: must be root to perform backup\n" if $<;

    # option takes backup arg
    my $backup = $BACKUP_BOOTSTRAP;

    if (is_remote_backup($CONFIG_REF, $backup)) {
	do_backup_bootstrap_ssh($CONFIG_REF, $backup);
    }

    elsif (is_local_backup($CONFIG_REF, $backup)) {
	do_backup_bootstrap_local($CONFIG_REF, $backup);
    }

    else { die "[!] Error: no such defined backup '$backup'\n" }

    exit 0;
}

if ($DO_BACKUP) {

    die "[!] Permission Error: must be root to perform backup\n" if $<;

    my $backup = $DO_BACKUP;

    if (Yabsm::Base::is_remote_backup($CONFIG_REF, $backup)) {
	do_backup_ssh($CONFIG_REF, $backup);
    }
    elsif (Yabsm::Base::is_local_backup($CONFIG_REF, $backup)) {
	do_backup_local($CONFIG_REF, $backup);
    }

    else { die "[!] Error: no such defined backup '$backup'\n" }

    exit 0;
}

# no options were passed
usage();
exit 1;
