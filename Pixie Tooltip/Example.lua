--[[ Pixie Tooltip - Examples
     Description: Every example below is a separate, self-contained section: a build function plus the way it
                  is opened. They follow the three levels of DOCUMENTATION.md: Simple, Advanced, Expert.

     In game:
         Esc -> Options -> AddOns -> Pixie Tooltip  -> the list of the examples; hover a line to open it
         /ptt                   -> opens that list
         /ptt <number>          -> opens that example at the mouse cursor (anchor = nil), e.g. /ptt 3
         /ptt close             -> closes every tooltip of the examples
         Line 15 of the list    -> PixieTooltip:Attach on that line ]]

local addonName, private = ...
local PixieTooltip = private.PixieTooltip
local CELL, ROW = PixieTooltip.CELL, PixieTooltip.ROW

--==============================================================================
-- SetDefaults: every setting with its built-in value
-- An addon calls this once, at the top, with only the keys it wants to change. Here every key is listed
-- with its built-in value, so this call changes nothing; edit a value to see its effect on every example.
-- Every key is optional. Open's options override these; key, refresh and onClose belong to Open only.
--==============================================================================

PixieTooltip:SetDefaults({

    ---- Behavior ---------------------------------------------------------------

    -- true: tooltips do not open in combat. false: they open in combat too.
    -- Open's 4th parameter overrides it.
    noCombat = true,

    -- Seconds the mouse may be off the tooltip and its anchor before it closes. The countdown
    -- starts only after the mouse has been over one of them. false: stays open until Close.
    autoHide = 0.1,

    -- nil: automatic (as many columns as the widest row; first LEFT, the rest RIGHT).
    -- A number: that many columns, empty ones kept. A list: { "LEFT", "CENTER", "RIGHT" }.
    -- Open's 3rd parameter overrides it.
    columns = nil,

    ---- Position ---------------------------------------------------------------

    anchor = {
        point  = nil,          -- "TOP", "BOTTOM", "LEFT", "RIGHT", "TOPLEFT", ...; nil: towards the screen middle
        gap    = 0,            -- pixels between the anchor and the tooltip
        cursor = { 10, -10 },  -- offset from the mouse cursor when there is no anchor
    },

    hint = {                   -- the GameTooltip of OnHover
        side = nil,            -- "LEFT" or "RIGHT" of the tooltip; nil: the side with more room
        gap  = 0,              -- pixels between the tooltip and the hint
    },

    ---- Size -------------------------------------------------------------------

    minWidth  = nil,           -- pixels; nil: none
    maxWidth  = nil,           -- pixels; nil: 40% of the screen; false: no limit
    maxHeight = nil,           -- pixels; nil: 80% of the screen. Above it the body scrolls.

    ---- Frame ------------------------------------------------------------------

    scale      = 1,            -- size of the tooltip
    strata     = "TOOLTIP",    -- frame strata
    border     = nil,          -- border color; nil: native
    background = nil,          -- background color or image; nil: native

    ---- Spacing (pixels) -------------------------------------------------------

    padding    = 10,           -- between the border and the content
    columnGap  = 12,           -- between two columns
    rowSpacing = 2,            -- below every row
    sectionGap = 4,            -- between header, body and footer

    ---- Parts ------------------------------------------------------------------
    -- Each value works as if the matching Set... command were the first line of the build function.
    --   font        font: a font object, its name, { file, size, flags } or a full table
    --               { base, file, size, flags, color, shadow, spacing }
    --   color       text color
    --   align       { "LEFT", "RIGHT", ... } per column, or one value for column 1
    --   valign      "TOP", "MIDDLE" or "BOTTOM", or one per column
    --   wrap        pixels: one number for every column, or a list per column ({ nil, 250 })
    --   background  color or image behind the part (header and footer)

    header = { font = GameTooltipHeaderText },                  -- top, fixed, always there
    body   = { font = GameTooltipText },                        -- middle (tip), scrolls
    footer = { enabled = false, font = GameFontDisableSmall },  -- bottom, fixed; enabled = true to use it

    ---- Row parts --------------------------------------------------------------

    highlight = { fill = nil, alpha = 0.6 },      -- under the mouse on clickable rows; nil fill: quest-log glow
    bar       = { fill = "00cc00", alpha = 0.6 }, -- SetBar without a fill
    separator = { color = nil, size = 1 },        -- AddSeparator() without arguments; nil color: a gap
    image     = { size = 32, align = "CENTER" },  -- AddImage without a size or alignment

    ---- Scrolling --------------------------------------------------------------

    wheelStep = 40,            -- pixels per mouse wheel step

    ---- Panel ------------------------------------------------------------------
    -- With autoHide = false a tooltip stays open and works as a small panel (example 24).

    movable     = false,       -- true: drag it with the left mouse button
    closeButton = false,       -- true: Blizzard close button (X) in the top right corner
    escape      = false,       -- true: Esc closes it, like Blizzard windows
})

