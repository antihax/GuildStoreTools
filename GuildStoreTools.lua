local addonName = "GuildStoreTools"
local versionString = "v0.1.5"
local serverName = ""
local GST_Original_ZO_LinkHandler_OnLinkMouseUp 
GUILDSTORETOOLS_units = {}
GUILDSTORETOOLS_Variables = {}

local defaults = {
  left = 0,
  top = 0
}

local UnitList = ZO_SortFilterList:Subclass()
UnitList.defaults = {}
UnitList.SORT_KEYS = {
    ["eaPrice"] = {isNumeric=true},
    ["price"] = {isNumeric=true},
    ["stackCount"] = {isNumeric=true},
    ["npcName"] = {},
    ["zoneName"] = {} 
}

-- Returns a string with the server name.
local function getServerName() 
  local charName = GetUnitName("player")
  local uniqueName = GetUniqueNameForCharacter(charName)
  local serverName = string.sub(uniqueName, 1, string.find(uniqueName, charName)-2)
  return serverName
end

function UnitList:New(...)
  self.currentSortKey = "eaPrice"
  self.currentSortOrder = ZO_SORT_ORDER_UP
  return ZO_SortFilterList.New(self, ...)
end

function UnitList:Initialize(control, sv)
  self.masterList = {}
  ZO_SortFilterList.Initialize(self, control)
  ZO_ScrollList_AddDataType(self.list, 1, "DataUnitRow", 30, function(...) self:SetupUnitRow(...) end)
  ZO_ScrollList_EnableHighlight(self.list, "ZO_ThinListHighlight")
  self.sortFunction = function(listEntry1, listEntry2) return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, UnitList.SORT_KEYS, self.currentSortOrder) end
  self:RefreshData()
end

function UnitList:Refresh()
  self:RefreshData()
end

function UnitList:BuildMasterList()
  self.masterList = GUILDSTORETOOLS_units
  
  -- Since we do not have price each in the data, we must build them here.
  -- This is to save bandwidth since we can locally generate these data.
  for i = 1, #self.masterList do
    local data = self.masterList[i]
    data.eaPrice = data.price/data.stackCount
  end
end

function UnitList:FilterScrollList()
    if not self.masterList then return end
    
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    ZO_ClearNumericallyIndexedTable(scrollData)

    for i = 1, #self.masterList do
        local data = self.masterList[i]
      table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, data))
    end    
end

function UnitList:SortScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    table.sort(scrollData, self.sortFunction)
end

function UnitList:SetupUnitRow(control, data)
  control.eaPrice = GetControl(control, "EAPrice")
  control.price = GetControl(control, "Price")
  control.stackSize = GetControl(control, "StackSize")
  control.npcName = GetControl(control, "NPC")
  control.zoneName = GetControl(control, "Zone")
  
  control.eaPrice:SetText(ESODR_CurrencyToText(data.eaPrice))
  control.price:SetText(ESODR_NumberToText(data.price))
  control.stackSize:SetText(data.stackCount)
  control.npcName:SetText(data.npcName)
  control.zoneName:SetText(data.zoneName)
  control.data = data
  ZO_SortFilterList.SetupRow(self, control, data)
end

local function checkForESODataRelay()
  if not ESODataRelay then
    d("********************************")
    d("Guild Store Tools: ERROR!")
    d("The ESO Data Relay addon is missing.\n\nPlease download and install ESO Data Relay from http://www.ESOUI.com.")
    d("********************************")
    -- Complain a lot.
    zo_callLater(function() checkForESODataRelay() end, 1000 * 60 * 5)
  end
end

function GUILDSTORETOOLS_OnMoveStop()
  GUILDSTORETOOLS_Variables.left = GuildStoreToolsWindow:GetLeft()
  GUILDSTORETOOLS_Variables.top = GuildStoreToolsWindow:GetTop()
end

 -- Main entrypoint
