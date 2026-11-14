local _, ns = ...

-- Colors of the page rows (r, g, b, 0..1). Change them here; nothing else
-- in the addon hard-codes a status color.
ns.COLORS = {
    missing   = { 0.55, 0.55, 0.55 }, -- nowhere on the account
    have      = { 0.10, 0.60, 0.10 }, -- exactly one copy, in this character's bags (counts for the quest)
    elsewhere = { 1.00, 0.82, 0.00 }, -- bank, mailbox, mailed away, or on another character
    multiple  = { 0.25, 0.90, 0.25 }, -- more than one copy in total
    done      = { 0.25, 0.90, 0.25 }, -- chapter already put together / turned in
    header    = { 1.00, 0.82, 0.00 },
    dim       = { 0.60, 0.60, 0.60 },
}

ns.MAIN_QUEST = 338 -- The Green Hills of Stranglethorn (Barnil Stonepot, NPC 716)

-- Chapter quests, the chapter item each one rewards, and the pages it needs
-- as { page number, itemID }. Source: Wowhead Classic quests 338-342.
ns.CHAPTERS = {
    { quest = 339, item = 2756, roman = "I",   pages = { { 1, 2725 }, { 4, 2728 }, { 6, 2730 }, { 8, 2732 } } },
    { quest = 340, item = 2757, roman = "II",  pages = { { 10, 2734 }, { 11, 2735 }, { 14, 2738 }, { 16, 2740 } } },
    { quest = 341, item = 2758, roman = "III", pages = { { 18, 2742 }, { 20, 2744 }, { 21, 2745 }, { 24, 2748 } } },
    { quest = 342, item = 2759, roman = "IV",  pages = { { 25, 2749 }, { 26, 2750 }, { 27, 2751 } } },
}

-- Every tracked itemID (pages and chapter items) -> true
ns.TRACKED = {}
ns.PAGE_COUNT = 0
for _, chapter in ipairs(ns.CHAPTERS) do
    ns.TRACKED[chapter.item] = true
    for _, page in ipairs(chapter.pages) do
        ns.TRACKED[page[2]] = true
        ns.PAGE_COUNT = ns.PAGE_COUNT + 1
    end
end

local L = {
    title        = "Green Hills of Stranglethorn",
    chapter      = "Chapter %s",
    chapterDone  = "Chapter %s - done",
    page         = "Page %d",
    noQuest      = "This character doesn't have the quest.",
    questDone    = "Quest completed.",
    missingList  = "Missing: %s",
    allFound     = "All pages found.",
    bags         = "Bags",
    bank         = "Bank",
    mailbox      = "Mailbox",
    bagsOf       = "Bags of %s",
    bankOf       = "Bank of %s",
    mailboxOf    = "Mailbox of %s",
    sentTo       = "Mail to %s",
    nowhere      = "-",
    colPage      = "Page",
    colWhere     = "Where",
    colCount     = "Count",
    ttWhere      = "Where:",
    ttScanned    = "%s (seen %s ago)",
    ttRemoveSent = "Right-click: forget the mail entries",
    removedSent  = "Mail entries for %s forgotten.",
    mmLeft       = "Left-click: show/hide",
    mmDrag       = "Drag: move button",
    minutes      = "%d min",
    hours        = "%d h",
    days         = "%d d",
}

if GetLocale() == "deDE" then
    L.title        = "Grüne Hügel des Schlingendorntals"
    L.chapter      = "Kapitel %s"
    L.chapterDone  = "Kapitel %s - fertig"
    L.page         = "Seite %d"
    L.noQuest      = "Dieser Charakter hat die Quest nicht."
    L.questDone    = "Quest abgeschlossen."
    L.missingList  = "Fehlt: %s"
    L.allFound     = "Alle Seiten beisammen."
    L.bags         = "Taschen"
    L.bank         = "Bank"
    L.mailbox      = "Briefkasten"
    L.bagsOf       = "Taschen von %s"
    L.bankOf       = "Bank von %s"
    L.mailboxOf    = "Briefkasten von %s"
    L.sentTo       = "Post an %s"
    L.colPage      = "Seite"
    L.colWhere     = "Ort"
    L.colCount     = "Anzahl"
    L.ttWhere      = "Wo:"
    L.ttScanned    = "%s (gesehen vor %s)"
    L.ttRemoveSent = "Rechtsklick: Post-Einträge vergessen"
    L.removedSent  = "Post-Einträge für %s vergessen."
    L.mmLeft       = "Linksklick: ein-/ausblenden"
    L.mmDrag       = "Ziehen: Button verschieben"
    L.minutes      = "%d Min."
    L.hours        = "%d Std."
    L.days         = "%d T."
end

ns.L = L
