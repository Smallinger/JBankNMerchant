jMerchantNBank = LibStub("AceAddon-3.0"):NewAddon("Merchant & Bank Tools", "AceConsole-3.0","AceEvent-3.0")
local addon	= LibStub("AceAddon-3.0"):GetAddon("Merchant & Bank Tools")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local addonName, addonTable = ...
local L = addonTable.L
local _

addon.optionsFrame = {}
local options = nil

function addon:OnInitialize()
	self:RegisterChatCommand("mnb", "HandleSlashCommands")
	self.db = LibStub("AceDB-3.0"):New("jMerchantNBankDB")
	self.db:RegisterDefaults({
		char = {
			mAuto		= true,
			rAuto		= true,
			bAuto		= true,
			max12		= true,
			mPrintGold	= true,
			rPrintGold	= true,
			mShowSpam	= true,
			bSilentMode	= true,
			repairMode	= 1,
			bankModKey	= 0
		}
	})
	self:PopulateOptions()
	AceConfigRegistry:RegisterOptionsTable("Merchant & Bank Tools", options)
	addon.optionsFrame = AceConfigDialog:AddToBlizOptions("Merchant & Bank Tools", nil, nil, "general")
end

function addon:HandleSlashCommands()
	InterfaceOptionsFrame_OpenToCategory(addon.optionsFrame)
end

function addon:OnEnable()
	self:RegisterEvent("BANKFRAME_OPENED")
	self:RegisterEvent("MERCHANT_SHOW")
	self.total = 0
end

function addon:AddProfit(profit)
	if profit then
		self.total = self.total + profit
	end
end

function addon:PrintGold()
	if self.total > 0 then
		self:Print("Gained"..": "..GetMoneyString(self.total))
	end
end

function addon:BANKFRAME_OPENED()
	if addon.db.char.bAuto then
		if (addon.db.char.bankModKey == 1 and IsShiftKeyDown()) or (addon.db.char.bankModKey == 2 and IsControlKeyDown()) or (addon.db.char.bankModKey == 3 and IsAltKeyDown()) then
			return
		else
			self:Deposits()
		end
	end
end

function addon:MERCHANT_SHOW()
	if addon.db.char.rAuto then
		self:Repair()
	end
	if addon.db.char.mAuto then
		self:Sell()
	end
end

function addon:Deposits()
	if not BankFrameItemButton_Update_OLD then
		BankFrameItemButton_Update_OLD = BankFrameItemButton_Update
		
		BankFrameItemButton_Update = function(button)
			if BankFrameItemButton_Update_PASS == false then
				BankFrameItemButton_Update_OLD(button)
			else
				BankFrameItemButton_Update_PASS = false
			end
		end
	end
	BankFrameItemButton_Update_PASS = true
	DepositReagentBank()
	if addon.db.char.bSilentMode then
		self:Print("Reagents deposited into Reagent Bank.")
	end
end

function addon:Repair()
	if (CanMerchantRepair()) then
		repairAllCost, canRepair = GetRepairAllCost();
		-- If merchant can repair and there is something to repair
		if (canRepair and repairAllCost > 0) then
			-- Use Guild Bank
			guildRepairedItems = false
			if addon.db.char.repairMode == 2 then
				if (IsInGuild() and CanGuildBankRepair()) then
					-- Checks if guild has enough money
					local amount = GetGuildBankWithdrawMoney()
					local guildBankMoney = GetGuildBankMoney()
					amount = amount == -1 and guildBankMoney or min(amount, guildBankMoney)
					if (amount >= repairAllCost) then
						RepairAllItems(true);
						guildRepairedItems = true
						if addon.db.char.rPrintGold then
							self:Print("Your items have been repaired from Guild for: "..GetCoinTextureString(repairAllCost)..".")
						end
					end
				end
				-- Use own funds
				if not guildRepairedItems then
					if (repairAllCost <= GetMoney()) then
						RepairAllItems(false);
						if addon.db.char.rPrintGold then
							self:Print("Your items have been repaired for "..GetCoinTextureString(repairAllCost)..".")
						end
					else
						if addon.db.char.rPrintGold then
							self:Print("You don't have enough money for repair!")
						end
					end
				end
			end
			if addon.db.char.repairMode == 1 then
				-- Use only own funds
				if (repairAllCost <= GetMoney() and not guildRepairedItems) then
					RepairAllItems(false);
					if addon.db.char.rPrintGold then
						self:Print("Your items have been repaired for "..GetCoinTextureString(repairAllCost)..".")
					end
				else
					if addon.db.char.rPrintGold then
						self:Print("You don't have enough money for repair!")
					end
				end
			end
		end
	end
