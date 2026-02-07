--[[
    Blade Ball - Simple AutoPlay
    Одна кнопка - полная автоматизация!
]]

-- Ждем загрузки персонажа
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end

wait(1) -- Дополнительная задержка для полной загрузки

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

-- Настройки
local Settings = {
    AutoPlayEnabled = false,
    ParryDistance = 18,
    ParryTiming = 0.55, -- Базовый тайминг (будет адаптироваться)
    UseAbilities = true, -- Автоиспользование способностей
    AbilityCooldown = 1.5, -- Минимальная задержка между использованием способностей
    AggressiveMode = false, -- Режим агрессивного нацеливания
    TargetPlayer = nil, -- Цель для агрессивного режима
    
    -- ESP настройки
    ESPEnabled = true,
    ShowBallTrajectory = true,
    ShowParryCircle = true,
    ShowPlayerESP = true,
    
    -- UI настройки
    Theme = "Dark", -- Dark, Light, Neon
    
    -- Режимы (AUTO = ИИ решает сам, ON = всегда, OFF = никогда)
    ChaosMode = "AUTO", -- "AUTO", "ON", "OFF"
    TrickMode = "AUTO", -- "AUTO", "ON", "OFF"
}

-- Темы оформления
local Themes = {
    Dark = {
        Background = Color3.fromRGB(20, 20, 25),
        Primary = Color3.fromRGB(255, 50, 50),
        Secondary = Color3.fromRGB(50, 255, 100),
        Text = Color3.fromRGB(255, 255, 255),
        Accent = Color3.fromRGB(100, 200, 255),
    },
    Light = {
        Background = Color3.fromRGB(240, 240, 245),
        Primary = Color3.fromRGB(220, 50, 50),
        Secondary = Color3.fromRGB(50, 200, 80),
        Text = Color3.fromRGB(20, 20, 20),
        Accent = Color3.fromRGB(70, 150, 255),
    },
    Neon = {
        Background = Color3.fromRGB(10, 10, 15),
        Primary = Color3.fromRGB(255, 0, 255),
        Secondary = Color3.fromRGB(0, 255, 255),
        Text = Color3.fromRGB(255, 255, 255),
        Accent = Color3.fromRGB(255, 255, 0),
    },
}

-- Адаптивные настройки парирования (более агрессивные)
local AdaptiveParry = {
    VeryFast = {speed = 150, timing = 0.70},  -- Очень быстрый мяч - парируем НАМНОГО раньше
    Fast = {speed = 100, timing = 0.62},      -- Быстрый мяч
    Normal = {speed = 50, timing = 0.55},     -- Нормальный мяч
    Slow = {speed = 0, timing = 0.50},        -- Медленный мяч
}

-- Сохраненная оригинальная скорость
local OriginalWalkSpeed = 16

-- Статистика
local Stats = {
    Parries = 0,
    Successful = 0,
    Missed = 0,
    AbilitiesUsed = 0,
    AggressiveHits = 0,
    
    -- Калибровка тайминга
    RecentParries = {}, -- Последние 10 парирований с результатами
    AverageTiming = 0.55,
    
    -- Сложные игроки
    DangerousPlayers = {}, -- {PlayerName = {curves = 0, speed = 0, hits = 0}}
}

-- Состояние
local IsParrying = false
local LastParryTime = 0
local LastAbilityTime = 0
local CurrentBall = nil
local Connections = {}
local CachedBall = nil
local LastBallCheck = 0
local CurrentAbility = "Unknown"
local AbilityType = "Unknown"

-- ESP объекты
local ESPFolder = nil
local ParryCircle = nil
local BallLine = nil
local PlayerESPs = {}
local BallSpeedLabel = nil
local ParryTimerLabel = nil
local AbilityCooldownLabel = nil

-- Предсказание траектории
local BallHistory = {} -- История позиций мяча для предсказания кривизны
local LastBallPosition = nil
local LastBallVelocity = nil

-- Типы способностей и их использование
local AbilityData = {
    -- Защитные способности (использовать когда мяч близко)
    Defensive = {
        "INVISIBILITY", "PLATFORM", "FREEZE", "FORCEFIELD", "GALE'S EDGE",
        "PULSE", "GUARDIAN ANGEL", "CALMING DEFLECTION", "FREEZE TRAP",
        "FORCE", "SERPENT SHADOW CLONE"
    },
    -- Атакующие способности (использовать перед парированием)
    Offensive = {
        "THUNDER DASH", "SHADOW STEP", "RAGING DEFLECTION", "SCOPOPHOBIA",
        "MISFORTUNE", "NINJA DASH", "SWAP", "TELEKINESIS", "PULL",
        "AERODYNAMIC SLASH", "GOLDEN BALL", "HELL HOOK", "QI-CHARGE",
        "FLASH COUNTER", "ABSOLUTE CONFIDENCE", "RAPTURE", "PHASE BYPASS",
        "DEATH SLASH", "QUANTUM ARENA", "TACT", "DRIBBLE", "TIME HOLE",
        "DRAGON SPIRIT", "SINGULARITY", "BUNNY LEAP", "SLASH OF DUALITY",
        "BOUNTY", "SLASHES OF FURY", "DOPPELGÄNGER", "DISPLACE"
    },
    -- Нейтральные способности (использовать в любой момент)
    Neutral = {
        "DASH", "SUPER JUMP", "QUAD JUMP", "LUCK", "WIND CLOAK", "BLINK",
        "REAPER", "MARTYRDOM", "CHIEFTAIN'S TOTEM", "BLADE TRAP",
        "INFINITY", "PHANTOM", "WAYPOINT", "TITAN", "CONTINUITY ZERO",
        "QUASAR", "ENCRYPTED CLONE", "NECROMANCER", "FRACTURE"
    },
    -- Пассивные способности (не нужно активировать)
    Passive = {
        "QUAD JUMP", "LUCK", "REAPER", "MISFORTUNE", "MARTYRDOM",
        "GOLDEN BALL", "GUARDIAN ANGEL", "TACT"
    }
}

-- Удаление старого GUI
pcall(function()
    if LocalPlayer.PlayerGui:FindFirstChild("BladeBallGUI") then
        LocalPlayer.PlayerGui:FindFirstChild("BladeBallGUI"):Destroy()
    end
end)

wait(0.3)

-- Создание GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BladeBallGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer.PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 350, 0, 350)
MainFrame.Position = UDim2.new(0.5, -175, 0.5, -175)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = MainFrame

-- Заголовок
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
Title.Text = "⚔️ BLADE BALL - AUTO PLAY"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.BorderSizePixel = 0
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = Title

