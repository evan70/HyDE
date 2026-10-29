# Poznámky pre agenta

- **Jazyk:** s používateľom komunikuj **po slovensky** (nie česky). Týka sa to odpovedí v chate aj komentárov v kóde, ktoré píšeš.
- **Prostredie:** CachyOS, Hyprland 0.56 (Lua config), HyDE nainštalované z `~/HyDE` (viď `HyDE/dots.toml`).
- Konfiguráky v `~/.config` sú **kopie**, nie symlinky do `~/HyDE/Configs`. Zmena, ktorá má prežiť reinstall, patrí do `~/HyDE/Configs/...` a musí sa prejaviť aj v `~/.config/...`.
- Veci, ktoré HyDE neprepisuje a sú určené na úpravy: `~/.config/hypr/hyprland.lua`, `~/.config/waybar/user-style.css`, `~/.config/hyde/config.toml`.
- **OpenSpec:** `~/HyDE` používa OpenSpec (CLI `~/.local/bin/openspec`, plán v `~/HyDE/openspec/`). Väčšia zmena začína návrhom: `openspec new change <nazov>` (alebo skill `openspec-propose`) → `changes/<nazov>/{proposal.md,design.md,tasks.md,specs/}`, implementuje sa až po odsúhlasení a hotová zmena sa archivuje do `openspec/changes/archive/`, pričom sa jej delty zlúčia do `openspec/specs/`. Workflow skilly sú v `~/HyDE/.agents/skills/openspec-*` (`propose`, `apply-change`, `update-change`, `sync-specs`, `archive-change`, `explore`); projektové obmedzenia pre ne sú v `~/HyDE/openspec/config.yaml`. Malé opravy idú priamo, bez návrhu.
