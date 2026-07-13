local normal_webhook_url = "https://discord.com/api/webhooks/1523914403907371099/48Y1f7Mh3yPWLr6T_VpGrvZpJ9PWTjhNf6dFrixzQ1ZWJbMd1rtkqBmsPX-iEzIsymKW" 
local special_webhook_url = "https://discord.com/api/webhooks/1526046487778430977/Kd-Eq0sh0_-NB7ceEILYTE85hyjcBPNHyrzAFHKYyzsucR93Q7CDGqWLPH7zpm6IB-c1" 

-- CONFIGURATION 
local LOAD_DELAY = 3 
local SPECIAL_PETS = { "racoon", "goldendragonfly", "fih" } 

-- Universal request resolver for Delta/Mobile executors
local requestFunction = request or http_request or (syn and syn.request) or HttpPost 
local Http = game:GetService("HttpService") 
local TPS = game:GetService("TeleportService") 
local MS = game:GetService("MessagingService")
local Api = "https://games.roblox.com/v1/games/" 

-- Global tracking variables
local normalAlertLoopActive = false 
local specialAlertLoopActive = false 
local alertEmbedData = {} 
local specialEmbedData = {} 

-- ==========================================
-- ANTI-SAME-USER & SERVER HISTORY MANAGEMENT
-- ==========================================
local CACHE_FILE = "hop_history_" .. tostring(game.PlaceId) .. ".json"
local serverHistory = {}
local occupiedServers = {}

-- Load 5-server history tracking from local cache
local function loadHistory()
    if isfile and isfile(CACHE_FILE) then
        pcall(function()
            serverHistory = Http:JSONDecode(readfile(CACHE_FILE))
        end)
    end
    if type(serverHistory) ~= "table" then serverHistory = {} end
end

-- Save 5-server history tracking to local cache
local function saveHistory(newJobId)
    table.insert(serverHistory, newJobId)
    if #serverHistory > 5 then
        table.remove(serverHistory, 1)
    end
    if writefile then
        pcall(function()
            writefile(CACHE_FILE, Http:JSONEncode(serverHistory))
        end)
    end
end

loadHistory()

-- Real-time tracking of other users running this script
pcall(function()
    MS:SubscribeToTopic("ScriptUserTrackingGlobal", function(message)
        local data = message.Data
        if data and type(data) == "table" then
            if data.Action == "Ping" then
                occupiedServers[data.JobId] = os.time()
            elseif data.Action == "Leave" then
                occupiedServers[data.JobId] = nil
            end
        end
    end)
end)

-- Broadcast current server occupancy every 8 seconds
task.spawn(function()
    while true do
        pcall(function()
            MS:PublishAsync("ScriptUserTrackingGlobal", {
                Action = "Ping",
                JobId = game:JobId
            })
        end)
        task.wait(8)
    end
end)

-- Clear out server IDs from memory if they haven't pinged in 25 seconds
task.spawn(function()
    while true do
        local now = os.time()
        for jobId, timestamp in pairs(occupiedServers) do
            if now - timestamp > 25 then
                occupiedServers[jobId] = nil
            end
        end
        task.wait(10)
    end
end)

-- Notify other servers instantly when this user disconnects
game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == game.Players.LocalPlayer then
        pcall(function()
            MS:PublishAsync("ScriptUserTrackingGlobal", {
                Action = "Leave",
                JobId = game:JobId
            })
        end)
    end
end)

-- ==========================================
-- CORE UTILITIES & CLEANING FUNCTIONS
-- ==========================================
local function cleanName(fullName) 
    local str = tostring(fullName) 
    local base, firstIdSegment = string.match(str, "^([%w_]+_)[%w_]+_([%w]+)%-") 
    if base and firstIdSegment then 
        local cleanedBase = string.gsub(base, "^WildPet_", "") 
        return cleanedBase .. string.sub(firstIdSegment, 1, 2) 
    end 
    return string.gsub(str, "^WildPet_", "") 
end 

local function isSpecial(petName) 
    local name = tostring(petName):lower() 
    for _, specialName in pairs(SPECIAL_PETS) do 
        if string.find(name, specialName) then return true end 
    end 
    return false 
end 

local function postToWebhook(url, embedData) 
    if not requestFunction then return end 
    local cleanedUrl = url:gsub("discord.com", "webhook.lewisakura.moe"):gsub("discordapp.com", "webhook.lewisakura.moe") 
    local rawJoinLink = "https://7luk3e7.github.io/roblox/?placeId=" .. game.PlaceId .. "&jobId=" .. tostring(game.JobId) 
    local payload = { 
        ["embeds"] = { { 
            ["title"] = embedData.title or "Server Notification", 
            ["type"] = "rich", 
            ["description"] = "[**Click To Join Server**](" .. rawJoinLink .. ")", 
            ["color"] = embedData.color or 5763719, 
            ["fields"] = { { 
                ["name"] = embedData.fieldName or "Pets Found", 
                ["value"] = embedData.fieldValue or "No details available", 
                ["inline"] = false 
            } } 
        } } 
    } 
    pcall(function() 
        requestFunction({ 
            Url = cleanedUrl, 
            Method = "POST", 
            Headers = {["content-type"] = "application/json"}, 
            Body = Http:JSONEncode(payload) 
        }) 
    end) 
