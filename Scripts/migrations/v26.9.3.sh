#!/usr/bin/env sh

# Two pairs of files were renamed by an earlier HyDE release, and the old names
# were never cleaned up on a machine that had them: the current files deploy
# next to them, so neither shadows the other -- except that the consumer reads
# the old name first.
#
# 1. Waybar loads "config" before "config.jsonc" (it logs "Using configuration
#    file .../waybar/config"). A machine upgraded from the pre-jsonc layout
#    therefore keeps starting the whole old bar -- its modules, its power
#    button, its screenshot scripts -- no matter how often the new
#    config.jsonc is deployed.
# 2. wlogout's versioned layouts ("layout_1", "style_1.css") replaced the
#    unprefixed "layout"/"style.css", and logoutlaunch.sh passes
#    "--layout layout_<n>". A bare "wlogout" call (the old bar's power button
#    does exactly that) still reads "layout", which on the affected machine
#    carried "hyprctl dispatch exit".
#
# Hyprland 0.56 with the Lua config rejects that legacy dispatcher name with
# "hl.dispatch: expected a dispatcher", so Logout silently did nothing on the
# notebook (2026-10-31).
#
# Only files that the current release replaces are moved, and only when their
# replacement is present; each one is kept as "<name>.pre-hyde", never deleted,
# and an existing backup means the file is left alone. Deployed files are not
# touched -- this only gets the old name out of the way.

conf_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
status=0

move_aside() {
    src="$1"
    dst="${src}.pre-hyde"
    [ -f "${src}" ] || return 0
    if [ -e "${dst}" ]; then
        echo "  kept ${src} -- ${dst} already exists" >&2
        return 0
    fi
    if mv "${src}" "${dst}"; then
        echo "Moved ${src#${HOME}/} aside, kept as $(basename "${dst}")"
    else
        echo "  failed to move ${src}" >&2
        status=1
    fi
}

# 1. waybar: the pre-jsonc config wins over config.jsonc
if [ -f "${conf_home}/waybar/config.jsonc" ]; then
    move_aside "${conf_home}/waybar/config"
fi

# 2. wlogout: layout_1/style_1.css replace the unprefixed names
if [ -f "${conf_home}/wlogout/layout_1" ]; then
    move_aside "${conf_home}/wlogout/layout"
fi
if [ -f "${conf_home}/wlogout/style_1.css" ]; then
    move_aside "${conf_home}/wlogout/style.css"
fi

exit "${status}"
