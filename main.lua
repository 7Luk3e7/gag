-- CONFIGURATION
local MAIN_WEBHOOK = "https://discord.com/api/webhooks/1526056984112140370/n-YJtoOZ5BlBN0kMR1oLiPkRw1IEMIG-beJvs36iMbVRLD6v3B2KGNBfbPRLI4JPFsY8"
local SECONDARY_WEBHOOK = "https://discord.com/api/webhooks/1526056984112140370/n-YJtoOZ5BlBN0kMR1oLiPkRw1IEMIG-beJvs36iMbVRLD6v3B2KGNBfbPRLI4JPFsY8"
local LOAD_DELAY = 3 -- Time (in seconds) allowed for game files and pets to load into the server.

-- Pets added here will only be sent to the SECONDARY webhook and will NOT trigger the main webhook
local SECONDARY_LIST = {
    "raccoon"
    -- Add more pets here using lowercase text, separated by commas (e.g., "fox", "cat")
}

-- Services
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local TPS = game:GetService("TeleportService")

-- Universal request resolver for mobile/PC executors
local requestFunction = request or http_request or (syn and syn.request) or HttpPost
local Api = "https://games.roblox.com/v1/games/"

-- Global tracking variable to manage the repeating notification stream
local alertLoopActive = false
local alertEmbedData = {}
local targetWebhookUsed = MAIN_WEBHOOK

-- Helper function to format the pet's name to drop "WildPet_" and only include the name and the start of the ID
local function cleanName(fullName)
    local str = tostring(fullName)
    local base, firstIdSegment = string.match(str, "^([%w_]+_)[%w_]+_([%w]+)%-")
    if base and firstIdSegment then
        local cleanedBase = string.gsub(base, "^WildPet_", "")
        return cleanedBase .. string.sub(firstIdSegment, 1, 2)
    end
    return string.gsub(str, "^WildPet_", "")
end

