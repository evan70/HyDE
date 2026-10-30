-- Hyprland loads this file when it is started without a config, and it prefers
-- it over hyprland.conf. HyDE loads it too, last, as the override layer below.
-- The block keeps the two apart: hyde.lua sets `hyde` on its first line, so it
-- runs only when this file is the entry point and HyDE has not been loaded.
-- Removing it leaves a session with a cursor and nothing else.
if not hyde then
	local share = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
	local entry = share .. "/hypr/hyde.lua"
	local handle = io.open(entry, "r")
	if not handle then
		error("HyDE is not installed at " .. entry .. ". Run install.sh -r, or point Hyprland at your own config.")
	end
	handle:close()
	dofile(entry)
end

-- Your Hyprland configuration. HyDE never overwrites this file.
--
-- It loads after HyDE's own binds, so settings here take precedence. Replacing
-- a bind needs more than that: see below. HyDE's defaults live in
-- ~/.local/share/hypr/lua/ and are overwritten on every update, so edits there
-- do not survive.
--
-- Adding a keybind:
--
--     hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(hyde.sh.gamelauncher()), {
--         description = "[Utilities] game launcher",
--     })
--
-- Replacing one of HyDE's: bind the same combination again and yours takes
-- over, but copy its flags across as well. A bind counts as the same one only
-- when its flags match, and `description` is not a flag — miss one and both
-- binds stay live on that combination. Copy the whole options table from
-- ~/.local/share/hypr/lua/key_binds.lua and change only what you need:
--
--     hl.bind("F9", hl.dsp.exec_cmd(hyde.sh.volumecontrol("-o", "m")), {
--         locked = true,
--         description = "[Hardware Controls|Audio] un/mute output",
--     })
--
-- Press SUPER + / to see what is actually loaded, your own binds included.
-- The full reference is KEYBINDINGS.md in the HyDE repository.
--
-- Other Lua files next to this one can be pulled in with require("name").

-- Po prihlásení zhrnie stav SDDM/Hyprland/waybar z logov: notifikácia + report
-- v $XDG_STATE_HOME/login-report/last.txt. Skript sám čaká na waybar max 10 s,
-- takže stačí krátke oneskorenie, aby stihol nabehnúť.
if hl and hl.on and hl.exec_cmd then
	hl.on("hyprland.start", function()
		hl.exec_cmd("sleep 6 && exec $HOME/.local/bin/login-report --quiet")
		hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/keyboard-layout-notify")
		-- Relácia: watch si počas sedenia drží zoznam okien a restore ich po
		-- prihlásení vráti na pôvodné plochy. Skript sa dá kedykoľvek vypnúť
		-- cez `session-restore off` (aj stav zmazať cez `session-restore forget`).
		hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/session-restore restore")
		hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/session-restore watch")
	end)
end

-- Snímka pre ďalšie prihlásenie sa robí tu, kým okná ešte existujú. HyDE pri
-- odhlásení spúšťa `uwsm stop`, takže bez toho by posledné eventy `closewindow`
-- prepísali uložený stav prázdnym zoznamom a obnovilo by sa nič.
if hl and hl.on and hl.exec_cmd then
	hl.on("hyprland.shutdown", function()
		hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/session-restore seal")
	end)
end

-- Vypnutie stroja po nečinnosti (náhrada xfce4-power-manageru): rofi menu
-- s profilmi, ktoré čítajú listenery v hypridle.conf.
if hl and hl.bind and hl.dsp and hl.dsp.exec_cmd then
	hl.bind("SUPER + ALT + Delete", hl.dsp.exec_cmd("$HOME/.local/bin/idle-shutdown select"), {
		description = "[Utilities] shutdown timer after idle",
	})
end

-- Rozloženie klávesnice: angličtina + slovenčina (QWERTY), prepínanie
-- ALT+SHIFT. Prepínanie robí xkb, takže naň nejde naviazať bind — zmenu
-- preto oznamuje keyboard-layout-notify cez event socket (viď nižšie).
if hl and hl.config then
	hl.config({
		input = {
			kb_layout = "us,sk",
			kb_variant = ",qwerty",
			kb_options = "grp:alt_shift_toggle",
		},
	})
end

-- SUPER + K prepína rozloženie tiež, ale cez HyDE skript, ktorý by pridal
-- druhé oznámenie k tomu z ALT+SHIFT. Preto ho prepíšeme na tiché prepnutie;
-- oznámenie dodá keyboard-layout-notify pre obe cesty.
if hl and hl.bind and hl.dsp and hl.dsp.exec_cmd then
	hl.bind("SUPER + K", hl.dsp.exec_cmd("hyprctl switchxkblayout current next"), {
		description = "[Utilities] toggle keyboard layout",
		locked = true,
	})
