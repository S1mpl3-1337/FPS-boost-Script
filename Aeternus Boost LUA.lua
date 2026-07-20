--[[
    Aeternus FPS Booster  - Estável
    Otimização de desempenho + Stretch Screen
    Compatível com PC e Mobile (toque)
]]

-- ============================================================================
-- Serviços
-- ============================================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

-- ============================================================================
-- Configuração (estado)
-- ============================================================================
local Config = {
    BoostEnabled = false,
    DisableShadows = false,
    DisablePostProcessing = false,
    LowQuality = false,
    DisableWater = false,
    DisableParticles = false,
    RemoveDecals = false,
    PlasticMaterials = false,
    DisableExplosions = false,
    BlurTextures = false,
    StretchScreen = false,
    StretchFactor = 0.65,
    ApplyFFlags = false,
}

-- ============================================================================
-- Estado original para reversão (guardado apenas para Lighting, Terrain, Quality e PostEffects)
-- ============================================================================
local Original = {
    Lighting = {},
    Terrain = {},
    Quality = nil,
    TextureQuality = nil,
    PostEffects = {},
}

local function SaveOriginalState()
    -- Lighting
    Original.Lighting = {
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        Brightness = Lighting.Brightness,
        Ambient = Lighting.Ambient,
        ColorShift_Top = Lighting.ColorShift_Top,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
    }

    -- Terrain
    local terrain = Workspace:FindFirstChild("Terrain")
    if terrain then
        Original.Terrain = {
            WaterWaveSize = terrain.WaterWaveSize,
            WaterWaveSpeed = terrain.WaterWaveSpeed,
            WaterReflectance = terrain.WaterReflectance,
            WaterTransparency = terrain.WaterTransparency,
        }
    end

    -- Rendering
    Original.Quality = settings().Rendering.QualityLevel
    pcall(function()
        Original.TextureQuality = settings().Rendering.TextureQualityOverride
    end)

    -- PostEffects
    Original.PostEffects = {}
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("PostEffect") then
            Original.PostEffects[obj] = obj.Enabled
        end
    end
end

-- ============================================================================
-- Funções de otimização (aplicar / reverter)
-- ============================================================================
local function ApplyTextureFFlags()
    local setfflag = setfflag
    if not setfflag then return false end
    local flags = {
        ["DFIntDebugTextureManagerSkipMips"] = "10",
        ["DFIntTextureCompositorActiveJobs"] = "0",
        ["DFIntPerformanceControlTextureQualityBestUtility"] = "-1",
    }
    local okCount = 0
    for k, v in pairs(flags) do
        local ok, err = pcall(function() setfflag(k, v) end)
        if ok then okCount = okCount + 1 end
    end
    return okCount == 3
end

local function ApplyBoost()
    local cfg = Config

    -- Shadows
    Lighting.GlobalShadows = not cfg.DisableShadows

    -- PostProcessing
    for obj, _ in pairs(Original.PostEffects) do
        if obj and obj.Parent then
            obj.Enabled = not cfg.DisablePostProcessing
        end
    end

    -- Quality
    if cfg.LowQuality then
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    else
        settings().Rendering.QualityLevel = Original.Quality or Enum.QualityLevel.Level01
    end

    -- Blur Textures
    if cfg.BlurTextures then
        pcall(function()
            settings().Rendering.TextureQualityOverride = Enum.TextureQuality.Low
        end)
        ApplyTextureFFlags() -- tenta aplicar FFlags específicas
    else
        pcall(function()
            settings().Rendering.TextureQualityOverride = Original.TextureQuality or Enum.TextureQuality.Automatic
        end)
    end

    -- Water
    local terrain = Workspace:FindFirstChild("Terrain")
    if terrain then
        if cfg.DisableWater then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0
        else
            terrain.WaterWaveSize = Original.Terrain.WaterWaveSize or 0.5
            terrain.WaterWaveSpeed = Original.Terrain.WaterWaveSpeed or 1
            terrain.WaterReflectance = Original.Terrain.WaterReflectance or 0.5
            terrain.WaterTransparency = Original.Terrain.WaterTransparency or 0.5
        end
    end

    -- Particles
    if cfg.DisableParticles then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                obj.Lifetime = NumberRange.new(0)
            end
        end
    end

    -- Decals
    if cfg.RemoveDecals then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Decal") then
                obj.Transparency = 1
            end
        end
    end

    -- Plastic Materials
    if cfg.PlasticMaterials then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.Material = Enum.Material.Plastic
                obj.Reflectance = 0
            end
        end
    end

    -- Explosions
    if cfg.DisableExplosions then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Explosion") then
                obj.BlastPressure = 1
                obj.BlastRadius = 1
            end
        end
    end

    -- FFlags gerais (se ativado pelo botão)
    if cfg.ApplyFFlags then
        local setfflag = setfflag
        if setfflag then
            local allFlags = {
                ["DFIntCSGLevelOfDetailSwitchingDistanceL23"] = "0",
                ["FFlagDebugGraphicsPreferD3D11"] = "True",
                ["FIntRenderShadowmapBias"] = "0",
                ["FFlagDisablePostFx"] = "True",
                ["FFlagDisableParticles"] = "True",
                ["FFlagDisableDecals"] = "True",
                ["FFlagNoShadows"] = "True",
                ["FFlagReduceTextureMemory"] = "True",
                ["FFlagForceTextureReduction"] = "True",
            }
            for k, v in pairs(allFlags) do
                pcall(function() setfflag(k, v) end)
            end
        end
    end
