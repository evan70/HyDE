# Design

## Context

The four failures were observed on the notebook `probook` on 2026-10-31, in the deploy of a second
account (`hypr`) on a machine that already had another account (`dany`) provisioned. The desktop
worked afterwards in all four cases; only the reporting was wrong, except for the GTK 4 link, which
needed a manual `mv` before the next run could pass. The relevant code today:

- `Scripts/dots/archives.toml` describes the cursor, hyprcursor and CJK font with two file entries
  each: one `sync` into `${XDG_DATA_HOME}`, one `tarball` into `/usr/local/share/...`. deez-dots
  performs the second as the invoking account, so it aborts that dot with `PermissionError:
  Unable to prepare destination path: /usr/local/share/icons/Bibata-Modern-Ice`, and `install.sh -r`
  ends with `ERROR :: Some dots were not deployed`.
- `Configs/.local/lib/hyde/color.set.sh` renders templates through GNU `parallel`. `fn_wallbash`
  returns 0 when the target's directory is absent (`skip 'missing directory'`), but the caller
  accumulates `render_failures=$((render_failures + $?))` from `parallel`'s exit status, which is
  the number of failed jobs, and exits 1 when that total is non-zero, printing `one or more
  templates failed, the colour state is incomplete`. `theme.switch.sh` maps that to
  `[theme] error :: generating the colour state for <theme> failed with 4`.
- `Configs/.local/lib/hyde/theme.switch.sh` (`link_gtk4_theme`) removes only symlinks from
  `~/.config/gtk-4.0` before creating the new ones, so a real `gtk.css` from a preinstalled desktop
  (CachyOS ships one) makes `ln -s` fail with `File exists`.
- `Scripts/machine-setup.sh` never changes directory: it computes `scrDir`/`cloneDir` with
  `realpath` but leaves the caller's cwd in place, so `find` steps inside `install.sh -r` and the
  theme patch report `Failed to restore initial working directory /home/<other>: Permission denied`
  and part of the dots are not written.

## Goals / Non-Goals

**Goals:**

- A deploy that finished its work exits zero, and one that did not names what is missing.
- The same result whether the entry point is started from the checkout, from `$HOME`, or from a
  directory belonging to another account.
- No manual `mv` before a re-run, and no user file silently deleted.
- Small, localised upstream edits so `HyDE-Project/HyDE` merges stay cheap.

**Non-Goals:**

- Installing system-wide assets with `sudo` from the deploy, or running the whole deploy as `root`.
- Changing what the three system dots contain, or where the desktop reads cursors and fonts from.
- Fixing the SDDM theme and login-manager work (already done in `8696782`).
- Making `--verify` depend on privileges: it stays readable as an ordinary account.

## Decisions

**1. `machine-setup.sh` classifies the permission failures; `archives.toml` stays as it is.**
The wrapper tees the deploy output, and when `install.sh -r` returns non-zero it reads
`Unable to prepare destination path: <path>` out of that log. Each such path that already exists is
reported as a note and counts as satisfied; only a path that is genuinely absent fails the run, and
then the `sudo cp -a` command that installs it from the account's own copy is printed. Alternatives
rejected: deleting the three `/usr/local/share` entries from `Scripts/dots/archives.toml`, because
that file is upstream-owned and this fork keeps its diff to `install_pst.sh`, `color.set.sh` and
`theme.switch.sh`; and `sudo` inside the dot, which would turn a user deploy into a privileged one
and prompt mid-run.

**2. An absent target directory is optional, a failed write is not.**
`fn_wallbash` keeps returning 0 for `skip 'missing directory'` and returns a distinct non-zero code
only for real write failures (target exists but is not a regular file, or `mv` fails). The caller
stops summing raw `parallel` exit codes — which are job counts, so three skipped templates could read
as `4` failures — and instead counts jobs that exited with the write-failure code. The colour state
is declared incomplete only when at least one required template failed.

**3. Missing optional targets are not created.**
The deploy does not `mkdir` `~/.config/spicetify/Themes/Sleek` or `~/.config/vim/colors` on an
account that has neither application: empty config trees for uninstalled apps are noise the user
then has to discover and delete. Once the app is installed, its dot creates the directory and the
template renders on the next theme switch.

**4. `link_gtk4_theme` moves a pre-existing regular file aside once.**
Before linking, a target that exists as a regular file is renamed to `<name>.pre-hyde` next to the
link (never deleted, and only when the `.pre-hyde` name is free), then the symlink is created. This
matches the existing rule for `settings.ini`, which is already never overwritten. Alternative
rejected: forcing the link with `ln -sf`, which would delete a file the user's previous desktop
wrote.

**5. `machine-setup.sh` runs from `$HOME`.**
One `cd "$HOME"` after the guard section, so every relative path and every `find` inside the
sub-scripts starts in a directory the account can read. This is cheaper and more predictable than
exporting a `PWD` for the children or copying the checkout into `$HOME`.

## Risks / Trade-offs

- [Dropping the `/usr/local/share` entries loses system-wide cursors for other accounts] → the
  desktop reads `${XDG_DATA_HOME}`, so the account that runs the deploy is unaffected; `SYNC.md`
  documents the optional `sudo` command for machines that need the shared copy, and the sdmm/GTK
  themes do not reference `/usr/local/share` directly.
- [A genuinely broken template could now be skipped as "optional"] → skip stays limited to a missing
  *directory*; a target whose directory exists but cannot be written still fails and is named.
- [Renaming `gtk.css` surprises a user who wanted the distro file] → the file is kept on disk as
  `gtk.css.pre-hyde`, the rename happens once, and the deploy output names both paths.
- [`cd "$HOME"` could mask a caller who expects relative output paths] → all output paths are
  absolute or `$HOME`-relative already, and `--verify` prints `checkout`/`domov`, so nothing depends
  on the caller's cwd.

## Migration Plan

No data migration. A machine that already ran the broken deploy needs one re-run
(`Scripts/machine-setup.sh`), which renames the pre-existing `gtk.css` once and finishes the dots.
The three system dots are removed from the manifest on that run; the assets under
`/usr/local/share` are left exactly as they are.
