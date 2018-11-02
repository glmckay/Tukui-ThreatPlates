local T, C, L = Tukui:unpack()

local TukuiColors = T["Colors"]
local ThreatPlates = CreateFrame("Frame")

--Localise globals
local UnitPlayerControlled = UnitPlayerControlled
local UnitIsTapDenied = UnitIsTapDenied
local UnitIsPlayer = UnitIsPlayer
local UnitReaction = UnitReaction
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitIsUnit = UnitIsUnit


-- Config
C["ThreatPlates"] = {
    ["Enable"] = true,
    ["BadAggro"] = { .78, .25, .25 },
    ["GoodTransition"] = { .85, .77, .36 },
    ["BadTransition"] = { .92, .64, .16 },
    ["GoodAggro"] = { .3,  .69, .3  },
    ["CheckOtherTanks"] = true,
    ["IsTankedByOther"] = { .8,  .1,  1   },
}

if (TukuiConfig) then
    TukuiConfig.enUS["ThreatPlates"] = {
        ["Enable"] = {
            ["Name"] = "Enable Threat Color on Namplates",
            ["Desc"] = "Derp",
        },
        ["BadAggro"] = {
            ["Name"] = "Bad threat color",
            ["Desc"] = "Color for bad threat status",
        },
        ["GoodTransition"] = {
            ["Name"] = "Good transition color",
            ["Desc"] = "Color for good threat status transition",
        },
        ["BadTransition"] = {
            ["Name"] = "Bad transition color",
            ["Desc"] = "Color for bad threat status transition",
        },
        ["GoodAggro"] = {
            ["Name"] = "Good threat color",
            ["Desc"] = "Color for good threat status",
        },
        ["CheckOtherTanks"] = {
            ["Name"] = "Check aggro of other tanks",
            ["Desc"] = "Show if a tank (other than the player) is tanking",
        },
        ["IsTankedByOther"] = {
            ["Name"] = "Other tank color",
            ["Desc"] = "Color given if another tank has aggro",
        },
    }
end



function ThreatPlates:UpdatePlayerRole()
    local assignedRole = UnitGroupRolesAssigned("player");
    if (assignedRole == "NONE") then
         self.PlayerIsTank = (GetSpecializationRole(GetSpecialization()) == "TANK")
    else
        self.PlayerIsTank = (assignedRole == "TANK")
    end
end


-- We keep a list of tanks in the group (other than the player)
function ThreatPlates:UpdateTankList()
    self.NumTanks = 0
    local NumMembers = GetNumGroupMembers()

    for i = 1, NumMembers do
        local UnitId = "raid"..i
        if (UnitGroupRolesAssigned(UnitId) == "TANK" and not UnitIsUnit(UnitId, "player")) then
            self.NumTanks = self.NumTanks + 1
            self.TankList[self.NumTanks] = UnitId
        end
    end
end


-- Modified version of the health bar's UpdateColor function
-- Lacks gradient color functionality, but it don't see how that could be used when coloring according to threat
function ThreatPlates:UpdateNamePlateColor(unit, cur, max)
    local t

    if (self.colorTapping and not UnitPlayerControlled(unit) and UnitIsTapDenied(unit)) then
        t = TukuiColors.tapped
    elseif (self.colorDisconnected and self.disconnected) then
        t = TukuiColors.disconnected
    elseif (self.colorClass and UnitIsPlayer(unit)) or
            (self.colorClassNPC and not UnitIsPlayer(unit)) or
            (self.colorClassPet and UnitPlayerControlled(unit) and not UnitIsPlayer(unit)) then
        t = TukuiColors.class[select(2, UnitClass(unit))]
    else
        local Status = select(2, UnitDetailedThreatSituation("player", unit))
        if (Status) then
            local NamePlate = self:GetParent()
            if (Status == 0 and NamePlate.IsTankedByOther) then
                t = TukuiColors.ThreatStatus.IsTankedByOther
            else
                if (ThreatPlates.PlayerIsTank) then
                    t = TukuiColors.ThreatStatus[Status+1]
                else
                    t = TukuiColors.ThreatStatus[4-Status]
                end
            end
        elseif(self.colorReaction and UnitReaction(unit, 'player')) then
            t = TukuiColors.reaction[UnitReaction(unit, 'player')]
        elseif(self.colorHealth) then
            t = TukuiColors.health
        end
    end

    if (t) then
        self:SetStatusBarColor(t[1], t[2], t[3])
    end
end


function ThreatPlates:UpdateAggroStatus()
    if not self.IsEnemyNPC then return end
    self.IsTankedByOther = false

    local IsTanking, Status = UnitDetailedThreatSituation("player", self.unit)

    if (Status) then
        if (not IsTanking) then
            for i = 1,ThreatPlates.NumTanks do
                if (select(1, UnitDetailedThreatSituation(ThreatPlates.TankList[i], self.unit))) then
                    self.IsTankedByOther = true
                    break
                end
            end
        end

        self.Health:UpdateColor(self.unit)
    end
end


function ThreatPlates:OnNamePlateUnitAdded(event, unit)
    if (self.unit == unit) then
        self.IsEnemyNPC = (UnitCanAttack(self.unit, "player") and not UnitIsPlayer(self.unit))
        self.IsTankedByOther = false
    end
end


function ThreatPlates:EditNameplateStyle()
    self.Health.UpdateColor = ThreatPlates.UpdateNamePlateColor

    self:RegisterEvent("NAME_PLATE_UNIT_ADDED", ThreatPlates.OnNamePlateUnitAdded)
    self:RegisterEvent("UNIT_THREAT_LIST_UPDATE", ThreatPlates.UpdateAggroStatus)
end

hooksecurefunc(T["UnitFrames"], "Nameplates", ThreatPlates.EditNameplateStyle)


function ThreatPlates:Enable()
    -- Snapshot the config values
    local CheckOtherTanks = C.ThreatPlates.CheckOtherTanks
    TukuiColors["ThreatStatus"] = {
         C.ThreatPlates.BadAggro,
         C.ThreatPlates.GoodTransition,
         C.ThreatPlates.BadTransition,
         C.ThreatPlates.GoodAggro,
         ["IsTankedByOther"] = C.ThreatPlates.IsTankedByOther
    }

    self.TankList = {}
    self.NumTanks = 0

    self:UpdatePlayerRole()
    if (CheckOtherTanks) then
        self:UpdateTankList()
    end

    self:SetScript("OnEvent", function(self, event)
        self:UpdatePlayerRole()
        if (CheckOtherTanks and event == "GROUP_ROSTER_UPDATE") then
            self:UpdateTankList()
        end
    end)
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
end

T["ThreatPlates"] = ThreatPlates


local function LoadThreatPlates(self, event, addon)
    if (event == "PLAYER_LOGIN") then
        if (C.NamePlates.Enable and C.ThreatPlates.Enable) then
            T["ThreatPlates"]:Enable()
        end
    end
end

T["Loading"]:HookScript("OnEvent", LoadThreatPlates)
