

local addonName, TbdAltManagerWorldQuests = ...;

local playerUnitToken = "player"




local function CreateCharacterEntry()
    return {
        lastCompleted = 0,
        itemRewards = {},
        isActive = false,
        isCompleted = false,
    }
end












TbdAltManagerWorldQuests.Api = {}
function TbdAltManagerWorldQuests.Api.InitializeCharacter(characterUID)
    if TbdAltManager_WorldQuestTracking then
        for _, questIDs in pairs(TbdAltManager_WorldQuestTracking) do
            for questID, info in pairs(questIDs) do
                if not info.characters[characterUID] then
                    info.characters[characterUID] = CreateCharacterEntry()
                end
                local isActive = C_TaskQuest.IsActive(questID)
                info.characters[characterUID].isActive = isActive
                local completed = C_QuestLog.IsQuestFlaggedCompleted(questID)
                info.characters[characterUID].isCompleted = completed

                TbdAltManagerWorldQuests.Api.AddCharactersToQuest(questID)
            end
        end
    end
end

function TbdAltManagerWorldQuests.Api.InitializeQuest(mapID, questID, title, finishTime, link)
    if TbdAltManager_WorldQuestTracking then
        if not TbdAltManager_WorldQuestTracking[mapID] then
            TbdAltManager_WorldQuestTracking[mapID] = {}
        end
        if not TbdAltManager_WorldQuestTracking[mapID][questID] then
            TbdAltManager_WorldQuestTracking[mapID][questID] = {
                title = title,
                finishTime = finishTime,
                link = link,
                characters = {}
            }
        else
            TbdAltManager_WorldQuestTracking[mapID][questID].title = title
            TbdAltManager_WorldQuestTracking[mapID][questID].finishTime = finishTime
            TbdAltManager_WorldQuestTracking[mapID][questID].link = link
        end
    end
end

function TbdAltManagerWorldQuests.Api.SetCharacterQuestInfo(characterUID, questID, isActive, isCompleted, lastCompleted)
    if TbdAltManager_WorldQuestTracking then
        for _, questIDs in pairs(TbdAltManager_WorldQuestTracking) do
            for qid, info in pairs(questIDs) do
                if qid == questID then
                    if info.characters then
                        if not info.characters[characterUID] then
                            info.characters[characterUID] = CreateCharacterEntry()
                        end

                        if isActive ~= nil then
                            info.characters[characterUID].isActive = isActive
                        end
                        if isCompleted ~= nil then
                            info.characters[characterUID].isCompleted = isCompleted
                        end
                        if lastCompleted ~= nil then
                            info.characters[characterUID].lastCompleted = lastCompleted
                        end
                    end
                end
            end
        end
    end
end

--[[
    If the world quest finish time has elapsed, it longer matters if characters 
    show the quest as not completed (its no longer available, until it respawns)

    So, reset the .isCompleted values
]]
function TbdAltManagerWorldQuests.Api.ResetQuestsCompleted()

    local now = GetServerTime()

    if TbdAltManager_WorldQuestTracking then
        for _, questIDs in pairs(TbdAltManager_WorldQuestTracking) do
            for questID, info in pairs(questIDs) do

                if now > info.finishTime then
                    for uid, data in pairs(info.characters) do
                        data.isCompleted = false;
                    end
                end
            end
        end
    end
end

function TbdAltManagerWorldQuests.Api.GetAllCharacters()
    local ret = {}
    if TbdAltManager_WorldQuestTracking then
        for _, questIDs in pairs(TbdAltManager_WorldQuestTracking) do
            for questID, info in pairs(questIDs) do
                for uid, _ in pairs(info.characters) do
                    table.insert(ret, uid)
                end
            end
        end
    end
    return ret
end

function TbdAltManagerWorldQuests.Api.AddCharactersToQuest(questID)

    if not TbdAltManager_WorldQuestTracking then
        return
    end
    
    local characters = TbdAltManagerWorldQuests.Api.GetAllCharacters()

    if not questID then
        for _, questIDs in pairs(TbdAltManager_WorldQuestTracking) do
            for _, info in pairs(questIDs) do
                if info.characters then
                    for _, uid in ipairs(characters) do
                        if not info.characters[uid] then
                            info.characters[uid] = CreateCharacterEntry()
                        end
                    end
                end
            end
        end
    else
        for _, questIDs in pairs(TbdAltManager_WorldQuestTracking) do
            for qid, info in pairs(questIDs) do
                if qid == questID then
                    if info.characters then
                        for _, uid in ipairs(characters) do
                            if not info.characters[uid] then
                                info.characters[uid] = CreateCharacterEntry()
                            end
                        end
                    end
                end
            end
        end
    end
end




local EventsToRegister = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "QUEST_ACCEPTED",
    "QUEST_TURNED_IN",
    "QUEST_LOOT_RECEIVED",
}

