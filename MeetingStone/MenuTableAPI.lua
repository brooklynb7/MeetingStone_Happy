BuildEnv(...)

local makedCategorys = {}
local validCategorys = {}
local currentCodeCache

local historyMenuTables
local activityCodeCaches

do
    local function f()
        return { --
            [ACTIVITY_FILTER_BROWSE] = {},
            [ACTIVITY_FILTER_CREATE] = {},
            [ACTIVITY_FILTER_OTHER] = {},
        }
    end

    historyMenuTables = f()
    activityCodeCaches = f()
end

local function initValidCategorys()
    wipe(validCategorys)
    for i, baseFilter in ipairs({ Enum.LFGListFilter.PvE, Enum.LFGListFilter.PvP }) do
        for _, categoryId in ipairs(C_LFGList.GetAvailableCategories(baseFilter)) do
            validCategorys[categoryId] = true
        end
    end
end

local function isCategoryValid(categoryId)
    return validCategorys[categoryId]
end

local function MakeActivityMenuTable(activityId, baseFilter, customId, menuType)
    --2022-11-17
    --local fullName, shortName, categoryId, groupId, _, filters = C_LFGList.GetActivityInfo(activityId)

    local activityInfo = C_LFGList.GetActivityInfoTable(activityId);
    local fullName = activityInfo.fullName;
    local shortName = activityInfo.shortName;
    local categoryId = activityInfo.categoryID;
    local groupId = activityInfo.groupFinderActivityGroupID;
    local filters = activityInfo.filters;

    if customId then
        fullName = ACTIVITY_CUSTOM_NAMES[customId]
    end

    local data = {}

    -- 2 普通, 凋魂之殇（普通）  --print(categoryId, groupId, shortName, "," , fullName)
    -- 3 英雄,  尼奥罗萨，觉醒之城（英雄）
    -- 113 难度1, 扭曲回廊
    -- 4 2v2 竞技场（2v2）
    data.text = fullName
    if categoryId == 113 then
        data.text = fullName .. " " .. shortName
    end
    data.fullName = fullName
    data.categoryId = categoryId
    data.groupId = groupId
    data.activityId = activityId
    data.customId = customId
    data.filters = filters
    data.baseFilter = baseFilter
    data.value = GetActivityCode(activityId, customId, categoryId, groupId)
    if menuType == ACTIVITY_FILTER_BROWSE then
        --2022-11-17
        local categoryInfo = C_LFGList.GetLfgCategoryInfo(categoryId);
        data.full = categoryInfo.name
    end

    currentCodeCache[data.value] = data
    return data
end

local function MakeCustomActivityMenuTable(activityId, baseFilter, customId, menuType)
    local data = MakeActivityMenuTable(activityId, baseFilter, customId, menuType)

    local customData = ACTIVITY_CUSTOM_DATA.A[activityId]
    if customData and not customId then
        data.menuTable = {}
        data.hasArrow = true

        for _, id in ipairs(customData) do
            tinsert(data.menuTable, MakeActivityMenuTable(activityId, baseFilter, id, menuType))
        end
    end
    return data
end

local function isClickable(menuType)
    if menuType == ACTIVITY_FILTER_BROWSE then
        return true
    elseif menuType == ACTIVITY_FILTER_OTHER then
        return true
    end
end

local function MakeGroupMenuTable(categoryId, groupId, baseFilter, menuType)
    local data = {}
    data.text = C_LFGList.GetActivityGroupInfo(groupId)
    data.fullName = data.text
    data.categoryId = categoryId
    data.groupId = groupId
    data.baseFilter = baseFilter
    -- data.notClickable = categoryId == 1 or not isClickable(menuType)
    data.notClickable = true
    data.value = not data.notClickable and GetActivityCode(nil, nil, categoryId, groupId)
    data.tooltipTitle = L['请选择具体副本难度']
    data.tooltipOnButton = true

    if data.value then
        currentCodeCache[data.value] = data
    end

    local menuTable = {}
    local shownActivities = {}

    for _, activityId in ipairs(C_LFGList.GetAvailableActivities(categoryId, groupId)) do
        tinsert(menuTable, MakeCustomActivityMenuTable(activityId, baseFilter, nil, menuType))
        shownActivities[activityId] = true
    end

    local customData = ACTIVITY_CUSTOM_DATA.G[groupId]
    if customData then
        for _, id in ipairs(customData) do
            local activityId = ACTIVITY_CUSTOM_IDS[id]
            if activityId and shownActivities[activityId] then
                tinsert(menuTable, MakeActivityMenuTable(activityId, baseFilter, id, menuType))
            end
        end
    end

    if #menuTable > 0 then
        data.menuTable = menuTable
        data.hasArrow = true
    end
    return data
