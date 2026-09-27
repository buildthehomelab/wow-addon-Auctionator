-- Stat filters for compound searches: a "+agi" part keeps only items whose
-- tooltip carries Agility.  Read from the tooltip rather than GetItemStats
-- so random suffixes ("of the Monkey") and gems count too.  enUS text only.

local STATS = {
	{ token = "str",    label = "Strength",          find = { "strength" } },
	{ token = "agi",    label = "Agility",           find = { "agility" } },
	{ token = "sta",    label = "Stamina",           find = { "stamina" } },
	{ token = "int",    label = "Intellect",         find = { "intellect" } },
	{ token = "spi",    label = "Spirit",            find = { "spirit" } },
	{ token = "ap",     label = "Attack Power",      find = { "attack power" } },
	{ token = "sp",     label = "Spell Power",       find = { "spell power" } },
	{ token = "crit",   label = "Crit Rating",       find = { "critical strike rating" } },
	{ token = "hit",    label = "Hit Rating",        find = { "hit rating" } },
	{ token = "haste",  label = "Haste Rating",      find = { "haste rating" } },
	{ token = "exp",    label = "Expertise",         find = { "expertise rating" } },
	{ token = "arp",    label = "Armor Pen",         find = { "armor penetration rating" } },
	{ token = "def",    label = "Defense",           find = { "defense rating" } },
	{ token = "dodge",  label = "Dodge",             find = { "dodge rating" } },
	{ token = "parry",  label = "Parry",             find = { "parry rating" } },
	{ token = "block",  label = "Block",             find = { "block rating", "block value" } },
	{ token = "resil",  label = "Resilience",        find = { "resilience rating" } },
	{ token = "mp5",    label = "Mana per 5",        find = { "mana per 5", "mana every 5" } },
	{ token = "spen",   label = "Spell Pen",         find = { "spell penetration" } },
}

-- lines that mention a stat without the item having it
local SKIP_PREFIXES = { "socket bonus:", "use:", "chance on hit:", "requires", "(", "\"" }

local byToken = {}
for _, stat in ipairs(STATS) do
	byToken[stat.token] = stat
end

-----------------------------------------

function Atr_GetStatFilters ()
	return STATS
end

-----------------------------------------

function Atr_StatLabel (token)
	local stat = byToken[token]
	return stat and stat.label
end

-----------------------------------------

function Atr_StatFromSearchPart (s)		-- returns "agi" for "+agi", nil if not a stat part

	if (string.len(s) > 1 and string.sub(s,1,1) == "+") then
		local token = string.lower (string.sub(s,2))
		if (byToken[token]) then
			return token
		end
	end

	return nil
end

-----------------------------------------

local scanTip
local tipStats = {}		-- itemLink -> { token = true }

local function statsOnTooltip (itemLink)

	if (tipStats[itemLink]) then
		return tipStats[itemLink]
	end

	if (scanTip == nil) then
		scanTip = CreateFrame ("GameTooltip", "AtrStatScanTip", nil, "GameTooltipTemplate")
	end

	scanTip:SetOwner (WorldFrame, "ANCHOR_NONE")
	scanTip:ClearLines()
	scanTip:SetHyperlink (itemLink)

	local found = {}
	local numFound = 0

	for i = 2, scanTip:NumLines() do		-- line 1 is the item name
		local fs   = _G["AtrStatScanTipTextLeft"..i]
		local line = fs and fs:GetText()

		if (line) then
			line = string.lower (line)

			local skip = false
			for _, prefix in ipairs(SKIP_PREFIXES) do
				if (string.sub (line, 1, string.len(prefix)) == prefix) then
					skip = true
					break
				end
			end

			if (not skip) then
				for _, stat in ipairs(STATS) do
					for _, text in ipairs(stat.find) do
						if (string.find (line, text, 1, true)) then
							found[stat.token] = true
							numFound = numFound + 1
						end
					end
				end
			end
		end
	end

	scanTip:Hide()

	-- an uncached item shows "Retrieving item information"; don't remember that
	if (numFound > 0 or scanTip:NumLines() > 2) then
		tipStats[itemLink] = found
	end

	return found
end

-----------------------------------------

function Atr_ItemHasStats (itemLink, tokens)

	if (tokens == nil or #tokens == 0) then
		return true
	end

	local found = statsOnTooltip (itemLink)

	for _, token in ipairs(tokens) do
		if (not found[token]) then
			return false
		end
	end

	return true
end
