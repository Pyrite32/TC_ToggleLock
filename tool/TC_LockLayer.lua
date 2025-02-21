-- **************************************************
-- Provide Moho with the name of this script object
-- **************************************************

ScriptName = "TC_LockLayer"

-- **************************************************
-- General information about this script
-- **************************************************

function TC_LockLayer:Name()
	return 'TC_LockLayer'
end

function TC_LockLayer:Version()
	return '1.0'
end

function TC_LockLayer:UILabel()
	return 'Lock Layer'
end

function TC_LockLayer:Creator()
	return 'Patrick Keefe, A.K.A Tetrachroma'
end

function TC_LockLayer:Description()
	return 'Moho lets you lock layers (secretly with scripting). It\'s time to break the secret!'
end


TC_LockLayer = {}

TC_LockLayer.CHOICE_PLACE_HOOK = 0
TC_LockLayer.CHOICE_CANCEL = 1
TC_LockLayer.CHOICE_DISABLE_HOOKS = 2

TC_LockLayer.LOCK_PREF_UNDECIDED = 0
TC_LockLayer.LOCK_PREF_USE_HOOK = 1
TC_LockLayer.LOCK_PREF_NO_HOOK = 2
TC_LockLayer.HOOK_SCRIPT_NAME = '.TC_ToggleLock.hook.lua'
TC_LockLayer.HOOK_PREF_FILE_NAME = '.TC_ToggleLock.config.txt'

---@type MOHO.MohoLayer
TC_LockLayer.hookReference = nil

TC_LockLayer.lockHookPreference = TC_LockLayer.LOCK_PREF_UNDECIDED

TC_LockLayer.LOCK_EMOJI = '🔒'
TC_LockLayer.SCRIPT_EMOJI = '📜'

TC_LockLayer.didInitializeEverything = false
TC_LockLayer.warnedNonexistentHook = false
TC_LockLayer.pathToLockFile = ''
TC_LockLayer.pathToConfigFile = ''

TC_LockLayer.hookConfigFileTemplate = [[
# Say you opted out of using the lock hook for this document, but want it back, or vice-versa.
# By changing the below value (true/false), you may choose to either include lock hooks (meaning at least one layer must have the lock hook layer script bound), or not (renamed files may not accurately reflect the layer lock status)
# Make sure to reload scripts after doing so (Ctrl/⌘+Alt+Shift+L by default)
use_lock_hook=%s
]]

TC_LockLayer.scriptPrefixDefSource = [[
function DecorateNameScript(activeLayer)
	--META/TC_HOOK/INJECT/HOOK_PATHS
	--META/TC_HOOK/INJECT/SCRIPT_ICON_STRING
	local activeLayerName = activeLayer:Name()
	local hasHook = false
	local scriptPath = activeLayer:LayerScript()
	if scriptPath ~= '' then	
		for k, v in ipairs(HOOK_PATHS) do
			if scriptPath == v then
				hasHook = true
				break
			end
		end
	end
	
	local foundScriptStr = activeLayerName:len() >= SCRIPT_ICON_STRING:len() and activeLayerName:find(SCRIPT_ICON_STRING) ~= nil
	if hasHook and not foundScriptStr then
		activeLayer:SetName(SCRIPT_ICON_STRING .. activeLayerName)
	elseif not hasHook and foundScriptStr then
		activeLayer:SetName(activeLayerName:gsub(SCRIPT_ICON_STRING, ''))
	end
end
]]

TC_LockLayer.lockPrefixDefSource = [[
function DecorateNameLock(activeLayer)
	--META/TC_HOOK/INJECT/LOCK_ICON_STRING
	local selLayerIsLocked = activeLayer:IsLocked()
	local activeLayerName = activeLayer:Name()
	local foundLockStr = activeLayerName:len() >= LOCK_ICON_STRING:len() and activeLayerName:find(LOCK_ICON_STRING) ~= nil
	if selLayerIsLocked and not foundLockStr then
		activeLayer:SetName(LOCK_ICON_STRING .. activeLayerName)
	elseif not selLayerIsLocked and foundLockStr then
		activeLayer:SetName(activeLayerName:gsub(LOCK_ICON_STRING, ''))
	end
end
]]

