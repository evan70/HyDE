# Spec Delta

## ADDED Requirements

### Requirement: Account readiness is reported without changing anything

The repository SHALL offer a read-only check of the account that is meant to run this desktop, naming each unmet condition and exiting non-zero while any remains.

#### Scenario: Account missing on a fresh machine

- **WHEN** the check runs on a machine that has no account for this desktop yet
- **THEN** it reports the account as missing, names the remaining conditions as unmet and exits non-zero

#### Scenario: Account ready for provisioning

- **WHEN** the account exists, is not `root`, may use `sudo`, owns a writable `$HOME`, carries the groups this desktop uses, has a login shell listed in `/etc/shells` and the login manager offers a Hyprland session
- **THEN** the check reports every condition as satisfied and exits zero

#### Scenario: Check never needs privileges

- **WHEN** the check runs as an ordinary user who cannot use `sudo` without a password
- **THEN** it reports the privilege condition as unmet and still reports the conditions it could read

### Requirement: A missing account can be created on request

Account creation SHALL happen only when it is explicitly requested, SHALL apply only to the account named on the command line, and SHALL be idempotent.

#### Scenario: Creating the account

- **WHEN** creation is requested for an account that does not exist
- **THEN** the account is created with a home directory, the groups this desktop needs and a login shell, and the result is reported as created

#### Scenario: Running creation twice

- **WHEN** creation is requested for an account that already exists
- **THEN** nothing about the account is recreated, only missing group membership is added, and the run reports success

#### Scenario: Password is handed to an interactive prompt

- **WHEN** the account has just been created
- **THEN** the password is set through an interactive prompt that never echoes it, no password appears on a command line, and without a terminal the run prints the exact command that would set it

#### Scenario: Other accounts stay untouched

- **WHEN** a machine already has other accounts
- **THEN** creation changes no home directory, group, shell or password of those accounts

### Requirement: An existing account is not rewritten

Creation SHALL NOT rename an existing account or change its login shell, because provisioning afterwards mirrors the repository into whatever shell and `$HOME` the account already has.

#### Scenario: Existing account with a different shell

- **WHEN** creation runs for an existing account whose shell is not the one this desktop expects
- **THEN** the shell is left as it is and the run prints the command that would change it
