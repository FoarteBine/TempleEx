--[[
    TempleEx Core Function Implementations
    Fly, Speed, InfiniteJump, Noclip, ESP, Fullbright, Hitbox, Freecam, etc.
]]

local Core = require(script.Parent.core)
local Executor = require(script.Parent.executor)
local Log = require(script.Parent.log)
local ThemeEngine = require(script.Parent.theme)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Utility: get character and humanoid
local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ============================================================
-- FLY
-- ============================================================
local flyBodyVelocity = nil
local flyBodyGyro = nil
local flyConnection = nil
local flyKeys = {W=false, A=false, S=false, D=false, Space=false, LeftControl=false}

Core.register({
    id = "fly",
    title = "Fly",
    icon = "✈",
    category = "Movement",
    keybind = "E",
    params = {
        speed = { type = "number", default = 50, min = 1, max = 500, suffix = " studs/s" },
        verticalSpeed = { type = "number", default = 50, min = 1, max = 500, suffix = " studs/s" },
        mode = { type = "string", default = "BodyVelocity", options = {"BodyVelocity", "LinearVelocity", "CFrame"} }
    },
    onEnable = function(params)
        local char = getCharacter()
        local root = getRootPart()
        local humanoid = getHumanoid()
        if not root or not humanoid then
            return false, "Character not loaded"
        end

        humanoid.PlatformStand = true

        local mode = params.mode or "BodyVelocity"

        if mode == "BodyVelocity" then
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            flyBodyVelocity.Velocity = Vector3.zero
            flyBodyVelocity.Parent = root

            flyBodyGyro = Instance.new("BodyGyro")
            flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            flyBodyGyro.CFrame = root.CFrame
            flyBodyGyro.Parent = root
        elseif mode == "LinearVelocity" then
            -- Modern constraint-based (more stable)
            local attachment = root:FindFirstChild("FlyAttachment") or Instance.new("Attachment")
            attachment.Name = "FlyAttachment"
            attachment.Parent = root

            flyBodyVelocity = Instance.new("LinearVelocity")
            flyBodyVelocity.Attachment0 = attachment
            flyBodyVelocity.MaxForce = math.huge
            flyBodyVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
            flyBodyVelocity.VectorVelocity = Vector3.zero
            flyBodyVelocity.Parent = root

            local alignOrientation = Instance.new("AlignOrientation")
            alignOrientation.Attachment0 = attachment
            alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
            alignOrientation.MaxTorque = math.huge
            alignOrientation.CFrame = root.CFrame
            alignOrientation.Parent = root
            flyBodyGyro = alignOrientation -- reuse variable
        end

        -- Input handling
        flyKeys = {W=false, A=false, S=false, D=false, Space=false, LeftControl=false}
        flyConnection = RunService.RenderStepped:Connect(function()
            local root = getRootPart()
            local humanoid = getHumanoid()
            if not root or not humanoid then return end

            local camCF = Camera.CFrame
            local moveDir = Vector3.zero

            if flyKeys.W then moveDir = moveDir + camCF.LookVector end
            if flyKeys.S then moveDir = moveDir - camCF.LookVector end
            if flyKeys.A then moveDir = moveDir - camCF.RightVector end
            if flyKeys.D then moveDir = moveDir + camCF.RightVector end
            if flyKeys.Space then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if flyKeys.LeftControl then moveDir = moveDir - Vector3.new(0, 1, 0) end

            if moveDir.Magnitude > 0 then
                moveDir = moveDir.Unit
            end

            local horizSpeed = params.speed or 50
            local vertSpeed = params.verticalSpeed or 50

            local velocity = Vector3.new(
                moveDir.X * horizSpeed,
                moveDir.Y * vertSpeed,
                moveDir.Z * horizSpeed
            )

            if flyBodyVelocity then
                if flyBodyVelocity:IsA("BodyVelocity") then
                    flyBodyVelocity.Velocity = velocity
                elseif flyBodyVelocity:IsA("LinearVelocity") then
                    flyBodyVelocity.VectorVelocity = velocity
                end
            end

            if flyBodyGyro then
                if flyBodyGyro:IsA("BodyGyro") then
                    flyBodyGyro.CFrame = CFrame.new(root.Position, root.Position + camCF.LookVector)
                elseif flyBodyGyro:IsA("AlignOrientation") then
                    flyBodyGyro.CFrame = CFrame.new(root.Position, root.Position + camCF.LookVector)
                end
            end
        end)

        -- Keybind listeners
        local function onInputBegan(input, processed)
            if processed then return end
            if input.KeyCode == Enum.KeyCode.W then flyKeys.W = true end
            if input.KeyCode == Enum.KeyCode.A then flyKeys.A = true end
            if input.KeyCode == Enum.KeyCode.S then flyKeys.S = true end
            if input.KeyCode == Enum.KeyCode.D then flyKeys.D = true end
            if input.KeyCode == Enum.KeyCode.Space then flyKeys.Space = true end
            if input.KeyCode == Enum.KeyCode.LeftControl then flyKeys.LeftControl = true end
        end

        local function onInputEnded(input, processed)
            if input.KeyCode == Enum.KeyCode.W then flyKeys.W = false end
            if input.KeyCode == Enum.KeyCode.A then flyKeys.A = false end
            if input.KeyCode == Enum.KeyCode.S then flyKeys.S = false end
            if input.KeyCode == Enum.KeyCode.D then flyKeys.D = false end
            if input.KeyCode == Enum.KeyCode.Space then flyKeys.Space = false end
            if input.KeyCode == Enum.KeyCode.LeftControl then flyKeys.LeftControl = false end
        end

        Core.connections.fly = {
            UserInputService.InputBegan:Connect(onInputBegan),
            UserInputService.InputEnded:Connect(onInputEnded)
        }

        return true
    end,
    onDisable = function()
        -- Cleanup
        if flyConnection then flyConnection:Disconnect() flyConnection = nil end
        if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
        if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end

        local conn = Core.connections.fly
        if conn then
            for _, c in ipairs(conn) do c:Disconnect() end
            Core.connections.fly = nil
        end

        local humanoid = getHumanoid()
        if humanoid then
            humanoid.PlatformStand = false
        end

        -- Remove attachment if created
        local root = getRootPart()
        if root then
            local att = root:FindFirstChild("FlyAttachment")
            if att then att:Destroy() end
        end
    end,
    onParamChange = function(param, value)
        -- Params applied in render loop
    end
})

