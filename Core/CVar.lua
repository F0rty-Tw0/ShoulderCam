local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local format = string.format
local tostring = tostring

-- The one CVar write path: skips CVars the client lacks and values already
-- set, so a mode switch writes only what changes.
local CVar = {}

-- %.14g gives the same text on Lua 5.1 and 5.4 (5.4 prints 2.0 as "2.0").
local function normalize(value)
  if type(value) == "number" then
    return format("%.14g", value)
  end
  return tostring(value)
end

function CVar.Set(name, value)
  local current = _G.GetCVar(name)
  local text = normalize(value)
  if current == nil or current == text then
    return false
  end
  _G.SetCVar(name, text)
  return true
end

ns.CVar = CVar
return CVar
