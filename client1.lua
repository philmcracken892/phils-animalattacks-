
local RSGCore = exports['rsg-core']:GetCoreObject()
local STRESS_RELIEF_AMOUNT = 100
local CHECK_RADIUS = 5.0
local CHICKEN_TYPES = {
    {
        label = "lion",
        model = `a_c_lionmangy_01`,
        health = 150,
        speed = 1.2
    },
    {
        label = "shepherd",
        model = `A_C_DogAustralianSheperd_01`, 
        health = 200,
        speed = 1.5
    },
	{
        label = "husky",
        model = `a_c_doghusky_01`, 
        health = 200,
        speed = 1.5
    },
	{
        label = "Prize Bear",
        model = `A_C_Bear_01`, 
        health = 200,
        speed = 1.5
    },
	{
        label = "Prize Aligator",
        model = `A_C_Alligator_01`, 
        health = 200,
        speed = 1.5
    },
	{
        label = "lion dog",
        model = `a_c_doglion_01`, 
        health = 200,
        speed = 1.5
    },
	{
        label = "Prize cougar",
        model = `A_C_Cougar_01`, 
        health = 200,
        speed = 1.5
    }
}


local spawnedChickens = {}
local chickenCounter = 0

function FindAndAttackNearbyTarget(animal)
    local coords = GetEntityCoords(animal)
    local nearbyPeds = GetGamePool('CPed')

    for _, ped in ipairs(nearbyPeds) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) and ped ~= animal then
            local dist = #(coords - GetEntityCoords(ped))
            if dist < 20.0 and not IsPedDeadOrDying(ped, true) then
                TaskCombatPed(animal, ped, 0, 16)
                break
            end
        end
    end
end
local function MakeRoosterFollow(rooster)
    if not DoesEntityExist(rooster) then return end
    
    SetEntityInvincible(rooster, false)
    local playerPed = PlayerPedId()
    local heading = GetEntityHeading(playerPed)
    
    
    local followOffset = vector3(
        3.0 * math.sin(math.rad(heading + math.random(-45, 45))),
        3.0 * math.cos(math.rad(heading + math.random(-45, 45))),
        0.0
    )
    
    
    TaskFollowToOffsetOfEntity(rooster, playerPed, followOffset.x, followOffset.y, followOffset.z, 1.0, -1, 2.0, true)
    DecorSetBool(rooster, "IsFollowing", true)
    DecorSetBool(rooster, "IsStaying", false)
end

local function MakeRoosterStay(rooster)
    if not DoesEntityExist(rooster) then return end
    
    ClearPedTasks(rooster)
    TaskStandStill(rooster, -1)
    SetEntityInvincible(rooster, true)
    DecorSetBool(rooster, "IsStaying", true)
    DecorSetBool(rooster, "IsFollowing", false)
end

local function MakeRoosterDefault(rooster)
    if not DoesEntityExist(rooster) then return end
    
    SetEntityInvincible(rooster, false)
    ClearPedTasks(rooster)
    DecorSetBool(rooster, "IsStaying", false)
    DecorSetBool(rooster, "IsFollowing", false)
    
    
    TaskWanderStandard(rooster, 10.0, 10)
end


local function SetupRoosterBehavior(rooster)
    if not DoesEntityExist(rooster) then return end

    local playerPed = PlayerPedId()
    local playerGroupHash = GetHashKey("OWNER_" .. tostring(GetPlayerServerId(PlayerId())))

    -- Register group and set relationships
    AddRelationshipGroup("OWNER_" .. tostring(GetPlayerServerId(PlayerId())))

    -- Owner group is friendly to PLAYER group
    SetRelationshipBetweenGroups(1, playerGroupHash, `PLAYER`)
    SetRelationshipBetweenGroups(1, `PLAYER`, playerGroupHash)

    -- Owner group hates other groups (e.g., ambient ped types)
    SetRelationshipBetweenGroups(5, playerGroupHash, `CIVMALE`)
    SetRelationshipBetweenGroups(5, playerGroupHash, `CIVFEMALE`)
    SetRelationshipBetweenGroups(5, playerGroupHash, `AMBIENT_GANG_LOWER`)
    SetRelationshipBetweenGroups(5, playerGroupHash, `REL_NO_RELATIONSHIP`)
    SetRelationshipBetweenGroups(5, playerGroupHash, `REL_GANG_DUTCHS`)
    SetRelationshipBetweenGroups(5, playerGroupHash, `REL_GANG_ODRISCOLLS`)
    SetRelationshipBetweenGroups(5, playerGroupHash, `REL_GANG_SKINNER_BROTHERS`)
    SetRelationshipBetweenGroups(5, playerGroupHash, `REL_GANG_LEMOYNE_RAIDERS`)

    -- Apply group to the animal
    SetPedRelationshipGroupHash(rooster, playerGroupHash)

    -- Combat setup
    SetPedAsCop(rooster, false)
    SetBlockingOfNonTemporaryEvents(rooster, true)
    SetPedFleeAttributes(rooster, 0, false)
    SetPedCombatAttributes(rooster, 5, true)   -- BF_CanFightWithoutWeapon
    SetPedCombatAttributes(rooster, 46, true)  -- BF_AlwaysFight
    SetPedCombatAttributes(rooster, 0, true)   -- Aggressive
    SetPedCombatRange(rooster, 2)              -- Combat range: Close
    SetPedCombatMovement(rooster, 2)           -- Chase movement

    SetPedCanRagdoll(rooster, false)
    SetEntityInvincible(rooster, false)

    DecorSetBool(rooster, "IsFollowing", true)
    DecorSetBool(rooster, "IsStaying", false)

    MakeRoosterFollow(rooster)