local WorldQuestsEventFrame = CreateFrame("Frame")
for _, event in ipairs(EventsToRegister) do
    WorldQuestsEventFrame:RegisterEvent(event)
end

WorldQuestsEventFrame:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

function WorldQuestsEventFrame:ADDON_LOADED(...)
    if (... == addonName) then
        
        if TbdAltManager_WorldQuestTracking == nil then
            TbdAltManager_WorldQuestTracking = {}
        end
    end
end

function WorldQuestsEventFrame:PLAYER_ENTERING_WORLD(...)
    local account = "Default"
    local realm = GetRealmName()
    local name = UnitName(playerUnitToken)

    self.characterUID = string.format("%s.%s.%s", account, realm, name)

    if ViragDevTool_AddData then
        ViragDevTool_AddData(TbdAltManager_WorldQuestTracking, "WorldQuests")
    end

    TbdAltManagerWorldQuests.Api.InitializeCharacter(self.characterUID)

    --C_TaskQuest.GetQuestsOnMap
end


function WorldQuestsEventFrame:QUEST_ACCEPTED(...)
    local questID = ...;
    if C_QuestLog.IsWorldQuest(questID) then

        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then

            C_Timer.After(0.1, function()
                local index = C_QuestLog.GetLogIndexForQuestID(questID)
                if index then
                    local info = C_QuestLog.GetInfo(index)
                    --print(info.title, info.frequency)
                    if info then

                        local timeRemaining = C_TaskQuest.GetQuestTimeLeftSeconds(questID)
                        local now = GetServerTime()
                        local finishTime = now + timeRemaining

                        local link = GetQuestLink(questID)

                        --questTitle, factionID, capped, displayAsObjective = C_TaskQuest.GetQuestInfoByQuestID(questID)

                        TbdAltManagerWorldQuests.Api.InitializeQuest(mapID, questID, info.title, finishTime, link)

                        --C_QuestLog.GetQuestObjectives(questID)

                        TbdAltManagerWorldQuests.Api.SetCharacterQuestInfo(self.characterUID, questID, true, false, nil)

                        TbdAltManagerWorldQuests.Api.AddCharactersToQuest(questID)

                    end
                end
            end)
        end
    end
end

function WorldQuestsEventFrame:QUEST_TURNED_IN(...)
    local questID, xp, copper = ...;
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then
        if TbdAltManager_WorldQuestTracking[mapID] and TbdAltManager_WorldQuestTracking[mapID][questID] and TbdAltManager_WorldQuestTracking[mapID][questID].characters[self.characterUID] then
            TbdAltManager_WorldQuestTracking[mapID][questID].characters[self.characterUID].lastCompleted = GetServerTime()
            TbdAltManager_WorldQuestTracking[mapID][questID].characters[self.characterUID].isCompleted = true
            TbdAltManager_WorldQuestTracking[mapID][questID].characters[self.characterUID].isActive = false
        end
    end
end


function WorldQuestsEventFrame:QUEST_LOOT_RECEIVED(...)
    local questID, link, quantity = ...;
    --print(questID, link)
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then
        --print("got mapID")
        if TbdAltManager_WorldQuestTracking[mapID] and TbdAltManager_WorldQuestTracking[mapID][questID] and TbdAltManager_WorldQuestTracking[mapID][questID].characters[self.characterUID] then
            if not TbdAltManager_WorldQuestTracking[mapID][questID].characters[self.characterUID].itemRewards then
                TbdAltManager_WorldQuestTracking[mapID][questID].characters[self.characterUID].itemRewards = {}
            end
            table.insert(TbdAltManager_WorldQuestTracking[mapID][questID].characters[self.characterUID].itemRewards, 1, {
                link = link,
                quantity = quantity,
                receivedTime = GetServerTime(),
            })
        end
    end
end










TbdAltManagerWorldQuestsListItemMixin = {}
function TbdAltManagerWorldQuestsListItemMixin:OnLoad()
    self.ToggleButton:SetScript("OnClick", function()
        self.node:ToggleCollapsed()
        if self.node:IsCollapsed() then
            self.ToggleButton:SetNormalAtlas("128-RedButton-Plus")
            self.ToggleButton:SetPushedAtlas("128-RedButton-Plus-Pressed")
        else
            self.ToggleButton:SetNormalAtlas("128-RedButton-Minus")
            self.ToggleButton:SetPushedAtlas("128-RedButton-Minus-Pressed")
        end
    end)
    self.SecondaryToggleButton:SetScript("OnClick", function()
        self.node:ToggleCollapsed()
        if self.node:IsCollapsed() then
            self.SecondaryToggleButton:SetNormalAtlas("UI-QuestTrackerButton-Secondary-Expand")
            self.SecondaryToggleButton:SetPushedAtlas("UI-QuestTrackerButton-Secondary-Expand-Pressed")
        else
            self.SecondaryToggleButton:SetNormalAtlas("UI-QuestTrackerButton-Secondary-Collapse")
            self.SecondaryToggleButton:SetPushedAtlas("UI-QuestTrackerButton-Secondary-Collapse-Pressed")
        end
    end)
