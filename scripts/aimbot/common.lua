-- ETAimbotDetector - Common Functions Module
-- Common utility functions for the aimbot detection system

-- Check if player is an OMNIBOT
local function isOmniBot(guid)
    if not guid then return false end
    return string.find(string.lower(guid), "omnibot") ~= nil
end

-- Initialize player data
local function initPlayerData(clientNum)
    local userinfo = et.trap_GetUserinfo(clientNum)
    local name = et.Info_ValueForKey(userinfo, "name")
    local guid = et.Info_ValueForKey(userinfo, "cl_guid")
    local ip = et.Info_ValueForKey(userinfo, "ip")
    
    players[clientNum] = {
        name = name,
        guid = guid,
        ip = ip,
        
        -- Tracking variables
        lastAngle = {pitch = 0, yaw = 0},
        angleChanges = {},
        angleChangePatterns = {},
        shots = 0,
        hits = 0,
        headshots = 0,
        kills = 0,
        consecutiveHits = 0,
        
        -- Weapon-specific stats
        weaponStats = {},
        lastWeapon = "default",
        
        -- Time-based tracking
        lastDetectionTime = 0,
        lastShotTime = 0,
        reactionTimes = {},
        shotTimings = {},
        hitTimings = {},
        
        -- Target tracking
        lastTarget = -1,
        lastTargetTime = 0,
        targetSwitches = {},
        
        -- Statistical data
        avgAngleChange = 0,
        stdDevAngleChange = 0,
        
        -- Warning system
        warnings = 0,
        lastWarningTime = 0,
        
        -- Ban history
        tempBans = 0,
        
        -- Detection confidence
        aimbotConfidence = 0,
        humanizedAimbotConfidence = 0,
        
        -- Skill tracking
        xp = 0,
        rank = 0
    }
    
    debugLog("Player initialized: " .. name .. " (GUID: " .. guid .. ")")
end

-- Update player angles
local function updatePlayerAngles(clientNum)
    local player = players[clientNum]
    if not player then return end
    
    -- Get current view angles
    local ps = et.gentity_get(clientNum, "ps.viewangles")
    if not ps then return end
    
    local currentAngle = {
        pitch = ps[0],
        yaw = ps[1]
    }
    
    -- Calculate angle change
    local angleChange = {
        pitch = math.abs(currentAngle.pitch - player.lastAngle.pitch),
        yaw = math.abs(currentAngle.yaw - player.lastAngle.yaw)
    }
    
    -- Normalize yaw angle change (handle 359° -> 0° transitions)
    if angleChange.yaw > 180 then
        angleChange.yaw = 360 - angleChange.yaw
    end
    
    -- Calculate total angle change
    local totalAngleChange = math.sqrt(angleChange.pitch^2 + angleChange.yaw^2)
    
    -- Store angle change if it's within reasonable limits
    if totalAngleChange <= config.MAX_ANGLE_CHANGE then
        table.insert(player.angleChanges, totalAngleChange)
        
        -- Keep only the last 50 angle changes
        if #player.angleChanges > 50 then
            table.remove(player.angleChanges, 1)
        end
    end
    
    -- Update last angle
    player.lastAngle = currentAngle
end

-- Export functions
return {
    isOmniBot = isOmniBot,
    initPlayerData = initPlayerData,
    updatePlayerAngles = updatePlayerAngles
}
