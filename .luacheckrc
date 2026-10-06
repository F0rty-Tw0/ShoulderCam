-- .luacheckrc for ShoulderCam (WoW addon, all flavors)
-- Targets Lua 5.1 (WoW runtime)

std = "lua51"
max_line_length = false -- StyLua handles formatting; luacheck handles semantics
cache = true
jobs = 4

exclude_files = {
  ".luacheckrc",
  ".tools/",
}

ignore = {
  "212/self", -- unused 'self' in method definitions
  "211/addonName", -- unused first return from `local addonName, ns = ...`
  "212/addonName", -- same when treated as argument
  "331/ns", -- ns is set (mutated) then exported, not read directly
}

-- Globals the addon WRITES
globals = {
  -- SavedVariables (declared in .toc)
  "ShoulderCamDB",

  -- Slash command registration (Blizzard pattern)
  "SlashCmdList",
  "SLASH_SHOULDERCAM1",
  "SLASH_SHOULDERCAM2",

  -- AddOn Compartment handlers (named in the .toc)
  "ShoulderCam_OnAddonCompartmentClick",
  "ShoulderCam_OnAddonCompartmentEnter",
  "ShoulderCam_OnAddonCompartmentLeave",

  -- Key bindings (Bindings.xml)
  "ShoulderCam_ToggleEnabled",
  "ShoulderCam_SwapShoulder",
  "BINDING_HEADER_SHOULDERCAM",
  "BINDING_NAME_SHOULDERCAM_TOGGLE",
  "BINDING_NAME_SHOULDERCAM_SWAP",

  -- Experimental CVar popup suppression (Retail)
  GameEvent = { fields = { "HandleExperimentalCVarConfirmationNeeded" } },
}

-- Globals the addon READS (WoW API surface used by this addon)
read_globals = {
  "StaticPopup_Hide",

  -- Frames and hooks
  "CreateFrame",
  "UIParent",
  "GameTooltip",
  "hooksecurefunc",
  "Settings",
  "MinimalSliderWithSteppersMixin",
  "CreateMinimalSliderFormatter",
  "Minimap",
  "GetCursorPosition",

  -- Timers and client info
  "GetTime",
  "C_Timer",
  "GetBuildInfo",
  "WOW_PROJECT_ID",
  "WOW_PROJECT_MAINLINE",

  -- CVars and camera
  "GetCVar",
  "SetCVar",
  "GetCameraZoom",
  "CameraZoomIn",
  "CameraZoomOut",
  "MoveViewInStart",
  "MoveViewOutStart",
  "MoveViewInStop",
  "MoveViewOutStop",

  -- Player state
  "IsMounted",
  "UnitAffectingCombat",
  "GetShapeshiftFormID",
  "UnitClass",

  -- WoW: Forever global that throws for unknown modules
  "require",
}

-- Test files stub WoW globals freely
files["tests/**/*.lua"] = {
  globals = { "_G", "require" },
  ignore = {
    "111", -- setting undefined global (tests stub globals)
    "112", -- mutating undefined global
    "113", -- accessing undefined global
    "122", -- setting read-only field (tests stub read_globals)
    "142", -- setting undefined field of global
    "143", -- accessing undefined field of global
    "211", -- unused local variable
    "212", -- unused argument
    "421", -- shadowing local variable
    "431", -- shadowing upvalue
    "432", -- shadowing upvalue argument
  },
}