end

function addon:Sell()
	local limit = 0
	local currPrice
	local showSpam = addon.db.char.mShowSpam
	local max12 = addon.db.char.max12

	for myBags = 0,4 do
		for bagSlots = 1,GetContainerNumSlots(myBags) do
			local CurrentItemLink = GetContainerItemLink(myBags,bagSlots)
			if CurrentItemLink then
				-- is it grey quality item?
				--local grey = string_find(item,"|cff9d9d9d")
				_, _, itemRarity, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(CurrentItemLink)
				_, itemCount = GetContainerItemInfo(myBags, bagSlots)
				--if (grey and (not addon:isException(item))) or ((not grey) and (addon:isException(item))) then
				if itemRarity == 0 and itemSellPrice ~= 0 then
					currPrice = (select(11, GetItemInfo(CurrentItemLink)) or 0) * select(2, GetContainerItemInfo(myBags, bagSlots))
					-- this should get rid of problems with grey items, that cant be sell to a vendor
					if currPrice > 0 then
						addon:AddProfit(currPrice)
						PickupContainerItem(myBags, bagSlots)
						PickupMerchantItem()
						if showSpam then
							self:Print("Sold"..": "..CurrentItemLink)
						end

						if max12 then
							limit = limit + 1
							if limit == 12 then
								return
							end
						end
					end
				end
			end
		end
	end

	if self.db.char.mPrintGold then
		self:PrintGold()
	end
	self.total = 0
end

