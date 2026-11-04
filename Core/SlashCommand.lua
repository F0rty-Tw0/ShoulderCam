local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("ShoulderCam.Core.Localization")

local lower = string.lower
local match = string.match

local USAGE = "Shoulder Cam: /shc, /shc toggle, /shc swap"
-- Whole trimmed, lowercased message -> action name; anything else prints USAGE.
local WORDS = { [""] = "open", toggle = "toggle", swap = "swap" }

-- `/shouldercam` and `/shc` (SPEC.md → Settings). actions = { open, toggle, swap }.
local SlashCommand = {}

function SlashCommand.Register(actions)
  _G.SLASH_SHOULDERCAM1 = "/shouldercam"
  _G.SLASH_SHOULDERCAM2 = "/shc"
  _G.SlashCmdList["SHOULDERCAM"] = function(msg)
    local action = actions[WORDS[lower(match(msg or "", "^%s*(.-)%s*$"))]]
    if action then
      action()
    else
      -- Looked up at call time so tests can capture it.
      _G.print(Localization.Text(USAGE))
    end
  end
end

ns.SlashCommand = SlashCommand
return SlashCommand
