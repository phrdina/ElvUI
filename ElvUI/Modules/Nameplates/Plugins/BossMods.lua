local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local NP = E:GetModule('NamePlates')

local _G = _G
local wipe = wipe
local next = next
local floor = floor
local pairs = pairs
local unpack = unpack
local GetTime = GetTime
local UnitGUID = UnitGUID
local CreateFrame = CreateFrame

NP.BossMods_ActiveUnitGUID = {}

--[=[
	function NP:TestBossMods()
		local target = UnitGUID('target')
		if not target then return end

		NP:BossMods_AddIcon(target, 537100, 10, false)
		NP:BossMods_AddIcon(target, 656551, 200, false)
	end
	E:RegisterChatCommand('testbossmods', NP.TestBossMods)

	/run ElvUI[1].NamePlates:BossMods_AddIcon(UnitGUID('target'), 537100, 10, false)
	/run ElvUI[1].NamePlates:BossMods_AddIcon(UnitGUID('target'), 656551, 200, false)

	/run ElvUI[1].NamePlates:BossMods_RemoveIcon(UnitGUID('target'), 537100, true)
	/run ElvUI[1].NamePlates:BossMods_RemoveIcon(UnitGUID('target'), 656551, true)
]=]

local allowHostile, allowAuras = false -- true to test
function NP:BossMods_CreateIcon(element)
	element.index = not element.index and 1 or (element.index + 1)

	local button = CreateFrame('Button', element:GetName()..'Button'..element.index, element)
	button:EnableMouse(false)
	button:SetTemplate()

	local cooldown = CreateFrame('Cooldown', '$parentCooldown', button, 'CooldownFrameTemplate')
	cooldown:SetReverse(true)
	cooldown:SetInside(button)
	cooldown.CooldownOverride = 'nameplates'
	E:RegisterCooldown(cooldown)

	local icon = button:CreateTexture(nil, 'ARTWORK')
	icon:SetTexCoord(unpack(E.TexCoords))
	icon:SetInside()

	button.icon = icon
	button.cd = cooldown

	return button
end

function NP:BossMods_GetIcon(plate, texture)
	local element, unused, avaiableIcon = plate.BossMods

	local activeButton = element.activeIcons[texture]
	if not activeButton then
		unused, avaiableIcon = next(element.unusedIcons)
		if unused then element.unusedIcons[unused] = nil end
	end

	local button = activeButton or avaiableIcon or NP:BossMods_CreateIcon(element)
	if not activeButton then
		element.activeIcons[texture] = button
	end

	return button
end

function NP:BossMods_PositionIcons(element)
	if not next(element.activeIcons) then return end

	local holder = element.centerHolder
	local anchor = element.initialAnchor
	local size = element.size + element.spacing
	local growthX = (element.growthX == 'LEFT' and -1) or 1
	local growthY = (element.growthY == 'DOWN' and -1) or 1
	local cols = floor(element:GetWidth() / size + 0.5)

	local i, center = 1, anchor == 'TOP' or anchor == 'BOTTOM'
	for _, button in pairs(element.activeIcons) do
		local z = i - 1
		local col = z % cols
		local row = floor(z / cols)

		local point = center and ((growthY == 1 and 'BOTTOM' or 'TOP')..(growthX == 1 and 'LEFT' or 'RIGHT')) or anchor

		button:ClearAllPoints()
		button:SetPoint(point, (center and holder) or element, point, col * size * growthX, row * size * growthY)
		button:SetSize(element.size, element.size)
		button:Show()

		i = i + 1
	end

	if center then
		local z = i - 1
		holder:ClearAllPoints()
		holder:SetPoint(anchor)
		holder:SetSize((z < cols and z or cols) * size, element.size)
	end
end

function NP:BossMods_ClearIcon(plate, texture)
	local element = plate.BossMods
	local button = element.activeIcons[texture]
	if not button then return end

	button:Hide()

	element.activeIcons[texture] = nil
	element.unusedIcons[texture] = button
end

function NP:BossMods_TrackIcons(track, unitGUID, texture, duration, desaturate, startTime)
	if track then
		if not NP.BossMods_ActiveUnitGUID[unitGUID] then
			NP.BossMods_ActiveUnitGUID[unitGUID] = {}
		end

		local active = NP.BossMods_ActiveUnitGUID[unitGUID]
		if not active[texture] then
			active[texture] = {}
		end

		local activeTexture = active[texture]
		activeTexture.duration = duration
		activeTexture.desaturate = desaturate
		activeTexture.startTime = startTime
	else
		local active = NP.BossMods_ActiveUnitGUID[unitGUID]
		if active then
			if active[texture] then
				active[texture] = nil
			end

			if not next(active) then
				NP.BossMods_ActiveUnitGUID[unitGUID] = nil
			end
		end
	end
end

function NP:BossMods_AddIcon(unitGUID, texture, duration, desaturate)
	local active = NP.BossMods_ActiveUnitGUID[unitGUID]
	local activeTexture = active and active[texture]

	local pastTime = activeTexture and activeTexture.startTime
	local pastDuration = activeTexture and activeTexture.duration
	if pastTime and pastDuration and pastDuration ~= duration then
		pastTime = nil -- reset the cooldown timer if a new duration is given
	end

	local startTime = duration and (pastTime or GetTime()) or nil
	NP:BossMods_TrackIcons(true, unitGUID, texture, duration, desaturate, startTime)

	local plate = NP.PlateGUID[unitGUID]
	if not plate then return end

	-- print('AddIcon')

	local button = NP:BossMods_GetIcon(plate, texture)
	button.icon:SetDesaturated(desaturate)
	button.icon:SetTexture(texture)

	if duration then
		button.cd:SetCooldown(startTime, duration)
	else
		button.cd:Hide()
	end

	if desaturate then
		button:SetBackdropBorderColor(unpack(E.media.bordercolor))
	else
		local color = _G.DebuffTypeColor.none
		button:SetBackdropBorderColor(color.r * 0.6, color.g * 0.6, color.b * 0.6)
	end

	NP:BossMods_PositionIcons(plate.BossMods)
