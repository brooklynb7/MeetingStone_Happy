BuildEnv(...)

local memorize = require('NetEaseMemorize-1.0')
local nepy = require('NetEasePinyin-1.0')
local Base64 = LibStub('NetEaseBase64-1.0')
local AceSerializer = LibStub('AceSerializer-3.0')

local RoleIconTextures = {
    [1] = "Interface/AddOns/MeetingStone/Media/SunUI/TANK.tga",
    [2] = "Interface/AddOns/MeetingStone/Media/SunUI/Healer.tga",
    [3] = "Interface/AddOns/MeetingStone/Media/SunUI/DPS.tga",
}
local classNameToSpecIcon = {}
local classNameToSpecId = {}
for classID = 1, 13 do
    local classFile = select(2, GetClassInfo(classID)) -- "WARRIOR"
    if classFile then
        for specIndex = 1, 4 do
            local specId, localizedSpecName, _, icon = GetSpecializationInfoForClassID(classID, specIndex)
            if specId and localizedSpecName and icon then
                classNameToSpecIcon[classFile .. localizedSpecName] = icon
                classNameToSpecId[classFile .. localizedSpecName] = specId
            end
        end
    end
end

function GetClassColorText(className, text)
    local color = RAID_CLASS_COLORS[className]
    return format('|c%s%s|r', color.colorStr, text)
end

function IsGroupLeader()
    return not IsInGroup(LE_PARTY_CATEGORY_HOME) or UnitIsGroupLeader('player', LE_PARTY_CATEGORY_HOME)
end

function GetFullName(name, realm)
    if not name then
        return
    end
    if not realm or realm == '' then
        name, realm = strsplit('-', name)
        realm = realm or GetRealmName()
    end
    return format('%s-%s', name, realm)
end

function UnitFullName(unit)
    return GetFullName(UnitName(unit))
end

function IsActivityManager()
    return UnitIsGroupLeader('player', LE_PARTY_CATEGORY_HOME) or
        (IsInRaid(LE_PARTY_CATEGORY_HOME) and UnitIsGroupAssistant('player', LE_PARTY_CATEGORY_HOME))
end

function ToggleCreatePanel(...)
    MainPanel:SelectPanel(ManagerPanel)
    if not CreatePanel:IsActivityCreated() then
        CreatePanel:SelectActivity(...)
    end
end

function GetPlayerClass()
    return (select(3, UnitClass('player')))
end

function GetPlayerItemLevel(isPvP)
    if isPvP then
        return floor(select(3, GetAverageItemLevel()))
    else
        return floor(GetAverageItemLevel())
    end
end

-- DecodeCommetData = memorize.multirets(function(comment)
--     if not comment or comment == '' then
--         return nil
--     end
--     local summary, data = comment:match('^(.*)%((^1^.+^^)%)$')
--     if data then
--         if data:match('%^[ZBbTt][^^]') then
--             return false
--         end
--         -- olddata = data
--         -- data = data:gsub('%^([^%dSNFfTtBbZ^])', '\126\125%1')
--         -- if olddata ~= data then
--         --     print(data, olddata)
--         -- end
--         return true, summary, AceSerializer:Deserialize(data)
--     else
--         return false, comment
--     end
-- end)

function DecodeCommetData(comment)
    if not comment or comment == '' then
        return true, ''
    end
    local summary, data = comment:match('^(.*)%((^1^.+^^)%)$')
    if not data then
        return true, comment
    end

    local proto = ActivityProto:New()
    local ok, valid = proto:Deserialize(data)
    if not valid then
        return false
    end
    if not ok then
        return true, comment
    end
    return true, summary, proto
end

function CompressNumber(n)
    n = tonumber(n)
    return n and n > 0 and n or nil
end

function CodeCommentData(activity)
    local activityId = activity:GetActivityID()
    local customId = activity:GetCustomID()
    local data = format('(%s)',
        AceSerializer:Serialize(CompressNumber(customId), ADDON_VERSION_SHORT, activity:GetMode(),
            activity:GetLoot(), GetPlayerClass(),
            GetPlayerItemLevel(activity:IsUseHonorLevel()),
            GetPlayerRaidProgression(activityId, customId),
            GetPlayerPvPRating(activityId), CompressNumber(activity:GetMinLevel()),
            CompressNumber(activity:GetMaxLevel()),
            CompressNumber(activity:GetPvPRating()), GetAddonSource(),
            GetPlayerFullName(), GetPlayerSavedInstance(customId), nil,
            CompressNumber(
                activity:IsUseHonorLevel() and UnitHonorLevel('player') or nil)))
    return data
