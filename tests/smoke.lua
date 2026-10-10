-- Smoke test for Krispy Tools outside DaVinci Resolve.
-- Loads every tool with a stand-in Resolve/Fusion API, opens its window, then fires every
-- button/event handler once. It cannot judge Resolve behaviour; it catches crashes on load,
-- Windows-only commands or paths reaching macOS, and missing platform branches.
-- Usage: luajit tests/smoke.lua "tools/Text/Caption Titler.lua" [...]
local IS_MAC = jit and jit.os == "OSX"
local IS_WIN = package.config:sub(1, 1) == "\\"
pcall(function() jit.off() end) -- so the instruction-count hook also sees hot loops

local report = { fails = {}, warns = {}, cmds = {} }
local function fail(m) report.fails[#report.fails + 1] = m end
local function warn(m) report.warns[#report.warns + 1] = m end

local WIN_ONLY = { "powershell", "cmd /c", "cmd.exe", "wscript", "explorer ", "explorer.exe", "where.exe", "reg query", "%.bat" }
local MAC_ONLY = { "osascript", "pbcopy", "open %-R", "^open ", "mdfind" }
local function check_cmd(kind, cmd)
  cmd = tostring(cmd or "")
  report.cmds[#report.cmds + 1] = kind .. ": " .. cmd:sub(1, 160)
  local low = cmd:lower()
  if not IS_WIN then for _, p in ipairs(WIN_ONLY) do if low:find(p) then fail("Windows-only command on " .. jit.os .. ": " .. cmd:sub(1, 160)) end end end
  if IS_WIN then for _, p in ipairs(MAC_ONLY) do if low:find(p) then fail("macOS-only command on Windows: " .. cmd:sub(1, 160)) end end end
end
local real_execute, real_popen, real_open = os.execute, io.popen, io.open
os.execute = function(c) check_cmd("execute", c); if not c then return real_execute() end; return real_execute(c) end
io.popen = function(c, m) check_cmd("popen", c); return real_popen(c, m) end
io.open = function(p, m)
  if not IS_WIN and type(p) == "string" and p:find("\\", 1, true) and (m or "r"):find("[wa]") then
    fail("Backslash path written on " .. jit.os .. ": " .. p)
  end
  return real_open(p, m)
end

-- UI stand-ins -------------------------------------------------------------
local STR = { Text = 1, PlainText = 1, HTML = 1, CurrentText = 1, PlaceholderText = 1, ToolTip = 1, StyleSheet = 1, WindowTitle = 1, ID = 1 }
local NUM = { CurrentIndex = 1, Value = 1, Minimum = 1, Maximum = 1, Interval = 1 }
local METHOD_RET = { Count = 0, TopLevelItemCount = 0, ColumnCount = 0, GetGeometry = { 0, 0, 0, 0 }, selectedItems = {}, SelectedItems = {}, GetItems = nil }
local new_element
local function auto_table()
  return setmetatable({}, { __index = function(t, k) local v = auto_table(); rawset(t, k, v); return v end })
end
local all_on = {}
new_element = function()
  local e = {}
  return setmetatable(e, { __index = function(t, k)
    if STR[k] then return "" end
    if NUM[k] then return 0 end
    if k == "Checked" then return false end
    if k == "Enabled" or k == "Visible" then return true end
    if k == "On" then local on = auto_table(); all_on[#all_on + 1] = on; rawset(t, k, on); return on end
    if k == "GetItems" then
      return function()
        return setmetatable({}, { __index = function(it, id) local el = new_element(); rawset(it, id, el); return el end })
      end
    end
    return function()
      local r = METHOD_RET[k]
      if r ~= nil then return r end
      if k:match("^New") or k:match("^Add") or k:match("Item$") or k:match("Child$") then return new_element() end
      return nil
    end
  end })
end
local ui = setmetatable({}, { __index = function(_, k)
  return function(_, a, b)
    if k == "Timer" then return new_element() end
    local t = type(b) == "table" and b or (type(a) == "table" and a or {})
    local el = new_element()
    for kk, vv in pairs(t) do rawset(el, kk, vv) end
    return el
  end
end })

local function make_disp()
  local d = new_element()
  rawset(d, "AddWindow", function() return new_element() end)
  rawset(d, "RunLoop", function() end)
  rawset(d, "ExitLoop", function() end)
  return d
end

-- Resolve API stand-ins: an open project with no timeline -------------------
local function obj(t) return setmetatable(t, { __index = function() return function() return nil end end }) end
local folder = obj({ GetClipList = function() return {} end, GetSubFolderList = function() return {} end, GetName = function() return "Master" end })
local media_pool = obj({ GetRootFolder = function() return folder end, GetCurrentFolder = function() return folder end })
local timeline = obj({
  GetName = function() return "Smoke Timeline" end, GetSetting = function(_, k) if k == "timelineFrameRate" then return "25" end; return "" end,
  GetTrackCount = function() return 1 end, GetItemListInTrack = function() return {} end, GetItemsInTrack = function() return {} end,
  GetMarkers = function() return {} end, GetStartFrame = function() return 90000 end, GetEndFrame = function() return 90250 end,
  GetStartTimecode = function() return "01:00:00:00" end, GetCurrentTimecode = function() return "01:00:00:00" end,
  GetTrackName = function() return "Track 1" end, GetIsTrackEnabled = function() return true end, GetUniqueId = function() return "smoke-tl" end,
})
local project = obj({
  GetName = function() return "Smoke Test" end, GetCurrentTimeline = function() return timeline end,
  GetTimelineCount = function() return 1 end, GetTimelineByIndex = function() return timeline end, GetMediaPool = function() return media_pool end,
  GetSetting = function() return "" end, GetRenderPresetList = function() return {} end,
  GetRenderJobList = function() return {} end, GetRenderFormats = function() return {} end,
  GetCurrentRenderFormatAndCodec = function() return {} end, IsRenderingInProgress = function() return false end,
  GetPresetList = function() return {} end,
})
local pm = obj({ GetCurrentProject = function() return project end })
local resolve = obj({
  GetProjectManager = function() return pm end, GetProductName = function() return "DaVinci Resolve Studio" end,
  GetVersionString = function() return "20.2.0.0" end, GetVersion = function() return { 20, 2, 0, 0, "" } end,
  GetCurrentPage = function() return "edit" end, OpenPage = function() return true end,
  GetMediaStorage = function() return obj({ GetMountedVolumeList = function() return {} end }) end,
  Fusion = function() return _G.fu end,
})
local home = os.getenv("HOME") or os.getenv("USERPROFILE") or "."
_G.fu = obj({
  UIManager = ui,
  MapPath = function(_, p) return home .. "/" .. tostring(p):gsub(":", "") end,
  RequestFile = function() return nil end, RequestDir = function() return nil end,
  GetResolve = function() return resolve end,
})
_G.fusion = _G.fu
_G.app = _G.fu
_G.Resolve = function() return resolve end
_G.bmd = obj({
  UIDispatcher = function() return make_disp() end,
  scriptapp = function(n) if n == "Resolve" then return resolve end; return _G.fu end,
  wait = function() end, fileexists = function(p) local f = real_open(p, "r"); if f then f:close(); return true end; return false end,
  readdir = function() return {} end,
})

-- Run ----------------------------------------------------------------------
local function budget(n) debug.sethook(function() error("TIMEOUT: still running after " .. n .. " instructions", 2) end, "", n) end
local function collect(t, path, out, seen)
  seen = seen or {}
  if seen[t] then return end; seen[t] = true
  for k, v in pairs(t) do
    if type(v) == "function" then out[#out + 1] = { path .. "." .. tostring(k), v }
    elseif type(v) == "table" then collect(v, path .. "." .. tostring(k), out, seen) end
  end
end

local file = arg[1]
local chunk, err = loadfile(file)
if not chunk then print("FAIL syntax: " .. tostring(err)); os.exit(1) end
budget(2e9)
local ok, e = xpcall(chunk, debug.traceback)
debug.sethook()
if not ok then fail("load: " .. tostring(e):sub(1, 600)) end

local handlers = {}
for i, on in ipairs(all_on) do collect(on, "On", handlers) end
local fired, herr = 0, 0
for _, h in ipairs(handlers) do
  budget(5e8)
  local hok, he = xpcall(function() h[2]({ who = "smoke", Key = "", Modifiers = {} }) end, debug.traceback)
  debug.sethook()
  fired = fired + 1
  if not hok then herr = herr + 1; warn(h[1] .. ": " .. tostring(he):match("[^\n]*")) end
end

print(("%s | %s | handlers fired %d, handler errors %d, shell commands %d"):format(file, jit and jit.os or "?", fired, herr, #report.cmds))
for _, c in ipairs(report.cmds) do print("  cmd  " .. c) end
for _, w in ipairs(report.warns) do print("  warn " .. w) end
for _, f in ipairs(report.fails) do print("  FAIL " .. f) end
os.exit(#report.fails == 0 and 0 or 1)
