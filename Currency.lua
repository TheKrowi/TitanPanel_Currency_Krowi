local _, addon = ...;

local currency = {};
addon.Currency = currency;

local C_CurrencyInfo = C_CurrencyInfo;

local headerStack = {};
local headerOrder = {};

local function GetNextCurrencyWithHeader(currencies, startIndex)
	local size = C_CurrencyInfo.GetCurrencyListSize();
	for i = startIndex, size do
		local info = C_CurrencyInfo.GetCurrencyListInfo(i);
		if info.isHeader then
			local depth = info.currencyListDepth;

			-- Trim stack to current depth
			while #headerStack > depth do
				table.remove(headerStack);
			end

			local headerEntry = {
				name = info.name,
				depth = depth,
				children = {},
				currencies = {}
			};

			if depth == 0 then
				currencies[info.name] = headerEntry;
				tinsert(headerOrder, info.name);
				headerStack = {headerEntry};
			else
				if headerStack[depth] then
					headerStack[depth].children[info.name] = headerEntry;
				end
				headerStack[depth + 1] = headerEntry;
			end

			if not info.isHeaderExpanded then
				C_CurrencyInfo.ExpandCurrencyList(i, true);
				return false, i + 1;
			end
		elseif #headerStack > 0 and not (KrowiTPC_Options.CurrencyHideUnused and info.isTypeUnused) then
			local currentHeader = headerStack[#headerStack];
			if currentHeader then
				tinsert(currentHeader.currencies, info);
			end
		end
	end
	return true, size + 1;
end

function currency.GetAllCurrenciesWithHeader()
	local currencies = {};
	headerOrder = {};
	local finished, nextIndex = false, 1;
	while not finished do
		finished, nextIndex = GetNextCurrencyWithHeader(currencies, nextIndex);
	end
	return currencies, headerOrder;
end

function currency.GetAllAvailableHeaders()
	local headers = currency.GetAllCurrenciesWithHeader();
	local headerList = {};
	
	local function AddHeadersRecursive(headerEntry, parentPath)
		local currentPath = parentPath and (parentPath .. " > " .. headerEntry.name) or headerEntry.name;
		tinsert(headerList, {
			name = headerEntry.name,
			path = currentPath,
			depth = headerEntry.depth
		});
		
		for _, childHeader in pairs(headerEntry.children) do
			AddHeadersRecursive(childHeader, currentPath);
		end
	end
	
	for _, headerEntry in pairs(headers) do
		AddHeadersRecursive(headerEntry);
	end
	
	return headerList;
end

function currency.UpdateChildHeaders(headerEntry, newValue)
	for _, childHeader in pairs(headerEntry.children) do
		local childSettingKey = "ShowHeader_" .. childHeader.name:gsub(" ", "_");
		addon.Util.WriteNestedKeys(KrowiTPC_Options, {"HeaderSettings", childSettingKey}, newValue);
		currency.UpdateChildHeaders(childHeader, newValue);
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
		elseif not (KrowiTPC_Options.CurrencyHideUnused and info.isTypeUnused) then
			tinsert(currencies, info);
		end
	end
	return true, size + 1;
end

function currency.GetAllCurrencies()
	local currencies, finished, nextIndex = {}, false, 1;
	while not finished do
		finished, nextIndex = GetNextCurrency(currencies, nextIndex);
	end
	return currencies;
end