local RSGCore = exports['rsg-core']:GetCoreObject()

-- Create useable chicken item
RSGCore.Functions.CreateUseableItem("sanctuary", function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    
    TriggerClientEvent('rsg-chickens:client:openChickenMenu', source)
    Player.Functions.RemoveItem("sanctuary", 0)
end)

-- Return chicken item when picked up
RegisterNetEvent('rsg-chickens:server:returnChickenItem', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    Player.Functions.AddItem("sanctuary", 0)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items["sanctuary"], "add")
end)

RSGCore.Functions.CreateCallback('rsg-chickens:server:getCitizenId', function(source, cb, targetServerId)
    local targetServerId = targetServerId or source
    local Player = RSGCore.Functions.GetPlayer(targetServerId)
    
    if Player then
        -- Get citizen ID from player data
        local citizenId = Player.PlayerData.citizenid
        cb(citizenId)
    else
        cb(nil)
    end
end)

