local BUILD = 15
local PORT = 21496
local mixinRequire = [==[local __RSMIXINS=require(game:GetService"ReplicatedStorage".Mixins);local __RSMIXIN=function(a,b,c)if type(__RSMIXINS[a])=='function'then return __RSMIXINS[a](a,b,c)else return __RSMIXINS[a]end end
]==]
local mixinRequireOld = [==[local __RSMIXINS=require(game.ReplicatedStorage.Mixins);__RSMIXIN=function(a,b,c)if type(__RSMIXINS[a])=='function'then return __RSMIXINS[a](a,b,c)else return __RSMIXINS[a]end end
]==]
local moonBoilerplate = [==[-- RSync Boilerplate --
local function mixin(name, automatic)
	if (not automatic) and (name == "autoload" or name == "client" or name == "server") then
		error("RSync: Name \"" .. name .. "\" is a reserved name, and is automatically included in every applicable script.")
	end

	local ReplicatedStorage = game:GetService"ReplicatedStorage"
	if not ReplicatedStorage:FindFirstChild("Mixins") then
		return
	end

	if script.Name == "Mixins" and script.Parent == ReplicatedStorage then
		return
	end

	local mixins = require(ReplicatedStorage.Mixins)

	if type(mixins[name]) == "function" then
		return mixins[name](name, script, getfenv(2))
	else
		return mixins[name]
	end
end

mixin("autoload", true)
mixin(game:GetService"Players".LocalPlayer and "client" or "server", true)
-- End Boilerplate --
]==]
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")
local hookChanges, sendScript, doSelection, alertBox, alertActive, resetCache, checkMoonHelper
local justAdded, parseMixinsOut, parseMixinsIn, deleteScript, checkForPlaceName, placeNameAdded
local pmPath = "Documents\\ROBLOX\\RSync"
local scriptCache = { }
local sourceCache = { }
local gameGUID = HttpService:GenerateGUID()
local temp = true
local polling = false
local failed = 0
local mixinString = "__RSMIXIN('%1', script, getfenv())"
local mixinStringPattern = "__RSMIXIN%('([%w_]+)', script, getfenv%(%)%)"
local debug
debug = function(...)
  return print("[RSync build " .. tostring(BUILD) .. "] ", ...)
