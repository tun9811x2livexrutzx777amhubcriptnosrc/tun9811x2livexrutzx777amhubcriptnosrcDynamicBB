print("Executor "..identifyexecutor())
if not game:IsLoaded() then repeat game.Loaded:Wait() until game:IsLoaded() end
local HttpService = game:GetService("HttpService")
getgenv().Config = {
    Save_Member = true
}
_G.Check_Save_Setting = "CheckSaveSetting"
getgenv()['JsonEncode'] = function(msg)
    return game:GetService("HttpService"):JSONEncode(msg)
end
getgenv()['JsonDecode'] = function(msg)
    return game:GetService("HttpService"):JSONDecode(msg)
end
getgenv()['Check_Setting'] = function(Name)
    if not _G.Dis then
        if not isfolder('Dynamic Hub') then
            makefolder('Dynamic Hub')
        end
        if not isfolder('Dynamic Hub/All Star Tower Defense X') then
            makefolder('Dynamic Hub/All Star Tower Defense X')
        end
        if not isfile('Dynamic Hub/All Star Tower Defense X/'..Name..'.json') then
            writefile('Dynamic Hub/All Star Tower Defense X/'..Name..'.json', JsonEncode(getgenv().Config))
        end
    end
end
getgenv()['Get_Setting'] = function(Name)
    if not _G.Dis then
        if isfolder('Dynamic Hub') and isfile('Dynamic Hub/All Star Tower Defense X/'..Name..'.json') then
            getgenv().Config = JsonDecode(readfile('Dynamic Hub/All Star Tower Defense X/'..Name..'.json'))
            return getgenv().Config
        else
            getgenv()['Check_Setting'](Name)
        end
    end
end
getgenv()['Update_Setting'] = function(Name)
    if not _G.Dis then
        if isfolder('Dynamic Hub') and isfile('Dynamic Hub/All Star Tower Defense X/'..Name..'.json') then
            writefile('Dynamic Hub/All Star Tower Defense X/'..Name..'.json', JsonEncode(getgenv().Config))
        else
            getgenv()['Check_Setting'](Name)
        end
    end
end
getgenv()['Check_Setting'](_G.Check_Save_Setting)
getgenv()['Get_Setting'](_G.Check_Save_Setting)
if getgenv().Config.Save_Member then
    getgenv()['MyName'] = game.Players.LocalPlayer.Name
elseif getgenv().Config.Save_All_Member then
    getgenv()['MyName'] = "AllMember"
else
    getgenv()['MyName'] = "None"
    _G.Dis = true
end
getgenv()['Check_Setting'](getgenv()['MyName'])
getgenv()['Get_Setting'](getgenv()['MyName'])
getgenv().Config.Key = _G.wl_key
getgenv()['Update_Setting'](getgenv()['MyName'])
local Compkiller = loadstring(game:HttpGet("https://raw.githubusercontent.com/tun9811/CompKillerssss/refs/heads/main/LICENSE"))();
local Notifier = Compkiller.newNotify();
local ConfigManager = Compkiller:ConfigManager({
	Directory = "Compkiller-UI",
	Config = "Example-Configs"
});
Compkiller:Loader("rbxassetid://105608302686093" , 2.5).yield();
local Window = Compkiller.new({
	Name = "Dynamic Hub",
	Keybind = "LeftAlt",
	Logo = "rbxassetid://105608302686093",
	Scale = Compkiller.Scale.Window, -- Leave blank if you want automatic scale [PC, Mobile].
	TextSize = 15,
});
Notifier.new({
	Title = "Notification",
	Content = "Thank you for use this script!",
	Duration = 10,
	Icon = "rbxassetid://105608302686093"
});
local Watermark = Window:Watermark();
Watermark:AddText({
	Icon = "user",
	Text = game.Players.LocalPlayer.Name,
});
Watermark:AddText({
	Icon = "clock",
	Text = Compkiller:GetDate(),
});
local Time = Watermark:AddText({
	Icon = "timer",
	Text = "TIME",
});
task.spawn(function()
	while true do task.wait()
		Time:SetText(Compkiller:GetTimeNow());
	end
end)
Watermark:AddText({
	Icon = "server",
	Text = Compkiller.Version,
});
Window:DrawCategory({
	Name = "General"
});
local General = Window:DrawTab({
	Name = "Combat",
	Icon = "component",
    Type = "Single",
	EnableScrolling = true
});
local NormalSection = General:DrawSection({
	Name = "Auto Parry",
	Position = 'left'	
});
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("Player tidak ditemukan! Script dihentikan.")
    return
