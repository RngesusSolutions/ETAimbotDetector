-- ETAimbotDetector
-- A Lua script for ET:Legacy servers that detects and bans players using aimbots.
-- Enhanced version with improved detection algorithms and configurable thresholds.

-- ETAimbotDetector - Enhanced with micro-movement detection
-- A Lua script for ET:Legacy servers that detects and bans players using aimbots.
-- This version includes advanced micro-movement detection for humanized aimbots

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

-- Check if player is an OMNIBOT
local function isOmniBot(guid)
    if not guid then return false end
    return string.find(string.lower(guid), "omnibot") ~= nil
end

-- Get player skill level based on XP
local function getPlayerSkillLevel(player)
    if not config.SKILL_ADAPTATION then return "REGULAR" end
    
    local xp = player.xp or 0
    
    if xp >= config.SKILL_LEVELS.EXPERT then
        return "EXPERT"
    elseif xp >= config.SKILL_LEVELS.SKILLED then
        return "SKILLED"
    elseif xp >= config.SKILL_LEVELS.REGULAR then
        return "REGULAR"
    else
        return "NOVICE"
    end
end

-- Get adjusted threshold based on player skill level
local function getAdjustedThreshold(player, baseThreshold, thresholdType)
    if not config.SKILL_ADAPTATION then return baseThreshold end
    
    local skillLevel = getPlayerSkillLevel(player)
    local adjustment = config.SKILL_ADJUSTMENTS[skillLevel][thresholdType] or 0
    
    return baseThreshold + adjustment
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
