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
local Icons = require(script.Parent.icons)

-- Material icon name per dock pin id
local PIN_ICON = {
    fly = "flight", speed = "directions_run", esp = "visibility", noclip = "block",
    infjump = "arrow_upward", fullbright = "wb_sunny", hitbox = "center_focus",
    freecam = "photo_camera", themes = "palette", ai = "auto_awesome", scripts = "code",
}
Shell._dockIconSetters = {}   -- recolor functions, run on theme change

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
    -- Recolor existing dock Material icons to the new theme.
    for _, setter in ipairs(Shell._dockIconSetters) do
        pcall(setter, tokens.dockIcon)
    end
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

    -- NOTE: windows are NOT auto-added to the dock. The dock holds only the
    -- Start button and user-pinned shortcuts. Open windows are listed in the
    -- Start Menu instead.

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
    if not window then return end
    if window.onClose then
        window.onClose()
    end
    Shell.unregisterWindow(id)
    -- unregisterWindow only untracks; destroy the actual GUI so the window
    -- disappears (previously the frame stayed on screen after Close).
    if window.gui then
        pcall(function() window.gui:Destroy() end)
    end
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

-- Magnetic snap for window dragging: align to screen edges and to other
-- windows' edges/centers within a threshold. Returns adjusted (x, y) in
-- absolute screen pixels. `excludeId` is the window being dragged.
function Shell.snapPosition(excludeId, x, y, w, h)
    local vw, vh = Camera.ViewportSize.X, Camera.ViewportSize.Y
    local top = Shell.getMenuBarHeight()
    local bottom = vh - Shell.getDockHeight()
    local TH = 8
    local xs = { 0, vw - w, (vw - w) / 2 }
    local ys = { top, bottom - h, (top + bottom - h) / 2 }
    for id, win in pairs(Shell.windows) do
        if id ~= excludeId and win.gui and win.gui.Visible then
            local ox, oy = win.gui.AbsolutePosition.X, win.gui.AbsolutePosition.Y
            local ow, oh = win.gui.AbsoluteSize.X, win.gui.AbsoluteSize.Y
            table.insert(xs, ox); table.insert(xs, ox + ow - w); table.insert(xs, ox + ow / 2 - w / 2)
            table.insert(ys, oy); table.insert(ys, oy + oh - h); table.insert(ys, oy + oh / 2 - h / 2)
        end
    end
    local function snapTo(val, cands)
        local best, bd = val, TH + 1
        for _, c in ipairs(cands) do
            local d = math.abs(c - val)
            if d < bd then bd = d; best = c end
        end
        if bd > TH then return val end
        return best
    end
    return snapTo(x, xs), snapTo(y, ys)
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

    local pins = config.pins or Config.get("shell.dock.pins") or { "start" }
    -- One-time migration: the old default pre-pinned a set of shortcuts. The
    -- dock now starts with only the Start button; drop that legacy set so the
    -- user gets a clean dock (their own added shortcuts are preserved).
    local LEGACY_DEFAULT = { "fly", "esp", "speed", "themes", "ai", "scripts" }
    local function sameList(a, b)
        if #a ~= #b then return false end
        for i = 1, #a do if a[i] ~= b[i] then return false end end
        return true
    end
    if sameList(pins, LEGACY_DEFAULT) then pins = { "start" } end
    -- The Start button is always present; its side (leftmost/rightmost in the
    -- dock) is configurable via shell.dock.start_position.
    local startPos = Config.get("shell.dock.start_position") or "left"
    for i = #pins, 1, -1 do if pins[i] == "start" then table.remove(pins, i) end end
    if startPos == "right" then
        table.insert(pins, "start")
    else
        table.insert(pins, 1, "start")
    end

    Shell.dockConfig = {
        position = config.position or "bottom",
        reveal = config.reveal or "hover",
        revealZone = config.reveal_zone or 4,
        hideDelay = config.hide_delay or 0.4,
        iconSize = config.icon_size or 40,
        magnify = config.magnify ~= false,
        pins = pins
    }

    local iconSize = Shell.dockConfig.iconSize
    local dockHeight = iconSize + 16

    -- Compact dock: hugs its content (AutomaticSize.X), centered at the bottom,
    -- NOT full screen width.
    Shell.dock = createInstance("Frame", {
        Name = "Dock",
        Size = UDim2.new(0, 0, 0, dockHeight),
        AutomaticSize = Enum.AutomaticSize.X,
        Position = UDim2.new(0.5, 0, 1, dockHeight + 10), -- start off-screen (slides up on reveal)
        AnchorPoint = Vector2.new(0.5, 1),
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
        createInstance("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)})
    })

    Shell.dock.Parent = Shell.screenGui

    -- Add pinned items
    for _, pinId in ipairs(Shell.dockConfig.pins) do
        Shell.addDockPin(pinId)
    end

    -- Hover reveal logic. Token-based: entering the dock OR the reveal zone
    -- bumps a token that cancels any scheduled hide, so moving between them
    -- never hides the dock, and re-entering always shows it (no stuck debounce).
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

        local hideToken = 0
        local function mouseOverDockOrZone()
            local m = UserInputService:GetMouseLocation()
            if Shell.dock then
                local p, s = Shell.dock.AbsolutePosition, Shell.dock.AbsoluteSize
                if m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y then
                    return true
                end
            end
            -- reveal strip is pinned to the bottom edge
            if m.Y >= revealArea.AbsolutePosition.Y then return true end
            return false
        end
        local function onEnter()
            hideToken = hideToken + 1          -- cancel any scheduled hide
            Shell.showDock()
        end
        local function onLeave()
            hideToken = hideToken + 1
            local myToken = hideToken
            task.delay(Shell.dockConfig.hideDelay, function()
                if hideToken ~= myToken then return end   -- re-entered meanwhile
                if not mouseOverDockOrZone() then          -- safety net vs event race
                    Shell.hideDock()
                end
            end)
        end

        revealArea.MouseEnter:Connect(onEnter)
        revealArea.MouseLeave:Connect(onLeave)
        Shell.dock.MouseEnter:Connect(onEnter)
        Shell.dock.MouseLeave:Connect(onLeave)
    end
end

function Shell.showDock()
    if not Shell.dock then return end
    Shell.dockVisible = true
    Shell.dock.Visible = true
    tween(Shell.dock, {Position = UDim2.new(0.5, 0, 1, 0)}, 0.2)
end

function Shell.hideDock()
    if not Shell.dock then return end
    Shell.dockVisible = false
    local off = Shell.dock.Size.Y.Offset + 10
    tween(Shell.dock, {Position = UDim2.new(0.5, 0, 1, off)}, 0.2)
    task.delay(0.2, function()
        -- Finish hiding only if it is still meant to be hidden (no re-show since).
        if not Shell.dockVisible then
            Shell.dock.Visible = false
        end
    end)
end

function Shell.addDockPin(pinId)
    if not Shell.dock then return end

    local icon, tooltip, action, isActiveFn, iconName

    local mod = Shell.resolveModule(pinId)
    if mod then
        icon = mod.glyph
        tooltip = mod.title
        action = mod.action
        isActiveFn = mod.isActiveFn
        iconName = mod.iconName
    else
        -- Custom pin registered via Shell.DockPin(def)
        local pin = Shell.dockPins[pinId]
        if pin then
            icon = pin.icon
            tooltip = pin.tooltip
            action = pin.action
            isActiveFn = pin.isActive
            iconName = pin.iconName
        else
            return
        end
    end

    local btn = createInstance("TextButton", {
        Name = "DockPin_" .. pinId,
        Size = UDim2.new(0, Shell.dockConfig.iconSize, 0, Shell.dockConfig.iconSize),
        BackgroundColor3 = tokens.elementBg,
        BackgroundTransparency = 0.3,
        Text = iconName and "" or icon,
        TextColor3 = tokens.dockIcon,
        TextSize = Shell.dockConfig.iconSize * 0.5,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        ZIndex = 141
    })
    roundCorners(btn, 12)
    addStroke(btn, tokens.border)

    if iconName then
        local _, setIcon = Icons.new(iconName, btn, Shell.dockConfig.iconSize * 0.5, tokens.dockIcon)
        table.insert(Shell._dockIconSetters, setIcon)
    end

    -- Shortcut badge: small marker at the bottom-right of every pinned
    -- shortcut (not the Start button).
    if pinId ~= "start" and Icons.shortcutBadge then
        local badge = Instance.new("ImageLabel")
        badge.Name = "ShortcutBadge"
        badge.Image = Icons.shortcutBadge
        badge.BackgroundTransparency = 1
        badge.ImageColor3 = tokens.dockIcon
        badge.Size = UDim2.new(0, 14, 0, 14)
        badge.Position = UDim2.new(1, -1, 1, -1)
        badge.AnchorPoint = Vector2.new(1, 1)
        badge.ZIndex = 143
        badge.Parent = btn
    end

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

    -- Right click = unpin this shortcut (Start button is permanent).
    btn.MouseButton2Click:Connect(function()
        if pinId ~= "start" then
            Shell.unpinModule(pinId)
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
-- MODULE REGISTRY + START MENU + DOCK SHORTCUTS
-- ============================================================

-- Panel pseudo-modules (open a window rather than toggle a Core function).
Shell.panelModules = {
    themes  = { title = "Themes",    iconName = "palette",      glyph = "🎨", open = function() Shell.openThemePicker() end },
    ai      = { title = "AI Themes", iconName = "auto_awesome", glyph = "✨", open = function() Shell.openAIThemes() end },
    scripts = { title = "Scripts",   iconName = "code",         glyph = "📜", open = function() Shell.openScriptHub() end },
}

-- Resolve any dock/start id to a uniform module descriptor, or nil.
function Shell.resolveModule(id)
    if id == "start" then
        return { id = "start", title = "Start", iconName = "start", glyph = "⊞",
                 kind = "start", action = function() Shell.toggleStartMenu() end }
    end
    local panel = Shell.panelModules[id]
    if panel then
        return { id = id, title = panel.title, iconName = panel.iconName, glyph = panel.glyph,
                 kind = "panel", action = panel.open }
    end
    local def = Core.getModule(id)
    if def then
        return {
            id = id, title = def.title or id, glyph = def.icon, iconName = PIN_ICON[id],
            kind = "core", category = def.category,
            action = function() Core.toggle(id) end,
            isActiveFn = function() return Core.isEnabled(id) end,
        }
    end
    return nil
end

-- ---- Dock shortcut pin/unpin with persistence ----------------
function Shell.pinModule(id)
    if not Shell.dockConfig then return end
    if not Shell.resolveModule(id) then return end   -- only real modules are pinnable
    for _, p in ipairs(Shell.dockConfig.pins) do
        if p == id then return end                    -- already pinned
    end
    table.insert(Shell.dockConfig.pins, id)
    Shell.addDockPin(id)
    Shell.saveDockPins()
end

function Shell.unpinModule(id)
    if id == "start" then return end
    Shell.DockUnpin(id)
    if Shell.dockConfig then
        for i, p in ipairs(Shell.dockConfig.pins) do
            if p == id then table.remove(Shell.dockConfig.pins, i); break end
        end
    end
    Shell.saveDockPins()
end

function Shell.saveDockPins()
    if not Shell.dockConfig then return end
    pcall(Config.set, "shell.dock.pins", Shell.dockConfig.pins)
end

-- ---- Drag & drop helpers -------------------------------------
local function isOverDock(mpos)
    if not Shell.dock or not Shell.dock.Visible then return false end
    local p, s = Shell.dock.AbsolutePosition, Shell.dock.AbsoluteSize
    return mpos.X >= p.X and mpos.X <= p.X + s.X and mpos.Y >= p.Y and mpos.Y <= p.Y + s.Y
end

local function makeDragGhost(iconName, id)
    local g = createInstance("Frame", {
        Name = "DragGhost", Size = UDim2.new(0, 46, 0, 46),
        BackgroundColor3 = tokens.elementBg, BackgroundTransparency = 0.15,
        AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = 1000
    })
    roundCorners(g, 10)
    addStroke(g, tokens.accent, 2)
    Icons.new(iconName or id, g, 28, tokens.dockIcon)
    g.Parent = Shell.screenGui
    return g
end

-- Attach click-to-open + drag-to-dock behaviour to a Start Menu row.
function Shell._makeRowDraggable(btn, id, onClick, canDrag)
    if not canDrag then
        btn.MouseButton1Click:Connect(function() if onClick then onClick() end end)
        return
    end
    btn.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local startPos = input.Position
        local dragging, ghost, moveConn, endConn
        Shell.showDock()
        moveConn = UserInputService.InputChanged:Connect(function(m)
            if m.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            if not dragging and (m.Position - startPos).Magnitude > 8 then
                dragging = true
                local mod = Shell.resolveModule(id)
                ghost = makeDragGhost(mod and mod.iconName, id)
            end
            if dragging and ghost then
                ghost.Position = UDim2.new(0, m.X, 0, m.Y)
            end
        end)
        endConn = UserInputService.InputEnded:Connect(function(m)
            if m.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            moveConn:Disconnect(); endConn:Disconnect()
            if dragging then
                if ghost then
                    if isOverDock(m.Position) then Shell.pinModule(id) end
                    ghost:Destroy()
                end
            else
                if onClick then onClick() end
            end
            dragging = false
        end)
    end)
end

-- ---- Open a module in its own window -------------------------
function Shell.openModuleWindow(id)
    local mod = Shell.resolveModule(id)
    if not mod then return end
    Shell._moduleWindows = Shell._moduleWindows or {}
    local ex = Shell._moduleWindows[id]
    if ex and Shell.windows[ex.id] then
        if Shell.minimizedWindows[ex.id] then Shell.restoreWindow(ex.id) end
        Shell.focusWindow(ex.id)
        return ex
    end
    local ok, TempleApi = pcall(function() return require(script.Parent.api) end)
    if not ok or not TempleApi or not TempleApi.Window then
        Log.warn("openModuleWindow: api unavailable")
        return
    end
    local win = TempleApi.Window({ title = mod.title or id, size = { 380, 340 } })
    Shell._moduleWindows[id] = win
    win:OnClosed(function() Shell._moduleWindows[id] = nil end)
    local tab = win:Tab("Main")
    local def = Core.getModule(id)
    -- A module may provide its own rich window builder instead of the
    -- auto-generated param widgets.
    if def and def.buildWindow then
        local okBuild = pcall(function() def.buildWindow(win, tab, id) end)
        if not okBuild then Log.warn("buildWindow failed for " .. tostring(id)) end
        return win
    end
    local sec = tab:Section(mod.title or id)
    if mod.kind == "core" then
        sec:Toggle({
            title = "Enable",
            default = Core.isEnabled(id),
            callback = function(state)
                if state then Core.enable(id) else Core.disable(id) end
                Shell.updateDockIndicators()
            end
        })
        if def and def.params then
            local names = {}
            for pn in pairs(def.params) do table.insert(names, pn) end
            table.sort(names)
            for _, pn in ipairs(names) do
                local pd = def.params[pn]
                if pd.type == "number" then
                    sec:Slider({
                        title = pn, min = pd.min or 0, max = pd.max or 100, step = pd.step or 1,
                        suffix = pd.suffix or "",
                        default = Core.getParam(id, pn) or pd.default or 0,
                        callback = function(v) Core.setParam(id, pn, v) end
                    })
                elseif pd.type == "string" and pd.options then
                    sec:Dropdown({
                        title = pn, values = pd.options,
                        default = Core.getParam(id, pn) or pd.default,
                        callback = function(v) Core.setParam(id, pn, v) end
                    })
                elseif pd.type == "boolean" then
                    sec:Toggle({
                        title = pn, default = Core.getParam(id, pn) or pd.default or false,
                        callback = function(v) Core.setParam(id, pn, v) end
                    })
                end
            end
        end
    else
        sec:Label({ text = (mod.title or id) .. " panel" })
        if mod.action then pcall(mod.action) end
    end
    return win
end

-- ---- Start Menu panel ----------------------------------------
function Shell.toggleStartMenu()
    if Shell._startMenu and Shell._startMenu.Visible then
        Shell.closeStartMenu()
    else
        Shell.openStartMenu()
    end
end

function Shell.openStartMenu()
    if not Shell._startMenu then Shell._buildStartMenu() end
    local sm = Shell._startMenu
    if not sm then return end
    local dh = (Shell.dock and Shell.dock.Size.Y.Offset) or 56
    sm.Position = UDim2.new(0.5, 0, 1, -(dh + 8))
    sm.Visible = true
    Shell._populateStartMenu(Shell._startSearch and Shell._startSearch.Text or "")
end

function Shell.closeStartMenu()
    if Shell._startMenu then Shell._startMenu.Visible = false end
end

function Shell._buildStartMenu()
    local W, H = 340, 420
    local sm = createInstance("Frame", {
        Name = "StartMenu", Size = UDim2.new(0, W, 0, H),
        Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = tokens.bg, BorderSizePixel = 0, ZIndex = 200,
        Visible = false, ClipsDescendants = false
    })
    roundCorners(sm, tokens.radius)
    addStroke(sm, tokens.border)
    addShadow(sm)

    createInstance("TextLabel", {
        Name = "Title", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 0, 6),
        BackgroundTransparency = 1, Text = "Start", TextColor3 = tokens.textPrimary,
        TextSize = 15, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201, Parent = sm
    })

    local search = createInstance("TextBox", {
        Name = "Search", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 0, 40),
        BackgroundColor3 = tokens.elementBg, PlaceholderText = "Search modules...",
        Text = "", TextColor3 = tokens.textPrimary, PlaceholderColor3 = tokens.textMuted,
        TextSize = 13, Font = Enum.Font.Gotham, ClearTextOnFocus = false, ZIndex = 201
    })
    roundCorners(search, 8)
    addStroke(search, tokens.border)
    createInstance("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = search })
    search.Parent = sm

    local list = createInstance("ScrollingFrame", {
        Name = "List", Size = UDim2.new(1, -24, 1, -86), Position = UDim2.new(0, 12, 0, 78),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
        ScrollBarImageColor3 = tokens.accent, ZIndex = 201
    })
    createInstance("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
    list.Parent = sm

    search:GetPropertyChangedSignal("Text"):Connect(function()
        Shell._populateStartMenu(search.Text)
    end)

    -- Click outside (and not on the dock) closes the menu.
    UserInputService.InputBegan:Connect(function(input)
        if not (Shell._startMenu and Shell._startMenu.Visible) then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local p = input.Position
        local sp, ss = Shell._startMenu.AbsolutePosition, Shell._startMenu.AbsoluteSize
        local inSm = p.X >= sp.X and p.X <= sp.X + ss.X and p.Y >= sp.Y and p.Y <= sp.Y + ss.Y
        if not inSm and not isOverDock(p) then Shell.closeStartMenu() end
    end)

    sm.Parent = Shell.screenGui
    Shell._startMenu = sm
    Shell._startSearch = search
    Shell._startList = list
end

function Shell._populateStartMenu(filter)
    if not Shell._startMenu then return end
    filter = (filter or ""):lower()
    local list = Shell._startList

    for _, ch in ipairs(list:GetChildren()) do
        if ch:IsA("GuiObject") and ch.Name ~= "UIListLayout" then ch:Destroy() end
    end

    local order = 0
    local function addRow(id, title, glyph, iconName, onClick, active, canDrag)
        if filter ~= "" and not (tostring(title):lower():find(filter, 1, true)) then return end
        order = order + 1
        local row = createInstance("TextButton", {
            Name = "Row_" .. id, Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = tokens.elementBg, BackgroundTransparency = 0.4,
            Text = "", AutoButtonColor = false, ZIndex = 202, LayoutOrder = order
        })
        roundCorners(row, 8)
        -- Left icon holder (Icons.new centers within it, so it sits at the left).
        local holder = createInstance("Frame", {
            Name = "IconHolder", Size = UDim2.new(0, 44, 1, 0), Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1, ZIndex = 202
        })
        holder.Parent = row
        Icons.new(iconName or id, holder, 22, active and tokens.accent or tokens.dockIcon)
        createInstance("TextLabel", {
            Name = "Lbl", Size = UDim2.new(1, -56, 1, 0), Position = UDim2.new(0, 44, 0, 0),
            BackgroundTransparency = 1, Text = title, TextColor3 = tokens.textPrimary,
            TextSize = 13, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 203, Parent = row
        })
        if active then
            local dot = createInstance("Frame", {
                Name = "Dot", Size = UDim2.new(0, 6, 0, 6), Position = UDim2.new(1, -16, 0.5, -3),
                BackgroundColor3 = tokens.accent, BorderSizePixel = 0, ZIndex = 203
            })
            roundCorners(dot, 3)
            dot.Parent = row
        end
        row.Parent = list
        Shell._makeRowDraggable(row, id, onClick, canDrag)
    end

    -- Core modules (sorted by category, then title)
    local mods = Core.listModules()
    table.sort(mods, function(a, b)
        local ca, cb = a.category or "", b.category or ""
        if ca ~= cb then return ca < cb end
        return (a.title or "") < (b.title or "")
    end)
    for _, m in ipairs(mods) do
        addRow(m.id, m.title or m.id, m.icon, PIN_ICON[m.id],
            function() Shell.openModuleWindow(m.id) end, m.enabled, true)
    end

    -- Panels
    local panelIds = {}
    for id in pairs(Shell.panelModules) do table.insert(panelIds, id) end
    table.sort(panelIds)
    for _, id in ipairs(panelIds) do
        local panel = Shell.panelModules[id]
        addRow(id, panel.title, panel.glyph, panel.iconName,
            function() Shell.openModuleWindow(id) end, false, true)
    end

    -- Currently open windows (focus on click; not pinnable)
    local winIds = {}
    for wid in pairs(Shell.windows) do table.insert(winIds, wid) end
    table.sort(winIds)
    for _, wid in ipairs(winIds) do
        local win = Shell.windows[wid]
        if win then
            addRow("win_" .. wid, win.title or ("Window " .. wid), nil, nil, function()
                if Shell.minimizedWindows[wid] then Shell.restoreWindow(wid) else Shell.focusWindow(wid) end
            end, Shell.focusedWindow == wid, false)
        end
    end
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
                local badge = pin.button:FindFirstChild("ShortcutBadge")
                if badge then badge.ImageColor3 = tokens.dockIcon end
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