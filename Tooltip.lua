local _, addon = ...;

local tooltip = {};
addon.Tooltip = tooltip;

local TitanUtils_NumToString = TitanUtils_NumToString;
local GameTooltip = GameTooltip;
local GameTooltip_AddBlankLineToTooltip = GameTooltip_AddBlankLineToTooltip;

local function HeaderHasCurrencies(headerEntry)
	if #headerEntry.currencies > 0 then
		return true;
	end
	for _, childHeader in pairs(headerEntry.children) do
		if HeaderHasCurrencies(childHeader) then
			return true;
		end
	end

	return false;
end

local function ShouldShowHeader(headerName)
	local settingKey = addon.GetHeaderSettingKey(headerName);
	local shouldShow = addon.Util.ReadNestedKeys(KrowiTPC_Options, {"HeaderSettings", settingKey});
	if shouldShow == nil then return true; end
	return shouldShow;
end

local function DisplayHeaderRecursive(headerEntry, depth, abbreviateK, abbreviateM, thousandsSeparator, decimalSeparator)
	if not HeaderHasCurrencies(headerEntry) then
		return;
	end

	if not ShouldShowHeader(headerEntry.name) then
		return;
	end

	local indent = string.rep("  ", depth);

	GameTooltip:AddLine(indent .. headerEntry.name);
	if #headerEntry.currencies > 0 then
		local currencies = {};
		for _, currency in ipairs(headerEntry.currencies) do
			tinsert(currencies, currency);
		end
		table.sort(currencies, function(a, b) return a.name < b.name end);

		for _, currency in ipairs(currencies) do
			local quantity, abbr = addon.AbbreviateValue(currency.quantity, abbreviateK, abbreviateM);
			quantity = TitanUtils_NumToString(quantity, thousandsSeparator, decimalSeparator);
			GameTooltip:AddDoubleLine(indent .. "  " .. currency.name, quantity .. abbr .. " |T" .. currency.iconFileID .. ":16|t", 1, 1, 1, 1, 1, 1);
		end
	end

	for _, childHeader in pairs(headerEntry.children) do
		if HeaderHasCurrencies(childHeader) then
			DisplayHeaderRecursive(childHeader, depth + 1, abbreviateK, abbreviateM, thousandsSeparator, decimalSeparator);
		end
	end
end

function tooltip.GetAllCurrenciesWithHeaderSorted()
	local headers, orderedHeaderNames = addon.Currency.GetAllCurrenciesWithHeader();
    local abbreviateK = KrowiTPC_Options.CurrencyAbbreviate == addon.L["1k"];
    local abbreviateM = KrowiTPC_Options.CurrencyAbbreviate == addon.L["1m"];
	local thousandsSeparator, decimalSeparator = addon.GetSeparators();

	local hasDisplayedAnyHeader = false;
	for _, headerName in ipairs(orderedHeaderNames) do
		local headerEntry = headers[headerName];
		if headerEntry then
			if HeaderHasCurrencies(headerEntry) and ShouldShowHeader(headerEntry.name) then
				if hasDisplayedAnyHeader then
					GameTooltip_AddBlankLineToTooltip(GameTooltip);
				end
				DisplayHeaderRecursive(headerEntry, 0, abbreviateK, abbreviateM, thousandsSeparator, decimalSeparator);
				hasDisplayedAnyHeader = true;
			end
		end
	end
end

function tooltip.GetAllCurrenciesSorted()
	local currencies = addon.Currency.GetAllCurrencies();
    local abbreviateK = KrowiTPC_Options.CurrencyAbbreviate == addon.L["1k"];
    local abbreviateM = KrowiTPC_Options.CurrencyAbbreviate == addon.L["1m"];
	local thousandsSeparator, decimalSeparator = addon.GetSeparators();

	table.sort(currencies, function(a, b) return a.name < b.name end);

	for _, currency in next, currencies do
		local quantity, abbr = addon.AbbreviateValue(currency.quantity, abbreviateK, abbreviateM);
		quantity = TitanUtils_NumToString(quantity, thousandsSeparator, decimalSeparator);
		GameTooltip:AddDoubleLine(currency.name, quantity .. abbr .. " |T" .. currency.iconFileID .. ":16|t", 1, 1, 1, 1, 1, 1);
	end
