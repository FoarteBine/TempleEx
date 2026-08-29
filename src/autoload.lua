--[[
    TempleEx Autoload System
    Handles script auto-loading, session restore, rejoin relaunch
]]

local Autoload = {}
Autoload.__index = Autoload

local Executor = require(script.Parent.executor)
local Config = require(script.Parent.config)
local Core = require(script.Parent.core)
local Log = require(script.Parent.log)
local Shell = require(script.Parent.shell)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

Autoload.loadedScripts = {}       -- scriptId -> {thread, env, pluginDef}
Autoload.sessionData = {}         -- for session restore
Autoload.watchThread = nil

-- ============================================================
-- INIT
-- ============================================================
function Autoload.init()
    local config = Config.data
    if not config or not config.scripts then return end

    local scriptsConfig = config.scripts

    -- Load plugins from config
    local plugins = config.plugins or {}
    for _, pluginDef in ipairs(plugins) do
        if pluginDef.autoload then
            Autoload.loadScript(pluginDef)
        end
    end

    -- Watch plugins folder
    if scriptsConfig.watch_folder then
        Autoload.startFolderWatch()
    end

    -- Restore session
    if scriptsConfig.restore_session then
        Autoload.restoreSession()
    end

    -- Setup rejoin relaunch
    if scriptsConfig.rejoin_relaunch then
        Autoload.setupRejoinRelaunch()
    end

    Log.info("Autoload initialized")
end

-- ============================================================
-- LOAD SCRIPT
-- ============================================================
function Autoload.loadScript(pluginDef)
    if not pluginDef or not pluginDef.file then
        return false, "Invalid plugin definition"
    end

    local scriptId = pluginDef.name:gsub("%s+", "_"):lower()
    if Autoload.loadedScripts[scriptId] then
        Log.warn("Script already loaded:", scriptId)
        return false, "Already loaded"
    end

    local filePath = pluginDef.file
    local isGitUrl = filePath:match("^https?://") or filePath:match("^git@")

    local function executeScript(content, name)
        -- Create isolated environment
        local env = setmetatable({
            Temple = require(script.Parent.api),
            TempleApi = require(script.Parent.api),
            TempleEx = require(script.Parent.api),
            _G = _G,
            game = game,
            workspace = workspace,
            script = {Name = name},
            print = print,
            warn = warn,
            error = error,
            pcall = pcall,
            xpcall = xpcall,
            require = require,
            task = task,
            coroutine = coroutine,
            math = math,
            string = string,
            table = table,
            os = os,
            debug = debug,
            Vector2 = Vector2,
            Vector3 = Vector3,
            CFrame = CFrame,
            Color3 = Color3,
            UDim = UDim,
            UDim2 = UDim2,
            Ray = Ray,
            Rect = Rect,
            Enum = Enum,
            Instance = Instance,
            game = game,
            wait = task.wait,
            spawn = task.spawn,
            delay = task.delay,
            tick = tick,
            time = time,
            Random = Random,
            loadstring = loadstring,
            getgenv = getgenv,
            getfenv = getfenv,
            setfenv = setfenv,
            getrawmetatable = getrawmetatable,
            setreadonly = setreadonly,
            hookmetamethod = hookmetamethod,
            hookfunction = hookfunction,
            newcclosure = newcclosure,
        }, {__index = _G})

        -- Override require to sandbox
        env.require = function(mod)
            if type(mod) == "string" and mod:sub(1,1) ~= "." and mod:sub(1,1) ~= "/" then
                -- External module - block for security
                return nil, "External require blocked in sandbox"
            end
            return require(mod)
        end

        local func, err = loadstring(content, name)
        if not func then
            return false, "Compile error: " .. err
        end

        setfenv(func, env)

        local thread = task.spawn(function()
            local ok, err = pcall(func)
            if not ok then
                Log.error("Script '" .. name .. "' runtime error:", err)
                -- Show badge on dock
                if Shell and Shell.dockPins then
                    local pin = Shell.dockPins["window_" .. scriptId] or Shell.dockPins[scriptId]
                    if pin and pin.indicator then
                        pin.indicator.BackgroundColor3 = Color3.new(1, 0, 0)
                        pin.indicator.Visible = true
                    end
                end
            end
        end)

        Autoload.loadedScripts[scriptId] = {
            thread = thread,
            env = env,
            pluginDef = pluginDef,
            name = name,
            startTime = tick()
        }

        return true
    end

    if isGitUrl then
        -- Fetch from git (raw GitHub URL)
        local res = Executor.http(filePath)
        if not res.Success then
            return false, "Failed to fetch from URL: " .. (res.Error or "unknown")
        end
        return executeScript(res.Body, scriptId)
    else
        -- Local file
        local fullPath = filePath
        if not fullPath:match("^/") and not fullPath:match("^%a:") then
            -- Relative to workspace
            local workspacePath = Config.get("paths.workspace") or "."
            fullPath = workspacePath .. "/" .. fullPath
        end

        local ok, content = pcall(Executor.fs_read, fullPath)
        if not ok or not content then
            return false, "Failed to read script file: " .. fullPath
        end
        return executeScript(content, scriptId)
    end
end