-- Modified to bundle the click to join option directly inside the embed description
local function sendToDiscord(embedData, urlToUse)
    if not requestFunction then return end
    local currentUrl = urlToUse or MAIN_WEBHOOK
    local cleanedUrl = currentUrl:gsub("discord.com", "webhook.lewisakura.moe"):gsub("discordapp.com", "webhook.lewisakura.moe")
    local rawJoinLink = "https://7luk3e7.github.io/roblox/?placeId=" .. game.PlaceId .. "&jobId=" .. tostring(game.JobId)
    
    local payload = {
        ["embeds"] = {
            {
                ["title"] = embedData.title or "Server Notification",
                ["type"] = "rich",
                ["description"] = "[**Click To Join Server**](" .. rawJoinLink .. ")",
                ["color"] = 5763719, -- Vibrant Green (#57F287)
                ["fields"] = {
                    {
                        ["name"] = embedData.fieldName or "Pets Found",
                        ["value"] = embedData.fieldValue or "No details available",
                        ["inline"] = false
                    }
                }
            }
        }
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

-- Helper check function to find unwanted pets (Modified with priority bypass)
local function isUnwanted(petName)
    local name = tostring(petName):lower()
    
    -- Priority Bypass: If the name contains big, mega, or rainbow, it is always wanted
    if string.find(name, "big") or string.find(name, "mega") or string.find(name, "rainbow") then
        return false
    end
    
    -- Standard filter list
    if string.find(name, "bunny") or string.find(name, "owl") or string.find(name, "bear") or 
       string.find(name, "robin") or string.find(name, "baldeagle") or string.find(name, "monkey") or 
       string.find(name, "bee") or string.find(name, "fih") or string.find(name, "deer") or 
       string.find(name, "turtle") or string.find(name, "frog") then
        return true
    end
    
    return false
end

-- Helper check function to find if a pet belongs to the secondary list
local function isSecondaryPet(petName)
    local name = tostring(petName):lower()
    for _, secondaryName in ipairs(SECONDARY_LIST) do
        if string.find(name, secondaryName:lower()) then
            return true
        end
    end
    return false
end

-- Reusable Server Hopping Function (Tries every 2 seconds until successful)
local hoppingStarted = false
local function startHopping()
    if hoppingStarted then return end
    hoppingStarted = true
    alertLoopActive = false
    local _place = game.PlaceId
    local _servers = Api.._place.."/servers/Public?sortOrder=Asc&limit=100"
    
    local function ListServers(cursor)
        local success, Raw = pcall(function() return game:HttpGet(_servers .. ((cursor and "&cursor="..cursor) or "")) end)
        if success and Raw then return Http:JSONDecode(Raw) end
        return nil
    end
    
    print("🚀 Starting auto-hop sequence...")
    while true do
        local chosenServer = nil
        pcall(function()
            local Servers = ListServers()
            if Servers and Servers.data and #Servers.data > 0 then
                chosenServer = Servers.data[math.random(1, #Servers.data)]
            end
        end)
        
        if chosenServer then
            pcall(function()
                TPS:TeleportToPlaceInstance(_place, chosenServer.id, Players.LocalPlayer)
            end)
        end
        task.wait(2)
    end
end

-- Check if specific players are in the game or join later
local function checkPlayer(player)
    if player and player.Name == "Iulkay" then
        print("🚨 Target player Iulkay joined! Initiating auto-hop...")
        startHopping()
    end
end

Players.PlayerAdded:Connect(checkPlayer)
for _, player in ipairs(Players:GetPlayers()) do
    checkPlayer(player)
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

-- Modified thread to send exactly 2 times and then auto-leave/hop
local function triggerAlertSpam(embedStructure, webhookUrl)
    alertEmbedData = embedStructure
    targetWebhookUsed = webhookUrl
    if alertLoopActive then return end
    alertLoopActive = true
    
    task.spawn(function()
        local sendCount = 0
        while alertLoopActive and sendCount < 2 do
            sendToDiscord(alertEmbedData, targetWebhookUsed)
            sendCount = sendCount + 1
            if sendCount < 2 then
                task.wait(2) -- Interval between the first and second webhook
            end
        end
        print("🛑 Dispatched 2 webhooks. Initiating auto-hop sequence...")
        startHopping()
    end)
end

-- Main Check & Notification Sequence
local map = workspace:WaitForChild("Map", 10)
local spawnsFolder = map and map:WaitForChild("WildPetSpawns", 10)

task.wait(LOAD_DELAY)

if spawnsFolder then
    local initialItems = spawnsFolder:GetChildren()
    local wantedPetsFound = {}
    local secondaryPetsFound = {}
    
    for _, item in pairs(initialItems) do
        local name = tostring(item.Name)
        if not isUnwanted(name) then
            if isSecondaryPet(name) then
                table.insert(secondaryPetsFound, cleanName(name))
            else
                table.insert(wantedPetsFound, cleanName(name))
            end
        end
    end
    
    -- Priority selection if mixed pets spawn initially (prefers secondary routing if it hits)
    if #secondaryPetsFound > 0 then
        local initialList = ""
        for _, name in pairs(secondaryPetsFound) do
            initialList = initialList .. "• " .. name .. "\n"
        end
        triggerAlertSpam({
            title = "IchiGoat (Secondary)",
            fieldName = "IchiGoat Found A Secondary List Pet",
            fieldValue = initialList
        }, SECONDARY_WEBHOOK)
    elseif #wantedPetsFound > 0 then
        local initialList = ""
        for _, name in pairs(wantedPetsFound) do
            initialList = initialList .. "• " .. name .. "\n"
        end
        triggerAlertSpam({
            title = "IchiGoat",
            fieldName = "IchiGoat Found A",
            fieldValue = initialList
        }, MAIN_WEBHOOK)
    else
        startHopping()
    end
    
    spawnsFolder.ChildAdded:Connect(function(newItem)
        task.wait(0.1)
        local name = tostring(newItem.Name)
        if not isUnwanted(name) then
            if isSecondaryPet(name) then
                triggerAlertSpam({
                    title = "✨ Rare Secondary Item Spawned!",
                    fieldName = "Pet Name",
                    fieldValue = "• " .. cleanName(name)
                }, SECONDARY_WEBHOOK)
            else
                triggerAlertSpam({
                    title = "✨ Rare Item Spawned!",
                    fieldName = "Pet Name",
                    fieldValue = "• " .. cleanName(name)
                }, MAIN_WEBHOOK)
            end
        end
    end)
    
    spawnsFolder.ChildRemoved:Connect(function()
        task.wait(0.5)
        if getWantedPetCount(spawnsFolder) == 0 then
            print("📉 All wanted pets are gone (bought or despawned). Leaving server...")
            startHopping()
        end
    end)
else
    warn("Path workspace.Map.WildPetSpawns could not be found.")
    startHopping()
end
