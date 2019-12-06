local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local B = E:GetModule('Blizzard')

--Lua functions
local _G = _G
local floor = floor
local format = format
--WoW API / Variables
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local UnitAlternatePowerInfo = UnitAlternatePowerInfo
local UnitPowerMax = UnitPowerMax
local UnitPower = UnitPower

local function updateTooltip(self)
	if _G.GameTooltip:IsForbidden() then return end

	if self.powerName and self.powerTooltip then
		_G.GameTooltip:SetText(self.powerName, 1, 1, 1)
		_G.GameTooltip:AddLine(self.powerTooltip, nil, nil, nil, 1)
		_G.GameTooltip:Show()
	end
end

local function onEnter(self)
	if (not self:IsVisible()) or _G.GameTooltip:IsForbidden() then return end

	_G.GameTooltip:ClearAllPoints()
	_G.GameTooltip_SetDefaultAnchor(_G.GameTooltip, self)
	updateTooltip(self)
end

local function onLeave()
	_G.GameTooltip:Hide()
end

function B:SetAltPowerBarText(text, name, value, max, percent)
	local textFormat = E.db.general.altPowerBar.textFormat
	if textFormat == 'NONE' or not textFormat then
		text:SetText('')
	elseif textFormat == 'NAME' then
		text:SetText(format('%s', name))
	elseif textFormat == 'NAMEPERC' then
		text:SetText(format('%s: %s%%', name, percent))
	elseif textFormat == 'NAMECURMAX' then
		text:SetText(format('%s: %s / %s', name, value, max))
	elseif textFormat == 'NAMECURMAXPERC' then
		text:SetText(format('%s: %s / %s - %s%%', name, value, max, percent))
	elseif textFormat == 'PERCENT' then
		text:SetText(format('%s%%', percent))
	elseif textFormat == 'CURMAX' then
		text:SetText(format('%s / %s', value, max))
	elseif textFormat == 'CURMAXPERC' then
		text:SetText(format('%s / %s - %s%%', value, max, percent))
	end
end

function B:PositionAltPowerBar()
	local holder = CreateFrame('Frame', 'AltPowerBarHolder', E.UIParent)
	holder:Point('TOP', E.UIParent, 'TOP', 0, -18)
	holder:Size(128, 50)

	_G.PlayerPowerBarAlt:ClearAllPoints()
	_G.PlayerPowerBarAlt:Point('CENTER', holder, 'CENTER')
	_G.PlayerPowerBarAlt:SetParent(holder)
	_G.PlayerPowerBarAlt.ignoreFramePositionManager = true

	--The Blizzard function FramePositionDelegate:UIParentManageFramePositions()
	--calls :ClearAllPoints on PlayerPowerBarAlt under certain conditions.
	--Doing ".ClearAllPoints = E.noop" causes error when you enter combat.
	local function Position(bar) bar:Point('CENTER', _G.AltPowerBarHolder, 'CENTER') end
	hooksecurefunc(_G.PlayerPowerBarAlt, "ClearAllPoints", Position)

	E:CreateMover(holder, 'AltPowerBarMover', L["Alternative Power"], nil, nil, nil, nil, nil, 'general,alternativePowerGroup')
end

function B:UpdateAltPowerBarColors()
	local bar = _G.ElvUI_AltPowerBar

	if E.db.general.altPowerBar.statusBarColorGradient then
		if bar.colorGradientR and bar.colorGradientG and bar.colorGradientB then
			bar:SetStatusBarColor(bar.colorGradientR, bar.colorGradientG, bar.colorGradientB)
		elseif bar.powerValue then
			local power, maxPower = bar.powerValue or 0, bar.powerMaxValue or 0
			local value = (maxPower > 0 and power / maxPower) or 0
			bar.colorGradientValue = value

			local r, g, b = E:ColorGradient(value, 0.8,0,0, 0.8,0.8,0, 0,0.8,0)
			bar.colorGradientR, bar.colorGradientG, bar.colorGradientB = r, g, b

			bar:SetStatusBarColor(r, g, b)
		else
			bar:SetStatusBarColor(0.6, 0.6, 0.6) -- uh, fallback!
		end
	else
		local color = E.db.general.altPowerBar.statusBarColor
		bar:SetStatusBarColor(color.r, color.g, color.b)
	end
