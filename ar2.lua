--[[
    AR2 LITE — v3
    - ESP preciso via GetBoundingBox (sem hack de 40px)
    - Item ESP (scan automático de folders Items/Pickups/Loot/etc.)
    - Aimbot melhorado (mouse + camera, auto-fallback)
    - Tecla "-" fecha TUDO permanentemente
]]

-- ============================================================
-- CLEANUP ANTERIOR (guarda contra dupla execução)
-- ============================================================
pcall(function()
    getgenv().AR2_ALIVE = false
    if getgenv().AR2_CONNECTIONS then
        for _, c in ipairs(getgenv().AR2_CONNECTIONS) do pcall(function() c:Disconnect() end) end
    end
    if getgenv().AR2_DRAWINGS then
        for _, d in ipairs(getgenv().AR2_DRAWINGS) do pcall(function() d:Remove() end) end
    end
    if getgenv().AR2_FOLDER then pcall(function() getgenv().AR2_FOLDER:Destroy() end) end
end)

getgenv().AR2_ALIVE = true
getgenv().AR2_CONNECTIONS = getgenv().AR2_CONNECTIONS or {}
getgenv().AR2_DRAWINGS = getgenv().AR2_DRAWINGS or {}

local CONNS = getgenv().AR2_CONNECTIONS
local DRAWS = getgenv().AR2_DRAWINGS

local function newConn(c) table.insert(CONNS, c); return c end
local function newDraw(typ)
    local ok, d = pcall(Drawing.new, typ)
    if not ok then return nil end
    table.insert(DRAWS, d)
    return d
end

-- ============================================================
-- SERVICES + STATE
-- ============================================================
local cloneref = cloneref or function(v) return v end
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local Lighting = cloneref(game:GetService("Lighting"))
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local S = {
    Aimbot=false, AimPart="Head", FOV=120, Smooth=0.3, WallCheck=false, ShowFOV=false,
    ESP_Player=false, ESP_Zombie=false, ESP_Items=false,
    ESP_Line=false, ESP_Distance=false,
    Fullbright=false, WalkSpeed=16, JumpPower=50,
}

-- ============================================================
-- HOOK (instalado só uma vez por sessão, alive-flag controla)
-- ============================================================
local canHook = (getnamecallmethod ~= nil) and (hookmetamethod ~= nil) and (checkcaller ~= nil)

if canHook and not getgenv().AR2_HOOKED then
    local ok = pcall(function()
        local old
        old = hookmetamethod(game, "__namecall", function(self, ...)
            if not getgenv().AR2_ALIVE then return old(self, ...) end
            local args = { ... }
            local m
            pcall(function() m = getnamecallmethod() end)
            if m and not checkcaller() and (m == "FindFirstChild" or m == "FindFirstChildWhichIsA") then
                local a1 = args[1]
                if type(a1) == "string" and (a1:find("AR2_") or a1:find("Rayfield")) then
                    return nil
                end
            end
            return old(self, ...)
        end)
    end)
    if ok then getgenv().AR2_HOOKED = true end
end

-- ============================================================
-- DRAWING
-- ============================================================
local hasDrawing = pcall(function() local d = Drawing.new("Circle"); d:Remove() end)

local FOVCircle = newDraw("Circle")
if FOVCircle then
    FOVCircle.Thickness = 1.5
    FOVCircle.NumSides = 48
    FOVCircle.Filled = false
    FOVCircle.Transparency = 1
    FOVCircle.Color = Color3.fromRGB(0, 122, 255)
    FOVCircle.Visible = false
end

-- ============================================================
-- UI
-- ============================================================
local Rayfield
local okRay = pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not okRay or not Rayfield then
    warn("[AR2] Rayfield não carregou — usando fallback")
    Rayfield = {
        CreateWindow = function()
            return {
                CreateTab = function()
                    return {
                        CreateToggle = function() end,
                        CreateSlider = function() end,
                        CreateDropdown = function() end,
                    }
                end,
            }
        end,
        Notify = function() end,
    }
