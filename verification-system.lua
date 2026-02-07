--[[
    Blade Ball - Verification System
    Discord: https://discord.gg/EFEkgZQFcQ
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

-- Настройки верификации
local VerificationSettings = {
    DiscordLink = "https://discord.gg/EFEkgZQFcQ",
    ValidKey = "V67hBYN_189BH", -- Единственный рабочий ключ
    SavedKeyFile = "BladeBall_SavedKey.txt", -- Для сохранения ключа
}

-- Проверка сохраненного ключа
local function GetSavedKey()
    local success, result = pcall(function()
        return readfile(VerificationSettings.SavedKeyFile)
    end)
    if success and result then
        return result
    end
    return nil
end

local function SaveKey(key)
    pcall(function()
        writefile(VerificationSettings.SavedKeyFile, key)
    end)
end

local function ValidateKey(key)
    if not key or key == "" then
        return false
    end
    
    -- Проверяем единственный правильный ключ
    if key == VerificationSettings.ValidKey then
        return true
    end
    
    return false
end

-- Проверяем сохраненный ключ
local savedKey = GetSavedKey()
if savedKey and ValidateKey(savedKey) then
    print("✅ Saved key validated! Loading script...")
    -- Загружаем основной скрипт
    loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/blade-ball-autoplay.lua"))()
    return
end

-- Удаляем старый GUI если есть
pcall(function()
    if LocalPlayer.PlayerGui:FindFirstChild("VerificationGUI") then
        LocalPlayer.PlayerGui:FindFirstChild("VerificationGUI"):Destroy()
    end
end)

wait(0.3)

-- Создание GUI верификации
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VerificationGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer.PlayerGui

-- Затемнение фона
local Overlay = Instance.new("Frame")
Overlay.Size = UDim2.new(1, 0, 1, 0)
Overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Overlay.BackgroundTransparency = 0.5
Overlay.BorderSizePixel = 0
Overlay.Parent = ScreenGui

-- Главный фрейм
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 450, 0, 400)
MainFrame.Position = UDim2.new(0.5, -225, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 15)
MainCorner.Parent = MainFrame

-- Градиент фона
local Gradient = Instance.new("UIGradient")
Gradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 35)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 25))
}
Gradient.Rotation = 45
Gradient.Parent = MainFrame

-- Заголовок
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 0, 60)
Title.Position = UDim2.new(0, 20, 0, 20)
Title.BackgroundTransparency = 1
Title.Text = "⚔️ BLADE BALL - VERIFICATION"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 24
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

-- Подзаголовок
local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -40, 0, 30)
Subtitle.Position = UDim2.new(0, 20, 0, 80)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Join our Discord to get your key!"
Subtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
Subtitle.TextSize = 14
Subtitle.Font = Enum.Font.Gotham
Subtitle.Parent = MainFrame

-- Discord кнопка
local DiscordBtn = Instance.new("TextButton")
DiscordBtn.Size = UDim2.new(1, -40, 0, 50)
DiscordBtn.Position = UDim2.new(0, 20, 0, 120)
DiscordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242) -- Discord цвет
DiscordBtn.Text = "📱 JOIN DISCORD SERVER"
DiscordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DiscordBtn.TextSize = 16
DiscordBtn.Font = Enum.Font.GothamBold
DiscordBtn.BorderSizePixel = 0
DiscordBtn.Parent = MainFrame

local DiscordCorner = Instance.new("UICorner")
DiscordCorner.CornerRadius = UDim.new(0, 10)
DiscordCorner.Parent = DiscordBtn

-- Инструкция
local Instructions = Instance.new("TextLabel")
Instructions.Size = UDim2.new(1, -40, 0, 40)
Instructions.Position = UDim2.new(0, 20, 0, 185)
Instructions.BackgroundTransparency = 1
Instructions.Text = "Enter your key from Discord:"
Instructions.TextColor3 = Color3.fromRGB(200, 200, 200)
Instructions.TextSize = 13
Instructions.Font = Enum.Font.GothamBold
Instructions.TextXAlignment = Enum.TextXAlignment.Left
Instructions.Parent = MainFrame

-- Поле ввода ключа
local KeyBox = Instance.new("TextBox")
KeyBox.Size = UDim2.new(1, -40, 0, 50)
KeyBox.Position = UDim2.new(0, 20, 0, 230)
KeyBox.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
KeyBox.Text = ""
KeyBox.PlaceholderText = "Enter your key here..."
KeyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
KeyBox.TextSize = 16
KeyBox.Font = Enum.Font.Gotham
KeyBox.ClearTextOnFocus = false
KeyBox.BorderSizePixel = 0
KeyBox.Parent = MainFrame

local KeyBoxCorner = Instance.new("UICorner")
KeyBoxCorner.CornerRadius = UDim.new(0, 10)
KeyBoxCorner.Parent = KeyBox

