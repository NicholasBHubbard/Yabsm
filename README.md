# -*- mode:org;mode:auto-fill;fill-column:79 -*-
#+title: YABSM (yet another btrfs snapshot manager)
#+author: Nicholas Hubbard

* Why should I use YABSM?
  The entire point of YABSM is to make it trivial to set up a custom snapshot
  system. All you have to do is edit a simple configuration file and run one
  command.

* How do I use it?
  Here is an example yabsm configuration

  #+BEGIN_SRC  
  # /etc/yabsmrc
                                        
            #-----------------------------------------#
            # WELCOME TO THE YABSM CONFIGURATION FILE #
            #-----------------------------------------#

  snapshot_directory=/.snapshots



  I_want_to_snap_this_subvol=root,/

  root_hourly_take=60
  root_hourly_keep=24

  root_daily_take=24
  root_daily_keep=48

  root_midnight_want=no
  root_midnight_keep=10001

  root_monthly_want=yes
  root_monthly_keep=12



  I_want_to_snap_this_subvol=home,/home/user
  
  home_hourly_take=12
  home_hourly_keep=100

  home_daily_take=13
  home_daily_keep=

  home_midnight_want=no
  home_midnight_keep=0

  home_monthly_want=no
  home_monthly_keep=0
  #+END_SRC  

  There are a couple of things to note here
  + You must specify the mount point of the root of your snapshot
    subvolume. Traditionally this subvolume is mounted at /.snapshots.
  + For every subvolume you want to snapshot you must specify a
    'I_want_to_snap_this_subvol' field. On the right hand side of the equals
    sign should be the name of the subvolume and it's mount point. Note that
    you can name your subvolumes whatever you would like. These names are not
    related to the internal btrfs names.
  + For every subvolume you wish to snapshot you are required to specify a
    field for all of the following: *_hourly_take, *_hourly_keep, *_daily_take,
    *_daily_keep, *_midnight_want, *_midnight_keep, *_monthly_want,
    *_monthly_keep. 
