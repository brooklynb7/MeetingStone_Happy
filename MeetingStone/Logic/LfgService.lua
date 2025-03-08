-- LfgService.lua
-- @Author : DengSir (tdaddon@163.com)
-- @Link   : https://dengsir.github.io/
-- @Date   : 2018-1-17 10:29:00

BuildEnv(...)

LfgService = Addon:NewModule('LfgService', 'AceEvent-3.0', 'AceBucket-3.0', 'AceTimer-3.0', 'AceHook-3.0')

function LfgService:OnInitialize()
    self.activityHash = {}
    self.activityList = {}
    self.activityRemoved = {}

    self:RegisterEvent('LFG_LIST_SEARCH_RESULTS_RECEIVED')
    self:RegisterEvent('LFG_LIST_SEARCH_FAILED', 'LFG_LIST_SEARCH_RESULTS_RECEIVED')
    self:RegisterEvent('LFG_LIST_APPLICATION_STATUS_UPDATED', 'LFG_LIST_SEARCH_RESULT_UPDATED')
    self:RegisterEvent('LFG_LIST_SEARCH_RESULT_UPDATED')

    -- self:RegisterBucketEvent('LFG_LIST_SEARCH_RESULT_UPDATED', 0.1, 'LFG_LIST_SEARCH_RESULT_UPDATED_BUCKET')

    self:SecureHook(C_LFGList, 'Search', 'C_LFGList_Search')
end

function LfgService:C_LFGList_Search()
    self.inSearch = true
    self.dirty = true
end

function LfgService:GetActivity(id)
    return self.activityHash[id]
end

function LfgService:GetActivityCount()
    return #self.activityList
end

function LfgService:GetActivityList()
    return self.activityList
end

function LfgService:RemoveActivity(id)
    self.activityRemoved[id] = true

    local activity = self:GetActivity(id)
    if not activity then
        return
    end
    tDeleteItem(self.activityList, activity)
    self.activityHash[id] = nil
end

function LfgService:IsActivityRemoved(id)
    return self.activityRemoved[id]
end

