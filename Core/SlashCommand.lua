local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SlashCommand = {}

function SlashCommand.Register(openSettings)
  _G.SLASH_SHOULDERCAM1 = "/shouldercam"
  _G.SLASH_SHOULDERCAM2 = "/shc"
  _G.SlashCmdList["SHOULDERCAM"] = function(_msg)
    openSettings()
  end
end

ns.SlashCommand = SlashCommand
return SlashCommand
