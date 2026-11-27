-- End Hub - Loader (Key System)
--
-- ไฟล์นี้คือไฟล์ที่แจกให้ผู้ใช้รัน สคริปต์หลักไม่ได้อยู่ในนี้
-- ขั้นตอน: ใส่คีย์ -> ส่ง key + HWID + GameId ไปตรวจที่ Cloudflare Worker
--          -> ถ้าผ่าน Worker ส่งสคริปต์ของเกมนั้นกลับมา แล้วค่อยรัน
--             (Anime Mining RNG / Raycity RB ใช้ loader + คีย์ตัวเดียวกัน)
-- (ดูวิธีตั้งค่า Worker ที่ keysystem/README.md)

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local API_URL = "https://endhub.kantapongboontawin1.workers.dev"
local APP_SECRET = "efd17ee3a7695e1ddf66bdaa16775fdbbd8a50f6b20d508a"
local KEY_FILE = "EndHub_key.txt"                  -- จำคีย์ไว้ ครั้งหน้าไม่ต้องใส่ใหม่

-- Kaitun Lite (ไม่มีหน้าต่าง กินแรมน้อย): ตั้ง _G.Kaitun = { Lite = true, ... } ก่อนรัน loader
--   หรือ EndHubLite = true (Kaitun Lite ตั้งเองตอนย้ายเซิร์ฟ ใช้ครั้งเดียวแล้วล้าง)
--   Worker ส่งตัว Lite ให้เฉพาะคีย์ถาวร (คีย์อื่นได้สคริปต์ปกติ)
local VARIANT = (function()
    local env = (getgenv and getgenv()) or _G
    local k = (type(env.Kaitun) == "table" and env.Kaitun) or (type(_G.Kaitun) == "table" and _G.Kaitun)
    local hop = env.EndHubLite == true
    env.EndHubLite = nil
    if hop or (k and k.Lite == true) then return "kaitun" end
    return nil
end)()

----------------------------------------------------------------
-- SERVICES / EXECUTOR API
----------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- autoexec รันก่อนเกม/ตัวผู้เล่นพร้อม (บางทีตอน Roblox ยังเปิดไม่เสร็จ PlaceId = 0): รอให้ครบก่อน
--   ไม่งั้น Players.LocalPlayer.Name พัง (attempt to index nil with 'Name')
repeat
    task.wait(0.25)
until game:IsLoaded() and game.PlaceId ~= 0 and Players.LocalPlayer

local httpRequest = request or http_request
    or (syn and syn.request) or (http and http.request)

-- รหัสประจำเครื่อง: ใช้ของ executor ก่อน ถ้าไม่มีใช้ ClientId ของ Roblox
local function getHwid()
    local ok, id = pcall(function() return gethwid and gethwid() end)
    if ok and type(id) == "string" and id ~= "" then return id end
    ok, id = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if ok and type(id) == "string" and id ~= "" then return id end
    return nil
end

local ERROR_TEXT = {
    invalid_key   = "คีย์ไม่ถูกต้อง",
    hwid_mismatch = "คีย์นี้ถูกใช้กับเครื่องอื่นแล้ว (ติดต่อแอดมินเพื่อรีเซ็ต)",
    expired       = "คีย์หมดอายุแล้ว",
    bad_hwid      = "อ่านรหัสเครื่องไม่ได้",
    no_script     = "เซิร์ฟเวอร์ยังไม่มีสคริปต์ (แจ้งแอดมิน)",
    forbidden     = "โหลดเดอร์ไม่ผ่านการยืนยัน (ใช้ไฟล์ทางการเท่านั้น)",
    bad_session   = "เซสชันหมดอายุ ลองใหม่อีกครั้ง",
}

-- คีย์ที่เซิร์ฟเวอร์ปฏิเสธแน่นอน -> ลบคีย์ที่จำไว้ทิ้ง
local REJECTED = { invalid_key = true, hwid_mismatch = true, expired = true }

-- ส่งคีย์ไปตรวจ
-- คืนค่า: data (ตารางที่มี script) เมื่อผ่าน / nil, ข้อความ, รหัส error เมื่อไม่ผ่าน
local function auth(key)
    if not httpRequest then
        return nil, "executor นี้ไม่รองรับ request()"
    end
    local hwid = getHwid()
    if not hwid then
        return nil, ERROR_TEXT.bad_hwid
    end

    local post = function(path, payload)
        local ok, res = pcall(httpRequest, {
            Url = API_URL .. path,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload),
        })
        if not ok or type(res) ~= "table" then
            return nil, "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้"
        end
        local decoded, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
        if not decoded or type(data) ~= "table" then
            return nil, "เซิร์ฟเวอร์ตอบกลับผิดปกติ (" .. tostring(res.StatusCode) .. ")"
        end
        return data
    end

    local shake, err1 = post("/handshake", {
        app = APP_SECRET,
        key = key,
        hwid = hwid,
        user = Players.LocalPlayer and Players.LocalPlayer.Name or "",
        game = tostring(game.GameId),
        place = tostring(game.PlaceId),
        variant = VARIANT,
    })
    if not shake then return nil, err1 end
    if not shake.ok or type(shake.sid) ~= "string" then
        local code = tostring(shake.error)
        return nil, ERROR_TEXT[code] or ("ผิดพลาด: " .. code), code
    end

    local data, err2 = post("/auth", { sid = shake.sid, hwid = hwid })
    if not data then return nil, err2 end
    if not data.ok or type(data.script) ~= "string" then
        local code = tostring(data.error)
        return nil, ERROR_TEXT[code] or ("ผิดพลาด: " .. code), code
    end
    data.free = shake.free
    return data
end