end



local function GetChickenTypeByModel(model)
    for _, chicken in ipairs(CHICKEN_TYPES) do
        if chicken.model == model then
            return chicken
        end
    end
    return nil
end

local function IsPlayerOwner(chickenEntity)
    local playerServerId = GetPlayerServerId(PlayerId())
    if spawnedChickens[playerServerId] then
        for _, chickenData in pairs(spawnedChickens[playerServerId]) do
            if chickenData.entity == chickenEntity then
                return true
            end
        end
    end
    return false
end

local function GetPlayerChickenCount()
    local playerServerId = GetPlayerServerId(PlayerId())
    if spawnedChickens[playerServerId] then
        local count = 0
        for _ in pairs(spawnedChickens[playerServerId]) do
            count = count + 1
        end
        return count
    end
    return 0
end

-- Menu System
local function ShowChickenMenu()
    local chickenOptions = {}
    
    for i, chicken in ipairs(CHICKEN_TYPES) do
        table.insert(chickenOptions, {
            title = chicken.label,
            description = "Spawn a " .. chicken.label .. " (Health: " .. chicken.health .. ") - Will follow you!",
            icon = 'fas fa-egg',
            onSelect = function()
                TriggerEvent('rsg-chickens:client:spawnChicken', i)
            end
        })
    end

    
    table.insert(chickenOptions, {
        title = "Call All Animals",
        description = "Call all your animals to follow you",
        icon = 'fas fa-whistle',
        onSelect = function()
            TriggerEvent('rsg-chickens:client:callChickens')
        end
    })

   
    table.insert(chickenOptions, {
        title = "Make All Stay",
        description = "Make all your chickens stay in place",
        icon = 'fas fa-stop',
        onSelect = function()
            TriggerEvent('rsg-chickens:client:makeAllStay')
        end
    })

    lib.registerContext({
        id = 'chicken_selection_menu',
        title = 'Chicken Management',
        options = chickenOptions
    })
    
    lib.showContext('chicken_selection_menu')
end


local function RegisterChickenTargeting()
    local models = {}
    for _, chicken in ipairs(CHICKEN_TYPES) do
        table.insert(models, chicken.model)
    end

    exports['ox_target']:addModel(models, {
        {
            name = 'toggle_follow',
            event = 'rsg-chickens:client:toggleFollow',
            icon = "fas fa-walking",
            label = "Toggle Follow/Stay",
            distance = 3.0,
            canInteract = function(entity)
                return IsPlayerOwner(entity)
            end
        },
        {
            name = 'pet',
            event = 'rsg-chickens:client:petChicken',
            icon = "fas fa-hand-paper",
            label = "Pet",
            distance = 2.0,
            canInteract = function(entity)
                return true
            end
        },
        {
            name = 'pickup',
            event = 'rsg-chickens:client:pickupChicken',
            icon = "fas fa-hand",
            label = "Pick Up",
            distance = 2.0,
            canInteract = function(entity)
                return IsPlayerOwner(entity)
            end
        }
    })
end