end

function B:UpdateAltPowerBarSettings()
	local bar = _G.ElvUI_AltPowerBar
	local db = E.db.general.altPowerBar

	bar:Size(db.width or 250, db.height or 20)
	bar:SetStatusBarTexture(E.Libs.LSM:Fetch("statusbar", db.statusBar))
	bar.text:FontTemplate(E.Libs.LSM:Fetch("font", db.font), db.fontSize or 12, db.fontOutline or 'OUTLINE')
	_G.AltPowerBarHolder:Size(bar.backdrop:GetSize())

	E:SetSmoothing(bar, db.smoothbars)

	B:SetAltPowerBarText(bar.text, bar.powerName or "", bar.powerValue or 0, bar.powerMaxValue or 0, bar.powerPercent or 0)
end

function B:UpdateAltPowerBar()
	_G.PlayerPowerBarAlt:UnregisterAllEvents()
	_G.PlayerPowerBarAlt:Hide()

	local unit = 'player'
	local barType, min, _, _, _, _, _, _, _, _, powerName, powerTooltip = UnitAlternatePowerInfo(unit)
	if not barType then
		unit = 'target'
		barType, min, _, _, _, _, _, _, _, _, powerName, powerTooltip = UnitAlternatePowerInfo(unit)
	end

	self.powerName = powerName
	self.powerTooltip = powerTooltip

	if barType then
		local power = UnitPower(unit, _G.ALTERNATE_POWER_INDEX)
		local maxPower = UnitPowerMax(unit, _G.ALTERNATE_POWER_INDEX) or 0
		local perc = (maxPower > 0 and floor(power / maxPower * 100)) or 0

		self.powerValue = power
		self.powerMaxValue = maxPower
		self.powerPercent = perc
		self.unit = unit

		self:Show()
		self:SetMinMaxValues(min, maxPower)
		self:SetValue(power)

		if E.db.general.altPowerBar.statusBarColorGradient then
			local value = (maxPower > 0 and power / maxPower) or 0
			self.colorGradientValue = value

			local r, g, b = E:ColorGradient(value, 0.8,0,0, 0.8,0.8,0, 0,0.8,0)
			self.colorGradientR, self.colorGradientG, self.colorGradientB = r, g, b

			self:SetStatusBarColor(r, g, b)
		end

		B:SetAltPowerBarText(self.text, powerName or "", power, maxPower, perc)
	else
		self.unit = nil
		self:Hide()
	end
end

function B:SkinAltPowerBar()
	if not E.db.general.altPowerBar.enable then return end

	local powerbar = CreateFrame("StatusBar", "ElvUI_AltPowerBar", E.UIParent)
	powerbar:CreateBackdrop(nil, true)
	powerbar:SetMinMaxValues(0, 200)
	powerbar:Point("CENTER", _G.AltPowerBarHolder)
	powerbar:Hide()

	powerbar:SetScript("OnEnter", onEnter)
	powerbar:SetScript("OnLeave", onLeave)

	powerbar.text = powerbar:CreateFontString(nil, "OVERLAY")
	powerbar.text:Point("CENTER", powerbar, "CENTER")
	powerbar.text:SetJustifyH("CENTER")

	B:UpdateAltPowerBarSettings()
	B:UpdateAltPowerBarColors()

	--Event handling
	powerbar:RegisterEvent("UNIT_POWER_UPDATE")
	powerbar:RegisterEvent("UNIT_POWER_BAR_SHOW")
	powerbar:RegisterEvent("UNIT_POWER_BAR_HIDE")
	powerbar:RegisterEvent("PLAYER_TARGET_CHANGED")
	powerbar:RegisterEvent("PLAYER_ENTERING_WORLD")
	powerbar:SetScript("OnEvent", B.UpdateAltPowerBar)
end
