# Poznámky — HyDE

## 2026-10-29 — SDDM, CI, prehľad okien, OpenSpec

### Hotovo (všetko pushnuté, `master` = `origin/master`, CI zelené)
- **SDDM Candy:** QML hlášky vyriešené — `SystemButtons.qml` (undefined v `KeyNavigation`), `Main.qml` (`pointSize` 0 pri prvom layoute), `Input.qml` (deprecated `Connections`). Overené greeterom v test režime: pôvodná téma z archívu hlási 5 typov hlášok, opravená **0**.
- **Upstream suite:** portovaných 5 dev-only vecí, aby „Tests“ prešli aj na masteri — bindy cez `hyde.config.exec` (#2087), `link_gtk4_theme` (#2200), `mediaplayer.py` cez `python_env.v_import` (#1552), locale formáty SDDM tém, `language-packs` → `main`. Výsledok: 60/60 prípadov + coverage.
- **Prehľad okien:** klik na už fokusovanú dlaždicu funguje (submap `overview` + `--pointer`), okná s vlastnou minimálnou veľkosťou (Telegram) dostali vlastný stĺpec a neprekrývajú susedov, fokus sa po zatvorení vracia na pôvodné okno.
- **OpenSpec:** CLI `~/.local/bin/openspec` (v1.15.0, SHA256 overené), `~/HyDE/openspec/` + `.agents/skills/openspec-*`, projektové pravidlá v `openspec/config.yaml`, poznámka v `~/AGENTS.md`.
- **Bundle:** `/home/hypr/hyde-master-20261029.bundle` (82 MB, complete history, verify OK), posledný commit `0112f13`.

### Odpovede (2026-10-29, večer)
1. **Refactor = sync na druhý stroj.** Dilema „ako dostať fork aj živé configy na druhý stroj“ je téma zajtrajška → založená zmena `sync-to-second-machine`.
2. **Upstream:** držať sa **masteru a cherry-pickovať z `dev`** len to, čo treba (testy už prechádzajú).
3. **Vybrané doplnky:** nové okno v prehľade, `AGENTS.md`/`NOTES.md` do repa, vypnúť telemetriu, a **kill/close tlačidlo na dlaždici** v prehľade.
4. **Corners** hlášky: neriešiť (Candy je aktívna téma).

### Založená zmena: `sync-to-second-machine`
`openspec/changes/sync-to-second-machine/` — 4/4 artefakty, `openspec validate` OK.
- **Proposal:** jeden vstupný bod `Scripts/machine-setup.sh` (+ `--verify`), `SYNC.md`, idempotentnosť; transport (bundle vs. clone) necháva na používateľovi.
- **Spec** `machine-provisioning`: jeden príkaz, overenie bez zmien, vymenované kroky pre človeka, používateľove súbory prežijú opakovaný beh.
- **Design:** obal nad upstream `install.sh -r` + `install_pst.sh` (nie nový inštalátor, nie Nix/Ansible), `--verify` zdieľa zoznam súborov s deployom, `config.toml`/`settings.ini`/téma sa nikdy neprepisujú.
- **Tasks:** 12 krokov v 4 skupinách, každý s vlastným overením.

### Ešte otvorené (na zajtra, mimo tejto zmeny)
- **Prehľad okien — druhá zmena:** (a) okno otvorené počas prehľadu skončí na `special:exposed` a prekryje dlaždice, (b) **kill/close tlačidlo na dlaždici**. Otázka do designu: Hyprland nevie kresliť overlaye bez pluginu — buď vlastná layer-shell vrstva (GTK4/QML) s X tlačidlami, alebo klávesa v submape `overview` (napr. `d`/`Delete` na dlaždicu pod kurzorom). Treba vybrať jednu cestu.
- **Corners:** 8× `Unable to assign [undefined] to QString` — vedome nechané.

### Hotovo navyše (večer)
- `AGENTS.md` a `NOTES.md` sú v repe; `~/AGENTS.md` a `~/NOTES.md` sú symlinky do `~/HyDE`, takže idú s bundlom.
- OpenSpec telemetria vypnutá (`~/.config/openspec/config.json`, `telemetry.enabled: false`).

### Ako začať zajtra
```bash
cd ~/HyDE && git status -sb
openspec status --change sync-to-second-machine     # 4/4 hotovo, čaká na apply
openspec instructions apply --change sync-to-second-machine --json
```
Malé opravy idú priamo, bez návrhu; väčšia zmena = proposal → design → tasks → apply → archive.
