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
	MaxCharacters = 20,
	DefaultTooltip = addon.L["Currency"],
	ButtonDisplay = addon.L["Character Gold"],
	TrackSessionGold = true,
	SessionDuration = 3600,
	SessionActivityCheckInterval = 600
};

KrowiTPC_SavedData = KrowiTPC_SavedData or {
	CharacterData = {},
	SessionProfit = 0,
	SessionSpent = 0,
	SessionLastUpdate = 0
};

local activityCheckTimer = nil;

local function CheckSessionExpiration()
	local currentTime = time();
	local lastUpdate = KrowiTPC_SavedData.SessionLastUpdate or 0;
	local duration = KrowiTPC_Options.SessionDuration or 3600;
	
	if currentTime - lastUpdate > duration then
		KrowiTPC_SavedData.SessionProfit = 0;
		KrowiTPC_SavedData.SessionSpent = 0;
		KrowiTPC_SavedData.SessionLastUpdate = currentTime;
		return true;
	end
	return false;
end

local function UpdateSessionActivity()
	KrowiTPC_SavedData.SessionLastUpdate = time();
end

function addon.GetSessionProfit()
	return KrowiTPC_SavedData.SessionProfit or 0;
end

function addon.GetSessionSpent()
	return KrowiTPC_SavedData.SessionSpent or 0;
end

function addon.ResetSessionTracking()
	KrowiTPC_SavedData.SessionProfit = 0;
	KrowiTPC_SavedData.SessionSpent = 0;
	KrowiTPC_SavedData.SessionLastUpdate = time();
end

function addon.GetSessionDuration()
	return KrowiTPC_Options.SessionDuration or 3600;
end

function addon.SetSessionDuration(seconds)
	KrowiTPC_Options.SessionDuration = math.max(3600, seconds);
end

local GetMoney = GetMoney;
local IsShiftKeyDown = IsShiftKeyDown;

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
		local money = C_Bank.FetchDepositedMoney(Enum.BankType.Account);
		if type(money) == "number" then
			warbandMoney = money;
		end
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
	local characterData = KrowiTPC_SavedData.CharacterData or {};

	if displayMode == addon.L["Character Gold"] then
		return nil, addon.FormatMoney(GetMoney());
	elseif displayMode == addon.L["Current Faction Total"] then
		local factionTotal = 0;
		for _, char in pairs(characterData) do
			if char.faction == currentFaction then
				factionTotal = factionTotal + (char.money or 0);
			end
		end
		return nil, addon.FormatMoney(factionTotal);
	elseif displayMode == addon.L["Realm Total"] then
		local realmTotal = 0;
		for _, char in pairs(characterData) do
			if char.realm == currentRealmName then
				realmTotal = realmTotal + (char.money or 0);
			end
		end
		return nil, addon.FormatMoney(realmTotal);
	elseif displayMode == addon.L["Account Total"] then
		local accountTotal = 0;
		for _, char in pairs(characterData) do
			accountTotal = accountTotal + (char.money or 0);
		end
		local warbandMoney = addon.GetWarbandMoney();
		return nil, addon.FormatMoney(accountTotal + warbandMoney);
	elseif displayMode == addon.L["Warband Bank"] then
		local warbandMoney = addon.GetWarbandMoney();
		return nil, addon.FormatMoney(warbandMoney);
	else
		return nil, addon.FormatMoney(GetMoney());
	end
end

local function LoadButton(self)
	local notes = ""
		.. "Displays gold and currencies with flexible options:\n"
		.. "• Multiple display modes: Character, Faction, Realm, Account, or Warband Bank gold\n"
		.. "• Session tracking: Monitor earned and spent gold with configurable duration\n"
		.. "• Combined tooltips: View money and currencies together with modifier keys\n"
		.. "• Character tracking: See gold across all characters with faction/realm totals\n"
		.. "• Currency management: Group by headers, hide unused, and customize visibility\n"

	self.registry = {
		id = addon.Metadata.TitanPanelId,
		category = "Information",
		version = addon.Metadata.Version,
		menuText = addon.L["Currency by Krowi"],
		buttonTextFunction = GetFormattedMoney,
		icon = "Interface\\AddOns\\TitanGold\\Artwork\\TitanGold",
		iconWidth = 16,
		notes = notes,
		controlVariables = {
			ShowIcon = true,
			DisplayOnRightSide = true,
			ShowLabelText = true,
		},
		savedVariables = {
			ShowIcon = false,
			DisplayOnRightSide = false,
			ShowLabelText = false,
		}
	};
end

function addon.GetHeaderSettingKey(headerName)
	return "ShowHeader_" .. headerName:gsub(" ", "_");
end