-- Кнопка закрытия
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 35, 0, 35)
CloseBtn.Position = UDim2.new(1, -38, 0, 2.5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 18
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Title

local CloseBtnCorner = Instance.new("UICorner")
CloseBtnCorner.CornerRadius = UDim.new(0, 8)
CloseBtnCorner.Parent = CloseBtn

-- Главная кнопка AutoPlay
local AutoPlayBtn = Instance.new("TextButton")
AutoPlayBtn.Size = UDim2.new(1, -40, 0, 60)
AutoPlayBtn.Position = UDim2.new(0, 20, 0, 60)
AutoPlayBtn.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
AutoPlayBtn.Text = "▶️ START AUTO PLAY"
AutoPlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoPlayBtn.TextSize = 20
AutoPlayBtn.Font = Enum.Font.GothamBold
AutoPlayBtn.BorderSizePixel = 0
AutoPlayBtn.Parent = MainFrame

local AutoPlayCorner = Instance.new("UICorner")
AutoPlayCorner.CornerRadius = UDim.new(0, 10)
AutoPlayCorner.Parent = AutoPlayBtn

-- Индикатор способности
local AbilityLabel = Instance.new("TextLabel")
AbilityLabel.Size = UDim2.new(1, -40, 0, 30)
AbilityLabel.Position = UDim2.new(0, 20, 0, 130)
AbilityLabel.BackgroundColor3 = Color3.fromRGB(60, 40, 100)
AbilityLabel.Text = "🔮 Ability: Detecting..."
AbilityLabel.TextColor3 = Color3.fromRGB(200, 180, 255)
AbilityLabel.TextSize = 12
AbilityLabel.Font = Enum.Font.GothamBold
AbilityLabel.BorderSizePixel = 0
AbilityLabel.Parent = MainFrame

local AbilityCorner = Instance.new("UICorner")
AbilityCorner.CornerRadius = UDim.new(0, 8)
AbilityCorner.Parent = AbilityLabel

-- Статистика
local StatsLabel = Instance.new("TextLabel")
StatsLabel.Size = UDim2.new(1, -40, 0, 30)
StatsLabel.Position = UDim2.new(0, 20, 0, 170)
StatsLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
StatsLabel.Text = "⚔️ Parries: 0 (0%) | 🔮 Abilities: 0 | 🎯 Aggressive: 0"
StatsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatsLabel.TextSize = 10
StatsLabel.Font = Enum.Font.Gotham
StatsLabel.BorderSizePixel = 0
StatsLabel.Parent = MainFrame

local StatsCorner = Instance.new("UICorner")
StatsCorner.CornerRadius = UDim.new(0, 8)
StatsCorner.Parent = StatsLabel

-- Кнопка агрессивного режима
local AggressiveBtn = Instance.new("TextButton")
AggressiveBtn.Size = UDim2.new(1, -80, 0, 30)
AggressiveBtn.Position = UDim2.new(0, 20, 0, 210)
AggressiveBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
AggressiveBtn.Text = "🎯 Aggressive Mode: OFF"
AggressiveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AggressiveBtn.TextSize = 12
AggressiveBtn.Font = Enum.Font.GothamBold
AggressiveBtn.BorderSizePixel = 0
AggressiveBtn.Parent = MainFrame

local AggressiveCorner = Instance.new("UICorner")
AggressiveCorner.CornerRadius = UDim.new(0, 8)
AggressiveCorner.Parent = AggressiveBtn

-- Кнопка сброса цели (крестик)
local ClearTargetBtn = Instance.new("TextButton")
ClearTargetBtn.Size = UDim2.new(0, 30, 0, 30)
ClearTargetBtn.Position = UDim2.new(1, -50, 0, 210)
ClearTargetBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
ClearTargetBtn.Text = "✕"
ClearTargetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ClearTargetBtn.TextSize = 16
ClearTargetBtn.Font = Enum.Font.GothamBold
ClearTargetBtn.BorderSizePixel = 0
ClearTargetBtn.Visible = false -- Скрыт по умолчанию
ClearTargetBtn.Parent = MainFrame

local ClearTargetCorner = Instance.new("UICorner")
ClearTargetCorner.CornerRadius = UDim.new(0, 8)
ClearTargetCorner.Parent = ClearTargetBtn

-- Кнопка Chaos Mode
local ChaosBtn = Instance.new("TextButton")
ChaosBtn.Size = UDim2.new(0.48, -15, 0, 30)
ChaosBtn.Position = UDim2.new(0, 20, 0, 250)
ChaosBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
ChaosBtn.Text = "🎲 Chaos: AUTO"
ChaosBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ChaosBtn.TextSize = 11
ChaosBtn.Font = Enum.Font.GothamBold
ChaosBtn.BorderSizePixel = 0
ChaosBtn.Parent = MainFrame

local ChaosCorner = Instance.new("UICorner")
ChaosCorner.CornerRadius = UDim.new(0, 8)
ChaosCorner.Parent = ChaosBtn

-- Кнопка Trick Mode
local TrickBtn = Instance.new("TextButton")
TrickBtn.Size = UDim2.new(0.48, -15, 0, 30)
TrickBtn.Position = UDim2.new(0.52, 5, 0, 250)
TrickBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
TrickBtn.Text = "🎪 Trick: AUTO"
TrickBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TrickBtn.TextSize = 11
TrickBtn.Font = Enum.Font.GothamBold
TrickBtn.BorderSizePixel = 0
TrickBtn.Parent = MainFrame

local TrickCorner = Instance.new("UICorner")
TrickCorner.CornerRadius = UDim.new(0, 8)
TrickCorner.Parent = TrickBtn

-- Индикатор состояния
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -40, 0, 30)
StatusLabel.Position = UDim2.new(0, 20, 0, 290)
StatusLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
StatusLabel.Text = "⚪ IDLE - Waiting..."
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.TextSize = 10
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.BorderSizePixel = 0
StatusLabel.Parent = MainFrame

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 8)
StatusCorner.Parent = StatusLabel

local function GetCurrentTheme()
    return Themes[Settings.Theme] or Themes.Dark
end

-- ============ ESP ФУНКЦИИ ============

local function CreateESPFolder()
    pcall(function()
        if ESPFolder and ESPFolder.Parent then
            ESPFolder:Destroy()
        end
    end)
    
    ESPFolder = Instance.new("Folder")
    ESPFolder.Name = "BladeBallESP"
    ESPFolder.Parent = Workspace
    
    -- Проверяем что папка создалась
    if not ESPFolder or not ESPFolder.Parent then
        warn("⚠️ Failed to create ESP Folder in Workspace")
        return false
    end
    
    return true
end

local function CreateParryCircle()
    if not LocalPlayer.Character then return end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    if not ESPFolder or not ESPFolder.Parent then
        warn("⚠️ Cannot create ParryCircle: ESPFolder missing")
        return
    end
    
    pcall(function()
        if ParryCircle and ParryCircle.Parent then
            ParryCircle:Destroy()
        end
    end)
    
    -- Создаем круг парирования (упрощенная версия)
    ParryCircle = Instance.new("Part")
    ParryCircle.Name = "ParryCircle"
    ParryCircle.Size = Vector3.new(Settings.ParryDistance * 2, 0.5, Settings.ParryDistance * 2)
    ParryCircle.Anchored = true
    ParryCircle.CanCollide = false
    ParryCircle.Transparency = 0.8
    ParryCircle.Material = Enum.Material.Neon
    ParryCircle.Color = GetCurrentTheme().Secondary
    ParryCircle.Shape = Enum.PartType.Cylinder
    ParryCircle.Parent = ESPFolder
    
    -- Обновляем позицию круга
    task.spawn(function()
        while ParryCircle and ParryCircle.Parent and Settings.ESPEnabled and Settings.ShowParryCircle do
            pcall(function()
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local newHrp = LocalPlayer.Character.HumanoidRootPart
                    ParryCircle.CFrame = CFrame.new(newHrp.Position) * CFrame.Angles(0, 0, math.rad(90))
                    ParryCircle.Size = Vector3.new(0.5, Settings.ParryDistance * 2, Settings.ParryDistance * 2)
                end
            end)
            task.wait(0.1)
        end
    end)
end

local function CreateBallSpeedLabel()
    pcall(function()
        if BallSpeedLabel and BallSpeedLabel.Parent then
            BallSpeedLabel:Destroy()
        end
    end)
    
    if not ESPFolder or not ESPFolder.Parent then
        warn("⚠️ Cannot create BallSpeedLabel: ESPFolder missing")
        return
    end
    
    -- Создаем BillboardGui для отображения скорости над мячом
    BallSpeedLabel = Instance.new("BillboardGui")
    BallSpeedLabel.Name = "BallSpeedLabel"
    BallSpeedLabel.AlwaysOnTop = true
    BallSpeedLabel.Size = UDim2.new(0, 100, 0, 50)
    BallSpeedLabel.StudsOffset = Vector3.new(0, 3, 0)
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 0.3
    textLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.GothamBold
    textLabel.Text = "0"
    textLabel.Parent = BallSpeedLabel
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = textLabel
    
    BallSpeedLabel.Parent = ESPFolder
end

local function CreateParryTimerLabel()
    if ParryTimerLabel then
        pcall(function() ParryTimerLabel:Destroy() end)
    end
    
    -- Создаем ScreenGui для таймера парирования
    ParryTimerLabel = Instance.new("TextLabel")
    ParryTimerLabel.Name = "ParryTimer"
    ParryTimerLabel.Size = UDim2.new(0, 200, 0, 40)
    ParryTimerLabel.Position = UDim2.new(0.5, -100, 0.15, 0)
    ParryTimerLabel.AnchorPoint = Vector2.new(0.5, 0)
    ParryTimerLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    ParryTimerLabel.BackgroundTransparency = 0.3
    ParryTimerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ParryTimerLabel.TextScaled = true
    ParryTimerLabel.Font = Enum.Font.GothamBold
    ParryTimerLabel.Text = "Ready"
    ParryTimerLabel.Visible = false
    ParryTimerLabel.Parent = LocalPlayer.PlayerGui:FindFirstChild("BladeBallGUI")
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = ParryTimerLabel
end