local a = "C:\\Users\\patri\\Art\\MohoCustomFolder\\MohoWorkspace\\me-guides\\.TC_ToggleLock__Hook.lua"

TC_LockLayer.hookPreludeSource = [[
--META/TC_HOOK/VER: 1.0

-- Auto-generated with the --META/TC_HOOK/ORIGIN script.
-- DO NOT MODIFY OR DELETE THIS SCRIPT
function LayerScript(moho)
	if moho.document == nil then return end
	local currentLayer = moho.document:GetSelectedLayer(0)
	if currentLayer == nil then return end
	
	if LastSelLayer ~= nil and LastSelLayer == currentLayer then
		return
	end

	for i = 0, moho.document:CountSelectedLayers() - 1 do
		local activeLayer = moho.document:GetSelectedLayer(i)
		if activeLayer then
			--META/TC_HOOK/SEL_LAYER_PASS
		end
	end
	if (LastSelLayer ~= nil) then
		--META/TC_HOOK/PREV_SEL_LAYER_PASS
	end
	LastSelLayer = currentLayer
end

--META/TC_HOOK/HOOK_DEFS

]]


-- **************************************************
-- Preferences
-- **************************************************

---@param preferences MOHO.ScriptPrefs
function TC_LockLayer:SavePrefs(preferences)
	-- preferences:SetInt(TC_LockLayer:Name() .. ".lockHookPreference", TC_LockLayer.lockHookPreference)
end

---@param preferences MOHO.ScriptPrefs
function TC_LockLayer:LoadPrefs(preferences)
	-- savePrefs
	-- TC_LockLayer.lockHookPreference = preferences:GetInt(TC_LockLayer:Name() .. ".lockHookPreference",
	-- 	TC_LockLayer.LOCK_PREF_UNSET)
	-- -- print("lhp: " .. TC_LockLayer.lockHookPreference )
end

-- **************************************************
-- Is Relevant / Is Enabled
-- **************************************************

function TC_LockLayer:IsRelevant(moho)
	return true
end

function TC_LockLayer:IsEnabled(moho)
	return true
end

-- **************************************************
-- The guts of this script
-- **************************************************

---@param api MOHO.ScriptInterface
function TC_LockLayer:Run(api)
	-- print(TC_LockLayer.lockHookPreference)

	if not api.document then
		return
	end

	-- optional code that runs when a hook is attached, but never if the user doesn't want to use hooks.
	if TC_LockLayer.lockHookPreference ~= TC_LockLayer.LOCK_PREF_NO_HOOK and TC_LockLayer:TryInitializeHook(api) then
		if not api.layer then
			LM.GUI.Alert(LM.GUI.ALERT_WARNING,
				"No layer(s) selected. Please select one or more layers in order to toggle locking.")
			return
		end

		---@type int?
		local replaceReferenceChoice = nil

		if TC_LockLayer.lockHookPreference == TC_LockLayer.LOCK_PREF_UNDECIDED then
			replaceReferenceChoice = TC_LockLayer:GetShouldUseHookUserChoice(
			"This tool works best if you attach a lock hook.")
		elseif TC_LockLayer.lockHookPreference == TC_LockLayer.LOCK_PREF_USE_HOOK then
			if TC_LockLayer.hookReference == nil then
				if not TC_LockLayer:RefreshHook(api) then
					replaceReferenceChoice = TC_LockLayer:GetShouldUseHookUserChoice("No lock hook references found.")
				end
			elseif not api.document:IsLayerValid(TC_LockLayer.hookReference) then
				-- refresh references to find a new hook.
				if not TC_LockLayer:RefreshHook(api) then
					replaceReferenceChoice = TC_LockLayer:GetShouldUseHookUserChoice(
					"The layer containing the last-remaining lock hook was deleted.")
				end
			elseif TC_LockLayer.hookReference:LayerScript() ~= TC_LockLayer.pathToLockFile then
				local message = TC_LockLayer.hookReference == nil
					and "The document's lock hook was deleted by the user."
					or "The lock hook on layer "
						.. TC_LockLayer.hookReference:Name() ..
						" was deleted by the user."
				if TC_LockLayer.hookReference ~= nil then
					-- handle automatically removing the script icon for you
					TC_LockLayer.hookReference:SetName(TC_LockLayer.hookReference:Name():gsub(TC_LockLayer:ScriptIconString(), ''))
				end
				if not TC_LockLayer:RefreshHook(api) then
					replaceReferenceChoice = TC_LockLayer:GetShouldUseHookUserChoice(message)
				end
			end
		end

		if replaceReferenceChoice ~= nil then
			TC_LockLayer.hookReference = nil
			TC_LockLayer:ExecuteUseHookDecision(api, replaceReferenceChoice)
			-- Do not lock the layer if it is being hooked.
			return
		end
	end
	api.document:SetDirty()
	api.document:PrepUndo(api.layer)

	-- If first layer in the selection is locked, unlock everything
	-- otherwise, lock everything
	local cascadeShouldLock = nil

	for i = 0, api.document:CountSelectedLayers() - 1 do
		local selLayer = api.document:GetSelectedLayer(i)
		if selLayer then
			if cascadeShouldLock == nil then
				cascadeShouldLock = not selLayer:IsLocked()
			end
			if cascadeShouldLock then
				TC_LockLayer:LockLayer(selLayer)
			else
				TC_LockLayer:UnlockLayer(selLayer)
			end
		end
	end
