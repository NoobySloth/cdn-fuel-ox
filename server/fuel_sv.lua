-- Variables
local QBCore = exports['qb-core']:GetCoreObject()

-- Functions
local function GlobalTax(value)
	local tax = (value / 100 * Config.GlobalTax)
	return tax
end

--- Events
if Config.RenewedPhonePayment then
	RegisterNetEvent('cdn-fuel:server:phone:givebackmoney', function(amount)
		local src = source
		local player = QBCore.Functions.GetPlayer(src)
		player.Functions.AddMoney("bank", math.ceil(amount), Lang:t("phone_refund_payment_label"))
	end)
end

RegisterNetEvent("cdn-fuel:server:OpenMenu", function(amount, inGasStation, hasWeapon, purchasetype, FuelPrice)
	local src = source
	if not src then return end
	local player = QBCore.Functions.GetPlayer(src)
	if not player then return end
	local tax = GlobalTax(amount)
	local total = math.ceil(amount + tax)
	local fuelamounttotal = (amount / FuelPrice)
	if amount < 1 then TriggerClientEvent('QBCore:Notify', src, Lang:t("more_than_zero"), 'error') return end
	if inGasStation == true and not hasWeapon then
		if Config.RenewedPhonePayment and purchasetype == "bank" then
			TriggerClientEvent("cdn-fuel:client:phone:PayForFuel", src, fuelamounttotal)
		else
			if Config.qbox then
					TriggerClientEvent('cdn-fuel:client:OpenContextMenu', src, total, fuelamounttotal, purchasetype)
			else
				TriggerClientEvent('qb-menu:client:openMenu', src, {
					{
						header = Lang:t("menu_refuel_header"),
						isMenuHeader = true,
						icon = "fas fa-gas-pump",
					},
					{
						header = "",
						icon = "fas fa-info-circle",
						isMenuHeader = true,
						txt = Lang:t("menu_purchase_station_header_1")..total..Lang:t("menu_purchase_station_header_2") ,
					},
					{
						header = Lang:t("menu_purchase_station_confirm_header"),
						icon = "fas fa-check-circle",
						txt = Lang:t("menu_refuel_accept"),
						params = {
							event = "cdn-fuel:client:RefuelVehicle",
							args = {
								fuelamounttotal = fuelamounttotal,
								purchasetype = purchasetype,
							}
						}
					},
					{
						header = Lang:t("menu_header_close"),
						txt = Lang:t("menu_refuel_cancel"),
						icon = "fas fa-times-circle",
						params = {
							event = "qb-menu:closeMenu",
						}
					},
				})
			end
		end
	end
end)

RegisterNetEvent("cdn-fuel:server:PayForFuel", function(amount, purchasetype, FuelPrice, electric)
	local src = source
	if not src then return end
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player then return end
	local tax = GlobalTax(amount)
	local total = math.ceil(amount + tax)
	local moneyremovetype = purchasetype
	if purchasetype == "bank" then
		moneyremovetype = "bank"
	elseif purchasetype == "cash" then
		moneyremovetype = "cash"
	end
	local payString = Lang:t("menu_pay_label_1") ..FuelPrice..Lang:t("menu_pay_label_2")
	if electric then payString = Lang:t("menu_electric_payment_label_1") ..FuelPrice..Lang:t("menu_electric_payment_label_2") end
	Player.Functions.RemoveMoney(moneyremovetype, math.ceil(total), payString)

end)

RegisterNetEvent("cdn-fuel:server:purchase:jerrycan", function(purchasetype)
	local src = source if not src then return end
	local Player = QBCore.Functions.GetPlayer(src) if not Player then return end
	local tax = GlobalTax(Config.JerryCanPrice) local total = math.ceil(Config.JerryCanPrice + tax)
	local moneyremovetype = purchasetype
	if purchasetype == "bank" then
		moneyremovetype = "bank"
	elseif purchasetype == "cash" then
		moneyremovetype = "cash"
	end
	if Config.qbox then
		local info = {cdn_fuel = tostring(Config.JerryCanGas)}
		exports.ox_inventory:AddItem(src, 'jerrycan', 1, info)
		local hasItem = exports.ox_inventory:GetItem(src, 'jerrycan', info, 1)
		if hasItem then
			Player.Functions.RemoveMoney(moneyremovetype, total, Lang:t("jerry_can_payment_label"))
		end
	else
		local info = {gasamount = Config.JerryCanGas}
		if Player.Functions.AddItem("jerrycan", 1, false, info) then -- Dont remove money if AddItem() not possible!
			TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['jerrycan'], "add")
			Player.Functions.RemoveMoney(moneyremovetype, total, Lang:t("jerry_can_payment_label"))
		end
	end
end)

