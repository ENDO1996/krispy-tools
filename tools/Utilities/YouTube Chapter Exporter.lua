-- Krispy Tools product: youtube-chapter-exporter
-- Release: 2026.2
-- Source SHA-256: 0695273fb49be61d641ff3865a39b7682c990413f017f5f9b264157708bcf8fc
--[[==========================================================================
  YouTube Chapter Exporter for DaVinci Resolve  (v1.2)
  Free to use, modify, and share.
============================================================================]]

local VERSION = "1.2"
local WINDOW_ID = "YouTubeChapterExporterV1"

local SEP = package.config:sub(1, 1)
local IS_WINDOWS = SEP == "\\"

local DEFAULTS = { FIRST_CHAPTER_LABEL = "Intro", OUTPUT_FILENAME = "youtube_chapters.txt" }
local COLOR_OPTIONS = {
  "All colors", "Blue", "Cyan", "Green", "Yellow", "Red", "Pink", "Purple",
  "Fuchsia", "Rose", "Lavender", "Sky", "Mint", "Lemon", "Sand", "Cocoa", "Cream",
}

local function trim(s) return (tostring(s or "")):match("^%s*(.-)%s*$") end
local function homeDir() return os.getenv("USERPROFILE") or os.getenv("HOME") or "." end
local function defaultExportPath() return homeDir() .. SEP .. "Desktop" .. SEP .. DEFAULTS.OUTPUT_FILENAME end
local function splitPath(p)
  local dir, file = tostring(p or ""):match("^(.*)[/\\]([^/\\]+)$")
  if not dir then return "", tostring(p or "") end
  return dir, file
end

local APPDATA = os.getenv("APPDATA")
local CONFIG_PATH = (APPDATA and (APPDATA .. SEP .. "YouTube_Chapter_Exporter_State.txt"))
  or (homeDir() .. SEP .. ".youtube_chapter_exporter_state")

local STATE = { color="All colors", title_source="name", ensure_zero="1", export_path=defaultExportPath() }

local function load_state()
  local f = io.open(CONFIG_PATH, "r"); if not f then return end
  for line in f:lines() do
    local k, v = line:match("^([%w_]+)=(.*)$")
    if k and v and STATE[k] ~= nil then STATE[k] = v end
  end
  f:close()
end
local function save_state()
  local f = io.open(CONFIG_PATH, "w"); if not f then return end
  for _, k in ipairs({ "color", "title_source", "ensure_zero", "export_path" }) do
    f:write(k .. "=" .. tostring(STATE[k] or "") .. "\n")
  end
  f:close()
end

local function getResolve()
  if resolve ~= nil then return resolve end
  if type(Resolve) == "function" then return Resolve() end
  if bmd ~= nil and bmd.scriptapp then return bmd.scriptapp("Resolve") end
  return nil
end
local function getFusion()
  if fu ~= nil then return fu end
  if fusion ~= nil then return fusion end
  local app = getResolve()
  if app and app.Fusion then local ok, f = pcall(function() return app:Fusion() end); if ok and f then return f end end
  if bmd ~= nil and bmd.scriptapp then local ok, f = pcall(function() return bmd.scriptapp("Fusion") end); if ok and f then return f end end
  return nil
end

local resolveApp = getResolve()
local fuObj = getFusion()
local ui = fuObj and fuObj.UIManager
local disp = (ui and bmd and bmd.UIDispatcher) and bmd.UIDispatcher(ui) or nil

-- Theme (YouTube red on graphite)
local C = {
  bg="#0f0f0f", bg_input="#1f1f1f", bg_btn="#272727", bg_log="#161616",
  accent="#ff0033", accent2="#cc0000", accent_hi="#ff4d4d",
  fg="#f1f1f1", fg_dim="#aaaaaa",
  ok="#5fd06a", warn="#f2c45a", err="#ff6b6b",
  border="#3a3a3a", border_hot="#ff4d4d",
}

