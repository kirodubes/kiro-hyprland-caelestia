#!/bin/bash
set -euo pipefail
#####################################################################
# Author    : Erik Dubois
# Website   : https://kiroproject.be
#####################################################################
#
#   DO NOT JUST RUN THIS. EXAMINE AND JUDGE. RUN AT YOUR OWN RISK.
#
#   Purpose:
#   Checks a running "Kiro Hyprland Caelestia" session on a test box
#   (QEMU VM or real metal): packages, shipped files, the config contract
#   with the premium app, the shell, notifications, global shortcuts,
#   theming, idle and the shared pieces (logout, Variety, installer).
#   Run it as the session user, from SSH or a terminal; it borrows the
#   session's environment from the running Hyprland. Prints PASS / WARN /
#   FAIL per check and exits 1 when anything FAILs.
#   --active also changes the wallpaper once (and puts it back) to check
#   that a wallpaper change keeps the GTK/icon/light-dark choices.
#
#   Why: every Kiro Wayland edition so far broke in one of these places
#   (mako stealing notifications, a stray Variety window, logout doing
#   nothing, QS_CONFIG_PATH leaking, lock-on-idle defaults, a launcher
#   hiding an invalid .desktop entry, a shell resetting the GTK theme).
#   One script checks them all on every test round.
#
#####################################################################

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

#####################################################################
# Colors
#####################################################################
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    CYAN="$(tput setaf 6)"
    RESET="$(tput sgr0)"
else
    RED="" GREEN="" YELLOW="" BLUE="" CYAN="" RESET=""
fi

#####################################################################
# Logging
#####################################################################
log_section() { echo; echo "${GREEN}############ $* ############${RESET}"; }
log_info()    { echo "${BLUE}############ $* ############${RESET}"; }
log_warn()    { echo "${YELLOW}############ $* ############${RESET}"; }
log_error()   { echo "${RED}############ $* ############${RESET}"; }
log_success() { echo "${GREEN}############ $* ############${RESET}"; }

on_error() {
    echo "${RED}ERROR on line $1: $2${RESET}"
    sleep 10
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

#####################################################################
# Functions
#####################################################################
ED="kiro-hyprland-caelestia"
CFG="$HOME/.config/$ED"
LUA="$CFG/hyprland.lua"
CAE="$HOME/.config/caelestia"
ACTIVE=0
NPASS=0 NWARN=0 NFAIL=0

pass() { NPASS=$((NPASS + 1)); echo "${GREEN}PASS${RESET} $*"; }
warn() { NWARN=$((NWARN + 1)); echo "${YELLOW}WARN${RESET} $*"; }
fail() { NFAIL=$((NFAIL + 1)); echo "${RED}FAIL${RESET} $*"; }

# check "<label>" <command...>: PASS when the command succeeds, FAIL otherwise.
check() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}

# Same, but a WARN instead of a FAIL (expected to fail until a later build).
check_warn() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then pass "$label"; else warn "$label"; fi
}

json_get() {
    python3 -I -c 'import json,sys
d=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."):
    d=d[int(k)] if isinstance(d,list) else d[k]
print(json.dumps(d))' "$1" "$2"
}

import_session_env() {
    local pid sig
    pid="$(pgrep -u "$(id -u)" -x Hyprland | head -1 || true)"
    if [[ -z "$pid" ]]; then
        log_error "No Hyprland running for $(id -un): log in to Kiro Hyprland Caelestia first"
        exit 1
    fi
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    # Hyprland's own environ predates the signature; the newest socket dir is the live one.
    sig="$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1 || true)"
    export HYPRLAND_INSTANCE_SIGNATURE="$sig"
    export WAYLAND_DISPLAY="$(tr '\0' '\n' < "/proc/$pid/environ" | sed -n 's/^WAYLAND_DISPLAY=//p' | head -1)"
    [[ -n "$WAYLAND_DISPLAY" ]] || export WAYLAND_DISPLAY="wayland-1"
    HYPR_PID="$pid"
}

