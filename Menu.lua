local _, addon = ...;

local menu = {};
addon.Menu = menu;

local TitanPanelButton_UpdateButton = TitanPanelButton_UpdateButton;
local CheckboxMixin = {};

function CheckboxMixin:KeyIsTrue(filters, keys)
	return addon.Util.ReadNestedKeys(filters, keys);
end

function CheckboxMixin:KeyEqualsText(text, filters, keys)
	return addon.Util.ReadNestedKeys(filters, keys) == text;
end

function CheckboxMixin:KeyEqualsValue(value, filters, keys)
	return addon.Util.ReadNestedKeys(filters, keys) == value;
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
			if value == nil then return defaultValue; end
			return value;
		end,
		function()
			self:OnCheckboxSelect(filters, keys);
		end
	);
end

local function CreateCheckbox(menuObj, text, keyPath, defaultValue, resetKeys, customOnClick)
	if customOnClick then
		return menuObj:CreateCheckbox(
			text,
			function()
				local value = CheckboxMixin:KeyIsTrue(KrowiTPC_Options, keyPath);
				if value == nil then return defaultValue; end
				return value;
			end,
			customOnClick
		);
	else
		return CheckboxMixin:CreateCheckbox(menuObj, text, KrowiTPC_Options, keyPath, defaultValue);
	end
end

local function CreateParentHeaderCheckbox(parentMenu, text, setKey, headerEntry)
	return CreateCheckbox(parentMenu, text, {"HeaderSettings", setKey}, true, nil, function()
		local keyPath = {"HeaderSettings", setKey};
		local currentValue = CheckboxMixin:KeyIsTrue(KrowiTPC_Options, keyPath);
		if currentValue == nil then currentValue = true; end
		local newValue = not currentValue;
		CheckboxMixin:SetSelected(KrowiTPC_Options, keyPath, newValue);
		addon.Currency.UpdateChildHeaders(headerEntry, newValue);
	end);
end

local function CreateRadio(menuObj, text, keyPath, valueToStore)
	local compareValue = valueToStore ~= nil and valueToStore or text;
	
    local button = menuObj:CreateRadio(
        text,
        function()
			if type(compareValue) == "number" then
				return CheckboxMixin:KeyEqualsValue(compareValue, KrowiTPC_Options, keyPath);
			end
            return CheckboxMixin:KeyEqualsText(text, KrowiTPC_Options, keyPath);
        end,
        function()
            CheckboxMixin:OnRadioSelect(compareValue, KrowiTPC_Options, keyPath);
        end
    );
    button:SetResponse(MenuResponse.Refresh);
end

local function CreateHeaderMenu(parentMenu, headerEntry)
	local settingKey = addon.GetHeaderSettingKey(headerEntry.name);
	local hasChildren = next(headerEntry.children);
	
	if not hasChildren then
		CreateCheckbox(parentMenu, headerEntry.name, {"HeaderSettings", settingKey}, true);
		return;
	end
	
	local headerSubmenu = addon.MenuUtil:CreateButton(parentMenu, headerEntry.name);
	CreateParentHeaderCheckbox(headerSubmenu, "Show " .. headerEntry.name, settingKey, headerEntry);
	addon.MenuUtil:CreateDivider(headerSubmenu);
	
	for _, childHeader in pairs(headerEntry.children) do
		CreateHeaderMenu(headerSubmenu, childHeader);
	end
	
	addon.MenuUtil:AddChildMenu(parentMenu, headerSubmenu);
end