-- ============================================================
-- SPEED
-- ============================================================
local speedConnection = nil
local originalWalkSpeed = 16

Core.register({
    id = "speed",
    title = "Speed",
    icon = "🏃",
    category = "Movement",
    keybind = "Q",
    params = {
        multiplier = { type = "number", default = 2, min = 0.1, max = 10, suffix = "x" },
        mode = { type = "string", default = "WalkSpeed", options = {"WalkSpeed", "Humanoid", "Velocity"} }
    },
    onEnable = function(params)
        local humanoid = getHumanoid()
        if not humanoid then return false, "No humanoid" end

        originalWalkSpeed = humanoid.WalkSpeed

        local mode = params.mode or "WalkSpeed"
        local mult = params.multiplier or 2

        if mode == "WalkSpeed" then
            speedConnection = RunService.RenderStepped:Connect(function()
                local hum = getHumanoid()
                if hum then
                    hum.WalkSpeed = originalWalkSpeed * mult
                end
            end)
        elseif mode == "Velocity" then
            speedConnection = RunService.Heartbeat:Connect(function()
                local root = getRootPart()
                local hum = getHumanoid()
                if root and hum and hum.MoveDirection.Magnitude > 0 then
                    root.Velocity = hum.MoveDirection * (originalWalkSpeed * mult)
                end
            end)
        end
    end,
    onDisable = function()
        if speedConnection then speedConnection:Disconnect() speedConnection = nil end
        local humanoid = getHumanoid()
        if humanoid then
            humanoid.WalkSpeed = originalWalkSpeed
        end
    end,
    onParamChange = function(param, value)
        -- Applied in loop
    end
})

-- ============================================================
-- INFINITE JUMP
-- ============================================================
local infJumpConnection = nil

