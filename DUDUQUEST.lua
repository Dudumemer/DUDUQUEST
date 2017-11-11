--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------
-- BEHAVIOR : 
-- 1. completes any completable quests
--   1a. Takes best reward or, if no upgrades, take highest vendor priced item
-- 2. picks up any available quests
-- 3. checks for gossip text and picks the first choice
--
-- USAGE:
-- edit the values below based on your class/spec
-- ctrl-copy everything into a Super Duper Macro script
-- make a regular macro to call the Super Duper Macro script
-- then spam the shit out of it during quest dialog
-- get SDM here: http://www.wowinterface.com/downloads/getfile.php?id=10496&aid=78141
--
-- double dashes ' -- ' is a comment, and anything on the the same line that goes after is ignored by lua
--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------

local statWeights = {                       --default values are guestimated stat weights for [gobo] arms war
  ITEM_MOD_HASTE_RATING_SHORT = 0.22,
  ITEM_MOD_AGILITY_SHORT = 0.5,
  ITEM_MOD_STRENGTH_SHORT = 1,
  ITEM_MOD_SPIRIT_SHORT = 0,
  ITEM_MOD_INTELLECT_SHORT = 0,
  ITEM_MOD_STAMINA_SHORT = 0,	
  ITEM_MOD_CRIT_RATING_SHORT = 0.66, 
  ITEM_MOD_HIT_RATING_SHORT = 1,
  ITEM_MOD_DODGE_RATING_SHORT = 0,
  ITEM_MOD_PARRY_RATING_SHORT = 0,
  ITEM_MOD_EXPERTISE_RATING_SHORT = 1, 
  ITEM_MOD_MASTERY_RATING_SHORT = 0.4, 
  ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 6,
  ITEM_MOD_ATTACK_POWER_SHORT = 0.46,
  ITEM_MOD_SPELL_POWER_SHORT = 0,
  RESISTANCE0_NAME = 0, -- armor value
}

local ONLY_CONSIDER_SPECIALIZATION_TYPE = false --set true to only check armor types of your class (for 5% bonus stat)
                                                --
                                                --leaving this false is useful for lvling/dungeon quests where
                                                --there's a nice agi quest reward, but your a str/plate class
                                                --**this option not heavily tested/debugged

local ignoreDPS = {           --ignores the weapon dps of these slots
  "INVTYPE_RANGEDRIGHT",      --if ur class uses a statstick weapon leave it here
  --"INVTYPE_WEAPONMAINHAND", --if not, remove/comment it out
  --"INVTYPE_WEAPONOFFHAND",  --default setting set to arms war
  --"INVTYPE_WEAPON",
  --"INVTYPE_2HWEAPON",
  "INVTYPE_THROWN",
}

local compareWithSlot = {  --comment/remove line of the item you dont want to check upgrades for 
  INVTYPE_HEAD = { 1 },    --i.e if you're a dualwield class comment out: --INVTYPE_2HWEAPON = { 16 },
  INVTYPE_NECK = { 2 },    --default setting for arms war
  INVTYPE_SHOULDER = { 3 },
  INVTYPE_SHIRT = { 4 },
  INVTYPE_ROBE = { 5 },
  INVTYPE_CHEST = { 5 },
  INVTYPE_WAIST = { 6 },
  INVTYPE_LEGS = { 7 },
  INVTYPE_FEET = { 8 },
  INVTYPE_WRIST = { 9 },
  INVTYPE_HAND = { 10 },
  INVTYPE_FINGER = { 11, 12 },
  INVTYPE_TRINKET = { 13, 14 },
  INVTYPE_CLOAK = { 15 },
  INVTYPE_2HWEAPON = { 16 },
  INVTYPE_WEAPON = { 16 },        -- INVTYPE_WEAPON = { 16, 17 }, if u dual wield
  INVTYPE_RANGEDRIGHT = { 18 },   --bows/wands/guns
 -- INVTYPE_HOLDABLE = { 17 },    --caster offhand
 -- INVTYPE_RELIC = { 18 },
 -- INVTYPE_SHIELD = { 17 },
  INVTYPE_WEAPONMAINHAND = { 16 },
  --INVTYPE_WEAPONOFFHAND = { 17 },
  INVTYPE_THROWN = { 18 },
}

----------------------------------------------------------------------------- dont edit below

local armorSpec = {
  DRUID = "Leather",
  DEATHKNIGHT = "Plate",
  ROGUE = "Leather",
  MAGE = "Cloth",
  PRIEST = "Cloth",
  WARLOCK = "Cloth",
  WARRIOR = "Plate",
  PALADIN = "Plate",
  HUNTER = "Mail",
  SHAMAN = "Mail",
}

local ignoreArmorTypes = {
  INVTYPE_SHIRT = true,
  INVTYPE_RELIC = true,
  INVTYPE_SHIELD = true,
  INVTYPE_CLOAK = true,
  INVTYPE_FINGER = true,
  INVTYPE_TRINKET = true,
  INVTYPE_NECK = true,
  INVTYPE_HOLDABLE = true,
}

local function Round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

local function SortQuestRewards(A, v, descending) --insertion sort
  for j = 2, #A do
    key = A[j]
    i = j - 1
    if not descending then
      while ( i > 0 and A[i][v] > key[v] ) do
        A[i + 1] = A[i]
        i = i - 1
      end
      A[i + 1] = key
    else
      while ( i > 0 and A[i][v] < key[v] ) do
        A[i + 1] = A[i]
        i = i - 1
      end
      A[i + 1] = key
    end
  end
end

