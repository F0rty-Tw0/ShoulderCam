local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Defaults = ns.Defaults or require("ShoulderCam.Settings.Defaults")
local FlavorCompat = ns.FlavorCompat or require("ShoulderCam.Core.FlavorCompat")
local Localization = ns.Localization or require("ShoulderCam.Core.Localization")
local Widgets = ns.Widgets or require("ShoulderCam.Settings.Widgets")

local CATEGORY_NAME = "ShoulderCam"
local DEFAULTS_KEY = "*defaults"
local LEFT = 16
local TOP = -16
local TITLE_HEIGHT = 36
local HEADER_HEIGHT = 26
local HEADER_OFFSET_Y = -8
local CHECKBOX_HEIGHT = 26
local SLIDER_ROW_HEIGHT = 46
local COLUMN_WIDTH = { main = 310, situations = 215 }
local MODE_COLUMN = { onFoot = 1, combat = 2, mounted = 3 }

-- Two canvas pages under Options → AddOns: the main category and the
-- Situations subcategory (SPEC.md → Settings). Each page builds its widgets
-- on its first show. The native Defaults button calls OnDefault on a page.
local Panel = {}

local mainCategory
local db, onChanged
local widgets = {}

local function addText(frame, font, text, x, y)
  local label = frame:CreateFontString(nil, "ARTWORK", font)
  label:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
  label:SetJustifyH("LEFT")
  label:SetText(text)
  return label
end

-- Mode -> db key of that mode's own switch (combatEnabled, mountedEnabled).
local modeToggles = {}
for _, entry in ipairs(Defaults.list) do
  if entry.modeToggle then
    modeToggles[entry.mode] = entry.key
  end
end

-- Greys every widget of a switched-off mode except the switch itself.
local function updateActive()
  for _, widget in ipairs(widgets) do
    local entry = Defaults.byKey[widget.key]
    local toggle = modeToggles[entry.mode]
    if toggle and not entry.modeToggle then
      widget:SetActive(db[toggle])
    end
  end
end

local function changed(key)
  updateActive()
  onChanged(key)
end

local function addWidget(frame, entry, x, y)
  local create = entry.min and Widgets.Slider or Widgets.Checkbox
  widgets[#widgets + 1] = create(frame, entry, x, y, db, changed)
  return entry.min and SLIDER_ROW_HEIGHT or CHECKBOX_HEIGHT
end

local function buildPage(frame, pageName, title)
  addText(frame, "GameFontNormalLarge", title, LEFT, TOP)
  local width = COLUMN_WIDTH[pageName]
  local x, y = LEFT, TOP - TITLE_HEIGHT
  local page
  for _, entry in ipairs(Defaults.list) do
    page = entry.page or page
    if page == pageName and not entry.page then
      local column = entry.column or (entry.header and MODE_COLUMN[entry.mode])
      if column then
        x, y = LEFT + (column - 1) * width, TOP - TITLE_HEIGHT
      end
      if entry.header then
        addText(frame, "GameFontNormal", Localization.Text(entry.header), x, y + HEADER_OFFSET_Y)
        y = y - HEADER_HEIGHT
      elseif entry.key and entry.label then
        y = y - addWidget(frame, entry, x, y)
      end
    end
  end
end

local function buildUnavailable(frame)
  addText(frame, "GameFontNormalLarge", CATEGORY_NAME, LEFT, TOP)
  addText(frame, "GameFontHighlight", Localization.Text("Action camera is not available in this game version."), LEFT, TOP - TITLE_HEIGHT)
end

function Panel.Refresh()
  for _, widget in ipairs(widgets) do
    widget:Refresh(db)
  end
  updateActive()
end

-- Bound to both pages; the client's "All Settings" reset may call both,
-- so only a reset that changed something reports, and only once.
local function restoreDefaults()
  local differs = false
  for key, entry in pairs(Defaults.byKey) do
    differs = differs or db[key] ~= entry.default
  end
  Defaults.Reset(db)
  Panel.Refresh()
  if differs then
    onChanged(DEFAULTS_KEY)
  end
end

local function newPage(build)
  local frame = _G.CreateFrame("Frame")
  -- New frames start shown. The settings window shows a page by reparenting
  -- it and calling Show(); on an already-shown page OnShow never fires when
  -- the window was showing another addon's page, so the page stayed empty.
  frame:Hide()
  local built = false
  frame:SetScript("OnShow", function(self)
    if not built then
      built = true
      build(self)
    end
    Panel.Refresh()
  end)
  frame.OnCommit = function() end
  frame.OnRefresh = Panel.Refresh
  frame.OnDefault = restoreDefaults
  return frame
end

function Panel.Register(settingsDb, onSettingChanged)
  if not FlavorCompat.hasSettingsApi then
    return nil
  end
  db, onChanged = settingsDb, onSettingChanged
  local settings = _G.Settings
  if not FlavorCompat.hasActionCam then
    mainCategory = settings.RegisterCanvasLayoutCategory(newPage(buildUnavailable), CATEGORY_NAME)
    settings.RegisterAddOnCategory(mainCategory)
    return mainCategory
  end
  local main = newPage(function(frame)
    buildPage(frame, "main", CATEGORY_NAME)
  end)
  mainCategory = settings.RegisterCanvasLayoutCategory(main, CATEGORY_NAME)
  local situationsName = Localization.Text("Situations")
  local situations = newPage(function(frame)
    buildPage(frame, "situations", situationsName)
  end)
  settings.RegisterCanvasLayoutSubcategory(mainCategory, situations, situationsName)
  settings.RegisterAddOnCategory(mainCategory)
  return mainCategory
end

function Panel.Open()
  if mainCategory then
    _G.Settings.OpenToCategory(mainCategory:GetID())
  end
end

ns.Panel = Panel
return Panel
