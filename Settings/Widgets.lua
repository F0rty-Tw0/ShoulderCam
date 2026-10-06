local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("ShoulderCam.Core.Localization")

local BOX_SIZE = 22
local LABEL_GAP = 4
local LABEL_OFFSET_Y = -5
local LABEL_WIDTH = 170
local SLIDER_WIDTH = 190
local SLIDER_HEIGHT = 20
local SLIDER_OFFSET_Y = -16
local LABEL_FONT = "GameFontHighlight"
local DISABLED_FONT = "GameFontDisable"
-- Shortest round-trip text for a number; "%g" never prints "20.0".
local NUMBER_FORMAT = "%.14g"

-- One setting row each: a checkbox or a titled slider bound to db[entry.key].
-- Each returns a wrapper { frame, label, key, :Refresh(db), :SetActive(bool) }
-- so nothing of ours lands on (or shadows members of) Blizzard's frames.
-- A widget writes db and calls onChanged(key) only on a player change;
-- :Refresh(db) re-reads db silently and :SetActive(false) greys it out.
local Widgets = {}

local function addLabel(parent, text, x, y)
  local label = parent:CreateFontString(nil, "ARTWORK", LABEL_FONT)
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  label:SetJustifyH("LEFT")
  label:SetText(Localization.Text(text))
  return label
end

local function setActive(self, active)
  self.frame:SetEnabled(active)
  self.label:SetFontObject(active and LABEL_FONT or DISABLED_FONT)
end

-- Decimal places of a step (0.05 -> 2, 0.5 -> 1, 1 -> 0).
local function decimalsOf(step)
  local fraction = string.match(string.format(NUMBER_FORMAT, step), "%.(%d+)$")
  return fraction and #fraction or 0
end

-- Rounds away float noise (7 * 0.05 = 0.35000000000000003 -> 0.35).
local function roundTo(value, decimals)
  return tonumber(string.format("%." .. decimals .. "f", value))
end

local function snap(value, entry, decimals)
  return roundTo(entry.min + math.floor((value - entry.min) / entry.step + 0.5) * entry.step, decimals)
end

function Widgets.Checkbox(parent, entry, x, y, db, onChanged)
  local box = _G.CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  box:SetSize(BOX_SIZE, BOX_SIZE)
  box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  box:SetHitRectInsets(0, -LABEL_WIDTH, 0, 0)
  local key = entry.key
  local widget = { frame = box, key = key, SetActive = setActive }
  widget.label = addLabel(parent, entry.label, x + BOX_SIZE + LABEL_GAP, y + LABEL_OFFSET_Y)
  widget.label:SetWidth(LABEL_WIDTH)
  box:SetScript("OnClick", function(self)
    db[key] = self:GetChecked() and true or false
    onChanged(key)
  end)
  function widget:Refresh(current)
    self.frame:SetChecked(current[key])
  end
  widget:Refresh(db)
  return widget
end

-- MinimalSliderWithSteppersTemplate, set up the way ActionCamPlus does
-- (ActionCamPlusConfig.lua:169-172) without Settings.CreateSliderOptions.
function Widgets.Slider(parent, entry, x, y, db, onChanged)
  local slider = _G.CreateFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
  slider:SetSize(SLIDER_WIDTH, SLIDER_HEIGHT)
  slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y + SLIDER_OFFSET_Y)
  local key = entry.key
  local widget = { frame = slider, key = key, label = addLabel(parent, entry.label, x, y), SetActive = setActive }
  local mixin = _G.MinimalSliderWithSteppersMixin
  local right = mixin.Label.Right
  local decimals = decimalsOf(entry.step)
  local formatters = {
    [right] = _G.CreateMinimalSliderFormatter(right, function(value)
      return string.format(NUMBER_FORMAT, roundTo(value, decimals))
    end),
  }
  slider:Init(db[key], entry.min, entry.max, (entry.max - entry.min) / entry.step, formatters)
  local refreshing = false
  slider:RegisterCallback(mixin.Event.OnValueChanged, function(_owner, value)
    if refreshing then
      return
    end
    local snapped = snap(value, entry, decimals)
    if db[key] == snapped then
      return
    end
    db[key] = snapped
    onChanged(key)
  end, widget)
  function widget:Refresh(current)
    refreshing = true
    self.frame:SetValue(current[key])
    refreshing = false
  end
  return widget
end

ns.Widgets = Widgets
return Widgets
