local addonName, addon = ...;

addon.L = LibStub(addon.Libs.AceLocale):GetLocale(addonName);
local titan = {};
titan.L = LibStub("AceLocale-3.0"):GetLocale("Titan", true);

-- Initialize custom SavedVariables for all settings
KrowiTPC_Options = KrowiTPC_Options or {
	HeaderSettings = {},
	MoneyLabel = addon.L["Icon"],
	MoneyAbbreviate = addon.L["None"],
	ThousandsSeparator = addon.L["Space"],
	CurrencyAbbreviate = addon.L["None"],
	MoneyGoldOnly = false,
	MoneyColored = true,
	CurrencyGroupByHeader = true,
	CurrencyHideUnused = true,
	TrackAllRealms = true,
	CharacterData = {},
	MaxCharacters = 20,
	DefaultTooltip = addon.L["Currency"],
	ButtonDisplay = addon.L["Character Gold"]
};

-- Local references for better performance
local GetMoney = GetMoney;

function addon.AbbreviateValue(value, abbreviateK, abbreviateM)
	if abbreviateK and value >= 1000 then
		return math.floor(value / 1000), "k";
	elseif abbreviateM and value >= 1000000 then
		return math.floor(value / 1000000), "m";
	end
	return value, "";
end

function addon.GetSeparators()
	if (KrowiTPC_Options.ThousandsSeparator == addon.L["Space"]) then
		return " ", ".";
	elseif (KrowiTPC_Options.ThousandsSeparator == addon.L["Period"]) then
		return ".", ",";
	elseif (KrowiTPC_Options.ThousandsSeparator == addon.L["Comma"]) then
		return ",", ".";
	end
	return "", "";
end

function addon.GetWarbandMoney()
	local warbandMoney = 0;
	if C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType then
		warbandMoney = C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0;
	end
	return warbandMoney;
end

local function BreakMoney(value)
	return math.floor(value / 10000), math.floor((value % 10000) / 100), value % 100;
end

function addon.FormatMoney(value)
	local thousandsSeparator, decimalSeparator = addon.GetSeparators();

	local gold, silver, copper, abbr = BreakMoney(value);

	local moneyAbbreviateK = KrowiTPC_Options.MoneyAbbreviate == addon.L["1k"];
	local moneyAbbreviateM = KrowiTPC_Options.MoneyAbbreviate == addon.L["1m"];
	gold, abbr = addon.AbbreviateValue(gold, moneyAbbreviateK, moneyAbbreviateM);
	gold = TitanUtils_NumToString(gold, thousandsSeparator, decimalSeparator);

	local goldLabel, silverLabel, copperLabel = "", "", "";
	if KrowiTPC_Options.MoneyLabel == addon.L["Text"] then
		goldLabel = titan.L["TITAN_GOLD_GOLD"];
		silverLabel = titan.L["TITAN_GOLD_SILVER"];
		copperLabel = titan.L["TITAN_GOLD_COPPER"];
	elseif KrowiTPC_Options.MoneyLabel == addon.L["Icon"] then
		local font_size = TitanPanelGetVar("FontSize");
		local icon_pre = "|TInterface\\MoneyFrame\\";
		local icon_post = ":" .. font_size .. ":" .. font_size .. ":2:0|t";
		goldLabel = icon_pre .. "UI-GoldIcon" .. icon_post;
		silverLabel = icon_pre .. "UI-SilverIcon" .. icon_post;
		copperLabel = icon_pre .. "UI-CopperIcon" .. icon_post;
	end

	local colors = KrowiTPC_Options.MoneyColored and Titan_Global.colors or {
        coin_gold = Titan_Global.colors.white,
        coin_silver = Titan_Global.colors.white,
        coin_copper = Titan_Global.colors.white,
    };

	local outstr = "|cff" .. colors.coin_gold .. gold .. abbr .. goldLabel .. "|r";

	if not KrowiTPC_Options.MoneyGoldOnly then
		outstr = outstr .. " " .. "|cff" .. colors.coin_silver .. silver .. silverLabel .. "|r";
		outstr = outstr .. " " .. "|cff" .. colors.coin_copper .. copper .. copperLabel .. "|r";
	end

	return outstr;
end

local function GetFormattedMoney()
	local displayMode = KrowiTPC_Options.ButtonDisplay;
	local currentRealmName = GetRealmName() or "Unknown";
	local currentFaction = UnitFactionGroup("player") or "Neutral";
	local characterData = KrowiTPC_Options.CharacterData or {};
	
	if displayMode == addon.L["Character Gold"] then
		return addon.FormatMoney(GetMoney());
	elseif displayMode == addon.L["Current Faction Total"] then
		local factionTotal = 0;
		for _, char in pairs(characterData) do
			if char.faction == currentFaction then
				factionTotal = factionTotal + (char.money or 0);
			end
		end
		return addon.FormatMoney(factionTotal);
	elseif displayMode == addon.L["Realm Total"] then
		local realmTotal = 0;
		for _, char in pairs(characterData) do
			if char.realm == currentRealmName then
				realmTotal = realmTotal + (char.money or 0);
			end
		end
		return addon.FormatMoney(realmTotal);
	elseif displayMode == addon.L["Account Total"] then
		local accountTotal = 0;
		for _, char in pairs(characterData) do
			accountTotal = accountTotal + (char.money or 0);
		end
		local warbandMoney = addon.GetWarbandMoney();
		return addon.FormatMoney(accountTotal + warbandMoney);
	elseif displayMode == addon.L["Warband Bank"] then
		local warbandMoney = addon.GetWarbandMoney();
		return addon.FormatMoney(warbandMoney);
	else
		return addon.FormatMoney(GetMoney());
	end