local function GUILDSTORETOOLS_addonLoaded(eventCode, name)
  -- Prevent loading twice
  if name ~= addonName then return end

  -- get the serverName
  serverName = getServerName()

  -- Saved Variables
  GUILDSTORETOOLS_Variables = ZO_SavedVars:NewAccountWide("GuildStoreToolsSavedVariables", 1, "Position", defaults)

  -- Hook the link handler right click.
  GST_Original_ZO_LinkHandler_OnLinkMouseUp = ZO_LinkHandler_OnLinkMouseUp
  ZO_LinkHandler_OnLinkMouseUp = function(iL, b, c) 
    GUILDSTORETOOLS_LinkHandler_OnLinkMouseUp(iL, b, c) end

  ZO_PreHookHandler(ItemTooltip, "OnUpdate", function(c, ...) GUILDSTORETOOLS_OnTooltip(c) end)
  ZO_PreHookHandler(ItemTooltip, "OnHide",   function(c, ...) GUILDSTORETOOLS_OnHideTooltip(c) end)
  
  ZO_PreHook("ZO_InventorySlot_ShowContextMenu", function(c) GUILDSTORETOOLS_InventoryContextMenu(c) end)
  
  GuildStoreToolsWindow:ClearAnchors()
  GuildStoreToolsWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, GUILDSTORETOOLS_Variables.left, GUILDSTORETOOLS_Variables.top)
  
  -- Check and report if the uploader is running or not.
  zo_callLater(function() checkForESODataRelay() end, 2000)
end
EVENT_MANAGER:RegisterForEvent("GuildStoreTools", EVENT_ADD_ON_LOADED, GUILDSTORETOOLS_addonLoaded)

function GUILDSTORETOOLS_InventoryContextMenu(c)
  zo_callLater(function() 
    AddCustomSubMenuItem("|cAFEBFFGuild Store Tools|r", {
      {
        label = "Copy Item Statistics to Chat",
        callback = function() GUILDSTORETOOLS_StatsLinkMenu(link) end,
        },
        {
          label = "Show Item Data",
          callback = function() GUILDSTORETOOLS_ShowDataMenu(link) end,
        }
      })
    ShowMenu()
  end, 50)
end

 -- Copied from MasterMerchant (MIT license. Copyright (c) 2014, Dan Stone (aka @khaibit) / Chris Lasswell (aka @Philgo68))
