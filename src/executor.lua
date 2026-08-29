--[[
    TempleEx Executor Detection & Facade
    Provides unified API across Wave, Codex, Hydrogen, Potassium, Swift, etc.
]]

local Executor = {}

-- Detect current executor
function Executor.detect()
    local name = "unknown"
    local version = "unknown"
    local caps = {}

    -- Resolve the global environment TABLE. In most executors `getgenv` is a
    -- FUNCTION (getgenv() -> env table); indexing a function errors in Luau
    -- ("attempt to index function with 'hookmetamethod'"). Normalize to a table.
    local getgenv = (function()
        local g = getgenv  -- the global: function, table, or nil
        if type(g) == "function" then
            local ok, r = pcall(g)
            if ok and type(r) == "table" then return r end
        elseif type(g) == "table" then
            return g
        end
        return _G
    end)()
    local identifyexecutor = identifyexecutor or (getgenv and getgenv.identifyexecutor)

    if identifyexecutor then
        local ok, n, v = pcall(identifyexecutor)
        if ok and n then
            name = n
            version = v or "unknown"
        end
    elseif getgenv and getgenv.Wave then
        name = "wave"
    elseif getgenv and getgenv.Codex then
        name = "codex"
    elseif getgenv and getgenv.Hydrogen then
        name = "hydrogen"
    elseif getgenv and getgenv.Potassium then
        name = "potassium"
    elseif getgenv and getgenv.Swift then
        name = "swift"
    elseif getgenv and getgenv.Electron then
        name = "electron"
    elseif getgenv and getgenv.Fluxus then
        name = "fluxus"
    elseif getgenv and getgenv.Arceus then
        name = "arceus"
    elseif getgenv and getgenv.Delta then
        name = "delta"
    elseif getgenv and getgenv.Krnl then
        name = "krnl"
    elseif getgenv and getgenv.Synapse then
        name = "synapse"
    elseif getgenv and getgenv.ScriptWare then
        name = "scriptware"
    end

    -- Capability detection
    caps.request = (request or http_request or (syn and syn.request) or (getgenv and getgenv.request)) ~= nil
    caps.httpget = (game and game.HttpGet) ~= nil
    caps.queue_on_teleport = (queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)) ~= nil
    caps.gethui = (gethui or (getgenv and getgenv.gethui)) ~= nil
    caps.setreadonly = (setreadonly or make_writeable) ~= nil
    caps.hookmetamethod = (hookmetamethod or (getgenv and getgenv.hookmetamethod)) ~= nil
    caps.hookfunction = (hookfunction or replaceclosure) ~= nil
    caps.newcclosure = (newcclosure or (getgenv and getgenv.newcclosure)) ~= nil
    caps.getgc = (getgc or (getgenv and getgenv.getgc)) ~= nil
    caps.getinstances = (getinstances or (getgenv and getgenv.getinstances)) ~= nil
    caps.decompile = (decompile or (getgenv and getgenv.decompile)) ~= nil
    caps.drawing = (Drawing or (getgenv and getgenv.Drawing)) ~= nil
    caps.rconsole = (rconsoleprint or (getgenv and getgenv.rconsoleprint)) ~= nil
    caps.setclipboard = (setclipboard or toclipboard) ~= nil
    caps.isfile = (isfile or (getgenv and getgenv.isfile)) ~= nil
    caps.writefile = (writefile or (getgenv and getgenv.writefile)) ~= nil
    caps.readfile = (readfile or (getgenv and getgenv.readfile)) ~= nil
    caps.listfiles = (listfiles or (getgenv and getgenv.listfiles)) ~= nil
    caps.makefolder = (makefolder or (getgenv and getgenv.makefolder)) ~= nil
    caps.delfile = (delfile or (getgenv and getgenv.delfile)) ~= nil
    caps.loadfile = (loadfile or (getgenv and getgenv.loadfile)) ~= nil
    caps.dofile = (dofile or (getgenv and getgenv.dofile)) ~= nil
    caps.getclipboard = (getclipboard or (getgenv and getgenv.getclipboard)) ~= nil
    caps.fireclickdetector = (fireclickdetector or (getgenv and getgenv.fireclickdetector)) ~= nil
    caps.firetouchinterest = (firetouchinterest or (getgenv and getgenv.firetouchinterest)) ~= nil
    caps.fireproximityprompt = (fireproximityprompt or (getgenv and getgenv.fireproximityprompt)) ~= nil
    caps.keypress = (keypress or (getgenv and getgenv.keypress)) ~= nil
    caps.keyrelease = (keyrelease or (getgenv and getgenv.keyrelease)) ~= nil
    caps.mouse1click = (mouse1click or (getgenv and getgenv.mouse1click)) ~= nil
    caps.mouse2click = (mouse2click or (getgenv and getgenv.mouse2click)) ~= nil

    return {
        name = name:lower(),
        version = version,
        capabilities = caps,
        raw_globals = {
            request = request or http_request or (syn and syn.request) or (getgenv and getgenv.request),
            httpget = game and game.HttpGet,
            queue_on_teleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport),
            gethui = gethui or (getgenv and getgenv.gethui),
            setreadonly = setreadonly or make_writeable,
            hookmetamethod = hookmetamethod or (getgenv and getgenv.hookmetamethod),
            hookfunction = hookfunction or replaceclosure,
            newcclosure = newcclosure or (getgenv and getgenv.newcclosure),
            getgc = getgc or (getgenv and getgenv.getgc),
            getinstances = getinstances or (getgenv and getgenv.getinstances),
            decompile = decompile or (getgenv and getgenv.decompile),
            Drawing = Drawing or (getgenv and getgenv.Drawing),
            rconsoleprint = rconsoleprint or (getgenv and getgenv.rconsoleprint),
            setclipboard = setclipboard or toclipboard,
            isfile = isfile or (getgenv and getgenv.isfile),
            writefile = writefile or (getgenv and getgenv.writefile),
            readfile = readfile or (getgenv and getgenv.readfile),
            listfiles = listfiles or (getgenv and getgenv.listfiles),
            makefolder = makefolder or (getgenv and getgenv.makefolder),
            delfile = delfile or (getgenv and getgenv.delfile),
            loadfile = loadfile or (getgenv and getgenv.loadfile),
            dofile = dofile or (getgenv and getgenv.dofile),
            getclipboard = getclipboard or (getgenv and getgenv.getclipboard),
            fireclickdetector = fireclickdetector or (getgenv and getgenv.fireclickdetector),
            firetouchinterest = firetouchinterest or (getgenv and getgenv.firetouchinterest),
            fireproximityprompt = fireproximityprompt or (getgenv and getgenv.fireproximityprompt),
            keypress = keypress or (getgenv and getgenv.keypress),
            keyrelease = keyrelease or (getgenv and getgenv.keyrelease),
            mouse1click = mouse1click or (getgenv and getgenv.mouse1click),
            mouse2click = mouse2click or (getgenv and getgenv.mouse2click),
        }
    }