end

local function RevertBoost()
    -- Lighting
    for k, v in pairs(Original.Lighting) do
        Lighting[k] = v
    end

    -- Terrain
    local terrain = Workspace:FindFirstChild("Terrain")
    if terrain then
        for k, v in pairs(Original.Terrain) do
            terrain[k] = v
        end
    end

    -- Quality
    settings().Rendering.QualityLevel = Original.Quality or Enum.QualityLevel.Level01
    pcall(function()
        settings().Rendering.TextureQualityOverride = Original.TextureQuality or Enum.TextureQuality.Automatic
    end)

    -- PostEffects
    for obj, enabled in pairs(Original.PostEffects) do
        if obj and obj.Parent then
            obj.Enabled = enabled
        end
    end

    -- Nota: partículas, decals, materiais e explosões não são revertidos.
    Config.ApplyFFlags = false
end

-- ============================================================================
-- Stretch Screen (gerenciamento separado)
-- ============================================================================
local stretchConnection = nil

local function ApplyStretch()
    local factor = Config.StretchFactor
    if factor == 1 then return end -- evita multiplicação desnecessária
    Camera.CFrame = Camera.CFrame * CFrame.new(0,0,0,
        1, 0, 0,
        0, factor, 0,
        0, 0, 1
    )
end

local function StartStretch()
    if stretchConnection then stretchConnection:Disconnect(); stretchConnection = nil end
    if Config.StretchScreen then
        stretchConnection = RunService.RenderStepped:Connect(ApplyStretch)
    end
end

local function StopStretch()
    if stretchConnection then
        stretchConnection:Disconnect()
        stretchConnection = nil
    end
    -- Não restaura CFrame para não travar.
end

-- ============================================================================
-- UI - Glassmorphism (com scroll)
-- ============================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FPSBoosterPro"
ScreenGui.Parent = PlayerGui

-- Blur de fundo
local BlurBackground = Instance.new("Frame")
BlurBackground.Size = UDim2.new(1, 0, 1, 0)
BlurBackground.BackgroundTransparency = 0.85
BlurBackground.BackgroundColor3 = Color3.fromRGB(20,20,30)
BlurBackground.BorderSizePixel = 0
BlurBackground.Parent = ScreenGui
local BlurEffect = Instance.new("BlurEffect")
BlurEffect.Size = 24
BlurEffect.Parent = BlurBackground

-- Container principal
local Container = Instance.new("Frame")
Container.Size = UDim2.new(0, 500, 0, 440)
Container.Position = UDim2.new(0.5, -250, 0.5, -220)
Container.BackgroundTransparency = 0.5
Container.BackgroundColor3 = Color3.fromRGB(30,30,40)
Container.BorderSizePixel = 0
Container.ClipsDescendants = true
Container.Parent = ScreenGui
local ContainerCorner = Instance.new("UICorner")
ContainerCorner.CornerRadius = UDim.new(0, 12)
ContainerCorner.Parent = Container