end

function GetSafeSummaryLength(activityId, customId, mode, loot)
    local data = format('(%s)', AceSerializer:Serialize(customId, ADDON_VERSION_SHORT, mode, loot, GetPlayerClass(),
        GetPlayerItemLevel(IsUseHonorLevel(activityId)),
        GetPlayerRaidProgression(activityId, customId),
        GetPlayerPvPRating(activityId), 999, 999,
        IsUsePvPRating(activityId) and 9999 or nil, GetAddonSource(),
        GetPlayerFullName(), GetPlayerSavedInstance(customId), format(
            '%s-%s-%s', GetModeName(mode), GetLootName(loot),
            GetActivityName(activityId, customId)), CompressNumber(
            IsUseHonorLevel(activityId) and UnitHonorLevel('player') or
            nil)))
    return min(MAX_MEETINGSTONE_SUMMARY_LETTERS, MAX_SUMMARY_LETTERS - strlenutf8(data))
end

function GetPlayerFullName()
    return (format('%s-%s', UnitName('player'), GetRealmName()):gsub('%s+', ''))
end

function CodeDescriptionData(activity)
    if not activity:IsMeetingStone() then
        return nil, 0
    else
        local activityId = activity:GetActivityID()
        local data = format('(%s)',
            AceSerializer:Serialize(GetPlayerRaidProgression(activityId, activity:GetCustomID()),
                GetPlayerPvPRating(activityId), GetAddonSource()))
        return data, strlenutf8(data)
    end
end

function DecodeDescriptionData(description)
    if not description or description == '' then
        return
    end
    local summary, data = description:match('^(.*)%((.+)%)$')
    if data then
        return summary, AceSerializer:Deserialize(data)
    else
        return description
    end
end

function GetClassColoredText(class, text)
    if not class or not text then
        return text
    end
    local color = RAID_CLASS_COLORS[class]
    if color then
        return format('|c%s%s|r', color.colorStr, text)
    end
    return text
end

function GetActivityCode(activityId, customId, categoryId, groupId)
    if activityId and (not categoryId or not groupId) then
        --2022-11-17
        local activityInfo = C_LFGList.GetActivityInfoTable(activityId);
        categoryId = activityInfo.categoryID;
        groupId = activityInfo.groupFinderActivityGroupID;
        --categoryId, groupId = select(3, C_LFGList.GetActivityInfo(activityId))
    end
    return format('%d-%d-%d-%d', categoryId or 0, groupId or 0, activityId or 0, customId or 0)
end

--2022-11-17
function IsUseHonorLevel(activityId)
    if activityId then
        local activityInfo = C_LFGList.GetActivityInfoTable(activityId);
        return activityId and activityInfo.useHonorLevel;
    end
end

function IsMythicPlusActivity(activityId)
    if activityId then
        local activityInfo = C_LFGList.GetActivityInfoTable(activityId);
        return activityId and activityInfo.isMythicActivity;
    end
end

function IsRatedPvpActivity(activityId)
    if activityId then
        local activityInfo = C_LFGList.GetActivityInfoTable(activityId);
        return activityId and activityInfo.isRatedPvpActivity;
    end
end

local PVP_INDEXS = { [6] = 1, [7] = 1, [8] = 1, [19] = 2 }

function IsUsePvPRating(activityId)
    return PVP_INDEXS[activityId]
end

function GetPlayerPvPRating(activityId)
    local ratingType = PVP_INDEXS[activityId]
    if not ratingType then
        return
    end

    if ratingType == 2 then
        return (GetPersonalRatedInfo(4))
    else
        return max((GetPersonalRatedInfo(1)), (GetPersonalRatedInfo(2)), (GetPersonalRatedInfo(3)))
    end
end

function GetPlayerBattleTag()
    return (select(2, BNGetInfo()))
end

function GetRaidProgressionData(activityId, customId)
    return CUSTOM_PROGRESSION_LIST[customId] or RAID_PROGRESSION_LIST[activityId]
end

