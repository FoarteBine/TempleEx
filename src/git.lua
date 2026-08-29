--[[
    TempleEx Git Layer
    Handles self-update, hub registries, theme/script pulling from git
]]

local Git = {}
Git.__index = Git

local Executor = require(script.Parent.executor)
local Config = require(script.Parent.config)
local ThemeEngine = require(script.Parent.theme)
local Log = require(script.Parent.log)
local Autoload = require(script.Parent.autoload)

local HttpService = game:GetService("HttpService")

Git.currentVersion = "1.0.0"
Git.cachedVersion = nil
Git.updateAvailable = false

-- ============================================================
-- GITHUB API HELPERS
-- ============================================================
local function githubApiRequest(endpoint)
    local mirrors = Config.get("git.mirrors") or {"https://raw.githubusercontent.com"}
    local baseUrl = mirrors[1] .. "/FoarteBine/TempleEx/main" -- default to raw

    -- Try GitHub API for releases
    local apiUrl = "https://api.github.com/repos/FoarteBine/TempleEx" .. endpoint
    local res = Executor.http(apiUrl, {
        Headers = {
            ["Accept"] = "application/vnd.github.v3+json",
            ["User-Agent"] = "TempleEx/1.0"
        }
    })

    if res.Success and res.StatusCode == 200 then
        return HttpService:JSONDecode(res.Body)
    end

    -- Fallback to raw version file
    local versionUrl = baseUrl .. "/VERSION"
    local vres = Executor.http(versionUrl)
    if vres.Success then
        return {tag_name = "v" .. vres.Body:match("([%d%.]+)")}
    end

    return nil, "GitHub API unavailable"
end

local function downloadFromMirrors(path)
    local mirrors = Config.get("git.mirrors") or {"https://raw.githubusercontent.com"}
    local repo = Config.get("git.repo") or "FoarteBine/TempleEx"
    local channel = Config.get("git.channel") or "stable"
    local branch = channel == "canary" and "dev" or "main"

    for _, mirror in ipairs(mirrors) do
        local url
        if mirror:find("jsdelivr") then
            url = mirror .. "/" .. repo .. "@" .. branch .. "/" .. path
        else
            url = mirror .. "/" .. repo .. "/" .. branch .. "/" .. path
        end

        local res = Executor.http(url)
        if res.Success and res.StatusCode == 200 then
            return res.Body, url
        end
    end
    return nil, "All mirrors failed"
end

-- ============================================================
-- CHECK FOR UPDATES
-- ============================================================
function Git.checkForUpdates()
    local channel = Config.get("git.channel") or "stable"
    local repo = Config.get("git.repo") or "FoarteBine/TempleEx"

    Log.info("Checking for updates on channel:", channel)

    if channel == "canary" then
        -- Canary: check latest commit on dev branch
        local res = Executor.http("https://api.github.com/repos/" .. repo .. "/commits/dev", {
            Headers = {["Accept"] = "application/vnd.github.v3+json"}
        })
        if res.Success then
            local data = HttpService:JSONDecode(res.Body)
            Git.cachedVersion = data.sha:sub(1, 7)
            Git.updateAvailable = Git.cachedVersion ~= Git.currentVersion
        end
    else
        -- Stable: check latest release
        local release = githubApiRequest("/releases/latest")
        if release and release.tag_name then
            Git.cachedVersion = release.tag_name:gsub("^v", "")
            Git.updateAvailable = Git.cachedVersion ~= Git.currentVersion

            -- Cache release assets URLs
            if release.assets then
                for _, asset in ipairs(release.assets) do
                    if asset.name == "TempleEx-full.lua" then
                        Git.latestFullBuildUrl = asset.browser_download_url
                        break
                    end
                end
            end
        end
    end

    Log.info("Update check:", Git.updateAvailable and "UPDATE AVAILABLE" or "Up to date", "(" .. (Git.cachedVersion or "unknown") .. ")")
    return Git.updateAvailable
end

-- ============================================================
-- DOWNLOAD LATEST BUILD
-- ============================================================
function Git.downloadLatestBuild()
    if not Git.updateAvailable then
        return false, "No update available"
    end

    Log.info("Downloading latest build...")

    -- Try to download full build from release assets
    if Git.latestFullBuildUrl then
        local res = Executor.http(Git.latestFullBuildUrl)
        if res.Success then
            return res.Body
        end
    end

    -- Fallback: download from raw mirrors
    local content, url = downloadFromMirrors("TempleEx-full.lua")
    if content then
        Log.info("Downloaded from:", url)
        return content
    end

    return nil, "Failed to download from all mirrors"
end

-- ============================================================
-- APPLY UPDATE
-- ============================================================
function Git.applyUpdate(buildContent)
    if not buildContent then return false, "No build content" end

    local workspacePath = Config.get("paths.workspace") or "."

    -- Backup current
    local ok, current = Executor.fs_read(workspacePath .. "/TempleEx.lua")
    if ok and current then
        pcall(Executor.fs_write, workspacePath .. "/cache/TempleEx.prev.lua", current)
    end

    -- Write new build
    local ok, err = Executor.fs_write(workspacePath .. "/TempleEx.lua", buildContent)
    if not ok then
        return false, "Failed to write update: " .. err
    end

    -- Update version cache
    Git.currentVersion = Git.cachedVersion
    Git.updateAvailable = false

    Log.info("Update applied successfully. Restart required.")
    return true
end

