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
      rg.text(PANEL_X + 10, y + 2, upper(tab.item(i)), { width = PANEL_W - 18, color = selected and C.white or C.text })
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

function draw_launcher(tab)
  if tab.browsing then
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