end

local function MakeVersionMenuTable(categoryId, versionId, baseFilter, menuType)
    local data = {}
    data.text = _G['EXPANSION_NAME' .. versionId]
    data.notClickable = true

    local menuTable = {}

    for _, groupId in ipairs(C_LFGList.GetAvailableActivityGroups(categoryId)) do
        -- print(versionId, groupId)
        if CATEGORY[versionId].groups[groupId] then
            tinsert(menuTable, MakeGroupMenuTable(categoryId, groupId, baseFilter, menuType))
        end
    end

    for _, activityId in ipairs(C_LFGList.GetAvailableActivities(categoryId)) do
        --2022-11-17
        local activityInfo = C_LFGList.GetActivityInfoTable(activityId);
        local groupId = activityInfo.groupFinderActivityGroupID;
        if CATEGORY[versionId].activities[activityId] and groupId == 0 then
            tinsert(menuTable, MakeCustomActivityMenuTable(activityId, baseFilter, nil, menuType))
        end
    end

    if #menuTable > 0 then
        data.menuTable = menuTable
        data.hasArrow = true
    else
        return
    end
    return data
end

local function MakeCategoryMenuTable(categoryId, baseFilter, menuType)
    --2022-11-17
    local categoryInfo = C_LFGList.GetLfgCategoryInfo(categoryId);
    local name = categoryInfo.name

    local data = {}
    data.text = name
    data.categoryId = categoryId
    data.baseFilter = baseFilter
    data.notClickable = not isClickable(menuType)
    data.value = not data.notClickable and GetActivityCode(nil, nil, categoryId)

    if data.value then
        currentCodeCache[data.value] = data
    end

    local menuTable = {}
    makedCategorys[categoryId] = true

    if categoryId == 2 or categoryId == 3 then
        -- for i = #MAX_PLAYER_LEVEL_TABLE, 0, -1 do
        for i = #CATEGORY, 0, -1 do
            local versionMenu = MakeVersionMenuTable(categoryId, i, baseFilter, menuType)
            if versionMenu then
                tinsert(menuTable, versionMenu)
            end
        end
    elseif autoChoose and categoryId ~= 6 then
        return MakeCustomActivityMenuTable(C_LFGList.GetAvailableActivities(categoryId)[1], baseFilter, nil, menuType)
    else
        local list = C_LFGList.GetAvailableActivityGroups(categoryId)
        local count = #list
        if count > 1 then
            local s, e, step = 1, count, 1
            if categoryId == 1 then
                s, e, step = e, s, -1
            end
            for i = s, e, step do
                tinsert(menuTable, MakeGroupMenuTable(categoryId, list[i], baseFilter, menuType))
            end
        end
        for _, activityId in ipairs(C_LFGList.GetAvailableActivities(categoryId)) do
            --2022-11-17
            local activityInfo = C_LFGList.GetActivityInfoTable(activityId);
            local groupId = activityInfo.groupFinderActivityGroupID;
            if groupId == 0 or count == 1 then
                tinsert(menuTable, MakeCustomActivityMenuTable(activityId, baseFilter, nil, menuType))
            end
        end
    end

    if #menuTable > 0 then
        data.menuTable = menuTable
        data.hasArrow = true
    end

    return data
end

local PACKED_CATEGORYS = { --
    ['PvP'] = { 4, 7, 8, 9, 10, key = 'packedPvp' },
}

local function FindPacked(categoryId)
    for key, v in pairs(PACKED_CATEGORYS) do
        if Profile:GetSetting(v.key) then
            for _, c in ipairs(v) do
                if c == categoryId then
                    return key
                end
            end
        end
    end
end

