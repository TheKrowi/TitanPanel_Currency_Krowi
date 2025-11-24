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

local headerStack = {}; -- Stack to track nested headers
local headerOrder = {}; -- Track the order of top-level headers

local function GetNextCurrencyWithHeader(currencies, startIndex)
	local size = C_CurrencyInfo.GetCurrencyListSize();
	for i = startIndex, size do
		local info = C_CurrencyInfo.GetCurrencyListInfo(i);
		if info.isHeader then
			-- Maintain a stack of headers based on depth
			local depth = info.currencyListDepth;

			-- Trim stack to current depth (remove deeper levels when going back up)
			while #headerStack > depth do
				table.remove(headerStack);
			end

			-- Create header entry with metadata
			local headerEntry = {
				name = info.name,
				depth = depth,
				children = {},
				currencies = {}
			};

			if depth == 0 then
				-- Top-level header - track its order
				currencies[info.name] = headerEntry;
				tinsert(headerOrder, info.name);
				headerStack = {headerEntry};
			else
				-- Nested header - add to parent's children
				if headerStack[depth] then
					headerStack[depth].children[info.name] = headerEntry;
				end
				-- Add to stack at current depth
				headerStack[depth + 1] = headerEntry;
			end

			if not info.isHeaderExpanded then
				C_CurrencyInfo.ExpandCurrencyList(i, true);
				return false, i + 1;
			end
		elseif #headerStack > 0 and not (TitanGetVar(id, "CurrencyHideUnused") and info.isTypeUnused) then
			-- Add currency to the deepest current header
			local currentHeader = headerStack[#headerStack];
			if currentHeader then
				tinsert(currentHeader.currencies, info);
			end
		end
	end
	return true, size + 1;
end

local function GetAllCurrenciesWithHeader()
	local currencies = {}; -- GetAllMainHeaders();
	headerOrder = {}; -- Reset header order tracking
	local finished, nextIndex = false, 1;
	while not finished do
		finished, nextIndex = GetNextCurrencyWithHeader(currencies, nextIndex);
	end
	return currencies, headerOrder;
end

-- Helper function to check if a header has any currencies (including in children)
local function HeaderHasCurrencies(headerEntry)
	-- Check if this header has currencies
	if #headerEntry.currencies > 0 then
		return true;
	end
	
	-- Check if any child headers have currencies
	for _, childHeader in pairs(headerEntry.children) do
		if HeaderHasCurrencies(childHeader) then
			return true;
		end
	end
	
	return false;
end

-- Helper function to check if a header should be shown based on user settings
local function ShouldShowHeader(headerName)
	local settingKey = "ShowHeader_" .. headerName:gsub(" ", "_");
	local shouldShow = TitanGetVar(id, settingKey);
	-- Default to true if setting doesn't exist
	return shouldShow == nil or shouldShow;
end

-- Recursive function to display nested headers and currencies
local function DisplayHeaderRecursive(headerEntry, depth, abbreviateK, abbreviateM, thousandsSeparator, decimalSeparator)
	-- Don't display headers with no currencies
	if not HeaderHasCurrencies(headerEntry) then
		return;
	end
	
	-- If this header is disabled by user, skip it entirely (including its currencies and children)
	if not ShouldShowHeader(headerEntry.name) then
		return;
	end

	local indent = string.rep("  ", depth); -- Indent based on depth

	-- Display header name
	GameTooltip:AddLine(indent .. headerEntry.name);

	-- Display currencies in this header (sorted by name)
	if #headerEntry.currencies > 0 then
		local currencies = {};
		for _, currency in ipairs(headerEntry.currencies) do
			tinsert(currencies, currency);
		end
		table.sort(currencies, function(a, b) return a.name < b.name end);

		for _, currency in ipairs(currencies) do
			local quantity, abbr = AbbreviateValue(currency.quantity, abbreviateK, abbreviateM);
			quantity = TitanUtils_NumToString(quantity, thousandsSeparator, decimalSeparator);
			GameTooltip:AddDoubleLine(indent .. "  " .. currency.name, quantity .. abbr .. " |T" .. currency.iconFileID .. ":16|t", 1, 1, 1, 1, 1, 1);
		end
	end

	-- Recursively display child headers (only those with currencies)
	for childName, childHeader in pairs(headerEntry.children) do
		if HeaderHasCurrencies(childHeader) then
			DisplayHeaderRecursive(childHeader, depth + 1, abbreviateK, abbreviateM, thousandsSeparator, decimalSeparator);
		end
	end
end

local function GetAllCurrenciesWithHeaderSorted(self)
	local headers, orderedHeaderNames = GetAllCurrenciesWithHeader();
	local abbreviateK, abbreviateM = TitanGetVar(id, "CurrencyAbbreviate") == addon.L["1k"], TitanGetVar(id, "CurrencyAbbreviate") == addon.L["1m"];
	local thousandsSeparator, decimalSeparator = GetSeparators();

	-- Display top-level headers in their original order
	local hasDisplayedAnyHeader = false;
	for _, headerName in ipairs(orderedHeaderNames) do
		local headerEntry = headers[headerName];
		if headerEntry then
			-- Check if this header should be displayed before adding blank lines
			if HeaderHasCurrencies(headerEntry) and ShouldShowHeader(headerEntry.name) then
				-- Add blank line before header (except for the first one)
				if hasDisplayedAnyHeader then
					GameTooltip_AddBlankLineToTooltip(GameTooltip);
				end
				DisplayHeaderRecursive(headerEntry, 0, abbreviateK, abbreviateM, thousandsSeparator, decimalSeparator);
				hasDisplayedAnyHeader = true;
			end
		end
	end
end

-- Function to get all available headers (for menu creation)
local function GetAllAvailableHeaders()
	local headers = GetAllCurrenciesWithHeader();
	local headerList = {};
	
	local function AddHeadersRecursive(headerEntry, parentPath)
		local currentPath = parentPath and (parentPath .. " > " .. headerEntry.name) or headerEntry.name;
		tinsert(headerList, {
			name = headerEntry.name,
			path = currentPath,
			depth = headerEntry.depth
		});
		
		-- Add child headers
		for _, childHeader in pairs(headerEntry.children) do
			AddHeadersRecursive(childHeader, currentPath);
		end
	end
	
	-- Add all top-level headers and their children
	for _, headerEntry in pairs(headers) do
		AddHeadersRecursive(headerEntry);
	end
	
	-- Headers will be returned in their original order
	
	return headerList;
end

-- Function to recursively update all child headers
local function UpdateChildHeaders(headerEntry, newValue)
	-- Update all direct children
	for _, childHeader in pairs(headerEntry.children) do
		local childSettingKey = "ShowHeader_" .. childHeader.name:gsub(" ", "_");
		TitanSetVar(id, childSettingKey, newValue);
		-- Recursively update grandchildren
		UpdateChildHeaders(childHeader, newValue);
	end
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
		elseif not (TitanGetVar(id, "CurrencyHideUnused") and info.isTypeUnused) then
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

local function GetAllCurrenciesSorted()
	local currencies = GetAllCurrencies();
	local abbreviateK, abbreviateM = TitanGetVar(id, "CurrencyAbbreviate") == addon.L["1k"], TitanGetVar(id, "CurrencyAbbreviate") == addon.L["1m"];
	local thousandsSeparator, decimalSeparator = GetSeparators();

	table.sort(currencies, function(a, b) return a.name < b.name end);

	for _, currency in next, currencies do
		local quantity, abbr = AbbreviateValue(currency.quantity, abbreviateK, abbreviateM);
		quantity = TitanUtils_NumToString(quantity, thousandsSeparator, decimalSeparator);
		GameTooltip:AddDoubleLine(currency.name, quantity .. abbr .. " |T" .. currency.iconFileID .. ":16|t", 1, 1, 1, 1, 1, 1);
	end
end

local function GetAllCurrenciesTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_NONE");
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT");
	GameTooltip:AddLine(addon.Metadata.Title .. " " .. addon.Metadata.Version);
	GameTooltip_AddBlankLineToTooltip(GameTooltip);

	if TitanGetVar(id, "CurrencyGroupByHeader") then
		GetAllCurrenciesWithHeaderSorted(self);
	else
		GetAllCurrenciesSorted(self);
	end

	GameTooltip:Show();
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
		.. "in a tooltip, including a currency or gold shown on the Titan Panel bar.\n"
	
	-- Build savedVariables with dynamic header settings
	local savedVars = {
		MoneyLabel = addon.L["Icon"],
		MoneyAbbreviate = addon.L["None"],
		MoneyGoldOnly = false,
		MoneyColored = true,
		ThousandsSeparator = addon.L["Space"],
		CurrencyAbbreviate = addon.L["None"],
		CurrencyGroupByHeader = true,
		CurrencyHideUnused = true,
	};

	-- Initialize header visibility settings before creating registry
	local availableHeaders = GetAllAvailableHeaders();
	for _, headerInfo in ipairs(availableHeaders) do
		local settingKey = "ShowHeader_" .. headerInfo.name:gsub(" ", "_");
		-- Only set default if the setting doesn't exist yet
		if TitanGetVar(id, settingKey) == nil then
			savedVars[settingKey] = true;
		end
	end
	
	self.registry = {
		id = id,
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
		},
		savedVariables = savedVars
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

-- Generic checkbox creation function with optional custom onClick handler
local function CreateCheckbox(menu, text, setKey, resetKeys, customOnClick)
    return menu:CreateCheckbox(
        text,
        function()
            return TitanGetVar(id, setKey);
        end,
        customOnClick or function()
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

-- Create parent checkbox with cascading behavior using the generic function
local function CreateParentCheckbox(parentMenu, text, setKey, headerEntry)
	return CreateCheckbox(parentMenu, text, setKey, nil, function()
		local newValue = not TitanGetVar(id, setKey);
		TitanSetVar(id, setKey, newValue);
		-- Update all children with the same value
		UpdateChildHeaders(headerEntry, newValue);
		TitanPanelButton_UpdateButton(id);
	end);
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

-- Recursive function to create nested menu structure
local function CreateHeaderMenu(parentMenu, headerEntry)
	local settingKey = "ShowHeader_" .. headerEntry.name:gsub(" ", "_");
	local hasChildren = next(headerEntry.children) ~= nil;
	
	if not hasChildren then
		-- Simple checkbox for leaf headers
		CreateCheckbox(parentMenu, headerEntry.name, settingKey);
		return;
	end
	
	-- Create submenu for headers with children
	local headerSubmenu = addon.MenuUtil:CreateButton(parentMenu, headerEntry.name);
	
	-- Add checkbox for the header itself that cascades to children
	CreateParentCheckbox(headerSubmenu, "Show " .. headerEntry.name, settingKey, headerEntry);
	addon.MenuUtil:CreateDivider(headerSubmenu);
	
	-- Add child headers recursively
	for childName, childHeader in pairs(headerEntry.children) do
		CreateHeaderMenu(headerSubmenu, childHeader);
	end
	
	addon.MenuUtil:AddChildMenu(parentMenu, headerSubmenu);
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
	CreateCheckbox(menu, addon.L["Currency Group By Header"], "CurrencyGroupByHeader");
	CreateCheckbox(menu, addon.L["Currency Hide Unused"], "CurrencyHideUnused");

	local headerVisibility = addon.MenuUtil:CreateButton(menu, addon.L["Header Visibility"] or "Header Visibility");
	local structuredHeaders, orderedHeaderNames = GetAllCurrenciesWithHeader();
	for _, headerName in ipairs(orderedHeaderNames) do
		local headerEntry = structuredHeaders[headerName];
		if headerEntry then
			CreateHeaderMenu(headerVisibility, headerEntry);
		end
	end

	addon.MenuUtil:AddChildMenu(menu, headerVisibility);
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

local function OnEnter(self)
	GetAllCurrenciesTooltip(self);
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
     end);

     button:SetScript("OnEvent", function(self, event, ...)
          OnEvent(self, event, ...);
     end);

     button:SetScript("OnClick", function(self, mouseButton)
          OnClick(self, mouseButton);
          TitanPanelButton_OnClick(self, mouseButton);
     end);

     button:SetScript("OnEnter", function(self)
          OnEnter(self);
     end);
end

Create_Frames();