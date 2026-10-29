# Proposal

## Why

The tiled overview (`SUPER + grave`, `Configs/.local/bin/window-overview`) can show windows and
close itself on a click, but it cannot do anything with a tile and it mishandles windows that
appear while it is open:

- A window opened during the overview (launching a terminal, a notification app, `xdg-open`)
  lands on `special:exposed` *behind* the tiles, in whatever geometry the application asked for, so
  it covers the grid and takes clicks away from the tiles under it.
- A tile cannot be closed or killed from the overview. The only ways out are opening the window
  (which closes the overview) or `ESCAPE`, and both leave a dead window on its workspace.

Hyprland cannot draw controls on a window without a plugin (`hyprexpo` needs `hyprpm`, which this
build does not ship), so a visible X button would mean a second client with a layer-shell surface
and its own click channel. The cheap, dependency-free route is the submap the overview already
owns: mouse buttons and keys can act on the tile under the cursor.

## What Changes

- **Closing a tile:** in the `overview` submap, `mouse:273` (middle click) closes the window under
  the cursor, `SHIFT + mouse:273` kills it, and `Delete`/`d` do the same from the keyboard
  (`SHIFT` variants kill). The remaining tiles re-flow so the grid keeps its shape, and the
  overview stays open; closing the last tile closes the overview.
- **Windows opened during the overview** are adopted as tiles: the window is moved onto the grid,
  the grid is recomputed so every tile stays square, and on close the window returns to the
  workspace that was active before the overview was opened.
- The layout code moves out of `open_overview` into one `layout_tiles` used by opening, adopting
  and closing, so the three paths cannot drift apart.

Explicitly out of scope: a drawn overlay with X buttons (would need a layer-shell client and a
plugin alternative), animations, renaming windows, and overview behaviour on multiple monitors
beyond the focused monitor it already uses.

## Capabilities

### New Capabilities
- `window-overview`: the tiled overview — which windows it takes, how it lays them out, how a tile
  is opened or removed, and how windows that appear while it is open are handled.

### Modified Capabilities
<!-- none: no existing spec describes the overview -->

## Impact

- Live paths: `~/.local/bin/window-overview` and `~/.config/hypr/hyprland.lua` (new submap binds);
  both are edited in the repository (`Configs/...`) and mirrored live, then Hyprland is reloaded.
- `CHANGELOG.md`, and the overview's own `--help`-less flag set (`--close-pointer`, `--kill-pointer`,
  `--adopt=ADDRESS`).
- Upstream drift: none of this exists upstream (`evan70/HyDE` only), so it is added code on top of
  `master` and cannot conflict with a `dev` cherry-pick.
- No new dependency, no plugin, no service: the overview keeps working when `window-overview` is
  the only file deployed.
