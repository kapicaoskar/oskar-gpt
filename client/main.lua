local ScriptCheck = GetCurrentResourceName()

if ScriptCheck == "ES-Gpt" then
    local active = "main"
    local onDuty = false
    local patrolUnits = {}

    local tabletEntity = nil
    local tabletModel = "prop_cs_tablet"
    local tabletDict = "amb@world_human_seat_wall_tablet@female@base"
    local tabletAnim = "base"

    ESX = nil

    Citizen.CreateThread(function()
        while ESX == nil do
            TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
            Citizen.Wait(0)
        end
        ESX.PlayerData = ESX.GetPlayerData()
    end)
    RegisterNetEvent('esx:playerLoaded')
    AddEventHandler('esx:playerLoaded', function(xPlayer)
        ESX.PlayerData = xPlayer
    end)
    RegisterNetEvent('esx:setJob')
    AddEventHandler('esx:setJob', function(job)
        ESX.PlayerData.job = job
    end)

    local function attachObject()
        if tabletEntity == nil then
            RequestModel(tabletModel)
            while not HasModelLoaded(tabletModel) do
                Citizen.Wait(1)
            end
            tabletEntity = CreateObject(GetHashKey(tabletModel), 1.0, 1.0, 1.0, 1, 1, 0)
            AttachEntityToEntity(tabletEntity, GetPlayerPed(-1), GetPedBoneIndex(GetPlayerPed(-1), 57005), 0.12, 0.10, -0.13, 25.0, 170.0, 160.0, true, true, false, true, 1, true)
        end
        return
    end
    local function startTabletAnimation()
        Citizen.CreateThread(function()
            RequestAnimDict(tabletDict)
            while not HasAnimDictLoaded(tabletDict) do
                    Citizen.Wait(0)
            end
            attachObject()
            TaskPlayAnim(GetPlayerPed(-1), tabletDict, tabletAnim, 4.0, -4.0, -1, 50, 0, false, false, false)
        end)
        return
    end
    local function stopTabletAnimation()
        if tabletEntity ~= nil then
            StopAnimTask(GetPlayerPed(-1), tabletDict, tabletAnim ,8.0, -8.0, -1, 50, 0, false, false, false)
            DeleteEntity(tabletEntity)
            tabletEntity = nil
        end
        return
    end

    RegisterNUICallback("GptClose", function(data)
        SetNuiFocus(false, false)
        SendNUIMessage({type = 'CLOSE'})
        stopTabletAnimation()
        active = data.active
    end)

    RegisterNUICallback("GptGetData", function(data, cb)
        active = data.active
        ESX.TriggerServerCallback("server-gpt-tirex:GetGptData", function(newData, jobData)
            if active == "main" then
                for k, v in pairs(newData.vehicles) do
                    newData.vehicles[k].model = GetDisplayNameFromVehicleModel(v.model)
                end
            elseif active == "citizens" then
                if newData.vehicles ~= nil and #newData.vehicles > 0 then
                    for k, v in pairs(newData.vehicles) do
                        newData.vehicles[k].model = GetDisplayNameFromVehicleModel(v.model)
                    end
                end
            elseif active == "vehicles" then
                if #newData > 0 then
                    for k, v in pairs(newData) do
                        newData[k].model = GetDisplayNameFromVehicleModel(v.model)
                    end
                end
            end
            cb(newData)
        end, data)
    end)

    RegisterNUICallback("GptAddData", function(data, cb)
        ESX.TriggerServerCallback("server-gpt-tirex:AddGptData", function(newData)
            cb(newData)
        end, data)
    end)

    RegisterNUICallback("DispatchGetData", function(data, cb)
        ESX.TriggerServerCallback("server-gpt-tirex:GetDispatchData", function(newData)
            if data.type == "getCoords" then
                SetNewWaypoint(newData.x, newData.y)
            end
            cb(newData)
        end, data)
    end)

    RegisterNetEvent('client-gpt-tirex:loadGptData')
    AddEventHandler('client-gpt-tirex:loadGptData', function(newData)
        for k, v in pairs(newData.data) do
            local asd, dsa = GetStreetNameAtCoord(v.coords.x, v.coords.y, v.coords.z, Citizen.ResultAsInteger(), Citizen.ResultAsInteger())
            newData.data[k].street = GetStreetNameFromHashKey(asd)
        end
        SendNUIMessage({type = 'LOAD_DISPATCH_DATA', ssn = newData.ssn, newData.data})
    end)

    RegisterNetEvent('client-gpt-tirex:openGpt')
    AddEventHandler('client-gpt-tirex:openGpt', function()
        if ESX.PlayerData.job and ((ESX.PlayerData.job.name == Config.JobName['police'].onDuty and Config.JobName['police'].toogle) or (ESX.PlayerData.job.name == Config.JobName['sheriff'].onDuty and Config.JobName['sheriff'].toogle) or (ESX.PlayerData.job.name == Config.JobName['doj'].onDuty and Config.JobName['doj'].toogle) or (ESX.PlayerData.job.name == Config.JobName['fib'].onDuty and Config.JobName['fib'].toogle)) then
            local acces = false
            if ESX.PlayerData.job.grade >= Config.JobName[ESX.PlayerData.job.name].menagmentGrade then
                acces = true
            end
            ESX.TriggerServerCallback("server-gpt-tirex:GetGptData", function(newData, jobData)
                if active == "main" then
                    for k, v in pairs(newData.vehicles) do
                        newData.vehicles[k].model = GetDisplayNameFromVehicleModel(v.model)
                    end
                elseif active == "vehicles" then
                    if #newData > 0 then
                        for k, v in pairs(newData) do
                            newData[k].model = GetDisplayNameFromVehicleModel(v.model)
                        end
                    end
                end
                startTabletAnimation()
                SetNuiFocus(true, true)
                SendNUIMessage({type = 'OPEN-GPT', acces = acces, patrolUnits = patrolUnits, jobData = jobData, newData})
            end, {active = active})
        end
    end)
    RegisterNetEvent('client-gpt-tirex:openDispatch')
    AddEventHandler('client-gpt-tirex:openDispatch', function()
        if ESX.PlayerData.job and ((ESX.PlayerData.job.name == Config.JobName['police'].onDuty and Config.JobName['police'].toogle) or (ESX.PlayerData.job.name == Config.JobName['sheriff'].onDuty and Config.JobName['sheriff'].toogle) or (ESX.PlayerData.job.name == Config.JobName['doj'].onDuty and Config.JobName['doj'].toogle) or (ESX.PlayerData.job.name == Config.JobName['fib'].onDuty and Config.JobName['fib'].toogle)) then
            ESX.TriggerServerCallback("server-gpt-tirex:GetDispatchData", function(newData)
                for k, v in pairs(newData.data) do
                    local asd, dsa = GetStreetNameAtCoord(v.coords.x, v.coords.y, v.coords.z, Citizen.ResultAsInteger(), Citizen.ResultAsInteger())
                    newData.data[k].street = GetStreetNameFromHashKey(asd)
                end
                SetNuiFocus(true, true)
                SendNUIMessage({type = 'OPEN_DISPATCH', ssn = newData.ssn, newData.data})
            end, {type = "getData"})
        end
    end)

    Citizen.CreateThread(function()
        TriggerEvent('chat:addSuggestion', '/'..Config.HelpCommand.name, '/'..Config.HelpCommand.name..' '..Config.HelpCommand.helpText,{ { name = Config.HelpCommand.helpText, help = Config.HelpCommand.helpTextOfArgs} })
        Wait(100)
        if #Config.UnitsType > 0 then
            patrolUnits = Config.UnitsType
        else
            patrolUnits = {"None"}
        end
        while true do
            Citizen.Wait(10)
            if ESX.PlayerData.job and ((ESX.PlayerData.job.name == Config.JobName['police'].onDuty and Config.JobName['police'].toogle) or (ESX.PlayerData.job.name == Config.JobName['sheriff'].onDuty and Config.JobName['sheriff'].toogle) or (ESX.PlayerData.job.name == Config.JobName['doj'].onDuty and Config.JobName['doj'].toogle) or (ESX.PlayerData.job.name == Config.JobName['fib'].onDuty and Config.JobName['fib'].toogle)) then
                if not onDuty then
                    onDuty = true
                    TriggerServerEvent("server-gpt-tirex:dutyChange", onDuty)
                end
                if Config.OpenOptions["gpt"].keyId ~= nil then
                    if IsControlJustReleased(1, Config.OpenOptions["gpt"].keyId) then
                        TriggerEvent('client-gpt-tirex:openGpt')
                    end
                end
                if Config.OpenOptions["dispatch"].keyId ~= nil then
                    if IsControlJustReleased(1, Config.OpenOptions["dispatch"].keyId) then
                        TriggerEvent('client-gpt-tirex:openDispatch')
                    end
                end
            elseif ESX.PlayerData.job and ((ESX.PlayerData.job.name == Config.JobName['police'].offDuty and Config.JobName['police'].toogle) or (ESX.PlayerData.job.name == Config.JobName['sheriff'].offDuty and Config.JobName['sheriff'].toogle) or (ESX.PlayerData.job.name == Config.JobName['doj'].offDuty and Config.JobName['doj'].toogle) or (ESX.PlayerData.job.name == Config.JobName['fib'].offDuty and Config.JobName['fib'].toogle)) then
                if onDuty then
                    onDuty = false
                    TriggerServerEvent("server-gpt-tirex:dutyChange", onDuty)
                end
            end
        end
    end)
end