Core.register({
    id = "infjump",
    title = "Infinite Jump",
    icon = "🦘",
    category = "Movement",
    keybind = "Space",
    params = {
        delay = { type = "number", default = 0.1, min = 0, max = 1, suffix = "s" }
    },
    onEnable = function(params)
        infJumpConnection = UserInputService.JumpRequest:Connect(function()
            local humanoid = getHumanoid()
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end,
    onDisable = function()
        if infJumpConnection then infJumpConnection:Disconnect() infJumpConnection = nil end
    end
})

-- ============================================================
-- NOCLIP
-- ============================================================
local noclipConnection = nil

Core.register({
    id = "noclip",
    title = "Noclip",
    icon = "👻",
    category = "Movement",
    keybind = "N",
    params = {},
    onEnable = function()
        noclipConnection = RunService.Stepped:Connect(function()
            local char = getCharacter()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end,
    onDisable = function()
        if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
        local char = getCharacter()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
})

-- ============================================================
-- FULLBRIGHT
-- ============================================================
local originalLighting = {}

Core.register({
    id = "fullbright",
    title = "Fullbright",
    icon = "☀",
    category = "Visuals",
    keybind = "B",
    params = {
        brightness = { type = "number", default = 2, min = 0, max = 10 },
        clockTime = { type = "number", default = 14, min = 0, max = 24 },
        fogEnd = { type = "number", default = 100000, min = 100, max = 1000000 }
    },
    onEnable = function(params)
        local Lighting = game:GetService("Lighting")
        originalLighting = {
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd,
            GlobalShadows = Lighting.GlobalShadows,
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient
        }

        Lighting.Brightness = params.brightness or 2
        Lighting.ClockTime = params.clockTime or 14
        Lighting.FogEnd = params.fogEnd or 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)

        -- Keep it applied
        Core.connections.fullbright = Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
            if Core.active.fullbright then
                Lighting.Brightness = params.brightness or 2
            end
        end)
    end,
    onDisable = function()
        local Lighting = game:GetService("Lighting")
        for k, v in pairs(originalLighting) do
            Lighting[k] = v
        end
        local conn = Core.connections.fullbright
        if conn then conn:Disconnect() Core.connections.fullbright = nil end
    end,
    onParamChange = function(param, value)
        local Lighting = game:GetService("Lighting")
        if param == "brightness" then Lighting.Brightness = value end
        if param == "clockTime" then Lighting.ClockTime = value end
        if param == "fogEnd" then Lighting.FogEnd = value end
    end
})

-- ============================================================
-- ESP (Basic - Boxes, Names, Tracers)
-- ============================================================
local espObjects = {}
local espConnection = nil

local function createESPForPlayer(player)
    if player == LocalPlayer then return end
    local function onCharacterAdded(char)
        task.wait(0.5)
        if not Core.active.esp then return end
        createESPForPlayer(player) -- recreate
    end
    player.CharacterAdded:Connect(onCharacterAdded)

    local char = player.Character
    if not char then return end

    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not root or not head or not humanoid then return end

    local params = Core.getParams("esp") or {}
    local showBoxes = params.boxes ~= false
    local showNames = params.names ~= false
    local showTracers = params.tracers == true
    local teamColor = params.teamColor == true

    local function getColor()
        if teamColor and player.Team then
            return player.Team.TeamColor.Color
        end
        return ThemeEngine.getToken("esp.box") or Color3.new(1, 0, 0)
    end

    -- Box (using Drawing API if available, else Highlight)
    local box, nameLabel, tracer

    if Executor.has_drawing() then
        -- Drawing API
        if showBoxes then
            box = Drawing.new("Square")
            box.Thickness = 2
            box.Filled = false
            box.Color = getColor()
        end
        if showNames then
            nameLabel = Drawing.new("Text")
            nameLabel.Size = 14
            nameLabel.Center = true
            nameLabel.Outline = true
            nameLabel.Color = Color3.new(1, 1, 1)
        end
        if showTracers then
            tracer = Drawing.new("Line")
            tracer.Thickness = 1
            tracer.Color = getColor()
        end
    else
        -- Fallback: Highlight + BillboardGui
        local highlight = Instance.new("Highlight")
        highlight.FillTransparency = 0.8
        highlight.OutlineTransparency = 0
        highlight.OutlineColor = getColor()
        highlight.Adornee = char
        highlight.Parent = char

        if showNames then
            local billboard = Instance.new("BillboardGui")
            billboard.Size = UDim2.new(0, 200, 0, 30)
            billboard.StudsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = true
            billboard.Adornee = head
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = player.Name
            label.TextColor3 = Color3.new(1, 1, 1)
            label.TextStrokeTransparency = 0
            label.Font = Enum.Font.GothamBold
            label.TextSize = 14
            label.Parent = billboard
            billboard.Parent = head
            nameLabel = billboard
        end
    end

    espObjects[player] = { box = box, name = nameLabel, tracer = tracer, highlight = highlight, char = char }
end

local function removeESPForPlayer(player)
    local obj = espObjects[player]
    if obj then
        if obj.box then obj.box:Remove() end
        if obj.name then obj.name:Remove() end
        if obj.tracer then obj.tracer:Remove() end
        if obj.highlight then obj.highlight:Destroy() end
        espObjects[player] = nil
    end
