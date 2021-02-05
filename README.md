# -*- mode:org;mode:auto-fill;fill-column:79 -*-
#+title: YABSM (yet another btrfs snapshot manager)
#+author: Nicholas Hubbard

* Why should I use YABSM?
  The entire point of YABSM is to make it trivial to set up a custom snapshot
  system. All you have to do is edit a simple configuration file and run one
  command.

* Features
  + Split your snapshots into hourly, daily, midnight, and monthly categories.
  + Take up to a snapshot per minute, a snapshot per hour, a snapshot every
    night at midnight, and a snapshot on the first of every month.
  + Keep as many or as little snapshots as you want per category. YABSM will
    delete appropriate snapshots.
  
* How do I use it?
  You can tweak your configuration to your liking by editing the =/etc/yabsmrc=
  file. After you are done simply run =sudo yabsm update= and you are good to
  go. You may of course modify your settings whenever you want. 

  Snapshots are named after the time they are taken in =yyyy_mm_dd= format. 
  For example a snapshot taken at 15:30 on March 20th 2021 will be named
  =day=2021_03_20,time=15:30=. 

  Please note that snapshots are read only.

  Please also note that =/usr/local/sbin= must be on your path. 

* Installation
  #+BEGIN_SRC  
  $ cd
  $ git clone https://github.com/NicholasBHubbard/yabsm.git
  $ cd ./yabsm/src/
  $ sudo perl yabsm_init.pl
  #+END_SRC  
  Now just modify =/etc/yabsmrc= to your liking and then run:
  #+BEGIN_SRC
  sudo yabsm --update
  #+END_SRC
  Feel free to remove the cloned repo.

*  Example Configuration
  #+BEGIN_SRC  
# /etc/yabsmrc
                                      
              #-----------------------------------------#
              # WELCOME TO THE YABSM CONFIGURATION FILE #
              #-----------------------------------------#

snapshot_directory=/.snapshots



I_want_to_snap_this_subvol=root,/

root_hourly_take=12
root_hourly_keep=24

root_daily_take=24
root_daily_keep=48

root_midnight_want=yes
root_midnight_keep=14

root_monthly_want=yes
root_monthly_keep=12



I_want_to_snap_this_subvol=home,/home

home_hourly_take=12
home_hourly_keep=100

home_daily_take=13
home_daily_keep=

home_midnight_want=no
home_midnight_keep=0

home_monthly_want=no
home_monthly_keep=100001
  #+END_SRC  
  There are a few things to note here:
  + You must specify the mount point of the root of your snapshot
    subvolume. Traditionally this subvolume is mounted at /.snapshots.


  + For every subvolume you want to snapshot you must specify a
    =I_want_to_snap_this_subvol= field. On the right hand side of the equals
    sign should be the name of the subvolume and it's mount point. Note that
    you can name your subvolumes whatever you would like. These names are not
    related to the internal btrfs names.


  + For every subvolume you wish to snapshot you are required to specify a
    field for each of the following: =*_hourly_take=, =*_hourly_keep=,
    =*_daily_take=, =*_daily_keep=, =*_midnight_want=, =*_midnight_keep=,
    =*_monthly_want=, =*_monthly_keep=.

  + You are required to take hourly and daily snapshots. 
* What do the settings mean?
  + =*_*_keep=: How many of this type of snapshot do you want to keep around? 


  + =*_hourly_take=: How many snapshots do you want to take over the course of
    an hour? Max value is 60.


  + =*_daily_take=: How many snapshots do you want to take per day? These
    snapshots are taken at the beginning of the hour. Max value is 24.


  + =*_midnight_want=: Do you want to take a snapshot every night at midnight?


  + =*_monthly_want=: Do you want to take a snapshot on the first day of every month?

* Where do my snapshots go?
Here is the file tree structure of the example configuration
  #+BEGIN_SRC  
  /.snapshots
  |
  ├── root
  │   ├── hourly
  │   ├── daily
  │   ├── midnight
  │   └── monthly
  └── home
      ├── hourly
      ├── daily
  #+END_SRC  

* What does YABSM do to my computer?
  YABSM simply writes cronjobs to =/etc/crontab= that call a script for
  taking new snapshots and deleting old snapshots.

  Three scripts, namely =yabsm-take-snapshot=, =yabsm-update-conf=, and =yabsm=
  are placed into =/usr/local/sbin=. Only the =yabsm= script is meant to be
  used by the user. 
