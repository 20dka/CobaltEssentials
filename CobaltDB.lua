--Copyright (C) 2020, Preston Elam (CobaltTetra) ALL RIGHTS RESERVED
--COBALTESSENTIALS IS PROTECTED UNDER AN GPLv3 LICENSE

--    PRE: Precondition
--   POST: Postcondition
--RETURNS: What the method returns

--TODO: CHANGE THE FORMAT TO DATABASES > TABLES > KEYS > VALUES

local M = {}

local loadedDatabases = {}
local loadedJson = {}

local cobaltSysChar = string.char(0x99, 0x99, 0x99, 0x99)

local CobaltDBport = 58933

RegisterEvent("initDB","initDB")
RegisterEvent("openDatabase","openDatabase")
RegisterEvent("closeDatabase","closeDatabase")
RegisterEvent("setCobaltDBport","setCobaltDBport")

RegisterEvent("query","query")
RegisterEvent("getTable","getTable")
RegisterEvent("getTables","getTables")
RegisterEvent("getKeys","getKeys")
RegisterEvent("tableExists","tableExists")

RegisterEvent("HandleSyncEvent","HandleSyncEvent")

RegisterEvent("set","set")

----------------------------------------------------------EVENTS-----------------------------------------------------------
--give the CobaltDBconnector all the information it needs without having to re-calculate it all
function initDB(path, cpath, dbpath, config)
	
	package.cpath = cpath
	package.path = path

	json = require("json")
	socket = require("socket")
	utils = require("CobaltUtils")

	config = json.parse(config)

	_G.dbpath = dbpath

	local jsonFile, error = io.open(dbpath .."config.json")

	if error == nil then
		local cfg = json.parse(jsonFile:read("*a"))
		CobaltDBport = cfg.CobaltDBport.value or CobaltDBport
		jsonFile:close()
	end

	CElog("CobaltDB Initiated","CobaltDB")
	TriggerLocalEvent("onCobaltDBhandshake",CobaltDBport)

	connector = socket.udp()
end
----------------------------------------------------------MUTATORS---------------------------------------------------------

local function sendto(data, addr, port)
	connector:setpeername(addr, port)
	connector:send(data)
	connector:setpeername('*')
end

function openDatabase(DBname)
	DBname = DBname:gsub('\\','/')
	local jsonPath = dbpath .. DBname .. ".json"

	local jsonFile, error = io.open(jsonPath,"r")
	--CElog(jsonFile, error)

	local databaseLoaderInfo = "loaded" -- defines if the DB was created just now or if it was pre-existing.

	if jsonFile == nil then
		databaseLoaderInfo = "new"
		CElog("JSON file does not exist, creating a new one.","CobaltDB")
		jsonFile, error = io.open(jsonPath, "w")

		--print("json open error", error)


		if error then
			local s = DBname:find('/')

			CElog("Parent directory does not exist, creating it.","CobaltDB")
			DBfolder = s and DBname:sub(1,s-1) or ""

			--print(dbpath .. DBfolder)
			utils.createDirectory(dbpath .. DBfolder)
			jsonFile, error = io.open(jsonPath, "w")
			if error then
				CElog("that still didnt work, im giving up lmao.\n"..jsonPath.." should be accessible","CobaltDB")
				return
			end
		end

		jsonFile:write("{}")
		jsonFile:close()
		jsonFile, error = io.open(jsonPath,"r")
		loadedJson[DBname] = "{}"
		loadedDatabases[DBname] = {}
	else
		local jsonText = jsonFile:read("*a")

		loadedJson[DBname] = jsonText
		loadedDatabases[DBname] = json.parse(jsonText)

		jsonFile:close()
	end

	sendto(databaseLoaderInfo, "127.0.0.1", CobaltDBport)
end

function closeDatabase(DBname)
	updateDatabase(DBname)

	loadedJson[DBname] = nil
	loadedDatabases[DBname] = nil