local function CreateAbilityCooldownLabel()
    if AbilityCooldownLabel then
        pcall(function() AbilityCooldownLabel:Destroy() end)
    end
    
    -- Создаем индикатор кулдауна способности
    AbilityCooldownLabel = Instance.new("TextLabel")
    AbilityCooldownLabel.Name = "AbilityCooldown"
    AbilityCooldownLabel.Size = UDim2.new(0, 150, 0, 30)
    AbilityCooldownLabel.Position = UDim2.new(0.5, -75, 0.2, 0)
    AbilityCooldownLabel.AnchorPoint = Vector2.new(0.5, 0)
    AbilityCooldownLabel.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
    AbilityCooldownLabel.BackgroundTransparency = 0.3
    AbilityCooldownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    AbilityCooldownLabel.TextScaled = true
    AbilityCooldownLabel.Font = Enum.Font.GothamBold
    AbilityCooldownLabel.Text = "🔮 Ready"
    AbilityCooldownLabel.Visible = false
    AbilityCooldownLabel.Parent = LocalPlayer.PlayerGui:FindFirstChild("BladeBallGUI")
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = AbilityCooldownLabel
end

local function UpdateBallSpeedLabel(ball)
    if not Settings.ESPEnabled or not ball then 
        if BallSpeedLabel then BallSpeedLabel.Adornee = nil end
        return 
    end
    
    pcall(function()
        if not BallSpeedLabel then CreateBallSpeedLabel() end
        
        BallSpeedLabel.Adornee = ball
        local speed = GetBallSpeed(ball)
        local distance = GetDistance(ball)
        local isComingToMe = IsBallComingToMe(ball)
        
        local textLabel = BallSpeedLabel:FindFirstChild("TextLabel")
        if textLabel then
            textLabel.Text = string.format("%.0f\n%.0fm", speed, distance)
            
            -- Меняем цвет в зависимости от скорости
            if speed > 150 then
                textLabel.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Красный
            elseif speed > 100 then
                textLabel.BackgroundColor3 = Color3.fromRGB(255, 165, 0) -- Оранжевый
            else
                textLabel.BackgroundColor3 = Color3.fromRGB(0, 200, 0) -- Зелёный
            end
            
            -- Мигаем если мяч летит к нам
            if isComingToMe then
                textLabel.BackgroundTransparency = (tick() % 0.5 < 0.25) and 0.1 or 0.5
            else
                textLabel.BackgroundTransparency = 0.3
            end
        end
    end)
end

local function UpdateParryTimer(ball)
    if not ball or not ParryTimerLabel then return end
    
    pcall(function()
        local distance = GetDistance(ball)
        local speed = GetBallSpeed(ball)
        local isComingToMe = IsBallComingToMe(ball)
        
        if isComingToMe and speed > 0 then
            local timeToReach = distance / speed
            ParryTimerLabel.Visible = true
            
            if timeToReach <= 0.3 then
                ParryTimerLabel.Text = "⚔️ PARRY NOW!"
                ParryTimerLabel.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            elseif timeToReach <= 0.6 then
                ParryTimerLabel.Text = string.format("🎯 %.2fs", timeToReach)
                ParryTimerLabel.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
            else
                ParryTimerLabel.Text = string.format("⏳ %.2fs", timeToReach)
                ParryTimerLabel.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
            end
        else
            ParryTimerLabel.Visible = false
        end
    end)
end

local function UpdateAbilityCooldown()
    if not AbilityCooldownLabel then return end
    
    pcall(function()
        local timeSinceLastAbility = tick() - LastAbilityTime
        local cooldownRemaining = Settings.AbilityCooldown - timeSinceLastAbility
        
        if cooldownRemaining > 0 then
            AbilityCooldownLabel.Visible = true
            AbilityCooldownLabel.Text = string.format("🔮 %.1fs", cooldownRemaining)
            AbilityCooldownLabel.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        else
            if IsPassiveAbility() then
                AbilityCooldownLabel.Visible = false
            else
                AbilityCooldownLabel.Visible = true
                AbilityCooldownLabel.Text = "🔮 READY!"
                AbilityCooldownLabel.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
            end
        end
    end)
end

local function CreateBallTrajectoryLine()
    pcall(function()
        if BallLine and BallLine.Parent then
            BallLine:Destroy()
        end
    end)
    
    if not ESPFolder or not ESPFolder.Parent then
        warn("⚠️ Cannot create BallTrajectoryLine: ESPFolder missing")
        return
    end
    
    BallLine = Instance.new("Part")
    BallLine.Name = "BallTrajectory"
    BallLine.Anchored = true
    BallLine.CanCollide = false
    BallLine.Transparency = 0.5
    BallLine.Material = Enum.Material.Neon
    BallLine.Color = GetCurrentTheme().Primary
    BallLine.Parent = ESPFolder
end

local function UpdateBallTrajectory(ball)
    if not Settings.ESPEnabled or not Settings.ShowBallTrajectory then 
        if BallLine then
            pcall(function() BallLine:Destroy() end)
            BallLine = nil
        end
        return 
    end
    if not ball or not LocalPlayer.Character then 
        if BallLine then
            BallLine.Transparency = 1 -- Скрываем линию если нет мяча
        end
        return 
    end
    
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    pcall(function()
        if not BallLine or not BallLine.Parent then 
            CreateBallTrajectoryLine() 
        end
        
        local ballPos = ball.Position
        local playerPos = hrp.Position
        local distance = (ballPos - playerPos).Magnitude
        
        -- Показываем линию только если мяч летит к нам
        local isComingToMe = IsBallComingToMe(ball)
        if isComingToMe then
            BallLine.Transparency = 0.5
            
            -- Создаем линию от мяча к игроку
            BallLine.Size = Vector3.new(0.2, 0.2, distance)
            BallLine.CFrame = CFrame.new(ballPos, playerPos) * CFrame.new(0, 0, -distance / 2)
            
            -- Меняем цвет в зависимости от дистанции
            if distance < 15 then
                BallLine.Color = Color3.fromRGB(255, 0, 0) -- Красный - опасно
            elseif distance < 30 then
                BallLine.Color = Color3.fromRGB(255, 255, 0) -- Желтый - внимание
            else
                BallLine.Color = Color3.fromRGB(0, 255, 0) -- Зеленый - безопасно
            end
        else
            BallLine.Transparency = 1 -- Скрываем если мяч не к нам
        end
    end)
end

local function CreatePlayerESP(player)
    if not Settings.ESPEnabled or not Settings.ShowPlayerESP then return end
    if player == LocalPlayer then return end
    if not player.Character then return end
    
    pcall(function()
        -- Удаляем старый ESP если есть
        if PlayerESPs[player.Name] then
            PlayerESPs[player.Name]:Destroy()
        end
        
        local char = player.Character
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        -- Создаем подсветку
        local highlight = Instance.new("Highlight")
        highlight.Name = "PlayerESP"
        highlight.Adornee = char
        highlight.FillTransparency = 0.7
        highlight.OutlineTransparency = 0.3
        
        -- УМНАЯ ЦВЕТОВАЯ ИНДИКАЦИЯ
        if Settings.AggressiveMode and Settings.TargetPlayer == player then
            -- Текущая цель - КРАСНЫЙ
            highlight.FillColor = Color3.fromRGB(255, 0, 0)
            highlight.OutlineColor = Color3.fromRGB(255, 100, 100)
            highlight.FillTransparency = 0.5 -- Более яркий
        elseif IsDangerousPlayer(player.Name) then
            -- Опасный игрок (делает кривые удары) - ОРАНЖЕВЫЙ
            highlight.FillColor = Color3.fromRGB(255, 100, 0)
            highlight.OutlineColor = Color3.fromRGB(255, 150, 50)
        elseif Stats.DangerousPlayers[player.Name] and Stats.DangerousPlayers[player.Name].avgSpeed < 80 then
            -- Слабый игрок (медленные удары) - ЗЕЛЁНЫЙ
            highlight.FillColor = Color3.fromRGB(0, 255, 0)
            highlight.OutlineColor = Color3.fromRGB(100, 255, 100)
        else
            -- Обычный игрок - СИНИЙ
            highlight.FillColor = GetCurrentTheme().Accent
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        end
        
        highlight.Parent = char
        PlayerESPs[player.Name] = highlight
    end)
