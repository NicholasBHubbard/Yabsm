# -*- mode:org;mode:auto-fill;fill-column:79 -*-
#+title: YABSM (yet another btrfs snapshot manager)
#+author: Nicholas Hubbard

* Why should I use YABSM?
  The entire point of YABSM is to make it effortless to set up a custom snapshot
  system. All you have to do is edit a simple configuration file and run one
  command. YABSM is a workflow tool more than a backup system. 

* Features
  + Split your snapshots into hourly, daily, midnight, and monthly categories.
  + Take up to a snapshot per minute, a snapshot per hour, a snapshot every
    night at midnight, and a snapshot on the first of every month.
  + Keep as many or as little snapshots as you want per category. 
  + Use =yabsm-find= to quickly jump to a snapshot.

    These are the main features. I use this as a workflow tool. How many times
    have you been like, "I know this was working 10 hours ago, or 2 days ago,
    or 15 minutes ago"? Whenever I think this I just use =yabsm-find= to
    quickly go back in time.

* How do I use it?
  You can tweak your configuration by editing the =/etc/yabsmrc= file. After
  you're done simply run =sudo yabsm-update= and you're good to go. 

  Snapshots are named after the time they are taken in =yyyy_mm_dd_hh_mm= format. 
  For example a snapshot taken at 15:30 on March 20th 2021 will be named
  =day=2021_03_20,time=15:30=. 

  Please note that snapshots are read only. To take read/write snapshots remove the =-r= from
  line 89 of =/usr/local/sbin/yabsm-take-snapshot=.

  Please also note that =/usr/local/sbin= must be on your path (unless you
  enjoy typing long path names!).

* Installation
  #+BEGIN_SRC  
  $ cd
  $ git clone https://github.com/NicholasBHubbard/yabsm.git
  $ sudo yabsm/init
  #+END_SRC  
  Now just modify =/etc/yabsmrc= to your liking and then run:
  #+BEGIN_SRC
  sudo yabsm-update
  #+END_SRC
*  The config file
This is what your config will look like out of the gate:
  #+BEGIN_SRC  
# /etc/yabsmrc
                                      
            #-----------------------------------------#
            # WELCOME TO THE YABSM CONFIGURATION FILE #
            #-----------------------------------------#

snapshot_directory=/.snapshots

### Every subvolume requires 8 fields

### subvolumes can be named whatever you want. These names only 
### exits in the world of YABSM.

### I_want_to_snap_this_subvol=NAME,PATH 

I_want_to_snap_this_subvol=root,/

root_hourly_take=12
root_hourly_keep=24

root_daily_take=24
root_daily_keep=48

root_midnight_want=yes
root_midnight_keep=14 

root_monthly_want=yes
root_monthly_keep=12


### I can snapshot as many subvolumes as I want

I_want_to_snap_this_subvol=home,/home

home_hourly_take=12
home_hourly_keep=100

home_daily_take=13
home_daily_keep=14

home_midnight_want=no
home_midnight_keep=0

home_monthly_want=no
home_monthly_keep=100001
  #+END_SRC  
  There are a few things to note here:
  + You must specify the mount point of the root of your snapshot
    subvolume. Traditionally this is =/.snapshots=.


  + For every subvolume you want to snapshot you must specify a
    =I_want_to_snap_this_subvol= field. On the right hand side of the equals
    sign should be the name of the subvolume and it's mount point, separated by
    a comma. The name you choose is only relevant to YABSM.


  + Every subvolume is required to have 8 fields associated with it.

* What do the settings mean?
  + =*_*_keep=: How many of this type of snapshot do you want to keep around? 


  + =*_hourly_take=: How many snapshots do you want to take over the course of
    an hour? Max value is 60.


  + =*_daily_take=: How many snapshots do you want to take per day? These
    snapshots are taken at the beginning of the hour. Max value is 24.


  + =*_midnight_want=: Do you want to take a snapshot every night at midnight?


  + =*_monthly_want=: Do you want to take a snapshot on the first of every month?

* yabsm-find
  YABSM comes with a program called =yabsm-find=. This program lets you access
  a snapshot by making a simple query like =yabsm-find home back-40-mins=, to jump to a
  snapshot taken 40 minutes ago. You can also go back by hours or days. The other
  type of query you can make is entering a date formated like =yyyy-mm-dd-hh-mm=.

  Yabsm will copy to your clipboard a =cd= command to the root directory of your desired
  snapshot. Unfortunately YABSM cannot directly change your directory due to a
  limitation of Perl.

  You must install xclip if using x11 or wl-clipboard if using Wayland.

  If you are using Wayland then please remove the =#= from the beginning of line 74 in
  =/usr/local/sbin/yabsm-find= and delete line 75.

  Here are some examples that should show how it works:
  #+BEGIN_SRC  
  $ yabsm-find home back-40-mins
    successfully copied "cd" command to clipboard

  $ yabsm-find root 'b 40 days'
    successfully copied "cd" command to clipboard

  $ yabsm-find home 2020-3-23-13-30
    successfully copied "cd" command to clipboard
  #+END_SRC  
  You do not have to pass your subvolume or query on the command line (you can
  pass just one if you'd like).
  #+BEGIN_SRC  
  $ yabsm-find 
  select subvolume:
  1 -> home     2 -> root
  >>> 1
  enter query:
  >>> b 5 h
  successfully copied "cd" command to clipboard
  #+END_SRC  
  Here is a list of valid queries. 
  #+BEGIN_SRC
  b 4 m
  back 4 m
  b 4 h
  b 4 d
  b 4 mins
  b 4 hrs
  b 4 days
  2020-3-20-13-30
  #+END_SRC
  Note: If you are only using YABSM to snapshot one subvolume then you don't need to
  mention it to yabsm-find.

* Where do my snapshots go?
Here is the file tree structure for the example configuration.
  #+BEGIN_SRC  
/.snapshots
|
|── yabsm
    |
    |── root
    |   |── hourly
    |   |── daily
    |   |── midnight
    |   |── monthly
    |
    |── home
        |── hourly
        |── daily

  #+END_SRC  

* What does YABSM do to my computer?
  YABSM simply writes cronjobs to =/etc/crontab= that call =yabsm-take-snapshot= for
  taking new snapshots and deleting old snapshots.

  Three scripts, namely =yabsm-take-snapshot=, =yabsm-update=, and =yabsm-find=
  are placed into =/usr/local/sbin=. Only the =yabsm-update=, and =yabsm-find=
  scripts are meant to be used by the user.

  Helper files, namely =Yabsm.pm= and =Yabsm.t= are placed into =/usr/local/lib/yabsm=.