--- Jerry Can
if Config.UseJerryCan then
	QBCore.Functions.CreateUseableItem("jerrycan", function(source, item)
		local src = source
		local jerry_can = exports.ox_inventory:GetItem(source, 'jerrycan', nil, false)
		if jerry_can.count == 1 then
			TriggerClientEvent('cdn-fuel:jerrycan:refuelmenu', src, item)
		else
			TriggerClientEvent('QBCore:Notify', src, 'U have more than 1 jerry cans in your inventory!', 'error')
		end
	end)
end

--- Syphoning
if Config.UseSyphoning then
	QBCore.Functions.CreateUseableItem("syphoningkit", function(source, item)
		local src = source
		if item.metadata.cdn_fuel == nil then
			item.metadata.cdn_fuel = '0'
			exports.ox_inventory:SetMetadata(src, item.slot, item.metadata)
		end
		TriggerClientEvent('cdn-syphoning:syphon:menu', src, item)
	end)
end

RegisterNetEvent('cdn-fuel:info', function(type, amount, srcPlayerData, itemdata)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local srcPlayerData = srcPlayerData
	if Config.qbox then
		if itemdata == "jerrycan" then
			if amount < 1 or amount > Config.JerryCanCap then if Config.FuelDebug then print("Error, amount is invalid (< 1 or > "..Config.SyphonKitCap..")! Amount:" ..amount) end return end
		elseif itemdata == "syphoningkit" then
			if amount < 1 or amount > Config.SyphonKitCap then if Config.SyphonDebug then print("Error, amount is invalid (< 1 or > "..Config.SyphonKitCap..")! Amount:" ..amount) end return end
		end
		local jerry_can = exports.ox_inventory:Search(source, 1, itemdata)
		for k, v in pairs(jerry_can) do
			jerry_can = v
			break
		end
		local fuel_amount = tonumber(jerry_can.metadata.cdn_fuel)
		if type == "add" then
			fuel_amount = fuel_amount + amount
			jerry_can.metadata.cdn_fuel = tostring(fuel_amount)
			exports.ox_inventory:SetMetadata(src, jerry_can.slot, jerry_can.metadata)
		elseif type == "remove" then
			fuel_amount = fuel_amount - amount
			jerry_can.metadata.cdn_fuel = tostring(fuel_amount)
			exports.ox_inventory:SetMetadata(src, jerry_can.slot, jerry_can.metadata)
		else
			if Config.SyphonDebug then print("error, type is invalid!") end
		end
	else
		if itemdata.info.name == "jerrycan" then
			if amount < 1 or amount > Config.JerryCanCap then if Config.FuelDebug then print("Error, amount is invalid (< 1 or > "..Config.SyphonKitCap..")! Amount:" ..amount) end return end
		elseif itemdata.info.name == "syphoningkit" then
			if amount < 1 or amount > Config.SyphonKitCap then if Config.SyphonDebug then print("Error, amount is invalid (< 1 or > "..Config.SyphonKitCap..")! Amount:" ..amount) end return end
		end

		if type == "add" then
			srcPlayerData.items[itemdata.slot].info.gasamount = srcPlayerData.items[itemdata.slot].info.gasamount + amount
			Player.Functions.SetInventory(srcPlayerData.items)
		elseif type == "remove" then
			srcPlayerData.items[itemdata.slot].info.gasamount = srcPlayerData.items[itemdata.slot].info.gasamount - amount
			Player.Functions.SetInventory(srcPlayerData.items)
		else
			if Config.SyphonDebug then print("error, type is invalid!") end
		end
	end
end)

RegisterNetEvent('cdn-syphoning:callcops', function(coords)
    TriggerClientEvent('cdn-syphoning:client:callcops', -1, coords)
end)

--- Update Alerts
local updatePath
local resourceName

local function checkVersion(err, responseText, headers)
    local curVersion = LoadResourceFile(GetCurrentResourceName(), "version")
	if responseText == nil then print("^1"..resourceName.." check for updates failed ^7") return end
    if curVersion ~= nil and responseText ~= nil then
		if curVersion == responseText then Color = "^2" else Color = "^1" end
        print("\n^1----------------------------------------------------------------------------------^7")
        print(resourceName.."'s latest version is: ^2"..responseText.."!\n^7Your current version: "..Color..""..curVersion.."^7!\nIf needed, update from https://github.com"..updatePath.."")
        print("^1----------------------------------------------------------------------------------^7")
    end
end

Citizen.CreateThread(function()
	updatePath = "/CodineDev/cdn-fuel"
	resourceName = "cdn-fuel ("..GetCurrentResourceName()..")"
	PerformHttpRequest("https://raw.githubusercontent.com"..updatePath.."/master/version", checkVersion, "GET")
end)