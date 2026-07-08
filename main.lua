local webhook_url = "https://discord.com/api/webhooks/1523914403907371099/48Y1f7Mh3yPWLr6T_VpGrvZpJ9PWTjhNf6dFrixzQ1ZWJbMd1rtkqBmsPX-iEzIsymKW"

-- CONFIGURATION
local LOAD_DELAY = 15 -- Time (in seconds) allowed for game files and pets to load into the server.

-- Configuration Object to encapsulate mutable global states
local State = {
    isHopping = false,
    alertLoopActive = false,
    alertMessage = "",
    alertThread = nil
}

-- Target list for quick O(1) unwanted pet lookups (Fixes hardcoded, brittle string.find matches)
local UNWANTED_PETS = {
    ["bunny"]      = true, ["owl"]    = true, ["butterfly"] = true,
    ["monkey"]     = true, ["baldeagle"] = true, ["bear"]   = true,
    ["bee"]        = true, ["robin"]  = true, ["deer"]      = true,
    ["turtle"]     = true, ["frog"]   = true
}

-- Universal request resolver for mobile/PC executors
local requestFunction = request or http_request or (syn and syn.request) or HttpPost
local Http = game:GetService("HttpService")
local TPS = game:GetService("TeleportService")
local Api = "https://games.roblox.com/v1/games/"

-- Webhook execution with explicit error logging instead of silent failure paths
local function sendToDiscord(messageText)
    if not requestFunction then 
        warn("❌ Request function not supported on this executor.")
        return 
    end
    
    local cleanedUrl = webhook_url:gsub("discord.com", "webhook.lewisakura.moe"):gsub("discordapp.com", "webhook.lewisakura.moe")
    
    local success, err = pcall(function()
        requestFunction({
            Url = cleanedUrl,
            Method = "POST",
            Headers = {["content-type"] = "application/json"},
            Body = Http:JSONEncode({ ["content"] = messageText })
        })
    end)
    
    if not success then
        warn("⚠️ Webhook Failed to Send: " .. tostring(err))
    end
end

-- Fast dictionary lookup helper
local function isUnwanted(petName)
    local name = tostring(petName):lower()
    return UNWANTED_PETS[name] == true
end

-- Thread-safe alert system manager (Fixes race conditions and memory leaks)
local function stopAlertLoop()
    State.alertLoopActive = false
    State.alertMessage = ""
    State.alertThread = nil
end

local function triggerAlertSpam(initialText)
    State.alertMessage = initialText
    if State.alertLoopActive then return end
    
    State.alertLoopActive = true
    State.alertThread = task.spawn(function()
        local backoff = 2
        while State.alertLoopActive do
            sendToDiscord(State.alertMessage)
            task.wait(backoff)
        end
    end)
end

-- Reusable Server Hopping Function (Fixes infinite loops and added exponential adaptive backoff)
local function startHopping()
    if State.isHopping then return end
    State.isHopping = true
    
    stopAlertLoop() -- Terminate alerts instantly on server hop initialization
    
    local _place = game.PlaceId
    local _servers = Api.._place.."/servers/Public?sortOrder=Asc&limit=100"
    
    local function ListServers(cursor)
        local success, Raw = pcall(function()
            return game:HttpGet(_servers .. ((cursor and "&cursor="..cursor) or ""))
        end)
        if success and Raw then 
            return Http:JSONDecode(Raw) 
        elseif not success then
            warn("⚠️ API Failure fetching servers: " .. tostring(Raw))
        end
        return nil
    end
    
    print("🚀 Starting auto-hop sequence...")
    
    local baseWaitTime = 2
    local attempts = 0
    
    while State.isHopping do
        attempts = attempts + 1
        local chosenServer = nil
        
        local success, err = pcall(function()
            local Servers = ListServers()
            if Servers and Servers.data and #Servers.data > 0 then
                chosenServer = Servers.data[math.random(1, #Servers.data)]
            end
        end)
        
        if not success then
            warn("⚠️ Error parsing servers on attempt " .. attempts .. ": " .. tostring(err))
        end
        
        if chosenServer then
            local tpSuccess, tpErr = pcall(function()
                TPS:TeleportToPlaceInstance(_place, chosenServer.id, game.Players.LocalPlayer)
            end)
            if not tpSuccess then
                warn("⚠️ Teleport failed: " .. tostring(tpErr))
            end
        end
        
        -- Adaptive Backoff: scales waiting penalty upwards under constant API failures to protect rate-limits
        local adaptiveWait = math.min(baseWaitTime * (1.5 ^ (attempts - 1)), 30)
        task.wait(adaptiveWait)
    end
end

-- Helper function to count how many wanted pets are currently spawned
local function getWantedPetCount(folder)
    if not folder then return 0 end
    local count = 0
    for _, item in pairs(folder:GetChildren()) do
        if not isUnwanted(item.Name) then
            count = count + 1
        end
    end
    return count
end

-- Main Check & Notification Sequence
local map = workspace:WaitForChild("Map", 10)
local spawnsFolder = map and map:WaitForChild("WildPetSpawns", 10)

task.wait(LOAD_DELAY)

if spawnsFolder then
    local joinLink = string.format("https://7luk3e7.github.io/roblox/?placeId=%d&jobId=%s", game.PlaceId, tostring(game.JobId))
    local initialItems = spawnsFolder:GetChildren()
    local wantedPetsFound = {}
    
    for _, item in pairs(initialItems) do
        local name = tostring(item.Name)
        if not isUnwanted(name) then
            table.insert(wantedPetsFound, name)
        end
    end
    
    if #wantedPetsFound > 0 then
        local initialList = "📋 **Current target items in folder:**\n"
        for _, name in pairs(wantedPetsFound) do
            initialList = initialList .. "• " .. name .. "\n"
        end
        initialList = initialList .. "\n" .. joinLink
        triggerAlertSpam(initialList)
    else
        startHopping()
    end
    
    -- Track event connections so they can be garbage collected if script scales up
    local connections = {}
    
    connections.ChildAdded = spawnsFolder.ChildAdded:Connect(function(newItem)
        task.wait(0.1)
        local name = tostring(newItem.Name)
        if not isUnwanted(name) then
            local newSpawnAlert = "✨ **New rare item spawned:** " .. name .. "\n\n" .. joinLink
            triggerAlertSpam(newSpawnAlert)
        end
    end)
    
    connections.ChildRemoved = spawnsFolder.ChildRemoved:Connect(function()
        task.wait(0.5)
        if getWantedPetCount(spawnsFolder) == 0 then
            print("📉 All wanted pets are gone. Leaving server...")
            
            -- Disconnect listeners before tearing down the scene to prevent memory leaks
            for _, conn in pairs(connections) do 
                if conn.Connected then conn:Disconnect() end 
            end
            
            startHopping()
        end
    end)
else
    warn("❌ Path workspace.Map.WildPetSpawns could not be found.")
    startHopping()
end