-- index -> { level, title, build, columns, noCombat, options }: opened as
-- PixieTooltip:Open(anchor, build, columns, noCombat, options)
local examples = {}

local LEVELS = { "Simple", "Advanced", "Expert" }

local FOOTER_ON = { footer = { enabled = true } }

--==============================================================================
-- Level 1 - Simple
--==============================================================================

--------------------------------------------------------------------------------
-- Example 1: Automatic columns - PixieTooltip:Open(anchor, Build)
--------------------------------------------------------------------------------

local function BuildSimple(tip, header)
    header:AddRow("My Addon", "1.0")
    header:AddSeparator("ffcc00", 1)
    tip:AddRow("Gold", GetMoneyString(GetMoney(), true))
    tip:AddRow("Level", UnitLevel("player"))
    tip:AddRow("Zone", GetZoneText())
end

examples[1] = { level = 1, title = "Automatic columns", build = BuildSimple }

--------------------------------------------------------------------------------
-- Example 2: A column count - PixieTooltip:Open(anchor, Build, 4)
--------------------------------------------------------------------------------

local characters = {
    { name = "Pixie", level = 80, gold = "1234g", week = "+56g" },
    { name = "Tanky", level = 80, gold = "234g", week = "+12g" },
    { name = "Healz", level = 72, gold = "34g" },                    -- no weekly value
}

local function BuildColumns(tip, header)
    header:AddRow("Characters", nil, nil, date("%H:%M"))
    header:AddSeparator("ffcc00", 1)
    tip:AddRow("Name", "Level", "Gold", "Week")
    for _, char in ipairs(characters) do
        tip:AddRow(char.name, char.level, char.gold, char.week)    -- Healz: column 4 stays empty
    end
end

examples[2] = { level = 1, title = "Four columns", build = BuildColumns, columns = 4 }

--------------------------------------------------------------------------------
-- Example 3: Merged cells (CELL and ROW)
--------------------------------------------------------------------------------

local function BuildMerge(tip, header)
    header:AddRow({ "Merged cells", ROW })
    tip:AddRow({ "Character", CELL, "CENTER" }, { "Gold", CELL, "CENTER" })   -- 1-2 | 3-4
    tip:AddRow("Name", "Level", "Now", "Week")
    tip:AddRow("Pixie", 80, "1234g", "56g")
    tip:AddRow({ "Total (columns 1-3)", CELL, CELL, "RIGHT" }, "56g")          -- 1-3 | 4
    tip:AddRow("A", { "Columns 2-4 (ROW)", ROW, "CENTER" })                    -- 1 | 2-4
    tip:AddRow({ "Whole row", ROW, "CENTER" })                                 -- 1-4
end

examples[3] = { level = 1, title = "Merged cells", build = BuildMerge, columns = 4 }

--------------------------------------------------------------------------------
-- Example 4: Lines and gaps
--------------------------------------------------------------------------------

local function BuildLines(tip, header)
    header:AddRow({ "Lines and gaps", ROW })
    tip:AddSeparator("ffcc00", 1)               -- gold line, 1 px
    tip:AddRow("After a gold 1 px line")
    tip:AddSeparator("ffffff", 2)               -- white line, 2 px
    tip:AddRow("After a white 2 px line")
    tip:AddSeparator(nil, 12)                   -- no color: 12 px gap
    tip:AddRow("After a 12 px gap")
end

examples[4] = { level = 1, title = "Lines and gaps", build = BuildLines }

--------------------------------------------------------------------------------
-- Example 5: Click
--------------------------------------------------------------------------------

local settings = { autoSell = true, autoRepair = false }

local function OnOff(value)
    return value and "|cff00ff00On|r" or "|cffff4040Off|r"
end

local function BuildClick(tip, header)
    header:AddRow({ "Settings", ROW })
    header:AddSeparator("ffcc00", 1)
    tip:AddRow("Auto sell junk", OnOff(settings.autoSell))
        :OnClick(function(t)
            settings.autoSell = not settings.autoSell
            t:Refresh()
        end)
    tip:AddRow("Auto repair", OnOff(settings.autoRepair))
        :OnClick(function(t)
            settings.autoRepair = not settings.autoRepair
            t:Refresh()
        end)
    tip:AddRow({ "Print the mouse button", ROW })
        :OnClick(function(t, button)
            print(addonName .. ": " .. tostring(button))
        end)
end

examples[5] = { level = 1, title = "Click", build = BuildClick }

--------------------------------------------------------------------------------
-- Example 6: Mouse wheel
--------------------------------------------------------------------------------

local volumes = { Master = 80, Music = 40, Effects = 100 }
local VOLUME_ORDER = { "Master", "Music", "Effects" }

local function BuildWheel(tip, header)
    header:AddRow({ "Volume (wheel over a row)", ROW })
    header:AddSeparator("ffcc00", 1)
    for _, name in ipairs(VOLUME_ORDER) do
        tip:AddRow(name, volumes[name] .. "%")
            :OnWheel(function(t, delta)
                volumes[name] = math.max(0, math.min(100, volumes[name] + delta * 5))
                t:Refresh()
            end)
    end
