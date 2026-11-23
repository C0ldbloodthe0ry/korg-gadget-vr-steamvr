--[[
  KORG Gadget VR height fix: a UE4SS Lua mod.
  https://github.com/C0ldbloodthe0ry/korg-gadget-vr-steamvr

  Under SteamVR the game runs with a floor-level tracking origin. Your real
  head height is then added on top of the camera height the game already sets,
  and you float above the desk. This mod switches the game to an eye-level
  origin and recenters on your head once the headset is tracking. That is how
  the game behaves on a Quest over Oculus Link.

  Press F8 on the keyboard to recenter at any time.
  Log: ue4ss/UE4SS.log next to GadgetGame-Win64-Shipping.exe.
]]

local Config = {
    -- Seconds between the headset starting to track and the first recenter.
    -- Get into your playing position before it runs out.
    FirstRecenterDelaySeconds = 5,
    -- Keyboard key that recenters. Set to nil to turn it off.
    RecenterKey = Key.F8,
    -- When recentering, also turn the scene to face where you are looking.
    ResetFacing = true,
    -- Stop waiting for a tracked headset after this many seconds.
    WaitForHeadsetSeconds = 300,
}

local TAG = "[KorgGadgetHeightFix] "
local ORIGIN_EYE = 1     -- EHMDTrackingOrigin: Floor = 0, Eye = 1, Stage = 2
local RESET_POSITION = 1 -- EOrientPositionSelector: Orientation = 0, Position = 1,
local RESET_BOTH = 2     --                          OrientationAndPosition = 2

local function Log(message)
    print(TAG .. message .. "\n")
end

local library = nil
local function HMD()
    if library == nil or not library:IsValid() then
        library = StaticFindObject("/Script/HeadMountedDisplay.Default__HeadMountedDisplayFunctionLibrary")
    end
    return library
end

local function HeadsetActive(lib)
    return lib:IsValid() and lib:IsHeadMountedDisplayEnabled()
end

-- Diagnostics only. Failures here must never stop the fix itself.
local function DeviceName(lib)
    local ok, name = pcall(function() return lib:GetHMDDeviceName():ToString() end)
    return ok and name or "?"
end

local function HeadHeight(lib)
    local ok, height = pcall(function()
        local rotation, position = {}, {}
        lib:GetOrientationAndPosition(rotation, position)
        return string.format("%.0f cm", position.Z)
    end)
    return ok and height or "?"
end

local function Recenter(reason)
    local lib = HMD()
    if not HeadsetActive(lib) then
        Log(reason .. ": no active headset, not recentering")
        return
    end
    local before = HeadHeight(lib)
    lib:ResetOrientationAndPosition(0.0, Config.ResetFacing and RESET_BOTH or RESET_POSITION)
    Log(string.format("%s: recentered, head height %s -> %s", reason, before, HeadHeight(lib)))
end

local function UseEyeLevel(reason)
    local lib = HMD()
    if not lib:IsValid() then
        Log(reason .. ": HeadMountedDisplayFunctionLibrary not found")
        return
    end
    local was = lib:GetTrackingOrigin()
    if was ~= ORIGIN_EYE then
        lib:SetTrackingOrigin(ORIGIN_EYE)
        Log(string.format("%s: tracking origin %s -> %s on %s",
            reason, tostring(was), tostring(lib:GetTrackingOrigin()), DeviceName(lib)))
        -- Let the runtime deliver poses in the new space before recentering.
        ExecuteInGameThreadWithDelay(500, function() Recenter(reason) end)
    else
        Recenter(reason)
    end
end

-- Startup: wait for a tracked headset, give the player time to settle, then fix.
local started = false
local waited = 0
local waitLoop
waitLoop = LoopInGameThreadWithDelay(1000, function()
    waited = waited + 1
    local lib = HMD()
    if HeadsetActive(lib) and lib:HasValidTrackingPosition() then
        CancelDelayedAction(waitLoop)
        Log(string.format("headset %s is tracking, origin %s; recentering in %d s",
            DeviceName(lib), tostring(lib:GetTrackingOrigin()), Config.FirstRecenterDelaySeconds))
        ExecuteInGameThreadWithDelay(Config.FirstRecenterDelaySeconds * 1000, function()
            started = true
            UseEyeLevel("startup")
        end)
    elseif waited >= Config.WaitForHeadsetSeconds then
        CancelDelayedAction(waitLoop)
        Log(string.format("no tracked headset after %d s; press F8 once you are in VR", waited))
    end
end)

-- If anything switches the origin back on a level change, switch it again.
RegisterLoadMapPostHook(function(Engine, World)
    ExecuteInGameThreadWithDelay(1000, function()
        local lib = HMD()
        if started and HeadsetActive(lib) and lib:GetTrackingOrigin() ~= ORIGIN_EYE then
            UseEyeLevel("level load")
        end
    end)
end)

if Config.RecenterKey then
    RegisterKeyBind(Config.RecenterKey, function()
        ExecuteInGameThread(function() UseEyeLevel("key") end)
    end)
end

Log("loaded")
