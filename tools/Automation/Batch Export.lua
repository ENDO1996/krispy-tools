-- Krispy Tools product: batch-export
-- Release: 2026.2
-- Source SHA-256: 27b0265020d144dd32970b34e58c7623df791f7ef93d738b49e6b6543fbabf3a
--[[
Batch Export  (Lua)  -  Krispy Tools
===================================
Queue many timelines for render with one preset and one output folder.

INSTALLATION
Windows: %APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility\
macOS:   ~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/
Run via: Workspace > Scripts > Utility > Batch Export

Requires DaVinci Resolve Studio 19.1 or newer.
Also part of Resolve Automator, which has all five tools in one window.
--]]

-- Build switch. nil = the full Resolve Automator with all five tabs.
-- The single-tool releases (Timeline Renamer, Marker Screenshots, Marker Insert,
-- Track Overlay, Batch Export) are generated from this file with ONLY_TAB = 1..5.
local ONLY_TAB = 5

-- ============================================================
--  UTILITIES
-- ============================================================

local IS_WINDOWS = (os.getenv("SYSTEMROOT") ~= nil)

-- CPU-spin sleep  -  no external process, no CMD window, cross-platform
local function sleep(n)
    local deadline = os.clock() + n
    while os.clock() < deadline do end
end

-- Create a directory without spawning a visible shell window.
-- Uses bmd.createdir() if available (Fusion built-in), otherwise
-- falls back to PowerShell (hidden) on Windows or mkdir -p on Mac/Linux.
local function ensureDir(path)
    if pcall(function() bmd.createdir(path) end) then return end
    if IS_WINDOWS then
        os.execute('powershell -WindowStyle Hidden -NonInteractive -Command '
            .. '"New-Item -ItemType Directory -Force -Path \'' .. path .. '\' | Out-Null"')
    else
        os.execute('mkdir -p "' .. path .. '"')
    end
end

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function safeName(s)
    return trim(s:gsub('[<>:"/\\|?*%z%c]', "_"))
end

local function tableLen(t)
    local n = 0; for _ in pairs(t) do n = n + 1 end; return n
end

local function sortedNumericKeys(t)
    local keys = {}
    for k in pairs(t) do table.insert(keys, tonumber(k) or k) end
    table.sort(keys)
    return keys
end

local function framesToTC(frames, fps)
    frames = math.floor(frames)
    local f = frames % fps
    local s = math.floor(frames / fps) % 60
    local m = math.floor(frames / (fps * 60)) % 60
    local h = math.floor(frames / (fps * 3600))
    return string.format("%02d:%02d:%02d:%02d", h, m, s, f)
end

local function tcToFrames(tc, fps)
    local h, m, s, f = tc:match("(%d+):(%d+):(%d+):(%d+)")
    if not h then return 0 end
    return math.floor(tonumber(f) + tonumber(s)*fps + tonumber(m)*60*fps + tonumber(h)*3600*fps)
end

local function getTimelineStartFrame(timeline, fps)
    local ok, n = pcall(function() return timeline:GetStartFrame() end)
    if ok and type(n) == "number" then return n end
    local tcStr = timeline:GetSetting("timelineStartTimecode") or "00:00:00:00"
    return tcToFrames(tcStr, fps)
end

local function getTimelineFPS(timeline)
    local ok, r = pcall(function()
        return tonumber(timeline:GetSetting("timelineFrameRate")) or 24.0
    end)
    return (ok and r) or 24.0
end

-- ============================================================
--  CONSTANTS
-- ============================================================

local MARKER_COLORS = {
    "Blue","Cyan","Green","Yellow","Red","Pink",
    "Purple","Fuchsia","Rose","Lavender","Sky","Mint",
    "Lemon","Sand","Cocoa","Cream"
}

local AUDIO_EXTS = {
    [".mp3"]=true,[".wav"]=true,[".aac"]=true,[".aif"]=true,
    [".aiff"]=true,[".flac"]=true,[".m4a"]=true
}
local VIDEO_EXTS = {
    [".mp4"]=true,[".mov"]=true,[".mxf"]=true,[".avi"]=true,
    [".mkv"]=true,[".r3d"]=true,[".braw"]=true,[".m4v"]=true,
    [".wmv"]=true,[".mpg"]=true,[".mpeg"]=true,[".webm"]=true
}
local IMAGE_EXTS = {
    [".jpg"]=true,[".jpeg"]=true,[".png"]=true,[".gif"]=true,
    [".bmp"]=true,[".tiff"]=true,[".tif"]=true,[".webp"]=true,
    [".psd"]=true,[".dpx"]=true,[".exr"]=true,[".tga"]=true,
    [".heic"]=true,[".heif"]=true
}

-- ============================================================
--  UI THEME
-- ============================================================

