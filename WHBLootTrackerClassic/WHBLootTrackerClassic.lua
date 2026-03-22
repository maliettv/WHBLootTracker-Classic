-- Initialize saved variables & Version
WHB_CURRENT_VERSION = "1.6.2"
WHBLootData = WHBLootData or {}
WHBSettings = WHBSettings or { 
    minQuality = 3, 
    ignoredZones = {},
    announcePlayer = false,
    announcePlayerName = "Realpower", 
    allowedRanks = { [0] = true },
    activeGroup = "Group 1"
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Raid Settings Events
frame:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")

-- Trade Events for Auto-Reassignment
frame:RegisterEvent("TRADE_SHOW")
frame:RegisterEvent("TRADE_CLOSED")
frame:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED")
frame:RegisterEvent("UI_INFO_MESSAGE")

-- Register our secret Addon channel prefix for Guild Syncing
C_ChatInfo.RegisterAddonMessagePrefix("WHBLoot")

-- Tables & Flags for sync management
local WHBSyncAcks = nil
local WHBReceivingSyncFrom = nil
local hasNotifiedUpdate = false
local hasBroadcastVersion = false

-- PUG Detection Variables
local WHB_InstanceTrackingApproved = nil
local WHB_PendingLootToTrack = {}

-- Trade Tracking Variables
local WHB_PendingTradeTarget = nil
local WHB_PendingTradeItems = {}

-- Safe helper function to get rank and avoid nil errors if not in a guild
local function GetSafeRank()
    if not IsInGuild() then return 99 end
    local _, _, rank = GetGuildInfo("player")
    return rank or 99
end

-- SECURITY HELPER: Check if a remote sender is actually an authorized officer
local function IsSenderAuthorized(senderName)
    if not IsInGuild() then return false end
    for i = 1, GetNumGuildMembers() do
        local name, _, rankIndex = GetGuildRosterInfo(i)
        if name then
            local cleanName = name:match("([^%-]+)") or name
            if cleanName == senderName then
                return WHBSettings.allowedRanks and WHBSettings.allowedRanks[rankIndex]
            end
        end
    end
    return false
end

-- Helper to compare semantic versions (e.g. 1.6.2 vs 1.6.1)
local function IsNewerVersion(remoteVer)
    local v1, v2, v3 = strsplit(".", WHB_CURRENT_VERSION)
    local r1, r2, r3 = strsplit(".", remoteVer)
    v1, v2, v3 = tonumber(v1) or 0, tonumber(v2) or 0, tonumber(v3) or 0
    r1, r2, r3 = tonumber(r1) or 0, tonumber(r2) or 0, tonumber(r3) or 0
    
    if r1 > v1 then return true end
    if r1 == v1 and r2 > v2 then return true end
    if r1 == v1 and r2 == v2 and r3 > v3 then return true end
    return false
end

-- Roster Scan Helper
local function CheckInstanceTrackingPrompt(zoneName)
    if WHB_InstanceTrackingApproved ~= nil then return end

    local _, _, _, _, maxPlayers = GetInstanceInfo()
    if not maxPlayers or maxPlayers == 0 then
        if zoneName == "Karazhan" or zoneName == "Zul'Aman" then maxPlayers = 10 else maxPlayers = 25 end
    end

    local guildCount = 0
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if UnitIsInMyGuild("raid"..i) then guildCount = guildCount + 1 end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() do
            if UnitIsInMyGuild("party"..i) then guildCount = guildCount + 1 end
        end
        if UnitIsInMyGuild("player") then guildCount = guildCount + 1 end
    end

    -- Trigger Thresholds
    if (maxPlayers <= 10 and guildCount <= 9) or (maxPlayers > 10 and guildCount <= 18) then
        WHB_InstanceTrackingApproved = "PENDING"
        StaticPopup_Show("WHB_CONFIRM_TRACKING", tostring(maxPlayers), tostring(guildCount))
    else
        WHB_InstanceTrackingApproved = true
    end
end

----------------------------------------
-- POPUP DIALOGS
----------------------------------------
StaticPopupDialogs["WHB_SYNC_REQUEST"] = {
    text = "|cFF00FF00[WHB Loot Tracker]|r\n%s is requesting missing data.\nPush your database to them directly?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self)
        local requester = self.data
        if not requester then return end
        WHBSyncAcks = {}
        if WHBPushSyncBtn then WHBPushSyncBtn:Disable(); WHBPushSyncBtn:SetText("Syncing...") end
        WHBSyncIndex = 1
        WHBSyncTarget = requester
        WHBSendNextSync()
    end,
    timeout = 20,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["WHB_CLEAR_DATA"] = {
    text = "|cFFFF0000WARNING:|r\nAre you sure you want to completely wipe the WHB Loot Tracker database? This cannot be undone.",
    button1 = "Yes, Clear Data",
    button2 = "Cancel",
    OnAccept = function()
        WHBLootData = {}
        currentSelectedZone = "All Zones"
        currentSelectedGroup = "All Groups"
        currentSelectedDate = "All Dates"
        if WHBSearchBox then WHBSearchBox:SetText("") end
        if UpdateViewer then UpdateViewer() end
        print("|cFF00FF00[WHB Loot Tracker]|r All data cleared.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["WHB_CONFIRM_TRACKING"] = {
    text = "|cFF00FF00[WHB Loot Tracker]|r\nYou are in a %s-man raid with only %s guild members.\nDo you want to track loot for this run?",
    button1 = "Yes, Track It",
    button2 = "No, Ignore",
    OnAccept = function()
        WHB_InstanceTrackingApproved = true
        for _, entry in ipairs(WHB_PendingLootToTrack) do
            table.insert(WHBLootData, entry)
            if IsInGuild() then
                local msg = entry.time .. "~" .. entry.dateOnly .. "~" .. entry.player .. "~" .. entry.item .. "~" .. entry.zone .. "~" .. entry.group
                C_ChatInfo.SendAddonMessage("WHBLoot", msg, "GUILD")
            end
        end
        WHB_PendingLootToTrack = {}
        if WHBMainWindow and WHBMainWindow:IsShown() and UpdateViewer then UpdateViewer() end
        print("|cFF00FF00[WHB Loot Tracker]|r Loot tracking ENABLED for this raid session.")
    end,
    OnCancel = function()
        WHB_InstanceTrackingApproved = false
        WHB_PendingLootToTrack = {}
        print("|cFFFF0000[WHB Loot Tracker]|r Loot tracking DISABLED for this raid session.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["WHB_DISCORD_POPUP"] = {
    text = "Join the Waffle House Brawlers Discord!\nPress Ctrl+C to copy the link below.",
    button1 = "Close",
    hasEditBox = true,
    OnShow = function(self)
        if self.EditBox then
            self.EditBox:SetText("https://discord.gg/whbguild")
            self.EditBox:HighlightText()
            self.EditBox:SetFocus()
        end
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

----------------------------------------
-- EVENT HANDLER (Tracking, Syncing & Trades)
----------------------------------------
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "WHBLootTrackerClassic" then
            WHBLootData = WHBLootData or {}
            WHBSettings = WHBSettings or { minQuality = 3, ignoredZones = {}, announcePlayer = false, announcePlayerName = "Realpower", allowedRanks = { [0] = true }, activeGroup = "Group 1" }
            WHBSettings.ignoredZones = WHBSettings.ignoredZones or {}
            WHBSettings.allowedRanks = WHBSettings.allowedRanks or { [0] = true }
            if not WHBSettings.activeGroup then WHBSettings.activeGroup = "Group 1" end
            if WHBSettings.announcePlayer == nil then WHBSettings.announcePlayer = false end
            if WHBSettings.announcePlayerName == nil then WHBSettings.announcePlayerName = "Realpower" end
            
            print("|cFF00FF00[WHB Loot Tracker v" .. WHB_CURRENT_VERSION .. "]|r loaded! Type /whb or /whbloot to open.")
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        WHB_InstanceTrackingApproved = nil
        WHB_PendingLootToTrack = {}

        if IsInGuild() and not hasBroadcastVersion then
            C_Timer.After(5, function() 
                C_ChatInfo.SendAddonMessage("WHBLoot", "VER_CHECK~" .. WHB_CURRENT_VERSION, "GUILD") 
            end)
            hasBroadcastVersion = true
        end
        
    ----------------------------------------
    -- MASTER LOOTER CHECK (SECURED WITH DELAY)
    ----------------------------------------
    elseif event == "PARTY_LOOT_METHOD_CHANGED" then
        C_Timer.After(0.5, function() 
            if IsInRaid() then
                local lootMethod = _G.GetLootMethod and _G.GetLootMethod() or "n/a"
                if lootMethod == "master" then
                    local zoneName = GetRealZoneText()
                    if not WHBSettings.ignoredZones[zoneName] then
                        CheckInstanceTrackingPrompt(zoneName)
                    end
                end
            end
        end)

    ----------------------------------------
    -- TRADE EVENT LOGIC
    ----------------------------------------
    elseif event == "TRADE_SHOW" then
        WHB_PendingTradeTarget = UnitName("npc")
        WHB_PendingTradeItems = {}

    elseif event == "TRADE_PLAYER_ITEM_CHANGED" then
        WHB_PendingTradeItems = {}
        for i = 1, 6 do
            local link = GetTradePlayerItemLink(i)
            if link then table.insert(WHB_PendingTradeItems, link) end
        end

    elseif event == "UI_INFO_MESSAGE" then
        local errorType, msg = ...
        if msg == ERR_TRADE_COMPLETE then
            if WHB_PendingTradeTarget and #WHB_PendingTradeItems > 0 then
                local myName = UnitName("player") or "Unknown"
                
                if IsSenderAuthorized(myName) then
                    for _, tradedLink in ipairs(WHB_PendingTradeItems) do
                        local tName = GetItemInfo(tradedLink)
                        if tName then
                            for i = #WHBLootData, 1, -1 do
                                local entry = WHBLootData[i]
                                local eName = GetItemInfo(entry.item)
                                
                                if entry.player == myName and eName == tName then
                                    entry.player = WHB_PendingTradeTarget
                                    if IsInGuild() then
                                        local modMsg = "MOD~" .. entry.time .. "~" .. myName .. "~" .. entry.item .. "~" .. WHB_PendingTradeTarget
                                        C_ChatInfo.SendAddonMessage("WHBLoot", modMsg, "GUILD")
                                    end
                                    print("|cFF00FF00[WHB Loot Tracker]|r Auto-reassigned " .. entry.item .. " to " .. WHB_PendingTradeTarget .. ".")
                                    if WHBMainWindow and WHBMainWindow:IsShown() and UpdateViewer then UpdateViewer() end
                                    break 
                                end
                            end
                        end
                    end
                end
            end
            WHB_PendingTradeTarget = nil
            WHB_PendingTradeItems = {}
        end

    elseif event == "TRADE_CLOSED" then
        C_Timer.After(1.0, function()
            WHB_PendingTradeTarget = nil
            WHB_PendingTradeItems = {}
        end)

    ----------------------------------------
    -- STANDARD LOOT & SYNC EVENTS
    ----------------------------------------
    elseif event == "CHAT_MSG_LOOT" then
        if IsInRaid() then
            local zoneName = GetRealZoneText()
            if WHBSettings.ignoredZones[zoneName] then return end 
            
            local message, sender = ...
            local itemLink = message:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
            local playerName = sender:match("([^%-]+)") or sender
            
            if itemLink then
                local itemName, _, itemQuality = GetItemInfo(itemLink)
                if not itemQuality or itemQuality >= WHBSettings.minQuality then
                    
                    if WHB_InstanceTrackingApproved == false then return end 
                    
                    local timestamp = date("%Y-%m-%d %H:%M:%S")
                    local dateOnlyStr = date("%Y-%m-%d")
                    
                    local rGroup = "Main Raid"
                    if zoneName == "Karazhan" or zoneName == "Zul'Aman" then
                        rGroup = WHBSettings.activeGroup
                    end

                    local lootEntry = { time = timestamp, dateOnly = dateOnlyStr, player = playerName, item = itemLink, zone = zoneName, group = rGroup }

                    if WHB_InstanceTrackingApproved == nil then
                        CheckInstanceTrackingPrompt(zoneName)
                        
                        if WHB_InstanceTrackingApproved == "PENDING" then
                            table.insert(WHB_PendingLootToTrack, lootEntry)
                            return
                        end
                        
                    elseif WHB_InstanceTrackingApproved == "PENDING" then
                        table.insert(WHB_PendingLootToTrack, lootEntry)
                        return
                    end

                    if WHB_InstanceTrackingApproved == true then
                        table.insert(WHBLootData, lootEntry)
                        if IsInGuild() then
                            local msg = timestamp .. "~" .. dateOnlyStr .. "~" .. playerName .. "~" .. itemLink .. "~" .. zoneName .. "~" .. rGroup
                            C_ChatInfo.SendAddonMessage("WHBLoot", msg, "GUILD")
                        end
                        if WHBMainWindow and WHBMainWindow:IsShown() and UpdateViewer then UpdateViewer() end
                    end
                end
            end
        end
        
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix == "WHBLoot" and sender ~= UnitName("player") then
            local cleanSender = sender:match("([^%-]+)") or sender
            
            if text:match("^VER_CHECK~") then
                local remoteVer = text:match("^VER_CHECK~(.+)")
                if remoteVer and not hasNotifiedUpdate and IsNewerVersion(remoteVer) then
                    print("|cFFFF0000[WHB Loot Tracker]|r A new version (v" .. remoteVer .. ") is available! Please download the latest version from CurseForge.")
                    hasNotifiedUpdate = true
                end
                return
            end
            
            if text:match("^PERM_SYNC:") then
                if not IsSenderAuthorized(cleanSender) then return end
                local permData = text:gsub("PERM_SYNC:", "")
                WHBSettings.allowedRanks = {}
                for rankIdx in permData:gmatch("([^,]+)") do
                    WHBSettings.allowedRanks[tonumber(rankIdx)] = true
                end
                return
            end

            if text == "REQ_SYNC" then
                local playerRank = GetSafeRank()
                if WHBSettings.allowedRanks and WHBSettings.allowedRanks[playerRank] then
                    StaticPopup_Show("WHB_SYNC_REQUEST", cleanSender, nil, sender)
                end
                return
            end

            if text == "SYNC_END" then
                print("|cFF00FF00[WHB Loot Tracker]|r Sync from " .. cleanSender .. " complete!")
                WHBReceivingSyncFrom = nil
                C_ChatInfo.SendAddonMessage("WHBLoot", "SYNC_ACK", "WHISPER", sender)
                return
            elseif text == "SYNC_ACK" then
                if WHBSyncAcks then WHBSyncAcks[cleanSender] = true end
                return
            end

            if text:match("^DEL~") then
                if not IsSenderAuthorized(cleanSender) then return end
                local delTime, delPlayer, delItem = strsplit("~", text:gsub("^DEL~", ""))
                if delTime and delItem then
                    for i = #WHBLootData, 1, -1 do
                        local entry = WHBLootData[i]
                        if entry.time == delTime and entry.player == delPlayer and entry.item == delItem then
                            table.remove(WHBLootData, i)
                            if WHBMainWindow and WHBMainWindow:IsShown() and UpdateViewer then UpdateViewer() end
                            break
                        end
                    end
                end
                return
            end
            
            if text:match("^MOD~") then
                if not IsSenderAuthorized(cleanSender) then return end
                local modTime, modOldPlayer, modItem, modNewPlayer = strsplit("~", text:gsub("^MOD~", ""))
                if modTime and modNewPlayer then
                    for i = #WHBLootData, 1, -1 do
                        local entry = WHBLootData[i]
                        if entry.time == modTime and entry.player == modOldPlayer and entry.item == modItem then
                            entry.player = modNewPlayer
                            if WHBMainWindow and WHBMainWindow:IsShown() and UpdateViewer then UpdateViewer() end
                            break
                        end
                    end
                end
                return
            end

            local tTime, tDate, tPlayer, tItem, tZone, tGroup = strsplit("~", text)
            if tTime and tItem then
                if not WHBReceivingSyncFrom then
                    WHBReceivingSyncFrom = cleanSender
                    if channel == "WHISPER" then
                        print("|cFF00FF00[WHB Loot Tracker]|r Receiving targeted data sync from " .. cleanSender .. "...")
                    else
                        print("|cFF00FF00[WHB Loot Tracker]|r Receiving full database sync from " .. cleanSender .. "...")
                    end
                end
                local isDuplicate = false
                for _, entry in ipairs(WHBLootData) do
                    if entry.time == tTime and entry.player == tPlayer and entry.item == tItem then isDuplicate = true; break end
                end
                if not isDuplicate then
                    table.insert(WHBLootData, { 
                        time = tTime, 
                        dateOnly = tDate, 
                        player = tPlayer, 
                        item = tItem, 
                        zone = tZone or "Unknown",
                        group = tGroup or "Main Raid"
                    })
                    if WHBMainWindow and WHBMainWindow:IsShown() and UpdateViewer then UpdateViewer() end
                end
            end
        end
        
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if WHBSettings.announcePlayer and IsInGuild() and WHBSettings.announcePlayerName and WHBSettings.announcePlayerName ~= "" then
            local _, subevent, _, _, _, _, _, _, destName = CombatLogGetCurrentEventInfo()
            if subevent == "UNIT_DIED" and destName then
                local cleanDestName = string.match(destName, "([^%-]+)") or destName
                if string.lower(cleanDestName) == string.lower(WHBSettings.announcePlayerName) then
                    SendChatMessage(WHBSettings.announcePlayerName .. " is dead again.", "GUILD")
                end
            end
        end
    end
end)

----------------------------------------
-- UI FRAMES (VIEWER, OPTIONS, ETC)
----------------------------------------
local currentSelectedZone = "All Zones"
local currentSelectedGroup = "All Groups"
local currentSelectedDate = "All Dates"

local mainWindow = CreateFrame("Frame", "WHBMainWindow", UIParent, "BasicFrameTemplateWithInset")
mainWindow:SetSize(600, 520) 
mainWindow:SetPoint("CENTER")
mainWindow:SetMovable(true); mainWindow:EnableMouse(true); mainWindow:RegisterForDrag("LeftButton")
mainWindow:SetScript("OnDragStart", mainWindow.StartMoving); mainWindow:SetScript("OnDragStop", mainWindow.StopMovingOrSizing)
mainWindow:Hide()

mainWindow:SetResizable(true)
if mainWindow.SetResizeBounds then mainWindow:SetResizeBounds(500, 520) else mainWindow:SetMinResize(500, 520) end

local resizeGrip = CreateFrame("Button", nil, mainWindow)
resizeGrip:SetPoint("BOTTOMRIGHT", -5, 5); resizeGrip:SetSize(16, 16)
resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeGrip:SetScript("OnMouseDown", function() mainWindow:StartSizing("BOTTOMRIGHT") end)
resizeGrip:SetScript("OnMouseUp", function() mainWindow:StopMovingOrSizing() end)

mainWindow.title = mainWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mainWindow.title:SetPoint("CENTER", mainWindow.TitleBg, "CENTER", 0, 0)
mainWindow.title:SetText("WHB Loot Tracker - Viewer v" .. WHB_CURRENT_VERSION)

local zoneDropdown = CreateFrame("Frame", "WHBZoneDropdown", mainWindow, "UIDropDownMenuTemplate")
zoneDropdown:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 0, -30)

local groupDropdown = CreateFrame("Frame", "WHBGroupDropdown", mainWindow, "UIDropDownMenuTemplate")
groupDropdown:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 180, -30)

local dateDropdown = CreateFrame("Frame", "WHBDateDropdown", mainWindow, "UIDropDownMenuTemplate")
dateDropdown:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 360, -30)

local searchLabel = mainWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
searchLabel:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 20, -65)
searchLabel:SetText("Search Player:")

