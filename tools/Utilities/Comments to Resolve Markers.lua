-- Krispy Tools product: comments-to-resolve-markers
-- Release: 2026.2
-- Source SHA-256: 402bbb41ab737acb0185660b7b8325302880b339acc90692c332890954bcb752
--[[
Comments To Resolve Markers
===========================
Paste timecoded review comments and add them as timeline markers in DaVinci Resolve.

Paste comments from an email, a doc, YouTube, Frame.io or a spreadsheet. Accepted examples:
00:39 - Point marker note             [00:39] Note           (0:39) Note
00:42 - 00:46 - Duration marker note  0:42 to 0:46 Note     1m20s: Note
01:00:12:05 Note (timecode with frames)  Logo is late - 0:52  Typo at 1:05, should be Riga
CSV / tab-separated exports with a Timecode (or Time / Start / Frame) column and a Comment column.
Lines without a time are added to the comment above them.
--]]

local WINDOW_ID = "CommentsToResolveMarkersGraphite2026V3"
local WINDOW_W, WINDOW_H = 1220, 820

local MARKER_COLORS = {
    "Blue", "Cyan", "Green", "Yellow", "Red", "Pink", "Purple", "Fuchsia",
    "Rose", "Lavender", "Sky", "Mint", "Lemon", "Sand", "Cocoa", "Cream",
    "Lime", "Navy", "Gray",
}

local C = {
    bg = "#151515", panel = "#191919", bg_frame = "#191919",
    bg_input = "#202020", input = "#202020", bg_log = "#181818",
    bg_btn = "#2b2b2b", btn = "#2b2b2b", btn2 = "#252525",
    accent = "#8b5cf6", accent2 = "#d46cff", accent_hi = "#dca8ff",
    fg = "#f4f4f4", fg_dim = "#a2a2a2", dim = "#a2a2a2",
    fg_on_acc = "#101010", ok = "#56d364", warn = "#ffcc66",
    err = "#ff6b6b", border = "#535353", border_hot = "#dca8ff",
}

