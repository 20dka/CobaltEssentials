--Copyright (C) 2020, Preston Elam (CobaltTetra) ALL RIGHTS RESERVED
--COBALTESSENTIALS IS PROTECTED UNDER AN GPLv3 LICENSE

local M = {}
_G.SendChatMessageV = _G.SendChatMessage
_G.RemoveVehicleV = _G.RemoveVehicle
_G.GetPlayerVehiclesV = _G.GetPlayerVehicles
_G.DropPlayerV = _G.DropPlayer

-------------------------------------------------REPLACED-GLOBAL-FUNCTIONS-------------------------------------------------
--Trigger the on VehicleDeleted event
function RemoveVehicle(playerID, vehID)
	RemoveVehicleV(playerID,vehID)
	TriggerGlobalEvent("onVehicleDeleted", playerID, vehID)
end

--Make sending multi-line chat messages with \n possible.
function SendChatMessage(playerID, message)
	message = split(message ,"\n")

	for k,v in ipairs(message) do
		SendChatMessageV(playerID, v)
		Sleep(10)
	end
end

--make GetPlayerVehicles actually work.
function GetPlayerVehicles(playerID)
	return players[playerID].vehicles
end

function DropPlayer(playerID, reason)
	if players[playerID] ~= nil then
		players[playerID].dropReason = reason
	end
	DropPlayerV(playerID, reason)
end
---------------------------------------------------------------------------------------------------------------------------

function CElog(string, heading, debug)
	heading = heading or "Cobalt"
	debug = debug or false

	local out = ("[" .. color(90) .. os.date("%d/%m/%Y %X", os.time()) .. color(0) ..  "]"):gsub("/0","/"):gsub("%[0","[")

	if heading == "WARN" then
		out =  out .. " [" .. color(31) .. "WARN" .. color(0) .. "] " .. color(31) .. string
	elseif heading == "RCON" then
		out = out .. " [" .. color(33) .. "RCON" .. color(0) .. "] " .. color(0) .. string
	elseif heading == "CobaltDB" then
		out = out .. " [" .. color(35) .. "CobaltDB" .. color(0) .. "] " .. color(0) .. string
	elseif heading == "CHAT" then
		out = out .. " [" .. color(32) .. "CHAT" .. color(0) .. "] " .. color(0) .. string
	elseif heading == "DEBUG" and ((config == nil or config.enableDebug.value == true) or (query and query("config","enableDebug","value") == true)) then
		out = out .. " [" .. color(97) .. "DEBUG" .. color(0) .. "] " .. color(0) .. string
	else
		out = out .. " [" .. color(94) .. heading .. color(0) .. "] " .. color(0) .. string
	end


	out = out .. color(0)
	print(out)
	return out
end

--changes the color of the console.
function color(fg,bg)
	if (config == nil or config.enableColors.value == true) and true then
		if bg then
			return string.char(27) .. '[' .. tostring(fg) .. ';' .. tostring(bg) .. 'm'
		else
			return string.char(27) .. '[' .. tostring(fg) .. 'm'
		end
	else
		return ""
	end
end

function split(s, sep)
	local fields = {}

	local sep = sep or " "
	local pattern = string.format("([^%s]+)", sep)
	string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)

	return fields
end

--PRE: ID is passed in, representing a player ID, an RCON ID, or C to print into console with message, a valid string.
--POST: message is output to the desired destination, if sent to players \n is seperated.

--IDs | "C" = console | "R<N>" = RCON | "<number>" = player
function output(ID, message)
	if ID == nil then
		error("ID is nil")
	end
	if message == nil then
		error("message is nil")	
	end

	if type(ID) == "string" then

		if ID == "C" then
			CElog(message)
		elseif ID:sub(1,1) == "R" then
			TriggerGlobalEvent("RCONsend", ID, message)
		end
	
	elseif type(ID) == "number" then
		SendChatMessage(ID, message)
	else
		error("Invalid ID")
	end
end

-- https://stackoverflow.com/a/40195356/7137271
local function exists(file)
	local ok, err, code = os.rename(file, file)
	if not ok then
		if code == 13 then
			-- Permission denied, but it exists
			return true
		end
	end
	return ok, err
end

local function isDir(path)
	-- "/" works on both Unix and Windows
	return exists(path.."/")
