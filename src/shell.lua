--[[
    TempleEx Shell - WM, MenuBar, Dock
    The desktop environment inside Roblox
]]

local Shell = {}
Shell.__index = Shell

local Executor = require(script.Parent.executor)
local ThemeEngine = require(script.Parent.theme)
local Core = require(script.Parent.core)
local Config = require(script.Parent.config)
local Log = require(script.Parent.log)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- State
Shell.windows = {}              -- windowId -> window object
Shell.focusedWindow = nil
Shell.workspaces = {}           -- workspaceId -> {windows}
Shell.currentWorkspace = 1
Shell.minimizedWindows = {}     -- windowId -> true
Shell.dockPins = {}             -- id -> pin definition
Shell.menuItems = {}            -- menu bar dropdown items
Shell.statusChips = {}          -- status bar chips
Shell.snapZones = {}            -- visual snap preview zones
Shell.dockVisible = false
Shell.dockAnimating = false
Shell.menuBarVisible = true
Shell.switcherVisible = false
Shell.switcherIndex = 1

-- GUI References
Shell.screenGui = nil
Shell.menuBar = nil
Shell.dock = nil
Shell.workspaceIndicator = nil
Shell.snapPreview = nil
Shell.switcherGui = nil

-- Theme tokens cache
local tokens = {}

-- Convert a "#rrggbb"/"rrggbb" string to Color3; pass through Color3/nil.
local function toColor3(v, fallback)
    if typeof(v) == "Color3" then return v end
    if type(v) == "string" then
        local hex = v:gsub("#", "")
        if #hex == 3 then hex = hex:gsub("(.)", "%1%1") end
        if #hex == 6 then
            local r = tonumber(hex:sub(1, 2), 16)
            local g = tonumber(hex:sub(3, 4), 16)
            local b = tonumber(hex:sub(5, 6), 16)
            if r and g and b then return Color3.new(r / 255, g / 255, b / 255) end
        end
    end
    return fallback
end

local function updateTokens()
    local raw = ThemeEngine.currentRawTheme
    local geo = raw and raw.geometry or {}
    local rad = geo.radius or {}
    local pad = geo.padding or {}
    local fx = raw and raw.effects or {}
    local shadow = geo.shadow or {}
    tokens = {
        bg = ThemeEngine.getToken("window.bg"),
        border = ThemeEngine.getToken("window.border"),
        titleFg = ThemeEngine.getToken("window.title.fg"),
        sidebarBg = ThemeEngine.getToken("sidebar.bg"),
        tabActive = ThemeEngine.getToken("tab.active"),
        textPrimary = ThemeEngine.getToken("text.primary"),
        textMuted = ThemeEngine.getToken("text.muted"),
        accent = ThemeEngine.getToken("toggle.track.on"),
        warning = ThemeEngine.getToken("notification.level.warn"),
        danger = ThemeEngine.getToken("button.danger.bg"),
        menubarBg = ThemeEngine.getToken("menubar.bg"),
        menubarFg = ThemeEngine.getToken("menubar.fg"),
        dockBg = ThemeEngine.getToken("dock.bg"),
        dockIcon = ThemeEngine.getToken("dock.icon"),
        dockIconActive = ThemeEngine.getToken("dock.icon.active"),
        dockIndicator = ThemeEngine.getToken("dock.indicator"),
        snapPreview = ThemeEngine.getToken("snap.preview"),
        switcherBg = ThemeEngine.getToken("switcher.bg"),
        workspaceActive = ThemeEngine.getToken("workspace.active.fg"),
        elementBg = ThemeEngine.getToken("element.bg"),
        elementBorder = ThemeEngine.getToken("element.border"),
        elementFocus = ThemeEngine.getToken("element.focus"),
        radius = rad.window or 12,
        padding = pad.window or 14,
        shadow = {
            blur = shadow.blur or 12,
            transparency = shadow.transparency or 0.5,
            color = toColor3(shadow.color, Color3.new(0, 0, 0)),
        },
        animSpeed = fx.animation_speed or 1.0,
        animations = fx.animations == nil and true or fx.animations,
    }
end

-- Subscribe to theme changes
ThemeEngine.subscribe(updateTokens)
updateTokens()

-- ============================================================
-- UTILITIES
-- ============================================================
local function createInstance(className, props, children)
    local inst = Instance.new(className)
    for k, v in pairs(props) do
        inst[k] = v
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    return inst
end

local function tween(obj, props, duration, easingStyle, easingDirection)
    if not tokens.animations then
        for k, v in pairs(props) do obj[k] = v end
        return
    end
    local tweenInfo = TweenInfo.new((duration or 0.2) / tokens.animSpeed, easingStyle or Enum.EasingStyle.Quad, easingDirection or Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, tweenInfo, props)
    t:Play()
    return t
end

local function roundCorners(obj, radius)
    local corner = (obj and obj:FindFirstChild("UICorner")) or Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or tokens.radius)
    if obj then corner.Parent = obj end
    return corner
end

local function addStroke(obj, color, thickness)
    local stroke = (obj and obj:FindFirstChild("UIStroke")) or Instance.new("UIStroke")
    stroke.Color = color or tokens.border
    stroke.Thickness = thickness or 1
    stroke.Transparency = 0.5
    if obj then stroke.Parent = obj end
    return stroke
end

local function addShadow(obj)
    if not tokens.shadow then return end
    local shadow = (obj and obj:FindFirstChild("UIShadow")) or Instance.new("ImageLabel")
    shadow.Name = "UIShadow"
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://1316045217" -- soft shadow
    shadow.ImageColor3 = tokens.shadow.color
    shadow.ImageTransparency = tokens.shadow.transparency
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10, 10, 118, 118)
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    if obj then
        shadow.ZIndex = obj.ZIndex - 1
        shadow.Parent = obj
    end
    return shadow
end

