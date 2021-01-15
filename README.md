# -*- mode:org;mode:auto-fill;fill-column:79 -*-
#+title: YABSM (yet another btrfs snapshot manager)
#+author: Nicholas Hubbard

* Why should I use YABSM?
  The entire point of YABSM is to make it trivial to set up a custom snapshot
  system. All you have to do is edit a simple configuration file and run one
  command. 

* How it works
  Here is an example yabsm configuration

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
  #+END_SRC  
