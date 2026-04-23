-- ZYROX DESYNC - Shows where OTHER PLAYERS see you
local Players = game:GetService("Players")
local tween = game:GetService("TweenService")
local input = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local camera = workspace.CurrentCamera

local lp = Players.LocalPlayer
local guiParent = lp:WaitForChild("PlayerGui")

local active = false
local isDesyncing = false
local noAnimActive = false
local noAnimConnection = nil
local desyncConnection = nil
local humanoid, hrp
local firstActivationDone = false
local ghostBeam = nil

-- Track positions - THIS IS KEY
local yourActualPosition = nil
local positionWhereOthersSeeYou = nil
local lastPosition = nil
local lagBackCount = 0

local dragging = false
local dragStart
local startPos

-- ==================== DETECT WHERE OTHER PLAYERS SEE YOU ====================
-- When you lag back, the server snaps you to where IT thinks you should be
-- But OTHER PLAYERS still see you at the position you were trying to go to
local function detectOtherPlayersView()
    local char = lp.Character
    if not char then return end
    
    local currentHrp = char:FindFirstChild("HumanoidRootPart")
    if not currentHrp then return end
    
    yourActualPosition = currentHrp.Position
    
    if lastPosition then
        local distance = (yourActualPosition - lastPosition).Magnitude
        
        -- LAG BACK DETECTED - Server corrected your position
        if distance > 15 and distance < 500 then
            -- HERE'S THE FIX:
            -- The server snapped you from lastPosition TO yourActualPosition
            -- BUT other players saw you at lastPosition (where you were trying to go)
            -- So the ghost beam should show lastPosition, NOT yourActualPosition!
            
            positionWhereOthersSeeYou = lastPosition  -- This is where other players see you!
            
            if ghostBeam and active then
                -- Move ghost to where OTHER PLAYERS see you
                ghostBeam.part.Position = positionWhereOthersSeeYou
                
                -- BIG VISUAL EFFECT at other players' view of you
                ghostBeam.part.Transparency = 0
                ghostBeam.part.Size = Vector3.new(4, 4, 4)
                
                -- Flash beams
                if ghostBeam.beam then
                    ghostBeam.beam.Transparency = NumberSequence.new(0)
                    ghostBeam.beam2.Transparency = NumberSequence.new(0)
                    ghostBeam.downwardBeam.Transparency = NumberSequence.new(0)
                end
                
                -- Create marker at where other players see you
                local marker = Instance.new("Part")
                marker.Size = Vector3.new(3, 3, 3)
                marker.Shape = Enum.PartType.Ball
                marker.Color = Color3.fromRGB(255, 0, 255)
                marker.Material = Enum.Material.Neon
                marker.Anchored = true
                marker.CanCollide = false
                marker.Position = positionWhereOthersSeeYou
                marker.Parent = workspace
                
                -- Expand and fade
                local markerTween = tween:Create(marker, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = Vector3.new(6, 6, 6),
                    Transparency = 1
                })
                markerTween:Play()
                
                -- Ring effect
                local ring = Instance.new("Part")
                ring.Size = Vector3.new(1, 0.2, 1)
                ring.Shape = Enum.PartType.Cylinder
                ring.Color = Color3.fromRGB(255, 255, 0)
                ring.Material = Enum.Material.Neon
                ring.Anchored = true
                ring.CanCollide = false
                ring.Position = positionWhereOthersSeeYou
                ring.Parent = workspace
                
                local ringTween = tween:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = Vector3.new(12, 0.2, 12),
                    Transparency = 1
                })
                ringTween:Play()
                
                -- Clean up
                task.delay(0.5, function()
                    marker:Destroy()
                    ring:Destroy()
                    if ghostBeam then
                        ghostBeam.part.Transparency = 0.3
                        ghostBeam.part.Size = Vector3.new(2.5, 2.5, 2.5)
                        if ghostBeam.beam then
                            ghostBeam.beam.Transparency = NumberSequence.new(0.2)
                            ghostBeam.beam2.Transparency = NumberSequence.new(0.4)
                            ghostBeam.downwardBeam.Transparency = NumberSequence.new(0.3)
                        end
                    end
                end)
                
                -- Text label showing where other players see you
                local billboard = Instance.new("BillboardGui")
                billboard.Size = UDim2.new(0, 200, 0, 50)
                billboard.StudsOffset = Vector3.new(0, 2.5, 0)
                billboard.AlwaysOnTop = true
                
                local text = Instance.new("TextLabel")
                text.Size = UDim2.new(1, 0, 1, 0)
                text.BackgroundTransparency = 1
                text.Text = "⚠️ OTHER PLAYERS SEE YOU HERE ⚠️"
                text.TextColor3 = Color3.fromRGB(255, 255, 0)
                text.TextSize = 12
                text.Font = Enum.Font.LuckiestGuy
                text.TextStrokeTransparency = 0.2
                text.Parent = billboard
                
                billboard.Parent = ghostBeam.part
                task.delay(1.5, function() if billboard then billboard:Destroy() end end)
            end
            
            lagBackCount = lagBackCount + 1
            return true
        end
    end
    
    lastPosition = yourActualPosition
    return false