end

--- https://stackoverflow.com/questions/1340230/check-if-directory-exists-in-lua
--- Check if a file or directory exists in this path
function TC_LockLayer:PathExists(file)
	local ok, err, code = os.rename(file, file)
	if not ok then
		if code == 13 then
			-- Permission denied, but it exists
			return true
		end
	end
	return ok, err
end

-- Initializes a directory to hold the global lock workflow script
-- lock workflow scripts will ensure the lock symbol is kept even if the file is renamed.
-- return
-- **************************************************
---comment
---@param api MOHO.ScriptInterface
---@return boolean
function TC_LockLayer:TryInitializeHook(api)
	-- print("try init all!")
	if TC_LockLayer.didInitializeEverything then
		-- print("already initialized!")
		return true
	end

	local didWriteConfig, didWriteHook = false, false

	if api.document == nil then
		-- print("doc is nill!")
		return false
	end

	local pathToHookSource = TC_LockLayer:GetPathToHookScript(api.document)
	if pathToHookSource == '' then
		local choice = LM.GUI.Alert(LM.GUI.ALERT_WARNING,
			"Cannot attach lock hook, because the filename for this document has not been set.",
			"When locking layers with this script, a lock character \'" ..
			TC_LockLayer.LOCK_EMOJI ..
			"\' is inserted into the name. The lock hook is optional; It is a layer script that ensures that renamed layers have the " ..
			TC_LockLayer.LOCK_EMOJI .. " added back to their name.",
			"Do you want to use a lock hook?",
			"Yes (Choose file name...)",
			"No",
			"Decide Later"
		);
		if choice == 0 then --yes
			TC_LockLayer.lockHookPreference = TC_LockLayer.LOCK_PREF_USE_HOOK
			api:FileSave()
			pathToHookSource = TC_LockLayer:GetPathToHookScript(api.document)
			if pathToHookSource == '' then
				LM.GUI.Alert(LM.GUI.ALERT_WARNING, "Cancelled hook setup, because user cancelled saving.")
				return false
			end
		elseif choice == 1 then --no
			TC_LockLayer.lockHookPreference = TC_LockLayer.LOCK_PREF_NO_HOOK
			return false
		else -- decide later
			TC_LockLayer.lockHookPreference = TC_LockLayer.LOCK_PREF_UNDECIDED
			return false
		end
	end

	
	if TC_LockLayer:PathExists(TC_LockLayer:GetPathToConfigFile(api.document)) then
		-- print("config path exists!")
		TC_LockLayer.lockHookPreference = TC_LockLayer:ParseConfigFile()
				and TC_LockLayer.LOCK_PREF_USE_HOOK
				or  TC_LockLayer.LOCK_PREF_NO_HOOK
		didWriteConfig = true
	else
		-- write configuration
		-- print("config path does not exist!")
		if TC_LockLayer.lockHookPreference == TC_LockLayer.LOCK_PREF_UNDECIDED then
			local choice = LM.GUI.Alert(LM.GUI.ALERT_QUESTION,
				"About this script, and the Lock Hook:",
				"When locking layers with this script, a lock character \'" ..
				TC_LockLayer.LOCK_EMOJI ..
				"\' is inserted into the name. The lock hook is optional; It is a layer script that ensures that renamed layers have the " ..
				TC_LockLayer.LOCK_EMOJI .. " added back to their name.",
				"\nDo you want to use a lock hook in this document? (You can change your mind later by editing " .. TC_LockLayer.HOOK_PREF_FILE_NAME .. " in your project's directory).",
				"Yes",
				"No"
			);
			TC_LockLayer.lockHookPreference = choice == 0 and TC_LockLayer.LOCK_PREF_USE_HOOK or TC_LockLayer.LOCK_PREF_NO_HOOK
			TC_LockLayer:WritePreferenceToConfig(api)
		end
	end

	
	if TC_LockLayer:PathExists(pathToHookSource) then
		-- print("hook source exist!")
		-- -- print('hook exists (I think) at: ' .. pathToHookSource)
		TC_LockLayer.pathToLockFile = pathToHookSource
		-- if the hook code is here, chances are, it will be attached somewhere.
		TC_LockLayer:RefreshHook(api)
		didWriteHook = true
	else
		-- print("hook source not exist!")
		-- -- print("hook source location: " .. pathToHookSource)
		local file, err = io.open(pathToHookSource, "w")
		if file ~= nil then
			local declVarFormatStr = "local %s = \"%s\""
			local declVarFormatTableVars = "local %s = {%s}"

			local hookPathsDecl = string.format(declVarFormatTableVars, "HOOK_PATHS",
				'"' .. pathToHookSource:gsub("\\", "\\\\") .. '"')
			local lockIconDecl = string.format(declVarFormatStr, "LOCK_ICON_STRING", TC_LockLayer:LockIconString())
			local scriptIconDecl = string.format(declVarFormatStr, "SCRIPT_ICON_STRING",
				TC_LockLayer:ScriptIconString())

			--TODO: Stop throwing away so many strings
			TC_LockLayer.scriptPrefixDefSource =
				TC_LockLayer.scriptPrefixDefSource
				:gsub("--META/TC_HOOK/INJECT/HOOK_PATHS", hookPathsDecl)
				:gsub("--META/TC_HOOK/INJECT/SCRIPT_ICON_STRING", scriptIconDecl)
			TC_LockLayer.lockPrefixDefSource =
				TC_LockLayer.lockPrefixDefSource
				:gsub("--META/TC_HOOK/INJECT/LOCK_ICON_STRING", lockIconDecl)
			local layerPassCallbacks = {
				"DecorateNameLock",
				"DecorateNameScript"
			}

			local selLayerPassCallsStr = ""
			for index, value in ipairs(layerPassCallbacks) do
				selLayerPassCallsStr = selLayerPassCallsStr
					.. string.format("%s(activeLayer)\n\t\t", value)
			end

			local lastLayerPassCallsStr = ""
			for index, value in ipairs(layerPassCallbacks) do
				lastLayerPassCallsStr = lastLayerPassCallsStr
					.. string.format("%s(LastSelLayer)\n\t\t", value)
			end

			TC_LockLayer.hookPreludeSource =
				TC_LockLayer.hookPreludeSource
				:gsub("--META/TC_HOOK/ORIGIN", TC_LockLayer:Name())
				:gsub("--META/TC_HOOK/SEL_LAYER_PASS", selLayerPassCallsStr)
				:gsub("--META/TC_HOOK/PREV_SEL_LAYER_PASS", lastLayerPassCallsStr)
				:gsub("--META/TC_HOOK/HOOK_DEFS",
					TC_LockLayer.lockPrefixDefSource
					.. TC_LockLayer.scriptPrefixDefSource
				)

			file:write(TC_LockLayer.hookPreludeSource)
			file:close()
			didWriteHook = true
		else
			if pathToHookSource == '' then
				pathToHookSource = '<empty path>'
			end
			LM.GUI.Alert(LM.GUI.ALERT_WARNING, "error initializing TC_ToggleLock: ", err or "failed to create hook file!",
				"tried to open path: " .. pathToHookSource)
			return false
		end
	end
	-- print("end here")
	TC_LockLayer.didInitializeEverything = didWriteHook and didWriteConfig 
	-- print("initted all is equal to: " .. tostring(TC_LockLayer.didInitializeEverything))
	-- print("wrote cfg: " .. tostring(didWriteConfig))
	-- print("wrote hook: " .. tostring(didWriteHook))
	return TC_LockLayer.didInitializeEverything