end

Core.register({
    id = "esp",
    title = "ESP",
    icon = "👁",
    category = "Visuals",
    keybind = "P",
    params = {
        players = { type = "boolean", default = true },
        boxes = { type = "boolean", default = true },
        names = { type = "boolean", default = true },
        tracers = { type = "boolean", default = false },
        teamColor = { type = "boolean", default = false }
    },
    onEnable = function(params)
        -- Create ESP for existing players
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                createESPForPlayer(player)
            end
        end

        -- Listen for new players
        Core.connections.espPlayers = Players.PlayerAdded:Connect(function(player)
            if Core.active.esp then
                createESPForPlayer(player)
            end
        end)

        Players.PlayerRemoving:Connect(removeESPForPlayer)

        -- Update loop
        espConnection = RunService.RenderStepped:Connect(function()
            if not Core.active.esp then return end
            local params = Core.getParams("esp") or {}
            local showBoxes = params.boxes ~= false
            local showNames = params.names ~= false
            local showTracers = params.tracers == true

            for player, obj in pairs(espObjects) do
                if not player.Character or player.Character ~= obj.char then
                    removeESPForPlayer(player)
                    createESPForPlayer(player)
                    continue
                end

                local char = player.Character
                local root = char:FindFirstChild("HumanoidRootPart")
                local head = char:FindFirstChild("Head")
                if not root or not head then continue end

                local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                local height = math.abs(screenPos.Y - headPos.Y) * 2
                local width = height / 2

                local color = params.teamColor and player.Team and player.Team.TeamColor.Color or (ThemeEngine.getToken("esp.box") or Color3.new(1, 0, 0))

                if obj.box then
                    obj.box.Visible = showBoxes and onScreen
                    if onScreen then
                        obj.box.Size = Vector2.new(width, height)
                        obj.box.Position = Vector2.new(screenPos.X - width/2, screenPos.Y - height/2)
                        obj.box.Color = color
                    end
                end

                if obj.name then
                    obj.name.Visible = showNames and onScreen
                    if onScreen then
                        obj.name.Position = Vector2.new(screenPos.X, screenPos.Y - height/2 - 15)
                        obj.name.Text = player.Name .. (params.distance and " [" .. math.floor((Camera.CFrame.Position - root.Position).Magnitude) .. "m]" or "")
                    end
                end

                if obj.tracer then
                    obj.tracer.Visible = showTracers and onScreen
                    if onScreen then
                        obj.tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                        obj.tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                        obj.tracer.Color = color
                    end
                end

                if obj.highlight then
                    obj.highlight.OutlineColor = color
                end
            end
        end)
    end,
    onDisable = function()
        if espConnection then espConnection:Disconnect() espConnection = nil end
        for player, _ in pairs(espObjects) do
            removeESPForPlayer(player)
        end
        local conn = Core.connections.espPlayers
        if conn then conn:Disconnect() Core.connections.espPlayers = nil end
    end,
    onParamChange = function(param, value)
        -- Recreate ESP to apply visual changes
        if Core.active.esp then
            Core.disable("esp")
            task.wait(0.1)
            Core.enable("esp")
        end
    end
})

-- ============================================================
-- HITBOX EXPANDER
-- ============================================================
local hitboxConnection = nil

Core.register({
    id = "hitbox",
    title = "Hitbox Expander",
    icon = "🎯",
    category = "Combat",
    keybind = "H",
    params = {
        size = { type = "number", default = 10, min = 2, max = 50, suffix = " studs" },
        transparency = { type = "number", default = 0.7, min = 0, max = 1 },
        show = { type = "boolean", default = true }
    },
    onEnable = function(params)
        hitboxConnection = RunService.Heartbeat:Connect(function()
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local root = player.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local size = params.size or 10
                        root.Size = Vector3.new(size, size, size)
                        root.Transparency = params.show and (params.transparency or 0.7) or 1
                        root.Material = Enum.Material.Neon
                        root.CanCollide = false
                    end
                end
            end
        end)
    end,
    onDisable = function()
        if hitboxConnection then hitboxConnection:Disconnect() hitboxConnection = nil end
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    root.Size = Vector3.new(2, 2, 1)
                    root.Transparency = 1
                    root.Material = Enum.Material.Plastic
                    root.CanCollide = true
                end
            end
        end
    end,
    onParamChange = function(param, value)
        -- Applied in loop
    end
})

