local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Feature flags come from API presence, never from the flavor: WoW: Forever
-- reports itself as Retail.
local FlavorCompat = {}

local getCVar = _G.GetCVar
FlavorCompat.hasActionCam = getCVar ~= nil and getCVar("test_cameraDynamicPitch") ~= nil

local settings = _G.Settings
FlavorCompat.hasSettingsApi = type(settings) == "table" and type(settings.RegisterCanvasLayoutCategory) == "function"

-- Registering an event the client lacks throws. Clients without the check
-- predate the flavor split, so their events are taken as known.
function FlavorCompat.IsEventKnown(event)
  local eventUtils = _G.C_EventUtils
  if type(eventUtils) ~= "table" or type(eventUtils.IsEventValid) ~= "function" then
    return true
  end
  return eventUtils.IsEventValid(event) == true
end

ns.FlavorCompat = FlavorCompat
return FlavorCompat