end

---@param api MOHO.ScriptInterface
---@return boolean hookRefreshSuccessful
function TC_LockLayer:RefreshHook(api)
	if TC_LockLayer.pathToLockFile == '' then
		return false
	end

	---@type MOHO.MohoLayer?
	local hookRef = nil

	local index = 0
	-- acquire the reference to the layer script if it exists.
	-- and also remove additional hooks.
	repeat
		local layer = api.document:LayerByAbsoluteID(index)
		if layer then
			index = index + 1
			local layerScriptPath = layer:LayerScript()
			if layerScriptPath == TC_LockLayer.pathToLockFile then
				if not hookRef then
					hookRef = layer
				else
					TC_LockLayer:UnhookLayer(layer)
				end
			end
		end
	until not layer

	TC_LockLayer.hookReference = hookRef
	
	-- Let the user decide.

	-- if TC_LockLayer.hookReference ~= nil then
	-- 	TC_LockLayer.lockHookPreference = TC_LockLayer.LOCK_PREF_USE_HOOK
	-- end
	return hookRef ~= nil
end

---@param what MOHO.MohoLayer
function TC_LockLayer:UnhookLayer(what)
	-- FIXME: When combining multiple hooks, instead of clearing, concatenate them.
	-- print("unhooked " .. what:Name())
	what:SetLayerScript('')
	local nameWithoutScriptEmoji = what:Name():gsub(TC_LockLayer:ScriptIconString(), '')
	what:SetName(nameWithoutScriptEmoji)
