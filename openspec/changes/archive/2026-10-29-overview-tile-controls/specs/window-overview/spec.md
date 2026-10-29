# Spec Delta

## Purpose

A tiled overview of every window on the normal workspaces: one key opens it, a click or a key acts
on the tile under the cursor, and closing it puts every window back where it came from.

## ADDED Requirements

### Requirement: A tile can be removed from the overview

While the overview is open, the window under the cursor SHALL be removable without first opening
it, and the remaining tiles SHALL be laid out again so the grid keeps its shape.

#### Scenario: Closing a tile with the mouse
- **WHEN** the user middle-clicks a tile
- **THEN** that window is closed, the other tiles re-flow, and the overview stays open

#### Scenario: Killing a tile with the mouse
- **WHEN** the user middle-clicks a tile with `SHIFT` held
- **THEN** that window is killed instead of asked to close, and the rest behaves as a close

#### Scenario: Closing a tile from the keyboard
- **WHEN** the user presses `Delete` or `d` while the cursor is over a tile
- **THEN** that tile is closed, and its `SHIFT` variants kill it instead

#### Scenario: The last tile is removed
- **WHEN** the tile being closed is the last one in the overview
- **THEN** the overview closes and the session is left in its normal workspace

### Requirement: Windows opened during the overview become tiles

A window that appears while the overview is open SHALL NOT stay loose on `special:exposed`; it
SHALL join the grid, and when the overview closes it SHALL land on the workspace that was active
before the overview was opened.

#### Scenario: Launching a terminal from the overview
- **WHEN** a new window opens while the overview is displayed
- **THEN** it is placed in the grid as one more tile, the grid is recomputed for the new count, and
  opening or closing the overview restores it like any other tile

#### Scenario: The adopted window is closed again
- **WHEN** an adopted window is closed from the overview or from its own application
- **THEN** the remaining tiles re-flow and no stale entry is kept for it

### Requirement: A fullscreen window is tiled like any other

A window that is fullscreen or maximized before the overview SHALL be a normal tile while the
overview is open, and SHALL be fullscreen again once the overview closes.

#### Scenario: Opening the overview with a fullscreen window
- **WHEN** the overview opens while one of the windows is fullscreen
- **THEN** that window is laid out in the grid like the others, because Hyprland refuses to resize
  or move a fullscreen window and it would otherwise cover the whole overview

#### Scenario: Closing the overview after a fullscreen tile
- **WHEN** the overview closes
- **THEN** the window that was fullscreen is fullscreen again

### Requirement: Normal interaction is unchanged

The overview SHALL keep the behaviour it already had: it takes windows from the normal workspaces
only, restores floating geometry and fullscreen, and a click on a tile opens that window.

#### Scenario: Click on a tile
- **WHEN** the user left-clicks a tile
- **THEN** the overview closes and that window is focused on its own workspace

#### Scenario: Keys outside the overview
- **WHEN** the overview is not open
- **THEN** the new middle-click and `Delete`/`d` binds do nothing, because they live in the
  `overview` submap only
