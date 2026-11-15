-- bedwars ingame

local _runCount = 0
local _runBusy = false
local run = function(func)
	if not _runBusy then
		_runBusy = true
		_runCount = _runCount + 1
		if _runCount % 8 == 0 then
			task.wait()
		end
		local ok, err = pcall(func)
		_runBusy = false
		if not ok then
			warn('[aerov4] module failed to load: ' .. tostring(err))
		end
		return
	end
	local ok, err = pcall(func)
	if not ok then
		warn('[aerov4] module failed to load: ' .. tostring(err))
	end
end
task.wait()
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})
getgenv().vapeEvents = vapeEvents

local cloneref = cloneref or function(obj)
	return obj
end

local function safeGetProto(func, index)
    if not func then return nil end
    local success, proto = pcall(debug.getconstant, func, index)
    if success then
        return proto
    end
end

local inventoryDebounce = false
local function fireInventoryChanged()
    if inventoryDebounce then return end
    inventoryDebounce = true
    task.spawn(function()
        task.wait() 
        vapeEvents.InventoryChanged:Fire()
        inventoryDebounce = false
    end)
end

local playersService = cloneref(game:GetService('Players'))
local collectionService = cloneref(game:GetService('CollectionService'))
local function getLocalKits()
	local raw = playersService.LocalPlayer:GetAttribute('PlayingAsKits')
	local list = {}
	if type(raw) == 'string' then
		for kit in raw:gmatch('[%w_]+') do
			if kit ~= '' and kit ~= 'none' then
				table.insert(list, kit)
			end
		end
	end
	return list
end
getgenv().aeroTeamColors = {
	[1] = {name = 'blue',   color = Color3.fromRGB(85, 150, 255)},
	[2] = {name = 'orange', color = Color3.fromRGB(255, 150, 50)},
	[3] = {name = 'pink',   color = Color3.fromRGB(255, 100, 200)},
	[4] = {name = 'yellow', color = Color3.fromRGB(255, 255, 50)},
	[5] = {name = 'brown',  color = Color3.fromRGB(139, 69, 19)},  
	[6] = {name = 'white',  color = Color3.fromRGB(255, 255, 255)}, 
	[7] = {name = 'cyan',   color = Color3.fromRGB(120, 255, 255)}, 
	[8] = {name = 'purple', color = Color3.fromRGB(180, 90, 255)},  
}
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))
local VirtualInputManager = game:GetService("VirtualInputManager")
local lightingService = cloneref(game:GetService('Lighting'))

local isnetworkowner = identifyexecutor and table.find({'Delta', 'Volt'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
if vape and not vape.Clean then
	vape.Clean = function(self, conn)
		if not conn then return end
		
		if not vape.Connections then
			vape.Connections = {}
		end

		if self and self.Enabled then
			vape.Connections[conn] = true
			return conn
		else
			if vape.Connections[conn] then
				if typeof(conn) == "RBXScriptConnection" then
					pcall(conn.Disconnect, conn)
				end
				vape.Connections[conn] = nil
			end
		end
	end
end
if vape and not vape.Remove then
    vape.Remove = function(module) 
		return module 
	end
end
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = { get = function() return nil, true end, tag = function() return '' end, customtags = {} }
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local store = {
    attackReach = 0,
    attackReachUpdate = tick(),
    hand = {},
    inventory = {
        inventory = {
            items = {},
            armor = {}
        },
        hotbar = {}
    },
    inventories = setmetatable({}, { __mode = "k" }), 
    matchState = 0,
    queueType = 'bedwars_test',
    tools = {},
    lastToolUpdate = 0,
	lastKrystalUpdateCheck = 0,
	BedAlarmNotifyTick = 0,
	BedAlarmIsTrigged = false,
	BedAlarmHighlightedEnimes = {},
	BedAlarm = {},
	BedAlarmSoundTick = 0,
	silasAbilityTime = 0,
	terraStompTime = 0,
	terraKickTime = 0,
}
getgenv().store = store
local splashParams = RaycastParams.new()
splashParams.FilterType = Enum.RaycastFilterType.Include
local function splashAimPoint(root, hip)
	local map = workspace:FindFirstChild('Map')
	if not map or not root then return nil end
	if math.abs(root.AssemblyLinearVelocity.Y) > 2 then return nil end
	splashParams.FilterDescendantsInstances = {map}
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -((hip or 2) + root.Size.Y / 2 + 0.6), 0), splashParams)
	if hit then
		return Vector3.new(root.Position.X, hit.Position.Y + 0.5, root.Position.Z)
	end
	return nil
end
local function balloonGravity(balloons, char)
	local lift = balloons >= 4 and 1.2 or balloons >= 3 and 1.1 or balloons >= 2 and 0.975 or 0.85
	local root = char and char.PrimaryPart
	local vy = root and root.AssemblyLinearVelocity.Y or 0
	return workspace.Gravity * (1 - lift) + 0.1731 * vy * math.abs(vy)
end
local Reach = {}
local HitBoxes = {}
local TrapDisabler
local TrapSnap, TrapMine, TrapTeleport, TrapPortal = {}, {}, {}, {}
local AntiFallPart
local bedwars, remotes, sides, oldinvrender, oldSwing = {}, {}, {}, {}, {}

local function getReach(tool)
	local itemMeta = tool and bedwars.ItemMeta and bedwars.ItemMeta[tool.Name]
	return itemMeta and itemMeta.sword and itemMeta.sword.attackRange or 14.4
end
getgenv().getReach = getReach

local _missingRemotes = {}
setmetatable(remotes, {
	__index = function(_, key)
		if not _missingRemotes[key] then
			_missingRemotes[key] = true
			task.delay(10, function()
				if rawget(remotes, key) == nil then
					pcall(function()
						vape.Notify('[aerov4] remote "' .. tostring(key) .. '" changed or removed some features may not work bru (dm @5qvx for fix)', 6)
					end)
				end
			end)
		end
		return nil
	end
})
local originalKnit

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('aerov4/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local readyGate = getgenv().aeroReadyGate or {}
getgenv().aeroReadyGate = readyGate

function readyGate.Release()
	if not readyGate.Held then
		return
	end
	readyGate.Held = false
	local heldRemote = readyGate.Remote
	readyGate.Remote = nil
	if heldRemote then
		heldRemote:FireServer()
	end
end

if not readyGate.Hooked and hookmetamethod and not lplr:GetAttribute('PlayerConnected') then
	readyGate.Hooked = true
	readyGate.Held = true
	readyGate.Started = os.clock()
	local wrap = newcclosure or function(f) return f end
	local oldNamecall
	oldNamecall = hookmetamethod(game, '__namecall', wrap(function(...)
		local self = ...
		if readyGate.Held and not checkcaller() and getnamecallmethod() == 'FireServer' and tostring(self) == 'PlayerReady' then
			readyGate.Remote = self
			return
		end
		return oldNamecall(...)
	end))
	task.delay(45, function()
		if not readyGate.Claimed then
			readyGate.Release()
		end
	end)
end
vape:Clean(function()
	readyGate.Release()
end)

local function notif(...) return
	vape:CreateNotification(...)
end

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}
	local fastIndex = #tags == 1 and tags[1] == 'block' and not customadd and not customremove and {} or nil

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			if fastIndex and fastIndex[v] then return end
			table.insert(objs, v)
			if fastIndex then fastIndex[v] = #objs end
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			local idx = fastIndex and fastIndex[v] or (not fastIndex and table.find(objs, v))
			if idx then
				local last = #objs
				local moved = objs[last]
				objs[idx] = moved
				objs[last] = nil
				if fastIndex then
					fastIndex[v] = nil
					if idx ~= last then fastIndex[moved] = idx end
				end
			end
		end))

		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			if not fastIndex or not fastIndex[v] then
				table.insert(objs, v)
				if fastIndex then fastIndex[v] = #objs end
			end
		end
	end

	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		if fastIndex then table.clear(fastIndex) end
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end

local function scanDescendants(root, fn, module)
	local state = {cancelled = false}
	if module then
		module:Clean(function() state.cancelled = true end)
	end
	task.spawn(function()
		local stack = {root or workspace}
		local budget = 0
		while #stack > 0 do
			if state.cancelled then return end
			local node = stack[#stack]
			stack[#stack] = nil
			local kids = node:GetChildren()
			for i = 1, #kids do
				local child = kids[i]
				stack[#stack + 1] = child
				fn(child)
			end
			budget += #kids
			if budget >= 700 then
				budget = 0
				task.wait()
				if state.cancelled then return end
			end
		end
	end)
	return state
end

local function cleanThread(module, thread)
	module:Clean(function()
		if thread then
			pcall(task.cancel, thread)
			thread = nil
		end
	end)
	return thread
end

local function getBestArmor(slot)
	local closest, mag = nil, 0

	for _, item in store.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta[item.itemType] or {}

		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)

			if newmag > mag then
				closest, mag = item, newmag
			end
		end
	end

	return closest
end

local function getBow()
	local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local _bowItemMeta = bedwars.ItemMeta[item.itemType]
        local bowMeta = _bowItemMeta and _bowItemMeta.projectileSource
		if bowMeta and table.find(bowMeta.ammoItemTypes, 'arrow') then
			local bowDamage = bedwars.ProjectileMeta[bowMeta.projectileType('arrow')].combat.damage or 0
			if bowDamage > bestBowDamage then
				bestBow, bestBowSlot, bestBowDamage = item, slot, bowDamage
			end
		end
	end
	return bestBow, bestBowSlot
end

local function getItem(itemName, inv)
	for slot, item in (inv or store.inventory.inventory.items) do
		if item.itemType == itemName then
			return item, slot
		end
	end
	return nil
end

local function GetItems(item: string): table
	local Items: table = {};
	for _, v in next, Enum[item]:GetEnumItems() do 
		table.insert(Items, v["Name"]) ;
	end;
	return Items;
end;

local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end

local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local _swordItemMeta = bedwars.ItemMeta[item.itemType]
        local swordMeta = _swordItemMeta and _swordItemMeta.sword
		if swordMeta then
			local swordDamage = swordMeta.damage or 0
			if swordDamage > bestSwordDamage then
				bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
			end
		end
	end
	return bestSword, bestSwordSlot
end

local function getTool(breakType)
	local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local _toolItemMeta = bedwars.ItemMeta[item.itemType]
        local toolMeta = _toolItemMeta and _toolItemMeta.breakBlock
		if toolMeta then
			local toolDamage = toolMeta[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
			end
		end
	end
	return bestTool, bestToolSlot
end

local function getWool()
	for _, wool in store.inventory.inventory.items do
		if wool.itemType:find('wool') then
			return wool and wool.itemType, wool and wool.amount
		end
	end
end

local function getStrength(plr)
	if not plr or not plr.Player then
		return 0
	end

	local strength = 0
	for _, v in (store.inventories[plr.Player] or {items = {}}).items do
		local itemmeta = bedwars.ItemMeta[v.itemType]
		if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
			strength = itemmeta.sword.damage
		end
	end

	return strength
end

local function getPlacedBlock(pos)
	if not pos then
		return
	end
	local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
	return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
end

local function getBlocksInPoints(s, e)
	local blocks, list = bedwars.BlockController:getStore(), {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					table.insert(list, vec * 3)
				end
			end
		end
	end
	return list
end

local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
	local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))

	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local newmag = (localPosition - v).Magnitude
			if newmag < mag then
				mag, closest = newmag, v + Vector3.new(0, 3, 0)
			end
		end
	end

	table.clear(blocks)
	return closest
end

local itemSkinMetaFn
local function getItemSkinMeta(skin)
	if itemSkinMetaFn == nil then
		itemSkinMetaFn = false
		pcall(function()
			for _, m in replicatedStorage.TS.games.bedwars['item-skin']:GetDescendants() do
				if m:IsA('ModuleScript') then
					local ok, res = pcall(require, m)
					if ok and type(res) == 'table' and type(res.getItemSkinMeta) == 'function' then
						itemSkinMetaFn = res.getItemSkinMeta
						break
					end
				end
			end
		end)
	end
	if not itemSkinMetaFn then return nil end
	local ok, res = pcall(itemSkinMetaFn, skin)
	return ok and res or nil
end

local skinSoundBackup = {}
local function applySkinSounds(itemType, skin)
	local meta = bedwars.ItemMeta and bedwars.ItemMeta[itemType]
	if not meta then return end
	local backup = skinSoundBackup[itemType]
	if backup then
		for _, v in backup do
			v[1][v[2]] = v[3]
		end
		skinSoundBackup[itemType] = nil
	end
	local skinmeta = skin and getItemSkinMeta(skin)
	if type(skinmeta) ~= 'table' then return end
	local saved = {}
	for section, data in skinmeta do
		local target = meta[section]
		if type(data) == 'table' and type(target) == 'table' then
			for key, val in data do
				if type(key) == 'string' and key:lower():find('sound') then
					table.insert(saved, {target, key, target[key]})
					target[key] = val
				end
			end
		end
	end
	if #saved > 0 then
		skinSoundBackup[itemType] = saved
	end
end

local function getShieldAttribute(char)
	local total = char:GetAttribute('TotalShield')
	if type(total) == 'number' then
		return math.max(total, 0)
	end
	local returned = 0
	for name, val in char:GetAttributes() do
		if name:find('Shield') and type(val) == 'number' and val > 0 then
			returned += val
		end
	end
	return returned
end

local function getSpeed()
	local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()

	local modifiers2 = bedwars.SprintController:getMovementStatusModifier():getModifiers()
	for _, v in modifiers do
		if type(v) == 'table' then
			local val = v.constantSpeedMultiplier and v.constantSpeedMultiplier or 0
			if val and val > math.max(multi, 1) then
				increase = false
				multi = val - (0.06 * math.round(val))
			end
		end
	end

	for _, v in modifiers2 do
		if type(v) == 'table' then
			multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
		end
	end

	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end

	return 20 * (multi + 1)
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end

local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
end

local function getHotbar(tool)
	for i, v in (store.inventory.hotbar or {}) do
		if v.item and v.item.tool == tool then
			return i - 1
		end
	end
	return nil
end
getgenv().getHotbar = getHotbar

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function roundPos(vec)
    return Vector3.new(
        math.round(vec.X / 3) * 3,
        math.round(vec.Y / 3) * 3,
        math.round(vec.Z / 3) * 3
    )
end

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end

local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = tick() + timeout
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if (returned and returned.Name ~= 'UpperTorso') or check < tick() then
			break
		end
		task.wait()
	until false
	return returned
end

local frictionTable, oldfrict = {}, setmetatable({}, {__mode = 'k'})
local lastUpdate = setmetatable({}, {__mode = 'k'})
local lagConnections = {}
local frictionConnection
local frictionState

local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end

local function updateVelocity(force)
	local newState = getTableSize(frictionTable) > 0
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end

local function isEveryoneDead()
	return #bedwars.Store:getState().Party.members <= 0
end
	
local function joinQueue()
	if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
		bedwars.QueueController:joinQueue(store.queueType)
	end
end

local function lobby()
    bedwars.Client:Get(remotes.TeleportToLobby):FireServer()
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local function HasSeed(character)
    if not character then return false end
    return character:FindFirstChild("Seed", true) ~= nil
end

local sortmethods = {
	Threat = function(a, b)
		if not a.Entity then return false end
		if not b.Entity then return true end
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Health = function(a, b)
		if not a.Entity then return false end
		if not b.Entity then return true end
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		if not a.Entity or not a.Entity.RootPart then return false end
		if not b.Entity or not b.Entity.RootPart then return true end
		local selfrootpos = entitylib.character.RootPart.Position
		local rawFacing = (getgenv().ViewMode and getgenv().ViewMode.Value == 'Third Person') and gameCamera.CFrame.LookVector or entitylib.character.RootPart.CFrame.LookVector
		local flatFacing = Vector3.new(rawFacing.X, 0, rawFacing.Z)
		if flatFacing.Magnitude < 0.001 then return false end
		local localFacing = flatFacing.Unit
		local deltaA = Vector3.new(a.Entity.RootPart.Position.X - selfrootpos.X, 0, a.Entity.RootPart.Position.Z - selfrootpos.Z)
		local deltaB = Vector3.new(b.Entity.RootPart.Position.X - selfrootpos.X, 0, b.Entity.RootPart.Position.Z - selfrootpos.Z)
		if deltaA.Magnitude < 0.001 or deltaB.Magnitude < 0.001 then return deltaA.Magnitude < deltaB.Magnitude end
		local angle = math.acos(math.clamp(localFacing:Dot(deltaA.Unit), -1, 1))
		local angle2 = math.acos(math.clamp(localFacing:Dot(deltaB.Unit), -1, 1))
		return angle < angle2
	end,
	Distance = function(a, b)
		if not a.Entity or not a.Entity.RootPart then return false end
		if not b.Entity or not b.Entity.RootPart then return true end
		local selfpos = entitylib.character.RootPart.Position
		local distA = (a.Entity.RootPart.Position - selfpos).Magnitude
		local distB = (b.Entity.RootPart.Position - selfpos).Magnitude
		return distA < distB
	end,
	Cursor = function(a, b)
		if not a.Entity or not a.Entity.RootPart then return false end
		if not b.Entity or not b.Entity.RootPart then return true end
		local camera = gameCamera
		local mousePos = inputService:GetMouseLocation()
		local function screenDist(ent)
			local rootPart = ent.RootPart
			if not rootPart then return math.huge end
			local screenPos, onScreen = camera:WorldToScreenPoint(rootPart.Position)
			if not onScreen then return math.huge end
			return (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
		end
		local distA = screenDist(a.Entity)
		local distB = screenDist(b.Entity)
		if distA == math.huge and distB == math.huge then
			local selfpos = entitylib.character.RootPart.Position
			local worldA = (a.Entity.RootPart.Position - selfpos).Magnitude
			local worldB = (b.Entity.RootPart.Position - selfpos).Magnitude
			return worldA < worldB
		end
		return distA < distB
	end,
	Forest = function(a, b)
		if not a.Entity then return false end
		if not b.Entity then return true end
		local aHasSeed = HasSeed(a.Entity.Character)
		local bHasSeed = HasSeed(b.Entity.Character)
		if aHasSeed and not bHasSeed then return true end
		if not aHasSeed and bHasSeed then return false end
		if not a.Entity.RootPart then return false end
		if not b.Entity.RootPart then return true end
		local selfpos = entitylib.character.RootPart.Position
		local distA = (a.Entity.RootPart.Position - selfpos).Magnitude
		local distB = (b.Entity.RootPart.Position - selfpos).Magnitude
		return distA < distB
	end
}

local function getSortList(priority)
	local methods = {}
	for _, v in ipairs(priority or {}) do
		table.insert(methods, v)
	end
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	return methods
end

run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') then
			return
		end

		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end

	entitylib.start = function()
		if entitylib.Running then entitylib.stop() end

		local function customEntity(ent)
			if playersService:GetPlayerFromCharacter(ent) then return end
			if collectionService:HasTag(ent.Parent, 'entity') then return end
			local teamFunc = function(self)
				local npcTeam = self.Character:GetAttribute('Team')
				if not npcTeam then return true end
				return lplr:GetAttribute('Team') ~= npcTeam
			end
			entitylib.addEntity(ent, nil, teamFunc)
		end

		table.insert(entitylib.Connections, playersService.PlayerAdded:Connect(function(v)
			entitylib.addPlayer(v)
		end))
		table.insert(entitylib.Connections, playersService.PlayerRemoving:Connect(function(v)
			entitylib.removePlayer(v)
		end))

		for _, v in playersService:GetPlayers() do
			entitylib.addPlayer(v)
		end

		for _, ent in collectionService:GetTagged('entity') do
			customEntity(ent)
		end

		table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
		table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
			entitylib.removeEntity(ent)
		end))

		local function addDesertPot(pot)
			if not pot:IsA('Model') then return end
			entitylib.addEntity(pot, nil, function() return true end)
		end
		for _, v in collectionService:GetTagged('desert_pot') do
			addDesertPot(v)
		end
		table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('desert_pot'):Connect(addDesertPot))
		table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('desert_pot'):Connect(function(v)
			entitylib.removeEntity(v)
		end))

		table.insert(entitylib.Connections, workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
			gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
		end))

		entitylib.Running = true
	end

	entitylib.addPlayer = function(plr)
		if entitylib.PlayerConnections[plr] then
			for _, conn in ipairs(entitylib.PlayerConnections[plr]) do
				if conn and typeof(conn) == "RBXScriptConnection" then
					conn:Disconnect()
				end
			end
		end

		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				if plr == lplr then
					for _, v in entitylib.List do
						local newTargetable = entitylib.targetCheck(v)
						if v.Targetable ~= newTargetable then
							v.Targetable = newTargetable
							entitylib.Events.EntityUpdated:Fire(v)
						end
					end
				else
					entitylib.refreshEntity(plr.Character, plr)
					for _, v in entitylib.List do
						if v.Player ~= plr and v.Targetable ~= entitylib.targetCheck(v) then
							local newTargetable = entitylib.targetCheck(v)
							v.Targetable = newTargetable
							entitylib.Events.EntityUpdated:Fire(v)
						end
					end
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = {}
			if plr and plr ~= lplr then
				local names = {'ArmorInvItem_0', 'ArmorInvItem_1', 'ArmorInvItem_2', 'HandInvItem'}
				for _, name in names do
					local found = char:FindFirstChild(name)
					if found then
						table.insert(updateobjects, found)
					end
				end
			end

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = tick(),
					Jumping = false,
					LandTick = tick(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.AirTime = tick()					end)

					task.wait(0.3)

					if animation then
						pcall(function()
							animation:Stop()
							animation:Destroy()
						end)
					end
				end)
			end

			bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
				blockRef = {blockPosition = dpos},
				hitPosition = pos,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			}):andThen(function(result)
				do
					if result == 'cancelled' then
						table.clear(cache)
						return
					end
					if result == 'destroyed' then
						table.clear(cache) 
					end
					if effects then
						local hmeta = hitType and bedwars.ItemMeta[hitType]
						local btype = getBreakType(dblock)
						local hitdmg = (hmeta and hmeta.breakBlock and btype and hmeta.breakBlock[btype]) or 2
						local predicted = math.max(blockhealthbar.blockHealth - hitdmg, 1)
						local nowHealth = result == 'destroyed' and 0 or math.min(getBlockHealth(dblock, dpos) or predicted, predicted)
						local blockdmg = math.max(blockhealthbar.blockHealth - nowHealth, 0)
						local dmeta = bedwars.ItemMeta[dblock.Name]
						local maxHealth = dblock:GetAttribute('MaxHealth') or (dmeta and dmeta.block and dmeta.block.health) or math.max(blockhealthbar.blockHealth, 1)
						customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
						pcall(customHealthbar, bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, maxHealth, blockdmg, dblock)
						blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)
						pcall(function()
							if blockhealthbar.blockHealth <= 0 then
								bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
								blockhealthbar.breakingBlockPosition = Vector3.zero
								blockhealthbar.blockHealth = -1
								if bedwars.BlockBreaker.healthbarMaid then
									bedwars.BlockBreaker.healthbarMaid:DoCleaning()
								end
							else
								bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
							end
						end)
					end
				end
			end)

			return pos, path, target
		end
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
		end
		if new.Game ~= old.Game then
			store.matchState = new.Game.matchState
			store.queueType = new.Game.queueType or 'bedwars_test'
		end

		if new.Inventory ~= old.Inventory then
			local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
			local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
			store.inventory = newinv

			if newinv ~= oldinv then
				fireInventoryChanged()
			end

			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				store.tools.sword = getSword()
				local now = tick()
				if not store.lastToolUpdate or now - store.lastToolUpdate > 0.5 then
					store.lastToolUpdate = now
					for _, v in {'stone', 'wood', 'wool'} do
						store.tools[v] = getTool(v)
					end
				elseif not store.toolUpdatePending then
					store.toolUpdatePending = true
					task.delay(0.5, function()
						store.toolUpdatePending = false
						store.lastToolUpdate = tick()
						for _, v in {'stone', 'wood', 'wool'} do
							store.tools[v] = getTool(v)
						end
					end)
				end
			end

			if newinv.inventory.hand ~= oldinv.inventory.hand then
				store.lastToolUpdate = tick()
				store.tools.sword = getSword()
				for _, v in {'stone', 'wood', 'wool'} do
					store.tools[v] = getTool(v)
				end
				local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType]
					toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
				end

				store.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end
		end
	end

	local storeChanged = bedwars.Store.changed:connect(updateStore)
	vape:Clean(function() storeChanged:disconnect() end)
	updateStore(bedwars.Store:getState(), {})

	for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(event):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[event]:Fire(...)
			end))
		end)
	end

	local _dmgEventData = {entityInstance=nil,damage=nil,damageType=nil,fromPosition=nil,fromEntity=nil,knockbackMultiplier=nil,knockbackId=nil,disableDamageHighlight=nil}
	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		_dmgEventData.entityInstance = ...
		_dmgEventData.damage = select(2, ...)
		_dmgEventData.damageType = select(3, ...)
		_dmgEventData.fromPosition = select(4, ...)
		_dmgEventData.fromEntity = select(5, ...)
		_dmgEventData.knockbackMultiplier = select(6, ...)
		_dmgEventData.knockbackId = select(7, ...)
		_dmgEventData.disableDamageHighlight = select(13, ...)
		_dmgEventData.swingInfo = select(8, ...)
		vapeEvents.EntityDamageEvent:Fire(_dmgEventData)
	end))

	vape:Clean(playersService.PlayerRemoving:Connect(function(plr)
		store.inventories[plr] = nil
	end))

	for _, event in {'PlaceBlockEvent', 'BreakBlockEvent'} do
		vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
			local pos = ...
			local plr = select(5, ...)
			task.spawn(function()
				pcall(function()
					vapeEvents[event]:Fire({blockRef = {blockPosition = pos}, player = plr})
				end)
			end)
		end))
	end

	store.blocks = collection('block', vape)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, vape, function(tab, obj)
		for _, entry in tab do
			if entry.RootPart == obj then
				entry.Id = obj.Name
				entry.Shop = obj:HasTag('BedwarsItemShop')
				entry.Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
				return
			end
		end
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end, function(tab, obj)
		local active = obj:IsDescendantOf(game)
		local shop = active and obj:HasTag('BedwarsItemShop')
		local upgrades = active and obj:HasTag('TeamUpgradeShopkeeper')
		for i = #tab, 1, -1 do
			local entry = tab[i]
			if entry.RootPart == obj then
				if shop or upgrades then
					entry.Shop = shop
					entry.Upgrades = upgrades
				else
					table.remove(tab, i)
				end
				break
			end
		end
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, vape, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)

	task.delay(1, function()
		games:Increment()
	end)

	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			store.map = waitForChildYield(workspace, 9e9, 'Map', 'Worlds'):GetChildren()[1]
			mapname = store.map.Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
			if store.map then
				vape:Clean(store.map.Blocks.ChildAdded:Connect(function(v) 
					task.delay(0, function()
						if v:GetAttribute('Block') and (v:GetAttribute('PlacedByUserId') or 0) ~= 0 then
							local data = {
								blockRef = {
									blockPosition = v.Position / 3,
								},
								player = playersService:GetPlayerByUserId(v:GetAttribute('PlacedByUserId')),
							}
							for i, v in cache do
								if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
									table.clear(v[3])
									table.clear(v)
									cache[i] = nil
								end
							end
							vapeEvents.PlaceBlockEvent:Fire(data)
						end
					end)
				end))
			end
		end)
	end)

	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	pcall(function()
		bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
		bedwars.ShopItems = bedwars.Shop.ShopItems
		bedwars.Shop.getShopItem('iron_sword', lplr)
		store.shopLoaded = true
	end)

	vape:Clean(function()
		Client.Get = OldGet
		bedwars.BlockController.isBlockBreakable = OldBreak
		store.blockPlacer:disable()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, v in cache do
			table.clear(v[3])
			table.clear(v)
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(bedwars)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		storeChanged:disconnect()
		storeChanged = nil

		if entitylib.Connections then
			for _, conn in ipairs(entitylib.Connections) do
				if conn and type(conn) == "userdata" and conn.Connected then
					conn:Disconnect()
				end
			end
			table.clear(entitylib.Connections)
		end

		if entitylib.PlayerConnections then
			for _, plrConns in pairs(entitylib.PlayerConnections) do
				if type(plrConns) == "table" then
					for _, conn in ipairs(plrConns) do
						if conn and type(conn) == "userdata" and conn.Connected then
							conn:Disconnect()
						end
					end
				end
			end
			table.clear(entitylib.PlayerConnections)
		end

		if entitylib.EntityThreads then
			for char, thread in pairs(entitylib.EntityThreads) do
				if thread and task.cancel then
					task.cancel(thread)
				end
			end
			table.clear(entitylib.EntityThreads)
		end

		if entitylib.List then
			for _, ent in ipairs(entitylib.List) do
				if ent.Connections then
					for _, conn in ipairs(ent.Connections) do
						if conn and type(conn) == "userdata" and conn.Connected then
							conn:Disconnect()
						end
					end
					table.clear(ent.Connections)
				end
			end
			table.clear(entitylib.List)
		end
		if entitylib.stop then
			entitylib.stop()
		end
		for playerId, data in pairs(lagConnections) do
			if data and data.connection then
				pcall(function() data.connection:Disconnect() end)
			end
		end
		table.clear(lagConnections)
	end)
end)

for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'MouseTP', 'MurderMystery', 'NameTags', 'Killaura', 'AimAssist', 'AutoClicker', 'Reach', 'AntiFall', 'Fly', 'HitBoxes', 'LongJump', 'Speed', 'Swim', 'PlayerModel', 'Search', 'Waypoints', 'Blink', 'StaffDetector', ''} do
	vape:Remove(v)
end

local Fly
local LongJump

local kitImageIds = {
	['none'] = "rbxassetid://16493320215",
	["random"] = "rbxassetid://79773209697352",
	["cowgirl"] = "rbxassetid://9155462968",
	["davey"] = "rbxassetid://9155464612",
	["warlock"] = "rbxassetid://15186338366",
	["ember"] = "rbxassetid://9630017904",
	["black_market_trader"] = "rbxassetid://18922642482",
	["yeti"] = "rbxassetid://9166205917",
	["scarab"] = "rbxassetid://137137517627492",
	["defender"] = "rbxassetid://131690429591874",
	["cactus"] = "rbxassetid://104436517801089",
	["oasis"] = "rbxassetid://120283205213823",
	["berserker"] = "rbxassetid://90258047545241",
	["sword_shield"] = "rbxassetid://131690429591874",
	["airbender"] = "rbxassetid://74712750354593",
	["gun_blade"] = "rbxassetid://138231219644853",
	["frost_hammer_kit"] = "rbxassetid://11838567073",
	["spider_queen"] = "rbxassetid://95237509752482",
	["archer"] = "rbxassetid://9224796984",
	["axolotl"] = "rbxassetid://9155466713",
	["baker"] = "rbxassetid://9155463919",
	["barbarian"] = "rbxassetid://9166207628",
	["builder"] = "rbxassetid://9155463708",
	["necromancer"] = "rbxassetid://11343458097",
	["cyber"] = "rbxassetid://9507126891",
	["sorcerer"] = "rbxassetid://97940108361528",
	["bigman"] = "rbxassetid://9155467211",
	["spirit_assassin"] = "rbxassetid://10406002412",
	["farmer_cletus"] = "rbxassetid://9155466936",
	["ice_queen"] = "rbxassetid://9155466204",
	["grim_reaper"] = "rbxassetid://9155467410",
	["spirit_gardener"] = "rbxassetid://132108376114488",
	["hannah"] = "rbxassetid://10726577232",
	["shielder"] = "rbxassetid://9155464114",
	["summoner"] = "rbxassetid://18922378956",
	["glacial_skater"] = "rbxassetid://84628060516931",
	["dragon_sword"] = "rbxassetid://16215630104",
	["lumen"] = "rbxassetid://9630018371",
	["flower_bee"] = "rbxassetid://101569742252812",
	["jellyfish"] = "rbxassetid://18129974852",
	["melody"] = "rbxassetid://9155464915",
	["mimic"] = "rbxassetid://14783283296",
	["miner"] = "rbxassetid://9166208461",
	["nazar"] = "rbxassetid://18926951849",
	["seahorse"] = "rbxassetid://11902552560",
	["elk_master"] = "rbxassetid://15714972287",
	["rebellion_leader"] = "rbxassetid://18926409564",
	["void_hunter"] = "rbxassetid://122370766273698",
	["taliyah"] = "rbxassetid://13989437601",
	["angel"] = "rbxassetid://9166208240",
	["harpoon"] = "rbxassetid://18250634847",
	["void_walker"] = "rbxassetid://78915127961078",
	["spirit_summoner"] = "rbxassetid://95760990786863",
	["triple_shot"] = "rbxassetid://9166208149",
	["void_knight"] = "rbxassetid://73636326782144",
	["regent"] = "rbxassetid://9166208904",
	["vulcan"] = "rbxassetid://9155465543",
	["owl"] = "rbxassetid://12509401147",
	["dasher"] = "rbxassetid://9155467645",
	["disruptor"] = "rbxassetid://11596993583",
	["wizard"] = "rbxassetid://13353923546",
	["aery"] = "rbxassetid://9155463221",
	["agni"] = "rbxassetid://17024640133",
	["alchemist"] = "rbxassetid://9155462512",
	["spearman"] = "rbxassetid://9166207341",
	["beekeeper"] = "rbxassetid://9312831285",
	["falconer"] = "rbxassetid://17022941869",
	["bounty_hunter"] = "rbxassetid://9166208649",
	["blood_assassin"] = "rbxassetid://12520290159",
	["battery"] = "rbxassetid://10159166528",
	["steam_engineer"] = "rbxassetid://15380413567",
	["vesta"] = "rbxassetid://9568930198",
	["beast"] = "rbxassetid://9155465124",
	["dino_tamer"] = "rbxassetid://9872357009",
	["drill"] = "rbxassetid://12955100280",
	["elektra"] = "rbxassetid://13841413050",
	["fisherman"] = "rbxassetid://9166208359",
	["queen_bee"] = "rbxassetid://12671498918",
	["card"] = "rbxassetid://13841410580",
	["frosty"] = "rbxassetid://9166208762",
	["gingerbread_man"] = "rbxassetid://9155464364",
	["ghost_catcher"] = "rbxassetid://9224802656",
	["tinker"] = "rbxassetid://17025762404",
	["ignis"] = "rbxassetid://13835258938",
	["oil_man"] = "rbxassetid://9166206259",
	["jade"] = "rbxassetid://9166306816",
	["dragon_slayer"] = "rbxassetid://10982192175",
	["paladin"] = "rbxassetid://11202785737",
	["pinata"] = "rbxassetid://10011261147",
	["merchant"] = "rbxassetid://9872356790",
	["metal_detector"] = "rbxassetid://9378298061",
	["slime_tamer"] = "rbxassetid://15379766168",
	["nyoka"] = "rbxassetid://17022941410",
	["midnight"] = "rbxassetid://9155462763",
	["pyro"] = "rbxassetid://9155464770",
	["raven"] = "rbxassetid://9166206554",
	["santa"] = "rbxassetid://9166206101",
	["sheep_herder"] = "rbxassetid://9155465730",
	["smoke"] = "rbxassetid://9155462247",
	["spirit_catcher"] = "rbxassetid://9166207943",
	["star_collector"] = "rbxassetid://9872356516",
	["styx"] = "rbxassetid://17014536631",
	["block_kicker"] = "rbxassetid://15382536098",
	["trapper"] = "rbxassetid://9166206875",
	["hatter"] = "rbxassetid://12509388633",
	["ninja"] = "rbxassetid://15517037848",
	["jailor"] = "rbxassetid://11664116980",
	["warrior"] = "rbxassetid://9166207008",
	["mage"] = "rbxassetid://10982191792",
	["void_dragon"] = "rbxassetid://10982192753",
	["cat"] = "rbxassetid://15350740470",
	["wind_walker"] = "rbxassetid://9872355499",
	['skeleton'] = "rbxassetid://120123419412119",
	['winter_lady'] = "rbxassetid://83274578564074",
	['soul_broker'] = 'rbxassetid://130409166262430'
}

local function isFirstPerson()
    if not (lplr.Character and lplr.Character:FindFirstChild("Head")) then
        return false
    end
    return (lplr.Character.Head.Position - gameCamera.CFrame.Position).Magnitude < 2
end

local function isFrozen(entity, threshold)
    threshold = threshold or 10
    local char
    if type(entity) == "table" and entity.Character then
        char = entity.Character
    elseif type(entity) == "Instance" and entity:IsA("Model") then
        char = entity
    elseif entity == nil then
        if not entitylib.isAlive then return false end
        char = entitylib.character.Character
    else
        return false
    end

    local stacks = char:GetAttribute("ColdStacks") or char:GetAttribute("FrostStacks")
               or char:GetAttribute("FreezeStacks") or char:GetAttribute("FROZEN_STACKS")
    if stacks and stacks >= threshold then return true end

    local statusEffects = char:GetAttribute("StatusEffects")
    if type(statusEffects) == "table" then
        for effectName, stackCount in pairs(statusEffects) do
            local nameLower = tostring(effectName):lower()
            if nameLower:match("cold") or nameLower:match("frost") or nameLower:match("freeze") then
                if type(stackCount) == "number" then
                    if stackCount >= threshold then return true end
                elseif stackCount then
                    return true
                end
            end
        end
    end

    if char:FindFirstChild("IceBlock") or char:FindFirstChild("FrozenBlock") or char:FindFirstChild("IceShell") then
        return true
    end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.WalkSpeed <= 2 then
        return true
    end

    return false
end

local sharedRaycast = RaycastParams.new()
sharedRaycast.FilterType = Enum.RaycastFilterType.Include
sharedRaycast.FilterDescendantsInstances = {workspace:FindFirstChild('Map') or workspace}

local function cloneRaycast()
    local r = RaycastParams.new()
    r.FilterType = sharedRaycast.FilterType
    r.FilterDescendantsInstances = sharedRaycast.FilterDescendantsInstances
    r.RespectCanCollide = sharedRaycast.RespectCanCollide
    return r
end

local function isSword()
    return store.hand and store.hand.toolType == 'sword'
end

local function hasValidWeapon()
    if not store.hand or not store.hand.tool then return false end
    local toolType = store.hand.toolType
    local toolName = store.hand.tool.Name:lower()
    if toolName:find('headhunter') then return true end
    return toolType == 'sword' or toolType == 'bow' or toolType == 'crossbow'
end

local function fixPosition(pos)
    if bedwars and bedwars.BlockController and bedwars.BlockController.getBlockPosition then
        return bedwars.BlockController:getBlockPosition(pos) * 3
    end
    return pos * 3
end

local function getAmmoForProjectile(check)
    for _, item in store.inventory.inventory.items do
        if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
            return item.itemType
        end
    end
end

local function getProjectileItems(ammoFilter)
    local items = {}
    for _, item in store.inventory.inventory.items do
        local _itemMeta = bedwars.ItemMeta[item.itemType]
        local proj = _itemMeta and _itemMeta.projectileSource
        local ammo = proj and getAmmoForProjectile(proj)
        if ammo and table.find(ammoFilter, ammo) then
            table.insert(items, {item, ammo, proj.projectileType(ammo), proj})
        end
    end
    return items
end

local function isHoldingItem(keywords, includeProjectileSource)
    if not store.hand or not store.hand.tool then return false end
    local toolName = store.hand.tool.Name:lower()
    for _, kw in ipairs(keywords) do
        if toolName:find(kw) then return true end
    end
    if includeProjectileSource then
        return bedwars.ItemMeta[toolName] and bedwars.ItemMeta[toolName].projectileSource and true or false
    end
    return false
end

local function isHoldingBowCrossbow(includeProjectileSource)
    return isHoldingItem({'bow', 'crossbow', 'headhunter'}, includeProjectileSource)
end

local function isHoldingPickaxe()
    return isHoldingItem({'pickaxe'})
end

local function isEnemy(ent)
    if not ent then return false end
    if ent.Character and ent.Character:HasTag('petrified-player') then return false end
    if ent.Player then
        local myTeam = lplr:GetAttribute('Team')
        local theirTeam = ent.Player:GetAttribute('Team')
        if not myTeam or not theirTeam or myTeam == theirTeam then return false end
        return true
    elseif ent.NPC then
        local npcTeam = ent.Character:GetAttribute('Team')
        if npcTeam then return lplr:GetAttribute('Team') ~= npcTeam end
        return true
    end
    return false
end

local function getShopNPC()
    local shop, items, upgrades, newid = nil, false, false, nil
    if entitylib.isAlive then
        local localPosition = entitylib.character.RootPart.Position
        for _, v in store.shop do
            if (v.RootPart.Position - localPosition).Magnitude <= 20 then
                shop = v.Upgrades or v.Shop or nil
                upgrades = upgrades or v.Upgrades
                items = items or v.Shop
                newid = v.Shop and v.Id or newid
            end
        end
    end
    return shop, items, upgrades, newid
end

local function isTeammate(player)
    if not lplr or not player then return false end
    local myTeam = lplr:GetAttribute('Team')
    local theirTeam = player:GetAttribute('Team')
    return myTeam and theirTeam and myTeam == theirTeam
end

local function getPlayerName(player, useDisplayName)
    if not player then return '' end
    return (useDisplayName and player.DisplayName ~= "" and player.DisplayName) or player.Name
end

local armorTiers = {'none','leather_chestplate','iron_chestplate','diamond_chestplate','emerald_chestplate'}
local function getArmorTier(player)
    if not player or not store.inventories[player] then return 0 end
    local chest = store.inventories[player].armor and store.inventories[player].armor[5]
    if not chest or chest == 'empty' then return 1 end
    return table.find(armorTiers, chest.itemType) or 1
end

local function checkFaceAdjacent(pos, faces)
    faces = faces or {
        Vector3.new(3,0,0), Vector3.new(-3,0,0), Vector3.new(0,3,0),
        Vector3.new(0,-3,0), Vector3.new(0,0,3), Vector3.new(0,0,-3)
    }
    for _, v in ipairs(faces) do
        if getPlacedBlock(pos + v) then return true end
    end
    return false
end

local _isAboveVoidParams = RaycastParams.new()
_isAboveVoidParams.FilterType = Enum.RaycastFilterType.Exclude
local function isAboveVoid(position)
    if not entitylib.isAlive or not entitylib.character then return false end
    _isAboveVoidParams.FilterDescendantsInstances = {entitylib.character.Character}
    local result = workspace:Raycast(position, Vector3.new(0, -500, 0), _isAboveVoidParams)
    return result == nil
end

local function hasFaceBelowOrSide(pos)
    if getPlacedBlock(pos - Vector3.new(0,3,0)) then return true end
    local sides = {Vector3.new(3,0,0), Vector3.new(-3,0,0), Vector3.new(0,0,3), Vector3.new(0,0,-3)}
    for _, v in ipairs(sides) do
        if getPlacedBlock(pos + v) then return true end
    end
    return false
end

local function nearCorner(poscheck, pos)
    local start = poscheck - Vector3.new(3,3,3)
    local fin = poscheck + Vector3.new(3,3,3)
    local dir = (pos - poscheck).Unit * 100
    local check = poscheck + dir
    return Vector3.new(
        math.clamp(check.X, start.X, fin.X),
        math.clamp(check.Y, start.Y, fin.Y),
        math.clamp(check.Z, start.Z, fin.Z)
    )
end

local function blockProximity(pos, rangeBlocks)
    rangeBlocks = rangeBlocks or 21
    local mag, best = 60, nil
    local blocks = getBlocksInPoints(
        bedwars.BlockController:getBlockPosition(pos - Vector3.new(rangeBlocks,rangeBlocks,rangeBlocks)),
        bedwars.BlockController:getBlockPosition(pos + Vector3.new(rangeBlocks,rangeBlocks,rangeBlocks))
    )
    for _, v in ipairs(blocks) do
        local bp = nearCorner(v, pos)
        local d = (pos - bp).Magnitude
        if hasFaceBelowOrSide(bp) and d < mag then
            mag, best = d, bp
        end
    end
    return best
end

local function isGUIOpen()
    return bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN)
        or bedwars.AppController:isLayerOpen(bedwars.UILayers.DIALOG)
        or bedwars.AppController:isLayerOpen(bedwars.UILayers.POPUP)
        or bedwars.AppController:isAppOpen('BedwarsItemShopApp')
        or (bedwars.Store:getState().Inventory and bedwars.Store:getState().Inventory.open)
end

local function isTargetValid(ent, maxDist, checkWalls)
    if not ent or not ent.RootPart or not ent.Character then return false end
    if not entitylib.isAlive then return false end
    local dist = (ent.RootPart.Position - entitylib.character.RootPart.Position).Magnitude
    if dist > maxDist then return false end
    if checkWalls then
        local ray = workspace:Raycast(
            entitylib.character.RootPart.Position,
            (ent.RootPart.Position - entitylib.character.RootPart.Position),
            sharedRaycast
        )
        if ray then return false end
    end
    local hum = ent.Character:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

local function getTargetByPriority(originPos, range, opts)
    opts = opts or {}
    local players = opts.players == nil and true or opts.players
    local npcs = opts.npcs or false
    local walls = opts.walls or false
    local sort = opts.sort or 'distance' -- 'health','armor','damage'
    local damageTracker = opts.damageTracker 

    local valid = {}
    for _, ent in ipairs(entitylib.List) do
        if (players and ent.Player) or (npcs and ent.NPC) then
            if isEnemy(ent) and ent.RootPart then
                local dist = (ent.RootPart.Position - originPos).Magnitude
                if dist <= range then
                    if walls then
                        local ray = workspace:Raycast(originPos, (ent.RootPart.Position - originPos), sharedRaycast)
                        if not ray then
                            table.insert(valid, ent)
                        end
                    else
                        table.insert(valid, ent)
                    end
                end
            end
        end
    end
    if #valid == 0 then return nil end

    if sort == 'distance' then
        table.sort(valid, function(a,b)
            return (a.RootPart.Position - originPos).Magnitude < (b.RootPart.Position - originPos).Magnitude
        end)
    elseif sort == 'damage' and damageTracker then
        table.sort(valid, function(a,b)
            local keyA = a.Player and a.Player.UserId or tostring(a)
            local keyB = b.Player and b.Player.UserId or tostring(b)
            return (damageTracker[keyA] or 0) > (damageTracker[keyB] or 0)
        end)
    elseif sort == 'health' then
        table.sort(valid, function(a,b)
            return a.Health < b.Health
        end)
    elseif sort == 'armor' then
        table.sort(valid, function(a,b)
            return getArmorTier(a.Player) < getArmorTier(b.Player)
        end)
    end
    return valid[1]
end

local isMobile = inputService.TouchEnabled and not inputService.KeyboardEnabled and not inputService.MouseEnabled

local function getTeammates(namesOnly)
    local result = {}
    local myTeam = lplr:GetAttribute('Team')
    if not myTeam then return result end
    for _, player in playersService:GetPlayers() do
        if player ~= lplr and player:GetAttribute('Team') == myTeam then
            if namesOnly then
                table.insert(result, player.Name)
            elseif player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
                table.insert(result, player)
            end
        end
    end
    if namesOnly then
        table.sort(result)
    end
    return result
end

local function getNearestTeammateInRange(range, condition)
    if not entitylib.isAlive then return nil end
    local myPos = entitylib.character.RootPart.Position
    local nearest = nil
    local nearestDist = math.huge
    for _, player in ipairs(getTeammates()) do
        if player.Character and player.Character.PrimaryPart then
            local dist = (player.Character.PrimaryPart.Position - myPos).Magnitude
            if dist <= range then
                if condition and not condition(player) then continue end
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = player
                end
            end
        end
    end
    return nearest
end

local function getPlayerHealth(player)
    if not player or not player.Character then return 0, 100 end
    local health = player.Character:GetAttribute('Health') or (player.Character:FindFirstChildOfClass('Humanoid') and player.Character.Humanoid.Health) or 0
    local maxHealth = player.Character:GetAttribute('MaxHealth') or (player.Character:FindFirstChildOfClass('Humanoid') and player.Character.Humanoid.MaxHealth) or 100
    return health, maxHealth
end

local function getPlayerHealthPercent(player)
    local health, maxHealth = getPlayerHealth(player)
    if maxHealth == 0 then return 0 end
    return (health / maxHealth) * 100
end

local function leftClick()
	pcall(function()
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
		task.wait(0.05)
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
	end)
end

local function getWorldFolder()
    local Map = workspace:FindFirstChild("Map")
    if not Map then return nil end
    local Worlds = Map:FindFirstChild("Worlds")
    if not Worlds then return nil end
    for _, world in Worlds:GetChildren() do
        return world
    end
    return nil
end

local function getPickaxeSlot()
	for i, v in store.inventory.hotbar do
		if v.item and bedwars.ItemMeta[v.item.itemType] then
			local meta = bedwars.ItemMeta[v.item.itemType]
			if meta.breakBlock then
				return i - 1
			end
		end
	end
	return nil
end

local function getScaffoldBlockForModule(limitItem)
	if limitItem.Enabled then
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name
		end
		return nil
	else
		local wool = getWool()
		if wool then
			return wool
		else
			for _, item in store.inventory.inventory.items do
				local meta = bedwars.ItemMeta[item.itemType]
				if meta and meta.block then
					return item.itemType
				end
			end
		end
	end
	return nil
end

local function safeIsBreakable(pos)
    if not bedwars.BlockController then return false end
    local ok, result = pcall(function()
        return bedwars.BlockController:isBlockBreakable({blockPosition = pos / 3}, lplr)
    end)
    return ok and result
end

local function fetchBedfromPos(bedPos)
    local offsets = {
        Vector3.new(0, 0, 1),
        Vector3.new(0, 0, -1),
        Vector3.new(1, 0, 0),
        Vector3.new(-1, 0, 0),
    }
    for _, v in next, offsets do
        local pos = bedPos + v
        local suc, res = pcall(function()
            return bedwars.BlockController:getStore():getBlockAt(pos)
        end)
        if suc and res and res.Name == "bed" then
            return pos
        end
    end
    return nil
end

--[[
	Combat Modules
]]

run(function()
    local Mode
    local Expand
    local AutoToggle
    local Visible
    local VisibleColor
    local Targets
    local objects = {}
    local set = false
    local hitboxesActive = false
    local autoToggleConnection = nil
    local autoToggleFrameCounter = 0

    local vector3new = Vector3.new
    local vector3one = Vector3.one

    local colorList = {
        Red = Color3.fromRGB(255, 0, 0),
        Blue = Color3.fromRGB(0, 100, 255),
        Green = Color3.fromRGB(0, 255, 0),
        Yellow = Color3.fromRGB(255, 255, 0),
        Orange = Color3.fromRGB(255, 140, 0),
        Purple = Color3.fromRGB(180, 0, 255),
        White = Color3.fromRGB(255, 255, 255),
        Cyan = Color3.fromRGB(0, 255, 255),
        Pink = Color3.fromRGB(255, 50, 150),
        Black = Color3.fromRGB(0, 0, 0)
    }

    local function shouldCreateHitbox(ent)
        if not ent.Targetable then return false end
        if ent.Player and Targets and Targets.Players and Targets.Players.Enabled then return true end
        if not ent.Player and Targets and Targets.NPCs and Targets.NPCs.Enabled then return true end
        return false
    end

    local _wallRayParams = RaycastParams.new()
    _wallRayParams.FilterType = Enum.RaycastFilterType.Exclude
    local function isTargetBehindWall(ent)
        if not Targets or not Targets.Walls or not Targets.Walls.Enabled then return false end
        if not ent.RootPart then return false end
        if not entitylib.isAlive or not entitylib.character or not entitylib.character.RootPart then return false end
        local origin = entitylib.character.RootPart.Position
        local target = ent.RootPart.Position
        local direction = target - origin
        _wallRayParams.FilterDescendantsInstances = {entitylib.character, ent.Character}
        local result = workspace:Raycast(origin, direction, _wallRayParams)
        if result then
            local hitDist = (result.Position - origin).Magnitude
            local targetDist = direction.Magnitude
            if hitDist < targetDist - 0.5 then return true end
        end
        return false
    end

    local cachedExpandSize = vector3new(3, 6, 3)
    local lastExpandValue = 0
    local function updateExpandSize(val)
        if val ~= lastExpandValue then
            lastExpandValue = val
            cachedExpandSize = vector3new(3, 6, 3) + vector3one * (val / 5)
        end
    end

    local function createHitbox(ent)
        if not shouldCreateHitbox(ent) then return end
        if isTargetBehindWall(ent) then return end
        if objects[ent] then return end
        for _, old in ent.Character:GetChildren() do
            if old.Name == 'AeroHitbox' then old:Destroy() end
        end                            AutoClicker:Clean(lplr.PlayerGui.MobileUI[v].MouseButton1Down:Connect(AutoClick))
                            AutoClicker:Clean(lplr.PlayerGui.MobileUI[v].MouseButton1Up:Connect(StopClick))
                        end)
                    end
                else
                    StopClick()
                end
            end,
            Tooltip = 'clicks for you'
        })

        CPS = AutoClicker:CreateTwoSlider({
            Name = 'CPS',
            Min = 1,
            Max = 9,
            DefaultMin = 7,
            DefaultMax = 7
        })

        AutoClicker:CreateToggle({
            Name = 'Place Blocks',
            Default = true,
            Function = function(callback)
                if BlockCPS.Object then
                    BlockCPS.Object.Visible = callback
                end
            end
        })

        BlockCPS = AutoClicker:CreateTwoSlider({
            Name = 'Block CPS',
            Min = 1,
            Max = 20,
            DefaultMin = 12,
            DefaultMax = 12,
            Darker = true
        })

        task.defer(function()
            if BlockCPS and BlockCPS.Object then
                BlockCPS.Object.Visible = PlaceBlocksToggle and PlaceBlocksToggle.Enabled
            end
        end)

    else
        local AutoClicker
        local CPS
        local BlockCPS = {}
        local SwordCPS = {}
        local PlaceBlocksToggle
        local SwingSwordToggle
        local Thread

        local task_wait = task.wait
        local task_spawn = task.spawn
        local workspace_GetServerTimeNow = function() return workspace:GetServerTimeNow() end

        local function getSafeCPS()
            local toolType = store.hand and store.hand.toolType or nil
            if toolType == 'block' and PlaceBlocksToggle and PlaceBlocksToggle.Enabled and BlockCPS and BlockCPS.GetRandomValue then
                return BlockCPS
            elseif toolType == 'sword' and SwingSwordToggle and SwingSwordToggle.Enabled and SwordCPS and SwordCPS.GetRandomValue then
                return SwordCPS
            elseif CPS and CPS.GetRandomValue then
                return CPS
            end
            return nil
        end

        local function AutoClickskid()
            if Thread then task.cancel(Thread) end
            Thread = task_spawn(function()
                repeat
                    if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
                        local toolType = store.hand and store.hand.toolType
                        if PlaceBlocksToggle.Enabled and toolType == 'block' then
                            local blockPlacer = bedwars.BlockPlacementController and bedwars.BlockPlacementController.blockPlacer
                            if blockPlacer then
                                if (workspace_GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
                                    local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
                                    if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
                                        task_spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
                                    end
                                end
                            end
                        elseif SwingSwordToggle.Enabled and toolType == 'sword' then
                            bedwars.SwordController:swingSwordAtMouse(0.39)
                        end
                    end

                    local currentCPS = getSafeCPS()
                    task_wait(1 / (currentCPS and currentCPS.GetRandomValue() or 7))
                until not AutoClicker.Enabled
            end)
        end

        local function StopAutoClick()
            if Thread then
                task.cancel(Thread)
                Thread = nil
            end
        end

        local MIN_HOLD_TIME = 0.12
        local ActivationScheduled = nil

        AutoClicker = vape.Categories.Combat:CreateModule({
            Name = 'AutoClicker',
            Function = function(callback)
                if callback then
                    AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            ActivationScheduled = task.delay(MIN_HOLD_TIME, function()
                                ActivationScheduled = nil
                                if inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                                    AutoClickskid()
                                end
                            end)
                        end
                    end))
                    AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            if ActivationScheduled then
                                task.cancel(ActivationScheduled)
                                ActivationScheduled = nil
                            end
                            if Thread then
                                task.cancel(Thread)
                                Thread = nil
                            end
                        end
                    end))
                else
                    StopAutoClick()
                end
            end,
            Tooltip = 'clicks for you'
        })

        PlaceBlocksToggle = AutoClicker:CreateToggle({
            Name = 'Place Blocks',
            Default = false,
            Function = function(callback)
                task.defer(function()
                    if BlockCPS and BlockCPS.Object then BlockCPS.Object.Visible = callback end
                end)
            end
        })

        BlockCPS = AutoClicker:CreateTwoSlider({
            Name = 'Block CPS',
            Min = 1,
            Max = 20,
            DefaultMin = 12,
            DefaultMax = 12,
            Darker = true
        })

        SwingSwordToggle = AutoClicker:CreateToggle({
            Name = 'Swing Sword',
            Default = false,
            Function = function(callback)
                if SwordCPS.Object then SwordCPS.Object.Visible = callback end
            end
        })

        SwordCPS = AutoClicker:CreateTwoSlider({
            Name = 'Sword CPS',
            Min = 1,
            Max = 9,
            DefaultMin = 7,
            DefaultMax = 7,
            Darker = true
        })

        task.defer(function()
            if BlockCPS and BlockCPS.Object then
                BlockCPS.Object.Visible = PlaceBlocksToggle and PlaceBlocksToggle.Enabled
            end
            if SwordCPS and SwordCPS.Object then
                SwordCPS.Object.Visible = SwingSwordToggle and SwingSwordToggle.Enabled
            end
        end)
    end
end)  
	
run(function()
	local Attack
	local Mine
	local Place
	local oldAttackReach, oldMineReach, oldPlaceReach
	local oldRegionTarget
	local SwordReach, MineReach
	local AirReach, AirReachChance
	local airReachState = false
	local airReachRolled = false
	local _airReachThread

	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			if callback then
				if bedwars.SwordController and not oldRegionTarget then
					oldRegionTarget = bedwars.SwordController.getTargetInRegion
					bedwars.SwordController.getTargetInRegion = function(self, range, ...)
						local cur = bedwars.CombatConstant and bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE
						if SwordReach.Enabled and type(range) == 'number' and cur and cur > (oldAttackReach or 14.4) then
							range = math.max(range, cur - 2)
						end
						return oldRegionTarget(self, range, ...)
					end
				end
				if SwordReach and SwordReach.Enabled then
					task.spawn(function()
						repeat task.wait(0.1) until (bedwars.CombatConstant and bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE) or not Reach.Enabled
						if not Reach.Enabled or not SwordReach.Enabled then return end
						oldAttackReach = bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE
						bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
					end)
				end
				
				task.spawn(function()
					repeat task.wait(0.1) until bedwars.BlockBreakController or not Reach.Enabled
					if not Reach.Enabled or not MineReach or not MineReach.Enabled then return end
					
					pcall(function()
						local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
						if blockBreaker then
							oldMineReach = oldMineReach or blockBreaker:getRange()
							blockBreaker:setRange(Mine.Value)
						end
					end)
				end)
				
				local _reachLoopThread = task.spawn(function()
					while Reach.Enabled do
						task.wait(5)
						if not Reach.Enabled then break end
						if SwordReach.Enabled and not (AirReach and AirReach.Enabled) and bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE ~= Attack.Value + 2 then
							bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
						end
						if MineReach.Enabled then
							pcall(function()
								local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
								if blockBreaker and blockBreaker:getRange() ~= Mine.Value then
									blockBreaker:setRange(Mine.Value)
								end
							end)
						end
					end
				end)
				airReachRolled = false
				_airReachThread = task.spawn(function()
					while Reach.Enabled do
						task.wait(0.05)
						if not Reach.Enabled then break end
						if not AirReach or not AirReach.Enabled or not SwordReach.Enabled then
							airReachRolled = false
						else
							local ent = store.KillauraTarget
							local tchar = ent and ent.Character
							local hum = tchar and tchar:FindFirstChildOfClass('Humanoid')
							local inAir = false
							if hum then
								inAir = hum.FloorMaterial == Enum.Material.Air
								if not inAir then
									local st = hum:GetState()
									inAir = st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall
								end
								if not inAir then
									local root = tchar.PrimaryPart
									local vy = root and root.AssemblyLinearVelocity.Y or 0
									inAir = math.abs(vy) > 3
								end
							end
							if not inAir then
								airReachRolled = false
								bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
							else
								if not airReachRolled then
									airReachRolled = true
									airReachState = math.random(1, 100) <= AirReachChance.Value
								end
								bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = airReachState and (Attack.Value + 2) or (oldAttackReach or 14.4)
							end
						end
					end
				end)
				Reach:Clean(function()
					if _airReachThread then
						pcall(task.cancel, _airReachThread)
						_airReachThread = nil
					end
					airReachRolled = false
				end)
				Reach:Clean(function()
					if _reachLoopThread then
						pcall(task.cancel, _reachLoopThread)
						_reachLoopThread = nil
					end
				end)
			else
				if oldRegionTarget then
					bedwars.SwordController.getTargetInRegion = oldRegionTarget
					oldRegionTarget = nil
				end
				if oldAttackReach then
					bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = oldAttackReach
				end
				
				if oldMineReach then
					pcall(function()
						local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
						if blockBreaker then
							blockBreaker:setRange(oldMineReach)
						end
					end)
				end

				oldAttackReach, oldMineReach = nil, nil
			end
		end,
		Tooltip = 'increases reach for attacking, mining'
	})
	
	SwordReach = Reach:CreateToggle({
		Name = 'Sword Reach',
		Default = true,
		Function = function(v)
			if Attack then Attack.Object.Visible = v end
			if Reach.Enabled then
				if v then
					bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
				else
					bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = oldAttackReach or 14.4
				end
			end
		end
	})

	Attack = Reach:CreateSlider({
		Name = 'Attack Range',
		Darker = true,
		Visible = true,
		Min = 0,
		Max = 20,
		Default = 18,
		Function = function(val)
			if Reach.Enabled then
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = val + 2
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	
	AirReach = Reach:CreateToggle({
		Name = 'Air Reach',
		Default = false,
		Tooltip = 'puts ur reach back to normal when they in the air so it looks legit',
		Function = function(v)
			if AirReachChance then AirReachChance.Object.Visible = v end
			if not v and Reach.Enabled and SwordReach and SwordReach.Enabled then
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
			end
		end
	})

	AirReachChance = Reach:CreateSlider({
		Name = 'Air Reach Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Suffix = '%',
		Darker = true,
		Visible = false,
		Tooltip = 'how often u still get reach while they jumpin'
	})

	MineReach = Reach:CreateToggle({
		Name = 'Mine Reach',
		Default = false,
		Function = function(v)
			if Mine then Mine.Object.Visible = v end
		end
	})

	Mine = Reach:CreateSlider({
		Name = 'Mine Range',
		Darker = true,
		Visible = false,
		Min = 0,
		Max = 30,
		Default = 18,
		Function = function(val)
			if Reach.Enabled then
				pcall(function()
					local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
					if blockBreaker then
						blockBreaker:setRange(val)
					end
				end)
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local Sprint
	local old
	local sprintSession = 0
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback ~= Sprint.Enabled then return end
			sprintSession = sprintSession + 1
			local session = sprintSession
			local controller = bedwars.SprintController
			if callback then
				if inputService.TouchEnabled then 
					pcall(function() 
						lplr.PlayerGui.MobileUI['4'].Visible = false 
					end) 
				end
				if not old then
					old = controller.stopSprinting
					controller.stopSprinting = function(self, ...)
						if Sprint.Enabled and entitylib.isAlive then return end
						return old(self, ...)
					end
				end
				task.spawn(function()
					while Sprint.Enabled and sprintSession == session do
						if entitylib.isAlive then
							pcall(function()
								if not controller:isSprinting() then
									controller:startSprinting()
								end
							end)
						end
						task.wait(0.12)
					end
				end)
			else
				if inputService.TouchEnabled then 
					pcall(function() 
						lplr.PlayerGui.MobileUI['4'].Visible = true 
					end) 
				end
				if old then
					controller.stopSprinting = old
					old = nil
					controller:stopSprinting()
				end
			end
		end,
	})
end)
	
run(function()
	local TriggerBot
	local CPS

	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				repeat
					local swung = false
					local hand = store.hand
					if entitylib.isAlive
						and hand and hand.tool and hand.toolType == 'sword'
						and not (bedwars.DaoController and bedwars.DaoController.chargingMaid)
						and not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
						local meta = bedwars.ItemMeta[hand.tool.Name]
						local range = meta and meta.sword and meta.sword.attackRange or 14.4
						local near = entitylib.EntityPosition({
							Range = range,
							Part = 'RootPart',
							Players = true,
							NPCs = true
						})
						if near then
							bedwars.SwordController:swingSwordAtMouse()
							swung = true
						end
					end
					task.wait(swung and 1 / CPS.GetRandomValue() or 0.05)
				until not TriggerBot.Enabled
			end
		end,
		Tooltip = 'swings ur sword on its own when someone is close'
	})

	CPS = TriggerBot:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
end)

run(function()
	local Velocity
	local Vertical
	local Horizontal
	local Mode
	local DelayGround
	local DelayAir
	local Targetting
	local Chance
	local KiteMode
	local KiteHorizontal
	local KiteVertical
	local AlwaysKite
	local old = nil
	local rand = Random.new()

	local function hitterPosition(hitFrom)
		local ok, ids = pcall(function()
			return bedwars.KnockbackController.recentlyReceivedKnockback:getValues()
		end)
		if ok and type(ids) == 'table' then
			for i = #ids, 1, -1 do
				local plr = playersService:GetPlayerByUserId(ids[i])
				local char = plr and plr.Character
				local part = char and char.PrimaryPart
				if part then
					return part.Position
				end
			end
		end
		return typeof(hitFrom) == 'Vector3' and hitFrom or nil
	end

	local function kiting(root, hitFrom)
		if not KiteMode.Enabled then return false end
		if AlwaysKite.Enabled then return true end
		if not root then return false end
		local from = hitterPosition(hitFrom)
		if not from or (from - root.Position).Magnitude > 20 then return false end
		local toHitter = (from - root.Position) * Vector3.new(1, 0, 1)
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if toHitter.Magnitude < 0.5 or look.Magnitude < 0.01 then return false end
		return look.Unit:Dot(toHitter.Unit) < -0.2
	end

	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Tooltip = 'control you to edit ur knockback',
		Function = function(callback)
			if callback then
				old = bedwars.KnockbackUtil.applyKnockback
				Velocity:Clean(vapeEvents.TakeKnockback.Event:Connect(function(root, mass, dir, knockback, ...)
					local args = {...}
					local clone = table.clone(knockback)

					local air, ground = false, false
					task.delay(DelayAir.Value / 1000, function()
						clone.horizontal = knockback.horizontal or 1
						air = true
					end)
					task.delay(DelayGround.Value / 1000, function()
						clone.vertical = knockback.vertical or 1
						ground = true
					end)
					repeat task.wait(0.1) until air
					repeat task.wait(0.05) until ground
					old(root, mass, dir, clone, unpack(args))
				end))

				bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
					local check = (not Targetting.Enabled) or entitylib.EntityPosition({
						Range = 50,
						Part = 'RootPart',
						Players = true
					})

					if check and kiting(root, dir) then
						local boosted = table.clone(knockback or {})
						boosted.horizontal = (boosted.horizontal or 1) * (KiteHorizontal.Value / 100)
						boosted.vertical = (boosted.vertical or 1) * (KiteVertical.Value / 100)
						return old(root, mass, dir, boosted, ...)
					end

					local chance = rand:NextNumber(0, 100)
					chance = math.floor(chance)
					if Mode.Value == 'Default' then
						if chance >= Chance.Value then return old(root, mass, dir, knockback, ...) end
					end

					if check then
						knockback = knockback or {}
						if Mode.Value == 'Lag' then
							if chance < Chance.Value then
								return vapeEvents.TakeKnockback:Fire(root, mass, dir, knockback, ...)
							end
						else
							if Horizontal.Value == 0 and Vertical.Value == 0 then return end
							knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
							knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
						end
					end

					return old(root, mass, dir, knockback, ...)
				end
			else
				bedwars.KnockbackUtil.applyKnockback = old
				old = nil
			end
		end
	})
	Mode = Velocity:CreateDropdown({
		Name = "Mode",
		List = {'Lag','Default'},
		Function = function(val)
			local isDefault = val == 'Default'
			if Horizontal then Horizontal.Object.Visible = isDefault end
			if Vertical then Vertical.Object.Visible = isDefault end
			if DelayGround then DelayGround.Object.Visible = not isDefault end
			if DelayAir then DelayAir.Object.Visible = not isDefault end
		end
	})
	Vertical = Velocity:CreateSlider({
		Name = "Vertical",
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 1,
		Visible = (Mode.Value == 'Default')
	})
	Horizontal = Velocity:CreateSlider({
		Name = "Horizontal",
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 1,
		Visible = (Mode.Value == 'Default')
	})
	DelayGround = Velocity:CreateSlider({
		Name = "Delay Ground",
		Min = 0,
		Max = 3000,
		Default = 1000,
		Suffix = 'ms',
		Decimal = 1,
		Visible = (Mode.Value == 'Lag')
	})
	DelayAir = Velocity:CreateSlider({
		Name = "Delay Air",
		Min = 0,
		Max = 3000,
		Default = 1000,
		Suffix = 'ms',
		Decimal = 1,
		Visible = (Mode.Value == 'Lag')
	})
	Targetting = Velocity:CreateToggle({
		Name = 'Only when targetting',
		Default = false
	})
	Chance = Velocity:CreateSlider({
		Name = "Chance",
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 1,
		Suffix = '%',
		Tooltip = 'how often it actually changes ur knockback, 100 means every hit'
	})
	KiteMode = Velocity:CreateToggle({
		Name = 'Kite Mode',
		Tooltip = 'boosts ur knockback when ur not facing them so u fly further away when runnin',
		Function = function(callback)
			if KiteHorizontal then KiteHorizontal.Object.Visible = callback end
			if KiteVertical then KiteVertical.Object.Visible = callback end
			if AlwaysKite then AlwaysKite.Object.Visible = callback end
		end
	})
	KiteHorizontal = Velocity:CreateSlider({
		Name = 'Kite Horizontal',
		Min = 100,
		Max = 200,
		Default = 120,
		Suffix = '%',
		Darker = true,
		Visible = false
	})
	KiteVertical = Velocity:CreateSlider({
		Name = 'Kite Vertical',
		Min = 100,
		Max = 200,
		Default = 120,
		Suffix = '%',
		Darker = true,
		Visible = false
	})
	AlwaysKite = Velocity:CreateToggle({
		Name = 'Always Kite',
		Tooltip = 'boosts ur knockback on every hit even when ur facin them',
		Darker = true,
		Visible = false
	})
end)

--[[
	Blatant Modules
]]

run(function()
	local PlayerAttachModule
	local RangeSlider
	local HeightSlider
	local attachRay = RaycastParams.new()
	local lastGroundTime = tick()

	local function isValidTarget(ent)
		if not ent or not ent.Targetable or not ent.RootPart or not ent.Humanoid then
			return false
		end
		if ent.Humanoid.Health <= 0 then
			return false
		end
		if ent.Player then
			if entitylib.isFriend and entitylib.isFriend(ent.Player) then
				return false
			end
			local myPlayer = game:GetService("Players").LocalPlayer
			if myPlayer and myPlayer.Team and ent.Player.Team and myPlayer.Team == ent.Player.Team then
				return false
			end
		end
		return true
	end

	local function getTarget(myRoot)
		local closestTarget = nil
		local closestDist = RangeSlider.Value
		for _, ent in ipairs(entitylib.List) do
			if isValidTarget(ent) then
				local dist = (ent.RootPart.Position - myRoot.Position).Magnitude
				if dist <= closestDist then
					closestDist = dist
					closestTarget = ent
				end
			end
		end
		return closestTarget
	end

	PlayerAttachModule = vape.Categories.Blatant:CreateModule({
		Name = 'PlayerAttach',
		Function = function(callback)
			frictionTable.PlayerAttach = callback or nil
			if callback then
				local tpTick, tpToggle, oldy = tick(), true
				lastGroundTime = tick()

				PlayerAttachModule:Clean(runService.PreSimulation:Connect(function(dt)
					if not entitylib.isAlive then return end
					local root = entitylib.character.RootPart
					if not root or not isnetworkowner(root) then return end

					local target = getTarget(root)
					if not target then
						lastGroundTime = tick()
						tpToggle = true
						oldy = nil
						return
					end

					local now = tick()
					local humanoid = entitylib.character.Humanoid
					if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
						lastGroundTime = now
					end
					local airTime = now - lastGroundTime

					local oscillation = (now % 0.4 < 0.2) and -1 or 1
					local mass = 1.95 + (6 * oscillation)

					local goalPos = target.RootPart.Position + Vector3.new(0, HeightSlider.Value, 0)

					if tpToggle then
						if airTime > 2 and not oldy then
							attachRay.FilterDescendantsInstances = {lplr.Character, gameCamera}
							attachRay.CollisionGroup = root.CollisionGroup
							local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), attachRay)
							if ray then
								tpToggle = false
								oldy = HeightSlider.Value
								tpTick = now + 0.11
								root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
								root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
								return
							end
						end
						root.CFrame = CFrame.lookAlong(goalPos, root.CFrame.LookVector)
					else
						if oldy then
							if tpTick < now then
								root.CFrame = CFrame.lookAlong(goalPos, root.CFrame.LookVector)
								tpToggle = true
								oldy = nil
								lastGroundTime = now
							else
								return
							end
						end
					end

					root.AssemblyLinearVelocity = Vector3.new(0, mass, 0)
				end))
			else
				if entitylib.isAlive and entitylib.character and entitylib.character.RootPart then
					entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.zero
					entitylib.character.RootPart.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end,
		Tooltip = 'sticks u right above whoever u fightin so u can stay on em the whole time gng'
	})

	RangeSlider = PlayerAttachModule:CreateSlider({
		Name = 'Range',
		Min = 5,
		Max = 30,
		Default = 20,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end
	})

	HeightSlider = PlayerAttachModule:CreateSlider({
		Name = 'Height',
		Min = 0,
		Max = 20,
		Default = 10,
		Decimal = 10,
		Suffix = 'studs',
		Tooltip = 'how high above em u sit'
	})
end)

local function watchTargets()
	return runService.Heartbeat:Connect(function()
		if not entitylib.isAlive or not prediction.Observe then return end
		local here = entitylib.character.RootPart.Position
		for _, ent in entitylib.List do
			local root = ent.RootPart
			if root and root.Parent and (root.Position - here).Magnitude < 250 then
				local vel = root.AssemblyLinearVelocity
				local air = (ent.Humanoid and ent.Humanoid.FloorMaterial == Enum.Material.Air) or math.abs(vel.Y) > 0.01
				pcall(prediction.Observe, root, root.Position, vel, air, workspace.Gravity, here, ent.HipHeight, ent.Jumping and 42.6 or nil)
			end
		end
	end)
end

run(function()
	local SilentAim
	local Targets
	local TargetPart
	local SortMethod
	local Range
	local FOV
	local SAFOVCircle
	local RandomHeadPercent
	local RandomTorsoPercent
	local OtherProjectiles
	local Blacklist
	local AutoCharge
	local skidChargePercent

	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}

	local namecall
	local namecallHooked = false
	local lockedRandomPart
	local _saVelHistory = {}
	local _saVelStamp = {}
	local fovConn

	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
		return inputService:GetMouseLocation()
	end

	local function getClosestPart(char, mousePos)
		local magnitude, part = 9e9, nil
		for _, v in char:GetChildren() do
			if v:IsA('BasePart') then
				local position, vis = gameCamera:WorldToViewportPoint(v.Position)
				if vis then
					local mag = (mousePos - Vector2.new(position.X, position.Y)).Magnitude
					if mag < magnitude then
						magnitude = mag
						part = v
					end
				end
			end
		end
		return part
	end

	local function pickRandomPart(char)
		local roll = math.random(1, 100)
		local head = char:FindFirstChild('Head')
		local torso = char:FindFirstChild('HumanoidRootPart') or char.PrimaryPart
		if head and roll <= RandomHeadPercent.Value then
			return head
		elseif torso and roll <= (RandomHeadPercent.Value + RandomTorsoPercent.Value) then
			return torso
		end
		return torso or head
	end

	local shotTool, shotProj
	local function getTargetPart(plr)
		local val = TargetPart.Value
		if val == 'Dynamic' then
			local tool = (typeof(shotTool) == 'Instance' and shotTool) or (store.hand and store.hand.tool)
			local itemType = tostring(tool and tool.Name or ''):lower()
			if (itemType:find('headhunter') or tostring(shotProj or ''):find('headhunter')) and plr.Character and plr.Character:FindFirstChild('Head') then
				return plr.Character.Head
			end
			return plr.RootPart
		elseif val == 'Head' then
			return (plr.Character and plr.Character:FindFirstChild('Head')) or plr.RootPart
		elseif val == 'Closest' then
			return (plr.Character and getClosestPart(plr.Character, getMousePosition())) or plr.RootPart
		elseif val == 'Randomize' then
			if lockedRandomPart and lockedRandomPart.Parent ~= plr.Character then
				lockedRandomPart = nil
			end
			if plr.Character and (not lockedRandomPart or not lockedRandomPart.Parent) then
				lockedRandomPart = pickRandomPart(plr.Character)
			end
			return lockedRandomPart or plr.RootPart
		end
		return plr.RootPart
	end

	local function isBlacklisted(projType)
		local key = (projType == 'glue_trap' or projType == 'glue_projectile') and 'gloop' or projType
		if Blacklist and table.find(Blacklist.ListEnabled or Blacklist.Value or {}, key) then
			return true
		end
		return false
	end

	local fovDrawing
	local function isHoldingProjectile()
		local tool = store.hand and store.hand.tool
		local itemType = tool and tool.Name or ''
		local itemMeta = bedwars.ItemMeta and bedwars.ItemMeta[itemType]
		if not (itemMeta and itemMeta.projectileSource) then return false end
		local src = itemMeta.projectileSource
		local isArrow = src.ammoItemTypes and table.find(src.ammoItemTypes, 'arrow')
		local isHeadhunter = itemType:find('headhunter')
		if isArrow or isHeadhunter then return true end
		if OtherProjectiles and OtherProjectiles.Enabled then
			local projectileType = src.projectileType and (type(src.projectileType) == 'function' and src.projectileType('arrow') or src.projectileType) or ''
			for _, black in ipairs(Blacklist and Blacklist.ListEnabled or {}) do
				if tostring(projectileType):find(black) then return false end
			end
			return true
		end
		return false
	end
	local function runFOVCircle(state)
		if fovConn then fovConn:Disconnect() fovConn = nil end
		if fovDrawing then fovDrawing:Destroy() fovDrawing = nil end
		if not state then return end
		fovDrawing = Instance.new('Frame')
		fovDrawing.Name = 'SAFOVCircle'
		fovDrawing.BackgroundTransparency = 1
		fovDrawing.AnchorPoint = Vector2.new(0.5, 0.5)
		fovDrawing.Visible = false
		local stroke = Instance.new('UIStroke')
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Parent = fovDrawing
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = fovDrawing
		fovDrawing.Parent = vape.gui
		fovConn = runService.RenderStepped:Connect(function()
			if not fovDrawing or not FOV or not FOV.Value then return end
			local shouldShow = SilentAim and SilentAim.Enabled and SAFOVCircle and SAFOVCircle.Enabled and isHoldingProjectile()
			fovDrawing.Visible = shouldShow
			if shouldShow then                groundtime = nil
                flyCooldownActive = false
                bedwars.BalloonController.deflateBalloon = old
                if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
                    for _ = 1, 3 do
                        bedwars.BalloonController:deflateBalloon()
                    end
                end
                cleanupMobileControls()
                cachedBalloonCount = 0
                lastBalloonCheck = 0
                cachedMatchState = 0
            end
        end,
        ExtraText = function()
            return 'Heatseeker'
        end,
        Tooltip = 'makes you go zoom!'
    })
    Value = Fly:CreateSlider({
        Name = 'Speed',
        Min = 1,
        Max = 23,
        Default = 23,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    VerticalValue = Fly:CreateSlider({
        Name = 'Vertical Speed',
        Min = 1,
        Max = 150,
        Default = 50,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    WallCheck = Fly:CreateToggle({
        Name = 'Wall Check',
        Default = true
    })
    PopBalloons = Fly:CreateToggle({
        Name = 'Pop Balloons',
        Default = true
    })
    FlyAnywayProgressBar = Fly:CreateToggle({
        Name = "Progress Bar",
        Function = function(callback)
            if BarColor and BarColor.Object then
                BarColor.Object.Visible = callback
            end
            if callback then
                FlyAnywayProgressBarFrame = Instance.new("Frame")
                FlyAnywayProgressBarFrame.AnchorPoint = Vector2.new(0.5, 0)
                FlyAnywayProgressBarFrame.Position = udim2new(0.5, 0, 1, -200)
                FlyAnywayProgressBarFrame.Size = udim2new(0.2, 0, 0, 20)
                FlyAnywayProgressBarFrame.BackgroundTransparency = 0.5
                FlyAnywayProgressBarFrame.BorderSizePixel = 0
                FlyAnywayProgressBarFrame.BackgroundColor3 = Color3.new(0, 0, 0)
                FlyAnywayProgressBarFrame.Visible = false
                FlyAnywayProgressBarFrame.Parent = vape.gui
                
                local FlyAnywayProgressBarFrame2 = Instance.new("Frame")
                FlyAnywayProgressBarFrame2.Name = "Frame"
                FlyAnywayProgressBarFrame2.AnchorPoint = Vector2.new(0, 0)
                FlyAnywayProgressBarFrame2.Position = udim2new(0, 0, 0, 0)
                FlyAnywayProgressBarFrame2.Size = udim2new(1, 0, 0, 20)
                FlyAnywayProgressBarFrame2.BackgroundTransparency = 0
                FlyAnywayProgressBarFrame2.BorderSizePixel = 0
                FlyAnywayProgressBarFrame2.BackgroundColor3 = BarColor and Color3.fromHSV(BarColor.H, BarColor.S, BarColor.V) or Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
                FlyAnywayProgressBarFrame2.Visible = true
                FlyAnywayProgressBarFrame2.Parent = FlyAnywayProgressBarFrame
                
                local FlyAnywayProgressBartext = Instance.new("TextLabel")
                FlyAnywayProgressBartext.Name = "TextLabel"
                FlyAnywayProgressBartext.Text = "2.5s"
                FlyAnywayProgressBartext.Font = Enum.Font.Gotham
                FlyAnywayProgressBartext.TextStrokeTransparency = 0
                FlyAnywayProgressBartext.TextColor3 = Color3.new(0.9, 0.9, 0.9)
                FlyAnywayProgressBartext.TextSize = 20
                FlyAnywayProgressBartext.Size = udim2new(1, 0, 1, 0)
                FlyAnywayProgressBartext.BackgroundTransparency = 1
                FlyAnywayProgressBartext.Position = udim2new(0, 0, 0, 0)
                FlyAnywayProgressBartext.Parent = FlyAnywayProgressBarFrame
            else
                if FlyAnywayProgressBarFrame then 
                    FlyAnywayProgressBarFrame:Destroy() 
                    FlyAnywayProgressBarFrame = nil 
                end
            end
        end,
        Tooltip = "show amount of time for fly",
        Default = true
    })
    BarColor = Fly:CreateColorSlider({
        Name = 'Bar Color',
        Darker = true,
        Visible = false,
        Function = function(h, s, v, o)
            if FlyAnywayProgressBarFrame then
                FlyAnywayProgressBarFrame:FindFirstChild('Frame').BackgroundColor3 = Color3.fromHSV(h, s, v)
                FlyAnywayProgressBarFrame:FindFirstChild('Frame').BackgroundTransparency = 1 - o
            end
        end
    })

    TP = Fly:CreateToggle({
        Name = 'TP Down',
        Default = true,
        Function = function(callback)
            if callback and FlyAnywayProgressBarFrame then
                FlyAnywayProgressBarFrame.Visible = false
            end
        end
    })
    MobileButtons = Fly:CreateToggle({
        Name = "Mobile Buttons",
        Visible = false,
        Tooltip = 'puts up n down buttons on ur screen gng',
        Function = function() 
            if Fly.Enabled then
                Fly:Toggle()
                Fly:Toggle()
            end
        end
    })

    task.defer(function()
        if BarColor and BarColor.Object then
            BarColor.Object.Visible = FlyAnywayProgressBar.Enabled
        end
        if MobileButtons and MobileButtons.Object then
            MobileButtons.Object.Visible = inputService.TouchEnabled
        end
    end)
end)

run(function()
	vape.Categories.Blatant:CreateModule({
		Name = 'KeepSprint',
		Function = function(callback)
			debug.setconstant(bedwars.SprintController.startSprinting, 5, callback and 'blockSprinting' or 'blockSprint')
			bedwars.SprintController:stopSprinting()
		end,
		Tooltip = 'allows you to sprint with potions'
	})
end)

run(function()
	local NoSlowDown
    local old
    local SophiaCheck
    local FROZEN_THRESHOLD = 10
    local cachedModifier = nil
    local nsHooked = false
    local savedSlow = setmetatable({}, {__mode = 'k'})
    local origPunch = nil
    local origGroveDisable = nil

    local function hookKitNoSlow()
        if bedwars.DragonSlayerController and not origPunch then
            origPunch = bedwars.DragonSlayerController.playPunchAnimation
            bedwars.DragonSlayerController.playPunchAnimation = function(self, arg2)
                local ok, maid = pcall(function()
                    local imp = debug.getupvalue(origPunch, 1)
                    local anim = debug.getupvalue(origPunch, 2)
                    local plrs = debug.getupvalue(origPunch, 3)
                    local atype = debug.getupvalue(origPunch, 4)
                    local rs = debug.getupvalue(origPunch, 6)
                    local m = imp.new()
                    local track = anim:playAnimation(plrs.LocalPlayer, atype.DRAGON_SLAYER_PUNCH)
                    m:GiveTask(function()
                        if track then track:Stop() end
                    end)
                    m:GiveTask(rs.Heartbeat:Connect(function()
                        local char = plrs.LocalPlayer.Character
                        if not char or not char.PrimaryPart then
                            m:DoCleaning()
                            return
                        end
                        char:PivotTo(CFrame.new(char:GetPrimaryPartCFrame().Position) * arg2)
                    end))
                    task.delay(0.46, function() m:DoCleaning() end)
                    return m
                end)
                if ok and maid then return maid end
                return origPunch(self, arg2)
            end
        end

        if bedwars.SpiritGardenerController and not origGroveDisable then
            origGroveDisable = bedwars.SpiritGardenerController.disableActionsOnCharge
            bedwars.SpiritGardenerController.disableActionsOnCharge = function(self, maid, character)
                if character ~= lplr.Character then
                    return origGroveDisable(self, maid, character)
                end
                local ok = pcall(function()
                    local KnitClient = bedwars.KnitClient
                    KnitClient.Controllers.SwordController:toggleSwordSwing(true)
                    KnitClient.Controllers.BlockPlacementController:disableBlockPlacer()
                    local ClientSyncEvents = debug.getupvalue(origGroveDisable, 3)
                    local projConn = ClientSyncEvents.BeginProjectileTargeting:connect(function(event)
                        event:setCancelled(true)
                    end)
                    local jumpMod = KnitClient.Controllers.JumpHeightController:getJumpModifier():addModifier({
                        jumpHeightMultiplier = 0
                    })
                    maid:GiveTask(function()
                        KnitClient.Controllers.SwordController:toggleSwordSwing(false)
                        KnitClient.Controllers.BlockPlacementController:enableBlockPlacer()
                        projConn:Destroy()
                        jumpMod.Destroy()
                    end)
                end)
                if not ok then
                    return origGroveDisable(self, maid, character)
                end
            end
        end
    end

    local function unhookKitNoSlow()
        if origPunch and bedwars.DragonSlayerController then
            bedwars.DragonSlayerController.playPunchAnimation = origPunch
        end
        origPunch = nil
        if origGroveDisable and bedwars.SpiritGardenerController then
            bedwars.SpiritGardenerController.disableActionsOnCharge = origGroveDisable
        end
        origGroveDisable = nil
    end
    NoSlowdown = vape.Categories.Blatant:CreateModule({
        Name = 'NoSlowdown',
        Function = function(callback)
            if not cachedModifier then
                if not bedwars.SprintController then return end
                cachedModifier = bedwars.SprintController:getMovementStatusModifier()
            end
            local modifier = cachedModifier
            if callback then
                if nsHooked then return end
                hookKitNoSlow()
                old = modifier.addModifier
                if not old then return end
                local orig = old

                local function removeSlow(tab)
                    if type(tab) ~= 'table' then
                        return false, false
                    end

                    local changed = false
                    local unblocked = false

                    if not savedSlow[tab] then
                        savedSlow[tab] = {
                            move = tab.moveSpeedMultiplier,
                            constant = tab.constantSpeedMultiplier,
                            blockSprint = tab.blockSprint
                        }
                    end

                    local move = tonumber(tab.moveSpeedMultiplier)
                    local constant = tonumber(tab.constantSpeedMultiplier)

                    if move and move < 1 then
                        tab.moveSpeedMultiplier = 1
                        changed = true
                    end

                    if constant and constant < 1 then
                        tab.constantSpeedMultiplier = 1
                        changed = true
                    end

                    if tab.blockSprint == true and not (constant and constant > 1) then
                        tab.blockSprint = false
                        changed = true
                        unblocked = true
                    end

                    return changed, unblocked
                end

                nsHooked = true
                modifier.addModifier = function(self, tab)
                    if not orig then return end

                    if SophiaCheck and SophiaCheck.Enabled and isFrozen(nil, FROZEN_THRESHOLD) then
                        return orig(self, tab)
                    end

                    removeSlow(tab)
                    return orig(self, tab)
                end

                local changed = false
                local unblocked = false

                for i, v in modifier.modifiers do
                    local mod = type(v) == 'table' and v or (type(i) == 'table' and i or nil)

                    if mod then
                        local didChange, didUnblock = removeSlow(mod)

                        if didChange then
                            changed = true
                        end

                        if didUnblock then
                            unblocked = true
                        end
                    end
                end

                if changed and modifier.updateModifiers then
                    modifier:updateModifiers()
                end

                if unblocked
                    and entitylib.isAlive
                    and entitylib.character.Humanoid.MoveDirection.Magnitude > 0 then

                    pcall(function()
                        bedwars.SprintController:startSprinting()
                    end)
                end

                NoSlowdown:Clean(runService.PreSimulation:Connect(function()
                    if not NoSlowdown.Enabled or not cachedModifier then
                        return
                    end

                    if SophiaCheck and SophiaCheck.Enabled and isFrozen(nil, FROZEN_THRESHOLD) then
                        return
                    end

                    local updated = false
                    local resumeSprint = false

                    for i, v in cachedModifier.modifiers do
                        local mod = type(v) == 'table' and v or (type(i) == 'table' and i or nil)

                        if mod then
                            local didChange, didUnblock = removeSlow(mod)

                            if didChange then
                                updated = true
                            end

                            if didUnblock then
                                resumeSprint = true
                            end
                        end
                    end

                    if updated and cachedModifier.updateModifiers then
                        cachedModifier:updateModifiers()
                    end

                    if resumeSprint
                        and entitylib.isAlive
                        and entitylib.character.Humanoid.MoveDirection.Magnitude > 0 then

                        pcall(function()
                            bedwars.SprintController:startSprinting()
                        end)
                    end
                end))
            else
                unhookKitNoSlow()
                if cachedModifier then
                    cachedModifier.addModifier = old
                    for tab, orig in savedSlow do
                        tab.moveSpeedMultiplier = orig.move
                        tab.constantSpeedMultiplier = orig.constant
                        tab.blockSprint = orig.blockSprint
                    end
                    if cachedModifier.updateModifiers then
                        pcall(cachedModifier.updateModifiers, cachedModifier)
                    end
                    cachedModifier = nil
                end
                table.clear(savedSlow)
                old = nil
                nsHooked = false
            end
        end,
        Tooltip = 'prevents slowing down when using items.'
    })

    SophiaCheck = NoSlowdown:CreateToggle({
        Name = 'Sophia Check',
        Default = false
    })
end)

run(function()
	local DamageBoost
	local stack
	
	DamageBoost = vape.Categories.Blatant:CreateModule({
		Name = 'DamageBoost',
		Function = function(callback)
			if callback then
				DamageBoost:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if entitylib.isAlive and tick() > (stack or 0) and damageTable.entityInstance == lplr.Character and not vape.Modules.LongJump.Enabled then
						local horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 0)
						knockbackSpeed = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
							vertical = 0,
							horizontal = horizontal,
						}).Magnitude * (0.9 + (store.ping and store.ping.total or 0))
						stack = tick() + (knockbackSpeed / 45)
						knockbackBoost = tick() + (horizontal / 3.5)
					end
				end))
			end
		end,
		Tooltip = 'makes you go slightly faster when damaged'
	})
end)

run(function()
	local NoFall
	local Chance
	local voidParams = RaycastParams.new()
	voidParams.FilterType = Enum.RaycastFilterType.Exclude
	voidParams.IgnoreWater = true
	local lastVoidCheck = 0
	local cachedVoid = false

	local voidOffsets = {
		Vector3.new(0, 0, 0),
		Vector3.new(2, 0, 0),
		Vector3.new(-2, 0, 0),
		Vector3.new(0, 0, 2),
		Vector3.new(0, 0, -2)
	}

	local function nearVoid(position)
		if not entitylib.isAlive then return false end
		local now = tick()
		if (now - lastVoidCheck) < 0.1 then
			return cachedVoid
		end
		lastVoidCheck = now
		voidParams.FilterDescendantsInstances = {entitylib.character.Character, gameCamera}

		local down = Vector3.new(0, -600, 0)
		for _, off in voidOffsets do
			if workspace:Raycast(position + off, down, voidParams) then
				cachedVoid = false
				return false
			end
		end

		cachedVoid = true
		return true
	end

	NoFall = vape.Categories.Blatant:CreateModule({
		Name = 'NoFall',
		Function = function(callback)
			if callback then
				NoFall:Clean(runService.Heartbeat:Connect(function(dt)
					if entitylib.isAlive and store.matchState == 1 then
						local root = entitylib.character.RootPart
						local v = root.Velocity

						if root.Velocity.Y < -35 and not nearVoid(root.Position) then
							if math.random(1, 100) <= Chance.Value then
								root.Velocity = Vector3.new(0,2.5,0)
								entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
								runService.PreRender:Wait()
								root.Velocity = v
							end
						end
					end
				end))

				NoFall:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					local animator = char.Humanoid:WaitForChild('Animator', 1)
					if animator and NoFall.Enabled then
						task.wait(.5)
						NoFall:Toggle()
						NoFall:Toggle()
					end
				end))
			end
		end,
		Tooltip = 'Take no fall damage.'
	})

	Chance = NoFall:CreateSlider({
		Name = 'Chance',
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)

run(function()
	local FastPickup
	local FastPickupDelay
	local PickupRemote = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('PickupItemDrop')
	local pendingDrops = setmetatable({}, {__mode = 'k'})

	FastPickup = vape.Categories.Blatant:CreateModule({
		Name = 'FastPickup',
		Tooltip = 'picks up items fast asl',
		Function = function(callback)
			if callback then
				cleanThread(FastPickup, task.spawn(function()
					while FastPickup.Enabled do
						if entitylib.isAlive then
							local drops = workspace:WaitForChild('ItemDropsCache')
							for _, drop in pairs(drops:GetChildren()) do
								if not pendingDrops[drop] then
									pendingDrops[drop] = true
									task.spawn(function()
										task.wait(FastPickupDelay.Value)
										if FastPickup.Enabled and entitylib.isAlive and drop.Parent == drops then
											pcall(function()
												PickupRemote:InvokeServer({ itemDrop = drop })
											end)
										end
										pendingDrops[drop] = nil
									end)
								end
							end
						end
						task.wait(0.05)
					end
				end))
			end
		end,
	})

	FastPickupDelay = FastPickup:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 0.5,
		Default = 0,
		Decimal = 100,
		Suffix = 's',
	})
end)

run(function()
	local ProjectileAimbot
	local TargetPart
	local Targets
	local FOV
	local Range
	local OtherProjectiles
	local Blacklist
	local SortMethod
	local skidPAChargePercent
	local RandomHeadPercent
	local RandomTorsoPercent
	local DesirePAWorkMode
	local DesirePAHideCursor
	local DesirePACursorViewMode
	local DesirePACursorLimitBow
	local DesirePACursorShowGUI
	local cursorRenderConnection
	local lastGUIState = false
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	local _rayMap = nil
	local function refreshRayCheck()
		local map = workspace:FindFirstChild('Map')
		if map ~= _rayMap or not map or not map.Parent then
			_rayMap = map
			if map and map.Parent then
				rayCheck.FilterDescendantsInstances = {map}
			else
				rayCheck.FilterType = Enum.RaycastFilterType.Exclude
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
				return
			end
			rayCheck.FilterType = Enum.RaycastFilterType.Include
		end
	end
	refreshRayCheck()
	local old
	local math_sqrt = math.sqrt
	local math_rad = math.rad
	local math_cos = math.cos
	local math_clamp = math.clamp
	local math_min = math.min
	local math_max = math.max
	local lockedRandomPart = nil
	local wasHovering = false
	local _paVelHistory = {}
	local CustomPredictions
	local PredictHorizontal
	local PredictVertical
	local PAFOVCircle
	local paFOVCircleDrawing = nil
	local AutoCharge
	local paFOVCircleConnection = nil

	local paFOVCircleDrawing = nil 
	local paFOVCircleConnection = nil

	local function runPAFOVCircle(call)
		if paFOVCircleConnection then
			paFOVCircleConnection:Disconnect()
			paFOVCircleConnection = nil
		end
		if paFOVCircleDrawing then
			paFOVCircleDrawing:Destroy()
			paFOVCircleDrawing = nil
		end
		if not call then return end

		paFOVCircleDrawing = Instance.new('Frame')
		paFOVCircleDrawing.Name = 'PAFOVCircle'
		paFOVCircleDrawing.BackgroundTransparency = 1
		paFOVCircleDrawing.AnchorPoint = Vector2.new(0.5, 0.5)
		paFOVCircleDrawing.Visible = false
		local stroke = Instance.new('UIStroke')
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Parent = paFOVCircleDrawing
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = paFOVCircleDrawing
		paFOVCircleDrawing.Parent = vape.gui

		paFOVCircleConnection = runService.RenderStepped:Connect(function()
			if not paFOVCircleDrawing or not FOV or not FOV.Value then
				paFOVCircleDrawing.Visible = false
				return
			end

			local shouldShow = false
			if PAFOVCircle and PAFOVCircle.Enabled and ProjectileAimbot and ProjectileAimbot.Enabled then
				local tool = store.hand and store.hand.tool
				local itemType = tool and tool.Name or ""
				local itemMeta = bedwars.ItemMeta and bedwars.ItemMeta[itemType]
				if store.owlAiming or itemType == 'owl_orb' then
					shouldShow = true
				elseif itemMeta and itemMeta.projectileSource then
					local src = itemMeta.projectileSource
					local isArrow = src.ammoItemTypes and table.find(src.ammoItemTypes, 'arrow')
					local isHeadhunter = itemType:find('headhunter')
					if isArrow or isHeadhunter then
						shouldShow = true
					elseif OtherProjectiles and OtherProjectiles.Enabled then
						local projectileType = src.projectileType and (type(src.projectileType) == 'function' and src.projectileType('arrow') or src.projectileType) or ""
						local blacklisted = false
						for _, black in ipairs(Blacklist and Blacklist.ListEnabled or {}) do
							if tostring(projectileType):find(black) then
								blacklisted = true
								break
							end
						end
						if not blacklisted then
							shouldShow = true
						end
					end
				end
			end

			paFOVCircleDrawing.Visible = shouldShow

			if shouldShow then
				local mousePos
				if inputService.TouchEnabled then
					mousePos = gameCamera.ViewportSize / 2
				else
					local mp = inputService:GetMouseLocation()
					mousePos = Vector2.new(mp.X, mp.Y)
				end
				paFOVCircleDrawing.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
				paFOVCircleDrawing.Size = UDim2.fromOffset(FOV.Value * 2, FOV.Value * 2)
			end
		end)
	end

	local function hasBowEquipped()
		if not store.hand or not store.hand.toolType then return false end
		return store.hand.toolType == 'bow' or store.hand.toolType == 'crossbow'
	end

	local function shouldHideCursor()
		if not DesirePAHideCursor or not DesirePAHideCursor.Enabled then return false end
		if DesirePACursorShowGUI and DesirePACursorShowGUI.Enabled and isGUIOpen() then return false end
		if DesirePACursorLimitBow and DesirePACursorLimitBow.Enabled and not hasBowEquipped() then return false end
		local inFirstPerson = isFirstPerson()
		if DesirePACursorViewMode then
			if DesirePACursorViewMode.Value == 'First Person' then return inFirstPerson
			elseif DesirePACursorViewMode.Value == 'Third Person' then return not inFirstPerson
			end
		end
		return true
	end

	local function updateCursor()
		pcall(function() inputService.MouseIconEnabled = not shouldHideCursor() end)
	end

	local function checkGUIState()
		local currentGUIState = isGUIOpen()
		if lastGUIState ~= currentGUIState then
			updateCursor()
			lastGUIState = currentGUIState
		end
	end

	local paLockedTarget = nil
	local paLockTime = 0
	local paLeadStart = 0
	local paVelSmooth = setmetatable({}, {__mode = 'k'})

	local function paValidLock(originPos)
		local t = paLockedTarget
		if not t then return nil end
		if tick() - paLockTime > 0.4 then return nil end
		if not t.Character or not t.Character.Parent then return nil end
		if not t.RootPart or not t.RootPart.Parent then return nil end
		local hp = t.Humanoid and t.Humanoid.Health or t.Health
		if type(hp) == 'number' and hp <= 0 then return nil end
		if (t.RootPart.Position - originPos).Magnitude > Range.Value then return nil end
		local _, visible = gameCamera:WorldToViewportPoint(t.RootPart.Position)
		if not visible then return nil end
		return t
	end

	local function shouldPAWork()
		if not DesirePAWorkMode then return true end
		local inFirstPerson = isFirstPerson()
		if DesirePAWorkMode.Value == 'First Person' then return inFirstPerson
		elseif DesirePAWorkMode.Value == 'Third Person' then return not inFirstPerson
		end
		return true
	end

	local function isBlacklisted(projectileName)
		if not OtherProjectiles or not OtherProjectiles.Enabled then
			local isTurret = projectileName:find('turret') ~= nil or projectileName:find('vulcan') ~= nil
			return not projectileName:find('arrow') and not isTurret and not projectileName:find('owl')
		end
		for _, black in ipairs(Blacklist and Blacklist.ListEnabled or {}) do
			if projectileName:find(black) then
				return true
			end
		end
		return false
	end

	local function pickRandomPart(character)
		local roll = math.random(1, 100)
		local headChance = RandomHeadPercent.Value
		local torsoChance = RandomTorsoPercent.Value
		if roll <= headChance then
			return character:FindFirstChild('Head') or character:FindFirstChild('HumanoidRootPart')
		elseif roll <= headChance + torsoChance then
			return character:FindFirstChild('UpperTorso') or character:FindFirstChild('HumanoidRootPart')
		else
			return character:FindFirstChild('HumanoidRootPart')
		end
	end

	local function getClosestPart(character, mousePos)
		local parts = {
			'HumanoidRootPart', 'Head', 'LeftHand', 'RightHand',
			'LeftLowerArm', 'RightLowerArm', 'LeftUpperArm', 'RightUpperArm',
			'LeftFoot', 'RightFoot', 'LeftLowerLeg', 'RightLowerLeg',
			'LeftUpperLeg', 'RightUpperLeg', 'LowerTorso', 'UpperTorso'
		}
		local camera = gameCamera
		local rayOrigin = camera.CFrame.Position
		local rayDir = camera:ScreenPointToRay(mousePos.X, mousePos.Y, 0).Direction
		local bestAngle = math.huge
		local bestPart = nil

		for _, partName in ipairs(parts) do
			local part = character:FindFirstChild(partName)
			if part then
				local dirToPart = (part.Position - rayOrigin).Unit
				local angle = math.acos(math_clamp(rayDir:Dot(dirToPart), -1, 1))
				if angle < bestAngle then
					bestAngle = angle
					bestPart = part
				end
			end
		end
		return bestPart or character:FindFirstChild('HumanoidRootPart')
	end

	ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			if callback then
				if SilentAim and SilentAim.Enabled then
					SilentAim:Toggle(false)
					notif('ProjectileAimbot', 'turned off SilentAim, they cant both run at once gng', 4)
				end
				if PAFOVCircle then
					runPAFOVCircle(PAFOVCircle.Enabled)
				end
				ProjectileAimbot:Clean(watchTargets())
				if DesirePAHideCursor and DesirePAHideCursor.Enabled and not cursorRenderConnection then
					cursorRenderConnection = runService.RenderStepped:Connect(function()
						checkGUIState()
						updateCursor()
					end)
					ProjectileAimbot:Clean(cursorRenderConnection)
				end

				old = bedwars.ProjectileController.calculateImportantLaunchValues
				bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
					local self, projmeta, worldmeta, origin, shootpos = ...
					local originPos = entitylib.isAlive and (shootpos or (entitylib.character and entitylib.character.RootPart and entitylib.character.RootPart.Position)) or Vector3.zero
					if not originPos then return old(...) end

					local plr = entitylib.EntityMouse({
						Part = 'RootPart',
						Range = FOV.Value,
						Players = Targets.Players.Enabled,
						NPCs = (Targets.NPCs and Targets.NPCs.Enabled) or false,
						Wallcheck = Targets.Walls.Enabled,
						Sort = sortmethods[SortMethod.Value or 'Cursor'],
						Origin = originPos
					})
					if plr and plr ~= paLockedTarget then
						paLeadStart = tick()
					end
					if plr then
						paLockedTarget = plr
						paLockTime = tick()
					end

					if not plr then
						paLockedTarget = nil
						paLeadStart = 0
						wasHovering = false
						return old(...)
					end
					
					if not shouldPAWork() then
						wasHovering = false
						return old(...)
					end

					local targetBodyPart = nil
					if TargetPart.Value == 'Dynamic' then
						local tool = (typeof(origin) == 'Instance' and origin) or (store.hand and store.hand.tool)
						local itemType = tostring(tool and tool.Name or ""):lower()
						local isHH = itemType:find("headhunter") or tostring(projmeta.projectile or ""):find("headhunter")
						targetBodyPart = (isHH and plr.Character and plr.Character:FindFirstChild("Head")) or plr.RootPart
					elseif TargetPart.Value == 'RootPart' then
						targetBodyPart = plr.RootPart
					elseif TargetPart.Value == 'Head' then
						targetBodyPart = (plr.Character and plr.Character:FindFirstChild('Head')) or plr.RootPart
					elseif TargetPart.Value == 'Closest' then
						local mousePos = inputService.TouchEnabled and (gameCamera.ViewportSize / 2) or inputService:GetMouseLocation()
						targetBodyPart = plr.Character and getClosestPart(plr.Character, mousePos) or plr.RootPart
					elseif TargetPart.Value == 'Randomize' then
						if lockedRandomPart and lockedRandomPart.Parent ~= plr.Character then
							lockedRandomPart = nil
						end
						if plr.Character and (not lockedRandomPart or not lockedRandomPart.Parent) then
							lockedRandomPart = pickRandomPart(plr.Character)
						end
						targetBodyPart = lockedRandomPart or plr.RootPart
					else
						targetBodyPart = plr.RootPart
					end
					if not targetBodyPart then
						wasHovering = false
						return old(...)
					end
					local dist = (targetBodyPart.Position - originPos).Magnitude
					if dist > Range.Value then
						wasHovering = false
						return old(...)
					end
					local pos = shootpos or self:getLaunchPosition(origin)
					if not pos then
						wasHovering = false
						return old(...)
					end
					local projectileName = projmeta.projectile or ""
					if isBlacklisted(projectileName) then
						wasHovering = false
						return old(...)
					end
					refreshRayCheck()
					local meta = projmeta:getProjectileMeta()
					local overrides

					if meta.getProjectileOverridesFunction then
						pcall(function()
							overrides = meta.getProjectileOverridesFunction(lplr)
						end)
					end

					overrides = type(overrides) == 'table' and overrides or {}

					local predictionLifetime = tonumber(overrides.predictionLifetimeOverride) or tonumber(meta.predictionLifetimeSec)
					local normalLifetime = tonumber(overrides.lifetimeOverride) or tonumber(meta.lifetimeSec) or 3
					local lifetime = worldmeta and (predictionLifetime or normalLifetime) or normalLifetime
					local gravityMultiplier = tonumber(projmeta.gravityMultiplier) or 1
					local gravity = (tonumber(meta.gravitationalAcceleration) or 196.2) * gravityMultiplier

					local toolMeta = origin and bedwars.ItemMeta[origin.Name]
					local sourceMeta = toolMeta and toolMeta.projectileSource
					local maxDraw = tonumber(sourceMeta and sourceMeta.maxStrengthChargeSec)
						or tonumber(sourceMeta and sourceMeta.maxDrawDurationSeconds)
						or (tostring(projmeta.projectile):find('arrow') and 0.65 or 0.8)

					local paMinScalar = tonumber(sourceMeta and sourceMeta.minStrengthScalar) or 1
					local baseSpeed = tonumber(overrides.launchVelocityOverride) or tonumber(meta.launchVelocity) or 100
					local nativeValues = old(...)
					local projSpeed
					local customDrawDuration
					local offsetpos

					if nativeValues and typeof(nativeValues.positionFrom) == 'Vector3' then
						offsetpos = nativeValues.positionFrom
					else
						local safeOffset = projmeta.fromPositionOffset

						if typeof(safeOffset) ~= 'Vector3' then
							safeOffset = Vector3.new(0, 2, 0)
						end

						offsetpos = pos + safeOffset
					end

					if nativeValues and type(nativeValues.gravitationalAcceleration) == 'number' then
						gravity = nativeValues.gravitationalAcceleration
					end

					if AutoCharge.Enabled then
						local drawPct = math.clamp(skidPAChargePercent.Value / 100, 0, 1)

						projSpeed = baseSpeed * (paMinScalar + (1 - paMinScalar) * drawPct)
						customDrawDuration = maxDraw * drawPct
					else
						if nativeValues
							and typeof(nativeValues.initialVelocity) == 'Vector3'
							and nativeValues.initialVelocity.Magnitude > 0 then

							projSpeed = nativeValues.initialVelocity.Magnitude
						else
							local liveDraw = tonumber(projmeta.drawDurationSeconds) or 0
							local livePct = maxDraw > 0 and math.clamp(liveDraw / maxDraw, 0, 1) or 0

							projSpeed = baseSpeed * (paMinScalar + (1 - paMinScalar) * livePct)
						end

						customDrawDuration = nativeValues
							and tonumber(nativeValues.drawDurationSeconds)
							or tonumber(projmeta.drawDurationSeconds)
							or 0
					end
					local balloons = plr.Character and plr.Character:GetAttribute('InflatedBalloons')
					local playerGravity = workspace.Gravity
					if balloons and balloons > 0 then
						playerGravity = balloonGravity(balloons, plr.Character)
					end
					if plr.Character and plr.Character.PrimaryPart and plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
						playerGravity = 6
					end
					if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
						for _, owl in ipairs(collectionService:GetTagged('Owl')) do
							if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
								playerGravity = 0
								break
							end
						end
					end
					local rawVel = plr.RootPart.AssemblyLinearVelocity or plr.RootPart.Velocity or Vector3.zero
					local aimTarget = targetBodyPart.Position
					if tostring(projmeta.projectile):find('fireball') then
						aimTarget = splashAimPoint(plr.RootPart, plr.HipHeight) or aimTarget
					end
					local solverVelocity = projmeta.projectile == 'telepearl' and Vector3.zero or rawVel
					local tAirborne = (plr.Humanoid and plr.Humanoid.FloorMaterial == Enum.Material.Air) or math.abs(rawVel.Y) > 0.01
					local tJump = plr.Jumping and 42.6 or nil
					local horizLead = 1
					local vertLead = 1
					if CustomPredictions and CustomPredictions.Enabled and projmeta.projectile ~= 'telepearl' then
						horizLead = PredictHorizontal.Value / 100
						vertLead = PredictVertical.Value / 100
					end
					if horizLead ~= 1 or vertLead ~= 1 then
						solverVelocity = Vector3.new(
							solverVelocity.X * horizLead,
							solverVelocity.Y * vertLead,
							solverVelocity.Z * horizLead
						)
					end
			local proj = meta.projectileSource
			if not proj or not proj.projectileType then continue end
			local ammo = getAmmo(proj)
			if not ammo then continue end
			local projType = proj.projectileType(ammo)
			local pmeta = projType and bedwars.ProjectileMeta[projType]
			if pmeta and pmeta.arrow and pmeta.launchVelocity then
				table.insert(_projectilesCache, {item, ammo, projType, proj})
			end
		end
		return _projectilesCache
	end

	local function canShoot(proj)
		return tick() > (FireRates[proj[1].itemType] or 0) and tick() > LastShot and not FastHitPending
	end

	local sharedFastHitsRayParams = RaycastParams.new()
	sharedFastHitsRayParams.FilterType = Enum.RaycastFilterType.Exclude

	local fhBusy = false

	local function fhInAngle(v)
		if not AngleSlider or AngleSlider.Value >= 360 then return true end
		if not v or not v.RootPart then return false end
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return false end
		local look = root.CFrame.LookVector
		local flatLook = look * Vector3.new(1, 0, 1)
		if flatLook.Magnitude < 0.001 then return true end
		local flat = (v.RootPart.Position - root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude <= 1 then return true end
		return math.acos(math.clamp(flatLook.Unit:Dot(flat.Unit), -1, 1)) <= math.rad(AngleSlider.Value) / 2
	end

	local function fhEquipAwait(tool)
		if not tool or not tool.Parent then return false end
		local success = pcall(switchItem, tool, 0.0475)
		return success
	end

	local fhRestoreToken = 0
	local function fhRestoreSword()
		local sw = store.tools.sword
		if not sw or not sw.tool or not sw.tool.Parent then return end
		local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem')
		if not check then return end
		fhRestoreToken = fhRestoreToken + 1
		local token = fhRestoreToken
		check.Value = sw.tool
		task.spawn(function()
			pcall(function() bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = sw.tool}) end)
			for _ = 1, 3 do
				task.wait(0)
				if token ~= fhRestoreToken then return end
				if not sw.tool.Parent then return end
				if not Killaura or not Killaura.Enabled then return end
				if check.Value ~= sw.tool or (store.hand and store.hand.tool ~= sw.tool) then
					check.Value = sw.tool
					pcall(function() bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = sw.tool}) end)
				else
					return
				end
			end
		end)
	end

	local _fhVelHistory = {}
	local _fhPing = 0.1
	local _fhPingClock = 0
	local _fhIdChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

	local function fhGenId()
		local out = table.create(8)
		for i = 1, 8 do
			local n = math.random(1, #_fhIdChars)
			out[i] = _fhIdChars:sub(n, n)
		end
		return table.concat(out)
	end

	local function getFHPing()
		if tick() - _fhPingClock < 1 then return _fhPing end
		_fhPingClock = tick()
		-- Use store.ping.total for direct ping measurement (more accurate than game stats)
		local val = (store.ping and store.ping.total) or 0
		_fhPing = math.clamp(val, 0.02, 1)
		return _fhPing
	end

	local function smoothedVelocity(ent, targetPart)
		local rawVel = targetPart.AssemblyLinearVelocity or targetPart.Velocity or Vector3.zero
		local key = tostring(ent)
		if not _fhVelHistory[key] then
			_fhVelHistory[key] = rawVel
		else
			_fhVelHistory[key] = _fhVelHistory[key]:Lerp(rawVel, 0.35)
		end
		return _fhVelHistory[key], rawVel
	end

	local function targetGravity(ent)
		local playerGravity = workspace.Gravity
		local balloons = ent.Character and ent.Character:GetAttribute('InflatedBalloons')
		if balloons and balloons > 0 then
			playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
		end
		if ent.Character and ent.Character.PrimaryPart and ent.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
			playerGravity = 6
		end
		if ent.Player and ent.Player:GetAttribute('IsOwlTarget') then
			local _owls = collectionService:GetTagged('Owl')
			if #_owls > 0 then
				local _uid = ent.Player.UserId
				for _, owl in ipairs(_owls) do
					if owl:GetAttribute('Target') == _uid and owl:GetAttribute('Status') == 2 then
						playerGravity = 0
						break
					end
				end
			end
		end
		return playerGravity
	end

	local function shootProjectile(item, ammo, projectile, itemMeta, selfPos, ent, ignoreSwitch)
		local meta = bedwars.ProjectileMeta[projectile]
		if not meta then return false end

		local switched = false
		if not ignoreSwitch then
			fhBusy = true
			store._fhBusySince = workspace:GetServerTimeNow()
			if not fhEquipAwait(item.tool) then
				fhRestoreSword()
				fhBusy = false
				return false
			end
			switched = true
			local root = entitylib.character and entitylib.character.RootPart
			if not root then
				fhRestoreSword()
				fhBusy = false
				return false
			end
			selfPos = root.Position
		end

		local gravity = tonumber(meta.gravitationalAcceleration) or 196.2
		if gravity < 1 then gravity = 0 end
		local targetPart = ent.RootPart
		local playerGravity = targetGravity(ent)

		local maxCharge = tonumber(itemMeta.maxStrengthChargeSec) or 0
		local chargePct = ArrowCharge / 100
		local drawTime = maxCharge * chargePct
		local multiAt = tonumber(itemMeta.multiShotChargeTime)
		if multiAt and chargePct >= 1 then
			drawTime = math.max(drawTime, multiAt)
		end
		local minScalar = tonumber(itemMeta.minStrengthScalar) or 1
		local chargeRatio = maxCharge > 0 and math.clamp(drawTime / maxCharge, 0, 1) or 1
		local projSpeed = meta.launchVelocity * (minScalar + (1 - minScalar) * chargeRatio)

		local ping = getFHPing()
		local smoothVel, rawVel = smoothedVelocity(ent, targetPart)
		smoothVel = Vector3.new(smoothVel.X, rawVel.Y, smoothVel.Z)
		local hip = ent.HipHeight or 2
		local aimPart = targetPart
		local aimOffset = hip * 0.15
		do
			local itype = tostring(item.itemType)
			local head = ent.Character and ent.Character:FindFirstChild('Head')
			local speed = tonumber(meta.launchVelocity) or 0
			local grav = tonumber(meta.gravitationalAcceleration) or 196.2
			local dist = (targetPart.Position - selfPos).Magnitude

			if itype:find('headhunter') then
				local hspeed = Vector3.new(smoothVel.X, 0, smoothVel.Z).Magnitude
				if head and dist < 90 and hspeed < 28 and math.abs(smoothVel.Y) < 30 then
					aimPart = head
					aimOffset = -0.35
				else
					aimOffset = hip * 0.15
				end
			elseif itype:find('bomb') or itype:find('grenade') or itype:find('santa') or itype:find('impulse') then
				aimOffset = -hip * 0.5
			elseif itype:find('rocket') or itype:find('launcher') or itype:find('firework') then
				aimOffset = 0
			elseif meta.arrow then
				if grav <= 40 and speed >= 200 and dist < 60 and head then
					aimPart = head
					aimOffset = 0
				else
					aimOffset = hip * 0.15
				end
			elseif itype:find('snowball') or itype:find('chakram') or itype:find('spell') then
				aimOffset = hip * 0.3
			end
		end
		local leadPos = aimPart.Position + Vector3.new(0, aimOffset, 0)
		local netLead = math.clamp(ping, 0.02, 0.12)
		local vy = smoothVel.Y
		local dropY = vy * netLead
		if vy < -12 or vy > 12 then
			dropY = dropY - 0.5 * playerGravity * netLead * netLead
		end
		leadPos = leadPos + Vector3.new(smoothVel.X * netLead, dropY, smoothVel.Z * netLead)

		sharedFastHitsRayParams.FilterDescendantsInstances = {lplr.Character, gameCamera, ent.Character}

		local originPos
		do
			local handle = item.tool and item.tool:FindFirstChild('Handle')
			local bo = handle and handle:FindFirstChild('BulletOrigin')
			if bo and bo:IsA('Attachment') then
				originPos = bo.WorldPosition
			else
				local char = entitylib.character and entitylib.character.Character
				local hand = char and (char:FindFirstChild('RightHand') or char:FindFirstChild('Right Arm'))
				if hand then
					originPos = hand.Position
				else
					local pp = entitylib.character and entitylib.character.RootPart
					originPos = pp and (pp.Position + Vector3.new(0, 1.5, 0)) or gameCamera.CFrame.Position
				end
			end
		end

		local calc, flightTime = prediction.SolveTrajectory(
			originPos, projSpeed, gravity, leadPos, smoothVel,
			playerGravity, ent.HipHeight or 2,
			ent.Jumping and 42.6 or nil, sharedFastHitsRayParams
		)

		local lifetime = tonumber(meta.predictionLifetimeSec) or tonumber(meta.lifetimeSec) or (projSpeed > 0 and math.min(3, 120 / projSpeed) or 3)
		if not calc or (flightTime and flightTime > lifetime) then
			if switched then
				fhRestoreSword()
				fhBusy = false
			end
			return false
		end

		local shootPos = originPos
		if meta.arrow then
			shootPos = (CFrame.new(originPos, calc) * CFrame.new(Vector3.new(-(bedwars.BowConstantsTable.RelX or 0), -(bedwars.BowConstantsTable.RelY or 0), -(bedwars.BowConstantsTable.RelZ or 0)))).Position
		end
		do
			local myRoot = entitylib.character and entitylib.character.RootPart
			if myRoot then
				local away = (calc - shootPos)
				if away.Magnitude > 0.01 then
					shootPos = shootPos + away.Unit * 2
				end
				local flat = (shootPos - myRoot.Position) * Vector3.new(1, 0, 1)
				if flat.Magnitude < 0.5 then
					shootPos = shootPos + Vector3.new(0, 0.5, 0)
				end
			end
		end
		local dir = CFrame.lookAt(shootPos, calc).LookVector
		local id = fhGenId()
		local shotMeta = {
			shotId = fhGenId(),
			drawDurationSec = drawTime,
			drawDurationSeconds = drawTime
		}

		targetinfo.Targets[ent] = tick() + 1
		FireRates[item.itemType] = tick() + (tonumber(itemMeta.fireDelaySec) or 0.095)
		LastShot = tick() + (FireRate and FireRate.Value or 0.05)

		bedwars.ProjectileController:createLocalProjectile(
			meta, ammo, projectile, shootPos, id, dir * projSpeed,
			{drawDurationSec = drawTime, drawDurationSeconds = drawTime}
		)

		FastHitPending = true
		task.spawn(function()
			local res = projectileRemote:InvokeServer(
				item.tool, ammo, projectile, shootPos, selfPos,
				dir * projSpeed, id, shotMeta,
				workspace:GetServerTimeNow() - 0.05
			)
			FastHitPending = false
			if res then
				pcall(function() res.Parent = replicatedStorage end)
				local sound = itemMeta.launchSound
				sound = sound and sound[math.random(1, #sound)] or nil
				if sound and bedwars.SoundManager then
					pcall(function() bedwars.SoundManager:playSound(sound) end)
				end
				lastProjectileTime = workspace:GetServerTimeNow()
			end
		end)

		if switched then
			fhRestoreSword()
			fhBusy = false
		end

		return true
	end

	local function getGloopItem()
		for _, item in store.inventory.inventory.items do
			if item.itemType == 'glue_projectile' then
				return item
			end
		end
		return nil
	end

	local function getFireballItem()
		for _, item in store.inventory.inventory.items do
			if item.itemType == 'fireball' then
				return item
			end
		end
		return nil
	end

	local function isGlooped(ent)
		local char = ent and ent.Character
		if not char then return false end
		local val = char:GetAttribute('GlueSlow')
		return val ~= nil and val ~= 0
	end



	local function shootGloop(item, ent)
		-- Strict check: throw Gloops ONLY on real players (not NPCs)
		if not ent or not ent.RootPart or not ent.Player then return false end
		local key = tostring(ent)
		local now = tick()
		local tracked = gloopTracker[key]

		if tracked and tracked.target == ent then
			if tracked.gloopedUntil and now < tracked.gloopedUntil then return false end
			if tracked.lastShot and (now - tracked.lastShot) < (GloopCooldown and GloopCooldown.Value or 6) then return false end
		end

		if isGlooped(ent) then
			gloopTracker[key] = {target = ent, lastShot = now, gloopedUntil = now + 8}
			return false
		end

		local myRoot = entitylib.character and entitylib.character.RootPart
		if not myRoot then return false end
		if (ent.RootPart.Position - myRoot.Position).Magnitude > 45 then return false end

		local selfPos = entitylib.character.RootPart.Position
		local targetPart = ent.RootPart

		local gmeta = bedwars.ProjectileMeta.glue_trap
		local gSpeed = tonumber(gmeta and gmeta.launchVelocity) or 100
		local gGrav = tonumber(gmeta and gmeta.gravitationalAcceleration) or 85
		if gGrav < 1 then gGrav = 0 end

		local gitem = bedwars.ItemMeta[item.itemType]
		local gMax = tonumber(gitem and gitem.maxStrengthChargeSec) or 0
		local gMin = tonumber(gitem and gitem.minStrengthScalar) or 1
		local gPct = ArrowCharge / 100
		local gRatio = gMax > 0 and math.clamp(gPct, 0, 1) or 1
		gSpeed = gSpeed * (gMin + (1 - gMin) * gRatio)

		local ping = getFHPing()
		local smoothVel, rawVel = smoothedVelocity(ent, targetPart)
		smoothVel = Vector3.new(smoothVel.X, rawVel.Y, smoothVel.Z)
		local playerGravity = targetGravity(ent)

		local aimPos = targetPart.Position - Vector3.new(0, (ent.HipHeight or 2) * 0.6, 0)
		local netLead = math.clamp(ping, 0.02, 0.12)
		local dropY = smoothVel.Y * netLead
		if smoothVel.Y < -12 or smoothVel.Y > 12 then
			dropY = dropY - 0.5 * playerGravity * netLead * netLead
		end
		aimPos = aimPos + Vector3.new(smoothVel.X * netLead, dropY, smoothVel.Z * netLead)

		sharedFastHitsRayParams.FilterDescendantsInstances = {lplr.Character, gameCamera, ent.Character}

		local originPos = selfPos + Vector3.new(0, 1.5, 0)
		local calc, gFlight = prediction.SolveTrajectory(
			originPos, gSpeed, gGrav, aimPos, smoothVel,
			playerGravity, ent.HipHeight or 2,
			ent.Jumping and 42.6 or nil, sharedFastHitsRayParams
		)
		local gLife = tonumber(gmeta and gmeta.predictionLifetimeSec) or 2
		if not calc or (gFlight and gFlight > gLife) then return false end

		local dir = CFrame.lookAt(originPos, calc).LookVector

		fhBusy = true
		store._fhBusySince = workspace:GetServerTimeNow()
		if not fhEquipAwait(item.tool) then
			fhRestoreSword()
			fhBusy = false
			return false
		end

		pcall(function()
			glueRemote:InvokeServer(
				replicatedStorage.Inventories[lplr.Name].glue_projectile,
				'glue_projectile',
				'glue_trap',
				originPos,
				selfPos,
				dir * gSpeed,
				httpService:GenerateGUID(true):sub(1, 8):upper(),
				{shotId = httpService:GenerateGUID(true):sub(1, 8):upper(), drawDurationSec = 0.05},
				workspace:GetServerTimeNow() - 0.0475
			)
			lastProjectileTime = workspace:GetServerTimeNow()
		end)

		gloopTracker[key] = {target = ent, lastShot = now}
		task.wait(0.05)
		fhRestoreSword()
		fhBusy = false
		return true
	end

	local function shootFireball(item, ent)
		-- Strict check: throw Fireballs ONLY on real players (not NPCs)
		if not ent or not ent.RootPart or not ent.Player then return false end
		local key = tostring(ent)
		local now = tick()
		local tracked = fireballTracker[key]

		if tracked and tracked.lastShot and (now - tracked.lastShot) < (FireballCooldown and FireballCooldown.Value or 8) then
			return false
		end

		local myRoot = entitylib.character and entitylib.character.RootPart
		if not myRoot then return false end
		if (ent.RootPart.Position - myRoot.Position).Magnitude > 60 then return false end

		local selfPos = entitylib.character.RootPart.Position
		local targetPart = ent.RootPart

		local fmeta = bedwars.ProjectileMeta.fireball or {launchVelocity = 80, gravitationalAcceleration = 0}
		local fSpeed = tonumber(fmeta.launchVelocity) or 80
		local fGrav = tonumber(fmeta.gravitationalAcceleration) or 0

		local ping = getFHPing()
		local smoothVel, rawVel = smoothedVelocity(ent, targetPart)
		smoothVel = Vector3.new(smoothVel.X, rawVel.Y, smoothVel.Z)

		local aimPos = targetPart.Position
		local netLead = math.clamp(ping, 0.02, 0.12)
		aimPos = aimPos + Vector3.new(smoothVel.X * netLead, smoothVel.Y * netLead, smoothVel.Z * netLead)

		sharedFastHitsRayParams.FilterDescendantsInstances = {lplr.Character, gameCamera, ent.Character}

		local originPos = selfPos + Vector3.new(0, 1.5, 0)
		local calc = prediction.SolveTrajectory(
			originPos, fSpeed, fGrav, aimPos, smoothVel,
			workspace.Gravity, ent.HipHeight or 2,
			ent.Jumping and 42.6 or nil, sharedFastHitsRayParams
		)
		if not calc then calc = aimPos end

		local dir = CFrame.lookAt(originPos, calc).LookVector

		fhBusy = true
		store._fhBusySince = workspace:GetServerTimeNow()
		if not fhEquipAwait(item.tool) then
			fhRestoreSword()
			fhBusy = false
			return false
		end

		pcall(function()
			projectileRemote:InvokeServer(
				item.tool,
				'fireball',
				'fireball',
				originPos,
				selfPos,
				dir * fSpeed,
				httpService:GenerateGUID(true):sub(1, 8):upper(),
				{shotId = httpService:GenerateGUID(true):sub(1, 8):upper(), drawDurationSec = 0.05},
				workspace:GetServerTimeNow() - 0.0475
			)
			lastProjectileTime = workspace:GetServerTimeNow()
		end)

		fireballTracker[key] = {target = ent, lastShot = now}
		task.wait(0.05)
		fhRestoreSword()
		fhBusy = false
		return true
	end

	local fhStage = 1
	local fhUsageIndex = 1
	local function doFastHitsNEW(ent)
		if not ent or not ent.RootPart or not entitylib.isAlive then return end
		local selfPos = entitylib.character.RootPart.Position

		local anyOn = (Gloops and Gloops.Enabled) or (Fireballs and Fireballs.Enabled) or (Arrows and Arrows.Enabled)
		if not anyOn then return end

		for _ = 1, 3 do
			if fhStage == 1 then
				fhStage = 2
				if Gloops and Gloops.Enabled then
					local gloopItem = getGloopItem()
					if gloopItem and shootGloop(gloopItem, ent) then return end
				end
			elseif fhStage == 2 then
				fhStage = 3
				if Fireballs and Fireballs.Enabled then
					local fireballItem = getFireballItem()
					if fireballItem and shootFireball(fireballItem, ent) then return end
				end
			else
				fhStage = 1
				if Arrows and Arrows.Enabled then
					local projectiles = getProjectiles()
					if projectiles and #projectiles > 0 then
						for _i = 1, #projectiles do
							fhUsageIndex = fhUsageIndex % #projectiles + 1
							local p = projectiles[fhUsageIndex]
							if canShoot(p) then
								local item, ammo, projectile, itemMeta = unpack(p)
								if shootProjectile(item, ammo, projectile, itemMeta, selfPos, ent, false) then return end
								break
							end
						end
					end
				end
			end
		end
	end

	local function doFastHitsLegitSwitch(ent)
		if not ent or not ent.RootPart or not entitylib.isAlive then return end

		local selfPos = entitylib.character.RootPart.Position

		if Gloops and Gloops.Enabled then
			local gloopItem = getGloopItem()
			if gloopItem and shootGloop(gloopItem, ent) then return end
		end

		if Fireballs and Fireballs.Enabled then
			local fireballItem = getFireballItem()
			if fireballItem and shootFireball(fireballItem, ent) then return end
		end

		local projectiles = getProjectiles()
		if not projectiles or #projectiles == 0 then return end

		local readyProj
		for _, proj in projectiles do
			if canShoot(proj) then
				readyProj = proj
				break
			end
		end
		if not readyProj then return end

		local item, ammo, projectile, itemMeta = unpack(readyProj)
		local bowSlot, swordSlot
		local originalSlot = store.inventory.hotbarSlot
		local hotbar = store.inventory.hotbar
		for i = 1, #hotbar do
			local hv = hotbar[i]
			if hv and hv.item and hv.item.itemType then
				if hv.item.itemType == item.itemType and not bowSlot then
					bowSlot = i - 1
				end
				if isMeleeWeapon(hv.item.itemType) and not swordSlot then
					swordSlot = i - 1
				end
			end
		end
		if not bowSlot then return end

		fhBusy = true
		store._fhBusySince = workspace:GetServerTimeNow()
		local shotOk, shotErr = pcall(function()
			if hotbarSwitch(bowSlot) then task.wait(0.0375) end
			shootProjectile(item, ammo, projectile, itemMeta, selfPos, ent, true)
			task.wait(0.075)
		end)

		-- Restore the exact slot selected before the projectile switch.
		if originalSlot ~= nil then
			local restoreOk, restoreErr = pcall(hotbarSwitch, originalSlot)
			if not restoreOk then
				warn('[aerov4] FastHits hotbar restore failed: ' .. tostring(restoreErr))
			end
		end
		fhBusy = false
		if not shotOk then
			warn('[aerov4] FastHits projectile switch failed: ' .. tostring(shotErr))
		end
	end

	local function doFastHits()
		if not FastHits or not FastHits.Enabled then return end
		if not Killaura or not Killaura.Enabled then return end
		if not entitylib.isAlive then return end

		local selfRoot = entitylib.character and entitylib.character.RootPart
		if not selfRoot then return end

		local ent = store.KillauraTarget
		if not ent or not ent.RootPart then return end
		if not fhInAngle(ent) then return end
		if (ent.RootPart.Position - selfRoot.Position).Magnitude > SwingRange.Value then return end

		if not FastHitPending then
			if LegitSwitch and LegitSwitch.Enabled then
				doFastHitsLegitSwitch(ent)
			else
				doFastHitsNEW(ent)
			end
		end
	end

	local function startAutoShootLoop()
		if autoShootLoop then return end
		if not FireRates then FireRates = {} end
		fhUsageIndex = 1
		fhStage = 1
		table.clear(FireRates)
		LastShot = 0
		FastHitPending = false

		autoShootLoop = task.spawn(function()
			while Killaura and Killaura.Enabled and FastHits and FastHits.Enabled do
				pcall(doFastHits)
				task.wait(0.05)
			end
			fhBusy = false
			autoShootLoop = nil
		end)
	end

	local function stopAutoShootLoop()
		if autoShootLoop then
			pcall(task.cancel, autoShootLoop)
			autoShootLoop = nil
		end
		if FireRates then table.clear(FireRates) end
		table.clear(_fhVelHistory)
		table.clear(gloopTracker)
		table.clear(fireballTracker)
		fhUsageIndex = 1
		fhStage = 1
		fhBusy = false
		LastShot = 0
		FastHitPending = false
	end

	local killauraFireLoop
	local _graceTarget = nil
	local _graceUntil = 0
	local _fastAcqTime = 0
	local _fastAcqRes = nil

	local function withinAngle(v)
		if not AngleSlider or AngleSlider.Value >= 360 then return true end
		if not v or not v.RootPart then return false end
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return true end
		local flatLV = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		local facing = flatLV.Magnitude > 0.001 and flatLV.Unit or root.CFrame.RightVector
		local flat = (v.RootPart.Position - root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude <= 1 then return true end
		return math.acos(math.clamp(facing:Dot(flat.Unit), -1, 1)) <= math.rad(AngleSlider.Value) / 2
	end

	local function inReach(v)
		local root = entitylib.character and entitylib.character.RootPart
		if not root or not v or not v.RootPart then return false end
		return (v.RootPart.Position - root.Position).Magnitude <= (AttackRange.Value + 0)
	end

	local function aliveTarget(v)
		if not v or not v.RootPart then return false end
		local char = v.Character
		if not char or not char.Parent then return false end
		if v.Health ~= nil and v.Health <= 0 then return false end
		return true
	end

	local function resolveTarget()
		local v = store.KillauraTarget
		if aliveTarget(v) and withinAngle(v) and inReach(v) then
			_graceTarget = v
			_graceUntil = tick() + 0.4
			return v
		end
		if _graceTarget and tick() < _graceUntil then
			local g = _graceTarget
			if aliveTarget(g) and inReach(g) then
				return g
			end
		end
		local now = tick()
		if (now - _fastAcqTime) < 0.03 and _fastAcqRes then
			if not (aliveTarget(_fastAcqRes) and withinAngle(_fastAcqRes) and inReach(_fastAcqRes)) then return nil end
			return _fastAcqRes
		end
		_fastAcqTime = now
		_fastAcqRes = nil
		local list = entitylib.AllPosition({
			Range = AttackRange.Value + 0,
			Wallcheck = Targets.Walls.Enabled or nil,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Limit = 5,
			Sort = sortmethods[Sort.Value] or sortmethods['Distance']
		})
		for _, ent in list do
			if withinAngle(ent) then
				_fastAcqRes = ent
				break
			end
		end
		return _fastAcqRes
	end

	local function attemptFire()
		if fhBusy and (workspace:GetServerTimeNow() - (store._fhBusySince or 0)) < 0.10 then return false end
		
		-- Add small delay after FastHits to prevent ghosting sword hits
		if lastProjectileTime > 0 and (workspace:GetServerTimeNow() - lastProjectileTime) < 0.075 then
			return false
		end
		
		local v = resolveTarget()
		if not v then return false end

		local sword, meta = getAttackData()
		if not sword or not meta then return false end

		local weaponInst = sword.tool
		pcall(function()
			local inv = replicatedStorage:FindFirstChild('Inventories')
			local mine = inv and inv:FindFirstChild(lplr.Name)
			local w = mine and mine:FindFirstChild(sword.tool.Name)
			if w then weaponInst = w end
		end)

		local char = lplr.Character
		if not char or not char.PrimaryPart then return false end
		local tchar = v.Character
		if not tchar or not tchar.PrimaryPart then return false end
		local selfPos = entitylib.character.RootPart.Position
		local targetPos = tchar.PrimaryPart.Position
		local dist = (targetPos - selfPos).Magnitude
		if dist > AttackRange.Value + 0 then return false end

		if AirHit and AirHit.Enabled and AirHitsChance and AirHitsChance.Value < 100 then
			local hum = tchar:FindFirstChildOfClass('Humanoid')
			if hum then
				local inAir = hum.FloorMaterial == Enum.Material.Air
				if not inAir then
					local st = hum:GetState()
					inAir = st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall
				end
				if not inAir then
					local root = tchar.PrimaryPart
					local vy = root and root.AssemblyLinearVelocity.Y or 0
					inAir = math.abs(vy) > 3
				end
				if inAir then
					if math.random(1, 100) > AirHitsChance.Value then return false end
				end
			end
		end

		if sword.tool.Name:find('summoner_claw') then
			pcall(function() KaidaController:request(tchar) end)
			return false
		end

		if not FireAttackRemote(weaponInst, tchar, selfPos, targetPos) then
			markAttackResult(false)
			return false
		end

		local srvNow = workspace:GetServerTimeNow()

		lastAttackTime = tick()
		store.attackReach = (dist * 100) // 1 / 100
		store.attackReachUpdate = tick() + 1

		-- Mark attack as successful for dynamic delay system
		markAttackResult(true)

		kaLastSend = srvNow
		if kaLastSrv > 0 then
			kaLastSrv = kaLastSrv + kaPeriod
			if kaLastSrv < srvNow then
				kaLastSrv = srvNow
			end
		else
			kaLastSrv = srvNow
		end
		kaNextFire = 0

		if bedwars.SwordController then
			bedwars.SwordController.lastAttack = srvNow
		end
		return true
	end

	local function startKillauraFireLoop()
		if killauraFireLoop then return end

		kaPeriod = HIT_PERIOD
		animPeriod = NORMAL_SWORD_SWING_SPEED
		kaNextFire = 0
		kaLastSrv = workspace:GetServerTimeNow() - kaPeriod
		kaLastSend = 0

		killauraFireLoop = task.spawn(function()
			while Killaura and Killaura.Enabled do
				runService.Heartbeat:Wait()

				local sword, meta = getAttackData()
				if sword and meta then
					kaPeriod = getAttackDelay(meta)
					animPeriod = NORMAL_SWORD_SWING_SPEED
				else
					kaPeriod = HIT_PERIOD
					animPeriod = NORMAL_SWORD_SWING_SPEED
				end

				updatePreciseClock()

				local heartbeatDt = 1 / 60
				local target = kaPeriod - math.min(heartbeatDt * 0.5, kaPeriod * 0.06)
				if (workspace:GetServerTimeNow() - kaLastSrv) >= target then
					pcall(attemptFire)
				end
			end
		end)
	end

	local function stopKillauraFireLoop()
		if killauraFireLoop then
			pcall(task.cancel, killauraFireLoop)
			killauraFireLoop = nil
		end
		_graceTarget = nil
		_graceUntil = 0
		_fastAcqTime = 0
		_fastAcqRes = nil
		kaNextFire = 0
			kaSync = 0
		kaSyncSrv = 0
		animPeriod = NORMAL_SWORD_SWING_SPEED
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				lastAttackTime = 0
				lastTargetTime = 0
				lastAnimTime = 0
				resetSwordCooldown()
				preciseRemainder = 0
				preciseTimestamp = tick()

				if inputService.TouchEnabled and not preserveSwordIcon then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = Limit and Limit.Enabled
					end)
				end

				if FastHits and FastHits.Enabled then
					startAutoShootLoop()
				end

				if UseKits and UseKits.Enabled then
					startUseKitsLoop()
				end

				startKillauraFireLoop()

				if Animation and Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
					task.spawn(function()
						local started = false
						repeat
							if Attacking and not (LegitAura and LegitAura.Enabled) then
								if not armC0 then
									armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
								end
								local first = not started
								started = true
								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end
								for _, v in anims[AnimationMode.Value] do
									if AnimTween then AnimTween:Destroy() AnimTween = nil end
									AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
										C0 = armC0 * v.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									first = false
									if (not Killaura.Enabled) or (not Attacking) then break end
								end
							elseif started then
								started = false
								if AnimTween then AnimTween:Destroy() AnimTween = nil end
								AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween and AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = armC0
								})
								AnimTween:Play()
							end
							if not started then
								task.wait(1 / 3.5)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled)
					end)
				end

				local _gatherCache = nil
				local _gatherCacheTime = 0
				local function gatherTargets()
					if _gatherCache and (tick() - _gatherCacheTime) < 0.05 then
						return _gatherCache[1], _gatherCache[2]
					end

					local walls = Targets.Walls.Enabled or nil
					local players = Targets.Players.Enabled
					local npcs = Targets.NPCs.Enabled
					local sort = sortmethods[Sort.Value]

					local function buildList(range)
						return entitylib.AllPosition({Range = range, Wallcheck = walls, Part = 'RootPart', Players = players, NPCs = npcs, Limit = 1, Sort = sort})
					end

					local attackPlrs = buildList(AttackRange.Value)
					local swingPlrs = AttackRange.Value == SwingRange.Value and attackPlrs or buildList(SwingRange.Value)
					_gatherCache = {swingPlrs, attackPlrs}
					_gatherCacheTime = tick()
					return swingPlrs, attackPlrs
				end

				local _cachedSwordType = nil
				local _cachedIsClaw = false

				repeat
					-- Update 240Hz precise clock for consistent timing
					updatePreciseClock()

					if AttackCheck and AttackCheck.Enabled then
						local triggered = false
						local stunTime = lplr.Character and lplr.Character:GetAttribute('StunnedUntilTime')
						if stunTime and stunTime > workspace:GetServerTimeNow() then triggered = true end
						if not triggered and kitChecks then
							for _, check in pairs(kitChecks) do
								local ok, res = pcall(check)
								if ok and res then triggered = true break end
							end
						end
						if triggered then
							Attacking = false
							getgenv().Attacking = false
							store.KillauraTarget = nil
							_graceUntil = 0
							task.wait(0.3)
							continue
						end
					end

					local sword, meta = getAttackData()
					if not sword then
						if Attacking then
							Attacking = false
							getgenv().Attacking = false
							store.KillauraTarget = nil
						end
						task.wait(0.05)
						continue
					end

					if vapeTargetInfo and vapeTargetInfo.Targets then
						vapeTargetInfo.Targets.Killaura = nil
					end

					if sword then
						local swordName = sword.tool.Name
						if swordName ~= _cachedSwordType and not fhBusy then
							_cachedSwordType = swordName
							_cachedIsClaw = swordName:find('summoner_claw') ~= nil
							resetSwordCooldown()
						end
						local isClaw = _cachedIsClaw

						local selfpos = entitylib.character.RootPart.Position
						local flatLV = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
						local localfacing = flatLV.Magnitude > 0.001 and flatLV.Unit or entitylib.character.RootPart.CFrame.RightVector
						local maxAngle = math.rad(AngleSlider.Value) / 2
						local swingPlrs, attackPlrs = gatherTargets()

						local function passesAngle(v)
							if AngleSlider.Value >= 360 then return true end
							local flat = (v.RootPart.Position - selfpos) * Vector3.new(1, 0, 1)				
				local foundItem = false
				for i, v in LongJumpMethods do
					local item = getItem(i)
					if item or store.equippedKit == i then
						foundItem = true
						task.spawn(v, item, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
						break
					end
				end
				if not foundItem then
					notif("LongJump", "unable to find tool to use Long Jump with gng", 3)
					LongJump:Toggle()
					return
				end
			else
				JumpTick = tick()
				Direction = nil
				JumpSpeed = 0
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'lets you jump farther'
	})
	Value = LongJump:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 37,
		Default = 37,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	CameraDir = LongJump:CreateToggle({
		Name = 'Camera Direction'
	})
end)

--[[
	Render Modules
]]

run(function()
    local SetPlayerLevel
    local originalLevel = nil
    local customLevel = 1

    SetPlayerLevel = vape.Categories.Render:CreateModule({
        Name = "SetPlayerLevel",
        Function = function(state)
            if state then
                originalLevel = lplr:GetAttribute("PlayerLevel")
                lplr:SetAttribute("PlayerLevel", customLevel)
            else
                lplr:SetAttribute("PlayerLevel", originalLevel)
                originalLevel = nil
            end
        end,
        Tooltip = "Spoof your player level (client-sided)"
    })

    SetPlayerLevel:CreateSlider({
        Name = "Level",
        Min = 1,
        Max = 1000,
        Default = 1,
        Decimal = 1,
        Function = function(val)
            customLevel = math.floor(val)
            if SetPlayerLevel.Enabled then
                lplr:SetAttribute("PlayerLevel", customLevel)
            end
        end
    })
end)

run(function()
	local BedESP
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(bed)
		if not BedESP.Enabled then return end
		local BedFolder = Instance.new('Folder')
		BedFolder.Parent = Folder
		Reference[bed] = BedFolder
		local parts = bed:GetChildren()
		table.sort(parts, function(a, b)
			return a.Name > b.Name
		end)
	
		for _, part in parts do
			if part:IsA('BasePart') and part.Name ~= 'Blanket' then
				local handle = Instance.new('BoxHandleAdornment')
				handle.Size = part.Size + Vector3.new(.01, .01, .01)
				handle.AlwaysOnTop = true
				handle.ZIndex = 2
				handle.Visible = true
				handle.Adornee = part
				handle.Color3 = part.Color
				if part.Name == 'Legs' then
					handle.Color3 = Color3.fromRGB(167, 112, 64)
					handle.Size = part.Size + Vector3.new(.01, -1, .01)
					handle.CFrame = CFrame.new(0, -0.4, 0)
					handle.ZIndex = 0
				end
				handle.Parent = BedFolder
			end
		end
	
		table.clear(parts)
	end
	
	BedESP = vape.Categories.Render:CreateModule({
		Name = 'BedESP',
		Function = function(callback)
			if callback then
				BedESP:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(function(bed)
					task.delay(0.2, Added, bed)
				end))
				BedESP:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(bed)
					if Reference[bed] then
						Reference[bed]:Destroy()
						Reference[bed] = nil
					end
				end))
				for _, bed in collectionService:GetTagged('bed') do
					Added(bed)
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'Render Beds through walls'
	})
end)

run(function()
	local LootESP
	local IronToggle
	local DiamondToggle
	local EmeraldToggle
	local GeneratorToggle
	local ScaleToggle
	local ScaleSlider
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui	
	local CollectionService = collectionService
	
	local lootTypes = {
		iron = {
			keywords = {'iron'},
			color = Color3.fromRGB(200, 200, 200),
			icon = 'iron',
			displayName = 'IRON'
		},
		diamond = {
			keywords = {'diamond'},
			color = Color3.fromRGB(85, 200, 255),
			icon = 'diamond',
			displayName = 'DIAMOND'
		},
		emerald = {
			keywords = {'emerald'},
			color = Color3.fromRGB(0, 255, 100),
			icon = 'emerald',
			displayName = 'EMERALD'
		}
	}
	
	local function getLootType(itemName)
		local nameLower = itemName:lower()
		for lootType, config in pairs(lootTypes) do
			for _, keyword in ipairs(config.keywords) do
				if nameLower:find(keyword, 1, true) then 
					return lootType, config
				end
			end
		end
		return nil
	end
	
	local function isLootEnabled(lootType)
		if lootType == 'iron' then
			return IronToggle.Enabled
		elseif lootType == 'diamond' then
			return DiamondToggle.Enabled
		elseif lootType == 'emerald' then
			return EmeraldToggle.Enabled
		end
		return false
	end
	
	local function readDropAttr(handle, attr)
		if not handle then return nil end
		local val = handle:GetAttribute(attr)
		if val == nil and handle.Parent then
			val = handle.Parent:GetAttribute(attr)
		end
		return val
	end
	
	local function isGeneratorDrop(handle)
		return readDropAttr(handle, 'OreGenDrop') == true
	end
	
	local function getDropAmount(handle)
		local amt = readDropAttr(handle, 'Amount')
		if type(amt) ~= 'number' then return 1 end
		return amt
	end
	
	local function getProperIcon(lootType)
		local icon = bedwars.getIcon({itemType = lootType}, true)
		
		if not icon or icon == "" then
			return nil
		end
		
		return icon
	end
	
	local function Added(lootHandle, lootType, config)
		if not isLootEnabled(lootType) then return end
		if Reference[lootHandle] then return end 
		local dropRoot = lootHandle.Parent
		if dropRoot and dropRoot:GetAttribute('AeroBanked') then return end
		if dropRoot then
			local bankedConn
			bankedConn = dropRoot:GetAttributeChangedSignal('AeroBanked'):Connect(function()
				if dropRoot:GetAttribute('AeroBanked') and Reference[lootHandle] then
					Reference[lootHandle]:Destroy()
					Reference[lootHandle] = nil
				end
				bankedConn:Disconnect()
			end)
		end 
		if isGeneratorDrop(lootHandle) and not (GeneratorToggle and GeneratorToggle.Enabled) then return end 
		
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = lootType
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		local ls = (ScaleToggle and ScaleToggle.Enabled and ScaleSlider) and ScaleSlider.Value or 1
		billboard.Size = UDim2.fromOffset(40 * ls, 40 * ls)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = lootHandle
		
		local blur = addBlur(billboard)
		blur.Visible = true 
		
		local iconImage = getProperIcon(config.icon)
		
		if iconImage then
			local image = Instance.new('ImageLabel')
			image.Size = UDim2.fromOffset(40, 40)
			image.Position = UDim2.fromScale(0.5, 0.5)
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.BackgroundColor3 = Color3.new(0, 0, 0) 
			image.BackgroundTransparency = 0.3 
			image.BorderSizePixel = 0
			image.Image = iconImage
			image.Parent = billboard
			
			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = image
			
			local amt = Instance.new('TextLabel')
			amt.Name = 'Amt'
			amt.AnchorPoint = Vector2.new(1, 1)
			amt.Position = UDim2.new(1, -1, 1, -1)
			amt.Size = UDim2.fromOffset(40, 14)
			amt.BackgroundTransparency = 1
			amt.Text = tostring(getDropAmount(lootHandle))
			amt.TextColor3 = Color3.fromRGB(255, 255, 255)
			amt.TextStrokeTransparency = 0.4
			amt.TextSize = 13
			amt.Font = Enum.Font.GothamBold
			amt.TextXAlignment = Enum.TextXAlignment.Right
			amt.TextYAlignment = Enum.TextYAlignment.Bottom
			amt.Parent = image
		else
			local frame = Instance.new('Frame')
			frame.Size = UDim2.fromOffset(40, 40)
			frame.Position = UDim2.fromScale(0.5, 0.5)
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.BackgroundColor3 = Color3.new(0, 0, 0) 
			frame.BackgroundTransparency = 0.3 
			frame.BorderSizePixel = 0
			frame.Parent = billboard
			
			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = frame
			
			local textLabel = Instance.new('TextLabel')
			textLabel.Size = UDim2.fromScale(1, 1)
			textLabel.Position = UDim2.fromScale(0.5, 0.5)
			textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = config.displayName
			textLabel.TextColor3 = config.color
			textLabel.TextScaled = true
			textLabel.Font = Enum.Font.GothamBold
			textLabel.TextStrokeTransparency = 0.5
			textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			textLabel.Parent = frame
			
			local amt = Instance.new('TextLabel')
			amt.Name = 'Amt'
			amt.AnchorPoint = Vector2.new(1, 1)
			amt.Position = UDim2.new(1, -1, 1, -1)
			amt.Size = UDim2.fromOffset(40, 14)
			amt.BackgroundTransparency = 1
			amt.Text = tostring(getDropAmount(lootHandle))
			amt.TextColor3 = Color3.fromRGB(255, 255, 255)
			amt.TextStrokeTransparency = 0.4
			amt.TextSize = 13
			amt.Font = Enum.Font.GothamBold
			amt.TextXAlignment = Enum.TextXAlignment.Right
			amt.TextYAlignment = Enum.TextYAlignment.Bottom
			amt.Parent = frame
		end
		
		local content = billboard:FindFirstChild('ImageLabel') or billboard:FindFirstChild('Frame')
		if content then
			local sc = Instance.new('UIScale')
			sc.Name = 'LootScale'
			sc.Scale = ls
			sc.Parent = content
		end

		local amtLabel = billboard:FindFirstChild('Amt', true)
		if amtLabel then
			local src = lootHandle:GetAttribute('Amount') ~= nil and lootHandle or lootHandle.Parent
			if src then
				local conn = src:GetAttributeChangedSignal('Amount'):Connect(function()
					if amtLabel.Parent then
						amtLabel.Text = tostring(getDropAmount(lootHandle))
					end
				end)
				billboard.AncestryChanged:Connect(function()
					if not billboard.Parent then conn:Disconnect() end
				end)
			end
		end
		
		Reference[lootHandle] = billboard
	end
	
	local function Removed(lootHandle)
		if Reference[lootHandle] then
			Reference[lootHandle]:Destroy()
			Reference[lootHandle] = nil
		end
	end
	
	local function findExistingLoot()
		local tagged = CollectionService:GetTagged('ItemDrop')
		for _, drop in ipairs(tagged) do
			local handle = drop:FindFirstChild('Handle')
			if handle then
				local lootType, config = getLootType(drop.Name)
				if lootType and isLootEnabled(lootType) then
					if not Reference[handle] then
						Added(handle, lootType, config)
					end
				end
			end
		end
	end
	
	local function refreshLootType(lootType)
		if not LootESP.Enabled then return end
		
		local enabled = isLootEnabled(lootType)
		
		if not (GeneratorToggle and GeneratorToggle.Enabled) then
			for handle, billboard in pairs(Reference) do
				if isGeneratorDrop(handle) then
					billboard:Destroy()
					Reference[handle] = nil
				end
			end
		end
		
		if not enabled then
			for handle, billboard in pairs(Reference) do
				if billboard.Name == lootType then
					billboard:Destroy()
					Reference[handle] = nil
				end
			end
		else
			local tagged = CollectionService:GetTagged('ItemDrop')
			for _, drop in ipairs(tagged) do
				local handle = drop:FindFirstChild('Handle')
				if handle then
					local dropLootType, config = getLootType(drop.Name)
					if dropLootType == lootType and not Reference[handle] then
						Added(handle, lootType, config)
					end
				end
			end
		end
	end
	
	LootESP = vape.Categories.Render:CreateModule({
		Name = 'LootESP',
		Function = function(callback)
			if callback then
				findExistingLoot()
				
				LootESP:Clean(CollectionService:GetInstanceAddedSignal('ItemDrop'):Connect(function(drop)
					if not LootESP.Enabled then return end
					
					task.defer(function()
						local handle = drop:FindFirstChild('Handle')
						if not handle then return end
						
						local lootType, config = getLootType(drop.Name)
						if lootType and isLootEnabled(lootType) then
							Added(handle, lootType, config)
						end
					end)
				end))
				
				LootESP:Clean(CollectionService:GetInstanceRemovedSignal('ItemDrop'):Connect(function(drop)
					local handle = drop:FindFirstChild('Handle')
					if handle then
						Removed(handle)
					end
				end))
				
			else
				for handle, billboard in pairs(Reference) do
					billboard:Destroy()
				end
				table.clear(Reference)
			end
		end,
		Tooltip = 'esp for loot (iron, emerald, diamonds)'
	})
	
	IronToggle = LootESP:CreateToggle({
		Name = 'Iron',
		Function = function(callback)
			refreshLootType('iron')
		end,
		Default = true
	})
	
	DiamondToggle = LootESP:CreateToggle({
		Name = 'Diamond',
		Function = function(callback)
			refreshLootType('diamond')
		end,
		Default = true
	})
	
	EmeraldToggle = LootESP:CreateToggle({
		Name = 'Emerald',
		Function = function(callback)
			refreshLootType('emerald')
		end,
		Default = true
	})
	
	GeneratorToggle = LootESP:CreateToggle({
		Name = 'Generators',
		Function = function(callback)
			if not LootESP.Enabled then return end
			refreshLootType('iron')
			refreshLootType('diamond')
			refreshLootType('emerald')
		end,
		Tooltip = 'off = loot sittin on a gen gets hidden, only shows stuff ppl dropped. flip it on if u wanna see gen loot too gng'
	})

	local function applyLootScale()
		local val = (ScaleToggle and ScaleToggle.Enabled and ScaleSlider) and ScaleSlider.Value or 1
		for _, billboard in pairs(Reference) do
			billboard.Size = UDim2.fromOffset(40 * val, 40 * val)
			local sc = billboard:FindFirstChild('LootScale', true)
			if sc then sc.Scale = val end
		end
	end

	ScaleToggle = LootESP:CreateToggle({
		Name = 'Custom Scale',
		Function = function(callback)
			if ScaleSlider then ScaleSlider.Object.Visible = callback end
			applyLootScale()
		end,
		Tooltip = 'turn on to pick ur own size for the loot icons'
	})

	ScaleSlider = LootESP:CreateSlider({
		Name = 'Scale',
		Min = 0.5,
		Max = 3,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false,
		Function = function()
			applyLootScale()
		end,
		Tooltip = 'makes the loot icons bigger or smaller gng'
	})
end)

run(function()
	local StorageESP
	local List
	local Background
	local Color = {}
	local Reference = {}
	local ChestContents = {} 
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function getEnabledItemsSet()
		local set = {}
		for _, v in ipairs(List.ListEnabled) do
			set[v] = true
		end
		return set
	end
	
	local function nearStorageItem(item, enabledSet)
		for itemName in pairs(enabledSet) do
			if item:find(itemName, 1, true) then return itemName end
		end
		return nil
	end
	
	local function refreshAdornee(billboard)
		local chestPart = billboard.Adornee
		local folderValue = chestPart and chestPart:FindFirstChild('ChestFolderValue')
		local chest = folderValue and folderValue.Value or nil

		if not chest then
			ChestContents[chestPart] = nil
			billboard.Enabled = false
			return
		end

		local chestitems = chest:GetChildren()
		local enabledSet = getEnabledItemsSet()
		local listIsEmpty = next(enabledSet) == nil

		local matchedItems = {}
		local amounts = {}
		for _, item in ipairs(chestitems) do
			if item:IsA('Accessory') then
				if listIsEmpty or enabledSet[item.Name] or nearStorageItem(item.Name, enabledSet) then
					if amounts[item.Name] == nil then
						amounts[item.Name] = 0
						table.insert(matchedItems, item.Name)
					end
					amounts[item.Name] = amounts[item.Name] + (item:GetAttribute('Amount') or 1)
				end
			end
		end

		local count = #matchedItems
		if count == 0 then
			billboard.Enabled = false
			return
		end

		local signatureParts = {}
		for _, itemName in ipairs(matchedItems) do
			table.insert(signatureParts, itemName .. '=' .. tostring(amounts[itemName]))
		end
		local signature = table.concat(signatureParts, '\0')
		local previous = ChestContents[chestPart]
		billboard.Enabled = true
		if previous and previous.chest == chest and previous.signature == signature then return end
		ChestContents[chestPart] = {chest = chest, signature = signature}
		for _, obj in ipairs(billboard:GetChildren()) do
			if obj:IsA('ImageLabel') and obj.Name == 'Icon' then
				obj:Destroy()
			end
		end
		local iconSize = 36
		local padding = 2
		local totalWidth = count * iconSize + (count - 1) * padding
		billboard.Size = UDim2.fromOffset(totalWidth, iconSize)

		for i, itemName in ipairs(matchedItems) do
			local icon = Instance.new('ImageLabel')
			icon.Name = 'Icon'
			icon.Size = UDim2.fromOffset(iconSize, iconSize)
			icon.Position = UDim2.fromOffset((i - 1) * (iconSize + padding), 0)
			icon.AnchorPoint = Vector2.new(0, 0)
			icon.BackgroundColor3 = Color3.new(0, 0, 0)
			icon.BackgroundTransparency = 0.3
			icon.BorderSizePixel = 0
			icon.Image = bedwars.getIcon({itemType = itemName}, true)
			icon.Parent = billboard

			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = icon

			local amt = Instance.new('TextLabel')
			amt.Name = 'Amt'
			amt.AnchorPoint = Vector2.new(1, 1)
			amt.Position = UDim2.new(1, -1, 1, -1)
			amt.Size = UDim2.fromOffset(iconSize, 14)
			amt.BackgroundTransparency = 1
			amt.Text = tostring(amounts[itemName] or 0)
			amt.TextColor3 = Color3.fromRGB(255, 255, 255)
			amt.TextStrokeTransparency = 0.4
			amt.TextSize = 13
			amt.Font = Enum.Font.GothamBold
			amt.TextXAlignment = Enum.TextXAlignment.Right
			amt.TextYAlignment = Enum.TextYAlignment.Bottom
			amt.Parent = icon
		end
	end
	
	local function Added(v)
		if Reference[v] then return end

		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'chest'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		billboard.Enabled = false

		local blur = addBlur(billboard)

		Reference[v] = billboard

		refreshAdornee(billboard)

		task.defer(function()
			local folderValue = v:FindFirstChild('ChestFolderValue')
			local chest = folderValue and folderValue.Value or nil
			if chest and Reference[v] then
				local conn1 = chest.ChildAdded:Connect(function()
					if Reference[v] then refreshAdornee(Reference[v]) end
				end)
				local conn2 = chest.ChildRemoved:Connect(function()
					if Reference[v] then refreshAdornee(Reference[v]) end
				end)
				billboard.AncestryChanged:Connect(function()
					conn1:Disconnect()
					conn2:Disconnect()
				end)
			end
		end)
	end
	
	local function Removed(v)
		if Reference[v] then
			Reference[v]:Destroy()
			Reference[v] = nil
			ChestContents[v] = nil
		end
	end
	
	StorageESP = vape.Categories.Render:CreateModule({
		Name = 'StorageESP',
		Function = function(callback)
			if callback then
				local tagged = collectionService:GetTagged('chest')
				for _, v in ipairs(tagged) do
					Added(v)
				end
				
				StorageESP:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(Added))
				StorageESP:Clean(collectionService:GetInstanceRemovedSignal('chest'):Connect(Removed))
				cleanThread(StorageESP, task.spawn(function()
					while StorageESP.Enabled do
						task.wait(0.5)
						if not StorageESP.Enabled then break end
						for chest, billboard in pairs(Reference) do
							if not chest or not chest.Parent then
								Removed(chest)
							else
								refreshAdornee(billboard)
							end
						end
					end
				end))
			else
				for chest in pairs(Reference) do
					Removed(chest)
				end
			end
		end,
		Tooltip = 'shows what items are in a chest'
	})
	
	List = StorageESP:CreateTextList({
		Name = 'Item',
		Function = function()
			table.clear(ChestContents)
			for _, v in pairs(Reference) do
				refreshAdornee(v)
			end
		end
	})
	
	Background = StorageESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in pairs(Reference) do
				local icon = v:FindFirstChild('Icon')
				if icon then
					icon.BackgroundTransparency = callback and 0.3 or 1
				end
			end
		end,
		Default = true
	})
	
    Color = StorageESP:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, v in pairs(Reference) do
                v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                v.Frame.BackgroundTransparency = 1 - opacity
            end
        end,
        Darker = true
    })

    task.defer(function()
        if Color and Color.Object then
            Color.Object.Visible = Background.Enabled  
        end
    end)
end)

run(function()
	local TrapESP
	local Background = {}
	local Color = {}
	local Snap, Venom, Explosive, Landmine, Tesla, Gloop
	local Reference = {}
	local Watch = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui

	local Tags = {
		'snap_trap',
		'trapper_trap',
		'invisible-landmine',
		'invisible_landmine',
		'tesla-trap',
		'tesla_trap',
		'glue_trap',
		'GlueTrap'
	}

	local function getToggle(kind)
		return kind == 'snap' and Snap
			or kind == 'venom' and Venom
			or kind == 'explosive' and Explosive
			or kind == 'landmine' and Landmine
			or kind == 'tesla' and Tesla
			or kind == 'gloop' and Gloop
	end

	local function getTrap(v, tag)
		if tag == 'trapper_trap' then
			local trapType = tostring(
				v:GetAttribute('trapType')
				or v:GetAttribute('TrapType')
				or v:GetAttribute('Type')
				or ''
			):lower()

			if trapType:find('venom', 1, true)
				or v.Name:lower():find('venom', 1, true)
				or v:FindFirstChild('venom_trap', true) then
				return 'venom', 'venom_trap'
			end

			if trapType:find('explosive', 1, true)
				or v.Name:lower():find('explosive', 1, true)
				or v:FindFirstChild('explosive_trap', true) then
				return 'explosive', 'explosive_trap'
			end

			if trapType:find('snap', 1, true)
				or v.Name:lower():find('snap', 1, true)
				or v:FindFirstChild('snap_trap', true) then
				return 'snap', 'snap_trap'
			end

			return
		elseif tag == 'snap_trap' then
			return 'snap', 'snap_trap'
		elseif tag == 'invisible-landmine' or tag == 'invisible_landmine' then
			return 'landmine', 'invisible_landmine'
		elseif tag == 'tesla-trap' or tag == 'tesla_trap' then
			return 'tesla', 'tesla_trap'
		elseif tag == 'glue_trap' or tag == 'GlueTrap' or v.Name == 'GlueTrap' then
			return 'gloop', 'glue_projectile'
		end
	end

	local function isFriendly(v)
		local owner = tonumber(v:GetAttribute('PlacedByUserId') or v:GetAttribute('ownerId'))
		if owner and owner == lplr.UserId then
			return true
		end

		local teamName = lplr.Team and lplr.Team.Name
		local teamId = lplr:GetAttribute('Team')

		for _, attribute in {'SnapTrapTeamId', 'TrapperTeamId', 'LandmineTeam', 'TeamId'} do
			local value = v:GetAttribute(attribute)
			if value ~= nil then
				if typeof(value) == 'Instance' then
					value = value.Name
				end
				value = tostring(value)

				if (teamName and value == tostring(teamName))
					or (teamId ~= nil and value == tostring(teamId)) then
					return true
				end
			end
		end

		return false
	end

	local function remove(v)
		if Reference[v] then
			Reference[v]:Destroy()
			Reference[v] = nil
		end
		if Watch[v] then
			for _, conn in Watch[v] do
				conn:Disconnect()
			end
			Watch[v] = nil
		end
	end

	local function clearAll()
		for v in Watch do
			remove(v)
		end
		for v in Reference do
			remove(v)
		end
		Folder:ClearAllChildren()
	end

	local function pickAdornee(v)
		if v:IsA('BasePart') then return v end
		if v:IsA('Model') and v.PrimaryPart then return v.PrimaryPart end
		local best, size = nil, -1
		for _, part in v:GetDescendants() do
			if part:IsA('BasePart') and part.Transparency < 1 then
				local vol = part.Size.X * part.Size.Y * part.Size.Z
				if vol > size then
					best, size = part, vol
				end
			end
		end
		return best or v:FindFirstChildWhichIsA('BasePart', true)
	end

	local function added(v, icon, kind)
		if Reference[v] or isFriendly(v) then return end

		local toggle = getToggle(kind)
		if not toggle or not toggle.Enabled then return end

		local adornee = pickAdornee(v)

		if not adornee then return end

		Watch[v] = {
			v.AncestryChanged:Connect(function(_, parent)
				if not parent then
					remove(v)
				end
			end),
			v.AttributeChanged:Connect(function()
				if isFriendly(v) then
					remove(v)
				end
			end)
		}

		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = icon
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = adornee

		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled

		local image = Instance.new('ImageLabel')
		image.Name = 'ImageLabel'
		image.Size = UDim2.fromOffset(36, 36)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		image.Image = bedwars.getIcon({itemType = icon}, true)
		image.Parent = billboard

		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = image

		Reference[v] = billboard
	end

	local function isHeld(v)
		if v:IsDescendantOf(gameCamera) then return true end
		local inv = replicatedStorage:FindFirstChild('Inventories')
		if inv and v:IsDescendantOf(inv) then return true end
		if v:FindFirstAncestorWhichIsA('Tool') or v:FindFirstAncestorWhichIsA('Accessory') then return true end
		local model = v:FindFirstAncestorOfClass('Model')
		while model do
			if model:FindFirstChildOfClass('Humanoid') then return true end
			model = model:FindFirstAncestorOfClass('Model')
		end
		return false
	end

	local function addByTag(v, tag)
		if isHeld(v) then return end
		local kind, icon = getTrap(v, tag)
		if kind then
			added(v, icon, kind)
		end
	end

	local function addGloop(v)
		if v.Name ~= 'GlueTrap' then return end

		task.spawn(function()
			for _ = 1, 12 do
				if not TrapESP.Enabled or not v.Parent then return end

				addByTag(v, 'GlueTrap')

				if Reference[v] then
					return
				end

				task.wait(0.05)
			end
		end)
	end

	local function refresh()
		clearAll()

		if not TrapESP.Enabled then return end

		for _, tag in Tags do
			for _, v in collectionService:GetTagged(tag) do
				addByTag(v, tag)
			end
		end
	end

	TrapESP = vape.Categories.Render:CreateModule({
		Name = 'TrapESP',
		Function = function(callback)
			if callback then
				TrapESP:Clean(workspace.DescendantAdded:Connect(function(v)
					if v.Name == 'GlueTrap' then
						addGloop(v)
					end
				end))			if Distance.Enabled then
				Strings[ent] = '[%s] ' .. Strings[ent]
			end
			local textSize = 14 * Scale.Value
			local fontFace = FontOption.Value
			local size = getfontsize(removeTags(Strings[ent]), textSize, fontFace, vector2new(100000, 100000))
			local nametag = Instance.new('TextLabel')
			nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
			nametag.Size = udim2fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = vector2new(0.5, 1)
			nametag.BackgroundColor3 = color3new()
			nametag.BackgroundTransparency = Background.Value
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.Text = Strings[ent]
			nametag.TextColor3 = getTeamColor(ent) or color3fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.RichText = true
			nametag.TextSize = textSize
			nametag.FontFace = fontFace
			nametag.Parent = Folder

			if KitTracker and KitTracker.Enabled and ent.Player then
			  pcall(function()
				local vkRoman = {'I','II','III','IV','V'}
				local ktLabel = Instance.new('TextLabel')
				ktLabel.Name = 'KitTrackerLabel'
				ktLabel.BackgroundTransparency = 1
				ktLabel.TextScaled = false
				ktLabel.TextSize = 13
				ktLabel.FontFace = FontOption.Value
				ktLabel.RichText = true
				ktLabel.AnchorPoint = Vector2.new(1, 0.5)
				ktLabel.Position = UDim2.new(0, -2, 0.5, 0)
				ktLabel.Size = UDim2.new(0, 40, 1, 0)
				ktLabel.ZIndex = 2
				ktLabel.Parent = nametag

				local stroke = Instance.new('UIStroke')
				stroke.Color = Color3.new(0, 0, 0)
				stroke.Thickness = 1.5
				stroke.Parent = ktLabel

				local ktEventsBound = false
				local function updateKtLabel()
					if not KitTracker.Enabled then ktLabel.Text = '' return end
					local playerKit = ent.Player:GetAttribute('PlayingAsKits') or 'none'
					if playerKit == 'void_knight' then
						local tier = ent.Player:GetAttribute('VoidKnightTier') or 0
						if tier > 0 then
							ktLabel.Text = '【' .. (vkRoman[tier] or tostring(tier)) .. '】'
							ktLabel.TextColor3 = Color3.fromRGB(180, 80, 255)
						else
							ktLabel.Text = ''
						end
					elseif playerKit == 'block_kicker' then
						local char = ent.Character
						local count = (char and char:GetAttribute('BlockKickerKit_BlockCount')) or ent.Player:GetAttribute('BlockKickerKit_BlockCount') or 0
						ktLabel.Text = count > 0 and '【' .. tostring(count) .. '】' or ''
						ktLabel.TextColor3 = Color3.fromRGB(100, 210, 100)
					elseif playerKit == 'elk_master' then
						local char = ent.Character
						local isMounted = char and char:FindFirstChild('elk') ~= nil
						if isMounted then
							ktLabel.Text = '【🦌】'
							ktLabel.TextColor3 = Color3.fromRGB(160, 220, 80)
						else
							ktLabel.Text = ''
						end
					elseif playerKit == 'summoner' then
						local tier = ent.Player:GetAttribute("Summoner_ClawLevel") or 0
						if not tier or tier == 0 then ktLabel.Text = '' return end
						ktLabel.Text = '【 ' .. (vkRoman[tier] or tostring(tier)) .. ' 】'
						ktLabel.TextColor3 = Color3.fromRGB(191, 0, 255)
					elseif playerKit == 'paladin' then
						ktLabel.Text = '【 🪽 】'
						ktLabel.TextColor3 = Color3.fromRGB(255, 242, 150)
					elseif playerKit == 'davey' then
						local tier = ent.Character and ent.Character:GetAttribute('StatusEffect_powdered_stacks') or 0
						if tier > 0 then
							ktLabel.Text = '【 ' .. tostring(tier) .. ' 】'
						else
							ktLabel.Text = ''
						end
						ktLabel.TextColor3 = Color3.fromRGB(255, 105, 130)
					elseif playerKit == 'airbender' then
						ktLabel.Text = ''
						ktLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
						if not ktEventsBound then
							ktEventsBound = true
							if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
							task.spawn(function()
								table.insert(kitTrackerConnections[ent], bedwars.Client:Get("Airbender_UseTornadoFromServer"):Connect(function(p12)
									if not KitTracker.Enabled then ktLabel.Text = '' return end
									if p12.tornadoData.owner == ent.Player then
										ktLabel.Text = '【 🌪️ 】'
									end
								end))
								table.insert(kitTrackerConnections[ent], bedwars.Client:Get("Airbender_EndTornadoFromServer"):Connect(function(p13)
									if not KitTracker.Enabled then ktLabel.Text = '' return end
									if p13.tornadoData.owner == ent.Player then
										ktLabel.Text = ''
									end
								end))
							end)
						end
					elseif playerKit == 'hatter' then
						ktLabel.Text = ''
						ktLabel.TextColor3 = Color3.fromRGB(45, 15, 80)
						if not ktEventsBound then
							ktEventsBound = true
							if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
							task.spawn(function()
								if vape.ThreadFix then setthreadidentity(8) end
								table.insert(kitTrackerConnections[ent], bedwars.Client:OnEvent("HatterUseTeleport", function(p14)
									if vape.ThreadFix then setthreadidentity(8) end
									if not KitTracker.Enabled then ktLabel.Text = '' return end
									local dtc = p14.arriveTime - workspace:GetServerTimeNow() + 0.05
									if p14.hatterPlayer == ent.Player then
										ktLabel.Text = '【 🎩 】'
										task.wait(dtc)
										if vape.ThreadFix then setthreadidentity(8) end
										ktLabel.Text = ''
									else
										ktLabel.Text = ''
									end
								end))
							end)
						end
					elseif playerKit == 'black_market_trader' then
						ktLabel.Text = ''
						ktLabel.TextColor3 = Color3.fromRGB(30, 10, 60)
						if not ktEventsBound then
							ktEventsBound = true
							if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
							task.spawn(function()
								table.insert(kitTrackerConnections[ent], bedwars.Client:Get("BlackMarketPlaceShop"):Connect(function(p15)
									if not KitTracker.Enabled then ktLabel.Text = '' return end
									if p15.shopOwnerUserId == ent.Player.UserId then
										ktLabel.Text = '【 🏪 】'
									end
								end))
								local worldFolder = getWorldFolder()
								local blocks = worldFolder:WaitForChild("Blocks", math.huge)
								table.insert(kitTrackerConnections[ent], blocks.ChildAdded:Connect(function(obj)
									if obj.Name == 'black_market_shop' and obj:GetAttribute('PlacedByUserId') == ent.Player.UserId then
									local billboard = Instance.new('BillboardGui')
									billboard.Parent = obj
									billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
									billboard.Size = UDim2.fromOffset(36, 36)
									billboard.AlwaysOnTop = true
									billboard.ClipsDescendants = false
									local blur = addBlur(billboard)
									blur.Visible = Background.Enabled
									local image = Instance.new('ImageLabel')
									image.Size = UDim2.fromOffset(36, 36)
									image.Position = UDim2.fromScale(0.5, 0.5)
									image.AnchorPoint = Vector2.new(0.5, 0.5)
									image.BackgroundColor3 = Color3.fromHSV(0, 0, 0)
									image.BackgroundTransparency = 0.85
									image.BorderSizePixel = 0
									image.Image = bedwars.getIcon({itemType = 'shadow_coin'}, true)
									image.Parent = billboard
									local uicorner = Instance.new('UICorner')
									uicorner.CornerRadius = UDim.new(0, 4)
									uicorner.Parent = image
									if not billboardCache[ent] then billboardCache[ent] = {} end
									table.insert(billboardCache[ent], billboard)
									end
								end))
							end)
						end
					elseif playerKit == 'wizard' then
						ktLabel.TextColor3 = Color3.fromRGB(100, 70, 220)
						local function getStaffTier(v)
							local inv = store.inventories[v] and store.inventories[v].items or {}
							for _, item in inv do
								local nowstr = string.lower(item.itemType or '')
								if string.find(nowstr, 'wizard_staff') then
									return tonumber(item.itemType:sub(#item.itemType, #item.itemType)) or 1
								end
							end
						end
						local tier = getStaffTier(ent.Player)
						if not tier or tier < 0 then ktLabel.Text = '' return end
						ktLabel.Text = '【' .. (vkRoman[tier] or tostring(tier)) .. '】'
					elseif playerKit == 'aery' then
						ktLabel.TextColor3 = Color3.fromRGB(130, 210, 255)
						local stacks = ent.Player:GetAttribute('AeryStacks') or 0
						ktLabel.Text = '【' .. tostring(stacks) .. '】'
					elseif playerKit == 'mimic' then
						ktLabel.TextColor3 = Color3.fromRGB(180, 210, 60)
						ktLabel.Text = ''
						if not ktEventsBound then
							ktEventsBound = true
							if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
							task.spawn(function()
								if vape.ThreadFix then setthreadidentity(8) end
								table.insert(kitTrackerConnections[ent], bedwars.Client:OnEvent("ValidatedMimicBlock", function(p14)
									if not KitTracker.Enabled then ktLabel.Text = '' return end
									if vape.ThreadFix then setthreadidentity(8) end
									if p14.player == ent.Player then
										ktLabel.Text = '【 👔 】'
									else
										ktLabel.Text = ''
									end
								end))
								local val = workspace:FindFirstChild('DisguisedPlayerBlock_' .. ent.Player.UserId) ~= nil
								if val then ktLabel.Text = '【 👔 】' end
							end)
						end
					elseif playerKit == 'disruptor' then
						ktLabel.TextColor3 = Color3.fromRGB(40, 180, 140)
						if not ktEventsBound then
							ktEventsBound = true
							if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
							task.spawn(function()
								local worldFolder = getWorldFolder()
								local blocks = worldFolder:WaitForChild("Blocks", math.huge)
								table.insert(kitTrackerConnections[ent], blocks.ChildAdded:Connect(function(obj)
									if obj.Name == 'satellite_dish' and obj:GetAttribute('PlacedByUserId') == ent.Player.UserId then
									local billboard = Instance.new('BillboardGui')
									billboard.Parent = obj
									billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
									billboard.Size = UDim2.fromOffset(36, 36)
									billboard.AlwaysOnTop = true
									billboard.ClipsDescendants = false
									local blur = addBlur(billboard)
									blur.Visible = Background.Enabled
									local image = Instance.new('ImageLabel')
									image.Size = UDim2.fromOffset(36, 36)
									image.Position = UDim2.fromScale(0.5, 0.5)
									image.AnchorPoint = Vector2.new(0.5, 0.5)
									image.BackgroundColor3 = Color3.fromHSV(0, 0, 0)
									image.BackgroundTransparency = 0.85
									image.BorderSizePixel = 0
									image.Image = bedwars.getIcon({itemType = 'satellite_dish'}, true)
									image.Parent = billboard
									local uicorner = Instance.new('UICorner')
									uicorner.CornerRadius = UDim.new(0, 4)
									uicorner.Parent = image
									if not billboardCache[ent] then billboardCache[ent] = {} end
									table.insert(billboardCache[ent], billboard)
									end
								end))
							end)
						end
						ktLabel.Text = '【 ' .. (ent.Player:GetAttribute('DisruptorTarget') and ent.Player:GetAttribute('DisruptorTarget') .. ' Team' or 'Unknown Team') .. ' 】'
					elseif playerKit == 'winter_lady' then
						ktLabel.TextColor3 = Color3.fromRGB(200, 225, 255)
						local function getWandTier(v)
							local inv = store.inventories[v] and store.inventories[v].items or {}
							for _, item in inv do
								local nowstr = string.lower(item.itemType or '')
								if string.find(nowstr, 'frost_staff') then
									return tonumber(item.itemType:sub(#item.itemType, #item.itemType)) or 1
								end
							end
						end
						local tier = getWandTier(ent.Player)
						if not tier or tier < 0 then ktLabel.Text = '' return end
						ktLabel.Text = '【' .. (vkRoman[tier] or tostring(tier)) .. '】'
					elseif playerKit == 'warrior' then
						ktLabel.TextColor3 = Color3.fromRGB(220, 60, 60)
						local grit = ent.Player:GetAttribute('Grit') or 0
						ktLabel.Text = '【 ' .. tostring(grit) .. '/100】'
					else
						ktLabel.Text = ''
					end
				end

				updateKtLabel()

				if ent.Character then
					if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
					table.insert(kitTrackerConnections[ent], ent.Character.AttributeChanged:Connect(function(attr)
						if attr == 'BlockKickerKit_BlockCount' or attr == 'StatusEffect_powdered_stacks' then
							updateKtLabel()
						end
					end))
					table.insert(kitTrackerConnections[ent], ent.Player.AttributeChanged:Connect(function(attr)
						if attr == 'DisruptorTarget' or attr == 'DisruptorActivation'
						or attr == 'AeryStacks' or attr == 'VoidKnightTier'
						or attr == 'PaladinStartTime' or attr == 'Summoner_ClawLevel'
						or attr == 'Grit' then
							updateKtLabel()
						end
					end))
					table.insert(kitTrackerConnections[ent], ent.Character.ChildAdded:Connect(function(child)
						if child.Name == 'elk' or string.find(child.Name, "wizard_staff") or string.find(child.Name, "frost_staff") then
							updateKtLabel()
						end
					end))
					table.insert(kitTrackerConnections[ent], ent.Character.ChildRemoved:Connect(function(child)
						if child and (child.Name == 'elk' or string.find(child.Name, "wizard_staff") or string.find(child.Name, "frost_staff")) then
							updateKtLabel()
						end
					end))
					table.insert(kitTrackerConnections[ent], workspace.ChildAdded:Connect(function(child)
						if child and child.Name:sub(1, 20) == 'DisguisedPlayerBlock' then
							updateKtLabel()
						end
					end))
					table.insert(kitTrackerConnections[ent], workspace.ChildRemoved:Connect(function(child)
						if child and child.Name:sub(1, 20) == 'DisguisedPlayerBlock' then
							updateKtLabel()
						end
					end))
				end
				if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
				table.insert(kitTrackerConnections[ent], ent.Player:GetAttributeChangedSignal('PlayingAsKits'):Connect(updateKtLabel))
			  end)
			end

			if Potions.Enabled then
				local baseX = -39 + ((Loot.Enabled and 3 or 0) + (NTBedBreak.Enabled and 2 or 0)) * 34
				for i, def in potionDefs do
					local iconSc = Scale.Value
					local Icon = Instance.new('ImageLabel')
					Icon.Name = def.name
					Icon.Size = udim2fromOffset(26 * iconSc, 26 * iconSc)
					Icon.Position = udim2fromOffset((baseX + ((i - 1) * 28)) * iconSc, (Equipment.Enabled and -58 or -30) * iconSc)
					Icon.BackgroundTransparency = 1
					Icon.Image = ''
					Icon.Parent = nametag
				end
			end

			if Loot.Enabled then
				local lootDefs = { LootIron = 'iron', LootDiamond = 'diamond', LootEmerald = 'emerald' }
				for i, v in { 'LootIron', 'LootDiamond', 'LootEmerald' } do
					makeCountSlot(nametag, v, -39 + ((i - 1) * 34), Equipment.Enabled and -58 or -30, Scale.Value)
				end

				local function applyLootIcons()
					if not (NameTags.Enabled and Loot.Enabled and nametag and nametag.Parent and ent.Player) then return end
					local inventory = store.inventories[ent.Player]
					if not inventory and bedwars.getInventory then
						inventory = bedwars.getInventory(ent.Player)
						if inventory then store.inventories[ent.Player] = inventory end
					end
					if not inventory then return end
					local counts = { iron = 0, diamond = 0, emerald = 0 }
					for _, it in inventory.items or {} do
						if counts[it.itemType] ~= nil then
							counts[it.itemType] = counts[it.itemType] + (it.amount or 0)
						end
					end
					for slot, nm in lootDefs do
						local ic = nametag:FindFirstChild(slot)
						if ic then
							local c = counts[nm]
							if c > 0 then
								ic.Image = bedwars.getIcon({ itemType = nm }, true)
								if ic.Amt then ic.Amt.Text = kCount(c) end
							else
								ic.Image = ''
								if ic.Amt then ic.Amt.Text = '' end
							end
						end
					end
				end

				applyLootIcons()
				if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
				table.insert(kitTrackerConnections[ent], vapeEvents.InventoryChanged.Event:Connect(function()
					if nametag and nametag.Parent then applyLootIcons() end
				end))
			end

			if NTBedBreak.Enabled and ent.Player then
				local bbX = Loot.Enabled and 63 or -39
				local bbY = Equipment.Enabled and -58 or -30
				makeCountSlot(nametag, 'LootTnt', bbX, bbY, Scale.Value)
				makeCountSlot(nametag, 'LootSiege', bbX + 34, bbY, Scale.Value)
				applyBedBreakIcon(ent, nametag)
				if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
				table.insert(kitTrackerConnections[ent], vapeEvents.InventoryChanged.Event:Connect(function()
					if NameTags.Enabled and nametag and nametag.Parent then applyBedBreakIcon(ent, nametag) end
				end))
			end

			if Equipment.Enabled then
				for i, v in { 'Hand', 'Helmet', 'Chestplate', 'Boots' } do
					local Icon = Instance.new('ImageLabel')
					Icon.Name = v
					local iconSc = Scale.Value
					Icon.Size = udim2fromOffset(30 * iconSc, 30 * iconSc)
					Icon.Position = udim2fromOffset((-60 + (i * 30)) * iconSc, -30 * iconSc)
					Icon.BackgroundTransparency = 1
					Icon.Image = ''
					Icon.Parent = nametag
					if v == 'Hand' then
						local amt = Instance.new('TextLabel')
						amt.Name = 'Amt'
						amt.AnchorPoint = Vector2.new(0, 1)
						amt.Position = UDim2.new(0, 0, 1, 0)
						amt.Size = UDim2.new(0, 14 * iconSc, 0, 10 * iconSc)
						amt.BackgroundTransparency = 1
						amt.Text = ''
						amt.TextColor3 = Color3.fromRGB(255, 255, 255)
						amt.TextStrokeTransparency = 0.4
						amt.TextSize = 10 * iconSc
						amt.Font = Enum.Font.GothamBold
						amt.TextXAlignment = Enum.TextXAlignment.Left
						amt.TextYAlignment = Enum.TextYAlignment.Bottom
						amt.Parent = Icon
					end
				end

				local equipRetry = nil
				local function applyEquipmentIcons(attempt)
					if not ent.Player then return end
					if not (NameTags.Enabled and Equipment.Enabled and nametag and nametag.Parent) then return end
					local inventory = store.inventories[ent.Player]
					if not inventory and bedwars.getInventory then
						inventory = bedwars.getInventory(ent.Player)
						if inventory then store.inventories[ent.Player] = inventory end
					end
					if not inventory then
						if equipRetry then task.cancel(equipRetry) end
						local wait = math.min(0.1 * (attempt or 1), 1)
						equipRetry = task.delay(wait, function()
							equipRetry = nil
							applyEquipmentIcons((attempt or 1) + 1)
						end)
						return
					end
					local handItem = inventory.hand
					local kit = ent.Player:GetAttribute('PlayingAsKits')
					local handImage = bedwars.getIcon(handItem or { itemType = '' }, true)
					if nametag.Hand then
						nametag.Hand.Image = handImage
						if nametag.Hand.Amt then
							local a = handItem and handItem.amount
							nametag.Hand.Amt.Text = (a and a > 1) and tostring(a) or ''
						end
					end
					if nametag.Helmet then nametag.Helmet.Image = bedwars.getIcon(inventory.armor and inventory.armor[4] or { itemType = '' }, true) end
					local chestImage = bedwars.getIcon(inventory.armor and inventory.armor[5] or { itemType = '' }, true)
					if kit == 'tinker' then
						local level = ent.Player:GetAttribute('TinkerMachineLevel')
						if level and level >= 1 and level <= 5 then
							local mechImg = getChainsawImage(level)
							if mechImg and mechImg ~= '' then
								chestImage = mechImg
							end
						end
					end
					if nametag.Chestplate then nametag.Chestplate.Image = chestImage end
					if nametag.Boots then nametag.Boots.Image = bedwars.getIcon(inventory.armor and inventory.armor[6] or { itemType = '' }, true) end
				end
				applyEquipmentIcons()
				if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
				table.insert(kitTrackerConnections[ent], vapeEvents.InventoryChanged.Event:Connect(function()
					if nametag and nametag.Parent then
						applyEquipmentIcons()
					end
				end))

				if ent.Player then
					local attrConn = ent.Player:GetAttributeChangedSignal('TinkerMachineLevel'):Connect(function()
						if Equipment.Enabled and nametag and nametag.Parent then
							applyEquipmentIcons()
						end
					end)
					if not kitTrackerConnections[ent] then
						kitTrackerConnections[ent] = {}
					end
					table.insert(kitTrackerConnections[ent], attrConn)
				end
			end

			if ShowKits.Enabled and ent.Player then
				local kitIcon = Instance.new('ImageLabel')
				kitIcon.Name = 'KitIcon'
				kitIcon.Size = udim2fromOffset(30, 30)
				kitIcon.AnchorPoint = vector2new(0.5, 0)
				kitIcon.BackgroundTransparency = 1
				kitIcon.Image = ''

				if Equipment.Enabled then
					kitIcon.Position = udim2fromOffset(110, -30)
				else
					kitIcon.Position = UDim2.new(0.5, 0, 0, -35)
				end

				kitIcon.Parent = nametag

				local kit = ent.Player:GetAttribute('PlayingAsKits')
				if kit then
					local kitImage = kitImageIds[kit:lower()]
					kitIcon.Image = kitImage or kitImageIds["none"]
					kitCache[ent] = kitImage or kitImageIds["none"]
				else
					kitIcon.Image = kitImageIds["none"]
					kitCache[ent] = kitImageIds["none"]
				end
			end

			if DeviceIcon and DeviceIcon.Enabled and ent.Player then
				local function getPlayerDevice(plr)
					local val = plr:GetAttribute('UserInputType') or 'Unknown'
					if not val then return 'Unknown' end
					val = val:upper()
					if val == 'MOBILE' then return 'Mobile'
					elseif val == 'GAMEPAD' or val == 'CONTROLLER' then return 'Controller'
					else return 'PC' end
				end
				local deviceType = getPlayerDevice(ent.Player)
				if deviceType then
					local deviceEmoji = {Mobile = '📱', PC = '🖥', Controller = '🎮', Unknown = '❔'}
					local deviceLabel = Instance.new('TextLabel')
					deviceLabel.Name = 'DeviceIcon'
					deviceLabel.Size = udim2fromOffset(22, 22)
					deviceLabel.AnchorPoint = vector2new(0, 0)
					deviceLabel.Position = UDim2.new(1, 10, 0, -1)
					deviceLabel.BackgroundTransparency = 1
					deviceLabel.BorderSizePixel = 0
					deviceLabel.Text = deviceEmoji[deviceType] or ''
					deviceLabel.RichText = false
					deviceLabel.TextScaled = false
					deviceLabel.TextSize = 16
					deviceLabel.FontFace = Font.fromEnum(Enum.Font.Arial)
					deviceLabel.TextColor3 = Color3.new(1, 1, 1)
					deviceLabel.Parent = nametag
				end
			end

			if Rank.Enabled and ent.Player then
				local rankIcon = Instance.new('ImageLabel')
				rankIcon.Name = 'RankIcon'
				rankIcon.Size = udim2fromOffset(30, 30)
				rankIcon.Position = UDim2.new(1, (DeviceIcon and DeviceIcon.Enabled and 42 or 10), 0, -4)
				rankIcon.BackgroundTransparency = 1
				rankIcon.Image = ''
				rankIcon.Parent = nametag

				task.spawn(function()
					task.wait(math.random() * 0.5)
					if not NameTags.Enabled then return end
					if vape.ThreadFix then setthreadidentity(8) end
					local plr = playersService:GetPlayerFromCharacter(ent.Character)
					if not plr then return end
					if not rankIcon or not rankIcon.Parent then return end

					local ok, success, data = pcall(function()
						return bedwars.Client:Get(remotes.Ranks):CallServerAsync({ plr.UserId }):await()
					end)

					if vape.ThreadFix then setthreadidentity(8) end

					if ok and success and type(data) == "table" then
						local division = data[1] and data[1].rankDivision
						if division and bedwars.RankMeta and bedwars.RankMeta[division] then
							if rankIcon and rankIcon.Parent then
								rankIcon.Image = bedwars.RankMeta[division].image
							end
						end
					end
				end)
			end

			if GloopIndicator and GloopIndicator.Enabled and ent.Character then
				local gloopIcon = Instance.new('ImageLabel')
				gloopIcon.Name = 'GloopIcon'
				gloopIcon.Size = udim2fromOffset(24, 24)
				gloopIcon.BackgroundTransparency = 1
				gloopIcon.Image = bedwars.getIcon({itemType = 'glue_projectile'}, true)
				gloopIcon.Visible = false
				if Rank.Enabled and DeviceIcon and DeviceIcon.Enabled then
					gloopIcon.Position = UDim2.new(1, 74, 0, -2)
				elseif Rank.Enabled or (DeviceIcon and DeviceIcon.Enabled) then
					gloopIcon.Position = UDim2.new(1, 42, 0, -2)
				else
					gloopIcon.Position = UDim2.new(1, 10, 0, -2)
				end
				gloopIcon.Parent = nametag
				local gloopTimer = nil
				if gloopConnections[ent] then gloopConnections[ent]:Disconnect() end
				gloopConnections[ent] = ent.Character.AttributeChanged:Connect(function(attr)
					if attr ~= 'GlueSlow' then return end
					local val = ent.Character:GetAttribute('GlueSlow')
					if val ~= nil and val ~= 0 then
						gloopIcon.Visible = true
						if gloopTimer then task.cancel(gloopTimer) end
						gloopTimer = task.delay(10, function()
							gloopIcon.Visible = false
							gloopTimer = nil
						end)
					end
				end)
			end

			if Enchant.Enabled and ent.Player and ent.Character then
				local Icon = Instance.new('ImageLabel')
				Icon.Name = 'EnchantIcon'
				Icon.Size = udim2fromOffset(30, 30)
				Icon.Position = udim2fromOffset(-30, -4)
				Icon.BackgroundTransparency = 1
				Icon.Image = getActiveEnchantImage(ent.Character)
				Icon.Parent = nametag
				enchantCache[ent] = Icon.Image
				if enchantConnections[ent] then enchantConnections[ent]:Disconnect() end
				enchantConnections[ent] = ent.Character.AttributeChanged:Connect(function(attr)
					if attr:sub(1, 13) ~= 'StatusEffect_' then return end
					local val = ent.Character:GetAttribute(attr)
					if type(val) ~= 'number' then return end
					local newImage = getActiveEnchantImage(ent.Character)
					if enchantCache[ent] ~= newImage then
						Icon.Image = newImage
						enchantCache[ent] = newImage
					end
				end)
			end

			Reference[ent] = nametag
			charCache[ent] = ent.Character
			lastUpdate[ent] = 0
		end,

		Drawing = function(ent)
			if not shouldShow(ent) then return end
			if Reference[ent] then return end

			local bg = Drawing.new('Square')
			bg.Filled = true
			bg.Thickness = 0
			bg.Color = color3new(0, 0, 0)
			bg.Transparency = 1 - Background.Value
			bg.ZIndex = 1
			bg.Visible = false

			local text = Drawing.new('Text')
			text.Center = false
			text.Outline = true
			text.OutlineColor = color3new(0, 0, 0)
			text.Size = math_round(14 * Scale.Value)
			text.Font = 2
			text.Color = getTeamColor(ent) or color3fromHSV(Color.Hue, Color.Sat, Color.Value)
			text.ZIndex = 2
			text.Visible = false

			local baseName = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or (getBossDisplayName(ent) or (ent.Character and ent.Character.Name)) or ''
			local built = baseName
			if Health.Enabled then built = built .. ' ' .. healthPlain(ent) end
			if ShowKits.Enabled and ent.Player then
				local kit = ent.Player:GetAttribute('PlayingAsKits')
				if kit then
					built = built .. ' (' .. (kit:gsub('_', ' '):gsub('^%l', string.upper)) .. ')'
				end
			end
			if Distance.Enabled then
				Strings[ent] = '[%s] ' .. built
			else
				Strings[ent] = built
				text.Text = built
				bg.Size = vector2new(text.TextBounds.X + 8, text.TextBounds.Y + 7)
			end

			Reference[ent] = {Text = text, BG = bg}
			charCache[ent] = ent.Character
		end
	}

	Removed = {
		Normal = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				lastUpdate[ent] = nil
				kitCache = {}
				equipmentCache = {}
				lootCache = {}
				enchantCache = {}
				healthCache[ent] = nil
				charCache[ent] = nil
				if enchantConnections[ent] then
					enchantConnections[ent]:Disconnect()
					enchantConnections[ent] = nil
				end
				if gloopConnections[ent] then
					gloopConnections[ent]:Disconnect()
					gloopConnections[ent] = nil
				end
				if kitTrackerConnections[ent] then
					for _, c in ipairs(kitTrackerConnections[ent]) do
						pcall(function() c:Disconnect() end)
					end
					kitTrackerConnections[ent] = nil
				end
				if billboardCache[ent] then
					for _, b in ipairs(billboardCache[ent]) do
						pcall(function() b:Destroy() end)
					end
					billboardCache[ent] = nil
				end
				v:Destroy()
			end
		end,
		Drawing = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				lastUpdate[ent] = nil
				kitCache[ent] = nil
				healthCache[ent] = nil
				if enchantConnections[ent] then
					enchantConnections[ent]:Disconnect()
					enchantConnections[ent] = nil
				end
				if gloopConnections[ent] then
					gloopConnections[ent]:Disconnect()
					gloopConnections[ent] = nil
				end
				if billboardCache[ent] then
					for _, b in ipairs(billboardCache[ent]) do
						pcall(function() b:Destroy() end)
					end
					billboardCache[ent] = nil
				end
				for _, obj in v do
					pcall(function()
						obj.Visible = false
						obj:Remove()
					end)
				end
			end
		end
	}

	local Updated = {
		Normal = function(ent)
			local nametag = Reference[ent]
			if not nametag then return end

			local now = tick()
			if lastUpdate[ent] and (now - lastUpdate[ent]) < 0.2 then return end
			lastUpdate[ent] = now

			Sizes[ent] = nil
			local bossDisplayName = ent.NPC and ent.Character and getBossDisplayName(ent) or nil
			local entityName = bossDisplayName or (ent.Player and nil) or ent.Character.Name
			Strings[ent] = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or entityName

			if Health.Enabled then
				Strings[ent] = Strings[ent]..' '..healthRich(ent)
			end

			if Distance.Enabled then
				Strings[ent] = '[%s] ' .. Strings[ent]
			end

			if Equipment.Enabled and ent.Player then
				if not store.inventories[ent.Player] and bedwars.getInventory then
					local fetched = bedwars.getInventory(ent.Player)
					if fetched then store.inventories[ent.Player] = fetched end
				end
				local inventory = store.inventories[ent.Player] or {hand = nil, armor = {}}
				local handItem = inventory.hand
				local kit = ent.Player:GetAttribute('PlayingAsKits')
				local handImage = bedwars.getIcon(handItem or { itemType = '' }, true)
				local chestImage = bedwars.getIcon(inventory.armor and inventory.armor[5] or { itemType = '' }, true)
				if kit == 'tinker' then
					local level = ent.Player:GetAttribute('TinkerMachineLevel')
					if level and level >= 1 and level <= 5 then
						local mechImg = getChainsawImage(level)
						if mechImg and mechImg ~= '' then
							chestImage = mechImg
						end
					end
				end
				local currentEquip = {
					tostring(handItem and handItem.itemType or ''),
					tostring((inventory.armor and inventory.armor[4] and inventory.armor[4].itemType) or ''),
					tostring((inventory.armor and inventory.armor[5] and inventory.armor[5].itemType) or ''),
					tostring((inventory.armor and inventory.armor[6] and inventory.armor[6].itemType) or '')
				}
				local equipKey = table.concat(currentEquip, "|")
				if equipmentCache[ent] ~= equipKey then
					equipmentCache[ent] = equipKey
					if nametag.Hand then
						nametag.Hand.Image = handImage
						if nametag.Hand.Amt then
							local a = handItem and handItem.amount
							nametag.Hand.Amt.Text = (a and a > 1) and tostring(a) or ''
						end
					end
					if nametag.Helmet then
						nametag.Helmet.Image = bedwars.getIcon(inventory.armor and inventory.armor[4] or { itemType = '' }, true)
					end
					if nametag.Chestplate then
						nametag.Chestplate.Image = chestImage
					end
					if nametag.Boots then
						nametag.Boots.Image = bedwars.getIcon(inventory.armor and inventory.armor[6] or { itemType = '' }, true)
					end
				end
			end

			local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, vector2new(100000, 100000))
			nametag.Size = udim2fromOffset(size.X + 8, size.Y + 7)
			nametag.Text = Strings[ent]
			nametag.TextColor3 = getTeamColor(ent) or color3fromHSV(Color.Hue, Color.Sat, Color.Value)
		end,

		Drawing = function(ent)
			local nametag = Reference[ent]
			if nametag then
				if vape.ThreadFix then setthreadidentity(8) end
				Sizes[ent] = nil
				local bossDisplayName = ent.NPC and ent.Character and getBossDisplayName(ent) or nil
				local entityName = bossDisplayName or (ent.Player and nil) or ent.Character.Name
				Strings[ent] = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or entityName

				if Health.Enabled then
					Strings[ent] = Strings[ent]..' '..healthPlain(ent)
					nametag.Text.Color = getHealthColor(ent)
				end

				if Distance.Enabled then
					Strings[ent] = '[%s] ' .. Strings[ent]
					nametag.Text.Text = entitylib.isAlive and string_format(Strings[ent], math_floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
				else
					nametag.Text.Text = Strings[ent]
				end

				if ShowKits.Enabled and ent.Player then
					local kit = ent.Player:GetAttribute('PlayingAsKits')
					if kit then
						local kitName = kit:gsub("_", " "):gsub("^%l", string.upper)
						nametag.Text.Text = nametag.Text.Text .. ' (' .. kitName .. ')'
					end
				end

				nametag.BG.Size = vector2new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
				if not Health.Enabled then
					nametag.Text.Color = getTeamColor(ent) or color3fromHSV(Color.Hue, Color.Sat, Color.Value)
				end
			end
		end
	}

	local ColorFunc = {
		Normal = function(hue, sat, val)
			local color = color3fromHSV(hue, sat, val)
			for i, v in Reference do
				v.TextColor3 = getTeamColor(i) or color
			end
		end,
		Drawing = function(hue, sat, val)
			local color = color3fromHSV(hue, sat, val)
			for i, v in Reference do
				if not Health.Enabled then
					v.Text.Color = getTeamColor(i) or color
				end
			end
		end
	}

	local frameCounter = 0
	Loop = {
		Normal = function()
			frameCounter = frameCounter + 1
			local skipVisCheck = frameCounter % 2 ~= 0
			local updateDistText = frameCounter % 3 == 0
			local updateEquipment = frameCounter % 30 == 0
			local forceEquip = frameCounter % 150 == 0
			local updateKit = frameCounter % 30 == 0
			local updateDistanceText = frameCounter % 6 == 0
			local myPos = entitylib.isAlive and entitylib.character.RootPart and entitylib.character.RootPart.Position

			for ent, nametag in Reference do
				if not ent.RootPart or not ent.Character or not ent.Character.Parent or (ent.Health ~= nil and ent.Health <= 0) then
					nametag.Visible = false
					continue
				end
				if DistanceCheck.Enabled then
					local distance = myPos and (myPos - ent.RootPart.Position).Magnitude or math_huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						nametag.Visible = false
						continue
					end
				end

				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + vector3new(0, ent.HipHeight + 1, 0))
				if not skipVisCheck then
					nametag.Visible = headVis
				end
				if not nametag.Visible or not headVis then continue end
				nametag.Position = udim2fromOffset(headPos.X, headPos.Y)

				if Health.Enabled and (frameCounter % 2 == 0) then
					local hp = healthRich(ent)
					if healthCache[ent] ~= hp then
						healthCache[ent] = hp
						local baseName = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or (getBossDisplayName(ent) or (ent.Character and ent.Character.Name)) or ''
						Strings[ent] = baseName..' '..hp
						if Distance.Enabled then
							Strings[ent] = '[%s] ' .. Strings[ent]
						else
							nametag.Text = Strings[ent]
							local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, vector2new(100000, 100000))
							nametag.Size = udim2fromOffset(size.X + 8, size.Y + 7)
						end
						Sizes[ent] = nil
					end
				end

				if Distance.Enabled and updateDistText then
					local mag = myPos and math_floor((myPos - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text = string_format(Strings[ent], mag)
						if updateDistanceText then
							local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, vector2new(100000, 100000))
							nametag.Size = udim2fromOffset(size.X + 8, size.Y + 7)
						end
						Sizes[ent] = mag
					end
				end

				if Equipment.Enabled and (updateEquipment or forceEquip) then
					if ent.Player and not store.inventories[ent.Player] and bedwars.getInventory then
						local fetched = bedwars.getInventory(ent.Player)
						if fetched then store.inventories[ent.Player] = fetched end
					end
					if ent.Player and store.inventories[ent.Player] then
						local inventory = store.inventories[ent.Player]
						local handItem = inventory.hand
						local currentEquip = {
							(handItem and handItem.itemType) or '',
							(inventory.armor and inventory.armor[4] and inventory.armor[4].itemType) or '',
							(inventory.armor and inventory.armor[5] and inventory.armor[5].itemType) or '',
							(inventory.armor and inventory.armor[6] and inventory.armor[6].itemType) or ''
						}
						local equipKey = table.concat(currentEquip, "|")
						local iconsBlank = nametag.Hand and (nametag.Hand.Image == '' or nametag.Hand.Image == nil)
						if equipmentCache[ent] ~= equipKey or forceEquip or (iconsBlank and equipKey ~= "|||") then
							local kit = ent.Player:GetAttribute('PlayingAsKits')
							local handImage = bedwars.getIcon(handItem or { itemType = '' }, true)
							local chestImage = bedwars.getIcon(inventory.armor and inventory.armor[5] or { itemType = '' }, true)
							if kit == 'tinker' then
								local level = ent.Player:GetAttribute('TinkerMachineLevel')
								if level and level >= 1 and level <= 5 then
									local mechImg = getChainsawImage(level)
									if mechImg and mechImg ~= '' then
										chestImage = mechImg
									end
								end
							end
							equipmentCache[ent] = equipKey
							if nametag.Hand then
								nametag.Hand.Image = handImage
								if nametag.Hand.Amt then
									local a = handItem and handItem.amount
									nametag.Hand.Amt.Text = (a and a > 1) and tostring(a) or ''
								end
							end
							if nametag.Helmet then
								nametag.Helmet.Image = bedwars.getIcon(inventory.armor and inventory.armor[4] or { itemType = '' }, true)
							end
							if nametag.Chestplate then
								nametag.Chestplate.Image = chestImage
							end
							if nametag.Boots then
								nametag.Boots.Image = bedwars.getIcon(inventory.armor and inventory.armor[6] or { itemType = '' }, true)
							end
						end
					elseif ent.Player then
						equipmentCache[ent] = nil
					end
				end

				if Loot.Enabled and (updateEquipment or forceEquip) and ent.Player and nametag.LootIron then
					local inv = store.inventories[ent.Player]
					if not inv and bedwars.getInventory then
						inv = bedwars.getInventory(ent.Player)
						if inv then store.inventories[ent.Player] = inv end
					end
					if inv and inv.items then
						local counts = { iron = 0, diamond = 0, emerald = 0 }
						for _, it in inv.items do
							local c = counts[it.itemType]
							if c then
								counts[it.itemType] = c + (it.amount or 0)
							end
						end
						local lootKey = counts.iron .. '|' .. counts.diamond .. '|' .. counts.emerald
						if lootCache[ent] ~= lootKey or forceEquip then
							lootCache[ent] = lootKey
							for slot, nm in { LootIron = 'iron', LootDiamond = 'diamond', LootEmerald = 'emerald' } do
								local ic = nametag:FindFirstChild(slot)
								if ic then
									local c = counts[nm]
									if c > 0 then
										ic.Image = bedwars.getIcon({ itemType = nm }, true)
										if ic.Amt then ic.Amt.Text = kCount(c) end			dot.Size = UDim2.fromOffset(8, 8)
			dot.Position = UDim2.new(0, 10, 0, 5)
			dot.BackgroundColor3 = displayColor
			dot.BorderSizePixel = 0
			local dotCorner = Instance.new('UICorner')
			dotCorner.CornerRadius = UDim.new(1, 0)
			dotCorner.Parent = dot

			local teamLabel = Instance.new('TextLabel')
			teamLabel.Name = 'TeamLabel'
			teamLabel.Parent = billboard
			teamLabel.BackgroundTransparency = 1
			teamLabel.Size = UDim2.new(1, 0, 0, 18)
			teamLabel.Position = UDim2.new(0, 0, 0, 0)
			teamLabel.Text = teamName
			teamLabel.TextColor3 = displayColor
			teamLabel.TextSize = 13
			teamLabel.Font = Enum.Font.GothamBold
			teamLabel.TextStrokeTransparency = 0.4
			teamLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			teamLabel.TextXAlignment = Enum.TextXAlignment.Center
		end

		local frame = Instance.new('Frame')
		frame.Size = config.isTeamGen and UDim2.new(1, 0, 0, 35) or UDim2.fromScale(1, 1)
		frame.Position = config.isTeamGen and UDim2.new(0, 0, 0, 20) or UDim2.new(0, 0, 0, 0)
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BackgroundTransparency = 0.3
		frame.BorderSizePixel = 0
		frame.Parent = billboard

		if config.isTeamGen and teamId and teamColors[teamId] then
			local stripe = Instance.new('Frame')
			stripe.Name = 'TeamStripe'
			stripe.Parent = frame
			stripe.Size = UDim2.new(0, 3, 1, 0)
			stripe.Position = UDim2.new(0, 0, 0, 0)
			stripe.BackgroundColor3 = displayColor
			stripe.BorderSizePixel = 0
			local stripeCorner = Instance.new('UICorner')
			stripeCorner.CornerRadius = UDim.new(0, 3)
			stripeCorner.Parent = stripe
		end

		local uicorner2 = Instance.new('UICorner')
		uicorner2.CornerRadius = UDim.new(0, 6)
		uicorner2.Parent = frame

		if config.isTeamGen then
			local tierLabel = Instance.new('TextLabel')
			tierLabel.Name = 'Tier'
			tierLabel.Size = UDim2.new(0, 25, 1, 0)
			tierLabel.Position = UDim2.new(0, 8, 0, 0)
			tierLabel.BackgroundTransparency = 1
			tierLabel.Text = "0"
			tierLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
			tierLabel.TextSize = 16
			tierLabel.Font = Enum.Font.GothamBold
			tierLabel.TextStrokeTransparency = 0.5
			tierLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			tierLabel.Parent = frame

			local resources = {
				{name = 'iron',    color = Color3.fromRGB(200, 200, 200), icon = 'iron',    xOffset = 35},
				{name = 'diamond', color = Color3.fromRGB(85, 200, 255),  icon = 'diamond', xOffset = 85},
				{name = 'emerald', color = Color3.fromRGB(0, 255, 100),   icon = 'emerald', xOffset = 135}
			}

			local resourceLabels = {}
			for _, resource in ipairs(resources) do
				local iconImage = getProperIcon(resource.icon)
				if iconImage then
					local image = Instance.new('ImageLabel')
					image.Size = UDim2.fromOffset(18, 18)
					image.Position = UDim2.new(0, resource.xOffset, 0.5, 0)
					image.AnchorPoint = Vector2.new(0, 0.5)
					image.BackgroundTransparency = 1
					image.Image = iconImage
					image.Parent = frame
				end
				local countLabel = Instance.new('TextLabel')
				countLabel.Name = resource.name .. '_count'
				countLabel.Size = UDim2.new(0, 25, 1, 0)
				countLabel.Position = UDim2.new(0, resource.xOffset + 20, 0, 0)
				countLabel.BackgroundTransparency = 1
				countLabel.Text = "0"
				countLabel.TextColor3 = resource.color
				countLabel.TextSize = 16
				countLabel.Font = Enum.Font.GothamBold
				countLabel.TextStrokeTransparency = 0.5
				countLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
				countLabel.TextXAlignment = Enum.TextXAlignment.Left
				countLabel.Parent = frame
				resourceLabels[resource.name] = countLabel
			end

			Reference[generatorAdornee] = {
				billboard = billboard,
				tierLabel = tierLabel,
				ironLabel = resourceLabels.iron,
				diamondLabel = resourceLabels.diamond,
				emeraldLabel = resourceLabels.emerald,
				genType = genType,
				position = position,
				teamId = teamId,
				isTeamGen = true
			}
		else
			local iconImage = getProperIcon(config.icon)
			if iconImage then
				local image = Instance.new('ImageLabel')
				image.Size = UDim2.fromOffset(20, 20)
				image.Position = UDim2.new(0, 5, 0.5, 0)
				image.AnchorPoint = Vector2.new(0, 0.5)
				image.BackgroundTransparency = 1
				image.Image = iconImage
				image.Parent = frame
			end
			local timerLabel = Instance.new('TextLabel')
			timerLabel.Name = 'Timer'
			timerLabel.Size = UDim2.new(0, 30, 1, 0)
			timerLabel.Position = UDim2.new(0.5, 0, 0, 0)
			timerLabel.AnchorPoint = Vector2.new(0.5, 0)
			timerLabel.BackgroundTransparency = 1
			timerLabel.Text = "00"
			timerLabel.TextColor3 = displayColor
			timerLabel.TextSize = 18
			timerLabel.Font = Enum.Font.GothamBold
			timerLabel.TextStrokeTransparency = 0.5
			timerLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			timerLabel.Parent = frame
			local amountLabel = Instance.new('TextLabel')
			amountLabel.Name = 'Amount'
			amountLabel.Size = UDim2.new(0, 20, 1, 0)
			amountLabel.Position = UDim2.new(1, -20, 0, 0)
			amountLabel.BackgroundTransparency = 1
			amountLabel.Text = "0"
			amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			amountLabel.TextSize = 16
			amountLabel.Font = Enum.Font.GothamBold
			amountLabel.TextStrokeTransparency = 0.5
			amountLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			amountLabel.Parent = frame
			Reference[generatorAdornee] = {
				billboard = billboard,
				timerLabel = timerLabel,
				amountLabel = amountLabel,
				genType = genType,
				position = position,
				teamId = teamId,
				isTeamGen = false
			}
		end
		billboard.Enabled = true
	end

	local function updateESP(generatorAdornee)
		local ref = Reference[generatorAdornee]
		if not ref then return end
		if UIStyle.Value == 'Compact' then return end

		if ref.isTeamGen then
			if ref.tierLabel then
				local tierTextLabel = getTierText(generatorAdornee)
				if tierTextLabel and tierTextLabel.Text then
					ref.tierLabel.Text = extractTierLevel(tierTextLabel.Text)
				else
					ref.tierLabel.Text = "0"
				end
			end
			if ref.ironLabel then
				ref.ironLabel.Text = tostring(getResourceCount(ref.position, 'iron'))
			end
			if ref.diamondLabel then
				ref.diamondLabel.Text = tostring(getResourceCount(ref.position, 'diamond'))
			end
			if ref.emeraldLabel then
				ref.emeraldLabel.Text = tostring(getResourceCount(ref.position, 'emerald'))
			end
		else
			local countdownText = getCountdownText(generatorAdornee)
			if countdownText and countdownText.Text then
				local timeLeft = extractSecondsFromText(countdownText.Text)
				if ref.timerLabel then
					ref.timerLabel.Text = string.format("%02d", timeLeft)
					if timeLeft <= 5 then
						ref.timerLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
					elseif timeLeft <= 10 then
						ref.timerLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
					else
						ref.timerLabel.TextColor3 = generatorTypes[ref.genType].color
					end
				end
			else
				if ref.timerLabel then
					ref.timerLabel.Text = "00"
					ref.timerLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
				end
			end
			if ref.amountLabel then
				ref.amountLabel.Text = tostring(getResourceCount(ref.position, ref.genType))
			end
		end
	end

	local function processGeneratorAdornee(obj)
		if obj.Name ~= 'GeneratorAdornee' then return end
		local ok, generatorId = pcall(function() return obj:GetAttribute('Id') end)
		if not ok then return end
		if generatorId == nil then return end
		if type(generatorId) ~= 'string' then return end
		if generatorId == '' then return end

		local position = obj:GetPivot().Position
		local genType, config = getGeneratorType(generatorId)
		if not genType or not config then return end

		local teamId = getGeneratorTeamId(generatorId)
		if isGeneratorEnabled(genType, teamId) then
			createESP(obj, genType, config, position, teamId)
		end
	end

	local function findAllGenerators()
		scanDescendants(workspace, function(obj)
			pcall(processGeneratorAdornee, obj)
		end, GeneratorESP)
	end

	local function refreshESP()
		clearAllESP()
		if GeneratorESP.Enabled then
			findAllGenerators()
		end
	end

	local updateTimer = 0

	GeneratorESP = vape.Categories.Render:CreateModule({
		Name = 'GeneratorESP',
		Function = function(callback)
			if callback then
				findAllGenerators()
				rebuildCompactGenerators()

				GeneratorESP:Clean(workspace.DescendantAdded:Connect(function(obj)
					if not GeneratorESP.Enabled or obj.Name ~= 'GeneratorAdornee' then return end
					task.wait(0.2)
					if not GeneratorESP.Enabled or not obj.Parent then return end
					pcall(processGeneratorAdornee, obj)
					rebuildCompactGenerators()
				end))

				GeneratorESP:Clean(runService.Heartbeat:Connect(function(dt)
					if not GeneratorESP.Enabled then return end
					updateTimer = updateTimer + dt
					if updateTimer < 0.2 then return end
					updateTimer = 0
					if UIStyle.Value ~= 'Compact' then
						resourceDrops = CollectionService:GetTagged('ItemDrop')
					end
					for generatorAdornee, ref in pairs(Reference) do
						if generatorAdornee and generatorAdornee.Parent then
							updateESP(generatorAdornee)
						else
							if ref.billboard then ref.billboard:Destroy() end
							Reference[generatorAdornee] = nil
						end
					end
					updateCompactUI()
				end))

				GeneratorESP:Clean(workspace.DescendantRemoving:Connect(function(obj)
					if not GeneratorESP.Enabled then return end
					if Reference[obj] then
						if Reference[obj].billboard then Reference[obj].billboard:Destroy() end
						Reference[obj] = nil
					end
				end))
			else
				clearAllESP()
			end
		end,
		Tooltip = 'esp for generators showing timer and items count'
	})

	UIStyle = GeneratorESP:CreateDropdown({
		Name = 'UI Style',
		List = {'Original', 'Compact'},
		Default = 'Original',
		Function = function(val)
			local isOriginal = val == 'Original'
			if DiamondToggle then DiamondToggle.Object.Visible = isOriginal end
			if EmeraldToggle then EmeraldToggle.Object.Visible = isOriginal end
			if TeamGenToggle then TeamGenToggle.Object.Visible = isOriginal end
			if ShowOwnTeamGen then ShowOwnTeamGen.Object.Visible = isOriginal and TeamGenToggle.Enabled end
			if ShowEnemyTeamGen then ShowEnemyTeamGen.Object.Visible = isOriginal and TeamGenToggle.Enabled end
			if CompactDiamondToggle then CompactDiamondToggle.Object.Visible = not isOriginal end
			if CompactEmeraldToggle then CompactEmeraldToggle.Object.Visible = not isOriginal end
			refreshESP()
		end,
		Tooltip = 'pick between the norm billboard esp on generators or a ui with timers for generators '
	})

	DiamondToggle = GeneratorESP:CreateToggle({
		Name = 'Diamond',
		Function = function() refreshESP() end,
		Default = false,
		Visible = true
	})

	EmeraldToggle = GeneratorESP:CreateToggle({
		Name = 'Emerald',
		Function = function() refreshESP() end,
		Default = false,
		Visible = true
	})

	CompactDiamondToggle = GeneratorESP:CreateToggle({
		Name = 'Compact Diamond',
		Default = false,
		Visible = false,
		Function = function()
			refreshESP()
		end
	})

	CompactEmeraldToggle = GeneratorESP:CreateToggle({
		Name = 'Compact Emerald',
		Default = false,
		Visible = false,
		Function = function()
			refreshESP()
		end
	})

	TeamGenToggle = GeneratorESP:CreateToggle({
		Name = 'Team Generators',
		Function = function(callback)
			if ShowOwnTeamGen then ShowOwnTeamGen.Object.Visible = callback end
			if ShowEnemyTeamGen then ShowEnemyTeamGen.Object.Visible = callback end
			refreshESP()
		end,
		Default = true
	})

	ShowOwnTeamGen = GeneratorESP:CreateToggle({
		Name = 'Show Own Team',
		Function = function() refreshESP() end,
		Default = false,
		Visible = true
	})

	ShowEnemyTeamGen = GeneratorESP:CreateToggle({
		Name = 'Show Enemy Teams',
		Function = function() refreshESP() end,
		Default = true,
		Visible = true
	})
end)

run(function()
	local VictoriousKitSkins
	local ItemSkinDropdown
	local SkinTypeDropdown
	local RS = game:GetService('ReplicatedStorage')
	local LocalPlayer = lplr
	local RESKIN_NAME = 'LOCAL_ITEM_RESKIN'
	local state = {
		itemSkin = 'Victorious Lyla',
		skinType = 'Nightmare',
	}
	local ok1, ItemType = pcall(function()
		return require(RS.TS.item['item-type']).ItemType
	end)
	if not ok1 then ItemType = {} end
	local ok2, ItemSkinType = pcall(function()
		return require(RS.TS.games.bedwars['item-skin']['item-skin-types']).ItemSkinType
	end)
	if not ok2 then ItemSkinType = {} end
	local KitSkinCtrl
	pcall(function()
		local KC = require(RS.rbxts_include.node_modules['@easy-games'].knit.src).KnitClient
		KitSkinCtrl = KC.Controllers.KitSkinController
	end)

	local VICTORIOUS_ARCHER_BOW_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, -52, math.rad(90))
	local VICTORIOUS_ARCHER_CROSSBOW_ROT = CFrame.new(0.00, 0.00, 0.00) * CFrame.Angles(math.rad(0), math.rad(80), math.rad(0.00))
	local VICTORIOUS_ARCHER_HEADHUNTER_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(0), 0)
	local STAFF_ROT = CFrame.Angles(0, math.rad(90), 0)
	local VIC_ROT = CFrame.new(0, -1.9, 0) * CFrame.Angles(0, math.rad(360), 0)
	local TRIDENT_ROT = CFrame.new(0, 0.5, 0.05) * CFrame.Angles(0, math.rad(180), 0)
	local LYLA_BOW_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(30, -30, 183.56)
	local LYLA_CROSSBOW_ROT = CFrame.Angles(math.rad(0), math.rad(180), math.rad(0))
	local LYLA_HEADHUNTER_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(0), 0)
	local CANNON_HAND_SCALE = 0.34
	local CANNON_PLACED_OFFSET = CFrame.new(0, -1.0, 0)
	local CANNON_TOOL_NAME = "cannon"

	local CANNON_SKIN_NAMES = {
		["Victorious Cannon"] = {
			Gold = "cannon_gold_victorious",
			Platinum = "cannon_platinum_victorious",
			Diamond = "cannon_diamond_victorious",
			Emerald = "cannon_emerald_victorious",
			Nightmare = "cannon_nightmare_victorious",
		},
	}
	local CANNON_SOUND_NAMES = {
		Gold = "CANNON_FIRE_VICTORIOUS_NIGHTMARE",
		Platinum = "CANNON_FIRE_VICTORIOUS_NIGHTMARE",
		Diamond = "CANNON_FIRE_VICTORIOUS_DIAMOND",
		Emerald = "CANNON_FIRE_VICTORIOUS_EMERALD",
		Nightmare = "CANNON_FIRE_VICTORIOUS_NIGHTMARE",
	}
	local SKIN_OFFSETS = {
		["nightmare_victorious_flower_bow"] = LYLA_BOW_ROT,
		["emerald_victorious_flower_bow"] = LYLA_BOW_ROT,
		["diamond_victorious_flower_bow"] = LYLA_BOW_ROT,
		["platinum_victorious_flower_bow"] = LYLA_BOW_ROT,
		["gold_victorious_flower_bow"] = LYLA_BOW_ROT,
		["nightmare_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["emerald_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["diamond_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["platinum_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["gold_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["nightmare_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["emerald_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["diamond_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["platinum_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["gold_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_nightmare"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_emerald"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_diamond"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_platinum"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_gold"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["wood_bow_victorious_nightmare"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_emerald"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_diamond"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_platinum"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_gold"] = VICTORIOUS_ARCHER_BOW_ROT,
		["tactical_crossbow_victorious_nightmare"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_emerald"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_diamond"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_platinum"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_gold"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["victorious_gold_triton"] = TRIDENT_ROT,
		["victorious_platinum_triton"] = TRIDENT_ROT,
		["victorious_diamond_triton"] = TRIDENT_ROT,
		["victorious_emerald_triton"] = TRIDENT_ROT,
		["victorious_nightmare_triton"] = TRIDENT_ROT,
		["gold_victorious_wizard_staff"] = STAFF_ROT,
		["gold_victorious_wizard_staff_2"] = STAFF_ROT,
		["gold_victorious_wizard_staff_3"] = STAFF_ROT,
		["platinum_victorious_wizard_staff"] = STAFF_ROT,
		["platinum_victorious_wizard_staff_2"] = STAFF_ROT,
		["platinum_victorious_wizard_staff_3"] = STAFF_ROT,
		["diamond_victorious_wizard_staff"] = STAFF_ROT,
		["diamond_victorious_wizard_staff_2"] = STAFF_ROT,
		["diamond_victorious_wizard_staff_3"] = STAFF_ROT,
		["emerald_victorious_wizard_staff"] = STAFF_ROT,
		["emerald_victorious_wizard_staff_2"] = STAFF_ROT,
		["emerald_victorious_wizard_staff_3"] = STAFF_ROT,
		["nightmare_victorious_wizard_staff"] = STAFF_ROT,
		["nightmare_victorious_wizard_staff_2"] = STAFF_ROT,
		["nightmare_victorious_wizard_staff_3"] = STAFF_ROT,
		["wood_dao_victorious"] = VIC_ROT,
		["stone_dao_victorious"] = VIC_ROT,
		["iron_dao_victorious"] = VIC_ROT,
		["diamond_dao_victorious"] = VIC_ROT,
		["emerald_dao_victorious"] = VIC_ROT,
	}
	local KIT_SKIN_MAP = {
		["Victorious Lyla"] = { Gold = "gold_victorious_lyla", Platinum = "platinum_victorious_lyla", Diamond = "diamond_victorious_lyla", Emerald = "emerald_victorious_lyla", Nightmare = "nightmare_victorious_lyla" },
		["Victorious Archer"] = { Gold = "archer_victorious_gold", Platinum = "archer_victorious_platinum", Diamond = "archer_victorious_diamond", Emerald = "archer_victorious_emerald", Nightmare = "archer_victorious_nightmare" },
		["Victorious Yuzi"] = { Default = "yuzi_victorious" },
		["Victorious Zeno"] = { Gold = "gold_victorious_wizard", Platinum = "platinum_victorious_wizard", Diamond = "diamond_victorious_wizard", Emerald = "emerald_victorious_wizard", Nightmare = "nightmare_victorious_wizard" },
		["Victorious Triton"] = { Gold = "victorious_gold_triton", Platinum = "victorious_platinum_triton", Diamond = "victorious_diamond_triton", Emerald = "victorious_emerald_triton", Nightmare = "victorious_nightmare_triton" },
		["Victorious Cannon"] = { Gold = "gold_victorious_davey", Platinum = "platinum_victorious_davey", Diamond = "diamond_victorious_davey", Emerald = "emerald_victorious_davey", Nightmare = "nightmare_victorious_davey" },
	}
	local function yuziDaoMap(suffix)
		return {
			wood_dao = "wood_dao_" .. suffix,
			stone_dao = "stone_dao_" .. suffix,
			iron_dao = "iron_dao_" .. suffix,
			diamond_dao = "diamond_dao_" .. suffix,
			emerald_dao = "emerald_dao_" .. suffix,
		}
	end
	local SKIN_DATA = {
		["Victorious Lyla"] = function(t)
			local lt = t:lower()
			return {
				flower_bow = lt .. "_victorious_flower_bow",
				flower_crossbow = lt .. "_victorious_flower_crossbow",
				flower_headhunter = lt .. "_victorious_flower_headhunter",
			}
		end,
		["Victorious Archer"] = function(t)
			local lt = t:lower()
			return {
				wood_bow = "wood_bow_victorious_" .. lt,
				tactical_crossbow = "tactical_crossbow_victorious_" .. lt,
				tactical_headhunter = "tactical_headhunter_victorious_" .. lt,
			}
		end,
		["Victorious Triton"] = function(t)
			return { harpoon = "victorious_" .. t:lower() .. "_triton" }
		end,
		["Victorious Yuzi"] = function() return yuziDaoMap("victorious") end,
		["Victorious Zeno"] = function(t)
			local lt = t:lower()
			return {
				wizard_staff = lt .. "_victorious_wizard_staff",
				wizard_staff_2 = lt .. "_victorious_wizard_staff_2",
				wizard_staff_3 = lt .. "_victorious_wizard_staff_3",
			}
		end,
	}
	local TIERED_SKINS = {
		["Victorious Lyla"] = true,
		["Victorious Archer"] = true,
		["Victorious Zeno"] = true,
		["Victorious Triton"] = true,
		["Victorious Cannon"] = true,
	}

	local active = {}
	local hideList = {}
	local hookConns = {}
	local renderConn
	local oldGetKitSkin
	local oldFireCannon
	local oldLaunchSelf
	local soundsHooked = false
	local refreshVersion = 0

	local function normalizeName(s)
		return s:lower():gsub('[_%s%-]', '')
	end

	local function isCannonSkin()
		return CANNON_SKIN_NAMES[state.itemSkin] ~= nil
	end

	local function getCannonSkinName()
		local tbl = CANNON_SKIN_NAMES[state.itemSkin]
		if not tbl then return nil end
		return tbl[state.skinType] or tbl.Default
	end

	local function getCurrentMappings()
		local fn = SKIN_DATA[state.itemSkin]
		if not fn then return {} end
		local ok, res = pcall(fn, state.skinType)
		if ok and type(res) == 'table' then return res end
		return {}
	end

	local function getKitSkinValue()
		local m = KIT_SKIN_MAP[state.itemSkin]
		if not m then return nil end
		return m[state.skinType] or m.Default
	end

	local function itemsFolder()
		return RS:FindFirstChild('Items')
	end

	local function blocksFolder()
		local assets = RS:FindFirstChild('Assets')
		return assets and assets:FindFirstChild('Blocks')
	end

	local function firstBasePart(root)
		if root:IsA('BasePart') then return root end
		for _, d in root:GetDescendants() do
			if d:IsA('BasePart') then return d end
		end
		return nil
	end

	local function setNoCollide(model)
		local function strip(p)
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			p.Anchored = false
		end
		if model:IsA('BasePart') then strip(model) end
		for _, d in model:GetDescendants() do
			if d:IsA('BasePart') then strip(d) end
		end
	end

	local function weldAllTo(anchor, container)
		for _, d in container:GetDescendants() do
			if d:IsA('BasePart') and d ~= anchor then
				local wc = Instance.new('WeldConstraint')
				wc.Part0 = anchor
				wc.Part1 = d
				wc.Parent = anchor
			end
		end
	end

	local function getRigScale(root)
		local node = root
		local hum
		for _ = 1, 6 do
			if not node or node == workspace then break end
			hum = node:FindFirstChildOfClass('Humanoid')
			if hum then break end
			node = node.Parent
		end
		if not hum then return 1 end
		local total, count = 0, 0
		for _, name in {'BodyHeightScale', 'BodyWidthScale', 'BodyDepthScale'} do
			local v = hum:FindFirstChild(name)
			if v and v:IsA('NumberValue') and v.Value > 0 then
				total = total + v.Value
				count = count + 1
			end
		end
		if count == 0 then return 1 end
		return math.clamp(total / count, 0.3, 3)
	end

	local function startRenderLoop()
		if renderConn then return end
		renderConn = runService.RenderStepped:Connect(function()
			for i = #hideList, 1, -1 do
				local p = hideList[i]
				if p and p.Parent then
					p.LocalTransparencyModifier = 1
				else
					table.remove(hideList, i)
				end
			end
		end)
	end

	local function stopRenderLoop()
		if renderConn then
			pcall(function() renderConn:Disconnect() end)
			renderConn = nil
		end
	end

	local function hideDescendant(entry, d)
		if d:IsA('BasePart') then
			entry.parts[#entry.parts + 1] = {d, d.Transparency}
			d.Transparency = 1
			d.LocalTransparencyModifier = 1
			hideList[#hideList + 1] = d
		elseif d:IsA('Decal') or d:IsA('Texture') then
			entry.decals[#entry.decals + 1] = {d, d.Transparency}
			d.Transparency = 1
		end
	end

	local function hideOriginal(entry, root)
		for _, d in root:GetDescendants() do
			if not d:IsDescendantOf(entry.clone) then
				hideDescendant(entry, d)
			end
		end
	end

	local function detach(root)
		local entry = active[root]
		if not entry then return end
		active[root] = nil
		for _, c in entry.conns do
			pcall(function() c:Disconnect() end)
		end
		if entry.clone then
			pcall(function() entry.clone:Destroy() end)
		end
		for _, rec in entry.parts do
			local p = rec[1]
			local idx = table.find(hideList, p)
			if idx then table.remove(hideList, idx) end
			pcall(function()
				if p.Parent then
					p.Transparency = rec[2]
					p.LocalTransparencyModifier = 0
				end
			end)
		end
		for _, rec in entry.decals do
			local d = rec[1]
			pcall(function()
				if d.Parent then d.Transparency = rec[2] end
			end)
		end
	end

	local function detachAll()
		for root in active do
			detach(root)
		end
		table.clear(active)
		table.clear(hideList)
	end

	local function attachReskin(root, skinName, source, opts)
		if not root or not root.Parent then return end
		if active[root] or not source then return end
		opts = opts or {}

		local origHandle = root:FindFirstChild('Handle')
		if not (origHandle and origHandle:IsA('BasePart')) then
			origHandle = firstBasePart(root)
		end
		if not origHandle then return end

		local clone = source:Clone()
		clone.Name = RESKIN_NAME
		for _, d in clone:GetDescendants() do
			if d:IsA('LuaSourceContainer') then
				pcall(function() d:Destroy() end)
			end
		end
		setNoCollide(clone)

		local anchor
		local alignByPivot = false
		if clone:IsA('BasePart') then
			anchor = clone
		else
			local handle = clone:FindFirstChild('Handle')
			if handle and handle:IsA('BasePart') then
				anchor = handle
			else
				alignByPivot = true
				anchor = clone:IsA('Model') and clone.PrimaryPart or nil
				anchor = anchor or firstBasePart(clone)
			end
		end
		if not anchor then
			pcall(function() clone:Destroy() end)
			return
		end
		if clone:IsA('Model') and not clone.PrimaryPart then
			pcall(function() clone.PrimaryPart = anchor end)
		end

		local scale = (opts.scale or 1) * getRigScale(root)
		if clone:IsA('Model') and math.abs(scale - 1) > 0.001 then
			pcall(function() clone:ScaleTo(scale) end)
		end

		local entry = {clone = clone, parts = {}, decals = {}, conns = {}}
		active[root] = entry
		clone.Parent = root

		local offset = (SKIN_OFFSETS[skinName] or CFrame.identity) * (opts.offset or CFrame.identity)
		local target = origHandle.CFrame * offset
		pcall(function()
			if not clone:IsA('Model') then
				anchor.CFrame = target
			elseif alignByPivot then
				clone:PivotTo(target)
			else
				clone:PivotTo(target * anchor.CFrame:ToObjectSpace(clone:GetPivot()))
			end
		end)

		weldAllTo(anchor, clone)

		local weld = Instance.new('WeldConstraint')
		weld.Part0 = origHandle
		weld.Part1 = anchor
		weld.Parent = anchor

		hideOriginal(entry, root)
		startRenderLoop()

		entry.conns[#entry.conns + 1] = root.DescendantAdded:Connect(function(d)
			if entry.clone and entry.clone.Parent and d:IsDescendantOf(entry.clone) then return end
			hideDescendant(entry, d)
		end)
		entry.conns[#entry.conns + 1] = root.AncestryChanged:Connect(function(_, parent)
			if not parent then detach(root) end
		end)
	end

	local function track(conn)
		hookConns[#hookConns + 1] = conn
		return conn
	end

	local function clearHooks()
		for _, c in hookConns do
			pcall(function() c:Disconnect() end)
		end
		table.clear(hookConns)
	end

	local function deferCall(fn, ...)
		local args = table.pack(...)
		task.spawn(function()
			task.wait()
			fn(table.unpack(args, 1, args.n))
		end)
	end

	local function skinNameForChild(childName)
		local mappings = getCurrentMappings()
		local skinName = mappings[childName:lower()]
		if not skinName then
			local norm = normalizeName(childName)
			for k, v in mappings do
				if normalizeName(k) == norm then
					skinName = v
					break
				end
			end
		end
		return skinName
	end

	local function applyItem(child)
		if not (VictoriousKitSkins and VictoriousKitSkins.Enabled) then return end
		if isCannonSkin() or not child or not child.Parent then return end
		local skinName = skinNameForChild(child.Name)
		if not skinName then return end
		local folder = itemsFolder()
		if not folder then return end
		attachReskin(child, skinName, folder:FindFirstChild(skinName))
	end

	local function applyCannon(child, placed)
		if not (VictoriousKitSkins and VictoriousKitSkins.Enabled) then return end
		if not isCannonSkin() or not child or not child.Parent then return end
		if child.Name ~= CANNON_TOOL_NAME then return end
		local skinName = getCannonSkinName()
		if not skinName then return end
		local folder = blocksFolder()
		if not folder then return end
		attachReskin(child, skinName, folder:FindFirstChild(skinName), {
			offset = placed and CANNON_PLACED_OFFSET or CFrame.identity,
			scale = placed and 1 or CANNON_HAND_SCALE,
		})
	end

	local function applyProjectile(inst)
		if not (VictoriousKitSkins and VictoriousKitSkins.Enabled) then return end
		if isCannonSkin() or not inst or not inst.Parent then return end
		if not inst:IsA('Model') or inst.Name ~= 'harpoon_projectile' then return end
		local shooter = inst:GetAttribute('ProjectileShooter')
		if not shooter or tostring(shooter) ~= tostring(LocalPlayer.UserId) then return end
		local skinName = getCurrentMappings().harpoon
		if not skinName then return end
		local folder = itemsFolder()
		if not folder then return end
		attachReskin(inst, skinName, folder:FindFirstChild(skinName))
	end

	local function hookItemContainer(container)
		if not container then return end
		for _, child in container:GetChildren() do
			deferCall(applyItem, child)
		end
		track(container.ChildAdded:Connect(function(child)
			deferCall(applyItem, child)
		end))
	end

	local function hookCannonContainer(container, placed)
		if not container then return end
		for _, child in container:GetChildren() do
			deferCall(applyCannon, child, placed)
		end
		track(container.ChildAdded:Connect(function(child)
			deferCall(applyCannon, child, placed)
		end))
	end

	local function hookViewmodel(vm)
		if not vm then return end
		if isCannonSkin() then
			hookCannonContainer(vm, false)
		else
			hookItemContainer(vm)
		end
	end

	local function hookCamera(cam)
		if not cam then return end
		local vm = cam:FindFirstChild('Viewmodel')
		if vm then hookViewmodel(vm) end
		track(cam.ChildAdded:Connect(function(child)
			if child.Name == 'Viewmodel' then
				deferCall(hookViewmodel, child)
			end
		end))
	end

	local function hookWorldCannons()
		local map = workspace:FindFirstChild('Map')
		if not map then return end
		local worlds = map:FindFirstChild('Worlds')
		if not worlds then return end
		local function hookWorld(world)
			local blocks = world:FindFirstChild('Blocks')
			if blocks then hookCannonContainer(blocks, true) end
		end
		for _, world in worlds:GetChildren() do
			hookWorld(world)
		end
		track(worlds.ChildAdded:Connect(function(world)
			deferCall(hookWorld, world)
		end))
	end

	local function hookProjectiles()
		track(workspace.DescendantAdded:Connect(function(inst)
			if inst.Name == 'harpoon_projectile' then
				deferCall(applyProjectile, inst)
			end
		end))
	end

	local function applyKitSkinHook()
		if not KitSkinCtrl then return end
		local val = getKitSkinValue()
		if not val then return end
		if not oldGetKitSkin then oldGetKitSkin = KitSkinCtrl.getKitSkin end
		local base = oldGetKitSkin
		KitSkinCtrl.getKitSkin = function(self, char)
			if char == LocalPlayer.Character then return val end
			return base(self, char)
		end
	end

	local function removeKitSkinHook()
		if KitSkinCtrl and oldGetKitSkin then
			KitSkinCtrl.getKitSkin = oldGetKitSkin
			oldGetKitSkin = nil
		end
	end

	local function hookCannonSounds()
		if soundsHooked then return end
		if not (bedwars and bedwars.CannonHandController) then return end
		soundsHooked = true
		oldFireCannon = bedwars.CannonHandController.fireCannon
		oldLaunchSelf = bedwars.CannonHandController.launchSelf

		local function replaceSound()
			pcall(function()
				local pool = workspace:FindFirstChild('SoundPool')
				if pool then
					for _, v in pool:GetChildren() do
						if v:IsA('Sound') and v.SoundId == 'rbxassetid://7121064180' then
							v:Destroy()
						end
					end
				end
				local key = CANNON_SOUND_NAMES[state.skinType] or CANNON_SOUND_NAMES.Nightmare
				if bedwars.SoundManager and bedwars.SoundList and bedwars.SoundList[key] then
					bedwars.SoundManager:playSound(bedwars.SoundList[key])
				end
			end)
		end

		if oldFireCannon then
			bedwars.CannonHandController.fireCannon = function(...)
				replaceSound()
				return oldFireCannon(...)
			end
		end
		if oldLaunchSelf then
			bedwars.CannonHandController.launchSelf = function(...)
				replaceSound()
				return oldLaunchSelf(...)
			end
		end
	end

	local function unhookCannonSounds()
		if soundsHooked and bedwars and bedwars.CannonHandController then
			if oldFireCannon then bedwars.CannonHandController.fireCannon = oldFireCannon end
			if oldLaunchSelf then bedwars.CannonHandController.launchSelf = oldLaunchSelf end
		end
		oldFireCannon = nil
		oldLaunchSelf = nil
		soundsHooked = false
	end

	local function hookCharacter(char)
		if not char then return end
		local backpack = LocalPlayer:FindFirstChildOfClass('Backpack')
		if isCannonSkin() then
			hookCannonContainer(char, false)
			hookCannonContainer(backpack, false)
		else		'wreck',
		'destroy',
		'annihilate',
		'obliterate',
		'decimate',
		'massacre',
		'slaughter',
		'fuck you',
		'shithead',
		'dick',
		'pussy',
		'twat',
		'wanker',
		'bugger',
		'bloody hell',
		'goddamn',
		'holy shit',
		'what the fuck',
		'oh fuck',
		'fucking hell',
		'shitty',
		'crappy',
		'lousy',
		'motherfucking',
		'goddamn shit',
		'fuckface',
		'dipshit',
		'dumbshit',
		'jackass',
		'prick',
		'cocksucker',
		'asshat',
		'buttfuck',
		'fucknut',
		'shitbag',
		'hellfire',
		'fuckshit',
		'damnass',
		'piss off',
		'screw you',
		'bastard shit',
		'fucktard',
		'shitfuck',
		'cunt',
	    'bitchass nigga',
		'nigga',
		'die pls',
		'desire is some ass',
	}
	
	local RGBColors = {
		Color3.fromRGB(255, 255, 255), 
		Color3.fromRGB(0, 0, 0),       
		Color3.fromRGB(128, 0, 128), 
		Color3.fromRGB(0, 0, 255),  
		Color3.fromRGB(75, 0, 130),    
		Color3.fromRGB(0, 100, 255), 
		Color3.fromRGB(200, 200, 255),
		Color3.fromRGB(30, 30, 30)  
	}
	
	local function randomizer(tbl)
	    if not typeof(tbl) == "table" then return end
	    local index = math.random(1,#tbl)
	    local value = tbl[index]
	    return value,index
	end
	local font  = 'Arial'
    DamageTexts = vape.Categories.Render:CreateModule({
        Name = "DamageTexts",
        Function = function(call)
			if call then
				DamageTexts:Clean(workspace.DescendantAdded:Connect(function(part)
				    if part.Name == "DamageIndicatorPart" and part:IsA("BasePart") then
				        for i, v in part:GetDescendants() do
				            if v:IsA("TextLabel") then
				                local txt = randomizer(DamageMessages)
				                local clr = randomizer(RGBColors)
								if customMSG.Enabled then
				                	v.Text = txt
								end
								if Color.Enabled then
				              	  	v.TextColor3 = clr
								end
				            end
				        end
				    end
				end))
			else

			end
        end,
        Tooltip = "Customizes Damage Affects"
    })
	customMSG = DamageTexts:CreateToggle({
		Name = "Custom Messages",
		Default = true
	})
	Color = DamageTexts:CreateToggle({
		Name = "Custom Colors",
		Default = true
	})
	Fonts = DamageTexts:CreateFont({
		Name = 'Font',
		Function = function(val)
			font = val
		end
	})
end)

run(function()
	local PotESP
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local tracked = {}
	local function getSandIcon()
		local ok, icon = pcall(function() return bedwars.getIcon({itemType = 'sand'}, true) end)
		return ok and icon or 'rbxassetid://0'
	end
	local function createESP(obj)
		if tracked[obj] then return end
		if obj.Name:lower() ~= 'desert_pot' then return end
		local bill = Instance.new('BillboardGui')
		bill.Size = UDim2.fromOffset(40, 40)
		bill.Adornee = obj
		bill.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		bill.AlwaysOnTop = true
		bill.Parent = Folder
		local frame = Instance.new('Frame')
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundTransparency = 0.4
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.Parent = bill
		local uic = Instance.new('UICorner')
		uic.CornerRadius = UDim.new(0, 4)
		uic.Parent = frame
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.new(1, -6, 1, -6)
		image.Position = UDim2.new(0.5, 0, 0.5, 0)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundTransparency = 1
		image.Image = getSandIcon()
		image.Parent = frame
		tracked[obj] = bill
	end
	local function removeESP(obj)
		if tracked[obj] then
			tracked[obj]:Destroy()
			tracked[obj] = nil
		end
	end
	local function scanAll()
		scanDescendants(workspace, function(obj)
			createESP(obj)
		end, PotESP)
	end
	local function cleanup()
		for _, bill in pairs(tracked) do
			bill:Destroy()
		end
		table.clear(tracked)
	end
	PotESP = vape.Categories.Render:CreateModule({
		Name = 'PotESP',
		Function = function(callback)
			if callback then
				scanAll()
				PotESP:Clean(workspace.DescendantAdded:Connect(function(obj)
					if obj.Name:lower() ~= 'desert_pot' then return end
					task.wait(0.1)
					if PotESP.Enabled and obj.Parent then
						createESP(obj)
					end
				end))
				PotESP:Clean(workspace.DescendantRemoving:Connect(function(obj)
					if tracked[obj] then
						removeESP(obj)
					end
				end))
			else
				cleanup()
			end
		end,
		Tooltip = 'shows a sand block icon above each desert pot'
	})
end)

run(function()
	local OreESP
	local Background
	local Color
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local tracked = {}
	local function getIronIcon()
		local ok, icon = pcall(function() return bedwars.getIcon({itemType = 'iron'}, true) end)
		return ok and icon or 'rbxassetid://0'
	end
	local function createESP(obj)
		if tracked[obj] then return end
		if obj.Name:lower() ~= 'iron_ore_mesh_block' then return end
		local bill = Instance.new('BillboardGui')
		bill.Size = UDim2.fromOffset(40, 40)
		bill.Adornee = obj
		bill.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		bill.AlwaysOnTop = true
		bill.Parent = Folder
		local frame = Instance.new('Frame')
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundTransparency = Background.Enabled and 0.4 or 1
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.Parent = bill
		local uic = Instance.new('UICorner')
		uic.CornerRadius = UDim.new(0, 4)
		uic.Parent = frame
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.new(1, -6, 1, -6)
		image.Position = UDim2.new(0.5, 0, 0.5, 0)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundTransparency = 1
		image.Image = getIronIcon()
		image.Parent = frame
		tracked[obj] = {Billboard = bill, Frame = frame}
	end
	local function removeESP(obj)
		if tracked[obj] then
			tracked[obj].Billboard:Destroy()
			tracked[obj] = nil
		end
	end
	local function scanAll()
		scanDescendants(workspace, function(obj)
			createESP(obj)
		end, OreESP)
	end
	local function cleanup()
		for _, v in pairs(tracked) do
			v.Billboard:Destroy()
		end
		table.clear(tracked)
	end
	OreESP = vape.Categories.Render:CreateModule({
		Name = 'OreESP',
		Function = function(callback)
			if callback then
				scanAll()
				OreESP:Clean(workspace.DescendantAdded:Connect(function(obj)
					if obj.Name:lower() ~= 'iron_ore_mesh_block' then return end
					task.wait(0.1)
					if OreESP.Enabled and obj.Parent then
						createESP(obj)
					end
				end))
				OreESP:Clean(workspace.DescendantRemoving:Connect(function(obj)
					if tracked[obj] then
						removeESP(obj)
					end
				end))
			else
				cleanup()
			end
		end,
		Tooltip = 'puts an icon above iron ore blocks so u can find em? - idea from piston the goat'
	})
	Background = OreESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color and Color.Object then Color.Object.Visible = callback end
			for _, v in pairs(tracked) do
				v.Frame.BackgroundTransparency = callback and 0.4 or 1
			end
		end,
		Default = true
	})
	Color = OreESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.6,
		Function = function(hue, sat, val, opacity)
			for _, v in pairs(tracked) do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
	task.defer(function()
		if Color and Color.Object then
			Color.Object.Visible = Background.Enabled
		end
	end)
end)

--[[
	Utility Mobule
]]

run(function()
	local AutoEnchant
	local EnchantPick
	local UnlockTable
	local EnchantRange
	local netFolder
	local enchantInfo = {}
	local tableCost
	local diamondType
	local anyTeamTable = false

	local researchRemotes = {
		EnchantMeta = 'ResearchEnchant',
		ArmorEnchantMeta = 'ResearchArmorEnchant',
		ToolEnchantMeta = 'ResearchToolEnchant'
	}

	task.spawn(function()
		netFolder = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged')
	end)

	task.spawn(function()
		pcall(function()
			local meta = require(replicatedStorage.TS.enchant['enchant-meta'])
			for group, remoteName in researchRemotes do
				for _, v in meta[group] or {} do
					if type(v) == 'table' and type(v.name) == 'string' and v.statusEffect then
						local lower = v.name:lower()
						for _, want in {'static', 'forest'} do
							if lower:find(want) and not enchantInfo[want] then
								enchantInfo[want] = {effect = v.statusEffect, remote = remoteName}
							end
						end
					end
				end
			end
		end)
		pcall(function()
			tableCost = require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-util']).TeamUpgradeUtil.ENCHANT_TABLE_COST
		end)
		pcall(function()
			diamondType = require(replicatedStorage.TS.item['item-type']).ItemType.DIAMOND
		end)
		pcall(function()
			anyTeamTable = require(replicatedStorage.TS.enchant['enchant-util']).EnchantBalance.USE_ENCHANT_TABLE_ANY_TEAM == true
		end)
	end)

	local function hasEnchant(info)
		local char = lplr.Character
		local val = char and char:GetAttribute('StatusEffect_' .. tostring(info.effect))
		return type(val) == 'number' and val < 0
	end

	local function closestTable(tag, needTeam)
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return nil end
		local myTeam = lplr:GetAttribute('Team')
		local best, bestDist = nil, EnchantRange.Value
		for _, v in collectionService:GetTagged(tag) do
			if v:IsA('BasePart') and (not needTeam or v:GetAttribute('Team') == myTeam) then
				local dist = (v.Position - root.Position).Magnitude
				if dist <= bestDist then
					best, bestDist = v, dist
				end
			end
		end
		return best
	end

	local function invoke(name, ...)
		local remote = netFolder and netFolder:FindFirstChild(name)
		if not remote then return end
		local args = table.pack(...)
		pcall(function()
			remote:InvokeServer(table.unpack(args, 1, args.n))
		end)
	end

	AutoEnchant = vape.Categories.Utility:CreateModule({
		Name = 'AutoEnchant',
		Function = function(callback)
			if callback then
				repeat
					local waitTime = 0.5
					if entitylib.isAlive and netFolder then
						local broken = UnlockTable.Enabled and closestTable('broken-enchant-table', true)
						local diamonds = diamondType and getItem(diamondType)
						if broken and (not tableCost or (diamonds and diamonds.amount >= tableCost)) then
							invoke('RepairEnchantTable', broken)
							waitTime = 2
						else
							local info = enchantInfo[EnchantPick.Value]
							if info and not hasEnchant(info) then
								local enchantTable = closestTable('enchant-table', not anyTeamTable)
								if enchantTable then
									invoke(info.remote, {enchantTable = enchantTable})
									waitTime = 1.5
								end
							end
						end
					end
					task.wait(waitTime)
				until not AutoEnchant.Enabled
			end
		end,
		Tooltip = 'auto rolls the enchant table till u get the enchant u picked'
	})

	EnchantPick = AutoEnchant:CreateDropdown({
		Name = 'enchant',
		List = {'static', 'forest'},
		Tooltip = 'which enchant u tryna get gng'
	})

	UnlockTable = AutoEnchant:CreateToggle({
		Name = 'Unlock Enchant Table',
		Default = true,
		Tooltip = 'fixes ur team enchant table for u when u got the diamonds'
	})

	EnchantRange = AutoEnchant:CreateSlider({
		Name = 'range',
		Min = 1,
		Max = 20,
		Default = 6,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
		Tooltip = 'how close u gotta be to the table for it to work'
	})
end)

run(function()
	local CheatDetector
	local SelfTest
	local toggles = {}

	local SAMPLE_STEP = 0.05
	local HISTORY_TIME = 2
	local FLAG_SCORE = 70
	local SCORE_DECAY = 1.2
	local REASON_LIFE = 25
	local REASON_COOLDOWN = 6

	local tips = {
		Speed = 'catches ppl movin way too fast',
		Reach = 'catches ppl hittin u from too far away',
		Killaura = 'catches ppl hittin mad fast or behind them',
		Fly = 'catches ppl floatin in the air'
	}

	local history = {}
	local meta = {}
	local score = {}
	local flagged = {}
	local reachStreak = {}
	local airTime = {}
	local speedTime = {}
	local kaData = {}

	local function resetPlayer(plr)
		history[plr] = nil
		meta[plr] = nil
		score[plr] = nil
		reachStreak[plr] = nil
		airTime[plr] = nil
		speedTime[plr] = nil
		kaData[plr] = nil
	end

	local function resetAll()
		table.clear(history)
		table.clear(meta)
		table.clear(score)
		table.clear(flagged)
		table.clear(reachStreak)
		table.clear(airTime)
		table.clear(speedTime)
		table.clear(kaData)
	end

	local function isOn(name)
		local t = toggles[name]
		return t and t.Enabled
	end

	local function notSelf(plr)
		return plr ~= lplr or (SelfTest and SelfTest.Enabled)
	end

	local function getEntities()
		if SelfTest and SelfTest.Enabled and entitylib.character then
			local list = table.clone(entitylib.List)
			table.insert(list, entitylib.character)
			return list
		end
		return entitylib.List
	end

	local function flagPlayer(plr, reasons)
		local key = tostring(plr)
		local now = os.clock()
		if flagged[key] and now < flagged[key] then return end
		flagged[key] = now + 20
		notif('CheatDetector', 'yo '..(plr.DisplayName or plr.Name)..' is prob cheatin -> '..reasons, 12, 'alert')
	end

	local function addScore(plr, amount, reason, label)
		if not plr then return end
		local now = os.clock()
		local s = score[plr]
		if not s then
			s = {value = 0, seen = {}, labels = {}, last = now}
			score[plr] = s
		end
		if s.seen[reason] and now - s.seen[reason] < REASON_COOLDOWN then return end
		s.seen[reason] = now
		s.labels[reason] = label
		s.value = s.value + amount
		if s.value >= FLAG_SCORE then
			local list = {}
			for r in s.labels do
				list[#list + 1] = s.labels[r]
			end
			table.sort(list)
			flagPlayer(plr, table.concat(list, ' + '))
			s.value = 0
			table.clear(s.seen)
			table.clear(s.labels)
		end
	end

	local function pushSample(plr, ent)
		local root = ent.RootPart
		if not root then return end
		local h = history[plr]
		if not h then
			h = {}
			history[plr] = h
		end
		local now = os.clock()
		local cf = root.CFrame
		h[#h + 1] = {t = now, pos = cf.Position, look = cf.LookVector, vel = root.AssemblyLinearVelocity}
		while h[1] and now - h[1].t > HISTORY_TIME do
			table.remove(h, 1)
		end
	end

	local function trackMeta(plr, ent)
		local now = os.clock()
		local m = meta[plr]
		if not m then
			m = {spawn = now, lastMove = now, lastDamaged = 0, char = ent.Character}
			meta[plr] = m
		end
		if m.char ~= ent.Character then
			m.char = ent.Character
			m.spawn = now
			m.lastMove = now
			m.lastPos = nil
			history[plr] = nil
			reachStreak[plr] = nil
			airTime[plr] = nil
			speedTime[plr] = nil
		end
		local root = ent.RootPart
		if root then
			if not m.lastPos or (root.Position - m.lastPos).Magnitude > 0.05 then
				m.lastMove = now
			end
			m.lastPos = root.Position
		end
		return m
	end

	local function getHumanoid(ent)
		if ent.Humanoid then return ent.Humanoid end
		return ent.Character and ent.Character:FindFirstChildOfClass('Humanoid')
	end

	local function trusted(plr, ent)
		if not plr or not ent then return false end
		local char = ent.Character
		local root = ent.RootPart
		if not char or not root or not char.Parent or not root.Parent then return false end
		local m = meta[plr]
		if not m then return false end
		local now = os.clock()
		if now - m.spawn < 3 then return false end
		if now - m.lastMove > 0.35 then return false end
		local hum = getHumanoid(ent)
		if not hum or hum.Health <= 0 then return false end
		if (char:GetAttribute('InflatedBalloons') or 0) > 0 then return false end
		local serverNow = workspace:GetServerTimeNow()
		if serverNow - (plr:GetAttribute('LastTeleported') or 0) < 1.5 then return false end
		local stun = char:GetAttribute('StunnedUntilTime')
		if stun and stun > serverNow - 1 then return false end
		local dashNext = char:GetAttribute('CanDashNext')
		if dashNext and dashNext > serverNow then return false end
		if lplr:GetNetworkPing() > 0.15 then return false end
		local h = history[plr]
		if not h or #h < 8 then return false end
		return true
	end

	local function minDistanceTo(plr, point, window)
		local h = history[plr]
		if not h or #h == 0 then return nil end
		local now = os.clock()
		local best
		for i = #h, 1, -1 do
			local s = h[i]
			if now - s.t > window then break end
			local d = (s.pos - point).Magnitude
			if not best or d < best then best = d end
		end
		return best
	end

	local function minPairDistance(a, b, window)
		local ha, hb = history[a], history[b]
		if not ha or not hb then return nil end
		local now = os.clock()
		local best
		for i = #ha, 1, -1 do
			if now - ha[i].t > window then break end
			for j = #hb, 1, -1 do
				if now - hb[j].t > window then break end
				if math.abs(ha[i].t - hb[j].t) <= 0.12 then
					local d = (ha[i].pos - hb[j].pos).Magnitude
					if not best or d < best then best = d end
				end
			end
		end
		return best
	end

	local function recentSample(plr)
		local h = history[plr]
		if not h or #h == 0 then return nil end
		local ping = math.clamp(lplr:GetNetworkPing() * 0.5, 0, 0.3)
		local target = os.clock() - ping
		local best, bestDiff
		for i = #h, 1, -1 do
			local diff = math.abs(h[i].t - target)
			if not bestDiff or diff < bestDiff then
				best = h[i]
				bestDiff = diff
			end
		end
		return best
	end

	local function getAttackRange(plr)
		local inv = store.inventories[plr]
		local hand = inv and inv.hand
		local name = hand and hand.tool and hand.tool.Name
		if not name then return nil end
		local itemMeta = bedwars.ItemMeta[name]
		local swordMeta = itemMeta and itemMeta.sword
		if not swordMeta then return nil end
		return swordMeta.attackRange
	end

	local function blockedByMap(fromPos, toPos)
		local dir = toPos - fromPos
		local dist = dir.Magnitude
		if dist < 3 then return false end
		local params = cloneRaycast()
		local hit = workspace:Raycast(fromPos, dir.Unit * (dist - 1.5), params)
		if not hit then return false end
		return (hit.Position - fromPos).Magnitude < dist - 2
	end

	local function kaState(plr)
		local d = kaData[plr]
		if not d then
			d = {targets = {}, intervals = {}, lastHit = 0, angleHits = {}, wallHits = {}}
			kaData[plr] = d
		end
		return d
	end

	local function pruneStamps(list, life)
		local now = os.clock()
		for i = #list, 1, -1 do
			if now - list[i] > life then table.remove(list, i) end
		end
		return #list
	end

	local function checkReach(attacker, victimPlr, victimPos, fromPosition)
		if not isOn('Reach') then return end
		local range = getAttackRange(attacker)
		if not range then return end

		local best
		if fromPosition then
			if victimPlr then
				best = minDistanceTo(victimPlr, fromPosition, 0.8)
			elseif victimPos then
				best = (victimPos - fromPosition).Magnitude
			end
		end
		if victimPlr then
			local paired = minPairDistance(attacker, victimPlr, 0.8)
			if paired and (not best or paired < best) then best = paired end
		end
		if not best then return end

		local allowance = range + 2.5 + math.min(lplr:GetNetworkPing(), 0.2) * 30
		if best > allowance then
			reachStreak[attacker] = (reachStreak[attacker] or 0) + 1
			if reachStreak[attacker] >= 3 then
				reachStreak[attacker] = 0
				addScore(attacker, 45, 'reach', 'reach ('..string.format('%.1f', best)..' studs, max is '..string.format('%.1f', allowance)..')')
			end
		else
			reachStreak[attacker] = 0
		end
	end

	local function checkKillaura(attacker, victimInstance, victimPlr, victimPos, fromPosition)
		if not isOn('Killaura') then return end
		local d = kaState(attacker)
		local now = os.clock()

		d.targets[victimInstance] = now
		local distinct = 0
		for inst, t in d.targets do
			if now - t <= 0.35 then
				distinct = distinct + 1
			else
				d.targets[inst] = nil
			end
		end
		if distinct >= 2 then
			addScore(attacker, 40, 'multi', 'killaura (hit '..distinct..' ppl at once)')
		end

		if d.lastHit > 0 then
			local gap = now - d.lastHit
			if gap > 0.04 and gap < 1.2 then
				d.intervals[#d.intervals + 1] = gap
				while #d.intervals > 16 do
					table.remove(d.intervals, 1)
				end
				if #d.intervals >= 12 then
					local sum = 0
					for _, g in d.intervals do sum = sum + g end
					local mean = sum / #d.intervals
					local varSum = 0
					for _, g in d.intervals do varSum = varSum + (g - mean) ^ 2 end
					local sd = math.sqrt(varSum / #d.intervals)
					if mean > 0.05 and sd / mean < 0.07 then
						addScore(attacker, 45, 'timing', 'killaura (hits perfectly on beat, no human jitter)')
						table.clear(d.intervals)
					end
				end
			end
		end
		d.lastHit = now

		local attackerSample = recentSample(attacker)
		local origin = attackerSample and attackerSample.pos or fromPosition
		local look = attackerSample and attackerSample.look
		local targetPos = victimPos
		if victimPlr then
			local vs = recentSample(victimPlr)
			if vs then targetPos = vs.pos end
		end

		if origin and look and targetPos then
			local flatLook = look * Vector3.new(1, 0, 1)
			local flatDir = (targetPos - origin) * Vector3.new(1, 0, 1)
			if flatLook.Magnitude > 0.001 and flatDir.Magnitude > 0.001 then
				local angle = math.deg(math.acos(math.clamp(flatLook.Unit:Dot(flatDir.Unit), -1, 1)))
				if angle > 75 then
					d.angleHits[#d.angleHits + 1] = now
					if pruneStamps(d.angleHits, 15) >= 4 then
						table.clear(d.angleHits)
						addScore(attacker, 35, 'angle', 'killaura (swingin at ppl behind them)')
					end
				end
			end

			if blockedByMap(origin, targetPos) then
				d.wallHits[#d.wallHits + 1] = now
				if pruneStamps(d.wallHits, 15) >= 3 then
					table.clear(d.wallHits)
					addScore(attacker, 40, 'wall', 'killaura (hittin straight thru blocks)')
				end
			end
		end
	end

	local function onMeleeDamage(dmg)
		if not CheatDetector.Enabled then return end
		if dmg.damageType ~= 0 then return end
		if not dmg.fromEntity or not dmg.entityInstance then return end

		local attacker = playersService:GetPlayerFromCharacter(dmg.fromEntity)
		if not attacker or not notSelf(attacker) then return end

		local victimPlr = playersService:GetPlayerFromCharacter(dmg.entityInstance)
		if victimPlr then
			local vm = meta[victimPlr]
			if vm then vm.lastDamaged = os.clock() end
		end

		local victimRoot = dmg.entityInstance.PrimaryPart or dmg.entityInstance:FindFirstChild('HumanoidRootPart')
		local victimPos = victimRoot and victimRoot.Position

		local am = meta[attacker]
		if not am or os.clock() - am.spawn < 3 then return end
		if lplr:GetNetworkPing() > 0.15 then return end

		checkReach(attacker, victimPlr, victimPos, dmg.fromPosition)
		checkKillaura(attacker, dmg.entityInstance, victimPlr, victimPos, dmg.fromPosition)
	end

	local function checkFly(plr, ent, dt, rayParams)
		if not isOn('Fly') then
			airTime[plr] = 0
			return
		end
		local root = ent.RootPart
		rayParams.FilterDescendantsInstances = {ent.Character, lplr.Character, gameCamera}
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -250, 0), rayParams)
		local groundDist = hit and (root.Position.Y - hit.Position.Y) or 250
		local vel = root.AssemblyLinearVelocity
		local horizontal = (vel * Vector3.new(1, 0, 1)).Magnitude

		if groundDist > 8 and math.abs(vel.Y) < 3 and horizontal > 2 then
			airTime[plr] = (airTime[plr] or 0) + dt
			if airTime[plr] >= 1.75 then
				airTime[plr] = 0
				addScore(plr, 50, 'fly', 'fly (hoverin '..math.floor(groundDist)..' studs off the ground)')
			end
		else
			airTime[plr] = 0
		end
	end

	local function checkSpeed(plr, ent, dt)
		if not isOn('Speed') then
			speedTime[plr] = 0
			return
		end
		local m = meta[plr]
		if m and os.clock() - (m.lastDamaged or 0) < 1.5 then
			speedTime[plr] = 0
			return
		end
		local h = history[plr]
		if not h or #h < 8 then
			speedTime[plr] = 0
			return
		end

		local now = os.clock()
		local newest, oldest, prev
		local maxStep = 0
		for i = #h, 1, -1 do
			local s = h[i]
			if now - s.t > 0.5 then break end
			if not newest then newest = s end
			if prev then
				local step = ((prev.pos - s.pos) * Vector3.new(1, 0, 1)).Magnitude
				if step > maxStep then maxStep = step end
			end
			prev = s
			oldest = s
		end

		if not newest or not oldest then
			speedTime[plr] = 0
			return
		end
		local span = newest.t - oldest.t
		if span < 0.3 or maxStep > 8 then
			speedTime[plr] = 0
			return
		end

		local travelled = ((newest.pos - oldest.pos) * Vector3.new(1, 0, 1)).Magnitude
		local speed = travelled / span
		if speed > 34 then
			speedTime[plr] = (speedTime[plr] or 0) + dt
			if speedTime[plr] >= 1.2 then
				speedTime[plr] = 0
				addScore(plr, 45, 'speed', 'speed ('..math.floor(speed)..' studs a sec)')
			end
		else
			speedTime[plr] = 0
		end
	end

	local function decayScores(dt)
		local now = os.clock()
		for plr, s in score do
			s.last = now
			s.value = math.max(0, s.value - SCORE_DECAY * dt)
			for reason, t in s.seen do
				if now - t > REASON_LIFE then
					s.seen[reason] = nil
					s.labels[reason] = nil
				end
			end
			if s.value <= 0 and not next(s.seen) then
				score[plr] = nil
			end
		end
	end

	CheatDetector = vape.Categories.Utility:CreateModule({
		Name = 'CheatDetector',
		Function = function(callback)
			if callback then
				resetAll()

				CheatDetector:Clean(playersService.PlayerRemoving:Connect(function(plr)
					resetPlayer(plr)
					flagged[tostring(plr)] = nil
				end))

				CheatDetector:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(dmg)
					pcall(onMeleeDamage, dmg)
				end))

				task.spawn(function()
					local rayParams = RaycastParams.new()
					rayParams.FilterType = Enum.RaycastFilterType.Exclude
					local last = os.clock()
					local decayAccum = 0
					repeat
						local now = os.clock()
						local dt = now - last
						last = now
						decayAccum = decayAccum + dt

						for _, ent in getEntities() do
							local plr = ent.Player
							if plr and notSelf(plr) and ent.RootPart and ent.Character then
								trackMeta(plr, ent)
								pushSample(plr, ent)
								if trusted(plr, ent) then
									checkFly(plr, ent, dt, rayParams)
									checkSpeed(plr, ent, dt)
								else
									airTime[plr] = 0
									speedTime[plr] = 0
								end
							end
						end

						if decayAccum >= 1 then
							decayScores(decayAccum)
							decayAccum = 0
						end

						task.wait(SAMPLE_STEP)
					until not CheatDetector.Enabled
					resetAll()
				end)
			else
				resetAll()
			end
		end,
		Tooltip = 'tells u if sum1 in ur game is prob cheatin'
	})

	SelfTest = CheatDetector:CreateToggle({
		Name = 'Self',
		Default = false,
		Tooltip = 'lets it flag u too so u can test it on urself'
	})

	for _, name in {'Speed', 'Reach', 'Killaura', 'Fly'} do
		toggles[name] = CheatDetector:CreateToggle({
			Name = name,
			Default = true,
			Tooltip = tips[name]
		})
	end
end)

run(function()
    local moduleData = {
        Connection = nil,
        CurrentDuration = 1,
        CachedPrompts = {}
    }
    
    local function updatePrompt(prompt, duration)
        if prompt and prompt:IsA("ProximityPrompt") then
            prompt.HoldDuration = duration
        end
    end
    
    local function updateAllPrompts(duration)
        for prompt in pairs(moduleData.CachedPrompts) do	local function buyTeamUpgrade(upgradeType)
		if not upgradeType then return end
		pcall(function()
			upgradeRemote:InvokeServer(upgradeType)
		end)
	end

	local lastBedBarrierBuy = 0
	local BED_BARRIER_DURATION = 180

	local bedUpgradeRemote = replicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("RequestPurchaseBedTeamUpgrade")

	local function buyBedBarrier()
		local now = tick()
		if now - lastBedBarrierBuy < BED_BARRIER_DURATION then return end
		local ok = pcall(function()
			bedUpgradeRemote:InvokeServer("bed_shield")
			bedUpgradeRemote:InvokeServer("bed_alarm")
		end)
		if ok then
			lastBedBarrierBuy = now
		end
	end

	AutoBuy = vape.Categories.Utility:CreateModule({
		Name = 'AutoBuy',
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat task.wait() until store.shopLoaded or not AutoBuy.Enabled
					if not AutoBuy.Enabled then return end
					repeat
						task.wait(0.5)
						if not entitylib.isAlive then continue end
						if WrenShop.Enabled then
							if BuySerpentToggle.Enabled then buyPotion('serpents_touch_potion') end
							if BuyJumpToggle.Enabled then buyPotion('jump_potion') end
							if BuyShieldToggle.Enabled then buyPotion('mini_shield') end
						end
						if ItemShop.Enabled and isNearShop('item') then
							local sid = "1_item_shop"
							if BuyArmorToggle.Enabled then buyBestTier(armorTiers, sid) end
							if BuyAxeToggle.Enabled then buyBestTier(axeTiers, sid) end
							if BuyPickaxeToggle.Enabled then buyBestTier(pickaxeTiers, sid) end
							if BuyProjectileToggle.Enabled then buyProjectile(sid) end
						end
						if TeamUpgrade.Enabled and isNearShop('upgrade') then
							if BreakSpeedToggle.Enabled   then buyTeamUpgrade(upgradeIds.BreakSpeed) end
							if ArmorUpgradeToggle.Enabled then buyTeamUpgrade(upgradeIds.Armor) end
							if DamageToggle.Enabled        then buyTeamUpgrade(upgradeIds.Damage) end
							if DiamondGenToggle.Enabled    then buyTeamUpgrade(upgradeIds.DiamondGen) end
							if TeamGenToggle.Enabled       then buyTeamUpgrade(upgradeIds.TeamGen) end
							if BedBarrierToggle.Enabled then buyBedBarrier() end
						end
					until not AutoBuy.Enabled
				end)
			end
		end,
		Tooltip = 'auto buys from the shops u turn on when ur near them'
	})

	ItemShop = AutoBuy:CreateToggle({
		Name = 'Item Shop',
		Default = true,
		Tooltip = 'buys gear from the item shop when ur near it',
		Function = function(v)
			if BuyArmorToggle     then BuyArmorToggle.Object.Visible     = v end
			if BuyAxeToggle       then BuyAxeToggle.Object.Visible       = v end
			if BuyPickaxeToggle   then BuyPickaxeToggle.Object.Visible   = v end
			if BuyProjectileToggle then BuyProjectileToggle.Object.Visible = v end
		end
	})

	TeamUpgrade = AutoBuy:CreateToggle({
		Name = 'Team Upgrade',
		Default = false,
		Tooltip = 'buys team upgrades when ur near the upgrade shop',
		Function = function(v)
			if BreakSpeedToggle   then BreakSpeedToggle.Object.Visible   = v end
			if ArmorUpgradeToggle then ArmorUpgradeToggle.Object.Visible = v end
			if DamageToggle       then DamageToggle.Object.Visible       = v end
			if DiamondGenToggle   then DiamondGenToggle.Object.Visible   = v end
			if TeamGenToggle      then TeamGenToggle.Object.Visible      = v end
			if BedBarrierToggle   then BedBarrierToggle.Object.Visible   = v end
		end
	})

	WrenShop = AutoBuy:CreateToggle({
		Name = 'Wren Shop',
		Default = false,
		Tooltip = 'buys potions from the wren shop gng',
		Function = function(v)
			if BuySerpentToggle then BuySerpentToggle.Object.Visible = v end
			if BuyJumpToggle    then BuyJumpToggle.Object.Visible    = v end
			if BuyShieldToggle  then BuyShieldToggle.Object.Visible  = v end
		end
	})

	GUICheck = AutoBuy:CreateToggle({
		Name = 'GUI Check',
		Default = true,
		Tooltip = 'only buys when ur near the shop'
	})

	BuyArmorToggle     = AutoBuy:CreateToggle({Name = 'Buy Armor',      Default = true, Darker = true})
	BuyAxeToggle       = AutoBuy:CreateToggle({Name = 'Buy Axe',        Default = false, Darker = true})
	BuyPickaxeToggle   = AutoBuy:CreateToggle({Name = 'Buy Pickaxe',    Default = false, Darker = true})
	BuyProjectileToggle = AutoBuy:CreateToggle({Name = 'Buy Projectile', Default = false, Darker = true})
	BuySerpentToggle   = AutoBuy:CreateToggle({Name = 'Buy Serpent Potion',     Default = false, Darker = true})
	BuyJumpToggle      = AutoBuy:CreateToggle({Name = 'Buy Jump Potion',        Default = false, Darker = true})
	BuyShieldToggle    = AutoBuy:CreateToggle({Name = 'Buy Shield Potion',      Default = false, Darker = true})
	BreakSpeedToggle   = AutoBuy:CreateToggle({Name = 'Break Speed',  Default = false, Darker = true})
	ArmorUpgradeToggle = AutoBuy:CreateToggle({Name = 'Armor',        Default = false, Darker = true})
	DamageToggle       = AutoBuy:CreateToggle({Name = 'Damage',       Default = false, Darker = true})
	DiamondGenToggle   = AutoBuy:CreateToggle({Name = 'Diamond Gen',  Default = false, Darker = true})
	TeamGenToggle      = AutoBuy:CreateToggle({Name = 'Team Gen',     Default = false, Darker = true})
	BedBarrierToggle   = AutoBuy:CreateToggle({Name = 'Bed Barrier',  Default = false, Darker = true})

	task.defer(function()
		if BuySerpentToggle   and BuySerpentToggle.Object   then BuySerpentToggle.Object.Visible   = WrenShop.Enabled end
		if BuyJumpToggle      and BuyJumpToggle.Object      then BuyJumpToggle.Object.Visible      = WrenShop.Enabled end
		if BuyShieldToggle    and BuyShieldToggle.Object    then BuyShieldToggle.Object.Visible    = WrenShop.Enabled end
		if BreakSpeedToggle   and BreakSpeedToggle.Object   then BreakSpeedToggle.Object.Visible   = TeamUpgrade.Enabled end
		if ArmorUpgradeToggle and ArmorUpgradeToggle.Object then ArmorUpgradeToggle.Object.Visible = TeamUpgrade.Enabled end
		if DamageToggle       and DamageToggle.Object       then DamageToggle.Object.Visible       = TeamUpgrade.Enabled end
		if DiamondGenToggle   and DiamondGenToggle.Object   then DiamondGenToggle.Object.Visible   = TeamUpgrade.Enabled end
		if TeamGenToggle      and TeamGenToggle.Object      then TeamGenToggle.Object.Visible      = TeamUpgrade.Enabled end
		if BedBarrierToggle   and BedBarrierToggle.Object   then BedBarrierToggle.Object.Visible   = TeamUpgrade.Enabled end
	end)
end)

run(function()
	local ViewMatchHistory

	ViewMatchHistory = vape.Categories.Utility:CreateModule({
		Name = "ViewMatchHistory",
		Function = function(callback)
			if callback then
				ViewMatchHistory:Toggle(false)
				local d = nil
				bedwars.MatchHistoryController:requestMatchHistory(lplr.Name):andThen(function(Data)
					if Data then
						bedwars.AppController:openApp({app = bedwars.MatchHistoryApp,appId = "MatchHistoryApp",},Data)
					end
				end)
			else
				return
			end
		end,
	})																								
end)

run(function()
	local KitRender
	local LastKitToggle
	local LastKitCount
	local LevelToggle
	local PartyToggle
	local Players = playersService
	local player = Players.LocalPlayer
	local PlayerGui = player:WaitForChild("PlayerGui")
	local scanThread = nil
	local retryThread = nil
	local currentDraft = nil
	local lastKitCache = {}
	local lastKitPending = {}
	local lastKitRetry = {}
	local partyCache = {}
	local currentPartyNumbers = {}

	local function resolveKitImage(kit)
		kit = kit or "none"
		local meta = bedwars.BedwarsKitMeta and (bedwars.BedwarsKitMeta[kit] or bedwars.BedwarsKitMeta.none)
		return (meta and meta.renderImage) or kitImageIds[kit] or kitImageIds["none"] or ""
	end

	local function clearLastKitCache()
		table.clear(lastKitCache)
		table.clear(lastKitPending)
		table.clear(lastKitRetry)
		table.clear(partyCache)
		table.clear(currentPartyNumbers)
	end

	local function destroyNamed(root, name)
		if not root then return end
		for _, obj in root:GetDescendants() do
			if obj.Name == name then
				obj:Destroy()
			end
		end
	end

	local function cleanupVisuals()
		destroyNamed(PlayerGui, "aerov4KitRender")
		destroyNamed(PlayerGui, "aerov4KitIcon")
		destroyNamed(PlayerGui, "aerov4KitLevel")
		destroyNamed(PlayerGui, "aerov4LastKit")
	end

	local function cleanupLastMatch()
		destroyNamed(PlayerGui, "aerov4LastKit")
	end

	local function extractHistory(payload)
		if type(payload) ~= "table" then return nil end

		if type(payload.matchHistory) == "table" then
			return payload.matchHistory
		end

		if type(payload.data) == "table" then
			if type(payload.data.matchHistory) == "table" then
				return payload.data.matchHistory
			end
			if type(payload.data.history) == "table" then
				return payload.data.history
			end
			if next(payload.data) ~= nil then
				return payload.data
			end
		end

		if type(payload.history) == "table" then
			return payload.history
		end

		return payload
	end

	local function getMatchEntry(match, uid)
		if type(match) ~= "table" or type(match.players) ~= "table" then return nil end
		for _, entry in match.players do
			local info = entry and entry.playerInfo
			if info and tostring(info.userId) == tostring(uid) then
				return entry
			end
		end
		return nil
	end

	local function readLastCompletedKit(history, uid)
		if type(history) ~= "table" then return nil end

		local matches = {}
		local order = 0

		if history[1] ~= nil then
			for index, match in ipairs(history) do
				if type(match) == "table" then
					order += 1
					table.insert(matches, {
						match = match,
						time = tonumber(match.matchStartTime) or tonumber(match.startTime) or 0,
						order = order,
						index = index
					})
				end
			end
		else
			for index, match in pairs(history) do
				if type(match) == "table" then
					order += 1
					table.insert(matches, {
						match = match,
						time = tonumber(match.matchStartTime) or tonumber(match.startTime) or 0,
						order = order,
						index = tonumber(index) or order
					})
				end
			end
		end

		table.sort(matches, function(a, b)
			if a.time ~= b.time then
				return a.time > b.time
			end
			if a.index ~= b.index then
				return a.index < b.index
			end
			return a.order < b.order
		end)

		local kits = {}
		local loose = {}

		for _, record in matches do
			local entry = getMatchEntry(record.match, uid)
			if entry then
				local kit = entry.bedwars and entry.bedwars.kit
				if type(kit) == "string" and kit ~= "" then
					local outcome = entry.generic and string.lower(tostring(entry.generic.matchOutcome or "")) or ""
					if outcome == "win"
						or outcome == "loss"
						or outcome == "lose"
						or outcome == "lost"
						or outcome == "defeat"
						or outcome == "victory" then
						table.insert(kits, kit)
						if #kits >= 5 then break end
					elseif #loose < 5 then
						table.insert(loose, kit)
					end
				end
			end
		end

		if #kits == 0 then
			kits = loose
		end

		return #kits > 0 and kits or nil
	end

	local function readTeammates(history, uid)
		local found = {}
		if type(history) ~= "table" then return found end
		local matches = {}
		for _, match in pairs(history) do
			if type(match) == "table" and type(match.players) == "table" then
				table.insert(matches, match)
			end
		end
		table.sort(matches, function(a, b)
			return (tonumber(a.matchStartTime) or 0) > (tonumber(b.matchStartTime) or 0)
		end)
		local decided = {}
		for i = 1, math.min(5, #matches) do
			local match = matches[i]
			local me = getMatchEntry(match, uid)
			local myTeam = me and (me.teamId or (me.generic and me.generic.team))
			local myParty = me and me.partyId
			if me then
				for _, entry in match.players do
					local info = entry and entry.playerInfo
					local key = info and tonumber(info.userId)
					if key and not entry.observer and tostring(info.userId) ~= tostring(uid) and not decided[key] then
						if myParty ~= nil and entry.partyId ~= nil then
							decided[key] = true
							found[key] = tostring(entry.partyId) == tostring(myParty) and 2 or nil
						elseif myTeam then
							local otherTeam = entry.teamId or (entry.generic and entry.generic.team)
							if tostring(otherTeam) == tostring(myTeam) then
								found[key] = (found[key] or 0) + 1
							end
						end
					end
				end
			end
		end
		return found
	end

	local function finishLastKit(uid, payload)
		local history = extractHistory(payload)
		local kit = readLastCompletedKit(history, uid)
		lastKitCache[uid] = kit or false
		partyCache[uid] = readTeammates(history, uid)
		lastKitPending[uid] = nil
		lastKitRetry[uid] = nil
	end

	local function failLastKit(uid)
		lastKitPending[uid] = nil
		lastKitRetry[uid] = tick() + 1.5
	end

	local function consumeHistoryRequest(uid, request)
		if type(request) == "table" and type(request.andThen) == "function" then
			local chained = pcall(function()
				request:andThen(function(data)
					finishLastKit(uid, data)
				end):catch(function()
					failLastKit(uid)
				end)
			end)
			if not chained then
				failLastKit(uid)
			end
			return
		end

		if type(request) == "table" then
			finishLastKit(uid, request)
		else
			failLastKit(uid)
		end
	end

	local function fetchLastKit(plr)
		if not plr then return end
		local uid = plr.UserId
		if lastKitCache[uid] ~= nil or lastKitPending[uid] then return end
		if lastKitRetry[uid] and tick() < lastKitRetry[uid] then return end

		lastKitPending[uid] = true

		task.spawn(function()
			local controllers = (bedwars.KnitClient and bedwars.KnitClient.Controllers)
				or (bedwars.Knit and bedwars.Knit.Controllers)
			local controller = bedwars.MatchHistoryController
				or (controllers and controllers.MatchHistoryController)
				or bedwars.MatchHistoryController

			local request = nil

			if controller and type(controller.requestMatchHistory) == "function" then
				local ok, result = pcall(function()
					return controller:requestMatchHistory(plr.Name)
				end)
				if ok then
					request = result
				end
			end

			if not request then
				pcall(function()
					request = bedwars.Client:Get("RequestMatchHistory"):CallServerAsync(plr.Name)
				end)
			end

			if not request then
				local _remotes = getgenv().remotes or remotes
				pcall(function()
					local remoteName = _remotes and (_remotes.RequestMatchHistory or "RequestMatchHistory") or "RequestMatchHistory"
					request = bedwars.Client:Get(remoteName):CallServerAsync(plr.Name)
				end)
			end

			if not request then
				pcall(function()
					local client = require(replicatedStorage.TS.remotes).default.Client
					request = client:Get("RequestMatchHistory"):CallServerAsync(plr.Name)
				end)
			end

			if not request then
				failLastKit(uid)
				return
			end

			consumeHistoryRequest(uid, request)
		end)
	end

	local function unclip(inst)
		local node = inst
		for _ = 1, 7 do
			if not node then break end
			pcall(function()
				node.ClipsDescendants = false
			end)
			node = node.Parent
		end
	end

	local function findPlayerFromRender(render)
		if not render then return nil end

		local image = tostring(render.Image or "")
		local userId = image:match("id=(%d+)")
			or image:match("userId=(%d+)")
			or image:match("(%d+)")

		if userId then
			local plr = Players:GetPlayerByUserId(tonumber(userId))
			if plr then return plr end
		end

		local node = render.Parent
		for _ = 1, 6 do
			if not node then break end
			local label = node:FindFirstChild("PlayerName", true)
			if label and label:IsA("TextLabel") then
				local text = label.Text
				for _, plr in Players:GetPlayers() do
					if plr.Name == text or plr.DisplayName == text or plr:GetAttribute("DisguiseDisplayName") == text then
						return plr
					end
					local smName = nil
					pcall(function()
						smName = bedwars.KnitClient.Controllers.StreamerModeController:getDisplayName(plr)
					end)
					if smName and smName == text then
						return plr
					end
				end
			end
			node = node.Parent
		end

		return nil
	end

	local function findHost(render)
		local node = render
		local fallback = nil

		for _ = 1, 8 do
			node = node and node.Parent
			if not node then break end

			if node.Name == "MatchDraftPlayerCard" then
				return node
			end

			if not fallback and node:FindFirstChild("PlayerName", true) and node:FindFirstChild("PlayerRender", true) then
				fallback = node
			end
		end

		return fallback or render.Parent
	end

	local function isEnemy(plr)
		if not plr or plr == player then return false end
		local myTeam = player:GetAttribute("Team")
		local theirTeam = plr:GetAttribute("Team")
		if not myTeam or not theirTeam then return false end
		return myTeam ~= theirTeam
	end

	local function ensureCurrentKit(host, plr)
		if not host or not host.Parent then return end
		unclip(host)

		local icon = host:FindFirstChild("aerov4KitRender")
		if not icon then
			icon = Instance.new("ImageLabel")
			icon.Name = "aerov4KitRender"
			icon.AnchorPoint = Vector2.new(1, 0.5)
			icon.Position = UDim2.new(1.05, 0, 0.5, 0)
			icon.Size = UDim2.new(1.5, 0, 1.5, 0)
			icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
			icon.BackgroundTransparency = 1
			icon.BorderSizePixel = 0
			icon.ImageTransparency = 0.4
			icon.ScaleType = Enum.ScaleType.Crop
			icon.ZIndex = 5

			local ratio = Instance.new("UIAspectRatioConstraint")
			ratio.AspectRatio = 1
			ratio.AspectType = Enum.AspectType.FitWithinMaxSize
			ratio.DominantAxis = Enum.DominantAxis.Width
			ratio.Parent = icon

			icon.Parent = host
		end

		local kit = plr:GetAttribute("PlayingAsKits") or "none"
		local image = resolveKitImage(kit)
		if icon.Image ~= image then
			icon.Image = image
		end
	end

	local function ensureLevel(host, plr)
		if not host or not host.Parent then return end
		local nameLabel = host:FindFirstChild("PlayerName", true)
		if not nameLabel then return end
		unclip(nameLabel)

		local levelLabel = nameLabel:FindFirstChild("aerov4KitLevel")
		if not levelLabel then
			levelLabel = Instance.new("TextLabel")
			levelLabel.Name = "aerov4KitLevel"
			levelLabel.AnchorPoint = Vector2.new(0, 0.5)
			levelLabel.Position = UDim2.new(1, 5, 0.5, 0)
			levelLabel.Size = UDim2.fromOffset(44, 15)
			levelLabel.BackgroundTransparency = 1
			levelLabel.TextColor3 = Color3.fromRGB(255, 214, 51)
			levelLabel.TextSize = 12
			levelLabel.Font = Enum.Font.GothamBold
			levelLabel.TextStrokeTransparency = 0.25
			levelLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			levelLabel.TextXAlignment = Enum.TextXAlignment.Left
			levelLabel.TextYAlignment = Enum.TextYAlignment.Center
			levelLabel.ZIndex = 10001
			levelLabel.Parent = nameLabel
		end

		local level = plr:GetAttribute("PlayerLevel") or 0
		local text = "[" .. tostring(level) .. "]"
		if levelLabel.Text ~= text then
			levelLabel.Text = text
		end
	end

	local function createLastMatchBadge(host, plr, slot)
		slot = slot or 1
		local badge = Instance.new("Frame")
		badge.Name = "aerov4LastKit"
		badge:SetAttribute("UserId", plr.UserId)
		badge:SetAttribute("Slot", slot)
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.new(0.41, (slot - 1) * 58, 0.5, 0)
		badge.Size = UDim2.fromOffset(54, 56)
		badge.BackgroundTransparency = 1
		badge.BorderSizePixel = 0
		badge.ClipsDescendants = false
		badge.ZIndex = 10000
		badge.Visible = false

		local tag = Instance.new("TextLabel")
		tag.Name = "Tag"
		tag.AnchorPoint = Vector2.new(0.5, 0)
		tag.Position = UDim2.new(0.5, 0, 0, -1)
		tag.Size = UDim2.new(1.1, 0, 0, 14)
		tag.BackgroundTransparency = 1
		tag.Text = slot == 1 and "last game" or (slot .. " games ago")
		tag.TextColor3 = Color3.fromRGB(255, 64, 64)
		tag.TextSize = 10
		tag.Font = Enum.Font.FredokaOne
		tag.TextStrokeTransparency = 0.35
		tag.TextStrokeColor3 = Color3.new(0, 0, 0)
		tag.TextXAlignment = Enum.TextXAlignment.Center
		tag.ZIndex = 10002
		tag.Parent = badge

		local img = Instance.new("ImageLabel")
		img.Name = "Render"
		img.AnchorPoint = Vector2.new(0.5, 1)
		img.Position = UDim2.new(0.5, 0, 1, 1)
		img.Size = UDim2.fromOffset(44, 41)
		img.BackgroundTransparency = 1
		img.BorderSizePixel = 0
		img.ImageTransparency = 0.05
		img.ScaleType = Enum.ScaleType.Fit
		img.ZIndex = 10001
		img.Parent = badge

		badge.Parent = host
		return badge
	end

	local function ensureLastMatch(host, plr)
		if not host or not host.Parent then return end

		if not (LastKitToggle and LastKitToggle.Enabled) then
			for _, old in host:GetChildren() do
				if old.Name == "aerov4LastKit" then
					old:Destroy()
				end
			end
			return
		end

		unclip(host)

		local count = LastKitCount and LastKitCount.Value or 1
		local badges = {}
		for _, obj in host:GetChildren() do
			if obj.Name == "aerov4LastKit" then
				local slot = obj:GetAttribute("Slot") or 1
				if slot > count or badges[slot] then
					obj:Destroy()
				else
					badges[slot] = obj
				end
			end
		end

		local cached = lastKitCache[plr.UserId]
		if cached == nil then
			fetchLastKit(plr)
		end

		for slot = 1, count do
			local badge = badges[slot] or createLastMatchBadge(host, plr, slot)
			local kit = type(cached) == "table" and cached[slot]
			if kit then
				local img = badge:FindFirstChild("Render")
				local image = resolveKitImage(kit)
				if img and img.Image ~= image then
					img.Image = image
				end
				badge.Visible = true
			else
				badge.Visible = false
			end
		end
	end

	local function getPartyNumbers()
		local list = {}
		for _, plr in Players:GetPlayers() do
			if partyCache[plr.UserId] then
				table.insert(list, plr)
			end
		end
		table.sort(list, function(a, b)
			return a.UserId < b.UserId
		end)
		local parent = {}
		local function find(x)
			while parent[x] ~= x do
				x = parent[x]
			end
			return x
		end
		for _, plr in list do
			parent[plr.UserId] = plr.UserId
		end
		for i, a in list do
			for j = i + 1, #list do
				local b = list[j]
				if a:GetAttribute("Team") == b:GetAttribute("Team") then
					local ab = partyCache[a.UserId][b.UserId] or 0
					local ba = partyCache[b.UserId][a.UserId] or 0
					if math.max(ab, ba) >= 2 then
						parent[find(b.UserId)] = find(a.UserId)
					end
				end
			end
		end
		local groups, order = {}, {}
		for _, plr in list do
			local root = find(plr.UserId)
			if not groups[root] then
				groups[root] = {}
				table.insert(order, root)
			end
			table.insert(groups[root], plr.UserId)
		end
		local numbers = {}
		local n = 0
		for _, root in order do
			if #groups[root] >= 2 then
				n += 1
				for _, id in groups[root] do
					numbers[id] = n
				end
			end
		end
		return numbers
	end

	local function ensureParty(host, plr)
		local icon = host and host:FindFirstChild("aerov4KitRender")
		if not icon then return end
		local badge = icon:FindFirstChild("aerov4Party")
		local num = PartyToggle and PartyToggle.Enabled and currentPartyNumbers[plr.UserId]
		if not num then
			if badge then
				badge.Visible = false
			end
			return
		end
		if not badge then
			badge = Instance.new("TextLabel")
			badge.Name = "aerov4Party"
			badge.AnchorPoint = Vector2.new(1, 0)
			badge.Position = UDim2.new(1, 2, 0, -2)
			badge.Size = UDim2.fromOffset(16, 16)
			badge.BackgroundColor3 = Color3.fromRGB(40, 120, 255)
			badge.BorderSizePixel = 0
			badge.TextColor3 = Color3.new(1, 1, 1)
			badge.TextSize = 11
			badge.Font = Enum.Font.GothamBold
			badge.ZIndex = 10003
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = badge
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Thickness = 1
			stroke.Color = Color3.new(0, 0, 0)
			stroke.Parent = badge
			badge.Parent = icon
		end
		local text = tostring(num)
		if badge.Text ~= text then
			badge.Text = text
		end
		badge.Visible = true
	end

	local function processRender(render)
		if not KitRender.Enabled or not render or not render.Parent then return end
		if render.Name ~= "PlayerRender" or not render:IsA("ImageLabel") then return end

		local plr = findPlayerFromRender(render)
		if not plr then return end
		if not isEnemy(plr) then
			local mine, theirs = player:GetAttribute("Team"), plr:GetAttribute("Team")
			if mine and theirs and mine == theirs then
				local mateHost = findHost(render)
				destroyNamed(mateHost, "aerov4KitRender")
				destroyNamed(mateHost, "aerov4KitLevel")
				destroyNamed(mateHost, "aerov4LastKit")
			end
			return
		end

		local host = findHost(render)
		if not host or not host.Parent then return end

		ensureCurrentKit(host, plr)
		if LevelToggle and LevelToggle.Enabled then
			ensureLevel(host, plr)
		else
			destroyNamed(host, "aerov4KitLevel")
		end
		ensureLastMatch(host, plr)
		if PartyToggle and PartyToggle.Enabled and lastKitCache[plr.UserId] == nil then
			fetchLastKit(plr)
		end
		ensureParty(host, plr)
	end

	local function scanDraft(app)
		if not app or not app.Parent then return end
		currentPartyNumbers = getPartyNumbers()
		for _, obj in app:GetDescendants() do
			if obj.Name == "PlayerRender" and obj:IsA("ImageLabel") then
				pcall(processRender, obj)
			end
		end
	end

	local function startScanner()
		if scanThread then return end

		scanThread = task.spawn(function()
			while KitRender and KitRender.Enabled do
				local app = PlayerGui:FindFirstChild("MatchDraftApp")

				if app ~= currentDraft then
					cleanupVisuals()
					clearLastKitCache()
					currentDraft = app
				end

				if app then
					pcall(scanDraft, app)
				end

				task.wait(0.25)
			end

			scanThread = nil
		end)
	end

	local function stopScanner()
		if scanThread then
			pcall(task.cancel, scanThread)
			scanThread = nil
		end

		if retryThread then
			pcall(task.cancel, retryThread)
			retryThread = nil
		end

		currentDraft = nil
		clearLastKitCache()
		cleanupVisuals()
	end

	KitRender = vape.Categories.Utility:CreateModule({
		Name = "KitRender",
		Tooltip = "renders enemy kits during draft and shows their last match kit",
		Function = function(callback)
			if callback then
				cleanupVisuals()
				clearLastKitCache()
				startScanner()

				if not PlayerGui:FindFirstChild("MatchDraftApp") then
					retryThread = task.spawn(function()
						while KitRender.Enabled and not PlayerGui:FindFirstChild("MatchDraftApp") do
							task.wait(0.25)
						end
						if KitRender.Enabled then
							startScanner()
						end
						retryThread = nil
					end)
				end
			else
				stopScanner()
			end
		end
	})

	LastKitToggle = KitRender:CreateToggle({
		Name = "Show Last Match",
		Default = true,
		Tooltip = "shows the kit they used in their last completed match",
		Function = function(callback)
			if LastKitCount then
				LastKitCount.Object.Visible = callback
			end

			if not callback then
				cleanupLastMatch()
				return
			end

			clearLastKitCache()
			if KitRender and KitRender.Enabled then
				local app = PlayerGui:FindFirstChild("MatchDraftApp")
				if app then
					pcall(scanDraft, app)
				end
			end
		end
	})

	LastKitCount = KitRender:CreateSlider({
		Name = "last match count",
		Min = 1,
		Max = 5,
		Default = 1,
		Tooltip = "how many of they old kits u tryna see gng, 1 is they last game and 5 is 5 games ago",
		Function = function()
			if KitRender and KitRender.Enabled then
				local app = PlayerGui:FindFirstChild("MatchDraftApp")
				if app then
					pcall(scanDraft, app)
				end
			end
		end
	})
	LastKitCount.Object.Visible = LastKitToggle.Enabled

	LevelToggle = KitRender:CreateToggle({
		Name = "show level",
		Default = true,
		Tooltip = "shows they level next to they name so u know if they a sweat or not",
		Function = function()
			if KitRender and KitRender.Enabled then
				local app = PlayerGui:FindFirstChild("MatchDraftApp")
				if app then
					pcall(scanDraft, app)
				end
			end
		end
	})

	PartyToggle = KitRender:CreateToggle({
		Name = "show party",
		Default = true,
		Tooltip = "puts a number on ppl who queue together, same number means same party",
		Function = function()
			if KitRender and KitRender.Enabled then
				local app = PlayerGui:FindFirstChild("MatchDraftApp")
				if app then
					pcall(scanDraft, app)
				end
			end
		end
	})
end)

run(function()
	local StaffDetector
	local Mode
	local Clans
	local Party
	local Profile
	local Users
	local AlertDuration
	local blacklistedclans = {'gg', 'gg2', 'DV', 'DV2', 'nwr'}
	local blacklisteduserids = {1502104539, 3826146717, 4531785383, 1049767300, 4926350670, 653085195, 184655415, 2752307430, 5087196317, 5744061325, 1536265275}
	local apiModNames = {}
	local teamNameMap = { [1] = 'Blue', [2] = 'Orange', [3] = 'Pink', [4] = 'Yellow' }
	local joined = {}
	local detectedPlayers = {}
	local processing = {}
	for _, name in ipairs({'chasemaser','IllIlllIIIllllIIIll','7SlyR','DoordashRP','OrionYeets','lIllllllllllIllIIlll','AUW345678','the2ndtestaccount','IllIIIIlllIlllIIIIIl','IllIIIIlllIlllIlIIII','ProSurferGamer1','22willow_place','celisnix','G_TP56','celisnix_3','nwrkr','lIIlIlIllllllIIlI','IllIIIIIIlllllIIlIlI','GorillaWithASuit','liilliilliiiliill','IllIllIllllIIIIIIlIl','Typhoon_Kang','VictoryForLife2468','IlIIIlllllIIIIlIIIIl','Erin_Ireland22','IIIIllIIIIIIlllIlIII','IIIIIlllIlllllIlII','Ghostwxstaken','wvwvwvwwvwvvwvw','lllIIllIllIIllIllII','TheAwkwardSponge','TotallyKoaIa','YT_GoraPlays','LegendaryToragon','appleapplelllllll','Yo_johnny67','llIIllIIllllIlIl','PoopFarm_1','llIIIllIIIIIllllIII','Lemon01204','HugeMudOtter','AGameMasterHD','krustykrab204','kevinchuey','IllIIIIlIllIlIIIlI','YoZevStar','pzlican','Deevicus','Blackprincess1','yhpro1230','eple_147','whoisdv2_erin','whoisdv4_erin','whoisdv3_erin','VicForLife14','SleeplessSoulmate','Jsquire07','DVwastaken','pxIican','devzebu','FunFamilyKids177','Artan3333','3MEWMTS5LJCB','Zengoulen','GloriousConfigB2','heywasupsir','c6chisa'}) do
		apiModNames[name:lower()] = true
	end
	local listsLoaded = true

	getgenv()._onnation_staffCounts = {spec=0, mod=0, impossible=0}
	local function refreshStaffCounts()
		local c = {spec=0, mod=0, impossible=0}
		for _, data in pairs(detectedPlayers) do
			local ct = data.checktype
			if ct == 'spectator' then c.spec += 1
			elseif ct == 'impossible_join' then c.impossible += 1
			elseif ct == 'unverified' then c.impossible += 1
			else c.mod += 1 end
		end
		getgenv()._aerov4_staffCounts = c
		vapeEvents.StaffCountUpdate:Fire()
	end

	local function staffFunction(plr, checktype)
		if detectedPlayers[plr.UserId] then return end
		if not vape.Loaded then repeat task.wait() until vape.Loaded end
		local duration = AlertDuration.Value
		local playerName = plr.Name
		local playerId = plr.UserId
		detectedPlayers[playerId] = {name=playerName, checktype=checktype, detectedTime=tick()}
		notif('StaffDetector', 'Staff Detected (' .. checktype .. '): ' .. playerName .. ' (' .. playerId .. ')', duration, 'alert')
		whitelist.customtags[playerName] = {{text='GAME STAFF', color=Color3.new(1,0,0)}}
		local isClanCheck = checktype:find('clan')					end
					for _, group in knownTiers do
						local chain = {items = {}, index = {}}
						for _, it in group do
							if itemsByType[it] then
								table.insert(chain.items, it)
								chain.index[it] = #chain.items
							end
						end
						if #chain.items > 1 then
							for _, it in chain.items do
								tierChains[it] = chain
							end
						end
					end
				end
				collectAndBypass()
				if bedwars.Shop and bedwars.Shop.getShop and not originalGetShop then
					originalGetShop = bedwars.Shop.getShop
					bedwars.Shop.getShop = function(...)
						local result = originalGetShop(...)
						if type(result) == "table" then
							applyBypassToTable(result)
						end
						return result
					end
				end
				
				if not originalClientGet then
					originalClientGet = bedwars.Client.Get
					local wrapperCache = setmetatable({}, {__mode = 'kv'})
					bedwars.Client.Get = function(self, name, ...)
						local remote = originalClientGet(self, name, ...)
						if name == 'BedwarsPurchaseItem' then
							local cached = wrapperCache[remote]
							if cached then return cached end
							local wrapper = {}
							wrapperCache[remote] = wrapper
							setmetatable(wrapper, {
								__index = function(_, key)
									if key == 'CallServerAsync' then
										return function(_, data, ...)
											if data and data.shopItem and data.shopItem.itemType then
												local itemType = data.shopItem.itemType
												if shouldBlock(itemType) then
													local displayName = bedwars.ItemMeta[itemType] and bedwars.ItemMeta[itemType].displayName or itemType
													if isDowngrade(itemType) then
														notif('ShopTierBypass', 'prevented yo ass from downgrading to '..displayName, 3, 'alert')
													else
														notif('ShopTierBypass', 'u alr got this item lmao: ', 3, 'alert')
													end
													return {andThen = function() end}
												end
											end
											return remote:CallServerAsync(data, ...)
										end
									end
									local value = remote[key]
									if type(value) == 'function' then
										return function(_, ...)
											return value(remote, ...)
										end
									end
									return value
								end
							})
							return wrapper
						end
						return remote
					end
				end

				local shopController = getShopController()
				if shopController and shopController.BedwarsShop and shopController.BedwarsShop.getShop then
					if not originalControllerShop then
						hookedController = shopController.BedwarsShop
						originalControllerShop = hookedController.getShop
						local base = originalControllerShop
						hookedController.getShop = function(...)
							local result = base(...)
							if type(result) == "table" then
								applyBypassToTable(result)
							end
							return result
						end
					end
				end
			else
				for item, _ in pairs(shopItemsTracked) do
					if item and type(item) == "table" then
						if tiered[item] ~= nil then
							item.tiered = tiered[item]
						end
						if nexttier[item] ~= nil then
							item.nextTier = nexttier[item]
						end
					end
				end
				
				if hookedController and originalControllerShop then
					hookedController.getShop = originalControllerShop
					originalControllerShop = nil
					hookedController = nil
				end
				
				if originalGetShop then
					bedwars.Shop.getShop = originalGetShop
					originalGetShop = nil
				end

				if originalClientGet then
					bedwars.Client.Get = originalClientGet
					originalClientGet = nil
				end
				
				table.clear(tiered)
				table.clear(nexttier)
				table.clear(shopItemsTracked)
				table.clear(tierChains)
			end
		end,
		Tooltip = 'lets u buy shit without buying the other tiers'
	})

	vape:Clean(function()
		if originalGetShop then
			pcall(function() bedwars.Shop.getShop = originalGetShop end)
			originalGetShop = nil
		end
		if originalClientGet then
			pcall(function() bedwars.Client.Get = originalClientGet end)
			originalClientGet = nil
		end
	end)
end)

run(function()
    local AutoPearl
    local Limit
    
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    rayCheck.FilterType = Enum.RaycastFilterType.Include
    local groundCheck = RaycastParams.new()
    groundCheck.RespectCanCollide = true
    groundCheck.FilterType = Enum.RaycastFilterType.Include
    local projectileRemote = {InvokeServer = function(self, ...) end}
    task.spawn(function()
    	projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    end)
    
    local function firePearl(pos, spot, item)
    	for _, v in store.selfProjectiles or {} do
    		if v.Name == 'telepearl' then
    			return
    		end
    	end

    	local originalSlot = store.inventory.hotbarSlot
    	local pearlSlot = getHotbar(item.tool)
    	if not pearlSlot then
    		switchItem(item.tool)
    	else
    		if hotbarSwitch(pearlSlot) then
    			task.wait(0.05)
    		end
    	end
    
    	local meta = bedwars.ProjectileMeta.telepearl
    	local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
    
    	if calc then
    		local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
    		local projectile = bedwars.ProjectileController:createLocalProjectile(meta, 'telepearl', 'telepearl', pos, nil, dir, {drawDurationSeconds = 1})
    		local res = projectileRemote:InvokeServer(
    			item.tool,
    			'telepearl',
    			'telepearl',
    			pos,
    			pos,
    			dir,
    			httpService:GenerateGUID(true),
    			{ 
                    drawDurationSeconds = 1, 
                    shotId = httpService:GenerateGUID(false) 
                },
    			workspace:GetServerTimeNow() - 0.045
    		)
    		if res then
    			pcall(function()
    				res.Parent = replicatedStorage
    			end)
    		end
    	end
    
    	if pearlSlot then
    		task.wait(0.05)
    		local swordSlot
    		for i, hv in store.inventory.hotbar do
    			if hv and hv.item and hv.item.itemType then
    				local hm = bedwars.ItemMeta[hv.item.itemType]
    				if hm and hm.sword then
    					swordSlot = i - 1
    					break
    				end
    			end
    		end
    		hotbarSwitch(swordSlot or originalSlot)
    	end
    end
    
    local function findNearGround(origin)
    	for _, v in {Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1)} do
    		for i = 1, 24 do
    			local ray = workspace:Raycast((origin.Position + (Vector3.yAxis * 3)) + (v * i), Vector3.new(0, -60, 0), groundCheck)
    			if ray then
    				return ray.Position + Vector3.new(0, 2, 0)
    			end
    		end
    	end
    	return nil
    end
    
    AutoPearl = vape.Categories.Utility:CreateModule({
    	Name = 'AutoPearl',
    	Function = function(callback)
    		if callback then
    			local check, lasty
    			repeat
    				if entitylib.isAlive and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'telepearl') then
    					local root = entitylib.character.RootPart
    					local pearl = getItem('telepearl')
    					local mapFolder = workspace:FindFirstChild('Map') or workspace
    					rayCheck.FilterDescendantsInstances = {mapFolder}
    					rayCheck.CollisionGroup = root.CollisionGroup
    					groundCheck.FilterDescendantsInstances = {mapFolder}
    					groundCheck.CollisionGroup = 'Default'
    
    					if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
    						lasty = root.CFrame
    					end
    
    					if pearl and root.Velocity.Y < -100 and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
    						if not check then
    							check = true
    							local ground = findNearGround(root.CFrame + Vector3.new(0, 40, 0)) or findNearGround(lasty and lasty + Vector3.new(0, 5, 0) or root.CFrame)
    							if ground then
    								firePearl(root.Position, ground, pearl)
    							end
    						end
    					else
    						check = false
    					end
    				end
    				task.wait(0.1)
    			until not AutoPearl.Enabled
    		end
    	end,
    	Tooltip = 'auto throws yo pearl when falling in the void'
    })
    
    Limit = AutoPearl:CreateToggle({
    	Name = 'Limit to pearl',
    	Tooltip = 'only throws when ur already holding a pearl'
    })
end)

--[[
	World Modules
]]

run(function()
	local Protect
	local Target
	local LimitItem
	local protectOffsets = {
		Vector3.new(3, 0, 0),
		Vector3.new(-3, 0, 0),
		Vector3.new(0, 0, 3),
		Vector3.new(0, 0, -3),
		Vector3.new(0, 3, 0),
		Vector3.new(0, -3, 0),
	}

	local function getMyBeehive()
		for _, v in collectionService:GetTagged('beehive') do
			if v:GetAttribute('PlacedByUserId') == lplr.UserId then
				return v
			end
		end
	end

	local function getTargetItem()
		if Target.Value == 'Beehive' then
			return getMyBeehive()
		end
	end

	local function getProtectBlock()
		if LimitItem.Enabled then
			if store.hand.toolType == 'block' then
				return store.hand.tool.Name
			end
			return nil
		end
		if StrongestBlock.Enabled then
			local best, bestHealth
			for _, item in store.inventory.inventory.items do
				local meta = bedwars.ItemMeta[item.itemType]
				if meta and meta.block and (item.amount or 0) > 0 then
					local health = meta.block.health or 0
					if not bestHealth or health > bestHealth then
						best = item.itemType
						bestHealth = health
					end
				end
			end
			return best
		end
		return getScaffoldBlockForModule(LimitItem)
	end

	Protect = vape.Categories.World:CreateModule({
		Name = 'Protect',
		Function = function(callback)
			if callback then
				repeat
					local item = getTargetItem()
					if item then
						local basePos = bedwars.BlockController:getBlockPosition(item.Position) * 3
						for _, offset in protectOffsets do
							if not Protect.Enabled then break end
							local pos = basePos + offset
							if not getPlacedBlock(pos) then
								local block = getProtectBlock()
								if block then
									task.spawn(bedwars.placeBlock, pos, block, false)
									task.wait(0.05)
								end
							end
						end
					end
					task.wait(0.5)
				until not Protect.Enabled
			end
		end,
		Tooltip = 'boxes ur hive in so nobody can break it gng - more coming soon ig'
	})

	Target = Protect:CreateDropdown({
		Name = 'Target',
		List = {'Beehive'},
		Default = 'Beehive'
	})
	LimitItem = Protect:CreateToggle({Name = 'Limit to items'})
	StrongestBlock = Protect:CreateToggle({Name = 'Use Strongest Block'})
end)

run(function()
	local BedProtector
	local LimitItem
	local AutoSwitch
	local RangeSlider
	local LayerSlider
	local currentLayer = 0
	local buildingComplete = false
	local heldBlockType = nil
	local previousSlot = nil
	local lastPlaceTime = 0

	local ALLOWED_BLOCKS = {
		obsidian = true,
		wood_plank_oak = true,
		wood_oak_plank = true,
		ceramic = true,
		stone_brick = true
	}

	local function isAllowedBlock(itemType)
		if ALLOWED_BLOCKS[itemType] then return true end
		return itemType:find('wool') ~= nil
	end

	local pyramidCache = {}
	local function getPyramid(size, grid)
		local key = size .. ':' .. grid
		if pyramidCache[key] then return pyramidCache[key] end
		local positions = {}
		for h = size, 0, -1 do
			for w = h, 0, -1 do
				table.insert(positions, Vector3.new(w, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w, (size - h), (h - w) * -1) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), (h - w) * -1) * grid)
			end
		end
		pyramidCache[key] = positions
		return positions
	end

	local function getMyBed()
		local myTeam = lplr:GetAttribute('Team')
		if not myTeam then return nil end
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return nil end
		for _, bed in collectionService:GetTagged('bed') do
			if bed and bed.Parent and bed:GetAttribute('Team'..myTeam..'NoBreak') then
				local bedPos = bed:IsA('BasePart') and bed.Position or (bed.PrimaryPart and bed.PrimaryPart.Position or bed:GetPivot().Position)
				if (root.Position - bedPos).Magnitude < 40 then
					return bed
				end
			end
		end
		return nil
	end

	local function getBlocks()
		local blocks = {}
		for _, item in store.inventory.inventory.items do
			local meta = bedwars.ItemMeta[item.itemType]
			if meta and meta.block and not meta.block.seeThrough and (item.amount or 0) > 0 and isAllowedBlock(item.itemType) then
				table.insert(blocks, {itemType = item.itemType, tool = item.tool, health = meta.block.health or 0})
			end
		end
		table.sort(blocks, function(a, b) return a.health > b.health end)
		return blocks
	end

	local function getBlockTypeForLayer(_, blocks)
		if #blocks == 0 then return nil end
		return blocks[1]
	end

	local function getSlotFor(itemType)
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType == itemType then
				return i - 1
			end
		end
		return nil
	end

	local function restorePreviousSlot()
		if heldBlockType then
			if previousSlot then hotbarSwitch(previousSlot) end
			heldBlockType = nil
			previousSlot = nil
		end
	end

	local function switchToBlock(itemType)
		if LimitItem.Enabled then return end
		if not AutoSwitch.Enabled then return end
		if heldBlockType == itemType then return end
		local slot = getSlotFor(itemType)
		if slot then
			previousSlot = previousSlot or store.inventory.hotbarSlot
			hotbarSwitch(slot)
			heldBlockType = itemType
		end
	end

	local function isPositionInRange(worldPos)
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return false end
		return (root.Position - worldPos).Magnitude <= RangeSlider.Value
	end

	local function repairAll(bedCFrame, blocks, upto)
		if upto <= 0 then return end

		local block = getBlockTypeForLayer(0, blocks) or blocks[1]
		if LimitItem.Enabled then
			if store.hand.toolType ~= 'block' then return end
			if not isAllowedBlock(store.hand.tool.Name) then return end
			block = {itemType = store.hand.tool.Name}
		end
		if not block then return end

		local switched = false
		for layer = 0, upto - 1 do
			local positions = getPyramid(layer + 1, 3)
			for _, pos in positions do
				if not BedProtector.Enabled then return end
				local worldPos = (bedCFrame * CFrame.new(pos)).Position
				if isPositionInRange(worldPos) and not getPlacedBlock(worldPos) then
					if not switched then
						switchToBlock(block.itemType)
						switched = true
					end
					task.spawn(bedwars.placeBlock, worldPos, block.itemType, false)
				end
			end
		end
	end

	local function buildLayer(bedCFrame, blocks)
		if buildingComplete then return false end

		local block = getBlockTypeForLayer(currentLayer, blocks) or blocks[1]
		if not block then return false end

		if LimitItem.Enabled then
			if store.hand.toolType ~= 'block' then return false end
			if not isAllowedBlock(store.hand.tool.Name) then return false end
			block = {itemType = store.hand.tool.Name}
		end

		local positions = getPyramid(currentLayer + 1, 3)
		local allPlaced = true
		local hasMissingInRange = false

		for _, pos in positions do
			local worldPos = (bedCFrame * CFrame.new(pos)).Position
			if not getPlacedBlock(worldPos) then
				allPlaced = false
				if isPositionInRange(worldPos) then
					hasMissingInRange = true
				end
			end
		end

		if allPlaced then
			currentLayer += 1
			if currentLayer >= LayerSlider.Value then
				buildingComplete = true
				restorePreviousSlot()
				notif('BedProtector', 'bed is fully walled gng ur good', 4)
			end
			return false
		end

		if not hasMissingInRange then return false end

		for _, pos in positions do
			if not BedProtector.Enabled then break end
			local worldPos = (bedCFrame * CFrame.new(pos)).Position
			if isPositionInRange(worldPos) and not getPlacedBlock(worldPos) then
				if tick() - lastPlaceTime >= 0.05 then
					switchToBlock(block.itemType)
					task.spawn(bedwars.placeBlock, worldPos, block.itemType, false)
					lastPlaceTime = tick()
					task.wait(0.05)
				end
			end
		end
		return true
	end

	BedProtector = vape.Categories.World:CreateModule({
		Name = 'BedProtector',
		Function = function(callback)
			if callback then
				currentLayer = 0
				buildingComplete = false
				heldBlockType = nil
				previousSlot = nil
				repeat
					pcall(function()
						if not entitylib.isAlive then return end
						local bed = getMyBed()
						if not bed then
							restorePreviousSlot()
							return
						end
						local bedCFrame = bed:IsA('BasePart') and bed.CFrame or (bed.PrimaryPart and bed.PrimaryPart.CFrame or bed:GetPivot())
						local blocks = getBlocks()
						if #blocks == 0 and not LimitItem.Enabled then return end
						repairAll(bedCFrame, blocks, currentLayer)
						if not buildingComplete then
							buildLayer(bedCFrame, blocks)
						end
					end)
					task.wait(0.05)
				until not BedProtector.Enabled
				restorePreviousSlot()
			end
		end,
		Tooltip = 'stacks a pyramid over ur bed w ur strongest block'
	})

	LimitItem = BedProtector:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'only builds while ur already holdin a block'
	})
	AutoSwitch = BedProtector:CreateToggle({
		Name = 'Auto Switch',
		Default = true,
		Tooltip = 'swaps ur hotbar to the block by itself then swaps back after. ignored if limit to items is on'
	})
	RangeSlider = BedProtector:CreateSlider({
		Name = 'Place Range',
		Min = 1,
		Max = 30,
		Default = 15,
		Suffix = ' studs'
	})
	LayerSlider = BedProtector:CreateSlider({
		Name = 'Layers',
		Min = 1,
		Max = 10,
		Default = 3,
		Suffix = ' layers'
	})
end)

run(function()
	local a = {Enabled = false}
	a = vape.Categories.World:CreateModule({
		Name = "LeaveParty",
		Function = function(call)
			if call then
				a:Toggle(false)
				game:GetService("ReplicatedStorage"):WaitForChild("events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events"):WaitForChild("leaveParty"):FireServer()
			end
		end
	})
end)

run(function()
    local anim
    local asset
    local trackingConnection
    local lastPosition
    local NightmareEmote
    local cachedRootPart
    local cachedHumanoid
    local lastValidationCheck = 0
    
    NightmareEmote = vape.Categories.World:CreateModule({
        Name = "NightmareEmote",
        Function = function(call)
            if call then
                local l__GameQueryUtil__8
                if (not shared.CheatEngineMode) then 
                    l__GameQueryUtil__8 = require(game:GetService("ReplicatedStorage")['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil 
                else
                    local backup = {}; function backup:setQueryIgnored() end; l__GameQueryUtil__8 = backup;
                end
                local l__TweenService__9 = tweenService
                local player = playersService.LocalPlayer
                local character = player.Character
                
                if not character then 
                    NightmareEmote:Toggle() 
                    return 
                end
                
                local humanoid = character:WaitForChild("Humanoid")
                local rootPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
                
                if not rootPart then 
                    NightmareEmote:Toggle() 
                    return 
                end
                
                cachedRootPart = rootPart
                cachedHumanoid = humanoid
                lastPosition = rootPart.Position
                lastValidationCheck = 0
                
                local v10 = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Effects"):WaitForChild("NightmareEmote"):Clone()
                asset = v10
                v10.Parent = game.Workspace
                
                local descendants = v10:GetDescendants()
                for _, part in ipairs(descendants) do
                    if part:IsA("BasePart") then
                        l__GameQueryUtil__8:setQueryIgnored(part, true)
                        part.CanCollide = false
                        part.Anchored = true
                    end
                end
                
                local l__Outer__15 = v10:FindFirstChild("Outer")
                if l__Outer__15 then
                    l__TweenService__9:Create(l__Outer__15, TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {
                        Orientation = l__Outer__15.Orientation + Vector3.new(0, 360, 0)
                    }):Play()
                end
                
                local l__Middle__16 = v10:FindFirstChild("Middle")
                if l__Middle__16 then
                    l__TweenService__9:Create(l__Middle__16, TweenInfo.new(12.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {
                        Orientation = l__Middle__16.Orientation + Vector3.new(0, -360, 0)
                    }):Play()
                end
                
                anim = Instance.new("Animation")
                anim.AnimationId = "rbxassetid://9191822700"
                anim = humanoid:LoadAnimation(anim)
                anim:Play()
                
                local movementThresholdSq = 0.1 * 0.1
                
                trackingConnection = runService.RenderStepped:Connect(function()
                    if not asset or not asset.Parent then 
                        if trackingConnection then
                            trackingConnection:Disconnect()
                        end
                        return 
                    end
                    
                    local currentTime = tick()
                    
                    if (currentTime - lastValidationCheck) > 0.5 then
                        if not character or not character.Parent then
                            asset:Destroy()
                            asset = nil
                            if trackingConnection then
                                trackingConnection:Disconnect()
                            end
                            NightmareEmote:Toggle()
                            return
                        end
                        
                        if not cachedRootPart or not cachedRootPart.Parent then
                            cachedRootPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
                        end
                        
                        if not cachedHumanoid or not cachedHumanoid.Parent then
                            cachedHumanoid = character:FindFirstChildOfClass("Humanoid")
                        end
                        
                        if not cachedRootPart or not cachedHumanoid or cachedHumanoid.Health <= 0 then
                            asset:Destroy()
                            asset = nil
                            if trackingConnection then
                                trackingConnection:Disconnect()
                            end
                            NightmareEmote:Toggle()
                            return
                        end
                        
                        lastValidationCheck = currentTime
                    end
                    
                    if lastPosition and cachedRootPart then
                        local currentPosition = cachedRootPart.Position
                        local dx = currentPosition.X - lastPosition.X
                        local dy = currentPosition.Y - lastPosition.Y
                        local dz = currentPosition.Z - lastPosition.Z
                        local distanceMovedSq = dx * dx + dy * dy + dz * dz
                        
                        if distanceMovedSq > movementThresholdSq then
                            asset:Destroy()
                            asset = nil
                            if trackingConnection then
                                trackingConnection:Disconnect()
                            end
                            NightmareEmote:Toggle()
                            return
                        end
                        
                        lastPosition = currentPosition
                    end
                    
                    if cachedRootPart then
                        v10:SetPrimaryPartCFrame(cachedRootPart.CFrame * CFrame.new(0, -3, 0))
                    end
                end)
                
                NightmareEmote:Clean(trackingConnection)
                
            else 
                if trackingConnection then
                    trackingConnection:Disconnect()
                    trackingConnection = nil
                end
                
                if anim then 
                    anim:Stop()
                    anim = nil
                end
                
                if asset then
                    asset:Destroy() 
                    asset = nil
                end
                
                lastPosition = nil
                cachedRootPart = nil
                cachedHumanoid = nil
                lastValidationCheck = 0
            end
        end
    })
end)

run(function()
    local AutoCounter
    local tntCount
    local LimitItem
    local AutoPlaceToggle
    local HighlightToggle
    local alltntBlocks = {}
    local counteredtnt = {}
    local tntHighlights = {}
    local tntRemovalConnections = {}
    local autoCounterPlacing = false

    local function addHighlight(tntBlock)
        if tntHighlights[tntBlock] or not tntBlock.Parent then return end
        local h = Instance.new('SelectionBox')
        h.Adornee = tntBlock
        h.Color3 = Color3.fromRGB(255, 50, 50)
        h.LineThickness = 0.05
        h.SurfaceTransparency = 0.6
        h.SurfaceColor3 = Color3.fromRGB(255, 50, 50)
        h.Parent = coreGui
        tntHighlights[tntBlock] = h
    end

    local function removeHighlight(tntBlock)
        if tntHighlights[tntBlock] then
            tntHighlights[tntBlock]:Destroy()
            tntHighlights[tntBlock] = nil
        end
    end

    local function clearAllHighlights()
        for _, h in pairs(tntHighlights) do
            h:Destroy()
        end
        table.clear(tntHighlights)
    end

    local function isEnemytnt(tntBlock)
        if not tntBlock or not tntBlock.Parent then return false end
        if tntBlock:GetAttribute("AutoCountertnt") then return false end

        local placerId = tntBlock:GetAttribute("PlacedByUserId")
        if not placerId then
            return true
        end

        if placerId == lplr.UserId then
            return false
        end
        local myTeam = lplr:GetAttribute('Team')
        if myTeam then
            for _, player in playersService:GetPlayers() do
                if player.UserId == placerId and player:GetAttribute('Team') == myTeam then
                    return false
                end
            end
        end

        return true
    end

    local function isHoldingtnt()
        return isHoldingItem({'tnt'})
    end

    AutoCounter = vape.Categories.World:CreateModule({
        Name = 'AutoCounter',
        Function = function(callback)
            if callback then
                table.clear(counteredtnt)

                local function trackTnt(obj)
                    if not AutoCounter.Enabled or obj.Name ~= "tnt" or not obj:IsA("Part") or alltntBlocks[obj] then return end
                    if autoCounterPlacing then
                        obj:SetAttribute("AutoCountertnt", true)
                    end
                    alltntBlocks[obj] = true

                    task.defer(function()
                        if AutoCounter.Enabled and HighlightToggle and HighlightToggle.Enabled and isEnemytnt(obj) then
                            addHighlight(obj)
                        end
                    end)

                    local connection
                    connection = obj.AncestryChanged:Connect(function()
                        if not obj:IsDescendantOf(workspace) then
                            alltntBlocks[obj] = nil
                            counteredtnt[obj] = nil
                            removeHighlight(obj)

                            local fixedPos = fixPosition(obj.Position)
                            local posKey = string.format("%.0f,%.0f,%.0f", fixedPos.X, fixedPos.Y, fixedPos.Z)
                            if autoCounterPositions then
                                autoCounterPositions[posKey] = nil
                            end

                            connection:Disconnect()
                            tntRemovalConnections[obj] = nil
                        end
                    end)

                    tntRemovalConnections[obj] = connection
                end

                AutoCounter:Clean(workspace.DescendantAdded:Connect(trackTnt))
                scanDescendants(workspace, trackTnt, AutoCounter)

                local horizontalSides = {}
                for _, side in ipairs(Enum.NormalId:GetEnumItems()) do
                    local sideVec = Vector3.fromNormalId(side)
                    if sideVec.Y == 0 then
                        table.insert(horizontalSides, sideVec)
                    end
                end

                repeat
                    if not entitylib.isAlive then
                        task.wait(0.1)
                        continue
                    end

                    if HighlightToggle and HighlightToggle.Enabled then
                        for tntBlock in pairs(alltntBlocks) do
                            if tntBlock.Parent and isEnemytnt(tntBlock) then
                                addHighlight(tntBlock)
                            end
                        end
                    else
                        clearAllHighlights()
                    end

                    if AutoPlaceToggle and AutoPlaceToggle.Enabled then
                        if LimitItem.Enabled and not isHoldingtnt() then
                            task.wait(0.1)
                            continue
                        end

                        if not getItem("tnt") then
                            task.wait(0.1)
                            continue
                        end

                        local myPosition = entitylib.character.RootPart.Position
                        local maxDistanceSq = 30 * 30

                        for tntBlock in pairs(alltntBlocks) do
                            if tntBlock.Parent and not counteredtnt[tntBlock] and isEnemytnt(tntBlock) then
                                local offset = tntBlock.Position - myPosition
                                local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z

                                if distanceSq <= maxDistanceSq then
                                    local placedCount = 0
                                    local maxCount = tntCount.Value

                                    for _, sideVec in ipairs(horizontalSides) do
                                        if LimitItem.Enabled and not isHoldingtnt() then break end
                                        if placedCount >= maxCount then break end

                                        local placePos = fixPosition(tntBlock.Position + sideVec * 3.5)
                                        if not getPlacedBlock(placePos) and getItem("tnt") then
                                            if LimitItem.Enabled and not isHoldingtnt() then break end
                                            autoCounterPlacing = true
                                            bedwars.placeBlock(placePos, "tnt")
                                            autoCounterPlacing = false
                                            placedCount = placedCount + 1
                                            task.wait(0.05)
                                        end
                                    end

                                    counteredtnt[tntBlock] = true
                                end
                            end
                        end
                    end

                    task.wait(0.1)
                until not AutoCounter.Enabled
            else
                for _, conn in pairs(tntRemovalConnections) do
                    conn:Disconnect()
                end
                table.clear(tntRemovalConnections)
                table.clear(alltntBlocks)
                table.clear(counteredtnt)
                clearAllHighlights()
            end
        end,
        Tooltip = 'Highlights and counters enemys tnt'
    })

    tntCount = AutoCounter:CreateSlider({
        Name = 'tnt Count',
        Min = 1,
        Max = 5,
        Default = 3
    })

    LimitItem = AutoCounter:CreateToggle({
        Name = 'Limit to tnt',
        Default = true,
    })

    AutoPlaceToggle = AutoCounter:CreateToggle({
        Name = 'AutoPlace',
        Default = true,
    })

    HighlightToggle = AutoCounter:CreateToggle({
        Name = 'Highlight',		end
		table.clear(ntReference)
	end
	local function ntScan()
		local descendants = store.map:GetDescendants()
		for i, v in descendants do
			if not PotatoMode.Enabled or Mode.Value ~= 'No Texture' then return end
			ntStrip(v)
			if i % 500 == 0 then
				task.wait()
			end
		end
	end

	PotatoMode = vape.Categories.World:CreateModule({
		Name = 'PotatoMode',
		Function = function(callback)
			if callback then
				if Mode.Value == 'No Texture' then
					repeat task.wait() until store.map or not PotatoMode.Enabled
					if not PotatoMode.Enabled then return end
					PotatoMode:Clean(store.map.DescendantAdded:Connect(function(obj)
						task.defer(ntStrip, obj)
					end))
					ntScan()
				else
					processExistingBlocks(true)
					setupBlockMonitor(true)
				end
			else
				processExistingBlocks(false)
				for _, conn in blockMonitorConnections do
					conn:Disconnect()
				end
				table.clear(blockMonitorConnections)
				table.clear(cachedColors)
				cleanupDeadReferences()
				ntRestore()
			end
		end,
	})
	Mode = PotatoMode:CreateDropdown({
		Name = 'Mode',
		List = {'Original', 'No Texture'},
		Default = 'Original',
		Tooltip = 'Original = flat colored blocks, No Texture = strips everything off the map',
		Function = function(val)
			if PotatoMode.Enabled then
				PotatoMode:Toggle()
				PotatoMode:Toggle()
			end
		end
	})
end)

run(function()
	local Clutch
	local LimitItem

	local function getScaffoldBlock()
		return getScaffoldBlockForModule(LimitItem)
	end

	local lastPlace = 0

	Clutch = vape.Categories.World:CreateModule({
		Name = 'Clutch',
		Tooltip = 'clutchs for u via blocks',
		Function = function(callback)
			if callback then
				Clutch:Clean(runService.Heartbeat:Connect(function()
					if not Clutch.Enabled or not entitylib.isAlive then return end
					local root = entitylib.character.RootPart
					if not root then return end
					if root.Velocity.Y >= -50 then return end
					local wool = getScaffoldBlock()
					if not wool then return end
					local now = os.clock()
					if now - lastPlace < 0.05 then return end
					local target = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + 4.5, 0))
					if not getPlacedBlock(target) then
						local prox = blockProximity(target)
						bedwars.placeBlock(prox or target, wool, false)
						lastPlace = now
					end
				end))
			else
				lastPlace = 0
			end
		end,
	})

	LimitItem = Clutch:CreateToggle({
		Name = 'Limit to items',
		Default = false,
	})
end)

run(function()
	local PhaseMine
	local connections = {}
	local trackedParts = {}
	local lastWeaponState = nil
	local weaponCheckCounter = 0
	
	local function removeCollision(character)
		if not character then return end
		
		local charParts = trackedParts[character]
		if not charParts then
			charParts = {}
			trackedParts[character] = charParts
			
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					table.insert(charParts, {part = part, origCollide = part.CanCollide, origQuery = part.CanQuery})
					part.CanCollide = false
					part.CanQuery = false
				end
			end
		else
			for _, entry in charParts do
				if entry.part and entry.part.Parent then
					entry.part.CanCollide = false
					entry.part.CanQuery = false
				end
			end
		end
	end
	
	local function restoreCollision(character)
		if not character then return end
		
		local charParts = trackedParts[character]
		if charParts then
			for _, entry in charParts do
				if entry.part and entry.part.Parent then
					entry.part.CanCollide = entry.origCollide
					entry.part.CanQuery = entry.origQuery
				end
			end
		end
	end

	local function updateAllCollisions(forceUpdate)
		weaponCheckCounter = weaponCheckCounter + 1
		local shouldCheck = forceUpdate or (weaponCheckCounter % 3 == 0)
		
		if not shouldCheck then return end
		
		local isWeaponEquipped = hasValidWeapon()
		
		if not forceUpdate and lastWeaponState == isWeaponEquipped then
			return
		end
		
		lastWeaponState = isWeaponEquipped
		
		for _, entity in entitylib.List do
			if entity.Character and entity.Character.Parent then
				if isWeaponEquipped then
					restoreCollision(entity.Character)
				else
					removeCollision(entity.Character)
				end
			end
		end
	end
	
	local motorParts = {}
	local function updateMotorParts()
		for _, entity in entitylib.List do
			if entity.Character then
				local charMotors = motorParts[entity.Character]
				
				if not charMotors then
					charMotors = {}
					motorParts[entity.Character] = charMotors
					
					for _, part in entity.Character:GetChildren() do
						if part:IsA("BasePart") and part.Name == "Part" and part:FindFirstChildOfClass("Motor6D") then
							table.insert(charMotors, part)
						end
					end
				end
				
				for _, part in charMotors do
					if part and part.Parent then
						part.CanCollide = false
					end
				end
			end
		end
	end
	
	local tracked = {}
	local descConnections = {}

	PhaseMine = vape.Categories.World:CreateModule({
		Name = 'PhaseMine',
		Function = function(callback)
			if callback then

				local function ignorePart(part)
					pcall(function()
						bedwars.QueryUtil:setQueryIgnored(part, true)
					end)
				end

				local function onPartAdded(char, part)
					if not PhaseMine.Enabled or not char or char == lplr.Character then return end
					if not part:IsA('BasePart') then return end
					local list = tracked[char]
					if not list then
						list = {}
						tracked[char] = list
					end
					if not list[part] then
						list[part] = true
						ignorePart(part)
					end
				end

				local function applyToChar(char)
					if not char or char == lplr.Character then return end
					for _, part in char:GetDescendants() do
						onPartAdded(char, part)
					end
				end

				local function setupCharacter(char)
					if not char then return end
					if char == lplr.Character then return end
					if descConnections[char] then
						descConnections[char]:Disconnect()
						descConnections[char] = nil
					end
					applyToChar(char)
					local conn = char.DescendantAdded:Connect(function(part)
						onPartAdded(char, part)
					end)
					descConnections[char] = conn
				end

				local function cleanupCharacter(char)
					if descConnections[char] then
						descConnections[char]:Disconnect()
						descConnections[char] = nil
					end
					tracked[char] = nil
				end

				local function applyToAll(remove)
					for _, entity in ipairs(entitylib.List) do
						if entity.Character then
							applyToChar(entity.Character, remove)
						end
					end
					for _, obj in ipairs(workspace:GetChildren()) do
						if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
							if obj ~= lplr.Character then
								applyToChar(obj, remove)
							end
						end
					end
				end

				local function updateCollision()
					if not PhaseMine.Enabled then return end
					applyToAll()
				end

				local function setupAllCharacters()
					for _, entity in ipairs(entitylib.List) do
						if entity.Character then
							setupCharacter(entity.Character)
						end
					end
					for _, obj in ipairs(workspace:GetChildren()) do
						if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
							if obj ~= lplr.Character then
								setupCharacter(obj)
							end
						end
					end
				end

				task.wait(0.2)
				setupAllCharacters()
				updateCollision()

				local entityAdded = entitylib.Events.EntityAdded:Connect(function(entity)
					if entity.Character then
						task.wait(0.1)
						setupCharacter(entity.Character)
					end
				end)
				table.insert(connections, entityAdded)

				local workspaceChildAdded = workspace.ChildAdded:Connect(function(obj)
					if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
						if obj ~= lplr.Character then
							task.wait(0.1)
							setupCharacter(obj)
						end
					end
				end)
				table.insert(connections, workspaceChildAdded)

				local entityRemoved = entitylib.Events.EntityRemoved:Connect(function(entity)
					if entity.Character then
						cleanupCharacter(entity.Character)
					end
				end)
				table.insert(connections, entityRemoved)

				local workspaceChildRemoved = workspace.ChildRemoved:Connect(function(obj)
					if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
						if obj ~= lplr.Character then
							cleanupCharacter(obj)
						end
					end
				end)
				table.insert(connections, workspaceChildRemoved)

				local localAdded = lplr.CharacterAdded:Connect(function(char)
					if PhaseMine.Enabled then
						if lplr.Character and lplr.Character ~= char then
							cleanupCharacter(lplr.Character)
						end
						task.wait(0.2)
						updateCollision()
						setupAllCharacters()
					end
				end)
				table.insert(connections, localAdded)

			else
				for _, conn in ipairs(connections) do
					conn:Disconnect()
				end
				table.clear(connections)

				for char, conn in pairs(descConnections) do
					conn:Disconnect()
				end
				table.clear(descConnections)

				for char, list in pairs(tracked) do
					for part in pairs(list) do
						if part.Parent then
							pcall(function()
								bedwars.QueryUtil:setQueryIgnored(part, false)
							end)
						end
					end
				end
				table.clear(tracked)
			end
		end,
		Tooltip = 'mine OR build through players and npcs'
	})
end)

run(function()
	local AntiEffects
	local AntiDizzy
	local AntiSleep
	local AntiTrap
	local AntiFear
	local old = nil
	local oldAdd = nil
	local sleepModifier = nil

	local function applyEffects()
		if AntiDizzy and AntiDizzy.Enabled then
			if not old then
				old = bedwars.ForestEnvironmentCollectibleEntityController.canPickupEntity
			end
			bedwars.ForestEnvironmentCollectibleEntityController.canPickupEntity = function(a, b, c)
				local selfRef, plr, mushroom = a, b, c
				if c == nil then
					selfRef, plr, mushroom = nil, a, b
				end
				if typeof(mushroom) == 'Instance' then
					local mush = mushroom:GetAttribute('MushroomType')
					if mush == 'Dizzy' then return false end
					if mush then return true end
				end
				if selfRef == nil then
					return old(plr, mushroom)
				end
				return old(selfRef, plr, mushroom)
			end
			runService:BindToRenderStep('antieffects_dizzy', Enum.RenderPriority.Character.Value + 2, function()
				runService:UnbindFromRenderStep('dizzy-status')
			end)
		else
			if old then
				bedwars.ForestEnvironmentCollectibleEntityController.canPickupEntity = old
				old = nil
			end
			runService:UnbindFromRenderStep('antieffects_dizzy')
		end

		if AntiTrap and AntiTrap.Enabled then
			runService:BindToRenderStep('antieffects_trap', Enum.RenderPriority.Character.Value + 2, function()
				local char = lplr.Character
				if not char then return end
				local hum = char:FindFirstChildOfClass('Humanoid')
				if char:GetAttribute('SnapTrapMarked') then
					char:SetAttribute('SnapTrapMarked', nil)
				end
				if hum then
					if hum.JumpPower == 0 then hum.JumpPower = 50 end
					if hum.JumpHeight == 0 then hum.JumpHeight = 7.2 end
					if hum.WalkSpeed < 10 then hum.WalkSpeed = 16 end
				end
			end)
		else
			runService:UnbindFromRenderStep('antieffects_trap')
		end

		if AntiFear and AntiFear.Enabled then
			runService:UnbindFromRenderStep('werewolf-fear-status')
			runService:BindToRenderStep('antieffects_fear', Enum.RenderPriority.Character.Value + 2, function()
				runService:UnbindFromRenderStep('werewolf-fear-status')
			end)
		else
			runService:UnbindFromRenderStep('antieffects_fear')
		end

		if AntiSleep and AntiSleep.Enabled then
			local char = lplr.Character
			if char then
				sleepModifier = bedwars.SprintController:getMovementStatusModifier()
				oldAdd = sleepModifier.addModifier
				sleepModifier.addModifier = function(self, tab)
					if tab and tab.moveSpeedMultiplier and tab.moveSpeedMultiplier <= 0 then
						return oldAdd(self, { moveSpeedMultiplier = 1 })
					end
					return oldAdd(self, tab)
				end
				runService:BindToRenderStep('antieffects_sleep', Enum.RenderPriority.Character.Value + 2, function()
					local stunTime = char:GetAttribute('StunnedUntilTime')
					local now = workspace:GetServerTimeNow()
					if stunTime and stunTime > now then
						char:SetAttribute('StunnedUntilTime', -1)
					end
					for mod, _ in sleepModifier.modifiers do
						if type(mod) == 'table' and (mod.moveSpeedMultiplier or 1) <= 0 then
							sleepModifier:removeModifier(mod)
						end
					end
					local hum = char:FindFirstChildOfClass('Humanoid')
					if hum then
						if hum.JumpPower == 0 then hum.JumpPower = 50 end
						if hum.JumpHeight == 0 then hum.JumpHeight = 7.2 end
					end
				end)
			end
		else
			runService:UnbindFromRenderStep('antieffects_sleep')
			if sleepModifier and oldAdd then
				sleepModifier.addModifier = oldAdd
				oldAdd = nil
				sleepModifier = nil
			end
		end
	end

	AntiEffects = vape.Categories.World:CreateModule({
		Name = 'AntiEffects',
		Tooltip = 'blocks negative effects',
		Function = function(callback)
			if callback then
				applyEffects()
			else
				if old then
					bedwars.ForestEnvironmentCollectibleEntityController.canPickupEntity = old
					old = nil
				end
				runService:UnbindFromRenderStep('antieffects_dizzy')
				runService:UnbindFromRenderStep('antieffects_sleep')
				runService:UnbindFromRenderStep('antieffects_fear')
				runService:UnbindFromRenderStep('antieffects_trap')
				if sleepModifier and oldAdd then
					sleepModifier.addModifier = oldAdd
					oldAdd = nil
					sleepModifier = nil
				end
			end
		end
	})
	AntiDizzy = AntiEffects:CreateToggle({
		Name = 'Dizzy',
		Tooltip = 'blocks dizzy effects from mushrooms and toads',
		Default = true,
		Function = function()
			if AntiEffects.Enabled then applyEffects() end
		end
	})
	AntiSleep = AntiEffects:CreateToggle({
		Name = 'Sleep',
		Tooltip = 'blocks sleep splash potion effect',
		Default = true,
		Function = function()
			if AntiEffects.Enabled then applyEffects() end
		end
	})
	AntiTrap = AntiEffects:CreateToggle({
		Name = 'Trap',
		Tooltip = 'allows you to move when snapped by a trap',
		Default = true,
		Function = function()
			if AntiEffects.Enabled then applyEffects() end
		end
	})
	AntiFear = AntiEffects:CreateToggle({
		Name = 'Fear',
		Tooltip = 'stops werewolf fear from walkin u away from them',
		Default = true,
		Function = function()
			if AntiEffects.Enabled then applyEffects() end
		end
	})
end)

run(function()
	local AntiMagma

	AntiMagma = vape.Categories.World:CreateModule({
		Name = "AntiMagma",
		Tooltip = 'allows you not to be instantly killed by magma',
		Function = function(callback)
			if callback then
				local function disableMagmaPart(v)
					if not v:IsA("BasePart") then return end
					if not string.find(string.lower(v.Name), 'magma') then return end
					for _, stuff in v:GetDescendants() do
						if stuff:IsA("TouchTransmitter") then
							pcall(function() stuff:Destroy() end)
						end
					end
				end

				scanDescendants(workspace, disableMagmaPart, AntiMagma)

				AntiMagma:Clean(workspace.DescendantAdded:Connect(function(v)
					disableMagmaPart(v)
				end))
				local worldFolder = getWorldFolder()
				if not worldFolder then return end
				local blocks = worldFolder:WaitForChild("Blocks", 1)
				if not blocks then return end
				AntiMagma:Clean(blocks.ChildAdded:Connect(function(v)
					disableMagmaPart(v)
				end))
			end
		end
	})
end)

run(function()
    local BlockIn
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    local PlaceSpeed
    local LimitItem
    local Blacklist

    local function isBlacklisted(itemType)
        return Blacklist and table.find(Blacklist.ListEnabled, itemType)
    end

    local function getBlocks()
        local blocks = {}

        if LimitItem and LimitItem.Enabled then
            local itemType = store.hand.toolType == 'block' and store.hand.tool and store.hand.tool.Name
            local meta = itemType and bedwars.ItemMeta[itemType]
            local block = meta and meta.block
            if block and not isBlacklisted(itemType) and (store.hand.amount or 0) > 0 then
                table.insert(blocks, { itemType, block.health or 0, store.hand.tool, store.hand.amount })
            end
            return blocks
        end

        for _, item in store.inventory.inventory.items do
            local itemType = item.itemType
            local meta = itemType and bedwars.ItemMeta[itemType]
            local block = meta and meta.block
            if block and not isBlacklisted(itemType) and (item.amount or 0) > 0 then
                table.insert(blocks, { itemType, block.health or 0, item.tool, item.amount })
            end
        end
        table.sort(blocks, function(a, b)
            return a[2] > b[2]
        end)
        return blocks
    end

    local function getPyramid()
        return {
            Vector3.new(0, 0, 3),
            Vector3.new(0, 3, 3),
            Vector3.new(-3, 0, 0),
            Vector3.new(-3, 3, 0),
            Vector3.new(0, 0, -3),
            Vector3.new(0, 3, -3),
            Vector3.new(3, 0, 0),
            Vector3.new(3, 3, 0),
            Vector3.new(3, 6, 0),
            Vector3.new(0, 6, 0),
        }
    end

    local function isMoving()
        if not entitylib.isAlive then return false end
        local vel = entitylib.character.RootPart.AssemblyLinearVelocity
        return Vector3.new(vel.X, 0, vel.Z).Magnitude > 2
    end

    local function doBuild()
        local basePos = bedwars.BlockController:getBlockPosition(entitylib.character.RootPart.Position) * 3
        rayCheck.FilterDescendantsInstances = { lplr.Character, gameCamera }
        local oldPlaceCPS = bedwars.SharedConstants.BLOCK_PLACE_CPS
        bedwars.SharedConstants.BLOCK_PLACE_CPS = 20
        local blocks = getBlocks()
        if #blocks < 1 then
            notif('BlockIn', 'Missing blocks', 4, 'warning')
        end
        local pattern = getPyramid()
        local aborted = false
        for attempt = 1, 4 do
            if not BlockIn.Enabled or not entitylib.isAlive then break end
            for _, block in blocks do
                if not BlockIn.Enabled or not entitylib.isAlive then break end
                if (block[4] or 0) <= 0 then continue end
                local switched = false
                for _, pos in pattern do
                    if not BlockIn.Enabled or not entitylib.isAlive then break end
                    if isMoving() then
                        aborted = true
                        break
                    end
                    local target = basePos + pos
                    if getPlacedBlock(target) then continue end
                    if not switched then
                        for index, v in store.inventory.hotbar do
                            if v.item and v.item.tool == block[3] and index ~= (store.inventory.hotbarSlot + 1) then
                                hotbarSwitch(index - 1)
                                break
                            end
                        end
                        switched = true
                    end
                    bedwars.placeBlock(target, block[1])
                    local delay = PlaceSpeed.Value
                    if delay > 0 then task.wait(delay) end
                end
                if aborted then break end
            end
            if aborted then break end
            local complete = true
            for _, pos in pattern do
                if not getPlacedBlock(basePos + pos) then
                    complete = false
                    break
                end
            end
            if complete then break end
            task.wait(0.08)
        end
        bedwars.SharedConstants.BLOCK_PLACE_CPS = oldPlaceCPS or 12
        return aborted
    end

    BlockIn = vape.Categories.World:CreateModule({
        Name = 'BlockIn',
        Function = function(callback)
            if callback then
                if not entitylib.isAlive then
                elseif LimitItem and LimitItem.Enabled and store.hand.toolType ~= 'block' then
                    notif('BlockIn', 'Hold a block first', 2, 'warning')
                else
                    doBuild()
                end
                if BlockIn.Enabled then
                    BlockIn:Toggle()
                end
            end
        end,
        Tooltip = 'auto places blocks around yo self'
    })

    PlaceSpeed = BlockIn:CreateSlider({
        Name = 'Placement Speed',
        Min = 0,
        Max = 0.5,
        Default = 0.07,
        Decimal = 100,
        Suffix = 'seconds',
    })
    LimitItem = BlockIn:CreateToggle({
        Name = 'Limit to items',
    })
    Blacklist = BlockIn:CreateTextList({
        Name = 'Blacklists',
        Placeholder = 'block',
        Default = {
            'cannon',
            'tnt',
            'siege_tnt',
        }
    })
end)

run(function()
    local AutoSuffo
    local Range
    local LimitItem
    local Targets

    local function fixPosition(pos)
        return bedwars.BlockController:getBlockPosition(pos) * 3
    end

    local ring = {
        Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0),
        Vector3.new(0, 0, 3), Vector3.new(0, 0, -3),
    }

    local function getBlockItem()
        if store.hand.toolType == 'block' then
            return store.hand.tool.Name
        elseif not LimitItem.Enabled then
            return (getWool())
        end
        return nil
    end

    local function predict(part)
        local vel = part.AssemblyLinearVelocity or Vector3.zero
        return part.Position + vel * lplr:GetNetworkPing()
    end

    local function buildCells(ent)
        local root = predict(ent.RootPart)
        local head = predict(ent.Head)
        local cells = {}
        table.insert(cells, fixPosition(head))
        table.insert(cells, fixPosition(head + Vector3.new(0, 3, 0)))
        for _, o in ring do
            table.insert(cells, fixPosition(head + o))
            table.insert(cells, fixPosition(root + o))
        end
        return cells
    end

    AutoSuffo = vape.Categories.World:CreateModule({
        Name = 'AutoSuffo',
        Function = function(callback)
            if callback then
                repeat
                    local item = entitylib.isAlive and getBlockItem()

                    if item then
                        for _, ent in entitylib.AllPosition({
                            Part = 'RootPart',
                            Range = Range.Value,
                            Players = Targets.Players.Enabled,
                            NPCs = Targets.NPCs.Enabled,
                        }) do
                            if ent.Targetable and ent.Head then
                                for _, pos in buildCells(ent) do
                                    if not getPlacedBlock(pos) and checkFaceAdjacent(pos) then
                                        task.spawn(bedwars.placeBlock, pos, item)
                                    end
                                end
                            end
                        end
                    end

                    task.wait(0.05)
                until not AutoSuffo.Enabled
            end
        end,
    })
    Range = AutoSuffo:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 20,
        Default = 14,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    Targets = AutoSuffo:CreateTargets({Players = true})
    LimitItem = AutoSuffo:CreateToggle({
        Name = 'Limit to Items',
    })
end)

--[[
	Inventory Modules
]]

run(function()
	local AutoBank
	local UIToggle
	local GUICheck
	local UI
	local Chests
	local Items = {}
	local BankToggles = {
		iron = nil,
		diamond = nil,
		emerald = nil
	}
	local cachedChest
	local lastChestCheck = 0
	local lastHotbarUpdate = 0
	local Spectators
	local TeamCheck
	local BankOnLeave
	local lastBaseDist
	local baseChestCache, baseChestCheck = nil, 0

	local function getSpectator()
		local myTeam = lplr:GetAttribute('Team')
		for _, plr in playersService:GetPlayers() do
			if plr ~= lplr and (plr:GetAttribute('Spectator') or (plr.Team and plr.Team.Name == 'Spectators')) then
				if not myTeam or plr:GetAttribute('Team') ~= myTeam then
					return plr
				end
			end
		end
		return nil
	end

	local function getBaseChest()
		if baseChestCache and baseChestCache.Parent and tick() - baseChestCheck < 2 then
			return baseChestCache
		end
		baseChestCheck = tick()
		baseChestCache = nil
		local root = entitylib.isAlive and entitylib.character.RootPart
		local best, bestDist
		local myTeam = lplr:GetAttribute('Team')
		for _, chest in pairs(Chests or {}) do
			local personal = chest.Parent and (chest.Name == 'personal_chest' or chest.Name == 'og_personal_chest')
			local team = personal and store.getChestTeam(chest)
			if personal and (team == nil or myTeam == nil or team == tostring(myTeam)) then
				local dist = root and (chest.Position - root.Position).Magnitude or 0
				if not bestDist or dist < bestDist then
					best, bestDist = chest, dist
				end
			end
		end
		baseChestCache = best
		return best
	end

	local lastWithdraw = 0
	local function getOwnShop()
		local root = entitylib.isAlive and entitylib.character.RootPart
		if not root then return nil end
		local myTeam = lplr:GetAttribute('Team')
		local best, bestDist
		for _, v in store.shop do
			local keeper = v.RootPart
			if keeper and keeper.Parent and (v.Shop or v.Upgrades) then
				local team = keeper:GetAttribute('TeamId') or store.getChestTeam(keeper)
				if team == nil or myTeam == nil or tostring(team) == tostring(myTeam) then
					local pos = keeper:IsA('BasePart') and keeper.Position or keeper:GetPivot().Position
					local dist = (pos - root.Position).Magnitude
					if not bestDist or dist < bestDist then
						best, bestDist = pos, dist
					end
				end
			end
		end
		return best
	end

	local function withdrawBank()
		if not cachedChest or tick() - lastWithdraw < 0.5 then return end
		lastWithdraw = tick()
		for itemType, toggle in BankToggles do
			if toggle and toggle.Enabled then
				local item = cachedChest:FindFirstChild(itemType)
				if item then
					pcall(function()
						bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(cachedChest, item)
					end)
				end
			end
		end
	end

	local function addItem(itemType, shop)
		local item = Instance.new('ImageLabel')
		item.Image = bedwars.getIcon({itemType = itemType}, true)
		item.Size = UDim2.fromOffset(32, 32)
		item.Name = itemType
		item.BackgroundTransparency = 1
		item.LayoutOrder = #UI:GetChildren()
		item.Parent = UI
		local itemtext = Instance.new('TextLabel')
		itemtext.Name = 'Amount'
		itemtext.Size = UDim2.fromScale(1, 1)
		itemtext.BackgroundTransparency = 1
		itemtext.Text = ''
		itemtext.TextColor3 = Color3.new(1, 1, 1)
		itemtext.TextSize = 16
		itemtext.TextStrokeTransparency = 0.3
		itemtext.Font = Enum.Font.Arial
		itemtext.Parent = item
		Items[itemType] = {Object = itemtext, Type = shop}
	end

	local function refreshBank(echest)
		for i, v in pairs(Items) do
			local item = echest:FindFirstChild(i)
			v.Object.Text = item and item:GetAttribute('Amount') or ''
		end
	end

	local function nearChest(teamOnly)
		if not entitylib.isAlive then return false end

		local pos = entitylib.character.RootPart.Position
		local maxDistanceSq = 22 * 22

		for _, chest in pairs(Chests) do
			if chest.Parent then
				store.getChestTeam(chest)
				local offset = chest.Position - pos
				local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
				if distanceSq < maxDistanceSq and (not teamOnly or store.isMyTeamChest(chest)) then
					return true
				end
			end
		end

		return false
	end

	local function handleState()
		local currentTime = tick()

		if not cachedChest or not cachedChest.Parent or (currentTime - lastChestCheck) > 1 then
			cachedChest = replicatedStorage.Inventories:FindFirstChild(lplr.Name..'_personal')
			lastChestCheck = currentTime
		end

		if not cachedChest then return end

		if not nearChest(TeamCheck and TeamCheck.Enabled) and not GUICheck.Enabled then
			return
		end

		local itemsToDeposit = {}
		for _, v in ipairs(store.inventory.inventory.items) do
			local itemInfo = Items[v.itemType]
			if itemInfo and BankToggles[v.itemType] and BankToggles[v.itemType].Enabled then
				table.insert(itemsToDeposit, v)
			end
		end

		if #itemsToDeposit > 0 then
			for _, v in ipairs(itemsToDeposit) do
				bedwars.Client:GetNamespace('Inventory'):Get('ChestGiveItem'):CallServer(cachedChest, v.tool)
			end
			task.defer(function()
				if cachedChest and cachedChest.Parent then
					refreshBank(cachedChest)
				end
			end)
		end
	end


	AutoBank = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBank',
		Function = function(callback)
			if callback then
				Chests = collection('chest', AutoBank)
				cachedChest = nil
				lastChestCheck = 0
				lastHotbarUpdate = 0
				UI = Instance.new('Frame')
				UI.Size = UDim2.new(1, 0, 0, 44)
				UI.Position = UDim2.fromOffset(0, -256)
				UI.BackgroundTransparency = 1
				UI.Visible = UIToggle.Enabled
				UI.Parent = vape.gui
				AutoBank:Clean(UI)			close.Size = UDim2.fromOffset(16, 16)
			close.Position = UDim2.new(1, -23, 0, 6)
			close.BackgroundColor3 = Color3.new(1, 1, 1)
			close.BackgroundTransparency = 1
			close.Image = getcustomasset('aerov4/assets/new/closemini.png')
			close.ImageColor3 = color.Light(uipallet.Text, 0.2)
			close.ImageTransparency = 0.5
			close.AutoButtonColor = false
			close.Parent = hotbar
			local closecorner = Instance.new('UICorner')
			closecorner.CornerRadius = UDim.new(1, 0)
			closecorner.Parent = close
			close.MouseEnter:Connect(function()
				close.ImageTransparency = 0.3
				tween:Tween(close, TweenInfo.new(0.2), {
					BackgroundTransparency = 0.6
				})
			end)
			close.MouseLeave:Connect(function()
				close.ImageTransparency = 0.5
				tween:Tween(close, TweenInfo.new(0.2), {
					BackgroundTransparency = 1
				})
			end)
			close.MouseButton1Click:Connect(function()
				local ind = table.find(self.Hotbars, hotbardata)
				local obj = self.Hotbars[self.Selected]
				local obj2 = self.Hotbars[ind]
				if obj and obj2 then
					obj2.Object:ClearAllChildren()
					obj2.Object:Destroy()
					table.remove(self.Hotbars, ind)
					ind = table.find(self.Hotbars, obj)
					self.Selected = table.find(self.Hotbars, obj) or 1
				end
			end)
		end
	
		api.Options.HotbarList = optionapi
	
		return optionapi
	end
	
	local function getBlock()
		local clone = table.clone(store.inventory.inventory.items)
		table.sort(clone, function(a, b)
			return a.amount < b.amount
		end)
	
		for _, item in clone do
			local block = bedwars.ItemMeta[item.itemType].block
			if block and not block.seeThrough then
				return item
			end
		end
	end
	
	local function getCustomItem(v)
		if v == 'diamond_sword' then
			local sword = store.tools.sword
			v = sword and sword.itemType or 'wood_sword'
		elseif v == 'diamond_pickaxe' then
			local pickaxe = store.tools.stone
			v = pickaxe and pickaxe.itemType or 'wood_pickaxe'
		elseif v == 'diamond_axe' then
			local axe = store.tools.wood
			v = axe and axe.itemType or 'wood_axe'
		elseif v == 'wood_bow' then
			local bow = getBow()
			v = bow and bow.itemType or 'wood_bow'
		elseif v == 'wool_white' then
			local block = getBlock()
			v = block and block.itemType or 'wool_white'
		end
	
		return v
	end
	
	local function findItemInTable(tab, item)
		for slot, v in tab do
			if item.itemType == getCustomItem(v) then
				return tonumber(slot)
			end
		end
	end
	
	local function findInHotbar(item)
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType == item.itemType then
				return i - 1, v.item
			end
		end
	end
	
	local function findInInventory(item)
		for _, v in store.inventory.inventory.items do
			if v.itemType == item.itemType then
				return v
			end
		end
	end
	
	local function dispatch(...)
		bedwars.Store:dispatch(...)
		vapeEvents.InventoryChanged.Event:Wait()
	end
	
	local function sortCallback()
		if Active then return end
		Active = true
		local items = (List.Hotbars[List.Selected] and List.Hotbars[List.Selected].Hotbar or {})
	
		for _, v in store.inventory.inventory.items do
			local slot = findItemInTable(items, v)
			if slot then
				local olditem = store.inventory.hotbar[slot]
				if olditem.item and olditem.item.itemType == v.itemType then continue end
				if olditem.item then
					dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = slot - 1
					})
				end
	
				local newslot = findInHotbar(v)
				if newslot then
					dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = newslot
					})
					if olditem.item then
						dispatch({
							type = 'InventoryAddToHotbar',
							item = findInInventory(olditem.item),
							slot = newslot
						})
					end
				end
	
				dispatch({
					type = 'InventoryAddToHotbar',
					item = findInInventory(v),
					slot = slot - 1
				})
			elseif Clear.Enabled then
				local newslot = findInHotbar(v)
				if newslot then
				   	dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = newslot
					})
				end
			end
		end
	
		Active = false
	end
	
	AutoHotbar = vape.Categories.Inventory:CreateModule({
		Name = 'AutoHotbar',
		Function = function(callback)
			if callback then
				task.spawn(sortCallback)
				if Mode.Value == 'On Key' then
					AutoHotbar:Toggle()
					return
				end
	
				AutoHotbar:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(sortCallback))
			end
		end,
		Tooltip = 'arranges your hotbar based off what u want'
	})
	Mode = AutoHotbar:CreateDropdown({
		Name = 'Activation',
		List = {'Toggle', 'On Key'},
		Function = function()
			if AutoHotbar.Enabled then
				AutoHotbar:Toggle()
				AutoHotbar:Toggle()
			end
		end
	})
	Clear = AutoHotbar:CreateToggle({Name = 'Clear Hotbar'})
	List = AutoHotbar:CreateHotbarList({})
end)

--[[
	Minigames Modules
]]

run(function()
    local BedPlates
    local Background
    local TeamColor
    local Color = {}
    local Reference = {}
    local BlockCache = {}
	local LayerCounter
	local LayerColor
	local UIStyle
	local PositionDropdown
	local IgnoreTeam
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local compactUI = Instance.new('ScreenGui')
    compactUI.Name = 'BedPlatesCompactUI'
    compactUI.Parent = vape.gui
    compactUI.Enabled = false
    compactUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    compactUI.DisplayOrder = 10
    compactUI.ResetOnSpawn = false
    local compactMainFrame = Instance.new('Frame')
    compactMainFrame.Name = 'MainFrame'
    compactMainFrame.Parent = compactUI
    compactMainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    compactMainFrame.BackgroundTransparency = 0.3
    compactMainFrame.BorderSizePixel = 0
    compactMainFrame.Position = UDim2.new(1, -8, 1, -8)
    compactMainFrame.Size = UDim2.new(0, 150, 0, 0)
    compactMainFrame.AutomaticSize = Enum.AutomaticSize.Y
    compactMainFrame.AnchorPoint = Vector2.new(1, 1)
    local compactCorner = Instance.new('UICorner')
    compactCorner.CornerRadius = UDim.new(0, 8)
    compactCorner.Parent = compactMainFrame
    local compactListLayout = Instance.new('UIListLayout')
    compactListLayout.Padding = UDim.new(0, 4)
    compactListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    compactListLayout.Parent = compactMainFrame
    local compactPadding = Instance.new('UIPadding')
    compactPadding.PaddingTop = UDim.new(0, 6)
    compactPadding.PaddingBottom = UDim.new(0, 6)
    compactPadding.PaddingLeft = UDim.new(0, 6)
    compactPadding.PaddingRight = UDim.new(0, 6)
    compactPadding.Parent = compactMainFrame
    
	local teamColors = getgenv().aeroTeamColors
    
    local function getBedTeamColor(bed)
        local teamId = bed:GetAttribute('TeamID') or bed:GetAttribute('Team') or bed:GetAttribute('TeamId')
        teamId = tonumber(teamId)
        if teamId and teamColors[teamId] then
            return teamColors[teamId]
        end
        return {name = 'Enemy', color = Color3.new(1, 1, 1)}
    end
    
    local function isMyBed(bed)
        local myTeam = lplr.Character and (lplr.Character:GetAttribute('Team') or lplr.Character:GetAttribute('TeamId'))
        local bedTeam = bed:GetAttribute('TeamID') or bed:GetAttribute('Team') or bed:GetAttribute('TeamId')
        if not myTeam or not bedTeam then return false end
        return tonumber(myTeam) == tonumber(bedTeam)
    end
    
	local function updateLayerTextColor()
		local textColor = LayerColor and Color3.fromHSV(LayerColor.Hue, LayerColor.Sat, LayerColor.Value) or Color3.fromRGB(250, 250, 250)
		for _, ref in pairs(Reference) do
			for _, holder in {ref.billboard.Frame, ref.compactRow and ref.compactRow.iconsFrame} do
				for _, img in holder:GetChildren() do
					if img:IsA('ImageLabel') then
						local txt = img:FindFirstChild('Amount')
						if txt then
							txt.TextColor3 = textColor
						end
					end
				end
			end
		end
	end

	local layerDirs = {
		Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
		Vector3.new(0, 1, 0),
	}

	local function getBedCells(bed)
		local ok, cells = pcall(function()
			local handler = bedwars.BlockController:getHandlerRegistry():getHandler(bed.Name)
			return handler and handler:getContainedPositions(bed)
		end)
		if ok and type(cells) == 'table' and #cells > 0 then
			return cells
		end
		local start = bedwars.BlockController:getBlockPosition(bed.Position)
		return {start, start + Vector3.new(0, 0, 1)}
	end
    
	local cellParams = OverlapParams.new()
	cellParams.FilterType = Enum.RaycastFilterType.Include
	local cellSize = Vector3.new(1, 1, 1)

	local function getBedLayers(bed)
		local store = bedwars.BlockController:getStore()
		local world = getWorldFolder()
		local blocksFolder = world and world:FindFirstChild('Blocks')
		if blocksFolder then
			cellParams.FilterDescendantsInstances = {blocksFolder}
		end
		local function blockAt(n)
			if not blocksFolder then
				return store:getBlockAt(n)
			end
			for _, part in workspace:GetPartBoundsInBox(CFrame.new(n * 3), cellSize, cellParams) do
				local inst = part
				while inst.Parent and inst.Parent ~= blocksFolder do
					inst = inst.Parent
				end
				if inst.Parent == blocksFolder then
					return inst
				end
			end
			return nil
		end

		local seen, frontier = {}, {}
		for _, cell in getBedCells(bed) do
			seen[cell] = true
			table.insert(frontier, cell)
		end

		local entries, byBlock = {}, {}
		local fraction
		for ring = 1, 8 do
			local nextFrontier, total, filled, counts = {}, 0, 0, {}
			for _, cell in frontier do
				for _, dir in layerDirs do
					local n = cell + dir
					if not seen[n] then
						seen[n] = true
						table.insert(nextFrontier, n)
						total += 1
						local blk = blockAt(n)
						if blk and blk.Name ~= 'bed' and not blk:GetAttribute('NoBreak') then
							filled += 1
							counts[blk.Name] = (counts[blk.Name] or 0) + 1
						end
					end
				end
			end
			frontier = nextFrontier

			local main, mainCount = nil, 0
			for name, count in counts do
				if count > mainCount or (count == mainCount and main and name < main) then
					main, mainCount = name, count
				end
			end

			if ring == 1 then
				if not main then break end
				if filled < total then
					fraction = {block = main, text = filled..'/'..total}
					continue
				end
			elseif filled < total * 0.5 then
				break
			end

			local entry = byBlock[main]
			if entry then
				entry.amt += 1
			else
				entry = {block = main, amt = 1}
				byBlock[main] = entry
				table.insert(entries, entry)
			end
		end

		if fraction then
			table.insert(entries, 1, fraction)
		end
		return entries, #entries
	end

	local function renderLayers(frame, entries)
		for _, obj in frame:GetChildren() do
			if obj and ((obj:IsA('ImageLabel') and obj.Name ~= 'Blur') or obj.Name == 'Fraction') then
				obj:Destroy()
			end
		end
		for i, e in entries do
			local image = Instance.new('ImageLabel')
			image.LayoutOrder = i
			image.Size = UDim2.fromOffset(32, 32)
			image.BackgroundTransparency = 1
			image.Image = bedwars.getIcon({itemType = e.block}, true)
			image.Parent = frame
			local label = e.text or (e.amt and e.amt >= 2 and (not LayerCounter or LayerCounter.Enabled) and tostring(e.amt)) or nil
			if label then
				local txt = Instance.new('TextLabel')
				txt.Name = 'Amount'
				txt.Size = UDim2.fromScale(1, 1)
				txt.BackgroundTransparency = 1
				txt.Text = label
				txt.TextColor3 = LayerColor and Color3.fromHSV(LayerColor.Hue, LayerColor.Sat, LayerColor.Value) or Color3.fromRGB(250, 250, 250)
				txt.TextSize = e.text and 16 or 24
				txt.TextStrokeTransparency = 0.3
				txt.Font = e.text and Enum.Font.GothamBold or Enum.Font.Arial
				txt.Parent = image
			end
		end
	end

	local function refreshAdornee(v)
		local bed = v.Adornee
		local entries, layers = getBedLayers(bed)
		local sig = (LayerCounter and LayerCounter.Enabled) and '1' or '0'
		for _, e in entries do
			sig ..= e.block..(e.amt or '')..(e.text or '')..','
		end
		local changed = BlockCache[bed] ~= sig
		BlockCache[bed] = sig
		local mine = isMyBed(bed)
		local hasPlates = #entries > 0
		v.Enabled = hasPlates and UIStyle.Value == 'Original' and not mine
		if changed then
			renderLayers(v.Frame, entries)
		end
		if Reference[bed] and Reference[bed].compactRow then
			if changed then
				renderLayers(Reference[bed].compactRow.iconsFrame, entries)
			end
			Reference[bed].compactRow.countLabel.Text = tostring(layers)
			Reference[bed].compactRow.frame.Visible = hasPlates and not (mine and IgnoreTeam and IgnoreTeam.Enabled)
		end
	end
    
    local function Added(v)
        if Reference[v] then return end
        local _bpUserId = v:GetAttribute('PlacedByUserId')
        if _bpUserId then
            local _bpOk, _bpOwner = pcall(function() return playersService:GetPlayerByUserId(_bpUserId) end)
        end
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = 'bed'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
        billboard.Size = UDim2.fromOffset(36, TeamColor.Enabled and 50 or 36)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = v
        billboard.Enabled = UIStyle.Value == 'Original'
        
        local blur = addBlur(billboard)
        blur.Visible = Background.Enabled
        
        local frame = Instance.new('Frame')
        frame.Size = TeamColor.Enabled and UDim2.new(1, 0, 1, -16) or UDim2.fromScale(1, 1)
        frame.Position = TeamColor.Enabled and UDim2.new(0, 0, 0, 16) or UDim2.new(0, 0, 0, 0)
        frame.BackgroundColor3 = TeamColor.Enabled and getBedTeamColor(v).color or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
        frame.BackgroundTransparency = 1 - (Background.Enabled and (TeamColor.Enabled and 0.5 or Color.Opacity) or 0)
        frame.Parent = billboard

        local teamLabel = Instance.new('TextLabel')
        teamLabel.Name = 'TeamLabel'
        teamLabel.Size = UDim2.new(1, 0, 0, 14)
        teamLabel.Position = UDim2.new(0, 0, 0, 0)
        teamLabel.BackgroundTransparency = 1
        teamLabel.Text = getBedTeamColor(v).name
        teamLabel.TextColor3 = getBedTeamColor(v).color
        teamLabel.TextSize = 13
        teamLabel.Font = Enum.Font.GothamBold
        teamLabel.TextStrokeTransparency = 0.4
        teamLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        teamLabel.Visible = TeamColor.Enabled
        teamLabel.Parent = billboard
        
        local layout = Instance.new('UIListLayout')
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.Padding = UDim.new(0, 4)
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), TeamColor.Enabled and 50 or 36)
        end)
        layout.Parent = frame
        
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = frame

        local rowFrame = Instance.new('Frame')
        rowFrame.BackgroundTransparency = 1
        rowFrame.Size = UDim2.new(1, 0, 0, 50)
        rowFrame.AutomaticSize = Enum.AutomaticSize.Y
        rowFrame.LayoutOrder = #compactMainFrame:GetChildren()
        rowFrame.Visible = false
        rowFrame.Parent = compactMainFrame

        local rowTeamLabel = Instance.new('TextLabel')
        rowTeamLabel.Size = UDim2.new(1, 0, 0, 14)
        rowTeamLabel.BackgroundTransparency = 1
        rowTeamLabel.Text = getBedTeamColor(v).name
        rowTeamLabel.TextColor3 = getBedTeamColor(v).color
        rowTeamLabel.TextSize = 13
        rowTeamLabel.Font = Enum.Font.GothamBold
        rowTeamLabel.TextStrokeTransparency = 0.4
        rowTeamLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        rowTeamLabel.Parent = rowFrame

        local rowBG = Instance.new('Frame')
        rowBG.Position = UDim2.new(0, 0, 0, 16)
        rowBG.Size = UDim2.new(1, 0, 0, 34)
        rowBG.AutomaticSize = Enum.AutomaticSize.Y
        rowBG.BackgroundColor3 = Color3.new(0, 0, 0)
        rowBG.BackgroundTransparency = 0.3
        rowBG.Parent = rowFrame

        local rowCorner = Instance.new('UICorner')
        rowCorner.CornerRadius = UDim.new(0, 4)
        rowCorner.Parent = rowBG

        local rowIcons = Instance.new('Frame')
        rowIcons.BackgroundTransparency = 1
        rowIcons.Size = UDim2.new(1, -30, 0, 34)
        rowIcons.AutomaticSize = Enum.AutomaticSize.Y
        rowIcons.Parent = rowBG

        local rowIconLayout = Instance.new('UIListLayout')
        rowIconLayout.FillDirection = Enum.FillDirection.Horizontal
        rowIconLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rowIconLayout.Padding = UDim.new(0, 2)
        rowIconLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        rowIconLayout.Wraps = true
        rowIconLayout.Parent = rowIcons

        local rowCount = Instance.new('TextLabel')
        rowCount.Size = UDim2.new(0, 28, 1, 0)
        rowCount.Position = UDim2.new(1, -28, 0, 0)
        rowCount.BackgroundTransparency = 1
        rowCount.Text = "0"
        rowCount.TextColor3 = Color3.fromRGB(255, 255, 255)
        rowCount.TextSize = 14
        rowCount.Font = Enum.Font.GothamBold
        rowCount.Parent = rowBG

        Reference[v] = {
            billboard = billboard,
            compactRow = {
                frame = rowFrame,
                iconsFrame = rowIcons,
                countLabel = rowCount
            }
        }
        BlockCache[v] = ""
        refreshAdornee(billboard)
    end
    
	local pendingBeds = {}
	local _refreshNearPending = false
	local function refreshNear(data)
		local blockPos = data and data.blockRef and data.blockRef.blockPosition
		if not blockPos then return end
		blockPos *= 3
		for bed in pairs(Reference) do
			if bed.Parent and (blockPos - bed.Position).Magnitude <= 30 then
				pendingBeds[bed] = true
			end
		end
		if _refreshNearPending or not next(pendingBeds) then return end
		_refreshNearPending = true
		task.delay(0.1, function()
			_refreshNearPending = false
			local done = {}
			for bed in pairs(pendingBeds) do
				pendingBeds[bed] = nil
				local ref = Reference[bed]
				if ref and bed.Parent then
					refreshAdornee(ref.billboard)
					table.insert(done, bed)
				end
			end
			task.delay(0.5, function()
				for _, bed in done do
					local ref = Reference[bed]
					if ref and bed.Parent then
						refreshAdornee(ref.billboard)
					end
				end
			end)
		end)
	end

    local currentCorner = 'Bottom Right'

    local function updateCompactPosition()
        local genUI = vape.gui:FindFirstChild('GeneratorCompactUI')
        local offset = 8
        if genUI and genUI.Enabled and currentCorner == 'Bottom Right' then
            offset = offset + 128
        end
        local invHost = (gethui and gethui()) or game:GetService('CoreGui')
        if invHost:FindFirstChild('InventoryESP') and (currentCorner == 'Bottom Right' or currentCorner == 'Top Right') then
            offset = offset + 200
        end
        if currentCorner == 'Top Right' then
            compactMainFrame.AnchorPoint = Vector2.new(1, 0)
            compactMainFrame.Position = UDim2.new(1, -offset, 0, 8)
        elseif currentCorner == 'Top Left' then
            compactMainFrame.AnchorPoint = Vector2.new(0, 0)
            compactMainFrame.Position = UDim2.new(0, 8, 0, 8)
        elseif currentCorner == 'Bottom Left' then
            compactMainFrame.AnchorPoint = Vector2.new(0, 1)
            compactMainFrame.Position = UDim2.new(0, 8, 1, -8)
        else
            compactMainFrame.AnchorPoint = Vector2.new(1, 1)
            compactMainFrame.Position = UDim2.new(1, -offset, 1, -8)
        end
    end
    
    BedPlates = vape.Categories.Minigames:CreateModule({
        Name = 'BedPlates',
        Function = function(callback)
            if callback then
                table.clear(BlockCache)
                compactUI.Enabled = UIStyle.Value == 'Compact'
                
                local tagged = collectionService:GetTagged('bed')
                for _, v in ipairs(tagged) do 
                    Added(v)
                end
                
                BedPlates:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(refreshNear))
                BedPlates:Clean(vapeEvents.BreakBlockEvent.Event:Connect(refreshNear))
                BedPlates:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(Added))

                local worldFolder = getWorldFolder()
                local blocksFolder = worldFolder and worldFolder:FindFirstChild('Blocks')
                if blocksFolder then
                    local function onBlockChange(obj)
                        if not (obj:IsA('BasePart')) then return end
                        refreshNear({blockRef = {blockPosition = obj.Position / 3}})
                    end
                    BedPlates:Clean(blocksFolder.ChildAdded:Connect(onBlockChange))
                    BedPlates:Clean(blocksFolder.ChildRemoved:Connect(onBlockChange))
                end
                BedPlates:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(v)
                    if Reference[v] then
                        Reference[v].billboard:Destroy()
                        Reference[v].compactRow.frame:Destroy()
                        Reference[v] = nil
                        BlockCache[v] = nil
                    end
                end))
				local lastCompact = 0
				BedPlates:Clean(runService.Heartbeat:Connect(function()
					if compactUI.Enabled and tick() - lastCompact > 0.5 then
						lastCompact = tick()
						updateCompactPosition()
					end
				end))
            else
                for _, v in pairs(Reference) do
                    v.billboard:Destroy()
                    v.compactRow.frame:Destroy()
                end
                table.clear(Reference)
                table.clear(BlockCache)
                compactUI.Enabled = false
            end
        end,
        Tooltip = 'shows enemys bed defence'
    })

    UIStyle = BedPlates:CreateDropdown({
        Name = 'UI Style',
        List = {'Original', 'Compact'},
        Default = 'Original',
        Function = function(val)
            local isOriginal = val == 'Original'
            compactUI.Enabled = BedPlates.Enabled and not isOriginal
            for bed, ref in pairs(Reference) do
                ref.billboard.Enabled = isOriginal
                refreshAdornee(ref.billboard)
            end
            if PositionDropdown.Object then
                PositionDropdown.Object.Visible = not isOriginal
            end
            if IgnoreTeam and IgnoreTeam.Object then
                IgnoreTeam.Object.Visible = not isOriginal
            end
        end,
        Tooltip = 'pick between the floating world esp or a corner panel'
    })

    PositionDropdown = BedPlates:CreateDropdown({
        Name = 'Position',
        List = {'Top Right', 'Top Left', 'Bottom Left', 'Bottom Right'},
        Default = 'Bottom Right',
        Function = function(val)
            currentCorner = val
            updateCompactPosition()
        end,
        Tooltip = 'pick w corner u want the panel chillin in'
    })

    task.defer(function()
        if PositionDropdown and PositionDropdown.Object then
            PositionDropdown.Object.Visible = (UIStyle.Value == 'Compact')
        end
        if IgnoreTeam and IgnoreTeam.Object then
            IgnoreTeam.Object.Visible = (UIStyle.Value == 'Compact')
        end
    end)
    
    IgnoreTeam = BedPlates:CreateToggle({
        Name = 'Ignore Team',
        Default = false,
        Function = function(callback)
            for bed, ref in pairs(Reference) do
                refreshAdornee(ref.billboard)
            end
        end,
        Tooltip = 'wont show ur own team bed on the compact panel'
    })
    
    Background = BedPlates:CreateToggle({
        Name = 'Background',
        Function = function(callback)
            if Color.Object then 
                Color.Object.Visible = callback and not TeamColor.Enabled
            end
            for _, v in pairs(Reference) do
                v.billboard.Frame.BackgroundTransparency = 1 - (callback and (TeamColor.Enabled and 0.5 or Color.Opacity) or 0)
                local blur = v.billboard:FindFirstChild('Blur')
                if blur then
                    blur.Visible = callback
                end
            end
        end,
        Default = true
    })

    Color = BedPlates:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for bed, v in pairs(Reference) do
                if not TeamColor.Enabled then
                    v.billboard.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                end
                if Background.Enabled and not TeamColor.Enabled then
                    v.billboard.Frame.BackgroundTransparency = 1 - opacity
                end
            end
        end,
        Visible = false,
        Darker = true
    })
    
    TeamColor = BedPlates:CreateToggle({
        Name = 'Team Color',
        Default = true,
        Function = function(callback)
            if Color.Object then
                Color.Object.Visible = Background.Enabled and not callback
            end
            for bed, ref in pairs(Reference) do
                ref.billboard.Frame.BackgroundColor3 = callback and getBedTeamColor(bed).color or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                ref.billboard.Frame.BackgroundTransparency = 1 - (Background.Enabled and (callback and 0.5 or Color.Opacity) or 0)
            end
        end
    })

	LayerCounter = BedPlates:CreateToggle({
		Name = 'Layer Counter',
		Function = function(callback)
			if LayerColor and LayerColor.Object then
				LayerColor.Object.Visible = callback
			end
			for _, ref in pairs(Reference) do
				refreshAdornee(ref.billboard)
			end
		end,
		Default = true
	})
	LayerColor = BedPlates:CreateColorSlider({
		Name = 'Counter Text Color',
		DefaultSat = 1,
		DefaultValue = 1,
		Function = function()
			updateLayerTextColor()
		end,
		Visible = LayerCounter.Enabled
	})	
end)
run(function()
	local AutoHonor
	local Delay
	local honoredusers = {}
	local maxhonors = 2
	
	local function getTeammates()
		local teammates = {}
		local nonteammates = {}
		local myTeam = lplr.Team
		
		for i, plr in playersService:GetPlayers() do
			if plr ~= lplr then
				if plr.Team == myTeam then
					table.insert(teammates, plr)
				else
					table.insert(nonteammates, plr)
				end
			end
		end
		return teammates, nonteammates
	end
	
	local function honorPlayers()
		if #honoredusers >= maxhonors then return end
		
		local teammates, nonteammates = getTeammates()
		
		if #teammates > 0 and #honoredusers < maxhonors then
			local randomTeammate = teammates[math.random(1, #teammates)]
			if not honoredusers[randomTeammate.UserId] then
				task.wait(Delay.Value)
				bedwars.HonorController:honorPlayer(randomTeammate.UserId)
				honoredusers[randomTeammate.UserId] = true
			end
		end
		
		if #nonteammates > 0 and #honoredusers < maxhonors then
			local randomEnemy = nonteammates[math.random(1, #nonteammates)]
			if not honoredusers[randomEnemy.UserId] then
				task.wait(Delay.Value)
				bedwars.HonorController:honorPlayer(randomEnemy.UserId)
				honoredusers[randomEnemy.UserId] = true
			end
		end
	end
	
	AutoHonor = vape.Categories.Minigames:CreateModule({
		Name = "AutoHonor",
		Function = function(callback)
			if callback then
				AutoHonor:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
						honorPlayers()
					end
				end))
				AutoHonor:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(...)
					honorPlayers()
				end))
			else
				table.clear(honoredusers)
			end
		end
	})
	Delay = AutoHonor:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Default = 0.05
	})
end)

run(function()
	local Nuker
	local TargetMode
	local BreakType
	local Mode
	local Range
	local BreakSpeed
	local UpdateRate
	local Bed
	local BedCheck
	local LuckyBlock
	local IronOre
	local Tesla
	local Hive
	local Pinata
	local Crops
	local Snow
	local Effect
	local CustomHealth = {}
	local Animation
	local SelfBreak
	local LimitItem
	local AutoTool
	local MouseDown
	local YetiBreaker
	local RagnarBreaker
	local ShowPath
	local BlockHighlight
	local BreakerHighlightColor
	local BreakerAngle
	local FACES = {Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0), Vector3.new(0, 3, 0), Vector3.new(0, -3, 0), Vector3.new(0, 0, 3), Vector3.new(0, 0, -3)}
	local parts = {}
	local highlightBox
	local plan
	local lastHit = 0
	local lastYetiUse = 0
	local breakableCache = setmetatable({}, {__mode = 'k'})
	local hbMounted, hbPart, hbRef, hbBlock, hbMax, hbLast, hbPercent = nil, nil, nil, nil, 1, 0, -1

	local function cleanupHealthbar()
		if hbMounted then
			pcall(bedwars.Roact.unmount, hbMounted)
			hbMounted = nil
		end
		if hbPart then
			pcall(function() hbPart:Destroy() end)
			hbPart = nil
		end
		hbRef, hbBlock, hbPercent = nil, nil, -1
	end

	local function setHealthbarPercent(percent)
		percent = math.clamp(percent, 0, 1)
		if math.abs(percent - hbPercent) < 0.001 then return end
		hbPercent = percent
		local bar = hbRef and hbRef:getValue()
		if bar then
			tweenService:Create(bar, TweenInfo.new(0.15), {
				Size = UDim2.fromScale(percent, 1),
				BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
			}):Play()
		end
		if percent <= 0 then
			local mine = hbBlock
			task.delay(0.25, function()
				if hbBlock == mine then
					cleanupHealthbar()
				end
			end)
		end
	end

	local function customHealthbar(_, blockRef, health, maxHealth, changeHealth, block)
		if not Nuker or not Nuker.Enabled or not block then return end
		health = math.max((tonumber(health) or 0) - (tonumber(changeHealth) or 0), 0)
		maxHealth = math.max(tonumber(block:GetAttribute('MaxHealth') or maxHealth) or 1, 1)
		if hbBlock ~= block then
			cleanupHealthbar()
			hbBlock = block
			local create = bedwars.Roact.createElement
			local percent = math.clamp((health + (tonumber(changeHealth) or 0)) / maxHealth, 0, 1)
			local name = (bedwars.ItemMeta[block.Name] and bedwars.ItemMeta[block.Name].displayName) or block.Name
			hbRef = bedwars.Roact.createRef()
			local part = Instance.new('Part')
			part.Name = 'AeroNukerHB'
			part.Size = Vector3.one
			part.CFrame = CFrame.new(bedwars.BlockController:getWorldPosition(blockRef.blockPosition))
			part.Transparency = 1
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.Parent = workspace
			hbPart = part
			pcall(function() bedwars.QueryUtil:setQueryIgnored(part, true) end)
			hbMounted = bedwars.Roact.mount(create('BillboardGui', {
				Size = UDim2.fromOffset(249, 102),
				StudsOffset = Vector3.new(0, 2.5, 0),
				Adornee = part,
				MaxDistance = 40,
				AlwaysOnTop = true
			}, {
				create('Frame', {
					Size = UDim2.fromOffset(160, 50),
					Position = UDim2.fromOffset(44, 32),
					BackgroundColor3 = Color3.new(),
					BackgroundTransparency = 0.5
				}, {
					create('UICorner', {CornerRadius = UDim.new(0, 5)}),
					create('ImageLabel', {
						Size = UDim2.new(1, 89, 1, 52),
						Position = UDim2.fromOffset(-48, -31),
						BackgroundTransparency = 1,
						Image = getcustomasset('aerov4/assets/new/blur.png'),
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(52, 31, 261, 502)
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(13, 12),
						BackgroundTransparency = 1,
						Text = name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = Color3.new(),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(12, 11),
						BackgroundTransparency = 1,
						Text = name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = color.Dark(uipallet.Text, 0.16),
						TextScaled = true,		Delete = function(_, _, char, _)
			char:Destroy()
		end
	}
	
	KillEffect = vape.Categories.Legit:CreateModule({
		Name = 'KillEffect',
		Function = function(callback)
			if callback then
				for i, v in killeffects do
					bedwars.KillEffectController.killEffects['Custom'..i] = {
						new = function()
							return {
								onKill = v,
								isPlayDefaultKillEffect = function()
									return false
								end
							}
						end
					}
				end
				KillEffect:Clean(lplr:GetAttributeChangedSignal('KillEffectType'):Connect(function()
					lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
				end))
				lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
			else
				for i in killeffects do
					bedwars.KillEffectController.killEffects['Custom'..i] = nil
				end
				lplr:SetAttribute('KillEffectType', 'default')
			end
		end,
		Tooltip = 'Custom final kill effects'
	})
	local modes = {'Bedwars'}
	for i in killeffects do
		table.insert(modes, i)
	end
	Mode = KillEffect:CreateDropdown({
		Name = 'Mode',
		List = modes,
		Function = function(val)
			List.Object.Visible = val == 'Bedwars'
			if KillEffect.Enabled then
				lplr:SetAttribute('KillEffectType', val == 'Bedwars' and NameToId[List.Value] or 'Custom'..val)
			end
		end
	})
	local KillEffectName = {}
	for i, v in bedwars.KillEffectMeta do
		table.insert(KillEffectName, v.name)
		NameToId[v.name] = i
	end
	table.sort(KillEffectName)
    List = KillEffect:CreateDropdown({
        Name = 'Bedwars',
        List = KillEffectName,
        Function = function(val)
            if KillEffect.Enabled then
                lplr:SetAttribute('KillEffectType', NameToId[val])
            end
        end,
        Darker = true
    })

    task.defer(function()
        if List and List.Object then
            List.Object.Visible = (Mode.Value == 'Bedwars')
        end
    end)
end)
	
run(function()
    local WinEffect
    local List
    local NameToId = {}
    
    WinEffect = vape.Categories.Legit:CreateModule({
        Name = "WinEffect",
        Function = function(callback)
            if callback then
                WinEffect:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
                    local remote = bedwars.Client:Get(remotes.WinEffectTriggered).instance
                    local payload = {
                        winEffectType = NameToId[List.Value],
                        winningPlayer = lplr
                    }
                    local ok = pcall(function()
                        remote.OnClientEvent:Fire(payload)
                    end)
                    if not ok then
                        for _, v in getconnections(remote.OnClientEvent) do
                            local fn = v.Function or v.Callback or v[1]
                            if fn then pcall(fn, payload) end
                        end
                    end
                end))
            end
        end,
        Tooltip = "select any clientside win effect"
    })
    
    local WinEffectName = {}
    for i, v in bedwars.WinEffectMeta do
        table.insert(WinEffectName, v.name)
        NameToId[v.name] = i
    end
    table.sort(WinEffectName)
    
    List = WinEffect:CreateDropdown({
        Name = "Effects",
        List = WinEffectName
    })
end)

run(function()
	local DamageIndicator
	local FontOption
	local Color
	local Size
	local Anchor
	local Stroke

	local fn = bedwars.DamageIndicator

	local suc, tab = pcall(function()
		return debug.getupvalue(fn, 2)
	end)
	tab = suc and tab or {}

	local fontIndices = {}
	local strokeIndex
	do
		local ok, consts = pcall(debug.getconstants, fn)
		if ok and consts then
			for i, v in consts do
				if typeof(v) == 'EnumItem' and v.EnumType == Enum.Font then
					table.insert(fontIndices, i)
				elseif v == 'Thickness' or v == 'Enabled' then
					strokeIndex = i
				end
			end
		end
	end
	if #fontIndices == 0 then fontIndices = {86} end
	if not strokeIndex then strokeIndex = 119 end

	local oldvalues = {}
	local oldfonts = {}

	local function applyFont(fontName)
		local font = Enum.Font[fontName]
		if not font then return end
		for _, i in fontIndices do
			pcall(debug.setconstant, fn, i, font)
		end
	end

	local function applyStroke(on)
		pcall(debug.setconstant, fn, strokeIndex, on and 'Thickness' or 'Enabled')
		tab.strokeThickness = on and 1 or false
	end
	
	DamageIndicator = vape.Categories.Legit:CreateModule({
		Name = 'DamageIndicator',
		Function = function(callback)
			if callback then
				oldvalues = table.clone(tab)
				oldfonts = {}
				for _, i in fontIndices do
					oldfonts[i] = debug.getconstant(fn, i)
				end
				applyFont(FontOption.Value)
				applyStroke(Stroke.Enabled)
				tab.textSize = Size.Value
				tab.blowUpSize = Size.Value
				tab.blowUpDuration = 0
				tab.baseColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				tab.blowUpCompleteDuration = 0
				tab.anchoredDuration = Anchor.Value
			else
				for i, v in oldvalues do
					tab[i] = v
				end
				for i, v in oldfonts do
					pcall(debug.setconstant, fn, i, v)
				end
				pcall(debug.setconstant, fn, strokeIndex, 'Thickness')
			end
		end,
		Tooltip = 'customize the damage indicator'
	})
	local fontitems = {'GothamBlack'}
	for _, v in Enum.Font:GetEnumItems() do
		if v.Name ~= 'GothamBlack' then
			table.insert(fontitems, v.Name)
		end
	end
	FontOption = DamageIndicator:CreateDropdown({
		Name = 'Font',
		List = fontitems,
		Function = function(val)
			if DamageIndicator.Enabled then
				applyFont(val)
			end
		end
	})
	Color = DamageIndicator:CreateColorSlider({
		Name = 'Color',
		DefaultHue = 0,
		Function = function(hue, sat, val)
			if DamageIndicator.Enabled then
				tab.baseColor = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	Size = DamageIndicator:CreateSlider({
		Name = 'Size',
		Min = 1,
		Max = 32,
		Default = 32,
		Function = function(val)
			if DamageIndicator.Enabled then
				tab.textSize = val
				tab.blowUpSize = val
			end
		end
	})
	Anchor = DamageIndicator:CreateSlider({
		Name = 'Anchor',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Function = function(val)
			if DamageIndicator.Enabled then
				tab.anchoredDuration = val
			end
		end
	})
	Stroke = DamageIndicator:CreateToggle({
		Name = 'Stroke',
		Function = function(callback)
			if DamageIndicator.Enabled then
				applyStroke(callback)
			end
		end
	})
end)

run(function()
    local DisableStreamer
    local old = {}
    local oldLevels = {}
    local oldUsernames = {}
    local levelMap = {}
    local updaterThread = nil

    DisableStreamer = vape.Categories.Legit:CreateModule({
        Name = 'DisableStreamer',
        Function = function(callback)
            if callback then
                for _, plrs in playersService:GetPlayers() do
                    if plrs == lplr then continue end
                    
                    local disguiseName = plrs:GetAttribute("DisguiseDisplayName")
                    if disguiseName and disguiseName ~= "" then
                        old[plrs] = disguiseName
                        plrs:SetAttribute("DisguiseDisplayName", "")
                    end

                    local disguiseUsername = plrs:GetAttribute("DisguiseUsername")
                    if disguiseUsername and disguiseUsername ~= "" then
                        oldUsernames[plrs] = disguiseUsername
                        plrs:SetAttribute("DisguiseUsername", "")
                    end

                    local playerLevel = plrs:GetAttribute("PlayerLevel")
                    if playerLevel then
                        oldLevels[plrs] = playerLevel
                        levelMap[plrs.Name] = playerLevel
                    end
                end

                pcall(function()
                    bedwars.StreamerModeController:updateNametags(true)
                end)

                local running = true
                updaterThread = task.spawn(function()
                    while running do
                        local tabList = lplr.PlayerGui:FindFirstChild("TabListScreenGui")
                        if tabList then
                            for _, desc in tabList:GetDescendants() do
                                if desc:IsA("TextLabel") and desc.Name == "PlayerLevel" then
                                    local text = desc.Text
                                    if text:find("%[%?%]") then
                                        local siblingName = desc.Parent:FindFirstChild("PlayerName")
                                        if siblingName then
                                            local currentNameText = siblingName.Text
                                            local cleanName = currentNameText:gsub("^@", ""):match("^%s*(.-)%s*$")
                                            
                                            local matchedPlayer = nil
                                            for _, plr in playersService:GetPlayers() do
                                                if plr == lplr then continue end
                                                if cleanName == plr.Name or cleanName == plr.DisplayName then
                                                    matchedPlayer = plr
                                                    break
                                                end
                                            end
                                            
                                            if matchedPlayer then
                                                local realLevel = levelMap[matchedPlayer.Name]
                                                if realLevel then
                                                    desc.Text = '<font color="rgb(255,255,255)">[' .. tostring(realLevel) .. ']</font>'
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        task.wait(0.3)
                    end
                end)

            else
                if updaterThread then
                    task.cancel(updaterThread)
                    updaterThread = nil
                end
                
                for _, plrs in playersService:GetPlayers() do
                    if plrs == lplr then continue end
                    
                    if old[plrs] then
                        plrs:SetAttribute("DisguiseDisplayName", old[plrs])
                        old[plrs] = nil
                    end
                    
                    if oldUsernames[plrs] then
                        plrs:SetAttribute("DisguiseUsername", oldUsernames[plrs])
                        oldUsernames[plrs] = nil
                    end
                    
                    if oldLevels[plrs] then
                        plrs:SetAttribute("PlayerLevel", oldLevels[plrs])
                        oldLevels[plrs] = nil
                    end
                end
                
                pcall(function()
                    bedwars.StreamerModeController:updateNametags(true)
                end)
                
                task.spawn(function()
                    local tabList = lplr.PlayerGui:FindFirstChild("TabListScreenGui")
                    if tabList then
                        tabList.Enabled = false
                        task.wait()
                        tabList.Enabled = true
                    end
                end)
            end
        end,
        Tooltip = 'sisable people streamer mode'
    })
end)

run(function()
	local WhiteHits
	WhiteHits = vape.Categories.Legit:CreateModule({
		Name = "WhiteHits",
		Function = function(callback)
			if callback then
				local function killHighlight(obj)
					if obj and obj.Name == '_DamageHighlight_' then
						pcall(function()
							obj.Enabled = false
							obj:Destroy()
						end)
					end
				end
				local function sweep(model)
					if not model then return end
					for _, obj in model:GetDescendants() do
						killHighlight(obj)
					end
				end
				WhiteHits:Clean(workspace.DescendantAdded:Connect(killHighlight))
				for _, plr in playersService:GetPlayers() do
					sweep(plr.Character)
				end
				for _, v in entitylib.List do
					sweep(v.Character)
				end
			end
		end,
		Tooltip = 'stops that red flash when ppl get hit so hits stay "white"'
	})
end)

--[[
	Kits Modules
]]

run(function()
    local Caitlyn
    local MethodDropdown
    local LowHealthSlider
    local ExecuteRangeSlider
    local HitRangeSlider
    local ProximityRangeSlider
    local connections = {}
    local Players = playersService
    local lplr = Players.LocalPlayer
    local currentTarget = nil
    local lastHitTime = 0
    local lastContractSelect = 0
    
    local function selectContract(targetPlayer)
        if not entitylib.isAlive then return false end
        if tick() - lastContractSelect < 0.1 then return false end
        
        local storeState = bedwars.Store:getState()
        local activeContract = storeState.Kit.activeContract
        local availableContracts = storeState.Kit.availableContracts or {}
        
        if activeContract then return false end
        if #availableContracts == 0 then return false end
        
        for _, contract in pairs(availableContracts) do
            if contract.target == targetPlayer then
                bedwars.Client:Get(remotes.BloodAssassinSelectContract):SendToServer({
                    contractId = contract.id
                })
                lastContractSelect = tick()
                return true
            end
        end
        return false
    end
    
    local function executeOnLowHealth()
        if not currentTarget or tick() - lastHitTime > 3 then
            currentTarget = nil
            return
        end
        
        if not currentTarget.Character then return end
        
        local humanoid = currentTarget.Character:FindFirstChild("Humanoid")
        local rootPart = currentTarget.Character:FindFirstChild("HumanoidRootPart")
        
        if humanoid and rootPart and lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart") then
            local health = humanoid.Health
            local distance = (lplr.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
            
            if health > 0 and health <= LowHealthSlider.Value and distance <= ExecuteRangeSlider.Value then
                selectContract(currentTarget)
            end
        end
    end
    
    local function contractOnHit()
        if not currentTarget or tick() - lastHitTime > 0.5 then
            currentTarget = nil
            return
        end
        
        if not currentTarget.Character then return end
        
        local rootPart = currentTarget.Character:FindFirstChild("HumanoidRootPart")
        
        if rootPart and lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (lplr.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
            
            if distance <= HitRangeSlider.Value then
                selectContract(currentTarget)
            end
        end
    end
    
    local function proximityContract()
        if not entitylib.isAlive then return end
        
        local myRoot = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        
        local closestPlayer = nil
        local closestDistance = ProximityRangeSlider.Value
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= lplr and player.Character then
                local theirRoot = player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = player.Character:FindFirstChild("Humanoid")
                
                if theirRoot and humanoid and humanoid.Health > 0 then
                    local distance = (myRoot.Position - theirRoot.Position).Magnitude
                    
                    if distance < closestDistance then
                        closestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
        
        if closestPlayer then
            selectContract(closestPlayer)
        end
    end
    
    Caitlyn = vape.Categories.Kits:CreateModule({
        Name = 'AutoCaitlyn',
        Function = function(callback)
            if callback then
                local damageConnection = vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
                    if not entitylib.isAlive then return end
                    
                    local attacker = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
                    local victim = playersService:GetPlayerFromCharacter(damageTable.entityInstance)
                
                    if attacker == lplr and victim and victim ~= lplr then
                        currentTarget = victim
                        lastHitTime = tick()
                    end
                end)
                table.insert(connections, damageConnection)
                
                task.spawn(function()
                    repeat
                        if entitylib.isAlive then
                            local method = MethodDropdown.Value
                            
                            if method == "Execute on Low HP" then
                                executeOnLowHealth()
                            elseif method == "Contract on Hit" then
                                contractOnHit()
                            elseif method == "Proximity Select" then
                                proximityContract()
                            end
                        end
                        task.wait(0.1)
                    until not Caitlyn.Enabled
                end)
            else
                for _, conn in pairs(connections) do
                    if typeof(conn) == "RBXScriptConnection" then
                        conn:Disconnect()
                    end
                end
                table.clear(connections)
                
                currentTarget = nil
                lastHitTime = 0
            end
        end,
        Tooltip = 'Auto contract selection for Caitlyn'
    })
    
    MethodDropdown = Caitlyn:CreateDropdown({
        Name = 'Method',
        List = {"Execute on Low HP", "Contract on Hit", "Proximity Select"},
        Default = "Execute on Low HP",
        Tooltip = 'Contract selection method',
        Function = function(value)
            LowHealthSlider.Object.Visible = (value == "Execute on Low HP")
            ExecuteRangeSlider.Object.Visible = (value == "Execute on Low HP")
            HitRangeSlider.Object.Visible = (value == "Contract on Hit")
            ProximityRangeSlider.Object.Visible = (value == "Proximity Select")
        end
    })
    
    LowHealthSlider = Caitlyn:CreateSlider({
        Name = 'Select HP',
        Min = 10,
        Max = 100,
        Default = 30,
        Tooltip = 'HP value to execute contract'
    })
    
    ExecuteRangeSlider = Caitlyn:CreateSlider({
        Name = 'Select Range',
        Min = 5,
        Max = 50,
        Default = 20,
        Suffix = ' studs',
        Tooltip = 'Range to select contract'
    })
    
    HitRangeSlider = Caitlyn:CreateSlider({
        Name = 'Hit Range',
        Min = 10,
        Max = 200,
        Default = 100,
        Suffix = ' studs',
        Tooltip = 'Max range to select a contract when hitting the player'
    })
    
    ProximityRangeSlider = Caitlyn:CreateSlider({
        Name = 'Proximity Range',
        Min = 10,
        Max = 200,
        Default = 50,
        Suffix = ' studs',
        Tooltip = 'Range to auto select nearby players'
    })
    
    LowHealthSlider.Object.Visible = true
    ExecuteRangeSlider.Object.Visible = true
    HitRangeSlider.Object.Visible = false
    ProximityRangeSlider.Object.Visible = false
end)

run(function()
    local InfKrystal
    local UPDATE_INTERVAL = 0.016
    local lastUpdateTime = 0
    local renderStepName = 'InfiniteKrystalMovement'

    InfKrystal = vape.Categories.Kits:CreateModule({
        Name = 'InfKrystal/AC Disabler',
        Tooltip = 'Infinite Krystal movement + AC Disabler -- made by crobo',
        Function = function(callback)
            if callback then
                lastUpdateTime = 0

                runService:BindToRenderStep(
                    renderStepName,
                    Enum.RenderPriority.Character.Value + 2,
                    function()
                        local currentTime = tick()

                        if currentTime - lastUpdateTime < UPDATE_INTERVAL then
                            return
                        end

                        lastUpdateTime = currentTime

                        pcall(function()
                            bedwars.GlacialSkaterController:updateMomentum(100, "newValue")
                        end)
                    end
                )
            else
                runService:UnbindFromRenderStep(renderStepName)

                pcall(function()
                    bedwars.GlacialSkaterController:updateMomentum(0, "newValue")
                end)
            end
        end
    })
end)

run(function()
    local DronePhase
    local modified = {}

    DronePhase = vape.Categories.Kits:CreateModule({
        Name = 'DronePhase',
        Function = function(callback)
            if callback then
                local lastDroneScan = 0
                DronePhase:Clean(runService.Stepped:Connect(function()
                    local now = os.clock()
                    if now - lastDroneScan < 0.25 then return end
                    lastDroneScan = now
                    local myDrone
                    for _, drone in collectionService:GetTagged('Drone') do
                        if drone:GetAttribute('PlayerUserId') == lplr.UserId then
                            myDrone = drone
                            break
                        end
                    end

                    for part, was in modified do
                        if not part.Parent or not myDrone or not part:IsDescendantOf(myDrone) then
                            modified[part] = nil
                            if part.Parent then
                                part.CanCollide = was
                            end
                        end
                    end

                    if myDrone then
                        for _, part in myDrone:GetDescendants() do
                            if part:IsA('BasePart') and part.CanCollide then
                                modified[part] = part.CanCollide
                                part.CanCollide = false
                            end
                        end
                    end
                end))
            else
                for part, was in modified do
                    if part.Parent then
                        part.CanCollide = was
                    end
                end
                table.clear(modified)

                for _, drone in collectionService:GetTagged('Drone') do
                    if drone:GetAttribute('PlayerUserId') == lplr.UserId then
                        for _, part in drone:GetDescendants() do
                            if part:IsA('BasePart') and not part.CanCollide then
                                part.CanCollide = true
                            end
                        end
                    end
                end
            end
        end,
        Tooltip = 'turns off collision for your drone - allowing you to phase through walls :D',
    })
end)

run(function()
    local AutoMetal
    local CollectionToggle
    local LimitToItem
    local Animation
    local CollectionDelay
    local DelaySlider
    local RangeSlider
    local ESPToggle
    local ESPNotify
    local ESPBackground
    local ESPColor
    local HoldingCheck
    local DistanceCheck
    local DistanceLimit
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local Reference = {}
    local lastNotification = 0
    local notificationPending = false
    local spawnQueue = {}
    local notificationCooldown = 1
    local collectionActive = false
    local collectedMetals = {}
    local animationDebounce = {}

    local function isHoldingAutoMetal()
        if not store.hand or not store.hand.tool then return false end
        return store.hand.tool.Name == 'metal_detector'
    end

    local function sendNotification(count)
        notif("Metal ESP", string.format("%d metals spawned", count), 3)
    end

    local function processSpawnQueue()
        if #spawnQueue == 0 then return end
        local currentTime = tick()
        local remaining = notificationCooldown - (currentTime - lastNotification)
        if remaining <= 0 then
            sendNotification(#spawnQueue)
            lastNotification = currentTime
            spawnQueue = {}
            notificationPending = false
        elseif not notificationPending then
            notificationPending = true
            task.delay(remaining, function()
                if #spawnQueue > 0 then
                    sendNotification(#spawnQueue)
                    lastNotification = tick()
                    spawnQueue = {}
                end
                notificationPending = false
            end)
        end
    end

    local function getProperImage()
        return bedwars.getIcon({itemType = 'iron'}, true)
    end

    local function Added(v)
        if Reference[v] then return end
        local _bpUserId = v:GetAttribute('PlacedByUserId')
        if _bpUserId then
            local _bpOk, _bpOwner = pcall(function() return playersService:GetPlayerByUserId(_bpUserId) end)
        end
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = 'hidden-metal'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
        billboard.Size = UDim2.fromOffset(36, 36)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = v
        
        local blur = addBlur(billboard)
        blur.Visible = ESPBackground.Enabled
        
        local image = Instance.new('ImageLabel')
        image.Size = UDim2.fromOffset(36, 36)
        image.Position = UDim2.fromScale(0.5, 0.5)
        image.AnchorPoint = Vector2.new(0.5, 0.5)
        image.BackgroundColor3 = Color3.fromHSV(ESPColor.Hue, ESPColor.Sat, ESPColor.Value)
        image.BackgroundTransparency = 1 - (ESPBackground.Enabled and ESPColor.Opacity or 0)
        image.BorderSizePixel = 0
        image.Image = getProperImage()
        image.Parent = billboard
        
        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 4)
        uicorner.Parent = image
        
        Reference[v] = billboard
        
        if ESPNotify.Enabled then
            table.insert(spawnQueue, {item = 'metal', time = tick()})
            processSpawnQueue()
        end
    end

    local function Removed(v)
        if Reference[v] then
            Reference[v]:Destroy()
            Reference[v] = nil
        end
    end

    local function setupESP()
        for _, v in collectionService:GetTagged('hidden-metal') do
            if v:IsA("Model") and v.PrimaryPart then
                Added(v.PrimaryPart)
            end
        end

        AutoMetal:Clean(collectionService:GetInstanceAddedSignal('hidden-metal'):Connect(function(v)
            if v:IsA("Model") and v.PrimaryPart then
                Added(v.PrimaryPart)
            end
        end))

        AutoMetal:Clean(collectionService:GetInstanceRemovedSignal('hidden-metal'):Connect(function(v)
            if v.PrimaryPart then
                Removed(v.PrimaryPart)
            end
        end))

        local _mdLastUpdate = 0
        AutoMetal:Clean(runService.RenderStepped:Connect(function()
            if not ESPToggle.Enabled then return end
            local _now = tick()
            if _now - _mdLastUpdate < 0.1 then return end
            _mdLastUpdate = _now
            
            for v, billboard in pairs(Reference) do
                if not v or not v.Parent then
                    Removed(v)
                    continue
                end

                local shouldShow = true

                if HoldingCheck.Enabled and not isHoldingAutoMetal() then
                    shouldShow = false
                end

                if shouldShow and DistanceCheck.Enabled and entitylib.isAlive then
                    local distance = (entitylib.character.RootPart.Position - v.Position).Magnitude
                    if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
                        shouldShow = false
                    end
                end

                billboard.Enabled = shouldShow
            end
        end))
    end

    local function collectMetal(metalModel)
        local metalId = metalModel:GetAttribute('Id')
        if not metalId then return false end
        if collectedMetals[metalId] then return false end

        collectedMetals[metalId] = true

        local success = pcall(function()
            bedwars.Client:Get(remotes.CollectCollectableEntity).instance:FireServer({ id = metalId })
        end)

        if Animation.Enabled then
            local currentTick = tick()
            if not animationDebounce[metalId] or (currentTick - animationDebounce[metalId]) >= 0.5 then
                animationDebounce[metalId] = currentTick
                pcall(function()
                    bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.SHOVEL_DIG)
                    bedwars.SoundManager:playSound(bedwars.SoundList.SNAP_TRAP_CONSUME_MARK)
                end)
            end
        end

        task.delay(2, function()
            collectedMetals[metalId] = nil
            animationDebounce[metalId] = nil
        end)
        
        return success
    end

    local function startAutoCollect()
        if collectionActive then return end
        collectionActive = true
        
        task.spawn(function()
            while AutoMetal.Enabled and CollectionToggle.Enabled and collectionActive do
                if not entitylib.isAlive then 
                    task.wait(0.5)
                    continue 
                end
                
                if LimitToItem.Enabled and not isHoldingAutoMetal() then 
                    task.wait(0.5)
                    continue 
                end
                
                local localPosition = entitylib.character.RootPart.Position
                local range = RangeSlider.Value
                local collectedThisCycle = false
								
				for _, v in collectionService:GetTagged('hidden-metal') do
					if not AutoMetal.Enabled or not CollectionToggle.Enabled or not collectionActive then 
						break 
					end
					
					if v:IsA("Model") and v.PrimaryPart then
						local distance = (localPosition - v.PrimaryPart.Position).Magnitude
						
						if distance <= range then
							if CollectionDelay.Enabled and DelaySlider.Value > 0 then
								task.wait(DelaySlider.Value)
							end
							if collectMetal(v) then
								collectedThisCycle = true
								if Animation.Enabled then
									task.wait(0.15)
								end
							end
						end
					end
				end
                
                task.wait(collectedThisCycle and (Animation.Enabled and 0.3 or 0.05) or 0.5)
            end
            
            collectionActive = false
        end)
    end

    local function stopAutoCollect()
        collectionActive = false
        table.clear(collectedMetals)
        table.clear(animationDebounce)
    end

    AutoMetal = vape.Categories.Kits:CreateModule({
        Name = 'AutoMetal',
        Function = function(callback)
            if callback then
                if ESPToggle.Enabled then 
                    setupESP() 
                end
                if CollectionToggle.Enabled then
                    startAutoCollect()
                end
            else
                stopAutoCollect()
                Folder:ClearAllChildren()
                table.clear(Reference)
                spawnQueue = {}
                lastNotification = 0
                notificationPending = false
            end
        end,
        Tooltip = 'automatically collects metal loot and esp'
    })
    
    CollectionToggle = AutoMetal:CreateToggle({
        Name = 'Auto Collect',
        Default = true,
        Function = function(callback)
            if LimitToItem and LimitToItem.Object then LimitToItem.Object.Visible = callback end
            if Animation and Animation.Object then Animation.Object.Visible = callback end
            if CollectionDelay and CollectionDelay.Object then CollectionDelay.Object.Visible = callback end
            if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = callback end
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback and CollectionDelay and CollectionDelay.Enabled
            end
            
            if AutoMetal.Enabled then
                if callback then
                    startAutoCollect()
                else
                    stopAutoCollect()                            if not PlayerDropdown.Value or PlayerDropdown.Value == "" or not table.find(newList, PlayerDropdown.Value) then
                                PlayerDropdown:SetValue(newList[1])
                            else
                                PlayerDropdown:SetValue(PlayerDropdown.Value)
                            end
                        end
                    end)
                end
                
                notif("AutoWhisper", string.format("teammate list (%d teammates)", #newList), 2)
            end)
        end,
    })
    
    LimitToItem = AutoWhisper:CreateToggle({
        Name = "Limit to Owl Orb",
        Default = true,
        Function = function(val)
        end,
    })

    AutoFly = AutoWhisper:CreateToggle({
        Name = "Auto Fly",
        Default = true,
        Function = function(val)
            if AutoWhisper.Enabled then
                if val then
                    flyRunning = true
                    hasActivatedFly = false
                    fallCheckTimer = 0
                    
                    task.spawn(function()
                        while flyRunning and AutoFly.Enabled do
                            if currentTarget and not hasActivatedFly then
                                if isFalling(currentTarget) and isAboveVoid(currentTarget) then
                                    fallCheckTimer = fallCheckTimer + 0.1
                                    
                                    if fallCheckTimer >= 0.5 then
                                        activateFly()
                                        fallCheckTimer = 0
                                    end
                                else
                                    fallCheckTimer = 0
                                end
                            else
                                fallCheckTimer = 0
                            end
                            
                            task.wait(0.1)
                        end
                    end)
                else
                    flyRunning = false
                    hasActivatedFly = false
                    fallCheckTimer = 0
                end
            end
        end,
    })
    
    AutoHeal = AutoWhisper:CreateToggle({
        Name = "Auto Heal",
        Default = true,
        Function = function(val)
            if AutoHealSlider and AutoHealSlider.Object then
                AutoHealSlider.Object.Visible = val
            end
            
            if AutoWhisper.Enabled then
                if val then
                    healRunning = true
                    task.spawn(function()
                        while healRunning and AutoHeal.Enabled do
                            if currentTarget then
                                local health, maxHealth = getPlayerHealth(currentTarget)
                                if not (health and maxHealth and maxHealth > 0) then task.wait(0.5) continue end
                                local healthPercent = (health / maxHealth) * 100
                                if healthPercent < AutoHealSlider.Value and healthPercent < 90 then
                                    healTarget()
                                    task.wait(8.5)
                                end
                            end
                            
                            task.wait(0.5)
                        end
                    end)
                else
                    healRunning = false
                end
            end
        end,
    })
    
    AutoHealSlider = AutoWhisper:CreateSlider({
        Name = "Heal Threshold",
        Min = 1,
        Max = 100,
        Default = 50,
        Suffix = "%",
    })

    OwlAuraToggle = AutoWhisper:CreateToggle({
        Name = "Owl Aura",
        Default = false,
        Function = function(val)
            setOwlOptionsVisible(val)
            if AutoWhisper.Enabled and val then
                startOwlAura()
            else
                stopOwlAura()
            end
        end,
        Tooltip = 'ur owl shoots whoever close to it on its own',
    })

    OwlTargets = AutoWhisper:CreateTargets({
        Players = true,
        NPCs = false,
        Walls = true,
        Visible = false
    })

    OwlRange = AutoWhisper:CreateSlider({
        Name = "Aura Range",
        Min = 10,
        Max = 60,
        Default = 40,
        Visible = false,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end,
    })

    OwlSort = AutoWhisper:CreateDropdown({
        Name = "Aura Sort",
        List = {'Distance', 'Damage', 'Cursor'},
        Default = 'Distance',
        Visible = false,
        Tooltip = 'who the owl goes for first, damage means whoever got hit last',
    })

    task.defer(function()
        setOwlOptionsVisible(OwlAuraToggle.Enabled)
    end)
end)

run(function()
	local AutoLasso
	local Targets
	local Range
	local Angle
	local LimitToLasso
	local ArrowCharge

	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		projectileRemote = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('ProjectileFire')
	end)
	local handGunRemote = {InvokeServer = function() end}
	task.spawn(function()
		handGunRemote = game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("HandGunFireRequest")
	end)

	local rayCheck = RaycastParams.new()
	local lastShot = 0
	local autoLassoLoop

	local function doLasso()
		if not entitylib.isAlive then return false end
		if LimitToLasso.Enabled then
			if not store.hand or not store.hand.tool or store.hand.tool.Name ~= 'lasso' then
				return false
			end
		end

		local lasso = getItem('lasso')
		if not lasso then return false end

		local ent = entitylib.EntityPosition({
			Range = Range.Value,
			Part = 'RootPart',
			Wallcheck = Targets.Walls.Enabled,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Sort = sortmethods.Distance
		})
		if not ent or not ent.RootPart then return false end

		local selfpos = entitylib.character.RootPart.Position
		local localfacing = gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
		local delta = (ent.RootPart.Position - selfpos) * Vector3.new(1, 0, 1)
		if delta.Magnitude <= 0.001 then return false end
		if math.acos(math.clamp(localfacing:Dot(delta.Unit), -1, 1)) > (math.rad(Angle.Value) / 2) then return false end
		local meta = bedwars.ProjectileMeta['lasso']
		local projSpeed = (meta and tonumber(meta.launchVelocity)) or 200
		local gravity = (meta and tonumber(meta.gravitationalAcceleration)) or 135
		local hip = ent.HipHeight or (ent.Humanoid and ent.Humanoid.HipHeight) or 2
		local leadPos = ent.RootPart.Position + Vector3.new(0, hip * 0.15, 0)
		local vel = ent.RootPart.AssemblyLinearVelocity or ent.RootPart.Velocity
		local calc = prediction.SolveTrajectory(selfpos, projSpeed, gravity, leadPos, vel, workspace.Gravity, hip, ent.Jumping and 42.6 or nil, rayCheck, nil, ent.RootPart.Position, ent.RootPart, nil, true)
		if not calc then return false end
		local originalSlot = store.inventory.hotbarSlot
		local lassoSlot
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType == 'lasso' then
				lassoSlot = i - 1
				break
			end
		end

		local swapped = false
		if lassoSlot and lassoSlot ~= originalSlot and not LimitToLasso.Enabled then
			hotbarSwitch(lassoSlot)
			task.wait(0.03)
			swapped = true
		end

		local res = projectileRemote:InvokeServer(
			lasso.tool,
			'lasso',
			'lasso',
			selfpos,
			selfpos,
			CFrame.lookAt(selfpos, calc).LookVector * projSpeed,
			httpService:GenerateGUID(true),
			{
				drawDurationSeconds = 1,
				shotId = httpService:GenerateGUID(false)
			},
			workspace:GetServerTimeNow() - 0.045
		)

		if swapped then
			hotbarSwitch(originalSlot)
		end

		return res and true or false
	end

	local function startAutoLassoLoop()
		if autoLassoLoop then return end
		autoLassoLoop = task.spawn(function()
			while AutoLasso and AutoLasso.Enabled do
				local ok, fired = pcall(doLasso)
				task.wait((ok and fired) and 0.5 or 0.1)
			end
			autoLassoLoop = nil
		end)
	end

	local function stopAutoLassoLoop()
		if autoLassoLoop then
			task.cancel(autoLassoLoop)
			autoLassoLoop = nil
		end
	end

	AutoLasso = vape.Categories.Kits:CreateModule({
		Name = 'AutoLasso',
		Function = function(callback)
			if callback then
				startAutoLassoLoop()
			else
				stopAutoLassoLoop()
			end
		end
	})

	Targets = AutoLasso:CreateTargets({Players = true})
	Range = AutoLasso:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 60,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Angle = AutoLasso:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 120
	})
	LimitToLasso = AutoLasso:CreateToggle({
		Name = 'Limit to Lasso',
		Default = false,
	})
end)

run(function()
	local InfiniteSigrid
	local Kit = 'elk_master'
	local running = false

	InfiniteSigrid = vape.Categories.Kits:CreateModule({
		Name = 'InfiniteSigrid',
		Tooltip = 'ride yo shitty ass elk forever',
		Function = function(call)
			if call then
				if running then return end
				running = true
				task.spawn(function()
					repeat
						if entitylib.isAlive then
							if store.equippedKit == Kit then
								local Mount = bedwars.Client:Get('ElkKitMounted')
								if Mount then
									Mount:SendToServer()
								end
							end
						end
						task.wait(0.1)
					until not InfiniteSigrid.Enabled or not running
					running = false
				end)
			else
				running = false
			end
		end
	})
end)

run(function()
	local MinerSpy
	local IgnoreTeammatesMiner

	MinerSpy = vape.Categories.Kits:CreateModule({
		Name = "MinerSpy",
		Tooltip = 'notifies when players get petrified or mined by a miner',
		Function = function(callback)
			if callback then
				MinerSpy:Clean(bedwars.Client:OnEvent("Petrified", function(tbl)
					if not MinerSpy.Enabled then return end
					local victim = playersService:GetPlayerFromCharacter(tbl.to)
					local killer = playersService:GetPlayerFromCharacter(tbl.killer)
					if not victim then return end

					if IgnoreTeammatesMiner.Enabled then
						if victim.Team == lplr.Team then return end
					end

					local victimName = victim.Name
					victimName = victimName:sub(1, 1):upper() .. victimName:sub(2)

					local killerText = ''
					if killer then
						local killerName = killer.Name
						killerName = killerName:sub(1, 1):upper() .. killerName:sub(2)
						killerText = ' by ' .. killerName
					end

					notif("MinerSpy", victimName .. " was petrified" .. killerText, 8)
				end))

				MinerSpy:Clean(bedwars.Client:OnEvent("PetrifiedPlayerDestroyed", function(tbl)
					if not MinerSpy.Enabled then return end
					local destroyer = tbl.destroyer

					local destroyerText = 'Unknown'
					if destroyer then
						local destroyerName = destroyer.Name
						destroyerText = destroyerName:sub(1, 1):upper() .. destroyerName:sub(2)
						if IgnoreTeammatesMiner.Enabled and destroyer.Team == lplr.Team then return end
					end

					local rewardText = ''
					if tbl.rewards then
						local totals = {}
						local order = {}
						for _, reward in ipairs(tbl.rewards) do
							local item = tostring(reward.itemType) or 'unknown'
							local amount = tonumber(reward.amount) or 0
							if not totals[item] then
								totals[item] = 0
								table.insert(order, item)
							end
							totals[item] = totals[item] + amount
						end
						local parts = {}
						for _, item in ipairs(order) do
							table.insert(parts, item .. ' x' .. totals[item])
						end
						if #parts > 0 then
							rewardText = ' | Loot: ' .. table.concat(parts, ', ')
						end
					end

					notif("MinerSpy", destroyerText .. " mined a petrified player" .. rewardText, 8)
				end))
			end
		end
	})
	IgnoreTeammatesMiner = MinerSpy:CreateToggle({Name='Ignore Teammates',Default=true})
end)

run(function()
	local AutoVulcan
	local Targets
	local ArrowCharge
	local turretfiretime = {}
	local netman = game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged
	local turretTargets = {}
	local Sort
	local AimTurretRemote = netman:FindFirstChild("AimTurret")
	local PFR = netman:FindFirstChild("ProjectileFire")
	local turretthread = {}
	local Distance
	local PHR = netman:FindFirstChild("ProjectileHit")
	local RTR = netman:FindFirstChild("RaycastTurret")
	local LimitTablet

	local function tableFind(tab, val)
		for _, v in ipairs(tab) do
			if v == val then return true end
		end
		return false
	end

	local function isHoldingTablet()
		local hand = store.hand
		return hand and hand.tool and hand.tool.Name and hand.tool.Name:find('tablet') ~= nil
	end

	local function getOwnedTurrets()
		local turrets = {}
		for _, block in ipairs(store.blocks or {}) do
			if block.Name == "camera_turret"
				and block:GetAttribute("PlacedByUserId") == lplr.UserId
				and block.Parent
			then
				table.insert(turrets, block)
			end
		end
		return turrets
	end

	local function isTargetValid(ent, turretPos)
		if not ent or not ent.Character then return false end
		if not ent.RootPart or not ent.RootPart.Parent then return false end
		if (ent.Character:GetAttribute("Health") or 0) <= 0 then return false end
		if (turretPos - ent.RootPart.Position).Magnitude > (Distance and Distance.Value or 1000) then return false end
		return true
	end

	local function getTarget(turret)
		local turretPos = turret.Position
		local locked = turretTargets[turret]
		if isTargetValid(locked, turretPos) then
			return locked
		end

		local ent = entitylib.EntityPosition({
			Origin = turretPos,
			Range = Distance and Distance.Value or 1000,
			Part = "RootPart",
			Players = Targets and Targets.Players.Enabled or true,
			NPCs = Targets and Targets.NPCs.Enabled or true,
			Sort = sortmethods and Sort and sortmethods[Sort.Value] or nil
		})

		turretTargets[turret] = ent
		return ent
	end

	local turretBlockPosCache = {}

	local function fireTurret(turret)
		if not turret or not turret.Parent then return end
		if LimitTablet and LimitTablet.Enabled and not isHoldingTablet() then return end

		local turretPos = turret.Position
		local blockPos = turretBlockPosCache[turret]
		if not blockPos then
			blockPos = bedwars.BlockController:getBlockPosition(turretPos)
			turretBlockPosCache[turret] = blockPos
		end
		local ent = getTarget(turret)
		if not ent or not ent.RootPart then return end

		local char = ent.Character
		local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or ent.RootPart
		local targetVel = ent.RootPart.AssemblyLinearVelocity or Vector3.zero
		local travel = (torso.Position - turretPos).Magnitude / 300
		local targetPos = torso.Position + targetVel * travel

		local lookDir = targetPos - turretPos
		if lookDir.Magnitude < 0.1 then return end
		lookDir = lookDir.Unit

		local flatMag = Vector3.new(lookDir.X, 0, lookDir.Z).Magnitude
		local yaw = math.atan2(-lookDir.X, -lookDir.Z)
		local pitch = math.atan2(lookDir.Y, flatMag > 0 and flatMag or 0.001)

		if AimTurretRemote then
			pcall(function()
				AimTurretRemote:FireServer({
					angleX = math.deg(yaw),
					angleY = math.deg(pitch),
					turretBlockPos = blockPos,
				})
			end)
		end

		local now = tick()
		if (now - (turretfiretime[turret] or 0)) < (FireRate and FireRate.Value or 0.05) then return end
		turretfiretime[turret] = now

		local fireId = httpService:GenerateGUID(false):sub(1, 8)
		local shotId = httpService:GenerateGUID(false):sub(1, 8)
		local targetChar = ent.Character
		local shootOrigin = turretPos + lookDir * 2 + Vector3.new(0, 1, 0)
		local velocity = lookDir * 300

		task.spawn(function()
			local firedId
			local myKit = lplr.Character and lplr.Character:GetAttribute('Kit')
			if PFR and myKit ~= 'block-kicker' then
				pcall(function()
					firedId = PFR:InvokeServer(
						turret, nil, "turretBullet",
						shootOrigin, turretPos, velocity,
						fireId,
						{ shotId = shotId, drawDurationSec = 0 },
						workspace:GetServerTimeNow() - 0.045 - 0.045
					)
				end)
			elseif RTR then
				pcall(function()
					local targetDir = (targetPos - turretPos).Unit * 500
					RTR:FireServer(turret, turretPos + Vector3.new(0, 1, 0), targetDir, blockPos)
				end)
			end

			if not firedId then
				turretTargets[turret] = nil
				return
			end

			task.wait(0.05)
			if not targetChar or not targetChar.Parent then return end
			if (targetChar:GetAttribute("Health") or 0) <= 0 then return end

			if PHR then
				pcall(function() PHR:FireServer(firedId, targetChar) end)
				task.wait(0.02)
				if targetChar and targetChar.Parent and (targetChar:GetAttribute("Health") or 0) > 0 then
					pcall(function() PHR:FireServer(firedId, targetChar) end)
				end
			end
		end)
	end

	local function startTurretLoop(turret)
		if turretthread[turret] then return end

		turretthread[turret] = task.spawn(function()
			while AutoVulcan.Enabled and turret and turret.Parent do
				if entitylib.isAlive then
					pcall(fireTurret, turret)
				end
				task.wait(0.05)
			end
			turretthread[turret] = nil
			turretTargets[turret] = nil
			turretfiretime[turret] = nil
		end)
	end

	local function stopAllLoops()
		for _, thread in pairs(turretthread) do
			pcall(task.cancel, thread)
		end
		table.clear(turretthread)
		table.clear(turretTargets)
		table.clear(turretfiretime)
		table.clear(turretBlockPosCache)
	end

	AutoVulcan = vape.Categories.Kits:CreateModule({
		Name = 'AutoVulcan',
		Function = function(callback)
			if callback then
				cleanThread(AutoVulcan, task.spawn(function()
					while AutoVulcan.Enabled do
						local turrets = getOwnedTurrets()
						for _, turret in ipairs(turrets) do
							startTurretLoop(turret)
						end
						for turret, thread in pairs(turretthread) do
							if not turret.Parent then
								pcall(task.cancel, thread)
								turretthread[turret] = nil
								turretTargets[turret] = nil
								turretfiretime[turret] = nil
							end
						end
						task.wait(1)
					end
				end))
				AutoVulcan:Clean(stopAllLoops)
			else
				stopAllLoops()
			end
		end,
	})

	Targets = AutoVulcan:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = false,
	})

	FireRate = AutoVulcan:CreateSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 3,
		Default = 0,
		Tooltip = 'Shots per second',
	})

	Distance = AutoVulcan:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 1000,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
	})

	Sort = AutoVulcan:CreateDropdown({
		Name = 'Target mode',
		List = getSortList({'Distance', 'Health', 'Cursor'}),
		Default = 'Distance',
	})

	LimitTablet = AutoVulcan:CreateToggle({
		Name = 'Limit to tablet',
		Default = false,
		Tooltip = 'only works when u holdin the tablet'
	})
end)

run(function()
	local InstantJade
	local old = nil
	
    InstantJade = vape.Categories.Kits:CreateModule({
		Name = "InstantJade",
		Tooltip = "no cooldown on the jade hammer",
		Function = function(callback)
			if callback then
				if old then return end
				old = bedwars.CooldownController.isOnCooldown
				bedwars.CooldownController.isOnCooldown = function(self, id)
					if id ~= nil and string.find(tostring(id):lower(), 'jade', 1, true) then
						return false
					end
					if type(old) ~= 'function' then return false end
					return old(self, id)
				end
			else
				if old then
					bedwars.CooldownController.isOnCooldown = old
					old = nil
				end
			end
		end
	})
end)

run(function()
	local InstantRegent
	local old = nil
	
	InstantRegent = vape.Categories.Kits:CreateModule({
		Name = "InstantRegent",
		Tooltip = "no cooldown on the void axe spam",
		Function = function(callback)
			if callback then
				if old then return end
				old = bedwars.CooldownController.isOnCooldown
				bedwars.CooldownController.isOnCooldown = function(self, id)
					if id ~= nil and string.find(tostring(id):lower(), 'void_axe', 1, true) then
						return false
					end
					if type(old) ~= 'function' then return false end
					return old(self, id)
				end
			else
				if old then
					bedwars.CooldownController.isOnCooldown = old
					old = nil
				end
			end
		end
	})
end)

run(function()
	local YuziDasher
	local ImpulseSlider
	local JumpHeightSlider
	local CurrentKeybind = Enum.KeyCode.Q
	local canDash = true

	local function PerformDash()
		if not canDash then return end
		if not entitylib.isAlive then return end

		local heldItem = store.hand.tool
		if not heldItem or not (heldItem.Name:find("dao") or heldItem.Name:find("yuzi") or heldItem.Name == "jade_hammer" or heldItem.Name == "void_axe") then return end

		local abilityId = (heldItem.Name == "jade_hammer" and "JADE_HAMMER_JUMP") or (heldItem.Name == "void_axe" and "VOID_AXE_JUMP") or nil

		local character = lplr.Character
		if not (character and character.PrimaryPart) then return end

		canDash = false

		task.spawn(function()
			local originalJumpHeight = character.Humanoid.JumpHeight

			pcall(function() character:SetAttribute('CanDash', 0) end)

			local lookVector = gameCamera.CFrame.LookVector
			local origin = character.PrimaryPart.Position

			pcall(function()
				local n = game:GetService("ReplicatedStorage"):FindFirstChild("rbxts_include")
				if n then n = n:FindFirstChild("node_modules") end
				if n then n = n:FindFirstChild("@rbxts") end
				if n then n = n:FindFirstChild("net") end
				if n then n = n:FindFirstChild("out") end
				if n then n = n:FindFirstChild("_NetManaged") end
				if n then n = n:FindFirstChild("SwordSwingMiss") end
				if n then n:FireServer({ weapon = heldItem, chargeRatio = 0 }) end
			end)

			task.wait(0.05)

			local useDash = abilityId == nil
			local canUse = useDash and bedwars.AbilityController:canUseAbility('dash') or (abilityId and bedwars.AbilityController:canUseAbility(abilityId))

			if canUse then
				if useDash then
					bedwars.AbilityController:useAbility('dash', nil, {
						direction = lookVector,
						origin = origin,
						weapon = heldItem.Name
					})
				else
					bedwars.AbilityController:useAbility(abilityId)
				end

				pcall(function()
					bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.DAO_DASH)
				end)

				pcall(function()
					local hrp = character.HumanoidRootPart
					local mass = hrp.AssemblyMass or 5
					hrp:ApplyImpulse(lookVector.Unit * Vector3.new(1, 0, 1) * mass * ImpulseSlider.Value)
					character.Humanoid.JumpHeight = JumpHeightSlider.Value
					character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end)

				task.delay(0.5, function()
					if character and character.Humanoid then
						pcall(function()
							character.Humanoid.JumpHeight = originalJumpHeight
							if bedwars.JumpHeightController then
								bedwars.JumpHeightController:setJumpHeight(game:GetService("StarterPlayer").CharacterJumpHeight)
							end
						end)
					end
				end)
			end

			task.wait(0.3)
			canDash = true
		end)
	end

	YuziDasher = vape.Categories.Kits:CreateModule({
		Name = 'YuziDasher',
		Function = function(callback)
			if callback then
				YuziDasher:Clean(inputService.InputBegan:Connect(function(input, gameProcessed)
					if gameProcessed then return end
					if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == CurrentKeybind then
						PerformDash()
					end
				end))
			else
				canDash = true
			end
		end,
	})

	local keybindOptions = {
		"Q", "E", "R", "F", "G", "X", "Z", "V", "B",
		"LeftAlt", "LeftControl", "LeftShift", "RightAlt", "RightControl", "RightShift",
		"Space", "CapsLock", "Tab"
	}

	YuziDasher:CreateDropdown({
		Name = 'Keybind',
		List = keybindOptions,
		Default = "Q",
		Function = function(value)
			CurrentKeybind = Enum.KeyCode[value]
		end
	})

	ImpulseSlider = YuziDasher:CreateSlider({
		Name = 'Impulse Multiplier',
		Min = 10,
		Max = 500,
		Default = 100,
		Tooltip = 'Controls dash speed'
	})

	JumpHeightSlider = YuziDasher:CreateSlider({
		Name = 'Jump Height',
		Min = 0,
		Max = 50,
		Default = 10,
	})
end)

run(function()
	local KaidaKillaura	
	local Targets
	local AttackRange
	local UpdateRate
	local MouseDown
	local GUICheck
	local ShowAnimation
	local AutoAbility
	local AbilityDistance
	local SwingDuringAbility
	local lastAttackTime = 0
	local lastAbilityTime = 0
	local attackCooldown = 0.55
	local abilityCooldown = 22
	local isChargingAbility = false
	manualCharging = false
	local currentTarget = nil
	local AutoStopAbility
	local SummonerKitController = nil
	local function getSummonerController()
		if SummonerKitController then return SummonerKitController end
		pcall(function()
			SummonerKitController = bedwars.KnitClient.Controllers.SummonerKitController
		end)
		return SummonerKitController
	end

	local function isActuallyCharging()
		if isChargingAbility then return true end
		if manualCharging then return true end
		local result = false
		pcall(function()
			local btns = lplr.PlayerGui
				:FindFirstChild("ActionBarScreenGui")
				and lplr.PlayerGui.ActionBarScreenGui:FindFirstChild("ActionBar")
				and lplr.PlayerGui.ActionBarScreenGui.ActionBar:FindFirstChild("AbilityButtons")
			if btns and btns:FindFirstChild("summoner_finish_charging") then
				result = true
			end
		end)
		return result
	end

	local function getSpellLevel()
		local level = 1
		pcall(function()
			local util = require(game:GetService("ReplicatedStorage").TS.games.bedwars.kit.kits.summoner['summoner-kit-util'])
			local result = util.summoner_getPlayerSpellLevel(lplr)
			if result then level = result end
		end)
		return level
	end

	local function getCastTime(level)
		local castTime = 2
		pcall(function()
			local util = require(game:GetService("ReplicatedStorage").TS.games.bedwars.kit.kits.summoner['summoner-kit-util'])
			local result = util.summoner_getTotalCastTimeRequired(level)
			if result then castTime = result end
		end)
		return castTime
	end

	local function fireUseAbility(abilityName)
		pcall(function()
			game:GetService("ReplicatedStorage")
				:WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events")
				:WaitForChild("useAbility"):FireServer(abilityName)
		end)
	end

	local function doAutoAbility()
		if isChargingAbility then return end
		isChargingAbility = true

		pcall(function()
			local remote = game:GetService("ReplicatedStorage")
				:WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events")
				:WaitForChild("useAbility")

			remote:FireServer(unpack({"summoner_start_charging"}))

			if AutoStopAbility.Enabled then
				task.wait(0.5)
				remote:FireServer(unpack({"summoner_finish_charging"}))
			else
				local level = getSpellLevel()
				local castTime = getCastTime(level)
				task.wait(math.max(castTime, 0.5))
				if isChargingAbility then
					remote:FireServer(unpack({"summoner_finish_charging"}))
					if currentTarget and currentTarget.RootPart then
						local myPos = entitylib.character.RootPart.Position
						local shootDir = CFrame.lookAt(myPos, currentTarget.RootPart.Position).LookVector
						local localPosition = myPos + shootDir * math.max((myPos - currentTarget.RootPart.Position).Magnitude - 16, 0)
						bedwars.Client:Get(remotes.SummonerClawAttack):SendToServer({
							position = localPosition,
							direction = shootDir,
							clientTime = workspace:GetServerTimeNow()
						})
					end
				end
			end
		end)

		lastAbilityTime = tick()
		isChargingAbility = false
	end

	local function getPlayerClawLevel()
		local handItem = lplr.Character and lplr.Character:FindFirstChild('HandInvItem')
		if handItem and handItem.Value then
			local itemType = handItem.Value.Name
			if itemType == 'summoner_claw_1' then return 1 end
			if itemType == 'summoner_claw_2' then return 2 end
			if itemType == 'summoner_claw_3' then return 3 end
			if itemType == 'summoner_claw_4' then return 4 end
		end
		if store and store.inventory and store.inventory.hotbar then
			for _, v in pairs(store.inventory.hotbar) do
				if v.item then
					local itemType = v.item.itemType
					if itemType == 'summoner_claw_1' then return 1 end
					if itemType == 'summoner_claw_2' then return 2 end
					if itemType == 'summoner_claw_3' then return 3 end
					if itemType == 'summoner_claw_4' then return 4 end
				end
			end
		end
		return 1
	end

	KaidaKillaura = vape.Categories.Kits:CreateModule({
		Name = 'AutoKaida',
		Function = function(callback)
			if callback then
				lastAttackTime = 0
				lastAbilityTime = 0
				isChargingAbility = false
				manualCharging = false   
				pcall(function()
					local abilityButtons = lplr.PlayerGui
						:WaitForChild("ActionBarScreenGui", 10)
						:WaitForChild("ActionBar", 10)
						:WaitForChild("AbilityButtons", 10)

					KaidaKillaura:Clean(abilityButtons.ChildRemoved:Connect(function(child)
						if child.Name == "summoner_start_charging" then
							manualCharging = true
						end
						if child.Name == "summoner_finish_charging" then
							manualCharging = false
						end
					end))

					KaidaKillaura:Clean(abilityButtons.ChildAdded:Connect(function(child)
						if child.Name == "summoner_start_charging" then
							manualCharging = false
						end
					end))

					if abilityButtons:FindFirstChild("summoner_finish_charging") then
						manualCharging = true
					end
				end)

				repeat
					if not entitylib.isAlive then
						task.wait(0.1)		end
	})

	BeehiveBackground = KitSpy:CreateToggle({
		Name = 'Beehive Background',
		Default = true,
		Darker = true,
		Visible = false,
		Function = function(callback)
			if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = callback end
			for _, ref in BeehiveReference do
				if ref and ref.frame then
					local opacity = BeehiveColor and BeehiveColor.Opacity or 0.5
					ref.frame.BackgroundTransparency = 1 - (callback and opacity or 0)
				end
				if ref and ref.billboard then
					local blur = ref.billboard:FindFirstChild("Blur")
					if blur then blur.Visible = callback end
				end
			end
		end
	})

	BeehiveColor = KitSpy:CreateColorSlider({
		Name = 'Beehive Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Darker = true,
		Visible = false,
		Function = function(hue, sat, val, opacity)
			for _, ref in BeehiveReference do
				if ref and ref.frame then
					ref.frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					ref.frame.BackgroundTransparency = 1 - (BeehiveBackground.Enabled and opacity or 0)
				end
			end
		end
	})

	LuciaToggle = KitSpy:CreateToggle({
		Name = 'Lucia',
		Function = function(callback)
			if LuciaIgnoreTeammates and LuciaIgnoreTeammates.Object then LuciaIgnoreTeammates.Object.Visible = callback end
			if LuciaDisplayName and LuciaDisplayName.Object then LuciaDisplayName.Object.Visible = callback end
			if KitSpy.Enabled then
				if callback then setupLuciaSpy() else cleanupLucia() end
			end
		end
	})

	LuciaIgnoreTeammates = KitSpy:CreateToggle({
		Name = 'Lucia Ignore Teammates',
		Default = true,
		Darker = true,
		Visible = false,
	})

	LuciaDisplayName = KitSpy:CreateToggle({
		Name = 'Lucia Display Name',
		Default = false,
		Darker = true,
		Visible = false,
	})

	FishermanToggle = KitSpy:CreateToggle({
		Name = 'Fisherman',
		Function = function(callback)
			if FishermanIgnoreTeammates and FishermanIgnoreTeammates.Object then FishermanIgnoreTeammates.Object.Visible = callback end
			if KitSpy.Enabled and callback then
				setupFishermanSpy()
			end
		end
	})

	FishermanIgnoreTeammates = KitSpy:CreateToggle({
		Name = 'Fisherman Ignore Teammates',
		Default = true,
		Darker = true,
		Visible = false,
	})

	BountyHunterToggle = KitSpy:CreateToggle({
		Name = 'Bounty Hunter',
		Tooltip = 'shows u who a bounty hunter is huntin and the loot they get when they get em',
		Function = function(callback)
			if BountyTargetToggle and BountyTargetToggle.Object then BountyTargetToggle.Object.Visible = callback end
			if BountyLootToggle and BountyLootToggle.Object then BountyLootToggle.Object.Visible = callback end
			if KitSpy.Enabled then
				if callback then setupBountyHunterSpy() else cleanupBountyHunter() end
			end
		end
	})

	BountyTargetToggle = KitSpy:CreateToggle({
		Name = 'Bounty Hunter Target',
		Default = true,
		Darker = true,
		Visible = false,
	})

	BountyLootToggle = KitSpy:CreateToggle({
		Name = 'Bounty Hunter Loot',
		Default = true,
		Darker = true,
		Visible = false,
	})
	local DrillToggle, DrillNotify, DrillESPToggle, DrillTeamCheck
	local drillFolder = Instance.new('Folder')
	drillFolder.Parent = vape.gui
	local drillRefs, drillConns, drillLast = {}, {}, {}
	local drillActive = false

	local function drillOwner(drill)
		local id = drill:GetAttribute('PlacedByUserId')
		return id and playersService:GetPlayerByUserId(id) or nil
	end

	local function drillSkip(drill)
		local owner = drillOwner(drill)
		if owner == lplr then return true end
		local myTeam = lplr:GetAttribute('Team')
		return owner ~= nil and ((myTeam ~= nil and owner:GetAttribute('Team') == myTeam) or (lplr.Team ~= nil and owner.Team == lplr.Team))
	end

	local function drillLoot(drill)
		local itemType = drill:GetAttribute('ItemType')
		return itemType, itemType and (drill:GetAttribute(itemType) or 0) or 0
	end

	local function drillUpdate(drill)
		local gui = drillRefs[drill]
		if not gui then return end
		local itemType, amount = drillLoot(drill)
		local owner = drillOwner(drill)
		gui.Label.Text = (owner and owner.DisplayName or 'drill') .. (itemType and (' | ' .. amount .. ' ' .. itemType:gsub('_', ' ')) or '') .. ' | ' .. math.floor(drill:GetAttribute('Health') or 0) .. ' hp'
	end

	local function drillAddESP(drill)
		if drillRefs[drill] or drillSkip(drill) then return end
		local head = drill:FindFirstChild('Head') or drill.PrimaryPart or drill:FindFirstChildWhichIsA('BasePart')
		if not head then return end
		local gui = Instance.new('BillboardGui')
		gui.Name = 'drill-spy'
		gui.Size = UDim2.fromOffset(200, 22)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		gui.AlwaysOnTop = true
		gui.Adornee = head
		gui.Parent = drillFolder
		local label = Instance.new('TextLabel')
		label.Name = 'Label'
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.new(0, 0, 0)
		label.BackgroundTransparency = 0.45
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.4
		label.TextSize = 13
		label.Font = Enum.Font.GothamBold
		label.Parent = gui
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = label
		drillRefs[drill] = gui
		drillUpdate(drill)
	end

	local function drillRemoveESP(drill)
		if drillRefs[drill] then
			drillRefs[drill]:Destroy()
			drillRefs[drill] = nil
		end
	end

	local function drillWatch(drill, fresh)
		if drillLast[drill] ~= nil then return end
		local _, amount = drillLoot(drill)
		drillLast[drill] = amount
		local owner = drillOwner(drill)
		if fresh and DrillNotify.Enabled and not drillSkip(drill) then
			notif('Kit Spy', (owner and owner.DisplayName or 'someone') .. ' placed a drill', 4)
		end
		table.insert(drillConns, drill.AttributeChanged:Connect(function()
			local itemType, now = drillLoot(drill)
			local before = drillLast[drill] or 0
			drillLast[drill] = now
			if now < before and DrillNotify.Enabled and not drillSkip(drill) then
				notif('Kit Spy', (owner and owner.DisplayName or 'someone') .. ' took ' .. (before - now) .. ' ' .. tostring(itemType or 'loot'):gsub('_', ' ') .. ' from their drill', 4)
			end
			if DrillESPToggle.Enabled then
				drillUpdate(drill)
			end
		end))
		if DrillESPToggle.Enabled then
			drillAddESP(drill)
		end
	end

	local function drillStop()
		drillActive = false
		for _, conn in drillConns do
			conn:Disconnect()
		end
		table.clear(drillConns)
		table.clear(drillLast)
		for drill in drillRefs do
			drillRemoveESP(drill)
		end
	end

	local function drillStart()
		if drillActive then return end
		drillActive = true
		for _, obj in workspace:GetDescendants() do
			if obj:IsA('Model') and obj.Name == 'Drill' then
				drillWatch(obj, false)
			end
		end
		table.insert(drillConns, workspace.DescendantAdded:Connect(function(obj)
			if obj:IsA('Model') and obj.Name == 'Drill' then
				task.wait(0.2)
				if obj.Parent then
					drillWatch(obj, true)
				end
			end
		end))
		table.insert(drillConns, workspace.DescendantRemoving:Connect(function(obj)
			if drillLast[obj] ~= nil then
				drillLast[obj] = nil
				drillRemoveESP(obj)
			end
		end))
	end

	task.spawn(function()
		while vape.Loaded ~= false do
			local want = KitSpy and KitSpy.Enabled and DrillToggle and DrillToggle.Enabled
			if want and not drillActive then
				drillStart()
			elseif not want and drillActive then
				drillStop()
			end
			task.wait(0.5)
		end
		drillStop()
	end)

	DrillToggle = KitSpy:CreateToggle({
		Name = 'Drill',
		Tooltip = 'tells u when someone places a drill or takes loot from their drill',
		Function = function(callback)
			if DrillNotify and DrillNotify.Object then DrillNotify.Object.Visible = callback end
			if DrillESPToggle and DrillESPToggle.Object then DrillESPToggle.Object.Visible = callback end
		end
	})
	DrillNotify = KitSpy:CreateToggle({
		Name = 'Drill Notifications',
		Default = true,
		Darker = true,
		Visible = false
	})
	DrillESPToggle = KitSpy:CreateToggle({
		Name = 'Drill ESP',
		Darker = true,
		Visible = false,
		Tooltip = 'shows who owns each drill, whats in it and its health',
		Function = function(callback)
			if not drillActive then return end
			for drill in drillLast do
				if callback then drillAddESP(drill) else drillRemoveESP(drill) end
			end
		end
	})
	task.defer(function()
		local on = DrillToggle.Enabled
		DrillNotify.Object.Visible = on
		DrillESPToggle.Object.Visible = on
	end)
end)

run(function()
    local StarCollector
    local CollectionToggle
    local Animation
    local RangeSlider
    local ESPToggle
    local ESPNotify
    local ESPBackground
    local ESPColor
    local SwordCheck
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local Reference = {}
    local starCooldowns = {}
    local COOLDOWN_TIME = 0.5
    local lastNotification = 0
    local spawnQueue = {}
    local notificationCooldown = 1
    local collectionRunning = false

    local function sendNotification(count)
        notif("Star ESP", string.format("%d stars spawned", count), 3)
    end

    local function processSpawnQueue()
        if #spawnQueue > 0 then
            local currentTime = tick()
            if currentTime - lastNotification >= notificationCooldown then
                sendNotification(#spawnQueue)
                lastNotification = currentTime
                spawnQueue = {}
            else
                task.delay(notificationCooldown - (currentTime - lastNotification), function()
                    if #spawnQueue > 0 then
                        sendNotification(#spawnQueue)
                        spawnQueue = {}
                    end
                end)
            end
        end
    end

    local function getProperImage(v)
        local parent = v.Parent
        if parent and parent:IsA("Model") then
            local modelName = parent.Name
            if modelName == "CritStar" then
                return bedwars.getIcon({itemType = 'crit_star'}, true)
            elseif modelName == "VitalityStar" then
                return bedwars.getIcon({itemType = 'vitality_star'}, true)
            elseif modelName:find("vitality") or modelName:lower():find("vitality") then
                return bedwars.getIcon({itemType = 'vitality_star'}, true)
            elseif modelName:find("crit") or modelName:lower():find("crit") then
                return bedwars.getIcon({itemType = 'crit_star'}, true)
            end
        end
        return bedwars.getIcon({itemType = 'crit_star'}, true)
    end

    local function Added(v)
        if Reference[v] then return end
        local _bpUserId = v:GetAttribute('PlacedByUserId')
        if _bpUserId then
            local _bpOk, _bpOwner = pcall(function() return playersService:GetPlayerByUserId(_bpUserId) end)
        end
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = 'stars'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
        billboard.Size = UDim2.fromOffset(36, 36)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = v
        
        local blur = addBlur(billboard)
        blur.Visible = ESPBackground.Enabled
        
        local image = Instance.new('ImageLabel')
        image.Size = UDim2.fromOffset(36, 36)
        image.Position = UDim2.fromScale(0.5, 0.5)
        image.AnchorPoint = Vector2.new(0.5, 0.5)
        image.BackgroundColor3 = Color3.fromHSV(ESPColor.Hue, ESPColor.Sat, ESPColor.Value)
        image.BackgroundTransparency = 1 - (ESPBackground.Enabled and ESPColor.Opacity or 0)
        image.BorderSizePixel = 0
        image.Image = getProperImage(v)
        image.Parent = billboard
        
        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 4)
        uicorner.Parent = image
        
        Reference[v] = billboard
        
        if ESPNotify.Enabled then
            table.insert(spawnQueue, {item = 'star', time = tick()})
            processSpawnQueue()
        end
    end

    local function Removed(v)
        if Reference[v] then
            Reference[v]:Destroy()
            Reference[v] = nil
        end
        starCooldowns[v] = nil
    end

    local function setupESP()
        for _, v in collectionService:GetTagged('stars') do
            if v:IsA("Model") and v.PrimaryPart then
                Added(v.PrimaryPart)
            end
        end

        StarCollector:Clean(collectionService:GetInstanceAddedSignal('stars'):Connect(function(v)
            if v:IsA("Model") and v.PrimaryPart then
                task.wait(0.1)
                Added(v.PrimaryPart)
            end
        end))

        StarCollector:Clean(collectionService:GetInstanceRemovedSignal('stars'):Connect(function(v)
            if v.PrimaryPart then
                Removed(v.PrimaryPart)
            end
        end))
        
        local _scLastUpdate = 0
        StarCollector:Clean(runService.RenderStepped:Connect(function()
            if not ESPToggle.Enabled then return end
            local _now = tick()
            if _now - _scLastUpdate < 0.1 then return end
            _scLastUpdate = _now
            
            for v, billboard in pairs(Reference) do
                if not v or not v.Parent then
                    Removed(v)
                    continue
                end

                local shouldShow = true

                if SwordCheck.Enabled and isSword() then
                    shouldShow = false
                end

                billboard.Enabled = shouldShow
            end
        end))
    end

    local function collectStar(star)
        if not star or not star.Parent then return end
        
        if Animation.Enabled and entitylib.isAlive then
            bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.PUNCH)
            bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
        end
        
        bedwars.StarCollectorController:collectEntity(lplr, star, star.Name)
    end

	local function startCollection()
		collectionRunning = true
		task.spawn(function()
			while collectionRunning and StarCollector.Enabled and CollectionToggle.Enabled do
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end

				local localPosition = entitylib.character.RootPart.Position
				local range = RangeSlider.Value
				local collected = false

				for _, v in collectionService:GetTagged('stars') do
					if not collectionRunning or not StarCollector.Enabled or not CollectionToggle.Enabled then
						break
					end

					if v:IsA("Model") and v.PrimaryPart then
						local starPos = v.PrimaryPart.Position
						local distance = (localPosition - starPos).Magnitude

						if distance <= range then
							local lastAttempt = starCooldowns[v]
							if lastAttempt and tick() - lastAttempt < COOLDOWN_TIME then
								continue
							end
							starCooldowns[v] = tick()
							collectStar(v)
							collected = true
							break
						end
					end
				end

				task.wait(collected and 0.1 or 0.2)
			end
			collectionRunning = false
		end)
	end

    StarCollector = vape.Categories.Kits:CreateModule({
        Name = 'AutoStar',
        Function = function(callback)
            if callback then
                if ESPToggle.Enabled then 
                    setupESP() 
                end
                
                if CollectionToggle.Enabled then
                    startCollection()
                end
            else
                collectionRunning = false
                Folder:ClearAllChildren()
                table.clear(Reference)
                table.clear(spawnQueue)
                table.clear(starCooldowns)
                lastNotification = 0
            end
        end,
    })
    
    CollectionToggle = StarCollector:CreateToggle({
        Name = 'Auto Collect',
        Default = true,
        Function = function(callback)
            if Animation and Animation.Object then Animation.Object.Visible = callback end
            if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = callback end
            
            if callback and StarCollector.Enabled then
                startCollection()
            else
                collectionRunning = false
            end
        end
    })
    
    Animation = StarCollector:CreateToggle({
        Name = 'Animation',
        Default = true,
    })
    
    RangeSlider = StarCollector:CreateSlider({
        Name = 'Range',
        Min = 1, 
        Max = 18,
        Default = 10,
        Decimal = 1,
        Suffix = ' studs',
    })
    
    ESPToggle = StarCollector:CreateToggle({
        Name = 'Star ESP',
        Default = false,
        Function = function(callback)
            if ESPNotify and ESPNotify.Object then ESPNotify.Object.Visible = callback end
            if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = callback end
            if ESPColor and ESPColor.Object then ESPColor.Object.Visible = callback end
            if SwordCheck and SwordCheck.Object then SwordCheck.Object.Visible = callback end
            
            if StarCollector.Enabled then
                if callback then 
                    setupESP() 
                else
                    Folder:ClearAllChildren()
                    table.clear(Reference)
                end
            end
        end
    })
    
    ESPNotify = StarCollector:CreateToggle({
        Name = 'Notify',
        Default = false,
    })
    
    ESPBackground = StarCollector:CreateToggle({
        Name = 'Background',
        Default = true,
        Function = function(callback)
            if ESPColor and ESPColor.Object then ESPColor.Object.Visible = callback end
            for _, v in Reference do
                if v and v:FindFirstChild("ImageLabel") then
                    v.ImageLabel.BackgroundTransparency = 1 - (callback and ESPColor.Opacity or 0)
                    if v:FindFirstChild("Blur") then
                        v.Blur.Visible = callback
                    end
                end
            end
        end
    })
    
    ESPColor = StarCollector:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, v in Reference do
                if v and v:FindFirstChild("ImageLabel") then
                    v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                    v.ImageLabel.BackgroundTransparency = 1 - opacity
                end
            end
        end,
        Darker = true
    })
    SwordCheck = StarCollector:CreateToggle({
        Name = 'Sword Check',
        Default = false,
    })

    task.defer(function()
        local espOn = ESPToggle and ESPToggle.Enabled
        if ESPNotify and ESPNotify.Object then ESPNotify.Object.Visible = espOn end
        if ESPBackground and ESPBackground.Object then ESPBackground.Object.Visible = espOn end
        if ESPColor and ESPColor.Object then ESPColor.Object.Visible = espOn end
        if SwordCheck and SwordCheck.Object then SwordCheck.Object.Visible = espOn end
    end)
end)

run(function()
    local Melody
    local SelfHeal
    local TeammateHeal
    local RangeSlider
    local PlayerDropdown
    local healRunning = false
    local lastHealTime = 0
    local healCooldown = 1

    local function getItem(itemName)
        if not entitylib.isAlive then return false end
        
        local inventory = store.inventory
        if inventory and inventory.inventory and inventory.inventory.hand then
            local handItem = inventory.inventory.hand
            if handItem and handItem.itemType == itemName then
                return true
            end
        end
        return false
    end

    local function getLowestHealthTeammate()
        if not entitylib.isAlive then return nil end

        local localPosition = entitylib.character.RootPart.Position
        local range = RangeSlider.Value
        local picked = PlayerDropdown and PlayerDropdown.Value

        if picked and picked ~= 'None' then
            for _, v in entitylib.List do
                if v.Player and v.Player ~= lplr and v.Player.Name == picked then
                    local distance = (localPosition - v.RootPart.Position).Magnitude
                    if distance <= range and v.Health < v.MaxHealth then
                        return v
                    end
                    return nil
                end
            end
            return nil
        end

        local lowestHp = math.huge
        local targetEntity = nil

        for _, v in entitylib.List do
            if v.Player and v.Player ~= lplr and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') then
                local distance = (localPosition - v.RootPart.Position).Magnitude

                if distance <= range and v.Health < lowestHp and v.Health < v.MaxHealth then
                    lowestHp = v.Health
                    targetEntity = v
                end
            end
        end

        return targetEntity
    end

    local function shouldSelfHeal()
        if not entitylib.isAlive then return false end
        
        local currentHealth = lplr.Character:GetAttribute('Health') or 0
        local maxHealth = lplr.Character:GetAttribute('MaxHealth') or 100
        
        return currentHealth < maxHealth
    end

    local function performHeal(target)
        local currentTime = tick()
        if currentTime - lastHealTime < healCooldown then
            return false
        end
        
        if not getItem('guitar') then
            return false
        end
        
        bedwars.Client:Get(remotes.GuitarHeal):SendToServer({
            healTarget = target
        })
        
        lastHealTime = currentTime
        return true
    end

    local function startHealing()
        healRunning = true
        task.spawn(function()
            while healRunning and Melody.Enabled do
                if not entitylib.isAlive then
                    task.wait(0.1)
                    continue
                end
                
                if not getItem('guitar') then
                    task.wait(0.2)
                    continue
                end
                
                local healed = false
                
                if SelfHeal.Enabled and shouldSelfHeal() then
                    if performHeal(lplr.Character) then
                        healed = true
                    end
                end
                
                if not healed and TeammateHeal.Enabled then
                    local teammate = getLowestHealthTeammate()
                    if teammate then
                        if performHeal(teammate.Character) then
                            healed = true
                        end
                    end
                end
                
                task.wait(0.1)
            end
            healRunning = false
        end)
    end

    Melody = vape.Categories.Kits:CreateModule({
        Name = 'AutoMelody',
        Function = function(callback)
            if callback then
                lastHealTime = 0
                startHealing()
                local function refreshList()
                    if PlayerDropdown and type(PlayerDropdown.SetList) == 'function' then
                        local list = {'None'}
                        for _, name in ipairs(getTeammates(true)) do
                            table.insert(list, name)
                        end
                        PlayerDropdown:SetList(list)
                    end
                end
                refreshList()
                Melody:Clean(playersService.PlayerAdded:Connect(function() task.wait(0.5) refreshList() end))
                Melody:Clean(playersService.PlayerRemoving:Connect(function() task.wait(0.5) refreshList() end))
                Melody:Clean(lplr:GetAttributeChangedSignal('Team'):Connect(function() task.wait(1) refreshList() end))
            else
                healRunning = false
                lastHealTime = 0
            end
        end,
        Tooltip = 'auto heal yourself and teammates with guitar'
    })
    
    SelfHeal = Melody:CreateToggle({
        Name = 'Self Heal',
        Default = true,
    })
    
    TeammateHeal = Melody:CreateToggle({
        Name = 'Teammate Heal',
        Default = true,
        Function = function(callback)
            if RangeSlider and RangeSlider.Object then
                RangeSlider.Object.Visible = callback
            end
        end
    })
    
    RangeSlider = Melody:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 20,
        Default = 20,
        Decimal = 1,
        Suffix = ' studs',
    })

    PlayerDropdown = Melody:CreateDropdown({
        Name = 'Target Teammate',
        List = {'None'},
        Default = 'None',
        Tooltip = 'pick who u wanna heal, None just heals whoevers lowest hp'
    })
end)

run(function()
    local autoZenoModule
    local targetSettings
    local targetSelectionMode
    local itemLimitToggle
    local shockwaveToggle
    local shockwaveRadius
    local lightningStrikeToggle
    local lightningStormToggle
    local attackRange
    local actionDelay

    local function fetchAttackItem()
        if itemLimitToggle.Enabled then
            local wizardStaff = (store.hand.tool and store.hand.tool.Name:find('wizard_staff')) and store.hand.tool or nil
            return wizardStaff, wizardStaff and getHotbar(wizardStaff) or nil, wizardStaff and (tonumber(wizardStaff.Name:sub(#wizardStaff.Name, #wizardStaff.Name)) or 1) or nil
        end

        if store.hand.tool and store.hand.tool.Name:find('wizard_staff') then
            local item = store.hand.tool
            return item, getHotbar(item), tonumber(item.Name:sub(#item.Name, #item.Name)) or 1
        end

        for index, item in pairs(store.inventory.inventory.items) do
            if item.itemType:find('wizard_staff') then
                switchItem(item, 0)
                return item, index, tonumber(item.itemType:sub(#item.itemType, #item.itemType)) or 1
            end
        end

        return nil
    end

    autoZenoModule = vape.Categories.Kits:CreateModule({
        Name = 'AutoZeno',
        Function = function(callback)
            if callback then
                repeat
                    if entitylib.isAlive then
                        local staff, _, level = fetchAttackItem()

                        if staff then
                            local playerPosition = entitylib.character.RootPart.Position
                            local nearestEntity = entitylib.EntityPosition({
                                Origin = playerPosition,
                                Range = (attackRange.Value < 6 and shockwaveToggle.Enabled and 7) or attackRange.Value,
                                Part = 'RootPart',
                                Players = targetSettings.Players.Enabled,
                                NPCs = targetSettings.NPCs.Enabled,
                                Sort = sortmethods[targetSelectionMode.Value]
                            })

                            if nearestEntity then
                                if shockwaveToggle.Enabled and level > 2 then
                                    if bedwars.AbilityController:canUseAbility('SHOCKWAVE') and (playerPosition - nearestEntity.RootPart.Position).Magnitude <= shockwaveRadius.Value then
                                        bedwars.AbilityController:useAbility('SHOCKWAVE', newproxy(true), {
                                            target = CFrame.lookAt(playerPosition, nearestEntity.RootPart.Position).LookVector
                                        })
                                        task.wait(actionDelay.Value)
                                    end
                                end

                                if lightningStrikeToggle.Enabled and bedwars.AbilityController:canUseAbility('LIGHTNING_STRIKE') then
                                    bedwars.AbilityController:useAbility('LIGHTNING_STRIKE', newproxy(true), {
                                        target = nearestEntity.RootPart.Position + ((nearestEntity.Humanoid.MoveDirection or Vector3.zero) * (1 + lplr:GetNetworkPing()))
                                    })
                                    task.wait(actionDelay.Value)
                                end

                                if lightningStormToggle.Enabled and level > 1 then
                                    if bedwars.AbilityController:canUseAbility('LIGHTNING_STORM') then
                                        bedwars.AbilityController:useAbility('LIGHTNING_STORM', newproxy(true), {
                                            target = nearestEntity.RootPart.Position + ((nearestEntity.Humanoid.MoveDirection or Vector3.zero) * (1 + lplr:GetNetworkPing()))
                                        })
                                        task.wait(actionDelay.Value)
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                until not autoZenoModule.Enabled
            end
        end,
    })

    targetSettings = autoZenoModule:CreateTargets({
        Players = true,
        NPCs = false
    })

    local availableSortingMethods = {'Damage', 'Distance'}
    for method in sortmethods do
        if not table.find(availableSortingMethods, method) then
            table.insert(availableSortingMethods, method)
        end
    end

    targetSelectionMode = autoZenoModule:CreateDropdown({
        Name = 'Target Mode',
        List = availableSortingMethods,
        Default = 'Distance'
    })

    itemLimitToggle = autoZenoModule:CreateToggle({
        Name = 'Limit to item',
        Default = true
    })

    lightningStrikeToggle = autoZenoModule:CreateToggle({
        Name = 'Use Lightning Strike',
        Default = true
    })

    lightningStormToggle = autoZenoModule:CreateToggle({
        Name = 'Use Lightning Storm'
    })

    shockwaveRadius = autoZenoModule:CreateSlider({
        Name = 'Shockwave Range',
        Visible = false,
        Darker = true,
        Min = 1,
        Max = 12,
        Suffix = function(value)
            return value > 1 and 'studs' or 'stud'
        end,
        Decimal = 5,
        Default = 12
    })

    shockwaveToggle = autoZenoModule:CreateToggle({
        Name = 'Auto Shockwave',
        Function = function(enabled)
            pcall(function()
                shockwaveRadius.Object.Visible = enabled
            end)
        end
    })

    attackRange = autoZenoModule:CreateSlider({
        Name = 'Attack Range',
        Min = 1,
        Max = 60,
        Default = 35,
        Suffix = function(value)
            return value > 1 and 'studs' or 'stud'
        end,
        Decimal = 5
    })

    actionDelay = autoZenoModule:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 10,
        Default = 0.5,
        Decimal = 5,
        Suffix = function(value)
            return value > 1 and 'secs' or 'sec'
        end
    })
end)

run(function()
    local AutoGinger
    local LimitToItem
    local BreakDelay
    local BreakDelaySlider
    local AutoSwitch
    local SwitchMode
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local lastBreakTime = 0
    local lastPlaceTime = 0
    local placeCheckConnection
    local justPlacedGumdrop = false
    local lastPlacedPosition = nil
    
    _G.gingerLock = _G.gingerLock or false
    
    local function getGumdropSlot()
        for i, v in store.inventory.hotbar do
            if v.item and v.item.itemType == "gumdrop_bounce_pad" then
                return i - 1
            end
        end
        return nil
    end
    
    local function getPredictedPosition()
        if not (lplr.Character and lplr.Character.PrimaryPart) then return nil end
        local root = lplr.Character.PrimaryPart
        local velocity = root.AssemblyLinearVelocity
        local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
        local speed = horizontalVelocity.Magnitude
        if speed < 1 then return root.Position end
        local predictionTime = math.clamp(speed / 40, 0.15, 0.35)
        return root.Position + (horizontalVelocity * predictionTime)
    end
    
    local function forceBreak(block)
        if not block then return end
        lastBreakTime = tick()
        justPlacedGumdrop = false
        task.spawn(function()
            for i = 1, 6 do
                if not block or not block.Parent then return end
                pcall(bedwars.breakBlock, block, false, nil, true)
                task.wait(0.05)
            end
        end)
    end
    
    local function tryPlaceGumdrop()
        if not AutoSwitch.Enabled or _G.gingerLock then return end        Function = function(callback)
            if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = callback end
            for _, ref in BeehiveReference do
                if ref and ref.billboard then
                    local frame = ref.billboard:FindFirstChild("Frame")
                    if frame then
                        if ref.isMaxed and ref.isOwn then
                            frame.BackgroundTransparency = 1 - (callback and 0.5 or 0)
                        else
                            frame.BackgroundTransparency = 1 - (callback and BeehiveColor.Opacity or 0)
                        end
                    end
                    if ref.billboard:FindFirstChild("Blur") then
                        ref.billboard.Blur.Visible = callback
                    end
                end
            end
        end
    })
    
    BeehiveColor = Beekeeper:CreateColorSlider({
        Name = 'Beehive Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, ref in BeehiveReference do
                if ref and ref.billboard then
                    local frame = ref.billboard:FindFirstChild("Frame")
                    if frame and not (ref.isMaxed and ref.isOwn) then
                        frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                        frame.BackgroundTransparency = 1 - opacity
                    end
                end
            end
        end,
        Darker = true
    })
    
    AutoDeposit = Beekeeper:CreateToggle({
        Name = 'Auto Deposit',
        Default = false,
		Function = function(callback)
			if DepositDelay and DepositDelay.Object then DepositDelay.Object.Visible = callback end
			if DepositDelaySlider and DepositDelaySlider.Object then DepositDelaySlider.Object.Visible = (callback and DepositDelay.Enabled) end
			if DepositRange and DepositRange.Object then DepositRange.Object.Visible = callback end
			if HiveLimit and HiveLimit.Object then HiveLimit.Object.Visible = callback end
			
			if not callback then
				if DepositDelaySlider and DepositDelaySlider.Object then DepositDelaySlider.Object.Visible = false end
			end

			if callback and Beekeeper.Enabled then
				startDeposit()
			else
				depositRunning = false
			end
		end
    })
    
    DepositDelay = Beekeeper:CreateToggle({
        Name = 'Deposit Delay',
        Default = false,
        Function = function(callback)
            if DepositDelaySlider and DepositDelaySlider.Object then
                DepositDelaySlider.Object.Visible = callback
            end
        end
    })
    
    DepositDelaySlider = Beekeeper:CreateSlider({
        Name = 'Deposit Delay',
        Min = 0,
        Max = 2,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
    })
    
    DepositRange = Beekeeper:CreateSlider({
        Name = 'Deposit Range',
        Min = 1,
        Max = 10,
        Default = 10,
        Decimal = 1,
        Suffix = ' studs',
    })
    
    HiveLimit = Beekeeper:CreateSlider({
        Name = 'Hive Limit',
        Min = 1,
        Max = 20,
        Default = 12,
        Decimal = 1,
        Suffix = ' bees',
        Function = function()
            table.clear(maxedBeehives)
            table.clear(maxedNotificationSent)
        end
    })
	task.defer(function()
		if HiveLimit and HiveLimit.Object then HiveLimit.Object.Visible = AutoDeposit.Enabled end
		if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = CollectionDelay.Enabled end
		if not ESPToggle.Enabled or not BeesESP.Enabled then
			if BeesNotify and BeesNotify.Object then BeesNotify.Object.Visible = false end
			if BeesBackground and BeesBackground.Object then BeesBackground.Object.Visible = false end
			if BeesColor and BeesColor.Object then BeesColor.Object.Visible = false end
		else
			if BeesColor and BeesColor.Object then BeesColor.Object.Visible = BeesBackground.Enabled end
		end

		if not ESPToggle.Enabled or not BeehiveESP.Enabled then
			if ShowOtherBeehives and ShowOtherBeehives.Object then ShowOtherBeehives.Object.Visible = false end
			if BeehiveBackground and BeehiveBackground.Object then BeehiveBackground.Object.Visible = false end
			if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = false end
		else
			if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = BeehiveBackground.Enabled end
		end

		if AutoDeposit and not AutoDeposit.Enabled then
			if DepositDelay and DepositDelay.Object then DepositDelay.Object.Visible = false end
			if DepositDelaySlider and DepositDelaySlider.Object then DepositDelaySlider.Object.Visible = false end
			if DepositRange and DepositRange.Object then DepositRange.Object.Visible = false end
		end

		if DepositDelaySlider and DepositDelaySlider.Object then
			DepositDelaySlider.Object.Visible = (AutoDeposit.Enabled and DepositDelay.Enabled)
		end
	end)
end)

run(function()
    local Fisherman
    local AutoMinigameToggle
    local CompleteDelaySlider
    local PullAnimationToggle
    local MinigameAnimationToggle
    local BlacklistOption
    local Blacklist
    local ESPToggle
	local AutoCastDelay
	local AutoCast
    local ESPNotifyToggle
    local Players = playersService
	local RunService = runService
	local lplr = Players.LocalPlayer
	local RandomizeToggle
    local RandomRange
	local waitTime
    local fishNames = {
		fish_iron = "Iron Fish",
		fish_diamond = "Diamond Fish",
		fish_gold = "Gold Fish",
		fish_special = "Special Fish",
		fish_emerald = "Emerald Fish",
	}

    local function buildMessage(fishModel, drops)
        local fishName = fishNames[fishModel] or fishModel

        if not drops or #drops == 0 then
            if fishModel == "fish_special" then
                return "You caught a " .. fishName .. "! (special item incoming)"
            end
            return "You caught a " .. fishName .. "!"
        end

        local totals = {}
        local order = {}
        for _, drop in ipairs(drops) do
            local item = tostring(drop.itemType) or 'unknown'
            local amount = tonumber(drop.amount) or 0
            if not totals[item] then
                totals[item] = 0
                table.insert(order, item)
            end
            totals[item] = totals[item] + amount
        end

        if fishModel == "fish_special" then
            return "You caught a " .. fishName .. "! You will receive a " .. table.concat(order, ", ")
        end

        local parts = {}
        for _, item in ipairs(order) do
            table.insert(parts, math.ceil(totals[item] * 1.4) .. "x " .. item)
        end

        return "You caught a " .. fishName .. "! Receiving " .. table.concat(parts, ", ")
    end

    local notifQueue = {}
	local function safeNotif(title, msg, dur)
		table.insert(notifQueue, {title=title, message=msg, duration=dur or 5})
	end
	local heartbeatConn = nil

    local autoMinigameActive    = false
    local pullAnimationTrack    = nil
    local successAnimationTrack = nil
    local espOld                = nil

	local function getBait()
		for _, v in workspace:GetChildren() do
			if v.Name == "fisherman_bobber" and v:GetAttribute("ProjectileShooter") == lplr.UserId then
				return v
			end
		end

		return
	end

    local function stopAllAnimations()
        if pullAnimationTrack then
            pcall(function() pullAnimationTrack:Stop() end)
            pullAnimationTrack = nil
        end
        if successAnimationTrack then
            pcall(function() successAnimationTrack:Stop() end)
            successAnimationTrack = nil
        end
    end

    local function setupESP()
        if not bedwars or not bedwars.FishingMinigameController then
            warn("[AutoFisher] FishingMinigameController not found")
            return
        end
        if espOld then return end 
        espOld = bedwars.FishingMinigameController.startMinigame

        bedwars.FishingMinigameController.startMinigame = function(self, dropData, result)
            if ESPToggle.Enabled and ESPNotifyToggle.Enabled and dropData and dropData.fishModel then
                safeNotif("Fisherman ESP", buildMessage(dropData.fishModel, dropData.drops), 8)
            end
            return espOld(self, dropData, result)
        end

        Fisherman:Clean(function()
            if espOld then
                bedwars.FishingMinigameController.startMinigame = espOld
                espOld = nil
            end
        end)
    end

    local function cleanupESP()
        if espOld then
            bedwars.FishingMinigameController.startMinigame = espOld
            espOld = nil
        end
    end

    local function setupAutoMinigame()
        if not bedwars or not bedwars.FishingMinigameController then
            warn("[AutoFisher] FishingMinigameController not found")
            return
        end

        local old = bedwars.FishingMinigameController.startMinigame

        bedwars.FishingMinigameController.startMinigame = function(self, dropData, result)
            if not AutoMinigameToggle.Enabled then
                return old(self, dropData, result)
            end

            if BlacklistOption.Enabled and dropData and dropData.fishModel then
                if table.find(Blacklist.ListEnabled, dropData.fishModel) then
                    local hum = lplr.Character and lplr.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum:GetState() ~= Enum.HumanoidStateType.Jumping then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                    return old(self, dropData, result)
                end
            end

            autoMinigameActive = true
            stopAllAnimations()

            local waitTime = 0
            if RandomizeToggle and RandomizeToggle.Enabled then
                local min = RandomRange.ValueMin
                local max = RandomRange.ValueMax
                waitTime = min + (max - min) * math.random()
            else
                waitTime = CompleteDelaySlider.Value
            end

            task.spawn(function()
                if PullAnimationToggle.Enabled and waitTime > 0 then
                    local ok, track = pcall(function()
                        return bedwars.GameAnimationUtil:playAnimation(
                            lplr, bedwars.AnimationType.FISHING_ROD_PULLING
                        )
                    end)
                    if ok and track then pullAnimationTrack = track end
                end

                if waitTime > 0 then
                    task.wait(waitTime)
                end

                if pullAnimationTrack then
                    pcall(function() pullAnimationTrack:Stop() end)
                    pullAnimationTrack = nil
                end

                if MinigameAnimationToggle.Enabled then
                    local ok, track = pcall(function()
                        return bedwars.GameAnimationUtil:playAnimation(
                            lplr, bedwars.AnimationType.FISHING_ROD_CATCH_SUCCESS
                        )
                    end)
                    if ok and track then successAnimationTrack = track end
                end

                if result then
                    pcall(function() result({ win = true }) end)
                end

                task.wait(0.5)

                if successAnimationTrack then
                    pcall(function() successAnimationTrack:Stop() end)
                    successAnimationTrack = nil
                end

                autoMinigameActive = false
            end)
        end

        Fisherman:Clean(function()
            bedwars.FishingMinigameController.startMinigame = old
            stopAllAnimations()
        end)
    end

	local function setupAutoCast()
		task.spawn(function()
			repeat
				if entitylib.isAlive and AutoCast.Enabled and (store.hand.tool and store.hand.tool.Name == 'fishing_rod') then
					local position = workspace.CurrentCamera.ViewportSize / 2
					local ray = cloneref(lplr:GetMouse()).UnitRay

					if not getBait() and not workspace:Raycast(entitylib.character.Head.Position + (ray.Direction * 6), Vector3.new(0, -20, 0)) then
						task.wait(AutoCastDelay:GetRandomValue())

						for _, v in {true, false} do
							VirtualInputManager:SendMouseButtonEvent(position.X, position.Y, 0, v, game, 1)
							task.wait()
						end
						task.wait(0.5)
					end
				end
				task.wait(0.1)
			until not Fisherman.Enabled
		end)
	end

    Fisherman = vape.Categories.Kits:CreateModule({
		Name = "AutoFisher",
		Function = function(callback)
            if callback then
                if ESPToggle.Enabled then setupESP() end
                if AutoMinigameToggle.Enabled then setupAutoMinigame() end
                setupAutoCast()

                heartbeatConn = RunService.Heartbeat:Connect(function()
                    if #notifQueue == 0 then return end
                    local entry = table.remove(notifQueue, 1)
                    pcall(notif, entry.title, entry.message, entry.duration)
                end)
                Fisherman:Clean(heartbeatConn)

            else
                autoMinigameActive = false
                stopAllAnimations()
                cleanupESP()
                notifQueue = {} 
            end
        end
    })

    AutoMinigameToggle = Fisherman:CreateToggle({
		Name = "Auto Minigame",
		Default = false,
		Function = function(cv)
			if CompleteDelaySlider and CompleteDelaySlider.Object then
				CompleteDelaySlider.Object.Visible = cv and not (RandomizeToggle and RandomizeToggle.Enabled)
			end
			if PullAnimationToggle and PullAnimationToggle.Object then PullAnimationToggle.Object.Visible = cv end
			if MinigameAnimationToggle and MinigameAnimationToggle.Object then MinigameAnimationToggle.Object.Visible = cv end
			if RandomizeToggle and RandomizeToggle.Object then RandomizeToggle.Object.Visible = cv end
			if RandomRange and RandomRange.Object then RandomRange.Object.Visible = cv and RandomizeToggle.Enabled end
			if Fisherman.Enabled and cv then setupAutoMinigame() end
		end
	})

	CompleteDelaySlider = Fisherman:CreateSlider({
		Name = "Complete Delay",
		Min = 0,
		Max = 5,
		Default = 1,
		Decimal = 10,
		Suffix = "s",
		Visible = false,
	})

	RandomizeToggle = Fisherman:CreateToggle({
		Name = "Randomize Timing",
		Default = false,
		Function = function(cv)
			if RandomRange and RandomRange.Object then RandomRange.Object.Visible = cv end
			if CompleteDelaySlider and CompleteDelaySlider.Object then CompleteDelaySlider.Object.Visible = not cv end
		end
	})

	RandomRange = Fisherman:CreateTwoSlider({
		Name = "Random Delay Range",
		Min = 0.1,
		Max = 5,
		DefaultMin = 0.5,
		DefaultMax = 2,
		Decimal = 10,
		Visible = false,
	})

	PullAnimationToggle = Fisherman:CreateToggle({
		Name = "Pull Animation",
		Default = true,
		Visible = false,
	})

	MinigameAnimationToggle = Fisherman:CreateToggle({
		Name = "Success Animation",
		Default = true,
		Visible = false,
	})

	BlacklistOption = Fisherman:CreateToggle({
		Name = "Blacklist",
		Default = false,
		Function = function(cv)
			if Blacklist and Blacklist.Object then Blacklist.Object.Visible = cv end
		end
	})

	Blacklist = Fisherman:CreateTextList({
		Name = "Blacklist Fish",
		Default = {"fish_iron"}
	})

	AutoCast = Fisherman:CreateToggle({
		Name 	= "AutoCast",
		Default = false,
		Function = function(callback)
			if callback then
				if AutoCastDelay and AutoCastDelay.Object then AutoCastDelay.Object.Visible = callback end
				if AutoCast.Enabled and callback then setupAutoCast() end
			end
		end
	})

	AutoCastDelay = Fisherman:CreateTwoSlider({
		Name 	= "Cast Delay",
		Min 	= 0,
		Max 	= 5,
		Decimal = 5,
		DefaultMin = 0.3,
		DefaultMax = 1.2,
		Darker 	= true,
		Visible = AutoCast.Enabled
	})	

    ESPToggle = Fisherman:CreateToggle({
		Name = "Fisherman ESP",
		Default = false,
		Function = function(cv)
			if ESPNotifyToggle and ESPNotifyToggle.Object then ESPNotifyToggle.Object.Visible = cv end
			if Fisherman.Enabled then
				if cv then setupESP() else cleanupESP() end
			end
		end
	})

	ESPNotifyToggle = Fisherman:CreateToggle({
		Name = "Notify Loot",
		Default = true,
		Visible = false,
	})

	task.defer(function()
		local minigameOn = AutoMinigameToggle and AutoMinigameToggle.Enabled
		local randomOn = RandomizeToggle and RandomizeToggle.Enabled
		if Blacklist and Blacklist.Object then Blacklist.Object.Visible = BlacklistOption and BlacklistOption.Enabled or false end
		if AutoCastDelay and AutoCastDelay.Object then AutoCastDelay.Object.Visible = AutoCast and AutoCast.Enabled or false end
		if ESPNotifyToggle and ESPNotifyToggle.Object then ESPNotifyToggle.Object.Visible = ESPToggle and ESPToggle.Enabled or false end
		if PullAnimationToggle and PullAnimationToggle.Object then PullAnimationToggle.Object.Visible = minigameOn or false end
		if MinigameAnimationToggle and MinigameAnimationToggle.Object then MinigameAnimationToggle.Object.Visible = minigameOn or false end
		if RandomizeToggle and RandomizeToggle.Object then RandomizeToggle.Object.Visible = minigameOn or false end
		if RandomRange and RandomRange.Object then RandomRange.Object.Visible = (minigameOn and randomOn) or false end
		if CompleteDelaySlider and CompleteDelaySlider.Object then CompleteDelaySlider.Object.Visible = (minigameOn and not randomOn) or false end
	end)
end)

run(function()
	local CannonHandController = bedwars.CannonHandController
	local CannonController = bedwars.CannonController
	local oldLaunchSelf = CannonHandController.launchSelf
	local oldStopAiming = CannonController.stopAiming
	local oldStartAiming = CannonController.startAiming
	local AutoDavey
	local AutoDaveyAutojump
	local AutoDaveyAutoLaunch
	local AutoDaveyAutoBreak
	local AutoDaveyPickaxeCheck
	local AutoDaveyAutoSwitch
	local LaunchDelay
	local BreakDelay
	local isLaunching = false
	local didAutoLaunch = false

	local function getCannonSlot()
		for i, v in pairs(store.inventory.hotbar) do
			if v.item then
				local t = tostring(v.item.itemType):lower()
				if t:find("cannon") then
					return i - 1
				end
			end
		end
		return nil
	end

	local function hasWoodPickaxeOnly()
		local bestTier = 0
		for _, slot in pairs(store.inventory.hotbar) do
			if slot.item then
				local t = tostring(slot.item.itemType):lower()
				if t == "wood_pickaxe" and bestTier < 1 then
					bestTier = 1
				elseif (t:find("pickaxe") or t:find("drill")) and t ~= "wood_pickaxe" then
					bestTier = 2
				end
			end
		end
		return bestTier == 1
	end

	local function getNearestCannon()
		if not entitylib.isAlive then return nil end
		local nearest
		local nearestDist = math.huge
		for i, v in pairs(CannonController.getCannons()) do
			pcall(function()
				local dist = (v.Position - entitylib.character.RootPart.Position).Magnitude
				if dist < nearestDist and dist < 30 then
					nearestDist = dist
					nearest = v
				end
			end)
		end
		return nearest
	end

	local function findCannonModel(pos)
		local closest = nil
		local closestDist = 8
		for _, obj in store.blocks do
			if obj and obj:IsA("BasePart") and obj.Name == "cannon" then
				local dist = (obj.Position - pos).Magnitude
				if dist < closestDist then
					closestDist = dist
					closest = obj
				end
			end
		end
		return closest
	end

	local function doBreakCannon(cannon)
		if not entitylib.isAlive then return end
		if not cannon or not cannon.Parent then return end
		local block, blockpos = getPlacedBlock(cannon.Position)
		if block and block.Name == 'cannon' and
		   (entitylib.character.RootPart.Position - block.Position).Magnitude < 30 then
			pcall(bedwars.breakBlock, block, false, nil, true)
		else
			local directBlock = findCannonModel(cannon.Position)
			if directBlock and directBlock.Parent then
				pcall(bedwars.breakBlock, directBlock, false, nil, true)
			end
		end
	end

	local function firstHitCannon(cannon)
		if not entitylib.isAlive then return end
		if not cannon or not cannon.Parent then return end
		if hasWoodPickaxeOnly() then
			doBreakCannon(cannon)
		end
	end

	local function breakCannon(cannon, shootfunc)
		if not entitylib.isAlive then
			isLaunching = false
			return shootfunc()
		end

		local cannonSlot = nil

		if AutoDaveyAutoSwitch.Enabled and not isHoldingPickaxe() then
			local pickaxeSlot = getPickaxeSlot()
			if not pickaxeSlot then
				notif("AutoDavey", "No pickaxe found in hotbar!", 3)
				if AutoDaveyAutojump.Enabled and entitylib.isAlive and entitylib.character.Humanoid then
					entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end
				isLaunching = false
				return shootfunc()
			end
			cannonSlot = getCannonSlot()
			if hotbarSwitch(pickaxeSlot) then
				task.wait(0.05)
			end
		end

		if AutoDaveyPickaxeCheck.Enabled and not isHoldingPickaxe() then
			notif("AutoDavey", "You need to HOLD a pickaxe to break cannons!", 3)
			if AutoDaveyAutojump.Enabled and entitylib.isAlive and entitylib.character.Humanoid then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
			isLaunching = false
			return shootfunc()
		end

		if BreakDelay.Value > 0 then
			task.wait(BreakDelay.Value)
		end

		local cannonRef = cannon
		if AutoDaveyAutojump.Enabled and entitylib.isAlive and entitylib.character.Humanoid then
			entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
		shootfunc()
		isLaunching = false

		task.spawn(function()
			task.wait(0.05)
			doBreakCannon(cannonRef)
			task.wait(0.35)
			if cannonRef and cannonRef.Parent then
				doBreakCannon(cannonRef)
			end
			if AutoDaveyAutoSwitch.Enabled and cannonSlot then
				task.wait(0.05)
				hotbarSwitch(cannonSlot)
			end
		end)
	end

	AutoDavey = vape.Categories.Kits:CreateModule({
		Name = 'AutoDavey',
		Function = function(callback)
			if callback then
				CannonHandController.launchSelf = function(...)
					if isLaunching then
						isLaunching = false
						return oldLaunchSelf(...)
					end
					isLaunching = true
					if LaunchDelay.Value > 0 then
						task.wait(LaunchDelay.Value)
					end
					if AutoDaveyAutoBreak.Enabled then
						local cannon = getNearestCannon()
						if cannon then
							local args = {...}
							breakCannon(cannon, function()
								oldLaunchSelf(unpack(args))
							end)
							return
						else
							if AutoDaveyAutojump.Enabled and entitylib.isAlive and entitylib.character.Humanoid then
								entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
							end
							local res = oldLaunchSelf(...)
							isLaunching = false
							return res
						end
					else
						if AutoDaveyAutojump.Enabled and entitylib.isAlive and entitylib.character.Humanoid then
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
						local res = oldLaunchSelf(...)
						isLaunching = false
						return res
					end
				end

				local aimedCannon = nil
				CannonController.startAiming = function(...)
					didAutoLaunch = false
					isLaunching = false
					local result = oldStartAiming(...)
					aimedCannon = getNearestCannon()
					return result
				end

				CannonController.stopAiming = function(...)
					local cannon = aimedCannon or getNearestCannon()
					local result = oldStopAiming(...)
					aimedCannon = nil
					isLaunching = false
					if AutoDaveyAutoLaunch.Enabled and not didAutoLaunch then
						didAutoLaunch = true
						if AutoDaveyAutoBreak.Enabled and AutoDaveyPickaxeCheck.Enabled and not isHoldingPickaxe() and not AutoDaveyAutoSwitch.Enabled then
							notif("AutoDavey", "Hold a pickaxe to auto-break!", 3)
							return result
						end
						if cannon then
							task.spawn(function()
								pcall(CannonHandController.launchSelf, CannonHandController, cannon)
							end)
						end
					end
					return result
				end

				local firstHitDebounce = {}
				AutoDavey:Clean(workspace.DescendantAdded:Connect(function(obj)
					if not (obj:IsA("BasePart") and obj.Name == "cannon") then return end
					if firstHitDebounce[obj] then return end
					firstHitDebounce[obj] = true
					task.spawn(function()
						task.wait(0.5)
						if AutoDaveyAutoBreak.Enabled and hasWoodPickaxeOnly() then
							local dist = entitylib.isAlive
								and (entitylib.character.RootPart.Position - obj.Position).Magnitude
								or math.huge
							if dist < 20 and obj.Parent then
								firstHitCannon(obj)
							end
						end
						firstHitDebounce[obj] = nil
					end)
				end))
			else
				CannonHandController.launchSelf = oldLaunchSelf
				CannonController.stopAiming = oldStopAiming
				CannonController.startAiming = oldStartAiming
				isLaunching = false
				didAutoLaunch = false
			end
		end,
	})

	LaunchDelay = AutoDavey:CreateSlider({
		Name = 'Launch Delay',
		Min = 0,
		Max = 2,
		Default = 0,
		Decimal = 10,
		Suffix = 's',
	})
	BreakDelay = AutoDavey:CreateSlider({
		Name = 'Break Delay',
		Min = 0,
		Max = 2,
		Default = 0,
		Decimal = 10,
		Suffix = 's',
	})

	AutoDaveyAutojump = AutoDavey:CreateToggle({
		Name = 'Auto Jump',
		Default = true,
	})
	AutoDaveyAutoLaunch = AutoDavey:CreateToggle({
		Name = 'Auto Launch',
		Default = true,
		Tooltip = 'automatically lauches u after your done aiming'
	})
	AutoDaveyAutoBreak = AutoDavey:CreateToggle({
		Name = 'Auto Break',
		Default = true,
		Tooltip = 'auto breaks cannon when you lauch'
	})
	AutoDaveyPickaxeCheck = AutoDavey:CreateToggle({
		Name = 'Pickaxe Check',
		Default = true,
	})
	AutoDaveyAutoSwitch = AutoDavey:CreateToggle({
		Name = 'AutoSwitch Pickaxe',
		Default = false,
		Tooltip = 'switches to pickaxe when breaking thens switches back to cannon'
	})
end)

run(function()
	local KitESP
	local Notify
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
    local currentSize = 36
	Folder.Parent = vape.gui
	
	local ESPKits = {
		alchemist = {'alchemist_ingedients', 'thorns'},
		beekeeper = {'bee', 'bee'},
		bigman = {'treeOrb', 'natures_essence_1'},
		ghost_catcher = {'ghost', 'ghost_orb'},
		metal_detector = {'hidden-metal', 'iron'},
		sheep_herder = {'SheepModel', 'purple_hay_bale'},
		sorcerer = {'alchemy_crystal', 'wild_flower'},
		star_collector = {'stars', 'crit_star'},
		black_market_trader = {'shadow_coin', 'shadow_coin'},
		miner = {'petrified-player', 'large_rock'},
		trapper = {'snap_trap', 'snap_trap'},
		mage = {'ElementTome', 'mage_spellbook'},
	}
	local NONTaggedKits = {
		necromancer = {'Gravestone', true},
		battery = {'Open', true},
	}
	local DescendantKits = {
		['farmer_cletus'] = {
			{'carrot', 'carrot_seeds'},
			{'melon', 'melon_seeds'},
			{'pumpkin', 'pumpkin_seeds'},
		},
	}

	local function isMineOnMyTeam(part)
		local teamAttr = part:GetAttribute('Team') or part:GetAttribute('TeamId') or part:GetAttribute('TeamID')
		if teamAttr then
			local myTeam = lplr:GetAttribute('Team') or lplr:GetAttribute('TeamId') or lplr:GetAttribute('TeamID')
			if myTeam and tostring(teamAttr) == tostring(myTeam) then
				return true
			end
		end
		local placedBy = part:GetAttribute('PlacedByUserId')
		if placedBy then
			local player = playersService:GetPlayerByUserId(placedBy)
			if player then
				local myTeam = lplr:GetAttribute('Team')
				if myTeam and player:GetAttribute('Team') == myTeam then
					return true
				end
			end
		end
		return false
	end

	local function getAlchemistImage(v)
		local name = v and v.Name or ''
		if name == 'Mushrooms' then
			return bedwars.getIcon({itemType = 'mushrooms'}, true)
		elseif name == 'Thorns' then
			return bedwars.getIcon({itemType = 'thorns'}, true)
		else
			return bedwars.getIcon({itemType = 'wild_flower'}, true)
		end
	end

	local function getStarImage(v)
		local parent = v and v.Parent
		if parent and parent:IsA("Model") then
			local modelName = parent.Name
			if modelName == "CritStar" or modelName:lower():find("crit") then
				return bedwars.getIcon({itemType = 'crit_star'}, true)
			elseif modelName == "VitalityStar" or modelName:lower():find("vitality") then
				return bedwars.getIcon({itemType = 'vitality_star'}, true)
			end
		end
		return bedwars.getIcon({itemType = 'crit_star'}, true)
	end

	local function Added(v, icon, non)
		if Reference[v] then return end
		if Notify.Enabled then
			vape:CreateNotification("KitESP", `New object is added {v.Name}`, 2)
		end
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = icon
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(currentSize, currentSize)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.fromOffset(currentSize, currentSize)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		if non then
			image.Image = icon
		else
			image.Image = bedwars.getIcon({itemType = icon}, true)
		end
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[v] = billboard
	end

	local function AddedStar(v)
		if not v or not v.Parent then return end
		if Reference[v] then return end

		if Notify.Enabled then
			vape:CreateNotification("KitESP", `New object is added {v.Name}`, 2)
		end
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'star'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(currentSize, currentSize)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.fromOffset(currentSize, currentSize)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		image.Image = getStarImage(v)
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[v] = billboard
	end
	
	local currentConnections = {}
	local currentKit = nil

	local function disconnectAll()
		for _, conn in ipairs(currentConnections) do
			conn:Disconnect()
		end
		table.clear(currentConnections)
	end

	local function isRealBee(v)
		if not v then return false end

		local beeId = v:GetAttribute('BeeId')

		if beeId == nil then
			local part = v.PrimaryPart or v:FindFirstChildWhichIsA('BasePart', true)
			beeId = part and part:GetAttribute('BeeId')
		end

		return beeId ~= nil and beeId > -1
	end

	local function addKit(tag, icon)
		if tag == 'bee' then
			local beeIcon = bedwars.getIcon({itemType = 'bee'}, true)
			for _, tagName in {'bee', 'MeadowBee', 'ChromaBee'} do
				local connAdded = collectionService:GetInstanceAddedSignal(tagName):Connect(function(v)
					if v:IsA("Model") and v.PrimaryPart then
						task.wait(0.1)
						if isRealBee(v) then
							Added(v.PrimaryPart, beeIcon, true)
						end
					end
				end)
				table.insert(currentConnections, connAdded)
				local connRemoved = collectionService:GetInstanceRemovedSignal(tagName):Connect(function(v)
					if v.PrimaryPart and Reference[v.PrimaryPart] then
						Reference[v.PrimaryPart]:Destroy()
						Reference[v.PrimaryPart] = nil
					end
				end)
				table.insert(currentConnections, connRemoved)
				for _, v in collectionService:GetTagged(tagName) do
					if v:IsA("Model") and v.PrimaryPart and isRealBee(v) then
						Added(v.PrimaryPart, beeIcon, true)
					end
				end
			end
			return
		end
		if tag == 'alchemist_ingedients' then
			local connAdded = collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
				if v.PrimaryPart then
					task.wait(0.1)				for _, itemType in ItemList do
					addItem(itemType)
				end

				AutoBankV2:Clean(collectionService:GetInstanceAddedSignal('ItemDrop'):Connect(function(part)
					local asked = Pending[part.Name]
					local root = myRoot()
					if not asked or tick() - asked > 1.5 or not root or not part:IsA('BasePart') then return end
					if (part.Position - root.Position).Magnitude > 8 then return end
					Pending[part.Name] = nil
					bank(part)
				end))

				AutoBankV2:Clean(runService.PreSimulation:Connect(function()
					local root = myRoot()
					for part, spot in Banked do
						if part.Parent and part:IsDescendantOf(workspace) then
							part.AssemblyLinearVelocity = Vector3.zero
							part.CFrame = root and Returning and isReady(part) and root.CFrame * CFrame.new(0, -4.5, 0) or hiddenSpot(spot)
						else
							Banked[part] = nil
						end
					end
				end))

				local warnedSpectator = false
				local function step()
					if not AutoBankV2.Enabled or Session ~= current then return end
					if UI and UI.Visible then
						updateUI()
					end
					local spectated = Spectators.Enabled and getSpectator()
					if spectated and not warnedSpectator then
						warnedSpectator = true
						notif('AutoBankV2', 'someone is spectating u so autobank wont work till they leave', 6, 'warning')
					elseif not spectated then
						warnedSpectator = false
					end
					if not entitylib.isAlive or spectated then
						Returning = false
					elseif isNearShop() then
						Returning = true
						for part in Banked do
							giveBack(part)
						end
					else
						Returning = false
						if not isShopping() then
							dropItems(current)
						end
					end
				end

				AutoBankV2:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(function()
					task.defer(pcall, step)
				end))

				repeat
					pcall(step)
					task.wait(0.1)
				until not AutoBankV2.Enabled or Session ~= current
			else
				Session = nil
				table.clear(Items)
				table.clear(Pending)
				local started = tick()
				task.spawn(function()
					repeat
						if entitylib.isAlive then
							Returning = true
							for part, spot in Banked do
								if part.Parent then
									if not isReady(part) then
										part.AssemblyLinearVelocity = Vector3.zero
										part.CFrame = hiddenSpot(spot)
									end
									giveBack(part)
								else
									Banked[part] = nil
								end
							end
						end
						task.wait()
					until AutoBankV2.Enabled or not next(Banked) or tick() - started > 60
					Returning = false
				end)
			end
		end,
		Tooltip = 'hides ur loot somewhere safe when u leave base and gives it back when ur at ur shop'
	})
	UIToggle = AutoBankV2:CreateToggle({
		Name = 'UI',
		Function = function(callback)
			if UI then
				UI.Visible = callback
			end
		end,
		Default = true
	})
	for _, itemType in ItemList do
		local nice = itemType:gsub('_', ' '):gsub('^%l', string.upper)
		BankToggles[itemType] = AutoBankV2:CreateToggle({
			Name = 'Bank '..nice,
			Default = itemType == 'iron' or itemType == 'diamond' or itemType == 'emerald'
		})
	end
	TeamCheck = AutoBankV2:CreateToggle({
		Name = 'Team Check',
		Tooltip = 'only gives ur loot back at ur own base'
	})
	Spectators = AutoBankV2:CreateToggle({
		Name = 'Spectator Check',
		Tooltip = 'wont bank or give stuff back while an enemy is spectating'
	})
end)

run(function()
	local AutoKit
	local Legit
	local Targets
	local Toggles = {}
	local Running = {}
	local netFolder, abilityRemote

	local function getNet(name)
		if not netFolder then
			pcall(function()
				netFolder = replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged
			end)
		end
		return netFolder and netFolder:FindFirstChild(name)
	end

	local function useAbility(name, data)
		if not abilityRemote then
			pcall(function()
				abilityRemote = replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility
			end)
		end
		if abilityRemote then
			pcall(function()
				if data ~= nil then
					abilityRemote:FireServer(name, data)
				else
					abilityRemote:FireServer(name)
				end
			end)
		end
	end

	local function range(legit, blatant)
		return Legit.Enabled and legit or blatant
	end

	local function NewSession()
		local Session = {Tasks = {}, Active = true}

		function Session:Clean(Task)
			table.insert(self.Tasks, Task)
			return Task
		end

		function Session:Stop()
			self.Active = false
			if self.Thread and coroutine.status(self.Thread) ~= 'dead' then
				pcall(task.cancel, self.Thread)
			end
			for i = #self.Tasks, 1, -1 do
				local Task = self.Tasks[i]
				pcall(function()
					if type(Task) == 'function' then
						Task()
					elseif typeof(Task) == 'RBXScriptConnection' then
						Task:Disconnect()
					elseif typeof(Task) == 'Instance' then
						Task:Destroy()
					elseif type(Task) == 'table' then
						if Task.Disconnect then Task:Disconnect() elseif Task.Destroy then Task:Destroy() end
					end
				end)
			end
			table.clear(self.Tasks)
		end

		return Session
	end

	local function findTarget(dist, extra)
		if not entitylib.isAlive then return nil end
		local options = {
			Range = dist,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled or nil,
			Sort = sortmethods.Distance
		}
		for k, v in extra or {} do
			options[k] = v
		end
		return entitylib.EntityPosition(options)
	end

	local function KitCollection(Session, Tag, Range, Callback)
		local Objects = type(Tag) == 'table' and Tag or collection(Tag, Session)
		repeat
			if entitylib.isAlive then
				local here = entitylib.character.RootPart.Position
				for _, v in Objects do
					if not Session.Active then break end
					local part = typeof(v) == 'Instance' and (v:IsA('BasePart') and v or (v:IsA('Model') and (v.PrimaryPart or v:FindFirstChildWhichIsA('BasePart', true))))
					if part and part.Parent and (part.Position - here).Magnitude <= Range() then
						pcall(Callback, v, part)
					end
				end
			end
			task.wait(0.1)
		until not Session.Active
	end

	local function sameTeam(plr)
		local mine, theirs = lplr:GetAttribute('Team'), plr:GetAttribute('Team')
		if mine ~= nil and theirs ~= nil then
			return mine == theirs
		end
		return lplr.Team ~= nil and plr.Team == lplr.Team
	end

	local AutoKitFunctions = {
		trapper = function(Session)
			local traps = setmetatable({}, {__mode = 'k'})
			local nextBoom = 0
			local function isExplosive(trap)
				local kind = tostring(trap:GetAttribute('trapType') or trap:GetAttribute('TrapType') or trap:GetAttribute('Type') or ''):lower()
				return kind:find('explosive', 1, true) or trap.Name:lower():find('explosive', 1, true) or trap:FindFirstChild('explosive_trap', true)
			end
			local function isMine(trap)
				local owner = tonumber(trap:GetAttribute('PlacedByUserId') or trap:GetAttribute('OwnerUserId') or trap:GetAttribute('PlayerUserId') or trap:GetAttribute('ownerId'))
				if owner then return owner == lplr.UserId end
				local team = trap:GetAttribute('TrapperTeamId') or trap:GetAttribute('TeamId')
				return team ~= nil and tostring(team) == tostring(lplr:GetAttribute('Team'))
			end
			local function radiusOf(trap)
				for _, name in {'TriggerRadius', 'DetonationRadius', 'ExplosionRadius', 'ActivationRadius', 'Radius'} do
					local value = tonumber(trap:GetAttribute(name))
					if value and value > 0 then return value end
				end
				local best = 0
				for _, part in trap:GetDescendants() do
					if part:IsA('BasePart') then
						local name = part.Name:lower()
						if name:find('radius', 1, true) or name:find('range', 1, true) or name:find('circle', 1, true) or name:find('trigger', 1, true) or name:find('hitbox', 1, true) then
							best = math.max(best, math.max(part.Size.X, part.Size.Z) / 2)
						end
					end
				end
				return best > 0 and best or 8
			end
			local function track(trap)
				task.wait()
				if trap.Parent and isExplosive(trap) and isMine(trap) then
					traps[trap] = true
				end
			end
			Session:Clean(collectionService:GetInstanceAddedSignal('trapper_trap'):Connect(track))
			Session:Clean(collectionService:GetInstanceRemovedSignal('trapper_trap'):Connect(function(trap)
				traps[trap] = nil
			end))
			for _, trap in collectionService:GetTagged('trapper_trap') do
				task.spawn(track, trap)
			end
			repeat
				if tick() >= nextBoom then
					for trap in traps do
						local part = trap.Parent and (trap:IsA('BasePart') and trap or trap.PrimaryPart or trap:FindFirstChildWhichIsA('BasePart', true))
						if not part then
							traps[trap] = nil
							continue
						end
						local reach = radiusOf(trap)
						for _, plr in playersService:GetPlayers() do
							local root = plr ~= lplr and not sameTeam(plr) and plr.Character and plr.Character:FindFirstChild('HumanoidRootPart')
							local hum = root and plr.Character:FindFirstChildOfClass('Humanoid')
							if hum and hum.Health > 0 and (root.Position - part.Position).Magnitude <= reach then
								nextBoom = tick() + 0.25
								useAbility('trapper_detonate')
								break
							end
						end
						if tick() < nextBoom then break end
					end
				end
				task.wait(0.03)
			until not Session.Active
		end,

		jellyfish = function(Session)
			local jellies = collection('jellyfish', Session, function(list, obj)
				task.delay(0, function()
					if obj:GetAttribute('PlacedByUserId') == lplr.UserId then
						table.insert(list, obj)
					end
				end)
			end)
			repeat
				if entitylib.isAlive and bedwars.AbilityController:canUseAbility('electrify_jellyfish') then
					for _, jelly in jellies do
						if jelly.PrimaryPart and findTarget(range(14, 18), {Origin = jelly.PrimaryPart.Position, Wallcheck = nil}) then
							bedwars.AbilityController:useAbility('electrify_jellyfish')
							break
						end
					end
				end
				task.wait(0.1)
			until not Session.Active
		end,

		tinker = function(Session)
			local abilityNames = {
				'hephaestus_self_repair', 'tinker_self_repair', 'hephaestus_repair', 'tinker_repair',
				'HEPHAESTUS_SELF_REPAIR', 'TINKER_SELF_REPAIR', 'HEPHAESTUS_REPAIR', 'TINKER_REPAIR',
				'self_repair', 'SELF_REPAIR', 'shield_repair', 'SHIELD_REPAIR', 'kit_repair', 'KIT_REPAIR'
			}
			local repairingUntil = 0
			local function kitShield(char)
				local best = 0
				for name, value in char:GetAttributes() do
					if name:find('Shield') and type(value) == 'number' and value > best and name ~= 'Shield_POTION' and name ~= 'TotalShield' then
						best = value
					end
				end
				return best
			end
			local function repair()
				local names = table.clone(abilityNames)
				for _, obj in {lplr.Character, lplr} do
					if obj then
						for _, value in obj:GetAttributes() do
							if type(value) == 'string' and value:lower():find('repair') and not table.find(names, value) then
								table.insert(names, 1, value)
							end
						end
					end
				end
				for _, name in names do
					local ok, can = pcall(bedwars.AbilityController.canUseAbility, bedwars.AbilityController, name)
					if ok and can then
						pcall(bedwars.AbilityController.useAbility, bedwars.AbilityController, name)
						return true
					end
				end
				return false
			end
			local function attackUnlocked()
				return not Legit.Enabled and tick() < repairingUntil
			end
			local oldClicking = bedwars.SwordController.isClickingTooFast
			bedwars.SwordController.isClickingTooFast = function(self, ...)
				if attackUnlocked() then
					return false
				end
				return oldClicking(self, ...)
			end
			Session:Clean(function()
				bedwars.SwordController.isClickingTooFast = oldClicking
			end)
			local function watchStun(char)
				if not char then return end
				Session:Clean(char:GetAttributeChangedSignal('StunnedUntilTime'):Connect(function()
					local value = char:GetAttribute('StunnedUntilTime')
					if attackUnlocked() and value and value > workspace:GetServerTimeNow() then
						pcall(function() char:SetAttribute('StunnedUntilTime', 0) end)
					end
				end))
			end
			watchStun(lplr.Character)
			Session:Clean(lplr.CharacterAdded:Connect(watchStun))
			local maxShield, lastRepair, wasAlive = 0, 0, false
			repeat
				task.wait(0.1)
				local char = entitylib.isAlive and lplr.Character
				if not char then
					maxShield, wasAlive = 0, false
					continue
				end
				local current = kitShield(char)
				if not wasAlive or current > maxShield then
					maxShield = current
				end
				wasAlive = true
				if maxShield > 0 and current <= maxShield * 0.5 and tick() - lastRepair >= 6 and repair() then
					lastRepair = tick()
					repairingUntil = tick() + 2
				end
			until not Session.Active
		end,

		soul_broker = function(Session)
			local linked = {}
			repeat
				local ent = findTarget(range(14, 60))
				local count = 0
				for _ in linked do count += 1 end
				if ent and ent.Character and count < 8 and not linked[ent.Character] then
					local char = ent.Character
					useAbility('soul_link')
					task.wait(0.1)
					local remote = getNet('AttemptSoulLink')
					local ok, result = pcall(function() return remote:InvokeServer(char) end)
					if ok and type(result) == 'table' and result.result then
						linked[char] = true
						Session:Clean(char.AncestryChanged:Connect(function()
							if not char.Parent then linked[char] = nil end
						end))
					end
				end
				task.wait(0.3)
			until not Session.Active
		end,

		warrior = function(Session)
			repeat
				if (lplr:GetAttribute('Grit') or 0) >= 100 and findTarget(range(14, 40)) then
					useAbility('warrior_strike')
				end
				task.wait(0.1)
			until not Session.Active
		end,

		builder = function(Session)
			local fortified = {}
			local shapes = {}
			local function pyramid(size)
				if shapes[size] then return shapes[size] end
				local list = {}
				for h = size, 0, -1 do
					for w = h, 0, -1 do
						table.insert(list, Vector3.new(w, size - h, (h + 1) - w) * 3)
						table.insert(list, Vector3.new(-w, size - h, (h + 1) - w) * 3)
						table.insert(list, Vector3.new(w, size - h, -(h - w)) * 3)
						table.insert(list, Vector3.new(-w, size - h, -(h - w)) * 3)
					end
				end
				shapes[size] = list
				return list
			end
			repeat
				local team = lplr:GetAttribute('Team')
				local bedCFrame
				for _, bed in collectionService:GetTagged('bed') do
					if team and bed.Parent and bed:GetAttribute('Team' .. team .. 'NoBreak') then
						bedCFrame = bed:IsA('BasePart') and bed.CFrame or bed:GetPivot()
						break
					end
				end
				local remote = getNet('FortifyBlock')
				if bedCFrame and remote then
					for layer = 1, 3 do
						local sent = false
						for _, offset in pyramid(layer) do
							if not Session.Active then break end
							local block, rounded = getPlacedBlock((bedCFrame * CFrame.new(offset)).Position)
							if block and block.Name ~= 'bed' and fortified[tostring(rounded)] ~= block then
								pcall(function() remote:FireServer(rounded) end)
								fortified[tostring(rounded)] = block
								sent = true
								task.wait(0.05)
							end
						end
						if sent then break end
					end
				end
				task.wait(0.1)
			until not Session.Active
		end,

		dragon_slayer = function(Session)
			local controller = bedwars.DragonSlayerController
			local oldPunch = controller and controller.playPunchAnimation
			if oldPunch then
				controller.playPunchAnimation = function(self, look)
					if Legit.Enabled then
						return oldPunch(self, look)
					end
					local Maid = debug.getupvalue(oldPunch, 1)
					local AnimUtil = debug.getupvalue(oldPunch, 2)
					local Players = debug.getupvalue(oldPunch, 3)
					local AnimType = debug.getupvalue(oldPunch, 4)
					local Run = debug.getupvalue(oldPunch, 6)
					local maid = Maid.new()
					local track = AnimUtil:playAnimation(Players.LocalPlayer, AnimType.DRAGON_SLAYER_PUNCH)
					maid:GiveTask(function()
						if track then track:Stop() end
					end)
					maid:GiveTask(Run.Heartbeat:Connect(function()
						local char = Players.LocalPlayer.Character
						if not (char and char.PrimaryPart) then
							maid:DoCleaning()
							return
						end
						char:PivotTo(CFrame.new(char:GetPrimaryPartCFrame().Position) * look)
					end))
					task.delay(0.46, function()
						maid:DoCleaning()
					end)
					return maid
				end
				Session:Clean(function()
					controller.playPunchAnimation = oldPunch
				end)
			end
			local cooldown = {}
			repeat
				local punched = false
				if entitylib.isAlive and controller and controller.dragonEmblems then
					local here = entitylib.character.RootPart.Position
					local list = {}
					for model, emblem in controller.dragonEmblems do
						if emblem.stackCount >= 3 and model.PrimaryPart and (here - model.PrimaryPart.Position).Magnitude <= range(14, 18) then
							table.insert(list, model)
						end
					end
					table.sort(list, function(a, b)
						return (here - a.PrimaryPart.Position).Magnitude < (here - b.PrimaryPart.Position).Magnitude
					end)
					for _, model in list do
						if not Session.Active then break end
						if not cooldown[model] and bedwars.AbilityController:canUseAbility('dragon_slayer_punch', {disableBlockedAbilityAlert = true}) then
							if Legit.Enabled then
								task.wait(1)
							end
							cooldown[model] = true
							task.delay(0.4, function() cooldown[model] = nil end)
							local char = lplr.Character
							if char and char.PrimaryPart and model.PrimaryPart then
								local from = char:GetPivot().Position
								local look = CFrame.new(from, model.PrimaryPart.Position * Vector3.new(1, 0, 1) + Vector3.new(0, from.Y, 0))
								char:PivotTo(look)
								pcall(function() controller:playPunchAnimation(look - look.Position) end)
								useAbility('dragon_slayer_punch')
								punched = true
								task.wait(0.2)
							end
						end
					end
				end
				task.wait(punched and 0.15 or 0.1)
			until not Session.Active
		end,

		spirit_gardener = function(Session)
			local gardener = bedwars.SpiritGardenerController
			local oldCharge = gardener and gardener.disableActionsOnCharge
			if oldCharge then
				gardener.disableActionsOnCharge = function(self, maid, character)
					if Legit.Enabled or character ~= lplr.Character then
						return oldCharge(self, maid, character)
					end
					local Knit = bedwars.KnitClient
					Knit.Controllers.SwordController:toggleSwordSwing(true)
					Knit.Controllers.BlockPlacementController:disableBlockPlacer()
					local SyncEvents = debug.getupvalue(oldCharge, 3)
					local block = SyncEvents.BeginProjectileTargeting:connect(function(event)
						event:setCancelled(true)
					end)
					local jump = Knit.Controllers.JumpHeightController:getJumpModifier():addModifier({jumpHeightMultiplier = 0})
					maid:GiveTask(function()
						Knit.Controllers.SwordController:toggleSwordSwing(false)
						Knit.Controllers.BlockPlacementController:enableBlockPlacer()
						block:Destroy()
						jump.Destroy()
					end)
				end
				Session:Clean(function()
					gardener.disableActionsOnCharge = oldCharge
				end)
			end
			local seeds = bedwars.SpiritGardenerSeedController
			local oldPickup = seeds and seeds.checkForPickup
			if oldPickup then
				seeds.checkForPickup = function(self)
					local char = lplr.Character
					if not char or not char.PrimaryPart then return nil end
					local here = char.PrimaryPart.Position
					for _, kind in self:validCollectableEntityTypes() do
						for _, orb in collectionService:GetTagged(kind) do
							local spawned = orb:GetAttribute('SpawnTime')
							if spawned and workspace:GetServerTimeNow() - spawned >= 1 and (here - orb:GetPivot().Position).Magnitude <= 12 then
								self:collectEntity(lplr, orb, kind)
							end
						end
					end
				end
				Session:Clean(function()
					seeds.checkForPickup = oldPickup
				end)
				pcall(function() seeds:listenToPickup() end)
			end
			repeat
				local watered = false
				if entitylib.isAlive then
					local here = entitylib.character.RootPart.Position
					for _, flower in collectionService:GetTagged('SpiritGardenerFlower') do
						if flower:IsA('Model') and flower.PrimaryPart and flower:GetAttribute('PlacedByUserId') == lplr.UserId and not flower:GetAttribute('HasFullyGrown') and (here - flower.PrimaryPart.Position).Magnitude <= range(14, 20) then
							useAbility('spirit_gardener_water')
							watered = true
							break
						end
					end
				end
				task.wait(watered and 0.6 or 0.5)
			until not Session.Active
		end,

		hannah = function(Session)
			KitCollection(Session, 'HannahExecuteInteraction', function() return range(14, 16) end, function(victim, part)
				if not Legit.Enabled and isAboveVoid(part.Position) then return end
				local remote = bedwars.Client:Get(remotes.HannahPromptTrigger).instance
				if remote:InvokeServer({user = lplr, victimEntity = victim}) then
					local icon = victim:FindFirstChild('Hannah Execution Icon')
					if icon then icon:Destroy() end
				end
				task.wait(0.05)
			end)
		end,

		mimic = function(Session)
			repeat
				if entitylib.isAlive and Targets.Players.Enabled then
					local here = entitylib.character.RootPart.Position
					for _, ent in entitylib.List do
						if not Session.Active then break end
						if ent.Targetable and ent.Player and ent.Character and ent.RootPart and (ent.RootPart.Position - here).Magnitude <= range(14, 18) and collectionService:HasTag(ent.Character, 'MimicBLockPickPocketPlayer') then
							if not Targets.Walls.Enabled or not entitylib.Wallcheck(here, ent.RootPart.Position, true, ent) then
								pcall(function()
									bedwars.Client:Get(remotes.MimicBlockPickPocketPlayer).instance:InvokeServer(ent.Player)
								end)
								task.wait(0.5)
							end
						end
					end
				end
				task.wait(0.1)
			until not Session.Active
		end,

		spirit_assassin = function(Session)
			KitCollection(Session, 'EvelynnSoul', function() return range(14, 150) end, function(spirit)
				bedwars.SpiritAssassinController:useSpirit(lplr, spirit)
				task.wait(0.1)
			end)
		end,

		void_dragon = function(Session)
			local dragon = bedwars.VoidDragonController
			local oldFlap = dragon and dragon.flapWings
			if oldFlap then
				dragon.flapWings = function(self, ...)
					local result = oldFlap(self, ...)
					if not Legit.Enabled and result ~= false and self.inDragonForm then
						self.SpeedMaid:GiveTask(bedwars.SprintController:getMovementStatusModifier():addModifier({
							blockSprint = true,
							constantSpeedMultiplier = 2
						}))
					end
					return result
				end
				Session:Clean(function()
					dragon.flapWings = oldFlap
				end)
			end
			repeat
				if dragon and dragon.inDragonForm and findTarget(range(14, 60)) then
					local remote = getNet('DragonBreath')
					if remote then
						pcall(function() remote:FireServer({player = lplr}) end)
					end
					task.wait(1)
				end
				task.wait(0.1)
			until not Session.Active
		end,

		cactus = function(Session)
			repeat
				if bedwars.AbilityController:canUseAbility('cactus_fire') and findTarget(range(14, 40)) then
					pcall(function() bedwars.AbilityController:useAbility('cactus_fire') end)
					task.wait(0.5)
				end
				task.wait(0.1)
			until not Session.Active
		end,

		card = function(Session)
			repeat
				if bedwars.AbilityController:canUseAbility('CARD_THROW') then
					local ent = findTarget(12)
					if ent and ent.Character then
						useAbility('CARD_THROW', {targetEntityInstance = ent.Character})
						task.wait(0.5)
					end
				end
				task.wait(0.1)
			until not Session.Active
		end,

		mage = function(Session)
			KitCollection(Session, 'ElementTome', function() return range(14, 30) end, function(tome)
				local secret = tome:GetAttribute('TomeSecret')
				if not secret then return end
				pcall(function() bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.PUNCH) end)
				pcall(function() bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM) end)
				local result = bedwars.Client:Get(remotes.LearnElementTome).instance:InvokeServer({secret = secret})
				if type(result) == 'table' and result.success then
					tome:Destroy()
					task.wait(0.5)
				end
			end)
		end,

		warlock = function(Session)
			local last
			repeat
				if entitylib.isAlive and store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
					local dist = range(10, 20)
					if last then
						local hum = last:FindFirstChildOfClass('Humanoid')
						local root = last:FindFirstChild('HumanoidRootPart')
						if not last.Parent or not hum or hum.Health <= 0 or not root or (root.Position - entitylib.character.RootPart.Position).Magnitude > dist then
							last = nil
						end
					end
					if not last then
						local ent = findTarget(dist)
						if ent and ent.Character then
							last = ent.Character
							pcall(function() bedwars.AbilityController:useAbility('WARLOCK_LINK') end)
							task.wait(0.1)
							pcall(function() bedwars.Client:Get(remotes.WarlockTarget):CallServer({target = last}) end)
						end
					end
				else
					last = nil
				end
				task.wait(0.3)
			until not Session.Active
		end,

		drill = function(Session)
			local useDrill, drillAttack = getNet('PlayerUseDrillController'), getNet('DrillAttack')
			local lastShot = 0
			local function release()
				pcall(function()
					local Knit = bedwars.KnitClient
					local tablet = Knit.Controllers.DrillTabletController
					if tablet then
						if tablet.sessionMaid then tablet.sessionMaid:DoCleaning() end
						tablet.enabled = false
						tablet.lastAttackTime = 0
					end
					local item = Knit.Controllers.DrillItemController
					if item and item.sessionMaid then item.sessionMaid:DoCleaning() end
					gameCamera.CameraSubject = entitylib.character and entitylib.character.Humanoid or gameCamera.CameraSubject
					gameCamera.CameraType = Enum.CameraType.Custom
				end)
			end
			local drills = {}
			for _, obj in workspace:GetDescendants() do
				if obj:IsA('Model') and obj.Name == 'Drill' then drills[obj] = true end
			end
			Session:Clean(workspace.DescendantAdded:Connect(function(obj)
				if obj:IsA('Model') and obj.Name == 'Drill' then drills[obj] = true end
			end))
			repeat
				local acted = false
				if entitylib.isAlive and useDrill and drillAttack and tick() - lastShot >= 0.3 then
					for drill in drills do
						if not drill.Parent then
							drills[drill] = nil
							continue
						end
						if drill:GetAttribute('PlacedByUserId') == lplr.UserId then
							local head = drill:FindFirstChild('Head') or drill.PrimaryPart or drill:FindFirstChildWhichIsA('BasePart')
							local ent = head and findTarget(range(14, 18), {Origin = head.Position})
							if ent and ent.RootPart then
								pcall(function() useDrill:InvokeServer({drill = drill}) end)
								release()
								pcall(function() drillAttack:FireServer({targetPosition = ent.RootPart.Position}) end)
								pcall(function() useDrill:InvokeServer({}) end)
								release()
								lastShot = tick()
								acted = true
								break
							end
						end
					end
				end
				task.wait(acted and 0.05 or 0.15)
			until not Session.Active
		end,

		ghost_catcher = function(Session)
			KitCollection(Session, 'ghost', function() return range(14, 30) end, function(ghost)
				if Legit.Enabled and not isHoldingItem({'vacuum'}) then return end
				local id = ghost:GetAttribute('Id') or ghost:GetAttribute('id') or ghost:GetAttribute('CollectableId') or tonumber(ghost.Name:match('%d+'))
				local remote = getNet('CollectCollectableEntity')
				if id and remote then
					remote:FireServer({id = id})
					task.wait(0.1)
				end
			end)
		end,

		rebellion_leader = function(Session)
			repeat
				local hum = entitylib.isAlive and entitylib.character.Humanoid
				if hum and hum.MaxHealth > 0 and hum.Health / hum.MaxHealth <= 0.5 then
					useAbility('rebellion_shield')
					if lplr:GetAttribute('LeaderAuraType') ~= 'healing' then
						useAbility('rebellion_aura_swap')
					end
				end
				task.wait(0.1)
			until not Session.Active
		end,

		miner = function(Session)
			KitCollection(Session, 'petrified-player', function() return range(6, 10) end, function(rock)
				local id = rock:GetAttribute('PetrifyId') or rock:GetAttribute('petrifyId')
				if id then
					bedwars.Client:Get(remotes.DestroyPetrifiedPlayer):SendToServer({petrifyId = id})
				end
			end)
		end,

		dragon_sword = function(Session)
			repeat
				local ent = findTarget(range(14, 18))
				local remote = getNet('DragonSwordFire')
				if ent and ent.Character and remote then
					pcall(function() remote:FireServer({target = ent.Character}) end)
					task.wait(0.5)
				end
				task.wait(0.1)
			until not Session.Active
		end,

		ice_queen = function(Session)
			repeat
				if entitylib.isAlive then
					local here = entitylib.character.RootPart.Position
					for _, ent in entitylib.List do
						local allowed = ent.Player and Targets.Players.Enabled or not ent.Player and Targets.NPCs.Enabled
						if allowed and ent.Targetable and ent.Character and ent.RootPart and (ent.RootPart.Position - here).Magnitude <= range(14, 60) and (ent.Character:GetAttribute('IceQueenStacks') or 0) >= 4 then
							if not Targets.Walls.Enabled or not entitylib.Wallcheck(here, ent.RootPart.Position, true, ent) then
								useAbility('ice_queen')
								task.wait(0.5)
								break
							end
						end
					end
				end
				task.wait(0.1)
			until not Session.Active
		end,

		styx = function(Session)
			local entrance, exit = nil, ''
			local function enemyClose()
				if not entitylib.isAlive then return false end
				local here = entitylib.character.RootPart.Position
				for _, ent in entitylib.List do
					if ent.Targetable and ent.RootPart and (ent.RootPart.Position - here).Magnitude <= 10 then
						return true
					end
				end
				return false
			end
			Session:Clean(bedwars.Client:Get(remotes.StyxSpawnEntrancePortal):Connect(function(data)
				if data.entrancePortalData.player == lplr then
					entrance = data.entrancePortalData
				end
			end))
			Session:Clean(bedwars.Client:Get(remotes.StyxSpawnExitPortal):Connect(function(data)
				exit = data.exitPortalData.uuid
				task.spawn(function()
					repeat task.wait(0.1) until not Session.Active or enemyClose()
					if Session.Active and exit ~= '' then
						pcall(function() getNet('StyxTryOpenExitPortalFromClient'):InvokeServer(exit) end)
					end
				end)
			end))
			Session:Clean(bedwars.Client:Get(remotes.StyxExitPortal):Connect(function()
				if entrance then
					task.wait(0.1)
					bedwars.Client:Get(remotes.StyxPortal):SendToServer({entrancePortalData = entrance})
				end
			end))
		end,

		sorcerer = function(Session)
			KitCollection(Session, 'alchemy_crystal', function() return 10 end, function(crystal)
				local id = crystal:GetAttribute('Id') or crystal:GetAttribute('id') or crystal:GetAttribute('CollectableId') or tonumber(crystal.Name:match('%d+'))
				local remote = getNet('CollectCollectableEntity')
				if id and remote then
					pcall(function() bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH) end)
					pcall(function() bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM) end)
					remote:FireServer({id = id, collectableName = 'AlchemyCrystal'})
					task.wait(0.1)
				end
			end)
		end,

		hatter = function(Session)
			local app = lplr.PlayerGui:WaitForChild('NotificationApp', 10)
			if not app or not Session.Active then return end
			Session:Clean(app.DescendantAdded:Connect(function(obj)
				if obj:IsA('TextLabel') and obj.Text:lower():find('teleport') then
					task.spawn(function()
						task.wait(0.05)
						for _ = 1, 10 do
							if not Session.Active then break end
							if bedwars.AbilityController:canUseAbility('HATTER_TELEPORT') then
								bedwars.AbilityController:useAbility('HATTER_TELEPORT')
								break
							end
							task.wait(0.05)
						end
					end)
				end
			end))
		end,

		necromancer = function(Session)
			KitCollection(Session, 'Gravestone', function() return range(12, 40) end, function(grave)
				local secret = grave:GetAttribute('GravestoneSecret')
				if not secret then return end
				local result = bedwars.Client:Get(remotes.ActivateGravestone).instance:InvokeServer({
					skeletonData = {
						armorType = grave:GetAttribute('ArmorType'),
						weaponType = grave:GetAttribute('SwordType'),
						associatedPlayerUserId = grave:GetAttribute('GravestonePlayerUserId')
					},
					secret = secret,
					position = grave:GetAttribute('GravestonePosition')
				})
				if type(result) == 'table' and result.success then
					local controller = bedwars.Knit.Controllers.NecromancerController
					if controller then
						pcall(function() controller:useGravestone(lplr, grave) end)
					end
				end
				task.wait(0.1)
			end)
		end,

		midnight = function(Session)
			repeat
				if bedwars.AbilityController:canUseAbility('midnight') and findTarget(range(14, 40)) then
					pcall(function() bedwars.AbilityController:useAbility('midnight') end)
					task.wait(0.5)
				end
				task.wait(0.1)
			until not Session.Active
		end,

		defender = function(Session)
			repeat
				local controller = entitylib.isAlive and bedwars.Knit.Controllers.DefenderKitController
				if controller and controller.currentSchematic then
					for blockPos, blockType in controller.currentSchematic do
						if not Session.Active or not entitylib.isAlive then break end
						pcall(function()
							local mode = bedwars.Store:getState().Kit.defenderScannerMode
							if mode == 'upgrade' then
								controller:requestScannerAction(blockPos, 'upgrade', blockType)
							elseif mode == 'refund' then
								controller:requestScannerAction(blockPos, 'refund')
							else
								controller:requestPlaceDefenderBlock(blockPos)
							end
						end)
						task.wait(0.05)
					end
				end
				task.wait(0.1)
			until not Session.Active
		end,

		block_kicker = function(Session)
			repeat
				if entitylib.isAlive then
					local blocks = (lplr.Character and lplr.Character:GetAttribute('BlockKickerKit_BlockCount')) or lplr:GetAttribute('BlockKickerKit_BlockCount') or 0
					if blocks <= 0 and bedwars.AbilityController:canUseAbility('BLOCK_STOMP') then
						pcall(function() bedwars.AbilityController:useAbility('BLOCK_STOMP') end)
						task.wait(0.8)
					end
				end
				task.wait(0.1)
			until not Session.Active