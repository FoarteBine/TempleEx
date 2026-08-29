--[[
    TempleEx - Main Entry Point (Bootloader + Single-File Build Target)
    Version: 1.0.0
    Load via: loadstring(game:HttpGet("https://raw.githubusercontent.com/FoarteBine/TempleEx/main/TempleEx.lua"))()
]]

-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ
-- BOOTLOADER SECTION (runs first, downloads full build if needed)
-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ

local BOOTLOADER_VERSION = "1.0.0"
local REPO = "FoarteBine/TempleEx"
local BRANCH = "main"
local MIRRORS = {
    "https://raw.githubusercontent.com",
    "https://cdn.jsdelivr.net/gh"
}

-- Check if already loaded (idempotent)
if _G.TempleExLoaded and _G.TempleEx then
    -- Toggle GUI visibility
    if _G.TempleEx.ToggleGUI then
        _G.TempleEx.ToggleGUI()
    end
    return _G.TempleEx
end

-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ
-- EXECUTOR DETECTION (minimal, inline)
-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ

local function detectExecutor()
    local name = "unknown"
    local caps = {}

    -- Resolve the global environment TABLE (getgenv is usually a FUNCTION;
    -- indexing it directly errors in Luau). Normalize to a table once.
    local getgenv = (function()
        local g = getgenv
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
        if ok and n then name = n end
    elseif getgenv and getgenv.Wave then name = "wave"
    elseif getgenv and getgenv.Codex then name = "codex"
    elseif getgenv and getgenv.Hydrogen then name = "hydrogen"
    elseif getgenv and getgenv.Potassium then name = "potassium"
    elseif getgenv and getgenv.Swift then name = "swift"
    elseif getgenv and getgenv.Fluxus then name = "fluxus"
    elseif getgenv and getgenv.Arceus then name = "arceus"
    elseif getgenv and getgenv.Delta then name = "delta"
    elseif getgenv and getgenv.Krnl then name = "krnl"
    elseif getgenv and getgenv.Synapse then name = "synapse"
    end

    caps.request = (request or http_request or (syn and syn.request) or (getgenv and getgenv.request)) ~= nil
    caps.httpget = (game and game.HttpGet) ~= nil
    caps.queue_on_teleport = (queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)) ~= nil
    caps.gethui = (gethui or (getgenv and getgenv.gethui)) ~= nil
    caps.drawing = (Drawing or (getgenv and getgenv.Drawing)) ~= nil
    caps.isfile = (isfile or (getgenv and getgenv.isfile)) ~= nil
    caps.writefile = (writefile or (getgenv and getgenv.writefile)) ~= nil
    caps.readfile = (readfile or (getgenv and getgenv.readfile)) ~= nil
    caps.listfiles = (listfiles or (getgenv and getgenv.listfiles)) ~= nil
    caps.makefolder = (makefolder or (getgenv and getgenv.makefolder)) ~= nil
    caps.delfile = (delfile or (getgenv and getgenv.delfile)) ~= nil

    return {
        name = name:lower(),
        capabilities = caps,
        raw = {
            request = request or http_request or (syn and syn.request) or (getgenv and getgenv.request),
            httpget = game and game.HttpGet,
            queue_on_teleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport),
            gethui = gethui or (getgenv and getgenv.gethui),
            isfile = isfile or (getgenv and getgenv.isfile),
            writefile = writefile or (getgenv and getgenv.writefile),
            readfile = readfile or (getgenv and getgenv.readfile),
            listfiles = listfiles or (getgenv and getgenv.listfiles),
            makefolder = makefolder or (getgenv and getgenv.makefolder),
            delfile = delfile or (getgenv and getgenv.delfile),
        }
    }
end

-- Never let executor detection kill the bootloader; fall back to a minimal
-- profile (httpRequest then uses game:HttpGet, which is always available).
local detectOk, detectInfo = pcall(detectExecutor)
local EXECUTOR_INFO = (detectOk and detectInfo)
    or { name = "unknown", version = "unknown", capabilities = {}, raw_globals = {} }

-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ
-- MINIMAL HTTP + FS (for bootloader only)
-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ

local function httpRequest(url, options)
    options = options or {}
    local method = options.Method or "GET"
    local headers = options.Headers or {}
    local body = options.Body

    local req = EXECUTOR_INFO.raw.request
    if req then
        local ok, res = pcall(req, {Url = url, Method = method, Headers = headers, Body = body, Timeout = options.Timeout or 30})
        if ok and res then return res end
    end

    if method == "GET" and EXECUTOR_INFO.raw.httpget then
        local ok, content = pcall(EXECUTOR_INFO.raw.httpget, game, url)
        if ok then return {StatusCode = 200, Body = content, Success = true} end
    end

    return {StatusCode = 0, Success = false, Error = "No HTTP provider"}
end

local function fsRead(path)
    local fn = EXECUTOR_INFO.raw.readfile
    if fn then return pcall(fn, path) end
    return false, "readfile unavailable"
end

local function fsWrite(path, content)
    local fn = EXECUTOR_INFO.raw.writefile
    if fn then return pcall(fn, path, content) end
    return false, "writefile unavailable"
end

local function fsList(path)
    local fn = EXECUTOR_INFO.raw.listfiles
    if fn then return pcall(fn, path) end
    return false, "listfiles unavailable"
end

local function fsMkdir(path)
    local fn = EXECUTOR_INFO.raw.makefolder
    if fn then return pcall(fn, path) end
    return false, "makefolder unavailable"