end

examples[6] = { level = 1, title = "Mouse wheel", build = BuildWheel }

--------------------------------------------------------------------------------
-- Example 7: Hover hints (link and text)
--------------------------------------------------------------------------------

local HEARTHSTONE_ITEM_ID = 6948

local function BuildHint(tip, header)
    header:AddRow({ "Hover hints", ROW })
    header:AddSeparator("ffcc00", 1)
    tip:AddRow("Short link", "hover"):OnHover("item:" .. HEARTHSTONE_ITEM_ID)
    local _, link = C_Item.GetItemInfo(HEARTHSTONE_ITEM_ID)
    tip:AddRow("Full link", link and "hover" or "not cached yet"):OnHover(link)
    tip:AddRow("Text", "hover"):OnHover("Left click: nothing happens.\nThis is a plain text hint.")
end

examples[7] = { level = 1, title = "Hover hints", build = BuildHint }

--==============================================================================
-- Level 2 - Advanced
--==============================================================================

--------------------------------------------------------------------------------
-- Example 8: Footer - switched on in the Open options
--------------------------------------------------------------------------------

local function BuildFooter(tip, header, footer)
    header:AddRow({ "Footer", ROW })
    header:AddSeparator("ffcc00", 1)
    tip:AddRow("The footer is switched on with")
    tip:AddRow("{ footer = { enabled = true } }")
    footer:AddSeparator("ffcc00", 1)
    footer:AddRow({ "Footer: small grey font, fixed at the bottom", ROW, "CENTER" })
end

examples[8] = { level = 2, title = "Footer", build = BuildFooter, options = FOOTER_ON }

--------------------------------------------------------------------------------
-- Example 9: Look of rows and parts
--------------------------------------------------------------------------------

local function BuildLook(tip, header)
    header:AddRow({ "Look", ROW })
    header:SetBackground({ 1, 1, 1, 0.05 })                       -- strip behind the header
    tip:AddRow("Name", "Value"):SetColor("ffffff"):SetBackground({ 1, 1, 1, 0.08 })
    tip:AddRow("Row color", "blue"):SetColor("80c0ff")
    tip:AddRow("Background", "cyan"):SetBackground({ 0, 0.6, 1, 0.2 })
    tip:AddRow("Title font", "row"):SetFont(GameTooltipHeaderText)
    tip:AddRow("Centered", "left"):SetAlign("CENTER", "LEFT")
    tip:AddRow("Progress", "65%"):SetBar(65, 100, "ffcc00")
    tip:SetFont(GameFontNormalSmall)                              -- every row after this is small
    tip:AddRow("Small font", "1")
    tip:AddRow("Small font", "2")
    tip:SetFont(nil)                                              -- back to the normal font
    tip:AddRow("Normal again", "3")
end

examples[9] = { level = 2, title = "Look of rows and parts", build = BuildLook }

--------------------------------------------------------------------------------
-- Example 10: Bags - progress bars, footer click, live update from events
--------------------------------------------------------------------------------

-- Classic clients may still use the old global names.
local GetBagName = C_Container.GetBagName or GetBagName
local ContainerIDToInventoryID = C_Container.ContainerIDToInventoryID or ContainerIDToInventoryID

local BACKPACK_ICON = "Interface\\Buttons\\Button-Backpack-Up"
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS   -- includes the reagent bag on Retail

local function GetBagIcon(bag)
    if bag == 0 then
        return BACKPACK_ICON
    end
    return GetInventoryItemTexture("player", ContainerIDToInventoryID(bag))
end

-- Green, yellow, red as the bag fills up.
local function GetFillColor(used, total)
    local ratio = used / total
    if ratio >= 0.9 then
        return "ff4040"
    elseif ratio >= 0.7 then
        return "ffcc00"
    end
    return "40ff40"
end

local function BuildBags(tip, header, footer)
    header:AddRow({ "Bags", ROW })

    tip:AddRow("Bag", "Free", "Slots"):SetColor("ffffff")
    tip:AddSeparator("808080", 1)

    local totalFree, totalSlots = 0, 0
    for bag = 0, LAST_BAG do
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots > 0 then
            local free = C_Container.GetContainerNumFreeSlots(bag)
            local used = slots - free
            local icon = GetBagIcon(bag)
            local name = GetBagName(bag) or ("Bag " .. bag)
            if icon then
                name = "|T" .. icon .. ":16|t " .. name
            end
            totalFree, totalSlots = totalFree + free, totalSlots + slots
            tip:AddRow(name, free, slots):SetBar(used, slots, GetFillColor(used, slots))
        end
    end

    tip:AddSeparator("808080", 1)
    tip:AddRow("Total", totalFree, totalSlots):SetColor("ffffff")
    tip:AddSeparator(nil, 6)
    tip:AddRow("Gold", { GetMoneyString(GetMoney(), true), ROW })

    footer:AddRow({ "Click here: open all bags", ROW })
        :OnClick(function() ToggleAllBags() end)
