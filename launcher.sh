#!/bin/bash

set -u

C_RESET="\033[0m"
C_DIM="\033[2m"
C_BOLD="\033[1m"
C_GREEN="\033[32m"
C_RED="\033[31m"
C_YELLOW="\033[33m"
C_CYAN="\033[36m"
C_GRAY="\033[90m"
C_PURPLE="\033[38;2;105;52;175m"

get_time() {
    local s=""
    local mot="RoninMac"
    local couleurs=("180;120;255" "160;100;245" "140;85;230" "120;70;210" "105;52;175" "95;45;160" "85;40;145" "75;35;130")
    for ((i=0; i<${#mot}; i++)); do
        s+="\033[38;2;${couleurs[$i]}m${mot:$i:1}"
    done
    s+="${C_RESET}"
    printf "%b" "${s}${C_GRAY}::${C_RESET}${C_GREEN}[$(date +%H:%M:%S)]${C_RESET}"
}

die() {
    spinner_stop "fail" "$1"
    exit 1
}

SPIN_FRAMES=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")
SPINNER_PID=""
SPINNER_MSG=""

spinner_start() {
    SPINNER_MSG="$1"
    printf "\033[?25l\033[?7l"
    (
        local i=0
        while true; do
            local frame="${SPIN_FRAMES[$((i % ${#SPIN_FRAMES[@]}))]}"
            printf "\r\033[2K%b ${C_CYAN}%s${C_RESET}  %s" "$(get_time)" "$frame" "$SPINNER_MSG"
            i=$((i+1))
            sleep 0.08
        done
    ) &
    SPINNER_PID=$!
    disown "$SPINNER_PID" 2>/dev/null || true
}

spinner_stop() {
    local status="${1:-ok}"
    local msg="${2:-$SPINNER_MSG}"
    if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null || true
    fi
    SPINNER_PID=""
    printf "\r\033[2K"
    case "$status" in
        ok)   printf "%b ${C_GREEN}✔${C_RESET}  %b\n" "$(get_time)" "$msg" ;;
        fail) printf "%b ${C_RED}✖${C_RESET}  %b\n"   "$(get_time)" "$msg" ;;
        warn) printf "%b ${C_YELLOW}!${C_RESET}  %b\n" "$(get_time)" "$msg" ;;
        *)    printf "%b    %b\n" "$(get_time)" "$msg" ;;
    esac
    printf "\033[?7h\033[?25h"
}

download_with_progress() {
    local url="$1"
    local out="$2"
    local label="$3"
    local bar_width=20

    local total
    total=$(curl -sIL -m 10 "$url" \
        | awk 'BEGIN{IGNORECASE=1} /^content-length:/ {gsub(/\r/,""); v=$2} END{print v+0}')
    [[ -z "$total" || "$total" == "0" ]] && total=0

    curl -fL -s "$url" -o "$out" &
    local pid=$!

    printf "\033[?25l\033[?7l"

    local i=0
    local min_loops=5
    while kill -0 "$pid" 2>/dev/null || (( i < min_loops )); do
        local cur=0
        [[ -f "$out" ]] && cur=$(stat -f%z "$out" 2>/dev/null || echo 0)

        local pct="0.0" filled=0
        if [[ "$total" -gt 0 ]]; then
            pct=$(awk -v c="$cur" -v t="$total" 'BEGIN{p=(c/t)*100; if(p>100)p=100; printf "%.1f", p}')
            filled=$(awk -v c="$cur" -v t="$total" -v w="$bar_width" 'BEGIN{f=int((c/t)*w); if(f>w)f=w; print f}')
        fi

        local bar=""
        for ((j=0; j<filled; j++));        do bar+="━"; done
        for ((j=filled; j<bar_width; j++)); do bar+="─"; done

        local frame="${SPIN_FRAMES[$((i % ${#SPIN_FRAMES[@]}))]}"
        printf "\r\033[2K%b ${C_CYAN}%s${C_RESET} %s ${C_GREEN}%s${C_RESET} ${C_BOLD}%5s%%${C_RESET}" \
            "$(get_time)" "$frame" "$label" "$bar" "$pct"
        i=$((i+1))
        sleep 0.1

        if ! kill -0 "$pid" 2>/dev/null && (( i >= min_loops )); then
            break
        fi
    done
    wait "$pid" 2>/dev/null; local rc=$?

    printf "\r\033[2K"
    if [[ $rc -eq 0 ]]; then
        local bar=""
        for ((j=0; j<bar_width; j++)); do bar+="━"; done
        printf "%b ${C_GREEN}✔${C_RESET} %s ${C_GREEN}%s${C_RESET} ${C_BOLD}100.0%%${C_RESET}\n" \
            "$(get_time)" "$label" "$bar"
    else
        printf "%b ${C_RED}✖${C_RESET} %s failed\n" "$(get_time)" "$label"
    fi

    printf "\033[?7h\033[?25h"
    return $rc
}

