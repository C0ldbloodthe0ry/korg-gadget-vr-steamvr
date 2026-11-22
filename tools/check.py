#!/usr/bin/env python3
"""Check every bindings/*.json against SteamVR's input profile for its controller
and against the game's action manifest. Read-only. Needs SteamVR and the game
installed; finds both through Steam's library list, or pass paths:

    tools/check.py [--steamvr DIR] [--manifest FILE]
"""
import argparse
import glob
import json
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir))
MANIFEST_REL = os.path.join("GadgetVRGame", "GadgetVRGame", "Config", "SteamVRBindings", "steamvr_manifest.json")

SLOT_TYPE = {"click": "boolean", "touch": "boolean", "north": "boolean", "south": "boolean",
             "east": "boolean", "west": "boolean", "center": "boolean",
             "pull": "vector1", "position": "vector2"}
MODES = {"button": {"button"}, "trigger": {"button", "trigger"},
         "joystick": {"joystick", "dpad"}, "trackpad": {"trackpad", "dpad", "button"}}


def steam_libraries():
    roots = [os.path.expanduser(p) for p in (
        "~/.local/share/Steam", "~/.steam/steam", "~/.steam/debian-installation",
        "~/.var/app/com.valvesoftware.Steam/.local/share/Steam")]
    roots += [r"C:\Program Files (x86)\Steam", r"C:\Program Files\Steam"]
    libs = []
    for root in roots:
        vdf = os.path.join(root, "steamapps", "libraryfolders.vdf")
        if os.path.isfile(vdf):
            libs.append(root)
            text = open(vdf, encoding="utf-8", errors="replace").read()
            libs += [p.replace("\\\\", "\\") for p in re.findall(r'"path"\s+"([^"]+)"', text)]
    seen, out = set(), []
    for lib in libs:
        real = os.path.realpath(lib)
        if real not in seen:
            seen.add(real)
            out.append(lib)
    return out


def find(rel):
    for lib in steam_libraries():
        p = os.path.join(lib, "steamapps", "common", rel)
        if os.path.exists(p):
            return p
    return None


def profiles(steamvr):
    found = {}
    for p in glob.glob(os.path.join(steamvr, "**", "*profile*.json"), recursive=True):
        try:
            ct = json.load(open(p, encoding="utf-8")).get("controller_type")
        except (ValueError, OSError):
            continue
        if ct and (ct not in found or "drivers" in p):  # prefer the driver's own copy
            found[ct] = p
    return found


def check_binding(path, actions, profile_path):
    errors, used = [], set()
    b = json.load(open(path, encoding="utf-8"))
    inputs = json.load(open(profile_path, encoding="utf-8"))["input_source"]

    def use(name, want, where):
        t = actions.get(name.lower())
        if t is None:
            errors.append(f"{where}: action not in game manifest: {name}")
        elif t != want:
            errors.append(f"{where}: {name} is {t}, this slot needs {want}")
        used.add(name.lower())

    def split(p):
        parts = p.split("/")
        return parts[3], "/" + "/".join(parts[4:])

    for s in b["bindings"].values():
        for i, src in enumerate(s.get("sources", [])):
            hand, inp = split(src["path"])
            where = f"sources[{i}] {src['path']} ({src['mode']})"
            spec = inputs.get(inp)
            if spec is None:
                errors.append(f"{where}: {b['controller_type']} has no {inp}")
                continue
            if spec.get("side") and spec["side"] != hand:
                errors.append(f"{where}: {inp} is only on the {spec['side']} controller")
            if src["mode"] not in MODES.get(spec["type"], set()):
                errors.append(f"{where}: mode not allowed on a {spec['type']} input")
            if src["mode"] == "button" and spec["type"] == "button" and not spec.get("click"):
                errors.append(f"{where}: {inp} has no click")
            for slot, out in src["inputs"].items():
                if slot not in SLOT_TYPE:
                    errors.append(f"{where}: unknown slot {slot}")
                else:
                    use(out["output"], SLOT_TYPE[slot], where)
        for key, want in (("poses", "pose"), ("haptics", "vibration"), ("skeleton", "skeleton")):
            for e in s.get(key, []):
                if split(e["path"])[1] not in inputs:
                    errors.append(f"{key}: {e['path']} not on {b['controller_type']}")
                use(e["output"], want, key)
    return b["controller_type"], errors, used


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--steamvr", help="SteamVR install folder")
    ap.add_argument("--manifest", help="the game's steamvr_manifest.json")
    args = ap.parse_args()
    steamvr = args.steamvr or find("SteamVR")
    manifest = args.manifest or find(MANIFEST_REL)
    if not steamvr or not manifest:
        sys.exit("SteamVR or KORG Gadget VR not found; pass --steamvr and --manifest")

    # A patched manifest is fine: only "actions" is read.
    actions = {a["name"].lower(): a["type"] for a in json.load(open(manifest, encoding="utf-8"))["actions"]}
    known = profiles(steamvr)
    failed = False
    for path in sorted(glob.glob(os.path.join(ROOT, "bindings", "*.json"))):
        ct = json.load(open(path, encoding="utf-8"))["controller_type"]
        if ct not in known:
            print(f"{os.path.basename(path)}: no SteamVR profile for {ct}")
            failed = True
            continue
        ct, errors, used = check_binding(path, actions, known[ct])
        print(f"{os.path.basename(path)}: {len(errors)} errors, {len(used)} of {len(actions)} actions bound")
        for e in errors:
            print("   ", e)
        failed |= bool(errors)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
