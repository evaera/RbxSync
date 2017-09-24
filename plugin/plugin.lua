local PORT = 21496
local BUILD = 100
local META_VERSION = 1
local API_URL = "http://localhost"
local LINK = "--*Sync"

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local SelectionService = game:GetService("Selection")

local IsConnectionEstablished = false
local PlaceId

function SplitString(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t={} ; i=1
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		t[i] = str
		i = i + 1
	end
	return t
end

function Alert(message)
	debug(message)
end

function debug(...)
	print("[RbxSync]", ...)
end

function Send(action, data)
	if not IsConnectionEstablished and action ~= "new" then
		if not EstablishConnection() then
			return
		end
	end

	local response
	local url = API_URL .. ":" .. PORT .. "/" .. action

	if PlaceId then
		url = url .. "/" .. PlaceId
	end

	local success, errorMessage = pcall(function()
		if not data then
			response = HttpService:GetAsync(url, true)
		else
			response = HttpService:PostAsync(url, HttpService:JSONEncode(data), Enum.HttpContentType.ApplicationJson, false)
		end
	end)

	if success then
		print('r', response)
		local json 
		pcall(function()
			json = HttpService:JSONDecode(response)
		end)

		return json
	else
		if errorMessage:find("Http requests are not enabled") then
			Alert("Set HttpServioce.HttpEnabled to true to use this feature.")
		elseif errorMessage:find("Couldn't connect to server") then
			Alert("Couldn't connect to the RbxSync executable, please ensure it is running.")
		else
			Alert("An unknown error has occurred, check output")
			debug(errorMessage)
		end

		Disconnect()
	end
end

function StartPolling()
	spawn(function()
		while IsConnectionEstablished do
			local data = Send("get")

			if not data then
				break
			end

			wait(0.1)
		end
	end)
end

function Disconnect()
	IsConnectionEstablished = false
	PlaceId = nil
end

function EstablishConnection()
	local data = Send("new")

	if not data then
		Alert("An error occurred while establishing connection")
		return false
	end

	if data.build == BUILD then
		PlaceId = data.placeId
		IsConnectionEstablished = true
		StartPolling()
		return true
	else
		Alert("Plugin version does not match helper version, restart Studio.")
		return false
	end
end

function GetMetadata(object)
	local lines = SplitString(object.Source, "\n")
	local meta

	if lines[1] and lines[1]:sub(1, #LINK) == LINK then
		meta = SplitString(lines[1]:sub(#LINK + 1), ":")
	end

	return meta
end

function StripMetadata(object)
	local lines = SplitString(object.Source, "\n")

	if lines[1] and lines[1]:sub(1, #LINK) == LINK then
		table.remove(lines, 1)
	end

	return table.concat(lines, "\n")
end

function AttachMetadata(object)
	local currentMetadata = GetMetadata(object)
	local guid

	if currentMetadata then
		guid = currentMetadata[2]
	else
		guid = "r$" .. HttpService:GenerateGUID(false)
	end

	object.Source = LINK .. ":" .. META_VERSION .. ":" .. guid .. ":" .. object:GetFullName() .. "\n" .. StripMetadata(object)

	return guid, object:GetFullName()
end

function SendScript(object, open)
	local action = open and "write/open" or "write/file"

	local guid, fullName = AttachMetadata(object)

	Send(action, {
		id = guid,
		path = fullName,
		source = object.Source
	})
end

function OpenSelection()
	for _, object in pairs(SelectionService:Get()) do
		if object:IsA("LuaSourceContainer") then
			SendScript(object, true)
		end
	end
end

function Initialize()
	wait(0.5)

	if RunService:IsStudio() and not RunService:IsRunning() and (RunService:IsClient() and RunService:IsServer()) then
		local toolbar = plugin:CreateToolbar("RbxSync")
		local button = toolbar:CreateButton("Open with Editor", "Open with system .lua editor (Crl+B)", "https://www.roblox.com/asset?id=478150446")

		button.Click:Connect(OpenSelection)
	end
end

Initialize()