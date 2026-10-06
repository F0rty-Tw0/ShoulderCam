local Assert = require("tests.helpers.assert")
local Constants = require("ShoulderCam.Core.Constants")

local function test_version_matches_toc()
  local tocVersion
  for line in io.lines("ShoulderCam.toc") do
    tocVersion = tocVersion or string.match(line, "^## Version: (%S+)")
  end
  Assert.equal(Constants.VERSION, tocVersion)
end

local function test_druid_mount_forms_follow_spec()
  local forms = {}
  for formId in pairs(Constants.DRUID_MOUNT_FORMS) do
    forms[#forms + 1] = formId
  end
  table.sort(forms)
  Assert.equal(table.concat(forms, ","), "3,4,27,29,48")
end

return function()
  test_version_matches_toc()
  test_druid_mount_forms_follow_spec()
end
