-- Krispy Tools product: resolve-video-differentiator
-- Release: 2026.2
-- Source SHA-256: 213f67b452e80b628ca78638991edb0251fad16414ce62ef14daddf932a890bd
--[[
Video Diff Marker for DaVinci Resolve
=====================================

Resolve-native front-end for comparing two video files and adding timeline
markers where the image changes.

Install:
  Windows:
    %APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Edit\
  macOS:
    ~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Edit/

Run:
  Workspace > Scripts > Edit > Video_Diff_Marker_Resolve

Important:
  Resolve scripting cannot read raw frame pixels by itself, so this Lua script
  calls ffmpeg/ffprobe in the background for analysis. Editors do not need to
  run a separate app.
--]]

local IS_WINDOWS = package.config:sub(1, 1) == "\\"
-- DaVinci Resolve on macOS does not inherit /usr/local/bin or /opt/homebrew/bin on its PATH,
-- so we call ffmpeg/ffprobe by absolute path on macOS to make sure Resolve can find them.
local FFMPEG = IS_WINDOWS and "ffmpeg" or "/usr/local/bin/ffmpeg"
local FFPROBE = IS_WINDOWS and "ffprobe" or "/usr/local/bin/ffprobe"
local OUTPUT_DIR
if IS_WINDOWS then
    OUTPUT_DIR = (os.getenv("LOCALAPPDATA") or os.getenv("APPDATA") or os.getenv("TEMP") or ".") .. [[\VideoDiffMarker]]
else
    OUTPUT_DIR = (os.getenv("HOME") or "/tmp") .. "/Library/Caches/VideoDiffMarker"
end
local SUPPORT_DIR = OUTPUT_DIR .. (IS_WINDOWS and [[\support]] or "/support")
local HIDDEN_LAUNCHER = SUPPORT_DIR .. [[\krispy_hidden_runner.vbs]]
local ENSURED_DIRS = {}

local DEFAULT_SAMPLE_RATE = 12.0
local DEFAULT_THRESHOLD = 3.5
local DEFAULT_MAX_DIFF_THRESHOLD = 28.0
local DEFAULT_CHANGED_PIXELS_PERCENT = 0.08
local DEFAULT_MAX_PIXEL_MIN_PERCENT = 0.02
local DEFAULT_LOCAL_AVG_MIN = 0.35
local DEFAULT_PIXEL_THRESHOLD = 26 -- FFmpeg diff black is usually 16, so 16 + 10.
local DEFAULT_GRAPHICS_SAMPLE_RATE = 8.0
local DEFAULT_GRAPHICS_WIDTH = 512
local DEFAULT_GRAPHICS_HEIGHT = 288
local DEFAULT_GRAPHICS_PIXEL_THRESHOLD = 28 -- 16 + 12; ignores gentle whole-frame drift.
local DEFAULT_GRAPHICS_MAX_DIFF = 50.0
local DEFAULT_GRAPHICS_CHANGED_PIXELS_PERCENT = 0.75
local DEFAULT_MERGE_GAP = 0.75
local DEFAULT_GRAPHICS_REFINE_MARGIN = 0.35
local DEFAULT_GRAPHICS_FINAL_MERGE_GAP = 0.10
local DEFAULT_GRAPHICS_TAIL_TRIM_PEAK_AVG = 10.0
local DEFAULT_GRAPHICS_TAIL_AVG_RATIO = 0.20
local DEFAULT_GRAPHICS_TAIL_CHANGED_RATIO = 0.20
local DEFAULT_TEMPORAL_PADDING = 0
local DEFAULT_PROXY_LONG_EDGE = 256
local DEFAULT_WIDTH = 256
local DEFAULT_HEIGHT = 256
local DEFAULT_REFINE_MARGIN = 1.5
local DEFAULT_REFINE_BATCH_GAP = 6.0
local DEFAULT_REFINE_BATCH_MAX_DURATION = 28.0

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

local function trim(s)
    return (s or ""):match("^%s*(.-)%s*$")
end

local function quote(path)
    if IS_WINDOWS then
        return '"' .. tostring(path):gsub('"', '\\"') .. '"'
    end
    return "'" .. tostring(path):gsub("'", "'\\''") .. "'"
end