-- Top bar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 36)
TopBar.BackgroundTransparency = 0.6
TopBar.BackgroundColor3 = Color3.fromRGB(40,40,55)
TopBar.BorderSizePixel = 0
TopBar.Parent = Container
local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 12)
TopBarCorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Text = "Aeterus FPS Booster"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(200,200,255)
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(0, 200, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

-- Minimizar
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Text = "—"
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 20
MinimizeBtn.TextColor3 = Color3.fromRGB(255,255,255)
MinimizeBtn.BackgroundTransparency = 0.8
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(80,80,120)
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -75, 0.5, -15)
MinimizeBtn.Parent = TopBar
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)

-- Fechar
local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
CloseBtn.TextColor3 = Color3.fromRGB(255,100,100)
CloseBtn.BackgroundTransparency = 0.8
CloseBtn.BackgroundColor3 = Color3.fromRGB(80,80,120)
CloseBtn.BorderSizePixel = 0
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0.5, -15)
CloseBtn.Parent = TopBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- Área de conteúdo com scroll
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -20, 1, -50)
ContentArea.Position = UDim2.new(0, 10, 0, 44)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = Container

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, 0, 1, 0)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.Parent = ContentArea

local ContentList = Instance.new("UIListLayout")
ContentList.SortOrder = Enum.SortOrder.LayoutOrder
ContentList.Padding = UDim.new(0, 6)
ContentList.Parent = ScrollFrame

ScrollFrame.ChildAdded:Connect(function()
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, ContentList.AbsoluteContentSize.Y)
end)
ScrollFrame.ChildRemoved:Connect(function()
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, ContentList.AbsoluteContentSize.Y)
end)

-- ============================================================================
-- Funções auxiliares de UI
-- ============================================================================
local function CreateToggle(parent, text, configKey, default)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(220,220,220)
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0, 200, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(0, 48, 0, 24)
    toggleFrame.Position = UDim2.new(1, -58, 0.5, -12)
    toggleFrame.BackgroundColor3 = default and Color3.fromRGB(80,160,255) or Color3.fromRGB(80,80,80)
    toggleFrame.BorderSizePixel = 0
    toggleFrame.Parent = frame
    Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = default and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel = 0
    knob.Parent = toggleFrame
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local state = default or false
    local function setState(val)
        state = val
        Config[configKey] = val
        local posGoal = val and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
        local colorGoal = val and Color3.fromRGB(80,160,255) or Color3.fromRGB(80,80,80)
        TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = posGoal}):Play()
        TweenService:Create(toggleFrame, TweenInfo.new(0.2), {BackgroundColor3 = colorGoal}):Play()
        -- Aplica mudanças
        if Config.BoostEnabled then
            ApplyBoost()
        end
        -- Gerencia stretch separadamente
        if configKey == "StretchScreen" then
            if val then StartStretch() else StopStretch() end
        end
    end

    local function onClick()
        setState(not state)
    end
    toggleFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            onClick()
        end
    end)
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            onClick()
        end
    end)

    return {
        SetState = setState,
        GetState = function() return state end
    }
end

local function CreateSlider(parent, text, min, max, default, callback, step)
    step = step or 0.05
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Text = text .. ": " .. string.format("%.2f", default)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(220,220,220)
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0, 180, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(0, 180, 0, 6)
    sliderFrame.Position = UDim2.new(1, -190, 0.5, -3)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(60,60,70)
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Parent = frame
    Instance.new("UICorner", sliderFrame).CornerRadius = UDim.new(0,3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(120,180,255)
    fill.BorderSizePixel = 0
    fill.Parent = sliderFrame
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0,3)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new((default - min) / (max - min), -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel = 0
    knob.Parent = sliderFrame
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local value = default
    local function updateDisplay()
        label.Text = text .. ": " .. string.format("%.2f", value)
    end

    local function setValueFromPosition(input)
        local relX = (input.Position.X - sliderFrame.AbsolutePosition.X) / sliderFrame.AbsoluteSize.X
        relX = math.clamp(relX, 0, 1)
        local raw = min + relX * (max - min)
        value = math.floor(raw / step + 0.5) * step
        value = math.clamp(value, min, max)
        fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
        knob.Position = UDim2.new((value - min) / (max - min), -7, 0.5, -7)
        updateDisplay()
        callback(value)
    end

    local dragging = false
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setValueFromPosition(input)
        end
    end)
    sliderFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            setValueFromPosition(input)
            dragging = true
        end
    end)

    return {
        SetValue = function(val)
            value = math.clamp(val, min, max)
            fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
            knob.Position = UDim2.new((value - min) / (max - min), -7, 0.5, -7)
            updateDisplay()
        end,
        GetValue = function() return value end
    }
