local _, addon = ...;

local menu = {};
addon.Menu = menu;

-- Local references for better performance
local TitanPanelButton_UpdateButton = TitanPanelButton_UpdateButton;

-- Standardized Checkbox System
local CheckboxMixin = {};

function CheckboxMixin:KeyIsTrue(filters, keys)
	return addon.Util.ReadNestedKeys(filters, keys);
end

function CheckboxMixin:KeyEqualsText(text, filters, keys)
	return addon.Util.ReadNestedKeys(filters, keys) == text;
end

function CheckboxMixin:SetSelected(filters, keys, value)
	addon.Util.WriteNestedKeys(filters, keys, value);
	TitanPanelButton_UpdateButton(addon.Metadata.TitanPanelId);
end

function CheckboxMixin:OnRadioSelect(text, filters, keys)
	self:SetSelected(filters, keys, text);
end

function CheckboxMixin:OnCheckboxSelect(filters, keys)
	self:SetSelected(filters, keys, not self:KeyIsTrue(filters, keys));
end

function CheckboxMixin:CreateCheckbox(menuObj, text, filters, keys, defaultValue)
	return menuObj:CreateCheckbox(
		text,
		function()
			local value = self:KeyIsTrue(filters, keys);
			return value == nil and defaultValue or value;
		end,
		function()
			self:OnCheckboxSelect(filters, keys);
		end
	);
end

-- Unified checkbox function for both header and custom settings
local function CreateKrowiCheckbox(menuObj, text, keyPath, defaultValue, resetKeys, customOnClick)
	if customOnClick then
		return menuObj:CreateCheckbox(
			text,
			function()
				local value = CheckboxMixin:KeyIsTrue(KrowiTPC_Options, keyPath);
				return value == nil and defaultValue or value;
			end,
			customOnClick
		);
	else
		return CheckboxMixin:CreateCheckbox(menuObj, text, KrowiTPC_Options, keyPath, defaultValue);
	end
end

-- Create parent checkbox with cascading behavior using custom header settings
local function CreateParentHeaderCheckbox(parentMenu, text, setKey, headerEntry)
	return CreateKrowiCheckbox(parentMenu, text, {"HeaderSettings", setKey}, true, nil, function()
		local keyPath = {"HeaderSettings", setKey};
		local currentValue = CheckboxMixin:KeyIsTrue(KrowiTPC_Options, keyPath);
		local newValue = not (currentValue == nil and true or currentValue);
		CheckboxMixin:SetSelected(KrowiTPC_Options, keyPath, newValue);
		-- Update all children with the same value
		addon.Currency.UpdateChildHeaders(headerEntry, newValue);
	end);
end

