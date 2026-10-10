-- Krispy Tools product: resolve-page-time-tracker
-- Release: 2026.2
-- Source SHA-256: 39f5a03920106c4c0ae49186239bed285f5e7474148be5cb3dff827d82687477
-- Resolve Page Time Tracker - Graphite 2026
-- Project-total view | Background tracking | Reset | Clean UI

local VERSION    = "2.15"
local WINDOW_ID  = "ResolvePageTimeTrackerGraphite2026V2"
local IS_WINDOWS = (os.getenv("SYSTEMROOT") ~= nil)
local SEP        = IS_WINDOWS and "\\" or "/"

local function getDataDir()
    if IS_WINDOWS then
        return (os.getenv("APPDATA") or "C:\\Users\\Public") .. SEP .. "ResolvePageTracker"
    else
        return (os.getenv("HOME") or "") .. "/Library/Application Support/ResolvePageTracker"
    end
end

local DATA_DIR       = getDataDir()
local DATA_FILE      = DATA_DIR .. SEP .. "data.json"
local ACTIVE_FILE    = DATA_DIR .. SEP .. "active.json"
local HEARTBEAT_FILE = DATA_DIR .. SEP .. "heartbeat.json"
local SIGNAL_FILE    = DATA_DIR .. SEP .. "show.signal"

local PAGES = {
    { key="media",     label="Media",     color="#546E7A" },
    { key="cut",       label="Cut",       color="#6D4C41" },
    { key="edit",      label="Edit",      color="#388E3C" },
    { key="fusion",    label="Fusion",    color="#5E35B1" },
    { key="color",     label="Color",     color="#C62828" },
    { key="fairlight", label="Fairlight", color="#00838F" },
    { key="deliver",   label="Deliver",   color="#9E9D24" },
    { key="photo",     label="Photo",     color="#AD1457" },
}
local PAGE_BY_KEY = {}
for _, p in ipairs(PAGES) do PAGE_BY_KEY[p.key] = p end

-- ============================================================
--  STYLE CONSTANTS
-- ============================================================
local C_BG      = "#151515"
local C_BG2     = "#181818"
local C_BG3     = "#202020"
local C_BTN     = "#2b2b2b"
local C_ACC     = "#4f9cff"
local C_ACC2    = "#78d6ff"
local C_GREEN   = "#00c853"
local C_YELL    = "#f57f17"
local C_FG      = "#f4f4f4"
local C_DIM     = "#a2a2a2"
local C_DIM2    = "#929292"
local C_WHT     = "#ffffff"

local function css(bg, fg, x)
    return "background-color:" .. (bg or "transparent") .. "; color:" .. (fg or C_FG) .. ";" .. (x or "")
end

local S_WIN     = css(C_BG, C_FG, " font-family:'Segoe UI','Helvetica Neue',sans-serif;")
local S_BTN     = "QPushButton { background-color:qlineargradient(x1:0,y1:0,x2:0,y2:1,stop:0 #343434,stop:1 #2b2b2b); color:#f4f4f4; border:1px solid #535353; padding:7px 14px; border-radius:7px; font-size:8pt; font-weight:600; } QPushButton:hover { border-color:#78d6ff; }"
local S_ACC     = "QPushButton { background-color:qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 #4f9cff,stop:1 #78d6ff); color:#101010; border:1px solid #4f9cff; padding:8px 16px; border-radius:7px; font-size:8pt; font-weight:800; } QPushButton:hover { border-color:#bceeff; }"
local S_START   = "QPushButton { background-color:qlineargradient(x1:0,y1:0,x2:1,y2:0,stop:0 #24b86a,stop:1 #69e8a1); color:#07140d; border:1px solid #4fd78b; padding:0px; border-radius:8px; font-size:11pt; font-weight:800; letter-spacing:2px; } QPushButton:hover { border-color:#b5ffd4; } QPushButton:disabled { background-color:#252525; color:#666666; border-color:#3b3b3b; }"
local S_STOP    = "QPushButton { background-color:#2b2b2b; color:#ff9d9d; border:1px solid #754242; padding:0px; border-radius:8px; font-size:10pt; font-weight:700; letter-spacing:2px; } QPushButton:hover { border-color:#ff7777; } QPushButton:disabled { color:#5e4949; border-color:#3b3333; }"
local S_DANG    = "QPushButton { background-color:#2b2020; color:#ff9d9d; border:1px solid #754242; padding:7px 12px; border-radius:7px; font-size:8pt; } QPushButton:hover { border-color:#ff7777; }"
local S_INPUT   = css(C_BG3, C_FG, " border:1px solid #535353; border-radius:6px; padding:5px 8px; font-size:8pt;")
local S_LOG     = css(C_BG2, C_FG, " border:1px solid #535353; border-radius:7px; padding:8px; font-family:Consolas,monospace; font-size:8pt;")
local S_SEPC    = "background-color:#535353;"
local S_DIM     = "color:" .. C_DIM2 .. "; font-size:8pt;"
local S_HDR     = "color:" .. C_ACC2 .. "; font-size:7pt; letter-spacing:2px; font-weight:700;"
local S_PROJLBL = "color:" .. C_FG   .. "; font-size:10pt; font-weight:700;"
local S_TRUN    = "color:" .. C_GREEN .. "; font-size:42pt; font-weight:700; font-family:Consolas,monospace;"
local S_TSTOP   = "color:#656565; font-size:42pt; font-weight:700; font-family:Consolas,monospace;"
local S_TLAST   = "color:#b5b5b5; font-size:42pt; font-weight:700; font-family:Consolas,monospace;"
local S_SUBRN   = "color:" .. C_GREEN .. "; font-size:8pt; font-weight:bold; letter-spacing:1px;"
local S_SUBSTP  = "color:" .. C_DIM   .. "; font-size:8pt;"
local S_PAGELBL = "color:" .. C_DIM2  .. "; font-size:8pt;"
local S_TAB     = css(C_BG, C_DIM, " border:1px solid transparent; padding:8px 14px; font-size:8pt; letter-spacing:1px;")
local S_TABON   = css(C_BG3, C_FG, " border:1px solid #535353; border-bottom-color:#4f9cff; padding:8px 14px; font-size:8pt; letter-spacing:1px; font-weight:bold;")
local S_VIEW    = css(C_BG3, C_DIM2, " border:1px solid #535353; padding:4px 8px; border-radius:6px; font-size:7pt; letter-spacing:1px;")
-- ============================================================
--  FILE HELPERS
-- ============================================================
local function ensureDir(dir)
    local exists=false
    pcall(function() if bmd and bmd.fileexists then exists=bmd.fileexists(dir) end end)
    if exists then return end
    if IS_WINDOWS then
        os.execute('md "' .. dir .. '" 2>NUL')
    else
        os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
    end
