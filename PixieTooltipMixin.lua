--[[ Pixie Tooltip
     Description: Rich multi-column tooltips for WoW addons from one build function: merged cells, fixed header
                  and footer, progress bars, images and hover hints. Rows react to clicks and the mouse wheel,
                  long lists scroll, and Refresh redraws it live. No libraries, no globals.
                  This file is a mixin: the "Mixin" in the file name marks it, so the variable is simply
                  PixieTooltip (private.PixieTooltip), without the suffix.
     Clients:     Retail, Mists of Pandaria Classic, Classic Era, Anniversary, Forever (tested on all four; Forever not yet).

     Naming:      Add... adds content, Set... changes the look, On... reacts to the mouse.
     Targets:     tip (the whole tooltip and its body), header (fixed top), footer (fixed bottom, only when
                  footer.enabled) and row (one row). The same Add.../Set... names work on each of them.
     Markers:     CELL and ROW merge cells in AddRow and extend areas in the Set... masks.
     Precedence:  built-in value -> SetDefaults -> Open -> Set... in the build function.

     Usage:
         local PixieTooltip = private.PixieTooltip
         local CELL, ROW = PixieTooltip.CELL, PixieTooltip.ROW

         local function Build(tip, header)
             header:AddRow("My Addon")
             tip:AddRow("Gold", GetMoneyString(GetMoney(), true))
         end

         PixieTooltip:Open(anchor, Build)            -- automatic columns, not in combat
         PixieTooltip:Open(anchor, Build, 4)         -- 4 columns
         PixieTooltip:Open(anchor, Build, 4, false)  -- 4 columns, also in combat

     See DOCUMENTATION.md for the full API. ]]

local addonName, private = ...

local PixieTooltip = {}
private.PixieTooltip = PixieTooltip

-- Markers: unique values, so a cell text "cell" or "row" is never mistaken for them.
local CELL = setmetatable({}, { __tostring = function() return "PixieTooltip.CELL" end })
local ROW = setmetatable({}, { __tostring = function() return "PixieTooltip.ROW" end })
PixieTooltip.CELL = CELL
PixieTooltip.ROW = ROW

-- Technical limits; not settings.
local AUTO_HIDE_STEP = 0.1         -- ticker interval while a tooltip is shown
local DEFAULT_MAX_HEIGHT = 0.8     -- share of the screen height before the body scrolls
local DEFAULT_MAX_WIDTH = 0.4      -- share of the screen width before the widest columns wrap
local MIN_BODY_HEIGHT = 40         -- the body never shrinks below this when header and footer are tall
local MIN_COLUMN_WIDTH = 40        -- maxWidth never squeezes a column below this
local SCROLLBAR_WIDTH = 14
local CLOSE_BUTTON_SPACE = 16      -- extra room on the right for the closeButton
local DEFAULT_AUTO_HIDE = 0.1

local HIGHLIGHT_TEXTURE = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local SCROLL_KNOB_TEXTURE = "Interface\\Buttons\\UI-ScrollBar-Knob"

-- Default font of each part (names of global font objects).
local SECTION_FONTS = {
    header = "GameTooltipHeaderText",
    body = "GameTooltipText",
    footer = "GameFontDisableSmall",
}

-- Built-in values of every setting (see SetDefaults). nil values are listed in comments.
local BUILTIN = {
    noCombat = true,
    autoHide = DEFAULT_AUTO_HIDE,
    -- columns = nil            automatic
    anchor = { gap = 0, cursor = { 10, -10 } },   -- point = nil: automatic
    hint = { gap = 0 },                           -- side = nil: the side with more room
    -- minWidth, maxWidth, maxHeight = nil
    scale = 1,
    strata = "TOOLTIP",
    -- border, background = nil: native
    padding = 10,
    columnGap = 12,
    rowSpacing = 2,
    sectionGap = 4,
    header = {},
    body = {},
    footer = { enabled = false },
    highlight = { alpha = 0.6 },                  -- fill = nil: the quest-log glow
    bar = { fill = "00cc00", alpha = 0.6 },
    separator = { size = 1 },                     -- color = nil: a gap
    image = { size = 32, align = "CENTER" },
    wheelStep = 40,
    movable = false,
    closeButton = false,
    escape = false,
}

-- Settings that are tables: SetDefaults and Open merge them field by field.
local TABLE_SETTINGS = {
    anchor = true, hint = true, header = true, body = true, footer = true,
    highlight = true, bar = true, separator = true, image = true,
}

-- Every setting name SetDefaults accepts (Open also takes key, refresh and onClose).
local SETTINGS = {
    "noCombat", "autoHide", "columns", "anchor", "hint", "minWidth", "maxWidth", "maxHeight", "scale",
    "strata", "border", "background", "padding", "columnGap", "rowSpacing", "sectionGap", "header", "body",
    "footer", "highlight", "bar", "separator", "image", "wheelStep", "movable", "closeButton", "escape",
}

local FALLBACK_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local JUSTIFY = { LEFT = true, CENTER = true, RIGHT = true }
local VALIGN = { TOP = true, MIDDLE = true, BOTTOM = true }

-- The look lists of a row (filled by its Set... / On... calls, emptied on every refresh).
local ROW_LISTS = { "fonts", "colors", "wraps", "backgrounds", "bars", "highlights", "clicks", "wheels" }

local openTooltips = {}  -- key -> tooltip frame
local freeTooltips = {}  -- released frames, reused by the next Open
local defaults = {}      -- SetDefaults

local TooltipMixin = {}
local SectionMixin = {}
local RowMixin = {}

local Layout  -- forward declaration (defined below the mixins)

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--[[ ParseColor
     Purpose:  Converts a color argument to r, g, b, a.
     Params:   color - "rrggbb", "aarrggbb", "#rrggbb", {r, g, b[, a]}, {r=, g=, b=[, a=]} or a ColorMixin
     Returns:  r, g, b, a, or nil when the color is not recognized ]]
local colorCache = {}  -- color string -> { r, g, b, a }, or false (e.g. a texture path); parsed once

local function ParseColor(color)
    if type(color) == "string" then
        local cached = colorCache[color]
        if cached == nil then
            local hex = (color:gsub("^#", ""))
            if #hex == 6 then hex = "ff" .. hex end
            local a, r, g, b = hex:match("^(%x%x)(%x%x)(%x%x)(%x%x)$")
            if a then
                cached = { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, tonumber(a, 16) / 255 }
            else
                cached = false
            end
            colorCache[color] = cached
        end
        if cached then
            return cached[1], cached[2], cached[3], cached[4]
        end
    elseif type(color) == "table" then
        if color.GetRGBA then return color:GetRGBA() end
        local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
        if type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b, color.a or color[4] or 1
        end
    end
    return nil
end

-- MeasureText - Unconstrained width of a font string's text.
local function MeasureText(fontString)
    fontString:SetWidth(0)
    -- GetUnboundedStringWidth: 8.0+ and the modern Classic clients; GetStringWidth elsewhere.
    if fontString.GetUnboundedStringWidth then
        return fontString:GetUnboundedStringWidth()
    end
    return fontString:GetStringWidth()
end

-- PixelSize - Rounds a size to whole physical pixels (PixelUtil: 8.0+ and the modern Classic clients).
local function PixelSize(tip, size)
    if size > 0 and PixelUtil and PixelUtil.GetNearestPixelSize then
        return PixelUtil.GetNearestPixelSize(size, tip:GetEffectiveScale(), 1)
    end
    return size
end

-- IsAtlas - True when the string names an atlas (C_Texture: 8.0+ and the modern Classic clients).
local function IsAtlas(texture)
    return type(texture) == "string" and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(texture) ~= nil
end

--[[ ApplyFill
     Purpose:  Paints a texture with a color or an image.
     Params:   texture, fill - a color (see ParseColor) or a file path, fileID or atlas name
     Returns:  true when fill was an image, false for a color ]]
local function ApplyFill(texture, fill)
    local r, g, b, a = ParseColor(fill)
    if r then
        texture:SetColorTexture(r, g, b, a)
        return false
    end
    if IsAtlas(fill) then
        texture:SetAtlas(fill)
    else
        texture:SetTexture(fill)
    end
    return true
end

-- IsSecret - True for a 12.0 secret value (combat data an addon may show but not compare or calculate with).
local IsSecret = issecretvalue or function() return false end

-- RequestLayout - Re-lays out a visible tooltip on the next frame (batches several changes).
local function RequestLayout(tip)
    if tip.building or tip.layoutPending or not tip:IsShown() then return end
    tip.layoutPending = true
    -- One callback per tooltip, made once, so a refresh creates no new function.
    if not tip.layoutCallback then
        tip.layoutCallback = function()
            if tip.layoutPending then Layout(tip) end
        end
    end
    C_Timer.After(0, tip.layoutCallback)
end

--------------------------------------------------------------------------------
-- Fonts: a font object, its name, { file, size, flags } or a full table
-- { base, file, size, flags, color, shadow, spacing }. Missing fields come from base.
--------------------------------------------------------------------------------

local fontCache = {}   -- key -> font object made from a table
local fontBySpec = setmetatable({}, { __mode = "k" })  -- font table -> { base, object }, forgotten with the table
local fontCount = 0
local FONT_PREFIX = (addonName:gsub("[^%w_]", "")) .. "_PixieTooltipFont"