check_packages() {
    log_section "Packages"
    local p
    for p in "$ED" caelestia-shell caelestia-cli quickshell qt6-m3shapes-git ttf-rubik-vf \
        xdg-desktop-portal-hyprland polkit-gnome cliphist; do
        check "installed: $p" pacman -Q "$p"
    done
    # caelestia-shell is patched to extra's quickshell; -git would conflict with every other Quickshell edition.
    if pacman -Q quickshell-git >/dev/null 2>&1; then fail "quickshell-git is installed (should be extra's quickshell)"
    else pass "no quickshell-git"; fi
    if pacman -Qi caelestia-shell | grep -E '^Depends On' | grep -q 'quickshell-git'; then
        fail "caelestia-shell still depends on quickshell-git (Kiro patch missing)"
    else pass "caelestia-shell depends on extra's quickshell"; fi
    local ver
    ver="$(pacman -Q quickshell 2>/dev/null | awk '{print $2}')"
    if [[ -n "$ver" ]] && [[ "$(vercmp "$ver" 0.3.2)" -ge 0 ]]; then pass "quickshell $ver >= 0.3.2"
    else fail "quickshell ${ver:-missing} < 0.3.2"; fi
}

check_files() {
    log_section "Shipped files"
    local f
    for f in /usr/bin/$ED-session /usr/bin/$ED-hide-upstream-session; do
        check "executable: $f" test -x "$f"
    done
    local desk="/usr/share/wayland-sessions/$ED.desktop"
    check "session entry: $desk" test -f "$desk"
    # impasto's strict launcher hid an entry with two Type= lines (2026-11-04).
    if command -v desktop-file-validate >/dev/null; then
        local out
        # DesktopNames is the session-file key every Kiro Hyprland edition uses; the validator only knows Application keys.
        out="$(desktop-file-validate "$desk" 2>&1 | grep -v -e 'hint:' -e '"DesktopNames"' || true)"
        if [[ -z "$out" ]]; then pass "desktop-file-validate $ED.desktop"; else fail "desktop-file-validate: $out"; fi
    else
        warn "desktop-file-validate missing (desktop-file-utils); entry not validated"
    fi
    check "session Exec runs the wrapper" grep -qE "^Exec=(/usr/bin/)?$ED-session$" "$desk"
    check "golden copy /usr/share/kiro/$ED" test -f "/usr/share/kiro/$ED/$ED/hyprland.lua"
    check "mako drop-in installed" test -f "/usr/lib/systemd/user/mako.service.d/$ED.conf"
    for f in "$LUA" "$CFG/keybindings.txt" "$CFG/bg/kiro.jpg" "$CFG/scripts/firstrun-wallpaper.sh" \
        "$CFG/scripts/import-gsettings.sh" "$CAE/shell.json" "$CAE/cli.json"; do
        check "in home: ${f#"$HOME"/}" test -f "$f"
    done
    check "firstrun-wallpaper.sh executable" test -x "$CFG/scripts/firstrun-wallpaper.sh"
    check "import-gsettings.sh executable" test -x "$CFG/scripts/import-gsettings.sh"
    # On an installed system kiro_final strips the live-ISO installer line (and its comments): expected.
    local delta
    delta="$(diff "/usr/share/kiro/$ED/$ED/hyprland.lua" "$LUA" 2>/dev/null | grep '^[<>]' \
        | grep -vE '^< *--|^< on_start\(.*bootmnt.*calamares' || true)"
    if cmp -s "$LUA" "/usr/share/kiro/$ED/$ED/hyprland.lua"; then pass "home hyprland.lua matches the package"
    elif [[ -z "$delta" ]]; then pass "home hyprland.lua matches the package (installer line stripped by kiro_final)"
    else warn "home hyprland.lua differs from the package (user change, or skel from an older build)"; fi
}

check_config_contract() {
    log_section "Config contract (premium app)"
    check "appearance loader in hyprland.lua" grep -q 'pcall(require, "appearance")' "$LUA"
    local last
    last="$(grep -v '^[[:space:]]*$' "$LUA" | tail -2 | head -1)"
    if [[ "$last" == *'pcall(require, "appearance")'* ]]; then pass "appearance loader is at the end"
    else fail "appearance loader is not the last lines of hyprland.lua"; fi
    check "kirotux_apps override" grep -q 'pcall(require, "kirotux_apps")' "$LUA"
    check "kb_layout from the installer (vconsole)" grep -q 'installer_keyboard' "$LUA"
    check "Ctrl+Alt+H opens the premium app (or its hint)" grep -qE 'CTRL \+ ALT \+ H".*kiro-premium-hint' "$LUA"
    check "Super+Ctrl+S opens kiro-keybindings" grep -q 'kiro-keybindings' "$LUA"
    check "caelestia shell started by the config" grep -q 'caelestia shell -d' "$LUA"
    # Never QS_CONFIG_PATH: it leaks into the systemd user env and hijacks other Quickshell editions.
    if grep -q 'QS_CONFIG_PATH' "$LUA"; then fail "hyprland.lua sets QS_CONFIG_PATH"; else pass "no QS_CONFIG_PATH in hyprland.lua"; fi
    if systemctl --user show-environment | grep -q '^QS_CONFIG_PATH='; then fail "QS_CONFIG_PATH in the systemd user env"
    else pass "no QS_CONFIG_PATH in the systemd user env"; fi
    if command -v luac >/dev/null; then check "hyprland.lua parses (luac -p)" luac -p "$LUA"; fi
}

