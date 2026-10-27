# Pixie Tooltip - Documentation

Rich multi-column tooltips for WoW addons from one build function: merged cells, fixed header and footer, progress bars, images and hover hints. Rows react to clicks and the mouse wheel, long lists scroll, and Refresh redraws it live. One mixin-based Lua file on Blizzard functions only: no libraries, no globals. Retail and Classic.

What that means:

**1. Multi-column**

A row can have as many columns as you need, each aligned left, center or right. Cells can be merged across
columns.

```
Name         Level     Gold     Week
Pixie           80    1234g     +56g
```

**2. Mixin-based**

The tooltip is a normal Blizzard frame with the Pixie Tooltip commands mixed in (Blizzard's `Mixin`).
So every Blizzard frame method still works on it (`tip:SetScale`, `tip:SetFrameStrata`), next to the
Pixie Tooltip commands (`tip:AddRow`). The file name ends in `Mixin` to show this.

**3. Interactive**

Rows react to the mouse: clicks, the mouse wheel, and hints shown beside the tooltip on hover.
The tooltip stays open while the mouse is over it, so the rows can be used.

**4. No libraries**

Nothing to install next to it: no LibStub, no LibQTip, no CallbackHandler. One file, built only on Blizzard's
own functions.

**5. No globals**

It creates no global variables. It lives in the private table of the addon that loads it, so two addons that
use it never interfere.

**6. Clients**

Retail (Midnight), Mists of Pandaria Classic, Burning Crusade Classic Anniversary, Classic Era and WoW: Forever.

**Contents**

1. [Setup](#1-setup)
2. [Concepts](#2-concepts)
3. [Level 1 - Simple](#3-level-1---simple)
4. [Level 2 - Advanced](#4-level-2---advanced)
5. [Level 3 - Expert](#5-level-3---expert)
6. [Reference](#6-reference)
7. [Coming from LibQTip](#7-coming-from-libqtip)
8. [Behavior notes](#8-behavior-notes)

---

## 1. Setup

**1. Add the file to the TOC**

```
PixieTooltipMixin.lua
Core.lua
```

`PixieTooltipMixin.lua` must come before every file that uses it.

**2. Get it in your file**

```lua
local addonName, private = ...
local PixieTooltip = private.PixieTooltip
```

Put these two lines at the top of every file that opens a tooltip.

**3. Get the markers (only if you need them)**

```lua
local CELL, ROW = PixieTooltip.CELL, PixieTooltip.ROW
```

Add this line under the other two when the file merges cells or uses masks (3.3, 5.1).
Without it `CELL` and `ROW` are `nil`: nothing merges, and you get no error message.

---

## 2. Concepts

### 2.1 The build function

**1. You write one function that describes the tooltip**

```lua
local function Build(tip, header)
    header:AddRow("My Addon")
    tip:AddRow("Gold", GetMoneyString(GetMoney(), true))
end
```

This function lists everything the tooltip shows. It does not open anything by itself.

**2. You give it to Open**

```lua
PixieTooltip:Open(anchor, Build)
```

Pass the name only, without `()`. Pixie Tooltip calls the function for you.

**3. Pixie Tooltip runs it again whenever needed**

It runs when the tooltip opens and on every `Refresh` (after a click, on an event, on a timer).
You never change a single cell: `Refresh` draws everything again from your data. The scroll position is kept.

### 2.2 Targets

The build function gets the parts of the tooltip as parameters. The same commands work on every part.

**1. `tip` - the middle part (and the whole tooltip)**

```lua
tip:AddRow("Gold", "123g")
```

The main content. It scrolls when it is taller than the screen allows. `tip` also stands for the whole
tooltip (`tip:Refresh()`, `tip:Close()`).

**2. `header` - the top**

```lua
header:AddRow("My Addon")
```

Fixed at the top, in a big font. It does not scroll. Always there.

**3. `footer` - the bottom (only when switched on)**

```lua
footer:AddRow({ "Click: open", ROW })
```

Fixed at the bottom, in a small grey font. It does not scroll. It exists only when you switch it on (4.3).

**4. `row` - one row**

```lua
local row = tip:AddRow("Gold", "123g")
row:SetColor("ffcc00")
```

Every `Add...` command returns the row it made, so you can change its look.

So the build function has one of these two forms:

```lua
local function Build(tip, header)            -- default
local function Build(tip, header, footer)    -- footer switched on
```

An empty part takes no space. The order of the commands does not matter: a header row added last is still
at the top.

### 2.3 Verbs

The first word of every command tells what it does.

**1. `Add...` - adds content**

`AddRow`, `AddSeparator`, `AddImage`.

**2. `Set...` - changes the look or a setting**

`SetColor`, `SetFont`, `SetBar`, `SetAlign`, `SetDefaults`, ...

**3. `On...` - reacts to the mouse**

`OnClick`, `OnWheel`, `OnHover`.

**4. No verb - opens, closes, rebuilds**

`Open`, `Close`, `Refresh`, `Attach`, `IsOpen`, `Get`.

No name is shared with GameTooltip (`AddLine`, `SetText`, ...), so the two are never mixed up.

### 2.4 Who wins

A setting can come from four places. The later one always wins.

**1. Built-in value**

Always there: native tooltip look, 2 columns for two values, no combat, ...

**2. `PixieTooltip:SetDefaults({ ... })`**

Once, at the top of the addon. For every tooltip of the addon.

**3. `PixieTooltip:Open(anchor, build, columns, noCombat, options)`**

When one tooltip opens. Only for that tooltip.

**4. `tip:Set...`, `header:Set...`, `row:Set...`**

Inside the build function. Only for that content.

```
built-in  ->  SetDefaults  ->  Open  ->  Set...
```

### 2.5 Markers: CELL and ROW

**1. `CELL` - this column belongs to the one before**

```lua
tip:AddRow({ "Character", CELL }, "Gold")      -- "Character" over columns 1-2
```

**2. `ROW` - to the end of the row**

```lua
tip:AddRow("Name", { "Note", ROW })            -- "Note" over column 2 and every column after it
```

The two markers mean the same in merged cells (3.3) and in masks (5.1).

### 2.6 Levels

**1. Simple (chapter 3)**

Open a tooltip with rows, a header, merged cells, lines, clicks and hints.

**2. Advanced (chapter 4)**

One style for the whole addon, options of one tooltip, footer, row and part looks, bars, images.

**3. Expert (chapter 5)**

Single cells (masks), per-cell clicks, wrapping, own fonts, every default.

---

## 3. Level 1 - Simple

### 3.1 Open

There are three simple ways to open a tooltip. Use the shortest one that does what you need.

**1. Automatic**

```lua
PixieTooltip:Open(anchor, Build)
```

As many columns as the widest row; the first column left, the others right. Does not open in combat.
Enough for most tooltips.

**2. With a column count**

```lua
PixieTooltip:Open(anchor, Build, 4)
```

Always 4 columns, even when a row has fewer values: the rows stay aligned. Does not open in combat.

**3. With a column count, also in combat**

```lua
PixieTooltip:Open(anchor, Build, 4, false)
```

The same 4 columns, and `false` lets it open in combat too.

Everything else (`key`, `refresh`, `maxWidth`, ...) is a 5th parameter, see 4.2.

| Parameter | Default | Meaning |
|---|---|---|
| `anchor` | - | The frame the tooltip opens next to (e.g. the broker display in its `OnEnter`). `nil`: at the mouse cursor. |
| `build` | - | Your build function, **without** `()`: `Build`, not `Build()`. |
| `columns` | automatic | Number of columns. |
| `noCombat` | `true` | `true`: does not open in combat. `false`: opens in combat too. |

The tooltip closes by itself shortly after the mouse leaves it and its anchor.

**The build function can also be written into the call**

```lua
PixieTooltip:Open(anchor, function(tip, header)
    header:AddRow("My Addon")
    tip:AddRow("Gold", GetMoneyString(GetMoney(), true))
end)
```

Handy for a short tooltip. For a long one, or one opened from several places, a named `Build` is clearer.

### 3.2 Rows

**1. One value per column**

```lua
tip:AddRow("Gold", "123g")
```

"Gold" goes into column 1, "123g" into column 2.

**2. Numbers**

```lua
tip:AddRow("Level", 80)
```

A number is shown as text; no `tostring` needed.

**3. An empty cell**

```lua
tip:AddRow("Note", nil, "x")
```

`nil` leaves column 2 empty; "x" goes into column 3.

**4. A row in the header**

```lua
header:AddRow("My Addon", "1.0")
```

The same command on `header`: big font, fixed at the top.

### 3.3 Merged cells

A table is one cell that covers several columns: `{ text, CELL..., ROW, align }`.

**1. Over two columns**

```lua
tip:AddRow({ "Character", CELL }, "Gold", "Week")      -- 1-2 | 3 | 4
```

Each `CELL` adds one more column to the cell.

**2. Over three columns**

```lua
tip:AddRow({ "Character", CELL, CELL }, "Week")        -- 1-3 | 4
```

**3. To the end of the row**

```lua
tip:AddRow("Name", { "Note", ROW })                    -- 1 | 2 to the last column
```

`ROW` takes every column that is left, whatever the column count is.

**4. The whole row**

```lua
tip:AddRow({ "Total", ROW })                           -- 1 to the last column
```

**5. With an alignment**

```lua
tip:AddRow({ "Total", ROW, "CENTER" })
```

The last entry of the table may be `"LEFT"`, `"CENTER"` or `"RIGHT"`.

A merged cell never runs past the last column.

### 3.4 Lines and gaps

**1. A line**

```lua
tip:AddSeparator("ffcc00", 1)
```

A gold line, 1 pixel high. It stays sharp at every UI scale.

**2. A gap**

```lua
tip:AddSeparator(nil, 6)
```

No color: an empty space of 6 pixels.

### 3.5 Mouse

**1. Click**

```lua
tip:AddRow("Auto repair", settings.repair and "On" or "Off")
    :OnClick(function(tip, button)
        settings.repair = not settings.repair
        tip:Refresh()
    end)
```

The row lights up under the mouse. `button` is `"LeftButton"`, `"RightButton"`, ...
Call `tip:Refresh()` to draw the new value.

**2. Mouse wheel**

```lua
tip:AddRow("Volume", volume .. "%")
    :OnWheel(function(tip, delta)
        volume = math.max(0, math.min(100, volume + delta * 5))
        tip:Refresh()
    end)
```

`delta` is `1` (wheel up) or `-1` (wheel down).

**3. Hint with a link**

```lua
tip:AddRow("Hearthstone"):OnHover("item:6948")
```

Shows the item's GameTooltip beside the tooltip, level with the row. Works with item, spell and currency
links, short (`"item:6948"`) or full.

**4. Hint with text**

```lua
tip:AddRow("Help"):OnHover("Left click: toggle.")
```

Shows plain text beside the tooltip.

### 3.6 Refresh and close

**1. Refresh from a click handler**

```lua
tip:Refresh()
```

Runs the build function again and draws the new values.

**2. Refresh from anywhere**

```lua
PixieTooltip:Refresh()
```

The same from an event handler or another file. When the tooltip is closed it does nothing.

```lua
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_MONEY")
events:SetScript("OnEvent", function() PixieTooltip:Refresh() end)
```

**3. Close**

```lua
tip:Close()                -- in a click handler
PixieTooltip:Close()       -- from anywhere
```

Usually not needed: the tooltip closes by itself when the mouse leaves.

### 3.7 A complete simple example

```lua
local addonName, private = ...
local PixieTooltip = private.PixieTooltip
local CELL, ROW = PixieTooltip.CELL, PixieTooltip.ROW

local function Build(tip, header)
    header:AddRow("Characters", nil, nil, date("%H:%M"))
    header:AddSeparator("ffcc00", 1)
    tip:AddRow("Name", "Level", "Gold", "Week")
    tip:AddRow("Pixie", 80, "1234g", "+56g")
    tip:AddRow("Healz", 72, "34g")
    tip:AddRow({ "Total", CELL }, "1268g", "+56g")
end

local function OnEnter(display)
    PixieTooltip:Open(display, Build, 4)
end
```

A header with a clock, a table of characters, and a total whose label covers columns 1-2.
"Healz" has no weekly value; thanks to the `4` its row stays aligned.

---

## 4. Level 2 - Advanced

### 4.1 One style for the whole addon: SetDefaults

**1. Call it once**

```lua
PixieTooltip:SetDefaults({
    autoHide = 0.2,
    maxWidth = 350,
    border   = "ffcc00",
})
```

At the top of the addon, outside any function. Every tooltip the addon opens uses these values.

**2. Give only what you change**

```lua
PixieTooltip:SetDefaults({ border = "ffcc00" })
```

Every key is optional. A key you leave out keeps its built-in value.

**3. An Open call still wins**

```lua
PixieTooltip:Open(anchor, BuildDetails, 3, true, { maxWidth = 500 })
```

This tooltip is 500 pixels wide at most; the others keep 350.

The advanced keys (the full list is in 6.6):

| Key | Built-in | Meaning |
|---|---|---|
| `noCombat` | `true` | `false`: tooltips open in combat too |
| `autoHide` | `0.1` | seconds the mouse may be away before it closes; `false`: stays open until `Close` |
| `columns` | automatic | number of columns, or a list of alignments |
| `minWidth` | none | minimum width (pixels) |
| `maxWidth` | 40% of the screen | maximum width; the widest columns wrap their text; `false`: no limit |
| `maxHeight` | 80% of the screen | above this the body scrolls; header and footer stay |
| `scale` | `1` | size of the tooltip |
| `strata` | `"TOOLTIP"` | frame strata |
| `border` | native | border color |
| `background` | native | background color or image |
| `footer.enabled` | `false` | `true`: the footer exists and the build function gets it |

### 4.2 Options of one tooltip

The 5th parameter of `Open` is a table. It takes every `SetDefaults` key, and three more that only make sense
for one tooltip.

**1. `key` - a name for the tooltip**

```lua
PixieTooltip:Open(anchor, BuildDetails, 3, true, { key = "details" })
PixieTooltip:Close("details")
```

Needed only when the addon has more than one tooltip open at a time. Default: the addon name.

**2. `refresh` - redraw on a timer**

```lua
PixieTooltip:Open(anchor, BuildClock, 2, true, { refresh = 1 })
```

The build function runs again every second while the tooltip is open: clocks, cooldowns, FPS.

**3. `onClose` - do something when it closes**

```lua
PixieTooltip:Open(anchor, Build, 2, true, { onClose = function(tip) SaveSettings() end })
```

**4. Any SetDefaults key for this tooltip only**

```lua
PixieTooltip:Open(anchor, Build, 4, true, { maxWidth = 500, border = "ff4040" })
```

**5. Only the options, without columns and noCombat**

```lua
PixieTooltip:Open(anchor, Build, nil, nil, { key = "details" })
```

`nil` keeps the default of a parameter you skip.

**Part tables are merged field by field**

```lua
-- SetDefaults:  footer = { font = GameFontNormalSmall }
-- Open:         footer = { enabled = true }
-- result:       footer = { enabled = true, font = GameFontNormalSmall }
```

`Open` changes only the fields it names; the rest stays as `SetDefaults` set it.

### 4.3 Footer

**1. Switch it on for every tooltip**

```lua
PixieTooltip:SetDefaults({ footer = { enabled = true } })
```

**2. Or for one tooltip**

```lua
PixieTooltip:Open(anchor, Build, 4, true, { footer = { enabled = true } })
```

**3. Use it in the build function**

```lua
local function Build(tip, header, footer)
    header:AddRow("Bags")
    tip:AddRow("Backpack", 4, 16)
    footer:AddRow({ "Click: open all bags", ROW, "CENTER" })
end
```

The build function now gets a third parameter, `footer`. It stays at the bottom while the body scrolls,
in a small grey font.

Without `enabled = true` there is no `footer` parameter; `footer:AddRow` would be an error.

### 4.4 Look of one row

Without a mask (5.1) these commands change the whole row. Every command returns the row, so they chain.

**1. Text color**

```lua
tip:AddRow("Name", "Level", "Gold"):SetColor("ffffff")
```

**2. Font**

```lua
tip:AddRow("Details"):SetFont(GameFontNormalSmall)
```

Any of the font forms in 5.4.

**3. Background**

```lua
tip:AddRow("Name", "Level", "Gold"):SetBackground({ 1, 1, 1, 0.08 })
```

A color or an image behind the row.

**4. Alignment**

```lua
tip:AddRow("A", "B", "C"):SetAlign("CENTER", nil, "LEFT")
```

One value per column; `nil` keeps the default of that column.

**5. Progress bar**

```lua
tip:AddRow("Honor", "4500 / 9000"):SetBar(4500, 9000, "ffcc00")
```

A bar behind the text, filled to 4500 of 9000. The color is optional (default green).

**6. Several at once**

```lua
tip:AddRow("Total", "1268g"):SetColor("ffcc00"):SetBackground({ 1, 1, 1, 0.08 })
```

### 4.5 Look of a part

The same commands on `tip`, `header` and `footer` set the look of that part.

**1. Alignment of every row**

```lua
tip:SetAlign("LEFT", "CENTER", "RIGHT")
```

Also sets the column count (here 3), and is the default of the header and the footer too.

**2. Font from here on**

```lua
tip:SetFont(GameFontNormalSmall)
tip:AddRow("Small")
tip:AddRow("Small too")
tip:SetFont(nil)
tip:AddRow("Normal again")
```

Applies to the rows added **after** it. `nil` goes back to the part's own font.

**3. Text color from here on**

```lua
tip:SetColor("ffffff")
```

Works like `SetFont`: rows added after it.

**4. Background of the header or the footer**

```lua
header:SetBackground({ 1, 1, 1, 0.05 })
```

A strip behind that part.

**5. Border and background of the whole tooltip**

```lua
tip:SetBorder("ffcc00")
tip:SetBackground({ 0, 0, 0, 0.9 })
```

**6. Blizzard frame methods**

```lua
tip:SetScale(0.9)
tip:SetFrameStrata("FULLSCREEN")
```

The tooltip is a normal frame, so these work too.

### 4.6 Images

**1. File path**

```lua
tip:AddImage("Interface\\Icons\\INV_Misc_QuestionMark", 48, 48)
```

A row with one image, 48 x 48, centered.

**2. FileID, on the left**

```lua
tip:AddImage(134400, 32, 32, "LEFT")
```

**3. Atlas name, on the right**

```lua
tip:AddImage("common-icon-checkmark", 24, 24, "RIGHT")
```

**4. Icon inside the text**

```lua
tip:AddRow("|T134400:16|t Inline icon")
```

The usual WoW texture code; no image row needed.

### 4.7 Attach

**1. Open on mouseover**

```lua
PixieTooltip:Attach(myButton, Build)
```

The tooltip opens whenever the mouse enters `myButton`. No `OnEnter` code needed. Use it on your own frames.

**2. With the same parameters as Open**

```lua
PixieTooltip:Attach(myButton, Build, 2, true, { autoHide = 0.3 })
```

### 4.8 Several tooltips

**1. Open two at once**

```lua
PixieTooltip:Open(anchor, BuildMain)
PixieTooltip:Open(anchor, BuildDetails, 3, true, { key = "details" })
```

Different keys, so both stay open.

**2. Is it open?**

```lua
if PixieTooltip:IsOpen("details") then ... end
```

**3. Get the open tooltip**

```lua
local tip = PixieTooltip:Get("details")
```

`nil` when it is closed.

**4. Refresh or close one of them**

```lua
PixieTooltip:Refresh("details")
PixieTooltip:Close("details")
```

Without a key these work on the addon's main tooltip.

### 4.9 Panels

A tooltip with `autoHide = false` stays open, so it can be used as a small panel: rows to click, values to
change with the wheel, live data. Three settings make it behave like a window.

**1. Keep it open, in the middle of the screen**

```lua
PixieTooltip:Open(UIParent, BuildPanel, 2, false, {
    key      = "panel",
    autoHide = false,
    anchor   = { point = "CENTER" },
})
```

`UIParent` as the anchor and `point = "CENTER"`: the middle of the screen. `false` lets it open in combat too.

**2. Make it movable**

```lua
{ movable = true }
```

Drag it with the left mouse button wherever there is no clickable row. It stays at its new place while it is
open; `Refresh` does not move it.

**3. Add a close button**

```lua
{ closeButton = true }
```

The Blizzard close button (X) in the top right corner. The tooltip gets a little wider to make room for it.

**4. Close it with Esc**

```lua
{ escape = true }
```

Esc closes it, like Blizzard windows.

**5. Remember its place**

```lua
local savedPosition

local tip = PixieTooltip:Open(UIParent, BuildPanel, 2, false, {
    key = "panel", autoHide = false, anchor = { point = "CENTER" }, movable = true,
    onClose = function(tip) savedPosition = { tip:GetPoint(1) } end,
})
if tip and savedPosition then
    tip:ClearAllPoints()
    tip:SetPoint(unpack(savedPosition))
end
```

Pixie Tooltip saves nothing itself. `onClose` gets the tooltip, so the addon can keep its place (in
SavedVariables to keep it after a reload) and put it back after `Open`.

What a panel cannot have: text input fields and drop-down menus (use Blizzard controls), and protected actions
like using an item on click (the tooltip is not a secure frame).

### 4.10 Key bindings

A key can open a tooltip or a panel from anywhere, without a `Bindings.xml`.

**1. Bind a key**

```lua
PixieTooltip:Bind("F12", BuildPanel)
```

Pressing F12 opens the tooltip at the mouse cursor; pressing it again closes it.

**2. With the same parameters as Open**

```lua
PixieTooltip:Bind("CTRL-SHIFT-P", BuildPanel, 2, false, {
    key = "panel", autoHide = false, anchor = { point = "CENTER" }, movable = true, escape = true,
})
```

After the key come `build`, `columns`, `noCombat` and `options`, exactly as for `Open`. With an
`anchor.point` it opens relative to the screen (here in the middle), without one at the mouse cursor.

**3. Remove it**

```lua
PixieTooltip:Unbind("CTRL-SHIFT-P")
```

The key does its normal job again.

**4. Choose a free key**

Keys are written the Blizzard way: `"F12"`, `"CTRL-SHIFT-P"`, `"ALT-F"`, `"SHIFT-F11"`. While it is bound, the
key does only this, even when the game uses it for something else. Check Options -> Keybindings for a free
key, or let the player choose it in your addon's settings.

**5. Combat**

Key bindings cannot change in combat. A `Bind` or `Unbind` called in combat takes effect when combat ends.
Whether the tooltip opens in combat depends on `noCombat`, as for `Open`.

---

## 5. Level 3 - Expert

### 5.1 Masks

Every `Set...` and `On...` row command can take a **mask** after its value: one entry per column, saying which
columns it changes.

**1. No mask - the whole row**

```lua
row:SetBackground("333333")
```

**2. `true` - this column**

```lua
row:SetColor("ff4040", true)                      -- column 1
row:SetColor("ff4040", false, true)               -- column 2
```

`false` (or `nil`) skips a column.

**3. `CELL` - one area over several columns**

```lua
row:SetBackground("333333", false, true, CELL)    -- columns 2-3 as one area
```

`true` starts the area, `CELL` extends it to the next column.

**4. Two separate areas**

```lua
row:SetBackground("333333", false, true, true)    -- column 2 and column 3, apart
```

**5. `ROW` - to the end of the row**

```lua
row:SetBar(85, 100, "00ff00", false, true, ROW)   -- one bar from column 2 to the last
```

For backgrounds, bars and highlights an area is one piece: one bar across columns 2-3, not two bars.
Areas reach half the column gap into their neighbors, so they look continuous.
For colors, fonts and wrapping only the columns count.

### 5.2 Per-cell mouse handlers

**1. A click on one cell**

```lua
tip:AddRow("Sound", "Master")
    :OnClick(function(tip) ToggleMaster(); tip:Refresh() end, false, true)
```

Only column 2 reacts and lights up.

**2. Different clicks in one row**

```lua
tip:AddRow("Sound", "Master", "Music", "Effects")
    :OnClick(function(tip) ToggleMaster(); tip:Refresh() end, false, true)
    :OnClick(function(tip) ToggleMusic(); tip:Refresh() end, false, false, true)
    :OnClick(function(tip) ToggleEffects(); tip:Refresh() end, false, false, false, true)
```

Each cell has its own handler.

**3. The same for the mouse wheel**

```lua
row:OnWheel(function(tip, delta) ChangeVolume(delta); tip:Refresh() end, false, true)
```

### 5.3 More row commands

**1. Highlight without a click**

```lua
row:SetHighlight("40ffffff")
row:SetHighlight("40ffffff", false, true, CELL)   -- only columns 2-3
```

Lights up under the mouse even when the row has no `OnClick`.

**2. Wrapping**

```lua
tip:AddRow("Note", { longText, ROW, "LEFT" }):SetWrap(250, false, true)
```

The text from column 2 on wraps at 250 pixels; the row grows taller.

**3. Vertical alignment**

```lua
row:SetValign("TOP")                       -- every column
row:SetValign("TOP", "MIDDLE", "BOTTOM")   -- one per column
```

Matters only when a row is taller than one line (wrapped text, a bigger font).

**4. Wrapping and alignment together**

```lua
tip:AddRow("Note", { longText, ROW, "LEFT" })
    :SetWrap(250, false, true)
    :SetValign("TOP")
```

"Note" stays at the top of the taller row.

**5. Hint with a function**

```lua
row:OnHover(function(gameTooltip, row)
    gameTooltip:SetItemByID(6948)
    gameTooltip:AddLine("Click to use", 0, 1, 0)
end)
```

Fill the hint with any GameTooltip method.

### 5.4 Fonts

Wherever a font is accepted (`SetFont`, `SetDefaults`) it can be given in four forms.

**1. A font object**

```lua
row:SetFont(GameFontNormalSmall)
```

**2. The name of a font object**

```lua
row:SetFont("GameFontNormalSmall")
```

**3. Short table: file, size, flags**

```lua
row:SetFont({ "Fonts\\FRIZQT__.TTF", 14, "OUTLINE" })
```

**4. Full table**

```lua
row:SetFont({ size = 11, flags = "OUTLINE", color = "ffcc00" })
```

Every field is optional. A field you leave out comes from `base`, and `base` defaults to the part's own font.
So `{ size = 11 }` is the usual font, only smaller.

| Field | Meaning | Example |
|---|---|---|
| `base` | font object to start from | `GameFontNormal` |
| `file` | font file | `"Fonts\\FRIZQT__.TTF"` |
| `size` | height in pixels | `14` |
| `flags` | `""`, `"OUTLINE"`, `"THICKOUTLINE"`, `"MONOCHROME"`, combined with `,` | `"OUTLINE"` |
| `color` | text color | `"ffcc00"` |
| `shadow` | `{ color, x, y }`; `false`: no shadow | `{ color = "000000", x = 1, y = -1 }` |
| `spacing` | extra space between wrapped lines | `2` |

The font's `color` is the weakest: a part's `color` and `row:SetColor` override it.

### 5.5 All defaults

Every `SetDefaults` key, with its built-in value and a comment, is in 6.6.

---

## 6. Reference

### 6.1 Module: `PixieTooltip`

| Command | Meaning |
|---|---|
| `Open(anchor, build, columns, noCombat, options)` | Opens the tooltip, or rebuilds it when it is already open with the same key. Returns it, or `nil` when combat blocked it. |
| `Close(key)` | Closes it. |
| `Refresh(key)` | Runs the build function again; nothing when it is closed. |
| `IsOpen(key)` | `true` when it is open. |
| `Get(key)` | The open tooltip, or `nil`. |
| `Attach(frame, build, columns, noCombat, options)` | Opens the tooltip whenever the mouse enters the frame. |
| `SetDefaults(options)` | Options for every tooltip of the addon. `nil` clears them. |
| `Bind(key, build, columns, noCombat, options)` | The key (e.g. `"F12"`) opens the tooltip, and closes it when pressed again. |
| `Unbind(key)` | Removes the key binding. |
| `CELL`, `ROW` | The markers. |

`key` defaults to the addon name everywhere.

`columns` can be:

1. `nil` - automatic: as many as the widest row; first column LEFT, the rest RIGHT.
2. a number (`4`) - that many columns; empty ones are kept.
3. a list (`{ "LEFT", "CENTER", "RIGHT" }`) - its length is the column count, its values the alignment.

When a row has more values than `columns`, the column count grows; nothing is cut off.

### 6.2 Build function

```lua
function Build(tip, header)            -- default
function Build(tip, header, footer)    -- footer.enabled = true
```

`tip.header` and `tip.footer` reach the same parts from anywhere, e.g. a click handler.
`tip.footer` is `nil` when the footer is off.

### 6.3 Content: `tip`, `header`, `footer`

| Command | Meaning |
|---|---|
| `AddRow(a, b, c, ...)` | New row; each argument fills the next column. A table is a merged cell: `{ text, CELL..., ROW, align }`. Returns the row. |
| `AddSeparator(color, size)` | A line of `size` pixels (default 1). `AddSeparator(nil, 6)`: an empty gap. `AddSeparator()`: the `separator` default. |
| `AddImage(texture, width, height, align)` | A row with one image: file path, fileID or atlas name. Size and alignment default to the `image` default (32, `"CENTER"`). |

### 6.4 Look of a part: `tip`, `header`, `footer`

| Command | Applies to | Meaning |
|---|---|---|
| `SetAlign(a, b, ...)` | the whole part | alignment per column; on `tip` also the column count and the default of header and footer |
| `SetValign(...)` | the whole part | one value, or one per column |
| `SetWrap(width, mask...)` | the whole part | wraps the masked columns |
| `SetFont(font, mask...)` | rows added after it | `nil`: back to the part's own font |
| `SetColor(color, mask...)` | rows added after it | `nil`: back to the font's color |
| `SetHighlight(fill, mask...)` | rows added after it | highlight of the clickable rows |
| `SetBackground(fill)` | the part | `header` / `footer`: that strip. `tip`: the whole tooltip. |
| `tip:SetBorder(color)` | the tooltip | border color |
| `tip:Refresh()`, `tip:Close()` | the tooltip | rebuild, close |

### 6.5 Row (returned by `Add...`; every command returns the row)

| Command | Meaning |
|---|---|
| `:SetColor(color, mask...)` | text color |
| `:SetFont(font, mask...)` | font |
| `:SetBackground(fill, mask...)` | background |
| `:SetHighlight(fill, mask...)` | shown under the mouse |
| `:SetBar(value, max, fill, mask...)` | progress bar behind the text; one bar per area |
| `:SetWrap(width, mask...)` | wrapping |
| `:SetAlign(...)` | alignment per column (`nil` keeps the default) |
| `:SetValign(...)` | one value for the row, or one per column |
| `:OnClick(func, mask...)` | `func(tip, button, row)` |
| `:OnWheel(func, mask...)` | `func(tip, delta, row)`, delta 1 / -1 |
| `:OnHover(hint)` | plain text, a link (`"item:6948"` or a full link) or `func(GameTooltip, row)` |

### 6.6 SetDefaults: every key

Every key is optional. `Open`'s 5th parameter takes the same keys for one tooltip.
`key`, `refresh` and `onClose` are accepted only by `Open`.

```lua
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
        point  = nil,          -- "TOP", "BOTTOM", "LEFT", "RIGHT", "TOPLEFT", ..., "CENTER"; nil: towards the screen middle
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
    --   font        font (any of the four forms in 5.4)
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

    ---- Panel (see 4.9) --------------------------------------------------------

    movable     = false,       -- true: drag it with the left mouse button
    closeButton = false,       -- true: Blizzard close button (X) in the top right corner
    escape      = false,       -- true: Esc closes it, like Blizzard windows
})
```

In the build function the middle part is `tip`; in `SetDefaults` it is `body`, because there `tip` would mean
the whole tooltip.

### 6.7 Value formats

**1. Colors**

```lua
"ffcc00"                       -- rrggbb
"80ffcc00"                     -- aarrggbb: alpha first
"#ffcc00"
{ 1, 0.8, 0 }                  -- r, g, b (0-1)
{ 1, 0.8, 0, 0.5 }             -- with alpha
{ r = 1, g = 0.8, b = 0 }
NORMAL_FONT_COLOR              -- any ColorMixin, e.g. RAID_CLASS_COLORS.MAGE
```

**2. Fills (`SetBackground`, `SetHighlight`, `SetBar`, `background`)**

A color, or an image: file path (`"Interface\\TargetingFrame\\UI-StatusBar"`), fileID (`134400`) or atlas
name (`"common-icon-checkmark"`).

**3. Alignment**

`"LEFT"`, `"CENTER"`, `"RIGHT"`. Vertical: `"TOP"`, `"MIDDLE"`, `"BOTTOM"`.

**4. Text**

Strings and numbers. `|cff...|r` colors and `|T...|t` / `|A...|a` icons work as usual.

---

## 7. Coming from LibQTip

| LibQTip | Pixie Tooltip |
|---|---|
| `LibStub("LibQTip-1.0")`, Libs folder, TOC lines | Remove them; add `PixieTooltipMixin.lua` to the TOC. |
| `Acquire(key, 3, "LEFT", "RIGHT", "RIGHT")` + `SmartAnchorTo` + `SetAutoHideDelay` + `Show` | `Open(anchor, Build, 3)` or `Open(anchor, Build, { "LEFT", "RIGHT", "RIGHT" })` |
| `Release(tip)`, `IsAcquired(key)` | `Close()`, `IsOpen()` (it also closes by itself) |
| `SetAutoHideDelay(delay, frame, releaseHandler)` | `{ autoHide = delay, onClose = releaseHandler }` |
| `AddHeader(...)` | `header:AddRow(...)` |
| `AddLine(a, b, c)` | `tip:AddRow(a, b, c)` |
| `AddLine("")` + `SetCell(line, 1, text, "CENTER", 3)` | `tip:AddRow({ text, ROW, "CENTER" })` |
| `SetCell(line, col, text, justify, colSpan)` | a table cell in `AddRow`: `{ text, CELL, justify }` |
| `AddSeparator(h, r, g, b, a)` | `tip:AddSeparator({ r, g, b, a }, h)`; spacer: `tip:AddSeparator(nil, h)` |
| `SetLineColor` / `SetCellColor` / `SetColumnColor` | `row:SetBackground(color, mask...)` |
| `SetLineTextColor` / `SetCellTextColor` / `SetColumnTextColor` | `row:SetColor(color, mask...)` (per row; in the loop for a column) |
| `SetFont` / `SetHeaderFont` | `tip:SetFont`, `header:SetFont`, `row:SetFont` |
| `SetLineScript(line, "OnMouseUp", func, arg)` / `SetCellScript` | `row:OnClick(func, mask...)` (a closure instead of `arg`) |
| `OnEnter` script with `GameTooltip:SetHyperlink(link)` | `row:OnHover(link)` |
| `Clear` and rebuild, or editing cell font strings | `tip:Refresh()` |
| `UpdateScrolling(maxHeight)`, `SetScrollStep` | automatic; `maxHeight`, `wheelStep` |
| `SetFrameStrata(...)` | `tip:SetFrameStrata(...)` or `strata` |

---

## 8. Behavior notes

**1. Rows are reused**

A row returned by `AddRow` is valid until the next `Refresh` or `Close`. Keep your data, not the rows.

**2. Mouse input**

Only rows with `OnClick`, `OnWheel`, `OnHover` or `SetHighlight` take the mouse; the rest let it through.

**3. Refresh under a still mouse**

The highlight and the hint of the row under the cursor stay visible.

**4. Auto-hide waits for the mouse**

The countdown starts only after the mouse has been over the tooltip or its anchor. A tooltip opened from a
slash command or at the cursor waits until the mouse visits it.

**5. Combat**

By default tooltips do not open in combat. The tooltip is not a secure frame: never call protected actions
from its handlers.

**6. Errors**

An error in the build function is reported by the normal Lua error handler. The tooltip still shows what was
added before the error.

**7. No OnUpdate**

Auto-hide and `refresh` use timers that run only while the tooltip is open.

**8. Light on memory**

Rows, cells, settings and layout tables are reused on every `Refresh`, and a cell whose text and font did not
change is not measured again. A live tooltip that refreshes every second therefore makes very little garbage
for the Lua garbage collector.

**9. Secret values (Retail 12.0)**

A secret value from a combat API can be shown in a cell as it is. It is never compared or calculated with;
a `SetBar` with a secret value is skipped instead of raising an error.

**10. No globals**

Everything lives in the addon's private table. Three exceptions, all with a global name starting with the
addon name: fonts made from a font table (`CreateFont` requires a name), a tooltip with `escape = true`
while it is open (Blizzard's Esc list, `UISpecialFrames`, holds names), and one hidden button per `Bind` key
(`SetOverrideBindingClick` clicks a button by its name).
