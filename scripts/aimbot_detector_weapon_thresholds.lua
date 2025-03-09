-- Weapon-specific thresholds for aimbot detection
-- This module implements different detection thresholds for different weapon types

-- Weapon-specific threshold configuration
local weaponThresholds = {
    -- Default thresholds
    default = {
        accuracy = 0.75,              -- Base accuracy threshold
        headshot = 0.65,              -- Base headshot ratio threshold
        angleChange = 160             -- Base angle change threshold
    },
    -- Sniper rifles (high accuracy expected)
    weapon_K43 = {
        accuracy = 0.85,
        headshot = 0.8,
        angleChange = 175
    },
    weapon_K43_scope = {
        accuracy = 0.9,
        headshot = 0.85,
        angleChange = 175
    },
    weapon_FG42Scope = {
        accuracy = 0.85,
        headshot = 0.8,
        angleChange = 175
    },
    -- Automatic weapons (medium accuracy expected)
    weapon_MP40 = {
        accuracy = 0.7,
        headshot = 0.6,
        angleChange = 160
    },
    weapon_Thompson = {
        accuracy = 0.7,
        headshot = 0.6,
        angleChange = 160
    },
    weapon_Sten = {
        accuracy = 0.7,
        headshot = 0.6,
        angleChange = 160
    },
    -- Pistols
    weapon_Luger = {
        accuracy = 0.8,
        headshot = 0.7,
        angleChange = 165
    },
    weapon_Colt = {
        accuracy = 0.8,
        headshot = 0.7,
        angleChange = 165
    },
    -- Machine guns
    weapon_MG42 = {
        accuracy = 0.65,
        headshot = 0.5,
        angleChange = 150
    },
    -- Grenades and explosives (very low accuracy expected)
    weapon_Grenade = {
        accuracy = 0.4,
        headshot = 0.1,
        angleChange = 140
    },
    weapon_Panzerfaust = {
        accuracy = 0.5,
        headshot = 0.2,
        angleChange = 145
    }
}

-- Get weapon-specific threshold
local function getWeaponThreshold(weapon, thresholdType)
    if not config.WEAPON_SPECIFIC_THRESHOLDS then
        -- Use global threshold if weapon-specific thresholds are disabled
        if thresholdType == "accuracy" then
            return config.ACCURACY_THRESHOLD
        elseif thresholdType == "headshot" then
            return config.HEADSHOT_RATIO_THRESHOLD
        else
            return config.ANGLE_CHANGE_THRESHOLD
        end
    end
    
    -- Use weapon-specific threshold if available
    if weaponThresholds[weapon] and weaponThresholds[weapon][thresholdType] then
        return weaponThresholds[weapon][thresholdType]
    end
    
    -- Fall back to default weapon threshold
    return weaponThresholds.default[thresholdType]
end

-- Get adjusted threshold based on player skill level
local function getAdjustedThreshold(player, baseThreshold, thresholdType)
    if not config.SKILL_ADAPTATION then return baseThreshold end
    
    local skillLevel = getPlayerSkillLevel(player)
    local adjustment = config.SKILL_ADJUSTMENTS[skillLevel][thresholdType] or 0
    
    return baseThreshold + adjustment
end

-- Initialize weapon stats for a player
local function initWeaponStats(player, weapon)
    if not player.weaponStats[weapon] then
        player.weaponStats[weapon] = {
            shots = 0,
            hits = 0,
            headshots = 0,
            kills = 0,
            accuracy = 0,
            headshotRatio = 0
        }
    end
end

-- Update weapon stats for a player
local function updateWeaponStats(player, weapon, isHit, isHeadshot, isKill)
    -- Initialize weapon stats if needed
    initWeaponStats(player, weapon)
    
    -- Update stats
    player.weaponStats[weapon].shots = player.weaponStats[weapon].shots + 1
    
    if isHit then
        player.weaponStats[weapon].hits = player.weaponStats[weapon].hits + 1
    end
    
    if isHeadshot then
        player.weaponStats[weapon].headshots = player.weaponStats[weapon].headshots + 1
    end
    
    if isKill then
        player.weaponStats[weapon].kills = player.weaponStats[weapon].kills + 1
    end
    
    -- Calculate ratios
    if player.weaponStats[weapon].shots > 0 then
        player.weaponStats[weapon].accuracy = player.weaponStats[weapon].hits / player.weaponStats[weapon].shots
    end
    
    if player.weaponStats[weapon].kills > 0 then
        player.weaponStats[weapon].headshotRatio = player.weaponStats[weapon].headshots / player.weaponStats[weapon].kills
    end
}

