-- Initialize saved variables
WHBLootData = WHBLootData or {}
WHBSettings = WHBSettings or { 
    minQuality = 3, 
    ignoredZones = {},
    announcePlayer = false,
    announcePlayerName = "Realpower", -- Default name
    officerRankIndex = 1 
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Register our secret Addon channel prefix for Guild Syncing
C_ChatInfo.RegisterAddonMessagePrefix("WHBLoot")

-- Table to hold the sync acknowledgements
local WHBSyncAcks = nil

----------------------------------------
-- EVENT HANDLER (Tracking, Syncing & Deaths)
----------------------------------------
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "WHBLootTrackerClassic" then
            WHBLootData = WHBLootData or {}
            WHBSettings = WHBSettings or { minQuality = 3, ignoredZones = {}, announcePlayer = false, announcePlayerName = "Realpower", officerRankIndex = 1 }
            WHBSettings.ignoredZones = WHBSettings.ignoredZones or {}
            if WHBSettings.announcePlayer == nil then WHBSettings.announcePlayer = false end
            if WHBSettings.announcePlayerName == nil then WHBSettings.announcePlayerName = "Realpower" end
            if WHBSettings.officerRankIndex == nil then WHBSettings.officerRankIndex = 1 end
            
            print("|cFF00FF00[WHB Loot Tracker]|r loaded! Type /whbloot to open.")
        end

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
                    local timestamp = date("%Y-%m-%d %H:%M:%S")
                    local dateOnlyStr = date("%Y-%m-%d")
                    
                    table.insert(WHBLootData, {
                        time = timestamp,
                        dateOnly = dateOnlyStr,
                        player = playerName,
                        item = itemLink
                    })
                    
                    if IsInGuild() then
                        local msg = timestamp .. "~" .. dateOnlyStr .. "~" .. playerName .. "~" .. itemLink
                        C_ChatInfo.SendAddonMessage("WHBLoot", msg, "GUILD")
                    end
                end
            end
        end
        
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix == "WHBLoot" and sender ~= UnitName("player") then
            
            -- Handle the Sync Handshake Protocol
            if text == "SYNC_END" then
                C_ChatInfo.SendAddonMessage("WHBLoot", "SYNC_ACK", "WHISPER", sender)
                return
            elseif text == "SYNC_ACK" then
                if WHBSyncAcks then
                    local cleanName = sender:match("([^%-]+)") or sender
                    WHBSyncAcks[cleanName] = true
                end
                return
            end

            -- Handle Normal Loot Data
            local tTime, tDate, tPlayer, tItem = text:match("([^~]+)~([^~]+)~([^~]+)~(.+)")
            
            if tTime and tItem then
                local isDuplicate = false
                for _, entry in ipairs(WHBLootData) do
                    if entry.time == tTime and entry.player == tPlayer and entry.item == tItem then
                        isDuplicate = true
                        break
                    end
                end
                
                if not isDuplicate then
                    table.insert(WHBLootData, {
                        time = tTime,
                        dateOnly = tDate,
                        player = tPlayer,
                        item = tItem
                    })
                    if WHBMainWindow and WHBMainWindow:IsShown() and UpdateViewer then
                        UpdateViewer()
                    end
                end
            end
        end
        
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if WHBSettings.announcePlayer and IsInGuild() and WHBSettings.announcePlayerName and WHBSettings.announcePlayerName ~= "" then
            local _, subevent, _, _, _, _, _, _, destName = CombatLogGetCurrentEventInfo()
            
            if subevent == "UNIT_DIED" and destName then
                -- Strip server names just in case (e.g., "Player-Server")
                local cleanDestName = string.match(destName, "([^%-]+)") or destName
                
                -- Case insensitive check
                if string.lower(cleanDestName) == string.lower(WHBSettings.announcePlayerName) then
                    SendChatMessage(WHBSettings.announcePlayerName .. " is dead again.", "GUILD")
                end
            end
        end
    end
end)

----------------------------------------
-- UI FRAMES: VIEWER, OPTIONS & EXPORT
----------------------------------------
local currentSelectedDate = "All Dates"