local C = {
    bg = "#151515", panel = "#191919", bg_frame = "#191919",
    bg_input = "#202020", input = "#202020", bg_log = "#181818",
    bg_btn = "#2b2b2b", btn = "#2b2b2b", btn2 = "#252525",
    accent = "#4a9eff", accent2 = "#75d5ff", accent_hi = "#75d5ff",
    fg = "#f4f4f4", fg_dim = "#a2a2a2", dim = "#a2a2a2",
    fg_on_acc = "#101010", ok = "#56d364", warn = "#ffcc66",
    err = "#ff6b6b", border = "#535353", border_hot = "#75d5ff",
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
    spin_fixed = ("QSpinBox { background-color:%s; color:%s; border:1px solid %s; border-radius:6px; padding:5px 28px 5px 10px; font-size:9pt; font-family:'Segoe UI'; selection-background-color:%s; } QSpinBox:focus { border-color:%s; } QSpinBox::up-button, QSpinBox::down-button { width:22px; border-left:1px solid %s; background-color:#2a2a2a; }"):format(C.bg_input, C.fg, C.border, C.accent, C.border_hot, C.border),
    multiline = ("QTextEdit { background-color:%s; color:%s; border:1px solid %s; border-radius:7px; padding:8px; selection-background-color:%s; font-family:'Segoe UI','Helvetica Neue',sans-serif; font-size:9pt; } QTextEdit:focus { border-color:%s; }"):format(C.bg_input, C.fg, C.border, C.accent, C.border_hot),
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

-- ============================================================
--  LOG HELPERS  (pass the widget element directly, e.g. itm.TLLog)
-- ============================================================

local function logAppend(w, msg, tag)
    local colors = {
        info=C.fg, ok=C.ok, warn=C.warn, err=C.err, head=C.accent, dim=C.fg_dim
    }
    local color = colors[tag] or C.fg
    local safe = msg:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")
    safe = safe:gsub("\r?\n", "<br>")
    w.HTML = w.HTML .. ('<span style="color:%s">%s</span><br>'):format(color, safe)
    -- Keep the newest line in view.
    pcall(function() w:MoveCursor("End", "MoveAnchor") end)
end

local function logClear(w)
    w.HTML = ""
end

-- ============================================================
--  TIMELINE RENAMER  -  LOGIC
-- ============================================================

local function getAllTimelines(project)
    local result = {}
    local n = project:GetTimelineCount()
    for i = 1, n do
        local tl = project:GetTimelineByIndex(i)
        if tl then table.insert(result, {name=tl:GetName(), timeline=tl}) end
    end
    table.sort(result, function(a, b)
        return tostring(a.name):lower() < tostring(b.name):lower()
    end)
    return result
end

-- Parse replacement entries: commas and line breaks both separate values.
local function parseReplacements(text)
    local result = {}
    local normalized = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    for entry in (normalized .. "\n"):gmatch("([^,\n]*)[,\n]") do
        entry = trim(entry)
        if entry ~= "" then table.insert(result, entry) end
    end
    return result
end

local function doTimelineOperations(project, tlInfos, findStr, replacements, duplicateMode, logFn)
    if findStr == "" then
        if logFn then logFn("Find text is empty.", "err") end
        return {done=0, errors=1}
    end
    if #replacements == 0 then
        if logFn then logFn("No replacement text provided.", "err") end
        return {done=0, errors=1}
    end

    local done, errors = 0, 0

    for _, info in ipairs(tlInfos) do
        local tl   = info.timeline
        local name = tl:GetName()

        if not name:find(findStr, 1, true) then
            if logFn then logFn("  Skipped (no match): " .. name, "dim") end
        elseif duplicateMode then
            for _, rep in ipairs(replacements) do
                local newName = name:gsub(findStr:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"), rep, 1)
                local ok, dup = pcall(function() return tl:DuplicateTimeline(newName) end)
                if ok and dup then
                    if logFn then logFn("  OK Duplicated  ->  " .. newName, "ok") end
                    done = done + 1
                else
                    if logFn then logFn("  ERROR Failed: " .. name .. "  ->  " .. newName, "err") end
                    errors = errors + 1
                end
            end
        else
            -- Rename in place using first replacement only
            local newName = name:gsub(findStr:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"), replacements[1], 1)
            local ok2, _ = pcall(function() return tl:SetName(newName) end)
            if ok2 then
                if logFn then logFn("  OK Renamed  ->  " .. newName, "ok") end
                done = done + 1
            else
                if logFn then logFn("  ERROR Failed rename: " .. name, "err") end
                errors = errors + 1
            end
        end
    end
    return {done=done, errors=errors}
end

-- ============================================================
--  DRX SIDECAR CLEANUP  (shared by Screenshots and Quick Screenshot)
-- ============================================================

-- Deletes every "prefix*.drx" file Resolve creates alongside an exported JPEG.
-- Three-tier approach  -  no subprocess on macOS; brief CMD flash only as last resort on Windows.
local function cleanDRX(outputDir, prefix)
    local sep2 = IS_WINDOWS and "\\" or "/"
    local base  = outputDir .. sep2 .. prefix
    local done  = false

    -- Tier 1: lfs.dir() scan  -  finds any suffix variant without spawning a process
    local ok_lfs, lfs = pcall(require, "lfs")
    if ok_lfs and lfs then
        pcall(function()
            for fname in lfs.dir(outputDir) do
                if fname:sub(1, #prefix) == prefix
                   and fname:lower():sub(-4) == ".drx" then
                    os.remove(outputDir .. sep2 .. fname)
                    done = true
                end
            end
        end)
    end

    -- Tier 2: io.open probe  -  pure Lua existence check on every realistic name variant
    if not done then
        for _, sfx in ipairs({
            "", "1","2","3","4","5",
            "_1","_2","_3","_4","_5",
            "01","02","03","04","05",
            "_01","_02","_03","_04","_05",
            "001","002","003",
            "_001","_002","_003",
            "0001","_0001",
        }) do
            local p = base .. sfx .. ".drx"
            local fh = io.open(p, "rb")
            if fh then
                fh:close()
                os.remove(p)
                done = true
            end
        end
    end

    -- Tier 3: OS shell fallback  -  rm is completely silent on macOS;
    --          del may show a brief CMD flash on Windows (acceptable per user)
    if not done then
        if IS_WINDOWS then
            os.execute('cmd /c del /F /Q "' .. base .. '*.drx" 2>nul')
        else
            os.execute('rm -f "' .. base .. '"*.drx 2>/dev/null')
        end
    end
end

-- ============================================================
--  MARKER SCREENSHOTS  -  LOGIC
-- ============================================================

-- Resolve's ExportStills adds the still label to the file name (for example
-- "prefix_1.1.1.jpg"). Find that file and give it the name the user expects.
local function finalizeStill(outputDir, prefix, finalBase)
    local sep2 = IS_WINDOWS and "\\" or "/"
    local found = nil
    local ok_lfs, lfs = pcall(require, "lfs")
    if ok_lfs and lfs then
        pcall(function()
            for fname in lfs.dir(outputDir) do
                if fname:sub(1, #prefix) == prefix and fname:lower():sub(-4) == ".jpg" then found = fname end
            end
        end)
    end
    if not found then
        local candidates = { "" }
        for a = 1, 4 do for b = 1, 4 do for c = 1, 4 do
            table.insert(candidates, ("_%d.%d.%d"):format(a, b, c))
        end end end
        for _, sfx in ipairs({"_1", "1", "_01", "_001"}) do table.insert(candidates, sfx) end
        for _, sfx in ipairs(candidates) do
            local fh = io.open(outputDir .. sep2 .. prefix .. sfx .. ".jpg", "rb")
            if fh then fh:close(); found = prefix .. sfx .. ".jpg"; break end
        end
    end
    if not found then return nil end
    local target = finalBase .. ".jpg"
    local n = 2
    while true do
        local fh = io.open(outputDir .. sep2 .. target, "rb")
        if not fh or target == found then if fh then fh:close() end break end
        fh:close()
        target = ("%s (%d).jpg"):format(finalBase, n); n = n + 1
    end
    if target ~= found then
        local ok = os.rename(outputDir .. sep2 .. found, outputDir .. sep2 .. target)
        if not ok then return found end
    end
    return target
end

local function doMarkerScreenshots(resolve, project, timeline, fps, markerColor, outputDir, logFn)
    local function log(m, t) if logFn then logFn(m, t) end end

    -- Get markers
    local ok1, allMarkers = pcall(function() return timeline:GetMarkers() end)
    if not ok1 or not allMarkers then
        return {success=false, message="GetMarkers() failed"}
    end

    local targets = {}
    for fid, info in pairs(allMarkers) do
        if (info["color"] or ""):lower() == markerColor:lower() then
            targets[fid] = info
        end
    end
    if tableLen(targets) == 0 then
        return {success=false, message="No " .. markerColor .. " markers found."}
    end
    log("Found " .. tableLen(targets) .. " " .. markerColor .. " marker(s).", "ok")

    -- Ensure output dir exists (no CMD window)
    ensureDir(outputDir)

    -- Switch to Color page
    local ok2, _ = pcall(function() resolve:OpenPage("color") end)
    sleep(0.8)

    -- Get gallery
    local gallery = project:GetGallery()
    if not gallery then
        resolve:OpenPage("edit")
        return {success=false, message="Could not access Gallery."}
    end
    local album = gallery:GetCurrentStillAlbum()
    if not album then
        resolve:OpenPage("edit")
        return {success=false, message="No current still album."}
    end

    local startFrame = getTimelineStartFrame(timeline, fps)
    local tlName = safeName(timeline:GetName())
    local done, errors = 0, 0
    local index = 0

    for _, fid in ipairs(sortedNumericKeys(targets)) do
        local info     = targets[fid]
        local absFrame = startFrame + fid
        local tcStr    = framesToTC(absFrame, fps)
        local mName    = trim(info["name"] or "") ~= "" and info["name"] or "(no name)"
        index = index + 1
        log("  " .. tcStr .. "   -   " .. mName)

        -- Seek to frame
        local ok3, _ = pcall(function()
            timeline:SetCurrentTimecode(tcStr)
        end)
        sleep(0.15)

        -- Grab still
        local ok4, still = pcall(function() return timeline:GrabStill() end)
        if not ok4 or not still then
            log("    ERROR GrabStill failed", "err"); errors = errors + 1
        else
            local prefix = tlName .. "_" .. tcStr:gsub(":", "-")
            local ok5, _ = pcall(function()
                album:ExportStills({still}, outputDir, prefix, "jpg")
            end)
            sleep(0.5)
            cleanDRX(outputDir, prefix)
            -- Clean up the still from gallery
            pcall(function() album:DeleteStills({still}) end)
            if ok5 then
                local base = trim(info["name"] or "") ~= ""
                    and ("%02d %s"):format(index, safeName(info["name"]))
                    or ("%02d %s %s"):format(index, tlName, tcStr:gsub(":", "-"))
                local saved = finalizeStill(outputDir, prefix, base) or (prefix .. ".jpg")
                log("    OK " .. saved, "ok"); done = done + 1
            else
                log("    ERROR ExportStills failed", "err"); errors = errors + 1
            end
        end
    end

    resolve:OpenPage("edit")
    local msg = ("Screenshots: %d / %d"):format(done, tableLen(targets))
    if errors > 0 then msg = msg .. ("  (%d errors)"):format(errors) end
    return {success=true, done=done, errors=errors, message=msg}
end

-- ============================================================
--  MARKER INSERT  -  LOGIC
-- ============================================================

local function getFileExt(name)
    return (name:match("%.([^%.]+)$") or ""):lower()
end

local function listPoolClipsByMode(mediaPool, mode)
    local results = {}
    local seen = {}

    local function scanFolder(folder)
        if not folder then return end
        local clips = {}
        pcall(function() clips = folder:GetClipList() or {} end)
        for _, clip in pairs(clips) do
            local name, ctype, fpath = "", "", ""
            pcall(function() name  = clip:GetName() or "" end)
            pcall(function() ctype = (clip:GetClipProperty("Type") or ""):lower() end)
            pcall(function() fpath = (clip:GetClipProperty("File Path") or ""):lower() end)
            name = trim(name)
            if name ~= "" and not seen[name] then
                local ext = "." .. getFileExt(fpath)
                local include = false

                if mode == "audio" then
                    include = AUDIO_EXTS[ext] or (ctype == "audio")
                elseif mode == "video" then
                    include = VIDEO_EXTS[ext] or (fpath ~= "" and (ctype == "video" or ctype == "video + audio"))
                elseif mode == "graphics" then
                    include = IMAGE_EXTS[ext] or (ctype == "still" or ctype == "image")
                elseif mode == "adjustment" then
                    local nl = name:lower()
                    include = nl:find("adjustment") ~= nil or ctype:find("adjustment") ~= nil
                elseif mode == "all" then
                    include = true
                end

                if include then
                    seen[name] = true
                    table.insert(results, {name=name, item=clip, ext=ext, ctype=ctype})
                end
            end
        end
        local subs = {}
        pcall(function() subs = folder:GetSubFolderList() or {} end)
        for _, sub in pairs(subs) do scanFolder(sub) end
    end

    pcall(function()
        local root = mediaPool:GetRootFolder()
        if root then scanFolder(root) end
    end)
    pcall(function()
        local pb = nil
        pcall(function() pb = mediaPool:GetPowerBinFolder() end)
        if pb then scanFolder(pb) end
    end)
    return results
end

local function doMarkerInsert(resolve, project, timeline, fps, markerColor, clipItem, mode, offsetFrames, logFn)
    local function log(m, t) if logFn then logFn(m, t) end end
    offsetFrames = offsetFrames or 0

    -- Derive track type and mediaType from mode (or from file extension for "all")
    local trackType, mediaType
    if mode == "audio" then
        trackType = "audio"; mediaType = 2
    elseif mode == "all" then
        -- detect from the clip's file extension / type
        local clipName, clipCtype, clipPath = "", "", ""
        pcall(function() clipName  = (clipItem:GetName() or ""):lower() end)
        pcall(function() clipCtype = (clipItem:GetClipProperty("Type") or ""):lower() end)
        pcall(function() clipPath  = (clipItem:GetClipProperty("File Path") or ""):lower() end)
        local ext = "." .. (clipPath:match("%.([^%.]+)$") or ""):lower()
        if AUDIO_EXTS[ext] or clipCtype == "audio" then
            trackType = "audio"; mediaType = 2
        else
            trackType = "video"; mediaType = 1
        end
    else
        -- video, graphics, adjustment  -  all go on a video track
        trackType = "video"; mediaType = 1
    end

    -- Collect markers
    local ok1, allMarkers = pcall(function() return timeline:GetMarkers() end)
    if not ok1 or not allMarkers then
        return {success=false, message="GetMarkers() failed"}
    end
    local targets = {}
    for fid, info in pairs(allMarkers) do
        if (info["color"] or ""):lower() == markerColor:lower() then
            targets[fid] = info
        end
    end
    if tableLen(targets) == 0 then
        return {success=false, message="No " .. markerColor .. " markers found."}
    end
    log("Found " .. tableLen(targets) .. " " .. markerColor .. " marker(s).", "ok")
    log("Clip: " .. (clipItem:GetName() or "?"), "info")

    if offsetFrames ~= 0 then
        local sign = offsetFrames > 0 and "+" or ""
        log("Offset: " .. sign .. offsetFrames .. " frames", "info")
    end

    -- Clip duration
    local clipFrames = 0
    pcall(function()
        local durStr = clipItem:GetClipProperty("Duration") or ""
        if durStr ~= "" then clipFrames = tcToFrames(durStr, fps) end
    end)
    if clipFrames == 0 then
        pcall(function() clipFrames = tonumber(clipItem:GetClipProperty("Frames") or "0") end)
    end
    if not clipFrames or clipFrames == 0 then
        clipFrames = math.floor(fps * 2)
        log("Could not read clip duration  -  using 2s default.", "warn")
    else
        log(("Clip duration: %d frames (%.2fs)"):format(clipFrames, clipFrames/fps), "info")
    end

    -- Switch to Edit page
    pcall(function() resolve:OpenPage("edit"); sleep(0.3) end)

    -- Add new track
    local oldCount = 0
    pcall(function() oldCount = timeline:GetTrackCount(trackType) end)
    local ok2, _ = pcall(function() timeline:AddTrack(trackType) end)
    if not ok2 then return {success=false, message="AddTrack('" .. trackType .. "') failed."} end
    sleep(0.3)
    local newCount = 0
    pcall(function() newCount = timeline:GetTrackCount(trackType) end)
    if newCount <= oldCount then
        return {success=false, message="AddTrack did not create a new track."}
    end
    local newTrack    = newCount
    local trackPrefix = (trackType == "audio") and "A" or "V"
    log("Created " .. trackType .. " track " .. trackPrefix .. newTrack, "ok")

    -- Place clips
    local mediaPool  = project:GetMediaPool()
    local startFrame = getTimelineStartFrame(timeline, fps)
    local sortedFids = sortedNumericKeys(targets)
    local done, errors = 0, 0
    -- Resolve ignores startFrame/endFrame for still images and always uses the
    -- standard still duration, so a still can run into the next marker. Track the end
    -- of each placement and stack onto an extra track instead of letting Resolve shift it.
    local laneTracks = { newTrack }
    local laneEnds = { [newTrack] = -math.huge }

    for i, fid in ipairs(sortedFids) do
        local info     = targets[fid]
        local absFrame = math.max(0, startFrame + fid + offsetFrames)
        local tcStr    = framesToTC(absFrame, fps)
        local mName    = trim(info["name"] or "") ~= "" and info["name"] or "(no name)"

        -- Trim to next marker
        local clipEnd = clipFrames
        if i < #sortedFids then
            local nextAbs = startFrame + sortedFids[i+1] + offsetFrames
            local gap     = nextAbs - absFrame
            clipEnd = math.min(clipFrames, math.max(1, gap))
        end
        local trimNote = (clipEnd < clipFrames) and (" (trimmed to " .. clipEnd .. " fr)") or ""
        log("  " .. tcStr .. "   -   '" .. mName .. "'" .. trimNote)

        local laneTrack = nil
        for _, t in ipairs(laneTracks) do
            if laneEnds[t] <= absFrame then laneTrack = t; break end
        end
        if not laneTrack then
            local before = 0
            pcall(function() before = timeline:GetTrackCount(trackType) end)
            pcall(function() timeline:AddTrack(trackType) end)
            local after = before
            pcall(function() after = timeline:GetTrackCount(trackType) end)
            if after > before then
                laneTrack = after
                table.insert(laneTracks, laneTrack)
                laneEnds[laneTrack] = -math.huge
                log("    Overlaps the previous clip - using extra track " .. trackPrefix .. laneTrack, "warn")
            else
                laneTrack = newTrack
            end
        end
        local ok3, placed = pcall(function()
            return mediaPool:AppendToTimeline({{
                mediaPoolItem = clipItem,
                trackIndex    = laneTrack,
                recordFrame   = absFrame,
                startFrame    = 0,
                endFrame      = clipEnd,
                mediaType     = mediaType,
            }})
        end)
        if ok3 and placed and #placed > 0 then
            pcall(function() laneEnds[laneTrack] = placed[1]:GetEnd() end)
            log("    OK Placed", "ok"); done = done + 1
        else
            log("    ERROR AppendToTimeline returned empty", "err"); errors = errors + 1
        end
    end

    local parts = {
        ("Clips placed: %d / %d"):format(done, tableLen(targets)),
        (trackType:sub(1,1):upper() .. trackType:sub(2)) .. " track: " .. trackPrefix .. newTrack,
    }
    if offsetFrames ~= 0 then
        local sign = offsetFrames > 0 and "+" or ""
        table.insert(parts, "Offset applied: " .. sign .. offsetFrames .. " frames")
    end
    if errors > 0 then table.insert(parts, "Errors: " .. errors) end
    table.insert(parts, "\nCtrl+Z in Resolve to undo if needed.")
    return {success=true, done=done, errors=errors, message=table.concat(parts, "\n")}
end

-- ============================================================
--  SLOW ZOOM  -  LOGIC  (Adjustment Layer only)
-- ============================================================

local function getEnabledClips(timeline, trackIndex)
    local items = {}
    local ok, raw = pcall(function() return timeline:GetItemListInTrack("video", trackIndex) end)
    if not ok or not raw then return items end
    for _, item in pairs(raw) do
        local enabled = true
        pcall(function() enabled = item:GetClipEnabled() end)
        if not enabled then goto continue end

        -- Skip transitions and gaps: real clips always have a MediaPoolItem;
        -- transitions, gaps, and generated items return nil.
        local hasMPI = false
        pcall(function() hasMPI = (item:GetMediaPoolItem() ~= nil) end)
        if not hasMPI then goto continue end

        local start, duration, name = 0, 0, ""
        pcall(function() start    = item:GetStart()    end)
        pcall(function() duration = item:GetDuration() end)
        pcall(function() name     = item:GetName()     end)

        -- Extra guard: skip blank-name or zero-duration items
        if name ~= "" and duration > 0 then
            table.insert(items, {item=item, start=start, duration=duration, name=name})
        end

        ::continue::
    end
    return items
end

local function findAdjClipInPool(mediaPool)
    local function scan(folder)
        if not folder then return nil end
        local clips = {}
        pcall(function() clips = folder:GetClipList() or {} end)
        for _, clip in pairs(clips) do
            local name, ctype = "", ""
            pcall(function() name  = (clip:GetName() or ""):lower() end)
            pcall(function() ctype = (clip:GetClipProperty("Type") or ""):lower() end)
            if name:find("adjustment") or ctype:find("adjustment") then
                return clip
            end
        end
        local subs = {}
        pcall(function() subs = folder:GetSubFolderList() or {} end)
        for _, sub in pairs(subs) do
            local found = scan(sub)
            if found then return found end
        end
        return nil
    end
    local result = nil
    pcall(function() result = scan(mediaPool:GetRootFolder()) end)
    if not result then
        pcall(function()
            local pb = nil
            pcall(function() pb = mediaPool:GetPowerBinFolder() end)
            if pb then result = scan(pb) end
        end)
    end
    return result
end

local function doTrackOverlay(resolve, project, timeline, mediaPool, fps, sourceTrack, adjClipOverride, dryRun, logFn)
    local function log(m, t) if logFn then logFn(m, t) end end

    local clips = getEnabledClips(timeline, sourceTrack)
    if #clips == 0 then
        return {success=false, message="No enabled clips on V" .. sourceTrack}
    end
    table.sort(clips, function(a, b) return a.start < b.start end)
    log("Found " .. #clips .. " enabled clip(s) on V" .. sourceTrack, "ok")

    -- Clamp each clip's duration to the gap before the next clip.
    -- Compound clips can cause GetDuration() to report 1 extra phantom frame at their
    -- boundary, which would make the adj clip placed over the preceding clip 1 frame too long.
    for i = 1, #clips - 1 do
        local avail = clips[i+1].start - clips[i].start
        if avail > 0 and avail < clips[i].duration then
            clips[i].duration = avail
        end
    end

    if dryRun then
        local lines = {"DRY RUN  -  no changes will be made\n",
                       ("Source: V%d  |  %d clip(s)"):format(sourceTrack, #clips)}
        for i, c in ipairs(clips) do
            local d = c.duration / fps
            table.insert(lines, ("  %d. \"%s\"  %.1fs"):format(i, c.name:sub(1,35), d))
        end
        return {success=true, dry_run=true, clip_count=#clips, message=table.concat(lines, "\n")}
    end

    local adjClip = adjClipOverride or findAdjClipInPool(mediaPool)
    if not adjClip then
        return {success=false,
            message="No Adjustment Clip found in Media Pool.\n\n"
                 .. "Setup:\n1. Insert an Adjustment Clip into any timeline\n"
                 .. "2. Add zoom keyframes in the Inspector (ZoomX at start and end)\n"
                 .. "3. Drag that clip into the Media Pool\n"
                 .. "4. Re-run this script."}
    end
    log("Template: " .. (adjClip:GetName() or "?"), "info")

    -- Still images (PNG, JPG...) always get Resolve's standard still length when placed by a
    -- script, so they cannot be trimmed to each clip. Build a long compound clip of the still
    -- once, keep it in the Media Pool, and use that as the template instead.
    local clipType, clipFrames = "", 0
    pcall(function() clipType = adjClip:GetClipProperty("Type") or "" end)
    pcall(function() clipFrames = tonumber(adjClip:GetClipProperty("Frames")) or 0 end)
    if clipType == "Still" or clipFrames == 1 then
        local need = 0
        for _, c in ipairs(clips) do need = math.max(need, c.duration) end
        local longName = (adjClip:GetName() or "Overlay"):gsub("%.%w+$", "") .. " (overlay)"
        local existing = nil
        local function scan(folder)
            for _, it in ipairs(folder:GetClipList() or {}) do
                local fr = 0
                pcall(function() fr = tonumber(it:GetClipProperty("Frames")) or 0 end)
                if it:GetName() == longName and fr >= need then existing = it end
            end
            for _, sub in ipairs(folder:GetSubFolderList() or {}) do scan(sub) end
        end
        pcall(function() scan(mediaPool:GetRootFolder()) end)
        if existing then
            adjClip = existing
            log("Using " .. longName .. " (a long copy of the still)", "info")
        elseif not dryRun then
            log("Still image: building " .. longName .. " so it can be trimmed to each clip...", "info")
            local built = nil
            pcall(function()
                local tmp = mediaPool:CreateEmptyTimeline("Krispy overlay build " .. os.time())
                if not tmp then return end
                project:SetCurrentTimeline(tmp)
                local s0 = tmp:GetStartFrame()
                local probe = mediaPool:AppendToTimeline({{mediaPoolItem = adjClip, trackIndex = 1, recordFrame = s0, mediaType = 1}})
                local stillLen = (probe and probe[1] and probe[1]:GetDuration()) or 125
                local infos = {}
                for i = 1, math.ceil(need / stillLen) do
                    infos[#infos + 1] = {mediaPoolItem = adjClip, trackIndex = 1, recordFrame = s0 + i * stillLen, mediaType = 1}
                end
                if #infos > 0 then mediaPool:AppendToTimeline(infos) end
                local items = tmp:GetItemListInTrack("video", 1) or {}
                local cc = tmp:CreateCompoundClip(items, {name = longName})
                built = cc and cc:GetMediaPoolItem()
                project:SetCurrentTimeline(timeline)
                mediaPool:DeleteTimelines({tmp})
            end)
            pcall(function() project:SetCurrentTimeline(timeline) end)
            if not built then
                return {success=false, message="Could not prepare the still image. Put it on a timeline, make it as long as your longest clip, turn it into a compound clip and pick that as the template."}
            end
            adjClip = built
        end
    end

    -- Get the adj clip's own fps so we can convert timeline frame counts correctly.
    -- AppendToTimeline's startFrame/endFrame are in SOURCE MEDIA frames (adj clip fps),
    -- not timeline frames.  If they differ, clips get wrong lengths and gaps appear.
    local adjFPS = fps
    pcall(function()
        local f = tonumber(adjClip:GetClipProperty("FPS"))
        if f and f > 0 then adjFPS = f end
    end)

    -- Snap both fps values to the nearest standard cinema/broadcast rate.
    -- GetClipProperty("FPS") can return e.g. 30.000001 instead of 30  -  without
    -- snapping this causes math.ceil to add a spurious +1 frame on matching rates.
    local KNOWN_FPS = {23.976, 24, 25, 29.97, 30, 48, 50, 59.94, 60, 120}
    local function snapFPS(f)
        for _, c in ipairs(KNOWN_FPS) do
            if math.abs(f - c) < 0.02 then return c end
        end
        return f
    end
    local snFps    = snapFPS(fps)
    local snAdjFPS = snapFPS(adjFPS)

    if snAdjFPS ~= snFps then
        log(("Adj clip fps %.6g != timeline fps %.6g  -  applying rate conversion"):format(snAdjFPS, snFps), "info")
    end

    -- Ensure Edit page
    pcall(function() resolve:OpenPage("edit"); sleep(0.4) end)

    -- Always create a brand-new video track at the top so we never collide with
    -- existing clips. Resolve only supports AddTrack (appends at top); there is
    -- no API to insert at a specific position.
    local tracksBefore = 0
    pcall(function() tracksBefore = timeline:GetTrackCount("video") end)
    pcall(function() timeline:AddTrack("video") end)
    sleep(0.3)
    local targetTrack = 0
    pcall(function() targetTrack = timeline:GetTrackCount("video") end)
    if targetTrack <= tracksBefore then
        -- AddTrack did not increase the count  -  fall back to one above source
        targetTrack = tracksBefore + 1
        local vc = 0
        pcall(function() vc = timeline:GetTrackCount("video") end)
        while vc < targetTrack do
            pcall(function() timeline:AddTrack("video") end)
            sleep(0.2)
            pcall(function() vc = timeline:GetTrackCount("video") end)
        end
    end
    log("New overlay track: V" .. targetTrack, "ok")

    local ok_count, fail_count = 0, 0

    for _, c in ipairs(clips) do
        local srcStart = c.start
        local srcDur   = c.duration
        local d        = srcDur / fps
        -- Convert timeline duration to adj-clip source frames.
        -- endFrame must be in SOURCE MEDIA frames (at snAdjFPS), not timeline frames.
        -- When the two rates are identical we skip conversion entirely (exact integer, no rounding).
        -- When they genuinely differ we use math.ceil so the placed clip is never shorter than srcDur.
        local endFrameSrc
        if snAdjFPS == snFps then
            endFrameSrc = srcDur   -- same rate: 1-to-1, no arithmetic needed
        else
            endFrameSrc = math.ceil(srcDur * snAdjFPS / snFps)
        end
        endFrameSrc = math.max(1, endFrameSrc)
        -- Place adjClip over this clip
        local ok3, placed = pcall(function()
            return mediaPool:AppendToTimeline({{
                mediaPoolItem = adjClip,
                trackIndex    = targetTrack,
                recordFrame   = srcStart,
                startFrame    = 0,
                endFrame      = endFrameSrc,
                mediaType     = 1,
            }})
        end)
        if ok3 and placed and #placed > 0 then
            -- Check that Resolve really put it where and as long as asked.
            local pStart, pDur = srcStart, srcDur
            pcall(function() pStart = placed[1]:GetStart(); pDur = placed[1]:GetDuration() end)
            if pStart == srcStart and math.abs(pDur - srcDur) <= 1 then
                log(("  OK \"%s\"  %.1fs"):format(c.name:sub(1,35), d), "ok")
                ok_count = ok_count + 1
            else
                log(("  CHECK \"%s\"  placed %d frames at %d, expected %d at %d"):format(c.name:sub(1,35), pDur, pStart, srcDur, srcStart), "warn")
                fail_count = fail_count + 1
            end
        else
            log(("  ERROR \"%s\"   -  placement failed"):format(c.name:sub(1,35)), "err")
            fail_count = fail_count + 1
        end
    end

    local lines = {
        "Track Overlay\n",
        ("Source: V%d   ->   Overlay: V%d"):format(sourceTrack, targetTrack),
        ("Placed: %d / %d"):format(ok_count, #clips),
    }
    if fail_count > 0 then table.insert(lines, "Errors: " .. fail_count) end
    table.insert(lines, "\nCtrl+Z to undo if needed.")
    return {success=true, zoom_ok=ok_count, zoom_fail=fail_count, message=table.concat(lines, "\n")}
end

-- ============================================================
--  BATCH EXPORT  -  LOGIC
-- ============================================================

local function doBatchExport(project, timelines, presetName, outputDir, clearFirst, logFn)
    local function log(m, t) if logFn then logFn(m, t) end end

    if clearFirst then
        pcall(function() project:DeleteAllRenderJobs() end)
        -- DeleteAllRenderJobs can silently do nothing outside the Deliver page.
        -- Check, and remove anything left one job at a time.
        local left = {}
        pcall(function() left = project:GetRenderJobList() or {} end)
        for _, job in ipairs(left) do
            pcall(function() project:DeleteRenderJob(job["JobId"]) end)
        end
        pcall(function() left = project:GetRenderJobList() or {} end)
        if #left == 0 then
            log("Existing render queue cleared.", "dim")
        else
            log(("Could not clear %d existing job(s); they stay in the queue."):format(#left), "warn")
        end
    end
    ensureDir(outputDir)

    local queued, errors = 0, 0

    for _, info in ipairs(timelines) do
        local tl   = info.timeline
        local name = tl:GetName()
        log("--- " .. name .. " ---", "head")

        -- Switch to this timeline
        local ok1 = false
        pcall(function()
            ok1 = project:SetCurrentTimeline(tl)
        end)
        if not ok1 then
            log("  ERROR Could not switch to timeline", "err"); errors = errors + 1
        else
            sleep(0.15)

            -- Load render preset
            local ok2 = false
            pcall(function() ok2 = project:LoadRenderPreset(presetName) end)
            if not ok2 then
                log("  ERROR Preset '" .. presetName .. "' not found  -  check exact name in Deliver > Presets", "err")
                errors = errors + 1
            else
                log("  Preset '" .. presetName .. "' loaded.", "dim")

                -- Determine In/Out frames
                local markIn, markOut
                local ok3 = pcall(function()
                    markIn  = tl:GetStartFrame()
                    markOut = tl:GetEndFrame() - 1  -- -1 avoids trailing black frame
                    if markOut < markIn then markOut = markIn end
                end)
                if not ok3 then
                    log("  ERROR Could not read timeline frame range", "err"); errors = errors + 1
                else
                    local fpsStr = tl:GetSetting("timelineFrameRate") or "?"
                    log(("  Frames: %d  ->  %d  (%s fps)"):format(markIn, markOut, fpsStr), "dim")

                    -- Apply render settings
                    local fname = safeName(name)
                    local ok4 = pcall(function()
                        project:SetRenderSettings({
                            SelectAllFrames = false,
                            MarkIn          = markIn,
                            MarkOut         = markOut,
                            TargetDir       = outputDir,
                            CustomName      = fname,
                        })
                    end)
                    if not ok4 then
                        log("  ERROR SetRenderSettings failed", "err"); errors = errors + 1
                    else
                        -- Add to queue
                        local jobId = nil
                        pcall(function() jobId = project:AddRenderJob() end)
                        if jobId and jobId ~= false and jobId ~= "" then
                            log("  OK Queued   ->   " .. fname, "ok")
                            queued = queued + 1
                        else
                            log("  ERROR AddRenderJob failed", "err"); errors = errors + 1
                        end
                    end
                end
            end
        end
    end

    local msg = ("Queued: %d / %d"):format(queued, #timelines)
    if errors > 0 then msg = msg .. ("  (%d error(s))"):format(errors) end
    msg = msg .. "\n\nSwitch to Resolve's Deliver page and hit Render All."
    return {success=true, queued=queued, errors=errors, message=msg}
end

-- ============================================================
--  QUICK SCREENSHOT  -  LOGIC
-- ============================================================

local function doQuickScreenshot(resolve, project, timeline, outputDir, logFn)
    local function log(m, t) if logFn then logFn(m, t) end end

    -- Build unique file prefix from timeline name + current timecode
    local tlName = safeName(timeline:GetName())
    local prefix
    pcall(function()
        local tc = timeline:GetCurrentTimecode()
        if tc and tc ~= "" then
            prefix = tlName .. "_" .. tc:gsub(":", "-")
        end
    end)
    if not prefix or prefix == "" then
        -- Fallback to a timestamp
        prefix = tlName .. "_" .. os.date("%Y%m%d_%H%M%S")
    end
    log("Capturing frame...  " .. prefix .. ".jpg", "info")

    ensureDir(outputDir)

    -- Switch to Color page
    pcall(function() resolve:OpenPage("color") end)
    sleep(0.8)

    -- Grab still
    local still = nil
    pcall(function() still = timeline:GrabStill() end)
    if not still then
        resolve:OpenPage("edit")
        return {success=false, message="GrabStill() failed  -  make sure a clip is under the playhead."}
    end
    sleep(0.3)

    local gallery = project:GetGallery()
    local album   = gallery and gallery:GetCurrentStillAlbum()
    if not album then
        resolve:OpenPage("edit")
        return {success=false, message="Could not access Gallery still album."}
    end

    -- Export JPEG
    local ok5, _ = pcall(function()
        album:ExportStills({still}, outputDir, prefix, "jpg")
    end)
    sleep(0.5)

    -- Remove .drx sidecar
    cleanDRX(outputDir, prefix)

    -- Clean still from gallery
    pcall(function() album:DeleteStills({still}) end)

    resolve:OpenPage("edit")

    if ok5 then
        local saved = finalizeStill(outputDir, prefix, prefix) or (prefix .. ".jpg")
        return {success=true, message="OK Saved: " .. saved .. "\nFolder: " .. outputDir}
    else
        return {success=false, message="ExportStills() returned false."}
    end
end

-- ============================================================
--  MAIN WINDOW
-- ============================================================

local function run(resolve, project, timeline, fps)
    -- 'fusion' and 'bmd' are globals pre-provided by Resolve's Lua environment.
    -- Do NOT call resolve:Fusion()  -  it may return nil in this context.
    local ui   = fusion.UIManager
    local disp = bmd.UIDispatcher(ui)

    local mediaPool = project:GetMediaPool()

    local function SHOW(n) return ONLY_TAB == nil or ONLY_TAB == n end
    local SINGLE = {
        { title = "Timeline Renamer",   id = "KrispyTimelineRenamer2026",   size = {780, 860},
          blurb = "Duplicate or rename many timelines at once with find and replace." },
        { title = "Marker Screenshots", id = "KrispyMarkerScreenshots2026", size = {760, 480},
          blurb = "Save a still at every marker of one colour, or grab the current frame." },
        { title = "Marker Insert",      id = "KrispyMarkerInsert2026",      size = {780, 820},
          blurb = "Place one Media Pool clip at every marker of one colour, on a new track." },
        { title = "Track Overlay",      id = "KrispyTrackOverlay2026",      size = {780, 580},
          blurb = "Put a template clip over every clip on a track, cut for cut, on a new track." },
        { title = "Batch Export",       id = "KrispyBatchExport2026",       size = {780, 780},
          blurb = "Queue many timelines for render with one preset and one output folder." },
    }
    local WIN_ID = ONLY_TAB and SINGLE[ONLY_TAB].id or "ResolveAutomatorGraphite2026V17"

    -- Mutable state shared between logic and event handlers
    local state = {
        allTimelines  = getAllTimelines(project),   -- [{name, timeline}]
        poolClips     = {},    -- [{name, item}] for Marker Insert
        poolTemplates = {},    -- [{name, item}] for Track Overlay
        activeTab     = 1,
    }

    -- -- Build UI --------------------------------------------------------------

    local function sep()
        return ui:Label{Weight=0, MinimumSize={1,1}, MaximumSize={9999,1}, StyleSheet=SS.sep}
    end

    -- Keep logs and action buttons in one bounded block. UIManager can ignore a
    -- TextEdit's MaximumSize when it is a direct child of a stacked page; the
    -- fixed wrapper prevents the log from growing through the footer row.
    local function action_footer(log_id, button_row)
        local LOG_H = 104
        return ui:VGroup{
            Weight=0, Spacing=0,
            MinimumSize={0,LOG_H + 107}, MaximumSize={9999,LOG_H + 107},
            sep(),
            ui:VGap(7),
            ui:Label{Weight=0, Text="Log:", StyleSheet=SS.dim,
                     MinimumSize={0,18}, MaximumSize={9999,18}},
            ui:VGap(5),
            ui:TextEdit{ID=log_id, Weight=0,
                        MinimumSize={0,LOG_H}, MaximumSize={9999,LOG_H},
                        ReadOnly=true, StyleSheet=SS.log},
            ui:VGap(14),
            button_row,
            ui:VGap(10),
        }
    end

    -- Tab page IDs
    local TAB_IDS     = {"TLRenamerPage","MarkerScrPage","MarkerInsPage","TrackOverlayPage","BatchExportPage"}
    local TAB_BTN_IDS = {"TabBtn1","TabBtn2","TabBtn3","TabBtn4","TabBtn5"}
    local TAB_LABELS  = {"TL Renamer","Screenshots","Marker Insert","Track Overlay","Batch Export"}

    -- -- Timeline Renamer page -------------------------------------------------
    local tlRenamerPage = SHOW(1) and ui:VGroup{
        ID = "TLRenamerPage", Spacing=10,

        ui:Label{Weight=0, MinimumSize={0,18}, MaximumSize={9999,18},
                 Text="Select timelines, type the part of the name to find, then what to replace it with.",
                 StyleSheet=SS.dim},

        -- This is the page's only flexible region. Extra height belongs to the timeline list.
        ui:VGroup{Weight=1, Spacing=6, MinimumSize={0,236},
            ui:Label{Weight=0, MinimumSize={0,20}, MaximumSize={9999,20},
                     Text="Timelines  (Ctrl+click or Shift+click to multi-select):",
                     StyleSheet=SS.label},
            ui:HGroup{Weight=0, Spacing=8, MinimumSize={0,38}, MaximumSize={9999,38},
                ui:LineEdit{ID="TLFilterText", StyleSheet=SS.input_fixed, Weight=1,
                            PlaceholderText="Filter by name...", MinimumSize={0,38}, MaximumSize={9999,38}},
                ui:Button{ID="TLFilterClear", Text="x", StyleSheet=SS.btn, Weight=0,
                          MinimumSize={42,38}, MaximumSize={42,38}},
            },
            ui:HGroup{Weight=1, Spacing=8, MinimumSize={0,160},
                ui:Tree{
                    ID="TLList", Weight=1, MinimumSize={0,160},
                    SelectionMode="ExtendedSelection", HeaderHidden=true,
                    SortingEnabled=false, ColumnCount=1, StyleSheet=SS.tree,
                },
                ui:VGroup{Weight=0, Spacing=0, MinimumSize={92,160}, MaximumSize={92,9999},
                    ui:Button{ID="TLRefreshBtn", Text="Refresh", StyleSheet=SS.btn,
                              MinimumSize={92,40}, MaximumSize={92,40}, Weight=0},
                    ui:VGap(120),
                },
            },
        },

        -- Fixed rename region: labels and editors always keep separate rows.
        ui:VGroup{Weight=0, Spacing=6, MinimumSize={0,214}, MaximumSize={9999,214},
            ui:HGroup{Weight=0, Spacing=8, MinimumSize={0,38}, MaximumSize={9999,38},
                ui:Label{Weight=0, Text="Find:", StyleSheet=SS.label,
                         MinimumSize={62,38}, MaximumSize={62,38}},
                ui:LineEdit{ID="TLFindText", StyleSheet=SS.input_fixed, Weight=1,
                            MinimumSize={0,38}, MaximumSize={9999,38}},
            },
            ui:Label{Weight=0, MinimumSize={0,20}, MaximumSize={9999,20},
                     Text="Replace with  (comma-separated or one per line  -  in Duplicate mode each entry makes one copy):",
                     StyleSheet=SS.label},
            ui:TextEdit{ID="TLReplaceText", Weight=0, StyleSheet=SS.multiline,
                        PlaceholderText="e.g. v2, Client Review, 9x16, Final",
                        MinimumSize={0,82}, MaximumSize={9999,82}},
            ui:HGroup{Weight=0, MinimumSize={0,28}, MaximumSize={9999,28},
                ui:CheckBox{ID="TLModeDupe", Text="Duplicate + Rename  (keeps originals)",
                            Checked=true, StyleSheet=SS.check, Weight=1},
                ui:CheckBox{ID="TLModeRename", Text="Rename in place",
                            StyleSheet=SS.check, Weight=1},
            },
            ui:Label{Weight=0, MinimumSize={0,28}, MaximumSize={9999,28},
                     Text="Duplicate creates copies. Rename changes each selected timeline directly.",
                     StyleSheet=SS.dim},
        },

        action_footer("TLLog", ui:HGroup{Weight=0, Spacing=10,
                                         MinimumSize={0,42}, MaximumSize={9999,42},
            ui:Button{ID="TLPreviewBtn", Text="Preview", StyleSheet=SS.btn, Weight=1,
                      MinimumSize={0,38}, MaximumSize={9999,38}},
            ui:Button{ID="TLClearBtn", Text="Clear Log", StyleSheet=SS.btn, Weight=1,
                      MinimumSize={0,38}, MaximumSize={9999,38}},
            ui:Button{ID="TLApplyBtn", Text="Apply", StyleSheet=SS.btn_acc, Weight=1,
                      MinimumSize={0,38}, MaximumSize={9999,38}},
        }),
    }
    -- -- Marker Screenshots page -----------------------------------------------
    local markerScrPage = SHOW(2) and ui:VGroup{
        ID = "MarkerScrPage",

        ui:Label{Weight=0,
                 Text="Capture a JPEG at every marker of the chosen colour, or a single shot at the current playhead position.\n"
                   .. "Both modes briefly switch to Color page for GrabStill, then return to Edit.",
                 StyleSheet=SS.dim, WordWrap=true},

        ui:HGroup{Weight=0,
            ui:Label{Weight=0, Text="Marker color:", StyleSheet=SS.label, MinimumSize={90,0}},
            ui:ComboBox{ID="ScrColorCombo", StyleSheet=SS.combo},
        },

        ui:HGroup{Weight=0,
            ui:Label{Weight=0, Text="Output folder:", StyleSheet=SS.label, MinimumSize={90,0}},
            ui:LineEdit{ID="ScrFolderText", StyleSheet=SS.input, Weight=1},
            ui:Button{ID="ScrFolderBtn", Text="...", StyleSheet=SS.btn, Weight=0, MinimumSize={42,30}, MaximumSize={42,36}},
        },
        ui:Label{Weight=0, Text="Folder will be created if it does not exist.",
                 StyleSheet=SS.dim},

        ui:VGap(0, 1),
        action_footer("ScrLog", ui:HGroup{Weight=0, Spacing=10,
                                          MinimumSize={0,42}, MaximumSize={9999,42},
            ui:Button{ID="ScrPreviewBtn", Text="Preview", StyleSheet=SS.btn, Weight=1, MinimumSize={0,38}, MaximumSize={9999,38}},
            ui:Button{ID="ScrClearBtn", Text="Clear Log", StyleSheet=SS.btn, Weight=1, MinimumSize={0,38}, MaximumSize={9999,38}},
            ui:Button{ID="ScrQuickBtn", Text="Capture Frame", StyleSheet=SS.btn, Weight=1, MinimumSize={0,38}, MaximumSize={9999,38}},
            ui:Button{ID="ScrCaptureBtn", Text="Capture Markers", StyleSheet=SS.btn_acc, Weight=1, MinimumSize={0,38}, MaximumSize={9999,38}},
        }),
    }

    -- -- Marker Insert page ----------------------------------------------------
    local markerInsPage = SHOW(3) and ui:VGroup{
        ID = "MarkerInsPage",

        ui:Label{Weight=0,
                 Text="Places a clip from the Media Pool at every matching marker on a new track.\n"
                   .. "Audio  ->  new audio track.  Video / Graphics / Adjustment  ->  new video track.",
                 StyleSheet=SS.dim, WordWrap=true},

        -- Mode (radio-style)
        ui:HGroup{Weight=0,
            ui:CheckBox{ID="InsAudioMode",      Text="Audio",      Checked=true, StyleSheet=SS.label},
            ui:CheckBox{ID="InsVideoMode",      Text="Video",                    StyleSheet=SS.label},
            ui:CheckBox{ID="InsGraphicsMode",   Text="Graphics",                 StyleSheet=SS.label},
            ui:CheckBox{ID="InsAllMode",        Text="All",                      StyleSheet=SS.label},
        },

        -- Marker color + offset
        ui:HGroup{Weight=0, Spacing=8, MinimumSize={0,40}, MaximumSize={9999,40},
            ui:Label{Weight=0, Text="Marker color:", StyleSheet=SS.label, MinimumSize={90,38}, MaximumSize={90,38}},
            ui:ComboBox{ID="InsColorCombo", StyleSheet=SS.combo, MinimumSize={250,38}, MaximumSize={9999,38}},
            ui:HGap(10),
            ui:Label{Weight=0, Text="Frame offset:", StyleSheet=SS.label, MinimumSize={90,38}, MaximumSize={90,38}},
            ui:SpinBox{ID="InsOffsetSpin", Minimum=-999, Maximum=999, Value=0,
                       StyleSheet=SS.input, Weight=0,
                       Alignment={AlignHCenter=true, AlignVCenter=true},
                       MinimumSize={118,38}, MaximumSize={118,38}},
            ui:Label{Weight=0, Text="(- earlier / + later)", StyleSheet=SS.dim,
                     MinimumSize={130,38}, MaximumSize={130,38}},
        },

        -- Clip picker
        ui:Label{Weight=0, Text="Clip  (from Media Pool):", StyleSheet=SS.label},
        ui:HGroup{Weight=1, MinimumSize={0,260},
            ui:Tree{
                ID="InsClipList", Weight=1,
                SelectionMode="SingleSelection",
                HeaderHidden=true, SortingEnabled=false,
                ColumnCount=1,
                StyleSheet=SS.tree,
            },
            ui:VGroup{Weight=0, Spacing=0, MinimumSize={92,0}, MaximumSize={92,9999},
                ui:Button{ID="InsRefreshBtn", Text="Refresh", StyleSheet=SS.btn, Weight=0,
                          MinimumSize={92,40}, MaximumSize={92,40}},
                ui:Label{Weight=1, Text=""},
            },
        },
        ui:Label{Weight=0,
                 Text="A brand-new track is always created  -  existing tracks are never touched.",
                 StyleSheet=SS.dim, WordWrap=true},

        action_footer("InsLog", ui:HGroup{Weight=0, Spacing=10,
                                          MinimumSize={0,42}, MaximumSize={9999,42},
            ui:Button{ID="InsPreviewBtn", Text="Preview", StyleSheet=SS.btn, Weight=1, MinimumSize={0,38}, MaximumSize={9999,38}},
            ui:Button{ID="InsClearBtn", Text="Clear Log", StyleSheet=SS.btn, Weight=1, MinimumSize={0,38}, MaximumSize={9999,38}},
            ui:Button{ID="InsPlaceBtn", Text="Place Clip", StyleSheet=SS.btn_acc, Weight=1, MinimumSize={0,38}, MaximumSize={9999,38}},
        }),
    }

    -- -- Track Overlay page ----------------------------------------------------
    local trackOverlayPage = SHOW(4) and ui:VGroup{
        ID = "TrackOverlayPage",

        ui:Label{Weight=0,
                 Text="Places a template clip over every clip on a source track, on a new track above it.\n"
                   .. "Supports any media type: Adjustment Clips, video, graphics, or audio.\n"
                   .. "SETUP: Drag template into the Media Pool  ->  select below  ->  pick source track.",
                 StyleSheet=SS.dim, WordWrap=true},

        -- Template filter mode
        ui:HGroup{Weight=0,
            ui:Label{Weight=0, Text="Filter:", StyleSheet=SS.label, MinimumSize={70,0}},
            ui:CheckBox{ID="ZoomFilterAdj",      Text="Adjustment", Checked=true, StyleSheet=SS.label},
            ui:CheckBox{ID="ZoomFilterVideo",    Text="Video",                    StyleSheet=SS.label},
            ui:CheckBox{ID="ZoomFilterGraphics", Text="Graphics",                 StyleSheet=SS.label},
            ui:CheckBox{ID="ZoomFilterAudio",    Text="Audio",                    StyleSheet=SS.label},
            ui:CheckBox{ID="ZoomFilterAll",      Text="All",                      StyleSheet=SS.label},
        },

        -- Template
        ui:HGroup{Weight=0,
            ui:Label{Weight=0, Text="Template:", StyleSheet=SS.label, MinimumSize={70,0}},
            ui:ComboBox{ID="ZoomTemplateCombo", StyleSheet=SS.combo, Weight=1},
            ui:Button{ID="ZoomTemplateRefreshBtn", Text="Refresh", StyleSheet=SS.btn, Weight=0,
                      MinimumSize={92,34}, MaximumSize={92,36}},
        },
        ui:Label{ID="ZoomTemplateStatus", Weight=0, Text="", StyleSheet=SS.dim},

        -- Source track
        ui:HGroup{Weight=0,
            ui:Label{Weight=0, Text="Source track:", StyleSheet=SS.label, MinimumSize={90,0}},
            ui:ComboBox{ID="ZoomTrackCombo", StyleSheet=SS.combo},
        },
        ui:Label{Weight=0, Text="Only Enabled clips are processed. Disabled clips and transitions are ignored.",
                 StyleSheet=SS.dim, WordWrap=true},

        ui:VGap(0, 1),
        action_footer("ZoomLog", ui:HGroup{Weight=0, Spacing=10,
                                           MinimumSize={0,42}, MaximumSize={9999,42},
            ui:Button{ID="ZoomDryRunBtn", Text="Dry Run", StyleSheet=SS.btn, Weight=1, MinimumSize={0,38}, MaximumSize={9999,38}},
            ui:Button{ID="ZoomClearBtn", Text="Clear Log", StyleSheet=SS.btn, Weight=1, MinimumSize={0,38}, MaximumSize={9999,38}},
            ui:Button{ID="ZoomApplyBtn", Text="Apply Overlay", StyleSheet=SS.btn_acc, Weight=1, MinimumSize={0,38}, MaximumSize={9999,38}},
        }),
    }

    -- -- Batch Export page -----------------------------------------------------

    local batchExportPage = SHOW(5) and ui:VGroup{ID="BatchExportPage", Spacing=6,
        ui:Label{Weight=0, Text="Select timelines to queue for render:", StyleSheet=SS.label},
        ui:HGroup{Weight=0, Spacing=4,
            ui:LineEdit{ID="ExpFilterText", StyleSheet=SS.input,
                        PlaceholderText="Filter by name..."},
            ui:Button{ID="ExpFilterClear", Text="x", StyleSheet=SS.btn, Weight=0,
                      MinimumSize={42,34}, MaximumSize={42,36}},
        },
        ui:Tree{
            ID="ExpTLList", Weight=1, MinimumSize={0,170},
            SortingEnabled=false, SelectionMode="ExtendedSelection",
            AlternatingRowColors=true, HeaderHidden=true, StyleSheet=SS.tree,
        },
        ui:HGroup{Weight=0, Spacing=8, MinimumSize={0,38}, MaximumSize={9999,38},
            ui:Label{Weight=0, Text="Render preset:", StyleSheet=SS.label, MinimumSize={90,38}, MaximumSize={90,38}},
            ui:LineEdit{ID="ExpPresetText", StyleSheet=SS.input_fixed, Text="h264", Weight=1,
                        MinimumSize={0,36}, MaximumSize={9999,36},
                        PlaceholderText="Must match exactly the preset name shown in Deliver  ->  Presets"},
        },
        ui:HGroup{Weight=0, Spacing=8, MinimumSize={0,38}, MaximumSize={9999,38},
            ui:Label{Weight=0, Text="Output folder:", StyleSheet=SS.label, MinimumSize={90,38}, MaximumSize={90,38}},
            ui:LineEdit{ID="ExpFolderText", StyleSheet=SS.input_fixed, Weight=1,
                        MinimumSize={0,36}, MaximumSize={9999,36}},
            ui:Button{ID="ExpFolderBtn", Text="...", StyleSheet=SS.btn, Weight=0,
                      MinimumSize={42,36}, MaximumSize={42,36}},
        },
        ui:HGroup{Weight=0, Spacing=6,
            ui:CheckBox{ID="ExpClearQueue", Text="Clear existing queue before adding", StyleSheet=SS.label, Checked=false},
        },
        action_footer("ExpLog", ui:HGroup{Weight=0, Spacing=10,
                                          MinimumSize={0,42}, MaximumSize={9999,42},
            ui:Button{ID="ExpRefreshBtn", Text="Refresh", StyleSheet=SS.btn, Weight=1, MinimumSize={0,38}, MaximumSize={9999,38}},
            ui:Button{ID="ExpClearBtn", Text="Clear Log", StyleSheet=SS.btn, Weight=1, MinimumSize={0,38}, MaximumSize={9999,38}},
            ui:Button{ID="ExpQueueBtn", Text="Add to Queue", StyleSheet=SS.btn_acc, Weight=1, MinimumSize={0,38}, MaximumSize={9999,38}},
        }),
    }

    -- -- Assemble window -------------------------------------------------------

    local body
    if ONLY_TAB then
        local info = SINGLE[ONLY_TAB]
        local page = ({tlRenamerPage, markerScrPage, markerInsPage, trackOverlayPage, batchExportPage})[ONLY_TAB]
        body = ui:VGroup{Weight=1, Spacing=6,
            ui:HGroup{Weight=0, Spacing=12, MinimumSize={0,34}, MaximumSize={9999,34},
                ui:Label{Weight=0, MinimumSize={5,34}, MaximumSize={5,34}, StyleSheet=SS.bar},
                ui:Label{Text=info.title, StyleSheet=SS.title, Weight=1, MinimumSize={0,34}, MaximumSize={9999,34}},
            },
            sep(),
            ui:VGroup{ID="MainStack", Weight=1, page},
        }
    else
        body = ui:VGroup{Weight=1, Spacing=6,
            ui:HGroup{Weight=0, Spacing=4, MinimumSize={0,38}, MaximumSize={9999,38},
                ui:Button{ID=TAB_BTN_IDS[1], Text=TAB_LABELS[1], StyleSheet=SS.btn_tab_active},
                ui:Button{ID=TAB_BTN_IDS[2], Text=TAB_LABELS[2], StyleSheet=SS.btn_tab},
                ui:Button{ID=TAB_BTN_IDS[3], Text=TAB_LABELS[3], StyleSheet=SS.btn_tab},
                ui:Button{ID=TAB_BTN_IDS[4], Text=TAB_LABELS[4], StyleSheet=SS.btn_tab},
                ui:Button{ID=TAB_BTN_IDS[5], Text=TAB_LABELS[5], StyleSheet=SS.btn_tab},
            },
            sep(),
            ui:Stack{
                ID="MainStack",
                Weight=1,
                tlRenamerPage,
                markerScrPage,
                markerInsPage,
                trackOverlayPage,
                batchExportPage,
            },
        }
    end

    local winSize = ONLY_TAB and SINGLE[ONLY_TAB].size or {900, 1000}
    local winMin = ONLY_TAB and {winSize[1] - 40, winSize[2] - 40} or {860, 960}
    local win = disp:AddWindow({
        ID = WIN_ID,
        WindowTitle = ONLY_TAB and SINGLE[ONLY_TAB].title or "DaVinci Resolve Automator",
        Geometry = {120, 10, winSize[1], winSize[2]},
        MinimumSize = winMin,
        StyleSheet = SS.win,

        ui:VGroup{Spacing=0,
            ui:VGap(12),
            ui:HGroup{Weight=1, Spacing=0,
                ui:HGap(12),
                body,
                ui:HGap(12),
            },
            ui:VGap(12),
        },
    })

    -- Get all items table  -  use itm.ID instead of win:Find("ID")
    local itm = win:GetItems()

    -- Ensure Stack starts on page 0 (Timeline Renamer) and tab styles are correct
    if not ONLY_TAB then
        itm.MainStack.CurrentIndex = 0
        for i, btnID in ipairs(TAB_BTN_IDS) do
            itm[btnID].StyleSheet = (i == 1) and SS.btn_tab_active or SS.btn_tab
        end
    end

    -- Pre-initialise all log HTML so w.HTML is never nil on first append
    local LOG_IDS = {"TLLog", "ScrLog", "InsLog", "ZoomLog", "ExpLog"}
    for _, id in ipairs(LOG_IDS) do
        if itm[id] then itm[id].HTML = "" end
    end

    -- Warn if no timeline was open when the script launched
    if not timeline then
        local noTLMsg = "No active timeline detected at launch  -  open a timeline in Resolve, then press Refresh."
        for _, id in ipairs({"TLLog", "ScrLog", "InsLog", "ZoomLog"}) do
            if itm[id] then logAppend(itm[id], noTLMsg, "warn") end
        end
    end

    -- -- Populate initial widget data ------------------------------------------

    -- Helper: populate a Tree with a list of strings, optional case-insensitive filter
    local function fillTree(widget, items, filter)
        filter = (filter and trim(filter) ~= "") and trim(filter):lower() or nil
        widget:Clear()
        local count = 0
        for _, name in ipairs(items) do
            if not filter or name:lower():find(filter, 1, true) then
                local item = widget:NewItem()
                item.Text[0] = name
                widget:AddTopLevelItem(item)
                count = count + 1
            end
        end
        return count
    end

    -- Helper: populate a ComboBox with a list of strings
    -- Uses the items array for index lookup  -  avoids Count/ItemText API calls
    local function fillCombo(widget, items, defaultVal)
        widget:Clear()
        for _, v in ipairs(items) do widget:AddItem(v) end
        if defaultVal then
            for i, v in ipairs(items) do
                if v == defaultVal then widget.CurrentIndex = i - 1; break end
            end
        end
    end

    -- Helper: rebuild TLList and select only the first visible timeline
    local function refreshTLList()
        local tlNames = {}
        for _, info in ipairs(state.allTimelines) do table.insert(tlNames, info.name) end
        local count = fillTree(itm.TLList, tlNames, itm.TLFilterText.Text)
        if count > 0 then itm.TLList:TopLevelItem(0).Selected = true end
    end

    -- Timelines (initial populate)
    if SHOW(1) then refreshTLList() end

    -- Marker color combos
    if SHOW(2) then fillCombo(itm.ScrColorCombo, MARKER_COLORS, "Blue") end
    if SHOW(3) then fillCombo(itm.InsColorCombo, MARKER_COLORS, "Blue") end

    -- Detect OS path separator and Desktop path
    local sep2    = IS_WINDOWS and "\\" or "/"
    local desktop = (os.getenv("USERPROFILE") or os.getenv("HOME") or "") .. sep2 .. "Desktop"

    -- Screenshot default folder (Desktop/Screenshots)
    if SHOW(2) then itm.ScrFolderText.Text = desktop .. sep2 .. "Screenshots" end

    -- Batch Export: populate timeline list and select only the first visible timeline
    local function refreshExpTLList()
        state.allTimelines = getAllTimelines(project)
        local names = {}
        for _, info in ipairs(state.allTimelines) do table.insert(names, info.name) end
        local count = fillTree(itm.ExpTLList, names, itm.ExpFilterText.Text)
        if count > 0 then itm.ExpTLList:TopLevelItem(0).Selected = true end
    end
    if SHOW(5) then refreshExpTLList() end

    -- Batch Export: default output folder (Desktop/Renders)
    if SHOW(5) then itm.ExpFolderText.Text = desktop .. sep2 .. "Renders" end

    -- Track Overlay: video tracks
    local function refreshZoomTracks()
        local count = 1
        pcall(function() count = timeline:GetTrackCount("video") end)
        local tracks = {}
        for i = 1, count do table.insert(tracks, "V" .. i) end
        fillCombo(itm.ZoomTrackCombo, tracks, "V1")
    end
    if SHOW(4) then refreshZoomTracks() end

    -- Track Overlay: current filter mode
    local function zoomFilterMode()
        if itm.ZoomFilterAdj.Checked      then return "adjustment" end
        if itm.ZoomFilterVideo.Checked    then return "video"      end
        if itm.ZoomFilterGraphics.Checked then return "graphics"   end
        if itm.ZoomFilterAudio.Checked    then return "audio"      end
        return "all"
    end

    -- Track Overlay: templates
    local function refreshTemplates(silent)
        local mode = zoomFilterMode()
        state.poolTemplates = {}
        local names = {}

        local modeLabels = {
            adjustment = "Adjustment Clips",
            video      = "Video clips",
            graphics   = "Graphics / images",
            audio      = "Audio clips",
            all        = "clips",
        }

        local clips = listPoolClipsByMode(mediaPool, mode)
        for _, c in ipairs(clips) do
            table.insert(state.poolTemplates, {name=c.name, item=c.item})
            table.insert(names, c.name)
        end

        itm.ZoomTemplateCombo:Clear()
        if #names > 0 then
            for _, n in ipairs(names) do itm.ZoomTemplateCombo:AddItem(n) end
            itm.ZoomTemplateStatus.Text = #names .. " " .. (modeLabels[mode] or "clips") .. " found in pool"
        else
            itm.ZoomTemplateCombo:AddItem(" -  None found  - ")
            itm.ZoomTemplateStatus.Text = "No " .. (modeLabels[mode] or "clips") .. " found  -  drag one into pool first"
        end
    end
    if SHOW(4) then refreshTemplates(true) end

    -- Marker Insert: pool clips
    local function refreshInsertClips(mode)
        state.poolClips = listPoolClipsByMode(mediaPool, mode or "audio")
        local names = {}
        for _, c in ipairs(state.poolClips) do table.insert(names, c.name) end
        fillTree(itm.InsClipList, names)
    end
    if SHOW(3) then refreshInsertClips("audio") end

    -- -- Tab switching ---------------------------------------------------------

    local function switchTab(idx)
        itm.MainStack.CurrentIndex = idx - 1
        state.activeTab = idx
        for i, btnID in ipairs(TAB_BTN_IDS) do
            itm[btnID].StyleSheet = (i == idx) and SS.btn_tab_active or SS.btn_tab
        end
    end

    -- -- Helper: get selected timelines ----------------------------------------

    local function getSelectedTimelines()
        local sel = itm.TLList:SelectedItems()
        local result = {}
        for _, item in pairs(sel) do
            local name = item.Text[0]
            for _, info in ipairs(state.allTimelines) do
                if info.name == name then
                    table.insert(result, info)
                    break
                end
            end
        end
        return result
    end

    local function getSelectedInsertClip()
        local sel = itm.InsClipList:SelectedItems()
        for _, item in pairs(sel) do
            local name = item.Text[0]
            for _, c in ipairs(state.poolClips) do
                if c.name == name then return c end
            end
        end
        return nil
    end

    -- -- EVENT HANDLERS --------------------------------------------------------

    -- Tab buttons
    win.On.TabBtn1.Clicked = function() switchTab(1) end
    win.On.TabBtn2.Clicked = function() switchTab(2) end
    win.On.TabBtn3.Clicked = function() switchTab(3) end
    win.On.TabBtn4.Clicked = function() switchTab(4) end
    win.On.TabBtn5.Clicked = function() switchTab(5) end

    -- -- Timeline Renamer ------------------------------------------------------

    win.On.TLFilterText.TextChanged = function()
        refreshTLList()
    end
    win.On.TLFilterClear.Clicked = function()
        itm.TLFilterText.Text = ""   -- triggers TextChanged  ->  refreshTLList
    end

    win.On.TLRefreshBtn.Clicked = function()
        state.allTimelines = getAllTimelines(project)
        refreshTLList()
        logAppend(itm.TLLog,
            ("Timeline list refreshed (%d total, %d visible)."):format(
                #state.allTimelines, itm.TLList:TopLevelItemCount()), "ok")
    end

    win.On.TLPreviewBtn.Clicked = function()
        logClear(itm.TLLog)
        local selected = getSelectedTimelines()
        local findStr  = trim(itm.TLFindText.Text)
        local repText  = itm.TLReplaceText.PlainText
        local reps     = parseReplacements(repText)
        local isDupe   = itm.TLModeDupe.Checked

        logAppend(itm.TLLog, "-- PREVIEW --", "head")
        logAppend(itm.TLLog, ("Selected: %d timeline(s)  |  Find: '%s'  |  %d replacement(s)  |  Mode: %s"):format(
            #selected, findStr, #reps, isDupe and "Duplicate" or "Rename"), "info")

        if findStr == "" then logAppend(itm.TLLog, "Find text is empty.", "err"); return end
        if #selected == 0 then logAppend(itm.TLLog, "No timelines selected.", "err"); return end

        for _, info in ipairs(selected) do
            local name = info.name
            if not name:find(findStr, 1, true) then
                logAppend(itm.TLLog, "  [no match] " .. name, "dim")
            elseif isDupe then
                for _, rep in ipairs(reps) do
                    local newName = name:gsub(findStr:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]","%%%1"), rep, 1)
                    logAppend(itm.TLLog, "  " .. name .. "   ->   " .. newName .. "  (duplicate)", "info")
                end
            else
                local newName = name:gsub(findStr:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]","%%%1"), reps[1] or "", 1)
                logAppend(itm.TLLog, "  " .. name .. "   ->   " .. newName .. "  (rename)", "info")
            end
        end
    end

    -- Mode checkboxes behave like radio buttons (mutually exclusive)
    win.On.TLModeDupe.Clicked = function()
        itm.TLModeDupe.Checked   = true
        itm.TLModeRename.Checked = false
    end
    win.On.TLModeRename.Clicked = function()
        itm.TLModeRename.Checked = true
        itm.TLModeDupe.Checked   = false
    end

    win.On.TLClearBtn.Clicked = function() logClear(itm.TLLog) end

    win.On.TLApplyBtn.Clicked = function()
        logClear(itm.TLLog)
        local selected = getSelectedTimelines()
        local findStr  = trim(itm.TLFindText.Text)
        local repText  = itm.TLReplaceText.PlainText
        local reps     = parseReplacements(repText)
        local isDupe   = itm.TLModeDupe.Checked

        if findStr == "" then logAppend(itm.TLLog, "Find text is empty.", "err"); return end
        if #selected == 0 then logAppend(itm.TLLog, "No timelines selected.", "err"); return end
        if #reps == 0 then logAppend(itm.TLLog, "No replacement text provided.", "err"); return end

        logAppend(itm.TLLog, "-- Applying --", "head")

        local function log(m, t) logAppend(itm.TLLog, m, t) end
        local result = doTimelineOperations(project, selected, findStr, reps, isDupe, log)

        logAppend(itm.TLLog,
            ("\nDone  -  %d operation(s)%s"):format(
                result.done,
                result.errors > 0 and ("  (" .. result.errors .. " error(s))") or ""),
            result.errors > 0 and "warn" or "ok")

        -- Refresh timeline list (preserves active filter)
        state.allTimelines = getAllTimelines(project)
        refreshTLList()
    end

    -- -- Marker Screenshots ----------------------------------------------------

    win.On.ScrFolderBtn.Clicked = function()
        local current = trim(itm.ScrFolderText.Text)
        local chosen  = nil
        pcall(function()
            chosen = fusion:RequestDir(current ~= "" and current or nil)
        end)
        if chosen and trim(chosen) ~= "" then
            -- Strip any trailing slash/backslash Resolve appends
            itm.ScrFolderText.Text = trim(chosen):gsub("[/\\]+$", "")
        end
    end

    win.On.ScrPreviewBtn.Clicked = function()
        logClear(itm.ScrLog)
        local color = itm.ScrColorCombo.CurrentText
        local currentTL = project:GetCurrentTimeline()
        if not currentTL then logAppend(itm.ScrLog, "No active timeline.", "err"); return end

        local curFPS = getTimelineFPS(currentTL)
        local ok1, markers = pcall(function() return currentTL:GetMarkers() end)
        if not ok1 or not markers then
            logAppend(itm.ScrLog, "GetMarkers() failed.", "err"); return
        end
        local hits = {}
        for fid, info in pairs(markers) do
            if (info["color"] or ""):lower() == color:lower() then hits[fid] = info end
        end
        local startF = getTimelineStartFrame(currentTL, curFPS)

        logAppend(itm.ScrLog, "-- PREVIEW - " .. color .. " markers --", "head")
        if tableLen(hits) == 0 then
            logAppend(itm.ScrLog, "No " .. color .. " markers on this timeline.", "warn"); return
        end
        logAppend(itm.ScrLog, tableLen(hits) .. " marker(s):", "ok")
        for _, fid in ipairs(sortedNumericKeys(hits)) do
            local info = hits[fid]
            local tc   = framesToTC(startF + fid, curFPS)
            local name = trim(info["name"] or "") ~= "" and info["name"] or "(no name)"
            logAppend(itm.ScrLog, "  " .. tc .. "   -   " .. name, "info")
        end
    end

    win.On.ScrClearBtn.Clicked = function() logClear(itm.ScrLog) end

    win.On.ScrQuickBtn.Clicked = function()
        logClear(itm.ScrLog)
        local outputDir = trim(itm.ScrFolderText.Text)
        local currentTL = project:GetCurrentTimeline()
        if not currentTL then logAppend(itm.ScrLog, "No active timeline.", "err"); return end
        if outputDir == "" then logAppend(itm.ScrLog, "Output folder is empty.", "err"); return end

        logAppend(itm.ScrLog, "-- Capture Current Frame --", "head")
        local function log(m, t) logAppend(itm.ScrLog, m, t) end
        local result = doQuickScreenshot(resolve, project, currentTL, outputDir, log)
        logAppend(itm.ScrLog, "\n" .. result.message, result.success and "ok" or "err")
    end

    win.On.ScrCaptureBtn.Clicked = function()
        logClear(itm.ScrLog)
        local color     = itm.ScrColorCombo.CurrentText
        local outputDir = trim(itm.ScrFolderText.Text)
        local currentTL = project:GetCurrentTimeline()
        if not currentTL then logAppend(itm.ScrLog, "No active timeline.", "err"); return end
        if outputDir == "" then logAppend(itm.ScrLog, "Output folder is empty.", "err"); return end

        local curFPS = getTimelineFPS(currentTL)
        logAppend(itm.ScrLog, "-- Capturing " .. color .. " markers --", "head")

        local function log(m, t) logAppend(itm.ScrLog, m, t) end
        local result = doMarkerScreenshots(resolve, project, currentTL, curFPS, color, outputDir, log)

        logAppend(itm.ScrLog, "\n" .. result.message, result.success and "ok" or "err")
    end

    -- -- Marker Insert ---------------------------------------------------------

    local function insMode()
        if itm.InsAudioMode.Checked    then return "audio"    end
        if itm.InsVideoMode.Checked    then return "video"    end
        if itm.InsGraphicsMode.Checked then return "graphics" end
        return "all"
    end

    local function setInsMode(mode)
        itm.InsAudioMode.Checked    = (mode == "audio")
        itm.InsVideoMode.Checked    = (mode == "video")
        itm.InsGraphicsMode.Checked = (mode == "graphics")
        itm.InsAllMode.Checked      = (mode == "all")
        refreshInsertClips(mode)
    end

    -- Mode checkboxes behave like radio buttons (mutually exclusive)
    win.On.InsAudioMode.Clicked    = function() setInsMode("audio")    end
    win.On.InsVideoMode.Clicked    = function() setInsMode("video")    end
    win.On.InsGraphicsMode.Clicked = function() setInsMode("graphics") end
    win.On.InsAllMode.Clicked      = function() setInsMode("all")      end

    win.On.InsRefreshBtn.Clicked = function()
        refreshInsertClips(insMode())
        logAppend(itm.InsLog, "Clip list refreshed.", "ok")
    end

    win.On.InsPreviewBtn.Clicked = function()
        logClear(itm.InsLog)
        local color  = itm.InsColorCombo.CurrentText
        local offset = tonumber(itm.InsOffsetSpin.Value) or 0
        offset = math.max(-999, math.min(999, math.floor(offset)))
        local mode   = insMode()
        local clip   = getSelectedInsertClip()
        local currentTL = project:GetCurrentTimeline()
        if not currentTL then logAppend(itm.InsLog, "No active timeline.", "err"); return end

        local curFPS = getTimelineFPS(currentTL)
        local ok1, markers = pcall(function() return currentTL:GetMarkers() end)
        if not ok1 then logAppend(itm.InsLog, "GetMarkers() failed.", "err"); return end
        local hits = {}
        for fid, info in pairs(markers or {}) do
            if (info["color"] or ""):lower() == color:lower() then hits[fid] = info end
        end
        local startF = getTimelineStartFrame(currentTL, curFPS)
        local offNote = offset ~= 0 and ("  offset " .. (offset>0 and "+" or "") .. offset .. "fr") or ""

        logAppend(itm.InsLog, "-- PREVIEW - " .. color .. " - " .. mode .. offNote .. " --", "head")
        logAppend(itm.InsLog, "Clip: " .. (clip and clip.name or "(none selected)"), "info")
        if tableLen(hits) == 0 then
            logAppend(itm.InsLog, "No " .. color .. " markers found.", "warn"); return
        end
        logAppend(itm.InsLog, tableLen(hits) .. " marker(s):", "ok")
        for _, fid in ipairs(sortedNumericKeys(hits)) do
            local info = hits[fid]
            local tc   = framesToTC(math.max(0, startF + fid + offset), curFPS)
            local name = trim(info["name"] or "") ~= "" and info["name"] or "(no name)"
            logAppend(itm.InsLog, "  " .. tc .. "   -   " .. name, "info")
        end
    end

    win.On.InsClearBtn.Clicked = function() logClear(itm.InsLog) end

    win.On.InsPlaceBtn.Clicked = function()
        logClear(itm.InsLog)
        local color  = itm.InsColorCombo.CurrentText
        local offset = tonumber(itm.InsOffsetSpin.Value) or 0
        offset = math.max(-999, math.min(999, math.floor(offset)))
        local mode   = insMode()
        local clip   = getSelectedInsertClip()
        local currentTL = project:GetCurrentTimeline()

        if not currentTL then logAppend(itm.InsLog, "No active timeline.", "err"); return end
        if not clip then
            logAppend(itm.InsLog, "No clip selected. Pick one from the list (Refresh if empty).", "err"); return
        end

        local curFPS = getTimelineFPS(currentTL)
        local offNote = offset ~= 0 and ("  offset " .. (offset>0 and "+" or "") .. offset .. "fr") or ""
        logAppend(itm.InsLog, "-- Marker Insert - " .. mode .. " - " .. color .. offNote .. " --", "head")

        local function log(m, t) logAppend(itm.InsLog, m, t) end
        local result = doMarkerInsert(resolve, project, currentTL, curFPS,
                                      color, clip.item, mode, offset, log)

        logAppend(itm.InsLog, "\n" .. result.message,
                  result.success and (result.errors > 0 and "warn" or "ok") or "err")
    end

    -- -- Track Overlay ---------------------------------------------------------

    -- Filter radio buttons for Track Overlay template picker
    local function setZoomFilter(mode)
        itm.ZoomFilterAdj.Checked      = (mode == "adjustment")
        itm.ZoomFilterVideo.Checked    = (mode == "video")
        itm.ZoomFilterGraphics.Checked = (mode == "graphics")
        itm.ZoomFilterAudio.Checked    = (mode == "audio")
        itm.ZoomFilterAll.Checked      = (mode == "all")
        refreshTemplates(false)
    end
    win.On.ZoomFilterAdj.Clicked      = function() setZoomFilter("adjustment") end
    win.On.ZoomFilterVideo.Clicked    = function() setZoomFilter("video")      end
    win.On.ZoomFilterGraphics.Clicked = function() setZoomFilter("graphics")   end
    win.On.ZoomFilterAudio.Clicked    = function() setZoomFilter("audio")      end
    win.On.ZoomFilterAll.Clicked      = function() setZoomFilter("all")        end

    win.On.ZoomTemplateRefreshBtn.Clicked = function()
        refreshTemplates(false)
        logAppend(itm.ZoomLog, "Template list refreshed.", "ok")
    end

    win.On.ZoomClearBtn.Clicked = function() logClear(itm.ZoomLog) end

    local function getZoomParams()
        local trackStr  = itm.ZoomTrackCombo.CurrentText
        local trackIdx  = tonumber(trackStr:sub(2)) or 1
        local tmplItem  = nil
        local tmplName  = itm.ZoomTemplateCombo.CurrentText
        for _, t in ipairs(state.poolTemplates) do
            if t.name == tmplName then tmplItem = t.item; break end
        end
        local currentTL = project:GetCurrentTimeline()
        return currentTL, trackIdx, tmplItem
    end

    win.On.ZoomDryRunBtn.Clicked = function()
        logClear(itm.ZoomLog)
        local tl, track, tmpl = getZoomParams()
        if not tl then logAppend(itm.ZoomLog, "No active timeline.", "err"); return end
        local curFPS = getTimelineFPS(tl)
        logAppend(itm.ZoomLog, "-- Dry Run V" .. track .. " --", "head")
        local function log(m, t) logAppend(itm.ZoomLog, m, t) end
        local result = doTrackOverlay(resolve, project, tl, mediaPool, curFPS, track, tmpl, true, log)
        logAppend(itm.ZoomLog, "\n" .. result.message, result.success and "info" or "err")
    end

    win.On.ZoomApplyBtn.Clicked = function()
        logClear(itm.ZoomLog)
        local tl, track, tmpl = getZoomParams()
        if not tl then logAppend(itm.ZoomLog, "No active timeline.", "err"); return end
        local clips = getEnabledClips(tl, track)
        if #clips == 0 then
            logAppend(itm.ZoomLog, "No enabled clips on V" .. track .. ".", "err"); return
        end
        local curFPS = getTimelineFPS(tl)
        logAppend(itm.ZoomLog, "-- Track Overlay V" .. track .. " --", "head")
        local function log(m, t) logAppend(itm.ZoomLog, m, t) end
        local result = doTrackOverlay(resolve, project, tl, mediaPool, curFPS, track, tmpl, false, log)
        logAppend(itm.ZoomLog, "\n" .. result.message,
                  result.success and (result.zoom_fail > 0 and "warn" or "ok") or "err")
    end

    -- -- Batch Export ----------------------------------------------------------

    -- Helper: get timelines selected in ExpTLList
    local function getExpSelectedTimelines()
        local sel = itm.ExpTLList:SelectedItems()
        local result = {}
        for _, item in pairs(sel) do
            local name = item.Text[0]
            for _, info in ipairs(state.allTimelines) do
                if info.name == name then
                    table.insert(result, info)
                    break
                end
            end
        end
        return result
    end

    win.On.ExpFilterText.TextChanged = function()
        -- Re-apply filter without re-scanning Resolve (fast, local filter only)
        local names = {}
        for _, info in ipairs(state.allTimelines) do table.insert(names, info.name) end
        local count = fillTree(itm.ExpTLList, names, itm.ExpFilterText.Text)
        if count > 0 then itm.ExpTLList:TopLevelItem(0).Selected = true end
    end
    win.On.ExpFilterClear.Clicked = function()
        itm.ExpFilterText.Text = ""   -- triggers TextChanged  ->  re-filters
    end

    win.On.ExpRefreshBtn.Clicked = function()
        refreshExpTLList()
        logAppend(itm.ExpLog,
            ("Timeline list refreshed (%d total, %d visible)."):format(
                #state.allTimelines, itm.ExpTLList:TopLevelItemCount()), "ok")
    end

    win.On.ExpFolderBtn.Clicked = function()
        local current = trim(itm.ExpFolderText.Text)
        local chosen  = nil
        pcall(function()
            chosen = fusion:RequestDir(current ~= "" and current or nil)
        end)
        if chosen and trim(chosen) ~= "" then
            itm.ExpFolderText.Text = trim(chosen):gsub("[/\\]+$", "")
        end
    end

    win.On.ExpClearBtn.Clicked = function() logClear(itm.ExpLog) end

    win.On.ExpQueueBtn.Clicked = function()
        logClear(itm.ExpLog)
        local selected   = getExpSelectedTimelines()
        local presetName = trim(itm.ExpPresetText.Text)
        local outputDir  = trim(itm.ExpFolderText.Text)
        local clearFirst = itm.ExpClearQueue.Checked

        if #selected == 0 then
            logAppend(itm.ExpLog, "No timelines selected.", "err"); return
        end
        if presetName == "" then
            logAppend(itm.ExpLog, "Render preset name is empty  -  enter the exact name from the Deliver page.", "err"); return
        end
        if outputDir == "" then
            logAppend(itm.ExpLog, "Output folder is empty.", "err"); return
        end

        logAppend(itm.ExpLog,
            ("-- Add to Queue - %d timeline(s) - Preset: %s --"):format(#selected, presetName), "head")

        local function log(m, t) logAppend(itm.ExpLog, m, t) end
        local result = doBatchExport(project, selected, presetName, outputDir, clearFirst, log)

        logAppend(itm.ExpLog, "\n" .. result.message,
                  result.errors > 0 and "warn" or "ok")
    end

    -- -- Window close ---------------------------------------------------------

    win.On[WIN_ID].Close = function()
        disp:ExitLoop()
    end

    -- -- Show ------------------------------------------------------------------

    win:Show()
    disp:RunLoop()
    win:Hide()
end

-- ============================================================
--  ENTRY POINT
-- ============================================================
-- In Resolve's Lua scripting environment, 'fusion' and 'bmd' are
-- pre-provided globals. We obtain 'resolve' via fusion:GetResolve().
-- The entire body is wrapped in pcall so any runtime error is written
-- to a log file rather than silently disappearing.

local function main()
    -- Workspace launches provide `fusion`; external fuscript launches do not.
    -- Resolve both contexts here so UI and file dialogs share one app handle.
    local resolveApp = bmd and bmd.scriptapp and bmd.scriptapp("Resolve")
    local fusionApp = fusion
        or (resolveApp and bmd.scriptapp("Fusion"))
    if not fusionApp then
        print("ERROR: 'fusion' global is not available. "
            .."Make sure External Scripting is set to Local in Preferences.")
        return
    end
    fusion = fusionApp

    local resolve = fusionApp:GetResolve() or resolveApp
    if not resolve then
        print("ERROR: Cannot connect to DaVinci Resolve.")
        return
    end

    local pm      = resolve:GetProjectManager()
    local project = pm:GetCurrentProject()
    if not project then
        print("ERROR: No project is open in Resolve.")
        return
    end

    local timeline = project:GetCurrentTimeline()   -- may be nil; window still opens
    local fps = timeline and getTimelineFPS(timeline) or 24.0
    if timeline then
        print(("Batch Export | %s | %s | %g fps"):format(
            project:GetName(), timeline:GetName(), fps))
    else
        print(("Batch Export | %s | (no active timeline)"):format(project:GetName()))
    end

    run(resolve, project, timeline, fps)
end

local ok, err = pcall(main)
if not ok then
    local msg = "Batch Export ERROR:\n" .. tostring(err)
    print(msg)
    -- Also write to a temp file so you can read it even if the Console isn't open
    local tmp
    if IS_WINDOWS then
        tmp = (os.getenv("TEMP") or os.getenv("TMP") or "C:\\Windows\\Temp") .. "\\batch_export_error.txt"
    else
        local dir = (os.getenv("TMPDIR") or "/tmp"):gsub("/+$", "")
        tmp = dir .. "/batch_export_error.txt"
    end
    local f = io.open(tmp, "w")
    if f then f:write(msg .. "\n"); f:close() end
end