local searchBox = CreateFrame("EditBox", "WHBSearchBox", mainWindow, "InputBoxTemplate")
searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
searchBox:SetSize(150, 20)
searchBox:SetAutoFocus(false)
searchBox:SetScript("OnTextChanged", function(self)
    if UpdateViewer then UpdateViewer() end
end)
searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

local viewerScroll = CreateFrame("ScrollFrame", "WHBViewerScroll", mainWindow, "UIPanelScrollFrameTemplate")
viewerScroll:SetPoint("TOPLEFT", 10, -95); viewerScroll:SetPoint("BOTTOMRIGHT", -30, 40)

local messageFrame = CreateFrame("ScrollingMessageFrame", nil, viewerScroll)
messageFrame:SetSize(560, 390); messageFrame:SetFontObject(ChatFontNormal); messageFrame:SetJustifyH("LEFT")
messageFrame:SetMaxLines(1000); messageFrame:SetFading(false); messageFrame:SetInsertMode("BOTTOM")
viewerScroll:SetScrollChild(messageFrame)

messageFrame:SetHyperlinksEnabled(true)

local exportEditBox = CreateFrame("EditBox", nil, viewerScroll)
exportEditBox:SetMultiLine(true); exportEditBox:SetFontObject(ChatFontNormal); exportEditBox:SetWidth(560); exportEditBox:Hide()

