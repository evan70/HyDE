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
- **`Scripts/machine-user.sh`** (414 riadkov, komentáre po slovensky, `print_log` a `shell_listed` z `global_fn.sh`): `--check` je default a nič nemení, `--create`, `--name` (default je účet, z ktorého skript beží), `-h`; exit 0/1/2; ako root odmietne bežať. Kontrola má 14 riadkov: účet existuje, nie je root, `sudo -n`, domov (existuje, vlastník, právo zápisu), shell v `/etc/shells`, heslo cez `passwd -S` (P/L/NP), šesť skupín, `hyprland.desktop`. `--create` volá `useradd -m` s primárnou skupinou, `-G` a shellom (`zsh` ak je v `/etc/shells`, inak `bash` + poznámka); existujúcemu účtu doplní len chýbajúce skupiny a shell nemení; heslo ide výhradne cez interaktívne `sudo passwd`, bez terminálu sa vypíše príkaz.
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

## 2026-10-31 — prvý ozajstný beh na notase (`probook`, 192.168.1.105)

### Hotovo
- **Notas bootoval do XFCE:** `display-manager.service → lightdm.service` a `sddm` disabled, hoci `sddm 0.21` aj `hyprland 0.56` boli nainštalované. `systemctl enable --force sddm; systemctl disable lightdm` to prehodilo; po reštarte `Desktop=Hyprland`, `Type=wayland` cez `uwsm start -e -D Hyprland hyprland.desktop`.
- **SDDM téma na notase nebola:** `/etc/sddm.conf.d/the_hyde_project.conf` chýbal, `/usr/share/sddm/themes` mal len `elarun`, `maldives`, `maya` a `kde_settings.conf` ukazoval `Current=maya`. Candy som preniesol z tohto repa (tarball `Source/arcs/Sddm_Candy.tar.gz` + šesť súborov z `Configs/`), `sddm-greeter --test-mode` prešiel bez jediného riadku v logu.
- **`hypr` nemal HyDE vôbec:** len `~/.config/hypr/hyprland.lua`. Doplnené skupiny (`video render input audio storage`), klon do `/home/hypr/HyDE` a `machine-setup.sh`; výsledok `HYDE_THEME="Catppuccin Mocha"`, waybar + wallbash nasadené.
- **Zvuk v `hypr`:** PipeWire bežal, karta v duplexnom profile, ale výstupný node sa nevytvoril (`wireplumber: Failed to create ALSA node alsa_output…analog-stereo: Object activation aborted: PipeWire proxy destroyed`), takže default bol `Dummy Output`. `systemctl --user restart wireplumber` (potom `pipewire pipewire-pulse`) sink vytvoril; default `alsa_output.pci-0000_00_1b.0.analog-stereo`, nemutované.

### Odchytené bugy (otvorené)
1. **Deploy systémových dots bez roota** — `PermissionError: Unable to prepare destination path: /usr/local/share/icons/Bibata-Modern-Ice`, to isté `hyprcursor-bibata-modern-ice` a `font-noto-sans-cjk-ttc`. Deploy skončí `ERROR :: Some dots were not deployed`, `machine-setup.sh` vráti chybu, hoci oba assety na stroji sú (28 M kurzor, 19 M fontov, `fc-list` 40 CJK). Re-deploy hotového účtu preto vždy vyzerá ako rozbitý stroj.
2. **Wallbash na čistom účte** — `skip 'missing directory'` pre `~/.config/hypr/animations/theme.conf`, `~/.config/spicetify/Themes/Sleek/color.ini`, `~/.config/vim/colors/wallbash.vim`, potom `render one or more templates failed, the colour state is incomplete` (exit 4) a `[theme] error :: generating the colour state for Catppuccin Mocha failed with 4`; `colors.conf` pritom vznikol (88 farebných riadkov).
3. **`gtk-4.0/gtk.css` kolízia** — `ln: failed to create symbolic link '/home/hypr/.config/gtk-4.0/gtk.css': File exists`, lebo na CachyOS tam bol reálny súbor. Dot sa počíta ako zlyhaný; pomohlo ručné presunutie do `gtk.css.pre-hyde`.
4. **`machine-setup.sh` dedí cwd** — spustený ako `hypr` z `/home/dany` sype `find: Failed to restore initial working directory /home/dany: Permission denied` a časť dots sa nenasadí. Poistka by bol `cd "$HOME"` na začiatku.