end

-- Detect at load, but never let a weird executor's globals kill initialization.
local detectOk, detectInfo = pcall(Executor.detect)
Executor.info = (detectOk and detectInfo)
    or { name = "unknown", version = "unknown", capabilities = {}, raw_globals = {} }

-- HTTP Request with fallback chain
function Executor.http(url, options)
    options = options or {}
    local method = options.Method or "GET"
    local headers = options.Headers or {}
    local body = options.Body
    local timeout = options.Timeout or 30

    local req = Executor.info.raw_globals.request
    if req then
        local ok, res = pcall(req, {
            Url = url,
            Method = method,
            Headers = headers,
            Body = body,
            Timeout = timeout
        })
        if ok and res then
            return res
        end
    end

    -- Fallback: game:HttpGet (GET only)
    if method == "GET" and Executor.info.raw_globals.httpget then
        local ok, content = pcall(Executor.info.raw_globals.httpget, game, url)
        if ok then
            return {
                StatusCode = 200,
                Body = content,
                Headers = {},
                Success = true
            }
        end
    end

    return {
        StatusCode = 0,
        Body = "",
        Headers = {},
        Success = false,
        Error = "No HTTP provider available"
    }
end

-- Queue on teleport
function Executor.queue_on_teleport(code)
    local fn = Executor.info.raw_globals.queue_on_teleport
    if fn then
        return pcall(fn, code)
    end
    return false, "queue_on_teleport not available"
