-- ETAimbotDetector
-- A Lua script for ET:Legacy servers that detects and bans players using aimbots.
-- Enhanced version with improved detection algorithms and configurable thresholds.

-- Load all script modules
local microMovementDetection = dofile("scripts/aimbot_detector_micro_movement.lua")
local flickAnalysis = dofile("scripts/aimbot_detector_flick_analysis.lua")
local timeSeriesAnalysis = dofile("scripts/aimbot_detector_time_series.lua")
local weaponThresholds = dofile("scripts/aimbot_detector_weapon_thresholds.lua")
local skillAdaptation = dofile("scripts/aimbot_detector_skill_adaptation.lua")
local warningSystem = dofile("scripts/aimbot_detector_warning_system.lua")
local logging = dofile("scripts/aimbot_detector_logging.lua")

-- Load base configuration
dofile("scripts/aimbot_detector.lua")

-- Initialize global functions
debugLog = logging.debugLog
log = logging.log

-- Initialize the script
function et_InitGame(levelTime, randomSeed, restart)
    et.G_Print("^3ETAimbotDetector^7 v1.0 loaded\n")
    et.G_Print("^3ETAimbotDetector^7: Monitoring for suspicious aim patterns\n")
    
    -- Create log directory
    logging.ensureLogDirExists()
    
    -- Log initialization
    logging.logStartup()
}

-- Script information
function et_PrintModuleInformation()
    et.G_Print("^3ETAimbotDetector^7 v1.0 - Advanced aimbot detection for ET:Legacy\n")
    et.G_Print("^3ETAimbotDetector^7: Developed by Devin AI\n")
}

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
    
    -- Initialize detection variables
    local totalConfidence = 0
    local detectionCount = 0
    local reasons = {}
    
    -- Enhance detection with micro-movement analysis
    totalConfidence, detectionCount, reasons = microMovementDetection.enhanceDetectionWithMicroMovements(
        clientNum, totalConfidence, detectionCount, reasons)
    
    -- Enhance detection with flick pattern analysis
    totalConfidence, detectionCount, reasons = flickAnalysis.enhanceDetectionWithFlickAnalysis(
        clientNum, totalConfidence, detectionCount, reasons)
    
    -- Enhance detection with time-series analysis
    totalConfidence, detectionCount, reasons = timeSeriesAnalysis.enhanceDetectionWithTimeSeriesAnalysis(
        clientNum, totalConfidence, detectionCount, reasons)
    
    -- Enhance detection with weapon-specific thresholds
    totalConfidence, detectionCount, reasons = weaponThresholds.enhanceDetectionWithWeaponThresholds(
        clientNum, totalConfidence, detectionCount, reasons)
    
    -- Calculate average confidence
    local avgConfidence = 0
    if detectionCount > 0 then
        avgConfidence = totalConfidence / detectionCount
    end
    
    -- Adjust confidence based on skill level
    local suspiciousActivity = avgConfidence >= config.CONFIDENCE_THRESHOLD
    suspiciousActivity, avgConfidence = skillAdaptation.enhanceDetectionWithSkillAdaptation(
        clientNum, suspiciousActivity, avgConfidence)
    
    -- Determine aimbot type
    local aimbotType = "Unknown"
    if player.humanizedAimbotConfidence > player.aimbotConfidence then
        aimbotType = "Humanized"
    else
        aimbotType = "Standard"
    end
    
    -- Combine reasons into a single string
    local reasonStr = table.concat(reasons, ", ")
    
    debugLog("calculateAimbotConfidence: Final confidence for " .. player.name .. ": " .. avgConfidence .. " (type: " .. aimbotType .. ")", 1)
    
    return avgConfidence, detectionCount, aimbotType, reasonStr
}

-- Run detection on a player
local function runDetection(clientNum)
    local player = players[clientNum]
    if not player then return end
    
    -- Skip if we don't have enough data yet
    if player.shots < config.MIN_SAMPLES_REQUIRED then
        debugLog("runDetection: Skipping " .. player.name .. " - insufficient data (" .. player.shots .. "/" .. config.MIN_SAMPLES_REQUIRED .. " shots)", 2)
        return
    end
    
    -- Skip if detection was run recently
    local currentTime = et.trap_Milliseconds()
    if currentTime - player.lastDetectionTime < config.DETECTION_INTERVAL then
        debugLog("runDetection: Skipping " .. player.name .. " - detection ran recently (" .. (currentTime - player.lastDetectionTime) .. "ms ago)", 3)
        return
    end
    
    -- Update last detection time
    player.lastDetectionTime = currentTime
    
    -- Calculate aimbot confidence
    local confidence, detectionCount, aimbotType, reason = calculateAimbotConfidence(clientNum)
    
    -- Store confidence score
    player.aimbotConfidence = confidence
    
    -- Check if confidence exceeds threshold
    if confidence >= config.CONFIDENCE_THRESHOLD and detectionCount >= 2 then
        debugLog("runDetection: Aimbot detected for " .. player.name .. " - confidence: " .. confidence .. ", detections: " .. detectionCount .. ", type: " .. aimbotType, 1)
        
        -- Log detection
        logging.logDetection(player, confidence, detectionCount, aimbotType, reason)
        
        -- Check if player should be warned
        warningSystem.checkForWarning(clientNum, confidence, detectionCount, reason)
    else
        debugLog("runDetection: No aimbot detected for " .. player.name .. " - confidence: " .. confidence .. ", detections: " .. detectionCount, 2)
    end
}

-- ET:Legacy callback: RunFrame
function et_RunFrame(levelTime)
    -- Process each player
    for clientNum = 0, et.trap_Cvar_Get("sv_maxclients") - 1 do
        if et.gentity_get(clientNum, "inuse") then
            -- Initialize player data if needed
            if not players[clientNum] then
                initPlayerData(clientNum)
            end
            
            -- Update player angles
            updatePlayerAngles(clientNum)
            
            -- Run detection
            runDetection(clientNum)
            
            -- Log player stats periodically
            local currentTime = et.trap_Milliseconds()
            if player.lastStatsLogTime and currentTime - player.lastStatsLogTime >= config.LOG_STATS_INTERVAL then
                logging.logPlayerStats(player)
                player.lastStatsLogTime = currentTime
            end
        end
    end
}

-- Script is now loaded and ready
et.G_Print("^3ETAimbotDetector^7: All modules loaded successfully\n")