CreateThread(function()
    exports['ox_target']:addGlobalPed({
        {
            name = 'attack_with_animal',
            icon = 'fas fa-dog',
            label = 'Command Animal to Attack',
            distance = 3.0,
            canInteract = function(entity)
                local playerServerId = GetPlayerServerId(PlayerId())
                local hasAnimal = spawnedChickens[playerServerId] and next(spawnedChickens[playerServerId]) ~= nil
                return hasAnimal and IsPedHuman(entity) and not IsPedAPlayer(entity)
            end,
            onSelect = function(data)
                local target = data.entity
                TriggerEvent('rsg-chickens:client:animalAttackTarget', target)
            end
        }
    })
end)



RegisterNetEvent('rsg-chickens:client:animalAttackTarget', function(target)
    if not DoesEntityExist(target) or IsEntityDead(target) then
        lib.notify({ title = 'Invalid Target', description = 'Target is invalid or dead.', type = 'error' })
        return
    end

    local playerServerId = GetPlayerServerId(PlayerId())
    local playerAnimals = spawnedChickens[playerServerId]

    if not playerAnimals then
        lib.notify({ title = 'No Animals', description = 'You don’t have any animals spawned.', type = 'error' })
        return
    end

    local closestAnimal = nil
    local closestDist = 9999.0
    local playerCoords = GetEntityCoords(PlayerPedId())

    for _, animal in pairs(playerAnimals) do
        if DoesEntityExist(animal.entity) then
            local dist = #(GetEntityCoords(animal.entity) - playerCoords)
            if dist < closestDist then
                closestDist = dist
                closestAnimal = animal.entity
            end
        end
    end

    if not closestAnimal then
        lib.notify({ title = 'No Animal Found', description = 'Could not find your animal.', type = 'error' })
        return
    end

    -- Clear existing tasks to avoid chasing past targets
    ClearPedTasksImmediately(closestAnimal)

    -- Combat attribute cleanup: Disable other combat options
    SetPedCombatAttributes(closestAnimal, 16, false) -- BF_AlwaysFlee
    SetPedCombatAttributes(closestAnimal, 46, true)  -- BF_AlwaysFight
    SetPedCombatAttributes(closestAnimal, 5, false)  -- BF_CanInvestigate
    SetPedCombatAttributes(closestAnimal, 0, true)   -- Aggressive
    SetPedCombatAttributes(closestAnimal, 1, false)  -- Disable fleeing from player

    -- Force attack on that one ped, don't pursue others
    TaskCombatPed(closestAnimal, target, 0, 16) -- 16 = use melee

    -- Monitor the target: stop attacking when dead
    CreateThread(function()
        while DoesEntityExist(target) and not IsEntityDead(target) do
            Wait(500)
        end

        -- Target is dead, stop animal
        if DoesEntityExist(closestAnimal) then
            ClearPedTasksImmediately(closestAnimal)
            MakeRoosterFollow(closestAnimal)
            lib.notify({
                title = 'Target Eliminated',
                description = 'Your animal has returned to you.',
                type = 'success'
            })
        end
    end)

    lib.notify({
        title = 'Attack Command',
        description = 'Your animal is attacking the target!',
        type = 'success'
    })
end)