end

-- ==================== LASER BEAM SYSTEM ====================
local function createGhostBeam()
    if ghostBeam then 
        pcall(function() ghostBeam.part:Destroy() end)
        ghostBeam = nil
    end
    
    -- Ghost part shows where OTHER PLAYERS see you
    local ghostPart = Instance.new("Part")
    ghostPart.Name = "OtherPlayersView"
    ghostPart.Size = Vector3.new(2.5, 2.5, 2.5)
    ghostPart.Shape = Enum.PartType.Ball
    ghostPart.Color = Color3.fromRGB(255, 0, 255)  -- Purple = other players' view
    ghostPart.Material = Enum.Material.Neon
    ghostPart.Anchored = true
    ghostPart.CanCollide = false
    ghostPart.Transparency = 0.2
    
    -- Glow effect
    local selectionBox = Instance.new("SelectionBox")
    selectionBox.Adornee = ghostPart
    selectionBox.Color3 = Color3.fromRGB(255, 0, 255)
    selectionBox.Transparency = 0.3
    selectionBox.LineThickness = 0.2
    selectionBox.Parent = ghostPart
    
    -- Point light
    local pointLight = Instance.new("PointLight")
    pointLight.Color = Color3.fromRGB(255, 0, 255)
    pointLight.Range = 15
    pointLight.Brightness = 2
    pointLight.Parent = ghostPart
    
    -- Particles
    local particles = Instance.new("ParticleEmitter")
    particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particles.Rate = 80
    particles.Lifetime = NumberRange.new(0.8)
    particles.SpreadAngle = Vector2.new(360, 360)
    particles.VelocityInheritance = 0
    particles.Speed = NumberRange.new(4)
    particles.Color = ColorSequence.new(Color3.fromRGB(255, 0, 255))
    particles.Transparency = NumberSequence.new(0.3)
    particles.Parent = ghostPart
    
    ghostPart.Parent = workspace
    
    -- Main connecting beam (shows gap between you and other players' view)
    local beam = Instance.new("Beam")
    beam.Width0 = 0.4
    beam.Width1 = 0.4
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 255))
    beam.Transparency = NumberSequence.new(0.2)
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.Parent = ghostPart
    
    -- Inner beam
    local beam2 = Instance.new("Beam")
    beam2.Width0 = 0.15
    beam2.Width1 = 0.15
    beam2.Color = ColorSequence.new(Color3.fromRGB(255, 100, 255))
    beam2.Transparency = NumberSequence.new(0.4)
    beam2.FaceCamera = true
    beam2.Parent = ghostPart
    
    -- Downward laser
    local downwardBeam = Instance.new("Beam")
    downwardBeam.Width0 = 0.3
    downwardBeam.Width1 = 0.3
    downwardBeam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 255))
    downwardBeam.Transparency = NumberSequence.new(0.3)
    downwardBeam.FaceCamera = false
    downwardBeam.LightEmission = 0.8
    downwardBeam.Parent = ghostPart
    
    -- Attachments
    local att0 = Instance.new("Attachment")
    att0.Parent = ghostPart
    local att1 = Instance.new("Attachment")
    att1.Parent = ghostPart
    
    local att2_0 = Instance.new("Attachment")
    att2_0.Parent = ghostPart
    local att2_1 = Instance.new("Attachment")
    att2_1.Parent = ghostPart
    
    local downAtt0 = Instance.new("Attachment")
    downAtt0.Position = Vector3.new(0, -1, 0)
    downAtt0.Parent = ghostPart
    local downAtt1 = Instance.new("Attachment")
    downAtt1.Position = Vector3.new(0, -15, 0)
    downAtt1.Parent = ghostPart
    
    beam.Attachment0 = att0
    beam.Attachment1 = att1
    beam2.Attachment0 = att2_0
    beam2.Attachment1 = att2_1
    downwardBeam.Attachment0 = downAtt0
    downwardBeam.Attachment1 = downAtt1
    
    -- Laser cylinder for ground
    local laserCylinder = Instance.new("Part")
    laserCylinder.Name = "LaserGround"
    laserCylinder.Size = Vector3.new(0.5, 15, 0.5)
    laserCylinder.Shape = Enum.PartType.Cylinder
    laserCylinder.Color = Color3.fromRGB(255, 0, 255)
    laserCylinder.Material = Enum.Material.Neon
    laserCylinder.Anchored = true
    laserCylinder.CanCollide = false
    laserCylinder.Transparency = 0.5
    laserCylinder.Parent = ghostPart
    
    ghostBeam = {
        part = ghostPart,
        beam = beam,
        beam2 = beam2,
        downwardBeam = downwardBeam,
        laserCylinder = laserCylinder,
        light = pointLight,
        att0 = att0,
        att1 = att1,
        att2_0 = att2_0,
        att2_1 = att2_1,
        downAtt0 = downAtt0,
        downAtt1 = downAtt1
    }
    
    return ghostBeam