-- ============================================================
-- SCREEN GUI SETUP
-- ============================================================
function Shell.init()
    if Shell.screenGui then return Shell.screenGui end
    local config = Config.data
    local shellConfig = config and config.shell or {}

    -- Main ScreenGui
    local guiName = "TempleEx_Shell"
    if config and config.behavior and config.behavior.stealth and config.behavior.stealth.gui_name_prefix then
        guiName = config.behavior.stealth.gui_name_prefix .. "_Shell"
    end

    Shell.screenGui = createInstance("ScreenGui", {
        Name = guiName,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
        IgnoreGuiInset = true
    })

    -- Parent to CoreGui (or gethui if available)
    local parent = Executor.gethui()
    Shell.screenGui.Parent = parent

    -- Initialize subsystems
    Shell.initMenuBar(shellConfig.menubar)
    Shell.initDock(shellConfig.dock)
    Shell.initWM(shellConfig.wm)
    Shell.initSnapZones()
    Shell.initSwitcher()

    -- Input handling for global keys
    Shell.bindGlobalKeys(shellConfig.wm)

    -- Character respawn handling
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        Shell.restoreWindowPositions()
    end)

    Log.info("Temple.Shell initialized")
    return Shell.screenGui
end

-- ============================================================
-- WINDOW MANAGER (WM)
-- ============================================================
function Shell.initWM(wmConfig)
    wmConfig = wmConfig or {}
    Shell.wmConfig = {
        snap = wmConfig.snap ~= false,
        tiling = wmConfig.tiling or "off",
        workspaces = math.clamp(wmConfig.workspaces or 3, 0, 8),
        switcherKey = wmConfig.switcher_key or "Alt+Tab",
        remember = wmConfig.remember ~= false
    }

    -- Create workspaces
    for i = 1, Shell.wmConfig.workspaces do
        Shell.workspaces[i] = {}
    end

    -- Load saved window positions
    if Shell.wmConfig.remember then
        Shell.restoreWindowPositions()
    end
end

-- Register a window with WM
function Shell.registerWindow(window)
    local id = window.id or #Shell.windows + 1
    window.id = id
    window.workspace = window.workspace or Shell.currentWorkspace

    -- Ensure window has WM methods
    window.minimize = function() Shell.minimizeWindow(id) end
    window.maximize = function() Shell.maximizeWindow(id) end
    window.restore = function() Shell.restoreWindow(id) end
    window.focus = function() Shell.focusWindow(id) end
    window.close = function() Shell.closeWindow(id) end
    window.snap = function(dir) Shell.snapWindow(id, dir) end
    window.setWorkspace = function(ws) Shell.setWindowWorkspace(id, ws) end

    Shell.windows[id] = window

    -- Add to current workspace
    table.insert(Shell.workspaces[Shell.currentWorkspace], id)

    -- Focus it
    Shell.focusWindow(id)

    -- Create dock entry for this window
    Shell.addDockWindow(id, window.title or "Window", window.icon)

    return id
end

function Shell.unregisterWindow(id)
    local window = Shell.windows[id]
    if not window then return end

    -- Remove from workspace
    local ws = window.workspace or Shell.currentWorkspace
    local wsList = Shell.workspaces[ws]
    for i, wid in ipairs(wsList) do
        if wid == id then table.remove(wsList, i) break end
    end

    -- Remove from minimized
    Shell.minimizedWindows[id] = nil

    -- Remove dock entry
    Shell.removeDockWindow(id)

    -- Cleanup focus
    if Shell.focusedWindow == id then
        Shell.focusedWindow = nil
        -- Focus next window in workspace
        for _, wid in ipairs(Shell.workspaces[Shell.currentWorkspace]) do
            if Shell.windows[wid] then
                Shell.focusWindow(wid)
                break
            end
        end
    end

    Shell.windows[id] = nil
end

function Shell.focusWindow(id)
    local window = Shell.windows[id]
    if not window then return end

    if Shell.focusedWindow and Shell.focusedWindow ~= id then
        local prev = Shell.windows[Shell.focusedWindow]
        if prev and prev.onFocusLost then prev.onFocusLost() end
    end

    Shell.focusedWindow = id
    window.gui.ZIndex = 200 -- bring to front

    if window.onFocus then window.onFocus() end
    Shell.updateDockIndicators()
end

function Shell.minimizeWindow(id)
    local window = Shell.windows[id]
    if not window then return end

    Shell.minimizedWindows[id] = true
    window.gui.Visible = false
    Shell.updateDockIndicators()

    if Shell.focusedWindow == id then
        Shell.focusedWindow = nil
    end
end

function Shell.maximizeWindow(id)
    local window = Shell.windows[id]
    if not window then return end

    window.maximized = true
    window.gui.Size = UDim2.new(1, 0, 1, -Shell.getMenuBarHeight())
    window.gui.Position = UDim2.new(0, 0, 0, Shell.getMenuBarHeight())
    Shell.updateDockIndicators()
end

function Shell.restoreWindow(id)
    local window = Shell.windows[id]
    if not window then return end

    window.maximized = false
    window.minimized = false
    Shell.minimizedWindows[id] = nil
    window.gui.Visible = true

    -- Restore saved position/size
    if window.savedPosition and window.savedSize then
        window.gui.Position = window.savedPosition
        window.gui.Size = window.savedSize
    end

    Shell.focusWindow(id)
    Shell.updateDockIndicators()
end

function Shell.closeWindow(id)
    local window = Shell.windows[id]
    if window and window.onClose then
        window.onClose()
    end
    Shell.unregisterWindow(id)
end

