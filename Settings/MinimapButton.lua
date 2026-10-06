local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("ShoulderCam.Core.Localization")

local cos, sin, rad, deg = math.cos, math.sin, math.rad, math.deg
-- Lua 5.1 (the game) has math.atan2; Lua 5.4 (local test runs) only math.atan(y, x).
---@diagnostic disable-next-line: deprecated
local atan2 = math.atan2 or math.atan

local BUTTON_NAME = "ShoulderCamMinimapButton"
local BUTTON_SIZE = 31
local FRAME_STRATA = "MEDIUM"
local FRAME_LEVEL = 8
local RADIUS_PAD = 5
local DRAG_TICK = 0.02
local FULL_TURN = 360
local ICON = "Interface\\AddOns\\ShoulderCam\\Media\\Icon"
local BACKGROUND = "Interface\\Minimap\\UI-Minimap-Background"
local BORDER = "Interface\\Minimap\\MiniMap-TrackingBorder"
local HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
local BACKGROUND_SIZE = 24
local ICON_SIZE = 18
local BORDER_SIZE = 50

-- Round button on the minimap edge (SPEC.md → Settings): left-click opens
-- the settings, right-click toggles the addon, a left drag moves it around
-- the edge. The frame is created the first time it must be shown; the drag
-- ticker runs only while the button is held.
local MinimapButton = {}

local db, actions, minimap, button, dragTicker

local function place()
  local angle = rad(db.minimapAngle % FULL_TURN)
  local radius = minimap:GetWidth() / 2 + RADIUS_PAD
  button:ClearAllPoints()
  button:SetPoint("CENTER", minimap, "CENTER", cos(angle) * radius, sin(angle) * radius)
end

-- Saves the cursor's angle from the minimap's center and moves there.
local function follow()
  local scale = minimap:GetEffectiveScale()
  local cursorX, cursorY = _G.GetCursorPosition()
  local centerX, centerY = minimap:GetCenter()
  db.minimapAngle = deg(atan2(cursorY / scale - centerY, cursorX / scale - centerX)) % FULL_TURN
  place()
end

local function stopDrag()
  if dragTicker then
    dragTicker:Cancel()
    dragTicker = nil
  end
end

local function startDrag()
  _G.GameTooltip:Hide()
  stopDrag()
  dragTicker = _G.C_Timer.NewTicker(DRAG_TICK, follow)
end

local function endDrag()
  follow()
  stopDrag()
end

local function onClick(_self, mouseButton)
  if mouseButton == "RightButton" then
    actions.toggle()
  else
    actions.open()
  end
end

local function showTooltip(self)
  local tooltip = _G.GameTooltip
  tooltip:SetOwner(self, "ANCHOR_LEFT")
  tooltip:SetText(Localization.Text("ShoulderCam"))
  tooltip:AddLine(Localization.Text("Left-click: settings"))
  tooltip:AddLine(Localization.Text("Right-click: toggle on/off"))
  tooltip:Show()
end

local function hideTooltip()
  _G.GameTooltip:Hide()
end

local function addTexture(frame, path, layer, size)
  local texture = frame:CreateTexture(nil, layer)
  texture:SetTexture(path)
  texture:SetSize(size, size)
  return texture
end

-- LibDBIcon's layout (LibDBIcon-1.0.lua:533-537,572-578,607-615).
local function create()
  local frame = _G.CreateFrame("Button", BUTTON_NAME, minimap)
  frame:SetSize(BUTTON_SIZE, BUTTON_SIZE)
  frame:SetFrameStrata(FRAME_STRATA)
  frame:SetFrameLevel(FRAME_LEVEL)
  frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  frame:RegisterForDrag("LeftButton")
  addTexture(frame, BACKGROUND, "BACKGROUND", BACKGROUND_SIZE):SetPoint("CENTER")
  addTexture(frame, ICON, "ARTWORK", ICON_SIZE):SetPoint("CENTER")
  addTexture(frame, BORDER, "OVERLAY", BORDER_SIZE):SetPoint("TOPLEFT", 0, 0)
  frame:SetHighlightTexture(HIGHLIGHT)
  frame:SetScript("OnClick", onClick)
  frame:SetScript("OnEnter", showTooltip)
  frame:SetScript("OnLeave", hideTooltip)
  frame:SetScript("OnDragStart", startDrag)
  frame:SetScript("OnDragStop", endDrag)
  frame:SetScript("OnHide", stopDrag)
  return frame
end

-- Shows or hides the button from db.minimapButton; no-op until installed.
function MinimapButton.Refresh()
  if not db then
    return
  end
  if db.minimapButton then
    button = button or create()
    place()
    button:Show()
  elseif button then
    button:Hide()
  end
end

-- actions = { open = fn, toggle = fn }. Does nothing without a minimap.
function MinimapButton.Install(settingsDb, buttonActions)
  minimap = _G.Minimap
  if not minimap then
    return
  end
  db, actions = settingsDb, buttonActions
  MinimapButton.Refresh()
end

ns.MinimapButton = MinimapButton
return MinimapButton