local mainWindow = CreateFrame("Frame", "WHBMainWindow", UIParent, "BasicFrameTemplateWithInset")
mainWindow:SetSize(600, 500) 
mainWindow:SetPoint("CENTER")
mainWindow:SetMovable(true)
mainWindow:EnableMouse(true)
mainWindow:RegisterForDrag("LeftButton")
mainWindow:SetScript("OnDragStart", mainWindow.StartMoving)
mainWindow:SetScript("OnDragStop", mainWindow.StopMovingOrSizing)
mainWindow:Hide()

mainWindow:SetResizable(true)
if mainWindow.SetResizeBounds then
    mainWindow:SetResizeBounds(500, 500) -- Increased minimum height slightly to fit options
else
    mainWindow:SetMinResize(500, 500)
end

local resizeGrip = CreateFrame("Button", nil, mainWindow)
resizeGrip:SetPoint("BOTTOMRIGHT", -5, 5)
resizeGrip:SetSize(16, 16)
resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

resizeGrip:SetScript("OnMouseDown", function() mainWindow:StartSizing("BOTTOMRIGHT") end)
resizeGrip:SetScript("OnMouseUp", function() mainWindow:StopMovingOrSizing() end)

mainWindow.title = mainWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mainWindow.title:SetPoint("CENTER", mainWindow.TitleBg, "CENTER", 0, 0)
mainWindow.title:SetText("WHB Loot Tracker - Viewer")

local dateDropdown = CreateFrame("Frame", "WHBDateDropdown", mainWindow, "UIDropDownMenuTemplate")
dateDropdown:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 0, -30)

local viewerScroll = CreateFrame("ScrollFrame", "WHBViewerScroll", mainWindow, "UIPanelScrollFrameTemplate")
viewerScroll:SetPoint("TOPLEFT", 10, -65)
viewerScroll:SetPoint("BOTTOMRIGHT", -30, 40)

local messageFrame = CreateFrame("ScrollingMessageFrame", nil, viewerScroll)
messageFrame:SetSize(560, 390) 
messageFrame:SetFontObject(ChatFontNormal)
messageFrame:SetJustifyH("LEFT")
messageFrame:SetMaxLines(1000)
messageFrame:SetFading(false)
messageFrame:SetInsertMode("BOTTOM")
viewerScroll:SetScrollChild(messageFrame)

local exportEditBox = CreateFrame("EditBox", nil, viewerScroll)
exportEditBox:SetMultiLine(true)
exportEditBox:SetFontObject(ChatFontNormal)
exportEditBox:SetWidth(560) 
exportEditBox:Hide()

mainWindow:SetScript("OnSizeChanged", function(self, width, height)
    local newWidth = width - 40 
    local newHeight = height - 110 
    if newWidth > 0 and newHeight > 0 then
        messageFrame:SetSize(newWidth, newHeight)
        exportEditBox:SetWidth(newWidth)
    end
end)

----------------------------------------
-- INTERNAL OPTIONS PANEL
----------------------------------------
local optionsFrame = CreateFrame("Frame", nil, mainWindow)
optionsFrame:SetPoint("TOPLEFT", 10, -30)
optionsFrame:SetPoint("BOTTOMRIGHT", -10, 40)
optionsFrame:Hide()

local optionsTitle = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
optionsTitle:SetPoint("TOP", 0, -10)
optionsTitle:SetText("Tracker Settings")

local qualityBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
qualityBtn:SetPoint("TOP", 0, -40)
qualityBtn:SetSize(250, 30)

local function UpdateQualityText()
    if WHBSettings.minQuality == 4 then qualityBtn:SetText("Minimum Quality: |cFFA335EEEpic|r")
    elseif WHBSettings.minQuality == 3 then qualityBtn:SetText("Minimum Quality: |cFF0070DDRare|r")
    else qualityBtn:SetText("Minimum Quality: |cFF1EFF00Uncommon|r") end
end
UpdateQualityText()

qualityBtn:SetScript("OnClick", function()
    if WHBSettings.minQuality == 2 then WHBSettings.minQuality = 3
    elseif WHBSettings.minQuality == 3 then WHBSettings.minQuality = 4
    else WHBSettings.minQuality = 2 end
    UpdateQualityText()
end)

local raidLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
raidLabel:SetPoint("TOP", qualityBtn, "BOTTOM", 0, -15)
raidLabel:SetText("Check Raids to IGNORE Loot Tracking:")

