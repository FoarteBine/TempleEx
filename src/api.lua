--[[
    TempleEx Public API (TempleApi)
    The interface that third-party scripts use
]]

local TempleApi = {}
TempleApi.__index = TempleApi

local Executor = require(script.Parent.executor)
local ThemeEngine = require(script.Parent.theme)
local Core = require(script.Parent.core)
local Shell = require(script.Parent.shell)
local Config = require(script.Parent.config)
local Log = require(script.Parent.log)

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Shared tween helper (must be defined before use)
local function tween(obj, props, duration)
    if not obj then return end
    local t = TweenService:Create(obj, TweenInfo.new(duration or 0.15, Enum.EasingStyle.Quad), props)
    t:Play()
    return t
end

-- Safe geometry accessors (theme sections may be missing)
local function themeRadius(fallback)
    local t = ThemeEngine.currentRawTheme
    return (t and t.geometry and t.geometry.radius and t.geometry.radius.window) or fallback
end
local function themePadding(fallback)
    local t = ThemeEngine.currentRawTheme
    return (t and t.geometry and t.geometry.padding and t.geometry.padding.window) or fallback
end
local function themeElemRadius(fallback)
    local t = ThemeEngine.currentRawTheme
    return (t and t.geometry and t.geometry.radius and t.geometry.radius.element) or fallback
end
local function themeElemPadding(fallback)
    local t = ThemeEngine.currentRawTheme
    return (t and t.geometry and t.geometry.padding and t.geometry.padding.element) or fallback
end

TempleApi.version = {major = 1, minor = 0, patch = 0}
TempleApi._windows = {}
TempleApi._windowIdCounter = 0
TempleApi._flags = {}
TempleApi._callbacks = {}
TempleApi._keybinds = {}
TempleApi._commands = {}
TempleApi._initialized = false
TempleApi._scriptContext = nil

-- ============================================================
-- INITIALIZATION
-- ============================================================
function TempleApi.init()
    if TempleApi._initialized then return TempleApi end

    -- Initialize subsystems (idempotent — main init may have done this already)
    local Config = require(script.Parent.config)
    if not Config.data then
        Config.init("")  -- executor workspace root
    end
    local ThemeEngine = require(script.Parent.theme)
    if not next(ThemeEngine.themes) then
        ThemeEngine.loadAllThemes(Config.get("paths.themes") or "themes")
    end
    if not ThemeEngine.currentTheme then
        ThemeEngine.applyTheme(Config.get("theme.active") or "midnight-temple")
    end
    local Shell = require(script.Parent.shell)
    if not Shell.screenGui then
        Shell.init()
    end

    -- Load core state
    Core.loadState(Config.data)

    TempleApi._initialized = true
    Log.info("TempleApi initialized v" .. TempleApi.version.major .. "." .. TempleApi.version.minor .. "." .. TempleApi.version.patch)

    return TempleApi
end

function TempleApi.get()
    if not TempleApi._initialized then
        TempleApi.init()
    end
    return TempleApi
end

-- ============================================================
-- UI: WINDOW MANAGEMENT
-- ============================================================
local createSection  -- forward declaration (defined after widgets section)