function Shell.snapWindow(id, direction)
    local window = Shell.windows[id]
    if not window or not Shell.wmConfig.snap then return end

    local viewport = Camera.ViewportSize
    local mbHeight = Shell.getMenuBarHeight()
    local dockHeight = Shell.getDockHeight()

    local newPos, newSize

    if direction == "left" then
        newPos = UDim2.new(0, 0, 0, mbHeight)
        newSize = UDim2.new(0.5, 0, 1, -mbHeight - dockHeight)
    elseif direction == "right" then
        newPos = UDim2.new(0.5, 0, 0, mbHeight)
        newSize = UDim2.new(0.5, 0, 1, -mbHeight - dockHeight)
    elseif direction == "tl" then -- top-left
        newPos = UDim2.new(0, 0, 0, mbHeight)
        newSize = UDim2.new(0.5, 0, 0.5, -mbHeight/2 - dockHeight/2)
    elseif direction == "tr" then
        newPos = UDim2.new(0.5, 0, 0, mbHeight)
        newSize = UDim2.new(0.5, 0, 0.5, -mbHeight/2 - dockHeight/2)
    elseif direction == "bl" then
        newPos = UDim2.new(0, 0, 0.5, mbHeight/2)
        newSize = UDim2.new(0.5, 0, 0.5, -mbHeight/2 - dockHeight/2)
    elseif direction == "br" then
        newPos = UDim2.new(0.5, 0, 0.5, mbHeight/2)
        newSize = UDim2.new(0.5, 0, 0.5, -mbHeight/2 - dockHeight/2)
    elseif direction == "center" then
        newSize = UDim2.new(0.8, 0, 0.8, 0)
        newPos = UDim2.new(0.1, 0, 0.1, mbHeight)
    end

    if newPos and newSize then
        window.savedPosition = window.gui.Position
        window.savedSize = window.gui.Size
        tween(window.gui, {Position = newPos, Size = newSize}, 0.15)
    end
end

function Shell.setWindowWorkspace(id, wsIndex)
    local window = Shell.windows[id]
    if not window or wsIndex < 1 or wsIndex > Shell.wmConfig.workspaces then return end

    -- Remove from old workspace
    local oldWs = window.workspace
    local oldList = Shell.workspaces[oldWs]
    for i, wid in ipairs(oldList) do
        if wid == id then table.remove(oldList, i) break end
    end

    -- Add to new workspace
    window.workspace = wsIndex
    table.insert(Shell.workspaces[wsIndex], id)

    -- If moving to current workspace, show it
    if wsIndex == Shell.currentWorkspace then
        window.gui.Visible = not Shell.minimizedWindows[id]
    else
        window.gui.Visible = false
    end

    Shell.updateWorkspaceIndicator()
end

function Shell.switchWorkspace(wsIndex)
    if wsIndex < 1 or wsIndex > Shell.wmConfig.workspaces or wsIndex == Shell.currentWorkspace then return end

    -- Hide current workspace windows
    for _, id in ipairs(Shell.workspaces[Shell.currentWorkspace]) do
        local win = Shell.windows[id]
        if win then win.gui.Visible = false end
    end

    Shell.currentWorkspace = wsIndex

    -- Show new workspace windows
    for _, id in ipairs(Shell.workspaces[wsIndex]) do
        local win = Shell.windows[id]
        if win and not Shell.minimizedWindows[id] then
            win.gui.Visible = true
        end
    end

    Shell.updateWorkspaceIndicator()
    Shell.updateDockIndicators()
end

function Shell.getMenuBarHeight()
    local config = Config.data
    if config and config.shell and config.shell.menubar and config.shell.menubar.enabled then
        return config.shell.menubar.height or 24
    end
    return 0
end

function Shell.getDockHeight()
    local config = Config.data
    if config and config.shell and config.shell.dock and config.shell.dock.enabled then
        return (config.shell.dock.icon_size or 40) + 10
    end
    return 0
end

-- Save window positions to cache
function Shell.saveWindowPositions()
    if not Shell.wmConfig.remember then return end
    local data = {}
    for id, window in pairs(Shell.windows) do
        data[id] = {
            position = {window.gui.Position.X.Scale, window.gui.Position.X.Offset, window.gui.Position.Y.Scale, window.gui.Position.Y.Offset},
            size = {window.gui.Size.X.Scale, window.gui.Size.X.Offset, window.gui.Size.Y.Scale, window.gui.Size.Y.Offset},
            workspace = window.workspace,
            minimized = Shell.minimizedWindows[id] or false
        }
    end
    local Executor = require(script.Parent.executor)
    pcall(Executor.fs_write, "cache/configs/windows.json", game:GetService("HttpService"):JSONEncode(data))
end

function Shell.restoreWindowPositions()
    local Executor = require(script.Parent.executor)
    local ok, content = Executor.fs_read("cache/configs/windows.json")
    if not ok or not content then return end

    local ok2, data = pcall(function() return game:GetService("HttpService"):JSONDecode(content) end)
    if not ok2 or not data then return end

    for id, saved in pairs(data) do
        local window = Shell.windows[id]
        if window then
            local pos = saved.position
            local size = saved.size
            window.gui.Position = UDim2.new(pos[1], pos[2], pos[3], pos[4])
            window.gui.Size = UDim2.new(size[1], size[2], size[3], size[4])
            window.workspace = saved.workspace or 1
            if saved.minimized then
                Shell.minimizedWindows[id] = true
                window.gui.Visible = false
            end
            -- Ensure in correct workspace list
            table.insert(Shell.workspaces[window.workspace], id)
        end
    end
    Shell.updateWorkspaceIndicator()
end

-- ============================================================
-- MENU BAR (Top)
-- ============================================================
function Shell.initMenuBar(config)
    config = config or {}
    if not config.enabled then
        Shell.menuBarVisible = false
        return
    end

    local height = config.height or 24
    local items = config.items or {"menu", "title", "clock", "fps", "executor", "theme", "tray", "binds"}

    Shell.menuBar = createInstance("Frame", {
        Name = "MenuBar",
        Size = UDim2.new(1, 0, 0, height),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = tokens.menubarBg,
        BorderSizePixel = 0,
        ZIndex = 150,
        Visible = true
    }, {
        roundCorners(nil, 0), -- no rounding for top bar
        addStroke(nil, tokens.border),
        createInstance("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 8)
        }),
        createInstance("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)})
    })

    Shell.menuBar.Parent = Shell.screenGui

    -- Build items
    for _, itemName in ipairs(items) do
        Shell.createMenuBarItem(itemName)
    end

    -- FPS counter update
    Shell.startFPSCounter()

    -- Clock update
    Shell.startClock()