local SS = {
    win = ("background-color:%s; color:%s; font-family:'Segoe UI','Helvetica Neue',sans-serif;"):format(C.bg, C.fg),
    title = ("color:%s; font-size:17px; font-weight:700;"):format(C.fg),
    subtitle = ("color:%s; font-size:11px;"):format(C.fg_dim),
    label = ("color:%s; font-weight:600;"):format(C.fg),
    hint = ("color:%s; font-size:11px;"):format(C.fg_dim),
    dim = ("color:%s; font-size:8pt;"):format(C.fg_dim),
    input = ("QLineEdit, QSpinBox, QDoubleSpinBox { background-color:%s; color:%s; border:1px solid %s; border-radius:6px; padding:5px 9px; selection-background-color:%s; min-height:20px; font-weight:400; } QLineEdit:focus, QSpinBox:focus, QDoubleSpinBox:focus { border-color:%s; }"):format(C.bg_input, C.fg, C.border, C.accent, C.border_hot),
    input_fixed = ("QLineEdit { background-color:%s; color:%s; border:1px solid %s; border-radius:6px; padding:5px 9px; font-size:9pt; } QLineEdit:focus { border-color:%s; }"):format(C.bg_input, C.fg, C.border, C.border_hot),
    input_video = ("QLineEdit { background-color:%s; color:%s; border:1px solid %s; border-radius:6px; padding:5px 9px; font-size:9pt; } QLineEdit:focus { border-color:%s; }"):format(C.bg_input, C.fg, C.border, C.border_hot),
    log = ("background-color:%s; color:%s; border:1px solid %s; border-radius:7px; padding:9px; font-family:Consolas,Menlo,monospace; font-size:8pt; selection-background-color:%s;"):format(C.bg_log, C.fg, C.border, C.accent),
    btn = ("QPushButton { background-color:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #343434,stop:1 %s); color:%s; border:1px solid %s; border-radius:7px; padding:7px 14px; font-weight:600; } QPushButton:hover { border-color:%s; } QPushButton:pressed { background-color:#1c1c1c; } QPushButton:disabled { background-color:#202020; color:#666666; border-color:#363636; }"):format(C.bg_btn, C.fg, C.border, C.border_hot),
    btn_sec = ("QPushButton { background-color:%s; color:%s; border:1px solid %s; border-radius:7px; padding:7px 14px; } QPushButton:hover { border-color:%s; } QPushButton:disabled { background-color:#202020; color:#666666; border-color:#363636; }"):format(C.btn2, C.fg, C.border, C.border_hot),
    btn_acc = ("QPushButton { background-color:qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 %s,stop:1 %s); color:%s; border:1px solid %s; border-radius:7px; padding:8px 18px; font-weight:800; } QPushButton:hover { border-color:%s; } QPushButton:pressed { background-color:%s; } QPushButton:disabled { background-color:#292929; color:#6f6f6f; border-color:#3b3b3b; }"):format(C.accent, C.accent2, C.fg_on_acc, C.accent, C.accent2, C.accent),
    btn_sel = ("QPushButton { background-color:%s; color:%s; border:1px solid %s; border-radius:7px; padding:7px 14px; font-weight:700; }"):format(C.bg_btn, C.fg, C.accent),
    btn_to = ("QPushButton { background-color:%s; color:%s; border:1px solid %s; border-radius:7px; padding:7px 14px; }"):format(C.btn2, C.fg, C.border),
    btn_to_sel = ("QPushButton { background-color:%s; color:%s; border:1px solid %s; border-radius:7px; padding:7px 14px; font-weight:700; }"):format(C.bg_btn, C.fg, C.accent),
    btn_tab = ("QPushButton { background-color:%s; color:%s; border:1px solid %s; border-radius:6px; padding:6px 9px; font-size:8pt; } QPushButton:hover { border-color:%s; }"):format(C.bg_btn, C.fg_dim, C.border, C.border_hot),
    btn_tab_active = ("QPushButton { background-color:%s; color:%s; border:1px solid %s; border-radius:6px; padding:6px 9px; font-size:8pt; font-weight:700; }"):format(C.bg_input, C.fg, C.accent),
    combo = ("QComboBox { background-color:%s; color:%s; border:1px solid %s; border-radius:6px; padding:4px 9px; } QComboBox:hover { border-color:%s; } QComboBox::drop-down { width:22px; border:none; background:transparent; } QComboBox QAbstractItemView { background-color:%s; color:%s; selection-background-color:%s; border:1px solid %s; }"):format(C.bg_input, C.fg, C.border, C.border_hot, C.bg_input, C.fg, C.accent, C.border),
    tree = ("background-color:%s; color:%s; border:1px solid %s; border-radius:7px; font-size:8pt; selection-background-color:%s;"):format(C.bg_input, C.fg, C.border, C.accent),
    frame = ("background-color:%s; border:1px solid %s; border-radius:7px; padding:6px;"):format(C.bg_frame, C.border),
    check = ("QCheckBox { color:%s; } QCheckBox::indicator { width:15px; height:15px; }"):format(C.fg),
    sep = ("background-color:%s;"):format(C.border),
    bar = ("background-color:%s;"):format(C.accent),
    footer = ("color:%s; font-size:10px;"):format(C.fg_dim),
}

local SAMPLE = [[00:04 - Start on the wide shot, the close-up feels too sudden.
[00:09 - 00:14] Music is too loud under the voice here.
- 0:21 Colour on this shot is warmer than the rest.
Typo in the lower third at 0:27, it should say "Riga".
0:33 to 0:38: Hold this shot a little longer,
the product is only on screen for a moment.
1m02s - Logo should animate out instead of cutting.]]

local function trim(value)
    value = tostring(value or "")
    return value:match("^%s*(.-)%s*$")
end

local function html_escape(value)
    return tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function strip_html(value)
    local text = tostring(value or "")
    text = text:gsub("<br%s*/?>", "\n")
    text = text:gsub("</p>", "\n")
    text = text:gsub("<[^>]+>", "")
    text = text:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&")
    text = text:gsub("&quot;", '"'):gsub("&#39;", "'")
    return text
end

local function get_widget_text(widget)
    local ok, value = pcall(function() return widget.PlainText end)
    if ok and value and tostring(value) ~= "" then return tostring(value) end
    ok, value = pcall(function() return widget.Text end)
    if ok and value and tostring(value) ~= "" then return tostring(value) end
    ok, value = pcall(function() return widget.HTML end)
    if ok and value and tostring(value) ~= "" then return strip_html(value) end
    return ""
end

local function set_widget_text(widget, value)
    pcall(function() widget.PlainText = tostring(value or "") end)
    pcall(function() widget.Text = tostring(value or "") end)
end

local function log_append(widget, message, tag)
    local colors = { info=C.fg, ok=C.ok, warn=C.warn, err=C.err, head=C.accent, dim=C.dim }
    local color = colors[tag] or C.fg
    widget.HTML = tostring(widget.HTML or "") .. ('<span style="color:%s">%s</span><br>'):format(color, html_escape(message))
    pcall(function() widget:MoveCursor("End", "MoveAnchor") end)
