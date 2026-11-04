-- Midnight theme for Retro-Go (Handheld)
--
-- This file replaces some of Retro-Go's drawing functions. Every function is optional: whatever isn't
-- defined here is drawn by the built-in code. A function can also `return false` to fall back to the
-- built-in drawing. The available hooks and the `rg` API are documented in THEMING.md.
--
-- Layout values are computed from rg.width / rg.height so the theme works at 480x320 and 320x240.

local W, H = rg.width, rg.height

-- Palette -------------------------------------------------------------------------------------------

local C = {
  sky_top    = "#070B1E",
  sky_bottom = "#1A1F4D",
  panel      = "#10163A",
  panel_edge = "#2B3373",
  row_sel    = "#2A2466",
  accent     = "#8B6CFF", -- violet
  accent2    = "#46C2FF", -- cyan
  text       = "#E6E8F5",
  text_dim   = "#8D93C0",
  text_faint = "#4A5185",
  star       = "#C9CEF5",
  star_dim   = "#5C6399",
}

-- Helpers -------------------------------------------------------------------------------------------

local function mix(c1, c2, t)
  local function channel(hex, i) return tonumber(hex:sub(i, i + 1), 16) end
  local r = channel(c1, 2) + (channel(c2, 2) - channel(c1, 2)) * t
  local g = channel(c1, 4) + (channel(c2, 4) - channel(c1, 4)) * t
  local b = channel(c1, 6) + (channel(c2, 6) - channel(c1, 6)) * t
  return rg.rgb(math.floor(r), math.floor(g), math.floor(b))
end

-- Precomputed so redraws stay cheap on the device
local BANDS = 32
local sky = {}
for i = 0, BANDS - 1 do sky[i] = mix(C.sky_top, C.sky_bottom, i / (BANDS - 1)) end

