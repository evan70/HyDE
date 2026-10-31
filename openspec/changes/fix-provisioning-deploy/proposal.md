# Proposal

## Why

The first real second-machine run (notebook `probook`, 2026-10-31) ended in
`ERROR :: Some dots were not deployed` and `[theme] error :: generating the colour state for
Catppuccin Mocha failed with 4`, although the desktop came up themed and working. Four separate
causes made a healthy deploy report failure, and one of them (`gtk.css`) needed a manual `mv`
before the next run could pass. A provisioning entry point that cries wolf on every re-run cannot
be trusted to tell a ready machine from a broken one.

## What Changes

- Deployment stops counting the three dots that install into `/usr/local/share` (cursor, hyprcursor,
  CJK font) as failures when it may not write there: the system copy is verified through the same
  manifest and reported as a note when it already exists, instead of aborting the run with
  `PermissionError`.
- `wallbash` treats a template whose target directory does not exist yet as an optional target:
  it is skipped with a note and no longer makes the whole colour state "incomplete", so
  `theme.switch.sh` applies the theme and reports success instead of exit 4.
- The GTK 4 link step in `theme.switch.sh` no longer fails on a pre-existing real file
  (`~/.config/gtk-4.0/gtk.css` from a distro default): the file is moved aside once, and only then
  is the theme's symlink created.
- `machine-setup.sh` runs from the account's `$HOME` regardless of where it was started, so
  `sudo -u <account>` from another account's shell deploys the complete tree instead of failing
  every `find` with `Failed to restore initial working directory`.

## Capabilities

### New Capabilities
<!-- none: the deploy behaviour below already belongs to machine-provisioning -->

### Modified Capabilities

- `machine-provisioning`: provisioning reports a failure only when something is genuinely missing
  or could not be written inside the account, keeps working when it is started from another
  account's directory, and completes the theme colour state on an account that never had HyDE.

## Impact

- Repository files: `Scripts/machine-setup.sh` (cwd), `Scripts/dots/archives.toml` (system targets),
  `Configs/.local/lib/hyde/color.set.sh` (optional targets), `Configs/.local/lib/hyde/theme.switch.sh`
  (GTK 4 link), `CHANGELOG.md`, `SYNC.md` (what a clean deploy looks like).
- Live paths under `$HOME`: `~/.config/gtk-4.0/gtk.css` (the pre-existing file is moved to
  `gtk.css.pre-hyde`, then linked), `~/.config/hypr/themes/colors.conf` (written by the same
  wallbash pass, unchanged content), `~/.local/share/deez/dots` (manifest entries for the system
  dots). No user-owned setting is rewritten.
- System-wide: `/usr/local/share/icons/Bibata-Modern-Ice` and
  `/usr/local/share/fonts/NotoSansCJK` are read, not written, by this change; when they are absent
  the deploy still reports them as missing, because they need `root` and stay a human step.
- Upstream drift: `color.set.sh` and `theme.switch.sh` are upstream files; this fork already patches
  them (`color/hypr.sh` safety fix, GTK 4 directory layout, SDDM locale formats), so the two edits
  here are small and localised to keep merges from `HyDE-Project/HyDE` cheap. `machine-setup.sh` and
  `Scripts/dots/archives.toml` are fork-owned.
- Out of scope: installing the missing system assets with `sudo` from the deploy, running the whole
  deploy as `root`, changing what a `tarball` dot contains, and the SDDM theme or login manager work
  that was finished in `8696782`.
