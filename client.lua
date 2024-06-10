local casinoCoords = vector3(945.08, 35.17, 71.83) -- Replace with the actual coordinates of the casino
local casinoRadius = 750.0 -- Radius around the coordinates to consider as inside the casino

local function IsPlayerInCasino(playerCoords)
    local distance = #(playerCoords - casinoCoords)
    return distance <= casinoRadius
end

local spawnOffset = vector3(0.0, 10.0, 0.0) -- Offset spawn location by 10 units 

local merryweatherNPCs = {
    's_m_y_blackops_01', -- Merryweather black ops
    's_m_y_blackops_02',
    's_m_y_blackops_03'
}

local merryweatherVehicles = {
    'crusader', -- Military jeep
    'mesa', -- Off-road vehicle used by Merryweather
    'sandking2' -- Attack helicopter (if you want aerial attacks)
}

local ambushWeapons = {
    'WEAPON_ASSAULTRIFLE',
    'WEAPON_CARBINERIFLE',
    'WEAPON_COMBATMG',
    -- Add more weapon models as needed
}

local spawnedNPCs = {}
local escapeDistance = 20000.0 -- Distance in meters to consider as an escape

-- Function to generate a random location within a radius around a given position
function GenerateRandomLocationAroundPosition(posX, posY, radius)
    local randomAngle = math.rad(math.random(0, 360)) -- Random angle in radians
    local randomRadius = math.random() * radius -- Random radius within the specified range
    local offsetX = randomRadius * math.cos(randomAngle)
    local offsetY = randomRadius * math.sin(randomAngle)
    return vector3(posX + offsetX, posY + offsetY, 0.0) -- Z-coordinate set to 0 for 2D position
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(math.random(300000, 600000)) -- Wait for a random time between 5 and 10 minutes

        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local spawnRadius = 200.0 -- Radius within which ambush can be triggered

     if not IsPlayerInCasino(playerCoords) then
        local spawnLocation = GenerateRandomLocationAroundPosition(playerCoords.x, playerCoords.y, spawnRadius)

        TriggerEvent('npc_ambush:spawnAmbush', spawnLocation)
        TriggerClientEvent('chatMessage', -1, '^1[AMBUSH]', {255, 0, 0}, 'An ambush has been triggered!')
         else
            print('Player is in the casino, skipping ambush.')
        end
    end
end)

RegisterNetEvent('npc_ambush:spawnAmbush')
AddEventHandler('npc_ambush:spawnAmbush', function(location)
    if not location then
        print('Failed to get ambush location!')
        return
    end

    print('Ambush triggered at location: ' .. json.encode(location))

    local spawnLocation = vector3(location.x + spawnOffset.x, location.y + spawnOffset.y, location.z + spawnOffset.z)

    local npcModel = merryweatherNPCs[math.random(#merryweatherNPCs)]
    local model = GetHashKey(npcModel)
    local vehicleModel = GetHashKey(merryweatherVehicles[math.random(#merryweatherVehicles)])
    local weapon = GetHashKey(ambushWeapons[math.random(#ambushWeapons)])

    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(100)
    end

    RequestModel(vehicleModel)
    while not HasModelLoaded(vehicleModel) do
        Citizen.Wait(100)
    end

    local vehicle = CreateVehicle(vehicleModel, spawnLocation, 0.0, true, true)
    if not DoesEntityExist(vehicle) then
        print('Failed to create vehicle!')
        return
    end

    -- Create the driver NPC
local driver = CreatePedInsideVehicle(vehicle, 4, model, -1, true, true)
if not DoesEntityExist(driver) then
    print('Failed to create driver!')
    DeleteVehicle(vehicle)
    return
end

-- Give weapon and set task for the driver
SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), GetHashKey('GANG_9')) -- Hostile behavior towards player
GiveWeaponToPed(driver, weapon, 255, false, true)
TaskCombatPed(driver, PlayerPedId(), 0, 16) -- Attack the player

-- Insert the driver NPC and vehicle into the spawnedNPCs table
table.insert(spawnedNPCs, {npc = driver, vehicle = vehicle})

-- Attempt to create the passenger NPC
local passengerSeatIndex = GetEmptySeat(vehicle)
print('Passenger seat index: ' .. passengerSeatIndex) -- Debug output
        
if passengerSeatIndex ~= -1 then
    print('Found empty passenger seat at index: ' .. passengerSeatIndex)
    local passenger = CreatePedInsideVehicle(vehicle, 4, model, passengerSeatIndex, true, true)
    if DoesEntityExist(passenger) then
        -- Give weapon and set task for the passenger
        SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), GetHashKey('GANG_9')) -- Hostile behavior towards player
        GiveWeaponToPed(passenger, weapon, 255, false, true)
        TaskCombatPed(passenger, PlayerPedId(), 0, 16) -- Attack the player
        
        -- Insert the passenger NPC and vehicle into the spawnedNPCs table
        table.insert(spawnedNPCs, {npc = passenger, vehicle = vehicle})
    else
        print('Failed to create passenger!')
    end
else
    print('No empty passenger seat available!')
end

    Citizen.CreateThread(function()
        while DoesEntityExist(driver) do
            Citizen.Wait(1000)
            local playerCoords = GetEntityCoords(playerPed)
            local npcCoords = GetEntityCoords(driver)
            local distance = #(playerCoords - npcCoords)

            if distance > escapeDistance then
                print('NPC escaped! Distance: ' .. distance) -- Print distance for debugging
                DeleteEntity(driver)
                DeleteVehicle(vehicle)
                break
            end
        end

        for i, entity in ipairs(spawnedNPCs) do
            if entity.npc == driver then
                table.remove(spawnedNPCs, i)
                break
            end
        end

        if #spawnedNPCs == 0 then
            print('All NPCs dead!') -- Print message for debugging
            TriggerServerEvent('npc_ambush:allNPCsDead')
        end
    end)
end)

RegisterNetEvent('npc_ambush:adminTriggerAmbush')
AddEventHandler('npc_ambush:adminTriggerAmbush', function()
    print('Admin triggered ambush!') -- Print message for debugging
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    TriggerServerEvent('npc_ambush:requestAmbush', playerCoords)
end)
