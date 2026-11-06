local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Controller = ns.Controller or require("ShoulderCam.Camera.Controller")
local Constants = ns.Constants or require("ShoulderCam.Core.Constants")
local FlavorCompat = ns.FlavorCompat or require("ShoulderCam.Core.FlavorCompat")
local Localization = ns.Localization or require("ShoulderCam.Core.Localization")
local MinimapButton = ns.MinimapButton or require("ShoulderCam.Settings.MinimapButton")
local Panel = ns.Panel or require("ShoulderCam.Settings.Panel")
local SavedState = ns.SavedState or require("ShoulderCam.Settings.SavedState")
local SlashCommand = ns.SlashCommand or require("ShoulderCam.Core.SlashCommand")

local ADDON_NAME = "ShoulderCam"
local POPUP_EVENT = "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"
local POPUP_DIALOG = "EXPERIMENTAL_CVAR_WARNING"
local MINIMAP_KEY = "minimapButton"
-- What Panel reports after its Defaults button reset every setting.
local DEFAULTS_KEY = "*defaults"
local MESSAGE_ON = "Shoulder Cam: on"
local MESSAGE_OFF = "Shoulder Cam: off"
local MESSAGE_LEFT = "Shoulder Cam: left shoulder"
local MESSAGE_RIGHT = "Shoulder Cam: right shoulder"

-- Addon entry point: popup suppression, init on ADDON_LOADED, key binding
-- AddOn Compartment globals, the minimap button and the slash command's chat
-- confirmations (SPEC.md → Settings).
local Bootstrap = {}

local db

-- The "experimental feature" popup (SPEC.md → Modes): same two lines as
-- ActionCamPlus. GameEvent exists on Retail only.
pcall(_G.UIParent.UnregisterEvent, _G.UIParent, POPUP_EVENT)
local gameEvent = _G.GameEvent
if type(gameEvent) == "table" then
  gameEvent.HandleExperimentalCVarConfirmationNeeded = function() end
end
-- The client can fire the event at login before addons load: close a popup
-- already up. Hiding skips its Disable button, which resets the camera CVars.
local hidePopup = _G.StaticPopup_Hide
if hidePopup then
  hidePopup(POPUP_DIALOG)
end

local function openSettings()
  Panel.Open()
end

-- The minimap button is cosmetic: showing or hiding it never re-applies the
-- camera (that would restart a running shoulder-offset slide).
local function onSettingChanged(key)
  if key == MINIMAP_KEY then
    MinimapButton.Refresh()
    return
  end
  Controller.OnSettingChanged(key)
  if key == DEFAULTS_KEY then
    MinimapButton.Refresh()
  end
end

-- Key bindings fire before ADDON_LOADED too: no-op until then.
local function flip(key)
  if not db then
    return
  end
  db[key] = not db[key]
  Controller.OnSettingChanged(key)
  Panel.Refresh()
end

local function toggleEnabled()
  flip("enabled")
end

local function swapShoulder()
  flip("leftShoulder")
end

-- The silent set: the minimap button uses it as is.
local actions = { open = openSettings, toggle = toggleEnabled, swap = swapShoulder }

-- Only the slash command speaks (it is registered after `db` is set).
local function say(message)
  _G.print(Localization.Text(message))
end

local function toggleAndSay()
  toggleEnabled()
  say(db.enabled and MESSAGE_ON or MESSAGE_OFF)
end

local function swapAndSay()
  swapShoulder()
  say(db.leftShoulder and MESSAGE_LEFT or MESSAGE_RIGHT)
end

local slashActions = { open = openSettings, toggle = toggleAndSay, swap = swapAndSay }

function Bootstrap.Initialize(saved)
  db = SavedState.Initialize(saved)
  -- Saved before anything else runs: a later Lua error must not leave the
  -- client writing back the raw file and losing this session's changes.
  _G.ShoulderCamDB = db
  Controller.Install(db)
  Panel.Register(db, onSettingChanged)
  Controller.onRemembered = Panel.Refresh
  SlashCommand.Register(slashActions)
  -- No action camera: the page only says so. No Settings API: no page to
  -- open and no checkbox to hide the button. Either way, no button.
  if FlavorCompat.hasActionCam and FlavorCompat.hasSettingsApi then
    MinimapButton.Install(db, actions)
  end
  return db
end

_G.BINDING_HEADER_SHOULDERCAM = Localization.Text(Constants.DISPLAY_NAME)
_G.BINDING_NAME_SHOULDERCAM_TOGGLE = Localization.Text("Toggle Shoulder Cam")
_G.BINDING_NAME_SHOULDERCAM_SWAP = Localization.Text("Swap shoulder")

_G.ShoulderCam_ToggleEnabled = toggleEnabled

_G.ShoulderCam_SwapShoulder = swapShoulder

-- AddOn Compartment (Retail): names declared in the TOC.
_G.ShoulderCam_OnAddonCompartmentClick = openSettings

function _G.ShoulderCam_OnAddonCompartmentEnter(_, button)
  local tooltip = _G.GameTooltip
  tooltip:SetOwner(button, "ANCHOR_LEFT")
  tooltip:SetText(Localization.Text(Constants.DISPLAY_NAME))
  tooltip:AddLine(Localization.Text("Click to open settings."))
  tooltip:Show()
end

function _G.ShoulderCam_OnAddonCompartmentLeave()
  _G.GameTooltip:Hide()
end

local loader = _G.CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _event, loadedName)
  if loadedName ~= ADDON_NAME then
    return
  end
  self:UnregisterEvent("ADDON_LOADED")
  Bootstrap.Initialize(_G.ShoulderCamDB)
end)

ns.Bootstrap = Bootstrap
return Bootstrap
