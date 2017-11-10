--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------

-- BEHAVIOR : 
-- 1. completes any completable quests
--   1a. Takes best reward or, if no upgrades, take highest vendor priced item
-- 2. picks up any available quests
-- 3. checks for gossip text and picks the first choice
--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------


local statWeights = { 
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
  RESISTANCE0_NAME = 0 -- armor value
}

local ONLY_CONSIDER_SPECIALIZATION_TYPE = false --- only check armor types of your class. ie: hunter only wants mail when lvl 50+ for 5% agi

local compareWithSlot = {   ------ remove lines you dont want to consider i.e if you're a dualwield class, remove INVTYPE_2HWEAPON = { 16 },
  INVTYPE_HEAD = { 1 },
  INVTYPE_NECK = { 2 },
  INVTYPE_SHOULDER = { 3 },
  INVTYPE_SHIRT = { 4 },
  INVTYPE_ROBE = { 5 },
  INVTYPE_WAIST = { 6 },
  INVTYPE_LEGS = { 7 },
  INVTYPE_FEET = { 8 },
  INVTYPE_WRIST = { 9 },
  INVTYPE_HAND = { 10 },
  INVTYPE_FINGER = { 11, 12 },
  INVTYPE_TRINKET = { 13, 14 },
  INVTYPE_CLOAK = { 15 },
  INVTYPE_2HWEAPON = { 16 },
  INVTYPE_WEAPON = { 16 }, --- INVTYPE_WEAPON = { 16, 17 }, if u dual wield
  INVTYPE_RANGEDRIGHT = { 18 },
  INVTYPE_HOLDABLE = { 17 }, --caster offhand
  INVTYPE_RELIC = { 18 },
  INVTYPE_SHIELD = { 17 },
  INVTYPE_WEAPONMAINHAND = { 16 },
  INVTYPE_WEAPONOFFHAND = { 17 },
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
  SHAMAN = "Mail"
}

local function TableLength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
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

function CanIEquip(itemLink)
  if not itemLink then return end
  local myLevel = UnitLevel("player")
  local _, _, _, _, reqLevel = GetItemInfo(itemLink)
  local tip = myTooltipFromTemplate or CreateFrame("GAMETOOLTIP", "myTooltipFromTemplate",nil,"GameTooltipTemplate")
  tip:SetOwner(WorldFrame, "ANCHOR_NONE")
  tip:SetHyperlink(itemLink)
  local leftText = "myTooltipFromTemplateTextLeft3"
  local rightText = "myTooltipFromTemplateTextRight3"
  local r, b, g = _G[leftText]:GetTextColor()
  local r, b, g = math.round(r*255), math.round(b*255), math.round(g*255)
  local r2, b2, g2 = _G[rightText]:GetTextColor()
  local r2, b2, g2 = math.round(r2*255), math.round(b2*255), math.round(g2*255)

  if r == 255 and b == 255 and g == 255 and r2 == 255 and b2 == 255 and g2 == 255 and myLevel >= reqLevel then
    return true
  end
end

local function AggregateStats(itemLink, weights)
  if not itemLink then return 0 end
  local itemStats = GetItemStats(itemLink)
  local weightedStats = 0
  local count = 0

  for k, v in pairs(itemStats) do
    if ( weights[k] ) then
      weightedStats = weightedStats + (weights[k] * v)
      count = count + 1
    end
  end
  if ( weightedStats == 0 and count == 1 ) then
    weightedStats = weights.RESISTANCE0_NAME
  end

  return weightedStats
end

local function GetQuestRewardItems()
  local rewards = {}

  for i = 1, GetNumQuestChoices() do
    local itemLink = GetQuestItemLink("choice", i)
    local _, _, _, _, _, itemType, itemSubType, _, itemInventorySlot, _, itemVendorPrice = GetItemInfo(itemLink)
    local itemStats = AggregateStats(itemLink, statWeights)
    table.insert(rewards, { i, itemStats, itemInventorySlot, itemSubType, itemVendorPrice, CanIEquip(itemLink) })
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
      if ( myLevel >= 50 and matchSpecType ) then
        if ( rewards[i][4] == mySpec ) then
          questRewardItem = rewards[i]
        end
      else
        questRewardItem = rewards[i]
      end

      for k, v in pairs(compareWithSlot) do
        if ( questRewardItem[3] == k ) then
          for j = 1, #v do
            myItemLink = GetInventoryItemLink("player", v[j])
            myItem = AggregateStats(myItemLink, statWeights)
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
    print("no upgrades, choosing highest vendor priced item")
    for i = 1, #rewards do
      table.insert(upgrades, rewards[i])
    end
    SortQuestRewards(upgrades, 5, true)
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