local tbcRaids = {
    { internal = "Karazhan", display = "Karazhan" },
    { internal = "Gruul's Lair", display = "Gruul's Lair" },
    { internal = "Magtheridon's Lair", display = "Magtheridon's Lair" },
    { internal = "Serpentshrine Cavern", display = "Serpentshrine Cavern" },
    { internal = "The Eye", display = "Tempest Keep (The Eye)" },
    { internal = "Hyjal Summit", display = "Battle for Mount Hyjal" },
    { internal = "Black Temple", display = "Black Temple" },
    { internal = "Zul'Aman", display = "Zul'Aman" },
    { internal = "Sunwell Plateau", display = "Sunwell Plateau" }
}

for i, raid in ipairs(tbcRaids) do
    local cb = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
    local col = (i % 2 == 1) and 1 or 2
    local row = math.ceil(i / 2)
    local xOffset = (col == 1) and 30 or 260 
    local yOffset = -110 - ((row - 1) * 25) 
    
    cb:SetPoint("TOPLEFT", xOffset, yOffset)
    cb:SetSize(24, 24)
    
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 1)
    cb.text:SetText(raid.display)
    
    cb:SetScript("OnShow", function(self) self:SetChecked(WHBSettings.ignoredZones[raid.internal]) end)
    cb:SetScript("OnClick", function(self) WHBSettings.ignoredZones[raid.internal] = self:GetChecked() end)
end

-- 3. Dynamic Player Death Announcer
local deathAnnounceCb = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
deathAnnounceCb:SetPoint("TOPLEFT", 30, -235) 
deathAnnounceCb:SetSize(24, 24)

deathAnnounceCb.text = deathAnnounceCb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
deathAnnounceCb.text:SetPoint("LEFT", deathAnnounceCb, "RIGHT", 5, 1)
deathAnnounceCb.text:SetText("Announce deaths for:")

deathAnnounceCb:SetScript("OnShow", function(self) self:SetChecked(WHBSettings.announcePlayer) end)
deathAnnounceCb:SetScript("OnClick", function(self) WHBSettings.announcePlayer = self:GetChecked() end)

local deathAnnounceEditBox = CreateFrame("EditBox", nil, optionsFrame, "InputBoxTemplate")
deathAnnounceEditBox:SetPoint("LEFT", deathAnnounceCb.text, "RIGHT", 10, 0)
deathAnnounceEditBox:SetSize(120, 20)
deathAnnounceEditBox:SetAutoFocus(false)

deathAnnounceEditBox:SetScript("OnShow", function(self)
    self:SetText(WHBSettings.announcePlayerName or "Realpower")
end)

deathAnnounceEditBox:SetScript("OnTextChanged", function(self)
    WHBSettings.announcePlayerName = self:GetText()
end)

-- Warning Label below the checkbox
local deathWarningLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
deathWarningLabel:SetPoint("TOPLEFT", 35, -260)
deathWarningLabel:SetText("|cFFFF0000(WARNING: Only ONE person in the guild should check this!)|r")

-- 4. Guild Rank Sync Permissions
local rankLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rankLabel:SetPoint("TOPLEFT", 16, -285)
rankLabel:SetText("Minimum Rank Required to Push Full Sync:")

local rankDropdown = CreateFrame("Frame", "WHBRankDropdown", optionsFrame, "UIDropDownMenuTemplate")
rankDropdown:SetPoint("TOPLEFT", -5, -300)

local function RankDropdown_OnClick(self, arg1)
    WHBSettings.officerRankIndex = arg1
    UIDropDownMenu_SetSelectedValue(rankDropdown, arg1)
    UIDropDownMenu_SetText(rankDropdown, GuildControlGetRankName(arg1 + 1))
end

local function InitializeRankDropdown(self, level)
    local numRanks = GuildControlGetNumRanks()
    if numRanks == 0 then numRanks = 10 end 
    
    for i = 1, numRanks do
        local info = UIDropDownMenu_CreateInfo()
        info.text = GuildControlGetRankName(i) or ("Rank " .. i)
        info.arg1 = i - 1 
        info.value = i - 1
        info.func = RankDropdown_OnClick
        info.checked = (WHBSettings.officerRankIndex == (i - 1))
        UIDropDownMenu_AddButton(info, level)
    end
end

-- 5. Guild Sync Push Button
local syncBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
syncBtn:SetPoint("TOP", 0, -355) 
syncBtn:SetSize(250, 30)
syncBtn:SetText("Push Full DB Sync to Guild")

