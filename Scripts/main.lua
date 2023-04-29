local wtChat
local valuedText = common.CreateValuedText()
local wtTimerText
local willBeDestroyedAt
local currentMechanismObjectId


function LogToChat(text)
    if not wtChat then
        wtChat = stateMainForm:GetChildUnchecked("ChatLog", false):GetChildUnchecked("Container", true)
        local formatVT = "<html fontname='AllodsFantasy' fontsize='14' shadow='1'><rs class='color'><r name='addonName'/><r name='text'/></rs></html>"
        valuedText:SetFormat(userMods.ToWString(formatVT))
    end

    if wtChat and wtChat.PushFrontValuedText then
        if not common.IsWString(text) then
            text = userMods.ToWString(text)
        end

        valuedText:ClearValues()
        valuedText:SetClassVal("color", "LogColorYellow")
        valuedText:SetVal("text", text)
        valuedText:SetVal("addonName", userMods.ToWString("PT: "))
        wtChat:PushFrontValuedText(valuedText)
    end
end

function GetReadableTimerValue(timerInMs)
    if timerInMs < 60000 then
        return string.format("%ds", math.floor(timerInMs / 1000))
    end

    local total_seconds = math.floor(timerInMs / 1000)
    local minutes = math.floor(total_seconds / 60)
    local seconds = total_seconds % 60

    return string.format("%dm %ds", minutes, seconds)
end

function UpdateTimers()
    if willBeDestroyedAt == nil then
        return
    end

    local currentMs = common.GetMsFromDateTime(common.GetLocalDateTime())
    if currentMs > willBeDestroyedAt then
        DestroyMechanism()
        return
    end

    wtTimerText:SetVal('value', GetReadableTimerValue(willBeDestroyedAt - currentMs))
end

function SetMechanismInfo(followerId)
    local remainingMs = GetMechanismRemainingTime(followerId)
    if remainingMs == nil then
        DestroyMechanism()
        return
    end

    currentMechanismObjectId = followerId
    willBeDestroyedAt = remainingMs + common.GetMsFromDateTime(common.GetLocalDateTime());

    common.RegisterEventHandler(OnSecondTimer, 'EVENT_SECOND_TIMER')
    common.RegisterEventHandler(OnSpellbookElementEffect, 'EVENT_SPELLBOOK_ELEMENT_EFFECT')
    common.RegisterEventHandler(OnUnitDead, "EVENT_AVATAR_ALIVE_CHANGED")
    common.RegisterEventHandler(OnZoneChanged, "EVENT_AVATAR_MAP_CHANGED")
end

function OnZoneChanged()
    DestroyMechanism()
end

function OnUnitDead(params)
    if params.alive == false then
        DestroyMechanism()
    end
end

function GetMechanismRemainingTime(followerId)
    local activeBuffs = object.GetBuffs(followerId)
    if activeBuffs == nil then
        return
    end

    local buffInfo = object.GetBuffInfo(activeBuffs[2])
    if buffInfo ~= nil and buffInfo.durationMs == config['TTL'] then
        return buffInfo.remainingMs
    end

    for _, buffId in pairs(activeBuffs) do
        buffInfo = object.GetBuffInfo(buffId)
        if buffInfo ~= nil and buffInfo.durationMs == config['TTL'] then
            return buffInfo.remainingMs
        end
    end

    return nil
end

function DestroyMechanism()
    currentMechanismObjectId = nil
    willBeDestroyedAt = nil
    wtTimerText:SetVal('value', '')

    common.UnRegisterEventHandler(OnSecondTimer, 'EVENT_SECOND_TIMER')
    common.UnRegisterEventHandler(OnSpellbookElementEffect, "EVENT_SPELLBOOK_ELEMENT_EFFECT")
    common.UnRegisterEventHandler(OnUnitDead, "EVENT_AVATAR_ALIVE_CHANGED")
    common.UnRegisterEventHandler(OnZoneChanged, "EVENT_AVATAR_MAP_CHANGED")
end


function OnSecondTimer()
    UpdateTimers()
end

function OnEventUnitFollowersListChanged(params)
    if avatar.GetId() ~= params['id'] then
        return
    end

    local followers = unit.GetFollowers(params['id'])
    for _, followerId in pairs(followers) do
        if userMods.FromWString(object.GetName(followerId)) == config['MECHANISM_NAME'] then
            wtTimerText:SetTextColor(nil, config['DEFAULT_COLOR'])
            SetMechanismInfo(followerId)
            return
        end
    end

    if currentMechanismObjectId ~= nil then
        currentMechanismObjectId = nil
        wtTimerText:SetTextColor(nil, config['ALT_COLOR'])
    end
end

function OnSpellbookElementEffect(params)
    if params.effect ~= EFFECT_TYPE_COOLDOWN_STARTED then
        return
    end

    local spellName = spellLib.GetDescription(params.id).name
    if userMods.FromWString(spellName) == 'Отключение механизмов' then
        DestroyMechanism()
    end
end

function OnEventAvatarCreated()
    if avatar.GetClass() ~= 'ENGINEER' then
        return
    end

    wtTimerText = mainForm:GetChildUnchecked("TimerText", false)
    local str = '<body color="0xFFFFFFFF" fontsize="' .. config['FONT_SIZE'] .. '" alignx="right" aligny="bottom" outline="1"><rs class="class"><r name="value"/></rs></body>'
    wtTimerText:SetFormat(userMods.ToWString(str))

    DnD.Init(wtTimerText, nil, true)

    common.RegisterEventHandler(OnEventUnitFollowersListChanged, "EVENT_UNIT_FOLLOWERS_LIST_CHANGED")
end

function Init()
    if avatar and avatar.IsExist() then
        OnEventAvatarCreated()
    else
        common.RegisterEventHandler(OnEventAvatarCreated, "EVENT_AVATAR_CREATED")
    end
end

Init()