function TempleApi.Window(options)
    options = options or {}
    TempleApi._windowIdCounter = TempleApi._windowIdCounter + 1
    local id = TempleApi._windowIdCounter

    local window = {
        id = id,
        title = options.title or "Window",
        tabs = {},
        currentTab = nil,
        gui = nil,
        container = nil,
        sidebar = nil,
        contentArea = nil,
        onFocus = options.onFocus,
        onFocusLost = options.onFocusLost,
        onClose = options.onClose,
        keybind = options.keybind,
        minimized = false,
        maximized = false,
        savedPosition = nil,
        savedSize = nil,
        workspace = Shell.currentWorkspace,
        floating = options.floating or false,
        _elements = {}
    }

    -- Create GUI
    local size = options.size or Config.get("behavior.window_default.size") or {520, 380}
    local radius = themeRadius(12)
    local padding = themePadding(14)

    window.gui = Instance.new("Frame")
    window.gui.Name = "TempleWindow_" .. id
    window.gui.Size = UDim2.new(0, size[1], 0, size[2])
    window.gui.Position = UDim2.new(0.5, -size[1]/2, 0.5, -size[2]/2)
    window.gui.BackgroundColor3 = ThemeEngine.getToken("window.bg")
    window.gui.BorderSizePixel = 0
    window.gui.ZIndex = 50
    window.gui.Visible = true
    window.gui.Parent = Shell.screenGui

    -- Round corners, stroke, shadow
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = window.gui

    local stroke = Instance.new("UIStroke")
    stroke.Color = ThemeEngine.getToken("window.border")
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = window.gui

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 36)
    titleBar.BackgroundTransparency = 1
    titleBar.ZIndex = 51
    titleBar.Parent = window.gui

    local titleText = Instance.new("TextLabel")
    titleText.Name = "Title"
    titleText.Size = UDim2.new(1, -80, 1, 0)
    titleText.Position = UDim2.new(0, padding, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = window.title
    titleText.TextColor3 = ThemeEngine.getToken("window.title.fg")
    titleText.TextSize = 14
    titleText.Font = Enum.Font.GothamSemibold
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.ZIndex = 52
    titleText.Parent = titleBar

    -- Window controls
    local controls = Instance.new("Frame")
    controls.Name = "Controls"
    controls.Size = UDim2.new(0, 70, 1, 0)
    controls.Position = UDim2.new(1, -70, 0, 0)
    controls.BackgroundTransparency = 1
    controls.ZIndex = 51
    controls.Parent = titleBar

    local function makeControlBtn(name, text, pos, callback)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(0, 28, 0, 28)
        btn.Position = pos
        btn.BackgroundTransparency = 1
        btn.Text = text
        btn.TextColor3 = ThemeEngine.getToken("window.title.fg")
        btn.TextSize = 14
        btn.Font = Enum.Font.GothamBold
        btn.ZIndex = 52
        btn.Parent = controls
        btn.MouseButton1Click:Connect(callback)
        btn.MouseEnter:Connect(function()
            btn.TextColor3 = ThemeEngine.getToken("window.close.hover") or ThemeEngine.getToken("text.accent")
        end)
        btn.MouseLeave:Connect(function()
            btn.TextColor3 = ThemeEngine.getToken("window.title.fg")
        end)
        return btn
    end

    makeControlBtn("Minimize", "—", UDim2.new(0, 0, 0.5, -14), function() window.minimize() end)
    makeControlBtn("Maximize", "□", UDim2.new(0, 28, 0.5, -14), function()
        if window.maximized then window.restore() else window.maximize() end
    end)
    makeControlBtn("Close", "✕", UDim2.new(0, 56, 0.5, -14), function() window.close() end)

    -- Drag handling
    local dragging = false
    local dragStart, startPos

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = window.gui.Position
        end
    end)

    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            window.savedPosition = window.gui.Position
            window.savedSize = window.gui.Size
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            window.gui.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- Content area
    window.container = Instance.new("Frame")
    window.container.Name = "Container"
    window.container.Size = UDim2.new(1, 0, 1, -36)
    window.container.Position = UDim2.new(0, 0, 0, 36)
    window.container.BackgroundTransparency = 1
    window.container.ZIndex = 50
    window.container.Parent = window.gui

    -- Sidebar
    local rawTheme = ThemeEngine.currentRawTheme
    local sidebarWidth = (rawTheme and rawTheme.layout and rawTheme.layout.sidebar == "left") and 160 or 0
    window.sidebar = Instance.new("Frame")
    window.sidebar.Name = "Sidebar"
    window.sidebar.Size = UDim2.new(0, sidebarWidth, 1, 0)
    window.sidebar.BackgroundColor3 = ThemeEngine.getToken("sidebar.bg")
    window.sidebar.BorderSizePixel = 0
    window.sidebar.ZIndex = 50
    window.sidebar.Visible = sidebarWidth > 0
    window.sidebar.Parent = window.container

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.FillDirection = Enum.FillDirection.Vertical
    sidebarLayout.Padding = UDim.new(0, 4)
    sidebarLayout.Parent = window.sidebar

    local sidebarPadding = Instance.new("UIPadding")
    sidebarPadding.PaddingTop = UDim.new(0, 8)
    sidebarPadding.PaddingLeft = UDim.new(0, 8)
    sidebarPadding.PaddingRight = UDim.new(0, 8)
    sidebarPadding.Parent = window.sidebar

    -- Content frame
    window.contentArea = Instance.new("Frame")
    window.contentArea.Name = "ContentArea"
    window.contentArea.Size = UDim2.new(1, -sidebarWidth, 1, 0)
    window.contentArea.Position = UDim2.new(0, sidebarWidth, 0, 0)
    window.contentArea.BackgroundTransparency = 1
    window.contentArea.ZIndex = 50
    window.contentArea.Parent = window.container

    -- Register with WM
    Shell.registerWindow(window)

    -- Keybind for toggle
    if window.keybind and window.keybind ~= "None" then
        local keyCode = Enum.KeyCode[window.keybind]
        if keyCode then
            UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.KeyCode == keyCode then
                    if window.minimized then
                        window.restore()
                    else
                        window.minimize()
                    end
                end
            end)
        end
    end

    -- Window methods
    function window:Tab(title)
        local tab = {
            title = title,
            sections = {},
            button = nil,
            contentFrame = nil,
            window = self
        }
        tab.Section = function(self2, secTitle) return createSection(tab, secTitle) end

        -- Tab button in sidebar
        tab.button = Instance.new("TextButton")
        tab.button.Name = "Tab_" .. title
        tab.button.Size = UDim2.new(1, 0, 0, 36)
        tab.button.BackgroundTransparency = 1
        tab.button.Text = title
        tab.button.TextColor3 = ThemeEngine.getToken("tab.idle.fg")
        tab.button.TextSize = 13
        tab.button.Font = Enum.Font.GothamMedium
        tab.button.TextXAlignment = Enum.TextXAlignment.Left
        tab.button.ZIndex = 51
        tab.button.Parent = self.sidebar

        local tabPadding = Instance.new("UIPadding")
        tabPadding.PaddingLeft = UDim.new(0, 12)
        tabPadding.Parent = tab.button

        -- Tab content frame
        tab.contentFrame = Instance.new("ScrollingFrame")
        tab.contentFrame.Name = "Content_" .. title
        tab.contentFrame.Size = UDim2.new(1, 0, 1, 0)
        tab.contentFrame.BackgroundTransparency = 1
        tab.contentFrame.BorderSizePixel = 0
        tab.contentFrame.ScrollBarThickness = 4
        tab.contentFrame.ScrollBarImageColor3 = ThemeEngine.getToken("tab.active")
        tab.contentFrame.Visible = false
        tab.contentFrame.ZIndex = 50
        tab.contentFrame.Parent = self.contentArea

        local contentLayout = Instance.new("UIListLayout")
        contentLayout.FillDirection = Enum.FillDirection.Vertical
        contentLayout.Padding = UDim.new(0, 8)
        contentLayout.Parent = tab.contentFrame

        local contentPadding = Instance.new("UIPadding")
        contentPadding.PaddingTop = UDim.new(0, padding)
        contentPadding.PaddingLeft = UDim.new(0, padding)
        contentPadding.PaddingRight = UDim.new(0, padding)
        contentPadding.PaddingBottom = UDim.new(0, padding)
        contentPadding.Parent = tab.contentFrame

        -- Tab click handler
        tab.button.MouseButton1Click:Connect(function()
            self:SelectTab(title)
        end)

        -- Hover effects
        tab.button.MouseEnter:Connect(function()
            if self.currentTab ~= title then
                tab.button.BackgroundTransparency = 0.8
                tab.button.BackgroundColor3 = ThemeEngine.getToken("tab.hover")
            end
        end)
        tab.button.MouseLeave:Connect(function()
            if self.currentTab ~= title then
                tab.button.BackgroundTransparency = 1
            end
        end)

        self.tabs[title] = tab

        -- Auto-select first tab
        if not self.currentTab then
            self:SelectTab(title)
        end

        return tab
    end

    function window:SelectTab(title)
        for tName, tab in pairs(self.tabs) do
            local isActive = tName == title
            tab.contentFrame.Visible = isActive
            if tab.button then
                tab.button.TextColor3 = isActive and ThemeEngine.getToken("tab.active") or ThemeEngine.getToken("tab.idle.fg")
                tab.button.BackgroundTransparency = isActive and 0.2 or 1
                tab.button.BackgroundColor3 = isActive and ThemeEngine.getToken("tab.active") or Color3.new(0,0,0)
            end
        end
        self.currentTab = title
    end

    function window:Minimize()
        self.minimized = true
        self.gui.Visible = false
        Shell.minimizeWindow(self.id)
    end

    function window:Maximize()
        self.maximized = true
        local mbHeight = Shell.getMenuBarHeight()
        local dockHeight = Shell.getDockHeight()
        tween(self.gui, {Size = UDim2.new(1, 0, 1, -mbHeight - dockHeight), Position = UDim2.new(0, 0, 0, mbHeight)}, 0.15)
    end

    function window:Restore()
        self.maximized = false
        self.minimized = false
        self.gui.Visible = true
        if self.savedPosition and self.savedSize then
            tween(self.gui, {Position = self.savedPosition, Size = self.savedSize}, 0.15)
        end
        Shell.focusWindow(self.id)
    end

    function window:Focus()
        Shell.focusWindow(self.id)
    end

    function window:Close()
        if self.onClose then self.onClose() end
        Shell.unregisterWindow(self.id)
        self.gui:Destroy()
        TempleApi._windows[id] = nil
    end

    function window:Snap(dir)
        Shell.snapWindow(self.id, dir)
    end

    function window:SetWorkspace(ws)
        Shell.setWindowWorkspace(self.id, ws)
    end

    function window:OnClosed(fn)
        self.onClose = fn
    end

    function window:OnFocusChanged(fn)
        self.onFocus = fn
    end

    function window:Destroy()
        self:Close()
    end

    TempleApi._windows[id] = window
    return window
