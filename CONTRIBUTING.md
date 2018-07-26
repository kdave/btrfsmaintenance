#### Contributions are welcome ####

This tool is getting wider use in various distros and environments and may not
cover particular usecase.

Changes in functionlity should try to be generic and respect needs of others if
applicable.

Common scripts/configs are preferred but per-distro exceptions will be added
when necessary.

Backward compatibility is important to us. The scripts could be used on
long-term supported distros but also in bleeding edge development environments.

The shell code assumes the basic `sh` level, and no advanced trick should be
used.


#### Bug reports, feature requests ####

Please open issues for bugs or feature requests.

Some features may depend on functionality provided by linux kernel or
btrfs-progs. Patches might get applied after the required functionality is
merged upstream.


#### Pull requests ####

Pull requests will be accepted if the patches satisfy some basic quality
requirements:

* descriptive subject lines
* changelogs that explain why the change is made (unless it's obvious)
* one logical change per patch (really simple changes can be grouped), ie.
  multiple patches per pull request branch are fine
* the `Signed-off-by` line is optional but desirable, see [Developer
  Certificate of Origin](http://developercertificate.org/), eg. use `git commit -s`

For non-github contributors: mail bug reports or patches are also accepted.


#### Releases ####

At the moment there's no schedule, the basic functionality is covered.
Releases are cut when there are enough bugfixes accumulated or there's an
urgent fix. If you think thre's an important fix yet unreleased, feel free to
ping and ask about the ETA.
