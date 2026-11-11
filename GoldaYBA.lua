local API = "https://morning-base-3d8e.daun7580.workers.dev"
local GET_KEY_LINK = "https://discord.gg/5JvnRB8TZk"

API = API:gsub("%s", ""):gsub("/+$", "") -- a trailing slash breaks every path

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local DIR = "GoldaYBA"
local KEY_FILE = DIR .. "/Key.txt"

local function getHwid()
    local ok, id = pcall(function() return gethwid and gethwid() end)
    if ok and type(id) == "string" and id ~= "" then return id end
    local ok2, cid = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
    if ok2 and cid then return tostring(cid) end
    return "uid-" .. lp.UserId
end
local HWID = getHwid()

local function call(path, key)
    local url = API .. path .. "?key=" .. HttpService:UrlEncode(key) .. "&hwid=" .. HttpService:UrlEncode(HWID)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" then return body end
    return nil
end

local REASONS = {
    ["invalid key"] = "That key doesn't exist",
    ["key expired"] = "This key has run out",
    ["key is linked to another device"] = "This key is already used on another PC",
    ["missing key"] = "Paste a key first",
    ["server error"] = "Key server hiccup, try again"
}

local function check(key)
    local body = call("/check", key)
    if not body then return false, "Can't reach the key server, try again" end
    local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok or type(data) ~= "table" then
        local snippet = body:gsub("%s+", " "):sub(1, 90)
        warn("[GoldaYBA] key server answered: " .. body:sub(1, 500))
        return false, "The key server sent something weird: " .. snippet
    end
    if data.ok then return true, nil, tonumber(data.expires) or 0 end
    return false, REASONS[data.reason] or tostring(data.reason)
end

local function saveKey(k)
    if not writefile then return end
    pcall(function()
        if makefolder and not (isfolder and isfolder(DIR)) then makefolder(DIR) end
        writefile(KEY_FILE, k)
    end)
end

local function readKey()
    if not (isfile and readfile) then return nil end
    local ok, k = pcall(function() return isfile(KEY_FILE) and readfile(KEY_FILE) end)
    if ok and type(k) == "string" and k:match("%S") then return (k:gsub("%s", "")) end
    return nil
end

local function timeLeft(expires)
    if not expires or expires == 0 then return "lifetime" end
    local s = math.max(0, math.floor(expires / 1000 - os.time()))
    local d, h, m = math.floor(s / 86400), math.floor(s % 86400 / 3600), math.floor(s % 3600 / 60)
    if d > 0 then return d .. "d " .. h .. "h left" end
    if h > 0 then return h .. "h " .. m .. "m left" end
    return m .. "m left"
end

