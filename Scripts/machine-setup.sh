#!/usr/bin/env bash
#|---/ /+--------------------------------------------+---/ /|#
#|--/ /-| Bring a checkout to a ready session      |--/ /-|#
#|-/ /--| evan70/HyDE (fork of HyDE-Project/HyDE)   |-/ /--|#
#|/ /---+--------------------------------------------+/ /---|#
#
# Jeden vstupný bod pre druhý stroj; pozadie a transport sú v SYNC.md.
#
# Čo skript spraví sám (deploy):
#   - vypíše revíziu checkoutu a cesty, ktorých sa dotkne
#   - Scripts/install.sh -r   (deploy Configs/ do $HOME, so zálohou do ~/.config/cfg_backups)
#   - Scripts/install_pst.sh  (SDDM téma, shell, file manager, flatpak)
#   - zistí OpenSpec CLI
#
# Čo ostáva na človeka (skript to len vypíše, nič neháda):
#   - balíky: Scripts/install.sh -i   (interaktívny; AUR, nvidia, shell)
#   - prvý login cez SDDM, voľba témy a wallpaperu
#   - push na GitHub: gh auth login
#   - OpenSpec CLI, ak chýba (presný príkaz vypíše)
#
# Skript beží ako používateľ, ktorý má desktop dostať, a okrem systémovej SDDM
# témy (zdieľanej všetkými účtami, a len keď ešte nie je nastavená) nesiaha
# mimo jeho $HOME. Existujúci účet na stroji sa nemení.
#
# --verify nič nemení. Porovnáva presne to, čo deez-dots nasadil (jeho manifest
# v ~/.local/share/deez/dots), a to, čo si prepisuje téma alebo bežiaca služba,
# vypíše ako poznámku — inak by každé prepnutie témy vyzeralo ako rozbitý stroj.

set -eo pipefail

scrDir="$(dirname "$(realpath "$0")")"
cloneDir="$(dirname "${scrDir}")"
cfgDir="${cloneDir}/Configs"
verifyHelper="${scrDir}/machine-setup-verify.py"
export CLONE_DIR="${cloneDir}"

# pkg_installed a print_log z upstreamu; nič neinštalujú, len definujú funkcie
# shellcheck disable=SC1091
source "${scrDir}/global_fn.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

  (bez voľby)   nasadiť checkout do live ciest a dokončiť post-install kroky
  --verify      nič nemeniť; porovnať live strom s tým, čo je nasadené, a overiť session
  --dry-run     deploy ako skúšobný beh (install.sh -t); nič sa neprepíše
  -h, --help    táto nápoveda

Exit status: 0 = v poriadku, 1 = rozdiel alebo zlyhanie, 2 = zlá voľba.
EOF
}

mode="deploy"
dryRun=0
while (($#)); do
    case "$1" in
    --verify) mode="verify" ;;
    --dry-run) dryRun=1 ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "Neznáma voľba: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
    shift
done

#----------------#
# stráže         #
#----------------#

if [[ ! -d "${cfgDir}" || ! -f "${scrDir}/install.sh" || ! -f "${scrDir}/install_pst.sh" ]]; then
    echo "CHYBA: ${cloneDir} nie je checkout tohto forku — chýba Configs/, Scripts/install.sh alebo Scripts/install_pst.sh." >&2
    exit 1
fi

if [[ ! -f "${verifyHelper}" ]] || ! command -v python3 >/dev/null 2>&1; then
    echo "CHYBA: chýba ${verifyHelper} alebo python3; bez nich sa nedá porovnať nasadený strom." >&2
    exit 1
fi

# Skript stojí na flagoch upstream installera. Keď ich upstream premenuje,
# treba sa prispôsobiť upstreamu, nie obchádzať ho vlastnou kópiou.
if ! "${scrDir}/install.sh" --help 2>/dev/null | grep -q -- '--restore'; then
    echo "CHYBA: Scripts/install.sh už neponúka -r/--restore, na ktorom tento skript stojí. Aktualizuj machine-setup.sh podľa upstreamu." >&2
    exit 1
fi

#----------------#
# porovnanie     #
#----------------#