end

function Shell.createMenuBarItem(itemName)
    if not Shell.menuBar then return end

    if itemName == "menu" then
        -- Temple logo + dropdown
        local btn = createInstance("TextButton", {
            Name = "MenuBtn",
            Size = UDim2.new(0, 32, 1, 0),
            BackgroundTransparency = 1,
            Text = "⛩",
            TextColor3 = tokens.menubarFg,
            TextSize = 16,
            Font = Enum.Font.GothamBold,
            ZIndex = 151
        })
        btn.Parent = Shell.menuBar
        btn.MouseButton1Click:Connect(function() Shell.toggleMainMenu(btn) end)

    elseif itemName == "title" then
        Shell.menuTitle = createInstance("TextLabel", {
            Name = "Title",
            Size = UDim2.new(0, 200, 1, 0),
            BackgroundTransparency = 1,
            Text = "TempleEx",
            TextColor3 = tokens.menubarFg,
            TextSize = 14,
            Font = Enum.Font.GothamSemibold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 151
        })
        Shell.menuTitle.Parent = Shell.menuBar

    elseif itemName == "clock" then
        Shell.clockLabel = createInstance("TextLabel", {
            Name = "Clock",
            Size = UDim2.new(0, 60, 1, 0),
            BackgroundTransparency = 1,
            Text = os.date("%H:%M"),
            TextColor3 = tokens.textMuted,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            ZIndex = 151
        })
        Shell.clockLabel.Parent = Shell.menuBar

    elseif itemName == "fps" then
        Shell.fpsLabel = createInstance("TextLabel", {
            Name = "FPS",
            Size = UDim2.new(0, 50, 1, 0),
            BackgroundTransparency = 1,
            Text = "60 FPS",
            TextColor3 = tokens.textMuted,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            ZIndex = 151
        })
        Shell.fpsLabel.Parent = Shell.menuBar

    elseif itemName == "executor" then
        Shell.executorLabel = createInstance("TextLabel", {
            Name = "Executor",
            Size = UDim2.new(0, 80, 1, 0),
            BackgroundTransparency = 1,
            Text = Executor.info.name:upper(),
            TextColor3 = tokens.accent,
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            ZIndex = 151
        })
        Shell.executorLabel.Parent = Shell.menuBar

    elseif itemName == "theme" then
        local btn = createInstance("TextButton", {
            Name = "ThemeBtn",
            Size = UDim2.new(0, 80, 0, 20),
            BackgroundColor3 = tokens.accent,
            Text = ThemeEngine.currentTheme or "Theme",
            TextColor3 = Color3.new(0,0,0),
            TextSize = 11,
            Font = Enum.Font.GothamSemibold,
            ZIndex = 151,
            AutoButtonColor = false
        })
        roundCorners(btn, 4)
        btn.Parent = Shell.menuBar
        btn.MouseButton1Click:Connect(Shell.cycleTheme)

    elseif itemName == "tray" then
        Shell.notificationBell = createInstance("TextButton", {
            Name = "NotificationBell",
            Size = UDim2.new(0, 28, 1, 0),
            BackgroundTransparency = 1,
            Text = "🔔",
            TextColor3 = tokens.menubarFg,
            TextSize = 16,
            ZIndex = 151
        })
        Shell.notificationBell.Parent = Shell.menuBar
        Shell.notificationBadge = createInstance("TextLabel", {
            Name = "Badge",
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(1, -8, 0, -4),
            BackgroundColor3 = tokens.danger or Color3.new(1,0,0),
            Text = "0",
            TextColor3 = Color3.new(1,1,1),
            TextSize = 10,
            Font = Enum.Font.GothamBold,
            ZIndex = 152
        })
        roundCorners(Shell.notificationBadge, 8)
        Shell.notificationBadge.Parent = Shell.notificationBell
        Shell.notificationBadge.Visible = false
        Shell.notificationBell.MouseButton1Click:Connect(Shell.toggleNotificationTray)

    elseif itemName == "binds" then
        Shell.bindsContainer = createInstance("Frame", {
            Name = "BindsContainer",
            Size = UDim2.new(0, 200, 1, 0),
            BackgroundTransparency = 1,
            ZIndex = 151
        }, {
            createInstance("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, 4)
            })
        })
        Shell.bindsContainer.Parent = Shell.menuBar
    end
end

function Shell.startFPSCounter()
    local frames = 0
    local lastTime = tick()
    RunService.RenderStepped:Connect(function()
        frames = frames + 1
        local now = tick()
        if now - lastTime >= 1 then
            if Shell.fpsLabel then
                Shell.fpsLabel.Text = frames .. " FPS"
                Shell.fpsLabel.TextColor3 = frames >= 55 and tokens.textMuted or (frames >= 30 and tokens.warning or tokens.danger)
            end
            frames = 0
            lastTime = now
        end
    end)
end

function Shell.startClock()
    task.spawn(function()
        while Shell.menuBar and Shell.menuBar.Parent do
            if Shell.clockLabel then
                Shell.clockLabel.Text = os.date("%H:%M:%S")
            end
            task.wait(1)
        end
    end)
end

function Shell.updateMenuTitle(title)
    if Shell.menuTitle then
        Shell.menuTitle.Text = title or "TempleEx"
    end
end

