# Design

## Context

See `proposal.md` — Why. Constraints that shape the approach:

- `Scripts/machine-setup.sh` documents and relies on a property: it writes only inside the
  `$HOME` of the account that runs it, plus the SDDM theme when the machine has none. That property
  is a spec requirement ("Existing accounts are left alone"), so account creation cannot quietly
  join the deploy path.
- `Configs/` is deployed by deez-dots; `Scripts/` is not. A new script therefore lives in the
  checkout and is run from there, exactly like `machine-setup.sh` — no live copy, no deploy entry.
- The reference account on the current machine is: uid 1002, shell `/bin/zsh`, groups
  `wheel`, `audio`, `input`, `render`, `storage`, `video`; `/usr/share/wayland-sessions/` offers
  `hyprland.desktop` and `hyprland-uwsm.desktop`.
- Fork checks run `bash -n` over every tracked `*.sh`, so the script has to be plain bash with no
  new dependency (no `jq`, no Python).

## Goals / Non-Goals

**Goals:**

- One command answers "is this machine's account ready to receive the desktop", and one command
  makes it so, both from the repository.
- The dangerous half (creating an account, touching groups) is opt-in, confined to one name, and
  never guesses a password.
- Consistent with `machine-setup.sh`: same output helpers, same exit-code contract, same Slovak
  runtime messages and English documentation.

**Non-Goals:**

- Deploying dotfiles, choosing a theme, or starting a session — those stay in
  `machine-setup.sh` / `install.sh`.
- Password policy, `sudoers` content, SDDM autologin, `hyprlock` credentials.
- Managing accounts other than the one named on the command line; migrating an existing account to
  a different name or uid.
- Supporting non-Arch login managers or distros whose group names differ beyond skipping them.

## Decisions

**1. A separate `Scripts/machine-user.sh`, not a flag on `machine-setup.sh`.**
Keeping account work out of the deploy keeps "provisioning only writes in `$HOME`" literally true
and keeps `--verify` non-privileged. Alternative rejected: `machine-setup.sh --user`, which would
make a script that today cannot touch accounts able to run `useradd` from the same entry point that
is safe to re-run any time.

**2. `--check` is the default; creation needs an explicit `--create`.**
A typo or an exploratory run must never create an account. Both modes take `--name NAME` (default
`hypr`) and an optional positional name, validated against `^[a-z_][a-z0-9_-]*$` before anything
runs. Alternative rejected: `--create` default with `--dry-run`, which puts the privileged path on
the shortcut.

**3. Required groups are data in the script, and only groups that exist on the system count.**
`wheel` (sudo, which `install.sh -i` needs), `video`/`render` (GPU and Hyprland DRM), `input`
(devices), `audio` (PipeWire), `storage` (udisks mounts). A group that the system does not define
at all is reported as a note, not a failure — a distro without `storage` is not a broken desktop;
a group that exists but the account lacks is a failure. Alternatives rejected: creating missing
groups ourselves (system policy, not ours to invent) and hardcoding a single group string (no way
to tell "absent here" from "not granted").

**4. Shell is chosen at creation only; an existing account keeps its shell.**
Creation passes `-s /bin/zsh` when `zsh` is listed in `/etc/shells`, otherwise `/bin/bash` and a
note. For an existing account the script prints the `chsh -s` command instead of running it,
because `Scripts/restore_shl.sh` owns shell selection during install and two owners of the same
setting is how shells get flipped back and forth.

**5. The password only ever goes through an interactive `sudo passwd`.**
No `chpasswd`, no `usermod -p`, no password in argv, environment or output. Without a terminal the
script skips the prompt and prints the command, matching the existing "human steps are named" rule
instead of inventing a random password that then lives in a transcript.

**6. The script refuses to run as `root`.**
Its checks are about a user's `$HOME`, session and sudo ability, which are meaningless for uid 0,
and provisioning afterwards must run as the account that owns `$HOME`. It is meant to be run by
the human account that has sudo (often the existing account on the notebook) with the target given
by name. Alternative rejected: silently switching to `SUDO_USER`, which hides which account is
being inspected.

**7. No state file, no marker, no `--json`.**
Every run reads the system (`getent passwd`, `id -nG`, `/etc/shells`, `visudo -c`-free
`sudo -n true`, `/usr/share/wayland-sessions/`) so a half-finished notebook is described by its
actual state, the same reasoning that made `--verify` compare the deez manifest rather than a
snapshot.

**8. Output reuses `print_log` from `Scripts/global_fn.sh` and the exit codes of
`machine-setup.sh`.** 0 = ready, 1 = something unmet or failed, 2 = bad usage. One vocabulary
(`[ok]`, `[chyba]`, `poznámka ::`) across both scripts.

## Risks / Trade-offs

- [Adding `wheel` grants sudo] → command line and output name the account being changed; nothing
  happens without `--create`; `--check` shows the group as missing rather than granting it.
- [Account created but no password, so SDDM cannot log in] → creation ends with the interactive
  `passwd` step, or prints the exact command when there is no terminal; `--check` reports "password
  not set" as unmet.
- [`hyprland.desktop` is absent before packages are installed] → expected on a fresh notebook;
  `--check` says so and the documented order (check → create → `install.sh -i -s` → deploy) makes
  that a normal intermediate state, not an error to work around.
- [`useradd` defaults differ between systems] → home, primary group, groups and shell are passed
  explicitly (`-m`, `-U` or `-g` when a group of the account name already exists, `-G`, `-s`), so
  `/etc/login.defs` cannot decide them for us.
- [Group list drifts from reality] → the list is one array at the top of the script with a comment
  pointing at `id hypr` as the reference; `--check` output shows every group, granted or not.
- [Someone runs it on the desktop machine by mistake] → `--create` on an existing account only
  adds missing groups and reports; it never deletes, renames or changes the shell.

## Migration Plan

No data migration. On the notebook the documented order becomes:

```bash
git clone https://github.com/evan70/HyDE.git ~/HyDE   # or the bundle
./Scripts/machine-user.sh --check                     # read-only
./Scripts/machine-user.sh --create                    # only when the check says it is missing
./Scripts/install.sh -i -s                            # packages, needs sudo
./Scripts/machine-setup.sh                            # deploy into that account's $HOME
```

Rollback of a created account: `sudo userdel -r hypr`. Removing group membership:
`sudo gpasswd -d hypr <group>`. Nothing else on the machine is touched, so no other rollback is
needed.