-- FontKey - A string that identifies a font table on its base, for the cache.
local function FontKey(base, file, size, flags, spec)
    local parts = { tostring(base), tostring(file), tostring(size), tostring(flags), tostring(spec.spacing) }
    local r, g, b, a = ParseColor(spec.color)
    parts[#parts + 1] = r and string.format("%.3f,%.3f,%.3f,%.3f", r, g, b, a) or "-"
    local shadow = spec.shadow
    if shadow == false then
        parts[#parts + 1] = "noshadow"
    elseif type(shadow) == "table" then
        local sr, sg, sb, sa = ParseColor(shadow.color)
        parts[#parts + 1] = string.format("%s,%s,%s,%s,%s,%s", tostring(sr), tostring(sg), tostring(sb),
            tostring(sa), tostring(shadow.x), tostring(shadow.y))
    end
    return table.concat(parts, "|")
end

--[[ ResolveFont
     Purpose:  Turns any accepted font form into a font object.
     Params:   font - font object, global name, { file, size, flags } or a full table;
               base - font object the missing fields of a table come from
     Returns:  a font object, or nil ]]
local function ResolveFont(font, base)
    if type(font) == "string" then font = _G[font] end
    if type(font) ~= "table" then return nil end
    if font.GetFont then return font end

    local spec = font
    base = ResolveFont(spec.base) or base or GameTooltipText
    -- The same table again (e.g. from SetDefaults on every refresh): no key to build.
    local known = fontBySpec[spec]
    if known and known.base == base then return known.object end

    local baseFile, baseSize, baseFlags = base:GetFont()
    local file = spec.file or spec[1] or baseFile
    local size = spec.size or spec[2] or baseSize
    local flags = spec.flags or spec[3] or baseFlags or ""

    local key = FontKey(base, file, size, flags, spec)
    local object = fontCache[key]
    if object then
        fontBySpec[spec] = { base = base, object = object }
        return object
    end

    -- CreateFont needs a global name; it starts with the addon name so it never clashes.
    fontCount = fontCount + 1
    object = CreateFont(FONT_PREFIX .. fontCount)
    object:CopyFontObject(base)
    object:SetFont(file, size, flags)
    local r, g, b, a = ParseColor(spec.color)
    if r then object:SetTextColor(r, g, b, a) end
    if spec.shadow == false then
        object:SetShadowOffset(0, 0)
        object:SetShadowColor(0, 0, 0, 0)
    elseif type(spec.shadow) == "table" then
        local sr, sg, sb, sa = ParseColor(spec.shadow.color)
        if sr then object:SetShadowColor(sr, sg, sb, sa) end
        object:SetShadowOffset(spec.shadow.x or 1, spec.shadow.y or -1)
    end
    if tonumber(spec.spacing) then object:SetSpacing(tonumber(spec.spacing)) end
    fontCache[key] = object
    fontBySpec[spec] = { base = base, object = object }
    return object
end

--------------------------------------------------------------------------------
-- Settings: built-in -> SetDefaults -> Open options
--------------------------------------------------------------------------------

-- MergeInto - Copies the fields of source over target (a boolean footer means { enabled = it }).
local function MergeInto(target, source)
    if type(source) == "boolean" then
        target.enabled = source
    elseif type(source) == "table" then
        for field, value in pairs(source) do
            target[field] = value
        end
    end
end

-- ResolveSettings - The settings of one Open call.
local function ResolveSettings(options)
    local settings = {}
    for _, name in ipairs(SETTINGS) do
        if TABLE_SETTINGS[name] then
            local merged = {}
            MergeInto(merged, BUILTIN[name])
            MergeInto(merged, defaults[name])
            MergeInto(merged, options[name])
            settings[name] = merged
        elseif options[name] ~= nil then
            settings[name] = options[name]
        elseif defaults[name] ~= nil then
            settings[name] = defaults[name]
        else
            settings[name] = BUILTIN[name]
        end
    end
    return settings
end

--------------------------------------------------------------------------------
-- Masks: Set...(value, true, false, CELL, ROW, ...)
-- No mask: the whole row. true starts an area at that column, CELL extends the previous area to it,
-- ROW extends the previous area to the last column, false or nil leaves the column out.
--------------------------------------------------------------------------------

--[[ AcquireLook
     Purpose:  A value with its column mask, as stored by the Set... / On... calls. Looks are pooled per row or
               part and reused on every refresh, so rebuilding a tooltip creates no new tables.
     Params:   owner (row or part; has lookPool and lookCount), value, mask...
     Returns:  the look { value, mask, areas, areaCount }, or nil when value is nil ]]
local function AcquireLook(owner, value, ...)
    if value == nil then return nil end
    local index = owner.lookCount + 1
    owner.lookCount = index
    local look = owner.lookPool[index]
    if not look then
        look = { mask = { n = 0 }, areas = {}, areaCount = 0 }
        owner.lookPool[index] = look
    end
    look.value = value
    local mask = look.mask
    local count = select("#", ...)
    for column = 1, math.max(count, mask.n) do
        mask[column] = (select(column, ...))
    end
    mask.n = count
    look.areasColumns = nil  -- the areas are worked out again for this mask
    return look
end

--[[ GetAreas
     Purpose:  The column ranges of a look's mask, as a flat list first1, last1, first2, last2, ...
               Worked out once per look and column count, then reused.
     Returns:  areas, number of entries (2 per area) ]]
local function GetAreas(look, numColumns)
    if look.areasColumns == numColumns then
        return look.areas, look.areaCount
    end
    local mask, areas = look.mask, look.areas
    local count = 0
    if mask.n == 0 then
        areas[1], areas[2], count = 1, numColumns, 2
    else
        local open = false  -- an area is open: its last column is areas[count]
        for column = 1, math.min(mask.n, numColumns) do
            local value = mask[column]
            if value == true or ((value == CELL or value == ROW) and not open) then
                areas[count + 1], areas[count + 2] = column, column
                count = count + 2
                open = true
            elseif value == CELL then
                areas[count] = column
            elseif value ~= ROW then
                open = false
            end
            if value == ROW then
                areas[count] = numColumns
                break
            end
        end
    end
    look.areaCount = count
    look.areasColumns = numColumns
    return areas, count
end

-- ApplyLook - Writes a look's value into target[column] for every column its mask covers.
local function ApplyLook(target, look, numColumns)
    if not look then return end
    local areas, count = GetAreas(look, numColumns)
    for index = 1, count, 2 do
        for column = areas[index], areas[index + 1] do
            target[column] = look.value
        end
    end
end

-- InArea - True when column lies in one of the look's areas.
local function InArea(look, column, numColumns)
    local areas, count = GetAreas(look, numColumns)
    for index = 1, count, 2 do
        if column >= areas[index] and column <= areas[index + 1] then return true end
    end
    return false
end

-- FillList - Writes the arguments into a reused list and sets list.n (entries past n are cleared).
local function FillList(list, ...)
    local count = select("#", ...)
    for index = 1, math.max(count, list.n or 0) do
        list[index] = (select(index, ...))
    end
    list.n = count
end

-- PickAlign / PickValign - A column's value from a SetAlign / SetValign list (one SetValign value: every column).
local function PickAlign(list, column)
    if not list or column > (list.n or #list) then return nil end
    local value = list[column]
    return JUSTIFY[value] and value or nil
end

local function PickValign(list, column)
    if not list or not list.n or list.n == 0 then return nil end
    local value = list.n == 1 and list[1] or list[column]
    return VALIGN[value] and value or nil
end

--------------------------------------------------------------------------------
-- Hover hint (GameTooltip beside the tooltip)
--------------------------------------------------------------------------------

-- HideHint - Hides GameTooltip when one of this tooltip's rows owns it.
local function HideHint(tip)
    local owner = GameTooltip:GetOwner()
    if owner and owner.tip == tip then GameTooltip:Hide() end
end

-- IsHyperlink - Full links ("|Hitem:...|h") and short ones ("item:6948", "spell:1234").
local function IsHyperlink(text)
    return text:find("|H") ~= nil or text:find("^%a+:%-?%d") ~= nil
end

-- ShowHint - Shows the row's hint level with the row, on the hint.side of the tooltip.
local function ShowHint(row)
    local tip = row.tip
    local settings = tip.settings.hint
    local gap = tonumber(settings.gap) or 0
    local side = settings.side
    if side ~= "LEFT" and side ~= "RIGHT" then
        local x = tip:GetCenter()
        side = (x and x > UIParent:GetWidth() / 2) and "LEFT" or "RIGHT"
    end
    GameTooltip:SetOwner(row, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    local offset = (row:GetTop() or 0) - (tip:GetTop() or 0)
    if side == "LEFT" then
        GameTooltip:SetPoint("TOPRIGHT", tip, "TOPLEFT", -gap, offset)
    else
        GameTooltip:SetPoint("TOPLEFT", tip, "TOPRIGHT", gap, offset)
    end
    local hint = row.hint
    if type(hint) == "function" then
        hint(GameTooltip, row)
    elseif type(hint) == "string" and IsHyperlink(hint) then
        GameTooltip:SetHyperlink(hint)
    else
        GameTooltip:SetText(tostring(hint), 1, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- Row frames
--------------------------------------------------------------------------------

-- ShowHover / HideHover - The highlight textures of a row.
local function ShowHover(row)
    for _, texture in ipairs(row.hover) do texture:Show() end
end

local function HideHover(row)
    for _, texture in ipairs(row.hover) do texture:Hide() end
end

-- GetColumnAt - The column under the mouse (cells own half the gap on each side).
local function GetColumnAt(row)
    local layout = row.tip.layout
    if not layout then return 1 end
    local x = GetCursorPosition() / row:GetEffectiveScale() - (row:GetLeft() or 0)
    for column = 1, layout.numColumns - 1 do
        if x < layout.offsets[column] + layout.widths[column] + layout.columnGap / 2 then return column end
    end
    return layout.numColumns
end

-- FindHandler - The last OnClick / OnWheel handler whose mask covers the column under the mouse.
local function FindHandler(row, handlers)
    if #handlers == 0 then return nil end
    local column = GetColumnAt(row)
    local numColumns = row.tip.layout and row.tip.layout.numColumns or 1
    for index = #handlers, 1, -1 do
        local handler = handlers[index]
        if InArea(handler, column, numColumns) then return handler.value end
    end
    return nil
end

local function Row_OnEnter(row)
    ShowHover(row)
    if row.hint then ShowHint(row) end
end

local function Row_OnLeave(row)
    HideHover(row)
    if GameTooltip:GetOwner() == row then GameTooltip:Hide() end
end

local function Row_OnMouseUp(row, button)
    if not row:IsMouseOver() then return end
    local func = FindHandler(row, row.clicks)
    if func then func(row.tip, button, row) end
end

local function Row_OnMouseWheel(row, delta)
    local func = FindHandler(row, row.wheels)
    if func then func(row.tip, delta, row) end
end

-- CreateRow - New pooled row frame inside a part.
local function CreateRow(section)
    local row = CreateFrame("Frame", nil, section.parent)
    Mixin(row, RowMixin)
    row.section = section
    row.tip = section.tip
    row.fontStrings = {}  -- column -> FontString
    row.cells = {}        -- column -> cell { text, span, align, ... } from cellPool
    row.cellPool, row.cellCount = {}, 0
    row.textures = {}     -- pooled area textures: backgrounds, bars, highlights
    row.textureCount = 0
    row.hover = {}        -- textures shown while the mouse is over the row

    -- Looks added with the row's Set... / On... calls: lists of pooled { value, mask } looks.
    row.lookPool, row.lookCount = {}, 0
    row.barPool, row.barCount = {}, 0
    for _, name in ipairs(ROW_LISTS) do
        row[name] = {}
    end
    row.align = { n = 0 }
    row.valign = { n = 0 }
    row.cellFonts, row.cellColors, row.cellWraps = {}, {}, {}  -- work tables of PrepareRow

    row.separator = row:CreateTexture(nil, "ARTWORK")
    row.separator:SetAllPoints()
    row.separator:Hide()

    row.image = row:CreateTexture(nil, "ARTWORK")
    row.image:Hide()

    row:SetScript("OnEnter", Row_OnEnter)
    row:SetScript("OnLeave", Row_OnLeave)
    row:SetScript("OnMouseUp", Row_OnMouseUp)
    row:SetScript("OnMouseWheel", Row_OnMouseWheel)
    row:EnableMouse(false)
    row:EnableMouseWheel(false)
    row:Hide()
    return row
end

-- ReleaseTextures - Hides the row's area textures before they are drawn again.
local function ReleaseTextures(row)
    for index = 1, row.textureCount do
        row.textures[index]:Hide()
    end
    row.textureCount = 0
    wipe(row.hover)
end

-- AcquireTexture - The next pooled area texture of a row, on the given draw layer.
local function AcquireTexture(row, layer, sublevel)
    local index = row.textureCount + 1
    local texture = row.textures[index]
    if not texture then
        texture = row:CreateTexture(nil, layer, nil, sublevel)
        row.textures[index] = texture
    else
        texture:SetDrawLayer(layer, sublevel)
    end
    row.textureCount = index
    texture:ClearAllPoints()
    texture:SetTexCoord(0, 1, 0, 1)  -- a pooled texture may still carry an atlas' coordinates
    texture:SetBlendMode("BLEND")
    texture:SetAlpha(1)
    return texture
end

-- ResetRow - Returns a pooled row to its empty state; its pooled tables are kept for the next use.
local function ResetRow(row)
    wipe(row.cells)
    row.cellCount = 0
    for _, name in ipairs(ROW_LISTS) do
        wipe(row[name])
    end
    row.lookCount = 0
    row.barCount = 0
    row.kind = nil
    row.columnCount = 0
    row.baseFont = nil
    row.baseColor = nil
    row.baseHighlight = nil
    row.align.n = 0
    row.valign.n = 0
    row.space = nil
    row.imageWidth = nil
    row.imageHeight = nil
    row.imageJustify = nil
    row.hint = nil
    ReleaseTextures(row)
    row.separator:Hide()
    row.image:Hide()
    -- The text stays: PrepareRow skips measuring when the same text comes back.
    for _, fontString in pairs(row.fontStrings) do
        fontString:Hide()
    end
    row:EnableMouse(false)
    row:EnableMouseWheel(false)
    row:Hide()
end

-- UpdateMouse - Enables mouse input only on rows that react to it, so the rest stays click-through.
local function UpdateMouse(row)
    row:EnableMouse(#row.clicks > 0 or #row.wheels > 0 or #row.highlights > 0 or row.hint ~= nil)
    row:EnableMouseWheel(#row.wheels > 0)
end

-- GetFontString - The row's font string for a column, created on first use.
local function GetFontString(row, column)
    local fontString = row.fontStrings[column]
    if not fontString then
        fontString = row:CreateFontString(nil, "ARTWORK")
        fontString:SetJustifyV("TOP")
        row.fontStrings[column] = fontString
    end
    return fontString
end

--------------------------------------------------------------------------------
-- RowMixin (returned by every Add... call; every method returns the row, so they chain)
--------------------------------------------------------------------------------

-- AddLook - Stores a Set... / On... call of the row and redraws a visible tooltip.
local function AddLook(row, list, value, ...)
    local look = AcquireLook(row, value, ...)
    if look then list[#list + 1] = look end
    RequestLayout(row.tip)
    return row
end

-- SetColor - Text color (see ParseColor), mask optional.
function RowMixin:SetColor(color, ...)
    return AddLook(self, self.colors, color, ...)
end

-- SetFont - Font (object, name or table; see ResolveFont), mask optional.
function RowMixin:SetFont(font, ...)
    return AddLook(self, self.fonts, ResolveFont(font, self.section.defaultFont), ...)
end

-- SetBackground - Background: a color or an image (file path, fileID, atlas), mask optional.
function RowMixin:SetBackground(fill, ...)
    return AddLook(self, self.backgrounds, fill, ...)
end

-- SetHighlight - Shown while the mouse is over the row (also on rows without OnClick), mask optional.
function RowMixin:SetHighlight(fill, ...)
    AddLook(self, self.highlights, fill, ...)
    UpdateMouse(self)
    return self
end

--[[ SetBar
     Purpose:  A progress bar behind the text.
     Params:   value, max (numbers), fill (color or image; nil: the bar default), mask optional
               (each area of the mask gets its own bar) ]]
function RowMixin:SetBar(value, max, fill, ...)
    -- A 12.0 secret value cannot be calculated with: no bar instead of an error.
    if IsSecret(value) or IsSecret(max) then return self end
    local index = self.barCount + 1
    self.barCount = index
    local bar = self.barPool[index]
    if not bar then
        bar = {}
        self.barPool[index] = bar
    end
    bar.value, bar.max, bar.fill = tonumber(value) or 0, tonumber(max) or 0, fill
    return AddLook(self, self.bars, bar, ...)
end

-- SetWrap - Wraps the text of the masked columns at width pixels.
function RowMixin:SetWrap(width, ...)
    return AddLook(self, self.wraps, tonumber(width), ...)
end

-- SetAlign - Horizontal alignment per column ("LEFT", "CENTER", "RIGHT"; nil keeps the default).
function RowMixin:SetAlign(...)
    FillList(self.align, ...)
    RequestLayout(self.tip)
    return self
end

-- SetValign - Vertical alignment ("TOP", "MIDDLE", "BOTTOM"): one value for the row, or one per column.
function RowMixin:SetValign(...)
    FillList(self.valign, ...)
    RequestLayout(self.tip)
    return self
end

--[[ OnClick
     Purpose:  Makes the row (or the masked cells) clickable and highlighted on hover.
     Params:   func(tip, button, row) - call tip:Refresh() in it to redraw the tooltip; mask optional ]]
function RowMixin:OnClick(func, ...)
    AddLook(self, self.clicks, func, ...)
    UpdateMouse(self)
    return self
end

--[[ OnWheel
     Purpose:  Reacts to the mouse wheel over the row (or the masked cells).
     Params:   func(tip, delta, row) - delta is 1 (up) or -1 (down); mask optional ]]
function RowMixin:OnWheel(func, ...)
    AddLook(self, self.wheels, func, ...)
    UpdateMouse(self)
    return self
end

--[[ OnHover
     Purpose:  Shows a GameTooltip beside the tooltip while the mouse is over the row.
     Params:   hint - plain text, a hyperlink ("item:6948" or a full link) or func(GameTooltip, row) ]]
function RowMixin:OnHover(hint)
    self.hint = hint
    UpdateMouse(self)
    return self
end

--------------------------------------------------------------------------------
-- SectionMixin (header, footer and the body behind tip)
--------------------------------------------------------------------------------

-- NewRow - Takes the next pooled row of a part and copies the part's current look into it.
local function NewRow(section, kind)
    local index = section.rowCount + 1
    local row = section.rows[index]
    if not row then
        row = CreateRow(section)
        section.rows[index] = row
    end
    section.rowCount = index
    row.kind = kind
    row.baseFont = section.font
    row.baseColor = section.color
    row.baseHighlight = section.highlight or section.tip.body.highlight
    RequestLayout(section.tip)
    return row
end

-- AcquireCell - A pooled cell table of the row, reset for new text.
local function AcquireCell(row, text)
    local index = row.cellCount + 1
    row.cellCount = index
    local cell = row.cellPool[index]
    if not cell then
        cell = {}
        row.cellPool[index] = cell
    end
    cell.text, cell.span, cell.align = text, 1, nil
    return cell
end

--[[ ParseCells
     Purpose:  Fills the row's cells from the AddRow arguments.
               "text" or a number: one cell; nil: an empty cell;
               { "text", CELL, CELL, "RIGHT" }: one cell over three columns, right aligned;
               { "text", ROW }: one cell to the last column. ]]
local function ParseCells(row, ...)
    local cells = row.cells
    local column, last = 1, nil
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if IsSecret(value) then
            -- A 12.0 secret value is shown as it is; it cannot be compared with the markers.
            last = AcquireCell(row, value)
            cells[column] = last
            column = column + 1
        elseif value == CELL then
            -- A bare CELL widens the cell before it.
            if last and last.span ~= ROW then last.span = last.span + 1 end
            column = column + 1
        elseif value == ROW then
            if last then last.span = ROW end
            break
        elseif type(value) == "table" then
            local text = value[1]
            if not IsSecret(text) then
                text = text ~= nil and tostring(text) or ""
            end
            local cell = AcquireCell(row, text)
            local count = table.maxn and table.maxn(value) or #value
            for part = 2, count do
                local option = value[part]
                if option == CELL then
                    if cell.span ~= ROW then cell.span = cell.span + 1 end
                elseif option == ROW then
                    cell.span = ROW
                elseif JUSTIFY[option] then
                    cell.align = option
                end
            end
            cells[column] = cell
            last = cell
            if cell.span == ROW then
                column = column + 1
                break
            end
            column = column + cell.span
        else
            if value ~= nil then
                last = AcquireCell(row, tostring(value))
                cells[column] = last
            else
                last = nil
            end
            column = column + 1
        end
    end
    row.columnCount = column - 1
    return row
end

-- AddRow - Adds a row; each argument fills the next column (see ParseCells). Returns the row.
function SectionMixin:AddRow(...)
    return ParseCells(NewRow(self, "text"), ...)
end

--[[ AddSeparator
     Purpose:  A pixel-perfect horizontal line, or an empty gap when color is nil.
     Params:   color (see ParseColor, or nil for a gap), size (pixels, default: separator.size).
               Without any argument it uses the separator default (color and size). ]]
function SectionMixin:AddSeparator(...)
    local color, size = ...
    local defaultSeparator = self.tip.settings.separator
    if select("#", ...) == 0 then
        color = defaultSeparator.color
    end
    local row = NewRow(self, "separator")
    row.space = PixelSize(self.tip, tonumber(size) or tonumber(defaultSeparator.size) or 1)
    local r, g, b, a = ParseColor(color)
    if r then
        row.separator:SetColorTexture(r, g, b, a)
        row.separator:Show()
    end
    return row
end

--[[ AddImage
     Purpose:  A row with one image.
     Params:   texture (file path, fileID or atlas name), width, height (default width),
               align ("LEFT"|"CENTER"|"RIGHT"). Width and align default to the image settings. ]]
function SectionMixin:AddImage(texture, width, height, align)
    local defaultImage = self.tip.settings.image
    local row = NewRow(self, "image")
    row.imageWidth = tonumber(width) or tonumber(defaultImage.size) or 32
    row.imageHeight = tonumber(height) or row.imageWidth
    row.imageJustify = (JUSTIFY[align] and align) or (JUSTIFY[defaultImage.align] and defaultImage.align) or "CENTER"
    local image = row.image
    if IsAtlas(texture) then
        image:SetAtlas(texture)
    else
        image:SetTexCoord(0, 1, 0, 1)
        image:SetTexture(texture)
    end
    image:SetSize(row.imageWidth, row.imageHeight)
    return row
end

-- SetFont - Font of the rows added after this call (mask optional; nil: back to the part's font).
function SectionMixin:SetFont(font, ...)
    self.font = AcquireLook(self, ResolveFont(font, self.defaultFont), ...)
    return self
end

-- SetColor - Text color of the rows added after this call (mask optional; nil: back to the font's color).
function SectionMixin:SetColor(color, ...)
    self.color = AcquireLook(self, color, ...)
    return self
end

-- SetHighlight - Highlight of the clickable rows added after this call (nil: the highlight setting).
function SectionMixin:SetHighlight(fill, ...)
    self.highlight = AcquireLook(self, fill, ...)
    return self
end

-- SetWrap - Wraps the masked columns of every row of the part at width pixels.
function SectionMixin:SetWrap(width, ...)
    local look = AcquireLook(self, tonumber(width), ...)
    if look then self.wraps[#self.wraps + 1] = look end
    RequestLayout(self.tip)
    return self
end

-- SetAlign - Horizontal alignment per column for every row. On tip it also sets the column count.
function SectionMixin:SetAlign(...)
    FillList(self.align, ...)
    RequestLayout(self.tip)
    return self
end

-- SetValign - Vertical alignment for every row: one value, or one per column.
function SectionMixin:SetValign(...)
    FillList(self.valign, ...)
    RequestLayout(self.tip)
    return self
end

-- SetBackground - Background of the part: a color or an image (nil removes it).
function SectionMixin:SetBackground(fill)
    if fill == nil then
        self.background:Hide()
    else
        self.background:SetTexCoord(0, 1, 0, 1)
        ApplyFill(self.background, fill)
        self.background:Show()
    end
    return self
end

-- ResetSection - Empties a part before the build function runs again.
local function ResetSection(section)
    for index = 1, section.rowCount do
        ResetRow(section.rows[index])
    end
    section.rowCount = 0
    section.lookCount = 0
    section.font = nil
    section.color = nil
    section.highlight = nil
    wipe(section.wraps)
    section.align.n = 0
    section.valign.n = 0
    section.background:Hide()
end

local wrapMask = {}  -- reused by ApplyPartSettings for per-column wrap widths

--[[ ApplyPartSettings
     Purpose:  The header / body / footer setting, as if its Set... calls were the first lines of the build.
     Params:   section, settings ({ font, color, align, valign, wrap, background }) ]]
local function ApplyPartSettings(section, settings)
    if settings.font ~= nil then section:SetFont(settings.font) end
    if settings.color ~= nil then section:SetColor(settings.color) end
    if type(settings.align) == "table" then
        section:SetAlign(unpack(settings.align))
    elseif settings.align ~= nil then
        section:SetAlign(settings.align)
    end
    if type(settings.valign) == "table" then
        section:SetValign(unpack(settings.valign))
    elseif settings.valign ~= nil then
        section:SetValign(settings.valign)
    end
    if type(settings.wrap) == "table" then
        -- One width per column: a mask with true at that column.
        local count = table.maxn and table.maxn(settings.wrap) or #settings.wrap
        for column = 1, count do
            local width = settings.wrap[column]
            if width then
                for before = 1, column - 1 do wrapMask[before] = false end
                wrapMask[column] = true
                section:SetWrap(width, unpack(wrapMask, 1, column))
            end
        end
    elseif settings.wrap ~= nil then
        section:SetWrap(settings.wrap)
    end
    if settings.background ~= nil and section.name ~= "body" then
        section:SetBackground(settings.background)
    end
end

--------------------------------------------------------------------------------
-- TooltipMixin (the tooltip passed to the build function)
-- Add... and Set... go to the body; SetAlign, SetValign, SetWrap and SetHighlight are also the
-- defaults of the header and the footer.
--------------------------------------------------------------------------------

for _, name in ipairs({ "AddRow", "AddSeparator", "AddImage" }) do
    TooltipMixin[name] = function(self, ...)
        return self.body[name](self.body, ...)
    end
end

for _, name in ipairs({ "SetFont", "SetColor", "SetHighlight", "SetWrap", "SetAlign", "SetValign" }) do
    TooltipMixin[name] = function(self, ...)
        self.body[name](self.body, ...)
        return self
    end
end

-- ResetFrameLook - Restores the native tooltip background and border after SetBackground / SetBorder.
local function ResetFrameLook(tip)
    tip.backgroundImage:Hide()
    if not tip.lookChanged then return end
    tip.lookChanged = false
    if tip.NineSlice then
        local background = tip.backdropColor or TOOLTIP_DEFAULT_BACKGROUND_COLOR
        local border = tip.backdropBorderColor or TOOLTIP_DEFAULT_COLOR
        if background then
            local r, g, b = background:GetRGB()
            tip.NineSlice:SetCenterColor(r, g, b, tip.backdropColorAlpha or 1)
        end
        if border then
            local r, g, b = border:GetRGB()
            tip.NineSlice:SetBorderColor(r, g, b, tip.backdropBorderColorAlpha or 1)
        end
    else
        tip:SetBackdropColor(0, 0, 0, 0.9)
        tip:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end
end

-- SetBackground - Background of the whole tooltip: a color or an image.
function TooltipMixin:SetBackground(fill)
    self.lookChanged = true
    local r, g, b, a = ParseColor(fill)
    if r then
        self.backgroundImage:Hide()
        if self.NineSlice then
            self.NineSlice:SetCenterColor(r, g, b, a)
        else
            self:SetBackdropColor(r, g, b, a)
        end
    elseif fill ~= nil then
        ApplyFill(self.backgroundImage, fill)
        self.backgroundImage:Show()
    end
    return self
end

-- SetBorder - Border color of the tooltip.
function TooltipMixin:SetBorder(color)
    local r, g, b, a = ParseColor(color)
    if not r then return self end
    self.lookChanged = true
    if self.NineSlice then
        self.NineSlice:SetBorderColor(r, g, b, a)
    else
        self:SetBackdropBorderColor(r, g, b, a)
    end
    return self
end

-- Refresh - Clears the tooltip and runs the build function again (keeps the scroll position).
function TooltipMixin:Refresh()
    HideHint(self)
    for _, section in ipairs(self.sections) do
        ResetSection(section)
    end
    ResetFrameLook(self)
    local settings = self.settings
    self.building = true
    -- Settings first, so the Set... calls in the build function win.
    if settings.border ~= nil then self:SetBorder(settings.border) end
    if settings.background ~= nil then self:SetBackground(settings.background) end
    ApplyPartSettings(self.header, settings.header)
    ApplyPartSettings(self.body, settings.body)
    ApplyPartSettings(self.footerSection, settings.footer)
    if self.build then
        local ok, err = pcall(self.build, self, self.header, self.footer)
        if not ok then
            geterrorhandler()(addonName .. " [PixieTooltip]: " .. tostring(err))
        end
    end
    self.building = false
    Layout(self)
    -- The rows were rebuilt under a still mouse: restore the hint of the hovered row.
    if self:IsShown() then
        for _, section in ipairs(self.sections) do
            for index = 1, section.rowCount do
                local row = section.rows[index]
                if row.hint and row:IsMouseOver() then
                    ShowHint(row)
                    return
                end
            end
        end
    end
end

-- Close - Hides and releases this tooltip.
function TooltipMixin:Close()
    PixieTooltip:Close(self.key)
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

-- PrepareRow - Sets text, font and color of every cell and measures it (pass 1 of Layout).
-- The row's own work tables are reused, and a cell whose text and font did not change is not measured again.
local function PrepareRow(row, numColumns, widths)
    local section, body = row.section, row.tip.body
    local fonts, colors, wraps = row.cellFonts, row.cellColors, row.cellWraps
    wipe(colors)
    wipe(wraps)
    for column = 1, numColumns do fonts[column] = section.defaultFont end
    ApplyLook(fonts, row.baseFont, numColumns)
    for _, look in ipairs(row.fonts) do ApplyLook(fonts, look, numColumns) end
    ApplyLook(colors, row.baseColor, numColumns)
    for _, look in ipairs(row.colors) do ApplyLook(colors, look, numColumns) end
    for _, look in ipairs(body.wraps) do ApplyLook(wraps, look, numColumns) end
    if section ~= body then
        for _, look in ipairs(section.wraps) do ApplyLook(wraps, look, numColumns) end
    end
    for _, look in ipairs(row.wraps) do ApplyLook(wraps, look, numColumns) end

    for column, cell in pairs(row.cells) do
        local room = numColumns - column + 1
        cell.last = column + (cell.span == ROW and room or math.min(cell.span, room)) - 1
        cell.font = fonts[column]
        cell.wrap = wraps[column]
        cell.justify = cell.align or PickAlign(row.align, column) or PickAlign(section.align, column)
            or PickAlign(body.align, column) or PickAlign(row.tip.columnAlign, column)
            or (column == 1 and "LEFT" or "RIGHT")
        cell.valign = PickValign(row.valign, column) or PickValign(section.valign, column)
            or PickValign(body.valign, column) or "MIDDLE"

        local fontString = GetFontString(row, column)
        if fontString.cachedFont ~= cell.font then
            fontString:SetFontObject(cell.font)
            fontString.cachedFont = cell.font
            fontString.cachedText = nil
        end
        local r, g, b, a = ParseColor(colors[column])
        if r then
            fontString:SetTextColor(r, g, b, a)
        else
            fontString:SetTextColor(cell.font:GetTextColor())
        end
        local text = cell.text
        local secret = IsSecret(text)
        if secret or fontString.cachedText ~= text then
            fontString:SetText(text)
            local measured = MeasureText(fontString)
            fontString.cachedWidth = IsSecret(measured) and 0 or math.ceil(measured)
            fontString.cachedText = not secret and text or nil
        end
        fontString:SetWordWrap(cell.wrap ~= nil)
        local width = fontString.cachedWidth
        if cell.wrap then width = math.min(width, cell.wrap) end
        cell.width = width
        if cell.last == column then
            widths[column] = math.max(widths[column], width)
        end
    end
end

-- PlaceCells - Positions the cells of a text row; returns the row height.
local function PlaceCells(row, layout)
    local offsets, widths = layout.offsets, layout.widths
    local height = 0
    for column, cell in pairs(row.cells) do
        local fontString = row.fontStrings[column]
        local width = offsets[cell.last] + widths[cell.last] - offsets[column]
        fontString:SetWidth(width)
        -- SetWrap, or a column squeezed by maxWidth: the text wraps instead of overflowing.
        fontString:SetWordWrap(cell.wrap ~= nil or cell.width > width)
        fontString:SetJustifyH(cell.justify)
        local _, fontHeight = cell.font:GetFont()
        local stringHeight = fontString:GetStringHeight()
        if IsSecret(stringHeight) then stringHeight = 0 end
        cell.height = math.max(stringHeight, fontHeight or 0)
        height = math.max(height, cell.height)
    end
    if height == 0 then
        local _, fontHeight = row.section.defaultFont:GetFont()
        height = fontHeight or 12
    end
    height = math.ceil(height)
    for column, cell in pairs(row.cells) do
        local fontString = row.fontStrings[column]
        local offset = layout.rowSpacing / 2
        if cell.valign == "MIDDLE" then
            offset = offset + (height - cell.height) / 2
        elseif cell.valign == "BOTTOM" then
            offset = offset + height - cell.height
        end
        fontString:ClearAllPoints()
        fontString:SetPoint("TOPLEFT", row, "TOPLEFT", offsets[column], -offset)
        fontString:Show()
    end
    -- Columns covered by a merged cell keep a font string from an earlier layout.
    for column, fontString in pairs(row.fontStrings) do
        if not row.cells[column] then fontString:Hide() end
    end
    return height + layout.rowSpacing
end

-- PlaceArea - Sizes an area texture over columns first-last (half the column gap on the inner sides).
local function PlaceArea(texture, row, first, last, layout, height)
    local left, right
    if first == 1 then
        left = 0
    else
        left = layout.offsets[first] - layout.columnGap / 2
    end
    if last == layout.numColumns then
        right = layout.totalWidth
    else
        right = layout.offsets[last] + layout.widths[last] + layout.columnGap / 2
    end
    local width = math.max(right - left, 1)
    texture:SetPoint("TOPLEFT", row, "TOPLEFT", left, 0)
    texture:SetSize(width, height)
    return width
end

-- AddHover - One highlight texture over columns first-last, shown while the mouse is over the row.
local function AddHover(row, fill, alpha, first, last, layout, height)
    local texture = AcquireTexture(row, "BORDER", 0)
    if fill == nil then
        texture:SetTexture(HIGHLIGHT_TEXTURE)
        texture:SetBlendMode("ADD")
    elseif ApplyFill(texture, fill) then
        texture:SetBlendMode("ADD")
    end
    if alpha then texture:SetAlpha(alpha) end
    PlaceArea(texture, row, first, last, layout, height)
    texture:Hide()
    row.hover[#row.hover + 1] = texture
end

-- AddHandlerHovers - The default highlight over the areas of each OnClick / OnWheel handler.
local function AddHandlerHovers(row, handlers, fill, alpha, layout, height)
    for _, handler in ipairs(handlers) do
        local areas, count = GetAreas(handler, layout.numColumns)
        for index = 1, count, 2 do
            AddHover(row, fill, alpha, areas[index], areas[index + 1], layout, height)
        end
    end
end

-- DrawAreas - Backgrounds, bars and hover highlights of a row.
local function DrawAreas(row, layout, height)
    local numColumns = layout.numColumns
    local settings = row.tip.settings

    for _, look in ipairs(row.backgrounds) do
        local areas, count = GetAreas(look, numColumns)
        for index = 1, count, 2 do
            local texture = AcquireTexture(row, "BACKGROUND", 1)
            ApplyFill(texture, look.value)
            PlaceArea(texture, row, areas[index], areas[index + 1], layout, height)
            texture:Show()
        end
    end

    for _, look in ipairs(row.bars) do
        local bar = look.value
        local ratio = bar.max > 0 and math.max(0, math.min(1, bar.value / bar.max)) or 0
        if ratio > 0 then
            local areas, count = GetAreas(look, numColumns)
            for index = 1, count, 2 do
                local texture = AcquireTexture(row, "BACKGROUND", 2)
                ApplyFill(texture, bar.fill or settings.bar.fill)
                local width = PlaceArea(texture, row, areas[index], areas[index + 1], layout, height)
                texture:SetWidth(math.max(width * ratio, 1))
                texture:SetAlpha(tonumber(settings.bar.alpha) or 1)
                texture:Show()
            end
        end
    end

    -- Own SetHighlight calls; otherwise clickable and wheel rows get the default one over their areas.
    if #row.highlights > 0 then
        for _, look in ipairs(row.highlights) do
            local areas, count = GetAreas(look, numColumns)
            for index = 1, count, 2 do
                AddHover(row, look.value, nil, areas[index], areas[index + 1], layout, height)
            end
        end
    elseif #row.clicks > 0 or #row.wheels > 0 then
        local base = row.baseHighlight
        local fill = base and base.value or settings.highlight.fill
        local alpha = tonumber(settings.highlight.alpha) or 1
        if base and base.mask.n > 0 then
            local areas, count = GetAreas(base, numColumns)
            for index = 1, count, 2 do
                AddHover(row, fill, alpha, areas[index], areas[index + 1], layout, height)
            end
        else
            AddHandlerHovers(row, row.clicks, fill, alpha, layout, height)
            AddHandlerHovers(row, row.wheels, fill, alpha, layout, height)
        end
    end
end

-- PlaceSection - Positions the rows of a part; returns the part's height.
local function PlaceSection(section, layout)
    local y = 0
    for index = 1, section.rowCount do
        local row = section.rows[index]
        ReleaseTextures(row)
        local height
        if row.kind == "separator" then
            height = row.space
        elseif row.kind == "image" then
            row.image:ClearAllPoints()
            row.image:SetPoint(row.imageJustify, row, row.imageJustify)
            row.image:Show()
            height = row.imageHeight + layout.rowSpacing
        else
            height = PlaceCells(row, layout)
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", section.parent, "TOPLEFT", 0, -y)
        row:SetSize(math.max(layout.totalWidth, 1), height)
        DrawAreas(row, layout, height)
        row:Show()
        if row:IsMouseOver() then ShowHover(row) end
        y = y + height
    end
    for index = section.rowCount + 1, #section.rows do
        section.rows[index]:Hide()
    end
    return y
end

local capSorted = {}  -- reused by CapWidths
local function Descending(a, b) return a > b end

--[[ CapWidths
     Purpose:  Narrows the widest columns to one common width so the columns lose excess pixels in total
               (maxWidth). Narrower columns are untouched; their text wraps in PlaceCells. ]]
local function CapWidths(widths, numColumns, excess)
    wipe(capSorted)
    for column = 1, numColumns do capSorted[column] = widths[column] end
    table.sort(capSorted, Descending)
    local level, sum = 0, 0
    for index = 1, numColumns do
        sum = sum + capSorted[index]
        local nextWidth = capSorted[index + 1] or 0
        -- Lowering the widest index columns to nextWidth would remove sum - index * nextWidth pixels.
        if sum - index * nextWidth >= excess then
            level = (sum - excess) / index
            break
        end
    end
    level = math.max(math.floor(level), MIN_COLUMN_WIDTH)
    for column = 1, numColumns do
        widths[column] = math.min(widths[column], level)
    end
end

-- PlaceBackground - The background texture of a part, reaching into the padding.
local function PlaceBackground(section, padding, sectionGap)
    local background = section.background
    background:ClearAllPoints()
    background:SetPoint("TOPLEFT", section.frame, "TOPLEFT", -(padding - 4), sectionGap / 2)
    background:SetPoint("BOTTOMRIGHT", section.frame, "BOTTOMRIGHT", padding - 4, -sectionGap / 2)
end

--[[ Layout
     Purpose:  Measures every cell, sizes the columns (shared by header, body and footer), places the rows
               and sets up scrolling of the body. Called automatically; addon code never needs it. ]]
function Layout(tip)
    tip.layoutPending = false
    local sections = tip.sections
    local settings = tip.settings
    local padding = tonumber(settings.padding) or 0
    local columnGap = tonumber(settings.columnGap) or 0
    local rowSpacing = tonumber(settings.rowSpacing) or 0
    local sectionGap = tonumber(settings.sectionGap) or 0

    -- Column count: the Open columns, the widest row or the longest SetAlign list.
    local numColumns = math.max(1, tip.fixedColumns or 0)
    for _, section in ipairs(sections) do
        numColumns = math.max(numColumns, section.align and section.align.n or 0)
        for index = 1, section.rowCount do
            numColumns = math.max(numColumns, section.rows[index].columnCount or 0)
        end
    end

    -- One layout table per tooltip, reused by every layout.
    local layout = tip.layoutData
    if not layout then
        layout = { widths = {}, offsets = {} }
        tip.layoutData = layout
    end
    local widths, offsets = layout.widths, layout.offsets
    for column = 1, numColumns do widths[column] = 0 end
    local imageWidth = 0

    -- Pass 1: text, font, color; cells ending in a column set its width.
    for _, section in ipairs(sections) do
        for index = 1, section.rowCount do
            local row = section.rows[index]
            if row.kind == "image" then
                imageWidth = math.max(imageWidth, row.imageWidth)
            elseif row.kind == "text" then
                PrepareRow(row, numColumns, widths)
            end
        end
    end

    -- Pass 2: merged cells widen their last column when they do not fit.
    for _, section in ipairs(sections) do
        for index = 1, section.rowCount do
            local row = section.rows[index]
            if row.kind == "text" then
                for column, cell in pairs(row.cells) do
                    if cell.last > column then
                        local available = (cell.last - column) * columnGap
                        for spanned = column, cell.last do available = available + widths[spanned] end
                        if cell.width > available then
                            widths[cell.last] = widths[cell.last] + cell.width - available
                        end
                    end
                end
            end
        end
    end

    local totalWidth = (numColumns - 1) * columnGap
    for column = 1, numColumns do totalWidth = totalWidth + widths[column] end
    local minWidth = math.max((tip.minWidth or 0) - 2 * padding, imageWidth)
    if totalWidth < minWidth then
        widths[numColumns] = widths[numColumns] + minWidth - totalWidth
        totalWidth = minWidth
    end
    if tip.maxWidth then
        local room = math.max(tip.maxWidth - 2 * padding, 1)
        if totalWidth > room then
            CapWidths(widths, numColumns, totalWidth - room)
            totalWidth = (numColumns - 1) * columnGap
            for column = 1, numColumns do totalWidth = totalWidth + widths[column] end
        end
    end

    local x = 0
    for column = 1, numColumns do
        offsets[column] = x
        x = x + widths[column] + columnGap
    end
    layout.numColumns = numColumns
    layout.totalWidth = totalWidth
    layout.columnGap = columnGap
    layout.rowSpacing = rowSpacing
    tip.layout = layout

    -- Pass 3: place the rows of each part.
    local headerHeight = PlaceSection(tip.header, layout)
    local bodyHeight = PlaceSection(tip.body, layout)
    local footerHeight = PlaceSection(tip.footerSection, layout)

    -- Pass 4: stack header, body and footer; only the body scrolls.
    local headerGap = (headerHeight > 0 and (bodyHeight > 0 or footerHeight > 0)) and sectionGap or 0
    local footerGap = (footerHeight > 0 and bodyHeight > 0) and sectionGap or 0
    local maxHeight = tip.maxHeight or UIParent:GetHeight() * DEFAULT_MAX_HEIGHT
    local bodyRoom = math.max(maxHeight - 2 * padding - headerHeight - headerGap - footerGap - footerHeight,
        MIN_BODY_HEIGHT)
    local visibleBody = math.min(bodyHeight, bodyRoom)
    local scrolling = bodyHeight > bodyRoom
    local width = math.max(totalWidth, 1)

    local y = padding
    tip.header.frame:ClearAllPoints()
    tip.header.frame:SetPoint("TOPLEFT", tip, "TOPLEFT", padding, -y)
    tip.header.frame:SetSize(width, math.max(headerHeight, 1))
    tip.header.frame:SetShown(headerHeight > 0)
    y = y + headerHeight + headerGap

    tip.scroll:ClearAllPoints()
    tip.scroll:SetPoint("TOPLEFT", tip, "TOPLEFT", padding, -y)
    tip.scroll:SetSize(width, math.max(visibleBody, 1))
    tip.content:SetSize(width, math.max(bodyHeight, 1))
    y = y + visibleBody + footerGap

    tip.footerSection.frame:ClearAllPoints()
    tip.footerSection.frame:SetPoint("TOPLEFT", tip, "TOPLEFT", padding, -y)
    tip.footerSection.frame:SetSize(width, math.max(footerHeight, 1))
    tip.footerSection.frame:SetShown(footerHeight > 0)
    y = y + footerHeight + padding

    for _, section in ipairs(sections) do
        PlaceBackground(section, padding, sectionGap)
    end

    local extraRight = (scrolling and SCROLLBAR_WIDTH or 0) + (tip.settings.closeButton and CLOSE_BUTTON_SPACE or 0)
    tip:SetSize(totalWidth + 2 * padding + extraRight, y)

    if scrolling then
        local position = math.min(tip.scrollBar:GetValue(), bodyHeight - visibleBody)
        tip.scrollBar:SetMinMaxValues(0, bodyHeight - visibleBody)
        tip.scrollBar:SetValue(position)
        tip.scroll:SetVerticalScroll(position)
        tip.scrollBar:Show()
        tip.scroll:EnableMouseWheel(true)
    else
        tip.scrollBar:SetMinMaxValues(0, 0)
        tip.scrollBar:SetValue(0)
        tip.scroll:SetVerticalScroll(0)
        tip.scrollBar:Hide()
        tip.scroll:EnableMouseWheel(false)
    end
end

--------------------------------------------------------------------------------
-- Tooltip frames
--------------------------------------------------------------------------------

local function Scroll_OnMouseWheel(scroll, delta)
    local tip = scroll:GetParent()
    local bar = tip.scrollBar
    bar:SetValue(bar:GetValue() - delta * (tonumber(tip.settings.wheelStep) or 40))
end

local function ScrollBar_OnValueChanged(bar, value)
    bar:GetParent().scroll:SetVerticalScroll(value)
end

local function Tooltip_OnHide(tip)
    -- Hidden from outside (e.g. the UI was hidden with Alt+Z): release it properly.
    if tip.isOpen then PixieTooltip:Close(tip.key) end
end

--[[ CreateSection
     Purpose:  A part object (header, body or footer).
     Params:   tip, name ("header"|"body"|"footer"),
               parent (frame the rows live in), area (frame the part occupies on the tooltip) ]]
local function CreateSection(tip, name, parent, area)
    local section = Mixin({}, SectionMixin)
    section.tip = tip
    section.name = name
    section.parent = parent
    section.frame = area
    section.rows = {}
    section.rowCount = 0
    section.wraps = {}
    section.align = { n = 0 }
    section.valign = { n = 0 }
    section.lookPool, section.lookCount = {}, 0
    section.defaultFont = ResolveFont(SECTION_FONTS[name]) or GameTooltipText
    -- On the tooltip itself, so the scroll frame never clips it.
    section.background = tip:CreateTexture(nil, "BACKGROUND", nil, 2)
    section.background:Hide()
    return section
end

-- CreateTooltip - New tooltip frame with header, scrolling body, footer and scroll bar.
local function CreateTooltip()
    -- TooltipBackdropTemplate gives the native tooltip look; older clients fall back to a backdrop.
    local ok, tip = pcall(CreateFrame, "Frame", nil, UIParent, "TooltipBackdropTemplate")
    if not ok or not tip then
        -- BackdropTemplate: 9.0+ and the modern Classic clients; earlier frames have SetBackdrop natively.
        tip = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        tip:SetBackdrop(FALLBACK_BACKDROP)
        tip:SetBackdropColor(0, 0, 0, 0.9)
        tip:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end
    Mixin(tip, TooltipMixin)
    tip:SetClampedToScreen(true)
    tip:EnableMouse(true)
    tip:Hide()
    tip:SetScript("OnHide", Tooltip_OnHide)

    tip.backgroundImage = tip:CreateTexture(nil, "BACKGROUND", nil, 1)
    tip.backgroundImage:SetPoint("TOPLEFT", 4, -4)
    tip.backgroundImage:SetPoint("BOTTOMRIGHT", -4, 4)
    tip.backgroundImage:Hide()

    local headerFrame = CreateFrame("Frame", nil, tip)
    local footerFrame = CreateFrame("Frame", nil, tip)

    tip.scroll = CreateFrame("ScrollFrame", nil, tip)
    tip.scroll:SetScript("OnMouseWheel", Scroll_OnMouseWheel)
    tip.content = CreateFrame("Frame", nil, tip.scroll)
    tip.content:SetSize(1, 1)
    tip.scroll:SetScrollChild(tip.content)

    local bar = CreateFrame("Slider", nil, tip)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(SCROLLBAR_WIDTH - 4)
    bar:SetPoint("TOPLEFT", tip.scroll, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", tip.scroll, "BOTTOMRIGHT", 4, 0)
    bar:SetThumbTexture(SCROLL_KNOB_TEXTURE)
    bar:GetThumbTexture():SetSize(SCROLLBAR_WIDTH + 6, 24)
    bar:EnableMouse(true)  -- needed to drag the thumb
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0, 0, 0, 0.4)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    bar:SetScript("OnValueChanged", ScrollBar_OnValueChanged)
    bar:Hide()
    tip.scrollBar = bar

    tip.header = CreateSection(tip, "header", headerFrame, headerFrame)
    tip.body = CreateSection(tip, "body", tip.content, tip.scroll)
    -- The footer part always exists inside; tip.footer is set only when footer.enabled.
    tip.footerSection = CreateSection(tip, "footer", footerFrame, footerFrame)
    tip.sections = { tip.header, tip.body, tip.footerSection }
    return tip
end

-- Opposite points for anchor.point: the tooltip's point that touches the anchor's point.
local OPPOSITE_VERTICAL = { TOP = "BOTTOM", BOTTOM = "TOP" }
local OPPOSITE_HORIZONTAL = { LEFT = "RIGHT", RIGHT = "LEFT" }

--[[ PlaceTooltip
     Purpose:  Positions the tooltip next to its anchor (anchor.point, anchor.gap) or at the cursor
               (anchor.cursor). Automatic: towards the middle of the screen. ]]
local function PlaceTooltip(tip, anchor)
    local settings = tip.settings.anchor
    local gap = tonumber(settings.gap) or 0
    tip:ClearAllPoints()

    local x, y
    if anchor and anchor.GetCenter then x, y = anchor:GetCenter() end
    if not x then
        local cursor = type(settings.cursor) == "table" and settings.cursor or { 10, -10 }
        local scale = tip:GetEffectiveScale()
        local cursorX, cursorY = GetCursorPosition()
        tip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            cursorX / scale + (cursor[1] or 0), cursorY / scale + (cursor[2] or 0))
        return
    end

    local point = type(settings.point) == "string" and settings.point:upper() or nil
    if point == "CENTER" then
        tip:SetPoint("CENTER", anchor, "CENTER")
        return
    end
    if point then
        local vertical = point:match("^(TOP)") or point:match("^(BOTTOM)")
        local horizontal = point:match("(LEFT)$") or point:match("(RIGHT)$") or ""
        if vertical then
            -- Above or below the anchor; the horizontal part keeps the edges aligned.
            local offsetY = vertical == "TOP" and gap or -gap
            tip:SetPoint(OPPOSITE_VERTICAL[vertical] .. horizontal, anchor, point, 0, offsetY)
            return
        elseif OPPOSITE_HORIZONTAL[point] then
            local offsetX = point == "RIGHT" and gap or -gap
            tip:SetPoint(OPPOSITE_HORIZONTAL[point], anchor, point, offsetX, 0)
            return
        end
    end

    -- Automatic: below an anchor in the upper half of the screen, above it in the lower half.
    local scale = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    x, y = x * scale, y * scale
    local screenWidth = UIParent:GetWidth()
    local vertical = y > UIParent:GetHeight() / 2 and "TOP" or "BOTTOM"
    local opposite = OPPOSITE_VERTICAL[vertical]
    local horizontal = (x < screenWidth / 3 and "LEFT") or (x > screenWidth * 2 / 3 and "RIGHT") or ""
    tip:SetPoint(vertical .. horizontal, anchor, opposite .. horizontal, 0, vertical == "TOP" and -gap or gap)
end

-- IsMouseOverTooltip - True when the mouse is over the tooltip or its visible anchor.
local function IsMouseOverTooltip(tip)
    local anchor = tip.anchor
    return tip:IsMouseOver() or (anchor and anchor.IsMouseOver and anchor:IsVisible() and anchor:IsMouseOver()) or false
end

-- StopTickers - Cancels the auto-hide and auto-refresh tickers.
local function StopTickers(tip)
    if tip.hideTicker then
        tip.hideTicker:Cancel()
        tip.hideTicker = nil
    end
    if tip.refreshTicker then
        tip.refreshTicker:Cancel()
        tip.refreshTicker = nil
    end
end

--[[ StartTickers
     Purpose:  Auto-hide: closes the tooltip once the mouse has been away from it and its anchor for autoHide
               seconds. The countdown only starts after the mouse has been over the tooltip or its anchor once,
               so a tooltip opened from a slash command, a click elsewhere or at the cursor stays open until the
               mouse has visited it.
               Auto-refresh: reruns the build function every refresh seconds. ]]
local function StartTickers(tip)
    StopTickers(tip)
    if tip.autoHide then
        local armed = IsMouseOverTooltip(tip)
        local away = 0
        tip.hideTicker = C_Timer.NewTicker(AUTO_HIDE_STEP, function()
            if IsMouseOverTooltip(tip) then
                armed = true
                away = 0
                return
            end
            if not armed then return end
            away = away + AUTO_HIDE_STEP
            if away >= tip.autoHide then tip:Close() end
        end)
    end
    if tip.refresh then
        tip.refreshTicker = C_Timer.NewTicker(tip.refresh, function() tip:Refresh() end)
    end
end

--------------------------------------------------------------------------------
-- Panel settings: movable, closeButton, escape
--------------------------------------------------------------------------------

local function Tooltip_OnDragStart(tip)
    tip:StartMoving()
end

local function Tooltip_OnDragStop(tip)
    tip:StopMovingOrSizing()
end

-- ApplyMovable - Left-button drag moves the tooltip (rows with mouse handlers keep their own clicks).
local function ApplyMovable(tip, enabled)
    tip:SetMovable(enabled)
    if enabled then
        tip:RegisterForDrag("LeftButton")
        tip:SetScript("OnDragStart", Tooltip_OnDragStart)
        tip:SetScript("OnDragStop", Tooltip_OnDragStop)
    else
        tip:RegisterForDrag()
        tip:SetScript("OnDragStart", nil)
        tip:SetScript("OnDragStop", nil)
    end
end

local function CloseButton_OnClick(button)
    button:GetParent():Close()
end

--[[ ApplyCloseButton
     Purpose:  The Blizzard close button (X) in the top right corner. The NoScripts template has the look without
               Blizzard's panel-manager click handler (which would taint it); the click only closes this tooltip. ]]
local function ApplyCloseButton(tip, enabled)
    if enabled and not tip.closeButton then
        local ok, button = pcall(CreateFrame, "Button", nil, tip, "UIPanelCloseButtonNoScripts")
        if not ok or not button then
            button = CreateFrame("Button", nil, tip, "UIPanelCloseButton")
        end
        button:SetScript("OnClick", CloseButton_OnClick)
        button:SetSize(22, 22)
        button:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -2, -2)
        tip.closeButton = button
    end
    if tip.closeButton then
        tip.closeButton:SetShown(enabled)
    end
end

local escapeCount = 0

--[[ ApplyEscape
     Purpose:  Esc closes the tooltip, like Blizzard windows: UISpecialFrames lists global names, so the tooltip
               gets one (starting with the addon name) only while escape is on. ]]
local function ApplyEscape(tip, enabled)
    if not tip.escapeName then
        escapeCount = escapeCount + 1
        tip.escapeName = (addonName:gsub("[^%w_]", "")) .. "_PixieTooltipFrame" .. escapeCount
    end
    local name = tip.escapeName
    local listed
    for index, entry in ipairs(UISpecialFrames) do
        if entry == name then
            listed = index
            break
        end
    end
    if enabled then
        _G[name] = tip
        if not listed then table.insert(UISpecialFrames, name) end
    else
        _G[name] = nil
        if listed then table.remove(UISpecialFrames, listed) end
    end
end

--------------------------------------------------------------------------------
-- Public API: private.PixieTooltip
--------------------------------------------------------------------------------

--[[ Open
     Purpose:  Opens (or rebuilds) a tooltip next to an anchor frame.
     Params:   anchor (Frame, or nil for the mouse cursor),
               build (function(tip, header[, footer])) - adds the rows; runs again on every Refresh.
                     footer is passed only when footer.enabled,
               columns (optional) - a number, or a list of "LEFT"/"CENTER"/"RIGHT" (its length is the count);
                     nil: the columns setting, else automatic,
               noCombat (optional) - false also opens in combat; nil: the noCombat setting (default true),
               options (optional table) - any SetDefaults setting for this tooltip, plus
                     key (default: the addon name), refresh (seconds) and onClose (function(tip)).
     Returns:  the tooltip, or nil when blocked in combat ]]
function PixieTooltip:Open(anchor, build, columns, noCombat, options)
    options = options or {}
    local settings = ResolveSettings(options)
    if columns == nil then columns = settings.columns end
    if noCombat == nil then noCombat = settings.noCombat end
    if noCombat and InCombatLockdown() then return nil end

    local key = options.key or addonName
    local tip = openTooltips[key]
    if not tip then
        tip = table.remove(freeTooltips) or CreateTooltip()
        openTooltips[key] = tip
        tip.key = key
        tip.scrollBar:SetValue(0)
    end
    tip.isOpen = true
    tip.anchor = anchor
    tip.build = build
    tip.settings = settings
    tip.onClose = options.onClose
    local refresh = tonumber(options.refresh)
    tip.refresh = refresh and refresh > 0 and refresh or nil

    if settings.autoHide == false then
        tip.autoHide = nil
    else
        tip.autoHide = tonumber(settings.autoHide) or DEFAULT_AUTO_HIDE
    end
    tip.minWidth = tonumber(settings.minWidth)
    if settings.maxWidth == false then
        tip.maxWidth = nil
    else
        tip.maxWidth = tonumber(settings.maxWidth) or UIParent:GetWidth() * DEFAULT_MAX_WIDTH
    end
    tip.maxHeight = tonumber(settings.maxHeight)

    -- Fixed columns: a count, or a list of alignments (its length is the count).
    if type(columns) == "table" then
        tip.columnAlign = columns
        tip.fixedColumns = #columns
    else
        tip.columnAlign = nil
        tip.fixedColumns = tonumber(columns)
    end

    tip.footer = settings.footer.enabled and tip.footerSection or nil

    -- Before the build, so tip:SetScale / tip:SetFrameStrata in it win.
    tip:SetScale(tonumber(settings.scale) or 1)
    tip:SetFrameStrata(settings.strata or "TOOLTIP")
    ApplyMovable(tip, settings.movable == true)
    ApplyCloseButton(tip, settings.closeButton == true)
    ApplyEscape(tip, settings.escape == true)

    PlaceTooltip(tip, anchor)
    tip:Refresh()
    tip:Show()
    StartTickers(tip)
    return tip
end

-- Close - Hides and releases the tooltip of a key (default: the addon name).
function PixieTooltip:Close(key)
    local tip = openTooltips[key or addonName]
    if not tip then return end
    openTooltips[tip.key] = nil
    tip.isOpen = false
    StopTickers(tip)
    HideHint(tip)
    tip:Hide()
    local onClose = tip.onClose
    tip.onClose = nil
    if onClose then
        local ok, err = pcall(onClose, tip)
        if not ok then geterrorhandler()(addonName .. " [PixieTooltip]: " .. tostring(err)) end
    end
    for _, section in ipairs(tip.sections) do
        ResetSection(section)
    end
    ResetFrameLook(tip)
    ApplyMovable(tip, false)
    ApplyCloseButton(tip, false)
    ApplyEscape(tip, false)
    tip.build = nil
    tip.anchor = nil
    tip.footer = nil
    tip.columnAlign = nil
    tip.fixedColumns = nil
    tip.layout = nil
    tip.layoutPending = false
    table.insert(freeTooltips, tip)
end

-- Refresh - Rebuilds an open tooltip (no-op when it is closed). Handy from event or callback handlers.
function PixieTooltip:Refresh(key)
    local tip = openTooltips[key or addonName]
    if tip then tip:Refresh() end
end

-- IsOpen - True when the tooltip of the key is open.
function PixieTooltip:IsOpen(key)
    return openTooltips[key or addonName] ~= nil
end

-- Get - The open tooltip of the key, or nil.
function PixieTooltip:Get(key)
    return openTooltips[key or addonName]
end

--[[ Attach
     Purpose:  Opens the tooltip whenever the mouse enters a frame the addon owns.
     Params:   frame (Frame), build, columns, noCombat and options as for Open ]]
function PixieTooltip:Attach(frame, build, columns, noCombat, options)
    frame:HookScript("OnEnter", function(owner)
        PixieTooltip:Open(owner, build, columns, noCombat, options)
    end)
end

--[[ SetDefaults
     Purpose:  Settings for every tooltip of this addon; an Open call's own options override them.
     Params:   settings (table; nil clears them). Every key is optional. key, refresh and onClose belong to
               one tooltip and are ignored here. See DOCUMENTATION.md, 6.6. ]]
function PixieTooltip:SetDefaults(settings)
    wipe(defaults)
    if type(settings) ~= "table" then return end
    for _, name in ipairs(SETTINGS) do
        defaults[name] = settings[name]
    end
end

--------------------------------------------------------------------------------
-- Key bindings: Bind / Unbind (no Bindings.xml)
-- SetOverrideBindingClick clicks a named button, so every bound key gets a hidden button with a global name
-- that starts with the addon name. Bindings cannot change in combat; they are applied when combat ends.
--------------------------------------------------------------------------------

local BIND_PREFIX = (addonName:gsub("[^%w_]", "")) .. "_PixieTooltipKey"
local bindings = {}       -- key -> { name, button, build, columns, noCombat, options }
local bindCount = 0
local bindOwner           -- hidden frame that owns the override bindings
local bindingsPending = false

-- ApplyBindings - Sets every override binding again (later, when called in combat).
local function ApplyBindings()
    if InCombatLockdown() then
        bindingsPending = true
        return
    end
    bindingsPending = false
    ClearOverrideBindings(bindOwner)
    for key, binding in pairs(bindings) do
        SetOverrideBindingClick(bindOwner, true, key, binding.name)
    end
end

-- GetBindOwner - The owner frame, created on first use; it applies pending bindings after combat.
local function GetBindOwner()
    if not bindOwner then
        bindOwner = CreateFrame("Frame")
        bindOwner:RegisterEvent("PLAYER_REGEN_ENABLED")
        bindOwner:SetScript("OnEvent", function()
            if bindingsPending then ApplyBindings() end
        end)
    end
    return bindOwner
end

-- Binding_OnClick - The key was pressed: open the tooltip, or close it when it is open.
local function Binding_OnClick(button)
    local binding = button.binding
    local options = binding.options or {}
    local key = options.key or addonName
    if PixieTooltip:IsOpen(key) then
        PixieTooltip:Close(key)
        return
    end
    -- With an anchor.point (option or default) it opens relative to the screen, otherwise at the mouse cursor.
    local point = (type(options.anchor) == "table" and options.anchor.point)
        or (type(defaults.anchor) == "table" and defaults.anchor.point)
    PixieTooltip:Open(point and UIParent or nil, binding.build, binding.columns, binding.noCombat, options)
end

--[[ Bind
     Purpose:  A key (e.g. "F12", "CTRL-SHIFT-P") opens the tooltip, and closes it when pressed again.
     Params:   key (string, Blizzard notation), then build, columns, noCombat and options as for Open.
               Binding the same key again replaces it. The override is stronger than the game's own binding
               of that key while it is set. ]]
function PixieTooltip:Bind(key, build, columns, noCombat, options)
    if type(key) ~= "string" or key == "" then return end
    key = key:upper()
    local owner = GetBindOwner()
    local binding = bindings[key]
    if not binding then
        bindCount = bindCount + 1
        local name = BIND_PREFIX .. bindCount
        local button = CreateFrame("Button", name, owner)
        button:SetScript("OnClick", Binding_OnClick)
        binding = { name = name, button = button }
        button.binding = binding
        bindings[key] = binding
    end
    binding.build = build
    binding.columns = columns
    binding.noCombat = noCombat
    binding.options = options
    ApplyBindings()
end

-- Unbind - Removes the binding of a key; the key does its normal job again.
function PixieTooltip:Unbind(key)
    if type(key) ~= "string" then return end
    key = key:upper()
    if not bindings[key] then return end
    bindings[key] = nil
    ApplyBindings()
end
