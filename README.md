# Pixie Tooltip

Rich multi-column tooltips for WoW addons from one build function: merged cells, fixed header and footer,
progress bars, images and hover hints. Rows react to clicks and the mouse wheel, long lists scroll, and Refresh
redraws it live. One mixin-based Lua file on Blizzard functions only: no libraries, no globals. Retail and
Classic.

The full guide, in three levels (Simple, Advanced, Expert) with every command and setting:
**[DOCUMENTATION.md](DOCUMENTATION.md)**

## Quick start

**1. Add the file to the TOC, before the files that use it**

```
PixieTooltipMixin.lua
Core.lua
```

**2. Get it in your file**

```lua
local addonName, private = ...
local PixieTooltip = private.PixieTooltip
local CELL, ROW = PixieTooltip.CELL, PixieTooltip.ROW
```

**3. Write a build function**

```lua
local function Build(tip, header)
    header:AddRow("Characters", nil, nil, date("%H:%M"))
    header:AddSeparator("ffcc00", 1)
    tip:AddRow("Name", "Level", "Gold", "Week")
    tip:AddRow("Pixie", 80, "1234g", "+56g")
    tip:AddRow({ "Total", CELL }, "1234g", "+56g")
end
```

**4. Open it - three simple ways**

```lua
PixieTooltip:Open(anchor, Build)            -- automatic columns, not in combat
PixieTooltip:Open(anchor, Build, 4)         -- 4 columns
PixieTooltip:Open(anchor, Build, 4, false)  -- 4 columns, also in combat
```

**5. Redraw it when the data changes**

```lua
PixieTooltip:Refresh()
```

## Files

| File | What it is |
|---|---|
| `PixieTooltipMixin.lua` | The module. Copy it into the addon. |
| `DOCUMENTATION.md` | The full guide. |
| `Pixie Tooltip\` | Test addon: `Example.lua` has 24 copyable examples in the three levels, and a `SetDefaults` call listing every setting with its built-in value. In game: Esc → Options → AddOns → Pixie Tooltip (or type `/ptt`), and hover a line. `/ptt <number>` opens an example at the cursor. |

## Tested in game

Tested in game on Retail (Midnight), Mists of Pandaria Classic, Burning Crusade Classic Anniversary and Classic Era: every point below works. WoW: Forever (16001) is not tested yet; check it the same way (`/ptt` in the test addon):

1. `/ptt` opens the Pixie Tooltip page in the AddOns options; it lists all 24 examples under Simple, Advanced
   and Expert, and hovering a line opens its example at a fixed spot on the right of the page.
2. Examples 1-2: automatic columns; with `4`, the row without a weekly value stays aligned.
3. Example 3: merged cells (`CELL`, `ROW`, alignment in the table).
4. Example 4: 1 px lines are sharp at different UI scales; `nil` gives a gap.
5. Examples 5-7: click highlight and toggles, mouse wheel, hints with a short link, a full link and text.
6. Example 8: the footer appears only with `footer = { enabled = true }`, small and grey.
7. Example 9: row colors, fonts, backgrounds, alignment, bar; `tip:SetFont` and `tip:SetFont(nil)`.
8. Example 10: bag bars and colors, gold, live update when looting, footer click opens the bags.
9. Example 11: file path, fileID, atlas (the atlas may not exist on Classic), the image default.
10. Examples 12-15: refresh clock, pinned tooltip, own key with border/background/strata (opens in combat),
    and the next tooltip has the native look again; Attach on line 15 of the list.
11. Example 16: header and footer stay while the body scrolls (wheel and dragging the scroll bar).
12. Example 17: `maxWidth` wraps the long text; `scale` 0.9.
13. Examples 18-19: mask areas, bars (default color, color, texture), cell colors, per-cell clicks,
    highlight without click, wrap with `TOP`, function hint.
14. Example 20: all font forms; no shadow and colored shadow; `SetColor` over the font color.
15. Example 21: tooltip below the button with a gap, hint on the left, larger padding and gaps.
16. Example 22: everything together while it refreshes every second.
17. In combat: only example 14 opens (`/ptt 14`).
18. Example 23: item icons and quality colors, item tooltip on hover, Shift+click links to chat, Ctrl+click tries on;
    "Loading..." turns into the item after the first load.
19. Example 24: the panel opens in the middle of the screen and stays; drag it, X and Esc close it; reopened, it
    comes back where it was; it stays open while other lines are hovered; `/ptt close` closes it.
20. F12 opens the Panel (example 24) from anywhere and closes it on the next press; the line at the top of the
    example page says so; in combat F12 still opens it (the panel allows combat).
