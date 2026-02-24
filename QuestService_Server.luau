--!strict
--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Dependencies
local LibraryDictionary = require(ReplicatedStorage.Shared.Libraries.LibraryDictionary)
local QuestServiceTypes = require(ReplicatedStorage.Shared.Services.QuestService["QuestService_Types"])
local ServerNetwork = require(ReplicatedStorage.Shared.Network.Server)
local QuestLibrary = LibraryDictionary.GetAllQuests()
local DATAMANAGER = require(ServerScriptService.Libraries.Data["DATA_MANAGER"])

--// Modules
local QuestAPI = {}
QuestAPI.__Cache = {} :: {[string]: {QuestServiceTypes.Quest}}
QuestAPI.__Current = {} :: {[string]: {[string]: string}}

local QuestService = {}

--// API Functions
function QuestAPI.NewRewardID() : string
	return HttpService:GenerateGUID(false)
end

--[[
	Constructs a quest table structure.
]]
function QuestAPI.CreateQuery(QuestName : string, Amount : number) : QuestServiceTypes.Quest
	return {
		QuestName = QuestName,
		Amount = Amount,
		AmountDone = 0,
		RewardID = QuestAPI.NewRewardID()
	}
end

--[[
	Cache's a players construct.
]]
function QuestAPI.Cache(PlayerName : string, Construct : QuestServiceTypes.Quest)
	if not QuestAPI.__Cache[PlayerName] then
		QuestAPI.__Cache[PlayerName] = {}
		QuestAPI.__Current[PlayerName] = {}
	end
	
	QuestAPI.__Current[PlayerName][Construct.QuestName] = Construct.RewardID
	table.insert(QuestAPI.__Cache[PlayerName], Construct)
end

--[[
	Uncaches a single construct.
]]
function QuestAPI.UnCache(PlayerName : string, RewardID : string)
	if not QuestAPI.__Cache[PlayerName] then
		warn(`{PlayerName} does not have a cache to uncache.`)
		return
	end
	
	local function Foo()
		for Index, Quest in QuestAPI.__Cache[PlayerName] do
			if Quest.RewardID == RewardID then
				QuestAPI.__Current[PlayerName][Quest.QuestName] = nil
				table.remove(QuestAPI.__Cache[PlayerName], Index)
			end
		end
	end
	
	task.spawn(Foo)
end

--[[
	Gets the latest version of player caches.
]]
function QuestAPI.GetCache(PlayerName : string)
	return QuestAPI.__Cache[PlayerName]
end

--[[
	Gets the latest version of player currents.
]]
function QuestAPI.GetCurrent(PlayerName : string)
	return QuestAPI.__Current[PlayerName]
end
--[[
	Cleans the players cache
]]
function QuestAPI.CleanCache(PlayerName : string)
	QuestAPI.__Cache[PlayerName] = nil
	QuestAPI.__Current[PlayerName] = nil
end

--// Public Functions
--[[
	Initates a new quest for the player arguement.
	@param Player Player? The Player
	@param Construct QuestConstruct -- Use the API for this!!
]]
function QuestService.Create(Player : Player, Construct : QuestServiceTypes.Quest)
	-- Caching
	QuestAPI.Cache(Player.Name, Construct)
	
	-- Replicating Data to Client
	ServerNetwork.QuestEvents.NewQuest.Fire(Player, Construct)
end

--[[
	Removes an already existing quest for the player.
	@param Player Player? The Player
	@param RewardID String -- Use existing API or fetch catch
]]
function QuestService.Remove(Player : Player, RewardID : string)
	-- Uncaching
	QuestAPI.UnCache(Player.Name, RewardID)
	
	-- Replicating to client
	ServerNetwork.QuestEvents.QuestRemove.Fire(Player, RewardID)
end

--[[
	Updates an already existing quest (Only Amount Done)
	@param Player Player? The Player
	@param RewardID String -- Use existing API or fetch catch
	@param NewAmount Number The Amount DOne
]]
function QuestService.Update(Player : Player, RewardID : string, AddedAmount : number)
	-- Getting Cache
	local Cache = QuestAPI.GetCache(Player.Name)
	assert(Cache, `No cache for {Player}`)
	
	-- Looping through cache for RewardID
	for i,v in Cache do 
		if v.RewardID == RewardID then
			if v.Amount <= v.AmountDone then 
				QuestService.Reward(Player, v.RewardID)
				break
			end 
			
			v.AmountDone += AddedAmount or 1
			ServerNetwork.QuestEvents.QuestUpdate.Fire(Player, v)
			
			break
		end
	end
end

--[[
	Uses Library to find the reward
]]
function QuestService.Reward(Player : Player, RewardID : string)
	local Cache = QuestAPI.GetCache(Player.Name)
	assert(Cache, `No cache for {Player}`)
	
	-- Looping through cache for RewardID
	for i,v in Cache do 
		if v.RewardID == RewardID then
			local Reward = QuestLibrary[v.QuestName]
			assert(Reward, `No reward library found for {v.QuestName}`)
			
			-- Removing 
			QuestService.Remove(Player, RewardID)
			
			-- Rewarding
			if Reward.RewardType == 'Cash' then
				DATAMANAGER.ModifyCash(Player, Reward.Value)
			end
			
			break
		end
	end
end

function QuestService.GetAPI()
	return QuestAPI
end

return QuestService