-- Copyright 2015, r. brian harrison.  all rights reserved.

local ADDON_NAME = ...
local HNA = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0", "AceTimer-3.0")
if not HNA then return end

local AchievementLocations = LibStub:GetLibrary("AchievementLocations-1.0")
assert(AchievementLocations, string.format("%s requires AchievementLocations-1.0", ADDON_NAME))

local InstanceLocations = LibStub:GetLibrary("InstanceLocations-1.0")
assert(InstanceLocations, string.format("%s requires InstanceLocations-1.0", ADDON_NAME))

local HandyNotes = LibStub("AceAddon-3.0"):GetAddon("HandyNotes", true)
assert(HandyNotes, string.format("%s requires HandyNotes", ADDON_NAME))

local QTip = LibStub("LibQTip-1.0")
assert(QTip, string.format("%s requires LibQTip-1.0", ADDON_NAME))


local ICON_PATH = "Interface/AchievementFrame/UI-Achievement-TinyShield"
local ICON_SCALE = 5
local ICON_ALPHA = 1.0
local NEAR = 0.03
local DEFAULT_X, DEFAULT_Y = 0.5, 0.5
local ZONE_X, ZONE_Y = 0.5, 0.5

local EMPTY = {}
local visible = {}
local tooltip


function HNA:GetAchievementCriteriaInfoByDescription(achievementID, description)
    for i = 1, GetAchievementNumCriteria(achievementID) do
        local retval = {GetAchievementCriteriaInfo(achievementID, i)}
        if description == retval[1] then
            return unpack(retval, 1, 10)
        end
    end
end


function HNA:HandyNotesCoordsNear(c, coord)
    --return c == coord
    -- within 3% of the map
    local dx = (c - coord) / 1e8
    local dy = (c % 1e4 - coord % 1e4) / 1e4
    return dx * dx + dy * dy < NEAR * NEAR
end


function HNA:OnEnter(mapFile, coord)
    tooltip = QTip:Acquire(ADDON_NAME, 2, "LEFT", "RIGHT")
    local firstRow = true
    local previousAchievementID
    for c, _, _, _, _, _, row in HNA:GetNodes(mapFile, nil, nil) do
        if HNA:HandyNotesCoordsNear(c, coord) and HNA:Valid(row) then
            local achievementID = row[1]
            local criterion = row.criterion

            local _, name, points, completed, _, _, _, description, _, _, _, _, _, _ = GetAchievementInfo(achievementID)
            
            if achievementID ~= previousAchievementID then
                if not firstRow then
                    tooltip:AddSeparator(2, 0, 0, 0, 0)
                    tooltip:AddSeparator(1, 1, 1, 1, 0.5)
                    tooltip:AddSeparator(2, 0, 0, 0, 0)
                end
                firstRow = false

                tooltip:SetHeaderFont(GameFontGreenLarge)
                tooltip:AddHeader(name)

                tooltip:SetFont(GameTooltipTextSmall)
                tooltip:AddLine(description)
                previousAchievementID = achievementID
            end

            if criterion then
                local criterionDescription, quantityString
                if type(criterion) == "number" then
                    criterionDescription, _, _, _, _, _, _, _, quantityString, _ = GetAchievementCriteriaInfoByID(achievementID, criterion)
                else
                    criterionDescription, _, _, _, _, _, _, _, quantityString, _ = HNA:GetAchievementCriteriaInfoByDescription(achievementID, criterion)
                end
                
                if quantityString == "0" then
                    quantityString = ""
                end

                if criterionDescription then
                    tooltip:AddSeparator(2, 0, 0, 0, 0)
                    tooltip:SetFont(GameTooltipTextSmall)
                    tooltip:AddLine(criterionDescription, quantityString)
                end
            end
        end
    end

    tooltip:SmartAnchorTo(self)
    tooltip:Show()
end


function HNA:OnLeave(mapFile, coord)
    QTip:Release(tooltip)
end


function HNA:OnClick(button, down, mapFile, coord)
    if not AchievementFrame then
        AchievementFrame_LoadUI()
    end
    -- XXX ...
    if achievementID then
        ShowUIPanel(AchievementFrame)
        AchievementFrame_SelectAchievement(achievementID)
    end
end


function HNA:OnInitialize()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end


local function notifyUpdate(event)
    -- print(string.format("%s:%s()", ADDON_NAME, event))
    HNA:UpdateVisible()
    HNA:SendMessage("HandyNotes_NotifyUpdate", ADDON_NAME)