end

examples[10] = { level = 2, title = "Bags (bars, events)", build = BuildBags, columns = 3, options = FOOTER_ON }

-- Keep it live while it is open; Refresh does nothing when it is closed.
local bagEvents = CreateFrame("Frame")
bagEvents:RegisterEvent("BAG_UPDATE_DELAYED")
bagEvents:RegisterEvent("PLAYER_MONEY")
bagEvents:SetScript("OnEvent", function()
    PixieTooltip:Refresh()
end)

--------------------------------------------------------------------------------
-- Example 11: Images
--------------------------------------------------------------------------------

local function BuildImages(tip, header)
    header:AddRow({ "Images", ROW })
    header:AddSeparator("ffcc00", 1)
    tip:AddImage("Interface\\Icons\\INV_Misc_QuestionMark", 48, 48)        -- file path, centered
    tip:AddImage(134400, 32, 32, "LEFT")                                   -- fileID, left
    tip:AddImage("common-icon-checkmark", 24, 24, "RIGHT")                 -- atlas name, right
    tip:AddImage(134414)                                                   -- the image default: 32, centered
    tip:AddSeparator(nil, 4)
    tip:AddRow("|T134414:16|t Inline icon in a cell", "|T134400:16|t")
end

examples[11] = { level = 2, title = "Images", build = BuildImages }

--------------------------------------------------------------------------------
-- Example 12: Live update - refresh option and own key
--------------------------------------------------------------------------------

local function BuildLive(tip, header)
    header:AddRow({ "Live (refresh = 1)", ROW })
    header:AddSeparator("ffcc00", 1)
    tip:AddRow("Time", date("%H:%M:%S"))
    tip:AddRow("FPS", math.floor(GetFramerate()))
end

examples[12] = { level = 2, title = "Live update", build = BuildLive, options = { key = "live", refresh = 1 } }

--------------------------------------------------------------------------------
-- Example 13: Pinned tooltip (autoHide = false) with a close row
--------------------------------------------------------------------------------

local function BuildPinned(tip, header)
    header:AddRow("Pinned")
    tip:AddRow("It stays open when the mouse leaves.")
    tip:AddRow("Close"):SetColor("ffcc00"):OnClick(function(t) t:Close() end)
end

examples[13] = { level = 2, title = "Pinned (autoHide = false)", build = BuildPinned, options = { autoHide = false } }

--------------------------------------------------------------------------------
-- Example 14: Own key, strata, border and background (Open options), in combat too
--------------------------------------------------------------------------------

local function BuildFrame(tip, header)
    header:AddRow("Second tooltip")
    tip:AddRow("key = \"second\", strata FULLSCREEN")
    tip:AddRow("Own border and background, opens in combat")
    tip:AddRow("Close"):SetColor("ffcc00"):OnClick(function(t) t:Close() end)
end

examples[14] = {
    level = 2,
    title = "Own key, strata, border",
    build = BuildFrame,
    noCombat = false,
    options = {
        key = "second",
        autoHide = false,
        strata = "FULLSCREEN",
        border = "ffcc00",
        background = { 0.15, 0.05, 0.05, 0.95 },
    },
}

--------------------------------------------------------------------------------
-- Example 15: Attach to a frame (opens on mouseover, no OnEnter code needed)
--------------------------------------------------------------------------------

local function BuildAttach(tip, header)
    header:AddRow("Attached")
    tip:AddRow("Opened by PixieTooltip:Attach")
    tip:AddRow("on line 15 of the example list")
end

-- The list on the Settings panel (bottom of this file) attaches this to line 15.
local ATTACH_OPTIONS = { autoHide = 0.3 }

examples[15] = { level = 2, title = "Attach (on this line)", build = BuildAttach, options = ATTACH_OPTIONS }

--------------------------------------------------------------------------------
-- Example 16: Long list - the body scrolls, header and footer stay
--------------------------------------------------------------------------------

local function BuildLongList(tip, header, footer)
    header:AddRow("80 rows", "Value")
    header:AddSeparator("ffcc00", 1)
    for index = 1, 80 do
        local row = tip:AddRow("Row " .. index, index * 7)
        if index % 2 == 0 then row:SetBackground({ 1, 1, 1, 0.04 }) end
    end
    footer:AddSeparator("ffcc00", 1)
    footer:AddRow({ "Header and footer do not scroll", ROW, "CENTER" })
end

examples[16] = {
    level = 2,
    title = "Long list (scrolling)",
    build = BuildLongList,
    options = { maxHeight = 300, footer = { enabled = true } },
}

--------------------------------------------------------------------------------
-- Example 17: Size and scale - maxWidth wraps the widest column
--------------------------------------------------------------------------------

local function BuildSize(tip, header)
    header:AddRow({ "maxWidth = 250, scale = 0.9", ROW })
    header:AddSeparator("ffcc00", 1)
    tip:AddRow("Short", "value")
    tip:AddRow("Long", "This sentence is far too long for 250 pixels, so its column wraps instead of widening the tooltip.")