local SS = {
  win = ("background-color:%s; color:%s; font-family:'Segoe UI','Helvetica Neue',sans-serif;"):format(C.bg, C.fg),
  title = ("color:%s; font-size:17px; font-weight:800; font-family:'Segoe UI';"):format(C.fg),
  subtitle = ("color:%s; font-size:11px; font-family:'Segoe UI';"):format(C.fg_dim),
  label = ("color:%s; font-weight:600; font-family:'Segoe UI';"):format(C.fg),
  hint = ("color:%s; font-size:11px; font-family:'Segoe UI';"):format(C.fg_dim),
  -- The ::drop-down sub-control is borderless/transparent and shares the rounded
  -- right corners, otherwise Qt draws a square arrow button over the rounded corner.
  combo = ("QComboBox { background-color:%s; color:%s; border:1px solid %s; border-radius:6px; padding:4px 9px; } QComboBox:hover { border-color:%s; } QComboBox::drop-down { subcontrol-origin:padding; subcontrol-position:top right; width:22px; border:none; background:transparent; border-top-right-radius:6px; border-bottom-right-radius:6px; } QComboBox QAbstractItemView { background-color:%s; color:%s; selection-background-color:%s; border:1px solid %s; }")
    :format(C.bg_input, C.fg, C.border, C.border_hot, C.bg_input, C.fg, C.accent2, C.border),
  input = ("QLineEdit { background-color:%s; color:%s; border:1px solid %s; border-radius:6px; padding:5px 9px; selection-background-color:%s; } QLineEdit:focus { border-color:%s; }")
    :format(C.bg_input, C.fg, C.border, C.accent2, C.border_hot),
  check = ("QCheckBox { color:%s; font-family:'Segoe UI'; } QCheckBox::indicator { width:15px; height:15px; }"):format(C.fg),
  log = ("background-color:%s; color:%s; border:1px solid %s; border-radius:8px; padding:12px; font-family:Consolas,Menlo,monospace; font-size:12px; selection-background-color:%s;")
    :format(C.bg_log, C.fg, C.border, C.accent2),
  btn = ("QPushButton { background-color:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #343434,stop:1 %s); color:%s; border:1px solid %s; border-radius:7px; padding:7px 16px; font-weight:600; font-family:'Segoe UI'; } QPushButton:hover { border-color:%s; } QPushButton:pressed { background-color:#151515; }")
    :format(C.bg_btn, C.fg, C.border, C.border_hot),
  -- Subtle two-tone red (bright red -> deep red), horizontal like the amber reference. No white.
  btn_acc = "QPushButton { background-color:qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 #ff3b3b,stop:1 #cc0000); color:#ffffff; border:1px solid #8a0000; border-radius:7px; padding:8px 22px; font-weight:800; font-family:'Segoe UI'; } QPushButton:hover { background-color:qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 #ff5555,stop:1 #e00000); border-color:#ff9a9a; } QPushButton:pressed { background-color:#a80000; }",
  bar = ("background-color:%s;"):format(C.accent),
  sep = ("background-color:%s;"):format(C.border),
  footer = ("color:%s; font-size:10px; font-family:'Segoe UI';"):format(C.fg_dim),
}

local function show_message(title, text)
  if not (ui and disp) then print("[" .. tostring(title) .. "] " .. tostring(text)); return end
  local mwin = disp:AddWindow({ ID="YTMsg", WindowTitle=title, Geometry={400,300,460,200}, MinimumSize={420,180}, StyleSheet=SS.win }, {
    ui:VGroup{ Spacing=0,
      ui:VGap(20),
      ui:HGroup{ Weight=1, Spacing=0, ui:HGap(24),
        ui:VGroup{ Weight=1, Spacing=14,
          ui:Label{ Text=title, StyleSheet=SS.title, Weight=0 },
          ui:Label{ Text=text, WordWrap=true, StyleSheet=SS.label, Weight=1 },
          ui:HGroup{ Weight=0, ui:Label{ Weight=1 }, ui:Button{ ID="OK", Text="OK", StyleSheet=SS.btn_acc, MinimumSize={110,34}, Weight=0 } },
        },
        ui:HGap(24) },
      ui:VGap(20),
    },
  })
  mwin.On.OK.Clicked = function() disp:ExitLoop() end
  mwin.On.YTMsg.Close = function() disp:ExitLoop() end
  mwin:Show(); disp:RunLoop(); mwin:Hide()
