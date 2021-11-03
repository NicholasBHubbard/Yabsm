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

    subvol root {
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

    backup rootBackup {
        subvol=root

        remote=yes

        host=alice@192.168.1.73

        backup_dir=/backups/yabsm/desktopRootBackup

        timeframe=midnight

        keep=365
    }
#+END_SRC 
  
*** yabsm_dir
The directory for yabsm to store snapshots and use as a working directory for
incremental backups. This directory is taken literally so you probably want it
to end in =/yabsm=. It only makes sense for this directory to be a btrfs
subvolume.

*** Subvols
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
test
**** fourth depth
