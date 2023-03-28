local ScriptCheck = GetCurrentResourceName()

if ScriptCheck == "ES-Gpt" then
    ESX = nil
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

    local dutyTimers = {}
    local patrolList = {}
    local dispatch = {}
    local dispatchId = 1

    local function ToInteger(number)
        return math.floor(tonumber(number) or error("Could not cast '" .. tostring(number) .. "' to number.'"))
    end

    local dutyTimerSaveAllow = true
    local function GetUserDutyTime(xPlayer)
        local dTime = MySQL.query.await('SELECT dutyTime FROM users WHERE ssn = @ssn', {
            ['@ssn'] = xPlayer.ssn
        })

        return dTime[1].dutyTime
    end
    local function SaveAllDutyTime()
        if dutyTimerSaveAllow == true then
            for k, v in pairs(dutyTimers) do
                MySQL.update('UPDATE users SET dutyTime = @dutyTime WHERE ssn = @ssn', {
                    ['@dutyTime'] = v.time,
                    ['@ssn'] = v.ssn
                })
            end
        end
        return
    end
    local function SaveUserDutyTime(xPlayer)
        dutyTimerSaveAllow = false
        for k, v in pairs(dutyTimers) do
            if v.ssn == xPlayer.ssn then
                MySQL.update('UPDATE users SET dutyTime = @dutyTime, lastOnDuty = @nowDate WHERE ssn = @ssn', {
                    ['@dutyTime'] = v.time,
                    ['@nowDate'] = os.date("%m/%d/%Y"),
                    ['@ssn'] = v.ssn
                })
                table.remove(dutyTimers, k)
                break
            end
        end
        dutyTimerSaveAllow = true
        return
    end
    local function refreshAllDispatchData()
        for _, playerId in ipairs(GetPlayers()) do
            local xPlayer2 = ESX.GetPlayerFromId(playerId)
            if (xPlayer2.job.name == Config.JobName['police'].onDuty and Config.JobName['police'].toogle) or (xPlayer2.job.name == Config.JobName['sheriff'].onDuty and Config.JobName['sheriff'].toogle) or (xPlayer2.job.name == Config.JobName['doj'].onDuty and Config.JobName['doj'].toogle) or (xPlayer2.job.name == Config.JobName['fib'].onDuty and Config.JobName['fib'].toogle) then
                TriggerClientEvent("client-gpt-tirex:loadGptData", playerId, {data = dispatch, ssn = xPlayer2.ssn})
            end
        end
    end

    function GptGenerateSsn()
        repeat
            local generatedSsn = math.random(100000, 999999)
            local result = MySQL.query.await('SELECT * FROM users WHERE ssn = @ssn', {
                ['@ssn'] = generatedSsn
            })
            if #result <= 0 then
                return generatedSsn
            end
        until(#result > 0)
    end
    function GptGenerateVin()
        local vinCharacters = { '0', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'U', 'P', 'R', 'S', 'T', 'W', 'V', 'X', 'Y', 'Z' }
        repeat
            local vinNumber = ''
            for i = 1, 17, 1 do
                vinNumber = vinNumber..vinCharacters[math.random(1, #vinCharacters)]
            end
            local result = MySQL.query.await('SELECT * FROM owned_vehicles WHERE vin = @vin', {
                ['@vin'] = vinNumber
            })
            if #result <= 0 then
                return vinNumber
            end
        until(#result > 0)
    end
    exports('GptGenerateSsn', function()
        return GptGenerateSsn()
    end)
    exports('GptGenerateVin', function()
        return GptGenerateVin()
    end)

    Citizen.CreateThread(function()
        local ticks = 0
        while true do
            Citizen.Wait(1000)
            if #dutyTimers > 0 then
                for k, v in pairs(dutyTimers) do
                    local time = v.time
                    local hours = string.sub(time, 1, time:len()-6)
                    local minutes = string.sub(time, time:len()-4, time:len()-3)
                    local seconds = string.sub(time, time:len()-1, time:len())

                    if ToInteger(seconds) < 59 then
                        seconds = seconds + 1
                    elseif ToInteger(seconds) >= 59 then
                        seconds = 0
                        minutes = minutes + 1
                    end
                    if ToInteger(minutes) >= 59 then
                        minutes = 0
                        hours = hours + 1
                    end
                    if tostring(seconds):len() == 1 then
                        seconds = "0"..seconds
                    end
                    if tostring(minutes):len() == 1 then
                        minutes = "0"..minutes
                    end

                    dutyTimers[k].time = hours..":"..minutes..":"..seconds
                end
            end
            ticks = ticks + 1
            if ticks == 60 then
                ticks = 0
                Citizen.CreateThread(function()
                    SaveAllDutyTime()
                end)
            end
        end
    end)

    RegisterServerEvent('server-gpt-tirex:dutyChange')
    AddEventHandler('server-gpt-tirex:dutyChange', function(duty)
        local source = source
        local xPlayer = ESX.GetPlayerFromId(source)
        if duty == true then
            table.insert(dutyTimers, {ssn = xPlayer.ssn, time = GetUserDutyTime(xPlayer)})
        elseif duty == false then
            SaveUserDutyTime(xPlayer)
        end
    end)

    AddEventHandler('playerDropped', function (reason)
        local source = source
        local xPlayer = ESX.GetPlayerFromId(source)
        local job = xPlayer.job.name
        if job == "police" then
            SaveUserDutyTime(xPlayer)
        end
        for k, v in pairs(patrolList) do
            for k1, v1 in pairs(v.officers) do
                if xPlayer.ssn == v1.user then
                    table.remove(dispatch[k].officers, k1)
                    break
                end
            end
        end
    end)

    ESX.RegisterServerCallback("server-gpt-tirex:GetGptData", function(source, cb, data)
        local source = source
        local xPlayer = ESX.GetPlayerFromId(source)
        local meta = {}

        if data.active == "main" then
            local name = xPlayer.name
            local time = "ERROR 404"
            local officers = {}
            local wantedCitizens = {}
            local wantedVehicles = {}
            for _, v in pairs(dutyTimers) do
                if v.ssn == xPlayer.ssn then
                    time = v.time
                    break
                end
            end
            local searchJob = 'police'
            for k, v in pairs(Config.JobName) do
                if v.onDuty == xPlayer.job.name then
                    searchJob = k
                    break
                end
            end
            local resultOnline = MySQL.query.await('SELECT identifier, ssn, firstname, lastname, job, badge FROM users WHERE job = @job', {
                ['@job'] = Config.JobName[searchJob].onDuty
            })
            local resultOffline = MySQL.query.await('SELECT identifier, ssn, firstname, lastname, job, badge FROM users WHERE job = @job', {
                ['@job'] = Config.JobName[searchJob].offDuty
            })
            for _, v in pairs(resultOnline) do
                v.status = "yes"
                v.radio = '-'
                table.insert(officers, v)
            end
            for _, v in pairs(resultOffline) do
                v.status = "no"
                v.radio = '-'
                table.insert(officers, v)
            end
            for k, v in pairs(officers) do
                officers[k].radio = Config.RadioExport
            end

            -- citizens
            local result1 = MySQL.query.await('SELECT ssn, expiry_date, create_date FROM gpt_citizens_wanted', {})
            if #result1 > 0 then
                for _, v in pairs(result1) do
                    local nowDate = os.date("%m/%d/%Y")
                    local nowDay = string.sub(nowDate, 4, 5)
                    local nowMonth = string.sub(nowDate, 1, 2)
                    local nowYear = string.sub(nowDate, 7, v.expiry_date:len())

                    local createDay = string.sub(v.create_date, 4, 5)
                    local createMonth = string.sub(v.create_date, 1, 2)
                    local createYear = string.sub(v.create_date, 7, v.create_date:len())

                    local wantedDay = string.sub(v.expiry_date, 4, 5)
                    local wantedMonth = string.sub(v.expiry_date, 1, 2)
                    local wantedYear = string.sub(v.expiry_date, 7, v.expiry_date:len())

                    if (ToInteger(createYear) == ToInteger(nowYear) and ToInteger(createMonth) == ToInteger(nowMonth) and ToInteger(createDay) == ToInteger(nowDay)) and ((ToInteger(wantedYear) > ToInteger(nowYear)) or (ToInteger(wantedYear) == ToInteger(nowYear) and ToInteger(wantedMonth) > ToInteger(nowMonth)) or (ToInteger(wantedYear) == ToInteger(nowYear) and ToInteger(wantedMonth) == ToInteger(nowMonth) and ToInteger(wantedDay) >= ToInteger(nowDay))) then
                        local result11 = MySQL.query.await('SELECT firstname, lastname FROM users WHERE ssn = @ssn', {
                            ['@ssn'] = v.ssn
                        })
                        if #result11 > 0 then
                            local insertData = {name = result11[1].firstname..' '..result11[1].lastname, ssn = v.ssn}
                            table.insert(wantedCitizens, insertData)
                        end
                    end
                end
            end

            -- vehicles
            local result2 = MySQL.query.await('SELECT vin, expiry_date, create_date FROM gpt_vehicles_wanted', {})
            if #result2 > 0 then
                for _, v in pairs(result2) do
                    local nowDate = os.date("%m/%d/%Y")
                    local nowDay = string.sub(nowDate, 4, 5)
                    local nowMonth = string.sub(nowDate, 1, 2)
                    local nowYear = string.sub(nowDate, 7, v.expiry_date:len())

                    local createDay = string.sub(v.create_date, 4, 5)
                    local createMonth = string.sub(v.create_date, 1, 2)
                    local createYear = string.sub(v.create_date, 7, v.create_date:len())

                    local wantedDay = string.sub(v.expiry_date, 4, 5)
                    local wantedMonth = string.sub(v.expiry_date, 1, 2)
                    local wantedYear = string.sub(v.expiry_date, 7, v.expiry_date:len())

                    if (ToInteger(createYear) == ToInteger(nowYear) and ToInteger(createMonth) == ToInteger(nowMonth) and ToInteger(createDay) == ToInteger(nowDay)) and ((ToInteger(wantedYear) > ToInteger(nowYear)) or (ToInteger(wantedYear) == ToInteger(nowYear) and ToInteger(wantedMonth) > ToInteger(nowMonth)) or (ToInteger(wantedYear) == ToInteger(nowYear) and ToInteger(wantedMonth) == ToInteger(nowMonth) and ToInteger(wantedDay) >= ToInteger(nowDay))) then
                        local result21 = MySQL.query.await('SELECT plate, vehicle FROM owned_vehicles WHERE vin = @vin', {
                            ['@vin'] = v.vin
                        })
                        if #result21 > 0 then
                            local vehicle = json.decode(result21[1].vehicle)
                            local insertData = {model = vehicle.model, plates = result21[1].plate, vin = v.vin}
                            table.insert(wantedVehicles, insertData)
                        end
                    end
                end
            end

            local mainAnnoucement = {content = 'Brak', id = 0}
            local result3 = MySQL.query.await('SELECT id, content, expiry_date, create_date FROM gpt_announcements', {})
            if #result3 > 0 then
                if #result3 == 1 then
                    mainAnnoucement.content = result3[1].content
                    mainAnnoucement.id = result3[1].id
                else
                    for k, v in pairs(result3) do
                        local nowDate = os.date("%m/%d/%Y")
                        local nowDay = string.sub(nowDate, 4, 5)
                        local nowMonth = string.sub(nowDate, 1, 2)
                        local nowYear = string.sub(nowDate, 7, v.expiry_date:len())

                        local createDay = string.sub(v.create_date, 4, 5)
                        local createMonth = string.sub(v.create_date, 1, 2)
                        local createYear = string.sub(v.create_date, 7, v.create_date:len())

                        if ToInteger(nowDay) == ToInteger(createDay) and ToInteger(nowMonth) == ToInteger(createMonth) and ToInteger(nowYear) == ToInteger(createYear) and v.id > mainAnnoucement.id then
                            mainAnnoucement.content = v.content
                            mainAnnoucement.id = v.id
                        end
                    end
                end
            end

            meta = {name = name, dutyTime = time, officers = officers, citizens = wantedCitizens, vehicles = wantedVehicles, annoucement = mainAnnoucement.content}
        elseif data.active == "patrol" then
            if data.type == "search" then
                local newPatrolList = {}
                if data.name:len() > 0 then
                    for _, v in pairs(patrolList) do
                        for _, v2 in pairs(v.officers) do
                            local string = string.lower(v.patrolType)..'#'..string.lower(v.patrolId)..v2.badge..string.lower(v2.name)
                            local checkString = string.find(string.gsub(string, "%s+", ""), data.name)
                            if checkString ~= nil and checkString ~= null then
                                table.insert(newPatrolList, v)
                            end
                        end
                    end
                    meta = {ssn = xPlayer.ssn, patrols = newPatrolList}
                else
                    meta = {ssn = xPlayer.ssn, patrols = patrolList}
                end
            else
                meta = {ssn = xPlayer.ssn, patrols = patrolList}
            end

            if data.type2 ~= nil and data.type2 == "search" then
                local newDispatchList = {}
                if data.name2:len() > 0 then
                    for _, v in pairs(dispatch) do
                        local string = string.lower(v.content)..'#'..string.lower(v.id)
                        local checkString = string.find(string.gsub(string, "%s+", ""), data.name2)
                        if checkString ~= nil and checkString ~= null then
                            table.insert(newDispatchList, v)
                        end
                    end
                    meta.dispatch = newDispatchList
                else
                    meta.dispatch = dispatch
                end
            else
                meta.dispatch = dispatch
            end
        elseif data.active == "citizens" then
            if data.type == "search" then
                if data.name:len() > 0 then
                    local result = MySQL.query.await('SELECT firstname, lastname, ssn, image FROM users WHERE CONCAT(firstname, lastname) LIKE @data OR ssn LIKE @data', {
                        ['@data'] = "%"..data.name.."%"
                    })
                    if #result > 0 then
                        for k, v in pairs(result) do
                            result[k].wanted = "NIE"
                            local result2 = MySQL.query.await('SELECT * FROM gpt_citizens_wanted WHERE ssn = @ssn', {
                                ['@ssn'] = v.ssn
                            })
                            if #result2 > 0 then
                                for _, v1 in pairs(result2) do
                                    local nowDate = os.date("%m/%d/%Y")
                                    local nowDay = string.sub(nowDate, 4, 5)
                                    local nowMonth = string.sub(nowDate, 1, 2)
                                    local nowYear = string.sub(nowDate, 7, v1.expiry_date:len())

                                    local wantedDay = string.sub(v1.expiry_date, 4, 5)
                                    local wantedMonth = string.sub(v1.expiry_date, 1, 2)
                                    local wantedYear = string.sub(v1.expiry_date, 7, v1.expiry_date:len())

                                    if (ToInteger(wantedYear) > ToInteger(nowYear)) or (ToInteger(wantedYear) == ToInteger(nowYear) and ToInteger(wantedMonth) > ToInteger(nowMonth)) or (ToInteger(wantedYear) == ToInteger(nowYear) and ToInteger(wantedMonth) == ToInteger(nowMonth) and ToInteger(wantedDay) >= ToInteger(nowDay)) then
                                        result[k].wanted = "TAK"
                                        break
                                    end
                                end
                            end
                        end
                    end
                    meta = result
                else
                    meta = {}
                end
            elseif data.type == "citizen" then
                local result = MySQL.query.await('SELECT firstname, lastname, dateofbirth, ssn, image FROM users WHERE ssn = @ssn', {
                    ['@ssn'] = data.user
                })

                -- vehicles
                local result2 = MySQL.query.await('SELECT plate, vehicle, vin FROM owned_vehicles WHERE ssn = @ssn', {
                    ['@ssn'] = data.user
                })
                local vehicleList = {}
                if #result2 > 0 then
                    for _, v in pairs(result2) do
                        local wanted = {}
                        local result3 = MySQL.query.await('SELECT * FROM gpt_vehicles_wanted WHERE vin = @vin', {
                            ['@vin'] = v.vin
                        })
                        if #result3 > 0 then
                            for _, v1 in pairs(result3) do
                                local nowDate = os.date("%m/%d/%Y")
                                local nowDay = string.sub(nowDate, 4, 5)
                                local nowMonth = string.sub(nowDate, 1, 2)
                                local nowYear = string.sub(nowDate, 7, nowDate:len())

                                local wantedDay = string.sub(v1.expiry_date, 4, 5)
                                local wantedMonth = string.sub(v1.expiry_date, 1, 2)
                                local wantedYear = string.sub(v1.expiry_date, 7, v1.expiry_date:len())

                                if (ToInteger(wantedYear) > ToInteger(nowYear)) or (ToInteger(wantedYear) == ToInteger(nowYear) and ToInteger(wantedMonth) > ToInteger(nowMonth)) or (ToInteger(wantedYear) == ToInteger(nowYear) and ToInteger(wantedMonth) == ToInteger(nowMonth) and ToInteger(wantedDay) >= ToInteger(nowDay)) then
                                    table.insert(wanted, v1.id)
                                end
                            end
                        end
                        local vehicle = json.decode(v.vehicle)
                        local insertData = {model = vehicle.model, vin = v.vin, plates = v.plate, wanted = wanted}
                        table.insert(vehicleList, insertData)
                    end
                end
                result[1].vehicles = vehicleList

                -- wanted
                local result3 = MySQL.query.await('SELECT * FROM gpt_citizens_wanted WHERE ssn = @ssn', {
                    ['@ssn'] = data.user
                })
                local wantedList = {}
                if #result3 then
                    for _, v in pairs(result3) do
                        local nowDate = os.date("%m/%d/%Y")
                        local nowDay = string.sub(nowDate, 4, 5)
                        local nowMonth = string.sub(nowDate, 1, 2)
                        local nowYear = string.sub(nowDate, 7, nowDate:len())

                        local wantedDay = string.sub(v.expiry_date, 4, 5)
                        local wantedMonth = string.sub(v.expiry_date, 1, 2)
                        local wantedYear = string.sub(v.expiry_date, 7, v.expiry_date:len())

                        if (ToInteger(wantedYear) > ToInteger(nowYear)) or (ToInteger(wantedYear) == ToInteger(nowYear) and ToInteger(wantedMonth) > ToInteger(nowMonth)) or (ToInteger(wantedYear) == ToInteger(nowYear) and ToInteger(wantedMonth) == ToInteger(nowMonth) and ToInteger(wantedDay) >= ToInteger(nowDay)) then
                            local result31 = MySQL.query.await('SELECT firstname, lastname FROM users WHERE ssn = @ssn', {
                                ['@ssn'] = v.author
                            })
                            local insertData = {wantedId = v.id, content = v.content, case = v.caseid, expiry_date = v.expiry_date, author = result31[1].firstname..' '..result31[1].lastname}
                            table.insert(wantedList, insertData)
                        end
                    end
                end
                result[1].wanted = wantedList

                -- history
                local result4 = MySQL.query.await('SELECT * FROM gpt_judgments WHERE ssn = @ssn', {
                    ['@ssn'] = data.user
                })
                local historyInfo = {}
                if #result4 > 0 then
                    for _, v in pairs(result4) do
                        local result5 = MySQL.query.await('SELECT firstname, lastname FROM users WHERE ssn = @ssn', {
                            ['@ssn'] = v.author
                        })
                        table.insert(historyInfo, {id = v.id, ssn = v.ssn, reason = json.decode(v.reason), bill = v.bill, time = v.time, create_time = v.create_time, create_date = v.create_date, author = result5[1].firstname..' '..result5[1].lastname})
                    end
                end
                result[1].history = historyInfo

                -- notes
                local notesList = {}
                local result5 = MySQL.query.await('SELECT * FROM gpt_citizens_notes WHERE ssn = @ssn', {
                    ['@ssn'] = data.user
                })
                if #result5 > 0 then
                    for _, v in pairs(result5) do
                        local result51 = MySQL.query.await('SELECT firstname, lastname FROM users WHERE ssn = @ssn', {
                            ['@ssn'] = v.author
                        })
                        table.insert(notesList, {id = v.id, important = v.important, content = v.content, create_time = v.create_time, create_date = v.create_date, author = result51[1].firstname..' '..result51[1].lastname})
                    end
                end
                result[1].notes = notesList

                meta = result[1]
            elseif data.type == "getNote" then
                local result = MySQL.query.await('SELECT * FROM gpt_citizens_notes WHERE id = @id', {
                    ['@id'] = data.id
                })
                meta = result[1]
            end
        elseif data.active == "vehicles" then
            if data.type == "search" then
                if data.name:len() > 0 then
                    local vehiclesList = {}
                    local result = MySQL.query.await('SELECT ssn, plate, vehicle, vin FROM owned_vehicles WHERE vin LIKE @data OR plate LIKE @data', {
                        ['@data'] = "%"..data.name.."%"
                    })
                    if #result > 0 then
                        for k, v in pairs(result) do
                            local result2 = MySQL.query.await('SELECT firstname, lastname FROM users WHERE ssn = @ssn', {
                                ['@ssn'] = v.ssn
                            })
                            local name = 'ERROR 404'
                            if #result2 > 0 then
                                name = result2[1].firstname..' '..result2[1].lastname
                            end

                            local wanted = "NIE"
                            local result3 = MySQL.query.await('SELECT * FROM gpt_vehicles_wanted WHERE vin = @vin', {
                                ['@vin'] = v.vin
                            })
                            if #result3 > 0 then
                                for _, v1 in pairs(result3) do
                                    local nowDate = os.date("%m/%d/%Y")
                                    local nowDay = string.sub(nowDate, 4, 5)
                                    local nowMonth = string.sub(nowDate, 1, 2)
                                    local nowYear = string.sub(nowDate, 7, v1.expiry_date:len())

                                    local wantedDay = string.sub(v1.expiry_date, 4, 5)
                                    local wantedMonth = string.sub(v1.expiry_date, 1, 2)
                                    local wantedYear = string.sub(v1.expiry_date, 7, v1.expiry_date:len())

                                    if (ToInteger(wantedYear) > ToInteger(nowYear)) or (ToInteger(wantedYear) == ToInteger(nowYear) and ToInteger(wantedMonth) > ToInteger(nowMonth)) or (ToInteger(wantedYear) == ToInteger(nowYear) and ToInteger(wantedMonth) == ToInteger(nowMonth) and ToInteger(wantedDay) >= ToInteger(nowDay)) then
                                        wanted = "TAK"
                                        break
                                    end
                                end
                            end
                            local vehicle = json.decode(v.vehicle)

                            local vehData = {model = vehicle.model, wanted = wanted, owner = name, vin = v.vin, plates = v.plate}
                            table.insert(vehiclesList, vehData)
                        end
                    end
                    meta = vehiclesList
                else
                    meta = {}
                end
            elseif data.type == "vehicle" then
                local result = MySQL.query.await('SELECT ssn, cossn, plate, vehicle, vin FROM owned_vehicles WHERE vin = @vin', {
                    ['@vin'] = data.vehicle
                })
                local vehicle = json.decode(result[1].vehicle)
                result[1].model = vehicle.model
                local resul2 = MySQL.query.await('SELECT firstname, lastname FROM users WHERE ssn = @ssn', {
                    ['@ssn'] = result[1].ssn
                })
                if #resul2 > 0 then
                    result[1].ownerName = resul2[1].firstname..' '..resul2[1].lastname
                end
                if result[1].cossn ~= null and result[1].cossn ~= nil then
                    local result21 = MySQL.query.await('SELECT firstname, lastname FROM users WHERE ssn = @ssn', {
                        ['@ssn'] = result[1].cossn
                    })
                    if #result21 > 0 then
                        result[1].coownerName = result21[1].firstname..' '..result21[1].lastname
                    end
                end

                -- wanted
                local result3 = MySQL.query.await('SELECT * FROM gpt_vehicles_wanted WHERE vin = @vin', {
                    ['@vin'] = data.vehicle
                })
                local wantedList = {}
                -- local historyList = {}
                if #result3 then
                    for _, v in pairs(result3) do
                        local nowDate = os.date("%m/%d/%Y")
                        local nowDay = string.sub(nowDate, 4, 5)
                        local nowMonth = string.sub(nowDate, 1, 2)
                        local nowYear = string.sub(nowDate, 7, nowDate:len())

                        local wantedDay = string.sub(v.expiry_date, 4, 5)
                        local wantedMonth = string.sub(v.expiry_date, 1, 2)
                        local wantedYear = string.sub(v.expiry_date, 7, v.expiry_date:len())

                        if (ToInteger(wantedYear) > ToInteger(nowYear)) or (ToInteger(wantedYear) == ToInteger(nowYear) and ToInteger(wantedMonth) > ToInteger(nowMonth)) or (ToInteger(wantedYear) == ToInteger(nowYear) and ToInteger(wantedMonth) == ToInteger(nowMonth) and ToInteger(wantedDay) >= ToInteger(nowDay)) then
                            local result31 = MySQL.query.await('SELECT firstname, lastname FROM users WHERE ssn = @ssn', {
                                ['@ssn'] = v.author
                            })
                            local insertData = {wantedId = v.id, content = v.content, case = v.caseid, expiry_date = v.expiry_date, author = result31[1].firstname..' '..result31[1].lastname}
                            table.insert(wantedList, insertData)
                        end
                    end
                end
                result[1].wanted = wantedList

                -- notes
                local notesList = {}
                local result4 = MySQL.query.await('SELECT * FROM gpt_vehicles_notes WHERE vin = @vin', {
                    ['@vin'] = data.vehicle
                })
                if #result4 > 0 then
                    for _, v in pairs(result4) do
                        local result41 = MySQL.query.await('SELECT firstname, lastname FROM users WHERE ssn = @ssn', {
                            ['@ssn'] = v.author
                        })
                        table.insert(notesList, {id = v.id, important = v.important, content = v.content, create_time = v.create_time, create_date = v.create_date, author = result41[1].firstname..' '..result41[1].lastname})
                    end
                end
                result[1].notes = notesList

                meta = result
            elseif data.type == "getNote" then
                local result = MySQL.query.await('SELECT * FROM gpt_vehicles_notes WHERE id = @id', {
                    ['@id'] = data.id
                })
                meta = result[1]
            end
        elseif data.active == "weapon_evi" then
            local weapons = {}
            if data.type == 'search' then
                if data.name:len() > 0 then
                    local result = MySQL.query.await('SELECT owner, serial_number, model, purchase FROM gpt_weapons WHERE serial_number LIKE @data OR owner LIKE @data', {
                        ['@data'] = "%"..data.name.."%"
                    })
                    if #result > 0 then
                        for _, v in pairs(result) do
                            local resultName = MySQL.query.await('SELECT firstname, lastname FROM users WHERE ssn = @ssn', {
                                ['@ssn'] = v.owner
                            })
                            v.name = resultName[1].firstname..' '..resultName[1].lastname
                            table.insert(weapons, v)
                        end
                        meta = {weaponList = weapons}
                    else
                        meta = {}
                    end
                else
                    local result = MySQL.query.await('SELECT owner, serial_number, model, purchase FROM gpt_weapons', {})
                    if #result > 0 then
                        for _, v in pairs(result) do
                            local resultName = MySQL.query.await('SELECT firstname, lastname FROM users WHERE ssn = @ssn', {
                                ['@ssn'] = v.owner
                            })
                            v.name = resultName[1].firstname..' '..resultName[1].lastname
                            table.insert(weapons, v)
                        end
                        meta = {weaponList = weapons}
                    else
                        meta = {}
                    end
                end
            else
                local result = MySQL.query.await('SELECT owner, serial_number, model, purchase FROM gpt_weapons', {})
                if #result > 0 then
                    for _, v in pairs(result) do
                        local resultName = MySQL.query.await('SELECT firstname, lastname FROM users WHERE ssn = @ssn', {
                            ['@ssn'] = v.owner
                        })
                        v.name = resultName[1].firstname..' '..resultName[1].lastname
                        table.insert(weapons, v)
                    end
                    meta = {weaponList = weapons}
                else
                    meta = {}
                end
            end
        elseif data.active == "discourse" then
            if data.type == "search-citizen" then
                if data.name:len() > 0 then
                    local result = MySQL.query.await('SELECT firstname, lastname, ssn FROM users WHERE CONCAT(firstname, lastname) LIKE @data OR ssn LIKE @data', {
                        ['@data'] = "%"..data.name.."%"
                    })
                    meta = result
                else
                    meta = {}
                end
            elseif data.type == "search-officer" then
                if data.name:len() > 0 then
                    local result = MySQL.query.await('SELECT firstname, lastname, ssn FROM users WHERE (CONCAT(firstname, lastname) LIKE @data OR ssn LIKE @data) AND (job = @police OR job = @offpolice OR job = @sheriff OR job = @offsheriff OR job = @doj OR job = @offdoj OR job = @fib OR job = @offfib)', {
                        ['@data'] = "%"..data.name.."%",
                        ['@police'] = Config.JobName['police'].onDuty,
                        ['@offpolice'] = Config.JobName['police'].offDuty,
                        ['@sheriff'] = Config.JobName['sheriff'].onDuty,
                        ['@offsheriff'] = Config.JobName['sheriff'].offDuty,
                        ['@doj'] = Config.JobName['doj'].onDuty,
                        ['@offdoj'] = Config.JobName['doj'].offDuty,
                        ['@fib'] = Config.JobName['fib'].onDuty,
                        ['@offfib'] = Config.JobName['fib'].offDuty
                    })
                    meta = result
                else
                    meta = {}
                end
            elseif data.type == "search-vehicle" then
                if data.name:len() > 0 then
                    local result = MySQL.query.await('SELECT vin, plate FROM owned_vehicles WHERE vin LIKE @data OR REPLACE(plate, " ", "") LIKE @data', {
                        ['@data'] = "%"..data.name.."%"
                    })
                    meta = result
                else
                    meta = {}
                end
            elseif data.type == "search" then
                if data.name:len() > 0 then
                    local result = MySQL.query.await('SELECT * FROM gpt_cases WHERE name LIKE @data OR id LIKE @data', {
                        ['@data'] = "%"..data.name.."%"
                    })
                    if #result > 0 then
                        for k, _ in pairs(result) do
                            result[k].author = json.decode(result[k].author)
                        end
                    end
                    meta = result
                else
                    local result = MySQL.query.await('SELECT * FROM gpt_cases', {})
                    if #result > 0 then
                        for k, _ in pairs(result) do
                            result[k].author = json.decode(result[k].author)
                        end
                        meta = result
                    end
                end
            elseif data.type == "discourse" then
                local result = MySQL.query.await('SELECT * FROM gpt_cases WHERE id = @id', {
                    ['@id'] = data.id
                })
                result[1].citizens = json.decode(result[1].citizens)
                result[1].officers = json.decode(result[1].officers)
                result[1].vehicles = json.decode(result[1].vehicles)
                result[1].judgments = json.decode(result[1].judgments)
                result[1].images = json.decode(result[1].images)
                result[1].author = json.decode(result[1].author)
                meta = result[1]
            else
                local result = MySQL.query.await('SELECT * FROM gpt_cases', {})
                if #result > 0 then
                    for k, _ in pairs(result) do
                        result[k].author = json.decode(result[k].author)
                    end
                    meta = result
                end
            end
        elseif data.active == "judgement" then
            if data.type == "search-citizen" then
                if data.name:len() > 0 then
                    local result = MySQL.query.await('SELECT firstname, lastname, ssn FROM users WHERE CONCAT(firstname, lastname) LIKE @data OR ssn LIKE @data', {
                        ['@data'] = "%"..data.name.."%"
                    })
                    meta = result
                else
                    meta = {}
                end
            elseif data.type == "getCaseJudgement" then
                local result = MySQL.query.await('SELECT judgments FROM gpt_cases WHERE id = @id', {
                    ['@id'] = data.case
                })
                result[1].judgments = json.decode(result[1].judgments)
                meta = result[1].judgments
            end
        elseif data.active == "evidence" then

        elseif data.active == "annoucem" then
            local nowData = {}
            local result = MySQL.query.await('SELECT id, content, expiry_date, create_date, author FROM gpt_announcements', {})
            if #result > 0 then
                for k, v in ipairs(result) do
                    local result1 = MySQL.query.await('SELECT firstname, lastname FROM users WHERE ssn = @ssn', {
                        ['@ssn'] = v.author
                    })
                    if #result1 > 0 then
                        result[k].author = result1[1].firstname..' '..result1[1].lastname
                    end

                    local nowDate = os.date("%m/%d/%Y")
                    local nowDay = string.sub(nowDate, 4, 5)
                    local nowMonth = string.sub(nowDate, 1, 2)
                    local nowYear = string.sub(nowDate, 7, v.expiry_date:len())
        
                    local expiryDay = string.sub(v.expiry_date, 4, 5)
                    local expiryMonth = string.sub(v.expiry_date, 1, 2)
                    local expiryYear = string.sub(v.expiry_date, 7, v.expiry_date:len())

                    if (ToInteger(expiryYear) > ToInteger(nowYear)) or (ToInteger(expiryYear) == ToInteger(nowYear) and ToInteger(expiryMonth) > ToInteger(nowMonth)) or (ToInteger(expiryYear) == ToInteger(nowYear) and ToInteger(expiryMonth) == ToInteger(nowMonth) and ToInteger(expiryDay) >= ToInteger(nowDay)) then
                        result[k].status = 'true'
                        table.insert(nowData, v)
                    else
                        if ((ToInteger(expiryYear) + 1) == ToInteger(nowYear) and ToInteger(nowMonth) == 0 and ToInteger(nowDay) == 0) or (ToInteger(expiryYear) == ToInteger(nowYear) and ToInteger(expiryMonth) == ToInteger(nowMonth) and (ToInteger(expiryDay) + 1) == ToInteger(nowDay)) or (ToInteger(expiryYear) == ToInteger(nowYear) and (ToInteger(expiryMonth) + 1) == ToInteger(nowMonth) and ToInteger(nowDay) == 0) then
                            result[k].status = 'false'
                            table.insert(nowData, v)
                        end
                    end
                end
                
                meta = nowData
            else
                meta = {}
            end
        elseif data.active == "workers" then
            if data.type == 'search' then
                if data.name:len() > 0 then
                    local result = MySQL.query.await('SELECT ssn, job, job_grade, firstname, lastname, dutyTime, lastOnDuty FROM users WHERE CONCAT(firstname, lastname) LIKE @data AND (job = @job OR job = @offjob)', {
                        ['@data'] = "%"..data.name.."%",
                        ['@job'] = "police",
                        ['@offjob'] = "offpolice"
                    })
                    if #result > 0 then
                        for k, v in pairs(result) do
                            local result2 = MySQL.query.await('SELECT label FROM job_grades WHERE job_name = @job_name AND grade = @grade', {
                                ['@job_name'] = "police",
                                ['@grade'] = v.job_grade
                            })
                            result[k].job_grade = result2[1].label

                            result[k].patrol = 'BRAK'
                            if #patrolList > 0 then
                                for _, v2 in pairs(patrolList) do
                                    for _, v3 in pairs(v2.officers) do
                                        if v3.ssn == v.ssn then
                                            result[k].patrol = v2.patrolType..'#'..v2.patrolId
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    meta = result
                else
                    local result = MySQL.query.await('SELECT ssn, job, job_grade, firstname, lastname, dutyTime, lastOnDuty FROM users WHERE job = @job OR job = @offjob', {
                        ['@job'] = "police",
                        ['@offjob'] = "offpolice"
                    })
                    if #result > 0 then
                        for k, v in pairs(result) do
                            local result2 = MySQL.query.await('SELECT label FROM job_grades WHERE job_name = @job_name AND grade = @grade', {
                                ['@job_name'] = "police",
                                ['@grade'] = v.job_grade
                            })
                            result[k].job_grade = result2[1].label

                            result[k].patrol = 'BRAK'
                            if #patrolList > 0 then
                                for _, v2 in pairs(patrolList) do
                                    for _, v3 in pairs(v2.officers) do
                                        if v3.ssn == v.ssn then
                                            result[k].patrol = v2.patrolType..'#'..v2.patrolId
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    meta = result
                end
            elseif data.type == "worker" then
                local result = MySQL.query.await('SELECT job, job_grade, firstname, lastname, dateofbirth, ssn, dutyTime, badge FROM users WHERE ssn = @ssn', {
                    ['@ssn'] = data.user
                })
                local result2 = MySQL.query.await('SELECT label FROM job_grades WHERE job_name = @job_name AND grade = @grade', {
                    ['@job_name'] = "police",
                    ['@grade'] = result[1].job_grade
                })
                result[1].job_grade = result2[1].label

                result[1].patrol = 'BRAK'
                if #patrolList > 0 then
                    for _, v2 in pairs(patrolList) do
                        for _, v3 in pairs(v2.officers) do
                            if v3.ssn == data.user then
                                result[1].patrol = v2.patrolType..'#'..v2.patrolId
                                break
                            end
                        end
                    end
                end

                -- licencje
                local result3 = MySQL.query.await('SELECT name FROM gpt_licenses WHERE owner = @owner', {
                    ['@owner'] = data.user
                })
                result[1].licens = {}
                if #result3 > 0 then
                    result[1].licens = {}
                    for k, v in pairs(result3) do
                        local result31 = MySQL.query.await('SELECT label FROM licenses WHERE type = @type', {
                            ['@type'] = v.name
                        })
                        table.insert(result[1].licens, {name = result31[1].label})
                    end
                end

                meta = result[1]
            else
                local result = MySQL.query.await('SELECT ssn, job, job_grade, firstname, lastname, dutyTime, lastOnDuty FROM users WHERE job = @job OR job = @offjob', {
                    ['@job'] = "police",
                    ['@offjob'] = "offpolice"
                })
                if #result > 0 then
                    for k, v in pairs(result) do
                        local result2 = MySQL.query.await('SELECT label FROM job_grades WHERE job_name = @job_name AND grade = @grade', {
                            ['@job_name'] = "police",
                            ['@grade'] = v.job_grade
                        })
                        result[k].job_grade = result2[1].label

                        result[k].patrol = 'BRAK'
                        if #patrolList > 0 then
                            for _, v2 in pairs(patrolList) do
                                for _, v3 in pairs(v2.officers) do
                                    if v3.ssn == v.ssn then
                                        result[k].patrol = v2.patrolType..'#'..v2.patrolId
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                meta = result
            end
        end

        local jobData = {}
        jobData.ownJobGrade = xPlayer.job.grade
        jobData.jobGrades = MySQL.query.await('SELECT job_name, grade, label FROM job_grades WHERE job_name = @job_name', {
            ['@job_name'] = xPlayer.job.name
        })
        jobData.jobLicense = MySQL.query.await('SELECT * FROM licenses WHERE type LIKE @data', {
            ['@data'] = xPlayer.job.name.."%",
        })

        cb(meta, jobData)
    end)

    ESX.RegisterServerCallback("server-gpt-tirex:AddGptData", function(source, cb, data)
        local source = source
        local xPlayer = ESX.GetPlayerFromId(source)
        local meta = {}
        if data.active == "main" then

        elseif data.active == "patrol" then
            local newPatrolList = {}
            if data.type == "create" then
                local badge = MySQL.query.await('SELECT badge FROM users WHERE ssn = @ssn', {
                    ['@ssn'] = xPlayer.ssn
                })
                if #patrolList > 0 then
                    for k, v in pairs(patrolList) do
                        for k1, v1 in pairs(v.officers) do
                            if v1.ssn == xPlayer.ssn then
                                table.remove(patrolList[k].officers, k1)
                                if patrolList[k].officers == nil or #patrolList[k].officers < 1 then
                                    table.remove(patrolList, k)
                                end
                                break
                            end
                        end
                    end
                end
                table.insert(patrolList, {
                    blocked = false,
                    patrolId = data.patrolNumber,
                    patrolType = data.patrolType,
                    creator = xPlayer.ssn,
                    officers = {
                        {ssn = xPlayer.ssn, name = xPlayer.name, job = xPlayer.job.name, badge = badge[1].badge or "BRAK"},
                    }
                })
                for _, v in pairs(patrolList) do
                    local tempList = v
                    tempList.yourSsn = xPlayer.ssn
                    table.insert(newPatrolList, tempList)
                end
            elseif data.type == "leave" then
                if #patrolList > 0 then
                    for k, v in pairs(patrolList) do
                        for k1, v1 in pairs(v.officers) do
                            if v1.ssn == xPlayer.ssn then
                                table.remove(patrolList[k].officers, k1)
                                if patrolList[k].officers == nil or #patrolList[k].officers < 1 then
                                    table.remove(patrolList, k)
                                else
                                    patrolList[k].creator = patrolList[k].officers[1].ssn
                                end
                                break
                            end
                        end
                    end
                end
            elseif data.type == "kick" then
                if #patrolList > 0 then
                    for k, v in pairs(patrolList) do
                        for k1, v1 in pairs(v.officers) do
                            if v1.ssn == data.player then
                                table.remove(patrolList[k].officers, k1)
                                break
                            end
                        end
                    end
                end
            elseif data.type == "block" then
                if #patrolList > 0 then
                    for k, v in pairs(patrolList) do
                        if v.patrolId == data.id then
                            patrolList[k].blocked = not patrolList[k].blocked
                        end
                    end
                end
            elseif data.type == "join" then
                if #patrolList > 0 then
                    for k, v in pairs(patrolList) do
                        if v.patrolId == data.id and #v.officers < Config.MaxPatrolSlots then
                            local badge = MySQL.query.await('SELECT badge FROM users WHERE ssn = @ssn', {
                                ['@ssn'] = xPlayer.ssn
                            })
                            table.insert(patrolList[k].officers, {ssn = xPlayer.ssn, name = xPlayer.name, job = xPlayer.job.name, badge = badge[1].badge or "BRAK"})
                        end
                    end
                end
            end
        elseif data.active == "citizens" then
            if data.type == "newImage" then
                if data.image == '' or data.image == ' ' then
                    MySQL.update('UPDATE users SET image = @image WHERE ssn = @ssn', {
                        ['@image'] = '',
                        ['@ssn'] = data.user
                    })
                else
                    MySQL.update('UPDATE users SET image = @image WHERE ssn = @ssn', {
                        ['@image'] = data.image,
                        ['@ssn'] = data.user
                    })
                end
                meta = data.user
            elseif data.type == "addWanted" then
                local nowDate = os.date("%m/%d/%Y")
                local nowDay = string.sub(nowDate, 4, 5)
                local nowMonth = string.sub(nowDate, 1, 2)
                local nowYear = string.sub(nowDate, 7, nowDate:len())

                local endTime = os.time({day = nowDay + data.expiry, month = nowMonth, year = nowYear})

                MySQL.insert.await('INSERT INTO gpt_citizens_wanted (ssn, content, caseid, expiry_date, create_date, author) VALUES (?, ?, ?, ?, ?, ?)', {
                    data.user,
                    data.content,
                    data.case,
                    os.date("%m/%d/%Y", endTime),
                    nowDate,
                    xPlayer.ssn
                })
            elseif data.type == "deleteWanted" then
                if data.id ~= nil then
                    MySQL.update('UPDATE gpt_citizens_wanted SET expiry_date = @expiry_date WHERE id = @id', {
                        ['@expiry_date'] = '11/11/1111',
                        ['@id'] = data.id
                    })
                end
            elseif data.type == "addNote" then
                MySQL.insert.await('INSERT INTO gpt_citizens_notes (ssn, important, content, create_time, create_date, author) VALUES (?, ?, ?, ?, ?, ?)', {
                    data.user,
                    tostring(data.important),
                    data.content,
                    os.date("%H:%M"),
                    os.date("%m/%d/%Y"),
                    xPlayer.ssn
                })
            elseif data.type == "editNote" then
                MySQL.update('UPDATE gpt_citizens_notes SET content = @content, author = @author WHERE id = @id', {
                    ['@content'] = data.content,
                    ['@author'] = xPlayer.ssn,
                    ['@id'] = data.id
                })
            elseif data.type == "deleteNote" then
                MySQL.update.await('DELETE FROM gpt_citizens_notes WHERE id = @id', {
                    ['@id'] = data.id
                })
            end
        elseif data.active == "vehicles" then
            if data.type == "addWanted" then
                local nowDate = os.date("%m/%d/%Y")
                local nowDay = string.sub(nowDate, 4, 5)
                local nowMonth = string.sub(nowDate, 1, 2)
                local nowYear = string.sub(nowDate, 7, nowDate:len())

                local endTime = os.time({day = nowDay + data.expiry, month = nowMonth, year = nowYear})

                MySQL.insert.await('INSERT INTO gpt_vehicles_wanted (vid, content, caseid, expiry_date, create_date, author) VALUES (?, ?, ?, ?, ?, ?)', {
                    data.user,
                    data.content,
                    data.case,
                    os.date("%m/%d/%Y", endTime),
                    nowDate,
                    xPlayer.ssn
                })
            elseif data.type == "deleteWanted" then
                if data.id ~= nil then
                    MySQL.update('UPDATE gpt_vehicles_wanted SET expiry_date = @expiry_date WHERE id = @id', {
                        ['@expiry_date'] = '11/11/1111',
                        ['@id'] = data.id
                    })
                end
            elseif data.type == "addNote" then
                MySQL.insert.await('INSERT INTO gpt_vehicles_notes (vin, important, content, create_time, create_date, author) VALUES (?, ?, ?, ?, ?, ?)', {
                    data.vin,
                    tostring(data.important),
                    data.content,
                    os.date("%H:%M"),
                    os.date("%m/%d/%Y"),
                    xPlayer.ssn
                })
            elseif data.type == "editNote" then
                MySQL.update('UPDATE gpt_vehicles_notes SET content = @content, author = @author WHERE id = @id', {
                    ['@content'] = data.content,
                    ['@author'] = xPlayer.ssn,
                    ['@id'] = data.id
                })
            elseif data.type == "deleteNote" then
                MySQL.update.await('DELETE FROM gpt_vehicles_notes WHERE id = @id', {
                    ['@id'] = data.id
                })
            end
        elseif data.active == "weapon_evi" then

        elseif data.active == "discourse" then
            if data.type == "addDiscourse" then
                local newData = data.newdata[1]
                local author = {ssn = xPlayer.ssn, name = xPlayer.name}

                MySQL.insert.await('INSERT INTO gpt_cases (name, status, citizens, officers, vehicles, judgments, content, images, edit_date, create_date, author) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ', {
                    newData.name,
                    tostring(newData.status),
                    tostring(json.encode(newData.citizens)),
                    tostring(json.encode(newData.officers)),
                    tostring(json.encode(newData.vehicles)),
                    tostring(json.encode(newData.judgements)),
                    newData.content,
                    tostring(json.encode(newData.images)),
                    os.date("%m/%d/%Y"),
                    os.date("%m/%d/%Y"),
                    json.encode(author)
                })
            elseif data.type == "editDiscourse" then
                local newData = data.newdata[1]
                MySQL.update('UPDATE gpt_cases SET status = @status, citizens = @citizens, officers = @officers, vehicles = @vehicles, judgments = @judgments, content = @content, images = @images, edit_date = @edit_date WHERE id = @id', {
                    ['@status'] = newData.status,
                    ['@citizens'] = tostring(json.encode(newData.citizens)),
                    ['@officers'] = tostring(json.encode(newData.officers)),
                    ['@vehicles'] = tostring(json.encode(newData.vehicles)),
                    ['@judgments'] = tostring(json.encode(newData.judgements)),
                    ['@content'] = newData.content,
                    ['@images'] = tostring(json.encode(newData.images)), 
                    ['@edit_date'] = os.date("%m/%d/%Y"),
                    ['@id'] = newData.id
                })
            end
        elseif data.active == "judgement" then
            if data.type == "setCaseJudgements" then
                MySQL.update('UPDATE gpt_cases SET judgments = @judgments WHERE id = @id', {
                    ['@judgments'] = tostring(json.encode(data.judgements)),
                    ['@id'] = data.case
                })
            elseif data.type == "sendJailAndBill" then
                for _, v in pairs(data.players) do
                    MySQL.insert.await('INSERT INTO gpt_judgments (ssn, reason, bill, time, create_time, create_date, author) VALUES (?, ?, ?, ?, ?, ?, ?) ', {
                        v.ssn,
                        tostring(json.encode(data.reason)),
                        data.bill,
                        data.time,
                        os.date("%H:%M"),
                        os.date("%m/%d/%Y"),
                        xPlayer.ssn
                    })
                    for _, playerId in ipairs(GetPlayers()) do
                        local xPlayer2 = ESX.GetPlayerFromId(playerId)
                        if tostring(v.ssn) == tostring(xPlayer2.ssn) then
                            if Config.JailSettings.customJailSystem.type == 'client' then
                                TriggerClientEvent(Config.JailSettings.customJailSystem.trigger, playerId, xPlayer.job.name, data.bill, data.time)
                            elseif Config.JailSettings.customJailSystem.type == 'server' then
                                TriggerEvent(Config.JailSettings.customJailSystem.trigger, playerId, xPlayer.job.name, data.bill, data.time)
                            end
                            if Config.JailSettings.customBillSystem.type == 'client' then
                                TriggerClientEvent(Config.JailSettings.customBillSystem.trigger, playerId, xPlayer.job.name, data.bill, data.time)
                            elseif Config.JailSettings.customBillSystem.type == 'server' then
                                TriggerEvent(Config.JailSettings.customBillSystem.trigger, playerId, xPlayer.job.name, data.bill, data.time)
                            end
                            break
                        end
                    end
                end
            end
        elseif data.active == "evidence" then

        elseif data.active == "annoucem" then
            if data.type == "addAnnounce" then
                local nowTime = os.date("%H:%M:%S")
                local nowHour = string.sub(nowTime, 1, 2)
                local nowMin = string.sub(nowTime, 4, 5)
                local nowSec = string.sub(nowTime, 7, 8)
                local nowDate = os.date("%m/%d/%Y")
                local nowDay = string.sub(nowDate, 4, 5)
                local nowMonth = string.sub(nowDate, 1, 2)
                local nowYear = string.sub(nowDate, 7, nowDate:len())
                local endTime = os.time({year = nowYear, month = nowMonth, day = nowDay + ToInteger(data.days), hour = nowHour, min = nowMin, sec = nowSec})
                MySQL.insert.await('INSERT INTO gpt_announcements (content, expiry_date, create_date, author) VALUES (?, ?, ?, ?)', {
                    data.content,
                    os.date("%m/%d/%Y", endTime),
                    nowDate,
                    xPlayer.ssn
                })
            end
        elseif data.active == "workers" then
            if data.type == "addWorker" then
                local xPlayer2 = ESX.GetPlayerFromId(data.player)
                if xPlayer2 ~= nil then
                    xPlayer2.setJob(data.newJob, data.newGrade)
                end
            elseif data.type == "changeGrade" then
                local debug = true
                for _, playerId in ipairs(GetPlayers()) do
                    local xPlayer2 = ESX.GetPlayerFromId(playerId)
                    if xPlayer2.ssn == data.player then
                        xPlayer2.setJob(xPlayer2.job.name, data.newGrade)
                        debug = false
                        break
                    end
                end
                if debug == true then
                    MySQL.update('UPDATE users SET job_grade = @job_grade WHERE ssn = @ssn', {
                        ['@job_grade'] = data.newGrade,
                        ['@ssn'] = data.player
                    })
                end
            elseif data.type == "changeLicense" then
                local result = MySQL.query.await('SELECT * FROM gpt_licenses WHERE owner = @ssn AND name = @name', {
                    ['@ssn'] = data.player,
                    ['@name'] = data.license
                })
                if #result > 0 then
                    MySQL.update.await('DELETE FROM gpt_licenses WHERE owner = @ssn AND name = @name', {
                        ['@ssn'] = data.player,
                        ['@name'] = data.license
                    })
                else
                    MySQL.insert.await('INSERT INTO gpt_licenses (name, owner) VALUES (?, ?)', {
                        data.license,
                        data.player
                    })
                end
            elseif data.type == "changeBadge" then
                MySQL.update('UPDATE users SET badge = @badge WHERE ssn = @ssn', {
                    ['@badge'] = data.newBadge,
                    ['@ssn'] = data.player
                })
            end
        end
        cb(meta)
    end)

    ESX.RegisterServerCallback("server-gpt-tirex:GetDispatchData", function(source, cb, data)
        local source = source
        local xPlayer = ESX.GetPlayerFromId(source)
        local meta = {}

        if data.type == "getData" then
            meta = {data = dispatch, ssn = xPlayer.ssn}
        elseif data.type == "addToList" then
            for k, v in pairs(dispatch) do
                if ToInteger(v.id) == ToInteger(data.id) then
                    if v.maxOfficers > #v.officers then
                        local debug = true
                        for _, v1 in pairs(v.officers) do
                            if v1.user == xPlayer.ssn then
                                debug = false
                                break
                            end
                        end
                        if debug == true then
                            local result = MySQL.query.await('SELECT badge FROM users WHERE ssn = @ssn', {
                                ['@ssn'] = xPlayer.ssn
                            })
                            table.insert(dispatch[k].officers, {user = xPlayer.ssn, badge = result[1].badge})
                        end
            
                        Citizen.CreateThread(function()
                            refreshAllDispatchData()
                        end)
                    end
                    break
                end
            end
        elseif data.type == "getCoords" then
            for k, v in pairs(dispatch) do
                if ToInteger(v.id) == ToInteger(data.id) then
                    meta = dispatch[k].coords
                    break
                end
            end
        elseif data.type == "deleteFromList" then
            for k, v in pairs(dispatch) do
                if ToInteger(v.id) == ToInteger(data.id) then
                    for k1, v1 in pairs(v.officers) do
                        if xPlayer.ssn == v1.user then
                            table.remove(dispatch[k].officers, k1)
                            break
                        end
                    end
                    break
                end
            end
            Citizen.CreateThread(function()
                refreshAllDispatchData()
            end)
        elseif data.type == "deleteReport" then
            for k, v in pairs(dispatch) do
                if ToInteger(v.id) == ToInteger(data.id) then
                    table.remove(dispatch, k)
                    break
                end
            end
            Citizen.CreateThread(function()
                refreshAllDispatchData()
            end)
        end

        cb(meta)
    end)
    local function dispatchReportsTimer()
        Wait(100)
        while #dispatch > 0 do
            Citizen.Wait(1000)
            for k, v in pairs(dispatch) do
                local nowTime = os.date("%H:%M:%S")
                if nowTime == v.expiryTime and dispatch[k] ~= nil then
                    if #v.officers == 0 then
                        table.remove(dispatch, k)
                    else
                        local nowTime = os.date("%H:%M:%S")
                        local nowHour = string.sub(nowTime, 1, 2)
                        local nowMin = string.sub(nowTime, 4, 5)
                        local nowSec = string.sub(nowTime, 7, 8)
                        local nowDate = os.date("%m/%d/%Y")
                        local nowDay = string.sub(nowDate, 4, 5)
                        local nowMonth = string.sub(nowDate, 1, 2)
                        local nowYear = string.sub(nowDate, 7, nowDate:len())
                        local endTime = os.time({year = nowYear, month = nowMonth, day = nowDay, hour = nowHour, min = nowMin + 1, sec = nowSec})
                        dispatch[k].expiryTime = os.date("%H:%M:%S", endTime)
                    end
                    Citizen.CreateThread(function()
                        refreshAllDispatchData()
                    end)
                end
            end
        end
    end
    RegisterNetEvent('server-dispatch-tirex:addData')
    AddEventHandler('server-dispatch-tirex:addData', function(newtype, newcoords, newcontent, newmaxOfficers, newmin, addxPlayer)
        local xPlayer = nil
        if addxPlayer == true then
            xPlayer = ESX.GetPlayerFromId(source)
        end
        if #dispatch == 0 then
            Citizen.CreateThread(function()
                dispatchReportsTimer()
            end)
        end
        local nowTime = os.date("%H:%M:%S")
        local nowHour = string.sub(nowTime, 1, 2)
        local nowMin = string.sub(nowTime, 4, 5)
        local nowSec = string.sub(nowTime, 7, 8)

        local nowDate = os.date("%m/%d/%Y")
        local nowDay = string.sub(nowDate, 4, 5)
        local nowMonth = string.sub(nowDate, 1, 2)
        local nowYear = string.sub(nowDate, 7, nowDate:len())

        local endTime = os.time({year = nowYear, month = nowMonth, day = nowDay, hour = nowHour, min = nowMin + newmin, sec = nowSec})

        dispatch[dispatchId] = {id = dispatchId, type = newtype, coords = newcoords, content = newcontent, maxOfficers = newmaxOfficers, officers = {}, createTime = nowTime, expiryTime = os.date("%H:%M:%S", endTime)}
        dispatchId = dispatchId + 1

        for _, playerId in ipairs(GetPlayers()) do
            local xPlayer2 = ESX.GetPlayerFromId(playerId)
            if (xPlayer2.job.name == Config.JobName['police'].onDuty and Config.JobName['police'].toogle and Config.JobName['police'].notify) or (xPlayer2.job.name == Config.JobName['sheriff'].onDuty and Config.JobName['sheriff'].toogle and Config.JobName['sheriff'].notify) or (xPlayer2.job.name == Config.JobName['doj'].onDuty and Config.JobName['doj'].toogle and Config.JobName['doj'].notify) or (xPlayer2.job.name == Config.JobName['fib'].onDuty and Config.JobName['fib'].toogle and Config.JobName['fib'].notify) then
                TriggerClientEvent('esx:showNotification', playerId, "DISPATCH "..newtype.. ": " ..newcontent )
            end
        end

        Citizen.CreateThread(function()
            refreshAllDispatchData()
        end)
    end)

    RegisterCommand('911', function(source, args, raw)
        local xPlayer = ESX.GetPlayerFromId(source)
        local commandType = Config.HelpCommand.name
        local coords = xPlayer.getCoords(true)
        local content = string.sub(raw, Config.HelpCommand.name:len()+2, raw:len())
        local maxOfficers = Config.HelpCommand.maxOfficers
        local minutes = Config.HelpCommand.reportsDurability

        TriggerEvent("server-dispatch-tirex:addData", commandType, coords, content, maxOfficers, minutes, false)
    end)

    local messageData = {}

    messageData[#messageData+1] = '----------------------------------'
    messageData[#messageData+1] = '|   Experience Studio Presents   |'
    messageData[#messageData+1] = '|             ES-Gpt             |'
    messageData[#messageData+1] = '|      Created By Tirex#1514     |'
    messageData[#messageData+1] = '----------------------------------'

    for _, v in pairs(messageData) do
        print(v)
    end
else
    local messageData = {}

    local addSpaceString = ''
    local addMinusString = ''
    for i = 1, tostring(ScriptCheck):len(), 1 do
        addSpaceString = addSpaceString..' '
        addMinusString = addMinusString..'-'
    end

    messageData[#messageData+1] = '----------------------------------------'..addMinusString
    messageData[#messageData+1] = '| Your resource name "'..ScriptCheck..'" is no allowed! |'
    messageData[#messageData+1] = '|              Bring it back!          '..addSpaceString..'|'
    messageData[#messageData+1] = '----------------------------------------'..addMinusString

    for _, v in pairs(messageData) do
        print(v)
    end
end