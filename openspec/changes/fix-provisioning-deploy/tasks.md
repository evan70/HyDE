# Tasks

## 1. System-wide assets

- [x] 1.1 Teach `Scripts/machine-setup.sh` to classify the `PermissionError: Unable to prepare
  destination path: <path>` failures out of the deploy log it tees, treating a path that already
  exists as satisfied (a note) instead of failing the run; `Scripts/dots/archives.toml` stays
  untouched, because it is upstream-owned — verified in a stub tree (real `Scripts/` and
  `Configs/`, `install.sh` replaced by a stub printing the `PermissionError` line and exiting 1):
  deploy exits 0 and prints `poznámka :: systémové assety (1) už na stroji sú`, and `install_pst.sh`
  plus the human-step list still run
- [x] 1.2 Make a genuinely missing system asset visible: when the path is absent the run names it
  and prints the `sudo cp -a` command from the account's own copy, and exits non-zero — verified in
  the same stub tree with `/usr/local/share/icons/Nope-Missing`: exit 1, `[deploy] chýba ::
  /usr/local/share/icons/Nope-Missing`, and the run stops before the post-install step
- [ ] 1.3 Document the optional `sudo` install of the shared cursor and CJK fonts in `SYNC.md`
  (`sudo cp -r` from `~/.local/share/...` or the dot's own command), so "system copy" is a named
  human step rather than a silent gap

## 2. Colour state on a fresh account

- [x] 2.1 Reproduce the failure on a clean account and record what actually fails — reproduced on
  the notebook by removing `hypr` (`loginctl terminate-user` + `userdel -r`), re-creating it with
  `machine-user.sh --create` and running `machine-setup.sh`: the first run ends before the colour
  state because every cloned theme arrives without wallpapers (`No compatible wallpapers found`
  for all 12, `~/.config/hyde/wallpapers` empty → `Wallpaper cache was not generated`,
  `Theme colour state was not generated`, `Some dots were not deployed`, `install_pst.sh` skipped),
  and a second run finds them — so the missing-directory skips are a symptom, not the cause
- [ ] 2.5 Fix the wallpaper gap the reproduction exposed: a first deploy must leave the account
  with a wallpaper source (theme wallpapers fetched or a documented default), so `wallbash` can
  generate the colour state in the same run; verify by removing and re-creating a test account and
  confirming one `machine-setup.sh` run ends with `colors.conf` populated and exit 0
- [ ] 2.6 `Configs/.local/lib/hyde/theme.switch.sh` calls `hyde-shell` by bare name and dies with
  `hyde-shell: command not found` when run outside a login shell (ssh, `bash -c`, a unit without
  HyDE's PATH); resolve it from `$HOME/.local/bin` like the rest of the scripts, and verify with
  `bash -c 'PATH=/usr/bin:/bin theme.switch.sh'`
- [ ] 2.2 Change `Configs/.local/lib/hyde/color.set.sh` so an absent target directory is optional and
  cannot contribute to `render_failures`, and so `parallel`'s exit status is read as a job count (or
  ignored) instead of being summed into a failure total; keep a distinct non-zero return for a
  target that exists but cannot be written; verify on the throwaway account that the colour state is
  generated, `exit 0`, and `~/.config/hypr/themes/colors.conf` holds the theme's colours
- [ ] 2.3 Verify the failure path still fails: in a copy of `Configs/`, point one template at a
  directory that exists with a target that is not a regular file, run the theme switch and confirm
  `one or more templates failed` still appears and `theme.switch.sh` reports the error
- [ ] 2.4 Confirm the theme actually applies on the account: `theme.switch.sh` writes
  `colors.conf`, `kitty`/`dunst`/`hyprlock` targets render, and `hyde-shell` reports the chosen theme
  — verification on the running session

## 3. GTK 4 link over a distro file

- [x] 3.1 In `Configs/.local/lib/hyde/theme.switch.sh` (`link_gtk4_theme`), rename a pre-existing
  regular file to `<name>.pre-hyde` before creating the symlink, only when that name is free, and
  never delete it; verify on a throwaway account that has a real `~/.config/gtk-4.0/gtk.css`: the
  file ends up as `gtk.css.pre-hyde`, `gtk.css` is a symlink to the theme, and the switch reports no
  error — verified by sourcing the extracted function against a temp `$HOME` with a real `gtk.css`
  and a `settings.ini`: exit 0, `gtk.css` → theme file, `gtk.css.pre-hyde` holds the distro content,
  `settings.ini` untouched; a second call keeps the distro copy unrewritten and re-points the link,
  and the live `~/.local/lib/hyde/theme.switch.sh` is byte-identical to `Configs/`
- [ ] 3.2 Verify the ordinary path is unchanged: on a fresh `~/.config/gtk-4.0` with no files, and
  on the existing symlink layout, the link is created or migrated exactly as before, and
  `settings.ini` is still never linked, overwritten or removed

## 4. Directory independence

- [x] 4.1 Add `cd "$HOME"` to `Scripts/machine-setup.sh` after the guards, so the deploy runs from
  the account's home; verify by running it as `hypr` from `/home/dany` (a directory `hypr` cannot
  read) and confirming there is no `Failed to restore initial working directory` and that every dot
  is deployed — verified in the stub tree started from `/tmp`: the stub `install.sh` records
  `pwd=/home/hypr`, so the deploy and its sub-scripts run from the account's home regardless of the
  caller's directory
- [ ] 4.2 Verify the same run started from the checkout and from `$HOME` produces an identical
  manifest (`~/.local/share/deez/dots`) and `--verify` passes in both cases

## 5. Documentation and checks

- [ ] 5.1 Update `SYNC.md`: what a clean deploy prints, the optional system-wide asset step, and the
  `gtk.css.pre-hyde` behaviour when a previous desktop left a real file
- [ ] 5.2 Move the four entries from `### Known issues` in `CHANGELOG.md` into `### Fixed` with the
  cause and the fix, once the behaviour is verified — three are already moved (system assets, GTK 4
  link, directory independence); the `wallbash` entry stays in `### Known issues` until task 2 is done
- [ ] 5.3 Run the fork checks (`bash -n` over `*.sh`, `luac5.4 -p`, `.github/scripts/check_python.py`,
  `.github/scripts/check_jsonc.py`) and `openspec validate fix-provisioning-deploy --strict`; every
  command must exit 0
- [ ] 5.4 Re-run the documented notebook flow end to end on `probook` with the second account —
  `machine-setup.sh`, then `--verify` — and record in `NOTES.md` that the deploy exits 0

## Workflow follow-up

- Commit and push, then wait for `Fork checks` and `Tests` on the pushed commit.
- Archive the change with `openspec archive fix-provisioning-deploy` and confirm
  `openspec validate --specs --strict` still passes.
