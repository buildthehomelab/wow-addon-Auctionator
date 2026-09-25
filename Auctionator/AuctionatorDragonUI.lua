-- Dragonflight chrome for the auction house, borrowed from DragonUI when it is loaded.
-- Without DragonUI (or one too old to carry these helpers) this file does nothing.

local D = _G.DragonUI
local CP = D and D.CharacterPanel

if not (D and D._dir and D.SkinRedButton and D.SafeSetAtlas and NineSliceUtils
		and CP and CP.ReskinTab and CP.ModernizeCloseButton and CP.DrawPaneBorder) then
	return
end

local ROCK		= D._dir .. "UI\\ui-background-rock"
local MARBLE	= D._dir .. "UI\\ui-background-marble"

-- AuctionFrame is 832x447 and its old art bleeds to every edge; this is the rect that art drew
-- the window in, and where the new metal border goes.
local CHROME_LEFT, CHROME_TOP, CHROME_RIGHT, CHROME_BOTTOM = 10, -11, -1, 9

-- One recessed pane under the lists. Its top follows the tab: Blizzard's three tabs and
-- Auctionator's panel start their lists at different heights.
local INSET_LEFT, INSET_RIGHT, INSET_BOTTOM = 14, -6, 36
local INSET_TOP_BLIZZARD	= { -80, -48, -48 }		-- Browse, Bids, Auctions
local INSET_TOP_AUCTIONATOR	= -70
local INSET_TOP_OTHER		= -48					-- tabs some other addon added

local CLASSIC_ART = { "TopLeft", "Top", "TopRight", "BotLeft", "Bot", "BotRight" }

local DIALOGS = {
	"Atr_Error_Frame", "Atr_Confirm_Frame", "Atr_Buy_Confirm_Frame", "Atr_CheckActives_Frame",
	"Atr_CancelAuction_Confirm_Frame", "Atr_FullScanFrame", "Atr_Adv_Search_Dialog",
}

local chrome, insetTarget

-----------------------------------------

local function tiled (host, sublevel, file)
	local tex = host:CreateTexture(nil, "BACKGROUND", nil, sublevel)
	tex:SetTexture(file, "REPEAT", "REPEAT")
	tex:SetHorizTile(true)
	tex:SetVertTile(true)
	return tex
end

local function isPanelButton (btn)
	local tex = btn.GetNormalTexture and btn:GetNormalTexture()
	local path = tex and tex:GetTexture()
	return type(path) == "string" and path:lower():find("ui%-panel%-button%-up") ~= nil
end

-- Catches the unnamed OK/Cancel buttons too, which a list of globals would miss.
local function skinButtons (frame)
	local children = { frame:GetChildren() }
	for i = 1, #children do
		local child = children[i]
		if child:GetObjectType() == "Button" and isPanelButton(child) then
			D.SkinRedButton(child)
		end
		skinButtons(child)
	end
end

-- Both Blizzard's tabs and Auctionator's swap these textures on every click, but only ever
-- through SetTexture, so hiding them once holds. Re-hiding on tab change is just insurance.
local function hideClassicArt ()
	for _, piece in ipairs(CLASSIC_ART) do
		local tex = _G["AuctionFrame" .. piece]
		if tex then tex:Hide() end
	end
end

-----------------------------------------

local function layoutTabs ()
	local prev
	for i = 1, AuctionFrame.numTabs or 0 do
		local tab = _G["AuctionFrameTab" .. i]
		if tab then
			-- Without this DragonUI's resize hook re-chains the character panel's tabs instead.
			tab._duiRelayout = layoutTabs
			if not tab._duiReskinned then CP.ReskinTab(tab) end
			if tab:IsShown() then
				tab:ClearAllPoints()
				if prev then
					tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", 1, 0)
				else
					tab:SetPoint("TOPLEFT", chrome, "BOTTOMLEFT", 11, 2)
				end
				prev = tab
			end
		end
	end
end