end

-- ============================================================
-- UI: WIDGETS (Tab methods)
-- ============================================================
local function createWidget(tab, widgetType, options)
    options = options or {}
    local parent = tab.contentFrame
    local elemRadius = themeElemRadius(8)
    local elemPadding = themeElemPadding(8)

    local frame = Instance.new("Frame")
    frame.Name = widgetType .. "_" .. (options.flag or HttpService:GenerateGUID(false):sub(1,8))
    frame.Size = UDim2.new(1, 0, 0, 0) -- auto height
    frame.BackgroundColor3 = ThemeEngine.getToken("element.bg")
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = 0.3
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.ZIndex = 51

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, elemRadius)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = ThemeEngine.getToken("element.border")
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = frame

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, elemPadding)
    padding.PaddingBottom = UDim.new(0, elemPadding)
    padding.PaddingLeft = UDim.new(0, elemPadding)
    padding.PaddingRight = UDim.new(0, elemPadding)
    padding.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 6)
    layout.Parent = frame

    -- Title/Label
    if options.title then
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 18)
        label.BackgroundTransparency = 1
        label.Text = options.title
        label.TextColor3 = ThemeEngine.getToken("text.primary")
        label.TextSize = 13
        label.Font = Enum.Font.GothamSemibold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 52
        label.Parent = frame
    end

    if options.description then
        local desc = Instance.new("TextLabel")
        desc.Size = UDim2.new(1, 0, 0, 14)
        desc.BackgroundTransparency = 1
        desc.Text = options.description
        desc.TextColor3 = ThemeEngine.getToken("text.muted")
        desc.TextSize = 11
        desc.Font = Enum.Font.Gotham
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.TextWrapped = true
        desc.ZIndex = 52
        desc.Parent = frame
    end

    frame.Parent = parent
    table.insert(tab.window._elements, frame)
    return frame
