-- Dragonflight look for the auction house, borrowed from DragonUI when it is loaded.
-- Without DragonUI (or one too old to carry these helpers) this file does nothing.

local D = _G.DragonUI
local CP = D and D.CharacterPanel

if not (D and D._dir and D.atlasinfo and D.SkinRedButton and D.SafeSetAtlas and NineSliceUtils
		and CP and CP.ReskinTab and CP.ModernizeCloseButton) then
	return
end

local ROCK			= D._dir .. "UI\\ui-background-rock"
local MARBLE		= D._dir .. "UI\\ui-background-marble"
local QUICKSLOT		= D._dir .. "UI\\ui-quickslot2"
local QUICKSLOT_DOWN	= D._dir .. "UI\\ui-quickslot-depress"
local SEARCH_ICON	= D._dir .. "Collections\\UI-Searchbox-Icon"

-- AuctionFrame is 832x447 and its old art bleeds to every edge; this is the rect that art drew
-- the window in, and where the new metal border goes.
local CHROME_LEFT, CHROME_TOP, CHROME_RIGHT, CHROME_BOTTOM = 10, -11, -1, 9

-- Recessed panes per tab, as { left, top, right, bottom } from AuctionFrame's top-left corner,
-- sized to what each tab lays out: a list on the left, results on the right.
local PANES = {
	[1] = { { 18, -98, 180, -410 }, { 183, -80, 826, -410 } },	-- Browse: categories | results
	[2] = { { 18, -50, 826, -410 } },								-- Bids
	[3] = { { 14, -50, 213, -410 }, { 216, -50, 826, -410 } },	-- Auctions: new auction | yours
	auctionator	= { { 14, -76, 212, -410 }, { 216, -76, 826, -410 } },
	other		= { { 14, -50, 826, -410 } },						-- a tab some other addon added
}

local TITLES = { "BrowseTitle", "BidTitle", "AuctionsTitle" }

local CLASSIC_ART = { "TopLeft", "Top", "TopRight", "BotLeft", "Bot", "BotRight" }

-- Result rows, as prefix and count; every other one gets a stripe.
local ROWS = {
	{ "BrowseButton", 8 }, { "BidButton", 9 }, { "AuctionsButton", 9 },
	{ "AuctionatorEntry", 15 }, { "AuctionatorHEntry", 20 },
}

local DIALOGS = {
	"Atr_Error_Frame", "Atr_Confirm_Frame", "Atr_Buy_Confirm_Frame", "Atr_CheckActives_Frame",
	"Atr_CancelAuction_Confirm_Frame", "Atr_FullScanFrame", "Atr_Adv_Search_Dialog",
}

local SEARCH_BOXES = { BrowseName = true, Atr_Search_Box = true, Atr_AS_Searchtext = true }

local chrome, title
local panes = {}

-----------------------------------------
-- small helpers

local function tiled (host, sublevel, file)
	local tex = host:CreateTexture(nil, "BACKGROUND", nil, sublevel)
	tex:SetTexture(file, "REPEAT", "REPEAT")
	tex:SetHorizTile(true)
	tex:SetVertTile(true)
	return tex
end

local function solid (host, layer, r, g, b, a)
	local tex = host:CreateTexture(nil, layer)
	tex:SetTexture(r, g, b, a)
	return tex
end

local function texturePath (tex)
	local path = tex and tex.GetTexture and tex:GetTexture()
	return type(path) == "string" and path:lower() or nil
end

local function hasArt (tex, pattern)
	local path = texturePath(tex)
	return path ~= nil and path:find(pattern) ~= nil
end

local function named (frame, suffix)
	local name = frame.GetName and frame:GetName()
	return name and _G[name .. suffix]
end

-----------------------------------------
-- panes: drawn on AuctionFrame itself so every child panel sits on top of them