end

local function UpdatePlayerESPs()
    if not Settings.ESPEnabled or not Settings.ShowPlayerESP then return end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            CreatePlayerESP(player)
        end
    end
end

local function ClearESP()
    pcall(function()
        if ESPFolder then ESPFolder:Destroy() end
        if ParryCircle then ParryCircle:Destroy() end
        if BallLine then BallLine:Destroy() end
        if BallSpeedLabel then BallSpeedLabel:Destroy() end
        if ParryTimerLabel then ParryTimerLabel:Destroy() end
        if AbilityCooldownLabel then AbilityCooldownLabel:Destroy() end
        for _, esp in pairs(PlayerESPs) do
            pcall(function() esp:Destroy() end)
        end
        PlayerESPs = {}
        ESPFolder = nil
        ParryCircle = nil
        BallLine = nil
        BallSpeedLabel = nil
        ParryTimerLabel = nil
        AbilityCooldownLabel = nil
    end)
end

local function InitializeESP()
    pcall(function()
        ClearESP() -- Сначала очищаем старые ESP
        CreateESPFolder()
        
        if not ESPFolder or not ESPFolder.Parent then
            warn("⚠️ Failed to create ESP Folder")
            return
        end
        
        if Settings.ShowParryCircle then
            CreateParryCircle()
        end
        if Settings.ShowBallTrajectory then
            CreateBallTrajectoryLine()
        end
        CreateBallSpeedLabel()
        CreateParryTimerLabel()
        CreateAbilityCooldownLabel()
        UpdatePlayerESPs()
        
        print("✅ ESP Initialized successfully")
    end)
end

local function SetupCharacterRespawnHandler()
    -- Очищаем ESP при смерти/респавне персонажа
    if LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.Died:Connect(function()
                print("💀 Character died - Clearing ESP")
                ClearESP()
                task.wait(1)
                if Settings.AutoPlayEnabled and Settings.ESPEnabled then
                    InitializeESP()
                end
            end)
        end
    end
    
    -- Следим за новым персонажем
    LocalPlayer.CharacterAdded:Connect(function(character)
        print("🔄 Character respawned - Reinitializing ESP")
        task.wait(1) -- Ждем полной загрузки персонажа
        if Settings.AutoPlayEnabled and Settings.ESPEnabled then
            ClearESP()
            InitializeESP()
        end
        
        -- Подключаем обработчик смерти для нового персонажа
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            humanoid.Died:Connect(function()
                print("💀 Character died - Clearing ESP")
                ClearESP()
                task.wait(1)
                if Settings.AutoPlayEnabled and Settings.ESPEnabled then
                    InitializeESP()
                end
            end)
        end
    end)
end

-- ============ ФУНКЦИИ ============

local function DetectAbility()
    local abilityName = "Unknown"
    local abilityType = "Unknown"
    
    pcall(function()
        -- Пробуем найти способность в ReplicatedStorage
        local RS = game:GetService("ReplicatedStorage")
        if RS:FindFirstChild("Remotes") then
            local remotes = RS.Remotes
            -- Ищем информацию о способности игрока
            if remotes:FindFirstChild("AbilityInfo") then
                local info = remotes.AbilityInfo
                -- Здесь может быть информация о способности
            end
        end
        
        -- Пробуем найти в PlayerGui
        if LocalPlayer.PlayerGui:FindFirstChild("Hotbar") then
            local hotbar = LocalPlayer.PlayerGui.Hotbar
            if hotbar:FindFirstChild("Block") and hotbar.Block:FindFirstChild("Ability") then
                local abilityFrame = hotbar.Block.Ability
                -- Ищем название способности
                for _, child in pairs(abilityFrame:GetDescendants()) do
                    if child:IsA("TextLabel") or child:IsA("TextButton") then
                        local text = child.Text:upper()
                        -- Проверяем все известные способности
                        for type, abilities in pairs(AbilityData) do
                            for _, ability in pairs(abilities) do
                                if text:find(ability) or ability:find(text) then
                                    abilityName = ability
                                    abilityType = type
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Альтернативный метод: проверяем через Character
        if LocalPlayer.Character then
            for _, child in pairs(LocalPlayer.Character:GetChildren()) do
                if child:IsA("Tool") or child.Name:find("Ability") then
                    local toolName = child.Name:upper()
                    for type, abilities in pairs(AbilityData) do
                        for _, ability in pairs(abilities) do
                            if toolName:find(ability) or ability:find(toolName) then
                                abilityName = ability
                                abilityType = type
                                return
                            end
                        end
                    end
                end
            end
        end
    end)
    
    CurrentAbility = abilityName
    AbilityType = abilityType
    
    return abilityName, abilityType
end

local function IsPassiveAbility()
    for _, ability in pairs(AbilityData.Passive) do
        if CurrentAbility == ability then
            return true
        end
    end
    return false
end

local function GetAdaptiveTiming(speed)
    -- Адаптивный тайминг в зависимости от скорости мяча
    local baseTiming
    if speed >= AdaptiveParry.VeryFast.speed then
        baseTiming = AdaptiveParry.VeryFast.timing
    elseif speed >= AdaptiveParry.Fast.speed then
        baseTiming = AdaptiveParry.Fast.timing
    elseif speed >= AdaptiveParry.Normal.speed then
        baseTiming = AdaptiveParry.Normal.timing
    else
        baseTiming = AdaptiveParry.Slow.timing
    end
    
    -- Применяем калибровку на основе успешности
    local calibratedTiming = baseTiming + (Stats.AverageTiming - 0.55)
    
    return math.clamp(calibratedTiming, 0.4, 0.75)
end

local function UpdateParryCalibration(success, actualTiming, speed)
    -- Добавляем результат в историю
    table.insert(Stats.RecentParries, {
        success = success,
        timing = actualTiming,
        speed = speed,
        timestamp = tick()
    })
    
    -- Храним только последние 10 парирований
    if #Stats.RecentParries > 10 then
        table.remove(Stats.RecentParries, 1)
    end
    
    -- Рассчитываем средний успешный тайминг
    local successfulTimings = {}
    for _, parry in ipairs(Stats.RecentParries) do
        if parry.success then
            table.insert(successfulTimings, parry.timing)
        end
    end
    
    if #successfulTimings > 0 then
        local sum = 0
        for _, timing in ipairs(successfulTimings) do
            sum = sum + timing
        end
        Stats.AverageTiming = sum / #successfulTimings
        
        -- Если слишком много промахов, увеличиваем тайминг
        local missRate = Stats.Missed / math.max(Stats.Parries, 1)
        if missRate > 0.3 then
            Stats.AverageTiming = Stats.AverageTiming + 0.05
        end
    end
end

local function TrackDangerousPlayer(playerName, ball)
    if not playerName or playerName == "Unknown" then return end
    
    if not Stats.DangerousPlayers[playerName] then
        Stats.DangerousPlayers[playerName] = {
            curves = 0,
            avgSpeed = 0,
            hits = 0,
            totalSpeed = 0
        }
    end
    
    local player = Stats.DangerousPlayers[playerName]
    player.hits = player.hits + 1
    
    local speed = GetBallSpeed(ball)
    player.totalSpeed = player.totalSpeed + speed
    player.avgSpeed = player.totalSpeed / player.hits
    
    -- Определяем кривизну по истории позиций
    if #BallHistory >= 3 then
        local curve = CalculateBallCurve()
        if curve > 0.3 then
            player.curves = player.curves + 1
        end
    end
end

local function IsDangerousPlayer(playerName)
    if not playerName or not Stats.DangerousPlayers[playerName] then 
        return false 
    end
    
    local player = Stats.DangerousPlayers[playerName]
    -- Игрок опасен если делает много кривых ударов или очень быстрые
    return (player.curves / math.max(player.hits, 1)) > 0.5 or player.avgSpeed > 150
end