end

examples[17] = { level = 2, title = "Size (maxWidth, scale)", build = BuildSize, options = { maxWidth = 250, scale = 0.9 } }

--==============================================================================
-- Level 3 - Expert
--==============================================================================

--------------------------------------------------------------------------------
-- Example 18: Masks - areas of backgrounds, bars and colors
--------------------------------------------------------------------------------

local BLUE = { 0, 0.6, 1, 0.3 }
local STATUSBAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

local function BuildMasks(tip, header)
    header:AddRow("Masks", "1", "2", "3", "4")
    header:AddSeparator("ffcc00", 1)

    -- true starts an area, CELL extends it, ROW runs it to the end.
    tip:AddRow("No mask", "a", "b", "c", "d"):SetBackground(BLUE)
    tip:AddRow("true, CELL", "a", "b", "c", "d"):SetBackground(BLUE, false, true, CELL)
    tip:AddRow("true, true", "a", "b", "c", "d"):SetBackground(BLUE, false, true, true)
    tip:AddRow("true, ROW", "a", "b", "c", "d"):SetBackground(BLUE, false, true, ROW)
    tip:AddSeparator(nil, 6)

    tip:AddRow("Bar, row", nil, nil, nil, "85%"):SetBar(85, 100)                 -- bar default color
    tip:AddRow("Bar 2-5", { "4500 / 9000", ROW }):SetBar(4500, 9000, "ffcc00", false, true, ROW)
    tip:AddRow("Texture bar", { "60%", ROW }):SetBar(60, 100, STATUSBAR_TEXTURE, false, true, ROW)
    tip:AddSeparator(nil, 6)

    tip:AddRow("Colors", "red", "green", "red", "green")
        :SetColor("ff4040", false, true, false, true)
        :SetColor("40ff40", false, false, true, false, true)
end

examples[18] = { level = 3, title = "Masks", build = BuildMasks, columns = 5 }

--------------------------------------------------------------------------------
-- Example 19: Per-cell clicks, highlight, wrap, valign, function hint
--------------------------------------------------------------------------------

local function BuildCells(tip, header, footer)
    header:AddRow({ "Cells", ROW })
    header:AddSeparator("ffcc00", 1)

    tip:AddRow("Click a cell", "A", "B", "C", "D")
        :OnClick(function() print(addonName .. ": A") end, false, true)
        :OnClick(function() print(addonName .. ": B") end, false, false, true)
        :OnClick(function() print(addonName .. ": C or D") end, false, false, false, true, CELL)
    tip:AddRow("Highlight 2-3", "a", "b", "c", "d"):SetHighlight("40ffffff", false, true, CELL)
    tip:AddSeparator(nil, 6)

    tip:AddRow("Wrap + TOP", { "A long text that wraps at 160 pixels, so this row grows taller.", ROW, "LEFT" })
        :SetWrap(160, false, true)
        :SetValign("TOP")
    tip:AddRow("Function hint", { "hover", ROW })
        :OnHover(function(gameTooltip)
            gameTooltip:SetItemByID(HEARTHSTONE_ITEM_ID)
            gameTooltip:AddLine("Added by the hint function", 0, 1, 0)
        end)

    footer:AddRow({ "Hover and click the rows above", ROW, "CENTER" })
end

examples[19] = { level = 3, title = "Cells: clicks, wrap, hints", build = BuildCells, columns = 5, options = FOOTER_ON }

--------------------------------------------------------------------------------
-- Example 20: Fonts - the four forms
--------------------------------------------------------------------------------

local function BuildFonts(tip, header)
    header:AddRow({ "Fonts", ROW })
    header:AddSeparator("ffcc00", 1)
    tip:AddRow("Font object"):SetFont(GameFontNormalSmall)
    tip:AddRow("Font name"):SetFont("GameFontHighlightLarge")
    tip:AddRow("Short table: file, size, flags"):SetFont({ "Fonts\\FRIZQT__.TTF", 14, "OUTLINE" })
    tip:AddRow("Full table: only the size"):SetFont({ size = 10 })
    tip:AddRow("Full table: color, outline"):SetFont({ size = 13, flags = "OUTLINE", color = "ffcc00" })
    tip:AddRow("Full table: no shadow"):SetFont({ shadow = false })
    tip:AddRow("Full table: red shadow"):SetFont({ shadow = { color = "ff0000", x = 2, y = -2 } })
    tip:AddRow("SetColor beats the font color"):SetFont({ color = "ffcc00" }):SetColor("40ff40")
end

examples[20] = { level = 3, title = "Fonts", build = BuildFonts }

--------------------------------------------------------------------------------
-- Example 21: Position and spacing - anchor, hint, padding, gaps
--------------------------------------------------------------------------------

local function BuildPosition(tip, header)
    header:AddRow({ "Position and spacing", ROW })
    tip:AddRow("anchor", "BOTTOM, gap 6")
    tip:AddRow("hint", "LEFT, gap 4"):OnHover("Always on the left, 4 px away.")
    tip:AddRow("padding", "16")
    tip:AddRow("columnGap", "30")
    tip:AddRow("rowSpacing", "6")
