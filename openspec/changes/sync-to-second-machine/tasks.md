# Tasks

## 1. Inventory and guard rails

- [x] 1.1 List what deployment covers and what stays manual (packages, GitHub sign-in, theme choice) in `Scripts/machine-setup.sh` as the comment block at the top, and verify it names every step in `SYNC.md`
- [x] 1.2 Resolve the checkout with `realpath`, refuse to run when `Configs/` or `Scripts/install.sh` is missing, and print the absolute paths the run will touch — verified by running a copy of the script from `/tmp/hyde-guard/Scripts` (no `Configs/`): exit 1, `CHYBA: /tmp/hyde-guard nie je checkout tohto forku`
- [x] 1.3 Check the upstream flags the script relies on (`install.sh --help` contains `-r`/`--restore`) and fail loudly when they changed — verified with a stub `install.sh` that has no `--restore`: exit 1, `install.sh už neponúka -r/--restore`

## 2. Deploy mode

- [x] 2.1 Implement the deploy path: `install.sh -r`, then `install_pst.sh`, then the OpenSpec CLI check, and verify on this machine that a re-run leaves `git status` clean and the session unchanged — second run exit 0, no file rewritten, `git status` unchanged, Waybar unit still active
- [x] 2.2 Print the files that differ between `Configs/` and their live paths *before* invoking `install.sh -r`, and verify with a deliberately edited live file that the run mentions it — first run printed `prepíše sa :: 1 … .local/lib/hyde/logoutlaunch.sh`
- [x] 2.3 Never rewrite `~/.config/hyde/config.toml`, `~/.config/gtk-4.0/settings.ini` or the SDDM theme selection; verify by editing a value in `config.toml`, running the script, and reading it back unchanged — `config.toml`, `settings.ini` and the theme colours stay in deez's `preserve` bucket, and both deploys reported them as `nechá sa` and left the live values alone; `install_pst.sh` printed `sddm is already configured`
- [x] 2.4 Print the human steps that remain (log in once, pick a theme, `gh auth login`) and verify the output on a machine where none of them is done — printed on every deploy and in the dry run against an empty `$HOME`

## 3. Verify mode

- [x] 3.1 Implement `--verify`: compare every deployed file with its live path, summarise per directory, name the first mismatch and exit non-zero — verified by editing the live `logoutlaunch.sh` (exit 1, file named) and by the missing `custom-swaync.jsonc` entry before the layout caught up
- [x] 3.2 Add the session checks (Waybar unit active, Hyprland running, SDDM theme directory present, `openspec --version` works) and verify each failure path by stopping one service at a time — all four pass on the running session; a stubbed `pgrep` makes the Hyprland check print `[chyba]` and the run exit 1, `NO_MANIFEST` exits 1 as well
- [x] 3.3 Confirm `--verify` changes nothing: run it twice and compare `git status`, the live tree and `systemctl --user is-active` before and after — both runs exit 0, no file under `~/.config`, `~/.local/share/hyde`, `~/.local/lib/hyde` newer than the marker
- [x] 3.4 Document `SYNC.md` with the transport (bundle or clone), the commands and what each printed human step means, and verify the documented commands run as written on this machine — `machine-setup.sh`, `--verify` and `--dry-run` run as written; `install.sh -i -s` is the documented bare-machine step and was not run here

## 4. Integration

- [x] 4.1 Dry-run the whole flow against a throwaway `$HOME` (temp dir with a copy of `Configs/`) and verify the script does not depend on this machine's leftovers — `HOME=/tmp/hyde-home ./Scripts/machine-setup.sh --dry-run` exits 0, writes only under the temp home, and `--verify` there reports `NO_MANIFEST`
- [x] 4.2 Add the changelog entry describing the new entry point and verify it reads without the ticket context
- [x] 4.3 Confirm both CI workflows stay green on the push that lands this (fork checks plus the upstream suite) — `49ee7d0`: Fork checks success, Tests success (27 min, 60/60 cases + coverage)
