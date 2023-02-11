------------------------------------------------------------------------------------------------------------------------------
--
--	***************** GLOBAL QUEST SYSTEM BEHAVIOR *****************
--
--
--  ParameterType = 
--  {
--	  Default		 = 1;
--	  QuestName	   = 2;
--	  Scriptname	  = 3;
--	  PlayerID		= 4;
--	  RawGoods		= 5;
--	  Number		  = 6;
--	  BuildingType	= 7;
--	  TerritoryName   = 8;
--	  KnightTitle	= 9;
--	  Need	= 10;
--	  DiplomacyState = 11;
--	  TerritoryNameWithUnknown   = 12;
--	  Entity   = 13;
--	  Good   = 14;
--	  Custom = 15;
--   }; 
------------------------------------------------------------------------------------------------------------------------------

-- New file design by: Old McDonald
-- Current version can be found here: 
-- http://wiki.siedler-aek.de/
-- Last Change: March 25 2009

--################# 4th Release ###########################
-- Fixed Reward_RestartQuest/Reward_RestartQuestForceActive

--################# 3rd Release ###########################
-- Fixed bug in Reprisal_CustomVariables possibly causing a script error
-- Fixed bug in Goal_DestroyType which prevented restarting
-- Fixed bug in Goal_DestroySoldiers causing script error
-- Fixed Reward_CreateEffect
-- Fixed Reward_CreateSeveralBattalions to consider troop size

--################# 2nd Release ###########################
-- Added parameter to Reward_CreateEntity
-- Fixed bug in Goal_RandomRequestsFromVillages

--################# Release ###########################
-- Added Reward_CreateEffect
-- Added Reward_DestroyEffect
-- Added Trigger_OnEffectDestroyed
-- Some changes to Reward_CreateEntity/Settler/Battalion etc.
-- Fixed wrong debug error message in Reward_TravelingSalesman
-- Fixed typo in Goal_UnitsOnTerritory
-- Reward_ObjectInit resets the open state in quest system of an interactive object
--################# Beta5 #############################
-- Fixed Reward_CreateBattalion for orientation -1
-- Fixed wrong debug message from Reward_SendCart for gold carts
-- Fixed Goal_UnitsOnTerritory for sheeps
-- Fixed Goal_SatisfyNeed
--################# Beta4 #############################
-- Bugfixing Trigger_PlayerDiscovered (missing '*1'  in AddParameter) 
-- Enhancing Reward_DestroyEntity, the replacing XD_ScriptEntity is now created with the orientation of the destroyed entity.
-- Fixing an ugly check in Reward_Object... Behaviors. 
--################# Beta3 #############################
-- Bugfixing QuestMarkers in Objective.Distance
-- Bugfixing ScriptError when using Reward_DEBUG without "Enable Debug Mode"
-- Bugfixing false alarm when checking "numbered" Quests ("14.5")
-- Enhancing Quest checks at mapstart, Quest without any Trigger or Goal are now reported
--################# Beta2 #############################
-- Fixed Input Mode for the ChatBox in DebugMode
-- Fixed  german Parameter Names for Reward_DEBUG
-- Reward_DEBUG Modes are now restored when a savegame is loaded
--################# Beta 1 #############################
-- Added Goal_Festivals
-- Added Goal_RandomRequestsFromVillages
-- Added Trigger_NeverTriggered
-- Added Trigger_OnQuestOver
-- Added Reward_QuestActivate
-- Added Reward_DEBUG
-- Removed Reward_MerchantShipStart
-- Removed Reward_MerchantShipOffers
-- Renamed Reward_CreateBattalionOmD -> Reward_CreateSeveralBattalions
-- Renamed Reward_CreateEntity -> Reward_CreateSeveralEntities
-- Renamed Reward_ReplaceEntity -> Reward_CreateEntity
-- Renamed Reward_DestroySettler -> Reward_DestroyEntity
-- Removed Reward_ReplaceEntityByBattalion 
-- Added Reward_TravelingSalesman (now compatible with Old McDonalds TravelingSalesman)(and repaired _BackPath ;-) ) 
-- Change in Goal_DiscoverPlayer, the obsolete second Parameter was deleted. Be sure to check your Quests if you use this QSB in older Maps. Else this could cause ScriptErrors
-- Almost ALL BEHAVIORS WERE ALTERED TO COMPLY WITH REWARD_DEBUG
-- New General function :DEBUG(_QUEST) --for .....Yes, debugging the Quests...;-) by Old McDonald and bv
-- Bugfixing Problems with number-named Quests  when loading a savegame ("14.5")
--
-- Thanks to saladin@SiedlerGamesPortal for heavy betaTesting and additional input

----------------------------------------------------------------------------------------------------------------------------- 
g_GameExtraNo = 0
	if Framework then
		g_GameExtraNo = Framework.GetGameExtraNo()
	elseif MapEditor then
		g_GameExtraNo = MapEditor.GetGameExtraNo()
	end

g_QuestBehaviorVersion = 1

-- unregister all old behaviors (by defining a new table)
g_QuestBehaviorTypes = {}

-- define local functions

local tKnownNames = {}
-- validation function
local 
function ValidateBehavior(_behavior)
	assert( type( _behavior )						== "table"  )
	assert( type( _behavior.Name )					== "string" )
	assert( type( _behavior.Description )			== "table"  )
	assert( not tKnownNames[_behavior.Name] )
	tKnownNames[_behavior.Name] = true
	assert( type( next( _behavior.Description ) )	== "string" )

	if _behavior.Parameter ~= nil then
		assert( type( _behavior.Parameter )			== "table"  )
		local bParamsOk = false
		for _, v in ipairs( _behavior.Parameter ) do
			assert( type( v[1] )					== "number" )
			for k, v in pairs(v) do
				if not tonumber( k ) then
					bParamsOk = true
					break
				end
			end
		end
		assert( bParamsOk )
	end
end

-- add behavior
local 
function AddQuestBehavior(_t)
	ValidateBehavior(_t)
	if _t.CustomFunction then
		_t.CustomFunction2 = _t.CustomFunction;
		_t.CustomFunction = function(self, _quest)
			if WikiQSB.Reward_DEBUG.Enable_QuestDebuggingAtRuntime 
			and self.DEBUG 
			and not self.DEBUG_ERROR_FOUND 
			and self:DEBUG(_quest) 
			then
				self.DEBUG_ERROR_FOUND = true
			end
			return self:CustomFunction2(_quest);
		end
	end
	table.insert(g_QuestBehaviorTypes, _t)
end

-- yet another Message
local 
function yam(_string)
	Logic.DEBUG_AddNote(_string)
	Framework.WriteToLog("WikiQSB" .. _string)
end
-- extended Messages and Log if -DisplayScriptErrors is not used
local 
function SetupErrorMessages()
	if not g_DisplayScriptErrors then
		assert = function(_b, _msg) 
			if not _b then
				_msg = _msg or "Assertion failed, please activate -DisplayScriptErrors. \r\n Visit www.siedler-aek.de for further information."
				yam(_msg); 
				local x = x; x = x + 1; -- create Lua error
			end
			return _b;
		end
	end
end

local GameCallback_RecreateGameLogicOrig = GameCallback_RecreateGameLogic;
GameCallback_RecreateGameLogic = function()
	GameCallback_RecreateGameLogicOrig();
	SetupErrorMessages();
	if WikiQSB.Reward_DEBUG.Enable_DebugMode then WikiQSB.Reward_DEBUG.DebugMode() end
	if WikiQSB.Reward_DEBUG.Enable_QuestTrace then WikiQSB.Reward_DEBUG.QuestTrace() end
	Logic.ExecuteInLuaLocalState("if type(DEBUGButtons) == 'function' then DEBUGButtons() end")
end
-- HACK for numbered Quests in SaveGames
local 
function GetQuestByName(_name)
    if tonumber(_name) then
        _name = "HACK_Numbers_" .. _name;
    end
    return g_QuestNameToID[_name];
end
-- Replacement for Quest name validation via (g_QuestNameToID[name] ~= nil)
local 
function IsValidQuest(_name)
    return GetQuestByName(_name) ~= nil; -- force boolean
end
-- kidnapping CreateQuests
local CreateQuests_Original = CreateQuests
function CreateQuests()

	CreateQuests_Original()
	--HACK for numbered Quests in SaveGames
	local t = {};
    for k, v in pairs(g_QuestNameToID) do
        if tonumber(k) then
            g_QuestNameToID[k] = nil;
            local n = #t + 1;
            t[n] = k;
            t[n + 1] = v;
        end
    end
 
    for i = 1, #t, 2 do
        g_QuestNameToID["HACK_Numbers_" .. t[i]] = t[i + 1];
    end

	SetupErrorMessages();

	if WikiQSB.Reward_DEBUG.Enable_QuestDebuggingAtMapStart then

		local questsToExport = {}--ExportQuests
		for _, questName in ipairs(Logic.Quest_GetQuestNames()) do
			if not IsValidQuest(questName) then
				yam("Quest " .. questName .. " wasn't generated. Forgot a trigger or a goal?")
			else
				local q = Quests[GetQuestByName(questName)]
				questsToExport[#questsToExport+1] = {}--ExportQuests
				local qte = questsToExport[#questsToExport]--ExportQuests
				local _QuestName = q.Identifier
				qte[#qte+1] = string.format("{ Name					= %q,\r\n%s%s%s%s%s%s%s%s",	_QuestName,
				q.SendingPlayer~= 1 and "QuestGeber 				= " .. q.SendingPlayer .. ",\r\n" or "",
				q.ReceivingPlayer~= 1 and "QuestEmpfaenger			= " .. q.ReceivingPlayer .. ",\r\n" or "",
				q.Duration and q.Duration ~= 0 and "ZeitLimit					= " .. q.Duration .. ",\r\n" or "",
				q.Visible and "VersteckteQuest			= true ,\r\n" or "",
				q.QuestDescription ~= "" and "Beschreibung 			= \""..q.QuestDescription.."\",\r\n" or "",
				q.QuestStartMsg ~= "" and "StartNachricht			= \""..q.QuestStartMsg.."\",\r\n" or "",
				q.QuestSuccessMsg ~= "" and "ErfolgsNachricht 		= \""..q.QuestSuccessMsg.."\",\r\n" or "",
				q.QuestFailureMsg ~= "" and "NiederlageNachricht	= \""..q.QuestFailureMsg.."\",\r\n" or "")--ExportQuests
				local NumberOfBehavior = Logic.Quest_GetQuestNumberOfBehaviors(_QuestName)
				for i=0,NumberOfBehavior-1 do
					local qteParams = {}--ExportQuests
					local BehaviorName = Logic.Quest_GetQuestBehaviorName(_QuestName, i)	
					qteParams[#qteParams+1] = string.format( "%q, ", BehaviorName)--ExportQuests
					local BehaviorTemplate = GetBehaviorTemplateByName(BehaviorName)
					local Parameter = Logic.Quest_GetQuestBehaviorParameter(_QuestName, i)		
					for j=1,#Parameter do
						qteParams[#qteParams+1] = string.format( "%q, ", Parameter[j])--ExportQuests
						local parameterType = BehaviorTemplate.Parameter[j][1]
						if parameterType == ParameterType.QuestName 
						and not IsValidQuest(Parameter[j]) then
							yam(_QuestName .. ": Error in ".. BehaviorName ..": No Quest ".. Parameter[j] .." found")
						elseif parameterType == ParameterType.TerritoryName
						and GetTerritoryIDByName(Parameter[j]) == 0 then
							yam(_QuestName.. ": Error in ".. BehaviorName ..": No Territory ".. Parameter[j] .." found")
						elseif parameterType == ParameterType.TerritoryNameWithUnknown
						and GetTerritoryIDByName(Parameter[j]) == 0 
						and Parameter[j] ~= "---" then
							yam(_QuestName .. ": Error in ".. BehaviorName ..": No Territory ".. Parameter[j] .." found")
						elseif parameterType == ParameterType.ScriptName
						and Logic.IsEntityDestroyed(Parameter[j]) then
							yam(_QuestName .. ": Error in ".. BehaviorName ..": No Entity has the name: ".. Parameter[j])
						end
					end
					qte[#qte+1] = table.concat(qteParams) .. "\r\n" --ExportQuests
				end
				qte[#qte+1] =  "}," --ExportQuests
			end
		end
		
		if WikiQSB.ExportQuestsToLog then --ExportQuests
			for m = 1, #questsToExport do --ExportQuests
				Framework.WriteToLog(table.concat(questsToExport[m])) --ExportQuests
			end --ExportQuests
		end --ExportQuests
	end

end
-- Umlaute
Umlaute = function(_text)
	local texttype = type(_text);
	if texttype == "string" then
		_text = _text:gsub("ä", "\195\164");
		_text = _text:gsub("ö", "\195\182");
		_text = _text:gsub("ü", "\195\188");
		_text = _text:gsub("ß", "\195\159");
		_text = _text:gsub("Ä", "\195\132");
		_text = _text:gsub("Ö", "\195\150");
		_text = _text:gsub("Ü", "\195\156");
	elseif texttype == "table" then
		for k, v in pairs(_text) do
			_text[k] = Umlaute( v );
		end
	end
	return _text
end
-- GetEntitiesNamedWith, if not already set in the MapScript --needed for Reward_TravelingSalesman
GetEntitiesNamedWith = GetEntitiesNamedWith or function(_name)
    local list = {};
	local GetEntityIDByName = Logic.GetEntityIDByName
    for i = 1, math.huge do
        local entity = GetEntityIDByName(_name .. i);
        if entity == 0 then return list end
		list[#list+1] = entity;
    end
end
--###############################################################################################
--###
--###  Global Variable
--###
--###############################################################################################

WikiQSB = WikiQSB or {}
WikiQSB.GameLanguage = nil 			-- for checking the installed language
WikiQSB.CustomVariable = { List = { "Alpha", "Beta", "Gamma", "Delta", "Epsilon" } }	-- for use in "CustomVariable" Behaviors
for i, v in ipairs(WikiQSB.CustomVariable.List) do
	WikiQSB.CustomVariable[v] = 0
end

WikiQSB.Goal_Decide = {}			-- for use in Goal_Decide
WikiQSB.Goal_DestroySoldiers = { {}, {}, {}, {}, {}, {}, {}, {} }-- for use in Goal_DestroySoldiers
WikiQSB.Goal_RandomQuestsFromVillages = {}
WikiQSB.Reward_ObjectInit= {} --for good style when customizing IOs
WikiQSB.Reward_TravelingSalesman = {} -- for use in Reward_TravelingSalesman
WikiQSB.EntitiesCreatedByQuests = {}
WikiQSB.EffectNameToID = {}

Logic.ExecuteInLuaLocalState([[ 
	do
		local messageText = XGUIEng.GetStringTableText("Feedback_TextLines/TextLine_GenericUnreachable")
		if messageText == "Nicht erreichbar!" then
			GUI.SendScriptCommand('WikiQSB.GameLanguage = "de" ', true)
		elseif messageText == "Unreachable!" then
			GUI.SendScriptCommand('WikiQSB.GameLanguage = "en" ', true)
		else 
			GUI.SendScriptCommand('WikiQSB.GameLanguage = "en" ', true)
		end
	end
]])

--###############################################################################################
--###
--###  Quest Behaviors
--###
--###############################################################################################

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_AlwaysActive
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_AlwaysActive = {
	Name = "Trigger_AlwaysActive",
	Description = {
		en = "Trigger: Starts a quest directly after the map has been started",
		de = "Ausloeser: Startet eine Quest nachdem die Karte gestartet wurde",
	},
}

function Trigger_AlwaysActive:GetTriggerTable()

	return {Triggers.Time, 0 }

end

function Trigger_AlwaysActive:AddParameter(_Index, _Parameter)

end

AddQuestBehavior(Trigger_AlwaysActive)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger CustomVariables
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

Trigger_CustomVariables = {
	Name = "Trigger_CustomVariables",
	Description = {
		en = "Trigger: Check one of five possible variables",
		de = "Belohnung: Ueberwache eine von fuenf moeglichen Variablen",
	},
	Parameter = {
		{ ParameterType.Custom,   en = "Variable", de = "Variable" },
		{ ParameterType.Custom,   en = "Relation", de = "Relation" },
		{ ParameterType.Number,   en = "Value", de = "Wert" },
	},
}

function Trigger_CustomVariables:GetTriggerTable()

	return { Triggers.Custom2, {self, self.CustomFunction} }

end

function Trigger_CustomVariables:AddParameter(_Index, _Parameter)

	if (_Index ==0) then
		self.Variable = _Parameter
	elseif (_Index == 1) then
		self.Operator = _Parameter
	elseif (_Index == 2) then
		self.Value = _Parameter*1
	end

end

function Trigger_CustomVariables:CustomFunction()

	local check = WikiQSB.CustomVariable[self.Variable]
	
	return check and
		(	(self.Operator == "<" and check < self.Value) 
		or 	(self.Operator == ">" and check > self.Value) 
		or 	(self.Operator == "=" and check == self.Value)
		)
end

function Trigger_CustomVariables:DEBUG(_Quest)

	if not WikiQSB.CustomVariable[self.Variable] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": Wrong Variable name ")
		return true
	elseif type(self.Value) ~= "number" then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": Wrong type for Value")
		return true
	elseif not ( self.Operator == "<" or self.Operator == ">" or self.Operator == "=" ) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": Wrong Operator")
		return true
	end

end

function Trigger_CustomVariables:GetCustomData(_index)
	
	if (_index == 0) then
		return WikiQSB.CustomVariable.List
	elseif (_index == 1) then
		return {">", "<", "="}
	end
	
end

AddQuestBehavior(Trigger_CustomVariables)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_MapScriptFunction
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

Trigger_MapScriptFunction = {
	Name = "Trigger_MapScriptFunction",
	Description = {
		en = "Trigger: A script function, 'true' = triggered",
		de = "Ausloeser: Eine Script Funktion, 'true' = ausgeloest",
		},
	Parameter = {
		{ParameterType.Default, en = "Function", de = "Funktion", }
				},

}

function Trigger_MapScriptFunction:GetTriggerTable()

	return { Triggers.Custom2,{self, self.CustomFunction} }

end

function Trigger_MapScriptFunction:AddParameter(_Index, _Parameter)

	if (_Index == 0) then
		self.FuncName = _Parameter
	end

end

function Trigger_MapScriptFunction:CustomFunction(_Quest)

	if not self.FuncName then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": No function name ")
	elseif type(_G[self.FuncName]) ~= "function" then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Function does not exist: " .. self.FuncName)
	else
		return _G[self.FuncName](_Quest.Identifier)
	end
	
end

AddQuestBehavior(Trigger_MapScriptFunction)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_NeverTriggered
-- User generated 
------------------------------------------------------------------------------------------------------------------------------
Trigger_NeverTriggered = {	
	Name = "Trigger_NeverTriggered",
	Description = {
		en = "Trigger: Never triggers a Quest. The quest may be set active by Reward_QuestActivate or Reward_RestartQuestForceActive",
		de = "Ausloeser: Loest nie eine Quest aus. Die Quest kann von Reward_QuestActivate oder Reward_RestartQuestForceActive aktiviert werden.", 
	}, 
}

function Trigger_NeverTriggered:GetTriggerTable()

	return {Triggers.Custom2, {self, function() end} } 

end

function Trigger_NeverTriggered:AddParameter() 
end

AddQuestBehavior(Trigger_NeverTriggered)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnAmountOfGoods
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnAmountOfGoods = {
	Name = "Trigger_OnAmountOfGoods",
	Description = {
		en = "Trigger: Starts a quest after the player has gathered a given amount of resources in his storehouse",
		de = "Ausloeser: Startet eine Quest nachdem der Spieler eine bestimmte Menge einer Resource in seinem Lagerhaus hat",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
		{ ParameterType.RawGoods, en = "Type of good", de = "Resourcentyp" },
		{ ParameterType.Number, en = "Amount of good", de = "Anzahl der Resource" },
	},
}


function Trigger_OnAmountOfGoods:GetTriggerTable()

	return { Triggers.Custom2,{self, self.CustomFunction} }

end

function Trigger_OnAmountOfGoods:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.PlayerID = _Parameter * 1
	elseif (_Index == 1) then	
		self.GoodTypeName = _Parameter
	elseif (_Index == 2) then	
		self.GoodAmount = _Parameter * 1
	end

end

function Trigger_OnAmountOfGoods:CustomFunction()

	local StoreHouseID = Logic.GetStoreHouse(self.PlayerID)
	local GoodType = Logic.GetGoodTypeID(self.GoodTypeName)

	if (StoreHouseID == 0) or (GoodType == 0) then
		return false
	end
	
	local GoodAmount = Logic.GetAmountOnOutStockByGoodType(StoreHouseID, GoodType)	
	
	if (GoodAmount >= self.GoodAmount)then
		return true
	end

	return false

end

function Trigger_OnAmountOfGoods:DEBUG(_Quest)

	if Logic.GetStoreHouse(self.PlayerID) == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": " .. self.PlayerID .. " does not exist.")
		return true
	elseif not Goods[self.GoodTypeName] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Good type is wrong.")
		return true
	elseif self.GoodAmount < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Good amount is negative.")
		return true
	end

end

AddQuestBehavior(Trigger_OnAmountOfGoods)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnAtLeastOneQuestFailure
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnAtLeastOneQuestFailure = {
	Name = "Trigger_OnAtLeastOneQuestFailure",
	Description = {
		en = "Trigger: Starts a quest after one of two other quest has failed",
		de = "Ausloeser: Startet eine Quest nachdem einer von zwei Quests fehlgeschlagen ist",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name 1", de = "Questname 1" },
		{ ParameterType.QuestName, en = "Quest name 2", de = "Questname 2" },
	},
}

function Trigger_OnAtLeastOneQuestFailure:GetTriggerTable()

	return { Triggers.Custom2,{self, self.CustomFunction} }

end

function Trigger_OnAtLeastOneQuestFailure:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.QuestName1 = _Parameter	
	elseif (_Index == 1) then	
		self.QuestName2 = _Parameter	
	end

end

function Trigger_OnAtLeastOneQuestFailure:CustomFunction()
	local Quest1ID = GetQuestByName(self.QuestName1)
	local Quest2ID = GetQuestByName(self.QuestName2)

	return ( Quest1ID and Quests[Quest1ID].Result == QuestResult.Failure ) 
		or ( Quest2ID and Quests[Quest2ID].Result == QuestResult.Failure )

end

function Trigger_OnAtLeastOneQuestFailure:DEBUG(_Quest)

	if not IsValidQuest(self.QuestName1) then
		yam(_Quest.Identifier .. ": Error in Trigger_OnAtLeastOneQuestFailure: " .. self.QuestName1 .. " does not exist")
		return true
	elseif not IsValidQuest(self.QuestName2) then
		yam(_Quest.Identifier .. ": Error in Trigger_OnAtLeastOneQuestFailure: " .. self.QuestName2 .. " does not exist")
		return true
	end

end

AddQuestBehavior(Trigger_OnAtLeastOneQuestFailure)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnAtLeastOneQuestSuccess
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnAtLeastOneQuestSuccess = {
	Name = "Trigger_OnAtLeastOneQuestSuccess",
	Description = {
		en = "Trigger: Starts a quest after one of two other quest has been finished successfully",
		de = "Ausloeser: Startet eine Quest nachdem einer von zwei Quests erfolgreich abgeschlossen wurde",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name 1", de = "Questname 1" },
		{ ParameterType.QuestName, en = "Quest name 2", de = "Questname 2" },
	},
}

function Trigger_OnAtLeastOneQuestSuccess:GetTriggerTable()

	return { Triggers.Custom2,{self, self.CustomFunction} }

end

function Trigger_OnAtLeastOneQuestSuccess:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.QuestName1 = _Parameter	
	elseif (_Index == 1) then	
		self.QuestName2 = _Parameter	
	end

end

function Trigger_OnAtLeastOneQuestSuccess:CustomFunction()
	local Quest1ID = GetQuestByName(self.QuestName1)
	local Quest2ID = GetQuestByName(self.QuestName2)

	return ( Quest1ID and Quests[Quest1ID].Result == QuestResult.Success ) or ( Quest2ID and Quests[Quest2ID].Result == QuestResult.Success )

end

function Trigger_OnAtLeastOneQuestSuccess:DEBUG(_Quest)

	if not IsValidQuest(self.QuestName1) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": " .. self.QuestName1 .. " does not exist")
		return true
	elseif not IsValidQuest(self.QuestName2) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": " .. self.QuestName2 .. " does not exist")
		return true
	end

end

AddQuestBehavior(Trigger_OnAtLeastOneQuestSuccess)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnAtLeastXOfYQuestsSuccess
-- User Generated zweispeer
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnAtLeastXOfYQuestsSuccess = {
	Name = "Trigger_OnAtLeastXOfYQuestsSuccess",
	Description = {
		en = "Trigger: Starts a quest after at least X of Y other quest has been finished successfully",
		de = "Ausloeser: Startet eine Quest nachdem X von Y Quests erfolgreich abgeschlossen wurden",
	},
	Parameter = {
		{ ParameterType.Custom, en = "Least Amount", de = "Mindest Anzahl" },
		{ ParameterType.Custom, en = "Quest Amount", de = "Quest Anzahl" },
		{ ParameterType.QuestName, en = "Quest name 1", de = "Questname 1" },
		{ ParameterType.QuestName, en = "Quest name 2", de = "Questname 2" },
		{ ParameterType.QuestName, en = "Quest name 3", de = "Questname 3" },
		{ ParameterType.QuestName, en = "Quest name 4", de = "Questname 4" },
		{ ParameterType.QuestName, en = "Quest name 5", de = "Questname 5" },
	},
}

function Trigger_OnAtLeastXOfYQuestsSuccess:GetTriggerTable()

	return { Triggers.Custom2,{self, self.CustomFunction} }

end

function Trigger_OnAtLeastXOfYQuestsSuccess:AddParameter(_Index, _Parameter)

	if (_Index == 0) then
		self.LeastAmount = _Parameter*1
	elseif (_Index == 1) then
		self.QuestAmount = _Parameter*1
	elseif (_Index == 2) then
		self.QuestName1 = _Parameter	
	elseif (_Index == 3) then	
		self.QuestName2 = _Parameter	
	elseif (_Index == 4) then	
		self.QuestName3 = _Parameter	
	elseif (_Index == 5) then	
		self.QuestName4 = _Parameter	
	elseif (_Index == 6) then	
		self.QuestName5 = _Parameter	
	end

end

function Trigger_OnAtLeastXOfYQuestsSuccess:CustomFunction()

	local least = 0

	for i = 1, self.QuestAmount do

		local Q = GetQuestByName(self["QuestName"..i])
		
		if Q and (Quests[Q].Result == QuestResult.Success) then
			least = least + 1

			if least >= self.LeastAmount then

				return true

			end

		end

	end

	return false

end

function Trigger_OnAtLeastXOfYQuestsSuccess:DEBUG(_Quest)
	
	local leastAmount = self.LeastAmount
	local questAmount = self.QuestAmount
	if leastAmount <= 0 or leastAmount >5 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": LeastAmount is wrong")
		return true
	elseif questAmount <= 0 or questAmount > 5 then 
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": QuestAmount is wrong")
		return true
	elseif leastAmount > questAmount then 
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": LeastAmount is greater than QuestAmount")
		return true
	end
	for i = 1, questAmount do
		if not IsValidQuest(self["QuestName"..i]) then
			yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest ".. self["QuestName"..i] .. " not found")
			return true
		end
	end	
	-- return true	-- if this Check is passed once, there is less than little chance that it will ever fail
end

function Trigger_OnAtLeastXOfYQuestsSuccess:GetCustomData(_Index)

	if (_Index == 0) or (_Index == 1) then

		return {"1", "2", "3", "4", "5"}

	end

end

AddQuestBehavior(Trigger_OnAtLeastXOfYQuestsSuccess)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnDiplomacy
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnDiplomacy = {
	Name = "Trigger_OnDiplomacy",
	Description = {
		en = "Trigger: Starts a quest after diplomatic relations have been established with a player",
		de = "Ausloeser: Startet eine Quest nachdem diplomatische Beziehungen mit einem Spieler erreicht wurden",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
		{ ParameterType.DiplomacyState, en = "Relation", de = "Beziehung" },
	},
}

function Trigger_OnDiplomacy:GetTriggerTable()

	local checkedPlayerID = assert((self.PlayerID <= 8 and self.PlayerID >=1 and self.PlayerID), "Error in " .. self.Name .. ": Player is wrong")
	local checkedState = 	assert(DiplomacyStates[self.DiplState], "Error in " .. self.Name .. ": Unknown DiplomacyState" ) 
	
	return {Triggers.Diplomacy, checkedPlayerID, checkedState}
			
end

function Trigger_OnDiplomacy:AddParameter(_Index, _Parameter)

	if (_Index == 0)  then
		self.PlayerID = _Parameter * 1 
	elseif (_Index == 1) then	
		self.DiplState = _Parameter	
	end

end

AddQuestBehavior(Trigger_OnDiplomacy)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnEffectDestroyed								Quest created by: Old McDonald
-- User generated
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnEffectDestroyed = {
	Name = "Trigger_OnEffectDestroyed",
	Description = {
		en = "Trigger: Starts a quest after an effect was destroyed",
		de = "Ausloeser: Startet eine Quest, nachdem ein Effekt zerstoert wurde",
	},
	Parameter = {
		{ ParameterType.Default, en = "Effect name", de = "Effektname" },
	},
}

function Trigger_OnEffectDestroyed:GetTriggerTable()

	return { Triggers.Custom2, {self, self.CustomFunction} }

end

function Trigger_OnEffectDestroyed:AddParameter(_Index, _Parameter)

	if _Index == 0 then	
		self.EffectName = _Parameter
	end

end

function Trigger_OnEffectDestroyed:CustomFunction()

	return not WikiQSB.EffectNameToID[self.EffectName] or not Logic.IsEffectRegistered(WikiQSB.EffectNameToID[self.EffectName]);

end

function Trigger_OnEffectDestroyed:DEBUG(_Quest)

	if not WikiQSB.EffectNameToID[self.EffectName] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Effect has never existed")
		return true
	end

end
AddQuestBehavior(Trigger_OnEffectDestroyed)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnMonth
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnMonth = {
	Name = "Trigger_OnMonth",
	Description = {
		en = "Trigger: Starts a quest during a specified month",
		de = "Ausloeser: Startet eine Quest in einem bestimmten Monat",
	},
	Parameter = {
		{ ParameterType.Custom, en = "Month", de = "Monat" },
	},
}

function Trigger_OnMonth:GetTriggerTable()

	return { Triggers.Custom2, {self, self.CustomFunction} }

end

function Trigger_OnMonth:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.Month = _Parameter * 1
	end

end

function Trigger_OnMonth:CustomFunction()

	return self.Month == Logic.GetCurrentMonth()

end

function Trigger_OnMonth:DEBUG(_Quest)

	if self.Month < 1 or self.Month > 12 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Month has the wrong value")
		return true
	end

end

function Trigger_OnMonth:GetCustomData( _Index )

	local Data = {}
	if _Index == 0 then

		for i = 1, 12 do
			table.insert( Data, i )
		end

	else
		assert( false , "Error in " .. self.Name .. ": GetCustomData: wrong index")
	end

	return Data

end

AddQuestBehavior(Trigger_OnMonth)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnNeedUnsatisfied
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnNeedUnsatisfied = {
	Name = "Trigger_OnNeedUnsatisfied",
	Description = {
		en = "Trigger: Starts a quest if a specified need is unsatisfied",
		de = "Ausloeser: Startet eine Quest nachdem der Spieler ein bestimmtes Beduerfnis nicht befriedigt",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
		{ ParameterType.Need, en = "Need", de = "Beduerfnis" },
		{ ParameterType.Number, en = "Workers on strike", de = "Streikende Arbeiter" },
	},
}


function Trigger_OnNeedUnsatisfied:GetTriggerTable()

	return { Triggers.Custom2,{self, self.CustomFunction} }

end

function Trigger_OnNeedUnsatisfied:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.PlayerID = _Parameter * 1
	elseif (_Index == 1) then	
		self.Need = _Parameter
	elseif (_Index == 2) then	
		self.WorkersOnStrike = _Parameter * 1
	end

end

function Trigger_OnNeedUnsatisfied:CustomFunction()

	return Logic.GetNumberOfStrikingWorkersPerNeed( self.PlayerID, assert( Needs[self.Need], _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Need invalid" ) ) >= self.WorkersOnStrike

end

function Trigger_OnNeedUnsatisfied:DEBUG(Quest)

	if Logic.GetStoreHouse(self.PlayerID) == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": " .. self.PlayerID .. " does not exist.")
		return true
	elseif not Needs[self.Need] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": " .. self.Need .. " does not exist.")
		return true
	elseif self.WorkersOnStrike < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": WorkersOnStrike value negative")
		return true
	end

end

AddQuestBehavior(Trigger_OnNeedUnsatisfied)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnQuestActive
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnQuestActive = {
	Name = "Trigger_OnQuestActive",
	Description = {
		en = "Trigger: Starts a quest after another quest was activated but wasn't finished yet. This one should be used in combination with other triggers",
		de = "Ausloeser: Startet eine Quest nachdem eine andere Quest aktiviert aber noch nicht abgeschlossen wurde. Dieser Trigger sollte in Kombination mit anderen Triggern verwendet werden",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name", de = "Questname" },
	},
}

function Trigger_OnQuestActive:GetTriggerTable()

	return { Triggers.Custom2,{self, self.CustomFunction} }

end

function Trigger_OnQuestActive:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.QuestName = _Parameter	
	end

end

function Trigger_OnQuestActive:CustomFunction()

	if IsValidQuest(self.QuestName) then

		local QuestID = GetQuestByName(self.QuestName)
		if Quests[QuestID].State == QuestState.Active then

			return true

		end

	end

	return false

end

function Trigger_OnQuestActive:DEBUG(_Quest)

	if not IsValidQuest(self.QuestName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " does not exist")
		return true
	end	

end

AddQuestBehavior(Trigger_OnQuestActive)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnQuestFailure
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnQuestFailure = {
	Name = "Trigger_OnQuestFailure",
	Description = {
		en = "Trigger: Starts a quest after another quest has failed",
		de = "Ausloeser: Startet eine Quest nachdem eine andere Quest fehlgeschlagen ist",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name", de = "Questname" },
	},
}

function Trigger_OnQuestFailure:GetTriggerTable()

	return { Triggers.Custom2,{self, self.CustomFunction} }

end

function Trigger_OnQuestFailure:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.QuestName = _Parameter	
	end

end

function Trigger_OnQuestFailure:CustomFunction()

	if IsValidQuest(self.QuestName) then

		local QuestID = GetQuestByName(self.QuestName)
		if (Quests[QuestID].Result == QuestResult.Failure) then

			return true

		end

	end

	return false

end

function Trigger_OnQuestFailure:DEBUG(_Quest)
	
	if not IsValidQuest(self.QuestName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " does not exist")
		return true
	end	

end

AddQuestBehavior(Trigger_OnQuestFailure)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnQuestInterrupted
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnQuestInterrupted = {
	Name = "Trigger_OnQuestInterrupted",
	Description = {
		en = "Trigger: Starts a quest if another quest has been interrupted. This one should be used in combination with other triggers",
		de = "Ausloeser: Startet eine Quest wenn eine andere Quest unterbrochen worden ist. Dieser Trigger sollte in Kombination mit anderen Triggern verwendet werden",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name", de = "Questname" },
	},
}

function Trigger_OnQuestInterrupted:GetTriggerTable()

	return { Triggers.Custom2,{self, self.CustomFunction} }

end

function Trigger_OnQuestInterrupted:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.QuestName = _Parameter	
	end

end

function Trigger_OnQuestInterrupted:CustomFunction()

	if IsValidQuest(self.QuestName) then

		local QuestID = GetQuestByName(self.QuestName)
		if Quests[QuestID].State == QuestState.Over and Quests[QuestID].Result == QuestResult.Interrupted then

			return true

		end

	end

	return false

end

function Trigger_OnQuestInterrupted:DEBUG(_Quest)
	
	if not IsValidQuest(self.QuestName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " does not exist")
		return true
	end	

end

AddQuestBehavior(Trigger_OnQuestInterrupted)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnQuestNotTriggered
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnQuestNotTriggered = {
	Name = "Trigger_OnQuestNotTriggered",
	Description = {
		en = "Trigger: Starts a quest if another quest hasn't been triggered yet. This one should be used in combination with other triggers",
		de = "Ausloeser: Startet eine Quest wenn eine andere Quest noch nicht aktiviert worden ist. Dieser Trigger sollte in Kombination mit anderen Triggern verwendet werden",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name", de = "Questname" },
	},
}

function Trigger_OnQuestNotTriggered:GetTriggerTable()

	return { Triggers.Custom2,{self, self.CustomFunction} }

end

function Trigger_OnQuestNotTriggered:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.QuestName = _Parameter	
	end

end

function Trigger_OnQuestNotTriggered:CustomFunction()

	if IsValidQuest(self.QuestName) then

		local QuestID = GetQuestByName(self.QuestName)
		if Quests[QuestID].State == QuestState.NotTriggered then

			return true

		end

	end

	return false

end

function Trigger_OnQuestNotTriggered:DEBUG(_Quest)
	
	if not IsValidQuest(self.QuestName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " does not exist")
		return true
	end	

end

AddQuestBehavior(Trigger_OnQuestNotTriggered)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnQuestOver
-- User generated 
------------------------------------------------------------------------------------------------------------------------------
Trigger_OnQuestOver = {
	Name = "Trigger_OnQuestOver",
	Description = {
		en = "Trigger: Triggers when the given quest is over, regardless of its result",
		de = "Trigger: Loest aus wenn die angegebene Quest beendet ist, unabhaengig von deren Ergebnis",
			},
	Parameter = {
		{ParameterType.QuestName, en = "Quest name", de = "Questname", },
		{ParameterType.Custom, en = "Even if Interrupted", de = "Auch bei Unterbrechung", },
			},
}

function Trigger_OnQuestOver:GetTriggerTable()
	
	return {Triggers.Custom2, {self, self.CustomFunction} }

end

function Trigger_OnQuestOver:AddParameter(_Index, _Parameter)

	if (_Index == 0) then
		self.QuestName = _Parameter
	elseif(_Index == 1) then
		self.AndInterrupted = _Parameter == "Yes"
	else 
		assert(false, "Error in " .. self.Name .. ": AddParameter: Index invalid")
	end

end

function Trigger_OnQuestOver:CustomFunction(_Quest)

	local questID = GetQuestByName(self.QuestName)
	local quest = Quests[questID]
	if quest and quest.State == QuestState.Over then

		if not self.AndInterrupted then
			return quest.Result ~= QuestResult.Interrupted
		else
			return true
		end

	end	
	return false

end

function Trigger_OnQuestOver:DEBUG(_Quest)
	
	if not IsValidQuest(self.QuestName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " does not exist")
		return true
	end	

end

function Trigger_OnQuestOver:GetCustomData(_index)

	assert (_index == 1, "Error in " .. self.Name .. ": GetCustomData: Index invalid")
	return {"No", "Yes"}

end	

AddQuestBehavior(Trigger_OnQuestOver)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnQuestSuccess
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnQuestSuccess = {
	Name = "Trigger_OnQuestSuccess",
	Description = {
		en = "Trigger: Starts a quest after another quest has been finished successfully",
		de = "Ausloeser: Startet eine Quest nachdem eine andere Quest erfolgreich abgeschlossen wurde",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name", de = "Questname" },
		
	},
}

function Trigger_OnQuestSuccess:GetTriggerTable()

	return { Triggers.Custom2,{self, self.CustomFunction} }

end

function Trigger_OnQuestSuccess:AddParameter(_Index, _Parameter)

	if (_Index == 0) then
		self.QuestName = _Parameter	
	end

end

function Trigger_OnQuestSuccess:CustomFunction()

	if IsValidQuest(self.QuestName) then
	
		local QuestID = GetQuestByName(self.QuestName)	
		if (Quests[QuestID].Result == QuestResult.Success) then
			
			return true
				  
		end

	end

	return false

end

function Trigger_OnQuestSuccess:DEBUG(_Quest)
	
	if not IsValidQuest(self.QuestName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " does not exist")
		return true
	end	

end

AddQuestBehavior(Trigger_OnQuestSuccess)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnQuestSuccessWait
-- User Generated zweispeer
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnQuestSuccessWait = {
	Name = "Trigger_OnQuestSuccessWait",
	Description = {
		en = "Trigger: Starts a quest after another quest has been finished successfully and a given time has passed",
		de = "Ausloeser: Startet eine Quest nachdem eine andere Quest erfolgreich abgeschlossen wurde und die eingestellte Zeit vergangen ist",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name", de = "Questname" },
		{ ParameterType.Number, en = "Waiting time", de = "Wartezeit"},
	},
}

function Trigger_OnQuestSuccessWait:GetTriggerTable()

	return { Triggers.Custom2,{self, self.CustomFunction} }

end

function Trigger_OnQuestSuccessWait:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.QuestName = _Parameter	
	elseif (_Index == 1) then	
		self.WaitingTime = _Parameter*1 
	end

end

function Trigger_OnQuestSuccessWait:CustomFunction()

	if IsValidQuest(self.QuestName) then
		local QuestID = GetQuestByName(self.QuestName)
		if (Quests[QuestID].Result == QuestResult.Success) then
			if self.WaitingTime and self.WaitingTime > 0 then
				self.TimerStartTime = self.TimerStartTime or Logic.GetTime()
				if Logic.GetTime() >= (self.TimerStartTime + self.WaitingTime) then
					return true
				end
			else
			return true
			end	  
		end
	end
	return false
	
end

function Trigger_OnQuestSuccessWait:DEBUG(_Quest)
	
	if not IsValidQuest(self.QuestName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " does not exist")
		return true
	elseif self.WaitingTime < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Waiting time is negative")
		return true
	end	

end

function Trigger_OnQuestSuccessWait:Reset()

	self.TimerStartTime = nil	

end

AddQuestBehavior(Trigger_OnQuestSuccessWait)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnResourceDepleted
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnResourceDepleted = {
	Name = "Trigger_OnResourceDepleted",
	Description = {
		en = "Trigger: Starts a quest if a resource is (temporarily) depleted",
		de = "Ausloeser: Startet eine Quest nachdem eine Resource (zeitweilig) verbraucht ist",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script name", de = "Skriptname" },
	},
}

function Trigger_OnResourceDepleted:GetTriggerTable()

	return { Triggers.Custom2,{self, self.CustomFunction} }

end

function Trigger_OnResourceDepleted:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.Scriptname = _Parameter
	end
	
end

function Trigger_OnResourceDepleted:CustomFunction()

	local ID = Logic.GetEntityIDByName(self.Scriptname)
	return not ID or ID == 0 or Logic.GetResourceDoodadGoodType(ID) == 0 or Logic.GetResourceDoodadGoodAmount(ID) == 0
	
end
--DEBUG: Not necessary???
AddQuestBehavior(Trigger_OnResourceDepleted)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_OnWaterFreezes
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_OnWaterFreezes = {
	Name = "Trigger_OnWaterFreezes",
	Description = {
		en = "Trigger: Starts a quest if the water starts freezing",
		de = "Ausloeser: Startet eine Quest wenn die Gewaesser gefrieren",
	},
}

function Trigger_OnWaterFreezes:GetTriggerTable()

	return { Triggers.Custom2,{self, self.CustomFunction} }

end

function Trigger_OnWaterFreezes:AddParameter(_Index, _Parameter)
	
end

function Trigger_OnWaterFreezes:CustomFunction()

	if Logic.GetWeatherDoesWaterFreeze( 0 ) then
		return true
	end

end
--DEBUG: Not necessary???
AddQuestBehavior(Trigger_OnWaterFreezes)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_PlayerDiscovered
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_PlayerDiscovered = {
	Name = "Trigger_PlayerDiscovered",
	Description = {
		en = "Trigger: Starts a quest after a player has been discovered",
		de = "Ausloeser: Startet eine Quest nachdem ein Spieler entdeckt wurde",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
	},
}

function Trigger_PlayerDiscovered:GetTriggerTable()

	local checkedPlayerID = assert((self.PlayerID <= 8 and self.PlayerID >=1 and self.PlayerID), "Error in " .. self.Name .. ": Player is wrong")
	return {Triggers.PlayerDiscovered, checkedPlayerID}

end

function Trigger_PlayerDiscovered:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.PlayerID = _Parameter * 1	
	end

end

AddQuestBehavior(Trigger_PlayerDiscovered)

------------------------------------------------------------------------------------------------------------------------------
--
-- Trigger_Time
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Trigger_Time = {
	Name = "Trigger_Time",
	Description = {
		en = "Trigger: Starts a quest after a given amount of time since map start",
		de = "Ausloeser: Startet eine Quest nach einer gewissen Anzahl von Sekunden nach Spielbeginn",
	},
	Parameter = {
		{ ParameterType.Number, en = "Time (sec.)", de = "Zeit (Sek.)" },
	},
}

function Trigger_Time:GetTriggerTable()

	local checkedTime = assert(self.Time >= 0 and self.Time, "Error in " .. self.Name .. ": Time is negative")
	return {Triggers.Time, checkedTime}
	
end

function Trigger_Time:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.Time = _Parameter * 1
	end

end

AddQuestBehavior(Trigger_Time)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_ActivateBuff
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_ActivateBuff = {
	Name = "Goal_ActivateBuff",
	Description = {
		en = "Goal: Activate a buff",
		de = "Ziel: Aktiviere einen Buff",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
		{ ParameterType.Custom, en = "Buff", de = "Buff" },
	},
}

function Goal_ActivateBuff:GetGoalTable()

	return { Objective.Custom2, {self, self.CustomFunction} }

end

function Goal_ActivateBuff:AddParameter(_Index, _Parameter)

	if (_Index == 0) then
		self.PlayerID = _Parameter * 1
	elseif (_Index == 1) then
		self.Buff = _Parameter
	end
	
end

function Goal_ActivateBuff:CustomFunction(_Quest)

	local Buff = Logic.GetBuff( self.PlayerID, assert( Buffs[self.Buff], _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Buff is invalid" ) )
	if Buff and Buff ~= 0 then
		return true
	end

end

function Goal_ActivateBuff:DEBUG(_Quest)
	
	if Logic.GetStoreHouse(self.PlayerID) == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player "..  self.PlayerID .. " is dead :-(")
		return true
	elseif GetPlayerCategoryType(self.PlayerID) ~= PlayerCategories.City then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ":  Player "..  self.PlayerID .. " is no city")
		return true
	elseif not Buffs[self.Buff] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ":  Buff:"..  self.Buff .. " is wrong")
		return true
	end	

end

function Goal_ActivateBuff:GetCustomData( _Index )

	local Data = {}
	if _Index == 1 then
		for k, v in pairs( Buffs ) do
			table.insert( Data, k )
		end
		table.sort( Data )
	else
		assert( false , "Error in " .. self.Name .. ": GetCustomData: Index is invalid")
	end
	
	return Data
	
end

function Goal_ActivateBuff:GetIcon()

	local tMapping = {
		[Buffs.Buff_Spice] = "Goods.G_Salt",
		[Buffs.Buff_Colour] = "Goods.G_Dye",
		[Buffs.Buff_Entertainers] = "Entities.U_Entertainer_NA_FireEater", --{5, 12},
		[Buffs.Buff_FoodDiversity] = "Needs.Nutrition", --{1, 1},
		[Buffs.Buff_ClothesDiversity] = "Needs.Clothes", --{1, 2},
		[Buffs.Buff_HygieneDiversity] = "Needs.Hygiene", --{16, 1},
		[Buffs.Buff_EntertainmentDiversity] = "Needs.Entertainment", --{1, 4},
		--[Buffs.Buff_NoPayment] = "Goods_G_Gold", --{1, 8},
		--[Buffs.Buff_ExtraPayment] = "Goods.G_Gold", --{1, 8},
		[Buffs.Buff_Sermon] = "Technologies.R_Sermon", --{4, 14},
		--[Buffs.Buff_HighTaxes] = "Needs.Prosperity", --{1, 6},
		--[Buffs.Buff_NoTaxes] = "Needs.Prosperity", --{1, 6},
		[Buffs.Buff_Festival] = "Technologies.R_Festival", --{4, 15},
	}
	
	if g_GameExtraNo and g_GameExtraNo >= 1 then
		-- TODO: Could do this the generic way using string.gsub + post-check
		tMapping[Buffs.Buff_Gems] = "Goods.G_Gems"
		tMapping[Buffs.Buff_MusicalInstrument] = "Goods.G_MusicalInstrument"
		tMapping[Buffs.Buff_Olibanum] = "Goods.G_Olibanum"
	end
	
	return tMapping[Buffs[self.Buff]]

end

AddQuestBehavior(Goal_ActivateBuff)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_ActivateObject
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_ActivateObject = {
	Name = "Goal_ActivateObject",
	Description = {
		en = "Goal: Activate an interactive object",
		de = "Ziel: Aktiviere ein interaktives Objekt",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script name", de = "Skriptname" },
	},
}

function Goal_ActivateObject:GetGoalTable()

	assert( ( not Logic.IsEntityDestroyed(self.Scriptname) and Logic.IsInteractiveObject(Logic.GetEntityIDByName(self.Scriptname))),
			"Error in " .. self.Name .. ": GetGoalTable: Object is invalid")
	return {Objective.Object, { self.Scriptname } }

end

function Goal_ActivateObject:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.Scriptname = _Parameter
	end

end

function Goal_ActivateObject:GetMsgKey()

	-- Need to check for the context / type of the object
	-- Quest_Object_Build
	-- Quest_Object_Free
	-- Quest_Object_Treasure
	
	return "Quest_Object_Activate"
	
end

AddQuestBehavior(Goal_ActivateObject)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_BuildRoad
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_BuildRoad = {
	Name = "Goal_BuildRoad",
	Description = {
		en = "Goal: Connect two points with a road",
		de = "Ziel: Verbinde zwei Punkte mit einem Weg",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Entity 1", de = "Entity 1" },
		{ ParameterType.ScriptName, en = "Entity 2", de = "Entity 2" },
		{ ParameterType.Custom, en = "Relation", de = "Relation" },
		{ ParameterType.Number, en = "Length", de = "Laenge" },
		{ ParameterType.Custom, en = "Only roads", de = "Nur Strassen" },
	},
}

function Goal_BuildRoad:GetGoalTable()

	return { Objective.BuildRoad, { Logic.GetEntityIDByName( self.Entity1 ), Logic.GetEntityIDByName( self.Entity2 ),
		self.bRelSmallerThan, self.Length, self.bRoadsOnly } }

end

function Goal_BuildRoad:AddParameter(_Index, _Parameter)

	if (_Index == 0) then
		self.Entity1 = _Parameter
	elseif (_Index == 1) then
		self.Entity2 = _Parameter
	elseif (_Index == 2) then
		self.bRelSmallerThan = _Parameter == "<"
	elseif (_Index == 3) then
		self.Length = _Parameter * 1
	elseif (_Index == 4) then
		self.bRoadsOnly = _Parameter == "+"
	end
	
end

function Goal_BuildRoad:GetCustomData( _Index )

	local Data = {}
	if _Index == 2 then
		table.insert( Data, ">" )
		table.insert( Data, "<" )
		
	elseif _Index == 4 then
		table.insert( Data, "+" )
		table.insert( Data, "-" )
		
	else
		assert( false, "Error in " .. self.Name .. ": GetCustomData: Index is invalid" )
	end
	
	return Data
	
end

AddQuestBehavior(Goal_BuildRoad)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_BuildWall
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_BuildWall = {
	Name = "Goal_BuildWall",
	Description = {
		en = "Goal: Build a wall that prevents free travel for a player between two entities",
		de = "Ziel: Erstellung einer Mauer die die freie Bewegung eiens Spielers zwischen zwei Entities verhindert",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
		{ ParameterType.ScriptName, en = "Entity 1", de = "Entity 1" },
		{ ParameterType.ScriptName, en = "Entity 2", de = "Entity 2" },
	},
}

function Goal_BuildWall:GetGoalTable()

	return { Objective.Custom2, {self, self.CustomFunction} }

end

function Goal_BuildWall:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.PlayerID = _Parameter * 1
	elseif (_Index == 1) then	
		self.Entity1 = _Parameter
	elseif (_Index == 2) then	
		self.Entity2 = _Parameter
	end
	
end

function Goal_BuildWall:CustomFunction(_Quest)
	
	if Logic.IsEntityDestroyed( self.Entity1 ) or Logic.IsEntityDestroyed( self.Entity2 ) then
		return false
	end

	local ID1 = Logic.GetEntityIDByName( self.Entity1 )
	local ID2 = Logic.GetEntityIDByName( self.Entity2 )
	
	local x1, y1 = Logic.GetEntityPosition( ID1 )
	local x2, y2 = Logic.GetEntityPosition( ID2 )
	if Logic.IsBuilding( ID1 ) == 1 then
		x1, y1 = Logic.GetBuildingApproachPosition( ID1 )
	elseif Logic.GetEntityType(ID1) ~= Entities.XD_ScriptEntity then
		assert(false, _Quest.Identifier .. ": Error in " .. self.Name .. ": Entity 1 must be building or ScriptEntity.")
	end
	if Logic.IsBuilding( ID2 ) == 1 then
		x2, y2 = Logic.GetBuildingApproachPosition( ID2 )
	elseif Logic.GetEntityType(ID2) ~= Entities.XD_ScriptEntity then
		assert(false, _Quest.Identifier .. ": Error in " .. self.Name .. ": Entity 2 must be building or ScriptEntity.")
	end
	local Sector1 = Logic.GetPlayerSectorAtPosition( self.PlayerID, x1, y1 )
	local Sector2 = Logic.GetPlayerSectorAtPosition( self.PlayerID, x2, y2 )
	if Sector1 ~= Sector2 then
		return true
	end
	
end

function Goal_BuildWall:DEBUG(_Quest)
	
	local iD1 = Logic.GetEntityIDByName(self.Entity1) 
	local iD2 = Logic.GetEntityIDByName(self.Entity2)
	if Logic.GetStoreHouse(self.PlayerID) == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player "..  self.PlayerID .. " is dead :-(")
		return true
	elseif Logic.IsEntityDestroyed( self.Entity1 ) or Logic.IsEntityDestroyed( self.Entity2 ) then
		yam(_Quest.Identifier .. ": Warning in " .. self.Name .. ": One of the Entities is missing")
		return true
	elseif Logic.IsBuilding(iD1) == 0 and Logic.GetEntityType(iD1) ~= Entities.XD_ScriptEntity then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity 1 should be a building or XD_ScriptEntity")
		return true
	elseif Logic.IsBuilding(iD2) == 0 and Logic.GetEntityType(iD2) ~= Entities.XD_ScriptEntity then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity 2 should be a building or XD_ScriptEntity")
		return true
	end	

end

function Goal_BuildWall:GetMsgKey()

	return "Quest_Create_Wall"

end

function Goal_BuildWall:GetIcon()

	return "Technologies.R_Wall"	 

end

AddQuestBehavior(Goal_BuildWall)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_Capture
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_Capture = {
	Name = "Goal_Capture",
	Description = {
		en = "Goal: Capture an entity",
		de = "Ziel: Nimm eine Entitaet gefangen",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script name", de = "Skriptname" },
	},
}

function Goal_Capture:GetGoalTable()

	return { Objective.Capture, 1, { self.Scriptname } }

end

function Goal_Capture:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.Scriptname = _Parameter
	end

end

function Goal_Capture:GetMsgKey()
	
	if Logic.IsEntityAlive(self.Scriptname) then
		local ID = Logic.GetEntityIDByName(self.Scriptname)
		ID = Logic.GetEntityType( ID )
		if ID and ID ~= 0 then
			if Logic.IsEntityTypeInCategory( ID, EntityCategories.AttackableMerchant ) == 1 then
				return "Quest_Capture_Cart"
				
			elseif Logic.IsEntityTypeInCategory( ID, EntityCategories.SiegeEngine ) == 1 then
				return "Quest_Capture_SiegeEngine"
				
			elseif Logic.IsEntityTypeInCategory( ID, EntityCategories.Worker ) == 1
				or Logic.IsEntityTypeInCategory( ID, EntityCategories.Spouse ) == 1
				or Logic.IsEntityTypeInCategory( ID, EntityCategories.Hero ) == 1 then
				
				return "Quest_Capture_VIPOfPlayer"
			
			end
		end
	end
	
	-- No default message
end

AddQuestBehavior(Goal_Capture)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_CaptureType
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_CaptureType = {
	Name = "Goal_CaptureType",
	Description = {
		en = "Goal: Capture specified entity types",
		de = "Ziel: Nimm bestimmte Entitaetstypen gefangen",
	},
	Parameter = {
		{ ParameterType.Custom, en = "Type name", de = "Typbezeichnung" },
		{ ParameterType.Number, en = "Amount", de = "Anzahl" },
		{ ParameterType.Custom, en = "Player", de = "Spieler" },
	},
}

function Goal_CaptureType:GetGoalTable()

	local checkedType = assert( Entities[self.EntityName], "Error in " .. self.Name .. ": GetGoalTable: Entity is invalid" )
	local checkedAmount = assert( self.Amount > 0 and self.Amount, "Error in " .. self.Name .. ": GetGoalTable: Amount is invalid" )
	
	return { Objective.Capture, 2, checkedType, checkedAmount, self.PlayerID }

end

function Goal_CaptureType:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.EntityName = _Parameter
	elseif (_Index == 1) then   
		self.Amount = _Parameter * 1
	elseif (_Index == 2) then   
		self.PlayerID = _Parameter * 1
	end

end

function Goal_CaptureType:GetCustomData( _Index )

	local Data = {}
	if _Index == 0 then
		for k, v in pairs( Entities ) do
			if string.find( k, "^U_.+Cart" ) or Logic.IsEntityTypeInCategory( v, EntityCategories.AttackableMerchant ) == 1 then
				table.insert( Data, k )
			end
		end
		table.sort( Data )
	   
	elseif _Index == 2 then
		for i = 0, 8 do
			table.insert( Data, i )
		end
	   
	else
		assert( false , "Error in " .. self.Name .. ": GetCustomData: Index is invalid")
	end
	
	return Data
	
end

function Goal_CaptureType:GetMsgKey()
	
	local ID = self.EntityName
	if Logic.IsEntityTypeInCategory( ID, EntityCategories.AttackableMerchant ) == 1 then
		return "Quest_Capture_Cart"
		
	elseif Logic.IsEntityTypeInCategory( ID, EntityCategories.SiegeEngine ) == 1 then
		return "Quest_Capture_SiegeEngine"
		
	elseif Logic.IsEntityTypeInCategory( ID, EntityCategories.Worker ) == 1
		or Logic.IsEntityTypeInCategory( ID, EntityCategories.Spouse ) == 1
		or Logic.IsEntityTypeInCategory( ID, EntityCategories.Hero ) == 1 then
		
		return "Quest_Capture_VIPOfPlayer"
	end
	
	-- No default message
end

AddQuestBehavior(Goal_CaptureType)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_Claim
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_Claim = {
	Name = "Goal_Claim",
	Description = {
		en = "Goal: Claim a territory",
		de = "Ziel: Erobere ein Territorium"
	},
	Parameter = {
		{ ParameterType.TerritoryName, en = "Territory", de = "Territorium" },
	},
}

function Goal_Claim:GetGoalTable()

	assert( self.TerritoryID ~= 0 , "Error in " .. self.Name .. ": GetGoalTable: Territory is invalid")
	return { Objective.Claim, 1, self.TerritoryID }

end

function Goal_Claim:AddParameter(_Index, _Parameter)

	if (_Index == 0) then		
		self.TerritoryID = GetTerritoryIDByName(_Parameter)
	end

end

function Goal_Claim:GetMsgKey()

	return "Quest_Claim_Territory"

end

AddQuestBehavior(Goal_Claim)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_ClaimXTerritories
-- BB Original by zweispeer
------------------------------------------------------------------------------------------------------------------------------

Goal_ClaimXTerritories = {
	Name = "Goal_ClaimXTerritories",
	Description = {
		en = "Goal: Claim the given number of territories, all player territories are counted",
		de = "Ziel: Besetze die angegebene Zahl an Territorien, alle spielereigenen Territorien werden gezaehlt",
	},
	Parameter = {
		{ ParameterType.Number, en = "Territories" , de = "Territorien" }
	},
}

function Goal_ClaimXTerritories:GetGoalTable()

	assert(self.TerritoriesToClaim > 0, "Error in " .. self.Name .. ": GetGoalTable: Number of Territories is invalid")
	return { Objective.Claim, 2, self.TerritoriesToClaim }

end

function Goal_ClaimXTerritories:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.TerritoriesToClaim = _Parameter * 1
	end

end

function Goal_ClaimXTerritories:GetMsgKey()

	return "Quest_Claim_Territory"

end

AddQuestBehavior(Goal_ClaimXTerritories)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_Create
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_Create = {
	Name = "Goal_Create",
	Description = {
		en = "Goal: Create Buildings/Units (on a specified territory)",
		de = "Ziel: Erstelle Einheiten/Gebaeude (auf einem bestimmten Territorium)",
	},
	Parameter = {
		{ ParameterType.Entity, en = "Type name", de = "Typbezeichnung" },
		{ ParameterType.Number, en = "Amount", de = "Anzahl" },
		{ ParameterType.TerritoryNameWithUnknown, en = "Territory", de = "Territorium" },
	},
}

function Goal_Create:GetGoalTable()

	assert( Entities[self.EntityName] , "Error in " .. self.Name .. ": GetGoalTable: Entity type is invalid")
	assert( self.Amount > 0, "Error in " .. self.Name .. ": GetGoalTable: Amount is invalid")
	return { Objective.Create, Entities[self.EntityName], self.Amount, self.TerritoryID  }

end

function Goal_Create:AddParameter(_Index, _Parameter)

	if (_Index == 0) then
		self.EntityName = _Parameter
	elseif (_Index == 1) then		
		self.Amount = _Parameter * 1
	elseif (_Index == 2) then		
		self.TerritoryID = GetTerritoryIDByName(_Parameter)
	end

end

function Goal_Create:GetMsgKey()

	 return Logic.IsEntityTypeInCategory( Entities[self.EntityName], EntityCategories.AttackableBuilding ) == 1 and "Quest_Create_Building" or "Quest_Create_Unit"
	
end

AddQuestBehavior(Goal_Create)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal CustomVariables
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

Goal_CustomVariables = {
	Name = "Goal_CustomVariables",
	Description = {
		en = "Goal: Check one of five possible variables",
		de = "Belohnung: Ueberwache eine von fuenf moeglichen Variablen",
	},
	Parameter = {
		{ ParameterType.Custom,   en = "Variable", de = "Variable" },
		{ ParameterType.Custom,   en = "Relation", de = "Relation" },
		{ ParameterType.Number,   en = "Value", de = "Wert" },
	},
}

function Goal_CustomVariables:GetGoalTable()

	return { Objective.Custom2, {self, self.CustomFunction} }

end

function Goal_CustomVariables:AddParameter(_Index, _Parameter)

	if (_Index ==0) then
		self.Variable = _Parameter
	elseif (_Index == 1) then
		self.Operator = _Parameter
	elseif (_Index == 2) then
		self.Value = _Parameter*1
	end
	
end

function Goal_CustomVariables:CustomFunction()
	
	local check = WikiQSB.CustomVariable[self.Variable]
	if check then
		return (self.Operator == "<" and check < self.Value)
			or (self.Operator == ">" and check > self.Value)
			or (self.Operator == "=" and check == self.Value)
			or nil
	end

end

function Goal_CustomVariables:DEBUG(_Quest)
	
	if not WikiQSB.CustomVariable[self.Variable] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": Wrong Variable name ")
		return true
	elseif type(self.Value) ~= "number" then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": Wrong type for Value")
		return true
	elseif not ( self.Operator == "<" or self.Operator == ">" or self.Operator == "=" ) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": Wrong Operator")
		return true
	end
	
end

function Goal_CustomVariables:GetCustomData(_index)

	if (_index == 0) then
		return WikiQSB.CustomVariable.List
	elseif (_index == 1) then
		return {">", "<", "="}
	end
	
end

AddQuestBehavior(Goal_CustomVariables)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_Decide
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

Goal_Decide = {
	Name = "Goal_Decide",
	Description = { 
		en = "Goal: Opens a Yes/No Dialog. Decision = Quest Result",
		de = "Ziel: Oeffnet einen Ja/Nein Dialog. Entscheidung gleich Quest Ergebnis",
	},
	Parameter = {
		{ ParameterType.Default, en = "Text", de = "Text", },
		{ ParameterType.Default, en = "Title", de = "Titel", },
		{ ParameterType.Custom, en = "Button labels", de = "Button Beschriftung", },
	},
}

function Goal_Decide:GetGoalTable()

	return { Objective.Custom2, { self, self.CustomFunction } }

end

function Goal_Decide:AddParameter( _Index, _Parameter )

	if (_Index == 0) then
                
                local a = string.find(_Parameter, ";")
                if a then
                    if Network.GetDesiredLanguage() == "de" then self.Text = string.sub(_Parameter, 1, a-1)
                    else self.Text = string.sub(_Parameter, a+1)
                    end
                else
                    self.Text = _Parameter
                end
                
	elseif (_Index == 1) then
        
                local a = string.find(_Parameter, ";")
                if a then
                    if Network.GetDesiredLanguage() == "de" then self.Title = string.sub(_Parameter, 1, a-1)
                    else self.Title = string.sub(_Parameter, a+1)
                    end
                else
                    self.Title = _Parameter
                end
                
	elseif (_Index == 2) then
		self.Buttons = (_Parameter == "Ok/Cancel") 
	end
        
end

function Goal_Decide:CustomFunction(_Quest)
	
	if not self.LocalExecuted then
	
		if WikiQSB.DialogActive then 
			return; -- don't do anything if any QSB dialog is active
		end
		WikiQSB.DialogActive = true
		local buttons = (self.Buttons and "true") or "nil"
		self.LocalExecuted = true
		Logic.ExecuteInLuaLocalState(string.format([[
			Game.GameTimeSetFactor( GUI.GetPlayerID(), 0 )
			OpenRequesterDialog(%q,
								%q, 
								"Game.GameTimeSetFactor( GUI.GetPlayerID(), 1 ); GUI.SendScriptCommand( 'WikiQSB.Goal_Decide.Result = true ')",
								%s ,
								"Game.GameTimeSetFactor( GUI.GetPlayerID(), 1 ); GUI.SendScriptCommand( 'WikiQSB.Goal_Decide.Result = false ')")
		]], self.Text, "{center} " .. self.Title, buttons))
		
	end
	local result = WikiQSB.Goal_Decide.Result 
	if result ~= nil then
	
		WikiQSB.Goal_Decide.Result = nil
		WikiQSB.DialogActive = false;
		return result
		
	end

end
-- DEBUG: not necessary???
function Goal_Decide:Reset()

	self.LocalExecuted = nil
	
end

function Goal_Decide:GetCustomData(_index)

	if _index == 2 then
		return { "Yes/No", "Ok/Cancel" }
	end
	
end

AddQuestBehavior(Goal_Decide)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_Deliver
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_Deliver = {
	Name = "Goal_Deliver",
	Description = {
		en = "Goal: Deliver goods to quest giver",
		de = "Ziel: Liefere Waren zum Questgeber",
	},
	Parameter = {
		{ ParameterType.Custom, en = "Type of good", de = "Resourcentyp" },
		{ ParameterType.Number, en = "Amount of good", de = "Anzahl der Resource" },
		{ ParameterType.Custom, en = "To different player", de = "Zu anderem Spieler" },
		{ ParameterType.Custom, en = "Ignore capture", de = "Gefangennahme ignorieren" },
	},
}

function Goal_Deliver:GetGoalTable()

	assert( self.GoodAmount > 0, "Error in " .. self.Name .. ": GetGoalTable: Amount is invalid")
	local goodType = Logic.GetGoodTypeID(self.GoodTypeName)
	local category = Logic.GetGoodCategoryForGoodType(goodType)
	if category == GoodCategories.GC_Resource then
		for i = 1, 8 do
			local storeHouse = Logic.GetStoreHouse(i)
			if storeHouse ~= 0	and Logic.GetIndexOnInStockByGoodType(storeHouse, goodType) == -1 then
				Logic.AddGoodToStock(storeHouse, goodType, 0, true, true)
			end
		end
	end	
	return { Objective.Deliver, goodType, self.GoodAmount, self.OverrideTarget, self.IgnoreCapture }

end

function Goal_Deliver:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.GoodTypeName = _Parameter
	elseif (_Index == 1) then	
		self.GoodAmount = _Parameter * 1
	elseif (_Index == 2) then	
		self.OverrideTarget = _Parameter ~= "-" and _Parameter * 1
	elseif (_Index == 3) then	
		self.IgnoreCapture = _Parameter == "+"
	end
	
end

function Goal_Deliver:GetCustomData( _Index )

	local Data = {}
	if _Index == 0 then
		for k, v in pairs( Goods ) do
			if string.find( k, "^G_" ) then
				table.insert( Data, k )
			end
		end
		table.sort( Data )
		
	elseif _Index == 2 then
		table.insert( Data, "-" )
		for i = 1, 8 do
			table.insert( Data, i )
		end
		
	elseif _Index == 3 then
		table.insert( Data, "+" )
		table.insert( Data, "-" )
	else
		assert( false ,"Error in " .. self.Name .. ": GetCustomData: Index is invalid")
	end
	
	return Data
	
end

function Goal_Deliver:GetMsgKey()
	local GoodType = Logic.GetGoodTypeID(self.GoodTypeName)
	local GC = Logic.GetGoodCategoryForGoodType( GoodType )

	local tMapping = {
		[GoodCategories.GC_Clothes] = "Quest_Deliver_GC_Clothes",
		[GoodCategories.GC_Entertainment] = "Quest_Deliver_GC_Entertainment",
		[GoodCategories.GC_Food] = "Quest_Deliver_GC_Food",
		[GoodCategories.GC_Gold] = "Quest_Deliver_GC_Gold",
		[GoodCategories.GC_Hygiene] = "Quest_Deliver_GC_Hygiene",
		[GoodCategories.GC_Medicine] = "Quest_Deliver_GC_Medicine",
		[GoodCategories.GC_Water] = "Quest_Deliver_GC_Water",
		[GoodCategories.GC_Weapon] = "Quest_Deliver_GC_Weapon",
		[GoodCategories.GC_Resource] = "Quest_Deliver_Resources",
	}
	
	if GC then
		local Key = tMapping[GC]
		if Key then
			return Key
		end
	end

-- Quest_Deliver_GC_Gold_Tribute	
	return "Quest_Deliver_Goods"

end

AddQuestBehavior(Goal_Deliver)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_DestroyAllPlayerUnits
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_DestroyAllPlayerUnits = {
	Name = "Goal_DestroyAllPlayerUnits",
	Description = {
		en = "Goal: Destroy all units owned by player (be careful with script entities)",
		de = "Ziel: Zerstoere alle Einheiten eines Spielers (vorsicht mit Script Entities)",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
	},
}

function Goal_DestroyAllPlayerUnits:GetGoalTable()
	
	assert( self.PlayerID <= 8 and self.PlayerID >= 1, "Error in " .. self.Name .. ": GetGoalTable: PlayerID is invalid")
	return { Objective.DestroyAllPlayerUnits, self.PlayerID }

end

function Goal_DestroyAllPlayerUnits:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.PlayerID = _Parameter * 1
	end
	
end

function Goal_DestroyAllPlayerUnits:GetMsgKey()
	local tMapping = {
		[PlayerCategories.BanditsCamp] = "Quest_DestroyPlayers_Bandits",
		[PlayerCategories.City] = "Quest_DestroyPlayers_City",
		[PlayerCategories.Cloister] = "Quest_DestroyPlayers_Cloister",
		[PlayerCategories.Harbour] = "Quest_DestroyEntities_Building",
		[PlayerCategories.Village] = "Quest_DestroyPlayers_Village",
	}
	
	local PlayerCategory = GetPlayerCategoryType(self.PlayerID)
	if PlayerCategory then
		local Key = tMapping[PlayerCategory]
		if Key then
			return Key
		end
	end

	return "Quest_DestroyEntities"

end

AddQuestBehavior(Goal_DestroyAllPlayerUnits)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_DestroyPlayer
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_DestroyPlayer = {
	Name = "Goal_DestroyPlayer",
	Description = {
		en = "Goal: Destroy a player",
		de = "Ziel: Zerstoere einen Spieler",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
	},
}

function Goal_DestroyPlayer:GetGoalTable()

	assert( self.PlayerID <= 8 and self.PlayerID >= 1, "Error in " .. self.Name .. ": GetGoalTable: PlayerID is invalid")
	return { Objective.DestroyPlayers, self.PlayerID }

end

function Goal_DestroyPlayer:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.PlayerID = _Parameter * 1	
	end

end

function Goal_DestroyPlayer:GetMsgKey()
	local tMapping = {
		[PlayerCategories.BanditsCamp] = "Quest_DestroyPlayers_Bandits",
		[PlayerCategories.City] = "Quest_DestroyPlayers_City",
		[PlayerCategories.Cloister] = "Quest_DestroyPlayers_Cloister",
		[PlayerCategories.Harbour] = "Quest_DestroyEntities_Building",
		[PlayerCategories.Village] = "Quest_DestroyPlayers_Village",
	}
	
	local PlayerCategory = GetPlayerCategoryType(self.PlayerID)
	if PlayerCategory then
		local Key = tMapping[PlayerCategory]
		if Key then
			return Key
		end
	end

	return "Quest_DestroyEntities_Building"

end

AddQuestBehavior(Goal_DestroyPlayer)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_DestroyScriptEntity
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_DestroyScriptEntity = {
	Name = "Goal_DestroyScriptEntity",
	Description = {
		en = "Goal: Destroy an entity",
		de = "Ziel: Zerstoere eine Entitaet",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script name", de = "Skriptname" },
	},
}

function Goal_DestroyScriptEntity:GetGoalTable()
	
	assert( not Logic.IsEntityDestroyed(self.Scriptname), "Error in " .. self.Name .. ": GetGoalTable: Entity is missing")
	return {Objective.DestroyEntities, 1, { self.Scriptname } }

end

function Goal_DestroyScriptEntity:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.Scriptname = _Parameter
	end

end

function Goal_DestroyScriptEntity:GetMsgKey()
	if Logic.IsEntityAlive(self.Scriptname) then
		local ID = Logic.GetEntityIDByName(self.Scriptname)
		if ID and ID ~= 0 then
			ID = Logic.GetEntityType( ID )
			if ID and ID ~= 0 then
				if Logic.IsEntityTypeInCategory( ID, EntityCategories.AttackableBuilding ) == 1 then
					return "Quest_DestroyEntities_Building"
					
				elseif Logic.IsEntityTypeInCategory( ID, EntityCategories.AttackableAnimal ) == 1 then
					return "Quest_DestroyEntities_Predators"
					
				elseif Logic.IsEntityTypeInCategory( ID, EntityCategories.Hero ) == 1 then
					return "Quest_Destroy_Leader"
					
				elseif Logic.IsEntityTypeInCategory( ID, EntityCategories.Military ) == 1
					or Logic.IsEntityTypeInCategory( ID, EntityCategories.AttackableSettler ) == 1
					or Logic.IsEntityTypeInCategory( ID, EntityCategories.AttackableMerchant ) == 1  then
					
					return "Quest_DestroyEntities_Unit"
				end
			end
		end
	end
	
	return "Quest_DestroyEntities"
end

AddQuestBehavior(Goal_DestroyScriptEntity)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_DestroySoldiers
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

do
	local GameCallback_EntityKilledOrig = GameCallback_EntityKilled;
	function GameCallback_EntityKilled(_AttackedEntityID, _AttackedPlayerID, _AttackingEntityID, _AttackingPlayerID, _AttackedEntityType, _AttackingEntityType)

		if _AttackedPlayerID ~= 0 and _AttackingPlayerID ~= 0 then
			WikiQSB.Goal_DestroySoldiers[_AttackingPlayerID][_AttackedPlayerID] = WikiQSB.Goal_DestroySoldiers[_AttackingPlayerID][_AttackedPlayerID] or 0
			if Logic.IsEntityTypeInCategory( _AttackedEntityType, EntityCategories.Military ) == 1 
			and Logic.IsEntityInCategory( _AttackedEntityID, EntityCategories.HeavyWeapon) == 0 then 
				WikiQSB.Goal_DestroySoldiers[_AttackingPlayerID][_AttackedPlayerID] = WikiQSB.Goal_DestroySoldiers[_AttackingPlayerID][_AttackedPlayerID] +1
			end
		end
		GameCallback_EntityKilledOrig(_AttackedEntityID, _AttackedPlayerID, _AttackingEntityID, _AttackingPlayerID, _AttackedEntityType, _AttackingEntityType)
	end
end

Goal_DestroySoldiers = {
	Name = "Goal_DestroySoldiers",
	Description = {
		en = "Destroy a given amount of enemy soldiers",
		de = "Zerstoere eine Anzahl gegnerischer Soldaten",
				},
	Parameter = {
		{ParameterType.PlayerID, en = "Attacking Player", de = "Angreifer", },
		{ParameterType.PlayerID, en = "Attacked Player", de = "Verteidiger", },
		{ParameterType.Number, en = "Amount", de = "Anzahl", },
				},
					}

function Goal_DestroySoldiers:GetGoalTable()
	
	return {Objective.Custom2, {self, self.CustomFunction} }

end

function Goal_DestroySoldiers:AddParameter(_Index, _Parameter)

	if (_Index == 0) then
		self.AttackingPlayer = _Parameter * 1
	elseif (_Index == 1) then
		self.AttackedPlayer = _Parameter * 1
	elseif (_Index == 2) then
		self.KillsNeeded = _Parameter * 1
	end

end

function Goal_DestroySoldiers:CustomFunction()

	local currentKills = WikiQSB.Goal_DestroySoldiers[self.AttackingPlayer][self.AttackedPlayer] or 0
	self.SaveAmount = self.SaveAmount or currentKills
	
	return self.KillsNeeded <= currentKills - self.SaveAmount or nil

end

function Goal_DestroySoldiers:DEBUG(_Quest)

	if Logig.GetStoreHouse(self.AttackingPlayer) == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.AttackinPlayer .. " is dead :-(")
		return true
	elseif Logig.GetStoreHouse(self.AttackedPlayer) == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.AttackedPlayer .. " is dead :-(")
		return true
	elseif self.KillsNeeded < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Amount negative")
		return true
	end
	
end

function Goal_DestroySoldiers:Reset()
	
	self.SaveAmount = nil

end

AddQuestBehavior(Goal_DestroySoldiers)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_DestroyType
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_DestroyType = {
	Name = "Goal_DestroyType",
	Description = {
		en = "Goal: Destroy entity types",
		de = "Ziel: Zerstoere Entitaetstypen",
	},
	Parameter = {
		{ ParameterType.Custom, en = "Type name", de = "Typbezeichnung" },
		{ ParameterType.Number, en = "Amount", de = "Anzahl" },
		{ ParameterType.Custom, en = "Player", de = "Spieler" },
	},
}

function Goal_DestroyType:GetGoalTable()

	assert( Entities[self.EntityName] , "Error in " .. self.Name .. ": GetGoalTable: Entity type is invalid.")
	assert( self.Amount > 0, "Error in " .. self.Name .. ": GetGoalTable: Amount is invalid.")
	assert( self.PlayerID >= 0 and self.PlayerID <= 8, "Error in " .. self.Name .. ": GetGoalTable: PlayerID is invalid.")
	return {Objective.DestroyEntities, 2,  Entities[self.EntityName], self.Amount, self.PlayerID, DestroyTypeAmount = self.Amount }

end

function Goal_DestroyType:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.EntityName = _Parameter
	elseif (_Index == 1) then   
		self.Amount = _Parameter * 1
	elseif (_Index == 2) then   
		self.PlayerID = _Parameter * 1
	end

end

function Goal_DestroyType:GetCustomData( _Index )

	local Data = {}
	if _Index == 0 then
		for k, v in pairs( Entities ) do
			if string.find( k, "^[ABU]_" ) then
				table.insert( Data, k )
			end
		end
		table.sort( Data )
	   
	elseif _Index == 2 then
		for i = 0, 8 do
			table.insert( Data, i )
		end
	   
	else
		assert( false , "Error in " .. self.Name .. ": GetCustomData: Index is invalid.")
	end
	
	return Data
	
end

function Goal_DestroyType:GetMsgKey()
	local ID = self.EntityName
	if Logic.IsEntityTypeInCategory( ID, EntityCategories.AttackableBuilding ) == 1 then
		return "Quest_DestroyEntities_Building"

	elseif Logic.IsEntityTypeInCategory( ID, EntityCategories.AttackableAnimal ) == 1 then
		return "Quest_DestroyEntities_Predators"

	elseif Logic.IsEntityTypeInCategory( ID, EntityCategories.Hero ) == 1 then
		return "Quest_Destroy_Leader"

	elseif Logic.IsEntityTypeInCategory( ID, EntityCategories.Military ) == 1
		or Logic.IsEntityTypeInCategory( ID, EntityCategories.AttackableSettler ) == 1
		or Logic.IsEntityTypeInCategory( ID, EntityCategories.AttackableMerchant ) == 1  then

		return "Quest_DestroyEntities_Unit"
	end

	return "Quest_DestroyEntities"
end

AddQuestBehavior(Goal_DestroyType)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_Diplomacy
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_Diplomacy = {
	Name = "Goal_Diplomacy",
	Description = {
		en = "Goal: Reach a diplomatic state",
		de = "Ziel: Diplomatische Beziehungen",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
		{ ParameterType.DiplomacyState, en = "Relation", de = "Beziehung" },
	},
}

function Goal_Diplomacy:GetGoalTable()
	
	assert( self.PlayerID >= 0 and self.PlayerID <= 8, "Error in " .. self.Name .. ": GetGoalTable: PlayerID is invalid.")
	assert( DiplomacyStates[self.DiplState],  "Error in " .. self.Name .. ": GetGoalTable: DiplomacyState is invalid.")
	return { Objective.Diplomacy, self.PlayerID, DiplomacyStates[self.DiplState] }

end

function Goal_Diplomacy:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.PlayerID = _Parameter * 1	
	elseif (_Index == 1) then	
		self.DiplState = _Parameter	
	end

end

function Goal_Diplomacy:GetMsgKey()

	local tMappingAllied = {
		[PlayerCategories.City] = "Quest_Diplomacy_City_Allied",
		[PlayerCategories.Cloister] = "Quest_Diplomacy_Cloister_Allied",
		[PlayerCategories.Village] = "Quest_Diplomacy_Village_Allied",
		}
		
	local tMapping = {
		[PlayerCategories.City] = "Quest_Diplomacy_City_Improve",
		[PlayerCategories.Cloister] = "Quest_Diplomacy_Cloister_Improve",
		[PlayerCategories.Village] = "Quest_Diplomacy_Village_Improve",
	}
	
	local PlayerCategory = GetPlayerCategoryType(self.PlayerID)
	if PlayerCategory then
		local tab = ( DiplomacyStates[self.DiplState] == DiplomacyStates.Allied ) and tMappingAllied or tMapping
		local Key = tab[PlayerCategory]
		if Key then
			return Key
		end
	end

	-- No default message
end

AddQuestBehavior(Goal_Diplomacy)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_DiscoverPlayer
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_DiscoverPlayer = {
	Name = "Goal_DiscoverPlayer",
	Description = {
		en = "Goal: Discover a player",
		de = "Ziel: Entdecke einen Spieler",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
	},
}

function Goal_DiscoverPlayer:GetGoalTable()
	
	assert( self.PlayerID >= 1 and self.PlayerID <= 8, "Error in " .. self.Name .. ": GetGoalTable: PlayerID is invalid.")
	return {Objective.Discover, 2, { self.PlayerID } }

end

function Goal_DiscoverPlayer:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.PlayerID = _Parameter * 1	
	end

end

function Goal_DiscoverPlayer:GetMsgKey()
	local tMapping = {
		[PlayerCategories.BanditsCamp] = "Quest_Discover",
		[PlayerCategories.City] = "Quest_Discover_City",
		[PlayerCategories.Cloister] = "Quest_Discover_Cloister",
		[PlayerCategories.Harbour] = "Quest_Discover",
		[PlayerCategories.Village] = "Quest_Discover_Village",
	}
	
	local PlayerCategory = GetPlayerCategoryType(self.PlayerID)
	if PlayerCategory then
		local Key = tMapping[PlayerCategory]
		if Key then
			return Key
		end
	end

	return "Quest_Discover"

end

AddQuestBehavior(Goal_DiscoverPlayer)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_DiscoverTerritory
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_DiscoverTerritory = {
	Name = "Goal_DiscoverTerritory",
	Description = {
		en = "Goal: Discover a territory",
		de = "Ziel: Entdecke ein Territorium",
	},
	Parameter = {
		{ ParameterType.TerritoryName, en = "Territory", de = "Territorium" },
	},
}

function Goal_DiscoverTerritory:GetGoalTable()

	return { Objective.Discover, 1, { self.TerritoryID  } }

end

function Goal_DiscoverTerritory:AddParameter(_Index, _Parameter)

	if (_Index == 0) then		
		self.TerritoryID = GetTerritoryIDByName(_Parameter)
		assert( self.TerritoryID > 0 , "Error in " .. self.Name .. ": AddParameter: Territory is unkown.")
	end

end

function Goal_DiscoverTerritory:GetMsgKey()

	return "Quest_Discover_Territory"

end

AddQuestBehavior(Goal_DiscoverTerritory)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_EntityDistance
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_EntityDistance = {
	Name = "Goal_EntityDistance",
	Description = {
		en = "Goal: Distance between two entities",
		de = "Ziel: Entfernung zwischen zwei Entities",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Entity 1", de = "Entity 1" },
		{ ParameterType.ScriptName, en = "Entity 2", de = "Entity 2" },
		{ ParameterType.Custom, en = "Relation", de = "Relation" },
		{ ParameterType.Number, en = "Distance", de = "Entfernung" },
	},
}

function Goal_EntityDistance:GetGoalTable()

	return { Objective.Custom2, {self, self.CustomFunction} }

end

function Goal_EntityDistance:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.Entity1 = _Parameter
	elseif (_Index == 1) then	
		self.Entity2 = _Parameter
	elseif (_Index == 2) then	
		self.bRelSmallerThan = _Parameter == "<"
	elseif (_Index == 3) then	
		self.Distance = _Parameter * 1
	end
	
end

function Goal_EntityDistance:CustomFunction()
	
	if Logic.IsEntityDestroyed( self.Entity1 ) or Logic.IsEntityDestroyed( self.Entity2 ) then
		return false
	end

	local ID1 = Logic.GetEntityIDByName( self.Entity1 )
	local ID2 = Logic.GetEntityIDByName( self.Entity2 )
	local InRange = Logic.CheckEntitiesDistance( ID1, ID2, self.Distance )
	
	return self.bRelSmallerThan == InRange or nil
	
end

function Goal_EntityDistance:DEBUG(_Quest)
	
	if Logic.IsEntityDestroyed( self.Entity1 ) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entität " .. self.Entity1 .. " is missing")
		return true
	elseif Logic.IsEntityDestroyed( self.Entity2 ) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entität " .. self.Entity2 .. " is missing")
		return true
	elseif self.Distance < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Distance is negative")
		return true
	end
	
end

function Goal_EntityDistance:GetCustomData( _Index )

	local Data = {}
	if _Index == 2 then
		
		table.insert( Data, ">" )
		table.insert( Data, "<" )
		
	else
		assert( false , "Error in " .. self.Name .. ": GetCustomData: Index is invalid.")
	end
	
	return Data
	
end

AddQuestBehavior(Goal_EntityDistance)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_Festivals
-- User generated Old McDonald
------------------------------------------------------------------------------------------------------------------------------

Goal_Festivals = {
	Name = "Goal_Festivals",
	Description = {
		en = "Goal: The player has to start the given number of festivals.",
		de = "Ziel: Der Spieler muss eine gewisse Zahl Feste gestartet haben."
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
		{ ParameterType.Number, en = "Number of festivals", de = "Anzahl der Feste" }
	}
};

function Goal_Festivals:GetGoalTable()

	 return { Objective.Custom2, self, self.CustomFunction };

end

function Goal_Festivals:AddParameter(_index, _parameter)

	if _index == 0 then
		 self.PlayerID = tonumber(_parameter);
	else
		 assert(_index == 1, "Error in " .. self.Name .. ": AddParameter: Index is invalid.");
		 self.NeededFestivals = tonumber(_parameter);
	end

end

function Goal_Festivals:CustomFunction()
	
	if Logic.GetStoreHouse( self.PlayerID ) == 0  then
		return false 
	end
	local tablesOnFestival = {Logic.GetPlayerEntities(self.PlayerID, Entities.B_TableBeer, 5,0)}
	local amount = 0
	for k=2, #tablesOnFestival do
		local tableID = tablesOnFestival[k]
		if Logic.GetIndexOnOutStockByGoodType(tableID, Goods.G_Beer) ~= -1 then
			local goodAmountOnMarketplace = Logic.GetAmountOnOutStockByGoodType(tableID, Goods.G_Beer)
			amount = amount + goodAmountOnMarketplace
		end
	end
	if not self.FestivalStarted and amount > 0 then
		self.FestivalStarted = true
		self.FestivalCounter = (self.FestivalCounter and self.FestivalCounter + 1) or 1
		if self.FestivalCounter >= self.NeededFestivals then
			self.FestivalCounter = nil
			return true
		end
	elseif amount == 0 then
		self.FestivalStarted = false
	end

end

function Goal_Festivals:DEBUG(_Quest)
	
	if Logic.GetStoreHouse( self.PlayerID ) == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.PlayerID .. " is dead :-(")
		return true
	elseif GetPlayerCategoryType(self.PlayerID) ~= PlayerCategories.City then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ":  Player "..  self.PlayerID .. " is no city")
		return true
	elseif self.NeededFestivals < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Number of Festivals is negative")
		return true
	end
	
end

function Goal_Festivals:Reset()

	self.FestivalCounter = nil
	self.FestivalStarted = nil

end

function Goal_Festivals:GetIcon()

	return "Technologies.R_Festival"

end

AddQuestBehavior(Goal_Festivals)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_GoodAmount
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_GoodAmount = {
	Name = "Goal_GoodAmount",
	Description = {
		en = "Goal: Obtain an amount of goods - either by trading or producing them",
		de = "Ziel: Beschaffe eine Anzahl Waren - entweder durch Handel oder eigene Produktion",
	},
	Parameter = {
		{ ParameterType.Custom, en = "Type of good", de = "Warentyp" },
		{ ParameterType.Number, en = "Amount", de = "Anzahl" },
		{ ParameterType.Custom, en = "Relation", de = "Relation" },
	},
}

function Goal_GoodAmount:GetGoalTable()

	local GoodType = Logic.GetGoodTypeID(self.GoodTypeName)
	return { Objective.Produce, GoodType, self.GoodAmount, self.bRelSmallerThan }

end

function Goal_GoodAmount:AddParameter(_Index, _Parameter)

	if (_Index == 0) then
		self.GoodTypeName = _Parameter
	elseif (_Index == 1) then
		self.GoodAmount = _Parameter * 1
	elseif  (_Index == 2) then
		self.bRelSmallerThan = _Parameter == "<"
	end
	
end

function Goal_GoodAmount:GetCustomData( _Index )

	local Data = {}
	if _Index == 0 then
		for k, v in pairs( Goods ) do
			if string.find( k, "^G_" ) then
				table.insert( Data, k )
			end
		end
		table.sort( Data )
		
	elseif _Index == 2 then
		table.insert( Data, ">=" )
		table.insert( Data, "<" )
		
	else
		assert( false , "Error in " .. self.Name .. ": GetCustomData: Index is invalid.")
	end
	
	return Data
	
end

AddQuestBehavior(Goal_GoodAmount)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_InstantFailure
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_InstantFailure = {
	Name = "Goal_InstantFailure",
	Description = {
		en = "Goal: Instant failure (Hint: use this quest type for using reprisals as \"reward\")",
		de = "Ziel: Direkter Misserfolg (Tipp: mit dieser Quest koennen Vergeltungen als \"Lohn\" verwendet werden)",
	},
}

function Goal_InstantFailure:GetGoalTable()

	return { Objective.DummyFail }

end

AddQuestBehavior(Goal_InstantFailure)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_InstantSuccess
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_InstantSuccess = {
	Name = "Goal_InstantSuccess",
	Description = {
		en = "Goal: Instant success (Hint: use this quest type for conversations between players)",
		de = "Ziel: Direkter Erfolg (Tipp: mit dieser Quest koennen Konversationen zwischen Spielern nachgebildet werden)",
	},
}

function Goal_InstantSuccess:GetGoalTable()

	return { Objective.Dummy }

end

AddQuestBehavior(Goal_InstantSuccess)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_KnightDistance
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_KnightDistance = {
	Name = "Goal_KnightDistance",
	Description = {
		en = "Goal: Bring the knight close to a given entity",
		de = "Ziel: Bringe den Ritter nah an eine bestimmte Entitaet",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script name", de = "Skriptname" },
		{ ParameterType.Custom, en = "Show marker", de = "Markierung anzeigen" },
	},
}

function Goal_KnightDistance:GetGoalTable()

	assert(not Logic.IsEntityDestroyed(self.Scriptname), "Error in " .. self.Name .. ": GetGoalTable: Entity is missing.")
	return {Objective.Distance, Logic.GetKnightID(1), self.Scriptname, ShowQuestmarker = ({ Yes = true, No = false })[self.ShowQuestmarker] }

end

function Goal_KnightDistance:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.Scriptname = _Parameter
	elseif _Index == 1 then
		self.ShowQuestmarker = _Parameter
	end

end

function Goal_KnightDistance:GetCustomData(_Index)
	if _Index == 1 then
		return { "Default", "Yes", "No" }
	end
end

AddQuestBehavior(Goal_KnightDistance)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_KnightTitle
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_KnightTitle = {
	Name = "Goal_KnightTitle",
	Description = {
		en = "Goal: Reach a given knight title",
		de = "Ziel: Erreiche einen vorgegebenen Titel",
	},
	Parameter = {
		{ ParameterType.KnightTitle, en = "Knight title", de = "Titel" },
	},
}

function Goal_KnightTitle:GetGoalTable()

	assert( KnightTitles[self.KnightTitle], "Error in " .. self.Name .. ": GetGoalTable: KinghtTitle is invalid")
	return {Objective.KnightTitle, KnightTitles[self.KnightTitle] }

end

function Goal_KnightTitle:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.KnightTitle = assert( GetNameOfKeyInTable( KnightTitles, tonumber( string.match(_Parameter, "^(%d+) ") ) ), "Error in " .. self.Name .. ": GetGoalTable: KinghtTitle is invalid" )
	end

end

function Goal_KnightTitle:GetMsgKey()

	return "Quest_KnightTitle"

end

AddQuestBehavior(Goal_KnightTitle)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_MapScriptFunction
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_MapScriptFunction = {
	Name = "Goal_MapScriptFunction",
	Description = {
		en = "Goal: Calls a function within the map script which checks the goal condition (return true: success, return false: failure, return nil: undetermined",
		de = "Ziel: Ruft eine Funktion aus dem Kartenscript auf welche die Zielbedingung ueberprueft (return true: Erfolg, return false: Fehlschlag, return nil: (noch) unbestimmt",
	},
	Parameter = {
		{ ParameterType.Default, en = "Function name", de = "Funktionsname" },
	},
}

function Goal_MapScriptFunction:GetGoalTable()

	return { Objective.Custom2,{self, self.CustomFunction} }

end

function Goal_MapScriptFunction:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.FuncName = _Parameter
	end

end

function Goal_MapScriptFunction:CustomFunction(_Quest)

	if not self.FuncName then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": No function name ")
	elseif type(_G[self.FuncName]) ~= "function" then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Function does not exist: " .. self.FuncName)
	else
		return _G[self.FuncName](_Quest.Identifier)
	end

end

function Goal_MapScriptFunction:GetMsgKey()

	local KeyFuncName = self.FuncName .. "_MsgKey"
	if _G[KeyFuncName] then
		return _G[KeyFuncName]()
	end
	
end

function Goal_MapScriptFunction:GetIcon()

	local KeyFuncName = self.FuncName .. "_Icon"
	if _G[KeyFuncName] then
		return _G[KeyFuncName]()
	end
	
end

AddQuestBehavior(Goal_MapScriptFunction)
------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_NoChange
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_NoChange = {
	Name = "Goal_NoChange",
	Description = {
		en = "Goal: No change - this doesn't change the quest state (Hint: Use reward functions in other quests to change the state of this quest)",
		de = "Ziel: Keine Veraenderung - der Questzustand wird nicht veraendert (Tipp: Andere Quest sollten den Zustand dieses Quests mittels einer Reward-Funktion veraendern)",
	},
}

function Goal_NoChange:GetGoalTable()

	return { Objective.NoChange }

end

AddQuestBehavior(Goal_NoChange)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_Produce
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_Produce = {
	Name = "Goal_Produce",
	Description = {
		en = "Goal: Produce an amount of goods",
		de = "Ziel: Produziere eine Anzahl Waren",
	},
	Parameter = {
		{ ParameterType.RawGoods, en = "Type of good", de = "Resourcentyp" },
		{ ParameterType.Number, en = "Amount of good", de = "Anzahl der Resource" },
	},
}

function Goal_Produce:GetGoalTable()

	assert( self.GoodAmount > 0, "Error in " .. self.Name .. ": GetGoalTable: Amount is invalid")
	local GoodType = Logic.GetGoodTypeID(self.GoodTypeName)
	return { Objective.Produce, GoodType, self.GoodAmount }

end

function Goal_Produce:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.GoodTypeName = _Parameter
	elseif (_Index == 1) then	
		self.GoodAmount = _Parameter * 1
	end
	
end

function Goal_Produce:GetMsgKey()

	return "Quest_Produce"

end

AddQuestBehavior(Goal_Produce)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_Protect
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_Protect = {
	Name = "Goal_Protect",
	Description = {
		en = "Goal: Protect an entity (entity needs a script name",
		de = "Ziel: Beschuetze eine Entitaet (Entitaet benoetigt einen Skriptnamen)",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script name", de = "Skriptname" },
	},
}

function Goal_Protect:GetGoalTable()

	assert(not Logic.IsEntityDestroyed(self.Scriptname), "Error in " .. self.Name .. ": GetGoalTable: Entity is missing.")
	return {Objective.Protect, { self.Scriptname }}

end

function Goal_Protect:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.Scriptname = _Parameter
	end

end

function Goal_Protect:GetMsgKey()

	if Logic.IsEntityAlive(self.Scriptname) then
		local ID = Logic.GetEntityIDByName(self.Scriptname)
		if ID and ID ~= 0 then
			ID = Logic.GetEntityType( ID )
			if ID and ID ~= 0 then
				if Logic.IsEntityTypeInCategory( ID, EntityCategories.AttackableBuilding ) == 1 then
					return "Quest_Protect_Building"
					
				elseif Logic.IsEntityTypeInCategory( ID, EntityCategories.SpecialBuilding ) == 1 then
					local tMapping = {
						[PlayerCategories.City] = "Quest_Protect_City",
						[PlayerCategories.Cloister] = "Quest_Protect_Cloister",
						[PlayerCategories.Village] = "Quest_Protect_Village",
					}
					
					local PlayerCategory = GetPlayerCategoryType( Logic.EntityGetPlayer(Logic.GetEntityIDByName(self.Scriptname)) )
					if PlayerCategory then
						local Key = tMapping[PlayerCategory]
						if Key then
							return Key
						end
					end
					
					return "Quest_Protect_Building"
					
				elseif Logic.IsEntityTypeInCategory( ID, EntityCategories.Hero ) == 1 then
					return "Quest_Protect_Knight"
				
				elseif Logic.IsEntityTypeInCategory( ID, EntityCategories.AttackableMerchant ) == 1 then
					return "Quest_Protect_Cart"
				
				end
			end
		end
	end
	
	return "Quest_Protect"
end

AddQuestBehavior(Goal_Protect)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_QuestsEX
-- User Generated OldMcDonald
------------------------------------------------------------------------------------------------------------------------------

Goal_QuestsEX = {
	Name = "Goal_QuestsEX",
	Description = {
		en = "Goal: Win two quests, one failed quest will cause a fail of this one",
		de = "Ziel: Gewinne zwei Quests, eine verlorene wird hier Niederlage verursachen",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name 1", de = "Questname 1" },
		{ ParameterType.QuestName, en = "Quest name 2", de = "Questname 2" },
	},
}

function Goal_QuestsEX:GetGoalTable()

	 return { Objective.Custom2, {self, self.CustomFunction} }

end

function Goal_QuestsEX:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.QuestName1 = _Parameter	
	elseif (_Index == 1) then	
		self.QuestName2 = _Parameter	
	end

end

function Goal_QuestsEX:CustomFunction()

	if IsValidQuest(self.QuestName1) and IsValidQuest(self.QuestName2) then

		local QuestID1 = GetQuestByName(self.QuestName1)
		local QuestID2 = GetQuestByName(self.QuestName2)
		if (Quests[QuestID1].Result == QuestResult.Success) and (Quests[QuestID2].Result == QuestResult.Success) then
			return true
		elseif (Quests[QuestID1].Result == QuestResult.Failure) or (Quests[QuestID2].Result == QuestResult.Failure) then
			return false
		end
		
	end

	return nil
end

function Goal_QuestsEX:DEBUG(_Quest)
	
	if not IsValidQuest(self.QuestName1) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest " .. self.QuestName1 .. " not found.")
		return true
	elseif not IsValidQuest(self.QuestName2) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest " .. self.QuestName2 .. " not found.")
		return true
	end
	
end

AddQuestBehavior(Goal_QuestsEX)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_RampartAgainstAttackFromPlayer
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_RampartAgainstAttackFromPlayer = {
	Name = "Goal_RampartAgainstAttackFromPlayer",
	Description = {
		en = "Goal: Build a rampart against attacks from a player",
		de = "Ziel: Baue ein Bollwerk gegen Angriffe von einem Spieler",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
	},
}

function Goal_RampartAgainstAttackFromPlayer:GetGoalTable()

	return { Objective.Custom2, {self, self.CustomFunction} }

end

function Goal_RampartAgainstAttackFromPlayer:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.PlayerID = _Parameter * 1
	end

end

function Goal_RampartAgainstAttackFromPlayer:CustomFunction()

	if (Logic.GetStoreHouse(1) == 0) then
		return true
	end
	if (Logic.GetStoreHouse(self.PlayerID) == 0) then
		return true
	end

	local x,y = Logic.GetBuildingApproachPosition(Logic.GetStoreHouse(1))
	local Sector1 = Logic.GetPlayerSectorAtPosition(self.PlayerID, x, y)
	
	x, y = Logic.GetBuildingApproachPosition(Logic.GetStoreHouse(self.PlayerID))		
	local Sector2 = Logic.GetPlayerSectorAtPosition(self.PlayerID, x, y)
  
	if Sector1 ~= Sector2 then
		return true
	end

	return nil
	
end

function Goal_RampartAgainstAttackFromPlayer:DEBUG(_Quest)

	if (Logic.GetStoreHouse(self.PlayerID) == 0) then
		yam(_Quest.Identifier .. ": Minor Error in " .. self.Name .. ": Player " .. self.PlayerID .. " is dead :-(")
		return true
	end

end

function Goal_RampartAgainstAttackFromPlayer:GetMsgKey()

	return "Quest_Create_Wall"

end

function Goal_RampartAgainstAttackFromPlayer:GetIcon()

	return "Technologies.R_Wall"	 

end

AddQuestBehavior(Goal_RampartAgainstAttackFromPlayer)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_RandomRequestsFromVillages
-- User generated by Saladin
------------------------------------------------------------------------------------------------------------------------------
Goal_RandomRequestsFromVillages = {
	Name = "Goal_RandomRequestsFromVillages",
	Description = {
		en = "The given IDs request in random order a random good in a given Time. If player fails more than allowed, the Quest is loosed",
		de = "Die angegebenen IDs fordern in zufaelliger Reihenfolge ein zufaelliges Gut. Die Quest ist verloren, wenn mehr als angegeben nicht geliefert wird",
					},
	Parameter = {
		{ParameterType.Number, en = "Maximum amount of demand", de = "Maximale Hoehe der Forderung", },
		{ParameterType.Number, en = "Minimum amount of demand", de = "Minimale Hoehe der Forderung", },
		{ParameterType.Number, en = "Number of Fails allowed", 	de = "Anzahl der erlaubten Fehlversuche", },
		{ParameterType.Number, en = "Time for delivery", de = "Lieferzeit", },
		{ParameterType.Number, en = "Time between QuestsStarts", de = "Zeit zwischen Start der Quests", },
				},
	Goods = {
		{	Technologies = {"G_Wood", "R_Gathering", "R_Woodcutter", },
			Names = { de = "Holz", en = "wood", },
			},
		{	Technologies = {"G_Broom", "R_Gathering", "R_Woodcutter", "R_Hygiene", "R_BroomMaker", },
			Names = { de = "Besen", en ="brooms", } ,
			},
		{	Technologies = {"G_Stone", "R_Gathering", "R_StoneQuarry", },
			Names = { de = "Stein", en = "stones", },
			},
		{	Technologies = {"G_Carcass", "R_Gathering", "R_HuntersHut", },
			Names = { de = "Wild", en = "carcass", },
			},
		{	Technologies = {"G_Leather", "R_Gathering", "R_HuntersHut", "R_Clothes", "R_Tanner", },
			Names = { de = "Lederkleidung", en = "leather clothes", } ,
			},
		{	Technologies = {"G_Sausage", "R_Gathering", "R_HuntersHut", "R_Nutrition", "R_Butcher", },
			Names = { de = "Wurst", en = "sausage", },
			},
		{	Technologies = {"G_Soap", "R_Gathering", "R_HuntersHut", "R_Hygiene", "R_Soapmaker", },
			Names = { de = "Seife", en = "soap", },
			},
		{	Technologies = {"G_Wool", "R_Gathering", "R_SheepFarm", },
			Names = { de = "Wolle", en = "wool", },
			},
		{	Technologies = {"G_Clothes", "R_Gathering", "R_SheepFarm", "R_Clothes", "R_Weaver", },
			Names = { de = "Wollkleidung", en = "woolen clothes", },
			},
		{	Technologies = {"G_Grain", "R_Gathering", "R_GrainFarm", },
			Names = { de = "Weizen", en = "grain", },
			},
		{	Technologies = {"G_Bread", "R_Gathering", "R_GrainFarm", "R_Nutrition", "R_Bakery", },
			Names = { de = "Brot", en = "bread", },
			},
		{	Technologies = {"G_Milk","R_Gathering", "R_CattleFarm", },
			Names = { de = "Milch", en = "milk", },
			},
		{	Technologies = {"G_Cheese", "R_Gathering", "R_CattleFarm", "R_Nutrition", "R_Dairy", },
			Names = { de = "Käse", en = "cheese", },
			},
		{	Technologies = {"G_RawFish", "R_Gathering", "R_FishingHut", },
			Names = { de = "rohen Fisch", en = "raw fish", },
			},
		{	Technologies = {"G_SmokedFish", "R_Gathering", "R_FishingHut", "R_Nutrition", "R_SmokeHouse", },
			Names = { de = "Räucherfisch", en = "smoked fish", },
			},
		{	Technologies = {"G_Honeycomb", "R_Gathering", "R_Beekeeper", },
			Names = { de = "Honig", en = "honeycombs", },
			},
		{	Technologies = {"G_Beer", "R_Gathering", "R_Beekeeper", "R_Entertainment", "R_Tavern", },
			Names = { de = "Bier", en = "beer", },
			},
		{	Technologies = {"G_Herb", "R_Gathering", "R_HerbGatherer", },
			Names = { de = "Kräuter", en = "herbs", },
			},
		{	Technologies = {"G_Medicine", "R_Gathering", "R_HerbGatherer", "R_Hygiene", "R_Medicine", },
			Names = { de = "Medizin", en = "medicine", },
			},
		{	Technologies = {"G_Iron", "R_Gathering", "R_IronMine", },
			Names = { de = "Eisen", en = "iron", },
			},
			},
	Titles = {
				[0] = { dem = "Ehrenwerter Ritter! Als Lehnsherr", def = "Ehrenwerte Ritterin! Als Lehnsherrin", 
						enm = "Knight", enf = "Lady", },
				[1] = { dem = "Ehrenwerte Landvogt! Als Lehnsherr", def = "Ehrenwerte Landvögtin! Als Lehnsherrin", 
						enm = "Sheriff", enf = "Sheriff",},
				[2] = { dem = "Ehrenwerter Baron! Als Lehnsherr", def = "Ehrenwerte Baronin! Als Lehnsherrin", 
						enm = "Baron", enf = "Baroness", },
				[3] = { dem = "Ehrenwerter Graf! Als Lehnsherr", def = "Ehrenwerte Gräfin! Als Lehnsherrin",
						enm = "Count", enf = "Countess", },
				[4] = { dem = "Ehrenwerter Marquis! Als Lehnsherr", def = "Ehrenwerte Marquise! Als Lehnsherrin",
						enm = "Marques", enf = "Marquise", },
				[5] = { dem = "Ehrenwerter Herzog! Als Lehnsherr", def = "Ehrenwerte Herzogin! Als Lehnsherrin",
						enm = "Duke", enf = "Duchess", },
				[6] = { dem = "Ehrenwerter Erzherzog! Als Lehnsherr", def = "Ehrenwerte Erzherzogin! Als Lehnsherrin", 
						enm = "Archduke", enf = "Archduchess", },
			},
	Messages = {
				de = {
				Start = "%s ersuchen wir Euch um Hilfe und die Lieferung von %s Einheiten %s, die wir sehr dringend benötigen.",
				Warning = " {@color:255,0,0}Wenn Ihr dieses mal nicht liefert, wird das Folgen haben",
				Success = "Wir bedanken uns ausserordentlich für die Hilfe, die Ihr uns zuteil werden lasst. Der König hat mit Euch eine weise und gute Wahl getroffen.",
				Failure = "Unsere Bewohner sind sehr enttäuscht, einige Hitzköpfe haben eine Eingabe an den König verfasst. Ich bedauere dies sehr, aber Ihr seid selbst schuld.",
				Lost = "{@color:255,0,0}Nun ist das Mass voll!",
					},
				en = { 
				Start = "Honorable %s! We search your help as our liege and ask for %s units of %s which we need desparately.", 
				Warning = " {@color:255,0,0}If you don't help us this time, you'll have to face the consequences",
				Success = "Thank you very much for your assistance. The king was wise to choose you as our liege.",
				Failure = "Our citizens are very disappointed. Some hotspurs have send a message to the king about your failure. I'm sorry about that, but it is your responsibility to help us.",
				Lost = "{@color:255,0,0}You have failed us too many times.",
					},
				},
	MonthBeforeMonsoon = 6,			--June
}

function Goal_RandomRequestsFromVillages:GetGoalTable()

	return {Objective.Custom2, {self, self.CustomFunction},}
		
end

function Goal_RandomRequestsFromVillages:AddParameter(_Index, _Parameter)

	if (_Index==0) then
		self.MaxAmount = _Parameter*1
	elseif (_Index==1) then
		self.MinAmount = _Parameter*1
	elseif (_Index==2) then
		self.NumberOfFails = _Parameter*1
	elseif (_Index==3) then
		self.TimeForDelivery = _Parameter*1
	elseif (_Index==4) then 
		self.TimeBetweenQuests = _Parameter*1
	else
		assert(false, "Error in " .. self.Name .. ": AddParameter: Index is invalid")
	end
		
end

function Goal_RandomRequestsFromVillages:CustomFunction(_Quest)
	
	if not WikiQSB.Goal_RandomQuestsFromVillages.Running then
		--creating the Quest
		local questID = QuestTemplate:New("QuestRequest".._Quest.Identifier, 
											1, 1,
											{{ Objective.Deliver, Goods.G_Wood, 1 }},
											{{ Triggers.Custom2, {nil, function() end}}},
											self.TimeForDelivery) 
		g_QuestNameToID[Quests[questID].Identifier]= questID
		self.Quest = Quests[questID]
		WikiQSB.Goal_RandomQuestsFromVillages.Running = _Quest.Identifier
	
		--gathering possible beggars and checking if there are at least two of them
		if not self.Beggars then
			self.Beggars = {}
			for i = 2, 8 do
				--maybe even harbors and/or cities?? Parameter??
				local isBeggar = GetPlayerCategoryType(i) == PlayerCategories.Cloister or GetPlayerCategoryType(i) == PlayerCategories.Village
				self.Beggars[#self.Beggars+1] = (isBeggar and i) or nil
			end
			if #self.Beggars < 2 then
				self:Reset(_Quest)
				return true	-- don´t do this with less than two beggars, 
			end
		end
		-- parameter checking
		if self.MinAmount > self.MaxAmount then
		   Logic.DEBUG_AddNote("Debug: Quest: ".. _Quest.Identifier or "<unnamed>" .. "Goal_RandomRequestsFromVillages: Min > Max?")
		   local temp = self.MinAmount
		   self.MinAmount = self.MaxAmount
		   self.MaxAmount = temp
		end
	elseif WikiQSB.Goal_RandomQuestsFromVillages.Running ~= _Quest.Identifier then
		Logic.DEBUG_AddNote("DEBUG: Goal_RandomRequestsFromVillages already started by "..WikiQSB.Goal_RandomQuestsFromVillages.Running)
		Logic.DEBUG_AddNote("DEBUG: Quest: ".._Quest.Identifier.." is interrupted")
		self:Interrupt()
	end

	if not self.QuestStarted then
		if not (Logic.GetClimateZone() == ClimateZones.Asia and Logic.GetCurrentMonth() == self.MonthBeforeMonsoon) then
	
			local player = _Quest.ReceivingPlayer
			local territoryCount = GetNumberOfTerritoriesOfPlayer(player)
			if territoryCount > 0 then				--DEBUG:TESTING
				
				--preparing GoodsTable, checking if the player is allowed to produce the single good AND has some of it
				local goods = {}
				for i = 1, #self.Goods do
					local checkGoodAmount = GetPlayerGoodsInSettlement(Goods[self.Goods[i].Technologies[1]], player, true)
					if checkGoodAmount and checkGoodAmount > 0 then --Player has some of that good
						local allowedGood = true
						for j = 2, #self.Goods[i].Technologies do
							if Logic.TechnologyGetState(player, Technologies[self.Goods[i].Technologies[j]]) ~= TechnologyStates.Researched then
								allowedGood = false --don´t use this good this time
								--break
							end
						end
						goods[#goods+1] = (allowedGood and self.Goods[i]) or nil
					end
				end
				if #goods < 2 then	-- Player has not enough to deliver
					return --maybe later 
				end
			
				-- choosing beggar, should be different from the old one and alive ;-)
				local rBeggar
				repeat
					rBeggar = Logic.GetRandom(#self.Beggars)+1 
					local storeHouse = Logic.GetStoreHouse(self.Beggars[rBeggar])
					if (storeHouse == 0 or Logic.IsEntityDestroyed(storeHouse)) then
						table.remove(self.Beggars, rBeggar)
						if #self.Beggar < 2 then 
							self:Reset(_Quest)
							return true 
						end
					end
				until self.OldrBeggar ~= rBeggar
				local Beggar = self.Beggars[rBeggar]
				local playerSectorType = PlayerSectorTypes.Civil
				local isReachable = CanEntityReachTarget(Beggar,
														Logic.GetStoreHouse(player),
														Logic.GetStoreHouse(Beggar),
														nil, playerSectorType)
				if isReachable == false 
				or Diplomacy_GetRelationBetween(player, self.Beggars[rBeggar]) == DiplomacyStates.Enemy
				then 
					return-- try again, maybe another beggar is chosen or just waiting for removing obstacles
				end
				self.OldrBeggar = rBeggar

				-- choosing Good, should be different from the old one and wanted by the beggar (looks odd if a sheepfarmer wants wool)
				local rGood, blacklistedGood
				repeat
					blacklistedGood = false
					rGood = Logic.GetRandom(#goods)+1
					for i=1, MerchantSystem.TradeBlackList[Beggar][0] do
						local GoodTypeInList = MerchantSystem.TradeBlackList[Beggar][i]
						if GoodTypeInList == Goods[goods[rGood].Technologies[1]] then
							table.remove(goods, rgood)
							if #goods<2 then 
								return -- try again, hopefully another beggar will be chosen
							end
							blacklistedGood = true
						end
					end
				until self.OldrGood ~= rGood and not blacklistedGood
				self.OldrGood = rGood			
				local language = WikiQSB.GameLanguage
				local goodType, goodText = Goods[goods[rGood].Technologies[1]], Umlaute(goods[rGood].Names[language])

				-- choosing amount 
				local amountFactor = (territoryCount > 7 and 3) or (territoryCount > 5 and 2) or 1
				-- ToDo: i don´t like the territory factor at all.  Have to think of another way adjusting the amount or forget about adjusting at all
				local rAmount = Logic.GetRandom((self.MaxAmount*amountFactor)-(self.MinAmount*amountFactor)+1)
				local Amount = rAmount + (self.MinAmount * amountFactor)

				--Adjusting the Quest
				self.Quest.SendingPlayer = Beggar --SendingPlayer
				self.Quest.ReceivingPlayer = player --ReceivingPlayer
				self.Quest.Objectives[1].Completed = nil
				self.Quest.Objectives[1].Data[1] = goodType
				self.Quest.Objectives[1].Data[2] = Amount
				self.Quest.Objectives[1].Data[3] = nil
				self.Quest.Objectives[1].Data[4] = nil
				self.Quest.Objectives[1].Data[5] = nil
				local knightID = Logic.GetKnightID(player)
				local knightType = Logic.GetEntityType(knightID)
				local females = { "U_KnightHealing", "U_KnightPlunder", "U_KnightSabatta", "U_KnightSaraya", "U_KnightKhana",}
				local gender = "m"
				for k = 1, #females do
					if knightType == Entities[females[k]] then
						gender = "f"
					end
				end
				local currentTitle = Logic.GetKnightTitle(player)
				local title = self.Titles[currentTitle][language .. gender]
				local msg = self.Messages[language]
				local lastChance = self.FailureCounter and self.FailureCounter >= self.NumberOfFails-1 or self.NumberOfFails == 1
				self.Quest.QuestStartMsg = string.format(Umlaute(msg.Start), title, Amount, goodText)..((lastChance and Umlaute(msg.Warning)) or "" )
				self.Quest.QuestSuccessMsg = Umlaute(msg.Success)
				self.Quest.QuestFailureMsg = (lastChance and Umlaute(msg.Lost)) or Umlaute(msg.Failure)
				self.Quest.Result = nil
				local OldQuestState = self.Quest.State
				self.Quest.State = QuestState.NotTriggered
				Logic.ExecuteInLuaLocalState("LocalScriptCallback_OnQuestStatusChanged("..self.Quest.Index..")")
				if OldQuestState == QuestState.Over then
					Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_SECOND, "", QuestTemplate.Loop, 1, 0, { self.Quest.QueueID })
				end
				self.Quest:SetMsgKeyOverride()
				self.Quest:SetIconOverride()
				self.Quest:Trigger()					
				self.QuestStarted = Logic.GetTime() 
			end
		end
	else --Quest was generated, now check it

		local quest = self.Quest
		if quest.State == QuestState.Over then 
			if quest.Result == QuestResult.Failure and not self.FailureCounted then --player didn´t deliver 
				self.FailureCounter = (self.FailureCounter and self.FailureCounter + 1) or 1
				self.FailureCounted = true
				if self.FailureCounter >= self.NumberOfFails then
					self:Reset(_Quest)
					return false -- You loose
				end
			elseif Logic.GetTime() >= self.QuestStarted + self.TimeBetweenQuests then
				self.QuestStarted = nil
				self.PayWasSent = nil
				self.FailureCounted = nil
			end
		elseif quest.State == QuestState.Active 
		and quest.Objectives[1].Data[3] 
		and not Logic.IsEntityDestroyed(quest.Objectives[1].Data[3]) -- check that the trade gathering has succeeded
		and not self.PayWasSent
		then
			local sender = quest.SendingPlayer
			local BuildingID = Logic.GetHeadquarters(sender)
			if BuildingID == 0 then
				BuildingID = Logic.GetStoreHouse(sender)
			end 
			local payment = math.ceil(quest.Objectives[1].Data[2] / 9 * MerchantSystem.BasePrices[quest.Objectives[1].Data[1]])
			local cartID = Logic.CreateEntityAtBuilding(Entities.U_GoldCart, BuildingID, 0, quest.ReceivingPlayer)
			Logic.HireMerchant(cartID, quest.ReceivingPlayer, Goods.G_Gold, payment, quest.ReceivingPlayer)
			self.PayWasSent = true
		end
	end
end

function Goal_RandomRequestsFromVillages:Reset(_Quest)
	if 	WikiQSB.Goal_RandomQuestsFromVillages.Running == _Quest.Identifier then
		WikiQSB.Goal_RandomQuestsFromVillages.Running = nil
		self.Beggars = nil
		self.Quest = nil
		self.OldrGood = nil
		self.OldrBeggar = nil
		self.PayWasSent = nil
		self.FailureCounted = nil
	end
end

AddQuestBehavior(Goal_RandomRequestsFromVillages)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_Refill
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_Refill = {
	Name = "Goal_Refill",
	Description = {
		en = "Goal: Refill an object using a geologist",
		de = "Ziel: Lasse ein Objekt durch einen Geologen wieder auffuellen",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script name", de = "Skriptname" },
	},
	RequiresExtraNo = 1,
}

function Goal_Refill:GetGoalTable()

	assert(not Logic.IsEntityDestroyed(self.Scriptname), "Error in " .. self.Name .. ": GetGoalTable: Entity is missing.")
	return { Objective.Refill, { Logic.GetEntityIDByName(self.Scriptname) } }

end

function Goal_Refill:AddParameter(_Index, _Parameter)

	if (_Index == 0) then
		self.Scriptname = _Parameter
	end

end

if g_GameExtraNo >= 1 then
	AddQuestBehavior(Goal_Refill)
end

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_ResourceAmount
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_ResourceAmount = {
	Name = "Goal_ResourceAmount",
	Description = {
		en = "Goal: Reach a specified amount of resources in a doodad",
		de = "Ziel: Erreiche eine bestimmte Anzahl Ressourcen in einem Doodad",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script name", de = "Skriptname" },
		{ ParameterType.Custom, en = "Relation", de = "Relation" },
		{ ParameterType.Number, en = "Amount", de = "Menge" },
	},
}

function Goal_ResourceAmount:GetGoalTable()

	return { Objective.Custom2, {self, self.CustomFunction} }

end

function Goal_ResourceAmount:AddParameter(_Index, _Parameter)

	if (_Index == 0) then
		self.Scriptname = _Parameter
	elseif (_Index == 1) then	
		self.bRelSmallerThan = _Parameter == "<"
	elseif (_Index == 2) then	
		self.Amount = _Parameter * 1
	end

end

function Goal_ResourceAmount:CustomFunction()

	local ID = Logic.GetEntityIDByName(self.Scriptname)
	if ID and ID ~= 0 and Logic.GetResourceDoodadGoodType(ID) ~= 0 then
	
		local HaveAmount = Logic.GetResourceDoodadGoodAmount(ID)
		if ( self.bRelSmallerThan and HaveAmount < self.Amount ) or ( not self.bRelSmallerThan and HaveAmount > self.Amount ) then
		
			return true
			
		end
		
	end

end

function Goal_ResourceAmount:DEBUG(_Quest)

	if Logic.IsEntityDestroyed( self.Scriptname ) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity ".. self.Scriptname .. " is missing")
		return true
	elseif self.Amount < 0 then 
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Amount is negative")
		return true
	end

end

function Goal_ResourceAmount:GetCustomData( _Index )

	local Data = {}

	if _Index == 1 then
		table.insert( Data, ">" )
		table.insert( Data, "<" )
	else
		assert( false , "Error in " .. self.Name .. ": GetCustomData: Index is invalid.")
	end
	
	return Data
	
end

AddQuestBehavior(Goal_ResourceAmount)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_SatisfyNeed
-- BB Original - Corresponding Icons fixed
------------------------------------------------------------------------------------------------------------------------------

Goal_SatisfyNeed = {
	Name = "Goal_SatisfyNeed",
	Description = {
		en = "Goal: Satisfy a need",
		de = "Ziel: Erfuelle ein Beduerfnis",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
		{ ParameterType.Need, en = "Need", de = "Beduerfnis" },
		
	},
}

function Goal_SatisfyNeed:GetGoalTable()
	
	assert( Needs[self.Need], "Error in " .. self.Name .. ": GetGoalTable: Need is invalid" )
	assert( self.PlayerID >= 1 and self.PlayerID <= 8, "Error in " .. self.Name .. ": GetGoalTable: PlayerId is invalid")
	return { Objective.SatisfyNeed, Needs[self.Need], self.PlayerID }

end

function Goal_SatisfyNeed:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.PlayerID = _Parameter * 1	
	elseif (_Index == 1) then	
		self.Need = _Parameter
	end

end

function Goal_SatisfyNeed:GetMsgKey()
	local tMapping = {
		[Needs.Clothes] = "Quest_SatisfyNeed_Clothes",
		[Needs.Entertainment] = "Quest_SatisfyNeed_Entertainment",
		[Needs.Nutrition] = "Quest_SatisfyNeed_Food",
		[Needs.Hygiene] = "Quest_SatisfyNeed_Hygiene",
	}
	
	local Key = tMapping[Needs[self.Need]]
	if Key then
		return Key
	end
	
	-- No default message
end

AddQuestBehavior(Goal_SatisfyNeed)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_SettlersNumber
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_SettlersNumber = {
	Name = "Goal_SettlersNumber",
	Description = {
		en = "Goal: Get a given amount of settlers",
		de = "Ziel: Bekomme eine bestimmte Anzahl von Siedlern",
	},
	Parameter = {
		{ ParameterType.Number, en = "Amount", de = "Anzahl" },
	},
}

function Goal_SettlersNumber:GetGoalTable()

	assert( self.SettlersAmount > 0, "Error in " .. self.Name .. ": GetGoalTable: Settler amount is invalid")
	return {Objective.SettlersNumber, 1, self.SettlersAmount }

end

function Goal_SettlersNumber:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.SettlersAmount = _Parameter * 1
	end

end

function Goal_SettlersNumber:GetMsgKey()

	return "Quest_NumberSettlers"

end

AddQuestBehavior(Goal_SettlersNumber)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_SoldierCount
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_SoldierCount = {
	Name = "Goal_SoldierCount",
	Description = {
		en = "Goal: Create a specified number of soldiers",
		de = "Ziel: Erstelle eine Anzahl Soldaten",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
		{ ParameterType.Custom, en = "Relation", de = "Relation" },
		{ ParameterType.Number, en = "Number of soldiers", de = "Anzahl Soldaten" },
	},
}

function Goal_SoldierCount:GetGoalTable()

	return { Objective.Custom2, {self, self.CustomFunction} }

end

function Goal_SoldierCount:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.PlayerID = _Parameter * 1
	elseif (_Index == 1) then	
		self.bRelSmallerThan = _Parameter == "<"
	elseif (_Index == 2) then	
		self.NumberOfUnits = _Parameter * 1
	end
	
end

function Goal_SoldierCount:CustomFunction()
	
	local NumSoldiers = Logic.GetCurrentSoldierCount( self.PlayerID )
	if ( self.bRelSmallerThan and NumSoldiers < self.NumberOfUnits )
		or ( not self.bRelSmallerThan and NumSoldiers > self.NumberOfUnits ) then
		
		return true
		
	end
	
end

function Goal_SoldierCount:DEBUG(_Quest)

	if Logic.GetStoreHouse(self.PlayerID) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player ".. self.PlayerID .. " is dead:-(")
		return true
	elseif self.NumberOfSoldiers < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Number of soldiers is negative")
		return true
	end
	
end

function Goal_SoldierCount:GetCustomData( _Index )

	local Data = {}
	if _Index == 1 then
		
		table.insert( Data, ">" )
		table.insert( Data, "<" )
		
	else
		assert( false , "Error in " .. self.Name .. ": GetCustomData: Index is invalid")
	end
	
	return Data
	
end

function Goal_SoldierCount:GetIcon()

	-- "Technologies.R_Military"
	return "QuestTypes.CreateMilitary"

end

function Goal_SoldierCount:GetMsgKey()

	return "Quest_Create_Unit"

end

AddQuestBehavior(Goal_SoldierCount)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_Spouses
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_Spouses = {
	Name = "Goal_Spouses",
	Description = {
		en = "Goal: Get a given amount of spouses",
		de = "Ziel: Erreiche eine bestimmte Ehefrauenanzahl",
	},
	Parameter = {
		{ ParameterType.Number, en = "Amount", de = "Anzahl" },
	},
}

function Goal_Spouses:GetGoalTable()

	assert( self.SpousesAmount > 0, "Error in " .. self.Name .. ": GetGoalTable: Amount is invalid")
	return {Objective.Spouses, self.SpousesAmount }

end

function Goal_Spouses:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.SpousesAmount = _Parameter * 1
	end

end

function Goal_Spouses:GetMsgKey()

	return "Quest_NumberSpouses"

end

AddQuestBehavior(Goal_Spouses)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_Steal
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_Steal = {
	Name = "Goal_Steal",
	Description = {
		en = "Goal: Steal information from another players castle",
		de = "Ziel: Stehle Informationen aus der Burg eines Spielers",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
	},
}

function Goal_Steal:GetGoalTable()

	local Target = Logic.GetHeadquarters(self.PlayerID)
	if not Target or Target == 0 then
		Target = Logic.GetStoreHouse(self.PlayerID)
	end
	if not( Target and Target ~= 0 ) then
		assert(false, "Error in Goal_Steal: Player" .. self.PlayerID .. " is dead. :-(")
	end
	return {Objective.Steal, 1, { Target } }

end

function Goal_Steal:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.PlayerID = _Parameter * 1
	end

end

function Goal_Steal:GetMsgKey()
	-- Quest_Steal_Gold
	return "Quest_Steal_Info"

end

AddQuestBehavior(Goal_Steal)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_TributeBandit
-- User Generated
------------------------------------------------------------------------------------------------------------------------------
-- Dies ist kein herkoemmliches Goal
-- Es sollte immer versteckt eingesetzt werden, da es selbsttaetig weitere sichtbare Quests erzeugt.
-- Die Texte fuer diese Quests muessen in die NachrichtenParameter diese Verhaltens.
-- Der fordernde Player muss als Questgeber angegeben werden, typischerweise hier Banditen.
-- Es laeuft bis der Questgeber zerstoert wurde
-- Wird bezahlt, werden die Banditen zum Handelspartner (Handelsangebote muessen normal festgelegt werden) 
-- Wird nicht bezahlt, werden die Banditen feindlich.
-- Dieses Goal kann typischerweise mit einem Trigger_PlayerDiscovered verknuepft werden

Goal_TributeBandit = {
	Name = "Goal_TributeBandit",
	Description = {
		en = "Goal: AI requests periodical Tribute for better Diplomacy",
		de = "Goal: Die KI fordert einen regelmaessigen Tribut fuer bessere Diplomatie",
				},
	Parameter = {
		{ ParameterType.Number, en = "Amount", de = "Menge", },
		{ ParameterType.Custom, en = "Length of Period in month", de = "Dauer der Periode in Monaten", },
		{ ParameterType.Number, en = "Time to pay Tribut in seconds", de = "Zeit fuer Tribut in Sekunden", },
		{ ParameterType.Default, en = "Start Message for Tribut Quest", de = "Startnachricht fuer Tributquest", },
		{ ParameterType.Default, en = "Success Message for Tribut Quest", de = "Erfolgsnachricht fuer Tributquest", },
		{ ParameterType.Default, en = "Failure Message for Tribut Quest", de = "Niederlagenachricht fuer Tributquest", },
		{ ParameterType.Custom, en = "Restart if failed to pay", de = "Wiederholung bei Nichtbezahlen" },
				},
					}

function Goal_TributeBandit:GetGoalTable()
	
	return {Objective.Custom2, {self, self.CustomFunction} }

end

function Goal_TributeBandit:AddParameter(_Index, _Parameter)
	
	if (_Index == 0) then
		self.Amount = _Parameter * 1
	elseif (_Index == 1) then
		self.PeriodLength = _Parameter * 150
	elseif (_Index == 2) then
		self.TributTime = _Parameter * 1
	elseif (_Index == 3) then
		self.StartMsg = _Parameter
	elseif (_Index == 4) then
		self.SuccessMsg = _Parameter
	elseif (_Index == 5) then	
		self.FailureMsg = _Parameter
	elseif (_Index == 6) then
		self.RestartAtFailure = (_Parameter == "Yes")
	end

end

function Goal_TributeBandit:CustomFunction(_QuestID)
	
	if not self.Time then 
		if self.PeriodLength - 150 < self.TributTime then
			Logic.DEBUG_AddNote("Goal_TributeBandit: TributTime too long")
		end
	end
	if not self.QuestStarted then
		self.QuestStarted = QuestTemplate:New(_QuestID.Identifier.."TributeBanditQuest" , _QuestID.SendingPlayer, _QuestID.ReceivingPlayer, 
									{{ Objective.Deliver, {Goods.G_Gold, self.Amount}}},
									{{ Triggers.Time, 0 }},
									self.TributTime,
									nil, nil, nil, nil, true, true,
									nil,
									self.StartMsg,
									self.SuccessMsg,
									self.FailureMsg
									)
		self.Time = Logic.GetTime()
	end
	local TributeQuest = Quests[self.QuestStarted]
	if self.QuestStarted and TributeQuest.State == QuestState.Over and not self.RestartQuest then
		if TributeQuest.Result ~= QuestResult.Success then
			SetDiplomacyState( _QuestID.ReceivingPlayer, _QuestID.SendingPlayer, DiplomacyStates.Enemy)
			if not self.RestartAtFailure then
				return false
			end
		else
			SetDiplomacyState( _QuestID.ReceivingPlayer, _QuestID.SendingPlayer, DiplomacyStates.TradeContact)
		end
		
		self.RestartQuest = true
	end	
	local storeHouse = Logic.GetStoreHouse(_QuestID.SendingPlayer)
	if (storeHouse == 0 or Logic.IsEntityDestroyed(storeHouse)) then
		if self.QuestStarted and Quests[self.QuestStarted].State == QuestState.Active then
			Quests[self.QuestStarted]:Interrupt()
		end
		return true
	end
	if self.QuestStarted and self.RestartQuest and ( (Logic.GetTime() - self.Time) >= self.PeriodLength ) then
		TributeQuest.Objectives[1].Completed = nil
		TributeQuest.Objectives[1].Data[3] = nil
		TributeQuest.Objectives[1].Data[4] = nil
		TributeQuest.Objectives[1].Data[5] = nil
		TributeQuest.Result = nil
		TributeQuest.State = QuestState.NotTriggered 
		Logic.ExecuteInLuaLocalState("LocalScriptCallback_OnQuestStatusChanged("..TributeQuest.Index..")")
		Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_SECOND, "", QuestTemplate.Loop, 1, 0, { TributeQuest.QueueID })
		self.Time = Logic.GetTime()
		self.RestartQuest = nil
	end
end

function Goal_TributeBandit:DEBUG(_Quest)

	if self.Amount < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Amount is negative")
		return true
	elseif self.PeriodLength < 1 or PeriodLength > 60 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": PeriodLength is wrong")
		return true
	end
	
end

function Goal_TributeBandit:Reset()

	self.Time = nil
	self.QuestStarted = nil
	self.RestartQuest = nil
	
end

function Goal_TributeBandit:GetCustomData(_index)

	if (_index == 1) then
		return { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"}
	elseif (_index == 6) then
		return { "Yes", "No" }	
	end

end

AddQuestBehavior(Goal_TributeBandit)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_TributeClaim
-- User Generated
------------------------------------------------------------------------------------------------------------------------------
-- Dies ist kein herkoemmliches Goal
-- Es sollte immer versteckt eingesetzt werden, da es selbsttaetig weitere sichtbare Quests erzeugt.
-- Die Texte fuer diese Quests muessen in die NachrichtenParameter diese Verhaltens.
-- Der fordernde Player muss als Questgeber angegeben werden.
-- Es laeuft bis der Questgeber zerstoert wurde.
-- Quests werden nur dann erzeugt, wenn der QuestEmpfaenger das Territorium im Besitz hat.
-- Wird nicht bezahlt, wird automatisch der Aussenposten zerstoert udn das Territorium wird wieder neutral.
-- Dieses Goal kann typischerweise mit einem Trigger_AlwaysActive verknuepft werden.

Goal_TributeClaim = {
	Name = "Goal_TributeClaim",
	Description = {
		en = "Goal: AI requests periodical Tribute for a specified Territory",
		de = "Goal: Die KI fordert einen regelmaessigen Tribut fuer ein Territorium",
				},
	Parameter = {
		{ ParameterType.TerritoryName, en = "Territory", de = "Territorium", },
		{ ParameterType.PlayerID, en = "PlayerID", de = "PlayerID", },
		{ ParameterType.Number, en = "Amount", de = "Menge", },
		{ ParameterType.Custom, en = "Length of Period in month", de = "Dauer der Periode in Monaten", },
		{ ParameterType.Number, en = "Time to pay Tribut in seconds", de = "Zeit fuer Tribut in Sekunden", },
		{ ParameterType.Default, en = "Start Message for TributQuest", de = "Startnachricht fuer Tributquest", },
		{ ParameterType.Default, en = "Success Message for TributQuest", de = "Erfolgsnachricht fuer Tributquest", },
		{ ParameterType.Default, en = "Failure Message for TributQuest", de = "Niederlagenachricht fuer Tributquest", },
		{ ParameterType.Number, en = "How often to pay (0 = forerver)", de = "Wie oft muss gezahlt werden (0 = ewig)", },
		{ ParameterType.Custom, en = "Other Owner cancels the Quest", de = "Anderer Besitzer beendet die Quest", },
				},
					}

function Goal_TributeClaim:GetGoalTable()
	
	return {Objective.Custom2, {self, self.CustomFunction} }

end

function Goal_TributeClaim:AddParameter(_Index, _Parameter)
	
	if (_Index == 0) then
		self.TerritoryID = GetTerritoryIDByName(_Parameter)
	elseif (_Index == 1) then
		self.PlayerID = _Parameter * 1
	elseif (_Index == 2) then
		self.Amount = _Parameter * 1
	elseif (_Index == 3) then
		self.PeriodLength = _Parameter * 150
	elseif (_Index == 4) then
		self.TributTime = _Parameter * 1
	elseif (_Index == 5) then
		self.StartMsg = _Parameter
	elseif (_Index == 6) then
		self.SuccessMsg = _Parameter
	elseif (_Index == 7) then	
		self.FailureMsg = _Parameter
	elseif (_Index == 8) then
		self.HowOften = _Parameter * 1
	elseif (_Index == 9) then
		self.OtherOwnerCancels = (_Parameter == "Yes")
	end

end

function Goal_TributeClaim:CustomFunction(_QuestID)
	
	if Logic.GetTerritoryPlayerID(self.TerritoryID) == _QuestID.ReceivingPlayer then
	
		if self.OtherOwner then
			self:RestartTributeQuest()
			self.OtherOwner = nil
		end
		
		if not self.Time and self.PeriodLength -20 < self.TributTime then
				Logic.DEBUG_AddNote("Goal_TributeClaim: TributTime too long")
		end
		
		if not self.Quest then 
		
			local QuestID = QuestTemplate:New(_QuestID.Identifier.."TributeClaimQuest" , self.PlayerID, _QuestID.ReceivingPlayer, 
										{{ Objective.Deliver, {Goods.G_Gold, self.Amount}}},
										{{ Triggers.Time, 0 }},
										self.TributTime,
										nil, nil, nil, nil, true, true,
										nil,
										self.StartMsg,
										self.SuccessMsg,
										self.FailureMsg
										)
			self.Quest = Quests[QuestID]
			self.Time = Logic.GetTime()

		else
		
			if self.Quest.State == QuestState.Over then
			
				if self.Quest.Result == QuestResult.Failure then
				
					DestroyEntity(Logic.GetTerritoryAcquiringBuildingID( self.TerritoryID ))
					Logic.SetTerritoryPlayerID( self.TerritoryID, 0)
					self.Time = nil
					self.Quest.State = false
					
				elseif Logic.GetTime() >= self.Time + self.PeriodLength then
					
					if self.HowOften and self.HowOften ~= 0 then
						
						self.TributeCounter = self.TributeCounter or 0
						self.TributeCounter = self.TributeCounter + 1
						
						if self.TributeCounter >= self.HowOften then
						
							return false
						
						end
						
					end
					
					self:RestartTributeQuest()
					
				end
			
			elseif self.Quest.State == false then
				
				self:RestartTributeQuest()
				
			end
			
		end	
	
	elseif Logic.GetTerritoryPlayerID(self.TerritoryID) ~= 0 then
	
		if self.Quest.State == QuestState.Active then
			
			self.Quest:Interrupt()
				
		end
		
		if self.OtherOwnerCancels then
	
			_QuestID:Interrupt()
			
		end
		
		self.OtherOwner = true
		
	elseif Logic.GetTerritoryPlayerID(self.TerritoryID) == 0 and self.Quest then
		
		if self.Quest.State == QuestState.Active then
			
			self.Quest:Interrupt()
				
		end
		
		self.OtherOwner = true
		
	end
	
	local storeHouse = Logic.GetStoreHouse(self.PlayerID)
	if (storeHouse == 0 or Logic.IsEntityDestroyed(storeHouse)) then
	
		if self.Quest and self.Quest.State == QuestState.Active then
		
			self.Quest:Interrupt()
			
		end
		
		return true
		
	end
	
end

function Goal_TributeClaim:DEBUG(_Quest)

	if self.TerritoryID == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Unknown Territory")
		return true
	elseif not self.Quest and Logic.GetStoreHouse(self.PlayerID) == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.PlayerID .. " is dead. :-(")
		return true
	elseif self.Amount < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Amount is negative")
		return true
	elseif self.PeriodLength < 1 or self.PeriodLength > 60 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Period Length is wrong")
		return true
	elseif self.HowOften < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": HowOften is negative")
		return true
	end

end

function Goal_TributeClaim:Reset()
	
	self.Quest = nil
	self.Time = nil
	self.OtherOwner = nil

end

function Goal_TributeClaim:RestartTributeQuest()

	self.Time = Logic.GetTime()
	self.Quest.Objectives[1].Completed = nil
	self.Quest.Objectives[1].Data[3] = nil
	self.Quest.Objectives[1].Data[4] = nil
	self.Quest.Objectives[1].Data[5] = nil
	self.Quest.Result = nil
	self.Quest.State = QuestState.NotTriggered
	Logic.ExecuteInLuaLocalState("LocalScriptCallback_OnQuestStatusChanged("..self.Quest.Index..")")
	Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_SECOND, "", QuestTemplate.Loop, 1, 0, { self.Quest.QueueID })
	
end

function Goal_TributeClaim:GetCustomData(_index)

	if (_index == 3) then
		return { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"}
	elseif (_index == 9) then
		return { "No", "Yes" }
	end

end

AddQuestBehavior(Goal_TributeClaim)

------------------------------------------------------------------------------------------------------------------------------
--
-- Goal_UnitsOnTerritory
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Goal_UnitsOnTerritory = {
	Name = "Goal_UnitsOnTerritory",
	Description = {
		en = "Goal: Place a certain amount of units on a territory",
		de = "Ziel: Platziere eine bestimmte Anzahl Einheiten auf einem Gebiet",
	},
	Parameter = {
		{ ParameterType.TerritoryNameWithUnknown, en = "Territory", de = "Territorium" },
		{ ParameterType.Custom, en = "Player", de = "Spieler" },
		{ ParameterType.Custom, en = "Category", de = "Kategorie" },
		{ ParameterType.Custom, en = "Relation", de = "Relation" },
		{ ParameterType.Number, en = "Number of units", de = "Anzahl Einheiten" },
	},
}

function Goal_UnitsOnTerritory:GetGoalTable()

	return { Objective.Custom2, {self, self.CustomFunction} }

end

function Goal_UnitsOnTerritory:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.TerritoryID = GetTerritoryIDByName(_Parameter)
	elseif (_Index == 1) then	
		self.PlayerID = _Parameter * 1
	elseif (_Index == 2) then	
		self.Categorie = _Parameter
	elseif (_Index == 3) then	
		self.bRelSmallerThan = _Parameter == "<"
	elseif (_Index == 4) then	
		self.NumberOfUnits = _Parameter * 1
	end
	
end

function Goal_UnitsOnTerritory:CustomFunction(_Quest)

	local Categorie = assert( EntityCategories[self.Categorie], _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Entity category is invalid." )
	if self.TerritoryID == 0 then
		if self.PlayerID == -1 then
			local NumLast = 0
			for i = 1, 8 do
				NumLast = NumLast + Logic.GetNumberOfPlayerEntitiesInCategory( i, Categorie )

				if self.bRelSmallerThan then
					if NumLast >= self.NumberOfUnits then
						return	-- Can't have less than X units later on if there are more than X units already
					end
				else
					if NumLast > self.NumberOfUnits then
						return true
					end
				end
			end
		
			if self.bRelSmallerThan and NumLast < self.NumberOfUnits then
				return true
			end
			
		else
			local NumUnits = Logic.GetNumberOfPlayerEntitiesInCategory( self.PlayerID, Categorie )
			if ( self.bRelSmallerThan and NumUnits < self.NumberOfUnits )
				or ( not self.bRelSmallerThan and NumUnits > self.NumberOfUnits ) then
				
				return true
				
			end
		end
		
	else
		local Units
		local NumLast = 0
		repeat
			Units = { Logic.GetEntitiesOfCategoryInTerritory( self.TerritoryID, self.PlayerID, Categorie, NumLast ) }
			NumLast = NumLast + #Units
			
			if self.bRelSmallerThan then
				if NumLast >= self.NumberOfUnits then
					return	-- Can't have less than X units later on if there are more than X units already
				end
			else
				if NumLast > self.NumberOfUnits then
					return true
				end
			end
			
		until #Units == 0
		
		local Offset = NumLast
		if self.PlayerID == -1 then  -- Check neutral units too
			repeat
				Units = { Logic.GetEntitiesOfCategoryInTerritory( self.TerritoryID, 0, Categorie, NumLast - Offset ) }
				NumLast = NumLast + #Units
				
				if self.bRelSmallerThan then
					if NumLast >= self.NumberOfUnits then
						return	-- Can't have less than X units later on if there are more than X units already
					end
				else
					if NumLast > self.NumberOfUnits then
						return true
					end
				end
				
			until #Units == 0
		end
		
		if self.bRelSmallerThan and NumLast < self.NumberOfUnits then
			return true
		end
	end
	
	return
end

function Goal_UnitsOnTerritory:DEBUG(_Quest)

	if Logic.GetStoreHouse(self.PlayerID) == 0 
	and self.PlayerID ~= 0
	and self.PlayerID ~= -1 
	then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.PlayerID .. " is dead. :-(")
		return true
	elseif not EntityCategories[self.Categorie] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Wrong Category " .. self.Categorie)
		return true
	elseif self.NumberOfUnits < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": NumberOfUnits is negative")
		return true
	end

end

function Goal_UnitsOnTerritory:GetCustomData( _Index )

	local Data = {}
	if _Index == 1 then
		table.insert( Data, -1 )
		for i = 1, 8 do
			table.insert( Data, i )
		end
		
	elseif _Index == 2 then
		for k, v in pairs( EntityCategories ) do
			if not string.find( k, "^G_" ) then
			table.insert( Data, k )
		end
		end
		table.sort( Data );
		
	elseif _Index == 3 then
		table.insert( Data, ">" )
		table.insert( Data, "<" )
		
	else
		assert( false, "Error in " .. self.Name .. ": GetCustomData: Index is invalid." )
	end
	
	return Data
	
end

AddQuestBehavior(Goal_UnitsOnTerritory)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_AI_Agressiveness
-- User Generated OldMcDonald
------------------------------------------------------------------------------------------------------------------------------

Reward_AI_Agressiveness = {
	Name = "Reward_AI_Agressiveness",
	Description = {
		en = "Sets the AI player's agressiveness.",
		de = "Legt die Agressivitaet des KI-Spielers fest."
	},
	Parameter =
	{
		{ ParameterType.PlayerID, en = "AI player", de = "KI-Spieler" },
		{ ParameterType.Custom, en = "Agressiveness (1-3)", de = "Aggressivitaet (1-3)" }
	}
};
 
function Reward_AI_Agressiveness:GetRewardTable()

	return {Reward.Custom, {self, self.CustomFunction} };

end
 
function Reward_AI_Agressiveness:AddParameter(_Index, _Parameter)
	
	if _Index == 0 then
		self.AIPlayer = _Parameter * 1;
	elseif _Index == 1 then
		self.Agressiveness = tonumber(_Parameter);
	end

end
 
function Reward_AI_Agressiveness:CustomFunction()

	local player = (PlayerAIs[self.AIPlayer] 
		or AIPlayerTable[self.AIPlayer] 
		or AIPlayer:new(self.AIPlayer, AIPlayerProfile_City));
	PlayerAIs[self.AIPlayer] = player;
	if self.Agressiveness >= 2 then
		player.m_ProfileLoop = AIProfile_Skirmish;
		player.Skirmish = player.Skirmish or {};
		player.Skirmish.Claim_MinTime = SkirmishDefault.Claim_MinTime + (self.Agressiveness - 2) * 390;
		player.Skirmish.Claim_MaxTime = player.Skirmish.Claim_MinTime * 2;
	else
		player.m_ProfileLoop = AIPlayerProfile_City;
	end

end

function Reward_AI_Agressiveness:DEBUG(_Quest)
	
	if self.AIPlayer < 2 or Logic.GetStoreHouse(self.AIPlayer) == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.PlayerID .. " is wrong")
		return true
	end
 
end
 
function Reward_AI_Agressiveness:GetCustomData(_Index)

	assert(_Index == 1, "Error in " .. self.Name .. ": GetCustomData: Index is invalid.");
	return { "1", "2", "3" };

end

AddQuestBehavior(Reward_AI_Agressiveness)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_AI_BuildOrder
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_AI_BuildOrder = {
	Name = "Reward_AI_BuildOrder",
	Description = {
		en = "Reward: Sets a new AI construction level",
		de = "Lohn: Legt eine neue Ausbaustufe fuer die KI fest",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "AI Player", de = "KI Spieler" },
		{ ParameterType.Number, en = "Level", de = "Stufe" },
	},
}

function Reward_AI_BuildOrder:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_AI_BuildOrder:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.AIPlayerID = _Parameter * 1
	elseif (_Index == 1) then	
		self.Level = _Parameter * 1
	end

end

function Reward_AI_BuildOrder:CustomFunction()

	AICore.SetNumericalFact( self.AIPlayerID, "BPMX", self.Level )   
	
end

function Reward_AI_BuildOrder:DEBUG(_Quest)

	if self.AIPlayerID <= 1 or self.AIPlayerID >= 8 or Logic.PlayerGetIsHumanFlag(self.AIPlayerID) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.PlayerID .. " is wrong or human.")
		return true
	end

end

AddQuestBehavior(Reward_AI_BuildOrder)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_AI_SetEnemy
-- User Genereated OldMcDonald
------------------------------------------------------------------------------------------------------------------------------

Reward_AI_SetEnemy = {
	Name = "Reward_AI_SetEnemy",
	Description = {
		en = "Sets the enemy of an AI player (the AI only handles one enemy properly).",
		de = "Legt den Feind eines KI-Spielers fest (die KI behandelt nur einen Feind korrekt)."
	},
	Parameter =
	{
		{ ParameterType.PlayerID, en = "AI player", de = "KI-Spieler" },
		{ ParameterType.PlayerID, en = "Enemy", de = "Feind" }
	}
};
 
function Reward_AI_SetEnemy:GetRewardTable()

	return {Reward.Custom, {self, self.CustomFunction} };

end
 
function Reward_AI_SetEnemy:AddParameter(_Index, _Parameter)

	if _Index == 0 then
		self.AIPlayer = _Parameter * 1;
	elseif _Index == 1 then
		self.Enemy = _Parameter * 1;
	end

end
 
function Reward_AI_SetEnemy:CustomFunction()

	local player = PlayerAIs[self.AIPlayer];
	if player and player.Skirmish then
		player.Skirmish.Enemy = self.Enemy;
	end

end

function Reward_AI_SetEnemy:DEBUG(_Quest)
	
	if self.AIPlayer <= 1 or self.AIPlayer >= 8 or Logic.PlayerGetIsHumanFlag(self.AIPlayer) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.AIPlayer .. " is wrong")
		return true
	end
	
end
AddQuestBehavior(Reward_AI_SetEnemy)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_AI_SpawnAndAttackArea
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_AI_SpawnAndAttackArea = {
	Name = "Reward_AI_SpawnAndAttackArea",
	Description = {
		en = "Reward: Spawns AI troops and attacks everything within the specified area, except for the players main buildings",
		de = "Lohn: Erstellt KI Truppen und greift ein angegebenes Gebiet an, nicht aber die Hauptgebauede eines Spielers",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "AI Player", de = "KI Spieler" },
		{ ParameterType.ScriptName, en = "Spawn point", de = "Erstellungsort" },
		{ ParameterType.ScriptName, en = "Target", de = "Ziel" },
		{ ParameterType.Number, en = "Radius", de = "Radius" },
		{ ParameterType.Number, en = "Sword", de = "Schwert" },
		{ ParameterType.Number, en = "Bow", de = "Bogen" },
		{ ParameterType.Custom, en = "Soldier type", de = "Soldatentyp" },
		{ ParameterType.Custom, en = "Reuse troops", de = "Verwende bestehende Truppen" },
	},
}

function Reward_AI_SpawnAndAttackArea:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_AI_SpawnAndAttackArea:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.AIPlayerID = _Parameter * 1
	elseif (_Index == 1) then	
		self.Spawnpoint = _Parameter
	elseif (_Index == 2) then	
		self.TargetName = _Parameter
	elseif (_Index == 3) then	
		self.Radius = _Parameter * 1
	elseif (_Index == 4) then	
		self.NumSword = _Parameter * 1
	elseif (_Index == 5) then	
		self.NumBow = _Parameter * 1
	elseif (_Index == 6) then	
		if _Parameter == "Normal" then
			self.TroopType = false
		elseif _Parameter == "RedPrince" then
			self.TroopType = true
		elseif _Parameter == "Bandit" then
			self.TroopType = 2
		elseif _Parameter == "Cultist" then
			self.TroopType = 3
		else
			assert(false, "Error in " .. self.Name .. ": AddParameter: Soldier type is invalid")
		end
	elseif (_Index == 7) then	
		self.ReuseTroops = _Parameter == "+"
	end

end

function Reward_AI_SpawnAndAttackArea:GetCustomData( _Index )

	local Data = {}
	if _Index == 6 then
		table.insert( Data, "Normal" )
		table.insert( Data, "RedPrince" )
		table.insert( Data, "Bandit" )
		if g_GameExtraNo and g_GameExtraNo >= 1 then
			table.insert( Data, "Cultist" )
		end
		
	elseif _Index == 7 then
		table.insert( Data, "-" )
		table.insert( Data, "+" )
	   
	else
		assert( false, "Error in " .. self.Name .. ": GetCustomData: Index is invalid" )
	end
	
	return Data
	
end

function Reward_AI_SpawnAndAttackArea:CustomFunction()

	if Logic.IsEntityAlive( self.TargetName ) then
		local TargetID = Logic.GetEntityIDByName( self.TargetName )
		AIScript_SpawnAndRaidSettlement( self.AIPlayerID, TargetID, self.Spawnpoint, self.Radius, self.NumSword, self.NumBow, self.TroopType, self.ReuseTroops )
	end
   
end

function Reward_AI_SpawnAndAttackArea:DEBUG(_Quest)
	-- Is it still necessary that Spawn and Target are buildings???
	if self.AIPlayerID < 2 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.AIPlayerID .. " is wrong")
		return true
	elseif Logic.IsEntityDestroyed(self.Spawnpoint) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.Spawnpoint .. " is missing")
		return true
	elseif Logic.IsEntityDestroyed(self.TargetName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.TargetName .. " is missing")
		return true
	elseif self.Radius < 1 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Radius is to small or negative")
		return true
	elseif self.NumSword < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Number of Swords is negative")
		return true
	elseif self.NumBow < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Number of Bows is negative")
		return true
	elseif self.NumBow + self.NumSword < 1 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": No Soldiers?")
		return true
	end

end

AddQuestBehavior(Reward_AI_SpawnAndAttackArea)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_AI_SpawnAndAttackTerritory
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_AI_SpawnAndAttackTerritory = {
	Name = "Reward_AI_SpawnAndAttackTerritory",
	Description = {
		en = "Reward: Spawns AI troops and attacks a territory (Hint: Use for hidden quests as a surprise)",
		de = "Lohn: Erstellt KI Truppen und greift ein Territorium an (Tipp: Fuer eine versteckte Quest als Ueberraschung verwenden)",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "AI Player", de = "KI Spieler" },
		{ ParameterType.ScriptName, en = "Spawn point", de = "Erstellungsort" },
		{ ParameterType.TerritoryName, en = "Territory", de = "Territorium" },
		{ ParameterType.Number, en = "Sword", de = "Schwert" },
		{ ParameterType.Number, en = "Bow", de = "Bogen" },
		{ ParameterType.Number, en = "Catapults", de = "Katapulte" },
		{ ParameterType.Number, en = "Siege towers", de = "Belagerungstuerme" },
		{ ParameterType.Number, en = "Rams", de = "Rammen" },
		{ ParameterType.Number, en = "Ammo carts", de = "Munitionswagen" },
		{ ParameterType.Custom, en = "Soldier type", de = "Soldatentyp" },
		{ ParameterType.Custom, en = "Reuse troops", de = "Verwende bestehende Truppen" },
	},
}

function Reward_AI_SpawnAndAttackTerritory:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_AI_SpawnAndAttackTerritory:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.AIPlayerID = _Parameter * 1
	elseif (_Index == 1) then	
		self.Spawnpoint = _Parameter
	elseif (_Index == 2) then	
		self.TerritoryID = GetTerritoryIDByName(_Parameter)
	elseif (_Index == 3) then	
		self.NumSword = _Parameter * 1
	elseif (_Index == 4) then	
		self.NumBow = _Parameter * 1
	elseif (_Index == 5) then	
		self.NumCatapults = _Parameter * 1
	elseif (_Index == 6) then	
		self.NumSiegeTowers = _Parameter * 1
	elseif (_Index == 7) then	
		self.NumRams = _Parameter * 1
	elseif (_Index == 8) then	
		self.NumAmmoCarts = _Parameter * 1
	elseif (_Index == 9) then	
		if _Parameter == "Normal" then
			self.TroopType = false
		elseif _Parameter == "RedPrince" then
			self.TroopType = true
		elseif _Parameter == "Bandit" then
			self.TroopType = 2
		elseif _Parameter == "Cultist" then
			self.TroopType = 3
		else
			assert(false, "Error in " .. self.Name .. ": AddParameter: Soldier type is invalid")
		end
	elseif (_Index == 10) then	
		self.ReuseTroops = _Parameter == "+"
	end

end

function Reward_AI_SpawnAndAttackTerritory:CustomFunction()

	local TargetID = Logic.GetTerritoryAcquiringBuildingID( self.TerritoryID )
	if TargetID ~= 0 then
		AIScript_SpawnAndAttackCity( self.AIPlayerID, TargetID, self.Spawnpoint, self.NumSword, self.NumBow, self.NumCatapults, self.NumSiegeTowers, self.NumRams, self.NumAmmoCarts, self.TroopType, self.ReuseTroops)
	end
   
end

function Reward_AI_SpawnAndAttackTerritory:DEBUG(_Quest)
	-- Is it still necessary that Spawn and Target are buildings???
	if self.AIPlayerID < 2 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.AIPlayerID .. " is wrong")
		return true
	elseif Logic.IsEntityDestroyed(self.Spawnpoint) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.SpawnPoint .. " is missing")
		return true
	elseif self.TerritoryID == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Territory unknown")
		return true
	elseif self.NumSword < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Number of Swords is negative")
		return true
	elseif self.NumBow < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Number of Bows is negative")
		return true
	elseif self.NumBow + self.NumSword < 1 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": No Soldiers?")
		return true
	elseif self.NumCatapults < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Catapults is negative")
		return true
	elseif self.NumSiegeTowers < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": SiegeTowers is negative")
		return true
	elseif self.NumRams < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Rams is negative")
		return true
	elseif self.NumAmmoCarts < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": AmmoCarts is negative")
		return true
	end

end

function Reward_AI_SpawnAndAttackTerritory:GetCustomData( _Index )

	local Data = {}
	if _Index == 9 then
		table.insert( Data, "Normal" )
		table.insert( Data, "RedPrince" )
		table.insert( Data, "Bandit" )
		if g_GameExtraNo and g_GameExtraNo >= 1 then
			table.insert( Data, "Cultist" )
		end
		
	elseif _Index == 10 then
		table.insert( Data, "-" )
		table.insert( Data, "+" )
	   
	else
		assert( false, "Error in " .. self.Name .. ": GetCustomData: Index is invalid" )
	end
	
	return Data
	
end

AddQuestBehavior(Reward_AI_SpawnAndAttackTerritory)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_AI_SpawnAndProtectArea
-- BB Original
------------------------------------------------------------------------------------------------------------------------------


Reward_AI_SpawnAndProtectArea = {
	Name = "Reward_AI_SpawnAndProtectArea",
	Description = {
		en = "Reward: Spawns AI troops and defends a specified area",
		de = "Lohn: Erstellt KI Truppen und verteidigt ein angegebenes Gebiet",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "AI Player", de = "KI Spieler" },
		{ ParameterType.ScriptName, en = "Spawn point", de = "Erstellungsort" },
		{ ParameterType.ScriptName, en = "Target", de = "Ziel" },
		{ ParameterType.Number, en = "Radius", de = "Radius" },
		{ ParameterType.Number, en = "Time (-1 for infinite)", de = "Zeit (-1 fuer unendlich)" },
		{ ParameterType.Number, en = "Sword", de = "Schwert" },
		{ ParameterType.Number, en = "Bow", de = "Bogen" },
		{ ParameterType.Custom, en = "Capture tradecarts", de = "Handelskarren angreifen" },
		{ ParameterType.Custom, en = "Soldier type", de = "Soldatentyp" },
		{ ParameterType.Custom, en = "Reuse troops", de = "Verwende bestehende Truppen" },
	},
}

function Reward_AI_SpawnAndProtectArea:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_AI_SpawnAndProtectArea:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.AIPlayerID = _Parameter * 1
	elseif (_Index == 1) then	
		self.Spawnpoint = _Parameter
	elseif (_Index == 2) then	
		self.TargetName = _Parameter
	elseif (_Index == 3) then	
		self.Radius = _Parameter * 1
	elseif (_Index == 4) then	
		self.Time = _Parameter * 1
	elseif (_Index == 5) then	
		self.NumSword = _Parameter * 1
	elseif (_Index == 6) then	
		self.NumBow = _Parameter * 1
	elseif (_Index == 7) then	
		self.CaptureTradeCarts = _Parameter == "+"
	elseif (_Index == 8) then	
		if _Parameter == "Normal" then
			self.TroopType = false
		elseif _Parameter == "RedPrince" then
			self.TroopType = true
		elseif _Parameter == "Bandit" then
			self.TroopType = 2
		elseif _Parameter == "Cultist" then
			self.TroopType = 3
		else
			assert(false, "Error in " .. self.Name .. ": AddParameter: Soldier type is invalid")
		end
	elseif (_Index == 9) then	
		self.ReuseTroops = _Parameter == "+"
	end

end

function Reward_AI_SpawnAndProtectArea:GetCustomData( _Index )

	local Data = {}
	if _Index == 7 then
		table.insert( Data, "-" )
		table.insert( Data, "+" )
	elseif _Index == 8 then
		table.insert( Data, "Normal" )
		table.insert( Data, "RedPrince" )
		table.insert( Data, "Bandit" )
		if g_GameExtraNo and g_GameExtraNo >= 1 then
			table.insert( Data, "Cultist" )
		end
		
	elseif _Index == 9 then
		table.insert( Data, "-" )
		table.insert( Data, "+" )
	   
	else
		assert( false, "Error in " .. self.Name .. ": GetCustomData: Index is invalid" )
	end
	
	return Data
	
end

function Reward_AI_SpawnAndProtectArea:DEBUG(_Quest)
	-- Is it still necessary that Spawn and Target are buildings???
	if self.AIPlayerID < 2 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.AIPlayerID .. " is wrong")
		return true
	elseif Logic.IsEntityDestroyed(self.Spawnpoint) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.SpawnPoint .. " is missing")
		return true
	elseif Logic.IsEntityDestroyed(self.TargetName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.TargetName .. " is missing")
		return true
	elseif self.Radius < 1 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Radius is to small or negative")
		return true
	elseif self.Time < -1 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Time is smaller than -1")
		return true
	elseif self.NumSword < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Number of Swords is negative")
		return true
	elseif self.NumBow < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Number of Bows is negative")
		return true
	elseif self.NumBow + self.NumSword < 1 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": No Soldiers?")
		return true
	end

end

function Reward_AI_SpawnAndProtectArea:CustomFunction()

	if Logic.IsEntityAlive( self.TargetName ) then
		local TargetID = Logic.GetEntityIDByName( self.TargetName )
		AIScript_SpawnAndProtectArea( self.AIPlayerID, TargetID, self.Spawnpoint, self.Radius, self.NumSword, self.NumBow, self.Time, self.TroopType, self.ReuseTroops, self.CaptureTradeCarts )
	end
   
end

AddQuestBehavior(Reward_AI_SpawnAndProtectArea)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_CreateBattalion
-- BB Original, inspired from OldMcDonald, see Reward_CreateBattalionOmD
------------------------------------------------------------------------------------------------------------------------------

Reward_CreateBattalion = {
	Name = "Reward_CreateBattalion",
	Description = {
		en = "Reward: Replaces a script entity with a battalion, which retains the entities name",
		de = "Lohn: Ersetzt eine Script Entity durch ein Bataillon, welches den Namen der Script Entity uebernimmt",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script entity", de = "Script Entity" },
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
   		{ ParameterType.Custom, en = "Type name", de = "Typbezeichnung" },
   		{ ParameterType.Number, en = "Orientation (in degrees)(-1: from replaced Entity)", de = "Ausrichtung (in Grad)(-1: von der alten Entität)" },
   		{ ParameterType.Number, en = "Number of soldiers", de = "Anzahl Soldaten" },
   		{ ParameterType.Custom, en = "Hide from AI", de = "Vor KI verstecken" },
	},
}

function Reward_CreateBattalion:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_CreateBattalion:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.ScriptnameEntity = _Parameter	
	elseif (_Index == 1) then	
		self.PlayerID = _Parameter * 1
	elseif (_Index == 2) then	
		self.UnitKey = _Parameter
	elseif (_Index == 3) then	
		self.Orientation = _Parameter * 1
	elseif (_Index == 4) then	
		self.SoldierCount = _Parameter * 1
	elseif (_Index == 5) then	
		self.HideFromAI = _Parameter == "+"
	end

end

function Reward_CreateBattalion:CustomFunction(_Quest)
	
	if ( self.PlayerID < 1 )
	or ( self.PlayerID > 8 )
	or ( self.Orientation < -1)
	or ( self.SoldierCount < 1 )
	or ( string.find(self.UnitKey, "Bandit") and self.SoldierCount > 3 )
	or ( self.SoldierCount > 6 )
	or ( not Entities[self.UnitKey])
	then
		assert(false, _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Activate Reward_DEBUG for further information.")
	elseif Logic.IsEntityDestroyed( self.ScriptnameEntity ) then
		return false
	end
	
	local entityID = Logic.GetEntityIDByName( self.ScriptnameEntity )
	local spawnX, spawnY = Logic.GetEntityPosition( entityID )
	local orientation = self.Orientation == -1 and Logic.GetEntityOrientation( entityID ) or self.Orientation
	DestroyEntity( entityID )
	local newID = Logic.CreateBattalionOnUnblockedLand( Entities[self.UnitKey], spawnX, spawnY, orientation, self.PlayerID, self.SoldierCount )
	Logic.SetEntityName( newID, self.ScriptnameEntity )
	if self.HideFromAI then
		AICore.HideEntityFromAI( self.PlayerID, newID, true )
	end
	WikiQSB.EntitiesCreatedByQuests[self.ScriptnameEntity] = _Quest
end

function Reward_CreateBattalion:DEBUG(_Quest)

	if self.PlayerID < 1  then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.PlayerID .. " is wrong")
		return true
	elseif Logic.IsEntityDestroyed(self.ScriptnameEntity) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.ScriptnameEntity .. " is missing")
		return true
	elseif not Entities[self.UnitKey] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Bad Type Name " .. self.UnitKey)
		return true
	elseif self.Orientation < -1 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Orientation is negative")
		return true
	elseif self.SoldierCount < 1 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": No Soldiers?")
		return true
	elseif string.find(self.UnitKey, "Bandit") and self.SoldierCount > 3 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Too many soldiers for Bandits")
		return true
	elseif self.SoldierCount > 6 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Too many Soldiers")
		return true
	end

end

function Reward_CreateBattalion:GetCustomData( _Index )

	local Data = {}
	if _Index == 2 then
		for k, v in pairs( Entities ) do
			if Logic.IsEntityTypeInCategory( v, EntityCategories.Soldier ) == 1 then
				table.insert( Data, k )
			end
		end
		table.sort( Data )
	   
	elseif _Index == 5 then
		table.insert( Data, "-" )
		table.insert( Data, "+" )
		
	else
		assert( false, "Error in " .. self.Name .. ": GetCustomData: Index is invalid" )
	end
	
	return Data
	
end

AddQuestBehavior(Reward_CreateBattalion)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_CreateEffect						Quest created by: Old McDonald
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

Reward_CreateEffect = {
	Name = "Reward_CreateEffect",
	Description = {
		en = "Reward: Creates an effect at a specified position",
		de = "Belohnung: Erstellt einen Effekt an der angegebenen Position",
	},
	Parameter = {
		{ ParameterType.Default, en = "Effect name", de = "Effektname" },
		{ ParameterType.Custom, en = "Type name", de = "Typbezeichnung" },
 		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
  		{ ParameterType.ScriptName, en = "Location", de = "Ort" },
  		{ ParameterType.Number, en = "Orientation (in degrees)(-1: from locating entity)", de = "Ausrichtung (in Grad)(-1: von Positionseinheit)" },
	}
}
 
function Reward_CreateEffect:AddParameter(_Index, _Parameter)

	if _Index == 0 then
		self.EffectName = _Parameter;
	elseif _Index == 1 then
		self.Type = assert(EGL_Effects[_Parameter], "Error in " .. self.Name .. ": AddParameter: Type name is invalid");
	elseif _Index == 2 then
		self.PlayerID = _Parameter * 1;
	elseif _Index == 3 then
		self.Location = _Parameter;
	elseif _Index == 4 then
		self.Orientation = _Parameter * 1;
	end

end
 
function Reward_CreateEffect:GetRewardTable()

	return { Reward.Custom, { self, self.CustomFunction } };

end
 
function Reward_CreateEffect:CustomFunction(_Quest)

	if Logic.IsEntityDestroyed(self.Location) then
		return;
	end
	
	local entity = assert(Logic.GetEntityIDByName(self.Location), _Quest.Identifier .. "Error in " .. self.Name .. ": CustomFunction: Entity is invalid");
	
	if WikiQSB.EffectNameToID[self.EffectName] and Logic.IsEffectRegistered(WikiQSB.EffectNameToID[self.EffectName]) then
		return;
	end
	
	local posX, posY = Logic.GetEntityPosition(entity);
	local orientation = self.Orientation == -1 and Logic.GetEntityOrientation(entity) or self.Orientation;
	orientation = orientation * math.pi / 180;
	
	local effect = Logic.CreateEffectWithOrientation(self.Type, posX, posY, orientation, self.PlayerID);
	if self.EffectName ~= "" then
		WikiQSB.EffectNameToID[self.EffectName] = effect;
	end
end

function Reward_CreateEffect:DEBUG(_Quest)

	if WikiQSB.EffectNameToID[self.EffectName] and Logic.IsEffectRegistered(WikiQSB.EffectNameToID[self.EffectName]) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Effect " .. self.EffectName .. " already created")
	elseif Logic.IsEntityDestroyed( self.Location ) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.Entity .. " is missing")
		return true
	elseif self.PlayerID and (self.PlayerID < 0 or self.PlayerID > 8) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player is wrong")
		return true
	elseif self.Orientation and self.Orientation < -1 then 
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Orientation is negative")
		return true
	end
	
end

function Reward_CreateEffect:GetCustomData(_index)
	assert(_index == 1, "Error in " .. self.Name .. ": GetCustomData: Index is invalid.");
	local types = {};
	for k, v in pairs(EGL_Effects) do
		table.insert(types, k);
	end
	table.sort(types);
	return types;
end

AddQuestBehavior(Reward_CreateEffect)
------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_CreateEntity						Quest created by: Old McDonald
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

Reward_CreateEntity = {
	Name = "Reward_CreateEntity",
	Description = {
		en = "Reward: Replaces an entity by a new one of a given type",
		de = "Belohnung: Ersetzt eine Einheit durch eine neue gegebenen Typs",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Entity", de = "Einheit" },
		{ ParameterType.Custom, en = "Type name", de = "Typbezeichnung" },
 		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
  		{ ParameterType.Number, en = "Orientation (in degrees)(-1: from replaced entity)", de = "Ausrichtung (in Grad)(-1: von der alten Entität)" },
		{ ParameterType.Custom, en = "Hide from AI", de = "Vor KI verstecken" },
		{ ParameterType.Custom, en = "Place on blocked land", de = "Auf blockiertem Terrain setzen" },
	}
}
 
function Reward_CreateEntity:AddParameter(_Index, _Parameter)

	if _Index == 0 then
		self.Entity = _Parameter;
	elseif _Index == 1 then
		self.Type = assert(Entities[_Parameter], "Error in " .. self.Name .. ": AddParameter: Type name is invalid");
	elseif _Index == 2 then
		self.PlayerID = _Parameter * 1;
	elseif _Index == 3 then
		self.Orientation = _Parameter * 1;
	elseif _Index == 4 then
		self.HideFromAI = _Parameter == "+";
	elseif _Index == 5 then
		self.PlaceOnBlockedLand = _Parameter == "+";
	end

end
 
function Reward_CreateEntity:GetRewardTable()

	return { Reward.Custom, { self, self.CustomFunction } };

end
 
function Reward_CreateEntity:CustomFunction(_Quest)

	if Logic.IsEntityDestroyed( self.Entity ) then
		return
	end
	
	local entityID = assert(Logic.GetEntityIDByName( self.Entity ), _Quest.Identifier .. "Error in " .. self.Name .. ": CustomFunction: Entity is invalid")
	local spawnX, spawnY = Logic.GetEntityPosition( entityID )
	local orientation = self.Orientation == -1 and Logic.GetEntityOrientation( entityID ) or self.Orientation
	
	DestroyEntity( entityID )
	
	assert(self.Type, _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Type name is invalid")
	
	local suffix = self.PlaceOnBlockedLand and "" or "OnUnblockedLand"
	local newID 
	if Logic.IsEntityTypeInCategory( self.Type, EntityCategories.Soldier ) == 1 then
		newID = Logic["CreateBattalion" .. suffix]( self.Type, spawnX, spawnY, orientation, self.PlayerID, 1 )
	else
		newID = Logic["CreateEntity" .. suffix]( self.Type, spawnX, spawnY, orientation, self.PlayerID )
	end
	
	Logic.SetEntityName( newID, self.Entity )
	if self.HideFromAI then
		AICore.HideEntityFromAI( self.PlayerID, newID, true )
	end
	
	WikiQSB.EntitiesCreatedByQuests[self.Entity] = _Quest
	
end

function Reward_CreateEntity:DEBUG(_Quest)

	if Logic.IsEntityDestroyed( self.Entity ) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.Entity .. " is missing")
		return true
	elseif self.PlayerID and (self.PlayerID < 0 or self.PlayerID > 8) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player is wrong")
		return true
	elseif self.Orientation and self.Orientation < -1 then 
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Orientation is negative")
		return true
	end
	
end

function Reward_CreateEntity:GetCustomData(_index)
	if _index == 1 then
		local types = {};
		local categories = 
		{
			EntityCategories.Leader,
			EntityCategories.PalisadeSegment,
			EntityCategories.CityWallSegment,
			EntityCategories.CityWallGate,
			EntityCategories.Turret
		}
		for k, v in pairs(Entities) do
			local b = true;
			for i = 1, #categories do
				if Logic.IsEntityTypeInCategory(v, categories[i]) == 1 then
					b = false;
					break;
				end
			end
			if b and not string.find(k, "^B_BuildingPlot") and not string.find(k, "^XT_") and not string.find(k, "^XS_") then
				table.insert(types, k);
			end
		end
		table.sort(types);
		return types;
	elseif _index == 4 or _index == 5 then
		return {"-", "+"}
	end
	assert(false, "Error in " .. self.Name .. ": GetCustomData: Index is invalid.");
end

AddQuestBehavior(Reward_CreateEntity)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_CreateSettler
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_CreateSettler = {
	Name = "Reward_CreateSettler",
	Description = {
		en = "Reward: Replaces a script entity with a (NPC) settler, which retains the entities name",
		de = "Lohn: Ersetzt eine Script Entity durch einen (NPC) Siedler, der den Namen der Script Entity uebernimmt",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script entity", de = "Script Entity" },
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
   		{ ParameterType.Custom, en = "Type name", de = "Typbezeichnung" },
   		{ ParameterType.Number, en = "Orientation (in degrees)(-1: from replaced entity)", de = "Ausrichtung (in Grad)(-1: von der alten Entität)" },
		{ ParameterType.Custom, en = "Hide from AI", de = "Vor KI verstecken" },
	},
}

function Reward_CreateSettler:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_CreateSettler:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.ScriptnameEntity = _Parameter	
	elseif (_Index == 1) then	
		self.PlayerID = _Parameter * 1
	elseif (_Index == 2) then	
		self.UnitKey = _Parameter
	elseif (_Index == 3) then	
		self.Orientation = _Parameter * 1
	elseif (_Index == 4) then	
		self.HideFromAI = _Parameter == "+"
	end

end

function Reward_CreateSettler:CustomFunction(_Quest)
	
	if Logic.IsEntityDestroyed( self.ScriptnameEntity ) then
		return false
	end
	local entityID = Logic.GetEntityIDByName( self.ScriptnameEntity )
	local spawnX, spawnY = Logic.GetEntityPosition( entityID )
	local orientation = self.Orientation == -1 and Logic.GetEntityOrientation( entityID ) or self.Orientation
	DestroyEntity( entityID )
	assert(Entities[self.UnitKey], _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Type name is invalid")
	local newID = Logic.CreateEntityOnUnblockedLand( Entities[self.UnitKey], spawnX, spawnY, orientation, self.PlayerID )
	Logic.SetEntityName( newID, self.ScriptnameEntity )
	if self.HideFromAI then
		AICore.HideEntityFromAI( self.PlayerID, newID, true )
	end
	WikiQSB.EntitiesCreatedByQuests[self.ScriptnameEntity] = _Quest
	
end

function Reward_CreateSettler:DEBUG(_Quest)
		
	if self.PlayerID < 0  then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.Player .. " is wrong")
		return true
	elseif Logic.IsEntityDestroyed(self.ScriptnameEntity) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.ScriptnameEntity .. " is missing")
		return true
	elseif self.Orientation < -1 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Orientation is negative")
		return true
	elseif not Entities[self.UnitKey] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Type name is wrong")
		return true
	end

end 

function Reward_CreateSettler:GetCustomData( _Index )

	local Data = {}
	if _Index == 2 then
		for k, v in pairs( Entities ) do
			if ( string.find( k, "^U_" ) and Logic.IsEntityTypeInCategory( v, EntityCategories.Soldier ) == 0 ) or string.find( k, "^A_" ) then
				table.insert( Data, k )
			end
		end
		table.sort( Data )
		
	elseif _Index == 4 then
		table.insert( Data, "-" )
		table.insert( Data, "+" )
	   
	else
		assert( false, "Error in " .. self.Name .. ": GetCustomData: Index is invalid" )
	end
	
	return Data
	
end

AddQuestBehavior(Reward_CreateSettler)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_CreateSeveralBattalions						Quest created by: Old McDonald
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

Reward_CreateSeveralBattalions = {
	Name = "Reward_CreateSeveralBattalions",
	Description = {
		en = "Reward: Creates a given amount of battalions",
		de = "Belohnung: Erstellt eine gegebene Anzahl an Bataillonen",
	},
	Parameter = {
		{ ParameterType.Custom, en = "Soldier type", de = "Soldatentyp" },
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
		{ ParameterType.Number, en = "Amount", de = "Anzahl der Bataillone" },
		{ ParameterType.Number, en = "Battalion size", de = "Truppengroesse" },
		{ ParameterType.ScriptName, en = "Location", de = "Ort" }
	}
}
 
 
function Reward_CreateSeveralBattalions:AddParameter(_Index, _Parameter)

	if _Index == 0 then
		self.Type = assert(Entities[_Parameter], "Error in " .. self.Name .. ": AddParameter: Soldier type is invalid" );
	elseif _Index == 1 then
		self.Player = _Parameter * 1;
	elseif _Index == 2 then
		self.Amount = _Parameter * 1;
	elseif _Index == 3 then
		self.Troopsize = _Parameter * 1;
	elseif _Index == 4 then
		self.Location = _Parameter;
	end

end
 
function Reward_CreateSeveralBattalions:GetRewardTable()

	return { Reward.Custom, { self, self.CustomFunction } };

end

function Reward_CreateSeveralBattalions:CustomFunction(_Quest)
	if ( self.Troopsize <= 0 ) 
	or ( self.Amount <= 0 )
	or ( string.find(Logic.GetEntityTypeName(self.Type), "Bandit") and self.Troopsize > 3 )
	or ( self.Troopsize > 6 )
	or ( self.Player < 1 )
	or ( self.Player > 8 )
	or ( self.Troopsize * self.Amount > 200 )
	--or ( Logic.IsEntityDestroyed(self.Location) )
	then
		assert(false, _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Activate Reward_DEBUG for further information.")
	end
	local location = Logic.GetEntityIDByName(self.Location);
	if location == 0 then
		return;
	end
	local x, y = Logic.GetEntityPosition(location);
	for i = 1, self.Amount do
		Logic.CreateBattalionOnUnblockedLand(self.Type, x, y, 0, self.Player, self.Troopsize);
	end

end

function Reward_CreateSeveralBattalions:DEBUG(_Quest)
		
	if self.Player < 1 or self.Player > 8 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.Player .. " is wrong")
		return true
	elseif Logic.IsEntityDestroyed(self.Location) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.Location .. " is missing")
		return true
	elseif string.find(Logic.GetEntityTypeName(self.Type), "Bandit") and self.Troopsize > 3 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Troop size too high for bandits.")
		return true
	elseif self.Troopsize > 6 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Troop size too high.")
		return true
	elseif self.Amount < 1 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Wrong Amount")
		return true
	elseif self.Amount * self.Troopsize > 200 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Too many soldiers")
		return true
	end

end

function Reward_CreateSeveralBattalions:GetCustomData(_index)
	assert(_index == 0, "Error in " .. self.Name .. ": GetCustomData: Index is invalid" );
	local types = {};
	for k, v in pairs(Entities) do
		if Logic.IsEntityTypeInCategory(v, EntityCategories.Soldier) == 1 then
			table.insert(types, k);
		end
	end
	table.sort(types);
	return types;
end
 
AddQuestBehavior(Reward_CreateSeveralBattalions)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_CreateSeveralEntities							Quest created by: Old McDonald
-- User Generated
------------------------------------------------------------------------------------------------------------------------------
 
Reward_CreateSeveralEntities = {
	Name = "Reward_CreateSeveralEntities",
	Description = {
		en = "Reward: Creates a given amount of units/buildings",
		de = "Belohnung: Erstellt eine gegebene Anzahl an Einheiten/Gebaeuden",
	},
	Parameter = {
		{ ParameterType.Custom, en = "Type name", de = "Typbezeichnung" },
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
		{ ParameterType.Number, en = "Amount", de = "Anzahl" },
		{ ParameterType.ScriptName, en = "Location", de = "Ort" }
	}
}
 
function Reward_CreateSeveralEntities:AddParameter(_Index, _Parameter)
	
	if _Index == 0 then
		self.Type = assert(Entities[_Parameter], "Error in " .. self.Name .. ": AddParameter: Entity type is invalid.");
	elseif _Index == 1 then
		self.Player = _Parameter*1;
	elseif _Index == 2 then
		self.Amount = _Parameter*1;
	elseif _Index == 3 then
		self.Location = _Parameter;
	end
	
end
 
function Reward_CreateSeveralEntities:GetRewardTable()

	return { Reward.Custom, { self, self.CustomFunction } };

end
 
function Reward_CreateSeveralEntities:CustomFunction(_Quest)

	local location = assert(Logic.GetEntityIDByName(self.Location), _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Location entity is missing.");
	if location == 0 then
		return;
	end
	local x, y = Logic.GetEntityPosition(location);
	if Logic.IsEntityTypeInCategory(self.Type, EntityCategories.Soldier) == 1 then
		for i = 1, self.Amount do
			Logic.CreateBattalionOnUnblockedLand(self.Type, x, y, 0, self.Player, 1);
		end
	else
		for i = 1, self.Amount do
			Logic.CreateEntityOnUnblockedLand(self.Type, x, y, 0, self.Player);
		end
	end
	
end

function Reward_CreateSeveralEntities:DEBUG(_Quest)
		
	if self.Player < 0  then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.Player .. " is wrong")
		return true
	elseif Logic.IsEntityDestroyed(self.Location) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.Location .. " is missing")
		return true
	elseif self.Amount < 1 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Wrong Amount")
		return true
	end

end 

function Reward_CreateSeveralEntities:GetCustomData(_index)
	assert(_index == 0, "Error in " .. self.Name .. ": GetCustomData: Index is invalid");
	local types = {};
	local categories = 
	{
		EntityCategories.Leader,
		EntityCategories.PalisadeSegment,
		EntityCategories.CityWallSegment,
		EntityCategories.CityWallGate,
		EntityCategories.Turret
	}
	for k, v in pairs(Entities) do
		local b = true;
		for i = 1, #categories do
			if Logic.IsEntityTypeInCategory(v, categories[i]) == 1 then
				b = false;
				break;
			end
		end
		if b and not string.find(k, "^B_BuildingPlot") and not string.find(k, "^XT_") and not string.find(k, "^XS_") then
			table.insert(types, k);
		end
	end
	table.sort(types);
	return types;
end
 
AddQuestBehavior(Reward_CreateSeveralEntities)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward CustomVariables
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

Reward_CustomVariables = {
	Name = "Reward_CustomVariables",
	Description = {
		en = "Reward: + and - modifies one of five possible variables, = sets it",
		de = "Belohnung: + und - aendern eine von fuenf moeglichen Variablen, = setzt sie",
	},
	Parameter = {
		{ ParameterType.Custom,   en = "Variable", de = "Variable" },
		{ ParameterType.Custom,   en = "Operator", de = "Operand" },
		{ ParameterType.Number,   en = "Value", de = "Wert" },
		{ ParameterType.Default,  en = "(Expert)Use with caution", de = "(Experte)Mit Vorsicht benutzen)" },
	},
}

function Reward_CustomVariables:GetRewardTable()

	return { Reward.Custom, {self, self.CustomFunction} }

end

function Reward_CustomVariables:AddParameter(_Index, _Parameter)

	if (_Index ==0) then
		self.Variable = _Parameter
	elseif (_Index == 1) then
		self.Operator = _Parameter
	elseif (_Index == 2) then
		self.Value = _Parameter*1
	elseif (_Index == 3) then
		self.MultipleOpsAndValues = _Parameter
	end
	
end

function Reward_CustomVariables:CustomFunction(_Quest)

	local var = self.Variable
	local op = self.Operator
	local cont = WikiQSB.CustomVariable
	local val = self.Value
	local oldval = assert(cont[var], _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Variable not found")
	if op == "+" then
		cont[var] = oldval + val
	elseif op == "-" then
		cont[var] = oldval - val
	elseif op == "*" then
		cont[var] = oldval * val
	elseif op == "/" then
		assert( val ~= 0, _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Division by zero")
		cont[var] = oldval / val
	elseif op == "=" then
		cont[var] = val
	elseif op == "Expert" then
		for key, _ in pairs(_G) do
			assert( not string.find(self.MultipleOpsAndValues, key), _Quest.Identifier .. ": Fatal Error in " .. self.Name .. ": CustomFunction: DON'T YOU DARE TO GIVE FUNCTIONNAMES IN EXPERT!")
		end
		Logic.ExecuteInLuaLocalState([[GUI.SendScriptCommand("WikiQSB.CustomVariable.]] .. self.Variable .. [[ = WikiQSB.CustomVariable.]] .. self.Variable .. self.MultipleOpsAndValues..[[")]])
	else 
		assert(false, _Quest.Identifier ..": Error in " .. self.Name .. ": CustomFunction: Operator is invalid")
	end	
	_Quest[self.Name] = _Quest[self.Name] or {}
	_Quest[self.Name][var] = true
	
end

function Reward_CustomVariables:Reset(_Quest)

	_Quest[self.Name][self.Variable] = nil

end

function Reward_CustomVariables:DEBUG(_Quest)

	if not WikiQSB.CustomVariable[self.Variable] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": Wrong Variable name ")
		return true
	elseif _Quest[self.Name] and _Quest[self.Name][self.Variable] then
		yam(_Quest.Identifier .. ": Warning " .. self.Name ..": Don't use more than one Reward for the same variable in the same quest.")
		return true
	elseif type(self.Value) ~= "number" then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": Wrong type for Value")
		return true
	elseif not ( 	self.Operator == "+" 
				or 	self.Operator == "-" 
				or 	self.Operator == "*"
				or 	self.Operator == "/"
				or 	self.Operator == "="
				or 	self.Operator == "Expert") then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": Wrong Operator")
		return true
	elseif self.Operator == "/" and self.Value == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": Division by Zero: Illegal")
		return true
	elseif (	self.Operator == "+" 
			or 	self.Operator == "-"
			or 	self.Operator == "*") and self.Value == 0 then
		yam(_Quest.Identifier .. ": Warning in " .. self.Name ..": +/-/* 0 : Useless?")
		return true
	elseif self.Operator == "Expert" then
		for key, _ in pairs(_G) do
			if string.find(self.MultipleOpsAndValues, key) then
			yam(_Quest.Identifier .. ": Fatal Error in " .. self.Name .. ": CustomFunction: DON'T YOU DARE TO GIVE FUNCTIONNAMES IN EXPERT!")
				return true
			end
		end
	end
	
end

function Reward_CustomVariables:GetCustomData(_index)

	if (_index == 0) then
		return WikiQSB.CustomVariable.List
	elseif (_index == 1) then
		return { "+", "-", "*", "/", "=", "Expert" }
	end
	
end

AddQuestBehavior(Reward_CustomVariables)

------------------------------------------------------------------------------------------------------------------------------
-- BETA BETA BETA BETA BETA BETA BETA BETA BETA BETA BETA BETA BETA BETA BETA 
-- Reward_DEBUG
-- User Generated
------------------------------------------------------------------------------------------------------------------------------
Reward_DEBUG = {
	Name = "Reward_DEBUG",
	Description = {
		en = "A HELPER FOR DEBUGGING QUEST ERRORS!",
		de = "EIN HELFER UM QUESTFEHLER ZU FINDEN!",
		},
	Parameter = {
		{ParameterType.Custom, en = "Debug Quests at Runtime", de = "Teste Quests während der Laufzeit", },
		{ParameterType.Custom, en = "Debug Quests at Map start", de = "Quests bei Mapstart testen", },
		{ParameterType.Custom, en = "Enable Questtrace?", de = "Questverfolgung einschalten?", },
		{ParameterType.Custom, en = "Enable Debug Mode?", de = "Debug Modus aktivieren?", },
		},
}

function Reward_DEBUG:GetRewardTable()

	return {Reward.Custom, {self, self.CustomFunction}}

end

function Reward_DEBUG:AddParameter(_Index, _Parameter)
	
	if (_Index == 0) then
		self.DebugAtRuntime = (_Parameter == "On")
	elseif (_Index == 1) then
		if _Parameter == "On" then
			WikiQSB.Reward_DEBUG.Enable_QuestDebuggingAtMapStart = true
		end
	elseif (_Index == 2) then
		if _Parameter == "On" then
			WikiQSB.Reward_DEBUG.QuestTrace()
		end
		self.QuestTrace = _Parameter == "On"
	else
		assert(_Index == 3, "Error in " .. self.Name .. ": AddParameter: Index is invalid")
		self.EnableDebugMode = (_Parameter == "On")
	end
	
end

function Reward_DEBUG:CustomFunction(_Quest)
	WikiQSB.Reward_DEBUG.Enable_DebugMode = self.EnableDebugMode
	WikiQSB.Reward_DEBUG.Enable_QuestTrace = self.QuestTrace
	WikiQSB.Reward_DEBUG.Enable_QuestDebuggingAtRuntime = self.DebugAtRuntime
	if not self.QuestTrace then
		Logic.ExecuteInLuaLocalState([[
			g_QuestSysTraceActive = false
			Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierShift + Keys.Q, "GUI.AddNote()", 2)
			Input.KeyBindDown(Keys.ModifierControl + Keys.ModifierShift + Keys.W, "GUI.AddNote()", 2)
			]])
	end
	if self.EnableDebugMode then 
		WikiQSB.Reward_DEBUG.DebugMode()
	else
		Logic.ExecuteInLuaLocalState([[
			KeyBindings_EnableDebugMode(0)
			GUI_Chat.Confirm = (WikiQSB_DEBUG and WikiQSB_DEBUG.SaveChatConfirm and WikiQSB_DEBUG.SaveChatConfirm) or GUI_Chat.Confirm
			WikiQSB_DEBUG_CheckBox = nil
			WikiQSB_DEBUG = nil
			Input.KeyBindDown(	Keys.ModifierControl + Keys.ModifierShift + Keys.ModifierAlt + Keys.D0, 
							"GUI.AddNote()", 
							2, 
							true)
			XGUIEng.ShowWidget("/InGame/Root/Normal/AlignTopLeft/GameClock",0)
			]])
	end
end

function Reward_DEBUG:GetCustomData(_index)

	assert (_index >= 0 and _index <= 3, "Error in " .. self.Name .. ": GetCustomData: Index is invalid")
	return { "Off", "On",}

end

AddQuestBehavior(Reward_DEBUG)

WikiQSB.Reward_DEBUG = {
	
	QuestTrace = function()
		Logic.ExecuteInLuaLocalState("g_QuestSysTraceActive = true")
		DEBUG_EnableQuestDebugKeys() 
	end,
	
	DebugMode = function()
		Logic.ExecuteInLuaLocalState([[
		KeyBindings_EnableDebugMode(1)
		KeyBindings_EnableDebugMode(2)
		KeyBindings_EnableDebugMode(3)
		XGUIEng.ShowWidget("/InGame/Root/Normal/AlignTopLeft/GameClock",1)
		WikiQSB_DEBUG = {}
		WikiQSB_DEBUG.SaveChatConfirm = GUI_Chat.Confirm
		GUI_Chat.Confirm = function()
				Input.GameMode()
				XGUIEng.ShowWidget("/InGame/Root/Normal/ChatInput",0)
				WikiQSB_DEBUG.ChatBoxInput = XGUIEng.GetText("/InGame/Root/Normal/ChatInput/ChatInput")
				g_Chat.JustClosed = 1
				Game.GameTimeSetFactor( GUI.GetPlayerID(), 1 )
		end
		WikiQSB_DEBUG_CheckBox = function()
			if not WikiQSB_DEBUG.BoxShown then
				Input.ChatMode()
				Game.GameTimeSetFactor( GUI.GetPlayerID(), 0 )
				XGUIEng.ShowWidget("/InGame/Root/Normal/ChatInput",1)
				XGUIEng.SetText("/InGame/Root/Normal/ChatInput/ChatInput", "")
				XGUIEng.SetFocus("/InGame/Root/Normal/ChatInput/ChatInput")
				WikiQSB_DEBUG.BoxShown = true
			elseif WikiQSB_DEBUG.ChatBoxInput then
				GUI.SendScriptCommand("WikiQSB.Reward_DEBUG.Parser('"..WikiQSB_DEBUG.ChatBoxInput.."')")
				WikiQSB_DEBUG.BoxShown = nil
				return true
			end
		end
		Input.KeyBindDown(	Keys.ModifierControl + Keys.ModifierShift + Keys.ModifierAlt + Keys.D0, 
							"StartSimpleJob('WikiQSB_DEBUG_CheckBox')", 
							2, 
							true)
		
		]])
	end,
	
	Parser = function(_input)
		local keys = WikiQSB.Reward_DEBUG.Keys
		for _, t in ipairs(keys) do
			local first, last = string.find(_input, "^"..t[1])
			if first then
				local questName = string.sub(_input, last+1 )
				t[2](questName, t[3])
				return
			end
		end
	end,

	InterruptQuest = function( _Name, _Exact )
		local FoundQuests = FindQuestsByName( _Name, _Exact )
		if #FoundQuests > 0 then
			for _, Quest in ipairs( FoundQuests ) do
				Quest:Interrupt()
				Logic.DEBUG_AddNote( "Interrupted: " .. (Quest.Identifier or "nil") )
			end
		else
			Logic.DEBUG_AddNote( "Not found: " .. (_Name or "nil") )
		end
	end,

	StartQuest = function( _Name, _Exact )
		local FoundQuests = FindQuestsByName( _Name, _Exact )
		if #FoundQuests > 0 then
			for _, Quest in ipairs( FoundQuests ) do
				if Quest.State == QuestState.NotTriggered then
					Quest:SetMsgKeyOverride()
					Quest:SetIconOverride()
					Quest:Trigger()
					Logic.DEBUG_AddNote( "Triggered: " .. (Quest.Identifier or "nil") )
				else 
					Logic.DEBUG_AddNote( "Not Triggered: " .. (Quest.Identifier or "nil") .. " already active or over" )
				end
			end
		else
			Logic.DEBUG_AddNote( "Not found: " .. (_Name or "nil") )
		end
	end,

	ShowActives = function()
		for _, quest in ipairs(Quests) do
			if quest.State == QuestState.Active then
				Logic.DEBUG_AddNote("Active quest: " .. ((quest.Identifier and quest.Identifier ~= "" and quest.Identifier) or "Unknown Name"))
			end
		end
	end,
	
	ShowQuestState = function( _Name, _Exact )
		local FoundQuests = FindQuestsByName( _Name, _Exact )
		if #FoundQuests > 0 then
			for _, Quest in ipairs( FoundQuests ) do
				if type(Quest) == "table" then
					Logic.DEBUG_AddNote( Quest.Identifier .. ": ".. GetNameOfKeyInTable(QuestState, Quest.State) .. " Result: " ..((Quest.Result and GetNameOfKeyInTable(QuestResult, Quest.Result)) or "Running") )
				end
			end
		else
			Logic.DEBUG_AddNote( "Not found: " .. (_Name or "nil") )
		end
	end,

	RestartQuest = function( _Name, _Exact )
		local FoundQuests = FindQuestsByName( _Name, _Exact )
		if #FoundQuests > 0 then
			for _, Quest in ipairs( FoundQuests ) do
				if Quest.Objectives then
					for i = 1, Quest.Objectives[0] do
						Quest.Objectives[i].Completed = nil
						if Quest.Objectives[i].Type == Objective.Deliver then
							Quest.Objectives[i].Data[3] = nil
							Quest.Objectives[i].Data[4] = nil
							Quest.Objectives[i].Data[5] = nil
						elseif g_GameExtraNo and g_GameExtraNo >= 1 and Quest.Objectives[i].Type == Objective.Refill then
							Quest.Objectives[i].Data[2] = nil
						elseif Quest.Objectives[i].Type == Objective.Protect or Quest.Objectives[i].Type == Objective.Object then
							for j=-1, -Quest.Objectives[i].Data[0], -1 do
								Quest.Objectives[i].Data[j] = nil
							end
						elseif Quest.Objectives[i].Type == Objective.Custom2 
						and Quest.Objectives[i].Data[1].Reset then
							Quest.Objectives[i].Data[1]:Reset(Quest)
						end
					end
				end
				if Quest.Triggers then
					for i = 1, Quest.Triggers[0] do
						if Quest.Triggers[i].Type == Triggers.Custom2 
						and Quest.Triggers[i].Data[1]
						and Quest.Triggers[i].Data[1].Reset then
							Quest.Triggers[i].Data[1]:Reset(Quest)
						end
					end	
				end
				if Quest.Rewards then
					for i = 1, Quest.Rewards[0] do
						if Quest.Rewards[i].Type == Reward.Custom 
						and Quest.Rewards[i].Data[1]
						and Quest.Rewards[i].Data[1].Reset then
							Quest.Rewards[i].Data[1]:Reset(Quest)
						end
					end	
				end
				if Quest.Reprisals then
					for i = 1, Quest.Reprisals[0] do
						if Quest.Reprisals[i].Type == Reprisal.Custom 
						and Quest.Reprisals[i].Data[1]
						and Quest.Reprisals[i].Data[1].Reset then
							Quest.Reprisals[i].Data[1]:Reset(Quest)
						end
					end	
				end
				Quest.Result = nil
				local OldQuestState = Quest.State
				Quest.State = QuestState.NotTriggered
				Logic.ExecuteInLuaLocalState("LocalScriptCallback_OnQuestStatusChanged("..Quest.Index..")")
				if OldQuestState == QuestState.Over then
					Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_SECOND, "", QuestTemplate.Loop, 1, 0, { Quest.QueueID })
				end
				Logic.DEBUG_AddNote( "Restarted: " .. Quest.Identifier )
			end
		else
			Logic.DEBUG_AddNote( "Not found: " .. (_Name or "nil") )
		end
	end,
}

WikiQSB.Reward_DEBUG.Keys = {
		{ [1] = "win ", [2] = DEBUG_SucceedQuest, [3] = true},
		{ [1] = "fail ", [2] = DEBUG_FailQuest, [3] = true},
		{ [1] = "winall ", [2] = DEBUG_SucceedQuest, [3] = false},
		{ [1] = "failall ", [2] = DEBUG_FailQuest, [3] = false},
		{ [1] = "start ", [2] = WikiQSB.Reward_DEBUG.StartQuest, [3] = true},
		{ [1] = "startall ", [2] = WikiQSB.Reward_DEBUG.StartQuest, [3] = false},
		{ [1] = "interrupt ", [2] = WikiQSB.Reward_DEBUG.InterruptQuest, [3] = true},
		{ [1] = "interruptall ", [2] = WikiQSB.Reward_DEBUG.InterruptQuest, [3] = false},
		{ [1] = "restart ", [2] = WikiQSB.Reward_DEBUG.RestartQuest, [3] = true},
		{ [1] = "restartall ", [2] = WikiQSB.Reward_DEBUG.RestartQuest, [3] = false},
		{ [1] = "show ", [2] = WikiQSB.Reward_DEBUG.ShowQuestState, [3] = true },
		{ [1] = "showall ", [2] = WikiQSB.Reward_DEBUG.ShowQuestState, [3] = false },
		{ [1] = "showactive", [2] = WikiQSB.Reward_DEBUG.ShowActives, [3] = false},
}

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_DestroyEffect						Quest created by: Old McDonald
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

Reward_DestroyEffect = {
	Name = "Reward_DestroyEffect",
	Description = {
		en = "Reward: Destroys an effect",
		de = "Belohnung: Zerstoert einen Effekt",
	},
	Parameter = {
		{ ParameterType.Default, en = "Effect name", de = "Effektname" },
	}
}
 
function Reward_DestroyEffect:AddParameter(_Index, _Parameter)

	if _Index == 0 then
		self.EffectName = _Parameter;
	end

end
 
function Reward_DestroyEffect:GetRewardTable()

	return { Reward.Custom, { self, self.CustomFunction } };

end
 
function Reward_DestroyEffect:CustomFunction(_Quest)

	if not WikiQSB.EffectNameToID[self.EffectName] or not Logic.IsEffectRegistered(WikiQSB.EffectNameToID[self.EffectName]) then
		return;
	end
	Logic.DestroyEffect(WikiQSB.EffectNameToID[self.EffectName]);
end

function Reward_DestroyEffect:DEBUG(_Quest)

	if not WikiQSB.EffectNameToID[self.EffectName] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Effect " .. self.EffectName .. " never created")
	end
	
end

AddQuestBehavior(Reward_DestroyEffect)
------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_DestroyEntity
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_DestroyEntity = {
	Name = "Reward_DestroyEntity",
	Description = {
		en = "Reward: Replaces a (NPC) settler with an invisible script entity, which retains the entities name",
		de = "Lohn: Ersetzt einen (NPC) Siedler mit einer unsichtbaren Script Entity, die den Namen des Siedlers uebernimmt",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Settler", de = "Siedler" },
	},
}

function Reward_DestroyEntity:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_DestroyEntity:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.ScriptnameEntity = _Parameter	
	end

end

function Reward_DestroyEntity:CustomFunction()
	
	if Logic.IsEntityDestroyed( self.ScriptnameEntity ) then
		return false
	end
	
	local EntityID = Logic.GetEntityIDByName( self.ScriptnameEntity )
	local EntityX, EntityY = Logic.GetEntityPosition( EntityID )
	local orientation = Logic.GetEntityOrientation(EntityID)
	DestroyEntity( EntityID )
	local NewID = Logic.CreateEntityOnUnblockedLand( Entities.XD_ScriptEntity, EntityX, EntityY, orientation, 0 )
	Logic.SetEntityName( NewID, self.ScriptnameEntity )

end

function Reward_DestroyEntity:DEBUG(_Quest)
	
	if Logic.IsEntityDestroyed( self.ScriptnameEntity ) then
		yam(_Quest.Identifier .. ": Warning in " .. self.Name ..": Settler already dead?")
		return true
	elseif WikiQSB.EntitiesCreatedByQuests[self.ScriptnameEntity] == _Quest then
		yam(_Quest.Identifier .. ": Hint in " .. self.Name ..": Don't destroy an entity in the same quest it is created")
		return true
	end
	
end

AddQuestBehavior(Reward_DestroyEntity)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_SetDiplomacy
-- User Generated zweispeer
------------------------------------------------------------------------------------------------------------------------------

Reward_Diplomacy = {
	Name = "Reward_Diplomacy",
	Description = {
		en = "Reward: Sets Diplomacy between two Players  to a stated value",
		de = "Lohn: Stellt die Diplomatie zwischen zwei Spielern auf den angegebenen Wert",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "PlayerID 1", de = "PlayerID 1" },
		{ ParameterType.PlayerID, en = "PlayerID 2", de = "PlayerID 2" },
		{ ParameterType.DiplomacyState, en = "Diplomacy State", de = "Diplomatiestatus"},
	},
}

function Reward_Diplomacy:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_Diplomacy:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.PID1 = _Parameter*1   
	elseif (_Index == 1) then
		self.PID2 = _Parameter*1
	elseif (_Index == 2) then
		self.Diplomacy = _Parameter
	end

end

function Reward_Diplomacy:CustomFunction()

	if (self.PID1 == self.PID2) then
		return 
	end
	if self.Diplomacy and DiplomacyStates[self.Diplomacy] then
		SetDiplomacyState( self.PID1, self.PID2, DiplomacyStates[self.Diplomacy])
	end
	
end

function Reward_Diplomacy:DEBUG(_Quest)
	
	if self.PID1 < 1 or self.PID1 > 8 then
		yam(_Quest.Identifier .. ":  Error in " .. self.Name ..": Player 1 is wrong")
		return true
	elseif self.PID2 < 1 or self.PID2 > 8 then
		yam(_Quest.Identifier .. ":  Error in " .. self.Name ..": Player 2 is wrong")
		return true
	elseif not DiplomacyStates[self.Diplomacy] then
		yam(_Quest.Identifier .. ":  Error in " .. self.Name ..": Wrong Diplomacy")
		return true
	elseif self.PID1 == self.PID2 then
		yam(_Quest.Identifier .. ":  Error in " .. self.Name ..": PlayerIDs are identical")
		return true
	end
	
end

AddQuestBehavior(Reward_Diplomacy)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_FakeVictory
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_FakeVictory = {
	Name = "Reward_FakeVictory",
	Description = {
		en = "Reward: Display a victory icon for a quest",
		de = "Lohn: Zeigt ein Siegesicon fuer eine Quest"
	},
}

function Reward_FakeVictory:GetRewardTable()

	return { Reward.FakeVictory }

end

function Reward_FakeVictory:AddParameter(_Index, _Parameter)

end

AddQuestBehavior(Reward_FakeVictory)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_InitTradePost
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

Reward_InitTradePost= {
	Name = "Reward_InitTradePost",
	Description = {
		en = "Sets options for a Tradepost and deactivates it",
		de = "Stellt einen Handelsposten ein und deaktiviert ihn",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "PlayerID", de = "PlayerID" },
		{ ParameterType.Custom, en = "Active Slot, 0 for none", de = "Aktives Angebot, 0 fuer keines" },
		{ ParameterType.Custom, en = "Type of good to pay 1", de = "Resourcentyp Bezahlung 1" },
		{ ParameterType.Number, en = "Amount of good", de = "Anzahl der Resource" },
		{ ParameterType.Custom, en = "Type of good to get 1", de = "Resourcentyp Angebot 1" },
		{ ParameterType.Number, en = "Amount of good", de = "Anzahl der Resource" },
		{ ParameterType.Custom, en = "Type of good to pay 2", de = "Resourcentyp Bezahlung 2" },
		{ ParameterType.Number, en = "Amount of good", de = "Anzahl der Resource" },
		{ ParameterType.Custom, en = "Type of good to get 2", de = "Resourcentyp Angebot 2" },
		{ ParameterType.Number, en = "Amount of good", de = "Anzahl der Resource" },
		{ ParameterType.Custom, en = "Type of good to pay 3", de = "Resourcentyp Bezahlung 3" },
		{ ParameterType.Number, en = "Amount of good", de = "Anzahl der Resource" },
		{ ParameterType.Custom, en = "Type of good to get 3", de = "Resourcentyp Angebot 3" },
		{ ParameterType.Number, en = "Amount of good", de = "Anzahl der Resource" },
		{ ParameterType.Custom, en = "Type of good to pay 4", de = "Resourcentyp Bezahlung 4" },
		{ ParameterType.Number, en = "Amount of good", de = "Anzahl der Resource" },
		{ ParameterType.Custom, en = "Type of good to get 4", de = "Resourcentyp Angebot 4" },
		{ ParameterType.Number, en = "Amount of good", de = "Anzahl der Resource" },
	},
}

function Reward_InitTradePost:GetRewardTable()

	return { Reward.Custom, { self, self.CustomFunction } }
	
end

function Reward_InitTradePost:AddParameter(_Index, _Parameter)
	
	if (_Index == 0) then
		self.PlayerID = _Parameter * 1
	elseif (_Index == 1) then
		self.ActiveSlot = _Parameter * 1
	elseif (_Index == 2) then
		self.PayType1 = _Parameter
	elseif (_Index == 3) then
		self.PayAmount1 = _Parameter * 1
	elseif (_Index == 4) then
		self.OfferType1 = _Parameter
	elseif (_Index == 5) then
		self.OfferAmount1 = _Parameter * 1
	elseif (_Index == 6) then
		self.PayType2 = _Parameter
	elseif (_Index == 7) then
		self.PayAmount2 = _Parameter * 1
	elseif (_Index == 8) then
		self.OfferType2 = _Parameter
	elseif (_Index == 9) then
		self.OfferAmount2 = _Parameter * 1
	elseif (_Index == 10) then
		self.PayType3 = _Parameter
	elseif (_Index == 11) then
		self.PayAmount3 = _Parameter * 1
	elseif (_Index == 12) then
		self.OfferType3 = _Parameter
	elseif (_Index == 13) then
		self.OfferAmount3 = _Parameter * 1
	elseif (_Index == 14) then
		self.PayType4 = _Parameter
	elseif (_Index == 15) then
		self.PayAmount4 = _Parameter * 1
	elseif (_Index == 16) then
		self.OfferType4 = _Parameter
	elseif (_Index == 17) then
		self.OfferAmount4 = _Parameter * 1
	end

end

function Reward_InitTradePost:CustomFunction(_Quest)

	local OfferCount = 0
	for i = 1, 4 do
		if self["PayAmount"..i] and self["PayAmount"..i] > 0 and self["OfferAmount"..i] and self["OfferAmount"..i] > 0 then
			OfferCount = i
		else 
			break
		end
	end
	local _, TradepostID = Logic.GetPlayerEntities( self.PlayerID, Entities.I_X_TradePostConstructionSite, 1, 0 )
	assert( TradepostID and TradepostID ~= 0 , _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Tradepost is missing")
	if self.PlayerID and OfferCount > 0 then
		Logic.TradePost_SetTradePartnerGenerateGoodsFlag(TradepostID, true)
		Logic.TradePost_SetTradePartnerPlayerID(TradepostID, self.PlayerID)
		for j = 1, OfferCount do
			Logic.TradePost_SetTradeDefinition(TradepostID, (j-1), Goods[self["PayType"..j] ], self["PayAmount"..j], Goods[self["OfferType"..j] ], self["OfferAmount"..j])
		end
		if self.ActiveSlot and self.ActiveSlot > 0 and self.ActiveSlot <= OfferCount then
			Logic.TradePost_SetActiveTradeSlot(TradepostID, (self.ActiveSlot - 1))
		end
		Logic.InteractiveObjectSetAvailability(TradepostID, false )
		for i = 1, 8 do
			Logic.InteractiveObjectSetPlayerState(TradepostID, i, 2)
		end
		
	end

end

function Reward_InitTradePost:DEBUG(_Quest)
	
	local _, TradepostID = Logic.GetPlayerEntities( self.PlayerID, Entities.I_X_TradePostConstructionSite, 1, 0 )
	if Logic.GetStoreHouse(self.PlayerID) == 0 then
		yam(_Quest.Identifier .. ":  Error in " .. self.Name ..": Player " .. self.PlayerID .. " is dead :-(")
		return true
	elseif not TradepostID or TradepostID == 0 then
		yam(_Quest.Identifier .. ":  Error in " .. self.Name ..": No TradePost found")
		return true
	end
	for i = 1, 4 do
		if 	self["PayAmount"..i]
		and	self["OfferAmount"..i]
		and self["PayAmount"..i] > 0
		and	self["OfferAmount"..i] > 0
		and ( 	not Goods[self["PayType"..i]]
			or  not Goods[self["OfferType"..i]] )
		then
			yam(_Quest.Identifier .. ":  Error in " .. self.Name ..": Offer type or pay type in Slot " .. i .. " is wrong")
			return true
		end
	end
	
end

function Reward_InitTradePost:GetCustomData(_index)

	if (_index == 1) then
		return { "0", "1", "2", "3", "4"}
	elseif _index >= 2 and _index <= 16 and _index % 2 == 0 then
		return {"G_Carcass",
				"G_Grain",
				"G_Herb",
				"G_Honeycomb",
				"G_Iron",
				"G_Milk",
				"G_RawFish",
				"G_Stone",
				"G_Wood",
				"G_Wool",
				"G_Salt",
				"G_Dye",
				"G_Olibanum",
				"G_Gems",
				"G_MusicalInstrument",
				}
	end
	
end

if g_GameExtraNo and g_GameExtraNo >= 1 then
	AddQuestBehavior(Reward_InitTradePost)
end

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_InteractiveObjectActivate
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_InteractiveObjectActivate = {
	Name = "Reward_InteractiveObjectActivate",
	Description = {
		en = "Reward: Activates and interactive",
		de = "Lohn: Aktiviert ein interaktives Objekt",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Interactive object", de = "Interaktives Objekt" },
	},
}

function Reward_InteractiveObjectActivate:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_InteractiveObjectActivate:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.Scriptname = _Parameter	
	end

end

function Reward_InteractiveObjectActivate:CustomFunction(_Quest)
	
	if Logic.IsEntityDestroyed( self.Scriptname ) or not Logic.IsInteractiveObject(Logic.GetEntityIDByName(self.Scriptname)) then
		return false
	end
	
	local ID = assert( Logic.GetEntityIDByName( self.Scriptname , _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: IO is invalid") )

	Logic.InteractiveObjectSetAvailability( ID, true )
	for i = 1, 8 do
		Logic.InteractiveObjectSetPlayerState(ID, i, 0)
	end

end

function Reward_InteractiveObjectActivate:DEBUG(_Quest)
	
	if Logic.IsEntityDestroyed( self.Scriptname ) or not Logic.IsInteractiveObject(Logic.GetEntityIDByName(self.Scriptname)) then
		yam(_Quest.Identifier .. ":  Error in " .. self.Name ..": Entity " .. self.Scriptname .. " not found or no IO.")
		return true
	end
	
end

AddQuestBehavior(Reward_InteractiveObjectActivate)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_MapScriptFunction
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_MapScriptFunction = {
	Name = "Reward_MapScriptFunction",
	Description = {
		en = "Reward: Calls a function from the mapscript",
		de = "Lohn: Ruft eine Funktion aus dem Kartenscript auf",
	},
	Parameter = {
		{ ParameterType.Default, en = "Function name", de = "Funktionsname" },
	},
}

function Reward_MapScriptFunction:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_MapScriptFunction:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.FuncName = _Parameter	
	end

end

function Reward_MapScriptFunction:CustomFunction(_Quest)
	
	if not self.FuncName then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": No function name ")
	elseif type(_G[self.FuncName]) ~= "function" then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Function does not exist: " .. self.FuncName)
	else
		_G[self.FuncName](_Quest.Identifier)
	end
	
end

AddQuestBehavior(Reward_MapScriptFunction)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_Merchant
-- User Generated zweispeer
------------------------------------------------------------------------------------------------------------------------------

Reward_Merchant = {
	Name = "Reward_Merchant",
	Description = {
		en = "Reward: Deletes all existing offers for a merchant and sets new offers, if given",
		de = "Lohn: Loescht alle Angebote eines Haendlers und setzt neue, wenn angegeben",
	},
	Parameter = {
		{ ParameterType.Custom, en = "PlayerID", de = "PlayerID" },
		{ ParameterType.Custom, en = "Amount 1", de = "Menge 1" },
		{ ParameterType.Custom, en = "Offer 1", de = "Angebot 1" },
		{ ParameterType.Custom, en = "Amount 2", de = "Menge 2" },
		{ ParameterType.Custom, en = "Offer 2", de = "Angebot 2" },
		{ ParameterType.Custom, en = "Amount 3", de = "Menge 3" },
		{ ParameterType.Custom, en = "Offer 3", de = "Angebot 3" },
		{ ParameterType.Custom, en = "Amount 4", de = "Menge 4" },
		{ ParameterType.Custom, en = "Offer 4", de = "Angebot 4" },
	},
}

function Reward_Merchant:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_Merchant:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.PlayerID = _Parameter*1	
	elseif (_Index == 1) then
		self.AmountOffer1 = _Parameter*1
	elseif (_Index == 2) then
		self.Offer1 = _Parameter
	elseif (_Index == 3) then
		self.AmountOffer2 = _Parameter*1
	elseif (_Index == 4) then
		self.Offer2 = _Parameter
	elseif (_Index == 5) then
		self.AmountOffer3 = _Parameter*1
	elseif (_Index == 6) then
		self.Offer3 = _Parameter
	elseif (_Index == 7) then
		self.AmountOffer4 = _Parameter*1
	elseif (_Index == 8) then
		self.Offer4 = _Parameter
	end

end

function Reward_Merchant:CustomFunction()

	if (self.PlayerID > 1) and (self.PlayerID < 9) then
		local Storehouse = Logic.GetStoreHouse(self.PlayerID)
		Logic.RemoveAllOffers(Storehouse)
		for i =  1,4 do
			if (self["Offer"..i] ~= "NoOffer") and self["Offer"..i] then
				if Goods[self["Offer"..i]] then
					AddOffer(Storehouse, self["AmountOffer"..i], Goods[self["Offer"..i]])
				elseif Logic.IsEntityTypeInCategory(Entities[self["Offer"..i]], EntityCategories.Military) == 1 then
					AddMercenaryOffer(Storehouse, self["AmountOffer"..i], Entities[self["Offer"..i]])
				else
					AddEntertainerOffer (Storehouse , Entities[self["Offer"..i]])
				end
			end
		end
	end

end

function Reward_Merchant:DEBUG(_Quest)

	if Logic.GetStoreHouse(self.PlayerID ) == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.PlayerID .. " is dead. :-(")
		return true
	end

end

function Reward_Merchant:GetCustomData(_Index)

	local Players = { "2", "3", "4", "5", "6", "7", "8" }
	local Amount = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }
	local Offers = {"NoOffer",
					"G_Beer",
					"G_Bow",
					"G_Bread",
					"G_Broom",
					"G_Candle",
					"G_Carcass",
					"G_Cheese",
					"G_Clothes",
					"G_Cow",
					"G_Grain",
					"G_Herb",
					"G_Honeycomb",
					"G_Iron",
					"G_Leather",
					"G_Medicine",
					"G_Milk",
					"G_RawFish",
					"G_Sausage",
					"G_Sheep",
					"G_SmokedFish",
					"G_Soap",
					"G_Stone",
					"G_Sword",
					"G_Wood",
					"G_Wool",
					"G_Salt",
					"G_Dye",
					"U_MilitaryBandit_Melee_ME",
					"U_MilitaryBandit_Melee_SE",
					"U_MilitaryBandit_Melee_NA",
					"U_MilitaryBandit_Melee_NE",
					"U_MilitaryBandit_Ranged_ME",
					"U_MilitaryBandit_Ranged_NA",
					"U_MilitaryBandit_Ranged_NE",
					"U_MilitaryBandit_Ranged_SE",
					"U_Entertainer_NA_FireEater",
					"U_Entertainer_NA_StiltWalker",
					"U_Entertainer_NE_StrongestMan_Barrel",
					"U_Entertainer_NE_StrongestMan_Stone",
					}
	if g_GameExtraNo and g_GameExtraNo >= 1 then
		table.insert(Offers, "G_Gems")
		table.insert(Offers, "G_Olibanum")
		table.insert(Offers, "G_MusicalInstrument")
		table.insert(Offers, "G_MilitaryBandit_Ranged_AS")
		table.insert(Offers, "G_MilitaryBandit_Melee_AS")
	end
	if (_Index == 0) then 
		return Players 
	elseif (_Index == 1) or (_Index == 3) or (_Index == 5) or (_Index == 7) then 
		return Amount 
	elseif (_Index == 2) or (_Index == 4) or (_Index == 6) or (_Index == 8) then 
		return Offers
	end
end

AddQuestBehavior(Reward_Merchant)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_MountOutpost
-- User Generated zweispeer
------------------------------------------------------------------------------------------------------------------------------

Reward_MountOutpost = {
	Name = "Reward_MountOutpost",
	Description = {		
		en = "Reward: Places a troop of archers on a named outpost",
		de = "Lohn: Platziert einen Trupp Bogenschuetzen auf einem Aussenposten der KI",	
			},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script name", de = "Skriptname" },
			},
}

function Reward_MountOutpost:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_MountOutpost:AddParameter(_Index, _Parameter)

	assert(_Index == 0, "Error in " .. self.Name .. ": AddParameter: Index is invalid")
	self.Scriptname = _Parameter

end

function Reward_MountOutpost:CustomFunction(_Quest)

	local outpostID = assert( 	not Logic.IsEntityDestroyed(self.Scriptname) 
								and Logic.GetEntityIDByName(self.Scriptname), 
								_Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Outpost is invalid")
	local AIPlayerID = Logic.EntityGetPlayer(outpostID)
	local ax, ay = Logic.GetBuildingApproachPosition(outpostID)
	local TroopID = Logic.CreateBattalionOnUnblockedLand(Entities.U_MilitaryBow, ax, ay, 0, AIPlayerID, 0)
	AICore.HideEntityFromAI(AIPlayerID, TroopID, true)
	Logic.CommandEntityToMountBuilding(TroopID, outpostID)

end

function Reward_MountOutpost:DEBUG(_Quest)

	if Logic.IsEntityDestroyed(self.Scriptname) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Outpost " .. self.Scriptname .. " is missing")
		return true
	end
	
end

AddQuestBehavior(Reward_MountOutpost)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_MoveSettler
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_MoveSettler = {
	Name = "Reward_MoveSettler",
	Description = {
		en = "Reward: Moves a (NPC) settler to a destination. Must not be AI controlled, or it won't move",
		de = "Lohn: Bewegt einen (NPC) Siedler zu einem Zielort. Darf keinem KI Spieler gehoeren, ansonsten wird sich der Siedler nicht bewegen",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Settler", de = "Siedler" },
		{ ParameterType.ScriptName, en = "Destination", de = "Ziel" },
	},
}

function Reward_MoveSettler:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_MoveSettler:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.ScriptnameUnit = _Parameter	
	elseif (_Index == 1) then	
		self.ScriptnameDest = _Parameter	
	end

end

function Reward_MoveSettler:CustomFunction()
	
	if Logic.IsEntityDestroyed( self.ScriptnameUnit ) 
	or Logic.IsEntityDestroyed( self.ScriptnameDest ) 
	or not Logic.IsSettler( self.ScriptnameUnit )
	then
		return false
	end
	
	local DestID = Logic.GetEntityIDByName( self.ScriptnameDest )
	local DestX, DestY = Logic.GetEntityPosition( DestID )

	if Logic.IsBuilding( DestID ) == 1 then
		DestX, DestY = Logic.GetBuildingApproachPosition( DestID )
	end
	
	Logic.MoveSettler( Logic.GetEntityIDByName( self.ScriptnameUnit ), DestX, DestY )

end

function Reward_MoveSettler:DEBUG(_Quest)

	if Logic.IsEntityDestroyed( self.ScriptnameUnit ) or not Logic.IsSettler(self.ScriptnameUnit) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.ScriptnameUnit .. " is missing or no Settler")
		return true
	elseif Logic.IsEntityDestroyed( self.ScriptnameDest ) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.ScriptnameDest .. " is missing")
		return true
	elseif WikiQSB.EntitiesCreatedByQuests[self.ScriptnameUnit] == _Quest then
		yam(_Quest.Identifier .. ":  Hint in " .. self.Name ..": Don't move an entity in the same quest it is created")
		return true
	end
	
end

AddQuestBehavior(Reward_MoveSettler)


------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_ObjectAddReward
-- User Generated OldMcDonald
------------------------------------------------------------------------------------------------------------------------------
 
Reward_ObjectAddReward = {
	Name = "Reward_ObjectAddReward",
	Description = {
		en = "Reward: Adds a reward to an interactive object",
		de = "Lohn: Fuegt eine Belohnung zu dem interaktiven Objekt hinzu",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script name", de = "Skriptname" },
		{ ParameterType.Custom, en = "Good type", de = "Warentyp" },
		{ ParameterType.Number, en = "Good amount", de = "Warenmenge" },
	},
}
 
function Reward_ObjectAddReward:GetRewardTable()
 
	return { Reward.Custom,{self, self.CustomFunction} }
 
end
 
function Reward_ObjectAddReward:AddParameter(_Index, _Parameter)
 
	if (_Index == 0) then	
		self.Scriptname = _Parameter
	elseif (_Index == 1) then
		self.GoodType = _Parameter
	elseif (_Index == 2) then
		self.GoodAmount = _Parameter*1
	end
 
end
 
function Reward_ObjectAddReward:CustomFunction(_Quest)
 
	if Logic.IsEntityDestroyed(self.Scriptname) 
	or not Logic.IsInteractiveObject(Logic.GetEntityIDByName(self.Scriptname))
	then
		assert(false, _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Script name is invalid")
	end
	local IO = Logic.GetEntityIDByName(self.Scriptname)
	
	Logic.InteractiveObjectAddRewards(IO, Goods[self.GoodType], self.GoodAmount)
	
end

function Reward_ObjectAddReward:DEBUG(_Quest)

	if not WikiQSB.Reward_ObjectInit[self.Scriptname] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Object " .. self.Scriptname .. " is not initialised")
		return true
	elseif WikiQSB.Reward_ObjectInit[self.Scriptname] == _Quest then
		yam(_Quest.Identifier .. ": Hint in " .. self.Name .. ": Don't customize an interactive object in the quest you initialized it")
		return true
	elseif not Goods[self.GoodType] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": GoodType is wrong")
		return true
	elseif self.GoodAmount < 1 then 
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": GoodAmount is wrong")
		return true
	end

end

function Reward_ObjectAddReward:GetCustomData(_Index)
 
	local Data = {}
	if _Index == 1 then
		for k, v in pairs( Goods ) do
			if string.find( k, "^G_" ) then
				table.insert( Data, k )
			end
		end
	else
		assert( false, "Error in " .. self.Name .. ": GetCustomData: Index is invalid" )
	end
 
	return Data
 
end

AddQuestBehavior(Reward_ObjectAddReward)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_ObjectClearRewards
-- User Generated OldMcDonald
------------------------------------------------------------------------------------------------------------------------------
 
Reward_ObjectClearRewards = {
	Name = "Reward_ObjectClearRewards",
	Description = {
		en = "Reward: Clears all rewards of an interactive object",
		de = "Lohn: Entfernt alle Belohnungen von einem interaktiven Objekt",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script name", de = "Skriptname" },
	},
}
 
function Reward_ObjectClearRewards:GetRewardTable()
 
	return { Reward.Custom,{self, self.CustomFunction} }
 
end
 
function Reward_ObjectClearRewards:AddParameter(_Index, _Parameter)
 
	if (_Index == 0) then	
		self.Scriptname = _Parameter
	end
 
end
 
function Reward_ObjectClearRewards:CustomFunction(_Quest)

	if Logic.IsEntityDestroyed(self.Scriptname) 
	or not Logic.IsInteractiveObject(Logic.GetEntityIDByName(self.Scriptname))
	then
		assert( false, _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Script name is invalid" )
	end
	local IO = Logic.GetEntityIDByName(self.Scriptname)
	
	Logic.InteractiveObjectClearRewards(IO)
end

function Reward_ObjectClearRewards:DEBUG(_Quest)

	if not WikiQSB.Reward_ObjectInit[self.Scriptname] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Object " .. self.Scriptname .. " is not initialised")
		return true
	elseif WikiQSB.Reward_ObjectInit[self.Scriptname] == _Quest then
		yam(_Quest.Identifier .. ": Hint in " .. self.Name .. ": Don't customize an interactive object in the quest you initialized it")
		return true
	end

end

AddQuestBehavior(Reward_ObjectClearRewards)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_ObjectInit
-- User Generated OldMcDonald
------------------------------------------------------------------------------------------------------------------------------
 
Reward_ObjectInit = {
	Name = "Reward_ObjectInit",
	Description = {
		en = "Reward: Initialises an interactive object",
		de = "Lohn: Initialisiert ein interaktives Objekt",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script name", de = "Skriptname" },
		{ ParameterType.Custom, en = "Type of use", de = "Art der Nutzung" },
		{ ParameterType.Number, en = "Time till Action", de = "Zeit bis Betaetigung" },
		{ ParameterType.Number, en = "Distance", de = "Entfernung" },
	},
}
 
function Reward_ObjectInit:GetRewardTable()
 
	return { Reward.Custom,{self, self.CustomFunction} }
 
end
 
function Reward_ObjectInit:AddParameter(_Index, _Parameter)
 
	if (_Index == 0) then	
		self.Scriptname = _Parameter
	elseif (_Index == 1) then
		self.TypeUse = _Parameter
	elseif (_Index == 2) then
		self.TimeUse = _Parameter*1
	elseif (_Index == 3) then
		self.Distance = _Parameter*1
	end
 
end
 
function Reward_ObjectInit:CustomFunction(_Quest)
 
	local IO = Logic.GetEntityIDByName(self.Scriptname)
	if Logic.IsEntityDestroyed(self.Scriptname) 
	or not Logic.IsInteractiveObject(IO)
	then
		assert(false, _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: IO is invalid")
	end
	Logic.InteractiveObjectSetPlayerState(IO, 1, 	(self.TypeUse == "Always" and 1) 
												or 	(self.TypeUse == "Never"  and 2) or 0)
	Logic.InteractiveObjectSetAvailability(IO, true)
	if type(self.Distance) ~= "number" or self.Distance <= 0 then
		self.Distance = 1000;
	end
	if type(self.TimeUse) ~= "number" or self.TimeUse < 0 then
		self.TimeUse = 5;
	end
	Logic.InteractiveObjectSetInteractionDistance(IO, self.Distance)
	Logic.InteractiveObjectSetTimeToOpen(IO, self.TimeUse)
	
	Logic.InteractiveObjectClearCosts(IO)
	Logic.InteractiveObjectClearRewards(IO);
	
	Logic.InteractiveObjectSetCostGoldCartType(IO, Entities.U_GoldCart);
	Logic.InteractiveObjectSetCostResourceCartType(IO, Entities.U_ResourceMerchant);
	
	Logic.InteractiveObjectSetRewardGoldCartType(IO, Entities.U_GoldCart);
	Logic.InteractiveObjectSetRewardResourceCartType(IO, Entities.U_ResourceMerchant);
	
	RemoveInteractiveObjectFromOpenedList(IO);
	
	WikiQSB.Reward_ObjectInit[self.Scriptname] = _Quest
	
end

function Reward_ObjectInit:DEBUG(_Quest)

	if Logic.IsEntityDestroyed(self.Scriptname) or not Logic.IsInteractiveObject(Logic.GetEntityIDByName(self.Scriptname)) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.Scriptname .. " is missing or no IO")
		return true
	elseif not self.TimeUse or self.TimeUse < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": TimeUse is wrong")
		return true
	elseif self.Distance < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Distance is negative")
		return true
	end
	
end

function Reward_ObjectInit:GetCustomData(_Index)
 
	local Data = {}
	if (_Index == 1) then
		table.insert( Data, "Knight only" )
		table.insert( Data, "Always" )
		table.insert( Data, "Never" )
	else
		assert( false, "Error in " .. self.Name .. ": GetCustomData: Index is invalid" )
	end
 
	return Data
 
end

AddQuestBehavior(Reward_ObjectInit)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_ObjectSetCarts
-- User Generated OldMcDonald
------------------------------------------------------------------------------------------------------------------------------
 
Reward_ObjectSetCarts = {
	Name = "Reward_ObjectSetCarts",
	Description = {
		en = "Reward: Sets the (delivering) carts of an interactive object",
		de = "Lohn: Legt die (Liefer-)Wagen eines interaktiven Objektes fest",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script name", de = "Skriptname" },
		{ ParameterType.Custom, en = "Cart delivering goods as costs", de = "Waren liefernder Wagen fuer Kosten" },
		{ ParameterType.Custom, en = "Cart delivering goods as rewards", de = "Waren liefernder Wagen fuer Belohnungen" },
	},
}
 
function Reward_ObjectSetCarts:GetRewardTable()
 
	return { Reward.Custom,{self, self.CustomFunction} }
 
end
 
function Reward_ObjectSetCarts:AddParameter(_Index, _Parameter)
 
	if (_Index == 0) then	
		self.Scriptname = _Parameter
	elseif (_Index == 1) then
		self.CostResourceCart = _Parameter
	elseif (_Index == 2) then
		self.RewardResourceCart = _Parameter
	end
 
end
 
function Reward_ObjectSetCarts:CustomFunction(_Quest)
 
	if Logic.IsEntityDestroyed(self.Scriptname) 
	or not Logic.IsInteractiveObject(Logic.GetEntityIDByName(self.Scriptname))
	then
		assert(false, _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: IO is invalid")
	end	
	local IO = Logic.GetEntityIDByName(self.Scriptname)
	Logic.InteractiveObjectSetCostResourceCartType(IO, Entities[self.CostResourceCart])
	Logic.InteractiveObjectSetRewardResourceCartType(IO, Entities[self.RewardResourceCart])
	
end

function Reward_ObjectSetCarts:DEBUG(_Quest)

	if not WikiQSB.Reward_ObjectInit[self.Scriptname] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Object " .. self.Scriptname .. " is not initialised")
		return true
	elseif WikiQSB.Reward_ObjectInit[self.Scriptname] == _Quest then
		yam(_Quest.Identifier .. ": Hint in " .. self.Name .. ": Don't customize an interactive object in the quest you initialized it")
		return true
	elseif not Entities[self.CostResourceCart] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": CostResourceCart is wrong")
		return true
	elseif not Entities[self.RewardResourceCart] then 
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": RewardResourceCart is wrong")
		return true
	end

end

function Reward_ObjectSetCarts:GetCustomData(_Index)
 
	assert(_Index == 1 or _Index == 2, "Error in " .. self.Name .. ": GetCustomData: Index is invalid");
	return { "U_ResourceMerchant", "U_Marketer", "U_Medicus", "U_ThiefCart", "U_PrisonCart", "U_Noblemen_Cart" }

end

AddQuestBehavior(Reward_ObjectSetCarts)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_ObjectSetupCosts
-- User Generated OldMcDonald
------------------------------------------------------------------------------------------------------------------------------
 
Reward_ObjectSetupCosts = {
	Name = "Reward_ObjectSetupCosts",
	Description = {
		en = "Reward: Sets the costs of an interactive object",
		de = "Lohn: Legt die Kosten eines interaktiven Objektes fest",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script name", de = "Skriptname" },
		{ ParameterType.Custom, en = "Number of costs", de = "Anzahl der Kosten" },
		{ ParameterType.Custom, en = "First good type", de = "Erster Warentyp" },
		{ ParameterType.Number, en = "First good amount", de = "Erster Warenmenge" },
		{ ParameterType.Custom, en = "Second good type", de = "Zweiter Warentyp" },
		{ ParameterType.Number, en = "Second good amount", de = "Zweite Warenmenge" },
	},
}
 
function Reward_ObjectSetupCosts:GetRewardTable()
 
	return { Reward.Custom,{self, self.CustomFunction} }
 
end
 
function Reward_ObjectSetupCosts:AddParameter(_Index, _Parameter)
 
	if (_Index == 0) then	
		self.Scriptname = _Parameter
	elseif (_Index == 1) then
		self.NumberOfCosts = _Parameter*1
	elseif _Index % 2 == 0 then
		self["GoodType" .. (_Index / 2)] = _Parameter
	else
		self["GoodAmount" .. ((_Index - 1) / 2)] = _Parameter*1
	end
 
end
 
function Reward_ObjectSetupCosts:CustomFunction(_Quest)
	
	if Logic.IsEntityDestroyed(self.Scriptname) 
	or not Logic.IsInteractiveObject(Logic.GetEntityIDByName(self.Scriptname))
	then
		assert(false, _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: IO is invalid")
	end
	local IO = Logic.GetEntityIDByName(self.Scriptname)
	Logic.InteractiveObjectClearCosts(IO)
	
	for i = 1, self.NumberOfCosts do
		local goodType = assert( Goods[self["GoodType" .. i]]);
		Logic.InteractiveObjectAddCosts(IO, goodType, assert(self["GoodAmount" .. i] > 0 and self["GoodAmount" .. i]));
	end
	
end

function Reward_ObjectSetupCosts:DEBUG(_Quest)

	if not WikiQSB.Reward_ObjectInit[self.Scriptname] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Object " .. self.Scriptname .. " is not initialised")
		return true
	elseif WikiQSB.Reward_ObjectInit[self.Scriptname] == _Quest then
		yam(_Quest.Identifier .. ": Hint in " .. self.Name .. ": Don't customize an interactive object in the quest you initialized it")
		return true
	elseif self.NumberOfCosts ~= 1 and self.NumberOfCosts ~= 2 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Number of Costs is wrong.")
		return true
	end
	for i = 1, self.NumberOfCosts do
		if not self["GoodType" .. i] then
			yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Good type ".. i .. " is wrong.")
			return true
		elseif self["GoodAmount" .. i] < 1 then
			yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Good amount ".. i .. " is wrong.")
			return true
		end
	end

end

function Reward_ObjectSetupCosts:GetCustomData(_Index)
 
	local Data = {}
	assert(_Index == 1 or (_Index > 1 and _Index % 2 == 0), "Error in " .. self.Name .. ": GetCustomData: Index is invalid")
	if _Index == 1 then
		return { "0", "1", "2" };
	elseif _Index == 2 then
		for k, v in pairs( Goods ) do
			if string.find( k, "^G_" ) then
				table.insert( Data, k )
			end
		end
	else
		return { "G_Gold", "G_Wood", "G_Stone" }; --only wood, stone and gold are supported combined with other resources (see AreCostsAffordable())
	end
 
	return Data
 
end

AddQuestBehavior(Reward_ObjectSetupCosts)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_PrestigePoints
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_PrestigePoints = {
	Name = "Reward_PrestigePoints",
	Description = {
		en = "Reward: Prestige",
		de = "Lohn: Prestige",
	},
	Parameter = {
		{ ParameterType.Number, en = "Points", de = "Punkte" },
	},
}

function Reward_PrestigePoints:AddParameter(_Index, _Parameter)

	if (_Index == 0) then
		self.Points = _Parameter * 1
	end
	
end

function Reward_PrestigePoints:GetRewardTable()

	return { Reward.PrestigePoints, self.Points }

end

AddQuestBehavior(Reward_PrestigePoints)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_QuestActivate
-- User generated 
------------------------------------------------------------------------------------------------------------------------------
Reward_QuestActivate = {
	Name = "Reward_QuestActivate",
	Description = {
		en = "Reward: Activates a quest that is not triggered yet.",
		de = "Belohnung: Aktiviert eine Quest die noch nicht ausgeloest wurde.",
				},
	Parameter = {
		{ParameterType.QuestName, en = "Quest name", de = "Questname", },
	},
}

function Reward_QuestActivate:GetRewardTable()

	return {Reward.Custom, {self, self.CustomFunction} }

end

function Reward_QuestActivate:AddParameter(_Index, _Parameter)

	if (_Index==0) then
		self.QuestName = _Parameter
	else
		assert(false, "Error in " .. self.Name .. ": AddParameter: Index is invalid")
	end

end

function Reward_QuestActivate:CustomFunction(_Quest)

	local questID = GetQuestByName(self.QuestName)
	if questID then
		local quest = Quests[questID]
		if quest.State == QuestState.NotTriggered then
			quest:SetMsgKeyOverride()
			quest:SetIconOverride()
			quest:Trigger()
		end
	end
	
end

function Reward_QuestActivate:DEBUG(_Quest)

	if not IsValidQuest(self.QuestName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " does not exist")
		return true
	-- elseif Quests[g_QuestNameToID[self.QuestName]].State ~= QuestState.NotTriggered then
		-- yam(_Quest.Identifier .. ": Minor Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " is already triggered or over")
		-- return true
	end	
	
end

AddQuestBehavior(Reward_QuestActivate)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_QuestFailure
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_QuestFailure = {
	Name = "Reward_QuestFailure",
	Description = {
		en = "Reprisal: Lets another active quest fail",
		de = "Vergeltung: Laesst eine andere aktive Quest fehlschlagen",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name", de = "Questname" },
	},
}

function Reward_QuestFailure:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_QuestFailure:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.QuestName = _Parameter	
	end

end

function Reward_QuestFailure:CustomFunction()

	if IsValidQuest(self.QuestName) then
	
		local QuestID = GetQuestByName(self.QuestName)
		local Quest = Quests[QuestID]
		if Quest.State == QuestState.Active then
			Quest:Fail()
		end
	end
   
end

function Reward_QuestFailure:DEBUG(_Quest)

	if not IsValidQuest(self.QuestName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " does not exist")
		return true
	end	
	
end

AddQuestBehavior(Reward_QuestFailure)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_QuestForceInterrupt
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_QuestForceInterrupt = {
	Name = "Reward_QuestForceInterrupt",
	Description = {
		en = "Reward: Interrupts a quest even when it isn't active yet",
		de = "Lohn: Beendet eine aktive Quest auch wenn diese noch nicht aktiv ist",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name", de = "Questname" },
		{ ParameterType.Custom, en = "Ended quests", de = "Beendete Quests" },
	},
}

function Reward_QuestForceInterrupt:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_QuestForceInterrupt:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.QuestName = _Parameter	
	elseif (_Index == 1) then	
		self.InterruptEnded = _Parameter == "+"
	end

end

function Reward_QuestForceInterrupt:GetCustomData( _Index )

	local Data = {}
	if _Index == 1 then
		table.insert( Data, "-" )
		table.insert( Data, "+" )
		
	else
		assert( false, "Error in " .. self.Name .. ": GetCustomData: Index is invalid" )
	end
	
	return Data
	
end


function Reward_QuestForceInterrupt:CustomFunction()

	if IsValidQuest(self.QuestName) then
	
		local QuestID = g_QuestNameToID[self.QuestName]		
		local Quest = Quests[QuestID]
		if self.InterruptEnded or Quest.State ~= QuestState.Over then
			Quest:Interrupt()
		end
	end
   
end

function Reward_QuestForceInterrupt:DEBUG(_Quest)

	if not IsValidQuest(self.QuestName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " does not exist")
		return true
	end	
	
end

AddQuestBehavior(Reward_QuestForceInterrupt)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_QuestInterrupt
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_QuestInterrupt = {
	Name = "Reward_QuestInterrupt",
	Description = {
		en = "Reward: Interrupts a quest. The quest ends without success or failure",
		de = "Lohn: Beendet eine aktive Quest ohne Erfolg oder Misserfolg",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name", de = "Questname" },
	},
}

function Reward_QuestInterrupt:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_QuestInterrupt:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.QuestName = _Parameter	
	end

end

function Reward_QuestInterrupt:CustomFunction()

	if IsValidQuest(self.QuestName) then
	
		local QuestID = GetQuestByName(self.QuestName)
		local Quest = Quests[QuestID]
		if Quest.State == QuestState.Active then
			Quest:Interrupt()
		end
		
	end
   
end

function Reward_QuestInterrupt:DEBUG(_Quest)

	if not IsValidQuest(self.QuestName) == nil then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " does not exist")
		return true
	end	
	
end

AddQuestBehavior(Reward_QuestInterrupt)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_QuestSuccess
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_QuestSuccess = {
	Name = "Reward_QuestSuccess",
	Description = {
		en = "Reward: Lets another active quest complete successfully",
		de = "Lohn: Beendet eine andere aktive Quest erfolgreich",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name", de = "Questname" },
	},
}

function Reward_QuestSuccess:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_QuestSuccess:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.QuestName = _Parameter	
	end

end

function Reward_QuestSuccess:CustomFunction()

	if IsValidQuest(self.QuestName) then
	
		local QuestID = GetQuestByName(self.QuestName)
		local Quest = Quests[QuestID]
		if Quest.State == QuestState.Active then
			Quest:Success()
		end
	end
   
end

function Reward_QuestSuccess:DEBUG(_Quest)

	if not IsValidQuest(self.QuestName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " does not exist")
		return true
	end	
	
end

AddQuestBehavior(Reward_QuestSuccess)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_Resources
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_Resources = {
	Name = "Reward_Resources",
	Description = {
		en = "Reward: Resources",
		de = "Lohn: Resourcen",
	},
	Parameter = {
		{ ParameterType.RawGoods, en = "Type of good", de = "Resourcentyp" },
		{ ParameterType.Number, en = "Amount of good", de = "Anzahl der Resource" },
	},
}

function Reward_Resources:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.GoodTypeName = _Parameter
	elseif (_Index == 1) then	
		self.GoodAmount = _Parameter * 1
	end
	
end

function Reward_Resources:GetRewardTable()

	local GoodType = Logic.GetGoodTypeID(self.GoodTypeName)
	return { Reward.Resources, GoodType, self.GoodAmount }

end

AddQuestBehavior(Reward_Resources)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_RestartQuest
-- BB Original changed to fix other Behaviors, 
------------------------------------------------------------------------------------------------------------------------------

Reward_RestartQuest = {
	Name = "Reward_RestartQuest",
	Description = {
		en = "Reward: Restarts a (completed) quest so it can be triggered and completed again",
		de = "Lohn: Startet eine (beendete) Quest neu, damit diese neu ausgeloest und beendet werden kann",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name", de = "Questname" },
	},
}

function Reward_RestartQuest:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_RestartQuest:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.QuestName = _Parameter	
	end

end

function Reward_RestartQuest:CustomFunction()
	self:ResetQuest();
end

function Reward_RestartQuest:DEBUG(_Quest)

	if not IsValidQuest(self.QuestName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " does not exist")
		return true
	end	
	
end

function Reward_RestartQuest:ResetQuest()

	if IsValidQuest(self.QuestName) then
		local QuestID = GetQuestByName(self.QuestName)
		local Quest = Quests[QuestID]
		if Quest.Objectives then
			local questObjectives = Quest.Objectives;
			for i = 1, questObjectives[0] do
				local objective = questObjectives[i];
				objective.Completed = nil
				local objectiveType = objective.Type;
				if objectiveType == Objective.Deliver then
					local data = objective.Data;
					data[3] = nil
					data[4] = nil
					data[5] = nil
				elseif g_GameExtraNo and g_GameExtraNo >= 1 and objectiveType == Objective.Refill then
					objective.Data[2] = nil
				elseif objectiveType == Objective.Protect or objectiveType == Objective.Object then
					local data = objective.Data;
					for j=-1, -data[0], -1 do
						data[j] = nil
					end
				elseif objectiveType == Objective.DestroyEntities and objective.Data[1] ~= 1 and objective.DestroyTypeAmount then
					objective.Data[3] = objective.DestroyTypeAmount;
				elseif objectiveType == Objective.Custom2 and objective.Data[1].Reset then
					objective.Data[1]:Reset(Quest)
				end
			end
		end
		local function resetCustom(_type, _customType)
			local Quest = Quest;
			local behaviors = Quest[_type];
			if behaviors then
				for i = 1, behaviors[0] do
					local behavior = behaviors[i];
					if behavior.Type == _customType then
						local behaviorDef = behavior.Data[1];
						if behaviorDef and behaviorDef.Reset then
							behaviorDef:Reset(Quest);
						end
					end
				end
			end
		end
		
		resetCustom("Triggers", Triggers.Custom2);
		resetCustom("Rewards", Reward.Custom);
		resetCustom("Reprisals", Reprisal.Custom);
		
		Quest.Result = nil
		local OldQuestState = Quest.State
		Quest.State = QuestState.NotTriggered
		Logic.ExecuteInLuaLocalState("LocalScriptCallback_OnQuestStatusChanged("..Quest.Index..")")
		if OldQuestState == QuestState.Over then
			Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_SECOND, "", QuestTemplate.Loop, 1, 0, { Quest.QueueID })
		end
		return QuestID, Quest;
	end
end

AddQuestBehavior(Reward_RestartQuest)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_RestartQuestForceActive
-- User Generated 
------------------------------------------------------------------------------------------------------------------------------

Reward_RestartQuestForceActive = {
	Name = "Reward_RestartQuestForceActive",
	Description = {
		en = "Reward: Restarts a (completed) quest and triggers it immediately",
		de = "Lohn: Startet eine (beendete) Quest neu und triggert sie sofort",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name", de = "Questname" },
	},
}

function Reward_RestartQuestForceActive:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_RestartQuestForceActive:AddParameter(_Index, _Parameter)

	assert(_Index == 0, "Error in " .. self.Name .. ": AddParameter: Index is invalid.")
	self.QuestName = _Parameter	

end

function Reward_RestartQuestForceActive:CustomFunction()

	local QuestID, Quest = self:ResetQuest();
	if QuestID then
		Quest:SetMsgKeyOverride()
		Quest:SetIconOverride()
		Quest:Trigger()
	end
end

Reward_RestartQuestForceActive.ResetQuest = Reward_RestartQuest.ResetQuest;
function Reward_RestartQuestForceActive:DEBUG(_Quest)

	if not IsValidQuest(self.QuestName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " does not exist")
		return true
	end	
	
end

AddQuestBehavior(Reward_RestartQuestForceActive)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_SendCart
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_SendCart = {
	Name = "Reward_SendCart",
	Description = {
		en = "Reward: Sends a cart to a player. It spawns at a building or by replacing a script entity. The cart retains the script entities name",
		de = "Lohn: Sendet einen Karren zu einem Spieler. Der Karren wird an einem Gebaeude erstellt, oder ersetzt eine bestehende ScriptEntity. Der Karren uebernimmt den Namen der ScriptEntity",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Script entity", de = "Script Entity" },
		{ ParameterType.PlayerID, en = "Target player", de = "Zielspieler" },
   		{ ParameterType.Custom, en = "Type name", de = "Typbezeichnung" },
   		{ ParameterType.Custom, en = "Good type", de = "Warentyp" },
   		{ ParameterType.Number, en = "Amount", de = "Anzahl" },
   		{ ParameterType.Custom, en = "(Expert) Override target player", de = "(Expert) Anderer Zielspieler" },
   		{ ParameterType.Custom, en = "(Expert) Ignore reservations", de = "(Expert) Ignoriere Reservierungen" },
	},
}

function Reward_SendCart:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_SendCart:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.ScriptnameEntity = _Parameter	
	elseif (_Index == 1) then	
		self.PlayerID = _Parameter * 1
	elseif (_Index == 2) then	
		self.UnitKey = _Parameter
	elseif (_Index == 3) then	
		self.GoodType = _Parameter
	elseif (_Index == 4) then	
		self.GoodAmount = _Parameter * 1
	elseif (_Index == 5) then	
		self.OverrideTargetPlayer = tonumber(_Parameter)
	elseif (_Index == 6) then	
		self.IgnoreReservation = _Parameter == "+"
	end

end

function Reward_SendCart:CustomFunction(_Quest)
	
	if Logic.IsEntityDestroyed( self.ScriptnameEntity ) then
		return false
	end
	
	local SpawnID = Logic.GetEntityIDByName( self.ScriptnameEntity )
	local SpawnIsBuilding = Logic.IsBuilding( SpawnID ) == 1
	local CartID
	assert( Entities[self.UnitKey], _Quest.Identifier .. ": Error in ".. self.Name .. ": CustomFunction: Type name is invalid" )
	if SpawnIsBuilding then
		CartID = Logic.CreateEntityAtBuilding( Entities[self.UnitKey], SpawnID, 0, self.PlayerID )
	else
		local X, Y = Logic.GetEntityPosition( SpawnID )
		local Orientation = Logic.GetEntityOrientation( SpawnID )
		Logic.DestroyEntity( SpawnID )
		CartID = Logic.CreateEntityOnUnblockedLand( Entities[self.UnitKey], X, Y, Orientation, self.PlayerID )
		Logic.SetEntityName( CartID, self.ScriptnameEntity )
	end
	
	Logic.HireMerchant( CartID, self.PlayerID, Goods[self.GoodType], self.GoodAmount, self.PlayerID, self.IgnoreReservation )
	if self.OverrideTargetPlayer then
		Logic.ResourceMerchant_OverrideTargetPlayerID( CartID, self.OverrideTargetPlayer )
	end

end

function Reward_SendCart:DEBUG(_Quest)

	if Logic.IsEntityDestroyed( self.ScriptnameEntity ) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.ScriptnameEntity .. " is missing")
		return true
	elseif not Goods[self.GoodType] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Good type is wrong")
		return true
	elseif Logic.GetStoreHouse(self.PlayerID) == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.PlayerID .. " is dead. :-(")
		return true
	elseif self.OverrideTargetPlayer and Logic.GetStoreHouse(self.OverrideTargetPlayer) == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.OverrideTargetPlayer .. " is dead. :-(")
		return true
	elseif self.GoodAmount <= 0 then 
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Good amount is wrong")
		return true
	else
		local player = self.OverrideTargetPlayer or self.PlayerID
		
		if self.GoodType == "G_Gold" then
			if Logic.GetHeadquarters(player) == 0 and Logic.GetIndexOnInStockByGoodType(Logic.GetStoreHouse(player), Goods.G_Gold) == -1 then
				yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. player .. "doesn't have a castle.")
				return true
			elseif not self.UnitKey:find("^U_GoldCart") then
				yam(_Quest.Identifier .. ": Warning in " .. self.Name .. ": Good is not meant to be delivered into the storehouse. Select another cart")
				return true
			end
			return
		end
		
		if self.UnitKey:find("^U_GoldCart") then
			yam(_Quest.Identifier .. ": Warning in " .. self.Name .. ": Good is not meant to be delivered into the castle. Select another cart")
			return true
		end
		
		if Logic.GetIndexOnInStockByGoodType(Logic.GetStoreHouse(player), Goods[self.GoodType]) == -1 then
			if self.UnitKey ~= "U_Marketer" and self.UnitKey ~= "U_Medicus" then
				yam(_Quest.Identifier .. ": Warning in " .. self.Name .. ": Good is not meant to be delivered into the storehouse. Select another cart")
				return true
			end
		elseif self.UnitKey == "U_Marketer" or self.UnitKey == "U_Medicus" then
			yam(_Quest.Identifier .. ": Warning in " .. self.Name .. ": Good is not meant to be delivered to the marketplace. Select another cart")
			return true
		end
	end
	
end

function Reward_SendCart:GetCustomData( _Index )

	local Data = {}
	if _Index == 2 then
		Data = { "U_ResourceMerchant", "U_Medicus", "U_Marketer", "U_ThiefCart", "U_GoldCart", "U_NoblemenCart", "U_RegaliaCart" }
		if g_GameExtraNo and g_GameExtraNo >= 1 then
			table.insert(Data, "U_NPC_Resource_Monk_AS")
		end
		table.sort( Data )

	elseif _Index == 3 then
		for k, v in pairs( Goods ) do
			if string.find( k, "^G_" ) then
				table.insert( Data, k )
			end
		end
		table.sort( Data )
   
	elseif _Index == 5 then
		table.insert( Data, "---" )
		for i = 1, 8 do
			table.insert( Data, i )
		end
	
	elseif _Index == 6 then
		table.insert( Data, "-" )
		table.insert( Data, "+" )
		
	else
		assert( false, "Error in ".. self.Name .. ": GetCustomData: Index is invalid" ) 
	end
	
	return Data
	
end

AddQuestBehavior(Reward_SendCart)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_SetBuildingUpgradeLevel					Quest created by: Old McDonald
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

Reward_SetBuildingUpgradeLevel = {
	Name = "Reward_SetBuildingUpgradeLevel",
	Description = {
		en = "Sets the upgrade level of the specified building",
		de = "Legt das Upgrade-Level eines Gebaeudes fest",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Building", de = "Gebaeude" },
		{ ParameterType.Custom, en = "Upgrade level", de = "Upgrade-Level" },
	}
};
 
function Reward_SetBuildingUpgradeLevel:GetRewardTable()

	return {Reward.Custom, self, self.CustomFunction};

end
 
function Reward_SetBuildingUpgradeLevel:AddParameter(_Index, _Parameter)

	if _Index == 0 then
		self.Building = _Parameter;
	else
		assert(_Index == 1, "Error in ".. self.Name .. ": AddParameter: Index is invalid");
		self.UpgradeLevel = tonumber(_Parameter);
	end

end
 
function Reward_SetBuildingUpgradeLevel:CustomFunction()

	local building = Logic.GetEntityIDByName(self.Building);
	local upgradeLevel = Logic.GetUpgradeLevel(building);
	local maxUpgradeLevel = Logic.GetMaxUpgradeLevel(building);
	if building ~= 0 
	and Logic.IsBuilding(building) == 1 
	and (Logic.IsBuildingUpgradable(building, true) 
	or (maxUpgradeLevel ~= 0 
	and maxUpgradeLevel == upgradeLevel)) 
	then
		Logic.SetUpgradableBuildingState(building, math.min(self.UpgradeLevel, maxUpgradeLevel), 0);
	end

end

function Reward_SetBuildingUpgradeLevel:DEBUG(_Quest)
	
	local building = Logic.GetEntityIDByName( self.Building )
	local maxUpgradeLevel = Logic.GetMaxUpgradeLevel(building);
	if not building or Logic.IsBuilding(building) == 0  then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Building " .. self.Building .. " is missing or no building.")
		return true
	elseif not self.UpgradeLevel 
	or self.UpgradeLevel < 0 
	or self.UpgradeLevel > maxUpgradeLevel
	then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Upgrade level is wrong")
		return true
	end
	
end

function Reward_SetBuildingUpgradeLevel:GetCustomData(_Index)

	assert(_Index == 1, "Error in ".. self.Name .. ": GetCustomData: Index is invalid");
	return { "0", "1", "2", "3" };

end

AddQuestBehavior(Reward_SetBuildingUpgradeLevel)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_SetResourceAmount
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_SetResourceAmount = {
	Name = "Reward_SetResourceAmount",
	Description = {
		en = "Reward: Set the current and maximum amount of a ressource doodad (can also set the amount to 0)",
		de = "Lohn: Setzt die aktuellen sowie maximalen Resourcen in einem Doodad (auch 0 ist moeglich)",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Ressource", de = "Resource" },
		{ ParameterType.Number, en = "Amount", de = "Menge" },
	},
}

function Reward_SetResourceAmount:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_SetResourceAmount:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.Scriptname = _Parameter	
	elseif (_Index == 1) then	
		self.Amount = _Parameter * 1
	end

end

function Reward_SetResourceAmount:CustomFunction()

	if Logic.IsEntityDestroyed( self.Scriptname ) 
	or self.Amount < 0
	then
		return false
	end
	
	local EntityID = Logic.GetEntityIDByName( self.Scriptname )

	if Logic.GetResourceDoodadGoodType( EntityID ) == 0 then
		return false
	end
	
	Logic.SetResourceDoodadGoodAmount( EntityID, self.Amount )
   
end

function Reward_SetResourceAmount:DEBUG(_Quest)
	
	if Logic.IsEntityDestroyed(self.Scriptname) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Entity " .. self.Scriptname .. " is missing.")
		return true
	elseif self.Amount < 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Amount is negative")
		return true
	end
	
end

AddQuestBehavior(Reward_SetResourceAmount)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_SlightlyDiplomacyIncrease
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_SlightlyDiplomacyIncrease = {
	Name = "Reward_SlightlyDiplomacyIncrease",
	Description = {
		en = "Reward: Diplomacy increases slightly to another player",
		de = "Lohn: Verbesserung des Diplomatiestatus zu einem anderen Spieler",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
	},
}

function Reward_SlightlyDiplomacyIncrease:GetRewardTable()

	return {Reward.Diplomacy, self.PlayerID , 1 }

end

function Reward_SlightlyDiplomacyIncrease:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.PlayerID = _Parameter * 1	
	end

end

AddQuestBehavior(Reward_SlightlyDiplomacyIncrease)

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_Technology
-- User generated zweispeer
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Reward_Technology = {
	Name = "Reward_Technology",
	Description = {
		en = "Reward: Locks or UnLocks a Technology for the given Player",
		de = "Belohnung: Sperrt oder erlaubt eine Technolgie fuer den angegebenen Player",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "PlayerID", de = "SpielerID" },
		{ ParameterType.Custom,   en = "Un / Lock", de = "Sperren/Erlauben" },
		{ ParameterType.Custom,   en = "Technology", de = "Technologie" },
	},
}

function Reward_Technology:GetRewardTable()

	return { Reward.Custom, {self, self.CustomFunction} }

end

function Reward_Technology:AddParameter(_Index, _Parameter)

	if (_Index ==0) then
		self.PlayerID = _Parameter*1
	elseif (_Index == 1) then
		self.LockType = _Parameter == "Lock"
	elseif (_Index == 2) then
		self.Technology = _Parameter
	end
	
end

function Reward_Technology:CustomFunction()
	
	if self.PlayerID 
	and Logic.GetStoreHouse(self.PlayerID) ~= 0 
	and Technologies[self.Technology] 
	then
		if self.LockType  then
			LockFeaturesForPlayer(self.PlayerID, Technologies[self.Technology])
		else
			UnLockFeaturesForPlayer(self.PlayerID, Technologies[self.Technology])
		end
	else 
		return false
	end

end

function Reward_Technology:DEBUG(_Quest)
	
	if Logic.GetStoreHouse(self.PlayerID) == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Player " .. self.PlayerID .. " is dead. :-(")
		return true
	elseif not Technologies[self.Technology] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Technology is wrong")
		return true
	end
	
end

function Reward_Technology:GetCustomData(_index)

	local Data = {}
	if (_index == 1) then
		Data[1] = "Lock"
		Data[2] = "UnLock"
	elseif (_index == 2) then
		for k, v in pairs( Technologies ) do
			table.insert( Data, k )
		end
	end
	return Data

end

AddQuestBehavior(Reward_Technology)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_TravelingSalesman  (Replacement for Reward_MerchantShipStart and Reward_MerchantShipOffers by zweispeer)
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

Reward_TravelingSalesman = {
	Name = "Reward_TravelingSalesman",
	Description = {
		en = "Reward: Deletes all existing offers for a Month and sets new ones, if given",
		de = "Lohn: Loescht alle Angebote eines Monats und setzt neue, wenn angegeben",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "PlayerID", de = "PlayerID" },
		{ ParameterType.Custom, en = "Month", de= "Monat" },
		{ ParameterType.Custom, en = "Amount 1", de = "Menge 1" },
		{ ParameterType.Custom, en = "Offer 1", de = "Angebot 1" },
		{ ParameterType.Custom, en = "Amount 2", de = "Menge 2" },
		{ ParameterType.Custom, en = "Offer 2", de = "Angebot 2" },
		{ ParameterType.Custom, en = "Amount 3", de = "Menge 3" },
		{ ParameterType.Custom, en = "Offer 3", de = "Angebot 3" },
		{ ParameterType.Custom, en = "Amount 4", de = "Menge 4" },
		{ ParameterType.Custom, en = "Offer 4", de = "Angebot 4" },
		{ ParameterType.Number, en = "Duration at Harbor (in Month)", de = "Liegezeit im Hafen (In Monaten)" },
		{ ParameterType.Custom, en = "Check Diplomacy", de = "Pruefe Diplomatie" },
		{ ParameterType.Custom, en = "Use Paths?", de = "Pfade benutzen?" },
		{ ParameterType.ScriptName, en = "Path to Harbor", de = "Pfad zum Hafen" },
		{ ParameterType.ScriptName, en = "Path from Harbor", de = "Pfad vom Hafen" }, 
	},
}

function Reward_TravelingSalesman:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_TravelingSalesman:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.PlayerID = _Parameter*1
	elseif (_Index == 1) then
		self.Month = _Parameter*1
	elseif (_Index == 2) then
		self.AmountOffer1 = _Parameter*1
	elseif (_Index == 3) then
		self.Offer1 = _Parameter
	elseif (_Index == 4) then
		self.AmountOffer2 = _Parameter*1
	elseif (_Index == 5) then
		self.Offer2 = _Parameter
	elseif (_Index == 6) then
		self.AmountOffer3 = _Parameter*1
	elseif (_Index == 7) then
		self.Offer3 = _Parameter
	elseif (_Index == 8) then
		self.AmountOffer4 = _Parameter*1
	elseif (_Index == 9) then
		self.Offer4 = _Parameter
	elseif (_Index == 10) then
		self.ActiveTime = _Parameter*1
	elseif (_Index == 11) then
		self.bCheckDiplomacy = _Parameter == "Yes"
	elseif (_Index == 12) then
		self.PathUse = _Parameter
	elseif (_Index == 13) then
		self.Path = (tostring(_Parameter) and _Parameter ~= "" and (not Logic.IsEntityDestroyed(_Parameter)) and _Parameter:gsub("%d", "") ) or nil
	elseif (_Index == 14) then
		self.BackPath = (tostring(_Parameter) and _Parameter ~= "" and (not Logic.IsEntityDestroyed(_Parameter)) and _Parameter:gsub("%d", "") )or nil
	end

end

function Reward_TravelingSalesman:CustomFunction(_Quest)

	local GoodsTable ={}
	for i = 1, 4 do
		local cOffer, cAmount = self["Offer"..i], self["AmountOffer"..i]
		local Offer = (cOffer ~= "NoOffer" and type(cOffer) == "string") and (Goods[cOffer] or Entities[cOffer])
		if Offer and type(cAmount) == "number" and cAmount > 0 then
			table.insert (GoodsTable, {Offer, cAmount })
		end
	end
	if type(TravelingSalesman_Loop) ~= "function" then-- BB - Traveling Salesman  --to be removed in later versions
		if (self.PlayerID > 1) and (self.PlayerID < 9) and g_TravelingSalesman == nil then
			ActivateTravelingSalesman(self.PlayerID, {{2,{{Goods.G_Wood,1}}}})
			g_TravelingSalesman.MonthOfferTable[2] = nil
			WikiQSB.Reward_TravelingSalesman.FirstQuest = _Quest
		end
		if g_TravelingSalesman ~= nil and (self.Month < 13) and (self.Month > 0) then	
			g_TravelingSalesman.MonthOfferTable[self.Month] = (#GoodsTable > 0 and GoodsTable) or nil
		end
	else											-- Old McDonalds Traveling Salesman
		local playerID = WikiQSB.Reward_TravelingSalesman.PlayerID
		if not playerID then 
			playerID = self.PlayerID
			local path, backPath
			if self.PathUse == "Only One" or self.PathUse == "Use Both" then
				path = self.Path and GetEntitiesNamedWith(self.Path)
				if self.PathUse == "Use Both" then
					backPath = self.BackPath and GetEntitiesNamedWith(self.BackPath)
				end
			end
			TravelingSalesman:new(playerID, 
									{},
									(self.ActiveTime ~= 0 and self.ActiveTime or 1), 
									path, 
									self.bCheckDiplomacy,
									nil,
									backPath) 
			WikiQSB.Reward_TravelingSalesman.PlayerID = playerID
			WikiQSB.Reward_TravelingSalesman.FirstQuest = _Quest
		end
		if (self.Month < 13) and (self.Month > 0) then	
			TravelingSalesman.List[playerID]:RemoveOffers(self.Month)
			TravelingSalesman.List[playerID]:AddOffers(self.Month, GoodsTable)
		end
	end

end

function Reward_TravelingSalesman:DEBUG(_Quest)

	local e = function(_s) yam(string.format([[%s: Error in %s: %s]], _Quest.Identifier, self.Name, _s)) return true end
	for i = 1, 4 do
		if type(self["Offer"..i]) == "string" and self["Offer"..i] ~= "NoOffer" then
			if not Goods[self["Offer"..i]] and not Entities[self["Offer"..i]] then
				return e("Offer "..i.." is wrong.")
			elseif type(self["AmountOffer"..i]) ~= "number" or self["AmountOffer"..i] < 1 or self["AmountOffer"..i] > 9 then
				return e("Amount "..i.." is wrong.")
			end
		end
	end
	return (Logic.GetStoreHouse(self.PlayerID ) == 0 and e("Player " .. self.PlayerID .. " is dead. :-("))
		or ((self.Month < 1 or self.Month > 12) and e("Month "..self.Month.." is wrong."))
		or ((self.PathUse == "Only One" or self.PathUse == "Use Both") and #GetEntitiesNamedWith(self.Path) == 0 and e("Path does not exist"))
		or (self.PathUse == "Use Both" and #GetEntitiesNamedWith(self.BackPath) == 0 and e("BackPath does not exist"))
		or (tonumber(self.ActiveTime) and self.ActiveTime < 0 and e("Duration negative")) 
		or (WikiQSB.Reward_TravelingSalesman.FirstQuest == _Quest and e("Careful when placing more than one offer in the first Quest"))
		 
end

function Reward_TravelingSalesman:GetCustomData(_Index)
	local Amount = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }
	local Month  = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12" }
	local Boolean = { "No", "Yes" }
	local PathUse = { "No", "Only One", "Both Paths" }
	local Offers = {"NoOffer",
					"G_Beer",
					"G_Bow",
					"G_Bread",
					"G_Broom",
					"G_Candle",
					"G_Carcass",
					"G_Cheese",
					"G_Clothes",
					"G_Cow",
					"G_Grain",
					"G_Herb",
					"G_Honeycomb",
					"G_Iron",
					"G_Leather",
					"G_Medicine",
					"G_Milk",
					"G_RawFish",
					"G_Sausage",
					"G_Sheep",
					"G_SmokedFish",
					"G_Soap",
					"G_Stone",
					"G_Sword",
					"G_Wood",
					"G_Wool",
					"G_Salt",
					"G_Dye",
					"U_MilitaryBandit_Melee_ME",
					"U_MilitaryBandit_Melee_SE",
					"U_MilitaryBandit_Melee_NA",
					"U_MilitaryBandit_Melee_NE",
					"U_MilitaryBandit_Ranged_ME",
					"U_MilitaryBandit_Ranged_NA",
					"U_MilitaryBandit_Ranged_NE",
					"U_MilitaryBandit_Ranged_SE",
					"U_Entertainer_NA_FireEater",
					"U_Entertainer_NA_StiltWalker",
					"U_Entertainer_NE_StrongestMan_Barrel",
					"U_Entertainer_NE_StrongestMan_Stone",
					}
	if g_GameExtraNo and g_GameExtraNo >= 1 then
		table.insert(Offers, "G_Gems")
		table.insert(Offers, "G_Olibanum")
		table.insert(Offers, "G_MusicalInstrument")
		table.insert(Offers, "G_MilitaryBandit_Ranged_AS")
		table.insert(Offers, "G_MilitaryBandit_Melee_AS")
	end
	if (_Index == 1) then 
		return Month 
	elseif (_Index >= 2) and (_Index <= 9) then 
		return (_Index % 2 == 0 and Amount) or Offers
	elseif (_Index == 11) then
		return Boolean
	elseif (_Index == 12) then
		return PathUse
	end
	
end

AddQuestBehavior(Reward_TravelingSalesman)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_Units
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_Units = {
	Name = "Reward_Units",
	Description = {
		en = "Reward: Units",
		de = "Lohn: Einheiten",
	},
	Parameter = {
		{ ParameterType.Entity, en = "Type name", de = "Typbezeichnung" },
		{ ParameterType.Number, en = "Amount", de = "Anzahl" },
	},
}

function Reward_Units:AddParameter(_Index, _Parameter)

	if (_Index == 0) then
		self.EntityName = _Parameter
	elseif (_Index == 1) then		
		self.Amount = _Parameter * 1
	end
	
end

function Reward_Units:GetRewardTable()

	assert( self.Amount > 0, "Error in ".. self.Name .. ": GetRewardTable: Amount is invalid")
	assert( Entities[self.EntityName], "Error in ".. self.Name .. ": GetRewardTable: Type name is invalid" )
	return { Reward.Units, Entities[self.EntityName], self.Amount }

end

AddQuestBehavior(Reward_Units)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_UpgradeBuilding					Quest created by: Old McDonald
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

Reward_UpgradeBuilding = {
	Name = "Reward_UpgradeBuilding",
	Description = {
		en = "Upgrades a building",
		de = "Baut ein Gebaeude aus"
	},
	Parameter =	{
		{ ParameterType.ScriptName, en = "Building", de = "Gebaeude" }
	}
};
 
function Reward_UpgradeBuilding:GetRewardTable()

	return {Reward.Custom, self, self.CustomFunction};

end
 
function Reward_UpgradeBuilding:AddParameter(_Index, _Parameter)

	if _Index == 0 then
		self.Building = _Parameter;
	end

end
 
function Reward_UpgradeBuilding:CustomFunction(_Quest)

	local building = Logic.GetEntityIDByName(self.Building);
	if building ~= 0 
	and Logic.IsBuilding(building) == 1 
	and Logic.IsBuildingUpgradable(building, true) 
	and Logic.IsBuildingUpgradable(building, false) 
	then
		Logic.UpgradeBuilding(building);
	end

end

function Reward_UpgradeBuilding:DEBUG(_Quest)

	local building = Logic.GetEntityIDByName(self.Building);
	if not (building ~= 0 
			and Logic.IsBuilding(building) == 1 
			and Logic.IsBuildingUpgradable(building, true) 
			and Logic.IsBuildingUpgradable(building, false) )
	then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Building is wrong")
		return true
	end
	
end

AddQuestBehavior(Reward_UpgradeBuilding)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_Victory
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reward_Victory = {
	Name = "Reward_Victory",
	Description = {
		en = "Reward: Victory of map",
		de = "Lohn: Gewinn der Karte"
	},
}

function Reward_Victory:GetRewardTable()

	return { Reward.Victory }

end

function Reward_Victory:AddParameter(_Index, _Parameter)

end

AddQuestBehavior(Reward_Victory)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reward_VikingsInitAndAttack
-- User generated zweispeer
------------------------------------------------------------------------------------------------------------------------------

Reward_VikingsInitAndAttack = {
	Name = "Reward_VikingsInitAndAttack",
	Description = {		en = "Reward: Initiates a Vikings AI and an attack in the given month. When called a second time, PlayerID is ignored",
						de = "Lohn: Initiiert die Vikings AI und startet einen Angriff im abgegebenen Monat. Beim zweiten Aufruf wird PlayerID ignoriert",	},
	Parameter = {
				{ ParameterType.PlayerID, en = "Player ID", de = "Spieler ID" },
				{ ParameterType.ScriptName, en = "Ship spawning point", de = "Schiffsstartpunkt" },
				{ ParameterType.ScriptName, en = "Ship ending point", de = "Schiffsendpunkt" },
				{ ParameterType.ScriptName, en = "Vikings spawning point", de = "Vikingsstartpunkt" },
				{ ParameterType.ScriptName, en = "Attack point", de = "Angriffspunkt" },
				{ ParameterType.Number, en = "Amount", de = "Anzahl" },
				{ ParameterType.Custom, en = "Month", de = "Monat" },
				},
}

function Reward_VikingsInitAndAttack:GetRewardTable()

	return { Reward.Custom,{self, self.CustomFunction} }

end

function Reward_VikingsInitAndAttack:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.PlayerID = _Parameter
	elseif (_Index == 1) then
		self.ShipSpawnPoint = _Parameter
	elseif (_Index == 2) then
		self.ShipEndPoint = _Parameter
	elseif (_Index == 3) then
		self.VikingStartPoint = _Parameter
	elseif (_Index == 4) then
		self.AttackPoint = _Parameter
	elseif (_Index == 5) then
		self.Amount = _Parameter*1
	elseif (_Index == 6) then
		self.Month = _Parameter*1
	end

end

function Reward_VikingsInitAndAttack:CustomFunction()

	if not Viking then
		Viking = AIPlayer:new(self.PlayerID, AIPlayerProfile_Viking)
	end
	Viking.m_ShipSpawnID		= Logic.GetEntityIDByName(self.ShipSpawnPoint)
	Viking.m_ShipEndID			= Logic.GetEntityIDByName(self.ShipEndPoint)
	Viking.m_VikingSpawnID		= Logic.GetEntityIDByName(self.VikingStartPoint)
	Viking.m_NumberOfVikings	= self.Amount
	Viking.m_StartAttackMonth	= self.Month
	Viking.m_TargetID			= Logic.GetEntityIDByName(self.AttackPoint)

end

function Reward_VikingsInitAndAttack:DEBUG(_Quest)

	local shipStart = Logic.GetEntityIDByName(self.ShipSpawnPoint) 
	local shipEnd = Logic.GetEntityIDByName(self.ShipEndPoint) 
	local vikingStart = Logic.GetEntityIDByName(self.VikingStartPoint) 
	local attack = Logic.GetEntityIDByName(self.AttackPoint) 
	if Logic.GetStoreHouse(self.PlayerID) ~= 0 then
		yam(_Quest.Identifier .. ": Warning for " .. self.Name ..": Player has a Storehouse. Unwanted behavior possible.")
		return true
	elseif type(self.Amount) ~= "number" or self.Amount < 1 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": Amount is wrong")
		return true
	elseif type(self.Month) ~= "number" or self.Month < 1 or self. Month > 12 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": Month is wrong")
		return true
	elseif not shipStart or Logic.EntityGetPlayer(shipStart) ~= self.PlayerID then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": ShipSpawnPoint is wrong")
		return true
	elseif not shipEnd or Logic.EntityGetPlayer(shipEnd) ~= self.PlayerID then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": ShipEndPoint is wrong")
		return true
	elseif not vikingStart or Logic.EntityGetPlayer(vikingStart) ~= self.PlayerID then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": VikingStartPoint is wrong")
		return true
	elseif not attack or Logic.EntityGetPlayer(attack) ~= self.PlayerID then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": AttackPoint is wrong")
		return true
	end
	
end

function Reward_VikingsInitAndAttack:GetCustomData(_Index)

	assert(_Index == 6, "Error in ".. self.Name .. ": GetCustomData: Index is invalid") 
	return {1,2,3,4,5,6,7,8,9,10,11,12}

end

AddQuestBehavior(Reward_VikingsInitAndAttack)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reprisal CustomVariables
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

Reprisal_CustomVariables = {
	Name = "Reprisal_CustomVariables",
	Description = {
		en = "Reprisal: + and - modifies one of five possible variables, = sets it",
		de = "Bestrafung: + und - aendern eine von fuenf moeglichen Variablen, = setzt sie",
	},
	Parameter = {
		{ ParameterType.Custom,   en = "Variable", de = "Variable" },
		{ ParameterType.Custom,   en = "Operator", de = "Operand" },
		{ ParameterType.Number,   en = "Value", de = "Wert" },
	},
}

function Reprisal_CustomVariables:GetReprisalTable()

	return { Reprisal.Custom, {self, self.CustomFunction} }

end

function Reprisal_CustomVariables:AddParameter(_Index, _Parameter)

	if (_Index ==0) then
		self.Variable = _Parameter
	elseif (_Index == 1) then
		self.Operator = _Parameter
	elseif (_Index == 2) then
		self.Value = _Parameter*1
	end
	
end

function Reprisal_CustomVariables:CustomFunction(_Quest)
	
	local var = self.Variable
	local op = self.Operator
	local val = self.Value
	local cont = WikiQSB.CustomVariable
	local oldval = assert(cont[var], _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Variable not found")
	if op == "+" then
		cont[var] = oldval + val
	elseif op == "-" then
		cont[var] = oldval - val
	elseif op == "*" then
		cont[var] = oldval * val
	elseif op == "/" then
		assert( val ~= 0, _Quest.Identifier .. ": Error in " .. self.Name .. ": CustomFunction: Division by zero")
		cont[var] = oldval / val
	elseif op == "=" then
		cont[var] = val
	else 
		assert(false, _Quest.Identifier .. ": Error in ".. self.Name .. ": CustomFunction: Operator is invalid")
	end	
	_Quest[self.Name] = _Quest[self.Name] or {}
	_Quest[self.Name][var] = true
	
end

function Reprisal_CustomVariables:Reset(_Quest)

	_Quest[self.Name][self.Variable] = nil

end


function Reprisal_CustomVariables:DEBUG(_Quest)

	if not WikiQSB.CustomVariable[self.Variable] then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": Wrong Variable name ")
		return true
	elseif _Quest[self.Name] and _Quest[self.Name][self.Variable] then
		yam(_Quest.Identifier .. ": Warning " .. self.Name ..": Don't use more than one Reward for the same variable in the same quest.")
		return true
	elseif type(self.Value) ~= "number" then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": Wrong type for Value")
		return true
	elseif not ( 	self.Operator == "+" 
				or 	self.Operator == "-" 
				or 	self.Operator == "*" 
				or 	self.Operator == "/" 
				or 	self.Operator == "=" ) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": Wrong Operator")
		return true
	elseif (	self.Operator == "/") and self.Value == 0 then
		yam(_Quest.Identifier .. ": Error in " .. self.Name ..": / 0 : Illegal")
		return true
	elseif (	self.Operator == "+" 
			or 	self.Operator == "-"
			or 	self.Operator == "*") and self.Value == 0 then
		yam(_Quest.Identifier .. ": Warning in " .. self.Name ..": +/-/* 0 : Useless?")
		return true
	end
	
end

function Reprisal_CustomVariables:GetCustomData(_index)

	if (_index == 0) then
		return WikiQSB.CustomVariable.List
	elseif (_index == 1) then
		return { "+", "-", "*", "/", "=" }
	end
	
end

AddQuestBehavior(Reprisal_CustomVariables)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reprisal_Defeat
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reprisal_Defeat = {
	Name = "Reprisal_Defeat",
	Description = {
		en = "Reprisal: Defeat",
		de = "Vergeltung: Niederlage",
	},
}

function Reprisal_Defeat:GetReprisalTable()

	return { Reprisal.Defeat }

end

function Reprisal_Defeat:AddParameter(_Index, _Parameter)

end

AddQuestBehavior(Reprisal_Defeat)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reprisal_Diplomacy
-- User Generated 
------------------------------------------------------------------------------------------------------------------------------

Reprisal_Diplomacy = {
	Name = "Reprisal_Diplomacy",
	Description = {
		en = "Reprisal: Sets Diplomacy between two Players  to a stated value",
		de = "Bestrafung: Stellt die Diplomatie zwischen zwei Spielern auf den angegebenen Wert",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "PlayerID 1", de = "PlayerID 1" },
		{ ParameterType.PlayerID, en = "PlayerID 2", de = "PlayerID 2" },
		{ ParameterType.DiplomacyState, en = "Diplomacy State", de = "Diplomatiestatus"},
	},
}

function Reprisal_Diplomacy:GetReprisalTable()

	return { Reprisal.Custom,{self, self.CustomFunction} }

end

function Reprisal_Diplomacy:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.PID1 = _Parameter*1   
	elseif (_Index == 1) then
		self.PID2 = _Parameter*1
	elseif (_Index == 2) then
		self.Diplomacy = _Parameter
	end

end

function Reprisal_Diplomacy:CustomFunction()

	if (self.PID1 == self.PID2) then
		return 
	end
	if self.Diplomacy then
		SetDiplomacyState( self.PID1, self.PID2, DiplomacyStates[self.Diplomacy])
	end
	
end

function Reprisal_Diplomacy:DEBUG(_Quest)
	
	if Logic.GetStoreHouse( self.PID1 ) == 0 then
		yam(_Quest.Identifier .. ":  Error in " .. self.Name ..": Player " .. self.PID1 .. "is dead :-(")
		return true
	elseif Logic.GetStoreHouse( self.PID2 ) == 0 then
		yam(_Quest.Identifier .. ":  Error in " .. self.Name ..": Player " .. self.PID2 .. "is dead :-(")
		return true
	elseif not DiplomacyStates[self.Diplomacy] then
		yam(_Quest.Identifier .. ":  Error in " .. self.Name ..": Wrong Diplomacy")
		return true
	elseif self.PID1 == self.PID2 then
		yam(_Quest.Identifier .. ":  Error in " .. self.Name ..": PlayerIDs are identical")
		return true
	end
	
end

AddQuestBehavior(Reprisal_Diplomacy)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reprisal_FakeDefeat
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reprisal_FakeDefeat = {
	Name = "Reprisal_FakeDefeat",
	Description = {
		en = "Reprisal: Displays a defeat icon for a quest",
		de = "Vergeltung: Zeigt ein Niederlage Icon fuer eine Quest an",
	},
}

function Reprisal_FakeDefeat:GetReprisalTable()

	return { Reprisal.FakeDefeat }

end

function Reprisal_FakeDefeat:AddParameter(_Index, _Parameter)

end

AddQuestBehavior(Reprisal_FakeDefeat)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reprisal_InteractiveObjectDeactivate
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reprisal_InteractiveObjectDeactivate = {
	Name = "Reprisal_InteractiveObjectDeactivate",
	Description = {
		en = "Reprisal: Deactivates and interactive",
		de = "Vergeltung: Deaktiviert ein interaktives Objekt",
	},
	Parameter = {
		{ ParameterType.ScriptName, en = "Interactive object", de = "Interaktives Objekt" },
	},
}

function Reprisal_InteractiveObjectDeactivate:GetReprisalTable()

	return { Reprisal.Custom,{self, self.CustomFunction} }

end

function Reprisal_InteractiveObjectDeactivate:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.Scriptname = _Parameter	
	end

end

function Reprisal_InteractiveObjectDeactivate:CustomFunction(_Quest)

	if Logic.IsEntityDestroyed( self.Scriptname ) 
	or not Logic.IsInteractiveObject(Logic.GetEntityIDByName(self.Scriptname))
	then
		assert( false , _Quest.Identifier .. ": Error in ".. self.Name .. ": CustomFunction: Scriptname is no IO")
	end
	
	local ID = Logic.GetEntityIDByName( self.Scriptname )

	Logic.InteractiveObjectSetAvailability( ID, false )
	for i = 1, 8 do
		Logic.InteractiveObjectSetPlayerState(ID, i, 2)
	end
	
end

function Reprisal_InteractiveObjectDeactivate:DEBUG(_Quest)
	
	if Logic.IsEntityDestroyed( self.Scriptname ) 
	or not Logic.IsInteractiveObject(Logic.GetEntityIDByName(self.Scriptname))
	then
		yam(_Quest.Identifier .. ":  Error in " .. self.Name ..": Entity " .. self.Scriptname .. " not found or no IO.")
		return true
	end
	
end

AddQuestBehavior(Reprisal_InteractiveObjectDeactivate)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reprisal_MapScriptFunction					Quest created by: Old McDonald
-- User Generated
------------------------------------------------------------------------------------------------------------------------------

Reprisal_MapScriptFunction = {
	Name = "Reprisal_MapScriptFunction",
	Description = {
		en = "Reprisal: Calls a function from the mapscript. The quest name is given to the function as parameter.",
		de = "Vergeltung: Ruft eine Funktion aus dem Kartenscript auf. Der Funktion wird der Questname als Parameter uebergeben",
	},
	Parameter = {
		{ ParameterType.Default, en = "Function name", de = "Funktionsname" },
	},
}

function Reprisal_MapScriptFunction:GetReprisalTable()

	return { Reprisal.Custom, {self, self.CustomFunction} }

end

function Reprisal_MapScriptFunction:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.FuncName = _Parameter	
	end

end

function Reprisal_MapScriptFunction:CustomFunction(_Quest)
	
	if not self.FuncName then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": No function name ")
	elseif type(_G[self.FuncName]) ~= "function" then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Function does not exist: " .. self.FuncName)
	else
		_G[self.FuncName](_Quest.Identifier)
	end
	
end

AddQuestBehavior(Reprisal_MapScriptFunction)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reprisal_QuestFailure
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reprisal_QuestFailure = {
	Name = "Reprisal_QuestFailure",
	Description = {
		en = "Reprisal: Lets another active quest fail",
		de = "Vergeltung: Laesst eine andere aktive Quest fehlschlagen",
	},
	Parameter = {
		{ ParameterType.QuestName, en = "Quest name", de = "Questname" },
	},
}

function Reprisal_QuestFailure:GetReprisalTable()

	return { Reprisal.Custom,{self, self.CustomFunction} }

end

function Reprisal_QuestFailure:AddParameter(_Index, _Parameter)

	if (_Index == 0) then	
		self.QuestName = _Parameter	
	end

end

function Reprisal_QuestFailure:CustomFunction()

	if IsValidQuest(self.QuestName) then
	
		local QuestID = GetQuestByName(self.QuestName)
		local Quest = Quests[QuestID]
		if Quest.State == QuestState.Active then
			Quest:Fail()
		end
	end
   
end

function Reprisal_QuestFailure:DEBUG(_Quest)

	if not IsValidQuest(self.QuestName) then
		yam(_Quest.Identifier .. ": Error in " .. self.Name .. ": Quest: "..  self.QuestName .. " does not exist")
		return true
	elseif self.QuestName == _Quest.Identifier then
		yam(_Quest.Identifier .. ": Warning in " .. self.Name .. ": I shall fail myself? Are you sure?")
		return true
	end	
	
end

AddQuestBehavior(Reprisal_QuestFailure)

------------------------------------------------------------------------------------------------------------------------------
--
-- Reprisal_SlightlyDiplomacyDecrease
-- BB Original
------------------------------------------------------------------------------------------------------------------------------

Reprisal_SlightlyDiplomacyDecrease = {
	Name = "Reprisal_SlightlyDiplomacyDecrease",
	Description = {
		en = "Reprisal: Diplomacy decreases slightly to another player",
		de = "Vergeltung: Verschlechterung des Diplomatiestatus zu einem anderen Spieler",
	},
	Parameter = {
		{ ParameterType.PlayerID, en = "Player", de = "Spieler" },
	},
}

function Reprisal_SlightlyDiplomacyDecrease:GetReprisalTable()

	return {Reprisal.Diplomacy, self.PlayerID , -1 }

end

function Reprisal_SlightlyDiplomacyDecrease:AddParameter(_Index, _Parameter)

	if (_Index == 0) then   
		self.PlayerID = _Parameter * 1	
	end

end

AddQuestBehavior(Reprisal_SlightlyDiplomacyDecrease)
------------------------------------------------------------------------------------------------------------------------------
--####################################################################
--## General Code corrections
--####################################################################
-- Hack for enabling Questmarkers 
function ShowQuestMarker(_Entity)
	local entityID = GetEntityId(_Entity)
    local x,y = Logic.GetEntityPosition(entityID)
    local Marker = EGL_Effects.E_Questmarker_low
    if Logic.IsBuilding(entityID) == 1 then
        Marker = EGL_Effects.E_Questmarker
    end
    Questmarkers[_Entity] = Logic.CreateEffect(Marker, x,y,0)
end

function QuestTemplate:ShowQuestMarkers()
	local visible = self.Visible
	for i=1, self.Objectives[0] do
		if self.Objectives[i].Type == Objective.Distance then
			local b = self.Objectives[i].ShowQuestmarker
			if b == nil then
				b = visible
			end
			if b then
				ShowQuestMarker(self.Objectives[i].Data[2])
			end
		end
	end
end

-- Adds AmmoCart to the selection  of militiary Units (for better finding)
-- Logic.ExecuteInLuaLocalState([[
-- if g_PatchIdentifierExtra1 then
   -- LeaderSortOrder[21] = Entities.U_AmmunitionCart
   -- LeaderSortOrder[22] = Entities.U_Thief		
-- else
   -- LeaderSortOrder[19] = Entities.U_AmmunitionCart
   -- LeaderSortOrder[20] = Entities.U_Thief
-- end]])

-- Enhancements for Interactive Objects
-- Check Ex1 for changes
do
	Logic.ExecuteInLuaLocalState([[
		function GUI_Interaction.InteractiveObjectMouseOver()
			local PlayerID = GUI.GetPlayerID()
			local ButtonNumber = tonumber(XGUIEng.GetWidgetNameByID(XGUIEng.GetCurrentWidgetID()))
			local ObjectID = g_Interaction.ActiveObjectsOnScreen[ButtonNumber]
			local EntityType = Logic.GetEntityType(ObjectID)

			local CurrentWidgetID = XGUIEng.GetCurrentWidgetID()
			local Costs = {Logic.InteractiveObjectGetEffectiveCosts(ObjectID, PlayerID)}
			local IsAvailable = Logic.InteractiveObjectGetAvailability(ObjectID)

			local TooltipTextKey
			local TooltipDisabledTextKey

			if IsAvailable == true then
				TooltipTextKey = "InteractiveObjectAvailable"
			else
				TooltipTextKey = "InteractiveObjectNotAvailable"
			end

			-- interaction tooltip - disabled
			if Logic.InteractiveObjectHasPlayerEnoughSpaceForRewards(ObjectID, PlayerID) == false then
				TooltipDisabledTextKey = "InteractiveObjectAvailableReward"
			end
			
			-- FIX: more complicated checks...
			-- maximum number of resources: gold, wood, stone and other resource, so 4 resources...
			local CheckSettlement
			if Costs then 
				for i = 1, #Costs, 2 do
					if Logic.GetGoodCategoryForGoodType(Costs[i]) ~= GoodCategories.GC_Resource then
						CheckSettlement = true
						break
					end
				end
			end
			
			GUI_Tooltip.TooltipBuy(Costs, TooltipTextKey, TooltipDisabledTextKey, nil, CheckSettlement)
		end
		
		function GUI_Interaction.InteractiveObjectClicked()
			local ButtonNumber = tonumber(XGUIEng.GetWidgetNameByID(XGUIEng.GetCurrentWidgetID()))
			local ObjectID = g_Interaction.ActiveObjectsOnScreen[ButtonNumber]
			
			if ObjectID == nil or not Logic.InteractiveObjectGetAvailability(ObjectID) then
				return
			end
			
			local PlayerID = GUI.GetPlayerID()

			local Costs = {Logic.InteractiveObjectGetEffectiveCosts(ObjectID, PlayerID)}

			if Costs ~= nil
			and Costs[1] ~= nil then
				-- FIX: more complicated checks...
				-- maximum number of resources: gold, wood, stone and other resource, so 4 resources...
				local CheckSettlement
				for i = 1, #Costs, 2 do
					if Logic.GetGoodCategoryForGoodType(Costs[i]) ~= GoodCategories.GC_Resource then
						CheckSettlement = true
						break
					end
				end

				local CanBuyBoolean, CanNotBuyString = AreCostsAffordable(Costs,CheckSettlement)

				if CanBuyBoolean == true then
					-- Default button click?
					if  not GUI_Interaction.InteractionClickOverride 
						or 
						not GUI_Interaction.InteractionClickOverride(ObjectID)
					then
						Sound.FXPlay2DSound( "ui\\menu_click")
					end
					
					-- Default speech?
					if  not GUI_Interaction.InteractionSpeechFeedbackOverride 
						or 
						not GUI_Interaction.InteractionSpeechFeedbackOverride(ObjectID)
					then				
						GUI_FeedbackSpeech.Add("SpeechOnly_CartsSent", g_FeedbackSpeech.Categories.CartsUnderway, nil, nil)
					end
					
					if not Mission_Callback_OverrideObjectInteraction or not Mission_Callback_OverrideObjectInteraction( ObjectID, PlayerID, Costs ) then
						GUI.ExecuteObjectInteraction(ObjectID, PlayerID)
					end
					
				else
					Message(CanNotBuyString)
				end
			else
				GUI.ExecuteObjectInteraction(ObjectID, PlayerID)
			end
		end
		
		function AreCostsAffordable(_Costs, _GoodsInSettlementBoolean)

			local PlayerID = GUI.GetPlayerID()

			local CanBuyBoolean = true
			local CanNotBuyString = ""
			local CanNotBuyStringSections = {}
			CanNotBuyStringSections.Number = 0

			local CastleID = Logic.GetHeadquarters(PlayerID)
			local StorehouseID = Logic.GetStoreHouse(PlayerID)
			
			local PlayerGoldAmount = Logic.GetAmountOnOutStockByGoodType(CastleID, Goods.G_Gold)
			local PlayerStoneAmount = Logic.GetAmountOnOutStockByGoodType(StorehouseID, Goods.G_Stone)
			local PlayerWoodAmount = Logic.GetAmountOnOutStockByGoodType(StorehouseID, Goods.G_Wood)
			
			local PlayerWeaponOrPartAmount = 0
			local WeaponOrPartType
			local BarracksID = GUI.GetSelectedEntity()

			local GoldCost = 0
			local StoneCost = 0
			local WoodCost = 0
			local WeaponOrPartCost = 0

			for i = 1, table.getn(_Costs), 2 do
				if _Costs[i] == Goods.G_Gold then
					GoldCost = _Costs[i + 1]
				elseif _Costs[i] == Goods.G_Stone then
					StoneCost = _Costs[i + 1]
				elseif _Costs[i] == Goods.G_Wood then
					WoodCost = _Costs[i + 1]
				else
					if WeaponOrPartType == nil then
						WeaponOrPartType = _Costs[i]
						WeaponOrPartCost = _Costs[i + 1]
					else
						GUI.AddNote("Debug: Too many good types in cost table")
					end
				end
			end
			
			-- FIX in conditions below; more IFs...
			if WeaponOrPartType ~= nil then
				if _GoodsInSettlementBoolean ~= true then
					local CastleGoodIndex = Logic.GetIndexOnOutStockByGoodType(CastleID, WeaponOrPartType)
					local StorehouseGoodIndex = Logic.GetIndexOnOutStockByGoodType(StorehouseID, WeaponOrPartType)
					local BarracksGoodIndex = -1

					if BarracksID ~= nil then
						BarracksGoodIndex = Logic.GetIndexOnOutStockByGoodType(BarracksID, WeaponOrPartType)
						
						if BarracksGoodIndex == nil
						and Logic.IsEntityInCategory(BarracksID, EntityCategories.Leader) == 1 then
							BarracksID = Logic.GetRefillerID(BarracksID)
							BarracksGoodIndex = Logic.GetIndexOnOutStockByGoodType(BarracksID, WeaponOrPartType)
						end
					end

					if CastleGoodIndex == -1
					and StorehouseGoodIndex == -1
					and BarracksGoodIndex == -1 then
						GUI.AddNote("Debug: Good type " .. Logic.GetGoodTypeName(WeaponOrPartType) .. " neither in castle, storehouse or selected building")
						return
					end

					local BuildingID

					if CastleGoodIndex ~= -1 then
						BuildingID = CastleID
					elseif StorehouseGoodIndex ~= -1 then
						BuildingID = StorehouseID
					elseif BarracksGoodIndex ~= -1 then
						BuildingID = BarracksID
					end

					PlayerWeaponOrPartAmount = Logic.GetAmountOnOutStockByGoodType(BuildingID, WeaponOrPartType)
				else
					PlayerWeaponOrPartAmount = GetPlayerGoodsInSettlement(WeaponOrPartType, PlayerID, true)--we don't check in market place
				end
			end

			if PlayerGoldAmount < GoldCost then
				CanBuyBoolean = false
				local GoodName = Logic.GetGoodTypeName(Goods.G_Gold)
				CanNotBuyStringSections.Number = CanNotBuyStringSections.Number + 1
				CanNotBuyStringSections[CanNotBuyStringSections.Number] = GoodName
			end

			if PlayerStoneAmount < StoneCost then
				CanBuyBoolean = false
				local GoodName = Logic.GetGoodTypeName(Goods.G_Stone)
				CanNotBuyStringSections.Number = CanNotBuyStringSections.Number + 1
				CanNotBuyStringSections[CanNotBuyStringSections.Number] = GoodName
			end

			if PlayerWoodAmount < WoodCost then
				CanBuyBoolean = false
				local GoodName = Logic.GetGoodTypeName(Goods.G_Wood)
				CanNotBuyStringSections.Number = CanNotBuyStringSections.Number + 1
				CanNotBuyStringSections[CanNotBuyStringSections.Number] = GoodName
			end

			if PlayerWeaponOrPartAmount < WeaponOrPartCost then
				CanBuyBoolean = false
				local GoodName = Logic.GetGoodTypeName(WeaponOrPartType)
				CanNotBuyStringSections.Number = CanNotBuyStringSections.Number + 1
				CanNotBuyStringSections[CanNotBuyStringSections.Number] = GoodName
			end

			if CanNotBuyStringSections.Number == 1 then
				CanNotBuyString = "TextLine_NotEnough_" .. CanNotBuyStringSections[1]
			elseif CanNotBuyStringSections.Number == 2 then
				CanNotBuyString = "TextLine_NotEnough_" .. CanNotBuyStringSections[1] .. "_" .. CanNotBuyStringSections[2]
			end

			local CanNotBuyStringTableText = XGUIEng.GetStringTableText("Feedback_TextLines/" .. CanNotBuyString)
			
			if CanBuyBoolean == false
			and CanNotBuyStringTableText == "" then
				
				local StorehouseGoodIndex = Logic.GetIndexOnOutStockByGoodType(StorehouseID, _Costs[1])
				
				if _Costs[1] == Goods.G_Gold then
					CanNotBuyStringTableText = XGUIEng.GetStringTableText("Feedback_TextLines/TextLine_NotEnough_G_Gold")
				elseif StorehouseGoodIndex ~= -1 then
					CanNotBuyStringTableText = XGUIEng.GetStringTableText("Feedback_TextLines/TextLine_NotEnough_Resources")
				else
					CanNotBuyStringTableText = XGUIEng.GetStringTableText("Feedback_TextLines/TextLine_NotEnough_Goods")
				end
				
				--CanNotBuyStringTableText = "TextKey missing for " .. CanNotBuyString
			end
			
			return CanBuyBoolean, CanNotBuyStringTableText
		end
		]])
end
--####################################################################
--## TravelingSalesman by Old McDonald, for use in Reward_TravelingSalesman
--####################################################################

TravelingSalesman = {
	Loop = "TravelingSalesman_Loop",
	List = {}
};

-- ATTENTION: Only 1 BB salesman is supported, but you can create salesmen for each player with this script (so 2 and more players are supported)
-- either use BB script or this script, but not both (both scripts will end with an error message when this is tried; this script doesn't need this restriction, but BB's script wouldn't work otherwise because this script uses the BB table to use a BB function)
-- it is recommended only to create 1 salesman

function TravelingSalesman:new(_player, _offerTable, _duration, _path, _checkDiplomacy, _noWave, _backPath)
	_path = _path or ShipPath[_player];
	if not _path then
		-- get path from XD_TradeShipSpawn to XD_TradeShipMoveTo
		-- this emulates the standard BB implementation
		_path = {};
		local spawn = {Logic.GetPlayerEntities(_player, Entities.XD_TradeShipSpawn, 1, 0)};
		if spawn[1] > 0 then
			table.insert(_path, spawn[2]);
		end
		local destination = {Logic.GetPlayerEntities(_player, Entities.XD_TradeShipMoveTo, 1, 0)};
		if destination[1] > 0 then
			table.insert(_path, destination[2]);
		end
	end
	
	if g_TravelingSalesman and g_TravelingSalesman.PlayerID then
		Logic.DEBUG_AddNote("DEBUG: You must either use a BB traveling salesman or this salesman implementation");
		return;
	elseif TravelingSalesman.List[_player] then
		Logic.DEBUG_AddNote("DEBUG: There is already a traveling salesman for player " .. _player);
		return;
	elseif #_path == 0 then
		Logic.DEBUG_AddNote("DEBUG: Got no ship path for player " .. _player);
		return;
	end
	
	-- don't allow BB traveling salesman now
	g_TravelingSalesman = {};
	
	-- create new salesman and initialize
	local travelingSalesman = {};
	Table_Copy(travelingSalesman, self);
	travelingSalesman.PlayerID = _player;
	travelingSalesman.Storehouse = Logic.GetStoreHouse(_player);
	travelingSalesman.Status = g_TravelingSalesmanStatus.Sailing;
	travelingSalesman.ActiveTime = (_duration or 1) * Logic.GetMonthDurationInSeconds();
	travelingSalesman.OfferTable = {};
	travelingSalesman.CreateWave = not _noWave; -- standard: Use ship wave
	travelingSalesman.CheckDiplomacy = _checkDiplomacy == true;
	travelingSalesman.Disabled = false;
	
	-- transfer offer table
	for i = 1, #_offerTable do
		local month = _offerTable[i][1];
		travelingSalesman.OfferTable[month] = _offerTable[i][2];
	end
	
	travelingSalesman.Path = _path;
	travelingSalesman.BackPath = _backPath;
	travelingSalesman.SpawnPoint = travelingSalesman.Path[1];
	travelingSalesman.DestinationPoint = travelingSalesman.Path[#travelingSalesman.Path];
	if travelingSalesman.SpawnPoint == travelingSalesman.Destination then
		Logic.DEBUG_AddNote("DEBUG: Destination is spawn point?");
	end
	
	-- don't allow sale
	for pId = 1, 8 do
		Logic.SetTraderPlayerState(travelingSalesman.Storehouse, pId, 2);
	end
	
	-- setup the player
	SetupPlayer(_player, "H_NPC_Generic_Trader", "XTradeShipX", "TravelingSalesmanColor")
	
	-- start job
	travelingSalesman.Job = Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_SECOND, nil, self.Loop, 1, 0, { JobQueue_AddParameter(travelingSalesman) });
	
	-- add to list
	TravelingSalesman.List[_player] = travelingSalesman;
	
	-- return!
	return travelingSalesman;
end

function TravelingSalesman:Enable(_state)
	-- got a player id and not the table?
	if type(self) == "number" then
		self = TravelingSalesman.List[self];
	end
	-- checks
	assert(type(self) == "table");
	assert(type(_state) == "boolean");
	-- set property
	self.Disabled = not _state;
end

function TravelingSalesman:IsEnabled()
	-- got a player id and not the table?
	if type(self) == "number" then
		self = TravelingSalesman.List[self];
	end
	-- checks
	assert(type(self) == "table");
	
	return not self.Disabled;
end

function TravelingSalesman:IsOutOfMap()
	-- got a player id and not the table?
	if type(self) == "number" then
		self = TravelingSalesman.List[self];
	end
	-- checks
	assert(type(self) == "table");
	
	return self.Status == g_TravelingSalesmanStatus.Sailing;
end

function TravelingSalesman:IsSailingToHarbour()
	-- got a player id and not the table?
	if type(self) == "number" then
		self = TravelingSalesman.List[self];
	end
	-- checks
	assert(type(self) == "table");
	
	return self.Status == g_TravelingSalesmanStatus.OnHisWay;
end

function TravelingSalesman:IsAtHarbour()
	-- got a player id and not the table?
	if type(self) == "number" then
		self = TravelingSalesman.List[self];
	end
	-- checks
	assert(type(self) == "table");
	
	return self.Status == g_TravelingSalesmanStatus.AtHarbour;
end

function TravelingSalesman:IsLeavingTheMap()
	-- got a player id and not the table?
	if type(self) == "number" then
		self = TravelingSalesman.List[self];
	end
	-- checks
	assert(type(self) == "table");
	
	return self.Status == g_TravelingSalesmanStatus.Leaving;
end

function TravelingSalesman:AddOffers(_month, _offers)
	-- got a player id and not the table?
	if type(self) == "number" then
		self = TravelingSalesman.List[self];
	end
	
	-- checks
	assert(type(self) == "table");
	assert(type(_month) == "number" and _month >= 1 and _month <= 12);
	assert(type(_offers) == "table");
	
	self.OfferTable[_month] = _offers;
end

function TravelingSalesman:RemoveOffers(_month)
	-- got a player id and not the table?
	if type(self) == "number" then
		self = TravelingSalesman.List[self];
	end
	
	-- checks
	assert(type(self) == "table");
	assert(type(_month) == "number" and _month >= 1 and _month <= 12);
	
	self.OfferTable[_month] = nil;
end

function TravelingSalesman:Sail()

	-- is salesman disabled?
	if self.Disabled then
		return;
	end
	
	local currMonth = Logic.GetCurrentMonth();
	for month, offers in pairs(self.OfferTable) do
		if month == currMonth then
			-- create offers
			g_TravelingSalesman = { StorehouseID = self.Storehouse };
			
			GenerateTravelingSalesManOffersForMonth(offers);
			
			-- create ship (and wave)
			local x, y = Logic.GetEntityPosition(self.SpawnPoint);
			local orientation = Logic.GetEntityOrientation(self.SpawnPoint);
			self.Ship = Logic.CreateEntity(Entities.D_X_TradeShip, x, y, orientation, self.PlayerID);
			self.ShipPathInstance = Path:new(self.Ship, self.Path, false, not self.BackPath, self.ShipArrived, not self.BackPath and self.Left, true, self.LoopCallback, self, 500);
			
			if self.CreateWave then
				self.Wave = Logic.CreateEntity(Entities.E_Kogge, x, y, orientation, self.PlayerID);
				self.WavePathInstance = Path:new(self.Wave, self.Path, false, not self.BackPath, self.WaveArrived, nil, true, self.LoopCallback, self, 500);
			end
			
			self.Status = g_TravelingSalesmanStatus.OnHisWay;
			
			-- message of salesman
			Logic.ExecuteInLuaLocalState("LocalScriptCallback_QueueVoiceMessage(".. self.PlayerID ..", 'TravelingSalesmanSpotted')");
			
			-- callback
			if Mission_Callback_TravelingSalesman then
				Mission_Callback_TravelingSalesman(self.Status, self.PlayerID);
			end
			
			return;
		end
	end
end

function TravelingSalesman.ShipArrived(_path, _destPoint)
	local self = _path.TagData;
	
	-- timestamp
	self.StartOfActiveTime = Logic.GetTime();

	-- allow selling
	for pId = 1, 8 do
		if pId ~= self.PlayerID and (not self.CheckDiplomacy or GetDiplomacyState(self.PlayerID, pId) >= DiplomacyStates.TradeContact) then
			Logic.SetTraderPlayerState(self.Storehouse, pId, 0);
		end
	end
	
	QuestTemplate:New("TravelingSalesman",
		self.PlayerID,
		1,
		{ {Objective.Object, { _destPoint } } },
		{ { Triggers.Time, 0 } },
		self.ActiveTime
	);

	if Mission_Callback_TravelingSalesman then
		Mission_Callback_TravelingSalesman(self.Status, self.PlayerID);
	end

	self.Status = g_TravelingSalesmanStatus.AtHarbour;
	
	if not self.BackPath then
		-- hack to circumvent Trigger.DisableTrigger() problem and to rotate the entity (Logic.MoveEntity() seems to be called to the current position after this function is called)
		Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_TURN, nil, "HACK_TravelingSalesman_RotateEntityAndDisableTrigger", 1, 0, { _path.Job, _path.Entity, Logic.GetEntityOrientation(_destPoint) });
	end
end

function TravelingSalesman.WaveArrived(_path, _destPoint)

	-- hack to circumvent Trigger.DisableTrigger() problem and to rotate the entity (Logic.MoveEntity() seems to be called to the current position after this function is called)
	Trigger.RequestTrigger(Events.LOGIC_EVENT_EVERY_TURN, nil, "HACK_TravelingSalesman_RotateEntityAndDisableTrigger", 1, 0, { _path.Job, _path.Entity, Logic.GetEntityOrientation(_destPoint) });
end

function HACK_TravelingSalesman_RotateEntityAndDisableTrigger(_job, _entity, _orientation)
	Logic.RotateEntity(_entity, _orientation);
	Trigger.DisableTrigger(_job);
	return true;
end

function TravelingSalesman:AtHarbour()
	-- shall it return?
	if Logic.GetTime() > self.StartOfActiveTime + self.ActiveTime or self.Disabled then
	
		if self.BackPath then
			self.ShipPathInstance = Path:new(self.Ship, self.BackPath, false, false, self.Left, nil, true, nil, self);
			
			if self.Wave then
				self.WavePathInstance = Path:new(self.Wave, self.BackPath, false, false, nil, nil, true, nil, self);
			end
			
		else
			Trigger.EnableTrigger(self.ShipPathInstance.Job);
			
			if self.Wave then
				Trigger.EnableTrigger(self.WavePathInstance.Job);
			end
		end
		
		for pId = 1, 8 do
			Logic.SetTraderPlayerState(self.Storehouse, pId, 2);
		end
		
		self.Status = g_TravelingSalesmanStatus.Leaving;
		
		if Mission_Callback_TravelingSalesman then
			Mission_Callback_TravelingSalesman(self.Status, self.PlayerID);
		end
	end
end

function TravelingSalesman.Left(_path)
	local self = _path.TagData;
	
	-- destroy ship
	Logic.DestroyEntity(self.Ship);
	self.Ship = nil;
	self.ShipPathInstance = nil;
	
	-- destroy wave
	if self.Wave then
		Logic.DestroyEntity(self.Wave);
		self.Wave = nil;
		self.WavePathInstance = nil;
	end
	
	-- reset state
	self.Status = g_TravelingSalesmanStatus.Sailing;
	
	if Mission_Callback_TravelingSalesman then
		Mission_Callback_TravelingSalesman(self.Status, self.PlayerID);
	end
end

function TravelingSalesman.LoopCallback(_path)
	local self = _path.TagData;
	
	-- go back...
	if self.Disabled and _path.Direction > 0 then
		_path.Direction = -_path.Direction;
		if _path.Index > 1 then
			_path.Index = _path.Index + _path.Direction;
			_path:Move();
		end
		
		if Logic.GetEntityType(_path.Entity) == Entities.D_X_TradeShip then
			-- set state...
			self.Status = g_TravelingSalesmanStatus.Leaving;
			
			Logic.ExecuteInLuaLocalState("LocalScriptCallback_QueueVoiceMessage(" .. self.PlayerID .. ", 'TravelingSalesman_Failure')");

			if Mission_Callback_TravelingSalesman then
				Mission_Callback_TravelingSalesman(self.Status, self.PlayerID);
			end
		end
	end
end

function TravelingSalesman_Loop(_index)
	local self = JobQueue_GetParameter(_index);
	
	-- when store house is destroyed, end 
	if Logic.IsEntityDestroyed(self.Storehouse) then
		if self.Ship and Logic.IsEntityAlive(self.Ship) then
			Logic.DestroyEntity(self.Ship);
			if self.ShipPathInstance then
				Trigger.UnrequestTrigger(self.ShipPathInstance.Job);
				self.ShipPathInstance = nil;
			end
			if self.CreateWave and self.Wave and Logic.IsEntityAlive(self.Wave) then
				Logic.DestroyEntity(self.Wave);
				if self.WavePathInstance then
					Trigger.UnrequestTrigger(self.WavePathInstance.Job);
					self.WavePathInstance = nil;
				end
			end
		end
		TravelingSalesman.List[self.PlayerID] = nil;
		
		JobQueue_RemoveParameter(_index);
		Logic.ExecuteInLuaLocalState("LocalScriptCallback_QueueVoiceMessage(" .. self.PlayerID .. ", 'TravelingSalesmanDestroyed')");
		return true;
	end
	
	if self.Status == g_TravelingSalesmanStatus.Sailing then
		self:Sail();
	elseif self.Status == g_TravelingSalesmanStatus.AtHarbour then
		self:AtHarbour();
	elseif self.Status ~= g_TravelingSalesmanStatus.OnHisWay and self.Status ~= g_TravelingSalesmanStatus.Leaving then
		Logic.DEBUG_AddNote("DEBUG: Unknown traveling salesman state!");
	end
end
