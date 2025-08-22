--[[
  DRX_UI.client.lua
  - Builds the dark DRX GUI.
  - Fly toggle with adjustable speed (+/-).
  - Button to toggle NPC target lock (fires RemoteEvent; server decides).
  - Draggable window, respawn-safe.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- === Fly state ===================================================
local flying = false
local flySpeed = 50
local bodyGyro, bodyVelocity
local rsConn -- RenderStepped connection for movement

local function ensureCharacter()
    local char = player.Character or player.CharacterAdded:Wait()
    char:WaitForChild("Humanoid")
    char:WaitForChild("HumanoidRootPart")
    return char
end

local function startFly()
    local char = ensureCharacter()
    local hrp = char.HumanoidRootPart

    -- Clean any leftovers first
    if bodyGyro then bodyGyro:Destroy() end
    if bodyVelocity then bodyVelocity:Destroy() end

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.P = 9e4
    bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bodyGyro.CFrame = hrp.CFrame
    bodyGyro.Parent = hrp

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bodyVelocity.Velocity = Vector3.new()
    bodyVelocity.Parent = hrp

    -- movement loop
    if rsConn then rsConn:Disconnect() end
    rsConn = RunService.RenderStepped:Connect(function()
        if not flying or not workspace.CurrentCamera then return end
        if not char.Parent then return end
        local cam = workspace.CurrentCamera
        bodyGyro.CFrame = cam.CFrame

        local dir = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end

        if dir.Magnitude > 0 then
            dir = dir.Unit
        end
        bodyVelocity.Velocity = dir * flySpeed
    end)
end

local function stopFly()
    if rsConn then rsConn:Disconnect() rsConn = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
end

-- Clean up on respawn
player.CharacterAdded:Connect(function()
    if flying then
        -- Reapply on next frame to ensure HRP exists
        task.defer(startFly)
    end
end)

-- === UI helpers ==================================================
local function makeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 12)
    c.Parent = parent
    return c
end

local function makeShadow(parent)
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Thickness = 1
    uiStroke.Transparency = 0.4
    uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    uiStroke.Color = Color3.fromRGB(60, 60, 60)
    uiStroke.Parent = parent
end

-- Draggable behavior for a Frame via title bar
local function makeDraggable(dragHandle: Frame, root: Frame)
    local dragging = false
    local dragStart, startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = root.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local delta = input.Position - dragStart
            root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- === Build DRX UI ===============================================
local function buildUI()
    -- Clear old UI if re-run
    local existing = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("DRX_UI")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DRX_UI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 420, 0, 260)
    frame.Position = UDim2.new(0.5, -210, 0.5, -130)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    makeCorner(frame, 14)
    makeShadow(frame)

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 42)
    titleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = frame
    makeCorner(titleBar, 14)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "DRX"
    title.TextColor3 = Color3.fromRGB(0, 200, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    makeDraggable(titleBar, frame)

    -- Fly toggle button
    local flyBtn = Instance.new("TextButton")
    flyBtn.Size = UDim2.new(0, 160, 0, 40)
    flyBtn.Position = UDim2.new(0, 20, 0, 64)
    flyBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    flyBtn.Text = "Fly: OFF"
    flyBtn.TextScaled = true
    flyBtn.Font = Enum.Font.GothamBold
    flyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    flyBtn.Parent = frame
    makeCorner(flyBtn, 8)

    -- Speed label
    local speedLabel = Instance.new("TextLabel")
    speedLabel.Size = UDim2.new(0, 180, 0, 40)
    speedLabel.Position = UDim2.new(0, 200, 0, 64)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = "Speed: " .. flySpeed
    speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    speedLabel.TextScaled = true
    speedLabel.Font = Enum.Font.GothamBold
    speedLabel.Parent = frame

    -- Speed controls
    local minusBtn = Instance.new("TextButton")
    minusBtn.Size = UDim2.new(0, 60, 0, 40)
    minusBtn.Position = UDim2.new(0, 200, 0, 110)
    minusBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    minusBtn.Text = "-"
    minusBtn.TextScaled = true
    minusBtn.Font = Enum.Font.GothamBold
    minusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minusBtn.Parent = frame
    makeCorner(minusBtn, 10)

    local plusBtn = Instance.new("TextButton")
    plusBtn.Size = UDim2.new(0, 60, 0, 40)
    plusBtn.Position = UDim2.new(0, 270, 0, 110)
    plusBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
    plusBtn.Text = "+"
    plusBtn.TextScaled = true
    plusBtn.Font = Enum.Font.GothamBold
    plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    plusBtn.Parent = frame
    makeCorner(plusBtn, 10)

    -- Target lock toggle (fires RemoteEvent)
    local lockBtn = Instance.new("TextButton")
    lockBtn.Size = UDim2.new(0, 200, 0, 40)
    lockBtn.Position = UDim2.new(0, 20, 0, 110)
    lockBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    lockBtn.Text = "Toggle NPC Target Lock"
    lockBtn.TextScaled = true
    lockBtn.Font = Enum.Font.GothamBold
    lockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    lockBtn.Parent = frame
    makeCorner(lockBtn, 8)

    -- Hotkey hint
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -40, 0, 28)
    hint.Position = UDim2.new(0, 20, 1, -36)
    hint.BackgroundTransparency = 1
    hint.Text = "Hotkey: Press F to toggle Fly"
    hint.TextColor3 = Color3.fromRGB(170, 170, 170)
    hint.TextScaled = true
    hint.Font = Enum.Font.Gotham
    hint.Parent = frame

    -- === Wiring ===
    local function setFly(on)
        flying = on
        flyBtn.Text = flying and "Fly: ON" or "Fly: OFF"
        if flying then startFly() else stopFly() end
    end

    flyBtn.MouseButton1Click:Connect(function()
        setFly(not flying)
    end)

    plusBtn.MouseButton1Click:Connect(function()
        flySpeed += 5
        speedLabel.Text = "Speed: " .. flySpeed
    end)

    minusBtn.MouseButton1Click:Connect(function()
        flySpeed = math.max(5, flySpeed - 5)
        speedLabel.Text = "Speed: " .. flySpeed
    end)

    -- Hotkey F to toggle fly
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.F then
            setFly(not flying)
        end
    end)

    -- Remote toggle for NPC lock (server-authoritative)
    task.spawn(function()
        local evt = ReplicatedStorage:WaitForChild("ToggleTargetLock", 5)
        if evt and evt:IsA("RemoteEvent") then
            lockBtn.MouseButton1Click:Connect(function()
                evt:FireServer("global")
            end)
        else
            lockBtn.Text = "Target Lock: (No RemoteEvent)"
        end
    end)
end

-- Build immediately
buildUI()

