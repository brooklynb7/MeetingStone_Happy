BuildEnv(...)

RaiderIOService = Addon:NewModule('RaiderIOService', 'AceEvent-3.0', 'AceBucket-3.0', 'AceTimer-3.0', 'AceHook-3.0')

function RaiderIOService:test()

end

function RaiderIOService:GetNameRealm(nameRealm)
    local name, realm
    if nameRealm:find("-", nil, true) then
        name, realm = ("-"):split(nameRealm)
    else
        name = nameRealm
    end
    if not realm or realm == "" then
        realm = ""
    end

    return name, realm
end

function RaiderIOService:GetBestRunOfDungeons(...)
    local bestDungeon ---@type Dungeon|nil
    local bestLevel = 0 ---@type number
    local bestChests = 0 ---@type number
    local args = { ... }
    for i = 1, #args, 3 do
        local dungeon = args[i] ---@type Dungeon|nil
        local level = args[i + 1] ---@type number
        local chests = args[i + 2] ---@type number
        if dungeon and dungeon.keystone_instance and (level > bestLevel or (level >= bestLevel and chests > bestChests)) then
            bestDungeon, bestLevel, bestChests = dungeon, level, chests
        end
    end
    return bestDungeon, bestLevel, bestChests
end

function RaiderIOService:appendRaiderIOData(player, currentScore, tooltip)
    tooltip:AddSepatator()
    tooltip:AddLine(format("Raider.IO信息"))
    local currentScoreColor = GetDungeonScoreRarityColor(currentScore)

    tooltip:AddLine(format("当前赛季分数: %s", currentScoreColor:WrapTextInColorCode(currentScore)))

    local name, realm = RaiderIOService:GetNameRealm(player)

    local result = RaiderIO.GetProfile(name, realm)
    if result and result.mythicKeystoneProfile then
        if result.mythicKeystoneProfile.blocked then
            return
        end

        local keystoneProfile = result.mythicKeystoneProfile

        local currentSeason = keystoneProfile.mplusCurrent
        local currentSeasonMain = keystoneProfile.mplusMainCurrent
        local previousSeason = keystoneProfile.mplusPrevious
        local previousSeasonMain = keystoneProfile.mplusMainPrevious


        local ioData = {}
        ioData.currentScore = currentSeason and currentSeason.score or 0
        ioData.currentMainScore = currentSeasonMain and currentSeasonMain.score or 0
        ioData.previousScore = previousSeason and previousSeason.score or 0
        ioData.previousMainScore = previousSeasonMain and previousSeasonMain.score or 0
        ioData.previousSeasonNum = previousSeason.season
        ioData.keystone20Plus = keystoneProfile.keystoneTwentyPlus
        ioData.keystone15Plus = keystoneProfile.keystoneFifteenPlus
        ioData.keystone10Plus = keystoneProfile.keystoneTenPlus
        ioData.keystone5Plus = keystoneProfile.keystoneFivePlus

        local overallBest = { dungeon = nil, level = 0, chests = 0 } ---@type BestRun
        overallBest.dungeon,
        overallBest.level,
        overallBest.chests = RaiderIOService:GetBestRunOfDungeons(
            keystoneProfile.fortifiedMaxDungeon,
            keystoneProfile.fortifiedMaxDungeonLevel,
            keystoneProfile.fortifiedDungeonUpgrades[keystoneProfile.fortifiedMaxDungeonIndex],
            keystoneProfile.tyrannicalMaxDungeon,
            keystoneProfile.tyrannicalMaxDungeonLevel,
            keystoneProfile.tyrannicalDungeonUpgrades[keystoneProfile.tyrannicalMaxDungeonIndex]
        )

        -- local actId = activity:GetActivityID()

        -- local best = { dungeon = nil, level = 0, chests = 0 } ---@type BestRun
        -- local focusDungeon = RaiderIOService:GetDungeonByLFDActivityID(actId)
        -- print(focusDungeon)
        -- best.dungeon,
        -- best.level,
        -- best.chests = RaiderIOService:GetBestRunOfDungeons(
        --     focusDungeon,
        --     keystoneProfile.fortifiedDungeons[focusDungeon.index],
        --     keystoneProfile.fortifiedDungeonUpgrades[focusDungeon.index],
        --     focusDungeon,
        --     keystoneProfile.tyrannicalDungeons[focusDungeon.index],
        --     keystoneProfile.tyrannicalDungeonUpgrades[focusDungeon.index]
        -- )
        -- print(best.dungeon.shortNameLocale)
        -- print(best.dungeon.shortName)

        if ioData.currentMainScore and ioData.currentMainScore > 0 then
            local currentMainScoreColor = GetDungeonScoreRarityColor(ioData.currentMainScore)
            tooltip:AddLine(format("当前赛季大号分数: %s",
                currentMainScoreColor:WrapTextInColorCode(ioData.currentMainScore)))
        end

        if ioData.previousSeasonNum then
            local previousScoreColor = GetDungeonScoreRarityColor(ioData.previousScore)

            tooltip:AddLine(format("上赛季分数(第 %s 赛季): %s", ioData.previousSeasonNum + 1,
                previousScoreColor:WrapTextInColorCode(ioData.previousScore)))

            if ioData.previousMainScore and ioData.previousMainScore > 0 then
                local previousMainScoreColor = GetDungeonScoreRarityColor(ioData.previousMainScore)

                tooltip:AddLine(format("上赛季大号分数(第 %s 赛季): %s", ioData.previousSeasonNum + 1,
                    previousMainScoreColor:WrapTextInColorCode(ioData.previousMainScore)))
            end
        end

        if overallBest.dungeon and overallBest.level and overallBest.chests then
            tooltip:AddLine(format("最高记录: |cffffffff%s层 %s %s|r", overallBest.level, overallBest.dungeon
                .shortNameLocale,
                overallBest.chests == 0 and '超时' or "+" .. overallBest.chests))
        end

        if ioData.keystone20Plus and ioData.keystone20Plus > 0 then
            tooltip:AddLine(format("20层以上限时次数: |cffffffff%s|r", ioData.keystone20Plus))
        end
        if ioData.keystone15Plus and ioData.keystone15Plus > 0 then
            tooltip:AddLine(format("15-19层限时次数: |cffffffff%s|r", ioData.keystone15Plus))
        end
        if ioData.keystone15Plus and ioData.keystone10Plus > 0 then
            tooltip:AddLine(format("10-14层限时次数: |cffffffff%s|r", ioData.keystone10Plus))
        end
        if ioData.keystone15Plus and ioData.keystone5Plus > 0 then
            tooltip:AddLine(format("5-9层限时次数: |cffffffff%s|r", ioData.keystone5Plus))
        end
    end
end
