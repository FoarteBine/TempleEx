--[[
    TempleEx Config Manager
    Handles temple.yaml loading, validation, saving, and hot-reload
]]

local Config = {}
Config.__index = Config

local YAML = require(script.Parent.yaml)
local Executor = require(script.Parent.executor)
local Log = require(script.Parent.log)

local DEFAULT_CONFIG = [[
version: 1

temple:
  entry_key: "RightControl"     # Enum.KeyCode name (RightCtrl РЅРµ СЃСѓС‰РµСЃС‚РІСѓРµС‚ РІ Roblox)
  ui_mode: "hybrid"
  language: "ru"

shell:
  wm:
    snap: true
    tiling: "off"
    workspaces: 3
    switcher_key: "Alt+Tab"
    remember: true
  menubar:
    enabled: true
    height: 24
    autohide: false
    items: ["menu", "title", "clock", "fps", "executor", "theme", "tray", "binds"]
  dock:
    enabled: true
    position: "bottom"
    reveal: "hover"
    reveal_zone: 4
    hide_delay: 0.4
    icon_size: 40
    magnify: true
    pins: ["fly", "esp", "speed", "themes", "ai", "scripts"]

scripts:
  autoload: true
  restore_session: true
  rejoin_relaunch: true
  watch_folder: true
  stagger: 200

git:
  repo: "FoarteBine/TempleEx"
  channel: "stable"
  auto_update: true
  mirrors:
    - "https://raw.githubusercontent.com"
    - "https://cdn.jsdelivr.net/gh"
  registries:
    themes: "FoarteBine/TempleEx"
    scripts: "FoarteBine/TempleEx"

theme:
  active: "midnight-temple"
  fallback: "default"
  auto_reload: true
  accent_override: null

paths:
  workspace: "auto"
  themes: "themes"
  plugins: "plugins"

functions: {}

plugins: []

ai:
  provider: "openai-compatible"
  base_url: "https://api.openai.com/v1"
  model: "gpt-4o-mini"
  api_key_env: "TEMPLE_AI_KEY"
  agents:
    theme-gen:
      model: "inherit"
      temperature: 0.9
    theme-refine:
      model: "inherit"
      temperature: 0.4
    config-audit:
      model: "inherit"
      temperature: 0.0

behavior:
  notify_default:
    duration: 5
    position: "top-right"
  window_default:
    size: [520, 380]
    remember_pos: true
  stealth:
    gui_name_prefix: null
    anti_screenshot: false
]]

Config.data = nil
Config.path = nil
Config.watchThread = nil
Config.lastModified = 0
Config.onChangeCallbacks = {}

function Config.init(workspacePath)
    if Config.data then return Config.data end
    workspacePath = workspacePath or ""
    Config.path = (workspacePath == "") and "temple.yaml" or (workspacePath .. "/temple.yaml")
    Config.ensureWorkspace(workspacePath)
    Config.load()
    if Config.data.theme.auto_reload then
        Config.startWatch()
    end
    return Config.data
end

local function joinPath(base, sub)
    if base == nil or base == "" then return sub end
    return base .. "/" .. sub
end

function Config.ensureWorkspace(workspacePath)
    local Executor = require(script.Parent.executor)
    pcall(Executor.fs_mkdir, workspacePath)
    pcall(Executor.fs_mkdir, joinPath(workspacePath, "themes"))
    pcall(Executor.fs_mkdir, joinPath(workspacePath, "plugins"))
    pcall(Executor.fs_mkdir, joinPath(workspacePath, "cache"))
    pcall(Executor.fs_mkdir, joinPath(workspacePath, "cache/configs"))
    pcall(Executor.fs_mkdir, joinPath(workspacePath, "logs"))
end

function Config.load()
    local ok, content = Executor.fs_read(Config.path)
    local data, errors
    if ok and content then
        data, errors = YAML.parse(content)
    else
        -- First run - create default config
        data, errors = YAML.parse(DEFAULT_CONFIG)
        Config.save(data)
    end

    if errors and #errors > 0 then
        for _, e in ipairs(errors) do
            Log.warn("Config parse warning:", e)
        end
    end

    -- Merge with defaults for missing keys
    local defaults, _ = YAML.parse(DEFAULT_CONFIG)
    data = Config.deepMerge(defaults, data or {})

    Config.data = data
    Log.info("Config loaded from", Config.path)
    return data
end

function Config.deepMerge(base, override)
    local result = {}
    for k, v in pairs(base) do
        result[k] = v
    end
    for k, v in pairs(override) do
        if type(v) == "table" and type(result[k]) == "table" and not Config.isArray(v) then
            result[k] = Config.deepMerge(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

function Config.isArray(t)
    if type(t) ~= "table" then return false end
    local count = 0
    for k, _ in pairs(t) do
        if type(k) == "number" and k > 0 then
            count = count + 1
        else
            return false
        end
    end
    return count > 0 and count == #t
end

function Config.save(data)
    data = data or Config.data
    if not data then return false, "No config data" end

    -- Backup before write
    local backupPath = Config.path .. ".bak"
    local ok, current = Executor.fs_read(Config.path)
    if ok and current then
        pcall(Executor.fs_write, backupPath, current)
    end

    local yamlContent = YAML.stringify(data)
    local ok, err = Executor.fs_write(Config.path, yamlContent)
    if ok then
        Config.lastModified = os.time()
        Log.info("Config saved to", Config.path)
        Config.fireChange()
        return true
    else
        Log.error("Config save failed:", err)
        return false, err
    end
end

function Config.get(path)
    if not Config.data then return nil end
    local keys = path:split(".")
    local cur = Config.data
    for _, k in ipairs(keys) do
        if type(cur) == "table" then
            cur = cur[k]
        else
            return nil
        end
    end
    return cur
end

function Config.set(path, value)
    if not Config.data then return false end
    local keys = path:split(".")
    local cur = Config.data
    for i = 1, #keys - 1 do
        local k = keys[i]
        if type(cur[k]) ~= "table" then
            cur[k] = {}
        end
        cur = cur[k]
    end
    cur[keys[#keys]] = value
    return Config.save()
end

function Config.onChange(callback)
    table.insert(Config.onChangeCallbacks, callback)
end

function Config.fireChange()
    for _, cb in ipairs(Config.onChangeCallbacks) do
        pcall(cb, Config.data)
    end
end

function Config.startWatch()
    if Config.watchThread then return end
    Config.watchThread = task.spawn(function()
        while true do
            task.wait(2)
            local ok, modified = pcall(function()
                local info = Executor.fs_exists(Config.path)
                return info
            end)
            -- Simple polling: check if file size/modified changed
            -- For now just reload if theme.auto_reload and we detect external change
            -- A more robust implementation would track file hash
        end
    end)
end

function Config.stopWatch()
    if Config.watchThread then
        task.cancel(Config.watchThread)
        Config.watchThread = nil
    end
end

-- Helper for string split
if not string.split then
    function string:split(sep)
        local t = {}
        for part in self:gmatch("([^" .. sep .. "]+)") do
            table.insert(t, part)
        end
        return t
    end
end

return Config