local casinoCoords = vector3(925.0, 47.0, 80.0) -- Replace with the actual coordinates of the casino
local casinoRadius = 50.0 -- Radius around the coordinates to consider as inside the casino

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
    'sandking2' 
}

local ambushWeapons = {
    'WEAPON_ASSAULTRIFLE',
    'WEAPON_CARBINERIFLE',
    'WEAPON_COMBATMG',
    -- Add more weapon models as needed
}

local spawnedNPCs = {}
local escapeDistance = 1500.0 -- Distance in meters to consider as an escape

local function GenerateRandomLocationAroundPosition(x, y, radius)
    local angle = math.random() * 2 * math.pi
    local offsetX = math.cos(angle) * radius
    local offsetY = math.sin(angle) * radius
    return vector3(x + offsetX, y + offsetY, 0.0) -- Adjust Z coordinate as needed
end

local function CleanupAmbush()
    for _, data in ipairs(spawnedNPCs) do
        if DoesEntityExist(data.npc) then
            DeleteEntity(data.npc)
        end
        if DoesEntityExist(data.vehicle) then
            DeleteVehicle(data.vehicle)
        end
    end
    spawnedNPCs = {}
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(math.random(300000, 600000)) -- Wait for a random time between 5 and 10 minutes
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        if not IsPlayerInCasino(playerCoords) then
            local spawnLocation = GenerateRandomLocationAroundPosition(playerCoords.x, playerCoords.y, 200.0)
            TriggerEvent('npc_ambush:spawnAmbush', spawnLocation)
        else
            print('Player is in the casino, skipping ambush.')
        end

        Citizen.Wait(180000) -- Wait for 3 minutes before cleaning up
        CleanupAmbush()
    end
end)

RegisterNetEvent('npc_ambush:spawnAmbush')
AddEventHandler('npc_ambush:spawnAmbush', function(location)
    if not location then
        print('Failed to get ambush location!')
        return
    end

    print('Ambush triggered at location: ' .. json.encode(location))

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

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

    -- Create the relationship group
    local relationshipGroup = 'MERRYWEATHER'
    AddRelationshipGroup(relationshipGroup)

    -- Set relationship within group to friendly and towards player to hostile
    SetRelationshipBetweenGroups(0, GetHashKey(relationshipGroup), GetHashKey(relationshipGroup))
    SetRelationshipBetweenGroups(5, GetHashKey(relationshipGroup), GetHashKey('PLAYER'))
    SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), GetHashKey(relationshipGroup))

    local driver = CreatePedInsideVehicle(vehicle, 4, model, -1, true, true)
    if not DoesEntityExist(driver) then
        print('Failed to create driver!')
        DeleteVehicle(vehicle)
        return
    end
    SetPedRelationshipGroupHash(driver, GetHashKey(relationshipGroup))
    GiveWeaponToPed(driver, weapon, 255, false, true)
    TaskCombatPed(driver, PlayerPedId(), 0, 16) -- Attack the player    
    table.insert(spawnedNPCs, {npc = driver, vehicle = vehicle})
        
    -- Attempt to create the passenger NPC
    for i = 0, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if IsVehicleSeatFree(vehicle, i) then
            local passenger = CreatePedInsideVehicle(vehicle, 4, model, i, true, true)
            if DoesEntityExist(passenger) then
                SetPedRelationshipGroupHash(passenger, GetHashKey(relationshipGroup))
                -- Give weapon and set task for the passenger
                GiveWeaponToPed(passenger, weapon, 255, false, true)
                TaskCombatPed(passenger, PlayerPedId(), 0, 16) -- Attack the player
                table.insert(spawnedNPCs, {npc = passenger, vehicle = vehicle})
            else
                print('Failed to create passenger!')
            end
        end
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

        -- Check if all NPCs are dead and then delete the vehicle
        local allDead = true
        for _, npc in ipairs(spawnedNPCs) do
            if DoesEntityExist(npc.npc) then
                allDead = false
                break
            end
        end

        if allDead then
            DeleteVehicle(vehicle)
        end
    end)
end)