end
    

function HNA:PLAYER_ENTERING_WORLD(event)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ACHIEVEMENT_EARNED")
    self:RegisterEvent("CRITERIA_COMPLETE")
    self:RegisterEvent("CRITERIA_EARNED")
    self:RegisterEvent("CRITERIA_UPDATE")
    self:RegisterEvent("QUEST_COMPLETE")
    -- XXX ...
    local options = {
        name = "Achievements",
        args = {
            completed = {
                name = "Show completed",
                desc = "Show icons for achievements you have completed.",
                tpye = "toggle",
                width = "full",
                arg = "completed",
                order = 1,
            },
            icon_scale = {
                type = "range",
                name = "Icon Scale",
                desc = "The size of the icons.",
                min = 0.3, max = 5, step = 0.1,
                arg = "icon_scale",
                order = 3,
            },
            icon_alpha = {
                type = "range",
                name = "Icon Alpha",
                desc = "The transparency of the icons.",
                min = 0, max = 1, step = 0.01,
                arg = "icon_alpha",
                order = 4,
            },
        },
    }
    -- XXX
    options = {}
    HandyNotes:RegisterPluginDB(ADDON_NAME, self, options)
    notifyUpdate(event)
end


HNA.ACHIEVEMENT_EARNED = notifyUpdate
HNA.CRITERIA_COMPLETE  = notifyUpdate
HNA.CRITERIA_EARNED    = notifyUpdate
HNA.CRITERIA_UPDATE    = notifyUpdate
HNA.QUEST_COMPLETE     = notifyUpdate


function HNA:UpdateVisible()
    for _, categoryID in ipairs(GetCategoryList()) do
        for i = 1, GetCategoryNumAchievements(categoryID) do
            local achievementID = GetAchievementInfo(categoryID, i)
            if achievementID then
                visible[achievementID] = true
            end
        end
    end
end


function HNA:Valid(row)
    local achievementID = row[1]
    if not visible[achievementID] then
        return false
    end
    local _, _, _, completed, _, _, _, _, _, _, _, _, earnedByMe, _ = GetAchievementInfo(achievementID)
    if not completed and row.criterion then
        if type(row.criterion) == "number" then
            _, _, completed = GetAchievementCriteriaInfoByID(achievementID, row.criterion)
        else
            _, _, completed = HNA:GetAchievementCriteriaInfoByDescription(achievementID, row.criterion)
        end
    end
    if not completed and row.quest then
        completed = IsQuestFlaggedCompleted(row.quest)
    end
    return not completed
end


function HNA:GetNodes(mapFile, minimap, dungeonLevel)
    local function validRows(mapFile, x, y)
        local rows = AchievementLocations:Get(mapFile)
        for _, row in ipairs(rows or EMPTY) do
            if self:Valid(row) then
                coroutine.yield(mapFile, x or row[2], y or row[3], row)
            end
        end

        local zones = HandyNotes:GetContinentZoneList(mapFile)
        for _, subMap in ipairs(zones or EMPTY) do
            local subMapFile = HandyNotes:GetMapIDtoMapFile(subMap)
            -- put zone on the world map, all on one pin
            validRows(subMapFile, x or ZONE_X, y or ZONE_Y)
        end

        local instances = InstanceLocations:GetBelow(mapFile)
        for _, subMapFile in ipairs(instances or EMPTY) do
            local _, instanceX, instanceY = unpack(InstanceLocations:GetLocation(subMapFile))
            validRows(subMapFile, x or instanceX, y or instanceY)
            -- print(string.format("recurse %s", subMapFile))
        end
    end

    local rowsCo = coroutine.create(validRows)
    return function(state, value)
        local status, mF, x, y, row = coroutine.resume(rowsCo, mapFile)
        if not status then
            print(string.format("|cffff0000%s Error:|r %s", ADDON_NAME, tostring(mF)))
            return nil
        end
        if not row then
            return nil
        end
        local coord =  (x or DEFAULT_X) * 1e8 + (y or DEFAULT_Y) * 1e4
        -- HandyNotes does iterators wrong: the first value should be a iterator variable (cursor), eliminating the need for a "value" closure or coroutine
        -- added row for tooltip embellishment
        return coord, mF, ICON_PATH, ICON_SCALE, ICON_ALPHA, nil, row
    end, nil
end