end

-- Global state for parry
local Cooldown = 0
local IsParried = false
local Connection = nil
local LastSpamTime = 0         -- Variabel untuk spam mode
local BaseSpamInterval = 0.1     -- Interval dasar spam mode (detik)

-- Global untuk Mobile Optimization
local MobileOptimized = false  -- Default: non-mobile optimization
local lastOptimizedTime = 0    -- Untuk mengatur frekuensi perhitungan

--------------------------------------------------------
-- Utility Functions
--------------------------------------------------------
local DEBUG_MODE = true
local function DebugLog(message)
    if DEBUG_MODE then
        print("[DEBUG]: " .. message)
    end
end

local function validateCharacter()
    if not LocalPlayer.Character then return false, "Character belum tersedia" end
    if not LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then return false, "Humanoid tidak ditemukan" end
    if not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return false, "HumanoidRootPart tidak ditemukan" end
    return true
end

local function safeCall(fn, ...)
    local success, result = pcall(fn, ...)
    if not success then
        warn("[SafeCall] Error:", result)
        return nil
    end
    return result
end

-- Fungsi clamp lokal
local function clamp(x, minVal, maxVal)
    if x < minVal then return minVal end
    if x > maxVal then return maxVal end
    return x
end

local function getPingValue()
    local ping = 0
    pcall(function()
        ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"].Value / 1000
    end)
    return ping
end

--------------------------------------------------------
-- Deteksi Curve pada Bola (Peningkatan)
--------------------------------------------------------
local angleDifferences = {}    -- Menyimpan perbedaan sudut dari beberapa frame
local maxStoredAngles = 5        -- Jumlah nilai maksimum yang disimpan
local baseCurveThreshold = math.rad(10)  -- Ambang dasar deteksi curve (10° dalam radian)
local previousVelocity = nil     -- Vektor kecepatan dari frame sebelumnya

local function GetDynamicCurveThreshold(speed)
    local baseThreshold = baseCurveThreshold
    if speed > 50 then
        -- Semakin cepat bola, threshold menurun hingga minimal 50% dari nilai dasar
        local factor = clamp(1 - ((speed - 50) / 150), 0.5, 1)
        return baseThreshold * factor
    else
        return baseThreshold
    end
end

local function UpdateAngleDifference(currentVelocity)
    local angleDiff = 0
    if previousVelocity then
        local magProduct = currentVelocity.Magnitude * previousVelocity.Magnitude
        if magProduct > 0 then
            local dotVal = currentVelocity:Dot(previousVelocity) / magProduct
            dotVal = clamp(dotVal, -1, 1)
            angleDiff = math.acos(dotVal)
        end
    end
    previousVelocity = currentVelocity
    table.insert(angleDifferences, angleDiff)
    if #angleDifferences > maxStoredAngles then
        table.remove(angleDifferences, 1)
    end
    return angleDiff
end

local function IsAccelerationHigh(currentVelocity)
    local accDiff = 0
    if previousVelocity then
        accDiff = math.abs(currentVelocity.Magnitude - previousVelocity.Magnitude)
    end
    local accelerationThreshold = 5  -- Nilai ambang percepatan (sesuaikan jika perlu)
    if accDiff > accelerationThreshold then
        DebugLog("Deteksi percepatan mendadak: " .. tostring(accDiff))
        return true
    end
    return false
end