-- Кнопка верификации
local VerifyBtn = Instance.new("TextButton")
VerifyBtn.Size = UDim2.new(1, -40, 0, 50)
VerifyBtn.Position = UDim2.new(0, 20, 0, 295)
VerifyBtn.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
VerifyBtn.Text = "✅ VERIFY KEY"
VerifyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
VerifyBtn.TextSize = 18
VerifyBtn.Font = Enum.Font.GothamBold
VerifyBtn.BorderSizePixel = 0
VerifyBtn.Parent = MainFrame

local VerifyCorner = Instance.new("UICorner")
VerifyCorner.CornerRadius = UDim.new(0, 10)
VerifyCorner.Parent = VerifyBtn

-- Статус сообщение
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -40, 0, 30)
StatusLabel.Position = UDim2.new(0, 20, 0, 360)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = ""
StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusLabel.TextSize = 12
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.Parent = MainFrame

-- Анимация появления
MainFrame.Position = UDim2.new(0.5, -225, 1.5, 0)
MainFrame:TweenPosition(
    UDim2.new(0.5, -225, 0.5, -200),
    Enum.EasingDirection.Out,
    Enum.EasingStyle.Back,
    0.5,
    true
)

-- Функция копирования ссылки в буфер обмена
local function CopyToClipboard(text)
    if setclipboard then
        setclipboard(text)
        return true
    end
    return false
end

-- Обработчик Discord кнопки
DiscordBtn.MouseButton1Click:Connect(function()
    -- Анимация нажатия
    DiscordBtn.BackgroundColor3 = Color3.fromRGB(70, 80, 200)
    wait(0.1)
    DiscordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    
    -- Копируем ссылку
    if CopyToClipboard(VerificationSettings.DiscordLink) then
        StatusLabel.Text = "✅ Discord link copied to clipboard!"
        StatusLabel.TextColor3 = Color3.fromRGB(50, 255, 100)
    else
        StatusLabel.Text = "📱 Discord: " .. VerificationSettings.DiscordLink
        StatusLabel.TextColor3 = Color3.fromRGB(88, 101, 242)
    end
    
    -- Очищаем сообщение через 3 секунды
    task.delay(3, function()
        if StatusLabel then
            StatusLabel.Text = ""
        end
    end)
end)

-- Обработчик верификации
VerifyBtn.MouseButton1Click:Connect(function()
    local key = KeyBox.Text
    
    if key == "" then
        StatusLabel.Text = "❌ Please enter a key!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        
        -- Тряска поля ввода
        for i = 1, 3 do
            KeyBox.Position = UDim2.new(0, 15, 0, 230)
            wait(0.05)
            KeyBox.Position = UDim2.new(0, 25, 0, 230)
            wait(0.05)
        end
        KeyBox.Position = UDim2.new(0, 20, 0, 230)
        return
    end
    
    -- Анимация проверки
    VerifyBtn.Text = "⏳ VERIFYING..."
    VerifyBtn.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
    StatusLabel.Text = "Checking key..."
    StatusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
    
    wait(1) -- Имитация проверки
    
    if ValidateKey(key) then
        -- Успешная верификация
        VerifyBtn.Text = "✅ VERIFIED!"
        VerifyBtn.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
        StatusLabel.Text = "✅ Key verified! Loading script..."
        StatusLabel.TextColor3 = Color3.fromRGB(50, 255, 100)
        
        -- Сохраняем ключ
        SaveKey(key)
        
        wait(1)
        
        -- Анимация исчезновения
        MainFrame:TweenPosition(
            UDim2.new(0.5, -225, -0.5, 0),
            Enum.EasingDirection.In,
            Enum.EasingStyle.Back,
            0.5,
            true
        )
        
        wait(0.5)
        
        -- Удаляем GUI верификации
        ScreenGui:Destroy()
        
        -- Загружаем основной скрипт
        print("✅ Verification successful! Loading Blade Ball AutoPlay...")
        
        -- Загрузка с GitHub (с обходом кэша)
        local timestamp = tick()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/vbfgy/Blade-Ball-ai-autoplay/refs/heads/main/blade-ball-autoplay.lua?t=" .. timestamp))()
        
    else
        -- Неверный ключ
        VerifyBtn.Text = "❌ INVALID KEY"
        VerifyBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        StatusLabel.Text = "❌ Invalid key! Join Discord to get a valid key."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        
        -- Тряска окна
        for i = 1, 4 do
            MainFrame.Position = UDim2.new(0.5, -235, 0.5, -200)
            wait(0.05)
            MainFrame.Position = UDim2.new(0.5, -215, 0.5, -200)
            wait(0.05)
        end
        MainFrame.Position = UDim2.new(0.5, -225, 0.5, -200)
        
        wait(2)
        
        -- Возвращаем кнопку в исходное состояние
        VerifyBtn.Text = "✅ VERIFY KEY"
        VerifyBtn.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
    end
end)

-- Обработка Enter в поле ввода
KeyBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        VerifyBtn.MouseButton1Click:Fire()
    end
end)

print("🔐 Verification system loaded!")
print("📱 Discord: " .. VerificationSettings.DiscordLink)
print("💡 Join Discord to get your key!")
