-- simplelight for Retro-Go (Handheld)
--
-- Adapted from "simplelight", the Recalbox theme by the Recalbox community, based on "Simple" by
-- Nils Bonenberger (http://www.nilsbyte.de/), licensed CC BY-NC-SA. The images in this folder come
-- from it. See README.md.
--
-- Every function here is optional: whatever isn't defined is drawn by Retro-Go's built-in code, and a
-- function can `return false` to fall back to it. Hooks and the `rg` API are documented in THEMING.md.

local W, H = rg.width, rg.height

-- Which layout fits this screen: the 480x320 one needs a wide screen, everything else gets the compact one
local WIDE = W / H >= 1.4 and W >= 400

-- Palette (from the original simple.xml and its art folder) ----------------------------------------

local C = {
  text      = "#393A3B", -- game list, labels, selection bar
  selected  = "#97999B", -- selected game's text on the selection bar
  maker     = "#000000", -- first line of the system name in the header
  model     = "#7B7D7F", -- second line of the system name
  footer    = "#C5C6C8", -- footer bar (the original's footer.jpg, without its logos)
  info      = "#DDDEDF", -- bar under the logo on the systems screen
  help      = "#5F6062",
  menu      = "#F4F4F4", -- menu box
  line      = "#C5C6C8",
  disabled  = "#A0A2A4",
  white     = "#FFFFFF",
}

-- Layout. BAND_Y, BAND_H and HEADER_H must match the white areas drawn in the images
-- (background_*.png and games_*.png), which were made with these numbers.
local L = WIDE and {
  band_y = 98, band_h = 104, info_h = 22, footer_h = 22, header_h = 52, margin = 12,
  list_x = math.floor(W * 0.47), box_h = 150, row_pad = 5, name_lines = 3,
} or {
  band_y = 74, band_h = 76, info_h = 18, footer_h = 18, header_h = 38, margin = 6,
  list_x = math.floor(W * 0.40), box_h = 80, row_pad = 3, name_lines = 4,
}

-- The two lines of each system's name in the game list header (from the original theme's XML files)
local NAMES = {
  nes = { "Nintendo", "Entertainment System" },
  snes = { "Super Nintendo", "Entertainment System" },
  gb = { "Nintendo", "Game Boy" },
  gbc = { "Nintendo", "Game Boy Color" },
  gba = { "Nintendo", "Game Boy Advance" },
  gw = { "Nintendo", "Game and Watch" },
  sms = { "SEGA Master System", "Mark III" },
  gg = { "SEGA", "Game Gear" },
  md = { "SEGA Mega Drive", "SEGA Genesis" },
  pce = { "NEC", "PC Engine" },
  lnx = { "Atari", "Lynx" },
  doom = { "PrBoom", "Doom" },
  msx = { "MSX", "1|2|2+" },
  col = { "Coleco", "ColecoVision" },
  favorite = { "Favorites", "" },
  recent = { "Recently played", "" },
}

local LIGHT = { font = "light.rgf" } -- Open Sans Light, for the header and menu titles

-- Helpers -------------------------------------------------------------------------------------------

local function upper(s) return (s or ""):upper() end

-- Draws logos/<tab>_<kind>.png centered in a box, shrunk if it's bigger. Returns false if the file is missing.
local function logo(name, kind, x, y, box_w, box_h)
  local file = "logos/" .. name .. "_" .. kind .. ".png"
  local w, h = rg.image_size(file)
  if not w then return false end
  if w > box_w or h > box_h then
    local scale = math.min(box_w / w, box_h / h)
    w, h = math.floor(w * scale), math.floor(h * scale)
    rg.image(file, x + math.floor((box_w - w) / 2), y + math.floor((box_h - h) / 2), w, h)
  else
    rg.image(file, x + math.floor((box_w - w) / 2), y + math.floor((box_h - h) / 2))
  end
  return true
end

-- Small arrow icons for the help bar, in the help color
local function leftright_icon(x, y)
  for i = 0, 3 do
    rg.rect(x + i, y + 3 - i, 1, i * 2 + 1, C.text)      -- left arrow
    rg.rect(x + 10 - i, y + 3 - i, 1, i * 2 + 1, C.text) -- right arrow
  end
  return 11
end

-- Footer bar with button hints: { {"icon", "label"}, ... }. "leftright" is drawn as arrows.
local function footer(items)
  local top = H - L.footer_h
  rg.rect(0, top, W, L.footer_h, C.footer)
  local x = L.margin
  local y = top + math.floor((L.footer_h - rg.line_height()) / 2)
  for _, item in ipairs(items) do
    local icon, label = item[1], item[2]
    if icon == "leftright" then
      x = x + leftright_icon(x, y + math.floor(rg.line_height() / 2) - 3) + 4
    else
      x = x + rg.text(x, y, icon, { color = C.text }) + 3
    end
    x = x + rg.text(x, y, label, { color = C.help }) + (WIDE and 14 or 10)
  end
end

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

-- Launcher: systems screen --------------------------------------------------------------------------
-- The system's blurred artwork with a white band across the middle, its logo in the band, and the
-- number of games under it. Arrows show that there are more systems on both sides.

local function chevron(x, cy, size, dir) -- dir = -1 points left, 1 points right
  for i = 0, size - 1 do
    local len = (size - i) * 2 - 1
    local col = dir < 0 and x + size - 1 - i or x + i -- The tallest column is the arrow's back
    rg.rect(col, cy - (size - i) + 1, 1, len, C.text)
  end
end

local function draw_systems(tab)
  if tab.background then
    rg.image(tab.background, 0, 0)
  else
    rg.rect(0, 0, W, H, C.footer)
    rg.rect(0, L.band_y, W, L.band_h, C.white)
  end

  local n = tab.visible_tabs and #tab.visible_tabs or tab.count -- Older Retro-Go has no visible_tabs

  -- Logo in the band, with arrows on both sides when there are other systems to scroll to
  local logo_y, logo_h = L.band_y, L.band_h
  if not logo(tab.name, "sys", 0, logo_y, W, logo_h) then
    local text = upper(tab.desc or tab.name)
    rg.text(0, logo_y + math.floor((logo_h - rg.line_height(LIGHT)) / 2), text,
            { width = W, align = "center", color = C.text, font = "light.rgf" })
  end
  if n > 1 then
    local size = WIDE and 8 or 6
    local cy = logo_y + math.floor(logo_h / 2)
    chevron(L.margin + 4, cy, size, -1)
    chevron(W - L.margin - 4 - size, cy, size, 1)
  end

  -- Number of games (or the system's full name until its list has been loaded once)
  local info_y = L.band_y + L.band_h
  rg.rect(0, info_y, W, L.info_h, C.info)
  local info = upper(tab.desc)
  if tab.initialized then
    info = tab.list.count == 1 and "1 GAME AVAILABLE" or (tab.list.count .. " GAMES AVAILABLE")
  end
  rg.text(0, info_y + math.floor((L.info_h - rg.line_height()) / 2), info,
          { width = W, align = "center", color = C.help })

  footer({ { "leftright", "CHOOSE" }, { "A", "OPEN" }, { "START+SEL", "MENU" } })
  rg.status_icons()
end

-- Scrolling of the selected game's name when it's too long to fit -----------------------------------
-- Waits, scrolls right to left until the end of the name is visible, waits, jumps back, and again.

local MARQUEE_WAIT = 1500   -- ms before scrolling starts
local MARQUEE_END = 1000    -- ms showing the end of the name before going back
local MARQUEE_SPEED = 30    -- pixels per second
local MARQUEE_FRAME = 40    -- ms between redraws while scrolling (25 per second)

local marquee = { key = nil, start = 0 }

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

-- Launcher: game list ("detailed" view of the original) ---------------------------------------------
-- Washed-out artwork with a white header (logo on the left, system name on the right), the game's
-- picture on the left and the list on the right.

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

local function draw_header(tab)
  local m, hh = L.margin, L.header_h
  local logo_w = WIDE and 196 or 124
  if not logo(tab.name, "head", m, 0, logo_w, hh) then
    rg.text(m, math.floor((hh - rg.line_height()) / 2), upper(tab.desc or tab.name), { width = logo_w, color = C.text })
  end

  local names = NAMES[tab.name] or { tab.desc or tab.name, "" }
  local opts = WIDE and LIGHT or nil -- The light font is too big for the compact header
  local x = m + logo_w + 8
  local w = W - m - x
  local line_h = rg.line_height(opts)
  local lines = names[2] ~= "" and 2 or 1
  local y = math.floor((hh - line_h * lines) / 2) + (WIDE and 1 or 0)
  rg.text(x, y, upper(names[1]), { width = w, align = "right", color = C.maker, font = opts and opts.font })
  if lines == 2 then
    rg.text(x, y + line_h, upper(names[2]), { width = w, align = "right", color = C.model, font = opts and opts.font })
  end
end

local function draw_games(tab)
  local bg = "games_" .. tab.name .. ".png"
  if rg.image_size(bg) then
    rg.image(bg, 0, 0)
  else
    rg.rect(0, 0, W, H, C.menu)
    rg.rect(0, 0, W, L.header_h, C.white)
  end
  draw_header(tab)

  local m = L.margin
  local list = tab.list
  local list_x, list_w = L.list_x, W - L.list_x - m
  local top, bottom = L.header_h + (WIDE and 10 or 6), H - L.footer_h - (WIDE and 6 or 3)

  -- Game list
  if list.count == 0 then
    rg.text(list_x, top + 30, "NO GAMES", { width = list_w, align = "center", color = C.text })
    rg.text(list_x, top + 50, "Copy ROMs to /roms/" .. tab.name .. "/",
            { width = list_w, align = "center", multiline = true, color = C.model })
  else
    local row_h = rg.line_height() + L.row_pad
    local lines = math.floor((bottom - top) / row_h)
    local first = list_window(list, lines)
    local y = top
    local text_x, text_w = list_x + (WIDE and 6 or 4), list_w - (WIDE and 12 or 8)
    for i = first, math.min(first + lines - 1, list.count) do
      local selected = i == list.cursor
      if selected then rg.rect(list_x, y, list_w, row_h, C.text) end
      local name = upper(tab.item(i))
      local scroll = selected and marquee_offset(tab.name .. ":" .. i, name, text_w) or 0
      rg.text(text_x, y + math.floor(L.row_pad / 2), name,
              { width = text_w, color = selected and C.selected or C.text, scroll = scroll })
      y = y + row_h
    end
    -- Thin scroll indicator right of the list
    if list.count > lines then
      local track_h = lines * row_h
      local thumb_h = math.max(8, math.floor(track_h * lines / list.count))
      local thumb_y = top + math.floor((track_h - thumb_h) * (first - 1) / (list.count - lines))
      rg.rect(W - m + 3, thumb_y, 2, thumb_h, C.text)
    end
  end

  -- Game picture on the left
  local box_x, box_y, box_w, box_h = m, top, list_x - m * 2, L.box_h
  if tab.preview then
    local pw, ph = rg.image_size(tab.preview)
    local scale = math.min(box_w / pw, box_h / ph)
    local dw, dh = math.floor(pw * scale), math.floor(ph * scale)
    rg.image(tab.preview, box_x + math.floor((box_w - dw) / 2), box_y + math.floor((box_h - dh) / 2), dw, dh)
  elseif list.count > 0 then
    rg.rect(box_x, box_y, box_w, box_h, C.menu, 1, C.line)
    local label_h = rg.line_height() + 6
    if not logo(tab.name, "head", box_x, box_y, box_w, box_h - label_h) then
      rg.text(box_x, box_y + math.floor(box_h / 3), upper(tab.desc), { width = box_w, align = "center", color = C.model })
    end
    rg.text(box_x, box_y + box_h - label_h, "NO PICTURE", { width = box_w, align = "center", color = C.disabled })
  end

  -- Selected game's name and position
  if list.count > 0 then
    local y = box_y + box_h + (WIDE and 10 or 6)
    for _, line in ipairs(wrap_words(upper(tab.item(list.cursor)), box_w, L.name_lines)) do
      rg.text(box_x, y, line, { width = box_w, color = C.text })
      y = y + rg.line_height()
    end
    rg.text(box_x, bottom - rg.line_height(), "GAME " .. list.cursor .. " / " .. list.count, { color = C.model })
  end

  footer({ { "A", "PLAY" }, { "B", "BACK" }, { "START+SEL", "MENU" } })
end

function draw_launcher(tab)
  if tab.browsing then
    draw_games(tab)
  else
    draw_systems(tab)
  end
end

-- Menus (launcher and in-game) ----------------------------------------------------------------------
-- Light box like the original theme's menus: dark text, dark selection bar.

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
  local title_w = title and rg.measure(title, LIGHT) or 0
  local title_h = rg.line_height(LIGHT)
  local inner_w = math.max(label_w + gap + value_w, msg_w, title_w, math.floor(W * 0.6))
  inner_w = math.min(inner_w, max_w - pad * 2)
  local box_w = inner_w + pad * 2

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

  local header_h = title and (title_h + 14) or 4
  local box_h = math.min(header_h + content_h + pad, max_h)
  local box_x = math.floor((W - box_w) / 2)
  local box_y = math.floor((H - box_h) / 2)

  rg.rect(box_x, box_y, box_w, box_h, C.menu, 1, C.line)
  if title then
    rg.text(box_x, box_y + 6, title, { width = box_w, align = "center", color = C.text, bg = C.menu, font = "light.rgf" })
    rg.rect(box_x + pad, box_y + header_h - 5, inner_w, 1, C.line)
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
      rg.text(x, y + 2, opt.label, { width = inner_w, multiline = true, color = C.help, bg = C.menu })
    elseif h > 0 then
      local selected = i == dialog.selected and opt.kind == "normal"
      local bg = selected and C.text or C.menu
      local fg = selected and C.white or (opt.kind == "normal" and C.text or C.disabled)
      rg.rect(box_x + 1, y, box_w - 2, row_h, bg)
      local value = opt.value and upper(opt.value) or (opt.kind == "normal" and ">" or nil)
      local vw = value and math.min((rg.measure(value)), inner_w - gap) or 0
      if value and not WIDE then -- Small screens: cut a long value rather than its label
        vw = math.max(0, math.min(vw, inner_w - gap - (rg.measure(upper(opt.label)))))
      end
      rg.text(x, y + 3, upper(opt.label), { width = inner_w - (vw > 0 and vw + gap or 0), color = fg, bg = bg })
      if value then
        rg.text(x + inner_w - vw, y + 3, value, { width = vw, color = selected and C.selected or C.model, bg = bg })
      end
    end
    y = y + h
  end

  -- Scroll hints
  if first > 1 then rg.rect(box_x + box_w - 12, box_y + header_h - 4, 6, 2, C.text) end
  if last < #dialog.options then rg.rect(box_x + box_w - 12, box_y + box_h - 4, 6, 2, C.text) end

  return box_x, box_y, box_w, box_h
end