local function readSavedKey()
    local ok, key = pcall(function()
        return isfile and isfile(KEY_FILE) and readfile(KEY_FILE) or nil
    end)
    return ok and type(key) == "string" and key ~= "" and key or nil
end

local function forgetKey()
    pcall(function() if isfile and isfile(KEY_FILE) then delfile(KEY_FILE) end end)
end

-- คืน true = รันแล้ว / false = สคริปต์ที่ได้มาพัง (เน็ตตัดกลางทาง) ให้ขอใหม่
local function runScript(source)
    local fn, err = loadstring(source, "=EndHub")
    if not fn then
        warn("[End Hub] โหลดสคริปต์ไม่ได้:", err)
        return false
    end
    local env = (getgenv and getgenv()) or _G
    env.EndHubLoaded = true
    env.EndHubLoaderBusy = nil
    task.spawn(fn)
    return true
end

-- กัน loader ซ้อนกันตอนที่อีกตัวยังทำงานอยู่ (autoexec + กดรันเอง = หน้าต่างคีย์ซ้อน)
--   ทำงานเสร็จ / เกิน 60 วิ = รันใหม่ได้ (รันซ้ำเพื่อโหลดเวอร์ชันใหม่ได้ตามปกติ)
do
    local env = (getgenv and getgenv()) or _G
    if type(env.EndHubLoaderBusy) == "number" and os.clock() - env.EndHubLoaderBusy < 60 then
        return
    end
    env.EndHubLoaderBusy = os.clock()
end

----------------------------------------------------------------
-- 1) มีคีย์ที่จำไว้ -> ลองตรวจเลย ไม่ต้องเปิดหน้าต่าง
--    เน็ต / เซิร์ฟเวอร์ยังไม่พร้อม (autoexec รันเร็ว) = ลองใหม่ทุก 3 วิ สูงสุด 10 ครั้ง
--    คีย์ผิด / หมดอายุ / คนละเครื่อง = หยุดลอง เปิดหน้าต่างใส่คีย์
----------------------------------------------------------------
local startMessage = "ใส่คีย์แล้วกด Verify"
local savedKey = readSavedKey()
if not savedKey then
    local freeData = auth("FREE")
    if freeData and freeData.free and runScript(freeData.script) then
        return
    end
end
if savedKey then
    for attempt = 1, 10 do
        local data, message, code = auth(savedKey)
        if data and runScript(data.script) then
            return
        end
        if REJECTED[code] then
            forgetKey()
            startMessage = message
            break
        end
        startMessage = message or "โหลดสคริปต์ไม่สำเร็จ"
        warn(("[End Hub] โหลดไม่สำเร็จ (%s) ลองใหม่ %d/10"):format(tostring(startMessage), attempt))
        task.wait(3)
    end
end

local UI_URL = "https://raw.githubusercontent.com/xMidNxtx/ScriptR/refs/heads/main/ui.lua"
local MacLib
for _ = 1, 5 do
    local ok, lib = pcall(function()
        return loadstring(game:HttpGet(UI_URL))()
    end)
    if ok and type(lib) == "table" and lib.Window then
        MacLib = lib
        break
    end
    task.wait(2)
end
if not MacLib then
    warn("[End Hub] โหลดหน้าต่างใส่คีย์ไม่ได้ (เน็ต?) ลองรัน loader ใหม่")
    local env = (getgenv and getgenv()) or _G
    env.EndHubLoaderBusy = nil
    return
end

local Window = MacLib:Window({
    Title = "End Hub",
    Subtitle = "Key System",
    Size = UDim2.fromOffset(640, 420),
    DragStyle = 2,
    ShowUserInfo = true,
    Keybind = Enum.KeyCode.RightShift,
    AcrylicBlur = true,
    Footer = { Left = "Key System", Right = "End Hub" },
})
local tab = Window:TabGroup({ Name = "Access" }):Tab({ Name = "Key", Image = "rbxassetid://10734950309" })
local left = tab:Section({ Side = "Left", Title = "Whitelist" })
local right = tab:Section({ Side = "Right", Title = "Status" })

local status = right:Paragraph({ Header = "สถานะ", Body = startMessage })
local function setStatus(text)
    pcall(function() status:UpdateBody(text) end)
end

local keyText = ""
left:Input({
    Name = "Key",
    Placeholder = "END-XXXXX-XXXXX-XXXXX-XXXXX",
    AcceptedCharacters = "All",
    onChanged = function(text) keyText = text end,
    Callback = function(text) keyText = text end,
})

local busy = false
left:Button({
    Name = "Verify",
    Callback = function()
        if busy then return end
        local key = (keyText or ""):gsub("%s", "")
        if key == "" then
            setStatus("กรุณาใส่คีย์ก่อน")
            return
        end

        busy = true
        setStatus("กำลังตรวจสอบ...")
        local data, message = auth(key)
        if not data then
            setStatus(message)
            busy = false
            return
        end

        pcall(writefile, KEY_FILE, key)
        if not runScript(data.script) then
            setStatus("โหลดสคริปต์ไม่สำเร็จ กด Verify อีกครั้ง")
            busy = false
            return
        end
        pcall(function() Window:Unload() end)
    end,
})

left:Button({
    Name = "Get Key",
    Callback = function()
        local link = API_URL .. "/getkey"
        if setclipboard then
            pcall(setclipboard, link)
            setStatus("คัดลอกลิงก์รับคีย์แล้ว เปิดในเบราว์เซอร์\n" .. link)
        else
            setStatus("เปิดลิงก์นี้เพื่อรับคีย์\n" .. link)
        end
    end,
})

right:Label({ Text = "คีย์จะถูกจำไว้ ครั้งหน้าไม่ต้องใส่ใหม่ · ซื้อคีย์ถาวรได้ใน Discord ด้วยคำสั่ง /buy" })

tab:Select()
