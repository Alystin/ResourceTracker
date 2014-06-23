-----------------------------------------------------------------------------------------------
-- Client Lua Script for ResourceTracker
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

-----------------------------------------------------------------------------------------------
-- ResourceTracker Module Definition
-----------------------------------------------------------------------------------------------
local ResourceTracker = {}

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function ResourceTracker:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- initialize variables here

    return o
end

function ResourceTracker:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end


-----------------------------------------------------------------------------------------------
-- ResourceTracker OnLoad
-----------------------------------------------------------------------------------------------
function ResourceTracker:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("ResourceTracker.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)

	-- Define some vars
	self.iFound = 0;
	self.tLoot = {}
	self.zoneItems = setmetatable({}, {__index = function(tbl, key) tbl[key] = {} return tbl[key] end })
	
	if GameLib.GetPlayerUnit() then
		self:Refresh()
	else
		Apollo.RegisterEventHandler("CharacterCreated", "Refresh", self)
	end
end

-----------------------------------------------------------------------------------------------
-- ResourceTracker OnDocLoaded
-----------------------------------------------------------------------------------------------
function ResourceTracker:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "SRTForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end

	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil

		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("srt", "OnSettlerResourceTrackerOn", self)
		Apollo.RegisterEventHandler("LootedItem","OnLooted", self)
		Apollo.RegisterEventHandler("UpdateInventory","Refresh", self)
		Apollo.RegisterEventHandler("SubZoneChanged", "OnSubZoneChanged", self)

		--self.timer = ApolloTimer.Create(1.0, true, "Refresh", self)

		-- Do additional Addon initialization here
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "SRTForm", nil, self)
		self.wndConfig = Apollo.LoadForm(self.xmlDoc, "SRTConfig", self.wndMain, self)
		self.wndConfig:Show(false)
		self.lootTable = self.wndMain:FindChild("Grid")
	end
end

-----------------------------------------------------------------------------------------------
-- ResourceTracker Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/srt"
function ResourceTracker:OnSettlerResourceTrackerOn()
	self.wndMain:Invoke() -- show the window
end

-- Saving Stuff
function ResourceTracker:OnSave(eType)
	if eType == GameLib.CodeEnumAddonSaveLevel.Character then
		return self.zoneItems
	end
end

-- Loading Stuff
function ResourceTracker:OnRestore(eType, tData)
	for k,v in pairs(tData) do
		self.zoneItems[k] = v
	end
end

-- Add an item to the zoneItems table
function ResourceTracker:RecordItem(item)
	self.zoneItems[GameLib.GetCurrentZoneMap().id][item:GetName()] = item:GetItemId()
end

-- Lookup an item in the zoneItems table
function ResourceTracker:Contains(item)
	return self.zoneItems[GameLib.GetCurrentZoneMap().id][item:GetName()]
end

-- Looting an item triggers this
function ResourceTracker:OnLooted(item, nCount)
	if item:GetItemCategory() == 111 then -- if we have a settler resource item...
	
		if self.wndMain:FindChild("NothingHere"):IsVisible(true) then
			self.wndMain:FindChild("Grid"):Invoke()
			self.wndMain:FindChild("NothingHere"):Close()
			self.wndMain:FindChild("Title"):SetText("Settler Resource Tracker")
		end

		local iName = item:GetName()
		local iId = item:GetItemId()
		local zoneId = GameLib.GetCurrentZoneMap().id

		if self:Contains(item) ~= true then -- ... and it's not in the table...
			if zoneId ~= 60 then -- ... and we're not in our house...
				self:RecordItem(item) -- add it to the table with the zone we're in.
			end
		end

		if type(self.tLoot[1]) == "table" then
			for i = 1, #self.tLoot do
				if self.tLoot[i][1] == iName then
					self.iFound = 1;

					local prev_val = self.tLoot[i][2]
					self.tLoot[i] = {
						iName,
						nCount + prev_val
					}

					self.lootTable:SetCellText(i, 2, self.tLoot[i][2]);
				end
			end

			if self.iFound == 0 then
				local key = #self.tLoot + 1;
				self.tLoot[key] = {
					iName,
					nCount
				}

				self.lootTable:AddRow(self.tLoot[key][1]);
				self.lootTable:SetCellText(key, 2, self.tLoot[key][2])
			end

			self.iFound = 0;

		else
			self.tLoot[1] = {
				iName,
				nCount
			}

			self.lootTable:AddRow(self.tLoot[1][1]);
			self.lootTable:SetCellText(1, 2, self.tLoot[1][2])
		end

		self:Refresh()
	end