local function CanIEquip(itemLink)
  if not itemLink then return end
  local myLevel = UnitLevel("player")
  local _, _, _, _, reqLevel = GetItemInfo(itemLink)
  local tip = myTooltipFromTemplate or CreateFrame("GAMETOOLTIP", "myTooltipFromTemplate",nil,"GameTooltipTemplate")
  tip:SetOwner(WorldFrame, "ANCHOR_NONE")
  tip:SetHyperlink(itemLink)
  local leftText = "myTooltipFromTemplateTextLeft3"
  local rightText = "myTooltipFromTemplateTextRight3"
  local r, b, g = _G[leftText]:GetTextColor()
  local r, b, g = Round(r*255), Round(b*255), Round(g*255)
  local r2, b2, g2 = _G[rightText]:GetTextColor()
  local r2, b2, g2 = Round(r2*255), Round(b2*255), Round(g2*255)

  if r == 255 and b == 255 and g == 255 and r2 == 255 and b2 == 255 and g2 == 255 and myLevel >= reqLevel then
    return true
  end
end

local function AggregateStats(itemLink, weights, slotIgnoreDPS)
    if not itemLink then return 0 end
    local itemStats = GetItemStats(itemLink)
    local itemSlot = select(9, GetItemInfo(itemLink))
    local weightedStats = 0
    local count = 0
    local count2 = 0
    
    for k, v in pairs(itemStats) do
      if ( weights[k] ) then
			count = count + 1
        if k == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then
          for i = 1, #slotIgnoreDPS do
            if slotIgnoreDPS[i] ~= itemSlot then
              count2 = count2 + 1
            end
          end
          if count2 == #slotIgnoreDPS then
            weightedStats = weightedStats + (weights[k] * v)
          end
        else
          weightedStats = weightedStats + (weights[k] * v)
        end
      end
    end
    if ( weightedStats == 0 and count == 1 and weights.RESISTANCE0_NAME == 0 and itemStats.RESISTANCE0_NAME ) then
        weightedStats = itemStats.RESISTANCE0_NAME/1000000 ---nice HACK M8
    end
    
    return weightedStats
end

local function GetQuestRewardItems()
  local rewards = {}

  for i = 1, GetNumQuestChoices() do
    local itemLink = GetQuestItemLink("choice", i)
    local itemName, _, _, _, _, itemType, itemSubType, _, itemInventorySlot, _, itemVendorPrice = GetItemInfo(itemLink)
    local epValue = AggregateStats(itemLink, statWeights, ignoreDPS)
    table.insert(rewards, { i, epValue, itemInventorySlot, itemSubType, itemVendorPrice, CanIEquip(itemLink), itemName, itemType })
  end

  return rewards
end

local function CompareRewardWithEquipped(rewards, matchSpecType)
  local _, myClass = UnitClass("player")
  local mySpec = armorSpec[myClass]
  local myLevel = UnitLevel("player")
  local upgrades = {}
  local count = 0

  for i = 1, #rewards do local questRewardItem, myItemLink, myItem
    if rewards[i][6] then
      if ( myLevel >= 50 and matchSpecType and rewards[i][8] == "Armor" ) then
        if ( rewards[i][4] == mySpec or ignoreArmorTypes[rewards[i][3]] ) then
          questRewardItem = rewards[i]
        end
      else
        questRewardItem = rewards[i]
      end

      for k, v in pairs(compareWithSlot) do
        if ( questRewardItem[3] == k ) then
          for j = 1, #v do
            myItemLink = GetInventoryItemLink("player", v[j])
            myItem = AggregateStats(myItemLink, statWeights, ignoreDPS)
            if ( questRewardItem[2] > myItem ) then
                table.insert(upgrades, rewards[i])
            end
          end
        end
      end
    end
  end
  SortQuestRewards(upgrades, 2, true)
  if #upgrades == 0 then
    if #rewards > 0 then
      print("no upgrades, choosing highest vendor priced item")
      for i = 1, #rewards do
        table.insert(upgrades, rewards[i])
      end
      SortQuestRewards(upgrades, 5, true)
    end
  else
    print("upgrade available, selecting", upgrades[1][7])
  end
  
  return upgrades
end
AcceptQuest()CompleteQuest()ConfirmAcceptQuest()
local indexQuest = 0
local gossipQuests = GetNumGossipActiveQuests()
local activeQuests = GetNumActiveQuests()
if gossipQuests > 0 then
  for i = 1, gossipQuests do
    if select(i*4, GetGossipActiveQuests()) == 1 then
      indexQuest = i
    end
  end
elseif activeQuests > 0 then
  for i = 1, activeQuests do
    if select(2, GetActiveTitle(i)) == true then
      indexQuest = i 
    end
  end
end
if QuestFrameCompleteQuestButton:IsVisible() then
  local questRewards = GetQuestRewardItems()
  local itemChoice = CompareRewardWithEquipped(questRewards, ONLY_CONSIDER_SPECIALIZATION_TYPE)
  if #questRewards > 0 then
    GetQuestReward(itemChoice[1][1])
  else
    GetQuestReward(1)
  end
elseif indexQuest > 0 then
  if gossipQuests > 0 then
    SelectGossipActiveQuest(indexQuest)
  elseif activeQuests > 0 then
    SelectActiveQuest(indexQuest)
end
elseif GetNumGossipAvailableQuests() > 0 then
  SelectGossipAvailableQuest(1)
elseif GetNumAvailableQuests() > 0 then
  SelectAvailableQuest(1)
elseif GetNumGossipOptions() > 0 then
  SelectGossipOption(1)
end