local function CalculateBallCurve()
    if #BallHistory < 3 then return 0 end
    
    -- Берем последние 3 позиции
    local p1 = BallHistory[#BallHistory - 2]
    local p2 = BallHistory[#BallHistory - 1]
    local p3 = BallHistory[#BallHistory]
    
    -- Вычисляем ожидаемую позицию (прямая линия)
    local expectedPos = p2 + (p2 - p1)
    
    -- Вычисляем отклонение от прямой
    local deviation = (p3 - expectedPos).Magnitude
    
    return deviation
end

local function PredictBallPositionWithCurve(ball)
    if not ball then return nil end
    
    local ballPos = ball.Position
    local ballVel = ball.AssemblyLinearVelocity or ball.Velocity or Vector3.new()
    
    -- Добавляем текущую позицию в историю
    table.insert(BallHistory, ballPos)
    if #BallHistory > 5 then
        table.remove(BallHistory, 1)
    end
    
    -- Если недостаточно данных, используем простое предсказание
    if #BallHistory < 3 then
        return ballPos + (ballVel * 0.5)
    end
    
    -- Вычисляем кривизну
    local curve = CalculateBallCurve()
    
    -- Предсказываем с учетом кривизны
    local straightPrediction = ballPos + (ballVel * 0.5)
    
    -- Если есть кривизна, корректируем предсказание
    if curve > 0.1 then
        local p1 = BallHistory[#BallHistory - 2]
        local p2 = BallHistory[#BallHistory - 1]
        local curveDirection = (ballPos - p2) - (p2 - p1)
        
        -- Добавляем кривизну к предсказанию
        return straightPrediction + (curveDirection * 0.5)
    end
    
    return straightPrediction
end

local function GetAllPlayers()
    local playersList = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
            if player.Character.Humanoid.Health > 0 then
                table.insert(playersList, player)
            end
        end
    end
    return playersList
end

local function GetClosestPlayer()
    if not LocalPlayer.Character then return nil end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local closestPlayer = nil
    local closestDistance = math.huge
    
    for _, player in pairs(GetAllPlayers()) do
        local targetHrp = player.Character:FindFirstChild("HumanoidRootPart")
        if targetHrp then
            local distance = (hrp.Position - targetHrp.Position).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                closestPlayer = player
            end
        end
    end
    
    return closestPlayer
end

local function PredictBallTrajectory(ball)
    if not ball then return nil end
    
    local ballPos = ball.Position
    local ballVel = ball.AssemblyLinearVelocity or ball.Velocity or Vector3.new()
    
    -- Предсказываем позицию через 0.5 секунды
    local predictedPos = ballPos + (ballVel * 0.5)
    
    -- Находим ближайшего игрока к предсказанной позиции
    local closestPlayer = nil
    local closestDist = math.huge
    
    for _, player in pairs(GetAllPlayers()) do
        local targetHrp = player.Character:FindFirstChild("HumanoidRootPart")
        if targetHrp then
            local dist = (predictedPos - targetHrp.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestPlayer = player
            end
        end
    end
    
    return closestPlayer, predictedPos
end

local function UpdateStats()
    local successRate = Stats.Parries > 0 and math.floor((Stats.Successful / Stats.Parries) * 100) or 0
    StatsLabel.Text = string.format("⚔️ %d (%.0f%%) | 🔮 %d | 🎯 %d | ⏱️ %.2f",
        Stats.Parries, successRate, Stats.AbilitiesUsed, Stats.AggressiveHits, Stats.AverageTiming)
end

local function GetBall()
    -- Кэшируем мяч на 0.1 секунды чтобы не искать каждый раз
    local now = tick()
    if CachedBall and (now - LastBallCheck) < 0.1 then
        return CachedBall
    end
    
    LastBallCheck = now
    
    local ballsFolder = Workspace:FindFirstChild("Balls")
    if ballsFolder then
        for _, ball in pairs(ballsFolder:GetChildren()) do
            if ball:GetAttribute("realBall") == true or ball:IsA("BasePart") then
                CachedBall = ball
                return ball
            end
        end
        if #ballsFolder:GetChildren() > 0 then
            CachedBall = ballsFolder:GetChildren()[1]
            return CachedBall
        end
    end
    
    CachedBall = nil
    return nil
end

local function GetDistance(ball)
    if not ball or not LocalPlayer.Character then return math.huge end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return math.huge end
    return (ball.Position - hrp.Position).Magnitude
end

local function GetBallSpeed(ball)
    if not ball then return 0 end
    -- Пробуем разные способы получить скорость
    local velocity = nil
    
    -- Способ 1: zoomies (используется в игре)
    pcall(function()
        if ball:FindFirstChild("zoomies") and ball.zoomies:FindFirstChild("VectorVelocity") then
            velocity = ball.zoomies.VectorVelocity.Magnitude
        end
    end)
    
    -- Способ 2: AssemblyLinearVelocity
    if not velocity then
        pcall(function()
            velocity = ball.AssemblyLinearVelocity.Magnitude
        end)
    end
    
    -- Способ 3: Velocity
    if not velocity then
        pcall(function()
            velocity = ball.Velocity.Magnitude
        end)
    end
    
    return velocity or 0
end

local function IsBallComingToMe(ball)
    if not ball then return false end
    local target = ball:GetAttribute("target")
    if target then
        return target == LocalPlayer.Name
    end
    -- Альтернативный метод через скорость
    if not LocalPlayer.Character then return false end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local distance = GetDistance(ball)
    if distance < 30 then
        local velocity = ball.AssemblyLinearVelocity or ball.Velocity or Vector3.new()
        if velocity.Magnitude > 0 then
            local direction = velocity.Unit
            local toBall = (hrp.Position - ball.Position).Unit
            return direction:Dot(toBall) > 0.5
        end
    end
    return false
end

local function ShouldParry(ball)
    if not ball or not LocalPlayer.Character then return false end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local distance = GetDistance(ball)
    local speed = GetBallSpeed(ball)
    
    -- Если скорость слишком маленькая, используем старый метод
    if speed < 10 then
        return distance <= Settings.ParryDistance + 5 -- Увеличил запас
    end
    
    -- МАКСИМАЛЬНО АГРЕССИВНЫЙ РАСЧЕТ для 100% попадания
    local adaptiveTiming = GetAdaptiveTiming(speed)
    local timeToReach = distance / speed
    
    -- Проверяем кто отправил мяч
    local ballOwner = ball:GetAttribute("target")
    local previousOwner = ball:GetAttribute("from") or "Unknown"
    
    -- Если игрок опасный (делает кривые удары), парируем НАМНОГО раньше
    if IsDangerousPlayer(previousOwner) then
        adaptiveTiming = adaptiveTiming + 0.12 -- Увеличил с 0.08
        print(string.format("⚠️ Dangerous player detected: %s - Adjusting timing", previousOwner))
    end
    
    -- Если обнаружена кривизна траектории, парируем раньше
    local curve = CalculateBallCurve()
    if curve > 0.3 then
        adaptiveTiming = adaptiveTiming + 0.08 -- Увеличил с 0.05
        print(string.format("🌀 Curve detected: %.2f - Adjusting timing", curve))
    end
    
    -- КРИТИЧЕСКИЕ ПРОВЕРКИ для 100% попадания
    
    -- 1. Если мяч ОЧЕНЬ быстрый и близко - парируем НЕМЕДЛЕННО
    if speed > 180 and distance < 30 then
        print("🚨 CRITICAL: Very fast ball close!")
        return true
    end
    
    -- 2. Если мяч супер быстрый (>150), добавляем БОЛЬШОЙ запас
    if speed > 150 then
        adaptiveTiming = adaptiveTiming + 0.15 -- Увеличил с 0.1
    end
    
    -- 3. Если мяч быстрый (>100), добавляем запас
    if speed > 100 then
        adaptiveTiming = adaptiveTiming + 0.08
    end
    
    -- 4. Дополнительная проверка по дистанции (страховка)
    if distance < 20 then
        return true
    end
    
    -- 5. Основная проверка с увеличенным запасом
    return timeToReach <= adaptiveTiming
end

local function UseAbility()
    if not Settings.UseAbilities then return false end
    if tick() - LastAbilityTime < Settings.AbilityCooldown then return false end
    if IsPassiveAbility() then 
        print("🔮 Ability is PASSIVE, no need to activate")
        return false 
    end
    
    LastAbilityTime = tick()
    
    task.spawn(function()
        pcall(function()
            -- Нажимаем E для активации способности
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            
            Stats.AbilitiesUsed = Stats.AbilitiesUsed + 1
            print(string.format("🔮 Used ability: %s (%s)", CurrentAbility, AbilityType))
            UpdateStats()
        end)
    end)
    
    return true
end

local function ShouldUseAbility(ball)
    if not ball or not Settings.UseAbilities then return false end
    if tick() - LastAbilityTime < Settings.AbilityCooldown then return false end
    if IsPassiveAbility() then return false end
    
    local distance = GetDistance(ball)
    local speed = GetBallSpeed(ball)
    local isComingToMe = IsBallComingToMe(ball)
    
    if not isComingToMe then return false end
    
    -- Проверяем опасность ситуации
    local isDangerous = speed > 150 or distance < 15
    local isVeryDangerous = speed > 200 or distance < 10
    
    -- ПРИОРИТЕТ 1: Критическая ситуация - используем любую способность
    if isVeryDangerous then
        return true
    end
    
    -- ПРИОРИТЕТ 2: Используем способность в зависимости от типа
    if AbilityType == "Defensive" then
        -- Защитные: используем когда мяч близко и быстрый
        if isDangerous then
            return true
        end
        if distance < 20 and speed > 80 then
            return true
        end
        if distance < 12 then
            return true
        end
    elseif AbilityType == "Offensive" then
        -- Атакующие: используем для усиления удара
        -- Используем чаще если в агрессивном режиме
        if Settings.AggressiveMode and Settings.TargetPlayer then
            if distance < 35 and speed > 50 then
                return true
            end
        end
        
        -- Обычное использование
        if distance < 30 and distance > 15 and speed > 50 then
            return true
        end
        if speed > 120 and distance < 35 then
            return true
        end
        -- Случайно 20% шанс (увеличил с 15%)
        if distance < 40 and math.random() > 0.8 then
            return true
        end
    elseif AbilityType == "Neutral" then
        -- Нейтральные: используем умеренно
        if isDangerous then
            return true
        end
        if distance < 35 and math.random() > 0.75 then
            return true
        end
    end
    
    -- ПРИОРИТЕТ 3: Комбо с парированием
    local timeToReach = speed > 0 and (distance / speed) or 999
    if timeToReach <= 0.8 and timeToReach > 0.5 and speed > 100 then
        return true
    end
    
    return false
end

local function Parry()
    if IsParrying then return end
    if tick() - LastParryTime < 0.2 then return end -- Уменьшил кулдаун для быстрого повтора
    
    IsParrying = true
    local parryStartTime = tick()
    LastParryTime = parryStartTime
    
    task.spawn(function()
        local success = false
        local ball = GetBall()
        local parrySpeed = ball and GetBallSpeed(ball) or 0
        local parryDistance = ball and GetDistance(ball) or 0
        local ballOwner = ball and (ball:GetAttribute("from") or "Unknown") or "Unknown"
        
        pcall(function()
            if ball and LocalPlayer.Character then
                local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local speed = GetBallSpeed(ball)
                    
                    -- ИИ РЕШАЕТ: использовать ли режимы
                    local useChaos = false
                    local useTrick = false
                    
                    -- Для очень быстрых мячей - пропускаем трюки и хаос
                    local skipTricks = speed > 150
                    
                    if not skipTricks then
                        -- CHAOS MODE ЛОГИКА
                        if Settings.ChaosMode == "ON" then
                            useChaos = true
                        elseif Settings.ChaosMode == "AUTO" then
                            -- ИИ решает когда использовать Chaos
                            if speed < 80 and parryDistance > 20 then
                                useChaos = math.random() > 0.6
                            elseif speed < 60 then
                                useChaos = math.random() > 0.5
                            end
                        end
                        
                        -- TRICK MODE ЛОГИКА
                        if Settings.TrickMode == "ON" then
                            useTrick = true
                        elseif Settings.TrickMode == "AUTO" then
                            -- ИИ решает когда использовать Trick
                            if speed < 90 and parryDistance > 18 and parryDistance < 35 then
                                useTrick = math.random() > 0.7
                            elseif speed < 70 and parryDistance > 15 then
                                useTrick = math.random() > 0.6
                            end
                        end
                    end
                    
                    -- РЕЖИМ ТРЮКОВ: добавляем стильные движения
                    if useTrick then
                        local tricks = {
                            function() 
                                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(360), 0)
                            end,
                            function() 
                                local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
                                if humanoid then humanoid.Jump = true end
                            end,
                            function() 
                                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(180), 0)
                                task.wait(0.05)
                                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(180), 0)
                            end,
                        }
                        local trick = tricks[math.random(1, #tricks)]
                        trick()
                        task.wait(0.1)
                    end
                    
                    -- РЕЖИМ ХАОСА: случайные непредсказуемые действия
                    if useChaos then
                        if math.random() > 0.7 then
                            local angle = math.random(-90, 90)
                            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(angle), 0)
                        end
                        local delay = math.random(0, 10) / 100
                        task.wait(delay)
                    end
                    
                    -- Предсказываем позицию с учетом кривизны
                    local predictedPos = PredictBallPositionWithCurve(ball)
                    
                    -- АГРЕССИВНЫЙ РЕЖИМ: целимся в конкретного игрока
                    if Settings.AggressiveMode and Settings.TargetPlayer then
                        local target = Settings.TargetPlayer
                        if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                            local targetHrp = target.Character.HumanoidRootPart
                            local lookPos = Vector3.new(targetHrp.Position.X, hrp.Position.Y, targetHrp.Position.Z)
                            hrp.CFrame = CFrame.new(hrp.Position, lookPos)
                            Stats.AggressiveHits = Stats.AggressiveHits + 1
                            print(string.format("🎯 Aggressive parry towards: %s", target.Name))
                        else
                            Settings.TargetPlayer = GetClosestPlayer()
                        end
                    else
                        -- Используем предсказанную позицию для более точного прицеливания
                        if predictedPos then
                            local lookPos = Vector3.new(predictedPos.X, hrp.Position.Y, predictedPos.Z)
                            hrp.CFrame = CFrame.new(hrp.Position, lookPos)
                        else
                            local lookPos = Vector3.new(ball.Position.X, hrp.Position.Y, ball.Position.Z)
                            hrp.CFrame = CFrame.new(hrp.Position, lookPos)
                        end
                    end
                    
                    -- Минимальная задержка перед парированием
                    if speed > 150 then
                        -- Нет задержки для быстрых мячей!
                    else
                        task.wait(0.01)
                    end
                end
            end
            
            -- ТРОЙНОЕ ПАРИРОВАНИЕ для 100% гарантии!
            
            -- 1. Клик мыши
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.02)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            
            -- 2. Клавиша Q
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
            
            -- 3. Дублирование клика мыши (страховка)
            task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            
            Stats.Parries = Stats.Parries + 1
            Stats.Successful = Stats.Successful + 1
            success = true
            
            local actualTiming = tick() - parryStartTime
            local timing = GetAdaptiveTiming(parrySpeed)
            
            -- Обновляем калибровку
            UpdateParryCalibration(true, actualTiming, parrySpeed)
            
            -- Отслеживаем опасного игрока
            TrackDangerousPlayer(ballOwner, ball)
            
            print(string.format("⚔️ Parried! D:%d S:%d T:%.2f Avg:%.2f Owner:%s", 
                math.floor(parryDistance), math.floor(parrySpeed), timing, Stats.AverageTiming, ballOwner))
            UpdateStats()
        end)
        
        if not success then
            Stats.Missed = Stats.Missed + 1
            local actualTiming = tick() - parryStartTime
            UpdateParryCalibration(false, actualTiming, parrySpeed)
            print("❌ MISSED! Adjusting calibration...")
            UpdateStats()
        end
        
        task.wait(0.2) -- Уменьшил для быстрого повтора
        IsParrying = false
    end)
end

local function MoveRandomly()
    if not LocalPlayer.Character then return end
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end
    
    -- УМНОЕ ПОЗИЦИОНИРОВАНИЕ
    local bestPosition = hrp.Position
    local maxDistance = 0
    
    -- Находим всех живых игроков
    local alivePlayers = GetAllPlayers()
    
    if #alivePlayers > 0 then
        -- Генерируем несколько случайных точек и выбираем лучшую
        for i = 1, 5 do
            local testPos = hrp.Position + Vector3.new(
                math.random(-25, 25),
                0,
                math.random(-25, 25)
            )
            
            -- Вычисляем минимальную дистанцию до ближайшего игрока
            local minDistToPlayer = math.huge
            for _, player in pairs(alivePlayers) do
                local playerHrp = player.Character:FindFirstChild("HumanoidRootPart")
                if playerHrp then
                    local dist = (testPos - playerHrp.Position).Magnitude
                    minDistToPlayer = math.min(minDistToPlayer, dist)
                end
            end
            
            -- Выбираем позицию с максимальной дистанцией до ближайшего игрока
            if minDistToPlayer > maxDistance then
                maxDistance = minDistToPlayer
                bestPosition = testPos
            end
        end
        
        -- Если нашли хорошую позицию (дальше 15 studs от других)
        if maxDistance > 15 then
            humanoid:MoveTo(bestPosition)
        else
            -- Обычное случайное движение
            local randomOffset = Vector3.new(
                math.random(-20, 20),
                0,
                math.random(-20, 20)
            )
            humanoid:MoveTo(hrp.Position + randomOffset)
        end
    else
        -- Если нет других игроков, двигаемся случайно
        local randomOffset = Vector3.new(
            math.random(-20, 20),
            0,
            math.random(-20, 20)
        )
        humanoid:MoveTo(hrp.Position + randomOffset)
    end
end

local function StopMoving()
    if not LocalPlayer.Character then return end
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid:Move(Vector3.new(0, 0, 0))
    end
end

-- Функция полной остановки
local function StopAutoPlay()
    print("🛑 Stopping AutoPlay...")
    
    Settings.AutoPlayEnabled = false
    IsParrying = false
    
    -- Очищаем ESP
    ClearESP()
    
    -- Останавливаем движение
    StopMoving()
    
    -- Отключаем ВСЕ соединения
    for name, connection in pairs(Connections) do
        pcall(function()
            if connection and connection.Connected then
                connection:Disconnect()
            end
        end)
    end
    Connections = {}
    
    -- Восстанавливаем ОРИГИНАЛЬНУЮ скорость
    pcall(function()
        if LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = OriginalWalkSpeed
                print("✅ WalkSpeed restored to:", OriginalWalkSpeed)
            end
        end
    end)
    
    -- Очищаем состояние
    CurrentBall = nil
    LastParryTime = 0
    
    print("⛔ AutoPlay FULLY STOPPED")
end

-- ============ ГЛАВНЫЙ ЦИКЛ ============

local function StartAutoPlay()
    print("🚀 Starting AutoPlay...")
    
    -- Определяем способность
    local ability, type = DetectAbility()
    print(string.format("🔮 Detected Ability: %s (Type: %s)", ability, type))
    
    -- Инициализируем ESP
    if Settings.ESPEnabled then
        InitializeESP()
        print("�️ ESP Initialized")
    end
    
    -- Обновляем GUI
    if IsPassiveAbility() then
        AbilityLabel.Text = string.format("🔮 Ability: %s (PASSIVE)", ability)
        AbilityLabel.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    else
        AbilityLabel.Text = string.format("🔮 Ability: %s (%s)", ability, type)
        if type == "Defensive" then
            AbilityLabel.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        elseif type == "Offensive" then
            AbilityLabel.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        else
            AbilityLabel.BackgroundColor3 = Color3.fromRGB(60, 40, 100)
        end
    end
    
    -- Сохраняем оригинальную скорость
    pcall(function()
        if LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
            if humanoid then
                OriginalWalkSpeed = humanoid.WalkSpeed
                print("💾 Saved original WalkSpeed:", OriginalWalkSpeed)
            end
        end
    end)
    
    -- МАКСИМАЛЬНО ОПТИМИЗИРОВАННЫЙ цикл парирования
    local lastCheck = 0
    local emergencyParryActive = false
    local lastBallSpeed = 0
    local lastBallDistance = math.huge
    
    Connections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not Settings.AutoPlayEnabled then return end
        
        local now = tick()
        local ball = GetBall()
        
        if not ball then 
            lastCheck = now
            return 
        end
        
        -- КЭШИРУЕМ данные для оптимизации
        local speed = GetBallSpeed(ball)
        local isComingToMe = IsBallComingToMe(ball)
        local distance = GetDistance(ball)
        
        -- ЭКСТРЕННАЯ СИСТЕМА
        if isComingToMe and distance < 12 and not IsParrying and not emergencyParryActive then
            emergencyParryActive = true
            print("🚨 EMERGENCY PARRY!")
            task.spawn(function()
                pcall(function()
                    if LocalPlayer.Character then
                        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and ball then
                            hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(ball.Position.X, hrp.Position.Y, ball.Position.Z))
                        end
                    end
                    
                    -- Тройное мгновенное парирование
                    for i = 1, 3 do
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
                        if i < 3 then task.wait(0.01) end
                    end
                end)
                task.wait(0.3)
                emergencyParryActive = false
            end)
        end
        
        -- ДИНАМИЧЕСКИЙ ИНТЕРВАЛ для максимальной скорости
        local checkInterval = 0.05
        
        if isComingToMe then
            if speed > 180 or distance < 20 then
                checkInterval = 0 -- КАЖДЫЙ КАДР!
            elseif speed > 150 then
                checkInterval = 0
            elseif speed > 120 then
                checkInterval = 0.01
            elseif speed > 100 then
                checkInterval = 0.02
            elseif speed > 80 then
                checkInterval = 0.03
            end
            
            -- Если мяч ускоряется
            if speed > lastBallSpeed + 20 then
                checkInterval = 0
            end
            
            -- Если мяч быстро приближается
            if distance < lastBallDistance - 10 then
                checkInterval = math.min(checkInterval, 0.01)
            end
        else
            checkInterval = 0.1 -- Мяч не к нам - реже
        end
        
        lastBallSpeed = speed
        lastBallDistance = distance
        
        if now - lastCheck < checkInterval then return end
        lastCheck = now
        
        pcall(function()
            local ball = GetBall()
            if not ball then 
                StatusLabel.Text = "⚪ IDLE - No ball found"
                StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                StatusLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
                return 
            end
            
            -- Обновляем ESP траектории мяча
            if Settings.ESPEnabled and Settings.ShowBallTrajectory then
                UpdateBallTrajectory(ball)
            end
            
            -- Обновляем индикаторы
            if Settings.ESPEnabled then
                UpdateBallSpeedLabel(ball)
                UpdateParryTimer(ball)
                UpdateAbilityCooldown()
            end
            
            local distance = GetDistance(ball)
            local speed = GetBallSpeed(ball)
            local isComingToMe = IsBallComingToMe(ball)
            
            -- Предсказываем траекторию
            local predictedTarget, predictedPos = PredictBallTrajectory(ball)
            
            -- Обновляем цель в агрессивном режиме
            if Settings.AggressiveMode then
                if not Settings.TargetPlayer or not Settings.TargetPlayer.Character then
                    Settings.TargetPlayer = GetClosestPlayer()
                end
                
                if Settings.TargetPlayer then
                    AggressiveBtn.Text = string.format("🎯 Target: %s", Settings.TargetPlayer.Name)
                    -- Обновляем ESP цели
                    if Settings.ESPEnabled and Settings.ShowPlayerESP then
                        CreatePlayerESP(Settings.TargetPlayer)
                    end
                end
            end
            
            if isComingToMe then
                -- Мяч летит к нам!
                local shouldParry = ShouldParry(ball)
                local shouldUseAbility = ShouldUseAbility(ball)
                local adaptiveTiming = GetAdaptiveTiming(speed)
                local timeToReach = speed > 0 and (distance / speed) or 999
                
                -- Используем способность ПЕРЕД парированием если нужно
                if shouldUseAbility and not shouldParry then
                    UseAbility()
                end
                
                if shouldParry then
                    -- ПАРИРУЕМ НЕМЕДЛЕННО!
                    local targetInfo = Settings.AggressiveMode and Settings.TargetPlayer and Settings.TargetPlayer.Name or "Auto"
                    StatusLabel.Text = string.format("⚔️ PARRY! D:%.0f S:%.0f T:%.2f→%s", distance, speed, adaptiveTiming, targetInfo)
                    StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
                    StatusLabel.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
                    
                    if not IsParrying then
                        Parry()
                    end
                elseif timeToReach <= 1.0 then
                    -- Готовимся к парированию
                    StatusLabel.Text = string.format("🎯 READY! D:%.0f S:%.0f T:%.2fs", distance, speed, timeToReach)
                    StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
                    StatusLabel.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
                else
                    -- Мяч далеко
                    StatusLabel.Text = string.format("⏳ Coming... D:%.0f S:%.0f", distance, speed)
                    StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 0)
                    StatusLabel.BackgroundColor3 = Color3.fromRGB(150, 75, 0)
                end
            else
                -- Мяч летит к другому
                local target = ball:GetAttribute("target") or "Unknown"
                local predictInfo = predictedTarget and predictedTarget.Name or "?"
                StatusLabel.Text = string.format("👀 Target: %s | Next: %s", target, predictInfo)
                StatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
                StatusLabel.BackgroundColor3 = Color3.fromRGB(40, 80, 120)
            end
        end)
    end)
    
    -- Цикл обновления ESP игроков и очистки старых линий
    Connections.ESPUpdate = task.spawn(function()
        while Settings.AutoPlayEnabled do
            pcall(function()
                if Settings.ESPEnabled then
                    if Settings.ShowPlayerESP then
                        UpdatePlayerESPs()
                    end
                    
                    -- Проверяем что ESP объекты существуют
                    if not ESPFolder or not ESPFolder.Parent then
                        print("⚠️ ESP Folder lost - Reinitializing")
                        InitializeESP()
                    end
                    
                    -- Если нет мяча, скрываем линию
                    local ball = GetBall()
                    if not ball and BallLine then
                        BallLine.Transparency = 1
                    end
                end
            end)
            task.wait(2) -- Обновляем каждые 2 секунды
        end
    end)
    
    -- Цикл умного движения
    Connections.Movement = task.spawn(function()
        while Settings.AutoPlayEnabled do
            pcall(function()
                local ball = GetBall()
                if ball then
                    local isComingToMe = IsBallComingToMe(ball)
                    local distance = GetDistance(ball)
                    
                    -- НЕ двигаемся если мяч летит к нам и близко (нужно готовиться к парированию)
                    if isComingToMe and distance < 30 then
                        -- Стоим на месте и готовимся парировать
                        StopMoving()
                        return
                    end
                    
                    -- Двигаемся если мяч НЕ летит к нам
                    if not isComingToMe then
                        if math.random() > 0.5 then
                            MoveRandomly()
                        end
                    end
                else
                    -- Если нет мяча - двигаемся активно
                    if math.random() > 0.6 then
                        MoveRandomly()
                    end
                end
            end)
            task.wait(1.5) -- Проверяем каждые 1.5 секунды (чаще чем раньше)
        end
    end)
    
    print("✅ AutoPlay STARTED!")
    print("🎮 All systems ready!")
    print("📏 Parry Distance:", Settings.ParryDistance)
    print("💨 WalkSpeed unchanged:", OriginalWalkSpeed)
    print("⚡ Optimized mode - No lag!")
