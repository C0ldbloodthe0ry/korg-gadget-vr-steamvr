#!/usr/bin/env bash
# Install the SteamVR controller bindings for KORG Gadget VR (Linux / SteamOS).
#
#   ./install.sh                      find the game in your Steam libraries
#   ./install.sh /path/to/GadgetVRGame   or point at the game folder yourself
#   ./install.sh --uninstall [folder]    put everything back
#
# Copies bindings/*.json into the game's Config/SteamVRBindings folder and lists
# them as default bindings in steamvr_manifest.json. The unpatched manifest is
# kept as steamvr_manifest.json.orig. Steam's "Verify integrity" also undoes it.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
rel="GadgetVRGame/Config/SteamVRBindings"
mode=install
if [[ "${1:-}" == "--uninstall" ]]; then mode=uninstall; shift; fi

find_game() {
    local root lib
    for root in "$HOME/.local/share/Steam" "$HOME/.steam/steam" "$HOME/.steam/debian-installation" \
                "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; do
        [[ -f "$root/steamapps/libraryfolders.vdf" ]] || continue
        while IFS= read -r lib; do
            if [[ -f "$lib/steamapps/common/GadgetVRGame/$rel/steamvr_manifest.json" ]]; then
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
    echo "  ./install.sh ~/.local/share/Steam/steamapps/common/GadgetVRGame" >&2
    exit 1
fi
manifest="$game/$rel/steamvr_manifest.json"
[[ -f "$manifest" ]] || { echo "No steamvr_manifest.json in $game/$rel" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

python3 -I - "$mode" "$manifest" "$here/bindings" <<'EOF'
import glob, json, os, shutil, sys

mode, manifest, src = sys.argv[1:4]
dest, backup = os.path.dirname(manifest), manifest + ".orig"
files = sorted(glob.glob(os.path.join(src, "*.json")))
ours = [{"controller_type": json.load(open(p, encoding="utf-8"))["controller_type"],
         "binding_url": os.path.basename(p)} for p in files]
names = {o["binding_url"] for o in ours}
types = {o["controller_type"] for o in ours}

m = json.load(open(manifest, encoding="utf-8"))
current = m.get("default_bindings", [])
patched = any(d.get("binding_url") in names for d in current)

def write(obj):
    tmp = manifest + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        json.dump(obj, f, indent="\t")
        f.write("\n")
    os.replace(tmp, manifest)

if mode == "uninstall":
    if patched and os.path.exists(backup):
        os.replace(backup, manifest)
        print("Restored the original steamvr_manifest.json")
    elif patched:
        keep = [d for d in current if d.get("binding_url") not in names]
        if keep:
            m["default_bindings"] = keep
        else:
            m.pop("default_bindings", None)
        write(m)
        print("Removed this fix's entries from steamvr_manifest.json")
    else:
        if os.path.exists(backup):
            os.remove(backup)  # stale: Steam already restored or updated the manifest
        print("steamvr_manifest.json was not patched")
    for n in names:
        p = os.path.join(dest, n)
        if os.path.exists(p):
            os.remove(p)
    print("Removed the binding files. Restart SteamVR.")
    sys.exit(0)

if not patched:
    shutil.copy2(manifest, backup)  # always back up the current unpatched manifest
for p in files:
    shutil.copy2(p, os.path.join(dest, os.path.basename(p)))
m["default_bindings"] = [d for d in current if d.get("controller_type") not in types] + ours
write(m)
for o in ours:
    print(f"  {o['controller_type']:<18} {o['binding_url']}")
print(f"Installed into {dest}")
print("Restart SteamVR, then start the game.")
EOF
