# Spec Delta

## MODIFIED Requirements

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

#### Scenario: System-wide asset the account may not write is already present
- **WHEN** a dot installs something under `/usr/local/share`, the account cannot write there, and
  that path already holds the asset from an earlier install
- **THEN** the deploy reports it as a note, nothing is missing, and the run succeeds

#### Scenario: System-wide asset is genuinely absent
- **WHEN** the path under `/usr/local/share` does not hold the asset and the account cannot create it
- **THEN** the run names the asset and the command that installs it as a step for a human, and does
  not report the machine as ready

#### Scenario: Account that never had this desktop
- **WHEN** the deploy runs on an account whose `$HOME` never held a HyDE theme, so theme targets such
  as `~/.config/hypr/animations/theme.conf` and `~/.config/vim/colors/wallbash.vim` have no
  directory yet
- **THEN** those templates are skipped as optional, the colour state for the chosen theme is
  generated and applied, and the run reports success instead of an incomplete colour state

#### Scenario: A template that is required and cannot be written
- **WHEN** a template's target directory exists but the file cannot be written, because it is not a
  regular file or the write fails
- **THEN** the run reports that template as a failure and the colour state as incomplete

#### Scenario: Pre-existing file where the theme wants a link
- **WHEN** `~/.config/gtk-4.0/gtk.css` exists as a regular file left by the previous desktop
- **THEN** that file is kept beside the link (moved aside once) and the link is created, so the
  theme switch does not fail and the user's file is not lost

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

#### Scenario: System-wide asset needs root
- **WHEN** a system-wide asset could not be installed by the deploy and is not present
- **THEN** the output names the missing path and the command that installs it, instead of leaving the
  failure buried in a dot log

## ADDED Requirements

### Requirement: Deployment does not depend on the starting directory

The entry point SHALL deploy the complete tree regardless of the working directory it is started
from, because an account can run it from a directory it cannot read.

#### Scenario: Started inside another account's home
- **WHEN** the entry point runs as one account but was started in a directory that account cannot
  read, such as another account's `$HOME`
- **THEN** every deployed file is written and no step fails on the working directory

#### Scenario: Started from the checkout
- **WHEN** the entry point is started from the checkout with no other path involved
- **THEN** the deployed result is identical to the case above