end

local function log_clear(widget)
    widget.HTML = ""
end

local function get_resolve()
    if fusion and fusion.GetResolve then
        local ok, resolve = pcall(function() return fusion:GetResolve() end)
        if ok and resolve then return resolve end
    end
    if Resolve then return Resolve() end
    if bmd and bmd.scriptapp then return bmd.scriptapp("Resolve") end
    return nil
end

local function parse_fps(value)
    local n = tonumber(tostring(value or ""):match("[%d%.]+"))
    if not n or n <= 0 then return nil end
    return n
end

local function current_timeline()
    local resolve = get_resolve()
    if not resolve then return nil, nil, 0, "Could not connect to Resolve." end
    local project_manager = resolve:GetProjectManager()
    local project = project_manager and project_manager:GetCurrentProject()
    if not project then return nil, nil, 0, "Open a Resolve project first." end
    local timeline = project:GetCurrentTimeline()
    if not timeline then return nil, nil, 0, "Open a timeline first." end
    local fps = parse_fps(timeline:GetSetting("timelineFrameRate")) or parse_fps(project:GetSetting("timelineFrameRate")) or 24
    local timeline_start = 0
    pcall(function() timeline_start = tonumber(timeline:GetStartFrame()) or 0 end)
    return timeline, fps, timeline_start, nil
end

local function resolve_marker_color(value)
    value = tostring(value or "")
    for _, color in ipairs(MARKER_COLORS) do
        if color:lower() == value:lower() then return color end
    end
    return "Blue"
end

local function color_from_index(index)
    local i = tonumber(index) or 0
    return MARKER_COLORS[i + 1] or "Blue"
end

-- ---------------------------------------------------------------------------
-- Comment parsing. Accepts most review formats:
--   00:39 note | [00:39] note | (0:39) note | @0:39 note | 1m20s note
--   01:00:12:05 note (timecode with frames, ; = drop frame) | 1:02:03.5 note
--   ranges: 0:42 - 0:46 / 0:42-0:46 / 0:42 to 0:46 / 0:42 -> 0:46 / 0:42 ~ 0:46
--   time at the end ("Logo is late - 0:52") or inside a sentence
--   bullets and numbered lists, comments that wrap onto the next lines
--   CSV / tab-separated exports with a Timecode (or Time/Start/Frame) and a Comment column
-- ---------------------------------------------------------------------------

local TC_PATTERNS = {
    { "%f[%d](%d%d?):(%d%d):(%d%d)([:;])(%d%d)%f[%D]", "hmsf" },
    { "%f[%d](%d+):(%d%d):(%d%d)[%.,](%d+)%f[%D]", "hmsd" },
    { "%f[%d](%d+):(%d%d):(%d%d)%f[%D]", "hms" },
    { "%f[%d](%d+):(%d%d)[%.,](%d+)%f[%D]", "msd" },
    { "%f[%d](%d+):(%d%d)%f[%D]", "ms" },
    { "%f[%w](%d+)h%s*(%d+)m%s*(%d+)s%f[%W]", "hms" },
    { "%f[%w](%d+)h%s*(%d+)m%f[%W]", "hm" },
    { "%f[%w](%d+)m%s*(%d+)s%f[%W]", "ms" },
}

local function make_token(kind, c)
    local n = function(i) return tonumber(c[i]) end
    local t = { kind = kind, h = 0, m = 0, s = 0, f = 0, dec = 0, drop = false }
    if kind == "hmsf" then
        t.h, t.m, t.s, t.f = n(3), n(4), n(5), n(7)
        t.drop = (c[6] == ";")
        if t.f >= 100 then return nil end
    elseif kind == "hmsd" then
        t.h, t.m, t.s = n(3), n(4), n(5)
        t.dec = tonumber("0." .. c[6]) or 0
    elseif kind == "hms" then
        t.h, t.m, t.s = n(3), n(4), n(5)
    elseif kind == "msd" then
        t.m, t.s = n(3), n(4)
        t.dec = tonumber("0." .. c[5]) or 0
    elseif kind == "ms" then
        t.m, t.s = n(3), n(4)
    elseif kind == "hm" then
        t.h, t.m = n(3), n(4)
    end
    if not (t.h and t.m and t.s) then return nil end
    if t.s >= 60 then return nil end
    if (kind == "hmsf" or kind == "hmsd" or kind == "hms" or kind == "hm") and t.m >= 60 then return nil end
    t.seconds = t.h * 3600 + t.m * 60 + t.s + t.dec
    return t