local function UpdateCharacterData()
	local playerName = UnitName("player") or "Unknown";
	local realmName = GetRealmName() or "Unknown";
	local currentMoney = GetMoney();
	local faction = UnitFactionGroup("player") or "Neutral";
	local _, className = UnitClass("player");
	local characterKey = playerName .. "-" .. realmName;

	local characterData = KrowiTPC_SavedData.CharacterData or {};

	local oldData = characterData[characterKey];
	local oldMoney = (oldData and oldData.money) or currentMoney;
	
	local change = currentMoney - oldMoney;
	if change ~= 0 and KrowiTPC_Options.TrackSessionGold then
		if change > 0 then
			KrowiTPC_SavedData.SessionProfit = (KrowiTPC_SavedData.SessionProfit or 0) + change;
		elseif change < 0 then
			KrowiTPC_SavedData.SessionSpent = (KrowiTPC_SavedData.SessionSpent or 0) - change;
		end
		UpdateSessionActivity();
	end

	characterData[characterKey] = {
		name = playerName,
		realm = realmName,
		money = currentMoney,
		faction = faction,
		className = className,
	};

	KrowiTPC_SavedData.CharacterData = characterData;
end

local sessionDataLoaded = false;

local function OnEvent(self, event, ...)
	if event == "PLAYER_MONEY" or event == "SEND_MAIL_MONEY_CHANGED" or 
	   event == "SEND_MAIL_COD_CHANGED" or event == "PLAYER_TRADE_MONEY" or 
	   event == "TRADE_MONEY_CHANGED" then
		UpdateCharacterData();
		TitanPanelButton_UpdateButton(addon.Metadata.TitanPanelId);
	elseif event == "PLAYER_ENTERING_WORLD" then
		if not sessionDataLoaded then
			CheckSessionExpiration();
			sessionDataLoaded = true;
			
			if not activityCheckTimer then
				local interval = KrowiTPC_Options.SessionActivityCheckInterval or 600;
				activityCheckTimer = C_Timer.NewTicker(interval, function()
					UpdateSessionActivity();
				end);
			end
		end
		
		UpdateCharacterData();
	end
end

local function OnShow(self)
    self:RegisterEvent("PLAYER_MONEY");
	self:RegisterEvent("SEND_MAIL_MONEY_CHANGED");
	self:RegisterEvent("SEND_MAIL_COD_CHANGED");
	self:RegisterEvent("PLAYER_TRADE_MONEY");
	self:RegisterEvent("TRADE_MONEY_CHANGED");
	TitanPanelButton_OnShow(self);
end

local function OnHide(self)
    self:UnregisterEvent("PLAYER_MONEY");
	self:UnregisterEvent("SEND_MAIL_MONEY_CHANGED");
	self:UnregisterEvent("SEND_MAIL_COD_CHANGED");
	self:UnregisterEvent("PLAYER_TRADE_MONEY");
	self:UnregisterEvent("TRADE_MONEY_CHANGED");
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
		local ctrlPressed = IsLeftControlKeyDown() or IsRightControlKeyDown();
		
		if defaultTooltip == addon.L["Combined"] then
			if ctrlPressed then
				tooltipType = addon.L["Currency"];
			elseif shiftPressed then
				tooltipType = addon.L["Money"];
			else
				tooltipType = addon.L["Combined"];
			end
		elseif defaultTooltip == addon.L["Money"] then
			tooltipType = shiftPressed and addon.L["Currency"] or addon.L["Money"];
		else
			tooltipType = shiftPressed and addon.L["Money"] or addon.L["Currency"];
		end
	end

	if tooltipType == addon.L["Money"] then
		addon.Tooltip.GetDetailedMoneyTooltip(self);
	elseif tooltipType == addon.L["Combined"] then
		addon.Tooltip.GetCombinedTooltip(self);
	else
		addon.Tooltip.GetAllCurrenciesTooltip(self);
	end
end

local function OnEnter(self)
	ShowTooltip(self);

	local lastShiftState = IsShiftKeyDown();
	local lastCtrlState = IsLeftControlKeyDown() or IsRightControlKeyDown();
	local throttle = 0;
	self:SetScript("OnUpdate", function(frame, elapsed)
		throttle = throttle + elapsed;
		if throttle < 0.1 then return; end
		throttle = 0;
		
		local currentShiftState = IsShiftKeyDown();
		local currentCtrlState = IsLeftControlKeyDown() or IsRightControlKeyDown();
		if currentShiftState ~= lastShiftState or currentCtrlState ~= lastCtrlState then
			lastShiftState = currentShiftState;
			lastCtrlState = currentCtrlState;
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
	
	button:RegisterEvent("PLAYER_ENTERING_WORLD");
end

Create_Frames();