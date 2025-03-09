-- ETAimbotDetector
-- A Lua script for ET:Legacy servers that detects and bans players using aimbots.

-- Configuration variables
-- Weapon-specific thresholds
local weaponThresholds = {
    -- Default thresholds
    default = {
        accuracy = 0.8,
        headshot = 0.6,
        angleChange = 160
    },
    -- Sniper rifles
    weapon_K43 = {
        accuracy = 0.85,
        headshot = 0.7,
        angleChange = 170
    },
    weapon_K43_scope = {
        accuracy = 0.9,
        headshot = 0.8,
        angleChange = 175
    },
    weapon_M1Garand_scope = {
        accuracy = 0.9,
        headshot = 0.8,
        angleChange = 175
    },
    -- Machine guns
    weapon_MP40 = {
        accuracy = 0.7,
        headshot = 0.5,
        angleChange = 150
    },
    weapon_Thompson = {
        accuracy = 0.7,
        headshot = 0.5,
        angleChange = 150
    },
    -- Pistols
    weapon_Luger = {
        accuracy = 0.75,
        headshot = 0.6,
        angleChange = 160
    },
    weapon_Colt = {
        accuracy = 0.75,
        headshot = 0.6,
        angleChange = 160
    }
}

local config = {
    -- Detection thresholds
    MAX_ANGLE_CHANGE = 180,           -- Maximum angle change in degrees that's considered suspicious
    ANGLE_CHANGE_THRESHOLD = 120,     -- Angle change threshold for suspicious activity (decreased from 170)
    HEADSHOT_RATIO_THRESHOLD = 0.6,   -- Ratio of headshots to total kills that's considered suspicious (decreased from 0.8)
    ACCURACY_THRESHOLD = 0.7,         -- Accuracy threshold that's considered suspicious (decreased from 0.9)
    CONSECUTIVE_HITS_THRESHOLD = 10,  -- Number of consecutive hits that's considered suspicious (decreased from 15)
    
    -- Advanced detection settings
    DETECTION_INTERVAL = 3000,        -- Minimum time between detections in milliseconds (decreased from 5000)
    PATTERN_DETECTION = true,         -- Enable pattern-based detection
    STATISTICAL_ANALYSIS = true,      -- Enable statistical analysis
    TIME_SERIES_ANALYSIS = true,      -- Enable time-series analysis
    MICRO_MOVEMENT_DETECTION = true,  -- Enable micro-movement detection for humanized aimbots
    MIN_SAMPLES_REQUIRED = 15,        -- Minimum number of samples required for statistical analysis (decreased from 20)
    CONFIDENCE_THRESHOLD = 0.6,       -- Confidence threshold for aimbot detection (decreased from 0.8)
    
    -- Time-series analysis settings
    TIME_SERIES_THRESHOLD = 0.6,      -- Threshold for time-series analysis confidence
    MIN_SHOT_SAMPLES = 5,             -- Minimum number of shot timing samples required
    TIMING_CONSISTENCY_WEIGHT = 0.6,  -- Weight for timing consistency in time-series analysis
    PATTERN_DETECTION_WEIGHT = 0.4,   -- Weight for pattern detection in time-series analysis
    
    -- Weapon-specific settings
    WEAPON_SPECIFIC_THRESHOLDS = true, -- Enable weapon-specific thresholds
    
    -- Warning and ban settings
    WARNINGS_BEFORE_BAN = 3,          -- Number of warnings before ban
    BAN_DURATION = 7,                 -- Ban duration in days
    PERMANENT_BAN_THRESHOLD = 3,      -- Number of temporary bans before permanent ban
    
    -- Logging settings
    LOG_LEVEL = 2,                    -- 0: None, 1: Minimal, 2: Detailed, 3: Debug
    LOG_FILE = "aimbot_detector.log", -- Log file name
    LOG_DIR = "logs",                 -- Directory to store log files (will be created if it doesn't exist)
    
    -- Enable/disable specific detection methods
    DETECT_ANGLE_CHANGES = true,      -- Detect suspicious angle changes
    DETECT_HEADSHOT_RATIO = true,     -- Detect suspicious headshot ratio
    DETECT_ACCURACY = true,           -- Detect suspicious accuracy
    DETECT_CONSECUTIVE_HITS = true,   -- Detect suspicious consecutive hits
    
    -- New options
    DEBUG_MODE = true,                -- Enable/disable debug logging to server console
    DEBUG_LEVEL = 3,                  -- Debug level: 1=basic, 2=detailed, 3=verbose
    IGNORE_OMNIBOTS = true,           -- Skip detection for OMNIBOT players
    CHAT_WARNINGS = true,             -- Show warnings in player chat
}

-- Player data storage
local players = {}

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
    }
    
    debugLog("Player initialized: " .. name .. " (GUID: " .. guid .. ")")