-- ============================================================
-- ROLLBACK
-- ============================================================
function Git.rollback()
    local workspacePath = Config.get("paths.workspace") or "."
    local ok, backup = Executor.fs_read(workspacePath .. "/cache/TempleEx.prev.lua")
    if ok and backup then
        pcall(Executor.fs_write, workspacePath .. "/TempleEx.lua", backup)
        Log.info("Rolled back to previous version")
        return true
    end
    return false, "No backup available"
end

-- ============================================================
-- PIN VERSION
-- ============================================================
function Git.pinVersion(versionTag)
    local url = "https://github.com/FoarteBine/TempleEx/releases/download/" .. versionTag .. "/TempleEx-full.lua"
    local res = Executor.http(url)
    if res.Success then
        return Git.applyUpdate(res.Body)
    end

    -- Try mirrors
    local mirrors = Config.get("git.mirrors") or {}
    for _, mirror in ipairs(mirrors) do
        local murl = mirror .. "/FoarteBine/TempleEx/" .. versionTag .. "/TempleEx-full.lua"
        local mres = Executor.http(murl)
        if mres.Success then
            return Git.applyUpdate(mres.Body)
        end
    end

    return false, "Version not found on mirrors"
end

-- ============================================================
-- HUB REGISTRY
-- ============================================================
function Git.fetchRegistry(registryName)
    local registries = Config.get("git.registries") or {}
    local registryRepo = registries[registryName]
    if not registryRepo then
        return nil, "Registry not configured: " .. registryName
    end

    local mirrors = Config.get("git.mirrors") or {"https://raw.githubusercontent.com"}
    local path = "index.yaml"

    for _, mirror in ipairs(mirrors) do
        local url
        if mirror:find("jsdelivr") then
            url = mirror .. "/" .. registryRepo .. "@main/" .. path
        else
            url = mirror .. "/" .. registryRepo .. "/main/" .. path
        end

        local res = Executor.http(url)
        if res.Success then
            local YAML = require(script.Parent.yaml)
            local data, errors = YAML.parse(res.Body)
            if data then
                return data
            end
        end
    end
    return nil, "Failed to fetch registry from all mirrors"
end

function Git.pullFromRegistry(registryName, itemName)
    local registry, err = Git.fetchRegistry(registryName)
    if not registry then return false, err end

    local item
    for _, entry in ipairs(registry) do
        if entry.name == itemName then
            item = entry
            break
        end
    end

    if not item then return false, "Item not found in registry" end

    -- Download the file
    local fileUrl
    if item.file:match("^https?://") then
        fileUrl = item.file
    else
        -- Relative to registry repo
        local mirrors = Config.get("git.mirrors") or {"https://raw.githubusercontent.com"}
        local registryRepo = Config.get("git.registries")[registryName]
        for _, mirror in ipairs(mirrors) do
            local url = mirror .. "/" .. registryRepo .. "/main/" .. item.file
            local res = Executor.http(url)
            if res.Success then
                fileUrl = url
                break
            end
        end
    end

    if not fileUrl then return false, "Could not resolve file URL" end

    local res = Executor.http(fileUrl)
    if not res.Success then return false, "Download failed" end

    -- Verify sha256 if provided
    if item.sha256 then
        -- TODO: implement sha256 verification
    end

    -- Save to plugins/
    local pluginsPath = Config.get("paths.plugins") or "plugins"
    local fileName = item.file:match("([^/]+)$") or item.name .. ".lua"
    local destPath = pluginsPath .. "/" .. fileName

    pcall(Executor.fs_write, destPath, res.Body)

    -- Add to plugins list
    local plugins = Config.get("plugins") or {}
    local exists = false
    for _, p in ipairs(plugins) do
        if p.file == destPath then exists = true break end
    end
    if not exists then
        table.insert(plugins, {
            name = item.name,
            file = destPath,
            autoload = false
        })
        Config.set("plugins", plugins)
        Config.save()
    end

    Log.info("Pulled", itemName, "from", registryName, "to", destPath)
    return true
end

-- ============================================================
-- THEME PULL
-- ============================================================
function Git.pullTheme(repoOrUrl)
    -- If it's a full URL
    if repoOrUrl:match("^https?://") then
        local res = Executor.http(repoOrUrl)
        if res.Success then
            local name = repoOrUrl:match("([^/]+)%.yaml$") or "imported-theme"
            local themesPath = Config.get("paths.themes") or "themes"
            pcall(Executor.fs_write, themesPath .. "/" .. name .. ".yaml", res.Body)
            ThemeEngine.loadAllThemes(themesPath)
            return true, name
        end
        return false, "Download failed"
    end

    -- Assume user/repo format, fetch from themes registry
    return Git.pullFromRegistry("themes", repoOrUrl)
end

-- ============================================================
-- AUTO UPDATE LOOP
-- ============================================================
function Git.startAutoUpdateLoop()
    if not Config.get("git.auto_update") then return end

    task.spawn(function()
        while true do
            task.wait(3600) -- check every hour
            local ok = pcall(Git.checkForUpdates)
            if ok and Git.updateAvailable then
                Log.info("Auto-update available, downloading...")
                local content = Git.downloadLatestBuild()
                if content then
                    Git.applyUpdate(content)
                    TempleApi.Notify({
                        title = "TempleEx Updated",
                        content = "New version applied. Restart to use it.",
                        duration = 10,
                        level = "success"
                    })
                end
            end
        end
    end)
end

return Git