end

-- ============================================================================
-- Construção da UI
-- ============================================================================
-- Toggle Boost
local boostFrame = Instance.new("Frame")
boostFrame.Size = UDim2.new(1, 0, 0, 50)
boostFrame.BackgroundTransparency = 1
boostFrame.Parent = ScrollFrame

local boostLabel = Instance.new("TextLabel")
boostLabel.Text = "Modo Boost"
boostLabel.Font = Enum.Font.GothamBold
boostLabel.TextSize = 16
boostLabel.TextColor3 = Color3.fromRGB(255,255,255)
boostLabel.BackgroundTransparency = 1
boostLabel.Size = UDim2.new(0, 150, 1, 0)
boostLabel.Position = UDim2.new(0, 5, 0, 0)
boostLabel.TextXAlignment = Enum.TextXAlignment.Left
boostLabel.Parent = boostFrame

local boostToggle = Instance.new("Frame")
boostToggle.Size = UDim2.new(0, 48, 0, 24)
boostToggle.Position = UDim2.new(1, -58, 0.5, -12)
boostToggle.BackgroundColor3 = Color3.fromRGB(80,80,80)
boostToggle.BorderSizePixel = 0
boostToggle.Parent = boostFrame
Instance.new("UICorner", boostToggle).CornerRadius = UDim.new(1,0)

local boostKnob = Instance.new("Frame")
boostKnob.Size = UDim2.new(0, 20, 0, 20)
boostKnob.Position = UDim2.new(0, 2, 0.5, -10)
boostKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
boostKnob.BorderSizePixel = 0
boostKnob.Parent = boostToggle
Instance.new("UICorner", boostKnob).CornerRadius = UDim.new(1,0)

local boostState = false
local function setBoostState(val)
    boostState = val
    Config.BoostEnabled = val
    local posGoal = val and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    local colorGoal = val and Color3.fromRGB(80,160,255) or Color3.fromRGB(80,80,80)
    TweenService:Create(boostKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = posGoal}):Play()
    TweenService:Create(boostToggle, TweenInfo.new(0.2), {BackgroundColor3 = colorGoal}):Play()
    if val then
        ApplyBoost()
    else
        RevertBoost()
        StopStretch() -- se o stretch estiver ativo, para (mas o toggle de stretch é independente)
    end
end

local function onBoostClick()
    setBoostState(not boostState)
end
boostToggle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        onBoostClick()
    end
end)
boostKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        onBoostClick()
    end
end)

-- Toggles individuais
local toggleKeys = {
    {key="DisableShadows", label="Desativar Sombras"},
    {key="DisablePostProcessing", label="Desativar Pós-Processamento"},
    {key="LowQuality", label="Modo Baixa Qualidade"},
    {key="DisableWater", label="Desativar Água"},
    {key="DisableParticles", label="Desativar Partículas"},
    {key="RemoveDecals", label="Remover Decals"},
    {key="PlasticMaterials", label="Materiais Plásticos / Sem Reflexo"},
    {key="DisableExplosions", label="Desativar Explosões"},
    {key="BlurTextures", label="Borrar Texturas"},
    {key="StretchScreen", label="Esticar Tela (vertical)"},
}
local toggles = {}
for _, t in ipairs(toggleKeys) do
    toggles[t.key] = CreateToggle(ScrollFrame, t.label, t.key, false)
end

-- Slider Stretch Factor
local stretchSlider = CreateSlider(ScrollFrame, "Fator de Esticamento", 0.50, 1.50, Config.StretchFactor, function(val)
    Config.StretchFactor = val
    -- Se o stretch estiver ativo, o próximo frame aplica automaticamente
end, 0.05)

