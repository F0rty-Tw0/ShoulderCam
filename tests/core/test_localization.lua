local Assert = require("tests.helpers.assert")
local Localization = require("ShoulderCam.Core.Localization")

local function test_english_text_is_its_own_key()
  Assert.equal(Localization.Text("Shoulder offset"), "Shoulder offset")
end

local function test_catalog_entry_replaces_english_text()
  Localization.catalog["Shoulder offset"] = "Schulterversatz"
  Assert.equal(Localization.Text("Shoulder offset"), "Schulterversatz")
  Localization.catalog["Shoulder offset"] = nil
end

return function()
  test_english_text_is_its_own_key()
  test_catalog_entry_replaces_english_text()
end