function addon:PopulateOptions()
	if not options then
		options = {
			order = 1,
			type  = "group",
			name  = "Merchant & Bank Tools v"..GetAddOnMetadata("jMerchantNBank", "Version"),
			args  = {
				general = {
					order	= 1,
					type	= "group",
					name	= "Settings",
					args	= {
						divider1 = {
							order	= 1,
							type	= "header",
							name	= "Merchant Settings",
                        },
                        merchantAutoToggleButton = {
							order	= 2,
							type 	= "toggle",
							name 	= "Automatically sell grey items",
                            desc 	= "Toggles the automatic selling of grey items when the merchant window is opened.",
							get 	= function() return addon.db.char.mAuto end,
							set 	= function() self.db.char.mAuto = not self.db.char.mAuto end,
                        },
                        divider2 = {
							order	= 3,
							type	= "description",
							name	= "",
                        },
                        merchantMax12ToggleButton = {
							order 	= 4,
							type  	= "toggle",
							name  	= "Sell max. 12 items",
							desc  	= "This is failsafe mode. Will sell only 12 items in one pass.",
							get 	= function() return addon.db.char.max12 end,
							set 	= function() self.db.char.max12 = not self.db.char.max12 end,
                        },
                        divider3 = {
							order	= 5,
							type	= "description",
							name	= "",
						},
						merchantShowSpamToggleButton = {
                            order = 6,
                            type  = "toggle",
                            name  = "Show 'item sold' spam",
                            desc  = "Prints itemlinks to chat, when automatically selling items.",
                            get   = function() return self.db.char.mShowSpam end,
                            set   = function() self.db.char.mShowSpam = not self.db.char.mShowSpam end,
                        },
                        divider4 = {
							order	= 7,
							type	= "description",
							name	= "",
                        },
                        merchantPrintGoldToggleButton = {
							order 	= 8,
							type  	= "toggle",
							name  	= "Show gold gained",
							desc  	= "Shows gold gained from selling trash.",
							get 	= function() return addon.db.char.mPrintGold end,
							set 	= function() self.db.char.mPrintGold = not self.db.char.mPrintGold end,
                        },
                        divider5 = {
							order	= 9,
							type	= "description",
							name	= "",
						},
						divider6 = {
							order	= 10,
							type	= "header",
							name	= "Repair Settings",
						},
						repairAutoToggleButton = {
							order	= 11,
							type 	= "toggle",
							name 	= "Automatically Repair items",
                            desc 	= "Toggles the automatic Repair of items when the merchant window is opened.",
							get 	= function() return addon.db.char.rAuto end,
							set 	= function() self.db.char.rAuto = not self.db.char.rAuto end,
						},
						divider7 = {
							order	= 12,
							type	= "description",
							name	= "",
						},
						repairPrintGoldToggleButton = {
							order 	= 13,
							type 	= "toggle",
							name  	= "Show gold spent",
							desc  	= "Shows gold spent from Repair items.",
							get 	= function() return addon.db.char.rPrintGold end,
							set 	= function() self.db.char.rPrintGold = not self.db.char.rPrintGold end,
						},
						divider10 = {
							order	= 14,
							type	= "description",
							name	= "",
						},
						repairModeRadioButton = {
							order	= 15,
							type 	= "select",
							name    = "Repair mode",
							desc    = "Select your Repair mode.\n1.Repairs only from your own gold.\n2.Tries to repair from guild bank, then tries to repair from your own gold.",
							style	= "radio",
							values 	= {
								[1] = "Repair from own gold",
								[2] = "Use first guild bank",
							},
							get   	= function(info, value) return self.db.char.repairMode end,
							set		= function(info, value) self.db.char.repairMode = value end,
						},
						divider11 = {
							order	= 16,
							type	= "description",
							name	= "",
                        },
                        divider12 = {
							order	= 17,
							type	= "header",
							name	= "Bank Settings",
                        },
                        bankAutoToggleButton = {
							order	= 18,
							type 	= "toggle",
							name 	= "Automatically deposits reagents",
                            desc 	= "Toggles the automatic deposits reagents when you open your bank window.",
							get 	= function() return addon.db.char.bAuto end,
							set 	= function() self.db.char.bAuto = not self.db.char.bAuto end,
						},
						divider13 = {
							order	= 19,
							type	= "description",
							name	= "",
                        },
						bankSilentModeToggleButton = {
                            order = 20,
                            type  = "toggle",
                            name  = "Show 'deposits reagents' spam",
                            desc  = "Prints to chat, when automatically deposits reagents in your bank.",
                            get   = function() return self.db.char.bSilentMode end,
                            set   = function() self.db.char.bSilentMode = not self.db.char.bSilentMode end,
						},
						divider14 = {
							order	= 21,
							type	= "description",
							name	= "",
						},
						bankKeyDropdownMenu = {
							order	= 22,
							type 	= "select",
							name    = "Don't run with key is down",
							desc    = "Don't run 'deposits reagents' with key is down.",
							style	= "dropdown",
							values 	= {
								[0] = "none",
								[1] = "shift",
								[2] = "ctrl",
								[3] = "alt",
							},
							get   	= function(info, value) return self.db.char.bankModKey end,
							set		= function(info, value) self.db.char.bankModKey = value end,
						},
						divider15 = {
							order	= 23,
							type	= "description",
							name	= "",
						},
						divider16 = {
							order	= 24,
							type	= "header",
							name	= "Informations",
						},
						divider17 = {
							order	= 25,
							type	= "description",
							name	= "",
						},
						informationDescription = {
							order	= 26,
							type	= "description",
							width	= "full",
							name	= [[
            MerchantNBank Tools by Junxx @ Khaz'goroth - EU / Smallinger on wowinterface.com or Curse.com
                                ]],
						},
						divider18 = {
							order	= 27,
							type	= "description",
							name	= "",
						},
					}
				}
			}
		}
	end
end