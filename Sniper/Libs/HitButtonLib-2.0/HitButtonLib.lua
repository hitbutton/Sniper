if not AceLibrary then error("HitButtonLib requires AceLibrary.") end

local lib = {}
local major,minor = "HitButtonLib-2.0",11

if not AceLibrary:IsNewVersion(major, minor) then return end

-- VARS
local talentCache
local spellDataCache
local actionDataCache
local refreshSlots
local frame
local tooltip

-- INIT
local function OnEvent()
  if ( event == "SPELL_LEARNED_IN_TAB" ) then
    spellDataCache = nil
  elseif ( event == "ACTIONBAR_SLOT_CHANGED" ) then
    refreshSlots = refreshSlots or {}
    refreshSlots[arg1] = true
  elseif ( event == "CHARACTER_POINTS_CHANGED" ) then
    talentCache = nil
  end
end

local function activate()
  frame = CreateFrame("FRAME","HitButtonLib_Frame",UIParent)
  frame:RegisterEvent("SPELL_LEARNED_IN_TAB")
  frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
  frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
  frame:SetScript("OnEvent", OnEvent )
end

local function tooltipInit()
  if not tooltip then
    tooltip = CreateFrame("GameTooltip", "HitButtonLib_Tooltip", nil, "GameTooltipTemplate")
    tooltip:Hide()
    tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
  end
end

-- GLOBAL FUNC
function PrintT(v,level)
  level = tonumber(level)
  if not level then
    level = 0
  end
  if type(v) ~= "table" then
    v = {v}
  end
  for k,t in pairs(v) do
    t = t or "-nil-"
    if ( type(t) == "table" ) then    
      DEFAULT_CHAT_FRAME:AddMessage(k .. ": -table-",1,1,1)
      PrintT(level + 1 , t)
      --[[
    elseif ( type(t) == "function" or type(t) == "userdata" ) then
      t = k .. ": " .. type(t)
      if (level > 0) then
        for i = 1, level do
          t = ">" .. t
        end
      end      
      DEFAULT_CHAT_FRAME:AddMessage(t,1,1,1)
      ]]
    else
      if ( type(t) == "function" or type(t) == "userdata" ) then
        t = "-" .. type(t) .. "-"
      end
      if ( type(t) == "boolean" ) then
        if t then
          t = "-true-"
        else
          t = "-false-"
        end
      end
      t = k .. ": " .. t
      if ( type(t) == "boolean") then
        t = "-" .. tostring(t) .. "-"
      elseif ( t == "" ) then
        t = '-""-'
      end
      if (level > 0) then
        for i = 1, level do
          t = ">" .. t
        end
      end
      DEFAULT_CHAT_FRAME:AddMessage(t,1,1,1)
    end
  end
end

-- ACTION FUNCS
local function validateRank(rank)
  local nRank
  if rank then
    local _, _,sRank = strfind(rank, "(%d+)")
    nRank = tonumber(sRank)
  end
  return nRank
end

local function GetActionName(action)
  tooltipInit()
  tooltip:SetAction(action)
  return HitButtonLib_TooltipTextLeft1:GetText(),HitButtonLib_TooltipTextRight1:GetText()
end

local function BuildActionSlotData(slot)
  if HasAction(slot) then
    if not GetActionText(slot) then
      local name,rank = GetActionName(slot)
      if name then
        local nRank = validateRank(rank) or 1
        actionDataCache[name] = actionDataCache[name] or {}
        if not actionDataCache[name].maxRank or nRank > actionDataCache[name].maxRank then
          actionDataCache[name].maxRank = nRank
        end
        actionDataCache[name].ranks = actionDataCache[name].ranks or {}
        local actionData = {
          slot = slot
        }
        actionDataCache[name].ranks[nRank] = actionData
      end
    else
      local name = "macro_" .. GetActionText(slot)
      actionDataCache[name] = slot
    end
  end
end

local function BuildActionCache()
  actionDataCache = {}
  for slot = 1,120 do
    BuildActionSlotData(slot)
  end
end