function GetPlayerRaidProgression(activityId, customId)
    local list = GetRaidProgressionData(activityId, customId)
    if not list then
        return
    end

    local result = 0
    for i, v in ipairs(list) do
        if tonumber((GetStatistic(v.id))) or (v.id2 and tonumber((GetStatistic(v.id2)))) then
            result = bit.bor(result, bit.lshift(1, i - 1))
        end
    end
    return result
end

function GetPlayerSavedInstance(customId)
    local data = ACTIVITY_CUSTOM_INSTANCE[customId]
    if not data then
        return
    end

    for i = 1, GetNumSavedInstances() do
        local name, id, _, difficulty, locked, extended, _, _, _, difficultyName, numEncounters =
            GetSavedInstanceInfo(i)
        if name == data.instance and (not data.difficulty or data.difficulty == difficultyName) then
            local result = 0
            for bossIndex = 1, numEncounters do
                if select(3, GetSavedInstanceEncounterInfo(i, bossIndex)) then
                    result = bit.bor(result, bit.lshift(1, bossIndex - 1))
                end
            end
            return result ~= 0 and result or nil
        end
    end
end

function GetProgressionTex(value, bossIndex)
    local killed = bit.band(value, bit.lshift(1, bossIndex - 1)) > 0

    return killed and [[|TINTERFACE\FriendsFrame\StatusIcon-Online:16|t]] or
        [[|TINTERFACE\FriendsFrame\StatusIcon-Offline:16|t]]
end

function GetActivityName(activityId, customId)
    return customId and ACTIVITY_CUSTOM_NAMES[customId] or ACTIVITY_NAME_CACHE[activityId]
end

function GetActivityShortName(activityId, customId)
    return customId and ACTIVITY_CUSTOM_SHORT_NAMES[customId] or select(2, C_LFGList.GetActivityInfo(activityId))
end

function GetModeName(mode)
    return ACTIVITY_MODE_NAMES[mode]
end

function GetLootName(loot)
    return ACTIVITY_LOOT_LONG_NAMES[loot]
end

function GetLootShortName(loot)
    return ACTIVITY_LOOT_NAMES[loot]
end

function CodeActivityTitle(activityId, customId, mode, loot)
    return format('%s-%s-%s-%s', L['集合石'], GetLootName(loot), GetModeName(mode),
        GetActivityName(activityId, customId))
end

function GetFullVersion(version)
    return version:gsub('(%d)(%d)(%d%d)', '%10%200.%3')
end

function FormatActivitiesSummaryUrl(summary, url)
    return (summary:gsub('{URL([^}]*)}', function(info)
        local path, text = info:match('^(.*):(.+)$')
        if not path then
            path = info
            text = url .. path
        end
        return format('|Hurl:%s%s|h|cff00ffff[%s]|r|h', url, path, text)
    end):gsub('{QR([^:}]+):([^}]+)}', function(title, info)
        return format('|Hqrcode:%s|h|cffff64ec[%s]|r|h', info, title)
    end))
end

function SummaryToHtml(text)
    return text:gsub('^', '<html><body><p>　　'):gsub('$', '</p></body></html>'):gsub('[\r\n]+', '</p><p>　　')
end

CheckSpamWord, ClearSpamWordCache = memorize.normal(function(word)
    if not word then
        return
    end
    for i, v in ipairs(Profile:GetSpamWords()) do
        if strfind(word, v.text, 1, v.pain) then
            return true
        end
    end
    return false
end)

CheckContent, ClearCheckContentCache = memorize.normal(function(content)
    if content == nil then
        return
    end
    local filterPinyin, filterNormal = Addon:GetFilterData()
    if filterPinyin then
        local pinyin = nepy.utf8topinyin(nepy.unchinesefilter(nepy.toutf8(content:lower():gsub('[\001-\127]+', ''))))

        for i, v in ipairs(filterPinyin) do
            if pinyin:match(v) then
                return true
            end
        end
    end
    if filterNormal then
        for i, v in ipairs(filterNormal) do
            if content:match(v) then
                return true
            end
        end
    end
    return false
end)

function PlayerHasPet(name)
    return select(2, C_PetJournal.FindPetIDByName(name)) ~= nil
end

function PlayerHasItem(id)
    for i = -3, 11 do
        for j = 1, GetContainerNumSlots(i) do
            if GetContainerItemID(i, j) == id then
                return true
            end
        end
    end