end

local function LoadButton(self)
	local notes = ""
		.. "Displays all in-game currencies for your current character\n"
		.. "in a tooltip, including a currency or gold shown on the Titan Panel bar.\n"

	self.registry = {
		id = addon.Metadata.TitanPanelId,
		category = "Information",
		version = addon.Metadata.Version,
		menuText = addon.L["Currency by Krowi"],
		-- menuTextFunction = CreateMenu,
		tooltipTitle = addon.L["Currency Info"],
		-- tooltipTextFunction = GetAllCurrenciesTooltip,
		buttonTextFunction = GetFormattedMoney,
		icon = "Interface\\AddOns\\TitanGold\\Artwork\\TitanGold",
		iconWidth = 16,
		notes = notes,
		controlVariables = {
			ShowIcon = true,
			-- ShowLabelText = true,
			-- ShowRegularText = false,
			DisplayOnRightSide = true,
		}
	};

	self:RegisterEvent("PLAYER_MONEY");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
end

-- Update character money data
local function UpdateCharacterData()
	local playerName = UnitName("player") or "Unknown";
	local realmName = GetRealmName() or "Unknown";
	local currentMoney = GetMoney();
	local faction = UnitFactionGroup("player") or "Neutral";
	local _, className = UnitClass("player");
	local classColor = RAID_CLASS_COLORS[className] or {r = 1, g = 1, b = 1};

	local characterKey = playerName .. "-" .. realmName;

	-- Get or create character data table
	local characterData = KrowiTPC_Options.CharacterData or {};

	-- Update character information
	characterData[characterKey] = {
		name = playerName,
		realm = realmName,
		money = currentMoney,
		faction = faction,
		className = className,
		classColor = classColor,
		lastUpdate = time(),
		level = UnitLevel("player") or 1
	};

	-- Save updated data
	KrowiTPC_Options.CharacterData = characterData;
end

local function OnEvent(self, event, ...)
	if event == "PLAYER_MONEY" then
		UpdateCharacterData();
		TitanPanelButton_UpdateButton(addon.Metadata.TitanPanelId);
	elseif event == "PLAYER_ENTERING_WORLD" then
		UpdateCharacterData();
	end
end

local function OnShow(self)
    self:RegisterEvent("PLAYER_MONEY");
    self:RegisterEvent("PLAYER_ENTERING_WORLD");
	TitanPanelButton_OnShow(self);
end

local function OnHide(self)
    self:UnregisterEvent("PLAYER_MONEY");
    self:UnregisterEvent("PLAYER_ENTERING_WORLD");
end

local function OnClick(self, button)
	if button == "LeftButton" then
		ToggleAllBags();
		return;
	end

	if button ~= "RightButton" then
		return;
	end

	if addon.Util.IsTheWarWithin then
		MenuUtil.CreateContextMenu(self, function(owner, menuObj)
			menuObj:SetTag("KTPC_RIGHT_CLICK_MENU_OPTIONS");
			addon.Menu.CreateMenu(self, menuObj);
		end);
	else
		local rightClickMenu = LibStub("Krowi_Menu-1.0");
		rightClickMenu:Clear();
		addon.Menu.CreateMenu(self, rightClickMenu);
		rightClickMenu:Open();
	end
	TitanPanelButton_OnClick(self, button);
end

local function ShowTooltip(self, forceType)
	local tooltipType = forceType;
	if not tooltipType then
		local defaultTooltip = KrowiTPC_Options.DefaultTooltip;
		local shiftPressed = IsShiftKeyDown();
		
		if defaultTooltip == addon.L["Money"] then
			tooltipType = shiftPressed and addon.L["Currency"] or addon.L["Money"];
		else
			tooltipType = shiftPressed and addon.L["Money"] or addon.L["Currency"];
		end
	end

	if tooltipType == addon.L["Money"] then
		addon.Tooltip.GetDetailedMoneyTooltip(self);
	else
		addon.Tooltip.GetAllCurrenciesTooltip(self);
	end
end

local function OnEnter(self)
	ShowTooltip(self);

	local lastShiftState = IsShiftKeyDown();
	self:SetScript("OnUpdate", function(frame)
		local currentShiftState = IsShiftKeyDown();
		if currentShiftState ~= lastShiftState then
			lastShiftState = currentShiftState;
			ShowTooltip(frame);
		end
	end);
end

local function OnLeave(self)
	GameTooltip:Hide();
	self:SetScript("OnUpdate", nil);
end

local function Create_Frames()
	local buttonName = "TitanPanel" .. addon.Metadata.TitanPanelId .. "Button";
	if _G[buttonName] then
		return;
	end

	local container = CreateFrame("Frame", nil, UIParent);
	local button = CreateFrame("Button", buttonName, container, "TitanPanelComboTemplate");
	button:SetFrameStrata("FULLSCREEN");

	LoadButton(button);

	button:SetScript("OnEvent", OnEvent);
	button:SetScript("OnShow", OnShow);
	button:SetScript("OnHide", OnHide);
	button:SetScript("OnClick", OnClick);
	button:SetScript("OnEnter", OnEnter);
	button:SetScript("OnLeave", OnLeave);
end

Create_Frames();