end

examples[21] = {
    level = 3,
    title = "Position and spacing",
    build = BuildPosition,
    options = {
        key = "position",
        anchor = { point = "BOTTOM", gap = 6 },
        hint = { side = "LEFT", gap = 4 },
        padding = 16,
        columnGap = 30,
        rowSpacing = 6,
    },
}

--------------------------------------------------------------------------------
-- Example 22: Everything combined (a dashboard-like tooltip)
--------------------------------------------------------------------------------

local dashboard = {
    showDetails = true,
    showLog = false,
    volume = 70,
    channels = {
        { name = "Master", enabled = true },
        { name = "Music", enabled = false },
        { name = "Effects", enabled = true },
    },
    alts = {
        { name = "Pixie", level = 80, class = "MAGE", gold = 1234, week = 56 },
        { name = "Tanky", level = 80, class = "WARRIOR", gold = 234, week = 12 },
        { name = "Healz", level = 72, class = "PRIEST", gold = 34, week = 3 },
    },
}

local function BuildCombined(tip, header, footer)
    -- Header with a live clock in the last column (refresh = 1); it stays while the body scrolls.
    header:AddRow("Pixie Dashboard", nil, nil, date("%H:%M:%S"))
    header:AddSeparator("ffcc00", 1)

    -- Part 1: merged group header + table with class colors, weekly bars and a total
    tip:AddRow({ "Characters", CELL, "CENTER" }, { "Gold", CELL, "CENTER" }):SetColor("ffcc00")
    tip:AddRow("Name", "Level", "Now", "Week"):SetColor("ffffff"):SetBackground({ 1, 1, 1, 0.08 })
    local total, week = 0, 0
    for index, alt in ipairs(dashboard.alts) do
        local row = tip:AddRow(alt.name, alt.level, alt.gold .. "g", "+" .. alt.week .. "g")
            :SetColor(RAID_CLASS_COLORS[alt.class], true)
            :SetColor("00ff00", false, false, false, true)
            :SetBar(alt.week, 60, "00ff00", false, false, false, true)
        if index % 2 == 0 then row:SetBackground({ 1, 1, 1, 0.04 }) end
        total, week = total + alt.gold, week + alt.week
    end
    tip:AddSeparator({ 0.5, 0.5, 0.5, 1 }, 1)
    tip:AddRow({ "Total", CELL, "RIGHT" }, total .. "g", "+" .. week .. "g"):SetColor("ffcc00")

    tip:AddSeparator(nil, 6)

    -- Part 2: clickable toggles and a wheel-controlled value
    tip:AddRow({ "Sound", ROW }):SetColor(NORMAL_FONT_COLOR)
    for _, channel in ipairs(dashboard.channels) do
        tip:AddRow("  " .. channel.name, nil, nil, OnOff(channel.enabled))
            :OnClick(function(t)
                channel.enabled = not channel.enabled
                t:Refresh()
            end)
    end
    tip:AddRow("  Volume", nil, nil, dashboard.volume .. "%")
        :SetBar(dashboard.volume, 100, "ffcc00", false, true, ROW)
        :OnWheel(function(t, delta)
            dashboard.volume = math.max(0, math.min(100, dashboard.volume + delta * 5))
            t:Refresh()
        end)

    tip:AddSeparator(nil, 6)

    -- Part 3: hover hint with an inline icon
    tip:AddRow({ "Items", ROW }):SetColor(NORMAL_FONT_COLOR)
    tip:AddRow("  |T134414:16|t Hearthstone", nil, nil, "hover")
        :OnHover("item:" .. HEARTHSTONE_ITEM_ID)

    -- Part 4: collapsible parts (click the title to open/close)
    tip:AddSeparator(nil, 6)
    tip:AddRow({ (dashboard.showDetails and "[-] " or "[+] ") .. "Details", ROW }):SetColor(NORMAL_FONT_COLOR)
        :OnClick(function(t)
            dashboard.showDetails = not dashboard.showDetails
            t:Refresh()
        end)
    if dashboard.showDetails then
        tip:SetFont(GameFontNormalSmall)
        tip:AddRow("  Zone", { GetZoneText(), ROW, "RIGHT" })
        tip:AddRow("  FPS", nil, nil, math.floor(GetFramerate()))
        tip:SetFont(nil)
    end

    tip:AddRow({ (dashboard.showLog and "[-] " or "[+] ") .. "Log (40 rows, scrolls)", ROW }):SetColor(NORMAL_FONT_COLOR)
        :OnClick(function(t)
            dashboard.showLog = not dashboard.showLog
            t:Refresh()
        end)
    if dashboard.showLog then
        tip:SetFont(GameFontHighlightSmall)
        for index = 1, 40 do
            tip:AddRow("  Entry " .. index, nil, nil, "|cffaaaaaa#" .. index .. "|r")
        end
        tip:SetFont(nil)
    end

    -- Footer: always visible at the bottom
    footer:AddSeparator("ffcc00", 1)
    footer:AddRow({ "Click: toggle   Wheel: volume   Hover: item", ROW, "CENTER" })