mainWindow:SetScript("OnSizeChanged", function(self, width, height)
    local newWidth = width - 40; local newHeight = height - 160 
    if newWidth > 0 and newHeight > 0 then messageFrame:SetSize(newWidth, newHeight); exportEditBox:SetWidth(newWidth) end
end)

----------------------------------------
-- RIGHT-CLICK CONTEXT MENU & REASSIGN
----------------------------------------
WHBContextIndex = nil

local WHBReassignFrame = CreateFrame("Frame", "WHBReassignFrame", UIParent, "BasicFrameTemplateWithInset")
WHBReassignFrame:SetSize(250, 110); WHBReassignFrame:SetPoint("CENTER"); WHBReassignFrame:SetFrameStrata("DIALOG"); WHBReassignFrame:Hide()

WHBReassignFrame.title = WHBReassignFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
WHBReassignFrame.title:SetPoint("CENTER", WHBReassignFrame.TitleBg, "CENTER", 0, 0)
WHBReassignFrame.title:SetText("Reassign Loot")

local reassignLabel = WHBReassignFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
reassignLabel:SetPoint("TOP", 0, -35); reassignLabel:SetText("Enter new player name:")

local reassignEditBox = CreateFrame("EditBox", nil, WHBReassignFrame, "InputBoxTemplate")
reassignEditBox:SetPoint("TOP", 0, -55); reassignEditBox:SetSize(150, 20); reassignEditBox:SetAutoFocus(true)