end

-- Calculate standard deviation
local function calculateStdDev(values, mean)
    if #values < 2 then return 0 end
    
    local sum = 0
    for _, v in ipairs(values) do
        sum = sum + (v - mean)^2
    end
    
    return math.sqrt(sum / (#values - 1))
end

-- Calculate moving average
local function calculateMovingAverage(values, window)
    if #values < window then return 0 end
    
    local sum = 0
    for i = #values - window + 1, #values do
        sum = sum + values[i]
    end
    
    return sum / window
end

-- Calculate timing consistency between shots
local function calculateTimingConsistency(player)
    if not player.weaponStats[player.lastWeapon] then return 0 end
    if not player.shotTimings or #player.shotTimings < 5 then return 0 end
    
    local timings = player.shotTimings
    local avg = calculateMovingAverage(timings, #timings)
    local stdDev = calculateStdDev(timings, avg)
    
    -- Normalize standard deviation as a percentage of the average
    local normalizedStdDev = stdDev / avg
    
    -- Return consistency score (1 - normalized standard deviation)
    -- Higher score means more consistent timing (suspicious)
    return math.max(0, math.min(1, 1 - normalizedStdDev))
end

-- Detect repeating patterns in a sequence
local function detectRepeatingPatterns(sequence)
    if #sequence < 10 then return 0 end
    
    local patternCount = 0
    -- Check for patterns of length 2-4
    for patternLength = 2, 4 do
        for i = 1, #sequence - (patternLength * 2) + 1 do
            local pattern = {}
            for j = 0, patternLength - 1 do
                pattern[j+1] = sequence[i+j]
            end
            
            -- Check if this pattern repeats
            local repeats = 0
            for k = i + patternLength, #sequence - patternLength + 1, patternLength do
                local matches = true
                for j = 1, patternLength do
                    if math.abs(sequence[k+j-1] - pattern[j]) > 5 then
                        matches = false
                        break
                    end
                end
                if matches then repeats = repeats + 1 end
            end
            
            if repeats > 1 then patternCount = patternCount + 1 end
        end
    end
    
    -- Return normalized pattern score (0-1)
    return math.min(1, patternCount / 5)
end

-- Analyze time-series data for aimbot patterns
local function analyzeTimeSeriesData(clientNum)
    local player = players[clientNum]
    if not player then return 0, "No data" end
    
    -- Skip if we don't have enough data
    if #player.angleChanges < 10 or not player.shotTimings or #player.shotTimings < 5 then
        return 0, "Insufficient data"
    end
    
    -- Calculate timing consistency
    local timingConsistency = calculateTimingConsistency(player)
    
    -- Detect repeating patterns in angle changes
    local patternScore = detectRepeatingPatterns(player.angleChanges)
    
    -- Calculate combined time-series score
    local timeSeriesScore = (timingConsistency * 0.6) + (patternScore * 0.4)
    
    local reason = string.format("Time-series analysis (timing: %.2f, patterns: %.2f)", 
        timingConsistency, patternScore)
    
    return timeSeriesScore, reason
end

-- Get weapon-specific threshold
local function getWeaponThreshold(weapon, thresholdType)
    if not config.WEAPON_SPECIFIC_THRESHOLDS then
        return config[thresholdType]
    end
    
    if weaponThresholds[weapon] and weaponThresholds[weapon][thresholdType] then
        return weaponThresholds[weapon][thresholdType]
    end
    
    return weaponThresholds.default[thresholdType] or config[thresholdType]
end

-- Calculate angle difference (accounting for 360 degree wrapping)
local function getAngleDifference(a1, a2)
    if a1 == nil or a2 == nil then
        return 0
    end
    local diff = math.abs(a1 - a2)
    if diff > 180 then
        diff = 360 - diff
    end
    return diff
end

-- Ensure log directory exists (cross-platform compatible)
local function ensureLogDirExists()
    if not config.LOG_DIR or config.LOG_DIR == "" then
        return ""
    end
    
    -- Check if directory exists first
    local dirExists = false
    local testFile = io.open(config.LOG_DIR .. "/test.tmp", "w")
    if testFile then
        testFile:close()
        os.remove(config.LOG_DIR .. "/test.tmp")
        dirExists = true
    end
    
    -- Create directory if it doesn't exist
    if not dirExists then
        -- Try platform-specific directory creation
        local success
        if package.config:sub(1,1) == '\\' then
            -- Windows
            success = os.execute('if not exist "' .. config.LOG_DIR .. '" mkdir "' .. config.LOG_DIR .. '"')
        else
            -- Unix/Linux/macOS
            success = os.execute("mkdir -p " .. config.LOG_DIR)
        end
        
        if not success then
            et.G_Print("Warning: Failed to create log directory: " .. config.LOG_DIR .. "\n")
            return ""
        end
    end
    
    -- Add trailing slash/backslash based on platform
    local separator = package.config:sub(1,1)
    if config.LOG_DIR:sub(-1) ~= separator then
        return config.LOG_DIR .. separator
    else
        return config.LOG_DIR
    end
end

-- Log function
local function log(level, message)
    if level <= config.LOG_LEVEL then
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        local logMessage = string.format("[%s] %s\n", timestamp, message)
        
        -- Print to console
        et.G_Print(logMessage)
        
        -- Write to log file
        local logDir = ensureLogDirExists()
        local file = io.open(logDir .. config.LOG_FILE, "a")
        if file then
            file:write(logMessage)
            file:close()
        else
            et.G_Print("Warning: Could not open log file: " .. logDir .. config.LOG_FILE .. "\n")
        end
    end
end

-- Debug logging function (global for ET:Legacy callbacks)
function debugLog(message, level)
    level = level or 1 -- Default to level 1 if not specified
    
    if config.DEBUG_MODE and level <= config.DEBUG_LEVEL then
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        local debugMessage = string.format("[DEBUG-%d %s] %s", level, timestamp, message)
        et.G_Print(debugMessage .. "\n")
        
        -- Also write to log file for persistent debugging
        local logDir = ensureLogDirExists()
        local file = io.open(logDir .. "aimbot_debug.log", "a")
        if file then
            file:write(debugMessage .. "\n")
            file:close()
        else
            et.G_Print("Warning: Could not open debug log file: " .. logDir .. "aimbot_debug.log\n")
        end
    end
end

-- Ban player
local function banPlayer(clientNum, reason)
    local player = players[clientNum]
    if not player then return end
    
    player.tempBans = player.tempBans + 1
    
    -- Determine ban duration
    local banDuration = config.BAN_DURATION
    local isPermanent = player.tempBans >= config.PERMANENT_BAN_THRESHOLD
    
    if isPermanent then
        banDuration = 0 -- 0 means permanent in ET:Legacy
    end
    
    -- Log ban
    log(1, string.format("%s ban issued to %s (%s): %s", 
        isPermanent and "Permanent" or "Temporary", 
        player.name, player.guid, reason))
    
    -- Execute ban command
    local banCmd = string.format("!ban %s %d %s", 
        player.guid, banDuration, "Aimbot detected: " .. reason)
    et.trap_SendConsoleCommand(et.EXEC_APPEND, banCmd)
end

-- Issue warning to player
local function warnPlayer(clientNum, reason)
    local player = players[clientNum]
    if not player then return end
    
    player.warnings = player.warnings + 1
    player.lastWarningTime = et.trap_Milliseconds()
    
    local warningMessage = string.format("^1WARNING^7: Suspicious activity detected (%s). Warning %d/%d", 
        reason, player.warnings, config.WARNINGS_BEFORE_BAN)
    
    -- Send center-print message to player
    et.trap_SendServerCommand(clientNum, "cp " .. warningMessage)
    
    -- Send chat message to player if enabled
    if config.CHAT_WARNINGS then
        et.trap_SendServerCommand(clientNum, "chat \"" .. warningMessage .. "\"")
    end
    
    -- Log warning
    log(1, string.format("Warning issued to %s (%s): %s", 
        player.name, player.guid, reason))
    
    debugLog("Warning issued to " .. player.name .. " for " .. reason)
    
    -- Check if player should be banned
    if player.warnings >= config.WARNINGS_BEFORE_BAN then
        banPlayer(clientNum, reason)
    end
end

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
    for i = 2, #player.angleChanges do
        if player.angleChanges[i] > 100 and player.angleChanges[i-1] < 5 then
            snapCount = snapCount + 1
            debugLog("detectAngleChanges: Snap detected at sample " .. i .. " (" .. player.angleChanges[i] .. "° after " .. player.angleChanges[i-1] .. "°)", 3)
        end
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
    local headshotThreshold = getWeaponThreshold(currentWeapon, "headshot")
    
    -- Calculate headshot ratio
    local ratio = player.headshots / player.kills
    
    debugLog("detectHeadshotRatio: " .. player.name .. " - weapon=" .. currentWeapon .. ", headshots=" .. player.headshots .. ", kills=" .. player.kills .. ", ratio=" .. ratio .. ", threshold=" .. headshotThreshold, 2)
    
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
    local accuracyThreshold = getWeaponThreshold(currentWeapon, "accuracy")
    
    -- Calculate overall accuracy
    local accuracy = player.hits / player.shots
    
    -- Calculate weapon-specific accuracy if available
    local weaponAccuracy = accuracy
    if player.weaponStats[currentWeapon] then
        weaponAccuracy = player.weaponStats[currentWeapon].hits / player.weaponStats[currentWeapon].shots
    end
    
    debugLog("detectAccuracy: " .. player.name .. " - weapon=" .. currentWeapon .. ", hits=" .. player.hits .. ", shots=" .. player.shots .. ", accuracy=" .. weaponAccuracy .. ", threshold=" .. accuracyThreshold, 2)
    
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
    if not config.DETECT_CONSECUTIVE_HITS then return false end
    
    local player = players[clientNum]
    if not player then return false end
    
    if player.consecutiveHits > config.CONSECUTIVE_HITS_THRESHOLD then
        return true, string.format("Suspicious consecutive hits (%d)", player.consecutiveHits)
    end
    
    return false
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

-- Detect rapid target switching
local function detectTargetSwitching(clientNum)
    local player = players[clientNum]
    if not player or #player.targetSwitches < 5 then return false, 0 end
    
    local rapidSwitchCount = 0
    for _, switchTime in ipairs(player.targetSwitches) do
        if switchTime < 300 then -- Less than 300ms between target switches
            rapidSwitchCount = rapidSwitchCount + 1
        end
    end
    
    local switchRatio = rapidSwitchCount / #player.targetSwitches
    debugLog("Target switching: " .. player.name .. " - rapid=" .. rapidSwitchCount .. ", total=" .. #player.targetSwitches .. ", ratio=" .. switchRatio)
    
    if switchRatio > 0.6 and #player.targetSwitches > 5 then
        local confidence = switchRatio - 0.6
        return true, confidence, string.format("Suspicious rapid target switching (%.2f of switches < 300ms)", switchRatio)
    end
    
    return false, 0
end

-- Calculate overall aimbot confidence score
local function calculateAimbotConfidence(clientNum)
    local player = players[clientNum]
    if not player then 
        debugLog("calculateAimbotConfidence: Player not found for clientNum " .. clientNum, 2)
        return 0, 0, "Unknown", "" 
    end
    
    -- Skip if we don't have enough data
    if player.shots < config.MIN_SAMPLES_REQUIRED then
        debugLog("calculateAimbotConfidence: Insufficient data for " .. player.name .. " (shots: " .. player.shots .. "/" .. config.MIN_SAMPLES_REQUIRED .. ")", 2)
        return 0, 0, "Insufficient data", ""
    end
    
    debugLog("calculateAimbotConfidence: Analyzing player " .. player.name .. " (shots: " .. player.shots .. ", hits: " .. player.hits .. ", headshots: " .. player.headshots .. ")", 2)
    
    -- Run individual detections and collect confidence scores
    local totalConfidence = 0
    local detectionCount = 0
    local reasons = {}
    local detectionResults = {}
    
    local suspicious, confidence, reason
    
    -- Angle changes detection
    suspicious, confidence, reason = detectAngleChanges(clientNum)
    detectionResults["angle"] = {suspicious = suspicious, confidence = confidence, reason = reason}
    debugLog("Detection - Angle changes: " .. (suspicious and "SUSPICIOUS" or "normal") .. " (confidence: " .. confidence .. ")", 2)
    
    if suspicious then
        totalConfidence = totalConfidence + confidence
        detectionCount = detectionCount + 1
        table.insert(reasons, reason)
    end
    
    -- Headshot ratio detection
    suspicious, confidence, reason = detectHeadshotRatio(clientNum)
    detectionResults["headshot"] = {suspicious = suspicious, confidence = confidence, reason = reason}
    debugLog("Detection - Headshot ratio: " .. (suspicious and "SUSPICIOUS" or "normal") .. " (confidence: " .. confidence .. ")", 2)
    
    if suspicious then
        totalConfidence = totalConfidence + confidence
        detectionCount = detectionCount + 1
        table.insert(reasons, reason)
    end
    
    -- Accuracy detection
    suspicious, confidence, reason = detectAccuracy(clientNum)
    detectionResults["accuracy"] = {suspicious = suspicious, confidence = confidence, reason = reason}
    debugLog("Detection - Accuracy: " .. (suspicious and "SUSPICIOUS" or "normal") .. " (confidence: " .. confidence .. ")", 2)
    
    if suspicious then
        totalConfidence = totalConfidence + confidence
        detectionCount = detectionCount + 1
        table.insert(reasons, reason)
    end
    
    -- Consecutive hits detection
    suspicious, confidence, reason = detectConsecutiveHits(clientNum)
    detectionResults["consecutive"] = {suspicious = suspicious, confidence = confidence, reason = reason}
    debugLog("Detection - Consecutive hits: " .. (suspicious and "SUSPICIOUS" or "normal") .. " (confidence: " .. confidence .. ")", 2)
    
    if suspicious then
        totalConfidence = totalConfidence + confidence
        detectionCount = detectionCount + 1
        table.insert(reasons, reason)
    end
    
    -- Target switching detection (new)
    if config.MICRO_MOVEMENT_DETECTION and player.targetSwitches and #player.targetSwitches >= 5 then
        suspicious, confidence, reason = detectTargetSwitching(clientNum)
        if suspicious then
            totalConfidence = totalConfidence + confidence * 1.2 -- Weight target switching higher
            detectionCount = detectionCount + 1
            table.insert(reasons, reason)
            
            debugLog("Target switching detection found suspicious pattern: " .. reason)
        end
    end
    
    -- Time-series analysis (new)
    if config.TIME_SERIES_ANALYSIS and player.shotTimings and #player.shotTimings >= config.MIN_SHOT_SAMPLES then
        local timeSeriesScore, timeSeriesReason = analyzeTimeSeriesData(clientNum)
        
        if timeSeriesScore > config.TIME_SERIES_THRESHOLD then
            totalConfidence = totalConfidence + timeSeriesScore
            detectionCount = detectionCount + 1
            table.insert(reasons, timeSeriesReason)
            
            debugLog("Time-series analysis detected suspicious pattern: " .. timeSeriesReason)
        end
    end
    
    -- Calculate final confidence score
    local finalConfidence = 0
    if detectionCount > 0 then
        finalConfidence = totalConfidence / detectionCount
    end
    
    -- Determine aimbot type based on patterns
    local aimbotType = "Unknown"
    if finalConfidence > config.CONFIDENCE_THRESHOLD then
        -- Determine aimbot type based on multiple factors
        if player.stdDevAngleChange < 15 and player.avgAngleChange > 100 then
            aimbotType = "Humanized"
        elseif player.shotTimings and #player.shotTimings >= 5 then
            local timingConsistency = calculateTimingConsistency(player)
            if timingConsistency > 0.8 then
                aimbotType = "Humanized"
            else
                aimbotType = "Normal"
            end
        else
            aimbotType = "Normal"
        end
    end
    
    -- Detailed debug output
    debugLog("DETECTION SUMMARY for " .. player.name .. ":", 1)
    debugLog("  - Shots: " .. player.shots .. ", Hits: " .. player.hits .. ", Headshots: " .. player.headshots .. ", Kills: " .. player.kills, 1)
    debugLog("  - Angle changes: avg=" .. player.avgAngleChange .. ", stdDev=" .. player.stdDevAngleChange, 1)
    debugLog("  - Final confidence: " .. finalConfidence .. " (threshold: " .. config.CONFIDENCE_THRESHOLD .. ")", 1)
    debugLog("  - Detection count: " .. detectionCount, 1)
    debugLog("  - Aimbot type: " .. aimbotType, 1)
    debugLog("  - Reasons: " .. (reasons[1] and table.concat(reasons, "; ") or "none"), 1)
    
    return finalConfidence, detectionCount, aimbotType, table.concat(reasons, "; ")
end
-- Run detection with time-based intervals and confidence scoring
local function runDetection(clientNum)
    local player = players[clientNum]
    if not player then 
        debugLog("runDetection: Player not found for clientNum " .. clientNum, 2)
        return 
    end
    
    -- Skip detection for OMNIBOT players if enabled
    if config.IGNORE_OMNIBOTS and isOmniBot(player.guid) then
        debugLog("runDetection: Skipping detection for OMNIBOT: " .. player.name, 1)
        return
    end
    
    -- Check if enough time has passed since last detection
    local currentTime = et.trap_Milliseconds()
    if (currentTime - player.lastDetectionTime) < config.DETECTION_INTERVAL then
        debugLog("runDetection: Detection interval not reached for " .. player.name .. " (" .. (currentTime - player.lastDetectionTime) .. "/" .. config.DETECTION_INTERVAL .. "ms)", 3)
        return
    end
    
    debugLog("runDetection: Running detection for player: " .. player.name, 1)
    debugLog("runDetection: Player stats - shots: " .. player.shots .. ", hits: " .. player.hits .. ", headshots: " .. player.headshots .. ", kills: " .. player.kills, 2)
    
    -- Calculate confidence score
    local confidence, detectionCount, aimbotType, reasons = calculateAimbotConfidence(clientNum)
    
    -- Update player's confidence score
    player.aimbotConfidence = confidence
    player.lastDetectionTime = currentTime
    
    debugLog("runDetection: Detection result - confidence: " .. confidence .. ", threshold: " .. config.CONFIDENCE_THRESHOLD .. ", detectionCount: " .. detectionCount, 1)
    
    -- Issue warning if confidence exceeds threshold
    if confidence > config.CONFIDENCE_THRESHOLD and detectionCount >= 2 then
        local warningMessage = string.format("Detected possible %s aimbot (confidence: %.2f)", 
            aimbotType, confidence)
        
        debugLog("runDetection: WARNING TRIGGERED for " .. player.name .. " - " .. warningMessage .. " - " .. reasons, 1)
        warnPlayer(clientNum, warningMessage .. " - " .. reasons)
    else
        debugLog("runDetection: No warning triggered for " .. player.name .. " (confidence: " .. confidence .. ", detectionCount: " .. detectionCount .. ")", 2)
        if confidence > 0 then
            debugLog("runDetection: Suspicious activity detected but below threshold - " .. reasons, 2)
        end
    end
end

-- ET:Legacy callback: InitGame
function et_InitGame(levelTime, randomSeed, restart)
    log(1, "Aimbot Detector initialized")
    debugLog("DEBUG mode enabled")
    
    -- Reset player data on map change
    players = {}
end

-- ET:Legacy callback: ClientConnect
function et_ClientConnect(clientNum, firstTime, isBot)
    if isBot == 1 then return end
    
    initPlayerData(clientNum)
    
    -- Log if player is an OMNIBOT
    if config.IGNORE_OMNIBOTS and isOmniBot(players[clientNum].guid) then
        log(1, string.format("OMNIBOT detected and will be ignored: %s (%s)", 
            players[clientNum].name, players[clientNum].guid))
        debugLog("OMNIBOT detected: " .. players[clientNum].name)
    else
        log(2, string.format("Player connected: %s (%s)", 
            players[clientNum].name, players[clientNum].guid))
    end
end

-- ET:Legacy callback: ClientDisconnect
function et_ClientDisconnect(clientNum)
    if players[clientNum] then
        log(2, string.format("Player disconnected: %s (%s)", 
            players[clientNum].name, players[clientNum].guid))
        players[clientNum] = nil
    end
end

-- ET:Legacy callback: ClientUserinfoChanged
function et_ClientUserinfoChanged(clientNum)
    if not players[clientNum] then
        initPlayerData(clientNum)
    else
        -- Update player name
        players[clientNum].name = et.Info_ValueForKey(et.trap_GetUserinfo(clientNum), "name")
    end
end

-- ET:Legacy callback: WeaponFire
function et_WeaponFire(clientNum, weapon)
    if not players[clientNum] then 
        debugLog("et_WeaponFire: Player not found for clientNum " .. clientNum, 2)
        return 0 
    end
    
    local player = players[clientNum]
    
    -- Skip OMNIBOT players if enabled
    if config.IGNORE_OMNIBOTS and isOmniBot(player.guid) then
        debugLog("et_WeaponFire: Skipping WeaponFire for OMNIBOT: " .. player.name, 1)
        return 0
    end
    
    -- Track current weapon
    player.lastWeapon = weapon
    
    -- Initialize weapon stats if needed
    if not player.weaponStats[weapon] then
        player.weaponStats[weapon] = {
            shots = 0,
            hits = 0,
            headshots = 0,
            lastShotTime = 0,
            shotTimings = {}
        }
        debugLog("et_WeaponFire: Initialized weapon stats for " .. player.name .. " using " .. weapon, 2)
    end
    
    -- Update shot count
    player.shots = player.shots + 1
    player.weaponStats[weapon].shots = player.weaponStats[weapon].shots + 1
    
    -- Track shot timing
    local currentTime = et.trap_Milliseconds()
    local timeSinceLastShot = currentTime - player.lastShotTime
    
    -- Store shot timing data if it's a valid interval (not first shot and not too long between shots)
    if player.lastShotTime > 0 and timeSinceLastShot < 2000 then
        -- Store in weapon-specific timings
        table.insert(player.weaponStats[weapon].shotTimings, timeSinceLastShot)
        if #player.weaponStats[weapon].shotTimings > 20 then
            table.remove(player.weaponStats[weapon].shotTimings, 1)
        end
        
        -- Store in player's overall timings
        table.insert(player.shotTimings, timeSinceLastShot)
        if #player.shotTimings > 20 then
            table.remove(player.shotTimings, 1)
        end
        
        debugLog("Shot timing: " .. timeSinceLastShot .. "ms with " .. weapon)
    end
    
    player.lastShotTime = currentTime
    player.weaponStats[weapon].lastShotTime = currentTime
    
    debugLog("et_WeaponFire: " .. player.name .. " fired weapon " .. weapon .. " (total shots: " .. player.shots .. ")", 1)
    
    -- Get current view angles
    local angles = et.gentity_get(clientNum, "ps.viewangles")
    
    -- Check if angles are valid
    if angles == nil then 
        debugLog("et_WeaponFire: Could not get view angles for " .. player.name, 2)
        return 0 
    end
    
    -- Calculate angle change
    local pitchChange = getAngleDifference(angles[0], player.lastAngle.pitch)
    local yawChange = getAngleDifference(angles[1], player.lastAngle.yaw)
    local totalChange = math.sqrt(pitchChange^2 + yawChange^2)
    
    debugLog("et_WeaponFire: Angle change for " .. player.name .. " - pitch: " .. pitchChange .. "°, yaw: " .. yawChange .. "°, total: " .. totalChange .. "°", 2)
    
    -- Store angle change
    if totalChange < config.MAX_ANGLE_CHANGE then
        table.insert(player.angleChanges, totalChange)
        if #player.angleChanges > 20 then
            table.remove(player.angleChanges, 1)
        end
        debugLog("et_WeaponFire: Stored angle change for " .. player.name .. " (" .. #player.angleChanges .. " samples)", 3)
    else
        debugLog("et_WeaponFire: Angle change exceeds MAX_ANGLE_CHANGE, not storing", 2)
    end
    
    -- Update last angle
    player.lastAngle.pitch = angles[0]
    player.lastAngle.yaw = angles[1]
    
    return 0 -- Pass through to game
end

-- ET:Legacy callback: Damage
function et_Damage(targetNum, attackerNum, damage, dflags, mod)
    if attackerNum < 0 or attackerNum >= 64 or targetNum < 0 or targetNum >= 64 then 
        debugLog("et_Damage: Invalid client numbers (attacker: " .. attackerNum .. ", target: " .. targetNum .. ")", 2)
        return 
    end
    
    if not players[attackerNum] then 
        debugLog("et_Damage: Player not found for attackerNum " .. attackerNum, 2)
        return 
    end
    
    local player = players[attackerNum]
    
    -- Skip OMNIBOT players if enabled
    if config.IGNORE_OMNIBOTS and isOmniBot(player.guid) then
        debugLog("et_Damage: Skipping Damage for OMNIBOT: " .. player.name, 1)
        return
    end
    
    debugLog("et_Damage: " .. player.name .. " dealt " .. damage .. " damage to player " .. targetNum .. " with mod " .. mod, 1)
    
    -- Update hit counts
    player.hits = player.hits + 1
    player.consecutiveHits = player.consecutiveHits + 1
    
    -- Update weapon-specific stats
    local currentWeapon = player.lastWeapon or "default"
    if player.weaponStats[currentWeapon] then
        player.weaponStats[currentWeapon].hits = player.weaponStats[currentWeapon].hits + 1
        debugLog("et_Damage: Updated weapon stats for " .. currentWeapon .. " (hits: " .. player.weaponStats[currentWeapon].hits .. ")", 3)
    else
        debugLog("et_Damage: No weapon stats found for " .. currentWeapon, 2)
    end
    
    -- Check if headshot (bit 2 is DAMAGE_HEADSHOT in ET:Legacy)
    local isHeadshot = false
    if et.isBitSet then
        isHeadshot = et.isBitSet(dflags, 2)
        if isHeadshot then
            player.headshots = player.headshots + 1
            debugLog("et_Damage: HEADSHOT detected for " .. player.name .. " (total: " .. player.headshots .. ")", 1)
            if player.weaponStats[currentWeapon] then
                player.weaponStats[currentWeapon].headshots = player.weaponStats[currentWeapon].headshots + 1
            end
        end
    else
        debugLog("et_Damage: et.isBitSet function not available, cannot check for headshot", 2)
    end
    
    -- Track target switching
    local currentTime = et.trap_Milliseconds()
    if player.lastTarget ~= targetNum and player.lastTarget ~= -1 then
        local switchTime = currentTime - player.lastTargetTime
        
        -- Only track valid switches (not too long between targets)
        if switchTime < 2000 then
            table.insert(player.targetSwitches, switchTime)
            if #player.targetSwitches > 20 then
                table.remove(player.targetSwitches, 1)
            end
            
            debugLog("Target switch: " .. player.name .. " switched from " .. player.lastTarget .. " to " .. targetNum .. " in " .. switchTime .. "ms")
        end
    end
    
    -- Update last target info
    player.lastTarget = targetNum
    player.lastTargetTime = currentTime
    
    -- Only run detection occasionally, not on every hit
    if (currentTime - player.lastDetectionTime) > config.DETECTION_INTERVAL then
        debugLog("et_Damage: Running detection for " .. player.name .. " after damage event", 2)
        runDetection(attackerNum)
    else
        debugLog("et_Damage: Skipping detection due to interval not reached", 3)
    end
end

-- ET:Legacy callback: Obituary
function et_Obituary(targetNum, attackerNum, meansOfDeath)
    if attackerNum < 0 or attackerNum >= 64 or targetNum < 0 or targetNum >= 64 then 
        debugLog("et_Obituary: Invalid client numbers (attacker: " .. attackerNum .. ", target: " .. targetNum .. ")", 2)
        return 
    end
    
    if not players[attackerNum] then 
        debugLog("et_Obituary: Player not found for attackerNum " .. attackerNum, 2)
        return 
    end
    
    if attackerNum == targetNum then
        debugLog("et_Obituary: Self kill detected for " .. players[attackerNum].name, 2)
        return
    end
    
    local player = players[attackerNum]
    
    -- Skip OMNIBOT players if enabled
    if config.IGNORE_OMNIBOTS and isOmniBot(player.guid) then
        debugLog("et_Obituary: Skipping Obituary for OMNIBOT: " .. player.name, 1)
        return
    end
    
    player.kills = player.kills + 1
    debugLog("et_Obituary: " .. player.name .. " killed player " .. targetNum .. " with " .. meansOfDeath .. " (total kills: " .. player.kills .. ")", 1)
    
    -- Run detection after updating stats
    debugLog("et_Obituary: Running detection for " .. player.name .. " after kill", 2)
    runDetection(attackerNum)
end

-- ET:Legacy callback: MissedShot (custom)
function et_MissedShot(clientNum)
    if not players[clientNum] then 
        debugLog("et_MissedShot: Player not found for clientNum " .. clientNum, 2)
        return 
    end
    
    local player = players[clientNum]
    
    -- Skip OMNIBOT players if enabled
    if config.IGNORE_OMNIBOTS and isOmniBot(player.guid) then
        debugLog("et_MissedShot: Skipping MissedShot for OMNIBOT: " .. player.name, 1)
        return
    end
    
    debugLog("et_MissedShot: " .. player.name .. " missed a shot, resetting consecutive hits", 2)
    player.consecutiveHits = 0
end

-- Return 1 if the module loaded successfully
return 1
