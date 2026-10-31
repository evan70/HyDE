# Moving this desktop to a second machine

The repository is the whole desktop: `Configs/` mirrors `$HOME`, `Scripts/install.sh -r` deploys it
through deez-dots, and `Scripts/install_pst.sh` does the post-install steps. This page is the
checklist for taking that tree to another machine without a chat history, and for asking a machine
whether it still matches the repository.

## Transport

The checkout is the transport. Clone it on the second machine:

```bash
git clone https://github.com/evan70/HyDE.git ~/HyDE
```

When the machine has no network access to GitHub yet, carry a bundle instead and clone from it:

```bash
# first machine
git -C ~/HyDE bundle create /media/usb/hyde.bundle --all
# second machine
git clone /media/usb/hyde.bundle ~/HyDE
git -C ~/HyDE remote set-url origin https://github.com/evan70/HyDE.git
```

`AGENTS.md`, `NOTES.md` and the OpenSpec tree live in the checkout, so they arrive with either
transport; nothing outside `Configs/` has to be copied by hand.

## Account

`machine-setup.sh` starts from a logged-in account and still writes only inside that account's
`$HOME`; it does not create accounts. The account this desktop expects is checked, and on request
created, by `Scripts/machine-user.sh`, which runs from the checkout like the other scripts:

```bash
./Scripts/machine-user.sh --check                 # read-only, changes nothing; default account is hypr
./Scripts/machine-user.sh --create --name hypr    # only when the check says the account is missing
```

The check prints every condition it can read and exits non-zero while one is unmet: the account
exists and is not `root`; `sudo -n` works (the installer needs sudo); `$HOME` exists, belongs to the
account and is writable by it; the login shell is listed in `/etc/shells`; a password is set (a
locked account cannot sign in at SDDM); each group in the table;
`/usr/share/wayland-sessions/hyprland.desktop` exists; and
`display-manager.service` starts SDDM rather than whatever login manager the machine had before.

| Group | Why this desktop needs it |
| --- | --- |
| `wheel` | sudo, which `install.sh -i` needs |
| `video`, `render` | GPU access and DRM for Hyprland |
| `input` | input devices |
| `audio` | PipeWire |
| `storage` | drive mounts through udisks |

A group the distribution does not define at all is reported as a note, not a failure; a group that
exists but the account lacks is a failure, and the output prints the `usermod` command that fixes
it.

`--create` creates a missing account with `useradd -m` and those groups, using `/bin/zsh` when
`/etc/shells` lists it and `/bin/bash` otherwise; the primary group is created with the account
(`-U`), or reused if a group of the same name already exists. An existing account keeps its name,
`$HOME` and shell — only missing groups are added, so the command is safe to re-run. The password
is set only through the interactive `sudo passwd`; without a terminal the script prints that
command instead of choosing a password, and the check keeps failing until it runs.

The script refuses to run as `root`: its questions are about a user's `$HOME`, session and sudo,
and the deploy afterwards has to run as that same account. Run it as any account that has sudo and
name the target with `--name`.

The name is a default, not a requirement. On a machine that already runs another desktop — an Arch
install with someone's own account, for example — pass that account instead of creating `hypr`:

```bash
./Scripts/machine-user.sh --check --name evan    # is the account you already use ready?
./Scripts/machine-user.sh --create --name evan   # adds only the missing groups
./Scripts/machine-setup.sh                       # run as that account; the desktop lands in its $HOME
```

That account keeps its home, shell and password, and nothing is renamed: this desktop is an
addition to it, not a replacement. The only shared thing is the SDDM theme.

Rollback of a created account: `sudo userdel -r hypr`. Removing one group:
`sudo gpasswd -d hypr <group>`.

## Provisioning

