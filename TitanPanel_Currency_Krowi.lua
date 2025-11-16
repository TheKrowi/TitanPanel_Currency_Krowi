local addonName, addon = ...;

addon.L = LibStub(addon.Libs.AceLocale):GetLocale(addonName);
local titan = {};
titan.L = LibStub("AceLocale-3.0"):GetLocale("Titan", true);

local id = "Currency_Krowi"; -- Needs to be equal to this file's name without the "TitanPanel" prefix and ".lua" suffix

local function AbbreviateValue(value, abbreviateK, abbreviateM)
	if abbreviateK and value >= 1000 then
		return math.floor(value / 1000), "k";
	elseif abbreviateM and value >= 1000000 then
		return math.floor(value / 1000000), "m";
	end
	return value, "";
end

local function GetNextCurrency(currencies, startIndex)
	local size = C_CurrencyInfo.GetCurrencyListSize();
	for i = startIndex, size do
		local info = C_CurrencyInfo.GetCurrencyListInfo(i);
		if info.isHeader then
			if not info.isHeaderExpanded then
				C_CurrencyInfo.ExpandCurrencyList(i, true);
				return false, i + 1;
			end
		else
			tinsert(currencies, info);
		end
	end
	return true, size + 1;
end

local function GetAllCurrencies()
	local currencies, finished, nextIndex = {}, false, 1;
	while not finished do
		finished, nextIndex = GetNextCurrency(currencies, nextIndex);
	end
	return currencies;
end

local function GetSeparators()
	if (TitanGetVar(id, "ThousandsSeparator") == addon.L["Space"]) then
		return " ", ".";
	elseif (TitanGetVar(id, "ThousandsSeparator") == addon.L["Period"]) then
		return ".", ",";
	elseif (TitanGetVar(id, "ThousandsSeparator") == addon.L["Comma"]) then
		return ",", ".";
	end
	return "", "";
end

local function GetAllCurrenciesSorted()
	local currencies = GetAllCurrencies();
	local abbreviateK, abbreviateM = TitanGetVar(id, "CurrencyAbbreviate") == addon.L["1k"], TitanGetVar(id, "CurrencyAbbreviate") == addon.L["1m"];
	local thousandsSeparator, decimalSeparator = GetSeparators();

	table.sort(currencies, function(a, b) return a.name < b.name end);

	local line, tooltip = "", "";
	for _, currency in next, currencies do
		local quantity, abbr = AbbreviateValue(currency.quantity, abbreviateK, abbreviateM);
		quantity = TitanUtils_NumToString(quantity, thousandsSeparator, decimalSeparator);
		line = currency.name .. "\t" .. quantity .. abbr .. " |T" .. currency.iconFileID .. ":16|t"
		tooltip = strconcat(tooltip, line, "|r\n");
	end
	return tooltip;
end

local function BreakMoney(value)
	return math.floor(value / 10000), math.floor((value % 10000) / 100), value % 100;
end

local function MoneyToString(value, thousandsSeparator, decimalSeparator, moneyAbbreviateK, moneyAbbreviateM, label, goldOnly, colored)
	local gold, silver, copper, abbr = BreakMoney(value);

	gold, abbr = AbbreviateValue(gold, moneyAbbreviateK, moneyAbbreviateM);
	gold = TitanUtils_NumToString(gold, thousandsSeparator, decimalSeparator);

	local goldLabel, silverLabel, copperLabel = "", "", "";
	if label == addon.L["Text"] then
		goldLabel = titan.L["TITAN_GOLD_GOLD"];
		silverLabel = titan.L["TITAN_GOLD_SILVER"];
		copperLabel = titan.L["TITAN_GOLD_COPPER"];
	elseif label == addon.L["Icon"] then
		local font_size = TitanPanelGetVar("FontSize");
		local icon_pre = "|TInterface\\MoneyFrame\\";
		local icon_post = ":" .. font_size .. ":" .. font_size .. ":2:0|t";
		goldLabel = icon_pre .. "UI-GoldIcon" .. icon_post;
		silverLabel = icon_pre .. "UI-SilverIcon" .. icon_post;
		copperLabel = icon_pre .. "UI-CopperIcon" .. icon_post;
	end

	local colors = colored and Titan_Global.colors or {
        coin_gold = Titan_Global.colors.white,
        coin_silver = Titan_Global.colors.white,
        coin_copper = Titan_Global.colors.white,
    };

	local outstr = "|cff" .. colors.coin_gold .. gold .. abbr .. goldLabel .. "|r";

	if not goldOnly then
		outstr = outstr .. " " .. "|cff" .. colors.coin_silver .. silver .. silverLabel .. "|r";
		outstr = outstr .. " " .. "|cff" .. colors.coin_copper .. copper .. copperLabel .. "|r";
	end

	return outstr;