### Cyklus účtu na notase (minimálny install, 2026-10-31)
- Záloha `hypr` domova: `/home/dany/hypr-home-20261031-0030.tgz` (1.1 G).
- `loginctl terminate-user hypr` + `userdel -r hypr` → `getent passwd hypr` prázdne, `/home/hypr` zmazaný.
- `machine-user.sh --check --name hypr` po zmazaní → exit 1 (`účet existuje (účet neexistuje)` + závislé `[chyba]`).
- `machine-user.sh --create --name hypr` → exit 0, `hypr:x:1001:1002::/home/hypr:/bin/zsh`, skupiny `wheel audio input render storage video`, domov `700`; `--check` po → exit 0 „pripravený na deploy“.
- `teraz` overené: skript funguje aj na **druhom účte**, ktorý sa vytvára po boku existujúceho (`dany`), a `--check` je idempotentný.
- **Nález 1:** `--create` cez SSH bez terminálu zlyhá (`sudo: a password is required`) — sudo v skripte nemá `-S`; pod `script -qec` s pipnutým heslom sa tiež minie. Riešenie pri teste: dočasný `sudoers.d/99-provision-test` s `NOPASSWD` pre `dany`, po cykle zmazaný.
- **Nález 2:** keď účet, ktorý skript púšťa, má sudo za heslo, `--check` hlási dve falošné chyby (`sudo (bez hesla sa nedá overiť)` a `heslo (nie je nastavené)`) hoci účet je v poriadku — `passwd -S` bez roota zlyhá a fallback `sudo -n passwd -S` sa nedostane k heslu.
- **Nález 3 (deploy na čistom účte):** prvý beh `machine-setup.sh` skončí pred farbami — témy sú naklonované bez wallpaperov (`No compatible wallpapers found` pre všetkých 12, `~/.config/hyde/wallpapers` prázdny), takže `Wallpaper cache was not generated`, `Theme colour state was not generated` a `Some dots were not deployed`; `install_pst.sh` sa už nespustí. Príčina je nižšie — témy sa vôbec nenaklonovali.
- **Nález 4:** `theme.switch.sh` volá `hyde-shell` bez PATH; z `bash -c`/SSH to skončí `hyde-shell: command not found` a `unable to detect theme`.

### Opravené po cykle (2026-10-31, `b7c4614`, `4741d0f`)
- **Nález 3 mal príčinu o krok skôr, než to vyzeralo:** `theme.patch.sh` ani nezačal klonovať. `globalcontrol.sh` vrátil 1, lebo chcel vytvoriť `$XDG_RUNTIME_DIR/hyde` (`/run/user/1001`), a ten bez logind session neexistuje — `/run` vlastní root, takže ho účet nevytvorí. `theme.patch.sh` preto skončil na `unable to source globalcontrol.sh`, témy ostali prázdne (len `.sort` z `restore_thm.sh`) a wallbash nemal z čoho renderovať. Rovnaká pasca bola v zámku wallpaper backendu (`wallpaper_acquire_lock`), ktorý cestu staval z `$XDG_RUNTIME_DIR` priamo: `mkdir: cannot create directory '/run/user/1001'` → „Another wallpaper backend is still running after waiting 15s“.
- **Oprava:** `HYDE_RUNTIME_DIR` padá do `~/.cache/hyde/runtime`, keď `$XDG_RUNTIME_DIR` chýba alebo sa doň nedá zapisovať; `wallpaper_acquire_lock` aj package lock používajú `HYDE_RUNTIME_DIR`. `theme.switch.sh` hľadá `hyde-shell` v PATH aj v `~/.local/bin` (nález 4).
- **Overené na notase, účet `hypr` bez session, beh cez ssh:** `restore_thm.sh` → 12/12 tém s wallpapermi (4–17 na tému), `theme.switch.sh` → `colors.conf` 111 riadkov, `wallpaper/cache.sh` → 109 dcol + 436 náhľadov. Potom celý `machine-setup.sh` dobehol až na záverečný blok `Zostáva na teba` (ten sa vypíše len po úspešnom `install_pst.sh`), v logu ani jeden `ERROR` / `not generated`.
- **`--verify`:** exit 1 len na `OpenSpec CLI (nie je na PATH)` — CLI na notase chýba, deploy s tým nemá nič; Hyprland, Waybar aj SDDM téma prešli.
- **Upratané:** dočasný `sudoers.d/99-provision-test` (NOPASSWD pre `hypr`) je zmazaný, `sudo -n` pre `hypr` je zase `rc=1`; `/home/hypr/.cache/probe` a pomocné logy tiež.
- **Vlastná chyba pri teste:** drop-in som prvýkrát zapísal cez `echo … | sudo -S tee` a do súboru sa dostal riadok s heslom → sudo hlásil `syntax error`. Opravené zápisom do `/tmp` a `sudo cp` + `visudo -c` (`parsed OK`). Sudoers sa nemá skladať v pipe s heslom, ale z pripraveného súboru.

