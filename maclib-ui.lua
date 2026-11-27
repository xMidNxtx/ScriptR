local ok, MacLib = pcall(function()
    return loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()
end)
if not ok or type(MacLib) ~= "table" then warn("[End Hub] MacLib load failed:", MacLib) return end

local Window = MacLib:Window({
    Title = "End Hub",
    Subtitle = "MacLib Edition",
    Size = UDim2.fromOffset(868, 650),
    DragStyle = 1,
    DisabledWindowControls = {},
    ShowUserInfo = true,
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
})

MacLib:SetFolder("EndHub")

local tabGroups = {
    Main = Window:TabGroup(),
    Util = Window:TabGroup(),
    Config = Window:TabGroup(),
}

local tabs = {
    Combat = tabGroups.Main:Tab({ Name = "Combat", Image = "rbxassetid://10734950309" }),
    Visuals = tabGroups.Main:Tab({ Name = "Visuals", Image = "rbxassetid://18821914323" }),
    Player = tabGroups.Util:Tab({ Name = "Player", Image = "rbxassetid://10734950309" }),
    Misc = tabGroups.Util:Tab({ Name = "Misc", Image = "rbxassetid://18821914323" }),
    Settings = tabGroups.Config:Tab({ Name = "Settings", Image = "rbxassetid://10734950309" }),
}

local sections = {
    CombatL = tabs.Combat:Section({ Side = "Left" }),
    CombatR = tabs.Combat:Section({ Side = "Right" }),
    VisualsL = tabs.Visuals:Section({ Side = "Left" }),
    VisualsR = tabs.Visuals:Section({ Side = "Right" }),
    PlayerL = tabs.Player:Section({ Side = "Left" }),
    PlayerR = tabs.Player:Section({ Side = "Right" }),
    MiscL = tabs.Misc:Section({ Side = "Left" }),
    MiscR = tabs.Misc:Section({ Side = "Right" }),
    SettingsL = tabs.Settings:Section({ Side = "Left" }),
    SettingsR = tabs.Settings:Section({ Side = "Right" }),
}

sections.CombatL:Header({ Name = "Aimbot" })

sections.CombatL:Toggle({
    Name = "Enable Aimbot",
    Default = false,
    Callback = function(state) end,
}, "AimbotEnabled")

sections.CombatL:Dropdown({
    Name = "Target Part",
    Multi = false,
    Options = { "Head", "HumanoidRootPart", "Torso", "UpperTorso" },
    Default = 1,
    Callback = function(opt) end,
}, "TargetPart")

sections.CombatL:Slider({
    Name = "FOV Radius",
    Default = 150,
    Minimum = 10,
    Maximum = 500,
    DisplayMethod = "Value",
    Precision = 0,
    Callback = function(val) end,
}, "FOVRadius")

sections.CombatL:Keybind({
    Name = "Aim Key",
    Default = Enum.KeyCode.E,
    Callback = function() end,
}, "AimKey")

sections.CombatR:Header({ Name = "Silent Aim" })

sections.CombatR:Toggle({
    Name = "Enable Silent Aim",
    Default = false,
    Callback = function(state) end,
}, "SilentAimEnabled")

sections.CombatR:Slider({
    Name = "Hit Chance",
    Default = 100,
    Minimum = 1,
    Maximum = 100,
    DisplayMethod = "Percent",
    Precision = 0,
    Callback = function(val) end,
}, "HitChance")

sections.CombatR:Dropdown({
    Name = "Prediction Method",
    Multi = false,
    Options = { "None", "Linear", "Quadratic" },
    Default = 1,
    Callback = function(opt) end,
}, "Prediction")

sections.CombatR:Divider()
sections.CombatR:Label({ Text = "Silent aim sends hit requests server-side" })

sections.VisualsL:Header({ Name = "ESP" })

sections.VisualsL:Toggle({
    Name = "Enable ESP",
    Default = false,
    Callback = function(state) end,
}, "ESPEnabled")

sections.VisualsL:Dropdown({
    Name = "ESP Elements",
    Multi = true,
    Options = { "Box", "Name", "Health", "Distance", "Tracer", "Skeleton" },
    Default = { "Box", "Name", "Health" },
    Callback = function(selected) end,
}, "ESPElements")

sections.VisualsL:Colorpicker({
    Name = "ESP Color",
    Default = Color3.fromRGB(99, 102, 241),
    Callback = function(color) end,
}, "ESPColor")

