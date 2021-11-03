# -*- mode:org;mode:auto-fill;fill-column:79 -*-
#+title: YABSM (yet another btrfs snapshot manager)
#+author: Nicholas Hubbard
* Features
  + Organize snapshots into 5minute, hourly, midnight, weekly and monthly
    timeframe categories.
  + Cycle out old snapshots on a per-timeframe basis.
  + Remote and local incremental backups.
  + Query snapshots and backups to quickly jump back to a previous machine state.

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
