# Tasks

## 1. Inventory and guard rails

- [ ] 1.1 List what deployment covers and what stays manual (packages, GitHub sign-in, theme choice) in `Scripts/machine-setup.sh` as the comment block at the top, and verify it names every step in `SYNC.md`
- [ ] 1.2 Resolve the checkout with `realpath`, refuse to run when `Configs/` or `Scripts/install.sh` is missing, and print the absolute paths the run will touch — verified by running the script from a directory without `Configs/` and seeing it exit non-zero with that message
- [ ] 1.3 Check the upstream flags the script relies on (`install.sh --help` contains `-r`/`--restore`) and fail loudly when they changed — verified by pointing the check at a stub `install.sh` without the flag

## 2. Deploy mode

- [ ] 2.1 Implement the deploy path: `install.sh -r`, then `install_pst.sh`, then the OpenSpec CLI check, and verify on this machine that a re-run leaves `git status` clean and the session unchanged
- [ ] 2.2 Print the files that differ between `Configs/` and their live paths *before* invoking `install.sh -r`, and verify with a deliberately edited live file that the run mentions it
- [ ] 2.3 Never rewrite `~/.config/hyde/config.toml`, `~/.config/gtk-4.0/settings.ini` or the SDDM theme selection; verify by editing a value in `config.toml`, running the script, and reading it back unchanged
- [ ] 2.4 Print the human steps that remain (log in once, pick a theme, `gh auth login`) and verify the output on a machine where none of them is done

## 3. Verify mode

- [ ] 3.1 Implement `--verify`: compare every git-tracked file under `Configs/` with its live path, summarise per directory, name the first mismatch and exit non-zero — verified by touching a live file and seeing that file named
- [ ] 3.2 Add the session checks (Waybar unit active, Hyprland running, SDDM theme directory present, `openspec --version` works) and verify each failure path by stopping one service at a time
- [ ] 3.3 Confirm `--verify` changes nothing: run it twice and compare `git status`, the live tree and `systemctl --user is-active` before and after
- [ ] 3.4 Document `SYNC.md` with the transport (bundle or clone), the commands and what each printed human step means, and verify the documented commands run as written on this machine

## 4. Integration

- [ ] 4.1 Dry-run the whole flow against a throwaway `$HOME` (temp dir with a copy of `Configs/`) and verify the script does not depend on this machine's leftovers
- [ ] 4.2 Add the changelog entry describing the new entry point and verify it reads without the ticket context
- [ ] 4.3 Confirm both CI workflows stay green on the push that lands this (fork checks plus the upstream suite)