end

createSection = function(self, title)
    local section = {
        title = title,
        tab = self,
        elements = {}
    }

    local frame = Instance.new("Frame")
    frame.Name = "Section_" .. title
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.BackgroundTransparency = 1
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.ZIndex = 50
    frame.Parent = self.contentFrame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 8)
    layout.Parent = frame

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 20)
    header.BackgroundTransparency = 1
    header.Text = title
    header.TextColor3 = ThemeEngine.getToken("section.header.fg")
    header.TextSize = 12
    header.Font = Enum.Font.GothamBold
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.ZIndex = 51
    header.Parent = frame

    section.frame = frame

    -- Widget creators
    local function makeWidget(widgetType, options)
        options = options or {}
        local frame = createWidget(self, widgetType, options)
        table.insert(section.elements, frame)
        return frame
    end

    -- Toggle
    function section:Toggle(options)
        options = options or {}
        local frame = makeWidget("Toggle", options)

        local toggleFrame = Instance.new("Frame")
        toggleFrame.Size = UDim2.new(0, 44, 0, 24)
        toggleFrame.Position = UDim2.new(1, -44, 0, 0)
        toggleFrame.BackgroundColor3 = ThemeEngine.getToken("toggle.track.off")
        toggleFrame.BorderSizePixel = 0
        toggleFrame.ZIndex = 52
        toggleFrame.Parent = frame

        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(1, 0)
        toggleCorner.Parent = toggleFrame

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 20, 0, 20)
        knob.Position = UDim2.new(0, 2, 0.5, -10)
        knob.BackgroundColor3 = ThemeEngine.getToken("toggle.knob")
        knob.BorderSizePixel = 0
        knob.ZIndex = 53
        knob.Parent = toggleFrame

        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(1, 0)
        knobCorner.Parent = knob

        local state = options.default or false
        local flag = options.flag

        local function updateVisual()
            local targetColor = state and ThemeEngine.getToken("toggle.track.on") or ThemeEngine.getToken("toggle.track.off")
            local targetPos = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
            tween(toggleFrame, {BackgroundColor3 = targetColor}, 0.15)
            tween(knob, {Position = targetPos}, 0.15)
        end

        updateVisual()

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.ZIndex = 54
        btn.Parent = toggleFrame

        btn.MouseButton1Click:Connect(function()
            state = not state
            updateVisual()
            if flag then TempleApi._flags[flag] = state end
            if options.callback then pcall(options.callback, state) end
        end)

        if flag then TempleApi._flags[flag] = state end

        return {
            Get = function() return state end,
            Set = function(v)
                state = v
                updateVisual()
                if flag then TempleApi._flags[flag] = state end
            end
        }
    end

    -- Slider
    function section:Slider(options)
        options = options or {}
        local frame = makeWidget("Slider", options)

        local min = options.min or 0
        local max = options.max or 100
        local step = options.step or 1
        local value = options.default or min
        local flag = options.flag
        local suffix = options.suffix or ""

        local sliderBg = Instance.new("Frame")
        sliderBg.Size = UDim2.new(1, 0, 0, 20)
        sliderBg.BackgroundColor3 = ThemeEngine.getToken("element.border")
        sliderBg.BorderSizePixel = 0
        sliderBg.ZIndex = 52
        sliderBg.Parent = frame

        local bgCorner = Instance.new("UICorner")
        bgCorner.CornerRadius = UDim.new(1, 0)
        bgCorner.Parent = sliderBg

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = ThemeEngine.getToken("slider.fill")
        fill.BorderSizePixel = 0
        fill.ZIndex = 53
        fill.Parent = sliderBg

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = fill

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 20, 0, 20)
        knob.Position = UDim2.new(fill.Size.X.Scale, -10, 0.5, -10)
        knob.BackgroundColor3 = ThemeEngine.getToken("slider.knob")
        knob.BorderSizePixel = 0
        knob.ZIndex = 54
        knob.Parent = sliderBg

        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(1, 0)
        knobCorner.Parent = knob

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.new(0, 50, 1, 0)
        valueLabel.Position = UDim2.new(1, -55, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = tostring(value) .. suffix
        valueLabel.TextColor3 = ThemeEngine.getToken("text.muted")
        valueLabel.TextSize = 11
        valueLabel.Font = Enum.Font.Gotham
        valueLabel.ZIndex = 53
        valueLabel.Parent = sliderBg

        local dragging = false

        local function updateFromInput(input)
            local relX = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            local newValue = math.floor(min + relX * (max - min) + step/2)
            newValue = math.clamp(newValue, min, max)
            if newValue ~= value then
                value = newValue
                local scale = (value - min) / (max - min)
                fill.Size = UDim2.new(scale, 0, 1, 0)
                knob.Position = UDim2.new(scale, -10, 0.5, -10)
                valueLabel.Text = tostring(value) .. suffix
                if flag then TempleApi._flags[flag] = value end
                if options.callback then pcall(options.callback, value) end
            end
        end

        sliderBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                updateFromInput(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateFromInput(input)
            end
        end)

        if flag then TempleApi._flags[flag] = value end

        return {
            Get = function() return value end,
            Set = function(v)
                value = math.clamp(v, min, max)
                local scale = (value - min) / (max - min)
                fill.Size = UDim2.new(scale, 0, 1, 0)
                knob.Position = UDim2.new(scale, -10, 0.5, -10)
                valueLabel.Text = tostring(value) .. suffix
                if flag then TempleApi._flags[flag] = value end
            end
        }
    end

    -- Dropdown
    function section:Dropdown(options)
        options = options or {}
        local frame = makeWidget("Dropdown", options)

        local values = options.values or {}
        local value = options.default or values[1]
        local flag = options.flag
        local multi = options.multi or false

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.BackgroundColor3 = ThemeEngine.getToken("dropdown.bg")
        btn.BorderSizePixel = 0
        btn.Text = multi and "Select..." or tostring(value)
        btn.TextColor3 = ThemeEngine.getToken("text.primary")
        btn.TextSize = 13
        btn.Font = Enum.Font.Gotham
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.ZIndex = 52
        btn.Parent = frame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn

        local btnPadding = Instance.new("UIPadding")
        btnPadding.PaddingLeft = UDim.new(0, 10)
        btnPadding.Parent = btn

        local arrow = Instance.new("TextLabel")
        arrow.Size = UDim2.new(0, 20, 1, 0)
        arrow.Position = UDim2.new(1, -24, 0, 0)
        arrow.BackgroundTransparency = 1
        arrow.Text = "▼"
        arrow.TextColor3 = ThemeEngine.getToken("text.muted")
        arrow.TextSize = 12
        arrow.Font = Enum.Font.Gotham
        arrow.ZIndex = 53
        arrow.Parent = btn

        local dropdownOpen = false
        local dropdownList = nil

        local function closeDropdown()
            if dropdownList then dropdownList:Destroy() dropdownList = nil end
            dropdownOpen = false
            arrow.Text = "▼"
        end

        btn.MouseButton1Click:Connect(function()
            if dropdownOpen then
                closeDropdown()
            else
                dropdownOpen = true
                arrow.Text = "▲"

                dropdownList = Instance.new("Frame")
                dropdownList.Size = UDim2.new(1, 0, 0, math.min(#values * 30, 200))
                dropdownList.Position = UDim2.new(0, 0, 1, 4)
                dropdownList.BackgroundColor3 = ThemeEngine.getToken("dropdown.bg")
                dropdownList.BorderSizePixel = 0
                dropdownList.ZIndex = 100
                dropdownList.Parent = frame

                local listCorner = Instance.new("UICorner")
                listCorner.CornerRadius = UDim.new(0, 6)
                listCorner.Parent = dropdownList

                local listStroke = Instance.new("UIStroke")
                listStroke.Color = ThemeEngine.getToken("element.border")
                listStroke.Thickness = 1
                listStroke.Parent = dropdownList

                local listLayout = Instance.new("UIListLayout")
                listLayout.FillDirection = Enum.FillDirection.Vertical
                listLayout.Parent = dropdownList

                for _, v in ipairs(values) do
                    local item = Instance.new("TextButton")
                    item.Size = UDim2.new(1, 0, 0, 30)
                    item.BackgroundTransparency = 1
                    item.Text = tostring(v)
                    item.TextColor3 = ThemeEngine.getToken("text.primary")
                    item.TextSize = 13
                    item.Font = Enum.Font.Gotham
                    item.TextXAlignment = Enum.TextXAlignment.Left
                    item.ZIndex = 101
                    item.Parent = dropdownList

                    local itemPadding = Instance.new("UIPadding")
                    itemPadding.PaddingLeft = UDim.new(0, 10)
                    itemPadding.Parent = item

                    item.MouseEnter:Connect(function()
                        item.BackgroundTransparency = 0.8
                        item.BackgroundColor3 = ThemeEngine.getToken("dropdown.item.hover")
                    end)
                    item.MouseLeave:Connect(function()
                        item.BackgroundTransparency = 1
                    end)

                    item.MouseButton1Click:Connect(function()
                        if multi then
                            -- Multi-select not fully implemented
                        else
                            value = v
                            btn.Text = tostring(value)
                            if flag then TempleApi._flags[flag] = value end
                            if options.callback then pcall(options.callback, value) end
                        end
                        closeDropdown()
                    end)
                end
            end
        end)

        -- Close on outside click
        UserInputService.InputBegan:Connect(function(input)
            if dropdownOpen and input.UserInputType == Enum.UserInputType.MouseButton1 then
                local mousePos = UserInputService:GetMouseLocation()
                local absPos = dropdownList.AbsolutePosition
                local absSize = dropdownList.AbsoluteSize
                if mousePos.X < absPos.X or mousePos.X > absPos.X + absSize.X or
                   mousePos.Y < absPos.Y or mousePos.Y > absPos.Y + absSize.Y then
                    closeDropdown()
                end
            end
        end)

        if flag then TempleApi._flags[flag] = value end

        return {
            Get = function() return value end,
            Set = function(v) value = v; btn.Text = tostring(v); if flag then TempleApi._flags[flag] = v end end,
            SetValues = function(v) values = v end
        }
    end

    -- Button
    function section:Button(options)
        options = options or {}
        local frame = makeWidget("Button", options)

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.BackgroundColor3 = options.danger and ThemeEngine.getToken("button.danger.bg") or ThemeEngine.getToken("button.primary.bg")
        btn.BorderSizePixel = 0
        btn.Text = options.title or "Button"
        btn.TextColor3 = options.danger and Color3.new(1,1,1) or ThemeEngine.getToken("button.primary.fg")
        btn.TextSize = 13
        btn.Font = Enum.Font.GothamSemibold
        btn.ZIndex = 52
        btn.Parent = frame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            if options.callback then pcall(options.callback) end
        end)

        return btn
    end

    -- Input
    function section:Input(options)
        options = options or {}
        local frame = makeWidget("Input", options)

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, 0, 0, 32)
        box.BackgroundColor3 = ThemeEngine.getToken("input.bg")
        box.BorderSizePixel = 0
        box.Text = options.default or ""
        box.PlaceholderText = options.placeholder or ""
        box.PlaceholderColor3 = ThemeEngine.getToken("input.placeholder")
        box.TextColor3 = ThemeEngine.getToken("text.primary")
        box.TextSize = 13
        box.Font = Enum.Font.Gotham
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.ClearTextOnFocus = false
        box.ZIndex = 52
        box.Parent = frame

        local boxCorner = Instance.new("UICorner")
        boxCorner.CornerRadius = UDim.new(0, 6)
        boxCorner.Parent = box

        local boxPadding = Instance.new("UIPadding")
        boxPadding.PaddingLeft = UDim.new(0, 10)
        boxPadding.Parent = box

        local flag = options.flag
        if flag then TempleApi._flags[flag] = options.default or "" end

        box.FocusLost:Connect(function(enterPressed)
            if flag then TempleApi._flags[flag] = box.Text end
            if options.callback then pcall(options.callback, box.Text, enterPressed) end
        end)

        return {
            Get = function() return box.Text end,
            Set = function(v) box.Text = v; if flag then TempleApi._flags[flag] = v end end
        }
    end

    -- Keybind
    function section:Keybind(options)
        options = options or {}
        local frame = makeWidget("Keybind", options)

        local value = options.default
        local mode = options.mode or "toggle"
        local flag = options.flag
        local binding = false

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 100, 0, 28)
        btn.Position = UDim2.new(1, -100, 0, 0)
        btn.BackgroundColor3 = ThemeEngine.getToken("keybind.bg")
        btn.BorderSizePixel = 0
        btn.Text = value and value.Name or "None"
        btn.TextColor3 = ThemeEngine.getToken("text.primary")
        btn.TextSize = 12
        btn.Font = Enum.Font.Gotham
        btn.ZIndex = 52
        btn.Parent = frame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            binding = true
            btn.Text = "..."
            btn.TextColor3 = ThemeEngine.getToken("text.accent")
        end)

        UserInputService.InputBegan:Connect(function(input, processed)
            if binding and input.UserInputType == Enum.UserInputType.Keyboard then
                binding = false
                value = input.KeyCode
                btn.Text = value.Name
                btn.TextColor3 = ThemeEngine.getToken("text.primary")
                if flag then TempleApi._flags[flag] = value end
            elseif not binding and value and input.KeyCode == value then
                if mode == "toggle" then
                    -- Toggle logic handled by script
                end
                if options.callback then pcall(options.callback, input.KeyCode) end
            end
        end)

        if flag then TempleApi._flags[flag] = value end

        return {
            Get = function() return value end,
            Set = function(v) value = v; btn.Text = v and v.Name or "None"; if flag then TempleApi._flags[flag] = v end end
        }
    end

    -- Label
    function section:Label(options)
        options = options or {}
        local frame = makeWidget("Label", options)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 18)
        label.BackgroundTransparency = 1
        label.Text = options.text or ""
        label.TextColor3 = ThemeEngine.getToken("text.primary")
        label.TextSize = 13
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextWrapped = true
        label.ZIndex = 52
        label.Parent = frame

        return {
            Set = function(t) label.Text = t end
        }
    end

    -- Paragraph
    function section:Paragraph(options)
        options = options or {}
        local frame = makeWidget("Paragraph", options)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = options.text or ""
        label.TextColor3 = ThemeEngine.getToken("text.muted")
        label.TextSize = 12
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextWrapped = true
        label.AutomaticSize = Enum.AutomaticSize.Y
        label.ZIndex = 52
        label.Parent = frame

        return {
            Set = function(t) label.Text = t end
        }
    end

    -- List
    function section:List(options)
        options = options or {}
        local frame = makeWidget("List", options)
        -- Simplified implementation
        return frame
    end

    -- Colorpicker (basic)
    function section:Colorpicker(options)
        options = options or {}
        local frame = makeWidget("Colorpicker", options)
        -- TODO: Full color picker
        return frame
    end

    -- Table
    function section:Table(options)
        options = options or {}
        local frame = makeWidget("Table", options)
        -- TODO: Table implementation
        return frame
    end

    -- Image
    function section:Image(options)
        options = options or {}
        local frame = makeWidget("Image", options)

        local img = Instance.new("ImageLabel")
        img.Size = options.size or UDim2.new(1, 0, 0, 200)
        img.BackgroundTransparency = 1
        img.Image = options.src or ""
        img.ScaleType = Enum.ScaleType.Fit
        img.ZIndex = 52
        img.Parent = frame

        return {
            SetImage = function(src) img.Image = src end
        }
    end

    return section