end

local function updateGhostBeam()
    if not ghostBeam or not active then return end
    
    local char = lp.Character
    if not char then return end
    
    local currentHrp = char:FindFirstChild("HumanoidRootPart")
    if not currentHrp then return end
    
    local currentPos = currentHrp.Position
    local ghostPos = ghostBeam.part.Position
    
    -- Update beam to connect YOUR position to where OTHER PLAYERS see you
    if ghostBeam.att1 and ghostBeam.att2_1 then
        local direction = currentPos - ghostPos
        ghostBeam.att1.Position = direction
        ghostBeam.att2_1.Position = direction
    end
    
    -- Update downward laser
    if ghostBeam.downAtt1 then
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {ghostBeam.part}
        
        local rayResult = workspace:Raycast(ghostPos, Vector3.new(0, -100, 0), raycastParams)
        if rayResult then
            local groundDistance = ghostPos.Y - rayResult.Position.Y
            ghostBeam.downAtt1.Position = Vector3.new(0, -groundDistance, 0)
            
            if ghostBeam.laserCylinder then
                ghostBeam.laserCylinder.Size = Vector3.new(0.5, groundDistance, 0.5)
                ghostBeam.laserCylinder.CFrame = CFrame.new(ghostPos.X, ghostPos.Y - groundDistance/2, ghostPos.Z)
            end
        end
    end
    
    -- Calculate desync distance (how far apart you are from what others see)
    local desyncDistance = (currentPos - ghostPos).Magnitude
    
    -- Pulse effect
    local pulse = math.sin(tick() * 8) * 0.1
    ghostBeam.beam.Width0 = 0.4 + pulse
    ghostBeam.beam.Width1 = 0.4 + pulse
    
    -- Color based on distance
    if desyncDistance > 20 then
        ghostBeam.beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 255))
        ghostBeam.part.Color = Color3.fromRGB(255, 0, 255)
    elseif desyncDistance > 10 then
        ghostBeam.beam.Color = ColorSequence.new(Color3.fromRGB(255, 100, 0))
        ghostBeam.part.Color = Color3.fromRGB(255, 100, 0)
    else
        ghostBeam.beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
        ghostBeam.part.Color = Color3.fromRGB(255, 0, 0)
    end
    
    -- Update UI
    if desyncStatusBox and active then
        if desyncDistance > 3 then
            desyncStatusBox.Text = string.format("DESYNC: %.0f", desyncDistance)
            desyncStatusBox.TextColor3 = Color3.fromRGB(255, 100, 0)
        else
            desyncStatusBox.Text = "SYNCED"
            desyncStatusBox.TextColor3 = Color3.fromRGB(80, 255, 120)
        end
    end