-- ============================================================
-- STOP SCRIPT
-- ============================================================
function Autoload.stopScript(scriptId)
    local data = Autoload.loadedScripts[scriptId]
    if not data then return false end

    if data.thread then
        task.cancel(data.thread)
    end

    -- Call onUnload if plugin had one
    if data.pluginDef and data.pluginDef.onUnload then
        pcall(data.pluginDef.onUnload)
    end

    Autoload.loadedScripts[scriptId] = nil
    Log.info("Stopped script:", scriptId)
    return true
end

-- ============================================================
-- RELOAD SCRIPT
-- ============================================================
function Autoload.reloadScript(scriptId)
    local data = Autoload.loadedScripts[scriptId]
    if not data then return false end

    Autoload.stopScript(scriptId)
    task.wait(0.1)
    return Autoload.loadScript(data.pluginDef)
end

-- ============================================================
-- SESSION RESTORE
-- ============================================================
function Autoload.saveSession()
    local session = {
        timestamp = os.time(),
        scripts = {}
    }

    for scriptId, data in pairs(Autoload.loadedScripts) do
        table.insert(session.scripts, {
            id = scriptId,
            name = data.name,
            pluginDef = data.pluginDef
        })
    end

    local Executor = require(script.Parent.executor)
    pcall(Executor.fs_write, "cache/configs/session.json", HttpService:JSONEncode(session))
    Log.debug("Session saved:", #session.scripts, "scripts")
end

function Autoload.restoreSession()
    local Executor = require(script.Parent.executor)
    local ok, content = pcall(Executor.fs_read, "cache/configs/session.json")
    if not ok or not content then return end

    local ok2, session = pcall(function() return HttpService:JSONDecode(content) end)
    if not ok2 or not session or not session.scripts then return end

    Log.info("Restoring session:", #session.scripts, "scripts")

    local stagger = Config.get("scripts.stagger") or 200
    for i, scriptData in ipairs(session.scripts) do
        task.delay(i * stagger / 1000, function()
            if scriptData.pluginDef then
                Autoload.loadScript(scriptData.pluginDef)
            end
        end)
    end
end

-- ============================================================
-- REJOIN RELAUNCH (queue_on_teleport)
-- ============================================================
function Autoload.setupRejoinRelaunch()
    local reloadCode = [[
        -- TempleEx Auto-Reload on Rejoin
        loadstring(game:HttpGet("https://raw.githubusercontent.com/TempleEx/TempleEx/main/TempleEx.lua"))()
    ]]

    local ok, err = Executor.queue_on_teleport(reloadCode)
    if ok then
        Log.info("Rejoin relaunch armed")
    else
        Log.warn("queue_on_teleport failed:", err)
        -- Fallback: listen for respawn
        Autoload.setupRespawnFallback()
    end
end

function Autoload.setupRespawnFallback()
    local LocalPlayer = Players.LocalPlayer
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        -- Check if TempleEx is already loaded
        if not _G.TempleExLoaded then
            local reloadCode = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/TempleEx/TempleEx/main/TempleEx.lua"))()'
            pcall(function() loadstring(reloadCode)() end)
        end
    end)
end

-- ============================================================
-- FOLDER WATCH
-- ============================================================
function Autoload.startFolderWatch()
    local pluginsPath = Config.get("paths.plugins") or "plugins"
    local knownFiles = {}

    local function scan()
        local ok, files = pcall(Executor.fs_list, pluginsPath)
        if not ok or not files then return end

        local current = {}
        for _, f in ipairs(files) do
            if f:match("%.lua$") then
                current[f] = true
                if not knownFiles[f] then
                    -- New file detected
                    Log.info("New script detected in plugins/:", f)
                    -- Add to plugins list with autoload=false by default
                    local plugins = Config.get("plugins") or {}
                    local exists = false
                    for _, p in ipairs(plugins) do
                        if p.file == f then exists = true break end
                    end
                    if not exists then
                        table.insert(plugins, {
                            name = f:gsub("%.lua$", ""),
                            file = f,
                            autoload = false
                        })
                        Config.set("plugins", plugins)
                        Config.save()
                        -- Notify UI
                        if Shell and Shell.updateDockIndicators then
                            Shell.updateDockIndicators()
                        end
                    end
                end
            end
        end

        -- Check for deleted files
        for f, _ in pairs(knownFiles) do
            if not current[f] then
                Log.info("Script removed from plugins/:", f)
                -- Remove from plugins list
                local plugins = Config.get("plugins") or {}
                for i, p in ipairs(plugins) do
                    if p.file == f then
                        table.remove(plugins, i)
                        break
                    end
                end
                Config.set("plugins", plugins)
                Config.save()
            end
        end

        knownFiles = current
    end

    Autoload.watchThread = task.spawn(function()
        scan() -- initial
        while true do
            task.wait(3)
            scan()
        end
    end)
end

function Autoload.stopFolderWatch()
    if Autoload.watchThread then
        task.cancel(Autoload.watchThread)
        Autoload.watchThread = nil
    end
end

-- ============================================================
-- PERIODIC SESSION SAVE
-- ============================================================
task.spawn(function()
    while true do
        task.wait(30) -- save every 30 seconds
        Autoload.saveSession()
    end
end)

-- Save on game close
game:BindToClose(function()
    Autoload.saveSession()
end)

return Autoload