local function placeInset ()
	local index = AuctionFrame.selectedTab or 1
	local tab = _G["AuctionFrameTab" .. index]
	local top
	if tab and tab.auctionatorTab then
		top = INSET_TOP_AUCTIONATOR
	else
		top = INSET_TOP_BLIZZARD[index] or INSET_TOP_OTHER
	end
	insetTarget:ClearAllPoints()
	insetTarget:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", INSET_LEFT, top)
	insetTarget:SetPoint("BOTTOMRIGHT", AuctionFrame, "BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)
end

-----------------------------------------

local function skinDialog (frame)
	if not frame or frame.atrDragonSkinned then return end
	frame.atrDragonSkinned = true

	-- Auctionator still calls SetBackdropColor on some of these; with no backdrop that's a no-op.
	frame:SetBackdrop(nil)
	tiled(frame, -8, ROCK):SetAllPoints(frame)
	NineSliceUtils.ApplyLayout(frame, NineSliceUtils.GetLayout("Dialog"))

	local regions = { frame:GetRegions() }
	for i = 1, #regions do
		local region = regions[i]
		if region:GetObjectType() == "Texture" then
			local path = region:GetTexture()
			if type(path) == "string" and path:lower():find("ui%-dialogbox%-header") then
				region:Hide()
			end
		end
	end

	skinButtons(frame)
end

-----------------------------------------

local function skinAuctionHouse ()
	if chrome or not AuctionFrame then return end
	local f = AuctionFrame

	hideClassicArt()

	-- The border goes on its own frame above the content: NineSlice pieces are textures, and on
	-- AuctionFrame itself every child panel would draw over them.
	chrome = CreateFrame("Frame", nil, f)
	chrome:SetPoint("TOPLEFT", f, "TOPLEFT", CHROME_LEFT, CHROME_TOP)
	chrome:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", CHROME_RIGHT, CHROME_BOTTOM)
	chrome:SetFrameLevel(f:GetFrameLevel() + 20)
	chrome:EnableMouse(false)
	NineSliceUtils.ApplyLayout(chrome, NineSliceUtils.GetLayout("PortraitFrameTemplate"))

	-- Everything else is drawn on AuctionFrame, so it sits under every child panel for free.
	local rock = tiled(f, -8, ROCK)
	rock:SetPoint("TOPLEFT", chrome, "TOPLEFT", 2, -21)
	rock:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -2, 2)

	-- Between the rock and the marble: on Bids and Auctions the inset starts inside the band.
	local streaks = f:CreateTexture(nil, "BACKGROUND", nil, -7)
	if D:SafeSetAtlas(streaks, "_UI-Frame-TopTileStreaks") then
		streaks:SetHorizTile(true)
		streaks:SetHeight(43)
		streaks:SetPoint("TOPLEFT", chrome, "TOPLEFT", 6, -21)
		streaks:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -2, -21)
	else
		streaks:Hide()
	end

	insetTarget = CreateFrame("Frame", nil, f)
	insetTarget:EnableMouse(false)
	tiled(f, -5, MARBLE):SetAllPoints(insetTarget)
	CP.DrawPaneBorder(f, insetTarget)
	placeInset()

	-- 56px under the corner ring, as DragonUI's own windows do: with no masks in 3.3.5a a full
	-- square face spills past the metal.
	local portrait = AuctionPortraitTexture
	if portrait then
		portrait:ClearAllPoints()
		portrait:SetPoint("TOPLEFT", chrome, "TOPLEFT", -2, 4)
		portrait:SetSize(56, 56)
		portrait:SetDrawLayer("ARTWORK")
	end

	if AuctionFrameCloseButton then
		CP.ModernizeCloseButton(AuctionFrameCloseButton, chrome, 1, 0)
		AuctionFrameCloseButton:SetFrameLevel(chrome:GetFrameLevel() + 5)
	end

	layoutTabs()
	skinButtons(f)

	for _, name in ipairs(DIALOGS) do
		skinDialog(_G[name])
	end

	-- Both Blizzard's tab handler and Auctionator's replacement end up here, and so would a tab
	-- another addon adds later.
	hooksecurefunc("PanelTemplates_SetTab", function (frame)
		if frame ~= AuctionFrame then return end
		hideClassicArt()
		placeInset()
		layoutTabs()
	end)
end

-- Atr_Init runs once, when Blizzard_AuctionUI loads; by then its tabs and panel exist and
-- Atr_LocalizeFrames has settled the button widths.
hooksecurefunc("Atr_Init", skinAuctionHouse)