end

local function destroyGhostBeam()
    if ghostBeam then
        pcall(function() ghostBeam.part:Destroy() end)
        ghostBeam = nil
    end
end

-- ==================== NO ANIMATION SYSTEM ====================
local function toggleNoAnim(state)
    local char = lp.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    
    if state then
        if noAnimConnection then return end
        noAnimConnection = runService.RenderStepped:Connect(function()
            for _, track in pairs(hum:GetPlayingAnimationTracks()) do
                track:Stop()
                track:AdjustSpeed(0)
            end
        end)
    else
        if noAnimConnection then
            noAnimConnection:Disconnect()
            noAnimConnection = nil
        end
    end
end

-- ==================== DESYNC SYSTEM ====================
local function performInstantReset()
    local character = lp.Character
    if not character then return false end
    
    local humanoidReset = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    
    if humanoidReset and root then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                part.Transparency = 1
            elseif part:IsA("ParticleEmitter") or part:IsA("Trail") or part:IsA("Beam") then
                part.Enabled = false
            end
        end
        
        humanoidReset.Health = 0
        humanoidReset:ChangeState(Enum.HumanoidStateType.Dead)
        
        task.wait(0.1)
        lp:LoadCharacter()
        return true
    end
    return false
end

local function startDesync()
    if active or isDesyncing then return end
    isDesyncing = true
    
    local success = pcall(function()
        local character = lp.Character
        if not character then
            character = lp.CharacterAdded:Wait()
        end
        hrp = character:WaitForChild("HumanoidRootPart", 5)
        humanoid = character:WaitForChild("Humanoid", 5)
        
        if not hrp or not humanoid then
            error("Could not find HRP or Humanoid")
        end
        
        -- Initialize tracking
        lastPosition = hrp.Position
        yourActualPosition = hrp.Position
        positionWhereOthersSeeYou = hrp.Position
        
        -- Create ghost beam
        createGhostBeam()
        if ghostBeam then
            ghostBeam.part.Position = hrp.Position
        end
        
        -- Create desync
        for i = 1, 4 do
            hrp.CFrame = hrp.CFrame + Vector3.new(0, 0, -15)
            task.wait(0.08)
            hrp.CFrame = hrp.CFrame + Vector3.new(15, 0, 0)
            task.wait(0.08)
            hrp.CFrame = hrp.CFrame + Vector3.new(0, 0, 15)
            task.wait(0.08)
            hrp.CFrame = hrp.CFrame + Vector3.new(-15, 0, 0)
            task.wait(0.08)
        end
        
        if raknet and raknet.desync then
            raknet.desync(true)
        end
        
        if not firstActivationDone then
            firstActivationDone = true
            performInstantReset()
            task.wait(0.5)
            local newChar = lp.CharacterAdded:Wait()
            hrp = newChar:WaitForChild("HumanoidRootPart")
            humanoid = newChar:WaitForChild("Humanoid")
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = humanoid
        end
        
        active = true
        updateDesyncUI()
        
        -- Start detection
        desyncConnection = runService.RenderStepped:Connect(function()
            if not active then return end
            detectOtherPlayersView()  -- Detects where other players see you
            updateGhostBeam()
        end)
    end)
    
    if not success then
        warn("Desync activation failed")
        active = false
        updateDesyncUI()
    end
    
    isDesyncing = false
