you need to change your es_extended like in needtowork folder


How to add serial number to weapons?
MySQL.insert.await('INSERT INTO gpt_weapons (owner, serial_number, model, purchase) VALUES (?, ?, ?, ?)', {
    xPlayer.ssn,
    'serial_number',
    'model',
    os.date("%m/%d/%Y")
})
Add it to your weaponshop where script give you weapon (only legal weapons)


How to add vin to your owned cars
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
paste it to your serverside in vehicleshop and change your database insert to
MySQL.Async.execute('INSERT INTO owned_vehicles (owner, plate, vehicle, vin) VALUES (@owner, @plate, @vehicle, @vin)',
	{
		['@owner']   = xPlayer.identifier,
		['@plate']   = vehicleProps.plate,
		['@vehicle'] = json.encode(vehicleProps),
		['@vin'] = GptGenerateVin()
	},




How to add ssn to esx_identity?
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
add this to your serverside in esx_identity and change your create identity trigger sql



