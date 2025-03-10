-- ETAimbotDetector
-- A Lua script for ET:Legacy servers that detects and bans players using aimbots.
-- Enhanced version with improved detection algorithms and configurable thresholds.

-- Load all script modules
-- Micro-movement detection functions are included directly in this file
-- Flick analysis functions are included directly in this file
-- Time series analysis functions are included directly in this file
-- Weapon thresholds functions are included directly in this file
-- Skill adaptation functions are included directly in this file
-- Warning system functions are included directly in this file
-- Logging functions are included directly in this file

-- Load base configuration
-- Configuration is included directly in this file
-- Configuration variables
-- Weapon-specific thresholds
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
    }
}

local config = {
    -- General detection settings
    CONFIDENCE_THRESHOLD = 0.65,        -- Overall confidence threshold for triggering warnings
    MIN_SAMPLES_REQUIRED = 15,          -- Minimum samples needed before detection
    DETECTION_INTERVAL = 5000,          -- Time between detection runs (ms)
    
    -- Angle change detection
    ANGLE_CHANGE_THRESHOLD = 150,       -- Suspicious angle change threshold (degrees)
    MAX_ANGLE_CHANGE = 180,             -- Maximum angle change to consider (degrees)
    
    -- Accuracy detection
    ACCURACY_THRESHOLD = 0.8,           -- Base accuracy threshold
    HEADSHOT_RATIO_THRESHOLD = 0.7,     -- Base headshot ratio threshold
    
    -- Consecutive hits detection
    CONSECUTIVE_HITS_THRESHOLD = 10,    -- Suspicious consecutive hits
    
    -- Advanced detection options
    PATTERN_DETECTION = true,           -- Enable pattern detection
    MICRO_MOVEMENT_DETECTION = true,    -- Enable micro-movement detection for humanized aimbots
    TIME_SERIES_ANALYSIS = true,        -- Enable time-series analysis
    
    -- Micro-movement detection settings
    MICRO_MOVEMENT_MIN_COUNT = 5,       -- Minimum number of micro-movements to be suspicious
    MICRO_MOVEMENT_MIN_SEQUENCE = 3,    -- Minimum sequence length of consecutive micro-movements
    MICRO_MOVEMENT_MAX_STDDEV = 5,      -- Maximum standard deviation for suspicious micro-movements
    
    -- Flick pattern analysis settings
    FLICK_ANGLE_THRESHOLD = 100,        -- Angle change threshold to consider as a flick (degrees)
    FLICK_ADJUSTMENT_MIN = 5,           -- Minimum post-flick adjustment for human-like behavior
    FLICK_ADJUSTMENT_MAX = 30,          -- Maximum post-flick adjustment for human-like behavior
    QUICK_HIT_THRESHOLD = 100,          -- Maximum time (ms) between flick and hit to be suspicious
    
    -- Time-series analysis settings
    TIME_SERIES_THRESHOLD = 0.6,        -- Threshold for time-series analysis confidence
    MIN_SHOT_SAMPLES = 5,               -- Minimum number of shot timing samples required
    TIMING_CONSISTENCY_WEIGHT = 0.6,    -- Weight for timing consistency in time-series analysis
    PATTERN_DETECTION_WEIGHT = 0.4,     -- Weight for pattern detection in time-series analysis
    TARGET_SWITCH_THRESHOLD = 0.5,      -- Threshold for suspicious target switching patterns
    MIN_TARGET_SWITCHES = 5,            -- Minimum number of target switches needed for analysis
    
    -- Weapon-specific settings
    WEAPON_SPECIFIC_THRESHOLDS = true,  -- Enable weapon-specific thresholds
    WEAPON_STATS_MIN_SAMPLES = 10,      -- Minimum samples needed for weapon-specific detection
    WEAPON_ACCURACY_WEIGHT = 0.7,       -- Weight for weapon-specific accuracy in detection
    WEAPON_HEADSHOT_WEIGHT = 0.8,       -- Weight for weapon-specific headshot ratio in detection
    
    -- Warning and ban settings
    WARN_THRESHOLD = 1,                 -- Number of warnings before notifying player
    MAX_WARNINGS = 3,                   -- Number of warnings before ban
    ENABLE_BANS = true,                 -- Enable automatic banning
    BAN_DURATION = 7,                   -- Ban duration in days
    PERMANENT_BAN_THRESHOLD = 3,        -- Number of temporary bans before permanent ban
    WARNING_COOLDOWN = 300000,          -- Cooldown between warnings (ms) - 5 minutes
    USE_SHRUBBOT_BANS = true,           -- Use shrubbot ban system if available
    NOTIFY_ADMINS = true,               -- Notify admins of suspicious activity
    
    -- Logging settings
    LOG_LEVEL = 2,                      -- 0: None, 1: Minimal, 2: Detailed, 3: Debug
    LOG_FILE = "aimbot_detector.log",   -- Log file name
    LOG_DIR = "logs",                   -- Directory to store log files
    LOG_STATS_INTERVAL = 300000,        -- How often to log player stats (ms) - 5 minutes
    LOG_ROTATION = true,                -- Enable log rotation
    LOG_MAX_SIZE = 5242880,             -- Maximum log file size before rotation (5MB)
    LOG_MAX_FILES = 5,                  -- Maximum number of rotated log files to keep
    
    -- Enable/disable specific detection methods
    DETECT_ANGLE_CHANGES = true,        -- Detect suspicious angle changes
    DETECT_HEADSHOT_RATIO = true,       -- Detect suspicious headshot ratio
    DETECT_ACCURACY = true,             -- Detect suspicious accuracy
    DETECT_CONSECUTIVE_HITS = true,     -- Detect suspicious consecutive hits
    
    -- Debug options
    DEBUG_MODE = true,                  -- Enable/disable debug logging to file
    DEBUG_LEVEL = 3,                    -- Debug level: 1=basic, 2=detailed, 3=verbose
    SERVER_CONSOLE_DEBUG = true,        -- Enable/disable debug printing to server console
    SERVER_CONSOLE_DEBUG_LEVEL = 2,     -- Debug level for server console
    
    -- Other options
    IGNORE_OMNIBOTS = true,             -- Skip detection for OMNIBOT players
    CHAT_WARNINGS = true,               -- Show warnings in player chat
    
    -- Skill level adaptation
    SKILL_ADAPTATION = true,            -- Enable skill level adaptation
    SKILL_CONFIDENCE_ADJUSTMENT = true, -- Adjust confidence scores based on skill level
    SKILL_THRESHOLD_ADJUSTMENT = true,  -- Adjust detection thresholds based on skill level
    SKILL_XP_UPDATE_INTERVAL = 60000,   -- How often to update player XP (ms)
    SKILL_LEVELS = {                    -- Skill level thresholds
        NOVICE = 0,                     -- 0-999 XP
        REGULAR = 1000,                 -- 1000-4999 XP
        SKILLED = 5000,                 -- 5000-9999 XP
        EXPERT = 10000                  -- 10000+ XP
    },
    SKILL_ADJUSTMENTS = {               -- Threshold adjustments based on skill level
        NOVICE = { accuracy = 0.0, headshot = 0.0 },
        REGULAR = { accuracy = 0.05, headshot = 0.05 },
        SKILLED = { accuracy = 0.1, headshot = 0.1 },
        EXPERT = { accuracy = 0.15, headshot = 0.15 }
    }
}

-- Player data storage
local players = {}


-- Initialize global functions
-- debugLog function is defined directly in this file
-- log function is defined directly in this file

-- Load common functions
-- Common functions are included directly in this file

-- Initialize global functions
-- initPlayerData function is defined directly in this file
-- updatePlayerAngles function is defined directly in this file

-- Initialize the script
function et_InitGame(levelTime, randomSeed, restart)
    et.G_Print("^3ETAimbotDetector^7 v1.0 loaded\n")
    et.G_Print("^3ETAimbotDetector^7: Monitoring for suspicious aim patterns\n")
    
    -- Create log directory
    ensureLogDirExists()
    
    -- Log initialization
    logStartup()
end