end
local function readFile(p)  local f=io.open(p,"r"); if not f then return nil end; local s=f:read("*all"); f:close(); return s end
local function writeFile(p,s) local f=io.open(p,"w"); if not f then return false end; f:write(s); f:close(); return true end
-- Write to a temp file, verify it, keep the previous version as .bak, then swap in.
-- A crash mid-write can never leave a half-written data file behind.
local function writeFileAtomic(p,s)
    local tmp=p..".tmp"
    if not writeFile(tmp,s) then return false end
    if readFile(tmp)~=s then pcall(os.remove,tmp); return false end
    local bak=p..".bak"
    pcall(os.remove,bak)
    local hadOld=os.rename(p,bak)
    local ok=os.rename(tmp,p)
    if not ok then if hadOld then pcall(os.rename,bak,p) end; pcall(os.remove,tmp); return false end
    return true
end

-- ============================================================
--  JSON  (bmd preferred, pure-Lua fallback)
-- ============================================================
local function jsonEncode(val)
    if bmd and bmd.tojson then return bmd.tojson(val) end
    local function enc(v)
        local T=type(v)
        if T=="nil" then return "null"
        elseif T=="boolean" then return tostring(v)
        elseif T=="number" then return (v~=v) and "null" or tostring(v)
        elseif T=="string" then
            return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"'
        elseif T=="table" then
            if #v>0 then local a={}; for _,i in ipairs(v) do table.insert(a,enc(i)) end; return "["..table.concat(a,",").."]"
            else local o={}; for k,i in pairs(v) do table.insert(o,enc(tostring(k))..":"..enc(i)) end; return "{"..table.concat(o,",").."}" end
        end; return "null"
    end; return enc(val)
end
local function jsonDecode(src)
    if bmd and bmd.fromjson then local ok,r=pcall(bmd.fromjson,src); if ok and r then return r end end
    if not src or src=="" then return {} end
    local pos=1
    local function skip() while pos<=#src and src:sub(pos,pos):match("%s") do pos=pos+1 end end
    local parse; parse=function()
        skip(); local c=src:sub(pos,pos)
        if c=='"' then
            pos=pos+1; local r=""
            while pos<=#src do
                local ch=src:sub(pos,pos)
                if ch=='\\' then pos=pos+1; local e=src:sub(pos,pos)
                    if e=='n' then r=r..'\n' elseif e=='t' then r=r..'\t' elseif e=='r' then r=r..'\r' else r=r..e end
                elseif ch=='"' then pos=pos+1; return r
                else r=r..ch end; pos=pos+1
            end; return r
        elseif c=='{' then
            pos=pos+1; skip(); local obj={}
            if src:sub(pos,pos)=='}' then pos=pos+1; return obj end
            while pos<=#src do
                skip(); local k=parse(); skip(); pos=pos+1; skip()
                obj[k]=parse(); skip()
                if src:sub(pos,pos)=='}' then pos=pos+1; return obj end; pos=pos+1
            end; return obj
        elseif c=='[' then
            pos=pos+1; skip(); local arr={}
            if src:sub(pos,pos)==']' then pos=pos+1; return arr end
            while pos<=#src do skip(); table.insert(arr,parse()); skip()
                if src:sub(pos,pos)==']' then pos=pos+1; return arr end; pos=pos+1
            end; return arr
        elseif src:sub(pos,pos+3)=="true" then pos=pos+4; return true
        elseif src:sub(pos,pos+4)=="false" then pos=pos+5; return false
        elseif src:sub(pos,pos+3)=="null" then pos=pos+4; return nil
        else local n=src:match("^-?%d+%.?%d*[eE]?[+-]?%d*",pos); if n then pos=pos+#n; return tonumber(n) end
        end
    end
    local ok,r=pcall(parse); return (ok and r) or {}
end

-- ============================================================
--  TIME HELPERS
-- ============================================================
local function fmtSecs(s) s=math.max(0,math.floor(s or 0)); return string.format("%02d:%02d:%02d",math.floor(s/3600),math.floor((s%3600)/60),s%60) end
local function dtStr(t)   return os.date("%Y-%m-%d %H:%M:%S", t or os.time()) end
local function dateStr(t) return os.date("%Y-%m-%d", t or os.time()) end
local function timeStr(t) return os.date("%H:%M:%S", t or os.time()) end

-- ============================================================
--  DATA HELPERS
-- ============================================================
local function newData() return {version=2,projects={},settings={}} end
local function decodeData(s)
    if not s or s:match("^%s*$") then return nil end
    if not s:match("^%s*{") or not s:match("}%s*$") then return nil end  -- truncated or foreign file
    local ok,d=pcall(jsonDecode,s)
    if ok and type(d)=="table" and type(d.projects)=="table" then return d end
    return nil
end
local DATA_LOAD_NOTE=nil
local function loadData()
    ensureDir(DATA_DIR)
    local s=readFile(DATA_FILE)
    local d=decodeData(s)
    if d then return d end
    -- Main file missing or unreadable: fall back to the last good backup, never silently start empty.
    local b=decodeData(readFile(DATA_FILE..".bak"))
    if s and not s:match("^%s*$") then
        local keep=DATA_DIR..SEP.."data.unreadable-"..os.date("%Y%m%d-%H%M%S")..".json"
        writeFile(keep,s)
        DATA_LOAD_NOTE="data.json could not be read; a copy was kept as "..keep..(b and " and the backup was restored." or ".")
        print("[Tracker] "..DATA_LOAD_NOTE)
    end
    if b then return b end
    return newData()
end
local function saveData(d) local ok,s=pcall(jsonEncode,d); if ok and s then return writeFileAtomic(DATA_FILE,s) end; return false end
local function getOrMakeProj(d,name)
    if not d.projects[name] then d.projects[name]={name=name,sessions={},totalSecs=0,pageTotals={}} end
    return d.projects[name]
end
local function getProj(d,name)
    return d.projects and d.projects[name]