-- Check for suspicious accuracy with weapon-specific thresholds
local function detectWeaponSpecificAccuracy(clientNum)
    if not config.DETECT_ACCURACY or not config.WEAPON_SPECIFIC_THRESHOLDS then 
        return false, 0 
    end
    
    local player = players[clientNum]
    if not player then return false, 0 end
    
    -- Get current weapon
    local currentWeapon = player.lastWeapon or "default"
    
    -- Skip if we don't have enough data for this weapon
    if not player.weaponStats[currentWeapon] or 
       player.weaponStats[currentWeapon].shots < config.MIN_SAMPLES_REQUIRED then
        return false, 0
    end
    
    -- Get weapon-specific threshold
    local baseAccuracyThreshold = getWeaponThreshold(currentWeapon, "accuracy")
    
    -- Apply skill-based adjustment
    local accuracyThreshold = getAdjustedThreshold(player, baseAccuracyThreshold, "accuracy")
    
    -- Get weapon-specific accuracy
    local weaponAccuracy = player.weaponStats[currentWeapon].accuracy
    
    debugLog("detectWeaponSpecificAccuracy: " .. player.name .. " - weapon=" .. currentWeapon .. 
             ", accuracy=" .. weaponAccuracy .. ", threshold=" .. accuracyThreshold, 2)
    
    -- Check if accuracy exceeds threshold
    if weaponAccuracy > accuracyThreshold then
        local confidence = (weaponAccuracy - accuracyThreshold) / (1 - accuracyThreshold)
        return true, confidence, string.format("Suspicious %s accuracy (%.2f)", currentWeapon, weaponAccuracy)
    end
    
    return false, 0
}

-- Check for suspicious headshot ratio with weapon-specific thresholds
local function detectWeaponSpecificHeadshotRatio(clientNum)
    if not config.DETECT_HEADSHOT_RATIO or not config.WEAPON_SPECIFIC_THRESHOLDS then 
        return false, 0 
    end
    
    local player = players[clientNum]
    if not player then return false, 0 end
    
    -- Get current weapon
    local currentWeapon = player.lastWeapon or "default"
    
    -- Skip if we don't have enough data for this weapon
    if not player.weaponStats[currentWeapon] or 
       player.weaponStats[currentWeapon].kills < config.MIN_SAMPLES_REQUIRED / 2 then
        return false, 0
    end
    
    -- Get weapon-specific threshold
    local baseHeadshotThreshold = getWeaponThreshold(currentWeapon, "headshot")
    
    -- Apply skill-based adjustment
    local headshotThreshold = getAdjustedThreshold(player, baseHeadshotThreshold, "headshot")
    
    -- Get weapon-specific headshot ratio
    local weaponHeadshotRatio = player.weaponStats[currentWeapon].headshotRatio
    
    debugLog("detectWeaponSpecificHeadshotRatio: " .. player.name .. " - weapon=" .. currentWeapon .. 
             ", headshotRatio=" .. weaponHeadshotRatio .. ", threshold=" .. headshotThreshold, 2)
    
    -- Check if headshot ratio exceeds threshold
    if weaponHeadshotRatio > headshotThreshold then
        local confidence = (weaponHeadshotRatio - headshotThreshold) / (1 - headshotThreshold)
        return true, confidence, string.format("Suspicious %s headshot ratio (%.2f)", currentWeapon, weaponHeadshotRatio)
    end
    
    return false, 0
}

-- Integrate weapon-specific thresholds into the main detection system
local function enhanceDetectionWithWeaponThresholds(clientNum, totalConfidence, detectionCount, reasons)
    if not config.WEAPON_SPECIFIC_THRESHOLDS then
        return totalConfidence, detectionCount, reasons
    end
    
    -- Check for suspicious weapon-specific accuracy
    local suspicious, confidence, reason = detectWeaponSpecificAccuracy(clientNum)
    
    if suspicious then
        totalConfidence = totalConfidence + confidence
        detectionCount = detectionCount + 1
        table.insert(reasons, reason)
        
        debugLog("enhanceDetectionWithWeaponThresholds: Detected suspicious weapon-specific accuracy for client " .. 
                 clientNum .. " with confidence " .. confidence, 1)
    end
    
    -- Check for suspicious weapon-specific headshot ratio
    suspicious, confidence, reason = detectWeaponSpecificHeadshotRatio(clientNum)
    
    if suspicious then
        totalConfidence = totalConfidence + confidence
        detectionCount = detectionCount + 1
        table.insert(reasons, reason)
        
        debugLog("enhanceDetectionWithWeaponThresholds: Detected suspicious weapon-specific headshot ratio for client " .. 
                 clientNum .. " with confidence " .. confidence, 1)
    end
    
    return totalConfidence, detectionCount, reasons
}

-- Export functions and data
return {
    weaponThresholds = weaponThresholds,
    getWeaponThreshold = getWeaponThreshold,
    getAdjustedThreshold = getAdjustedThreshold,
    initWeaponStats = initWeaponStats,
    updateWeaponStats = updateWeaponStats,
    detectWeaponSpecificAccuracy = detectWeaponSpecificAccuracy,
    detectWeaponSpecificHeadshotRatio = detectWeaponSpecificHeadshotRatio,
    enhanceDetectionWithWeaponThresholds = enhanceDetectionWithWeaponThresholds
}