local function launch(key, expires)
    saveKey(key)
    local env = (getgenv and getgenv()) or _G
    env.GoldaYBA_Key = { key = key, expires = expires or 0, left = timeLeft(expires) }

    local src = call("/script", key)
    if not src or (src:sub(1, 2) == "--" and #src < 200) then
        warn("[GoldaYBA] couldn't load the hub: " .. tostring(src))
        return false
    end
    local fn, err = loadstring(src)
    if not fn then
        warn("[GoldaYBA] the hub didn't compile: " .. tostring(err))
        return false
    end
    task.spawn(fn)
    return true
end

local saved = readKey()
local savedError
if saved then
    local ok, why, expires = check(saved)
    if ok and launch(saved, expires) then return end
    savedError = why
end

local function guiParent()
    local ok, g = pcall(function() return gethui and gethui() end)
    if ok and g then return g end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then return cg end
    return lp:WaitForChild("PlayerGui")
end

local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local C = {
    accent = Color3.fromRGB(96, 205, 255),
    accent2 = Color3.fromRGB(150, 110, 255),
    bg = Color3.fromRGB(20, 20, 23),
    field = Color3.fromRGB(28, 28, 33),
    line = Color3.fromRGB(55, 55, 62),
    text = Color3.fromRGB(235, 235, 240),
    dim = Color3.fromRGB(140, 140, 152),
    good = Color3.fromRGB(120, 230, 140),
    bad = Color3.fromRGB(255, 105, 105)
}

local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = o
end

local function stroke(o, color, transp)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = 1
    s.Transparency = transp or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = o
    return s
end

local function gradient(o, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(C.accent, C.accent2)
    g.Rotation = rot or 0
    g.Parent = o
    return g
end

local function label(parent, text, size, color, font)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Text = text
    t.TextColor3 = color
    t.Font = font or Enum.Font.GothamMedium
    t.TextSize = size
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = parent
    return t
end

local gui = Instance.new("ScreenGui")
gui.Name = "GoldaYBA_Key"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 200
gui.Parent = guiParent()

local win = Instance.new("Frame")
win.AnchorPoint = Vector2.new(0.5, 0.5)
win.Position = UDim2.fromScale(0.5, 0.5)
win.Size = UDim2.fromOffset(380, 214)
win.BackgroundColor3 = C.bg
win.BackgroundTransparency = 0.04
win.BorderSizePixel = 0
win.Active = true
win.Draggable = true
win.ClipsDescendants = true
win.Parent = gui
corner(win, 8)
stroke(win, C.line, 0.15)

local topLine = Instance.new("Frame")
topLine.Size = UDim2.new(1, 0, 0, 2)
topLine.BorderSizePixel = 0
topLine.BackgroundColor3 = Color3.new(1, 1, 1)
topLine.Parent = win
gradient(topLine)

local badge = Instance.new("TextLabel")
badge.Position = UDim2.fromOffset(16, 16)
badge.Size = UDim2.fromOffset(28, 28)
badge.BackgroundColor3 = Color3.new(1, 1, 1)
badge.BorderSizePixel = 0
badge.Text = "GY"
badge.TextColor3 = Color3.fromRGB(12, 12, 16)
badge.Font = Enum.Font.GothamBlack
badge.TextSize = 12
badge.Parent = win
corner(badge, 6)
gradient(badge, 45)

local name = label(win, "GoldaYBA", 15, C.text, Enum.Font.GothamBold)
name.Position = UDim2.fromOffset(54, 15)
name.Size = UDim2.new(1, -100, 0, 16)

local sub = label(win, "by Kabildzhon and IsraelGPT", 11, C.dim)
sub.Position = UDim2.fromOffset(54, 32)
sub.Size = UDim2.new(1, -100, 0, 13)

local close = Instance.new("TextButton")
close.Position = UDim2.new(1, -40, 0, 16)
close.Size = UDim2.fromOffset(24, 24)
close.BackgroundColor3 = C.field
close.BorderSizePixel = 0
close.Text = "X"
close.TextColor3 = C.dim
close.Font = Enum.Font.GothamBold
close.TextSize = 11
close.AutoButtonColor = true
close.Parent = win
corner(close, 6)
stroke(close, C.line, 0.3)
close.MouseButton1Click:Connect(function() gui:Destroy() end)

local field = Instance.new("Frame")
field.Position = UDim2.fromOffset(16, 60)
field.Size = UDim2.new(1, -32, 0, 38)
field.BackgroundColor3 = C.field
field.BorderSizePixel = 0
field.Parent = win
corner(field, 6)
local fieldStroke = stroke(field, C.line, 0.1)

local tag = label(field, "KEY", 10, C.dim, Enum.Font.GothamBold)
tag.Position = UDim2.fromOffset(12, 0)
tag.Size = UDim2.fromOffset(30, 38)

local box = Instance.new("TextBox")
box.Position = UDim2.fromOffset(44, 0)
box.Size = UDim2.new(1, -54, 1, 0)
box.BackgroundTransparency = 1
box.PlaceholderText = "GOLDA-XXXX-XXXX-XXXX"
box.PlaceholderColor3 = Color3.fromRGB(90, 90, 100)
box.Text = saved or ""
box.TextColor3 = C.text
box.Font = Enum.Font.GothamMedium
box.TextSize = 13
box.TextXAlignment = Enum.TextXAlignment.Left
box.ClearTextOnFocus = false
box.Parent = field

box.Focused:Connect(function()
    TweenService:Create(fieldStroke, TweenInfo.new(0.15), { Color = C.accent, Transparency = 0 }):Play()
end)
box.FocusLost:Connect(function()
    TweenService:Create(fieldStroke, TweenInfo.new(0.15), { Color = C.line, Transparency = 0.1 }):Play()
end)

local function button(text, x, primary)
    local b = Instance.new("TextButton")
    b.Position = UDim2.new(x, x == 0 and 16 or 5, 0, 110)
    b.Size = UDim2.new(0.5, -21, 0, 34)
    b.BackgroundColor3 = primary and Color3.new(1, 1, 1) or C.field
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = text
    b.TextColor3 = primary and Color3.fromRGB(12, 12, 16) or C.text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Parent = win
    corner(b, 6)
    if primary then
        gradient(b)
    else
        stroke(b, C.line, 0.1)
    end

    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.15 }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
    end)
    return b
end

local checkBtn = button("Check key", 0, true)
local getBtn = button("Get key", 0.5, false)

local statusDot = Instance.new("Frame")
statusDot.Position = UDim2.fromOffset(17, 163)
statusDot.Size = UDim2.fromOffset(6, 6)
statusDot.BorderSizePixel = 0
statusDot.BackgroundColor3 = savedError and C.bad or C.dim
statusDot.Parent = win
corner(statusDot, 3)

local status = label(win, "", 12, C.dim)
status.Position = UDim2.fromOffset(30, 158)
status.Size = UDim2.new(1, -46, 0, 32)
status.TextWrapped = true
status.TextYAlignment = Enum.TextYAlignment.Top

local foot = label(win, "Locked to this PC the first time you use it", 10, Color3.fromRGB(95, 95, 105))
foot.Position = UDim2.fromOffset(16, 192)
foot.Size = UDim2.new(1, -32, 0, 12)

local function setStatus(t, color)
    status.Text = t
    status.TextColor3 = color or C.dim
    statusDot.BackgroundColor3 = color or C.dim
end

setStatus(savedError and ("Saved key: " .. savedError) or "Paste your key and hit Check", savedError and C.bad or nil)

local busy = false
checkBtn.MouseButton1Click:Connect(function()
    if busy then return end
    local key = box.Text:gsub("%s", "")
    if key == "" then
        setStatus("Paste a key first", C.bad)
        return
    end
    busy = true
    setStatus("Checking...", C.accent)
    local ok, why, expires = check(key)
    if ok then
        setStatus("Key works (" .. timeLeft(expires) .. "), loading...", C.good)
        task.wait(0.4)
        gui:Destroy()
        if not launch(key, expires) then
            warn("[GoldaYBA] the key is fine but the hub didn't load, try again in a minute")
        end
    else
        setStatus(why, C.bad)
    end
    busy = false
end)

getBtn.MouseButton1Click:Connect(function()
    if setclipboard then
        pcall(setclipboard, GET_KEY_LINK)
        setStatus("Link copied, open it in your browser", C.good)
    else
        setStatus(GET_KEY_LINK)
    end
end)