local reassignBtn = CreateFrame("Button", nil, WHBReassignFrame, "UIPanelButtonTemplate")
reassignBtn:SetPoint("BOTTOMLEFT", 15, 10); reassignBtn:SetSize(100, 25); reassignBtn:SetText("Assign")

local reassignCancelBtn = CreateFrame("Button", nil, WHBReassignFrame, "UIPanelButtonTemplate")
reassignCancelBtn:SetPoint("BOTTOMRIGHT", -15, 10); reassignCancelBtn:SetSize(100, 25); reassignCancelBtn:SetText("Cancel")

local function PerformReassign(index, newName)
    if not index or not newName or newName == "" then return end
    local entry = WHBLootData[index]; if not entry then return end
    if IsInGuild() then
        local msg = "MOD~" .. entry.time .. "~" .. entry.player .. "~" .. entry.item .. "~" .. newName
        C_ChatInfo.SendAddonMessage("WHBLoot", msg, "GUILD")
    end
    entry.player = newName; if UpdateViewer then UpdateViewer() end
    print("|cFF00FF00[WHB Loot Tracker]|r Loot reassigned to " .. newName .. ".")
    WHBReassignFrame:Hide()
end

reassignBtn:SetScript("OnClick", function() PerformReassign(WHBContextIndex, reassignEditBox:GetText()) end)
reassignEditBox:SetScript("OnEnterPressed", function() PerformReassign(WHBContextIndex, reassignEditBox:GetText()) end)
reassignEditBox:SetScript("OnEscapePressed", function() WHBReassignFrame:Hide() end)
reassignCancelBtn:SetScript("OnClick", function() WHBReassignFrame:Hide() end)

local WHBContextMenu = CreateFrame("Frame", "WHBContextMenu", UIParent, "UIDropDownMenuTemplate")
local function InitializeContextMenu(self, level)
    if not WHBContextIndex then return end
    local entry = WHBLootData[WHBContextIndex]; if not entry then return end
    
    local cleanItemName = entry.item:match("%[(.-)%]") or "Item"
    
    local titleInfo = UIDropDownMenu_CreateInfo()
    titleInfo.text = "Modify: " .. cleanItemName; titleInfo.isTitle = true; titleInfo.notCheckable = true
    UIDropDownMenu_AddButton(titleInfo, level)

    local reassignPlayerInfo = UIDropDownMenu_CreateInfo()
    reassignPlayerInfo.text = "Assign to Player..."; reassignPlayerInfo.notCheckable = true
    reassignPlayerInfo.func = function() WHBReassignFrame:Show(); reassignEditBox:SetText(entry.player); reassignEditBox:HighlightText() end
    UIDropDownMenu_AddButton(reassignPlayerInfo, level)

    local bankInfo = UIDropDownMenu_CreateInfo()
    bankInfo.text = "Send to Bank"; bankInfo.notCheckable = true
    bankInfo.func = function() PerformReassign(WHBContextIndex, "Bank") end
    UIDropDownMenu_AddButton(bankInfo, level)

    local deInfo = UIDropDownMenu_CreateInfo()
    deInfo.text = "Disenchant"; deInfo.notCheckable = true
    deInfo.func = function() PerformReassign(WHBContextIndex, "Disenchant") end
    UIDropDownMenu_AddButton(deInfo, level)

    local delInfo = UIDropDownMenu_CreateInfo()
    delInfo.text = "Remove Line Item"; delInfo.notCheckable = true; delInfo.colorCode = "|cFFFF0000"
    delInfo.func = function()
        if IsInGuild() then
            local msg = "DEL~" .. entry.time .. "~" .. entry.player .. "~" .. entry.item
            C_ChatInfo.SendAddonMessage("WHBLoot", msg, "GUILD")
        end
        table.remove(WHBLootData, WHBContextIndex); UpdateViewer()
        print("|cFF00FF00[WHB Loot Tracker]|r Line item deleted.")
    end
    UIDropDownMenu_AddButton(delInfo, level)
    
    local cancelInfo = UIDropDownMenu_CreateInfo()
    cancelInfo.text = "Cancel"; cancelInfo.notCheckable = true
    UIDropDownMenu_AddButton(cancelInfo, level)
end
UIDropDownMenu_Initialize(WHBContextMenu, InitializeContextMenu, "MENU")

messageFrame:SetScript("OnHyperlinkClick", function(self, link, text, button)
    local linkType, indexStr = strsplit(":", link)
    if linkType == "whbctx" then
        if button == "RightButton" then
            WHBContextIndex = tonumber(indexStr)
            ToggleDropDownMenu(1, nil, WHBContextMenu, "cursor", 3, -3)
        end
    else
        SetItemRef(link, text, button)
    end
end)