end

-- ============================================================
-- FLAGS SYSTEM
-- ============================================================
TempleApi.Flags = setmetatable({}, {
    __index = function(_, key) return TempleApi._flags[key] end,
    __newindex = function(_, key, value) TempleApi._flags[key] = value end
})

function TempleApi:GetFlag(key, default)
    return TempleApi._flags[key] ~= nil and TempleApi._flags[key] or default
end

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
function TempleApi.Notify(options)
    options = options or {}
    local title = options.title or "Notification"
    local content = options.content or ""
    local duration = options.duration or Config.get("behavior.notify_default.duration") or 5
    local level = options.level or "info"
    local themeRole = options.theme_role or "notification.bg"

    -- Create notification frame
    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(0, 320, 0, 0)
    notif.BackgroundColor3 = ThemeEngine.getToken(themeRole)
    notif.BackgroundTransparency = 0.1
    notif.BorderSizePixel = 0
    notif.AutomaticSize = Enum.AutomaticSize.Y
    notif.ZIndex = 200
    notif.Parent = Shell.screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = notif

    local stroke = Instance.new("UIStroke")
    stroke.Color = ThemeEngine.getToken("notification.level." .. level) or ThemeEngine.getToken("element.border")
    stroke.Thickness = 2
    stroke.Parent = notif

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 12)
    padding.PaddingBottom = UDim.new(0, 12)
    padding.PaddingLeft = UDim.new(0, 14)
    padding.PaddingRight = UDim.new(0, 14)
    padding.Parent = notif

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 6)
    layout.Parent = notif

    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 20)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = ThemeEngine.getToken("notification.fg")
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 201
    titleLabel.Parent = notif

    -- Content
    local contentLabel = Instance.new("TextLabel")
    contentLabel.Size = UDim2.new(1, 0, 0, 0)
    contentLabel.BackgroundTransparency = 1
    contentLabel.Text = content
    contentLabel.TextColor3 = ThemeEngine.getToken("notification.fg")
    contentLabel.TextSize = 13
    contentLabel.Font = Enum.Font.Gotham
    contentLabel.TextXAlignment = Enum.TextXAlignment.Left
    contentLabel.TextWrapped = true
    contentLabel.AutomaticSize = Enum.AutomaticSize.Y
    contentLabel.ZIndex = 201
    contentLabel.Parent = notif

    -- Position based on config
    local pos = Config.get("behavior.notify_default.position") or "top-right"
    local viewport = Camera.ViewportSize
    local mbHeight = Shell.getMenuBarHeight()
    local dockHeight = Shell.getDockHeight()

    local anchor, position
    if pos == "top-right" then
        anchor = Vector2.new(1, 0)
        position = UDim2.new(1, -20, 0, mbHeight + 20)
    elseif pos == "top-left" then
        anchor = Vector2.new(0, 0)
        position = UDim2.new(0, 20, 0, mbHeight + 20)
    elseif pos == "bottom-right" then
        anchor = Vector2.new(1, 1)
        position = UDim2.new(1, -20, 1, -dockHeight - 20)
    elseif pos == "bottom-left" then
        anchor = Vector2.new(0, 1)
        position = UDim2.new(0, 20, 1, -dockHeight - 20)
    else -- center
        anchor = Vector2.new(0.5, 0.5)
        position = UDim2.new(0.5, 0, 0.5, 0)
    end

    notif.AnchorPoint = anchor
    notif.Position = position

    -- Animate in
    notif.Size = UDim2.new(0, 320, 0, 0)
    notif.BackgroundTransparency = 1
    local tweenIn = TweenService:Create(notif, TweenInfo.new(0.3), {BackgroundTransparency = 0.1})
    tweenIn:Play()

    -- Auto-dismiss
    task.delay(duration, function()
        if notif and notif.Parent then
            local tweenOut = TweenService:Create(notif, TweenInfo.new(0.3), {BackgroundTransparency = 1})
            tweenOut:Play()
            tweenOut.Completed:Wait()
            notif:Destroy()
        end
    end)

    return notif