end

-- Page-time computation
local function computePageSecs(changes, endTime)
    local out={}; endTime=endTime or os.time()
    for i,ev in ipairs(changes) do
        local nxt=(changes[i+1] and changes[i+1].time) or endTime
        local dur=nxt-ev.time
        if dur>0 and ev.page then out[ev.page]=(out[ev.page] or 0)+dur end
    end
    return out
end
local function dominantPage(ps) local best,bv=nil,-1; for k,v in pairs(ps) do if v>bv then best=k;bv=v end end; return best end

-- Active session (crash recovery + background resume)
local function readActive()
    local s=readFile(ACTIVE_FILE); if not s or s=="" then return nil end
    local ok,a=pcall(jsonDecode,s); return (ok and a and a.startTimestamp) and a or nil
end
local function deleteActive() pcall(os.remove, ACTIVE_FILE) end

local function recoverActiveSession(data, forceProject)
    local a=readActive(); if not a then return nil end
    local endTime=a.lastSaved or os.time()
    local duration=math.max(0,endTime-a.startTimestamp)
    if duration<10 then deleteActive(); return nil end
    local ps=computePageSecs(a.pageChanges or {},endTime)
    local sess={
        date=dateStr(a.startTimestamp), startTime=a.startTime or dtStr(a.startTimestamp),
        endTime=dtStr(endTime), totalSecs=duration, pageTotals=ps,
        mainPage=dominantPage(ps), recovered=true,
    }
    local projName=forceProject or a.project or "Unknown"
    local proj=getOrMakeProj(data,projName)
    table.insert(proj.sessions,sess)
    proj.totalSecs=(proj.totalSecs or 0)+duration
    if not proj.pageTotals then proj.pageTotals={} end
    for pk,pv in pairs(ps) do proj.pageTotals[pk]=(proj.pageTotals[pk] or 0)+pv end
    saveData(data); deleteActive()
    print(string.format("[Tracker] Recovered %s for '%s' (%s)", sess.date, projName, fmtSecs(duration)))
    return {projName=projName, duration=duration, sess=sess}
end