function Shell.cycleTheme()
    local themes = ThemeEngine.listThemes()
    local current = ThemeEngine.currentTheme
    local nextTheme = themes[1]
    for i, t in ipairs(themes) do
        if t.name == current then
            nextTheme = themes[i % #themes + 1]
            break
        end
    end
    ThemeEngine.setTheme(nextTheme.name)
end

function Shell.toggleMainMenu(anchor)
    -- TODO: Implement dropdown menu
end

function Shell.toggleNotificationTray()
    -- TODO: Implement notification history dropdown
end

-- ============================================================
-- DOCK (Bottom, Hover Reveal)
-- ============================================================
function Shell.initDock(config)
    config = config or {}
    if not config.enabled then return end

    Shell.dockConfig = {
        position = config.position or "bottom",
        reveal = config.reveal or "hover",
        revealZone = config.reveal_zone or 4,
        hideDelay = config.hide_delay or 0.4,
        iconSize = config.icon_size or 40,
        magnify = config.magnify ~= false,
        pins = config.pins or {"fly", "esp", "speed", "themes", "ai", "scripts"}
    }

    local iconSize = Shell.dockConfig.iconSize
    local dockHeight = iconSize + 16

    Shell.dock = createInstance("Frame", {
        Name = "Dock",
        Size = UDim2.new(1, 0, 0, dockHeight),
        Position = UDim2.new(0, 0, 1, 0), -- start hidden (off-screen)
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = tokens.dockBg,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ZIndex = 140,
        ClipsDescendants = false,
        Visible = false
    }, {
        roundCorners(nil, 16),
        addStroke(nil, tokens.border),
        createInstance("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 8)
        }),
        createInstance("UIPadding", {PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)})
    })

    Shell.dock.Parent = Shell.screenGui

    -- Add pinned items
    for _, pinId in ipairs(Shell.dockConfig.pins) do
        Shell.addDockPin(pinId)
    end

    -- Hover reveal logic
    if Shell.dockConfig.reveal == "hover" then
        local revealArea = createInstance("Frame", {
            Name = "DockRevealZone",
            Size = UDim2.new(1, 0, 0, Shell.dockConfig.revealZone),
            Position = UDim2.new(0, 0, 1, 0),
            AnchorPoint = Vector2.new(0, 1),
            BackgroundTransparency = 1,
            ZIndex = 139
        })
        revealArea.Parent = Shell.screenGui

        local revealDebounce = false
        revealArea.MouseEnter:Connect(function()
            if not revealDebounce then
                revealDebounce = true
                Shell.showDock()
            end
        end)

        Shell.dock.MouseLeave:Connect(function()
            task.wait(Shell.dockConfig.hideDelay)
            -- Check if mouse is still not over dock or reveal zone
            local mouse = UserInputService:GetMouseLocation()
            local dockPos = Shell.dock.AbsolutePosition
            local dockSize = Shell.dock.AbsoluteSize
            local revealPos = revealArea.AbsolutePosition

            local overDock = mouse.X >= dockPos.X and mouse.X <= dockPos.X + dockSize.X and
                           mouse.Y >= dockPos.Y and mouse.Y <= dockPos.Y + dockSize.Y
            local overReveal = mouse.Y >= revealPos.Y

            if not overDock and not overReveal then
                Shell.hideDock()
            end
            revealDebounce = false
        end)

        revealArea.MouseLeave:Connect(function()
            task.wait(Shell.dockConfig.hideDelay)
            local mouse = UserInputService:GetMouseLocation()
            local dockPos = Shell.dock.AbsolutePosition
            local dockSize = Shell.dock.AbsoluteSize

            local overDock = mouse.X >= dockPos.X and mouse.X <= dockPos.X + dockSize.X and
                           mouse.Y >= dockPos.Y and mouse.Y <= dockPos.Y + dockSize.Y

            if not overDock then
                Shell.hideDock()
            end
        end)
    end
end

function Shell.showDock()
    if Shell.dockVisible or Shell.dockAnimating then return end
    Shell.dockAnimating = true
    Shell.dock.Visible = true
    tween(Shell.dock, {Position = UDim2.new(0, 0, 1, 0)}, 0.2)
    Shell.dockVisible = true
    task.delay(0.2, function() Shell.dockAnimating = false end)
end

function Shell.hideDock()
    if not Shell.dockVisible or Shell.dockAnimating then return end
    Shell.dockAnimating = true
    tween(Shell.dock, {Position = UDim2.new(0, 0, 1, Shell.dock.AbsoluteSize.Y + 10)}, 0.2)
    task.delay(0.2, function()
        if not Shell.dockVisible then return end
        Shell.dock.Visible = false
        Shell.dockAnimating = false
    end)
    Shell.dockVisible = false
end