local function file_exists(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

-- macOS: Resolve does not inherit the user shell PATH, so look in the usual install
-- folders first and then ask a login zsh where the tool lives.
local function find_mac_tool(name)
    local home = os.getenv("HOME") or ""
    local dirs = { "/opt/homebrew/bin/", "/usr/local/bin/", "/opt/local/bin/", home .. "/bin/", home .. "/.local/bin/", "/usr/bin/" }
    for _, dir in ipairs(dirs) do
        if file_exists(dir .. name) then return dir .. name end
    end
    local h = io.popen("/bin/zsh -lc 'command -v " .. name .. "' 2>/dev/null")
    if h then
        local out = h:read("*a") or ""
        h:close()
        for line in out:gmatch("[^\r\n]+") do
            line = trim(line)
            if line:sub(1, 1) == "/" and file_exists(line) then return line end
        end
    end
    return "/usr/local/bin/" .. name
end

if not IS_WINDOWS then
    FFMPEG = find_mac_tool("ffmpeg")
    FFPROBE = find_mac_tool("ffprobe")
end

-- Executable for a shell command line: bare name on Windows, quoted absolute path on macOS.
local function exe(path)
    if IS_WINDOWS then return path end
    return quote(path)
end

local FFMPEG_HELP = IS_WINDOWS and "FFmpeg failed. Make sure ffmpeg is installed and available on PATH."
    or "FFmpeg failed. Install it with Homebrew (brew install ffmpeg), then restart DaVinci Resolve."

local function ensure_dir(path)
    path = tostring(path or "")
    if path == "" or ENSURED_DIRS[path] then return end
    ENSURED_DIRS[path] = true
    if IS_WINDOWS then
        os.execute('mkdir ' .. quote(path) .. ' >nul 2>nul')
    else
        os.execute('mkdir -p ' .. quote(path))
    end
end

local EMBEDDED_HIDDEN_LAUNCHER = [===[
Option Explicit
' Krispy Tools hidden runner: starts a batch file without a console window and
' waits for its done file. If the cancel file appears, it stops the batch and
' everything it started. No Python needed.
Dim fso, shell, svc, batchFile, doneFile, cancelFile, token, ticks, procs, p
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

If WScript.Arguments.Count < 2 Then WScript.Quit 2
batchFile = WScript.Arguments(0)
doneFile = WScript.Arguments(1)
cancelFile = ""
If WScript.Arguments.Count > 2 Then cancelFile = WScript.Arguments(2)
token = fso.GetFileName(batchFile)

shell.Run "cmd.exe /d /s /c " & Chr(34) & Chr(34) & batchFile & Chr(34) & Chr(34), 0, False

On Error Resume Next
Set svc = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
On Error GoTo 0

ticks = 0
Do While Not fso.FileExists(doneFile)
    WScript.Sleep 150
    ticks = ticks + 1
    If cancelFile <> "" Then
        If fso.FileExists(cancelFile) Then
            StopBatch
            WriteDone "-2"
            WScript.Quit 0
        End If
    End If
    ' Every ~3 s, make sure the batch is still alive so a crash cannot hang Resolve.
    If ticks Mod 20 = 0 And IsObject(svc) Then
        If Not fso.FileExists(doneFile) Then
            If CountBatch() = 0 And Not fso.FileExists(doneFile) Then
                WScript.Sleep 300
                If Not fso.FileExists(doneFile) Then WriteDone "1"
            End If
        End If
    End If
Loop
WScript.Quit 0

Function CountBatch()
    CountBatch = 1
    On Error Resume Next
    Set procs = svc.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name = 'cmd.exe' AND CommandLine LIKE '%" & token & "%'")
    If Err.Number = 0 Then CountBatch = procs.Count
    On Error GoTo 0
End Function

Sub StopBatch()
    If Not IsObject(svc) Then Exit Sub
    On Error Resume Next
    Set procs = svc.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name = 'cmd.exe' AND CommandLine LIKE '%" & token & "%'")
    For Each p In procs
        shell.Run "taskkill /F /T /PID " & p.ProcessId, 0, True
    Next
    On Error GoTo 0
End Sub

Sub WriteDone(code)
    Dim f
    Set f = fso.CreateTextFile(doneFile, True)
    f.Write code
    f.Close
End Sub

]===]

local function read_all(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*all")
    f:close()
    return data
end

local function write_text_if_changed(path, text)
    if read_all(path) == text then return true end
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(text)
    f:close()
    return true
end

local function ensure_hidden_runner()
    if not IS_WINDOWS then return true end
    ensure_dir(SUPPORT_DIR)
    return write_text_if_changed(HIDDEN_LAUNCHER, EMBEDDED_HIDDEN_LAUNCHER)
end

-- Windows: write the command as a batch file that captures output and the exit code.
-- chcp 65001 keeps non-ASCII file paths working; % is doubled for batch syntax.
local function write_windows_batch(batch_path, cmd, out_file, done_file)
    local f = io.open(batch_path, "wb")
    if not f then return false end
    local escaped = (tostring(cmd):gsub("%%", "%%%%"))
    f:write("@echo off\r\n")
    f:write("chcp 65001 >nul\r\n")
    f:write(escaped .. " > " .. quote(out_file) .. " 2>&1\r\n")
    f:write("> " .. quote(done_file .. ".tmp") .. " echo %ERRORLEVEL%\r\n")
    f:write("move /y " .. quote(done_file .. ".tmp") .. " " .. quote(done_file) .. " >nul\r\n")
    f:close()
    return true
end

local function launch_hidden_windows(batch_path, done_file, cancel_file)
    local launch = 'start "" wscript.exe //B //Nologo ' .. quote(HIDDEN_LAUNCHER) .. " " .. quote(batch_path) .. " " .. quote(done_file)
    if cancel_file then launch = launch .. " " .. quote(cancel_file) end
    os.execute(launch)
end

local TEMP_COUNTER = 0
local function temp_run_paths()
    TEMP_COUNTER = TEMP_COUNTER + 1
    ensure_dir(OUTPUT_DIR)
    local sep = IS_WINDOWS and "\\" or "/"
    local base = OUTPUT_DIR .. sep .. "video_diff_" .. tostring(os.time()) .. "_" .. tostring(TEMP_COUNTER)
    return base .. (IS_WINDOWS and ".run.cmd" or ".cmd.txt"), base .. ".out.log", base .. ".done.txt", base .. ".cancel"
end

local function popen_read(cmd)
    if IS_WINDOWS and not ensure_hidden_runner() then
        return nil, "Could not prepare hidden command runner."
    end
    if IS_WINDOWS and file_exists(HIDDEN_LAUNCHER) then
        local cmd_file, out_file, done_file = temp_run_paths()
        if not write_windows_batch(cmd_file, cmd, out_file, done_file) then return nil, "Could not prepare command file" end
        launch_hidden_windows(cmd_file, done_file, nil)

        local deadline = os.time() + 20
        while not file_exists(done_file) do
            if os.time() > deadline then
                return nil, "Command timed out"
            end
            pcall(function() bmd.wait(0.1) end)
        end

        local out = ""
        local fout = io.open(out_file, "r")
        if fout then
            out = fout:read("*all") or ""
            fout:close()
        end
        local exit_code = 1
        local fdone = io.open(done_file, "r")
        if fdone then
            exit_code = tonumber(fdone:read("*a") or "1") or 1
            fdone:close()
        end
        if exit_code ~= 0 then return out, "Command failed" end
        return out, nil
    end

    local f = io.popen(cmd, "r")
    if not f then return nil, "Could not run command" end
    local out = f:read("*all")
    local ok = f:close()
    if not ok then return out, "Command failed" end
    return out, nil
end

local function parse_fraction(text)
    if not text or text == "" then return nil end
    local a, b = tostring(text):match("([%d%.]+)%s*/%s*([%d%.]+)")
    if a and b then
        b = tonumber(b)
        if b and b ~= 0 then return tonumber(a) / b end
    end
    return tonumber(text)
end

local function get_timeline_fps(resolve)
    local ok, fps = pcall(function()
        local project = resolve:GetProjectManager():GetCurrentProject()
        local timeline = project and project:GetCurrentTimeline()
        local timeline_fps = timeline and timeline:GetSetting("timelineFrameRate")
        if timeline_fps and timeline_fps ~= "" then return timeline_fps end
        return project and project:GetSetting("timelineFrameRate")
    end)
    if ok then return parse_fraction(fps) end
    return nil
end

local function probe_duration(path)
    local cmd = exe(FFPROBE) .. " -v error -show_entries format=duration -of default=nw=1:nk=1 " .. quote(path)
    local out = popen_read(cmd)
    return tonumber(trim(out or ""))
end

local function probe_fps(path)
    local cmd = exe(FFPROBE) .. " -v error -select_streams v:0 -show_entries stream=avg_frame_rate,r_frame_rate -of default=nw=1:nk=1 " .. quote(path)
    local out = popen_read(cmd)
    if not out then return nil end
    for line in out:gmatch("[^\r\n]+") do
        local fps = parse_fraction(trim(line))
        if fps and fps > 0 then return fps end
    end
    return nil
end

local function probe_dimensions(path)
    local cmd = exe(FFPROBE) .. " -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x " .. quote(path)
    local out = popen_read(cmd)
    if not out then return nil, nil end
    local w, h = out:match("(%d+)%s*x%s*(%d+)")
    return tonumber(w), tonumber(h)
end

local function round_even(value)
    value = tonumber(value) or 0
    local rounded = math.floor(value / 2 + 0.5) * 2
    return math.max(16, rounded)
end

local function proxy_size_for_source(width, height)
    width, height = tonumber(width), tonumber(height)
    if not width or not height or width <= 0 or height <= 0 then
        return DEFAULT_WIDTH, DEFAULT_HEIGHT
    end
    if width >= height then
        return DEFAULT_PROXY_LONG_EDGE, round_even(DEFAULT_PROXY_LONG_EDGE * height / width)
    end
    return round_even(DEFAULT_PROXY_LONG_EDGE * width / height), DEFAULT_PROXY_LONG_EDGE
end

local function show_message(title, text)
    local ui = fusion.UIManager
    local disp = bmd.UIDispatcher(ui)
    local win = disp:AddWindow({
        ID = "VideoDiffMessage",
        WindowTitle = title,
        Geometry = { 500, 300, 660, 300 },
        MinimumSize = { 660, 300 },
        StyleSheet = SS.win,
    }, {
        ui:VGroup{ Spacing = 12, Margin = 18,
            ui:Label({ Text = text, WordWrap = true, Weight = 1, StyleSheet = SS.label }),
            ui:HGroup{ Weight = 0, MinimumSize = { 0, 58 },
                ui:HGap(0),
                ui:Button({ ID = "OK", Text = "OK", MinimumSize = { 150, 42 }, StyleSheet = SS.btn_acc }),
                ui:HGap(0),
            },
            ui:VGap(6),
        },
    })
    win.On.OK.Clicked = function()
        disp:ExitLoop()
    end
    win.On.VideoDiffMessage.Close = function()
        disp:ExitLoop()
    end
    win:Show()
    disp:RunLoop()
    win:Hide()
end

local function get_clip_path(candidate)
    if not candidate then return nil end
    local ok, path = pcall(function()
        return candidate:GetClipProperty("File Path")
    end)
    if ok and path and path ~= "" then return path end
    return nil
end

local function filename_from_path(path)
    return tostring(path or ""):match("[^/\\]+$") or tostring(path or "")
end

local function get_clip_label(candidate, path)
    local ok, name = pcall(function()
        return candidate:GetClipProperty("Clip Name")
    end)
    if ok and name and name ~= "" then return name end
    return filename_from_path(path)
end

local function add_clip_option(options, seen, path, label, prefix, role)
    if not path or path == "" or seen[path] then return end
    seen[path] = true
    table.insert(options, {
        path = path,
        label = (prefix or "") .. label,
        role = role or "",
    })
end

local function collect_folder_clips(folder, options, seen, depth)
    if not folder or depth > 6 then return end
    local ok_clips, clips = pcall(function() return folder:GetClipList() end)
    if ok_clips and clips then
        for key, value in pairs(clips) do
            for _, candidate in ipairs({ value, key }) do
                local path = get_clip_path(candidate)
                if path then add_clip_option(options, seen, path, get_clip_label(candidate, path), "") end
            end
        end
    end
    local ok_folders, folders = pcall(function() return folder:GetSubFolderList() end)
    if ok_folders and folders then
        for key, value in pairs(folders) do
            collect_folder_clips(value, options, seen, depth + 1)
            collect_folder_clips(key, options, seen, depth + 1)
        end
    end
end

local function timeline_item_path(item)
    if not item then return "" end
    local ok_media, media_item = pcall(function() return item:GetMediaPoolItem() end)
    if ok_media and media_item then
        local ok_path, path = pcall(function() return media_item:GetClipProperty("File Path") end)
        if ok_path and path and path ~= "" then return path end
    end
    local ok_clip_path, clip_path = pcall(function() return item:GetClipProperty("File Path") end)
    if ok_clip_path and clip_path and clip_path ~= "" then return clip_path end
    return ""
end

local function timecode_to_frames(tc, fps)
    local h, m, s, f = tostring(tc or ""):match("(%d+):(%d+):(%d+):(%d+)")
    if not h then return nil end
    fps = math.floor((tonumber(fps) or 24) + 0.5)
    return tonumber(f) + tonumber(s) * fps + tonumber(m) * 60 * fps + tonumber(h) * 3600 * fps
end

local function get_timeline_pair(resolve)
    local ok_project, project = pcall(function() return resolve:GetProjectManager():GetCurrentProject() end)
    if not ok_project or not project then return nil end
    local ok_timeline, timeline = pcall(function() return project:GetCurrentTimeline() end)
    if not ok_timeline or not timeline then return nil end

    local timeline_fps = parse_fraction(timeline:GetSetting("timelineFrameRate")) or parse_fraction(project:GetSetting("timelineFrameRate")) or 24
    local timeline_start = 0
    pcall(function() timeline_start = timeline:GetStartFrame() or 0 end)
    local playhead_frame = nil
    local ok_tc, tc = pcall(function() return timeline:GetCurrentTimecode() end)
    if ok_tc then playhead_frame = timecode_to_frames(tc, timeline_fps) end

    local clips = {}
    local track_count = 0
    pcall(function() track_count = timeline:GetTrackCount("video") or 0 end)
    for track = 1, track_count do
        local ok_items, items = pcall(function() return timeline:GetItemListInTrack("video", track) end)
        if ok_items and items then
            for _, item in pairs(items) do
                local path = timeline_item_path(item)
                local ok_start, start_frame = pcall(function() return item:GetStart() end)
                local ok_end, end_frame = pcall(function() return item:GetEnd() end)
                if path ~= "" and ok_start and ok_end and start_frame and end_frame and end_frame > start_frame then
                    table.insert(clips, {
                        path = path,
                        label = filename_from_path(path),
                        track = track,
                        start_frame = tonumber(start_frame),
                        end_frame = tonumber(end_frame),
                        duration = tonumber(end_frame) - tonumber(start_frame),
                    })
                end
            end
        end
    end

    if #clips < 2 then return nil end

    local function overlaps_playhead(clip)
        if not playhead_frame then return false end
        local candidates = { playhead_frame, playhead_frame - timeline_start }
        for _, frame in ipairs(candidates) do
            if frame >= clip.start_frame and frame < clip.end_frame then return true end
        end
        return false
    end

    local active = {}
    for _, clip in ipairs(clips) do
        if overlaps_playhead(clip) then table.insert(active, clip) end
    end
    table.sort(active, function(a, b) return a.track > b.track end)
    if #active >= 2 then
        return { new_clip = active[1], old_clip = active[2], reason = "playhead overlap" }
    end

    table.sort(clips, function(a, b)
        if a.start_frame ~= b.start_frame then return a.start_frame < b.start_frame end
        return a.track > b.track
    end)
    for i = 1, #clips do
        for j = i + 1, #clips do
            local a, b = clips[i], clips[j]
            if a.path ~= b.path and a.start_frame == b.start_frame and a.end_frame == b.end_frame and a.track ~= b.track then
                if a.track > b.track then
                    return { new_clip = a, old_clip = b, reason = "matching timeline range" }
                end
                return { new_clip = b, old_clip = a, reason = "matching timeline range" }
            end
        end
    end

    return nil
end

local function get_media_pool_options(resolve, selected_paths)
    local options, seen = {}, {}
    local timeline_pair = get_timeline_pair(resolve)
    if timeline_pair then
        add_clip_option(options, seen, timeline_pair.old_clip.path, timeline_pair.old_clip.label, "Timeline Old (lower track): ", "old")
        add_clip_option(options, seen, timeline_pair.new_clip.path, timeline_pair.new_clip.label, "Timeline New (top track): ", "new")
    end
    for i, path in ipairs(selected_paths or {}) do
        add_clip_option(options, seen, path, filename_from_path(path), "Selected " .. i .. ": ")
    end

    local ok, media_pool = pcall(function()
        return resolve:GetProjectManager():GetCurrentProject():GetMediaPool()
    end)
    if ok and media_pool then
        local ok_folder, folder = pcall(function() return media_pool:GetCurrentFolder() end)
        if ok_folder and folder then collect_folder_clips(folder, options, seen, 0) end
        local ok_root, root = pcall(function() return media_pool:GetRootFolder() end)
        if ok_root and root and root ~= folder then collect_folder_clips(root, options, seen, 0) end
    end
    return options
end

local function request_settings(resolve, selected_paths)
    local ui = fusion.UIManager
    local disp = bmd.UIDispatcher(ui)
    local result = nil
    local state = {
        selected_index = nil,
        old_index = nil,
        new_index = nil,
        filtered_indices = {},
    }
    local base_options = get_media_pool_options(resolve, selected_paths)
    if #base_options == 0 then
        show_message("Video Diff Marker", "No Media Pool video clips were found in the selected clips or current bin. Select two clips in the Media Pool, then run the script again.")
        return nil
    end
    for i, option in ipairs(base_options) do
        if option.role == "old" then state.old_index = i end
        if option.role == "new" then state.new_index = i end
    end
    state.new_index = state.new_index or 1
    state.old_index = state.old_index or math.min(2, #base_options)

    local timeline_fps = get_timeline_fps(resolve)
    if not timeline_fps then
        show_message("Video Diff Marker", "Could not read the current timeline FPS. Open a timeline before running the script.")
        return nil
    end
    local fps_text = string.format("Timeline FPS: %.6g", timeline_fps)

    local function sep()
        return ui:Label{Weight=0, MinimumSize={1,1}, MaximumSize={9999,1}, StyleSheet=SS.sep}
    end

    local function setting_row(label, id, value, help)
        return ui:HGroup{Weight=0, Spacing=8,
            ui:Label{Weight=0, Text=label, StyleSheet=SS.label, MinimumSize={108,0}},
            ui:LineEdit{ID=id, Text=tostring(value), StyleSheet=SS.input, MinimumSize={82,0}, MaximumSize={82,9999}},
            ui:Label{Weight=1, Text=help, StyleSheet=SS.dim, WordWrap=true},
        }
    end

    local SIDE_GUTTER = 28
    local BOTTOM_GUTTER = 20
    local win = disp:AddWindow({
        ID = "VideoDiffMarkerGraphite2026V14",
        WindowTitle = "Video Diff Marker",
        Geometry = { 60, 30, 1260, 720 },
        MinimumSize = { 1100, 700 },
        StyleSheet = SS.win,
    }, {
        ui:VGroup{Spacing=0,
            ui:VGap(20),
            ui:HGroup{Weight=1, Spacing=0,
                ui:HGap(SIDE_GUTTER),
                ui:VGroup{Spacing=6, Weight=1,
                    ui:HGroup{Weight=0, Spacing=12, MinimumSize={0,34}, MaximumSize={9999,34},
                        ui:Label{Weight=0, MinimumSize={5,34}, MaximumSize={5,34}, StyleSheet=SS.bar},
                        ui:Label{Weight=1, Text="Video Diff Marker", StyleSheet=SS.title, MinimumSize={0,34}, MaximumSize={9999,34}},
                    },
                    ui:Label{Weight=0, MinimumSize={0,34}, MaximumSize={9999,34},
                        Text="Choose two clips. If two same-length clips are stacked on the timeline, the lower track is Old and the top track is New automatically.",
                        StyleSheet=SS.dim, WordWrap=true},
                    ui:HGroup{Weight=0, Spacing=6, MinimumSize={0,42}, MaximumSize={9999,42},
                        ui:Button{ID="Run", Text="Compare + Add Markers", StyleSheet=SS.btn_acc, MinimumSize={250,36}, MaximumSize={250,36}, Weight=0},
                        ui:Label{Weight=1},
                    },
                    sep(),
                    ui:HGroup{ID="Workspace", Weight=0, Spacing=26, MinimumSize={0,340}, MaximumSize={9999,340},
                        ui:VGroup{ID="ClipBrowserPanel", Weight=3, Spacing=8,
                            ui:HGroup{Weight=0, Spacing=10, MinimumSize={0,24}, MaximumSize={9999,24},
                                ui:Label{Weight=1, Text="Clip Browser", StyleSheet=SS.label, MinimumSize={0,24}, MaximumSize={9999,24}},
                                ui:Label{ID="ClipCount", Text="", StyleSheet=SS.dim, Weight=0, Alignment={AlignRight=true, AlignVCenter=true}, MinimumSize={150,24}, MaximumSize={150,24}},
                            },
                            ui:LineEdit{ID="ClipSearch", StyleSheet=SS.input, PlaceholderText="Filter clips by name or path...", Weight=0, MinimumSize={0,38}, MaximumSize={9999,38}},
                            ui:Tree{
                                ID="ClipList", Weight=1,
                                SortingEnabled=false, AlternatingRowColors=true,
                                HeaderHidden=false, RootIsDecorated=false,
                                StyleSheet=SS.tree,
                            },
                            ui:HGroup{Weight=0, Spacing=10, MinimumSize={0,42}, MaximumSize={9999,42},
                                ui:Label{Weight=0, Text="Old / Reference", StyleSheet=SS.label, MinimumSize={120,38}, MaximumSize={120,38}},
                                ui:Label{ID="OldSelected", Text="(none)", Weight=1, StyleSheet=SS.dim, Alignment={AlignVCenter=true}},
                                ui:Button{ID="SetOld", Text="Set Old", StyleSheet=SS.btn, Weight=0, MinimumSize={130,38}, MaximumSize={130,38}},
                            },
                            ui:HGroup{Weight=0, Spacing=10, MinimumSize={0,42}, MaximumSize={9999,42},
                                ui:Label{Weight=0, Text="New / Updated", StyleSheet=SS.label, MinimumSize={120,38}, MaximumSize={120,38}},
                                ui:Label{ID="NewSelected", Text="(none)", Weight=1, StyleSheet=SS.dim, Alignment={AlignVCenter=true}},
                                ui:Button{ID="SetNew", Text="Set New", StyleSheet=SS.btn, Weight=0, MinimumSize={130,38}, MaximumSize={130,38}},
                            },
                        },
                        ui:VGroup{ID="DetectionPanel", Weight=2, Spacing=10,
                            ui:Label{Weight=0, Text="Detection", StyleSheet=SS.label, MinimumSize={0,24}, MaximumSize={9999,24}},
                            ui:Label{Weight=0, Text="Tune how aggressively the two clips are compared.", StyleSheet=SS.dim, WordWrap=true, MinimumSize={0,34}, MaximumSize={9999,34}},
                            sep(),
                            ui:HGroup{Weight=0, Spacing=8, MinimumSize={0,28}, MaximumSize={9999,28},
                                ui:CheckBox{ID="TwoPass", Text="Two-pass exact scan", Checked=true, StyleSheet=SS.label, Weight=1},
                                ui:Label{Text=fps_text, StyleSheet=SS.dim, Weight=0, Alignment={AlignRight=true, AlignVCenter=true}, MinimumSize={130,28}, MaximumSize={130,28}},
                            },
                            ui:HGroup{Weight=0, Spacing=8, MinimumSize={0,42}, MaximumSize={9999,42},
                                ui:CheckBox{ID="GraphicsPass", Text="Localized graphics/color pass", Checked=true, StyleSheet=SS.label, Weight=1},
                                ui:Label{Text="Catches small UI and color-only edits", StyleSheet=SS.dim, Weight=1, WordWrap=true, Alignment={AlignRight=true, AlignVCenter=true}},
                            },
                            sep(),
                            setting_row("Fast scan fps", "SampleRate", DEFAULT_SAMPLE_RATE, "First-pass samples per second. Higher values catch shorter flashes."),
                            setting_row("Average change", "Threshold", DEFAULT_THRESHOLD, "Overall brightness change needed to flag a moment."),
                            setting_row("Peak change", "MaxDiff", DEFAULT_MAX_DIFF_THRESHOLD, "Single-pixel and edge change threshold."),
                            setting_row("Changed pixels %", "ChangedPct", DEFAULT_CHANGED_PIXELS_PERCENT, "Minimum changed area used with Peak change."),
                            ui:VGap(1),
                        },
                    },
                    sep(),
                    ui:Label{Weight=0, Text="Log", StyleSheet=SS.dim, MinimumSize={0,20}, MaximumSize={9999,20}},
                    ui:HGroup{Weight=0, Spacing=0, MinimumSize={0,90}, MaximumSize={9999,90},
                        ui:TextEdit{ID="RunLog", Weight=1, ReadOnly=true, StyleSheet=SS.log},
                    },
                    ui:Label{ID="Status", Text="", Weight=0, StyleSheet=SS.dim, MinimumSize={0,20}, MaximumSize={9999,20}},
                },
                ui:HGap(SIDE_GUTTER),
            },
            ui:VGap(BOTTOM_GUTTER),
        },
    })

    local itm = win:GetItems()
    itm.ClipList.ColumnCount = 2
    itm.ClipList:SetHeaderLabels({"Clip", "Path"})
    itm.ClipList.ColumnWidth[0] = 250
    itm.ClipList.ColumnWidth[1] = 430
    itm.RunLog.HTML = '<span style="color:' .. C.fg_dim .. '">Ready. Select clips and run comparison.</span><br>'

    local function log(msg, color)
        color = color or C.fg_dim
        local safe = tostring(msg):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")
        itm.RunLog.HTML = itm.RunLog.HTML .. ('<span style="color:%s">%s</span><br>'):format(color, safe)
    end

    local function option_text(index)
        local option = base_options[index]
        if not option then return "(none)" end
        return option.label
    end

    local function update_selected_labels()
        itm.OldSelected.Text = option_text(state.old_index)
        itm.NewSelected.Text = option_text(state.new_index)
    end

    local function repopulate_clip_tree(query)
        query = (query or ""):lower()
        itm.ClipList:Clear()
        state.filtered_indices = {}
        for i, option in ipairs(base_options) do
            local hay = (option.label .. " " .. option.path):lower()
            if query == "" or hay:find(query, 1, true) then
                table.insert(state.filtered_indices, i)
                local row = itm.ClipList:NewItem()
                row.Text[0] = option.label
                row.Text[1] = option.path
                itm.ClipList:AddTopLevelItem(row)
            end
        end
        itm.ClipCount.Text = #state.filtered_indices .. " clip(s) shown"
        itm.Status.Text = ""
    end

    update_selected_labels()
    repopulate_clip_tree("")

    win.On.ClipSearch.TextChanged = function()
        repopulate_clip_tree(itm.ClipSearch.Text)
    end

    win.On.ClipList.CurrentItemChanged = function()
        local item = itm.ClipList:CurrentItem()
        if not item then return end
        local path = item.Text[1]
        for i, option in ipairs(base_options) do
            if option.path == path then
                state.selected_index = i
                itm.Status.Text = "Selected: " .. option.label
                return
            end
        end
    end

    win.On.SetOld.Clicked = function()
        if state.selected_index then
            state.old_index = state.selected_index
            update_selected_labels()
            log("Old/reference set: " .. option_text(state.old_index), C.ok)
        else
            itm.Status.Text = "Select a clip from the list first."
        end
    end

    win.On.SetNew.Clicked = function()
        if state.selected_index then
            state.new_index = state.selected_index
            update_selected_labels()
            log("New/updated set: " .. option_text(state.new_index), C.ok)
        else
            itm.Status.Text = "Select a clip from the list first."
        end
    end

    local function close_win() disp:ExitLoop() end
    win.On.VideoDiffMarkerGraphite2026V14.Close = close_win
    win.On.Run.Clicked = function()
        local old_path = base_options[state.old_index] and base_options[state.old_index].path or ""
        local new_path = base_options[state.new_index] and base_options[state.new_index].path or ""
        local two_pass = itm.TwoPass.Checked
        local sample_rate = tonumber(itm.SampleRate.Text) or DEFAULT_SAMPLE_RATE
        if two_pass then
            sample_rate = math.min(timeline_fps, math.max(sample_rate, DEFAULT_SAMPLE_RATE))
        end
        result = {
            old_path = trim(old_path),
            new_path = trim(new_path),
            sample_rate = sample_rate,
            threshold = tonumber(itm.Threshold.Text) or DEFAULT_THRESHOLD,
            max_diff = tonumber(itm.MaxDiff.Text) or DEFAULT_MAX_DIFF_THRESHOLD,
            changed_pct = tonumber(itm.ChangedPct.Text) or DEFAULT_CHANGED_PIXELS_PERCENT,
            max_pixel_min_pct = DEFAULT_MAX_PIXEL_MIN_PERCENT,
            graphics_pass = itm.GraphicsPass.Checked,
            local_avg_min = DEFAULT_LOCAL_AVG_MIN,
            fps = timeline_fps,
            two_pass = two_pass,
            frame_accurate = false,
        }
        log("Starting comparison...", C.accent)
        disp:ExitLoop()
    end

    win:Show()
    disp:RunLoop()
    win:Hide()
    return result
end

local function get_selected_media_paths(resolve)
    local paths = {}
    local project = resolve:GetProjectManager():GetCurrentProject()
    if not project then return paths end
    local media_pool = project:GetMediaPool()
    if not media_pool then return paths end
    local selected = media_pool:GetSelectedClips()
    if not selected then return paths end

    local function try_add_path(candidate)
        if not candidate then return end
        local ok, path = pcall(function()
            return candidate:GetClipProperty("File Path")
        end)
        if ok and path and path ~= "" then
            table.insert(paths, path)
        end
    end

    for key, value in pairs(selected) do
        try_add_path(value)
        try_add_path(key)
    end
    return paths
end

local function seconds_to_frame(seconds, fps)
    return math.floor(seconds * fps + 0.5)
end

local function frame_to_seconds(frame, fps)
    if not fps or fps <= 0 then return 0 end
    return frame / fps
end

local function build_ffmpeg_command(settings)
    local duration_filter = ""
    if settings.compare_duration and settings.compare_duration > 0 then
        duration_filter = ",tpad=stop_mode=clone:stop_duration=36000,trim=duration=" .. string.format("%.6f", settings.compare_duration)
    end
    local proxy_width = settings.proxy_width or DEFAULT_WIDTH
    local proxy_height = settings.proxy_height or DEFAULT_HEIGHT
    local pixel_threshold = DEFAULT_PIXEL_THRESHOLD
    local input_format = "gray"
    -- Offset the difference by 16 so it matches the "-16" applied when reading
    -- signalstats and the 16+N blackframe thresholds. Without the offset, whole-frame
    -- changes under ~16 luma levels (grades, exposure tweaks) were read as zero.
    -- format=gray pins the pixel format so ffmpeg cannot silently range-convert the
    -- difference image before signalstats/blackframe (that happens with files tagged
    -- as limited-range BT.709 and made every frame look changed).
    local blend = "blend=all_expr=abs(A-B)+16,format=gray"
    local stats_pin = "format=gray,"

    if settings.localized_graphics then
        proxy_width = settings.proxy_width or DEFAULT_GRAPHICS_WIDTH
        proxy_height = settings.proxy_height or DEFAULT_GRAPHICS_HEIGHT
        pixel_threshold = DEFAULT_GRAPHICS_PIXEL_THRESHOLD
        input_format = "rgb24"
        blend = "blend=all_expr=abs(A-B)+16,format=yuv444p"
        stats_pin = ""
    end

    local scale = "fps=" .. string.format("%.6f", settings.sample_rate) ..
        ",scale=" .. proxy_width .. ":" .. proxy_height .. ":force_original_aspect_ratio=decrease" ..
        ",pad=" .. proxy_width .. ":" .. proxy_height .. ":(ow-iw)/2:(oh-ih)/2" ..
        ",format=" .. input_format .. duration_filter .. ",setpts=PTS-STARTPTS"

    local filter = "[0:v]" .. scale .. "[a];" ..
        "[1:v]" .. scale .. "[b];" ..
        "[a][b]" .. blend .. ",signalstats," .. stats_pin ..
        "blackframe=amount=0:threshold=" .. pixel_threshold .. "," ..
        "metadata=print:file=-"

    local seek = ""
    if settings.offset and settings.offset > 0 then
        seek = " -ss " .. string.format("%.6f", settings.offset)
    end

    return exe(FFMPEG) .. " -hide_banner -loglevel error -threads 0 -filter_threads 0 -filter_complex_threads 0" .. seek .. " -i " .. quote(settings.old_path) ..
        seek .. " -i " .. quote(settings.new_path) ..
        " -filter_complex " .. quote(filter) ..
        " -an -f null -"
end

local function progress_bar_text(percent)
    percent = math.max(0, math.min(100, percent or 0))
    local width = 34
    local filled = math.floor(width * percent / 100 + 0.5)
    return "[" .. string.rep("#", filled) .. string.rep("-", width - filled) .. "] " .. string.format("%3.0f%%", percent)
end

-- macOS: run ffmpeg in the background, stop it if the cancel file appears, and
-- write the exit code through a temp file so the poller never reads a half-written file.
local function write_posix_script(script_path, cmd, out_file, done_file, cancel_file)
    local f = io.open(script_path, "w")
    if not f then return false end
    local tmp = done_file .. ".tmp"
    f:write("#!/bin/sh\n")
    f:write(cmd .. " > " .. quote(out_file) .. " 2>&1 &\n")
    f:write("pid=$!\n")
    f:write("while kill -0 \"$pid\" 2>/dev/null; do\n")
    if cancel_file then
        f:write("  if [ -f " .. quote(cancel_file) .. " ]; then\n")
        f:write("    kill \"$pid\" 2>/dev/null; sleep 1; kill -9 \"$pid\" 2>/dev/null\n")
        f:write("    echo -2 > " .. quote(tmp) .. "; mv -f " .. quote(tmp) .. " " .. quote(done_file) .. "; exit 0\n")
        f:write("  fi\n")
    end
    f:write("  sleep 0.2\ndone\n")
    f:write("wait \"$pid\"\ncode=$?\n")
    f:write("echo \"$code\" > " .. quote(tmp) .. "\n")
    f:write("mv -f " .. quote(tmp) .. " " .. quote(done_file) .. "\n")
    f:close()
    return true
end

local function run_ffmpeg_silent(cmd)
    if IS_WINDOWS and not ensure_hidden_runner() then
        return nil, "Could not prepare hidden FFmpeg runner."
    end

    local lines = {}
    local cmd_file, out_file, done_file, cancel_file = temp_run_paths()
    if IS_WINDOWS then
        if not write_windows_batch(cmd_file, cmd, out_file, done_file) then return nil, "Could not prepare FFmpeg command file." end
    else
        if not write_posix_script(cmd_file, cmd, out_file, done_file, cancel_file) then return nil, "Could not prepare FFmpeg command file." end
    end

    if IS_WINDOWS then
        launch_hidden_windows(cmd_file, done_file, cancel_file)
    else
        os.execute("/bin/sh " .. quote(cmd_file) .. " >/dev/null 2>&1 &")
    end

    local launch_deadline = os.time() + 15
    while not file_exists(done_file) do
        if (not file_exists(out_file)) and os.time() > launch_deadline then
            if IS_WINDOWS then
                return nil, "Could not start FFmpeg in the background. Check that ffmpeg is installed and that the temp folder " .. OUTPUT_DIR .. " is writable."
            else
                return nil, "Could not start FFmpeg. Confirm ffmpeg is at " .. FFMPEG .. " and the temp folder " .. OUTPUT_DIR .. " is writable."
            end
        end
        pcall(function() bmd.wait(0.08) end)
    end

    local fout = io.open(out_file, "r")
    if fout then
        for line in fout:lines() do table.insert(lines, line) end
        fout:close()
    end

    local exit_code = 1
    local fdone = io.open(done_file, "r")
    if fdone then
        exit_code = tonumber(fdone:read("*a") or "1") or 1
        fdone:close()
    end
    if exit_code ~= 0 and #lines == 0 then
        return nil, FFMPEG_HELP
    end
    return table.concat(lines, "\n"), nil
end
local function run_ffmpeg_with_progress(cmd, duration, label)
    if IS_WINDOWS and not ensure_hidden_runner() then
        return nil, "Could not prepare hidden FFmpeg runner."
    end
    local ui = fusion.UIManager
    local disp = bmd.UIDispatcher(ui)
    local lines = {}
    local cancelled = false
    local cancel_file = nil
    local last_percent = -1
    local cmd_file, out_file, done_file
    cmd_file, out_file, done_file, cancel_file = temp_run_paths()

    local win = disp:AddWindow({
        ID = "VideoDiffProgress",
        WindowTitle = "Video Diff Marker - Comparing",
        Geometry = { 520, 260, 700, 285 },
        MinimumSize = { 700, 285 },
        StyleSheet = SS.win,
    }, {
        ui:VGroup{ Spacing = 12, Margin = 18,
            ui:Label({ Text = label or "Comparing videos. Resolve may feel busy while this runs.", WordWrap = true, StyleSheet = SS.label }),
            ui:Label({ ID = "Bar", Text = progress_bar_text(0), MinimumSize = { 590, 24 }, StyleSheet = SS.dim }),
            ui:Label({ ID = "Status", Text = "Starting FFmpeg...", WordWrap = true, Weight = 1, StyleSheet = SS.dim }),
            ui:HGroup{ Weight = 0, MinimumSize = { 0, 56 },
                ui:HGap(0),
                ui:Button{ ID = "CancelAnalysis", Text = "Cancel Analysis", MinimumSize = { 190, 40 }, StyleSheet = SS.btn },
                ui:HGap(0),
            },
            ui:VGap(6),
        },
    })
    local itm = win:GetItems()
    local function request_cancel()
        if cancelled then return end
        cancelled = true
        itm.Status.Text = "Cancelling analysis..."
        if cancel_file then
            local fcancel = io.open(cancel_file, "w")
            if fcancel then
                fcancel:write("cancel")
                fcancel:close()
            end
        end
    end
    win.On.CancelAnalysis.Clicked = function() request_cancel() end
    win.On.VideoDiffProgress.Close = function() request_cancel() end
    win:Show()

    if IS_WINDOWS then
        if not write_windows_batch(cmd_file, cmd, out_file, done_file) then
            win:Hide()
            return nil, "Could not prepare FFmpeg command file."
        end
    else
        if not write_posix_script(cmd_file, cmd, out_file, done_file, cancel_file) then
            win:Hide()
            return nil, "Could not prepare FFmpeg command file."
        end
    end

    if IS_WINDOWS then
        launch_hidden_windows(cmd_file, done_file, cancel_file)
    else
        -- macOS: run the shell script in the background so the polling loop can drive the UI.
        os.execute("/bin/sh " .. quote(cmd_file) .. " >/dev/null 2>&1 &")
    end

    local seen_lines = 0
    local launch_deadline = os.time() + 15
    while not file_exists(done_file) do
        pcall(function() disp:StepLoop() end)
        if (not file_exists(out_file)) and os.time() > launch_deadline then
            win:Hide()
            if IS_WINDOWS then
                return nil, "Could not start FFmpeg in the background. Check that ffmpeg is installed and that the temp folder " .. OUTPUT_DIR .. " is writable."
            else
                return nil, "Could not start FFmpeg. Confirm ffmpeg is at " .. FFMPEG .. " and the temp folder " .. OUTPUT_DIR .. " is writable."
            end
        end
        local fout = io.open(out_file, "r")
        if fout then
            local all = {}
            for line in fout:lines() do table.insert(all, line) end
            fout:close()
            for i = seen_lines + 1, #all do
                local line = all[i]
                table.insert(lines, line)
                local t = line:match("^frame:%d+%s+pts:%S+%s+pts_time:([%d%.]+)")
                if t and duration and duration > 0 then
                    local percent = math.floor((tonumber(t) or 0) * 100 / duration)
                    if percent > last_percent then
                        last_percent = percent
                        itm.Bar.Text = progress_bar_text(percent)
                        itm.Status.Text = string.format("Analyzed %.1f / %.1f seconds", tonumber(t) or 0, duration)
                    end
                end
            end
            seen_lines = #all
        end
        if cancelled then
            itm.Status.Text = "Cancelling analysis..."
        end
        pcall(function() bmd.wait(0.15) end)
    end
    pcall(function() disp:StepLoop() end)

    local fout = io.open(out_file, "r")
    if fout then
        local all = {}
        for line in fout:lines() do table.insert(all, line) end
        fout:close()
        for i = seen_lines + 1, #all do table.insert(lines, all[i]) end
    end
    local exit_code = 1
    local fdone = io.open(done_file, "r")
    if fdone then
        exit_code = tonumber(fdone:read("*a") or "1") or 1
        fdone:close()
    end
    if cancelled or exit_code == -2 then
        win:Hide()
        return nil, "Analysis cancelled."
    end
    itm.Bar.Text = progress_bar_text(100)
    itm.Status.Text = "Finished analysis. Building markers..."
    pcall(function() bmd.wait(0.05) end)
    win:Hide()

    if exit_code ~= 0 and #lines == 0 then
        return nil, FFMPEG_HELP
    end
    return table.concat(lines, "\n"), nil
end

local function trim_graphics_weak_tails(samples)
    local i = 1
    while i <= #samples do
        if not samples[i].different then
            i = i + 1
        else
            local a = i
            local peak_avg, peak_changed = 0, 0
            while i <= #samples and samples[i].different do
                peak_avg = math.max(peak_avg, samples[i].avg or 0)
                peak_changed = math.max(peak_changed, samples[i].changed_pct or 0)
                i = i + 1
            end
            local b = i - 1
            if peak_avg >= DEFAULT_GRAPHICS_TAIL_TRIM_PEAK_AVG then
                local avg_cut = peak_avg * DEFAULT_GRAPHICS_TAIL_AVG_RATIO
                local changed_cut = peak_changed * DEFAULT_GRAPHICS_TAIL_CHANGED_RATIO
                while b >= a do
                    local s = samples[b]
                    if (s.avg or 0) < avg_cut and (s.changed_pct or 0) < changed_cut then
                        s.different = false
                        b = b - 1
                    else
                        break
                    end
                end

            end
        end
    end
end
local function parse_metrics(text, settings)
    local samples = {}
    local current = nil
    for line in text:gmatch("[^\r\n]+") do
        local frame_no, pts_time = line:match("^frame:(%d+)%s+pts:%S+%s+pts_time:([%d%.]+)")
        if frame_no then
            current = {
                index = tonumber(frame_no),
                time = (settings.time_offset or 0) + (tonumber(pts_time) or (#samples / settings.sample_rate)),
                avg = 0,
                max = 0,
                pblack = 100,
                different = false,
            }
            table.insert(samples, current)
        elseif current then
            local yavg = line:match("lavfi%.signalstats%.YAVG=([%d%.%-]+)")
            if yavg then current.avg = math.max(0, tonumber(yavg) - 16) end
            local ymax = line:match("lavfi%.signalstats%.YMAX=([%d%.%-]+)")
            if ymax then current.max = math.max(0, tonumber(ymax) - 16) end
            local pblack = line:match("lavfi%.blackframe%.pblack=([%d%.%-]+)")
            if pblack then current.pblack = tonumber(pblack) end
        end
    end

    for _, sample in ipairs(samples) do
        local changed_pct = 100 - (sample.pblack or 100)
        local local_avg_min = settings.local_avg_min or DEFAULT_LOCAL_AVG_MIN
        sample.changed_pct = changed_pct
        if settings.localized_graphics then
            sample.different = (
                sample.max >= (settings.graphics_max_diff or DEFAULT_GRAPHICS_MAX_DIFF) and
                changed_pct >= (settings.graphics_changed_pct or DEFAULT_GRAPHICS_CHANGED_PIXELS_PERCENT)
            )
        else
            sample.different = (
                sample.avg >= settings.threshold or
                (sample.max >= settings.max_diff and sample.avg >= local_avg_min and changed_pct >= settings.changed_pct) or
                (sample.max >= settings.max_diff and sample.avg >= local_avg_min and changed_pct >= (settings.max_pixel_min_pct or DEFAULT_MAX_PIXEL_MIN_PERCENT))
            )
        end
    end

    if not settings.keep_isolated and #samples >= 3 then
        local original = {}
        for i, sample in ipairs(samples) do original[i] = sample.different end

        local function strong(i)
            local s = samples[i]
            local local_avg_min = settings.local_avg_min or DEFAULT_LOCAL_AVG_MIN
            if settings.localized_graphics then
                return (
                    s.max >= (settings.graphics_max_diff or DEFAULT_GRAPHICS_MAX_DIFF) * 1.25 and
                    (s.changed_pct or 0) >= (settings.graphics_changed_pct or DEFAULT_GRAPHICS_CHANGED_PIXELS_PERCENT)
                )
            end
            return (
                s.avg >= settings.threshold * 1.8 or
                (s.avg >= local_avg_min and (s.changed_pct or 0) >= settings.changed_pct * 3) or
                (s.max >= settings.max_diff * 1.25 and s.avg >= local_avg_min and (s.changed_pct or 0) >= (settings.max_pixel_min_pct or DEFAULT_MAX_PIXEL_MIN_PERCENT))
            )
        end

        if original[1] and not original[2] and not strong(1) then
            samples[1].different = false
        end
        for i = 2, #samples - 1 do
            if original[i] and not original[i - 1] and not original[i + 1] and not strong(i) then
                samples[i].different = false
            elseif (not original[i]) and original[i - 1] and original[i + 1] then
                samples[i].different = true
            end
        end
        if original[#samples] and not original[#samples - 1] and not strong(#samples) then
            samples[#samples].different = false
        end
    elseif DEFAULT_TEMPORAL_PADDING > 0 then
        local flagged = {}
        for i, sample in ipairs(samples) do
            if sample.different then table.insert(flagged, i) end
        end
        for _, i in ipairs(flagged) do
            for j = math.max(1, i - DEFAULT_TEMPORAL_PADDING), math.min(#samples, i + DEFAULT_TEMPORAL_PADDING) do
                samples[j].different = true
            end
        end
    end

    if settings.localized_graphics then
        trim_graphics_weak_tails(samples)
    end

    return samples
end

local function build_segments(samples, settings)
    local segments = {}
    if #samples == 0 then return segments end
    local sample_rate = settings.sample_rate
    local frame_len = 1 / sample_rate
    local start_i = 1
    local current = samples[1].different

    local function add_segment(a, b, state)
        local avg_total, max_score = 0, 0
        for i = a, b do
            avg_total = avg_total + samples[i].avg
            max_score = math.max(max_score, samples[i].max)
        end
        table.insert(segments, {
            state = state and "different" or "identical",
            start = samples[a].time,
            finish = samples[b].time + frame_len,
            avg = avg_total / math.max(1, b - a + 1),
            max = max_score,
        })
    end

    for i = 2, #samples do
        if samples[i].different ~= current then
            add_segment(start_i, i - 1, current)
            start_i = i
            current = samples[i].different
        end
    end
    add_segment(start_i, #samples, current)

    local merged = {}
    local merge_gap = settings.frame_accurate and (0.5 / sample_rate) or DEFAULT_MERGE_GAP
    for _, seg in ipairs(segments) do
        local last = merged[#merged]
        if last and last.state == seg.state and seg.start - last.finish <= merge_gap then
            last.finish = seg.finish
            last.avg = math.max(last.avg, seg.avg)
            last.max = math.max(last.max, seg.max)
        elseif last and not settings.frame_accurate and seg.state == "identical" and seg.finish - seg.start <= merge_gap then
            last.finish = seg.finish
        else
            table.insert(merged, seg)
        end
    end
    return merged
end

local function changed_segments_only(segments)
    local changed = {}
    for _, seg in ipairs(segments or {}) do
        if seg.state == "different" then table.insert(changed, seg) end
    end
    return changed
end

local function merge_changed_segments(segments, gap)
    local changed = changed_segments_only(segments)
    table.sort(changed, function(a, b) return a.start < b.start end)
    local merged = {}
    for _, seg in ipairs(changed) do
        local last = merged[#merged]
        if last and seg.start <= last.finish + (gap or 0) then
            last.finish = math.max(last.finish, seg.finish)
            last.avg = math.max(last.avg or 0, seg.avg or 0)
            last.max = math.max(last.max or 0, seg.max or 0)
        else
            table.insert(merged, {
                state = "different",
                start = seg.start,
                finish = seg.finish,
                avg = seg.avg or 0,
                max = seg.max or 0,
            })
        end
    end
    return merged
end

local function expand_and_merge_ranges(segments, duration, margin)
    local ranges = {}
    for _, seg in ipairs(changed_segments_only(segments)) do
        table.insert(ranges, {
            start = math.max(0, seg.start - margin),
            finish = math.min(duration, seg.finish + margin),
        })
    end
    table.sort(ranges, function(a, b) return a.start < b.start end)

    local merged = {}
    for _, range in ipairs(ranges) do
        local last = merged[#merged]
        if last and range.start <= last.finish then
            last.finish = math.max(last.finish, range.finish)
        else
            table.insert(merged, range)
        end
    end
    return merged
end

local function batch_refine_ranges(ranges, gap, max_duration)
    local batched = {}
    table.sort(ranges or {}, function(a, b) return a.start < b.start end)
    for _, range in ipairs(ranges or {}) do
        local last = batched[#batched]
        local can_merge = false
        if last then
            local merged_finish = math.max(last.finish, range.finish)
            can_merge = (
                range.start <= last.finish + (gap or 0) and
                (merged_finish - last.start) <= (max_duration or math.huge)
            )
        end
        if can_merge then
            last.finish = math.max(last.finish, range.finish)
        else
            table.insert(batched, { start = range.start, finish = range.finish })
        end
    end
    return batched
end
local function run_analysis_pass(settings, duration, label)
    local cmd = build_ffmpeg_command(settings)
    local output, err
    if settings.silent then
        output, err = run_ffmpeg_silent(cmd)
    else
        output, err = run_ffmpeg_with_progress(cmd, duration, label)
    end
    if err and (not output or output == "") then return nil, err end
    local samples = parse_metrics(output or "", settings)
    if #samples == 0 then return nil, "No comparison samples were returned. Check that FFmpeg can read both files." end
    return build_segments(samples, settings), nil
end

local function graphics_settings_from(settings)
    local graphics = {}
    for k, v in pairs(settings) do graphics[k] = v end
    graphics.localized_graphics = true
    graphics.proxy_width = DEFAULT_GRAPHICS_WIDTH
    graphics.proxy_height = DEFAULT_GRAPHICS_HEIGHT
    graphics.graphics_max_diff = DEFAULT_GRAPHICS_MAX_DIFF
    graphics.graphics_changed_pct = DEFAULT_GRAPHICS_CHANGED_PIXELS_PERCENT
    return graphics
end

local function run_localized_graphics_analysis(settings, compare_duration)
    local coarse = graphics_settings_from(settings)
    coarse.sample_rate = math.min(settings.fps or DEFAULT_GRAPHICS_SAMPLE_RATE, DEFAULT_GRAPHICS_SAMPLE_RATE)
    coarse.frame_accurate = false
    coarse.keep_isolated = false
    coarse.offset = 0
    coarse.time_offset = 0
    coarse.compare_duration = compare_duration

    local coarse_segments, err = run_analysis_pass(coarse, compare_duration, "Graphics/color pass 1/2: scan")
    if err then return nil, err end
    local ranges = expand_and_merge_ranges(coarse_segments, compare_duration, DEFAULT_GRAPHICS_REFINE_MARGIN)
    ranges = batch_refine_ranges(ranges, DEFAULT_REFINE_BATCH_GAP, DEFAULT_REFINE_BATCH_MAX_DURATION)
    if #ranges == 0 then return {}, nil end

    local refined_all = {}
    for i, range in ipairs(ranges) do
        local refine = graphics_settings_from(settings)
        refine.sample_rate = settings.fps
        refine.frame_accurate = true
        refine.keep_isolated = false
        refine.silent = true
        refine.offset = range.start
        refine.time_offset = range.start
        refine.compare_duration = math.max(1 / settings.fps, range.finish - range.start)

        local refined_segments, refine_err = run_analysis_pass(
            refine,
            refine.compare_duration,
            string.format("Graphics/color pass 2/2: frame refine %d/%d", i, #ranges)
        )
        if refine_err then return nil, refine_err end
        for _, seg in ipairs(changed_segments_only(refined_segments)) do
            table.insert(refined_all, seg)
        end
    end

    table.sort(refined_all, function(a, b) return a.start < b.start end)
    return merge_changed_segments(refined_all, DEFAULT_GRAPHICS_FINAL_MERGE_GAP), nil
end

local function run_opening_guard_analysis(settings, compare_duration)
    local guard_duration = math.min(compare_duration or 0, 12.0)
    if guard_duration <= 0 then return {}, nil end
    local guard = {}
    for k, v in pairs(settings) do guard[k] = v end
    guard.sample_rate = settings.fps
    guard.frame_accurate = true
    guard.keep_isolated = false
    guard.offset = 0
    guard.time_offset = 0
    guard.compare_duration = guard_duration
    guard.max_pixel_min_pct = DEFAULT_MAX_PIXEL_MIN_PERCENT
    guard.symmetric_diff = true
    local guard_segments, err = run_analysis_pass(guard, guard_duration, "Opening guard scan")
    if err then return nil, err end
    return changed_segments_only(guard_segments), nil
end

local function run_two_pass_analysis(settings, compare_duration)
    local coarse = {}
    for k, v in pairs(settings) do coarse[k] = v end
    coarse.sample_rate = settings.sample_rate
    coarse.frame_accurate = false
    coarse.keep_isolated = true
    coarse.offset = 0
    coarse.time_offset = 0
    coarse.compare_duration = compare_duration
    -- Coarse scan must be permissive; refinement decides exact marker edges.
    coarse.threshold = math.min(settings.threshold, 3.0)
    coarse.max_diff = math.min(settings.max_diff, 24.0)
    coarse.changed_pct = math.min(settings.changed_pct, 0.05)
    coarse.max_pixel_min_pct = 0.005
    coarse.local_avg_min = 0.15

    local coarse_segments, err = run_analysis_pass(coarse, compare_duration, "Pass 1/2: fast scan")
    if err then return nil, err end
    local ranges = expand_and_merge_ranges(coarse_segments, compare_duration, DEFAULT_REFINE_MARGIN)
    ranges = batch_refine_ranges(ranges, DEFAULT_REFINE_BATCH_GAP, DEFAULT_REFINE_BATCH_MAX_DURATION)
    if #ranges == 0 then return {}, nil end

    local refined_all = {}
    for i, range in ipairs(ranges) do
        local refine = {}
        for k, v in pairs(settings) do refine[k] = v end
        refine.sample_rate = settings.fps
        refine.frame_accurate = true
        refine.silent = true
        refine.offset = range.start
        refine.time_offset = range.start
        refine.compare_duration = math.max(1 / settings.fps, range.finish - range.start)
        refine.max_pixel_min_pct = DEFAULT_MAX_PIXEL_MIN_PERCENT

        local refined_segments, refine_err = run_analysis_pass(
            refine,
            refine.compare_duration,
            string.format("Pass 2/2: frame refine %d/%d", i, #ranges)
        )
        if refine_err then return nil, refine_err end
        for _, seg in ipairs(changed_segments_only(refined_segments)) do
            table.insert(refined_all, seg)
        end
    end

    table.sort(refined_all, function(a, b) return a.start < b.start end)
    return merge_changed_segments(refined_all, 0.25), nil
end

local function add_markers(resolve, segments, fps)
    local project = resolve:GetProjectManager():GetCurrentProject()
    if not project then return 0, "No current Resolve project." end
    local timeline = project:GetCurrentTimeline()
    if not timeline then return 0, "No current timeline." end

    local added = 0
    for _, seg in ipairs(segments) do
        if seg.state == "different" then
            local marker_start = seg.start
            local seg_duration = math.max(0, (seg.finish or seg.start) - (seg.start or 0))
            if marker_start < (2 / fps) and seg_duration > (0.5 / fps) then
                marker_start = math.min(seg.finish - (1 / fps), seg.start + math.min(0.5, seg_duration / 2))
            end
            local start_frame = seconds_to_frame(marker_start, fps)
            -- Marker duration is a frame count. Treat seg.finish as the first frame after the change,
            -- so a boundary that lands near the next frame does not add an extra marked frame.
            local end_frame = math.max(start_frame + 1, math.floor((seg.finish or marker_start) * fps + 0.0001))
            local duration_frames = math.max(1, end_frame - start_frame)
            local note = string.format("Different from %.2fs until %.2fs. Avg %.2f, max %.2f.", seg.start, seg.finish, seg.avg, seg.max)
            local ok = timeline:AddMarker(start_frame, "Green", "Video change", note, duration_frames, "")
            if ok then added = added + 1 end
        end
    end
    return added, nil
end

local function main()
    local resolve = fusion:GetResolve()
    if not resolve then
        show_message("Video Diff Marker", "Could not connect to DaVinci Resolve.")
        return
    end

    local selected = get_selected_media_paths(resolve)
    local settings = request_settings(resolve, selected)
    if not settings then return end
    if settings.old_path == "" or settings.new_path == "" then
        show_message("Video Diff Marker", "Please choose both video files.")
        return
    end
    if settings.old_path == settings.new_path then
        show_message("Video Diff Marker", "Old and New are the same file. Please choose two different clips.")
        return
    end

    local duration_a = probe_duration(settings.old_path)
    local duration_b = probe_duration(settings.new_path)
    local compare_duration = math.max(duration_a or 0, duration_b or 0)
    if compare_duration <= 0 then
        show_message("Video Diff Marker", "Could not read the duration of the selected clips with ffprobe.")
        return
    end
    settings.compare_duration = compare_duration
    local source_width, source_height = probe_dimensions(settings.old_path)
    settings.proxy_width, settings.proxy_height = proxy_size_for_source(source_width, source_height)

    local segments, err
    if settings.two_pass then
        segments, err = run_two_pass_analysis(settings, compare_duration)
    else
        local full = {}
        for k, v in pairs(settings) do full[k] = v end
        full.sample_rate = settings.fps
        full.frame_accurate = true
        full.offset = 0
        full.time_offset = 0
        full.compare_duration = compare_duration
        full.max_pixel_min_pct = DEFAULT_MAX_PIXEL_MIN_PERCENT
        segments, err = run_analysis_pass(full, compare_duration, "Full frame-accurate scan")
    end
    if err then
        show_message("Video Diff Marker", err)
        return
    end

    if settings.graphics_pass then
        local graphics_segments, graphics_err = run_localized_graphics_analysis(settings, compare_duration)
        if graphics_err then
            show_message("Video Diff Marker", graphics_err)
            return
        end
        for _, seg in ipairs(graphics_segments or {}) do
            table.insert(segments, seg)
        end
        segments = merge_changed_segments(segments, DEFAULT_GRAPHICS_FINAL_MERGE_GAP)
    end


    local added, marker_err = add_markers(resolve, segments, settings.fps)
    if marker_err then
        show_message("Video Diff Marker", marker_err)
        return
    end

    local changed_duration = 0
    for _, seg in ipairs(segments) do
        if seg.state == "different" then changed_duration = changed_duration + (seg.finish - seg.start) end
    end
    show_message(
        "Video Diff Marker",
        string.format(
            "Done. Analyzed %.1f seconds. Added %d green timeline markers. Changed duration: %.1f seconds.",
            compare_duration,
            added,
            changed_duration
        )
    )
end

local ok, err = pcall(main)
if not ok then
    print("Video Diff Marker error: " .. tostring(err))
    pcall(function()
        show_message("Video Diff Marker Error", tostring(err))
    end)
end