end
local alert
alert = function(...)
  debug(...)
  alertActive = tick()
  local text = ""
  local _list_0 = {
    ...
  }
  for _index_0 = 1, #_list_0 do
    local segment = _list_0[_index_0]
    text = text .. (segment .. " ")
  end
  text = text:sub(1, #text - 1)
  alertBox.Text = text
  alertBox.Visible = true
  local snapshot = alertActive
  return Spawn(function()
    wait(5)
    if snapshot == alertActive then
      alertBox.Visible = false
    end
  end)
end
parseMixinsOut = function(source)
  if not (ReplicatedStorage:FindFirstChild("Mixins") and ReplicatedStorage.Mixins:IsA("ModuleScript")) then
    return source
  end
  if source:sub(1, #mixinRequire) == mixinRequire then
    source = source:sub(#mixinRequire + 1)
  elseif source:sub(1, #mixinRequireOld) == mixinReqireOld then
    source = source:sub(#mixinRequireOld + 1)
  end
  source = source:gsub(mixinStringPattern, "@(%1)")
  return source
end
parseMixinsIn = function(source)
  if not (ReplicatedStorage:FindFirstChild("Mixins") and ReplicatedStorage.Mixins:IsA("ModuleScript")) then
    return source
  end
  if source:find("@%(([%w_]+)%)") then
    source = mixinRequire .. source
    source = source:gsub("@%(([%w_]+)%)", mixinString)
  end
  return source
end
hookChanges = function(obj)
  return obj.Changed:connect(function(prop)
    if obj == justAdded then
      justAdded = nil
      return 
    end
    local _exp_0 = prop
    if "Source" == _exp_0 then
      if obj:FindFirstChild("MoonScript") then
        return 
      end
      if sourceCache[obj] == obj.Source then
        sourceCache[obj] = nil
      else
        return sendScript(obj, false)
      end
    elseif "Parent" == _exp_0 or "Name" == _exp_0 then
      return deleteScript(obj)
    end
  end)
end
deleteScript = function(obj)
  if not (scriptCache[obj]) then
    return 
  end
  local data = {
    guid = scriptCache[obj]
  }
  scriptCache[scriptCache[obj]] = nil
  scriptCache[obj] = nil
  return pcall(function()
    HttpService:PostAsync("http://localhost:" .. tostring(PORT) .. "/delete", HttpService:JSONEncode(data), "ApplicationJson", false)
    return sendScript(obj, false)
  end)
end
sendScript = function(obj, open)
  if open == nil then
    open = true
  end
  if not (obj.Parent) then
    return 
  end
  local stack = { }
  local parent = obj.Parent
  while parent ~= game do
    table.insert(stack, 1, parent)
    parent = parent.Parent
  end
  local path = ""
  for _index_0 = 1, #stack do
    local ancestor = stack[_index_0]
    path = path .. (ancestor.Name .. "/")
  end
  if not scriptCache[obj] then
    scriptCache[obj] = HttpService:GenerateGUID(false)
    scriptCache[scriptCache[obj]] = obj
    hookChanges(obj)
  end
  local syntax, source
  if obj:FindFirstChild("MoonScript") and obj.MoonScript:IsA("StringValue") then
    syntax = "moon"
    source = obj.MoonScript.Value
  else
    syntax = "lua"
    source = parseMixinsOut(obj.Source)
  end
  local data = {
    path = path,
    syntax = syntax,
    source = source,
    temp = temp,
    name = obj.Name,
    class = obj.ClassName,
    place_name = gameGUID,
    guid = scriptCache[obj]
  }
  return pcall(function()
    return HttpService:PostAsync("http://localhost:" .. tostring(PORT) .. "/write/" .. tostring(open and 'open' or 'update'), HttpService:JSONEncode(data), "ApplicationJson", false)
  end)
end
resetCache = function()
  polling = false
  scriptCache = { }
  sourceCache = { }
  if temp then
    gameGUID = HttpService:GenerateGUID()
  end
  return debug("Resetting, if you restart the client you will need to reopen your scripts again, the files on disk will no longer be sent to this game instance as a result of the connection loss.")
end
local startPoll
startPoll = function()
  if polling then
    return 
  end
  polling = true
  return Spawn(function()
    while wait(0.14) do
      local success = pcall(function()
        local body = HttpService:GetAsync("http://localhost:" .. tostring(PORT) .. "/poll", true)
        local command = HttpService:JSONDecode(body)
        local _exp_0 = command.type
        if "update" == _exp_0 then
          if scriptCache[command.data.guid] then
            local obj = scriptCache[command.data.guid]
            local source
            if command.data.moon then
              source = moonBoilerplate .. command.data.source
            else
              source = parseMixinsIn(command.data.source)
            end
            sourceCache[scriptCache[command.data.guid]] = source
            obj.Source = source
            if command.data.moon and obj:FindFirstChild("MoonScript") and obj.MoonScript:IsA("StringValue") then
              obj.MoonScript.Value = command.data.moon
            end
          end
        elseif "output" == _exp_0 then
          if #command.data.text == 0 then
            return 
          end
          return debug(command.data.text)
        end
      end)
      if not (success) then
        failed = failed + 1
      end
      if success then
        failed = 0
      end
      if failed > 3 then
        resetCache()
        alert("Lost connection to the helper client, stopping.")
        break
      end
    end
  end)
end
local init
init = function(cb)
  local success, err = pcall(function()
    local data = HttpService:JSONDecode(HttpService:PostAsync("http://localhost:" .. tostring(PORT) .. "/new", HttpService:JSONEncode({
      place_name = gameGUID
    }), "ApplicationJson", false))
    if data.status == "OK" then
      if data.build == BUILD then
        pmPath = data.pm
        startPoll()
        return cb()
      else
        return alert("Plugin version does not match helper version, restart studio.")
      end
    else
      alert("Unhandled error, please check output.")
      return debug(data.error)
    end
  end)
  if not (success) then
    if err:find("Http requests are not enabled") then
      return alert("Set HttpService.HttpEnabled to true to use this feature.")
    elseif err:find("Couldn't connect to server") then
      return alert("Couldn't connect to helper client, did you start the executable?")
    else
      alert("Unhandled error, please check output.")
      return debug("An error occurred: " .. tostring(err))
    end
  end
end
local scan
scan = function()
  if not (polling) then
    return init(scan)
  end
  local lookIn
  lookIn = function(obj)
    local _list_0 = obj:GetChildren()
    for _index_0 = 1, #_list_0 do
      local child = _list_0[_index_0]
      if child:IsA("LuaSourceContainer") then
        sendScript(child, false)
      end
      lookIn(child)
    end
  end
  lookIn(game:GetService("Chat"))
  lookIn(game:GetService("Lighting"))
  lookIn(game:GetService("ReplicatedFirst"))
  lookIn(game:GetService("ReplicatedStorage"))
  lookIn(game:GetService("ServerScriptService"))
  lookIn(game:GetService("ServerStorage"))
  lookIn(game:GetService("StarterGui"))
  lookIn(game:GetService("StarterPack"))
  lookIn(game:GetService("StarterPlayer"))
  lookIn(game:GetService("Workspace"))
  game.DescendantAdded:connect(function(obj)
    return pcall(function()
      if obj:IsA("LuaSourceContainer") then
        justAdded = obj
        return sendScript(obj, false)
      end
    end)
  end)
  alert("All game scripts updated on filesystem, path in output")
  return debug("\\" .. tostring(pmPath) .. "\\" .. tostring(gameGUID) .. "\\")
end
doSelection = function()
  if not (polling) then
    return init(doSelection)
  end
  local selection = Selection:Get()
  if #selection == 0 then
    return alert("Select one or more scripts in the Explorer.")
  end
  local one = false
  for _index_0 = 1, #selection do
    local obj = selection[_index_0]
    if obj:IsA("LuaSourceContainer") then
      one = true
      checkMoonHelper(obj)
      sendScript(obj)
    end
  end
  if not (one) then
    return alert("Select one or more scripts in the Explorer.")
  end
end
checkMoonHelper = function(obj, force)
  if not (obj:IsA("LuaSourceContainer")) then
    return 
  end
  if obj:FindFirstChild("MoonScript") then
    return 
  end
  if #obj.Source > 100 then
    return 
  end
  local hasExt = obj.Name:sub(#obj.Name - 4, #obj.Name) == ".moon"
  if force or hasExt or obj.Source:lower() == "m" or obj.Source:lower() == "moon" or obj.Source:lower() == "moonscript" then
    do
      local _with_0 = Instance.new("StringValue", obj)
      _with_0.Name = "MoonScript"
      _with_0.Value = 'print "Hello", "from MoonScript", "Lua version: #{_VERSION}"'
    end
    if hasExt then
      obj.Name = obj.Name:sub(1, #obj.Name - 5)
    end
  end
end
checkForPlaceName = function(obj)
  if obj.Name == "PlaceName" and #obj.Value > 0 then
    resetCache()
    gameGUID = obj.Value
    temp = false
    return scan()
  end
end
placeNameAdded = function(obj)
  if obj:IsA("StringValue") then
    checkForPlaceName(obj)
    return obj.Changed:connect(function()
      return checkForPlaceName(obj)
    end)
  end
end
do
  alertBox = Instance.new("TextLabel")
  alertBox.Parent = Instance.new("ScreenGui", CoreGui)
  alertBox.Name = "RSync Alert"
  alertBox.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
  alertBox.TextColor3 = Color3.fromRGB(1, 1, 1)
  alertBox.BackgroundTransparency = 0
  alertBox.BorderColor3 = Color3.fromRGB(231, 76, 60)
  alertBox.BorderSizePixel = 30
  alertBox.Position = UDim2.new(0.5, -150, 0.5, -25)
  alertBox.Size = UDim2.new(0, 300, 0, 50)
  alertBox.ZIndex = 10
  alertBox.Font = "SourceSansLight"
  alertBox.TextSize = 24
  alertBox.Visible = false
  alertBox.TextWrapped = true
end
game:GetService("RunService").Heartbeat:Wait()
wait(0.5)
if (game:GetService("RunService"):IsStudio() and not game:GetService("RunService"):IsRunning()) and (game:GetService("RunService"):IsClient() and game:GetService("RunService"):IsServer()) then
  local toolbar = plugin:CreateToolbar("RSync")
  local button = toolbar:CreateButton("Open with Editor", "Open with system .lua editor (Ctrl+B)", "https://www.roblox.com/asset?id=478150446")
  button.Click:connect(doSelection)
  UserInputService.InputBegan:connect(function(input, gpe)
    if gpe then
      return 
    end
    if input.KeyCode == Enum.KeyCode.B and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
      if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
        local _list_0 = Selection:Get()
        for _index_0 = 1, #_list_0 do
          local obj = _list_0[_index_0]
          checkMoonHelper(obj, true)
        end
      end
      return doSelection()
    end
  end)
  local _list_0 = HttpService:GetChildren()
  for _index_0 = 1, #_list_0 do
    local obj = _list_0[_index_0]
    placeNameAdded(obj)
  end
  return HttpService.ChildAdded:connect(placeNameAdded)
end