# Naplní polia z výstupu machine-setup-verify.py (TSV: status, class, src, dst).
deployMissing=()
deployDiffering=()
userNotes=()
generatedNotes=()
staleNotes=()
manifestPresent=1

collect_drift() {
    local status class src dst

    deployMissing=()
    deployDiffering=()
    userNotes=()
    generatedNotes=()
    staleNotes=()
    manifestPresent=1

    while IFS=$'\t' read -r status class src dst; do
        case "${status}" in
        NO_MANIFEST) manifestPresent=0 ;;
        missing)
            case "${class}" in
            deploy) deployMissing+=("${src#Configs/}") ;;
            user) userNotes+=("${src#Configs/}") ;;
            *) generatedNotes+=("${src#Configs/}") ;;
            esac
            ;;
        diff)
            case "${class}" in
            deploy) deployDiffering+=("${src#Configs/}") ;;
            user) userNotes+=("${src#Configs/}") ;;
            *) generatedNotes+=("${src#Configs/}") ;;
            esac
            ;;
        stale) staleNotes+=("${src#Configs/}") ;;
        esac
    done < <(python3 "${verifyHelper}")
}

print_dir_summary() {
    local rel dir
    local -A dirCount=()

    for rel in "${deployMissing[@]}" "${deployDiffering[@]}"; do
        dir="${rel%/*}"
        dirCount["${dir}"]=$(( ${dirCount["${dir}"]:-0} + 1 ))
    done

    [[ ${#dirCount[@]} -eq 0 ]] && return 0
    for dir in $(printf '%s\n' "${!dirCount[@]}" | sort); do
        printf '    %-38s %s\n' "${dir}" "${dirCount["${dir}"]}"
    done
}

#----------------#
# session        #
#----------------#

session_failures=0

session_check() {
    local label="$1" status="$2" detail="${3:-}"

    if [[ "${status}" -eq 0 ]]; then
        print_log -g "[ok]   " -b " :: " "${label}${detail:+ (${detail})}"
    else
        print_log -r "[chyba]" -b " :: " "${label}${detail:+ (${detail})}"
        session_failures=$((session_failures + 1))
    fi
}

check_session() {
    session_failures=0

    # Hyprland musí bežať; bez neho nemá zmysel porovnávať zvyšok.
    # Status sa musí zachytiť cez "|| ", inak by ho set -e zobral ako zlyhanie skriptu.
    local hyprStatus=0
    pgrep -x Hyprland >/dev/null 2>&1 || hyprStatus=$?
    session_check "Hyprland beží" "${hyprStatus}"

    # Bar nie je waybar.service, ale template unit, ktorý HyDE spúšťa.
    if systemctl --user is-active --quiet hyde-Hyprland-bar.service 2>/dev/null || pgrep -x waybar >/dev/null 2>&1; then
        session_check "Waybar beží" 0 "hyde-Hyprland-bar.service"
    else
        session_check "Waybar beží" 1 "chýba hyde-Hyprland-bar.service aj proces"
    fi

    local sddmConf="/etc/sddm.conf.d/the_hyde_project.conf"
    if [[ -r "${sddmConf}" ]]; then
        local theme
        theme="$(sed -n 's/^Current=//p' "${sddmConf}" | tail -1)"
        if [[ -n "${theme}" && -d "/usr/share/sddm/themes/${theme}" ]]; then
            session_check "SDDM téma" 0 "${theme}"
        else
            session_check "SDDM téma" 1 "Current=${theme} nemá adresár v /usr/share/sddm/themes"
        fi
    else
        session_check "SDDM téma" 1 "chýba ${sddmConf}"
    fi

    local openspecBin
    openspecBin="$(command -v openspec || true)"
    if [[ -z "${openspecBin}" && -x "${HOME}/.local/bin/openspec" ]]; then
        openspecBin="${HOME}/.local/bin/openspec"
    fi
    if [[ -n "${openspecBin}" ]]; then
        session_check "OpenSpec CLI" 0 "$("${openspecBin}" --version 2>/dev/null | head -1)"
    else
        session_check "OpenSpec CLI" 1 "nie je na PATH"
    fi
}

#----------------#
# režim: verify  #
#----------------#

run_verify() {
    print_log -sec "setup" -b "revízia  :: " "$(git -C "${cloneDir}" rev-parse --short HEAD 2>/dev/null || echo "bez gitu")"
    print_log -sec "setup" -b "checkout :: " "${cloneDir}"
    print_log -sec "setup" -b "domov    :: " "${HOME}"

    collect_drift

    if [[ ${manifestPresent} -eq 0 ]]; then
        print_log -r "[verify] " -crit "ERROR" "na stroji nie je manifest deez-dots — nič ešte nebolo nasadené"
        print_log -y "[verify] " -b "ďalej :: " "spusti $(basename "$0") (deploy), potom over znova"
        check_session
        return 1
    fi

    local status=0

    if [[ ${#deployMissing[@]} -gt 0 ]]; then
        print_log -r "[verify] " -b "chýba :: " "${#deployMissing[@]} nasadených súborov"
        status=1
    fi
    if [[ ${#deployDiffering[@]} -gt 0 ]]; then
        print_log -r "[verify] " -b "rozdiel :: " "${#deployDiffering[@]} nasadených súborov sa líši od Configs/"
        status=1
    fi

    if [[ ${status} -ne 0 ]]; then
        echo "  podľa adresára (počet súborov):"
        print_dir_summary

        local first="${deployMissing[0]:-${deployDiffering[0]}}"
        if [[ ${#deployMissing[@]} -gt 0 ]]; then
            print_log -y "[verify] " -b "prvý :: " "${HOME}/${first} chýba (v Configs/ je)"
        else
            print_log -y "[verify] " -b "prvý :: " "${HOME}/${first} sa líši od Configs/${first}"
        fi
        print_log -y "[verify] " -b "oprava :: " "spusti $(basename "$0") (alebo zmenu prenes do repa, ak je novšia live verzia)"
    fi

    if [[ ${#userNotes[@]} -gt 0 ]]; then
        print_log -y "[verify] " -b "poznámka :: " "${#userNotes[@]} súborov patrí používateľovi (preserve), nepočíta sa ako chyba:"
        printf '    %s\n' "${userNotes[@]}"
    fi
    if [[ ${#generatedNotes[@]} -gt 0 ]]; then
        print_log -y "[verify] " -b "poznámka :: " "${#generatedNotes[@]} súborov prepisuje téma alebo služba, nepočíta sa ako chyba:"
        printf '    %s\n' "${generatedNotes[@]}"
    fi
    if [[ ${#staleNotes[@]} -gt 0 ]]; then
        print_log -y "[verify] " -b "poznámka :: " "${#staleNotes[@]} súborov už v repe nie je, ďalší deploy ich odstráni:"
        printf '    %s\n' "${staleNotes[@]}"
    fi

    check_session

    if [[ ${status} -ne 0 || ${session_failures} -ne 0 ]]; then
        return 1
    fi

    print_log -g "[verify] " -b "hotovo :: " "stroj sedí s nasadeným stromom (revízia $(git -C "${cloneDir}" rev-parse --short HEAD 2>/dev/null || echo "?"))"
    return 0
}

#----------------#
# režim: deploy  #
#----------------#

openspec_note() {
    local bin
    bin="$(command -v openspec || true)"
    if [[ -z "${bin}" && -x "${HOME}/.local/bin/openspec" ]]; then
        bin="${HOME}/.local/bin/openspec"
    fi

    if [[ -n "${bin}" ]]; then
        print_log -g "[OPENSPEC] " -b "ok :: " "$("${bin}" --version 2>/dev/null | head -1)"
        return 0
    fi

    print_log -y "[OPENSPEC] " -b "chýba :: " "OpenSpec CLI nie je nainštalované, plánovanie zmien bez neho nepôjde"
    cat <<'EOF'
    curl -fsSL https://raw.githubusercontent.com/Fission-AI/OpenSpec/main/scripts/binary/install.sh | sh
    # alebo pripnutá verzia:
    OPENSPEC_VERSION=v1.15.0 curl -fsSL https://raw.githubusercontent.com/Fission-AI/OpenSpec/main/scripts/binary/install.sh | sh
EOF
    return 1
}

# install.sh aj install_pst.sh končia otázkami (reboot, flatpak, SDDM). Človek
# v termináli dostane svoj vstup. Bez terminálu (CI, zavretý stdin) by read
# zlyhal a set -e by zhodil inak úspešný deploy, preto tam ide prázdny riadok:
# pre tieto otázky to znamená "nie / nechaj default".
run_interactive() {
    if [[ -t 0 ]]; then
        "$@"
    else
        "$@" < <(yes '')
    fi
}

run_deploy() {
    local -a installFlags=(-r)
    ((dryRun)) && installFlags+=(-t)

    print_log -sec "setup" -b "revízia  :: " "$(git -C "${cloneDir}" rev-parse --short HEAD 2>/dev/null || echo "bez gitu")"
    print_log -sec "setup" -b "checkout :: " "${cloneDir}"
    print_log -sec "setup" -b "domov    :: " "${HOME}"
    print_log -sec "setup" -b "zálohy   :: " "${HOME}/.config/cfg_backups"
    print_log -sec "setup" -b "systém   :: " "/etc/sddm.conf.d, /usr/share/sddm/themes (len keď SDDM ešte nie je nastavené)"

    if [[ -n "$(git -C "${cloneDir}" status --porcelain 2>/dev/null)" ]]; then
        print_log -y "[setup] " -b "pozor :: " "checkout má necommitnuté zmeny, nasadí sa aj to, čo je len v pracovnom strome"
    fi

    if ((dryRun)); then
        print_log -y "[setup] " -b "dry-run :: " "install.sh dostane -t, nič sa neprepíše"
    fi

    # Čo sa bude prepisovať, ešte predtým, než install.sh -r niečo zmení
    collect_drift
    if [[ ${manifestPresent} -eq 0 ]]; then
        print_log -sec "deploy" -b "prvý deploy :: " "manifest deez-dots ešte neexistuje, nasadí sa celý strom"
    elif [[ ${#deployMissing[@]} -gt 0 ]]; then
        print_log -sec "deploy" -b "chýba :: " "${#deployMissing[@]} nasadených súborov sa obnoví"
    fi
    if [[ ${#deployDiffering[@]} -gt 0 ]]; then
        print_log -sec "deploy" -b "prepíše sa :: " "${#deployDiffering[@]} existujúcich súborov sa líši od Configs/"
        printf '    %s\n' "${deployDiffering[@]}"
    fi
    if [[ ${#userNotes[@]} -gt 0 || ${#generatedNotes[@]} -gt 0 ]]; then
        print_log -sec "deploy" -b "nechá sa :: " "$(( ${#userNotes[@]} + ${#generatedNotes[@]} )) súborov (preserve alebo generované témou) sa neprepisuje"
    fi
    if [[ ${#staleNotes[@]} -gt 0 ]]; then
        print_log -sec "deploy" -b "odstráni sa :: " "${#staleNotes[@]} súborov už v repe nie je"
    fi

    print_log -sec "deploy" -b "krok 1/2 :: " "install.sh ${installFlags[*]}"
    if ! run_interactive "${scrDir}/install.sh" "${installFlags[@]}"; then
        print_log -r "[deploy] " -crit "ERROR" "install.sh skončil s chybou, zvyšok sa preskakuje"
        print_log -y "[deploy] " -b "tip :: " "ak chýbali balíky, spusti Scripts/install.sh -i -s a potom tento skript znova"
        return 1
    fi

    print_log -sec "deploy" -b "krok 2/2 :: " "install_pst.sh"
    export flg_DryRun="${dryRun}"
    if ! run_interactive "${scrDir}/install_pst.sh"; then
        print_log -r "[deploy] " -crit "ERROR" "install_pst.sh skončil s chybou"
        return 1
    fi

    openspec_note || true

    cat <<EOF

Zostáva na teba (skript to za teba neháda):
  1. balíky a systémové služby, ak ešte nie sú: ${scrDir}/install.sh -i -s
  2. reštart, ak ho HyDE po deployi odporúčal
  3. odhlás sa a prihlás sa; pri prvom prihlásení vyber tému a wallpaper
  4. push na GitHub:           gh auth login

Stav overíš bez zmien:  $(basename "$0") --verify
EOF

    return 0
}

case "${mode}" in
verify) run_verify ;;
deploy) run_deploy ;;
esac