end

function setCobaltDBport(port)
	CobaltDBport = tonumber(port)
	sendto(CobaltDBport ,"127.0.0.1", CobaltDBport)
end

--saves the table's changes to a file
function updateDatabase(DBname)
	--update current json
	loadedJson[DBname] = json.stringify(loadedDatabases[DBname])

	--write table
	local filePath = dbpath .. DBname
	local jsonFile, error = io.open(filePath .. ".temp","w")
	jsonFile:write(loadedJson[DBname])
	jsonFile:close()
	os.remove(filePath .. ".json")
	os.rename(filePath .. ".temp", filePath .. ".json")
	CElog("Updated: '" .. dbpath .. DBname .. ".json'","DEBUG")
end


--changes the table
function set(DBname, tableName, key, value)

	if loadedDatabases[DBname] ~= nil then
		
		if loadedDatabases[DBname][tableName] == nil then
			loadedDatabases[DBname][tableName] = {}
		end
		
		if key ~= nil then
			if value == "null" then
				loadedDatabases[DBname][tableName][key] = nil
			else
				loadedDatabases[DBname][tableName][key] = json.parse(value)
			end
			updateDatabase(DBname)
		end

	else --TABLE DOESN'T EXIST
		error("CobaltDB Table " .. DBname .. " not loaded!")
	end

end





---------------------------------------------------------ACCESSORS---------------------------------------------------------

--returns a specific value from the table
function query(DBname, tableName, key)

	if loadedDatabases[DBname] == nil then
		--error here, database isn't open
		data = cobaltSysChar .. "E:" .. DBname .. "not found." 
	else
		if loadedDatabases[DBname][tableName] == nil then
			--error here, table doesn't exist
			data = cobaltSysChar .. "E:" .. DBname .. " > " .. tableName .. " not found." 
		else
			if loadedDatabases[DBname][tableName][key] == nil then
				data = cobaltSysChar .. "E:" .. DBname .. " > " .. tableName .. " > " .. key .. " not found." 
			else
				--send the value as json
				data = json.stringify(loadedDatabases[DBname][tableName][key])
			end
		end
	end

	sendto(data ,"127.0.0.1", CobaltDBport)
end

--returns a read-only version of the table as json.
function getTable(DBname, tableName)
	local data

	if loadedDatabases[DBname] == nil then
		--error here, database isn't open
		data = cobaltSysChar .. "E:" .. DBname .. "not found." 
	else
		if loadedDatabases[DBname][tableName] == nil then
			--error here, tableName doesn't exist
			data = cobaltSysChar .. "E:" .. DBname .. " > " .. tableName .. " not found."
		else
			--send the table as json
			data = json.stringify(loadedDatabases[DBname][tableName])
		end
	end


	sendto(data ,"127.0.0.1", CobaltDBport)
end

--returns a read-only list of all table names within the database
function getTables(DBname)
	local data = {}
	for id, _ in pairs(loadedDatabases[DBname]) do
		data[id] = id
	end
	
	data = json.stringify(data)

	sendto(data ,"127.0.0.1", CobaltDBport)
end

function getKeys(DBname, tableName)
	local data = {}
	for id, _ in pairs(loadedDatabases[DBname][tableName]) do
		data[id] = id
	end
	
	data = json.stringify(data)

	sendto(data ,"127.0.0.1", CobaltDBport)
end

function tableExists(DBname, tableName)
	local data = "E: database not open"

	if loadedDatabases[DBname] ~= nil and loadedDatabases[DBname][tableName] ~= nil then
		data = tableName
	end

	sendto(data ,"127.0.0.1", CobaltDBport)
end


---------------------------------------------------------FUNCTIONS---------------------------------------------------------



------------------------------------------------------PUBLICINTERFACE------------------------------------------------------


----EVENTS-----

----MUTATORS-----

----ACCESSORS----

----FUNCTIONS----


return M