end

-- ============ ОБРАБОТЧИКИ ============

ChaosBtn.MouseButton1Click:Connect(function()
    -- Переключаем режимы: AUTO -> ON -> OFF -> AUTO
    if Settings.ChaosMode == "AUTO" then
        Settings.ChaosMode = "ON"
        ChaosBtn.Text = "� Chaos: ON"
        ChaosBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
        print("🎲 Chaos Mode: ON (Always active)")
    elseif Settings.ChaosMode == "ON" then
        Settings.ChaosMode = "OFF"
        ChaosBtn.Text = "� Chaos: OFF"
        ChaosBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        print("🎲 Chaos Mode: OFF (Disabled)")
    else
        Settings.ChaosMode = "AUTO"
        ChaosBtn.Text = "🎲 Chaos: AUTO"
        ChaosBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        print("🎲 Chaos Mode: AUTO (AI decides)")
    end
end)

TrickBtn.MouseButton1Click:Connect(function()
    -- Переключаем режимы: AUTO -> ON -> OFF -> AUTO
    if Settings.TrickMode == "AUTO" then
        Settings.TrickMode = "ON"
        TrickBtn.Text = "🎪 Trick: ON"
        TrickBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
        print("🎪 Trick Mode: ON (Always active)")
    elseif Settings.TrickMode == "ON" then
        Settings.TrickMode = "OFF"
        TrickBtn.Text = "🎪 Trick: OFF"
        TrickBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        print("🎪 Trick Mode: OFF (Disabled)")
    else
        Settings.TrickMode = "AUTO"
        TrickBtn.Text = "🎪 Trick: AUTO"
        TrickBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        print("🎪 Trick Mode: AUTO (AI decides)")
    end
end)

