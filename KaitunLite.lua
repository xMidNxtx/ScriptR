-- End Hub - Anime Mining RNG : Kaitun Lite (สร้างจาก AnimeminingRNG.lua ด้วย build_kaitun.py ห้ามแก้ไฟล์นี้ตรงๆ)
-- UI: Velvet (github.com/DexCodeSX/Velvet)

----------------------------------------------------------------
-- ผิดเกม: loader รุ่นเก่า (ไม่ส่ง GameId) ได้สคริปต์นี้ในทุกเกม
--   -> ขอสคริปต์ของเกมนี้ใหม่ด้วยคีย์ที่ loader จำไว้ แล้วรันตัวนั้นแทน
--   EndHubRedirectAt กันวนซ้ำ (Worker ไม่มีสคริปต์ของเกมนั้น = ได้ตัวนี้กลับมาภายใน 15 วิ -> รันต่อตามเดิม)
----------------------------------------------------------------
do
    local env = (getgenv and getgenv()) or _G
    local redirected = (function()
        if game.GameId == 10740316645 then return false end
        if not game:IsLoaded() then game.Loaded:Wait() end
        local plrs = game:GetService("Players")
        while not plrs.LocalPlayer do task.wait() end
        if os.clock() - (tonumber(env.EndHubRedirectAt) or -1e9) < 15 then return false end
        local httpRequest = request or http_request or (syn and syn.request) or (http and http.request)
        if not httpRequest then return false end
        local okK, key = pcall(function()
            return isfile and isfile("EndHub_key.txt") and readfile("EndHub_key.txt") or nil
        end)
        if not okK or type(key) ~= "string" or key == "" then return false end
        local hwid = nil
        pcall(function() hwid = gethwid and gethwid() end)
        if type(hwid) ~= "string" or hwid == "" then
            pcall(function() hwid = game:GetService("RbxAnalyticsService"):GetClientId() end)
        end
        if type(hwid) ~= "string" or hwid == "" then return false end
        local Http = game:GetService("HttpService")
        local ok, res = pcall(httpRequest, {
            Url = "https://endhub.kantapongboontawin1.workers.dev/auth",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = Http:JSONEncode({
                key = key, hwid = hwid, user = (game:GetService("Players").LocalPlayer or { Name = "" }).Name,
                game = tostring(game.GameId), place = tostring(game.PlaceId),
            }),
        })
        if not ok or type(res) ~= "table" then return false end
        local okJ, data = pcall(Http.JSONDecode, Http, res.Body)
        if not okJ or type(data) ~= "table" or not data.ok or type(data.script) ~= "string" then return false end
        local fn = loadstring(data.script, "=EndHub")
        if not fn then return false end
        env.EndHubRedirectAt = os.clock()
        task.spawn(fn)
        return true
    end)()
    if redirected then return end
end

----------------------------------------------------------------
-- รันซ้ำ: ปิดตัวเก่าก่อน (ลบ UI + หยุดทุกลูป เหมือนกด X)
--   ตัวเก่าฝาก EndHubUnload ไว้ใน getgenv (ตั้งหลังครอบ Velvet:Destroy ด้านล่าง)
--   อยู่ใน do ... end: ไม่เพิ่ม local ระดับบนสุดของไฟล์
----------------------------------------------------------------
do
    local env = (getgenv and getgenv()) or _G
    local old = env.EndHubUnload
    env.EndHubUnload = nil
    if type(old) == "function" then
        local ok, err = pcall(old)
        if not ok then warn("[End Hub] unload old:", err) end
    end
    -- กวาด GUI ที่ยังค้าง (ตัวเก่าที่ไม่มี EndHubUnload / ของที่ Velvet:Destroy ไม่ลบ)
    --   EndHub_*        : ปุ่มลอยมือถือ, Pickaxe Shop, My Plot, Gem Shop
    --   มี EndHubLogo   : หน้าต่าง Velvet ของ End Hub (ไม่ไปลบ Velvet ของสคริปต์อื่น)
    --   VelvetQuickBar  : เฉพาะที่มีปุ่มที่เรา pin ไว้
    local function sweep(root)
        if not root then return end
        for _, g in ipairs(root:GetChildren()) do
            if g:IsA("ScreenGui") and (
                g.Name:sub(1, 7) == "EndHub_"
                or g:FindFirstChild("EndHubLogo", true)
                or (g.Name == "VelvetQuickBar" and g:FindFirstChild("Tile_AutoSmartEquip", true))
            ) then
                pcall(function() g:Destroy() end)
            end
        end
    end
    pcall(function() sweep(gethui()) end)
    pcall(function() sweep(game:GetService("CoreGui")) end)
    pcall(function() sweep(game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")) end)
end

----------------------------------------------------------------
-- LOAD
----------------------------------------------------------------
-- ================================================================
-- End Hub Kaitun Lite: Velvet แบบไม่มีหน้าต่าง (headless)
--   build_kaitun.py เอาก้อนนี้ไปแทนบรรทัดโหลด Velvet + addon ทั้งหมดของ AnimeminingRNG.lua
--   ไม่โหลด Library.lua / SaveManager / ThemeManager / QuickBar / NotificationHistory / Icons
--   ไม่สร้าง Instance เลย ยกเว้นป้ายสถานะ Kaitun 1 ป้าย (ปิดได้: _G.Kaitun.Status = false)
--
--   พฤติกรรม Flags / element ต้องตรงกับ Velvet จริง (ตรรกะฟาร์มอ่าน Flags + เรียก :Set):
--     Toggle  : สร้าง = ตั้ง Flag + ยิง listener (ไม่เรียก Callback) | :Set = Flag + listener + Callback
--     Slider  : เหมือน Toggle + clamp(Min, Max) + ปัดตาม Increment
--     Dropdown: สร้าง = ตั้ง Flag เฉยๆ | :Set = Flag + listener (ไม่เรียก Callback)
--     Input   : สร้าง = ตั้ง Flag เฉยๆ | :Set = Flag + listener (ไม่เรียก Callback)
--   ทั้งก้อนอยู่ในฟังก์ชัน: ไม่เพิ่ม local ระดับบนสุดของไฟล์ (จำกัด 200 ตอน -O0)
-- ================================================================
local Velvet, SaveManager, ThemeManager, Icons, QuickBar, NotifHistory = (function()
    local function noop() end
    -- ของที่ไม่มีหน้าที่ในโหมดนี้: เรียก method อะไรก็ได้ ไม่ error
    local function dummy()
        return setmetatable({}, { __index = function() return function() return dummy() end end })
    end

    local V = { Flags = {}, _elements = {}, _listeners = {}, _onDestroy = {}, Windows = {}, Theme = {} }

    local function safecall(name, fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then warn("[End Hub] " .. name .. ": " .. tostring(err)) end
    end
    local function fireListeners(id, val)
        local cbs = V._listeners[id]
        if cbs then
            for _, fn in ipairs(cbs) do safecall("Listener:" .. tostring(id), fn, val) end
        end
    end
    function V:OnFlagChanged(id, fn)
        if not self._listeners[id] then self._listeners[id] = {} end
        table.insert(self._listeners[id], fn)
    end
    local function attachOnChanged(elem, id)
        function elem:OnChanged(fn)
            V:OnFlagChanged(id, fn)
            return self
        end
    end

    -------------------- ป้ายสถานะ Kaitun (ป้ายเดียว ไม่มีกรอบ / ไม่มี animation) --------------------
    local env = (getgenv and getgenv()) or _G
    local userCfg = (type(env.Kaitun) == "table" and env.Kaitun) or (type(_G.Kaitun) == "table" and _G.Kaitun) or {}
    local showStatus = userCfg.Status ~= false
    local statusGui, statusLabel = nil, nil
    local function setStatus(text)
        if not showStatus then return end
        if not statusLabel then
            local ok = pcall(function()
                local gui = Instance.new("ScreenGui")
                gui.Name = "EndHub_KaitunStatus"  -- ขึ้นต้น EndHub_ = รันซ้ำแล้วโดนกวาดทิ้ง
                gui.ResetOnSpawn = false
                gui.IgnoreGuiInset = true
                local label = Instance.new("TextLabel")
                label.BackgroundTransparency = 0.4
                label.BackgroundColor3 = Color3.new(0, 0, 0)
                label.BorderSizePixel = 0
                label.TextColor3 = Color3.new(1, 1, 1)
                label.Font = Enum.Font.Code
                label.TextSize = 13
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.TextYAlignment = Enum.TextYAlignment.Top
                label.AutomaticSize = Enum.AutomaticSize.XY
                label.Position = UDim2.fromOffset(8, 8)
                label.Parent = gui
                local okH, hui = pcall(function() return gethui() end)
                if not (okH and hui and pcall(function() gui.Parent = hui end)) then
                    if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
                        gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
                    end
                end
                statusGui, statusLabel = gui, label
            end)
            if not ok then showStatus = false; return end
        end
        statusLabel.Text = "End Hub Kaitun Lite\n" .. tostring(text)
    end

    -------------------- element --------------------
    local function newSection()
        local section = setmetatable({}, { __index = function() return function() return dummy() end end })

        function section:AddToggle(id, opts)
            opts = opts or {}
            local value = opts.Default or false
            local cb = opts.Callback or noop
            local function update(v, silent)
                value = v
                V.Flags[id] = v
                fireListeners(id, v)
                if not silent then safecall("Toggle:" .. tostring(id), cb, v) end
            end
            update(value, true)
            local toggle = { Value = value }
            function toggle:Set(v) update(v) end
            function toggle:Get() return value end
            attachOnChanged(toggle, id)
            V._elements[id] = toggle
            return toggle
        end

        function section:AddSlider(id, opts)
            opts = opts or {}
            local min, max, inc = opts.Min or 0, opts.Max or 100, opts.Increment or 1
            local cb = opts.Callback or noop
            local function clamp(v) return math.max(min, math.min(max, v)) end
            local value = clamp(opts.Default or min)
            local function update(v, silent)
                v = math.floor(clamp(v) / inc + 0.5) * inc
                value = v
                V.Flags[id] = v
                fireListeners(id, v)
                if not silent then safecall("Slider:" .. tostring(id), cb, v) end
            end
            update(value, true)
            local slider = { Value = value }
            function slider:Set(v) update(v) end
            function slider:Get() return value end
            attachOnChanged(slider, id)
            V._elements[id] = slider
            return slider
        end

        function section:AddDropdown(id, opts)
            opts = opts or {}
            local values = opts.Values or {}
            local multi = opts.Multi or false
            local selected = multi and {} or (opts.Default or (values[1] or ""))
            if multi and opts.Default then
                for _, v in pairs(opts.Default) do selected[v] = true end
            end
            V.Flags[id] = selected
            local dropdown = { Value = selected }
            function dropdown:Set(v)
                selected = v
                V.Flags[id] = selected
                fireListeners(id, selected)
            end
            function dropdown:Refresh(newValues) values = newValues end
            function dropdown:Get() return selected end
            attachOnChanged(dropdown, id)
            V._elements[id] = dropdown
            return dropdown
        end

        function section:AddInput(id, opts)
            opts = opts or {}
            local value = opts.Default or ""
            V.Flags[id] = value
            local input = { Value = value }
            function input:Set(v)
                value = v
                V.Flags[id] = v
                fireListeners(id, v)
            end
            function input:Get() return value end
            attachOnChanged(input, id)
            V._elements[id] = input
            return input
        end

        function section:AddParagraph(opts)
            opts = opts or {}
            local para = {}
            if opts.Content == "EndHubKaitunStatus" then
                function para:Set(txt) setStatus(txt) end
            else
                para.Set = noop
            end
            return para
        end

        function section:AddButton() return dummy() end
        return section
    end

    local function newTab()
        local tab = setmetatable({}, { __index = function() return function() return dummy() end end })
        function tab:AddSection() return newSection() end
        return tab
    end

    -------------------- library --------------------
    function V:CreateWindow()
        local window = setmetatable({ Visible = false }, {
            __index = function() return function() return dummy() end end,
        })
        function window:AddTab() return newTab() end
        window.Show, window.Hide, window.SetScale = noop, noop, noop
        table.insert(V.Windows, window)
        return window
    end
    V.SetIcons, V.SetTheme, V.Notify = noop, noop, noop
    function V:ResolveIcon() return nil end
    function V:CreateWatermark() return dummy() end
    function V:OnDestroy(fn) table.insert(self._onDestroy, fn) end
    function V:Destroy()
        for _, fn in ipairs(self._onDestroy) do pcall(fn) end
        table.clear(self._onDestroy)
        if statusGui then pcall(function() statusGui:Destroy() end) end
        statusGui, statusLabel, showStatus = nil, nil, false
        table.clear(self.Windows)
        table.clear(self.Flags)
        table.clear(self._listeners)
        table.clear(self._elements)
    end

    local function fail() return false, "Kaitun Lite has no config UI" end
    local SM = {
        Bind = noop, BuildProfileUI = noop,
        Save = fail, Load = fail, LoadProfile = fail, Import = fail,
    }
    local TM = { AddTheme = noop, SetTheme = noop, Bind = noop, Current = nil }
    function TM:GetThemes() return {} end
    local QB = { _gui = nil, _bar = nil, _pins = {}, Bind = noop, Pin = noop, PinButton = noop, Destroy = noop }
    local NH = { Bind = noop }
    local IC = { Get = noop, Fuzzy = noop }

    return V, SM, TM, IC, QB, NH
end)()

----------------------------------------------------------------
-- SETUP
----------------------------------------------------------------
Velvet:SetIcons(Icons)
SaveManager:Bind(Velvet, "EndHub")
ThemeManager:Bind(Velvet)

----------------------------------------------------------------
-- THEME "End Hub" (โทนมืด minimal + สีน้ำเงินม่วงไฟฟ้าสีเดียว)
--
-- หลักการ:
--   - พื้นเป็นสีเทาดำกลางๆ (ไม่อมม่วงแบบ Midnight) ไล่ระดับ Base -> Surface -> Panel
--   - ขอบบางและจาง ไม่แย่งสายตา
--   - สีเด่นมีสีเดียว (Accent) ใช้กับ toggle ที่เปิด, tab ที่เลือก, slider
--     ต้องเข้มพอให้ "ปุ่มกลมสีขาว" ของ toggle และตัวหนังสือสีขาวบน tab อ่านออก
--
-- สำคัญ: ห้ามใส่สีซ้ำกันใน theme นี้
--   Velvet เปลี่ยน theme โดยหา "สีเก่า" ทุกจุดแล้วแทนด้วยสีใหม่
--   ถ้าสองช่องสีเดียวกัน ตอนเปลี่ยนไป theme อื่นจะเปลี่ยนผิดช่อง
----------------------------------------------------------------
ThemeManager:AddTheme("End Hub", {
    Base       = Color3.fromRGB(9, 9, 11),      -- พื้นหน้าต่าง (เกือบดำ)
    Surface    = Color3.fromRGB(17, 17, 20),    -- พื้นชั้นที่ 2 (ราง toggle, กล่อง)
    Panel      = Color3.fromRGB(24, 24, 28),    -- พื้น section / ปุ่ม
    Border     = Color3.fromRGB(39, 39, 45),    -- เส้นขอบบางๆ
    Accent     = Color3.fromRGB(99, 102, 241),  -- สีเด่น (indigo)
    AccentDark = Color3.fromRGB(79, 70, 229),   -- สีเด่นตอนกด / hover
    Text       = Color3.fromRGB(244, 244, 245), -- ตัวหนังสือหลัก
    TextDim    = Color3.fromRGB(161, 161, 170), -- ตัวหนังสือรอง
    TextMuted  = Color3.fromRGB(98, 98, 108),   -- ตัวหนังสือจางสุด (คำอธิบาย)
    Success    = Color3.fromRGB(52, 211, 153),
    Warning    = Color3.fromRGB(251, 191, 36),
    Error      = Color3.fromRGB(248, 113, 113),
    Info       = Color3.fromRGB(96, 165, 250),
})
-- ตั้งก่อนสร้างหน้าต่าง -> ทุกอย่างถูกสร้างด้วยสีใหม่ตั้งแต่แรก
-- (ยังเปลี่ยนเป็น theme อื่นได้ที่ Settings > Theme)
ThemeManager:SetTheme("End Hub")

----------------------------------------------------------------
-- WINDOW
----------------------------------------------------------------
-- เลข version ที่เดียว: ใช้ทั้งใต้ชื่อหน้าต่าง และแจ้งเตือนตอนโหลด (ขวาบน)
local VERSION = "2.0.7"
local Window = Velvet:CreateWindow({
    Title = "End Hub",
    SubTitle = "version:" .. VERSION,
    ToggleKey = Enum.KeyCode.RightShift,
    ToggleIcon = "sparkles",  -- สำรอง: ถ้าใส่โลโก้ไม่สำเร็จจะเห็นไอคอนนี้แทน
})

----------------------------------------------------------------
-- LOGO (บล็อกหินสไตล์ End Stone)
--
-- หลักการ:
--   - Velvet ไม่มีช่องใส่โลโก้ เลยวาดเองเป็น pixel art 8x8 จาก Frame
--     (ไม่ต้องอัปโหลดรูปขึ้น Roblox)
--   - พื้นบล็อกสีครีมอมเหลือง + จุดสว่าง / หลุมตื้น / หลุมลึก
--   - ใส่ 2 ที่: หัวหน้าต่าง End Hub (แทนจุดกลมกระพริบ) และปุ่มลอยตอนซ่อนหน้าต่าง
--
-- หมายเหตุ: สีโลโก้ห้ามตรงกับสีใน theme
--           (ไม่งั้นตอนเปลี่ยน theme Velvet จะเปลี่ยนสีโลโก้ไปด้วย)
----------------------------------------------------------------
local LOGO_BASE = Color3.fromRGB(221, 224, 160)  -- พื้นบล็อก (ตัวอักษร ".")
local LOGO_COLORS = {
    l = Color3.fromRGB(238, 240, 186),  -- จุดสว่าง
    d = Color3.fromRGB(196, 198, 136),  -- หลุมตื้น
    x = Color3.fromRGB(166, 167, 112),  -- หลุมลึก
}
-- แผนที่ pixel: 1 ตัวอักษร = 1 ช่อง (8 แถว x 8 ช่อง)
local LOGO_PIXELS = {
    "l..d.l..",
    ".x...d.l",
    "..l.....",
    "d...xd..",
    ".l.....l",
    "...d.l..",
    "xd.....d",
    "..l.d...",
}

-- สร้างโลโก้ขนาด size x size (ใช้ size ที่หาร 8 ลงตัว จะได้ pixel คมไม่เบลอ)
local function makeLogo(parent, size, zindex)
    local n = #LOGO_PIXELS
    local logo = Instance.new("Frame")
    logo.Name = "EndHubLogo"
    logo.Size = UDim2.fromOffset(size, size)
    logo.BackgroundColor3 = LOGO_BASE
    logo.BorderSizePixel = 0
    logo.ZIndex = zindex
    -- วาดเฉพาะช่องที่ไม่ใช่สีพื้น
    for y, row in ipairs(LOGO_PIXELS) do
        for x = 1, #row do
            local color = LOGO_COLORS[row:sub(x, x)]
            if color then
                local px = Instance.new("Frame")
                px.Size = UDim2.fromScale(1 / n, 1 / n)
                px.Position = UDim2.fromScale((x - 1) / n, (y - 1) / n)
                px.BackgroundColor3 = color
                px.BorderSizePixel = 0
                px.ZIndex = zindex + 1
                px.Parent = logo
            end
        end
    end
    -- ขอบเข้มบางๆ ให้บล็อกดูมีมิติ
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 70, 46)
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = logo
    logo.Parent = parent
    return logo
end

-- เอาโลโก้ไปใส่ในหน้าต่าง Velvet
local function applyLogo()
    local main = Window._main
    local header = main and main:FindFirstChild("Header")
    if not header then return end

    -- 1) หัวหน้าต่าง: ลบจุดกลมกระพริบเดิม (Frame เล็กๆ สี Accent) แล้วใส่โลโก้แทน
    for _, child in ipairs(header:GetChildren()) do
        if child:IsA("Frame") and child.BackgroundColor3 == Velvet.Theme.Accent
            and child.Size.X.Offset <= 16 then
            child:Destroy()
        elseif child:IsA("TextLabel") and child.Position.X.Offset == 30 then
            -- ชื่อ + version เดิมอยู่ x=30 เลื่อนไปทางขวาให้มีที่ว่างสำหรับโลโก้
            child.Position = UDim2.new(0, 44, child.Position.Y.Scale, child.Position.Y.Offset)
        end
    end
    makeLogo(header, 24, 6).Position = UDim2.new(0, 12, 0.5, -12)

    -- 2) ปุ่มลอย (โผล่ตอนซ่อนหน้าต่าง): เอาไอคอนเดิมออก ใส่โลโก้แทน
    local pill = main.Parent and main.Parent:FindFirstChild("VelvetToggle")
    if pill then
        for _, child in ipairs(pill:GetChildren()) do
            if child:IsA("ImageLabel") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end
        local size = pill.Size.Y.Offset >= 48 and 32 or 24  -- มือถือปุ่มใหญ่กว่า
        local logo = makeLogo(pill, size, 101)
        logo.AnchorPoint = Vector2.new(0.5, 0.5)
        logo.Position = UDim2.fromScale(0.5, 0.5)
    end
end

local logoOk, logoErr = pcall(applyLogo)
if not logoOk then
    warn("[End Hub] logo error:", logoErr)
end

----------------------------------------------------------------
-- ADDONS BIND
----------------------------------------------------------------
QuickBar:Bind(Velvet, Window, { MaxPins = 6 })
NotifHistory:Bind(Velvet, Window)

----------------------------------------------------------------
-- GAME LOGIC
----------------------------------------------------------------
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local Event = RS:WaitForChild("Remotes"):WaitForChild("GamestateEvent")
local MineCatalog = require(RS:WaitForChild("Modules"):WaitForChild("MineOreCatalog"))

local function fire(...)
    local args = table.pack(...)
    pcall(function() Event:FireServer(table.unpack(args, 1, args.n)) end)
end

-- read a numeric slider flag with a fallback (flag can be nil before load)
local function flag(name, default)
    local v = Velvet.Flags[name]
    return (type(v) == "number" and v > 0) and v or default
end

-- makeLoop(fn, getInterval) -> start, stop  (runs in its own thread)
-- gen = เลขรอบการเปิด ใช้กันไม่ให้ลูปเก่าวิ่งซ้อนกับลูปใหม่
--       (ปิดแล้วเปิดใหม่เร็วๆ ลูปเก่าที่ยังรออยู่จะเห็นว่า gen เปลี่ยนแล้วหยุดเอง)
-- fn จะได้ alive() ไปด้วย ใช้เช็คกลางทางว่ายังเปิดอยู่ไหม
local function makeLoop(fn, getInterval)
    local running, gen = false, 0
    local function start()
        if running then return end
        running = true
        gen += 1
        local myGen = gen
        local function alive() return running and gen == myGen end
        task.spawn(function()
            while alive() do
                -- pcall: รอบไหน error ก็ข้ามรอบนั้นไป ลูปไม่ตายเงียบๆ ทั้งที่ toggle ยังเปิดอยู่
                local ok, err = pcall(fn, alive)
                if not ok then warn("[End Hub] loop error:", err) end
                if not alive() then break end
                task.wait(getInterval())
            end
        end)
    end
    local function stop() running = false end
    return start, stop
end

-- isolated(fn) -> ok, ...ค่าที่ fn คืน
-- รัน fn ใน thread แยก แล้วรอผล ใช้กับโค้ดที่เรียกฟังก์ชันของเกม
--   (ฟังก์ชันเกมบางตัว require module อื่นข้างใน เช่น MineConfig.GetVariantData
--    เคยเจอ: เรียกแล้ว thread เสียสิทธิ์ ทำ UI / แจ้งเตือนต่อไม่ได้)
--   thread ที่เรียก isolated ไม่โดนไปด้วย
local function isolated(fn)
    local out, done = nil, false
    task.spawn(function()
        out = table.pack(pcall(fn))
        done = true
    end)
    while not done do task.wait() end
    return table.unpack(out, 1, out.n)
end

----------------------------------------------------------------
-- PLOT ของเรา
--   workspace.MineWorld.Plots.MinePlot<n> มี attribute:
--     OwnerUserId = UserId เจ้าของ, PlotIndex = เลข plot, ZoneKey = zone ของ plot (เช่น Z7)
--   หา plot ที่ OwnerUserId == LP.UserId
----------------------------------------------------------------
-- อ่านค่าจาก attribute ก่อน ไม่มีค่อยหา ValueObject ลูกชื่อเดียวกัน
local function readValue(inst, key)
    local v = inst:GetAttribute(key)
    if v == nil then
        local obj = inst:FindFirstChild(key)
        if obj and obj:IsA("ValueBase") then v = obj.Value end
    end
    return v
end

local function getPlotOwnerId(plot)
    return tonumber(readValue(plot, "OwnerUserId") or readValue(plot, "OwnerId"))
end

-- คืน plot (Instance), เลข plot  | ไม่เจอ = nil
--   จำ plot ล่าสุดไว้: ถ้ายังอยู่ใน Plots และยังเป็นของเรา ไม่ต้องสร้าง array ของทุก plot ใหม่ทุกรอบ
local getMyPlot
do
    local cachedPlot, cachedNum = nil, nil
    getMyPlot = function()
        local world = workspace:FindFirstChild("MineWorld")
        local plots = world and world:FindFirstChild("Plots")
        if not plots then return nil end
        if cachedPlot and cachedPlot.Parent == plots and getPlotOwnerId(cachedPlot) == LP.UserId then
            return cachedPlot, cachedNum
        end
        cachedPlot, cachedNum = nil, nil
        for _, plot in ipairs(plots:GetChildren()) do
            if getPlotOwnerId(plot) == LP.UserId then
                local num = tonumber(readValue(plot, "PlotIndex")) or tonumber(plot.Name:match("(%d+)")) or plot.Name
                cachedPlot, cachedNum = plot, num
                return plot, num
            end
        end
        return nil
    end
end

-- เงินตอนนี้ จาก LocalPlayer.leaderstats.Cash.Value (แหล่งหลักของทุกระบบ auto buy)
--   คืน เงิน (ตัวเลข หรือ nil ถ้ายังไม่โหลด / อ่านไม่ออก), ค่าดิบ (ไว้ debug), ที่มา (ไว้ debug)
--   รองรับทั้ง NumberValue และ StringValue ที่เกมย่อไว้ เช่น "$1.25M", "3.4Qa", "1,234", "1.2e+20", "💰 1.2K"
--   (เงินเกม 1e18 ขึ้นไปใส่ IntValue ไม่ได้ -> หลายเกมเก็บเป็นข้อความย่อ)
--   หา "Cash" ไม่เจอ -> ลองชื่ออื่นใน leaderstats (Money / Coins / Gold / ชื่อที่มีคำว่า cash) -> attribute ของ player
-- ตัวย่อเลขของเกม เรียงทีละ x1000 (ตัวที่ i = 1000^(i-1)) จากโมดูล Researches ของเกม
--   ใช้ทั้งอ่านเงิน (parseMoney) และแสดงเลข (short) -> เลขที่เราโชว์ตรงกับที่เกมโชว์
--   เกมไม่มี "Dvg": Vg (1e63) -> Uvg (1e66) -> Tvg (1e69)   เพดานเงินของเกม zone 13 = 1e87 (Novg)
local SUFFIX = {
    "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
    "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod",
    "Vg", "Uvg", "Tvg", "Qavg", "Qivg", "Sxvg", "Spvg", "Ocvg", "Novg",
    "Tg", "Utg", "Dtg", "Ttg", "Qatg", "Qitg", "Sxtg", "Sptg", "Octg", "Notg",
}

local getCash
do
    -- ตัวย่อ (เทียบแบบตัวเล็ก) -> เลขยกกำลัง 10
    --   ชุดแรก = ชื่อเรียกแบบอื่นที่เกมอื่นใช้ (เผื่อไว้) / ตัวย่อของเกมนี้ใส่ทับจาก SUFFIX ข้างล่าง
    local MULT = {
        k = 3, m = 6, b = 9, t = 12, mn = 6, bn = 9, tn = 12,
        qa = 15, qd = 15, q = 15,
        qi = 18, qn = 18, qt = 18,
        sx = 21, sp = 24, oc = 27, o = 27, no = 30, n = 30,
        dc = 33, de = 33, d = 33, ud = 36, dd = 39, td = 42,
        qad = 45, qid = 48, sxd = 51, spd = 54, ocd = 57, nod = 60, vg = 63, v = 63,
    }
    for i, s in ipairs(SUFFIX) do
        if s ~= "" then MULT[s:lower()] = (i - 1) * 3 end
    end
    local function parseMoney(v)
        if type(v) == "number" then return v end
        if v == nil then return nil end
        local n = tonumber(v)
        if n then return n end
        -- ตัด RichText tag, ช่องว่าง, ลูกน้ำ, สัญลักษณ์เงิน
        local s = tostring(v):gsub("<[^>]+>", ""):gsub("[%s,%$]", "")
        n = tonumber(s)
        if n then return n end
        -- หาเลข + ตัวย่อตัวแรกในข้อความ (ข้างหน้า/ข้างหลังมีอย่างอื่นได้ เช่น "💰1.2Qa" หรือ "1.2M/s")
        for num, suffix in s:gmatch("(%d[%d%.]*[eE]?[%+%-]?%d*)(%a*)") do
            n = tonumber(num)
            if n then
                if suffix == "" then return n end
                local key = suffix:lower()
                -- ตัวย่อยาวไม่ตรง -> ลองตัดให้สั้นลง (เช่น "Qa" จาก "Qa/s" ถูกตัดไปแล้ว แต่ "Mcash" -> "m")
                while #key > 0 do
                    if MULT[key] then return n * 10 ^ MULT[key] end
                    key = key:sub(1, -2)
                end
                -- ตัวย่อที่ไม่รู้จัก -> ไม่เดา (เดาผิด = คิดว่าเงินน้อยกว่าจริง แล้วไม่ซื้อ/ไม่อัปเงียบๆ)
                return nil
            end
        end
        return nil
    end

    local CASH_NAMES = { "Cash", "Money", "Coins", "Coin", "Gold", "Currency" }
    local function valueOf(obj)
        if obj:IsA("ValueBase") then return obj.Value end
        local a = obj:GetAttribute("Value")
        if a ~= nil then return a end
        if obj:IsA("TextLabel") then return obj.Text end
        return nil
    end
    local function findCashObject(ls)
        for _, name in ipairs(CASH_NAMES) do
            local obj = ls:FindFirstChild(name)
            if obj then return obj end
        end
        -- ชื่อที่มีคำว่า cash / money / coin (เช่น "💰 Cash", "TotalCash")
        for _, obj in ipairs(ls:GetChildren()) do
            local low = obj.Name:lower()
            if low:find("cash") or low:find("money") or low:find("coin") then return obj end
        end
        return nil
    end

    getCash = function()
        local ls = LP:FindFirstChild("leaderstats")
        local obj = ls and findCashObject(ls)
        if obj then
            local raw = valueOf(obj)
            return parseMoney(raw), raw, "leaderstats." .. obj.Name
        end
        -- ไม่มีใน leaderstats -> attribute ของ player
        for _, name in ipairs(CASH_NAMES) do
            local raw = LP:GetAttribute(name)
            if raw ~= nil then return parseMoney(raw), raw, "Player@" .. name end
        end
        -- บอกว่าใน leaderstats มีอะไรบ้าง (ไว้ debug ตอนหาไม่เจอ)
        local names = {}
        for _, c in ipairs(ls and ls:GetChildren() or {}) do table.insert(names, c.Name .. ":" .. c.ClassName) end
        return nil, nil, ls and ("leaderstats มี: " .. (#names > 0 and table.concat(names, ", ") or "(ว่าง)")) or "ไม่มี leaderstats"
    end
end

----------------------------------------------------------------
-- TABS (แท็บด้านข้าง 1 แท็บ = 1 หมวด)
-- สร้างแท็บ + หมวดทั้งหมดไว้ตรงนี้ ฟังก์ชันข้างล่างค่อยใส่ลงหมวดของตัวเอง
--
--   Troops    > Auto Equip      : Auto Equip Best Troop
--             > Auto Upgrade Plot : อัป Damage / Speed / Mining Speed ของ miner บน plot (MineUpgradeCharacter)
--                                  + Focus Strongest Pad (อัปตัวแรงสุดจนตันก่อน)
--                                  + My Plot (หน้าต่างการ์ด miner บน plot ของเรา)
--   Rewards   > Chest           : Auto Take Chest
--             > Daily Spin      : Automatically Daily Spin
--             > Mailbox         : Auto Claim Mailbox (ClaimMailboxReward)        [ท้ายไฟล์ Addon.claims]
--             > Event Milestones: Auto Claim Event Milestones (MineEventsClaim)  [ท้ายไฟล์ Addon.claims]
--             > Index Rewards   : Auto Claim Index (MineIndexClaim)              [ท้ายไฟล์ Addon.claims]
--   Pickaxe   > Pickaxe Shop    : Pickaxe Shop Config, Auto Buy Pickaxe
--   Sell      > Auto Sell Ores  : Auto Sell Ores
--             > Auto Sell Characters : ขายตัวละคร rarity ที่ติ๊กไว้ (multi dropdown, MineSellItems) [ท้ายไฟล์ Addon.sellChars]
--   Research  > Auto Research   : Auto Buy Skill Tree (MineBuySkill), Skill Tree Status
--   Gem Shop  > Gem Shop        : Gem Shop Config (การ์ด potion), Auto Buy Potion (MineGemShopBuy)
--             > Auto Use Potion : ดื่ม potion แบบมีเวลาตอน boost หมด (MineUsePotion) [ท้ายไฟล์ Addon.usePotion]
--   Settings  > Interface / Config / Profiles   (สร้างไว้ท้ายไฟล์)
--
-- ลำดับบนหน้าจอ = ลำดับที่สร้างแท็บ/หมวดตรงนี้ (ไม่ใช่ลำดับที่ใส่ปุ่ม)
-- id ของ toggle/slider ไม่ได้เปลี่ยน -> config ที่เซฟไว้ยังใช้ได้
----------------------------------------------------------------
-- แท็บ Kaitun อยู่บนสุด (สร้างก่อน) ของข้างในใส่ทีหลังใน KAITUN ส่วนที่ 2
Window.EndHubKaitunTab = Window:AddTab("Kaitun", "zap")
local MinerTab = Window:AddTab("Miner", "swords")
local troopSection = MinerTab:AddSection("Auto Equip")
local plotSection = MinerTab:AddSection("Upgrade Miner")

local rewardTab = Window:AddTab("Rewards", "gift")
local chestSection = rewardTab:AddSection("Chest")
local spinSection = rewardTab:AddSection("Daily Spin")

local pickaxeSection = Window:AddTab("Pickaxe", "pickaxe"):AddSection("Pickaxe Shop")

local sellTab = Window:AddTab("Sell", "coins")
local sellSection = sellTab:AddSection("Auto Sell Ores")

local researchTab = Window:AddTab("Research", "flask-conical")
local researchSection = researchTab:AddSection("Auto Research")

-- Addon = ของที่เพิ่มทีหลัง (Gem Shop / Weblog) เก็บทุกอย่างในตารางเดียว
--   ไม่เพิ่ม local ระดับบนสุด (จำกัด 200 ตัวตอน -O0) ตัวฟังก์ชันอยู่ท้ายไฟล์ก่อน KAITUN ส่วนที่ 2
local Addon: { [string]: any } = { gemTab = Window:AddTab("Gem Shop", "gem"), diceTab = Window:AddTab("Dice", "dices") }

----------------------------------------------------------------
-- Miners 
----------------------------------------------------------------
-- (Auto Equip Best ของเกมถูกเอาออก: เลือกตัวไม่ดูเลเวล -> ใช้ Smart Equip แทน อยู่หมวดนี้เป็นอันแรก ดู Addon.smartEquip)

----------------------------------------------------------------
-- REWARDS
----------------------------------------------------------------
-- Auto Take Chest
local starttakeChest, stopTakeChest = makeLoop(
    function() fire("MineTakeChest") end,
    function() return flag("TakeInterval", 30) end
)

chestSection:AddToggle("AutoTakeChest", {
    Text = "Auto Take Chest",
    Default = false,
    Callback = function(on)
        if on then starttakeChest() else stopTakeChest() end
    end
})

chestSection:AddSlider("TakeInterval", {
    Text = "Take Chest Interval",
    Min = 3, Max = 300, Default = 30, Increment = 1,
    Suffix = "s",
    VisibleWhen = "AutoTakeChest",
})

----------------------------------------------------------------
-- DAILY SPIN (แท็บ Rewards)
--   remote: Event:FireServer("MineDailySpinOpen")  = เปิดกระดาน (server สร้าง/ส่งกระดานมา)
--           Event:FireServer("MineDailySpin")      = หมุนจริง (เดิมยิงแค่ Open เลยไม่เคยหมุน)
--   ผล: OnClientEvent("MineDailySpinView", { t = "board", nextAt, ... } / { t = "spin", refused, reason, ... })
--   หมุนได้เมื่อเวลา server >= MineGame.DailySpin.NextAt (คูลดาวน์ 24 ชม.)
--   ยังไม่ถึงเวลา = ไม่ยิงอะไรเลย แค่นับถอยหลัง / ไม่รู้ NextAt = ลองหมุน ให้ server ตัดสิน
----------------------------------------------------------------
local startDailySpin, stopDailySpin
do
    local para = spinSection:AddParagraph({ Title = "Daily Spin", Content = "ปิดอยู่" })
    local viewNextAt, lastResult, lastTry = nil, nil, -math.huge

    pcall(function()
        Event.OnClientEvent:Connect(function(name, p)
            if name ~= "MineDailySpinView" or type(p) ~= "table" then return end
            if tonumber(p.nextAt) then viewNextAt = tonumber(p.nextAt) end
            if p.t == "spin" then
                lastResult = p.refused and ("ไม่ได้: " .. tostring(p.reason or "server ปฏิเสธ")) or "หมุนแล้ว"
            end
        end)
    end)

    local function serverNow()
        local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
        return ok and t or os.time()
    end
    local function spinData()
        -- Addon.mineGame ถูกกำหนดท้ายไฟล์ (ตอนลูปรันมีแล้ว) ข้างในใช้ getMineGame เป็นตัวสำรองให้เอง
        local mg = Addon.mineGame and Addon.mineGame() or nil
        return mg and type(mg.DailySpin) == "table" and mg.DailySpin or nil
    end
    local function nextAt()
        local d = spinData()
        return math.max(tonumber(d and d.NextAt) or 0, viewNextAt or 0)
    end
    local function fmt(s)
        s = math.max(0, math.floor(s))
        return ("%d:%02d:%02d"):format(s // 3600, s // 60 % 60, s % 60)
    end
    local function lastText()
        local d = spinData()
        if d and d.LastName then
            return (" · ล่าสุด: %s x%s"):format(tostring(d.LastName), tostring(d.LastAmount or 1))
        end
        return ""
    end

    local function pass()
        local wait = nextAt() - serverNow()
        if wait > 0 then
            return para:Set(("หมุนได้อีกใน %s%s"):format(fmt(wait), lastText()))
        end
        if os.clock() - lastTry < 20 then return end  -- เพิ่งลองไป รอผล
        lastTry = os.clock()
        lastResult = nil
        -- เปิดกระดานก่อน แล้วเช็คเวลาจากกระดานอีกที (เพิ่งเข้าเกม ข้อมูล DailySpin ยังไม่มา = nextAt เป็น 0)
        --   เดิมหมุนเลย -> server ปฏิเสธ แต่ยังส่ง "Daily Spin ได้ ..." (ของรอบเก่า) ขึ้นเว็บทุกครั้งที่เข้าเกม
        para:Set("กำลังเช็คกระดาน...")
        fire("MineDailySpinOpen")
        local t0 = os.clock()
        while os.clock() - t0 < 3 and nextAt() <= serverNow() do task.wait(0.25) end
        if nextAt() > serverNow() then return end  -- ยังไม่ถึงเวลา -> รอบหน้านับถอยหลังเอง
        para:Set("กำลังหมุน...")
        fire("MineDailySpin")
        t0 = os.clock()
        while os.clock() - t0 < 8 and lastResult == nil and nextAt() <= serverNow() do task.wait(0.25) end
        local after = nextAt() - serverNow()
        if after > 0 then
            para:Set(("หมุนแล้ว%s · ครั้งถัดไปอีก %s"):format(lastText(), fmt(after)))
            -- server ตอบว่าปฏิเสธ = ไม่ได้หมุนจริง ไม่แจ้งเว็บ
            local refused = lastResult ~= nil and lastResult ~= "หมุนแล้ว"
            if not refused and Addon.emit then Addon.emit("spin", "Daily Spin" .. (lastText():gsub("^ · ล่าสุด:", " ได้"))) end
        else
            para:Set(lastResult or "ยิงหมุนแล้วแต่ยังไม่เห็นผล จะลองใหม่ในไม่กี่วินาที")
        end
    end

    startDailySpin, stopDailySpin = makeLoop(pass, function() return 10 end)
    spinSection:AddToggle("DailySpin", {
        Text = "Automatically Daily Spin",
        Default = false,
        Callback = function(on)
            if on then
                para:Set("กำลังเช็ค...")
                startDailySpin()
            else
                stopDailySpin()
                para:Set("ปิดอยู่")
            end
        end,
    })
end

----------------------------------------------------------------
-- AUTO TUTORIAL (แท็บ Miner > Tutorial) = กด node เอง (tap)
--   กด ClickDetector ของ node ใน plot เรา (workspace.MineWorld.Plots.MinePlot<n>.Nodes)
--   รอบละ 1 ครั้ง ทุก Tap Interval วิ (ปิด toggle = หยุดทันที) ต้องมี fireclickdetector ของ executor
--
--   เลือกก้อน: เฉพาะที่ยังไม่แตก (NodeHP > 0 และ NodeBroken ไม่ใช่ true) เอาก้อนที่ HP เหลือน้อยสุดก่อน
--     (ปิดก้อนที่ miner ตีค้างไว้ให้แตกเลย ได้แร่เร็วขึ้น miner ไปก้อนอื่นต่อ)
--   node ไม่มี attribute NodeHP เลย -> วนกดทุกก้อนแบบเดิม
--
--   ที่มา (วัดด้วย tools/tapcheck.lua zone 11 miner 8 ตัว ช่วงละ 6 วิ):
--     ไม่กด: โดนตี 18 ครั้ง แตก 9 ก้อน / กดทุก 0.2 วิ: โดนตี 28 ครั้ง แตก 12 ก้อน
--     กด 23 ครั้ง นับได้ ~10 ครั้ง = server รับราว 1.7 ครั้ง/วิ -> ค่าเริ่มต้น 0.3 วิ
--     แบบเดิม (วนทุกก้อนรวมก้อนที่แตกแล้ว ก้อนละ 1 วิ) กดทิ้งเปล่าเกือบครึ่ง
----------------------------------------------------------------
local stopAutoTutorial
do
    local tutorialSection = MinerTab:AddSection("Tap")
    local TutorialNoteKey = nil
    local TapTurn = 0  -- ลำดับวนกด (ใช้ตอน node ไม่มีข้อมูล HP)
    local function tutorialNote(key, text, kind)
        if key == TutorialNoteKey then return end
        TutorialNoteKey = key
        Velvet:Notify({ Title = "Auto Tap", Content = text, Duration = 4, Type = kind or "info" })
    end

    local function tutorialPass(alive)
        if type(fireclickdetector) ~= "function" then
            return tutorialNote("nofire", "executor นี้ไม่มี fireclickdetector", "error")
        end
        local plot = getMyPlot()
        local nodes = plot and plot:FindFirstChild("Nodes")
        if not nodes then
            return tutorialNote("nonodes", "หา Nodes ใน plot ของคุณไม่เจอ", "error")
        end
        -- หา node ที่กดได้: live = ยังไม่แตก (เรียงหา HP น้อยสุด), unknown = ไม่มีข้อมูล HP
        local best, bestHp = nil, math.huge
        local unknown, total = {}, 0
        for _, n in ipairs(nodes:GetChildren()) do
            local detector = n:FindFirstChildWhichIsA("ClickDetector", true)
            if detector then
                total += 1
                local hp = tonumber(n:GetAttribute("NodeHP"))
                if hp == nil then
                    table.insert(unknown, detector)
                elseif hp > 0 and n:GetAttribute("NodeBroken") ~= true and hp < bestHp then
                    best, bestHp = detector, hp
                end
            end
        end
        if total == 0 then
            return tutorialNote("empty", "ยังไม่มี node ให้กดใน plot ของคุณ")
        end
        if not best and #unknown > 0 then
            TapTurn = TapTurn % #unknown + 1  -- ไม่มีข้อมูล HP: วนทีละก้อน
            best = unknown[TapTurn]
        end
        if not best then return nil end  -- ทุกก้อนแตกอยู่ รอเกิดใหม่ (ไม่แจ้งเตือน)
        if not alive() then return nil end
        -- Tween to Rock: ไกลเกินระยะกดของ ClickDetector -> tween ไปยืนบนหินก่อน (Addon.tweenTo แบบเดียวกับไปขาย)
        --   ระบบขาย / Smart Equip กำลังเดินทาง = ไม่ขยับ กดจากที่เดิม ; จอง lock เดียวกัน (Addon.sellBusy) ระหว่าง tween
        if Velvet.Flags["TapTween"] ~= false and Addon.tweenTo then
            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            local node = best.Parent
            while node and node.Parent ~= nodes do node = node.Parent end
            local okP, cf, size = pcall(function()
                if node:IsA("Model") then
                    local c, s = node:GetBoundingBox()
                    return c, s
                end
                return node.CFrame, node.Size
            end)
            local reach = math.max(6, (tonumber(best.MaxActivationDistance) or 32) - 6)
            if hrp and okP and cf and (hrp.Position - cf.Position).Magnitude > reach
                and os.clock() - (Addon.sellBusy or -1e9) >= 10 and os.clock() - (Addon.equipBusy or -1e9) >= 60 then
                Addon.sellBusy = os.clock()
                pcall(Addon.tweenTo, hrp, CFrame.new(cf.Position + Vector3.new(0, size.Y / 2 + 1, 0)))
                Addon.sellBusy = nil
                if not alive() then return nil end
            end
        end
        pcall(fireclickdetector, best, 0, "MouseClick")
        tutorialNote("run", "กำลังกด node (เฉพาะก้อนที่ยังไม่แตก HP น้อยสุดก่อน)", "success")
        return nil
    end

    local startAutoTutorial
    startAutoTutorial, stopAutoTutorial = makeLoop(tutorialPass, function()
        return math.max(0.1, flag("TapInterval", 0.3))
    end)

    tutorialSection:AddToggle("AutoTutorial", {
        Text = "Auto Tap",
        Default = false,
        Callback = function(on)
            if on then
                TutorialNoteKey = nil
                startAutoTutorial()
            else
                stopAutoTutorial()
            end
        end,
    })

    tutorialSection:AddSlider("TapInterval", {
        Text = "Tap Interval",
        Min = 0.1, Max = 2, Default = 0.3, Increment = 0.05,
        Suffix = "s",
        VisibleWhen = "AutoTutorial",
    })

    tutorialSection:AddToggle("TapTween", {
        Text = "Tween to Rock",
        Default = true,
        VisibleWhen = "AutoTutorial",
    })
end

----------------------------------------------------------------
-- SELL
----------------------------------------------------------------
local SELL_POS = CFrame.new(-6000.615234375, 503.82452392578125, -5999.41552734375)

local function getHRP()
    local char = LP.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local OreNames = {}
for _, ore in ipairs(MineCatalog.Ores or {}) do
    if ore.ItemName then
        table.insert(OreNames, ore.ItemName)
    end
end
-- แร่ของแต่ละ zone (MineConfig.Zones[Zx].Ores) เผื่อแร่ใหม่ที่ catalog ยังไม่มี
pcall(function()
    local cfg = require(RS:WaitForChild("Modules"):WaitForChild("MineConfig"))
    for _, z in pairs(type(cfg.Zones) == "table" and cfg.Zones or {}) do
        for _, o in ipairs(type(z) == "table" and type(z.Ores) == "table" and z.Ores or {}) do
            local n = type(o) == "table" and o.Name or nil
            if type(n) == "string" and not table.find(OreNames, n) then table.insert(OreNames, n) end
        end
    end
end)
table.sort(OreNames)

local SelectOre = {}

local function GetSelectOres()
    local result = {}
    for k, v in pairs(SelectOre) do
        if v == true then
            table.insert(result, k)      -- { Name = true } format
        elseif type(v) == "string" then
            table.insert(result, v)      -- { "Name", ... } format
        end
    end
    return result
end

-- เดินทางไปจุดขาย -> fn() -> กลับจุดเดิม  (ใช้ร่วมกัน: Auto Sell Ores / Auto Sell Characters)
--   เดินทางด้วย TweenService (Addon.tweenTo) แทนวาปทันที (วาปที่ FPS ต่ำไม่เสถียร)
--   อีกอันเดินทางอยู่ = รอให้เสร็จก่อน ไม่ซ้อนกัน (lock ไม่ได้ต่อเวลาเกิน 10 วิ = ถือว่าว่าง) ; คืน true = ได้ไปขายจริง
--   Smart Equip กำลังจัดทีม (Addon.equipBusy) = รอจนจัดเสร็จทั้งรอบ (ค้างเกิน 60 วิ = ถือว่าว่าง)
Addon.atSeller = function(fn, alive)
    local hrp = getHRP()
    if not hrp then return false end
    while os.clock() - (Addon.sellBusy or -1e9) < 10 or os.clock() - (Addon.equipBusy or -1e9) < 60 do
        if alive and not alive() then return false end
        task.wait(0.2)
    end
    Addon.sellBusy = os.clock()  -- ตั้งทันทีหลังเช็ค (ไม่มี yield คั่น = ไม่ชนกับ Smart Equip)
    local oldPos = hrp.CFrame
    local arrived = Addon.tweenTo(hrp, SELL_POS)
    if arrived then
        task.wait(0.3)  -- ให้ server เห็นว่าอยู่ที่จุดขายก่อนยิงขาย
        pcall(fn)
        task.wait(1)
    end
    Addon.sellBusy = os.clock()
    if hrp.Parent then Addon.tweenTo(hrp, oldPos) end
    pcall(Addon.backTo, hrp, oldPos)  -- กันตก / โดนดึงไปที่อื่นหลังถึง (วาปซ้ำเฉพาะตอนหลุดจากจุดเดิม)
    Addon.sellBusy = nil
    return arrived
end

-- เลื่อนตัวไปที่ target ด้วย TweenService (ความเร็ว = slider "Sell Tween Speed" studs/วิ)
--   tween ตัว CFrameValue แล้วทุกเฟรมก่อน physics (PreSimulation) วางตัวตามค่านั้น + ความเร็ว 0
--     -> ไม่โดนแรงโน้มถ่วงดึงตกระหว่างทาง ; ปิดการชนตัวละครชั่วคราว (ผ่านกำแพง/ของกลางทาง)
--   PlatformStand = Humanoid ไม่แย่งคุมตัว (ไม่เดิน/ไม่ตก) ; จบแล้วคืนค่าเดิมทั้งหมด
--   ขอให้ stream ปลายทางก่อนออกเดินทาง (พื้นจุดหมายโหลดทันตอนถึง)
--   ยกจุดหมายสูงขึ้น 2-3 studs (TweenLift) ตัวละครชอบจมพื้นตอนวางตรงความสูงเดิม
Addon.tweenTo = function(hrp, target)
    local char = hrp.Parent
    if not char then return false end
    -- จุดหมายยกสูงจากเดิม (slider "Tween Height" ค่าเริ่มต้น 2.5 studs) กันตัวจมพื้น -> ถึงแล้วค่อยตกลงพื้นเอง
    local lift = tonumber(Velvet.Flags["TweenLift"]) or 2.5
    target = target + Vector3.new(0, math.clamp(lift, 0, 10), 0)
    local Run = game:GetService("RunService")
    local dist = (hrp.Position - target.Position).Magnitude
    local dur = math.clamp(dist / flag("SellTweenSpeed", 250), 0.25, 60)
    pcall(function() LP:RequestStreamAroundAsync(target.Position, 2) end)
    local hum = char:FindFirstChildOfClass("Humanoid")
    local platform = hum and hum.PlatformStand
    local collide = {}
    local cv = Instance.new("CFrameValue")
    cv.Value = hrp.CFrame
    local function place()
        if not hrp.Parent then return end
        hrp.CFrame = cv.Value
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
    local conns = {}
    local ok = pcall(function()
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then collide[p] = true; p.CanCollide = false end
        end
        if hum then hum.PlatformStand = true end
        conns[1] = Run.PreSimulation:Connect(place)
        conns[2] = Run.Heartbeat:Connect(place)  -- หลัง physics อีกรอบ = ภาพไม่สั่นตอน FPS ต่ำ
        local tw = game:GetService("TweenService"):Create(cv, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = target })
        tw:Play()
        while tw.PlaybackState == Enum.PlaybackState.Playing and hrp.Parent do
            if Addon.sellBusy then Addon.sellBusy = os.clock() end  -- กำลังเดินทาง = อีกระบบอย่าเพิ่งเริ่ม
            task.wait()
        end
        if not hrp.Parent then tw:Cancel() end
        place()
    end)
    for _, c in ipairs(conns) do c:Disconnect() end
    cv:Destroy()
    for p in pairs(collide) do if p.Parent then p.CanCollide = true end end
    if hum and hum.Parent then hum.PlatformStand = platform end
    return ok and hrp.Parent ~= nil and (hrp.Position - target.Position).Magnitude < 8 + lift
end

-- กลับจุดเดิมให้ชัวร์ (FPS ต่ำ เช่น 15 เคยไม่กลับ / กลับแล้วโดนดึงไปจุดขายอีก)
--   1. ขอให้ stream พื้นรอบจุดเดิมก่อน (จุดขายอยู่กลาง hub พื้นแถว plot อาจถูก stream ออกไปแล้ว)
--      = LocalPlayer:RequestStreamAroundAsync แบบเดียวกับที่เกมใช้ก่อนย้ายตัวใน cutscene
--   2. วาปกลับ แล้ว anchor ตัวไว้จนพื้นใต้จุดเดิมโหลด (raycast เจอ) -> ไม่ตกทะลุพื้น
--   3. ต้องอยู่ใกล้จุดเดิมต่อเนื่อง 2 วิ ถึงถือว่าเสร็จ ระหว่างนั้นโดนดึงไปที่อื่น = วาปกลับซ้ำ (สูงสุด 15 วิ)
Addon.backTo = function(hrp, oldPos)
    pcall(function() LP:RequestStreamAroundAsync(oldPos.Position, 5) end)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { LP.Character }
    local wasAnchored = hrp.Anchored
    local t0, stableSince = os.clock(), nil
    local ok = pcall(function()
        while os.clock() - t0 < 15 and hrp.Parent do
            if Addon.sellBusy then Addon.sellBusy = os.clock() end  -- ยังวาปกลับอยู่ = อีกระบบอย่าเพิ่งวาป
            if (hrp.Position - oldPos.Position).Magnitude > 6 then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.CFrame = oldPos + Vector3.new(0, 2.5, 0)  -- สูงกว่าเดิมนิดหน่อย กันจมพื้น
                stableSince = nil
            end
            -- พื้นยังไม่มา = ค้างตัวไว้ก่อน (หาไม่เจอเกิน 5 วิ เช่น ยืนกลางอากาศตอนกระโดด = ปล่อย)
            local floor = workspace:Raycast(oldPos.Position + Vector3.new(0, 2, 0), Vector3.new(0, -50, 0), rp)
            local floorOk = floor ~= nil or os.clock() - t0 > 5
            hrp.Anchored = wasAnchored or not floorOk
            if floorOk and (hrp.Position - oldPos.Position).Magnitude <= 6 then
                stableSince = stableSince or os.clock()
                if os.clock() - stableSince >= 2 then break end
            end
            task.wait(0.1)
        end
    end)
    if hrp.Parent then hrp.Anchored = wasAnchored end
    return ok and hrp.Parent ~= nil and (hrp.Position - oldPos.Position).Magnitude <= 6
end

-- แร่ทุกอย่างที่อยู่ในกระเป๋าตอนนี้ (อ่านจากข้อมูลเกม -> แร่ใหม่ที่เกมเพิ่มทีหลัง เช่น Clown Glass ก็ขายได้)
--   MineInventory.Collect(MineGame, "All") เอาเฉพาะ Kind = Ore / Junk ที่มีราคาขาย (Key = ชื่อที่ร้านใช้ขาย)
Addon.bagOres = function()
    local mg = Addon.mineGame and Addon.mineGame()
    if type(mg) ~= "table" then return nil end
    local ok, list = isolated(function()
        local inv = require(RS:WaitForChild("Modules"):WaitForChild("MineInventory"))
        local out = {}
        for _, e in ipairs(inv.Collect(mg, "All") or {}) do
            if type(e) == "table" and (e.Kind == "Ore" or e.Kind == "Junk") and type(e.Key) == "string"
                and (tonumber(e.SellCount or e.Count) or 0) > 0 and (tonumber(e.Worth) or 0) > 0 then
                table.insert(out, e.Key)
            end
        end
        return out
    end)
    return ok and type(list) == "table" and list or nil
end

local function sellOres()
    local list = GetSelectOres()
    if #list == 0 then
        -- ไม่ได้เลือก = ขายทุกแร่ที่มีในกระเป๋า (อ่านข้อมูลเกมไม่ได้ = ใช้รายชื่อแร่ตอนโหลด)
        list = Addon.bagOres() or OreNames
        if #list == 0 then return end  -- กระเป๋าไม่มีแร่ ไม่ต้องเดินทาง
    end
    Addon.atSeller(function() fire("MineSellItems", list) end)
end

-- รอระหว่างรอบขาย (คงที่ ไม่มี slider แล้ว) ขายทุก 1 นาที
local SELL_WAIT = 60
local startAutoSell, stopAutoSell = makeLoop(
    sellOres,
    function() return SELL_WAIT end
)

sellSection:AddToggle("AutoSellOres", {
    Text = "Auto Sell Ores",
    Default = false,
    Callback = function(on)
        if on then startAutoSell() else stopAutoSell() end
    end
})

sellSection:AddDropdown("OreName", {
    Text = "Select Ores",
    Values = OreNames,
    Default = {},
    Multi = true,
    VisibleWhen = "AutoSellOres",
})
-- ใช้ OnFlagChanged แทน Callback: Load Config เรียกแค่ :Set ซึ่งไม่เรียก Callback ของ dropdown
Velvet:OnFlagChanged("OreName", function(value)
    SelectOre = value or {}
end)
-- ความเร็วเดินทางไปจุดขาย/กลับ (TweenService) ใช้ร่วมกับ Auto Sell Characters
sellSection:AddSlider("SellTweenSpeed", {
    Text = "Sell Tween Speed",
    Min = 50, Max = 1000, Default = 250, Increment = 10,
    Suffix = " studs/s",
})
-- จุดหมาย tween สูงจากพื้นเดิมกี่ studs (กันตัวจมพื้น) ใช้กับขาย + Smart Equip
sellSection:AddSlider("TweenLift", {
    Text = "Tween Height",
    Min = 0, Max = 6, Default = 2.5, Increment = 0.5,
    Suffix = " studs",
})

----------------------------------------------------------------
-- PICKAXE (ปุ่ม Config + หน้าต่างการ์ด + Auto Buy)
-- remote: Event:FireServer("MineBuyPickaxe", index)
--
-- หลักการ:
--   1. ดึง pickaxe ที่ขายใน shop จาก MineConfig.Pickaxes
--      (ชื่อ, ราคา Cost, พลังขุด Multiplier, zone ที่ต้องปลดล็อค, Stock)
--      + รูปจากตาราง PICKAXE_IMAGES (ImageId จาก catalog ของเกม)
--   2. กดปุ่ม "Pickaxe Shop Config" -> เปิดหน้าต่างการ์ด
--      - กดการ์ด = เลือก จะมีเลขลำดับขึ้นมุมขวาบน (1, 2, 3 ...)
--      - กดการ์ดที่เลือกแล้วซ้ำ = เอาออก (เลขที่เหลือเลื่อนขึ้นมาเอง)
--      - Clear = ล้างที่เลือกทั้งหมด
--   3. Auto Buy ซื้อตามลำดับที่เลือก (เลข 1 ก่อน)
--      เปิด/ปิดได้ 2 ที่: toggle "Auto Buy Pickaxe" ใน End Hub หรือปุ่ม Auto Buy ในหน้าต่างการ์ด
--      (สองอันเชื่อมกัน กดอันไหนอีกอันก็เปลี่ยนตาม)
--      ไม่ได้เลือกเลย = ลองซื้อทุกอัน ไล่จากอันดีสุดลงมา
--      ข้าม (ไม่ยิง): ของหมดรอรีสต็อก / เงินไม่พอ (leaderstats.Cash) / zone ของ pickaxe (ZoneReq) ยังไม่ปลดล็อค
--      zone: เช็คจาก MineGame.UnlockedZones (ไม่มีข้อมูล -> ดู zone ของ plot / ยังไม่รู้ = ยิงให้ server ตัดสิน)
--   4. ลำดับที่เลือกเซฟลงไฟล์ EndHubData/pickaxe_buy.json (รันใหม่ก็ยังอยู่)
--
-- หมายเหตุ: อ่านแค่ "ตารางข้อมูล" ใน MineConfig ห้ามเรียกฟังก์ชันของเกม
--           (เคยทำให้ thread เสียสิทธิ์ แล้ว UI พัง)
----------------------------------------------------------------
local MineConfig = require(RS:WaitForChild("Modules"):WaitForChild("MineConfig"))
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")

----------------------------------------------------------------
-- KAITUN (ไก่ตัน) ส่วนที่ 1: config + ตัวคุมงบ
--   ตั้ง _G.Kaitun = { Enabled = true, ... } ก่อนรัน loader -> ฟาร์มเองจนถึงเป้าหมาย
--   (ตัวอย่าง + คำอธิบายทุกช่อง: Scripting/animeminerng/kaitun_example.lua)
--
-- กลยุทธ์ (เกมบังคับ: research ของ zone ต้องครบก่อน ถึงปลดล็อค zone ถัดไปได้ -> คอขวดคือ research):
--   1. รายได้ไม่หยุด: equip best / chest / spin / sell / tap เปิดตลอด
--   2. research เรียงตามความคุ้ม: ซื้อ node ที่ "ราคา / น้ำหนักของสาย" ต่ำสุด (สายเพิ่มรายได้ก่อน)
--   3. งบตามสัดส่วนเงิน: ซื้อได้เมื่อ ราคา <= Budget[หมวด] x เงินตอนนี้
--      (research เต็ม 1.0 / miner 0.3 ... -> ลูปอื่นไม่แย่งเงิน research)
--   4. research ที่เหลือติด MinePower -> งบ miner เป็น 1.0 จนผ่าน
--   5. research ครบ -> ทุกการซื้อต้องเหลือเงิน >= ค่าปลดล็อค zone ถัดไป (reserve)
--
-- ส่วนนี้มีแค่ config + Kaitun.allow ให้ลูปซื้อทุกอันถามก่อนยิง
-- ตัวสั่งเปิด toggle / เช็คเป้าหมาย / UI อยู่ท้ายไฟล์ (KAITUN ส่วนที่ 2)
-- ไม่ได้เปิด Kaitun -> allow คืน true เสมอ = ทุกอย่างทำงานแบบเดิม
----------------------------------------------------------------
local Kaitun: { [string]: any } = {
    on = false,         -- โหมด Kaitun ทำงานอยู่ไหม
    reserve = 0,        -- เงินที่ต้องเหลือไว้ (ค่าปลดล็อค zone ถัดไป ตอน research ครบ)
    needPower = false,  -- research ที่เหลือติด MinePower -> เทงบให้ miner
    maxZone = nil,      -- เลข zone เป้าหมาย (ไม่ปลดล็อคเกินนี้) ตั้งตอนเปิด Kaitun
    lifetime = nil,     -- คีย์ถาวรไหม: nil = ยังไม่ได้ตรวจ / true / false (Kaitun ใช้ได้เฉพาะคีย์ถาวร)
    cfg = nil,          -- config (ค่าเริ่มต้น + ของผู้ใช้)
    fromUser = false,   -- มี _G.Kaitun / ไฟล์ที่จำไว้ ไหม
    file = "EndHub/kaitun.json",
    -- แท็บ Kaitun (สร้างตรงนี้ จะได้อยู่หลัง Research ก่อน Settings) ของข้างในใส่ท้ายไฟล์
    tab = Window.EndHubKaitunTab,
}
-- อยู่ในฟังก์ชัน (ไม่ใช่ do): local ข้างในไม่นับรวมกับ local ระดับบนสุดของไฟล์ (จำกัด 200 ตอน -O0)
Kaitun.init = function()
    local DEFAULTS = {
        Enabled = false,
        -- ถึง zone นี้ (+ research ของ zone นี้ครบ) = จบ / "max" = zone สุดท้ายของเกม (นับจาก MineConfig.ZoneKeys)
        Goal = { Zone = "max", Research = true },
        OnGoal = "keep",    -- "keep" = ฟาร์มต่อ / "stop" = ปิดทุกอย่าง
        Persist = false,    -- true = จำ config ลงไฟล์ ใช้ต่อหลัง rejoin / auto execute
        Budget = { Research = 1, Slots = 1, Pickaxe = 0.6, Miner = 0.3, Tap = 0.05 },
        -- ใช้เงินฉลาด: ของถูกมาก (<= CheapShare ของเงิน) ซื้อเลยไม่ดูงบหมวด
        --   กำลังเก็บเงินปลดล็อค zone: อีก <= SaveSeconds วิจะครบ = หยุดซื้ออย่างอื่น
        --   ยังอีกนาน = ลงทุน miner/pickaxe/slot ได้ ถ้าราคา <= InvestShare ของเงินที่ยังขาด (ช้าลงไม่เกิน ~5%)
        Spend = { CheapShare = 0.02, SaveSeconds = 180, InvestShare = 0.05 },
        -- น้ำหนักของสาย research (มาก = ซื้อก่อน) ประมาณจากคำอธิบายสกิล ไม่ได้จำลองรายได้จริง
        SkillWeights = {
            NodeCount = 3, OreYield = 3, Force = 2.5, Refine = 2.5,
            NodeHealth = 2, Tempo = 2, Windfall = 2, Assay = 2, NodeLevel = 2,
            Regrowth = 1.5, Prospect = 1.5, Crit = 1.5, Awaken = 1.5, Lode = 1.5,
            Luck = 1, Unearth = 1, BigNode = 1,
            Slayer = 0.7, Bounty = 0.7, Vault = 0.5, Hammer = 0.5,
        },
        -- LevelCap: อัป miner ถึง level นี้แล้วหยุด (0 = อัปจนเต็ม ค่าเริ่มต้น) ใช้กับ Damage / Speed / Mining Speed
        Miner = { Types = { "Damage", "MineSpeed", "Speed" }, FocusStrongest = false, LevelCap = 0 },
        -- Smart Equip: ZoneFirst = ตัวจาก zone ลึกสุดที่เปิดแล้วได้ใส่ก่อน / zone เท่ากัน = พลัง base (ไม่นับเลเวล)
        --   false = ดาเมจจริงมากสุดก่อน (นับเลเวล + variant)
        Equip = { ZoneFirst = true },
        -- LevelCap: อัป tap ถึง level นี้แล้วหยุด (0 = อัปจนเต็ม)
        Tap = { Enabled = true, Upgrade = true, LevelCap = 0 },
        -- ดื่ม potion เอง (Gem Shop > Auto Use Potion) ตอน boost ของ family นั้นหมด ใช้ขวดแรงสุดที่มีก่อน
        --   Use = family ของ potion แบบมีเวลา (ไม่รวม MutLuck = ตอนสุ่ม mutation, Rally = ตอนตีบอส)
        Potion = {
            Enabled = true,
            Use = { "Strength", "Haste", "OreLuck", "Unearth", "Prospect", "Crit", "Regrowth", "Sell", "ChestCap", "TapFury", "CharLuck" },
        },
        -- สุ่ม mutation เอง (Miner > Mutation > Auto Mutation) ใช้งบหมวด Miner
        --   All = true: ทุกตัวบน pad (รวมตัวที่ Smart Equip ใส่ทีหลัง) / false = ตัวที่เลือกไว้ใน Mutation Config
        --   Target = variant ขั้นต่ำ สุ่มจนได้ตัวนี้ขึ้นไป: Bronze < Diamond < Platinum < Rainbow < Frozen < Inferno < Nightmare < Unreal
        Mutation = { Enabled = true, All = true, Target = "Bronze" },
        AntiAfk = true,
        BlockIdleRejoin = true, -- ลบ IdleRejoin ของเกม (Settings > General > Block Idle Rejoin) ไม่โดน rejoin ตอนยืน AFK
        FpsCap = false,     -- ตัวเลข เช่น 15 = จำกัด fps ลดภาระเครื่อง
        Disable3D = false,  -- true = ปิดการเรนเดอร์ 3D (จอไม่วาดเกม ประหยัดเครื่อง)
        FpsBoost = false,   -- true = เปิด FPS Boost ถาวร (ซ่อน plot / ผู้เล่นคนอื่น)
        AntiLag = false,    -- true = เปิด Anti Lag ถาวร (กราฟิกต่ำสุด ปิดเงา ปิด particle)
    }

    -- รวม config ผู้ใช้เข้ากับค่าเริ่มต้น (ช่องที่ไม่ใส่ / ใส่ผิดชนิด = ค่าเริ่มต้น)
    --   ตารางแบบรายการ (เช่น Miner.Types) = ใช้ของผู้ใช้ทั้งก้อน
    local function merge(def, user)
        local out = {}
        for k, v in pairs(def) do
            local u = type(user) == "table" and user[k] or nil
            if type(v) == "table" then
                if type(u) ~= "table" then
                    out[k] = merge(v, nil)
                elseif #v > 0 then
                    out[k] = table.clone(u)
                else
                    out[k] = merge(v, u)
                end
            elseif u ~= nil and (type(u) == type(v) or k == "FpsCap" or k == "Zone") then
                out[k] = u
            else
                out[k] = v
            end
        end
        -- key ที่ไม่มีในค่าเริ่มต้น (เช่น SkillWeights ของสายใหม่) เก็บไว้ด้วย
        for k, u in pairs(type(user) == "table" and user or {}) do
            if out[k] == nil and type(u) ~= "table" then out[k] = u end
        end
        return out
    end

    -- config จากผู้ใช้: _G.Kaitun -> getgenv().Kaitun -> ไฟล์ที่จำไว้ (Persist)
    --   _G ก่อน: autoexec ตั้งใหม่ทุกครั้งที่เข้าเกม ส่วน getgenv บาง executor จำข้ามเกม (ค่าเก่าค้าง)
    --   ข้าม config ของ Anime Crusaders (มี EvolveFarm / StoryHard / ChallengeFarm) ที่ชื่อ Kaitun เหมือนกัน
    --     ACX รุ่นเก่าเขียน getgenv().Kaitun ไว้ -> เข้าเกมนี้ต่อในเครื่องเดิม Kaitun ไม่เปิด
    local raw = nil
    pcall(function()
        local function mine(t)
            if type(t) ~= "table" then return nil end
            if t.Goal == nil and t.Budget == nil and t.Miner == nil
                and (t.EvolveFarm ~= nil or t.StoryHard ~= nil or t.ChallengeFarm ~= nil) then
                return nil
            end
            return t
        end
        local env = type(getgenv) == "function" and getgenv() or nil
        raw = mine(_G.Kaitun) or (type(env) == "table" and mine(env.Kaitun)) or nil
    end)
    if raw == nil then
        pcall(function()
            if isfile(Kaitun.file) then
                local data = HttpService:JSONDecode(readfile(Kaitun.file))
                if type(data) == "table" then
                    raw = data
                    -- จำไว้แค่ตอน hop (ไม่ได้ Persist) -> ใช้รอบนี้รอบเดียว
                    if data._hop == true and data.Persist ~= true then delfile(Kaitun.file) end
                    data._hop = nil
                end
            end
        end)
    elseif raw.Enabled == false then
        -- ตั้ง Enabled = false มาเอง = เลิกจำ
        pcall(function() if isfile(Kaitun.file) then delfile(Kaitun.file) end end)
    end
    Kaitun.fromUser = raw ~= nil
    Kaitun.cfg = merge(DEFAULTS, raw)

    -- ลูปซื้อถามก่อนยิง: หมวด "Research" / "Slots" / "Pickaxe" / "Miner" / "Tap"
    --   ไม่รู้ราคา / อ่านเงินไม่ได้ = true (ให้ server ตัดสินเอง เหมือนตอนไม่เปิด Kaitun)
    function Kaitun.allow(category, cost)
        if not Kaitun.on then return true end
        cost = tonumber(cost)
        local cash = getCash()
        if not cost or not cash then return true end
        local sp = Kaitun.cfg.Spend
        local frac = tonumber(Kaitun.cfg.Budget[category]) or 1
        if category == "Miner" and Kaitun.needPower then frac = 1 end
        if cost > cash then return false end
        local reserve = Kaitun.reserve or 0
        if reserve > 0 and cash - cost < reserve then
            -- ซื้อแล้วเงินต่ำกว่าค่าปลดล็อค zone
            local gap = reserve - cash
            local inc = tonumber(Kaitun.income) or 0
            local eta = (inc > 0 and gap > 0) and gap / inc or math.huge
            if gap > 0 and eta <= (tonumber(sp.SaveSeconds) or 180) then return false end  -- ใกล้ครบ: เก็บเงิน
            if category == "Tap" or category == "Research" then return false end
            -- ยังอีกนาน: ลงทุนที่เพิ่มรายได้ได้ ถ้าไม่ทำให้ช้าลงมาก
            return cost <= math.max(gap, 0) * (tonumber(sp.InvestShare) or 0.05) and cost <= cash * frac
        end
        if cost <= cash * (tonumber(sp.CheapShare) or 0.02) then return true end  -- ของถูกมาก
        return cost <= cash * frac
    end
end
Kaitun.init()

-------------------- 1) ข้อมูล pickaxe --------------------

-- รูป pickaxe (ImageId จาก catalog ของเกม) จับคู่ด้วยชื่อ
--   MineConfig ไม่มีรูป เลยต้องเก็บไว้ตรงนี้เอง
--   ใส่ไว้ครบทุกอัน เผื่อ shop เพิ่มของใหม่ในอนาคตจะมีรูปขึ้นเลย
--   ชื่อไหนไม่มีในนี้ -> การ์ดจะโชว์ตัวเลขพลังขุดตัวใหญ่แทนรูป
local PICKAXE_IMAGES = {
    ["Wooden Pickaxe"]          = "85933090485952",
    ["Stone Pickaxe"]           = "109067821154736",
    ["Iron Pickaxe"]            = "133241920635021",
    ["Gold Pickaxe"]            = "100315806652739",
    ["Quartz Pickaxe"]          = "97778206808640",
    ["Sapphire Pickaxe"]        = "78158476876167",
    ["Sapphire Quartz Pickaxe"] = "120273474276187",
    ["Tidehook Pickaxe"]        = "110980329940024",
    ["Emerald Pickaxe"]         = "99917727732573",
    ["Ruby Pickaxe"]            = "115574415148495",
    ["Sunstone Pickaxe"]        = "73003592414256",
    ["Riftcleaver Pickaxe"]     = "92764597805227",
    ["Starfall Pickaxe"]        = "90088226304317",
    ["Topaz Pickaxe"]           = "112437954797959",
    ["Dawnwing Pickaxe"]        = "97331678241603",
    ["Chrysoberyl Pickaxe"]     = "107195810077854",
    ["Sunwheel Pickaxe"]        = "140062769278345",
    ["Zircon Pickaxe"]          = "98636554531736",
    ["Thundercoil Pickaxe"]     = "93290566854963",
    ["Rhodolite Pickaxe"]       = "126433064984840",
    ["Heartpiercer Pickaxe"]    = "125385811252167",
    ["Anvilheart Pickaxe"]      = "111606744401225",
    ["Soulflare Pickaxe"]       = "135747905815168",
    ["Lanternfang Pickaxe"]     = "87432776460051",
    ["Gloomwing Pickaxe"]       = "96954753258482",
    ["Koifin Pickaxe"]          = "104601043120639",
    ["Foxfire Pickaxe"]         = "102750276680434",
    ["Dragonrise Pickaxe"]      = "89281654733117",
    ["Anchorfluke Pickaxe"]     = "83576691326449",
    ["Nightcross Pickaxe"]      = "84763230105379",
    ["Krakenmaw Pickaxe"]       = "81675160514254",
}

-- pickaxe ที่ขายใน shop (มีตาราง Stock และไม่ใช่ Robux) ตามลำดับในเกม (ถูก -> แพง)
--   index = เลขที่ใช้ยิง remote (ตำแหน่งใน MineConfig.Pickaxes)
local ShopList = {}
local ShopByName = {}  -- [ชื่อเต็ม] = ข้อมูล pickaxe
for index, p in ipairs(MineConfig.Pickaxes or {}) do
    if p.Name and not p.RobuxOnly and type(p.Stock) == "table" then
        local item = {
            name = p.Name,
            title = (p.Name:gsub("%s*Pickaxe$", "")),  -- "Stone Pickaxe" -> "Stone" ไว้โชว์บนการ์ด
            index = index,
            cost = tonumber(p.Cost) or 0,
            mult = tonumber(p.Multiplier) or 0,
            zone = tostring(p.ZoneReq or "-"),
            stock = p.Stock,
            image = PICKAXE_IMAGES[p.Name],  -- nil = ไม่มีรูป
        }
        table.insert(ShopList, item)
        ShopByName[p.Name] = item
    end
end

-- ใช้ตอนไม่ได้เลือกอะไรเลย: ทุกอัน เรียงจาก Multiplier มาก -> น้อย (ดีสุดก่อน)
local BestFirst = table.clone(ShopList)
table.sort(BestFirst, function(a, b) return a.mult > b.mult end)

-------------------- 2) ลำดับที่เลือก + เซฟ/โหลด --------------------

local CONFIG_FOLDER = "EndHubData"
local CONFIG_FILE = CONFIG_FOLDER .. "/pickaxe_buy.json"

-- PickOrder = ชื่อที่เลือก เรียงตามลำดับที่กด
--   เช่น { "Riftcleaver Pickaxe", "Sunstone Pickaxe" } -> Riftcleaver คือเลข 1
local PickOrder = {}
local PickRefresh = nil  -- วาดเลขบนการ์ดใหม่ (มีตอนเปิดหน้าต่าง Pickaxe Shop อยู่)

-- เซฟลง pickaxe_buy.json + ใส่ไว้ใน Velvet.Flags ด้วย (Save Config ของ End Hub จะเซฟลำดับนี้ไปด้วย)
local function saveConfig()
    Velvet.Flags["PickaxeOrder"] = table.clone(PickOrder)
    pcall(function()
        if not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
        writefile(CONFIG_FILE, HttpService:JSONEncode({ order = PickOrder }))
    end)
end

local function loadConfig()
    pcall(function()
        if not isfile(CONFIG_FILE) then return end
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(data) ~= "table" or type(data.order) ~= "table" then return end
        local seen = {}
        for _, name in ipairs(data.order) do
            -- เก็บเฉพาะชื่อที่ยังขายใน shop และไม่ซ้ำ
            if ShopByName[name] and not seen[name] then
                seen[name] = true
                table.insert(PickOrder, name)
            end
        end
    end)
end
loadConfig()
Velvet.Flags["PickaxeOrder"] = table.clone(PickOrder)

-- เลขลำดับของ pickaxe นี้ (ยังไม่ได้เลือก = nil)
local function pickNumber(name)
    for i, n in ipairs(PickOrder) do
        if n == name then
            return i
        end
    end
    return nil
end

-- กดการ์ด: ยังไม่เลือก -> ต่อท้ายคิว / เลือกแล้ว -> เอาออก
local function togglePick(name)
    local i = pickNumber(name)
    if i then
        table.remove(PickOrder, i)
    else
        table.insert(PickOrder, name)
    end
    saveConfig()
end

-- Load Config / Profile แล้ว Velvet.Flags.PickaxeOrder เปลี่ยน -> เอามาใช้เป็น PickOrder
--   (SaveManager แค่ใส่ค่าลง Flags ไม่ได้บอกเรา เลยเช็คเองก่อนซื้อทุกรอบ + หลังโหลด config)
local function syncPickOrder()
    local f = Velvet.Flags["PickaxeOrder"]
    if type(f) ~= "table" then return end
    local same = #f == #PickOrder
    for i, n in ipairs(PickOrder) do
        if f[i] ~= n then same = false; break end
    end
    if same then return end
    table.clear(PickOrder)
    local seen = {}
    for _, name in ipairs(f) do
        if type(name) == "string" and ShopByName[name] and not seen[name] then
            seen[name] = true
            table.insert(PickOrder, name)
        end
    end
    saveConfig()
    if PickRefresh then pcall(PickRefresh) end
end

-- หลัง Load Config / Load Profile / Import สำเร็จ -> ใช้ลำดับ pickaxe จาก config ทันที
do
    for _, m in ipairs({ "Load", "LoadProfile", "Import" }) do
        local orig = SaveManager[m]
        if type(orig) == "function" then
            SaveManager[m] = function(self, ...)
                local ok, err = orig(self, ...)
                if ok then pcall(syncPickOrder) end
                return ok, err
            end
        end
    end
end

-------------------- 3) การซื้อ --------------------

-- รายการที่จะยิงซื้อรอบนี้
local function getBuyTargets()
    syncPickOrder()
    if #PickOrder == 0 then
        return BestFirst  -- ไม่ได้เลือก = ลองทุกอัน ดีสุดก่อน
    end
    local targets = {}
    for _, name in ipairs(PickOrder) do
        table.insert(targets, ShopByName[name])
    end
    return targets
end

-------------------- ของหมด (sold out) --------------------
-- ยิงซื้อของที่หมด เกมจะเด้งข้อความ "X Pickaxe is sold out - the shop restocks in 2:56." ทุกครั้ง
--   1. อ่านข้อความนั้น -> จำว่า pickaxe นี้หมดถึงเมื่อไหร่ แล้วไม่ยิงซื้อจนกว่าจะรีสต็อก
--   2. ซ่อนข้อความ sold out ของเกมทิ้ง (ข้อความอื่นของเกมยังขึ้นปกติ)
local SoldOutUntil = {}  -- [ชื่อ pickaxe] = os.clock() ที่รีสต็อก

-- คืน true ถ้าเป็นข้อความ sold out (และจำเวลารีสต็อกไว้)
local function readSoldOut(text)
    if type(text) ~= "string" or not text:find("sold out", 1, true) then return false end
    local plain = text:gsub("<[^>]+>", "")  -- ตัด RichText tag
    local name = plain:match("^%s*(.-)%s+is sold out")
    local m, s = plain:match("restocks in (%d+):(%d+)")
    if name and ShopByName[name] then
        local secs = (tonumber(m) or 1) * 60 + (tonumber(s) or 0)
        SoldOutUntil[name] = os.clock() + secs + 1
    end
    return true
end

-- ดักข้อความใน PlayerGui: เป็น sold out -> ซ่อน
pcall(function()
    local pg = LP:WaitForChild("PlayerGui")
    -- hooked: กันต่อ connection ซ้ำกับ label เดิม (ย้าย parent = DescendantAdded ยิงซ้ำ)
    --   weak key: label ที่ถูกลบไปแล้วไม่ค้างในตาราง
    local hooked = setmetatable({}, { __mode = "k" })
    local function hookLabel(obj)
        if hooked[obj] or not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
        hooked[obj] = true
        local function check()
            if readSoldOut(obj.Text) then
                obj.Visible = false
                -- ซ่อนกรอบของข้อความด้วย (แถบพื้นหลังดำ) ถ้ากรอบมีแค่ข้อความนี้
                local parent = obj.Parent
                if parent and parent:IsA("GuiObject") and #parent:GetChildren() <= 3 then
                    parent.Visible = false
                end
            end
        end
        check()
        hooked[obj] = obj:GetPropertyChangedSignal("Text"):Connect(check)
    end
    for _, d in ipairs(pg:GetDescendants()) do hookLabel(d) end
    local addConn = pg.DescendantAdded:Connect(function(d) task.defer(hookLabel, d) end)
    -- ปิด End Hub (กด X / รันตัวใหม่ทับ): เลิกดักทั้งหมด ไม่ให้ตัวเก่าค้างในแรม
    Velvet:OnDestroy(function()
        addConn:Disconnect()
        for _, c in pairs(hooked) do
            if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
        end
        table.clear(hooked)
    end)
end)

-- zone นี้ปลดล็อคแล้วไหม: true / false / nil (ยังไม่รู้)
--   ตัวจริงกำหนดในก้อน Research (ต้องใช้ getMineGame ที่อยู่ข้างใน)
local isZoneUnlocked = nil
-- เลข zone ลึกสุดที่ปลดล็อคแล้ว จาก MineGame.UnlockedZones เท่านั้น (ไม่มีข้อมูล = nil)
local deepestUnlockedZoneNum = nil

-------------------- Auto Select Next Zone --------------------
-- เปิดไว้ + Auto Buy ทำงาน: ปลดล็อค zone ใหม่เมื่อไหร่
--   -> เอา pickaxe ของ zone เดิมออกจากที่เลือก แล้วเลือก pickaxe ของ zone ใหม่แทน (ดีสุดก่อน)
--   zone ใหม่ไม่มี pickaxe ขายใน shop -> ไม่เปลี่ยนอะไร (ยังซื้อของเดิมต่อ)
--   รันใหม่ / เปิด toggle ใหม่ = เริ่มนับจาก zone ตอนนั้น (ไม่สลับย้อนหลัง)
local followNewZone, setFollowZone
do
    local FollowZone = true   -- ตรงกับ Default ของ toggle
    local LastDeepest = nil   -- zone ลึกสุดตอนเช็คครั้งก่อน

    setFollowZone = function(on)
        FollowZone = on == true
        LastDeepest = nil
    end

    followNewZone = function()
        if not FollowZone or not deepestUnlockedZoneNum then return end
        local ok, d = pcall(deepestUnlockedZoneNum)
        if not ok or not d then return end

        -- โหมด "Current Zone Only" (ค่าเริ่มต้นเปิด): ที่เลือกในหน้าต่างการ์ด = pickaxe ของ zone ปัจจุบันอย่างเดียว
        --   ทำตอนเริ่ม + ทุกครั้งที่ zone เปลี่ยน / zone ปัจจุบันไม่มีของขาย = ใช้ zone ล่าสุดที่มีของขาย (ไม่ลบจนว่าง)
        if Velvet.Flags["PickaxeCurrentOnly"] ~= false then
            if d == LastDeepest then return end
            LastDeepest = d
            local zoneNum, newPicks = d, {}
            while zoneNum >= 1 do
                for _, p in ipairs(BestFirst) do
                    if p.zone == "Z" .. zoneNum then table.insert(newPicks, p.name) end
                end
                if #newPicks > 0 then break end
                zoneNum -= 1
            end
            if #newPicks == 0 then return end
            local same = #PickOrder == #newPicks
            if same then
                for i, name in ipairs(newPicks) do
                    if PickOrder[i] ~= name then same = false; break end
                end
            end
            if same then return end  -- เลือกถูกอยู่แล้ว
            table.clear(PickOrder)
            for _, name in ipairs(newPicks) do table.insert(PickOrder, name) end
            saveConfig()
            if PickRefresh then pcall(PickRefresh) end
            Velvet:Notify({
                Title = "Auto Buy Pickaxe",
                Content = ("ซื้อเฉพาะ pickaxe ของ Z%d (%d อัน) เอาของ zone อื่นออกจากที่เลือกแล้ว"):format(zoneNum, #newPicks),
                Duration = 5, Type = "success",
            })
            return
        end

        if LastDeepest == nil then LastDeepest = d; return end  -- ครั้งแรก = จำไว้เฉยๆ
        if d <= LastDeepest then return end
        local old = LastDeepest
        local newZone = "Z" .. d
        local newPicks = {}
        for _, p in ipairs(BestFirst) do
            if p.zone == newZone then table.insert(newPicks, p.name) end
        end
        if #newPicks == 0 then return end  -- zone ใหม่ไม่มีของขาย -> รอ zone ถัดไป (LastDeepest ไม่ขยับ)
        LastDeepest = d
        -- zone เดิม = old ถึง d-1 (เผื่อปลดล็อคข้ามหลาย zone)
        local keep, seen = {}, {}
        for _, name in ipairs(newPicks) do seen[name] = true end
        for _, name in ipairs(PickOrder) do
            local item = ShopByName[name]
            local n = item and tonumber(item.zone:match("^Z(%d+)$"))
            local fromOldZone = n and n >= old and n < d
            if not fromOldZone and not seen[name] then
                seen[name] = true
                table.insert(keep, name)
            end
        end
        table.clear(PickOrder)
        for _, name in ipairs(newPicks) do table.insert(PickOrder, name) end
        for _, name in ipairs(keep) do table.insert(PickOrder, name) end
        saveConfig()
        if PickRefresh then pcall(PickRefresh) end
        Velvet:Notify({
            Title = "Auto Buy Pickaxe",
            Content = ("ปลดล็อค %s แล้ว -> เปลี่ยนไปซื้อ pickaxe ของ %s (%d อัน)"):format(newZone, newZone, #newPicks),
            Duration = 5, Type = "success",
        })
    end
end

-- ซื้อ 1 รอบ
-- alive มาจาก makeLoop: ถ้าปิด toggle กลางทางจะหยุดยิงทันที
--   ข้ามอันที่รู้ว่าหมดอยู่ (รอรีสต็อก) / zone ยังไม่ปลดล็อค / เงินไม่พอ
local function buyPickaxePass(alive)
    pcall(followNewZone)  -- ปลดล็อค zone ใหม่ -> สลับ pickaxe ที่เลือกไป zone ใหม่ก่อน
    for _, p in ipairs(getBuyTargets()) do
        if alive and not alive() then
            return
        end
        if (SoldOutUntil[p.name] or 0) > os.clock() then continue end
        -- zone ที่ต้องใช้ยังไม่ปลดล็อค -> ข้าม (ยังไม่รู้ = ยิงให้ server ตัดสินเอง)
        if isZoneUnlocked then
            local okZ, unlocked = pcall(isZoneUnlocked, p.zone)
            if okZ and unlocked == false then continue end
        end
        -- เงินไม่พอ (leaderstats.Cash) -> ข้าม ไม่ยิงเปล่า
        local cash = getCash()
        if cash and cash < p.cost then continue end
        -- Kaitun: เกินงบหมวด Pickaxe / ต้องเก็บเงินปลดล็อค zone -> ข้าม
        if not Kaitun.allow("Pickaxe", p.cost) then continue end
        fire("MineBuyPickaxe", p.index)
        task.wait(0.15)  -- เว้นนิดนึง กันยิง remote รัวเกิน
    end
end

local startAutoBuy, stopAutoBuy = makeLoop(
    buyPickaxePass,
    function() return flag("BuyPickaxeInterval", 3) end
)

-------------------- 4) หน้าต่าง GUI (การ์ด) --------------------

-- ย่อเลขยาวๆ ให้อ่านง่าย เช่น 2350 -> "2.35K", 7.38e32 -> "739No" (ตัวย่อ = SUFFIX ด้านบนของไฟล์)
local function short(n)
    n = tonumber(n) or 0
    local i = 0
    while n >= 999.5 and i < #SUFFIX - 1 do
        n = n / 1000
        i += 1
    end
    return ("%.3g"):format(n) .. SUFFIX[i + 1]
end

-- ข้อความ Stock เช่น "3-5 (75%)" = รีสต็อกทีละ 3-5 อัน โอกาสมีของ 75%
local function stockText(p)
    local mn = tonumber(p.stock.Min) or 1
    local mx = tonumber(p.stock.Max) or mn
    local range = (mn == mx) and tostring(mn) or (mn .. "-" .. mx)
    return ("%s (%d%%)"):format(range, math.floor(tonumber(p.stock.Chance) or 100))
end

-- สี (โทนมืด minimal)
local C = {
    bg     = Color3.fromRGB(14, 14, 17),
    card   = Color3.fromRGB(21, 21, 25),
    hover  = Color3.fromRGB(31, 31, 37),
    nav    = Color3.fromRGB(30, 30, 35),
    stroke = Color3.fromRGB(70, 70, 78),
    line   = Color3.fromRGB(34, 34, 40),
    text   = Color3.fromRGB(240, 240, 245),
    sub    = Color3.fromRGB(150, 150, 160),
    dim    = Color3.fromRGB(100, 100, 110),
    accent = Color3.fromRGB(255, 196, 80),   -- สีพลังขุด
    picked = Color3.fromRGB(255, 255, 255),  -- ขอบ + วงเลขของการ์ดที่เลือก
    close  = Color3.fromRGB(220, 60, 60),    -- ปุ่มปิด (แดง)
    closeHover = Color3.fromRGB(245, 85, 85),-- ปุ่มปิดตอนเอาเมาส์ชี้ (แดงสว่างขึ้น)
}

-- ตัวช่วยสร้าง Instance
local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do
        obj[k] = v
    end
    obj.Parent = parent
    return obj
end

local function round(obj, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, obj)
end

local function outline(obj)
    return make("UIStroke", { Color = C.stroke, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, obj)
end

local function label(parent, text, props)
    local l = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
    for k, v in pairs(props or {}) do
        l[k] = v
    end
    return l
end

local function button(parent, text, props)
    local b = make("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = C.card,
        Text = text,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = C.text,
    }, parent)
    round(b, 8)
    outline(b)
    for k, v in pairs(props or {}) do
        b[k] = v
    end
    return b
end

-------------------- สถานะ Auto Buy (ใช้ร่วมกัน toggle + ปุ่มในหน้าต่าง) --------------------

local AutoBuyOn = false      -- ตอนนี้เปิด Auto Buy อยู่ไหม
local AutoBuyToggle = nil    -- toggle "Auto Buy Pickaxe" ใน End Hub (ได้ค่าตอนสร้างในข้อ 5)
local AutoBuyBtn = nil       -- ปุ่ม Auto Buy ในหน้าต่างการ์ด (มีหลังเปิดหน้าต่างครั้งแรก)

-- ทำให้ปุ่มในหน้าต่างตรงกับสถานะ: เปิด = ปุ่มขาว "Auto Buy: ON" / ปิด = ปุ่มมืด "Auto Buy: OFF"
local function updateAutoBuyBtn()
    if not AutoBuyBtn then return end
    AutoBuyBtn.Text = AutoBuyOn and "Auto Buy: ON" or "Auto Buy: OFF"
    AutoBuyBtn.BackgroundColor3 = AutoBuyOn and C.picked or C.card
    AutoBuyBtn.TextColor3 = AutoBuyOn and C.bg or C.text
end

-- เปิด/ปิดลูปซื้อจริงๆ (toggle ใน End Hub เรียกอันนี้ตอนถูกกด)
local function applyAutoBuy(on)
    AutoBuyOn = on == true
    if AutoBuyOn then startAutoBuy() else stopAutoBuy() end
    updateAutoBuyBtn()
end

-- กดปุ่มในหน้าต่าง: สั่ง toggle ใน End Hub ให้เปลี่ยนตาม แล้วเปิด/ปิดลูป
local function setAutoBuy(on)
    local elem = AutoBuyToggle
    if not (type(elem) == "table" and elem.Set) then
        elem = Velvet._elements and Velvet._elements["AutoBuyPickaxe"]  -- หาสำรองแบบเดียวกับปุ่ม Stop All
    end
    if type(elem) == "table" and elem.Set then
        pcall(function() elem:Set(on) end)
    end
    -- เรียกซ้ำกันพลาด เผื่อ Set ไม่ได้เรียก Callback ให้ (start/stop กดซ้ำได้ ไม่ซ้อนกัน)
    applyAutoBuy(on)
end

local GUI_NAME = "EndHub_PickaxeShop"
local W, H = 700, 480          -- ขนาดหน้าต่าง
local SIDE_W = 170             -- ความกว้างแถบซ้าย
local CARD_W, CARD_H = 116, 150
local GAP = 8
local PickaxeGui = nil         -- ScreenGui (สร้างตอนกดเปิดครั้งแรก)

-- หาที่วาง GUI: gethui (executor) -> CoreGui (ถ้าวางไม่ได้จะไป PlayerGui)
local function getGuiParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and typeof(hui) == "Instance" then
        return hui
    end
    return game:GetService("CoreGui")
end

local function buildGui()
    local parent = getGuiParent()
    -- รันสคริปต์ซ้ำ ลบหน้าต่างเก่าทิ้งก่อน
    pcall(function()
        local old = parent:FindFirstChild(GUI_NAME)
        if old then
            old:Destroy()
        end
    end)

    local gui = make("ScreenGui", {
        Name = GUI_NAME,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        -- เลขสูงสุด ให้อยู่บนสุด (ไม่งั้นโดนหน้าต่าง End Hub บังจนมองไม่เห็น)
        DisplayOrder = 2147483647,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, nil)
    if not pcall(function() gui.Parent = parent end) then
        gui.Parent = LP:WaitForChild("PlayerGui")
    end

    -- กรอบหลัก (กลางจอ)
    local win = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(W, H),
        BackgroundColor3 = C.bg,
        Active = true,  -- กันคลิกทะลุไปโดนเกมข้างหลัง
    }, gui)
    round(win, 12)
    outline(win)

    -- ย่อหน้าต่างให้พอดีจอ (เผื่อเล่นบนมือถือ)
    local scale = make("UIScale", {}, win)
    local cam = workspace.CurrentCamera
    local function fit()
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        scale.Scale = math.clamp(math.min((vp.X - 24) / W, (vp.Y - 24) / H), 0.5, 1)
    end
    fit()
    local conns = {}  -- connection ที่ผูกนอกหน้าต่าง (ต้องตัดทิ้งเองตอนหน้าต่างโดนลบ)
    if cam then
        table.insert(conns, cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit))
    end

    ---------- แถบซ้าย ----------
    -- ตรงชื่อหน้าต่าง = ที่จับลากย้ายหน้าต่าง
    local dragArea = make("Frame", {
        Size = UDim2.fromOffset(SIDE_W - 40, 64),
        BackgroundTransparency = 1,
    }, win)
    -- โลโก้บล็อกหิน (ตัวเดียวกับหัวหน้าต่าง End Hub)
    makeLogo(win, 24, 2).Position = UDim2.fromOffset(16, 20)
    label(win, "End Hub", {
        Position = UDim2.fromOffset(48, 16),
        Size = UDim2.fromOffset(SIDE_W - 90, 22),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
    })
    label(win, "Pickaxe config", {
        Position = UDim2.fromOffset(48, 38),
        Size = UDim2.fromOffset(SIDE_W - 60, 16),
        TextSize = 12,
        TextColor3 = C.sub,
    })
    -- ปุ่มปิด: พื้นแดง ตัว X สีขาว ให้มองเห็นชัด
    local closeBtn = make("TextButton", {
        Position = UDim2.fromOffset(SIDE_W - 38, 15),
        Size = UDim2.fromOffset(24, 24),
        AutoButtonColor = false,
        BackgroundColor3 = C.close,
        Text = "X",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = C.picked,
    }, win)
    round(closeBtn, 6)
    -- เอาเมาส์ชี้ = แดงสว่างขึ้น
    closeBtn.MouseEnter:Connect(function() closeBtn.BackgroundColor3 = C.closeHover end)
    closeBtn.MouseLeave:Connect(function() closeBtn.BackgroundColor3 = C.close end)

    -- เมนู (ตอนนี้มีหน้าเดียวคือ Shop)
    local nav = make("Frame", {
        Position = UDim2.fromOffset(10, 76),
        Size = UDim2.fromOffset(SIDE_W - 20, 32),
        BackgroundColor3 = C.nav,
    }, win)
    round(nav, 8)
    label(nav, "Shop", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -12, 1, 0),
        Font = Enum.Font.GothamBold,
    })

    -- บอกว่าเลือกไปกี่อัน (มุมซ้ายล่าง)
    local pickedLabel = label(win, "", {
        Position = UDim2.new(0, 18, 1, -34),
        Size = UDim2.fromOffset(SIDE_W - 30, 18),
        TextSize = 12,
        TextColor3 = C.sub,
    })

    -- เส้นแบ่งซ้าย/ขวา
    make("Frame", {
        Position = UDim2.fromOffset(SIDE_W, 12),
        Size = UDim2.new(0, 1, 1, -24),
        BackgroundColor3 = C.line,
        BorderSizePixel = 0,
    }, win)

    ---------- ด้านขวา ----------
    local X0 = SIDE_W + 14

    -- คำอธิบายด้านบน
    label(win, "Buys in the picked order (1 first). Nothing picked = tries every pickaxe, best first", {
        Position = UDim2.fromOffset(X0, 14),
        Size = UDim2.new(1, -(X0 + 216), 0, 34),
        TextSize = 12,
        TextColor3 = C.sub,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
    })
    -- ปุ่ม Auto Buy (เชื่อมกับ toggle "Auto Buy Pickaxe" ใน End Hub)
    local autoBuyBtn = button(win, "Auto Buy: OFF", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 16),
        Size = UDim2.fromOffset(110, 30),
    })
    local clearBtn = button(win, "Clear", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -132, 0, 16),
        Size = UDim2.fromOffset(70, 30),
    })

    -- ตารางการ์ด (เลื่อนขึ้นลงได้)
    local grid = make("ScrollingFrame", {
        Position = UDim2.fromOffset(X0 - 2, 60),
        Size = UDim2.new(1, -(X0 - 2) - 10, 1, -72),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = C.stroke,
    }, win)
    make("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }, grid)
    make("UIGridLayout", {
        CellSize = UDim2.fromOffset(CARD_W, CARD_H),
        CellPadding = UDim2.fromOffset(GAP, GAP),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)

    -- การ์ดของแต่ละ pickaxe
    local cards = {}  -- [ชื่อ] = { stroke, badge, badgeText }
    local refresh     -- ประกาศไว้ก่อน ให้การ์ดเรียกใช้ได้

    for i, p in ipairs(ShopList) do
        local card = make("TextButton", {
            LayoutOrder = i,
            AutoButtonColor = false,
            Text = "",
            BackgroundColor3 = C.card,
        }, grid)
        round(card, 10)
        local cardStroke = outline(card)

        -- zone ที่ต้องปลดล็อค (มุมซ้ายบน)
        label(card, p.zone, {
            Position = UDim2.fromOffset(9, 7),
            Size = UDim2.fromOffset(40, 14),
            TextSize = 11,
            TextColor3 = C.dim,
            Font = Enum.Font.GothamMedium,
        })

        -- วงกลมเลขลำดับ (มุมขวาบน โชว์เฉพาะอันที่เลือก)
        local badge = make("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -6, 0, 6),
            Size = UDim2.fromOffset(20, 20),
            BackgroundColor3 = C.picked,
            Visible = false,
        }, card)
        round(badge, 10)
        local badgeText = label(badge, "", {
            Size = UDim2.fromScale(1, 1),
            TextXAlignment = Enum.TextXAlignment.Center,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = C.bg,
        })

        -- รูป pickaxe ตรงกลางบน (56x56)
        --   ไม่มีรูปในตาราง PICKAXE_IMAGES -> โชว์พลังขุดตัวใหญ่แทน
        if p.image then
            make("ImageLabel", {
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new(0.5, 0, 0, 22),
                Size = UDim2.fromOffset(56, 56),
                BackgroundTransparency = 1,
                Image = "rbxassetid://" .. p.image,
                ScaleType = Enum.ScaleType.Fit,
            }, card)
        else
            label(card, "x" .. short(p.mult), {
                Position = UDim2.new(0, 6, 0, 36),
                Size = UDim2.new(1, -12, 0, 28),
                TextXAlignment = Enum.TextXAlignment.Center,
                Font = Enum.Font.GothamBold,
                TextSize = 22,
                TextColor3 = C.accent,
            })
        end

        -- ชื่อ (ยาวเกินจะย่อตัวหนังสือลงเอง)
        local nameLabel = label(card, p.title, {
            Position = UDim2.new(0, 6, 0, 84),
            Size = UDim2.new(1, -12, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Center,
            Font = Enum.Font.GothamBold,
            TextScaled = true,
        })
        make("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 9 }, nameLabel)

        -- บรรทัดเดียวกัน: พลังขุด (ซ้าย สีเหลือง) | ราคา (ขวา สีเทา)
        label(card, "x" .. short(p.mult), {
            Position = UDim2.new(0, 9, 0, 104),
            Size = UDim2.new(0.5, -9, 0, 14),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = C.accent,
        })
        label(card, short(p.cost), {
            Position = UDim2.new(0.5, 0, 0, 104),
            Size = UDim2.new(0.5, -9, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Right,
            TextSize = 12,
            TextColor3 = C.sub,
        })

        -- stock ของ shop
        label(card, "Stock " .. stockText(p), {
            Position = UDim2.new(0, 6, 0, 124),
            Size = UDim2.new(1, -12, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextSize = 11,
            TextColor3 = C.dim,
        })

        -- แผ่นล็อค: zone ของ pickaxe นี้ยังไม่ปลดล็อค -> การ์ดมืด + กดเลือกไม่ได้
        local lock = make("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = C.bg,
            BackgroundTransparency = 0.25,
            Visible = false,
            ZIndex = 5,
        }, card)
        round(lock, 10)
        label(lock, "LOCKED", {
            Position = UDim2.new(0, 6, 0.5, -18),
            Size = UDim2.new(1, -12, 0, 18),
            TextXAlignment = Enum.TextXAlignment.Center,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = C.text,
            ZIndex = 6,
        })
        label(lock, "Unlock " .. p.zone .. " first", {
            Position = UDim2.new(0, 6, 0.5, 2),
            Size = UDim2.new(1, -12, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextSize = 11,
            TextColor3 = C.sub,
            ZIndex = 6,
        })

        -- กดการ์ด = เลือก / เอาออก (การ์ดที่ล็อคอยู่เลือกเพิ่มไม่ได้ แต่ที่เลือกไว้แล้วยังกดเอาออกได้)
        card.MouseButton1Click:Connect(function()
            if cards[p.name].locked and not pickNumber(p.name) then
                Velvet:Notify({ Title = "Pickaxe Shop", Content = ("%s ต้องปลดล็อค %s ก่อน"):format(p.title, p.zone), Duration = 3, Type = "error" })
                return
            end
            togglePick(p.name)
            refresh()
        end)
        card.MouseEnter:Connect(function() card.BackgroundColor3 = C.hover end)
        card.MouseLeave:Connect(function() card.BackgroundColor3 = C.card end)

        cards[p.name] = { stroke = cardStroke, badge = badge, badgeText = badgeText, lock = lock, zone = p.zone, locked = false }
    end

    -- อัปเดตเลขลำดับ + ขอบการ์ด + ตัวนับ ให้ตรงกับ PickOrder + การ์ดที่ zone ยังไม่ปลดล็อค
    refresh = function()
        local zoneOpen = {}  -- [zone] = true / false / nil (ยังไม่รู้ = ไม่ล็อค)
        for name, c in pairs(cards) do
            if zoneOpen[c.zone] == nil and isZoneUnlocked then
                local ok, open = pcall(isZoneUnlocked, c.zone)
                zoneOpen[c.zone] = (ok and open == false) and "locked" or "open"
            end
            c.locked = zoneOpen[c.zone] == "locked"
            c.lock.Visible = c.locked
            local n = pickNumber(name)
            c.badge.Visible = n ~= nil
            c.badgeText.Text = n and tostring(n) or ""
            c.stroke.Color = n and C.picked or C.stroke
            c.stroke.Thickness = n and 1.5 or 1
        end
        if #PickOrder > 0 then
            pickedLabel.Text = ("Picked %d / %d"):format(#PickOrder, #ShopList)
        else
            pickedLabel.Text = "Nothing picked"
        end
    end
    PickRefresh = refresh

    -- ปุ่มต่างๆ
    closeBtn.MouseButton1Click:Connect(function()
        gui.Enabled = false
    end)
    clearBtn.MouseButton1Click:Connect(function()
        table.clear(PickOrder)
        saveConfig()
        refresh()
    end)
    autoBuyBtn.MouseButton1Click:Connect(function()
        setAutoBuy(not AutoBuyOn)  -- เปิดอยู่ -> ปิด / ปิดอยู่ -> เปิด
    end)
    AutoBuyBtn = autoBuyBtn
    updateAutoBuyBtn()  -- เปิดหน้าต่างมา ปุ่มต้องตรงกับสถานะตอนนี้เลย

    -- ลากหน้าต่างด้วยตรงชื่อ (รองรับทั้งเมาส์และนิ้ว)
    local dragging, dragStart, startPos = false, nil, nil
    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, win.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    table.insert(conns, UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            win.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))

    -- หน้าต่างโดนลบ -> ตัด connection ที่ผูกไว้ข้างนอกทิ้ง
    gui.Destroying:Connect(function()
        for _, c in ipairs(conns) do
            c:Disconnect()
        end
        if AutoBuyBtn == autoBuyBtn then
            AutoBuyBtn = nil  -- ปุ่มหายไปแล้ว ไม่ต้องอัปเดตอีก
        end
        if PickRefresh == refresh then PickRefresh = nil end
    end)

    refresh()
    -- เปิดหน้าต่างค้างไว้: เช็ค zone ใหม่ทุก 3 วิ (ปลดล็อค zone แล้วการ์ดปลดล็อคตามเอง)
    task.spawn(function()
        while gui.Parent do
            task.wait(3)
            if gui.Enabled and gui.Parent then pcall(refresh) end
        end
    end)
    -- ไว้เช็คใน console (F9) ว่าหน้าต่างถูกสร้างจริงและไปอยู่ที่ไหน
    print("[End Hub] Pickaxe Shop opened in:", tostring(gui.Parent))
    return gui
end

-- เปิด/ปิดหน้าต่าง (สร้างครั้งแรกตอนกดเปิด)
local function togglePickaxeGui()
    if PickaxeGui and PickaxeGui.Parent then
        PickaxeGui.Enabled = not PickaxeGui.Enabled
        if PickaxeGui.Enabled and PickRefresh then pcall(PickRefresh) end  -- เปิดกลับมา = เช็ค zone ใหม่
        return
    end
    local ok, result = pcall(buildGui)
    if ok then
        PickaxeGui = result
    else
        warn("[End Hub] Pickaxe Shop error:", result)
        Velvet:Notify({ Title = "Pickaxe Shop", Content = "เปิดหน้าต่างไม่ได้: " .. tostring(result), Duration = 6, Type = "error" })
    end
end

-------------------- 5) ปุ่มใน Velvet (แท็บ Pickaxe) --------------------

-- ปุ่มสีเด่น (indigo ของ theme End Hub) ใช้กับปุ่มเปิดหน้าต่าง Config
--   Velvet ไม่มีตัวเลือกสีปุ่ม -> แต่งเองจากปุ่มที่ AddButton คืนมา
--   กดแล้ว Velvet ทำแฟลชแล้วคืนเป็นสีพื้น (เสร็จใน 0.3 วิ) -> ใส่สีเรากลับหลังจากนั้น
local function accentButton(btn)
    if typeof(btn) ~= "Instance" or not btn:IsA("GuiButton") then return btn end
    local color = Color3.fromRGB(79, 70, 229)
    btn.BackgroundColor3 = color
    btn.MouseButton1Click:Connect(function()
        task.delay(0.35, function()
            if btn.Parent then btn.BackgroundColor3 = color end
        end)
    end)
    return btn
end

accentButton(pickaxeSection:AddButton({
    Text = "Pickaxe Shop Config",
    Callback = togglePickaxeGui,
}))

-- เก็บ toggle ไว้ใน AutoBuyToggle ให้ปุ่มในหน้าต่างการ์ดสั่งเปิด/ปิดได้
AutoBuyToggle = pickaxeSection:AddToggle("AutoBuyPickaxe", {
    Text = "Auto Buy Pickaxe",
    Default = false,
    Callback = applyAutoBuy,  -- เปิด/ปิดลูป + อัปเดตปุ่มในหน้าต่างการ์ด
})

pickaxeSection:AddToggle("PickaxeFollowZone", {
    Text = "Auto Select Next Zone",
    Default = true,
    VisibleWhen = "AutoBuyPickaxe",
    Callback = setFollowZone,
})

-- เปิด = ที่เลือกใน Pickaxe Shop Config เหลือ pickaxe ของ zone ปัจจุบันอย่างเดียว (ปลดล็อค zone ใหม่ = ลบของ zone เก่าออก)
--   ปิด = แบบเดิม: เอาออกแค่ zone ก่อนหน้า ของที่เลือกเองข้าม zone ยังอยู่
pickaxeSection:AddToggle("PickaxeCurrentOnly", {
    Text = "Current Zone Only",
    Default = true,
    VisibleWhen = "AutoBuyPickaxe",
    Callback = function() setFollowZone(Velvet.Flags["PickaxeFollowZone"] ~= false) end,
})

pickaxeSection:AddSlider("BuyPickaxeInterval", {
    Text = "Buy Interval",
    Min = 1, Max = 60, Default = 3, Increment = 1,
    Suffix = "s",
    VisibleWhen = "AutoBuyPickaxe",
})

-- ส่วน Research ถึง My Plot อยู่ใน do ... end ก้อนเดียว
--   local ระดับบนสุดของไฟล์ห้ามเกิน 200 ตัว (executor ที่ compile แบบไม่ optimize จะโหลดไม่ขึ้นเลย)
--   ตัวที่ข้างนอกต้องใช้ ประกาศไว้ตรงนี้ ข้างในแค่กำหนดค่า
local StopBuySkill, stopAutoZone, stopPlotUpgrade, PlotGui, stopBuySlot
-- ใช้ข้ามก้อน Research -> Upgrade Plot
local getMineGame, CharDefs, getCharDef
do
----------------------------------------------------------------
-- RESEARCH (Skill Tree ของแต่ละโซน)
-- remote: Event:FireServer("MineBuySkill", zoneKey, family, nodeId)
--   เช่น   Event:FireServer("MineBuySkill", "Z7", "Luck", "Luck3")
--
-- หลักการ (Automatically Buy Skill Tree):
--   1. อ่านข้อมูล player (MineGame.Skills / CurrentZone) ที่เกมส่งมาทาง OnClientEvent
--      zone หาเอง: ZoneKey ของ plot -> CurrentZone -> attribute ของ player -> zone ลึกสุดที่ปลดล็อค
--   2. หา node ที่ซื้อได้: ยังไม่เต็ม + unlock แล้ว + MinePower ถึง + เงินพอ
--      -> เลือกอันที่ถูกที่สุด (ใช้ฟังก์ชันของ MineConfig: IsSkillNodeOpen, GetSkillCost ...)
--   3. ยิง MineBuySkill แล้วรอ level เปลี่ยน (สูงสุด 2 วิ) ค่อยหาอันถัดไป
--      ไม่มีอันที่ซื้อได้ -> รอ 1 วิ แล้วเช็คใหม่
--   ฟังก์ชัน MineConfig ถูกเรียกในลูปของตัวเอง (task.spawn) + pcall ทุกรอบ
----------------------------------------------------------------
local ZoneKeys = {}
local ZoneSet = {}
for _, z in ipairs(MineConfig.ZoneKeys or {}) do
    if type(z) == "string" then
        table.insert(ZoneKeys, z)
        ZoneSet[z] = true
    end
end

-- รายชื่อสาย skill ทั้งหมด โชว์เป็นชื่อเดียวกับบน Skill Tree ในเกม
--   ใช้ชื่อ node ตัดเลขโรมันท้ายออก เช่น "Density III" -> "Density", "Yield I" -> "Yield"
--   (ไม่ใช้ DisplayName ใน MineConfig.Skills เพราะเป็นชื่อคนละแบบ เช่น NodeLevel = "Node level")
--   สายไหนมีหลายชื่อ (คนละ zone ตั้งชื่อต่างกัน) จะต่อกันด้วย " / "
local SkillLabels = {}     -- รายชื่อใน dropdown
local LabelToFamily = {}   -- [ชื่อใน dropdown] = family id
do
    local ROMAN = { I = true, II = true, III = true, IV = true, V = true, VI = true, VII = true,
        VIII = true, IX = true, X = true, XI = true, XII = true, XIII = true, XIV = true, XV = true }
    local function baseName(name)
        local head, tail = tostring(name):match("^(.-)%s+(%S+)$")
        if head and (ROMAN[tail] or tonumber(tail)) then return head end
        return tostring(name)
    end

    local order, names = {}, {}  -- names[family] = { list = {...}, seen = {...} }
    for _, z in ipairs(ZoneKeys) do
        local nodes = (MineConfig.ZoneSkillNodes or {})[z]
        for _, n in ipairs(type(nodes) == "table" and nodes or {}) do
            if type(n) == "table" and n.Family then
                local entry = names[n.Family]
                if not entry then
                    entry = { list = {}, seen = {} }
                    names[n.Family] = entry
                    table.insert(order, n.Family)
                end
                local b = baseName(n.Name or n.Family)
                if not entry.seen[b] then
                    entry.seen[b] = true
                    table.insert(entry.list, b)
                end
            end
        end
    end

    for _, fam in ipairs(order) do
        local text = table.concat(names[fam].list, " / ")
        if LabelToFamily[text] then text = text .. " (" .. fam .. ")" end  -- กันชื่อซ้ำ
        LabelToFamily[text] = fam
        table.insert(SkillLabels, text)
    end
    table.sort(SkillLabels)
end

-- dropdown multi คืนค่าได้ 2 แบบ: { Name = true } หรือ { "Name", ... }
-- คืน set ของ family id + มีเลือกอย่างน้อย 1 อันไหม
local SkillFilter = {}
local function familyFilter()
    local set, any = {}, false
    for k, v in pairs(type(SkillFilter) == "table" and SkillFilter or {}) do
        local picked = (v == true and k) or (type(v) == "string" and v) or nil
        local fam = picked and LabelToFamily[picked]
        if fam then set[fam] = true; any = true end
    end
    return set, any
end

-------------------- ข้อมูล player (MineGame) --------------------
-- state ของเกม (ตารางเดียวกับที่ UI ของเกมใช้):
--   Skills     = { [zone] = { [family] = level } }
--   Holders    = { [pad] = { CharName, CharLevel, CharSpeedLevel, CharMineSpeedLevel, CharVariant, ... } }
--   Characters / Ores / Pickaxes = ของในกระเป๋า,  CurrentZone, UnlockedZones, ...
-- หาได้ 2 ทาง:
--   1. ดักจาก GamestateEvent (OnClientEvent) ตอนเกมส่ง state มา
--   2. สำรอง: ถ้าข้อ 1 ยังไม่เคยได้ state เต็ม -> หาตารางเดียวกันในหน่วยความจำของเกมด้วย getgc
--      (เฉพาะ executor ที่มี getgc / อ่านตารางอย่างเดียว ไม่ได้เรียกฟังก์ชันของเกม)
local LastMineGame = nil
local LastMoney = nil
local MONEY_KEYS = { "Money", "Cash", "Coins", "Gold" }

local function pickMoney(t)
    for _, k in ipairs(MONEY_KEYS) do
        local v = tonumber(t[k])
        if v then return v end
    end
    return nil
end

-- state เต็ม = มี Holders + ช่องอื่นของ state อย่างน้อย 1 อัน
--   (กันข้อมูลบางส่วน และตารางอื่นที่บังเอิญมี key ชื่อ Holders)
local STATE_KEYS = { "Skills", "Characters", "Ores", "Pickaxes" }
local function isFullMineGame(t)
    if type(t) ~= "table" or type(rawget(t, "Holders")) ~= "table" then return false end
    for _, k in ipairs(STATE_KEYS) do
        if type(rawget(t, k)) == "table" then return true end
    end
    return false
end

local function grabState(t, depth)
    if type(t) ~= "table" or depth > 3 then return end
    local mineGame = nil
    if type(t.MineGame) == "table" then
        mineGame = t.MineGame
    elseif type(t.Skills) == "table" and (t.CurrentZone ~= nil or t.UnlockedZones ~= nil) then
        mineGame = t  -- ส่งมาเฉพาะ MineGame
    end
    if mineGame then
        -- ได้ state เต็มแล้ว ไม่ให้ข้อมูลบางส่วนมาทับ
        if isFullMineGame(mineGame) or not isFullMineGame(LastMineGame) then
            LastMineGame = mineGame
        end
        LastMoney = pickMoney(t) or pickMoney(mineGame) or LastMoney
        return
    end
    for _, v in pairs(t) do
        if type(v) == "table" then grabState(v, depth + 1) end
    end
end

pcall(function()
    Event.OnClientEvent:Connect(function(...)
        local args = table.pack(...)
        for i = 1, args.n do
            pcall(grabState, args[i], 0)
        end
    end)
end)

-------------------- สำรอง: หา state ในหน่วยความจำของเกม (getgc) --------------------
-- [pad] = Humanoid.DisplayName ของ miner ที่ยืนบน plot เรา
--   (ไว้เช็คว่าตารางที่เจอเป็นของเราจริง ไม่ใช่ของ player อื่น / ตารางเก่า)
local function plotCrewNames()
    local names = {}
    local plot = getMyPlot()
    local crew = plot and plot:FindFirstChild("Crew")
    for _, m in ipairs(crew and crew:GetChildren() or {}) do
        local pad = m.Name:match("([MH]%d+)$")
        local hum = m:FindFirstChildOfClass("Humanoid")
        if pad and hum then names[pad] = hum.DisplayName end
    end
    return names
end

-- เทียบ state กับ miner บน plot เรา
--   match    = จำนวน pad ที่ชื่อ miner ตรงกัน
--   conflict = จำนวน pad ที่เห็น miner บน plot แต่ใน state ไม่มี / ชื่อไม่ตรง
--   progress = level รวมทั้งหมด (เจอหลายตาราง อันที่มากกว่า = ใหม่กว่า)
local function rateMineGame(mineGame, names)
    local holders = rawget(mineGame, "Holders")
    local match, conflict, progress = 0, 0, 0
    for pad, shown in pairs(names) do
        local h = holders[pad]
        local charName = type(h) == "table" and h.CharName or nil
        if type(charName) == "string" and charName ~= "" and shown:find(charName, 1, true) then
            match += 1
        else
            conflict += 1
        end
    end
    for _, h in pairs(holders) do
        if type(h) == "table" then
            progress += (tonumber(h.CharLevel) or 0)
                + (tonumber(h.CharSpeedLevel) or 0)
                + (tonumber(h.CharMineSpeedLevel) or 0)
        end
    end
    local skills = rawget(mineGame, "Skills")
    for _, zone in pairs(type(skills) == "table" and skills or {}) do
        if type(zone) == "table" then
            for _, lv in pairs(zone) do
                progress += tonumber(lv) or 0
            end
        end
    end
    return match, conflict, progress
end

-- สแกนหา state: เลือกอันที่ miner ตรงกับ plot เรามากสุด (เท่ากัน = อันที่ level รวมมากกว่า)
-- คืน state, conflict ของอันที่เลือก
local function scanGcForMineGame()
    if type(getgc) ~= "function" then return nil end
    local ok, objects = pcall(getgc, true)
    if not ok or type(objects) ~= "table" then return nil end
    local names = plotCrewNames()
    local best, bestMatch, bestProgress, bestConflict = nil, -1, -1, 0
    for _, obj in pairs(objects) do
        if isFullMineGame(obj) then
            local okRate, match, conflict, progress = pcall(rateMineGame, obj, names)
            if okRate and (match > bestMatch or (match == bestMatch and progress > bestProgress)) then
                best, bestMatch, bestProgress, bestConflict = obj, match, progress, conflict
            end
        end
    end
    return best, bestConflict
end

local GcMineGame = nil
local GcConflict = 0           -- conflict ตอนสแกนเจอ (มากกว่านี้ทีหลัง = ตารางไม่อัปเดตตามเกมแล้ว)
local GcScanAt = -math.huge    -- เวลาที่สแกนล่าสุด
local GcCheckAt = -math.huge   -- เวลาที่เช็คล่าสุดว่าตารางยังตรงกับ plot
local GcRetry = 15             -- วินาทีก่อนสแกนใหม่ (getgc หนัก: สแกนไม่เจอ -> รอนานขึ้นเรื่อยๆ)

local function findGcMineGame()
    local now = os.clock()
    -- เช็คทุก 5 วิ: เปลี่ยน miner บน plot แล้วตารางไม่เปลี่ยนตาม = ตารางเก่า -> ทิ้ง แล้วสแกนใหม่
    if GcMineGame and now - GcCheckAt > 5 then
        GcCheckAt = now
        local ok, _, conflict = pcall(rateMineGame, GcMineGame, plotCrewNames())
        if not ok or conflict > GcConflict then GcMineGame = nil end
    end
    if GcMineGame == nil and now - GcScanAt > GcRetry then
        GcScanAt = now
        local found, conflict = scanGcForMineGame()
        GcMineGame, GcConflict, GcCheckAt = found, conflict or 0, now
        GcRetry = found and 15 or math.min(GcRetry * 2, 300)
    end
    return GcMineGame
end

-- ข้อมูลตอนนี้มาจากไหน: "event" (ดักจาก remote) / "memory" (getgc) / nil (ยังไม่มี)
local function mineGameSource()
    if isFullMineGame(LastMineGame) then return "event" end
    if GcMineGame then return "memory" end
    return LastMineGame and "event" or nil
end

-- คืน mineGame, money (money ไม่รู้ = nil -> ไม่เช็คเงิน ให้ server ตัดสินเอง)
--   เงินอ่านจาก leaderstats.Cash ก่อนเสมอ (ตรงกับที่เกมโชว์) ไม่มีค่อยใช้ทางสำรองข้างล่าง
function getMineGame()
    local mineGame = LastMineGame
    if not isFullMineGame(mineGame) then
        mineGame = findGcMineGame() or mineGame
    end
    local money = getCash()
    if money == nil then
        money = LastMoney
    end
    if money == nil and mineGame then
        money = pickMoney(mineGame)
    end
    if money == nil then
        for _, k in ipairs(MONEY_KEYS) do
            local v = tonumber(LP:GetAttribute(k))
            if v then money = v; break end
        end
    end
    if money == nil then
        local ls = LP:FindFirstChild("leaderstats")
        if ls then
            for _, k in ipairs(MONEY_KEYS) do
                local v = ls:FindFirstChild(k)
                if v and tonumber(v.Value) then money = tonumber(v.Value); break end
            end
        end
    end
    return mineGame, money
end

-- Auto Buy Pickaxe: zone นี้ปลดล็อคแล้วไหม (ประกาศไว้ก่อนส่วน Pickaxe)
--   1. MineGame.UnlockedZones = { Z1 = true, ... } (แบบเดียวกับ MineConfig.DeepestUnlockedZone ของเกม)
--   2. ไม่มีข้อมูล -> zone ของ plot เรา ลึกกว่าหรือเท่ากัน = ปลดล็อคแน่นอน
--   3. นอกนั้น = nil (ยังไม่รู้)
isZoneUnlocked = function(z)
    local want = tonumber(tostring(z):match("^Z(%d+)$"))
    if not want then return nil end
    local mg = getMineGame()
    local u = mg and mg.UnlockedZones
    if type(u) == "table" and next(u) ~= nil then
        for k, v in pairs(u) do
            local key = (v == true and k) or (type(v) == "string" and v) or (v and k) or nil
            if key ~= nil and tostring(key) == z then return true end
        end
        return false
    end
    local plot = getMyPlot()
    local cur = plot and tonumber(tostring(readValue(plot, "ZoneKey") or ""):match("^Z?(%d+)$"))
    if cur and cur >= want then return true end
    return nil
end

-- Auto Select Next Zone: zone ลึกสุดจาก UnlockedZones เท่านั้น
--   (ไม่ใช้ zone ของ plot แทน: ค่าสำรองอาจต่ำกว่าจริง พอข้อมูลจริงมาจะเหมือนเพิ่งปลดล็อค zone ใหม่)
deepestUnlockedZoneNum = function()
    local mg = getMineGame()
    local u = mg and mg.UnlockedZones
    if type(u) ~= "table" or next(u) == nil then return nil end
    local best = 0
    for k, v in pairs(u) do
        local key = (v == true and k) or (type(v) == "string" and v) or (v and k) or nil
        local n = key ~= nil and tonumber(tostring(key):match("^Z(%d+)$")) or nil
        if n and n > best then best = n end
    end
    return best > 0 and best or nil
end

-------------------- หา zone ปัจจุบันเอง --------------------
-- แปลงค่าเป็น "Z<n>" (รับได้ทั้ง 7, "7", "Z7")
local function toZoneKey(v)
    if v == nil then return nil end
    local s = tostring(v)
    local z = s:match("^Z%d+$") and s or (s:match("^%d+$") and ("Z" .. s)) or nil
    return (z and ZoneSet[z]) and z or nil
end

-- ลำดับที่เช็ค:
--   1. ZoneKey ของ plot เรา (attribute บน MinePlot<n> เช่น "Z7")
--   2. MineGame.CurrentZone (zone ที่อยู่ตอนนี้)
--   3. attribute ของ player (CurrentZone / Zone)
--   4. zone ลึกสุดที่ปลดล็อคแล้ว (MineGame.UnlockedZones)
-- คืนค่า: zone, source (มาจากไหน ไว้ print debug)
local function getCurrentZone(mineGame)
    local plot = getMyPlot()
    local z = plot and toZoneKey(readValue(plot, "ZoneKey"))
    if z then return z, "Plot.ZoneKey (" .. plot.Name .. ")" end
    z = toZoneKey(mineGame and mineGame.CurrentZone)
    if z then return z, "MineGame.CurrentZone" end
    for _, k in ipairs({ "CurrentZone", "Zone", "MineZone" }) do
        z = toZoneKey(LP:GetAttribute(k))
        if z then return z, "Player attribute " .. k end
    end
    local unlocked = mineGame and mineGame.UnlockedZones
    if type(unlocked) == "table" then
        local best = 0
        for k, v in pairs(unlocked) do
            local key = (v == true and k) or v
            local n = tonumber(tostring(key):match("^Z?(%d+)$"))
            if n and n > best and ZoneSet["Z" .. n] then best = n end
        end
        if best > 0 then return "Z" .. best, "UnlockedZones (ลึกสุด)" end
    end
    return nil, "none"
end
Addon.currentZone = getCurrentZone  -- ใช้นอกก้อน do นี้ (Smart Equip)

-- ข้อมูลตัวละคร [ชื่อ] = def (โหลดจาก MineCharacterCatalog ครั้งแรกที่ใช้)
--   ใช้ทั้ง MinePower ของ Skill Tree และ Auto Upgrade Plot / My Plot
CharDefs = nil
function getCharDef(name)
    if CharDefs == nil then
        CharDefs = {}
        pcall(function()
            local mod = RS:WaitForChild("Modules"):FindFirstChild("MineCharacterCatalog")
            local cat = mod and require(mod)
            for _, c in ipairs(type(cat) == "table" and cat.Characters or {}) do
                local key = type(c) == "table" and (c.ItemName or c.Name)  -- catalog ใช้ ItemName
                if key then CharDefs[key] = c end
            end
        end)
    end
    return CharDefs[name]
end

-------------------- หา node ที่ซื้อได้ --------------------
-- สถานะของแต่ละ node:
--   "maxed"  = เต็มแล้ว (หรือ level ถึง max)
--   "locked" = ยังไม่ unlock (parent ยังไม่เต็ม)
--   "power"  = unlock แล้ว แต่ MinePower ยังไม่ถึง
--   "money"  = unlock แล้ว แต่เงินไม่พอ
--   "ok"     = ซื้อได้เลย
-- คืน { { node, cost, state }, ... } ตามลำดับในต้นไม้
local function rateNodes(zone, mineGame, money)
    local skills = (mineGame.Skills or {})[zone] or {}
    -- MinePower: attribute ของ LocalPlayer ก่อน -> leaderstats -> คำนวณเองด้วยสูตรเกม
    --   (MineConfig.GetTeamPower(state, หา def) = ผลรวม damage ของ miner บน plot เรา)
    --   หาไม่ได้เลย = nil -> ไม่เช็ค power ให้ server ตัดสินเอง (เดิมเป็น 0 = ติด power ตลอด)
    local minePower = nil
    for _, k in ipairs({ "MinePower", "TeamPower", "Power" }) do
        minePower = minePower or tonumber(LP:GetAttribute(k))
        local ls = LP:FindFirstChild("leaderstats")
        local v = ls and ls:FindFirstChild(k)
        minePower = minePower or (v and v:IsA("ValueBase") and tonumber(v.Value)) or nil
    end
    if minePower == nil and type(MineConfig.GetTeamPower) == "function" then
        local okP, p = isolated(function() return MineConfig.GetTeamPower(mineGame, getCharDef) end)
        minePower = okP and tonumber(p) or nil
        if minePower == 0 then minePower = nil end  -- 0 = ยังไม่มีข้อมูล miner
    end
    local list = {}
    for _, node in ipairs(MineConfig.GetSkillNodes(zone)) do
        local level = tonumber(skills[node.Family]) or 0
        local entry = { node = node, state = "maxed" }
        if not MineConfig.IsSkillNodeMaxed(skills, node)
            and level < MineConfig.GetSkillMax(zone, node.Family) then
            if not MineConfig.IsSkillNodeOpen(skills, node) then
                entry.state = "locked"
            else
                local req = type(MineConfig.GetSkillPowerReq) == "function"
                    and MineConfig.GetSkillPowerReq(zone, node.Family, level + 1)
                local cost = MineConfig.GetSkillCost(zone, level, node.Family)
                entry.cost = type(cost) == "number" and cost or nil
                -- ไม่รู้ MinePower (nil) = ไม่เช็ค ให้ server ตัดสินเอง
                if req and minePower and (tonumber(req) or math.huge) > minePower then
                    entry.state = "power"
                elseif entry.cost == nil or (money ~= nil and entry.cost > money) then
                    entry.state = "money"
                else
                    entry.state = "ok"
                end
            end
        end
        table.insert(list, entry)
    end
    return list
end

-- เลือกตัวถูกสุดที่ซื้อได้จาก list (ไม่มี -> เหตุผลที่ติด)
--   เหตุผล: มีตัวติดเงิน > ติด power > ล็อคหมด > เต็มหมด
local REASON_RANK = { money = 4, power = 3, locked = 2, maxed = 1 }
local function pickCheapest(list)
    local best, reason = nil, nil
    for _, e in ipairs(list) do
        if e.state == "ok" then
            if not best or e.cost < best.cost then best = e end
        elseif not reason or REASON_RANK[e.state] > REASON_RANK[reason] then
            reason = e.state
        end
    end
    if best then return best.node, best.cost, nil end
    return nil, nil, reason or "maxed"
end

-------------------- Strategy --------------------
-- Cheapest    = ถูกสุดก่อน (สายที่เลือกใน Only These Skills / ว่าง = ทุกสาย)
-- Priority    = ไล่ตามลำดับสายที่กดเลือกใน Only These Skills (กดก่อน = สำคัญกว่า)
--               สายแรกติดเงิน -> รอเงิน ไม่เอาเงินไปลงสายรอง
--               สายแรกเต็ม / ล็อค / power ไม่ถึง -> ข้ามไปสายถัดไป
-- Kaitun      = คุ้มสุดก่อน: ราคา / น้ำหนักของสาย ต่ำสุด (น้ำหนัก = Kaitun.cfg.SkillWeights)
--               ไม่ดู Only These Skills (research ต้องครบทุกสายถึงปลดล็อค zone ถัดไปได้)
local STRATEGIES = { "Cheapest", "Priority", "Kaitun" }
local SkillStrategy = "Cheapest"
local SkillOrder = {}         -- ลำดับสายที่กดเลือก { family, ... }

-- dropdown multi ไม่จำลำดับ -> จำเองตอนกด: อันที่เพิ่งเลือกต่อท้าย อันที่เอาออกลบทิ้ง
--   (โหลด config = ไม่รู้ลำดับกด -> เรียงตามรายชื่อใน dropdown)
local function updateSkillOrder(value)
    local set = {}
    for k, v in pairs(type(value) == "table" and value or {}) do
        local picked = (v == true and k) or (type(v) == "string" and v) or nil
        local fam = picked and LabelToFamily[picked]
        if fam then set[fam] = true end
    end
    local order, seen = {}, {}
    for _, fam in ipairs(SkillOrder) do
        if set[fam] then table.insert(order, fam); seen[fam] = true end
    end
    for _, text in ipairs(SkillLabels) do
        local fam = LabelToFamily[text]
        if set[fam] and not seen[fam] then table.insert(order, fam); seen[fam] = true end
    end
    SkillOrder = order
end

-- ชื่อสายสำหรับแสดงผล (family id -> ชื่อใน dropdown)
local FamilyLabel = {}
for text, fam in pairs(LabelToFamily) do FamilyLabel[fam] = text end

local function pickPriority(list)
    local fams, anyFam = familyFilter()
    if not anyFam then return pickCheapest(list) end
    local reason = nil
    for _, fam in ipairs(SkillOrder) do
        if fams[fam] then
            local mine = {}
            for _, e in ipairs(list) do
                if e.node.Family == fam then table.insert(mine, e) end
            end
            local node, cost, why = pickCheapest(mine)
            if node then return node, cost, nil end
            if why == "money" then return nil, nil, "money" end  -- เก็บเงินไว้ให้สายนี้
            if not reason or REASON_RANK[why] > REASON_RANK[reason] then reason = why end
        end
    end
    return nil, nil, reason or "maxed"
end

-- Kaitun: node ที่ซื้อได้ที่ ราคา / น้ำหนัก ต่ำสุด
--   ไม่มีอันที่ซื้อได้ + ที่เหลือติด MinePower -> บอก Kaitun ให้เทงบไปอัป miner
local function pickWeighted(list)
    local weights = Kaitun.cfg.SkillWeights
    local best, bestScore, reason = nil, math.huge, nil
    for _, e in ipairs(list) do
        if e.state == "ok" then
            local w = math.max(tonumber(weights[e.node.Family]) or 1, 0.01)
            local score = e.cost / w
            if score < bestScore then best, bestScore = e, score end
        elseif not reason or REASON_RANK[e.state] > REASON_RANK[reason] then
            reason = e.state
        end
    end
    Kaitun.needPower = best == nil and reason == "power"
    if best then return best.node, best.cost, nil end
    return nil, nil, reason or "maxed"
end

-- คืน node, cost, เหตุผลที่ไม่มี ("maxed" / "locked" / "power" / "money")
local function findBuyable(zone, mineGame, money)
    local list = rateNodes(zone, mineGame, money)
    -- Strategy "Kaitun" ใช้ได้หลังตรวจแล้วว่าเป็นคีย์ถาวร (ตรวจตอนเปิด Kaitun Mode) ไม่งั้นใช้ Cheapest
    if SkillStrategy == "Kaitun" and Kaitun.lifetime == true then
        return pickWeighted(list)
    end
    Kaitun.needPower = false
    if SkillStrategy == "Priority" then
        return pickPriority(list)
    end
    -- Cheapest: เฉพาะสายที่เลือก (ว่าง = ทุกสาย)
    local fams, anyFam = familyFilter()
    if anyFam then
        local mine = {}
        for _, e in ipairs(list) do
            if fams[e.node.Family] then table.insert(mine, e) end
        end
        list = mine
    end
    return pickCheapest(list)
end

-- รอจน level ของ family นี้เปลี่ยน (หรือหมดเวลา / ปิด toggle)
local function waitForLevelChange(zone, family, oldLevel, timeout, isAlive)
    local t0 = os.clock()
    while os.clock() - t0 < timeout and isAlive() do
        task.wait(0.1)
        local mg = getMineGame()
        if mg then
            local lv = ((mg.Skills or {})[zone] or {})[family] or 0
            if lv ~= oldLevel then return true end
        end
    end
    return false
end

-------------------- แจ้งเตือน (เฉพาะตอนสถานะเปลี่ยน ไม่สแปม) --------------------
local REASON_TEXT = {
    nodata = "รอข้อมูลจากเกม... (ลองขุด/อัปอะไรสักอย่าง 1 ครั้ง)",
    nozone = "หา zone ปัจจุบันไม่เจอ",
    maxed  = "อัปครบทุก node ใน zone นี้แล้ว",
    locked = "node ที่เหลือยังล็อกอยู่",
    power  = "MinePower ยังไม่ถึง",
    money  = "เงินไม่พอ รอเงินก่อน",
}
local lastNotice = nil
local function notice(key, text, kind)
    if key == lastNotice then return end
    lastNotice = key
    Velvet:Notify({ Title = "Auto Skill Tree", Content = text, Duration = 4, Type = kind or "info" })
end

-------------------- ลูป Auto Skill --------------------
local buyGen = 0  -- ใช้แทน boolean กันลูปซ้อน
local SkillBought = 0  -- จำนวนที่ซื้อไปแล้วตั้งแต่เปิด

local function BuySkill()
    buyGen += 1
    local myGen = buyGen
    local function isAlive() return buyGen == myGen end
    local lastZone = nil
    SkillBought = 0
    lastNotice = nil

    while isAlive() do
        local bought = false

        local ok, err = pcall(function()
            local mineGame, money = getMineGame()
            if not mineGame then return notice("nodata", REASON_TEXT.nodata) end
            local zone, zoneSrc = getCurrentZone(mineGame)
            if not zone then return notice("nozone", REASON_TEXT.nozone, "error") end

            if zone ~= lastZone then
                print(("[AnimeMiningRNG] Zone changed: %s -> %s (from %s)"):format(
                    tostring(lastZone), zone, tostring(zoneSrc)))
                lastZone = zone
                lastNotice = nil
                notice("zone" .. zone, ("กำลังอัป Skill Tree ของ %s"):format(zone), "success")
            end

            local node, nodeCost, reason = findBuyable(zone, mineGame, money)
            if not node then
                return notice(zone .. reason, ("%s: %s"):format(zone, REASON_TEXT[reason]))
            end
            -- Kaitun: ซื้อแล้วเงินจะเหลือไม่พอปลดล็อค zone ถัดไป -> รอ
            if not Kaitun.allow("Research", nodeCost) then
                return notice(zone .. "hold", ("%s: Kaitun เก็บเงินไว้ก่อน"):format(zone))
            end

            local oldLevel = ((mineGame.Skills or {})[zone] or {})[node.Family] or 0
            fire("MineBuySkill", zone, node.Family, node.Id)
            bought = true
            SkillBought += 1
            lastNotice = nil  -- ซื้อได้ -> ถ้าติดอีกค่อยแจ้งใหม่
            waitForLevelChange(zone, node.Family, oldLevel, 2, isAlive)
            return nil
        end)

        if not ok then
            warn("[AutoSkill] error:", err)
        end
        if not bought then
            task.wait(1) -- เงินไม่พอ/ครบแล้ว/ยังไม่ได้ข้อมูล รอแล้วเช็กใหม่
        end
    end
end

function StopBuySkill()
    buyGen += 1 -- ทำให้ลูปเก่าทุกตัวหลุด
end

-------------------- UI --------------------
researchSection:AddToggle("Buy_Skill", {
    Text = "Auto Buy Skill Tree",
    Default = false,
    Callback = function(on)
        if on then task.spawn(BuySkill) else StopBuySkill() end
    end,
})

researchSection:AddDropdown("SkillStrategy", {
    Text = "Strategy",
    Values = STRATEGIES,
    Default = "Cheapest",
    Multi = false,
    VisibleWhen = "Buy_Skill",
})
-- ใช้ OnFlagChanged แทน Callback: Load Config เรียกแค่ :Set ซึ่งไม่เรียก Callback ของ dropdown
Velvet:OnFlagChanged("SkillStrategy", function(value)
    SkillStrategy = table.find(STRATEGIES, value) and value or "Cheapest"
    lastNotice = nil
end)

researchSection:AddDropdown("SkillFilter", {
    Text = "Only These Skills",
    Values = SkillLabels,
    Default = {},
    Multi = true,
    VisibleWhen = "Buy_Skill",
})
-- ใช้ OnFlagChanged แทน Callback: Load Config เรียกแค่ :Set ซึ่งไม่เรียก Callback ของ dropdown
Velvet:OnFlagChanged("SkillFilter", function(value)
    SkillFilter = value or {}
    updateSkillOrder(SkillFilter)
end)

-- ปุ่มดูสถานะ: zone, จำนวน node, อันถัดไป, เงิน
researchSection:AddButton({
    Text = "Skill Tree Status",
    Callback = function()
        local ok, msg = pcall(function()
            local mineGame, money = getMineGame()
            if not mineGame then return REASON_TEXT.nodata end
            local zone, zoneSrc = getCurrentZone(mineGame)
            print(("[AnimeMiningRNG] Current zone: %s (from %s) | MineGame.CurrentZone = %s"):format(
                tostring(zone), tostring(zoneSrc), tostring(mineGame.CurrentZone)))
            if not zone then return REASON_TEXT.nozone end
            local skills = (mineGame.Skills or {})[zone] or {}
            local unlocked, locked, maxed = 0, 0, 0
            for _, node in ipairs(MineConfig.GetSkillNodes(zone)) do
                if MineConfig.IsSkillNodeMaxed(skills, node) then maxed += 1
                elseif MineConfig.IsSkillNodeOpen(skills, node) then unlocked += 1
                else locked += 1 end
            end
            local node, cost, reason = findBuyable(zone, mineGame, money)
            local nextText = node
                and ("%s (%s)"):format(tostring(node.Name or node.Id), short(cost))
                or REASON_TEXT[reason]
            local stratText = SkillStrategy
            if SkillStrategy == "Priority" then
                local names = {}
                for _, fam in ipairs(SkillOrder) do table.insert(names, FamilyLabel[fam] or fam) end
                stratText ..= #names > 0 and (": " .. table.concat(names, " > ")) or " (ไม่ได้เลือกสาย = ถูกสุดก่อน)"
            end
            return ("Zone %s · Unlocked %d · Locked %d · Maxed %d\nStrategy: %s\nNext: %s\nMoney: %s · Bought: %d · Data: %s"):format(
                zone, unlocked, locked, maxed, stratText, nextText,
                money and short(money) or "?", SkillBought, mineGameSource() or "none")
        end)
        Velvet:Notify({ Title = "Skill Tree", Content = tostring(msg), Duration = 6, Type = ok and "info" or "error" })
    end,
})

-------------------- Auto Unlock Next Zone --------------------
-- remote: Event:FireServer("MineSelectZone", "Z10")
-- หลักการ:
--   1. หา zone ลึกสุดที่ปลดล็อคแล้ว (MineGame.UnlockedZones) ไม่มีข้อมูล -> ใช้ zone ปัจจุบัน
--   2. zone ถัดไป = ZoneKeys[ลึกสุด + 1] (ไม่มี = ปลดล็อคครบแล้ว)
--   3. research ของ zone ลึกสุดยังไม่ครบ (GetZoneResearchProgress) -> ยังไม่ยิง
--   4. รู้เงิน + เงินน้อยกว่า UnlockCost -> ยังไม่ยิง / นอกนั้นยิง MineSelectZone (server ตัดสินเอง)
--   ทุก 0.1 วิ
local function zoneIndex(z)
    return z and table.find(ZoneKeys, z) or nil
end

local function deepestUnlockedIndex(mineGame)
    local best = 0
    local unlocked = mineGame and mineGame.UnlockedZones
    if type(unlocked) == "table" then
        for k, v in pairs(unlocked) do
            local key = (v == true and k) or v
            local i = zoneIndex(tostring(key))
                or zoneIndex("Z" .. tostring(tostring(key):match("^Z?(%d+)$")))
            if i and i > best then best = i end
        end
    end
    if best == 0 then
        best = zoneIndex((getCurrentZone(mineGame))) or 0
    end
    return best
end

local ZoneNoteKey = nil
local function zoneNote(key, text, kind)
    if key == ZoneNoteKey then return end
    ZoneNoteKey = key
    Velvet:Notify({ Title = "Auto Unlock Zone", Content = text, Duration = 4, Type = kind or "info" })
end

local startAutoZone
startAutoZone, stopAutoZone = makeLoop(function()
    local mineGame, money = getMineGame()
    local cur = deepestUnlockedIndex(mineGame)
    if cur == 0 then return zoneNote("nodata", REASON_TEXT.nodata) end
    local nextZone = ZoneKeys[cur + 1]
    Kaitun.reserve = 0  -- ตั้งใหม่ข้างล่างเฉพาะตอน research ครบแล้วรอเงินปลดล็อค
    if not nextZone then return zoneNote("done", "ปลดล็อคครบทุก zone แล้ว", "success") end
    -- Kaitun: ถึง zone เป้าหมายแล้ว ไม่ปลดล็อคเกิน
    if Kaitun.on and Kaitun.maxZone and cur >= Kaitun.maxZone then
        return zoneNote("goal", ("Kaitun: ถึง zone เป้าหมาย (%s) แล้ว ไม่ปลดล็อคต่อ"):format(ZoneKeys[cur]), "success")
    end
    -- ต้องทำ research ของ zone ก่อนหน้าให้ครบก่อน (เกมบอก "Finish X's research to open Y (0/83)")
    --   เรียกฟังก์ชันเกมใน thread แยก (isolated) กัน thread นี้เสียสิทธิ์
    local gate = ZoneKeys[cur]
    local okProg, done, total = isolated(function()
        return MineConfig.GetZoneResearchProgress(mineGame and mineGame.Skills, gate)
    end)
    done, total = tonumber(done), tonumber(total)
    if not okProg or not done or not total then
        return zoneNote("noresearch", "อ่าน research progress ไม่ได้ (รอข้อมูลจากเกม)", "error")
    end
    if done < total then
        return zoneNote("research" .. gate, ("รอ research %s ให้ครบก่อน (%d/%d) แล้วค่อยปลดล็อค %s"):format(gate, done, total, nextZone))
    end
    local cost = tonumber(((MineConfig.Zones or {})[nextZone] or {}).UnlockCost)
    -- research ครบแล้ว: Kaitun ให้ลูปซื้ออื่นเหลือเงินไว้อย่างน้อยเท่าค่าปลดล็อค (Kaitun.allow)
    Kaitun.reserve = cost or 0
    if money and cost and money < cost then
        return zoneNote("money" .. nextZone, ("รอเงิน %s / %s เพื่อปลดล็อค %s"):format(short(money), short(cost), nextZone))
    end
    zoneNote("try" .. nextZone, ("กำลังปลดล็อค %s"):format(nextZone))
    fire("MineSelectZone", nextZone)
    return nil
end, function() return 0.1 end)

researchSection:AddToggle("AutoUnlockZone", {
    Text = "Auto Unlock Next Zone",
    Default = false,
    Callback = function(on)
        if on then
            ZoneNoteKey = nil
            startAutoZone()
        else
            stopAutoZone()
            Kaitun.reserve = 0  -- ไม่ได้รอปลดล็อคแล้ว ไม่ต้องกันเงิน
        end
    end,
})

end -- จบก้อน Research

-- ก้อน Upgrade Plot ถึง My Plot (แยกก้อน: local ในก้อนเดียวกันรวมกับข้างนอกห้ามเกิน 200 ตอน -O0)
do
----------------------------------------------------------------
-- AUTO UPGRADE PLOT (อัป miner ที่ยืนอยู่บน pad ของ plot)
-- remote: Event:FireServer("MineUpgradeCharacter", padId, upgradeType, nil)
--   เช่น   Event:FireServer("MineUpgradeCharacter", "M7", "Damage", nil)
--          Event:FireServer("MineUpgradeCharacter", "M7", "Speed", nil)
--          Event:FireServer("MineUpgradeCharacter", "M7", "MineSpeed", nil)
--
-- หลักการ:
--   - pad ที่จะอัป = pad ที่มี miner ยืนอยู่จริงบน plot เรา
--       workspace.MineWorld.Plots.MinePlot<n>.Crew.Crew_M<pad>   (Crew_M1 -> pad "M1")
--       + pad ที่มีใน state ของเกม (Holders) แต่ model ยังไม่โหลด
--     pad ว่าง / hauler -> ไม่ยิง
--   - level อ่านจาก Holders[pad] (CharLevel / CharSpeedLevel / CharMineSpeedLevel)
--     เต็มแล้ว (Damage 100 / Speed 17 / Mining Speed 16) -> ข้าม ไม่ยิงเปล่า
--   - ปกติ: 1 รอบ = ทุก pad x ทุกแบบที่เลือก อัปอย่างละ 1 ครั้ง
--   - เช็คเงินก่อนยิง: ราคาจาก MineConfig.GetCharacterUpgradeCost / GetCharacterSpeedUpgradeCost /
--     GetCharacterMineSpeedUpgradeCost(level ปัจจุบัน, def ตัวละคร) เทียบกับ leaderstats.Cash
--     -> เงินไม่พอ / อ่านเงินไม่ได้ = ยังไม่อัป
--     (ไม่รู้ level -> คิดที่ level 1 = ราคาต่ำสุด, หา def ตัวละครไม่เจอ -> ยิงให้ server ตัดสินเอง)
--   - Focus Strongest Pad: เรียง pad จากแรงสุด (ลำดับเดียวกับการ์ด My Plot)
--       มี level ครบทุก pad -> อัปแค่ pad แรงสุดที่ยังไม่ตัน (เงินไม่พอก็รอ ไม่เอาไปลงตัวอื่น)
--                             ตัน (ทุกแบบที่เลือกเต็ม) แล้วค่อยไป pad ถัดไป
--       ยังไม่มี level       -> รู้ไม่ได้ว่าตันหรือยัง เลยยิงทุก pad ไล่จากตัวแรงสุดก่อน
--                             (ตัวแรงได้เงินก่อน / pad ที่ตันแล้ว server ข้ามเอง)
--     ความแรง = MineConfig.GetHolderDamage (tier x level x pickaxe x variant แบบเดียวกับในเกม)
----------------------------------------------------------------
-- แบบที่อัปได้: id = ชื่อที่ remote ใช้, label = ชื่อในเกม
--   field = ช่อง level ใน Holders, max = level สูงสุด (อ่านจาก MineConfig)
--   costFn = ฟังก์ชันราคาของเกม (level ปัจจุบัน, def ตัวละคร) -> ราคาอัปขั้นถัดไป
local PLOT_UPGRADES = {
    { id = "Damage",    label = "Damage",       field = "CharLevel",          max = MineConfig.CharMaxLevel,          costFn = "GetCharacterUpgradeCost" },
    { id = "Speed",     label = "Speed",        field = "CharSpeedLevel",     max = MineConfig.CharSpeedMaxLevel,     costFn = "GetCharacterSpeedUpgradeCost" },
    { id = "MineSpeed", label = "Mining Speed", field = "CharMineSpeedLevel", max = MineConfig.CharMineSpeedMaxLevel, costFn = "GetCharacterMineSpeedUpgradeCost" },
}
local PLOT_LABELS = {}
local PlotLabelToId = {}
for _, u in ipairs(PLOT_UPGRADES) do
    table.insert(PLOT_LABELS, u.label)
    PlotLabelToId[u.label] = u.id
    PlotLabelToId[u.id] = u.id  -- รองรับ config เก่าที่เซฟเป็นชื่อ id
end
local PlotTypes = { Damage = true, Speed = true, MineSpeed = true }  -- แบบที่เลือก (ค่าเริ่มต้น = ทั้งหมด)
local PlotFocus = false   -- toggle Focus Strongest Pad

-- เลขท้าย id ไว้เรียง pad: "M10" -> 10
local function padNumber(id)
    return tonumber(tostring(id):match("(%d+)$")) or math.huge
end

-- Level Cap (ช่อง input "PlotLevelCap"): อัปถึง level นี้แล้วหยุด
--   ค่าเริ่มต้น = ว่าง = อัปจนเต็ม (max ของเกม: MineConfig.CharMaxLevel ตอนนี้ 100)
--     (2026-11-17 เลิกล็อค 50: เกมไม่จำกัดเลเวลตาม capacity แล้ว GetCharLevelCap = CharMaxLevel เสมอ
--      + research ที่ติด MinePower ต้องอัปเกิน 50 ถึงจะผ่าน) ใส่ตัวเลข = หยุดที่เลเวลนั้น
--   ใช้กับทุกแบบ: Damage / Speed / Mining Speed (แต่ไม่เกิน max ของแต่ละแบบ)
local function plotLevelCap()
    local v = Velvet.Flags["PlotLevelCap"]
    local n = tonumber(v)
    return (n and n > 0) and math.floor(n) or nil
end

-------------------- miner ที่เลือก (กดการ์ดในหน้าต่าง My Plot) --------------------
-- เลือกไว้ = อัปเฉพาะ pad ที่เลือก / ไม่ได้เลือกเลย = อัปทุกตัว
-- เซฟลงไฟล์ EndHubData/miner_select.json (รันใหม่ก็ยังอยู่)
local MINER_SELECT_FILE = "EndHubData/miner_select.json"
local SelectedPads = {}  -- [padId] = true

local function saveSelectedPads()
    pcall(function()
        if not isfolder("EndHubData") then makefolder("EndHubData") end
        local list = {}
        for id in pairs(SelectedPads) do table.insert(list, id) end
        writefile(MINER_SELECT_FILE, HttpService:JSONEncode({ pads = list }))
    end)
end

pcall(function()
    if not isfile(MINER_SELECT_FILE) then return end
    local data = HttpService:JSONDecode(readfile(MINER_SELECT_FILE))
    for _, id in ipairs(type(data) == "table" and type(data.pads) == "table" and data.pads or {}) do
        if type(id) == "string" and id:match("^M%d+$") then SelectedPads[id] = true end
    end
end)

local function selectedCount()
    local n = 0
    for _ in pairs(SelectedPads) do n += 1 end
    return n
end

-- pad ของ miner ("M1", "M2", ...) แบบที่ remote MineUpgradeCharacter ใช้
local function isMinerPad(id)
    return type(id) == "string" and id:match("^M%d+$") ~= nil
end

-- level นี้เต็มแล้วไหม (ไม่มีข้อมูล = ถือว่ายังไม่เต็ม)
local function isPlotMaxed(holder, u)
    if not holder then return false end
    -- miner แบบ Scaled: เกมคิด Speed / Mining Speed จากค่าของ Scaled ไม่ได้ดู level
    --   (MineConfig.GetHolderSpeed / GetHolderMineSpeed) อัปไปก็ไม่มีผล -> ถือว่าเต็ม
    local scaled = holder.Scaled
    if u.id ~= "Damage" and type(scaled) == "table" and scaled.Name ~= nil and scaled.Name == holder.CharName then
        return true
    end
    local lv = tonumber(holder[u.field]) or (u.id == "Damage" and tonumber(holder.Level)) or nil
    local mx = tonumber(u.max)
    local cap = plotLevelCap()
    if cap and (mx == nil or cap < mx) then mx = cap end  -- Level Cap ต่ำกว่า max -> หยุดที่ cap
    return lv ~= nil and mx ~= nil and lv >= mx
end

-- ความแรงของ miner บน pad (ยิ่งมากยิ่งแรง)
--   ใช้สูตรของเกม GetHolderDamage ถ้าเรียกไม่ได้ -> ประมาณจาก tier แล้วค่อย level
local function padStrength(holder)
    local def = getCharDef(holder.CharName)
    local ok, dmg = pcall(MineConfig.GetHolderDamage, holder, def)
    if ok and tonumber(dmg) then return tonumber(dmg) end
    local tier = def and tonumber(def.MineTier) or 0
    return tier * 1e6 + (tonumber(holder.CharLevel or holder.Level) or 0)
end

-------------------- crew บน plot เรา (ใช้ทั้ง Auto Upgrade Plot และการ์ด My Plot) --------------------
-- ข้อมูลที่ใช้:
--   crew   : workspace.MineWorld.Plots.MinePlot<n>.Crew.Crew_M<pad> -> model ของ miner แต่ละตัว
--            ชื่อตัวละคร = Humanoid.DisplayName (เทียบกับ catalog), pad = ท้ายชื่อ model (Crew_M1 -> M1)
--            attribute Variant (เช่น Platinum) -> สี + ตัวคูณจาก MineConfig.GetVariantData
--   ตัวละคร: MineCharacterCatalog (ItemName, Rarity, MineTier, MineDamageMult, ImageId, MineRole)
--   level  : Holders[pad] ใน state ของเกม (CharLevel / CharSpeedLevel / CharMineSpeedLevel) ถ้าหาได้

-- ชื่อ rarity + สี
--   rarity ของเกมเป็น table { Rarity = "Epic", Accent = Color3 } (Rarities.GetRarity) หรือ string
local RARITY_NAME_KEYS = { "Rarity", "Name", "DisplayName", "Id" }
local function rarityInfo(r)
    if type(r) ~= "table" then
        return r ~= nil and tostring(r) or "?", nil
    end
    local name = "?"
    for _, k in ipairs(RARITY_NAME_KEYS) do
        if type(r[k]) == "string" then name = r[k]; break end
    end
    local color = (typeof(r.Accent) == "Color3" and r.Accent)
        or (typeof(r.Color) == "Color3" and r.Color)
        or nil
    return name, color
end

-- ชื่อตัวละครทั้งหมดใน catalog เรียงยาว -> สั้น (ไว้หาชื่อที่อยู่ในข้อความ)
local CharNamesByLen = nil

-- แปลงข้อความ (เช่น Humanoid.DisplayName) -> ชื่อตัวละครใน catalog
--   1) ตรงตัว  2) ตัด variant ข้างหน้าออก ("Platinum Light Gami" -> "Light Gami")
--   3) ชื่อใน catalog ที่ยาวที่สุดที่อยู่ในข้อความเป็นคำเต็ม
local function resolveCharName(text, variant)
    if type(text) ~= "string" or text == "" then return nil end
    if getCharDef(text) then return text end
    if type(variant) == "string" and variant ~= "" and text:sub(1, #variant + 1) == variant .. " " then
        local rest = text:sub(#variant + 2)
        if getCharDef(rest) then return rest end
    end
    if CharNamesByLen == nil then
        CharNamesByLen = {}
        for n in pairs(CharDefs or {}) do table.insert(CharNamesByLen, n) end
        table.sort(CharNamesByLen, function(a, b) return #a > #b end)
    end
    for _, n in ipairs(CharNamesByLen) do
        local i, j = text:find(n, 1, true)
        if i and not text:sub(i - 1, i - 1):match("%w") and not text:sub(j + 1, j + 1):match("%w") then
            return n
        end
    end
    return nil
end

-- ข้อมูล miner 1 ตัว (ตัวละคร + variant + รูป + rarity)
local function makeCrewEntry(padId, name, variant, holder)
    local def = getCharDef(name)
    local rName, rColor = rarityInfo(def and def.Rarity)
    local img = def and def.ImageId

    -- สี + ตัวคูณของ variant จากเกม (ไม่มี = ใช้ตารางสีของเรา)
    local vColor, vMult = nil, nil
    if type(variant) == "string" then
        pcall(function()
            local vd = MineConfig.GetVariantData(variant)
            if type(vd) == "table" then
                if typeof(vd.Color) == "Color3" then vColor = vd.Color end
                vMult = tonumber(vd.Mult)
            end
        end)
    end

    return {
        name = tostring(name),
        pad = padId,
        variant = variant,
        variantColor = vColor,
        variantMult = vMult,
        image = (img and tostring(img) ~= "" and tostring(img) ~= "0") and tostring(img) or nil,
        rarity = rName,
        rarityColor = rColor,
        tier = def and tonumber(def.MineTier) or nil,
        hauler = def ~= nil and def.MineRole == "Hauler",  -- hauler ขนของ ไม่ได้ขุด
        holder = holder,
    }
end

-- miner ทั้งหมดบน plot ของเรา (เรียงแรงสุดก่อน)
--   1. model ใน Crew: Crew_M1 -> pad M1, ชื่อจาก Humanoid.DisplayName
--   2. pad ที่มีใน Holders แต่ยังไม่เห็น model (ยังไม่โหลด) -> เพิ่มให้ด้วย
--   level จาก Holders[pad] (ถ้าหา state ของเกมได้)
local function getCrewList()
    local plot = getMyPlot()
    local mg = getMineGame()
    local holders = (mg and type(mg.Holders) == "table") and mg.Holders or {}
    local list, seen = {}, {}

    local folder = plot and plot:FindFirstChild("Crew")
    for _, m in ipairs(folder and folder:GetChildren() or {}) do
        local hum = m:FindFirstChildOfClass("Humanoid")
        local padId = m.Name:match("([MH]%d+)$")                -- "Crew_M1" -> "M1"
        -- pad เดียวกันเอาแค่ตัวเดียว (ใน Crew มี model ซ้ำของ pad เดียวกันได้ เช่น ตัวโคลนของเกม)
        if (hum or m:IsA("Model")) and not (padId and seen[padId]) then
            local holder = padId and holders[padId] or nil
            if type(holder) ~= "table" then holder = nil end
            local variant = m:GetAttribute("Variant") or (holder and holder.CharVariant) or nil
            local display = hum and hum.DisplayName or ""
            local name = resolveCharName(display, variant)
                or resolveCharName(holder and holder.CharName, variant)
                or (display ~= "" and display)
                or (holder and holder.CharName)
                or m.Name
            -- ไม่มี state ของเกม -> อ่าน level จากตัวละครบน plot เอง (attribute ของ model / Humanoid)
            if not holder then
                local lv = {}
                for _, f in ipairs({ "CharLevel", "Level", "CharSpeedLevel", "SpeedLevel", "CharMineSpeedLevel", "MineSpeedLevel" }) do
                    local v = tonumber(m:GetAttribute(f)) or (hum and tonumber(hum:GetAttribute(f)))
                    if v then lv[f] = v end
                end
                if next(lv) then
                    holder = {
                        CharName = name, CharVariant = variant,
                        CharLevel = lv.CharLevel or lv.Level,
                        CharSpeedLevel = lv.CharSpeedLevel or lv.SpeedLevel,
                        CharMineSpeedLevel = lv.CharMineSpeedLevel or lv.MineSpeedLevel,
                    }
                end
            end
            if padId then seen[padId] = true end
            table.insert(list, makeCrewEntry(padId, name, variant, holder))
        end
    end

    for id, h in pairs(holders) do
        local padId = tostring(id)
        if not seen[padId] and padId:match("^[MH]%d+$")
            and type(h) == "table" and type(h.CharName) == "string" and h.CharName ~= "" then
            table.insert(list, makeCrewEntry(padId, h.CharName, h.CharVariant, h))
        end
    end

    -- ความแรง (สูตรเกม GetHolderDamage):
    --   มี level ครบทุกตัว = ใช้ข้อมูลจริง (รวม level + pickaxe)
    --   ไม่ครบ = ทุกตัวใช้แค่ ชื่อ + variant (level 1) จะได้เทียบกันได้แฟร์ๆ
    local allHaveData = #list > 0
    for _, c in ipairs(list) do
        if not c.holder then allHaveData = false; break end
    end
    for _, c in ipairs(list) do
        local h = (allHaveData and c.holder) or { CharName = c.name, CharVariant = c.variant }
        c.power = padStrength(h)
    end
    table.sort(list, function(a, b)
        if a.power ~= b.power then return a.power > b.power end
        return padNumber(a.pad or "") < padNumber(b.pad or "")
    end)
    return list, plot
end

-------------------- ลูปอัป --------------------
-- pad ที่จะอัป เรียงแรงสุดก่อน: { id = "M7", name = "...", holder = {...} หรือ nil }
--   เอาเฉพาะ pad ของ miner (ไม่เอา hauler)
--   เลือกการ์ดไว้ใน My Plot -> เอาเฉพาะ pad ที่เลือก
local function getPlotPads()
    local pads = {}
    local onlySelected = next(SelectedPads) ~= nil
    for _, c in ipairs((getCrewList())) do
        if isMinerPad(c.pad) and not c.hauler and (not onlySelected or SelectedPads[c.pad]) then
            table.insert(pads, { id = c.pad, name = c.name, holder = c.holder })
        end
    end
    return pads
end

-- แบบที่ยังอัปได้ของ pad นี้ (เลือกไว้ + ยังไม่เต็ม)
local function plotTodo(pad)
    local list = {}
    for _, u in ipairs(PLOT_UPGRADES) do
        if PlotTypes[u.id] and not isPlotMaxed(pad.holder, u) then
            table.insert(list, u)
        end
    end
    return list
end

local function plotNotify(text, kind)
    Velvet:Notify({ Title = "Upgrade Miner", Content = text, Duration = 4, Type = kind or "info" })
end

-- แจ้งเตือนเฉพาะตอนสถานะเปลี่ยน (ไม่สแปมทุกรอบ)
local PlotNoteKey = nil
local function plotNote(key, text, kind)
    if key == PlotNoteKey then return end
    PlotNoteKey = key
    plotNotify(text, kind)
end

-- ราคาอัปขั้นถัดไปของ pad นี้ (หา def ตัวละครไม่เจอ / เรียกฟังก์ชันเกมไม่ได้ = nil)
--   level ไม่มีในข้อมูล -> ใช้ level 1 เหมือนที่เกมทำ (GetHolderLevel: ... or 1)
--   ไม่มีข้อมูล level เลย (holder ยังไม่มา) -> คิดที่ level 1 = ราคาต่ำสุด
--     เงินยังไม่ถึงราคาต่ำสุด = ไม่พอแน่นอน -> ไม่อัป
--   เรียกฟังก์ชันของเกม -> ต้องเรียกผ่าน isolated
local function upgradeCost(pad, u)
    local h = pad.holder
    local fn = MineConfig[u.costFn]
    if type(fn) ~= "function" then return nil end
    local def = getCharDef(pad.name) or (h and getCharDef(h.CharName)) or nil
    if not def then return nil end
    local lv = h and (tonumber(h[u.field]) or (u.id == "Damage" and tonumber(h.Level))) or 1
    local ok, cost = pcall(fn, lv, def)
    return ok and tonumber(cost) or nil
end

-- เงินตอนนี้ (ไม่รู้ = nil -> ไม่เช็ค ให้ server ตัดสินเอง)
local function currentMoney()
    local _, money = getMineGame()
    return money
end

-- อัป 1 pad: ทุกแบบที่ยังอัปได้ อย่างละ 1 ครั้ง
--   รู้ราคา + รู้เงิน + เงินไม่พอ -> ข้าม ไม่ยิงเปล่า
--   คืนจำนวนที่ยิงไป, จำนวนที่ข้ามเพราะเงินไม่พอ, ราคาถูกสุดที่ข้าม (ไว้บอกว่าต้องใช้เท่าไหร่)
local function upgradePad(pad, todo, alive)
    local fired, poor, need = 0, 0, nil
    for _, u in ipairs(todo) do
        if not alive() then break end
        local cost = pad.costs and pad.costs[u.id]
        local money = currentMoney()  -- leaderstats.Cash ก่อน (ดู getMineGame)
        -- รู้ราคาแล้ว: เงินไม่พอ หรืออ่านเงินไม่ได้ -> ยังไม่อัป
        if cost and (money == nil or money < cost) then
            poor += 1
            if not need or cost < need.cost then
                need = { cost = cost, pad = pad.id, type = u.label }
            end
        elseif cost and not Kaitun.allow("Miner", cost) then
            -- Kaitun: เกินงบหมวด Miner / ต้องเก็บเงินปลดล็อค zone -> ข้าม (ไม่นับว่าเงินไม่พอ)
            continue
        else
            fire("MineUpgradeCharacter", pad.id, u.id, nil)
            fired += 1
            task.wait(1)
        end
    end
    return fired, poor, need
end

-- ข้อความตอนเงินไม่พอ: บอกเงินที่อ่านได้ + ราคาที่ต้องใช้ (ไว้เช็คว่าอ่านเงินถูกไหม)
--   ไม่ได้ใช้ key แยกตามจำนวนเงิน -> ไม่สแปม แจ้งใหม่เมื่อ pad/แบบที่รอเปลี่ยน
local function poorNote(need)
    local money = currentMoney()
    local _, raw, src = getCash()
    if money == nil then
        plotNote("nomoney", ("อ่านเงินไม่ได้ เลยยังไม่อัป\n%s = %s (%s)"):format(tostring(src), tostring(raw), typeof(raw)), "error")
        print("[End Hub] Upgrade Miner: อ่านเงินไม่ได้ |", src, "=", raw, typeof(raw))
        return
    end
    local key = "poor:" .. tostring(need and need.pad) .. tostring(need and need.type)
    local text = need
        and ("เงินไม่พอ: มี %s / ต้องใช้ %s (%s %s)"):format(short(money), short(need.cost), need.pad, need.type)
        or "เงินไม่พอ รอเงินก่อน"
    if key ~= PlotNoteKey then
        print(("[End Hub] Upgrade Miner: money=%s (%s=%s) need=%s"):format(
            tostring(money), tostring(src), tostring(raw), tostring(need and need.cost)))
    end
    plotNote(key, text)
end

local function upgradePlotPass(alive)
    -- ดึงข้อมูลใน thread แยก (มีเรียกฟังก์ชันของเกม) แล้วค่อยยิง / แจ้งเตือนใน thread นี้
    local ok, pads = isolated(getPlotPads)
    if not ok then
        warn("[End Hub] Auto Upgrade Plot data error:", pads)
        return
    end
    if #pads == 0 then
        if next(SelectedPads) ~= nil then
            plotNote("nosel", "miner ที่เลือกไว้ไม่อยู่บน plot แล้ว (กด Clear selection ใน My Plot)", "error")
        elseif getMyPlot() then
            plotNote("empty", "ยังไม่เห็น miner บน plot ของคุณ", "error")
        else
            plotNote("noplot", "หา plot ของคุณไม่เจอ (workspace.MineWorld.Plots)", "error")
        end
        return
    end

    -- รู้ level ครบทุก pad ไหม (ไม่ครบ = เช็คตันไม่ได้)
    local hasLevels = true
    for _, pad in ipairs(pads) do
        if not pad.holder then hasLevels = false; break end
    end

    -- ตามลำดับ Smart Equip (โหมด "ใส่ตามโซน" เปิด): ตัวจากโซนลึกกว่าได้อัปก่อน -> โซนเดียวกัน = พลัง base มากกว่า
    --   ตัวที่ Smart Equip กำลังจะเปลี่ยนออก (กระเป๋ามีตัวที่ดีกว่า) = ข้าม ไม่เสียเงินอัป
    local byZone = Addon.equipRank and Addon.equipZoneFirst and Addon.equipZoneFirst()
    local skipped = 0
    if byZone then
        isolated(function()
            local keep = {}
            for _, pad in ipairs(pads) do
                local nm = (pad.holder and pad.holder.CharName) or pad.name
                pad.zi, pad.base = Addon.equipRank(nm)
                if Addon.equipReplaceable(nm) then skipped += 1 else table.insert(keep, pad) end
            end
            pads = keep
        end)
        table.sort(pads, function(a, b)
            if (a.zi or 0) ~= (b.zi or 0) then return (a.zi or 0) > (b.zi or 0) end
            if (a.base or 0) ~= (b.base or 0) then return (a.base or 0) > (b.base or 0) end
            return padNumber(a.id) < padNumber(b.id)
        end)
        if #pads == 0 then
            plotNote("replace", ("รอ Smart Equip เปลี่ยนตัว %d pad ก่อน (ไม่อัปตัวที่จะโดนเปลี่ยนออก)"):format(skipped))
            return
        end
    end

    -- pad ที่ยังมีอะไรให้อัป (ลำดับเดิม = แรงสุดก่อน / โหมดโซน = ลำดับ Smart Equip)
    local queue = {}
    for _, pad in ipairs(pads) do
        pad.todo = plotTodo(pad)
        if #pad.todo > 0 then table.insert(queue, pad) end
    end
    if #queue == 0 then
        if next(PlotTypes) == nil then
            plotNote("notype", "ยังไม่ได้เลือกว่าจะอัปอะไร (Upgrade)", "error")
        else
            plotNote("done", "ทุก pad ตันแล้ว", "success")
        end
        return
    end

    -- ราคาอัปของแต่ละ pad (เรียกฟังก์ชันเกม -> thread แยก)
    isolated(function()
        for _, pad in ipairs(queue) do
            pad.costs = {}
            for _, u in ipairs(pad.todo) do
                pad.costs[u.id] = upgradeCost(pad, u)
            end
        end
    end)

    -- Focus Strongest Pad + รู้ level: อัปแค่ pad แรงสุดที่ยังไม่ตัน
    if PlotFocus and hasLevels then
        local pad = queue[1]
        local fired, poor, need = upgradePad(pad, pad.todo, alive)
        if fired == 0 and poor > 0 then
            poorNote(need)
        elseif fired == 0 then
            plotNote("hold", "Kaitun: เก็บเงินไว้ให้ research / ปลดล็อค zone ก่อน")
        else
            plotNote("focus:" .. pad.id, ("Focus %s (%s)"):format(pad.id, pad.name), "success")
        end
        return
    end

    if PlotFocus then
        plotNote("order", "ยังไม่มีข้อมูล level จากเกม เลยเช็คตันไม่ได้\nอัปทุก pad ไล่จากตัวแรงสุดก่อน")
    elseif not byZone then
        -- ปกติ: ไล่ตามเลข pad
        table.sort(queue, function(a, b) return padNumber(a.id) < padNumber(b.id) end)
    end
    local totalFired, totalPoor, totalNeed = 0, 0, nil
    for _, pad in ipairs(queue) do
        if not alive() then return end
        local fired, poor, need = upgradePad(pad, pad.todo, alive)
        totalFired += fired
        totalPoor += poor
        if need and (not totalNeed or need.cost < totalNeed.cost) then totalNeed = need end
    end
    if not PlotFocus then
        if totalFired == 0 and totalPoor > 0 then
            poorNote(totalNeed)
        elseif totalFired == 0 then
            plotNote("hold", "Kaitun: เก็บเงินไว้ให้ research / ปลดล็อค zone ก่อน")
        else
            plotNote("all:" .. #queue .. ":" .. skipped, ("กำลังอัป %d pad%s"):format(#queue,
                skipped > 0 and (" (ข้าม %d ตัวที่จะโดนเปลี่ยน)"):format(skipped) or ""), "success")
        end
    end
end

-- รอระหว่างรอบ (คงที่ ไม่มี slider แล้ว)
local PLOT_UPGRADE_WAIT = 1
local startPlotUpgrade
startPlotUpgrade, stopPlotUpgrade = makeLoop(
    upgradePlotPass,
    function() return PLOT_UPGRADE_WAIT end
)

-------------------- หน้าต่างการ์ด My Plot (miner บน plot ของเรา) --------------------
-- plot : attribute PlotIndex / ZoneKey / OwnerUserId (workspace.MineWorld.Plots.MinePlot<n>)
-- การ์ด: ข้อมูลจาก getCrewList ข้างบน เรียงแรงสุด -> อ่อนสุด (ลำดับเดียวกับ Focus Strongest Pad)

-- สี variant (ไม่มีในตาราง = สีเหลืองเดียวกับพลังขุด)
local VARIANT_COLORS = {
    Gold     = Color3.fromRGB(255, 200, 60),
    Golden   = Color3.fromRGB(255, 200, 60),
    Platinum = Color3.fromRGB(205, 225, 240),
    Diamond  = Color3.fromRGB(120, 220, 255),
    Rainbow  = Color3.fromRGB(255, 130, 210),
    Shadow   = Color3.fromRGB(170, 140, 255),
}

local PLOT_GUI_NAME = "EndHub_MyPlot"
local PCARD_W, PCARD_H = 116, 158
PlotGui = nil            -- ScreenGui (สร้างตอนกดเปิดครั้งแรก)
local PlotRender = nil   -- วาดการ์ดใหม่ (มีหลังสร้างหน้าต่าง)

local function buildPlotGui()
    local parent = getGuiParent()
    pcall(function()
        local old = parent:FindFirstChild(PLOT_GUI_NAME)
        if old then old:Destroy() end
    end)

    local gui = make("ScreenGui", {
        Name = PLOT_GUI_NAME,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 2147483647,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, nil)
    if not pcall(function() gui.Parent = parent end) then
        gui.Parent = LP:WaitForChild("PlayerGui")
    end

    local win = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(W, H),
        BackgroundColor3 = C.bg,
        Active = true,
    }, gui)
    round(win, 12)
    outline(win)

    local scale = make("UIScale", {}, win)
    local cam = workspace.CurrentCamera
    local function fit()
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        scale.Scale = math.clamp(math.min((vp.X - 24) / W, (vp.Y - 24) / H), 0.5, 1)
    end
    fit()
    local conns = {}
    if cam then
        table.insert(conns, cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit))
    end

    ---------- แถบซ้าย ----------
    local dragArea = make("Frame", {
        Size = UDim2.fromOffset(SIDE_W - 40, 64),
        BackgroundTransparency = 1,
    }, win)
    makeLogo(win, 24, 2).Position = UDim2.fromOffset(16, 20)
    label(win, "End Hub", {
        Position = UDim2.fromOffset(48, 16),
        Size = UDim2.fromOffset(SIDE_W - 90, 22),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
    })
    label(win, "My plot", {
        Position = UDim2.fromOffset(48, 38),
        Size = UDim2.fromOffset(SIDE_W - 60, 16),
        TextSize = 12,
        TextColor3 = C.sub,
    })
    local closeBtn = make("TextButton", {
        Position = UDim2.fromOffset(SIDE_W - 38, 15),
        Size = UDim2.fromOffset(24, 24),
        AutoButtonColor = false,
        BackgroundColor3 = C.close,
        Text = "X",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = C.picked,
    }, win)
    round(closeBtn, 6)
    closeBtn.MouseEnter:Connect(function() closeBtn.BackgroundColor3 = C.closeHover end)
    closeBtn.MouseLeave:Connect(function() closeBtn.BackgroundColor3 = C.close end)

    -- ข้อมูล plot
    local plotLabel = label(win, "", {
        Position = UDim2.fromOffset(18, 80),
        Size = UDim2.fromOffset(SIDE_W - 30, 26),
        Font = Enum.Font.GothamBold,
        TextSize = 22,
    })
    local ownerLabel = label(win, "", {
        Position = UDim2.fromOffset(18, 106),
        Size = UDim2.fromOffset(SIDE_W - 30, 16),
        TextSize = 12,
        TextColor3 = C.sub,
    })
    local zoneLabel = label(win, "", {
        Position = UDim2.fromOffset(18, 134),
        Size = UDim2.fromOffset(SIDE_W - 30, 18),
        Font = Enum.Font.GothamMedium,
    })
    local crewLabel = label(win, "", {
        Position = UDim2.fromOffset(18, 156),
        Size = UDim2.fromOffset(SIDE_W - 30, 18),
        Font = Enum.Font.GothamMedium,
    })
    -- miner ที่เลือก + Level Cap
    local selectLabel = label(win, "", {
        Position = UDim2.fromOffset(18, 190),
        Size = UDim2.fromOffset(SIDE_W - 30, 18),
        Font = Enum.Font.GothamMedium,
        RichText = true,
    })
    local capLabel = label(win, "", {
        Position = UDim2.fromOffset(18, 212),
        Size = UDim2.fromOffset(SIDE_W - 30, 18),
        Font = Enum.Font.GothamMedium,
        RichText = true,
    })
    label(win, "Tap a card to pick which miners to upgrade. None picked = all", {
        Position = UDim2.fromOffset(18, 238),
        Size = UDim2.fromOffset(SIDE_W - 30, 48),
        TextSize = 11,
        TextColor3 = C.dim,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
        TextYAlignment = Enum.TextYAlignment.Top,
    })

    -- ปุ่ม Clear (ล้างที่เลือก)
    local clearBtn = button(win, "Clear selection", {
        Position = UDim2.new(0, 10, 1, -86),
        Size = UDim2.fromOffset(SIDE_W - 20, 32),
        TextColor3 = C.sub,
    })
    clearBtn.MouseEnter:Connect(function() clearBtn.BackgroundColor3 = C.hover end)
    clearBtn.MouseLeave:Connect(function() clearBtn.BackgroundColor3 = C.card end)

    -- ปุ่ม Refresh: พื้นไล่สี indigo -> ม่วง ให้เด่นกว่าปุ่มอื่น
    local REFRESH_A = Color3.fromRGB(99, 102, 241)
    local REFRESH_B = Color3.fromRGB(168, 85, 247)
    local refreshBtn = button(win, "⟳  Refresh", {
        Position = UDim2.new(0, 10, 1, -46),
        Size = UDim2.fromOffset(SIDE_W - 20, 32),
        BackgroundColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.new(1, 1, 1),
    })
    local refreshGrad = make("UIGradient", {
        Color = ColorSequence.new(REFRESH_A, REFRESH_B),
        Rotation = 0,
    }, refreshBtn)
    local refreshStroke = refreshBtn:FindFirstChildOfClass("UIStroke")
    if refreshStroke then refreshStroke.Color = REFRESH_B; refreshStroke.Transparency = 0.4 end
    refreshBtn.MouseEnter:Connect(function() refreshGrad.Rotation = 180 end)
    refreshBtn.MouseLeave:Connect(function() refreshGrad.Rotation = 0 end)

    make("Frame", {
        Position = UDim2.fromOffset(SIDE_W, 12),
        Size = UDim2.new(0, 1, 1, -24),
        BackgroundColor3 = C.line,
        BorderSizePixel = 0,
    }, win)

    ---------- ด้านขวา ----------
    local X0 = SIDE_W + 14
    label(win, "Miners on your plot (strongest first)", {
        Position = UDim2.fromOffset(X0, 14),
        Size = UDim2.new(1, -(X0 + 14), 0, 18),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
    })
    label(win, "Name from Humanoid.DisplayName", {
        Position = UDim2.fromOffset(X0, 32),
        Size = UDim2.new(1, -(X0 + 14), 0, 16),
        TextSize = 12,
        TextColor3 = C.sub,
    })

    local grid = make("ScrollingFrame", {
        Position = UDim2.fromOffset(X0 - 2, 60),
        Size = UDim2.new(1, -(X0 - 2) - 10, 1, -72),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = C.stroke,
    }, win)
    make("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }, grid)
    make("UIGridLayout", {
        CellSize = UDim2.fromOffset(PCARD_W, PCARD_H),
        CellPadding = UDim2.fromOffset(GAP, GAP),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)

    -- สีการ์ดตอนถูกเลือก (พื้นสว่าง + ขอบขาว เหมือนการ์ด pickaxe ที่เลือก)
    local CARD_PICKED = Color3.fromRGB(48, 48, 58)
    local cardViews = {}  -- [padId] = { card, stroke, badge }

    -- แถบข้าง: miner ที่เลือก + Level Cap
    local function updateSide()
        local n = selectedCount()
        if n == 0 then
            selectLabel.Text = 'Selected  <font color="#A1A1AA">all</font>'
        else
            local ids = {}
            for id in pairs(SelectedPads) do table.insert(ids, id) end
            table.sort(ids, function(a, b) return padNumber(a) < padNumber(b) end)
            selectLabel.Text = ('Selected  <font color="#FFFFFF">%d</font> <font color="#A1A1AA">(%s)</font>')
                :format(n, table.concat(ids, ", "))
        end
        local cap = plotLevelCap()
        capLabel.Text = cap and ('Level cap  <font color="#FFC450">%d</font>'):format(cap)
            or 'Level cap  <font color="#A1A1AA">max</font>'
    end

    -- ทำให้การ์ดตรงกับสถานะเลือก/ไม่เลือก
    local function paintCard(padId)
        local v = cardViews[padId]
        if not v then return end
        local picked = SelectedPads[padId] == true
        v.card.BackgroundColor3 = picked and CARD_PICKED or C.card
        v.stroke.Color = picked and C.picked or C.stroke
        v.stroke.Thickness = picked and 1.5 or 1
        v.badge.Visible = picked
    end

    -- การ์ด 1 ใบ (กด = เลือก / เอาออก เฉพาะ miner pad M#)
    local function makeCard(i, c)
        local selectable = isMinerPad(c.pad) and not c.hauler
        local card = make("TextButton", {
            LayoutOrder = i,
            AutoButtonColor = false,
            Text = "",
            BackgroundColor3 = C.card,
        }, grid)
        round(card, 10)
        local stroke = outline(card)

        -- ป้าย "M7" มุมซ้ายบน (โชว์ตอนถูกเลือก) บอกว่าเป็น miner pad ไหน
        local badge = make("Frame", {
            Position = UDim2.fromOffset(6, 6),
            Size = UDim2.fromOffset(34, 18),
            BackgroundColor3 = C.picked,
            Visible = false,
            ZIndex = 3,
        }, card)
        round(badge, 9)
        label(badge, c.pad or "", {
            Size = UDim2.fromScale(1, 1),
            TextXAlignment = Enum.TextXAlignment.Center,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = C.bg,
            ZIndex = 4,
        })

        if selectable then
            cardViews[c.pad] = { card = card, stroke = stroke, badge = badge }
            card.MouseButton1Click:Connect(function()
                SelectedPads[c.pad] = (not SelectedPads[c.pad]) or nil
                saveSelectedPads()
                paintCard(c.pad)
                updateSide()
            end)
            card.MouseEnter:Connect(function()
                if not SelectedPads[c.pad] then card.BackgroundColor3 = C.hover end
            end)
            card.MouseLeave:Connect(function() paintCard(c.pad) end)
        end

        -- tier (ขวาบน)
        label(card, c.tier and ("T" .. c.tier) or "", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -9, 0, 7),
            Size = UDim2.fromOffset(50, 14),
            TextXAlignment = Enum.TextXAlignment.Right,
            TextSize = 11,
            TextColor3 = C.dim,
            Font = Enum.Font.GothamMedium,
        })

        -- รูปตัวละคร (ไม่มีรูป = ตัวอักษรแรกของชื่อ)
        if c.image then
            make("ImageLabel", {
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new(0.5, 0, 0, 22),
                Size = UDim2.fromOffset(56, 56),
                BackgroundTransparency = 1,
                Image = "rbxassetid://" .. c.image,
                ScaleType = Enum.ScaleType.Fit,
            }, card)
        else
            label(card, c.name:sub(1, 1):upper(), {
                Position = UDim2.new(0, 6, 0, 30),
                Size = UDim2.new(1, -12, 0, 40),
                TextXAlignment = Enum.TextXAlignment.Center,
                Font = Enum.Font.GothamBold,
                TextSize = 30,
                TextColor3 = C.dim,
            })
        end

        -- ชื่อ
        local nameLabel = label(card, c.name, {
            Position = UDim2.new(0, 6, 0, 84),
            Size = UDim2.new(1, -12, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Center,
            Font = Enum.Font.GothamBold,
            TextScaled = true,
        })
        make("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, nameLabel)

        -- variant (เช่น "Platinum x2.5") สีจากเกมถ้ามี
        local variant = c.variant and tostring(c.variant) or "Normal"
        local vText = variant
        if c.variantMult and c.variantMult ~= 1 then
            vText = ("%s x%s"):format(variant, ("%g"):format(c.variantMult))
        end
        local vLabel = label(card, vText, {
            Position = UDim2.new(0, 6, 0, 102),
            Size = UDim2.new(1, -12, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Center,
            Font = Enum.Font.GothamBold,
            TextScaled = true,
            TextColor3 = (variant == "Normal") and C.dim
                or (c.variantColor or VARIANT_COLORS[variant] or C.accent),
        })
        make("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 8 }, vLabel)

        -- rarity
        label(card, c.rarity, {
            Position = UDim2.new(0, 6, 0, 118),
            Size = UDim2.new(1, -12, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextSize = 11,
            TextColor3 = c.rarityColor or C.sub,
        })

        -- level (ถ้ามีข้อมูลจากเกม)
        local h = c.holder
        --   DMG แดง / SPD ฟ้า / MS เขียว ตัวเลขสีขาว (RichText)
        local function stat(name, color, value)
            return ('<font color="%s">%s</font> <font color="#FFFFFF">%s</font>'):format(color, name, tostring(value or "?"))
        end
        local lvText = h and table.concat({
            stat("DMG", "#FF5A5A", h.CharLevel or h.Level),
            stat("SPD", "#4FB4FF", h.CharSpeedLevel),
            stat("MS", "#4ADE80", h.CharMineSpeedLevel),
        }, '<font color="#64646E"> · </font>') or "Level: no data"
        local lvLabel = label(card, lvText, {
            Position = UDim2.new(0, 6, 0, 136),
            Size = UDim2.new(1, -12, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextColor3 = C.dim,
            TextScaled = true,
            RichText = true,
        })
        make("UITextSizeConstraint", { MaxTextSize = 11, MinTextSize = 7 }, lvLabel)
    end

    -- วาดใหม่ทั้งหมด
    local function render()
        for _, ch in ipairs(grid:GetChildren()) do
            if ch:IsA("GuiObject") then ch:Destroy() end
        end
        table.clear(cardViews)
        updateSide()
        local ok, list, plot = isolated(getCrewList)
        if not ok then
            warn("[End Hub] My Plot data error:", list)
            list, plot = {}, getMyPlot()
        end
        local _, num = getMyPlot()
        if not plot then
            plotLabel.Text = "Plot ?"
            ownerLabel.Text = "Plot not found"
            zoneLabel.Text = ""
            crewLabel.Text = ""
            label(grid, "Can't find your plot in workspace.MineWorld.Plots", {
                Size = UDim2.fromOffset(PCARD_W * 3, 20),
                TextColor3 = C.sub,
            })
            return
        end
        plotLabel.Text = ("Plot %s"):format(tostring(num))
        ownerLabel.Text = "Owned by you"
        zoneLabel.Text = ("Zone  %s"):format(tostring(plot:GetAttribute("ZoneKey") or "?"))
        crewLabel.Text = ("Miners  %d"):format(#list)
        if #list == 0 then
            label(grid, "No miners on your plot", {
                Size = UDim2.fromOffset(PCARD_W * 3, 20),
                TextColor3 = C.sub,
            })
            return
        end
        for i, c in ipairs(list) do
            makeCard(i, c)
            if c.pad then paintCard(c.pad) end
        end
    end
    PlotRender = render

    clearBtn.MouseButton1Click:Connect(function()
        table.clear(SelectedPads)
        saveSelectedPads()
        for id in pairs(cardViews) do paintCard(id) end
        updateSide()
    end)

    closeBtn.MouseButton1Click:Connect(function()
        gui.Enabled = false
    end)
    refreshBtn.MouseButton1Click:Connect(function()
        local ok, err = pcall(render)
        if not ok then warn("[End Hub] My Plot refresh error:", err) end
    end)

    -- ลากหน้าต่างด้วยตรงชื่อ
    local dragging, dragStart, startPos = false, nil, nil
    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, win.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    table.insert(conns, UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            win.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))

    gui.Destroying:Connect(function()
        for _, c in ipairs(conns) do c:Disconnect() end
        if PlotRender == render then PlotRender = nil end
    end)

    render()
    return gui
end

-- เปิด/ปิดหน้าต่าง (เปิดทุกครั้ง = ดึงข้อมูลใหม่)
local function togglePlotGui()
    if PlotGui and PlotGui.Parent then
        PlotGui.Enabled = not PlotGui.Enabled
        if PlotGui.Enabled and PlotRender then
            local ok, err = pcall(PlotRender)
            if not ok then warn("[End Hub] My Plot render error:", err) end
        end
        return
    end
    local ok, result = pcall(buildPlotGui)
    if ok then
        PlotGui = result
    else
        warn("[End Hub] My Plot error:", result)
        plotNotify("เปิดหน้าต่างไม่ได้: " .. tostring(result), "error")
    end
end

accentButton(plotSection:AddButton({
    Text = "Upgrade Miner Config",
    Callback = function()
        local opening = not (PlotGui and PlotGui.Parent and PlotGui.Enabled)
        togglePlotGui()
        if opening then
            local plot, num = getMyPlot()
            if plot then
                plotNotify(("Plot %s เป็นของคุณ"):format(tostring(num)), "success")
            else
                plotNotify("หา plot ของคุณไม่เจอ (workspace.MineWorld.Plots)", "error")
            end
        end
    end,
}))

-------------------- Auto Upgrade Plot Slots (ซื้อช่อง pad เพิ่ม) --------------------
-- remote: Event:FireServer("MineBuyMinerSlot")   (โค้ดจาก Cobalt)
-- MineConfig: เริ่ม BaseMinerSlots (5) ช่อง ซื้อได้ถึง MaxMinerSlots (8) = 3 ขั้น
--   ราคาขั้นถัดไป = MinerSlotCosts[ช่องตอนนี้ + 1]   ช่องตอนนี้ = MineGame.MinerSlots
--   ครบ 8 แล้วหยุดยิง / เงินไม่พอ (leaderstats.Cash) รอ / ไม่รู้จำนวนช่อง = ยิงให้ server ตัดสินเอง
do
    local SLOT_BASE = tonumber(MineConfig.BaseMinerSlots) or 5
    local SLOT_MAX = tonumber(MineConfig.MaxMinerSlots) or 8
    local SlotNoteKey = nil
    local function slotNote(key, text, kind)
        if key == SlotNoteKey then return end
        SlotNoteKey = key
        Velvet:Notify({ Title = "Upgrade Plot", Content = text, Duration = 4, Type = kind or "info" })
    end

    local function buySlotPass()
        local mg = getMineGame()
        local slots = mg and tonumber(mg.MinerSlots)
        if mg and not slots then slots = SLOT_BASE end  -- มี state แต่ยังไม่เคยซื้อ = ค่าเริ่มต้น
        if slots and slots >= SLOT_MAX then
            return slotNote("max", ("Plot อัปครบแล้ว (%d/%d ช่อง)"):format(slots, SLOT_MAX), "success")
        end
        local cost = slots and tonumber((MineConfig.MinerSlotCosts or {})[slots + 1])
        local money = getCash()
        if cost and money and money < cost then
            return slotNote("poor" .. slots, ("รอเงิน %s / %s เพื่ออัป Plot ขั้นที่ %d (%d -> %d ช่อง)"):format(
                short(money), short(cost), slots - SLOT_BASE + 1, slots, slots + 1))
        end
        -- Kaitun: เกินงบหมวด Slots / ต้องเก็บเงินปลดล็อค zone -> รอ
        if cost and not Kaitun.allow("Slots", cost) then
            return slotNote("hold" .. slots, "Kaitun: เก็บเงินไว้ปลดล็อค zone ก่อน ค่อยอัป Plot")
        end
        fire("MineBuyMinerSlot")
        if slots then
            slotNote("buy" .. slots, ("อัป Plot ขั้นที่ %d (%d -> %d ช่อง)"):format(slots - SLOT_BASE + 1, slots, slots + 1), "success")
        end
        return nil
    end

    local startBuySlot
    startBuySlot, stopBuySlot = makeLoop(buySlotPass, function() return 2 end)

    plotSection:AddToggle("AutoBuyMinerSlot", {
        Text = "Auto Upgrade Plot Slots",
        Default = false,
        Callback = function(on)
            if on then
                SlotNoteKey = nil
                startBuySlot()
            else
                stopBuySlot()
            end
        end,
    })
end

plotSection:AddToggle("AutoUpgradePlot", {
    Text = "Auto Upgrade Miner",
    Default = false,
    Callback = function(on)
        if on then
            PlotNoteKey = nil
            startPlotUpgrade()
        else
            stopPlotUpgrade()
        end
    end,
})

plotSection:AddToggle("PlotFocusStrongest", {
    Text = "Focus Strongest Pad",
    Default = false,
    VisibleWhen = "AutoUpgradePlot",
    Callback = function(on)
        PlotFocus = on == true
        PlotNoteKey = nil
    end,
})

plotSection:AddDropdown("PlotUpgradeTypes", {
    Text = "Upgrade",
    Values = PLOT_LABELS,
    Default = PLOT_LABELS,
    Multi = true,
    VisibleWhen = "AutoUpgradePlot",
})
-- ใช้ OnFlagChanged แทน Callback: Load Config เรียกแค่ :Set ซึ่งไม่เรียก Callback ของ dropdown
Velvet:OnFlagChanged("PlotUpgradeTypes", function(value)
    local set = {}
    for k, v in pairs(type(value) == "table" and value or {}) do
        local picked = (v == true and k) or (type(v) == "string" and v) or nil
        local id = picked and PlotLabelToId[picked]
        if id then set[id] = true end
    end
    PlotTypes = set
end)

plotSection:AddInput("PlotLevelCap", {
    Text = "Level Cap",
    Default = "",
    Placeholder = "ว่าง = อัปจนเต็ม",
    VisibleWhen = "AutoUpgradePlot",
    Callback = function(value)
        local n = tonumber(value)
        PlotNoteKey = nil
        if value ~= "" and not (n and n > 0) then
            plotNotify("Level Cap ต้องเป็นตัวเลขมากกว่า 0 (ว่าง = อัปจนเต็ม)", "error")
        elseif PlotRender and PlotGui and PlotGui.Enabled then
            pcall(PlotRender)
        end
    end,
})
end -- จบก้อน Upgrade Plot ถึง My Plot

----------------------------------------------------------------
-- SETTINGS TAB
----------------------------------------------------------------
local Settings = Window:AddTab("Settings", "settings")

-- Interface = หน้าตา UI (theme + ขนาด) อยู่หมวดเดียวกัน
local interfaceSection = Settings:AddSection("Interface")
interfaceSection:AddDropdown("Theme", {
    Text = "UI Theme",
    Values = ThemeManager:GetThemes(),
    Default = ThemeManager.Current,
    Callback = function(v)
        ThemeManager:SetTheme(v)
        Velvet:Notify({Title="Theme", Content="Switched to " .. v, Duration=2, Type="success"})
    end
})
interfaceSection:AddSlider("UIScale", {
    Text = "UI Scale",
    Min = 0.7, Max = 1.5, Default = 1, Increment = 0.05,
    Callback = function(v) Window:SetScale(v) end,
})

-- ซ่อน/โชว์ Quick Bar (แถบปุ่มลัดที่โผล่ตอนซ่อนหน้าต่าง)
--   ปิด = ซ่อนทั้งแถบ แล้วให้ปุ่มลอย (โลโก้) โผล่แทน ไว้กดเปิดหน้าต่างกลับ
--   (ปกติ QuickBar สั่งซ่อนปุ่มลอยไว้ ถ้าไม่เอากลับมา บนมือถือจะเปิดหน้าต่างไม่ได้)
local QuickBarOn = true
local FloatOn = false  -- ปุ่มลอยของเราเอง (ดูข้างล่าง) เปิดอยู่ไหม

-- จัดการปุ่มลอยของ Velvet (pill) ตอนหน้าต่างซ่อน:
--   มีปุ่มลอยของเราแล้ว -> ซ่อน pill (ไม่ให้มีปุ่มซ้อน 2 อัน)
--   ไม่มีปุ่มของเรา + ปิด Quick Bar -> โชว์ pill ไว้กดเปิดหน้าต่างกลับ
local function showPillIfHidden()
    local pill = Window._togglePill
    if not pill or Window.Visible then return end
    if FloatOn then
        pill.Visible = false
    elseif not QuickBarOn then
        pill.Visible = true
    end
end

-- ครอบ Window:Hide อีกชั้น: หลังซ่อนหน้าต่าง ค่อยจัดการ pill ตามด้านบน
local hideBeforeWrap = Window.Hide
function Window:Hide(...)
    local result = hideBeforeWrap(self, ...)
    task.delay(0.3, showPillIfHidden)  -- รอ QuickBar กับ Velvet ทำงานเสร็จก่อน (0.22-0.25 วิ)
    return result
end

----------------------------------------------------------------
-- ปุ่มโลโก้ลอย (สำหรับมือถือ / executor จอเล็ก)
--   - อยู่บนจอตลอด กด = เปิด/ปิดหน้าต่าง End Hub (แทนปุ่ม RightShift ที่มือถือไม่มี)
--   - ลากย้ายตำแหน่งได้ (ลากเกิน 6 pixel = ย้าย ไม่นับเป็นการกด)
--   - เปิดเองอัตโนมัติถ้าเป็นจอสัมผัส ปิด/เปิดได้ที่ Settings > Interface
----------------------------------------------------------------
local FloatGui = nil

local function buildFloatButton()
    local gui = Instance.new("ScreenGui")
    gui.Name = "EndHub_FloatButton"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147483646  -- ต่ำกว่าหน้าต่าง Pickaxe Shop 1 ขั้น
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if not pcall(function() gui.Parent = getGuiParent() end) then
        gui.Parent = LP:WaitForChild("PlayerGui")
    end

    -- ตัวปุ่ม: สี่เหลี่ยมมนสีมืด + โลโก้บล็อกหินตรงกลาง
    local btn = make("TextButton", {
        Size = UDim2.fromOffset(60, 60),
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 10),  -- กลางจอ ด้านบน
        AutoButtonColor = false,
        Text = "",
        BackgroundColor3 = C.bg,
        BackgroundTransparency = 0.1,
    }, gui)
    round(btn, 14)
    outline(btn)
    local logo = makeLogo(btn, 40, 2)  -- 40 หาร 8 ลงตัว pixel คม
    logo.AnchorPoint = Vector2.new(0.5, 0.5)
    logo.Position = UDim2.fromScale(0.5, 0.5)

    -- ลาก + แยกการลากออกจากการกด
    local dragging, moved, dragStart, startPos = false, false, nil, nil
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            dragStart, startPos = input.Position, btn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    local moveConn = UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 6 then
                moved = true
            end
            if moved then
                btn.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end
    end)
    gui.Destroying:Connect(function() moveConn:Disconnect() end)

    -- กด (ไม่ได้ลาก) = เปิด/ปิดหน้าต่าง
    btn.Activated:Connect(function()
        if moved then return end
        if Window.Visible then Window:Hide() else Window:Show() end
    end)

    return gui
end

local function setFloatButton(on)
    FloatOn = on
    if on and not FloatGui then
        local ok, result = pcall(buildFloatButton)
        if ok then
            FloatGui = result
        else
            warn("[End Hub] float button error:", result)
            FloatOn = false
        end
    end
    if FloatGui then
        FloatGui.Enabled = FloatOn
    end
    showPillIfHidden()
end

-- เปิดตั้งแต่เริ่มเสมอ (ทั้ง PC และมือถือ)
setFloatButton(false)

----------------------------------------------------------------
-- กดกากบาท (X) ของ End Hub = ปิดสคริปต์ทั้งหมด
--   ปุ่ม X ของ Velvet เรียก Velvet:Destroy() ซึ่งลบแค่ของ Velvet
--   เลยครอบเพิ่มให้ลบของที่เราสร้างเอง + หยุดลูปทุกอันด้วย
--   (ไม่งั้นปุ่มลอยกับหน้าต่าง Pickaxe ค้างอยู่ และลูปยังยิง remote ต่อ)
----------------------------------------------------------------
local stopAutoExec  -- สร้างในก้อน Auto Execute (Settings ท้ายไฟล์)
local velvetDestroy = Velvet.Destroy
function Velvet:Destroy(...)
    -- 1) หยุดทุกลูป
    stopTakeChest()
    stopDailySpin()
    stopAutoSell()
    stopAutoBuy()
    StopBuySkill()
    stopAutoZone()
    stopPlotUpgrade()
    stopAutoTutorial()
    stopBuySlot()
    if stopAutoExec then stopAutoExec() end
    if Kaitun.stop then Kaitun.stop() end
    if Addon.stop then Addon.stop() end  -- Auto Buy Potion + Weblog + หน้าต่าง Gem Shop
    -- 2) ลบปุ่มลอย + หน้าต่าง Pickaxe Shop
    if FloatGui then
        FloatGui:Destroy()
        FloatGui = nil
    end
    if PickaxeGui then
        PickaxeGui:Destroy()
        PickaxeGui = nil
    end
    if PlotGui then
        PlotGui:Destroy()
        PlotGui = nil
    end
    -- Quick Bar: Velvet:Destroy ไม่ลบให้ (เป็น ScreenGui แยก "VelvetQuickBar")
    pcall(function() QuickBar:Destroy() end)
    -- 3) ให้ Velvet ลบของตัวเองต่อ
    return velvetDestroy(self, ...)
end

-- ฝากตัวปิดไว้ให้ตัวที่รันทีหลังเรียก (ดู "รันซ้ำ" บนสุดของไฟล์)
--   destroyed: กด X ไปแล้วไม่ต้องลบซ้ำ
do
    local env = (getgenv and getgenv()) or _G
    local destroyed = false
    local function unload()
        if destroyed then return end
        destroyed = true
        if env.EndHubUnload == unload then env.EndHubUnload = nil end
        Velvet:Destroy()
    end
    env.EndHubUnload = unload
    local wrapped = Velvet.Destroy
    function Velvet:Destroy(...)
        destroyed = true
        if env.EndHubUnload == unload then env.EndHubUnload = nil end
        return wrapped(self, ...)
    end
end

interfaceSection:AddToggle("FloatButton", {
    Text = "Button for mobile executor",
    Default = true,
    Callback = setFloatButton,
})

-- Quick Bar ปิดไว้ตั้งแต่เริ่ม (เปิดเองได้ที่ toggle นี้)
--   Default ของ toggle ไม่เรียก Callback ตอนสร้าง เลยต้องสั่งปิดเองตรงนี้ด้วย
local function setQuickBar(on)
    QuickBarOn = on
    if QuickBar._gui then
        QuickBar._gui.Enabled = on  -- ปิดทั้ง ScreenGui (QuickBar ไม่ได้ยุ่งกับค่านี้)
    end
end
setQuickBar(false)

interfaceSection:AddToggle("ShowQuickBar", {
    Text = "Show Quick Bar",
    Default = false,
    Callback = function(on)
        setQuickBar(on)
        if on then
            -- เปิดกลับ: ถ้าหน้าต่างซ่อนอยู่ ให้แถบโผล่แทนปุ่มลอยเหมือนเดิม
            if not Window.Visible and QuickBar._bar and #QuickBar._pins > 0 then
                QuickBar._bar.Visible = true
                if Window._togglePill then Window._togglePill.Visible = false end
            end
        else
            showPillIfHidden()
        end
    end,
})

local configSection = Settings:AddSection("Config")
configSection:AddInput("ConfigName", {
    Text = "Config Name",
    Default = "default",
    Placeholder = "config name",
})
configSection:AddButton({
    Text = "Save Config",
    Callback = function()
        local name = Velvet.Flags["ConfigName"] or "default"
        local ok, err = SaveManager:Save(name)
        Velvet:Notify({Title="Config", Content=ok and ("Saved: "..name) or ("Error: "..tostring(err)), Duration=3, Type=ok and "success" or "error"})
    end
})
configSection:AddButton({
    Text = "Load Config",
    Callback = function()
        local name = Velvet.Flags["ConfigName"] or "default"
        local ok, err = SaveManager:Load(name)
        Velvet:Notify({Title="Config", Content=ok and ("Loaded: "..name) or ("Error: "..tostring(err)), Duration=3, Type=ok and "success" or "error"})
    end
})

local profileSection = Settings:AddSection("Profiles")
SaveManager:BuildProfileUI(profileSection)

----------------------------------------------------------------
-- ปิดฟังก์ชันทุกอัน
--   ใช้ 2 ที่: ปุ่ม "Disable All Functions" (Settings > General) และปุ่ม "Stop All" บน Quick Bar
--   ปิดเฉพาะ toggle ที่ "ทำงานในเกม" (ฟาร์ม / ซื้อ / อัป / Kaitun)
--   ไม่แตะตัวตั้งค่า: Anti AFK, Auto Execute, Auto Select Next Zone, Focus Strongest Pad, ปุ่มลอย, Quick Bar
--     (เดิม Stop All ปิดทุก toggle -> Auto Execute โดนปิดแล้วลบไฟล์ autoexec, Anti AFK โดนปิดไปด้วย)
--   คืนจำนวนที่ปิดไป
----------------------------------------------------------------
local function disableAllFunctions()
    local count = 0
    -- Kaitun ก่อน: มันเลิกคุมงบ + หยุดลูปผู้คุมของตัวเอง แล้วค่อยปิดฟังก์ชันที่มันเปิดไว้
    for _, id in ipairs({
        "KaitunMode",
        "AutoSmartEquip", "AutoOpenGate", "AutoTutorial",
        "AutoTakeChest", "DailySpin", "AutoClaimMail", "AutoClaimMilestone", "AutoClaimIndex", "AutoRedeemCodes",
        "AutoDailyTrial", "AutoDice",
        "AutoMutation",
        "AutoBuyPickaxe", "AutoSellOres", "AutoSellChars", "AutoBuyGemShop", "AutoUsePotion",
        "Buy_Skill", "AutoUnlockZone",
        "AutoBuyMinerSlot", "AutoUpgradePlot",
    }) do
        if Velvet.Flags[id] == true then
            local elem = Velvet._elements and Velvet._elements[id]
            if type(elem) == "table" and elem.Set then
                pcall(function() elem:Set(false) end)
                count += 1
            end
        end
    end
    return count
end

----------------------------------------------------------------
-- AUTO EXECUTE
--   เปิดไว้ = End Hub รันเองตอนเข้าเกม (loader จำคีย์ไว้แล้ว ไม่ต้องใส่คีย์)
--   1. เขียนไฟล์ EndHub.lua ลงโฟลเดอร์ autoexec ของ executor -> เปิด Roblox เข้าเกมใหม่ก็รันเอง
--      เขียนไม่ได้ (executor ไม่ให้เขียนนอก workspace) -> คัดลอกโค้ดให้ไปวางเอง
--   2. queue_on_teleport -> ย้ายเซิร์ฟ / rejoin รันเอง (ใช้ได้แม้ข้อ 1 ไม่สำเร็จ)
--   - ค่าเปิด/ปิดเก็บแยกไฟล์ EndHub/autoexec.txt เพราะ config ไม่ได้โหลดเองตอนเปิดสคริปต์
----------------------------------------------------------------
do
    local LOADER_URL = "https://raw.githubusercontent.com/xMidNxtx/test/main/loader.lua"
    local AUTOEXEC_FILE = "EndHub/autoexec.txt"
    local queueTp = queue_on_teleport or queueonteleport
        or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)

    local function readSaved()
        local ok, v = pcall(function()
            return isfile and isfile(AUTOEXEC_FILE) and readfile(AUTOEXEC_FILE)
        end)
        return ok and v == "1"
    end

    local function writeSaved(on)
        pcall(function()
            if makefolder and isfolder and not isfolder("EndHub") then makefolder("EndHub") end
            writefile(AUTOEXEC_FILE, on and "1" or "0")
        end)
    end

    -- โค้ดที่ใช้ทั้งไฟล์ autoexec และ queue_on_teleport
    --   - รันเฉพาะเกมนี้ (autoexec ของ executor รันทุกเกม)
    --   - ปิด toggle แล้ว (autoexec.txt ไม่ใช่ "1") = ไม่รัน ถึงลบไฟล์ autoexec ไม่สำเร็จก็ไม่รัน
    --   - กันรันซ้ำ: autoexec กับ queue ทำงานพร้อมกันหลัง teleport ได้ -> ตัวแรกที่มาถึงรันตัวเดียว
    local AUTO_CODE = table.concat({
        "-- End Hub auto execute (สร้างจาก Settings > Auto Execute ปิด toggle = ลบไฟล์นี้)",
        "if game.GameId ~= " .. tostring(game.GameId) .. " then return end",
        "if not game:IsLoaded() then game.Loaded:Wait() end",
        "local okOn, on = pcall(readfile, \"" .. AUTOEXEC_FILE .. "\")",
        "if not okOn or on ~= \"1\" then return end",
        "local env = (getgenv and getgenv()) or _G",
        "if env.EndHubAutoRan == game.JobId then return end",
        "env.EndHubAutoRan = game.JobId",
        "pcall(function() loadstring(game:HttpGet(\"" .. LOADER_URL .. "\"))() end)",
    }, "\n")

    -------------------- ไฟล์ในโฟลเดอร์ autoexec ของ executor --------------------
    -- โฟลเดอร์ autoexec อยู่ข้างๆ workspace (ชื่อต่างกันแต่ละ executor)
    --   executor ส่วนใหญ่ไม่ให้ writefile ออกนอก workspace -> ลองทีละชื่อ เขียนได้ + อ่านกลับได้ = สำเร็จ
    local AUTOEXEC_PATHS = {
        "../autoexec/EndHub.lua",
        "../Autoexec/EndHub.lua",
        "../autoexecute/EndHub.lua",
        "../Autoexecute/EndHub.lua",
        "../AutoExecute/EndHub.lua",
    }

    local function installAutoexec()
        for _, path in ipairs(AUTOEXEC_PATHS) do
            local ok = pcall(writefile, path, AUTO_CODE)
            local okRead, back = false, nil
            if ok then okRead, back = pcall(readfile, path) end
            if okRead and back == AUTO_CODE then return path end
        end
        return nil
    end

    -- สำเนาใน workspace (เขียนได้ทุก executor): executor ไม่รันไฟล์ใน workspace เอง
    --   แต่ใช้ย้ายไปโฟลเดอร์ autoexec ด้วยตัวจัดการไฟล์ได้ง่าย (มือถือ copy/paste โค้ดลำบาก)
    local WORKSPACE_COPY = "EndHub/EndHub_autoexec.lua"
    local function writeWorkspaceCopy()
        return (pcall(function()
            if makefolder and isfolder and not isfolder("EndHub") then makefolder("EndHub") end
            writefile(WORKSPACE_COPY, AUTO_CODE)
        end))
    end

    local function removeAutoexec()
        for _, path in ipairs(AUTOEXEC_PATHS) do
            pcall(function()
                if isfile(path) then delfile(path) end
            end)
        end
        pcall(function()
            if isfile(WORKSPACE_COPY) then delfile(WORKSPACE_COPY) end
        end)
    end

    local enabled = readSaved()
    if enabled then  -- เขียนทับทุกครั้งที่รัน (โค้ดในไฟล์อัปเดตตามเวอร์ชัน)
        task.spawn(function()
            writeWorkspaceCopy()
            installAutoexec()
        end)
    end

    -------------------- queue_on_teleport (ย้ายเซิร์ฟ / rejoin) --------------------
    local queued = false  -- คิวแล้วรอบนี้ ไม่คิวซ้ำ

    local conn = LP.OnTeleport:Connect(function(state)
        if state ~= Enum.TeleportState.Started then return end
        if not enabled or queued or not queueTp then return end
        queued = pcall(queueTp, AUTO_CODE)
    end)

    -------------------- Anti AFK (Settings > General) --------------------
    -- Roblox เตะคนที่ไม่ขยับ 20 นาที: ตอนเกมบอกว่าเรา idle (LP.Idled) ให้ VirtualUser กดเมาส์ขวา 1 ที
    --   เปิดไว้ตั้งแต่เริ่ม (Default = true) ปิดได้ที่ Settings > General
    local afkConn = nil
    local function setAntiAfk(on)
        if on and not afkConn then
            pcall(function()
                local vu = game:GetService("VirtualUser")
                afkConn = LP.Idled:Connect(function()
                    pcall(function()
                        vu:CaptureController()
                        vu:ClickButton2(Vector2.new())
                    end)
                end)
            end)
        elseif not on and afkConn then
            afkConn:Disconnect()
            afkConn = nil
        end
    end

    function stopAutoExec()
        enabled = false
        conn:Disconnect()
        setAntiAfk(false)  -- กด X ปิด End Hub = เลิกกัน AFK ด้วย
    end

    local generalSection = Settings:AddSection("General")
    generalSection:AddToggle("AntiAfk", {
        Text = "Anti AFK",
        Default = true,
        Callback = function(on) setAntiAfk(on == true) end,
    })
    setAntiAfk(true)  -- เผื่อ toggle ไม่เรียก Callback ตอนสร้าง

    local function killIdleRejoin()
        local ps = LP:FindFirstChild("PlayerScripts")
        local ess = ps and ps:FindFirstChild("Essentials")
        if not ess then return 0 end
        local count = 0
        for _, ch in ess:GetChildren() do
            if ch:IsA("LocalScript") and ch.Name == "IdleRejoin" then
                ch:Destroy()
                count = count + 1
            end
        end
        return count
    end

    local idleWatchConn = nil
    generalSection:AddToggle("BlockIdleRejoin", {
        Text = "Block Idle Rejoin",
        Default = false,
        Callback = function(on)
            if on then
                local n = killIdleRejoin()
                local ps = LP:FindFirstChild("PlayerScripts")
                local ess = ps and ps:FindFirstChild("Essentials")
                if ess and not idleWatchConn then
                    idleWatchConn = ess.ChildAdded:Connect(function(ch)
                        if ch:IsA("LocalScript") and ch.Name == "IdleRejoin" then
                            task.wait()
                            ch:Destroy()
                        end
                    end)
                end
                Velvet:Notify({ Title = "Idle Rejoin", Content = ("ลบ IdleRejoin แล้ว (%d) + เฝ้าไม่ให้กลับมา"):format(n), Duration = 3, Type = "success" })
            else
                if idleWatchConn then
                    idleWatchConn:Disconnect()
                    idleWatchConn = nil
                end
                Velvet:Notify({ Title = "Idle Rejoin", Content = "ปลดบล็อกแล้ว (rejoin เซิร์ฟใหม่จะมี IdleRejoin กลับ)", Duration = 3, Type = "info" })
            end
        end,
    })

    generalSection:AddButton({
        Text = "Disable All Functions",
        Callback = function()
            local n = disableAllFunctions()
            Velvet:Notify({
                Title = "Disable All",
                Content = n > 0 and ("ปิดแล้ว %d ฟังก์ชัน"):format(n) or "ไม่มีฟังก์ชันที่เปิดอยู่",
                Duration = 3, Type = "info",
            })
        end,
    })

    local function autoNote(text, kind, dur)
        Velvet:Notify({ Title = "Auto Execute", Content = text, Duration = dur or 5, Type = kind or "info" })
    end

    local autoExecSection = Settings:AddSection("Auto Execute")
    autoExecSection:AddToggle("AutoExecute", {
        Text = "Auto Execute",
        Default = enabled,
        Callback = function(on)
            on = on and true or false
            local changed = on ~= enabled  -- ตอนสร้าง toggle (ค่าเดิม) ไม่ต้องแจ้งเตือน
            enabled = on
            writeSaved(on)
            if not on then
                removeAutoexec()
                if changed then autoNote("ปิดแล้ว ลบไฟล์ autoexec แล้ว") end
                return
            end
            local wrote = writeWorkspaceCopy()
            local path = installAutoexec()
            if not changed then return end
            if path then
                autoNote(("บันทึกไฟล์ลง %s แล้ว\nเข้าเกมครั้งหน้า End Hub จะรันเอง"):format(path), "success")
            else
                -- เขียนนอก workspace ไม่ได้ -> บอกที่อยู่ไฟล์ใน workspace ให้ย้ายเอง + คัดลอกโค้ดให้
                local copied = pcall(setclipboard, AUTO_CODE)
                local how = wrote
                    and ("บันทึกไว้ที่ workspace/" .. WORKSPACE_COPY .. "\nย้ายไฟล์นี้ไปโฟลเดอร์ autoexec ของ executor")
                    or (copied and "คัดลอกโค้ดแล้ว -> วางเป็นไฟล์ .lua ในโฟลเดอร์ autoexec" or "")
                autoNote(("executor ไม่ให้เขียนลง autoexec ตรงๆ\n%s\nย้ายเซิร์ฟ / rejoin รันเองได้เลย%s"):format(
                    how, queueTp and "" or " (ไม่ได้: ไม่มี queue_on_teleport)"), "info", 10)
            end
        end,
    })
end

----------------------------------------------------------------
-- ADDON: Gem Shop (การ์ดซื้อ potion) + Weblog (ส่งสถานะขึ้นเว็บ)
--   อยู่ในฟังก์ชันของตาราง Addon: local ข้างในไม่นับรวมกับ local ระดับบนสุดของไฟล์
----------------------------------------------------------------

-- state ของเกมแบบสด: ตารางเดียวกับที่ UI ของเกมอ่าน (GameState.Players[UserId].Data.MineGame)
--   อ่านตารางอย่างเดียว ไม่เรียกฟังก์ชันของเกม / หาไม่เจอ -> ใช้ getMineGame() (ดักจาก remote / getgc)
Addon.mineGame = function()
    if Addon.gs == nil then
        Addon.gs = false
        pcall(function() Addon.gs = require(RS:WaitForChild("Modules"):WaitForChild("GameState")) end)
    end
    local mg = nil
    pcall(function()
        local players = type(Addon.gs) == "table" and rawget(Addon.gs, "Players")
        local me = type(players) == "table" and players[tostring(LP.UserId)]
        local data = type(me) == "table" and me.Data
        mg = type(data) == "table" and data.MineGame or nil
    end)
    if type(mg) == "table" then return mg end
    return (getMineGame())
end

----------------------------------------------------------------
-- GEM SHOP (แท็บ Gem Shop)
-- remote: Event:FireServer("MineGemShopBuy", itemName)   (เกมเรียก GameState.SendEvent("MineGemShopBuy", row.Item))
--
--   1. ของที่ขาย = MineGemsConfig.Shop เฉพาะแถวที่เป็น potion (มีใน MinePotionCatalog -> ได้รูป + คำอธิบาย)
--   2. กดปุ่ม "Gem Shop Config" -> หน้าต่างการ์ด: กดการ์ด = เลือก (มีเลขลำดับ) กดซ้ำ = เอาออก
--   3. Auto Buy Potion: ไล่ตามลำดับที่เลือก ซื้อทีละ 1 ขวด เมื่อ
--        - ในกระเป๋ามีน้อยกว่า "Max Each"
--        - ซื้อแล้ว gem ยังเหลือไม่ต่ำกว่า "Keep Gems"
--        - zone ที่ต้องใช้ (MinZone) ปลดล็อคแล้ว
--      ไม่ได้เลือกการ์ด = ไม่ซื้ออะไรเลย (potion ใช้แล้วหมด ไม่เดาแทนผู้ใช้)
--   4. กันเผา gem: ยิงซื้อแล้วรอดู gem ลด / จำนวนเพิ่ม 2 วิ ไม่เปลี่ยน 3 ครั้งติด = หยุด Auto Buy เอง
--      อ่าน gem / จำนวน potion ไม่ได้ = ไม่ซื้อ
--   5. ลำดับที่เลือกเซฟลง EndHubData/gemshop_buy.json
----------------------------------------------------------------
Addon.gemShop = function()
    local section = Addon.gemTab:AddSection("Gem Shop")
    local FILE = "EndHubData/gemshop_buy.json"
    local GUI_NAME = "EndHub_GemShop"

    -------------------- ข้อมูลของที่ขาย --------------------
    local potionDef = {}
    pcall(function()
        local cat = require(RS:WaitForChild("Modules"):WaitForChild("MinePotionCatalog"))
        for _, p in ipairs(type(cat.Potions) == "table" and cat.Potions or {}) do
            if type(p) == "table" and type(p.ItemName) == "string" then potionDef[p.ItemName] = p end
        end
    end)
    local items, byName = {}, {}
    pcall(function()
        local cfg = require(RS:WaitForChild("Modules"):WaitForChild("MineGemsConfig"))
        for i, row in ipairs(type(cfg.Shop) == "table" and cfg.Shop or {}) do
            local def = type(row) == "table" and potionDef[row.Item] or nil
            if def and not byName[row.Item] then
                local img = tostring(def.ImageId or "")
                local item = {
                    name = row.Item,
                    price = math.max(1, math.floor(tonumber(row.Price) or 1)),
                    minZone = tonumber(row.MinZone),
                    image = (img ~= "" and img ~= "0") and img or nil,
                    effect = tostring(def.EffectText or ""),
                    order = i,
                }
                table.insert(items, item)
                byName[item.name] = item
            end
        end
    end)
    table.sort(items, function(a, b)
        if a.price == b.price then return a.order < b.order end
        return a.price < b.price
    end)

    -------------------- ลำดับที่เลือก --------------------
    local picks = {}
    local function savePicks()
        Velvet.Flags["GemShopOrder"] = table.clone(picks)
        pcall(function()
            if not isfolder("EndHubData") then makefolder("EndHubData") end
            writefile(FILE, HttpService:JSONEncode({ order = picks }))
        end)
    end
    pcall(function()
        if not isfile(FILE) then return end
        local data = HttpService:JSONDecode(readfile(FILE))
        for _, name in ipairs(type(data) == "table" and type(data.order) == "table" and data.order or {}) do
            if byName[name] and not table.find(picks, name) then table.insert(picks, name) end
        end
    end)
    Velvet.Flags["GemShopOrder"] = table.clone(picks)

    -------------------- อ่าน state --------------------
    local function gemCount()
        local mg = Addon.mineGame()
        return mg and tonumber(mg.Gems) or nil
    end
    -- จำนวนในกระเป๋า (อ่าน state ไม่ได้ = nil)
    local function owned(name)
        local mg = Addon.mineGame()
        local p = mg and mg.Potions
        if type(p) ~= "table" then return nil end
        return tonumber(p[name]) or 0
    end
    -- zone ที่ต้องใช้ยังไม่ปลดล็อค (ยังไม่รู้ zone = ไม่ล็อค ให้ server ตัดสิน)
    local function locked(item)
        if not item.minZone or not deepestUnlockedZoneNum then return false end
        local ok, d = pcall(deepestUnlockedZoneNum)
        d = ok and tonumber(d) or nil
        return d ~= nil and d < item.minZone
    end

    -------------------- Auto Buy --------------------
    local lastNote = nil
    local function note(key, text, kind)
        if key == lastNote then return end
        lastNote = key
        Velvet:Notify({ Title = "Gem Shop", Content = text, Duration = 5, Type = kind or "info" })
    end

    local on, misses = false, 0
    local setAuto  -- กำหนดข้างล่าง (ต้องใช้ start/stop)

    local function buyPass(alive)
        local gems = gemCount()
        if not gems then return note("nodata", "ยังอ่านจำนวน gem ไม่ได้ รอข้อมูลจากเกม") end
        if #picks == 0 then return note("nopick", "ยังไม่ได้เลือก potion (กด Gem Shop Config แล้วเลือกการ์ด)") end
        local keep = math.max(0, tonumber(Velvet.Flags["GemShopKeep"]) or 0)
        local cap = flag("GemShopMax", 10)
        for _, name in ipairs(picks) do
            if alive and not alive() then return end
            local item = byName[name]
            local have = owned(name)
            if item and have and have < cap and not locked(item) and gems - item.price >= keep then
                fire("MineGemShopBuy", name)
                -- รอผล: gem ลด หรือ จำนวนเพิ่ม
                local t0, changed = os.clock(), false
                while os.clock() - t0 < 2 do
                    task.wait(0.15)
                    local g2 = gemCount()
                    if (g2 and g2 < gems) or (owned(name) or have) > have then changed = true; break end
                end
                if changed then
                    misses = 0
                    lastNote = nil
                    if Addon.emit then Addon.emit("potion", "ซื้อ " .. name .. " จาก Gem Shop") end
                    gems = gemCount() or (gems - item.price)
                else
                    misses += 1
                    if misses >= 3 then
                        note("stuck", ("ยิงซื้อ %s แล้วไม่เห็นผล 3 ครั้ง หยุด Auto Buy (ของอาจยังไม่เปิดขาย / ข้อมูลไม่อัปเดต)"):format(name), "error")
                        task.defer(setAuto, false)
                        return
                    end
                end
            end
        end
    end

    local start, stop = makeLoop(buyPass, function() return flag("GemShopInterval", 5) end)

    local autoToggle, autoBtn, refreshGui = nil, nil, nil
    local function paintBtn()
        if not autoBtn then return end
        autoBtn.Text = on and "Auto Buy: ON" or "Auto Buy: OFF"
        autoBtn.BackgroundColor3 = on and C.picked or C.card
        autoBtn.TextColor3 = on and C.bg or C.text
    end
    local function apply(v)
        on = v == true
        misses, lastNote = 0, nil
        if on then start() else stop() end
        paintBtn()
    end
    setAuto = function(v)
        local elem = autoToggle
        if not (type(elem) == "table" and elem.Set) then
            elem = Velvet._elements and Velvet._elements["AutoBuyGemShop"]
        end
        if type(elem) == "table" and elem.Set then pcall(function() elem:Set(v) end) end
        apply(v)
    end

    -------------------- หน้าต่างการ์ด --------------------
    local W, H, CW, CH = 660, 470, 148, 176
    local function build()
        local parent = getGuiParent()
        pcall(function()
            local old = parent:FindFirstChild(GUI_NAME)
            if old then old:Destroy() end
        end)
        local gui = make("ScreenGui", {
            Name = GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true,
            DisplayOrder = 2147483647, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        }, nil)
        if not pcall(function() gui.Parent = parent end) then gui.Parent = LP:WaitForChild("PlayerGui") end

        local win = make("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(W, H), BackgroundColor3 = C.bg, Active = true,
        }, gui)
        round(win, 12)
        outline(win)
        local scale = make("UIScale", {}, win)
        local cam = workspace.CurrentCamera
        local function fit()
            local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
            scale.Scale = math.clamp(math.min((vp.X - 24) / W, (vp.Y - 24) / H), 0.5, 1)
        end
        fit()
        local conns = {}
        if cam then table.insert(conns, cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)) end

        -- หัวหน้าต่าง (ลากได้)
        local dragArea = make("Frame", { Size = UDim2.new(1, -300, 0, 56), BackgroundTransparency = 1 }, win)
        makeLogo(win, 24, 2).Position = UDim2.fromOffset(16, 16)
        label(win, "End Hub", { Position = UDim2.fromOffset(48, 11), Size = UDim2.fromOffset(120, 20), Font = Enum.Font.GothamBold, TextSize = 17 })
        local gemLabel = label(win, "Gem Shop", { Position = UDim2.fromOffset(48, 31), Size = UDim2.fromOffset(260, 16), TextSize = 12, TextColor3 = C.sub })

        local closeBtn = make("TextButton", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 15), Size = UDim2.fromOffset(24, 24),
            AutoButtonColor = false, BackgroundColor3 = C.close, Text = "X",
            Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.picked,
        }, win)
        round(closeBtn, 6)
        closeBtn.MouseEnter:Connect(function() closeBtn.BackgroundColor3 = C.closeHover end)
        closeBtn.MouseLeave:Connect(function() closeBtn.BackgroundColor3 = C.close end)
        local btnAuto = button(win, "Auto Buy: OFF", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -48, 0, 12), Size = UDim2.fromOffset(110, 30) })
        local btnClear = button(win, "Clear", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -166, 0, 12), Size = UDim2.fromOffset(64, 30) })

        make("Frame", { Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 1), BackgroundColor3 = C.line, BorderSizePixel = 0 }, win)
        local hint = label(win, "", {
            Position = UDim2.fromOffset(16, 62), Size = UDim2.new(1, -32, 0, 18), TextSize = 12, TextColor3 = C.sub,
        })

        local grid = make("ScrollingFrame", {
            Position = UDim2.fromOffset(12, 86), Size = UDim2.new(1, -20, 1, -98),
            BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = C.stroke,
        }, win)
        make("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }, grid)
        make("UIGridLayout", {
            CellSize = UDim2.fromOffset(CW, CH), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
        }, grid)

        local cards = {}
        local refresh
        for i, item in ipairs(items) do
            local card = make("TextButton", { LayoutOrder = i, AutoButtonColor = false, Text = "", BackgroundColor3 = C.card }, grid)
            round(card, 10)
            local stroke = outline(card)
            local badge = make("Frame", {
                AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(20, 20),
                BackgroundColor3 = C.picked, Visible = false,
            }, card)
            round(badge, 10)
            local badgeText = label(badge, "", {
                Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
                Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.bg,
            })
            local ownLabel = label(card, "", { Position = UDim2.fromOffset(9, 7), Size = UDim2.fromOffset(70, 14), TextSize = 11, TextColor3 = C.dim, Font = Enum.Font.GothamMedium })
            if item.image then
                make("ImageLabel", {
                    AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.fromOffset(58, 58),
                    BackgroundTransparency = 1, Image = "rbxassetid://" .. item.image, ScaleType = Enum.ScaleType.Fit,
                }, card)
            end
            local nameLabel = label(card, item.name, {
                Position = UDim2.new(0, 6, 0, 88), Size = UDim2.new(1, -12, 0, 16),
                TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, TextScaled = true,
            })
            make("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, nameLabel)
            label(card, item.effect, {
                Position = UDim2.new(0, 6, 0, 106), Size = UDim2.new(1, -12, 0, 28),
                TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
                TextSize = 11, TextColor3 = C.sub, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
            })
            local priceLabel = label(card, short(item.price) .. " gems", {
                Position = UDim2.new(0, 6, 0, 148), Size = UDim2.new(1, -12, 0, 16),
                TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.accent,
            })
            local lock = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BackgroundTransparency = 0.25, Visible = false, ZIndex = 5 }, card)
            round(lock, 10)
            label(lock, "LOCKED", {
                Position = UDim2.new(0, 6, 0.5, -18), Size = UDim2.new(1, -12, 0, 18), TextXAlignment = Enum.TextXAlignment.Center,
                Font = Enum.Font.GothamBold, TextSize = 14, ZIndex = 6,
            })
            label(lock, "Unlock Z" .. tostring(item.minZone or "?") .. " first", {
                Position = UDim2.new(0, 6, 0.5, 2), Size = UDim2.new(1, -12, 0, 14), TextXAlignment = Enum.TextXAlignment.Center,
                TextSize = 11, TextColor3 = C.sub, ZIndex = 6,
            })
            local entry = { stroke = stroke, badge = badge, badgeText = badgeText, own = ownLabel, price = priceLabel, lock = lock, locked = false }
            cards[item.name] = entry
            card.MouseButton1Click:Connect(function()
                local at = table.find(picks, item.name)
                if at then
                    table.remove(picks, at)
                elseif entry.locked then
                    Velvet:Notify({ Title = "Gem Shop", Content = ("%s ต้องปลดล็อค Z%s ก่อน"):format(item.name, tostring(item.minZone)), Duration = 3, Type = "error" })
                    return
                else
                    table.insert(picks, item.name)
                end
                savePicks()
                refresh()
            end)
            card.MouseEnter:Connect(function() card.BackgroundColor3 = C.hover end)
            card.MouseLeave:Connect(function() card.BackgroundColor3 = C.card end)
        end

        refresh = function()
            local gems = gemCount()
            gemLabel.Text = "Gem Shop · " .. (gems and (short(gems) .. " gems") or "รอข้อมูล gem")
            local keep = math.max(0, tonumber(Velvet.Flags["GemShopKeep"]) or 0)
            hint.Text = #items == 0 and "อ่านรายการ Gem Shop ของเกมไม่ได้"
                or ("Picked %d · ซื้อจนมีอย่างละ %d · เก็บ gem ไว้ %s"):format(#picks, flag("GemShopMax", 10), short(keep))
            for _, item in ipairs(items) do
                local c = cards[item.name]
                local n = table.find(picks, item.name)
                local have = owned(item.name)
                c.locked = locked(item)
                c.lock.Visible = c.locked
                c.badge.Visible = n ~= nil
                c.badgeText.Text = n and tostring(n) or ""
                c.stroke.Color = n and C.picked or C.stroke
                c.stroke.Thickness = n and 1.5 or 1
                c.own.Text = have and ("x" .. short(have)) or ""
                c.price.TextColor3 = (gems and gems - item.price < keep) and C.dim or C.accent  -- จาง = ตอนนี้ซื้อไม่ได้
            end
        end
        refreshGui = refresh

        closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)
        btnClear.MouseButton1Click:Connect(function()
            table.clear(picks)
            savePicks()
            refresh()
        end)
        btnAuto.MouseButton1Click:Connect(function() setAuto(not on) end)
        autoBtn = btnAuto
        paintBtn()

        local dragging, dragStart, startPos = false, nil, nil
        dragArea.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging, dragStart, startPos = true, input.Position, win.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        table.insert(conns, UIS.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end))
        gui.Destroying:Connect(function()
            for _, c in ipairs(conns) do c:Disconnect() end
            if autoBtn == btnAuto then autoBtn = nil end
            if refreshGui == refresh then refreshGui = nil end
        end)

        refresh()
        task.spawn(function()  -- เปิดค้างไว้: อัปเดต gem / จำนวน / ล็อค ทุก 2 วิ
            while gui.Parent do
                task.wait(2)
                if gui.Enabled and gui.Parent then pcall(refresh) end
            end
        end)
        return gui
    end

    local function toggleGui()
        local gui = Addon.gemGui
        if gui and gui.Parent then
            gui.Enabled = not gui.Enabled
            if gui.Enabled and refreshGui then pcall(refreshGui) end
            return
        end
        local ok, result = pcall(build)
        if ok then
            Addon.gemGui = result
        else
            warn("[End Hub] Gem Shop error:", result)
            Velvet:Notify({ Title = "Gem Shop", Content = "เปิดหน้าต่างไม่ได้: " .. tostring(result), Duration = 6, Type = "error" })
        end
    end

    -------------------- ปุ่มใน Velvet --------------------
    accentButton(section:AddButton({ Text = "Gem Shop Config", Callback = toggleGui }))
    autoToggle = section:AddToggle("AutoBuyGemShop", {
        Text = "Auto Buy Potion",
        Default = false,
        Callback = apply,
    })
    section:AddSlider("GemShopMax", {
        Text = "Max Each",
        Min = 1, Max = 100, Default = 10, Increment = 1,
        VisibleWhen = "AutoBuyGemShop",
    })
    section:AddInput("GemShopKeep", {
        Text = "Keep Gems",
        Placeholder = "0",
    })
    section:AddSlider("GemShopInterval", {
        Text = "Buy Interval",
        Min = 2, Max = 120, Default = 5, Increment = 1,
        Suffix = "s",
        VisibleWhen = "AutoBuyGemShop",
    })

    Addon.stopGemShop = function()
        stop()
        if Addon.gemGui then
            Addon.gemGui:Destroy()
            Addon.gemGui = nil
        end
    end
end
Addon.gemShop()

----------------------------------------------------------------
-- WEBLOG (Settings > Weblog)
--   ส่งสถานะของไอดีนี้ขึ้น Worker -> ดูรวมทุกไอดีได้ที่ <API_URL>/weblog/
--   ทางหลัก WebSocket (wss://.../ws/game): ส่งทุก ~15 วิ หน้าเว็บเห็นสดทันที
--     executor ต้องมี WebSocket.connect (หรือ syn.websocket.connect)
--   ทางสำรอง HTTP (POST /log): executor ไม่มี WebSocket / ต่อไม่ได้ 3 ครั้งติด -> ส่งทุก ~60 วิ
--     (ใช้ HTTP แล้วจะลองกลับไป WebSocket ใหม่ทุก 10 นาที)
--   ใช้คีย์ที่ loader จำไว้ (EndHub_key.txt) + รหัสเครื่อง ตัวเดียวกับที่ใช้ตรวจคีย์
--   ส่งเฉพาะข้อมูลในเกม (zone / research / เงิน / gem / scroll / พลัง / miner / potion) + ชื่อไอดี
--   เหตุการณ์ (live feed): Addon.emit(kind, text) จากส่วนอื่นของสคริปต์ เข้าคิวแล้วส่งรอบถัดไป
--     kind: zone / research / goal / milestone / mail / spin / potion
--   Worker ยังไม่เปิด Weblog / ต่อไม่ได้ -> ลองใหม่ทุก 10 นาที ไม่รบกวนการฟาร์ม
----------------------------------------------------------------
-- คิวเหตุการณ์: ส่วนอื่นเรียกได้ตลอด (ก่อน Weblog พร้อมก็เข้าคิวไว้)
Addon.events = {}
-- ตัดข้อความไม่เกิน n ไบต์ โดยไม่ตัดกลางตัวอักษร (ภาษาไทย 1 ตัว = 3 ไบต์ ตัดกลางตัว = JSON พัง)
Addon.cut = function(text, n)
    if #text <= n then return text end
    text = text:sub(1, n)
    while #text > 0 and not utf8.len(text) do text = text:sub(1, -2) end
    return text
end
Addon.emit = function(kind, text)
    if type(kind) ~= "string" or type(text) ~= "string" or text == "" then return end
    if #Addon.events >= 30 then table.remove(Addon.events, 1) end
    -- เว็บเก็บไม่เกิน 140 ตัวอักษร (ไทยล้วน 140 ตัว = 420 ไบต์)
    table.insert(Addon.events, { kind = kind, text = Addon.cut(text, 420) })
end

Addon.weblog = function()
    local API_URL = "https://endhub.kantapongboontawin1.workers.dev"
    local KEY_FILE = "EndHub_key.txt"
    local section = Settings:AddSection("Weblog")
    local para = section:AddParagraph({ Title = "สถานะ", Content = "รอส่งครั้งแรก..." })
    local httpRequest = request or http_request or (syn and syn.request) or (http and http.request)

    local startedAt = os.clock()
    local waitSecs = 60
    local lastCash, lastT, income = nil, nil, 0

    local function finite(v)
        v = tonumber(v)
        if v == nil or v ~= v or v == math.huge or v == -math.huge then return nil end
        return v
    end

    local function readKey()
        local ok, key = pcall(function() return isfile(KEY_FILE) and readfile(KEY_FILE) or nil end)
        key = ok and type(key) == "string" and key:gsub("%s", "") or ""
        return key ~= "" and key or nil
    end
    local hwid = nil
    local function readHwid()
        if hwid then return hwid end
        local ok, id = pcall(function() return gethwid and gethwid() end)
        if ok and type(id) == "string" and id ~= "" then hwid = id end
        if not hwid then
            ok, id = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
            if ok and type(id) == "string" and id ~= "" then hwid = id end
        end
        return hwid
    end

    -- toggle ฟาร์มที่เปิดอยู่ (ไว้บอกว่าไอดีนี้ทำอะไรตอนไม่ได้เปิด Kaitun)
    local FARM = {
        AutoSmartEquip = "Equip", AutoTakeChest = "Chest", AutoSellOres = "Sell", AutoBuyPickaxe = "Pickaxe",
        Buy_Skill = "Research", AutoUnlockZone = "Zone", AutoUpgradePlot = "Upgrade", AutoBuyMinerSlot = "Slot",
        AutoTutorial = "Tap", AutoBuyGemShop = "Potion", AutoClaimMail = "Mail", AutoClaimMilestone = "Milestone",
        AutoClaimIndex = "Index", AutoSellChars = "SellChar", AutoUsePotion = "UsePotion",
        AutoDailyTrial = "Trial", AutoDice = "Dice",
    }

    local function collect()
        local mg = Addon.mineGame()
        local cash = finite((getCash()))
        local now = os.clock()
        -- เงินเพิ่มต่อวินาที (ไม่นับช่วงที่เงินลดเพราะซื้อของ = ค่าประมาณขั้นต่ำ)
        if cash and lastCash and lastT and now > lastT then
            local rate = math.max(0, cash - lastCash) / (now - lastT)
            income = income == 0 and rate or (income * 0.7 + rate * 0.3)
        end
        lastCash, lastT = cash, now

        local deep = nil
        if deepestUnlockedZoneNum then
            local okD, d = pcall(deepestUnlockedZoneNum)
            if okD then deep = tonumber(d) end
        end
        if not deep then
            local plot = getMyPlot()
            deep = plot and tonumber(tostring(readValue(plot, "ZoneKey") or ""):match("(%d+)")) or nil
        end
        local zoneKey = deep and ("Z" .. deep) or nil
        local zoneName = nil
        pcall(function() zoneName = MineConfig.Zones[zoneKey].DisplayName end)

        local done, total = nil, nil
        if zoneKey and mg and type(MineConfig.GetZoneResearchProgress) == "function" then
            local okP, a, b = isolated(function() return MineConfig.GetZoneResearchProgress(mg.Skills, zoneKey) end)
            if okP then done, total = finite(a), finite(b) end
        end

        local doing = Kaitun.on and Kaitun.doing or nil
        if not doing then
            local names = {}
            for id, text in pairs(FARM) do
                if Velvet.Flags[id] == true then table.insert(names, text) end
            end
            table.sort(names)
            doing = #names > 0 and table.concat(names, ", ") or "ไม่ได้เปิดฟังก์ชัน"
        end

        -- zone ใหม่ / research ครบ -> live feed (ครั้งแรกแค่จำค่าไว้)
        local zName = type(zoneName) == "string" and zoneName or nil
        if deep then
            if Addon.lastZone and deep > Addon.lastZone then
                Addon.emit("zone", ("ปลดล็อค Z%d%s"):format(deep, zName and (" " .. zName) or ""))
            end
            Addon.lastZone = math.max(Addon.lastZone or 0, deep)
        end
        if zoneKey and done and total and total > 0 then
            local full = done >= total
            if full and Addon.researchZone == zoneKey and Addon.researchFull == false then
                Addon.emit("research", ("research %s ครบ (%d/%d)"):format(zoneKey, done, total))
            end
            Addon.researchZone, Addon.researchFull = zoneKey, full
        end

        local snap = {
            zone = deep, zoneName = zName,
            rDone = done, rTotal = total,
            cash = cash, income = finite(income),
            gems = mg and finite(mg.Gems), scrolls = mg and finite(mg.SummonScrolls), dice = mg and finite(mg.EnchantDice),
            power = finite(LP:GetAttribute("MinePower")),
            goal = Kaitun.on and Kaitun.goalText or nil,
            doing = doing,
            kaitun = Kaitun.on == true, reached = Kaitun.on == true and Kaitun.reached == true,
            display = LP.DisplayName, ver = VERSION, up = math.floor(now - startedAt),
            -- Auto Trade: เว็บใช้เลือกตัวรับ / ตัวส่ง
            job = game.JobId, place = game.PlaceId,
            zoneMax = #(type(MineConfig.ZoneKeys) == "table" and MineConfig.ZoneKeys or {}),
            canTrade = Addon.canTrade and Addon.canTrade(mg) or nil,
        }

        local miners = {}
        if mg then
            local enchants = type(mg.Enchants) == "table" and mg.Enchants or {}
            for pad, h in pairs(type(mg.Holders) == "table" and mg.Holders or {}) do
                if type(h) == "table" and type(h.CharName) == "string" and h.CharName ~= "" then
                    -- รูปตัวละคร: ImageId จาก MineCharacterCatalog (เว็บแปลงเป็นรูปผ่าน /img/<id>)
                    local img = nil
                    pcall(function()
                        local def = getCharDef(h.CharName)
                        if not def and type(h.CharVariant) == "string" then
                            def = getCharDef((h.CharName:gsub("^" .. h.CharVariant:gsub("%p", "%%%0") .. " ", "")))
                        end
                        img = def and tostring(def.ImageId or ""):match("(%d+)") or nil
                    end)
                    table.insert(miners, {
                        img = img,
                        pad = tostring(pad), name = h.CharName,
                        lv = finite(h.CharLevel), spd = finite(h.CharSpeedLevel), mspd = finite(h.CharMineSpeedLevel),
                        variant = type(h.CharVariant) == "string" and h.CharVariant or nil,
                        enchant = type(enchants[pad]) == "string" and enchants[pad] or nil,
                    })
                end
            end
            table.sort(miners, function(a, b)
                return (tonumber(a.pad:match("%d+")) or 0) < (tonumber(b.pad:match("%d+")) or 0)
            end)
        end
        local bag = nil
        if Addon.tradeBag and snap.canTrade == true then pcall(function() bag = Addon.tradeBag() end) end
        return snap, { miners = miners, bag = bag }
    end

    local STOP_TEXT = {
        invalid_key = "คีย์ไม่ถูกต้อง", hwid_mismatch = "คีย์นี้ผูกกับเครื่องอื่น", expired = "คีย์หมดอายุแล้ว",
    }
    local stopLoop = nil
    local function stopFor(code)
        para:Set("หยุดส่ง: " .. STOP_TEXT[code])
        if stopLoop then stopLoop() end
    end

    -------------------- WebSocket --------------------
    local wsConnect = (WebSocket and WebSocket.connect) or (syn and syn.websocket and syn.websocket.connect) or nil
    local WS_URL = API_URL:gsub("^http", "ws") .. "/ws/game"
    local sock, sockReady, sockInterval = nil, false, 15
    local wsFails, wsRetryAt = 0, 0

    local function closeSock()
        local s = sock
        sock, sockReady = nil, false
        if s then pcall(function() s:Close() end) end
    end
    local function sockSend(tbl)
        if not sock then return false end
        local ok = pcall(function() sock:Send(HttpService:JSONEncode(tbl)) end)
        if not ok then closeSock() end
        return ok
    end

    -- ต่อ + hello -> true / false, error
    local function openSock(key, id)
        local okC, s = pcall(wsConnect, WS_URL)
        if not okC or not s then return false, "connect" end
        local reply = nil
        pcall(function()
            s.OnMessage:Connect(function(msg)
                local okJ, d = pcall(HttpService.JSONDecode, HttpService, msg)
                if not okJ or type(d) ~= "table" then return end
                if d.t == "ok" then
                    sockInterval = math.clamp(tonumber(d.interval) or 15, 5, 120)
                    reply = "ok"
                elseif d.t == "err" then
                    reply = tostring(d.error)
                elseif d.t == "cmd" and Addon.onCmd then
                    task.spawn(Addon.onCmd, d)  -- คำสั่งจากหน้าเว็บ (Auto Trade)
                end
            end)
        end)
        pcall(function()
            s.OnClose:Connect(function()
                if sock == s then sock, sockReady = nil, false end
            end)
        end)
        sock = s
        if not sockSend({ t = "hello", key = key, hwid = id, uid = tostring(LP.UserId), user = LP.Name }) then
            return false, "send"
        end
        local t0 = os.clock()
        while reply == nil and os.clock() - t0 < 8 do task.wait(0.1) end
        if reply == "ok" then
            sockReady = true
            return true
        end
        closeSock()
        return false, reply or "timeout"
    end

    local function takeEvents()
        local list = Addon.events
        Addon.events = {}
        return list
    end

    -------------------- HTTP (สำรอง) --------------------
    local function sendHttp(key, id, snap, detail, events)
        if not httpRequest then return false, "no_request" end
        local ok, res = pcall(httpRequest, {
            Url = API_URL .. "/log",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                key = key, hwid = id, uid = tostring(LP.UserId), user = LP.Name,
                snap = snap, detail = detail, events = events,
            }),
        })
        local data = nil
        if ok and type(res) == "table" then
            local okJ, d = pcall(HttpService.JSONDecode, HttpService, res.Body)
            data = okJ and type(d) == "table" and d or nil
        end
        if data and data.ok then return true, math.clamp(tonumber(data.next) or 60, 30, 600) end
        return false, data and tostring(data.error) or "network"
    end

    local function send()
        local key, id = readKey(), readHwid()
        if not key then waitSecs = 600; return para:Set("ไม่เจอคีย์ที่บันทึกไว้ (รันผ่าน loader ก่อน)") end
        if not id then waitSecs = 600; return para:Set("อ่านรหัสเครื่องไม่ได้") end

        -- WebSocket: ยังไม่ต่อ -> ลองต่อ (พลาด 3 ครั้งติด = ใช้ HTTP 10 นาทีแล้วค่อยลองใหม่)
        if wsConnect and not sockReady and os.clock() >= wsRetryAt then
            local ok, err = openSock(key, id)
            if ok then
                wsFails = 0
            elseif STOP_TEXT[err] then
                return stopFor(err)
            else
                wsFails += 1
                if wsFails >= 3 then wsFails, wsRetryAt = 0, os.clock() + 600 end
            end
        end

        local snap, detail = collect()
        if sockReady then
            local events = takeEvents()
            local sent = sockSend({ t = "status", snap = snap, detail = detail })
            for _, e in ipairs(events) do
                if sent then sent = sockSend({ t = "event", kind = e.kind, text = e.text }) end
            end
            if sent then
                waitSecs = sockInterval
                return para:Set(("ส่งสดผ่าน WebSocket · ล่าสุด %s"):format(os.date("%H:%M:%S")))
            end
            for _, e in ipairs(events) do Addon.emit(e.kind, e.text) end  -- ส่งไม่ออก -> คืนคิว
        end

        -- HTTP
        local events = takeEvents()
        local ok, res = sendHttp(key, id, snap, detail, events)
        if ok then
            waitSecs = res
            return para:Set(("ส่งผ่าน HTTP ทุก %d วิ · ล่าสุด %s%s"):format(res, os.date("%H:%M:%S"),
                wsConnect and "" or " (executor นี้ไม่มี WebSocket)"))
        end
        for _, e in ipairs(events) do Addon.emit(e.kind, e.text) end
        if STOP_TEXT[res] then return stopFor(res) end
        waitSecs = 600  -- Worker ยังไม่เปิด Weblog / ต่อไม่ได้ -> ลองใหม่อีก 10 นาที
        para:Set(res == "logs_not_configured" and "เซิร์ฟเวอร์ยังไม่เปิด Weblog (ลองใหม่ทุก 10 นาที)"
            or res == "no_request" and "executor นี้ไม่รองรับทั้ง WebSocket และ request()"
            or ("ส่งไม่ได้ (" .. res .. ") ลองใหม่ทุก 10 นาที"))
    end

    -------------------- รอบก่อนออกจากเซิร์ฟเพราะอะไร --------------------
    -- ไฟล์แยกต่อไอดี (หลายจอใช้โฟลเดอร์ workspace เดียวกัน): EndHub/session_<UserId>.json
    --   ทุก 60 วิ จดเวลาล่าสุด + JobId / หลุด-โดนเตะ (หน้าต่าง error ของ Roblox) จดข้อความ + ส่งเว็บทันทีถ้ายังต่ออยู่
    --   วาปออก (OnTeleport) จด "ย้ายเซิร์ฟ" / เข้าเกมรอบหน้า: แจ้งเว็บว่ารอบก่อนจบเพราะอะไร อยู่ได้กี่นาที
    --   ไม่มีข้อความ error = หน้าต่างถูกปิด / crash / ตัวเปิดเกม (เช่น Auto Join) สั่งปิด
    do
        local GuiService = game:GetService("GuiService")
        local FILE = ("EndHub/session_%d.json"):format(LP.UserId)
        local startAt = os.time()
        local why, whyAt, sentLive = nil, 0, false
        local function mins(sec)
            local m = math.max(0, math.floor((tonumber(sec) or 0) / 60))
            return m >= 60 and ("%d ชม. %d นาที"):format(m // 60, m % 60) or (m .. " นาที")
        end
        local function save()
            pcall(function()
                if not isfolder("EndHub") then makefolder("EndHub") end
                writefile(FILE, HttpService:JSONEncode({
                    job = game.JobId, start = startAt, at = os.time(), why = why, sent = sentLive or nil,
                }))
            end)
        end

        -- รอบก่อน (อ่านก่อนเขียนทับ) / JobId เดิม + ไม่มีเหตุผล = รันสคริปต์ซ้ำในเซิร์ฟเดิม ไม่ใช่เข้าใหม่
        local okP, prev = pcall(function()
            return isfile(FILE) and HttpService:JSONDecode(readfile(FILE)) or nil
        end)
        if okP and type(prev) == "table" and tonumber(prev.at) and os.time() - prev.at < 6 * 3600
            and not prev.sent and (prev.job ~= game.JobId or prev.why) then
            local reason = type(prev.why) == "string" and prev.why
                or "เกมปิดไปเฉยๆ ไม่มีข้อความหลุด (ปิดหน้าต่าง / crash / ตัวเปิดเกมสั่งปิด)"
            Addon.emit("online", ("เข้าใหม่ · รอบก่อน: %s · อยู่ได้ %s · หายไป %s"):format(
                reason, mins(prev.at - (tonumber(prev.start) or prev.at)), mins(os.time() - prev.at)))
        end
        save()

        local function replicated()
            local ok, has = pcall(function()
                local nc = game:FindService("NetworkClient")
                return nc ~= nil and nc:FindFirstChildOfClass("ClientReplicator") ~= nil
            end)
            if not ok then return nil end
            return has
        end
        local function mark(text)
            if why then return end
            why, whyAt = Addon.cut(text, 200), os.clock()
            save()
            if sockReady and sockSend({ t = "event", kind = "info",
                text = Addon.cut(("หลุดจากเซิร์ฟ: %s · อยู่ได้ %s"):format(why, mins(os.time() - startAt)), 420) }) then
                sentLive = true
                save()
            end
        end
        pcall(function()
            GuiService.ErrorMessageChanged:Connect(function(msg)
                if type(msg) ~= "string" or msg == "" then
                    pcall(function() msg = GuiService:GetErrorMessage() end)
                end
                if type(msg) ~= "string" or msg == "" then return end
                local code = ""
                pcall(function() code = " [" .. GuiService:GetErrorCode().Name .. "]" end)
                mark(msg:gsub("%s+", " ") .. code)
            end)
        end)
        pcall(function()
            LP.OnTeleport:Connect(function(state)
                if state == Enum.TeleportState.Started then
                    mark("ย้ายเซิร์ฟ (teleport)")
                elseif state == Enum.TeleportState.Failed and why == "ย้ายเซิร์ฟ (teleport)" then
                    why, sentLive = nil, false
                    save()
                end
            end)
        end)
        -- จดทุก 60 วิ / ข้อความ error ขึ้นแต่ผ่านไป 60 วิแล้วยังต่อกับเซิร์ฟอยู่ = ไม่ได้หลุดจริง ล้างทิ้ง
        task.spawn(function()
            while Addon.sessionOn ~= false do
                task.wait(60)
                if why and os.clock() - whyAt > 60 and replicated() == true then
                    why, sentLive = nil, false
                end
                save()
            end
        end)
    end

    local start, stopRaw = makeLoop(send, function() return waitSecs end)
    local function stop()
        stopRaw()
        closeSock()
    end
    stopLoop = stop

    section:AddToggle("WeblogOn", {
        Text = "Send status to Weblog",
        Default = true,
        Callback = function(v)
            if v then
                waitSecs = 60
                start()
            else
                stop()
                para:Set("ปิดอยู่")
            end
        end,
    })
    section:AddButton({
        Text = "Copy Weblog Link",
        Callback = function()
            local ok = pcall(function() setclipboard(API_URL .. "/weblog/") end)
            Velvet:Notify({
                Title = "Weblog", Duration = 4, Type = ok and "success" or "info",
                Content = ok and "ก๊อปลิงก์แล้ว เปิดในเบราว์เซอร์แล้วใส่คีย์" or (API_URL .. "/weblog/"),
            })
        end,
    })
    -- เผื่อ toggle ไม่เรียก Callback ตอนสร้าง (start กดซ้ำได้ ไม่ซ้อนกัน) รอ 10 วิให้ข้อมูลเกมมาก่อน
    task.delay(10, function()
        if Velvet.Flags["WeblogOn"] ~= false then start() end
    end)

    Addon.stopWeblog = function()
        Addon.sessionOn = false  -- หยุดจดไฟล์ session (กด X / รันซ้ำ)
        stop()
    end
end
Addon.weblog()

----------------------------------------------------------------
-- แจ้งเตือนได้ตัว Limited: เหตุการณ์ kind "limited" -> หน้าเว็บ Weblog เด้งแจ้งเตือน + เก็บไว้ในกล่อง Limited
--   นับตัว rarity Limited ที่มี = ในกระเป๋า (MineGame.Characters[stack key] = จำนวน) + บน pad (MineGame.Holders[pad].CharName)
--   เช็คทุก 5 วิ: จำนวนของตัวไหนเปลี่ยน แล้วเห็นค่าเดิมซ้ำรอบถัดไป ถึงจะนับ
--     (ย้ายตัวจากกระเป๋าขึ้น pad ข้อมูลเกมอัปเดตไม่พร้อมกัน อาจนับซ้ำชั่วครู่ -> ไม่แจ้งผิด)
--     เพิ่ม = แจ้ง 1 ครั้ง / ลด (trade ออก) = จำค่าใหม่ ได้ตัวเดิมกลับมาอีกก็แจ้งอีก
--   รอบแรก = จำของที่มีอยู่แล้ว ไม่แจ้ง (เข้าเกม / rejoin ไม่เด้งซ้ำ)
--   ได้มาตอนมีห้อง trade (ภายใน 2 นาทีหลัง MineTradeSync ล่าสุด) = ต่อท้าย "(จาก trade)"
----------------------------------------------------------------
Addon.limitedWatch = function()
    local function rarityOf(name)
        local def = type(name) == "string" and getCharDef(name) or nil
        local r = def and def.Rarity
        if type(r) == "table" then r = r.Rarity end
        return r
    end
    -- { [ชื่อตัวละคร] = จำนวน } / nil = ยังอ่านข้อมูลเกมไม่ได้
    local function count()
        local mg = Addon.mineGame()
        if type(mg) ~= "table" or type(mg.Characters) ~= "table" then return nil end
        local out = {}
        for key, n in pairs(mg.Characters) do
            n = tonumber(n) or 0
            if type(key) == "string" and n > 0 then
                -- stack key = ชื่อ + เลเวล / mutation ต่อท้าย -> ParseCharStack คืนชื่อตัวละครก่อน
                local name = key
                if type(MineConfig.ParseCharStack) == "function" then
                    local okP, base = pcall(MineConfig.ParseCharStack, key)
                    if okP and type(base) == "string" then name = base end
                end
                if rarityOf(name) == "Limited" then out[name] = (out[name] or 0) + n end
            end
        end
        for _, h in pairs(type(mg.Holders) == "table" and mg.Holders or {}) do
            local name = type(h) == "table" and h.CharName or nil
            if type(name) == "string" and name ~= "" then
                -- ตัวที่มี mutation: CharName อาจมีชื่อ mutation นำหน้า
                if not rarityOf(name) and type(h.CharVariant) == "string" then
                    name = name:gsub("^" .. h.CharVariant:gsub("%p", "%%%0") .. " ", "")
                end
                if rarityOf(name) == "Limited" then out[name] = (out[name] or 0) + 1 end
            end
        end
        return out
    end

    local known, pend = nil, {}
    local function pass()
        local ok, have = isolated(count)
        if not ok or type(have) ~= "table" then return end
        if not known then known = have; return end
        local fromTrade = os.clock() - (Addon.tradeSeenAt or -math.huge) < 120
        local names = {}
        for name in pairs(have) do names[name] = true end
        for name in pairs(known) do names[name] = true end
        for name in pairs(names) do
            local now, was = have[name] or 0, known[name] or 0
            if now == was then
                pend[name] = nil
            elseif pend[name] ~= now then
                pend[name] = now  -- รอดูรอบหน้าว่าค่าคงที่ไหม
            else
                pend[name] = nil
                known[name] = now > 0 and now or nil
                if now > was then
                    Addon.emit("limited", ("ได้ตัว Limited: %s%s%s"):format(name,
                        now - was > 1 and (" x" .. (now - was)) or "", fromTrade and " (จาก trade)" or ""))
                end
            end
        end
    end
    local start = makeLoop(pass, function() return 5 end)
    task.delay(15, start)  -- รอข้อมูลเกมโหลดครบก่อน
end
Addon.limitedWatch()

----------------------------------------------------------------
-- CLAIM (แท็บ Rewards): Mailbox + Event Milestones
--
-- Mailbox  remote: Event:FireServer("ClaimMailboxReward", mailId, rewardIndex)
--   ข้อมูล: GameState.Players[UserId].Data.Mailbox.Messages = { { Id, Claimed, Rewards = { { Type, Amount, Claimed }, ... } }, ... }
--   เคลมทีละรางวัล เว้น 0.35 วิ (เกมเว้น 0.25) จดหมายที่ไม่มี Id (แบบเก่า) เกมเองก็เคลมไม่ได้ -> ข้าม
--
-- Milestone remote: Event:FireServer("MineEventsClaim", ladderId, tier, rewardIndex)
--   1. ขอ state: Event:FireServer("MineEventsOpen", id ของอีเวนต์ที่กำลังเล่น)
--      -> server ตอบ OnClientEvent("MineEventsState", payload)  payload.Events = อีเวนต์ที่เปิดอยู่
--         แต่ละอัน: Id, Key, Days, Points, Thresholds = { แต้มของแต่ละขั้น }, Claimed = { [ขั้น] = true }, Got = { [ขั้น] = bitmask }
--         .Personal = ladder ส่วนตัว (Id ขึ้นต้น "P:") โครงเดียวกัน
--   2. ขั้นที่ แต้ม >= Thresholds[ขั้น] และยังไม่ Claimed -> เคลมรางวัลที่ยังไม่ได้ (bit ใน Got ยังไม่ติด)
--      ลำดับรางวัลของขั้น = MineEventsConfig.Tiers(Days, Catalog[Key]) / PersonalTiers() (ฟังก์ชันเกม -> isolated)
--   ยิงแล้ว 3 รอบยังไม่ได้ (server ไม่ให้ เช่น เล่นอีเวนต์ไม่ถึงเกณฑ์) -> พักรางวัลนั้น 10 นาที ไม่ยิงซ้ำรัวๆ
--   อีเวนต์จบแล้ว milestone ที่ไม่ได้เคลม เกมส่งเข้า Mailbox ให้เอง (Auto Claim Mailbox เก็บต่อ)
----------------------------------------------------------------
Addon.claims = function()
    local function playerData()
        Addon.mineGame()  -- โหลด GameState ไว้ใน Addon.gs
        local data = nil
        pcall(function()
            local players = type(Addon.gs) == "table" and rawget(Addon.gs, "Players")
            local me = type(players) == "table" and players[tostring(LP.UserId)]
            data = type(me) == "table" and me.Data or nil
        end)
        return type(data) == "table" and data or nil
    end

    -- กันยิงซ้ำของที่ server ไม่ให้: [key] = { n = จำนวนครั้ง, at = เวลาครั้งแรก }
    local tries = {}
    local function canTry(key)
        local t = tries[key]
        if t and os.clock() - t.at > 600 then tries[key] = nil; t = nil end
        return not t or t.n < 3
    end
    local function tried(key)
        local t = tries[key] or { n = 0, at = os.clock() }
        t.n += 1
        tries[key] = t
    end

    -------------------- Mailbox --------------------
    local mailSection = rewardTab:AddSection("Mailbox")
    local mailPara = mailSection:AddParagraph({ Title = "Mailbox", Content = "ปิดอยู่" })
    local mailTotal = 0

    local function unclaimedMail()
        local data = playerData()
        local box = data and data.Mailbox
        local msgs = type(box) == "table" and box.Messages
        if type(msgs) ~= "table" then return nil end
        local list = {}
        for _, msg in ipairs(msgs) do
            if type(msg) == "table" and msg.Id ~= nil and msg.Claimed ~= true and type(msg.Rewards) == "table" then
                for i, r in ipairs(msg.Rewards) do
                    if type(r) == "table" and r.Claimed ~= true then
                        table.insert(list, { id = tostring(msg.Id), index = i, title = tostring(msg.Title or msg.Id) })
                    end
                end
            end
        end
        return list
    end

    local function mailPass(alive)
        local list = unclaimedMail()
        if not list then return mailPara:Set("รอข้อมูล mailbox จากเกม...") end
        local fired = 0
        for _, it in ipairs(list) do
            if alive and not alive() then return end
            local key = "mail|" .. it.id .. "|" .. it.index
            if canTry(key) then
                tried(key)
                fire("ClaimMailboxReward", it.id, it.index)
                fired += 1
                task.wait(0.35)
            end
        end
        if fired > 0 then task.wait(1.5) end
        local left = unclaimedMail()
        local remain = left and #left or 0
        local got = math.max(0, #list - remain)
        mailTotal += got
        if got > 0 then Addon.emit("mail", ("เคลมรางวัลจาก Mailbox %d ชิ้น"):format(got)) end
        mailPara:Set(("เคลมไปแล้ว %d รางวัล · ค้าง %d%s · เช็คล่าสุด %s"):format(
            mailTotal, remain, remain > 0 and " (server ยังไม่ให้ จะลองใหม่)" or "", os.date("%H:%M:%S")))
    end
    local startMail, stopMail = makeLoop(mailPass, function() return 60 end)
    mailSection:AddToggle("AutoClaimMail", {
        Text = "Auto Claim Mailbox",
        Default = false,
        Callback = function(on)
            if on then mailPara:Set("กำลังเช็ค..."); startMail() else stopMail(); mailPara:Set("ปิดอยู่") end
        end,
    })

    -------------------- Event Milestones --------------------
    local msSection = rewardTab:AddSection("Event Milestones")
    local msPara = msSection:AddParagraph({ Title = "Milestones", Content = "ปิดอยู่" })
    local EC = nil
    pcall(function() EC = require(RS:WaitForChild("Modules"):WaitForChild("MineEventsConfig")) end)
    local payload, payloadAt = nil, -math.huge
    pcall(function()
        Event.OnClientEvent:Connect(function(name, p)
            if name == "MineEventsState" and type(p) == "table" then payload, payloadAt = p, os.clock() end
        end)
    end)
    local msTotal = 0

    local function at(t, k)  -- ตารางจาก remote: key อาจเป็นเลขหรือข้อความ
        if type(t) ~= "table" then return nil end
        local v = t[k]
        if v == nil then v = t[tostring(k)] end
        return v
    end

    -- ladder ทั้งหมดใน payload (ของอีเวนต์ + ส่วนตัว) ไม่แก้ตารางของ payload
    local function ladders(p)
        local out = {}
        for _, ev in ipairs(type(p.Events) == "table" and p.Events or {}) do
            if type(ev) == "table" then
                table.insert(out, { src = ev, Id = ev.Id, Key = ev.Key, Days = ev.Days, personal = false })
                local per = ev.Personal
                if type(per) == "table" and per.Id ~= nil then
                    table.insert(out, { src = per, Id = per.Id, Key = ev.Key, Days = ev.Days, personal = true })
                end
            end
        end
        return out
    end

    -- ลำดับรางวัลที่ต้องเคลมของขั้นนี้ (แบบเดียวกับที่หน้าต่างอีเวนต์ของเกมกดให้)
    local function rewardIndexes(l, tier)
        local list = {}
        if not EC then return list end
        local ok, tiers = isolated(function()
            if l.personal then return EC.PersonalTiers() end
            return EC.Tiers(l.Days, EC.Catalog[l.Key])
        end)
        local def = ok and type(tiers) == "table" and tiers[tier] or nil
        local rewards = type(def) == "table" and def.Rewards or nil
        if type(rewards) ~= "table" then return list end
        local okS, shown = isolated(function() return EC.Shown(rewards) end)
        for _, r in ipairs(okS and type(shown) == "table" and shown or rewards) do
            local idx = table.find(rewards, r)
            if idx then table.insert(list, idx) end
        end
        return list
    end

    local function liveId()
        if not EC then return nil end
        local ok, list = isolated(function() return EC.Active(EC.Now()) end)
        local first = ok and type(list) == "table" and list[1] or nil
        return type(first) == "table" and first.Id or nil
    end

    local function msPass(alive)
        -- ขอ state ใหม่ แล้วรอ server ตอบ (สูงสุด 4 วิ)
        local asked = os.clock()
        fire("MineEventsOpen", liveId())
        while payloadAt < asked and os.clock() - asked < 4 do task.wait(0.1) end
        if not payload then return msPara:Set("รอข้อมูลอีเวนต์จากเกม...") end
        if payload.Enabled == false then return msPara:Set("ตอนนี้ไม่มีอีเวนต์เปิดอยู่") end

        local fired, ready, names = 0, 0, {}
        for _, l in ipairs(ladders(payload)) do
            local src = l.src
            local points = tonumber(src.Points) or 0
            for tier, need in ipairs(type(src.Thresholds) == "table" and src.Thresholds or {}) do
                if alive and not alive() then return end
                if (tonumber(need) or math.huge) <= points and at(src.Claimed, tier) ~= true then
                    local got = tonumber(at(src.Got, tier)) or 0
                    for _, idx in ipairs(rewardIndexes(l, tier)) do
                        if not bit32.btest(got, 2 ^ (idx - 1)) then
                            ready += 1
                            local key = "ms|" .. tostring(l.Id) .. "|" .. tier .. "|" .. idx
                            if canTry(key) then
                                tried(key)
                                fire("MineEventsClaim", l.Id, tier, idx)
                                fired += 1
                                names[tostring(l.Key)] = true
                                task.wait(0.6)
                            end
                        end
                    end
                end
            end
        end
        msTotal += fired
        local evs = {}
        for k in pairs(names) do table.insert(evs, k) end
        if fired > 0 then Addon.emit("milestone", ("เคลม milestone %d รางวัล (%s)"):format(fired, table.concat(evs, ", "))) end
        msPara:Set(fired > 0
            and ("ยิงเคลม %d รางวัล (%s) · รวม %d · %s"):format(fired, table.concat(evs, ", "), msTotal, os.date("%H:%M:%S"))
            or ("ไม่มี milestone ให้เคลม%s · รวม %d · เช็คล่าสุด %s"):format(
                ready > 0 and (" (ค้าง " .. ready .. " ที่ server ยังไม่ให้)") or "", msTotal, os.date("%H:%M:%S")))
    end
    local startMs, stopMs = makeLoop(msPass, function() return 30 end)
    msSection:AddToggle("AutoClaimMilestone", {
        Text = "Auto Claim Event Milestones",
        Default = false,
        Callback = function(on)
            if on then msPara:Set("กำลังเช็ค..."); startMs() else stopMs(); msPara:Set("ปิดอยู่") end
        end,
    })

    -------------------- Index Rewards --------------------
    -- remote: Event:FireServer("MineIndexClaim", category, tierKey, rewardIndex)
    --   (หน้า Index ของเกมเรียก GameState.SendEvent(MineIndexRewardsConfig.Events.Claim, ...) แบบเดียวกัน)
    --   category = zone (Z1, Z2, ...) หรือหมวดพิเศษ (MineIndexRewardsConfig.Keys())
    --   tierKey  = Key ของขั้น ("Count10" / "0.25") , rewardIndex = รางวัลที่เท่าไหร่ของขั้นนั้น
    --   ขั้นที่ถึงแล้ว + ยังไม่ได้เคลม = MineIndexRewardsConfig.State(MineGame, category, HeldNames).Track
    --     (Reached = true, ClaimedRewards[i] ~= true) ; zone ที่ยังไม่ปลดล็อค เกมไม่ให้เคลม -> ข้าม
    --   server ตอบ OnClientEvent("MineIndexRewardView", { t = "claim", ok = true/false, wait = true })
    --   เกมเว้น 0.6 วิ ต่อการเคลม 1 ครั้ง -> เว้น 0.7 วิ
    local idxSection = rewardTab:AddSection("Index Rewards")
    local idxPara = idxSection:AddParagraph({ Title = "Index", Content = "ปิดอยู่" })
    local IRC = nil
    pcall(function() IRC = require(RS:WaitForChild("Modules"):WaitForChild("MineIndexRewardsConfig")) end)
    local idxView = IRC and type(IRC.Events) == "table" and IRC.Events.View or "MineIndexRewardView"
    local idxOk, idxTotal = 0, 0
    pcall(function()
        Event.OnClientEvent:Connect(function(name, p)
            if name == idxView and type(p) == "table" and p.t == "claim" and p.ok == true then idxOk += 1 end
        end)
    end)

    -- รางวัล Index ที่เคลมได้ตอนนี้ทั้งหมด (ทุก zone ที่ปลดล็อค + หมวดพิเศษ)
    local function indexTodo()
        local mg = Addon.mineGame()
        if type(mg) ~= "table" or not IRC then return nil end
        local ok, list = isolated(function()
            local out = {}
            if IRC.Enabled ~= true then return out end
            local held = IRC.HeldNames(mg)
            local unlocked = type(mg.UnlockedZones) == "table" and mg.UnlockedZones or {}
            for _, key in ipairs(IRC.Keys()) do
                local cat = IRC.Category(key)
                if cat and (cat.Zone == nil or unlocked[key] == true) and (tonumber(IRC.Total(key)) or 0) > 0 then
                    local catKey = cat.Key or key
                    for _, tier in ipairs(IRC.State(mg, catKey, held).Track or {}) do
                        if tier.Reached and not tier.Claimed then
                            local got = type(tier.ClaimedRewards) == "table" and tier.ClaimedRewards or {}
                            for i, r in ipairs(tier.Rewards or {}) do
                                if not got[i] then
                                    table.insert(out, { cat = catKey, tier = tier.Key, index = i, text = IRC.Describe(r) })
                                end
                            end
                        end
                    end
                end
            end
            return out
        end)
        return ok and type(list) == "table" and list or nil
    end

    local function indexPass(alive)
        local list = indexTodo()
        if not list then return idxPara:Set("รอข้อมูล Index จากเกม...") end
        local okBefore, fired, cats = idxOk, 0, {}
        for _, it in ipairs(list) do
            if alive and not alive() then return end
            local key = "idx|" .. tostring(it.cat) .. "|" .. tostring(it.tier) .. "|" .. it.index
            if canTry(key) then
                tried(key)
                fire("MineIndexClaim", it.cat, it.tier, it.index)
                fired += 1
                cats[tostring(it.cat)] = true
                task.wait(0.7)
            end
        end
        if fired > 0 then task.wait(1.5) end
        local left = indexTodo()
        local remain = left and #left or 0
        local got = math.max(idxOk - okBefore, #list - remain, 0)
        idxTotal += got
        local names = {}
        for k in pairs(cats) do table.insert(names, k) end
        table.sort(names)
        if got > 0 then Addon.emit("index", ("เคลมรางวัล Index %d ชิ้น (%s)"):format(got, table.concat(names, ", "))) end
        idxPara:Set(("เคลมไปแล้ว %d รางวัล · ค้าง %d%s · เช็คล่าสุด %s"):format(
            idxTotal, remain, remain > 0 and " (server ยังไม่ให้ จะลองใหม่)" or "", os.date("%H:%M:%S")))
    end
    local startIdx, stopIdx = makeLoop(indexPass, function() return 30 end)
    idxSection:AddToggle("AutoClaimIndex", {
        Text = "Auto Claim Index (ทุก zone + หมวดพิเศษ)",
        Default = false,
        Callback = function(on)
            if on then idxPara:Set("กำลังเช็ค..."); startIdx() else stopIdx(); idxPara:Set("ปิดอยู่") end
        end,
    })

    Addon.stopClaims = function()
        stopMail()
        stopMs()
        stopIdx()
    end
end
Addon.claims()

----------------------------------------------------------------
-- AUTO SELL CHARACTERS (แท็บ Sell): ขายตัวละครในกระเป๋าที่ rarity ตรงกับที่ติ๊กไว้ใน dropdown (เลือกได้หลายอัน)
--
-- remote: Event:FireServer("MineSellItems", { stackKey, ... })  (ร้านขาย แท็บ Miners ปุ่ม Sell ยิงแบบเดียวกัน)
--   ของในกระเป๋า = MineInventory.Collect(MineGame, "Miners") แต่ละอัน: Kind = "Character", Key = stack key,
--     Rarity, Count, Worth (ราคาขายทั้ง stack), Variant (mutation), Level / SpeedLevel / MineSpeedLevel, Role
--   ตัวที่ใส่อยู่บน pad ไม่อยู่ในกระเป๋า -> ไม่โดนขาย ; ขายแล้ว Index ไม่หาย (Index นับจาก MineGame.Found)
--   ตัวเลือก = MineConfig.RarityOrder ยกเว้น Limited / Exclusive / Scaled (ไม่ขายเสมอ เกมเองก็ไม่ให้ขาย Limited / Exclusive)
--   ค่าเริ่มต้น = Common / Uncommon / Rare / Epic (ต่ำกว่า Legendary) ; ไม่ได้ติ๊กอะไร = ไม่ขาย
--   "เก็บตัวพิเศษไว้" (ค่าเริ่มต้นเปิด): ไม่ขาย Shiny / มี mutation / Serial / Hauler / ตัวที่อัปเลเวลแล้ว
--   (ระบบ Auto Sell ของเกมเอง MineAutoSellSet / MineAutoSellRaritySet ต้องมี gamepass -> ไม่ใช้)
----------------------------------------------------------------
Addon.sellChars = function()
    local section = sellTab:AddSection("Auto Sell Characters")
    local para = section:AddParagraph({ Title = "Characters", Content = "ปิดอยู่" })
    local INV = nil
    pcall(function() INV = require(RS:WaitForChild("Modules"):WaitForChild("MineInventory")) end)
    local NEVER = { Limited = true, Exclusive = true, Scaled = true }
    local choices = {}
    for _, r in ipairs(type(MineConfig.RarityOrder) == "table" and MineConfig.RarityOrder or {}) do
        if type(r) == "string" and not NEVER[r] then table.insert(choices, r) end
    end
    if #choices == 0 then choices = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Exotic" } end
    local DEFAULT = { "Common", "Uncommon", "Rare", "Epic" }
    local pick, keepSpecial, soldTotal, fails = {}, true, 0, 0
    for _, r in ipairs(DEFAULT) do pick[r] = true end

    -- ค่าจาก multi dropdown: { Name = true } หรือ { "Name", ... }
    local function setPick(value)
        pick = {}
        for k, v in pairs(type(value) == "table" and value or {}) do
            local r = (v == true and k) or (type(v) == "string" and v) or nil
            if r and not NEVER[r] then pick[r] = true end
        end
    end
    local function pickText()
        local out = {}
        for _, r in ipairs(choices) do if pick[r] then table.insert(out, r) end end
        return #out > 0 and table.concat(out, ", ") or "ยังไม่ได้เลือก (ไม่ขาย)"
    end

    -- ตัวพิเศษ (เก็บไว้ถ้าเปิด "เก็บตัวพิเศษไว้")
    local function special(e)
        if string.find(tostring(e.Key), "Shiny", 1, true) then return true end
        if e.Variant ~= nil or e.Role == "Hauler" then return true end
        if (tonumber(e.Level) or 1) > 1 or (tonumber(e.SpeedLevel) or 1) > 1 or (tonumber(e.MineSpeedLevel) or 1) > 1 then
            return true
        end
        return type(MineConfig.IsSerialCharacter) == "function" and MineConfig.IsSerialCharacter(e.Name) == true
    end

    -- ตัวในกระเป๋าที่จะขายรอบนี้
    local function todo()
        local mg = Addon.mineGame()
        if type(mg) ~= "table" or not INV then return nil end
        local ok, list = isolated(function()
            local out = {}
            for _, e in ipairs(INV.Collect(mg, "Miners") or {}) do
                if type(e) == "table" and e.Kind == "Character" and type(e.Key) == "string"
                    and (tonumber(e.Count) or 0) > 0 and (tonumber(e.Worth) or 0) > 0
                    and pick[e.Rarity] == true and not NEVER[e.Rarity]
                    and not (keepSpecial and special(e)) then
                    table.insert(out, { key = e.Key, n = tonumber(e.Count) or 1 })
                end
            end
            return out
        end)
        return ok and type(list) == "table" and list or nil
    end

    local function pass(alive)
        if not next(pick) then return para:Set("ยังไม่ได้เลือกระดับที่จะขาย") end
        local list = todo()
        if not list then return para:Set("รอข้อมูลกระเป๋าจากเกม...") end
        if #list == 0 then
            return para:Set(("ไม่มีตัวที่เลือกไว้ในกระเป๋า · ขายไปแล้ว %d ตัว · เช็คล่าสุด %s"):format(soldTotal, os.date("%H:%M:%S")))
        end
        local keys = {}
        for _, it in ipairs(list) do table.insert(keys, it.key) end
        if not Addon.atSeller(function() fire("MineSellItems", keys) end, alive) then return end
        -- นับที่ขายได้จริง = จำนวนที่หายไปจากกระเป๋า
        local left = {}
        for _, it in ipairs(todo() or {}) do left[it.key] = it.n end
        local sold = 0
        for _, it in ipairs(list) do sold += math.max(0, it.n - (left[it.key] or 0)) end
        soldTotal += sold
        fails = sold > 0 and 0 or fails + 1  -- ขายไม่ออกติดกัน 3 รอบ = เว้นรอบเป็น 3 นาที (ไม่เดินทางรัวๆ)
        if sold > 0 then Addon.emit("sellchar", ("ขายตัวละคร %d ตัว (%s)"):format(sold, pickText())) end
        para:Set(("ขายรอบนี้ %d ตัว · รวม %d ตัว%s · %s"):format(sold, soldTotal,
            sold == 0 and " (server ยังไม่ขายให้ จะลองใหม่)" or "", os.date("%H:%M:%S")))
    end
    local start, stop = makeLoop(pass, function() return fails >= 3 and 180 or 60 end)  -- ขายทุก 1 นาที

    section:AddToggle("AutoSellChars", {
        Text = "Auto Sell Characters",
        Default = false,
        Callback = function(on)
            if on then fails = 0; para:Set("กำลังเช็ค..."); start() else stop(); para:Set("ปิดอยู่") end
        end,
    })
    section:AddDropdown("SellCharRarities", {
        Text = "ระดับที่จะขาย",
        Values = choices,
        Default = DEFAULT,
        Multi = true,
    })
    local preview = section:AddParagraph({ Title = "จะขาย", Content = pickText() })
    -- OnFlagChanged: Load Config เรียกแค่ :Set ไม่เรียก Callback ของ dropdown
    Velvet:OnFlagChanged("SellCharRarities", function(value)
        setPick(value)
        preview:Set(pickText())
    end)
    section:AddToggle("SellCharKeepSpecial", {
        Text = "เก็บตัวพิเศษไว้ (Shiny / Mutation / Serial / Hauler / อัปเลเวลแล้ว)",
        Default = true,
    })
    Velvet:OnFlagChanged("SellCharKeepSpecial", function(value)
        keepSpecial = value ~= false
    end)

    Addon.stopSellChars = stop
end
Addon.sellChars()

----------------------------------------------------------------
-- AUTO USE POTION (แท็บ Gem Shop): ดื่ม potion แบบมีเวลา (Timed) เองตอน boost หมด
--
-- remote: Event:FireServer("MineUsePotion", itemName, amount)  (หน้าต่างใช้ potion ของเกมยิงแบบเดียวกัน)
--   ของที่มี = MineGame.Potions[ชื่อ] = จำนวน ; รายการ = MinePotionCatalog.Potions (Kind / Family / Mult / Add / Duration)
--   boost ที่ทำงานอยู่ = MineConfig.GetBoost(MineGame, Family) (หมดเวลาแล้ว = nil) เหลือ = Until - AdminBoostNow
--   ใช้ทับตอน boost ยังทำงาน = เกม "แทนที่" ของเดิม (ขวดอ่อนทับขวดแรงได้) -> ใช้เฉพาะตอน family นั้นหมดแล้ว
--   family เดียวมีหลายขวด (I / II / III) -> ใช้ขวดแรงสุดที่มีก่อน ทีละ 1 ขวด
--   ใช้แค่ Kind = "Timed" (Charge / Instant / Food = ของเฉพาะทาง เช่น กุญแจปลดช่อง ระเบิด ไม่ใช้เอง)
--   Kaitun เปิดให้เองตาม Kaitun.cfg.Potion (Enabled + Use = รายการ family) [KAITUN ส่วนที่ 2 applyToggles]
----------------------------------------------------------------
Addon.usePotion = function()
    local section = Addon.gemTab:AddSection("Auto Use Potion")
    local para = section:AddParagraph({ Title = "Potion", Content = "ปิดอยู่" })
    local CAT = nil
    pcall(function() CAT = require(RS:WaitForChild("Modules"):WaitForChild("MinePotionCatalog")) end)

    -- family -> { label, potions = แรงสุดก่อน } ; label = ชื่อขวดไม่มีเลขขั้น (เช่น "Strength Potion")
    local fams, labels, byLabel = {}, {}, {}
    local function power(p)  -- แบบเดียวกับที่หน้าต่างเกมเทียบ "Stronger / Weaker" (Mult < 1 เช่น Regrowth 0.5 = ยิ่งน้อยยิ่งแรง)
        local m = tonumber(p.Mult)
        if m and m > 0 then return m < 1 and 1 / m or m end
        return tonumber(p.Add) or 0
    end
    for _, p in ipairs(CAT and type(CAT.Potions) == "table" and CAT.Potions or {}) do
        if type(p) == "table" and p.Kind == "Timed" and type(p.Family) == "string" and type(p.ItemName) == "string" then
            local f = fams[p.Family]
            if not f then
                local label = p.ItemName:gsub("%s+[IVX]+$", "")
                if byLabel[label] then label = label .. " (" .. p.Family .. ")" end
                f = { label = label, potions = {} }
                fams[p.Family], byLabel[label] = f, p.Family
                table.insert(labels, label)
            end
            table.insert(f.potions, { name = p.ItemName, power = power(p), dur = tonumber(p.Duration) or 0 })
        end
    end
    for _, f in pairs(fams) do
        table.sort(f.potions, function(a, b)
            if a.power ~= b.power then return a.power > b.power end
            return a.dur > b.dur
        end)
    end
    table.sort(labels)

    -- ค่าเริ่มต้น = ช่วยฟาร์มเงิน / ขุด (ไม่รวม Mutation Luck = ใช้ตอนสุ่ม mutation, Colossus Rally = ตอนตีบอส)
    local DEFAULT = { "Strength", "Haste", "OreLuck", "Unearth", "Prospect", "Crit", "Regrowth", "Sell", "ChestCap", "TapFury", "CharLuck" }
    local function flagOf(list)  -- รายการ family -> ค่า flag ของ dropdown { [label] = true }
        local v = {}
        for _, fam in ipairs(type(list) == "table" and list or {}) do
            if fams[fam] then v[fams[fam].label] = true end
        end
        return v
    end
    local pick = {}
    for _, fam in ipairs(DEFAULT) do if fams[fam] then pick[fam] = true end end
    local usedTotal, lastFire = 0, {}

    local function mmss(s)
        if s == math.huge then return "ถาวร" end
        s = math.max(0, math.floor(s))
        return ("%d:%02d"):format(s // 60, s % 60)
    end

    -- อ่านสถานะ: ขวดที่ต้องใช้ตอนนี้ / boost ที่ทำงานอยู่ / family ที่ขวดหมด
    local function scan(mg)
        local bag = type(mg.Potions) == "table" and mg.Potions or {}
        local ok, res = isolated(function()
            local use, active, empty = {}, {}, {}
            local now = MineConfig.AdminBoostNow(mg)
            for fam in pairs(pick) do
                local f = fams[fam]
                local b = f and MineConfig.GetBoost(mg, fam)
                if b then
                    local left = b.Until == nil and math.huge or (tonumber(b.Until) or 0) - now
                    table.insert(active, ("%s %s"):format(f.label, mmss(left)))
                elseif f then
                    local have = nil
                    for _, p in ipairs(f.potions) do
                        if (tonumber(bag[p.name]) or 0) > 0 then have = p.name; break end
                    end
                    if have then
                        table.insert(use, { fam = fam, name = have, n = tonumber(bag[have]) or 0 })
                    else
                        table.insert(empty, f.label)
                    end
                end
            end
            table.sort(active)
            table.sort(empty)
            return { use = use, active = active, empty = empty }
        end)
        return ok and type(res) == "table" and res or nil
    end

    local function pass(alive)
        if not next(pick) then return para:Set("ยังไม่ได้เลือก potion") end
        local mg = Addon.mineGame()
        if type(mg) ~= "table" then return para:Set("รอข้อมูลจากเกม...") end
        local st = scan(mg)
        if not st then return para:Set("อ่านข้อมูล potion ไม่ได้ (จะลองใหม่)") end
        local fired = {}
        for _, it in ipairs(st.use) do
            if alive and not alive() then return end
            -- เพิ่งใช้ไป (server ยังไม่อัปเดต boost) -> รอก่อน ไม่ใช้ซ้ำ
            if os.clock() - (lastFire[it.fam] or -math.huge) > 10 then
                lastFire[it.fam] = os.clock()
                fire("MineUsePotion", it.name, 1)
                table.insert(fired, it)
                task.wait(0.4)
            end
        end
        if #fired > 0 then
            task.wait(1.5)
            local after = Addon.mineGame()
            local bag = type(after) == "table" and type(after.Potions) == "table" and after.Potions or {}
            local names = {}
            for _, it in ipairs(fired) do
                if (tonumber(bag[it.name]) or 0) < it.n then
                    usedTotal += 1
                    table.insert(names, it.name)
                end
            end
            if #names > 0 then Addon.emit("potion", "ใช้ potion: " .. table.concat(names, ", ")) end
            st = scan(type(after) == "table" and after or mg) or st
        end
        local lines = {
            ("ทำงานอยู่: %s"):format(#st.active > 0 and table.concat(st.active, ", ") or "-"),
            ("ใช้ไปแล้ว %d ขวด · เช็คล่าสุด %s"):format(usedTotal, os.date("%H:%M:%S")),
        }
        if #st.empty > 0 then table.insert(lines, "ขวดหมด: " .. table.concat(st.empty, ", ")) end
        para:Set(table.concat(lines, "\n"))
    end
    local start, stop = makeLoop(pass, function() return 5 end)

    section:AddToggle("AutoUsePotion", {
        Text = "Auto Use Potion (ใช้ตอน boost หมด)",
        Default = false,
        Callback = function(on)
            if on then para:Set("กำลังเช็ค..."); start() else stop(); para:Set("ปิดอยู่") end
        end,
    })
    local defLabels = {}
    for _, fam in ipairs(DEFAULT) do if fams[fam] then table.insert(defLabels, fams[fam].label) end end
    section:AddDropdown("UsePotionTypes", {
        Text = "Potion ที่จะใช้",
        Values = labels,
        Default = defLabels,
        Multi = true,
    })
    -- OnFlagChanged: Load Config เรียกแค่ :Set ไม่เรียก Callback ของ dropdown ; ค่า { Name = true } หรือ { "Name", ... }
    Velvet:OnFlagChanged("UsePotionTypes", function(value)
        pick = {}
        for k, v in pairs(type(value) == "table" and value or {}) do
            local label = (v == true and k) or (type(v) == "string" and v) or nil
            local fam = label and byLabel[label]
            if fam then pick[fam] = true end
        end
    end)

    Addon.potionFlag = flagOf  -- Kaitun ใช้ตั้ง dropdown จาก cfg.Potion.Use
    Addon.stopUsePotion = stop
end
Addon.usePotion()

----------------------------------------------------------------
-- AUTO DAILY TRIAL (แท็บ Rewards > Infinity Trial)
--
-- ข้อมูล: MineGame.Trial = { Attempt = { EndsAt }, Day, DayRuns, DayBest, Claimed = { [claimKey] = true } }
-- remote (MineTrialConfig.Events): Start = "MineTrialStart" (ไม่มี argument) / Claim = "MineTrialClaim", tier
--   รางวัลรายวันคิดจากคะแนนดีสุดของวันนั้น (DailyClaims) -> เริ่ม trial วันละ N รอบ (slider) แล้วเคลมทุกขั้นที่ถึง
--   1 รอบ = WindowSeconds (300 วิ) ระหว่างรอบ (Attempt.EndsAt ยังไม่ถึง) ไม่ยิงอะไร
--   ปลดล็อคหรือยัง = MineTrialConfig.Unlocked(MineGame) ; ขั้นที่เคลมได้ = ClaimableTiers(Trial)
--   เคลมขั้นเดียวกันพลาด 3 ครั้ง = พักขั้นนั้น 10 นาที
----------------------------------------------------------------
Addon.trial = function()
    local section = rewardTab:AddSection("Infinity Trial")
    local para = section:AddParagraph({ Title = "Trial", Content = "ปิดอยู่" })
    local TC, Clock = nil, nil
    pcall(function()
        TC = require(RS:WaitForChild("Modules"):WaitForChild("MineTrialConfig"))
        Clock = require(RS:WaitForChild("Modules"):WaitForChild("ServerClock"))
    end)
    local tries, claimed, started = {}, 0, 0

    local function pass(alive)
        local mg = Addon.mineGame()
        if type(mg) ~= "table" or not TC then return para:Set("รอข้อมูลจากเกม...") end
        local ok, st = isolated(function()
            local trial = type(mg.Trial) == "table" and mg.Trial or {}
            local now = Clock and Clock.Now() or os.time()
            local _, runs, best = TC.Budgets(trial)
            local att = type(trial.Attempt) == "table" and tonumber(trial.Attempt.EndsAt) or 0
            return {
                on = TC.Enabled ~= false, unlocked = TC.Unlocked(mg) == true, why = TC.Unlocked(mg) ~= true and "ยังไม่ปลดล็อค" or nil,
                runs = tonumber(runs) or 0, best = tonumber(best) or 0, left = att - now, day = TC.DayIndex(),
                claim = TC.ClaimableTiers(trial), tier = TC.ReachedTier(trial),
            }
        end)
        if not ok or type(st) ~= "table" then return para:Set("อ่านข้อมูล trial ไม่ได้ (จะลองใหม่)") end
        if not st.on then return para:Set("เกมปิด Infinity Trial อยู่") end
        if not st.unlocked then return para:Set("ยังไม่ปลดล็อค Infinity Trial (ต้องทำ research Colossus ก่อน)") end
        if st.left > 0 then
            return para:Set(("กำลังทำ trial เหลือ %d วิ · วันนี้ %d รอบ · ถึงขั้น %s"):format(st.left, st.runs, tostring(st.tier)))
        end
        -- เคลมทุกขั้นที่ถึงแล้ว
        local fired = 0
        for _, tier in ipairs(type(st.claim) == "table" and st.claim or {}) do
            if alive and not alive() then return end
            local key = st.day .. "|" .. tostring(tier)
            local t = tries[key]
            if t and os.clock() - t.at > 600 then tries[key] = nil; t = nil end
            if not t or t.n < 3 then
                t = t or { n = 0, at = os.clock() }
                t.n += 1
                tries[key] = t
                fire(TC.Events.Claim, tier)
                fired += 1
                task.wait(0.8)
            end
        end
        if fired > 0 then
            claimed += fired
            Addon.emit("trial", ("เคลมรางวัล Infinity Trial %d ขั้น"):format(fired))
        end
        -- เริ่มรอบใหม่ถ้าวันนี้ยังไม่ครบ
        local want = flag("TrialRuns", 1)
        if st.runs < want then
            fire(TC.Events.Start)
            started += 1
            Addon.emit("trial", ("เริ่ม Infinity Trial (รอบที่ %d ของวันนี้)"):format(st.runs + 1))
            return para:Set(("เริ่ม trial รอบที่ %d/%d ของวันนี้..."):format(st.runs + 1, want))
        end
        para:Set(("วันนี้ทำครบ %d รอบ · ถึงขั้น %s · เคลมไปแล้ว %d ขั้น · เช็คล่าสุด %s"):format(
            st.runs, tostring(st.tier), claimed, os.date("%H:%M:%S")))
    end
    local start, stop = makeLoop(pass, function() return 20 end)
    section:AddToggle("AutoDailyTrial", {
        Text = "Auto Daily Trial (เริ่ม + เคลมรางวัล)",
        Default = false,
        Callback = function(on)
            if on then para:Set("กำลังเช็ค..."); start() else stop(); para:Set("ปิดอยู่") end
        end,
    })
    section:AddSlider("TrialRuns", {
        Text = "รอบต่อวัน",
        Min = 1, Max = 10, Default = 1, Increment = 1,
    })
    Addon.stopTrial = stop
end
Addon.trial()

----------------------------------------------------------------
-- AUTO DICE (แท็บ Dice): ทอย Enchanted Dice เอง + ใส่ enchant ที่ดีสุดให้ pad
--
-- ทอย:  Event:FireServer("MineRollEnchant", จำนวน, kind)   kind = nil = Enchanted Dice ปกติ
--   จำนวนลูกเต๋า = MineConfig.GetEnchantDiceCount(MineGame) ; ปลดล็อค = MineEnchantCatalog.Unlocked(MineGame)
--   ทอยได้ enchant เข้ากระเป๋า MineGame.EnchantItems[ชื่อ] = จำนวน
-- ใส่:  Event:FireServer("MineEquipEnchant", pad, ชื่อ)        enchant ของ pad = MineGame.Enchants[pad]
--   ค่าความแรงของ enchant = MineEnchantCatalog.ExpectedMult(def) (ไม่มี = DamageMult x SpeedMult)
--   pad แรงสุด (ดาเมจ miner) ได้ enchant แรงสุดก่อน เปลี่ยนเฉพาะเมื่อของในกระเป๋าแรงกว่าของที่ pad ใส่อยู่
----------------------------------------------------------------
Addon.dice = function()
    local section = Addon.diceTab:AddSection("Auto Dice")
    local para = section:AddParagraph({ Title = "Dice", Content = "ปิดอยู่" })
    local EC = nil
    pcall(function() EC = require(RS:WaitForChild("Modules"):WaitForChild("MineEnchantCatalog")) end)
    local rolled, equipped, stuck = 0, 0, 0

    local function diceCount(mg)
        local ok, n = isolated(function() return MineConfig.GetEnchantDiceCount(mg) end)
        return ok and tonumber(n) or 0
    end
    local function strength(name)  -- ความแรงของ enchant (ไม่รู้จัก = 0)
        if type(name) ~= "string" or name == "" or not EC then return 0 end
        local ok, v = isolated(function()
            local def = EC.ByName(name)
            if type(def) ~= "table" then return 0 end
            local e = type(EC.ExpectedMult) == "function" and tonumber(EC.ExpectedMult(def)) or nil
            return (e and e > 0) and e or (tonumber(def.DamageMult) or 1) * (tonumber(def.SpeedMult) or 1)
        end)
        return ok and tonumber(v) or 0
    end

    -- ใส่ enchant ดีสุดในกระเป๋าให้ pad แรงสุดก่อน (ทีละ pad ต่อรอบ)
    local function equipBest(mg)
        local bag = {}
        for name, n in pairs(type(mg.EnchantItems) == "table" and mg.EnchantItems or {}) do
            if (tonumber(n) or 0) > 0 then table.insert(bag, { name = name, s = strength(name) }) end
        end
        if #bag == 0 then return nil end
        table.sort(bag, function(a, b) return a.s > b.s end)
        local pads = {}
        for pad, h in pairs(type(mg.Holders) == "table" and mg.Holders or {}) do
            if type(pad) == "string" and pad:match("^M%d+$") and type(h) == "table" and type(h.CharName) == "string" and h.CharName ~= "" then
                local def = getCharDef(h.CharName)
                local tier = def and tonumber(def.MineTier) or 0
                local td = type(MineConfig.TierDamage) == "table" and tonumber(MineConfig.TierDamage[tier]) or tier
                local cur = type(mg.Enchants) == "table" and mg.Enchants[pad] or nil
                table.insert(pads, { pad = pad, w = td * (tonumber(def and def.MineDamageMult) or 1), cur = strength(cur), curName = cur })
            end
        end
        table.sort(pads, function(a, b) return a.w > b.w end)
        for _, p in ipairs(pads) do
            if bag[1].s > p.cur * 1.001 then
                fire("MineEquipEnchant", p.pad, bag[1].name)
                return ("%s: %s -> %s"):format(p.pad, tostring(p.curName or "-"), bag[1].name)
            end
        end
        return nil
    end

    local function pass(alive)
        local mg = Addon.mineGame()
        if type(mg) ~= "table" or not EC then return para:Set("รอข้อมูลจากเกม...") end
        local okU, unlocked = isolated(function() return EC.Unlocked(mg) end)
        if not (okU and unlocked) then return para:Set("ยังไม่ปลดล็อคระบบ Enchant") end
        local keep = math.floor(tonumber(Velvet.Flags["DiceKeep"]) or 0)
        local amount = math.max(1, math.floor(flag("DiceAmount", 1)))
        local have = diceCount(mg)
        local note = nil
        if Velvet.Flags["AutoRollDice"] ~= false and have - keep >= 1 then
            if stuck >= 3 then amount = 1 end  -- ทอยหลายลูกแล้วลูกเต๋าไม่ลด = server ไม่รับจำนวนนี้ -> ทอยทีละ 1
            amount = math.min(amount, have - keep)
            fire("MineRollEnchant", amount, nil)
            task.wait(1.5)
            if alive and not alive() then return end
            mg = Addon.mineGame() or mg
            local after = diceCount(mg)
            if after < have then
                rolled += have - after
                stuck = 0
            else
                stuck += 1
                note = "ทอยแล้วลูกเต๋าไม่ลด (server ยังไม่รับ จะลองใหม่)"
            end
            have = after
        end
        if Velvet.Flags["AutoEquipEnchant"] == true then
            local did = equipBest(mg)
            if did then
                equipped += 1
                Addon.emit("dice", "ใส่ enchant " .. did)
                note = "ใส่ " .. did
            end
        end
        para:Set(("ลูกเต๋า %d (เก็บไว้ %d) · ทอยไปแล้ว %d · ใส่ enchant %d ครั้ง%s · %s"):format(
            have, keep, rolled, equipped, note and (" · " .. note) or "", os.date("%H:%M:%S")))
    end
    local start, stop = makeLoop(pass, function() return 3 end)
    section:AddToggle("AutoDice", {
        Text = "Auto Dice",
        Default = false,
        Callback = function(on)
            if on then stuck = 0; para:Set("กำลังเช็ค..."); start() else stop(); para:Set("ปิดอยู่") end
        end,
    })
    section:AddToggle("AutoRollDice", { Text = "ทอย Enchanted Dice เอง", Default = true, VisibleWhen = "AutoDice" })
    section:AddSlider("DiceAmount", { Text = "ทอยครั้งละ", Min = 1, Max = 10, Default = 1, Increment = 1, VisibleWhen = "AutoDice" })
    section:AddSlider("DiceKeep", { Text = "เก็บลูกเต๋าไว้", Min = 0, Max = 500, Default = 0, Increment = 5, VisibleWhen = "AutoDice" })
    section:AddToggle("AutoEquipEnchant", {
        Text = "ใส่ enchant ดีสุดให้ pad แรงสุดก่อน",
        Default = false,
        VisibleWhen = "AutoDice",
    })
    Addon.stopDice = stop
end
Addon.dice()

----------------------------------------------------------------
-- AUTO TRADE (สั่งจากหน้า Weblog -> Hub -> WebSocket ของแต่ละไอดี)
--
-- ตัวรับ: ได้คำสั่ง { cmd = "recv", from = { userId ตัวส่ง, ... } }
--   - คำขอ trade (MineTradeShowRequest) จาก userId ในรายการ -> MineTradeRespond(true, requestId)
--   - ในห้อง trade: ตัวส่งกดพร้อมแล้ว + เราไม่ได้ใส่ของ -> MineTradeReady / MineTradeConfirm ให้เอง
--   - รับได้ 30 นาทีหลังสั่ง (หรือจนสั่งหยุด) คำขอจากคนอื่นไม่แตะ
--
-- ตัวส่ง: ได้คำสั่ง { cmd = "send", to = userId ตัวรับ, job = JobId ของตัวรับ, place }
--   1. คนละเซิร์ฟเวอร์ -> จำงานไว้ใน EndHub/trade_job.json + queue_on_teleport ให้โหลดสคริปต์ต่อ
--      -> TeleportToPlaceInstance ไปเซิร์ฟเวอร์ของตัวรับ (เข้าเกมใหม่แล้วอ่านไฟล์ทำต่อเอง)
--   2. รอบละ 1 trade: MineTradeRequest -> รอห้อง (MineTradeSync) -> MineTradeSetItem ทีละกอง
--      (ไม่เกิน TradeMaxStacks = 8 กอง / กองละไม่เกิน TradeMaxCount = 999 หรือเพดานของของชิ้นนั้น)
--      -> MineTradeReady -> MineTradeConfirm -> รอปิดห้อง
--   3. วนจนของที่ trade ได้หมด / รอบล่าสุดของไม่ลด (เหลือแต่ของที่ server ไม่ให้ย้าย) / พลาด 3 ครั้งติด
--   ของที่ trade ได้ = MineInventory.Collect(state, "All") ที่ MineConfig.TradeStack(key) ยอม (แบบเดียวกับหน้าต่าง trade ของเกม)
--   ความคืบหน้าส่งเข้าเว็บเป็นเหตุการณ์ kind = "trade"
----------------------------------------------------------------
Addon.trade = function()
    local TeleportService = game:GetService("TeleportService")
    local JOB_FILE = "EndHub/trade_job.json"
    local LOADER_URL = "https://raw.githubusercontent.com/xMidNxtx/test/main/loader.lua"
    local queueTp = queue_on_teleport or queueonteleport
        or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    -- โหลด End Hub ต่อหลังวาป (กันรันซ้ำกับ Auto Execute ด้วยตัวแปรเดียวกัน)
    local TP_CODE = table.concat({
        "if not game:IsLoaded() then game.Loaded:Wait() end",
        "local env = (getgenv and getgenv()) or _G",
        "if env.EndHubAutoRan == game.JobId then return end",
        "env.EndHubAutoRan = game.JobId",
        "pcall(function() loadstring(game:HttpGet(\"" .. LOADER_URL .. "\"))() end)",
    }, "\n")
    local GEMS_KEY = MineConfig.GemsItemName or "Gems"
    local MAX_STACKS = tonumber(MineConfig.TradeMaxStacks) or 8
    local MAX_COUNT = tonumber(MineConfig.TradeMaxCount) or 999
    local MAX_ROUNDS = 60

    local inv = nil
    pcall(function() inv = require(RS:WaitForChild("Modules"):WaitForChild("MineInventory")) end)

    -- trade ได้ไหม (เงื่อนไขเดียวกับปุ่ม Trade ของเกม) -> true / false / nil (ยังไม่รู้)
    Addon.canTrade = function(mg)
        if type(mg) ~= "table" then return nil end
        local on = false
        pcall(function() on = RS.Modules.MineConfig:GetAttribute("TradingEnabled") == true end)
        if not on or mg.TutorialDone ~= true then return false end
        local ok, unlocked = isolated(function() return MineConfig.TradeUnlocked(mg) end)
        return ok and unlocked == true
    end

    local function say(text)
        if Addon.emit then Addon.emit("trade", text) end
        print("[End Hub] Auto Trade:", text)
    end

    -------------------- สถานะ trade จาก server --------------------
    local sync, syncAt = nil, 0
    local closed = {}            -- [sessionId] = true (ห้องปิดแล้ว)
    local recv = nil             -- ตัวรับ: { from = { [userId] = true }, untilAt }
    local sendGen, recvGen = 0, 0

    pcall(function()
        Event.OnClientEvent:Connect(function(name, a, b, c)
            if name == "MineTradeSync" and type(a) == "table" then
                sync, syncAt = a, os.clock()
                Addon.tradeSeenAt = syncAt  -- แจ้งเตือน Limited: ได้มาตอนมีห้อง trade = "(จาก trade)"
            elseif name == "MineTradeClosed" then
                local sid = tonumber(b) or tonumber(a)
                if sid then closed[sid] = true end
            elseif name == "MineTradeShowRequest" then
                local uid, reqId = tonumber(b), c
                if recv and os.clock() < recv.untilAt and uid and recv.from[uid] and type(reqId) == "number" then
                    task.delay(0.4, function() fire("MineTradeRespond", true, reqId) end)
                end
            end
        end)
    end)

    local function waitFor(fn, timeout, alive)
        local t0 = os.clock()
        while os.clock() - t0 < timeout do
            if not alive() then return nil end
            local r = fn()
            if r then return r end
            task.wait(0.2)
        end
        return nil
    end

    -------------------- ตัวรับ --------------------
    local function recvLoop(myGen)
        while recvGen == myGen and recv and os.clock() < recv.untilAt do
            local x = sync
            if x and type(x.SessionId) == "number" and not closed[x.SessionId] then
                local since = os.clock() - syncAt
                local giving = type(x.Give) == "table" and next(x.Give) ~= nil
                if x.Stage == "negotiate" and x.ThemReady and not x.MeReady and not giving
                    and since >= (tonumber(x.ReadyAfter) or 0) then
                    fire("MineTradeReady", true, x.SessionId, x.Revision)
                    task.wait(0.6)
                elseif x.Stage == "confirm" and not x.MeConfirmed and since >= (tonumber(x.ConfirmAfter) or 0) then
                    fire("MineTradeConfirm", x.SessionId, x.Revision)
                    task.wait(0.6)
                end
            end
            task.wait(0.25)
        end
        if recvGen == myGen and recv then
            recv = nil
            say("หมดเวลารับของ (30 นาที)")
        end
    end

    -------------------- เลือก rarity ที่จะส่ง (Settings > Auto Trade) --------------------
    --   Character / Pickaxe: ส่งเฉพาะ rarity ที่ติ๊กไว้ (ค่าเริ่มต้น = ทุก rarity เหมือนเดิม)
    --   ของประเภทอื่น (แร่ / gem / ไอเทม) ส่งเหมือนเดิม
    --   เซฟลง EndHub/trade_filter.json (วาปไปเซิร์ฟตัวรับแล้วโหลดใหม่ก็ยังจำ)
    local FILTER_FILE = "EndHub/trade_filter.json"
    local RARITIES = {}
    for _, r in ipairs(type(MineConfig.RarityOrder) == "table" and MineConfig.RarityOrder or {}) do
        if type(r) == "string" then table.insert(RARITIES, r) end
    end
    local tradeFilter = { Character = nil, Pickaxe = nil }  -- nil = ส่งทุก rarity
    local function toSet(value)
        local set = {}
        for k, v in pairs(type(value) == "table" and value or {}) do
            local picked = (v == true and k) or (type(v) == "string" and v) or nil
            if picked then set[picked] = true end
        end
        return set
    end
    local function listOf(set)
        local out = {}
        for _, r in ipairs(RARITIES) do if set[r] then table.insert(out, r) end end
        return out
    end
    local function saveFilter()
        pcall(function()
            if not isfolder("EndHub") then makefolder("EndHub") end
            writefile(FILTER_FILE, HttpService:JSONEncode({
                Character = tradeFilter.Character and listOf(tradeFilter.Character) or RARITIES,
                Pickaxe = tradeFilter.Pickaxe and listOf(tradeFilter.Pickaxe) or RARITIES,
            }))
        end)
    end
    local jobFilter = nil  -- rarity จากหน้าเว็บ (มากับคำสั่ง send) ใช้แทนค่าในเกมระหว่างงานนั้น
    local jobItems = nil   -- ของที่เลือกเองจากหน้าเว็บ { [key] = true } มี = ส่งเฉพาะของพวกนี้ (ไม่ดู rarity)
    local function allowed(e)
        if jobItems then return jobItems[e.Key] == true end
        local set = (jobFilter and jobFilter[e.Kind]) or tradeFilter[e.Kind]
        if not set then return true end
        local r = type(e.Rarity) == "string" and e.Rarity or nil
        if not r or not table.find(RARITIES, r) then return true end  -- rarity ที่ไม่รู้จัก = ส่งตามเดิม
        return set[r] == true
    end
    do
        local saved = nil
        pcall(function()
            if isfile(FILTER_FILE) then saved = HttpService:JSONDecode(readfile(FILTER_FILE)) end
        end)
        local tradeSection = Settings:AddSection("Auto Trade")
        for _, kind in ipairs({ "Character", "Pickaxe" }) do
            local flag = "Trade" .. kind .. "Rarities"
            local def = type(saved) == "table" and type(saved[kind]) == "table" and saved[kind] or RARITIES
            tradeFilter[kind] = toSet(def)
            tradeSection:AddDropdown(flag, {
                Text = kind == "Character" and "Character Rarities" or "Pickaxe Rarities",
                Values = RARITIES,
                Default = def,
                Multi = true,
            })
            Velvet:OnFlagChanged(flag, function(value)
                tradeFilter[kind] = toSet(value)
                saveFilter()
            end)
        end
    end

    -------------------- ตัวส่ง --------------------
    -- ของที่ trade ได้ทั้งหมด { { key, n }, ... } (n ไม่เกินเพดานต่อกอง) / nil = อ่านไม่ได้
    local function collectItems()
        local mg = Addon.mineGame()
        if type(mg) ~= "table" or not inv then return nil end
        local ok, list = isolated(function()
            local out, seen = {}, {}
            local function cap(key)
                if type(MineConfig.TradeMaxCountFor) ~= "function" then return MAX_COUNT end
                local st = MineConfig.TradeStack(key)
                return st and tonumber(MineConfig.TradeMaxCountFor(st)) or MAX_COUNT
            end
            for _, e in ipairs(inv.Collect(mg, "All")) do
                if type(e) == "table" and e.Key ~= nil and not seen[e.Key] and allowed(e) and MineConfig.TradeStack(e.Key) then
                    local n = (e.Kind == "Pickaxe" or e.Kind == "BaseSkin") and tonumber(e.Spare) or tonumber(e.Count)
                    n = math.floor(n or 0)
                    if n > 0 then
                        seen[e.Key] = true
                        table.insert(out, { key = e.Key, n = math.min(n, cap(e.Key)) })
                    end
                end
            end
            -- gem (ถ้า Collect ไม่ได้ใส่มาให้)
            if not seen[GEMS_KEY] and (not jobItems or jobItems[GEMS_KEY]) and MineConfig.TradeStack(GEMS_KEY) then
                local g = math.floor(tonumber(MineConfig.GetGemCount(mg)) or 0)
                if g > 0 then table.insert(out, 1, { key = GEMS_KEY, n = math.min(g, cap(GEMS_KEY)) }) end
            end
            return out
        end)
        return ok and type(list) == "table" and list or nil
    end
    local function totalOf(list)
        local t = 0
        for _, it in ipairs(list or {}) do t += it.n end
        return t
    end

    -- ของในกระเป๋าที่ trade ได้ ส่งขึ้นเว็บ (detail.bag) ให้เลือกของเองในป๊อปอัป Auto Trade
    --   ไม่ดูตัวกรอง rarity / ตัวละครก่อน (rarity สูงก่อน) แล้วของอื่น / ไม่เกิน 200 กอง / จำไว้ 30 วิ
    --   hi = ตัวละคร rarity สูงกว่า Mythical (ตามลำดับ MineConfig.RarityOrder)
    local bagCache, bagAt = nil, -math.huge
    local KIND_ORDER = { Character = 1, Pickaxe = 2, Gem = 3 }
    Addon.tradeBag = function()
        if os.clock() - bagAt < 30 and bagCache then return bagCache end
        local mg = Addon.mineGame()
        if type(mg) ~= "table" or not inv then return nil end
        local ok, list = isolated(function()
            local rank = {}
            for i, r in ipairs(RARITIES) do rank[r] = i end
            local myth = rank.Mythical or rank.Mythic or math.huge
            local out, seen = {}, {}
            for _, e in ipairs(inv.Collect(mg, "All")) do
                if type(e) == "table" and type(e.Key) == "string" and not seen[e.Key] and MineConfig.TradeStack(e.Key) then
                    local n = (e.Kind == "Pickaxe" or e.Kind == "BaseSkin") and tonumber(e.Spare) or tonumber(e.Count)
                    n = math.floor(n or 0)
                    if n > 0 then
                        seen[e.Key] = true
                        local r = type(e.Rarity) == "string" and e.Rarity or ""
                        table.insert(out, {
                            k = e.Key, n = n, kind = tostring(e.Kind or ""), name = tostring(e.Display or e.Name or e.Key),
                            r = r, lv = tonumber(e.Level), v = type(e.Variant) == "string" and e.Variant or nil,
                            img = tostring(e.Image or ""):match("(%d+)"),
                            hi = e.Kind == "Character" and (rank[r] or 0) > myth or nil,
                            _rk = rank[r] or 0,
                        })
                    end
                end
            end
            if not seen[GEMS_KEY] and MineConfig.TradeStack(GEMS_KEY) then
                local g = math.floor(tonumber(MineConfig.GetGemCount(mg)) or 0)
                if g > 0 then table.insert(out, { k = GEMS_KEY, n = g, kind = "Gem", name = GEMS_KEY, r = "", _rk = 0 }) end
            end
            table.sort(out, function(a, b)
                local ka, kb = KIND_ORDER[a.kind] or 9, KIND_ORDER[b.kind] or 9
                if ka ~= kb then return ka < kb end
                if a._rk ~= b._rk then return a._rk > b._rk end
                return a.name < b.name
            end)
            for i = #out, 201, -1 do out[i] = nil end
            for _, it in ipairs(out) do it._rk = nil end
            return out
        end)
        if ok and type(list) == "table" then bagCache, bagAt = list, os.clock() end
        return bagCache
    end

    local REASON = {
        noinv = "อ่านกระเป๋าไม่ได้", notarget = "ตัวรับไม่ได้อยู่ในเซิร์ฟเวอร์นี้",
        busy = "ตัวรับยังไม่ว่าง / ยังไม่ปลดล็อค trade", noresponse = "ตัวรับไม่รับคำขอ",
        cancelled = "ห้อง trade ถูกปิดกลางทาง", noready = "กดพร้อมไม่สำเร็จ", noconfirm = "ยืนยันไม่สำเร็จ",
    }

    -- trade 1 รอบ -> "ok", จำนวนกอง / "empty" / เหตุผลที่พลาด
    local function tradeRound(job, alive)
        local items = collectItems()
        if not items then return "noinv" end
        if #items == 0 then return "empty" end
        local target = Players:GetPlayerByUserId(job.to)
        if not target then return "notarget" end
        if not waitFor(function()
            return target.Parent ~= nil and target:GetAttribute("MineTradeOpen") == true
                and target:GetAttribute("MineTradeBusy") ~= true
        end, 30, alive) then return "busy" end

        local asked = os.clock()
        fire("MineTradeRequest", job.to)
        local s = waitFor(function()
            local x = sync
            return x and syncAt > asked and type(x.SessionId) == "number" and not closed[x.SessionId]
                and x.Stage == "negotiate" and x or nil
        end, 35, alive)
        if not s then return "noresponse" end
        local sid = s.SessionId

        -- ใส่ของ (ไม่เกิน 8 กอง)
        local edit, put = tonumber(s.LastEditId) or 0, 0
        for i, it in ipairs(items) do
            if i > MAX_STACKS or not alive() then break end
            edit += 1
            fire("MineTradeSetItem", it.key, it.n, sid, edit)
            put += 1
            task.wait(0.25)
        end
        waitFor(function()
            local x = sync
            return x and x.SessionId == sid and (tonumber(x.LastEditId) or 0) >= edit
        end, 8, alive)

        -- พร้อม -> รอเข้าขั้นยืนยัน
        local r = waitFor(function()
            local x = sync
            if closed[sid] then return "gone" end
            if not x or x.SessionId ~= sid then return nil end
            if x.Stage ~= "negotiate" then return "next" end
            if not x.MeReady and os.clock() - syncAt >= (tonumber(x.ReadyAfter) or 0) then
                fire("MineTradeReady", true, sid, x.Revision)
                task.wait(0.6)
            end
            return nil
        end, 90, alive)
        if r == "gone" then return "cancelled" end
        if r ~= "next" then fire("MineTradeCancel", sid); return "noready" end

        -- ยืนยัน -> รอบันทึก
        r = waitFor(function()
            local x = sync
            if closed[sid] then return "closed" end
            if not x or x.SessionId ~= sid then return nil end
            if x.Stage == "saving" then return "saving" end
            if x.Stage == "confirm" and not x.MeConfirmed and os.clock() - syncAt >= (tonumber(x.ConfirmAfter) or 0) then
                fire("MineTradeConfirm", sid, x.Revision)
                task.wait(0.6)
            end
            return nil
        end, 90, alive)
        if not r then fire("MineTradeCancel", sid); return "noconfirm" end
        waitFor(function() return closed[sid] end, 20, alive)
        task.wait(2.5)  -- รอข้อมูลกระเป๋าอัปเดต
        return "ok", put
    end

    local function runSender(job, myGen)
        local function alive() return sendGen == myGen end
        jobFilter, jobItems = nil, nil
        if type(job.items) == "table" then
            jobItems = {}
            local n = 0
            for _, k in ipairs(job.items) do
                if type(k) == "string" and not jobItems[k] then jobItems[k] = true; n += 1 end
            end
            say(("ส่งเฉพาะของที่เลือกจากเว็บ %d อย่าง"):format(n))
        elseif type(job.filter) == "table" then
            jobFilter = {}
            for _, kind in ipairs({ "Character", "Pickaxe" }) do
                if type(job.filter[kind]) == "table" then jobFilter[kind] = toSet(job.filter[kind]) end
            end
            local function desc(kind)
                local l = type(job.filter[kind]) == "table" and job.filter[kind] or nil
                if not l then return "ตามในเกม" end
                if #l >= #RARITIES then return "ทั้งหมด" end
                return #l > 0 and table.concat(l, ", ") or "ไม่ส่ง"
            end
            say(("ตัวกรองจากเว็บ · Character: %s · Pickaxe: %s"):format(desc("Character"), desc("Pickaxe")))
        end
        say(("เริ่มส่งของให้ %s"):format(job.name ~= "" and job.name or tostring(job.to)))
        local rounds, stacks, fails = 0, 0, 0
        while alive() and rounds < MAX_ROUNDS do
            local before = totalOf(collectItems())
            local r, n = tradeRound(job, alive)
            if not alive() then break end
            if r == "ok" then
                rounds += 1
                stacks += n
                fails = 0
                say(("trade รอบ %d สำเร็จ (%d กอง)"):format(rounds, n))
                if totalOf(collectItems()) >= before then
                    say("ของที่เหลือย้ายไม่ได้ (server ไม่ให้ trade) หยุด")
                    break
                end
            elseif r == "empty" then
                say(("ส่งของหมดแล้ว · %d รอบ %d กอง"):format(rounds, stacks))
                break
            else
                fails += 1
                if fails >= 3 then
                    say("หยุด: " .. (REASON[r] or tostring(r)))
                    break
                end
                task.wait(5)
            end
        end
        if sendGen == myGen then jobFilter, jobItems = nil, nil; bagAt = -math.huge end
        pcall(function() if isfile(JOB_FILE) then delfile(JOB_FILE) end end)
    end

    local tpPending = false
    pcall(function()
        TeleportService.TeleportInitFailed:Connect(function(plr, result, msg)
            if plr ~= LP or not tpPending then return end
            tpPending = false
            say("วาปไม่สำเร็จ: " .. tostring(msg ~= "" and msg or result))
            pcall(function() if isfile(JOB_FILE) then delfile(JOB_FILE) end end)
        end)
    end)

    local function startSend(cmd)
        sendGen += 1
        local myGen = sendGen
        local job = {
            to = tonumber(cmd.to), name = tostring(cmd.toName or ""),
            job = tostring(cmd.job or ""), place = tonumber(cmd.place) or game.PlaceId, at = os.time(),
            filter = type(cmd.filter) == "table" and cmd.filter or nil,
            items = type(cmd.items) == "table" and cmd.items or nil,
        }
        if not job.to or job.to == LP.UserId then return end
        -- อยู่เซิร์ฟเดียวกันแล้ว -> เริ่มเลย
        if game.JobId == job.job or Players:GetPlayerByUserId(job.to) then
            task.spawn(runSender, job, myGen)
            return
        end
        if job.job == "" then return say("ไม่รู้เซิร์ฟเวอร์ของตัวรับ (ตัวรับยังไม่ได้ส่งสถานะ)") end
        pcall(function()
            if not isfolder("EndHub") then makefolder("EndHub") end
            writefile(JOB_FILE, HttpService:JSONEncode(job))
        end)
        if queueTp then pcall(queueTp, TP_CODE) end
        say("กำลังวาปไปเซิร์ฟเวอร์ของตัวรับ")
        tpPending = true
        local ok, err = pcall(function() TeleportService:TeleportToPlaceInstance(job.place, job.job, LP) end)
        if not ok then
            tpPending = false
            say("วาปไม่ได้: " .. tostring(err))
            pcall(function() if isfile(JOB_FILE) then delfile(JOB_FILE) end end)
        end
    end

    local function stopAll(quiet)
        sendGen += 1
        recvGen += 1
        local wasOn = recv ~= nil
        recv = nil
        local x = sync
        if x and type(x.SessionId) == "number" and not closed[x.SessionId] and x.Stage ~= "saving" then
            fire("MineTradeCancel", x.SessionId)
        end
        pcall(function() if isfile(JOB_FILE) then delfile(JOB_FILE) end end)
        if not quiet and wasOn then say("หยุดรับของแล้ว") end
    end

    -- คำสั่งจาก Hub (ผ่าน WebSocket ของ Weblog)
    Addon.onCmd = function(d)
        if type(d) ~= "table" then return end
        if d.cmd == "send" then
            startSend(d)
        elseif d.cmd == "recv" then
            local from, n = {}, 0
            for _, u in ipairs(type(d.from) == "table" and d.from or {}) do
                local id = tonumber(u)
                if id and id ~= LP.UserId and not from[id] then from[id] = true; n += 1 end
            end
            recvGen += 1
            recv = { from = from, untilAt = os.clock() + math.clamp(tonumber(d.minutes) or 30, 1, 120) * 60 }
            task.spawn(recvLoop, recvGen)
            say(("รอรับของจาก %d ไอดี"):format(n))
        elseif d.cmd == "stop" then
            stopAll(false)
            say("หยุด Auto Trade")
        elseif d.cmd == "rejoin" then
            -- Rejoin จากหน้าเว็บ: กลับเข้าเซิร์ฟเดิม (JobId เดิม) แล้วโหลด End Hub เวอร์ชันล่าสุด
            --   เข้าเซิร์ฟเดิมไม่ได้ (เต็ม / ปิด) -> ไปเซิร์ฟใหม่แทน
            --   (Kaitun ที่เปิดอยู่จำ config ไว้เองตอนวาป ดู Kaitun.setup hopConn)
            if Addon.emit then Addon.emit("info", "Rejoin จากหน้าเว็บ: กำลังโหลดเวอร์ชันใหม่") end
            pcall(function()
                local env = (getgenv and getgenv()) or _G
                env.EndHubAutoRan = nil  -- executor ที่จำ getgenv ข้ามเซิร์ฟ จะได้ไม่ข้ามการโหลด
            end)
            if queueTp then pcall(queueTp, TP_CODE) end
            task.wait(1)  -- ให้ event ส่งถึงเว็บก่อน
            local failConn
            failConn = TeleportService.TeleportInitFailed:Connect(function(plr)
                if plr ~= LP then return end
                failConn:Disconnect()
                if queueTp then pcall(queueTp, TP_CODE) end
                pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
            end)
            local ok = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
            if not ok then
                failConn:Disconnect()
                pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
            end
        end
    end

    -- เพิ่งวาปมา: มีงานค้างในไฟล์ + อยู่เซิร์ฟเวอร์ที่ตั้งใจ -> ทำต่อ
    task.delay(15, function()
        local ok, data = pcall(function()
            return isfile(JOB_FILE) and HttpService:JSONDecode(readfile(JOB_FILE)) or nil
        end)
        if not ok or type(data) ~= "table" then return end
        if os.time() - (tonumber(data.at) or 0) > 900 or data.job ~= game.JobId then
            pcall(function() delfile(JOB_FILE) end)
            return
        end
        sendGen += 1
        task.spawn(runSender, data, sendGen)
    end)

    Addon.stopTrade = function() stopAll(true) end
end
Addon.trade()

----------------------------------------------------------------
-- PERFORMANCE (Settings > Performance) ลด FPS ตก / CPU หนัก
--   FPS Boost: ใช้ระบบซ่อนของเกมเอง (MineLagToggles = เมนูลดแลคในตั้งค่าของเกม)
--     plot / ผู้เล่น -> "Others" = ซ่อนของคนอื่นทั้งหมด (แมพ หิน miner เอฟเฟกต์ อวตาร) plot เรายังเห็นปกติ
--     ทั้งโลก -> "Hide" = อากาศ particle ใน hub เอฟเฟกต์จอ
--     ปิด = คืนค่าเดิมที่ตั้งไว้ก่อนเปิด  (เป็นการตั้งค่าฝั่งเครื่องเรา ไม่กระทบการฟาร์ม)
--   Disable 3D: ไม่วาดภาพเลย (จอดำ / เกมยังทำงาน) ประหยัด CPU/GPU มากสุด เหมาะกับฟาร์มหลายจอ
--   FPS Cap: จำกัด FPS ด้วย setfpscap ของ executor (0 = ไม่จำกัด)
----------------------------------------------------------------
Addon.perf = function()
    local section = Settings:AddSection("Performance")
    local lag = nil
    pcall(function() lag = require(RS:WaitForChild("Modules"):WaitForChild("MineLagToggles")) end)
    local saved = nil  -- ค่าเดิมก่อนเปิด FPS Boost { [key] = scope }

    local function boost(on)
        if type(lag) ~= "table" or type(lag.ROWS) ~= "table" then
            return Velvet:Notify({ Title = "FPS Boost", Content = "หาระบบลดแลคของเกมไม่เจอ", Duration = 4, Type = "error" })
        end
        if on then
            if saved then return end
            saved = {}
            for _, row in ipairs(lag.ROWS) do
                local key, want = row.Key, (row.Kind == "world") and "Hide" or "Others"
                local okG, cur = isolated(function() return lag.Get(key) end)
                saved[key] = okG and cur or "Show"
                if cur ~= want and cur ~= "All" then
                    isolated(function() lag.Set(key, want) end)
                end
            end
            Velvet:Notify({ Title = "FPS Boost", Content = "ซ่อน plot / ผู้เล่นคนอื่น + เอฟเฟกต์โลกแล้ว", Duration = 3, Type = "success" })
        elseif saved then
            for key, scope in pairs(saved) do
                isolated(function() lag.Set(key, scope) end)
            end
            saved = nil
        end
    end

    local function set3d(on)
        pcall(function() game:GetService("RunService"):Set3dRenderingEnabled(not on) end)
    end

    -- Hide Damage Numbers (ค่าเริ่มต้นเปิด): ปิดตัวเลขดาเมจที่เด้งจากหิน = แถว "Damage numbers" ในเมนูลดแลคของเกม
    --   ตั้งเป็น "All" (ทุก plot รวมของเรา) ; เกมโหลดค่าตั้งค่าทับ (lag.Changed) = ตั้งกลับให้เอง ; ปิด toggle = คืนค่าเดิม
    local dmgSaved, dmgConn = nil, nil
    local function hideDamage(on)
        if type(lag) ~= "table" or type(lag.Set) ~= "function" then return end
        if on then
            if dmgSaved == nil then
                local okG, cur = isolated(function() return lag.Get("Damage") end)
                dmgSaved = okG and cur or "Show"
            end
            isolated(function() lag.Set("Damage", "All") end)
            local changed: any = lag.Changed
            if not dmgConn and typeof(changed) == "Instance" and changed:IsA("BindableEvent") then
                dmgConn = changed.Event:Connect(function(key)
                    if (key == "*" or key == "Damage") and Velvet.Flags["PerfHideDamage"] ~= false then
                        task.defer(function()
                            local okG, cur = isolated(function() return lag.Get("Damage") end)
                            if okG and cur ~= "All" then isolated(function() lag.Set("Damage", "All") end) end
                        end)
                    end
                end)
            end
        else
            if dmgConn then dmgConn:Disconnect(); dmgConn = nil end
            if dmgSaved ~= nil then
                local back = dmgSaved
                dmgSaved = nil
                isolated(function() lag.Set("Damage", back) end)
            end
        end
    end

    local capSet = false
    local function applyCap()
        local cap = tonumber(Velvet.Flags["PerfFpsCap"]) or 0
        if type(setfpscap) ~= "function" then return end
        if cap > 0 then
            capSet = pcall(setfpscap, cap)
        elseif capSet then
            pcall(setfpscap, 0)
            capSet = false
        end
    end

    section:AddToggle("PerfBoost", {
        Text = "FPS Boost",
        Default = false,
        Callback = function(on) boost(on == true) end,
    })
    section:AddToggle("PerfHideDamage", {
        Text = "Hide Damage Numbers",
        Default = true,
        Callback = function(on) hideDamage(on == true) end,
    })
    -- เผื่อ toggle ไม่เรียก Callback ตอนสร้าง
    task.delay(3, function() if Velvet.Flags["PerfHideDamage"] ~= false then hideDamage(true) end end)
    section:AddToggle("PerfNo3D", {
        Text = "Disable 3D Rendering",
        Default = false,
        Callback = function(on) set3d(on == true) end,
    })
    section:AddSlider("PerfFpsCap", {
        Text = "FPS Cap",
        Min = 0, Max = 240, Default = 0, Increment = 5,
        Callback = function() applyCap() end,
    })
    Velvet:OnFlagChanged("PerfFpsCap", function() applyCap() end)

    -- FPS Cap แบบ loop: ตั้งซ้ำทุก 1 วิ (เกม / executor บางตัวรีเซ็ต fps เอง)
    local startCapLoop, stopCapLoop = makeLoop(function()
        local cap = tonumber(Velvet.Flags["PerfFpsCap"]) or 0
        if cap > 0 and type(setfpscap) == "function" then capSet = pcall(setfpscap, cap) end
    end, function() return 1 end)
    startCapLoop()

    -- Anti Lag: ลดภาระเครื่อง (ฝั่งเราเท่านั้น ไม่กระทบการฟาร์ม)
    --   คุณภาพกราฟิกต่ำสุด, ปิดเงา, ปิด particle / trail / beam / ควัน / ไฟ (รวมของที่เกิดใหม่)
    --   ปิด = คืนค่าเดิม
    local FX = { ParticleEmitter = true, Trail = true, Beam = true, Smoke = true, Fire = true, Sparkles = true }
    local lagSaved, lagConn = nil, nil
    local function antiLag(on)
        local Lighting = game:GetService("Lighting")
        if on then
            if lagSaved then return end
            lagSaved = { fx = setmetatable({}, { __mode = "k" }) }  -- weak: effect ที่ถูกลบไปแล้วไม่ค้างในแรม
            pcall(function()
                lagSaved.quality = settings().Rendering.QualityLevel
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end)
            pcall(function() lagSaved.shadows = Lighting.GlobalShadows; Lighting.GlobalShadows = false end)
            local function kill(d)
                if FX[d.ClassName] and d.Enabled then
                    lagSaved.fx[d] = true
                    d.Enabled = false
                end
            end
            for _, d in ipairs(workspace:GetDescendants()) do pcall(kill, d) end
            lagConn = workspace.DescendantAdded:Connect(function(d)
                if lagSaved and FX[d.ClassName] then task.defer(pcall, kill, d) end
            end)
        elseif lagSaved then
            if lagConn then lagConn:Disconnect(); lagConn = nil end
            pcall(function() settings().Rendering.QualityLevel = lagSaved.quality end)
            pcall(function() Lighting.GlobalShadows = lagSaved.shadows end)
            for d in pairs(lagSaved.fx) do pcall(function() if d.Parent then d.Enabled = true end end) end
            lagSaved = nil
        end
    end
    section:AddToggle("PerfAntiLag", {
        Text = "Anti Lag",
        Default = false,
        Callback = function(on) antiLag(on == true) end,
    })

    -- ปิด End Hub: คืนทุกอย่าง
    Addon.stopPerf = function()
        boost(false)
        hideDamage(false)
        set3d(false)
        antiLag(false)
        stopCapLoop()
        if capSet then pcall(setfpscap, 0); capSet = false end
    end
end
Addon.perf()

----------------------------------------------------------------
-- CODES (แท็บ Rewards)
-- remote: Event:FireServer("UseCode", code)   (ปุ่ม Claim ในหน้าต่าง Codes ของเกม)
--   server ตรวจโค้ดเอง (client ไม่มีรายชื่อโค้ด) ผลส่งกลับเป็นข้อความแจ้งเตือน (Remotes.SendNotification)
--   โค้ดที่ใช้แล้วเกมจำไว้ที่ Data.Codes -> ข้าม
--   1. ช่อง Codes + ปุ่ม Redeem: ใส่หลายโค้ดได้ (คั่นด้วยช่องว่าง , ; หรือขึ้นบรรทัด) เว้นโค้ดละ ~1 วิ
--   2. Auto Redeem: ดึงรายชื่อโค้ดจาก Worker (GET /codes แอดมินตั้งด้วย ./admin.sh codes-set) ทุก 30 นาที
--      ใช้เฉพาะโค้ดที่ยังไม่เคยลอง (จำใน EndHub/codes_tried.json)
----------------------------------------------------------------
Addon.codes = function()
    local API_URL = "https://endhub.kantapongboontawin1.workers.dev"
    local TRIED_FILE = "EndHub/codes_tried.json"
    local section = rewardTab:AddSection("Codes")
    local para = section:AddParagraph({ Title = "Codes", Content = "Idle" })
    local httpRequest = request or http_request or (syn and syn.request) or (http and http.request)

    local tried = {}  -- [โค้ดตัวเล็ก] = ผล
    pcall(function()
        if isfile(TRIED_FILE) then
            local d = HttpService:JSONDecode(readfile(TRIED_FILE))
            if type(d) == "table" then tried = d end
        end
    end)
    local function saveTried()
        pcall(function()
            if not isfolder("EndHub") then makefolder("EndHub") end
            writefile(TRIED_FILE, HttpService:JSONEncode(tried))
        end)
    end

    -- ข้อความแจ้งเตือนล่าสุดจากเกม (ผลของ UseCode)
    local lastNote = nil
    pcall(function()
        for _, name in ipairs({ "SendNotification", "SendImportantNotification" }) do
            local remote = RS.Remotes:FindFirstChild(name)
            if remote then
                remote.OnClientEvent:Connect(function(msg)
                    local text = type(msg) == "table" and (msg.Text or msg.Message or msg[1]) or msg
                    if text ~= nil then lastNote = { text = tostring(text):gsub("<[^>]+>", ""), at = os.clock() } end
                end)
            end
        end
    end)

    local function usedCode(code)
        Addon.mineGame()
        local codes = nil
        pcall(function()
            local players = type(Addon.gs) == "table" and rawget(Addon.gs, "Players")
            local me = type(players) == "table" and players[tostring(LP.UserId)]
            codes = type(me) == "table" and type(me.Data) == "table" and me.Data.Codes or nil
        end)
        if type(codes) ~= "table" then return false end
        local low = code:lower()
        for k, v in pairs(codes) do
            if tostring(k):lower() == low or (type(v) == "string" and v:lower() == low) then return true end
        end
        return false
    end

    local function parse(text)
        local list, seen = {}, {}
        for c in tostring(text or ""):gmatch("[^%s,;]+") do
            if #c <= 40 and not seen[c:lower()] then
                seen[c:lower()] = true
                table.insert(list, c)
            end
        end
        return list
    end

    local busy = false
    -- ใช้โค้ดทีละตัว -> รายการผล  (auto = ข้ามโค้ดที่เคยลองแล้ว)
    local function redeem(list, auto)
        if busy then return nil end
        busy = true
        local lines, good = {}, 0
        for _, code in ipairs(list) do
            local low = code:lower()
            if usedCode(code) then
                tried[low] = tried[low] or "already used"
                if not auto then table.insert(lines, code .. ": already used") end
            elseif not (auto and tried[low]) then
                local t0 = os.clock()
                fire("UseCode", code)
                while os.clock() - t0 < 3 and not (lastNote and lastNote.at >= t0) do task.wait(0.1) end
                local msg = (lastNote and lastNote.at >= t0) and lastNote.text or nil
                if usedCode(code) then
                    good += 1
                    msg = msg or "redeemed"
                end
                msg = msg or "no reply"
                tried[low] = msg
                table.insert(lines, code .. ": " .. msg)
                task.wait(1)
            end
        end
        saveTried()
        busy = false
        if good > 0 and Addon.emit then Addon.emit("info", ("ใช้โค้ดสำเร็จ %d โค้ด"):format(good)) end
        return lines
    end

    section:AddInput("RedeemCodes", { Text = "Codes", Placeholder = "CODE1 CODE2 ..." })
    section:AddButton({
        Text = "Redeem Codes",
        Callback = function()
            local list = parse(Velvet.Flags["RedeemCodes"])
            if #list == 0 then return para:Set("ยังไม่ได้ใส่โค้ด") end
            para:Set(("กำลังใช้ %d โค้ด..."):format(#list))
            task.spawn(function()
                local lines = redeem(list, false)
                if lines then para:Set(#lines > 0 and table.concat(lines, "\n") or "ไม่มีโค้ดที่ต้องใช้") end
            end)
        end,
    })

    -- Auto Redeem: รายชื่อโค้ดจาก Worker
    local function autoPass()
        if not httpRequest then return para:Set("executor นี้ไม่รองรับ request()") end
        local ok, res = pcall(httpRequest, { Url = API_URL .. "/codes", Method = "GET" })
        local data = nil
        if ok and type(res) == "table" then
            local okJ, d = pcall(HttpService.JSONDecode, HttpService, res.Body)
            data = okJ and type(d) == "table" and d or nil
        end
        if not data or type(data.codes) ~= "table" then return para:Set("ดึงรายชื่อโค้ดไม่ได้ ลองใหม่รอบหน้า") end
        local list = {}
        for _, c in ipairs(data.codes) do if type(c) == "string" then table.insert(list, c) end end
        local lines = redeem(list, true)
        if not lines then return end
        para:Set((#lines > 0 and table.concat(lines, "\n") or ("ไม่มีโค้ดใหม่ (มีทั้งหมด %d โค้ด)"):format(#list))
            .. "\nเช็คล่าสุด " .. os.date("%H:%M"))
    end
    local startAuto, stopAuto = makeLoop(autoPass, function() return 1800 end)
    section:AddToggle("AutoRedeemCodes", {
        Text = "Auto Redeem New Codes",
        Default = false,
        Callback = function(on) if on then startAuto() else stopAuto() end end,
    })
    Addon.stopCodes = stopAuto
end
Addon.codes()

----------------------------------------------------------------
-- AUTO MUTATION (แท็บ Miner > Mutation)
-- remote: Event:FireServer("MineRollMutation", padId)        เช่น "M3" (ปุ่ม Roll ในหน้า slot ของเกม)
-- ผล:     Remotes.MineFX.OnClientEvent({ t = "mutation", key = padId, variant = "Rainbow" } / { refused = true })
--   variant ของ miner ตอนนี้ = MineGame.Holders[pad].CharVariant (ไม่มี = "Normal")
--   ลำดับ variant = MineConfig.GetVariantLadder(): Normal < Bronze < Diamond < Platinum < Rainbow < Frozen
--                   < Inferno < Nightmare < Unreal < Unleashed < Paradox  (2 ตัวท้ายสุ่มไม่ได้ Chance = 0)
--   ราคาต่อครั้ง = MineConfig.GetMutationRollCost(item, mineGame) จ่ายด้วยเงินในเกม
--
--   1. ปุ่ม "Mutation Config" -> หน้าต่างการ์ด: กดการ์ด miner = เลือกตัวที่จะสุ่ม / แถวบน = เลือก variant เป้าหมาย
--   2. Auto Mutation: ไล่ทีละตัวที่เลือก สุ่มจน variant >= เป้าหมาย แล้วไปตัวถัดไป
--      ตัวที่ถึงเป้าแล้ว (หรือสูงกว่า) ไม่สุ่ม / เงินไม่พอ = ข้ามไปตัวที่จ่ายไหว (ไม่มีเลย = รอ)
--      server ปฏิเสธ = ข้ามตัวนั้น (จำเป็น pad + ชื่อ: เปลี่ยนตัวบน pad = ลองใหม่)
--      ครบทุกตัว = ปิด toggle เอง (โหมดทุกตัว = ไม่ปิด รอ miner ใหม่)
--   3. ที่เลือกไว้เซฟลง EndHubData/mutation.json
--   4. Addon.mutationSet({ all = true, target = "Bronze" }) (Kaitun ใช้ตาม cfg.Mutation)
--      all = ทุกตัวบน pad รวมตัวที่ Smart Equip ใส่ทีหลัง (ไม่เซฟลงไฟล์ กดการ์ด / Clear = ออกจากโหมดนี้)
----------------------------------------------------------------
Addon.mutation = function()
    local section = MinerTab:AddSection("Mutation")
    local FILE = "EndHubData/mutation.json"
    local GUI_NAME = "EndHub_Mutation"
    local para = section:AddParagraph({ Title = "Mutation", Content = "ปิดอยู่" })

    -- variant ที่สุ่มได้ (Chance > 0) เรียงจากต่ำไปสูง + rank ของทุก variant
    local ladder, rankOf = {}, { Normal = 1 }
    do
        local ok, list = isolated(function() return MineConfig.GetVariantLadder() end)
        for i, v in ipairs(ok and type(list) == "table" and list or {}) do
            if type(v) == "table" and type(v.VariantName) == "string" then
                rankOf[v.VariantName] = i
                if (tonumber(v.Chance) or 0) > 0 then
                    table.insert(ladder, { name = v.VariantName, chance = tonumber(v.Chance), mult = tonumber(v.Mult) or 1 })
                end
            end
        end
    end
    local COLORS = {
        Normal = Color3.fromRGB(150, 150, 160), Bronze = Color3.fromRGB(205, 127, 50), Diamond = Color3.fromRGB(120, 220, 255),
        Platinum = Color3.fromRGB(225, 230, 240), Rainbow = Color3.fromRGB(255, 120, 200), Frozen = Color3.fromRGB(140, 200, 255),
        Inferno = Color3.fromRGB(255, 110, 60), Nightmare = Color3.fromRGB(170, 90, 255), Unreal = Color3.fromRGB(255, 215, 90),
        Unleashed = Color3.fromRGB(255, 80, 80), Paradox = Color3.fromRGB(120, 255, 190),
    }

    -------------------- ที่เลือกไว้ --------------------
    local picked, target = {}, ladder[1] and ladder[1].name or "Bronze"
    local allMode = false  -- true = ทุกตัวบน pad (ตั้งจาก Addon.mutationSet ไม่เซฟลงไฟล์)
    local function isPicked(pad) return allMode or picked[pad] == true end
    pcall(function()
        if not isfile(FILE) then return end
        local d = HttpService:JSONDecode(readfile(FILE))
        if type(d) ~= "table" then return end
        for _, pad in ipairs(type(d.pads) == "table" and d.pads or {}) do
            if type(pad) == "string" then picked[pad] = true end
        end
        if type(d.target) == "string" and rankOf[d.target] then target = d.target end
    end)
    local function save(flagsOnly)
        local pads = {}
        for pad in pairs(picked) do table.insert(pads, pad) end
        table.sort(pads)
        Velvet.Flags["MutationPads"] = pads
        Velvet.Flags["MutationTarget"] = target
        Velvet.Flags["MutationAll"] = allMode
        if flagsOnly then return end
        pcall(function()
            if not isfolder("EndHubData") then makefolder("EndHubData") end
            writefile(FILE, HttpService:JSONEncode({ pads = pads, target = target }))
        end)
    end

    -------------------- อ่าน state --------------------
    local function padNum(pad) return tonumber(tostring(pad):match("%d+")) or 0 end
    -- miner บน plot { pad, name, variant, image } เรียงตามเลข pad
    local function miners()
        local mg = Addon.mineGame()
        local list = {}
        for pad, h in pairs(mg and type(mg.Holders) == "table" and mg.Holders or {}) do
            if type(pad) == "string" and pad:sub(1, 1) == "M" and type(h) == "table"
                and type(h.CharName) == "string" and h.CharName ~= "" then
                local def = getCharDef(h.CharName)
                if not (def and def.MineRole == "Hauler") then
                    local variant = (type(h.CharVariant) == "string" and h.CharVariant ~= "") and h.CharVariant or "Normal"
                    table.insert(list, {
                        pad = pad, name = h.CharName, variant = variant, def = def,
                        image = def and tostring(def.ImageId or ""):match("(%d+)") or nil,
                    })
                end
            end
        end
        table.sort(list, function(a, b) return padNum(a.pad) < padNum(b.pad) end)
        return list, mg
    end
    local function reached(variant)
        return (rankOf[variant] or 0) >= (rankOf[target] or math.huge)
    end
    local function rollCost(m, mg)
        if not m.def then return nil end
        local ok, c = isolated(function() return MineConfig.GetMutationRollCost(m.def, mg) end)
        return ok and tonumber(c) or nil
    end

    -------------------- ผลจาก server --------------------
    local last = nil  -- { key, variant, refused, at }
    pcall(function()
        RS.Remotes.MineFX.OnClientEvent:Connect(function(p)
            if type(p) == "table" and p.t == "mutation" then
                last = { key = p.key, variant = p.variant, refused = p.refused == true, at = os.clock() }
            end
        end)
    end)

    -------------------- ลูปสุ่ม --------------------
    local on, rolls, spent = false, 0, 0
    local skipped = {}  -- [pad|ชื่อ] = true (server ปฏิเสธ) เปลี่ยนตัวบน pad = ลองใหม่
    local function skipKey(m) return m.pad .. "|" .. m.name end
    local setAuto, refreshGui = nil, nil
    local reportedDone = false  -- โหมดทุกตัว: แจ้ง "ครบ" ครั้งเดียวจนกว่าจะมีตัวใหม่ให้สุ่ม
    local ROLL_PER_MIN = 10     -- ยิงสุ่มได้ไม่เกินกี่ครั้งใน 1 นาที (นับทุกครั้งที่ยิง รวมที่ server ปฏิเสธ)
    local rollTimes = {}        -- os.clock() ของการยิงแต่ละครั้งในนาทีนี้ (เรียงตามเวลา)

    local function pass(alive)
        local list, mg = miners()
        if not mg then return para:Set("รอข้อมูลจากเกม...") end
        -- ตัวแรก (เรียงตาม pad) ที่ยังไม่ถึงเป้า + จ่ายไหว / ไม่มีเลย = ข้อความรอของตัวแรกที่ติด
        local todo, cost, waitMsg = nil, nil, nil
        local cash = getCash()
        for _, m in ipairs(list) do
            if isPicked(m.pad) and not skipped[skipKey(m)] and not reached(m.variant) then
                local c = rollCost(m, mg)
                if c and cash and cash < c then
                    waitMsg = waitMsg or ("%s %s: เงินไม่พอ (%s / %s) รอเงิน"):format(m.pad, m.name, short(cash), short(c))
                elseif c and not Kaitun.allow("Miner", c) then
                    waitMsg = waitMsg or ("%s %s: Kaitun เก็บเงินไว้ก่อน (%s / roll)"):format(m.pad, m.name, short(c))
                else
                    todo, cost = m, c
                    break
                end
            end
        end
        if not todo then
            if waitMsg then return para:Set(waitMsg) end
            if allMode then
                -- ทุกตัวบน pad: ไม่ปิด toggle รอ Smart Equip ใส่ตัวใหม่
                para:Set(("ครบแล้ว: ทุกตัวบน pad ได้ %s ขึ้นไป · สุ่มไป %d ครั้ง · รอ miner ใหม่"):format(target, rolls))
                if not reportedDone and Addon.emit and rolls > 0 then
                    Addon.emit("info", ("Auto Mutation ครบ (%s) %d ครั้ง"):format(target, rolls))
                end
                reportedDone = true
                return
            end
            local any = next(picked) ~= nil
            para:Set(any and ("ครบแล้ว: ทุกตัวที่เลือกได้ %s ขึ้นไป · สุ่มไป %d ครั้ง"):format(target, rolls)
                or "ยังไม่ได้เลือก miner (กด Mutation Config)")
            if any and Addon.emit and rolls > 0 then Addon.emit("info", ("Auto Mutation ครบ (%s) %d ครั้ง"):format(target, rolls)) end
            task.defer(setAuto, false)
            return
        end
        reportedDone = false

        -- เพดาน: ไม่เกิน ROLL_PER_MIN ครั้งใน 60 วินาทีล่าสุด
        local tNow = os.clock()
        while rollTimes[1] and tNow - rollTimes[1] >= 60 do table.remove(rollTimes, 1) end
        if #rollTimes >= ROLL_PER_MIN then
            return para:Set(("ถึงลิมิต %d ครั้ง/นาที รออีก %d วิ · สุ่มไปแล้ว %d ครั้ง"):format(
                ROLL_PER_MIN, math.ceil(60 - (tNow - rollTimes[1])), rolls))
        end
        table.insert(rollTimes, tNow)

        local t0 = os.clock()
        fire("MineRollMutation", todo.pad)
        while os.clock() - t0 < 5 and alive() and not (last and last.at >= t0 and last.key == todo.pad) do task.wait(0.1) end
        local res = (last and last.at >= t0 and last.key == todo.pad) and last or nil
        if res and res.refused then
            skipped[skipKey(todo)] = true
            return para:Set(("%s %s: server ไม่ให้สุ่ม (ข้ามตัวนี้)"):format(todo.pad, todo.name))
        end
        if not res then
            return para:Set(("%s %s: ยิงสุ่มแล้วไม่มีผลตอบ จะลองใหม่"):format(todo.pad, todo.name))
        end
        rolls += 1
        spent += cost or 0
        local got = tostring(res.variant or "?")
        para:Set(("%s %s: ได้ %s (เป้า %s) · สุ่ม %d ครั้ง ใช้เงิน %s"):format(todo.pad, todo.name, got, target, rolls, short(spent)))
        if reached(got) and Addon.emit then
            Addon.emit("info", ("%s %s ได้ mutation %s"):format(todo.pad, todo.name, got))
        end
        if refreshGui then pcall(refreshGui) end
        -- ไม่ต้อง wait เพิ่ม: loop ด้านล่างรอ ROLL_GAP วิก่อนรอบถัดไป (state ของ Holders อัปเดตทันก่อนถึงรอบนั้น)
    end

    -- ห่างระหว่างรอบ 2 วิ (รอบที่ไม่ได้สุ่มก็เช็คทุก 2 วิ ไม่ถี่)
    local start, stop = makeLoop(pass, function() return 2 end)
    local autoToggle, autoBtn = nil, nil
    local function paintBtn()
        if not autoBtn then return end
        autoBtn.Text = on and "Auto Roll: ON" or "Auto Roll: OFF"
        autoBtn.BackgroundColor3 = on and C.picked or C.card
        autoBtn.TextColor3 = on and C.bg or C.text
    end
    local function apply(v)
        on = v == true
        if on then
            rolls, spent, skipped, reportedDone = 0, 0, {}, false
            table.clear(rollTimes)
            para:Set("กำลังเริ่ม...")
            start()
        else
            stop()
        end
        paintBtn()
    end
    setAuto = function(v)
        local elem = autoToggle
        if not (type(elem) == "table" and elem.Set) then
            elem = Velvet._elements and Velvet._elements["AutoMutation"]
        end
        if type(elem) == "table" and elem.Set then pcall(function() elem:Set(v) end) end
        apply(v)
    end

    -------------------- หน้าต่างการ์ด --------------------
    local W, H, CW, CH = 660, 480, 148, 172
    local function build()
        local parent = getGuiParent()
        pcall(function()
            local old = parent:FindFirstChild(GUI_NAME)
            if old then old:Destroy() end
        end)
        local gui = make("ScreenGui", {
            Name = GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true,
            DisplayOrder = 2147483647, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        }, nil)
        if not pcall(function() gui.Parent = parent end) then gui.Parent = LP:WaitForChild("PlayerGui") end
        local win = make("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(W, H), BackgroundColor3 = C.bg, Active = true,
        }, gui)
        round(win, 12)
        outline(win)
        local scale = make("UIScale", {}, win)
        local cam = workspace.CurrentCamera
        local function fit()
            local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
            scale.Scale = math.clamp(math.min((vp.X - 24) / W, (vp.Y - 24) / H), 0.5, 1)
        end
        fit()
        local conns = {}
        if cam then table.insert(conns, cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)) end

        local dragArea = make("Frame", { Size = UDim2.new(1, -330, 0, 56), BackgroundTransparency = 1 }, win)
        makeLogo(win, 24, 2).Position = UDim2.fromOffset(16, 16)
        label(win, "End Hub", { Position = UDim2.fromOffset(48, 11), Size = UDim2.fromOffset(120, 20), Font = Enum.Font.GothamBold, TextSize = 17 })
        local subLabel = label(win, "Mutation", { Position = UDim2.fromOffset(48, 31), Size = UDim2.fromOffset(280, 16), TextSize = 12, TextColor3 = C.sub })
        local closeBtn = make("TextButton", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 15), Size = UDim2.fromOffset(24, 24),
            AutoButtonColor = false, BackgroundColor3 = C.close, Text = "X",
            Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.picked,
        }, win)
        round(closeBtn, 6)
        local btnAuto = button(win, "Auto Roll: OFF", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -48, 0, 12), Size = UDim2.fromOffset(110, 30) })
        local btnAll = button(win, "All", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -166, 0, 12), Size = UDim2.fromOffset(48, 30) })
        local btnClear = button(win, "Clear", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -220, 0, 12), Size = UDim2.fromOffset(58, 30) })
        make("Frame", { Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 1), BackgroundColor3 = C.line, BorderSizePixel = 0 }, win)

        -- แถวเลือก variant เป้าหมาย
        label(win, "Stop at", { Position = UDim2.fromOffset(16, 66), Size = UDim2.fromOffset(52, 26), TextSize = 12, TextColor3 = C.sub })
        local chipRow = make("Frame", { Position = UDim2.fromOffset(70, 66), Size = UDim2.new(1, -84, 0, 26), BackgroundTransparency = 1 }, win)
        make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, chipRow)
        local chips = {}
        local refresh
        for i, v in ipairs(ladder) do
            local chip = button(chipRow, v.name, { LayoutOrder = i, Size = UDim2.fromOffset(66, 26), TextSize = 11 })
            chips[v.name] = chip
            chip.MouseButton1Click:Connect(function()
                target = v.name
                save()
                refresh()
            end)
        end

        local grid = make("ScrollingFrame", {
            Position = UDim2.fromOffset(12, 102), Size = UDim2.new(1, -20, 1, -114),
            BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = C.stroke,
        }, win)
        make("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }, grid)
        make("UIGridLayout", {
            CellSize = UDim2.fromOffset(CW, CH), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
        }, grid)

        local cards = {}  -- [pad] = { card, stroke, check, name, variant, image, state, key }
        local function cardFor(pad)
            local c = cards[pad]
            if c then return c end
            local card = make("TextButton", { LayoutOrder = padNum(pad), AutoButtonColor = false, Text = "", BackgroundColor3 = C.card }, grid)
            round(card, 10)
            c = { card = card, stroke = outline(card) }
            label(card, pad, { Position = UDim2.fromOffset(9, 7), Size = UDim2.fromOffset(40, 14), TextSize = 11, TextColor3 = C.dim, Font = Enum.Font.GothamMedium })
            c.check = make("Frame", {
                AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(20, 20),
                BackgroundColor3 = C.picked, Visible = false,
            }, card)
            round(c.check, 10)
            label(c.check, "✓", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.bg })
            c.image = make("ImageLabel", {
                AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.fromOffset(64, 64),
                BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
            }, card)
            c.name = label(card, "", {
                Position = UDim2.new(0, 6, 0, 92), Size = UDim2.new(1, -12, 0, 16),
                TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, TextScaled = true,
            })
            make("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, c.name)
            c.variant = label(card, "", {
                Position = UDim2.new(0, 6, 0, 112), Size = UDim2.new(1, -12, 0, 16),
                TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, TextSize = 13,
            })
            c.state = label(card, "", {
                Position = UDim2.new(0, 6, 0, 134), Size = UDim2.new(1, -12, 0, 28),
                TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
                TextSize = 11, TextColor3 = C.sub, TextWrapped = true,
            })
            card.MouseButton1Click:Connect(function()
                if allMode then
                    -- ออกจากโหมดทุกตัว: เริ่มจากเลือกทุกตัวที่อยู่ตอนนี้ แล้วค่อยสลับตัวที่กด
                    allMode = false
                    for _, m in ipairs((miners())) do picked[m.pad] = true end
                end
                picked[pad] = (not picked[pad]) or nil
                save()
                refresh()
            end)
            card.MouseEnter:Connect(function() card.BackgroundColor3 = C.hover end)
            card.MouseLeave:Connect(function() card.BackgroundColor3 = C.card end)
            cards[pad] = c
            return c
        end

        refresh = function()
            local list, mg = miners()
            local seen = {}
            for _, m in ipairs(list) do
                seen[m.pad] = true
                local c = cardFor(m.pad)
                c.name.Text = m.name
                c.variant.Text = m.variant
                c.variant.TextColor3 = COLORS[m.variant] or C.text
                local img = m.image and ("rbxassetid://" .. m.image) or ""
                if c.image.Image ~= img then c.image.Image = img end
                local sel = isPicked(m.pad)
                c.check.Visible = sel
                c.stroke.Color = sel and C.picked or C.stroke
                c.stroke.Thickness = sel and 1.5 or 1
                if reached(m.variant) then
                    c.state.Text = "ถึงเป้าแล้ว"
                elseif skipped[skipKey(m)] then
                    c.state.Text = "server ไม่ให้สุ่ม"
                else
                    local cost = mg and rollCost(m, mg) or nil
                    c.state.Text = cost and (short(cost) .. " / roll") or ""
                end
            end
            for pad, c in pairs(cards) do
                if not seen[pad] then
                    c.card:Destroy()
                    cards[pad] = nil
                end
            end
            for name, chip in pairs(chips) do
                local sel = name == target
                chip.BackgroundColor3 = sel and (COLORS[name] or C.picked) or C.card
                chip.TextColor3 = sel and C.bg or (COLORS[name] or C.text)
            end
            local n = 0
            for pad in pairs(seen) do if isPicked(pad) then n += 1 end end
            subLabel.Text = ("Mutation · %s %d / %d · หยุดเมื่อได้ %s ขึ้นไป"):format(
                allMode and "ทุกตัว (Kaitun)" or "เลือก", n, #list, target)
        end
        refreshGui = refresh

        closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)
        btnClear.MouseButton1Click:Connect(function()
            allMode = false
            table.clear(picked)
            save()
            refresh()
        end)
        btnAll.MouseButton1Click:Connect(function()
            for _, m in ipairs((miners())) do picked[m.pad] = true end
            save()
            refresh()
        end)
        btnAuto.MouseButton1Click:Connect(function() setAuto(not on) end)
        autoBtn = btnAuto
        paintBtn()

        local dragging, dragStart, startPos = false, nil, nil
        dragArea.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging, dragStart, startPos = true, input.Position, win.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        table.insert(conns, UIS.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end))
        gui.Destroying:Connect(function()
            for _, c in ipairs(conns) do c:Disconnect() end
            if autoBtn == btnAuto then autoBtn = nil end
            if refreshGui == refresh then refreshGui = nil end
        end)

        refresh()
        task.spawn(function()
            while gui.Parent do
                task.wait(2)
                if gui.Enabled and gui.Parent then pcall(refresh) end
            end
        end)
        return gui
    end

    local function toggleGui()
        local gui = Addon.mutGui
        if gui and gui.Parent then
            gui.Enabled = not gui.Enabled
            if gui.Enabled and refreshGui then pcall(refreshGui) end
            return
        end
        local ok, result = pcall(build)
        if ok then
            Addon.mutGui = result
        else
            warn("[End Hub] Mutation error:", result)
            Velvet:Notify({ Title = "Mutation", Content = "เปิดหน้าต่างไม่ได้: " .. tostring(result), Duration = 6, Type = "error" })
        end
    end

    accentButton(section:AddButton({ Text = "Mutation Config", Callback = toggleGui }))
    autoToggle = section:AddToggle("AutoMutation", {
        Text = "Auto Mutation",
        Default = false,
        Callback = apply,
    })
    save()

    -- Kaitun ตั้งตาม cfg.Mutation: { all = true / false, target = "Bronze" }
    --   target ไม่สนตัวพิมพ์ ต้องเป็น variant ที่สุ่มได้ (ไม่งั้นใช้ขั้นต่ำสุดของ ladder) / ไม่เขียนทับไฟล์ที่เลือกไว้
    Addon.mutationSet = function(opts)
        opts = type(opts) == "table" and opts or {}
        if opts.all ~= nil then allMode = opts.all == true end
        if opts.target ~= nil then
            local want, found = tostring(opts.target):lower(), nil
            for _, v in ipairs(ladder) do
                if v.name:lower() == want then found = v.name; break end
            end
            if not found then warn("[End Hub] Mutation: ไม่รู้จัก variant " .. tostring(opts.target) .. " ใช้ขั้นต่ำสุดแทน") end
            target = found or (ladder[1] and ladder[1].name) or "Bronze"
        end
        save(true)
        if refreshGui then pcall(refreshGui) end
        return allMode, target
    end

    Addon.stopMutation = function()
        stop()
        if Addon.mutGui then
            Addon.mutGui:Destroy()
            Addon.mutGui = nil
        end
    end
end
Addon.mutation()

----------------------------------------------------------------
-- SMART EQUIP (แท็บ Miner > Smart Equip) เลือก miner ด้วย rarity + สูตรดาเมจของเกม แล้วเดินไปวางเอง
--   ลำดับการเลือก (ปิด toggle ข้อไหน = ข้ามข้อนั้น):
--     1. "ใส่ตามโซน" (SmartZoneFirst ค่าเริ่มต้นเปิด): ตัวละครแยก list ตาม zone (Addon.zoneChars)
--        ตัวจาก zone ลึกกว่าได้ใส่ก่อน (เปิด zone ถัดไปแล้ว = ใช้ตัว zone ถัดไปแทน)
--        zone เดียวกัน = พลัง base (TierDamage x MineDamageMult) ไม่นับเลเวล / pickaxe
--        zone ของตัว = CharacterPool ของ zone ที่ดรอปตัวนั้น / ไม่มีใน pool = zone จาก tier (charZone)
--     2. zone เท่ากัน = เทียบดาเมจ (แรงกว่าเกิน 2% ถึงเปลี่ยน)
--   สถานะโชว์ zone ที่เราอยู่ตอนนี้ (getCurrentZone) + zone / rarity ของตัวที่เปลี่ยน
--   ดาเมจ = TierDamage[tier] x MineDamageMult x (1 + CharLevelAdd x (เลเวล-1)) x ตัวคูณ variant
--           (pickaxe / enchant ผูกกับ pad เหมือนกันทุกตัว -> ไม่ต้องนับ)
--   ตัวในกระเป๋า: MineGame.Characters key = "ชื่อ|เลเวล|variant|speed|mine" (ชื่อเปล่า = Lv1 Normal)
--   1. หา pad ที่อ่อนสุด vs ตัวในกระเป๋าที่แรงสุด -> แรงกว่าเกิน 2% ถึงเปลี่ยน
--   2. MineAssignHotbar(slot, key) -> MineEquipSlot(slot) = ถือตัวนั้น
--   3. tween (Addon.tweenTo) ไปยืนบน pad -> กด HolderPrompt (server จัดการ)
--      จอง lock เคลื่อนที่ร่วมกับระบบขาย (Addon.sellBusy) ระหว่างใส่ตัว ไม่ให้ทับกัน
--   4. รอ Holders[pad] เปลี่ยน: ได้ตัวใหม่ = สำเร็จ / pad ว่าง (เกมเอาออกแทนสลับ) = ถือตัวใหม่แล้วกดอีกครั้ง
--   ทีละ pad / MinePower ลดหลังเปลี่ยน หรือไม่มีอะไรเปลี่ยน = หยุด
----------------------------------------------------------------
Addon.smartEquip = function()
    local section = troopSection  -- หมวดแรกของแท็บ Miner
    local para = section:AddParagraph({ Title = "Smart Equip", Content = "Idle" })
    local inv = nil
    pcall(function() inv = require(RS:WaitForChild("Modules"):WaitForChild("MineInventory")) end)
    local VMULT = {}
    do
        local ok, list = isolated(function() return MineConfig.GetVariantLadder() end)
        for _, v in ipairs(ok and type(list) == "table" and list or {}) do
            if type(v) == "table" and v.VariantName then VMULT[v.VariantName] = tonumber(v.Mult) or 1 end
        end
    end
    -- ตัว Scaled (rarity "Scaled"): ดาเมจ = พลังอ้างอิงของเรา x ScaledPct (ไม่ได้คิดจาก tier)
    --   = MineConfig.GetScaledReference(MineGame, Items.GetItemData, anyZone).Power x GetScaledPct(def) แบบเดียวกับที่กระเป๋าเกมโชว์
    local function scaledDmg(def)
        local r = def.Rarity
        if type(r) == "table" then r = r.Rarity end
        if r ~= "Scaled" then return nil end
        local mg = Addon.mineGame()
        local ok, v = isolated(function()
            local pct = MineConfig.GetScaledPct(def)
            if not pct then return nil end
            local items = require(RS:WaitForChild("Modules"):WaitForChild("Items"))
            local ref = MineConfig.GetScaledReference(mg, items.GetItemData, MineConfig.IsScaledAnyZone(def))
            return type(ref) == "table" and tonumber(ref.Power) and ref.Power * pct or nil
        end)
        return ok and tonumber(v) or nil
    end
    local function dmg(name, lv, var)
        local def = getCharDef(name)
        local tier = def and tonumber(def.MineTier)
        if not tier or def.MineRole == "Hauler" then return nil end
        local sd = scaledDmg(def)
        if sd then return sd end
        local td = type(MineConfig.TierDamage) == "table" and tonumber(MineConfig.TierDamage[tier]) or nil
        if not td then return nil end
        local add = tonumber(MineConfig.CharLevelAdd) or 0.25
        return td * (tonumber(def.MineDamageMult) or 1) * (1 + add * (math.max(1, lv or 1) - 1)) * (VMULT[var or "Normal"] or 1)
    end
    local function myPlot()
        local idx = LP:GetAttribute("MinePlotIndex")
        local plots = workspace:FindFirstChild("MineWorld") and workspace.MineWorld:FindFirstChild("Plots")
        return plots and idx and plots:FindFirstChild("MinePlot" .. tostring(idx)) or getMyPlot()
    end

    -- rarity ของตัวละคร (def.Rarity) ใช้โชว์ในสถานะเท่านั้น (ระบบ "rarity สูงก่อน" เอาออกแล้ว)
    local RRANK = {}
    for i, r in ipairs(type(MineConfig.RarityOrder) == "table" and MineConfig.RarityOrder or {}) do RRANK[r] = i end
    local function rarityOf(name)
        local def = getCharDef(name)
        local r = def and def.Rarity
        if type(r) == "table" then r = r.Rarity end
        r = type(r) == "string" and r or "?"
        return r, RRANK[r] or 0
    end
    local function rarityFirst() return false end  -- ระบบ "rarity สูงก่อน" ถูกเอาออก (เก็บ rarity ไว้โชว์ในสถานะเท่านั้น)

    -- ตัวละครแต่ละตัวมาจาก zone ไหน (เก็บจากข้อมูลเกมครั้งแรกที่ใช้ แล้วจำไว้)
    --   1. MineConfig.Zones[Zx].CharacterPool = ตัวที่ดรอปใน zone นั้น (ชื่อไม่ซ้ำข้าม zone)
    --   2. ไม่อยู่ใน pool ไหน (ได้จาก crate / event / เทรด) = zone จาก tier ของตัว
    --      (สูตรเดียวกับ MineConfig.TierZone: ceil(MineTier / TiersPerZone))
    --   คืนเลขลำดับ zone (Z1 = 1 ...) ตาม MineConfig.ZoneKeys / 0 = ไม่รู้
    local ZK = {}  -- ลำดับ zone (ZoneKeys ของไฟล์อยู่ในก้อน do ของ Research ใช้ตรงนี้ไม่ได้)
    for _, z in ipairs(type(MineConfig.ZoneKeys) == "table" and MineConfig.ZoneKeys or {}) do
        if type(z) == "string" then table.insert(ZK, z) end
    end
    local CHAR_ZONE = nil
    local function charZone(name)
        if CHAR_ZONE == nil then
            CHAR_ZONE = {}
            local zones = type(MineConfig.Zones) == "table" and MineConfig.Zones or {}
            for i, z in ipairs(ZK) do
                local pool = type(zones[z]) == "table" and zones[z].CharacterPool
                for _, c in ipairs(type(pool) == "table" and pool or {}) do
                    local n = type(c) == "table" and c.Name
                    if type(n) == "string" and not CHAR_ZONE[n] then CHAR_ZONE[n] = i end
                end
            end
        end
        local zi = CHAR_ZONE[name]
        if zi then return zi end
        local def = getCharDef(name)
        local tier, per = def and tonumber(def.MineTier), tonumber(MineConfig.TiersPerZone)
        zi = (tier and per and per > 0 and #ZK > 0) and math.clamp(math.ceil(tier / per), 1, #ZK) or 0
        CHAR_ZONE[name] = zi
        return zi
    end
    local function zoneName(zi) return ZK[zi] or "Z?" end
    -- พลัง base ของตัวละคร = TierDamage[tier] x MineDamageMult (ไม่นับเลเวล / variant / pickaxe / enchant)
    --   ตัว Scaled ไม่มี tier damage -> ใช้ค่าที่เกมคำนวณ (scaledDmg)
    local function baseDmg(name)
        local def = getCharDef(name)
        local tier = def and tonumber(def.MineTier)
        if not tier or def.MineRole == "Hauler" then return nil end
        local sd = scaledDmg(def)
        if sd then return sd end
        local td = type(MineConfig.TierDamage) == "table" and tonumber(MineConfig.TierDamage[tier]) or nil
        return td and td * (tonumber(def.MineDamageMult) or 1) or nil
    end
    -- รายชื่อตัวละครแยกตาม zone: Addon.zoneChars[zi] = { {name, base}, ... } เรียงพลัง base มากไปน้อย
    --   มาจาก CharacterPool ของแต่ละ zone (+ ตัวในกระเป๋าที่ไม่อยู่ใน pool ไหน เติมตามที่เจอ)
    local function zoneLists()
        if Addon.zoneChars then return Addon.zoneChars end
        local lists, seen = {}, {}
        for i = 1, #ZK do lists[i] = {} end
        local zones = type(MineConfig.Zones) == "table" and MineConfig.Zones or {}
        for i, z in ipairs(ZK) do
            local pool = type(zones[z]) == "table" and zones[z].CharacterPool
            for _, c in ipairs(type(pool) == "table" and pool or {}) do
                local n = type(c) == "table" and c.Name
                if type(n) == "string" and not seen[n] then
                    seen[n] = true
                    local b = baseDmg(n)
                    if b then table.insert(lists[i], { name = n, base = b }) end
                end
            end
            table.sort(lists[i], function(a, b) return a.base > b.base end)
        end
        Addon.zoneChars, Addon.zoneCharSeen = lists, seen
        return lists
    end
    local function noteZoneChar(name, zi)  -- ตัวนอก pool (crate / event / เทรด) -> เติมเข้า list ของ zone ตาม tier
        local lists = zoneLists()
        if Addon.zoneCharSeen[name] or not lists[zi] then return end
        Addon.zoneCharSeen[name] = true
        local b = baseDmg(name)
        if not b then return end
        table.insert(lists[zi], { name = name, base = b })
        table.sort(lists[zi], function(a, b2) return a.base > b2.base end)
    end
    -- zone เป้าหมาย = zone ลึกสุดที่ปลดล็อคแล้ว (UnlockedZones) ไม่มีข้อมูล = zone ที่อยู่ตอนนี้
    local function targetZone(mg)
        local n = deepestUnlockedZoneNum and deepestUnlockedZoneNum() or nil
        if not n then
            local z = Addon.currentZone and Addon.currentZone(mg)
            n = z and tonumber(tostring(z):match("^Z(%d+)$"))
        end
        return n
    end
    -- "ใส่ตามโซน" (toggle SmartZoneFirst ค่าเริ่มต้นเปิด):
    --   ตัวจาก zone ลึกกว่า (ใกล้ zone ที่เปิดล่าสุด) ได้ใส่ก่อน -> zone เดียวกัน = พลัง base มากกว่า
    --   ปิด = ดาเมจจริงมากสุดก่อน (นับเลเวล + variant)
    local function zoneFirst() return Velvet.Flags["SmartZoneFirst"] ~= false end

    -- ลำดับการเทียบ: zone ลึกกว่า -> พลัง base (โหมดโซน) / ดาเมจจริง (ปิดโหมดโซน)
    --   คืน "zone" / "rarity" / "power" = ตัดสินด้วยข้อไหน
    local function decide(a, b)
        if zoneFirst() and a.zi ~= b.zi then return "zone" end
        if rarityFirst() and a.rr ~= b.rr then return "rarity" end
        return "power"
    end
    local function better(a, b, margin)  -- a ดีกว่า b ไหม (margin = พลังต้องมากกว่ากี่เท่า)
        local by = decide(a, b)
        if by == "zone" then return a.zi > b.zi end
        if by == "rarity" then return a.rr > b.rr end
        if zoneFirst() then return (a.b or 0) > (b.b or 0) * (margin or 1) end
        return a.d > b.d * (margin or 1)
    end
    -- ให้ Auto Upgrade Miner ใช้ลำดับเดียวกัน (โค้ดอัปอยู่ก่อนส่วนนี้ เลยส่งผ่าน Addon)
    --   equipRank(name) = zone ของตัว, พลัง base
    --   equipReplaceable(name) = Smart Equip เปิดอยู่ + ในกระเป๋ามีตัวที่ดีกว่า (โซนลึกกว่า / base มากกว่า)
    --                            = ตัวนี้กำลังจะโดนเปลี่ยนออก ไม่ต้องเสียเงินอัป
    Addon.equipZoneFirst = zoneFirst
    Addon.equipRank = function(name)
        return charZone(name), baseDmg(name) or 0
    end
    Addon.equipReplaceable = function(name)
        if Velvet.Flags["AutoSmartEquip"] ~= true or not zoneFirst() then return false end
        local mg = Addon.mineGame()
        if type(mg) ~= "table" or type(mg.Characters) ~= "table" then return false end
        local me = { zi = charZone(name), b = baseDmg(name) or 0, d = 0, rr = 0 }
        for key, n in pairs(mg.Characters) do
            if type(key) == "string" and (tonumber(n) or 0) > 0 then
                local cn = string.split(key, "|")[1]
                local b = baseDmg(cn)
                if b and better({ zi = charZone(cn), b = b, d = 0, rr = 0 }, me, 1.02) then return true end
            end
        end
        return false
    end

    -- แผน: pad แย่สุด + ตัวในกระเป๋าดีสุด
    local function plan()
        local mg = Addon.mineGame()
        if type(mg) ~= "table" then return nil, "รอข้อมูลจากเกม" end
        local weakest = nil
        local holders = type(mg.Holders) == "table" and mg.Holders or {}
        -- รวม pad จากข้อมูลเกม + pad ในโลก (pad ว่างบางอันไม่มีใน Holders) ข้าม pad ที่ยังล็อก
        local pads = {}
        for pad in pairs(holders) do
            if type(pad) == "string" and pad:sub(1, 1) == "M" then pads[pad] = true end
        end
        local plot = myPlot()
        local hf = plot and plot:FindFirstChild("Holders")
        -- pad ที่ยังไม่ได้ซื้อ มี Model "Lock" (โซ่ + แม่กุญแจ) อยู่ข้างใน -> ข้าม ห้ามเดินไป
        local locked = {}
        for _, m in ipairs(hf and hf:GetChildren() or {}) do
            local pr = m:FindFirstChild("Pad") and m.Pad:FindFirstChild("HolderPrompt")
            if m:FindFirstChild("Lock") then
                locked[m.Name] = true
            elseif m.Name:sub(1, 1) == "M" and pr and pr.Enabled then
                pads[m.Name] = true
            end
        end
        -- ช่องปกติที่ยังไม่ได้ซื้อ (M<MinerSlots+1>..M<MaxMinerSlots>) ไม่มี Lock แต่ขึ้นราคา -> ข้ามด้วย
        --   (Smart Equip ไม่ซื้อช่อง ซื้อแล้วเกมเพิ่ม MinerSlots ก็จะใส่ให้เอง)
        local owned = tonumber(mg.MinerSlots) or tonumber(MineConfig.BaseMinerSlots) or 5
        local maxBase = tonumber(MineConfig.MaxMinerSlots) or 8
        for pad in pairs(pads) do
            local h = holders[pad]
            local filled = type(h) == "table" and type(h.CharName) == "string" and h.CharName ~= ""
            if locked[pad] then continue end
            local num = tonumber(pad:match("^M(%d+)$"))
            if not filled and num and num > owned and num <= maxBase then continue end
            local d = filled and dmg(h.CharName, tonumber(h.CharLevel), h.CharVariant) or (not filled and 0) or nil
            if d then
                local r, rr, zi, b = "-", -1, -1, 0  -- pad ว่าง = แย่สุดเสมอ
                if filled then r, rr = rarityOf(h.CharName); zi = charZone(h.CharName); b = baseDmg(h.CharName) or 0 end
                local cand = { pad = pad, d = d, b = b, r = r, rr = rr, zi = zi, name = filled and h.CharName or "(ว่าง)", empty = not filled }
                if not weakest or better(weakest, cand) then weakest = cand end
            end
        end
        local best = nil
        for key, n in pairs(type(mg.Characters) == "table" and mg.Characters or {}) do
            if type(key) == "string" and (tonumber(n) or 0) > 0 then
                local parts = string.split(key, "|")
                local lv = tonumber(parts[2]) or 1
                local var = (parts[3] and parts[3] ~= "") and parts[3] or "Normal"
                local d = dmg(parts[1], lv, var)
                if d then
                    local r, rr = rarityOf(parts[1])
                    local zi = charZone(parts[1])
                    noteZoneChar(parts[1], zi)
                    local cand = { key = key, d = d, b = baseDmg(parts[1]) or 0, r = r, rr = rr, zi = zi, name = parts[1], lv = lv, var = var }
                    if not best or better(cand, best) then best = cand end
                end
            end
        end
        local here = (Addon.currentZone and Addon.currentZone(mg)) or "?"
        local tz = targetZone(mg)
        if tz then here = here .. " · เปิดถึง Z" .. tz end
        if not weakest then return nil, ("[อยู่ %s] ไม่มี pad ของ miner"):format(here) end
        if not best or not better(best, weakest, 1.02) then
            local rule = {}
            if zoneFirst() then table.insert(rule, "zone ลึกกว่า") end
            if rarityFirst() then table.insert(rule, "rarity สูงกว่า") end
            table.insert(rule, zoneFirst() and "พลัง base มากกว่า" or "แรงกว่า")
            return nil, ("[อยู่ %s] ทีมดีที่สุดแล้ว (ไม่มีตัวในกระเป๋าที่ %s)"):format(here, table.concat(rule, " / "))
        end
        -- เปลี่ยนเพราะ zone ใหม่กว่า / rarity สูงกว่า (ดาเมจอาจน้อยลง) -> ไม่ใช้เช็ค "MinePower ลดลง = หยุด"
        local by = weakest.empty and "empty" or decide(best, weakest)
        -- โหมดโซนเทียบพลัง base (ไม่นับเลเวล) -> MinePower อาจลดได้ ไม่ใช้เช็ค "MinePower ลดลง = หยุด"
        return { pad = weakest.pad, from = weakest, to = best, by = by, here = here, byRarity = zoneFirst() or by == "rarity" }, mg
    end

    local function holdKey(key)
        local mg = Addon.mineGame()
        if not inv then return false end
        local ok, slot = isolated(function() return inv.TargetSlot(mg, key) end)
        if not ok or not slot then return false end
        local hb = mg and type(mg.Hotbar) == "table" and mg.Hotbar or {}
        if hb[slot] ~= key then
            fire("MineAssignHotbar", slot, key)
            task.wait(0.6)
        end
        local okE, eq = isolated(function() return inv.EquippedSlot(Addon.mineGame()) end)
        if not (okE and eq == slot) then
            fire("MineEquipSlot", slot)
            task.wait(0.6)
        end
        return true
    end

    local function walkTo(part)  -- เดินไปที่ pad (ไม่วาป)
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not root then return false end
        for _ = 1, 3 do
            if (root.Position - part.Position).Magnitude < 6 then return true end
            hum:MoveTo(part.Position)
            local done = false
            local c = hum.MoveToFinished:Connect(function() done = true end)
            local t0 = os.clock()
            while not done and os.clock() - t0 < 8 do task.wait(0.1) end
            c:Disconnect()
        end
        return (root.Position - part.Position).Magnitude < 9
    end

    -- tween ไปยืนบน pad (Addon.tweenTo ตัวเดียวกับระบบขาย) แทนการเดิน
    --   จุดหมาย = เหนือผิวบน pad ~3 studs (ความสูง HumanoidRootPart ตอนยืน) หันหน้าเหมือนเดิม
    local function tweenToPad(part)
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return false end
        if (root.Position - part.Position).Magnitude < 6 then return true end
        local top = part.Position + Vector3.new(0, part.Size.Y / 2 + 3, 0)
        Addon.tweenTo(root, CFrame.new(top) * (root.CFrame - root.Position))
        task.wait(0.15)  -- ให้ server เห็นตำแหน่งใหม่ก่อนกด prompt
        return (root.Position - part.Position).Magnitude < 9
    end
    -- จองการเคลื่อนที่ระหว่างใส่ตัว (lock เดียวกับระบบขาย: Addon.sellBusy)
    --   ระบบขายกำลังเดินทาง = รอให้เสร็จก่อน / ระหว่างใส่ตัว ระบบขายจะรอ (ไม่พาตัวไปจุดขายกลางคัน)
    local function holdMove()
        while os.clock() - (Addon.sellBusy or 0) < 10 do task.wait(0.2) end
        Addon.sellBusy = os.clock()
    end

    local function pressPrompt(prompt)
        if type(fireproximityprompt) == "function" then
            return pcall(fireproximityprompt, prompt)
        end
        return pcall(function()
            prompt:InputHoldBegin()
            task.wait((prompt.HoldDuration or 0) + 0.1)
            prompt:InputHoldEnd()
        end)
    end

    local function padState(pad)
        local mg = Addon.mineGame()
        local h = mg and type(mg.Holders) == "table" and mg.Holders[pad]
        if type(h) ~= "table" or type(h.CharName) ~= "string" or h.CharName == "" then return nil end
        return h.CharName .. "|" .. tostring(h.CharLevel or 1) .. "|" .. tostring(h.CharVariant or "Normal")
    end

    local busy = false
    local moving = false  -- กำลังจอง lock เคลื่อนที่อยู่ (คืนให้ระบบขายตอนจบ แม้ error)
    local function runOnce()
        if busy then return "busy" end
        busy = true
        local result
        local ok, err = pcall(function()
            local p, why = plan()
            if not p then result = why; return end
            local plot = myPlot()
            local model = plot and plot:FindFirstChild("Holders") and plot.Holders:FindFirstChild(p.pad)
            local padPart = model and model:FindFirstChild("Pad")
            local prompt = padPart and padPart:FindFirstChild("HolderPrompt")
            if not prompt then result = "หา pad " .. p.pad .. " ไม่เจอ"; return end
            local WHY = { zone = "zone ลึกกว่า", rarity = "rarity สูงกว่า", power = zoneFirst() and "พลัง base มากกว่า" or "แรงกว่า", empty = "pad ว่าง" }
            para:Set(("[อยู่ %s] " .. (p.from.empty and "ใส่" or "เปลี่ยน") .. " %s: %s%s -> %s (%s %s) Lv%d %s · %s"):format(
                p.here, p.pad, p.from.name,
                p.from.empty and "" or (" (" .. zoneName(p.from.zi) .. " " .. tostring(p.from.r) .. ")"),
                p.to.name, zoneName(p.to.zi), tostring(p.to.r), p.to.lv, p.to.var, WHY[p.by] or ""))
            local powerBefore = tonumber(LP:GetAttribute("MinePower"))
            local before = padState(p.pad)
            holdMove()
            moving = true
            if not holdKey(p.to.key) then result = "ถือตัวละครไม่ได้ (hotbar)"; return end
            Addon.sellBusy = os.clock()
            if not tweenToPad(padPart) then result = "tween ไปที่ pad ไม่ถึง"; return end
            local function waitChange(old)
                local t0 = os.clock()
                while os.clock() - t0 < 4 do
                    Addon.sellBusy = os.clock()
                    local now = padState(p.pad)
                    if now ~= old then return now end
                    task.wait(0.1)
                end
                return old
            end
            pressPrompt(prompt)
            local after = waitChange(before)
            if after == nil and before ~= nil then
                -- เกมเอาตัวเก่าออก ไม่สลับ -> ถือตัวใหม่แล้วกดอีกครั้ง
                holdKey(p.to.key)
                Addon.sellBusy = os.clock()
                tweenToPad(padPart)
                pressPrompt(prompt)
                after = waitChange(nil)
            end
            if moving then Addon.sellBusy = nil; moving = false end  -- ใส่เสร็จ (ช่วง 2 วิรอ MinePower ไม่ต้องจอง)
            if after == before then result = "กดแล้วไม่มีอะไรเปลี่ยน หยุด"; return end
            if not after or not after:find(p.to.name, 1, true) then
                result = "ผลไม่ตรงที่คาด (pad " .. p.pad .. " = " .. tostring(after) .. ") หยุด"; return
            end
            task.wait(2)
            local powerAfter = tonumber(LP:GetAttribute("MinePower"))
            if not p.byRarity and powerBefore and powerAfter and powerAfter < powerBefore * 0.999 then
                result = ("MinePower ลดลง (%s -> %s) หยุด"):format(short(powerBefore), short(powerAfter)); return
            end
            result = "ok"
            if Addon.emit then
                Addon.emit("info", ("Smart Equip: %s %s -> %s (%s %s) Lv%d"):format(p.pad, p.from.name, p.to.name,
                    zoneName(p.to.zi), tostring(p.to.r), p.to.lv))
            end
        end)
        busy = false
        if moving then Addon.sellBusy = nil; moving = false end
        if not ok then result = "error: " .. tostring(err) end
        return result
    end

    -------------------- Auto Best Pickaxe (pickaxe ผูกกับ pad: Holders[pad].Pickaxe) --------------------
    --   ดาเมจ pad = น้ำหนัก (ดาเมจ miner x enchant ของ pad) x Multiplier ของ pickaxe
    --   -> pickaxe แรงสุดไป pad น้ำหนักสูงสุด ไล่ลงไป (ได้ผลรวมสูงสุด) ของไม่พอ = "" (pickaxe ฟรี)
    --   remote: MineEquipPickaxe(pad, name)  name "" = pickaxe ฟรี (คืนของเข้ากระเป๋า)
    local FREE_M = 1
    do
        local p1 = type(MineConfig.Pickaxes) == "table" and MineConfig.Pickaxes[1]
        FREE_M = type(p1) == "table" and tonumber(p1.Multiplier) or 1
    end
    local function pickMult(name)  -- คืน multiplier, ชื่อจริง ("" = pickaxe ฟรี)
        if not name or name == "" then return FREE_M, "" end
        local ok, def = isolated(function() return MineConfig.GetPickaxeByName(name) end)
        if not ok or type(def) ~= "table" then return FREE_M, "" end
        local okF, free = isolated(function() return MineConfig.IsPickaxeFree(def) end)
        return tonumber(def.Multiplier) or 1, (okF and free == true) and "" or name
    end
    local function padPick(pad)
        local mg = Addon.mineGame()
        local h = mg and type(mg.Holders) == "table" and mg.Holders[pad]
        return type(h) == "table" and type(h.Pickaxe) == "string" and h.Pickaxe or ""
    end
    local function pickaxePlan()
        local mg = Addon.mineGame()
        if type(mg) ~= "table" or type(mg.Holders) ~= "table" then return nil end
        local pads = {}
        for pad, h in pairs(mg.Holders) do
            if type(pad) == "string" and pad:match("^M%d+$") and type(h) == "table"
                and type(h.CharName) == "string" and h.CharName ~= "" then
                local d = dmg(h.CharName, tonumber(h.CharLevel), h.CharVariant)
                if d then
                    local okE, e = isolated(function() return MineConfig.GetEnchantPowerMult(mg, pad) end)
                    table.insert(pads, { pad = pad, w = d * ((okE and tonumber(e)) or 1) })
                end
            end
        end
        table.sort(pads, function(a, b) return a.w > b.w end)
        local stock, picks = {}, {}
        for name, n in pairs(type(mg.Pickaxes) == "table" and mg.Pickaxes or {}) do
            local m, real = pickMult(name)
            n = math.min(tonumber(n) or 0, #pads)
            if real ~= "" and n > 0 then
                stock[name] = { m = m, n = n }
                for _ = 1, n do table.insert(picks, m) end
            end
        end
        table.sort(picks, function(a, b) return a > b end)
        -- pad ที่ multiplier ตรงลำดับแล้ว = เก็บไว้ (หักของที่ใส่อยู่ออกจากกอง) ที่เหลือ = ต้องเปลี่ยน
        local change = {}
        for i, p in ipairs(pads) do
            local cur = padPick(p.pad)
            local curM, real = pickMult(cur)
            local wantM = picks[i] or FREE_M
            if math.abs(curM - wantM) <= 1e-9 and (real == "" or (stock[real] and stock[real].n > 0)) then
                if real ~= "" then stock[real].n -= 1 end
            else
                table.insert(change, p)
            end
        end
        -- pad ที่ต้องเปลี่ยน (เรียงแรงสุดก่อน) รับของแรงสุดที่เหลือในกอง
        local todo = {}
        for _, p in ipairs(change) do
            local bestName, bestM = "", FREE_M
            for name, s in pairs(stock) do
                if s.n > 0 and s.m > bestM then bestName, bestM = name, s.m end
            end
            if bestName ~= "" then stock[bestName].n -= 1 end
            local cur = padPick(p.pad)
            local _, curReal = pickMult(cur)
            if curReal ~= bestName then table.insert(todo, { pad = p.pad, from = curReal, to = bestName }) end
        end
        return todo
    end
    local function shortPick(n) return (n == "" and "Free" or tostring(n):gsub(" Pickaxe$", "")) end
    local function pickaxePass()
        if Velvet.Flags["SmartPickaxe"] == false then return nil end
        local todo = pickaxePlan()
        if not todo or #todo == 0 then return nil end
        local function setPick(pad, name)
            local function waitPick()
                local t0 = os.clock()
                while os.clock() - t0 < 3 do
                    if padPick(pad) == name then return true end
                    task.wait(0.2)
                end
                return padPick(pad) == name
            end
            fire("MineEquipPickaxe", pad, name)
            if waitPick() then return true end
            local plot = myPlot()
            local model = plot and plot:FindFirstChild("Holders") and plot.Holders:FindFirstChild(pad)
            local padPart = model and model:FindFirstChild("Pad")
            if padPart then
                holdMove()
                local near = tweenToPad(padPart)
                Addon.sellBusy = nil
                if near then
                    fire("MineEquipPickaxe", pad, name)
                    return waitPick()
                end
            end
            return false
        end
        local powerBefore = tonumber(LP:GetAttribute("MinePower"))
        -- รอบ 1: คืนของจาก pad ที่ต้องเปลี่ยนก่อน (กันของที่ต้องการติดอยู่ pad อื่น)
        for _, t in ipairs(todo) do
            if t.from ~= "" then fire("MineEquipPickaxe", t.pad, ""); task.wait(0.4) end
        end
        task.wait(0.6)
        -- รอบ 2: ใส่ตัวที่ดีที่สุด
        local done = 0
        for _, t in ipairs(todo) do
            if t.to ~= "" then
                if not setPick(t.pad, t.to) then
                    return ("pickaxe %s ใส่ไม่สำเร็จ (%s) หยุด"):format(t.pad, shortPick(t.to))
                end
                task.wait(0.4)
            end
            done += 1
            if Addon.emit then Addon.emit("info", ("Pickaxe: %s %s -> %s"):format(t.pad, shortPick(t.from), shortPick(t.to))) end
        end
        task.wait(2)
        local powerAfter = tonumber(LP:GetAttribute("MinePower"))
        if powerBefore and powerAfter and powerAfter < powerBefore * 0.999 then
            return ("pickaxe: MinePower ลดลง (%s -> %s)"):format(short(powerBefore), short(powerAfter))
        end
        return ("จัด pickaxe %d pad"):format(done)
    end

    -- กดครั้งเดียว: เปลี่ยนจนทีมดีสุด (ไม่เกิน 12 pad) แล้วจัด pickaxe
    -- Addon.equipBusy = กำลังจัดทีมทั้งรอบ (ทุก pad + pickaxe) -> ระบบขายรอจนเสร็จ ไม่แทรกกลางรอบ
    local function runAll()
        Addon.equipBusy = os.clock()
        local n, r = 0, nil
        for _ = 1, 12 do
            Addon.equipBusy = os.clock()
            r = runOnce()
            if r ~= "ok" then break end
            n += 1
            r = nil
        end
        if r == "busy" then Addon.equipBusy = nil; return r end
        Addon.equipBusy = os.clock()
        local pr = nil
        if not busy then
            busy = true
            local ok, res = pcall(pickaxePass)
            busy = false
            pr = ok and res or ("pickaxe error: " .. tostring(res))
        end
        local parts = {}
        if n > 0 then table.insert(parts, ("เปลี่ยนแล้ว %d ตัว"):format(n)) end
        if r then table.insert(parts, tostring(r)) end
        if pr then table.insert(parts, pr) end
        Addon.equipBusy = nil
        para:Set(table.concat(parts, " · "))
        return r
    end

    accentButton(section:AddButton({
        Text = "Smart Equip Now",
        Callback = function()
            task.spawn(runAll)
        end,
    }))
    -- ไม่ปิด toggle เองเมื่อรอบไหนไม่สำเร็จ (เดินไม่ถึง / กดแล้วไม่เปลี่ยน ฯลฯ) -> โชว์สถานะแล้วลองใหม่รอบหน้า
    local start, stop = makeLoop(function() runAll() end, function() return 30 end)
    section:AddToggle("AutoSmartEquip", {
        Text = "Auto Smart Equip",
        Default = false,
        Callback = function(on) if on then start() else stop() end end,
    })
    Addon.stopSmartEquip = stop
    section:AddToggle("SmartZoneFirst", {
        Text = "ใส่ตามโซน: ตัวจากโซนที่เปิดล่าสุดก่อน แล้วดูพลัง base",
        Default = true,
        Callback = function() end,
    })
    section:AddToggle("SmartPickaxe", {
        Text = "Auto Best Pickaxe",
        Default = true,
        Callback = function() end,
    })

    -------------------- Auto Open Gate (ประตู Annex: ขยาย plot ได้ pad M9-M12) --------------------
    --   ราคา MineConfig.AnnexCost (cash) / เปิดแล้ว MineGame.PlotExpanded = true
    --   เงินถึง -> เดินไปที่ประตู (Annex.Gate) แล้วกด GatePrompt
    --   pad ใน annex ช่องแรกฟรี ช่องถัดไปใช้ไอเทม Slot Key (เกมจัดการเอง)
    local gateBusy = false
    local function gatePass()
        if gateBusy then return end
        local mg = Addon.mineGame()
        if type(mg) ~= "table" or mg.PlotExpanded == true then return end
        local cost = tonumber(MineConfig.AnnexCost)
        local cash = getCash()
        if not cost or not cash or cash < cost then return end
        if not Kaitun.allow("Slots", cost) then return end
        local plot = myPlot()
        local annex = plot and plot:FindFirstChild("Annex")
        -- FindFirstChild(recursive) ไม่ต้องสร้าง array ของ descendant ทั้งหมดทุก 5 วิ
        --   เจอชื่อตรงแต่ไม่ใช่ ProximityPrompt (แทบไม่มี) -> ค่อยไล่หาแบบเดิม
        local prompt = annex and annex:FindFirstChild("GatePrompt", true)
        if prompt and not prompt:IsA("ProximityPrompt") then
            prompt = nil
            for _, d in ipairs(annex:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Name == "GatePrompt" then prompt = d; break end
            end
        end
        local part = prompt and prompt.Parent
        if not (part and part:IsA("BasePart")) then return end
        gateBusy = true
        pcall(function()
            if walkTo(part) then
                pressPrompt(prompt)
                task.wait(2)
                local m2 = Addon.mineGame()
                if type(m2) == "table" and m2.PlotExpanded == true then
                    Velvet:Notify({ Title = "Open Gate", Content = "Plot expanded", Duration = 5, Type = "success" })
                    if Addon.emit then Addon.emit("info", "Open Gate: plot expanded") end
                end
            end
        end)
        gateBusy = false
    end
    local startGate, stopGate = makeLoop(gatePass, function() return 5 end)
    section:AddToggle("AutoOpenGate", {
        Text = "Auto Open Gate",
        Default = false,
        Callback = function(on) if on then startGate() else stopGate() end end,
    })
    Addon.stopOpenGate = stopGate
end
Addon.smartEquip()

Addon.stop = function()
    if Addon.stopGemShop then Addon.stopGemShop() end
    if Addon.stopWeblog then Addon.stopWeblog() end
    if Addon.stopClaims then Addon.stopClaims() end
    if Addon.stopTrade then Addon.stopTrade() end
    if Addon.stopPerf then Addon.stopPerf() end
    if Addon.stopCodes then Addon.stopCodes() end
    if Addon.stopMutation then Addon.stopMutation() end
    if Addon.stopSmartEquip then Addon.stopSmartEquip() end
    if Addon.stopOpenGate then Addon.stopOpenGate() end
end

----------------------------------------------------------------
-- KAITUN ส่วนที่ 2: ตัวสั่งงาน (แท็บ Kaitun)
--   เปิด "Kaitun Mode" (หรือ _G.Kaitun.Enabled = true) ->
--     1. เปิด toggle ฟาร์มทุกอัน + ตั้ง Strategy ของ Skill Tree เป็น "Kaitun"
--     2. ลูปผู้คุม ทุก 2 วิ: เช็คเป้าหมาย / อัป tap / อัปเดตสถานะในแท็บ
--     3. ตัวคุมงบ (Kaitun.allow ส่วนที่ 1) เริ่มทำงาน เพราะ Kaitun.on = true
--   ปิด = เลิกคุมงบ + หยุดลูปผู้คุม (toggle ฟาร์มที่เปิดไว้ยังเปิดอยู่ ปิดเองได้ / กด Stop All)
--   ถึงเป้าหมาย: OnGoal = "stop" -> ปิด toggle ฟาร์มทุกอัน / "keep" -> ฟาร์มต่อ
-- อยู่ในฟังก์ชัน: local ข้างในไม่นับรวมกับ local ระดับบนสุดของไฟล์
----------------------------------------------------------------
Kaitun.setup = function()
    local cfg = Kaitun.cfg
    local section = Kaitun.tab:AddSection("Kaitun")
    local statusPara = section:AddParagraph({ Title = "Status", Content = "EndHubKaitunStatus" })
    -- Velvet ล็อคขนาดตัวอักษรของ Paragraph ไว้ที่ 11 -> หาป้ายของเราในหน้าต่างแล้วขยายเอง
    pcall(function()
        local root = Window._main
        for _, d in ipairs(root and root:GetDescendants() or {}) do
            if d:IsA("TextLabel") and d.Text == "EndHubKaitunStatus" then
                d.TextSize = 15
                d.LineHeight = 1.15
                local title = d.Parent and d.Parent:FindFirstChildWhichIsA("TextLabel")
                if title and title ~= d then
                    title.TextSize = 16
                    title.Size = UDim2.new(1, 0, 0, 20)
                    d.Position = UDim2.new(0, 0, 0, 24)
                end
                break
            end
        end
    end)
    statusPara:Set("Off")

    local function setFlag(id, value)
        local elem = Velvet._elements and Velvet._elements[id]
        if type(elem) == "table" and elem.Set then
            pcall(function() elem:Set(value) end)
        end
    end

    -- เลข zone เป้าหมาย ("Z14" / 14 -> 14, "max" / ไม่มีเลข -> zone สุดท้าย) ไม่เกิน zone สุดท้ายของเกม
    local zoneCount = #(type(MineConfig.ZoneKeys) == "table" and MineConfig.ZoneKeys or {})
    --   (อ่านจำนวน zone ไม่ได้ + ไม่ได้ใส่เลข -> 99 = ไม่ถือว่าถึงเป้าหมายเอง)
    local goalZone = tonumber(tostring(cfg.Goal.Zone):match("(%d+)")) or (zoneCount > 0 and zoneCount or 99)
    if zoneCount > 0 then goalZone = math.clamp(goalZone, 1, zoneCount) end

    -- toggle ฟาร์มที่ Kaitun เปิดให้ (ถึงเป้าหมายแบบ "stop" = ปิดชุดนี้)
    local FARM_FLAGS = {
        "AutoSmartEquip", "AutoTakeChest", "DailySpin", "AutoSellOres",
        "PickaxeFollowZone", "AutoBuyPickaxe", "Buy_Skill", "AutoUnlockZone",
        "AutoBuyMinerSlot", "AutoUpgradePlot", "AutoClaimMail", "AutoClaimMilestone", "AutoClaimIndex", "AutoRedeemCodes",
    }
    local MINER_LABEL = { Damage = "Damage", Speed = "Speed", MineSpeed = "Mining Speed" }

    local function applyToggles()
        setFlag("SkillStrategy", "Kaitun")
        local types = {}
        for _, id in ipairs(cfg.Miner.Types) do
            local text = MINER_LABEL[id]
            if text then types[text] = true end
        end
        if next(types) then setFlag("PlotUpgradeTypes", types) end
        setFlag("PlotFocusStrongest", cfg.Miner.FocusStrongest == true)
        setFlag("SmartZoneFirst", cfg.Equip.ZoneFirst ~= false)
        local cap = tonumber(cfg.Miner.LevelCap)
        if cap then
            local text = cap > 0 and tostring(math.floor(cap)) or ""  -- 0 = ไม่จำกัด (ล้างช่อง)
            setFlag("PlotLevelCap", text)
            Velvet.Flags["PlotLevelCap"] = text  -- เผื่อ input ไม่อัปเดต flag ตอน Set
        end
        for _, id in ipairs(FARM_FLAGS) do setFlag(id, true) end
        if cfg.Tap.Enabled == true then setFlag("AutoTutorial", true) end
        if cfg.Potion.Enabled == true then
            local v = Addon.potionFlag and Addon.potionFlag(cfg.Potion.Use)
            if v and next(v) then setFlag("UsePotionTypes", v) end
            setFlag("AutoUsePotion", true)
        end
        if cfg.Mutation.Enabled == true then
            if Addon.mutationSet then
                Addon.mutationSet({ all = cfg.Mutation.All ~= false, target = cfg.Mutation.Target })
            end
            setFlag("AutoMutation", true)
        end
    end

    -------------------- ของเสริม: Anti AFK / FPS / ปิด 3D --------------------
    -- FpsCap / FpsBoost จาก config = ล็อคไว้ตลอดตอน Kaitun ทำงาน (ใช้ slider / toggle เดิมใน Settings)
    local capLock = tonumber(cfg.FpsCap)
    if capLock and capLock <= 0 then capLock = nil end
    local boostLock = cfg.FpsBoost == true
    local antiLagLock = cfg.AntiLag == true
    local function enforcePerf()
        if capLock then
            if Velvet.Flags["PerfFpsCap"] ~= capLock then
                setFlag("PerfFpsCap", capLock)
                Velvet.Flags["PerfFpsCap"] = capLock
            end
            if type(setfpscap) == "function" then pcall(setfpscap, capLock) end  -- กันเกม / executor รีเซ็ต
        end
        if boostLock and Velvet.Flags["PerfBoost"] ~= true then setFlag("PerfBoost", true) end
        if antiLagLock and Velvet.Flags["PerfAntiLag"] ~= true then setFlag("PerfAntiLag", true) end
    end
    local function extrasOn()
        -- Anti AFK ตัวจริงอยู่ที่ Settings > General (เปิดอยู่แล้วตั้งแต่เริ่ม) ตรงนี้แค่เปิดให้ถ้าถูกปิดไว้
        if cfg.AntiAfk == true then setFlag("AntiAfk", true) end
        if cfg.BlockIdleRejoin == true then setFlag("BlockIdleRejoin", true) end
        enforcePerf()
        if cfg.Disable3D == true then
            pcall(function() game:GetService("RunService"):Set3dRenderingEnabled(false) end)
        end
    end
    local function extrasOff()
        if capLock then setFlag("PerfFpsCap", 0) end
        if boostLock then setFlag("PerfBoost", false) end
        if antiLagLock then setFlag("PerfAntiLag", false) end
        if cfg.Disable3D == true then
            pcall(function() game:GetService("RunService"):Set3dRenderingEnabled(true) end)
        end
    end

    -------------------- ลูปผู้คุม --------------------
    local startedAt, lastCash, lastT, income = os.clock(), nil, nil, 0
    local goalDone = false
    local lastTapFire = 0

    local function fmtTime(s)
        s = math.max(0, math.floor(s))
        return ("%02d:%02d:%02d"):format(math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
    end

    -- ราคาอัป tap ขั้นถัดไป (สูตรเดียวกับ MineConfig.GetTapUpgradeCost คิดจากตารางข้อมูลเอง ไม่เรียกฟังก์ชันเกม)
    local function tapCost(level)
        local costs = MineConfig.TapZoneCost
        local per = tonumber(MineConfig.TapLevelsPerZone) or 3
        if type(costs) ~= "table" or #costs == 0 then return nil end
        local base = tonumber(costs[math.min(#costs, math.floor((level - 1) / per) + 1)])
        return base and math.floor(base * 4 ^ ((level - 1) % per)) or nil
    end

    local lastPerf = 0
    local function tick()
        if os.clock() - lastPerf >= 2 then lastPerf = os.clock(); enforcePerf() end
        local mg = getMineGame()
        local cash = getCash()
        local now = os.clock()

        -- เงินเพิ่มต่อวินาที (เฉลี่ยแบบถ่วง ไม่นับช่วงที่เงินลดเพราะซื้อของ = ค่าประมาณขั้นต่ำ)
        if cash and lastCash and lastT and now > lastT then
            local rate = math.max(0, cash - lastCash) / (now - lastT)
            income = income == 0 and rate or (income * 0.8 + rate * 0.2)
        end
        lastCash, lastT = cash, now
        Kaitun.income = income

        -- zone ลึกสุดที่ปลดล็อคแล้ว (ไม่มีข้อมูล -> zone ของ plot)
        local deep = nil
        if deepestUnlockedZoneNum then
            local okD, d = pcall(deepestUnlockedZoneNum)
            if okD then deep = tonumber(d) end
        end
        if not deep then
            local plot = getMyPlot()
            deep = plot and tonumber(tostring(readValue(plot, "ZoneKey") or ""):match("(%d+)")) or nil
        end
        local zoneKey = deep and ("Z" .. deep) or nil

        -- research ของ zone นั้น (ฟังก์ชันเกม -> thread แยก)
        local done, total = nil, nil
        if zoneKey and mg then
            local okP, a, b = isolated(function()
                return MineConfig.GetZoneResearchProgress(mg.Skills, zoneKey)
            end)
            if okP then done, total = tonumber(a), tonumber(b) end
        end
        local researchDone = done ~= nil and total ~= nil and done >= total

        -- เป้าหมาย
        local reached = deep ~= nil and (deep > goalZone
            or (deep == goalZone and (cfg.Goal.Research ~= true or researchDone)))
        if reached and not goalDone then
            goalDone = true
            if Addon.emit then
                Addon.emit("goal", ("Smart AI Kaitun ถึงเป้าหมาย Z%d%s (%s)"):format(
                    goalZone, cfg.Goal.Research == true and " + research ครบ" or "", fmtTime(now - startedAt)))
            end
            local stopNow = cfg.OnGoal == "stop"
            Velvet:Notify({
                Title = "Kaitun",
                Content = ("ถึงเป้าหมายแล้ว (Z%d%s) ใช้เวลา %s\n%s"):format(
                    goalZone, cfg.Goal.Research == true and " + research ครบ" or "",
                    fmtTime(now - startedAt), stopNow and "ปิดฟาร์มทั้งหมดแล้ว" or "ฟาร์มต่อ"),
                Duration = 10, Type = "success",
            })
            if stopNow then
                task.defer(function()
                    for _, id in ipairs(FARM_FLAGS) do
                        if id ~= "PickaxeFollowZone" then setFlag(id, false) end
                    end
                    setFlag("AutoTutorial", false)
                    if cfg.Potion.Enabled == true then setFlag("AutoUsePotion", false) end
                    if cfg.Mutation.Enabled == true then setFlag("AutoMutation", false) end
                    setFlag("KaitunMode", false)
                end)
                return
            end
        end

        -- อัป tap (เฉพาะตอนเปิด auto tap) ยิงไม่เกิน 5 วิครั้ง
        if cfg.Tap.Enabled == true and cfg.Tap.Upgrade == true and mg and now - lastTapFire > 5 then
            local level = tonumber(mg.TapLevel) or 1
            local maxLv = tonumber(MineConfig.TapMaxLevel) or 0
            local tapCap = tonumber(cfg.Tap.LevelCap)
            if tapCap and tapCap > 0 then maxLv = math.min(maxLv, math.floor(tapCap)) end
            local cost = level < maxLv and tapCost(level) or nil
            if cost and cash and cash >= cost and Kaitun.allow("Tap", cost) then
                lastTapFire = now
                fire("MineUpgradeTap")
            end
        end

        -- สถานะ
        local doing
        if goalDone then
            doing = "Goal reached (still farming)"
        elseif (Kaitun.reserve or 0) > 0 then
            local gap = Kaitun.reserve - (cash or 0)
            local eta = (gap > 0 and income > 0) and ("  ETA " .. fmtTime(gap / income)) or ""
            doing = ("Saving to unlock Z%d (%s / %s)%s"):format((deep or 0) + 1, short(cash or 0), short(Kaitun.reserve), eta)
        elseif Kaitun.needPower then
            doing = "Research needs more MinePower -> upgrading miners"
        else
            doing = "Buying best-value research"
        end
        -- ให้ Weblog อ่าน (Addon.weblog)
        Kaitun.doing = doing
        Kaitun.reached = goalDone
        Kaitun.goalText = ("Z%d%s"):format(goalZone, cfg.Goal.Research == true and " + research" or "")
        statusPara:Set(table.concat({
            ("Zone: %s  ->  Goal Z%d%s"):format(zoneKey or "?", goalZone, cfg.Goal.Research == true and " + full research" or ""),
            ("Research %s: %s"):format(zoneKey or "?", (done and total) and (("%d / %d"):format(done, total)) or "waiting for game data"),
            ("Money: %s  ·  +%s/s"):format(cash and short(cash) or "?", short(income)),
            "Now: " .. doing,
            "Time: " .. fmtTime(now - startedAt),
        }, "\n"))
    end

    local startDirector, stopDirector = makeLoop(tick, function() return 2 end)

    -------------------- ล็อค: เฉพาะคีย์ถาวร --------------------
    -- ถาม Worker ว่าคีย์ที่ loader จำไว้ (EndHub_key.txt) เป็นคีย์ถาวรไหม
    --   /check = ตรวจอย่างเดียว (Worker รุ่นใหม่) ไม่มี -> /auth (ได้ expires เหมือนกัน: ไม่มี expires = ถาวร)
    --   คืน "yes" / "no" / "error" (ตรวจไม่ได้ ไม่จำผล ลองใหม่ได้), ข้อความ
    --   ผล yes / no จำไว้ใน Kaitun.lifetime ตลอดการรันรอบนี้ (ไม่เก็บลงไฟล์)
    local API_URL = "https://endhub.kantapongboontawin1.workers.dev"
    local KEY_FILE = "EndHub_key.txt"
    local LOCK_TEXT = "Smart AI Kaitun requires a Permanent Key"

    local function checkLifetime()
        if Kaitun.lifetime == true then return "yes" end
        if Kaitun.lifetime == false then return "no", LOCK_TEXT end
        local httpRequest = request or http_request
            or (syn and syn.request) or (http and http.request)
        if not httpRequest then return "error", "This executor has no request(), cannot check the key" end

        local okKey, key = pcall(function()
            return isfile(KEY_FILE) and readfile(KEY_FILE) or nil
        end)
        key = okKey and type(key) == "string" and key:gsub("%s", "") or ""
        if key == "" then return "error", "No saved key found (run the loader and enter your key first)" end

        -- รหัสเครื่อง: ต้องได้ค่าเดียวกับ loader (ไม่งั้น Worker ตอบ hwid_mismatch)
        local hwid = nil
        local okH, id = pcall(function() return gethwid and gethwid() end)
        if okH and type(id) == "string" and id ~= "" then hwid = id end
        if not hwid then
            okH, id = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
            if okH and type(id) == "string" and id ~= "" then hwid = id end
        end
        if not hwid then return "error", "Cannot read the device ID, cannot check the key" end

        local function call(path)
            local ok, res = pcall(httpRequest, {
                Url = API_URL .. path,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({ key = key, hwid = hwid, user = LP.Name }),
            })
            if not ok or type(res) ~= "table" then return nil end
            local okJ, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
            return okJ and type(data) == "table" and data or nil
        end

        local data = call("/check")
        if not data or data.error == "not_found" then
            data = call("/auth")  -- Worker รุ่นเก่ายังไม่มี /check
        end
        if not data then return "error", "Cannot reach the key server, please try again" end
        if not data.ok then return "error", "Key check failed (" .. tostring(data.error) .. ")" end

        if type(data.lifetime) == "boolean" then
            Kaitun.lifetime = data.lifetime
        else
            Kaitun.lifetime = data.expires == nil  -- คีย์ถาวรไม่มีวันหมดอายุ
        end
        if Kaitun.lifetime then return "yes" end
        return "no", LOCK_TEXT
    end

    -------------------- เปิด / ปิด --------------------
    local function enable()
        if Kaitun.on then return end
        Kaitun.on = true
        Kaitun.maxZone = goalZone
        Kaitun.needPower = false
        goalDone = false
        startedAt, lastCash, lastT, income = os.clock(), nil, nil, 0
        applyToggles()
        extrasOn()
        if cfg.Persist == true then
            pcall(function()
                if makefolder and isfolder and not isfolder("EndHub") then makefolder("EndHub") end
                local saved = table.clone(cfg)
                saved.Enabled = true
                writefile(Kaitun.file, HttpService:JSONEncode(saved))
            end)
        end
        startDirector()
        Velvet:Notify({
            Title = "Kaitun",
            Content = ("เริ่มแล้ว เป้าหมาย Z%d%s"):format(goalZone, cfg.Goal.Research == true and " + research ครบ" or ""),
            Duration = 5, Type = "success",
        })
    end

    local function disable()
        if not Kaitun.on then return end
        Kaitun.on = false
        Kaitun.needPower = false
        Kaitun.doing, Kaitun.reached, Kaitun.goalText = nil, nil, nil
        stopDirector()
        extrasOff()
        pcall(function() if isfile(Kaitun.file) then delfile(Kaitun.file) end end)  -- ปิดเอง = เลิกจำ
        statusPara:Set("Off (farm toggles it turned on keep running: turn them off or press Stop All)")
    end

    -- ย้ายเซิร์ฟ / rejoin ขณะ Kaitun ทำงาน -> ทำงานต่อในเซิร์ฟใหม่
    --   1. เขียน config ลง Kaitun.file (_hop = true: ไม่ได้ Persist = ใช้แค่รอบหน้ารอบเดียว)
    --   2. queue_on_teleport: ล็อค fps ทันทีที่เข้า + โหลด End Hub (กันรันซ้ำกับ Auto Execute ด้วย JobId)
    local queueTp = queue_on_teleport or queueonteleport
        or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    local hopConn = LP.OnTeleport:Connect(function(state)
        if state ~= Enum.TeleportState.Started or not Kaitun.on then return end
        pcall(function()
            if makefolder and isfolder and not isfolder("EndHub") then makefolder("EndHub") end
            local saved = table.clone(cfg)
            saved.Enabled = true
            saved._hop = true
            writefile(Kaitun.file, HttpService:JSONEncode(saved))
        end)
        if queueTp then
            local lines = { "if not game:IsLoaded() then game.Loaded:Wait() end" }
            if capLock then table.insert(lines, ("pcall(setfpscap, %d)"):format(capLock)) end
            table.insert(lines, "local env = (getgenv and getgenv()) or _G; env.EndHubLite = true")
            table.insert(lines, "if env.EndHubAutoRan == game.JobId then return end")
            table.insert(lines, "env.EndHubAutoRan = game.JobId")
            table.insert(lines, 'pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/xMidNxtx/test/main/loader.lua"))() end)')
            pcall(queueTp, table.concat(lines, "\n"))
        end
    end)

    -- กด X ปิด End Hub: หยุดลูป + คืนค่า fps / 3D (ไม่ลบไฟล์ที่จำไว้)
    Kaitun.stop = function()
        hopConn:Disconnect()
        Kaitun.on = false
        stopDirector()
        extrasOff()
    end

    -- เปิด toggle: ตรวจคีย์ก่อน (ยิง HTTP เลยต้องอยู่ใน thread แยก) ผ่านแล้วค่อยเปิดจริง
    local checking = false
    local function tryEnable()
        if checking or Kaitun.on then return end
        checking = true
        statusPara:Set("Checking key...")
        local result, message = checkLifetime()
        checking = false
        if Velvet.Flags["KaitunMode"] ~= true then return end  -- ปิดไปแล้วระหว่างรอ
        if result == "yes" then
            enable()
            return
        end
        statusPara:Set("Locked: " .. tostring(message))
        Velvet:Notify({ Title = "Kaitun", Content = tostring(message), Duration = 6, Type = "error" })
        if result == "no" then
            -- ไม่ใช่คีย์ถาวร: เลิกจำ config ที่ Persist ไว้ จะได้ไม่เด้งเตือนทุกครั้งที่รัน
            pcall(function() if isfile(Kaitun.file) then delfile(Kaitun.file) end end)
        end
        setFlag("KaitunMode", false)
    end

    section:AddToggle("KaitunMode", {
        Text = "Smart AI Kaitun (Only Permanent Key)",
        Default = false,
        Callback = function(on)
            if on then task.spawn(tryEnable) else disable() end
        end,
    })

    -- ไม่มีคำอธิบายวิธีตั้งค่า _G.Kaitun ใน UI (ตั้งใจ: ไม่บอก client)
    --   คู่มืออยู่นอกสคริปต์ที่ Scripting/animeminerng/KAITUN_HOWTO.md (โฟลเดอร์นี้ไม่ขึ้น GitHub)

    -- _G.Kaitun.Enabled = true (หรือไฟล์ที่จำไว้) -> เปิดเองหลัง UI พร้อม
    if cfg.Enabled ~= false then
        task.defer(function() setFlag("KaitunMode", true) end)
    end
end
Kaitun.setup()

----------------------------------------------------------------
-- WATERMARK + QUICKBAR
----------------------------------------------------------------
Velvet:CreateWatermark({
    Text = "End Hub | {fps} fps | {ping} ms",
})

QuickBar:Pin("AutoSmartEquip", { Icon = "sparkles" })
QuickBar:Pin("AutoTakeChest", { Icon = "package" })
QuickBar:Pin("AutoSellOres", { Icon = "coins" })
QuickBar:Pin("Buy_Skill", { Icon = "flask-conical" })
QuickBar:Pin("AutoUpgradePlot", { Icon = "arrow-up" })
QuickBar:PinButton("Stop All", {
    Icon = "rotate-ccw",
    Callback = function()
        disableAllFunctions()  -- ตัวเดียวกับปุ่ม Disable All Functions ใน Settings
        Velvet:Notify({ Title = "Stop All", Content = "ปิดทุกฟังก์ชันแล้ว", Duration = 2, Type = "info" })
    end,
})

----------------------------------------------------------------
-- STARTUP NOTIFY
----------------------------------------------------------------
Velvet:Notify({
    Title = "End Hub v" .. VERSION,
    Content = "โหลดสำเร็จ",
    Duration = 4,
    Type = "success",
})