----------------------------------------
-- INTERNAL OPTIONS PANEL 
----------------------------------------
local optionsFrame = CreateFrame("Frame", nil, mainWindow)
optionsFrame:SetPoint("TOPLEFT", 10, -30); optionsFrame:SetPoint("BOTTOMRIGHT", -10, 40); optionsFrame:Hide()

local qualityBtn = CreateFrame("Button", "WHBQualityBtn", optionsFrame, "UIPanelButtonTemplate")
qualityBtn:SetPoint("TOP", 0, -10); qualityBtn:SetSize(250, 30)
local function UpdateQualityText()
    if WHBSettings.minQuality == 4 then qualityBtn:SetText("Minimum Quality: |cFFA335EEEpic|r")
    elseif WHBSettings.minQuality == 3 then qualityBtn:SetText("Minimum Quality: |cFF0070DDRare|r")
    else qualityBtn:SetText("Minimum Quality: |cFF1EFF00Uncommon|r") end
end
UpdateQualityText()
qualityBtn:SetScript("OnClick", function()
    if WHBSettings.minQuality == 2 then WHBSettings.minQuality = 3 elseif WHBSettings.minQuality == 3 then WHBSettings.minQuality = 4 else WHBSettings.minQuality = 2 end
    UpdateQualityText()
end)

local activeGroupLabel = optionsFrame:CreateFontString("WHBActiveGroupLabel", "OVERLAY", "GameFontNormal")
activeGroupLabel:SetPoint("TOPLEFT", 16, -55)
activeGroupLabel:SetText("Active 10-Man Group Tag:")

local activeGroupDropdown = CreateFrame("Frame", "WHBActiveGroupDropdown", optionsFrame, "UIDropDownMenuTemplate")
activeGroupDropdown:SetPoint("TOPLEFT", 200, -50)

local function ActiveGroupDropdown_OnClick(self, arg1)
    WHBSettings.activeGroup = arg1
    UIDropDownMenu_SetSelectedValue(activeGroupDropdown, arg1)
    UIDropDownMenu_SetText(activeGroupDropdown, arg1)
end

local function InitializeActiveGroupDropdown(self, level)
    local groups = {"Group 1", "Group 2", "Group 3", "Group 4", "Group 5"}
    for _, g in ipairs(groups) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = g; info.arg1 = g; info.value = g; info.func = ActiveGroupDropdown_OnClick
        info.checked = (WHBSettings.activeGroup == g)
        UIDropDownMenu_AddButton(info, level)
    end
end

local raidLabel = optionsFrame:CreateFontString("WHBRaidLabel", "OVERLAY", "GameFontNormal")
raidLabel:SetPoint("TOP", qualityBtn, "BOTTOM", 0, -45); raidLabel:SetText("Ignore Loot Tracking in:")

local tbcRaids = { "Karazhan", "Gruul's Lair", "Magtheridon's Lair", "Serpentshrine Cavern", "The Eye", "Hyjal Summit", "Black Temple", "Zul'Aman", "Sunwell Plateau" }
for i, raid in ipairs(tbcRaids) do
    local cb = CreateFrame("CheckButton", "WHBIgnoreCB"..i, optionsFrame, "UICheckButtonTemplate")
    local col = (i % 2 == 1) and 1 or 2; local row = math.ceil(i / 2)
    cb:SetPoint("TOPLEFT", (col == 1) and 30 or 260, -105 - ((row - 1) * 22))
    cb:SetSize(20, 20); cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0); cb.text:SetText(raid)
    cb:SetScript("OnShow", function(self) self:SetChecked(WHBSettings.ignoredZones[raid]) end)
    cb:SetScript("OnClick", function(self) WHBSettings.ignoredZones[raid] = self:GetChecked() end)
end

local daCb = CreateFrame("CheckButton", "WHBDeathAnnounceCB", optionsFrame, "UICheckButtonTemplate")
daCb:SetPoint("TOPLEFT", 30, -220); daCb:SetSize(22, 22)
daCb.text = daCb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
daCb.text:SetPoint("LEFT", daCb, "RIGHT", 5, 0); daCb.text:SetText("Announce deaths for:")
daCb:SetScript("OnShow", function(self) self:SetChecked(WHBSettings.announcePlayer) end)
daCb:SetScript("OnClick", function(self) WHBSettings.announcePlayer = self:GetChecked() end)

local daEdit = CreateFrame("EditBox", "WHBDeathAnnounceEdit", optionsFrame, "InputBoxTemplate")
daEdit:SetPoint("LEFT", daCb.text, "RIGHT", 10, 0); daEdit:SetSize(100, 20); daEdit:SetAutoFocus(false)
daEdit:SetScript("OnShow", function(self) self:SetText(WHBSettings.announcePlayerName or "Realpower") end)
daEdit:SetScript("OnTextChanged", function(self) WHBSettings.announcePlayerName = self:GetText() end)

local permLabel = optionsFrame:CreateFontString("WHBPermLabel", "OVERLAY", "GameFontNormal")
permLabel:SetPoint("TOPLEFT", 16, -250); permLabel:SetText("Ranks Allowed to Push Full Sync (GM Only):")

local function BuildPermGrid()
    local numRanks = IsInGuild() and GuildControlGetNumRanks() or 0
    local playerRank = GetSafeRank()
    local isGM = (playerRank == 0)

    for i = 1, 10 do
        local rankIdx = i - 1
        local cbName = "WHBPermCB"..rankIdx
        local cb = _G[cbName]
        if i <= numRanks then
            if not cb then
                cb = CreateFrame("CheckButton", cbName, optionsFrame, "UICheckButtonTemplate")
                local col = (i % 2 == 1) and 1 or 2; local row = math.ceil(i / 2)
                cb:SetPoint("TOPLEFT", (col == 1) and 30 or 260, -270 - ((row - 1) * 22))
                cb:SetSize(20, 20)
                cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
            end
            cb.text:SetText(GuildControlGetRankName(i) or "Unknown Rank")
            cb:SetChecked(WHBSettings.allowedRanks[rankIdx])
            
            if not isGM then 
                cb:Disable(); cb.text:SetTextColor(0.5, 0.5, 0.5) 
            else 
                cb:Enable(); cb.text:SetTextColor(1, 0.82, 0) 
            end
            cb:SetScript("OnClick", function(self) WHBSettings.allowedRanks[rankIdx] = self:GetChecked() end)
            cb:Show()
        else
            if cb then cb:Hide() end
        end
    end
end

