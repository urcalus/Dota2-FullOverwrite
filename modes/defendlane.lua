-------------------------------------------------------------------------------
--- AUTHOR: Keithen
--- GITHUB REPO: https://github.com/Nostrademous/Dota2-FullOverwrite
-------------------------------------------------------------------------------

BotsInit = require( "game/botsinit" )
local X = BotsInit.CreateGeneric()

local gHeroVar = require( GetScriptDirectory().."/global_hero_data" )
local utils = require( GetScriptDirectory().."/utility" )
require( GetScriptDirectory().."/item_usage" )

local function setHeroVar(var, value)
    gHeroVar.SetVar(GetBot():GetPlayerID(), var, value)
end

local function getHeroVar(var)
    return gHeroVar.GetVar(GetBot():GetPlayerID(), var)
end

function X:GetName()
    return "defendlane"
end

function X:OnStart(myBot)
end

function X:OnEnd()
end

function X:Desire(bot)
    local defInfo = getHeroVar("DoDefendLane")
    local building = defInfo[2]
    local hBuilding = buildings_status.GetHandle(GetTeam(), building)
    
    if #defInfo > 0 then    
        if hBuilding == nil then
            -- if building falls, don't stick around and defend area
            return BOT_MODE_DESIRE_NONE
        else
            return BOT_MODE_DESIRE_VERYHIGH
        end
    end
    
    -- if we are defending the lane, stay until all enemy
    -- creep is pushed back and enemies are not nearby
    local me = getHeroVar("Self")
    if me:getCurrentMode():GetName() == "defendlane" and
        (#gHeroVar.GetNearbyEnemyCreep(bot, 1500) > 0 or
        #gHeroVar.GetnearbyEnemies(bot, 1500)) and
        hBuilding ~= nil and GetUnitToUnitDistance(bot, hBuilding) < 900 then
        return me:getCurrentModeValue()
    end
    
    return BOT_MODE_DESIRE_NONE
end

function X:DefendTower(bot, hBuilding)
    -- TODO: all of this should use the fighting system.
    local enemies = gHeroVar.GetNearbyEnemies(bot, 1500)
    local allies = gHeroVar.GetNearbyAllies(bot, 1500)
    local eCreep = gHeroVar.GetNearbyEnemyCreep(bot, 1200)
    
    if #enemies > 0 and #allies >= #enemies then -- we are good to go
        gHeroVar.HeroAttackUnit(bot, enemies[1], true) -- Charge! at the closes enemy
    else -- stay back
        if #enemies > 0 then
            local dist = GetUnitToUnitDistance(bot, enemies[1])
            if dist < 900 then -- they are too close
                gHeroVar.HeroMoveToLocation(bot, utils.VectorAway(bot:GetLocation(), enemies[1]:GetLocation(), 950-dist))
            end -- else do nothing. abilityUse should handle this
        elseif #eCreep > 0 then
            local weakestCreep, _ = utils.GetWeakestCreep(eCreep)
            if weakestCreep then
                gHeroVar.HeroAttackUnit(bot, weakestCreep, true)
            end
        end
    end
end

function X:Think(bot)
    if utils.IsBusy(bot) then return end
    
    if utils.IsCrowdControlled(bot) then return end

    local defInfo = getHeroVar("DoDefendLane") -- TEAM has made the decision.
    -- TODO: unpack function??
    local lane = defInfo[1]
    local building = defInfo[2]
    local numEnemies = defInfo[3]

    local hBuilding = buildings_status.GetHandle(GetTeam(), building)

    if hBuilding == nil then
        setHeroVar("DoDefendLane", {})
        return
    end

    local distFromBuilding = GetUnitToUnitDistance(bot, hBuilding)
    local timeToReachBuilding = distFromBuilding/bot:GetCurrentMovementSpeed()

    if timeToReachBuilding <= 5.0 then
        X:DefendTower(bot, hBuilding)
    else
        if bot:IsChanneling() or bot:IsCastingAbility() then return true end
        local tp = utils.GetTeleportationAbility(bot)
        if tp == nil then
            X:DefendTower(bot, hBuilding)
        else
            -- calculate position for a defensive teleport
            -- TODO: consider hiding in trees, position of enemy
            -- TODO: is there, should there be a utils function for this?
            local pos = hBuilding:GetLocation()
            local vec = utils.Fountain(GetTeam()) - pos
            vec = vec * 575 / #vec -- resize to 575 units (max tp range from tower)
            pos = pos + vec
            bot:Action_UseAbilityOnLocation(tp, pos)
        end
    end

    return
end

return X