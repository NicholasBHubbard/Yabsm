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
  + Keep as many or as little snapshots as you want per category. 
  + A program called =yabsm-find= that makes it quick to jump to a snapshot.

    These are the main features. I use this as a workflow tool. How many times
    have you been like, "I know this was working 10 hours ago, or 2 days ago,
    or 15 minutes ago". Whenever I think this I just use `yabsm-find` to
    quickly go to an exact copy of 14 hours ago.

    To modify this program you will modify the source code. I swear it is easy. 

* How do I use it?
  You can tweak your configuration to your liking by editing the =/etc/yabsmrc=
  file. After you're done simply run =sudo yabsm-update= and you are good to
  go. You can modify your settings whenever you want and run the update program again.

  Snapshots are named after the time they are taken in =yyyy_mm_dd_hh_mm= format. 
  For example a snapshot taken at 15:30 on March 20th 2021 will be named
  =day=2021_03_20,time=15:30=. 

  Please note that snapshots are read only.

  Please also note that =/usr/local/sbin= must be on your path. 

* Installation
  #+BEGIN_SRC  
  $ cd
  $ git clone https://github.com/NicholasBHubbard/yabsm.git
  $ sudo ./yabsm/init
  #+END_SRC  
  Now just modify =/etc/yabsmrc= to your liking and then run:
  #+BEGIN_SRC
  sudo yabsm-update
  #+END_SRC
  This is another reminder you that you need /usr/local/sbin in your path.
  Feel free to remove the cloned repo.

*  THIS IS WHAT YOUR CONFIG WILL LOOK LIKE OUT OF THE GATE
  #+BEGIN_SRC  
# /etc/yabsmrc
                                      
                         #-----------------------------------------#
                         # WELCOME TO THE YABSM CONFIGURATION FILE #
                         #-----------------------------------------#

snapshot_directory=/.snapshots

### Every subvolume requires 8 fields

### subvolumes can be named whatever you want. These names only 
### exits in the world of yabsm.

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
    subvolume. Traditionally this subvolume is mounted at /.snapshots.

  + For every subvolume you want to snapshot you must specify a
    =I_want_to_snap_this_subvol= field. On the right hand side of the equals
    sign should be the name of the subvolume and it's mount point, seperated by
    a comma. These subvolume names are only relevant to yabsm.

  + Every subvolume is required to have 8 fields associated with it.

* What do the settings mean?
  + =*_*_keep=: How many of this type of snapshot do you want to keep around? 

  + =*_hourly_take=: How many snapshots do you want to take over the course of
    an hour? Max value is 60.

  + =*_daily_take=: How many snapshots do you want to take per day? These
    snapshots are taken at the beginning of the hour. Max value is 24.

  + =*_*_want=: Do you want to take a snapshot at midnight/first of the month?

* How can I quickly jump to a snapshot?
  Yabsm comes with a program called =yabsm-find=. This program lets you access
  a snapshot by making a simple query like =back 40 mins=, to jump to a
  snapshot taken 40 minutes ago. In fact, the only kind of query you can make
  is of the form =back n units=. 

  Caveat: I cannot make you directly jump to a a directory, instead a =cd=
  command is copied to the clipboard. This is due to a limitation of
  Perl. Because of this you must install the =xclip= program. 

  Here are some examples:
  #+BEGIN_SRC  
  $ yabsm-find home 'b 40 m'
    successfully copied "cd" command to clipboard
  $ yabsm-find
  $ sudo ./yabsm/init
  #+END_SRC  
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
  YABSM simply writes cronjobs to =/etc/crontab= that call a script for
  taking new snapshots and deleting old snapshots.

  Three scripts, namely =yabsm-take-snapshot=, =yabsm-update=, and =yabsm-find=
  are placed into =/usr/local/sbin=. Only the =yabsm-update=, and =yabsm-find=
  scripts are meant to be used by the user. 


  
