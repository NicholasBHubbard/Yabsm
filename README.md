# Yabsm (a btrfs snapshot manager and backup system)

Yabsm's user manual can be found on CPAN [here](https://metacpan.org/release/NHUBBARD/App-Yabsm-3.15.2/view/bin/yabsm).

I also wrote an article about how I personally use Yabsm [here](https://dev.to/nicholasbhubbard/how-i-use-yabsm-to-manage-my-btrfs-snapshots-19a3).

# Installation

Yabsm is officially supported on Arch, and Slackware (more distributions coming soon).

#### Arch

Available on the AUR as [yabsm](https://aur.archlinux.org/packages/yabsm). After creating a configuration, start and enable the yabsmd service:

```
# systemctl start yabsmd
# systemctl enable yabsmd
```

#### Slackware

Available on SlackBuilds.org as [system/yabsm](https://slackbuilds.org/repository/15.0/system/yabsm/) (be sure to read its README).

# Issues

Don't hesitate to [open an issue](https://github.com/NicholasBHubbard/Yabsm/issues).

# Developers

If Yabsm is not packaged for your Linux distribution I would really appreciate it if you packaged it (and let me know you packaged it).

#### Features to Add

- Bash completion, specifically for the `find` command
- On-demand snapshots/backups

#### Dependencies

- Perl >= 5.34.0
- btrfs-progs
- OpenSSH
- sudo
- which

#### Relevant Packaging Information

Yabsm runs as a cron-style daemon that is meant to be started at boot time. An example sysvinit-style init script is provided in `/examples/rc.yabsmd`, and an example systemd service is provided in `/examples/yabsmd.service`.

Yabsm is distributed as an [App::FatPacker](https://metacpan.org/pod/App::FatPacker) packed script. This allows Yabsm to be implemented in a single executable, with all of its CPAN dependencies packed into this file. For all packaging purposes Yabsm has zero CPAN dependencies. The test suite however depends on Test::Exception, so it will be needed if you want to run the test suite at install time (which should not be necessary).

An example configuration is provided in `/examples/yabsm.conf.example`. This example configuration should be installed to `/etc/yabsm.conf.example`.

#### Versioning Scheme

Yabsm uses [semantic versioning](https://semver.org/). The MAJOR version is upgraded if we make any change that breaks backwards compatibility. The MINOR version is upgraded if functionality is added that does not break backwards compatibility. The PATCH version is upgraded if there is a bug fix, or an upgrade is made to one of the fatpacked CPAN dependencies.


#### CPAN Release Steps

- Make sure the `$VERSION` variable is correct in `/lib/App/Yabsm.pm`
- Make sure that [/cpanfile](https://metacpan.org/dist/Module-CPANfile/view/lib/cpanfile.pod) lists all the dependencies (with specific versions) that need to be fatpacked
- Install all modules listed in `/cpanfile`: `$ cpanm --installdeps .`
- Run the test suite and make sure all tests pass
- Pack `bin/yabsm-unpacked` with [App::FatPacker](https://metacpan.org/pod/App::FatPacker): `$ fatpack pack bin/yabsm-unpacked > bin/yabsm`
  - Make the dist: `$ perl Makefile.PL; make; make test; make dist`
- Examine the dist to make sure everything is as expected
- Make sure `/Changes` lists all relevant changes since the previous version and denotes todays date for the version to be released
- Check everything one last time. Specifically, make sure all the CPAN deps (with correct version) have been fatpacked into `bin/yabsm`.
- Upload to CPAN: `$ cpan-upload -u $PAUSE_USERNAME App-Yabsm-$VERSION.tar.gz`
- Update this documents link to the official so it point to the new version.

# Copyright and License

Copyright (C) 2022-2023 by Nicholas Hubbard <nicholashubbard@posteo.net>

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with App-Yabsm. If not, see http://www.gnu.org/licenses/.