end

function PlayerHasMount(id)
    return Addon:FindMount(id)
end

function IsSoloCustomID(customId)
    return customId == SOLO_HIDDEN_CUSTOM_ID or customId == SOLO_VISIBLE_CUSTOM_ID
end

local RAID_UNITS = {}
do
    for i = 1, 40 do
        tinsert(RAID_UNITS, 'raid' .. i)
    end
end

local PARTY_UNITS = {}
do
    for i = 1, 4 do
        tinsert(PARTY_UNITS, 'party' .. i)
    end
    tinsert(PARTY_UNITS, 'player')
end

function IterateGroupUnits()
    if not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return nop
    elseif IsInRaid(LE_PARTY_CATEGORY_HOME) then
        return ipairs(RAID_UNITS)
    else
        return ipairs(PARTY_UNITS)
    end
end

function GetAddonSource()
    for line in gmatch(
        '\066\105\103\070\111\111\116\058\049\010\033\033\033\049\054\051\085\073\033\033\033\058\050\010\068\117\111\119\097\110\058\052\010\069\108\118\085\073\058\056',
        '[^\r\n]+') do
        local n, v = line:match('^(.+):(%d+)$')
        if C_AddOns.IsAddOnLoaded(n) then
            return tonumber(v)
        end
    end
    return 0
end

--[=[@bigfoot@
function GetAddonSource()
end
--@end-bigfoot@]=]

function GetGuildName()
    local name, _, _, realm = GetGuildInfo('player')
    return name and GetFullName(name, realm) or nil
end

function ChatTargetAppToSystem(chatTarget)
    return chatTarget and chatTarget:gsub(APP_WHISPER_DOT, '-')
end

function ChatTargetSystemToApp(chatTarget)
    return chatTarget and chatTarget:gsub('-', APP_WHISPER_DOT)
end

function IsChatTargetApp(chatTarget)
    return chatTarget and chatTarget:find(APP_WHISPER_DOT, nil, true)
end

function UnpackIds(data)
    local min_id, data = data:match('^(%d+):(.+)$')
    min_id = tonumber(min_id)

    data = Base64:DeCode(data)

    local list = {}
    local offset = 0
    local byte, b
    for i = 1, #data do
        byte = data:byte(i)
        for j = 7, 0, -1 do
            b = bit.band(byte, bit.lshift(1, j)) > 0 and 1 or 0
            if b == 1 then
                table.insert(list, min_id + offset)
            end
            offset = offset + 1
        end
    end
    return list
end

function ListToMap(list)
    local map = {}
    do
        for i, v in pairs(list) do
            map[v] = true
        end
    end
    return map
end

GetAutoCompleteItem = setmetatable({}, {
    __index = function(t, activityId)
        --2022-11-17
        --local name, shortName, category, group, iLevel, filters, minLevel, maxMembers, displayType =
        -- C_LFGList.GetActivityInfo(activityId)

        local activityInfo = C_LFGList.GetActivityInfoTable(activityId);
        local name = activityInfo.fullName;
        local shortName = activityInfo.shortName;
        local category = activityInfo.categoryID;
        local group = activityInfo.groupFinderActivityGroupID;
        local filters = activityInfo.filters;

        local iLevel = activityInfo.ilvlSuggestion;
        local minLevel = activityInfo.minLevel;
        local maxMembers = activityInfo.maxNumPlayers;
        local displayType = activityInfo.displayType;

        t[activityId] = {
            name = name,
            order = 0xffff - (ACTIVITY_ORDER.A[activityId] or ACTIVITY_ORDER.G[group] or 0),
            activityId = activityId,
            code = GetActivityCode(activityId, nil, category, group),
        }
        return t[activityId]
    end,
    __call = function(t, activityId)
        return t[activityId]
    end,
})

function FormatSummary(text, tbl)
    return text:gsub('{{([%w_]+)}}', function(key)
        if type(tbl[key]) == 'function' then
            return tbl[key](tbl) or ''
        end
        return tbl[key] or ''
    end)
end

local function UrlButtonOnClick(self)
    GUI:CallUrlDialog(self.url)
end

function ApplyUrlButton(button, url)
    if url then
        button:SetScript('OnClick', UrlButtonOnClick)
        button.url = url
    else
        button:SetScript('OnClick', nil)
        button.url = nil
    end
