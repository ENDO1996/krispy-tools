-- Krispy Tools product: caption-titler
-- Release: 2026.2
-- Source SHA-256: f6c829abdbf29ebe5607fc1a5f4b3279f0cbe4bc9f45d4bea1d0a94fb42a0fd0
--[[
Caption Titler  (Lua)  -  Krispy Tools
=====================================
Build styled Text+ captions from subtitles, using your own title template.

INSTALLATION
Windows: %APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility\
macOS:   ~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/
Run via: Workspace > Scripts > Utility > Caption Titler

Requires DaVinci Resolve Studio 19.1 or newer.
Also part of Resolve Text Toolkit, which has all five tools in one window.
--]]

-- Build switch. nil = the full Resolve Text Toolkit with all five tabs.
-- The single-tool releases are generated from this file with ONLY_TAB = 1..5
-- (1 Subtitle Creator, 2 Caption Titler, 3 SRT Replacer, 4 Font Changer, 5 Template Duplicator).
local ONLY_TAB = 2
local SINGLE_TOOLS = {
    { title = "Subtitle Creator",    id = "KrispySubtitleCreator2026",    blurb = "Turn Text+ clips into a real subtitle track and an SRT file." },
    { title = "Caption Titler",      id = "KrispyCaptionTitler2026",      blurb = "Build styled Text+ captions from subtitles, using your own title template." },
    { title = "SRT Replacer",        id = "KrispySrtReplacer2026",        blurb = "Swap the text of your Text+ captions for a translated SRT, keeping style and timing." },
    { title = "Font Changer",        id = "KrispyFontChanger2026",        blurb = "Change the font on every Text+ clip in one click." },
    { title = "Template Duplicator", id = "KrispyTemplateDuplicator2026", blurb = "Move every caption onto another title template, keeping text and timing." },
}

-- ================================================================
--  Platform detection
-- ================================================================
local IS_WINDOWS = (os.getenv("SYSTEMROOT") ~= nil or os.getenv("windir") ~= nil)

-- ================================================================
--  Utility helpers
-- ================================================================
local function sleep(secs)
    local deadline = os.clock() + secs
    while os.clock() < deadline do end
end

local function trim(s)
    return (s or ""):match("^%s*(.-)%s*$")
end

local function normalize_text_breaks(s)
    s = tostring(s or "")
    s = s:gsub("\226\128\168", "\n"):gsub("\226\128\169", "\n")
    s = s:gsub("\\r\\n", "\n"):gsub("\\n", "\n"):gsub("\\N", "\n")
    s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
    s = s:gsub("%[br%]", "\n"):gsub("%[BR%]", "\n")
    s = s:gsub("<br%s*/?>", "\n"):gsub("<BR%s*/?>", "\n")
    s = s:gsub("[ \t]+\n", "\n"):gsub("\n[ \t]+", "\n")
    return s
end

local function split_lines(s)
    s = normalize_text_breaks(s)
    local lines = {}
    local i, len = 1, #s
    while i <= len do
        local j = s:find("\n", i, true)
        if j then
            table.insert(lines, s:sub(i, j - 1))
            i = j + 1
        else
            table.insert(lines, s:sub(i))
            break
        end
    end
    return lines
end

local function split_words(s)
    local words = {}
    for w in s:gmatch("%S+") do table.insert(words, w) end
    return words
end

local function short_str(text, length)
    length = length or 40
    local t = trim((text or ""):gsub("\n", " "))
    return #t > length and (t:sub(1, length) .. "...") or t
end

local function show_breaks(text, length)
    length = length or 40
    local t = trim((text or ""):gsub("\n", "[br]"))
    return #t > length and (t:sub(1, length) .. "...") or t
end

