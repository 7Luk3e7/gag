local webhook_url = "https://discord.com/api/webhooks/1523914403907371099/48Y1f7Mh3yPWLr6T_VpGrvZpJ9PWTjhNf6dFrixzQ1ZWJbMd1rtkqBmsPX-iEzIsymKW"

-- CONFIGURATION
local LOAD_DELAY = 7 -- Time (in seconds) allowed for game files and pets to load into the server.

-- Universal request resolver for mobile/PC executors
local requestFunction = request or http_request or (syn and syn.request) or HttpPost
local Http = game:GetService("HttpService")
local TPS = game:GetService("TeleportService")
local Api = "https://games.roblox.com/v1/games/"

-- Global tracking variable to manage the repeating notification stream
local alertLoopActive = false
local alertMessage = ""

local function sendToDiscord(messageText)
    if not requestFunction then return end

    -- Automatically routing through a proxy to bypass Discord's direct API blocks on executors
    local cleanedUrl = webhook_url:gsub("discord.com", "webhook.lewisakura.moe"):gsub("discordapp.com", "webhook.lewisakura.moe")

    pcall(function()
        requestFunction({
            Url = cleanedUrl,
            Method = "POST",
            Headers = {["content-type"] = "application/json"},
            Body = Http:JSONEncode({
                ["content"] = messageText
            })
        })
    end)
end

-- Helper check function to find unwanted pets
local function isUnwanted(petName)
    local name = tostring(petName):lower()
    if string.find(name, "bunny") or string.find(name, "owl") or string.find(name, "butterfly") or string.find(name, "monkey") or string.find(name, "baldeagle") or string.find(name, "bear") or string.find(name, "bee") or string.find(name, "robin") or string.find(name, "deer") or string.find(name, "turtle") or string.find(name, "frog") then
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
        local success, Raw = pcall(function()
            return game:HttpGet(_servers .. ((cursor and "&cursor="..cursor) or ""))
        end)
        if success and Raw then
            return Http:JSONDecode(Raw)
        end
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
                TPS:TeleportToPlaceInstance(_place, chosenServer.id, game.Players.LocalPlayer)
            end)
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
local function triggerAlertSpam(initialText)
    alertMessage = initialText
    if alertLoopActive then return end
    alertLoopActive = true

    task.spawn(function()
        while alertLoopActive do
            sendToDiscord(alertMessage)
            task.wait(2)
        end
    end)
end

-- Main Check & Notification Sequence
local map = workspace:WaitForChild("Map", 10)
local spawnsFolder = map and map:WaitForChild("WildPetSpawns", 10)

task.wait(LOAD_DELAY)

if spawnsFolder then
    -- Clickable HTTPS redirect link (Discord linkifies this; it forwards to roblox:// automatically)
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
        local initialList = " **Pet found**\n"
        for _, name in pairs(wantedPetsFound) do
            initialList = initialList .. "• " .. name .. "\n"
        end
        initialList = initialList .. "\n" .. joinLink

        triggerAlertSpam(initialList)
    else
        startHopping()
    end

    spawnsFolder.ChildAdded:Connect(function(newItem)
        task.wait(0.1)
        local name = tostring(newItem.Name)
        if not isUnwanted(name) then
            local newSpawnAlert = "✨ **New rare item spawned:** " .. name .. "\n\n" .. joinLink
            triggerAlertSpam(newSpawnAlert)
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