end

--------------------------
-- NDui MOD
--------------------------
local _G = _G
local wipe = wipe
local select = select
local sort = sort

local UnitClass = UnitClass
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local C_LFGList_GetSearchResultMemberInfo = C_LFGList.GetSearchResultMemberInfo
local hooksecurefunc = hooksecurefunc

local roleCache = {}
local roleOrder = {
    ["TANK"] = 1,
    ["HEALER"] = 2,
    ["DAMAGER"] = 3,
}
local roleAtlas = {
    [1] = "groupfinder-icon-role-large-tank",
    [2] = "groupfinder-icon-role-large-heal",
    [3] = "groupfinder-icon-role-large-dps",
}

local function sortRoleOrder(a, b)
    if a and b then
        return a[1] < b[1]
    end
end

local function GetPartyMemberInfo(index)
    local unit = "player"
    if index > 1 then unit = "party" .. (index - 1) end

    local class = select(2, UnitClass(unit))
    if not class then return end
    local role = UnitGroupRolesAssigned(unit)
    if role == "NONE" then role = "DAMAGER" end
    return role, class
end

local function GetCorrectRoleInfo(frame, i)
    if frame.resultID then
        return C_LFGList_GetSearchResultMemberInfo(frame.resultID, i)
    elseif frame == ApplicationViewerFrame then
        return GetPartyMemberInfo(i)
    end
end

local function UpdateGroupRoles(self)
    wipe(roleCache)
    if not self.__owner then
        self.__owner = self:GetParent():GetParent()
    end

    local count = 0
    for i = 1, 5 do
        local role, class, classCN, spec = GetCorrectRoleInfo(self.__owner, i)

        local roleIndex = role and roleOrder[role]
        if roleIndex then
            count = count + 1
            if not roleCache[count] then roleCache[count] = {} end
            roleCache[count][1] = roleIndex
            roleCache[count][2] = class
            roleCache[count][3] = i == 1
            roleCache[count][4] = spec
        end
    end

    sort(roleCache, sortRoleOrder)
end

local function CheckShowIcons(frame)
    local isLFGList
    while true do
        if frame == LFGListFrame then
            isLFGList = true
            break
            -- There is no such frame named MeetingStoneFrame
        elseif frame == nil then
            isLFGList = false
            break
        end
        frame = frame:GetParent()
    end

    if not isLFGList then
        if not Profile:GetShowClassIco() then
            return "orig"
        elseif C_AddOns.IsAddOnLoaded("ElvUI_WindTools") and Profile:GetShowWindClassIco() then
            -- Module LFGList does not initialize when PremadeGroupsFilter is loaded
            -- print(WindTools[3].private.WT.misc.lfgList.enable)
            if not C_AddOns.IsAddOnLoaded("PremadeGroupsFilter") and WindTools[3].private.WT.misc.lfgList.enable then
                return "wind"
            else
                return "orig"
            end
        else
            return "meet"
        end
    else
        if C_AddOns.IsAddOnLoaded("PremadeGroupsFilter") then
            return "orig"
        elseif C_AddOns.IsAddOnLoaded("ElvUI_WindTools") and WindTools[3].private.WT.misc.lfgList.enable then
            return "wind"
        elseif Profile:GetShowClassIco() and not Profile:GetClassIcoMsOnly() then
            return "meet"
        else
            return "orig"
        end
    end
end