local function truncate_path(path, max_len)
    max_len = max_len or 50
    if #path <= max_len then return path end
    local filename = path:match("[^/\\]+$") or path
    if #filename >= max_len - 5 then
        return "..." .. filename:sub(-(max_len - 3))
    end
    return path:sub(1, max_len - #filename - 5) .. ".../" .. filename
end

local function next_key(t) -- check if table is non-empty
    return t and next(t) ~= nil
end

local function make_temp_path(suffix)
    suffix = suffix or ".tmp"
    if IS_WINDOWS then
        local d = os.getenv("TEMP") or os.getenv("TMP") or "C:\\Windows\\Temp"
        return d .. "\\resolve_rtk_" .. os.time() .. suffix
    end
    return "/tmp/resolve_rtk_" .. os.time() .. suffix
end

local function path_join(dir, name)
    local sep = IS_WINDOWS and "\\" or "/"
    if dir:sub(-1) == "\\" or dir:sub(-1) == "/" then return dir .. name end
    return dir .. sep .. name
end

local function default_documents_dir()
    local home = (IS_WINDOWS and os.getenv("USERPROFILE") or os.getenv("HOME")) or os.getenv("USERPROFILE") or ""
    if home == "" then return IS_WINDOWS and "C:\\Windows\\Temp" or "/tmp" end
    return IS_WINDOWS and (home .. "\\Documents") or (home .. "/Documents")
end

local function safe_filename(name)
    name = trim(name or "timeline")
    name = name:gsub("[\\/:*?\"<>|]", "_")
    name = name:gsub("%s+", "_")
    name = name:gsub("_+", "_")
    if name == "" then name = "timeline" end
    return name
end

-- ================================================================
--  LOGIC: SRT parsing
-- ================================================================
local function ms_to_frames(ms, fps_val)
    return math.floor(ms * fps_val / 1000.0 + 0.5)
end

local function normalize_srt_hour_jumps(entries)
    local one_hour_ms = 60 * 60 * 1000
    local max_gap_ms  = 10 * 60 * 1000
    local small_gap_ms = 2500
    local adjusted_entries = {}
    local adjusted_count = 0

    local function mark_adjusted(i)
        if not adjusted_entries[i] then
            adjusted_entries[i] = true
            adjusted_count = adjusted_count + 1
        end
    end

    local function rounded_hour_shift(ms)
        return math.floor((math.abs(ms) + one_hour_ms / 2) / one_hour_ms) * one_hour_ms
    end

    local function apply_best_shift(i, entry, prev_end, gap)
        local duration = entry.end_ms - entry.start_ms
        local candidates = {}
        local rounded = rounded_hour_shift(gap)
        if rounded > 0 then
            table.insert(candidates, { shift = gap > 0 and -rounded or rounded, prefer = true })
        end
        table.insert(candidates, { shift = -gap, prefer = false })

        local best_shift, best_score = nil, nil
        for _, candidate in ipairs(candidates) do
            local shift = candidate.shift
            local new_start = entry.start_ms + shift
            local new_end = new_start + duration
            local new_gap = new_start - prev_end
            if new_start >= 0 and new_end > new_start and math.abs(new_gap) <= max_gap_ms then
                local score = math.abs(new_gap)
                if candidate.prefer and score <= small_gap_ms then
                    score = -small_gap_ms + score
                end
                if not best_score or score < best_score then
                    best_shift, best_score = shift, score
                end
            end
        end
        if best_shift then
            entry.start_ms = entry.start_ms + best_shift
            entry.end_ms = entry.start_ms + duration
            mark_adjusted(i)
            return true
        end
        return false
    end

    for i, entry in ipairs(entries) do
        if i > 1 then
            local prev_end = entries[i - 1].end_ms
            local gap = entry.start_ms - prev_end
            if math.abs(gap) > max_gap_ms then
                apply_best_shift(i, entry, prev_end, gap)
            end
        end

        local duration = entry.end_ms - entry.start_ms
        if math.abs(duration) > max_gap_ms then
            local shift = rounded_hour_shift(duration)
            if shift > 0 then
                if duration > 0 then shift = -shift end
                local new_end = entry.end_ms + shift
                local new_duration = new_end - entry.start_ms
                if new_end > entry.start_ms and math.abs(new_duration) <= max_gap_ms then
                    entry.end_ms = new_end
                    mark_adjusted(i)
                end
            end
        end
    end

    return adjusted_count
end

local function parse_srt_clock(raw, inferred_hour)
    raw = trim(raw or "")
    local clock, ms = raw:match("^(.-)[,.](%d+)$")
    if not clock then return nil, false end
    -- Match the complete clock, not digits embedded in malformed input.
    if not (clock:match("^%d+:%d%d:%d%d$") or clock:match("^%d%d:%d%d$")) then
        return nil, false
    end

    local parts = {}
    for p in clock:gmatch("%d+") do table.insert(parts, tonumber(p)) end
    local h, m, s, repaired = 0, 0, 0, false
    if #parts == 3 then
        h, m, s = parts[1], parts[2], parts[3]
    elseif #parts == 2 then
        h, m, s = inferred_hour or 0, parts[1], parts[2]
        repaired = true
    else
        return nil, false
    end
    if not h or not m or not s or m >= 60 or s >= 60 then return nil, false end
    ms = tostring(ms)
    if #ms > 3 then ms = ms:sub(1, 3) end
    while #ms < 3 do ms = ms .. "0" end
    return (h * 3600 + m * 60 + s) * 1000 + tonumber(ms), repaired
end

local function parse_srt_time_range(tc)
    local left, right = trim(tc or ""):match("^(.-)%s*%-%->%s*(.-)$")
    if not left or not right then return nil end
    local start_ms, repaired_start = parse_srt_clock(left, 0)
    if not start_ms then return nil end
    local inferred_hour = math.floor(start_ms / (60 * 60 * 1000))
    local end_ms, repaired_end = parse_srt_clock(right, inferred_hour)
    if not end_ms then return nil end
    if end_ms <= start_ms and repaired_end then
        local bumped = end_ms + 60 * 60 * 1000
        if bumped > start_ms then end_ms = bumped end
    end
    if end_ms <= start_ms then return nil end
    return start_ms, end_ms, (repaired_start or repaired_end)
end

local function parse_srt(filepath)
    local f, err = io.open(filepath, "r")
    if not f then return nil, tostring(err) end
    local content = f:read("*all")
    f:close()
    -- strip UTF-8 BOM
    if content:byte(1) == 0xEF and content:byte(2) == 0xBB and content:byte(3) == 0xBF then
        content = content:sub(4)
    end
    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")
    -- Subtitle separators may contain spaces/tabs after editing in a text editor.
    content = content:gsub("\n[ \t]+\n", "\n\n")
    content = content:gsub("\n\n+", "\n\n") .. "\n\n"

    local entries = {}
    for block in content:gmatch("(.-)\n\n") do
        block = trim(block)
        if block ~= "" then
            local lines = split_lines(block)
            if #lines >= 3 then
                local idx = tonumber(trim(lines[1]))
                if idx then
                    local tc = trim(lines[2])
                    local start_ms, end_ms, repaired_timecode = parse_srt_time_range(tc)
                    if start_ms then
                        local parts = {}
                        for i = 3, #lines do table.insert(parts, lines[i]) end
                        table.insert(entries, {
                            index    = idx,
                            start_ms = start_ms,
                            end_ms   = end_ms,
                            text     = trim(table.concat(parts, "\n")),
                        })
                        if repaired_timecode then
                            entries._timecode_repairs = (entries._timecode_repairs or 0) + 1
                        end
                    end
                end
            end
        end
    end
    entries._hour_adjustments = normalize_srt_hour_jumps(entries)
    return entries
end

local function sibling_english_srt_path(filepath)
    local dir, filename = filepath:match("^(.*[\\/])([^\\/]+)$")
    if not filename then dir, filename = "", filepath end
    local function replace_lang_segment(name, lang)
        local prefix, _, suffix = name:match("^(.-%s+%-%s+)(.-)(%s+%-%s+.+%.srt)$")
        if prefix then return prefix .. lang .. suffix end
        return name
    end
    local en_filename = replace_lang_segment(filename, "EN")
    if en_filename == filename then
        en_filename = filename:gsub("^(.-%s%-%s)[^%-]+(%s%-%sVID.+%.srt)$", "%1EN%2")
    end
    if en_filename == filename then
        en_filename = filename:gsub("^(.-%s%-%s)[^%-]+(%s%-%s.+%.srt)$", "%1EN%2")
    end

    local sep = filepath:find("\\") and "\\" or "/"
    local function exists(path)
        local f = io.open(path, "r")
        if f then f:close(); return true end
        return false
    end
    local function strip_sep(path)
        return (path or ""):gsub("[\\/]+$", "")
    end
    local function dirname(path)
        return strip_sep(path):match("^(.*)[\\/][^\\/]+$") or ""
    end
    local function recursive_find(root, target_name)
        root = strip_sep(root)
        if root == "" then return nil end
        local cmd
        if sep == "\\" then
            cmd = 'dir /b /s "' .. root .. sep .. target_name .. '" 2>nul'
        else
            cmd = 'find "' .. root .. '" -name "' .. target_name .. '" -type f 2>/dev/null'
        end
        local pipe = io.popen(cmd)
        if not pipe then return nil end
        local result = pipe:read("*l")
        pipe:close()
        if result and result ~= "" and exists(result) then return result end
        return nil
    end

    local candidates = {}
    local recursive_roots = {}
    table.insert(candidates, dir .. en_filename)

    local leaf_dir = strip_sep(dir)
    local sub_root, sub_name = leaf_dir:match("^(.*[\\/])([^\\/]+)$")
    if sub_root and sub_name then
        local lang_root = strip_sep(sub_root)
        local subtitles_root = lang_root:match("^(.*[\\/])[^\\/]+$")
        if subtitles_root then
            local english_root = subtitles_root .. sep .. "01_English_EN"
            table.insert(candidates, english_root .. sep .. sub_name .. sep .. en_filename)
            table.insert(candidates, english_root .. sep .. en_filename)
            table.insert(recursive_roots, english_root)
        end
    end

    local replaced_folder = filepath:gsub("[\\/]%d%d_[^\\/]*_[A-Z][A-Z%-]*[\\/]", sep .. "01_English_EN" .. sep, 1)
    if replaced_folder ~= filepath then
        local folder_dir = replaced_folder:match("^(.*[\\/])") or ""
        table.insert(candidates, folder_dir .. en_filename)
        local english_root = replaced_folder:match("^(.*[\\/]01_English_EN)[\\/]")
        if english_root then table.insert(recursive_roots, english_root) end
    end

    for _, candidate in ipairs(candidates) do
        if exists(candidate) then return candidate end
    end
    for _, root in ipairs(recursive_roots) do
        local found = recursive_find(root, en_filename)
        if found then return found end
    end
    return candidates[#candidates] or (dir .. en_filename)
end

local function attach_source_srt_text(target_path, target_entries)
    local source_path = sibling_english_srt_path(target_path)
    if not source_path then return nil, 0 end
    local f = io.open(source_path, "r")
    if not f then return source_path, 0 end
    f:close()

    local source_entries = parse_srt(source_path)
    if not source_entries then return source_path, 0 end
    local n = math.min(#target_entries, #source_entries)
    for i = 1, n do
        target_entries[i].source_text = source_entries[i].text
    end
    return source_path, n
end

-- ================================================================
--  LOGIC: Text wrapping
-- ================================================================
local WRAP_OVERFLOW_TOLERANCE = 0

local function visible_len(text)
    local s = tostring(text or "")
    local _, continuation_bytes = s:gsub("[\128-\191]", "")
    return #s - continuation_bytes
end

local function can_keep_line(line, max_chars)
    return visible_len(line) <= max_chars + WRAP_OVERFLOW_TOLERANCE
end

local function wrap_simple(text, max_chars)
    if max_chars <= 0 then return text end
    local source_lines = split_lines(text)
    local needs_reflow = false
    for _, line in ipairs(source_lines) do
        if not can_keep_line(line, max_chars) then
            needs_reflow = true
            break
        end
    end

    if not needs_reflow then
        return table.concat(source_lines, "\n")
    end

    local result = {}
    local words = split_words(table.concat(source_lines, " "))
    local cur = ""
    for _, word in ipairs(words) do
        if cur == "" then
            cur = word
        elseif visible_len(cur .. " " .. word) <= max_chars then
            cur = cur .. " " .. word
        else
            table.insert(result, cur)
            cur = word
        end
    end
    if cur ~= "" then table.insert(result, cur) end
    return table.concat(result, "\n")
end

local function wrap_balanced(text, max_chars)
    if max_chars <= 0 then return text end
    local result = {}
    for _, line in ipairs(split_lines(text)) do
        if can_keep_line(line, max_chars) then
            table.insert(result, line)
        else
            local words = split_words(line)
            if #words == 0 then
                table.insert(result, line)
            else
                local total_len = -1
                for _, w in ipairs(words) do total_len = total_len + visible_len(w) + 1 end
                local num_lines = math.max(1, math.ceil(total_len / max_chars))
                local target    = total_len / num_lines
                local out, cur, cli = {}, "", 0
                for _, word in ipairs(words) do
                    if cur == "" then
                        cur = word
                    else
                        local test = cur .. " " .. word
                        local rem  = num_lines - cli - 1
                        if visible_len(test) > max_chars and rem > 0 then
                            table.insert(out, cur); cur = word; cli = cli + 1
                        elseif rem > 0 and visible_len(cur) >= target * 0.8 then
                            if math.abs(visible_len(cur) - target) <= math.abs(visible_len(test) - target) and visible_len(test) > target then
                                table.insert(out, cur); cur = word; cli = cli + 1
                            else
                                cur = test
                            end
                        else
                            cur = test
                        end
                    end
                    if visible_len(cur) > max_chars and cur:find(" ", 1, true) then
                        local forced = wrap_simple(cur, max_chars)
                        local parts  = split_lines(forced)
                        for pi = 1, #parts - 1 do
                            table.insert(out, parts[pi]); cli = cli + 1
                        end
                        cur = parts[#parts]
                    end
                end
                if cur ~= "" then table.insert(out, cur) end
                for _, l in ipairs(out) do table.insert(result, l) end
            end
        end
    end
    return table.concat(result, "\n")
end

local function wrap_text(text, max_chars, mode)
    if max_chars <= 0 then return text end
    return wrap_simple(text, max_chars)
end

local function wrap_preserving_authored_breaks(text, max_chars, mode)
    local source_lines = split_lines(text)
    if #source_lines <= 1 then
        return wrap_text(text, max_chars, mode)
    end
    local result = {}
    for _, line in ipairs(source_lines) do
        local wrapped = wrap_text(line, max_chars, mode)
        for _, wrapped_line in ipairs(split_lines(wrapped)) do
            table.insert(result, wrapped_line)
        end
    end
    return table.concat(result, "\n")
end

local function format_srt_text_for_transfer(text, max_chars, mode, wrap_enabled, is_last_matched)
    local source_lines = split_lines(text or "")
    if is_last_matched or not wrap_enabled or max_chars <= 0 then
        return table.concat(source_lines, "\n"), false
    end

    local needs_reflow = false
    for _, line in ipairs(source_lines) do
        if not can_keep_line(line, max_chars) then
            needs_reflow = true
            break
        end
    end

    if not needs_reflow then
        return table.concat(source_lines, "\n"), false
    end

    local reflowed = wrap_text(table.concat(source_lines, " "), max_chars, mode)
    return reflowed, reflowed ~= table.concat(source_lines, "\n")
end

-- ================================================================
--  LOGIC: Clip scanning (SRT Replacer)
-- ================================================================
-- Safe helper: iterate a Resolve item-list table in index order
-- Resolve returns 1-based integer-keyed tables; pairs() order is unreliable.
local function iter_items(tbl)
    if not tbl then return {} end
    local out = {}
    for _, v in pairs(tbl) do table.insert(out, v) end
    return out
end

-- Get a Fusion comp by index with locking to prevent Fusion UI redraws.
-- When running inside Fusion (as a Lua script), GetFusionCompByIndex causes
-- Fusion to switch its active comp context, triggering expensive redraws.
-- Locking the comp suppresses this. Always unlock after reading.
local function safe_get_comp(item, ci)
    local ok, comp = pcall(function() return item:GetFusionCompByIndex(ci) end)
    if not (ok and comp) then return nil end
    pcall(function() comp:Lock() end)
    return comp
end

local function release_comp(comp)
    if comp then pcall(function() comp:Unlock() end) end
end

local function find_text_clips_on_track(timeline, track_idx)
    local raw = timeline:GetItemListInTrack("video", track_idx)
    if not raw then return {} end
    local clips = {}
    for _, item in ipairs(iter_items(raw)) do
        local ok_cc, cc = pcall(function() return item:GetFusionCompCount() end)
        if ok_cc and cc and cc > 0 then
            local tools_list, orig_list = {}, {}
            for ci = 1, cc do
                local comp = safe_get_comp(item, ci)  -- comp is Locked
                if comp then
                    local ok_tt, tt = pcall(function() return comp:GetToolList(false, "TextPlus") end)
                    if not (ok_tt and next_key(tt)) then
                        ok_tt, tt = pcall(function() return comp:GetToolList(false, "Text3D") end)
                    end
                    if ok_tt and next_key(tt) then
                        local skeys = {}
                        for k in pairs(tt) do table.insert(skeys, k) end
                        table.sort(skeys, function(a, b) return tostring(a) < tostring(b) end)
                        for _, k in ipairs(skeys) do
                            local tool = tt[k]
                            local ok, val = pcall(function() return tool:GetInput("StyledText") end)
                            table.insert(tools_list, tool)
                            table.insert(orig_list, (ok and val) and val or "")
                        end
                        release_comp(comp)
                    else
                        release_comp(comp)
                    end
                end
            end
            if #tools_list > 0 then
                table.insert(clips, {
                    item           = item,
                    tool           = tools_list[1],
                    tools          = tools_list,
                    start_f        = item:GetStart(),
                    finish         = item:GetEnd(),
                    name           = item:GetName(),
                    original_text  = orig_list[1],
                    original_texts = orig_list,
                })
            end
        end
    end
    return clips
end

local function discover_all_text_tracks(timeline)
    local count = timeline:GetTrackCount("video")
    local found = {}
    for idx = count, 1, -1 do
        local clips = find_text_clips_on_track(timeline, idx)
        if #clips > 0 then found[idx] = clips end
    end
    return found
end

local function clip_caption_score(clip)
    local text = clip.original_text or ""
    if text == "" and clip.original_texts then
        text = table.concat(clip.original_texts, " ")
    end
    text = trim(normalize_text_breaks(text))
    local lower = text:lower()
    if lower == "" or lower == "text" or lower == "text+" or lower == "title" then
        return 0
    end
    local score = math.min(visible_len(text), 120)
    if text:find("%s") then score = score + 30 end
    if text:find("[%.!,%?]") then score = score + 10 end
    return score
end

local function match_norm(text)
    local s = normalize_text_breaks(tostring(text or "")):lower()
    s = s:gsub("[%.%,%!%?%:%;%-%_]+", " ")
    s = s:gsub("%s+", " ")
    return trim(s)
end

local function text_match_score(clip, source_text)
    source_text = match_norm(source_text)
    if source_text == "" then return 0 end
    local clip_text = clip.original_text or ""
    if clip.original_texts then clip_text = clip_text .. " " .. table.concat(clip.original_texts, " ") end
    clip_text = match_norm(clip_text)
    if clip_text == "" then return 0 end
    if clip_text == source_text then return 10000 end
    if clip_text:find(source_text, 1, true) or source_text:find(clip_text, 1, true) then return 8000 end

    local wanted, total, hits = {}, 0, 0
    for w in source_text:gmatch("%S+") do
        if #w > 1 and not wanted[w] then wanted[w] = true; total = total + 1 end
    end
    for w in clip_text:gmatch("%S+") do
        if wanted[w] then hits = hits + 1; wanted[w] = nil end
    end
    if total == 0 then return 0 end
    return math.floor((hits / total) * 5000)
end

local function flatten_text_tracks(text_tracks)
    local out = {}
    for track_idx, clips in pairs(text_tracks) do
        for _, clip in ipairs(clips) do
            table.insert(out, { track_idx = track_idx, clip = clip })
        end
    end
    table.sort(out, function(a, b)
        if a.clip.start_f == b.clip.start_f then return a.track_idx > b.track_idx end
        return a.clip.start_f < b.clip.start_f
    end)
    return out
end

local function best_clip_by_source_text(text_tracks, source_text, used_clips)
    if match_norm(source_text) == "" then return nil, 0 end
    local best_clip, best_score = nil, 0
    for _, row in ipairs(flatten_text_tracks(text_tracks)) do
        local clip = row.clip
        if not (used_clips and used_clips[clip]) then
            local score = text_match_score(clip, source_text)
            if score > best_score then
                best_clip, best_score = clip, score
            end
        end
    end
    return best_clip, best_score
end

local function topmost_text_clip_at_frame(text_tracks, frame, used_clips, source_text)
    local best_clip, best_score = nil, nil
    local sorted = {}
    for k in pairs(text_tracks) do table.insert(sorted, k) end
    table.sort(sorted, function(a, b) return a > b end)
    for _, track_idx in ipairs(sorted) do
        for _, clip in ipairs(text_tracks[track_idx]) do
            if (not used_clips or not used_clips[clip]) and clip.start_f <= frame and frame < clip.finish then
                local score = text_match_score(clip, source_text) * 100000 + clip_caption_score(clip) * 1000 + track_idx
                if not best_score or score > best_score then
                    best_clip, best_score = clip, score
                end
            end
        end
    end
    return best_clip
end

local function best_text_clip_for_range(text_tracks, start_frame, end_frame, fps_val, used_clips, source_text)
    local best_clip, best_score = nil, nil
    local mid = (start_frame + end_frame) / 2
    for track_idx, clips in pairs(text_tracks) do
        for _, clip in ipairs(clips) do
            if not (used_clips and used_clips[clip]) then
                local overlap = math.min(end_frame, clip.finish) - math.max(start_frame, clip.start_f)
                if overlap > 0 then
                    local clip_mid = (clip.start_f + clip.finish) / 2
                    local score = text_match_score(clip, source_text) * 100000 + overlap * 1000 + clip_caption_score(clip) * 100 + track_idx - math.abs(clip_mid - mid)
                    if not best_score or score > best_score then
                        best_clip, best_score = clip, score
                    end
                end
            end
        end
    end
    if best_clip then return best_clip, "overlap" end

    local tolerance = math.max(12, math.floor((fps_val or 24) * 1.5 + 0.5))
    local best_dist = nil
    for track_idx, clips in pairs(text_tracks) do
        for _, clip in ipairs(clips) do
            if not (used_clips and used_clips[clip]) then
                local dist = 0
                if clip.finish <= start_frame then
                    dist = start_frame - clip.finish
                elseif clip.start_f >= end_frame then
                    dist = clip.start_f - end_frame
                end
                if dist <= tolerance then
                    local score_dist = dist * 1000 - track_idx
                    if not best_dist or score_dist < best_dist then
                        best_clip, best_dist = clip, score_dist
                    end
                end
            end
        end
    end
    return best_clip, best_clip and "nearby" or nil
end

local function build_mapping(srt_entries, text_tracks, frame_offset, fps_val, skip_frames)
    local mapping = {}
    local used_clips = {}
    for i, entry in ipairs(srt_entries) do
        local srt_frame  = ms_to_frames(entry.start_ms, fps_val)
        local end_frame  = ms_to_frames(entry.end_ms, fps_val)
        local safe_frame = frame_offset + srt_frame + skip_frames
        local method = "probe+skip"
        local clip, source_score = best_clip_by_source_text(text_tracks, entry.source_text, used_clips)
        if clip and source_score >= 4000 then
            method = "source-text"
        else
            clip = topmost_text_clip_at_frame(text_tracks, safe_frame, used_clips, entry.source_text)
        end
        if not clip and skip_frames > 0 then
            method = "probe"
            clip = topmost_text_clip_at_frame(text_tracks, frame_offset + srt_frame, used_clips, entry.source_text)
        end
        if not clip then
            clip, method = best_text_clip_for_range(
                text_tracks,
                frame_offset + srt_frame,
                frame_offset + end_frame,
                fps_val,
                used_clips,
                entry.source_text
            )
        end
        if clip then used_clips[clip] = true end
        table.insert(mapping, { sub_index = i, srt_text = entry.text, clip = clip, method = method })
    end
    return mapping
end

local function auto_detect_offset(srt_entries, text_tracks, tl_start, fps_val, skip_frames)
    local candidates = {
        { offset = tl_start, skip = skip_frames, label = "relative+skip" },
        { offset = 0,        skip = skip_frames, label = "absolute+skip" },
        { offset = tl_start, skip = 0,           label = "relative"      },
        { offset = 0,        skip = 0,           label = "absolute"      },
    }
    local best_map, best_hits, best_label = nil, -1, "none"
    for _, c in ipairs(candidates) do
        local m = build_mapping(srt_entries, text_tracks, c.offset, fps_val, c.skip)
        local hits = 0
        for _, e in ipairs(m) do if e.clip then hits = hits + 1 end end
        if hits > best_hits then
            best_hits  = hits
            best_map   = m
            best_label = c.label
        end
    end
    print("  Offset mode: " .. best_label .. " (" .. best_hits .. " hits)")
    return 0, best_map, best_label
end

-- ================================================================
--  LOGIC: Font scanning
-- ================================================================
local STYLE_STRIP = {
    "Bold Italic", "Bold", "Italic", "Light Italic", "Light",
    "Medium Italic", "Medium", "SemiBold Italic", "SemiBold",
    "ExtraBold Italic", "ExtraBold", "Thin Italic", "Thin",
    "Black Italic", "Black", "ExtraLight Italic", "ExtraLight",
    "Condensed Bold", "Condensed", "Regular", "Oblique",
    "Heavy", "Ultra", "Demi", "Semi", "Book",
}

local function clean_font_name(raw)
    local name = raw:gsub("[-_]", " ")
    
    -- Insert spaces for CamelCase/PascalCase (e.g., NotoSansJP -> Noto Sans JP)
    name = name:gsub("(%l)(%u)", "%1 %2")
    name = name:gsub("(%u)(%u%l)", "%1 %2")
    
    -- Capitalize first letter of words (e.g., arial -> Arial)
    name = name:gsub("(%a)(%w*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)

    -- strip style suffixes (case-insensitive approximation)
    for _, suf in ipairs(STYLE_STRIP) do
        local pat = "%s+" .. suf:gsub("(%a+)", function(w)
            return "[" .. w:sub(1,1):upper() .. w:sub(1,1):lower() .. "]" .. w:sub(2)
        end) .. ".*$"
        name = name:gsub(pat, "")
    end
    name = name:gsub("%s+%d+$", "") -- strip trailing numbers like "Helvetica 55"
    return trim(name)
end

local function get_system_fonts()
    local families, seen = {}, {}

    local function add_font(name)
        name = trim(name)
        if name ~= "" and not name:match("^@") and not seen[name] then
            seen[name] = true; table.insert(families, name)
        end
    end

    local native_success = false

    -- 1. Try Native OS APIs first (gives exact names like 'Noto Sans JP' or 'Arial')
    if IS_WINDOWS then
        local cmd = 'powershell -NoProfile -Command "Add-Type -AssemblyName PresentationCore; foreach($f in [Windows.Media.Fonts]::SystemFontFamilies) { $f.Source }" 2>nul'
        local h = io.popen(cmd)
        if h then
            for line in h:lines() do add_font(line); native_success = true end
            h:close()
        end
    else
        local h_uname = io.popen("uname -s 2>/dev/null")
        local os_name = h_uname and trim(h_uname:read("*l") or "")
        if h_uname then h_uname:close() end

        if os_name == "Darwin" then
            -- Use macOS JXA to get exact font families from AppKit
            local cmd = 'osascript -l JavaScript -e "ObjC.import(\'AppKit\'); ObjC.deepUnwrap($.NSFontManager.sharedFontManager.availableFontFamilies).join(\'\\n\')" 2>/dev/null'
            local h = io.popen(cmd)
            if h then
                for line in h:lines() do add_font(line); native_success = true end
                h:close()
            end
        else
            -- Linux fallback
            local h = io.popen("fc-list --format '%{family}\\n' 2>/dev/null")
            if h then
                for line in h:lines() do
                    for fam in line:gmatch("[^,]+") do add_font(fam); native_success = true end
                end
                h:close()
            end
        end
    end

    -- 2. Fallback to scanning font folders if native API fails
    if not native_success or #families < 10 then
        if IS_WINDOWS then
            local h = io.popen('dir /b "C:\\Windows\\Fonts\\*.ttf" "C:\\Windows\\Fonts\\*.otf" 2>nul')
            if h then
                for line in h:lines() do
                    local name = line:match("^(.-)%.[tToO][tTtT][fF]$") or line:match("^(.-)%.[oO][tT][fF]$")
                    if name then add_font(clean_font_name(name)) end
                end
                h:close()
            end
            local appdata = os.getenv("LOCALAPPDATA") or ""
            if appdata ~= "" then
                local h2 = io.popen('dir /b "' .. appdata .. '\\Microsoft\\Windows\\Fonts\\*.ttf" "' ..
                                     appdata .. '\\Microsoft\\Windows\\Fonts\\*.otf" 2>nul')
                if h2 then
                    for line in h2:lines() do
                        local name = line:match("^(.-)%.[tToO][tTtT][fF]$") or line:match("^(.-)%.[oO][tT][fF]$")
                        if name then add_font(clean_font_name(name)) end
                    end
                    h2:close()
                end
            end
        else
            local home = os.getenv("HOME") or ""
            local dirs = { "/System/Library/Fonts", "/Library/Fonts", home .. "/Library/Fonts",
                           "/usr/share/fonts", "/usr/local/share/fonts", home .. "/.fonts", home .. "/.local/share/fonts" }
            for _, dir in ipairs(dirs) do
                local h = io.popen('find "' .. dir .. '" \\( -name "*.ttf" -o -name "*.otf" -o -name "*.ttc" \\) 2>/dev/null')
                if h then
                    for line in h:lines() do
                        local filename = line:match("[^/]+$") or ""
                        local base = filename:gsub("%.[^%.]+$", "")
                        if base ~= "" then add_font(clean_font_name(base)) end
                    end
                    h:close()
                end
            end
        end
    end

    if #families == 0 then
        families = { "Arial", "Helvetica", "Times New Roman", "Courier New",
                     "Verdana", "Georgia", "Open Sans", "Roboto" }
    end
    table.sort(families, function(a, b) return a:lower() < b:lower() end)
    return families
end

-- ================================================================
--  LOGIC: Template Duplicator helpers
-- ================================================================
local TRANSFORM_PROPS = { "ZoomX", "ZoomY", "Pan", "Tilt" }

local function read_transform(item)
    local props = {}
    for _, name in ipairs(TRANSFORM_PROPS) do
        local ok, val = pcall(function() return item:GetProperty(name) end)
        if ok and val ~= nil then props[name] = val end
    end
    return props
end

local function apply_transform(item, props)
    for name, val in pairs(props) do
        pcall(function() item:SetProperty(name, val) end)
    end
end

local function get_all_media_pool_items(media_pool)
    local items = {}
    local function scan_folder(folder)
        local ok1, clips = pcall(function() return folder:GetClipList() end)
        if ok1 and clips then
            for _, clip in pairs(clips) do
                local ok2, ct = pcall(function()
                    return (clip:GetClipProperty("Type") or ""):lower()
                end)
                if ok2 and (ct:find("fusion") or ct:find("generator")) then
                    table.insert(items, clip)
                end
            end
        end
        local ok3, subs = pcall(function() return folder:GetSubFolderList() end)
        if ok3 and subs then
            for _, sf in pairs(subs) do scan_folder(sf) end
        end
    end
    pcall(function() scan_folder(media_pool:GetRootFolder()) end)
    return items
end

local function scan_text_clips_for_duplicator(timeline, max_track)
    local track_count = timeline:GetTrackCount("video")
    if max_track and max_track < track_count then track_count = max_track end
    local clips = {}
    for track_idx = 1, track_count do
        local raw = timeline:GetItemListInTrack("video", track_idx)
        if raw then
            local track_clips = {}
            for _, item in ipairs(iter_items(raw)) do
                local ok_cc, cc = pcall(function() return item:GetFusionCompCount() end)
                if ok_cc and cc and cc > 0 then
                    local texts, has_text = {}, false
                    for ci = 1, cc do
                        local comp = safe_get_comp(item, ci)  -- comp is Locked
                        if comp then
                            local ok_tt, tt = pcall(function() return comp:GetToolList(false, "TextPlus") end)
                            if not (ok_tt and next_key(tt)) then
                                ok_tt, tt = pcall(function() return comp:GetToolList(false, "Text3D") end)
                            end
                            if ok_tt and next_key(tt) then
                                has_text = true
                                local skeys = {}
                                for k in pairs(tt) do table.insert(skeys, k) end
                                table.sort(skeys, function(a, b) return tostring(a) < tostring(b) end)
                                for _, k in ipairs(skeys) do
                                    local ok, val = pcall(function() return tt[k]:GetInput("StyledText") end)
                                    table.insert(texts, (ok and val) and val or "")
                                end
                                release_comp(comp)
                                break
                            else
                                release_comp(comp)
                            end
                        end
                    end
                    if has_text then
                        table.insert(track_clips, {
                            item      = item,
                            start_f   = item:GetStart(),
                            finish    = item:GetEnd(),
                            duration  = item:GetEnd() - item:GetStart(),
                            track     = track_idx,
                            name      = item:GetName(),
                            texts     = texts,
                            transform = read_transform(item),
                            transition_in  = 0,
                            transition_out = 0,
                        })
                    end
                end
            end
            -- detect overlapping transitions
            for i = 2, #track_clips do
                local prev = track_clips[i - 1]
                local cur  = track_clips[i]
                local overlap = prev.finish - cur.start_f
                if overlap > 0 then
                    cur.transition_in  = overlap
                    prev.transition_out = overlap
                end
            end
            for _, c in ipairs(track_clips) do table.insert(clips, c) end
        end
    end
    return clips
end

local function find_clip_near_frame(timeline, track_idx, target_frame, tolerance)
    tolerance = tolerance or 5
    local raw = timeline:GetItemListInTrack("video", track_idx)
    if not raw then return nil end
    local best, best_dist = nil, math.huge
    for _, item in pairs(raw) do
        local ok, s = pcall(function() return item:GetStart() end)
        if ok then
            local dist = math.abs(s - target_frame)
            if dist < best_dist then best_dist = dist; best = item end
        end
    end
    return (best and best_dist <= tolerance) and best or nil
end

local function frames_to_timecode(frame, fps_val)
    local fi  = math.floor(fps_val + 0.5)
    frame     = math.floor(frame)
    local ff  = frame % fi
    local ss  = math.floor(frame / fi) % 60
    local mm  = math.floor(frame / fi / 60) % 60
    local hh  = math.floor(frame / fi / 3600)
    return string.format("%02d:%02d:%02d:%02d", hh, mm, ss, ff)
end

local KNOWN_FPS = {23.976, 24, 25, 29.97, 30, 48, 50, 59.94, 60, 120}

local function snap_fps_value(fps_val)
    fps_val = tonumber(fps_val) or 0
    for _, candidate in ipairs(KNOWN_FPS) do
        if math.abs(fps_val - candidate) < 0.02 then return candidate end
    end
    return fps_val
end

local function media_pool_item_fps(item, fallback_fps)
    local out = tonumber(fallback_fps) or 24
    local detected = false
    pcall(function()
        local f = tonumber(item:GetClipProperty("FPS"))
        if f and f > 0 then out = f; detected = true end
    end)
    return snap_fps_value(out), detected
end

local function timeline_frames_to_source_frames(duration, timeline_fps, source_fps)
    duration = math.max(1, math.floor(duration))
    local tl_fps  = snap_fps_value(timeline_fps)
    local src_fps = snap_fps_value(source_fps)
    if math.abs(src_fps - tl_fps) < 0.0001 then
        return duration
    end
    return math.max(1, math.ceil(duration * src_fps / tl_fps))
end

local function caption_timing_offset(entries, timeline_start, fps_val, mode_index)
    local first_ms = (#entries > 0 and entries[1].start_ms) or 0
    local first_frame = ms_to_frames(first_ms, fps_val)
    local hour_frames = ms_to_frames(3600000, fps_val)
    local modes = {
        { label = "Auto", offset = nil },
        { label = "SRT starts at timeline start", offset = timeline_start },
        { label = "SRT uses timeline timecode", offset = 0 },
        { label = "Subtract 01:00:00:00 from SRT", offset = timeline_start - hour_frames },
        { label = "Add 01:00:00:00 to SRT", offset = timeline_start + hour_frames },
    }
    mode_index = mode_index or 0
    local selected = modes[mode_index + 1] or modes[1]
    if selected.offset then return selected.offset, selected.label end

    local candidates = { modes[2], modes[3], modes[4], modes[5] }
    local best, best_score = candidates[1], math.huge
    for _, c in ipairs(candidates) do
        local record = c.offset + first_frame
        local score = math.abs(record - timeline_start)
        if record < timeline_start - 2 then score = score + 10000000 end
        if score < best_score then best, best_score = c, score end
    end
    return best.offset, "Auto: " .. best.label
end

local function build_caption_plan(entries, timeline_start, fps_val, mode_index)
    local offset, label = caption_timing_offset(entries, timeline_start, fps_val, mode_index)
    local plan = {}
    for i, e in ipairs(entries) do
        local s = offset + ms_to_frames(e.start_ms, fps_val)
        local f = offset + ms_to_frames(e.end_ms, fps_val)
        if f <= s then f = s + 1 end
        table.insert(plan, {
            index    = i,
            start_f  = s,
            finish   = f,
            duration = f - s,
            text     = e.text,
        })
    end
    local one_frame_ms = 1000.0 / math.max(fps_val, 1)
    for i = 2, #plan do
        local prev = plan[i - 1]
        local cur  = plan[i]
        local source_gap_ms = entries[i].start_ms - entries[i - 1].end_ms
        if source_gap_ms <= one_frame_ms + 1.0 then
            prev.finish = cur.start_f
            prev.duration = math.max(1, prev.finish - prev.start_f)
        end
        if prev.finish > cur.start_f then
            prev.finish = cur.start_f
            prev.duration = math.max(1, prev.finish - prev.start_f)
        end
    end
    return plan, label
end

local function fusion_text_value(text)
    local s = tostring(text or "")
    s = s:gsub("\\N", "\n")
    s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
    s = s:gsub("\n+", "\n")
    return s:gsub("\n", "\r\n")
end

local function set_tool_text(tool, text)
    local val = fusion_text_value(text)
    local ok, result = pcall(function() return tool:SetInput("StyledText", val) end)
    if not ok or result == false then return false end
    local read_ok, actual = pcall(function() return tool:GetInput("StyledText") end)
    return read_ok and normalize_text_breaks(actual) == normalize_text_breaks(val)
end

local function set_text_on_timeline_item(item, text, split_across_tools)
    local ok_cc, cc = pcall(function() return item:GetFusionCompCount() end)
    if not (ok_cc and cc and cc > 0) then return false end
    local tools = {}
    for ci = 1, cc do
        local comp = item:GetFusionCompByIndex(ci)
        if comp then
            local tt = comp:GetToolList(false, "TextPlus")
            if not next_key(tt) then tt = comp:GetToolList(false, "Text3D") end
            if next_key(tt) then
                local skeys = {}
                for k in pairs(tt) do table.insert(skeys, k) end
                table.sort(skeys, function(a, b) return tostring(a) < tostring(b) end)
                for _, k in ipairs(skeys) do table.insert(tools, tt[k]) end
                break
            end
        end
    end
    if #tools == 0 then return false end

    if split_across_tools and #tools > 1 then
        local lines = split_lines(text)
        for i, tool in ipairs(tools) do
            local val = ""
            if i <= #lines then
                if i == #tools and #lines > #tools then
                    local tail = {}
                    for li = i, #lines do table.insert(tail, lines[li]) end
                    val = table.concat(tail, "\n")
                else
                    val = lines[i]
                end
            end
            if not set_tool_text(tool, val) then return false end
        end
    else
        return set_tool_text(tools[1], text)
    end
    return true
end

local function subtitle_text_from_item(item)
    local candidates = {}
    local function add(v, depth)
        depth = depth or 0
        if v == nil then return end
        -- Resolve returns false/true or numbers for properties a subtitle item does not have.
        if type(v) == "boolean" or type(v) == "number" or type(v) == "userdata" or type(v) == "function" then return end
        if type(v) == "table" and depth < 4 then
            for _, value in pairs(v) do add(value, depth + 1) end
            return
        end
        local s = trim(normalize_text_breaks(tostring(v)))
        if s ~= "" then table.insert(candidates, s) end
    end

    local prop_names = {
        "Text", "Subtitle", "Caption", "StyledText", "Name", "Clip Name",
        "Comments", "Description", "Text+", "TextPlus", "Caption Text",
        "Subtitle Text", "Content", "Current Caption", "Rich Text",
        "Plain Text", "Custom Name",
    }
    for _, prop in ipairs(prop_names) do
        pcall(function() add(item:GetProperty(prop)) end)
    end

    pcall(function()
        local props = item:GetProperty()
        if type(props) == "table" then
            for _, prop in ipairs(prop_names) do add(props[prop]) end
            for k, v in pairs(props) do
                local kk = tostring(k):lower()
                if kk:find("text", 1, true) or kk:find("caption", 1, true) or
                   kk:find("subtitle", 1, true) then
                    add(v)
                end
            end
        end
    end)

    pcall(function()
        local mpi = item:GetMediaPoolItem()
        if mpi then
            add(mpi:GetName())
            local props = mpi:GetClipProperty()
            if type(props) == "table" then
                for _, prop in ipairs(prop_names) do add(props[prop]) end
            end
        end
    end)

    -- Resolve can expose subtitle clip names as flattened one-line text.
    -- Prefer real text/caption properties first, then use the clip name fallback.
    pcall(function() add(item:GetName()) end)

    for _, s in ipairs(candidates) do
        local lower = s:lower()
        local generic = lower == "subtitle" or lower == "subtitle clip" or
                        lower:match("^subtitle%s*%d*$") ~= nil
        if (not generic) and s:find("\n", 1, true) then return s end
    end

    for _, s in ipairs(candidates) do
        local lower = s:lower()
        local generic = lower == "subtitle" or lower == "subtitle clip" or
                        lower:match("^subtitle%s*%d*$") ~= nil
        if not generic then return s end
    end
    return ""
end

local function scan_timeline_subtitle_items(timeline)
    local out = {}
    local info = { track_count = 0, item_count = 0, unreadable_count = 0, disabled_tracks = 0 }
    pcall(function() info.track_count = timeline:GetTrackCount("subtitle") or 0 end)
    for track_idx = 1, info.track_count do
        local enabled = true
        pcall(function() enabled = timeline:GetIsTrackEnabled("subtitle", track_idx) end)
        if not enabled then info.disabled_tracks = info.disabled_tracks + 1 end

        local raw = nil
        pcall(function() raw = timeline:GetItemListInTrack("subtitle", track_idx) end)
        if not raw then pcall(function() raw = timeline:GetItemsInTrack("subtitle", track_idx) end) end
        if raw then
            for _, item in ipairs(iter_items(raw)) do
                info.item_count = info.item_count + 1
                local text = subtitle_text_from_item(item)
                if text ~= "" then
                    text = wrap_text(text, 27, "balanced")
                    local s, f = item:GetStart(), item:GetEnd()
                    table.insert(out, {
                        index    = #out + 1,
                        start_f  = s,
                        finish   = f,
                        duration = math.max(1, f - s),
                        text     = text,
                    })
                else
                    info.unreadable_count = info.unreadable_count + 1
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.start_f < b.start_f end)
    return out, info
end

-- ================================================================
--  LOGIC: Subtitle Creator
-- ================================================================
local function normalise_styled_text(txt)
    txt = (txt or ""):gsub("\r\n", "\n"):gsub("|", "\n")
    return trim(txt)
end

local function scan_text_clips_for_subtitles(timeline, max_track)
    local track_count = timeline:GetTrackCount("video")
    if max_track and max_track < track_count then track_count = max_track end
    local clips = {}
    for track_idx = 1, track_count do
        local raw = timeline:GetItemListInTrack("video", track_idx)
        if raw then
            for _, item in ipairs(iter_items(raw)) do
                local ok_cc, cc = pcall(function() return item:GetFusionCompCount() end)
                if ok_cc and cc and cc > 0 then
                    local texts, has_text = {}, false
                    for ci = 1, cc do
                        local comp = safe_get_comp(item, ci)
                        if comp then
                            local ok_tt, tt = pcall(function() return comp:GetToolList(false, "TextPlus") end)
                            if not (ok_tt and next_key(tt)) then
                                ok_tt, tt = pcall(function() return comp:GetToolList(false, "Text3D") end)
                            end
                            if ok_tt and next_key(tt) then
                                has_text = true
                                local skeys = {}
                                for k in pairs(tt) do table.insert(skeys, k) end
                                table.sort(skeys, function(a, b) return tostring(a) < tostring(b) end)
                                for _, k in ipairs(skeys) do
                                    local ok, val = pcall(function() return tt[k]:GetInput("StyledText") end)
                                    local txt = normalise_styled_text((ok and val) and val or "")
                                    if txt ~= "" then table.insert(texts, txt) end
                                end
                                release_comp(comp)
                                break
                            else
                                release_comp(comp)
                            end
                        end
                    end
                    if has_text and #texts > 0 then
                        local combined = #texts > 1 and table.concat(texts, "\n") or texts[1]
                        table.insert(clips, {
                            start_f  = item:GetStart(),
                            finish   = item:GetEnd(),
                            duration = item:GetEnd() - item:GetStart(),
                            track    = track_idx,
                            name     = item:GetName(),
                            text     = combined,
                        })
                    end
                end
            end
        end
    end
    table.sort(clips, function(a, b)
        return a.start_f < b.start_f or (a.start_f == b.start_f and a.track < b.track)
    end)
    return clips
end

local function resolve_overlaps(clips)
    if #clips == 0 then return {} end
    local seen, unique = {}, {}
    for _, clip in ipairs(clips) do
        local key = clip.start_f .. "|" .. clip.text
        if not seen[key] then seen[key] = true; table.insert(unique, clip) end
    end
    table.sort(unique, function(a, b)
        return a.start_f < b.start_f or (a.start_f == b.start_f and a.track < b.track)
    end)
    local subs = {}
    for i, clip in ipairs(unique) do
        local sub = {
            start_f  = clip.start_f,
            finish   = clip.finish,
            orig_end = clip.finish,
            text     = clip.text,
            trimmed  = false,
            sources  = { "V" .. clip.track },
        }
        if i < #unique then
            local next_start = unique[i + 1].start_f
            if sub.finish > next_start then
                sub.finish  = next_start
                sub.trimmed = true
            end
        end
        if sub.finish > sub.start_f then
            table.insert(subs, sub)
        end
    end
    return subs
end

local function frames_to_srt_time(frame, fps_val)
    local total = frame / fps_val
    local hh = math.floor(total / 3600)
    local mm = math.floor((total % 3600) / 60)
    local ss = math.floor(total % 60)
    local ms = math.floor((total % 1) * 1000)
    return string.format("%02d:%02d:%02d,%03d", hh, mm, ss, ms)
end

local function try_srt_import(timeline, subs, fps_val, status_cb)
    local lines = {}
    for i, sub in ipairs(subs) do
        table.insert(lines, tostring(i))
        table.insert(lines, frames_to_srt_time(sub.start_f, fps_val) .. " --> " ..
                            frames_to_srt_time(sub.finish,  fps_val))
        table.insert(lines, trim(sub.text:gsub("\r\n", "\n")))
        table.insert(lines, "")
    end
    local srt_content = table.concat(lines, "\n")

    local tmp_path = make_temp_path(".srt")
    local f = io.open(tmp_path, "w")
    if not f then return 0, #subs end
    f:write(srt_content); f:close()
    print("  SRT file written: " .. tmp_path .. "  (" .. #subs .. " entries)")

    local created, failed = 0, #subs
    local ok, result = pcall(function() return timeline:ImportSubtitle(tmp_path) end)
    if ok and result then
        created = #subs; failed = 0
        print("  SRT import successful!")
    else
        print("  ImportSubtitle not available or returned false  -  saving SRT to Documents")
        local home = (IS_WINDOWS and os.getenv("USERPROFILE") or os.getenv("HOME")) or os.getenv("USERPROFILE") or ""
        local docs  = IS_WINDOWS and (home .. "\\Documents") or (home .. "/Documents")
        local sep   = IS_WINDOWS and "\\" or "/"
        local tl_name = (timeline:GetName() or "timeline"):gsub("[^%w%s%-_]", "_")
        local save_path = docs .. sep .. tl_name .. "_subtitles.srt"
        local f2 = io.open(save_path, "w")
        if f2 then
            f2:write(srt_content); f2:close()
            local msg = "SRT saved: " .. save_path .. "   -   import via  File > Import > Subtitle"
            print("  " .. msg)
            if status_cb then status_cb(msg) end
            created = #subs; failed = 0
        end
    end

    pcall(function() os.remove(tmp_path) end)
    return created, failed
end

-- ================================================================
--  UI THEME  (orange palette  -  mirrors the Automator's design)
-- ================================================================

local function frames_to_srt_time_precise(frame, fps_val)
    frame = math.max(0, frame)
    local total = frame / fps_val
    local hh = math.floor(total / 3600)
    local mm = math.floor((total % 3600) / 60)
    local ss = math.floor(total % 60)
    local ms = math.floor((total % 1) * 1000 + 0.5)
    if ms >= 1000 then
        ms = ms - 1000
        ss = ss + 1
        if ss >= 60 then ss = 0; mm = mm + 1 end
        if mm >= 60 then mm = 0; hh = hh + 1 end
    end
    return string.format("%02d:%02d:%02d,%03d", hh, mm, ss, ms)
end

local function build_export_srt_content(subs, fps_val, timeline_start)
    local lines = {}
    for i, sub in ipairs(subs) do
        local start_f = math.max(0, sub.start_f - (timeline_start or 0))
        local end_f   = math.max(start_f + 1, sub.finish - (timeline_start or 0))
        table.insert(lines, tostring(i))
        table.insert(lines, frames_to_srt_time_precise(start_f, fps_val) .. " --> " ..
                            frames_to_srt_time_precise(end_f,   fps_val))
        table.insert(lines, trim(sub.text:gsub("\r\n", "\n")))
        table.insert(lines, "")
    end
    return table.concat(lines, "\n")
end

local function write_subtitles_srt_file(timeline, subs, fps_val, folder)
    local dir = folder ~= "" and folder or default_documents_dir()
    local tl_name = safe_filename(timeline:GetName() or "timeline")
    local stamp = os.date("%Y%m%d_%H%M%S")
    local path = path_join(dir, tl_name .. "_subtitles_" .. stamp .. ".srt")
    local content = build_export_srt_content(subs, fps_val, timeline:GetStartFrame() or 0)
    local f, err = io.open(path, "w")
    if not f then return nil, tostring(err or "write failed") end
    f:write(content)
    f:close()
    print("  SRT file written: " .. path .. "  (" .. #subs .. " entries)")
    return path, nil
end

local function file_exists(path)
    local f = io.open(path or "", "r")
    if f then f:close(); return true end
    return false
end

local function latest_generated_srt_for_timeline(timeline, folder)
    local dir = folder ~= "" and folder or default_documents_dir()
    local tl_name = safe_filename(timeline:GetName() or "timeline")
    local pattern = tl_name .. "_subtitles_*.srt"
    local cmd
    if package.config:sub(1, 1) == "\\" then
        cmd = 'cmd /c dir /b /a-d /o-d "' .. dir .. '\\' .. pattern .. '" 2>nul'
    else
        -- Keep the * outside the quotes so the shell expands it.
        cmd = 'ls -t "' .. dir .. '/' .. tl_name .. '_subtitles_"*.srt 2>/dev/null'
    end
    local p = io.popen(cmd, "r")
    if not p then return nil end
    local first = p:read("*line")
    p:close()
    if not first or first == "" then return nil end
    if first:find("[/\\]") then return first end
    return path_join(dir, first)
end

local function subtitle_item_count(timeline, track_idx)
    local raw = nil
    pcall(function() raw = timeline:GetItemListInTrack("subtitle", track_idx) end)
    if not raw then return 0 end
    local n = 0
    for _, _ in pairs(raw) do n = n + 1 end
    return n
end

local function import_srt_to_subtitle_track(timeline, media_pool, srt_path, expected_count, status_cb)
    local function status(msg, level)
        print("  " .. msg)
        if status_cb then status_cb(msg, level or "info") end
    end

    local root = media_pool:GetRootFolder()
    local track_count = timeline:GetTrackCount("subtitle") or 0
    local enabled_states = {}
    for i = 1, track_count do
        pcall(function() enabled_states[i] = timeline:GetIsTrackEnabled("subtitle", i) end)
        pcall(function() timeline:SetTrackEnable("subtitle", i, false) end)
    end

    local target_track = nil
    for i = 1, track_count do
        if subtitle_item_count(timeline, i) == 0 then target_track = i; break end
    end
    if not target_track then
        pcall(function() timeline:AddTrack("subtitle") end)
        sleep(0.25)
        target_track = timeline:GetTrackCount("subtitle")
    end
    if target_track then pcall(function() timeline:SetTrackEnable("subtitle", target_track, true) end) end

    local srt_folder = nil
    pcall(function()
        for _, folder in pairs(root:GetSubFolderList() or {}) do
            if folder:GetName() == "srt" then srt_folder = folder; break end
        end
    end)
    if not srt_folder then pcall(function() srt_folder = media_pool:AddSubFolder(root, "srt") end) end
    if srt_folder then pcall(function() media_pool:SetCurrentFolder(srt_folder) end) end

    if not srt_folder then
        status("Could not create/find Media Pool folder named 'srt'.", "warn")
    else
        status("Media Pool folder: srt", "dim")
    end

    local mpi = nil
    local ok_import, imported = pcall(function() return media_pool:ImportMedia({ srt_path }) end)
    status("ImportMedia returned: ok=" .. tostring(ok_import) .. ", type=" .. type(imported), ok_import and "dim" or "warn")
    if ok_import and imported then
        if type(imported) == "table" then
            for _, item in pairs(imported) do
                if type(item) == "userdata" or type(item) == "table" then mpi = item end
            end
        else
            if type(imported) == "userdata" or type(imported) == "table" then mpi = imported end
        end
    end
    if not mpi and srt_folder then
        local fname = srt_path:match("[^/\\]+$") or srt_path
        pcall(function()
            for _, clip in pairs(srt_folder:GetClipList() or {}) do
                local nm = clip:GetName() or ""
                local file = clip:GetClipProperty("File Name") or ""
                if nm == fname or file == fname or file == srt_path then mpi = clip; break end
            end
        end)
    end

    if not mpi then
        status("SRT was not found as a Media Pool item after import.", "warn")
    else
        local nm = "?"
        pcall(function() nm = mpi:GetName() or "?" end)
        status("SRT Media Pool item: " .. nm, "dim")
    end

    local before = target_track and subtitle_item_count(timeline, target_track) or 0
    local total_before = 0
    pcall(function()
        for i = 1, timeline:GetTrackCount("subtitle") do
            total_before = total_before + subtitle_item_count(timeline, i)
        end
    end)
    local appended, append_method = false, "none"
    if mpi then
        pcall(function() timeline:SetCurrentTimecode(timeline:GetStartTimecode()) end)
        local ok_append, result = pcall(function() return media_pool:AppendToTimeline({ mpi }) end)
        status("Append SRT item returned: ok=" .. tostring(ok_append) .. ", type=" .. type(result), ok_append and "dim" or "warn")
        appended = ok_append and result ~= false
        append_method = "media_pool_item_list"
        if not appended then
            ok_append, result = pcall(function()
                return media_pool:AppendToTimeline({
                    { mediaPoolItem = mpi, trackIndex = target_track, startFrame = 0, endFrame = 1 }
                })
            end)
            status("Append clipInfo returned: ok=" .. tostring(ok_append) .. ", type=" .. type(result), ok_append and "dim" or "warn")
            appended = ok_append and result ~= false
            append_method = "clip_info"
        end
    end

    sleep(0.5)
    local after = target_track and subtitle_item_count(timeline, target_track) or 0
    local placed = math.max(0, after - before)
    local total_after = 0
    pcall(function()
        for i = 1, timeline:GetTrackCount("subtitle") do
            total_after = total_after + subtitle_item_count(timeline, i)
        end
    end)
    local placed_total = math.max(0, total_after - total_before)

    for i = 1, track_count do
        if i ~= target_track and enabled_states[i] ~= nil then
            pcall(function() timeline:SetTrackEnable("subtitle", i, enabled_states[i]) end)
        end
    end

    status(("Subtitle items after append: target +%d, all tracks +%d"):format(placed, placed_total), placed_total > 0 and "ok" or "warn")

    if appended and (placed > 0 or placed_total > 0 or expected_count == 0) then
        status(("Imported SRT to subtitle track %d."):format(target_track or 0), "ok")
        return expected_count, 0, target_track or 0, append_method
    end

    local ok_direct, direct_result = pcall(function() return timeline:ImportSubtitle(srt_path) end)
    status("Timeline ImportSubtitle returned: ok=" .. tostring(ok_direct) .. ", result=" .. tostring(direct_result), ok_direct and "dim" or "warn")
    if ok_direct and direct_result then
        status("Imported SRT using timeline ImportSubtitle fallback.", "ok")
        return expected_count, 0, target_track or 0, "timeline_import"
    end

    return 0, expected_count, target_track or 0, "failed"
end

local function insert_subtitles_direct(timeline, subs)
    local created, failed = 0, 0
    pcall(function() timeline:AddTrack("subtitle") end)
    sleep(0.25)
    local target_track = timeline:GetTrackCount("subtitle")
    for i, sub in ipairs(subs) do
        local ok, err2 = pcall(function()
            local success = timeline:InsertSubtitleAtFrame(
                sub.start_f, sub.finish - sub.start_f, sub.text
            )
            if success then created = created + 1
            else
                failed = failed + 1
                print("  [" .. i .. "] direct insert failed: start=" .. sub.start_f)
            end
        end)
        if not ok then
            failed = failed + 1
            print("  [" .. i .. "] direct insert error: " .. tostring(err2))
        end
    end
    return created, failed, target_track
end

local C = {
    bg = "#151515", panel = "#191919", bg_frame = "#191919",
    bg_input = "#202020", input = "#202020", bg_log = "#181818",
    bg_btn = "#2b2b2b", btn = "#2b2b2b", btn2 = "#252525",
    accent = "#e07820", accent2 = "#ffbd59", accent_hi = "#ffbd59",
    fg = "#f4f4f4", fg_dim = "#a2a2a2", dim = "#a2a2a2",
    fg_on_acc = "#101010", ok = "#56d364", warn = "#ffcc66",
    err = "#ff6b6b", border = "#535353", border_hot = "#ffbd59",
}

local SS = {
    win = ("background-color:%s; color:%s; font-family:'Segoe UI','Helvetica Neue',sans-serif;"):format(C.bg, C.fg),
    title = ("color:%s; font-size:17px; font-weight:700;"):format(C.fg),
    subtitle = ("color:%s; font-size:11px;"):format(C.fg_dim),
    label = ("color:%s; font-weight:600;"):format(C.fg),
    hint = ("color:%s; font-size:11px;"):format(C.fg_dim),
    dim = ("color:%s; font-size:8pt;"):format(C.fg_dim),
    input = ("QLineEdit, QSpinBox, QDoubleSpinBox { background-color:%s; color:%s; border:1px solid %s; border-radius:6px; padding:0px 9px; selection-background-color:%s; min-height:30px; font-weight:400; } QLineEdit:focus, QSpinBox:focus, QDoubleSpinBox:focus { border-color:%s; }"):format(C.bg_input, C.fg, C.border, C.accent, C.border_hot),
    input_fixed = ("QLineEdit { background-color:%s; color:%s; border:1px solid %s; border-radius:6px; padding:0px 9px; min-height:30px; font-size:9pt; } QLineEdit:focus { border-color:%s; }"):format(C.bg_input, C.fg, C.border, C.border_hot),
    input_video = ("QLineEdit { background-color:%s; color:%s; border:1px solid %s; border-radius:6px; padding:0px 9px; min-height:30px; font-size:9pt; } QLineEdit:focus { border-color:%s; }"):format(C.bg_input, C.fg, C.border, C.border_hot),
    log = ("background-color:%s; color:%s; border:1px solid %s; border-radius:7px; padding:9px; font-family:Consolas,Menlo,monospace; font-size:8pt; selection-background-color:%s;"):format(C.bg_log, C.fg, C.border, C.accent),
    btn = ("QPushButton { background-color:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #343434,stop:1 %s); color:%s; border:1px solid %s; border-radius:7px; padding:0px 14px; min-height:34px; font-weight:600; } QPushButton:hover { border-color:%s; } QPushButton:pressed { background-color:#1c1c1c; } QPushButton:disabled { background-color:#202020; color:#666666; border-color:#363636; }"):format(C.bg_btn, C.fg, C.border, C.border_hot),
    btn_sec = ("QPushButton { background-color:%s; color:%s; border:1px solid %s; border-radius:7px; padding:0px 14px; min-height:34px; } QPushButton:hover { border-color:%s; } QPushButton:disabled { background-color:#202020; color:#666666; border-color:#363636; }"):format(C.btn2, C.fg, C.border, C.border_hot),
    btn_acc = ("QPushButton { background-color:qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 %s,stop:1 %s); color:%s; border:1px solid %s; border-radius:7px; padding:0px 18px; min-height:36px; font-weight:800; } QPushButton:hover { border-color:%s; } QPushButton:pressed { background-color:%s; } QPushButton:disabled { background-color:#292929; color:#6f6f6f; border-color:#3b3b3b; }"):format(C.accent, C.accent2, C.fg_on_acc, C.accent, C.accent2, C.accent),
    btn_sel = ("QPushButton { background-color:%s; color:%s; border:1px solid %s; border-radius:7px; padding:0px 14px; min-height:34px; font-weight:700; }"):format(C.bg_btn, C.fg, C.accent),
    btn_to = ("QPushButton { background-color:%s; color:%s; border:1px solid %s; border-radius:7px; padding:7px 14px; }"):format(C.btn2, C.fg, C.border),
    btn_to_sel = ("QPushButton { background-color:%s; color:%s; border:1px solid %s; border-radius:7px; padding:0px 14px; min-height:34px; font-weight:700; }"):format(C.bg_btn, C.fg, C.accent),
    btn_tab = ("QPushButton { background-color:%s; color:%s; border:1px solid %s; border-radius:6px; padding:0px 9px; min-height:30px; font-size:8pt; } QPushButton:hover { border-color:%s; }"):format(C.bg_btn, C.fg_dim, C.border, C.border_hot),
    btn_tab_active = ("QPushButton { background-color:%s; color:%s; border:1px solid %s; border-radius:6px; padding:0px 9px; min-height:30px; font-size:8pt; font-weight:700; }"):format(C.bg_input, C.fg, C.accent),
    combo = ("QComboBox { background-color:%s; color:%s; border:1px solid %s; border-radius:6px; padding:0px 9px; min-height:30px; } QComboBox:hover { border-color:%s; } QComboBox::drop-down { width:22px; border:none; background:transparent; } QComboBox QAbstractItemView { background-color:%s; color:%s; selection-background-color:%s; border:1px solid %s; }"):format(C.bg_input, C.fg, C.border, C.border_hot, C.bg_input, C.fg, C.accent, C.border),
    tree = ("background-color:%s; color:%s; border:1px solid %s; border-radius:7px; font-size:8pt; selection-background-color:%s;"):format(C.bg_input, C.fg, C.border, C.accent),
    frame = ("background-color:%s; border:1px solid %s; border-radius:7px; padding:6px;"):format(C.bg_frame, C.border),
    check = ("QCheckBox { color:%s; } QCheckBox::indicator { width:15px; height:15px; }"):format(C.fg),
    sep = ("background-color:%s;"):format(C.border),
    bar = ("background-color:%s;"):format(C.accent),
    footer = ("color:%s; font-size:10px;"):format(C.fg_dim),
}

local function logAppend(w, msg, tag)
    local colors = { info=C.fg, ok=C.ok, warn=C.warn, err=C.err, head=C.accent, dim=C.fg_dim }
    local color  = colors[tag] or C.fg
    local safe   = msg:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")
    w.HTML = w.HTML .. ('<span style="color:%s">%s</span><br>'):format(color, safe)
end

local function logClear(w) w.HTML = "" end

-- ================================================================
--  MAIN  -  Fusion UIManager GUI
-- ================================================================
local function main()
    local ui   = fusion.UIManager
    local disp = bmd.UIDispatcher(ui)

    -- Connect to Resolve
    local resolve = fusion:GetResolve()
    if not resolve then
        print("\n  ERROR: Cannot connect to DaVinci Resolve.")
        print("  Make sure Resolve is running and External Scripting is set to Local.")
        return
    end

    local pm       = resolve:GetProjectManager()
    local project  = pm:GetCurrentProject()
    if not project then
        print("\n  ERROR: No project is open in Resolve."); return
    end

    local timeline = project:GetCurrentTimeline()
    if not timeline then
        print("\n  ERROR: No timeline is active. Open a timeline first."); return
    end

    local fps_str   = timeline:GetSetting("timelineFrameRate")
    local fps       = tonumber(fps_str) or 24.0
    local tl_start  = timeline:GetStartFrame()
    local tl_name   = timeline:GetName()
    local media_pool = project:GetMediaPool()
    local initial_track_count = timeline:GetTrackCount("video")

    print(string.rep("=", 55))
    print("  Resolve Text Toolkit")
    print(string.rep("=", 55))
    print("  Project  : " .. project:GetName())
    print("  Timeline : " .. tl_name)
    print("  FPS      : " .. fps)
    print()

    print("  Loading system fonts...")
    local all_fonts = get_system_fonts()
    print("  " .. #all_fonts .. " fonts found")

    print("  Scanning media pool for Fusion titles...")
    local item_names, item_map = {}, {}
    local function refresh_template_cache()
        item_names, item_map = {}, {}
        local all_items = get_all_media_pool_items(media_pool)
        for _, item in ipairs(all_items) do
            local nm = item:GetName()
            table.insert(item_names, nm)
            item_map[nm] = item
        end
        table.sort(item_names, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
        return #item_names
    end
    refresh_template_cache()
    print("  " .. #item_names .. " template(s) found")

    local FONT_STYLES = {
        "Regular", "Bold", "Italic", "Bold Italic",
        "Light", "Light Italic", "Medium", "Medium Italic",
        "SemiBold", "SemiBold Italic", "ExtraBold", "ExtraBold Italic",
        "Thin", "Thin Italic", "Black", "Black Italic",
        "Condensed", "Condensed Bold", "ExtraLight", "ExtraLight Italic",
    }

    local state = {
        srt_path               = "",
        font_srt_path          = "",
        selected_font          = "",
        selected_template_name = "",
        selected_snap_template = "",
        snap_srt_path          = "",
        snap_plan              = {},
        snap_timing_label      = "",
        snap_plan_source       = "",
        sub_output_folder      = default_documents_dir(),
        sub_last_srt_path      = "",
        scanned_dup_clips      = {},
        scanned_subs           = {},
    }

    -- -- UI helpers -----------------------------------------------
    local function sep()
        return ui:Label{Weight=0, MinimumSize={1,1}, MaximumSize={9999,1}, StyleSheet=SS.sep}
    end

    -- Tab IDs and labels
    local TAB_BTN_IDS = {"TxtTabBtn1","TxtTabBtn2","TxtTabBtn3","TxtTabBtn4","TxtTabBtn5"}
    local TAB_LABELS  = {"Subtitle Creator","Caption Titler","SRT Replacer","Font Changer","Tmpl. Duplicator"}

    -- -- Tab 1  -  SRT Replacer -------------------------------------
    local srtPage = ui:VGroup{ID="SRTPage", Spacing=4,
        ui:Label{Weight=0,
            Text="Maps SRT subtitle entries onto Text+ clips on the active timeline.\nSupports line-wrapping and multi text-box splitting.",
            StyleSheet=SS.dim, WordWrap=true},

        ui:HGroup{Weight=0, Spacing=4,
            ui:Label{Weight=0, Text="SRT file:", StyleSheet=SS.label, MinimumSize={70,0}},
            ui:Label{ID="SRT_FileLabel", Text="No file selected", Weight=1, StyleSheet=SS.dim},
            ui:Button{ID="SRT_Browse", Text="Browse...", StyleSheet=SS.btn},
        },

        sep(),
        ui:Label{Weight=0, Text="Line Wrapping:", StyleSheet=SS.label},
        ui:CheckBox{ID="SRT_WrapEnabled", Text="Enable auto line-wrapping",
                    Checked=true, StyleSheet=SS.label, Weight=0},
        ui:HGroup{Weight=0, Spacing=8,
            ui:Label{Weight=0, Text="Max chars per line:", StyleSheet=SS.label},
            ui:SpinBox{ID="SRT_MaxChars", Minimum=10, Maximum=80, Value=27,
                       StyleSheet=SS.input, MinimumSize={60,0}},
            ui:Label{Weight=0, Text="Mode:", StyleSheet=SS.label},
            ui:ComboBox{ID="SRT_WrapMode", StyleSheet=SS.combo, MinimumSize={170,0}},
        },

        sep(),
        ui:Label{Weight=0, Text="Multi Text-Box:", StyleSheet=SS.label},
        ui:CheckBox{ID="SRT_MultiEnabled",
            Text="Split SRT lines across TEXT 1, TEXT 2 ... boxes",
            Checked=true, StyleSheet=SS.label, Weight=0},

        sep(),
        ui:Label{Weight=0, Text="Advanced:", StyleSheet=SS.label},
        ui:HGroup{Weight=0, Spacing=8,
            ui:Label{Weight=0, Text="Skip frames:", StyleSheet=SS.label},
            ui:SpinBox{ID="SRT_Skip", Minimum=0, Maximum=100, Value=20,
                       StyleSheet=SS.input, MinimumSize={60,0}},
            ui:Label{Weight=0, Text="frames inside clip after transitions", StyleSheet=SS.dim},
        },

        sep(),
        ui:Label{Weight=0, Text="Log:", StyleSheet=SS.dim},
        ui:TextEdit{ID="SRTLog", Weight=1, ReadOnly=true, StyleSheet=SS.log},
        ui:HGroup{Weight=0,
            ui:Button{ID="SRT_DryRun",  Text="Dry Run",         StyleSheet=SS.btn},
            ui:Button{ID="SRT_ClearLog",Text="Clear Log",       StyleSheet=SS.btn},
            ui:HGap(0),
            ui:Button{ID="SRT_Run",     Text="  Run Transfer  ", StyleSheet=SS.btn_acc},
        },
    }

    -- -- Tab 2  -  Font Changer --------------------------------------
    local fontPage = ui:VGroup{ID="FONTPage", Spacing=4,
        ui:Label{Weight=0,
            Text="Changes the font (and optionally style) on Text+ clips.\nType to filter the list. Scope can be limited to SRT-matched clips only.",
            StyleSheet=SS.dim, WordWrap=true},

        ui:HGroup{Weight=0, Spacing=4,
            ui:Label{Weight=0, Text="Search:", StyleSheet=SS.label, MinimumSize={60,0}},
            ui:LineEdit{ID="FONT_Search", StyleSheet=SS.input,
                        PlaceholderText="filter " .. #all_fonts .. " fonts..."},
        },
        ui:Tree{
            ID="FONT_List", Weight=1,
            SortingEnabled=false, AlternatingRowColors=true,
            HeaderHidden=true, RootIsDecorated=false,
            StyleSheet=SS.tree,
        },
        ui:HGroup{Weight=0, Spacing=4,
            ui:Label{Weight=0, Text="Selected:", StyleSheet=SS.label},
            ui:Label{ID="FONT_Selected", Text="(none)", StyleSheet=SS.dim},
        },

        sep(),
        ui:HGroup{Weight=0, Spacing=8,
            ui:Label{Weight=0, Text="Style:", StyleSheet=SS.label, MinimumSize={45,0}},
            ui:ComboBox{ID="FONT_Style", StyleSheet=SS.combo, MinimumSize={160,0}},
            ui:CheckBox{ID="FONT_ChangeStyle", Text="Also change style",
                        Checked=true, StyleSheet=SS.label},
        },
        ui:HGroup{Weight=0, Spacing=4,
            ui:Label{Weight=0, Text="Scope:", StyleSheet=SS.label, MinimumSize={45,0}},
            ui:ComboBox{ID="FONT_Scope", StyleSheet=SS.combo, Weight=1},
            ui:Button{ID="FONT_BrowseSRT", Text="SRT...",
                      StyleSheet=SS.btn, MinimumSize={55,0}},
        },
        ui:Label{ID="FONT_SRTLabel", Text="", Weight=0, StyleSheet=SS.dim},

        sep(),
        ui:Label{Weight=0, Text="Log:", StyleSheet=SS.dim},
        ui:TextEdit{ID="FONTLog", Weight=0, MinimumSize={0,70},
                    ReadOnly=true, StyleSheet=SS.log},
        ui:HGroup{Weight=0,
            ui:Button{ID="FONT_ClearLog", Text="Clear Log",     StyleSheet=SS.btn},
            ui:HGap(0),
            ui:Button{ID="FONT_Apply",    Text="  Apply Font  ", StyleSheet=SS.btn_acc},
        },
    }

    -- -- Tab 3  -  Template Duplicator -------------------------------
    local dupPage = ui:VGroup{ID="DUPPage", Spacing=4,
        ui:Label{Weight=0,
            Text="Duplicates Text+ clips to new tracks using a Fusion template from the Media Pool.\nScan first, then select a template and click Duplicate.",
            StyleSheet=SS.dim, WordWrap=true},

        ui:HGroup{Weight=0, Spacing=4,
            ui:Label{Weight=0, Text="Search:", StyleSheet=SS.label, MinimumSize={60,0}},
            ui:LineEdit{ID="DUP_Search", StyleSheet=SS.input,
                        PlaceholderText="filter " .. #item_names .. " template(s)..."},
            ui:Button{ID="DUP_RefreshTemplates", Text="Refresh", StyleSheet=SS.btn},
        },
        ui:Tree{
            ID="DUP_List", Weight=1,
            SortingEnabled=false, AlternatingRowColors=true,
            HeaderHidden=true, RootIsDecorated=false,
            StyleSheet=SS.tree,
        },
        ui:HGroup{Weight=0, Spacing=4,
            ui:Label{Weight=0, Text="Selected:", StyleSheet=SS.label},
            ui:Label{ID="DUP_Selected", Text="(none)", StyleSheet=SS.dim},
        },

        sep(),
        ui:HGroup{Weight=0, Spacing=6,
            ui:Label{Weight=0, Text="Scan tracks: V1 to V", StyleSheet=SS.label},
            ui:SpinBox{ID="DUP_MaxTrack", Minimum=1, Maximum=99,
                       Value=initial_track_count, StyleSheet=SS.input, MinimumSize={60,0}},
            ui:Label{Weight=0,
                     Text="(of " .. initial_track_count .. " current)",
                     StyleSheet=SS.dim},
        },
        ui:Label{Weight=0,
            Text="New clips are placed on tracks added above the originals.",
            StyleSheet=SS.dim, WordWrap=true},

        sep(),
        ui:Label{Weight=0, Text="Log:", StyleSheet=SS.dim},
        ui:TextEdit{ID="DUPLog", Weight=0, MinimumSize={0,70},
                    ReadOnly=true, StyleSheet=SS.log},
        ui:HGroup{Weight=0,
            ui:Button{ID="DUP_Scan",     Text="Scan",           StyleSheet=SS.btn},
            ui:Button{ID="DUP_ClearLog", Text="Clear Log",      StyleSheet=SS.btn},
            ui:HGap(0),
            ui:Button{ID="DUP_Duplicate",Text="  Duplicate  ",  StyleSheet=SS.btn_acc},
        },
    }

    -- -- Tab 4  -  Subtitle Creator ----------------------------------
    local subPage = ui:VGroup{ID="SUBPage", Spacing=4,
        ui:Label{Weight=0,
            Text="Reads Text+ clips and creates a native subtitle track. Falls back to exporting an .srt file if the API is unavailable.",
            StyleSheet=SS.dim, WordWrap=true},

        ui:HGroup{Weight=0, Spacing=6,
            ui:Label{Weight=0, Text="Scan tracks: V1 to V", StyleSheet=SS.label},
            ui:SpinBox{ID="SUB_MaxTrack", Minimum=1, Maximum=99,
                       Value=initial_track_count, StyleSheet=SS.input, MinimumSize={60,0}},
            ui:Label{Weight=0,
                     Text="(of " .. initial_track_count .. " current)",
                     StyleSheet=SS.dim},
        },
        ui:HGroup{Weight=0, Spacing=6,
            ui:Label{Weight=0, Text="Output:", StyleSheet=SS.label, MinimumSize={85,0}},
            ui:ComboBox{ID="SUB_OutputMode", StyleSheet=SS.combo, Weight=1},
        },
        ui:HGroup{Weight=0, Spacing=4,
            ui:Label{Weight=0, Text="Export folder:", StyleSheet=SS.label, MinimumSize={85,0}},
            ui:Label{ID="SUB_OutputFolder", Text=truncate_path(default_documents_dir(), 55),
                     Weight=1, StyleSheet=SS.dim},
            ui:Button{ID="SUB_BrowseFolder", Text="Browse...", StyleSheet=SS.btn},
        },

        sep(),
        ui:Label{Weight=0, Text="Preview:", StyleSheet=SS.dim},
        ui:TextEdit{ID="SUB_Preview", ReadOnly=true, Weight=1, StyleSheet=SS.log},

        sep(),
        ui:Label{Weight=0, Text="Log:", StyleSheet=SS.dim},
        ui:TextEdit{ID="SUBLog", Weight=0, MinimumSize={0,45},
                    ReadOnly=true, StyleSheet=SS.log},
        ui:HGroup{Weight=0,
            ui:Button{ID="SUB_Scan",     Text="Scan",                   StyleSheet=SS.btn},
            ui:Button{ID="SUB_ClearLog", Text="Clear Log",              StyleSheet=SS.btn},
            ui:HGap(0),
            ui:Button{ID="SUB_Create",   Text="  Create Subtitles  ",   StyleSheet=SS.btn_acc},
        },
    }

    -- -- Tab 5  -  Caption Titler ------------------------------------
    local snapPage = ui:VGroup{ID="SNAPPage", Spacing=4,
        ui:Label{Weight=0,
            Text="Creates Text+ caption clips from an .srt using a Fusion title template from the Media Pool.\nBrowse an .srt by default, or try reading an existing timeline subtitle track.",
            StyleSheet=SS.dim, WordWrap=true},

        ui:HGroup{Weight=0, Spacing=4,
            ui:Label{Weight=0, Text="SRT file:", StyleSheet=SS.label, MinimumSize={70,0}},
            ui:Label{ID="SNAP_FileLabel", Text="No file selected", Weight=1, StyleSheet=SS.dim},
            ui:Button{ID="SNAP_Browse", Text="Browse...", StyleSheet=SS.btn},
            ui:Button{ID="SNAP_FromTimeline", Text="Use Timeline Subs", StyleSheet=SS.btn},
        },

        sep(),
        ui:HGroup{Weight=0, Spacing=4,
            ui:Label{Weight=0, Text="Template:", StyleSheet=SS.label, MinimumSize={70,0}},
            ui:LineEdit{ID="SNAP_Search", StyleSheet=SS.input,
                        PlaceholderText="filter " .. #item_names .. " template(s)..."},
            ui:Button{ID="SNAP_RefreshTemplates", Text="Refresh", StyleSheet=SS.btn},
        },
        ui:Tree{
            ID="SNAP_List", Weight=1,
            SortingEnabled=false, AlternatingRowColors=true,
            HeaderHidden=true, RootIsDecorated=false,
            StyleSheet=SS.tree,
        },
        ui:HGroup{Weight=0, Spacing=4,
            ui:Label{Weight=0, Text="Selected:", StyleSheet=SS.label},
            ui:Label{ID="SNAP_Selected", Text="(none)", StyleSheet=SS.dim},
        },

        sep(),
        ui:HGroup{Weight=0, Spacing=6,
            ui:Label{Weight=0, Text="Timing:", StyleSheet=SS.label},
            ui:ComboBox{ID="SNAP_TimingMode", StyleSheet=SS.combo, Weight=1},
        },
        ui:CheckBox{ID="SNAP_MultiEnabled",
            Text="Split SRT lines across multiple Text+ boxes in the template",
            Checked=true, StyleSheet=SS.label, Weight=0},
        ui:Label{Weight=0,
            Text="Auto handles the common 00:00:00:00 vs 01:00:00:00 mismatch by choosing the offset closest to the timeline start.",
            StyleSheet=SS.dim, WordWrap=true},

        sep(),
        ui:Label{Weight=0, Text="Preview:", StyleSheet=SS.dim},
        ui:TextEdit{ID="SNAP_Preview", ReadOnly=true, Weight=1, StyleSheet=SS.log},

        sep(),
        ui:Label{Weight=0, Text="Log:", StyleSheet=SS.dim},
        ui:TextEdit{ID="SNAPLog", Weight=0, MinimumSize={0,55},
                    ReadOnly=true, StyleSheet=SS.log},
        ui:HGroup{Weight=0,
            ui:Button{ID="SNAP_PreviewBtn", Text="Preview",        StyleSheet=SS.btn},
            ui:Button{ID="SNAP_ClearLog",   Text="Clear Log",      StyleSheet=SS.btn},
            ui:HGap(0),
            ui:Button{ID="SNAP_Create",     Text="  Create Clips  ", StyleSheet=SS.btn_acc},
        },
    }

    -- -- Assemble window -------------------------------------------
    local WIN_ID = ONLY_TAB and SINGLE_TOOLS[ONLY_TAB].id or "ResolveTextToolkitSingularGraphite2026V3"
    local topBar
    if ONLY_TAB then
        topBar = ui:VGroup{Weight=0, Spacing=4,
            ui:HGroup{Weight=0, Spacing=12, MinimumSize={0,34}, MaximumSize={9999,34},
                ui:Label{Weight=0, MinimumSize={5,30}, MaximumSize={5,30}, StyleSheet=("background-color:%s;"):format(C.accent)},
                ui:Label{Text=SINGLE_TOOLS[ONLY_TAB].title, StyleSheet=("color:%s; font-size:17px; font-weight:700;"):format(C.fg), Weight=1, MinimumSize={0,34}, MaximumSize={9999,34}},
            },
        }
    else
        topBar = ui:HGroup{Weight=0, Spacing=4, MinimumSize={0,36}, MaximumSize={9999,36},
            ui:Button{ID=TAB_BTN_IDS[1], Text=TAB_LABELS[1], StyleSheet=SS.btn_tab_active},
            ui:Button{ID=TAB_BTN_IDS[2], Text=TAB_LABELS[2], StyleSheet=SS.btn_tab},
            ui:Button{ID=TAB_BTN_IDS[3], Text=TAB_LABELS[3], StyleSheet=SS.btn_tab},
            ui:Button{ID=TAB_BTN_IDS[4], Text=TAB_LABELS[4], StyleSheet=SS.btn_tab},
            ui:Button{ID=TAB_BTN_IDS[5], Text=TAB_LABELS[5], StyleSheet=SS.btn_tab},
        }
    end
    local win = disp:AddWindow({
        ID          = WIN_ID,
        WindowTitle = ONLY_TAB and SINGLE_TOOLS[ONLY_TAB].title or "Resolve Text Toolkit",
        Geometry    = {100, 50, 940, 900},
        MinimumSize = {860, 800},
        StyleSheet  = SS.win,

        ui:VGroup{Spacing=0,
            ui:VGap(12),
            ui:HGroup{Weight=1, Spacing=0,
                ui:HGap(12),
                ui:VGroup{Weight=1, Spacing=4,
                    topBar,
                    sep(),
                    ui:Stack{ID="RTKStack", subPage, snapPage, srtPage, fontPage, dupPage},
                },
                ui:HGap(12),
            },
            ui:VGap(12),
        },
    })

    local itm = win:GetItems()

    -- Stack starts on tab 1; style all buttons
    -- (single-tool builds keep every page in the stack so shared code works, but only show their own)
    itm.RTKStack.CurrentIndex = ONLY_TAB and (ONLY_TAB - 1) or 0
    for i, btnID in ipairs(TAB_BTN_IDS) do
        if itm[btnID] then itm[btnID].StyleSheet = (i == 1) and SS.btn_tab_active or SS.btn_tab end
    end

    -- -- Init logs -------------------------------------------------
    itm.SRTLog.HTML  = ""
    itm.FONTLog.HTML = ""
    itm.DUPLog.HTML  = ""
    itm.SUBLog.HTML  = ""
    itm.SNAPLog.HTML = ""

    -- -- Init combo boxes ------------------------------------------
    itm.SRT_WrapMode:AddItem("Balanced (even line lengths)")
    itm.SRT_WrapMode:AddItem("Simple (fill then break)")

    itm.SNAP_TimingMode:AddItem("Auto")
    itm.SNAP_TimingMode:AddItem("SRT starts at timeline start")
    itm.SNAP_TimingMode:AddItem("SRT uses timeline timecode")
    itm.SNAP_TimingMode:AddItem("Subtract 01:00:00:00 from SRT")
    itm.SNAP_TimingMode:AddItem("Add 01:00:00:00 to SRT")

    itm.SUB_OutputMode:AddItem("Create in timeline + export SRT")
    itm.SUB_OutputMode:AddItem("Create in timeline only")
    itm.SUB_OutputMode:AddItem("Export SRT only")

    for _, sty in ipairs(FONT_STYLES) do itm.FONT_Style:AddItem(sty) end
    itm.FONT_Style.CurrentIndex = 1  -- Bold by default

    itm.FONT_Scope:AddItem("All Text+ clips on timeline")
    itm.FONT_Scope:AddItem("Only SRT-matched clips")

    -- -- Init trees ------------------------------------------------
    itm.FONT_List.ColumnCount = 1
    for _, font_name in ipairs(all_fonts) do
        local row = itm.FONT_List:NewItem()
        row.Text[0] = font_name
        itm.FONT_List:AddTopLevelItem(row)
    end

    itm.DUP_List.ColumnCount = 1
    for _, nm in ipairs(item_names) do
        local row = itm.DUP_List:NewItem()
        row.Text[0] = nm
        itm.DUP_List:AddTopLevelItem(row)
    end

    itm.SNAP_List.ColumnCount = 1
    for _, nm in ipairs(item_names) do
        local row = itm.SNAP_List:NewItem()
        row.Text[0] = nm
        itm.SNAP_List:AddTopLevelItem(row)
    end

    itm.SUB_Preview.PlainText = "Click Scan to read Text+ clips."
    itm.SNAP_Preview.PlainText = "Browse an .srt, choose a template, then click Preview."

    -- -- Tab switching ---------------------------------------------
    local function switchTab(idx)
        if ONLY_TAB then return end
        itm.RTKStack.CurrentIndex = idx - 1
        for i, btnID in ipairs(TAB_BTN_IDS) do
            itm[btnID].StyleSheet = (i == idx) and SS.btn_tab_active or SS.btn_tab
        end
    end

    win.On.TxtTabBtn1.Clicked = function() switchTab(1) end
    win.On.TxtTabBtn2.Clicked = function() switchTab(2) end
    win.On.TxtTabBtn3.Clicked = function() switchTab(3) end
    win.On.TxtTabBtn4.Clicked = function() switchTab(4) end
    win.On.TxtTabBtn5.Clicked = function() switchTab(5) end

    win.On[WIN_ID].Close = function() disp:ExitLoop() end

    -- -- SRT Replacer ---------------------------------------------

    win.On.SRT_Browse.Clicked = function()
        local path = fusion:RequestFile()
        if path and path ~= "" then
            state.srt_path = path
            itm.SRT_FileLabel.Text = truncate_path(path, 55)
        end
    end

    win.On.SRT_ClearLog.Clicked = function() logClear(itm.SRTLog) end

    local function do_transfer(dry_run)
        logClear(itm.SRTLog)
        local srt_path = state.srt_path
        if srt_path == "" then
            logAppend(itm.SRTLog, "No SRT file selected.", "err"); return
        end
        local current_tl = project:GetCurrentTimeline()
        if not current_tl then
            logAppend(itm.SRTLog, "No timeline active.", "err"); return
        end

        local cur_fps   = tonumber(current_tl:GetSetting("timelineFrameRate")) or fps
        local cur_start = current_tl:GetStartFrame()

        logAppend(itm.SRTLog, "Scanning Text+ clips...", "info")
        local text_tracks = discover_all_text_tracks(current_tl)
        if not next_key(text_tracks) then
            logAppend(itm.SRTLog, "No Text+ clips found on any video track.", "err"); return
        end
        local total_clips = 0
        for _, v in pairs(text_tracks) do total_clips = total_clips + #v end

        logAppend(itm.SRTLog, "Parsing SRT...", "info")
        local srt_entries, err = parse_srt(srt_path)
        if not srt_entries then
            logAppend(itm.SRTLog, "Error reading SRT: " .. (err or ""), "err"); return
        end
        if #srt_entries == 0 then
            logAppend(itm.SRTLog, "No entries found in SRT file.", "err"); return
        end
        local source_ref_path, source_ref_count = attach_source_srt_text(srt_path, srt_entries)
        if source_ref_count and source_ref_count > 0 then
            logAppend(itm.SRTLog, ("Using EN reference matching: %d entries   -   %s"):format(source_ref_count, source_ref_path or ""), "dim")
        else
            logAppend(itm.SRTLog, "EN reference matching unavailable: " .. tostring(source_ref_path or "no sibling EN path"), "warn")
        end
        if (srt_entries._timecode_repairs or 0) > 0 then
            logAppend(itm.SRTLog,
                ("Repaired %d malformed SRT timecode%s."):format(
                    srt_entries._timecode_repairs,
                    srt_entries._timecode_repairs == 1 and "" or "s"),
                "warn")
        end
        if (srt_entries._hour_adjustments or 0) > 0 then
            logAppend(itm.SRTLog,
                ("Fixed %d SRT entr%s with sudden timecode jump(s)."):format(
                    srt_entries._hour_adjustments,
                    srt_entries._hour_adjustments == 1 and "y" or "ies"),
                "warn")
        end

        local skip = itm.SRT_Skip.Value
        local offset, mapping, tc_type = auto_detect_offset(
            srt_entries, text_tracks, cur_start, cur_fps, skip
        )

        local matched, unmatched = 0, 0
        for _, m in ipairs(mapping) do
            if m.clip then matched = matched + 1 else unmatched = unmatched + 1 end
        end

        logAppend(itm.SRTLog,
            ("Timeline: %s   -   %d clips   -   %d SRT entries   -   offset: %s"):format(
                current_tl:GetName(), total_clips, #srt_entries, tc_type), "dim")
        logAppend(itm.SRTLog, ("Matched: %d / %d"):format(matched, #mapping),
                  matched == 0 and "err" or "info")
        if unmatched > 0 then
            local misses = {}
            for _, m in ipairs(mapping) do
                if not m.clip then
                    table.insert(misses, "#" .. tostring(m.sub_index) .. " " .. show_breaks(m.srt_text, 34))
                end
            end
            local msg = "Unmatched SRT entries: " .. table.concat(misses, " | ")
            logAppend(itm.SRTLog, msg, "warn")
            print("  " .. msg)
        end

        print("\n  Timeline : " .. current_tl:GetName())
        print("  SRT      : " .. (srt_path:match("[^/\\]+$") or srt_path) ..
              "  (" .. #srt_entries .. " entries)")
        print("  Clips    : " .. total_clips .. ",  Timecodes: " .. tc_type)
        print("  Matched  : " .. matched .. " / " .. #mapping)

        if matched == 0 then
            logAppend(itm.SRTLog,
                "No matches  -  check skip frames or verify SRT timecodes align with clips.", "warn")
            return
        end

        local w_enabled = itm.SRT_WrapEnabled.Checked
        local w_max     = itm.SRT_MaxChars.Value
        local w_mode    = itm.SRT_WrapMode.CurrentIndex == 0 and "balanced" or "simple"
        local m_enabled = true

        local function verified_set_tool_text(tool, text)
            if dry_run then return true end
            local wrote = false
            pcall(function() tool:SetInput("StyledText", text); wrote = true end)
            pcall(function() tool:SetInput("Text", text); wrote = true end)
            pcall(function() tool:SetInput("PlainText", text); wrote = true end)
            if not wrote then return false end
            for _, input_name in ipairs({"StyledText", "Text", "PlainText"}) do
                local ok_read, actual = pcall(function() return tool:GetInput(input_name) end)
                if ok_read and trim(normalize_text_breaks(actual or "")) == trim(normalize_text_breaks(text or "")) then
                    return true
                end
            end
            return false
        end

        local function get_numbered_text_inputs(tool)
            local out = {}
            local ok_list, inputs = pcall(function() return tool:GetInputList() end)
            if not (ok_list and inputs) then return out end
            for key, input in pairs(inputs) do
                local attrs = {}
                pcall(function() attrs = input:GetAttrs() or {} end)
                local id = tostring(attrs.INPS_ID or key or "")
                local name = tostring(attrs.LINKS_Name or attrs.INPS_Name or id)
                local label = (id .. " " .. name):lower()
                local data_type = tostring(attrs.LINKID_DataType or ""):lower()
                local n = tonumber(label:match("text%s*[_%- ]*(%d+)") or label:match("text(%d+)"))
                local is_text = n ~= nil or label:match("styledtext")
                if data_type ~= "" and not data_type:match("text") and not label:match("styledtext") then
                    is_text = false
                end
                local excluded = label:match("font") or label:match("size") or label:match("color")
                    or label:match("tracking") or label:match("spacing") or label:match("opacity")
                    or label:match("layout") or label:match("center") or label:match("round")
                    or label:match("width") or label:match("height") or label:match("write")
                    or label:match("start") or label:match("end")
                if id ~= "" and is_text and not excluded then
                    table.insert(out, { id = id, order = n or 9999, name = name })
                end
            end
            table.sort(out, function(a, b)
                if a.order == b.order then return a.id < b.id end
                return a.order < b.order
            end)
            return out
        end

        local function verified_set_tool_input(tool, input_id, text)
            if dry_run then return true end
            local wrote = false
            pcall(function() tool:SetInput(input_id, text); wrote = true end)
            if not wrote then return false end
            local ok_read, actual = pcall(function() return tool:GetInput(input_id) end)
            return ok_read and trim(normalize_text_breaks(actual or "")) == trim(normalize_text_breaks(text or ""))
        end

        local function get_clip_numbered_text_inputs(clip)
            local out = {}
            pcall(function()
                local cc = clip.item:GetFusionCompCount()
                if cc == 0 then return end
                for ci = 1, cc do
                    local comp = clip.item:GetFusionCompByIndex(ci)
                    if comp then
                        local all_tools = comp:GetToolList(false)
                        if next_key(all_tools) then
                            for _, any_tool in pairs(all_tools) do
                                for _, candidate in ipairs(get_numbered_text_inputs(any_tool)) do
                                    if candidate.order < 9999 then
                                        candidate.tool = any_tool
                                        table.insert(out, candidate)
                                    end
                                end
                            end
                        end
                    end
                end
            end)
            table.sort(out, function(a, b)
                if a.order == b.order then return a.id < b.id end
                return a.order < b.order
            end)
            return out
        end

        local last_match_pos = nil
        for mi = #mapping, 1, -1 do
            if mapping[mi].clip then last_match_pos = mi; break end
        end

        local replaced, lines_wrapped, multi_splits, write_failed = 0, 0, 0, 0

        for i, m in ipairs(mapping) do
            local clip = m.clip
            if clip then
                local srt_text = m.srt_text
                local is_last_matched = last_match_pos and i == last_match_pos
                -- Re-fetch tools fresh from the item (scanned refs may be stale)
                local tools = {}
                pcall(function()
                    local cc = clip.item:GetFusionCompCount()
                    if cc == 0 then return end
                    for ci = 1, cc do
                        local comp = clip.item:GetFusionCompByIndex(ci)
                        if comp then
                            local tt = comp:GetToolList(false, "TextPlus")
                            if not next_key(tt) then tt = comp:GetToolList(false, "Text3D") end
                            if next_key(tt) then
                                local skeys = {}
                                for k in pairs(tt) do table.insert(skeys, k) end
                                table.sort(skeys, function(a, b) return tostring(a) < tostring(b) end)
                                for _, k in ipairs(skeys) do table.insert(tools, tt[k]) end
                            end
                        end
                    end
                end)
                if #tools == 0 then goto continue_srt end

                local num_tools = #tools
                if m_enabled then
                    local multi_text, did_wrap = format_srt_text_for_transfer(srt_text, w_max, w_mode, w_enabled, is_last_matched)
                    local srt_lines = split_lines(multi_text)
                    if did_wrap then lines_wrapped = lines_wrapped + 1 end
                    local texts_for_tools = {}
                    local text_target_count = num_tools
                    local input_targets = {}
                    if num_tools == 1 then
                        input_targets = get_clip_numbered_text_inputs(clip)
                        if #input_targets > 1 then text_target_count = #input_targets end
                    end
                    if text_target_count > 1 then
                    for t_idx = 1, text_target_count do
                        if t_idx <= #srt_lines then
                            if t_idx == text_target_count and #srt_lines > text_target_count then
                                local tail = {}
                                for li = t_idx, #srt_lines do table.insert(tail, srt_lines[li]) end
                                table.insert(texts_for_tools, table.concat(tail, "\n"))
                            else
                                table.insert(texts_for_tools, srt_lines[t_idx])
                            end
                        else
                            table.insert(texts_for_tools, "")
                        end
                    end
                    for t_idx, tool_text in ipairs(texts_for_tools) do
                        local final = tool_text
                        local ok_write
                        if #input_targets > 1 then
                            ok_write = verified_set_tool_input(input_targets[t_idx].tool, input_targets[t_idx].id, final)
                        else
                            ok_write = verified_set_tool_text(tools[t_idx], final)
                        end
                        if not ok_write then
                            write_failed = write_failed + 1
                            print("  WRITE VERIFY FAILED #" .. tostring(m.sub_index) .. " tool " .. tostring(t_idx))
                        end
                    end
                    if #srt_lines > 1 or text_target_count > 1 then
                        multi_splits = multi_splits + 1
                        local parts = {}
                        for _, t in ipairs(texts_for_tools) do
                            table.insert(parts, show_breaks(t, 25))
                        end
                        print("  #" .. string.format("%2d", m.sub_index) ..
                              " MULTI (" .. num_tools .. "): " .. table.concat(parts, " | "))
                    end
                    replaced = replaced + 1
                    else
                    local final_text, did_wrap = format_srt_text_for_transfer(srt_text, w_max, w_mode, w_enabled, is_last_matched)
                    if did_wrap then lines_wrapped = lines_wrapped + 1 end
                    if not dry_run then
                        if not verified_set_tool_text(tools[1], final_text) then
                            write_failed = write_failed + 1
                            print("  WRITE VERIFY FAILED #" .. tostring(m.sub_index))
                        end
                    end
                    replaced = replaced + 1
                    end
                end
                ::continue_srt::
            end
        end

        local lang = (srt_path:match("[^/\\]+$") or srt_path):gsub("%.[^%.]+$", "")
        if dry_run then
            logAppend(itm.SRTLog, "-- Dry Run - no changes made --", "head")
            logAppend(itm.SRTLog,
                ("Would replace %d   -   wrap %d   -   multi-box %d   -   unmatched %d"):format(
                    replaced, lines_wrapped, multi_splits, unmatched), "info")
            logAppend(itm.SRTLog, "Click Run Transfer to apply.", "dim")
            print("\n  DRY RUN: replace=" .. replaced .. ", wrap=" .. lines_wrapped ..
                  ", multi=" .. multi_splits .. ", unmatched=" .. unmatched)
        else
            sleep(0.3)
            logAppend(itm.SRTLog, "-- Done --", "head")
            local parts = { "Replaced: " .. replaced }
            if lines_wrapped > 0 then table.insert(parts, "auto-wrapped: " .. lines_wrapped) end
            if multi_splits  > 0 then table.insert(parts, "multi-box: "   .. multi_splits)   end
            if unmatched     > 0 then table.insert(parts, "unmatched: "   .. unmatched)       end
            if write_failed  > 0 then table.insert(parts, "VERIFY FAILED: " .. write_failed)  end
            table.insert(parts, lang)
            logAppend(itm.SRTLog, table.concat(parts, "   -   "), write_failed > 0 and "err" or "ok")
            logAppend(itm.SRTLog, "Ctrl+Z to undo if needed.", "dim")
            print("\n  Done! replaced=" .. replaced .. ", wrapped=" .. lines_wrapped ..
                  ", multi=" .. multi_splits .. ", lang=" .. lang)
            print("  Ctrl+Z to undo if needed.")
        end
    end

    win.On.SRT_DryRun.Clicked  = function() do_transfer(true)  end
    win.On.SRT_Run.Clicked     = function() do_transfer(false) end

    -- -- Font Changer ---------------------------------------------

    local function repopulate_font_tree(query)
        query = query or ""
        itm.FONT_List:Clear()
        local qt = query:lower()
        for _, font_name in ipairs(all_fonts) do
            if qt == "" or font_name:lower():find(qt, 1, true) then
                local row = itm.FONT_List:NewItem()
                row.Text[0] = font_name
                itm.FONT_List:AddTopLevelItem(row)
            end
        end
    end

    win.On.FONT_Search.TextChanged = function(ev)
        repopulate_font_tree(itm.FONT_Search.Text)
    end

    win.On.FONT_List.CurrentItemChanged = function()
        local item = itm.FONT_List:CurrentItem()
        if item then
            state.selected_font = item.Text[0]
            itm.FONT_Selected.Text = item.Text[0]
        end
    end

    win.On.FONT_BrowseSRT.Clicked = function()
        local path = fusion:RequestFile()
        if path and path ~= "" then
            state.font_srt_path = path
            itm.FONT_SRTLabel.Text = truncate_path(path, 55)
        end
    end

    win.On.FONT_ClearLog.Clicked = function() logClear(itm.FONTLog) end

    win.On.FONT_Apply.Clicked = function()
        logClear(itm.FONTLog)
        local font_name = state.selected_font
        if font_name == "" then
            logAppend(itm.FONTLog, "No font selected from the list.", "err"); return
        end

        local style_name  = FONT_STYLES[itm.FONT_Style.CurrentIndex + 1] or "Regular"
        local apply_style = itm.FONT_ChangeStyle.Checked
        local scope       = itm.FONT_Scope.CurrentIndex  -- 0=all, 1=srt-matched

        local current_tl = project:GetCurrentTimeline()
        if not current_tl then
            logAppend(itm.FONTLog, "No timeline active.", "err"); return
        end

        local cur_fps   = tonumber(current_tl:GetSetting("timelineFrameRate")) or fps
        local cur_start = current_tl:GetStartFrame()

        logAppend(itm.FONTLog, "Scanning Text+ clips...", "info")
        local text_tracks = discover_all_text_tracks(current_tl)
        if not next_key(text_tracks) then
            logAppend(itm.FONTLog, "No Text+ clips found.", "err"); return
        end

        local clips_to_change = {}
        if scope == 0 then
            for _, clips in pairs(text_tracks) do
                for _, c in ipairs(clips) do table.insert(clips_to_change, c) end
            end
        else
            local srt_path = state.font_srt_path
            if srt_path == "" then
                logAppend(itm.FONTLog,
                    "SRT-matched scope requires an SRT file  -  click SRT... to browse.", "err")
                return
            end
            local srt_entries, err = parse_srt(srt_path)
            if not srt_entries then
                logAppend(itm.FONTLog, "Error reading SRT: " .. (err or ""), "err"); return
            end
            if #srt_entries == 0 then
                logAppend(itm.FONTLog, "No entries in SRT file.", "err"); return
            end
            local _, mapping, _ = auto_detect_offset(
                srt_entries, text_tracks, cur_start, cur_fps, 20)
            local seen_items = {}
            for _, m in ipairs(mapping) do
                local clip = m.clip
                if clip and not seen_items[clip.item] then
                    seen_items[clip.item] = true
                    table.insert(clips_to_change, clip)
                end
            end
        end

        if #clips_to_change == 0 then
            logAppend(itm.FONTLog, "No matching clips found.", "warn"); return
        end

        local desc = "'" .. font_name .. (apply_style and (" " .. style_name) or "") .. "'"
        logAppend(itm.FONTLog,
            ("Applying %s to %d clip(s)..."):format(desc, #clips_to_change), "info")

        local changed, tools_changed, errors = 0, 0, 0
        for _, clip in ipairs(clips_to_change) do
            pcall(function()
                local cc = clip.item:GetFusionCompCount()
                if cc == 0 then return end
                local comp = clip.item:GetFusionCompByIndex(1)
                if not comp then return end
                local tt = comp:GetToolList(false, "TextPlus")
                if not next_key(tt) then tt = comp:GetToolList(false, "Text3D") end
                if not next_key(tt) then return end
                for _, tool in pairs(tt) do
                    local ok, err2 = pcall(function()
                        tool:SetInput("Font", font_name)
                        if apply_style then tool:SetInput("Style", style_name) end
                    end)
                    if ok then tools_changed = tools_changed + 1
                    else
                        errors = errors + 1
                        print("  Error on '" .. clip.name .. "': " .. tostring(err2))
                    end
                end
                changed = changed + 1
            end)
        end

        local style_info = apply_style and (" " .. style_name) or ""
        print("\n  Font  ->  '" .. font_name .. style_info .. "'")
        print("  Clips: " .. changed .. ", text boxes: " .. tools_changed .. ", errors: " .. errors)
        print("  Timeline: " .. current_tl:GetName())
        print("  Ctrl+Z to undo if needed.")

        logAppend(itm.FONTLog, "-- Done --", "head")
        local status = ("OK %d clips  ->  '%s%s'"):format(changed, font_name, style_info)
        if errors > 0 then status = status .. ("   -   %d error(s)  -  see Console"):format(errors) end
        logAppend(itm.FONTLog, status, errors > 0 and "warn" or "ok")
        logAppend(itm.FONTLog, "Ctrl+Z to undo if needed.", "dim")
    end

    -- -- Template Duplicator ---------------------------------------

    local function repopulate_dup_tree(query)
        query = query or ""
        itm.DUP_List:Clear()
        local qt = query:lower()
        for _, nm in ipairs(item_names) do
            if qt == "" or nm:lower():find(qt, 1, true) then
                local row = itm.DUP_List:NewItem()
                row.Text[0] = nm
                itm.DUP_List:AddTopLevelItem(row)
            end
        end
    end

    win.On.DUP_Search.TextChanged = function()
        repopulate_dup_tree(itm.DUP_Search.Text)
    end

    win.On.DUP_List.CurrentItemChanged = function()
        local item = itm.DUP_List:CurrentItem()
        if item then
            state.selected_template_name = item.Text[0]
            itm.DUP_Selected.Text = item.Text[0]
        end
    end

    win.On.DUP_ClearLog.Clicked = function() logClear(itm.DUPLog) end

    local function run_dup_scan()
        logClear(itm.DUPLog)
        local current_tl = project:GetCurrentTimeline()
        if not current_tl then
            logAppend(itm.DUPLog, "No timeline active.", "err"); return
        end
        local max_track = itm.DUP_MaxTrack.Value
        logAppend(itm.DUPLog, "Scanning V1-V" .. max_track .. "...", "info")
        state.scanned_dup_clips = {}
        local clips = scan_text_clips_for_duplicator(current_tl, max_track)
        state.scanned_dup_clips = clips
        if #clips == 0 then logAppend(itm.DUPLog, "No Text+ clips found.", "warn"); return end
        local trans_count, xf_count = 0, 0
        for _, c in ipairs(clips) do
            if (c.transition_in or 0) > 0 or (c.transition_out or 0) > 0 then
                trans_count = trans_count + 1
            end
            if next_key(c.transform) then xf_count = xf_count + 1 end
        end
        local info = ("Found %d Text+ clip(s)"):format(#clips)
        if trans_count > 0 then info = info .. "   -   " .. trans_count .. " with transitions" end
        if xf_count    > 0 then info = info .. "   -   " .. xf_count    .. " with transform"   end
        logAppend(itm.DUPLog, info, "ok")
        print("\n  Scan: " .. #clips .. " clips on V1-V" .. max_track)
    end
    win.On.DUP_Scan.Clicked = run_dup_scan

    win.On.DUP_Duplicate.Clicked = function()
        local scanned = state.scanned_dup_clips
        if #scanned == 0 then
            logAppend(itm.DUPLog, "Click Scan first to read timeline clips.", "warn"); return
        end
        local tmpl_name = state.selected_template_name
        if tmpl_name == "" then
            logAppend(itm.DUPLog, "No template selected from the list.", "err"); return
        end
        local template_item = item_map[tmpl_name]
        if not template_item then
            logAppend(itm.DUPLog, "Template not found in media pool.", "err"); return
        end
        local current_tl = project:GetCurrentTimeline()
        if not current_tl then
            logAppend(itm.DUPLog, "No timeline active.", "err"); return
        end

        local cur_fps = tonumber(current_tl:GetSetting("timelineFrameRate")) or fps

        -- collect unique source tracks
        local orig_tracks_set = {}
        for _, c in ipairs(scanned) do orig_tracks_set[c.track] = true end
        local orig_tracks = {}
        for k in pairs(orig_tracks_set) do table.insert(orig_tracks, k) end
        table.sort(orig_tracks)

        -- Calibration
        logAppend(itm.DUPLog, "Calibrating template frame rate...", "info")
        current_tl:AddTrack("video")
        sleep(0.2)
        local cal_track     = current_tl:GetTrackCount("video")
        local test_endframe = 1000
        local test_start    = scanned[1].start_f
        local fps_scale     = 1.0
        local ok_cal, cal_err = pcall(function()
            local cal_result = media_pool:AppendToTimeline({
                { mediaPoolItem = template_item, trackIndex = cal_track,
                  recordFrame = test_start, startFrame = 0, endFrame = test_endframe, mediaType = 1 }
            })
            sleep(0.3)
            if cal_result and #cal_result > 0 then
                local cal_clip = find_clip_near_frame(current_tl, cal_track, test_start, 15)
                if cal_clip then
                    local cal_actual = cal_clip:GetEnd() - cal_clip:GetStart()
                    if cal_actual > 0 and math.abs(cal_actual - test_endframe) > 2 then
                        fps_scale = test_endframe / cal_actual
                        logAppend(itm.DUPLog,
                            ("Calibration: scale=%.4f  (%df  ->  %df)"):format(
                                fps_scale, test_endframe, cal_actual), "dim")
                        print("\n  CALIBRATION: scale=" .. string.format("%.4f", fps_scale) ..
                              " (" .. test_endframe .. "f  ->  " .. cal_actual .. "f)")
                    else
                        logAppend(itm.DUPLog, "Calibration: 1:1  -  no scaling needed.", "dim")
                        print("\n  CALIBRATION: 1:1  -  no scaling needed")
                    end
                end
            end
        end)
        if not ok_cal then
            logAppend(itm.DUPLog, "Calibration failed: " .. tostring(cal_err), "warn")
            print("  Calibration failed: " .. tostring(cal_err))
        end

        pcall(function() current_tl:DeleteTrack("video", cal_track) end)
        sleep(0.2)

        local current_track_count = current_tl:GetTrackCount("video")
        local track_map = {}
        for i, orig_t in ipairs(orig_tracks) do
            track_map[orig_t] = current_track_count + i
        end

        logAppend(itm.DUPLog,
            ("Placing %d clip(s)  (scale=%.3f)..."):format(#scanned, fps_scale), "info")
        for _ = 1, #orig_tracks do current_tl:AddTrack("video") end
        sleep(0.3)

        local clips_by_track = {}
        for _, clip in ipairs(scanned) do
            local t = track_map[clip.track] or (current_track_count + 1)
            if not clips_by_track[t] then clips_by_track[t] = {} end
            table.insert(clips_by_track[t], clip)
        end
        local target_tracks = {}
        for t in pairs(clips_by_track) do table.insert(target_tracks, t) end
        table.sort(target_tracks)
        for _, t in ipairs(target_tracks) do
            table.sort(clips_by_track[t], function(a, b) return a.start_f < b.start_f end)
        end

        local placed, failed, has_transitions = 0, 0, false

        for _, target_track in ipairs(target_tracks) do
            for _, clip in ipairs(clips_by_track[target_track]) do
                local corrected = math.ceil(clip.duration * fps_scale)
                local ok2, _ = pcall(function()
                    local result = media_pool:AppendToTimeline({
                        { mediaPoolItem = template_item, trackIndex = target_track,
                          recordFrame = clip.start_f, startFrame = 0,
                          endFrame = corrected, mediaType = 1 }
                    })
                    if result and #result > 0 then
                        placed = placed + 1
                        if (clip.transition_in or 0) + (clip.transition_out or 0) > 0 then
                            has_transitions = true
                        end
                    else
                        failed = failed + 1
                    end
                end)
                if not ok2 then
                    failed = failed + 1
                    print("  FAILED: V" .. target_track .. " start=" .. clip.start_f)
                end
            end
        end

        sleep(0.5)

        -- Phase 2: set text and verify
        local text_set, props_copied, duration_ok, duration_off = 0, 0, 0, 0

        for _, target_track in ipairs(target_tracks) do
            for _, clip in ipairs(clips_by_track[target_track]) do
                local new_clip = find_clip_near_frame(current_tl, target_track, clip.start_f, 15)
                if not new_clip then
                    print("  WARN: can't find placed clip V" .. target_track ..
                          " near " .. clip.start_f)
                else
                    local actual_dur = new_clip:GetEnd() - new_clip:GetStart()
                    if math.abs(actual_dur - clip.duration) <= 2 then
                        duration_ok = duration_ok + 1
                    else
                        duration_off = duration_off + 1
                        print("  V" .. target_track .. "@" .. new_clip:GetStart() ..
                              " dur=" .. actual_dur .. "f (wanted " .. clip.duration ..
                              "f, off by " .. (actual_dur - clip.duration) .. "f)")
                    end

                    pcall(function()
                        local cc = new_clip:GetFusionCompCount()
                        if cc > 0 then
                            local comp = new_clip:GetFusionCompByIndex(1)
                            if comp then
                                local tt = comp:GetToolList(false, "TextPlus")
                                if not next_key(tt) then tt = comp:GetToolList(false, "Text3D") end
                                if next_key(tt) then
                                    local skeys = {}
                                    for k in pairs(tt) do table.insert(skeys, k) end
                                    table.sort(skeys, function(a, b) return tostring(a) < tostring(b) end)
                                    for ti, k in ipairs(skeys) do
                                        if clip.texts[ti] then
                                            tt[k]:SetInput("StyledText", clip.texts[ti])
                                        end
                                    end
                                    text_set = text_set + 1
                                end
                            end
                        end
                    end)

                    if next_key(clip.transform) then
                        pcall(function()
                            apply_transform(new_clip, clip.transform)
                            props_copied = props_copied + 1
                        end)
                    end
                end
            end
        end

        local first_new = target_tracks[1] or 0
        local last_new  = target_tracks[#target_tracks] or 0
        local track_info = "V" .. first_new ..
            (first_new ~= last_new and ("-V" .. last_new) or "")

        print("\n  DUPLICATOR SUMMARY")
        print("  Template     : " .. tmpl_name)
        print("  FPS scale    : " .. string.format("%.4f", fps_scale))
        print("  Placed       : " .. placed .. " / " .. #scanned)
        print("  Failed       : " .. failed)
        print("  Duration OK  : " .. duration_ok .. "  |  Off: " .. duration_off)
        print("  Text set     : " .. text_set .. "  |  Transform: " .. props_copied)
        print("  New tracks   : " .. track_info)
        if has_transitions then print("  Transitions detected  -  select new clips and press Ctrl+T") end
        print("  Ctrl+Z to undo if needed.")

        logAppend(itm.DUPLog, "-- Done --", "head")
        local status = ("OK %d placed on %s"):format(placed, track_info)
        if failed       > 0 then status = status .. "   -   " .. failed .. " failed"                  end
        if duration_off > 0 then status = status .. "   -   " .. duration_off .. " duration mismatch" end
        if has_transitions   then status = status .. "   -   transitions detected (Ctrl+T)"           end
        logAppend(itm.DUPLog, status,
                  (failed > 0 or duration_off > 0) and "warn" or "ok")
        logAppend(itm.DUPLog, "Ctrl+Z to undo if needed.", "dim")

        run_dup_scan()
    end

    -- -- Snap Captions ----------------------------------------------

    local function repopulate_snap_tree(query)
        query = query or ""
        itm.SNAP_List:Clear()
        local qt = query:lower()
        for _, nm in ipairs(item_names) do
            if qt == "" or nm:lower():find(qt, 1, true) then
                local row = itm.SNAP_List:NewItem()
                row.Text[0] = nm
                itm.SNAP_List:AddTopLevelItem(row)
            end
        end
    end

    local function refresh_template_lists(log_widget, label)
        local count = refresh_template_cache()
        repopulate_dup_tree(itm.DUP_Search.Text)
        repopulate_snap_tree(itm.SNAP_Search.Text)
        if state.selected_snap_template ~= "" and not item_map[state.selected_snap_template] then
            state.selected_snap_template = ""
            itm.SNAP_Selected.Text = "(none)"
        end
        if state.selected_template_name ~= "" and not item_map[state.selected_template_name] then
            state.selected_template_name = ""
            itm.DUP_Selected.Text = "(none)"
        end
        pcall(function()
            itm.SNAP_Search.PlaceholderText = "filter " .. count .. " template(s)..."
        end)
        pcall(function()
            itm.DUP_Search.PlaceholderText = "filter " .. count .. " template(s)..."
        end)
        if log_widget then
            logAppend(log_widget, ("Refreshed: %d Fusion title template(s) found."):format(count), "ok")
        end
        print("  " .. (label or "Template") .. " refresh: " .. count .. " template(s)")
    end

    win.On.SNAP_Search.TextChanged = function()
        repopulate_snap_tree(itm.SNAP_Search.Text)
    end

    win.On.SNAP_RefreshTemplates.Clicked = function()
        refresh_template_lists(itm.SNAPLog, "Caption Titler template")
    end

    win.On.DUP_RefreshTemplates.Clicked = function()
        refresh_template_lists(itm.DUPLog, "Template Duplicator template")
    end

    win.On.SNAP_List.CurrentItemChanged = function()
        local item = itm.SNAP_List:CurrentItem()
        if item then
            state.selected_snap_template = item.Text[0]
            itm.SNAP_Selected.Text = item.Text[0]
        end
    end

    win.On.SNAP_ClearLog.Clicked = function()
        logClear(itm.SNAPLog)
        itm.SNAP_Preview.PlainText = ""
    end

    win.On.SNAP_Browse.Clicked = function()
        local path = fusion:RequestFile()
        if path and path ~= "" then
            state.snap_srt_path = path
            state.snap_use_timeline = false
            state.snap_plan = {}
            state.snap_timing_label = ""
            state.snap_plan_source = ""
            itm.SNAP_FileLabel.Text = truncate_path(path, 55)
            local filename = path:match("[^/\\]+$") or path
            itm.SNAP_Preview.PlainText = "Source: " .. filename .. "\n\nClick Preview to check timing before creating clips."
            logAppend(itm.SNAPLog, "Selected SRT: " .. filename, "info")
        end
    end

    local function refresh_snap_preview(from_timeline)
        logClear(itm.SNAPLog)
        local current_tl = project:GetCurrentTimeline()
        if not current_tl then
            logAppend(itm.SNAPLog, "No timeline active.", "err"); return false
        end

        local cur_fps   = tonumber(current_tl:GetSetting("timelineFrameRate")) or fps
        local cur_start = current_tl:GetStartFrame()
        local plan, timing_label

        if from_timeline then
            state.snap_srt_path = ""
            local scan_info = nil
            plan, scan_info = scan_timeline_subtitle_items(current_tl)
            timing_label = "Timeline subtitle track"
            itm.SNAP_FileLabel.Text = "Timeline subtitle track"
            if #plan == 0 then
                scan_info = scan_info or {}
                local tracks = scan_info.track_count or 0
                local items = scan_info.item_count or 0
                local disabled = scan_info.disabled_tracks or 0
                local msg
                if tracks == 0 then
                    msg = "No subtitle tracks found on this timeline."
                elseif items == 0 then
                    msg = ("Found %d subtitle track(s), but no subtitle clips."):format(tracks)
                    if disabled > 0 then msg = msg .. (" Disabled tracks: %d."):format(disabled) end
                else
                    msg = ("Found %d subtitle clip(s), but Resolve did not expose readable text."):format(items)
                end
                logAppend(itm.SNAPLog, msg, "warn")
                logAppend(itm.SNAPLog,
                    "Open the console/log and send the subtitle property dump if this happens; the reader now scans all exposed text/caption fields.",
                    "warn")
                itm.SNAP_Preview.PlainText = msg .. "\n\n" ..
                    "Timeline subtitle text is not readable through this Resolve API build."
                return false
            end
        else
            if state.snap_srt_path == "" then
                logAppend(itm.SNAPLog, "No SRT file selected.", "err"); return false
            end
            local entries, err = parse_srt(state.snap_srt_path)
            if not entries then
                logAppend(itm.SNAPLog, "Error reading SRT: " .. (err or ""), "err"); return false
            end
            if #entries == 0 then
                logAppend(itm.SNAPLog, "No entries found in SRT file.", "err"); return false
            end
            plan, timing_label = build_caption_plan(
                entries, cur_start, cur_fps, itm.SNAP_TimingMode.CurrentIndex
            )
        end

        state.snap_plan = plan
        state.snap_timing_label = timing_label
        state.snap_plan_source = from_timeline and "timeline" or "srt"

        local source_name = from_timeline and "Timeline subtitle track" or
            (state.snap_srt_path:match("[^/\\]+$") or state.snap_srt_path)

        local lines = {}
        table.insert(lines, ("Timeline: %s  |  FPS: %.3f  |  Start: %s"):format(
            current_tl:GetName(), cur_fps, frames_to_timecode(cur_start, cur_fps)))
        table.insert(lines, "Source: " .. source_name)
        table.insert(lines, "Timing: " .. timing_label)
        table.insert(lines, "Captions: " .. #plan)
        table.insert(lines, "")
        table.insert(lines, string.format("%-4s %-13s %-13s %-8s %s", "#", "Start", "End", "Dur", "Text"))
        table.insert(lines, string.rep("-", 76))

        local max_show = math.min(#plan, 60)
        for i = 1, max_show do
            local cap = plan[i]
            table.insert(lines, string.format("%3d  %s  %s  %5.1fs  %s",
                cap.index,
                frames_to_timecode(cap.start_f, cur_fps),
                frames_to_timecode(cap.finish, cur_fps),
                cap.duration / cur_fps,
                show_breaks(cap.text, 32)))
        end
        if #plan > max_show then
            table.insert(lines, ("... %d more captions"):format(#plan - max_show))
        end
        itm.SNAP_Preview.PlainText = table.concat(lines, "\n")
        logAppend(itm.SNAPLog,
            ("Preview ready: %d caption clip(s) from %s"):format(#plan, source_name), "ok")
        return true
    end

    win.On.SNAP_PreviewBtn.Clicked = function()
        -- Preview the source the user picked last: the timeline subtitle track or an SRT file.
        refresh_snap_preview(state.snap_use_timeline == true)
    end

    win.On.SNAP_FromTimeline.Clicked = function()
        state.snap_use_timeline = true
        refresh_snap_preview(true)
    end

    win.On.SNAP_Create.Clicked = function()
        if state.snap_use_timeline then
            if #state.snap_plan == 0 and not refresh_snap_preview(true) then return end
        elseif state.snap_srt_path ~= "" then
            if not refresh_snap_preview(false) then return end
        elseif #state.snap_plan == 0 then
            if not refresh_snap_preview(false) then return end
        end
        local tmpl_name = state.selected_snap_template
        if tmpl_name == "" then
            logAppend(itm.SNAPLog, "No template selected from the list.", "err"); return
        end
        local template_item = item_map[tmpl_name]
        if not template_item then
            logAppend(itm.SNAPLog, "Template not found in media pool.", "err"); return
        end
        local current_tl = project:GetCurrentTimeline()
        if not current_tl then
            logAppend(itm.SNAPLog, "No timeline active.", "err"); return
        end

        local cur_fps = tonumber(current_tl:GetSetting("timelineFrameRate")) or fps
        local plan = state.snap_plan

        logAppend(itm.SNAPLog, "Adding video track for caption clips...", "info")
        current_tl:AddTrack("video")
        sleep(0.25)
        local target_track = current_tl:GetTrackCount("video")

        local template_fps, template_fps_detected = media_pool_item_fps(template_item, cur_fps)
        local fps_scale = 1.0
        local append_duration_pad = 0
        if template_fps_detected then
            logAppend(itm.SNAPLog,
                ("Template FPS: %.6g   -   timeline FPS: %.6g"):format(template_fps, snap_fps_value(cur_fps)),
                math.abs(template_fps - snap_fps_value(cur_fps)) < 0.0001 and "dim" or "info")
        else
            logAppend(itm.SNAPLog, "Template FPS not reported; using calibration fallback...", "warn")
        end
        local cal_track = nil
        if not template_fps_detected then
            local ok_cal, cal_err = pcall(function()
                current_tl:AddTrack("video")
                sleep(0.15)
                cal_track = current_tl:GetTrackCount("video")
                local test_start = plan[1].start_f
                local test_dur = 1000
                media_pool:AppendToTimeline({
                    { mediaPoolItem = template_item, trackIndex = cal_track,
                      recordFrame = test_start, startFrame = 0, endFrame = test_dur, mediaType = 1 }
                })
                sleep(0.25)
                local cal_clip = find_clip_near_frame(current_tl, cal_track, test_start, 15)
                if cal_clip then
                    local actual = cal_clip:GetEnd() - cal_clip:GetStart()
                    if actual > 0 and math.abs(actual - test_dur) <= 2 then
                        append_duration_pad = test_dur - actual
                    elseif actual > 0 and math.abs(actual - test_dur) > 2 then
                        fps_scale = test_dur / actual
                    end
                end
            end)
            if cal_track then pcall(function() current_tl:DeleteTrack("video", cal_track) end) end
            if not ok_cal then
                logAppend(itm.SNAPLog, "Calibration failed: " .. tostring(cal_err), "warn")
            else
                logAppend(itm.SNAPLog,
                    ("Duration scale: %.4f   -   pad: %+d frame(s)"):format(fps_scale, append_duration_pad),
                    "dim")
            end
            sleep(0.2)
        end

        local placed, failed = 0, 0
        local text_set, duration_ok, duration_off = 0, 0, 0
        local placed_clips = {}
        local text_done = {}
        logAppend(itm.SNAPLog,
            ("Placing %d caption clip(s) on V%d..."):format(#plan, target_track), "info")

        for _, cap in ipairs(plan) do
            local corrected
            if template_fps_detected then
                corrected = timeline_frames_to_source_frames(cap.duration, cur_fps, template_fps)
            else
                corrected = math.max(1, math.ceil(cap.duration * fps_scale) + append_duration_pad)
            end
            local ok, err2 = pcall(function()
                local result = media_pool:AppendToTimeline({
                    { mediaPoolItem = template_item, trackIndex = target_track,
                      recordFrame = cap.start_f, startFrame = 0,
                      endFrame = corrected, mediaType = 1 }
                })
                if result and #result > 0 then
                    placed = placed + 1
                    placed_clips[cap.index] = result[1]
                    local new_clip = result[1]
                    if new_clip:GetStart() ~= cap.start_f then
                        pcall(function() new_clip:SetStart(cap.start_f) end)
                    end
                    if new_clip:GetEnd() ~= cap.finish then
                        pcall(function() new_clip:SetEnd(cap.finish) end)
                    end
                    if set_text_on_timeline_item(new_clip, cap.text, itm.SNAP_MultiEnabled.Checked) then
                        text_set = text_set + 1
                        text_done[cap.index] = true
                    end
                else
                    failed = failed + 1
                    print("  SNAP FAILED append #" .. cap.index .. " start=" .. cap.start_f)
                end
            end)
            if not ok then
                failed = failed + 1
                print("  SNAP FAILED #" .. cap.index .. ": " .. tostring(err2))
            end
        end

        sleep(0.5)

        for _, cap in ipairs(plan) do
            local new_clip = placed_clips[cap.index] or find_clip_near_frame(current_tl, target_track, cap.start_f, 1)
            if new_clip then
                if new_clip:GetStart() ~= cap.start_f then
                    pcall(function() new_clip:SetStart(cap.start_f) end)
                end
                if new_clip:GetEnd() ~= cap.finish then
                    pcall(function() new_clip:SetEnd(cap.finish) end)
                end
                if (not text_done[cap.index]) and set_text_on_timeline_item(new_clip, cap.text, itm.SNAP_MultiEnabled.Checked) then
                    text_set = text_set + 1
                    text_done[cap.index] = true
                end
                local actual_dur = new_clip:GetEnd() - new_clip:GetStart()
                if math.abs(actual_dur - cap.duration) <= 1 then
                    duration_ok = duration_ok + 1
                else
                    duration_off = duration_off + 1
                    print("  SNAP duration mismatch #" .. cap.index ..
                          " actual=" .. actual_dur .. " wanted=" .. cap.duration)
                end
            end
        end

        print("\n  SNAP CAPTIONS SUMMARY")
        print("  Template    : " .. tmpl_name)
        print("  Timing      : " .. state.snap_timing_label)
        print("  Track       : V" .. target_track)
        print("  Placed      : " .. placed .. " / " .. #plan)
        print("  Text set    : " .. text_set)
        print("  Duration OK : " .. duration_ok .. "  |  Off: " .. duration_off)
        print("  Ctrl+Z to undo if needed.")

        logAppend(itm.SNAPLog, "-- Done --", "head")
        local status = ("OK %d clips on V%d   -   text set %d"):format(placed, target_track, text_set)
        if failed > 0 then status = status .. "   -   " .. failed .. " failed" end
        if duration_off > 0 then status = status .. "   -   " .. duration_off .. " duration mismatch" end
        logAppend(itm.SNAPLog, status,
            (failed > 0 or duration_off > 0) and "warn" or "ok")
        logAppend(itm.SNAPLog, "Ctrl+Z to undo if needed.", "dim")
    end

    -- -- Subtitle Creator ------------------------------------------

    win.On.SUB_BrowseFolder.Clicked = function()
        local chosen = fusion:RequestDir(state.sub_output_folder ~= "" and state.sub_output_folder or nil)
        if chosen and chosen ~= "" then
            state.sub_output_folder = chosen
            itm.SUB_OutputFolder.Text = truncate_path(chosen, 55)
            logAppend(itm.SUBLog, "Export folder: " .. chosen, "info")
        end
    end

    win.On.SUB_ClearLog.Clicked = function()
        logClear(itm.SUBLog)
        itm.SUB_Preview.PlainText = ""
    end

    win.On.SUB_Scan.Clicked = function()
        logClear(itm.SUBLog)
        local current_tl = project:GetCurrentTimeline()
        if not current_tl then
            logAppend(itm.SUBLog, "No timeline active.", "err"); return
        end
        local max_track = itm.SUB_MaxTrack.Value
        logAppend(itm.SUBLog, "Scanning V1-V" .. max_track .. "...", "info")

        local raw_clips = scan_text_clips_for_subtitles(current_tl, max_track)
        if #raw_clips == 0 then
            itm.SUB_Preview.PlainText = "No Text+ clips found on any video track."
            logAppend(itm.SUBLog, "No clips found.", "warn")
            state.scanned_subs = {}
            return
        end

        local subs = resolve_overlaps(raw_clips)
        state.scanned_subs = subs

        if #subs == 0 then
            itm.SUB_Preview.PlainText = "All clips had empty text content."
            logAppend(itm.SUBLog, "No subtitle content found.", "warn")
            return
        end

        local cur_fps = tonumber(current_tl:GetSetting("timelineFrameRate")) or fps

        local lines = {}
        table.insert(lines, "Found " .. #raw_clips .. " Text+ clip(s)  ->  " .. #subs .. " subtitle(s):\n")
        table.insert(lines, string.format("%-4s %-13s %-13s %-8s %s", "#", "Start", "End", "Dur", "Text"))
        table.insert(lines, string.rep("-", 72))

        local trimmed_count = 0
        for i, sub in ipairs(subs) do
            local tc_s = frames_to_timecode(sub.start_f, cur_fps)
            local tc_e = frames_to_timecode(sub.finish,  cur_fps)
            local dur  = (sub.finish - sub.start_f) / cur_fps
            local txt  = short_str(sub.text, 30)
            local marker = sub.trimmed and "  *trimmed" or ""
            if sub.trimmed then trimmed_count = trimmed_count + 1 end
            table.insert(lines, string.format("%3d  %s  %s  %5.1fs  %s%s",
                i, tc_s, tc_e, dur, txt, marker))
        end
        table.insert(lines, "")
        table.insert(lines, "Total: " .. #subs .. " subtitle(s)")
        if trimmed_count > 0 then
            table.insert(lines, "Overlaps resolved: " .. trimmed_count .. "  (* = trimmed to next start)")
        end
        local track_set = {}
        for _, c in ipairs(raw_clips) do track_set[c.track] = true end
        local track_nums = {}
        for k in pairs(track_set) do table.insert(track_nums, k) end
        table.sort(track_nums)
        local track_strs = {}
        for _, t in ipairs(track_nums) do table.insert(track_strs, "V" .. t) end
        table.insert(lines, "Source tracks: " .. table.concat(track_strs, ", "))

        itm.SUB_Preview.PlainText = table.concat(lines, "\n")
        logAppend(itm.SUBLog,
            ("Found %d subtitle(s)  -  click Create Subtitles to generate."):format(#subs), "ok")
        print("\n  Scanned: " .. #raw_clips .. " clips  ->  " .. #subs .. " subtitles " ..
              "(" .. trimmed_count .. " overlaps trimmed)")
    end

    win.On.SUB_Create.Clicked = function()
        local subs = state.scanned_subs
        if #subs == 0 then
            logAppend(itm.SUBLog, "Click Scan first to read Text+ clips.", "warn"); return
        end
        local current_tl = project:GetCurrentTimeline()
        if not current_tl then
            logAppend(itm.SUBLog, "No timeline active.", "err"); return
        end

        local cur_fps = tonumber(current_tl:GetSetting("timelineFrameRate")) or fps

        logAppend(itm.SUBLog, "Adding subtitle track...", "info")
        current_tl:AddTrack("subtitle")
        sleep(0.3)
        local target_track = current_tl:GetTrackCount("subtitle")

        print("\n  Creating " .. #subs .. " subtitle(s) on subtitle track " .. target_track .. "...")
        local created, failed = 0, 0

        for i, sub in ipairs(subs) do
            local ok, err2 = pcall(function()
                local success = current_tl:InsertSubtitleAtFrame(
                    sub.start_f, sub.finish - sub.start_f, sub.text
                )
                if success then created = created + 1
                else
                    failed = failed + 1
                    print("  [" .. i .. "] FAILED: start=" .. sub.start_f)
                end
            end)
            if not ok then
                failed = failed + 1
                print("  [" .. i .. "] FAILED: " .. tostring(err2))
            end
        end

        if failed > 0 and created == 0 then
            logAppend(itm.SUBLog, "Trying SRT file import method...", "info")
            print("  Attempting SRT fallback...")
            created, failed = try_srt_import(
                current_tl, subs, cur_fps,
                function(msg) logAppend(itm.SUBLog, msg, "info") end
            )
        end

        print("\n  SUBTITLE SUMMARY: created=" .. created .. ", failed=" .. failed ..
              ", track=" .. target_track)
        print("  Ctrl+Z to undo if needed.")

        if created > 0 then
            logAppend(itm.SUBLog,
                ("OK %d subtitle(s) created on subtitle track %d"):format(created, target_track),
                failed > 0 and "warn" or "ok")
            if failed > 0 then logAppend(itm.SUBLog, failed .. " failed.", "warn") end
            logAppend(itm.SUBLog, "Ctrl+Z to undo if needed.", "dim")
        else
            logAppend(itm.SUBLog,
                "Failed  -  " .. failed .. " error(s). Check Console for details.", "err")
        end
    end

    -- -- Show window -----------------------------------------------
    print("\n  Window open  -  run via Workspace > Scripts > Resolve Text Toolkit")
    -- Override Subtitle Creator with the SRT-export/import pipeline.
    win.On.SUB_Create.Clicked = function()
        local subs = state.scanned_subs
        if #subs == 0 then
            logAppend(itm.SUBLog, "Click Scan first to read Text+ clips.", "warn"); return
        end
        local current_tl = project:GetCurrentTimeline()
        if not current_tl then
            logAppend(itm.SUBLog, "No timeline active.", "err"); return
        end

        local cur_fps = tonumber(current_tl:GetSetting("timelineFrameRate")) or fps
        local mode_index = itm.SUB_OutputMode.CurrentIndex
        local do_timeline = mode_index ~= 2
        local do_export = mode_index ~= 1

        logAppend(itm.SUBLog, "Writing SRT file...", "info")
        local write_folder = state.sub_output_folder
        local srt_path, write_err = write_subtitles_srt_file(current_tl, subs, cur_fps, write_folder)
        if not srt_path then
            logAppend(itm.SUBLog, "Failed to write SRT: " .. (write_err or ""), "err")
            return
        end
        state.sub_last_srt_path = srt_path
        if do_export then
            logAppend(itm.SUBLog, "SRT exported: " .. srt_path, "ok")
        else
            logAppend(itm.SUBLog, "Temporary SRT prepared for timeline import.", "dim")
        end

        if not do_timeline then
            print("\n  SUBTITLE SUMMARY: exported only")
            print("  SRT: " .. srt_path)
            logAppend(itm.SUBLog, "Export only complete.", "ok")
            return
        end

        logAppend(itm.SUBLog, "Importing SRT to subtitle track...", "info")
        print("\n  Creating " .. #subs .. " subtitle(s) via SRT import...")
        local created, failed, target_track, method = import_srt_to_subtitle_track(
            current_tl, media_pool, srt_path, #subs,
            function(msg, level) logAppend(itm.SUBLog, msg, level or "info") end
        )

        if created == 0 then
            logAppend(itm.SUBLog,
                "SRT import did not place subtitles. Direct insert is unavailable in this Resolve API build.",
                "warn")
            method = method or "failed"
        end

        print("\n  SUBTITLE SUMMARY: created=" .. created .. ", failed=" .. failed ..
              ", track=" .. tostring(target_track) .. ", method=" .. tostring(method))
        print("  SRT: " .. srt_path)
        print("  Ctrl+Z to undo if needed.")

        if created > 0 then
            logAppend(itm.SUBLog,
                ("Created %d subtitle(s) on subtitle track %d"):format(created, target_track or 0),
                failed > 0 and "warn" or "ok")
            logAppend(itm.SUBLog, "Method: " .. tostring(method), "dim")
            if failed > 0 then logAppend(itm.SUBLog, failed .. " failed.", "warn") end
            logAppend(itm.SUBLog, "Ctrl+Z to undo if needed.", "dim")
        else
            if do_export then
                logAppend(itm.SUBLog,
                    "Failed to place subtitles. SRT was still exported: " .. srt_path, "err")
            else
                logAppend(itm.SUBLog,
                    "Failed to place subtitles. No SRT was kept because output mode is timeline only.", "err")
            end
        end

        if not do_export then
            logAppend(itm.SUBLog, "Helper SRT kept for Caption Titler line-break preservation: " .. srt_path, "dim")
        end
    end

    win:Show()
    disp:RunLoop()
    win:Hide()
    print("  Window closed.")
end

-- Entry point
main()