RegisterNetEvent('rsg-chickens:client:spawnChicken')
AddEventHandler('rsg-chickens:client:spawnChicken', function(chickenIndex)
    local playerServerId = GetPlayerServerId(PlayerId())
    local currentCount = GetPlayerChickenCount()
    
    
    if currentCount >= Config.MaxChickensPerPlayer then
        
        if RSGCore then
            lib.notify({
                title = 'Chicken Limit',
                description = 'You can only have 3  at a time.',
                type = 'error'
            })
        else
            lib.notify({
                title = 'Chicken Limit',
                description = 'You can only have 3  at a time.',
                type = 'error'
            })
        end
        return
    end

    local chickenData = CHICKEN_TYPES[chickenIndex]
    if not chickenData then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local forward = GetEntityForwardVector(ped)
    
   
    local offsetDistance = math.random(2, 4)
    local sideOffset = math.random(-2, 2)
    local x = coords.x + forward.x * offsetDistance + sideOffset
    local y = coords.y + forward.y * offsetDistance + sideOffset
    local z = coords.z

    
    local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z + 1.0, false)
    if foundGround then
        z = groundZ
    end

    
    RequestModel(chickenData.model)
    while not HasModelLoaded(chickenData.model) do
        Wait(100)
    end

    
    local wasInventoryBusy = false
    if LocalPlayer.state then
        wasInventoryBusy = LocalPlayer.state.inv_busy or false
        LocalPlayer.state:set('inv_busy', true, true)
    end
    
    
    TaskStartScenarioInPlace(ped, GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), 2000, true, false, false, false)
    
    Wait(5000) -- Wait for animation

   
    local chickenPed = CreatePed(chickenData.model, x, y, z, heading, true, false, false, false)
    
    
    ClearPedTasks(ped)
    ClearPedTasksImmediately(ped)
    
    
    if LocalPlayer.state then
        LocalPlayer.state:set('inv_busy', wasInventoryBusy, true)
    end
    
    
    if chickenPed and DoesEntityExist(chickenPed) then
        Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1749618580, chickenPed)
        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, chickenPed, 0, false)
        SetupRoosterBehavior(chickenPed)
        
        SetEntityHealth(chickenPed, chickenData.health)
        SetEntityMaxHealth(chickenPed, chickenData.health)
        
        
        chickenCounter = chickenCounter + 1
        if not spawnedChickens[playerServerId] then
            spawnedChickens[playerServerId] = {}
        end
        
        spawnedChickens[playerServerId][chickenCounter] = {
            entity = chickenPed,
            model = chickenData.model,
            type = chickenData.label,
            health = chickenData.health,
            spawnTime = GetGameTimer(),
            id = chickenCounter
        }
        
        
        if RSGCore then
            RSGCore.Functions.Notify('Your ' .. chickenData.label .. ' is now following you!', 'success')
        else
            lib.notify({
                title = 'Spawned',
                description = 'Your ' .. chickenData.label .. ' is now following you!',
                type = 'success'
            })
        end
    else
        
        ClearPedTasks(ped)
        ClearPedTasksImmediately(ped)
        if LocalPlayer.state then
            LocalPlayer.state:set('inv_busy', wasInventoryBusy, true)
        end
    end
    
    SetModelAsNoLongerNeeded(chickenData.model)
end)


RegisterNetEvent('rsg-chickens:client:toggleFollow', function(data)
    local rooster = data.entity
    if not DoesEntityExist(rooster) then return end

    local isStaying = DecorGetBool(rooster, "IsStaying")
    local isFollowing = DecorGetBool(rooster, "IsFollowing")
    
    if isStaying then
        MakeRoosterFollow(rooster)
        lib.notify({
            title = "Following",
            description = "Your animal is now following you.",
            type = 'success'
        })
    elseif isFollowing then
        MakeRoosterStay(rooster)
        lib.notify({
            title = "Staying",
            description = "Your animal will stay here.",
            type = 'success'
        })
    else
        MakeRoosterFollow(rooster)
        lib.notify({
            title = "Following",
            description = "Your animal is now following you.",
            type = 'success'
        })
    end
end)




RegisterNetEvent('rsg-chickens:client:petChicken', function(data)
    local chickenEntity = data.entity
    local ped = PlayerPedId()
    
    TaskTurnPedToFaceEntity(ped, chickenEntity, 2000)
    Wait(1000)
    
    TaskStartScenarioInPlace(ped, GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), 3000, true, false, false, false)
    
   
    if DoesEntityExist(chickenEntity) then
        SetPedMoveRateOverride(chickenEntity, 0.5) 
        CreateThread(function()
            Wait(3000)
            if DoesEntityExist(chickenEntity) then
                SetPedMoveRateOverride(chickenEntity, 1.0) 
            end
        end)
    end
	
	TriggerServerEvent('hud:server:RelieveStress', STRESS_RELIEF_AMOUNT)
    
    lib.notify({
        title = 'Petted',
        description = 'It seems happy!',
        type = 'success'
    })
end)


RegisterNetEvent('rsg-chickens:client:pickupChicken', function(data)
    local chickenEntity = data.entity
    
    if not IsPlayerOwner(chickenEntity) then
        lib.notify({
            title = "Not Your animal",
            description = "This isn't your animal to pick up.",
            type = 'error'
        })
        return
    end

    local ped = PlayerPedId()
    
    
    local wasInventoryBusy = false
    if LocalPlayer.state then
        wasInventoryBusy = LocalPlayer.state.inv_busy or false
        LocalPlayer.state:set('inv_busy', true, true)
    end
    
    TaskStartScenarioInPlace(ped, GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), 2000, true, false, false, false)
    Wait(2000)

    
    ClearPedTasks(ped)
    ClearPedTasksImmediately(ped)
    
    if LocalPlayer.state then
        LocalPlayer.state:set('inv_busy', wasInventoryBusy, true)
    end

   
    local playerServerId = GetPlayerServerId(PlayerId())
    if spawnedChickens[playerServerId] then
        for id, chickenData in pairs(spawnedChickens[playerServerId]) do
            if chickenData.entity == chickenEntity then
                DeletePed(chickenEntity)
                spawnedChickens[playerServerId][id] = nil
                TriggerServerEvent('rsg-chickens:server:returnChickenItem')
                break
            end
        end
    end

    lib.notify({
        title = ' Picked Up',
        description = 'You have retrieved your animal.',
        type = 'success'
    })
