-- Krispy Tools product: marker-range-render-queue
-- Release: 2026.2
-- Source SHA-256: 39002a6292e156127ac332aaa5310cb3210cf076bf633f37b4a1ae4f1c1cecf5
--[[
Marker Range Render Queue
=========================
DaVinci Resolve utility that queues render jobs from timeline markers.

Set your Deliver page render settings first, then run:
Workspace > Scripts > Utility > Marker Range Render Queue
--]]

local MARKER_COLORS = {
    "Blue", "Cyan", "Green", "Yellow", "Red", "Pink", "Purple", "Fuchsia",
    "Rose", "Lavender", "Sky", "Mint", "Lemon", "Sand", "Cocoa", "Cream",
}

local DEFAULT_RENDER_PRESET = "h264"
local USER_HOME = os.getenv("USERPROFILE") or os.getenv("HOME") or "."
local DEFAULT_RENDER_DIR = USER_HOME .. (package.config:sub(1, 1) == "\\" and "\\Desktop\\Renders" or "/Desktop/Renders")

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

local function trim(value)
    value = tostring(value or "")
    return value:match("^%s*(.-)%s*$")
end

local function sanitize_filename(value)
    value = trim(value)
    value = value:gsub('[<>:"/\\|?*]', "_")
    value = value:gsub("%s+", " ")
    value = value:gsub("^%.+", "")
    value = value:gsub("%.+$", "")
    return value
end

local function html_escape(value)
    return tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function log_append(widget, message, tag)
    local colors = { info=C.fg, ok=C.ok, warn=C.warn, err=C.err, head=C.accent, dim=C.fg_dim }
    local color = colors[tag] or C.fg
    widget.HTML = widget.HTML .. ('<span style="color:%s">%s</span><br>'):format(color, html_escape(message))
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

local function marker_duration(marker)
    return math.floor(tonumber(marker and marker.duration) or 0)
end

local function marker_name(marker, index)
    local name = sanitize_filename(marker and marker.name)
    if name == "" then
        name = string.format("Marker Range %02d", index)
    end
    return name
end

local function frame_to_timecode(frame, fps)
    fps = tonumber(fps) or 24
    local fps_int = math.floor(fps + 0.5)
    if fps_int < 1 then fps_int = 24 end

    frame = math.floor(tonumber(frame) or 0)
    local sign = ""
    if frame < 0 then
        sign = "-"
        frame = -frame
    end

    local ff = frame % fps_int
    local total_seconds = math.floor(frame / fps_int)
    local ss = total_seconds % 60
    local total_minutes = math.floor(total_seconds / 60)
    local mm = total_minutes % 60
    local hh = math.floor(total_minutes / 60)

    return string.format("%s%02d:%02d:%02d:%02d", sign, hh, mm, ss, ff)
end

local function seconds_label(frames, fps)
    fps = tonumber(fps) or 24
    if fps <= 0 then fps = 24 end
    return string.format("%.2fs", (tonumber(frames) or 0) / fps)
end

local function color_allowed(color, selected_colors, use_all_colors)
    if use_all_colors then return true end
    return selected_colors[color or ""] == true
end

local function sorted_markers(timeline)
    local markers = timeline:GetMarkers() or {}
    local rows = {}

    for frame_id, marker in pairs(markers) do
        table.insert(rows, {
            frame = math.floor(tonumber(frame_id) or 0),
            color = marker and marker.color or "",
            duration = marker_duration(marker),
            marker = marker or {},
        })
    end

    table.sort(rows, function(a, b)
        return a.frame < b.frame
    end)

    return rows
end