end

local function stopDesync()
    if not active or isDesyncing then return end
    
    if raknet and raknet.desync then
        raknet.desync(false)
    end
    
    active = false
    
    if desyncConnection then
        desyncConnection:Disconnect()
        desyncConnection = nil
    end
    
    destroyGhostBeam()
    updateDesyncUI()
    
    local char = lp.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum and hum.Health <= 0 then
            lp:LoadCharacter()
        end
    end
end

-- Handle respawn
lp.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if noAnimActive then
        toggleNoAnim(true)
    end
    if active then
        task.wait(0.3)
        local newHrp = char:FindFirstChild("HumanoidRootPart")
        local newHum = char:FindFirstChild("Humanoid")
        if newHrp and newHum then
            hrp = newHrp
            humanoid = newHum
            lastPosition = hrp.Position
            yourActualPosition = hrp.Position
            positionWhereOthersSeeYou = hrp.Position
        end
        createGhostBeam()
        if ghostBeam and hrp then
            ghostBeam.part.Position = hrp.Position
        end
    end
end)

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "KawaiFuDesync"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = guiParent

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 280, 0, 195)
mainFrame.Position = UDim2.new(1, -295, 0.35, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
mainFrame.BackgroundTransparency = 0.15
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(210, 210, 210)
mainStroke.Thickness = 1.8
mainStroke.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Text = "KawaiFu DESYNC"
titleLabel.Font = Enum.Font.LuckiestGuy
titleLabel.TextSize = 14
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Size = UDim2.new(1, -50, 0, 32)
titleLabel.Position = UDim2.new(0, 14, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Parent = mainFrame

local dropdownBtn = Instance.new("TextButton")
dropdownBtn.Size = UDim2.new(0, 28, 0, 28)
dropdownBtn.Position = UDim2.new(1, -42, 0, 10)
dropdownBtn.BackgroundTransparency = 1
dropdownBtn.Text = "▼"
dropdownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dropdownBtn.Font = Enum.Font.LuckiestGuy
dropdownBtn.TextSize = 22
dropdownBtn.Parent = mainFrame

local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, -16, 1, -52)
contentFrame.Position = UDim2.new(0, 8, 0, 44)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = contentFrame

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 6)
contentPadding.PaddingBottom = UDim.new(0, 10)
contentPadding.Parent = contentFrame

-- DESYNC Row
local desyncRow = Instance.new("Frame")
desyncRow.Size = UDim2.new(1, -10, 0, 28)
desyncRow.BackgroundTransparency = 1
desyncRow.LayoutOrder = 1
desyncRow.Parent = contentFrame

local desyncCircle = Instance.new("Frame")
desyncCircle.Size = UDim2.new(0, 12, 0, 12)
desyncCircle.Position = UDim2.new(0, 0, 0.5, -6)
desyncCircle.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
desyncCircle.BorderSizePixel = 0
desyncCircle.Parent = desyncRow

local desyncCircleCorner = Instance.new("UICorner")
desyncCircleCorner.CornerRadius = UDim.new(1, 0)
desyncCircleCorner.Parent = desyncCircle

local desyncText = Instance.new("TextLabel")
desyncText.Text = "STATUS:"
desyncText.Font = Enum.Font.LuckiestGuy
desyncText.TextSize = 14
desyncText.TextColor3 = Color3.fromRGB(255, 255, 255)
desyncText.TextXAlignment = Enum.TextXAlignment.Left
desyncText.Size = UDim2.new(0.5, 0, 1, 0)
desyncText.Position = UDim2.new(0, 18, 0, 0)
desyncText.BackgroundTransparency = 1
desyncText.Parent = desyncRow