end

if not resolveApp then print("ERROR: Could not connect to DaVinci Resolve."); return end
local projectManager = resolveApp:GetProjectManager()
local project = projectManager and projectManager:GetCurrentProject()
if not project then show_message("YouTube Chapter Exporter", "No project is open."); return end
local timeline = project:GetCurrentTimeline()
if not timeline then show_message("YouTube Chapter Exporter", "No timeline is open."); return end
local fps = tonumber(timeline:GetSetting("timelineFrameRate"))
if not fps or fps <= 0 then fps = tonumber(project:GetSetting("timelineFrameRate")) or 24 end

local function buildChapters(colorFilter, titleSource, ensureZero)
  local markers = timeline:GetMarkers()
  if not markers or next(markers) == nil then return "", 0, "This timeline has no markers yet." end
  local anyColor = (not colorFilter) or colorFilter == "" or colorFilter == "All colors"
  local function pickTitle(m)
    local title = (titleSource == "note") and (m.note or "") or (m.name or "")
    return (tostring(title):gsub("[\r\n\t]", " "):gsub("^%s+", ""):gsub("%s+$", ""))
  end
  local chapters = {}
  for frameId, m in pairs(markers) do
    if anyColor or tostring(m.color) == colorFilter then
      chapters[#chapters + 1] = { frame = tonumber(frameId), seconds = math.floor(tonumber(frameId) / fps), title = pickTitle(m) }
    end
  end
  if #chapters == 0 then return "", 0, "No markers match the color '" .. tostring(colorFilter) .. "'." end
  -- Sort by exact frame so two markers in the same second keep their timeline order.
  table.sort(chapters, function(a, b) return a.frame < b.frame end)
  if ensureZero and chapters[1].seconds > 0 then table.insert(chapters, 1, { seconds = 0, title = DEFAULTS.FIRST_CHAPTER_LABEL }) end
  local useHours = chapters[#chapters].seconds >= 3600
  local function fmt(sec)
    local h = math.floor(sec / 3600); local m = math.floor((sec % 3600) / 60); local s = sec % 60
    if useHours then return string.format("%d:%02d:%02d", h, m, s) else return string.format("%d:%02d", m, s) end
  end
  local lines = {}
  for _, ch in ipairs(chapters) do
    local title = ch.title ~= "" and ch.title or "Chapter"
    lines[#lines + 1] = fmt(ch.seconds) .. " " .. title
  end
  local warn = ""
  if #chapters < 3 then warn = "Heads up: YouTube needs at least 3 chapters to show them." end
  for i = 2, #chapters do
    if (chapters[i].seconds - chapters[i - 1].seconds) < 10 then
      warn = (warn ~= "" and (warn .. " ") or "") .. "Some chapters are under 10s apart (YouTube's minimum)."
      break
    end
  end
  return table.concat(lines, "\n"), #chapters, warn
end

local function writeFile(path, text)
  local f = io.open(path, "w"); if not f then return false end
  f:write(text .. "\n"); f:close(); return true
end

if os.getenv("YTCHAP_TEST") then _G.YTChap_build = buildChapters; return end

if not (ui and disp) then
  local out, n, warn = buildChapters("All colors", "name", true)
  print("\n===== YouTube Chapters (" .. n .. " lines) =====")
  print(out); print("====")
  if warn ~= "" then print(warn) end
  local path = defaultExportPath()
  if writeFile(path, out) then print("Saved to: " .. path) else print("Could not write file") end
  return
end

load_state()

-- LAYOUT: margins are built from explicit HGap/VGap on all four sides.
-- (Fusion's VGroup 'Margin' does not reliably inset the RIGHT/BOTTOM edges,
-- which is what caused earlier horizontal clipping.) Every fixed row is
-- height-pinned; the preview is the only flexible element; the window minimum
-- height sits above the content total; and there is a generous bottom gutter.
local ROW_H = 34
local PAD   = 26
local win = disp:AddWindow({
    ID = WINDOW_ID,
    WindowTitle = "YouTube Chapter Exporter",
    Geometry = { 200, 110, 740, 780 },
    MinimumSize = { 600, 740 },
    StyleSheet = SS.win,
  }, {
    ui:VGroup{ Spacing = 0,
      ui:VGap(22),
      ui:HGroup{ Weight = 1, Spacing = 0,
        ui:HGap(PAD),
        ui:VGroup{ Weight = 1, Spacing = 10,

          ui:HGroup{ Weight = 0, Spacing = 12, MinimumSize = {0,46}, MaximumSize = {9999,46},
            ui:Label{ Weight = 0, MinimumSize = {5,42}, MaximumSize = {5,42}, StyleSheet = SS.bar },
            ui:VGroup{ Weight = 1, Spacing = 2,
              ui:Label{ Text = "YouTube Chapter Exporter", StyleSheet = SS.title, Weight = 0 },
              ui:Label{ Text = "Turn your timeline markers into a ready-to-paste chapter list.", StyleSheet = SS.subtitle, Weight = 0 },
            },
          },
          ui:Label{ Weight = 0, MinimumSize = {0,1}, MaximumSize = {9999,1}, StyleSheet = SS.sep },

          ui:HGroup{ Weight = 0, MinimumSize = {0,ROW_H}, MaximumSize = {9999,ROW_H},
            ui:Label{ Text = "Marker color", StyleSheet = SS.label, Weight = 0.32 },
            ui:ComboBox{ ID = "ColorCombo", StyleSheet = SS.combo, Weight = 0.68 },
          },
          ui:HGroup{ Weight = 0, MinimumSize = {0,ROW_H}, MaximumSize = {9999,ROW_H},
            ui:Label{ Text = "Chapter title from", StyleSheet = SS.label, Weight = 0.32 },
            ui:ComboBox{ ID = "TitleCombo", StyleSheet = SS.combo, Weight = 0.68 },
          },
          ui:HGroup{ Weight = 0, MinimumSize = {0,ROW_H}, MaximumSize = {9999,ROW_H},
            ui:CheckBox{ ID = "ZeroChk", Text = 'Add a 0:00 "' .. DEFAULTS.FIRST_CHAPTER_LABEL .. '" line if the first marker is not at the start', StyleSheet = SS.check, Weight = 1 },
          },

          ui:Label{ Text = "Save the .txt file to", StyleSheet = SS.label, Weight = 0, MinimumSize = {0,20}, MaximumSize = {9999,20} },
          ui:HGroup{ Weight = 0, Spacing = 8, MinimumSize = {0,ROW_H}, MaximumSize = {9999,ROW_H},
            ui:LineEdit{ ID = "PathEdit", Text = STATE.export_path, StyleSheet = SS.input, Weight = 1 },
            ui:Button{ ID = "BrowseBtn", Text = "Browse...", StyleSheet = SS.btn, MinimumSize = {120,ROW_H}, MaximumSize = {120,ROW_H}, Weight = 0 },
          },

          ui:Label{ Weight = 0, MinimumSize = {0,1}, MaximumSize = {9999,1}, StyleSheet = SS.sep },

          ui:HGroup{ Weight = 0, MinimumSize = {0,20}, MaximumSize = {9999,20},
            ui:Label{ Text = "Preview", StyleSheet = SS.label, Weight = 1 },
            ui:Label{ ID = "CountLbl", Text = "", StyleSheet = SS.hint, Weight = 0 },
          },
          ui:TextEdit{ ID = "Preview", Text = "", ReadOnly = true, StyleSheet = SS.log, Weight = 1, MinimumSize = {0,150} },
          ui:Label{ Text = "Tip: click in the preview, press Ctrl/Cmd+A then Ctrl/Cmd+C to copy - or just Save.", StyleSheet = SS.hint, Weight = 0, MinimumSize = {0,18}, MaximumSize = {9999,18} },
          ui:Label{ ID = "StatusLbl", Text = "", StyleSheet = SS.hint, Weight = 0, MinimumSize = {0,18}, MaximumSize = {9999,18} },

          ui:HGroup{ Weight = 0, Spacing = 10, MinimumSize = {0,40}, MaximumSize = {9999,40},
            ui:Label{ Text = "Free to use and share  -  v" .. VERSION, StyleSheet = SS.footer, Weight = 1 },
            ui:Button{ ID = "CloseBtn", Text = "Close", StyleSheet = SS.btn, MinimumSize = {100,36}, MaximumSize = {120,36}, Weight = 0 },
            ui:Button{ ID = "SaveBtn", Text = "Save .txt", StyleSheet = SS.btn_acc, MinimumSize = {150,36}, MaximumSize = {180,36}, Weight = 0 },
          },

        },
        ui:HGap(PAD),
      },
      ui:VGap(26),
    },
  })

local itm = win:GetItems()
for _, c in ipairs(COLOR_OPTIONS) do itm.ColorCombo:AddItem(c) end
itm.TitleCombo:AddItem("Marker Name")
itm.TitleCombo:AddItem("Marker Notes")
do
  local idx = 0
  for i, c in ipairs(COLOR_OPTIONS) do if c == STATE.color then idx = i - 1 break end end
  itm.ColorCombo.CurrentIndex = idx
  itm.TitleCombo.CurrentIndex = (STATE.title_source == "note") and 1 or 0
  itm.ZeroChk.Checked = (STATE.ensure_zero ~= "0")
end

local function setStatus(msg, color)
  itm.StatusLbl.Text = msg or ""
  itm.StatusLbl.StyleSheet = ("color:%s; font-size:11px; font-family:'Segoe UI';"):format(color or C.fg_dim)
end
local function currentOptions()
  local color = itm.ColorCombo.CurrentText
  local titleSource = (itm.TitleCombo.CurrentText == "Marker Notes") and "note" or "name"
  return color, titleSource, itm.ZeroChk.Checked
end
local function persist()
  local color, titleSource, ensureZero = currentOptions()
  STATE.color = color; STATE.title_source = titleSource
  STATE.ensure_zero = ensureZero and "1" or "0"; STATE.export_path = trim(itm.PathEdit.Text)
  save_state()
end
local function refreshPreview()
  local color, titleSource, ensureZero = currentOptions()
  local out, n, warn = buildChapters(color, titleSource, ensureZero)
  itm.Preview.PlainText = out
  if n == 0 then itm.CountLbl.Text = ""; setStatus(warn, C.warn)
  else
    itm.CountLbl.Text = n .. (n == 1 and " chapter" or " chapters")
    if warn ~= "" then setStatus(warn, C.warn) else setStatus("Ready to save.", C.ok) end
  end
  return out, n
end

win.On.ColorCombo.CurrentIndexChanged = function() persist() refreshPreview() end
win.On.TitleCombo.CurrentIndexChanged = function() persist() refreshPreview() end
win.On.ZeroChk.Clicked                = function() persist() refreshPreview() end
win.On.BrowseBtn.Clicked = function()
  local startDir = select(1, splitPath(itm.PathEdit.Text))
  if startDir == "" then startDir = homeDir() end
  local chosen
  pcall(function() chosen = fuObj:RequestDir(startDir) end)
  if chosen and chosen ~= "" then
    local _, file = splitPath(itm.PathEdit.Text)
    if file == "" then file = DEFAULTS.OUTPUT_FILENAME end
    itm.PathEdit.Text = tostring(chosen):gsub("[/\\]+$", "") .. SEP .. file
    persist()
  else setStatus("If the folder picker didn't open, just type or paste a path above.", C.warn) end
end
win.On.SaveBtn.Clicked = function()
  local out, n = refreshPreview()
  if n == 0 then return end
  persist()
  local path = trim(itm.PathEdit.Text)
  if path == "" then path = defaultExportPath(); itm.PathEdit.Text = path end
  if writeFile(path, out) then setStatus("Saved " .. n .. (n == 1 and " chapter to: " or " chapters to: ") .. path, C.ok)
  else setStatus("Couldn't write to that location. Check the folder exists and is writable.", C.err) end
end
win.On.CloseBtn.Clicked = function() persist() disp:ExitLoop() end
win.On[WINDOW_ID].Close = function() persist() disp:ExitLoop() end

refreshPreview()
win:Show()
disp:RunLoop()
win:Hide()