local function IsBallCurving(currentVelocity)
    if IsAccelerationHigh(currentVelocity) then
        return true
    end
    local currentAngleDiff = UpdateAngleDifference(currentVelocity)
    local sum = 0
    for _, a in ipairs(angleDifferences) do
        sum = sum + a
    end
    local averageAngle = (#angleDifferences > 0) and (sum / #angleDifferences) or 0
    local dynamicThreshold = GetDynamicCurveThreshold(currentVelocity.Magnitude)
    DebugLog("Rata-rata perbedaan sudut: " .. tostring(math.deg(averageAngle)) .. "°, Dynamic threshold: " .. tostring(math.deg(dynamicThreshold)) .. "°")
    return averageAngle > dynamicThreshold
end

--------------------------------------------------------
-- Parry Logic
--------------------------------------------------------
local ToggleSystem = {
    NormalMode = false,
    SpamMode = false,
    AdvancedMode = false,   -- Advanced Auto Parry (prediksi waktu reaksi dengan smoothing)
    HybridParry = false     -- Enchanted Function (gabungan logika Normal & Advanced)
}

local function GetBall()
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return nil end
    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if ball:GetAttribute("realBall") then
            return ball
        end
    end
    return nil
end

local function ResetConnection()
    if Connection then
        Connection:Disconnect()
        Connection = nil
    end
end
local function Parry()
    if IsParried then return end  -- Pastikan hanya terjadi satu kali per bola (kecuali anticipation parry)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.wait(0.005)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    IsParried = true
    Cooldown = tick()
    DebugLog("Parry dilakukan!")
end

-- Listener: Memantau perubahan target bola dan menerapkan logika anticipation parry
workspace.Balls.ChildAdded:Connect(function()
    local ball = GetBall()
    if not ball then return end
    ResetConnection()
    previousVelocity = nil  -- Reset deteksi curve untuk bola baru
    local anticipated = false  -- Flag agar anticipation parry hanya terjadi satu kali per bola
    Connection = ball:GetAttributeChangedSignal("target"):Connect(function()
        local target = ball:GetAttribute("target")
        if target == LocalPlayer.Name then
            IsParried = false
            anticipated = false
            DebugLog("Target berubah: Bola kini mengarah ke pemain!")
        else
            if IsParried and not anticipated then
                local targetPlayer = game:GetService("Players"):FindFirstChild(target)
                if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local distBetweenPlayers = (LocalPlayer.Character.HumanoidRootPart.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
                    if distBetweenPlayers < 10 then  -- threshold jarak antar pemain
                        DebugLog("Anticipation Parry: Target (" .. target.. ") dekat (" .. tostring(distBetweenPlayers) .. " studs).")
                        Parry()
                        anticipated = true
                    end
                end
            end
        end
    end)
end)

local function GetBallVelocity(ball)
    local velocity = nil
    local success, result = pcall(function() return ball.AssemblyLinearVelocity end)
    if success and typeof(result) == "Vector3" then
        velocity = result
    else
        local zoomies = ball:FindFirstChild("zoomies")
        if zoomies and zoomies:IsA("Vector3Value") then
            velocity = zoomies.Value
        end
    end
    return velocity
end

--------------------------------------------------------
-- Advanced Auto Parry
--------------------------------------------------------
local advancedPredictions = {}  -- Untuk smoothing prediksi waktu
--[[]
local function AdvancedAutoParry(Speed, Distance)
    local pingValue = getPingValue() or 0
    local predictedTime = Distance / math.max(Speed, 0.01)
    table.insert(advancedPredictions, predictedTime)
    if #advancedPredictions > 5 then
        table.remove(advancedPredictions, 1)
    end
    local sumTime = 0
    for _, t in ipairs(advancedPredictions) do
        sumTime = sumTime + t
    end
    local avgPredictedTime = sumTime / #advancedPredictions

    local baseReactionDelay = 0.42  -- dasar waktu reaksi
    local speedAdjustment = clamp(0.5 - 0.002 * Speed, 0.2, 0.5)
    local latencyAdjustment = pingValue * 0.3
    local reactionThreshold = baseReactionDelay + speedAdjustment - latencyAdjustment

    if Speed > 100 and Speed < 200 then
        reactionThreshold = reactionThreshold * 0.6  -- tingkatkan responsivitas jika bola sangat cepat
    end

    DebugLog("Advanced Parry: avgPredictedTime = " .. tostring(avgPredictedTime) ..
             ", reactionThreshold = " .. tostring(reactionThreshold) ..
             ", Speed = " .. tostring(Speed) ..
             ", Distance = " .. tostring(Distance) ..
             ", Ping = " .. tostring(pingValue))
    
    return avgPredictedTime < reactionThreshold
end
--[[]
local function AdvancedAutoParryS(Speed, Distance)
    local pingValue = getPingValue() or 0
    local predictedTime = Distance / math.max(Speed, 0.01)
    table.insert(advancedPredictions, predictedTime)
    if #advancedPredictions > 5 then
        table.remove(advancedPredictions, 1)
    end
    local sumTime = 0
    for _, t in ipairs(advancedPredictions) do
        sumTime = sumTime + t
    end
    local avgPredictedTime = sumTime / #advancedPredictions

    local baseReactionDelay = -10  -- dasar waktu reaksi
    local speedAdjustment = clamp(0.5 - 0.002 * Speed, 0.2, 0.5)
    local latencyAdjustment = pingValue * 0.3
    local reactionThreshold = baseReactionDelay + speedAdjustment - latencyAdjustment

    if Speed > 175 then
        reactionThreshold = reactionThreshold * 0.8  -- tingkatkan responsivitas jika bola sangat cepat
    end

    DebugLog("Advanced Parry: avgPredictedTime = " .. tostring(avgPredictedTime) ..
             ", reactionThreshold = " .. tostring(reactionThreshold) ..
             ", Speed = " .. tostring(Speed) ..
             ", Distance = " .. tostring(Distance) ..
             ", Ping = " .. tostring(pingValue))
    
    return avgPredictedTime < reactionThreshold
end
--]]
--------------------------------------------------------
-- Hybrid Parry (Gabungan Normal & Advanced) dengan Validasi Skill Freeze
--------------------------------------------------------
local function HybridParry(Speed, Distance)
    -- Validasi tambahan: jika bola tiba-tiba berhenti bergerak (skill freeze), skip parry
    local freezeThreshold = 1  -- Threshold kecepatan (stud/detik) untuk mendeteksi bola berhenti
    if Speed < freezeThreshold then
        DebugLog("Hybrid Parry: Skill freeze terdeteksi (Speed = " .. tostring(Speed) .. "), skip parry.")
        return false
    end

    local normalValue = Distance / math.max(Speed, 0.01)
    local normalThreshold = 0.6

    local baseReactionDelay = 0.3
    local speedAdjustment = clamp(0.5 - 0.002 * Speed, 0.2, 0.5)
    local latencyAdjustment = getPingValue() * 0.5
    local advancedThreshold = baseReactionDelay + speedAdjustment - latencyAdjustment

    if Speed > 150 then
        advancedThreshold = advancedThreshold * 1
    end

    local combinedThreshold = (normalThreshold + advancedThreshold) / 2

    if Distance < 10 then
        DebugLog("Hybrid Parry: Kondisi spam terpenuhi (Distance < 10).")
        return true
    end

    DebugLog("Hybrid Parry: normalValue = " .. tostring(normalValue) ..
             ", combinedThreshold = " .. tostring(combinedThreshold))
    
    return normalValue <= combinedThreshold
end
local function HybridParry2(Speed, Distance)
    -- Validasi tambahan: jika bola tiba-tiba berhenti bergerak (skill freeze), skip parry
    local freezeThreshold = 1  -- Threshold kecepatan (stud/detik) untuk mendeteksi bola berhenti
    if Speed < freezeThreshold then
        DebugLog("Hybrid Parry: Skill freeze terdeteksi (Speed = " .. tostring(Speed) .. "), skip parry.")
        return false
    end

    local normalValue = Distance / math.max(Speed, 0.01)
    local normalThreshold = 0.7

    local baseReactionDelay = 0.3
    local speedAdjustment = clamp(0.4 - 0.001 * Speed, 0.1, 0.4)
    local latencyAdjustment = getPingValue() * 0.5
    local advancedThreshold = baseReactionDelay + speedAdjustment - latencyAdjustment

    if Speed > 250 then
        advancedThreshold = advancedThreshold * 1
    end

    local combinedThreshold = (normalThreshold + advancedThreshold) / 2

    if Distance < 10 then
        DebugLog("Hybrid Parry: Kondisi spam terpenuhi (Distance < 10).")
        return true
    end

    DebugLog("Hybrid Parry: normalValue = " .. tostring(normalValue) ..
             ", combinedThreshold = " .. tostring(combinedThreshold))
    
    return normalValue <= combinedThreshold
end
local function HybridParry3(Speed, Distance)
    -- Validasi tambahan: jika bola tiba-tiba berhenti bergerak (skill freeze), skip parry
    local freezeThreshold = 1  -- Threshold kecepatan (stud/detik) untuk mendeteksi bola berhenti
    if Speed < freezeThreshold then
        DebugLog("Hybrid Parry: Skill freeze terdeteksi (Speed = " .. tostring(Speed) .. "), skip parry.")
        return false
    end

    local normalValue = Distance / math.max(Speed, 0.01)
    local normalThreshold = 0.7

    local baseReactionDelay = 0.2
    local speedAdjustment = clamp(0.3 - 0 * Speed, 0, 0.3)
    local latencyAdjustment = getPingValue() * 0.5
    local advancedThreshold = baseReactionDelay + speedAdjustment - latencyAdjustment

    if Speed > 350 then
        advancedThreshold = advancedThreshold * 1
    end

    local combinedThreshold = (normalThreshold + advancedThreshold) / 2

    if Distance < 10 then
        DebugLog("Hybrid Parry: Kondisi spam terpenuhi (Distance < 10).")
        return true
    end

    DebugLog("Hybrid Parry: normalValue = " .. tostring(normalValue) ..
             ", combinedThreshold = " .. tostring(combinedThreshold))
    
    return normalValue <= combinedThreshold
end
--------------------------------------------------------
-- Main Loop: Panggil parry sesuai mode & deteksi curve
--------------------------------------------------------
RunService.PreSimulation:Connect(function()
    if MobileOptimized then
        local currentTime = tick()
        if currentTime - lastOptimizedTime < 0.05 then
            return
        else
            lastOptimizedTime = currentTime
        end
    end

    local ball = GetBall()
    if not ball then return end
    if ball:GetAttribute("target") ~= LocalPlayer.Name then return end

    local character = LocalPlayer.Character
    if not character then return end

    local HRP = character:FindFirstChild("HumanoidRootPart")
    if not HRP then return end

    local ballVelocity = GetBallVelocity(ball)
    if not ballVelocity or typeof(ballVelocity) ~= "Vector3" then
        DebugLog("Tidak bisa mendapatkan kecepatan bola!")
        return
    end

    -- Validasi untuk special skill: jika bola spin upward dan sangat cepat, trigger parry langsung
    if ballVelocity.Y > 50 and ballVelocity.Magnitude > 150 then
        DebugLog("Special Skill Detected: Bola spin upward dan kecepatan tinggi!")
        Parry()
        return
    end

    -- Deteksi curve pada bola
    if IsBallCurving(ballVelocity) then
        DebugLog("Deteksi Curve: Bola sedang melengkung!")
        local curvingThreshold = 15  -- jarak threshold untuk anticipation parry jika bola melengkung
        local distanceCurve = (HRP.Position - ball.Position).Magnitude
        if distanceCurve < curvingThreshold then
            DebugLog("Anticipation Parry karena bola melengkung dan jarak (" .. tostring(distanceCurve) .. " studs) dekat!")
            Parry()
            return
        end
    end

    local Speed = ballVelocity.Magnitude
    local Distance = (HRP.Position - ball.Position).Magnitude
--[[]
    if getgenv().Config["Enabled"] then
        if HybridParry(Speed, Distance) then
            Parry()
        end
        return
    end
--]]
    if getgenv().Config["Enabled"] then
        if HybridParry(Speed, Distance) then
            Parry()
        elseif HybridParry2(Speed, Distance) then
            Parry()
        elseif HybridParry3(Speed, Distance) then
            Parry()
        end
        return
    end

    if ToggleSystem.SpamMode then
        if Distance <= 20 then
            local currentTime = tick()
            local spamInterval = math.max(BaseSpamInterval * (1 - (Speed / 100)), 0.01)
            if currentTime - LastSpamTime >= spamInterval then
                DebugLog("Mode Spam Parry Aktif - Bola terlalu dekat! (Interval: " .. spamInterval .. " detik)")
                Parry()
                LastSpamTime = currentTime
            end
        end
        return
    end

    if ToggleSystem.NormalMode then
        if IsParried and (tick() - Cooldown) < 1 then return end
        if (Distance / math.max(Speed, 0.01)) <= 0.55 then
            Parry()
        end
    end
end)

--------------------------------------------------------
-- Validasi Tambahan: Perpindahan Mendadak Local Player
-- Jika local player tiba-tiba mendekati pemain yang sedang di-target bola, trigger parry.
--------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
    local ball = GetBall()
    if ball and ball:GetAttribute("target") ~= LocalPlayer.Name then
        if validateCharacter() then
            local localHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local targetPlayer = game:GetService("Players"):FindFirstChild(ball:GetAttribute("target"))
            if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local targetHRP = targetPlayer.Character.HumanoidRootPart
                local dist = (localHRP.Position - targetHRP.Position).Magnitude
                if dist < 10 then
                    DebugLog("Anticipation Parry (Local Movement): Local player mendekati target (" .. tostring(dist) .. " studs).")
                    Parry()
                end
            end
        end
    end
end)