end

---@param document? MOHO.MohoDoc
---@return string path
function TC_LockLayer:GetPathToHookScript(document)
	if TC_LockLayer.pathToLockFile ~= '' then
		return TC_LockLayer.pathToLockFile
	else
		local result = TC_LockLayer:GetPathToLocalFile(document, TC_LockLayer.HOOK_SCRIPT_NAME) 
		TC_LockLayer.pathToLockFile = result
		return result
	end
end

---@param document? MOHO.MohoDoc
---@return string path
function TC_LockLayer:GetPathToConfigFile(document)
	if TC_LockLayer.pathToConfigFile ~= '' then
		return TC_LockLayer.pathToConfigFile
	else
		local result = TC_LockLayer:GetPathToLocalFile(document, TC_LockLayer.HOOK_PREF_FILE_NAME) 
		TC_LockLayer.pathToConfigFile = result
		return result
	end
end

---@param document? MOHO.MohoDoc
---@param filename string
---@return string path
function TC_LockLayer:GetPathToLocalFile(document, filename)
	if document ~= nil then
		local fullPath = document:Path()
		if fullPath == '' then
			return ''
		else
			local lastSlashLocation = fullPath:reverse():find("\\")
			local directoryPath = fullPath:sub(0, fullPath:len() - lastSlashLocation)
			return directoryPath .. "\\" .. filename
		end
	else
		LM.GUI.Alert(LM.GUI.ALERT_WARNING, "An error occurred whilst executing this script. Try again.")
		return ''
	end
end

-- ---@param where MOHO.MohoLayer
-- ---@return MOHO.MohoLayer? victim
-- ---@return string? failMsg
-- function TC_LockLayer:HookOntoLayerAncestor(where)
-- 	if not where then return nil, "Layer not selected." end

