--!strict

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Variables
local SharedFL = ReplicatedStorage.Shared
local QuestService = {}

-- Dependencies
local QuestFL = SharedFL.Services.QuestService
local QuestServiceTypes = require(QuestFL["QuestService_Types"])
local Client = require(SharedFL.Network.Client)

-- Sent by the server
local AwaitingQuests = {} :: {QuestServiceTypes.Quest}

-- Client
local NewQuestCallbacks = {} :: {(QuestServiceTypes.Quest) -> ()}
local QuestRemovedCallbacks = {} :: {(QuestServiceTypes.Quest) -> ()}
local QuestUpdateCallbacks = {} :: {(QuestServiceTypes.Quest) -> ()}

--// Functions
QuestService.Connect = {
	New = function(Callback : (QuestServiceTypes.Quest) -> ()) : () -> ()
		table.insert(NewQuestCallbacks, Callback)
		
		return function()
			table.remove(NewQuestCallbacks, table.find(NewQuestCallbacks, Callback))
		end
	end,
	
	Removed = function(Callback : (QuestServiceTypes.Quest) -> ()) : () -> ()
		table.insert(QuestRemovedCallbacks, Callback)
		
		return function()
			table.remove(QuestRemovedCallbacks, table.find(QuestRemovedCallbacks, Callback))
		end
	end,
	
	Updated = function(Callback : (QuestServiceTypes.Quest) -> ()) : () -> ()
		table.insert(QuestUpdateCallbacks, Callback)

		return function()
			table.remove(QuestUpdateCallbacks, table.find(QuestUpdateCallbacks, Callback))
		end
	end,
}

function QuestService.GetQuests()
	if not QuestFL:GetAttribute('Loaded') then 
		QuestFL:GetAttributeChangedSignal('Loaded'):Wait()
	end
	
	return AwaitingQuests
end


function QuestService.INIT()
	Client.QuestEvents.NewQuest.On(function(Quest)
		table.insert(AwaitingQuests, Quest)

		-- Calling every callback
		for _, Callback in NewQuestCallbacks do 
			Callback(Quest)
		end
		
		-- Setting Loaded on CLIENT
		QuestFL:SetAttribute('Loaded', true)
	end)
	
	Client.QuestEvents.QuestRemove.On(function(RewardID)
		-- Go through every AwaitingQuest and remove that questID
		for key, Quest in AwaitingQuests do 
			if Quest.RewardID == RewardID then
				-- Found
				local ClonedQuest = table.clone(Quest)
				table.remove(AwaitingQuests, key)

				-- Callbacks
				for _, Callback in QuestRemovedCallbacks do 
					Callback(ClonedQuest)
				end
				
				break
			end
		end
	end)
	
	Client.QuestEvents.QuestUpdate.On(function(Quest)
		-- Updating Updated Quests Cache
		for i,v in AwaitingQuests do 
			if v.RewardID == Quest.RewardID then
				table.remove(AwaitingQuests, i)
				break
			end
		end
		
		-- Adding new Quest
		table.insert(AwaitingQuests, Quest)
		
		-- Sending Update Callbacks
		for _, Callback in QuestUpdateCallbacks do 
			Callback(Quest)
		end
	end)
end

return QuestService