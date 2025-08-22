-- NPC_TargetLock.server.lua
-- Place in ServerScriptService

local replicatedStorage = game:GetService("ReplicatedStorage")

-- Create RemoteEvent if not already in ReplicatedStorage
local event = replicatedStorage:FindFirstChild("NPCTargetLockToggle")
if not event then
	event = Instance.new("RemoteEvent")
	event.Name = "NPCTargetLockToggle"
	event.Parent = replicatedStorage
end

-- Admins (only these players can toggle NPC lock)
local admins = {
	[12345678] = true, -- replace with your UserId
}

-- Store NPC lock state
local npcLockEnabled = false

-- Folder in Workspace that contains NPCs
local npcFolder = workspace:FindFirstChild("NPCs")
if not npcFolder then
	npcFolder = Instance.new("Folder")
	npcFolder.Name = "NPCs"
	npcFolder.Parent = workspace
end

-- Function: make an NPC chase the nearest player
local function chasePlayers(npc)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local hrp = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then return end

	while npc.Parent and npcLockEnabled do
		local nearest, dist = nil, math.huge
		for _, player in ipairs(game.Players:GetPlayers()) do
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local pHRP = player.Character.HumanoidRootPart
				local d = (pHRP.Position - hrp.Position).Magnitude
				if d < dist then
					dist = d
					nearest = pHRP
				end
			end
		end

		if nearest then
			humanoid:MoveTo(nearest.Position)
		end
		task.wait(0.5)
	end
end

-- When RemoteEvent is triggered
event.OnServerEvent:Connect(function(player, state)
	if not admins[player.UserId] then
		warn(player.Name .. " tried to toggle NPC lock but is not admin.")
		return
	end

	npcLockEnabled = state
	print("NPC Lock Enabled:", npcLockEnabled)

	if npcLockEnabled then
		-- Start chasing loop for all NPCs
		for _, npc in ipairs(npcFolder:GetChildren()) do
			task.spawn(chasePlayers, npc)
		end
	end
end)

-- Detect when new NPCs are added
npcFolder.ChildAdded:Connect(function(npc)
	if npcLockEnabled then
		task.spawn(chasePlayers, npc)
	end
end)