local function MakePackedCategoryMenuTable(key, baseFilter, menuType)
    local menuTable = { text = key, hasArrow = true, notClickable = true, menuTable = {} }

    for _, categoryId in ipairs(PACKED_CATEGORYS[key]) do
        if isCategoryValid(categoryId) then
            tinsert(menuTable.menuTable, MakeCategoryMenuTable(categoryId, baseFilter, menuType))
        end
    end

    return menuTable
end

local function MakeMenuTable(list, baseFilter, menuType)
    list = list or {}

    for _, categoryId in ipairs(C_LFGList.GetAvailableCategories(baseFilter)) do
        if not makedCategorys[categoryId] then
            local packed = FindPacked(categoryId)
            if packed then
                tinsert(list, MakePackedCategoryMenuTable(packed, baseFilter, menuType))
            elseif categoryId ~= 6 or baseFilter ~= Enum.LFGListFilter.PvE then
                tinsert(list, MakeCategoryMenuTable(categoryId, baseFilter, menuType))
            end
        end
    end

    return list
end

function GetActivitesMenuTable(menuType)
    currentCodeCache = wipe(activityCodeCaches[menuType])
    wipe(makedCategorys)
    initValidCategorys()

    local list = {}
    MakeMenuTable(list, Enum.LFGListFilter.PvE, menuType)
    MakeMenuTable(list, Enum.LFGListFilter.PvP, menuType)

    if menuType == ACTIVITY_FILTER_BROWSE or menuType == ACTIVITY_FILTER_CREATE then
        tinsert(list, 1, {
            text = menuType == ACTIVITY_FILTER_CREATE and L['|cff00ff00最近创建|r'] or L['|cff00ff00最近搜索|r'],
            notClickable = true,
            hasArrow = true,
            menuTable = RefreshHistoryMenuTable(menuType)
        })
        tinsert(list, 2, {
            text = L['|cffffff00当前版本地下城|r'],
            notClickable = true,
            hasArrow = true,
            menuTable = ListOfDungeons(menuType),
        })
    end

    

    -- if UnitLevel('player') >= 70 then
    --     if menuType == ACTIVITY_FILTER_CREATE then
    --         tinsert(list, {
    --             text         = L['单刷'],
    --             notClickable = true,
    --             hasArrow     = true,
    --             menuTable    = {
    --                 MakeActivityMenuTable(
    --                     ACTIVITY_CUSTOM_IDS[SOLO_HIDDEN_CUSTOM_ID],
    --                     Enum.LFGListFilter.PvP,
    --                     SOLO_HIDDEN_CUSTOM_ID,
    --                     ACTIVITY_CUSTOM_NAMES[SOLO_HIDDEN_CUSTOM_ID],
    --                     L['单刷开团，不会被其他玩家干扰。']
    --                 ),
    --                 MakeActivityMenuTable(
    --                     ACTIVITY_CUSTOM_IDS[SOLO_VISIBLE_CUSTOM_ID],
    --                     Enum.LFGListFilter.PvE,
    --                     SOLO_VISIBLE_CUSTOM_ID,
    --                     ACTIVITY_CUSTOM_NAMES[SOLO_VISIBLE_CUSTOM_ID],
    --                     L['这个活动可以被玩家搜索到。']
    --                 )
    --             }
    --         })
    --     elseif menuType == ACTIVITY_FILTER_BROWSE then
    --         tinsert(list, MakeActivityMenuTable(
    --             ACTIVITY_CUSTOM_IDS[SOLO_VISIBLE_CUSTOM_ID],
    --             Enum.LFGListFilter.PvP,
    --             SOLO_VISIBLE_CUSTOM_ID,
    --             ACTIVITY_CUSTOM_NAMES[SOLO_VISIBLE_CUSTOM_ID]
    --         ))
    --     end
    -- end
    return list
end

function RefreshHistoryMenuTable(menuType)
    local menuTable = wipe(historyMenuTables[menuType])
    local currentCodeCache = activityCodeCaches[menuType]
    local list = Profile:GetHistoryList(menuType == ACTIVITY_FILTER_CREATE)

    for _, value in ipairs(list) do
        local data = currentCodeCache[value]
        if data then
            local item = {
                categoryId = data.categoryId,
                groupId = data.groupId,
                activityId = data.activityId,
                customId = data.customId,
                filters = data.filters,
                baseFilter = data.baseFilter,
                value = data.value,
                text = data.text,
                fullName = data.fullName,
            }

            if menuType == ACTIVITY_FILTER_BROWSE then
                --2022-11-17
                local categoryInfo = C_LFGList.GetLfgCategoryInfo(data.categoryId);
                item.full = categoryInfo.name
            end

            tinsert(menuTable, item)
        end
    end

    if #menuTable == 0 then
        tinsert(menuTable, { text = L['暂无'], disabled = true })
    end

    return menuTable
