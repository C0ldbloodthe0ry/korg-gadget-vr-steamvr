#!/usr/bin/env python3
"""Generate bindings/<controller_type>.json for KORG Gadget VR (Steam app 2298070).

One table says which game actions each Touch control fires (LAYOUT); one table per
controller says where each Touch control sits on that controller (CONTROLLERS).
Add a controller by adding a CONTROLLERS entry, then run this and tools/check.py.
"""
import json
import os

APP_KEY = "steam.app.2298070"
ACTIONS = "/actions/main"

# Touch control -> game actions it fires on a Quest.
# Source: the game's own input config (DefaultInput.ini inside
# GadgetVRGame-WindowsNoEditor.pak), every ActionMapping/AxisMapping whose key is
# an OculusTouch_* key. Quest over Oculus Link is the only setup KORG supports, so
# this is the known-good layout. Several actions share one key, so one press fires
# all of them on a Quest too.
LAYOUT = {
    "right_trigger": ["VR_R_Trigger", "InterructionEnter"],        # OculusTouch_Right_Trigger_Click
    "left_trigger": ["VR_L_Trigger", "PadLeftTrigger"],            # OculusTouch_Left_Trigger_Click
    "right_grip": ["VR_R_Grip", "PadRightShoulder", "PadShiftButton"],  # OculusTouch_Right_Grip_Click
    "left_grip": ["VR_L_Grip", "PadLeftSholder", "PadShiftButton"],     # OculusTouch_Left_Grip_Click
    "a": ["VR_R_A_Button", "PadButtonEnter"],                      # OculusTouch_Right_A_Click
    "b": ["VR_R_B_Button", "PadButtonBack", "PadButtonRight"],     # OculusTouch_Right_B_Click
    "x": ["VR_L_X_Button", "PadButtonLeft", "PlayButton"],         # OculusTouch_Left_X_Click
    "y": ["VR_L_Y_Button", "PadButtonMenu"],                       # OculusTouch_Left_Y_Click
}
GRIP_PULL = {"right_grip": "RGrip axis", "left_grip": "LGrip axis"}  # OculusTouch_*_Grip_Axis
STICKS = {
    "left": "UIPadStickLeftX,UIPadStickLeftY X Y_axis2d",          # OculusTouch_Left_Thumbstick_X/Y
    "right": "UIPadStickRightX,UIPadStickRightY X Y_axis2d",       # OculusTouch_Right_Thumbstick_X/Y
}
LEFT_STICK_CLICK = "LeftStickPress"                                # OculusTouch_Left_Thumbstick_Click
LEFT_STICK_DIRECTIONS = {                                          # OculusTouch_Left_Thumbstick_Up/...
    "north": "PadDigitalUp", "south": "PadDigitalDown",
    "east": "PadDigitalRight", "west": "PadDigitalLeft",
}
CLICK_THRESHOLDS = {"click_activate_threshold": "0.7", "click_deactivate_threshold": "0.65"}
STICK_DPAD = {"sub_mode": "touch", "deadzone_pct": "70"}  # direction fires past 70% deflection

