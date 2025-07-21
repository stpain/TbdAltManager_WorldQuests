

local addonName, TbdAltManagerWorldQuests = ...;

local playerUnitToken = "player"







local characterDefaults = {
    uid = "",
    level = 1,
}


--Main DataProvider for the module
local CharacterDataProvider = CreateFromMixins(DataProviderMixin)

function CharacterDataProvider:InsertCharacter(characterUID)

    local character = self:FindElementDataByPredicate(function(characterData)
        return (characterData.uid == characterUID)
    end)

    if not character then        
        local newCharacter = {}
        for k, v in pairs(characterDefaults) do
            newCharacter[k] = v
        end

        newCharacter.uid = characterUID

        self:Insert(newCharacter)
        TbdAltManagerTradeskills.CallbackRegistry:TriggerEvent("Character_OnAdded")
    end
end

function CharacterDataProvider:FindCharacterByUID(characterUID)
    return self:FindElementDataByPredicate(function(character)
        return (character.uid == characterUID)
    end)
end

function CharacterDataProvider:UpdateDefaultKeys()
    for _, character in self:EnumerateEntireRange() do
        for k, v in pairs(characterDefaults) do
            if character[k] == nil then
                character[k] = v;
            end
        end
    end
end



















local function CreateCharacterEntry()
    return {
        lastCompleted = 0,
        itemRewards = {},
        currencyRewards = {},
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

function TbdAltManagerWorldQuests.Api.InitializeQuest(mapID, questID, title, finishTime, link, level)
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
            TbdAltManager_WorldQuestTracking[mapID][questID].level = level
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

--600+

function TbdAltManagerWorldQuests.Api.ScrapMaps()
    for i = 600, 2500 do
        TbdAltManagerWorldQuests.Api.GetWorldQuestsForMapID(i)
    end
end


function TbdAltManagerWorldQuests.Api.GetWorldQuestsForMapID(mapID)
    local mapInfo = C_Map.GetMapInfo(mapID)
    if mapInfo.mapType == Enum.UIMapType.Zone then
        local maskPOIs = C_TaskQuest.GetQuestsOnMap(mapID)
        if (type(maskPOIs) == "table") and (next(maskPOIs) ~= nil) then
            for _, info in ipairs(maskPOIs) do
                if info.questID and C_QuestLog.IsWorldQuest(info.questID) then
                    local active = C_TaskQuest.IsActive(info.questID)
                    local questTitle, factionID, capped, displayAsObjective = C_TaskQuest.GetQuestInfoByQuestID(info.questID)
                    local secondsLeft = C_TaskQuest.GetQuestTimeLeftSeconds(info.questID)
                    print(string.format("%s %s %s %s", mapInfo.name, questTitle, tostring(active), date("%m-%d %H:%M", GetServerTime() + (secondsLeft or 0))))
                end
            end
        end
    end
end

function TbdAltManagerWorldQuests.Api.InitializeQuests()
    if TbdAltManager_WorldQuestTracking then
        for _, questIDs in pairs(TbdAltManager_WorldQuestTracking) do
            for questID, info in pairs(questIDs) do

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
    "QUEST_CURRENCY_LOOT_RECEIVED",
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

        if TbdAltManager_WorldQuestCharacters == nil then
            TbdAltManager_WorldQuestCharacters = {}
        end

        if TbdAltManager_WorldQuestConfig == nil then
            TbdAltManager_WorldQuestConfig = {
                CharacterMinLevel = 40,
            }
        end

    end
end

function WorldQuestsEventFrame:PLAYER_ENTERING_WORLD(...)
    local account = "Default"
    local realm = GetRealmName()
    local name = UnitName(playerUnitToken)

    self.characterUID = string.format("%s.%s.%s", account, realm, name)

    if TbdAltManager_WorldQuestCharacters[self.characterUID] == nil then
        TbdAltManager_WorldQuestCharacters[self.characterUID] = {}
    end
    TbdAltManager_WorldQuestCharacters[self.characterUID].level = UnitLevel(playerUnitToken)
    TbdAltManager_WorldQuestCharacters[self.characterUID].class = select(2, UnitClass(playerUnitToken))

    if ViragDevTool_AddData then
        ViragDevTool_AddData(TbdAltManager_WorldQuestTracking, "WorldQuests")
    end

    TbdAltManagerWorldQuests.Api.InitializeCharacter(self.characterUID)

    --C_TaskQuest.GetQuestsOnMap

    --TbdAltManagerWorldQuests.Api.ScrapMaps()
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
                        if type(timeRemaining) == "number" then
                            local now = GetServerTime()
                            local finishTime = now + timeRemaining

                            local link = GetQuestLink(questID)

                            --questTitle, factionID, capped, displayAsObjective = C_TaskQuest.GetQuestInfoByQuestID(questID)

                            TbdAltManagerWorldQuests.Api.InitializeQuest(mapID, questID, info.title, finishTime, link, info.difficultyLevel)

                            --C_QuestLog.GetQuestObjectives(questID)

                            TbdAltManagerWorldQuests.Api.SetCharacterQuestInfo(self.characterUID, questID, true, false, nil)

                            TbdAltManagerWorldQuests.Api.AddCharactersToQuest(questID)
                        end
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

function WorldQuestsEventFrame:QUEST_CURRENCY_LOOT_RECEIVED(...)
    local questID, currencyId, quantity = ...;
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then
        --print("got mapID")
        if TbdAltManager_WorldQuestTracking[mapID] and TbdAltManager_WorldQuestTracking[mapID][questID] and TbdAltManager_WorldQuestTracking[mapID][questID].characters[self.characterUID] then
            if not TbdAltManager_WorldQuestTracking[mapID][questID].characters[self.characterUID].currencyRewards then
                TbdAltManager_WorldQuestTracking[mapID][questID].characters[self.characterUID].currencyRewards = {}
            end
            table.insert(TbdAltManager_WorldQuestTracking[mapID][questID].characters[self.characterUID].currencyRewards, 1, {
                currencyId = currencyId,
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

function TbdAltManagerWorldQuestsListItemMixin:UpdateToggleState()
    if self.node:IsCollapsed() then
        self.ToggleButton:SetNormalAtlas("128-RedButton-Plus")
        self.ToggleButton:SetPushedAtlas("128-RedButton-Plus-Pressed")
    else
        self.ToggleButton:SetNormalAtlas("128-RedButton-Minus")
        self.ToggleButton:SetPushedAtlas("128-RedButton-Minus-Pressed")
    end
    if self.node:IsCollapsed() then
        self.SecondaryToggleButton:SetNormalAtlas("UI-QuestTrackerButton-Secondary-Expand")
        self.SecondaryToggleButton:SetPushedAtlas("UI-QuestTrackerButton-Secondary-Expand-Pressed")
    else
        self.SecondaryToggleButton:SetNormalAtlas("UI-QuestTrackerButton-Secondary-Collapse")
        self.SecondaryToggleButton:SetPushedAtlas("UI-QuestTrackerButton-Secondary-Collapse-Pressed")
    end
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

    self:UpdateToggleState()

    if binding.label then
        self.Label:SetText(binding.label)
    end

    if binding.mapID then
        self.Label:SetFontObject(GameFontNormalLarge)
        self.ToggleButton:Show()
        --self.BottomBorder:Show()
    else
        self.Label:SetFontObject(GameFontNormal)
    end

    if binding.isQuestHeader and binding.finishTime then
        self.FinishTime:SetText(string.format("%s %s", CreateAtlasMarkup("perks-clock"), date("%A - %d/%m %H:%M", binding.finishTime)))
        self.link = binding.link
        self.Background:Show()
        self.SecondaryToggleButton:Show()

        if GetServerTime() > binding.finishTime then
            self.Label:SetText(string.format("%s %s", CreateAtlasMarkup("Bags-padlock-authenticator", 32, 38), binding.label))
            self.Label:SetFontObject(GameFontNormalLeftRed)
            self.FinishTime:SetFontObject(GameFontNormalLeftRed)
        else
            self.Label:SetFontObject(GameFontNormal)
            self.FinishTime:SetFontObject(GameFontNormal)
        end
    end


    if binding.data then

        -- if binding.data.lastCompleted and (binding.data.lastCompleted ~= 0) then
        --     self.FinishTime:SetText(date("%A - %d/%m %H:%M", binding.data.lastCompleted))
        -- end

        self.Label:SetFontObject(GameFontWhite)

        local characterName = binding.label
        if TbdAltManager_WorldQuestCharacters[binding.label] then
            local rgb = RAID_CLASS_COLORS[TbdAltManager_WorldQuestCharacters[binding.label].class]
            if rgb then
                characterName = rgb:WrapTextInColorCode(characterName)
            end
        end


        if binding.data.itemRewards[1] then
            self.FinishTime:SetText(string.format("|cffffffff[x%d] %s", binding.data.itemRewards[1].quantity or "", binding.data.itemRewards[1].link or ""))
            self.link = binding.data.itemRewards[1].link
        end

        if binding.data.currencyRewards and binding.data.currencyRewards[1] then

            local currencyIsNewer = false;
            if binding.data.itemRewards[1] == nil then
                currencyIsNewer = true
            else
                if binding.data.itemRewards[1] and (binding.data.itemRewards[1].receivedTime < binding.data.currencyRewards[1].receivedTime) then
                    currencyIsNewer = true
                end
            end

            if currencyIsNewer == true then
                local currency = C_CurrencyInfo.GetCurrencyInfo(binding.data.currencyRewards[1].currencyId)
                self.FinishTime:SetText(string.format("|cffffffff[x%d] %s", binding.data.currencyRewards[1].quantity or "", currency.name or ""))
            end
        end


        if #binding.data.itemRewards > 1 then
            self.itemRewardsTooltipData = binding.data.itemRewards;
        end
       
        -- if binding.data.isActive then
        --     self.Label:SetFontObject(GameFontWhite)
        -- else
        --     self.Label:SetFontObject(GameFontDisable)
        -- end

        --if its complete show a tick
        if binding.data.isCompleted then
            self.Label:SetText(string.format("%s %s", CreateAtlasMarkup("common-icon-checkmark", 20, 20), characterName))
            self.Label:SetFontObject(GameFontDisable)
        else
            --if its not flagged as complete and its still active and before its finish time show a ?
            if GetServerTime() < binding.finishTime then
                self.Label:SetText(string.format("%s %s", CreateAtlasMarkup("UI-LFG-PendingMark-Raid", 20, 20), characterName))
            end
        end

        --self.Label:SetText(characterName)

    end

    self:SetScript("OnMouseDown", nil)
end

function TbdAltManagerWorldQuestsListItemMixin:ResetDataBinding()
    self.Label:SetText("")
    self.Label:SetFontObject(GameFontNormal)
    self.FinishTime:SetText("")
    self.link = nil
    self.Background:Hide()
    self.BottomBorder:Hide()
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

    self.MinLevelSlider:SetMinMaxValues(1, 80)
    self.MinLevelSlider.label:SetFontObject(GameFontNormal)
    self.MinLevelSlider.label:SetText("Min character level")

    self.MinLevelSlider:SetScript("OnMouseWheel", function(_, delta)
        self.MinLevelSlider:SetValue(self.MinLevelSlider:GetValue() + delta)
    end)
    self.MinLevelSlider:SetScript("OnValueChanged", function(slider)
        local val = math.floor(self.MinLevelSlider:GetValue())
        TbdAltManager_WorldQuestConfig.CharacterMinLevel = val
        slider.value:SetText(val)
        self:LoadQuests()
    end)
end

function TbdAltManagerWorldQuestsMixin:OnShow()
    self.MinLevelSlider:SetMinMaxValues(1, GetMaxLevelForLatestExpansion())
    self.MinLevelSlider:SetValue(TbdAltManager_WorldQuestConfig.CharacterMinLevel)
    self:LoadQuests()
end

--return true if a should be before b
local function SortFunc_Quests(a, b)
    if a:GetData() and b:GetData() then
        local now = GetServerTime()

        if (now > a:GetData().finishTime) then
            if (now < b:GetData().finishTime) then
                return false
            end
        end

        if (now > b:GetData().finishTime) then
            if (now < a:GetData().finishTime) then
                return true
            end
        end

        return (a:GetData().finishTime < b:GetData().finishTime)

        -- if (a:GetData().finishTime == b:GetData().finishTime) then
        --     if (now > a:GetData().finishTime) then
        --         if (now < b:GetData().finishTime) then
        --             return false
        --         else
        --             return true
        --         end
        --     end
        -- else
        --     return (a:GetData().finishTime < b:GetData().finishTime)
        -- end
    end
end

local function SortFunc_Characters(a, b)
    return a:GetData().label < b:GetData().label
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
            nodes[mapName]:SetSortComparator(SortFunc_Quests)
        end

        for questID, info in pairs(quests) do
            --print(info.title)
            
            local questNode = nodes[mapName]:Insert({
                label = info.title,
                finishTime = info.finishTime,
                isQuestHeader = true,
                link = info.link,
            })

            questNode:SetSortComparator(SortFunc_Characters)

            for uid, data in pairs(info.characters) do

                --print(uid)
                if TbdAltManager_WorldQuestCharacters and TbdAltManager_WorldQuestCharacters[uid] then
                    if TbdAltManager_WorldQuestCharacters[uid].level >= TbdAltManager_WorldQuestConfig.CharacterMinLevel then
                        questNode:Insert({
                            label = uid,
                            data = data,
                            finishTime = info.finishTime,
                        })
                    end
                else
                    questNode:Insert({
                        label = uid,
                        data = data,
                        finishTime = info.finishTime,
                    })
                end
            end

            questNode:Sort()

            if GetServerTime() > info.finishTime then
                questNode:ToggleCollapsed()
            end
        end

        nodes[mapName]:Sort()
    end

    self.QuestList.scrollView:SetDataProvider(DataProvider)
end