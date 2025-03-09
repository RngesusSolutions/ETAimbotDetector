-- Skill level adaptation for aimbot detection
-- This module adjusts detection thresholds based on player experience level

-- Skill level thresholds
local SKILL_LEVELS = {
    NOVICE = 0,       -- 0-999 XP
    REGULAR = 1000,   -- 1000-4999 XP
    SKILLED = 5000,   -- 5000-9999 XP
    EXPERT = 10000    -- 10000+ XP
}

-- Threshold adjustments based on skill level
local SKILL_ADJUSTMENTS = {
    NOVICE = { accuracy = 0.0, headshot = 0.0 },
    REGULAR = { accuracy = 0.05, headshot = 0.05 },
    SKILLED = { accuracy = 0.1, headshot = 0.1 },
    EXPERT = { accuracy = 0.15, headshot = 0.15 }
}

-- Get player skill level based on XP
local function getPlayerSkillLevel(player)
    if not config.SKILL_ADAPTATION then return "REGULAR" end
    
    local xp = player.xp or 0
    
    if xp >= SKILL_LEVELS.EXPERT then
        return "EXPERT"
    elseif xp >= SKILL_LEVELS.SKILLED then
        return "SKILLED"
    elseif xp >= SKILL_LEVELS.REGULAR then
        return "REGULAR"
    else
        return "NOVICE"
    end
end

-- Get adjusted threshold based on player skill level
local function getAdjustedThreshold(player, baseThreshold, thresholdType)
    if not config.SKILL_ADAPTATION then return baseThreshold end
    
    local skillLevel = getPlayerSkillLevel(player)
    local adjustment = SKILL_ADJUSTMENTS[skillLevel][thresholdType] or 0
    
    debugLog("getAdjustedThreshold: " .. player.name .. " - skillLevel=" .. skillLevel .. 
             ", baseThreshold=" .. baseThreshold .. ", adjustment=" .. adjustment .. 
             ", finalThreshold=" .. (baseThreshold + adjustment), 3)
    
    return baseThreshold + adjustment
end

-- Update player XP (called when XP changes)
local function updatePlayerXP(clientNum, xp)
    local player = players[clientNum]
    if not player then return end
    
    local oldXP = player.xp or 0
    player.xp = xp
    
    -- Log skill level change
    local oldSkillLevel = player.skillLevel or "UNKNOWN"
    local newSkillLevel = getPlayerSkillLevel(player)
    
    if oldSkillLevel ~= newSkillLevel then
        debugLog("updatePlayerXP: " .. player.name .. " skill level changed from " .. oldSkillLevel .. " to " .. newSkillLevel, 2)
        player.skillLevel = newSkillLevel
        
        -- Recalculate detection thresholds
        if config.SKILL_ADAPTATION then
            debugLog("updatePlayerXP: Recalculating detection thresholds for " .. player.name .. " due to skill level change", 2)
        end
    end
    
    -- Log XP change
    if xp > oldXP then
        debugLog("updatePlayerXP: " .. player.name .. " gained " .. (xp - oldXP) .. " XP (total: " .. xp .. ")", 3)
    end
}

-- ET:Legacy callback: XP Stats
function et_ClientXPStat(clientNum, stats)
    if not config.SKILL_ADAPTATION then return end
    
    -- Calculate total XP
    local totalXP = 0
    for i = 0, #stats do
        totalXP = totalXP + stats[i]
    end
    
    -- Update player XP
    updatePlayerXP(clientNum, totalXP)
}

-- Integrate skill level adaptation into the main detection system
local function enhanceDetectionWithSkillAdaptation(clientNum, suspiciousActivity, confidence)
    if not config.SKILL_ADAPTATION then
        return suspiciousActivity, confidence
    end
    
    local player = players[clientNum]
    if not player then
        return suspiciousActivity, confidence
    end
    
    local skillLevel = getPlayerSkillLevel(player)
    
    -- Adjust confidence based on skill level
    -- For higher skill players, we require higher confidence to trigger warnings
    if suspiciousActivity then
        local skillAdjustment = 0
        
        if skillLevel == "EXPERT" then
            skillAdjustment = 0.1
        elseif skillLevel == "SKILLED" then
            skillAdjustment = 0.05
        elseif skillLevel == "REGULAR" then
            skillAdjustment = 0.02
        end
        
        -- Reduce confidence for higher skill players
        confidence = confidence - skillAdjustment
        
        -- If confidence drops below threshold after adjustment, don't consider it suspicious
        if confidence < config.CONFIDENCE_THRESHOLD then
            suspiciousActivity = false
            debugLog("enhanceDetectionWithSkillAdaptation: Suspicious activity ignored for " .. player.name .. 
                     " due to skill level " .. skillLevel .. " (adjusted confidence: " .. confidence .. ")", 2)
        else
            debugLog("enhanceDetectionWithSkillAdaptation: Suspicious activity confirmed for " .. player.name .. 
                     " despite skill level " .. skillLevel .. " (adjusted confidence: " .. confidence .. ")", 2)
        end
    }
    
    return suspiciousActivity, confidence
}

-- Export functions and data
return {
    SKILL_LEVELS = SKILL_LEVELS,
    SKILL_ADJUSTMENTS = SKILL_ADJUSTMENTS,
    getPlayerSkillLevel = getPlayerSkillLevel,
    getAdjustedThreshold = getAdjustedThreshold,
    updatePlayerXP = updatePlayerXP,
    enhanceDetectionWithSkillAdaptation = enhanceDetectionWithSkillAdaptation
}
