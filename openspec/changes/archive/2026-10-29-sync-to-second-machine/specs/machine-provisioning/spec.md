# Spec Delta

## Purpose

Brings a checkout of this fork to a working session on another machine, and reports whether a
machine already matches what the repository describes.

## ADDED Requirements

### Requirement: One command provisions a checkout

A checkout of this fork SHALL be brought to a ready session state by one documented entry point,
without a manual checklist.

#### Scenario: Fresh second machine
- **WHEN** the repository is present on a machine where the desktop was never set up
- **THEN** the entry point deploys the live configuration, applies the post-install steps this
  fork needs, and leaves the session services running

#### Scenario: Already provisioned machine
- **WHEN** the entry point runs on a machine that is already in the described state
- **THEN** it changes nothing and reports that the machine is up to date

#### Scenario: Successful deploy is not reported as a failure
- **WHEN** the installer finishes but its closing reboot question receives no answer
- **THEN** the entry point still reports success and no deploy step is skipped

### Requirement: Verification reports without changing anything

The entry point SHALL provide a check-only mode that inspects the machine and exits non-zero when
a deployed file differs from the repository.

#### Scenario: Live copy differs from the repository
- **WHEN** a file that deployment writes with `sync` has no identical counterpart at its live path
- **THEN** the check names that file, summarises the difference per directory and fails

#### Scenario: Everything matches
- **WHEN** every deployed file matches, the session services run and the login manager uses a
  shipped theme
- **THEN** the check reports success and exits zero

#### Scenario: Files the user or the theme owns
- **WHEN** a file deployed with `preserve` differs, or a live file rewritten by the theme engine or
  a running application differs
- **THEN** the check lists it as a note and does not fail, because deployment never promised to
  keep those identical

#### Scenario: Files deployment deliberately ignores
- **WHEN** a tracked file under `Configs/` is not deployed at all (`__pycache__`, `.editorconfig`,
  `share/hyde/schema`)
- **THEN** the check does not report it as missing

### Requirement: Human steps are named, not assumed

Anything the entry point cannot do itself SHALL be printed as a short list of steps for the user,
rather than silently skipped.

#### Scenario: Sign-in and theme choice still needed
- **WHEN** provisioning finishes on a machine that has no GitHub sign-in and no login theme chosen
- **THEN** the output names those two steps and stops without guessing a choice

#### Scenario: Missing planning CLI
- **WHEN** the OpenSpec CLI is not installed
- **THEN** the output names it with the exact install command and provisioning continues, because
  the desktop does not depend on it

### Requirement: User settings survive re-provisioning

Provisioning SHALL NOT overwrite files the user owns outside the deployed configuration tree, in
particular GTK `settings.ini`, `~/.config/hyde/config.toml` and the login theme selection.

#### Scenario: Second run after the user changed a setting
- **WHEN** the user edited `~/.config/hyde/config.toml` and provisioning runs again
- **THEN** the edited value is still there afterwards

### Requirement: Existing accounts are left alone

Provisioning SHALL only write inside the `$HOME` of the account that runs it; the single
system-wide write (the SDDM theme) SHALL happen only when the machine has none configured.

#### Scenario: Machine with an older account
- **WHEN** a new account provisions the desktop on a machine where another account already exists
- **THEN** that account's dotfiles are untouched, and the login theme is written only when no HyDE
  theme is configured yet