end 

local function triggerNormalAlertSpam(embedStructure) 
    alertEmbedData = embedStructure 
    if normalAlertLoopActive then return end 
    normalAlertLoopActive = true 
    task.spawn(function() 
        while normalAlertLoopActive do 
            postToWebhook(normal_webhook_url, alertEmbedData) 
            task.wait(2) 
        end 
    end) 
end 

local function triggerSpecialAlertSpam(embedStructure) 
    specialEmbedData = embedStructure 
    normalAlertLoopActive = false 
    if specialAlertLoopActive then return end 
    specialAlertLoopActive = true 
    task.spawn(function() 
        while specialAlertLoopActive do 
            postToWebhook(special_webhook_url, specialEmbedData) 
            task.wait(2) 
        end 
    end) 
end 

local function isUnwanted(petName) 
    local name = tostring(petName):lower() 
    if string.find(name, "bunny") or string.find(name, "owl") or string.find(name, "bear") or string.find(name, "robin") or string.find(name, "baldeagle") or string.find(name, "monkey") or string.find(name, "bee") or string.find(name, "fih") or string.find(name, "deer") or string.find(name, "turtle") or string.find(name, "frog") then 
        return true 
    end 
    return false 
end 

-- Optimized Server Hopping Engine
local hoppingStarted = false 
local function startHopping() 
    if hoppingStarted then return end 
    hoppingStarted = true 
    normalAlertLoopActive = false 
    specialAlertLoopActive = false 
    
    saveHistory(game.JobId)

    local _place = game.PlaceId 
    local _servers = Api.._place.."/servers/Public?sortOrder=Asc&limit=100" 
    
    local function ListServers(cursor) 
        local success, Raw = pcall(function() return game:HttpGet(_servers .. ((cursor and "&cursor="..cursor) or "")) end) 
        if success and Raw then return Http:JSONDecode(Raw) end 
        return nil 
    end 

    print("🚀 Filtering servers for script overlap & history...") 
    while true do 
        local chosenServer = nil 
        pcall(function() 
            local Servers = ListServers() 
            if Servers and Servers.data and #Servers.data > 0 then 
                local targetPool = {}
                for _, server in pairs(Servers.data) do
                    local skipThisServer = false
                    
                    -- Filter out last 5 servers visited
                    for _, oldId in pairs(serverHistory) do
                        if server.id == oldId then
                            skipThisServer = true
                            break
                        end
                    end
                    
                    -- Filter out servers with active matching script loops or full queues
                    if occupiedServers[server.id] or server.playing >= server.maxPlayers then
                        skipThisServer = true
                    end
                    
                    if not skipThisServer then
                        table.insert(targetPool, server)
                    end
                end
                
                -- Fallback to random if all listed servers fail strict filtering constraints
                if #targetPool > 0 then
                    chosenServer = targetPool[math.random(1, #targetPool)]
                else
                    chosenServer = Servers.data[math.random(1, #Servers.data)]
                end
            end 
        end) 

        if chosenServer then 
            pcall(function() 
                TPS:TeleportToPlaceInstance(_place, chosenServer.id, game.Players.LocalPlayer) 
            end) 
        end 
        task.wait(2) 
    end 
end 

local function getWantedPetCount(folder) 
    if not folder then return 0 end 
    local count = 0 
    for _, item in pairs(folder:GetChildren()) do 
        local name = item.Name 
        if isSpecial(name) or not isUnwanted(name) then 
            count = count + 1 
        end 
    end 
    return count 
end 

-- ==========================================
-- MAIN EXECUTION PIPELINE
-- ==========================================
local map = workspace:WaitForChild("Map", 10) 
local spawnsFolder = map and map:WaitForChild("WildPetSpawns", 10) 
task.wait(LOAD_DELAY) 

if spawnsFolder then 
    local initialItems = spawnsFolder:GetChildren() 
    local wantedPetsFound = {} 
    local specialPetsFound = {} 
    for _, item in pairs(initialItems) do 
        local name = tostring(item.Name) 
        if isSpecial(name) then 
            table.insert(specialPetsFound, cleanName(name)) 
        elseif not isUnwanted(name) then 
            table.insert(wantedPetsFound, cleanName(name)) 
        end 
    end 

    if #specialPetsFound > 0 then 
        local specialList = "" 
        for _, name in pairs(specialPetsFound) do 