end

function ListOfDungeons(menuType)
    local DungeonsList = {}
    do
        local function f()
            return {}
        end
        DungeonsList = f()
    end

    --9.27
    -- Dungeons = {280,281,256,257,127,128,7,10}
    -- Activitys = {1016,1017,679,683,471,473,180,183}

    -- 10.0
    -- Dungeons = {302,306,307,308,12,120,114,61}
    -- Activitys = {1160,1176,1180,1184,1193,466,461,1192}

    -- 10.1
    -- if C_MythicPlus.GetCurrentSeason() == 10 then
    --     Dungeons = {303,304,305,309,142,138,115,59}
    --     Activitys = {1164,1168,1172,1188,518,507,462,1195}
    -- end

    -- S2
    -- local Dungeons = { 303, 304, 305, 309, 142, 138, 115, 59 }
    -- local Activitys = { 1164, 1168, 1172, 1188, 518, 507, 462, 1195 }

    -- S3
    -- local Dungeons = { 11, 54, 113, 118, 137, 145, 316, 317 }
    -- local Activitys = { 184, 1274, 460, 463, 502, 530, 1247, 1248 }
    -- 永茂林地  184 / 11
    -- 潮汐王座  1274 / 54
    -- 黑心林地 460 / 113
    -- 黑鸦堡垒 463 / 118
    -- 阿塔达萨 502 / 137
    -- 维克雷丝庄园 530 / 145
    -- 永恒黎明1 1247 / 316
    -- 永恒黎明2 1248 / 317

    -- S4
    -- local Dungeons = { 302,303,304,305,306,307,308,309 }
    -- local Activitys = { 1160, 1164, 1168, 1172, 1176, 1180, 1184, 1188 }

    -- 11.0 S1
    local Dungeons = { 329,328 ,326, 323,56,262,265,146 }
    local Activitys = { 1288, 1287, 1285, 1284,1290,703,713,659 }
    -- 千丝之城  1288 / 329
    -- 矶石宝库  1287 / 328
    -- 破晨号  1285 / 326
    -- 回响之城  1284 / 323
    -- 格瑞姆巴托  1290 / 56
    -- 塞兹仙林  703 / 262
    -- 通灵战潮  713 / 265
    -- 围攻  659 / 146
    
    -- C_MythicPlus.IsMythicPlusActive()
    -- /run for i=284,300 do local info = C_LFGList.GetActivityInfoTable(i); if info then print(i, info.fullName) end end
    -- /dump C_LFGList.GetActivityGroupInfo(145)
    -- /dump C_LFGList.GetAvailableActivities(2,145)



    for k, groupId in ipairs(Dungeons) do
        local data = {}
        local actInfo = C_LFGList.GetActivityInfoTable(Activitys[k])

        data.text = actInfo.fullName     -- C_LFGList.GetActivityGroupInfo(groupId)
        data.fullName = actInfo.fullName -- data.text
        data.categoryId = 2
        data.groupId = groupId
        data.activityId = Activitys[k]
        data.baseFilter = 4
        data.customId = 0
        data.notClickable = true
        data.value = format('2-%d-%d-0', groupId, Activitys[k])
        if data then
            local item = {
                categoryId = data.categoryId,
                groupId = groupId,
                activityId = data.activityId,
                customId = data.customId,
                baseFilter = data.baseFilter,
                value = data.value,
                text = data.text, -- ..activitytypeText7,
                fullName = data.fullName,
            }

            if menuType == ACTIVITY_FILTER_BROWSE then
                --2022-11-17
                local categoryInfo = C_LFGList.GetLfgCategoryInfo(data.categoryId);
                item.full = categoryInfo.name
            end

            tinsert(DungeonsList, item)
        end
    end
    return DungeonsList
end