end

-- ============================================================
-- KEYBINDS
-- ============================================================
function TempleApi.Bind(options)
    options = options or {}
    local name = options.name
    local default = options.default
    local mode = options.mode or "toggle"
    local registry = options.registry or "global"
    local callback = options.callback

    local bind = {
        name = name,
        key = default,
        mode = mode,
        callback = callback,
        registry = registry
    }

    TempleApi._keybinds[name] = bind

    if default then
        local keyCode = default
        if type(default) == "string" then
            keyCode = Enum.KeyCode[default]
        end

        UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.KeyCode == keyCode then
                if callback then pcall(callback, input) end
            end
        end)
    end

    return bind
end

function TempleApi.Unbind(name)
    TempleApi._keybinds[name] = nil
end

-- ============================================================
-- COMMANDS (Command Palette)
-- ============================================================
function TempleApi.Command(options)
    options = options or {}
    local cmd = {
        name = options.name,
        category = options.category or "Custom",
        callback = options.callback
    }
    table.insert(TempleApi._commands, cmd)
    return cmd
end

-- ============================================================
-- THEME API
-- ============================================================
TempleApi.Theme = {}

function TempleApi.Theme:get(role)
    return ThemeEngine.getToken(role)
end

function TempleApi.Theme:set(role, value)
    -- Local override (doesn't save to file)
    ThemeEngine.tokens[role] = value
    ThemeEngine.notifySubscribers()
end

function TempleApi.Theme:apply(name)
    return ThemeEngine.setTheme(name)
end

function TempleApi.Theme:list()
    return ThemeEngine.listThemes()
end

function TempleApi.Theme:onChange(callback)
    return ThemeEngine.subscribe(callback)
end

-- ============================================================
-- CORE FUNCTIONS EXPOSURE
-- ============================================================
TempleApi.Core = {
    list = Core.listModules,
    enable = Core.enable,
    disable = Core.disable,
    toggle = Core.toggle,
    setParam = Core.setParam,
    getParam = Core.getParam,
    getParams = Core.getParams,
    isEnabled = Core.isEnabled
}

-- Individual function namespaces
for id, def in pairs(Core.modules) do
    local name = id:sub(1,1):upper() .. id:sub(2)
    TempleApi[name] = {
        Enable = function() return Core.enable(id) end,
        Disable = function() return Core.disable(id) end,
        Toggle = function() return Core.toggle(id) end,
        Set = function(param, value) return Core.setParam(id, param, value) end,
        Get = function(param) return Core.getParam(id, param) end,
        GetParams = function() return Core.getParams(id) end,
        IsEnabled = function() return Core.isEnabled(id) end
    }
end

-- ============================================================
-- EXECUTOR FACADE
-- ============================================================
TempleApi.Executor = {
    name = function() return Executor.info.name end,
    http = Executor.http,
    saveinstance = function() return Executor.info.raw_globals.saveinstance and pcall(Executor.info.raw_globals.saveinstance) end,
    queue_on_teleport = Executor.queue_on_teleport,
    get_clipboard = Executor.get_clipboard,
    fs_write = function(path, content)
        -- Sandbox to workspace
        local workspacePath = Config.get("paths.workspace") or "workspace"
        if path:find("..") then return false, "Path traversal not allowed" end
        return Executor.fs_write(workspacePath .. "/" .. path, content)
    end,
    fs_read = function(path)
        local workspacePath = Config.get("paths.workspace") or "workspace"
        if path:find("..") then return false, "Path traversal not allowed" end
        return Executor.fs_read(workspacePath .. "/" .. path)
    end,
    supports = Executor.supports
}

-- ============================================================
-- PLUGIN SYSTEM
-- ============================================================
function TempleApi.Plugin(def)
    def = def or {}
    local plugin = {
        name = def.name,
        version = def.version or "1.0.0",
        onLoad = def.onLoad,
        onUnload = def.onUnload
    }

    if plugin.onLoad then
        pcall(plugin.onLoad, TempleApi)
    end

    return plugin
end

-- ============================================================
-- CONFIG PERSISTENCE FOR SCRIPTS
-- ============================================================
TempleApi.Config = {}

function TempleApi.Config:save(scriptId)
    local data = {}
    -- Collect flags for this script (could namespace by scriptId)
    for k, v in pairs(TempleApi._flags) do
        if k:sub(1, #scriptId + 1) == scriptId .. "_" then
            data[k:sub(#scriptId + 2)] = v
        end
    end
    local Executor = require(script.Parent.executor)
    local path = "cache/configs/" .. scriptId .. ".json"
    pcall(Executor.fs_write, path, HttpService:JSONEncode(data))
end

function TempleApi.Config:load(scriptId)
    local Executor = require(script.Parent.executor)
    local path = "cache/configs/" .. scriptId .. ".json"
    local ok, content = Executor.fs_read(path)
    if ok and content then
        local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
        if ok2 and data then
            for k, v in pairs(data) do
                TempleApi._flags[scriptId .. "_" .. k] = v
            end
            return data
        end
    end
    return {}
end

-- ============================================================
-- WEBHOOK
-- ============================================================
TempleApi.Webhook = {}

function TempleApi.Webhook:send(url, payload)
    local body = HttpService:JSONEncode(payload)
    local res = Executor.http(url, {
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = body
    })
    return res.Success, res
end

-- ============================================================
-- HUB / GIT
-- ============================================================
TempleApi.Hub = {
    search = function(query)
        -- TODO: Implement hub search
        return {}
    end,
    run = function(name)
        -- TODO: Run script from hub
    end,
    pull = function(repoOrUrl)
        -- TODO: Pull from git registry
    end
}

function TempleApi.Update()
    -- Trigger self-update
    -- TODO: Implement
end

-- ============================================================
-- SCRIPT CONTEXT
-- ============================================================
TempleApi.Script = {}

function TempleApi.Script:id()
    return TempleApi._scriptContext or "unknown"
end

function TempleApi.Script:name()
    return TempleApi._scriptContext or "unknown"
end

function TempleApi.Script:SetAutoload(bool)
    -- Write to config
    local plugins = Config.get("plugins") or {}
    for _, p in ipairs(plugins) do
        if p.name == TempleApi._scriptContext then
            p.autoload = bool
            break
        end
    end
    Config.set("plugins", plugins)
    Config.save()
end

function TempleApi.Script:Reload()
    -- TODO: Implement script reload
end

-- ============================================================
-- IY COMPATIBILITY LAYER (v1.1)
-- ============================================================
function TempleApi.IYCompat()
    -- Returns an object with Infinity Yield compatible API
    -- TODO: Implement full IY compat
    return {
        CreateWindow = function(opts) return TempleApi.Window(opts) end,
        Notify = TempleApi.Notify,
        -- ... more compat methods
    }
end

return TempleApi