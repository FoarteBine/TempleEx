--[[
    TempleEx Theme Engine
    Handles theme loading, token resolution, hot-swap, and validation
]]

local ThemeEngine = {}
ThemeEngine.__index = ThemeEngine

local YAML = require(script.Parent.yaml)
local Executor = require(script.Parent.executor)
local Log = require(script.Parent.log)
local Config = require(script.Parent.config)

ThemeEngine.themes = {}        -- name -> parsed theme table
ThemeEngine.currentTheme = nil -- active theme name
ThemeEngine.tokens = {}        -- resolved token -> value
ThemeEngine.palette = {}       -- resolved palette
ThemeEngine.subscribers = {}   -- callback functions for token changes
ThemeEngine.watchThread = nil

-- Token role list (required tokens from schema)
local REQUIRED_TOKENS = {
    "window.bg", "window.border", "window.title.fg", "window.close.hover",
    "sidebar.bg", "sidebar.item.active.bg", "sidebar.item.fg",
    "tab.active", "tab.idle.fg", "tab.hover",
    "section.header.fg",
    "element.bg", "element.border", "element.focus",
    "text.primary", "text.muted", "text.accent",
    "toggle.track.off", "toggle.track.on", "toggle.knob",
    "slider.fill", "slider.knob",
    "dropdown.bg", "dropdown.item.hover",
    "button.primary.bg", "button.primary.fg", "button.ghost.fg", "button.danger.bg",
    "input.bg", "input.placeholder", "keybind.bg",
    "notification.bg", "notification.fg",
    "notification.level.info", "notification.level.success", "notification.level.warn", "notification.level.error",
    "menubar.bg", "menubar.fg",
    "dock.bg", "dock.icon", "dock.icon.active", "dock.indicator",
    "snap.preview", "switcher.bg", "workspace.active.fg"
}

local REQUIRED_PALETTE = {
    "bg-0", "bg-1", "bg-2", "fg-0", "fg-1", "accent", "accent-2", "danger", "success", "warning"
}

-- Convert hex color to Color3
local function hexToColor3(hex)
    hex = hex:gsub("#", "")
    if #hex == 3 then
        hex = hex:gsub("(.)", "%1%1")
    end
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    return Color3.new(r, g, b)
end

-- Resolve palette reference (e.g., "palette.accent" -> actual Color3)
local function resolvePaletteRef(ref, palette)
    if type(ref) ~= "string" then return ref end
    local key = ref:match("^palette%.(.+)$")
    if key and palette[key] then
        return palette[key]
    end
    -- Maybe it's a direct hex
    if ref:sub(1,1) == "#" then
        return hexToColor3(ref)
    end
    return ref
end