local function ReplaceGroupRoles(self, numPlayers, _, disabled)
    local flagCheckShowIcons = CheckShowIcons(self)
    if flagCheckShowIcons == "orig" then
        return
    elseif flagCheckShowIcons == "wind" then
        return WindTools[1]:GetModule("LFGList"):UpdateEnumerate(self)
    end

    local flagCheckShowSpecIcon = Profile:GetShowSpecIco()
    local flagCheckShowSmRoleIcon = Profile:GetShowSmRoleIco()

    UpdateGroupRoles(self)
    for i = 1, 5 do
        local icon = self.Icons[i]
        if not icon.role then
            icon.role = self:CreateTexture(nil, "OVERLAY")
            icon.role:SetSize(24, 24)
            -- icon.role:SetPoint("TOPLEFT", icon, -4, 5)
            if i == 1 then
                icon.role:SetPoint("RIGHT", -5, -2)
            else
                icon.role:ClearAllPoints()
                icon.role:SetPoint("RIGHT", self.Icons[i - 1].role, "LEFT", 0, 0)
            end
            icon.leader = self:CreateTexture(nil, "OVERLAY")
            icon.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
            icon.leader:SetRotation(rad(-15))
        end

        if i > numPlayers then
            icon.role:Hide()
        else
            icon.role:Show()
            icon.role:SetDesaturated(disabled)
            icon.role:SetAlpha(disabled and .5 or 1)
            icon.leader:SetDesaturated(disabled)
            icon.leader:SetAlpha(disabled and .5 or 1)
        end

        --icon.RoleIconWithBackground:Hide()
        --icon.RoleIcon:Hide()
        --icon.ClassCircle:Hide()
        --icon.Textures
        --icon.role:Hide()
        icon.leader:Hide()
    end

    local iconIndex = numPlayers
    for i = 1, #roleCache do
        local roleInfo = roleCache[i]
        if roleInfo then
            local icon = self.Icons[iconIndex]
            if flagCheckShowSmRoleIcon then
                icon:SetSize(15, 15)
                icon:SetPoint("TOPLEFT", icon.role, -4, 6)
                icon.leader:SetSize(13, 13)
                icon.leader:SetPoint("TOP", icon.role, 4, 8)
            else
                icon:SetSize(18, 18)
                icon:SetPoint("TOPLEFT", icon.role, -4, 5)
                icon.leader:SetSize(16, 16)
                icon.leader:SetPoint("TOP", icon.role, 4, 8)
            end

            if roleInfo[4] and flagCheckShowSpecIcon then
                -- print(classNameToSpecId[roleInfo[2]..roleInfo[4]])
                local spec_id = classNameToSpecId[roleInfo[2] .. roleInfo[4]]
                if spec_id == nil then
                    icon.role:SetTexture(classNameToSpecIcon[roleInfo[2] .. roleInfo[4]])
                else
                    icon.role:SetTexture("Interface/AddOns/MeetingStone/Media/SpellIcon/circular_" .. spec_id)
                end
                -- print(classNameToSpecIcon[roleInfo[2]..roleInfo[4]])
            else
                icon.role:SetTexture("Interface/AddOns/MeetingStone/Media/ClassIcon/" ..
                    string.lower(roleInfo[2]) .. "_flatborder2")
            end

            if roleInfo[1] and RoleIconTextures[roleInfo[1]] then
                -- icon.RoleIconWithBackground:SetTexture(RoleIconTextures[roleInfo[1]])
                icon.RoleIconWithBackground:SetAtlas(roleAtlas[roleInfo[1]])
            end

            -- icon.role:SetAtlas(roleAtlas[roleInfo[1]])
            icon.leader:SetShown(roleInfo[3])
            iconIndex = iconIndex - 1
        end
    end

    for i = 1, iconIndex do
        self.Icons[i].role:SetAtlas(nil)
    end
end

function InitMeetingStoneClass()
    local F = "LFGListGroupDataDisplayEnumerate_Update"
    Profile:OnInitialize()

    if not C_AddOns.IsAddOnLoaded("ElvUI_WindTools") then
        hooksecurefunc(F, ReplaceGroupRoles)
    else
        local W, _, E = unpack(WindTools)
        local L = W:GetModule("LFGList")
        E:Delay(0, function()
            if L:IsHooked(F) then L:Unhook(F) end
            L:SecureHook(F, ReplaceGroupRoles)
        end)
    end
end

function GetPlayerRegion()
    local regionTable = { "US", "KR", "EU", "TW", "CN" }
    local playerAccountInfo = C_BattleNet.GetAccountInfoByGUID(UnitGUID("player"))
    local currentRegion = GetCurrentRegion()

    if not playerAccountInfo or not playerAccountInfo.gameAccountInfo or not playerAccountInfo.gameAccountInfo.regionID then
        return regionTable[currentRegion]
    else
        return regionTable[playerAccountInfo.gameAccountInfo.regionID]
    end
end

function GetPortalByLocale()
    local gameLocale = GetLocale()
    local portalVal
    if gameLocale == "zhTW" then
        portalVal = 'TW'
    elseif gameLocale == "zhCN" then
        portalVal = 'CN'
    else
        portalVal = 'US'
    end

    return portalVal