check_caelestia_config() {
    log_section "Caelestia config (Kiro idle rule, theming)"
    check "shell.json is valid JSON" python3 -I -m json.tool "$CAE/shell.json"
    check "cli.json is valid JSON" python3 -I -m json.tool "$CAE/cli.json"
    # Kiro idle rule: screen off after 15 min, no idle lock, no idle suspend. Caelestia's own
    # defaults lock at 3 min and suspend at 10, so the shipped timeouts must replace them.
    local idle
    idle="$(json_get "$CAE/shell.json" general.idle.timeouts 2>/dev/null || echo MISSING)"
    if [[ "$idle" == MISSING ]]; then
        fail "shell.json has no general.idle.timeouts (Caelestia default = lock at 3 min)"
    else
        if grep -qiE 'lock|suspend|hibernate' <<<"$idle"; then fail "idle timeouts lock or suspend: $idle"
        else pass "idle timeouts have no lock/suspend"; fi
        if grep -q '900' <<<"$idle" && grep -q 'dpms off' <<<"$idle"; then pass "screen off at 900 s"
        else warn "no 900 s dpms off in idle timeouts: $idle"; fi
    fi
    local wd
    wd="$(json_get "$CAE/shell.json" paths.wallpaperDir 2>/dev/null || echo '""')"
    if [[ "$wd" == '"/usr/share/backgrounds/kiro"' ]]; then pass "wallpaperDir = /usr/share/backgrounds/kiro"
    else fail "wallpaperDir = $wd"; fi
    local hypr
    hypr="$(json_get "$CAE/cli.json" theme.enableHypr 2>/dev/null || echo missing)"
    if [[ "$hypr" == false ]]; then pass "cli.json theme.enableHypr false (Kiro owns hyprland.lua)"
    else fail "cli.json theme.enableHypr = $hypr"; fi
    local hook
    hook="$(json_get "$CAE/cli.json" theme.postHook 2>/dev/null || json_get "$CAE/cli.json" postHook 2>/dev/null || echo '""')"
    hook="${hook//\"/}"
    hook="${hook/#\~/$HOME}"
    if [[ -n "$hook" && -x "${hook%% *}" ]]; then pass "postHook runs an existing script"
    else fail "postHook missing or not executable: '$hook' (the CLI would leave adw-gtk3-dark/Papirus behind)"; fi
}

check_session() {
    log_section "Running session"
    if tr '\0' ' ' < "/proc/$HYPR_PID/cmdline" | grep -q -- "--config $LUA"; then pass "Hyprland runs this edition's config"
    else fail "Hyprland is not running $LUA"; fi
    local errs
    errs="$(hyprctl configerrors 2>&1 | grep -v '^[[:space:]]*$' || true)"
    if [[ -z "$errs" ]]; then pass "hyprctl configerrors empty"; else fail "config errors: $errs"; fi
    local n
    n="$(pgrep -u "$(id -u)" -fc '^qs -c caelestia' || true)"
    if [[ "$n" == 1 ]]; then pass "one caelestia shell (qs -c caelestia)"
    elif [[ "$n" == 0 ]]; then fail "caelestia shell is not running"
    else fail "$n caelestia shells running (started twice)"; fi
    check "polkit agent running" pgrep -u "$(id -u)" -f polkit-gnome-authentication-agent-1
    check "cliphist text watcher" pgrep -u "$(id -u)" -f 'wl-paste --type text --watch cliphist'
    check "cliphist image watcher" pgrep -u "$(id -u)" -f 'wl-paste --type image --watch cliphist'
    check "xdg-desktop-portal-hyprland running" pgrep -u "$(id -u)" -f xdg-desktop-portal-hyprland
    if pgrep -u "$(id -u)" -x hypridle >/dev/null; then warn "hypridle runs (Caelestia owns idle; two idle owners)"
    else pass "no hypridle (Caelestia owns idle)"; fi
}