local function collect_ranges(timeline, options)
    local rows = sorted_markers(timeline)
    local ranges = {}
    local point_count = 0
    local duration_count = 0
    local selected_rows = {}
    local timeline_start = 0

    if options.add_timeline_start_frame then
        local ok, start_frame = pcall(function() return timeline:GetStartFrame() end)
        if ok then timeline_start = math.floor(tonumber(start_frame) or 0) end
    end

    for _, row in ipairs(rows) do
        if color_allowed(row.color, options.selected_colors, options.use_all_colors) then
            table.insert(selected_rows, row)
            if row.duration >= options.minimum_duration_frames then
                duration_count = duration_count + 1
            else
                point_count = point_count + 1
            end
        end
    end

    for index, row in ipairs(selected_rows) do
        local use_duration = row.duration >= options.minimum_duration_frames
        local use_next_marker = false

        if options.mode == "duration" then
            use_next_marker = false
        elseif options.mode == "next" then
            use_duration = false
            use_next_marker = true
        elseif options.mode == "mixed" then
            use_next_marker = not use_duration
        end

        local mark_in = timeline_start + row.frame
        local mark_out = nil
        local source = nil

        if use_duration then
            mark_out = mark_in + row.duration - 1
            source = "duration"
        elseif use_next_marker and selected_rows[index + 1] then
            mark_out = timeline_start + selected_rows[index + 1].frame - 1
            source = "next marker"
        end

        if mark_out and mark_out >= mark_in and (mark_out - mark_in + 1) >= options.minimum_duration_frames then
            table.insert(ranges, {
                mark_in = mark_in,
                mark_out = mark_out,
                duration = mark_out - mark_in + 1,
                color = row.color,
                marker = row.marker,
                source = source,
            })
        end
    end

    return ranges, {
        total = #rows,
        selected = #selected_rows,
        duration = duration_count,
        point = point_count,
    }
end

local function build_job_name(timeline_name, marker, index, prefix)
    local name = marker_name(marker, index)
    prefix = sanitize_filename(prefix)
    if prefix ~= "" then name = prefix .. name end

    timeline_name = sanitize_filename(timeline_name)
    if timeline_name ~= "" then
        return timeline_name .. " - " .. name
    end
    return name
end

local function build_output_names(timeline_name, ranges, options)
    local bases, totals, reserved, used, names = {}, {}, {}, {}, {}
    for index, range in ipairs(ranges) do
        local base
        if options.exact_marker_names then
            base = marker_name(range.marker, index)
        else
            base = build_job_name(timeline_name, range.marker, index, options.job_name_prefix)
        end
        if base == "" then base = string.format("Marker Range %02d", index) end
        bases[index] = base
        local key = base:lower()
        totals[key] = (totals[key] or 0) + 1
        reserved[key] = true
    end
    for index, base in ipairs(bases) do
        local candidate, key = base, base:lower()
        if totals[key] > 1 or used[key] then
            local suffix = 1
            repeat
                candidate = string.format("%s %02d", base, suffix)
                suffix = suffix + 1
            until not reserved[candidate:lower()] and not used[candidate:lower()]
        end
        names[index] = candidate
        used[candidate:lower()] = true
    end
    return names
end

local function ensure_directory(path)
    path = trim(path)
    if path == "" then return false end

    local is_windows = (os.getenv("SYSTEMROOT") ~= nil or os.getenv("windir") ~= nil)
    local sep = is_windows and "\\" or "/"
    local partial = ""

    if is_windows and path:match("^%a:[/\\]") then
        partial = path:sub(1, 3)
        path = path:sub(4)
    elseif path:sub(1, 1) == "/" or path:sub(1, 1) == "\\" then
        partial = sep
        path = path:sub(2)
    end

    for part in path:gmatch("[^/\\]+") do
        if partial == "" or partial:sub(-1) == "/" or partial:sub(-1) == "\\" then
            partial = partial .. part
        else
            partial = partial .. sep .. part
        end
        pcall(function() bmd.createdir(partial) end)
    end

    return true
end

local function queue_ranges(project, timeline, ranges, options, logger)
    local queued = 0
    local failed = 0
    local timeline_name = timeline:GetName() or "Timeline"
    local target_dir = trim(options.target_dir)
    local preset_name = trim(options.render_preset)

    if preset_name ~= "" then
        local preset_ok = false
        pcall(function() preset_ok = project:LoadRenderPreset(preset_name) end)
        if preset_ok then
            logger("Loaded render preset: " .. preset_name, "dim")
        else
            logger("Render preset not found: " .. preset_name, "err")
            return 0, #ranges
        end
    end

    if target_dir ~= "" then
        ensure_directory(target_dir)
        logger("Output folder: " .. target_dir, "dim")
    end

    project:SetRenderSettings({ SelectAllFrames = false })
    local output_names = build_output_names(timeline_name, ranges, options)

    for index, range in ipairs(ranges) do
        local job_name = output_names[index]
        local ok = project:SetRenderSettings({
            SelectAllFrames = false,
            MarkIn = range.mark_in,
            MarkOut = range.mark_out,
            CustomName = job_name,
            TargetDir = target_dir,
        })

        if ok then
            local job_id = project:AddRenderJob()
            if job_id and job_id ~= "" then
                queued = queued + 1
                logger(("Queued %s | %s | %s - %s (%s)"):format(
                    job_name,
                    range.source,
                    frame_to_timecode(range.mark_in, options.fps),
                    frame_to_timecode(range.mark_out, options.fps),
                    seconds_label(range.duration, options.fps)
                ), "ok")
            else
                failed = failed + 1
                logger("Failed to add render job for " .. job_name, "err")
            end
        else
            failed = failed + 1
            logger("Failed to set render range for " .. job_name, "err")
        end
    end

    return queued, failed
