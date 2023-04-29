local wtChat
local valuedText = common.CreateValuedText()
local wtTimerText
local willBeDestroyedAt
local currentMechanismObjectId
local wtMapMarkers, wtMinimapSquareMarkers, wtMinimapCircleMarkers, avatarCordsAtPortalSetting, wtPortalMarker


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
    avatarCordsAtPortalSetting = object.GetPos(avatar.GetId())

    onCanvasChanged()

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
    avatarCordsAtPortalSetting = nil
    currentMechanismObjectId = nil
    willBeDestroyedAt = nil
    wtTimerText:SetVal('value', '')

    common.UnRegisterEventHandler(OnSecondTimer, 'EVENT_SECOND_TIMER')
    common.UnRegisterEventHandler(OnSpellbookElementEffect, "EVENT_SPELLBOOK_ELEMENT_EFFECT")
    common.UnRegisterEventHandler(OnUnitDead, "EVENT_AVATAR_ALIVE_CHANGED")
    common.UnRegisterEventHandler(OnZoneChanged, "EVENT_AVATAR_MAP_CHANGED")
end

local function getMapMarkers()
    if not wtMapMarkers or not wtMapMarkers:IsValid() then
        local wtMap = stateMainForm:GetChildUnchecked('Map', false)
        wtMapMarkers = wtMap and wtMap:GetChildUnchecked('Markers', true)
        if wtMapMarkers then wtMapMarkers:SetOnShowNotification(true) end
    end
    return wtMapMarkers
end

local function getMinimapSquareMarkers()
    if not wtMinimapSquareMarkers or not wtMinimapSquareMarkers:IsValid() then
        local wtMinimap = stateMainForm:GetChildUnchecked('Minimap', false)
        local wtSquare = wtMinimap and wtMinimap:GetChildUnchecked('Square', false)
        wtMinimapSquareMarkers = wtSquare and wtSquare:GetChildUnchecked('Markers', true)
        if wtMinimapSquareMarkers then wtMinimapSquareMarkers:SetOnShowNotification(true) end
    end
    return wtMinimapSquareMarkers
end

local function getMinimapCircleMarkers()
    if not wtMinimapCircleMarkers or not wtMinimapCircleMarkers:IsValid() then
        local wtMinimap = stateMainForm:GetChildUnchecked('Minimap', false)
        local wtCircle = wtMinimap and wtMinimap:GetChildUnchecked('Circle', false)
        wtMinimapCircleMarkers = wtCircle and wtCircle:GetChildUnchecked('Markers', true)
        if wtMinimapCircleMarkers then wtMinimapCircleMarkers:SetOnShowNotification(true) end
    end
    return wtMinimapCircleMarkers
end

local function getCanvas()
    wtMapMarkers = getMapMarkers()
    wtMinimapSquareMarkers = getMinimapSquareMarkers()
    wtMinimapCircleMarkers = getMinimapCircleMarkers()
    if wtMapMarkers and wtMapMarkers:IsVisibleEx() then
        return wtMapMarkers
    elseif wtMinimapSquareMarkers and wtMinimapSquareMarkers:IsVisibleEx() then
        return wtMinimapSquareMarkers
    elseif wtMinimapCircleMarkers and wtMinimapCircleMarkers:IsVisibleEx() then
        return wtMinimapCircleMarkers
    end
end

local function onWidgetShowChanged(p)
    if not p.widget:IsValid() then return end
    if wtMapMarkers and wtMapMarkers:IsEqual(p.widget) or wtMinimapSquareMarkers and wtMinimapSquareMarkers:IsEqual(p.widget) or wtMinimapCircleMarkers and wtMinimapCircleMarkers:IsEqual(p.widget) then
        onCanvasChanged()
    end
end

local function onAddonLoadStateChanged(p)
    if p.name ~= 'Map' and p.name ~= 'Minimap' then return end
    onCanvasChanged()
end


function onCanvasChanged()
    local wtMarkers = getCanvas()
    if not wtMarkers then return end

    local zoneInfo = cartographer.GetCurrentZoneInfo()
    local geodata = cartographer.GetObjectGeodata(avatar.GetId(), zoneInfo.zonesMapId)

    local screenParams = widgetsSystem:GetPosConverterParams()
    local canvasRect = wtMarkers:GetRealRect()

    local MAP_TEXTURE_X = (canvasRect.x2 - canvasRect.x1) * (screenParams.fullVirtualSizeX / screenParams.realSizeX)
    local MAP_TEXTURE_Y = (canvasRect.y2 - canvasRect.y1) * (screenParams.fullVirtualSizeY / screenParams.realSizeY)

    local pixelsPerMeterX = (MAP_TEXTURE_X / geodata.width)
    local pixelsPerMeterY = (MAP_TEXTURE_Y / geodata.height)

    local mapCenterX = geodata.x + (geodata.width / 2)
    local mapCenterY = geodata.y + (geodata.height / 2)

    if wtPortalMarker ~= nil and avatarCordsAtPortalSetting ~= nil then
        LogToChat('Отрисовываем!')
        wtMarkers:AddChild(wtPortalMarker)
        wtPortalMarker:SetSmartPlacementPlain {
            posX = math.ceil((avatarCordsAtPortalSetting.posX - mapCenterX) * pixelsPerMeterX), -- вообще можно и не округлять, но я воровал код из доков и там так
            posY = math.ceil((mapCenterY - avatarCordsAtPortalSetting.posY) * pixelsPerMeterY)
        }
    end
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

    wtPortalMarker = mainForm:GetChildUnchecked("Marker", false)
    wtPortalMarker:SetSmartPlacementPlain{ sizeX = 200, sizeY = 200 }

    wtTimerText = mainForm:GetChildUnchecked("TimerText", false)
    local str = '<body color="0xFFFFFFFF" fontsize="' .. config['FONT_SIZE'] .. '" alignx="right" aligny="bottom" outline="1"><rs class="class"><r name="value"/></rs></body>'
    wtTimerText:SetFormat(userMods.ToWString(str))
    DnD.Init(wtTimerText, nil, true)

    common.RegisterEventHandler(onWidgetShowChanged, 'EVENT_WIDGET_SHOW_CHANGED')
    common.RegisterEventHandler(onAddonLoadStateChanged, 'EVENT_ADDON_LOAD_STATE_CHANGED')
    common.RegisterEventHandler(OnEventUnitFollowersListChanged, "EVENT_UNIT_FOLLOWERS_LIST_CHANGED")

    onCanvasChanged()
end

function Init()
    if avatar and avatar.IsExist() then
        OnEventAvatarCreated()
    else
        common.RegisterEventHandler(OnEventAvatarCreated, "EVENT_AVATAR_CREATED")
    end
end

Init()