check_notifications() {
    log_section "Notifications"
    # mako (kiro-wayland-dotfiles) is D-Bus activated and took the name from impasto every login.
    local owner
    owner="$(busctl --user status org.freedesktop.Notifications 2>/dev/null | sed -n 's/^Comm=//p')"
    if [[ "$owner" == qs ]]; then pass "org.freedesktop.Notifications owned by qs"
    else fail "org.freedesktop.Notifications owned by '${owner:-nobody}' (expected qs)"; fi
    if systemctl --user is-active --quiet mako.service; then fail "mako.service is active"
    else pass "mako.service inactive"; fi
    if pgrep -u "$(id -u)" -x mako >/dev/null; then fail "a mako process runs"; else pass "no mako process"; fi
}

check_shortcuts() {
    log_section "Global shortcuts and binds"
    local gs names name
    gs="$(hyprctl globalshortcuts 2>/dev/null || true)"
    names="$(grep -o 'caelestia("[A-Za-z]*")' "$LUA" | sed 's/caelestia("\(.*\)")/\1/' | sort -u)"
    for name in $names; do
        if grep -q "caelestia:$name" <<<"$gs"; then pass "shell registered caelestia:$name"
        else fail "caelestia:$name is bound but the shell did not register it"; fi
    done
    local dups
    dups="$(hyprctl binds -j 2>/dev/null | python3 -I -c '
import json, sys, collections
c = collections.Counter((b.get("modmask"), b.get("key"), b.get("keycode"), b.get("submap", ""), b.get("release", False))
                        for b in json.load(sys.stdin) if not b.get("mouse"))
print(" ".join(f"{m}+{k or kc}" for (m, k, kc, s, r), n in c.items() if n > 1))' || echo ERR)"
    if [[ -z "$dups" ]]; then pass "no duplicate binds"; else fail "duplicate binds: $dups"; fi
}

