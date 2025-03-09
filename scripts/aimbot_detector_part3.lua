-- Check for suspicious angle changes with pattern detection
local function detectAngleChanges(clientNum)
    if not config.DETECT_ANGLE_CHANGES then 
        debugLog("detectAngleChanges: Detection disabled in config", 3)
        return false, 0 
    end
    
    local player = players[clientNum]
    if not player then
        debugLog("detectAngleChanges: Player not found for clientNum " .. clientNum, 3)
        return false, 0
    end
    
    if #player.angleChanges < config.MIN_SAMPLES_REQUIRED then
        debugLog("detectAngleChanges: Insufficient angle samples for " .. player.name .. " (" .. #player.angleChanges .. "/" .. config.MIN_SAMPLES_REQUIRED .. ")", 3)
        return false, 0
    end
    
    -- Calculate average and standard deviation of recent angle changes
    local sum = 0
    for i, change in ipairs(player.angleChanges) do
        sum = sum + change
        debugLog("detectAngleChanges: Sample " .. i .. " = " .. change .. "°", 3)
    end
    local avg = sum / #player.angleChanges
    local stdDev = calculateStdDev(player.angleChanges, avg)
    
    -- Store statistical data
    player.avgAngleChange = avg
    player.stdDevAngleChange = stdDev
    
    debugLog("detectAngleChanges: " .. player.name .. " - avg=" .. avg .. "°, stdDev=" .. stdDev .. "°, threshold=" .. config.ANGLE_CHANGE_THRESHOLD .. "°", 2)
    
    -- Pattern detection for aimbots
    local patternConfidence = 0
    
    -- Check for "snapping" behavior (high angles followed by very low angles)
    local snapCount = 0
    local legitimateFlickCount = 0
    
    for i = 2, #player.angleChanges do
        -- Aimbot snap: high angle change with no adjustment
        if player.angleChanges[i] > 100 and player.angleChanges[i-1] < 5 then
            snapCount = snapCount + 1
            debugLog("detectAngleChanges: Snap detected at sample " .. i .. " (" .. player.angleChanges[i] .. "° after " .. player.angleChanges[i-1] .. "°)", 3)
        end
        
        -- Legitimate flick: high angle change followed by small adjustments
        if player.angleChanges[i] > 100 and i < #player.angleChanges and 
           player.angleChanges[i+1] >= 5 and player.angleChanges[i+1] <= 30 then
            legitimateFlickCount = legitimateFlickCount + 1
            debugLog("detectAngleChanges: Legitimate flick pattern detected at sample " .. i, 3)
        end
    end
    
    -- Reduce confidence if we detect legitimate flick patterns
    if legitimateFlickCount > 0 then
        patternConfidence = patternConfidence - (legitimateFlickCount * 0.1)
        debugLog("detectAngleChanges: Detected " .. legitimateFlickCount .. " legitimate flick patterns, reducing confidence", 2)
    end
    
    if snapCount > 3 then
        patternConfidence = patternConfidence + 0.3
        debugLog("detectAngleChanges: Multiple snaps detected (" .. snapCount .. "), adding 0.3 confidence", 2)
    end
    
    -- Check for micro-movements (humanized aimbot detection)
    local microMovementCount = 0
    local microMovementSequence = 0
    local maxMicroMovementSequence = 0
    
    for i = 2, #player.angleChanges do
        -- Micro-movements are small, precise adjustments between 5-20 degrees
        if player.angleChanges[i] >= 5 and player.angleChanges[i] <= 20 then
            microMovementCount = microMovementCount + 1
            microMovementSequence = microMovementSequence + 1
            
            if microMovementSequence > maxMicroMovementSequence then
                maxMicroMovementSequence = microMovementSequence
            end
        else
            microMovementSequence = 0
        end
    end
    
    -- Detect humanized aimbot patterns based on micro-movements
    if microMovementCount >= 5 and maxMicroMovementSequence >= 3 and stdDev < 15 then
        patternConfidence = patternConfidence + 0.45
        return true, patternConfidence, string.format("Suspicious micro-movement pattern detected (count: %d, sequence: %d, stdDev: %.2f°)", 
            microMovementCount, maxMicroMovementSequence, stdDev)
    end
    
    -- Check for consistent high angles (normal aimbot)
    if avg > config.ANGLE_CHANGE_THRESHOLD then
        patternConfidence = patternConfidence + 0.5
        debugLog("detectAngleChanges: High average angle change detected, adding 0.5 confidence", 2)
        return true, patternConfidence, string.format("Suspicious angle changes (avg: %.2f°, stdDev: %.2f°)", avg, stdDev)
    end
    
    -- Check for humanized aimbot patterns (more subtle)
    if config.PATTERN_DETECTION and stdDev < 10 and avg > 100 then
        patternConfidence = patternConfidence + 0.4
        debugLog("detectAngleChanges: Humanized aimbot pattern detected (low stdDev with high avg), adding 0.4 confidence", 2)
        return true, patternConfidence, string.format("Suspicious angle pattern detected (avg: %.2f°, stdDev: %.2f°)", avg, stdDev)
    end
    
    debugLog("detectAngleChanges: No suspicious patterns detected for " .. player.name, 2)
    return false, patternConfidence
end

-- Check for suspicious headshot ratio
local function detectHeadshotRatio(clientNum)
    if not config.DETECT_HEADSHOT_RATIO then 
        debugLog("detectHeadshotRatio: Detection disabled in config", 3)
        return false, 0 
    end
    
    local player = players[clientNum]
    if not player then
        debugLog("detectHeadshotRatio: Player not found for clientNum " .. clientNum, 3)
        return false, 0
    end
    
    if player.kills < config.MIN_SAMPLES_REQUIRED / 2 then
        debugLog("detectHeadshotRatio: Insufficient kill samples for " .. player.name .. " (" .. player.kills .. "/" .. (config.MIN_SAMPLES_REQUIRED / 2) .. ")", 3)
        return false, 0
    end
    
    -- Get current weapon
    local currentWeapon = player.lastWeapon or "default"
    local baseHeadshotThreshold = getWeaponThreshold(currentWeapon, "headshot")
    
    -- Apply skill-based adjustment
    local headshotThreshold = getAdjustedThreshold(player, baseHeadshotThreshold, "headshot")
    
    -- Calculate headshot ratio
    local ratio = player.headshots / player.kills
    
    debugLog("detectHeadshotRatio: " .. player.name .. " - weapon=" .. currentWeapon .. 
             ", headshots=" .. player.headshots .. ", kills=" .. player.kills .. 
             ", ratio=" .. ratio .. ", base threshold=" .. baseHeadshotThreshold .. 
             ", adjusted threshold=" .. headshotThreshold, 2)
    
    -- Confidence calculation
    local confidenceScore = 0
    
    if ratio > headshotThreshold then
        confidenceScore = (ratio - headshotThreshold) / (1 - headshotThreshold)
        debugLog("detectHeadshotRatio: Suspicious headshot ratio detected, confidence=" .. confidenceScore, 2)
        return true, confidenceScore, string.format("Suspicious headshot ratio (%.2f)", ratio)
    end
    
    debugLog("detectHeadshotRatio: No suspicious headshot ratio detected for " .. player.name, 3)
    return false, confidenceScore
end

-- Check for suspicious accuracy with weapon-specific thresholds
local function detectAccuracy(clientNum)
    if not config.DETECT_ACCURACY then 
        debugLog("detectAccuracy: Detection disabled in config", 3)
        return false, 0 
    end
    
    local player = players[clientNum]
    if not player then
        debugLog("detectAccuracy: Player not found for clientNum " .. clientNum, 3)
        return false, 0
    end
    
    if player.shots < config.MIN_SAMPLES_REQUIRED then
        debugLog("detectAccuracy: Insufficient shot samples for " .. player.name .. " (" .. player.shots .. "/" .. config.MIN_SAMPLES_REQUIRED .. ")", 3)
        return false, 0
    end
    
    -- Get current weapon
    local currentWeapon = player.lastWeapon or "default"
    local baseAccuracyThreshold = getWeaponThreshold(currentWeapon, "accuracy")
    
    -- Apply skill-based adjustment
    local accuracyThreshold = getAdjustedThreshold(player, baseAccuracyThreshold, "accuracy")
    
    -- Calculate overall accuracy
    local accuracy = player.hits / player.shots
    
    -- Calculate weapon-specific accuracy if available
    local weaponAccuracy = accuracy
    if player.weaponStats[currentWeapon] then
        weaponAccuracy = player.weaponStats[currentWeapon].hits / player.weaponStats[currentWeapon].shots
    end
    
    debugLog("detectAccuracy: " .. player.name .. " - weapon=" .. currentWeapon .. 
             ", hits=" .. player.hits .. ", shots=" .. player.shots .. 
             ", accuracy=" .. weaponAccuracy .. ", base threshold=" .. baseAccuracyThreshold .. 
             ", adjusted threshold=" .. accuracyThreshold, 2)
    
    -- Confidence calculation
    local confidenceScore = 0
    
    if weaponAccuracy > accuracyThreshold then
        confidenceScore = (weaponAccuracy - accuracyThreshold) / (1 - accuracyThreshold)
        debugLog("detectAccuracy: Suspicious accuracy detected, confidence=" .. confidenceScore, 2)
        return true, confidenceScore, string.format("Suspicious accuracy with %s (%.2f)", currentWeapon, weaponAccuracy)
    end
    
    debugLog("detectAccuracy: No suspicious accuracy detected for " .. player.name, 3)
    return false, confidenceScore
end

-- Check for suspicious consecutive hits
local function detectConsecutiveHits(clientNum)
    if not config.DETECT_CONSECUTIVE_HITS then 
        debugLog("detectConsecutiveHits: Detection disabled in config", 3)
        return false, 0 
    end
    
    local player = players[clientNum]
    if not player then
        debugLog("detectConsecutiveHits: Player not found for clientNum " .. clientNum, 3)
        return false, 0
    end
    
    debugLog("detectConsecutiveHits: " .. player.name .. " - consecutiveHits=" .. player.consecutiveHits .. ", threshold=" .. config.CONSECUTIVE_HITS_THRESHOLD, 2)
    
    -- Confidence calculation
    local confidenceScore = 0
    
    if player.consecutiveHits > config.CONSECUTIVE_HITS_THRESHOLD then
        confidenceScore = (player.consecutiveHits - config.CONSECUTIVE_HITS_THRESHOLD) / 10
        if confidenceScore > 1 then confidenceScore = 1 end
        debugLog("detectConsecutiveHits: Suspicious consecutive hits detected, confidence=" .. confidenceScore, 2)
        return true, confidenceScore, string.format("Suspicious consecutive hits (%d)", player.consecutiveHits)
    end
    
    debugLog("detectConsecutiveHits: No suspicious consecutive hits detected for " .. player.name, 3)
    return false, confidenceScore
end
