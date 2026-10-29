# Design

## Context

See proposal.md — Why. What exists today:

- `Configs/` mirrors `$HOME`. Deployment is deez-dots: `install.sh -r` runs
  `deez … dots --deploy` with `Scripts/dots-groups/{core,extra,shell}.toml`, and deez writes a
  manifest of every deployed file (`src`, `dst`, `action`) to `~/.local/share/deez/dots/*.toml`.
  `Scripts/install_pst.sh` does the post-install steps (SDDM theme, shell, file manager, flatpak).
- `Scripts/restore_cfg.psv` and `restore_cfg.sh` are the legacy path; `install.sh` no longer calls
  them, so their `S`/`O`/`P` flags say nothing about what a modern restore actually writes.
- The repository carries the agent notes (`AGENTS.md`, `NOTES.md`) and the OpenSpec planning tree,
  so those travel with the checkout instead of being copied by hand.
- Outside the repository: installed packages (the restore re-checks and installs core deps, but a
  bare machine wants `install.sh -i -s` once), a GitHub sign-in for `git push`, the SDDM theme and
  the per-user files under `~/.config` once they diverge from `Configs/`.

Transport is `git clone` from `evan70/HyDE`; a `git bundle` remains documented as the offline
alternative, so the script itself knows nothing about either.

## Goals / Non-Goals

**Goals:**
- One command for "this checkout is now a working session", and one check-only command that says
  whether a machine already matches.
- Keep the transport out of the script: bundle and clone must both work.
- Make the human-only steps explicit in the output.
- Touch only the account that runs it.

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

**Verify reads deez's manifest, not the tracked tree.** `Scripts/machine-setup-verify.py` compares
the live files with the `src`/`dst`/`action` records deez wrote at deploy time. This is the only
list that cannot drift from deployment: files deez ignores by design (`__pycache__`,
`.editorconfig`, `share/hyde/schema`, the `I` entries of the old psv) would otherwise fail forever,
and the legacy psv contains paths that are no longer deployed at all. Alternative: compare all
`git ls-files Configs` with `$HOME` (rejected — 666 tracked files against 1 300 deployed entries,
with a third of them legitimately different); parsing the dots TOMLs and reimplementing deez's
matching rules (rejected — a second implementation of the thing being checked).

**Four buckets, one failure class.** Each file is `deploy` (action `sync`: wrong content or missing
is a failure), `user` (action `preserve`: the account owns it, reported as a note), `generated`
(the theme engine or a running application rewrites it, listed explicitly in the verifier), or
`stale` (the repository dropped it; the next deploy removes it). Without this split, a single theme
switch would make the check fail on twelve files the user never touched.

**A separate helper, not a heredoc.** The comparison lives in
`Scripts/machine-setup-verify.py`, driven by the shell script; it needs TOML parsing, and the repo
already pairs shell wrappers with Python helpers. It prints TSV and changes nothing; the exit
status belongs to the shell entry point.

**Idempotence by asking, not by overwriting.** Files the user may have edited (`config.toml`,
`settings.ini`, theme selection) are deployed with `preserve`; where the live file differs,
`--verify` reports it and leaves the decision to the user, and the deploy path prints which files it
would replace before it runs `install.sh -r`.

**Closed stdin is not a failure.** `install.sh -r` ends with "do you want to reboot? (y/N)". With
stdin closed, `read` fails, `set -e` aborts, and an otherwise successful deploy is reported as an
error and `install_pst.sh` never runs (observed on the first live run). The wrapper therefore hands
the terminal to these scripts when there is one, and an endless blank line when there is not — for
these prompts that means "no / keep the default", which is what an unattended run wants.

**Existing accounts stay untouched.** The only write outside the invoking account's `$HOME` is the
SDDM theme from `install_pst.sh`, and that script skips it when the machine already has
`/etc/sddm.conf.d/backup_the_hyde_project.conf`. New accounts on the laptop are therefore safe to
provision while an older account keeps its own dotfiles; the login screen is shared by nature.

**OpenSpec CLI is checked, not curl-piped.** The proposal originally had the script install it. A
single static binary fetched from a pipe by a provisioning script is a supply-chain decision that
belongs to the person, so the script reports the version or prints the pinned install command and
carries on: the desktop does not need the planning CLI.

**AGENTS.md and NOTES.md live in the repository.** Copying them per machine was the step most often
forgotten; `~/AGENTS.md` and `~/NOTES.md` are symlinks into the checkout on this machine, and the
second machine gets them from the clone.

## Risks / Trade-offs

- **`install.sh -r` is interactive** (theme picker, flatpak list, reboot) → the script runs it with
  the terminal attached, and any prompt is answered by the user, blank-line defaults only when
  there is no terminal.
- **A wrong `$HOME` would rewrite the wrong tree** → the script resolves the checkout with
  `realpath`, refuses to run when `Configs/` is missing, and prints the paths it will touch first.
- **A stale manifest hides a repo-side addition** — a file added to `Configs/` after the last
  deploy is not in the manifest, so `--verify` alone will not announce it; the next deploy adds it.
  Accepted: the check answers "did anything overwrite what was deployed", and "deploy the newer
  commit" is a deploy, not a verification, job.
- **The generated-file list is explicit** → a newly themed file that is not on the list shows up as
  a failure once and is added to `RUNTIME_GENERATED`; the alternative (a heuristic) would silently
  hide real drift.
- **`install.sh` flags and the deez manifest format are upstream-owned** → the flags are checked at
  start (`install.sh --help`), and the verifier skips manifest entries it does not understand, so a
  format change degrades to "fewer files checked" rather than a wrong verdict.

## Migration Plan

1. Land the script, the verifier and `SYNC.md` on `master`.
2. On the second machine: clone the fork, run `install.sh -i -s` once if it is bare, run
   `machine-setup.sh`, follow the printed human steps, then `git push` once credentials exist.
3. Rollback is `git revert`; nothing on the running desktop depends on the new script, and every
   overwritten file is kept in `~/.config/cfg_backups/<date>/`.