--------------------------------------------------------
-- GUI Status (Selalu Muncul, Draggable, Minimalis)
--------------------------------------------------------
_G['Show Ball Hitbox'] = false
_G["Enabled Hitbox"] = false
    LOL = nil
    local function createLOL()
        LOL = workspace:FindFirstChild("LOL")
        if not LOL then
            LOL = Instance.new("Part")
            LOL.Name = "LOL"
            LOL.Parent = workspace
            LOL.Material = Enum.Material.ForceField
            LOL.Shape = Enum.PartType.Ball
            LOL.Anchored = true
            LOL.CanCollide = false
            LOL.CastShadow = false
            LOL.Color = Color3.fromRGB(0, 255, 0)
        end
    end
    spawn(function()
        while task.wait() do
            createLOL()
            if _G['Show Ball Hitbox'] then
                if game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LOL.Position = game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart").Position
                    LOL.Transparency = 0.5
                end
            else
                if LOL then
                    LOL.Transparency = 1
                end
            end
        end
    end)
-- Update GUI Status setiap frame
RunService.RenderStepped:Connect(function()
    local ball = GetBall()
    if ball then
        local targetAttr = ball:GetAttribute("target") or "N/A"
        --targetLabel.Text = "Target: " .. tostring(targetAttr)
        
        local ballVel = GetBallVelocity(ball)
        if ballVel then
           -- speedLabel.Text = "Speed: " .. string.format("%.2f", ballVel.Magnitude);
local mag = tonumber(string.format("%.2f", ballVel.Magnitude))  -- ปัดทศนิยม 2 ตำแหน่ง แล้วแปลงกลับเป็น number
LOL.Size = Vector3.new(mag, mag, mag)

        else
            --speedLabel.Text = "Speed: N/A"
        end

        if validateCharacter() then
            local HRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if HRP and ball then
                local dist = (HRP.Position - ball.Position).Magnitude
                --distanceLabel.Text = "Distance: " .. string.format("%.2f", dist)
            else
                --distanceLabel.Text = "Distance: N/A"
            end
        end

        if ballVel then
            local curving = IsBallCurving(ballVel)
        else

        end

        if ballVel and validateCharacter() then
            local HRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local dist = HRP and (HRP.Position - ball.Position).Magnitude or 0
            local suggestion = "Parry Not Recommended"
            if HybridParry(ballVel.Magnitude, dist) then
                suggestion = "Parry Recommended"
            end
        else
        end
    else
    end
end)
NormalSection:AddToggle({
	Name = "Enabled",
	Flag = "", -- Leave it blank will not save to config
	Default = getgenv().Config["Enabled"] or false,
	Callback = function(Value)
        getgenv().Config["Enabled"] = Value
        getgenv()['Update_Setting'](getgenv()['MyName'])   
    end
});
Window:DrawCategory({
	Name = "Misc"
});