end

local function SortCharactersByMoney(charData)
	local sortedChars = {};
	for key, char in pairs(charData) do
		char.key = key;
		tinsert(sortedChars, char);
	end

	table.sort(sortedChars, function(a, b)
		return (a.money or 0) > (b.money or 0);
	end);

	return sortedChars;
end

local function DisplayMoneyContent()
	local currentPlayerName = UnitName("player") or "Unknown";
	local currentRealmName = GetRealmName() or "Unknown";
	local currentKey = currentPlayerName .. "-" .. currentRealmName;

	local characterData = KrowiTPC_SavedData.CharacterData or {};
	local maxChars = KrowiTPC_Options.MaxCharacters or 20;

	if not next(characterData) then
		GameTooltip:AddLine(addon.L["No character data available yet"], 0.7, 0.7, 0.7);
		GameTooltip:AddLine(addon.L["Data will be collected as you play"], 0.7, 0.7, 0.7);
		return;
	end

	local sortedCharacters = SortCharactersByMoney(characterData);
	local totalMoney = 0;
	local allianceTotal = 0;
	local hordeTotal = 0;
	local warbandMoney = addon.GetWarbandMoney();

	local sessionProfit = addon.GetSessionProfit();
	local sessionSpent = addon.GetSessionSpent();
	
	if sessionProfit > 0 or sessionSpent > 0 then
		GameTooltip:AddLine(addon.L["Session:"]);
		
		if sessionProfit > 0 then
			local profitFormatted = addon.FormatMoney(sessionProfit);
			GameTooltip:AddDoubleLine(addon.L["Earned:"], profitFormatted, 0.5, 1, 0.5, 1, 1, 1);
		end
		
		if sessionSpent > 0 then
			local spentFormatted = addon.FormatMoney(sessionSpent);
			GameTooltip:AddDoubleLine(addon.L["Spent:"], spentFormatted, 1, 0.5, 0.5, 1, 1, 1);
		end
		
		GameTooltip_AddBlankLineToTooltip(GameTooltip);
	end
	
	GameTooltip:AddLine(addon.L["Characters:"]);

	local count = 0;
	for _, char in ipairs(sortedCharacters) do
		count = count + 1;
		if count > maxChars then
			local remaining = #sortedCharacters - maxChars;
			GameTooltip:AddLine(string.format("+%d %s", remaining, addon.L["more characters"]), 0.7, 0.7, 0.7);
			break;
		end

		local money = char.money or 0;
		totalMoney = totalMoney + money;

		if char.faction == "Alliance" then
			allianceTotal = allianceTotal + money;
		elseif char.faction == "Horde" then
			hordeTotal = hordeTotal + money;
		end

		local formattedMoney = addon.FormatMoney(money);

		local charName = char.name or "Unknown";
		local realmName = char.realm or "Unknown";
		local displayName = charName;

		if realmName ~= currentRealmName then
			displayName = displayName .. " - " .. realmName;
		end

		if char.key == currentKey then
			displayName = displayName .. " |TInterface\\COMMON\\Indicator-Green:14|t";
		end

		local classColor = RAID_CLASS_COLORS[char.className] or {r = 1, g = 1, b = 1};
		GameTooltip:AddDoubleLine(displayName, formattedMoney, classColor.r, classColor.g, classColor.b, 1, 1, 1);
	end

	if allianceTotal > 0 and hordeTotal > 0 then
		GameTooltip_AddBlankLineToTooltip(GameTooltip);
		GameTooltip:AddLine(addon.L["Faction Totals:"]);

		if allianceTotal > 0 then
			local allianceFormatted = addon.FormatMoney(allianceTotal);
			GameTooltip:AddDoubleLine(addon.L["Alliance:"], allianceFormatted, 0, 0.376, 1, 1, 1, 1);
		end

		if hordeTotal > 0 then
			local hordeFormatted = addon.FormatMoney(hordeTotal);
			GameTooltip:AddDoubleLine(addon.L["Horde:"], hordeFormatted, 1, 0.2, 0.2, 1, 1, 1);
		end
	end

	GameTooltip_AddBlankLineToTooltip(GameTooltip);
	local warbandFormatted = addon.FormatMoney(warbandMoney);
	GameTooltip:AddDoubleLine(addon.L["Warband Bank:"], warbandFormatted, 0.8, 0.6, 1, 1, 1, 1);
	totalMoney = totalMoney + warbandMoney;

	GameTooltip_AddBlankLineToTooltip(GameTooltip);
	local totalFormatted = addon.FormatMoney(totalMoney);
	GameTooltip:AddDoubleLine(addon.L["Total:"], totalFormatted, 1, 1, 0, 1, 1, 1);