end

function GetDungeonScoreRarityColor(score)
    return C_ChallengeMode.GetDungeonScoreRarityColor(score) or
        HIGHLIGHT_FONT_COLOR
end

function GetSpecificDungeonOverallScoreRarityColor(score)
    return C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(score) or
        HIGHLIGHT_FONT_COLOR
end

-- ****** Fix ColorMixin issue from 11.0 - Start ****** --
local CreateColor = CreateColor
--- ColorMixin is a mixin that provides functionality for working with colors.
---@class ColorMixin : table
ColorMixin = {}

---@class colorRGB : table, ColorMixin
---@field r number
---@field g number
---@field b number

---Sets the RGBA values of the color.
---@param r number The red component of the color (0-1).
---@param g number The green component of the color (0-1).
---@param b number The blue component of the color (0-1).
---@param a? number The alpha component of the color (0-1).
function ColorMixin:SetRGBA(r, g, b, a) end

---Sets the RGB values of the color.
---@param r number The red component of the color (0-1).
---@param g number The green component of the color (0-1).
---@param b number The blue component of the color (0-1).
function ColorMixin:SetRGB(r, g, b) end

---Returns the RGB values of the color.
---@return number r
---@return number g
---@return number b
function ColorMixin:GetRGB() return 0, 0, 0 end

---Returns the RGB values of the color as bytes (0-255).
---@return number red
---@return number green
---@return number blue
function ColorMixin:GetRGBAsBytes() return 0, 0, 0 end

---Returns the RGBA values of the color.
---@return number red
---@return number green
---@return number blue
---@return number alpha
function ColorMixin:GetRGBA() return 0, 0, 0, 0 end

---Returns the RGBA values of the color as bytes (0-255).
---@return number red
---@return number green
---@return number blue
---@return number alpha
function ColorMixin:GetRGBAAsBytes() return 0, 0, 0, 0 end

---Checks if the RGB values of this color are equal to another color.
---@param otherColor table The other color to compare with.
---@return boolean bIsEqual if the RGB values are equal, false otherwise.
function ColorMixin:IsRGBEqualTo(otherColor) return true end

---Checks if this color is equal to another color.
---@param otherColor table The other color to compare with.
---@return boolean True if the RGB and alpha values are equal, false otherwise.
function ColorMixin:IsEqualTo(otherColor) return true end

---Generates a hexadecimal color string with alpha.
---@return string hexadecimal color string with alpha.
function ColorMixin:GenerateHexColor() return "" end

---Generates a hexadecimal color string without alpha.
---@return string hexadecimal color string without alpha.
function ColorMixin:GenerateHexColorNoAlpha() return "" end

---Generates a hexadecimal color markup string.
---@return string hexadecimal color markup string.
function ColorMixin:GenerateHexColorMarkup() return "" end

-- Function to convert RGB values to hexadecimal string
function ColorMixin:RGBToHex(r, g, b)
    -- Convert normalized RGB values to 0-255 range
    local red = math.floor(r * 255 + 5)
    local green = math.floor(g * 255 + 5)
    local blue = math.floor(b * 255 + 5)

    -- Ensure values are within range
    red = math.max(0, math.min(255, red))
    green = math.max(0, math.min(255, green))
    blue = math.max(0, math.min(255, blue))

    -- Convert to hexadecimal format
    return string.format("%02X%02X%02X", red, green, blue)
end

---Wraps the given text in a color code using this color.
---@param text string The text to wrap.
---@return string The wrapped text with the color code.
function ColorMixin:WrapTextInColorCode(text)
    local color = CreateColor(self.r, self.g, self.b, 1)
    local hex = color:GenerateHexColor()
    return "|c" .. hex .. text .. "|r"
end

-- ****** Fix ColorMixin issue from 11.0 - End ****** --

-- originally sourced from Blizzard_Deprecated/Deprecated_10_1_5.lua
function GetTexCoordsForRoleSmallCircle(role)
    if (role == 'TANK') then
        return 0, 19 / 64, 22 / 64, 41 / 64
    elseif (role == 'HEALER') then
        return 20 / 64, 39 / 64, 1 / 64, 20 / 64
    elseif (role == 'DAMAGER') then
        return 20 / 64, 39 / 64, 22 / 64, 41 / 64
    end
end
