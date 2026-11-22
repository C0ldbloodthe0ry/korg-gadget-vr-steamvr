# KORG Gadget VR: SteamVR controller fix (unofficial)

On Steam, KORG Gadget VR only officially supports a Quest connected through
Oculus Link. On any other SteamVR setup (Steam Frame, Index, Vive, Pico, a Quest
over Steam Link, ALVR or Virtual Desktop) the controllers are not tracked and the
buttons do nothing. This repo adds the missing SteamVR controller bindings so the
game gets the same buttons a Quest on Oculus Link gets.

## A note to KORG

> Hopefully people won't need this for long. Korg, LOVE your devices and software
> but please take anything that is available to build on here and fix the app.
> Don't give up on it please as I was excited since it was teased and was
> heartbroken to never see it fixed. I bought it the day it launched. Good luck!
>
> — C0ldbloodthe0ry

The findings below, the binding files and the tools are MIT-licensed. Take whatever helps.

## What it fixes, and what it doesn't

| Problem | Status |
|---|---|
| Controllers not tracked / buttons do nothing under SteamVR | **Fixed by this repo** |
| You spawn a meter or more above the desk | Not fixed. Workaround [below](#spawning-too-high) |
| Doesn't start properly under Virtual Desktop (acknowledged by KORG) | Not addressed |
| No sound (one report on Index) | Unknown |

## Tested on

| Setup | Result |
|---|---|
| Steam Frame, Linux (CachyOS, Proton), SteamVR 2.19.3 beta | Testing in progress |
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

## Spawning too high

This happens under SteamVR on every headset reported so far. KORG has acknowledged
"issues with viewpoint". Until the game fixes it:

- **OVR Advanced Settings** (free on Steam, Windows and Linux): use its playspace
  offset to move your height down until the desk sits where your hands are.
- **Experimental:** the launch option `-hmd=OpenXRHMD` makes the game use its
  built-in OpenXR backend instead of SteamVR's. Tracking may then behave
  differently. Untested.

## For KORG / DETUNE developers

Measured on build 15331537. Nothing here needs the source code.

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
4. **The floating viewpoint** fits a game built around an eye-level tracking origin
   while SteamVR reports a floor-level one. The exe contains `vr.TrackingOrigin`.
   Setting the origin explicitly at startup and placing the pawn to match would
   likely fix it. This is a hypothesis, not confirmed.

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
- Please don't commit files from the game itself.

## Disclaimer

Unofficial. Not affiliated with or endorsed by KORG Inc. or DETUNE Ltd. KORG and
KORG Gadget are trademarks of KORG Inc. This repo contains no game files. It adds
two small binding files to your own installation and edits one config file that
Steam can restore.

## License

[MIT](LICENSE)