local syncIndex = 1
local function SendNextSync()
    if syncIndex > #WHBLootData then
        C_ChatInfo.SendAddonMessage("WHBLoot", "SYNC_END", "GUILD")
        
        C_Timer.After(3.0, function()
            local count = 0
            local names = {}
            for name, _ in pairs(WHBSyncAcks) do
                count = count + 1
                table.insert(names, name)
            end
            
            if count == 0 then
                print("|cFFFF0000[WHB Loot Tracker]|r Sync pushed, but no other guild members with the addon responded.")
            elseif count <= 5 then
                print("|cFF00FF00[WHB Loot Tracker]|r Sync successfully received by: " .. table.concat(names, ", "))
            else
                print("|cFF00FF00[WHB Loot Tracker]|r Sync successfully received by " .. count .. " members.")
            end
            
            WHBSyncAcks = nil
            syncBtn:Enable()
            syncBtn:SetText("Push Full DB Sync to Guild")
        end)
        return
    end
    
    local entry = WHBLootData[syncIndex]
    local msg = entry.time .. "~" .. entry.dateOnly .. "~" .. entry.player .. "~" .. entry.item
    C_ChatInfo.SendAddonMessage("WHBLoot", msg, "GUILD")
    
    syncIndex = syncIndex + 1
    C_Timer.After(0.05, SendNextSync) 
end

syncBtn:SetScript("OnClick", function()
    if not IsInGuild() then
        print("|cFFFF0000[WHB Loot Tracker]|r Error: You must be in a guild to sync.")
        return
    end
    
    local _, _, playerRankIndex = GetGuildInfo("player")
    if playerRankIndex > WHBSettings.officerRankIndex then
        print("|cFFFF0000[WHB Loot Tracker]|r Access Denied. Pushing a full sync is restricted to Officers and the Guild Master.")
        return
    end
    
    WHBSyncAcks = {} 
    syncBtn:Disable()
    syncBtn:SetText("Syncing... Listening for ACKs...")
    syncIndex = 1
    SendNextSync()
end)

local copyrightText = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
copyrightText:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, 10)
copyrightText:SetText("© 2026 Maliettv-Nightslayer US - Waffle House Brawlers")

----------------------------------------
-- VIEWER LOGIC & NAVIGATION BUTTONS
----------------------------------------
function UpdateViewer()
    messageFrame:Clear()
    local hasData = false
    for _, entry in ipairs(WHBLootData) do
        local entryDate = entry.dateOnly or string.sub(entry.time, 1, 10)
        if currentSelectedDate == "All Dates" or currentSelectedDate == entryDate then
            messageFrame:AddMessage(entry.time .. " - " .. entry.player .. " looted " .. entry.item)
            hasData = true
        end
    end
    if not hasData then messageFrame:AddMessage("No loot recorded for this date.") end
end

local function Dropdown_OnClick(self, arg1)
    currentSelectedDate = arg1
    UIDropDownMenu_SetSelectedValue(dateDropdown, currentSelectedDate)
    UIDropDownMenu_SetText(dateDropdown, currentSelectedDate)
    UpdateViewer()
end

function InitializeDropdown(self, level)
    local info = UIDropDownMenu_CreateInfo()
    info.func = Dropdown_OnClick
    
    info.text = "All Dates"; info.arg1 = "All Dates"; info.value = "All Dates"; info.checked = currentSelectedDate == "All Dates"
    UIDropDownMenu_AddButton(info, level)
    
    local dates = {}; local found = {}
    for _, entry in ipairs(WHBLootData) do
        local entryDate = entry.dateOnly or string.sub(entry.time, 1, 10)
        if not found[entryDate] then
            table.insert(dates, entryDate)
            found[entryDate] = true
        end
    end
    table.sort(dates, function(a, b) return a > b end)
    
    for _, d in ipairs(dates) do
        info.text = d; info.arg1 = d; info.value = d; info.checked = currentSelectedDate == d
        UIDropDownMenu_AddButton(info, level)
    end
end

local exportBtn = CreateFrame("Button", nil, mainWindow, "UIPanelButtonTemplate")
exportBtn:SetPoint("BOTTOMLEFT", 10, 10)
exportBtn:SetSize(100, 25)
exportBtn:SetText("Export CSV")

local optionsToggleBtn = CreateFrame("Button", nil, mainWindow, "UIPanelButtonTemplate")
optionsToggleBtn:SetPoint("LEFT", exportBtn, "RIGHT", 10, 0)
optionsToggleBtn:SetSize(100, 25)
optionsToggleBtn:SetText("Options")

