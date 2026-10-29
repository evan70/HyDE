# Tasks

## 1. One layout path

- [x] 1.1 Move the grid (columns from the aspect ratio, oversized windows in their own column) out of `open_overview` into `layout_tiles(addresses)`, keeping the measured result identical for the same window set — verified by comparing `hyprctl clients` geometry before and after the refactor for the same four windows
      — A/B na živej session: `git show HEAD:...` spustený na tom istom sete 4 okien dal `[16,16]/[569,16]/[1122,16]/[16,531]` pri `541×503`, nový skript tie isté štyri dlaždice na tých istých pozíciách; po zavretí sa obe vrátili na `825×984` tiled
- [x] 1.2 Make `layout_tiles` work for a subset of windows and for a changed count, so adopting and closing can call it — verified by opening the overview with three windows, then with five
      — otvorenie s 3 dlaždicami `818×503`, pribratie 4. a 5. okna prepočítalo mriežku na `541×503`, zavretie 4. a 3. dlaždice na `818×503`

## 2. Removing a tile

- [x] 2.1 Add `--close-pointer` and `--kill-pointer`: resolve the tile under the cursor, remove it from the state, close or kill the window, re-lay out the rest, and stay in the overview — verified live by middle-clicking one tile and seeing the others re-flow
      — `--close-pointer` na pribratom okne: okno zmizlo, `submap` zostal `overview`, 4 dlaždice sa preložili z 5 na `541×503` a po ďalšom zavretí 4 → 3 na `818×503`; `--kill-pointer` (Shift vetva, SIGKILL) zabil `killprobe`, zvyšné 3 sa preložili a prehľad zostal otvorený
- [x] 2.2 Close the overview when the last tile goes — verified live by closing tiles down to the last one
      — overené so skonštruovaným stavom jedného okna (aby som nezavrel okná používateľa): `--close-pointer` na poslednej dlaždici ukončil prehľad — `special:exposed` skrytá, `submap` `default`, `state.json` zmazaný, ostatné okná nedotknuté
- [x] 2.3 Bind `mouse:273` (close), `SHIFT + mouse:273` (kill), `Delete`/`d` (close) and their `SHIFT` variants in the `overview` submap in `hyprland.lua`, with the descriptions the other binds carry — verified live: the binds do nothing outside the overview and act on the tile under the cursor inside it
      — `hyprctl -j binds` vypisuje všetkých 8 bindov so `submap = overview` a s popismi; v `default` submape nie je na `Delete`/`d`/`mouse:273` bez modifikátora nič (len `SUPER + Delete` a `SUPER + drag`), takže mimo prehľadu sa nedeje nič. Príkazy za bindmi sú overené live (2.1); fyzický stisk klávesy sa nedal simulovať, Hyprland nemá dispatcher, ktorý by poslal klávesu do vlastných bindov

## 3. Windows opened during the overview

- [x] 3.1 Record the pre-overview workspace in the state (`origin_workspace`) and return adopted windows there on close — verified live by opening a terminal during the overview, closing the overview and checking it lands on the old workspace
      — `adopt4` otvorené počas prehľadu (plocha 1 aktívna) skončilo po `--cancel` na ploche 1, tiled `825×984`, ostatné okná na svojich plochách
- [x] 3.2 Recognise `openwindow` in the watcher and adopt the new window (`--adopt=ADDRESS`): move it onto `special:exposed`, add it to the state, re-lay out — verified live by launching `kitty` while the overview is open and seeing it join the grid
      — nové okno (`kitty`) sa po 3 s objavilo ako 4. dlaždica `541×503` v 3×2 mriežke
- [x] 3.3 Suppress the focus event an adopted window causes (`ignore_activeuntil`) so adoption does not close the overview — verified live by checking the overview is still open after the launch
      — po pribratí `submap` ostal `overview`, okno sa neotvorilo
- [x] 3.4 Drop an adopted window from the state when it is closed while the overview is open, and re-flow the rest — verified live by closing the adopted terminal from the overview
      — zavretie pribratého okna (`adopt3`) cez `--close-pointer`: záznam zmizol zo stavu, zvyšné 3 dlaždice sa preložili na `818×503`, prehľad zostal otvorený

## 4. Housekeeping

- [x] 4.1 Document the new binds in `CHANGELOG.md` and next to the submap in `hyprland.lua`
      — `CHANGELOG.md`: nové riadky v `Added` (stredné tlačidlo, `Delete`/`d`, Shift varianty, pribratie okna) a vo `Fixed` (fullscreen dlaždica, `float` prepína namiesto nastavenia); komentár pri submape v `hyprland.lua` popisuje obe vetvy a správanie poslednej dlaždice; `KEYBINDINGS.md` má pod Window Management novú podsekciu Window overview s tabuľkou všetkých siedmich akcií vrátane Shift variantov (overené strojovo: 9 riadkov tabuľky, všetky s tromi oddeľovačmi)
- [x] 4.2 Run the fork checks and the upstream suite, and mirror both changed files to their live paths
      — `Configs/.local/bin/window-overview` a `Configs/.config/hypr/hyprland.lua` sú zhodné s `~/.local/bin/window-overview` a `~/.config/hypr/hyprland.lua` (`diff -q`), session používa nové bindy bez `hyprctl reload`; fork checks a suite: viď nižšie