local function newPane ()
	local f = AuctionFrame
	local anchor = CreateFrame("Frame", nil, f)
	anchor:EnableMouse(false)

	local pieces = {}
	local bg = tiled(f, -5, MARBLE)
	bg:SetAllPoints(anchor)
	pieces[#pieces + 1] = bg

	-- Retail's InsetFrameTemplate trim, the same pieces DragonUI's own panes use.
	local function corner (atlas, point, drop)
		local tex = f:CreateTexture(nil, "BORDER", nil, -5)
		D:SafeSetAtlas(tex, atlas)
		tex:SetSize(6, 6)
		tex:SetPoint(point, anchor, point, 0, drop or 0)
		pieces[#pieces + 1] = tex
		return tex
	end
	local tl = corner("UI-Frame-InnerTopLeft", "TOPLEFT")
	local tr = corner("UI-Frame-InnerTopRight", "TOPRIGHT")
	local bl = corner("UI-Frame-InnerBotLeftCorner", "BOTTOMLEFT", -1)
	local br = corner("UI-Frame-InnerBotRight", "BOTTOMRIGHT", -1)

	local function edge (atlas, vertical, p1, a1, r1, p2, a2, r2)
		local tex = f:CreateTexture(nil, "BORDER", nil, -5)
		D:SafeSetAtlas(tex, atlas)
		if vertical then tex:SetWidth(3) else tex:SetHeight(3) end
		tex:SetPoint(p1, a1, r1)
		tex:SetPoint(p2, a2, r2)
		pieces[#pieces + 1] = tex
	end
	edge("!UI-Frame-InnerLeftTile", true, "TOPLEFT", tl, "BOTTOMLEFT", "BOTTOMLEFT", bl, "TOPLEFT")
	edge("!UI-Frame-InnerRightTile", true, "TOPRIGHT", tr, "BOTTOMRIGHT", "BOTTOMRIGHT", br, "TOPRIGHT")
	edge("_UI-Frame-InnerTopTile", false, "TOPLEFT", tl, "TOPRIGHT", "TOPRIGHT", tr, "TOPLEFT")
	edge("_UI-Frame-InnerBotTile", false, "BOTTOMLEFT", bl, "BOTTOMRIGHT", "BOTTOMRIGHT", br, "BOTTOMLEFT")

	return { anchor = anchor, pieces = pieces }
end

local function placePane (pane, rect)
	for _, piece in ipairs(pane.pieces) do
		if rect then piece:Show() else piece:Hide() end
	end
	if not rect then return end
	pane.anchor:ClearAllPoints()
	pane.anchor:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", rect[1], rect[2])
	pane.anchor:SetPoint("BOTTOMRIGHT", AuctionFrame, "TOPLEFT", rect[3], rect[4])
end

local function selectedTab ()
	local index = AuctionFrame.selectedTab or 1
	return index, _G["AuctionFrameTab" .. index]
end

local function placePanes ()
	local index, tab = selectedTab()
	local layout
	if tab and tab.auctionatorTab then
		layout = PANES.auctionator
	else
		layout = PANES[index] or PANES.other
	end
	for i = 1, 2 do
		if not panes[i] then panes[i] = newPane() end
		placePane(panes[i], layout[i])
	end
end

-----------------------------------------
-- title: the metal band covers where every tab put its own, so one sits on top and copies it

local function updateTitle ()
	if not title then return end
	local index, tab = selectedTab()
	local source
	if tab and tab.auctionatorTab then
		source = AuctionatorTitle
	else
		source = _G[TITLES[index] or ""]
	end
	local text = source and source:GetText()
	if not text or text == "" then text = tab and tab:GetText() or "" end
	title:SetText(text)
end

-----------------------------------------
-- controls, recognised by the art their Blizzard templates ship with

local function isPanelButton (btn)
	return hasArt(btn:GetNormalTexture(), "ui%-panel%-button%-up")
end

local function skinQuickslot (btn)
	btn:GetNormalTexture():SetTexture(QUICKSLOT)
	local pushed = btn:GetPushedTexture()
	if pushed then pushed:SetTexture(QUICKSLOT_DOWN) end
end

-- Column headers: a dark strip with a thin gold rule, in place of the stone tabs.
local function dressHeader (host)
	local bg = solid(host, "BACKGROUND", 0, 0, 0, 0.45)
	bg:SetPoint("TOPLEFT", host, "TOPLEFT")
	bg:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -2, 0)
	local rule = solid(host, "BORDER", 1, 0.82, 0, 0.35)
	rule:SetHeight(1)
	rule:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT")
	rule:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT")
end

local function skinSortHeader (btn)
	for _, part in ipairs({ "Left", "Middle", "Right" }) do
		local tex = named(btn, part)
		if tex then tex:SetAlpha(0) end
	end
	dressHeader(btn)
end

-- Category list: retail's settings-list bar. Blizzard fades the stock art by type (class 1,
-- subclass 0.4, inventory slot 0); the new bar follows the same fade.
local FILTER_ALPHA = { class = 1, subclass = 0.5, invtype = 0 }

local function skinFilterButton (btn)
	local stock = btn:GetNormalTexture()
	if stock then stock:SetTexture(nil) end

	local h = btn:GetHeight()
	if not h or h <= 0 then h = 20 end
	local function piece (atlas, width)
		local tex = btn:CreateTexture(nil, "BACKGROUND")
		D:SafeSetAtlas(tex, atlas)
		if width then tex:SetSize(width, h) end
		return tex
	end
	local left = piece("options_listexpand_left", 12 * h / 26)
	left:SetPoint("LEFT", btn, "LEFT")
	local right = piece("options_listexpand_right", 28 * h / 26)
	right:SetPoint("RIGHT", btn, "RIGHT")
	local middle = piece("_options_listexpand_middle")
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

	btn.atrDragonBar = { left, middle, right }
end

local function onFilterType (btn, kind)
	local bar = btn and btn.atrDragonBar
	if not bar then return end
	local alpha = FILTER_ALPHA[kind] or 1
	for i = 1, #bar do bar[i]:SetAlpha(alpha) end
end

-- Text fields: the Common-Input-Border caps become a dark field with a thin grey rim.
local function skinInput (eb)
	local left, middle, right = named(eb, "Left"), named(eb, "Middle"), named(eb, "Right")
	for _, tex in ipairs({ left, middle, right }) do
		tex:SetTexture(0, 0, 0, 0.55)
	end

	local function rim (p1, r1, p2, r2, w, h)
		local tex = solid(eb, "BORDER", 0.5, 0.5, 0.5, 0.7)
		if w then tex:SetWidth(w) end
		if h then tex:SetHeight(h) end
		tex:SetPoint(p1, left, r1)
		tex:SetPoint(p2, right, r2)
	end
	rim("TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT", nil, 1)
	rim("BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT", nil, 1)
	local l = solid(eb, "BORDER", 0.5, 0.5, 0.5, 0.7)
	l:SetWidth(1); l:SetPoint("TOPLEFT", left, "TOPLEFT"); l:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT")
	local r = solid(eb, "BORDER", 0.5, 0.5, 0.5, 0.7)
	r:SetWidth(1); r:SetPoint("TOPRIGHT", right, "TOPRIGHT"); r:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT")

	if SEARCH_BOXES[eb:GetName()] then
		local glass = eb:CreateTexture(nil, "OVERLAY")
		glass:SetTexture(SEARCH_ICON)
		glass:SetSize(14, 14)
		glass:SetPoint("LEFT", left, "LEFT", 3, -1)
		eb:SetTextInsets(12, 0, 0, 0)
	end
end

-- Dropdowns: retail's "b" dropdown, cut into three so it stretches to any width.
local DROPDOWN_ART = {
	normal		= "common-dropdown-b-button",
	hover		= "common-dropdown-b-button-hover",
	pressed		= "common-dropdown-b-button-pressed",
	disabled	= "common-dropdown-b-button-disabled",
}
local DROPDOWN_CAP_L, DROPDOWN_CAP_R = 10, 28	-- of the art's 97px; the right cap holds the arrow

local function paintDropdown (skin, state)
	local info = D.atlasinfo[DROPDOWN_ART[state] or DROPDOWN_ART.normal]
	if not info then return end
	local file, w, l, r, t, b = info[1], info[2], info[4], info[5], info[6], info[7]
	local u1 = l + (r - l) * DROPDOWN_CAP_L / w
	local u2 = r - (r - l) * DROPDOWN_CAP_R / w
	skin.left:SetTexture(file);		skin.left:SetTexCoord(l, u1, t, b)
	skin.middle:SetTexture(file);	skin.middle:SetTexCoord(u1, u2, t, b)
	skin.right:SetTexture(file);	skin.right:SetTexCoord(u2, r, t, b)
end

local function skinDropdown (dd)
	local left, middle, right = named(dd, "Left"), named(dd, "Middle"), named(dd, "Right")
	local button = named(dd, "Button")
	left:SetAlpha(0); middle:SetAlpha(0); right:SetAlpha(0)

	-- The stock art is 64px tall around a 26px field that starts 17px below its top.
	local skin = {}
	skin.left = dd:CreateTexture(nil, "BACKGROUND")
	skin.left:SetPoint("TOPLEFT", left, "TOPLEFT", 16, -17)
	skin.left:SetSize(DROPDOWN_CAP_L, 26)
	skin.right = dd:CreateTexture(nil, "BACKGROUND")
	skin.right:SetPoint("TOPRIGHT", right, "TOPRIGHT", -15, -17)
	skin.right:SetSize(DROPDOWN_CAP_R, 26)
	skin.middle = dd:CreateTexture(nil, "BACKGROUND")
	skin.middle:SetPoint("TOPLEFT", skin.left, "TOPRIGHT")
	skin.middle:SetPoint("BOTTOMRIGHT", skin.right, "BOTTOMLEFT")
	paintDropdown(skin, "normal")

	-- The whole field opens the menu, as retail's does, not just the old arrow square.
	for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local tex = button[getter](button)
		if tex then tex:SetTexture(nil) end
	end
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", skin.left, "TOPLEFT")
	button:SetPoint("BOTTOMRIGHT", skin.right, "BOTTOMRIGHT")
	button:HookScript("OnEnter", function (self) if self:IsEnabled() == 1 then paintDropdown(skin, "hover") end end)
	button:HookScript("OnLeave", function (self) if self:IsEnabled() == 1 then paintDropdown(skin, "normal") end end)
	button:HookScript("OnMouseDown", function (self) if self:IsEnabled() == 1 then paintDropdown(skin, "pressed") end end)
	button:HookScript("OnMouseUp", function (self) if self:IsEnabled() == 1 then paintDropdown(skin, "hover") end end)
	button:HookScript("OnDisable", function () paintDropdown(skin, "disabled") end)
	button:HookScript("OnEnable", function () paintDropdown(skin, "normal") end)
end

local function isDropdown (frame)
	local button = named(frame, "Button")
	return button and named(frame, "Middle") and named(frame, "Left") and named(frame, "Right")
		and hasArt(named(frame, "Left"), "charactercreate%-labelframe")
end

local function isInput (eb)
	return named(eb, "Left") and named(eb, "Middle") and named(eb, "Right")
		and hasArt(named(eb, "Left"), "common%-input%-border")
end

local function skinScrollFrame (scroll)
	if not CP.ReskinScrollBar or not (named(scroll, "ScrollBar") and named(scroll, "ScrollBarScrollUpButton")) then
		return
	end
	-- The AH's lists carry their own groove art on the scroll frame, outside the slider.
	local regions = { scroll:GetRegions() }
	for i = 1, #regions do
		if hasArt(regions[i], "scrollbar") then regions[i]:Hide() end
	end
	-- Where the old 16px bar sat, just outside the list; the minimal one is 8px wide.
	CP.ReskinScrollBar(scroll, scroll, -7, 18, -7, true)
end

-- One walk over a frame and everything under it; each control is only ever skinned once.
local function skinTree (frame)
	local children = { frame:GetChildren() }
	for i = 1, #children do
		local child = children[i]
		if not child.atrDragonSkinned then
			child.atrDragonSkinned = true
			local kind = child:GetObjectType()
			if kind == "Button" then
				if isPanelButton(child) then
					D.SkinRedButton(child)
				elseif hasArt(child:GetNormalTexture(), "ui%-quickslot2") then
					skinQuickslot(child)
				elseif hasArt(named(child, "Left"), "whoframe%-columntabs") then
					skinSortHeader(child)
				elseif hasArt(child:GetNormalTexture(), "ui%-auctionframe%-filterbg") then
					skinFilterButton(child)
				end
			elseif kind == "CheckButton" then
				if CP.SkinCheckbox and hasArt(child:GetNormalTexture(), "ui%-checkbox%-up") then
					CP.SkinCheckbox(child)
				end
			elseif kind == "EditBox" then
				if isInput(child) then skinInput(child) end
			elseif kind == "ScrollFrame" then
				skinScrollFrame(child)
			elseif kind == "Frame" then
				if isDropdown(child) then skinDropdown(child) end
			end
		end
		skinTree(child)
	end
end

-----------------------------------------

local function stripeRows ()
	for _, spec in ipairs(ROWS) do
		for i = 1, spec[2] do
			local row = _G[spec[1] .. i]
			if row and not row.atrDragonStripe then
				row.atrDragonStripe = true
				-- The old name plate behind each item name; retail rows sit straight on the pane.
				local left, right = named(row, "Left"), named(row, "Right")
				if hasArt(left, "ui%-auctionitemnameframe") then left:SetAlpha(0) end
				if hasArt(right, "ui%-auctionitemnameframe") then right:SetAlpha(0) end
				if i % 2 == 0 then
					solid(row, "BACKGROUND", 1, 1, 1, 0.035):SetAllPoints(row)
				end
			end
		end
	end
end

local function skinAuctionatorPanel ()
	-- The panes already frame these; their own borders would draw a box inside the box.
	if Atr_Hlist then Atr_Hlist:SetBackdrop(nil) end
	if Atr_SellControls then Atr_SellControls:SetBackdrop(nil) end

	-- Its column headings sit on a 64px label plate; a header strip replaces the plate.
	local bar = Atr_HeadingsBar
	local plate = bar and _G["Atr_HeadingsBarMiddle"]
	if plate then
		plate:SetAlpha(0)
		-- On the bar itself, so the column labels it carries stay above the strip.
		local strip = solid(bar, "BACKGROUND", 0, 0, 0, 0.45)
		strip:SetHeight(20)
		strip:SetPoint("LEFT", bar, "LEFT", 4, 1)
		strip:SetPoint("RIGHT", bar, "RIGHT", -4, 1)
		local rule = solid(bar, "BORDER", 1, 0.82, 0, 0.35)
		rule:SetHeight(1)
		rule:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT")
		rule:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT")
	end
end

local function skinDialog (frame)
	if not frame or frame.atrDragonDialog then return end
	frame.atrDragonDialog = true

	-- Auctionator still calls SetBackdropColor on some of these; with no backdrop that's a no-op.
	frame:SetBackdrop(nil)
	tiled(frame, -8, ROCK):SetAllPoints(frame)
	NineSliceUtils.ApplyLayout(frame, NineSliceUtils.GetLayout("Dialog"))

	local regions = { frame:GetRegions() }
	for i = 1, #regions do
		if hasArt(regions[i], "ui%-dialogbox%-header") then regions[i]:Hide() end
	end

	skinTree(frame)
end

-----------------------------------------

local function hideClassicArt ()
	for _, piece in ipairs(CLASSIC_ART) do
		local tex = _G["AuctionFrame" .. piece]
		if tex then tex:Hide() end
	end
end

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

local function onTabChanged (frame)
	if frame ~= AuctionFrame then return end
	hideClassicArt()
	placePanes()
	layoutTabs()
	updateTitle()
end

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

	title = chrome:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", chrome, "TOP", 0, -5)
	title:SetPoint("LEFT", chrome, "LEFT", 60, 0)
	title:SetPoint("RIGHT", chrome, "RIGHT", -24, 0)
	title:SetHeight(16)
	title:SetJustifyH("CENTER")
	for _, name in ipairs(TITLES) do
		if _G[name] then _G[name]:SetAlpha(0) end
	end
	if AuctionatorTitle then
		AuctionatorTitle:SetAlpha(0)
		-- Auctionator names its pane after PanelTemplates_SetTab has already run.
		hooksecurefunc(AuctionatorTitle, "SetText", updateTitle)
	end

	-- Everything else is drawn on AuctionFrame, so it sits under every child panel for free.
	local rock = tiled(f, -8, ROCK)
	rock:SetPoint("TOPLEFT", chrome, "TOPLEFT", 2, -21)
	rock:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -2, 2)

	-- Between the rock and the marble: on Bids and Auctions the panes start inside the band.
	local streaks = f:CreateTexture(nil, "BACKGROUND", nil, -7)
	if D:SafeSetAtlas(streaks, "_UI-Frame-TopTileStreaks") then
		streaks:SetHorizTile(true)
		streaks:SetHeight(43)
		streaks:SetPoint("TOPLEFT", chrome, "TOPLEFT", 6, -21)
		streaks:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -2, -21)
	else
		streaks:Hide()
	end

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

	skinAuctionatorPanel()
	stripeRows()
	skinTree(f)
	for _, name in ipairs(DIALOGS) do
		skinDialog(_G[name])
	end
	if FilterButton_SetType then
		hooksecurefunc("FilterButton_SetType", onFilterType)
	end

	-- Both Blizzard's tab handler and Auctionator's replacement end up here, and so would a tab
	-- another addon adds later.
	hooksecurefunc("PanelTemplates_SetTab", onTabChanged)
	onTabChanged(f)
end

-- Atr_Init runs once, when Blizzard_AuctionUI loads; by then its tabs and panel exist and
-- Atr_LocalizeFrames has settled the button widths.
hooksecurefunc("Atr_Init", skinAuctionHouse)