local function ApplyOfficerLockdowns()
    local playerRank = GetSafeRank()
    local hasPerms = WHBSettings.allowedRanks and WHBSettings.allowedRanks[playerRank]
    
    UIDropDownMenu_Initialize(activeGroupDropdown, InitializeActiveGroupDropdown)
    UIDropDownMenu_SetText(activeGroupDropdown, WHBSettings.activeGroup)

    if hasPerms then
        qualityBtn:Enable()
        UIDropDownMenu_EnableDropDown(activeGroupDropdown)
        activeGroupLabel:SetTextColor(1, 0.82, 0)
        raidLabel:SetTextColor(1, 0.82, 0)
        daCb:Enable(); daCb.text:SetTextColor(1, 0.82, 0)
        daEdit:Enable(); daEdit:SetTextColor(1, 1, 1)
        for i=1, #tbcRaids do local cb = _G["WHBIgnoreCB"..i]; if cb then cb:Enable(); cb.text:SetTextColor(1, 0.82, 0) end end
    else
        qualityBtn:Disable()
        UIDropDownMenu_DisableDropDown(activeGroupDropdown)
        activeGroupLabel:SetTextColor(0.5, 0.5, 0.5)
        raidLabel:SetTextColor(0.5, 0.5, 0.5)
        daCb:Disable(); daCb.text:SetTextColor(0.5, 0.5, 0.5)
        daEdit:Disable(); daEdit:SetTextColor(0.5, 0.5, 0.5)
        for i=1, #tbcRaids do local cb = _G["WHBIgnoreCB"..i]; if cb then cb:Disable(); cb.text:SetTextColor(0.5, 0.5, 0.5) end end
    end
end

local syncBtn = CreateFrame("Button", "WHBPushSyncBtn", optionsFrame, "UIPanelButtonTemplate")
syncBtn:SetPoint("BOTTOMLEFT", 15, 30); syncBtn:SetSize(140, 30); syncBtn:SetText("Push DB to Guild")

local reqSyncBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
reqSyncBtn:SetPoint("BOTTOMRIGHT", -15, 30); reqSyncBtn:SetSize(140, 30); reqSyncBtn:SetText("Request Data")

syncBtn:SetScript("OnEnter", function(self)
    if not self:IsEnabled() then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not IsInGuild() then GameTooltip:SetText("|cFFFF0000Not in a Guild|r\nYou must be in a guild to sync data.")
        else GameTooltip:SetText("|cFFFF0000Permission Denied|r\nYou must be granted Sync Access to push the DB.") end
        GameTooltip:Show()
    end
end)
syncBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

reqSyncBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Ask online Officers to send you\nany loot data you might be missing.")
    GameTooltip:Show()
end)
reqSyncBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

WHBSyncIndex = 1
WHBSyncTarget = "GUILD"

function WHBSendNextSync()
    if WHBSyncIndex > #WHBLootData then
        local endChannel = (WHBSyncTarget == "GUILD") and "GUILD" or "WHISPER"
        local endTarget = (WHBSyncTarget == "GUILD") and nil or WHBSyncTarget
        C_ChatInfo.SendAddonMessage("WHBLoot", "SYNC_END", endChannel, endTarget)
        
        C_Timer.After(3.0, function()
            local count = 0; if WHBSyncAcks then for _ in pairs(WHBSyncAcks) do count = count + 1 end end
            if WHBSyncTarget == "GUILD" then print("|cFF00FF00[WHB Loot Tracker]|r Sync received by " .. count .. " members.")
            else
                if count > 0 then print("|cFF00FF00[WHB Loot Tracker]|r Targeted sync to " .. WHBSyncTarget .. " completed successfully.")
                else print("|cFFFF0000[WHB Loot Tracker]|r Targeted sync to " .. WHBSyncTarget .. " finished, but no response was received.") end
            end
            WHBSyncAcks = nil; syncBtn:Enable(); syncBtn:SetText("Push DB to Guild")
        end)
        return
    end
    
    local entry = WHBLootData[WHBSyncIndex]
    local msg = entry.time .. "~" .. (entry.dateOnly or "") .. "~" .. (entry.player or "") .. "~" .. (entry.item or "") .. "~" .. (entry.zone or "Unknown") .. "~" .. (entry.group or "Main Raid")
    
    if WHBSyncTarget == "GUILD" then C_ChatInfo.SendAddonMessage("WHBLoot", msg, "GUILD") else C_ChatInfo.SendAddonMessage("WHBLoot", msg, "WHISPER", WHBSyncTarget) end
    WHBSyncIndex = WHBSyncIndex + 1; C_Timer.After(0.05, WHBSendNextSync) 
end

syncBtn:SetScript("OnClick", function()
    if not IsInGuild() then return end
    local permStr = ""
    for rankIdx, allowed in pairs(WHBSettings.allowedRanks) do if allowed then permStr = permStr .. rankIdx .. "," end end
    C_ChatInfo.SendAddonMessage("WHBLoot", "PERM_SYNC:" .. permStr, "GUILD")
    WHBSyncAcks = {}; syncBtn:Disable(); syncBtn:SetText("Syncing..."); WHBSyncIndex = 1; WHBSyncTarget = "GUILD"; WHBSendNextSync()
end)

reqSyncBtn:SetScript("OnClick", function()
    if not IsInGuild() then return end
    C_ChatInfo.SendAddonMessage("WHBLoot", "REQ_SYNC", "GUILD")
    print("|cFF00FF00[WHB Loot Tracker]|r Data request sent to online Officers.")
    reqSyncBtn:Disable()
    C_Timer.After(10, function() reqSyncBtn:Enable() end) 
end)

local clearBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
clearBtn:SetPoint("BOTTOMRIGHT", -10, 65)  
clearBtn:SetSize(120, 25)
clearBtn:SetText("Clear All Data")

clearBtn:SetScript("OnEnter", function(self)
    if not self:IsEnabled() then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not IsInGuild() then GameTooltip:SetText("|cFFFF0000Not in a Guild|r\nData clearing is restricted.")
        else GameTooltip:SetText("|cFFFF0000Guild Master Only|r\nOnly the Guild Master can wipe the entire database.") end
        GameTooltip:Show()
    end
end)
clearBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

clearBtn:SetScript("OnClick", function()
    local playerRank = GetSafeRank()
    if playerRank ~= 0 then return end
    StaticPopup_Show("WHB_CLEAR_DATA")
end)

----------------------------------------
-- CREDITS PANEL 
----------------------------------------
local creditsFrame = CreateFrame("Frame", nil, mainWindow)
creditsFrame:SetPoint("TOPLEFT", 10, -30); creditsFrame:SetPoint("BOTTOMRIGHT", -10, 40); creditsFrame:Hide()

local cTitle = creditsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
cTitle:SetPoint("TOP", 0, -30)
cTitle:SetText("Made with <3 for Waffle House Brawlers")

local cBody = creditsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
cBody:SetPoint("TOP", cTitle, "BOTTOM", 0, -30)
cBody:SetJustifyH("CENTER")
cBody:SetText("Maliettv - Design and Coding\n\nBowphades - Concepts and Features\n\nFartjars - For putting up with Maliettv\n\nBigpingus - For being the guilds floor mat (RIP PINGUS)\n\nRealpower - For being the best Pally Tank Partner Maliettv could have.\n\nTreechopper - Being the voice of reason\n\nDoomdrizzle - For keeping a cool head\n\n\n|cFF00FF00The whole WoW Community for using this addon!|r")