end

-- Prehľad okien: SUPER + ` rozloží všetky okná do mriežky na špeciálnom
-- workspaci "exposed" a druhé stlačenie ich vráti späť (plocha, fokus,
-- floating aj fullscreen). Je to náhrada hyprexpo — ten je plugin, ktorý sa
-- musí skompilovať cez hyprpm, a ten v tomto Hyprlande (0.56.2) nie je.
-- Dwindle pri návrate skladá rozloženie znova, preto skript počas obnovy
-- pripína kurzor — rovnaké okná tak vrátia vždy rovnaké rozloženie. Výnimka
-- je plocha, ktorá už pred prehľadom mala zrkadlový tvar (veľký panel vpravo):
-- prvé zatvorenie ju vráti do štandardného tvaru a ďalej sa už nemení.
if hl and hl.bind and hl.dsp and hl.dsp.exec_cmd then
	hl.bind("SUPER + grave", hl.dsp.exec_cmd("$HOME/.local/bin/window-overview"), {
		description = "[Window Management] tiled overview of all windows",
	})
end

-- Kliknutie na dlaždicu: okno pod kurzorom dostane fokus a prehľad sa
-- zavrie. Kým je prehľad otvorený, platí submap "overview" s bindom na ľavé
-- tlačidlo — klik na už fokusovanú dlaždicu totiž nemení fokus, takže by
-- žiadny event neprišiel a nič by sa nestalo. ESC a SUPER + ` sú v submape
-- tiež, aby sa z neho nedalo zaseknúť (submap vypína všetky ostatné klávesy).
-- Mimo prehľadu je submap neaktívny, takže bežné klikanie ostáva nedotknuté.
--
-- Stredné tlačidlo a Delete/d zavrú dlaždicu pod kurzorom, Shift+stredné a
-- Shift+Delete/d ju zabijú. Prehľad ostane otvorený a zvyšok sa preloží;
-- posledná dlaždica prehľad zavrie.
if hl and hl.define_submap and hl.dsp and hl.dsp.exec_cmd then
	hl.define_submap("overview", "reset", function()
		hl.bind("mouse:272", hl.dsp.exec_cmd("$HOME/.local/bin/window-overview --pointer"), {
			description = "[Window Management] overview: open the window under the cursor",
		})
		hl.bind("ESCAPE", hl.dsp.exec_cmd("$HOME/.local/bin/window-overview --cancel"), {
			description = "[Window Management] close the overview",
		})
		hl.bind("SUPER + grave", hl.dsp.exec_cmd("$HOME/.local/bin/window-overview"), {
			description = "[Window Management] tiled overview of all windows",
		})
		hl.bind("mouse:273", hl.dsp.exec_cmd("$HOME/.local/bin/window-overview --close-pointer"), {
			description = "[Window Management] overview: close the window under the cursor",
		})
		hl.bind("SHIFT + mouse:273", hl.dsp.exec_cmd("$HOME/.local/bin/window-overview --kill-pointer"), {
			description = "[Window Management] overview: kill the window under the cursor",
		})
		hl.bind("Delete", hl.dsp.exec_cmd("$HOME/.local/bin/window-overview --close-pointer"), {
			description = "[Window Management] overview: close the window under the cursor",
		})
		hl.bind("SHIFT + Delete", hl.dsp.exec_cmd("$HOME/.local/bin/window-overview --kill-pointer"), {
			description = "[Window Management] overview: kill the window under the cursor",
		})
		hl.bind("d", hl.dsp.exec_cmd("$HOME/.local/bin/window-overview --close-pointer"), {
			description = "[Window Management] overview: close the window under the cursor",
		})
		hl.bind("SHIFT + d", hl.dsp.exec_cmd("$HOME/.local/bin/window-overview --kill-pointer"), {
			description = "[Window Management] overview: kill the window under the cursor",
		})
	end)
end

-- Alternatívne prepínanie pracovných plôch 1-9 cez ALT.
-- HyDE má SUPER + 1-9 aj SUPER + KP_1-9; SUPER + číslo však niektoré
-- vzdialené relácie a hostitelia (VM/SPICE, RDP, macOS) zachytávajú pre seba,
-- takže do Hyprlandu sa nedostane. ALT + 1-9 je voľné a prejde vždy.
if hl and hl.bind and hl.dsp then
	for i = 1, 9 do
		hl.bind("ALT + " .. i, hl.dsp.focus({ workspace = i }), {
			description = "[Workspaces|Navigation] workspace " .. i .. " (ALT fallback)",
		})
	end
end