function LfgService:UpdateActivity(id)
    if self:IsActivityRemoved(id) then
        return
    end

    local activity = self:GetActivity(id)

    if not activity then
        self:CacheActivity(id)
        self:SendMessage('MEETINGSTONE_ACTIVITIES_COUNT_UPDATED', #self.activityList)
    else
        -- activity:Update()
        -- if activity:GetNumMembers() == 5 then
        if not activity:Update() then
            self:RemoveActivity(id)
        end
    end
end

function LfgService:IterateActivities()
    return pairs(self.activityList)
end

function LfgService:CacheActivity(id)
    if not self:_CacheActivity(id) then
        self:RemoveActivity(id)
    end
end

function LfgService:_CacheActivity(id)
    local activity = Activity:New(id)
    if not activity:Update() then
        return
    end

    if self.activityId and activity:GetActivityID() ~= self.activityId then
        return
    end

    if activity:HasInvalidContent() then
        return
    end
    if not activity:IsValidCustomActivity() then
        return
    end

    tinsert(self.activityList, activity)
    self.activityHash[id] = activity

    return true
end

function LfgService:LFG_LIST_SEARCH_RESULTS_RECEIVED(event)
    table.wipe(self.activityList)
    table.wipe(self.activityHash)
    table.wipe(self.activityRemoved)

    self.inSearch = false

    local applications = C_LFGList.GetApplications()

    self.activityApps = self.activityApps or {} --abyui 9.1.5 applications also in SearchResults
    table.wipe(self.activityApps)

    for _, id in ipairs(applications) do
        self.activityApps[id] = true
        self:CacheActivity(id)
    end

    local _, resultList = C_LFGList.GetSearchResults()
    for _, id in ipairs(resultList) do
        if not self.activityApps[id] then
            self:CacheActivity(id)
        end
    end

    self:SendMessage('MEETINGSTONE_ACTIVITIES_COUNT_UPDATED', self:GetActivityCount())
    self:SendMessage('MEETINGSTONE_ACTIVITIES_RESULT_RECEIVED', event == 'LFG_LIST_SEARCH_FAILED')
end

function LfgService:LFG_LIST_SEARCH_RESULT_UPDATED_BUCKET(results)
    for id in pairs(results) do
        self:UpdateActivity(id)
    end
    self:SendMessage('MEETINGSTONE_ACTIVITIES_RESULT_UPDATED')
end

local hardDeclinedGroups = {}
local softDeclinedGroups = {}
local DECLINED_GROUPS_RESET = 60 * 15
local function GetDeclinedGroupsKey(searchResultInfo)
    return searchResultInfo.activityID .. searchResultInfo.leaderName
end
local function IsDeclinedGroup(lookupTable, searchResultInfo)
    if searchResultInfo.leaderName then -- leaderName is not available for brand new groups
        local lastDeclined = lookupTable[GetDeclinedGroupsKey(searchResultInfo)] or 0
        if lastDeclined > time() - DECLINED_GROUPS_RESET then
            return true
        end
    end
    return false
end
function LfgService:IsHardDeclinedGroup(searchResultInfo)
    return IsDeclinedGroup(hardDeclinedGroups, searchResultInfo)
end
function LfgService:IsSoftDeclinedGroup(searchResultInfo)
    return IsDeclinedGroup(softDeclinedGroups, searchResultInfo)
end
local COLOR_ENTRY_DECLINED_SOFT = { R = 0.6, G = 0.3, B = 0.1 } -- dark orange
local COLOR_ENTRY_DECLINED_HARD = { R = 0.6, G = 0.1, B = 0.1 } -- dark red
function LfgService:GetDeclinedColor(searchResultInfo)
    if not searchResultInfo or not searchResultInfo.leaderName then return end
    if LfgService:IsHardDeclinedGroup(searchResultInfo) then return COLOR_ENTRY_DECLINED_HARD end
    if LfgService:IsSoftDeclinedGroup(searchResultInfo) then return COLOR_ENTRY_DECLINED_SOFT end
end
function LfgService:LFG_LIST_SEARCH_RESULT_UPDATED(_, id, newStatus, ...)
    -- possible newStatus: declined, declined_full, declined_delisted, timedout
    local searchResultInfo = C_LFGList.GetSearchResultInfo(id)
    if searchResultInfo.leaderName then -- leaderName is not available for brand new groups
        if newStatus == "declined" then
            hardDeclinedGroups[GetDeclinedGroupsKey(searchResultInfo)] = time()
        elseif newStatus == "declined_delisted" or newStatus == "timedout" then
            softDeclinedGroups[GetDeclinedGroupsKey(searchResultInfo)] = time()
        end
    end
    if self.inSearch then
        return
    end
    self:UpdateActivity(id)
    self:SendMessage('MEETINGSTONE_ACTIVITIES_RESULT_UPDATED')
end

function LfgService:Search(categoryId, baseFilter, activityId)
    self.ourSearch = true
    self.activityId = activityId
    local filterVal = 0
    if categoryId == 2 then
        filterVal = 1
    end

    -- if activityId then
    --     local activityInfo = C_LFGList.GetActivityInfoTable(activityId);
    --     print(activityInfo.fullName)
    --     print(activityInfo.shortName)
    --     print(activityInfo.groupFinderActivityGroupID)
    -- end

    local languages = C_LFGList.GetLanguageSearchFilter();
    C_LFGList.Search(categoryId, filterVal, baseFilterVal, languages)
    self.ourSearch = false
    self.dirty = false
end

function LfgService:IsDirty()
    return self.dirty
end

function LfgService:GetSearchResultMemberInfo(...)
    local info = C_LFGList.GetSearchResultPlayerInfo(...);
    if (info) then
        return info.assignedRole, info.classFilename, info.className, info.specName, info.isLeader;
    end
end