sections.VisualsL:Slider({
    Name = "Max Distance",
    Default = 2000,
    Minimum = 100,
    Maximum = 5000,
    DisplayMethod = "Value",
    Precision = 0,
    Callback = function(val) end,
}, "ESPDistance")

sections.VisualsR:Header({ Name = "Chams" })

sections.VisualsR:Toggle({
    Name = "Enable Chams",
    Default = false,
    Callback = function(state) end,
}, "ChamsEnabled")

sections.VisualsR:Colorpicker({
    Name = "Visible Color",
    Default = Color3.fromRGB(52, 211, 153),
    Callback = function(color) end,
}, "ChamsVisible")

sections.VisualsR:Colorpicker({
    Name = "Hidden Color",
    Default = Color3.fromRGB(248, 113, 113),
    Callback = function(color) end,
}, "ChamsHidden")

sections.VisualsR:Slider({
    Name = "Opacity",
    Default = 50,
    Minimum = 0,
    Maximum = 100,
    DisplayMethod = "Percent",
    Precision = 0,
    Callback = function(val) end,
}, "ChamsOpacity")

sections.VisualsR:Divider()
sections.VisualsR:Label({ Text = "Chams use Highlight instances" })

sections.PlayerL:Header({ Name = "Movement" })

sections.PlayerL:Slider({
    Name = "Walk Speed",
    Default = 16,
    Minimum = 0,
    Maximum = 200,
    DisplayMethod = "Value",
    Precision = 0,
    Callback = function(val)
        local char = game:GetService("Players").LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = val end
        end
    end,
}, "WalkSpeed")

sections.PlayerL:Slider({
    Name = "Jump Power",
    Default = 50,
    Minimum = 0,
    Maximum = 500,
    DisplayMethod = "Value",
    Precision = 0,
    Callback = function(val)
        local char = game:GetService("Players").LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.JumpPower = val end
        end
    end,
}, "JumpPower")

sections.PlayerL:Toggle({
    Name = "Infinite Jump",
    Default = false,
    Callback = function(state) end,
}, "InfJump")

sections.PlayerL:Toggle({
    Name = "Noclip",
    Default = false,
    Callback = function(state) end,
}, "Noclip")

sections.PlayerR:Header({ Name = "Teleport" })

sections.PlayerR:Input({
    Name = "Player Name",
    Placeholder = "username...",
    AcceptedCharacters = "All",
    Callback = function(text) end,
}, "TpTarget")

sections.PlayerR:Button({
    Name = "Teleport to Player",
    Callback = function()
        local name = MacLib.Options["TpTarget"] and MacLib.Options["TpTarget"].Text or ""
        if name == "" then return end
        local Players = game:GetService("Players")
        for _, p in Players:GetPlayers() do
            if p.Name:lower():find(name:lower()) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                Players.LocalPlayer.Character.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame
                break
            end
        end
    end,
})

sections.PlayerR:Divider()

sections.PlayerR:Button({
    Name = "Teleport to Spawn",
    Callback = function()
        local spawn = workspace:FindFirstChild("SpawnLocation") or workspace:FindFirstChildOfClass("SpawnLocation")
        if spawn and game:GetService("Players").LocalPlayer.Character then
            game:GetService("Players").LocalPlayer.Character:SetPrimaryPartCFrame(spawn.CFrame + Vector3.new(0, 5, 0))
        end
    end,
})

sections.MiscL:Header({ Name = "Server" })

sections.MiscL:Button({
    Name = "Rejoin Server",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, game:GetService("Players").LocalPlayer)
    end,
})

sections.MiscL:Button({
    Name = "Server Hop",
    Callback = function()
        local HttpService = game:GetService("HttpService")
        local req = (request or http_request or (syn and syn.request) or (http and http.request))
        if not req then return end
        local ok2, res = pcall(req, {
            Url = "https://games.roblox.com/v1/games/" .. game.GameId .. "/servers/Public?sortOrder=Asc&limit=100",
            Method = "GET",
        })
        if ok2 and res and res.Body then
            local data = HttpService:JSONDecode(res.Body)
            if data and data.data then
                for _, srv in data.data do
                    if srv.id ~= game.JobId and srv.playing < srv.maxPlayers then
                        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, srv.id)
                        return
                    end
                end
            end
        end
    end,
})

