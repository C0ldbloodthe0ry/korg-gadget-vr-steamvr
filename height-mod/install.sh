#!/usr/bin/env bash
# Install the height fix for KORG Gadget VR: UE4SS (the open-source Unreal mod
# loader) plus the KorgGadgetHeightFix Lua mod. Linux / SteamOS.
#
#   height-mod/install.sh                     find the game in your Steam libraries
#   height-mod/install.sh /path/to/GadgetVRGame
#   height-mod/install.sh --uninstall [folder]
#
# Then set the game's Steam launch options to:
#   WINEDLLOVERRIDES="dwmapi=n,b" %command%
#
# If UE4SS is already installed for other mods, only this mod is added or removed.
set -euo pipefail

UE4SS_VERSION="v4.0.0"
UE4SS_URL="https://github.com/UE4SS-RE/RE-UE4SS/releases/download/$UE4SS_VERSION/UE4SS_$UE4SS_VERSION.zip"
UE4SS_SHA256="251ad0d1381a241750e036f5918cbf2b5d7ec58ebc608cb2dd09d459d0c81e45"
MOD="KorgGadgetHeightFix"
MARKER=".installed-by-korg-gadget-vr-steamvr"

here="$(cd "$(dirname "$0")" && pwd)"
rel="GadgetVRGame/Binaries/Win64"
exe="GadgetGame-Win64-Shipping.exe"
mode=install
if [[ "${1:-}" == "--uninstall" ]]; then mode=uninstall; shift; fi

find_game() {
    local root lib
    for root in "$HOME/.local/share/Steam" "$HOME/.steam/steam" "$HOME/.steam/debian-installation" \
                "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; do
        [[ -f "$root/steamapps/libraryfolders.vdf" ]] || continue
        while IFS= read -r lib; do
            if [[ -f "$lib/steamapps/common/GadgetVRGame/$rel/$exe" ]]; then
                printf '%s\n' "$lib/steamapps/common/GadgetVRGame"
                return 0
            fi
        done < <(printf '%s\n' "$root"
                 sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' \
                     "$root/steamapps/libraryfolders.vdf")
    done
    return 1
}

game="${1:-}"
if [[ -z "$game" ]] && ! game="$(find_game)"; then
    echo "KORG Gadget VR not found. Pass its folder, e.g.:" >&2
    echo "  $0 ~/.local/share/Steam/steamapps/common/GadgetVRGame" >&2
    exit 1
fi
win64="$game/$rel"
[[ -f "$win64/$exe" ]] || { echo "No $exe in $win64" >&2; exit 1; }
ue4ss="$win64/ue4ss"
mods_txt="$ue4ss/Mods/mods.txt"

if [[ "$mode" == uninstall ]]; then
    if [[ -f "$ue4ss/$MARKER" ]]; then
        rm -f -- "$win64/dwmapi.dll"
        rm -rf -- "$ue4ss"
        echo "Removed UE4SS and the height fix from $win64"
    elif [[ -d "$ue4ss/Mods/$MOD" ]]; then
        rm -rf -- "$ue4ss/Mods/$MOD"
        [[ -f "$mods_txt" ]] && sed -i "/^$MOD[[:space:]]*:/d" "$mods_txt"
        echo "Removed the height fix. Your own UE4SS install was left in place."
    else
        echo "The height fix was not installed."
    fi
    echo 'Also remove WINEDLLOVERRIDES="dwmapi=n,b" from the launch options if nothing else needs it.'
    exit 0
fi

if [[ -d "$ue4ss" && ! -f "$ue4ss/$MARKER" ]]; then
    echo "UE4SS is already installed (not by this repo). Adding only the mod."
elif [[ -e "$win64/dwmapi.dll" && ! -d "$ue4ss" ]]; then
    echo "There is a dwmapi.dll in $win64 that this script didn't put there." >&2
    echo "Remove it or install UE4SS yourself, then run this again." >&2
    exit 1
else
    command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
    command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }
    tmp="$(mktemp -d)"
    trap 'rm -rf -- "$tmp"' EXIT
    echo "Downloading UE4SS $UE4SS_VERSION..."
    curl -fsSL --proto '=https' -o "$tmp/ue4ss.zip" "$UE4SS_URL"
    echo "$UE4SS_SHA256  $tmp/ue4ss.zip" | sha256sum -c --quiet - \
        || { echo "Checksum mismatch: not installing." >&2; exit 1; }
    python3 -I -m zipfile -e "$tmp/ue4ss.zip" "$tmp/x"
    [[ -f "$tmp/x/dwmapi.dll" && -f "$tmp/x/ue4ss/UE4SS.dll" ]] \
        || { echo "Unexpected UE4SS archive layout: not installing." >&2; exit 1; }
    cp -f -- "$tmp/x/dwmapi.dll" "$win64/"
    mkdir -p -- "$ue4ss"
    cp -rf -- "$tmp/x/ue4ss/." "$ue4ss/"
    cp -f -- "$here/mods.txt" "$mods_txt"   # only this mod enabled
    echo "$UE4SS_VERSION" > "$ue4ss/$MARKER"
fi

rm -rf -- "$ue4ss/Mods/$MOD"
cp -r -- "$here/$MOD" "$ue4ss/Mods/$MOD"
if ! grep -q "^$MOD[[:space:]]*:" "$mods_txt" 2>/dev/null; then
    # UE4SS wants the Keybinds line last, so put this mod first.
    { echo "$MOD : 1"; cat "$mods_txt" 2>/dev/null || true; } > "$mods_txt.tmp"
    mv -f -- "$mods_txt.tmp" "$mods_txt"
fi

echo "Installed into $win64"
echo
echo "Now set the game's launch options in Steam (Properties > General):"
echo '  WINEDLLOVERRIDES="dwmapi=n,b" %command%'
echo "Start the game, sit how you'll play, and wait 5 seconds. F8 recenters."