function GUILDSTORETOOLS_LinkHandler_OnLinkMouseUp(link, button, control)
    if (type(link) == 'string' and #link > 0) then
    local handled = LINK_HANDLER:FireCallbacks(LINK_HANDLER.LINK_MOUSE_UP_EVENT, link, button, ZO_LinkHandler_ParseLink(link))
    if (not handled) then
            GST_Original_ZO_LinkHandler_OnLinkMouseUp(link, button, control)
            if (button == 2 and link ~= '') then        
                AddCustomSubMenuItem("|cAFEBFFGuild Store Tools|r", {
                  {
                    label = "Copy Item Statistics to Chat",
                    callback = function() GUILDSTORETOOLS_StatsLinkMenu(link) end,
                  },
                  {
                    label = "Show Item Data",
                    callback = function() GUILDSTORETOOLS_ShowDataMenu(link) end,
                  }
                })
                ShowMenu(control)
            end
        end
    end
end
-- END

local selectedItem

function GUILDSTORETOOLS_OnHideTooltip(tip)
  selectedItem = nil
end

function GUILDSTORETOOLS_OnTooltip(tip)
  local item = GUILDSTORETOOLS_GetItemLinkFromMOC()
  if selectedItem ~= item and tip then
    selectedItem = item
    
    local itemID = ESODR_ItemIDFromLink(item)
    local uniqueID = ESODR_UniqueIDFromLink(item)
    local data = GUILDSTORETOOLS_GetStatistics(item)
    
    if data then
      ZO_Tooltip_AddDivider(tip)
      tip:AddLine(
        data["days"] .. " days: " .. ESODR_NumberToText(data["count"]) .. 
        " sales and " .. ESODR_NumberToText(data["sum"]) .. 
        " items." 
        , "ZoFontGame", 255,255,255)
      tip:AddLine(
        "25th: " .. ESODR_CurrencyToText(data["p25th"]) ..
        "   median: " .. ESODR_CurrencyToText(data["median"]) ..
        "   75th: " .. ESODR_CurrencyToText(data["p75th"])
        , "ZoFontGame", 255,255,255)

    end
  end  
end

function GUILDSTORETOOLS_GetItemLinkFromMOC()
  local item = moc()
  if not item or not item.GetParent then return nil end
  local parent = item:GetParent()

  if parent then
    local parentName = parent:GetName()
    if (item.dataEntry and item.dataEntry.data.bagId) then
      return GetItemLink(item.dataEntry.data.bagId, item.dataEntry.data.slotIndex)
    elseif parentName == "ZO_StoreWindowListContents" then
      return GetStoreItemLink(item.dataEntry.data.slotIndex, LINK_STYLE_DEFAULT)
    elseif parentName == "ZO_TradingHouseItemPaneSearchResultsContents" 
      and item.dataEntry and item.dataEntry.data and item.dataEntry.data.timeRemaining then
      return GetTradingHouseSearchResultItemLink(item.dataEntry.data.slotIndex)
    elseif parentName == "ZO_TradingHousePostedItemsListContents" then
      return GetTradingHouseListingItemLink(item.dataEntry.data.slotIndex)
    end
  end
  return nil
end

function GUILDSTORETOOLS_GetStatistics(l)
  local days = 7
  local data = nil
  local data = ESODR_StatisticsForRange(ESODR_ItemIDFromLink(l), ESODR_UniqueIDFromLink(l), days)
  if not data or data["count"] < 10 then 
    days = 15
    data = ESODR_StatisticsForRange(ESODR_ItemIDFromLink(l), ESODR_UniqueIDFromLink(l), days)
    if not data or data["count"] < 10 then
      days = 30
      data = ESODR_StatisticsForRange(ESODR_ItemIDFromLink(l), ESODR_UniqueIDFromLink(l), days)
      if not data then
        days = 7
        data = ESODR_StatisticsForRange(ESODR_ItemIDFromLink(l), ESODR_UniqueIDFromLink(l), days)  
      end  
    end
  end
  
  if data then data["days"] = days end
  return data
end

function GUILDSTORETOOLS_StatsLinkMenu(l)
  local data = GUILDSTORETOOLS_GetStatistics(l)
  if not data then
    d("No data available for " .. l .. ".")
    return
  end
  
  local ChatEditControl = CHAT_SYSTEM.textEntry.editControl
  if (not ChatEditControl:HasFocus()) then StartChatInput() end
  ChatEditControl:InsertText(
    l .. 
    " " .. data["days"] .. " days: " .. ESODR_NumberToText(data["count"]) .. 
    " sales/" .. ESODR_NumberToText(data["sum"]) .. 
    " items. Price Stats: " ..  
    "   25th: " .. ESODR_CurrencyToText(data["p25th"]) ..
    "   median: " .. ESODR_CurrencyToText(data["median"]) ..
    "   75th: " .. ESODR_CurrencyToText(data["p75th"]))
end

function GUILDSTORETOOLS_ShowDataMenu(l)

  GuildStoreToolsWindow:SetHidden(false)
  local data = GUILDSTORETOOLS_GetStatistics(l)
  
  GuildStoreToolsWindow_Name:SetText(GetItemLinkName(l))
  
  if not data then
    GuildStoreToolsWindow_Sales:SetText("No Sales History")
    GuildStoreToolsWindow_Stats:SetText("")
    
  else
  
    GuildStoreToolsWindow_Sales:SetText("Observed " .. ESODR_NumberToText(data["count"]) .. 
        " sales totaling " .. ESODR_NumberToText(data["sum"]) .. 
        " items within " .. data["days"] .. " days.")
        
    GuildStoreToolsWindow_Stats:SetText(
        "5th: " .. ESODR_CurrencyToText(data["p5th"]) ..
        "  25th: " .. ESODR_CurrencyToText(data["p25th"]) ..
        "   median: " .. ESODR_CurrencyToText(data["median"]) ..
        "   75th: " .. ESODR_CurrencyToText(data["p75th"]) ..
        "   95th: " .. ESODR_CurrencyToText(data["p95th"]))
  end
  
  local itemID = ESODR_ItemIDFromLink(l)
  local uniqueID = ESODR_UniqueIDFromLink(l)
  
  GUILDSTORETOOLS_units = ESODR_GetGuildStoreItemTable(itemID, uniqueID)

  if not GUILDSTORETOOLS_units then GUILDSTORETOOLS_units = {} end
  GUILDSTORETOOLS_List:Refresh()
end

function GUILDSTORETOOLS_Window_OnInitialized(control)
  GUILDSTORETOOLS_List = UnitList:New(control)
end