end

examples[22] = {
    level = 3,
    title = "Everything combined",
    build = BuildCombined,
    columns = { "LEFT", "RIGHT", "RIGHT", "RIGHT" },
    options = {
        key = "combined",
        minWidth = 310,
        maxHeight = 450,
        refresh = 1,
        footer = { enabled = true },
    },
}

--------------------------------------------------------------------------------
-- Example 23: Items - icon, quality color, item tooltip, Shift/Ctrl+click like in the bags
--------------------------------------------------------------------------------

-- Classic clients may still use the old global names.
local GetItemInfo = C_Item.GetItemInfo or GetItemInfo
local GetItemIcon = C_Item.GetItemIconByID or GetItemIcon
local GetItemCount = C_Item.GetItemCount or GetItemCount

local ITEM_IDS = { 6948, 2589, 2770, 118 }   -- Hearthstone, Linen Cloth, Copper Ore, Minor Healing Potion

local function BuildItems(tip, header, footer)
    header:AddRow("Item", "Count")
    header:AddSeparator("ffcc00", 1)
    for _, itemID in ipairs(ITEM_IDS) do
        local _, link = GetItemInfo(itemID)                  -- nil until the client has loaded the item
        if not link then
            -- Draw again once it is loaded; until then the row says "Loading...".
            Item:CreateFromItemID(itemID):ContinueOnItemLoad(function() PixieTooltip:Refresh() end)
        end
        local icon = GetItemIcon(itemID)
        tip:AddRow("|T" .. (icon or 134400) .. ":16|t " .. (link or "Loading..."), GetItemCount(itemID))
            :OnHover("item:" .. itemID)                      -- the item's own tooltip beside the row
            :OnClick(function()
                if link then HandleModifiedItemClick(link) end   -- Shift: link to chat, Ctrl: try on, ...
            end)
    end
    footer:AddRow({ "Shift+click: link to chat   Ctrl+click: try on", ROW, "CENTER" })
end

examples[23] = { level = 3, title = "Items (Shift/Ctrl+click)", build = BuildItems, options = FOOTER_ON }

--------------------------------------------------------------------------------
-- Example 24: Panel - stays open, movable, close button, Esc, remembers its place
--------------------------------------------------------------------------------

local panelState = { sound = true, music = false, volume = 60 }
local panelPosition  -- { point, relativeTo, relativePoint, x, y } saved when the panel closes

local function BuildPanel(tip, header, footer)
    header:AddRow("Pixie Panel", date("%H:%M:%S"))
    header:AddSeparator("ffcc00", 1)
    tip:AddRow("Sound", OnOff(panelState.sound))
        :OnClick(function(t)
            panelState.sound = not panelState.sound
            t:Refresh()
        end)
    tip:AddRow("Music", OnOff(panelState.music))
        :OnClick(function(t)
            panelState.music = not panelState.music
            t:Refresh()
        end)
    tip:AddRow("Volume (wheel)", panelState.volume .. "%")
        :SetBar(panelState.volume, 100, "ffcc00")
        :OnWheel(function(t, delta)
            panelState.volume = math.max(0, math.min(100, panelState.volume + delta * 5))
            t:Refresh()
        end)
    footer:AddRow({ "Drag to move   Esc or X to close", ROW, "CENTER" })
end

examples[24] = {
    level = 3,
    title = "Panel (movable, X, Esc)",
    build = BuildPanel,
    noCombat = false,
    anchorFrame = UIParent,                 -- opens in the middle of the screen, not next to the list line
    options = {
        key = "panel",
        autoHide = false,                   -- stays open
        refresh = 1,                        -- live clock
        anchor = { point = "CENTER" },
        movable = true,
        closeButton = true,
        escape = true,
        minWidth = 220,
        footer = { enabled = true },
        -- The module saves nothing; the addon keeps the place itself (in an addon: in SavedVariables).
        onClose = function(tip)
            panelPosition = { tip:GetPoint(1) }
        end,
    },
    -- Back to the saved place when it opens again.
    onOpen = function(tip)
        if panelPosition then
            tip:ClearAllPoints()
            tip:SetPoint(unpack(panelPosition))
        end
    end,
}

--==============================================================================
-- Test harness (not an example): the list on the Settings panel and /ptt
--==============================================================================

local EXAMPLE_KEYS = { addonName, "live", "second", "combined", "position" }
local PANEL_KEY = "panel"
local LINE_HEIGHT = 18

-- CloseAll - Closes every tooltip the examples open; the panel (example 24) only when includePanel is true.
local function CloseAll(includePanel)
    for _, key in ipairs(EXAMPLE_KEYS) do
        PixieTooltip:Close(key)
    end
    if includePanel then
        PixieTooltip:Close(PANEL_KEY)
    end