function Shell.addDockPin(pinId)
    if not Shell.dock then return end

    local icon, tooltip, action, isActiveFn

    if pinId == "fly" then
        icon = "✈"
        tooltip = "Fly"
        action = function() Core.toggle("fly") end
        isActiveFn = function() return Core.isEnabled("fly") end
    elseif pinId == "speed" then
        icon = "🏃"
        tooltip = "Speed"
        action = function() Core.toggle("speed") end
        isActiveFn = function() return Core.isEnabled("speed") end
    elseif pinId == "esp" then
        icon = "👁"
        tooltip = "ESP"
        action = function() Core.toggle("esp") end
        isActiveFn = function() return Core.isEnabled("esp") end
    elseif pinId == "noclip" then
        icon = "👻"
        tooltip = "Noclip"
        action = function() Core.toggle("noclip") end
        isActiveFn = function() return Core.isEnabled("noclip") end
    elseif pinId == "infjump" then
        icon = "🦘"
        tooltip = "Inf Jump"
        action = function() Core.toggle("infjump") end
        isActiveFn = function() return Core.isEnabled("infjump") end
    elseif pinId == "fullbright" then
        icon = "☀"
        tooltip = "Fullbright"
        action = function() Core.toggle("fullbright") end
        isActiveFn = function() return Core.isEnabled("fullbright") end
    elseif pinId == "hitbox" then
        icon = "🎯"
        tooltip = "Hitbox"
        action = function() Core.toggle("hitbox") end
        isActiveFn = function() return Core.isEnabled("hitbox") end
    elseif pinId == "freecam" then
        icon = "🎥"
        tooltip = "Freecam"
        action = function() Core.toggle("freecam") end
        isActiveFn = function() return Core.isEnabled("freecam") end
    elseif pinId == "themes" then
        icon = "🎨"
        tooltip = "Themes"
        action = function() Shell.openThemePicker() end
    elseif pinId == "ai" then
        icon = "✨"
        tooltip = "AI Themes"
        action = function() Shell.openAIThemes() end
    elseif pinId == "scripts" then
        icon = "📜"
        tooltip = "Scripts"
        action = function() Shell.openScriptHub() end
    else
        -- Custom pin from API
        local pin = Shell.dockPins[pinId]
        if pin then
            icon = pin.icon
            tooltip = pin.tooltip
            action = pin.action
            isActiveFn = pin.isActive
        else
            return
        end
    end

    local btn = createInstance("TextButton", {
        Name = "DockPin_" .. pinId,
        Size = UDim2.new(0, Shell.dockConfig.iconSize, 0, Shell.dockConfig.iconSize),
        BackgroundColor3 = tokens.elementBg,
        BackgroundTransparency = 0.3,
        Text = icon,
        TextColor3 = tokens.dockIcon,
        TextSize = Shell.dockConfig.iconSize * 0.5,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        ZIndex = 141
    })
    roundCorners(btn, 12)
    addStroke(btn, tokens.border)

    -- Active indicator
    local indicator = createInstance("Frame", {
        Name = "ActiveIndicator",
        Size = UDim2.new(0, 6, 0, 6),
        Position = UDim2.new(0.5, -3, 1, -8),
        BackgroundColor3 = tokens.dockIndicator,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 142
    })
    roundCorners(indicator, 3)
    indicator.Parent = btn

    -- Magnify effect
    if Shell.dockConfig.magnify then
        btn.MouseEnter:Connect(function()
            if not Shell.dockConfig.magnify then return end
            tween(btn, {Size = UDim2.new(0, Shell.dockConfig.iconSize * 1.3, 0, Shell.dockConfig.iconSize * 1.3)}, 0.1)
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, {Size = UDim2.new(0, Shell.dockConfig.iconSize, 0, Shell.dockConfig.iconSize)}, 0.1)
        end)
    end

    -- Tooltip
    local tooltipLabel = createInstance("TextLabel", {
        Name = "Tooltip",
        Size = UDim2.new(0, 0, 0, 20),
        Position = UDim2.new(0.5, 0, 0, -28),
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = tokens.elementBg,
        Text = tooltip,
        TextColor3 = tokens.textPrimary,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        Visible = false,
        ZIndex = 143
    })
    roundCorners(tooltipLabel, 4)
    addStroke(tooltipLabel, tokens.border)
    tooltipLabel.Parent = btn

    btn.MouseEnter:Connect(function()
        tooltipLabel.Visible = true
        tooltipLabel.Size = UDim2.new(0, tooltipLabel.TextBounds.X + 16, 0, 20)
    end)
    btn.MouseLeave:Connect(function()
        tooltipLabel.Visible = false
    end)

    -- Click action
    btn.MouseButton1Click:Connect(function()
        if action then action() end
        -- Update active state
        if isActiveFn then
            indicator.Visible = isActiveFn()
        end
    end)

    -- Right click = popover (simplified)
    btn.MouseButton2Click:Connect(function()
        if isActiveFn and isActiveFn() then
            -- Show param popover
            Shell.showPinPopover(pinId, btn)
        end
    end)

    btn.Parent = Shell.dock
    Shell.dockPins[pinId] = {button = btn, indicator = indicator, isActiveFn = isActiveFn}
    return btn
end

function Shell.addDockWindow(windowId, title, icon)
    if not Shell.dock then return end
    -- Windows get added to a separate section in dock (after pins)
    -- For simplicity, add to dock pins with special handling
    local btn = createInstance("TextButton", {
        Name = "DockWindow_" .. windowId,
        Size = UDim2.new(0, Shell.dockConfig.iconSize, 0, Shell.dockConfig.iconSize),
        BackgroundColor3 = tokens.elementBg,
        BackgroundTransparency = 0.3,
        Text = icon or "📄",
        TextColor3 = tokens.dockIcon,
        TextSize = Shell.dockConfig.iconSize * 0.5,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        ZIndex = 141
    })
    roundCorners(btn, 12)
    addStroke(btn, tokens.border)

    local indicator = createInstance("Frame", {
        Name = "ActiveIndicator",
        Size = UDim2.new(0, 6, 0, 6),
        Position = UDim2.new(0.5, -3, 1, -8),
        BackgroundColor3 = tokens.dockIndicator,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 142
    })
    roundCorners(indicator, 3)
    indicator.Parent = btn

    btn.MouseButton1Click:Connect(function()
        local win = Shell.windows[windowId]
        if win then
            if Shell.minimizedWindows[windowId] then
                Shell.restoreWindow(windowId)
            else
                Shell.focusWindow(windowId)
            end
        end
    end)

    btn.Parent = Shell.dock
    Shell.dockPins["window_" .. windowId] = {button = btn, indicator = indicator, isWindow = true, windowId = windowId}
    Shell.updateDockIndicators()
end

function Shell.removeDockWindow(windowId)
    local pin = Shell.dockPins["window_" .. windowId]
    if pin then
        pin.button:Destroy()
        Shell.dockPins["window_" .. windowId] = nil
    end
end

