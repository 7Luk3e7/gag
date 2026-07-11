local webhook_url = "https://discord.com/api/webhooks/1399958078752821338/PkxHwpmZafDHECLccO8JdKtsLveDsDwV_1y6d3UHWcfpPAHFChOsTe9bE7WQAAkP_XUs" -- CONFIGURATION
local LOAD_DELAY = 3 -- Time (in seconds) allowed for game files and pets to load into the server.

-- Universal request resolver for mobile/PC executors
local requestFunction = request or http_request or (syn and syn.request) or HttpPost
local Http = game:GetService("HttpService")
local TPS = game:GetService("TeleportService")
local Api = "https://games.roblox.com/v1/games/"

-- Global tracking variable to manage the repeating notification stream
local alertLoopActive = false
local alertEmbedData = {}

-- Helper function to format the pet's name to drop "WildPet_" and only include the name and the start of the ID
local function cleanName(fullName)
    local str = tostring(fullName)
    -- Extracts the prefix (which contains WildPet_ and the pet type), and the first part of the UUID hyphen split
    local base, firstIdSegment = string.match(str, "^([%w_]+_)[%w_]+_([%w]+)%-")
    if base and firstIdSegment then
        -- Removes "WildPet_" from the base string
        local cleanedBase = string.gsub(base, "^WildPet_", "")
        -- Returns the name along with the first 2 characters of that ID segment (e.g. GoldenDragonfly_6d)
        return cleanedBase .. string.sub(firstIdSegment, 1, 2)
    end
    -- Fallback safety to strip out WildPet_ if pattern matching structure differs slightly
    return string.gsub(str, "^WildPet_", "")
end

-- Modified to bundle the click to join option directly inside the embed description
local function sendToDiscord(embedData)
    if not requestFunction then return end
    
    local cleanedUrl = webhook_url:gsub("discord.com", "webhook.lewisakura.moe"):gsub("discordapp.com", "webhook.lewisakura.moe")
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
            pcall(function() TPS:TeleportToPlaceInstance(_place, chosenServer.id, game.Players.LocalPlayer) end)
        end
        task.wait(2)
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

-- Activates a parallel thread to spam the webhook link every 2 seconds
local function triggerAlertSpam(embedStructure)
    alertEmbedData = embedStructure
    if alertLoopActive then return end
    alertLoopActive = true
    task.spawn(function()
        while alertLoopActive do
            sendToDiscord(alertEmbedData)
            task.wait(2)
        end
    end)
end

-- Main Check & Notification Sequence
local map = workspace:WaitForChild("Map", 10)
local spawnsFolder = map and map:WaitForChild("WildPetSpawns", 10)

task.wait(LOAD_DELAY)

if spawnsFolder then
    local initialItems = spawnsFolder:GetChildren()
    local wantedPetsFound = {}
    
    for _, item in pairs(initialItems) do
        local name = tostring(item.Name)
        if not isUnwanted(name) then
            table.insert(wantedPetsFound, cleanName(name))
        end
    end
    
    if #wantedPetsFound > 0 then
        local initialList = ""
        for _, name in pairs(wantedPetsFound) do
            initialList = initialList .. "• " .. name .. "\n"
        end
        
        triggerAlertSpam({
            title = "IchiGoat",
            fieldName = "IchiGoat Found A",
            fieldValue = initialList
        })
    else
        startHopping()
    end
    
    spawnsFolder.ChildAdded:Connect(function(newItem)
        task.wait(0.1)
        local name = tostring(newItem.Name)
        if not isUnwanted(name) then
            triggerAlertSpam({
                title = "✨ Rare Item Spawned!",
                fieldName = "Pet Name",
                fieldValue = "• " .. cleanName(name)
            })
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