end

function TbdAltManagerWorldQuestsListItemMixin:OnEnter()
    if self.link then
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()

    elseif self.itemRewardsTooltipData then
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        for i = 2, #self.itemRewardsTooltipData do
            GameTooltip:AddDoubleLine(string.format("%d %s", self.itemRewardsTooltipData[i].quantity, self.itemRewardsTooltipData[i].link), date("%Y-%m-%d", self.itemRewardsTooltipData[i].receivedTime))
        end
        GameTooltip:Show()
    end
end
function TbdAltManagerWorldQuestsListItemMixin:OnLeave()
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
end

function TbdAltManagerWorldQuestsListItemMixin:SetDataBinding(binding, _, node)

    self.node = node

    if binding.label then
        self.Label:SetText(binding.label)
    end

    if binding.mapID then
        self.Label:SetFontObject(GameFontNormalLarge)
        self.ToggleButton:Show()
    else
        self.Label:SetFontObject(GameFontNormal)
    end

    if binding.isQuestHeader and binding.finishTime then
        self.FinishTime:SetText(string.format("%s %s", CreateAtlasMarkup("perks-clock"), date("%A - %d/%m %H:%M", binding.finishTime)))
        self.link = binding.link
        self.Background:Show()
        self.SecondaryToggleButton:Show()
    end


    if binding.data then

        -- if binding.data.lastCompleted and (binding.data.lastCompleted ~= 0) then
        --     self.FinishTime:SetText(date("%A - %d/%m %H:%M", binding.data.lastCompleted))
        -- end


        if binding.data.itemRewards[1] then
            self.FinishTime:SetText(string.format("|cffffffff[x%d] %s", binding.data.itemRewards[1].quantity or "", binding.data.itemRewards[1].link or ""))
            self.link = binding.data.itemRewards[1].link
        end

        if #binding.data.itemRewards > 1 then
            self.itemRewardsTooltipData = binding.data.itemRewards;
        end

        if binding.data.isCompleted then
            self.Label:SetText(string.format("%s %s", CreateAtlasMarkup("common-icon-checkmark", 16, 16), binding.label))
        else

        end
        
        if binding.data.isActive then
            self.Label:SetFontObject(GameFontWhite)
        else
            self.Label:SetFontObject(GameFontDisable)
        end

    end

    self:SetScript("OnMouseDown", nil)
end

function TbdAltManagerWorldQuestsListItemMixin:ResetDataBinding()
    self.Label:SetText("")
    self.Label:SetFontObject(GameFontNormal)
    self.FinishTime:SetText("")
    self.link = nil
    self.Background:Hide()
    self.ToggleButton:Hide()
    self.SecondaryToggleButton:Hide()
    self.node = nil
    self.itemRewardsTooltipData = nil
end


















TbdAltManagerWorldQuestsMixin = {
    name = "WorldQuests",
    menuEntry = {
        height = 40,
        template = "TbdAltManagerSideBarListviewItemTemplate",
        initializer = function(frame)
            frame.Label:SetText("World Quests")
            frame.Icon:SetAtlas("worldquest-Capstone-questmarker-epic-Toast")
            frame:SetScript("OnMouseUp", function()
                TbdAltsManager.Api.SelectModule("WorldQuests")
            end)
            --MenuEntryToggleButton = frame.ToggleButton
            TbdAltsManager.Api.SetupSideMenuItem(frame, false, false)
        end,
    }
}
function TbdAltManagerWorldQuestsMixin:OnLoad()
    TbdAltsManager.Api.RegisterModule(self)
end

function TbdAltManagerWorldQuestsMixin:OnShow()
    self:LoadQuests()
end

function TbdAltManagerWorldQuestsMixin:LoadQuests()

    local nodes = {}
    local DataProvider = CreateTreeDataProvider()

    if next(TbdAltManager_WorldQuestTracking) == nil then
        return
    end

    for mapID, quests in pairs(TbdAltManager_WorldQuestTracking) do

        local mapName = C_Map.GetMapInfo(mapID).name

        --print(mapName)

        if not nodes[mapName] then
            nodes[mapName] = DataProvider:Insert({
                label = mapName,
                mapID = mapID,
            })
        end

        for questID, info in pairs(quests) do
            --print(info.title)
            
            local questNode = nodes[mapName]:Insert({
                label = info.title,
                finishTime = info.finishTime,
                isQuestHeader = true,
                link = info.link,
            })

            for uid, data in pairs(info.characters) do

                --print(uid)
                
                questNode:Insert({
                    label = uid,
                    data = data,
                    finishTime = info.finishTime,
                })
            end
        end
    end

    self.QuestList.scrollView:SetDataProvider(DataProvider)
end