ClearTargetBtn.MouseButton1Click:Connect(function()
    -- Выбираем новую цель
    Settings.TargetPlayer = GetClosestPlayer()
    if Settings.TargetPlayer then
        AggressiveBtn.Text = string.format("🎯 Target: %s", Settings.TargetPlayer.Name)
        print(string.format("🔄 New target: %s", Settings.TargetPlayer.Name))
    else
        AggressiveBtn.Text = "🎯 No target found"
        print("⚠️ No valid target found")
    end
end)

AggressiveBtn.MouseButton1Click:Connect(function()
    Settings.AggressiveMode = not Settings.AggressiveMode
    
    if Settings.AggressiveMode then
        AggressiveBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        AggressiveBtn.Text = "🎯 Aggressive Mode: ON"
        ClearTargetBtn.Visible = true -- Показываем крестик
        -- Выбираем ближайшего игрока как цель
        Settings.TargetPlayer = GetClosestPlayer()
        if Settings.TargetPlayer then
            AggressiveBtn.Text = string.format("🎯 Target: %s", Settings.TargetPlayer.Name)
            print(string.format("🎯 Aggressive Mode ON - Target: %s", Settings.TargetPlayer.Name))
        else
            print("🎯 Aggressive Mode ON - No target found yet")
        end
    else
        AggressiveBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        AggressiveBtn.Text = "🎯 Aggressive Mode: OFF"
        ClearTargetBtn.Visible = false -- Скрываем крестик
        Settings.TargetPlayer = nil
        print("⚪ Aggressive Mode OFF")
    end
end)

