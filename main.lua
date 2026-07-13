local normal_webhook_url = "https://discord.com/api/webhooks/1523914403907371099/48Y1f7Mh3yPWLr6T_VpGrvZpJ9PWTjhNf6dFrixzQ1ZWJbMd1rtkqBmsPX-iEzIsymKW"
local special_webhook_url = "https://discord.com/api/webhooks/1526046487778430977/Kd-Eq0sh0_-NB7ceEILYTE85hyjcBPNHyrzAFHKYyzsucR93Q7CDGqWLPH7zpm6IB-c1"

-- CONFIGURATION
local LOAD_DELAY = 3 -- Time (in seconds) allowed for game files and pets to load into the server.

-- Add the names of special pets here (lowercase letters only)
local SPECIAL_PETS = {
    "bunny",
    "fih",
    "fih"
}

-- Universal request resolver for mobile/PC executors
local requestFunction = request or http_request or (syn and syn.request) or HttpPost
local Http = game:GetService("HttpService")
local TPS = game:GetService("TeleportService")
local Api = "https://games.roblox.com/v1/games/"

-- Global tracking variables to manage the repeating notification streams
local normalAlertLoopActive = false
local specialAlertLoopActive = false
local alertEmbedData = {}
local specialEmbedData = {}

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

-- Helper check function to find if a pet is marked as special
local function isSpecial(petName)
    local name = tostring(petName):lower()
    for _, specialName in pairs(SPECIAL_PETS) do
        if string.find(name, specialName) then
            return true
        end
    end
    return false
end

-- Universal Discord post request runner
local function postToWebhook(url, embedData)
    if not requestFunction then return end
    local cleanedUrl = url:gsub("discord.com", "webhook.lewisakura.moe"):gsub("discordapp.com", "webhook.lewisakura.moe")
    local rawJoinLink = "https://7luk3e7.github.io/roblox/?placeId=" .. game.PlaceId .. "&jobId=" .. tostring(game.JobId)
    local payload = {
        ["embeds"] = {
            {
                ["title"] = embedData.title or "Server Notification",
                ["type"] = "rich",
                ["description"] = "[**Click To Join Server**](" .. rawJoinLink .. ")",
                ["color"] = embedData.color or 5763719,
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

-- Dedicated loop execution logic for normal alerts
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

-- Dedicated loop execution logic for special alerts (Takes top priority)
local function triggerSpecialAlertSpam(embedStructure)
    specialEmbedData = embedStructure
    normalAlertLoopActive = false -- Kill normal alerts immediately if a special pet is present
    if specialAlertLoopActive then return end
    specialAlertLoopActive = true
    task.spawn(function()
        while specialAlertLoopActive do
            postToWebhook(special_webhook_url, specialEmbedData)
            task.wait(2)
        end
    end)
end

-- Helper check function to find unwanted pets
local function isUnwanted(petName)
    local name = tostring(petName):lower()
    if string.find(name, "bunny") or string.find(name, "owl") or string.find(name, "bear") or string.find(name, "robin") or string.find(name, "baldeagle") or string.find(name, "monkey") or string.find(name, "bee") or string.find(name, "fih") or string.find(name, "deer") or string.find(name, "turtle") or string.find(name, "frog") then
        return true
    end
    return false
end

-- Reusable Server Hopping Function (Tries every 2 seconds until successful)
local hoppingStarted = false
local function startHopping()
    if hoppingStarted then return end
    hoppingStarted = true
    normalAlertLoopActive = false
    specialAlertLoopActive = false
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
            pcall(function() TPS:TeleportToPlaceInstance(_place, chosenServer.id, game.Players.LocalPlayer) end)
        end
        task.wait(2)
    end
end

-- Helper function to count how many valid target pets remain
local function getWantedPetCount(folder)
    if not folder then return 0 end
    local count = 0
    for _, item in pairs(folder:GetChildren()) do
        local name = item.Name
        if isSpecial(name) or not isUnwanted(name) then
            count = count + 1
        end
    end
    return count end

-- Main Check & Notification Sequence
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
    
    -- Processing rules execution
    if #specialPetsFound > 0 then
        local specialList = ""
        for _, name in pairs(specialPetsFound) do
            specialList = specialList .. "• " .. name .. "\n"
        end
        triggerSpecialAlertSpam({
            title = "⭐ SPECIAL PET FOUND! ⭐",
            fieldName = "Target Special Pet Identified",
            fieldValue = specialList,
            color = 15844367 -- Gold Color (#F1C40F)
        })
    elseif #wantedPetsFound > 0 then
        local initialList = ""
        for _, name in pairs(wantedPetsFound) do
            initialList = initialList .. "• " .. name .. "\n"
        end
        triggerAlertSpam({
            title = "IchiGoat",
            fieldName = "IchiGoat Found A",
            fieldValue = initialList,
            color = 5763719
        })
    else
        startHopping()
    end
    
    -- Event listening for live spawns
    spawnsFolder.ChildAdded:Connect(function(newItem)
        task.wait(0.1)
        local name = tostring(newItem.Name)
        if isSpecial(name) then
            triggerSpecialAlertSpam({
                title = "⭐ SPECIAL PET SPAWNED! ⭐",
                fieldName = "Pet Name",
                fieldValue = "• " .. cleanName(name),
                color = 15844367
            })
        elseif not isUnwanted(name) and not specialAlertLoopActive then
            triggerNormalAlertSpam({
                title = "✨ Rare Item Spawned!",
                fieldName = "Pet Name",
                fieldValue = "• " .. cleanName(name),
                color = 5763719
            })
        end
    end)
    
    spawnsFolder.ChildRemoved:Connect(function()
        task.wait(0.5)
        if getWantedPetCount(spawnsFolder) == 0 then
            print("📉 All wanted/special pets are gone. Leaving server...")
            startHopping()
        end
    end)
else
    warn("Path workspace.Map.WildPetSpawns could not be found.")
    startHopping()
end