### Log out na notase nefungoval (2026-10-31)
- **Príčina:** `~/.config/waybar/config` zo septembra 2025 (starý HyDE) prežíva vedľa nasadeného `config.jsonc`, a Waybar načíta `config` skôr (v journale `Using configuration file …/waybar/config`, bar mal starú geometriu 1580×50 namiesto 1600×44). Jeho tlačidlo power spúšťalo `wlogout` bez parametrov, ktorý číta `~/.config/wlogout/layout` — tiež starý súbor s `hyprctl dispatch exit`. Hyprland 0.56 s Lua configom ten legacy názov odmietne (`hl.dispatch: expected a dispatcher`), takže Logout neurobil nič.
- **Oprava:** migrácia `Scripts/migrations/v26.9.3.sh` odsunie `waybar/config` a nečíslované `wlogout/layout` + `style.css` na `*.pre-hyde`, keď sú vedľa prítomné súčasné súbory; nič sa nemaže. Na notase som ich odsunul ručne a reštartoval `hyde-Hyprland-bar.service` — bar sa načíta z `config.jsonc` (1600×44) a jeho power menu ide cez `hyde-shell logoutlaunch 1` → `layout_1` → `hyde-shell logout`.
- **Poznámka:** `uwsm check is-active` vracia na notase 1 aj s reálnym session env, `hyprshutdown` tam nie je — `hyde-logout` preto skončí na `hyprctl dispatch 'hl.dsp.exit()'`, čo je overená a funkčná forma (na tomto stroji je `uwsm` aktívny a `hyprshutdown` existuje).

### Zvuk znovu Dummy Output (2026-10-31)
- **Tentoraz to nebol wireplumber:** `journalctl --user` na `hypr` hlásil `spa.alsa: 'front:0': playback open failed: Device or resource busy`, takže kartu držal niekto iný. `fuser /dev/snd/*` ukázal procesy oboch účtov — `hypr` (pipewire 237404, wireplumber 237405) aj **`dany` (pipewire 237517, wireplumber 237518)**. Jeho session visela, takže `restart wireplumber` aj reštart celého reťazca na `hypr` skončili znovu na Dummy Output.
- **Maska na `dany` bola slepá ulička:** `dany` je účet, ktorý reálne sedí pri obrazovke (`loginctl list-sessions` ho ukazoval ako `seat0`), takže bez vlastného pipewire videl „Dummy Output“ práve on. Maska je zrušená (`systemctl --user unmask pipewire.socket pipewire-pulse.socket` pod `dany`).
- **Riešenie, ktoré funguje:** zastaviť audio stack **toho účtu, ktorý nemá sedenie** (`systemctl --user stop wireplumber pipewire-pulse pipewire pipewire.socket pipewire-pulse.socket`), počkať na prázdne `fuser -v /dev/snd/*`, a potom v prihlásenom účte `systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber`. Overené: `Default Sink: alsa_output.pci-0000_00_1b.0.analog-stereo`, 100 %, nemutované, `pw-play` → 0, kartu drží pipewire prihláseného účtu a `front:0 … Device or resource busy` v logu nie je. Zvuk patrí účtu pri stole, nie tomu, koho domovský adresár je v repe.
- **Druhá pasca:** keď pri stroji nikto nie je, `/run/user/<uid>` neexistuje a žiadny audio stack nebeží — „Dummy Output“ je vtedy správny stav, nie porucha. Ručné `systemctl start user@<uid>.service` zvonku (napr. cez `sudo -u hypr`) audio nezachráni trvalo; po odhlásení/prihlásení sa má starať logind.
- **Pravidlo do budúcna:** pri Dummy Output najprv `loginctl list-sessions` (kto má `seat0`) a `fuser -v /dev/snd/*` (kto drží kartu), až potom reštartovať služby — a nikdy nemaskovať audio účtu, ktorý má sedenie.

