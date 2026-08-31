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
-- VEHICLE FLY  (fly while seated in a vehicle, WASD + Space/Ctrl)
-- ============================================================
local vfBodyVelocity = nil
local vfBodyGyro = nil
local vfConnection = nil
local vfTarget = nil
local vfKeys = {W=false, A=false, S=false, D=false, Space=false, LeftControl=false}

local function vfDetach()
    if vfBodyVelocity then vfBodyVelocity:Destroy(); vfBodyVelocity = nil end
    if vfBodyGyro then vfBodyGyro:Destroy(); vfBodyGyro = nil end
    vfTarget = nil
end

Core.register({
    id = "vehiclefly",
    title = "Vehicle Fly",
    icon = "🚗",
    category = "Movement",
    keybind = "V",
    params = {
        speed = { type = "number", default = 50, min = 1, max = 500, suffix = " studs/s" },
        verticalSpeed = { type = "number", default = 50, min = 1, max = 500, suffix = " studs/s" },
    },
    onEnable = function(params)
        vfConnection = RunService.RenderStepped:Connect(function()
            local hum = getHumanoid()
            local seat = hum and hum.SeatPart
            if not seat then
                vfDetach()
                return
            end
            local model = seat:FindFirstAncestorOfClass("Model")
            local root = (model and model.PrimaryPart) or seat
            if root ~= vfTarget then
                vfDetach()
                vfTarget = root
                vfBodyVelocity = Instance.new("BodyVelocity")
                vfBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                vfBodyVelocity.Velocity = Vector3.zero
                vfBodyVelocity.Parent = root
                vfBodyGyro = Instance.new("BodyGyro")
                vfBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                vfBodyGyro.CFrame = root.CFrame
                vfBodyGyro.Parent = root
            end

            local p = Core.getParams("vehiclefly") or params
            local camCF = Camera.CFrame
            local moveDir = Vector3.zero
            if vfKeys.W then moveDir = moveDir + camCF.LookVector end
            if vfKeys.S then moveDir = moveDir - camCF.LookVector end
            if vfKeys.A then moveDir = moveDir - camCF.RightVector end
            if vfKeys.D then moveDir = moveDir + camCF.RightVector end
            if vfKeys.Space then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if vfKeys.LeftControl then moveDir = moveDir - Vector3.new(0, 1, 0) end
            if moveDir.Magnitude > 0 then moveDir = moveDir.Unit end

            local hs = p.speed or 50
            local vs = p.verticalSpeed or 50
            if vfBodyVelocity then vfBodyVelocity.Velocity = Vector3.new(moveDir.X * hs, moveDir.Y * vs, moveDir.Z * hs) end
            if vfBodyGyro then vfBodyGyro.CFrame = CFrame.new(root.Position, root.Position + camCF.LookVector) end
        end)

        local function onBegan(input, processed)
            if processed then return end
            local k = input.KeyCode
            if k == Enum.KeyCode.W then vfKeys.W = true
            elseif k == Enum.KeyCode.A then vfKeys.A = true
            elseif k == Enum.KeyCode.S then vfKeys.S = true
            elseif k == Enum.KeyCode.D then vfKeys.D = true
            elseif k == Enum.KeyCode.Space then vfKeys.Space = true
            elseif k == Enum.KeyCode.LeftControl then vfKeys.LeftControl = true end
        end
        local function onEnded(input)
            local k = input.KeyCode
            if k == Enum.KeyCode.W then vfKeys.W = false
            elseif k == Enum.KeyCode.A then vfKeys.A = false
            elseif k == Enum.KeyCode.S then vfKeys.S = false
            elseif k == Enum.KeyCode.D then vfKeys.D = false
            elseif k == Enum.KeyCode.Space then vfKeys.Space = false
            elseif k == Enum.KeyCode.LeftControl then vfKeys.LeftControl = false end
        end
        Core.connections.vehiclefly = {
            UserInputService.InputBegan:Connect(onBegan),
            UserInputService.InputEnded:Connect(onEnded),
        }
        return true
    end,
    onDisable = function()
        if vfConnection then vfConnection:Disconnect(); vfConnection = nil end
        vfDetach()
        local conn = Core.connections.vehiclefly
        if conn then
            for _, c in ipairs(conn) do c:Disconnect() end
            Core.connections.vehiclefly = nil
        end
    end,
    onParamChange = function()
        -- Params read fresh in the render loop
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
        speed = { type = "number", default = 50, min = 0, max = 10000, suffix = " studs/s" },
        mode = { type = "string", default = "WalkSpeed", options = {"WalkSpeed", "Humanoid", "Velocity"} }
    },
    onEnable = function(params)
        local humanoid = getHumanoid()
        if not humanoid then return false, "No humanoid" end

        originalWalkSpeed = humanoid.WalkSpeed
        if speedConnection then speedConnection:Disconnect() speedConnection = nil end

        local mode = params.mode or "WalkSpeed"

        if mode == "Velocity" then
            speedConnection = RunService.Heartbeat:Connect(function()
                local p = Core.getParams("speed") or params
                local spd = p.speed or 50
                local root = getRootPart()
                local hum = getHumanoid()
                if root and hum and hum.MoveDirection.Magnitude > 0 then
                    root.Velocity = hum.MoveDirection * spd
                end
            end)
        else
            speedConnection = RunService.RenderStepped:Connect(function()
                local p = Core.getParams("speed") or params
                local spd = p.speed or 50
                local hum = getHumanoid()
                if hum then
                    hum.WalkSpeed = spd
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
-- JUMP (JumpPower / JumpHeight)
-- ============================================================
local jumpPowerValue = 50
local jumpHeightValue = 7
local jumpCharConn = nil

local function applyJump()
    local hum = getHumanoid()
    if hum then
        hum.JumpPower = jumpPowerValue
        hum.JumpHeight = jumpHeightValue
    end
end

Core.register({
    id = "jump",
    title = "Jump",
    icon = "🦘",
    category = "Movement",
    params = {
        jumpPower = { type = "number", default = 50, min = 0, max = 1000 },
        jumpHeight = { type = "number", default = 7, min = 0, max = 1000, suffix = " studs" },
    },
    onEnable = function(params)
        jumpPowerValue = Core.getParam("jump", "jumpPower") or params.jumpPower or 50
        jumpHeightValue = Core.getParam("jump", "jumpHeight") or params.jumpHeight or 7
        applyJump()
        jumpCharConn = LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.3)
            if Core.active.jump then applyJump() end
        end)
        return true
    end,
    onDisable = function()
        if jumpCharConn then jumpCharConn:Disconnect(); jumpCharConn = nil end
        local hum = getHumanoid()
        if hum then hum.JumpPower = 50; hum.JumpHeight = 7.2 end
    end,
    onParamChange = function(param, value)
        if param == "jumpPower" then jumpPowerValue = value
        elseif param == "jumpHeight" then jumpHeightValue = value end
        local hum = getHumanoid()
        if hum and Core.active.jump then
            if param == "jumpPower" then hum.JumpPower = value
            elseif param == "jumpHeight" then hum.JumpHeight = value end
        end
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
-- VISUALS ESP (box / healthbar / name / distance / tracer /
--              state icons / part ESP)
-- ============================================================
local CoreGui = game:GetService("CoreGui")

local V = {
    Enabled = false, MaxDist = 2000,
    Box = true, HealthBar = true, Name = true, Distance = false, Tracer = false, StateIcons = false,
    PartESP = false, PartList = {},
    Color = Color3.fromRGB(255, 255, 255),
}
local VCache = {}
local VPartCache = {}
local VConn = nil
local VIcons = {
    Walking = "rbxassetid://117030571122427",
    Idle    = "rbxassetid://114666164258248",
    Jump    = "rbxassetid://132943442694668",
    Swim    = "rbxassetid://123260751807425",
    Dead    = "rbxassetid://104191266659021",
}

local function vDraw(t, props)
    if not Executor.has_drawing() then return nil end
    local ok, obj = pcall(Drawing.new, t)
    if not ok or not obj then return nil end
    for k, v in pairs(props) do obj[k] = v end
    return obj
end

local function vStateIcon(hum)
    if not hum or hum.Health <= 0 then return VIcons.Dead end
    local s = hum:GetState()
    if s == Enum.HumanoidStateType.Jumping or s == Enum.HumanoidStateType.Freefall then return VIcons.Jump end
    if s == Enum.HumanoidStateType.Swimming then return VIcons.Swim end
    if hum.MoveDirection.Magnitude > 0.1 then return VIcons.Walking end
    return VIcons.Idle
end

local function vCreate(plr)
    if plr == LocalPlayer or VCache[plr] then return end
    local esp = {
        Box    = vDraw("Square", { Thickness = 1, Filled = false, Transparency = 0, Color = V.Color, Visible = false }),
        HPOut  = vDraw("Square", { Thickness = 1, Filled = true, Color = Color3.new(0, 0, 0), Transparency = 0, Visible = false }),
        HPBar  = vDraw("Square", { Thickness = 1, Filled = true, Transparency = 0, Visible = false }),
        Name   = vDraw("Text", { Size = 13, Center = true, Outline = true, Color = V.Color, Visible = false }),
        Dist   = vDraw("Text", { Size = 11, Center = true, Outline = true, Color = V.Color, Visible = false }),
        Tracer = vDraw("Line", { Thickness = 2, Color = V.Color, Transparency = 0, Visible = false }),
    }
    local gui = Instance.new("BillboardGui")
    gui.Name = "VState_" .. plr.Name
    gui.Size = UDim2.new(0, 35, 0, 35)
    gui.AlwaysOnTop = true
    gui.ExtentsOffset = Vector3.new(0, 3, 0)
    gui.Enabled = false
    gui.Parent = CoreGui
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Size = UDim2.new(1, 0, 1, 0)
    img.Image = VIcons.Idle
    img.Parent = gui
    esp.IconGui = gui
    esp.IconImg = img
    VCache[plr] = esp
end

local function vHide(esp)
    if esp.Box then esp.Box.Visible = false end
    if esp.HPOut then esp.HPOut.Visible = false end
    if esp.HPBar then esp.HPBar.Visible = false end
    if esp.Name then esp.Name.Visible = false end
    if esp.Dist then esp.Dist.Visible = false end
    if esp.Tracer then esp.Tracer.Visible = false end
    if esp.IconGui then esp.IconGui.Enabled = false end
end

local function vRemove(plr)
    local esp = VCache[plr]
    if not esp then return end
    for _, v in pairs(esp) do
        if typeof(v) == "userdata" then pcall(function() v:Remove() end)
        elseif typeof(v) == "Instance" then pcall(function() v:Destroy() end) end
    end
    VCache[plr] = nil
end

local function vUpdate()
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    for plr, esp in pairs(VCache) do
        local char = plr.Character
        local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local head = char and char:FindFirstChild("Head")
        local show = V.Enabled and char and root and hum and hum.Health > 0 and plr ~= LocalPlayer
        if show then
            local pos, vis = Camera:WorldToViewportPoint(root.Position)
            local dist = myRoot and (root.Position - myRoot.Position).Magnitude or 0
            if vis and dist <= V.MaxDist then
                local size = Vector2.new(2000 / pos.Z, 2500 / pos.Z)
                local top = Vector2.new(pos.X - size.X / 2, pos.Y - size.Y / 2)
                if esp.Box then esp.Box.Visible = V.Box; if V.Box then esp.Box.Size = size; esp.Box.Position = top; esp.Box.Color = V.Color end end
                if V.HealthBar and esp.HPOut and esp.HPBar then
                    local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    esp.HPOut.Visible = true; esp.HPOut.Size = Vector2.new(4, size.Y); esp.HPOut.Position = Vector2.new(top.X - 6, top.Y)
                    esp.HPBar.Visible = true; esp.HPBar.Size = Vector2.new(2, size.Y * hp); esp.HPBar.Position = Vector2.new(top.X - 5, top.Y + size.Y * (1 - hp)); esp.HPBar.Color = Color3.fromHSV(hp * 0.3, 1, 1)
                else
                    if esp.HPOut then esp.HPOut.Visible = false end
                    if esp.HPBar then esp.HPBar.Visible = false end
                end
                if esp.Name then esp.Name.Visible = V.Name; if V.Name then esp.Name.Text = plr.Name; esp.Name.Position = Vector2.new(pos.X, top.Y - 15); esp.Name.Color = V.Color end end
                if esp.Dist then esp.Dist.Visible = V.Distance; if V.Distance then esp.Dist.Text = math.floor(dist) .. "m"; esp.Dist.Position = Vector2.new(pos.X, top.Y + size.Y + 2); esp.Dist.Color = V.Color end end
                if esp.Tracer then esp.Tracer.Visible = V.Tracer; if V.Tracer then esp.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y); esp.Tracer.To = Vector2.new(pos.X, pos.Y + size.Y / 2); esp.Tracer.Color = V.Color end end
                if esp.IconGui then
                    if V.StateIcons and head then esp.IconGui.Enabled = true; esp.IconGui.Adornee = head; esp.IconImg.Image = vStateIcon(hum)
                    else esp.IconGui.Enabled = false end
                end
            else
                vHide(esp)
            end
        else
            vHide(esp)
        end
    end

    if V.PartESP and #V.PartList > 0 then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and table.find(V.PartList, obj.Name) then
                if not VPartCache[obj] then
                    VPartCache[obj] = {
                        Box = vDraw("Square", { Thickness = 1, Color = Color3.fromRGB(255, 255, 0), Visible = false }),
                        Text = vDraw("Text", { Size = 12, Center = true, Outline = true, Color = V.Color, Visible = false }),
                    }
                end
                local d = VPartCache[obj]
                if d.Box and d.Text then
                    local pp, pv = Camera:WorldToViewportPoint(obj.Position)
                    if pv then
                        d.Box.Visible = true; d.Box.Size = Vector2.new(1000 / pp.Z, 1000 / pp.Z); d.Box.Position = Vector2.new(pp.X - d.Box.Size.X / 2, pp.Y - d.Box.Size.Y / 2)
                        d.Text.Visible = true; d.Text.Text = obj.Name; d.Text.Position = Vector2.new(pp.X, pp.Y + d.Box.Size.Y / 2 + 2)
                    else
                        d.Box.Visible = false; d.Text.Visible = false
                    end
                end
            end
        end
    else
        for _, d in pairs(VPartCache) do if d.Box then d.Box.Visible = false end; if d.Text then d.Text.Visible = false end end
    end
end


Core.register({
    id = "esp",
    title = "Visuals",
    icon = "👁",
    category = "Visuals",
    keybind = "P",
    params = {},
    onEnable = function()
        V.Enabled = true
        for _, p in ipairs(Players:GetPlayers()) do vCreate(p) end
        Core.connections.espPlayers = Players.PlayerAdded:Connect(vCreate)
        Core.connections.espRemoving = Players.PlayerRemoving:Connect(vRemove)
        VConn = RunService.RenderStepped:Connect(vUpdate)
    end,
    onDisable = function()
        V.Enabled = false
        if VConn then VConn:Disconnect(); VConn = nil end
        if Core.connections.espPlayers then Core.connections.espPlayers:Disconnect(); Core.connections.espPlayers = nil end
        if Core.connections.espRemoving then Core.connections.espRemoving:Disconnect(); Core.connections.espRemoving = nil end
        local keys = {}
        for plr in pairs(VCache) do keys[#keys + 1] = plr end
        for _, plr in ipairs(keys) do vRemove(plr) end
    end,
    buildWindow = function(win, tab)
        local s1 = tab:Section("1. Player ESP")
        s1:Toggle({ title = "Enable ESP", default = Core.isEnabled("esp"), callback = function(v)
            if v then Core.enable("esp") else Core.disable("esp") end
        end })
        s1:Toggle({ title = "Boxes", default = V.Box, callback = function(v) V.Box = v end })
        s1:Toggle({ title = "Health Bar", default = V.HealthBar, callback = function(v) V.HealthBar = v end })
        s1:Toggle({ title = "Names", default = V.Name, callback = function(v) V.Name = v end })
        s1:Toggle({ title = "Distance", default = V.Distance, callback = function(v) V.Distance = v end })
        s1:Toggle({ title = "Tracers", default = V.Tracer, callback = function(v) V.Tracer = v end })
        s1:Toggle({ title = "State Icons", default = V.StateIcons, callback = function(v) V.StateIcons = v end })
        s1:Slider({ title = "Max Distance", min = 100, max = 10000, step = 100, default = V.MaxDist, suffix = " studs", callback = function(v) V.MaxDist = v end })

        local s2 = tab:Section("2. Part ESP")
        local partInput = s2:Input({ title = "Part Name", placeholder = "Name...", callback = function() end })
        s2:Button({ title = "Add Part", callback = function()
            local t = partInput and partInput.Get and partInput:Get()
            if t and t ~= "" then table.insert(V.PartList, t) end
        end })
        s2:Button({ title = "Clear Parts", callback = function()
            for _, d in pairs(VPartCache) do
                if d.Box then pcall(function() d.Box:Remove() end) end
                if d.Text then pcall(function() d.Text:Remove() end) end
            end
            VPartCache = {}
            V.PartList = {}
        end })
        s2:Toggle({ title = "Enable Part ESP", default = V.PartESP, callback = function(v) V.PartESP = v end })
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
local freecamLooking = false
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

        -- Mouse look: only while the right mouse button is held, so the cursor
        -- stays free (not locked) and can click the UI.
        freecamLooking = false
        Core.connections.freecamMouse = UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and freecamEnabled and freecamLooking then
                local delta = input.Delta
                freecamCFrame = freecamCFrame * CFrame.Angles(0, -delta.X * 0.002, 0) * CFrame.Angles(-delta.Y * 0.002, 0, 0)
            end
        end)
        Core.connections.freecamLookBtn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then freecamLooking = true end
        end)
        Core.connections.freecamLookBtnEnd = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then freecamLooking = false end
        end)
    end,
    onDisable = function()
        freecamEnabled = false
        freecamLooking = false
        if freecamConnection then freecamConnection:Disconnect() freecamConnection = nil end
        local conn = Core.connections.freecamMouse
        if conn then conn:Disconnect() Core.connections.freecamMouse = nil end
        local lb = Core.connections.freecamLookBtn
        if lb then lb:Disconnect() Core.connections.freecamLookBtn = nil end
        local lbe = Core.connections.freecamLookBtnEnd
        if lbe then lbe:Disconnect() Core.connections.freecamLookBtnEnd = nil end

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