local discordBtn = CreateFrame("Button", nil, creditsFrame, "UIPanelButtonTemplate")
discordBtn:SetPoint("TOP", cBody, "BOTTOM", 0, -20)
discordBtn:SetSize(180, 30)
discordBtn:SetText("Join our Discord")
discordBtn:SetScript("OnClick", function()
    StaticPopup_Show("WHB_DISCORD_POPUP")
end)

local vLabel = creditsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
vLabel:SetPoint("BOTTOM", 0, 10)
vLabel:SetText("Version " .. WHB_CURRENT_VERSION)

----------------------------------------
-- VIEWER LOGIC & DROPDOWNS
----------------------------------------
function UpdateViewer()
    messageFrame:Clear(); local hasData = false
    
    local playerRank = GetSafeRank()
    local hasPerms = (WHBSettings.allowedRanks and WHBSettings.allowedRanks[playerRank])
    local searchText = (searchBox and searchBox:GetText() or ""):lower()

    for i, entry in ipairs(WHBLootData) do
        local entryZone = entry.zone or "Unknown"
        local entryGroup = entry.group or "Main Raid"
        local entryDate = entry.dateOnly or string.sub(entry.time, 1, 10)
        
        local zoneMatch = (currentSelectedZone == "All Zones" or currentSelectedZone == entryZone)
        local groupMatch = (currentSelectedGroup == "All Groups" or currentSelectedGroup == entryGroup)
        local dateMatch = (currentSelectedDate == "All Dates" or currentSelectedDate == entryDate)
        local playerMatch = (searchText == "" or string.find((entry.player or ""):lower(), searchText, 1, true) ~= nil)
        
        if zoneMatch and groupMatch and dateMatch and playerMatch then
            local displayTime = entry.time
            if hasPerms then displayTime = "|Hwhbctx:" .. i .. "|h|cFFFFD100" .. entry.time .. "|r|h" end
            
            local groupTag = ""
            if entryGroup ~= "Main Raid" then groupTag = " [" .. entryGroup .. "]" end

            messageFrame:AddMessage(displayTime .. " - " .. entry.player .. " looted " .. entry.item .. " in " .. entryZone .. groupTag)
            hasData = true
        end
    end
    if not hasData then messageFrame:AddMessage("No loot recorded for this selection.") end
end

local function ZoneDropdown_OnClick(self, arg1)
    currentSelectedZone = arg1; UIDropDownMenu_SetSelectedValue(zoneDropdown, currentSelectedZone); UIDropDownMenu_SetText(zoneDropdown, currentSelectedZone)
    currentSelectedGroup = "All Groups"; UIDropDownMenu_SetText(groupDropdown, currentSelectedGroup)
    currentSelectedDate = "All Dates"; UIDropDownMenu_SetText(dateDropdown, currentSelectedDate)
    UpdateViewer()
end
function InitializeZoneDropdown(self, level)
    local info = UIDropDownMenu_CreateInfo(); info.func = ZoneDropdown_OnClick
    info.text = "All Zones"; info.arg1 = "All Zones"; info.checked = currentSelectedZone == "All Zones"; UIDropDownMenu_AddButton(info)
    local zones = {}; local found = {}
    for _, entry in ipairs(WHBLootData) do
        local z = entry.zone or "Unknown"
        if not found[z] then table.insert(zones, z); found[z] = true end
    end
    table.sort(zones); for _, z in ipairs(zones) do info.text = z; info.arg1 = z; info.checked = currentSelectedZone == z; UIDropDownMenu_AddButton(info) end
end

local function GroupDropdown_OnClick(self, arg1)
    currentSelectedGroup = arg1; UIDropDownMenu_SetSelectedValue(groupDropdown, currentSelectedGroup); UIDropDownMenu_SetText(groupDropdown, currentSelectedGroup)
    currentSelectedDate = "All Dates"; UIDropDownMenu_SetText(dateDropdown, currentSelectedDate)
    UpdateViewer()
end
function InitializeGroupDropdown(self, level)
    local info = UIDropDownMenu_CreateInfo(); info.func = GroupDropdown_OnClick
    info.text = "All Groups"; info.arg1 = "All Groups"; info.checked = currentSelectedGroup == "All Groups"; UIDropDownMenu_AddButton(info)
    local groups = {}; local found = {}
    for _, entry in ipairs(WHBLootData) do
        local entryZone = entry.zone or "Unknown"
        local entryGroup = entry.group or "Main Raid"
        if currentSelectedZone == "All Zones" or currentSelectedZone == entryZone then
            if not found[entryGroup] then table.insert(groups, entryGroup); found[entryGroup] = true end
        end
    end
    table.sort(groups); for _, g in ipairs(groups) do info.text = g; info.arg1 = g; info.checked = currentSelectedGroup == g; UIDropDownMenu_AddButton(info) end
end

local function DateDropdown_OnClick(self, arg1)
    currentSelectedDate = arg1; UIDropDownMenu_SetSelectedValue(dateDropdown, currentSelectedDate); UIDropDownMenu_SetText(dateDropdown, currentSelectedDate)
    UpdateViewer()
end
function InitializeDateDropdown(self, level)
    local info = UIDropDownMenu_CreateInfo(); info.func = DateDropdown_OnClick
    info.text = "All Dates"; info.arg1 = "All Dates"; info.checked = currentSelectedDate == "All Dates"; UIDropDownMenu_AddButton(info)
    local dates = {}; local found = {}
    for _, entry in ipairs(WHBLootData) do
        local entryZone = entry.zone or "Unknown"
        local entryGroup = entry.group or "Main Raid"
        if (currentSelectedZone == "All Zones" or currentSelectedZone == entryZone) and (currentSelectedGroup == "All Groups" or currentSelectedGroup == entryGroup) then
            local d = entry.dateOnly or string.sub(entry.time, 1, 10)
            if not found[d] then table.insert(dates, d); found[d] = true end
        end
    end
    table.sort(dates, function(a, b) return a > b end)
    for _, d in ipairs(dates) do info.text = d; info.arg1 = d; info.checked = currentSelectedDate == d; UIDropDownMenu_AddButton(info) end
end

----------------------------------------
-- BOTTOM BUTTON NAVIGATION LOGIC
----------------------------------------
local exportBtn = CreateFrame("Button", nil, mainWindow, "UIPanelButtonTemplate")
exportBtn:SetPoint("BOTTOMLEFT", 10, 10); exportBtn:SetSize(100, 25)

local optionsToggleBtn = CreateFrame("Button", nil, mainWindow, "UIPanelButtonTemplate")
optionsToggleBtn:SetPoint("LEFT", exportBtn, "RIGHT", 10, 0); optionsToggleBtn:SetSize(100, 25)

local creditsBtn = CreateFrame("Button", nil, mainWindow, "UIPanelButtonTemplate")
creditsBtn:SetPoint("LEFT", optionsToggleBtn, "RIGHT", 10, 0); creditsBtn:SetSize(100, 25)