-- Deep clone table
local function deepClone(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = deepClone(v)
    end
    return copy
end

-- Merge theme with base (extends)
function ThemeEngine.mergeTheme(base, override)
    local result = deepClone(base)
    for k, v in pairs(override) do
        if type(v) == "table" and type(result[k]) == "table" and not ThemeEngine.isArray(v) then
            result[k] = ThemeEngine.mergeTheme(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

function ThemeEngine.isArray(t)
    if type(t) ~= "table" then return false end
    local count = 0
    for k, _ in pairs(t) do
        if type(k) == "number" and k > 0 then count = count + 1 else return false end
    end
    return count > 0 and count == #t
end

-- Load a single theme file
function ThemeEngine.loadTheme(name, themesPath)
    local path = themesPath .. "/" .. name .. ".yaml"
    local ok, content = pcall(Executor.fs_read, path)
    if not ok or not content then
        return nil, "Failed to read theme file: " .. path
    end

    local theme, errors = YAML.parse(content)
    if errors and #errors > 0 then
        return nil, "YAML parse errors: " .. table.concat(errors, "; ")
    end

    if not theme or theme.temple_theme ~= 1 then
        return nil, "Invalid theme format (missing temple_theme: 1)"
    end

    -- Handle extends
    if theme.extends then
        local baseTheme = ThemeEngine.themes[theme.extends]
        if not baseTheme then
            -- Try to load base
            local base, err = ThemeEngine.loadTheme(theme.extends, themesPath)
            if not base then
                return nil, "Base theme '" .. theme.extends .. "' not found: " .. err
            end
            baseTheme = base
        end
        theme = ThemeEngine.mergeTheme(baseTheme.raw, theme)
    end

    -- Validate required tokens
    local missingTokens = {}
    for _, token in ipairs(REQUIRED_TOKENS) do
        if not theme.tokens[token] then
            table.insert(missingTokens, token)
        end
    end
    if #missingTokens > 0 then
        Log.warn("Theme '" .. name .. "' missing tokens: " .. table.concat(missingTokens, ", "))
    end

    -- Validate palette
    local missingPalette = {}
    for _, p in ipairs(REQUIRED_PALETTE) do
        if not theme.palette[p] then
            table.insert(missingPalette, p)
        end
    end
    if #missingPalette > 0 then
        return nil, "Theme missing palette colors: " .. table.concat(missingPalette, ", ")
    end

    theme.name = name
    return theme
end

-- Load all themes from directory
function ThemeEngine.loadAllThemes(themesPath)
    ThemeEngine.themes = {}
    local ok, files = pcall(Executor.fs_list, themesPath)
    if not ok or not files then
        Log.warn("Could not list themes directory:", themesPath)
        return
    end

    for _, file in ipairs(files) do
        local name = file:match("^(.+)%.yaml$")
        if name then
            local theme, err = ThemeEngine.loadTheme(name, themesPath)
            if theme then
                ThemeEngine.themes[name] = theme
                Log.info("Loaded theme:", name)
            else
                Log.warn("Failed to load theme '" .. name .. "': " .. err)
            end
        end
    end
end

-- Apply theme (resolve tokens to actual values)
function ThemeEngine.applyTheme(name)
    local theme = ThemeEngine.themes[name]
    if not theme then
        return false, "Theme not found: " .. name
    end

    -- Resolve palette
    local resolvedPalette = {}
    for k, v in pairs(theme.palette) do
        resolvedPalette[k] = hexToColor3(v)
    end
    ThemeEngine.palette = resolvedPalette

    -- Resolve tokens
    local resolvedTokens = {}
    for token, ref in pairs(theme.tokens) do
        resolvedTokens[token] = resolvePaletteRef(ref, resolvedPalette)
    end

    -- Apply accent override from config
    local config = Config.data
    if config and config.theme.accent_override then
        local override = config.theme.accent_override
        if override:sub(1,1) == "#" then
            resolvedTokens["text.accent"] = hexToColor3(override)
            resolvedTokens["toggle.track.on"] = hexToColor3(override)
            resolvedTokens["button.primary.bg"] = hexToColor3(override)
            resolvedTokens["tab.active"] = hexToColor3(override)
            resolvedTokens["slider.fill"] = hexToColor3(override)
            resolvedTokens["dock.icon.active"] = hexToColor3(override)
            resolvedTokens["snap.preview"] = hexToColor3(override)
            resolvedTokens["workspace.active.fg"] = hexToColor3(override)
        end
    end

    ThemeEngine.tokens = resolvedTokens
    ThemeEngine.currentTheme = name
    ThemeEngine.currentRawTheme = theme

    Log.info("Applied theme:", name)
    ThemeEngine.notifySubscribers()
    return true
end

-- Get token value (Color3 or other)
function ThemeEngine.getToken(token)
    return ThemeEngine.tokens[token]
end

-- Get raw theme data
function ThemeEngine.getRawTheme(name)
    name = name or ThemeEngine.currentTheme
    return ThemeEngine.themes[name]
end

-- List available themes
function ThemeEngine.listThemes()
    local list = {}
    for name, theme in pairs(ThemeEngine.themes) do
        table.insert(list, {
            name = name,
            displayName = theme.name or name,
            author = theme.author,
            meta = theme.meta,
            extends = theme.extends
        })
    end
    return list
end

-- Subscribe to theme changes
function ThemeEngine.subscribe(callback)
    table.insert(ThemeEngine.subscribers, callback)
    return function()
        for i, cb in ipairs(ThemeEngine.subscribers) do
            if cb == callback then
                table.remove(ThemeEngine.subscribers, i)
                break
            end
        end
    end
end

function ThemeEngine.notifySubscribers()
    for _, cb in ipairs(ThemeEngine.subscribers) do
        pcall(cb, ThemeEngine.tokens, ThemeEngine.currentTheme)
    end
end

-- Hot-swap theme (called from UI)
function ThemeEngine.setTheme(name)
    local ok, err = ThemeEngine.applyTheme(name)
    if ok then
        -- Update config
        Config.set("theme.active", name)
        Config.save()
    else
        Log.error("Failed to apply theme:", err)
        -- Try fallback
        local fallback = Config.get("theme.fallback")
        if fallback and fallback ~= name then
            ThemeEngine.applyTheme(fallback)
        end
    end
    return ok, err
end

-- Start file watcher for themes directory
function ThemeEngine.startWatch(themesPath)
    if ThemeEngine.watchThread then return end
    ThemeEngine.watchThread = task.spawn(function()
        local lastFiles = {}
        while true do
            task.wait(2)
            local ok, files = pcall(Executor.fs_list, themesPath)
            if ok and files then
                local current = {}
                for _, f in ipairs(files) do
                    current[f] = true
                end
                -- Check for new/removed files
                local changed = false
                for f, _ in pairs(current) do
                    if not lastFiles[f] then
                        changed = true
                        local name = f:match("^(.+)%.yaml$")
                        if name and not ThemeEngine.themes[name] then
                            local theme, err = ThemeEngine.loadTheme(name, themesPath)
                            if theme then
                                ThemeEngine.themes[name] = theme
                                Log.info("Hot-loaded new theme:", name)
                            end
                        end
                    end
                end
                for f, _ in pairs(lastFiles) do
                    if not current[f] then
                        changed = true
                        local name = f:match("^(.+)%.yaml$")
                        if name and ThemeEngine.themes[name] then
                            ThemeEngine.themes[name] = nil
                            Log.info("Theme removed:", name)
                        end
                    end
                end
                if changed then
                    lastFiles = current
                    -- Notify UI to refresh theme list
                    ThemeEngine.notifySubscribers()
                end
            end
        end
    end)
end

function ThemeEngine.stopWatch()
    if ThemeEngine.watchThread then
        task.cancel(ThemeEngine.watchThread)
        ThemeEngine.watchThread = nil
    end
end

return ThemeEngine