-- Improved radio function following KrowiAF pattern
local function CreateRadio(menuObj, text, keyPath)
    local button = menuObj:CreateRadio(
        text,
        function()
            return CheckboxMixin:KeyEqualsText(text, KrowiTPC_Options, keyPath);
        end,
        function()
            CheckboxMixin:OnRadioSelect(text, KrowiTPC_Options, keyPath);
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
		CreateKrowiCheckbox(parentMenu, headerEntry.name, {"HeaderSettings", settingKey}, true);
		return;
	end
	
	-- Create submenu for headers with children
	local headerSubmenu = addon.MenuUtil:CreateButton(parentMenu, headerEntry.name);
	
	-- Add checkbox for the header itself that cascades to children
	CreateParentHeaderCheckbox(headerSubmenu, "Show " .. headerEntry.name, settingKey, headerEntry);
	addon.MenuUtil:CreateDivider(headerSubmenu);
	
	-- Add child headers recursively
	for _, childHeader in pairs(headerEntry.children) do
		CreateHeaderMenu(headerSubmenu, childHeader);
	end
	
	addon.MenuUtil:AddChildMenu(parentMenu, headerSubmenu);
end

function menu.CreateMenu(self, menuObj)
	addon.MenuUtil:CreateTitle(menuObj, addon.L["Currency by Krowi"]);
	local moneyLabel = addon.MenuUtil:CreateButton(menuObj, addon.L["Money Label"]);
	CreateRadio(moneyLabel, addon.L["None"], {"MoneyLabel"});
	CreateRadio(moneyLabel, addon.L["Text"], {"MoneyLabel"});
	CreateRadio(moneyLabel, addon.L["Icon"], {"MoneyLabel"});
	addon.MenuUtil:AddChildMenu(menuObj, moneyLabel);
	local moneyAbbreviate = addon.MenuUtil:CreateButton(menuObj, addon.L["Money Abbreviate"]);
	CreateRadio(moneyAbbreviate, addon.L["None"], {"MoneyAbbreviate"});
	CreateRadio(moneyAbbreviate, addon.L["1k"], {"MoneyAbbreviate"});
	CreateRadio(moneyAbbreviate, addon.L["1m"], {"MoneyAbbreviate"});
	addon.MenuUtil:AddChildMenu(menuObj, moneyAbbreviate);
	CreateKrowiCheckbox(menuObj, addon.L["Money Gold Only"], {"MoneyGoldOnly"}, false);
	CreateKrowiCheckbox(menuObj, addon.L["Money Colored"], {"MoneyColored"}, true);
	local buttonDisplay = addon.MenuUtil:CreateButton(menuObj, addon.L["Button Display"]);
	CreateRadio(buttonDisplay, addon.L["Character Gold"], {"ButtonDisplay"});
	CreateRadio(buttonDisplay, addon.L["Current Faction Total"], {"ButtonDisplay"});
	CreateRadio(buttonDisplay, addon.L["Realm Total"], {"ButtonDisplay"});
	CreateRadio(buttonDisplay, addon.L["Account Total"], {"ButtonDisplay"});
	CreateRadio(buttonDisplay, addon.L["Warband Bank"], {"ButtonDisplay"});
	addon.MenuUtil:AddChildMenu(menuObj, buttonDisplay);
	local defaultTooltip = addon.MenuUtil:CreateButton(menuObj, addon.L["Default Tooltip"]);
	CreateRadio(defaultTooltip, addon.L["Currency"], {"DefaultTooltip"});
	CreateRadio(defaultTooltip, addon.L["Money"], {"DefaultTooltip"});
	addon.MenuUtil:AddChildMenu(menuObj, defaultTooltip);
	addon.MenuUtil:CreateDivider(menuObj);
	local thousandsSeparator = addon.MenuUtil:CreateButton(menuObj, addon.L["Thousands Separator"]);
	CreateRadio(thousandsSeparator, addon.L["Space"], {"ThousandsSeparator"});
	CreateRadio(thousandsSeparator, addon.L["Period"], {"ThousandsSeparator"});
	CreateRadio(thousandsSeparator, addon.L["Comma"], {"ThousandsSeparator"});
	addon.MenuUtil:AddChildMenu(menuObj, thousandsSeparator);
	addon.MenuUtil:CreateDivider(menuObj);
	local currencyAbbreviate = addon.MenuUtil:CreateButton(menuObj, addon.L["Currency Abbreviate"]);
	CreateRadio(currencyAbbreviate, addon.L["None"], {"CurrencyAbbreviate"});
	CreateRadio(currencyAbbreviate, addon.L["1k"], {"CurrencyAbbreviate"});
	CreateRadio(currencyAbbreviate, addon.L["1m"], {"CurrencyAbbreviate"});
	addon.MenuUtil:AddChildMenu(menuObj, currencyAbbreviate);
	CreateKrowiCheckbox(menuObj, addon.L["Currency Group By Header"], {"CurrencyGroupByHeader"}, true);
	CreateKrowiCheckbox(menuObj, addon.L["Currency Hide Unused"], {"CurrencyHideUnused"}, true);
	
	-- Character tracking options divider
	if menuObj.CreateDivider then
		menuObj:CreateDivider();
	elseif addon.MenuUtil and addon.MenuUtil.CreateDivider then
		addon.MenuUtil:CreateDivider(menuObj);
	end
	
	-- Max characters submenu
	local maxCharsMenu = addon.MenuUtil:CreateButton(menuObj, addon.L["Max Characters"]);
	CreateRadio(maxCharsMenu, 10, {"MaxCharacters"});
	CreateRadio(maxCharsMenu, 15, {"MaxCharacters"});
	CreateRadio(maxCharsMenu, 20, {"MaxCharacters"});
	CreateRadio(maxCharsMenu, 25, {"MaxCharacters"});
	CreateRadio(maxCharsMenu, 30, {"MaxCharacters"});
	addon.MenuUtil:AddChildMenu(menuObj, maxCharsMenu);

	CreateKrowiCheckbox(menuObj, addon.L["Track All Realms"], {"TrackAllRealms"}, true);

	local headerVisibility = addon.MenuUtil:CreateButton(menuObj, addon.L["Header Visibility"]);
	local structuredHeaders, orderedHeaderNames = addon.Currency.GetAllCurrenciesWithHeader();
	for _, headerName in ipairs(orderedHeaderNames) do
		local headerEntry = structuredHeaders[headerName];
		if headerEntry then
			CreateHeaderMenu(headerVisibility, headerEntry);
		end
	end

	addon.MenuUtil:AddChildMenu(menuObj, headerVisibility);
end