sections.MiscL:Button({
    Name = "Copy Server ID",
    Callback = function()
        if setclipboard then setclipboard(game.JobId) end
    end,
})

sections.MiscL:Divider()

sections.MiscL:Toggle({
    Name = "Anti AFK",
    Default = true,
    Callback = function(state)
        if state then
            local vu = game:GetService("VirtualUser")
            game:GetService("Players").LocalPlayer.Idled:Connect(function()
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end)
        end
    end,
}, "AntiAFK")

sections.MiscR:Header({ Name = "Utility" })

sections.MiscR:Button({
    Name = "Unlock FPS",
    Callback = function()
        if setfpscap then setfpscap(999) end
    end,
})

sections.MiscR:Slider({
    Name = "FPS Cap",
    Default = 60,
    Minimum = 15,
    Maximum = 360,
    DisplayMethod = "Value",
    Precision = 0,
    Callback = function(val)
        if setfpscap then setfpscap(val) end
    end,
}, "FPSCap")

sections.MiscR:Toggle({
    Name = "Fullbright",
    Default = false,
    Callback = function(state)
        local lighting = game:GetService("Lighting")
        if state then
            lighting.Brightness = 2
            lighting.ClockTime = 14
            lighting.FogEnd = 100000
            lighting.GlobalShadows = false
        else
            lighting.Brightness = 1
            lighting.ClockTime = 14
            lighting.FogEnd = 10000
            lighting.GlobalShadows = true
        end
    end,
}, "Fullbright")

sections.MiscR:Divider()

sections.MiscR:Paragraph({
    Header = "End Hub",
    Body = "MacLib Edition | universal template\nKeybind: RightControl to toggle UI",
})

sections.SettingsL:Header({ Name = "Configuration" })

sections.SettingsL:Input({
    Name = "Config Name",
    Placeholder = "my-config",
    AcceptedCharacters = "All",
    Callback = function(input) end,
}, "ConfigName")

sections.SettingsL:Button({
    Name = "Save Config",
    Callback = function()
        local name = (MacLib.Options["ConfigName"] and MacLib.Options["ConfigName"].Text or "default")
        MacLib:SaveConfig(name)
        Window:Notify({
            Title = "Config Saved",
            Description = name,
            Lifetime = 3,
        })
    end,
})

sections.SettingsL:Button({
    Name = "Load Config",
    Callback = function()
        local name = (MacLib.Options["ConfigName"] and MacLib.Options["ConfigName"].Text or "default")
        MacLib:LoadConfig(name)
        Window:Notify({
            Title = "Config Loaded",
            Description = name,
            Lifetime = 3,
        })
    end,
})

sections.SettingsR:Header({ Name = "UI Settings" })

sections.SettingsR:Slider({
    Name = "UI Scale",
    Default = 100,
    Minimum = 50,
    Maximum = 150,
    DisplayMethod = "Percent",
    Precision = 0,
    Callback = function(val) Window:SetScale(val / 100) end,
}, "UIScale")

sections.SettingsR:Keybind({
    Name = "Toggle Keybind",
    Default = Enum.KeyCode.RightControl,
    Callback = function() end,
    onBinded = function(bind) Window:SetKeybind(bind) end,
}, "ToggleBind")

sections.SettingsR:Toggle({
    Name = "Show User Info",
    Default = true,
    Callback = function(state) Window:SetUserInfoState(state) end,
}, "ShowUserInfo")

sections.SettingsR:Toggle({
    Name = "Acrylic Blur",
    Default = true,
    Callback = function(state) Window:SetAcrylicBlurState(state) end,
}, "AcrylicBlur")

sections.SettingsR:Divider()

sections.SettingsR:Button({
    Name = "Destroy UI",
    Callback = function()
        Window:Dialog({
            Title = "Confirm",
            Description = "Destroy End Hub UI?",
            Buttons = {
                { Name = "Yes", Callback = function() Window:Unload() end },
                { Name = "Cancel", Callback = function() end },
            },
        })
    end,
})

sections.SettingsR:Spacer()

sections.SettingsR:Paragraph({
    Header = "End Hub — MacLib Edition",
    Body = "github.com/xMidNxtx\nMacLib by biggaboy212",
})

tabs.Settings:InsertConfigSection("Right")

tabs.Combat:Select()

Window:Notify({
    Title = "End Hub",
    Description = "Loaded successfully | RightControl to toggle",
    Lifetime = 5,
})
