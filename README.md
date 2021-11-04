# -*- mode:org;mode:auto-fill;fill-column:79 -*-
#+title: YABSM (yet another btrfs snapshot manager)
#+author: Nicholas Hubbard
* Contents
  + [[#Features][Features]]
  + [[#Installation][Installation]]
  + [[#Commands][Commands]]
  + [[#Configuration][Configuration]]
  + [[#Finding-Snapshots][Finding Snapshots]]

# Features
* Features
  + Organize snapshots into 5minute, hourly, midnight, weekly and monthly
    timeframe categories.
  + Cycle out old snapshots on a per-timeframe basis.
  + Remote and local incremental backups.
  + Query snapshots and backups to quickly jump back to a previous machine state.

# Installation
* Installation
  #+BEGIN_SRC  
  $ git clone https://github.com/NicholasBHubbard/yabsm
  # yabsm/install
  #+END_SRC  
* Dependencies
  + [[https://github.com/kdave/btrfs-progs][btrfs-progs]]
  + [[https://www.openssh.com/][OpenSSH]]
  + [[https://www.perl.org/][Perl (>= version 5.16.3)]]
It is unlikely that you do not already have these installed.

# Commands
* Commands
  Yabsm comes with commands that can be used like =yabsm <command> <arg(s)>=.
**** find, f SUBJECT QUERY
     Find one or more snapshots of SUBJECT that matches QUERY. SUBJECT can be
     any =subvol= or =backup= defined in =/etc/yabsm.conf=. For more
     information on queries see the section below titled =Finding Snapshots=.
**** update-crontabe, update
     Write the cronjobs to =/etc/crontab= that are generated by reading
     =/etc/yabsm.conf/=. This command should be used after configuration
     updates. Must be root user.
**** check-config, c ?CONFIG
     Check that ?CONFIG is a valid yabsm configuration file. If the ?CONFIG
     argument is omitted then =/etc/yabsm.conf= if checked. If any errors are
     found they are printed to STDERR and the program exits with non-zero
     status. If the configuration is valid print 'all good'.
**** test-remote-config, tr BACKUP
     Test that the remote backup BACKUP has been properly configured. If BACKUP
     is misconfigured print the errors to STDERR and exit with non-zero status.
     errors to STDERR. If BACKUP is configured properly print 'all good'. For
     more information on proper remote backup configuration see the section
     below titled =Remote Backup Configuration=.
**** print-subvols, subvols
     Print the names of all the subvols defined in =/etc/yabsm.conf=.
**** print-backups, backups
     Print the names of all the backups defined in =/etc/yabsm.conf=.
**** bootstrap-backups, bootstrap BACKUP
     Perform the bootstrap phase of a btrfs incremental backup for
     BACKUP. It may be useful to run this command every so often in order to
     speed up incremental backups.
**** take-snap, snap SUBVOL TIMEFRAME
     Warning: This command should only be used manually for debugging.

     Take a single read-only snapshot of SUBVOL and put it in it's TIMEFRAME
     directory. Delete old snapshot(s) that should be cycled out based off the
     users config.
**** incremental-backup, backup BACKUP
     Warning: This command should only be used manually for debugging.

     Perform a single incremental backup of BACKUP. Delete old backup(s) that
     should be cycled out based off the users config.

# Configuration
* Configuration
  Yabsm is configured through the =/etc/yabsm.conf= file. By default yabsm only
  installs the =/etc/yabsm.conf.example= file so you may want to run 
  =cp /etc/yabsm.conf.example /etc/yabsm.conf= and then create your config
  based off the example.
  
  Effort has been put in to ensure that erroneous configs are rejected with
  meaningful error messages. To check that your config is valid run 
  =yabsm check-config=.

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

        midnight_want=no

        weekly_want=yes
        weekly_day=wednesday
        weekly_keep=12

        monthly_want=no
    }

    backup homeBackup {
        subvol=home

        remote=yes

        host=alice@192.168.1.73

        backup_dir=/backups/yabsm/desktopHomeBackup

        timeframe=midnight

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
The subvols =name= must match the regex: =^[a-zA-Z][-_a-zA-Z0-9]*$=

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
     How many snapshots in the =5minute= timeframe do you want to keep? The
     value must be a positive integer. This setting is only required if
     =5minute_want=yes=.
**** hourly_want
     Do you want to take a snapshot at the beginning of every hour? The value
     must be either =yes= or =no=. This setting is always required.
**** hourly_keep
     How many snapshots in the =hourly= timeframe do you want to keep? The
     value must be a positive integer. This setting is only required if
     =hourly_want=yes=.
**** midnight_want
     Do you want to take a snapshot every night at 23:59? The value
     must be either =yes= or =no=. This setting is always required.
**** midnight_keep
     How many snapshots in the =midnight= timeframe do you want to keep? The
     value must be a positive integer. This setting is only required if
     =midnight_want=yes=.
**** weekly_want
     Do you want to take a snapshot at 23:59 on one day of the week? The value
     must be either =yes= or =no=. This setting is always required.
**** weekly_day
     Which day of the week do you want the =weekly= snapshot? The value be any
     of sunday, monday, tuesday, wednesday, thursday, friday, or saturday. This
     setting is only required if =weekly_want=yes=.
**** weekly_keep
     How many snapshots in the =weekly= timeframe do you want to keep? The
     value must be a positive integer. This setting is only required if
     =weekly_want=yes=.
**** monthly_want
     Do you want to take a snapshot at 00:00 on the first of every month? The
     value must be either =yes= or =no=. This setting is always required.
**** monthly_keep
     How many snapshots in the =monthly= timeframe do you want to keep? The
     value must be a positive integer. This setting is only required if
     =monthly_want=yes=.


*** Backup Definitions
A yabsm backup has the following form
#+BEGIN_SRC
backup name {
    setting=value
    ...
}
#+END_SRC
The backups =name= must match the regex: =^[a-zA-Z][-_a-zA-Z0-9]*$=

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
     hostname that works with =ssh=. This setting is only required if
     =remote=yes=.
**** backup_dir     
     The directory to place the backup snapshots. The value is taken literally
     so you probably want =/yabsm/= somewhere in the path. If the backup is a
     local backup then this directory will be created automatically. If the
     backup is a remote backup then this directory must already exist on the
     remote machine. This setting is always required.
**** keep
     The number of backups to keep around. The value must be a positive
     integer. This setting is always required.
**** timeframe
     The timeframe for performing backups. This value can be any of 5minute,
     hourly, midnight, weekly, or monthly. These timeframes are the same as a
     subvols timeframes. This setting is always required.
**** weekly_day
     The day of the week to perform the backup? The value can be any of sunday,
     monday, tuesday, wednesday, thursday, frieday, or saturday. This setting
     is only required if =timeframe=weekly=.

# Finding-Snapshots
* Finding Snapshots
  
Yabsm comes with a simple query language for locating snapshots and backups. To
query snapshots and backups use the =find= command that lets you ask questions
like: "find a snapshot of my home subvol from 2 hours ago", or "find all the
snapshots taken after 2 days ago".

When a snapshot is found it's path is printed to stdout. If multiple snapshots
are found they are printed linewise sorted from newest to oldest.

*** Examples
    Assume that you have a =subvol= named "home".

    + yabsm find home back-20-minutes
    + yabsm find home back-10-hours
    + yabsm find home back-2-days
    + yabsm find home 'between back-2-hours 12-25'
    + yabsm find home 2020-12-25-17-5
    + yabsm find home 12-25
    + yabsm find home newest
    + yabsm find home oldest
    + yabsm find home 'after b-2-d'
    + yabsm find home 'before b-10-h'

There are 7 different kinds of queries: =relative time=, =literal time=,
=newest=, =oldest=, =before=, =after=, =between=.

**** Relative Time
     A =relative time= is a time relative to the current time.

     A =relative time= query matches the one snapshot closest to the time denoted
     by the =relative time=.

     A =relative time= has the form =back-amount-unit=.

     =back= can always be abbreviated to =b=.

     =amount= can be any non-negative integer.

     =unit= can be one of =minutes=, =hours=, =days=.

     =minutes= can be abbreviated to =mins= or =m=.

     =hours= can be abbreviated to =hrs= or =h=.

     =days= can be abbreviated to =d=.

**** Literal Time
     A =literal time= is a denotes a date of the form =YEAR=MONTH-DAY-HOUR-MINUTE=.

     A =literal time= query matches the one snapshot closest to the time denoted
     by the =literal time=.

     A =literal time= comes in one of 5 forms:

     + yr-mon-day-hr-min
     + yr-mon-day
     + mon-day
     + mon-day-hr
     + mon-day-hr-min
       
     The first form =yr-mon-day-hr-min= is the base form that all other forms
     are shorthand for.

     The shorthand rules are simple, if the =yr= field is omitted then the
     current year is assumed. If either the =hr= or =min= field are omitted
     then they are assumed to be zero. Therefore if the current year is 2020
     then the literal time =12-25= is equivalent to =2020-12-25-0-0=

     

     
