# -*- mode:org;mode:auto-fill;fill-column:79 -*-
#+title: YABSM (yet another btrfs snapshot manager)
#+author: Nicholas Hubbard
* Contents
  + [[#Features][Features]]
  + [[#Dependencies][Dependencies]]
  + [[#Installation][Installation]]
  + [[#Post-Installation][Post Installation]]
  + [[#Configuration][Configuration]]
  + [[#Commands][Commands]]
  + [[#Finding-Snapshots][Finding Snapshots]]
  + [[#Remote-Backups][Remote Backups]]

# Features
* Features
  + Organize snapshots into 5minute, hourly, daily, weekly and monthly
    timeframe categories.
  + Cycle out old snapshots on a per-timeframe basis.
  + Remote and local incremental backups.
  + Cycle out old backups
  + Query language for locating snapshots and backups

# Dependencies
* Dependencies
  + [[https://github.com/kdave/btrfs-progs][btrfs-progs]]
  + [[https://www.openssh.com/][OpenSSH]]
  + [[https://www.perl.org/][Perl (>= version 5.16.3)]]
It is unlikely that you do not already have these installed.

# Installation
* Installation
  #+BEGIN_SRC  
  $ git clone https://github.com/NicholasBHubbard/yabsm
  # yabsm/install
  #+END_SRC  

# Post-Installation
* Post Installation
By default yabsm only installs the =/etc/yabsm.conf.example= example
configuration file. You will probably want to copy this file to
=/etc/yabsm.conf= and then build your custom config based off the
example.

After you are finished creating your config you will need to write the proper
yabsm cronjobs to your =/etc/crontab= file.
#+BEGIN_SRC
# yabsm update-crontab
#+END_SRC

For more information on how to create a configuration see the section below.

# Configuration
* Configuration
  Yabsm is configured through the =/etc/yabsm.conf= file.

  Effort has been put in to ensure that erroneous configs are rejected with
  meaningful error messages. To check that your config is valid run
  =yabsm check-config=.

  The fundamental building blocks of a configuration are =subvols= and
  =backups=.

  A =subvol= relates to a btrfs subvolume through its =mountpoint=
  setting which is the directory that will be snapshotted by yabsm. A =subvols=
  snapshotting is controlled through its =TIMEFRAME_want= settings. For each
  =TIMEFRAME_want=yes= setting a directory =YABSM_DIR/SUBVOL_NAME/TIMEFRAME=
  directory will be created where the corresponding snapshots will be placed.

  A =backup= performs incremental backups of a yabsm =subvol= to either a
  remote or local btrfs filesystem. The backup snapshots are placed in the
  directory specified by the =backup_dir= setting.

*** Example Config
#+BEGIN_SRC 
    # /etc/yabsm.conf

    yabsm_dir=/.snapshots/yabsm

    subvol home {
        mountpoint=/home

        5minute_want=yes
        5minute_keep=24

        hourly_want=yes
        hourly_keep=24

        daily_want=yes
        daily_time=23:59
        daily_keep=30

        weekly_want=yes
        weekly_day=wednesday
        weekly_time=00:00
        weekly_keep=12

        monthly_want=no
    }

    backup homeBackup {
        subvol=home

        remote=yes

        host=alice@192.168.1.73

        backup_dir=/backups/yabsm/desktopHomeBackup

        timeframe=daily

        time=23:59

        keep=365
    }
#+END_SRC 
  
*** yabsm_dir
The directory for yabsm to store snapshots and use as a working directory for
incremental backups. This directory is taken literally so you probably want it
to end in =/yabsm=. It only makes sense for this directory to be a btrfs
subvolume. If the directory does not exist then yabsm will create it
automatically.

*** Subvol Definitions
A yabsm subvol has the following form
#+BEGIN_SRC
subvol name {
    setting=value
    ...
}
#+END_SRC
The subvol =name= must match the regex: =^[a-zA-Z][-_a-zA-Z0-9]*$=

For every subvols =TIMEFRAME_want=yes= setting a new directory
=/YABSM_DIR/subvol_name/TIMEFRAME= will be created where snapshots for this
subvol will be placed. These snapshots are taken using the =btrfs subvolume
snapshot -r= command.

You can define as many subvols as you want.

*** Subvol Settings

**** mountpoint
     The =mountpoint= setting is the interface between a yabsm =subvol= and
     the corresponding btrfs subvolume. The value is the directory that will
     be snapshotted by yabsm. This setting is always required.
**** 5minute_want
     Do you want to take a snapshot of this subvol every 5 minutes? The value
     must be either =yes= or =no=. This setting is always required.
**** 5minute_keep
     The number of snapshots to keep for the =5minute= timeframe. The value
     must be a positive integer. This setting is only required if
     =5minute_want=yes=.
**** hourly_want
     Do you want to take a snapshot at the beginning of every hour? The value
     must be either =yes= or =no=. This setting is always required.
**** hourly_keep
     The number of snapshots to keep for the =hourly= timeframe. The value must
     be a positive integer. This setting is only required if =hourly_want=yes=.
**** daily_want
     Do you want to take a snapshot every day at a specified time? The value
     must be either =yes= or =no=. This setting is always required.
**** daily_time
     The time of day to take the =daily= snapshot. This value is a 24 hour time
     in the form =hh:mm=. A leading zero is required for single digit
     values. This setting is only required if =daily_want=yes=.
**** daily_keep
     The number of snapshots to keep for the =daily= timeframe. The value
     must be a positive integer. This setting is only required if
     =daily_want=yes=.
**** weekly_want
     Do you want to take a snapshot at 23:59 on one day of the week? The value
     must be either =yes= or =no=. This setting is always required.
**** weekly_day
     The name of the day of the week to take the =weekly= snapshot. The value
     be any of sunday, monday, tuesday, wednesday, thursday, friday, or
     saturday. This setting is only required if =weekly_want=yes=.
**** weekly_time
     The time of day to take the =weekly= snapshot. This value is a 24 hour
     time in the form =hh:mm=. A leading zero is required for single digit
     values. This setting is only required if =weekly_want=yes=.
**** weekly_keep
     The number of snapshots to keep for the =weekly= timeframe. The value must
     be a positive integer. This setting is only required if =weekly_want=yes=.
**** monthly_want
     Do you want to take a snapshot at 00:00 on the first of every month? The
     value must be either =yes= or =no=. This setting is always required.
**** monthly_time
     The time of day to take the =monthly= snapshot. This value is a 24 hour
     time in the form =hh:mm=. A leading zero is required for single digit
     values. This setting is only required if =monthly_want=yes=.
**** monthly_keep
     The number of snapshots to keep for the =monthly= timeframe. The value
     must be a positive integer. This setting is only required if
     =monthly_want=yes=.

*** Backup Definitions
A yabsm backup has the following form
#+BEGIN_SRC
backup name {
    setting=value
    ...
}
#+END_SRC
The backup =name= must match the regex: =^[a-zA-Z][-_a-zA-Z0-9]*$=

You can define as many backups as you want.

*** Backup Settings
**** subvol
     The name of the yabsm subvol that is being backed up. This setting is
     always required.
**** remote
     Is this backup a remote backup (to a server over ssh)? The value for this
     setting must be either =yes= or =no=. If =remote=no= then the backup must
     be a local backup (hard drive plugged into the computer). This setting is
     always required.
**** host
     The hostname of a server for a remote backup. The value can be any
     hostname that works with =ssh=. Note that the =ssh= connection will be
     established as the root user. This setting is only required if
     =remote=yes=.
**** backup_dir
     The directory to place the backup snapshots. The value is taken literally
     so you probably want =/yabsm/= somewhere in the path. If the backup is a
     local backup then this directory will be created automatically. If the
     backup is a remote backup then this directory must already exist on the
     remote machine. It only makes sense for this directory to be on a btrfs
     filesystem. This setting is always required.
**** keep
     The number of backups to keep around. The value must be a positive
     integer. This setting is always required.
**** timeframe
     The timeframe for performing backups. This value can be any of 5minute,
     hourly, daily, weekly, or monthly. These timeframes are the same as a
     subvols timeframes. This setting is always required.
**** time
     The time of day to perform the backup if the timeframe is one of =daily=,
     =weekly=, or =monthly=. This value is a 24 hour time in the form
     =hh:mm=. A leading zero is required for single digit values.
**** day
     The day of the week to perform the backup if the =timeframe=weekly=. The
     value can be any of sunday, monday, tuesday, wednesday, thursday, friday,
     or saturday.

# Commands
* Commands
  Yabsm's functionality is implemented in the following commands.
**** find, f SUBJECT QUERY
     Find one or more snapshots of SUBJECT that matches QUERY. SUBJECT can be
     any =subvol= or =backup= defined in =/etc/yabsm.conf=. For more
     information on queries see the section titled [[#Finding-Snapshots][Finding Snapshots]].
**** update-crontab, update
     Write the cronjobs to =/etc/crontab= that are generated by reading
     =/etc/yabsm.conf=. This command should be used after configuration
     updates. Must be root user.
**** check-config, c ?CONFIG
     Check that ?CONFIG is a valid yabsm configuration file. If the ?CONFIG
     argument is omitted then =/etc/yabsm.conf= is checked. If any errors are
     found they are printed to STDERR and the program exits with non-zero
     status. If the configuration is valid print 'all good'.
**** test-remote-config, tr BACKUP
     Test that the remote backup BACKUP has been properly configured. If BACKUP
     is misconfigured print the errors to STDERR and exit with non-zero status.
     errors to STDERR. If BACKUP is configured properly print 'all good'. For
     more information on proper remote backup configuration see the section
     titled [[#Remote-Backups][Remote Backups]].
**** bootstrap-backup, bootstrap BACKUP
     Perform the bootstrap phase of a btrfs incremental backup for
     BACKUP. It may be useful to run this command every so often in order to
     speed up incremental backups.
**** print-crons, crons
     Print the cronjob strings that would be written to =/etc/crontab= if the
     =update-crontab= command were used.
**** print-subvols, subvols
     Print the names of all the subvols defined in =/etc/yabsm.conf=.
**** print-backups, backups
     Print the names of all the backups defined in =/etc/yabsm.conf=.
**** take-snap SUBVOL TIMEFRAME
     Warning: This command should only be used manually for debugging purposes.

     Take a single read-only snapshot of SUBVOL and put it in it's TIMEFRAME
     directory. Delete old snapshot(s) that should be cycled out based off the
     users config. Must be root user.
**** incremental-backup BACKUP
     Warning: This command should only be used manually for debugging purposes.

     Perform a single incremental backup of BACKUP. Delete old backup(s) that
     should be cycled out based off the users config. Must be root user.

# Finding-Snapshots
* Finding Snapshots

Yabsm comes with a simple query language for locating snapshots and backups. To
query snapshots and backups use the =find= command that lets you ask questions
like: "find a snapshot of my home subvol from 2 hours ago", or "find all the
snapshots taken after 2 days ago".

I often use =yabsm find= as the argument to =cd= using command substitution to
quickly jump back in time.

When a snapshot is found it's path is printed to stdout. If multiple snapshots
are found they are printed linewise sorted from newest to oldest.

*** Examples
    Assume that you have a =subvol= named "home".

    + yabsm find home back-20-minutes
    + yabsm find home b-10-hours
    + yabsm find home b-2-days
    + yabsm find home 'between back-2-hours 12:25'
    + yabsm find home 2020-12-25-17:20
    + yabsm find home 12-25
    + yabsm find home 10:30
    + yabsm find home 'after b-2-d'
    + yabsm find home 'before b-10-h'
    + yabsm find home newest
    + yabsm find home oldest
    + yabsm find home all

There are 7 different kinds of queries: =relative time=, =literal time=,
=newest=, =oldest=, =before=, =after=, =between=.

**** Relative Time Query
     A =relative time= query matches the one snapshot closest to the time denoted
     by the =relative time= which has the from =back-amount-unit=.

     =back= can always be abbreviated to =b=.

     =amount= can be any non-negative integer.

     =unit= can be one of =minutes=, =hours=, =days=.

     =minutes= can be abbreviated to =mins= or =m=.

     =hours= can be abbreviated to =hrs= or =h=.

     =days= can be abbreviated to =d=.

**** Literal Time Query
     A =literal time= query matches the one snapshot closest to the time denoted
     by the =literal time=.

     There are 7 forms of =literal times=.

     + yr-mon-day-hr:min
     + yr-mon-day
     + mon-day
     + mon-day-hr
     + mon-day-hr:min
     + day-hr:min
     + hr:min
       
     The first form =yr-mon-day-hr:min= is the base form that all the other
     forms are a shorthand for.

     The shorthand rules are simple, if the =yr=, =mon=, or =day= field is
     omitted then the current year, month, or day is assumed.  If either the
     =hr= or =min= field are omitted then they are assumed to be zero. Therefore
     if the date is 2020/12/25 then the literal time =8:30= is equivalent to
     =2020-12-25-8:30=, and the literal time =2020-12-25= is always equivalent
     to =2020-12-25:0:0=.
     
**** Before Query     
     A =before= query takes either a =relative time= or a =literal time= as an
     argument and matches all the snapshots taken before (not inclusive) the
     denoted time.

     =older= is an alias for =before=.

     A =before= query must be quoted when passed via the command line.

**** After Query     
     An =after= query takes either a =relative time= or a =literal time= as an
     argument and matches all the snapshots taken after (not inclusive) the
     denoted time.

     =newer= is an alias for =after=.

     An =after= query must be quoted when passed via the command line.

**** Between Query
     A =between= query takes two =relative= / =literal= times and matches all
     the snapshots taken between (inclusive) the denoted times.

     A =between= query must be quoted when passed via the command line.

**** Newest Query
     A =newest= query is denoted by simply passing the constant string
     "newest". A =newest= query matches the one snapshot that is the newest.

**** Oldest Query
     An =oldest= query is denoted by simply passing the constant string
     "oldest". An =oldest= query matches the one snapshot that is the oldest.

**** All Query
     An =all= query is denoted by simply passing the constant string "all". An
     =all= query matches every snapshot.

# Remote-Backups
* Remote Backups
Yabsm does not deal with passwords directly so you will need to do some
configuration to allow yabsm to log into the remote host and run =btrfs= under
=sudo= without entering any passwords.

To test if the remote backup has been configured correctly you can use the
=test-remote-config= command.

To allow yabsm to connect to a backups remote host without entering a password
you must set up a passwordless ssh key pair.

To allow yabsm to use the =btrfs= command with sudo without entering a password
you must set up a =sudoers= rule. For example you could add this line to your
=/etc/sudoers= file to allow members of the group =btrfsers= to use the =btrfs=
command without a password.
#+BEGIN_SRC 
%btrfsers  ALL=(ALL) NOPASSWD: /path/to/btrfs
#+END_SRC 

Finally the remote backups =backup_dir= must already exist.

* Contributing

See CONTRIBUTING.

* License

MIT