-- ============================================================
--  SYSTEM INPUT IDLE  (seconds since last mouse/keyboard input)
-- ============================================================
local sysIdleSecs=nil
pcall(function()
    local ffi=require("ffi")
    if IS_WINDOWS then
        pcall(ffi.cdef,[[ typedef struct { unsigned int cbSize; unsigned int dwTime; } KRISPY_LASTINPUTINFO;
            int GetLastInputInfo(KRISPY_LASTINPUTINFO* plii); unsigned int GetTickCount(void); ]])
        local u32=ffi.load("user32"); local k32=ffi.load("kernel32")
        local lii=ffi.new("KRISPY_LASTINPUTINFO"); lii.cbSize=ffi.sizeof(lii)
        sysIdleSecs=function()
            if u32.GetLastInputInfo(lii)==0 then return nil end
            local d=(tonumber(k32.GetTickCount())-tonumber(lii.dwTime))/1000
            if d<0 then return 0 end; return d
        end
    else
        pcall(ffi.cdef,[[ double CGEventSourceSecondsSinceLastEventType(int source, unsigned int eventType); ]])
        local cg=ffi.load("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
        sysIdleSecs=function() return tonumber(cg.CGEventSourceSecondsSinceLastEventType(1,0xFFFFFFFF)) end
    end
    if not sysIdleSecs() then sysIdleSecs=nil end
end)

-- ============================================================
--  BACKGROUND TRACKING HELPERS  (heartbeat + show signal)
-- ============================================================
local function writeHeartbeat()
    pcall(function()
        writeFile(HEARTBEAT_FILE, '{"ts":'..tostring(os.time())..'}')
    end)
end
local function readHeartbeat()
    local s=readFile(HEARTBEAT_FILE); if not s then return nil end
    local ok,h=pcall(jsonDecode,s); return (ok and type(h)=="table") and h or nil
end
local function writeSignal()
    pcall(function() writeFile(SIGNAL_FILE,"1") end)
end

-- ============================================================
--  CSV EXPORT
-- ============================================================
local function exportCSV(proj,path)
    local hdrs={}; for _,p in ipairs(PAGES) do table.insert(hdrs,'"'..p.label..' (s)"') end
    local lines={'"#","Date","Start","End","Duration","Secs","Main Page",'..table.concat(hdrs,",")}
    local sorted={}; for _,s in ipairs(proj.sessions or {}) do table.insert(sorted,s) end
    table.sort(sorted,function(a,b) return (a.startTime or "")>(b.startTime or "") end)
    for i,sess in ipairs(sorted) do
        local cols={}; for _,p in ipairs(PAGES) do table.insert(cols,tostring(sess.pageTotals and sess.pageTotals[p.key] or 0)) end
        table.insert(lines,string.format('%d,"%s","%s","%s","%s",%d,"%s",%s',
            #sorted-i+1,sess.date or "",sess.startTime or "",sess.endTime or "",
            fmtSecs(sess.totalSecs or 0),sess.totalSecs or 0,sess.mainPage or "",table.concat(cols,",")))
    end
    return writeFile(path,table.concat(lines,"\n").."\n")
end

-- ============================================================
--  MAIN WINDOW
-- ============================================================
local function run(resolve, initProjName, data, resumeSession)

    local ui   = fusion.UIManager
    local disp = bmd.UIDispatcher(ui)

    local st = {
        running         = false,
        startTime       = nil,
        pageChanges     = {},
        curPage         = nil,
        idleSecs        = 120,
        lastPoll        = 0,
        lastDispUpdate  = 0,
        data            = data,
        projName        = initProjName,
        lastPageTotals  = {},
        lastSessionTotal= 0,
        viewMode        = "project",
        lastStopReason  = nil,
        lastActivity    = os.time(),
        lastSig         = nil,
        lastActiveSave  = 0,
    }

    if resumeSession then
        local ts = resumeSession.startTimestamp
        if ts and ts > 0 then
            st.running     = true
            st.startTime   = ts
            st.pageChanges = resumeSession.pageChanges or {}
            st.projName    = resumeSession.project or initProjName
            st.curPage     = resumeSession.curPage or nil
            st.lastPoll    = os.time()
            print("[Tracker] Resuming session from " .. timeStr(ts))
        else
            deleteActive()
            print("[Tracker] Active session data corrupt -- discarded.")
        end
    end

    local startSession, refreshHistory, refreshStats  -- forward declarations

    local function mkSep()
        return ui:Label{Weight=0,MinimumSize={1,1},MaximumSize={9999,1},StyleSheet=S_SEPC}
    end

    local BAR=16
    local function fmtRow(label,secs,totalSecs)
        local pct=(totalSecs and totalSecs>0) and math.floor(secs/totalSecs*100) or 0
        local fill=(totalSecs and totalSecs>0) and math.floor(secs/totalSecs*BAR) or 0
        return string.format("%-10s  %s  %3d%%  [%s%s]",
            label,fmtSecs(secs),pct,string.rep("|",fill),string.rep(".",BAR-fill))
    end

    -- Page rows
    local pgDef = {ID="PgSection",Weight=0,Spacing=0}
    for _, p in ipairs(PAGES) do
        table.insert(pgDef, ui:Label{
            ID="PgLbl_"..p.key, Weight=0,
            Text=fmtRow(p.label,0,nil),
            StyleSheet="color:"..C_DIM.."; font-family:Consolas,monospace; font-size:8pt;",
        })
    end
    table.insert(pgDef, ui:VGap{Weight=0, MinimumSize={1,4}, MaximumSize={9999,4}})
    local pgSection = ui:VGroup(pgDef)

    -- ----------------------------------------------------------------
    --  LIVE TAB
    -- ----------------------------------------------------------------
    local liveTab = ui:VGroup{ID="LiveTab",Spacing=4,
        ui:VGap(8),
        ui:Label{
            ID="BigTimer",Weight=0,Text="00:00:00",
            StyleSheet=S_TSTOP,
            Alignment={AlignHCenter=true,AlignVCenter=true},
            MinimumSize={0,66},
        },
        ui:Label{
            ID="SubLbl",Weight=0,Text="STOPPED",
            StyleSheet=S_SUBSTP,
            Alignment={AlignHCenter=true},
        },
        ui:Label{
            ID="PageLbl",Weight=0,Text="",
            StyleSheet=S_PAGELBL,
            Alignment={AlignHCenter=true},
        },
        ui:VGap(4),
        mkSep(),
        ui:VGap(4),
        ui:Button{ID="StartBtn",Weight=0,Text="START TRACKING",StyleSheet=S_START,MinimumSize={300,46}},
        ui:VGap(4),
        mkSep(),
        ui:VGap(2),
        ui:HGroup{Weight=0,Spacing=4,
            ui:Label{ID="ViewHdrLbl",Weight=1,StyleSheet=S_HDR,Text="PROJECT"},
            ui:Button{ID="ViewToggleBtn",Text="SESSION",StyleSheet=S_VIEW,
                MinimumSize={64,0},MaximumSize={64,9999}},
        },
        pgSection,
        ui:VGap(0),
    }

    -- ----------------------------------------------------------------
    --  HISTORY TAB
    -- ----------------------------------------------------------------
    local histTab = ui:VGroup{ID="HistTab",Spacing=4,
        ui:TextEdit{ID="HistLog",Weight=1,ReadOnly=true,StyleSheet=S_LOG},
        ui:HGroup{Weight=0,Spacing=4,
            ui:Button{ID="HistRefBtn",Text="Refresh",   StyleSheet=S_BTN,Weight=1},
            ui:Button{ID="ExportBtn", Text="Export CSV",StyleSheet=S_ACC,Weight=1},
        },
    }

    -- ----------------------------------------------------------------
    --  STATS TAB
    -- ----------------------------------------------------------------
    local statsTab = ui:VGroup{ID="StatsTab",Spacing=4,
        ui:TextEdit{ID="StatsLog",Weight=1,ReadOnly=true,StyleSheet=S_LOG},
        ui:Button{ID="StatsRefBtn",Text="Refresh",StyleSheet=S_BTN,Weight=0},
    }

    -- ----------------------------------------------------------------
    --  SETTINGS TAB
    -- ----------------------------------------------------------------
    local defaultIdleMins=5
    pcall(function()
        if data.settings and type(data.settings.idleMins)=="number" then
            defaultIdleMins=math.max(1,math.min(120,data.settings.idleMins))
        end
    end)
    local settingsTab = ui:VGroup{ID="SettingsTab",Spacing=8,
        ui:Label{Weight=0,Text="IDLE DETECTION",StyleSheet=S_HDR},
        ui:Label{Weight=0,StyleSheet=S_DIM,
            Text="If you step away, the timer pauses after this many minutes with no mouse, keyboard or playhead activity.\nThose idle minutes are not counted. Tracking resumes the moment you move the mouse or press a key."},
        ui:HGroup{Weight=0,Spacing=6,
            ui:Label{Weight=1,StyleSheet=S_DIM,Text="Pause after (minutes of no activity):"},
            ui:SpinBox{ID="IdleSpin",Minimum=1,Maximum=120,Value=defaultIdleMins,
                StyleSheet="QSpinBox { background-color:#202020; color:#f4f4f4; border:1px solid #535353; border-radius:6px; padding:2px 24px 2px 10px; font-size:10pt; } QSpinBox::up-button, QSpinBox::down-button { width:20px; }",
                MinimumSize={104,34},MaximumSize={104,34}},
        },
        mkSep(),
        ui:Label{Weight=0,Text="BACKGROUND TRACKING",StyleSheet=S_HDR},
        ui:Label{Weight=0,StyleSheet=S_DIM,
            Text="Closing the window while tracking keeps the timer running."},
        ui:Label{Weight=0,StyleSheet=S_DIM,
            Text="Re-open via Workspace > Scripts to bring the window back."},
        mkSep(),
        ui:Label{Weight=0,Text="DATA",StyleSheet=S_HDR},
        ui:Stack{ID="ResetStack", Weight=0, MinimumSize={0,42}, MaximumSize={9999,42},
            ui:HGroup{Weight=0,Spacing=0,
                ui:Label{Weight=1,Text=""},
                ui:Button{ID="ResetBtn",Text="Reset Project",StyleSheet=S_DANG,Weight=0, MinimumSize={120,34}, MaximumSize={140,34}},
            },
            ui:HGroup{Weight=0,Spacing=4,
                ui:Label{ID="ResetConfirmLbl",Weight=1,StyleSheet=S_DIM,
                    Text="Reset project? All time data will be erased."},
                ui:Button{ID="ResetCancelBtn",Text="Cancel",StyleSheet=S_BTN,
                    MinimumSize={0,0},MaximumSize={60,9999}},
                ui:Button{ID="ResetYesBtn",Text="Yes, Reset",StyleSheet=S_DANG,
                    MinimumSize={0,0},MaximumSize={80,9999}},
            },
        },
        ui:LineEdit{ID="DataPathEdit",Weight=0,ReadOnly=true,Text=DATA_FILE,StyleSheet=S_INPUT},
        ui:Button{ID="OpenDirBtn",Text="Open Folder",StyleSheet=S_BTN,Weight=0},
        mkSep(),
        ui:Label{Weight=0,StyleSheet=S_DIM,
            Text="Resolve Page Time Tracker  v"..VERSION.."  --  data stored locally only."},
        ui:VGap(0),
    }

    local TABS   = {"TBtnLive","TBtnHist","TBtnStats","TBtnSet"}
    local TABTXT = {"LIVE","HISTORY","STATS","SETTINGS"}

    local win = disp:AddWindow({
        ID=WINDOW_ID,
        WindowTitle=(st.running and "[TRACKING]  " or "").."Page Time Tracker  --  "..st.projName,
        Geometry={100,80,620,520},
        MinimumSize={560,500},
        StyleSheet=S_WIN,
        ui:VGroup{Spacing=0,
            ui:HGroup{Weight=0,Spacing=0,
                ui:HGap(12),
                ui:Label{ID="ProjLbl",Weight=1,Text=st.projName,
                    StyleSheet=S_PROJLBL,MinimumSize={0,30}},
                ui:HGap(12),
            },
            ui:Label{Weight=0,MinimumSize={1,1},MaximumSize={9999,1},StyleSheet="background-color:#252525;"},
            ui:HGroup{Weight=0,Spacing=0,
                ui:Button{ID=TABS[1],Text=TABTXT[1],StyleSheet=S_TABON},
                ui:Button{ID=TABS[2],Text=TABTXT[2],StyleSheet=S_TAB},
                ui:Button{ID=TABS[3],Text=TABTXT[3],StyleSheet=S_TAB},
                ui:Button{ID=TABS[4],Text=TABTXT[4],StyleSheet=S_TAB},
            },
            ui:Label{Weight=0,MinimumSize={1,1},MaximumSize={9999,1},StyleSheet="background-color:#161616;"},
            ui:HGroup{Weight=1,Spacing=0,
                ui:HGap(14),
                ui:Stack{ID="Stack",liveTab,histTab,statsTab,settingsTab},
                ui:HGap(14),
            },
            ui:VGap(10),
        },
    })

    local itm = win:GetItems()
    itm.Stack.CurrentIndex   = 0
    itm.ResetStack.CurrentIndex = 0

    st.idleSecs = defaultIdleMins * 60

    local function setRunningUI(running)
        pcall(function()
            itm.StartBtn.Text=running and "STOP" or "START TRACKING"
            itm.StartBtn.StyleSheet=running and S_STOP or S_START
        end)
    end
    setRunningUI(st.running)

    -- ----------------------------------------------------------------
    --  CORE FUNCTIONS
    -- ----------------------------------------------------------------

    local function saveActive()
        if not st.running then return end
        local active={
            project=st.projName, startTime=dtStr(st.startTime),
            startTimestamp=st.startTime, pageChanges=st.pageChanges,
            curPage=st.curPage, lastSaved=os.time(), idleSecs=st.idleSecs,
        }
        local ok,s=pcall(jsonEncode,active)
        if ok and s and writeFileAtomic(ACTIVE_FILE,s) then st.lastActiveSave=os.time() end
    end

    local function updatePageRows(ps,totalSecs)
        for _,p in ipairs(PAGES) do
            local lbl=itm["PgLbl_"..p.key]
            if lbl then
                local v=ps and ps[p.key] or 0
                lbl.Text=fmtRow(p.label,v,totalSecs)
                if v>0 then
                    lbl.StyleSheet="color:"..p.color.."; font-family:Consolas,monospace; font-size:8pt;"
                else
                    lbl.StyleSheet="color:"..C_DIM.."; font-family:Consolas,monospace; font-size:8pt;"
                end
            end
        end
    end

    -- Compute page data for display based on current viewMode
    local function getDisplayPageData()
        local now=os.time()
        local proj=st.data.projects and st.data.projects[st.projName]
        if st.viewMode=="project" then
            local basePT=(proj and proj.pageTotals) or {}
            local baseTotal=(proj and proj.totalSecs) or 0
            if st.running and st.startTime then
                local curPS=computePageSecs(st.pageChanges,now)
                local sessionSecs=math.max(0,now-st.startTime)
                local merged={}
                for _,p in ipairs(PAGES) do
                    merged[p.key]=(basePT[p.key] or 0)+(curPS[p.key] or 0)
                end
                return merged, baseTotal+sessionSecs
            else
                return basePT, baseTotal>0 and baseTotal or nil
            end
        else
            -- session view
            if st.running and st.startTime then
                local curPS=computePageSecs(st.pageChanges,now)
                local sessionSecs=math.max(0,now-st.startTime)
                return curPS, sessionSecs>0 and sessionSecs or nil
            else
                return st.lastPageTotals or {},
                    (st.lastSessionTotal and st.lastSessionTotal>0) and st.lastSessionTotal or nil
            end
        end
    end

    local function updateDisplay()
        local now=os.time()
        local projectBase=0
        pcall(function()
            if st.data.projects and st.data.projects[st.projName] then
                projectBase=st.data.projects[st.projName].totalSecs or 0
            end
        end)
        -- Big timer always shows cumulative project total
        if st.running and st.startTime then
            local sessionSecs=math.max(0,now-st.startTime)
            itm.BigTimer.Text=fmtSecs(sessionSecs)
            itm.BigTimer.StyleSheet=S_TRUN
            itm.SubLbl.Text="TRACKING  --  project total "..fmtSecs(projectBase+sessionSecs)
            itm.SubLbl.StyleSheet=S_SUBRN
        else
            itm.BigTimer.Text=fmtSecs(projectBase)
            itm.BigTimer.StyleSheet=projectBase>0 and S_TLAST or S_TSTOP
            itm.SubLbl.Text=(st.lastStopReason=="idle" and "PAUSED (idle) - resumes when you are back" or "STOPPED")..(projectBase>0 and "  --  project total" or "")
            itm.SubLbl.StyleSheet=S_SUBSTP
        end
        -- Section header + toggle button
        pcall(function()
            if st.viewMode=="project" then
                itm.ViewHdrLbl.Text="PROJECT"
                itm.ViewToggleBtn.Text="SESSION"
            else
                itm.ViewHdrLbl.Text=st.running and "THIS SESSION" or "LAST SESSION"
                itm.ViewToggleBtn.Text="PROJECT"
            end
        end)
        -- Page bars
        local ps,total=getDisplayPageData()
        updatePageRows(ps,total)
        -- Current page label
        if st.curPage then
            local pInfo=PAGE_BY_KEY[st.curPage]
            if pInfo then
                itm.PageLbl.Text=pInfo.label.." page"
                itm.PageLbl.StyleSheet="color:"..pInfo.color.."; font-size:8pt;"
            end
        end
        pcall(function()
            win.WindowTitle=(st.running and "[TRACKING]  " or "").."Page Time Tracker  --  "..st.projName
        end)
        st.lastDispUpdate=now
    end

    local function persistSession(endTime,autoStopped)
        if not st.running then return end
        local ps=computePageSecs(st.pageChanges,endTime)
        local duration=math.max(0,endTime-(st.startTime or endTime))
        local sess={
            date=dateStr(st.startTime), startTime=dtStr(st.startTime),
            endTime=dtStr(endTime), totalSecs=duration, pageTotals=ps,
            mainPage=dominantPage(ps), autoStopped=autoStopped or false,
        }
        local proj=getOrMakeProj(st.data,st.projName)
        table.insert(proj.sessions,sess)
        proj.totalSecs=(proj.totalSecs or 0)+duration
        if not proj.pageTotals then proj.pageTotals={} end
        for pk,pv in pairs(ps) do proj.pageTotals[pk]=(proj.pageTotals[pk] or 0)+pv end
        saveData(st.data); deleteActive()
        st.lastPageTotals=ps; st.lastSessionTotal=duration
        st.lastStopReason=autoStopped and "idle" or "manual"
        st.running=false; st.startTime=nil; st.pageChanges={}
        setRunningUI(false)
        pcall(function() itm.PageLbl.Text="" end)
        print(string.format("[Tracker] Session saved: %s (%s)",sess.date,fmtSecs(duration)))
        pcall(function()
            local idx=itm.Stack.CurrentIndex
            if idx==1 then refreshHistory() end
            if idx==2 then refreshStats() end
        end)
    end

    local function checkProjectChange()
        local newName=nil
        pcall(function()
            local pm=resolve:GetProjectManager()
            if pm then local proj=pm:GetCurrentProject(); if proj then newName=proj:GetName() end end
        end)
        if newName and newName~="" and newName~=st.projName then
            local wasTracking=st.running
            if st.running then pcall(persistSession,os.time(),false) end
            st.projName=newName; st.curPage=nil; st.viewMode="project"
            itm.ProjLbl.Text=newName
            -- Auto-resume only if we were already tracking AND project has prior time
            if wasTracking then
                pcall(startSession)
                print("[Tracker] Auto-resumed: "..newName)
            end
        end
    end

    local function detectPage()
        local page=nil
        pcall(function() page=resolve:GetCurrentPage() end)
        if not page or page=="" then return end
        if page~=st.curPage then
            if st.running then
                table.insert(st.pageChanges,{time=os.time(),page=page})
                pcall(saveActive); pcall(updateDisplay)
            end
            st.curPage=page; st.lastPoll=os.time()
        else
            st.lastPoll=os.time()
        end
        local pInfo=PAGE_BY_KEY[page]
        if pInfo then
            itm.PageLbl.Text=pInfo.label.." page"
            itm.PageLbl.StyleSheet="color:"..pInfo.color.."; font-size:8pt;"
        else
            itm.PageLbl.Text=page; itm.PageLbl.StyleSheet=S_PAGELBL
        end
    end

    -- Activity = mouse/keyboard input anywhere (when available) or any change in page,
    -- timeline or playhead position (covers playback and remote/scripted work).
    local function noteActivity()
        local now=os.time()
        local sig=nil
        pcall(function()
            local proj=resolve:GetProjectManager():GetCurrentProject()
            local tl=proj and proj:GetCurrentTimeline()
            sig=tostring(st.curPage).."|"..tostring(tl and tl:GetName()).."|"..tostring(tl and tl:GetCurrentTimecode())
        end)
        if sig and sig~=st.lastSig then st.lastSig=sig; st.lastActivity=now end
        if sysIdleSecs then
            local ok,idle=pcall(sysIdleSecs)
            if ok and idle then st.lastActivity=math.max(st.lastActivity,now-math.floor(idle)) end
        end
    end
    local function isIdle()
        if not st.running then return false end
        return (os.time()-st.lastActivity)>=st.idleSecs
    end

    local function checkSignal()
        local f=io.open(SIGNAL_FILE,"r")
        if f then
            f:close()
            pcall(os.remove,SIGNAL_FILE)
            pcall(function() win:Show() end)
            pcall(function() win:Raise() end)
            print("[Tracker] Show signal received -- window restored.")
        end
    end

    local function tick()
        pcall(checkProjectChange); pcall(detectPage); pcall(noteActivity)
        if isIdle() then
            -- Close the session at the last moment of activity so idle time is never billed.
            local endAt=math.max(st.startTime or 0, st.lastActivity)
            pcall(persistSession,endAt,true)
            pcall(function()
                itm.PageLbl.Text="Paused (idle)"
                itm.PageLbl.StyleSheet="color:"..C_YELL.."; font-size:8pt;"
            end)
        elseif (not st.running) and st.lastStopReason=="idle" and (os.time()-st.lastActivity)<3 then
            pcall(startSession)
            print("[Tracker] Activity detected -- resumed after idle.")
        end
        if st.running and (os.time()-st.lastActiveSave)>=15 then pcall(saveActive) end
        pcall(updateDisplay)
        pcall(writeHeartbeat)
        pcall(checkSignal)
    end

    startSession = function()
        if st.running then return end
        pcall(detectPage)
        local now=os.time()
        st.running=true; st.startTime=now; st.lastPoll=now; st.lastActivity=now
        st.lastStopReason=nil
        st.pageChanges=st.curPage and {{time=now,page=st.curPage}} or {}
        setRunningUI(true)
        pcall(saveActive); pcall(updateDisplay)
        print("[Tracker] Session started: "..st.projName)
    end

    local function stopSession()
        if not st.running then return end
        pcall(detectPage); pcall(persistSession,os.time(),false); pcall(updateDisplay)
    end

    refreshHistory = function()
        local proj=getProj(st.data,st.projName)
        local sessions=(proj and proj.sessions) or {}
        if #sessions==0 and not st.running then
            itm.HistLog.PlainText="No sessions for this project yet."; return
        end
        local totSecs=(proj and proj.totalSecs) or 0
        if st.running and st.startTime then
            totSecs=totSecs+math.max(0,os.time()-st.startTime)
        end
        local lines={
            "PROJECT: "..st.projName,
            "Total: "..fmtSecs(totSecs).."  |  "..#sessions.." session"
                ..(#sessions==1 and "" or "s")..(st.running and "  (+live)" or ""),
            string.rep("=",50),
        }
        if st.running and st.startTime then
            local now=os.time()
            local sessSecs=math.max(0,now-st.startTime)
            local curPS=computePageSecs(st.pageChanges,now)
            table.insert(lines,string.rep("-",50))
            table.insert(lines,"LIVE  "..dtStr(st.startTime).."  |  "..fmtSecs(sessSecs))
            for _,p in ipairs(PAGES) do
                local v=curPS[p.key] or 0
                if v>0 then table.insert(lines,"    "..fmtRow(p.label,v,sessSecs)) end
            end
        end
        local sorted={}
        for _,s in ipairs(sessions) do table.insert(sorted,s) end
        table.sort(sorted,function(a,b) return (a.startTime or "")>(b.startTime or "") end)
        for i,sess in ipairs(sorted) do
            local idx=#sessions-i+1
            table.insert(lines,string.rep("-",50))
            table.insert(lines,string.format("#%-3d  %s  |  %s",
                idx,sess.startTime or sess.date or "?",fmtSecs(sess.totalSecs or 0)))
            if sess.pageTotals then
                for _,p in ipairs(PAGES) do
                    local v=sess.pageTotals[p.key] or 0
                    if v>0 then
                        table.insert(lines,"    "..fmtRow(p.label,v,sess.totalSecs or 0))
                    end
                end
            end
        end
        itm.HistLog.PlainText=table.concat(lines,"\n")
    end

    refreshStats = function()
        local proj=getProj(st.data,st.projName)
        local sessions=(proj and proj.sessions) or {}
        local total,pt,byDay=0,{},{}
        for _,sess in ipairs(sessions) do
            total=total+(sess.totalSecs or 0)
            if sess.pageTotals then
                for k,v in pairs(sess.pageTotals) do pt[k]=(pt[k] or 0)+v end
            end
            local d=sess.date or "?"; byDay[d]=(byDay[d] or 0)+(sess.totalSecs or 0)
        end
        if st.running and st.startTime then
            local now=os.time()
            local liveSecs=math.max(0,now-st.startTime)
            total=total+liveSecs
            local curPS=computePageSecs(st.pageChanges,now)
            for k,v in pairs(curPS) do pt[k]=(pt[k] or 0)+v end
            local today=dateStr(now); byDay[today]=(byDay[today] or 0)+liveSecs
        end
        local sessCount=#sessions+(st.running and 1 or 0)
        local lines={
            "PROJECT: "..st.projName,
            "Sessions : "..sessCount..(st.running and "  (1 live)" or ""),
            "Total    : "..fmtSecs(total),
        }
        if sessCount>0 and total>0 then
            table.insert(lines,"Average  : "..fmtSecs(math.floor(total/sessCount)))
        end
        table.insert(lines,""); table.insert(lines,"-- Time by Page --")
        for _,p in ipairs(PAGES) do
            local v=pt[p.key] or 0
            if v>0 then
                table.insert(lines,"  "..fmtRow(p.label,v,total))
            end
        end
        local days={}
        for d,s in pairs(byDay) do table.insert(days,{d=d,s=s}) end
        table.sort(days,function(a,b) return a.d>b.d end)
        if #days>0 then
            table.insert(lines,""); table.insert(lines,"-- By Day --")
            for i=1,math.min(30,#days) do
                table.insert(lines,"  "..days[i].d.."  "..fmtSecs(days[i].s))
            end
        end
        itm.StatsLog.PlainText=table.concat(lines,"\n")
    end

    local function switchTab(idx)
        itm.Stack.CurrentIndex=idx-1
        for i,id in ipairs(TABS) do
            itm[id].StyleSheet=(i==idx) and S_TABON or S_TAB
        end
        if idx==2 then refreshHistory() end
        if idx==3 then refreshStats()   end
    end

    -- ----------------------------------------------------------------
    --  EVENT HANDLERS
    -- ----------------------------------------------------------------
    win.On.TBtnLive.Clicked  =function(ev) pcall(switchTab,1) end
    win.On.TBtnHist.Clicked  =function(ev) pcall(switchTab,2) end
    win.On.TBtnStats.Clicked =function(ev) pcall(switchTab,3) end
    win.On.TBtnSet.Clicked   =function(ev) pcall(switchTab,4) end

    win.On.StartBtn.Clicked=function(ev)
        local ok,e=pcall(st.running and stopSession or startSession)
        if not ok then print("[Tracker] Start/Stop: "..tostring(e)) end
    end

    win.On.ViewToggleBtn.Clicked=function(ev)
        st.viewMode=(st.viewMode=="project") and "session" or "project"
        pcall(updateDisplay)
    end

    win.On.ResetBtn.Clicked=function(ev)
        pcall(function()
            itm.ResetConfirmLbl.Text="Reset '"..st.projName.."'? All time data will be erased."
            itm.ResetStack.CurrentIndex=1
        end)
    end
    win.On.ResetCancelBtn.Clicked=function(ev)
        pcall(function() itm.ResetStack.CurrentIndex=0 end)
    end
    win.On.ResetYesBtn.Clicked=function(ev)
        pcall(function()
            if st.running then pcall(stopSession) end
            if st.data.projects then st.data.projects[st.projName]=nil end
            saveData(st.data)
            st.lastPageTotals={}; st.lastSessionTotal=0
            itm.ResetStack.CurrentIndex=0
            pcall(updateDisplay)
            updatePageRows({},nil)
            print("[Tracker] Project reset: "..st.projName)
        end)
    end

    win.On.HistRefBtn.Clicked  =function(ev) pcall(refreshHistory) end
    win.On.StatsRefBtn.Clicked =function(ev) pcall(refreshStats)   end

    win.On.ExportBtn.Clicked=function(ev)
        local ok,e=pcall(function()
            local proj=getProj(st.data,st.projName)
            if not proj or not proj.sessions or #proj.sessions==0 then
                print("[Tracker] Nothing to export."); return
            end
            local safenm=st.projName:gsub('[<>:"/\\|?*%z%c]',"_")
            local path=DATA_DIR..SEP..safenm.."_sessions.csv"
            if exportCSV(proj,path) then
                print("[Tracker] Exported: "..path)
                refreshHistory()
                itm.HistLog.PlainText=itm.HistLog.PlainText.."\n\nExported: "..path
            else print("[Tracker] Export failed") end
        end)
        if not ok then print("[Tracker] Export: "..tostring(e)) end
    end

    win.On.OpenDirBtn.Clicked=function(ev)
        pcall(function()
            if IS_WINDOWS then os.execute('explorer "'..DATA_DIR..'"')
            else os.execute('open "'..DATA_DIR..'"') end
        end)
    end

    win.On.IdleSpin.ValueChanged=function(ev)
        pcall(function()
            local v=itm.IdleSpin.Value
            if v and type(v)=="number" and v>=1 then
                st.idleSecs=v*60
                if not st.data.settings then st.data.settings={} end
                st.data.settings.idleMins=v
                saveData(st.data)
            end
        end)
    end

    win.On[WINDOW_ID].Activate =function(ev) pcall(updateDisplay) end
    win.On[WINDOW_ID].FocusIn  =function(ev) pcall(updateDisplay) end
    win.On[WINDOW_ID].MouseMove=function(ev)
        st.lastActivity=os.time()
        if not st.running then return end
        pcall(function()
            local now=os.time()
            if now>st.lastDispUpdate then
                st.lastDispUpdate=now
                local base=0
                if st.data.projects and st.data.projects[st.projName] then
                    base=st.data.projects[st.projName].totalSecs or 0
                end
                itm.BigTimer.Text=fmtSecs(math.max(0,now-(st.startTime or now)))
            end
        end)
    end

    win.On[WINDOW_ID].Close=function(ev)
        if st.running then
            -- Close while tracking = hide (keep running in background)
            pcall(detectPage); pcall(saveActive); pcall(writeHeartbeat)
            win:Hide()
            print("[Tracker] Window hidden -- tracking in background.")
            print("[Tracker] Re-open via Workspace > Scripts to restore the window.")
        else
            -- Close while stopped = actually quit
            disp:ExitLoop()
        end
    end

    -- ----------------------------------------------------------------
    --  TIMER  (confirmed pattern: ui:Timer upvalue + disp.On.Timeout)
    -- ----------------------------------------------------------------
    local timerOK=false
    local tickGuard=false
    local function safeTick()
        if tickGuard then return end
        tickGuard=true
        local ok,e=pcall(tick); if not ok then print("[Tracker] tick: "..tostring(e)) end
        tickGuard=false
        if not timerOK then
            timerOK=true
            print("[Tracker] Timer firing -- live display active")
        end
    end

    local trackerTmr=ui:Timer{ID="TrackerTmr",Interval=1000,SingleShot=false}
    function disp.On.Timeout(ev)
        if ev and ev.who=="TrackerTmr" then safeTick() end
    end

    pcall(detectPage); pcall(updateDisplay); pcall(refreshHistory)
    if DATA_LOAD_NOTE then pcall(function() itm.PageLbl.Text=DATA_LOAD_NOTE; itm.PageLbl.StyleSheet="color:"..C_YELL.."; font-size:8pt;" end) end
    win:Show()
    pcall(function() win.MouseTracking=true end)
    pcall(function() win:SetAttribute("mouseTracking",true) end)
    trackerTmr:Start()

    disp:RunLoop()

    pcall(function() trackerTmr:Stop() end)
    pcall(os.remove, HEARTBEAT_FILE)
    win:Hide()
end

-- ============================================================
--  MAIN
-- ============================================================
local function main()
    if not fusion then
        print("ERROR: fusion global not found.")
        print("Set Preferences > System > General > External scripting = Local.")
        return
    end
    local resolve=fusion:GetResolve()
    if not resolve then print("ERROR: Cannot reach Resolve."); return end
    local pm=resolve:GetProjectManager()
    if not pm then print("ERROR: Cannot get ProjectManager."); return end
    local project=pm:GetCurrentProject()
    if not project then print("ERROR: No project open."); return end
    local projName=project:GetName() or "Unknown"
    print("[Tracker] v"..VERSION.." | "..projName)

    local data=loadData()

    -- Check for a running background instance (heartbeat < 3s old)
    local hb=readHeartbeat()
    if hb and type(hb.ts)=="number" and (os.time()-hb.ts)<3 then
        writeSignal()
        print("[Tracker] Background instance detected -- show signal sent.")
        return
    end

    -- Auto-resume: if last save was recent (within idle window) resume silently.
    -- If too much time passed the user was idle -- auto-save and open fresh.
    local active=readActive()
    if active then
        local activeProjName=active.project or projName
        local elapsed=math.max(0,os.time()-(active.lastSaved or active.startTimestamp))
        local idleSecs=active.idleSecs or 120
        if elapsed<=idleSecs then
            print(string.format("[Tracker] Auto-resuming '%s' (away %s)",
                activeProjName,fmtSecs(elapsed)))
            run(resolve,activeProjName,data,active)
            return
        else
            print(string.format("[Tracker] Session idle %s -- auto-saved.",fmtSecs(elapsed)))
            pcall(recoverActiveSession,data,activeProjName)
        end
    end

    run(resolve, projName, data, nil)
end

local ok,err=pcall(main)
if not ok then
    local msg="Resolve Page Time Tracker -- Error:\n"..tostring(err)
    print(msg)
    local tmp=os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
    local f=io.open(tmp..SEP.."resolve_tracker_error.txt","w")
    if f then f:write(msg.."\n"); f:close() end
end
