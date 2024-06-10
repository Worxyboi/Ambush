RegisterServerEvent('npc_ambush:requestAmbush')
AddEventHandler('npc_ambush:requestAmbush', function(playerId)
    local source = source
    local ambushLocation = ambushLocations[math.random(#ambushLocations)]
    local ambushNPC = ambushNPCs[math.random(#ambushNPCs)]

    TriggerClientEvent('npc_ambush:spawnAmbush', source, ambushLocation, ambushNPC)
end)

RegisterServerEvent('npc_ambush:allNPCsDead')
AddEventHandler('npc_ambush:allNPCsDead', function()
    local source = source
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if xPlayer then
        TriggerEvent('qb-phone:server:sendNewMail', {
            sender = "Ambush System",
            subject = "Ambush Cleared",
            message = "You have successfully eliminated all ambushers. Well done!",
            button = {} -- You can add a button here if needed
        })
    end
end)