function Shell.updateDockIndicators()
    for pinId, pin in pairs(Shell.dockPins) do
        if pin.isActiveFn then
            pin.indicator.Visible = pin.isActiveFn()
        elseif pin.isWindow then
            local win = Shell.windows[pin.windowId]
            pin.indicator.Visible = win and Shell.focusedWindow == pin.windowId
        end
    end
end

function Shell.showPinPopover(pinId, anchor)
    -- Simplified: just open the main hub window for that function
    local hub = _G.TempleExHub
    if hub and hub.openTab then
        hub.openTab("Functions")
    end
end

-- Public API for scripts to add dock pins
function Shell.DockPin(def)
    def = def or {}
    local pinId = def.id or "custom_" .. (#Shell.dockPins + 1)
    Shell.dockPins[pinId] = def
    Shell.addDockPin(pinId)
    return pinId
end

function Shell.DockUnpin(pinId)
    local pin = Shell.dockPins[pinId]
    if pin and pin.button then
        pin.button:Destroy()
    end
    Shell.dockPins[pinId] = nil
end

-- ============================================================
-- SNAP ZONES (Visual preview when dragging window)
-- ============================================================
function Shell.initSnapZones()
    if not Shell.wmConfig.snap then return end

    Shell.snapPreview = createInstance("Frame", {
        Name = "SnapPreview",
        Size = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = tokens.snapPreview,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 2,
        BorderColor3 = tokens.snapPreview,
        Visible = false,
        ZIndex = 130
    })
    roundCorners(Shell.snapPreview, 0)
    Shell.snapPreview.Parent = Shell.screenGui
end

function Shell.showSnapPreview(zone)
    if not Shell.snapPreview then return end
    local viewport = Camera.ViewportSize
    local mbHeight = Shell.getMenuBarHeight()
    local dockHeight = Shell.getDockHeight()
    local usableHeight = viewport.Y - mbHeight - dockHeight

    local pos, size
    if zone == "left" then
        pos = UDim2.new(0, 0, 0, mbHeight)
        size = UDim2.new(0.5, 0, 0, usableHeight)
    elseif zone == "right" then
        pos = UDim2.new(0.5, 0, 0, mbHeight)
        size = UDim2.new(0.5, 0, 0, usableHeight)
    elseif zone == "tl" then
        pos = UDim2.new(0, 0, 0, mbHeight)
        size = UDim2.new(0.5, 0, 0, usableHeight/2)
    elseif zone == "tr" then
        pos = UDim2.new(0.5, 0, 0, mbHeight)
        size = UDim2.new(0.5, 0, 0, usableHeight/2)
    elseif zone == "bl" then
        pos = UDim2.new(0, 0, 0, mbHeight + usableHeight/2)
        size = UDim2.new(0.5, 0, 0, usableHeight/2)
    elseif zone == "br" then
        pos = UDim2.new(0.5, 0, 0, mbHeight + usableHeight/2)
        size = UDim2.new(0.5, 0, 0, usableHeight/2)
    end

    if pos and size then
        Shell.snapPreview.Position = pos
        Shell.snapPreview.Size = size
        Shell.snapPreview.Visible = true
    end
end

function Shell.hideSnapPreview()
    if Shell.snapPreview then
        Shell.snapPreview.Visible = false
    end
end

-- ============================================================
-- WINDOW SWITCHER (Alt+Tab)
-- ============================================================
function Shell.initSwitcher()
    Shell.switcherGui = createInstance("Frame", {
        Name = "WindowSwitcher",
        Size = UDim2.new(0, 600, 0, 120),
        Position = UDim2.new(0.5, -300, 0.5, -60),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = tokens.switcherBg,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 200
    }, {
        roundCorners(nil, 16),
        addStroke(nil, tokens.accent),
        addShadow(nil)
    })
    Shell.switcherGui.Parent = Shell.screenGui

    local list = createInstance("Frame", {
        Name = "List",
        Size = UDim2.new(1, -40, 1, -20),
        Position = UDim2.new(0, 20, 0, 10),
        BackgroundTransparency = 1
    }, {
        createInstance("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 12)
        })
    })
    list.Parent = Shell.switcherGui
    Shell.switcherList = list
end

