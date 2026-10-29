#!/usr/bin/env python3
# Porovná live strom s tým, čo deez-dots naozaj nasadil.
#
# Zdroj pravdy nie je git ls-files Configs/ ani legacy restore_cfg.psv: deploy
# ide cez deez-dots a ten si drží manifest v ~/.local/share/deez/dots/*.toml
# s mapovaním src/dst a akciou. Súbory, ktoré deez zámerne ignoruje
# (__pycache__, .editorconfig, schema/), sa preto nikdy nehlásia ako chýbajúce.
#
# Výstup je TSV, jeden riadok na problém:
#   status  class      src                       dst
#   missing deploy     Configs/.config/kitty/... /home/u/.config/kitty/...
#
# class:
#   deploy    - akcia sync, zmena je skutočný rozdiel (chyba)
#   user      - akcia preserve, súbor patrí používateľovi (poznámka)
#   generated - súbor prepisuje téma alebo bežiaca služba (poznámka)
#   stale     - súbor v repe už nie je, na disku ostal po starom deployi (poznámka)
#
# Bez manifestu vypíše NO_MANIFEST: na stroji ešte nič nebolo nasadené.
# Skript nič nemení a vždy končí s 0; o exit statusu rozhoduje machine-setup.sh.

import glob
import os
import sys
import tomllib

# Súbory v manifeste so sync, ktoré si prepisuje téma alebo aplikácia.
# Porovnávať ich byte po byte nemá zmysel — menia sa pri každom prepnutí témy
# a pri každom zatvorení okna aplikácie.
RUNTIME_GENERATED = (
    "Configs/.gtkrc-2.0",
    "Configs/.config/Kvantum/wallbash",
    "Configs/.config/dunst/dunstrc",
    "Configs/.config/dolphinrc",
    "Configs/.local/share/kxmlgui5/dolphin",
    "Configs/.config/hypr/hyprlock/HyDE.conf",
)


def expand(path):
    """Rozbalí ${HOME} a ${XDG_*} tak, ako to robí deez."""
    env = {
        "HOME": os.environ["HOME"],
        "XDG_CONFIG_HOME": os.environ.get("XDG_CONFIG_HOME", os.path.join(os.environ["HOME"], ".config")),
        "XDG_DATA_HOME": os.environ.get("XDG_DATA_HOME", os.path.join(os.environ["HOME"], ".local", "share")),
        "XDG_STATE_HOME": os.environ.get("XDG_STATE_HOME", os.path.join(os.environ["HOME"], ".local", "state")),
        "XDG_CACHE_HOME": os.environ.get("XDG_CACHE_HOME", os.path.join(os.environ["HOME"], ".cache")),
    }
    for key, value in env.items():
        path = path.replace("${" + key + "}", value)
    return path


def classify(src, action):
    for prefix in RUNTIME_GENERATED:
        if src == prefix or src.startswith(prefix + "/"):
            return "generated"
    return "user" if action == "preserve" else "deploy"


def same(src, dst):
    if os.path.islink(dst) and not os.path.isfile(dst):
        return False
    try:
        with open(src, "rb") as a, open(dst, "rb") as b:
            return a.read() == b.read()
    except OSError:
        return False


def main():
    home = os.environ["HOME"]
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    manifests = sorted(glob.glob(os.path.join(home, ".local", "share", "deez", "dots", "*.toml")))

    if not manifests:
        print("NO_MANIFEST\t\t\t")
        return 0

    for manifest in manifests:
        with open(manifest, "rb") as handle:
            data = tomllib.load(handle)

        for entry in data.get("files", []):
            src = entry.get("src", "")
            dst = entry.get("dst", "")
            action = entry.get("action", "sync")

            # Archívy a balíky, ktoré deez ťahá mimo Configs/, sem nepatria.
            if not src.startswith("Configs/") or not dst:
                continue

            repo_path = os.path.join(repo, src)
            live_path = expand(dst)
            if not os.path.exists(repo_path):
                # Súbor v repe zmizol. Keď po ňom ostal kus na disku, ďalší
                # deploy ho odstráni (clean_target); inak nie je čo hlásiť.
                if os.path.exists(live_path):
                    print(f"stale\tstale\t{src}\t{live_path}")
                continue

            if not os.path.exists(live_path):
                print(f"missing\t{classify(src, action)}\t{src}\t{live_path}")
            elif os.path.isfile(repo_path) and not same(repo_path, live_path):
                print(f"diff\t{classify(src, action)}\t{src}\t{live_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