local SettingTab = Window:DrawTab({
	Icon = "settings-3",
	Name = "Settings",
	Type = "Single",
	EnableScrolling = true
});

local ThemeTab = Window:DrawTab({
	Icon = "paintbrush",
	Name = "Themes",
	Type = "Single"
});

local Settings = SettingTab:DrawSection({
	Name = "UI Settings",
});

Settings:AddToggle({
	Name = "Alway Show Frame",
	Default = false,
	Callback = function(v)
		Window.AlwayShowTab = v;
	end,
});

Settings:AddColorPicker({
	Name = "Highlight",
	Default = Compkiller.Colors.Highlight,
	Callback = function(v)
		Compkiller.Colors.Highlight = v;
		Compkiller:RefreshCurrentColor();
	end,
});

Settings:AddColorPicker({
	Name = "Toggle Color",
	Default = Compkiller.Colors.Toggle,
	Callback = function(v)
		Compkiller.Colors.Toggle = v;
		
		Compkiller:RefreshCurrentColor(v);
	end,
});

Settings:AddColorPicker({
	Name = "Drop Color",
	Default = Compkiller.Colors.DropColor,
	Callback = function(v)
		Compkiller.Colors.DropColor = v;

		Compkiller:RefreshCurrentColor(v);
	end,
});

