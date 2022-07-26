local addonName, addonTable = ...
local UseEvent = addonTable.Utils.UseEvent

local sharedDestGUID
local pickPocketCast = false
local pickPocketedUnits = {}
local playerClass = select(2, UnitClass("player"))
local isRogue = playerClass == "ROGUE"

if (not isRogue) then
  return
end

local function HandlePickPocketEvent(self, event, ...)
  if (event == "COMBAT_LOG_EVENT_UNFILTERED") then
    local eventInfo = CombatLogGetCurrentEventInfo
    local subEvent, _, sourceGUID = select(2, eventInfo())
    local destGUID, destName = select(8, eventInfo())
    local spellId = select(12, eventInfo()) or 0
    local pickPocket = spellId == 921
    local fromCurrentPlayer = sourceGUID and UnitIsUnit(sourceGUID, UnitGUID("player"))

    if (subEvent == "SPELL_CAST_SUCCESS" and pickPocket and fromCurrentPlayer) then
      pickPocketCast = true
      sharedDestGUID = destGUID
      local pickPocketedUnit = pickPocketedUnits[destGUID]

      -- Disallow overwriting pending states
      if (pickPocketedUnit and not pickPocketedUnit.state) then
        pickPocketedUnit = { state = "pending" }
      end
    end

  elseif (event == "UI_ERROR_MESSAGE") then
    local _, message = ...

    if (message == "Your target has already had its pockets picked") then
      local pickPocketedUnit = pickPocketedUnits[sharedDestGUID]

      if (pickPocketedUnit and pickPocketedUnit.state ~= "picked") then
        pickPocketedUnit = { state = "alreadyPicked" }
      end
    end
    if (message == "Your target has already had its pockets picked"
      or message == "Out of range."
      or message == "You have no target."
      or message == "No pockets to pick") then
        pickPocketCast = false
    end

  elseif (event == "LOOT_OPENED") then
    local _, lootFromItem = ...

    if (lootFromItem) then
      return
    end

    if (pickPocketCast == true) then
      pickPocketCast = false

      for i = 1, GetNumLootItems() do
        LootSlot(i)
      end

      CloseLoot()

      pickPocketedUnits[sharedDestGUID] = {
        state = "picked",
        time = GetTime()
      }
    end
  end
end

UseEvent(
  HandlePickPocketEvent,
  "COMBAT_LOG_EVENT_UNFILTERED",
  "UI_ERROR_MESSAGE",
  "LOOT_OPENED"
)

local iconMargin = 4
local iconSize = 18
local fontSize = 10
local pickPocketIcon = GetSpellTexture(921)
local isBigDebuffsAddOnLoaded = IsAddOnLoaded("BigDebuffs")

local function RequestIcon(unitGUID)
  if (not unitGUID) then
    return
  end

  for i, namePlate in ipairs(C_NamePlate.GetNamePlates()) do
    local correctNamePlate = UnitIsUnit(unitGUID, UnitGUID(namePlate.namePlateUnitToken))

    if (correctNamePlate) then
      local pickPocketedUnit = pickPocketedUnits[unitGUID]
      local unitPocketsPicked =
        pickPocketedUnit and
        (pickPocketedUnit.state == "picked" or
        pickPocketedUnit.state == "alreadyPicked")

      -- If unit has been pickpocketed, create or show icon
      if (unitPocketsPicked) then
        if (not namePlate.PickPocket) then
          namePlate.PickPocket = CreateFrame("Frame", "PickPocket", namePlate)
          namePlate.PickPocket:SetSize(iconSize, iconSize)

          namePlate.PickPocket.Icon = namePlate.PickPocket:CreateTexture(nil, "OVERLAY")
          namePlate.PickPocket.Icon:SetTexture(pickPocketIcon)
          namePlate.PickPocket.Icon:SetAllPoints()

          namePlate.PickPocket.Cooldown = CreateFrame("Cooldown", nil, namePlate.PickPocket, "CooldownFrameTemplate")
          namePlate.PickPocket.Cooldown:SetAllPoints()
          namePlate.PickPocket.Cooldown:SetHideCountdownNumbers(false)
          namePlate.PickPocket.Cooldown.Text = namePlate.PickPocket.Cooldown:GetRegions()
          namePlate.PickPocket.Cooldown.Text:SetFont(namePlate.PickPocket.Cooldown.Text:GetFont(), fontSize)
        end

        -- Anchor to bigDebuffs icon if visible, otherwise anchor to namePlate
        local bigDebuffs = namePlate.UnitFrame.BigDebuffs
        if (isBigDebuffsAddOnLoaded and bigDebuffs and bigDebuffs.current) then
          namePlate.PickPocket:SetPoint("LEFT", bigDebuffs, "RIGHT", iconMargin, 0)
        else
          namePlate.PickPocket:SetPoint("LEFT", namePlate.UnitFrame.healthBar, "RIGHT", iconMargin, 0)
        end

        local start = pickPocketedUnit.time
        local expireAfter = 7 * 60
        local duration = expireAfter - (GetTime() - start)

        namePlate.PickPocket.Cooldown:SetCooldown(start, expireAfter)
        namePlate.PickPocket:Show()
      end
    end
  end
end

local function HandleIcon(self, event, ...)
  if (event == "NAME_PLATE_UNIT_ADDED" or event == "UNIT_AURA_NAMEPLATE") then
    local unit = ...

    if (unit) then
      local unitGUID = UnitGUID(unit)
      RequestIcon(unitGUID)
    end

  elseif (event == "LOOT_OPENED") then
    local _, lootFromItem = ...

    if (not lootFromItem) then
      RequestIcon(sharedDestGUID)
    end

  elseif (event == "NAME_PLATE_UNIT_REMOVED") then
    local unit = ...

    if (not unit) then
      return
    end

    local namePlate = C_NamePlate.GetNamePlateForUnit(unit)

    if (namePlate.PickPocket) then
      CooldownFrame_Clear(namePlate.PickPocket.Cooldown)

      if (namePlate.PickPocket:IsShown()) then 
        namePlate.PickPocket:Hide()
      end
    end
  end
end

if (isBigDebuffsAddOnLoaded and BigDebuffs) then
  hooksecurefunc(BigDebuffs, "UNIT_AURA_NAMEPLATE", function(self, unit)
    HandleIcon(self, "UNIT_AURA_NAMEPLATE", unit)
  end)
end

UseEvent(
  HandleIcon,
  "PLAYER_TARGET_CHANGED",
  "NAME_PLATE_UNIT_ADDED",
  "NAME_PLATE_UNIT_REMOVED",
  "LOOT_OPENED"
)