end

local Window = Rayfield:CreateWindow({
    Name = "AR2 // Lite",
    LoadingTitle = "carregando...",
    LoadingSubtitle = "ollie & killywilly",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

if Rayfield.GUI then
    pcall(function()
        local folder = CoreGui:FindFirstChild("AR2_Folder") or Instance.new("Folder")
        folder.Name = "AR2_Folder"
        folder.Parent = CoreGui
        Rayfield.GUI.Parent = folder
        getgenv().AR2_FOLDER = folder
    end)
end

-- ============================================================
-- TABS
-- ============================================================
local Combat  = Window:CreateTab("Combat", 4483362458)
local Visuals = Window:CreateTab("Visuals", 4483362458)
local Misc    = Window:CreateTab("Misc", 4483362458)

Combat:CreateToggle({ Name="Aimbot (Mouse)", CurrentValue=false, Flag="aimm",
    Callback=function(v) S.Aimbot=v; S.AimMouse=true end })
Combat:CreateToggle({ Name="Aimbot (Camera)", CurrentValue=false, Flag="aimc",
    Callback=function(v) S.Aimbot=v; S.AimMouse=false end })
Combat:CreateDropdown({ Name="Aim Part", Options={"Head","HumanoidRootPart","UpperTorso"},
    CurrentOption="Head", Flag="ap", Callback=function(o) S.AimPart=o end })
Combat:CreateSlider({ Name="FOV", Range={50,400}, Increment=5, Suffix="px",
    CurrentValue=120, Flag="fov", Callback=function(v) S.FOV=v end })
Combat:CreateSlider({ Name="Smooth (snappiness)", Range={0.1,1}, Increment=0.05,
    CurrentValue=0.3, Flag="sm", Callback=function(v) S.Smooth=v end })
Combat:CreateToggle({ Name="Wall Check", CurrentValue=false, Flag="wc",
    Callback=function(v) S.WallCheck=v end })
Combat:CreateToggle({ Name="Show FOV", CurrentValue=false, Flag="sfov",
    Callback=function(v) S.ShowFOV=v end })

Visuals:CreateToggle({ Name="Player ESP", CurrentValue=false, Flag="ep",
    Callback=function(v) S.ESP_Player=v end })
Visuals:CreateToggle({ Name="Zombie ESP", CurrentValue=false, Flag="ez",
    Callback=function(v) S.ESP_Zombie=v end })
Visuals:CreateToggle({ Name="Item ESP", CurrentValue=false, Flag="ei",
    Callback=function(v) S.ESP_Items=v end })
Visuals:CreateToggle({ Name="Line", CurrentValue=false, Flag="el",
    Callback=function(v) S.ESP_Line=v end })
Visuals:CreateToggle({ Name="Distance", CurrentValue=false, Flag="ed",
    Callback=function(v) S.ESP_Distance=v end })
Visuals:CreateToggle({ Name="Fullbright", CurrentValue=false, Flag="fb",
    Callback=function(v)
        S.Fullbright=v
        pcall(function()
            if v then
                Lighting.Brightness=2; Lighting.ClockTime=12
                Lighting.FogEnd=1e5; Lighting.GlobalShadows=false
            else
                Lighting.Brightness=1; Lighting.FogEnd=1000; Lighting.GlobalShadows=true
            end
        end)
    end })

Misc:CreateSlider({ Name="WalkSpeed", Range={16,120}, Increment=1,
    CurrentValue=16, Flag="ws",
    Callback=function(v)
        S.WalkSpeed=v
        pcall(function()
            local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed=v end
        end)
    end })
Misc:CreateSlider({ Name="JumpPower", Range={50,200}, Increment=5,
    CurrentValue=50, Flag="jp",
    Callback=function(v)
        S.JumpPower=v
        pcall(function()
            local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if h then h.JumpPower=v end
        end)
    end })

-- ============================================================
-- ESP HELPERS — bounding box preciso
-- ============================================================
local esp = {}
local itemEsp = {}

local function getEsp(inst, color)
    if esp[inst] then return esp[inst] end
    local bx = newDraw("Square")
    local nm = newDraw("Text")
    local ln = newDraw("Line")
    if not (bx and nm and ln) then return nil end
    bx.Thickness=1.5; bx.Filled=false; bx.Color=color; bx.Visible=false
    nm.Size=14; nm.Center=true; nm.Outline=true; nm.Color=color; nm.Visible=false
    ln.Thickness=1; ln.Color=color; ln.Visible=false
    esp[inst] = { Box=bx, Name=nm, Line=ln }
    return esp[inst]
end

local function hideEsp(d)
    if not d then return end
    pcall(function()
        if d.Box.Visible then d.Box.Visible=false end
        if d.Name.Visible then d.Name.Visible=false end
        if d.Line.Visible then d.Line.Visible=false end
    end)
end

local function dropEsp(inst)
    local d = esp[inst]
    if d then
        pcall(function() d.Box:Remove(); d.Name:Remove(); d.Line:Remove() end)
        esp[inst] = nil
    end
end

-- bounding box preciso via GetBoundingBox
local function getScreenBox(model)
    if not Camera then return nil end
    local ok, cf, size = pcall(function()
        return model:GetBoundingBox()
    end)
    if not ok or not cf or not size then return nil end

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local any = false

    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                local world = cf * Vector3.new(x*size.X/2, y*size.Y/2, z*size.Z/2)
                local sp, on = Camera:WorldToViewportPoint(world)
                if on and sp.Z > 0 then
                    any = true
                    if sp.X < minX then minX = sp.X end
                    if sp.Y < minY then minY = sp.Y end
                    if sp.X > maxX then maxX = sp.X end
                    if sp.Y > maxY then maxY = sp.Y end
                end
            end
        end
    end
    if not any then return nil end
    return Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY)
end

Players.PlayerRemoving:Connect(dropEsp)

-- ============================================================
-- TARGET FINDER
-- ============================================================
local function getAimTarget()
    if not Camera then return nil end
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local best, bestScore = nil, math.huge
    local myPos = Camera.CFrame.Position

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local part = plr.Character:FindFirstChild(S.AimPart) or plr.Character:FindFirstChild("Head")
                if part then
                    local sp, on = Camera:WorldToViewportPoint(part.Position)
                    if on and sp.Z > 0 then
                        local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if screenDist <= S.FOV then
                            local blocked = false
                            if S.WallCheck then
                                local rp = RaycastParams.new()
                                rp.FilterDescendantsInstances = { plr.Character, LocalPlayer.Character }
                                rp.FilterType = Enum.RaycastFilterType.Exclude
                                local hit = workspace:Raycast(myPos, part.Position - myPos, rp)
                                if hit then blocked = true end
                            end
                            if not blocked then
                                local worldDist = (part.Position - myPos).Magnitude
                                local score = screenDist + worldDist * 0.05
                                if score < bestScore then
                                    bestScore = score
                                    best = { part = part, pos = part.Position }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- ============================================================
-- ITEM SCAN — pega folders com nome de item/loot/weapon
-- ============================================================
local function getItemFolders()
    local results = {}
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Folder") or obj:IsA("Model") then
            local n = obj.Name:lower()
            if n:find("item") or n:find("pickup") or n:find("loot")
               or n:find("drop") or n:find("weapon") or n:find("spawn") then
                table.insert(results, obj)
            end
        end
    end
    return results
end

local function scanItems()
    local out = {}
    for _, folder in ipairs(getItemFolders()) do
        for _, item in ipairs(folder:GetChildren()) do
            if (item:IsA("BasePart") or item:IsA("Model")) and item.Parent then
                local part
                if item:IsA("BasePart") then
                    part = item
                else
                    part = item:FindFirstChildWhichIsA("BasePart", true)
                end
                if part then
                    out[item] = part
                end
            end
        end
    end
    return out
end

-- ============================================================
-- AIMBOT
-- ============================================================
local function aimAt(target, dt)
    if S.AimMouse then
        if mousemoverel then
            local sp = Camera:WorldToViewportPoint(target.pos)
            local m = UserInputService:GetMouseLocation()
            local factor = math.clamp(S.Smooth, 0.2, 0.7)
            pcall(function()
                mousemoverel((sp.X - m.X) * factor, (sp.Y - m.Y) * factor)
            end)
        end
    else
        pcall(function()
            local cur = Camera.CFrame
            local want = CFrame.lookAt(cur.Position, target.pos)
            local t = math.clamp(S.Smooth, 0.05, 0.5)
            Camera.CFrame = cur:Lerp(want, t)
        end)
    end
end

-- ============================================================
-- LOOP PRINCIPAL
-- ============================================================
local itemScanTimer = 0

newConn(RunService.RenderStepped:Connect(function(dt)
    if not getgenv().AR2_ALIVE then return end

    -- FOV
    if FOVCircle then
        pcall(function()
            FOVCircle.Visible = S.ShowFOV
            if S.ShowFOV and Camera then
                FOVCircle.Radius = S.FOV
                FOVCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
            end
        end)
    end

    -- Aimbot
    if S.Aimbot and Camera then
        local t = getAimTarget()
        if t then aimAt(t, dt) end
    end

    -- Player ESP
    if S.ESP_Player and hasDrawing and Camera then
        pcall(function()
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local d = getEsp(plr, Color3.fromRGB(0, 200, 255))
                        if d then
                            local pos, sz = getScreenBox(plr.Character)
                            if pos and sz then
                                d.Box.Size = sz
                                d.Box.Position = pos
                                d.Box.Visible = true

                                local head = plr.Character:FindFirstChild("Head")
                                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                                local dist = (head and hrp) and math.floor((Camera.CFrame.Position - hrp.Position).Magnitude) or 0
                                local txt = plr.Name
                                if S.ESP_Distance then txt = txt .. " [" .. dist .. "m]" end
                                d.Name.Text = txt
                                d.Name.Position = Vector2.new(pos.X + sz.X/2, pos.Y - 18)
                                d.Name.Visible = true

                                if S.ESP_Line then
                                    d.Line.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                                    d.Line.To = Vector2.new(pos.X + sz.X/2, pos.Y + sz.Y/2)
                                    d.Line.Visible = true
                                else
                                    d.Line.Visible = false
                                end
                            else
                                hideEsp(d)
                            end
                        end
                    elseif esp[plr] then
                        hideEsp(esp[plr])
                    end
                end
            end
        end)
    elseif not S.ESP_Player then
        for _, d in pairs(esp) do hideEsp(d) end
    end

    -- Zombie ESP
    if S.ESP_Zombie and hasDrawing and Camera then
        pcall(function()
            local f = workspace:FindFirstChild("Zombies") or workspace:FindFirstChild("Zombie")
            if f then
                for _, z in ipairs(f:GetChildren()) do
                    local hum = z:FindFirstChildOfClass("Humanoid")
                    local head = z:FindFirstChild("Head")
                    if hum and head and hum.Health > 0 then
                        local d = getEsp(z, Color3.fromRGB(255, 80, 80))
                        if d then
                            local pos, sz = getScreenBox(z)
                            if pos and sz then
                                d.Box.Size = sz
                                d.Box.Position = pos
                                d.Box.Visible = true
                                d.Name.Text = "Zombie"
                                d.Name.Position = Vector2.new(pos.X + sz.X/2, pos.Y - 18)
                                d.Name.Visible = true
                                if S.ESP_Line then
                                    d.Line.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                                    d.Line.To = Vector2.new(pos.X + sz.X/2, pos.Y + sz.Y/2)
                                    d.Line.Visible = true
                                else
                                    d.Line.Visible = false
                                end
                            else
                                hideEsp(d)
                            end
                        end
                    end
                end
            end
        end)
    end

    -- Item ESP
    if S.ESP_Items and hasDrawing and Camera then
        pcall(function()
            itemScanTimer = itemScanTimer + dt
            if itemScanTimer > 1.0 then
                itemScanTimer = 0
                local found = scanItems()
                for item, part in pairs(found) do
                    if not itemEsp[item] then
                        local txt = newDraw("Text")
                        local box = newDraw("Square")
                        if txt and box then
                            txt.Size = 13
                            txt.Center = true
                            txt.Outline = true
                            txt.Color = Color3.fromRGB(255, 200, 0)
                            txt.Visible = false
                            box.Thickness = 1
                            box.Filled = false
                            box.Color = Color3.fromRGB(255, 200, 0)
                            box.Visible = false
                            itemEsp[item] = { Text = txt, Box = box }
                        end
                    end
                end
            end

            -- render + cleanup
            for item, d in pairs(itemEsp) do
                if not item.Parent then
                    pcall(function() d.Text:Remove(); d.Box:Remove() end)
                    itemEsp[item] = nil
                else
                    local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
                    if part then
                        local sp, on = Camera:WorldToViewportPoint(part.Position)
                        if on and sp.Z > 0 then
                            local dist = math.floor((Camera.CFrame.Position - part.Position).Magnitude)
                            d.Text.Text = item.Name .. " [" .. dist .. "m]"
                            d.Text.Position = Vector2.new(sp.X, sp.Y - 8)
                            d.Text.Visible = true

                            local pos, sz = getScreenBox(item:IsA("Model") and item or nil)
                            if pos and sz then
                                d.Box.Size = sz
                                d.Box.Position = pos
                                d.Box.Visible = true
                            else
                                d.Box.Size = Vector2.new(24, 24)
                                d.Box.Position = Vector2.new(sp.X - 12, sp.Y - 12)
                                d.Box.Visible = true
                            end
                        else
                            d.Text.Visible = false
                            d.Box.Visible = false
                        end
                    end
                end
            end
        end)
    elseif not S.ESP_Items then
        for item, d in pairs(itemEsp) do
            pcall(function() d.Text.Visible=false; d.Box.Visible=false end)
        end
    end
end))

-- ============================================================
-- TECLA "-" → FECHA TUDO PERMANENTEMENTE
-- ============================================================
local closing = false

local function permanentClose()
    getgenv().AR2_ALIVE = false
    for _, c in ipairs(CONNS) do pcall(function() c:Disconnect() end) end
    for _, d in ipairs(DRAWS) do pcall(function() d:Remove() end) end
    if getgenv().AR2_FOLDER then pcall(function() getgenv().AR2_FOLDER:Destroy() end) end
    for k in pairs(esp) do esp[k] = nil end
    for k in pairs(itemEsp) do itemEsp[k] = nil end
    CONNS = {}
    DRAWS = {}
    getgenv().AR2_CONNECTIONS = {}
    getgenv().AR2_DRAWINGS = {}
end

newConn(UserInputService.InputBegan:Connect(function(input, gp)
    if gp or closing then return end
    if input.KeyCode == Enum.KeyCode.Minus or input.KeyCode == Enum.KeyCode.KeypadMinus then
        closing = true
        permanentClose()
        pcall(function()
            Rayfield:Notify({ Title="AR2", Content="bench fechado. executa o script dnv pra abrir.", Duration=3 })
        end)
    end
end))

pcall(function()
    Rayfield:Notify({ Title="AR2 Lite v3", Content="menu up — tecla '-' fecha permanente.", Duration=4, Image=4483362458 })
end)