local isExportMode = false; local isOptionsMode = false; local isCreditsMode = false

local function ResetViews() 
    viewerScroll:Hide(); exportEditBox:Hide(); optionsFrame:Hide(); creditsFrame:Hide()
    zoneDropdown:Hide(); groupDropdown:Hide(); dateDropdown:Hide()
    searchLabel:Hide(); searchBox:Hide()
    
    exportBtn:SetText("Export CSV")
    optionsToggleBtn:SetText("Options")
    creditsBtn:SetText("Credits")
end

exportBtn:SetScript("OnClick", function()
    local wasExport = isExportMode
    isExportMode, isOptionsMode, isCreditsMode = false, false, false
    ResetViews()
    
    if not wasExport then
        isExportMode = true
        mainWindow.title:SetText("WHB Loot Tracker - Export")
        exportBtn:SetText("Back")
        
        zoneDropdown:Show(); groupDropdown:Show(); dateDropdown:Show(); searchLabel:Show(); searchBox:Show()
        
        local csvData = "Date,Player,Item,Zone,Group\n"
        local searchText = (searchBox and searchBox:GetText() or ""):lower()
        
        for _, entry in ipairs(WHBLootData) do
            local entryZone = entry.zone or "Unknown"
            local entryGroup = entry.group or "Main Raid"
            local entryDate = entry.dateOnly or string.sub(entry.time, 1, 10)
            
            local zoneMatch = (currentSelectedZone == "All Zones" or currentSelectedZone == entryZone)
            local groupMatch = (currentSelectedGroup == "All Groups" or currentSelectedGroup == entryGroup)
            local dateMatch = (currentSelectedDate == "All Dates" or currentSelectedDate == entryDate)
            local playerMatch = (searchText == "" or string.find((entry.player or ""):lower(), searchText, 1, true) ~= nil)
            
            if zoneMatch and groupMatch and dateMatch and playerMatch then
                csvData = csvData .. entry.time .. "," .. (entry.player or "Unknown") .. "," .. (entry.item or "Unknown") .. "," .. entryZone .. "," .. entryGroup .. "\n"
            end
        end
        exportEditBox:SetText(csvData); viewerScroll:Show(); exportEditBox:Show(); viewerScroll:SetScrollChild(exportEditBox); exportEditBox:HighlightText()
    else
        mainWindow.title:SetText("WHB Loot Tracker - Viewer v" .. WHB_CURRENT_VERSION)
        zoneDropdown:Show(); groupDropdown:Show(); dateDropdown:Show(); searchLabel:Show(); searchBox:Show(); viewerScroll:Show(); messageFrame:Show()
    end
end)

optionsToggleBtn:SetScript("OnClick", function()
    local wasOptions = isOptionsMode
    isExportMode, isOptionsMode, isCreditsMode = false, false, false
    ResetViews()
    
    if not wasOptions then
        isOptionsMode = true
        mainWindow.title:SetText("WHB Loot Tracker - Options")
        optionsToggleBtn:SetText("Back")
        optionsFrame:Show()
        
        BuildPermGrid(); ApplyOfficerLockdowns()
        local playerRank = GetSafeRank()
        if WHBSettings.allowedRanks[playerRank] then syncBtn:Enable() else syncBtn:Disable() end
        if not IsInGuild() then reqSyncBtn:Disable() else reqSyncBtn:Enable() end
        if playerRank == 0 then clearBtn:Enable() else clearBtn:Disable() end
    else
        mainWindow.title:SetText("WHB Loot Tracker - Viewer v" .. WHB_CURRENT_VERSION)
        zoneDropdown:Show(); groupDropdown:Show(); dateDropdown:Show(); searchLabel:Show(); searchBox:Show(); viewerScroll:Show(); messageFrame:Show()
    end
end)

creditsBtn:SetScript("OnClick", function()
    local wasCredits = isCreditsMode
    isExportMode, isOptionsMode, isCreditsMode = false, false, false
    ResetViews()
    
    if not wasCredits then
        isCreditsMode = true
        mainWindow.title:SetText("WHB Loot Tracker - Credits")
        creditsBtn:SetText("Back")
        creditsFrame:Show()
    else
        mainWindow.title:SetText("WHB Loot Tracker - Viewer v" .. WHB_CURRENT_VERSION)
        zoneDropdown:Show(); groupDropdown:Show(); dateDropdown:Show(); searchLabel:Show(); searchBox:Show(); viewerScroll:Show(); messageFrame:Show()
    end
end)

ResetViews()
mainWindow.title:SetText("WHB Loot Tracker - Viewer v" .. WHB_CURRENT_VERSION)
zoneDropdown:Show(); groupDropdown:Show(); dateDropdown:Show(); searchLabel:Show(); searchBox:Show(); viewerScroll:Show(); messageFrame:Show()

----------------------------------------
-- SLASH COMMANDS
----------------------------------------
SLASH_WHBLOOT1 = "/whbloot"
SLASH_WHBLOOT2 = "/whb"
SlashCmdList["WHBLOOT"] = function()
    if mainWindow:IsShown() then mainWindow:Hide()
    else 
        UIDropDownMenu_Initialize(zoneDropdown, InitializeZoneDropdown); UIDropDownMenu_SetText(zoneDropdown, currentSelectedZone)
        UIDropDownMenu_Initialize(groupDropdown, InitializeGroupDropdown); UIDropDownMenu_SetText(groupDropdown, currentSelectedGroup)
        UIDropDownMenu_Initialize(dateDropdown, InitializeDateDropdown); UIDropDownMenu_SetText(dateDropdown, currentSelectedDate)
        UpdateViewer(); mainWindow:Show() 
    end
end

SLASH_WHBTEST1 = "/whbtest"
SlashCmdList["WHBTEST"] = function()
    local playerRank = GetSafeRank()
    if not (WHBSettings.allowedRanks and WHBSettings.allowedRanks[playerRank]) then
        print("|cFFFF0000[WHB Loot Tracker]|r Permission Denied: You must have Sync Access to inject test data.")
        return
    end

    local myName = UnitName("player") or "Unknown"
    table.insert(WHBLootData, { time = "2004-05-24 19:30:00", dateOnly = "2004-05-24", player = myName, item = "|cffff8000|Hitem:32837:::::::::::::|h[Warglaive of Azzinoth]|h|r", zone = "Black Temple", group = "Main Raid" })
    print("|cFF00FF00[WHB Loot Tracker]|r Test entry added for " .. myName .. "!")
    if WHBMainWindow and WHBMainWindow:IsShown() then 
        UIDropDownMenu_Initialize(zoneDropdown, InitializeZoneDropdown)
        UIDropDownMenu_Initialize(groupDropdown, InitializeGroupDropdown)
        UIDropDownMenu_Initialize(dateDropdown, InitializeDateDropdown)
        UpdateViewer() 
    end
end