local stars = {}
do
  local seed = 1337
  local function rand(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end
  for i = 1, 70 do
    stars[i] = { x = rand(W), y = rand(H), big = rand(9) == 0, dim = rand(3) ~= 0 }
  end
end

local function draw_sky(star_level)
  local band_h = math.ceil(H / BANDS)
  for i = 0, BANDS - 1 do
    rg.rect(0, i * band_h, W, band_h, sky[i])
  end
  if star_level > 0 then
    for _, s in ipairs(stars) do
      if star_level > 1 or not s.dim then
        local size = s.big and 2 or 1
        rg.rect(s.x, s.y, size, size, s.dim and C.star_dim or C.star)
      end
    end
  end
end

local function draw_moon(cx, cy, r)
  -- Crescent, one pixel row at a time: the moon's disc minus a smaller disc shifted up and right
  local cut_r, cut_x, cut_y = r * 0.85, cx + r * 0.45, cy - r * 0.15
  for dy = -r, r do
    local y = cy + dy
    local half = math.floor(math.sqrt(r * r - dy * dy))
    local x1, x2 = cx - half, cx + half
    local ddy = y - cut_y
    if math.abs(ddy) <= cut_r then
      local cut_half = math.sqrt(cut_r * cut_r - ddy * ddy)
      local c1, c2 = math.floor(cut_x - cut_half), math.floor(cut_x + cut_half)
      if c1 > x1 then rg.rect(x1, y, math.min(c1, x2 + 1) - x1, 1, C.text) end
      if c2 < x2 then rg.rect(math.max(c2 + 1, x1), y, x2 - math.max(c2 + 1, x1) + 1, 1, C.text) end
    else
      rg.rect(x1, y, x2 - x1 + 1, 1, C.text)
    end
  end
end

-- One dot per tab, the current one highlighted. x is the first dot (not the center!) because negative
-- coordinates mean "from the right/bottom edge" in rg.* functions.
local function dots(x, y, count, current)
  local gap = 10
  for i = 1, count do
    if i == current then
      rg.rect(x - 3, y - 1, 7, 3, C.accent)
    else
      rg.rect(x - 1, y, 2, 2, C.text_faint)
    end
    x = x + gap
  end
end

-- Launcher ------------------------------------------------------------------------------------------

local function draw_carousel(tab)
  draw_sky(2)
  draw_moon(W - 70, 58, 22)

  local cy = math.floor(H / 2) - 10
  local logo_w, logo_h = 46 * 2, 50 * 2
  if tab.logo then
    rg.rect(math.floor((W - logo_w) / 2) - 3, cy - logo_h - 3, logo_w + 6, logo_h + 6, C.panel, 1, C.panel_edge)
    rg.image(tab.logo, math.floor((W - logo_w) / 2), cy - logo_h, logo_w, logo_h)
  end

  rg.text(0, cy + 14, tab.desc or tab.name, { width = W, align = "center", big = true, color = C.text })

  dots(math.floor(W / 2) - math.floor((tab.count - 1) * 10 / 2), H - 34, tab.count, tab.index)
  rg.text(0, H - 22, "<  >  switch      A  open      START+SELECT  menu",
          { width = W, align = "center", color = C.text_faint })
  rg.status_icons()
end

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

local function draw_browser(tab)
  draw_sky(1)

  -- Top bar
  local bar_h = 36
  rg.rect(0, 0, W, bar_h, C.panel)
  rg.rect(0, bar_h, W, 1, C.panel_edge)
  if tab.logo then rg.image(tab.logo, 8, 3, 28, 30) end
  rg.text(44, 4, tab.desc or tab.name, { color = C.text })
  local games = tab.list.count == 1 and "1 game" or (tab.list.count .. " games")
  rg.text(44, 19, tab.navpath and ("/" .. tab.navpath) or games, { color = C.text_dim })
  rg.status_icons()

  -- Panels: list on the left, optional preview on the right
  local top, bottom = bar_h + 8, H - 26
  local list_x, list_w = 10, W - 20
  if tab.preview then
    local pw, ph = rg.image_size(tab.preview)
    local max_w, max_h = math.floor(W * 0.42), bottom - top
    local scale = math.min(1, max_w / pw, max_h / ph)
    local dw, dh = math.floor(pw * scale), math.floor(ph * scale)
    local px = W - 10 - dw
    rg.rect(px - 3, top - 3, dw + 6, dh + 6, C.panel, 1, C.panel_edge)
    rg.image(tab.preview, px, top, dw, dh)
    list_w = px - 10 - list_x - 6
  end

  rg.rect(list_x, top, list_w, bottom - top, C.panel, 1, C.panel_edge)

  local list = tab.list
  if list.count == 0 then
    rg.text(list_x, top + 30, "No games here yet", { width = list_w, align = "center", color = C.text })
    rg.text(list_x, top + 50, "Copy ROMs to /roms/" .. tab.name .. "/", { width = list_w, align = "center", color = C.text_dim })
  else
    local row_h = rg.line_height() + 6
    local lines = math.floor((bottom - top - 8) / row_h)
    local first = list_window(list, lines)
    local y = top + 4
    for i = first, math.min(first + lines - 1, list.count) do
      local label = tab.item(i) or ""
      if i == list.cursor then
        rg.rect(list_x + 4, y, list_w - 14, row_h, C.row_sel)
        rg.rect(list_x + 4, y, 3, row_h, C.accent)
        rg.text(list_x + 14, y + 3, label, { width = list_w - 30, color = C.text })
      else
        rg.text(list_x + 14, y + 3, label, { width = list_w - 30, color = C.text_dim })
      end
      y = y + row_h
    end

    -- Scrollbar
    if list.count > lines then
      local track_x, track_y, track_h = list_x + list_w - 6, top + 4, bottom - top - 8
      local thumb_h = math.max(10, math.floor(track_h * lines / list.count))
      local thumb_y = track_y + math.floor((track_h - thumb_h) * (first - 1) / (list.count - lines))
      rg.rect(track_x, track_y, 2, track_h, C.panel_edge)
      rg.rect(track_x - 1, thumb_y, 4, thumb_h, C.accent2)
    end
  end

  -- Bottom bar
  rg.rect(0, H - 20, W, 20, C.panel)
  rg.rect(0, H - 21, W, 1, C.panel_edge)
  dots(12, H - 10, tab.count, tab.index)
  local position = list.count > 0 and (list.cursor .. " / " .. list.count) or ""
  rg.text(0, H - 18, position, { width = W - 8, align = "right", color = C.accent2 })
  rg.text(0, H - 18, tab.status_right or "", { width = W, align = "center", color = C.text_faint })
end

function draw_launcher(tab)
  if tab.browsing then
    draw_browser(tab)
  else
    draw_carousel(tab)
  end
end

-- Dialogs and menus (launcher and in-game) ---------------------------------------------------------

local SKIPPED = { hidden = true }

-- Retro-Go's menus use a "----------" label for separators
local function is_separator(opt)
  return opt.kind == "separator" or (opt.kind == "skip" and opt.label:match("^%-+$") ~= nil)
end

-- Dialogs are drawn straight to the screen (no off-screen buffer), so text can't have a transparent
-- background there: always pass `bg`, or the text box shows up as a solid magenta rectangle.
function draw_dialog(dialog)
  local pad, gap = 10, 16
  local line_h = rg.line_height()
  local row_h = line_h + 4
  local max_w = math.floor(W * 0.86)
  local max_h = math.floor(H * 0.86)

  -- Measure: label column, value column, and messages (which may wrap)
  local label_w, value_w, msg_w = 0, 0, 0
  for _, opt in ipairs(dialog.options) do
    if not SKIPPED[opt.kind] then
      local lw = rg.measure(opt.label)
      if opt.kind == "message" then
        msg_w = math.max(msg_w, lw)
      elseif opt.value then
        label_w = math.max(label_w, lw)
        value_w = math.max(value_w, (rg.measure(opt.value)))
      else
        label_w = math.max(label_w, lw)
      end
    end
  end
  local title_w = dialog.title and rg.measure(dialog.title) or 0
  local inner_w = math.max(label_w + (value_w > 0 and gap + value_w or 0), msg_w, title_w, 140)
  inner_w = math.min(inner_w, max_w - pad * 2)
  local box_w = inner_w + pad * 2

  -- Row heights (messages wrap to the box width)
  local heights, content_h = {}, 0
  for i, opt in ipairs(dialog.options) do
    local h = 0
    if opt.kind == "message" then
      local _, mh = rg.measure(opt.label, { width = inner_w, multiline = true })
      h = mh + 2
    elseif is_separator(opt) then
      h = 9
    elseif not SKIPPED[opt.kind] then
      h = row_h
    end
    heights[i] = h
    content_h = content_h + h
  end

  local header_h = dialog.title and (line_h + 12) or 0
  local box_h = math.min(header_h + content_h + pad * 2, max_h)
  local box_x = math.floor((W - box_w) / 2)
  local box_y = math.floor((H - box_h) / 2)

  -- Frame
  rg.rect(box_x, box_y, box_w, box_h, C.panel, 1, C.accent)
  local y = box_y + pad
  if dialog.title then
    rg.text(box_x + 1, y - 2, dialog.title, { width = box_w - 2, align = "center", color = C.text, bg = C.panel })
    rg.rect(box_x + pad, y + line_h + 3, box_w - pad * 2, 1, C.panel_edge)
    rg.rect(math.floor(box_x + box_w / 2) - 12, y + line_h + 2, 24, 3, C.accent)
    y = y + header_h
  end

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
    if y + h > box_y + box_h - pad then break end
    last = i
    local x = box_x + pad
    if is_separator(opt) then
      rg.rect(x, y + 4, inner_w, 1, C.panel_edge)
    elseif opt.kind == "message" then
      rg.text(x, y, opt.label, { width = inner_w, multiline = true, color = C.text_dim, bg = C.panel })
    elseif h > 0 then
      local selected = i == dialog.selected and opt.kind == "normal"
      local fg = (opt.kind == "normal") and (selected and "#FFFFFF" or C.text) or C.text_faint
      local bg = selected and C.row_sel or C.panel
      rg.rect(x - 4, y, inner_w + 8, row_h, bg)
      if selected then rg.rect(x - 4, y, 3, row_h, C.accent) end
      local vw = opt.value and math.min((rg.measure(opt.value)), inner_w - label_w - gap) or 0
      rg.text(x + 2, y + 2, opt.label, { width = inner_w - 2 - (vw > 0 and vw + gap or 0), color = fg, bg = bg })
      if opt.value then
        rg.text(x + inner_w - vw, y + 2, opt.value, { width = vw, color = selected and C.accent2 or C.text_dim, bg = bg })
      end
    end
    y = y + h
  end

  -- Scroll hints
  if first > 1 then rg.rect(box_x + box_w - 14, box_y + header_h + 4, 6, 2, C.accent2) end
  if last < #dialog.options then rg.rect(box_x + box_w - 14, box_y + box_h - 6, 6, 2, C.accent2) end

  return box_x, box_y, box_w, box_h
end