# Where each Touch control sits on each controller: (hand, input name, mode).
# "trigger" mode is for analog inputs (click comes from the thresholds above).
CONTROLLERS = {
    "oculus_touch": {
        "name": "KORG Gadget VR - Quest layout (Touch)",
        "description": "Same buttons as the Quest over Oculus Link, the layout KORG supports. "
                       "SteamVR adapts this binding to most other controllers automatically.",
        "stick": "joystick",
        "place": {
            "right_trigger": [("right", "trigger", "trigger")],
            "left_trigger": [("left", "trigger", "trigger")],
            "right_grip": [("right", "grip", "trigger")],
            "left_grip": [("left", "grip", "trigger")],
            "a": [("right", "a", "button")],
            "b": [("right", "b", "button")],
            "x": [("left", "x", "button")],
            "y": [("left", "y", "button")],
        },
    },
    # Placement follows SteamVR's own Touch-to-Frame remap
    # (drivers/frame_controller/resources/input/frame_controller_remapping.json):
    # left X = d-pad down, left Y = the other three d-pad buttons, right B also on
    # x and y, triggers also on the bumpers.
    "frame_controller": {
        "name": "KORG Gadget VR - Quest layout (Steam Frame)",
        "description": "Quest layout moved to the Frame the way SteamVR remaps Touch: "
                       "X = left d-pad down, Y = left d-pad up/left/right, B also on x and y, "
                       "triggers also on the bumpers.",
        "stick": "thumbstick",
        "place": {
            "right_trigger": [("right", "trigger", "trigger"), ("right", "bumper", "button")],
            "left_trigger": [("left", "trigger", "trigger"), ("left", "bumper", "button")],
            "right_grip": [("right", "grip", "trigger")],
            "left_grip": [("left", "grip", "trigger")],
            "a": [("right", "a", "button")],
            "b": [("right", "b", "button"), ("right", "x", "button"), ("right", "y", "button")],
            "x": [("left", "dpad_down", "button")],
            "y": [("left", "dpad_up", "button"), ("left", "dpad_left", "button"),
                  ("left", "dpad_right", "button")],
        },
    },
}


def action(name):
    return f"{ACTIONS}/in/{name.lower()}"


def build(controller_type, spec):
    sources = []
    for control, actions in LAYOUT.items():
        for hand, inp, mode in spec["place"][control]:
            path = f"/user/hand/{hand}/input/{inp}"
            params = dict(CLICK_THRESHOLDS) if mode == "trigger" else {}
            for i, act in enumerate(actions):
                inputs = {"click": {"output": action(act)}}
                if i == 0 and control in GRIP_PULL and mode == "trigger":
                    inputs["pull"] = {"output": action(GRIP_PULL[control])}
                sources.append({"path": path, "mode": mode, "parameters": params, "inputs": inputs})

    stick = spec["stick"]
    sources.append({
        "path": f"/user/hand/left/input/{stick}", "mode": "joystick", "parameters": {},
        "inputs": {"position": {"output": action(STICKS["left"])},
                   "click": {"output": action(LEFT_STICK_CLICK)}},
    })
    sources.append({
        "path": f"/user/hand/left/input/{stick}", "mode": "dpad", "parameters": dict(STICK_DPAD),
        "inputs": {d: {"output": action(a)} for d, a in LEFT_STICK_DIRECTIONS.items()},
    })
    sources.append({
        "path": f"/user/hand/right/input/{stick}", "mode": "joystick", "parameters": {},
        "inputs": {"position": {"output": action(STICKS["right"])}},
    })

    hands = ("left", "right")
    return {
        "action_manifest_version": 0,
        "alias_info": {},
        "app_key": APP_KEY,
        "bindings": {ACTIONS: {
            "haptics": [{"output": f"{ACTIONS}/out/vibrate{h}", "path": f"/user/hand/{h}/output/haptic"}
                        for h in hands],
            "poses": [{"output": action(f"controller{h}"), "path": f"/user/hand/{h}/pose/raw"}
                      for h in hands],
            "skeleton": [{"output": action(f"skeleton{h}"), "path": f"/user/hand/{h}/input/skeleton/{h}"}
                         for h in hands],
            "sources": sources,
        }},
        "category": "steamvr_input",
        "controller_type": controller_type,
        "description": spec["description"],
        "interaction_profile": "",
        "name": spec["name"],
        "options": {},
        "simulated_actions": [],
    }


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, "bindings")
    for controller_type, spec in CONTROLLERS.items():
        path = os.path.normpath(os.path.join(out, f"{controller_type}.json"))
        with open(path, "w", newline="\n") as f:
            json.dump(build(controller_type, spec), f, indent=2)
            f.write("\n")
        print("wrote", path)


if __name__ == "__main__":
    main()