-- Botão Aplicar FFlags
local ffBtn = Instance.new("TextButton")
ffBtn.Size = UDim2.new(1, -20, 0, 36)
ffBtn.Position = UDim2.new(0, 10, 0, 10)
ffBtn.Text = "Aplicar FFlags"
ffBtn.Font = Enum.Font.GothamBold
ffBtn.TextSize = 14
ffBtn.BackgroundColor3 = Color3.fromRGB(60,60,90)
ffBtn.BorderSizePixel = 0
ffBtn.Parent = ScrollFrame
Instance.new("UICorner", ffBtn).CornerRadius = UDim.new(0,6)
ffBtn.MouseButton1Click:Connect(function()
    local setfflag = setfflag
    if not setfflag then
        ffBtn.Text = "setfflag indisponível"
        task.wait(2)
        ffBtn.Text = "Aplicar FFlags"
        return
    end
    local flags = {
        ["DFIntDebugTextureManagerSkipMips"] = "10",
        ["DFIntTextureCompositorActiveJobs"] = "0",
        ["DFIntPerformanceControlTextureQualityBestUtility"] = "-1",
        ["DFIntCSGLevelOfDetailSwitchingDistanceL23"] = "0",
        ["FFlagDebugGraphicsPreferD3D11"] = "True",
        ["FIntRenderShadowmapBias"] = "0",
        ["FFlagDisablePostFx"] = "True",
        ["FFlagDisableParticles"] = "True",
        ["FFlagDisableDecals"] = "True",
        ["FFlagNoShadows"] = "True",
        ["FFlagReduceTextureMemory"] = "True",
        ["FFlagForceTextureReduction"] = "True",
    }
    local count = 0
    for k, v in pairs(flags) do
        local ok, err = pcall(function() setfflag(k, v) end)
        if ok then count = count + 1 end
    end
    ffBtn.Text = "FFlags: " .. count .. "/" .. table.getn(flags)
    task.wait(2)
    ffBtn.Text = "Aplicar FFlags"
    Config.ApplyFFlags = true
    if Config.BoostEnabled then ApplyBoost() end
end)

-- Botão Restaurar Padrões
local restoreBtn = Instance.new("TextButton")
restoreBtn.Size = UDim2.new(1, -20, 0, 36)
restoreBtn.Position = UDim2.new(0, 10, 0, 56)
restoreBtn.Text = "Restaurar Padrões"
restoreBtn.Font = Enum.Font.GothamBold
restoreBtn.TextSize = 14
restoreBtn.BackgroundColor3 = Color3.fromRGB(90,60,60)
restoreBtn.BorderSizePixel = 0
restoreBtn.Parent = ScrollFrame
Instance.new("UICorner", restoreBtn).CornerRadius = UDim.new(0,6)
restoreBtn.MouseButton1Click:Connect(function()
    setBoostState(false)
    for key, toggle in pairs(toggles) do
        toggle:SetState(false)
        Config[key] = false
    end
    Config.ApplyFFlags = false
    Config.StretchFactor = 0.65
    stretchSlider:SetValue(0.65)
    StopStretch()
    -- Não restauramos CFrame para não travar.
end)

-- ============================================================================
-- Controles de janela
-- ============================================================================
local minimized = false
local originalHeight = Container.Size.Y.Offset

MinimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        Container:TweenSize(UDim2.new(0, 500, 0, 36), "Out", "Quad", 0.3)
    else
        Container:TweenSize(UDim2.new(0, 500, 0, originalHeight), "Out", "Quad", 0.3)
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui.Enabled = false
end)

-- Arrastar
local dragging = false
local dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = UserInputService:GetMouseLocation()
        startPos = Container.Position
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = UserInputService:GetMouseLocation() - dragStart
        Container.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                       startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ============================================================================
-- Inicialização
-- ============================================================================
SaveOriginalState()

-- Se o Boost estiver ativo no Config (caso tenha perfil), aplica
-- (neste exemplo simples, começa desativado)
setBoostState(false)

print("FPS Booster Pro carregado com sucesso!")
