# RSync - Third party IDE support for ROBLOX Studio in one click
RSync is an open source ROBLOX plugin that easily integrates any third-party code editor or IDE, such as Sublime Text, Notepad++, VS Code, or Atom, into ROBLOX Studio. This is accomplished via a helper application which runs in the tray and acts as a middle man between your code editor of choice and ROBLOX Studio. 

![Tray example](https://i.imgur.com/lqhr2sx.png)
![Demo Gif](https://i.imgur.com/z9oeWaF.gif)

## Download
Available in the [releases section.](https://github.com/evaera/RSync/releases/latest)

## Installation 
RSync is designed with simplicity in mind: just download the executable and run it, and it will automatically install the plugin into ROBLOX Studio. Just let the application run in the tray while you're developing. 

Files will open with your system default `.lua` editor.

RSync is designed to work on Windows only.

**Note**: If you already have Studio open when you run the application for the first time, you will need to restart Studio for the plugin to load.

## Features
### Persistent Mode / Git Mode
By default, RSync will use a temporary folder, but using a persistent directory is also supported. This will cause the plugin to write *all* scripts to disk (nested with folders that match in-game hierarchy), even ones you don't explicitly open. The plugin will keep the scripts up to date on disk, even through `Parent` or `Name` changes. If you delete the script from your game, it will also be deleted on disk. If two objects have the same name and parent, one of them will be appended with `(2)` at the end of its name. Try to avoid this.

This allows you to create a Git repository for all the scripts in your game super easily.

To enable this feature, create a `StringValue` in `HttpService` named `PlaceName`, and then set the value to the name you'd like the folder to use. The scripts will then be written to `C:\Users\<current user>\Documents\ROBLOX\RSync\<Place Name>`. **Note**: You must re-open your game in Studio after you create this value. And, make sure you turned `HttpEnabled` on!

![PMode Demo](http://i.imgur.com/3U2x9xr.png)

### Mixins
Mixins allow you to use the syntax `@(mixin_name)` in your scripts, which will return any values you set in the Mixins module. To use this feature, create a *ModuleScript* in *ReplicatedStorage* named `Mixins`. 

The module should return a table with string indexes for your mixin names. The values can be any type, but if they are a function, the function will be executed, given the arguments `(mixin_name, script, function\_environment)`. 

- `mixin_name`: The name of the mixin, e.g. what is `@(here)`.
- `script`: The Script object that is using the mixin
- `function_environment`: The result of `getfenv` in the function where the mixin is used

**Example `Mixins` script**: 
```lua
return {
	hello = "Hi there!";
	require_all_children = function(mixin, script, env)
		for _, child in pairs(script:GetChildren()) do
			if child:IsA("ModuleScript") then
				require(child)
			end
		end
	end;
}
```

Then, anywhere in another script:

```lua
@(require_all_children)

print(@(hello))
```

This actually compiles to:

```lua
local __RSMIXINS=require(game.ReplicatedStorage.Mixins);__RSMIXIN=function(a,b,c)if type(__RSMIXINS[a])=='function'then return __RSMIXINS[a](a,b,c)else return __RSMIXINS[a]end end

__RSMIXIN('require_all_children', script, getfenv())

print(__RSMIXIN('hello', script, getfenv()))
```

### MoonScript Support
If you have MoonScript installed on your computer (have [`moonc`](http://moonscript.org/) in your PATH), RSync can automatically compile your scripts into Lua every time you save them and instantly push them to your game in Studio.

**Note**: MoonScript mode is experimental and may not be stable. Additionaly, the mixins feature is not compatible with scripts in MoonScript mode.

**To put a script in MoonScript mode**, there must be a StringValue named "MoonScript" inside of it. The plugin provides several shortcuts so you don't have to do this manually:
- If you put `.moon` at the end of your script name (e.g. `KillScript.moon`, then press the *Open in Editor* button. It will remove the `.moon` from the name after it's created the value.
- If the script source contains `m`, `moon`, or `moonscript` exactly, when you press the *Open in Editor* button, it will also put the script in MoonScript mode.
- Use the hotkey `Ctrl+Alt+B` with a script selected.

## Building it yourself
The ROBLOX Studio plugin must be built before RSync will work, **even for development**. The build script will automatically copy the information from `/src/config.json` into *plugin.moon*, so that it always stays up to date with the config info.

### Prerequisites 
- `npm install -g electron-packager`
- `npm install -g coffee-script`
- You must have [`moonc`](http://moonscript.org/) in your PATH.

### Building the Plugin
Run `cake build:plugin`

### Building the entire app
Run `cake build:app`
