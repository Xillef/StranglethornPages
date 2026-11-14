local _, ns = ...
local L, COLORS = ns.L, ns.COLORS

local WIDTH = 270
local PAD = 14
local ROW_H = 16
local HEADER_H = 20
local COL_PAGE_W = 60
local COL_COUNT_W = 46
local READY_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"

local frame        -- created on first show
local headers, rows = {}, {}

local function SetColor(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

local function FormatAge(t)
    if not t then return nil end
    local s = math.max(0, time() - t)
    if s < 3600 then return L.minutes:format(math.max(1, math.floor(s / 60))) end
    if s < 86400 then return L.hours:format(math.floor(s / 3600)) end
    return L.days:format(math.floor(s / 86400))
end

local function LocationText(loc)
    if loc.kind == "sent" then return L.sentTo:format(ns.ShortName(loc.char)) end
    if loc.own then return L[loc.kind] end
    return L[loc.kind .. "Of"]:format(ns.ShortName(loc.char))
end

local function JoinLocations(locs)
    if #locs == 0 then return L.nowhere end
    local parts = {}
    for i, loc in ipairs(locs) do
        local text = LocationText(loc)
        if loc.count > 1 then text = text .. " (" .. loc.count .. ")" end
        parts[i] = text
    end
    return table.concat(parts, ", ")
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------
local function Row_OnEnter(self)
    local status = ns:GetItemStatus(self.itemID)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemID)
    if #status.locs > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.ttWhere, COLORS.header[1], COLORS.header[2], COLORS.header[3])
        for _, loc in ipairs(status.locs) do
            local text = LocationText(loc)
            -- own bags are live; everything else is a snapshot with an age
            if not (loc.own and loc.kind == "bags") then
                local age = FormatAge(loc.time)
                if age then text = L.ttScanned:format(text, age) end
            end
            GameTooltip:AddDoubleLine(text, loc.count, 1, 1, 1, 1, 1, 1)
        end
    end
    if ns:HasSentEntries(self.itemID) then
        GameTooltip:AddLine(L.ttRemoveSent, COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    end
    GameTooltip:Show()
end

local function Row_OnClick(self, button)
    if button == "RightButton" and ns:HasSentEntries(self.itemID) then
        ns:ForgetSent(self.itemID)
        print("|cffffd100Stranglethorn Pages:|r " .. L.removedSent:format(self.label))
        GameTooltip:Hide()
    end
end

local function CreatePageRow(parent, pageNumber, itemID)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row.itemID = itemID
    row:RegisterForClicks("RightButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:GetHighlightTexture():SetAlpha(0.35)

    row.page = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.page:SetPoint("LEFT", 8, 0)
    row.page:SetWidth(COL_PAGE_W - 8)
    row.page:SetJustifyH("LEFT")
    row.label = L.page:format(pageNumber)
    row.page:SetText(row.label)

    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.count:SetPoint("RIGHT", -2, 0)
    row.count:SetWidth(COL_COUNT_W)
    row.count:SetJustifyH("RIGHT")

    row.where = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.where:SetPoint("LEFT", COL_PAGE_W, 0)
    row.where:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
    row.where:SetJustifyH("LEFT")
    row.where:SetWordWrap(false)

    row:SetScript("OnEnter", Row_OnEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", Row_OnClick)
    return row
end

local function CreateHeader(parent)
    local h = CreateFrame("Frame", nil, parent)
    h:SetHeight(HEADER_H)
    h.label = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.label:SetPoint("LEFT", 0, -1)
    h.progress = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.progress:SetPoint("RIGHT", -2, -1)
    return h
end

---------------------------------------------------------------------------
-- Refresh: recompute every row from the tracker and lay out top to bottom
---------------------------------------------------------------------------
local function Refresh()
    if not frame or not frame:IsShown() then return end
    local hasQuest, questDone = ns:GetQuestState()
    local found, missing = 0, {}
    local y = -38

    if questDone or not hasQuest then
        frame.note:SetText(questDone and L.questDone or L.noQuest)
        frame.note:Show()
        y = y - 14
    else
        frame.note:Hide()
    end

    frame.columns:ClearAllPoints()
    frame.columns:SetPoint("TOPLEFT", PAD, y)
    frame.columns:SetPoint("TOPRIGHT", -PAD, y)
    y = y - ROW_H

    for ci, chapter in ipairs(ns.CHAPTERS) do
        local header = headers[ci]
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", PAD, y)
        header:SetPoint("TOPRIGHT", -PAD, y)
        y = y - HEADER_H

        local done = questDone or ns:IsChapterDone(chapter)
        local have = 0
        for pi, page in ipairs(chapter.pages) do
            local row = rows[ci][pi]
            if done then
                row:Hide()
            else
                local status = ns:GetItemStatus(page[2])
                local c = COLORS[status.state]
                SetColor(row.page, c)
                SetColor(row.where, c)
                row.where:SetText(JoinLocations(status.locs))
                if status.total > 1 then
                    row.count:SetText("x" .. status.total)
                    SetColor(row.count, COLORS.multiple)
                else
                    row.count:SetText("")
                end
                if status.total > 0 then
                    have = have + 1
                else
                    missing[#missing + 1] = page[1]
                end
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", PAD, y)
                row:SetPoint("TOPRIGHT", -PAD, y)
                row:Show()
                y = y - ROW_H
            end
        end

        if done then
            found = found + #chapter.pages
            header.label:SetText(L.chapterDone:format(chapter.roman))
            SetColor(header.label, COLORS.done)
            header.progress:SetText(READY_ICON)
        else
            found = found + have
            header.label:SetText(L.chapter:format(chapter.roman))
            SetColor(header.label, COLORS.header)
            header.progress:SetText(have .. "/" .. #chapter.pages)
            SetColor(header.progress, have == #chapter.pages and COLORS.done or COLORS.header)
        end
    end

    frame.counter:SetText(found .. "/" .. ns.PAGE_COUNT)
    y = y - 6
    frame.footer:ClearAllPoints()
    frame.footer:SetPoint("TOPLEFT", PAD, y)
    frame.footer:SetPoint("TOPRIGHT", -PAD, y)
    if #missing > 0 then
        frame.footer:SetText(L.missingList:format(table.concat(missing, ", ")))
        SetColor(frame.footer, COLORS.missing)
    else
        frame.footer:SetText(L.allFound)
        SetColor(frame.footer, COLORS.done)
    end
    frame:SetHeight(-y + frame.footer:GetStringHeight() + PAD + 2)
end

ns.OnDataChanged = Refresh

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function SavePosition(self)
    local point, _, relPoint, x, y = self:GetPoint(1)
    ns:GetUIState().point = { point, relPoint, x, y }
end

local function CreateWindow()
    frame = CreateFrame("Frame", "StranglethornPagesFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(WIDTH)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    local pos = ns:GetUIState().point
    if pos then
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 300, 80)
    end

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -2, -2)

    frame.counter = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.counter:SetPoint("TOPRIGHT", -32, -14)

    -- Title ends left of the counter and is cut with "..." if it doesn't fit
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", PAD, -14)
    frame.title:SetPoint("RIGHT", frame.counter, "LEFT", -6, 0)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetWordWrap(false)
    frame.title:SetText(L.title)

    frame.note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.note:SetPoint("TOPLEFT", PAD, -36)
    frame.note:SetPoint("TOPRIGHT", -PAD, -36)
    frame.note:SetJustifyH("LEFT")

    -- Column captions
    local columns = CreateFrame("Frame", nil, frame)
    columns:SetHeight(ROW_H)
    local function caption(text, point, x, justify, width)
        local fs = columns:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint(point, x, 0)
        fs:SetJustifyH(justify)
        if width then fs:SetWidth(width) end
        fs:SetText(text)
    end
    caption(L.colPage, "LEFT", 8, "LEFT")
    caption(L.colWhere, "LEFT", COL_PAGE_W, "LEFT")
    caption(L.colCount, "RIGHT", -2, "RIGHT", COL_COUNT_W)
    frame.columns = columns

    for ci, chapter in ipairs(ns.CHAPTERS) do
        headers[ci] = CreateHeader(frame)
        rows[ci] = {}
        for pi, page in ipairs(chapter.pages) do
            rows[ci][pi] = CreatePageRow(frame, page[1], page[2])
        end
    end

    frame.footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.footer:SetJustifyH("LEFT")

    frame:SetScript("OnShow", function()
        ns:GetUIState().shown = true
        Refresh()
    end)
    frame:SetScript("OnHide", function() ns:GetUIState().shown = false end)
    tinsert(UISpecialFrames, frame:GetName())
    frame:Hide()
end

function ns:Toggle()
    if not frame then CreateWindow() end
    frame:SetShown(not frame:IsShown())
end

---------------------------------------------------------------------------
-- Minimap button (own small button, dragged around the minimap edge)
---------------------------------------------------------------------------
local function PlaceMinimapButton(btn)
    local angle = math.rad(ns:GetUIState().minimapAngle or 200)
    local r = Minimap:GetWidth() / 2 + 10
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

-- OnUpdate only runs while the button is being dragged
local function MinimapButton_OnDragUpdate(self)
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    ns:GetUIState().minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    PlaceMinimapButton(self)
end

local function CreateMinimapButton()
    local btn = CreateFrame("Button", "StranglethornPagesMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    icon:SetTexture(C_Item.GetItemIconByID(ns.CHAPTERS[1].pages[1][2]) or 134400)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    btn:SetScript("OnClick", function() ns:Toggle() end)
    btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", MinimapButton_OnDragUpdate) end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L.title)
        GameTooltip:AddLine(L.mmLeft, 1, 1, 1)
        GameTooltip:AddLine(L.mmDrag, 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    PlaceMinimapButton(btn)
end

---------------------------------------------------------------------------
-- Login (called by Tracker.lua after the database is ready) and /ghs
---------------------------------------------------------------------------
function ns.OnLogin()
    CreateMinimapButton()
    if ns:GetUIState().shown then ns:Toggle() end
end

SLASH_STRANGLETHORNPAGES1 = "/ghs"
SlashCmdList.STRANGLETHORNPAGES = function() ns:Toggle() end
