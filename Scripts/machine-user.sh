#!/usr/bin/env bash
#|---/ /+---------------------------------------------------+---/ /|#
#|--/ /-| Priraví účet, ktorý má dostať tento desktop       |--/ /-|#
#|-/ /--| evan70/HyDE (fork of HyDE-Project/HyDE)            |-/ /--|#
#|/ /---+---------------------------------------------------+/ /---|#
#
# machine-setup.sh predpokladá, že účet existuje a je prihlásený — zapisuje
# len do jeho $HOME. Tento skript je krok pred ním: povie, či je účet na
# tento desktop pripravený, a na požiadanie ho vytvorí.
#
# --check (default) nič nemení. Overuje:
#   - účet existuje a nie je to root
#   - sudo funguje bez pýtania hesla (install.sh -i ho potrebuje)
#   - $HOME existuje, patrí účtu a je preň zapisovateľný
#   - login shell je uvedený v /etc/shells
#   - heslo je nastavené (inak sa cez SDDM neprihlási)
#   - skupiny, ktoré tento desktop používa
#   - SDDM ponúka hyprland.desktop
#
# --create chýbajúci účet vytvorí (useradd -m) a doplní chýbajúce skupiny.
# Existujúcemu účtu nemení meno, domov ani shell — len skupiny. Heslo ide
# výhradne cez interaktívne sudo passwd; bez terminálu sa vypíše príkaz.
#
# Skript sa púšťa ako bežný používateľ, ktorý má sudo. Ako root odmietne
# bežať, lebo jeho otázky (domov, session, sudo) sú o používateľovi, nie
# o uid 0, a deploy potom musí bežať ako ten istý účet.
#
# Poradie na druhom stroji (pozadie v SYNC.md):
#   git clone … → machine-user.sh --check → --create → install.sh -i -s
#   → machine-setup.sh

set -eo pipefail

scrDir="$(dirname "$(realpath "$0")")"
cloneDir="$(dirname "${scrDir}")"
export CLONE_DIR="${cloneDir}"

# pkg_installed, print_log a shell_listed z upstreamu; nič neinštalujú
# shellcheck disable=SC1091
source "${scrDir}/global_fn.sh"

# Skupiny, ktoré tento desktop používa. Referencia je "id hypr" na stroji,
# kde HyDE beží: wheel (sudo), video a render (GPU, DRM), input (zariadenia),
# audio (PipeWire), storage (udisks).
requiredGroups=(wheel video render input audio storage)

preferredShell="/bin/zsh"
fallbackShell="/bin/bash"
sessionFile="/usr/share/wayland-sessions/hyprland.desktop"
dmLink="/etc/systemd/system/display-manager.service"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [NAME]

  --check       (default) nič nemení; overí, či je účet pripravený na tento desktop
  --create      chýbajúci účet vytvorí (useradd -m) a doplní chýbajúce skupiny
  --name NAME   účet, o ktorý ide (default hypr); to isté ako NAME na konci
  -h, --help    táto nápoveda

Exit status: 0 = v poriadku, 1 = niečo chýba alebo zlyhalo, 2 = zlá voľba.
EOF
}

mode="check"
name=""
while (($#)); do
    case "$1" in
    --check) mode="check" ;;
    --create) mode="create" ;;
    --name)
        if [[ $# -lt 2 ]]; then
            echo "CHYBA: --name chce meno účtu." >&2
            usage >&2
            exit 2
        fi
        name="$2"
        shift
        ;;
    --name=*) name="${1#*=}" ;;
    -h | --help)
        usage
        exit 0
        ;;
    -*)
        echo "Neznáma voľba: $1" >&2
        usage >&2
        exit 2
        ;;
    *)
        if [[ -n "${name}" && "${name}" != "$1" ]]; then
            echo "CHYBA: účet je zadaný dvakrát (${name} a $1)." >&2
            usage >&2
            exit 2
        fi
        name="$1"
        ;;
    esac
    shift
done

name="${name:-hypr}"