check_qml_log() {
    log_section "Shell log (QML errors on extra's quickshell)"
    local log
    log="$(NO_COLOR=1 qs log -c caelestia 2>/dev/null || qs log -i "$(qs list --all 2>/dev/null | awk '/caelestia/{print $2; exit}')" 2>/dev/null || true)"
    log="$(sed "s/\x1b\[[0-9;]*m//g" <<<"$log")"
    if [[ -z "$log" ]]; then warn "could not read the qs log (qs log -c caelestia)"; return; fi
    local bad
    bad="$(grep -E 'ERROR|TypeError|ReferenceError|is not a type|module ".*" is not installed|Cannot assign|failed to load' <<<"$log" | sort | uniq -c | sort -rn | head -10 || true)"
    # A VM without a GL render node logs a dmabuf error once; that is the VM, not the shell.
    local vmonly
    vmonly="$(grep -c 'Failed to find render device' <<<"$bad" || true)"
    if [[ -n "$bad" && "$vmonly" -gt 0 && "$(systemd-detect-virt 2>/dev/null || true)" != none ]]; then
        warn "VM without a usable GL render node (quickshell dmabuf fallback): use virtio-vga-gl for a GL test"
        bad="$(grep -v 'Failed to find render device' <<<"$bad" || true)"
    fi
    if [[ -z "$bad" ]]; then pass "no QML errors in the shell log"
    else fail "QML errors in the shell log:"; echo "$bad"; fi
}

check_wallpaper_theme() {
    log_section "Wallpaper, scheme, GTK"
    local state="$HOME/.local/state/caelestia/wallpaper/path.txt"
    if [[ -s "$state" ]] && [[ -f "$(cat "$state")" ]]; then pass "wallpaper set: $(cat "$state")"
    else fail "no wallpaper in $state (first-login wallpaper did not run)"; fi
    check "first-login stamp present" test -e "$CFG/.firstrun-wallpaper-done"
    check "scheme generated" test -s "$HOME/.local/state/caelestia/scheme.json"
    local icon
    icon="$(gsettings get org.gnome.desktop.interface icon-theme)"
    if [[ "$icon" == "'Surfn-Kiro'" ]]; then pass "icon theme Surfn-Kiro"; else warn "icon theme $icon (Kiro default Surfn-Kiro)"; fi
    check_warn "color-scheme follows the gtk-4 setting" bash -c '
        want="prefer-dark"
        grep -qs "gtk-application-prefer-dark-theme=false" "$HOME/.config/gtk-4.0/settings.ini" && want="default"
        [[ "$(gsettings get org.gnome.desktop.interface color-scheme)" == "'"'"'$want'"'"'" ]]'
}

check_wallpaper_change() {
    log_section "Active: a wallpaper change keeps the theming"
    local before after cur other
    before="$(for k in gtk-theme icon-theme color-scheme cursor-theme; do gsettings get org.gnome.desktop.interface "$k"; done)"
    cur="$(cat "$HOME/.local/state/caelestia/wallpaper/path.txt" 2>/dev/null || true)"
    other="$(find /usr/share/backgrounds/kiro -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.png' \) ! -path "$cur" | head -1)"
    if [[ -z "$other" ]]; then warn "no second wallpaper in /usr/share/backgrounds/kiro"; return; fi
    caelestia wallpaper -N -f "$other" >/dev/null 2>&1 || { fail "caelestia wallpaper -N -f failed"; return; }
    sleep 4
    after="$(for k in gtk-theme icon-theme color-scheme cursor-theme; do gsettings get org.gnome.desktop.interface "$k"; done)"
    if [[ "$(cat "$HOME/.local/state/caelestia/wallpaper/path.txt")" == "$other" ]]; then pass "wallpaper changed"
    else fail "wallpaper did not change"; fi
    if [[ "$before" == "$after" ]]; then pass "GTK/icon/color-scheme/cursor unchanged after the change"
    else fail "theming changed by the wallpaper change: $(diff <(echo "$before") <(echo "$after") | grep '^[<>]' | tr '\n' ' ')"; fi
    if [[ -n "$cur" ]]; then caelestia wallpaper -N -f "$cur" >/dev/null 2>&1 || true; fi
}

check_variety() {
    log_section "Variety"
    check "variety runs (autostart)" pgrep -u "$(id -u)" -f '/usr/bin/variety'
    # A Variety main window at login was a bug on earlier editions.
    local win
    win="$(hyprctl clients -j 2>/dev/null | python3 -I -c 'import json,sys
print(" ".join(c["title"] for c in json.load(sys.stdin) if "variety" in c["class"].lower()))' || true)"
    if [[ -z "$win" ]]; then pass "no Variety window open"; else fail "Variety window open: $win"; fi
    check_warn "set_wallpaper_kiro knows this session (home)" grep -q "$ED" "$HOME/.config/variety/scripts/set_wallpaper_kiro"
    check_warn "set_wallpaper_kiro knows this session (skel)" grep -q "$ED" /etc/skel/.config/variety/scripts/set_wallpaper_kiro
}

check_shared() {
    log_section "Shared pieces"
    # Without a branch, archlinux-logout falls back to a pkill that matches nothing: logout does nothing.
    check "archlinux-logout knows $ED (else: flow-archlinux-logout)" grep -q "$ED" /usr/share/archlinux-logout/Functions.py
    if [[ -f /usr/lib/calamares/modules/kiro_displaymanager/main.py ]]; then
        check "installer maps $ED-session" grep -q "$ED-session" /usr/lib/calamares/modules/kiro_displaymanager/main.py
    else
        echo "${CYAN}SKIP${RESET} installer check (no kirotux-calamares-config here; ISO only)"
    fi
    if pacman -Q kirotux-hyprland-premium >/dev/null 2>&1; then
        check "premium app knows caelestia (else: flow-kirotux-hyprland-premium)" grep -rq "$ED" /usr/share/kirotux-hyprland-premium/khp_hypr.py
    else
        echo "${CYAN}SKIP${RESET} premium app check (not installed)"
    fi
    check "lock IPC target exists (caelestia shell lock lock)" bash -c 'caelestia shell -s 2>/dev/null | grep -qi lock'
}

main() {
    [[ "${1:-}" == --active ]] && ACTIVE=1
    log_info "$ED live check on $(uname -n), user $(id -un)"
    import_session_env
    check_packages
    check_files
    check_config_contract
    check_caelestia_config
    check_session
    check_notifications
    check_shortcuts
    check_qml_log
    check_wallpaper_theme
    [[ "$ACTIVE" == 1 ]] && check_wallpaper_change
    check_variety
    check_shared
    log_section "Result: $NPASS PASS, $NWARN WARN, $NFAIL FAIL"
    echo "Still to test by hand: keys by real key press, logout from Super+X, lock + unlock, suspend/resume,"
    echo "the installer in the launcher (live ISO), and a reboot (second login: no first-login wallpaper again)."
    if [[ "$NFAIL" -gt 0 ]]; then log_error "$NFAIL check(s) failed"; trap - ERR; exit 1; fi
    log_success "$(basename "$0") done"
}

main "$@"
