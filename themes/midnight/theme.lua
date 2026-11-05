-- Midnight for Retro-Go (Handheld)
--
-- Adapted from "Midnight", a Recalbox theme by Benoit Bounar (https://www.bounar.fr/Themes_es/Midnight/),
-- licensed CC BY-NC-SA 4.0. The images in this folder come from it. See README.md.
--
-- Every function here is optional: whatever isn't defined is drawn by Retro-Go's built-in code, and a
-- function can `return false` to fall back to it. Hooks and the `rg` API are documented in THEMING.md.

local W, H = rg.width, rg.height

-- Palette (from the original theme.xml) ------------------------------------------------------------

local C = {
  primary    = "#4040C4", -- selection bars, highlights
  primary_hi = "#6A6AE0", -- primary text on black (the darker primary is hard to read as text)
  secondary  = "#1D1D5B",
  dark       = "#2C2C3C", -- menu box
  side_top   = "#252530", -- side panel gradient
  side_bot   = "#0C0C0E",
  white      = "#FFFFFF",
  text       = "#CFCFCF",
  text_dim   = "#8A8A98",
  disabled   = "#5C5C6C",
  help       = "#777777",
  help_icon  = "#4E4E90",
  line       = "#3C3C4E",
  black      = "#000000",
}

-- Helpers -------------------------------------------------------------------------------------------

local function mix(c1, c2, t)
  local function channel(hex, i) return tonumber(hex:sub(i, i + 1), 16) end
  local function lerp(i) return math.floor(channel(c1, i) + (channel(c2, i) - channel(c1, i)) * t) end
  return rg.rgb(lerp(2), lerp(4), lerp(6))
end

-- Precomputed so redraws stay cheap on the device
local BANDS = 20
local side = {}
for i = 0, BANDS - 1 do side[i] = mix(C.side_top, C.side_bot, i / (BANDS - 1)) end

local function side_panel(x, w)
  local band_h = math.ceil(H / BANDS)
  for i = 0, BANDS - 1 do rg.rect(x, i * band_h, w, band_h, side[i]) end
end

local function upper(s) return (s or ""):upper() end

-- Logo images (logos/<tab>_<size>.png): s = small and dim, m = selected in the side list,
-- l = big on top of the screen, list = above the game list. Returns the drawn width, or nil if missing.
local function logo(name, size, x, y, center_w, center_h)
  local file = "logos/" .. name .. "_" .. size .. ".png"
  local w, h = rg.image_size(file)
  if not w then return nil end
  if center_w then x = x + math.floor((center_w - w) / 2) end
  if center_h then y = y + math.floor((center_h - h) / 2) end
  rg.image(file, x, y)
  return w
end

-- Small up/down arrows icon, 7px wide
local function updown_icon(x, y)
  for i = 0, 3 do
    rg.rect(x + 3 - i, y + i, i * 2 + 1, 1, C.help_icon)      -- up arrow
    rg.rect(x + 3 - i, y + 11 - i, i * 2 + 1, 1, C.help_icon) -- down arrow
  end
end

-- Help bar: { {"icon", "label"}, ... } drawn left to right from x. Icons are text in the icon color,
-- or "updown" for arrows.
local function help_bar(x, y, items)
  for _, item in ipairs(items) do
    local icon, label = item[1], item[2]
    if icon == "updown" then
      updown_icon(x, y + 1)
      x = x + 7 + 4
    else
      rg.text(x, y, icon, { color = C.help_icon })
      x = x + rg.measure(icon) + 3
    end
    rg.text(x, y, label, { color = C.help })
    x = x + rg.measure(label) + 12
  end
end

-- Launcher: list of systems (carousel) --------------------------------------------------------------

local SIDE_W = 120

local function draw_systems(tab)
  -- The backgrounds are black on the left and the artwork fades into it, so everything left of it is black
  rg.rect(0, 0, W, H, C.black)
  if tab.background then
    rg.image(tab.background, 0, 0)
  end
  rg.rect(0, 0, SIDE_W, H, C.black)

  -- Systems list on the left, the current one bigger and white in the middle
  local tabs, current = tab.visible_tabs, tab.visible_index
  if not tabs or #tabs == 0 then
    tabs, current = { { name = tab.name, desc = tab.desc } }, 1 -- Older Retro-Go without visible_tabs
  end
  local n = #tabs
  local center = math.floor(H * 0.49)
  local before, after = 3, 3
  if n < 7 then before, after = math.floor((n - 1) / 2), n - 1 - math.floor((n - 1) / 2) end
  for k = -before, after do
    local t = tabs[((current - 1 + k) % n) + 1]
    if t then
      local selected = k == 0
      local slot_h = selected and 44 or 34
      local cy = center + k * 38 + (k > 0 and 6 or (k < 0 and -6 or 0))
      local y = cy - math.floor(slot_h / 2)
      if not logo(t.name, selected and "m" or "s", 12, y, nil, slot_h) then
        rg.text(12, cy - 6, upper(t.desc or t.name), { width = SIDE_W - 18, color = selected and C.white or C.text_dim })
      end
    end
  end
  rg.rect(SIDE_W - 1, center - 22, 1, 44, C.white) -- marker next to the current system

  -- Big logo and info
  local x = math.floor(W * 0.30)
  if not logo(tab.name, "l", x, 18, nil, nil) then
    rg.text(x, 30, upper(tab.desc or tab.name), { big = true, color = C.white })
  end
  local info
  if tab.initialized then
    info = tab.list.count == 1 and "1 GAME AVAILABLE" or (tab.list.count .. " GAMES AVAILABLE")
  end
  rg.text(x, 80, upper(tab.desc), { color = C.text_dim })
  if info then rg.text(x, 94, info, { color = C.primary_hi }) end

  help_bar(SIDE_W + 12, H - 16, { {"updown", "CHOOSE"}, {"A", "OPEN"}, {"START+SEL", "MENU"} })
  rg.status_icons()
end

-- Scrolling of the selected game's name when it's too long to fit -----------------------------------
-- Waits, scrolls right to left until the end of the name is visible, waits, jumps back, and again.

local MARQUEE_WAIT = 1500   -- ms before scrolling starts
local MARQUEE_END = 1000    -- ms showing the end of the name before going back
local MARQUEE_SPEED = 30    -- pixels per second
local MARQUEE_FRAME = 40    -- ms between redraws while scrolling (25 per second)

local marquee = { key = nil, start = 0 }

-- How many pixels to shift the text left now. key identifies the selected entry (restarts on change).
local function marquee_offset(key, text, width)
  local overflow = rg.measure(text) - width
  if overflow <= 0 then return 0 end
  local now = rg.time_ms()
  if marquee.key ~= key then
    marquee.key, marquee.start = key, now
  end
  local scroll_ms = math.floor(overflow * 1000 / MARQUEE_SPEED)
  local t = (now - marquee.start) % (MARQUEE_WAIT + scroll_ms + MARQUEE_END)
  local offset, next_ms
  if t < MARQUEE_WAIT then
    offset, next_ms = 0, MARQUEE_WAIT - t
  elseif t < MARQUEE_WAIT + scroll_ms then
    offset, next_ms = math.floor((t - MARQUEE_WAIT) * MARQUEE_SPEED / 1000), MARQUEE_FRAME
  else
    offset, next_ms = overflow, MARQUEE_WAIT + scroll_ms + MARQUEE_END - t
  end
  if rg.redraw_in then rg.redraw_in(math.max(next_ms, 10)) end -- Launcher only
  return offset
end

-- Launcher: list of games ---------------------------------------------------------------------------

local PANEL_X = math.floor(W * 0.59)
local PANEL_W = W - PANEL_X

local function list_window(list, lines)
  local first
  if list.scroll_mode == "paging" then
    first = math.floor((list.cursor - 1) / lines) * lines + 1
  else
    first = list.cursor - math.floor(lines / 2)
    first = math.max(1, math.min(first, list.count - lines + 1))
  end
  return math.max(1, first)
end

local function draw_games(tab)
  rg.rect(0, 0, PANEL_X, H, C.black)
  side_panel(PANEL_X, PANEL_W)

  -- System logo above the list
  if not logo(tab.name, "list", PANEL_X, 6, PANEL_W, 34) then
    rg.text(PANEL_X, 16, upper(tab.desc or tab.name), { width = PANEL_W, align = "center", color = C.white })
  end

  -- Game list
  local list = tab.list
  local top, bottom = 44, H - 4
  if list.count == 0 then
    rg.text(PANEL_X, top + 30, "NO GAMES", { width = PANEL_W, align = "center", color = C.white })
    rg.text(PANEL_X + 8, top + 50, "Copy ROMs to /roms/" .. tab.name .. "/",
            { width = PANEL_W - 16, align = "center", multiline = true, color = C.text_dim })
  else
    local row_h = rg.line_height() + 4
    local lines = math.floor((bottom - top) / row_h)
    local first = list_window(list, lines)
    local y = top
    for i = first, math.min(first + lines - 1, list.count) do
      local selected = i == list.cursor
      if selected then rg.rect(PANEL_X + 4, y, PANEL_W - 8, row_h, C.primary) end
      local name = upper(tab.item(i))
      local scroll = selected and marquee_offset(tab.name .. ":" .. i, name, PANEL_W - 18) or 0
      rg.text(PANEL_X + 10, y + 2, name, { width = PANEL_W - 18, color = selected and C.white or C.text, scroll = scroll })
      y = y + row_h
    end
    -- Thin scroll indicator on the panel's edge
    if list.count > lines then
      local track_h = bottom - top
      local thumb_h = math.max(8, math.floor(track_h * lines / list.count))
      local thumb_y = top + math.floor((track_h - thumb_h) * (first - 1) / (list.count - lines))
      rg.rect(W - 2, thumb_y, 2, thumb_h, C.help_icon)
    end
  end

  -- Game picture (cover or screenshot, when Retro-Go has one) on the left
  local box_x, box_y, box_w, box_h = 10, 10, PANEL_X - 20, 176
  if tab.preview then
    local pw, ph = rg.image_size(tab.preview)
    local scale = math.min(box_w / pw, box_h / ph)
    local dw, dh = math.floor(pw * scale), math.floor(ph * scale)
    rg.image(tab.preview, box_x + math.floor((box_w - dw) / 2), box_y + math.floor((box_h - dh) / 2), dw, dh)
  elseif list.count > 0 then
    rg.rect(box_x, box_y, box_w, box_h, C.black, 1, C.line)
    if not logo(tab.name, "l", box_x, box_y, box_w, box_h - 20) then
      rg.text(box_x, box_y + 70, upper(tab.desc), { width = box_w, align = "center", color = C.text_dim })
    end
    rg.text(box_x, box_y + box_h - 22, "NO PICTURE", { width = box_w, align = "center", color = C.disabled })
  end

  -- Selected game info
  if list.count > 0 then
    local y = box_y + box_h + 12
    rg.text(box_x, y, upper(tab.desc), { width = box_w, color = C.primary_hi })
    local _, name_h = rg.measure(upper(tab.item(list.cursor)), { width = box_w, multiline = true })
    rg.text(box_x, y + 16, upper(tab.item(list.cursor)), { width = box_w, multiline = true, color = C.white })
    rg.text(box_x, y + 20 + name_h, "GAME " .. list.cursor .. " / " .. list.count, { color = C.text_dim })
  end
  if tab.navpath then
    rg.text(box_x, H - 32, "/" .. tab.navpath, { width = box_w, color = C.text_dim })
  end

  help_bar(box_x, H - 16, { {"A", "PLAY"}, {"B", "BACK"}, {"START+SEL", "MENU"} })
end

-- Launcher: 320x240 layout ("compact") -------------------------------------------------------------
-- Used on 4:3 and smaller screens. Its images and fonts are in the 320x240 folder, which Retro-Go uses
-- instead of the ones in the theme folder on a 320x240 screen.

-- Splits text into lines that fit width, at spaces (Retro-Go's multiline text breaks inside words)
local function wrap_words(text, width, max_lines)
  local lines, line = {}, ""
  for word in (text or ""):gmatch("%S+") do
    local candidate = line == "" and word or (line .. " " .. word)
    if line ~= "" and rg.measure(candidate) > width then
      lines[#lines + 1] = line
      line = word
    else
      line = candidate
    end
  end
  if line ~= "" then lines[#lines + 1] = line end
  while #lines > max_lines do table.remove(lines) end
  return lines
end

-- Small left/right arrows icon, 11px wide
local function leftright_icon(x, y)
  for i = 0, 3 do
    rg.rect(x + i, y + 3 - i, 1, i * 2 + 1, C.help_icon)      -- left arrow
    rg.rect(x + 10 - i, y + 3 - i, 1, i * 2 + 1, C.help_icon) -- right arrow
  end
end

local function draw_systems_compact(tab)
  rg.rect(0, 0, W, H, C.black)
  if tab.background then
    rg.image(tab.background, 0, 0)
  end

  -- Big logo and info at the top left
  local x = 12
  if not logo(tab.name, "l", x, 12, nil, nil) then
    rg.text(x, 18, upper(tab.desc or tab.name), { big = true, color = C.white })
  end
  local y = 60
  for _, line in ipairs(wrap_words(upper(tab.desc), math.floor(W * 0.45), 3)) do
    rg.text(x, y, line, { color = C.text_dim })
    y = y + rg.line_height()
  end
  if tab.initialized then
    local info = tab.list.count == 1 and "1 GAME AVAILABLE" or (tab.list.count .. " GAMES AVAILABLE")
    rg.text(x, y + 2, info, { color = C.primary_hi })
  end

  -- Row of systems at the bottom: the current one in the middle, bigger, with a marker under it
  local strip_y, strip_h = H - 54, 36
  rg.rect(0, strip_y - 1, W, H - strip_y + 1, C.black)
  rg.rect(0, strip_y - 2, W, 1, C.line)
  local tabs, current = tab.visible_tabs, tab.visible_index
  if not tabs or #tabs == 0 then
    tabs, current = { { name = tab.name, desc = tab.desc } }, 1
  end
  local n, slot_w = #tabs, 62
  local side = math.min(2, math.floor((n - 1) / 2))
  for k = -side, side do
    local t = tabs[((current - 1 + k) % n) + 1]
    local selected = k == 0
    local cx = math.floor(W / 2) + k * slot_w + (k > 0 and 12 or (k < 0 and -12 or 0))
    local x0 = cx - math.floor(slot_w / 2)
    if not logo(t.name, selected and "m" or "s", x0, strip_y, slot_w, strip_h) then
      rg.text(x0, strip_y + 12, upper(t.desc or t.name), { width = slot_w, align = "center",
              color = selected and C.white or C.text_dim })
    end
  end
  rg.rect(math.floor(W / 2) - 20, strip_y + strip_h, 40, 1, C.white) -- marker under the current system

  -- Help line
  local hx = 12
  leftright_icon(hx, H - 13)
  hx = hx + 15
  hx = hx + rg.text(hx, H - 15, "CHOOSE", { color = C.help }) + 10
  hx = hx + rg.text(hx, H - 15, "A", { color = C.help_icon }) + 3
  hx = hx + rg.text(hx, H - 15, "OPEN", { color = C.help }) + 10
  hx = hx + rg.text(hx, H - 15, "START+SEL", { color = C.help_icon }) + 3
  rg.text(hx, H - 15, "MENU", { color = C.help })
  rg.status_icons()
end

local function draw_games_compact(tab)
  local panel_x = math.floor(W * 0.42) -- The list gets most of the width so game names fit
  local panel_w = W - panel_x
  rg.rect(0, 0, panel_x, H, C.black)
  side_panel(panel_x, panel_w)

  -- System logo above the list
  if not logo(tab.name, "list", panel_x, 4, panel_w, 26) then
    rg.text(panel_x, 10, upper(tab.desc or tab.name), { width = panel_w, align = "center", color = C.white })
  end

  -- Game list
  local list = tab.list
  local top, bottom = 34, H - 3
  if list.count == 0 then
    rg.text(panel_x, top + 24, "NO GAMES", { width = panel_w, align = "center", color = C.white })
    rg.text(panel_x + 4, top + 42, "Copy ROMs to /roms/" .. tab.name .. "/",
            { width = panel_w - 8, align = "center", multiline = true, color = C.text_dim })
  else
    local row_h = rg.line_height() + 3
    local lines = math.floor((bottom - top) / row_h)
    local first = list_window(list, lines)
    local y = top
    for i = first, math.min(first + lines - 1, list.count) do
      local selected = i == list.cursor
      if selected then rg.rect(panel_x + 3, y, panel_w - 6, row_h, C.primary) end
      local name = upper(tab.item(i))
      local scroll = selected and marquee_offset(tab.name .. ":" .. i, name, panel_w - 12) or 0
      rg.text(panel_x + 7, y + 2, name, { width = panel_w - 12, color = selected and C.white or C.text, scroll = scroll })
      y = y + row_h
    end
    if list.count > lines then
      local track_h = bottom - top
      local thumb_h = math.max(6, math.floor(track_h * lines / list.count))
      local thumb_y = top + math.floor((track_h - thumb_h) * (first - 1) / (list.count - lines))
      rg.rect(W - 2, thumb_y, 2, thumb_h, C.help_icon)
    end
  end

  -- Game picture on the left
  local box_x, box_y, box_w, box_h = 8, 8, panel_x - 16, 90
  if tab.preview then
    local pw, ph = rg.image_size(tab.preview)
    local scale = math.min(box_w / pw, box_h / ph)
    local dw, dh = math.floor(pw * scale), math.floor(ph * scale)
    rg.image(tab.preview, box_x + math.floor((box_w - dw) / 2), box_y + math.floor((box_h - dh) / 2), dw, dh)
  elseif list.count > 0 then
    rg.rect(box_x, box_y, box_w, box_h, C.black, 1, C.line)
    if not logo(tab.name, "list", box_x, box_y, box_w, box_h - 16) then
      rg.text(box_x, box_y + 30, upper(tab.desc), { width = box_w, align = "center", color = C.text_dim })
    end
    rg.text(box_x, box_y + box_h - 17, "NO PICTURE", { width = box_w, align = "center", color = C.disabled })
  end

  -- Selected game: name only (there isn't room for more)
  if list.count > 0 then
    local y = box_y + box_h + 8
    for _, line in ipairs(wrap_words(upper(tab.item(list.cursor)), box_w, 6)) do
      rg.text(box_x, y, line, { width = box_w, color = C.white })
      y = y + rg.line_height()
    end
    rg.text(box_x, H - 32, "GAME " .. list.cursor .. " / " .. list.count, { color = C.text_dim })
  end

  help_bar(box_x, H - 16, { {"A", "PLAY"}, {"B", "BACK"} }) -- No room for the menu hint next to the list
end

-- Which layout fits this screen: the 480x320 one needs a wide screen, everything else gets the compact one
local WIDE = W / H >= 1.4 and W >= 400

function draw_launcher(tab)
  if not WIDE then
    if tab.browsing then
      draw_games_compact(tab)
    else
      draw_systems_compact(tab)
    end
  elseif tab.browsing then
    draw_games(tab)
  else
    draw_systems(tab)
  end
end

-- Menus (launcher and in-game) ----------------------------------------------------------------------

local SKIPPED = { hidden = true }

-- Retro-Go's menus use a "----------" label for separators
local function is_separator(opt)
  return opt.kind == "separator" or (opt.kind == "skip" and opt.label:match("^%-+$") ~= nil)
end

-- Menus are drawn straight to the screen (no off-screen buffer), so text can't have a transparent
-- background there: always pass `bg`, or the text box shows up as a solid magenta rectangle.
function draw_dialog(dialog)
  local pad, gap = 10, 16
  local line_h = rg.line_height()
  local row_h = line_h + 6
  local max_w = math.floor(W * 0.92)
  local max_h = math.floor(H * 0.90)

  -- Measure: label column, value column (or the ">" arrow), and messages (which may wrap)
  local arrow_w = rg.measure(">")
  local label_w, value_w, msg_w = 0, 0, 0
  for _, opt in ipairs(dialog.options) do
    if not SKIPPED[opt.kind] then
      local lw = rg.measure(upper(opt.label))
      if opt.kind == "message" then
        msg_w = math.max(msg_w, lw)
      else
        label_w = math.max(label_w, lw)
        value_w = math.max(value_w, opt.value and (rg.measure(upper(opt.value))) or arrow_w)
      end
    end
  end
  local title = dialog.title and upper(dialog.title)
  local TITLE = { font = "title.rgf" } -- Bigger Josefin Sans for menu titles
  local title_w = title and rg.measure(title, TITLE) or 0
  local title_h = rg.line_height(TITLE)
  local inner_w = math.max(label_w + gap + value_w, msg_w, title_w, math.floor(W * 0.6))
  inner_w = math.min(inner_w, max_w - pad * 2)
  local box_w = inner_w + pad * 2

  -- Row heights (messages wrap to the box width)
  local heights, content_h = {}, 0
  for i, opt in ipairs(dialog.options) do
    local h = 0
    if opt.kind == "message" then
      local _, mh = rg.measure(opt.label, { width = inner_w, multiline = true })
      h = mh + 4
    elseif is_separator(opt) then
      h = 7
    elseif not SKIPPED[opt.kind] then
      h = row_h
    end
    heights[i] = h
    content_h = content_h + h
  end

  local header_h = title and (title_h + 16) or 4
  local box_h = math.min(header_h + content_h + pad, max_h)
  local box_x = math.floor((W - box_w) / 2)
  local box_y = math.floor((H - box_h) / 2)

  rg.rect(box_x, box_y, box_w, box_h, C.dark)
  if title then
    rg.text(box_x, box_y + 8, title, { width = box_w, align = "center", color = C.white, bg = C.dark, font = "title.rgf" })
  end
  local y = box_y + header_h

  -- Scroll so the selected row is visible
  local avail = box_y + box_h - pad - y
  local first, used = 1, 0
  for i = 1, dialog.selected do used = used + (heights[i] or 0) end
  while used > avail and first < dialog.selected do
    used = used - heights[first]
    first = first + 1
  end

  local last = first
  for i = first, #dialog.options do
    local opt, h = dialog.options[i], heights[i]
    if y + h > box_y + box_h - pad + 4 then break end
    last = i
    local x = box_x + pad
    if is_separator(opt) then
      rg.rect(x, y + 3, inner_w, 1, C.line)
    elseif opt.kind == "message" then
      rg.text(x, y + 2, opt.label, { width = inner_w, multiline = true, color = C.text, bg = C.dark })
    elseif h > 0 then
      local selected = i == dialog.selected and opt.kind == "normal"
      local fg = opt.kind == "normal" and C.white or C.disabled
      local bg = selected and C.primary or C.dark
      rg.rect(box_x, y, box_w, row_h, bg)
      local value = opt.value and upper(opt.value) or (opt.kind == "normal" and ">" or nil)
      local vw = value and math.min((rg.measure(value)), inner_w - gap) or 0
      if value and not WIDE then -- Small screens: cut a long value rather than its label
        vw = math.max(0, math.min(vw, inner_w - gap - (rg.measure(upper(opt.label)))))
      end
      rg.text(x, y + 3, upper(opt.label), { width = inner_w - (vw > 0 and vw + gap or 0), color = fg, bg = bg })
      if value then
        rg.text(x + inner_w - vw, y + 3, value, { width = vw, color = selected and C.white or C.text_dim, bg = bg })
      end
    end
    y = y + h
  end

  -- Scroll hints
  if first > 1 then rg.rect(box_x + box_w - 12, box_y + header_h - 4, 6, 2, C.primary_hi) end
  if last < #dialog.options then rg.rect(box_x + box_w - 12, box_y + box_h - 4, 6, 2, C.primary_hi) end

  return box_x, box_y, box_w, box_h
end
