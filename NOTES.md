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

### Stav repa voči upstreamu (2026-10-29)
- `master` = upstream `HyDE-Project/HyDE:master` + **23 commitov, 0 pozadu** (compare API), 81 súborov.
- Z upstreamových súborov meníme jediný: `Scripts/install_pst.sh` (+10 riadkov, obnova SDDM témy z `Configs/usr`). Všetko ostatné sú nové súbory (SDDM Candy QML, `openspec/`, `.agents/`, `.github/` fork checks, `AGENTS/NOTES/SYNC.md`, `Scripts/machine-setup*`), takže upstream updaty sa majú kam zlúčiť.
- Voči `dev`: 24 vpredu / 82 pozadu — zámerne (master + cherry-pick z dev).

### Ešte otvorené
- **Push** (4.3): hotový — `49ee7d0` je na `origin/master`, „Fork checks“ aj upstream „Tests“ zelené. Remote `evan70/HyDE` je verejný (`git ls-remote` bez credentials), takže notas sa klonuje bez prihlásenia.
- **Notas:** `git clone https://github.com/evan70/HyDE.git ~/HyDE` → `./Scripts/install.sh -i -s` (na holom stroji) → `./Scripts/machine-setup.sh` → človek: reboot, login, téma, `gh auth login`. Starý účet na notase zostáva nedotknutý (zdieľa len login obrazovku).
- **Prehľad okien — druhá zmena:** hotová, viď sekcia nižšie.
- `sync-to-second-machine` sa po pushi a overení na notase archivuje (`openspec archive`).

## 2026-10-29 (noc) — prehľad okien: druhá zmena, apply

### Hotovo
- **Zmena `overview-tile-controls`** (4/4 artefakty, `openspec validate` OK): dlaždicu sa dá zavrieť/zabiť bez opustenia prehľadu (stredné tlačidlo, `Delete`/`d`, `SHIFT` = kill), zvyšok sa preloží a posledná dlaždica prehľad zavrie. Okno, ktoré sa otvorí počas prehľadu, sa priberie do mriežky (`--adopt=ADRESA`) a po zavretí sa vráti na plochu aktívnu pred prehľadom (`origin_workspace`).
- **Jedna layout cesta:** mriežka je v `layout_tiles()` — používa ju otvorenie, pribratie aj zavretie dlaždice.

### Dva skutočné bugy nájdené live testom
1. **`hl.dsp.window.float` ignoruje `action`** — `set` aj `unset` vždy prepnú (overené štyrmi dispatchmi na jednom okne). Otvorenie to nepostrehlo (okná sú tiled), ale pribratie prekladá už floating okná → odplavilo ich a mriežka skolabovala do tiling. `set_floating()` teraz číta živý stav a dispatchne len pri rozdiele.
2. **Fullscreen okno sa nedá posunúť ani zmenšiť** („Window is fullscreen“) — zostalo na celom monitore a prekrylo dlaždice. `layout_tiles()` preto pred rozložením fullscreen zruší a `close()` ho vráti zo záznamu; kontrola sa opakuje aj v `fit_in_cells()`, lebo nové okno hlási `fullscreen 1` (krátkodobý maximized stav) až chvíľu po zmapovaní.

### Overené na bežiacej session
- A/B starý vs. nový skript na tých istých 4 oknách: rovnaké dlaždice (`541×503`, rovnaké pozície), po zavretí obe vrátili `825×984` tiled → refactor nezmenil výsledok.
- Pribratie `kitty` počas prehľadu: 4. dlaždica v mriežke, `submap` ostal `overview`; po `--cancel` okno na ploche 1 (origin).
- `--close-pointer`: okno zmizlo, zvyšok sa preložil 5→4 a 4→3 (`541×503` → `818×503`), prehľad zostal otvorený. `--kill-pointer`: SIGKILL, zvyšok preložený.
- Posledná dlaždica (skonštruovaný stav jedného okna, aby som nezavrel okná používateľa): prehľad sa ukončil — `special:exposed` skrytá, `submap` `default`, `state.json` preč.
- Fullscreen okno (`fs=2`) v prehľade: dlaždica `541×503` s `fs=0`, po zavretí späť `fs=2` na `1680×1050`.
- `hyprctl -j binds`: 9 bindov v submape `overview` s popismi; v `default` submape na `Delete`/`d`/`mouse:273` bez modifikátora nič (kolízia len `SUPER + Delete`, `SUPER + drag`).
- Kontroly: `check_python.py` OK, `luac5.4 -p` 78 súborov OK, upstream `run.sh binds` → 164 bindov, 1 prípad, 0 zlyhaní, `openspec validate` OK.