function lib:GetAction(name,rank)
  if not actionDataCache then
    BuildActionCache()
  elseif refreshSlots then
    for slot in refreshSlots do
      BuildActionSlotData(slot)
    end
  end
  refreshSlots = nil
  if not actionDataCache[name] then
    return nil
  end
  if string.find(name,"macro_") == 1 then
    return actionDataCache[name]
  end
  local nRank = validateRank(rank) or actionDataCache[name].maxRank
  if not actionDataCache[name].ranks[nRank] then
    return nil
  end
  local slot = actionDataCache[name].ranks[nRank].slot
  local checkName = GetActionName(slot)
  if name ~= checkName then
    actionDataCache = nil
    slot = self:GetAction(name,rank)
  end
  return slot
end

-- SPELL FUNCS
local function BuildSpellCache()
  spellDataCache = {}
  local splId = 1
  local name, rank = GetSpellName(splId,BOOKTYPE_SPELL)
  while name do
    local nRank = validateRank(rank) or 1
    spellDataCache[name] = spellDataCache[name] or {}
    if not spellDataCache[name].maxRank or nRank > spellDataCache[name].maxRank then
      spellDataCache[name].maxRank = nRank
    end
    spellDataCache[name].ranks = spellDataCache[name].ranks or {}
    local splData = {
      splId = splId
    }
    spellDataCache[name].ranks[nRank] = splData
    splId = splId + 1
    name, rank = GetSpellName(splId,BOOKTYPE_SPELL)
  end
end

function lib:GetSpellId(name,rank)
  if not spellDataCache then
    BuildSpellCache()
  end
  if not spellDataCache[name] then
    return nil
  end
  rank = validateRank(rank) or spellDataCache[name].maxRank
  if spellDataCache[name].ranks[rank] then
    return spellDataCache[name].ranks[rank].splId
  end
  return nil
end

function lib:GetSpellCD(name)
  local splId = self:GetSpellId(name)
  if not splId then
    return nil
  end
  local starttime,dur = GetSpellCooldown(self:GetSpellId(name),BOOKTYPE_SPELL)
  if starttime > 0 and dur > 0 then
    return starttime - GetTime() + dur
  end
  return 0
end

function lib:GetSpellManaCost(name,rank)
  local spl = self:GetSpellId(name,rank)
  if spl then
    tooltipInit()
    tooltip:SetSpell(spl,BOOKTYPE_SPELL)
    local strMana = HitButtonLib_TooltipTextLeft2:GetText()
    if strMana then
      local nMana,_
      for k,power in pairs({"Mana","Energy","Rage"}) do
        _,_,nMana = string.find(strMana,"(%d+) "..power)
        if nMana then
          return tonumber(nMana)
        end
      end
    end
  end
  return 0
end

--TALENT FUNCS
local function BuildTalentCache()
  talentCache = {}
  for tab = 1,3 do
    local numTalents = GetNumTalents(tab)
    for talent = 1,numTalents do
      local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab,talent)
      talentCache[name] = {
        iconTexture = iconTexture,
        tier = tier,
        column = column,
        rank = rank,
        maxRank = maxRank,
        isExceptional = isExceptional,
        meetsPrereq = meetsPrereq,
      }
    end
  end
end

function lib:GetTalentPoints(talent)
  if not talentCache then
    BuildTalentCache()
  end
  if not talentCache[talent] then
    return
  else
    return talentCache[talent].rank 
  end
end

--MOUNT FUNCS
local problem_mounts = {
	["Interface\\Icons\\Ability_Mount_PinkTiger"] = true,
	["Interface\\Icons\\Ability_Mount_WhiteTiger"] = true,
	["Interface\\Icons\\Spell_Nature_Swiftness"] = true,
	["Interface\\Icons\\INV_Misc_Foot_Kodo"] = true,
	["Interface\\Icons\\Ability_Mount_JungleTiger"] =true,
}

function lib:PlayerMounted()
  local buff,mounted
  for i = 1,24 do
    buff = UnitBuff("player",i)
    if buff then
      if problem_mounts[buff] or string.find(buff,"QirajiCrystal_") then
        -- hunter could be in group, could be warlock epic mount etc, check if this is truly a mount
        tooltipInit()
        tooltip:SetUnitBuff("player",i)
        if string.find(HitButtonLib_TooltipTextLeft2:GetText() or "","^Increases speed") then
          mounted = true
          break
        end
      elseif string.find(buff,"Mount_") then
        mounted = true
        break
      end
    else
      break
    end
  end
  return mounted
end

-- REGISTER LIB
AceLibrary:Register( lib, major, minor, activate )