end

local function getHUI()
    local fn = EXECUTOR_INFO.raw.gethui
    if fn then return fn() end
    return game:GetService("CoreGui")
end

-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ
-- CACHE MANAGEMENT
-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ

local function getWorkspacePath()
    -- Executor file functions are relative to the workspace folder root.
    -- Verify write access; empty string = root (readfile("temple.yaml") style).
    local testPath = "TempleEx_test_write.tmp"
    if pcall(fsWrite, testPath, "test") then
        pcall(fsWrite, testPath, "") -- cleanup
        return ""
    end
    return ""
end

local WORKSPACE_PATH = getWorkspacePath()
local function wsJoin(sub)
    if WORKSPACE_PATH == "" then return sub end
    return WORKSPACE_PATH .. "/" .. sub
end
local CACHE_PATH = wsJoin("TempleEx.lua")
local VERSION_CACHE_PATH = wsJoin("cache/TempleEx.version")
local PREV_BUILD_PATH = wsJoin("cache/TempleEx.prev.lua")

local function readVersionCache()
    local ok, content = fsRead(VERSION_CACHE_PATH)
    if ok and content then return content:match("([%d%.]+)") end
    return nil
end

local function writeVersionCache(version)
    pcall(fsMkdir, wsJoin("cache"))
    pcall(fsWrite, VERSION_CACHE_PATH, version)
end

-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ
-- DOWNLOAD FULL BUILD
-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ

local function downloadFullBuild()
    print("[TempleEx] Downloading full build...")

    for _, mirror in ipairs(MIRRORS) do
        local url
        if mirror:find("jsdelivr") then
            url = mirror .. "/" .. REPO .. "@" .. BRANCH .. "/TempleEx-full.lua"
        else
            url = mirror .. "/" .. REPO .. "/" .. BRANCH .. "/TempleEx-full.lua"
        end

        local res = httpRequest(url)
        if res.Success and res.Body and #res.Body > 1000 then
            print("[TempleEx] Downloaded from:", url)
            return res.Body
        else
            warn("[TempleEx] Mirror failed:", url, res.Error or "empty")
        end
    end

    -- Try release asset
    local apiRes = httpRequest("https://api.github.com/repos/" .. REPO .. "/releases/latest", {
        Headers = {Accept = "application/vnd.github.v3+json"}
    })
    if apiRes.Success then
        local data = game:GetService("HttpService"):JSONDecode(apiRes.Body)
        if data.assets then
            for _, asset in ipairs(data.assets) do
                if asset.name == "TempleEx-full.lua" then
                    local assetRes = httpRequest(asset.browser_download_url)
                    if assetRes.Success then
                        print("[TempleEx] Downloaded from release asset")
                        return assetRes.Body
                    end
                end
            end
        end
    end

    return nil
end

-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ
-- MAIN BOOTSTRAP
-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ

local function bootstrap()
    -- Download-first: a loadstring should always fetch the latest build.
    -- The cache is only an OFFLINE fallback (we don't publish GitHub releases,
    -- so a release-based update check would pin the user to a stale build forever).
    local fresh = downloadFullBuild()
    if fresh then
        pcall(fsWrite, CACHE_PATH, fresh)
        writeVersionCache("1.0.0")
        print("[TempleEx] Using latest build (cached for offline)")
        return fresh
    end

    -- Offline / all mirrors failed: fall back to cache
    local ok, cached = fsRead(CACHE_PATH)
    if ok and cached and #cached > 1000 then
        warn("[TempleEx] Offline - using cached build")
        return cached
    end

    error("[TempleEx] Failed to download build and no cache available. Check internet connection.")
end

-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ
-- EXECUTE FULL BUILD
-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ

local fullBuild = bootstrap()
if not fullBuild then
    error("[TempleEx] No build content available")
end

-- Strip UTF-8 BOM if present (Luau loadstring rejects U+FEFF at position 1)
if fullBuild:sub(1, 3) == "\239\187\191" then
    fullBuild = fullBuild:sub(4)
end

-- Execute the full build (which defines all modules and returns TempleApi)
local buildFunc, err = loadstring(fullBuild, "TempleEx-full")
if not buildFunc then
    error("[TempleEx] Failed to compile build: " .. tostring(err))
end

local ok, TempleEx = pcall(buildFunc)
if not ok then
    error("[TempleEx] Build execution failed: " .. tostring(TempleEx))
end

-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ
-- GLOBAL EXPORTS
-- в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђ

_G.TempleExLoaded = true
_G.TempleEx = TempleEx
-- The full build already set _G.TempleApi / _G.Temple to the real API;
-- re-point explicitly to TempleEx.Api so scripts can call TempleApi.Window(...) etc.
_G.TempleApi = TempleEx.Api or _G.TempleApi
_G.Temple = TempleEx.Api or _G.Temple

-- Provide toggle function
_G.TempleEx.ToggleGUI = function()
    if TempleEx.Shell and TempleEx.Shell.screenGui then
        TempleEx.Shell.screenGui.Enabled = not TempleEx.Shell.screenGui.Enabled
    end
end

print("[TempleEx] Loaded successfully v" .. (TempleEx.version and table.concat({TempleEx.version.major, TempleEx.version.minor, TempleEx.version.patch}, ".") or "1.0.0"))
print("[TempleEx] Executor:", EXECUTOR_INFO.name)
print("[TempleEx] Press RightCtrl to toggle GUI")

return TempleEx





