# Design

## Context

See proposal.md — Why. What exists today:

- `Configs/` mirrors `$HOME`; `Scripts/install.sh -r` deploys it into the live paths, and
  `Scripts/install_pst.sh` does the post-install steps (SDDM theme from `Source/arcs/`, service
  enablement). Both are upstream-owned and already understand this fork's layout.
- The repository now carries the agent notes (`AGENTS.md`, `NOTES.md`) and the OpenSpec planning
  tree, so those no longer need copying by hand.
- Outside the repository: installed packages (pacman, `install.sh` owns that), the OpenSpec CLI in
  `~/.local/bin/openspec`, a GitHub sign-in for `git push`, the login theme choice in
  `/etc/sddm.conf.d/`, and the per-user files under `~/.config` once they diverge from `Configs/`.

Transport between the machines is a `git bundle` today (82 MB, complete history) or a clone of
`evan70/HyDE`; the second machine may not have GitHub credentials yet, which is why the bundle
stays an option.

## Goals / Non-Goals

**Goals:**
- One command for "this checkout is now a working session", and one check-only command that says
  whether a machine already matches.
- Keep the transport out of the script: bundle and clone must both work.
- Make the human-only steps explicit in the output.

**Non-Goals:**
- Installing packages or partitioning (that is `install.sh`'s job, and it is interactive).
- Distributing secrets or signing in for the user.
- Choosing a theme; the script reports that a choice is pending instead.
- Synchronising back from the second machine (that stays `git`).

## Decisions

**One wrapper script, not a new installer.** `Scripts/machine-setup.sh` calls the upstream scripts
instead of reimplementing them: `install.sh -r`, then `install_pst.sh`. Alternatives: extending
`install.sh` (rejected — upstream-owned, conflicts on every update); a Nix/Ansible/chezmoi layer
(rejected — a new dependency for two machines, while the repo already ships a working installer).

**Verify is a separate mode of the same script.** `--verify` shares the file list with the deploy
path, so the check cannot drift from what deployment does. It compares `Configs/**` against `$HOME`
byte for byte, then checks the Waybar unit, the SDDM theme in use and the OpenSpec CLI; the first
mismatch is named, and the exit code is non-zero.

**Idempotence by asking, not by overwriting.** Files the user may have edited (`config.toml`,
`settings.ini`, theme selection) are never rewritten by the script; where the deployed file and the
live file differ, `--verify` reports the difference and leaves the decision to the user, and the
deploy path prints which files it would replace before it runs `install.sh -r`.

**AGENTS.md and NOTES.md live in the repository.** Copying them per machine was the step most often
forgotten; `~/AGENTS.md` and `~/NOTES.md` are symlinks into the checkout on this machine, and the
second machine gets them from the clone. Alternative: keep them in `$HOME` and copy — rejected,
that is the manual step this change removes.

## Risks / Trade-offs

- **`install.sh -r` is interactive** (theme picker, prompts) → the script runs it with the
  documented flags, and any remaining prompt is answered by the user rather than piped in.
- **A wrong `$HOME` would rewrite the wrong tree** → the script resolves the checkout with
  `realpath`, refuses to run when `Configs/` is missing, and prints the paths it will touch first.
- **Byte-for-byte comparison flags harmless differences** (generated colors, timestamps inside
  files) → only files tracked by git are compared, and the check reports counts per directory
  before failing on the first mismatch, so a single generated file does not look like a broken
  machine.
- **The script depends on `install.sh` flags that upstream may rename** → the flags are checked at
  start (`install.sh --help`), and the script fails loudly instead of silently skipping a step.
- **Bundle and clone can drift apart** (bundle built from a different commit) → the script prints
  `git rev-parse --short HEAD` and refuses `--verify` when the checkout is behind its bundle
  marker, which the sync step writes next to the bundle.

## Migration Plan

1. Land the script and `SYNC.md` on `master` (this machine still uses the manual steps).
2. On the second machine: get the checkout (bundle or clone), run the script, follow the printed
   human steps, then `git push` once credentials exist.
3. Rollback is `git revert`; nothing on the running desktop depends on the new script.
