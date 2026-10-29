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

## 2026-10-29 (večer) — sync na druhý stroj, apply

### Hotovo
- **`Scripts/machine-setup.sh`** — deploy (`install.sh -r`, `install_pst.sh`, OpenSpec check) a `--verify`, `--dry-run`. Do `$HOME` iného účtu nesiaha; jediná systémová vec je SDDM téma a `install_pst.sh` ju preskočí, keď už je nastavená (`sddm is already configured`).
- **`Scripts/machine-setup-verify.py`** — porovnáva live strom s **deez manifestom** (`~/.local/share/deez/dots/*.toml`, `src`/`dst`/`action`). Zistenie: `restore_cfg.psv` je legacy, `install.sh` ho už nevolá — deploy ide výhradne cez deez-dots. Preto verify neporovnáva `git ls-files Configs` (666 súborov, tretina legitímne iná).
- **Štyri kôpky:** `deploy` (sync, chyba), `user` (preserve, poznámka), `generated` (prepisuje téma/služba, poznámka), `stale` (v repe už nie je, ďalší deploy odstráni). Bez toho by každé prepnutie témy hlásilo 12 „chybných“ súborov.
- **Dva bugy nájdené live testom:** (1) `install.sh -r` končí otázkou na reboot; s prázdnym stdin `read` zlyhá, `set -e` zhodí úspešný deploy a `install_pst.sh` sa už nespustí — skript preto v termináli odovzdá tty, bez terminálu pošle prázdne riadky („nie / default“). (2) `pgrep -x Hyprland` na vlastnom riadku pod `set -e` zhodil `--verify` skôr, než vypísal session checky; status sa teraz zachytáva cez `||`, takže zlyhanie je `[chyba]` a exit 1.
- **`SYNC.md`** — clone (bundle ako offline fallback), príkazy, čo znamenajú výpisy, troubleshooting, `NO_MANIFEST`.

### Prenesené do repa (live bolo novšie)
- `Configs/.config/kitty/kitty.conf` — `font_size 12.5` (HyDE default 9.0).
- `Configs/.config/swaync/config.json` — control-center margins 8.
- `Configs/.local/lib/hyde/logoutlaunch.sh` bol naopak novší v repe; deploy ho zosynchronizoval do live.

### Overené na bežiacej session
- 1. beh: `prepíše sa :: 1` (logoutlaunch.sh), deploy prešiel; 2. beh: `EXIT=0`, nič sa neprepísalo, `git status` bez zmeny, Waybar unit beží.
- `--verify` dvakrát: `EXIT=0`, žiadny súbor v `~` novší než marker; session checky (Hyprland, `hyde-Hyprland-bar.service`, SDDM Candy, OpenSpec 1.15.0) zelené.
- Negatívne testy: bez `Configs/` → 1, stub `install.sh` bez `--restore` → 1, zlá voľba → 2, prázdny `HOME` → `NO_MANIFEST` 1, stub `pgrep` → `[chyba] Hyprland` + 1.
- `--dry-run` s `HOME=/tmp/hyde-home` (a bez `XDG_*`): `EXIT=0`, zapisuje len do temp homu.
- Lokálne fork checks: shell, Python (57), Lua, JSONC všetko OK; `openspec validate` OK.

### Ešte otvorené
- **Push** (4.3): CI „fork checks“ + upstream suite zelené až po ňom; remote `evan70/HyDE` je verejný (`git ls-remote` bez credentials vráti `3465f40`), takže notas sa klonuje bez prihlásenia.
- **Notas:** `git clone https://github.com/evan70/HyDE.git ~/HyDE` → `./Scripts/install.sh -i -s` (na holom stroji) → `./Scripts/machine-setup.sh` → človek: reboot, login, téma, `gh auth login`. Starý účet na notase zostáva nedotknutý (zdieľa len login obrazovku).
- **Prehľad okien — druhá zmena:** okno otvorené počas prehľadu a kill/close tlačidlo na dlaždici (rozhodnutie layer-shell vs. klávesa v submape `overview`).
- `sync-to-second-machine` sa po pushi a overení na notase archivuje (`openspec archive`).