-- 	local parent = where:Parent()
-- 	if not parent then
-- 		return TC_LockLayer:HookOntoLayer(where)
-- 	else
-- 		local parentParent = parent:Parent()
-- 		while parentParent ~= nil do
-- 			parent = parentParent
-- 			parentParent = parentParent:Parent()
-- 		end
-- 		return TC_LockLayer:HookOntoLayer(parent)
-- 	end
-- end

---@param where MOHO.MohoLayer
---@return MOHO.MohoLayer? victim
---@return string? failMsg
function TC_LockLayer:HookOntoLayer(where)
	if not where then return nil, "Layer not found." end

	local scriptPath = where:LayerScript()
	if scriptPath ~= '' then
		return nil, "Layer already has script bound. Remove it, or pick another layer."
	end

	local path = TC_LockLayer:GetPathToHookScript(nil)
	if path == '' then return nil, "Please try again." end

	local succ, failMsg = pcall(MOHO.MohoLayer.SetLayerScript, where, path )

	if succ then
		-- decorate layer name
		local scriptIconStr = TC_LockLayer:ScriptIconString()
		local layerName = where:Name():gsub(scriptIconStr, '')
		layerName = scriptIconStr .. layerName
		where:SetName(layerName)
	else
		failMsg = "Internal Error:" .. failMsg
	end

	return where
end

function TC_LockLayer:LockIconString()
	return string.format("%s ", TC_LockLayer.LOCK_EMOJI)
end

function TC_LockLayer:ScriptIconString()
	return string.format("%s ", TC_LockLayer.SCRIPT_EMOJI)
end

---@param what MOHO.MohoLayer
function TC_LockLayer:LockLayer(what)
	-- -- print("lock")

	if not what then
		LM.GUI.Alert(LM.GUI.ALERT_WARNING, "Failed to lock layer", "The specified layer does not exist.")
		return
	end

	what:SetLocked(true)
	what:SetIgnoredByLayerPicker(true)
	-- prevent more than one lock symbol from being attached to the name.
	local newName = TC_LockLayer:LockIconString() .. (what:Name():gsub(TC_LockLayer:LockIconString(), ''))
	what:SetName(newName)
end

---@param what MOHO.MohoLayer
function TC_LockLayer:UnlockLayer(what)
	-- -- print("unlock")

	if not what then
		LM.GUI.Alert(LM.GUI.ALERT_WARNING, "Failed to unlock layer", "The specified layer does not exist.")
		return
	end

	what:SetLocked(false)
	what:SetIgnoredByLayerPicker(false)

	local newName = what:Name():gsub(TC_LockLayer:LockIconString(), '')
	what:SetName(newName)
end

---@param contextMsg string
function TC_LockLayer:GetShouldUseHookUserChoice(contextMsg)
	local familiarWithDescription = TC_LockLayer.lockHookPreference ~= TC_LockLayer.LOCK_PREF_UNDECIDED
	local descriptionString = "When locking layers with this script, a lock character \'" ..
	TC_LockLayer.LOCK_EMOJI ..
	"\' is inserted into the name. The lock hook is optional; It is a layer script that ensures that renamed layers have the " ..
	TC_LockLayer.LOCK_EMOJI .. " added back to their name."
	if familiarWithDescription then
		descriptionString = ''
	end

	local butChoice = LM.GUI.Alert(
		LM.GUI.ALERT_QUESTION,
		contextMsg,
		descriptionString,
		"Would you like to install a hook on this layer?",
		"Yes, This Layer",
		"No, Cancel",
		"No, Disable Hooks"
	)

	if butChoice == 0 then return TC_LockLayer.CHOICE_PLACE_HOOK end
	if butChoice == 1 then return TC_LockLayer.CHOICE_CANCEL end
	if butChoice == 2 then return TC_LockLayer.CHOICE_DISABLE_HOOKS end
end