-- ============================================================
-- FREECAM
-- ============================================================
local freecamEnabled = false
local freecamConnection = nil
local freecamCFrame = CFrame.new()
local freecamSpeed = 50
local originalCameraSubject = nil
local originalCameraType = nil

Core.register({
    id = "freecam",
    title = "Freecam",
    icon = "🎥",
    category = "Visuals",
    keybind = "C",
    params = {
        speed = { type = "number", default = 50, min = 1, max = 500, suffix = " studs/s" }
    },
    onEnable = function(params)
        freecamSpeed = params.speed or 50
        originalCameraSubject = Camera.CameraSubject
        originalCameraType = Camera.CameraType

        Camera.CameraType = Enum.CameraType.Scriptable
        Camera.CameraSubject = nil
        freecamCFrame = Camera.CFrame

        freecamEnabled = true
        freecamConnection = RunService.RenderStepped:Connect(function(dt)
            if not freecamEnabled then return end

            local move = Vector3.zero
            local look = Vector2.zero

            -- Movement keys
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + freecamCFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - freecamCFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - freecamCFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + freecamCFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end

            if move.Magnitude > 0 then
                freecamCFrame = freecamCFrame + move.Unit * freecamSpeed * dt
            end

            Camera.CFrame = freecamCFrame
        end)

        -- Mouse look
        Core.connections.freecamMouse = UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and freecamEnabled then
                local delta = input.Delta
                freecamCFrame = freecamCFrame * CFrame.Angles(0, -delta.X * 0.002, 0) * CFrame.Angles(-delta.Y * 0.002, 0, 0)
            end
        end)

        -- Lock mouse
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end,
    onDisable = function()
        freecamEnabled = false
        if freecamConnection then freecamConnection:Disconnect() freecamConnection = nil end
        local conn = Core.connections.freecamMouse
        if conn then conn:Disconnect() Core.connections.freecamMouse = nil end

        Camera.CameraType = originalCameraType or Enum.CameraType.Custom
        Camera.CameraSubject = originalCameraSubject or LocalPlayer.Character
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end,
    onParamChange = function(param, value)
        if param == "speed" then freecamSpeed = value end
    end
})

-- ============================================================
-- UNANCHOR / RESPAWN LOCK / NO FALL
-- ============================================================
local unanchorConnection = nil

Core.register({
    id = "unanchor",
    title = "Unanchor All",
    icon = "🔓",
    category = "Utility",
    keybind = "U",
    params = {},
    onEnable = function()
        unanchorConnection = RunService.Heartbeat:Connect(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Anchored then
                    obj.Anchored = false
                end
            end
        end)
    end,
    onDisable = function()
        if unanchorConnection then unanchorConnection:Disconnect() unanchorConnection = nil end
    end
})

Core.register({
    id = "respawnlock",
    title = "Respawn Lock",
    icon = "🔒",
    category = "Utility",
    keybind = "R",
    params = {},
    onEnable = function()
        LocalPlayer.CharacterAdded:Connect(function()
            if Core.active.respawnlock then
                task.wait(0.1)
                LocalPlayer:LoadCharacter()
            end
        end)
    end,
    onDisable = function() end
})

Core.register({
    id = "nofall",
    title = "No Fall Damage",
    icon = "🪂",
    category = "Utility",
    keybind = "F",
    params = {},
    onEnable = function()
        -- Hook fall damage (game-specific, basic implementation)
        local humanoid = getHumanoid()
        if humanoid then
            humanoid.StateChanged:Connect(function(old, new)
                if new == Enum.HumanoidStateType.FallingDown or new == Enum.HumanoidStateType.Ragdoll then
                    humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end)
        end
    end,
    onDisable = function() end
})

-- ============================================================
-- TELEPORT (Save/Goto points)
-- ============================================================
Core.register({
    id = "teleport",
    title = "Teleport",
    icon = "📍",
    category = "Utility",
    keybind = "T",
    params = {},
    onEnable = function() end,
    onDisable = function() end
})

-- ============================================================
-- PLAYER LIST
-- ============================================================
Core.register({
    id = "playerlist",
    title = "Player List",
    icon = "👥",
    category = "Utility",
    keybind = "L",
    params = {},
    onEnable = function() end,
    onDisable = function() end
})

Log.info("Core modules registered:", table.concat((function() local t={} for k,_ in pairs(Core.modules) do table.insert(t,k) end return t end)(), ", "))

return Core