Log in as the account that should get the desktop — create it first with the two commands from
[Account](#account) if the machine has none. The deploy only writes inside that account's `$HOME`;
an existing account on the machine keeps its own dotfiles. The one system-wide change is the SDDM
theme, and `install_pst.sh` only writes it when the machine has no HyDE theme configured yet — so
the login screen is shared, everything else is not.

```bash
cd ~/HyDE
./Scripts/machine-user.sh --check    # account check, read-only; see Account above
./Scripts/machine-user.sh --create   # only if the check reports the account as missing
./Scripts/install.sh -i -s           # only on a bare machine: packages, AUR helper, nvidia, shell, system services
./Scripts/machine-setup.sh           # deploy Configs/, post-install steps, OpenSpec check
```

`install.sh -i -s` enables SDDM but does not take over from a login manager that was already
running: on a notebook that came with XFCE, LightDM still owns the boot until it is switched (see
[When something goes wrong](#when-something-goes-wrong)).

`install.sh -i` is interactive (AUR helper, nvidia, shell) and `machine-setup.sh` inherits the
terminal, so prompts — the SDDM theme picker, the flatpak list — are answered by the person running
it. Without a terminal (CI, a closed stdin) it feeds empty answers instead, which those prompts read
as "take the default", so an unattended run does not stall on a question it cannot show.

What the deploy prints, in order:

| Output | Meaning |
| --- | --- |
| `revízia ::` | the commit being deployed, so the other machine can be compared against this one |
| `prvý deploy ::` / `prepíše sa ::` | which deployed files are missing or differ from `Configs/`, before anything is touched |
| `nechá sa ::` | files that belong to the user or are generated by the theme; never overwritten by this step |
| `install.sh -r` | deploy, dependency re-check, theme colour state, wallpaper cache |
| `install_pst.sh` | SDDM theme, shell, default file manager, optional flatpaks |
| `OPENSPEC` | OpenSpec CLI version, or the install command when it is missing |

Afterwards it prints the steps it cannot do for you: the first login and theme choice, and
`gh auth login` before the first `git push`.

Two more things it names but does not do for you:

- **Shared cursors and CJK fonts.** `Bibata-Modern-Ice`, its hyprcursor build and `NotoSansCJK` are
also installed under `/usr/local/share`, which an ordinary account cannot write. When they are
already there the deploy says `systémové assety (N) už na stroji sú` and carries on; when they are
missing it prints the path and the `sudo cp -a` command that copies it from the account's own copy
in `~/.local/share`.
- **`gtk.css.pre-hyde`.** An account that came from another desktop has a real
`~/.config/gtk-4.0/gtk.css` (CachyOS ships one). The theme switch renames it to `gtk.css.pre-hyde`
once and links the theme's file in its place; the distro file is kept, and an existing
`.pre-hyde` copy is never overwritten.

## Verifying

```bash
./Scripts/machine-setup.sh --verify   # changes nothing, exits non-zero on a difference
./Scripts/machine-setup.sh --dry-run  # what deploy would do, with install.sh -t
```

`--verify` compares the live tree with the deez-dots manifest (`~/.local/share/deez/dots/*.toml`),
which is the record of what deployment actually wrote. That is deliberate: `Configs/` also holds
files deez ignores on purpose (`__pycache__`, `.editorconfig`, `share/hyde/schema`), and comparing
every tracked file would report them as broken forever.

Each file is put in one of four buckets:

| Bucket | Meaning | Counts as failure |
| --- | --- | --- |
| `deploy` | deployed with `sync`; missing or different from `Configs/` | yes |
| `user` | deployed with `preserve` (`config.toml`, `settings.ini`, theme colours, ...) | no — the account owns it |
| `generated` | rewritten by the theme engine or a running application (`dunstrc`, `dolphinrc`, ...) | no |
| `stale` | the repository no longer has it; the next deploy removes it | no |

The session half checks that Hyprland runs, the Waybar unit is active, the SDDM theme named in
`/etc/sddm.conf.d/the_hyde_project.conf` exists, and `openspec --version` works. The account itself
is not part of `--verify` (it needs no privileges): `Scripts/machine-user.sh --check` covers it.

A failing `deploy` bucket means one of two things. If the repository is newer (the usual case after
`git pull`), run `./Scripts/machine-setup.sh` to deploy it. If the *live* file is the newer one — a
tweak made on the running desktop — move it into `Configs/` first, commit, then deploy: live copies
are edited through the repository, never the other way round.

## OpenSpec

Planning uses the OpenSpec CLI; the deploy only reports it, it does not install it from a pipe. If
it is missing:

```bash
curl -fsSL https://raw.githubusercontent.com/Fission-AI/OpenSpec/main/scripts/binary/install.sh | sh
# or pin the version this fork was set up with
OPENSPEC_VERSION=v1.15.0 curl -fsSL https://raw.githubusercontent.com/Fission-AI/OpenSpec/main/scripts/binary/install.sh | sh
```

Telemetry is off in `~/.config/openspec/config.json` on this machine; a new machine starts with the
default and can be switched off the same way.

## When something goes wrong

- **`install.sh -r` fails with `deez-dots not found`** — the Python environment is missing; run
  `./Scripts/install.sh -p` (pre-install only), then `./Scripts/machine-setup.sh` again.
- **Packages are missing** — `install.sh -i` first; the restore re-checks dependencies but a bare
  machine wants the full install once.
- **`--verify` reports `NO_MANIFEST`** — nothing has been deployed for this account yet; run the
  deploy.
- **The machine still boots into XFCE** — `install.sh -i -s` only enables `sddm`; when the machine
  already ran XFCE, the old login manager (usually LightDM) still owns
  `/etc/systemd/system/display-manager.service`, so the boot lands in the old session even though
  `sddm` is installed. `systemctl status display-manager` names the manager that starts; switch with
  `sudo systemctl disable lightdm && sudo systemctl enable sddm` and reboot.
  `machine-user.sh --check` reports this as a condition of its own, not as a missing session file,
  and separates it from a machine where `sddm` was never installed (`pacman -Q sddm` says nothing),
  because there the enable had nothing to start.
- **SDDM appears but preselects the XFCE session** — pick `Hyprland` in the greeter's session menu
  once; SDDM remembers the last choice and the repository does not set a default session.
- **Backups** — every overwritten file is kept under `~/.config/cfg_backups/<date>/`, so a wrong
  deploy can be undone by copying back from there.