local clearBtn = CreateFrame("Button", nil, mainWindow, "UIPanelButtonTemplate")
clearBtn:SetPoint("BOTTOMRIGHT", -25, 10) 
clearBtn:SetSize(100, 25)
clearBtn:SetText("Clear Data")

local isExportMode = false
local isOptionsMode = false

local function ResetViews()
    viewerScroll:Hide()
    exportEditBox:Hide()
    optionsFrame:Hide()
    dateDropdown:Hide()
end

exportBtn:SetScript("OnClick", function()
    isExportMode = not isExportMode
    isOptionsMode = false
    ResetViews()
    
    if isExportMode then
        mainWindow.title:SetText("WHB Loot Tracker - Export (Ctrl+C)")
        exportBtn:SetText("Back")
        optionsToggleBtn:SetText("Options")
        
        local csvData = "Date,Player,Item\n"
        for _, entry in ipairs(WHBLootData) do
            local entryDate = entry.dateOnly or string.sub(entry.time, 1, 10)
            if currentSelectedDate == "All Dates" or currentSelectedDate == entryDate then
                csvData = csvData .. entry.time .. "," .. entry.player .. "," .. entry.item .. "\n"
            end
        end
        exportEditBox:SetText(csvData)
        viewerScroll:Show()
        exportEditBox:Show()
        viewerScroll:SetScrollChild(exportEditBox)
        exportEditBox:HighlightText()
    else
        mainWindow.title:SetText("WHB Loot Tracker - Viewer")
        exportBtn:SetText("Export CSV")
        dateDropdown:Show()
        viewerScroll:Show()
        messageFrame:Show()
        viewerScroll:SetScrollChild(messageFrame)
    end
end)

optionsToggleBtn:SetScript("OnClick", function()
    isOptionsMode = not isOptionsMode
    isExportMode = false
    ResetViews()
    
    if isOptionsMode then
        mainWindow.title:SetText("WHB Loot Tracker - Options")
        optionsToggleBtn:SetText("Back")
        exportBtn:SetText("Export CSV")
        
        UIDropDownMenu_Initialize(rankDropdown, InitializeRankDropdown)
        local displayRank = GuildControlGetRankName((WHBSettings.officerRankIndex or 1) + 1) or "Select Rank"
        UIDropDownMenu_SetText(rankDropdown, displayRank)
        
        optionsFrame:Show()
    else
        mainWindow.title:SetText("WHB Loot Tracker - Viewer")
        optionsToggleBtn:SetText("Options")
        dateDropdown:Show()
        viewerScroll:Show()
        messageFrame:Show()
        viewerScroll:SetScrollChild(messageFrame)
    end
end)

clearBtn:SetScript("OnClick", function()
    WHBLootData = {}
    currentSelectedDate = "All Dates"
    UIDropDownMenu_SetText(dateDropdown, currentSelectedDate)
    UpdateViewer()
    exportEditBox:SetText("Date,Player,Item\n")
    print("|cFF00FF00[WHB Loot Tracker]|r All data cleared.")
end)

----------------------------------------
-- SLASH COMMANDS
----------------------------------------
SLASH_WHBLOOT1 = "/whbloot"
SlashCmdList["WHBLOOT"] = function()
    if mainWindow:IsShown() then
        mainWindow:Hide()
    else
        UIDropDownMenu_Initialize(dateDropdown, InitializeDropdown)
        UIDropDownMenu_SetText(dateDropdown, currentSelectedDate)
        UpdateViewer()
        mainWindow:Show()
    end
end

SLASH_WHBTEST1 = "/whbtest"
SlashCmdList["WHBTEST"] = function()
    local fakeWarglaive = "|cffff8000|Hitem:32837:::::::::::::|h[Warglaive of Azzinoth]|h|r"
    table.insert(WHBLootData, { time = "2004-05-24 19:30:00", dateOnly = "2004-05-24", player = "Realpower", item = fakeWarglaive })
    print("|cFF00FF00[WHB Loot Tracker]|r Test entry added for Realpower.")
    if WHBMainWindow and WHBMainWindow:IsShown() then
        UIDropDownMenu_Initialize(WHBDateDropdown, InitializeDropdown)
        UpdateViewer()
    end
end