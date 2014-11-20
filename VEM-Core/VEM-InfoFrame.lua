-- **             VEM Info Frame             **
-- **     http://www.deadlybossmods.com      **
-- ********************************************
--
-- This addon is written and copyrighted by:
--    * Paul Emmerich (Tandanu @ EU-Aegwynn) (VEM-Core)
--    * Martin Verges (Nitram @ EU-Azshara) (VEM-GUI)
--
-- The localizations are written by:
--    * enGB/enUS: Tandanu				http://www.deadlybossmods.com
--    * deDE: Tandanu					http://www.deadlybossmods.com
--    * zhCN: Diablohu					http://wow.gamespot.com.cn
--    * ruRU: BootWin					bootwin@gmail.com
--    * ruRU: Vampik					admin@vampik.ru
--    * zhTW: Hman						herman_c1@hotmail.com
--    * zhTW: Azael/kc10577				paul.poon.kw@gmail.com
--    * koKR: BlueNyx/nBlueWiz			bluenyx@gmail.com / everfinale@gmail.com
--    * esES: Snamor/1nn7erpLaY      	romanscat@hotmail.com
--
-- Special thanks to:
--    * Arta
--    * Omegal @ US-Whisperwind (continuing mod support for 3.2+)
--    * Tennberg (a lot of fixes in the enGB/enUS localization)
--
--
-- The code of this addon is licensed under a Creative Commons Attribution-Noncommercial-Share Alike 3.0 License. (see license.txt)
-- All included textures and sounds are copyrighted by their respective owners.
--
--
--  You are free:
--    * to Share ?to copy, distribute, display, and perform the work
--    * to Remix ?to make derivative works
--  Under the following conditions:
--    * Attribution. You must attribute the work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work).
--    * Noncommercial. You may not use this work for commercial purposes.
--    * Share Alike. If you alter, transform, or build upon this work, you may distribute the resulting work only under the same or similar license to this one.
--
--
-- This file makes use of the following free (Creative Commons Sampling Plus 1.0) sounds:
--    * alarmclockbeeps.ogg by tedthetrumpet (http://www.freesound.org/usersViewSingle.php?id=177)
--    * blip_8.ogg by Corsica_S (http://www.freesound.org/usersViewSingle.php?id=7037)
--  The full of text of the license can be found in the file "Sounds\Creative Commons Sampling Plus 1.0.txt".

---------------
--  Globals  --
---------------
VEM.InfoFrame = {}

--------------
--  Locals  --
--------------
local infoFrame = VEM.InfoFrame
local frame
local createFrame
local onUpdate
local dropdownFrame
local initializeDropdown
local currentMapId
local maxlines
local currentEvent
local headerText = "VEM Info Frame"	-- this is only used if VEM.InfoFrame:SetHeader(text) is not called before :Show()
local lines = {}
local sortingAsc
local sortedLines = {}
local icons = {}
local value = {}

-------------------
-- Local Globals --
-------------------
--Entire InfoFrame is a looping onupdate function. All of these globals get used several times a second
local GetRaidTargetIndex = GetRaidTargetIndex
local UnitName = UnitName
local UnitHealth = UnitHealth
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitDebuff = UnitDebuff
local UnitBuff = UnitBuff
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local GetSpellInfo = GetSpellInfo
local UnitThreatSituation = UnitThreatSituation
local GetRaidRosterInfo = GetRaidRosterInfo
local UnitPosition = UnitPosition
local GetPartyAssignment = GetPartyAssignment
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local twipe = table.wipe

---------------------
--  Dropdown Menu  --
---------------------
-- todo: this dropdown menu is somewhat ugly and unflexible....
do
	local function toggleLocked()
		VEM.Options.InfoFrameLocked = not VEM.Options.InfoFrameLocked
	end
	local function toggleShowSelf()
		VEM.Options.InfoFrameShowSelf = not VEM.Options.InfoFrameShowSelf
	end

	function initializeDropdown(dropdownFrame, level, menu)
		local info
		if level == 1 then
			info = UIDropDownMenu_CreateInfo()
			info.text = LOCK_FRAME
			if VEM.Options.InfoFrameLocked then
				info.checked = true
			end
			info.func = toggleLocked
			UIDropDownMenu_AddButton(info, 1)

			info = UIDropDownMenu_CreateInfo()
			info.keepShownOnClick = true
			info.text = VEM_CORE_INFOFRAME_SHOW_SELF
			if VEM.Options.InfoFrameShowSelf then
				info.checked = true
			end
			info.func = toggleShowSelf
			UIDropDownMenu_AddButton(info, 1)

			info = UIDropDownMenu_CreateInfo()
			info.text = HIDE
			info.notCheckable = true
			info.func = infoFrame.Hide
			info.arg1 = infoFrame
			UIDropDownMenu_AddButton(info, 1)
		end
	end
end


------------------------
--  Create the frame  --
------------------------
function createFrame()
	local elapsed = 0
	local frame = CreateFrame("GameTooltip", "VEMInfoFrame", UIParent, "GameTooltipTemplate")
	dropdownFrame = CreateFrame("Frame", "VEMInfoFrameDropdown", frame, "UIDropDownMenuTemplate")
	frame:SetFrameStrata("DIALOG")
	frame:SetPoint(VEM.Options.InfoFramePoint, UIParent, VEM.Options.InfoFramePoint, VEM.Options.InfoFrameX, VEM.Options.InfoFrameY)
	frame:SetHeight(maxlines*12)
	frame:SetWidth(64)
	frame:EnableMouse(true)
	frame:SetToplevel(true)
	frame:SetMovable(1)
	GameTooltip_OnLoad(frame)
	frame:SetPadding(16)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		if not VEM.Options.InfoFrameLocked then
			self:StartMoving()
		end
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		ValidateFramePosition(self)
		local point, _, _, x, y = self:GetPoint(1)
		VEM.Options.InfoFrameX = x
		VEM.Options.InfoFrameY = y
		VEM.Options.InfoFramePoint = point
	end)
	frame:SetScript("OnEvent", function(self, event, ...)
		if infoFrame[event] then
			infoFrame[event](self, ...)
		end
	end)
	frame:SetScript("OnMouseDown", function(self, button)
		if button == "RightButton" then
			UIDropDownMenu_Initialize(dropdownFrame, initializeDropdown)
			ToggleDropDownMenu(1, nil, dropdownFrame, "cursor", 5, -10)
		end
	end)
	return frame
end


------------------------
--  Update functions  --
------------------------
local updateCallbacks = {}
local function sortFuncDesc(a, b) return lines[a] > lines[b] end
local function sortFuncAsc(a, b) return lines[a] < lines[b] end
local function namesortFuncAsc(a, b) return a < b end
local function updateLines()
	twipe(sortedLines)
	for i in pairs(lines) do
		sortedLines[#sortedLines + 1] = i
	end
	if sortingAsc then
		table.sort(sortedLines, sortFuncAsc)
	else
		table.sort(sortedLines, sortFuncDesc)
	end
	for i, v in ipairs(updateCallbacks) do
		v(sortedLines)
	end
end

local function updateNamesortLines()
	twipe(sortedLines)
	for i in pairs(lines) do
		sortedLines[#sortedLines + 1] = i
	end
	table.sort(sortedLines, namesortFuncAsc)
	for i, v in ipairs(updateCallbacks) do
		v(sortedLines)
	end
end

local function updateLinesCustomSort(sortFunc)
	twipe(sortedLines)
	for i in pairs(lines) do
		sortedLines[#sortedLines + 1] = i
	end
	if type(sortFunc) == "function" then
		table.sort(sortedLines, sortFunc)
	end
	for i, v in ipairs(updateCallbacks) do
		v(sortedLines)
	end
end

local function updateIcons()
	twipe(icons)
	for uId in VEM:GetGroupMembers() do
		local icon = GetRaidTargetIndex(uId)
		local icon2 = GetRaidTargetIndex(uId.."target")
		if icon then
			icons[UnitName(uId)] = ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t"):format(icon)
		end
		if icon2 then
			icons[UnitName(uId.."target")] = ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t"):format(icon2)
		end
	end
	for i = 1, 5 do
		local icon = GetRaidTargetIndex("boss"..i)
		if icon then
			icons[UnitName("boss"..i)] = ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t"):format(icon)
		end
	end
end

local function updateHealth()
	twipe(lines)
	local threshold = value[1]
	for uId in VEM:GetGroupMembers() do
		if UnitHealth(uId) < threshold and not UnitIsDeadOrGhost(uId) then
			lines[UnitName(uId)] = UnitHealth(uId) - threshold
		end
	end
	updateLines()
	updateIcons()
end

local function updatePlayerPower()
	twipe(lines)
	local threshold = value[1]
	local powerType = value[2]
	for uId in VEM:GetGroupMembers() do
		local maxPower = UnitPowerMax(uId, powerType)
		if maxPower ~= 0 and not UnitIsDeadOrGhost(uId) and UnitPower(uId, powerType) / UnitPowerMax(uId, powerType) * 100 >= threshold then
			lines[UnitName(uId)] = UnitPower(uId, powerType)
		end
	end
	if VEM.Options.InfoFrameShowSelf and not lines[UnitName("player")] and UnitPower("player", powerType) > 0 then
		lines[UnitName("player")] = UnitPower("player", powerType)
	end
	updateLines()
	updateIcons()
end

local function updateEnemyPower()
	twipe(lines)
	local threshold = value[1]
	local powerType = value[2]
	for i = 1, 5 do
		if UnitExists("boss"..i) and (UnitPower("boss"..i, powerType) / UnitPowerMax("boss"..i, powerType) * 100 >= threshold) then
			lines[UnitName("boss"..i)] = UnitPower("boss"..i, powerType)
		end
	end
	updateLines()
	updateIcons()
end

--Buffs that are good to have, therefor bad not to have them.
local function updatePlayerBuffs()
	twipe(lines)
	local spellName = GetSpellInfo(value[1])
	local tankIgnored = value[2]
	for uId in VEM:GetGroupMembers() do
		if tankIgnored and UnitGroupRolesAssigned(uId) == "TANK" or GetPartyAssignment("MAINTANK", uId, 1) then
		else
			if not UnitBuff(uId, spellName) and not UnitIsDeadOrGhost(uId) then
				lines[UnitName(uId)] = ""
			end
		end
	end
	updateLines()
	updateIcons()
end

--Debuffs that are good to have, therefor it's bad NOT to have them.
local function updateGoodPlayerDebuffs()
	twipe(lines)
	local spellName = GetSpellInfo(value[1])
	local tankIgnored = value[2]
	for uId in VEM:GetGroupMembers() do
		if tankIgnored and UnitGroupRolesAssigned(uId) == "TANK" or GetPartyAssignment("MAINTANK", uId, 1) then
		else
			if not UnitDebuff(uId, spellName) and not UnitIsDeadOrGhost(uId) then
				lines[UnitName(uId)] = ""
			end
		end
	end
	updateLines()
	updateIcons()
end

--Debuffs that are bad to have, therefor it is bad to have them.
local function updateBadPlayerDebuffs()
	twipe(lines)
	local spellName = GetSpellInfo(value[1])
	local tankIgnored = value[2]
	for uId in VEM:GetGroupMembers() do
		if tankIgnored and UnitGroupRolesAssigned(uId) == "TANK" or GetPartyAssignment("MAINTANK", uId, 1) then
		else
			if UnitDebuff(uId, spellName) and not UnitIsDeadOrGhost(uId) then
				lines[UnitName(uId)] = ""
			end
		end
	end
	updateLines()
	updateIcons()
end

--Debuffs that are bad to have, but we want to show players who do NOT have them
local function updateReverseBadPlayerDebuffs()
	twipe(lines)
	local spellName = GetSpellInfo(value[1])
	local tankIgnored = value[2]
	for uId in VEM:GetGroupMembers() do
		if tankIgnored and UnitGroupRolesAssigned(uId) == "TANK" or GetPartyAssignment("MAINTANK", uId, 1) then
		else
			if not UnitDebuff(uId, spellName) and not UnitIsDeadOrGhost(uId) and not UnitDebuff(uId, GetSpellInfo(27827)) then--27827 Spirit of Redemption. This particular info frame wants to ignore this
				lines[UnitName(uId)] = ""
			end
		end
	end
	updateLines()
	updateIcons()
end

local function updatePlayerBuffStacks()
	twipe(lines)
	local spellName = GetSpellInfo(value[1])
	for uId in VEM:GetGroupMembers() do
		if UnitBuff(uId, spellName) then
			lines[UnitName(uId)] = select(4, UnitBuff(uId, spellName))
		end
	end
	updateIcons()
	updateLines()
end

local function updatePlayerDebuffStacks()
	twipe(lines)
	local spellName = GetSpellInfo(value[1])
	for uId in VEM:GetGroupMembers() do
		if UnitDebuff(uId, spellName) then
			lines[UnitName(uId)] = select(4, UnitDebuff(uId, spellName))
		end
	end
	updateIcons()
	updateLines()
end

local function updatePlayerAggro()
	twipe(lines)
	local aggroType = value[1]
	for uId in VEM:GetGroupMembers() do
		if UnitThreatSituation(uId) == aggroType then
			lines[UnitName(uId)] = ""
		end
	end
	updateLines()
	updateIcons()
end

local function updatePlayerTargets()
	twipe(lines)
	local cId = value[1]
	for uId, i in VEM:GetGroupMembers() do
		if VEM:GetUnitCreatureId(uId.."target") ~= cId and (UnitGroupRolesAssigned(uId) == "DAMAGER" or UnitGroupRolesAssigned(uId) == "NONE") then
			lines[UnitName(uId)] = ""
		end
	end
	updateLines()
	updateIcons()
end

local function updateByFunction()
	twipe(lines)
	local func = value[1]
	local sortFunc = value[2]
	local useIcon = value[3]
	lines = func()
	if sortFunc then
		updateLinesCustomSort(sortFunc)
	else
		updateLines()
	end
	if useIcon then
		updateIcons()
	end
end

local function updateTest()
	twipe(lines)
	lines["Alpha"] = 1
	lines["Beta"] = 10
	lines["Gamma"] = 25
	lines["Delta"] = 50
	lines["Epsilon"] = 100
	updateLines()
end

local events = {
	["health"] = updateHealth,
	["playerpower"] = updatePlayerPower,
	["enemypower"] = updateEnemyPower,
	["playerbuff"] = updatePlayerBuffs,
	["playergooddebuff"] = updateGoodPlayerDebuffs,
	["playerbaddebuff"] = updateBadPlayerDebuffs,
	["reverseplayerbaddebuff"] = updateReverseBadPlayerDebuffs,
	["playeraggro"] = updatePlayerAggro,
	["playerbuffstacks"] = updatePlayerBuffStacks,
	["playerdebuffstacks"] = updatePlayerDebuffStacks,
	["playertargets"] = updatePlayerTargets,
	["function"] = updateByFunction,
	["test"] = updateTest
}

----------------
--  OnUpdate  --
----------------
local friendlyEvents = {
	["health"] = true,
	["playerpower"] = true,
	["playerbuff"] = true,
	["playergooddebuff"] = true,
	["playerbaddebuff"] = true,
	["reverseplayerbaddebuff"] = true,
	["playeraggro"] = true,
	["playerbuffstacks"] = true,
	["playerdebuffstacks"] = true,
	["playertargets"] = true
}

function onUpdate(frame)
	if events[currentEvent] then
		events[currentEvent]()
	else
		frame:Hide()
		error("VEM-InfoFrame: Unsupported event", 2)
	end
	local color = NORMAL_FONT_COLOR
	frame:ClearLines()
	if headerText then
		frame:AddLine(headerText, 255, 255, 255, 0)
	end
	local linesShown = 0
	for i = 1, #sortedLines do
		if linesShown >= maxlines then
			break
		end
		local leftText = sortedLines[i]
		local rightText = lines[leftText]
		local icon = icons[leftText] and icons[leftText]..leftText
		if friendlyEvents[currentEvent] then
			local unitId = VEM:GetRaidUnitId(VEM:GetUnitFullName(leftText)) or "player"--Prevent nil logical error
			local addedSelf
			if unitId and select(4, UnitPosition(unitId)) == currentMapId then
				linesShown = linesShown + 1
				if leftText == UnitName("player") then--It's player.
					addedSelf = true
					if currentEvent == "health" or currentEvent == "playerpower" or currentEvent == "playerbuff" or currentEvent == "playergooddebuff" or currentEvent == "playerbaddebuff" or currentEvent == "playertargets" or (currentEvent == "playeraggro" and value[1] == 3) then--Red
						frame:AddDoubleLine(icon or leftText, rightText, 255, 0, 0, 255, 255, 255)-- (leftText, rightText, left.R, left.G, left.B, right.R, right.G, right.B)
					else--Green
						frame:AddDoubleLine(icon or leftText, rightText, 0, 255, 0, 255, 255, 255)
					end
				else--It's not player, do nothing special with it. Ordinary white text.
					frame:AddDoubleLine(icon or leftText, rightText, color.R, color.G, color.B, 255, 255, 255)
				end
			end
			if not addedSelf and VEM.Options.InfoFrameShowSelf and currentEvent == "playerpower" then-- Only Shows on playerpower event.
				frame:AddDoubleLine(UnitName("player"), lines[UnitName("player")], color.R, color.G, color.B, 255, 255, 255)
			end
		else
			linesShown = linesShown + 1
			if currentEvent == "enemypower" then--Green
				frame:AddDoubleLine(icon or leftText, rightText, 0, 255, 0, 255, 255, 255)
			else
				frame:AddDoubleLine(icon or leftText, rightText, color.R, color.G, color.B, 255, 255, 255)
			end
		end
	end
	frame:Show()
end

---------------
--  Methods  --
---------------
function infoFrame:Show(maxLines, event, ...)
	currentMapId = select(4, UnitPosition("player"))
	if VEM.Options.DontShowInfoFrame and (event or 0) ~= "test" then return end

	maxlines = maxLines or 5
	currentEvent = event
	for i = 1, select("#", ...) do
		value[i] = select(i, ...)
	end
	frame = frame or createFrame()

	if event == "health" then
		sortingAsc = true	-- Person who misses the most HP to be at threshold is listed on top
	end

	if events[currentEvent] then
		events[currentEvent]()
	else
		error("VEM-InfoFrame: Unsupported event", 2)
		return
	end

	if not friendlyEvents[currentEvent] then
		twipe(icons)
	end
	frame:Show()
	frame:SetOwner(UIParent, "ANCHOR_PRESERVE")
	onUpdate(frame)
	if not frame.ticker then
		frame.ticker = C_Timer.NewTicker(0.5, function() onUpdate(frame) end)
	end
end

function infoFrame:RegisterCallback(cb)
	updateCallbacks[#updateCallbacks + 1] = cb
end

function infoFrame:Update()
	onUpdate(frame)
end

function infoFrame:Hide()
	twipe(lines)
	twipe(icons)
	twipe(sortedLines)
	twipe(updateCallbacks)
	headerText = "VEM Info Frame"
	maxlines = nil
	currentEvent = nil
	twipe(value)
	if frame then
		if frame.ticker then
			frame.ticker:Cancel()
			frame.ticker = nil
		end
		frame:Hide()
	end
end

function infoFrame:IsShown()
	return frame and frame:IsShown()
end

function infoFrame:SetHeader(text)
	if not text then return end
	headerText = text
end

function infoFrame:SetSortingAsc(ascending)
	sortingAsc = ascending
end
