local addonName, addonTable = ...

addonTable.Utils = {}

addonTable.Utils.UseEvent = function(callback, ...)
  local frame = CreateFrame("FRAME")

  for i = 1, select("#", ...) do
    local event = select(i, ...)
    frame:RegisterEvent(event)
  end

  frame:SetScript("OnEvent", callback)
end