### Poznámka k prostrediu
- Nové okno na tejto session chvíľu hlási `fullscreen 1` (maximized) a po pár sekundách / ďalšom mapovaní to zmizne — nie je to perzistentná window rule (`hyprctl reload` to nezmenil, `alacritty` aj `kitty` sa správajú rovnako). Prehľad to musí tolerovať, čo je teraz súčasťou layout cesty.

## 2026-10-29 (noc) — archivácia oboch zmien, prvé hlavné specy

### Hotovo
- **Dokumentácia bindov:** `KEYBINDINGS.md` má pod Window Management novú podsekciu *Window overview* — `SUPER` + `grave` rozloží okná, tabuľka siedmich akcií (ľavý klik, stredný klik, `Delete`/`d`, `SHIFT` varianty, `ESC`, `SUPER` + `grave`) a poznámka, že ide o submap `overview` a že `mouse:272`/`mouse:273` sú ľavé/stredné tlačidlo. Sedem jazykových mutácií v `Source/assets/keybinds/` túto sekciu nemá — nechávam ich komunite.
- **`overview-tile-controls` zarchivovaná** do `openspec/changes/archive/2026-10-29-overview-tile-controls/` (`.openspec.yaml`, proposal, design, tasks aj pôvodná delta). Delty sa zlúčili: `openspec/specs/window-overview/spec.md` — **4 požiadavky, 10 scenárov**, `+4 added`, `## Purpose` skopírovaný z delty (žiadny `TBD` placeholder).
- **`sync-to-second-machine` zarchivovaná** do `openspec/changes/archive/2026-10-29-sync-to-second-machine/`; `openspec/specs/machine-provisioning/spec.md` — **5 požiadaviek, 11 scenárov**, `+5 added`.
- **Commity:** `3d448f1` (overview + KEYBINDINGS) a `9a7b9be` (sync), oba pushnuté na `origin/master`.

### Overené
- `openspec validate --specs --strict` → `✓ machine-provisioning`, `✓ window-overview`, 2 passed / 0 failed. V hlavných specoch nie je žiadna delta hlavička (`## ADDED/MODIFIED/REMOVED/RENAMED`) ani `TBD`.
- `openspec list` → `No active changes found`; `openspec list --specs` → `machine-provisioning 5 requirements`, `window-overview 4 requirements`.
- CI: na `3d448f1` aj `9a7b9be` „Fork checks“ success, upstream „Tests“ success (aj job *Shell coverage*), „CI“ skipped (tak je workflow nastavený pre tento fork).
- Git vidí presun zmeny do archívu ako rename (`R ... (95-100%)`), KEYBINDINGS ako čistý insert `+28`.

### Dôsledok pre ďalšiu zmenu
- `openspec/specs/` už nie je prázdne, takže ďalšia zmena prehľadu musí ísť cez `## MODIFIED Requirements` s **celým** blokom požiadavky (skopírovaným z hlavného specu), nie cez nové `ADDED` s rovnakým menom.
- `sync-to-second-machine` je zarchivovaná ešte pred prvým behom na notase. Ak notebook odhalí problém, archív sa dá vrátiť späť (`mv openspec/changes/archive/2026-10-29-sync-to-second-machine openspec/changes/`) a zmena sa doplní ako otvorená.

## 2026-10-29 (noc) — účet pre notas: `machine-user-account`