function menu.CreateMenu(self, menuObj)
	addon.MenuUtil:CreateTitle(menuObj, addon.L["Currency by Krowi"]);
	
	addon.MenuUtil:CreateDivider(menuObj);
	addon.MenuUtil:CreateTitle(menuObj, addon.L["Button Display"]);
	
	local buttonDisplay = addon.MenuUtil:CreateButton(menuObj, addon.L["Show On Button"]);
	CreateRadio(buttonDisplay, addon.L["Character Gold"], {"ButtonDisplay"});
	CreateRadio(buttonDisplay, addon.L["Current Faction Total"], {"ButtonDisplay"});
	CreateRadio(buttonDisplay, addon.L["Realm Total"], {"ButtonDisplay"});
	CreateRadio(buttonDisplay, addon.L["Account Total"], {"ButtonDisplay"});
	CreateRadio(buttonDisplay, addon.L["Warband Bank"], {"ButtonDisplay"});
	addon.MenuUtil:AddChildMenu(menuObj, buttonDisplay);
	
	addon.MenuUtil:CreateDivider(menuObj);
	addon.MenuUtil:CreateTitle(menuObj, addon.L["Tooltip Options"]);
	
	local defaultTooltip = addon.MenuUtil:CreateButton(menuObj, addon.L["Default Tooltip"]);
	CreateRadio(defaultTooltip, addon.L["Currency"], {"DefaultTooltip"});
	CreateRadio(defaultTooltip, addon.L["Money"], {"DefaultTooltip"});
	CreateRadio(defaultTooltip, addon.L["Combined"], {"DefaultTooltip"});
	addon.MenuUtil:AddChildMenu(menuObj, defaultTooltip);
	
	addon.MenuUtil:CreateDivider(menuObj);
	addon.MenuUtil:CreateTitle(menuObj, addon.L["Money Options"]);
	
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
	
	local thousandsSeparator = addon.MenuUtil:CreateButton(menuObj, addon.L["Thousands Separator"]);
	CreateRadio(thousandsSeparator, addon.L["Space"], {"ThousandsSeparator"});
	CreateRadio(thousandsSeparator, addon.L["Period"], {"ThousandsSeparator"});
	CreateRadio(thousandsSeparator, addon.L["Comma"], {"ThousandsSeparator"});
	addon.MenuUtil:AddChildMenu(menuObj, thousandsSeparator);
	
	CreateCheckbox(menuObj, addon.L["Money Gold Only"], {"MoneyGoldOnly"}, false);
	CreateCheckbox(menuObj, addon.L["Money Colored"], {"MoneyColored"}, true);
	
	local maxCharsMenu = addon.MenuUtil:CreateButton(menuObj, addon.L["Max Characters"]);
	CreateRadio(maxCharsMenu, 5, {"MaxCharacters"});
	CreateRadio(maxCharsMenu, 10, {"MaxCharacters"});
	CreateRadio(maxCharsMenu, 15, {"MaxCharacters"});
	CreateRadio(maxCharsMenu, 20, {"MaxCharacters"});
	CreateRadio(maxCharsMenu, 25, {"MaxCharacters"});
	CreateRadio(maxCharsMenu, 30, {"MaxCharacters"});
	addon.MenuUtil:AddChildMenu(menuObj, maxCharsMenu);

	CreateCheckbox(menuObj, addon.L["Track All Realms"], {"TrackAllRealms"}, true);
	
	CreateCheckbox(menuObj, addon.L["Track Session Gold"], {"TrackSessionGold"}, true, nil, function()
		local keyPath = {"TrackSessionGold"};
		local currentValue = CheckboxMixin:KeyIsTrue(KrowiTPC_Options, keyPath);
		if currentValue == nil then currentValue = true; end
		local newValue = not currentValue;
		CheckboxMixin:SetSelected(KrowiTPC_Options, keyPath, newValue);
		
		if not newValue then
			addon.ResetSessionTracking();
		end
	end);
	
	local sessionDuration = addon.MenuUtil:CreateButton(menuObj, addon.L["Session Duration"]);
	CreateRadio(sessionDuration, addon.L["1 Hour"], {"SessionDuration"}, 3600);
	CreateRadio(sessionDuration, addon.L["2 Hours"], {"SessionDuration"}, 7200);
	CreateRadio(sessionDuration, addon.L["4 Hours"], {"SessionDuration"}, 14400);
	CreateRadio(sessionDuration, addon.L["8 Hours"], {"SessionDuration"}, 28800);
	CreateRadio(sessionDuration, addon.L["12 Hours"], {"SessionDuration"}, 43200);
	CreateRadio(sessionDuration, addon.L["24 Hours"], {"SessionDuration"}, 86400);
	CreateRadio(sessionDuration, addon.L["48 Hours"], {"SessionDuration"}, 172800);
	addon.MenuUtil:AddChildMenu(menuObj, sessionDuration);
	
	addon.MenuUtil:CreateDivider(menuObj);
	addon.MenuUtil:CreateTitle(menuObj, addon.L["Currency Options"]);
	
	local currencyAbbreviate = addon.MenuUtil:CreateButton(menuObj, addon.L["Currency Abbreviate"]);
	CreateRadio(currencyAbbreviate, addon.L["None"], {"CurrencyAbbreviate"});
	CreateRadio(currencyAbbreviate, addon.L["1k"], {"CurrencyAbbreviate"});
	CreateRadio(currencyAbbreviate, addon.L["1m"], {"CurrencyAbbreviate"});
	addon.MenuUtil:AddChildMenu(menuObj, currencyAbbreviate);
	
	CreateCheckbox(menuObj, addon.L["Currency Group By Header"], {"CurrencyGroupByHeader"}, true);
	CreateCheckbox(menuObj, addon.L["Currency Hide Unused"], {"CurrencyHideUnused"}, true);
	
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