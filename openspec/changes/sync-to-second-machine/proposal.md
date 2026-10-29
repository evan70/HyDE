# Proposal

## Why

Setting up this fork on a second machine is a checklist that lives in chat history, `NOTES.md`
and memory: clone or fetch the bundle, run `Scripts/install.sh -r`, run `Scripts/install_pst.sh`,
pick the SDDM theme, install the OpenSpec CLI, fix up the GTK4 theme links — and only at the next
login does `login-report` say whether something was missed. The pieces exist; there is no single
entry point, and no way to ask "is this machine actually in the state the repository describes?".

## What Changes

- One entry point `Scripts/machine-setup.sh` that takes an existing checkout to a ready session:
  it runs the installer steps this fork needs (`install.sh -r`, `install_pst.sh`), reports the
  OpenSpec CLI, and prints what still needs a human (login, theme choice, `gh auth`).
- A `--verify` mode that changes nothing and reports each prerequisite — repository commit, live
  files matching what deployment wrote, Waybar unit, SDDM theme, OpenSpec CLI — with a non-zero
  exit when a deployed file does not match.
- A `SYNC.md` checklist in the repository, so the transport (bundle or clone) is documented next to
  the code instead of in chat.
- The script is idempotent: a second run on an already provisioned machine changes nothing and
  never overwrites the user's live `settings.ini`, `config.toml` or theme choice.
- It writes only inside the `$HOME` of the account that runs it, so an existing account on the
  machine keeps its own dotfiles; the SDDM theme is written only when none is configured yet.

Explicitly out of scope: installing Arch or packages from scratch (`install.sh` already owns that),
distributing secrets, choosing a theme automatically, and replacing `install.sh` — it is
upstream-owned and must stay unmodified so upstream updates still apply.

## Capabilities

### New Capabilities
- `machine-provisioning`: bringing a checkout to a working session on another machine, and
  reporting whether a machine already matches the repository.

### Modified Capabilities
<!-- none: no existing spec describes provisioning today -->

## Impact

- `Scripts/machine-setup.sh` (new), `Scripts/machine-setup-verify.py` (new), `Scripts/` helpers it
  reuses (`install.sh`, `install_pst.sh`, `global_fn.sh`), `SYNC.md` (new), `CHANGELOG.md`.
- Runs `sudo` for the SDDM theme step; everything else stays in the user's `$HOME`.
- Touches the upstream master/dev drift only by depending on `install.sh` flags that exist on
  master today (`-r`, `--restore`); if upstream changes them, this script must follow, not fork them.
- No change to the behaviour of a provisioned desktop: no bind, module or service is altered.