### Hotovo
- **Skript na účet dovtedy nebol.** `grep -rn 'useradd|adduser'` nenašiel v strome nič a `machine-setup.sh` začína až pri prihlásenom účte, takže `hypr` s `wheel/video/render/input/audio/storage` a `/bin/zsh` existoval len v pamäti tohto stroja. Vznikla zmena `machine-user-account` (proposal, design, delta s 3 požiadavkami a 8 scenármi, 11 taskov).
- **`Scripts/machine-user.sh`** (414 riadkov, komentáre po slovensky, `print_log` a `shell_listed` z `global_fn.sh`): `--check` je default a nič nemení, `--create`, `--name` (default `hypr`), `-h`; exit 0/1/2; ako root odmietne bežať. Kontrola má 14 riadkov: účet existuje, nie je root, `sudo -n`, domov (existuje, vlastník, právo zápisu), shell v `/etc/shells`, heslo cez `passwd -S` (P/L/NP), šesť skupín, `hyprland.desktop`. `--create` volá `useradd -m` s primárnou skupinou, `-G` a shellom (`zsh` ak je v `/etc/shells`, inak `bash` + poznámka); existujúcemu účtu doplní len chýbajúce skupiny a shell nemení; heslo ide výhradne cez interaktívne `sudo passwd`, bez terminálu sa vypíše príkaz.
- **Bug s IFS (idempotencia bola falošná):** `local IFS=,` v `ensure_groups` prechádzal aj do procesnej substitúcie `mapfile -t missing < <(missing_groups)`, kde `for grp in $(id -nG …)` delil už len podľa čiarok — každý druhý beh preto "doplnil" všetkých šesť skupín. Riešenie: `join_by_commas` (IFS len v pomocníkovi) a `local IFS=$' \t\n'` v `has_group`.
- **Druhá diera pri implementácii:** `useradd -m -U` zlyhá, ak po starom účte zostala skupina rovnakého mena; skript preto vtedy použije `-g <meno>` a riziko v `design.md` je prepísané, aby sedelo s realitou.
- **`SYNC.md`:** nová sekcia `## Account` (tabuľka skupín s dôvodmi, pravidlo "skupina na systéme nie je = poznámka, chýbajúce členstvo = chyba", root refusal, rollback `userdel -r` / `gpasswd -d`), poradie check → create → `install.sh -i -s` → `machine-setup.sh` a poznámka, že `--verify` účet nekontroluje.
- **`CHANGELOG.md`:** jeden riadok `Account:` v `## Unreleased → ### Added`.
- **Commit `510bd3e`** pushnutý na `origin/master`.

### Overené
- `hypr`: 14× `[ok]` a exit 0; `--name hyde-nope`: 13× `[chyba]` (účet + 12 závislých) a exit 1; `sudo ./Scripts/machine-user.sh`: exit 1; `--bogus`, `--name` bez hodnoty, zlé meno aj dve mená: exit 2 s usage na stderr.
- Throwaway účty `hyde-acct-test` (holý `useradd -m`), `hyde-acct-new`, `hyde-acct-new3` a `hyde-acct-new4` (ten so skupinou rovnakého mena): skupiny aj shell sedia, `passwd -S` = `L`, druhý beh `[ok] skupiny sedia`, po `gpasswd -d … video` doplnené len `video`, účet s `/usr/bin/bash` si shell nechal a dostal `chsh` hint.
- `diff` snapshotov (`getent passwd`, `id -nG hypr` / `nobody` / testovací účet, `ls -la /home`) okolo dvoch behov prázdny; všetky testovacie účty aj skupina zmazané, `/home` má len `ai-agent`, `evan`, `hypr`.
- Negatívne cesty: domov vlastnený rootom → `[chyba]`; temp kópia s `hyde_nogroup` → poznámka, do chýb sa nepočítala; temp kópia s neexistujúcou SDDM session → `[chyba]`.
- Testy sa opierali o passwordless sudo na tomto stroji (`sudo -n true` prechádza), takže `useradd`/`usermod`/`userdel` išli bez pýtania hesla.
- Lokálne: `bash -n` OK, Python 57/0, `luac5.4 -p` OK, JSONC 143/0, `openspec validate machine-user-account --strict` valid.
- CI na `510bd3e`: Fork checks success, Tests success (aj *Shell coverage*), CI skipped (tak je workflow nastavený).

### Ešte otvorené
- Zmena je hotová a CI zelené, ale **nie je zarchivovaná**: `openspec archive machine-user-account` zlúči 3 nové požiadavky do `openspec/specs/machine-provisioning/spec.md` (5 → 8 požiadaviek).
- Celý postup z `SYNC.md` ešte neprešiel na notase; skript je overený len tu, na throwaway účtoch, ktoré zase zmizli.