local desyncStatusBox = Instance.new("TextLabel")
desyncStatusBox.Size = UDim2.new(0.45, 0, 1, 0)
desyncStatusBox.Position = UDim2.new(0.55, 0, 0, 0)
desyncStatusBox.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
desyncStatusBox.BackgroundTransparency = 0.2
desyncStatusBox.Text = "OFF"
desyncStatusBox.TextColor3 = Color3.fromRGB(220, 70, 70)
desyncStatusBox.TextSize = 13
desyncStatusBox.Font = Enum.Font.LuckiestGuy
desyncStatusBox.Parent = desyncRow

local desyncStatusCorner = Instance.new("UICorner")
desyncStatusCorner.CornerRadius = UDim.new(0, 8)
desyncStatusCorner.Parent = desyncStatusBox

-- NO ANIMATION Row
local noAnimRow = Instance.new("Frame")
noAnimRow.Size = UDim2.new(1, -10, 0, 28)
noAnimRow.BackgroundTransparency = 1
noAnimRow.LayoutOrder = 2
noAnimRow.Parent = contentFrame

local noAnimCircle = Instance.new("Frame")
noAnimCircle.Size = UDim2.new(0, 12, 0, 12)
noAnimCircle.Position = UDim2.new(0, 0, 0.5, -6)
noAnimCircle.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
noAnimCircle.BorderSizePixel = 0
noAnimCircle.Parent = noAnimRow

local noAnimCircleCorner = Instance.new("UICorner")
noAnimCircleCorner.CornerRadius = UDim.new(1, 0)
noAnimCircleCorner.Parent = noAnimCircle

local noAnimText = Instance.new("TextLabel")
noAnimText.Text = "NO ANIM:"
noAnimText.Font = Enum.Font.LuckiestGuy
noAnimText.TextSize = 14
noAnimText.TextColor3 = Color3.fromRGB(255, 255, 255)
noAnimText.TextXAlignment = Enum.TextXAlignment.Left
noAnimText.Size = UDim2.new(0.5, 0, 1, 0)
noAnimText.Position = UDim2.new(0, 18, 0, 0)
noAnimText.BackgroundTransparency = 1
noAnimText.Parent = noAnimRow

local noAnimStatusBox = Instance.new("TextLabel")
noAnimStatusBox.Size = UDim2.new(0.45, 0, 1, 0)
noAnimStatusBox.Position = UDim2.new(0.55, 0, 0, 0)
noAnimStatusBox.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
noAnimStatusBox.BackgroundTransparency = 0.2
noAnimStatusBox.Text = "OFF"
noAnimStatusBox.TextColor3 = Color3.fromRGB(150, 150, 150)
noAnimStatusBox.TextSize = 13
noAnimStatusBox.Font = Enum.Font.LuckiestGuy
noAnimStatusBox.Parent = noAnimRow

local noAnimStatusCorner = Instance.new("UICorner")
noAnimStatusCorner.CornerRadius = UDim.new(0, 8)
noAnimStatusCorner.Parent = noAnimStatusBox

-- Buttons
local desyncBtn = Instance.new("TextButton")
desyncBtn.Size = UDim2.new(1, -10, 0, 42)
desyncBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
desyncBtn.Text = "START DESYNC"
desyncBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
desyncBtn.TextSize = 13
desyncBtn.Font = Enum.Font.LuckiestGuy
desyncBtn.LayoutOrder = 3
desyncBtn.Parent = contentFrame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 10)
btnCorner.Parent = desyncBtn

local noAnimBtn = Instance.new("TextButton")
noAnimBtn.Size = UDim2.new(1, -10, 0, 42)
noAnimBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
noAnimBtn.Text = "TOGGLE NO ANIM"
noAnimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
noAnimBtn.TextSize = 13
noAnimBtn.Font = Enum.Font.LuckiestGuy
noAnimBtn.LayoutOrder = 4
noAnimBtn.Parent = contentFrame

