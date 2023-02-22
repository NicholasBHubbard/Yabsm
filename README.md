# Yabsm (yet another btrfs snapshot manager)

The latest release of Yabsm, including all user documentation, can be found on CPAN [here](https://metacpan.org/dist/App-Yabsm/view/bin/yabsm).

# Issues

Don't hesitate to [open an issue](https://github.com/NicholasBHubbard/Yabsm/issues).

# Developers

All patches welcome!

#### Features to Add

- Add bash completion, specifically for the `find` command

#### CPAN Release Steps

- Make sure the `$VERSION` variable is correct in `/lib/App/Yabsm.pm`
- Make sure `/Changes` lists all relevant changes since previous version
- In `/Changes`, update TBD to today's yyyy-mm-dd
- Run the test suite
- Make sure that [/cpanfile](https://metacpan.org/dist/Module-CPANfile/view/lib/cpanfile.pod) lists all the dependencies (with specific versions) that need to be fatpacked
- Pack the script with [App::FatPacker](https://metacpan.org/pod/App::FatPacker): `$ fatpack pack bin/yabsm-unpacked > bin/yabsm`
- Make the dist: `$ make clean; perl Makefile.PL; make; make test; make dist`
- Examine the dist to make sure everything is as expected
- Do a [cpan-upload](https://metacpan.org/pod/CPAN::Uploader) dry run: `$ cpan-upload --dry-run App-Yabsm-*.tar.gz`
- Check everything one last time
- Upload to CPAN: `$ cpan-upload -u $PAUSE_USERNAME App-Yabsm-*.tar.gz`
- Cleanup: `$ make clean`

# Packagers

#### Dependencies

- Perl >= 5.34.0
- Sudo
- OpenSSH
- btrfs-progs

#### Relevant Packaging Information

Yabsm runs as a cron-style daemon that is meant to be started at boot time. An example sysvinit-style init script is provided in `/examples/rc.yabsmd`, and an example systemd service is provided in `/examples/yabsmd.service`.

An example configuration is provided in `/examples/yabsm.conf.example`. It would be helpful to the user if this file was installed to `/etc/yabsm.conf.example`.

#### Versioning Scheme

Yabsm uses [semantic versioning](https://semver.org/). The MAJOR version is upgraded if we make any change that breaks backwards compatibility. The MINOR version is upgraded if functionality is added. The PATCH version is upgraded if there is a bug fix, or an upgrade is made to one of the fatpacked CPAN dependencies.
