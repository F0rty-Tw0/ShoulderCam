local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Controller = ns.Controller or require("ShoulderCam.Camera.Controller")
local Localization = ns.Localization or require("ShoulderCam.Core.Localization")
local Panel = ns.Panel or require("ShoulderCam.Settings.Panel")
local SavedState = ns.SavedState or require("ShoulderCam.Settings.SavedState")
local SlashCommand = ns.SlashCommand or require("ShoulderCam.Core.SlashCommand")

local ADDON_NAME = "ShoulderCam"
local POPUP_EVENT = "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"
local POPUP_DIALOG = "EXPERIMENTAL_CVAR_WARNING"

-- Addon entry point: popup suppression, init on ADDON_LOADED, key binding
-- and AddOn Compartment globals (SPEC.md → Settings).
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

local function onSettingChanged(key)
  Controller.OnSettingChanged(key)
end

function Bootstrap.Initialize(saved)
  db = SavedState.Initialize(saved)
  Controller.Install(db)
  Panel.Register(db, onSettingChanged)
  Controller.onRemembered = Panel.Refresh
  SlashCommand.Register(openSettings)
  return db
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

_G.BINDING_HEADER_SHOULDERCAM = Localization.Text(ADDON_NAME)
_G.BINDING_NAME_SHOULDERCAM_TOGGLE = Localization.Text("Toggle ShoulderCam")
_G.BINDING_NAME_SHOULDERCAM_SWAP = Localization.Text("Swap shoulder")

function _G.ShoulderCam_ToggleEnabled()
  flip("enabled")
end

function _G.ShoulderCam_SwapShoulder()
  flip("leftShoulder")
end

-- AddOn Compartment (Retail): names declared in the TOC.
_G.ShoulderCam_OnAddonCompartmentClick = openSettings

function _G.ShoulderCam_OnAddonCompartmentEnter(_, button)
  local tooltip = _G.GameTooltip
  tooltip:SetOwner(button, "ANCHOR_LEFT")
  tooltip:SetText(Localization.Text(ADDON_NAME))
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
  _G.ShoulderCamDB = Bootstrap.Initialize(_G.ShoulderCamDB)
end)

ns.Bootstrap = Bootstrap
return Bootstrap
