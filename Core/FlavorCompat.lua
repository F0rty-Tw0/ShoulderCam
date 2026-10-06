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

ns.FlavorCompat = FlavorCompat
return FlavorCompat