end)


RegisterNetEvent('rsg-chickens:client:callChickens', function()
    local playerServerId = GetPlayerServerId(PlayerId())
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    
    if not spawnedChickens[playerServerId] then
        lib.notify({
            title = "No Animals",
            description = "You don't have any  spawned.",
            type = 'error'
        })
        return
    end

    local chickenCount = 0
    for id, chickenData in pairs(spawnedChickens[playerServerId]) do
        if DoesEntityExist(chickenData.entity) then
            local chickenCoords = GetEntityCoords(chickenData.entity)
            local distance = #(playerCoords - chickenCoords)
            
            if distance < 50.0 then -- Only call nearby chickens
                -- Clear current tasks and make them follow
                ClearPedTasks(chickenData.entity)
                MakeRoosterFollow(chickenData.entity)
                chickenCount = chickenCount + 1
            end
        end
    end
    
    if chickenCount > 0 then
        lib.notify({
            title = 'Animals Called',
            description = 'Called ' .. chickenCount .. ' Animals to follow you.',
            type = 'success'
        })
    else
        lib.notify({
            title = 'No animals Nearby',
            description = 'No animals are close enough to call.',
            type = 'error'
        })
    end
end)

-- Make All Chickens Stay
RegisterNetEvent('rsg-chickens:client:makeAllStay', function()
    local playerServerId = GetPlayerServerId(PlayerId())
    
    if not spawnedChickens[playerServerId] then
        lib.notify({
            title = "No animals",
            description = "You don't have any animals spawned.",
            type = 'error'
        })
        return
    end

    local chickenCount = 0
    for id, chickenData in pairs(spawnedChickens[playerServerId]) do
        if DoesEntityExist(chickenData.entity) then
            MakeRoosterStay(chickenData.entity)
            chickenCount = chickenCount + 1
        end
    end
    
    if chickenCount > 0 then
        lib.notify({
            title = 'Staying',
            description = 'Made ' .. chickenCount .. ' animals stay in place.',
            type = 'success'
        })
    end
end)


CreateThread(function()
    while true do
        Wait(5000) 
        
        local playerServerId = GetPlayerServerId(PlayerId())
        if spawnedChickens[playerServerId] then
            for id, chickenData in pairs(spawnedChickens[playerServerId]) do
                if DoesEntityExist(chickenData.entity) then
                    local isFollowing = DecorGetBool(chickenData.entity, "IsFollowing")
                    local isStaying = DecorGetBool(chickenData.entity, "IsStaying")
                    
                    
                    if isFollowing and not isStaying then
                        local currentTask = Citizen.InvokeNative(0x35B13D7BE9B03A9F, chickenData.entity)
                        if currentTask == 0 then -- No current task
                            MakeRoosterFollow(chickenData.entity)
                        end
                    end
                else
                    -- Clean up deleted entities
                    spawnedChickens[playerServerId][id] = nil
                end
            end
        end
    end
end)


CreateThread(function()
    while true do
        Wait(30000) 
        
        local playerServerId = GetPlayerServerId(PlayerId())
        if spawnedChickens[playerServerId] then
            for id, chickenData in pairs(spawnedChickens[playerServerId]) do
                if not DoesEntityExist(chickenData.entity) then
                    spawnedChickens[playerServerId][id] = nil
                end
            end
        end
    end
end)



AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    local playerServerId = GetPlayerServerId(PlayerId())
    if spawnedChickens[playerServerId] then
        for _, chickenData in pairs(spawnedChickens[playerServerId]) do
            if DoesEntityExist(chickenData.entity) then
                DeletePed(chickenData.entity)
            end
        end
    end
end)

-- Initialize
CreateThread(function()
    
    DecorRegister("IsFollowing", 2)
    DecorRegister("IsStaying", 2)
    
   
    RegisterChickenTargeting()
end)


RegisterNetEvent('rsg-chickens:client:openChickenMenu', function()
    ShowChickenMenu()
end)