if [[ ! "${name}" =~ ^[a-z_][a-z0-9_-]*$ || ${#name} -gt 32 ]]; then
    echo "CHYBA: '${name}' nie je platné meno účtu (malé písmená, číslice, _ a -, max 32 znakov)." >&2
    exit 2
fi

if [[ ${EUID} -eq 0 ]]; then
    echo "CHYBA: tento skript sa púšťa ako účet, ktorý má desktop dostať, nie ako root." >&2
    echo "       Skontroluj konkrétny účet: $(basename "$0") --check --name ${name}" >&2
    exit 1
fi

#----------------#
# pomocné        #
#----------------#

sudo_ready() {
    sudo -n true >/dev/null 2>&1
}

check_failures=0

check_line() {
    local label="$1" status="$2" detail="${3:-}"

    if [[ "${status}" -eq 0 ]]; then
        print_log -g "[ok]   " -b " :: " "${label}${detail:+ (${detail})}"
    else
        print_log -r "[chyba]" -b " :: " "${label}${detail:+ (${detail})}"
        check_failures=$((check_failures + 1))
    fi
}

note() {
    print_log -y "poznámka :: " -b "$1"
}

group_present() {
    getent group "$1" >/dev/null 2>&1
}

has_group() {
    local needle="$1" grp
    local IFS=$' \t\n'

    # Neúvodzované zámerne: id -nG vracia mená oddelené medzerou.
    for grp in $(id -nG "${name}" 2>/dev/null); do
        [[ "${grp}" == "${needle}" ]] && return 0
    done
    return 1
}

missing_groups() {
    local grp
    local -a out=()

    for grp in "${requiredGroups[@]}"; do
        group_present "${grp}" || continue
        has_group "${grp}" || out+=("${grp}")
    done

    [[ ${#out[@]} -eq 0 ]] && return 0
    printf '%s\n' "${out[@]}"
}

join_by_commas() {
    local IFS=,
    printf '%s' "$*"
}

same_shell() {
    local a b

    a="$(realpath -e "$1" 2>/dev/null)" || return 1
    b="$(realpath -e "$2" 2>/dev/null)" || return 1
    [[ "${a}" == "${b}" ]]
}

# Ktorý display manager systém naozaj spustí. `systemctl enable sddm` zapíše
# len alias display-manager.service; keď na stroji ostal LightDM z XFCE,
# ukazuje naň a prihlásenie skončí v XFCE, hoci sddm je nainštalované.
active_display_manager() {
    local target

    [[ -e "${dmLink}" ]] || return 1
    target="$(readlink -f "${dmLink}" 2>/dev/null)" || return 1
    [[ -n "${target}" ]] || return 1
    basename "${target}" .service
}

pick_shell() {
    if shell_listed "${preferredShell}"; then
        printf '%s' "${preferredShell}"
    else
        printf '%s' "${fallbackShell}"
    fi
}

# P = použiteľné heslo, L = uzamknuté, NP = žiadne. Cudzí účet sa bez roota
# nedá prečítať, preto druhý pokus cez sudo (bez pýtania hesla).
password_state() {
    local state=""

    state="$(passwd -S "${name}" 2>/dev/null | awk '{print $2}')" || true
    if [[ -z "${state}" ]] && sudo_ready; then
        state="$(sudo -n passwd -S "${name}" 2>/dev/null | awk '{print $2}')" || true
    fi

    printf '%s' "${state}"
}

report_missing_account() {
    local grp

    check_line "nie je root" 1 "účet neexistuje"
    check_line "sudo" 1 "účet neexistuje"
    check_line "domov" 1 "účet neexistuje"
    check_line "shell" 1 "účet neexistuje"
    check_line "heslo" 1 "účet neexistuje"
    for grp in "${requiredGroups[@]}"; do
        check_line "skupina ${grp}" 1 "účet neexistuje"
    done
    check_line "SDDM ponúka hyprland" 1 "účet neexistuje"
    check_line "SDDM je display manager" 1 "účet neexistuje"
}

#----------------#
# režim: check   #
#----------------#

run_check() {
    local entry uid home shell owner mode_bits owner_digit state grp dm

    check_failures=0

    print_log -sec "účet" -b "meno     :: " "${name}"
    print_log -sec "účet" -b "systém   :: " "$(uname -srm)"

    if ! entry="$(getent passwd "${name}" 2>/dev/null)"; then
        check_line "účet existuje" 1 "účet neexistuje"
        report_missing_account
        note "vytvoríš ho: $(basename "$0") --create --name ${name}"
        return 1
    fi

    IFS=: read -r _ _ uid _ _ home shell <<<"${entry}"

    check_line "účet existuje" 0 "${name}, uid ${uid}"

    if [[ "${uid}" -eq 0 ]]; then
        check_line "nie je root" 1 "uid 0"
    else
        check_line "nie je root" 0
    fi

    if sudo_ready; then
        check_line "sudo" 0 "sudo -n funguje"
    else
        check_line "sudo" 1 "bez hesla sa nedá overiť, raz spusti: sudo -v"
    fi

    if [[ ! -d "${home}" ]]; then
        check_line "domov" 1 "${home} neexistuje"
    else
        read -r owner mode_bits <<<"$(stat -c '%U %a' "${home}")"
        mode_bits="${mode_bits: -3}"
        owner_digit="${mode_bits:0:1}"
        if [[ "${owner}" != "${name}" ]]; then
            check_line "domov" 1 "${home} patrí ${owner}, nie ${name}"
        elif [[ -z "${owner_digit}" ]]; then
            check_line "domov" 1 "práva ${home} sa nedajú prečítať"
        elif (( (8#${owner_digit} & 2) == 0 )); then
            check_line "domov" 1 "${home} nie je zapisovateľný pre vlastníka (${mode_bits})"
        else
            check_line "domov" 0 "${home}"
        fi
    fi

    if [[ ! -x "${shell}" ]]; then
        check_line "shell" 1 "${shell} neexistuje"
    elif shell_listed "${shell}"; then
        check_line "shell" 0 "${shell}"
        if ! same_shell "${shell}" "${preferredShell}" && shell_listed "${preferredShell}"; then
            note "shell je ${shell}; HyDE je pripravené na ${preferredShell}: chsh -s ${preferredShell} ${name}"
        fi
    else
        check_line "shell" 1 "${shell} nie je v /etc/shells"
    fi

    state="$(password_state)"
    case "${state}" in
    P) check_line "heslo" 0 "nastavené" ;;
    L) check_line "heslo" 1 "uzamknuté, cez SDDM sa neprihlásiš: sudo passwd ${name}" ;;
    NP | "") check_line "heslo" 1 "nie je nastavené: sudo passwd ${name}" ;;
    *) check_line "heslo" 1 "neznámy stav '${state}': sudo passwd ${name}" ;;
    esac

    for grp in "${requiredGroups[@]}"; do
        if ! group_present "${grp}"; then
            note "skupina ${grp} na tomto systéme nie je, preskakuje sa"
        elif has_group "${grp}"; then
            check_line "skupina ${grp}" 0
        else
            check_line "skupina ${grp}" 1 "chýba: sudo usermod -aG ${grp} ${name}"
        fi
    done

    if [[ -f "${sessionFile}" ]]; then
        check_line "SDDM ponúka hyprland" 0 "hyprland.desktop"
    else
        check_line "SDDM ponúka hyprland" 1 "chýba ${sessionFile} (balíky: install.sh -i -s)"
    fi

    # Bez nainštalovaného sddm `systemctl enable sddm` zlyhá a boot ostane na
    # starom manažéri — ten istý výsledok ako LightDM, ktorý link drží.
    if ! command -v sddm >/dev/null 2>&1; then
        check_line "SDDM je display manager" 1 "sddm nie je nainštalované (install.sh -i -s, alebo sudo pacman -S sddm)"
    else
        dm="$(active_display_manager || true)"
        case "${dm}" in
        sddm) check_line "SDDM je display manager" 0 "display-manager.service" ;;
        "") check_line "SDDM je display manager" 1 "display-manager.service nie je nastavený: sudo systemctl enable sddm" ;;
        *) check_line "SDDM je display manager" 1 "štartuje ${dm}: sudo systemctl disable ${dm} && sudo systemctl enable sddm" ;;
        esac
    fi

    if [[ ${check_failures} -eq 0 ]]; then
        print_log -g "[check] " -b "hotovo :: " "účet ${name} je pripravený na deploy"
        return 0
    fi

    print_log -r "[check] " -b "chyba :: " "${check_failures} podmienok nie je splnených"
    return 1
}

#----------------#
# režim: create  #
#----------------#

ensure_groups() {
    local list
    local -a missing=()

    mapfile -t missing < <(missing_groups)

    if [[ ${#missing[@]} -eq 0 ]]; then
        print_log -g "[ok]   " -b " :: " "skupiny sedia"
        return 0
    fi

    list="$(join_by_commas "${missing[@]}")"
    print_log -sec "účet" -b "doplní :: " "sudo usermod -aG ${list} ${name}"
    if ! sudo usermod -aG "${list}" "${name}"; then
        print_log -r "[účet] " -crit "ERROR" "skupiny sa nepodarilo doplniť"
        return 1
    fi
    print_log -g "[ok]   " -b " :: " "doplnené skupiny: ${list}"
}

run_create() {
    local entry uid shell list grp
    local -a grantable=() absent=() primary=()

    if entry="$(getent passwd "${name}" 2>/dev/null)"; then
        IFS=: read -r _ _ uid _ _ _ _ <<<"${entry}"
        print_log -sec "účet" -b "existuje :: " "${name} (uid ${uid})"
        ensure_groups || return 1

        shell="${entry##*:}"
        if ! same_shell "${shell}" "$(pick_shell)"; then
            note "shell ${shell} nechávam; zmeníš ho cez: chsh -s $(pick_shell) ${name}"
        fi
        return 0
    fi

    for grp in "${requiredGroups[@]}"; do
        if group_present "${grp}"; then
            grantable+=("${grp}")
        else
            absent+=("${grp}")
        fi
    done

    # Skupina rovnakého mena mohla zostať po starom účte; vtedy sa použije
    # ako primárna, inak ju -U vytvorí spolu s účtom.
    if group_present "${name}"; then
        primary=(-g "${name}")
    else
        primary=(-U)
    fi

    shell="$(pick_shell)"
    if [[ "${shell}" != "${preferredShell}" ]]; then
        note "${preferredShell} nie je v /etc/shells, použije sa ${fallbackShell}"
    fi
    if [[ ${#absent[@]} -gt 0 ]]; then
        note "tieto skupiny systém nepozná, preskakujú sa: ${absent[*]}"
    fi

    if [[ ${#grantable[@]} -gt 0 ]]; then
        list="$(join_by_commas "${grantable[@]}")"
        print_log -sec "účet" -b "vytvorí :: " "sudo useradd -m ${primary[*]} -G ${list} -s ${shell} ${name}"
        if ! sudo useradd -m "${primary[@]}" -G "${list}" -s "${shell}" "${name}"; then
            print_log -r "[účet] " -crit "ERROR" "useradd zlyhal, účet ${name} nevznikol"
            return 1
        fi
    else
        print_log -sec "účet" -b "vytvorí :: " "sudo useradd -m ${primary[*]} -s ${shell} ${name}"
        if ! sudo useradd -m "${primary[@]}" -s "${shell}" "${name}"; then
            print_log -r "[účet] " -crit "ERROR" "useradd zlyhal, účet ${name} nevznikol"
            return 1
        fi
    fi

    print_log -g "[ok]   " -b " :: " "účet ${name} vznikol"

    if [[ -t 0 ]]; then
        print_log -sec "účet" -b "heslo :: " "sudo passwd ${name}"
        if ! sudo passwd "${name}"; then
            print_log -r "[účet] " -crit "ERROR" "heslo sa nepodarilo nastaviť"
            return 1
        fi
    else
        note "heslo nie je nastavené a bez terminálu sa nepýtam: sudo passwd ${name}"
    fi

    cat <<EOF

Zostáva na teba (skript to za teba neháda):
  1. heslo, ak sa nenastavilo vyššie:  sudo passwd ${name}
  2. balíky a systémové služby:        ${scrDir}/install.sh -i -s
  3. deploy do domova účtu:            ${scrDir}/machine-setup.sh   (ako ${name})
  4. prvý login cez SDDM a voľba témy

Stav overíš bez zmien:  $(basename "$0") --check --name ${name}
EOF

    return 0
}

status=0
case "${mode}" in
check) run_check || status=$? ;;
create) run_create || status=$? ;;
esac

exit "${status}"
