# Yabsm (yet another btrfs snapshot manager)

The latest release of Yabsm, including all documentation, can be found on CPAN [here](https://metacpan.org/dist/App-Yabsm/view/bin/yabsm).

# Issues

Don't hesitate to [open an issue](https://github.com/NicholasBHubbard/Yabsm/issues).

# Developers
### Install [Dist::Zilla](https://metacpan.org/pod/Dist::Zilla)
```
$ cpanm Dist::Zilla
```
### Download dependencies 
```
$ dzil authordeps | cpanm
$ dzil listdeps | cpanm
```
### Run the test suite
```
$ dzil test
```
### Build the distribution
```
$ dzil build
```
### Release to CPAN
```
$ dzil release
```
# License

MIT
