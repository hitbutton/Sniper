Sniper = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0", "AceModuleCore-2.0", "FuBarPlugin-2.0")
Sniper:SetModuleMixins("AceDebug-2.0")
local Tablet = AceLibrary("Tablet-2.0")
local Dewdrop = AceLibrary("Dewdrop-2.0")

Sniper.independentProfile = true
Sniper.defaultMinimapPosition = 270
Sniper.cannotDetachTooltip = true
Sniper.tooltipHidderWhenEmpty = false
Sniper.hasIcon = "Interface\\Icons\\Ability_EyeOfTheOwl"


BINDING_HEADER_SNIPER = "Sniper"
BINDING_NAME_SNIPER_SNIPE = "Snipe"
BINDING_NAME_SNIPER_ADDCURRENTTARGET = "Add current target"
BINDING_NAME_SNIPER_REMOVECURRENTTARGET = "Remove current target"

function Sniper:OnInitialize()
  self:RegisterDB("SniperDB")
  self:RegisterDefaults("profile", {
    targets = {},
    snipeSpell = {},
  })
  --self:RegisterChatCommand( { "/sniperconfig" } , self:BuildOptions() )
  SlashCmdList["SNIPER"] = function(parameter) Sniper:Slash(parameter) end
  SLASH_SNIPER1 = "/sniper"
end

function Sniper:Slash(parameter)
  if parameter == "add" then
    self:AddCurrentTarget()
  elseif parameter == "remove" then
    self:RemoveCurrentTarget()
  else
    self:Snipe()
  end
end

function Sniper:OnMenuRequest()
  Dewdrop:FeedAceOptionsTable(self:BuildOptions())
end

function Sniper:BuildOptions()
  local SniperMenu = {
    type = "group",
    desc = "Sniper options",
    args = {
      setSpell = {
        type = "text",
        name = "Set Spell",
        desc = "Set Spell",
        usage = "Set Spell",
        get = function() return self.db.profile.snipeSpell[1] end,
        set = function(v) self.db.profile.snipeSpell[1] = v end,
      },
      setSpell2 = {
        type = "text",
        name = "Set Backup Spell",
        desc = "Set Backup Spell",
        usage = "Set Backup Spell",
        get = function() return self.db.profile.snipeSpell[2] end,
        set = function(v) self.db.profile.snipeSpell[2] = v end,
      },
      addTarget = {
        type = "text",
        name = "Add Target",
        desc = "Add Target",
        usage = "Add Target",
        get = function() return "" end,
        set = function(v) self:AddTarget(v) end,
      },
      removeTarget = {
        type = "group",
        name = "Remove Target",
        desc = "Remove Target",
        args = {},
      },
      divider = {
        type = "header",
        order = 9999,
      },
    }
  }
  self:ValidateTargets()
  for target in self.db.profile.targets do
    local funcs = self:GetFuncsForTarget(target)    
    SniperMenu.args.removeTarget.args[string.gsub(target,"%A", "")] = {
      type = "execute",
      name = target,
      desc = target,
      func = funcs.funcRemove,
    }
  end
  return SniperMenu
end

function Sniper:GetFuncsForTarget(target)
  return {
    funcRemove = function() self:RemoveTarget(target) end,
  }
end

function Sniper:OnTooltipUpdate()
  local cat = Tablet:AddCategory("columns",1)
  cat:AddLine("text","Snipe spell is " .. (self.db.profile.snipeSpell[1] or "not set") )
  cat:AddLine("text","Backup Snipe spell is " .. (self.db.profile.snipeSpell[2] or "not set") )
  cat = Tablet:AddCategory("columns",1)
  cat:AddLine("text","Targets:")
  self:ValidateTargets()
  for target in self.db.profile.targets do
    cat:AddLine("text",target)
  end
end

function Sniper:AddTarget(name)
  if name then
    self.db.profile.targets[name] = true
  end
end

function Sniper:AddCurrentTarget()
  if UnitExists("target") then
    self:AddTarget(UnitName("target"))
  end
end

function Sniper:RemoveTarget(name)
  if name then
    self.db.profile.targets[name] = nil
  end
end

function Sniper:RemoveCurrentTarget()
  if UnitExists("target") then
    self:RemoveTarget(UnitName("target"))
  end
end

function Sniper:Snipe()
  self:ValidateTargets()
  local found = false
  ClearTarget()
  for n = 1, 12 do
    TargetNearestEnemy()
    if self.db.profile.targets[UnitName("target")] and not UnitIsTapped("target") then
      found = true
      break
    end
  end
  if found then
    for _,spell in self.db.profile.snipeSpell do
      CastSpellByName(spell)
    end
  else
    ClearTarget()
  end
end

function Sniper:ValidateTargets()
  if not self.db.profile.targets or type(self.db.profile.targets) ~= "table" then
    self.db.profile.targets = {}
  end
end