end

local function FormatMoney(value)
	local thousandsSeparator, decimalSeparator = GetSeparators();

	return MoneyToString(value, thousandsSeparator, decimalSeparator,
		TitanGetVar(id, "MoneyAbbreviate") == addon.L["1k"],
		TitanGetVar(id, "MoneyAbbreviate") == addon.L["1m"],
		TitanGetVar(id, "MoneyLabel"),
		TitanGetVar(id, "MoneyGoldOnly"),
		TitanGetVar(id, "MoneyColored"));
end

local function GetFormattedMoney()
    return (FormatMoney(GetMoney()));
end

local function LoadButton(self)
	local notes = ""
		.. "Displays all in-game currencies for your current character\n"
		.. "in a tooltip, including gold shown on the Titan Panel bar.\n"
	self.registry = {
		id = id,
		category = "Information",
		version = addon.Metadata.Version,
		menuText = addon.L["Currency by Krowi"],
		-- menuTextFunction = CreateMenu,
		tooltipTitle = addon.L["Currency Info"],
		tooltipTextFunction = GetAllCurrenciesSorted,
		buttonTextFunction = GetFormattedMoney,
		icon = "Interface\\AddOns\\TitanGold\\Artwork\\TitanGold",
		iconWidth = 16,
		notes = notes,
		controlVariables = {
			ShowIcon = true,
			-- ShowLabelText = true,
			-- ShowRegularText = false,
			DisplayOnRightSide = true,
		},
		savedVariables = {
			MoneyLabel = addon.L["Icon"],
			MoneyAbbreviate = addon.L["None"],
			MoneyGoldOnly = false,
			MoneyColored = true,
			ThousandsSeparator = addon.L["Space"],
			CurrencyAbbreviate = addon.L["None"],
			-- Initialized = true,
			-- DisplayGoldPerHour = true,
			-- SortByName = true,
			-- ViewAll = true,
			-- ShowIcon = true,
			-- ShowLabelText = false,
			-- DisplayOnRightSide = false,
			-- MergeServers = false,
			-- SeparateServers = true,
			-- AllServers = false,
			-- IgnoreFaction = false,
			-- GroupByRealm = false,
			-- gold = { total = "112233", neg = false },
			-- ShowSessionInfo = true,
			-- ShowWarband = true,
		}
	};

	self:RegisterEvent("PLAYER_MONEY");
end

local function OnEvent(self, event, a1, ...)
     if event == "PLAYER_MONEY" then
          TitanPanelButton_UpdateButton(id);
     end
end

local function OnShow(self)
    self:RegisterEvent("PLAYER_MONEY");
end

local function OnHide(self)
    self:UnregisterEvent("PLAYER_MONEY");
end

local function CreateCheckbox(menu, text, setKey, resetKeys)
    menu:CreateCheckbox(
        text,
        function()
            return TitanGetVar(id, setKey);
        end,
        function()
            TitanSetVar(id, setKey, not TitanGetVar(id, setKey));
			if resetKeys then
				for _, key in pairs(resetKeys) do
					TitanSetVar(id, key, false);
				end
			end
			TitanPanelButton_UpdateButton(id);
        end
    );
end

