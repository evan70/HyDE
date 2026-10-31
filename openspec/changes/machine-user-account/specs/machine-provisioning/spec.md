# Spec Delta

## ADDED Requirements

### Requirement: Account readiness is reported without changing anything

The repository SHALL offer a read-only check of the account that is meant to run this desktop, naming each unmet condition and exiting non-zero while any remains.

#### Scenario: Account missing on a fresh machine

- **WHEN** the check runs on a machine that has no account for this desktop yet
- **THEN** it reports the account as missing, names the remaining conditions as unmet and exits non-zero

#### Scenario: Account ready for provisioning

- **WHEN** the account exists, is not `root`, may use `sudo`, owns a writable `$HOME`, carries the groups this desktop uses, has a login shell listed in `/etc/shells`, the machine starts SDDM and the login manager offers a Hyprland session
- **THEN** the check reports every condition as satisfied and exits zero

#### Scenario: A different login manager still starts

- **WHEN** the account is otherwise ready but the machine still starts another login manager, such as the LightDM that came with XFCE
- **THEN** the check reports that condition as unmet, names the login manager that starts and prints the commands that switch the machine to SDDM

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

### Requirement: The account name is a default, not a requirement

The desktop SHALL be installable into any existing account named on the command line, so that it stays an addition to a machine that already runs another desktop rather than a fixed identity of its own.

#### Scenario: Adopting the account a person already uses

- **WHEN** the check and creation run with the name of the account that is already in use on that machine
- **THEN** that account keeps its home directory, shell and password, gains only the missing groups, and receives the desktop's files inside its own `$HOME`

#### Scenario: No name given on a machine that already has an account

- **WHEN** no name is given, because the script runs from the account that already uses the machine
- **THEN** that account is the target and nothing is created, and the output states which name it picked

### Requirement: An existing account is not rewritten

Creation SHALL NOT rename an existing account or change its login shell, because provisioning afterwards mirrors the repository into whatever shell and `$HOME` the account already has.

#### Scenario: Existing account with a different shell

- **WHEN** creation runs for an existing account whose shell is not the one this desktop expects
- **THEN** the shell is left as it is and the run prints the command that would change it