-- Script information
function et_PrintModuleInformation()
    et.G_Print("^3ETAimbotDetector^7 v1.0 - Advanced aimbot detection for ET:Legacy\n")
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
    
    -- Initialize detection variables
    local totalConfidence = 0
    local detectionCount = 0
    local reasons = {}
    
    -- Enhance detection with micro-movement analysis
    totalConfidence, detectionCount, reasons = enhanceDetectionWithMicroMovements(
        clientNum, totalConfidence, detectionCount, reasons)
    
    -- Enhance detection with flick pattern analysis
    totalConfidence, detectionCount, reasons = enhanceDetectionWithFlickAnalysis(
        clientNum, totalConfidence, detectionCount, reasons)
    
    -- Enhance detection with time-series analysis
    totalConfidence, detectionCount, reasons = enhanceDetectionWithTimeSeriesAnalysis(
        clientNum, totalConfidence, detectionCount, reasons)
    
    -- Enhance detection with weapon-specific thresholds
    totalConfidence, detectionCount, reasons = enhanceDetectionWithWeaponThresholds(
        clientNum, totalConfidence, detectionCount, reasons)
    
    -- Calculate average confidence
    local avgConfidence = 0
    if detectionCount > 0 then
        avgConfidence = totalConfidence / detectionCount
    end
    
    -- Adjust confidence based on skill level
    local suspiciousActivity = avgConfidence >= config.CONFIDENCE_THRESHOLD
    suspiciousActivity, avgConfidence = enhanceDetectionWithSkillAdaptation(
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
end

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
        logDetection(player, confidence, detectionCount, aimbotType, reason)
        
        -- Check if player should be warned
        checkForWarning(clientNum, confidence, detectionCount, reason)
    else
        debugLog("runDetection: No aimbot detected for " .. player.name .. " - confidence: " .. confidence .. ", detections: " .. detectionCount, 2)
    end
end

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
                logPlayerStats(player)
                player.lastStatsLogTime = currentTime
            end
        end
    end
end

-- Script is now loaded and ready
et.G_Print("^3ETAimbotDetector^7: All modules loaded successfully\n")
scripts/aimbot/common.lua:-- ETAimbotDetector - Common Functions Module
scripts/aimbot/common.lua:-- Common utility functions for the aimbot detection system
scripts/aimbot/common.lua:
scripts/aimbot/common.lua:-- Check if player is an OMNIBOT
scripts/aimbot/common.lua:local function isOmniBot(guid)
scripts/aimbot/common.lua:    if not guid then return false end
scripts/aimbot/common.lua:    return string.find(string.lower(guid), "omnibot") ~= nil
scripts/aimbot/common.lua:end
scripts/aimbot/common.lua:
scripts/aimbot/common.lua:-- Initialize player data
scripts/aimbot/common.lua:local function initPlayerData(clientNum)
scripts/aimbot/common.lua:    local userinfo = et.trap_GetUserinfo(clientNum)
scripts/aimbot/common.lua:    local name = et.Info_ValueForKey(userinfo, "name")
scripts/aimbot/common.lua:    local guid = et.Info_ValueForKey(userinfo, "cl_guid")
scripts/aimbot/common.lua:    local ip = et.Info_ValueForKey(userinfo, "ip")
scripts/aimbot/common.lua:    
scripts/aimbot/common.lua:    players[clientNum] = {
scripts/aimbot/common.lua:        name = name,
scripts/aimbot/common.lua:        guid = guid,
scripts/aimbot/common.lua:        ip = ip,
scripts/aimbot/common.lua:        
scripts/aimbot/common.lua:        -- Tracking variables
scripts/aimbot/common.lua:        lastAngle = {pitch = 0, yaw = 0},
scripts/aimbot/common.lua:        angleChanges = {},
scripts/aimbot/common.lua:        angleChangePatterns = {},
scripts/aimbot/common.lua:        shots = 0,
scripts/aimbot/common.lua:        hits = 0,
scripts/aimbot/common.lua:        headshots = 0,
scripts/aimbot/common.lua:        kills = 0,
scripts/aimbot/common.lua:        consecutiveHits = 0,
scripts/aimbot/common.lua:        
scripts/aimbot/common.lua:        -- Weapon-specific stats
scripts/aimbot/common.lua:        weaponStats = {},
scripts/aimbot/common.lua:        lastWeapon = "default",
scripts/aimbot/common.lua:        
scripts/aimbot/common.lua:        -- Time-based tracking
scripts/aimbot/common.lua:        lastDetectionTime = 0,
scripts/aimbot/common.lua:        lastShotTime = 0,
scripts/aimbot/common.lua:        reactionTimes = {},
scripts/aimbot/common.lua:        shotTimings = {},
scripts/aimbot/common.lua:        hitTimings = {},
scripts/aimbot/common.lua:        
scripts/aimbot/common.lua:        -- Target tracking
scripts/aimbot/common.lua:        lastTarget = -1,
scripts/aimbot/common.lua:        lastTargetTime = 0,
scripts/aimbot/common.lua:        targetSwitches = {},
scripts/aimbot/common.lua:        
scripts/aimbot/common.lua:        -- Statistical data
scripts/aimbot/common.lua:        avgAngleChange = 0,
scripts/aimbot/common.lua:        stdDevAngleChange = 0,
scripts/aimbot/common.lua:        
scripts/aimbot/common.lua:        -- Warning system
scripts/aimbot/common.lua:        warnings = 0,
scripts/aimbot/common.lua:        lastWarningTime = 0,
scripts/aimbot/common.lua:        
scripts/aimbot/common.lua:        -- Ban history
scripts/aimbot/common.lua:        tempBans = 0,
scripts/aimbot/common.lua:        
scripts/aimbot/common.lua:        -- Detection confidence
scripts/aimbot/common.lua:        aimbotConfidence = 0,
scripts/aimbot/common.lua:        humanizedAimbotConfidence = 0,
scripts/aimbot/common.lua:        
scripts/aimbot/common.lua:        -- Skill tracking
scripts/aimbot/common.lua:        xp = 0,
scripts/aimbot/common.lua:        rank = 0
scripts/aimbot/common.lua:    }
scripts/aimbot/common.lua:    
scripts/aimbot/common.lua:    debugLog("Player initialized: " .. name .. " (GUID: " .. guid .. ")")
scripts/aimbot/common.lua:end
scripts/aimbot/common.lua:
scripts/aimbot/common.lua:-- Update player angles
scripts/aimbot/common.lua:local function updatePlayerAngles(clientNum)
scripts/aimbot/common.lua:    local player = players[clientNum]
scripts/aimbot/common.lua:    if not player then return end
scripts/aimbot/common.lua:    
scripts/aimbot/common.lua:    -- Get current view angles
scripts/aimbot/common.lua:    local ps = et.gentity_get(clientNum, "ps.viewangles")
scripts/aimbot/common.lua:    if not ps then return end
scripts/aimbot/common.lua:    
scripts/aimbot/common.lua:    local currentAngle = {
scripts/aimbot/common.lua:        pitch = ps[0],
scripts/aimbot/common.lua:        yaw = ps[1]
scripts/aimbot/common.lua:    }
scripts/aimbot/common.lua:    
scripts/aimbot/common.lua:    -- Calculate angle change
scripts/aimbot/common.lua:    local angleChange = {
scripts/aimbot/common.lua:        pitch = math.abs(currentAngle.pitch - player.lastAngle.pitch),
scripts/aimbot/common.lua:        yaw = math.abs(currentAngle.yaw - player.lastAngle.yaw)
scripts/aimbot/common.lua:    }
scripts/aimbot/common.lua:    
scripts/aimbot/common.lua:    -- Normalize yaw angle change (handle 359° -> 0° transitions)
scripts/aimbot/common.lua:    if angleChange.yaw > 180 then
scripts/aimbot/common.lua:        angleChange.yaw = 360 - angleChange.yaw
scripts/aimbot/common.lua:    end
scripts/aimbot/common.lua:    
scripts/aimbot/common.lua:    -- Calculate total angle change
scripts/aimbot/common.lua:    local totalAngleChange = math.sqrt(angleChange.pitch^2 + angleChange.yaw^2)
scripts/aimbot/common.lua:    
scripts/aimbot/common.lua:    -- Store angle change if it's within reasonable limits
scripts/aimbot/common.lua:    if totalAngleChange <= config.MAX_ANGLE_CHANGE then
scripts/aimbot/common.lua:        table.insert(player.angleChanges, totalAngleChange)
scripts/aimbot/common.lua:        
scripts/aimbot/common.lua:        -- Keep only the last 50 angle changes
scripts/aimbot/common.lua:        if #player.angleChanges > 50 then
scripts/aimbot/common.lua:            table.remove(player.angleChanges, 1)
scripts/aimbot/common.lua:        end
scripts/aimbot/common.lua:    end
scripts/aimbot/common.lua:    
scripts/aimbot/common.lua:    -- Update last angle
scripts/aimbot/common.lua:    player.lastAngle = currentAngle
scripts/aimbot/common.lua:end
scripts/aimbot/common.lua:
scripts/aimbot/common.lua:-- Export functions
scripts/aimbot/common.lua:    isOmniBot = isOmniBot,
scripts/aimbot/common.lua:    initPlayerData = initPlayerData,
scripts/aimbot/common.lua:    updatePlayerAngles = updatePlayerAngles
scripts/aimbot/common.lua:}
scripts/aimbot/config.lua:-- ETAimbotDetector - Configuration Module
scripts/aimbot/config.lua:-- Configuration settings for the aimbot detection system
scripts/aimbot/config.lua:-- This module contains all configurable parameters and thresholds
scripts/aimbot/config.lua:
scripts/aimbot/config.lua:-- Configuration variables
scripts/aimbot/config.lua:-- Weapon-specific thresholds
scripts/aimbot/config.lua:local weaponThresholds = {
scripts/aimbot/config.lua:    -- Default thresholds
scripts/aimbot/config.lua:    default = {
scripts/aimbot/config.lua:        accuracy = 0.75,              -- Base accuracy threshold
scripts/aimbot/config.lua:        headshot = 0.65,              -- Base headshot ratio threshold
scripts/aimbot/config.lua:        angleChange = 160             -- Base angle change threshold
scripts/aimbot/config.lua:    },
scripts/aimbot/config.lua:    -- Sniper rifles (high accuracy expected)
scripts/aimbot/config.lua:    weapon_K43 = {
scripts/aimbot/config.lua:        accuracy = 0.85,
scripts/aimbot/config.lua:        headshot = 0.8,
scripts/aimbot/config.lua:        angleChange = 175
scripts/aimbot/config.lua:    },
scripts/aimbot/config.lua:    weapon_K43_scope = {
scripts/aimbot/config.lua:        accuracy = 0.9,
scripts/aimbot/config.lua:        headshot = 0.85,
scripts/aimbot/config.lua:        angleChange = 175
scripts/aimbot/config.lua:    },
scripts/aimbot/config.lua:    weapon_FG42Scope = {
scripts/aimbot/config.lua:        accuracy = 0.85,
scripts/aimbot/config.lua:        headshot = 0.8,
scripts/aimbot/config.lua:        angleChange = 175
scripts/aimbot/config.lua:    },
scripts/aimbot/config.lua:    -- Automatic weapons (medium accuracy expected)
scripts/aimbot/config.lua:    weapon_MP40 = {
scripts/aimbot/config.lua:        accuracy = 0.7,
scripts/aimbot/config.lua:        headshot = 0.6,
scripts/aimbot/config.lua:        angleChange = 160
scripts/aimbot/config.lua:    },
scripts/aimbot/config.lua:    weapon_Thompson = {
scripts/aimbot/config.lua:        accuracy = 0.7,
scripts/aimbot/config.lua:        headshot = 0.6,
scripts/aimbot/config.lua:        angleChange = 160
scripts/aimbot/config.lua:    },
scripts/aimbot/config.lua:    weapon_Sten = {
scripts/aimbot/config.lua:        accuracy = 0.7,
scripts/aimbot/config.lua:        headshot = 0.6,
scripts/aimbot/config.lua:        angleChange = 160
scripts/aimbot/config.lua:    },
scripts/aimbot/config.lua:    -- Pistols
scripts/aimbot/config.lua:    weapon_Luger = {
scripts/aimbot/config.lua:        accuracy = 0.8,
scripts/aimbot/config.lua:        headshot = 0.7,
scripts/aimbot/config.lua:        angleChange = 165
scripts/aimbot/config.lua:    },
scripts/aimbot/config.lua:    weapon_Colt = {
scripts/aimbot/config.lua:        accuracy = 0.8,
scripts/aimbot/config.lua:        headshot = 0.7,
scripts/aimbot/config.lua:        angleChange = 165
scripts/aimbot/config.lua:    }
scripts/aimbot/config.lua:}
scripts/aimbot/config.lua:
scripts/aimbot/config.lua:local config = {
scripts/aimbot/config.lua:    -- General detection settings
scripts/aimbot/config.lua:    CONFIDENCE_THRESHOLD = 0.65,        -- Overall confidence threshold for triggering warnings
scripts/aimbot/config.lua:    MIN_SAMPLES_REQUIRED = 15,          -- Minimum samples needed before detection
scripts/aimbot/config.lua:    DETECTION_INTERVAL = 5000,          -- Time between detection runs (ms)
scripts/aimbot/config.lua:    
scripts/aimbot/config.lua:    -- Angle change detection
scripts/aimbot/config.lua:    ANGLE_CHANGE_THRESHOLD = 150,       -- Suspicious angle change threshold (degrees)
scripts/aimbot/config.lua:    MAX_ANGLE_CHANGE = 180,             -- Maximum angle change to consider (degrees)
scripts/aimbot/config.lua:    
scripts/aimbot/config.lua:    -- Accuracy detection
scripts/aimbot/config.lua:    ACCURACY_THRESHOLD = 0.8,           -- Base accuracy threshold
scripts/aimbot/config.lua:    HEADSHOT_RATIO_THRESHOLD = 0.7,     -- Base headshot ratio threshold
scripts/aimbot/config.lua:    
scripts/aimbot/config.lua:    -- Consecutive hits detection
scripts/aimbot/config.lua:    CONSECUTIVE_HITS_THRESHOLD = 10,    -- Suspicious consecutive hits
scripts/aimbot/config.lua:    
scripts/aimbot/config.lua:    -- Advanced detection options
scripts/aimbot/config.lua:    PATTERN_DETECTION = true,           -- Enable pattern detection
scripts/aimbot/config.lua:    MICRO_MOVEMENT_DETECTION = true,    -- Enable micro-movement detection for humanized aimbots
scripts/aimbot/config.lua:    TIME_SERIES_ANALYSIS = true,        -- Enable time-series analysis
scripts/aimbot/config.lua:    
scripts/aimbot/config.lua:    -- Micro-movement detection settings
scripts/aimbot/config.lua:    MICRO_MOVEMENT_MIN_COUNT = 5,       -- Minimum number of micro-movements to be suspicious
scripts/aimbot/config.lua:    MICRO_MOVEMENT_MIN_SEQUENCE = 3,    -- Minimum sequence length of consecutive micro-movements
scripts/aimbot/config.lua:    MICRO_MOVEMENT_MAX_STDDEV = 5,      -- Maximum standard deviation for suspicious micro-movements
scripts/aimbot/config.lua:    
scripts/aimbot/config.lua:    -- Flick pattern analysis settings
scripts/aimbot/config.lua:    FLICK_ANGLE_THRESHOLD = 100,        -- Angle change threshold to consider as a flick (degrees)
scripts/aimbot/config.lua:    FLICK_ADJUSTMENT_MIN = 5,           -- Minimum post-flick adjustment for human-like behavior
scripts/aimbot/config.lua:    FLICK_ADJUSTMENT_MAX = 30,          -- Maximum post-flick adjustment for human-like behavior
scripts/aimbot/config.lua:    QUICK_HIT_THRESHOLD = 100,          -- Maximum time (ms) between flick and hit to be suspicious
scripts/aimbot/config.lua:    
scripts/aimbot/config.lua:    -- Time-series analysis settings
scripts/aimbot/config.lua:    TIME_SERIES_THRESHOLD = 0.6,        -- Threshold for time-series analysis confidence
scripts/aimbot/config.lua:    MIN_SHOT_SAMPLES = 5,               -- Minimum number of shot timing samples required
scripts/aimbot/config.lua:    TIMING_CONSISTENCY_WEIGHT = 0.6,    -- Weight for timing consistency in time-series analysis
scripts/aimbot/config.lua:    PATTERN_DETECTION_WEIGHT = 0.4,     -- Weight for pattern detection in time-series analysis
scripts/aimbot/config.lua:    TARGET_SWITCH_THRESHOLD = 0.5,      -- Threshold for suspicious target switching patterns
scripts/aimbot/config.lua:    MIN_TARGET_SWITCHES = 5,            -- Minimum number of target switches needed for analysis
scripts/aimbot/config.lua:    
scripts/aimbot/config.lua:    -- Weapon-specific settings
scripts/aimbot/config.lua:    WEAPON_SPECIFIC_THRESHOLDS = true,  -- Enable weapon-specific thresholds
scripts/aimbot/config.lua:    WEAPON_STATS_MIN_SAMPLES = 10,      -- Minimum samples needed for weapon-specific detection
scripts/aimbot/config.lua:    WEAPON_ACCURACY_WEIGHT = 0.7,       -- Weight for weapon-specific accuracy in detection
scripts/aimbot/config.lua:    WEAPON_HEADSHOT_WEIGHT = 0.8,       -- Weight for weapon-specific headshot ratio in detection
scripts/aimbot/config.lua:    
scripts/aimbot/config.lua:    -- Warning and ban settings
scripts/aimbot/config.lua:    WARN_THRESHOLD = 1,                 -- Number of warnings before notifying player
scripts/aimbot/config.lua:    MAX_WARNINGS = 3,                   -- Number of warnings before ban
scripts/aimbot/config.lua:    ENABLE_BANS = true,                 -- Enable automatic banning
scripts/aimbot/config.lua:    BAN_DURATION = 7,                   -- Ban duration in days
scripts/aimbot/config.lua:    PERMANENT_BAN_THRESHOLD = 3,        -- Number of temporary bans before permanent ban
scripts/aimbot/config.lua:    WARNING_COOLDOWN = 300000,          -- Cooldown between warnings (ms) - 5 minutes
scripts/aimbot/config.lua:    USE_SHRUBBOT_BANS = true,           -- Use shrubbot ban system if available
scripts/aimbot/config.lua:    NOTIFY_ADMINS = true,               -- Notify admins of suspicious activity
scripts/aimbot/config.lua:    
scripts/aimbot/config.lua:    -- Logging settings
scripts/aimbot/config.lua:    LOG_LEVEL = 2,                      -- 0: None, 1: Minimal, 2: Detailed, 3: Debug
scripts/aimbot/config.lua:    LOG_FILE = "aimbot_detector.log",   -- Log file name
scripts/aimbot/config.lua:    LOG_DIR = "logs",                   -- Directory to store log files
scripts/aimbot/config.lua:    LOG_STATS_INTERVAL = 300000,        -- How often to log player stats (ms) - 5 minutes
scripts/aimbot/config.lua:    LOG_ROTATION = true,                -- Enable log rotation
scripts/aimbot/config.lua:    LOG_MAX_SIZE = 5242880,             -- Maximum log file size before rotation (5MB)
scripts/aimbot/config.lua:    LOG_MAX_FILES = 5,                  -- Maximum number of rotated log files to keep
scripts/aimbot/config.lua:    
scripts/aimbot/config.lua:    -- Enable/disable specific detection methods
scripts/aimbot/config.lua:    DETECT_ANGLE_CHANGES = true,        -- Detect suspicious angle changes
scripts/aimbot/config.lua:    DETECT_HEADSHOT_RATIO = true,       -- Detect suspicious headshot ratio
scripts/aimbot/config.lua:    DETECT_ACCURACY = true,             -- Detect suspicious accuracy
scripts/aimbot/config.lua:    DETECT_CONSECUTIVE_HITS = true,     -- Detect suspicious consecutive hits
scripts/aimbot/config.lua:    
scripts/aimbot/config.lua:    -- Debug options
scripts/aimbot/config.lua:    DEBUG_MODE = true,                  -- Enable/disable debug logging to file
scripts/aimbot/config.lua:    DEBUG_LEVEL = 3,                    -- Debug level: 1=basic, 2=detailed, 3=verbose
scripts/aimbot/config.lua:    SERVER_CONSOLE_DEBUG = true,        -- Enable/disable debug printing to server console
scripts/aimbot/config.lua:    SERVER_CONSOLE_DEBUG_LEVEL = 2,     -- Debug level for server console
scripts/aimbot/config.lua:    
scripts/aimbot/config.lua:    -- Other options
scripts/aimbot/config.lua:    IGNORE_OMNIBOTS = true,             -- Skip detection for OMNIBOT players
scripts/aimbot/config.lua:    CHAT_WARNINGS = true,               -- Show warnings in player chat
scripts/aimbot/config.lua:    
scripts/aimbot/config.lua:    -- Skill level adaptation
scripts/aimbot/config.lua:    SKILL_ADAPTATION = true,            -- Enable skill level adaptation
scripts/aimbot/config.lua:    SKILL_CONFIDENCE_ADJUSTMENT = true, -- Adjust confidence scores based on skill level
scripts/aimbot/config.lua:    SKILL_THRESHOLD_ADJUSTMENT = true,  -- Adjust detection thresholds based on skill level
scripts/aimbot/config.lua:    SKILL_XP_UPDATE_INTERVAL = 60000,   -- How often to update player XP (ms)
scripts/aimbot/config.lua:    SKILL_LEVELS = {                    -- Skill level thresholds
scripts/aimbot/config.lua:        NOVICE = 0,                     -- 0-999 XP
scripts/aimbot/config.lua:        REGULAR = 1000,                 -- 1000-4999 XP
scripts/aimbot/config.lua:        SKILLED = 5000,                 -- 5000-9999 XP
scripts/aimbot/config.lua:        EXPERT = 10000                  -- 10000+ XP
scripts/aimbot/config.lua:    },
scripts/aimbot/config.lua:    SKILL_ADJUSTMENTS = {               -- Threshold adjustments based on skill level
scripts/aimbot/config.lua:        NOVICE = { accuracy = 0.0, headshot = 0.0 },
scripts/aimbot/config.lua:        REGULAR = { accuracy = 0.05, headshot = 0.05 },
scripts/aimbot/config.lua:        SKILLED = { accuracy = 0.1, headshot = 0.1 },
scripts/aimbot/config.lua:        EXPERT = { accuracy = 0.15, headshot = 0.15 }
scripts/aimbot/config.lua:    }
scripts/aimbot/config.lua:}
scripts/aimbot/config.lua:
scripts/aimbot/config.lua:-- Initialize global variables
scripts/aimbot/config.lua:players = {}
scripts/aimbot/config.lua:weaponThresholds = weaponThresholds
scripts/aimbot/config.lua:config = config
scripts/aimbot/config.lua:
scripts/aimbot/config.lua:-- Export configuration
scripts/aimbot/config.lua:    players = players,
scripts/aimbot/config.lua:    weaponThresholds = weaponThresholds,
scripts/aimbot/config.lua:    config = config
scripts/aimbot/config.lua:}
scripts/aimbot/flick_analysis.lua:-- Flick pattern analysis for aimbot detection
scripts/aimbot/flick_analysis.lua:-- This module implements detection for distinguishing between legitimate flicks and aimbot snaps
scripts/aimbot/flick_analysis.lua:
scripts/aimbot/flick_analysis.lua:-- Detect flick shot patterns with timing analysis
scripts/aimbot/flick_analysis.lua:local function detectFlickPattern(clientNum)
scripts/aimbot/flick_analysis.lua:    local player = players[clientNum]
scripts/aimbot/flick_analysis.lua:    if not player or #player.angleChanges < 10 then return false, 0 end
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    local flicks = 0
scripts/aimbot/flick_analysis.lua:    local adjustments = 0
scripts/aimbot/flick_analysis.lua:    local suspiciousFlicks = 0
scripts/aimbot/flick_analysis.lua:    local quickHitFlicks = 0
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    -- Analyze angle change patterns
scripts/aimbot/flick_analysis.lua:    for i = 2, #player.angleChanges - 1 do
scripts/aimbot/flick_analysis.lua:        -- Detect large angle changes (flicks)
scripts/aimbot/flick_analysis.lua:        if player.angleChanges[i] > 100 then
scripts/aimbot/flick_analysis.lua:            flicks = flicks + 1
scripts/aimbot/flick_analysis.lua:            
scripts/aimbot/flick_analysis.lua:            -- Check for post-flick adjustments (human behavior)
scripts/aimbot/flick_analysis.lua:            if player.angleChanges[i+1] >= 5 and player.angleChanges[i+1] <= 30 then
scripts/aimbot/flick_analysis.lua:                adjustments = adjustments + 1
scripts/aimbot/flick_analysis.lua:            else
scripts/aimbot/flick_analysis.lua:                suspiciousFlicks = suspiciousFlicks + 1
scripts/aimbot/flick_analysis.lua:            end
scripts/aimbot/flick_analysis.lua:            
scripts/aimbot/flick_analysis.lua:            -- Check if this flick resulted in a quick hit
scripts/aimbot/flick_analysis.lua:            if player.shotTimings and player.hitTimings and 
scripts/aimbot/flick_analysis.lua:               i <= #player.shotTimings and i <= #player.hitTimings then
scripts/aimbot/flick_analysis.lua:                -- If time between angle change and hit is very small, it's suspicious
scripts/aimbot/flick_analysis.lua:                local timeToHit = player.hitTimings[i] - player.shotTimings[i]
scripts/aimbot/flick_analysis.lua:                if timeToHit >= 0 and timeToHit < 100 then -- Less than 100ms is very fast
scripts/aimbot/flick_analysis.lua:                    quickHitFlicks = quickHitFlicks + 1
scripts/aimbot/flick_analysis.lua:                    debugLog("Flick pattern analysis: Quick hit detected - angle change to hit time: " .. timeToHit .. "ms", 3)
scripts/aimbot/flick_analysis.lua:                end
scripts/aimbot/flick_analysis.lua:            end
scripts/aimbot/flick_analysis.lua:        end
scripts/aimbot/flick_analysis.lua:    end
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    -- Calculate ratio of suspicious flicks to total flicks
scripts/aimbot/flick_analysis.lua:    local suspiciousRatio = 0
scripts/aimbot/flick_analysis.lua:    local quickHitRatio = 0
scripts/aimbot/flick_analysis.lua:    if flicks > 0 then
scripts/aimbot/flick_analysis.lua:        suspiciousRatio = suspiciousFlicks / flicks
scripts/aimbot/flick_analysis.lua:        quickHitRatio = quickHitFlicks / flicks
scripts/aimbot/flick_analysis.lua:    end
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    debugLog("Flick pattern analysis: " .. player.name .. " - flicks=" .. flicks .. 
scripts/aimbot/flick_analysis.lua:        ", adjustments=" .. adjustments .. ", suspicious=" .. suspiciousFlicks .. 
scripts/aimbot/flick_analysis.lua:        ", quickHits=" .. quickHitFlicks ..
scripts/aimbot/flick_analysis.lua:        ", suspiciousRatio=" .. suspiciousRatio .. 
scripts/aimbot/flick_analysis.lua:        ", quickHitRatio=" .. quickHitRatio, 2)
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    -- Detect suspicious patterns
scripts/aimbot/flick_analysis.lua:    local isDetected = false
scripts/aimbot/flick_analysis.lua:    local confidence = 0
scripts/aimbot/flick_analysis.lua:    local reason = ""
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    -- Check for quick hit flicks (as requested by user)
scripts/aimbot/flick_analysis.lua:    if quickHitRatio > 0.5 and flicks >= 3 then
scripts/aimbot/flick_analysis.lua:        confidence = quickHitRatio - 0.5
scripts/aimbot/flick_analysis.lua:        reason = string.format("Suspicious quick-hit flicks (%.2f of flicks resulted in immediate hits)", quickHitRatio)
scripts/aimbot/flick_analysis.lua:        isDetected = true
scripts/aimbot/flick_analysis.lua:    -- Check for suspicious flick patterns
scripts/aimbot/flick_analysis.lua:    elseif suspiciousRatio > 0.7 and flicks >= 3 then
scripts/aimbot/flick_analysis.lua:        confidence = suspiciousRatio - 0.7
scripts/aimbot/flick_analysis.lua:        reason = string.format("Suspicious flick pattern (%.2f of flicks without human-like adjustments)", suspiciousRatio)
scripts/aimbot/flick_analysis.lua:        isDetected = true
scripts/aimbot/flick_analysis.lua:    end
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    if isDetected then
scripts/aimbot/flick_analysis.lua:        return true, confidence, reason
scripts/aimbot/flick_analysis.lua:    end
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    return false, 0
scripts/aimbot/flick_analysis.lua:end
scripts/aimbot/flick_analysis.lua:
scripts/aimbot/flick_analysis.lua:-- Analyze flick timing to detect suspicious patterns
scripts/aimbot/flick_analysis.lua:local function analyzeFlickTiming(clientNum)
scripts/aimbot/flick_analysis.lua:    local player = players[clientNum]
scripts/aimbot/flick_analysis.lua:    if not player or #player.angleChanges < 10 then return false, 0 end
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    local flickTimings = {}
scripts/aimbot/flick_analysis.lua:    local lastFlickTime = 0
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    -- Collect timings between flicks
scripts/aimbot/flick_analysis.lua:    for i = 2, #player.angleChanges do
scripts/aimbot/flick_analysis.lua:        if player.angleChanges[i] > 100 then
scripts/aimbot/flick_analysis.lua:            local currentTime = et.trap_Milliseconds()
scripts/aimbot/flick_analysis.lua:            
scripts/aimbot/flick_analysis.lua:            if lastFlickTime > 0 then
scripts/aimbot/flick_analysis.lua:                local timeBetweenFlicks = currentTime - lastFlickTime
scripts/aimbot/flick_analysis.lua:                table.insert(flickTimings, timeBetweenFlicks)
scripts/aimbot/flick_analysis.lua:            end
scripts/aimbot/flick_analysis.lua:            
scripts/aimbot/flick_analysis.lua:            lastFlickTime = currentTime
scripts/aimbot/flick_analysis.lua:        end
scripts/aimbot/flick_analysis.lua:    end
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    -- Need at least 3 flick timings to analyze
scripts/aimbot/flick_analysis.lua:    if #flickTimings < 3 then
scripts/aimbot/flick_analysis.lua:        return false, 0
scripts/aimbot/flick_analysis.lua:    end
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    -- Calculate average and standard deviation
scripts/aimbot/flick_analysis.lua:    local sum = 0
scripts/aimbot/flick_analysis.lua:    for _, timing in ipairs(flickTimings) do
scripts/aimbot/flick_analysis.lua:        sum = sum + timing
scripts/aimbot/flick_analysis.lua:    end
scripts/aimbot/flick_analysis.lua:    local avg = sum / #flickTimings
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    local sumSquares = 0
scripts/aimbot/flick_analysis.lua:    for _, timing in ipairs(flickTimings) do
scripts/aimbot/flick_analysis.lua:        sumSquares = sumSquares + (timing - avg)^2
scripts/aimbot/flick_analysis.lua:    end
scripts/aimbot/flick_analysis.lua:    local stdDev = math.sqrt(sumSquares / (#flickTimings - 1))
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    -- Calculate coefficient of variation (normalized standard deviation)
scripts/aimbot/flick_analysis.lua:    local cv = stdDev / avg
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    debugLog("analyzeFlickTiming: " .. player.name .. " - flick timings=" .. #flickTimings .. 
scripts/aimbot/flick_analysis.lua:             ", avg=" .. avg .. "ms, stdDev=" .. stdDev .. "ms, cv=" .. cv, 2)
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    -- Extremely consistent flick timing is suspicious (low coefficient of variation)
scripts/aimbot/flick_analysis.lua:    if cv < 0.2 and #flickTimings >= 5 then
scripts/aimbot/flick_analysis.lua:        local confidence = 0.8
scripts/aimbot/flick_analysis.lua:        return true, confidence, string.format("Suspicious flick timing consistency (cv: %.2f)", cv)
scripts/aimbot/flick_analysis.lua:    elseif cv < 0.3 and #flickTimings >= 4 then
scripts/aimbot/flick_analysis.lua:        local confidence = 0.6
scripts/aimbot/flick_analysis.lua:        return true, confidence, string.format("Moderately suspicious flick timing (cv: %.2f)", cv)
scripts/aimbot/flick_analysis.lua:    end
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    return false, 0
scripts/aimbot/flick_analysis.lua:end
scripts/aimbot/flick_analysis.lua:
scripts/aimbot/flick_analysis.lua:-- Integrate flick pattern analysis into the main detection system
scripts/aimbot/flick_analysis.lua:local function enhanceDetectionWithFlickAnalysis(clientNum, totalConfidence, detectionCount, reasons)
scripts/aimbot/flick_analysis.lua:    local suspicious, confidence, reason = detectFlickPattern(clientNum)
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    if suspicious then
scripts/aimbot/flick_analysis.lua:        totalConfidence = totalConfidence + confidence
scripts/aimbot/flick_analysis.lua:        detectionCount = detectionCount + 1
scripts/aimbot/flick_analysis.lua:        table.insert(reasons, reason)
scripts/aimbot/flick_analysis.lua:        
scripts/aimbot/flick_analysis.lua:        debugLog("enhanceDetectionWithFlickAnalysis: Detected suspicious flick pattern for client " .. clientNum .. " with confidence " .. confidence, 1)
scripts/aimbot/flick_analysis.lua:    end
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    -- Also check flick timing
scripts/aimbot/flick_analysis.lua:    suspicious, confidence, reason = analyzeFlickTiming(clientNum)
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    if suspicious then
scripts/aimbot/flick_analysis.lua:        totalConfidence = totalConfidence + confidence
scripts/aimbot/flick_analysis.lua:        detectionCount = detectionCount + 1
scripts/aimbot/flick_analysis.lua:        table.insert(reasons, reason)
scripts/aimbot/flick_analysis.lua:        
scripts/aimbot/flick_analysis.lua:        debugLog("enhanceDetectionWithFlickAnalysis: Detected suspicious flick timing for client " .. clientNum .. " with confidence " .. confidence, 1)
scripts/aimbot/flick_analysis.lua:    end
scripts/aimbot/flick_analysis.lua:    
scripts/aimbot/flick_analysis.lua:    return totalConfidence, detectionCount, reasons
scripts/aimbot/flick_analysis.lua:end
scripts/aimbot/flick_analysis.lua:
scripts/aimbot/flick_analysis.lua:-- Export functions
scripts/aimbot/flick_analysis.lua:    detectFlickPattern = detectFlickPattern,
scripts/aimbot/flick_analysis.lua:    analyzeFlickTiming = analyzeFlickTiming,
scripts/aimbot/flick_analysis.lua:    enhanceDetectionWithFlickAnalysis = enhanceDetectionWithFlickAnalysis
scripts/aimbot/flick_analysis.lua:end
scripts/aimbot/logging.lua:-- Detailed logging system for aimbot detection
scripts/aimbot/logging.lua:-- This module implements a comprehensive logging system with configurable levels
scripts/aimbot/logging.lua:
scripts/aimbot/logging.lua:-- Ensure log directory exists (cross-platform compatible)
scripts/aimbot/logging.lua:local function ensureLogDirExists()
scripts/aimbot/logging.lua:    if not config.LOG_DIR or config.LOG_DIR == "" then
scripts/aimbot/logging.lua:        return ""
scripts/aimbot/logging.lua:    end
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    -- Check if directory exists first
scripts/aimbot/logging.lua:    local dirExists = false
scripts/aimbot/logging.lua:    local testFile = io.open(config.LOG_DIR .. "/test.tmp", "w")
scripts/aimbot/logging.lua:    if testFile then
scripts/aimbot/logging.lua:        testFile:close()
scripts/aimbot/logging.lua:        os.remove(config.LOG_DIR .. "/test.tmp")
scripts/aimbot/logging.lua:        dirExists = true
scripts/aimbot/logging.lua:    end
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    -- Create directory if it doesn't exist
scripts/aimbot/logging.lua:    if not dirExists then
scripts/aimbot/logging.lua:        -- Try platform-specific directory creation
scripts/aimbot/logging.lua:        local success
scripts/aimbot/logging.lua:        if package.config:sub(1,1) == '\\' then
scripts/aimbot/logging.lua:            -- Windows
scripts/aimbot/logging.lua:            success = os.execute('if not exist "' .. config.LOG_DIR .. '" mkdir "' .. config.LOG_DIR .. '"')
scripts/aimbot/logging.lua:        else
scripts/aimbot/logging.lua:            -- Unix/Linux/macOS
scripts/aimbot/logging.lua:            success = os.execute("mkdir -p " .. config.LOG_DIR)
scripts/aimbot/logging.lua:        end
scripts/aimbot/logging.lua:        
scripts/aimbot/logging.lua:        if not success then
scripts/aimbot/logging.lua:            et.G_Print("Warning: Failed to create log directory: " .. config.LOG_DIR .. "\n")
scripts/aimbot/logging.lua:            return ""
scripts/aimbot/logging.lua:        end
scripts/aimbot/logging.lua:    end
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    -- Add trailing slash/backslash based on platform
scripts/aimbot/logging.lua:    local separator = package.config:sub(1,1)
scripts/aimbot/logging.lua:    if config.LOG_DIR:sub(-1) ~= separator then
scripts/aimbot/logging.lua:        return config.LOG_DIR .. separator
scripts/aimbot/logging.lua:    else
scripts/aimbot/logging.lua:        return config.LOG_DIR
scripts/aimbot/logging.lua:    end
scripts/aimbot/logging.lua:end
scripts/aimbot/logging.lua:
scripts/aimbot/logging.lua:-- Standard logging function
scripts/aimbot/logging.lua:local function log(level, message)
scripts/aimbot/logging.lua:    if level <= config.LOG_LEVEL then
scripts/aimbot/logging.lua:        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
scripts/aimbot/logging.lua:        local logMessage = string.format("[%s] %s\n", timestamp, message)
scripts/aimbot/logging.lua:        
scripts/aimbot/logging.lua:        -- Print to console
scripts/aimbot/logging.lua:        et.G_Print(logMessage)
scripts/aimbot/logging.lua:        
scripts/aimbot/logging.lua:        -- Write to log file
scripts/aimbot/logging.lua:        local logDir = ensureLogDirExists()
scripts/aimbot/logging.lua:        local file = io.open(logDir .. config.LOG_FILE, "a")
scripts/aimbot/logging.lua:        if file then
scripts/aimbot/logging.lua:            file:write(logMessage)
scripts/aimbot/logging.lua:            file:close()
scripts/aimbot/logging.lua:        else
scripts/aimbot/logging.lua:            et.G_Print("Warning: Could not open log file: " .. logDir .. config.LOG_FILE .. "\n")
scripts/aimbot/logging.lua:        end
scripts/aimbot/logging.lua:    end
scripts/aimbot/logging.lua:end
scripts/aimbot/logging.lua:
scripts/aimbot/logging.lua:-- Debug logging function
scripts/aimbot/logging.lua:local function debugLog(message, level)
scripts/aimbot/logging.lua:    level = level or 1 -- Default to level 1 if not specified
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
scripts/aimbot/logging.lua:    local debugMessage = string.format("[DEBUG-%d %s] %s", level, timestamp, message)
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    -- Write to log file if debug mode is enabled
scripts/aimbot/logging.lua:    if config.DEBUG_MODE and level <= config.DEBUG_LEVEL then
scripts/aimbot/logging.lua:        -- Write to log file for persistent debugging
scripts/aimbot/logging.lua:        local logDir = ensureLogDirExists()
scripts/aimbot/logging.lua:        local file = io.open(logDir .. "aimbot_debug.log", "a")
scripts/aimbot/logging.lua:        if file then
scripts/aimbot/logging.lua:            file:write(debugMessage .. "\n")
scripts/aimbot/logging.lua:            file:close()
scripts/aimbot/logging.lua:        else
scripts/aimbot/logging.lua:            et.G_Print("Warning: Could not open debug log file: " .. logDir .. "aimbot_debug.log\n")
scripts/aimbot/logging.lua:        end
scripts/aimbot/logging.lua:    end
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    -- Print to server console if server console debug is enabled
scripts/aimbot/logging.lua:    if config.SERVER_CONSOLE_DEBUG and level <= config.SERVER_CONSOLE_DEBUG_LEVEL then
scripts/aimbot/logging.lua:        et.G_Print(debugMessage .. "\n")
scripts/aimbot/logging.lua:    end
scripts/aimbot/logging.lua:end
scripts/aimbot/logging.lua:
scripts/aimbot/logging.lua:-- Log detection event
scripts/aimbot/logging.lua:local function logDetection(player, confidence, detectionCount, aimbotType, reason)
scripts/aimbot/logging.lua:    if not player then return end
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    local detectionMessage = string.format("DETECTION: Player %s (%s) - confidence: %.2f, detections: %d, type: %s, reason: %s", 
scripts/aimbot/logging.lua:        player.name, player.guid, confidence, detectionCount, aimbotType, reason)
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    log(1, detectionMessage)
scripts/aimbot/logging.lua:end
scripts/aimbot/logging.lua:
scripts/aimbot/logging.lua:-- Log warning event
scripts/aimbot/logging.lua:local function logWarning(player, reason)
scripts/aimbot/logging.lua:    if not player then return end
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    local warningMessage = string.format("WARNING: Player %s (%s) - warning %d/%d, reason: %s", 
scripts/aimbot/logging.lua:        player.name, player.guid, player.warnings, config.MAX_WARNINGS, reason)
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    log(1, warningMessage)
scripts/aimbot/logging.lua:end
scripts/aimbot/logging.lua:
scripts/aimbot/logging.lua:-- Log ban event
scripts/aimbot/logging.lua:local function logBan(player, isPermanent, reason)
scripts/aimbot/logging.lua:    if not player then return end
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    local banMessage = string.format("BAN: Player %s (%s) - %s ban, reason: %s", 
scripts/aimbot/logging.lua:        player.name, player.guid, isPermanent and "permanent" or "temporary", reason)
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    log(1, banMessage)
scripts/aimbot/logging.lua:end
scripts/aimbot/logging.lua:
scripts/aimbot/logging.lua:-- Log player stats for debugging
scripts/aimbot/logging.lua:local function logPlayerStats(player)
scripts/aimbot/logging.lua:    if not player or config.DEBUG_LEVEL < 3 then return end
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    local statsMessage = string.format("STATS: Player %s - shots: %d, hits: %d, headshots: %d, accuracy: %.2f, headshot ratio: %.2f", 
scripts/aimbot/logging.lua:        player.name, player.shots, player.hits, player.headshots, 
scripts/aimbot/logging.lua:        player.shots > 0 and player.hits / player.shots or 0,
scripts/aimbot/logging.lua:        player.kills > 0 and player.headshots / player.kills or 0)
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    debugLog(statsMessage, 3)
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    -- Log weapon-specific stats
scripts/aimbot/logging.lua:    for weapon, stats in pairs(player.weaponStats) do
scripts/aimbot/logging.lua:        local weaponStatsMessage = string.format("WEAPON STATS: Player %s - weapon: %s, shots: %d, hits: %d, headshots: %d, accuracy: %.2f, headshot ratio: %.2f", 
scripts/aimbot/logging.lua:            player.name, weapon, stats.shots, stats.hits, stats.headshots,
scripts/aimbot/logging.lua:            stats.shots > 0 and stats.hits / stats.shots or 0,
scripts/aimbot/logging.lua:            stats.kills > 0 and stats.headshots / stats.kills or 0)
scripts/aimbot/logging.lua:        
scripts/aimbot/logging.lua:        debugLog(weaponStatsMessage, 3)
scripts/aimbot/logging.lua:    end
scripts/aimbot/logging.lua:end
scripts/aimbot/logging.lua:
scripts/aimbot/logging.lua:-- Log system startup
scripts/aimbot/logging.lua:local function logStartup()
scripts/aimbot/logging.lua:    log(1, "ETAimbotDetector v1.0 initialized")
scripts/aimbot/logging.lua:    
scripts/aimbot/logging.lua:    -- Log configuration
scripts/aimbot/logging.lua:    if config.DEBUG_MODE and config.DEBUG_LEVEL >= 2 then
scripts/aimbot/logging.lua:        debugLog("Configuration:", 2)
scripts/aimbot/logging.lua:        for key, value in pairs(config) do
scripts/aimbot/logging.lua:            if type(value) ~= "table" then
scripts/aimbot/logging.lua:                debugLog("  " .. key .. " = " .. tostring(value), 2)
scripts/aimbot/logging.lua:            else
scripts/aimbot/logging.lua:                debugLog("  " .. key .. " = [table]", 2)
scripts/aimbot/logging.lua:            end
scripts/aimbot/logging.lua:        end
scripts/aimbot/logging.lua:    end
scripts/aimbot/logging.lua:end
scripts/aimbot/logging.lua:
scripts/aimbot/logging.lua:-- Export functions
scripts/aimbot/logging.lua:    ensureLogDirExists = ensureLogDirExists,
scripts/aimbot/logging.lua:    log = log,
scripts/aimbot/logging.lua:    debugLog = debugLog,
scripts/aimbot/logging.lua:    logDetection = logDetection,
scripts/aimbot/logging.lua:    logWarning = logWarning,
scripts/aimbot/logging.lua:    logBan = logBan,
scripts/aimbot/logging.lua:    logPlayerStats = logPlayerStats,
scripts/aimbot/logging.lua:    logStartup = logStartup
scripts/aimbot/logging.lua:}
scripts/aimbot/micro_movement.lua:-- Micro-movement detection for humanized aimbots
scripts/aimbot/micro_movement.lua:-- This module implements detection for small, precise adjustments that are characteristic of humanized aimbots
scripts/aimbot/micro_movement.lua:
scripts/aimbot/micro_movement.lua:-- Check for micro-movements (humanized aimbot detection)
scripts/aimbot/micro_movement.lua:local function detectMicroMovements(clientNum)
scripts/aimbot/micro_movement.lua:    local player = players[clientNum]
scripts/aimbot/micro_movement.lua:    if not player or #player.angleChanges < config.MIN_SAMPLES_REQUIRED then
scripts/aimbot/micro_movement.lua:        return false, 0
scripts/aimbot/micro_movement.lua:    end
scripts/aimbot/micro_movement.lua:    
scripts/aimbot/micro_movement.lua:    local microMovementCount = 0
scripts/aimbot/micro_movement.lua:    local microMovementSequence = 0
scripts/aimbot/micro_movement.lua:    local maxMicroMovementSequence = 0
scripts/aimbot/micro_movement.lua:    
scripts/aimbot/micro_movement.lua:    -- Analyze angle changes for micro-movement patterns
scripts/aimbot/micro_movement.lua:    for i = 2, #player.angleChanges do
scripts/aimbot/micro_movement.lua:        -- Micro-movements are small, precise adjustments between 5-20 degrees
scripts/aimbot/micro_movement.lua:        if player.angleChanges[i] >= 5 and player.angleChanges[i] <= 20 then
scripts/aimbot/micro_movement.lua:            microMovementCount = microMovementCount + 1
scripts/aimbot/micro_movement.lua:            microMovementSequence = microMovementSequence + 1
scripts/aimbot/micro_movement.lua:            
scripts/aimbot/micro_movement.lua:            if microMovementSequence > maxMicroMovementSequence then
scripts/aimbot/micro_movement.lua:                maxMicroMovementSequence = microMovementSequence
scripts/aimbot/micro_movement.lua:            end
scripts/aimbot/micro_movement.lua:        else
scripts/aimbot/micro_movement.lua:            microMovementSequence = 0
scripts/aimbot/micro_movement.lua:        end
scripts/aimbot/micro_movement.lua:    end
scripts/aimbot/micro_movement.lua:    
scripts/aimbot/micro_movement.lua:    -- Calculate standard deviation of micro-movements
scripts/aimbot/micro_movement.lua:    local microMovements = {}
scripts/aimbot/micro_movement.lua:    for i = 2, #player.angleChanges do
scripts/aimbot/micro_movement.lua:        if player.angleChanges[i] >= 5 and player.angleChanges[i] <= 20 then
scripts/aimbot/micro_movement.lua:            table.insert(microMovements, player.angleChanges[i])
scripts/aimbot/micro_movement.lua:        end
scripts/aimbot/micro_movement.lua:    end
scripts/aimbot/micro_movement.lua:    
scripts/aimbot/micro_movement.lua:    local microMovementAvg = 0
scripts/aimbot/micro_movement.lua:    local microMovementStdDev = 0
scripts/aimbot/micro_movement.lua:    
scripts/aimbot/micro_movement.lua:    if #microMovements > 0 then
scripts/aimbot/micro_movement.lua:        -- Calculate average
scripts/aimbot/micro_movement.lua:        local sum = 0
scripts/aimbot/micro_movement.lua:        for _, v in ipairs(microMovements) do
scripts/aimbot/micro_movement.lua:            sum = sum + v
scripts/aimbot/micro_movement.lua:        end
scripts/aimbot/micro_movement.lua:        microMovementAvg = sum / #microMovements
scripts/aimbot/micro_movement.lua:        
scripts/aimbot/micro_movement.lua:        -- Calculate standard deviation
scripts/aimbot/micro_movement.lua:        local sumSquares = 0
scripts/aimbot/micro_movement.lua:        for _, v in ipairs(microMovements) do
scripts/aimbot/micro_movement.lua:            sumSquares = sumSquares + (v - microMovementAvg)^2
scripts/aimbot/micro_movement.lua:        end
scripts/aimbot/micro_movement.lua:        
scripts/aimbot/micro_movement.lua:        if #microMovements > 1 then
scripts/aimbot/micro_movement.lua:            microMovementStdDev = math.sqrt(sumSquares / (#microMovements - 1))
scripts/aimbot/micro_movement.lua:        end
scripts/aimbot/micro_movement.lua:    end
scripts/aimbot/micro_movement.lua:    
scripts/aimbot/micro_movement.lua:    debugLog("detectMicroMovements: " .. player.name .. " - microMovements=" .. microMovementCount .. 
scripts/aimbot/micro_movement.lua:             ", maxSequence=" .. maxMicroMovementSequence .. 
scripts/aimbot/micro_movement.lua:             ", avg=" .. microMovementAvg .. 
scripts/aimbot/micro_movement.lua:             ", stdDev=" .. microMovementStdDev, 2)
scripts/aimbot/micro_movement.lua:    
scripts/aimbot/micro_movement.lua:    -- Calculate confidence score based on micro-movement patterns
scripts/aimbot/micro_movement.lua:    local confidence = 0
scripts/aimbot/micro_movement.lua:    
scripts/aimbot/micro_movement.lua:    -- Suspicious pattern: Many micro-movements with low standard deviation
scripts/aimbot/micro_movement.lua:    if microMovementCount >= 5 and maxMicroMovementSequence >= 3 and microMovementStdDev < 3 then
scripts/aimbot/micro_movement.lua:        confidence = 0.8
scripts/aimbot/micro_movement.lua:        return true, confidence, string.format("Highly suspicious micro-movement pattern (count: %d, sequence: %d, stdDev: %.2f°)", 
scripts/aimbot/micro_movement.lua:            microMovementCount, maxMicroMovementSequence, microMovementStdDev)
scripts/aimbot/micro_movement.lua:    -- Moderately suspicious: Several micro-movements with moderate standard deviation
scripts/aimbot/micro_movement.lua:    elseif microMovementCount >= 5 and maxMicroMovementSequence >= 3 and microMovementStdDev < 5 then
scripts/aimbot/micro_movement.lua:        confidence = 0.6
scripts/aimbot/micro_movement.lua:        return true, confidence, string.format("Suspicious micro-movement pattern (count: %d, sequence: %d, stdDev: %.2f°)", 
scripts/aimbot/micro_movement.lua:            microMovementCount, maxMicroMovementSequence, microMovementStdDev)
scripts/aimbot/micro_movement.lua:    -- Slightly suspicious: Some micro-movements with higher standard deviation
scripts/aimbot/micro_movement.lua:    elseif microMovementCount >= 4 and maxMicroMovementSequence >= 2 and microMovementStdDev < 8 then
scripts/aimbot/micro_movement.lua:        confidence = 0.4
scripts/aimbot/micro_movement.lua:        return true, confidence, string.format("Slightly suspicious micro-movement pattern (count: %d, sequence: %d, stdDev: %.2f°)", 
scripts/aimbot/micro_movement.lua:            microMovementCount, maxMicroMovementSequence, microMovementStdDev)
scripts/aimbot/micro_movement.lua:    end
scripts/aimbot/micro_movement.lua:    
scripts/aimbot/micro_movement.lua:    return false, 0
scripts/aimbot/micro_movement.lua:end
scripts/aimbot/micro_movement.lua:
scripts/aimbot/micro_movement.lua:-- Integrate micro-movement detection into the main detection system
scripts/aimbot/micro_movement.lua:local function enhanceDetectionWithMicroMovements(clientNum, totalConfidence, detectionCount, reasons)
scripts/aimbot/micro_movement.lua:    if not config.MICRO_MOVEMENT_DETECTION then
scripts/aimbot/micro_movement.lua:        return totalConfidence, detectionCount, reasons
scripts/aimbot/micro_movement.lua:    end
scripts/aimbot/micro_movement.lua:    
scripts/aimbot/micro_movement.lua:    local suspicious, confidence, reason = detectMicroMovements(clientNum)
scripts/aimbot/micro_movement.lua:    
scripts/aimbot/micro_movement.lua:    if suspicious then
scripts/aimbot/micro_movement.lua:        totalConfidence = totalConfidence + confidence
scripts/aimbot/micro_movement.lua:        detectionCount = detectionCount + 1
scripts/aimbot/micro_movement.lua:        table.insert(reasons, reason)
scripts/aimbot/micro_movement.lua:        
scripts/aimbot/micro_movement.lua:        debugLog("enhanceDetectionWithMicroMovements: Detected suspicious micro-movements for client " .. clientNum .. " with confidence " .. confidence, 1)
scripts/aimbot/micro_movement.lua:    end
scripts/aimbot/micro_movement.lua:    
scripts/aimbot/micro_movement.lua:    return totalConfidence, detectionCount, reasons
scripts/aimbot/micro_movement.lua:end
scripts/aimbot/micro_movement.lua:
scripts/aimbot/micro_movement.lua:-- Export functions
scripts/aimbot/micro_movement.lua:    detectMicroMovements = detectMicroMovements,
scripts/aimbot/micro_movement.lua:    enhanceDetectionWithMicroMovements = enhanceDetectionWithMicroMovements
scripts/aimbot/micro_movement.lua:end
scripts/aimbot/skill_adaptation.lua:-- Skill level adaptation for aimbot detection
scripts/aimbot/skill_adaptation.lua:-- This module adjusts detection thresholds based on player experience level
scripts/aimbot/skill_adaptation.lua:
scripts/aimbot/skill_adaptation.lua:-- Skill level thresholds
scripts/aimbot/skill_adaptation.lua:local SKILL_LEVELS = {
scripts/aimbot/skill_adaptation.lua:    NOVICE = 0,       -- 0-999 XP
scripts/aimbot/skill_adaptation.lua:    REGULAR = 1000,   -- 1000-4999 XP
scripts/aimbot/skill_adaptation.lua:    SKILLED = 5000,   -- 5000-9999 XP
scripts/aimbot/skill_adaptation.lua:    EXPERT = 10000    -- 10000+ XP
scripts/aimbot/skill_adaptation.lua:
scripts/aimbot/skill_adaptation.lua:
scripts/aimbot/skill_adaptation.lua:-- Threshold adjustments based on skill level
scripts/aimbot/skill_adaptation.lua:local SKILL_ADJUSTMENTS = {
scripts/aimbot/skill_adaptation.lua:    NOVICE = { accuracy = 0.0, headshot = 0.0 },
scripts/aimbot/skill_adaptation.lua:    REGULAR = { accuracy = 0.05, headshot = 0.05 },
scripts/aimbot/skill_adaptation.lua:    SKILLED = { accuracy = 0.1, headshot = 0.1 },
scripts/aimbot/skill_adaptation.lua:    EXPERT = { accuracy = 0.15, headshot = 0.15 }
scripts/aimbot/skill_adaptation.lua:
scripts/aimbot/skill_adaptation.lua:
scripts/aimbot/skill_adaptation.lua:-- Get player skill level based on XP
scripts/aimbot/skill_adaptation.lua:local function getPlayerSkillLevel(player)
scripts/aimbot/skill_adaptation.lua:    if not config.SKILL_ADAPTATION then return "REGULAR" end
scripts/aimbot/skill_adaptation.lua:    
scripts/aimbot/skill_adaptation.lua:    local xp = player.xp or 0
scripts/aimbot/skill_adaptation.lua:    
scripts/aimbot/skill_adaptation.lua:    if xp >= SKILL_LEVELS.EXPERT then
scripts/aimbot/skill_adaptation.lua:        return "EXPERT"
scripts/aimbot/skill_adaptation.lua:    elseif xp >= SKILL_LEVELS.SKILLED then
scripts/aimbot/skill_adaptation.lua:        return "SKILLED"
scripts/aimbot/skill_adaptation.lua:    elseif xp >= SKILL_LEVELS.REGULAR then
scripts/aimbot/skill_adaptation.lua:        return "REGULAR"
scripts/aimbot/skill_adaptation.lua:    else
scripts/aimbot/skill_adaptation.lua:        return "NOVICE"
scripts/aimbot/skill_adaptation.lua:    end
scripts/aimbot/skill_adaptation.lua:end
scripts/aimbot/skill_adaptation.lua:
scripts/aimbot/skill_adaptation.lua:-- Get adjusted threshold based on player skill level
scripts/aimbot/skill_adaptation.lua:local function getAdjustedThreshold(player, baseThreshold, thresholdType)
scripts/aimbot/skill_adaptation.lua:    if not config.SKILL_ADAPTATION then return baseThreshold end
scripts/aimbot/skill_adaptation.lua:    
scripts/aimbot/skill_adaptation.lua:    local skillLevel = getPlayerSkillLevel(player)
scripts/aimbot/skill_adaptation.lua:    local adjustment = SKILL_ADJUSTMENTS[skillLevel][thresholdType] or 0
scripts/aimbot/skill_adaptation.lua:    
scripts/aimbot/skill_adaptation.lua:    debugLog("getAdjustedThreshold: " .. player.name .. " - skillLevel=" .. skillLevel .. 
scripts/aimbot/skill_adaptation.lua:             ", baseThreshold=" .. baseThreshold .. ", adjustment=" .. adjustment .. 
scripts/aimbot/skill_adaptation.lua:             ", finalThreshold=" .. (baseThreshold + adjustment), 3)
scripts/aimbot/skill_adaptation.lua:    
scripts/aimbot/skill_adaptation.lua:    return baseThreshold + adjustment
scripts/aimbot/skill_adaptation.lua:end
scripts/aimbot/skill_adaptation.lua:
scripts/aimbot/skill_adaptation.lua:-- Update player XP (called when XP changes)
scripts/aimbot/skill_adaptation.lua:local function updatePlayerXP(clientNum, xp)
scripts/aimbot/skill_adaptation.lua:    local player = players[clientNum]
scripts/aimbot/skill_adaptation.lua:    if not player then return end
scripts/aimbot/skill_adaptation.lua:    
scripts/aimbot/skill_adaptation.lua:    local oldXP = player.xp or 0
scripts/aimbot/skill_adaptation.lua:    player.xp = xp
scripts/aimbot/skill_adaptation.lua:    
scripts/aimbot/skill_adaptation.lua:    -- Log skill level change
scripts/aimbot/skill_adaptation.lua:    local oldSkillLevel = player.skillLevel or "UNKNOWN"
scripts/aimbot/skill_adaptation.lua:    local newSkillLevel = getPlayerSkillLevel(player)
scripts/aimbot/skill_adaptation.lua:    
scripts/aimbot/skill_adaptation.lua:    if oldSkillLevel ~= newSkillLevel then
scripts/aimbot/skill_adaptation.lua:        debugLog("updatePlayerXP: " .. player.name .. " skill level changed from " .. oldSkillLevel .. " to " .. newSkillLevel, 2)
scripts/aimbot/skill_adaptation.lua:        player.skillLevel = newSkillLevel
scripts/aimbot/skill_adaptation.lua:        
scripts/aimbot/skill_adaptation.lua:        -- Recalculate detection thresholds
scripts/aimbot/skill_adaptation.lua:        if config.SKILL_ADAPTATION then
scripts/aimbot/skill_adaptation.lua:            debugLog("updatePlayerXP: Recalculating detection thresholds for " .. player.name .. " due to skill level change", 2)
scripts/aimbot/skill_adaptation.lua:        end
scripts/aimbot/skill_adaptation.lua:    end
scripts/aimbot/skill_adaptation.lua:    
scripts/aimbot/skill_adaptation.lua:    -- Log XP change
scripts/aimbot/skill_adaptation.lua:    if xp > oldXP then
scripts/aimbot/skill_adaptation.lua:        debugLog("updatePlayerXP: " .. player.name .. " gained " .. (xp - oldXP) .. " XP (total: " .. xp .. ")", 3)
scripts/aimbot/skill_adaptation.lua:    end
scripts/aimbot/skill_adaptation.lua:end
scripts/aimbot/skill_adaptation.lua:
scripts/aimbot/skill_adaptation.lua:-- ET:Legacy callback: XP Stats
scripts/aimbot/skill_adaptation.lua:function et_ClientXPStat(clientNum, stats)
scripts/aimbot/skill_adaptation.lua:    if not config.SKILL_ADAPTATION then return end
scripts/aimbot/skill_adaptation.lua:    
scripts/aimbot/skill_adaptation.lua:    -- Calculate total XP
scripts/aimbot/skill_adaptation.lua:    local totalXP = 0
scripts/aimbot/skill_adaptation.lua:    for i = 0, #stats do
scripts/aimbot/skill_adaptation.lua:        totalXP = totalXP + stats[i]
scripts/aimbot/skill_adaptation.lua:    end
scripts/aimbot/skill_adaptation.lua:    
scripts/aimbot/skill_adaptation.lua:    -- Update player XP
scripts/aimbot/skill_adaptation.lua:    updatePlayerXP(clientNum, totalXP)
scripts/aimbot/skill_adaptation.lua:end
scripts/aimbot/skill_adaptation.lua:
scripts/aimbot/skill_adaptation.lua:-- Integrate skill level adaptation into the main detection system
scripts/aimbot/skill_adaptation.lua:local function enhanceDetectionWithSkillAdaptation(clientNum, suspiciousActivity, confidence)
scripts/aimbot/skill_adaptation.lua:    if not config.SKILL_ADAPTATION then
scripts/aimbot/skill_adaptation.lua:        return suspiciousActivity, confidence
scripts/aimbot/skill_adaptation.lua:    end
scripts/aimbot/skill_adaptation.lua:    
scripts/aimbot/skill_adaptation.lua:    local player = players[clientNum]
scripts/aimbot/skill_adaptation.lua:    if not player then
scripts/aimbot/skill_adaptation.lua:        return suspiciousActivity, confidence
scripts/aimbot/skill_adaptation.lua:    end
scripts/aimbot/skill_adaptation.lua:    
scripts/aimbot/skill_adaptation.lua:    local skillLevel = getPlayerSkillLevel(player)
scripts/aimbot/skill_adaptation.lua:    
scripts/aimbot/skill_adaptation.lua:    -- Adjust confidence based on skill level
scripts/aimbot/skill_adaptation.lua:    -- For higher skill players, we require higher confidence to trigger warnings
scripts/aimbot/skill_adaptation.lua:    if suspiciousActivity then
scripts/aimbot/skill_adaptation.lua:        local skillAdjustment = 0
scripts/aimbot/skill_adaptation.lua:        
scripts/aimbot/skill_adaptation.lua:        if skillLevel == "EXPERT" then
scripts/aimbot/skill_adaptation.lua:            skillAdjustment = 0.1
scripts/aimbot/skill_adaptation.lua:        elseif skillLevel == "SKILLED" then
scripts/aimbot/skill_adaptation.lua:            skillAdjustment = 0.05
scripts/aimbot/skill_adaptation.lua:        elseif skillLevel == "REGULAR" then
scripts/aimbot/skill_adaptation.lua:            skillAdjustment = 0.02
scripts/aimbot/skill_adaptation.lua:        end
scripts/aimbot/skill_adaptation.lua:        
scripts/aimbot/skill_adaptation.lua:        -- Reduce confidence for higher skill players
scripts/aimbot/skill_adaptation.lua:        confidence = confidence - skillAdjustment
scripts/aimbot/skill_adaptation.lua:        
scripts/aimbot/skill_adaptation.lua:        -- If confidence drops below threshold after adjustment, don't consider it suspicious
scripts/aimbot/skill_adaptation.lua:        if confidence < config.CONFIDENCE_THRESHOLD then
scripts/aimbot/skill_adaptation.lua:            suspiciousActivity = false
scripts/aimbot/skill_adaptation.lua:            debugLog("enhanceDetectionWithSkillAdaptation: Suspicious activity ignored for " .. player.name .. 
scripts/aimbot/skill_adaptation.lua:                     " due to skill level " .. skillLevel .. " (adjusted confidence: " .. confidence .. ")", 2)
scripts/aimbot/skill_adaptation.lua:        else
scripts/aimbot/skill_adaptation.lua:            debugLog("enhanceDetectionWithSkillAdaptation: Suspicious activity confirmed for " .. player.name .. 
scripts/aimbot/skill_adaptation.lua:                     " despite skill level " .. skillLevel .. " (adjusted confidence: " .. confidence .. ")", 2)
scripts/aimbot/skill_adaptation.lua:        end
scripts/aimbot/skill_adaptation.lua:    end
scripts/aimbot/skill_adaptation.lua:    
scripts/aimbot/skill_adaptation.lua:    return suspiciousActivity, confidence
scripts/aimbot/skill_adaptation.lua:end
scripts/aimbot/skill_adaptation.lua:
scripts/aimbot/skill_adaptation.lua:-- Export functions and data
scripts/aimbot/skill_adaptation.lua:    SKILL_LEVELS = SKILL_LEVELS,
scripts/aimbot/skill_adaptation.lua:    SKILL_ADJUSTMENTS = SKILL_ADJUSTMENTS,
scripts/aimbot/skill_adaptation.lua:    getPlayerSkillLevel = getPlayerSkillLevel,
scripts/aimbot/skill_adaptation.lua:    getAdjustedThreshold = getAdjustedThreshold,
scripts/aimbot/skill_adaptation.lua:    updatePlayerXP = updatePlayerXP,
scripts/aimbot/skill_adaptation.lua:    enhanceDetectionWithSkillAdaptation = enhanceDetectionWithSkillAdaptation
scripts/aimbot/skill_adaptation.lua:
scripts/aimbot/time_series.lua:-- Time-series analysis for aimbot detection
scripts/aimbot/time_series.lua:-- This module implements detection for timing patterns and consistency in player actions
scripts/aimbot/time_series.lua:
scripts/aimbot/time_series.lua:-- Calculate standard deviation
scripts/aimbot/time_series.lua:local function calculateStdDev(values, mean)
scripts/aimbot/time_series.lua:    if #values < 2 then return 0 end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    local sum = 0
scripts/aimbot/time_series.lua:    for _, v in ipairs(values) do
scripts/aimbot/time_series.lua:        sum = sum + (v - mean)^2
scripts/aimbot/time_series.lua:    end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    return math.sqrt(sum / (#values - 1))
scripts/aimbot/time_series.lua:end
scripts/aimbot/time_series.lua:
scripts/aimbot/time_series.lua:-- Calculate moving average
scripts/aimbot/time_series.lua:local function calculateMovingAverage(values, window)
scripts/aimbot/time_series.lua:    if #values < window then return 0 end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    local sum = 0
scripts/aimbot/time_series.lua:    for i = #values - window + 1, #values do
scripts/aimbot/time_series.lua:        sum = sum + values[i]
scripts/aimbot/time_series.lua:    end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    return sum / window
scripts/aimbot/time_series.lua:end
scripts/aimbot/time_series.lua:
scripts/aimbot/time_series.lua:-- Calculate timing consistency between shots
scripts/aimbot/time_series.lua:local function calculateTimingConsistency(player)
scripts/aimbot/time_series.lua:    if not player.weaponStats[player.lastWeapon] then return 0 end
scripts/aimbot/time_series.lua:    if not player.shotTimings or #player.shotTimings < config.MIN_SHOT_SAMPLES then return 0 end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    local timings = player.shotTimings
scripts/aimbot/time_series.lua:    local avg = calculateMovingAverage(timings, #timings)
scripts/aimbot/time_series.lua:    local stdDev = calculateStdDev(timings, avg)
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    -- Normalize standard deviation as a percentage of the average
scripts/aimbot/time_series.lua:    local normalizedStdDev = stdDev / avg
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    -- Human players show more variance in their timing
scripts/aimbot/time_series.lua:    -- Extremely low variance is suspicious (aimbots have very consistent timing)
scripts/aimbot/time_series.lua:    if normalizedStdDev < 0.05 and #timings >= 10 then
scripts/aimbot/time_series.lua:        -- Extremely low variance is highly suspicious
scripts/aimbot/time_series.lua:        debugLog("calculateTimingConsistency: Extremely low timing variance detected (" .. normalizedStdDev .. "), highly suspicious", 2)
scripts/aimbot/time_series.lua:        return 0.9
scripts/aimbot/time_series.lua:    elseif normalizedStdDev < 0.1 and #timings >= 8 then
scripts/aimbot/time_series.lua:        -- Very low variance is moderately suspicious
scripts/aimbot/time_series.lua:        debugLog("calculateTimingConsistency: Very low timing variance detected (" .. normalizedStdDev .. "), moderately suspicious", 2)
scripts/aimbot/time_series.lua:        return 0.7
scripts/aimbot/time_series.lua:    elseif normalizedStdDev < 0.15 and #timings >= 6 then
scripts/aimbot/time_series.lua:        -- Low variance is slightly suspicious
scripts/aimbot/time_series.lua:        debugLog("calculateTimingConsistency: Low timing variance detected (" .. normalizedStdDev .. "), slightly suspicious", 2)
scripts/aimbot/time_series.lua:        return 0.5
scripts/aimbot/time_series.lua:    end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    -- Return consistency score (1 - normalized standard deviation)
scripts/aimbot/time_series.lua:    -- Higher score means more consistent timing (suspicious)
scripts/aimbot/time_series.lua:    return math.max(0, math.min(0.4, 1 - normalizedStdDev))
scripts/aimbot/time_series.lua:end
scripts/aimbot/time_series.lua:
scripts/aimbot/time_series.lua:-- Detect repeating patterns in a sequence
scripts/aimbot/time_series.lua:local function detectRepeatingPatterns(sequence)
scripts/aimbot/time_series.lua:    if #sequence < 10 then return 0 end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    local patternCount = 0
scripts/aimbot/time_series.lua:    -- Check for patterns of length 2-4
scripts/aimbot/time_series.lua:    for patternLength = 2, 4 do
scripts/aimbot/time_series.lua:        for i = 1, #sequence - (patternLength * 2) + 1 do
scripts/aimbot/time_series.lua:            local pattern = {}
scripts/aimbot/time_series.lua:            for j = 0, patternLength - 1 do
scripts/aimbot/time_series.lua:                pattern[j+1] = sequence[i+j]
scripts/aimbot/time_series.lua:            end
scripts/aimbot/time_series.lua:            
scripts/aimbot/time_series.lua:            -- Check if this pattern repeats
scripts/aimbot/time_series.lua:            local repeats = 0
scripts/aimbot/time_series.lua:            for k = i + patternLength, #sequence - patternLength + 1, patternLength do
scripts/aimbot/time_series.lua:                local matches = true
scripts/aimbot/time_series.lua:                for j = 1, patternLength do
scripts/aimbot/time_series.lua:                    if math.abs(sequence[k+j-1] - pattern[j]) > 5 then
scripts/aimbot/time_series.lua:                        matches = false
scripts/aimbot/time_series.lua:                        break
scripts/aimbot/time_series.lua:                    end
scripts/aimbot/time_series.lua:                end
scripts/aimbot/time_series.lua:                if matches then repeats = repeats + 1 end
scripts/aimbot/time_series.lua:            end
scripts/aimbot/time_series.lua:            
scripts/aimbot/time_series.lua:            if repeats > 1 then 
scripts/aimbot/time_series.lua:                patternCount = patternCount + 1
scripts/aimbot/time_series.lua:                debugLog("detectRepeatingPatterns: Found repeating pattern of length " .. patternLength .. " with " .. repeats .. " repeats", 3)
scripts/aimbot/time_series.lua:            end
scripts/aimbot/time_series.lua:        end
scripts/aimbot/time_series.lua:    end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    -- Return normalized pattern score (0-1)
scripts/aimbot/time_series.lua:    return math.min(1, patternCount / 5)
scripts/aimbot/time_series.lua:end
scripts/aimbot/time_series.lua:
scripts/aimbot/time_series.lua:-- Analyze time-series data for aimbot patterns
scripts/aimbot/time_series.lua:local function analyzeTimeSeriesData(clientNum)
scripts/aimbot/time_series.lua:    local player = players[clientNum]
scripts/aimbot/time_series.lua:    if not player then return 0, "No data" end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    -- Skip if we don't have enough data
scripts/aimbot/time_series.lua:    if #player.angleChanges < 10 or not player.shotTimings or #player.shotTimings < config.MIN_SHOT_SAMPLES then
scripts/aimbot/time_series.lua:        return 0, "Insufficient data"
scripts/aimbot/time_series.lua:    end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    -- Calculate timing consistency
scripts/aimbot/time_series.lua:    local timingConsistency = calculateTimingConsistency(player)
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    -- Detect repeating patterns in angle changes
scripts/aimbot/time_series.lua:    local patternScore = detectRepeatingPatterns(player.angleChanges)
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    -- Detect repeating patterns in shot timings
scripts/aimbot/time_series.lua:    local shotPatternScore = 0
scripts/aimbot/time_series.lua:    if #player.shotTimings >= 10 then
scripts/aimbot/time_series.lua:        shotPatternScore = detectRepeatingPatterns(player.shotTimings)
scripts/aimbot/time_series.lua:    end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    -- Calculate combined time-series score
scripts/aimbot/time_series.lua:    local timeSeriesScore = (timingConsistency * config.TIMING_CONSISTENCY_WEIGHT) + 
scripts/aimbot/time_series.lua:                           (patternScore * config.PATTERN_DETECTION_WEIGHT * 0.6) +
scripts/aimbot/time_series.lua:                           (shotPatternScore * config.PATTERN_DETECTION_WEIGHT * 0.4)
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    local reason = string.format("Time-series analysis (timing: %.2f, angle patterns: %.2f, shot patterns: %.2f)", 
scripts/aimbot/time_series.lua:        timingConsistency, patternScore, shotPatternScore)
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    debugLog("analyzeTimeSeriesData: " .. player.name .. " - timingConsistency=" .. timingConsistency .. 
scripts/aimbot/time_series.lua:             ", patternScore=" .. patternScore .. ", shotPatternScore=" .. shotPatternScore .. 
scripts/aimbot/time_series.lua:             ", timeSeriesScore=" .. timeSeriesScore, 2)
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    return timeSeriesScore, reason
scripts/aimbot/time_series.lua:end
scripts/aimbot/time_series.lua:
scripts/aimbot/time_series.lua:-- Analyze target switching patterns
scripts/aimbot/time_series.lua:local function analyzeTargetSwitching(clientNum)
scripts/aimbot/time_series.lua:    local player = players[clientNum]
scripts/aimbot/time_series.lua:    if not player or not player.targetSwitches or #player.targetSwitches < 5 then
scripts/aimbot/time_series.lua:        return 0, "Insufficient target switch data"
scripts/aimbot/time_series.lua:    end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    -- Calculate average and standard deviation of target switch times
scripts/aimbot/time_series.lua:    local sum = 0
scripts/aimbot/time_series.lua:    for _, switchTime in ipairs(player.targetSwitches) do
scripts/aimbot/time_series.lua:        sum = sum + switchTime
scripts/aimbot/time_series.lua:    end
scripts/aimbot/time_series.lua:    local avg = sum / #player.targetSwitches
scripts/aimbot/time_series.lua:    local stdDev = calculateStdDev(player.targetSwitches, avg)
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    -- Calculate coefficient of variation
scripts/aimbot/time_series.lua:    local cv = stdDev / avg
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    debugLog("analyzeTargetSwitching: " .. player.name .. " - switches=" .. #player.targetSwitches .. 
scripts/aimbot/time_series.lua:             ", avg=" .. avg .. "ms, stdDev=" .. stdDev .. "ms, cv=" .. cv, 2)
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    -- Extremely consistent target switching is suspicious
scripts/aimbot/time_series.lua:    local confidence = 0
scripts/aimbot/time_series.lua:    local reason = ""
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    if cv < 0.2 and #player.targetSwitches >= 5 then
scripts/aimbot/time_series.lua:        confidence = 0.8
scripts/aimbot/time_series.lua:        reason = string.format("Highly suspicious target switching pattern (cv: %.2f)", cv)
scripts/aimbot/time_series.lua:    elseif cv < 0.3 and #player.targetSwitches >= 5 then
scripts/aimbot/time_series.lua:        confidence = 0.6
scripts/aimbot/time_series.lua:        reason = string.format("Suspicious target switching pattern (cv: %.2f)", cv)
scripts/aimbot/time_series.lua:    end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    return confidence, reason
scripts/aimbot/time_series.lua:end
scripts/aimbot/time_series.lua:
scripts/aimbot/time_series.lua:-- Integrate time-series analysis into the main detection system
scripts/aimbot/time_series.lua:local function enhanceDetectionWithTimeSeriesAnalysis(clientNum, totalConfidence, detectionCount, reasons)
scripts/aimbot/time_series.lua:    if not config.TIME_SERIES_ANALYSIS then
scripts/aimbot/time_series.lua:        return totalConfidence, detectionCount, reasons
scripts/aimbot/time_series.lua:    end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    local player = players[clientNum]
scripts/aimbot/time_series.lua:    if not player then
scripts/aimbot/time_series.lua:        return totalConfidence, detectionCount, reasons
scripts/aimbot/time_series.lua:    end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    -- Skip if we don't have enough data
scripts/aimbot/time_series.lua:    if not player.shotTimings or #player.shotTimings < config.MIN_SHOT_SAMPLES then
scripts/aimbot/time_series.lua:        return totalConfidence, detectionCount, reasons
scripts/aimbot/time_series.lua:    end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    -- Run time-series analysis
scripts/aimbot/time_series.lua:    local timeSeriesScore, timeSeriesReason = analyzeTimeSeriesData(clientNum)
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    if timeSeriesScore > config.TIME_SERIES_THRESHOLD then
scripts/aimbot/time_series.lua:        totalConfidence = totalConfidence + timeSeriesScore
scripts/aimbot/time_series.lua:        detectionCount = detectionCount + 1
scripts/aimbot/time_series.lua:        table.insert(reasons, timeSeriesReason)
scripts/aimbot/time_series.lua:        
scripts/aimbot/time_series.lua:        debugLog("enhanceDetectionWithTimeSeriesAnalysis: Detected suspicious time-series pattern for client " .. 
scripts/aimbot/time_series.lua:                 clientNum .. " with confidence " .. timeSeriesScore, 1)
scripts/aimbot/time_series.lua:    end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    -- Also analyze target switching patterns
scripts/aimbot/time_series.lua:    local targetSwitchConfidence, targetSwitchReason = analyzeTargetSwitching(clientNum)
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    if targetSwitchConfidence > 0.5 then
scripts/aimbot/time_series.lua:        totalConfidence = totalConfidence + targetSwitchConfidence
scripts/aimbot/time_series.lua:        detectionCount = detectionCount + 1
scripts/aimbot/time_series.lua:        table.insert(reasons, targetSwitchReason)
scripts/aimbot/time_series.lua:        
scripts/aimbot/time_series.lua:        debugLog("enhanceDetectionWithTimeSeriesAnalysis: Detected suspicious target switching pattern for client " .. 
scripts/aimbot/time_series.lua:                 clientNum .. " with confidence " .. targetSwitchConfidence, 1)
scripts/aimbot/time_series.lua:    end
scripts/aimbot/time_series.lua:    
scripts/aimbot/time_series.lua:    return totalConfidence, detectionCount, reasons
scripts/aimbot/time_series.lua:end
scripts/aimbot/time_series.lua:
scripts/aimbot/time_series.lua:-- Export functions
scripts/aimbot/time_series.lua:    calculateStdDev = calculateStdDev,
scripts/aimbot/time_series.lua:    calculateMovingAverage = calculateMovingAverage,
scripts/aimbot/time_series.lua:    calculateTimingConsistency = calculateTimingConsistency,
scripts/aimbot/time_series.lua:    detectRepeatingPatterns = detectRepeatingPatterns,
scripts/aimbot/time_series.lua:    analyzeTimeSeriesData = analyzeTimeSeriesData,
scripts/aimbot/time_series.lua:    analyzeTargetSwitching = analyzeTargetSwitching,
scripts/aimbot/time_series.lua:    enhanceDetectionWithTimeSeriesAnalysis = enhanceDetectionWithTimeSeriesAnalysis
scripts/aimbot/time_series.lua:end
scripts/aimbot/warning_system.lua:-- Progressive warning system for aimbot detection
scripts/aimbot/warning_system.lua:-- This module implements a warning and ban system with configurable thresholds
scripts/aimbot/warning_system.lua:
scripts/aimbot/warning_system.lua:-- Issue warning to player
scripts/aimbot/warning_system.lua:local function warnPlayer(clientNum, reason)
scripts/aimbot/warning_system.lua:    local player = players[clientNum]
scripts/aimbot/warning_system.lua:    if not player then return end
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    player.warnings = player.warnings + 1
scripts/aimbot/warning_system.lua:    player.lastWarningTime = et.trap_Milliseconds()
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    local warningMessage = string.format("^1WARNING^7: Suspicious activity detected (%s). Warning %d/%d", 
scripts/aimbot/warning_system.lua:        reason, player.warnings, config.MAX_WARNINGS)
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    -- Send center-print message to player if this is beyond the warning threshold
scripts/aimbot/warning_system.lua:    if player.warnings >= config.WARN_THRESHOLD then
scripts/aimbot/warning_system.lua:        et.trap_SendServerCommand(clientNum, "cp " .. warningMessage)
scripts/aimbot/warning_system.lua:        
scripts/aimbot/warning_system.lua:        -- Send chat message to player if enabled
scripts/aimbot/warning_system.lua:        if config.CHAT_WARNINGS then
scripts/aimbot/warning_system.lua:            et.trap_SendServerCommand(clientNum, "chat \"" .. warningMessage .. "\"")
scripts/aimbot/warning_system.lua:        end
scripts/aimbot/warning_system.lua:    end
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    -- Notify admins
scripts/aimbot/warning_system.lua:    local adminMessage = string.format("^3ANTI-CHEAT^7: Player %s ^7suspected of aimbot (%s)", 
scripts/aimbot/warning_system.lua:        player.name, reason)
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    -- Send to all admins (clients with admin flag)
scripts/aimbot/warning_system.lua:    for i = 0, et.trap_Cvar_Get("sv_maxclients") - 1 do
scripts/aimbot/warning_system.lua:        if et.gentity_get(i, "inuse") and et.G_shrubbot_permission(i, "a") then
scripts/aimbot/warning_system.lua:            et.trap_SendServerCommand(i, "chat \"" .. adminMessage .. "\"")
scripts/aimbot/warning_system.lua:        end
scripts/aimbot/warning_system.lua:    end
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    -- Log warning
scripts/aimbot/warning_system.lua:    log(1, string.format("Warning issued to %s (%s): %s", 
scripts/aimbot/warning_system.lua:        player.name, player.guid, reason))
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    debugLog("Warning issued to " .. player.name .. " for " .. reason)
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    -- Check if player should be banned
scripts/aimbot/warning_system.lua:    if player.warnings >= config.MAX_WARNINGS and config.ENABLE_BANS then
scripts/aimbot/warning_system.lua:        banPlayer(clientNum, reason)
scripts/aimbot/warning_system.lua:    end
scripts/aimbot/warning_system.lua:end
scripts/aimbot/warning_system.lua:
scripts/aimbot/warning_system.lua:-- Ban player
scripts/aimbot/warning_system.lua:local function banPlayer(clientNum, reason)
scripts/aimbot/warning_system.lua:    local player = players[clientNum]
scripts/aimbot/warning_system.lua:    if not player then return end
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    player.tempBans = player.tempBans + 1
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    -- Determine ban duration
scripts/aimbot/warning_system.lua:    local banDuration = config.BAN_DURATION
scripts/aimbot/warning_system.lua:    local isPermanent = player.tempBans >= config.PERMANENT_BAN_THRESHOLD
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    if isPermanent then
scripts/aimbot/warning_system.lua:        banDuration = 0 -- 0 means permanent in ET:Legacy
scripts/aimbot/warning_system.lua:    end
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    -- Log ban
scripts/aimbot/warning_system.lua:    log(1, string.format("%s ban issued to %s (%s): %s", 
scripts/aimbot/warning_system.lua:        isPermanent and "Permanent" or "Temporary", 
scripts/aimbot/warning_system.lua:        player.name, player.guid, reason))
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    -- Notify all players
scripts/aimbot/warning_system.lua:    local banMessage = string.format("^1ANTI-CHEAT^7: Player %s ^7has been %s banned for aimbot", 
scripts/aimbot/warning_system.lua:        player.name, isPermanent and "permanently" or "temporarily")
scripts/aimbot/warning_system.lua:    et.trap_SendServerCommand(-1, "chat \"" .. banMessage .. "\"")
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    -- Execute ban command
scripts/aimbot/warning_system.lua:    if config.USE_SHRUBBOT_BANS then
scripts/aimbot/warning_system.lua:        -- Use shrubbot ban command if available
scripts/aimbot/warning_system.lua:        local banCmd = string.format("!ban %s %d %s", 
scripts/aimbot/warning_system.lua:            player.guid, banDuration, "Aimbot detected: " .. reason)
scripts/aimbot/warning_system.lua:        et.trap_SendConsoleCommand(et.EXEC_APPEND, banCmd)
scripts/aimbot/warning_system.lua:    else
scripts/aimbot/warning_system.lua:        -- Use standard ET:Legacy ban
scripts/aimbot/warning_system.lua:        local banCmd = string.format("clientkick %d \"Banned: Aimbot detected\"", clientNum)
scripts/aimbot/warning_system.lua:        et.trap_SendConsoleCommand(et.EXEC_APPEND, banCmd)
scripts/aimbot/warning_system.lua:        
scripts/aimbot/warning_system.lua:        -- Add to ban file if permanent
scripts/aimbot/warning_system.lua:        if isPermanent then
scripts/aimbot/warning_system.lua:            local banFileCmd = string.format("addip %s", player.ip)
scripts/aimbot/warning_system.lua:            et.trap_SendConsoleCommand(et.EXEC_APPEND, banFileCmd)
scripts/aimbot/warning_system.lua:        end
scripts/aimbot/warning_system.lua:    end
scripts/aimbot/warning_system.lua:end
scripts/aimbot/warning_system.lua:
scripts/aimbot/warning_system.lua:-- Check if warning cooldown has expired
scripts/aimbot/warning_system.lua:local function canWarnPlayer(player)
scripts/aimbot/warning_system.lua:    if not player then return false end
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    -- Skip cooldown check for first warning
scripts/aimbot/warning_system.lua:    if player.warnings == 0 then return true end
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    local currentTime = et.trap_Milliseconds()
scripts/aimbot/warning_system.lua:    local timeSinceLastWarning = currentTime - player.lastWarningTime
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    -- Check if cooldown has expired
scripts/aimbot/warning_system.lua:    return timeSinceLastWarning >= config.WARNING_COOLDOWN
scripts/aimbot/warning_system.lua:end
scripts/aimbot/warning_system.lua:
scripts/aimbot/warning_system.lua:-- Reset warnings for a player
scripts/aimbot/warning_system.lua:local function resetWarnings(clientNum)
scripts/aimbot/warning_system.lua:    local player = players[clientNum]
scripts/aimbot/warning_system.lua:    if not player then return end
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    local oldWarnings = player.warnings
scripts/aimbot/warning_system.lua:    player.warnings = 0
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    if oldWarnings > 0 then
scripts/aimbot/warning_system.lua:        debugLog("resetWarnings: Reset " .. oldWarnings .. " warnings for " .. player.name, 2)
scripts/aimbot/warning_system.lua:    end
scripts/aimbot/warning_system.lua:end
scripts/aimbot/warning_system.lua:
scripts/aimbot/warning_system.lua:-- Check if player should be warned based on detection confidence
scripts/aimbot/warning_system.lua:local function checkForWarning(clientNum, confidence, detectionCount, reason)
scripts/aimbot/warning_system.lua:    local player = players[clientNum]
scripts/aimbot/warning_system.lua:    if not player then return end
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    -- Skip if confidence is below threshold
scripts/aimbot/warning_system.lua:    if confidence < config.CONFIDENCE_THRESHOLD then
scripts/aimbot/warning_system.lua:        debugLog("checkForWarning: Confidence too low for " .. player.name .. " (" .. confidence .. " < " .. config.CONFIDENCE_THRESHOLD .. ")", 3)
scripts/aimbot/warning_system.lua:        return
scripts/aimbot/warning_system.lua:    end
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    -- Skip if not enough detection methods triggered
scripts/aimbot/warning_system.lua:    if detectionCount < 2 then
scripts/aimbot/warning_system.lua:        debugLog("checkForWarning: Not enough detection methods triggered for " .. player.name .. " (" .. detectionCount .. " < 2)", 3)
scripts/aimbot/warning_system.lua:        return
scripts/aimbot/warning_system.lua:    end
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    -- Skip if warning cooldown hasn't expired
scripts/aimbot/warning_system.lua:    if not canWarnPlayer(player) then
scripts/aimbot/warning_system.lua:        debugLog("checkForWarning: Warning cooldown not expired for " .. player.name, 3)
scripts/aimbot/warning_system.lua:        return
scripts/aimbot/warning_system.lua:    end
scripts/aimbot/warning_system.lua:    
scripts/aimbot/warning_system.lua:    -- Issue warning
scripts/aimbot/warning_system.lua:    warnPlayer(clientNum, reason)
scripts/aimbot/warning_system.lua:end
scripts/aimbot/warning_system.lua:
scripts/aimbot/warning_system.lua:-- Export functions
scripts/aimbot/warning_system.lua:    warnPlayer = warnPlayer,
scripts/aimbot/warning_system.lua:    banPlayer = banPlayer,
scripts/aimbot/warning_system.lua:    canWarnPlayer = canWarnPlayer,
scripts/aimbot/warning_system.lua:    resetWarnings = resetWarnings,
scripts/aimbot/warning_system.lua:    checkForWarning = checkForWarning
scripts/aimbot/warning_system.lua:end
scripts/aimbot/weapon_thresholds.lua:-- Weapon-specific thresholds for aimbot detection
scripts/aimbot/weapon_thresholds.lua:-- This module implements different detection thresholds for different weapon types
scripts/aimbot/weapon_thresholds.lua:
scripts/aimbot/weapon_thresholds.lua:-- Weapon-specific threshold configuration
scripts/aimbot/weapon_thresholds.lua:local weaponThresholds = {
scripts/aimbot/weapon_thresholds.lua:    -- Default thresholds
scripts/aimbot/weapon_thresholds.lua:    default = {
scripts/aimbot/weapon_thresholds.lua:        accuracy = 0.75,              -- Base accuracy threshold
scripts/aimbot/weapon_thresholds.lua:        headshot = 0.65,              -- Base headshot ratio threshold
scripts/aimbot/weapon_thresholds.lua:        angleChange = 160             -- Base angle change threshold
scripts/aimbot/weapon_thresholds.lua:    },
scripts/aimbot/weapon_thresholds.lua:    -- Sniper rifles (high accuracy expected)
scripts/aimbot/weapon_thresholds.lua:    weapon_K43 = {
scripts/aimbot/weapon_thresholds.lua:        accuracy = 0.85,
scripts/aimbot/weapon_thresholds.lua:        headshot = 0.8,
scripts/aimbot/weapon_thresholds.lua:        angleChange = 175
scripts/aimbot/weapon_thresholds.lua:    },
scripts/aimbot/weapon_thresholds.lua:    weapon_K43_scope = {
scripts/aimbot/weapon_thresholds.lua:        accuracy = 0.9,
scripts/aimbot/weapon_thresholds.lua:        headshot = 0.85,
scripts/aimbot/weapon_thresholds.lua:        angleChange = 175
scripts/aimbot/weapon_thresholds.lua:    },
scripts/aimbot/weapon_thresholds.lua:    weapon_FG42Scope = {
scripts/aimbot/weapon_thresholds.lua:        accuracy = 0.85,
scripts/aimbot/weapon_thresholds.lua:        headshot = 0.8,
scripts/aimbot/weapon_thresholds.lua:        angleChange = 175
scripts/aimbot/weapon_thresholds.lua:    },
scripts/aimbot/weapon_thresholds.lua:    -- Automatic weapons (medium accuracy expected)
scripts/aimbot/weapon_thresholds.lua:    weapon_MP40 = {
scripts/aimbot/weapon_thresholds.lua:        accuracy = 0.7,
scripts/aimbot/weapon_thresholds.lua:        headshot = 0.6,
scripts/aimbot/weapon_thresholds.lua:        angleChange = 160
scripts/aimbot/weapon_thresholds.lua:    },
scripts/aimbot/weapon_thresholds.lua:    weapon_Thompson = {
scripts/aimbot/weapon_thresholds.lua:        accuracy = 0.7,
scripts/aimbot/weapon_thresholds.lua:        headshot = 0.6,
scripts/aimbot/weapon_thresholds.lua:        angleChange = 160
scripts/aimbot/weapon_thresholds.lua:    },
scripts/aimbot/weapon_thresholds.lua:    weapon_Sten = {
scripts/aimbot/weapon_thresholds.lua:        accuracy = 0.7,
scripts/aimbot/weapon_thresholds.lua:        headshot = 0.6,
scripts/aimbot/weapon_thresholds.lua:        angleChange = 160
scripts/aimbot/weapon_thresholds.lua:    },
scripts/aimbot/weapon_thresholds.lua:    -- Pistols
scripts/aimbot/weapon_thresholds.lua:    weapon_Luger = {
scripts/aimbot/weapon_thresholds.lua:        accuracy = 0.8,
scripts/aimbot/weapon_thresholds.lua:        headshot = 0.7,
scripts/aimbot/weapon_thresholds.lua:        angleChange = 165
scripts/aimbot/weapon_thresholds.lua:    },
scripts/aimbot/weapon_thresholds.lua:    weapon_Colt = {
scripts/aimbot/weapon_thresholds.lua:        accuracy = 0.8,
scripts/aimbot/weapon_thresholds.lua:        headshot = 0.7,
scripts/aimbot/weapon_thresholds.lua:        angleChange = 165
scripts/aimbot/weapon_thresholds.lua:    },
scripts/aimbot/weapon_thresholds.lua:    -- Machine guns
scripts/aimbot/weapon_thresholds.lua:    weapon_MG42 = {
scripts/aimbot/weapon_thresholds.lua:        accuracy = 0.65,
scripts/aimbot/weapon_thresholds.lua:        headshot = 0.5,
scripts/aimbot/weapon_thresholds.lua:        angleChange = 150
scripts/aimbot/weapon_thresholds.lua:    },
scripts/aimbot/weapon_thresholds.lua:    -- Grenades and explosives (very low accuracy expected)
scripts/aimbot/weapon_thresholds.lua:    weapon_Grenade = {
scripts/aimbot/weapon_thresholds.lua:        accuracy = 0.4,
scripts/aimbot/weapon_thresholds.lua:        headshot = 0.1,
scripts/aimbot/weapon_thresholds.lua:        angleChange = 140
scripts/aimbot/weapon_thresholds.lua:    },
scripts/aimbot/weapon_thresholds.lua:    weapon_Panzerfaust = {
scripts/aimbot/weapon_thresholds.lua:        accuracy = 0.5,
scripts/aimbot/weapon_thresholds.lua:        headshot = 0.2,
scripts/aimbot/weapon_thresholds.lua:        angleChange = 145
scripts/aimbot/weapon_thresholds.lua:    }
scripts/aimbot/weapon_thresholds.lua:end
scripts/aimbot/weapon_thresholds.lua:
scripts/aimbot/weapon_thresholds.lua:-- Get weapon-specific threshold
scripts/aimbot/weapon_thresholds.lua:local function getWeaponThreshold(weapon, thresholdType)
scripts/aimbot/weapon_thresholds.lua:    if not config.WEAPON_SPECIFIC_THRESHOLDS then
scripts/aimbot/weapon_thresholds.lua:        -- Use global threshold if weapon-specific thresholds are disabled
scripts/aimbot/weapon_thresholds.lua:        if thresholdType == "accuracy" then
scripts/aimbot/weapon_thresholds.lua:            return config.ACCURACY_THRESHOLD
scripts/aimbot/weapon_thresholds.lua:        elseif thresholdType == "headshot" then
scripts/aimbot/weapon_thresholds.lua:            return config.HEADSHOT_RATIO_THRESHOLD
scripts/aimbot/weapon_thresholds.lua:        else
scripts/aimbot/weapon_thresholds.lua:            return config.ANGLE_CHANGE_THRESHOLD
scripts/aimbot/weapon_thresholds.lua:        end
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Use weapon-specific threshold if available
scripts/aimbot/weapon_thresholds.lua:    if weaponThresholds[weapon] and weaponThresholds[weapon][thresholdType] then
scripts/aimbot/weapon_thresholds.lua:        return weaponThresholds[weapon][thresholdType]
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Fall back to default weapon threshold
scripts/aimbot/weapon_thresholds.lua:    return weaponThresholds.default[thresholdType]
scripts/aimbot/weapon_thresholds.lua:end
scripts/aimbot/weapon_thresholds.lua:
scripts/aimbot/weapon_thresholds.lua:-- Get adjusted threshold based on player skill level
scripts/aimbot/weapon_thresholds.lua:local function getAdjustedThreshold(player, baseThreshold, thresholdType)
scripts/aimbot/weapon_thresholds.lua:    if not config.SKILL_ADAPTATION then return baseThreshold end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    local skillLevel = getPlayerSkillLevel(player)
scripts/aimbot/weapon_thresholds.lua:    local adjustment = config.SKILL_ADJUSTMENTS[skillLevel][thresholdType] or 0
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    return baseThreshold + adjustment
scripts/aimbot/weapon_thresholds.lua:end
scripts/aimbot/weapon_thresholds.lua:
scripts/aimbot/weapon_thresholds.lua:-- Initialize weapon stats for a player
scripts/aimbot/weapon_thresholds.lua:local function initWeaponStats(player, weapon)
scripts/aimbot/weapon_thresholds.lua:    if not player.weaponStats[weapon] then
scripts/aimbot/weapon_thresholds.lua:        player.weaponStats[weapon] = {
scripts/aimbot/weapon_thresholds.lua:            shots = 0,
scripts/aimbot/weapon_thresholds.lua:            hits = 0,
scripts/aimbot/weapon_thresholds.lua:            headshots = 0,
scripts/aimbot/weapon_thresholds.lua:            kills = 0,
scripts/aimbot/weapon_thresholds.lua:            accuracy = 0,
scripts/aimbot/weapon_thresholds.lua:            headshotRatio = 0
scripts/aimbot/weapon_thresholds.lua:        end
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:end
scripts/aimbot/weapon_thresholds.lua:
scripts/aimbot/weapon_thresholds.lua:-- Update weapon stats for a player
scripts/aimbot/weapon_thresholds.lua:local function updateWeaponStats(player, weapon, isHit, isHeadshot, isKill)
scripts/aimbot/weapon_thresholds.lua:    -- Initialize weapon stats if needed
scripts/aimbot/weapon_thresholds.lua:    initWeaponStats(player, weapon)
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Update stats
scripts/aimbot/weapon_thresholds.lua:    player.weaponStats[weapon].shots = player.weaponStats[weapon].shots + 1
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    if isHit then
scripts/aimbot/weapon_thresholds.lua:        player.weaponStats[weapon].hits = player.weaponStats[weapon].hits + 1
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    if isHeadshot then
scripts/aimbot/weapon_thresholds.lua:        player.weaponStats[weapon].headshots = player.weaponStats[weapon].headshots + 1
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    if isKill then
scripts/aimbot/weapon_thresholds.lua:        player.weaponStats[weapon].kills = player.weaponStats[weapon].kills + 1
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Calculate ratios
scripts/aimbot/weapon_thresholds.lua:    if player.weaponStats[weapon].shots > 0 then
scripts/aimbot/weapon_thresholds.lua:        player.weaponStats[weapon].accuracy = player.weaponStats[weapon].hits / player.weaponStats[weapon].shots
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    if player.weaponStats[weapon].kills > 0 then
scripts/aimbot/weapon_thresholds.lua:        player.weaponStats[weapon].headshotRatio = player.weaponStats[weapon].headshots / player.weaponStats[weapon].kills
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:end
scripts/aimbot/weapon_thresholds.lua:
scripts/aimbot/weapon_thresholds.lua:-- Check for suspicious accuracy with weapon-specific thresholds
scripts/aimbot/weapon_thresholds.lua:local function detectWeaponSpecificAccuracy(clientNum)
scripts/aimbot/weapon_thresholds.lua:    if not config.DETECT_ACCURACY or not config.WEAPON_SPECIFIC_THRESHOLDS then 
scripts/aimbot/weapon_thresholds.lua:        return false, 0 
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    local player = players[clientNum]
scripts/aimbot/weapon_thresholds.lua:    if not player then return false, 0 end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Get current weapon
scripts/aimbot/weapon_thresholds.lua:    local currentWeapon = player.lastWeapon or "default"
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Skip if we don't have enough data for this weapon
scripts/aimbot/weapon_thresholds.lua:    if not player.weaponStats[currentWeapon] or 
scripts/aimbot/weapon_thresholds.lua:       player.weaponStats[currentWeapon].shots < config.MIN_SAMPLES_REQUIRED then
scripts/aimbot/weapon_thresholds.lua:        return false, 0
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Get weapon-specific threshold
scripts/aimbot/weapon_thresholds.lua:    local baseAccuracyThreshold = getWeaponThreshold(currentWeapon, "accuracy")
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Apply skill-based adjustment
scripts/aimbot/weapon_thresholds.lua:    local accuracyThreshold = getAdjustedThreshold(player, baseAccuracyThreshold, "accuracy")
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Get weapon-specific accuracy
scripts/aimbot/weapon_thresholds.lua:    local weaponAccuracy = player.weaponStats[currentWeapon].accuracy
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    debugLog("detectWeaponSpecificAccuracy: " .. player.name .. " - weapon=" .. currentWeapon .. 
scripts/aimbot/weapon_thresholds.lua:             ", accuracy=" .. weaponAccuracy .. ", threshold=" .. accuracyThreshold, 2)
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Check if accuracy exceeds threshold
scripts/aimbot/weapon_thresholds.lua:    if weaponAccuracy > accuracyThreshold then
scripts/aimbot/weapon_thresholds.lua:        local confidence = (weaponAccuracy - accuracyThreshold) / (1 - accuracyThreshold)
scripts/aimbot/weapon_thresholds.lua:        return true, confidence, string.format("Suspicious %s accuracy (%.2f)", currentWeapon, weaponAccuracy)
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    return false, 0
scripts/aimbot/weapon_thresholds.lua:end
scripts/aimbot/weapon_thresholds.lua:
scripts/aimbot/weapon_thresholds.lua:-- Check for suspicious headshot ratio with weapon-specific thresholds
scripts/aimbot/weapon_thresholds.lua:local function detectWeaponSpecificHeadshotRatio(clientNum)
scripts/aimbot/weapon_thresholds.lua:    if not config.DETECT_HEADSHOT_RATIO or not config.WEAPON_SPECIFIC_THRESHOLDS then 
scripts/aimbot/weapon_thresholds.lua:        return false, 0 
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    local player = players[clientNum]
scripts/aimbot/weapon_thresholds.lua:    if not player then return false, 0 end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Get current weapon
scripts/aimbot/weapon_thresholds.lua:    local currentWeapon = player.lastWeapon or "default"
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Skip if we don't have enough data for this weapon
scripts/aimbot/weapon_thresholds.lua:    if not player.weaponStats[currentWeapon] or 
scripts/aimbot/weapon_thresholds.lua:       player.weaponStats[currentWeapon].kills < config.MIN_SAMPLES_REQUIRED / 2 then
scripts/aimbot/weapon_thresholds.lua:        return false, 0
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Get weapon-specific threshold
scripts/aimbot/weapon_thresholds.lua:    local baseHeadshotThreshold = getWeaponThreshold(currentWeapon, "headshot")
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Apply skill-based adjustment
scripts/aimbot/weapon_thresholds.lua:    local headshotThreshold = getAdjustedThreshold(player, baseHeadshotThreshold, "headshot")
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Get weapon-specific headshot ratio
scripts/aimbot/weapon_thresholds.lua:    local weaponHeadshotRatio = player.weaponStats[currentWeapon].headshotRatio
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    debugLog("detectWeaponSpecificHeadshotRatio: " .. player.name .. " - weapon=" .. currentWeapon .. 
scripts/aimbot/weapon_thresholds.lua:             ", headshotRatio=" .. weaponHeadshotRatio .. ", threshold=" .. headshotThreshold, 2)
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Check if headshot ratio exceeds threshold
scripts/aimbot/weapon_thresholds.lua:    if weaponHeadshotRatio > headshotThreshold then
scripts/aimbot/weapon_thresholds.lua:        local confidence = (weaponHeadshotRatio - headshotThreshold) / (1 - headshotThreshold)
scripts/aimbot/weapon_thresholds.lua:        return true, confidence, string.format("Suspicious %s headshot ratio (%.2f)", currentWeapon, weaponHeadshotRatio)
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    return false, 0
scripts/aimbot/weapon_thresholds.lua:end
scripts/aimbot/weapon_thresholds.lua:
scripts/aimbot/weapon_thresholds.lua:-- Integrate weapon-specific thresholds into the main detection system
scripts/aimbot/weapon_thresholds.lua:local function enhanceDetectionWithWeaponThresholds(clientNum, totalConfidence, detectionCount, reasons)
scripts/aimbot/weapon_thresholds.lua:    if not config.WEAPON_SPECIFIC_THRESHOLDS then
scripts/aimbot/weapon_thresholds.lua:        return totalConfidence, detectionCount, reasons
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Check for suspicious weapon-specific accuracy
scripts/aimbot/weapon_thresholds.lua:    local suspicious, confidence, reason = detectWeaponSpecificAccuracy(clientNum)
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    if suspicious then
scripts/aimbot/weapon_thresholds.lua:        totalConfidence = totalConfidence + confidence
scripts/aimbot/weapon_thresholds.lua:        detectionCount = detectionCount + 1
scripts/aimbot/weapon_thresholds.lua:        table.insert(reasons, reason)
scripts/aimbot/weapon_thresholds.lua:        
scripts/aimbot/weapon_thresholds.lua:        debugLog("enhanceDetectionWithWeaponThresholds: Detected suspicious weapon-specific accuracy for client " .. 
scripts/aimbot/weapon_thresholds.lua:                 clientNum .. " with confidence " .. confidence, 1)
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    -- Check for suspicious weapon-specific headshot ratio
scripts/aimbot/weapon_thresholds.lua:    suspicious, confidence, reason = detectWeaponSpecificHeadshotRatio(clientNum)
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    if suspicious then
scripts/aimbot/weapon_thresholds.lua:        totalConfidence = totalConfidence + confidence
scripts/aimbot/weapon_thresholds.lua:        detectionCount = detectionCount + 1
scripts/aimbot/weapon_thresholds.lua:        table.insert(reasons, reason)
scripts/aimbot/weapon_thresholds.lua:        
scripts/aimbot/weapon_thresholds.lua:        debugLog("enhanceDetectionWithWeaponThresholds: Detected suspicious weapon-specific headshot ratio for client " .. 
scripts/aimbot/weapon_thresholds.lua:                 clientNum .. " with confidence " .. confidence, 1)
scripts/aimbot/weapon_thresholds.lua:    end
scripts/aimbot/weapon_thresholds.lua:    
scripts/aimbot/weapon_thresholds.lua:    return totalConfidence, detectionCount, reasons
scripts/aimbot/weapon_thresholds.lua:end
scripts/aimbot/weapon_thresholds.lua:
scripts/aimbot/weapon_thresholds.lua:-- Export functions and data
scripts/aimbot/weapon_thresholds.lua:    weaponThresholds = weaponThresholds,
scripts/aimbot/weapon_thresholds.lua:    getWeaponThreshold = getWeaponThreshold,
scripts/aimbot/weapon_thresholds.lua:    getAdjustedThreshold = getAdjustedThreshold,
scripts/aimbot/weapon_thresholds.lua:    initWeaponStats = initWeaponStats,
scripts/aimbot/weapon_thresholds.lua:    updateWeaponStats = updateWeaponStats,
scripts/aimbot/weapon_thresholds.lua:    detectWeaponSpecificAccuracy = detectWeaponSpecificAccuracy,
scripts/aimbot/weapon_thresholds.lua:    detectWeaponSpecificHeadshotRatio = detectWeaponSpecificHeadshotRatio,
scripts/aimbot/weapon_thresholds.lua:    enhanceDetectionWithWeaponThresholds = enhanceDetectionWithWeaponThresholds
scripts/aimbot/weapon_thresholds.lua:end
