# Design

## Context

`Configs/.local/bin/window-overview` is a Python script driven by `hyprctl`:

- Opening moves every window from workspaces `> 0` onto `special:exposed`, sets them floating,
  sizes them into a grid (with a right-hand column for windows that refuse to shrink below their
  own minimum), saves a state file with each window's workspace, geometry, floating and fullscreen
  state, then enters the `overview` submap and starts a background watcher.
- A left-click in the submap runs `window-overview --pointer`, which resolves the window under the
  cursor and closes the overview with that window focused.
- The watcher listens on the Hyprland event socket (`.socket2.sock`) for `activewindow` and closes
  the overview when a window on `special:exposed` receives focus — that is how a click on the
  *already focused* tile is noticed, since focus does not change there.

The layout logic (grid columns from the aspect ratio, oversized windows in their own column) is
inline in `open_overview`, which is why there is no way to re-lay out without reopening.

## Goals / Non-Goals

**Goals:**
- Remove a tile (close or kill) without leaving the overview, with mouse and keyboard.
- Adopt windows that appear during the overview into the grid, and give them a sane workspace to
  return to.
- One layout path for open, adopt and close.

**Non-Goals:**
- A visible X control on each tile (needs a layer-shell client; the chosen route is the submap).
- Multi-monitor overviews beyond the focused monitor.
- Animations or transitions.

## Decisions

**Submap binds, not an overlay.** The `overview` submap already captures the pointer for tile
clicks, so `mouse:273` and `Delete`/`d` cost two binds each and no new process. A layer-shell
overlay would need a GTK4/QML client with a click-through policy and a way to map clicks back to
window addresses — a new dependency and a new failure mode for the same result. The cost is that
the control is invisible: `Shift` means kill, plain means close, and the submap's binds are
documented in `hyprland.lua` next to the existing ones.

**`--close-pointer` / `--kill-pointer`, resolved under the cursor.** The keyboard and the mouse
share one code path: both act on the tile under the cursor, which is also what a click on a
non-focused tile would select. Resolving by focus instead would make `Delete` act on whatever the
window manager focused last, which during the overview is not meaningful.

**Closing a tile re-lays out the rest.** The alternative — leaving a hole — would break the
"tiles stay square" property and make the overview look broken after one close. The remaining
addresses go through the same `layout_tiles` the opening uses, so the grid is recomputed for the
new count.

**Adoption records the return workspace at open time.** A window created during the overview
already reports `special:exposed` as its workspace, so its "own" workspace cannot be read from
`clients` after the fact. `open_overview` therefore stores the workspace of the window that was
focused before the overview (`origin_workspace`), and every adopted window returns there. The
alternative — the workspace it would have been created on — is not observable from inside the
overview.

**Floating is set, not toggled.** `hl.dsp.window.float` in this Hyprland ignores its `action`
argument: `action = "set"` and `action = "unset"` both toggle (verified live on a probe window —
four calls flipped the state every time). Opening the overview never noticed, because the windows it
receives are tiled, but adoption re-lays out windows that are already floating and un-floated them,
so the grid collapsed into a tiling. `set_floating` therefore reads the live client and dispatches
only when the state differs.

**A fullscreen window is cleared before it becomes a tile.** Hyprland refuses `move` and `resize` on
a fullscreen or maximized window (`Window is fullscreen`) — a window that was fullscreen before the
overview stayed at monitor size and covered every tile. The open, adopt and close paths all go
through `layout_tiles`, which clears the state first; the recorded `fullscreen` value is what
`close()` restores. The clear also runs a second time in the cell-fitting pass, because a window
that maps during the overview can report `fullscreen 1` (a short-lived maximized state) a moment
after it was read, and the first pass would have skipped it.

**The watcher adopts; the script stays single-threaded.** The watcher already owns the event
socket, so it recognises `openwindow>>ADDRESS,...` and spawns `window-overview --adopt=ADDRESS`.
That path takes the same instance lock as every other invocation, reads the state file and
re-lays out. Doing it inside the watcher process would duplicate the lock and state handling.

**Focus noise is suppressed with a deadline.** Adopting a window moves and resizes it, and the new
window is focused when it maps; an `activewindow` event arriving in that window would look like
the user clicking a tile and would close the overview. Adopting stores `ignore_activeuntil`
(now + 1.5 s) in the state, and the watcher ignores `activewindow` until then — the same guard the
opening already gets from its 0.8 s sleep, without a sleep that blocks the socket.

**Kill vs close is the only destructive action, and it is opt-in.** Plain middle click and `d`
close (the application can still prompt to save), `Shift` kills. Nothing in the overview kills a
window by default.

## Risks / Trade-offs

- **A stray middle click in the overview closes a window** → the closing half of the submap is the
  same place the left click already acts, and the overview is a deliberate mode; `ESCAPE` still
  leaves it without touching anything.
- **Re-laying out on every adoption is expensive** (a `hyprctl` round trip per window) → the same
  cost the opening already pays for the same number of windows, and it happens once per new window.
- **`ignore_activeuntil` is a time-based guard** → 1.5 s is longer than the observed map-to-focus
  delay; if a machine is slower, a click in that window is ignored and the user clicks again.
- **Killed windows bypass save prompts** → it is the `Shift` variant only, documented next to the
  bind, and the spec names it.

## Migration Plan

1. Ship the script and the two submap binds on `master`.
2. Mirror both to `~/.local/bin/window-overview` and `~/.config/hypr/hyprland.lua`, then
   `hyprctl reload` so the submap picks up the new binds.
3. Rollback is `git revert` plus a reload; no state file format change is involved (adopted windows
   are ordinary entries).