end

-- Get HUI (hidden UI container)
function Executor.gethui()
    local fn = Executor.info.raw_globals.gethui
    if fn then
        return fn()
    end
    -- Fallback: CoreGui
    return game:GetService("CoreGui")
end

-- Filesystem operations (sandboxed to workspace)
function Executor.fs_read(path)
    local fn = Executor.info.raw_globals.readfile
    if fn then
        return pcall(fn, path)
    end
    return false, "readfile not available"
end

function Executor.fs_write(path, content)
    local fn = Executor.info.raw_globals.writefile
    if fn then
        return pcall(fn, path, content)
    end
    return false, "writefile not available"
end

function Executor.fs_append(path, content)
    local fn = Executor.info.raw_globals.appendfile
    if fn then
        return pcall(fn, path, content)
    end
    -- Fallback: read + write
    local ok, content_old = Executor.fs_read(path)
    if ok then
        return Executor.fs_write(path, content_old .. content)
    end
    return Executor.fs_write(path, content)
end

function Executor.fs_list(path)
    local fn = Executor.info.raw_globals.listfiles
    if fn then
        return pcall(fn, path)
    end
    return false, "listfiles not available"
end

function Executor.fs_mkdir(path)
    local fn = Executor.info.raw_globals.makefolder
    if fn then
        return pcall(fn, path)
    end
    return false, "makefolder not available"
end

function Executor.fs_exists(path)
    local fn = Executor.info.raw_globals.isfile
    if fn then
        return pcall(fn, path)
    end
    return false, false
end

function Executor.fs_is_folder(path)
    local fn = Executor.info.raw_globals.isfolder
    if fn then
        return pcall(fn, path)
    end
    return false, false
end

function Executor.fs_delete(path)
    local fn = Executor.info.raw_globals.delfile
    if fn then
        return pcall(fn, path)
    end
    return false, "delfile not available"
end

function Executor.fs_delete_folder(path)
    local fn = Executor.info.raw_globals.delfolder
    if fn then
        return pcall(fn, path)
    end
    return false, "delfolder not available"
end

-- Clipboard
function Executor.set_clipboard(text)
    local fn = Executor.info.raw_globals.setclipboard
    if fn then
        return pcall(fn, text)
    end
    return false, "setclipboard not available"
end

function Executor.get_clipboard()
    local fn = Executor.info.raw_globals.getclipboard
    if fn then
        return pcall(fn)
    end
    return false, "getclipboard not available"
end

-- Console
function Executor.console_print(...)
    local fn = Executor.info.raw_globals.rconsoleprint
    if fn then
        return pcall(fn, ...)
    end
    print(...)
    return true
end

function Executor.console_clear()
    local fn = Executor.info.raw_globals.rconsoleclear
    if fn then
        return pcall(fn)
    end
    return false, "rconsoleclear not available"
end

-- Drawing API check
function Executor.has_drawing()
    return Executor.info.capabilities.drawing == true
end

-- Input emulation
function Executor.key_press(code)
    local fn = Executor.info.raw_globals.keypress
    if fn then
        return pcall(fn, code)
    end
    return false, "keypress not available"
end

function Executor.key_release(code)
    local fn = Executor.info.raw_globals.keyrelease
    if fn then
        return pcall(fn, code)
    end
    return false, "keyrelease not available"
end

function Executor.mouse1_click()
    local fn = Executor.info.raw_globals.mouse1click
    if fn then
        return pcall(fn)
    end
    return false, "mouse1click not available"
end

function Executor.mouse2_click()
    local fn = Executor.info.raw_globals.mouse2click
    if fn then
        return pcall(fn)
    end
    return false, "mouse2click not available"
end

-- Check if executor supports a capability
function Executor.supports(cap)
    return Executor.info.capabilities[cap] == true
end

return Executor