---@param api MOHO.ScriptInterface
---@param userChoice integer
function TC_LockLayer:ExecuteUseHookDecision(api, userChoice)
	---@type MOHO.MohoLayer?
	local result
	---@type string?
	local failMsg

	if not TC_LockLayer:TryInitializeHook(api) then
		return
	end

	local targetPref = TC_LockLayer.LOCK_PREF_UNDECIDED
	if userChoice == TC_LockLayer.CHOICE_PLACE_HOOK then
		targetPref = TC_LockLayer.LOCK_PREF_USE_HOOK
		result, failMsg = TC_LockLayer:HookOntoLayer(api.layer)
	elseif userChoice == TC_LockLayer.CHOICE_CANCEL then
		return
	elseif userChoice == TC_LockLayer.CHOICE_DISABLE_HOOKS then
		TC_LockLayer.lockHookPreference = TC_LockLayer.LOCK_PREF_NO_HOOK
		TC_LockLayer:WritePreferenceToConfig(api)
		return
	else
		LM.GUI.Alert(LM.GUI.ALERT_WARNING, "Selected choice out of range!")
	end

	if result then
		TC_LockLayer.lockHookPreference = targetPref
	else
		LM.GUI.Alert(LM.GUI.ALERT_WARNING, failMsg or 'Unknown error!')
	end

	TC_LockLayer.hookReference = result
end

---@return boolean useHooks
function TC_LockLayer:ParseConfigFile()
	if TC_LockLayer.pathToConfigFile == '' then
		LM.GUI.Alert(LM.GUI.ALERT_WARNING, "Could not parse configuration!", "no path to config.")
		return false
	end
	local f, errMsg = io.open(TC_LockLayer.pathToConfigFile, "r")
	if f then
		---@type string
		local fileContents = f:read("a")
		f:close()
		local configKeyIdxStart, configKeyIdxEnd = fileContents:find('use_lock_hook=')
		if configKeyIdxStart == nil then
			LM.GUI.Alert(LM.GUI.ALERT_WARNING, "Could not parse configuration!",
				"could not find key 'use_lock_hook=' in config file. (case-sensitive)")
		end

		local configVal = fileContents:sub(configKeyIdxEnd + 1, configKeyIdxEnd + 6):lower():gsub(' ', ''):gsub('\n', ''):gsub('\t', '')
		if configVal == "true" then
			-- print("config true")
			return true
		elseif configVal == "false" then
			-- print("config false")
			return false
		else
			LM.GUI.Alert(LM.GUI.ALERT_WARNING, "ERROR, invalid config value", "[" .. configVal .. "]")
			return false
		end
	end
	return false
end

---@param api MOHO.ScriptInterface
function TC_LockLayer:WritePreferenceToConfig(api)
	if api.document == nil then
		return
	end

	local pathToConfig = TC_LockLayer:GetPathToConfigFile(api.document)
	if pathToConfig == '' then
		return
	end

	local f, err = io.open(pathToConfig, "w")
	if f ~= nil then
		local configValue = TC_LockLayer.lockHookPreference == TC_LockLayer.LOCK_PREF_USE_HOOK 
			and 'true'
			or 'false'
		local content = string.format(TC_LockLayer.hookConfigFileTemplate, configValue)
		f:write(content)
		f:close()
	else
		if pathToConfig == '' then
			pathToConfig = '<empty path>'
		end
		LM.GUI.Alert(LM.GUI.ALERT_WARNING, "error initializing TC_ToggleLock: ", err or "failed to create hook file!",
			"tried to open config path: " .. pathToConfig)
		return false
	end
end

-- This is causing issues at startup
-- because creating a script interface too early in Moho's lifetime will cause Moho to crash every time.

-- function TC_LockLayer:__Main__()
-- 	local helper = MOHO.ScriptInterfaceHelper:new_local()
-- 	local moho = helper:MohoObject()
-- 	-- check for config file.
-- 	if moho.document ~= nil then
-- 		local document = moho.document
-- 		local filepathToSearchFor = TC_LockLayer:GetPathToConfigFile(document)
-- 		if TC_LockLayer:PathExists(filepathToSearchFor) then
-- 			TC_LockLayer.lockHookPreference = TC_LockLayer:ParseConfigFile()
-- 				and TC_LockLayer.LOCK_PREF_USE_HOOK
-- 				or  TC_LockLayer.LOCK_PREF_NO_HOOK
-- 		else
-- 			TC_LockLayer.lockHookPreference = TC_LockLayer.LOCK_PREF_UNSET
-- 		end
-- 	end
-- 	helper:delete()
-- end

-- TC_LockLayer:__Main__()
