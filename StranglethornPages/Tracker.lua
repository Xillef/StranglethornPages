local _, ns = ...

-- Snapshots per character (account-wide SavedVariables):
--   db.chars["Name-Realm"] = { bags = {[itemID] = n}, bagsTime, bank = {...}, bankTime,
--                              mailbox = {...}, mailboxTime, quest = { has, mainDone, done = {[questID] = true} } }
--   db.sent = { { to = "Name-Realm", items = {[itemID] = n}, time } }
-- A page's status is always recomputed from all snapshots, so a page that is sold or
-- destroyed just drops out of the bag snapshot and shows as missing. Nothing polls:
-- bank and mailbox are only read while they are open.

local db, me, myKey
local bankOpen, mailOpen = false, false
local pendingSend          -- attachments of the mail being sent, until MAIL_SEND_SUCCESS/MAIL_FAILED
local sendCache = {}       -- last seen tracked attachments in the send window (fallback for the SendMail hook)

local KINDS = { "bags", "bank", "mailbox" }
local KIND_ORDER = { bags = 1, bank = 2, mailbox = 3, sent = 4 }

local function ItemIDFromLink(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- GetInboxItem/GetSendMailItem return (name, itemID, texture, count, ...) on the modern
-- client and (name, texture, count, ...) on old ones. The itemID comes from the link, and
-- the count position is picked by whether the 2nd value is that itemID. UNVERIFIED on Forever.
local function CountFromMailItem(itemID, ...)
    local second, third, fourth = select(2, ...)
    local n = (second == itemID) and fourth or third
    return tonumber(n) or 1
end

local function MailKey(name)
    if type(name) ~= "string" then return nil end
    name = strtrim(name)
    if name == "" then return nil end
    if not name:find("-", 1, true) then
        name = name .. "-" .. (GetNormalizedRealmName() or "")
    end
    return name
end

local function SameChar(a, b)
    return a ~= nil and b ~= nil and a:lower() == b:lower()
end

-- "Name" for characters on this realm, "Name-Realm" otherwise
function ns.ShortName(key)
    local name, realm = strsplit("-", key, 2)
    if realm and realm ~= "" and realm ~= GetNormalizedRealmName() then return key end
    return name
end

local function CountTracked(includeBank)
    local t = {}
    for itemID in pairs(ns.TRACKED) do
        local n = C_Item.GetItemCount(itemID, includeBank) or 0
        if n > 0 then t[itemID] = n end
    end
    return t
end

---------------------------------------------------------------------------
-- Change notification (coalesced, the UI redraws only while shown)
---------------------------------------------------------------------------
local updateQueued = false
local function QueueUpdate()
    if updateQueued then return end
    updateQueued = true
    C_Timer.After(0.2, function()
        updateQueued = false
        if ns.OnDataChanged then ns.OnDataChanged() end
    end)
end

---------------------------------------------------------------------------
-- Scans
---------------------------------------------------------------------------
local function ScanBags()
    me.bags = CountTracked(false)
    me.bagsTime = time()
    QueueUpdate()
end

-- Only valid while the bank is open: everything counted with the bank minus the bags.
-- UNVERIFIED on Forever: that includeBank covers all bank tabs.
local function ScanBank()
    if not bankOpen then return end
    local withBank = CountTracked(true)
    local bank = {}
    for itemID, n in pairs(withBank) do
        local inBank = n - (me.bags[itemID] or 0)
        if inBank > 0 then bank[itemID] = inBank end
    end
    me.bank = bank
    me.bankTime = time()
    QueueUpdate()
end

local function ScanMailbox()
    if not mailOpen or not GetInboxNumItems then return end
    local t = {}
    local maxAttach = ATTACHMENTS_MAX_RECEIVE or 16
    for i = 1, GetInboxNumItems() do
        for a = 1, maxAttach do
            local itemID = ItemIDFromLink(GetInboxItemLink(i, a))
            if itemID and ns.TRACKED[itemID] then
                t[itemID] = (t[itemID] or 0) + CountFromMailItem(itemID, GetInboxItem(i, a))
            end
        end
    end
    me.mailbox = t
    me.mailboxTime = time()
    -- Mail sent to this character is now either in this mailbox or already taken out
    for i = #db.sent, 1, -1 do
        if SameChar(db.sent[i].to, myKey) then table.remove(db.sent, i) end
    end
    QueueUpdate()
end

local function ReadSendAttachments()
    local items, any = {}, false
    if not GetSendMailItemLink then return items, any end
    for a = 1, ATTACHMENTS_MAX_SEND or 12 do
        local itemID = ItemIDFromLink(GetSendMailItemLink(a))
        if itemID and ns.TRACKED[itemID] then
            items[itemID] = (items[itemID] or 0) + CountFromMailItem(itemID, GetSendMailItem(a))
            any = true
        end
    end
    return items, any
end

local function OnSendMail(recipient)
    local items, any = ReadSendAttachments()
    if not any then items, any = sendCache, next(sendCache) ~= nil end
    local to = MailKey(recipient)
    if any and to and not SameChar(to, myKey) then
        pendingSend = { to = to, items = CopyTable(items) }
    else
        pendingSend = nil
    end
end

local function ScanQuests()
    local q = me.quest or {}
    q.done = q.done or {}
    local QL = C_QuestLog
    local function flagged(id) return QL and QL.IsQuestFlaggedCompleted and QL.IsQuestFlaggedCompleted(id) or false end
    q.mainDone = flagged(ns.MAIN_QUEST)
    if QL and QL.IsOnQuest then
        q.has = QL.IsOnQuest(ns.MAIN_QUEST) or false
    elseif QL and QL.GetLogIndexForQuestID then
        q.has = QL.GetLogIndexForQuestID(ns.MAIN_QUEST) ~= nil
    end
    for _, chapter in ipairs(ns.CHAPTERS) do
        q.done[chapter.quest] = flagged(chapter.quest) or nil
    end
    me.quest = q
    QueueUpdate()
end

---------------------------------------------------------------------------
-- Queries for the UI
---------------------------------------------------------------------------

-- All places an item is known to be, plus totals.
-- state: "missing" | "have" (this character's bags) | "elsewhere" | "multiple"
function ns:GetItemStatus(itemID)
    local locs, total, mine = {}, 0, 0
    if not db then return { state = "missing", total = 0, mine = 0, locs = locs } end
    for key, c in pairs(db.chars) do
        local own = (key == myKey)
        for _, kind in ipairs(KINDS) do
            local n = c[kind] and c[kind][itemID]
            if n and n > 0 then
                locs[#locs + 1] = { kind = kind, char = key, own = own, count = n, time = c[kind .. "Time"] }
                total = total + n
                if own and kind == "bags" then mine = n end
            end
        end
    end
    -- Mail sent away only counts while no copy is left anywhere else: a spare copy
    -- mailed off (e.g. to be sold) while one is still in bags/bank isn't shown.
    if total == 0 then
        for _, s in ipairs(db.sent) do
            local n = s.items[itemID]
            if n and n > 0 then
                locs[#locs + 1] = { kind = "sent", char = s.to, own = false, count = n, time = s.time }
                total = total + n
            end
        end
    end
    table.sort(locs, function(a, b)
        if a.own ~= b.own then return a.own end
        if a.kind ~= b.kind then return KIND_ORDER[a.kind] < KIND_ORDER[b.kind] end
        return a.char < b.char
    end)
    local state
    if total == 0 then state = "missing"
    elseif total > 1 then state = "multiple"
    elseif mine > 0 then state = "have"
    else state = "elsewhere" end
    return { state = state, total = total, mine = mine, locs = locs }
end

-- A chapter counts as done once its quest is turned in or its chapter item exists anywhere
function ns:IsChapterDone(chapter)
    local q = me and me.quest
    if q and (q.mainDone or q.done[chapter.quest]) then return true end
    return self:GetItemStatus(chapter.item).total > 0
end

function ns:GetQuestState()
    local q = me and me.quest or {}
    return q.has or false, q.mainDone or false
end

-- True only while a "Mail to X" location is actually shown for this item
function ns:HasSentEntries(itemID)
    for _, loc in ipairs(self:GetItemStatus(itemID).locs) do
        if loc.kind == "sent" then return true end
    end
    return false
end

function ns:ForgetSent(itemID)
    for i = #db.sent, 1, -1 do
        local s = db.sent[i]
        s.items[itemID] = nil
        if next(s.items) == nil then table.remove(db.sent, i) end
    end
    QueueUpdate()
end

function ns:GetUIState() return db.ui end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ADDON_NAME = ...
local frame = CreateFrame("Frame")
local handlers = {}

function handlers.ADDON_LOADED(name)
    if name ~= ADDON_NAME then return end
    frame:UnregisterEvent("ADDON_LOADED")
    StranglethornPagesDB = StranglethornPagesDB or {}
    db = StranglethornPagesDB
    db.version = 1
    db.chars = db.chars or {}
    db.sent = db.sent or {}
    db.ui = db.ui or {}
end

function handlers.PLAYER_LOGIN()
    myKey = UnitName("player") .. "-" .. (GetNormalizedRealmName() or "")
    db.chars[myKey] = db.chars[myKey] or {}
    me = db.chars[myKey]
    me.bags = me.bags or {}
    ScanBags()
    ScanQuests()

    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:RegisterEvent("BANKFRAME_OPENED")
    frame:RegisterEvent("BANKFRAME_CLOSED")
    frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    frame:RegisterEvent("MAIL_SHOW")
    frame:RegisterEvent("MAIL_CLOSED")
    frame:RegisterEvent("MAIL_INBOX_UPDATE")
    frame:RegisterEvent("MAIL_SEND_INFO_UPDATE")
    frame:RegisterEvent("MAIL_SEND_SUCCESS")
    frame:RegisterEvent("MAIL_FAILED")
    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:RegisterEvent("QUEST_TURNED_IN")
    if type(SendMail) == "function" then
        hooksecurefunc("SendMail", OnSendMail)
    end
    if ns.OnLogin then ns.OnLogin() end
end

function handlers.BAG_UPDATE_DELAYED()
    ScanBags()
    if bankOpen then ScanBank() end
end

function handlers.BANKFRAME_OPENED()
    bankOpen = true
    ScanBags()
    ScanBank()
end

function handlers.BANKFRAME_CLOSED() bankOpen = false end
handlers.PLAYERBANKSLOTS_CHANGED = ScanBank

function handlers.MAIL_SHOW() mailOpen = true end
function handlers.MAIL_CLOSED()
    mailOpen = false
    wipe(sendCache)
end
handlers.MAIL_INBOX_UPDATE = ScanMailbox

function handlers.MAIL_SEND_INFO_UPDATE()
    local items = ReadSendAttachments()
    sendCache = items
end

function handlers.MAIL_SEND_SUCCESS()
    if pendingSend then
        pendingSend.time = time()
        table.insert(db.sent, pendingSend)
        pendingSend = nil
        QueueUpdate()
    end
    wipe(sendCache)
end

function handlers.MAIL_FAILED() pendingSend = nil end

-- QUEST_LOG_UPDATE fires often; ScanQuests is a handful of flag lookups and the
-- redraw is coalesced, so no extra throttle here.
handlers.QUEST_LOG_UPDATE = ScanQuests
handlers.QUEST_TURNED_IN = ScanQuests

frame:SetScript("OnEvent", function(_, event, ...)
    local fn = handlers[event]
    if fn then fn(...) end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