end

function NP:BossMods_RemoveIcon(unitGUID, texture, untrack)
	local plate = NP.PlateGUID[unitGUID]
	if plate then NP:BossMods_ClearIcon(plate, texture) end

	if untrack then
		NP:BossMods_TrackIcons(false, unitGUID, texture)
		NP:BossMods_PositionIcons(plate.BossMods)
	end
end

function NP:BossMods_UpdateIcon(plate, removed)
	local unitGUID = plate.unitGUID
	local active = NP.BossMods_ActiveUnitGUID[unitGUID]

	if not active then
		local element = plate.BossMods
		if next(element.activeIcons) then
			for texture in pairs(element.activeIcons) do
				NP:BossMods_ClearIcon(plate, texture)
			end
		end

		return
	end

	local enabled = allowHostile and allowAuras
	for texture, info in pairs(active) do
		if removed or not enabled then
			NP:BossMods_RemoveIcon(unitGUID, texture)
		elseif enabled then
			NP:BossMods_AddIcon(unitGUID, texture, info.duration, info.desaturate, info.expiration)
		end
	end
end

function NP:BossMods_ShowNameplateAura(_, isGUID, unit, texture, duration, desaturate)
	if not (allowHostile and allowAuras) then return end

	local unitGUID = (isGUID and unit) or UnitGUID(unit)
	NP:BossMods_AddIcon(unitGUID, texture, duration, desaturate)
end

function NP:BossMods_HideNameplateAura(_, isGUID, unit, texture)
	local unitGUID = (isGUID and unit) or UnitGUID(unit)
	NP:BossMods_RemoveIcon(unitGUID, texture, true)
end

function NP:BossMods_AddNameplateIcon(_, unitGUID, texture, duration, desaturate)
	if not (allowHostile and allowAuras) then return end

	NP:BossMods_AddIcon(unitGUID, texture, duration, desaturate)
end

function NP:BossMods_RemoveNameplateIcon(_, unitGUID, texture)
	NP:BossMods_RemoveIcon(unitGUID, texture, true)
end

function NP:BossMods_DisableHostileNameplates()
	for unitGUID, textures in pairs(NP.BossMods_ActiveUnitGUID) do
		for texture in pairs(textures) do
			local plate = NP.PlateGUID[unitGUID]
			if plate then
				NP:BossMods_ClearIcon(plate, texture)
			end
		end
	end

	wipe(NP.BossMods_ActiveUnitGUID)

	allowHostile = false
	-- print('disabled')
end

function NP:BossMods_EnableHostileNameplates()
	-- print('enabled')
	allowHostile = true
end

function NP:DBM_SupportedNPMod()
	return _G.DBM.Options.UseNameplateHandoff
end

function NP:BossMods_RegisterCallbacks()
	local DBM = _G.DBM
	if DBM and DBM.RegisterCallback and DBM.Nameplate then
		-- print('registered DBM')

		DBM.Nameplate.SupportedNPMod = NP.DBM_SupportedNPMod

		DBM:RegisterCallback('BossMod_ShowNameplateAura',NP.BossMods_ShowNameplateAura)
		DBM:RegisterCallback('BossMod_HideNameplateAura',NP.BossMods_HideNameplateAura)
		DBM:RegisterCallback('BossMod_EnableHostileNameplates',NP.BossMods_EnableHostileNameplates)
		DBM:RegisterCallback('BossMod_DisableHostileNameplates',NP.BossMods_DisableHostileNameplates)
	end

	local BWL = _G.BigWigsLoader
	if BWL and BWL.RegisterMessage then
		-- print('registered BW')

		BWL.RegisterMessage(NP,'BigWigs_AddNameplateIcon',NP.BossMods_AddNameplateIcon)
		BWL.RegisterMessage(NP,'BigWigs_RemoveNameplateIcon',NP.BossMods_RemoveNameplateIcon)
		BWL.RegisterMessage(NP,'BigWigs_EnableHostileNameplates',NP.BossMods_EnableHostileNameplates)
		BWL.RegisterMessage(NP,'BigWigs_DisableHostileNameplates',NP.BossMods_DisableHostileNameplates)
	end
end

function NP:Update_BossMods(plate)
	local db = NP.db.bossMods

	allowAuras = db.enable
	if not db.enable then return end

	local element = plate.BossMods
	element:ClearAllPoints()
	element:SetPoint(E.InversePoints[db.anchorPoint] or 'TOPRIGHT', plate, db.anchorPoint or 'TOPRIGHT', db.xOffset, db.yOffset)
	element:SetSize(plate.width or 150, db.size)

	element.initialAnchor = E.InversePoints[db.anchorPoint]
	element.spacing = db.spacing
	element.growthY = db.growthY
	element.growthX = db.growthX
	element.size = db.size
end

function NP:Construct_BossMods(nameplate)
	local element = CreateFrame('Frame', '$parentBossMods', nameplate)
	element.centerHolder = CreateFrame('Frame', '$parentCenterHolder', element)

	element.activeIcons = {}
	element.unusedIcons = {}

	return element
end