end

-- Examples opened from the list hang from a fixed spot in the top right of the page: the tooltip's top right
-- corner sits on the spot ("BOTTOMRIGHT" of a 1 x 1 frame), so the list on the left stays readable.
local SPOT_ANCHOR = { point = "BOTTOMRIGHT", gap = 0 }
-- Example 15 (Attach) opens next to its own line, to the right of the text.
local LINE_ANCHOR = { point = "RIGHT", gap = 8 }

local spot  -- the fixed spot on the page, created with the page below

-- ListOptions - The example's options with the given anchor, unless the example has its own anchor.
local function ListOptions(example, anchor)
    local options = {}
    for name, value in pairs(example.options or {}) do
        options[name] = value
    end
    options.anchor = options.anchor or anchor
    return options
end

-- OpenExample - Opens example number index at the fixed spot of the page (fromList) or at the mouse cursor.
local function OpenExample(index, fromList)
    local example = examples[index]
    if not example then return end
    -- A panel that is already open stays where it was dragged.
    if example.anchorFrame and PixieTooltip:IsOpen(example.options.key) then return end
    -- Examples with their own key would stay open under the next one, so everything is closed first.
    CloseAll()
    local options = fromList and ListOptions(example, SPOT_ANCHOR) or example.options
    local anchor = example.anchorFrame or (fromList and spot) or nil
    local tip = PixieTooltip:Open(anchor, example.build, example.columns, example.noCombat, options)
    if tip and example.onOpen then
        example.onOpen(tip)
    end
end

local panel = CreateFrame("Frame")
panel.name = "Pixie Tooltip"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Pixie Tooltip examples")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
subtitle:SetText("Hover a line to open its example on the right.   /ptt <number>: at the cursor   /ptt close: close all")

local keyHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
keyHint:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -4)
keyHint:SetText("|cffffcc00F12|r: open or close the Panel (example 24) from anywhere - PixieTooltip:Bind")

spot = CreateFrame("Frame", nil, panel)
spot:SetSize(1, 1)
spot:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -80)   -- level with the "Simple" heading

-- CreateLevelTitle - The heading of one level (Simple, Advanced, Expert).
local function CreateLevelTitle(text, y)
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 16, y)
    label:SetText(text)
end

local lines = {}

-- FitLine - The line is as wide as its text, so the highlight and the tooltip sit right after it.
local function FitLine(line)
    line:SetWidth(32 + math.ceil(line.label:GetStringWidth()) + 6)
end

-- CreateLine - One example line; hovering it opens the example (example 15 uses Attach instead).
local function CreateLine(index, example, y)
    local line = CreateFrame("Button", nil, panel)
    line:SetPoint("TOPLEFT", 28, y)
    line:SetSize(200, LINE_HEIGHT)
    lines[#lines + 1] = line

    local highlight = line:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.1)

    local number = line:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    number:SetPoint("RIGHT", line, "LEFT", 24, 0)
    number:SetText(index)

    local label = line:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", 32, 0)
    label:SetText(example.title)
    line.label = label
    FitLine(line)

    if example.build == BuildAttach then
        -- Example 15: PixieTooltip:Attach on this line, no OnEnter code.
        line:SetScript("OnEnter", function() CloseAll() end)
        PixieTooltip:Attach(line, example.build, example.columns, example.noCombat, ListOptions(example, LINE_ANCHOR))
    else
        line:SetScript("OnEnter", function(self)
            OpenExample(index, true)
        end)
    end
end

local y, level = -80, nil
for index = 1, #examples do
    local example = examples[index]
    if example.level ~= level then
        level = example.level
        if index > 1 then y = y - 8 end
        CreateLevelTitle(LEVELS[level], y)
        y = y - LINE_HEIGHT
    end
    CreateLine(index, example, y)
    y = y - LINE_HEIGHT
end

-- Fonts may not be measured correctly at load time, so the widths are fitted again when the page opens.
panel:SetScript("OnShow", function()
    for _, line in ipairs(lines) do
        FitLine(line)
    end
end)

-- Settings: 10.0+ and the modern Classic clients; InterfaceOptions on older clients.
local OpenPanel
if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    OpenPanel = function() Settings.OpenToCategory(category:GetID()) end
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
    OpenPanel = function()
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)  -- the first call only opens the frame on old clients
    end
end

-- Example 24 on a key: F12 opens and closes the panel from anywhere (PixieTooltip:Bind, no Bindings.xml).
local panelExample = examples[24]
PixieTooltip:Bind("F12", panelExample.build, panelExample.columns, panelExample.noCombat, panelExample.options)

SLASH_PIXIETOOLTIPTEST1 = "/ptt"
SlashCmdList.PIXIETOOLTIPTEST = function(message)
    local command = strtrim(message or ""):lower()
    if command == "close" then
        CloseAll(true)
    elseif tonumber(command) then
        OpenExample(tonumber(command), false)
    elseif OpenPanel then
        OpenPanel()
    end
end
