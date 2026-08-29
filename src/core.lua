--[[
    TempleEx Core Functions (Temple.Core)
    Declarative modules for built-in cheat functions
]]

local Core = {}
Core.__index = Core

local Executor = require(script.Parent.executor)
local Log = require(script.Parent.log)
local ThemeEngine = require(script.Parent.theme)
local Config = require(script.Parent.config)

Core.modules = {}       -- id -> module definition
Core.active = {}        -- id -> active state
Core.connections = {}   -- id -> {connection1, connection2, ...}
Core.flags = {}         -- id -> {param -> value}

-- Register a core function module
-- definition = {
--   id = "fly",
--   title = "Fly",
--   icon = "✈",  -- or image asset id
--   category = "Movement",
--   params = {
--     speed = { type = "number", default = 50, min = 1, max = 500, suffix = " studs/s" },
--     verticalSpeed = { type = "number", default = 50, min = 1, max = 500, suffix = " studs/s" }
--   },
--   keybind = "E",
--   onEnable = function(params) ... end,
--   onDisable = function() ... end,
--   onParamChange = function(param, value) ... end,
--   supportedExecutors = {"wave", "codex", ...}  -- nil = all
-- }
function Core.register(def)
    if not def.id then
        Log.error("Core.register: missing id")
        return
    end
    if Core.modules[def.id] then
        Log.warn("Core.register: overwriting module", def.id)
    end
    Core.modules[def.id] = def
    Core.active[def.id] = false
    Core.flags[def.id] = {}
    -- Initialize params with defaults
    if def.params then
        for k, v in pairs(def.params) do
            Core.flags[def.id][k] = v.default
        end
    end
    Log.debug("Registered core module:", def.id)
end

-- Get module definition
function Core.getModule(id)
    return Core.modules[id]
end

-- List all modules
function Core.listModules()
    local list = {}
    for id, def in pairs(Core.modules) do
        table.insert(list, {
            id = id,
            title = def.title,
            icon = def.icon,
            category = def.category,
            enabled = Core.active[id],
            params = Core.flags[id],
            keybind = def.keybind,
            supported = def.supportedExecutors == nil or table.find(def.supportedExecutors, Executor.info.name) ~= nil
        })
    end
    return list
end

-- Enable a module
function Core.enable(id)
    local def = Core.modules[id]
    if not def then
        return false, "Module not found: " .. id
    end

    -- Check executor support
    if def.supportedExecutors and table.find(def.supportedExecutors, Executor.info.name) == nil then
        return false, "Module '" .. id .. "' not supported on " .. Executor.info.name
    end

    if Core.active[id] then
        return true -- already enabled
    end

    -- Prepare params
    local params = Core.flags[id] or {}

    -- Call onEnable
    local ok, err = pcall(def.onEnable, params)
    if not ok then
        Log.error("Core enable error (" .. id .. "):", err)
        return false, err
    end

    Core.active[id] = true
    Log.info("Core module enabled:", id)

    -- Notify config to persist
    if Config and Config.set then
        Config.set("functions." .. id .. ".enabled", true)
        for k, v in pairs(params) do
            Config.set("functions." .. id .. "." .. k, v)
        end
        Config.save()
    end

    return true
end

-- Disable a module
function Core.disable(id)
    local def = Core.modules[id]
    if not def then
        return false, "Module not found: " .. id
    end

    if not Core.active[id] then
        return true -- already disabled
    end

    -- Call onDisable
    local ok, err = pcall(def.onDisable)
    if not ok then
        Log.error("Core disable error (" .. id .. "):", err)
        return false, err
    end

    Core.active[id] = false
    Log.info("Core module disabled:", id)

    if Config and Config.set then
        Config.set("functions." .. id .. ".enabled", false)
        Config.save()
    end

    return true
end

-- Toggle a module
function Core.toggle(id)
    if Core.active[id] then
        return Core.disable(id)
    else
        return Core.enable(id)
    end
end

-- Set parameter
function Core.setParam(id, param, value)
    local def = Core.modules[id]
    if not def then
        return false, "Module not found: " .. id
    end
    if not def.params or not def.params[param] then
        return false, "Parameter not found: " .. param
    end

    local pdef = def.params[param]
    -- Clamp/validate
    if pdef.type == "number" then
        value = tonumber(value) or pdef.default
        if pdef.min then value = math.max(pdef.min, value) end
        if pdef.max then value = math.min(pdef.max, value) end
    elseif pdef.type == "boolean" then
        value = value == true
    end

    Core.flags[id][param] = value

    if Core.active[id] and def.onParamChange then
        pcall(def.onParamChange, param, value)
    end

    if Config and Config.set then
        Config.set("functions." .. id .. "." .. param, value)
        Config.save()
    end

    return true
end

-- Get parameter
function Core.getParam(id, param)
    return Core.flags[id] and Core.flags[id][param]
end

-- Get all params for module
function Core.getParams(id)
    return Core.flags[id] or {}
end

-- Check if module is enabled
function Core.isEnabled(id)
    return Core.active[id] == true
end

-- Cleanup all modules (on unload/reload)
function Core.cleanupAll()
    for id, _ in pairs(Core.active) do
        if Core.active[id] then
            Core.disable(id)
        end
    end
end

-- Load persisted state from config
function Core.loadState(configData)
    if not configData or not configData.functions then return end
    for id, data in pairs(configData.functions) do
        if Core.modules[id] then
            if data.enabled then
                -- Restore params first
                for k, v in pairs(data) do
                    if k ~= "enabled" then
                        Core.flags[id][k] = v
                    end
                end
                -- Then enable
                task.spawn(function()
                    task.wait(0.1) -- small delay for other systems to initialize
                    Core.enable(id)
                end)
            end
        end
    end
end

return Core