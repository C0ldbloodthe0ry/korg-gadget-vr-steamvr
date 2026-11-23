# KORG Gadget VR: SteamVR controller and height fix (unofficial)

On Steam, KORG Gadget VR only officially supports a Quest connected through
Oculus Link. On any other SteamVR setup (Steam Frame, Index, Vive, Pico, a Quest
over Steam Link, ALVR or Virtual Desktop) the controllers are not tracked, the
buttons do nothing, and you start far above the desk. This repo adds the missing
SteamVR controller bindings, so the game gets the same buttons a Quest on Oculus
Link gets. It also has an optional mod that puts the view back at the desk.

## A note to KORG

> Hopefully people won't need this for long. Korg, LOVE your devices and software
> but please take anything that is available to build on here and fix the app.
> Don't give up on it please as I was excited since it was teased and was
> heartbroken to never see it fixed. I bought it the day it launched. Good luck!
>
> — C0ldbloodthe0ry

Everything here is free to use under MIT-0, with no credit, attribution or
acknowledgement needed. Take whatever helps and ship it as your own.

## What it fixes, and what it doesn't

| Problem | Status |
|---|---|
| Controllers not tracked / buttons do nothing under SteamVR | **Fixed by this repo** |
| You spawn a meter or more above the desk | **Fixed by the optional [height mod](#spawning-too-high-the-height-mod)** |
| Doesn't start properly under Virtual Desktop (acknowledged by KORG) | Not addressed |
| No sound (one report on Index) | Unknown |

## Tested on

| Setup | Result |
|---|---|
| Steam Frame, Linux (CachyOS, Proton), SteamVR 2.19.4 | Controllers work. Height fixed by the height mod |
| Quest over SteamVR (Steam Link, ALVR, Virtual Desktop in SteamVR mode) | Untested, please report |
| Index, Vive wands, Pico, WMR / HP Reverb, PSVR2, Focus 3, Cosmos | Untested, please report |

Game build 15331537, the latest version (August 2024).

## Install

You don't need to back anything up first. The installer keeps the original file
as `steamvr_manifest.json.orig`, and Steam's **Verify integrity of game files**
also puts everything back.

**Windows:** download this repo (Code → Download ZIP), extract it, and double-click
`install.bat`. If the game is on a drive Steam doesn't report, run
`install.ps1 -GameDir "D:\SteamLibrary\steamapps\common\GadgetVRGame"`.
The Windows scripts haven't been run on Windows yet. Reports are very welcome.

**Linux / SteamOS:**

```sh
git clone https://github.com/C0ldbloodthe0ry/korg-gadget-vr-steamvr
cd korg-gadget-vr-steamvr
./install.sh            # or: ./install.sh /path/to/steamapps/common/GadgetVRGame
```

The game runs under Proton. With no Oculus runtime there, it picks its SteamVR
backend by itself, which is the one these bindings are for.

**By hand (any OS):** copy `bindings/*.json` into
`steamapps/common/GadgetVRGame/GadgetVRGame/Config/SteamVRBindings/`, then open
`steamvr_manifest.json` in that folder. Put a comma after the last `]` and add
this before the final `}`:

```json
"default_bindings": [
  { "controller_type": "oculus_touch", "binding_url": "oculus_touch.json" },
  { "controller_type": "frame_controller", "binding_url": "frame_controller.json" }
]
```

Then **restart SteamVR** and start the game.

**Uninstall:** `uninstall.bat` / `./uninstall.sh`, or Verify integrity in Steam.
A game update or a Verify also removes the fix, so just run the installer again.

## Controls

The layout is the game's own Quest layout, read from its input configuration, so
every button does what it does on a Quest. One press can feed two or three game
actions, exactly as on a Quest.

| Quest (Touch) | Steam Frame | Game actions |
|---|---|---|
| Right trigger | Right trigger or right bumper | `VR_R_Trigger`, `InterructionEnter` (select / confirm) |
| Left trigger | Left trigger or left bumper | `VR_L_Trigger`, `PadLeftTrigger` |
| A | a | `VR_R_A_Button`, `PadButtonEnter` |
| B | b, x or y | `VR_R_B_Button`, `PadButtonBack`, `PadButtonRight` |
| X | Left d-pad down | `VR_L_X_Button`, `PadButtonLeft`, `PlayButton` |
| Y | Left d-pad up, left or right | `VR_L_Y_Button`, `PadButtonMenu` (menu) |
| Grips (press / squeeze) | Grips | `VR_*_Grip`, `Pad*Shoulder`, `PadShiftButton` / `LGrip`, `RGrip` |
| Left stick (move / click / push) | Left stick | `UIPadStickLeft`, `LeftStickPress`, `PadDigital*` |
| Right stick | Right stick | `UIPadStickRight` |

On the Frame, the buttons go where SteamVR's own Touch-to-Frame remap puts them.
The other controllers in the table above get no file of their own. SteamVR adapts
the Touch binding to them automatically. To change anything, open SteamVR
Settings → Controllers → Manage Controller Bindings → KORG Gadget VR.

## Spawning too high: the height mod

Under SteamVR the game adds your real head height on top of its own camera
height, so you float above the desk. KORG has acknowledged "issues with
viewpoint". `height-mod/` is a small Lua mod for
[UE4SS](https://github.com/UE4SS-RE/RE-UE4SS), the open-source Unreal mod loader.
Once the headset is tracking, it switches the game to an eye-level origin and
recenters, which is how the game behaves on a Quest. Press **F8** on the keyboard
to recenter at any time.

UE4SS is not included in this repo. The Linux installer downloads the official
v4.0.0 release and checks its SHA-256 before installing.

**Linux / SteamOS:**

```sh
./height-mod/install.sh            # or: ./height-mod/install.sh /path/to/GadgetVRGame
```

Then set the game's launch options in Steam (Properties → General):

```
WINEDLLOVERRIDES="dwmapi=n,b" %command%
```

Start the game, sit or stand the way you'll play, and wait about 5 seconds.
To undo, run `./height-mod/install.sh --uninstall` and clear the launch option.
Steam's Verify integrity does not remove the mod. If you already use UE4SS for
other mods, the installer only adds this one.

**Windows (by hand, untested):**

1. Download `UE4SS_v4.0.0.zip` from the
   [UE4SS releases](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v4.0.0).
2. Extract it into `GadgetVRGame\Binaries\Win64`, next to `GadgetGame-Win64-Shipping.exe`.
3. Copy `height-mod\KorgGadgetHeightFix` into `Win64\ue4ss\Mods\`.
4. Add `KorgGadgetHeightFix : 1` as the first line of `Win64\ue4ss\Mods\mods.txt`.

Windows needs no launch option.

**Without a mod:** OVR Advanced Settings (free on Steam) can lower your view with
its playspace offset instead.

## For KORG / DETUNE developers

Measured on build 15331537. Nothing here needs the source code, and you're free
to use any of it without credit.

1. **The cause of the dead controllers:** `Config/SteamVRBindings/steamvr_manifest.json`
   ships with no `default_bindings`, and no binding files ship next to it.
   SteamVR therefore binds nothing for any controller. Shipping binding files
   (like the ones in `bindings/`) and listing them in `default_bindings` fixes
   input on every SteamVR headset. SteamVR adapts a Touch binding to most other
   controllers by itself.
2. **The Index and Vive mappings already in `DefaultInput.ini` leave out two actions.**
   `ValveIndex_*`, `Vive_*` and `MixedReality_*` keys are mapped, but none of them
   reaches `PadButtonEnter` or `PadButtonMenu`. Only `OculusTouch_Right_A_Click`
   and `OculusTouch_Left_Y_Click` reach those two. So even with generated bindings,
   the Y-button menu has no Index or Vive equivalent.
3. **Runtime choice:** `[HMDPluginPriority]` is OculusHMD 40 > SteamVR 30 >
   OpenXRHMD 20, and the OpenXR plugin is already enabled. UE 4.27's OpenXR path
   with the existing key mappings would cover every OpenXR headset through
   interaction profiles.
4. **The floating viewpoint.** No Blueprint in the pak calls `SetTrackingOrigin`.
   The name appears only in the engine's redirect list, and the startup map only
   calls `GetHMDDeviceName` and `IsHeadMountedDisplayEnabled`. So the game runs
   with each runtime's default origin, which under SteamVR is the floor. The view
   ends up about one head-height too high, which fits a scene laid out for an
   eye-level origin. `vr.TrackingOrigin` is a console command, not a variable, so
   `Engine.ini` can't set it. **Confirmed fix:** calling `SetTrackingOrigin(Eye Level)`
   once at startup puts the view back at the desk. On a Steam Frame the head then
   measured within a few cm of the game's camera height. In the game that is one
   Blueprint node. Here the UE4SS mod in `height-mod/` does it from outside.

## Contributing

Modifications are more than welcome.

- **Tried it?** Open an issue with your headset, controllers, OS, how you connect
  (Link, Steam Link, Virtual Desktop, ALVR, native), and what works and what doesn't.
- **Better layout or a new controller:** edit `tools/build_bindings.py`.
  `LAYOUT` says which game actions each Quest button fires. `CONTROLLERS` says
  where those buttons sit on each controller. Then run:

  ```sh
  python3 tools/build_bindings.py   # writes bindings/*.json
  python3 tools/check.py            # checks them against SteamVR and the game (both must be installed)
  ```

  Open a pull request and say what you tested on.
- **Height mod:** the settings are at the top of
  `height-mod/KorgGadgetHeightFix/Scripts/main.lua`. A Windows installer for it
  would be welcome.
- Please don't commit files from the game itself.

## Disclaimer

Unofficial. Not affiliated with or endorsed by KORG Inc. or DETUNE Ltd. KORG and
KORG Gadget are trademarks of KORG Inc. This repo contains no game files. The
controller fix adds two small binding files to your own installation and edits one
config file that Steam can restore. The optional height mod adds UE4SS and one Lua
script to the game folder.

## License

[MIT-0](LICENSE) (MIT No Attribution): use, copy, change and ship any of it.
No credit or acknowledgement needed. UE4SS is a separate project under its own
MIT license. It is downloaded from its official release, not included here.