log() { printf "%b %b\n" "$(get_time)" "$1"; }

banner() {
    echo ""
    printf "${C_PURPLE}      ██████╗   ██████╗ ███╗   ██╗██╗███╗   ██╗${C_RESET}\n"
    printf "${C_PURPLE}      ██╔══██╗ ██╔═══██╗████╗  ██║██║████╗  ██║${C_RESET}\n"
    printf "${C_PURPLE}      ██████╔╝ ██║   ██║██╔██╗ ██║██║██╔██╗ ██║${C_RESET}\n"
    printf "${C_PURPLE}      ██╔══██╗ ██║   ██║██║╚██╗██║██║██║╚██╗██║${C_RESET}\n"
    printf "${C_PURPLE}      ██║  ██║ ╚██████╔╝██║ ╚████║██║██║ ╚████║${C_RESET}\n"
    printf "${C_PURPLE}      ╚═╝  ╚═╝  ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝${C_RESET}\n"
    printf "  %b  ${C_BOLD}Installer${C_RESET}\n" "$(printf "\033[38;2;105;52;175m%s\033[0m" "Ronin")"
    echo ""
}

detect_arch() {
    local os arch
    os=$(uname -s); arch=$(uname -m)
    if [[ "$os" == "Darwin" ]]; then
        if [[ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" == "1" ]]; then
            arch="arm64"
        fi
    fi
    case "$arch" in
        arm64|aarch64) echo "arm" ;;
        x86_64|amd64)  echo "intel" ;;
        *)             echo "unknown" ;;
    esac
}

RAW_BASE="https://getronin.xyz/mac-installer.sh"

killall -9 Roblox       2>/dev/null
killall -9 RobloxPlayer 2>/dev/null
killall -9 RoninMac     2>/dev/null
killall -9 Ronin        2>/dev/null

banner

echo ""
log "Choose your installation:"
echo ""
echo "   1) ARM (Apple Silicon)"
echo "   2) Intel"
echo "   3) Auto-Detect"
echo ""

archi=""
while [[ -z "$archi" ]]; do
    printf "%b " "$(get_time)"
    read -r -p "Select an option: [1/2/3]: " choice </dev/tty
    case "$choice" in
        1) archi="arm";   log "Architecture Selected: ARM" ;;
        2) archi="intel"; log "Architecture Selected: Intel" ;;
        3)
            spinner_start "Scanning Architecture.."
            sleep 0.4
            archi=$(detect_arch)
            if [[ "$archi" == "arm" ]]; then
                spinner_stop ok "ARM Detected! (Apple Silicon)"
            elif [[ "$archi" == "intel" ]]; then
                spinner_stop ok "Intel Detected!"
            else
                spinner_stop fail "Unsupported Architecture!"
                exit 1
            fi
            ;;
        *) log "${C_RED}invalid choice${C_RESET}, please type 1, 2 or 3" ;;
    esac
done

if [[ "$archi" == "arm" ]]; then
    DMG_URL="${RAW_BASE}/ronin-arm.dmg"
    ROBLOX_ZIP_URL_BASE="https://setup.rbxcdn.com/mac/arm64"
else
    DMG_URL="${RAW_BASE}/ronin-intel.dmg"
    ROBLOX_ZIP_URL_BASE="https://setup.rbxcdn.com/mac"
fi

ROBLOX_API="https://clientsettings.roblox.com/v2/client-version/MacPlayer"
ROBLOX_API_FALLBACK="https://clientsettingscdn.roblox.com/v2/client-version/MacPlayer"
INSTALL_DIR="/Applications"
ROBLOX_APP="${INSTALL_DIR}/Roblox.app"

WORKDIR="$(mktemp -d -t roninmac)"
DMG_PATH="${WORKDIR}/RoninMac.dmg"
PLIST_PATH="${WORKDIR}/entitlement.plist"

cat > "${PLIST_PATH}" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.get-task-allow</key>
    <true/>
    <key>com.apple.security.cs.debugger</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.disable-executable-page-protection</key>
    <true/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.cs.allow-executive-stack</key>
    <true/>
    <key>com.apple.security.cs.disable-restrictions</key>
    <true/>
</dict>
</plist>
PLIST

MOUNT_PATH=""
SUDO_KEEPALIVE_PID=""

cleanup() {
    [[ -n "$SPINNER_PID" ]] && kill "$SPINNER_PID" 2>/dev/null
    printf "\033[?7h\033[?25h"
    [ -n "${MOUNT_PATH}" ] && [ -d "${MOUNT_PATH}" ] && hdiutil detach "${MOUNT_PATH}" -quiet 2>/dev/null
    [ -n "${SUDO_KEEPALIVE_PID}" ] && kill "${SUDO_KEEPALIVE_PID}" 2>/dev/null
    rm -rf "${WORKDIR}"
}
trap cleanup EXIT INT TERM