function Shell.showSwitcher()
    if Shell.switcherVisible then
        Shell.nextSwitcher()
        return
    end

    -- Build list
    Shell.switcherList:ClearAllChildren()
    local windows = {}
    for id, win in pairs(Shell.windows) do
        if win.workspace == Shell.currentWorkspace and not Shell.minimizedWindows[id] then
            table.insert(windows, win)
        end
    end

    if #windows == 0 then return end

    Shell.switcherIndex = 1
    for i, win in ipairs(windows) do
        local item = createInstance("Frame", {
            Name = "Item_" .. win.id,
            Size = UDim2.new(0, 140, 1, 0),
            BackgroundColor3 = i == 1 and tokens.accent or tokens.elementBg,
            BackgroundTransparency = i == 1 and 0 or 0.3,
            ZIndex = 201
        }, {
            roundCorners(nil, 10),
            addStroke(nil, i == 1 and tokens.accent or tokens.border),
            createInstance("TextLabel", {
                Size = UDim2.new(1, 0, 0, 30),
                Position = UDim2.new(0, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                Text = win.title or "Window",
                TextColor3 = i == 1 and Color3.new(0,0,0) or tokens.textPrimary,
                TextSize = 14,
                Font = Enum.Font.GothamSemibold,
                ZIndex = 202
            })
        })
        item.Parent = Shell.switcherList
    end

    Shell.switcherGui.Visible = true
    Shell.switcherVisible = true
    Shell.updateSwitcherSelection()
end

function Shell.nextSwitcher()
    local items = Shell.switcherList:GetChildren()
    if #items == 0 then return end
    Shell.switcherIndex = Shell.switcherIndex % #items + 1
    Shell.updateSwitcherSelection()
end

function Shell.updateSwitcherSelection()
    for i, item in ipairs(Shell.switcherList:GetChildren()) do
        local isSel = i == Shell.switcherIndex
        item.BackgroundColor3 = isSel and tokens.accent or tokens.elementBg
        item.BackgroundTransparency = isSel and 0 or 0.3
        local label = item:FindFirstChild("TextLabel")
        if label then
            label.TextColor3 = isSel and Color3.new(0,0,0) or tokens.textPrimary
        end
    end
end

function Shell.hideSwitcher()
    if not Shell.switcherVisible then return end
    local items = Shell.switcherList:GetChildren()
    if items[Shell.switcherIndex] then
        local winId = items[Shell.switcherIndex].Name:match("Item_(.+)")
        if winId then
            Shell.focusWindow(tonumber(winId))
        end
    end
    Shell.switcherGui.Visible = false
    Shell.switcherVisible = false
end

-- ============================================================
-- WORKSPACE INDICATOR
-- ============================================================
function Shell.updateWorkspaceIndicator()
    if Shell.wmConfig.workspaces <= 1 then return end
    -- TODO: Add workspace indicator to menu bar or dock
end

-- ============================================================
-- GLOBAL KEY BINDINGS
-- ============================================================
function Shell.bindGlobalKeys(wmConfig)
    wmConfig = wmConfig or {}

    -- Entry key (toggle all windows / hub)
    local entryKey = Config.get("temple.entry_key") or "RightControl"
    local okEntry, entryKeyCode = pcall(function() return Enum.KeyCode[entryKey] end)
    if not (okEntry and entryKeyCode) then
        -- Stale/invalid value in the saved config (e.g. old "RightCtrl"): fall back.
        entryKey = "RightControl"
        okEntry, entryKeyCode = pcall(function() return Enum.KeyCode[entryKey] end)
    end
    if okEntry and entryKeyCode then
        UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.KeyCode == entryKeyCode then
                Shell.toggleGUI()
            end
        end)
    end

    -- Alt+Tab switcher
    UserInputService.InputBegan:Connect(function(input, processed)
        if input.KeyCode == Enum.KeyCode.Tab and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
            Shell.showSwitcher()
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.LeftAlt and Shell.switcherVisible then
            Shell.hideSwitcher()
        end
    end)

    -- Workspace switching (Ctrl+1, Ctrl+2, etc.)
    -- Roblox top-row digit enum names are One..Nine, Zero (NOT "Number1").
    local DIGIT_KEYS = {"One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Zero"}
    for i = 1, 8 do
        local digitKey = Enum.KeyCode[DIGIT_KEYS[i]]
        if digitKey then
            UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.KeyCode == digitKey and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    if i <= Shell.wmConfig.workspaces then
                        Shell.switchWorkspace(i)
                    end
                end
            end)
        end
    end
end

-- Show / hide the entire hub (dock + menu bar + windows live in screenGui).
function Shell.toggleGUI()
    if Shell.screenGui then
        Shell.screenGui.Enabled = not Shell.screenGui.Enabled
    end
end

function Shell.showGUI()
    if Shell.screenGui then
        Shell.screenGui.Enabled = true
    end
end

function Shell.toggleAllWindows()
    local anyVisible = false
    for id, win in pairs(Shell.windows) do
        if win.workspace == Shell.currentWorkspace and win.gui.Visible then
            anyVisible = true
            break
        end
    end

    for id, win in pairs(Shell.windows) do
        if win.workspace == Shell.currentWorkspace then
            win.gui.Visible = not anyVisible and not Shell.minimizedWindows[id]
        end
    end
end

-- ============================================================
-- PUBLIC API FOR SCRIPTS
-- ============================================================
function Shell.MenuItem(def)
    -- Add item to menu bar dropdown
    table.insert(Shell.menuItems, def)
    -- TODO: Implement actual menu rendering
    return #Shell.menuItems
end

function Shell.StatusChip(def)
    -- Add status chip to menu bar
    table.insert(Shell.statusChips, def)
    -- TODO: Implement
    return #Shell.statusChips
end

function Shell.Workspace()
    return Shell.currentWorkspace
end

function Shell.SetWorkspace(ws)
    Shell.switchWorkspace(ws)
end

function Shell.WorkspaceCount()
    return Shell.wmConfig.workspaces
end

function Shell.openThemePicker()
    -- TODO: Open theme picker tab in hub
end

function Shell.openAIThemes()
    -- TODO: Open AI themes panel
end

function Shell.openScriptHub()
    -- TODO: Open scripts tab
end

-- ============================================================
-- THEME REACTIVITY
-- ============================================================
ThemeEngine.subscribe(function()
    updateTokens()
    -- Update all shell elements
    if Shell.menuBar then
        Shell.menuBar.BackgroundColor3 = tokens.menubarBg
        if Shell.menuTitle then Shell.menuTitle.TextColor3 = tokens.menubarFg end
        if Shell.clockLabel then Shell.clockLabel.TextColor3 = tokens.textMuted end
        if Shell.fpsLabel then Shell.fpsLabel.TextColor3 = tokens.textMuted end
        if Shell.executorLabel then Shell.executorLabel.TextColor3 = tokens.accent end
    end
    if Shell.dock then
        Shell.dock.BackgroundColor3 = tokens.dockBg
        for _, pin in pairs(Shell.dockPins) do
            if pin.button then
                pin.button.BackgroundColor3 = tokens.elementBg
                pin.button.TextColor3 = tokens.dockIcon
                if pin.indicator then pin.indicator.BackgroundColor3 = tokens.dockIndicator end
            end
        end
    end
    if Shell.snapPreview then
        Shell.snapPreview.BackgroundColor3 = tokens.snapPreview
        Shell.snapPreview.BorderColor3 = tokens.snapPreview
    end
    if Shell.switcherGui then
        Shell.switcherGui.BackgroundColor3 = tokens.switcherBg
    end
end)

return Shell