end

local function find_token(line, init)
    local best = nil
    for _, p in ipairs(TC_PATTERNS) do
        local c = { line:find(p[1], init) }
        if c[1] and (not best or c[1] < best.pos or (c[1] == best.pos and c[2] > best.last)) then
            local tok = make_token(p[2], c)
            if tok then
                tok.pos, tok.last = c[1], c[2]
                best = tok
            end
        end
    end
    return best
end

local function token_order(t)
    return t.seconds * 1000 + t.f
end

local function display_time(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    local whole = math.floor(seconds + 0.5)
    local h = math.floor(whole / 3600)
    local m = math.floor((whole % 3600) / 60)
    local s = whole % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

local function token_label(t)
    if t.kind == "hmsf" then return string.format("%02d:%02d:%02d%s%02d", t.h, t.m, t.s, t.drop and ";" or ":", t.f) end
    return display_time(t.seconds)
end

local function normalize_line(line)
    line = tostring(line or "")
    line = line:gsub("\226\134\146", "->")                      -- arrow
    line = line:gsub("\226\128\147", "-"):gsub("\226\128\148", "-") -- en / em dash
    line = line:gsub("\194\160", " "):gsub("\t", " ")
    return trim(line)
end

local function trim_separators(text)
    text = tostring(text or "")
    text = text:gsub("^[%s%-:|,;@>=~%.]+", "")
    text = text:gsub("[%s%-:|@>=~]+$", "")
    return trim(text)
end

local function strip_list_marker(text)
    text = trim(text)
    text = text:gsub("^\226\128\162%s*", "")         -- bullet
    text = text:gsub("^[%-%*%+]+%s+", "")
    text = text:gsub("^#%d+%s*", "")
    text = text:gsub("^%d+[%.%)]%s+", "")
    text = text:gsub("^%d+[%.%)]$", "")
    return trim(text)
end

local RANGE_SEPARATORS = { "^%s*%-+>%s*", "^%s*=>%s*", "^%s*%-%s*", "^%s*~%s*", "^%s+to%s+", "^%s+until%s+" }

-- Returns a marker table, or nil when the line holds no time.
local function parse_comment_line(raw, index)
    local line = normalize_line(raw)
    if line == "" then return nil end
    local first = find_token(line, 1)
    if not first then return nil end

    local last, finish = first, nil
    local after = line:sub(first.last + 1)
    for _, pattern in ipairs(RANGE_SEPARATORS) do
        local sep = after:match(pattern)
        if sep then
            local at = first.last + 1 + #sep
            local cand = find_token(line, at)
            if cand and cand.pos == at and token_order(cand) > token_order(first) then
                finish, last = cand, cand
            end
            break
        end
    end

    local prefix = line:sub(1, first.pos - 1):gsub("[%[%(@]%s*$", "")
    prefix = trim(prefix):gsub("%s+at$", ""):gsub("^at$", "")
    prefix = trim_separators(strip_list_marker(prefix))
    local suffix = trim_separators((line:sub(last.last + 1):gsub("^%s*[%]%)]", "")))

    local note
    if prefix == "" then
        note = suffix
    elseif suffix == "" then
        note = prefix
    else
        note = strip_list_marker(line) -- the time sits inside a sentence: keep the whole sentence
    end

    return {
        line = index,
        start = first,
        finish = finish,
        start_seconds = first.seconds,
        end_seconds = finish and finish.seconds or nil,
        note = note,
        ranged = finish ~= nil,
    }
end

local function split_csv(text, delim)
    local rows, row, field, inq = {}, {}, {}, false
    local i, n = 1, #text
    while i <= n do
        local c = text:sub(i, i)
        if inq then
            if c == '"' then
                if text:sub(i + 1, i + 1) == '"' then field[#field + 1] = '"'; i = i + 1 else inq = false end
            else
                field[#field + 1] = c
            end
        elseif c == '"' then
            inq = true
        elseif c == delim then
            row[#row + 1] = table.concat(field); field = {}
        elseif c == "\n" then
            row[#row + 1] = table.concat(field); field = {}
            rows[#rows + 1] = row; row = {}
        elseif c ~= "\r" then
            field[#field + 1] = c
        end
        i = i + 1
    end
    if #field > 0 or #row > 0 then row[#row + 1] = table.concat(field); rows[#rows + 1] = row end
    return rows
end

-- Spreadsheet-style exports (Frame.io CSV, Google Sheets, Excel). Returns nil if the text is not a table.
local function parse_table(text)
    local first_line = text:match("^%s*([^\r\n]+)") or ""
    local delim = nil
    if first_line:find("\t") then delim = "\t" elseif first_line:find(",") then delim = "," elseif first_line:find(";") then delim = ";" end
    if not delim then return nil end
    local rows = split_csv(text, delim)
    if #rows < 2 then return nil end
    local cols = {}
    for i, cell in ipairs(rows[1]) do
        local h = trim(cell):lower()
        if not cols.time and (h:find("timecode") or h:find("timestamp") or h == "time" or h == "tc" or h == "in" or h:find("^start") or h:find("^time ") or h == "position") then cols.time = i
        elseif not cols.frame and h:find("^frame") then cols.frame = i
        elseif not cols.finish and (h:find("^end") or h == "out" or h:find("^out ")) then cols.finish = i
        elseif not cols.author and (h:find("author") or h:find("commenter") or h == "name" or h == "user" or h:find("reviewer")) then cols.author = i
        elseif not cols.note and not h:find("#") and not h:find("number") and not h:find("^id") and (h:find("comment") or h:find("note") or h == "text" or h:find("feedback") or h:find("description") or h == "message") then cols.note = i
        end
    end
    if not cols.note or not (cols.time or cols.frame) then return nil end

    local markers, warnings = {}, {}
    for r = 2, #rows do
        local row = rows[r]
        local note = trim(row[cols.note] or "")
        local tok = cols.time and find_token(normalize_line(row[cols.time] or ""), 1) or nil
        if not tok and cols.frame then
            local fr = tonumber(trim(row[cols.frame] or ""))
            if fr then tok = { kind = "frames", h = 0, m = 0, s = 0, f = 0, dec = 0, frames = fr, seconds = 0 } end
        end
        if tok then
            local fin = cols.finish and find_token(normalize_line(row[cols.finish] or ""), 1) or nil
            if fin and token_order(fin) <= token_order(tok) then fin = nil end
            local author = cols.author and trim(row[cols.author] or "") or ""
            if author ~= "" then note = note .. " (" .. author .. ")" end
            if note == "" then note = "(no comment text)" end
            markers[#markers + 1] = { line = r, start = tok, finish = fin, start_seconds = tok.seconds, end_seconds = fin and fin.seconds or nil, note = note, ranged = fin ~= nil }
        elseif table.concat(row, ""):match("%S") then
            warnings[#warnings + 1] = ("Row %d has no usable time, skipped."):format(r)
        end
    end
    return markers, warnings
end

local function parse_comments(text)
    text = tostring(text or ""):gsub("^\239\187\191", ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    local markers, warnings = parse_table(text)
    if not markers then
        markers, warnings = {}, {}
        local last, gap = nil, false
        local index = 0
        for line in (text .. "\n"):gmatch("(.-)\n") do
            index = index + 1
            if trim(line) == "" then
                gap = true
            else
                local marker = parse_comment_line(line, index)
                if marker then
                    markers[#markers + 1] = marker
                    last, gap = marker, false
                elseif last and (not gap or last.note == "") then
                    -- a comment that wraps onto the next line(s)
                    local extra = strip_list_marker(normalize_line(line))
                    last.note = (last.note == "") and extra or (last.note .. " " .. extra)
                    gap = false
                else
                    warnings[#warnings + 1] = ("Line %d has no time, skipped: %s"):format(index, trim(line))
                end
            end
        end
        for _, m in ipairs(markers) do
            if m.note == "" then m.note = "(no comment text)" end
        end
    end
    table.sort(markers, function(a, b)
        local fa = a.start.frames or 0
        local fb = b.start.frames or 0
        if a.start_seconds + fa ~= b.start_seconds + fb then return a.start_seconds + fa < b.start_seconds + fb end
        return a.line < b.line
    end)
    return markers, warnings
end

-- Converts a time token to frames on the timeline (before any timeline-start correction).
local function token_frames(t, fps)
    if t.kind == "frames" then return math.floor(t.frames + 0.5) end
    local nominal = math.floor(fps + 0.5)
    if t.kind == "hmsf" then
        if t.drop and (nominal == 30 or nominal == 60) then
            local drop = (nominal == 60) and 4 or 2
            local total_min = t.h * 60 + t.m
            return (t.h * 3600 + t.m * 60 + t.s) * nominal + t.f - drop * (total_min - math.floor(total_min / 10))
        end
        return (t.h * 3600 + t.m * 60 + t.s) * nominal + t.f
    end
    return math.floor(t.seconds * nominal + 0.5)
end

local TIME_MODES = { "Auto-detect", "From video start (0:00)", "Timeline timecode (01:00:00:00)" }

local function marker_title(marker, prefix, max_len)
    prefix = trim(prefix)
    max_len = tonumber(max_len) or 54
    local title = marker.ranged and "Review range" or "Review note"
    if prefix ~= "" then title = prefix end
    title = title .. " " .. display_time(marker.start_seconds)
    if marker.ranged then title = title .. "-" .. display_time(marker.end_seconds) end
    if #title > max_len then title = title:sub(1, max_len) end
    return title
end

-- time_mode: 0 auto, 1 from 0:00, 2 timeline timecode
local function marker_rows(text, fps, timeline_start, time_mode, point_duration, title_prefix)
    local parsed, warnings = parse_comments(text)
    local rows = {}
    fps = tonumber(fps) or 24
    timeline_start = tonumber(timeline_start) or 0
    time_mode = tonumber(time_mode) or 0
    point_duration = math.max(1, math.floor(tonumber(point_duration) or 1))

    for _, marker in ipairs(parsed) do
        local frame = token_frames(marker.start, fps)
        local finish = marker.finish and token_frames(marker.finish, fps) or nil
        local timeline_tc = false
        if time_mode == 2 then
            timeline_tc = true
        elseif time_mode == 0 and timeline_start > 0 and marker.start.kind ~= "frames" and marker.start.h >= 1 and frame >= timeline_start then
            timeline_tc = true
        elseif time_mode == 0 and marker.start.kind == "frames" and timeline_start > 0 and frame >= timeline_start then
            timeline_tc = true
        end
        if timeline_tc then
            frame = frame - timeline_start
            if finish then finish = finish - timeline_start end
        end
        if frame < 0 then
            warnings[#warnings + 1] = ("Line %d (%s) is before the timeline start, skipped."):format(marker.line, token_label(marker.start))
        else
            local duration = point_duration
            if finish then duration = math.max(1, finish - frame) end
            rows[#rows + 1] = {
                marker = marker,
                frame = frame,
                duration = duration,
                title = marker_title(marker, title_prefix),
                timeline_tc = timeline_tc,
            }
        end
    end
    return rows, warnings
end

local function build_preview(rows, warnings, fps, timeline_start)
    local lines = {}
    table.insert(lines, ("Timeline fps: %.3f | start frame: %d"):format(tonumber(fps) or 24, tonumber(timeline_start) or 0))
    table.insert(lines, ("Parsed markers: %d"):format(#rows))
    table.insert(lines, "")
    for _, row in ipairs(rows) do
        local marker = row.marker
        local range_text = marker.start.kind == "frames" and ("frame " .. tostring(marker.start.frames)) or token_label(marker.start)
        if marker.ranged then range_text = range_text .. " - " .. token_label(marker.finish) end
        local tc_note = row.timeline_tc and " (timeline timecode)" or ""
        table.insert(lines, ("%s%s | frame %d | %d fr | %s"):format(range_text, tc_note, row.frame, row.duration, marker.note))
    end
    if #warnings > 0 then
        table.insert(lines, "")
        table.insert(lines, "Warnings:")
        for _, warning in ipairs(warnings) do table.insert(lines, warning) end
    end
    return table.concat(lines, "\n")
end

local function add_markers(timeline, rows, color)
    local added, failed, beyond, bumped = 0, 0, 0, 0
    color = resolve_marker_color(color)
    -- AddMarker frames are relative to the timeline start. Anything at or past the
    -- timeline length would be invisible, so report it instead of adding it.
    local length = nil
    pcall(function() length = (tonumber(timeline:GetEndFrame()) or 0) - (tonumber(timeline:GetStartFrame()) or 0) end)
    for _, row in ipairs(rows) do
        if length and length > 0 and row.frame >= length then
            beyond = beyond + 1
        else
            local custom = ("COMMENTS_TO_MARKERS|line=%d|start=%s"):format(row.marker.line, token_label(row.marker.start))
            -- Resolve allows one marker per frame. If a frame is taken, use the next free frame.
            local ok, shift = false, 0
            while not ok and shift <= 12 do
                local frame = row.frame + shift
                if length and length > 0 and frame >= length then break end
                ok = timeline:AddMarker(frame, color, row.title, row.marker.note, row.duration, custom)
                if not ok then shift = shift + 1 end
            end
            if ok then
                added = added + 1
                if shift > 0 then bumped = bumped + 1 end
            else
                failed = failed + 1
            end
        end
    end
    return added, failed, beyond, bumped
end

if rawget(_G, "CTM_SELFTEST") then
    return { parse_comments = parse_comments, marker_rows = marker_rows, build_preview = build_preview }
end

if not fusion or not bmd or not bmd.UIDispatcher then
    print("Comments To Resolve Markers needs Resolve/Fusion UIManager. Run it from DaVinci Resolve's Workspace > Scripts menu.")
    return
end

local ui = fusion.UIManager
local disp = bmd.UIDispatcher(ui)

local function sep()
    return ui:Label{Weight=0, MinimumSize={1,1}, MaximumSize={9999,1}, StyleSheet=SS.sep}
end

local SIDE_GUTTER = 28
local BOTTOM_GUTTER = 24
local ROW_H = 46
local CONTROL_H = 38

local win = disp:AddWindow({
    ID = WINDOW_ID,
    WindowTitle = "Comments To Resolve Markers",
    Geometry = { 130, 80, WINDOW_W, WINDOW_H },
    MinimumSize = { WINDOW_W, WINDOW_H },
    StyleSheet = SS.win,
}, {
    ui:VGroup{Spacing=0,
        ui:VGap(22),
        ui:HGroup{Weight=1, Spacing=0,
            ui:HGap(SIDE_GUTTER),
            ui:VGroup{Weight=1, Spacing=8,
                ui:HGroup{Weight=0, Spacing=12, MinimumSize={0,34}, MaximumSize={9999,34},
                    ui:Label{Weight=0, MinimumSize={5,34}, MaximumSize={5,34}, StyleSheet=SS.bar},
                    ui:Label{Text="Comments To Resolve Markers", StyleSheet=SS.title, Weight=1, MinimumSize={0,34}, MaximumSize={9999,34}},
                },
                ui:Label{Text="Paste comments from an email, doc, YouTube, Frame.io or a CSV. Any line with a time (0:39, [0:39], 00:00:39:12, 1m20s) becomes a marker, ranges (0:42 - 0:46) become duration markers, and lines without a time join the comment above.", WordWrap=true, StyleSheet=SS.dim, Weight=0, MinimumSize={0,34}},
                sep(),
                ui:HGroup{Weight=0, Spacing=8, MinimumSize={0,ROW_H}, MaximumSize={9999,ROW_H},
                    ui:Label{Text="Marker color:", StyleSheet=SS.label, Weight=0, MinimumSize={90,ROW_H}, MaximumSize={90,ROW_H}},
                    ui:ComboBox{ID="Color", StyleSheet=SS.combo, Weight=0, MinimumSize={150,CONTROL_H}, MaximumSize={150,CONTROL_H}},
                    ui:Label{Text="Title prefix:", StyleSheet=SS.label, Weight=0, MinimumSize={78,ROW_H}, MaximumSize={78,ROW_H}},
                    ui:LineEdit{ID="TitlePrefix", Text="Review", StyleSheet=SS.input, Weight=1, MinimumSize={180,CONTROL_H}, MaximumSize={9999,CONTROL_H}},
                    ui:Label{Text="Point duration:", StyleSheet=SS.label, Weight=0, MinimumSize={110,ROW_H}, MaximumSize={110,ROW_H}},
                    ui:SpinBox{ID="PointDuration", Value=1, Minimum=1, Maximum=600, StyleSheet=SS.input, Weight=0, MinimumSize={130,CONTROL_H}, MaximumSize={130,CONTROL_H}},
                    ui:Label{Text="Times:", StyleSheet=SS.label, Weight=0, MinimumSize={48,ROW_H}, MaximumSize={48,ROW_H}},
                    ui:ComboBox{ID="TimeMode", StyleSheet=SS.combo, Weight=0, MinimumSize={240,CONTROL_H}, MaximumSize={240,CONTROL_H}},
                },
                ui:HGroup{Weight=1, Spacing=12,
                    ui:VGroup{Weight=1, Spacing=6,
                        ui:Label{Text="Comments:", StyleSheet=SS.label, Weight=0, MinimumSize={0,22}, MaximumSize={9999,22}},
                        ui:TextEdit{ID="Comments", StyleSheet=SS.log, Weight=1, MinimumSize={0,398}},
                    },
                    ui:VGroup{Weight=1, Spacing=6,
                        ui:Label{Text="Preview:", StyleSheet=SS.label, Weight=0, MinimumSize={0,22}, MaximumSize={9999,22}},
                        ui:TextEdit{ID="Preview", ReadOnly=true, StyleSheet=SS.log, Weight=1, MinimumSize={0,398}},
                    },
                },
                sep(),
                ui:HGroup{Weight=0, Spacing=8, MinimumSize={0,44}, MaximumSize={9999,44},
                    ui:Button{ID="Sample", Text="Load Example", StyleSheet=SS.btn_sec, MinimumSize={130,36}, MaximumSize={130,36}, Weight=0},
                    ui:Button{ID="Clear", Text="Clear", StyleSheet=SS.btn_sec, MinimumSize={90,36}, MaximumSize={90,36}, Weight=0},
                    ui:Button{ID="PreviewButton", Text="Preview Markers", StyleSheet=SS.btn, MinimumSize={160,36}, MaximumSize={160,36}, Weight=0},
                    ui:Label{Weight=1},
                    ui:Button{ID="Add", Text="Add Markers To Current Timeline", StyleSheet=SS.btn_acc, MinimumSize={280,36}, MaximumSize={280,36}, Weight=0},
                },
                ui:TextEdit{ID="Log", ReadOnly=true, StyleSheet=SS.log, Weight=0, MinimumSize={0,54}, MaximumSize={9999,54}},
            },
            ui:HGap(SIDE_GUTTER),
        },
        ui:VGap(BOTTOM_GUTTER),
    }
})

local itm = win:GetItems()
for _, color in ipairs(MARKER_COLORS) do itm.Color:AddItem(color) end
itm.Color.CurrentIndex = 4 -- Red
for _, mode in ipairs(TIME_MODES) do itm.TimeMode:AddItem(mode) end
itm.TimeMode.CurrentIndex = 0
set_widget_text(itm.Comments, SAMPLE)

local state = {
    rows = {},
    warnings = {},
    fps = 24,
    timeline_start = 0,
}

local function refresh_preview()
    log_clear(itm.Log)
    local timeline, fps, timeline_start, err = current_timeline()
    if err then
        log_append(itm.Log, err, "warn")
        fps = 24
        timeline_start = 0
    end
    local text = get_widget_text(itm.Comments)
    local rows, warnings = marker_rows(
        text,
        fps,
        timeline_start,
        tonumber(itm.TimeMode.CurrentIndex) or 0,
        itm.PointDuration.Value,
        itm.TitlePrefix.Text
    )
    state.rows = rows
    state.warnings = warnings
    state.fps = fps
    state.timeline_start = timeline_start
    set_widget_text(itm.Preview, build_preview(rows, warnings, fps, timeline_start))

    if #rows == 0 then
        log_append(itm.Log, "No valid marker comments found yet.", "warn")
    else
        local ranged = 0
        for _, row in ipairs(rows) do if row.marker.ranged then ranged = ranged + 1 end end
        log_append(itm.Log, ("Ready: %d marker(s), %d ranged, %d regular."):format(#rows, ranged, #rows - ranged), "ok")
    end
    if #warnings > 0 then
        log_append(itm.Log, ("%d line(s) could not be parsed. See Preview warnings."):format(#warnings), "warn")
    end
    return timeline
end

win.On.Sample.Clicked = function()
    set_widget_text(itm.Comments, SAMPLE)
    refresh_preview()
end

win.On.Clear.Clicked = function()
    set_widget_text(itm.Comments, "")
    set_widget_text(itm.Preview, "")
    log_clear(itm.Log)
end

win.On.PreviewButton.Clicked = function()
    refresh_preview()
end

win.On.TimeMode.CurrentIndexChanged = function()
    refresh_preview()
end

win.On.Add.Clicked = function()
    local timeline = refresh_preview()
    if not timeline then return end
    if #state.rows == 0 then
        log_append(itm.Log, "Nothing to add. Paste comments with timecodes first.", "warn")
        return
    end
    local color = color_from_index(itm.Color.CurrentIndex)
    local added, failed, beyond, bumped = add_markers(timeline, state.rows, color)
    if added > 0 then log_append(itm.Log, ("Added %d marker(s) to the current timeline."):format(added), "ok") end
    if bumped > 0 then log_append(itm.Log, ("%d marker(s) moved by a frame or two because a marker already sat on that frame."):format(bumped), "warn") end
    if failed > 0 then log_append(itm.Log, ("Failed to add %d marker(s)."):format(failed), "err") end
    if beyond > 0 then log_append(itm.Log, ("Skipped %d comment(s) that fall after the end of this timeline. Check the timecodes or the Times setting."):format(beyond), "warn") end
end

win.On.Close = function() disp:ExitLoop() end
win.On[WINDOW_ID].Close = function() disp:ExitLoop() end

refresh_preview()
win:Show()
disp:RunLoop()
win:Hide()
