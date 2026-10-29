# Proposal

## Why

`machine-setup.sh` starts from the assumption that the account which gets the desktop already
exists and is already logged in — it only writes inside that account's `$HOME`. On the notebook
that assumption is the first unchecked step: the `hypr` account (groups `wheel`, `video`, `render`,
`input`, `audio`, `storage`, shell `/bin/zsh`) has to be created and verified by hand before
`install.sh -i -s` can even run, and nothing in the repository records what "ready for HyDE" means
for an account. `grep -rn 'useradd\|adduser'` finds nothing in the tree, so today the notebook test
depends on a machine-specific memory.

## What Changes

- New fork-only script `Scripts/machine-user.sh` with two modes:
  - `--check` (default): read-only. Reports whether the account exists, is not `root`, can use
    `sudo`, has its `$HOME` writable and owned by itself, carries the groups this desktop needs, has
    a shell listed in `/etc/shells`, and whether the login manager offers `hyprland.desktop` for it.
  - `--create`: creates the missing account with `useradd -m` and the required groups, then hands
    the password to interactive `sudo passwd` (never on the command line, never logged). Already
    existing account: adds only missing groups, renames nothing, changes no shell.
- Account name defaults to `hypr`, overridable with `--name NAME`; both modes accept it before any
  action, and neither mode touches any other account.
- `SYNC.md` gets an "Account" section: the pre-flight check, the create command, and the group list
  with the reason each group is needed.
- `machine-setup.sh` and its `--verify` are **not** changed: they keep their documented "only
  `$HOME`" property, and no privileged check starts running as a side effect of a deploy.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `machine-provisioning`: adds the requirement that an account prepared for this desktop is
  checkable and creatable from the repository, with its own scenario set; the existing "Existing
  accounts are left alone" requirement stays as it is and is not weakened.

## Impact

- Repository files: `Scripts/machine-user.sh` (new), `SYNC.md` (new section), this change's
  artifacts.
- Live paths under `$HOME`: **none**. `Scripts/` is not deployed by deez-dots, so the new script
  runs from the checkout exactly like `machine-setup.sh`; no file under `~/.config` or `~/.local`
  changes.
- System-wide: `useradd`/`usermod` behind `sudo`, plus the interactive `passwd`. Only when
  `--create` is asked for, and only for the account named on the command line.
- Upstream drift: untouched — the script is a fork-only addition, no upstream file is edited, so
  merges from `HyDE-Project/HyDE` are unaffected.
- Out of scope: dotfile deployment (that is `machine-setup.sh`), password policy and `sudoers`,
  SDDM autologin configuration, other login sessions, accounts on non-Arch systems, and renaming or
  migrating an existing account.
