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
  fork needs, and ends with the session services running

#### Scenario: Already provisioned machine
- **WHEN** the entry point runs on a machine that is already in the described state
- **THEN** it changes nothing and reports that the machine is up to date

### Requirement: Verification reports without changing anything

The entry point SHALL provide a check-only mode that inspects the machine and exits non-zero when
the machine differs from the repository.

#### Scenario: Live copy differs from the repository
- **WHEN** a file under `Configs/` has no identical counterpart at its live path under `$HOME`
- **THEN** the check names that file and fails

#### Scenario: Everything matches
- **WHEN** every deployed file matches, the session services run and the login manager uses a
  shipped theme
- **THEN** the check reports success and exits zero

### Requirement: Human steps are named, not assumed

Anything the entry point cannot do itself SHALL be printed as a short list of steps for the user,
rather than silently skipped.

#### Scenario: Sign-in and theme choice still needed
- **WHEN** provisioning finishes on a machine that has no GitHub sign-in and no login theme chosen
- **THEN** the output names those two steps and stops without guessing a choice

### Requirement: User settings survive re-provisioning

Provisioning SHALL NOT overwrite files the user owns outside the deployed configuration tree, in
particular GTK `settings.ini`, `~/.config/hyde/config.toml` and the login theme selection.

#### Scenario: Second run after the user changed a setting
- **WHEN** the user edited `~/.config/hyde/config.toml` and provisioning runs again
- **THEN** the edited value is still there afterwards