AutoPlayBtn.MouseButton1Click:Connect(function()
    Settings.AutoPlayEnabled = not Settings.AutoPlayEnabled
    
    if Settings.AutoPlayEnabled then
        AutoPlayBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        AutoPlayBtn.Text = "⏸️ STOP AUTO PLAY"
        StartAutoPlay()
    else
        AutoPlayBtn.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
        AutoPlayBtn.Text = "▶️ START AUTO PLAY"
        StopAutoPlay()
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    print("🔴 Closing Blade Ball AutoPlay...")
    
    -- Полностью останавливаем AutoPlay
    StopAutoPlay()
    
    -- Ждем чтобы всё отключилось
    task.wait(0.3)
    
    -- Удаляем GUI
    pcall(function()
        ScreenGui:Destroy()
    end)
    
    -- Финальная очистка
    pcall(function()
        for _, connection in pairs(getconnections(RunService.Heartbeat)) do
            if connection.Function then
                local info = debug.getinfo(connection.Function)
                if info and info.source and info.source:find("blade") then
                    connection:Disconnect()
                end
            end
        end
    end)
    
    print("✅ Fully closed and cleaned up!")
end)

-- Инициализация
UpdateStats()

-- Пробуем определить способность сразу
task.spawn(function()
    task.wait(2) -- Ждем загрузки игры
    local ability, type = DetectAbility()
    if ability ~= "Unknown" then
        print(string.format("🔮 Pre-detected Ability: %s (Type: %s)", ability, type))
        AbilityLabel.Text = string.format("🔮 Ability: %s (%s)", ability, type)
    end
end)

print("⚔️ Blade Ball AutoPlay loaded!")
print("📌 Click 'START AUTO PLAY' to begin")
print("🎮 Features:")
print("  • �️ Advanced ESP: Speed labels, timers, player colors")
print("  • ⚡ Ultra-fast reaction: Dynamic frame checking")
print("  • 🧠 Smart learning: Adapts to your playstyle")
print("  • � Emergency system: 100% parry guarantee")
print("  • 🎯 Smart positioning: Avoids crowds")
print("  • 🔮 Intelligent abilities: Priority-based usage")
print("  • 🎲 Chaos Mode: Unpredictable movements (AUTO/ON/OFF)")
print("  • 🎪 Trick Mode: Stylish parries (AUTO/ON/OFF)")
print("💡 AUTO mode = AI decides when to use tricks!")