Settings:AddColorPicker({
	Name = "Risky",
	Default = Compkiller.Colors.Risky,
	Callback = function(v)
		Compkiller.Colors.Risky = v;

		Compkiller:RefreshCurrentColor(v);
	end,
});

Settings:AddColorPicker({
	Name = "Mouse Enter",
	Default = Compkiller.Colors.MouseEnter,
	Callback = function(v)
		Compkiller.Colors.MouseEnter = v;

		Compkiller:RefreshCurrentColor(v);
	end,
});

Settings:AddColorPicker({
	Name = "Block Color",
	Default = Compkiller.Colors.BlockColor,
	Callback = function(v)
		Compkiller.Colors.BlockColor = v;

		Compkiller:RefreshCurrentColor(v);
	end,
});

Settings:AddColorPicker({
	Name = "Background Color",
	Default = Compkiller.Colors.BGDBColor,
	Callback = function(v)
		Compkiller.Colors.BGDBColor = v;

		Compkiller:RefreshCurrentColor(v);
	end,
});

Settings:AddColorPicker({
	Name = "Block Background Color",
	Default = Compkiller.Colors.BlockBackground,
	Callback = function(v)
		Compkiller.Colors.BlockBackground = v;

		Compkiller:RefreshCurrentColor(v);
	end,
});

