﻿if GetBuildInfo() ~= "5.4.0" then return end
local mod	= VEM:NewMod(860, "VEM-Pandaria", nil, 322)
local L		= mod:GetLocalizedStrings()
local sndWOP	= mod:NewSound(nil, "SoundWOP", true)

mod:SetRevision(("$Revision: 10106 $"):sub(12, -3))
mod:SetCreatureID(71953)
--mod:SetQuestID(32519)
mod:SetZone()

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START",
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_APPLIED_DOSE",
	"SPELL_AURA_REMOVED"
)

mod:RegisterEvents(
	"CHAT_MSG_MONSTER_YELL"
)

local warnSpectralSwipe				= mod:NewStackAnnounce(144638, 2, nil, mod:IsTank() or mod:IsHealer())
local warnAgility					= mod:NewTargetAnnounce(144631, 3)
local warnCracklingLightning		= mod:NewSpellAnnounce(144635, 3)--According to data, spread range is 60 yards so spreading out for this seems pointless. it's just healed through
local warnChiBarrage				= mod:NewSpellAnnounce(144642, 4)

local specWarnSpectralSwipe			= mod:NewSpecialWarningStack(144638, mod:IsTank(), 4)--Stack is guesswork
local specWarnSpectralSwipeOther	= mod:NewSpecialWarningTarget(144638, mod:IsTank())
local specWarnAgility				= mod:NewSpecialWarningDispel(144631, mod:IsMagicDispeller())
local specWarnChiBarrage			= mod:NewSpecialWarningSpell(144642, nil, nil, nil, 2)

local timerSpectralSwipe			= mod:NewTargetTimer(60, 144638, nil, mod:IsTank() or mod:IsHealer())
--local timerSpectralSwipeCD		= mod:NewCDTimer(26, 144638)
--local timerAgilityCD				= mod:NewCDTimer(25, 144631)
--local timerCracklingLightningCD	= mod:NewCDTimer(25, 144635)
--local timerChiBarrageCD			= mod:NewCDTimer(25, 144642)

mod:AddBoolOption("RangeFrame", true)--This is for chi barrage spreading.

--local yellTriggered = false

function mod:OnCombatStart(delay)
--[[	if yellTriggered then
		timerSpectralSwipeCD:Start(20-delay)
		timerAgilityCD:Start(40-delay)
	end--]]
	if self.Options.RangeFrame then
		VEM.RangeCheck:Show(3)
	end
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		VEM.RangeCheck:Hide()
	end
--	yellTriggered = false
end

function mod:SPELL_CAST_START(args)
	if args.spellId == 144635 then
		warnCracklingLightning:Show()
--		timerCracklingLightningCD:Start()
	elseif args.spellId == 144642 then
		warnChiBarrage:Show()
		specWarnChiBarrage:Show()
--		timerChiBarrageCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 144638 then
		local uId = VEM:GetRaidUnitId(args.destName)
		if self:IsTanking(uId) then--Only want debuffs on tanks, don't care about the dumb melee that stand in front of things.
			local amount = args.amount or 1
			warnSpectralSwipe:Show(args.destName, amount)
			timerSpectralSwipe:Start(args.destName)
--			timerSpectralSwipeCD:Start()
			if args:IsPlayer() and amount >= 4 then
				specWarnSpectralSwipe:Show(amount)
			else
				if amount >= 2 and not UnitIsDeadOrGhost("player") or not UnitDebuff("player", GetSpellInfo(144638)) then
					specWarnSpectralSwipeOther:Show(args.destName)
					if mod:IsTank() then
						sndWOP:Play("Interface\\AddOns\\VEM-Core\\extrasounds\\"..VEM.Options.CountdownVoice.."\\changemt.mp3") --換坦嘲諷
					end
				end
			end
		end
	elseif args.spellId == 144631 and not args:IsDestTypePlayer() then
		warnAgility:Show(args.destName)
		specWarnAgility:Show(args.destName)
		if mod:IsMagicDispeller() then
			sndWOP:Play("Interface\\AddOns\\VEM-Core\\extrasounds\\"..VEM.Options.CountdownVoice.."\\dispelnow.mp3") --快驅散
		end
--		timerAgilityCD:Start()
	end
end
mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 144638 then
		timerSpectralSwipe:Cancel(args.destName)
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if (msg == L.Victory or msg:find(L.Victory)) and self:IsInCombat() then
		VEM:EndCombat(self)
	--[[elseif msg == L.Pull and not self:IsInCombat() then
		if self:GetCIDFromGUID(UnitGUID("target")) == 71953 or self:GetCIDFromGUID(UnitGUID("targettarget")) == 71953 then
			yellTriggered = true
			VEM:StartCombat(self, 0)
		end--]]
	end
end