end

function ResourceTracker:Refresh()
	self.tLoot = {}
	if self.lootTable then
		self.lootTable:DeleteAll()
	end
	if GameLib.GetPlayerUnit():GetSupplySatchelItems()["Settler Resources"] ~= nil then
		local settlerItems = GameLib.GetPlayerUnit():GetSupplySatchelItems()["Settler Resources"]
		local zoneId = GameLib.GetCurrentZoneMap().id
		
		for i, item in ipairs(settlerItems) do
			local iCount = item.nCount
			local sName = item.itemMaterial:GetName()
		
			if self.zoneItems[zoneId][sName] then
				if type(self.tLoot[1]) == "table" then
					for j = 1, #self.tLoot do
						if self.tLoot[j][1] == sName then
							self.iFound = 1;
							
							local oldVal = self.tLoot[j][2]
							self.tLoot[j] = {
								sName,
								oldVal + iCount
							}

							self.lootTable:SetCellText(j, 2, iCount)
						end
					end
				
					if self.iFound == 0 and self.zoneItems[zoneId][sName] then
						local key = #self.tLoot + 1;
						
						self.tLoot[key] = {
							sName,
							iCount
						}

						self.lootTable:AddRow(self.tLoot[key][1])
						self.lootTable:SetCellText(key, 2, self.tLoot[key][2])
					end
					self.iFound = 0
				
				else
					self.tLoot[1] = {
						sName,
						iCount
					}
					
					self.lootTable:AddRow(self.tLoot[1][1])
					self.lootTable:SetCellText(1, 2, self.tLoot[1][2])
				end
			end
		end
	else
		self.wndMain:FindChild("Grid"):Close()
		self.wndMain:FindChild("NothingHere"):Invoke()
		self.wndMain:FindChild("Title"):SetText("Sorry, cupcake! Nothin' to see.")
	end
end

-- Changing the Zone triggers this
function ResourceTracker:OnSubZoneChanged(idZone, pszZoneName)
	self:Refresh()
end
-----------------------------------------------------------------------------------------------
-- SettlerResourceTrackerForm Functions
-----------------------------------------------------------------------------------------------
-- when the Cancel button is clicked
function ResourceTracker:OnCancel()
	self.wndMain:Close() -- hide the window
end


---------------------------------------------------------------------------------------------------
-- SRTForm Functions
---------------------------------------------------------------------------------------------------

function ResourceTracker:RemoveRow(tData)
	self.test = tData
	self.zoneItems[GameLib.GetCurrentZoneMap().id][tData:GetCellText(tData:GetCurrentRow(), 1)] = nil
	self.lootTable:DeleteRow(tData:GetCurrentRow())
end

function ResourceTracker:OnConfig()
	self.wndConfig:Show(true, true)
end

---------------------------------------------------------------------------------------------------
-- SRTConfig Functions
---------------------------------------------------------------------------------------------------

function ResourceTracker:OnClose()
	self.wndConfig:Close()
end

-----------------------------------------------------------------------------------------------
-- ResourceTracker Instance
-----------------------------------------------------------------------------------------------
local SettlerResourceTrackerInst = ResourceTracker:new()
SettlerResourceTrackerInst:Init()