local noAnimBtnCorner = Instance.new("UICorner")
noAnimBtnCorner.CornerRadius = UDim.new(0, 10)
noAnimBtnCorner.Parent = noAnimBtn

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -75, 0, 10)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.LuckiestGuy
closeBtn.TextSize = 18
closeBtn.Parent = mainFrame

-- UI Functions
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function updateDesyncUI()
    if active then
        desyncStatusBox.Text = "DESYNC"
        desyncStatusBox.TextColor3 = Color3.fromRGB(255, 100, 0)
        desyncBtn.Text = "DESYNC ACTIVE"
        desyncBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 60)
        tween:Create(desyncCircle, tweenInfo, {BackgroundColor3 = Color3.fromRGB(255, 100, 0)}):Play()
        tween:Create(mainStroke, tweenInfo, {Color = Color3.fromRGB(255, 100, 0)}):Play()
    else
        desyncStatusBox.Text = "OFF"
        desyncStatusBox.TextColor3 = Color3.fromRGB(220, 70, 70)
        desyncBtn.Text = "START DESYNC"
        desyncBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
        tween:Create(desyncCircle, tweenInfo, {BackgroundColor3 = Color3.fromRGB(220, 70, 70)}):Play()
        tween:Create(mainStroke, tweenInfo, {Color = Color3.fromRGB(210, 210, 210)}):Play()
    end
end

local function updateNoAnimUI()
    if noAnimActive then
        noAnimStatusBox.Text = "ON"
        noAnimStatusBox.TextColor3 = Color3.fromRGB(80, 255, 120)
        noAnimBtn.Text = "NO ANIM: ON"
        noAnimBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 120)
        tween:Create(noAnimCircle, tweenInfo, {BackgroundColor3 = Color3.fromRGB(80, 255, 120)}):Play()
    else
        noAnimStatusBox.Text = "OFF"
        noAnimStatusBox.TextColor3 = Color3.fromRGB(150, 150, 150)
        noAnimBtn.Text = "TOGGLE NO ANIM"
        noAnimBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
        tween:Create(noAnimCircle, tweenInfo, {BackgroundColor3 = Color3.fromRGB(150, 150, 150)}):Play()
    end
end

-- Button Events
desyncBtn.MouseButton1Click:Connect(function()
    if not active then
        startDesync()
    else
        stopDesync()
    end
end)

noAnimBtn.MouseButton1Click:Connect(function()
    noAnimActive = not noAnimActive
    toggleNoAnim(noAnimActive)
    updateNoAnimUI()
end)

closeBtn.MouseButton1Click:Connect(function()
    if active then
        if raknet and raknet.desync then
            raknet.desync(false)
        end
        destroyGhostBeam()
    end
    gui:Destroy()
end)

-- Dropdown
local minimized = false
dropdownBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        dropdownBtn.Text = "▲"
        contentFrame.Visible = false
        tween:Create(mainFrame, tweenInfo, {Size = UDim2.new(0, 280, 0, 44)}):Play()
    else
        dropdownBtn.Text = "▼"
        contentFrame.Visible = true
        tween:Create(mainFrame, tweenInfo, {Size = UDim2.new(0, 280, 0, 195)}):Play()
    end
end)

-- Dragging
local function startDragging(inputObject)
    dragging = true
    dragStart = inputObject.Position
    startPos = mainFrame.Position
end

titleLabel.InputBegan:Connect(function(inputObject)
    if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
        startDragging(inputObject)
    end
end)

input.InputChanged:Connect(function(inputObject)
    if dragging and inputObject.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = inputObject.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

input.InputEnded:Connect(function(inputObject)
    if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- Startup
mainFrame.Size = UDim2.new(0, 0, 0, 0)
mainFrame.BackgroundTransparency = 1
tween:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 280, 0, 195),
    BackgroundTransparency = 0.15
}):Play()

updateDesyncUI()
updateNoAnimUI()

print("ZYROX DESYNC Loaded - Purple beam shows where OTHER PLAYERS see you!")