end

local function createDirectory(path)
	path = path:gsub("\\","/")
	if os.getenv('HOME') then -- scuffed Unix check until the beammp server has a global for it
		os.execute("mkdir -p " .. path)
	else
		os.execute('poweshell "mkdir ' .. path .. '"')
	end
end

local function copyFile(src, dst)
	if os.getenv('HOME') then
		os.execute(string.format("cp %s %s",src:gsub('\\', '/'), dst:gsub('\\','/')))
	else
		os.execute(string.format("copy %s %s",src:gsub('/', '\\'), dst:gsub('/','\\')))
	end
end

local function getPathSplit(path)
	local name, ext = string.match(path , "/*(%w+)(.%w+)$")
	local dir = path:gsub('/'..name..ext, '')
	return dir, name, ext
end


local function readJson(path)
	local jsonFile, error = io.open(path,"r")
	if error then return nil, error end

	local jsonText = jsonFile:read("*a")
	jsonFile:close()

	return json.parse(jsonText), false
end

local function writeJson(path, data)
	local dir, fname, ext = getPathSplit(path)

	if not isDir(dir) then createDirectory(dir) end

	local jsonFile, error = io.open(path,"w")
	if error then return false end

	jsonFile:write(json.stringify(data or {}))
	jsonFile:close()

	return true
end

local function parseVehData(data)
	local s, e = data:find('%{')

	data = data:sub(s)

	local sucessful, tempData = pcall(json.parse, data)
	if not sucessful then
		--TODO: BACKUP THE JSON IN A FILE. tempData is the error, data is the json.
		return false
	end
	data = tempData


	data.serverVID = vehID
	data.clientVID = data.VID
	data.name = data.jbm
	data.cfg = data.vcf


	if data[4] ~= nil then
		local sucessful, tempData = pcall(json.parse, data[4])
		if not sucessful then
			--TODO: BACKUP THE JSON IN A FILE. tempData is the error, data is the json.
			return false
		end
		data.info = tempData 
	end

	return data
end

--read a .cfg file and return a table containing it's files
local function readCfg(path)

	local cfg = {}
	
	local n = 1

	local file = io.open(path,"r")

	local line = file:read("*l") --get first value for line
	while line ~= nil do

		--remove comments
		local c = line:find("#")

		if c ~= nil then
			line = line:sub(1,c-1)
		end

		--see if this line even contians a value
		local equalSignIndex = line:find("=")
		if equalSignIndex ~= nil then
			
			local k = line:sub(1, equalSignIndex - 1)
			k = k:gsub(" ", "") --remove spaces in the key, they aren't required and will serve to make thigns more confusing.

			local v = line:sub(equalSignIndex + 1)

			v = load("return " ..  v)()
			
			cfg[k] = v
		end


		--get next line ready
		line = file:read("*line")
	end

	if cfg.Name then
		cfg.rawName = cfg.Name
		local s,e = cfg.Name:find("%^")
		while s ~= nil do

			if s ~= nil then
				cfg.Name = cfg.Name:sub(0,s-1) .. cfg.Name:sub(s+2)
			end
		
			s,e = cfg.Name:find("%^")
		end
	end

	return cfg
end

-- PRE: number, time in seconds is passed in, followed by boolean hours, boolean minutes, boolean seconds, boolean milliseconds.
--POST: the formatted time is output as a string.
function formatTime(time)
	time = math.floor((time * 1000) + 0.5)
	local milliseconds = time % 1000
	time = math.floor(time/1000)
	local seconds = time % 60
	time = math.floor(time/60)
	if seconds < 10 then
		seconds = "0" .. seconds
	end
	if time < 10 then
		time = "0" .. time
	end
	if milliseconds < 10 then
		milliseconds = "00" .. milliseconds
	elseif milliseconds < 100 then
		milliseconds = "0" .. milliseconds
	end

	return  time ..":".. seconds .. ":" .. milliseconds
end

M.copyFile = copyFile
M.exists = exists
M.isDir = isDir
M.getPathSplit = getPathSplit
M.createDirectory = createDirectory

M.readJson = readJson
M.writeJson = writeJson
M.readCfg = readCfg
M.parseVehData = parseVehData

return M