local function CreateRadio(menu, text, setKey)
    local button = menu:CreateRadio(
        text,
        function()
            return TitanGetVar(id, setKey) == text;
        end,
        function()
            TitanSetVar(id, setKey, text);
			TitanPanelButton_UpdateButton(id);
        end
    );
    button:SetResponse(MenuResponse.Refresh);
end

local function CreateMenu(self, menu)
	addon.MenuUtil:CreateTitle(menu, addon.L["Currency by Krowi"]);
	local moneyLabel = addon.MenuUtil:CreateButton(menu, addon.L["Money Label"]);
	CreateRadio(moneyLabel, addon.L["None"], "MoneyLabel");
	CreateRadio(moneyLabel, addon.L["Text"], "MoneyLabel");
	CreateRadio(moneyLabel, addon.L["Icon"], "MoneyLabel");
	addon.MenuUtil:AddChildMenu(menu, moneyLabel);
	local moneyAbbreviate = addon.MenuUtil:CreateButton(menu, addon.L["Money Abbreviate"]);
	CreateRadio(moneyAbbreviate, addon.L["None"], "MoneyAbbreviate");
	CreateRadio(moneyAbbreviate, addon.L["1k"], "MoneyAbbreviate");
	CreateRadio(moneyAbbreviate, addon.L["1m"], "MoneyAbbreviate");
	addon.MenuUtil:AddChildMenu(menu, moneyAbbreviate);
	CreateCheckbox(menu, addon.L["Money Gold Only"], "MoneyGoldOnly");
	CreateCheckbox(menu, addon.L["Money Colored"], "MoneyColored");
	addon.MenuUtil:CreateDivider(menu);
	local thousandsSeparator = addon.MenuUtil:CreateButton(menu, addon.L["Thousands Separator"]);
	CreateRadio(thousandsSeparator, addon.L["Space"], "ThousandsSeparator");
	CreateRadio(thousandsSeparator, addon.L["Period"], "ThousandsSeparator");
	CreateRadio(thousandsSeparator, addon.L["Comma"], "ThousandsSeparator");
	addon.MenuUtil:AddChildMenu(menu, thousandsSeparator);
	addon.MenuUtil:CreateDivider(menu);
	local currencyAbbreviate = addon.MenuUtil:CreateButton(menu, addon.L["Currency Abbreviate"]);
	CreateRadio(currencyAbbreviate, addon.L["None"], "CurrencyAbbreviate");
	CreateRadio(currencyAbbreviate, addon.L["1k"], "CurrencyAbbreviate");
	CreateRadio(currencyAbbreviate, addon.L["1m"], "CurrencyAbbreviate");
	addon.MenuUtil:AddChildMenu(menu, currencyAbbreviate);
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
		MenuUtil.CreateContextMenu(self, function(owner, menu)
			menu:SetTag("KTPC_RIGHT_CLICK_MENU_OPTIONS");
			CreateMenu(self, menu);
		end);
	else
		local rightClickMenu = LibStub("Krowi_Menu-1.0");
		rightClickMenu:Clear();
		CreateMenu(self, rightClickMenu);
		rightClickMenu:Open();
	end
end

local function Create_Frames()
     local buttonName = "TitanPanel" .. id .. "Button";
     if _G[buttonName] then
          return;
     end

     local container = CreateFrame("Frame", nil, UIParent);
     local button = CreateFrame("Button", buttonName, container, "TitanPanelComboTemplate");
     button:SetFrameStrata("FULLSCREEN");

     LoadButton(button);

     button:SetScript("OnShow", function(self)
          OnShow(self);
          TitanPanelButton_OnShow(self);
     end);

     button:SetScript("OnHide", function(self)
          OnHide(self);
     end)

     button:SetScript("OnEvent", function(self, event, ...)
          OnEvent(self, event, ...);
     end);

     button:SetScript("OnClick", function(self, mouseButton)
          OnClick(self, mouseButton);
          TitanPanelButton_OnClick(self, mouseButton);
     end);
end

Create_Frames();