### Deploy do existujúceho účtu (`dany`), 2026-10-31
- **`hypr` zmazaný:** `loginctl terminate-user hypr` (nemal sedenie) → `userdel -r hypr` prešlo, `/home/hypr` je preč, `dany` si nechal záložný tarball (`/home/dany/hypr-home-20261031-0030.tgz`, 1,1 G — z druhého účtu ho už `userdel` nezmazal). Skupina `autologin` (gid 1001) ostala, lebo v nej je `dany`.
- **Nový default `machine-user.sh`:** `./Scripts/machine-user.sh --check` bez `--name` v `dany` hlási `meno :: dany`, teda účet, z ktorého sa púšťa — presne to, čo má účet s vlastným Archom dostať. Chýbali len `render` a `input`, `--create` ich doplnil; po ňom `--check` → `účet dany je pripravený na deploy` (exit 0).
- **Sudo cez SSH bez terminálu:** `--create` najprv skončil na `sudo: a password is required` a `--check` na `sudo (bez hesla sa nedá overiť)` — to je vlastnosť prostredia, nie skriptu. Testovací beh preto išiel s dočasným `sudoers.d/99-provision-test` (`dany ALL=(ALL) NOPASSWD: ALL`, `visudo -c` → `parsed OK`), ktorý som po cykle zmazal.
- **Deploy do existujúceho účtu:** `machine-setup.sh` v `dany` prešiel dots (`deez-dots deploy complete`, zálohy do `~/.local/share/deez/backup`), `gtk-4.0/gtk.css` je symlink na `Decay-Green` (predtým tam bol reálny súbor → presun na `.pre-hyde`), migrácia `v26.9.3.sh` sa zapísala a odsunula staré `waybar/config` aj `wlogout/layout`: teraz sú v `~/.config/waybar` len `config.jsonc`, `includes`, `layouts`, `style.css`, `theme.css`.
- **Nová chyba v `wallbash` (opravená):** farby skončili na `mv: cannot move '/tmp/tmp.…' to '/tmp/null': Operation not permitted` → `render one or more templates failed` → `[theme] error :: generating the colour state for Decay Green failed with 4` a `ERROR :: Theme colour state was not generated`. Príčina: `hyprlock_background.dcol` mal target `/tmp/null`; tam ostal súbor `600` od uid 1001 (zmazaný `hypr`) a sticky bit na `/tmp` nedovolí inému účtu ho prepísať. Fix v repe: target je `/tmp/hyde-wallbash-null-${UID}`.
- **Vypnutie po nečinnosti na `dany` nešlo založiť:** `hypridle.conf` aj bind `SUPER + ALT + Delete` volajú `$HOME/.local/bin/idle-shutdown`, ale `Scripts/dots/hyde.toml` z `Configs/.local/bin` nasadzoval len `hyde-shell` a `hydectl`, takže skript na účte chýbal a `idle-shutdown status` končil na `No such file or directory`. Doplnené do `paths`; po `install.sh -r` sa objaví v `~/.local/bin`.
- **Poznámka k logu:** tri `skip 'missing directory'` varovania (`animations/theme.conf`, `spicetify/…`, `vim/colors/…`) sú na existujúcom účte očakávané — tie adresáre `dany` nemá a podľa fixu z `fix-provisioning-deploy` sa nepočítajú ako zlyhanie.

### Pozorovania
- **`hypr` na notase je len testovací účet nášho setu**, nie denný účet — tým je `dany`. Slúži na cyklus `machine-user.sh` + `machine-setup.sh` (vytvor → deploy → zmazanie), takže sa dá kedykoľvek zmazať a založiť znova. Pri riešení prostredia (zvuk, sedenia, autologin, služby) preto vychádzať z `dany` a prihlásenie do `hypr` nesmie ovplyvniť bežnú prácu v `dany`; sedieť pri stroji má vždy len jeden z nich.
- Prečo na notase nikdy neprebehol `install_pst.sh` (chýbal `the_hyde_project.conf`), sa už nedá zistiť — log z toho behu niet. Rovnaká diera môže nastať na ďalšom stroji.
- `sshd` sa po reštarte nespustil, hoci bol `enable --now`; bez neho sa diaľková diagnostika nedá zopakovať, takže do `SYNC.md` patrí krok `systemctl enable sshd`, ak sa má nota obsluhovať na diaľku.