end

local function make_ui()
    local ui = fusion.UIManager
    local disp = bmd.UIDispatcher(ui)

    local function sep()
        return ui:Label{Weight=0, MinimumSize={1,1}, MaximumSize={9999,1}, StyleSheet=SS.sep}
    end

    local color_rows = {}
    for i = 1, #MARKER_COLORS, 8 do
        local row = ui:HGroup{Weight=0, Spacing=8}
        for j = i, math.min(i + 7, #MARKER_COLORS) do
            local color = MARKER_COLORS[j]
            row:AddChild(ui:CheckBox{
                ID="Color_" .. color,
                Text=color,
                Checked=true,
                StyleSheet=SS.label,
                Weight=0,
            })
        end
        table.insert(color_rows, row)
    end

    local WINDOW_ID = "MarkerRangeRenderQueueGraphite2026V7"
    local WINDOW_W, WINDOW_H = 1180, 960
    local SIDE_GUTTER, BOTTOM_GUTTER = 28, 16
    local ROW_H, CONTROL_H = 40, 34

    local win = disp:AddWindow({
        ID=WINDOW_ID,
        WindowTitle="Marker Range Render Queue",
        Geometry={90, 40, WINDOW_W, WINDOW_H},
        MinimumSize={1080, 880},
        StyleSheet=SS.win,

        ui:VGroup{Spacing=0,
            ui:HGroup{Weight=1, Spacing=0,
                ui:HGap(SIDE_GUTTER),
                ui:VGroup{Weight=1, Spacing=5,
                    ui:VGap(16),
                    ui:HGroup{Weight=0, Spacing=12, MinimumSize={0,46}, MaximumSize={9999,46},
                        ui:Label{Weight=0, MinimumSize={5,42}, MaximumSize={5,42}, StyleSheet=SS.bar},
                        ui:VGroup{Weight=1, Spacing=2,
                            ui:Label{Weight=0, Text="Marker Range Render Queue", StyleSheet=SS.title, MinimumSize={0,24}},
                            ui:Label{Weight=0, Text="Queue Deliver-page render jobs from timeline marker ranges.", StyleSheet=SS.dim, MinimumSize={0,18}},
                        },
                    },
                    sep(),

                    ui:HGroup{Weight=0, Spacing=10, MinimumSize={0,ROW_H}, MaximumSize={9999,ROW_H},
                        ui:Label{Weight=0, Text="Range mode:", StyleSheet=SS.label, MinimumSize={120,CONTROL_H}, MaximumSize={120,CONTROL_H}},
                        ui:ComboBox{ID="Mode", StyleSheet=SS.combo, Weight=1, MinimumSize={360,CONTROL_H}, MaximumSize={9999,CONTROL_H}},
                        ui:Label{Weight=0, Text="Min frames:", StyleSheet=SS.label, MinimumSize={92,CONTROL_H}, MaximumSize={92,CONTROL_H}},
                        ui:SpinBox{ID="MinFrames", Minimum=1, Maximum=9999, Value=24, StyleSheet=SS.input, Weight=0, MinimumSize={140,CONTROL_H}, MaximumSize={140,CONTROL_H}},
                    },
                    ui:HGroup{Weight=0, Spacing=10, MinimumSize={0,ROW_H}, MaximumSize={9999,ROW_H},
                        ui:Label{Weight=0, Text="Name prefix:", StyleSheet=SS.label, MinimumSize={120,CONTROL_H}, MaximumSize={120,CONTROL_H}},
                        ui:LineEdit{ID="Prefix", StyleSheet=SS.input, PlaceholderText="Optional prefix before marker names", Weight=1, MinimumSize={0,CONTROL_H}, MaximumSize={9999,CONTROL_H}},
                    },
                    ui:CheckBox{ID="ExactMarkerNames", Text="Use marker name only for output file name; add numbers for duplicate names", Checked=true, StyleSheet=SS.label, Weight=0, MinimumSize={0,28}, MaximumSize={9999,28}},
                    ui:HGroup{Weight=0, Spacing=10, MinimumSize={0,ROW_H}, MaximumSize={9999,ROW_H},
                        ui:Label{Weight=0, Text="Render preset:", StyleSheet=SS.label, MinimumSize={120,CONTROL_H}, MaximumSize={120,CONTROL_H}},
                        ui:LineEdit{ID="Preset", Text=DEFAULT_RENDER_PRESET, StyleSheet=SS.input, PlaceholderText="Exact Resolve preset name", Weight=1, MinimumSize={0,CONTROL_H}, MaximumSize={9999,CONTROL_H}},
                    },
                    ui:HGroup{Weight=0, Spacing=10, MinimumSize={0,ROW_H}, MaximumSize={9999,ROW_H},
                        ui:Label{Weight=0, Text="Output folder:", StyleSheet=SS.label, MinimumSize={120,CONTROL_H}, MaximumSize={120,CONTROL_H}},
                        ui:LineEdit{ID="OutputDir", Text=DEFAULT_RENDER_DIR, StyleSheet=SS.input, Weight=1, MinimumSize={0,CONTROL_H}, MaximumSize={9999,CONTROL_H}},
                        ui:Button{ID="BrowseOutput", Text="Browse...", StyleSheet=SS.btn, MinimumSize={130,CONTROL_H}, MaximumSize={130,CONTROL_H}, Weight=0},
                    },
                    ui:CheckBox{ID="AddTimelineStart", Text="Add timeline start frame to marker positions", Checked=true, StyleSheet=SS.label, Weight=0, MinimumSize={0,28}, MaximumSize={9999,28}},

                    sep(),
                    ui:HGroup{Weight=0, Spacing=10, MinimumSize={0,ROW_H}, MaximumSize={9999,ROW_H},
                        ui:CheckBox{ID="AllColors", Text="Use all marker colors", Checked=true, StyleSheet=SS.label, Weight=1},
                        ui:Button{ID="SelectAllColors", Text="All", StyleSheet=SS.btn, Weight=0, MinimumSize={130,CONTROL_H}, MaximumSize={130,CONTROL_H}},
                        ui:Button{ID="SelectNoColors", Text="None", StyleSheet=SS.btn, Weight=0, MinimumSize={130,CONTROL_H}, MaximumSize={130,CONTROL_H}},
                    },
                    ui:VGroup{ID="ColorBox", Weight=0, Spacing=5,
                        color_rows[1], color_rows[2],
                    },

                    sep(),
                    ui:Label{ID="Summary", Text="Click Refresh Scan to inspect markers.", Weight=0, StyleSheet=SS.dim, MinimumSize={0,22}, MaximumSize={9999,22}},
                    ui:HGroup{Weight=0, Spacing=10, MinimumSize={0,ROW_H}, MaximumSize={9999,ROW_H},
                        ui:Label{Text="Select rows to queue. Ctrl+click or Shift+click for multiple.", Weight=1, StyleSheet=SS.dim, MinimumSize={0,CONTROL_H}, MaximumSize={9999,CONTROL_H}},
                        ui:Button{ID="Refresh", Text="Refresh Scan", StyleSheet=SS.btn, Weight=0, MinimumSize={190,CONTROL_H}, MaximumSize={190,CONTROL_H}},
                        ui:Button{ID="SelectAllRanges", Text="All", StyleSheet=SS.btn, Weight=0, MinimumSize={130,CONTROL_H}, MaximumSize={130,CONTROL_H}},
                        ui:Button{ID="SelectNoRanges", Text="None", StyleSheet=SS.btn, Weight=0, MinimumSize={130,CONTROL_H}, MaximumSize={130,CONTROL_H}},
                    },
                    ui:Tree{ID="Preview", Weight=1, MinimumSize={0,80}, SortingEnabled=false, SelectionMode="ExtendedSelection", AlternatingRowColors=true, HeaderHidden=false, RootIsDecorated=false, StyleSheet=SS.tree},

                    sep(),
                    ui:VGroup{Weight=0, Spacing=6, MinimumSize={0,190}, MaximumSize={9999,190},
                        ui:Label{Weight=0, Text="Log", StyleSheet=SS.label, MinimumSize={0,20}, MaximumSize={9999,20}},
                        ui:HGroup{Weight=0, Spacing=0, MinimumSize={0,110}, MaximumSize={9999,110},
                            ui:TextEdit{ID="Log", Weight=1, ReadOnly=true, StyleSheet=SS.log},
                        },
                        ui:HGroup{Weight=0, Spacing=10, MinimumSize={0,ROW_H}, MaximumSize={9999,ROW_H},
                            ui:Button{ID="ClearLog", Text="Clear Log", StyleSheet=SS.btn, Weight=1, MinimumSize={0,CONTROL_H}, MaximumSize={9999,CONTROL_H}},
                            ui:Button{ID="Queue", Text="Add Selected Marker Ranges to Render Queue", StyleSheet=SS.btn_acc, Weight=1, MinimumSize={0,CONTROL_H}, MaximumSize={9999,CONTROL_H}},
                        },
                    },                    ui:VGap(BOTTOM_GUTTER),
                },
                ui:HGap(SIDE_GUTTER),
            },
        },
    })
    local itm = win:GetItems()
    itm.Mode:AddItem("Duration markers only")
    itm.Mode:AddItem("Point markers: range until next selected marker")
    itm.Mode:AddItem("Mixed: duration markers, points until next marker")
    itm.Mode.CurrentIndex = 0

    itm.Preview.ColumnCount = 5
    pcall(function()
        itm.Preview:SetHeaderLabels({"#", "Color", "Source", "Name", "Timecode Range"})
        itm.Preview.ColumnWidth[0] = 36
        itm.Preview.ColumnWidth[1] = 95
        itm.Preview.ColumnWidth[2] = 95
        itm.Preview.ColumnWidth[3] = 170
    end)

    local state = {
        project = nil,
        timeline = nil,
        ranges = {},
        stats = nil,
    }

    local function selected_options()
        local selected_colors = {}
        for _, color in ipairs(MARKER_COLORS) do
            selected_colors[color] = itm["Color_" .. color].Checked == true
        end

        local mode = "mixed"
        if itm.Mode.CurrentIndex == 0 then mode = "duration" end
        if itm.Mode.CurrentIndex == 1 then mode = "next" end
        local fps = 24
        if state.timeline then
            local ok, value = pcall(function() return state.timeline:GetSetting("timelineFrameRate") end)
            if ok then fps = tonumber(value) or fps end
        end

        return {
            use_all_colors = itm.AllColors.Checked == true,
            selected_colors = selected_colors,
            mode = mode,
            minimum_duration_frames = math.max(1, tonumber(itm.MinFrames.Value) or 1),
            job_name_prefix = itm.Prefix.Text or "",
            add_timeline_start_frame = itm.AddTimelineStart.Checked == true,
            fps = fps,
            render_preset = itm.Preset.Text or "",
            target_dir = itm.OutputDir.Text or "",
            exact_marker_names = itm.ExactMarkerNames.Checked == true,
        }
    end

    local function clear_preview()
        pcall(function() itm.Preview:Clear() end)
    end

    local function fill_preview(ranges)
        clear_preview()
        local opts = selected_options()
        for index, range in ipairs(ranges) do
            local row = itm.Preview:NewItem()
            row.Text[0] = tostring(index)
            row.Text[1] = tostring(range.color or "")
            row.Text[2] = range.source
            row.Text[3] = marker_name(range.marker, index)
            row.Text[4] = ("%s - %s (%s)"):format(
                frame_to_timecode(range.mark_in, opts.fps),
                frame_to_timecode(range.mark_out, opts.fps),
                seconds_label(range.duration, opts.fps)
            )
            itm.Preview:AddTopLevelItem(row)
            row.Selected = true
        end
    end

    local function selected_preview_ranges()
        local selected = {}
        local sel_items = itm.Preview:SelectedItems()

        if sel_items then
            for _, row in pairs(sel_items) do
                local index = tonumber(row.Text[0])
                if index and state.ranges[index] then
                    table.insert(selected, state.ranges[index])
                end
            end
        end

        table.sort(selected, function(a, b)
            if a.mark_in == b.mark_in then return a.mark_out < b.mark_out end
            return a.mark_in < b.mark_in
        end)

        return selected
    end

    local function scan()
        log_clear(itm.Log)

        local resolve = get_resolve()
        if not resolve then
            log_append(itm.Log, "Cannot connect to DaVinci Resolve.", "err")
            return
        end

        local pm = resolve:GetProjectManager()
        local project = pm and pm:GetCurrentProject()
        if not project then
            log_append(itm.Log, "No project is open.", "err")
            return
        end

        local timeline = project:GetCurrentTimeline()
        if not timeline then
            log_append(itm.Log, "No active timeline is open.", "err")
            return
        end

        local ranges, stats = collect_ranges(timeline, selected_options())
        state.project = project
        state.timeline = timeline
        state.ranges = ranges
        state.stats = stats

        itm.Summary.Text = ("Timeline: %s | markers: %d | selected: %d | queueable ranges: %d"):format(
            timeline:GetName() or "Timeline",
            stats.total,
            stats.selected,
            #ranges
        )

        fill_preview(ranges)
        log_append(itm.Log, ("Found %d marker(s), %d selected by color."):format(stats.total, stats.selected), "info")
        log_append(itm.Log, ("Selected marker types: %d duration, %d point."):format(stats.duration, stats.point), "dim")

        if #ranges == 0 and stats.point > 0 then
            log_append(itm.Log, "No queueable ranges in this mode. Try the point-marker or mixed mode if your markers are not duration markers.", "warn")
        elseif #ranges == 0 then
            log_append(itm.Log, "No queueable marker ranges found on the current timeline.", "warn")
        else
            log_append(itm.Log, ("Previewing %d render job(s). All are selected by default."):format(#ranges), "ok")
        end
    end

    win.On.Refresh.Clicked = function()
        scan()
    end

    win.On.Queue.Clicked = function()
        if not state.project or not state.timeline or not state.ranges then
            scan()
        end

        if not state.ranges or #state.ranges == 0 then
            log_append(itm.Log, "Nothing to queue. Refresh Scan first and check the preview list.", "warn")
            return
        end

        local ranges_to_queue = selected_preview_ranges()
        if #ranges_to_queue == 0 then
            log_append(itm.Log, "No marker ranges selected. Select one or more preview rows first.", "warn")
            return
        end

        log_append(itm.Log, ("Adding %d selected render job(s) using current Deliver page render settings..."):format(#ranges_to_queue), "head")
        local queued, failed = queue_ranges(state.project, state.timeline, ranges_to_queue, selected_options(), function(message, tag)
            log_append(itm.Log, message, tag)
        end)
        log_append(itm.Log, ("Done. Queued %d render job(s). Failed: %d."):format(queued, failed), failed == 0 and "ok" or "warn")
    end

    win.On.SelectAllRanges.Clicked = function()
        local n = itm.Preview:TopLevelItemCount()
        for i = 0, n - 1 do
            itm.Preview:TopLevelItem(i).Selected = true
        end
    end

    win.On.SelectNoRanges.Clicked = function()
        local n = itm.Preview:TopLevelItemCount()
        for i = 0, n - 1 do
            itm.Preview:TopLevelItem(i).Selected = false
        end
    end

    win.On.ClearLog.Clicked = function()
        log_clear(itm.Log)
    end

    win.On.BrowseOutput.Clicked = function()
        local path = fusion:RequestDir()
        if path and path ~= "" then
            itm.OutputDir.Text = path
        end
    end

    win.On.AllColors.Clicked = function()
        local enabled = not itm.AllColors.Checked
        for _, color in ipairs(MARKER_COLORS) do
            itm["Color_" .. color].Enabled = enabled
        end
    end

    win.On.SelectAllColors.Clicked = function()
        itm.AllColors.Checked = false
        for _, color in ipairs(MARKER_COLORS) do
            itm["Color_" .. color].Checked = true
            itm["Color_" .. color].Enabled = true
        end
    end

    win.On.SelectNoColors.Clicked = function()
        itm.AllColors.Checked = false
        for _, color in ipairs(MARKER_COLORS) do
            itm["Color_" .. color].Checked = false
            itm["Color_" .. color].Enabled = true
        end
    end

    win.On[WINDOW_ID].Close = function()
        disp:ExitLoop()
    end

    for _, color in ipairs(MARKER_COLORS) do
        itm["Color_" .. color].Enabled = false
    end

    win:Show()
    scan()
    disp:RunLoop()
    win:Hide()
end

local function main()
    if not fusion or not bmd or not bmd.UIDispatcher then
        print("This script needs Resolve/Fusion UIManager. Run it from DaVinci Resolve's Workspace > Scripts menu.")
        return
    end

    make_ui()
end

main()