echo ""
log "${C_CYAN}admin access required${C_RESET} — Enter Your Mac Password."
sudo -v || die "Administrator Permissions Denied!"
(
    while true; do
        sudo -n true
        sleep 30
        kill -0 "$$" 2>/dev/null || exit
    done
) &
SUDO_KEEPALIVE_PID=$!
disown "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
log "${C_GREEN}admin granted${C_RESET}"

spinner_start "Removing Outdated Roblox Version.."
sudo -n killall -9 Roblox 2>/dev/null
sudo -n rm -rf "/Applications/Roblox.app"
sudo -n rm -rf "/Applications/RobloxPlayer.app"
spinner_stop ok "Removed Outdated Roblox Version!"

spinner_start "fetching roblox build info..."
RO_VERSION=$(curl -fsS -m 10 "${ROBLOX_API}" | grep -oE '"clientVersionUpload":"[^"]*"' | cut -d'"' -f4)
[[ -z "$RO_VERSION" ]] && RO_VERSION=$(curl -fsS -m 10 "${ROBLOX_API_FALLBACK}" | grep -oE '"clientVersionUpload":"[^"]*"' | cut -d'"' -f4)
[[ -z "$RO_VERSION" ]] && { spinner_stop fail "Could Not Fetch Roblox Version"; exit 1; }
spinner_stop ok "Roblox Build : ${RO_VERSION}"

URL="${ROBLOX_ZIP_URL_BASE}/${RO_VERSION}-RobloxPlayer.zip"
OUT="/tmp/RobloxPlayer.zip"
download_with_progress "$URL" "$OUT" "downloading roblox " || die "Roblox Downloading Failed!"

spinner_start "Unpacking Roblox.."
cd /tmp || die "cannot cd /tmp"
unzip -o -q "$OUT" || { spinner_stop fail "Unzipping Failed!"; exit 1; }
mv "/tmp/RobloxPlayer.app" "/Applications/Roblox.app"
rm -f "$OUT"
[ -d "${ROBLOX_APP}" ] || { spinner_stop fail "Roblox Installation Failed!"; exit 1; }
spinner_stop ok "Roblox Installed!"

spinner_start "Preparing Roblox.."
sudo -n xattr -cr "${ROBLOX_APP}" || true
sudo -n codesign --force --sign - "${ROBLOX_APP}/Contents/MacOS/RobloxPlayer" 2>/dev/null || true
spinner_stop ok "Roblox Prepared!"

download_with_progress "${DMG_URL}" "${DMG_PATH}" "Downloading Ronin.." || die "Dmg Download Failed!"
[ -f "${DMG_PATH}" ] || die "Missing Dmg"

spinner_start "Mounting dmg.."
MOUNT_PATH="$(hdiutil attach "${DMG_PATH}" -nobrowse -noautoopen 2>/dev/null | awk -F'\t' '/\/Volumes\// {print $NF; exit}')"
[ -n "${MOUNT_PATH}" ] || { spinner_stop fail "Mount Failed"; exit 1; }
spinner_stop ok "Dmg mounted"

APP_NAME="$(ls "${MOUNT_PATH}" | grep '\.app$' | head -n 1)"
[ -n "${APP_NAME}" ] || die "No application found in dmg"

TARGET_PATH="${INSTALL_DIR}/${APP_NAME}"

spinner_start "!nstalling ${APP_NAME}.."
sudo -n rm -rf "${TARGET_PATH}"
sudo -n cp -R "${MOUNT_PATH}/${APP_NAME}" "${INSTALL_DIR}/" || { spinner_stop fail "Install Failed!"; exit 1; }
hdiutil detach "${MOUNT_PATH}" -quiet
MOUNT_PATH=""
spinner_stop ok "${APP_NAME} installed!"

spinner_start "Removing Quarantine..."
sudo -n xattr -rd com.apple.quarantine "${TARGET_PATH}" 2>/dev/null || true
sudo -n xattr -cr "${TARGET_PATH}"
spinner_stop ok "Quarantine Removed"

spinner_start "Signing Application.."
sudo -n codesign --force --deep --sign - --entitlements "${PLIST_PATH}" "${TARGET_PATH}" >/dev/null 2>&1 \
    || { spinner_stop fail "Codesign Failed!"; exit 1; }
spinner_stop ok "Application Signed!"

spinner_start "Verifying Signature.."
sudo -n codesign --verify --deep "${TARGET_PATH}" 2>/dev/null
spinner_stop ok "Signature Verified!"

spinner_start "Launching Roblox.."
open "/Applications/Roblox.app"
sleep 5
spinner_stop ok "Roblox Launched!"

spinner_start "Launching Ronin.."
sleep 1
open "${TARGET_PATH}"
spinner_stop ok "Ronin Launched!"

echo ""
printf "  ${C_GREEN}✔  All done — enjoy RoninMac ${C_RESET}\n"
echo ""