end

local function DisplayCurrencyContent()
	if KrowiTPC_Options.CurrencyGroupByHeader then
		tooltip.GetAllCurrenciesWithHeaderSorted();
	else
		tooltip.GetAllCurrenciesSorted();
	end
end

function tooltip.GetDetailedMoneyTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_NONE");
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT");
	GameTooltip:AddLine(addon.Metadata.Title .. " " .. addon.Metadata.Version);
	GameTooltip_AddBlankLineToTooltip(GameTooltip);

	DisplayMoneyContent();

	GameTooltip_AddBlankLineToTooltip(GameTooltip);
	local defaultTooltip = KrowiTPC_Options.DefaultTooltip;
	if defaultTooltip == addon.L["Combined"] then
		GameTooltip:AddLine(addon.L["Release Shift: Show combined"], 0.5, 0.8, 1);
	elseif defaultTooltip == addon.L["Money"] then
		GameTooltip:AddLine(addon.L["Hold Shift: Show currencies"], 0.5, 0.8, 1);
	else
		GameTooltip:AddLine(addon.L["Release Shift: Show currencies"], 0.5, 0.8, 1);
	end

	GameTooltip:Show();
end

function tooltip.GetAllCurrenciesTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_NONE");
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT");
	GameTooltip:AddLine(addon.Metadata.Title .. " " .. addon.Metadata.Version);
	GameTooltip_AddBlankLineToTooltip(GameTooltip);

	DisplayCurrencyContent();

	GameTooltip_AddBlankLineToTooltip(GameTooltip);
	local defaultTooltip = KrowiTPC_Options.DefaultTooltip;
	if defaultTooltip == addon.L["Combined"] then
		GameTooltip:AddLine(addon.L["Release Ctrl: Show combined"], 0.5, 0.8, 1);
	elseif defaultTooltip == addon.L["Money"] then
		GameTooltip:AddLine(addon.L["Release Shift: Show money"], 0.5, 0.8, 1);
	else
		GameTooltip:AddLine(addon.L["Hold Shift: Show money"], 0.5, 0.8, 1);
	end

	GameTooltip:Show();
end

function tooltip.GetCombinedTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_NONE");
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT");
	GameTooltip:AddLine(addon.Metadata.Title .. " " .. addon.Metadata.Version);
	GameTooltip_AddBlankLineToTooltip(GameTooltip);

	DisplayMoneyContent();

	GameTooltip_AddBlankLineToTooltip(GameTooltip);
	GameTooltip:AddLine("--------------------------------------------------", 0.5, 0.5, 0.5);
	GameTooltip_AddBlankLineToTooltip(GameTooltip);

	DisplayCurrencyContent();

	GameTooltip_AddBlankLineToTooltip(GameTooltip);
	GameTooltip:AddLine(addon.L["Hold Ctrl: Show currencies"], 0.5, 0.8, 1);
	GameTooltip:AddLine(addon.L["Hold Shift: Show money"], 0.5, 0.8, 1);

	GameTooltip:Show();
end