Settings:AddColorPicker({
	Name = "Stroke Color",
	Default = Compkiller.Colors.StrokeColor,
	Callback = function(v)
		Compkiller.Colors.StrokeColor = v;

		Compkiller:RefreshCurrentColor(v);
	end,
});

Settings:AddColorPicker({
	Name = "High Stroke Color",
	Default = Compkiller.Colors.HighStrokeColor,
	Callback = function(v)
		Compkiller.Colors.HighStrokeColor = v;

		Compkiller:RefreshCurrentColor(v);
	end,
});

Settings:AddColorPicker({
	Name = "Switch Color",
	Default = Compkiller.Colors.SwitchColor,
	Callback = function(v)
		Compkiller.Colors.SwitchColor = v;

		Compkiller:RefreshCurrentColor(v);
	end,
});

Settings:AddColorPicker({
	Name = "Line Color",
	Default = Compkiller.Colors.LineColor,
	Callback = function(v)
		Compkiller.Colors.LineColor = v;

		Compkiller:RefreshCurrentColor(v);
	end,
});

Settings:AddButton({
	Name = "Get Theme",
	Callback = function()
		print(Compkiller:GetTheme())
		
		Notifier.new({
			Title = "Notification",
			Content = "Copied Them Color to your clipboard",
			Duration = 5,
			Icon = "rbxassetid://120245531583106"
		});
	end,
});

ThemeTab:DrawSection({
	Name = "UI Themes"
}):AddDropdown({
	Name = "Select Theme",
	Default = "Default",
	Values = {
		"Default",
		"Dark Green",
		"Dark Blue",
		"Purple Rose",
		"Skeet"
	},
	Callback = function(v)
		Compkiller:SetTheme(v)
	end,
})

-- Creating Config Tab --
local ConfigUI = Window:DrawConfig({
	Name = "Config",
	Icon = "folder",
	Config = ConfigManager
});

ConfigUI:Init();
