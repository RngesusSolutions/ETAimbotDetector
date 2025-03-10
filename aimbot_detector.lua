-- ETAimbotDetector
-- A Lua script for ET:Legacy servers that detects and bans players using aimbots.

-- Configuration variables
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
    },
    -- Machine guns
    weapon_MG42 = {
        accuracy = 0.65,
        headshot = 0.5,
        angleChange = 150
    }
}

-- Player data storage
local players = {}

-- Initialize global variables
local lastStatsLogTime = 0
local lastXPUpdateTime = 0
-- Check if player is an OMNIBOT
local function isOmniBot(guid)
    if not guid then return false end
    return string.find(string.lower(guid), "omnibot") ~= nil
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

-- Debug logging function
local function debugLog(message, level)
    level = level or 1 -- Default to level 1 if not specified
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local debugMessage = string.format("[DEBUG-%d %s] %s", level, timestamp, message)
    
    -- Write to log file if debug mode is enabled
    if config.DEBUG_MODE and level <= config.DEBUG_LEVEL then
        -- Write to log file for persistent debugging
        local logDir = ensureLogDirExists()
        local file = io.open(logDir .. "aimbot_debug.log", "a")
        if file then
            file:write(debugMessage .. "\n")
            file:close()
        else
            et.G_Print("Warning: Could not open debug log file: " .. logDir .. "aimbot_debug.log\n")
        end
    end
    
    -- Print to server console if server console debug is enabled
    if config.SERVER_CONSOLE_DEBUG and level <= config.SERVER_CONSOLE_DEBUG_LEVEL then
        et.G_Print(debugMessage .. "\n")
    end
end

-- Log detection event
local function logDetection(player, confidence, detectionCount, aimbotType, reason)
    if not player then return end
    
    local detectionMessage = string.format("DETECTION: Player %s (%s) - confidence: %.2f, detections: %d, type: %s, reason: %s", 
        player.name, player.guid, confidence, detectionCount, aimbotType, reason)
    
    log(1, detectionMessage)
end

-- Log warning event
local function logWarning(player, reason)
    if not player then return end
    
    local warningMessage = string.format("WARNING: Player %s (%s) - warning %d/%d, reason: %s", 
        player.name, player.guid, player.warnings, config.MAX_WARNINGS, reason)
    
    log(1, warningMessage)
end

-- Log ban event
local function logBan(player, isPermanent, reason)
    if not player then return end
    
    local banMessage = string.format("BAN: Player %s (%s) - %s ban, reason: %s", 
        player.name, player.guid, isPermanent and "permanent" or "temporary", reason)
    
    log(1, banMessage)
end

-- Log player stats for debugging
local function logPlayerStats(player)
    if not player or config.DEBUG_LEVEL < 3 then return end
    
    local statsMessage = string.format("STATS: Player %s - shots: %d, hits: %d, headshots: %d, accuracy: %.2f, headshot ratio: %.2f", 
        player.name, player.shots, player.hits, player.headshots, 
        player.shots > 0 and player.hits / player.shots or 0,
        player.kills > 0 and player.headshots / player.kills or 0)
    
    debugLog(statsMessage, 3)
    
    -- Log weapon-specific stats
    for weapon, stats in pairs(player.weaponStats) do
        local weaponStatsMessage = string.format("WEAPON STATS: Player %s - weapon: %s, shots: %d, hits: %d, headshots: %d, accuracy: %.2f, headshot ratio: %.2f", 
            player.name, weapon, stats.shots, stats.hits, stats.headshots,
            stats.shots > 0 and stats.hits / stats.shots or 0,
            stats.kills > 0 and stats.headshots / stats.kills or 0)
        
        debugLog(weaponStatsMessage, 3)
    end
end

-- Log system startup
local function logStartup()
    log(1, "ETAimbotDetector initialized")
    
    -- Log configuration
    if config.DEBUG_MODE and config.DEBUG_LEVEL >= 2 then
        debugLog("Configuration:", 2)
        for key, value in pairs(config) do
            if type(value) ~= "table" then
                debugLog("  " .. key .. " = " .. tostring(value), 2)
            else
                debugLog("  " .. key .. " = [table]", 2)
            end
        end
    end
end

-- Helper function to convert callback parameters to numbers
local function convertParams(...)
    local result = {}
    for i, param in ipairs({...}) do
        result[i] = tonumber(param) or 0
    end
    return table.unpack(result)
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
    
    -- Get current view angles if available
    local ps = et.gentity_get(clientNum, "ps.viewangles")
    local initialAngle = {pitch = 0, yaw = 0}
    
    -- Use actual angles if available
    if ps then
        initialAngle = {
            pitch = ps[0],
            yaw = ps[1]
        }
    end
    
    players[clientNum] = {
        name = name,
        guid = guid,
        ip = ip,
        
        -- Tracking variables
        lastAngle = initialAngle, -- Ensure lastAngle is properly initialized
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
        rank = 0,
        
        -- Stats logging
        lastStatsLogTime = 0,
        
        -- OMNIBOT tracking
        lastOmnibotLogTime = 0,
        
        -- Insufficient data tracking
        lastInsufficientDataLogTime = 0
    }
    
    -- Log if this is an OMNIBOT
    if config.IGNORE_OMNIBOTS and isOmniBot(guid) then
        debugLog("Initialized OMNIBOT player: " .. name .. " (GUID: " .. guid .. ")", 1)
    else
        debugLog("Player initialized: " .. name .. " (GUID: " .. guid .. ")", 1)
    end
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
    
    -- Initialize lastAngle if it doesn't exist or has nil values
    if not player.lastAngle or not player.lastAngle.pitch or not player.lastAngle.yaw then
        player.lastAngle = {pitch = 0, yaw = 0}
        player.lastAngle = currentAngle
        return -- Skip angle change calculation on first update
    end
    
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
    
    -- Notify all players
    local banMessage = string.format("^1ANTI-CHEAT^7: Player %s ^7has been %s banned for aimbot", 
        player.name, isPermanent and "permanently" or "temporarily")
    et.trap_SendServerCommand(-1, "chat \"" .. banMessage .. "\"")
    
    -- Execute ban command
    if config.USE_SHRUBBOT_BANS then
        -- Use shrubbot ban command if available
        local banCmd = string.format("!ban %s %d %s", 
            player.guid, banDuration, "Aimbot detected: " .. reason)
        et.trap_SendConsoleCommand(et.EXEC_APPEND, banCmd)
    else
        -- Use standard ET:Legacy ban
        local banCmd = string.format("clientkick %d \"Banned: Aimbot detected\"", clientNum)
        et.trap_SendConsoleCommand(et.EXEC_APPEND, banCmd)
        
        -- Add to ban file if permanent
        if isPermanent then
            local banFileCmd = string.format("addip %s", player.ip)
            et.trap_SendConsoleCommand(et.EXEC_APPEND, banFileCmd)
        end
    end
    
    -- Log ban event
    logBan(player, isPermanent, reason)
end

-- Issue warning to player
local function warnPlayer(clientNum, reason)
    local player = players[clientNum]
    if not player then return end
    
    player.warnings = player.warnings + 1
    player.lastWarningTime = et.trap_Milliseconds()
    
    local warningMessage = string.format("^1WARNING^7: Suspicious activity detected (%s). Warning %d/%d", 
        reason, player.warnings, config.MAX_WARNINGS)
    
    -- Send center-print message to player if this is beyond the warning threshold
    if player.warnings >= config.WARN_THRESHOLD then
        et.trap_SendServerCommand(clientNum, "cp " .. warningMessage)
        
        -- Send chat message to player if enabled
        if config.CHAT_WARNINGS then
            et.trap_SendServerCommand(clientNum, "chat \"" .. warningMessage .. "\"")
        end
    end
    
    -- Notify admins
    if config.NOTIFY_ADMINS then
        local adminMessage = string.format("^3ANTI-CHEAT^7: Player %s ^7suspected of aimbot (%s)", 
            player.name, reason)
        
        -- Send to all admins (clients with admin flag)
        local maxClients = tonumber(et.trap_Cvar_Get("sv_maxclients")) or 64 -- Convert to number with fallback
        for i = 0, maxClients - 1 do
            if et.gentity_get(i, "inuse") and et.G_shrubbot_permission(i, "a") then
                et.trap_SendServerCommand(i, "chat \"" .. adminMessage .. "\"")
            end
        end
    end
    
    -- Log warning
    logWarning(player, reason)
    
    -- Check if player should be banned
    if player.warnings >= config.MAX_WARNINGS and config.ENABLE_BANS then
        banPlayer(clientNum, reason)
    end
end

-- Check if warning cooldown has expired
local function canWarnPlayer(player)
    if not player then return false end
    
    -- Skip cooldown check for first warning
    if player.warnings == 0 then return true end
    
    local currentTime = et.trap_Milliseconds()
    local timeSinceLastWarning = currentTime - player.lastWarningTime
    
    -- Check if cooldown has expired
    return timeSinceLastWarning >= config.WARNING_COOLDOWN
end
-- Check for micro-movements (humanized aimbot detection)
local function detectMicroMovements(clientNum)
    if not config.MICRO_MOVEMENT_DETECTION then return false, 0 end
    
    local player = players[clientNum]
    if not player or #player.angleChanges < config.MIN_SAMPLES_REQUIRED then
        return false, 0
    end
    
    local microMovementCount = 0
    local microMovementSequence = 0
    local maxMicroMovementSequence = 0
    
    -- Analyze angle changes for micro-movement patterns
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
    
    -- Calculate standard deviation of micro-movements
    local microMovements = {}
    for i = 2, #player.angleChanges do
        if player.angleChanges[i] >= 5 and player.angleChanges[i] <= 20 then
            table.insert(microMovements, player.angleChanges[i])
        end
    end
    
    local microMovementAvg = 0
    local microMovementStdDev = 0
    
    if #microMovements > 0 then
        -- Calculate average
        local sum = 0
        for _, v in ipairs(microMovements) do
            sum = sum + v
        end
        microMovementAvg = sum / #microMovements
        
        -- Calculate standard deviation
        microMovementStdDev = calculateStdDev(microMovements, microMovementAvg)
    end
    
    debugLog("detectMicroMovements: " .. player.name .. " - microMovements=" .. microMovementCount .. 
             ", maxSequence=" .. maxMicroMovementSequence .. 
             ", avg=" .. microMovementAvg .. 
             ", stdDev=" .. microMovementStdDev, 2)
    
    -- Calculate confidence score based on micro-movement patterns
    local confidence = 0
    local reason = ""
    
    -- Suspicious pattern: Many micro-movements with low standard deviation
    if microMovementCount >= config.MICRO_MOVEMENT_MIN_COUNT and 
       maxMicroMovementSequence >= config.MICRO_MOVEMENT_MIN_SEQUENCE and 
       microMovementStdDev < config.MICRO_MOVEMENT_MAX_STDDEV then
        confidence = 0.8
        reason = string.format("Highly suspicious micro-movement pattern (count: %d, sequence: %d, stdDev: %.2f°)", 
            microMovementCount, maxMicroMovementSequence, microMovementStdDev)
        return true, confidence, reason
    -- Moderately suspicious: Several micro-movements with moderate standard deviation
    elseif microMovementCount >= config.MICRO_MOVEMENT_MIN_COUNT and 
           maxMicroMovementSequence >= config.MICRO_MOVEMENT_MIN_SEQUENCE and 
           microMovementStdDev < config.MICRO_MOVEMENT_MAX_STDDEV * 1.5 then
        confidence = 0.6
        reason = string.format("Suspicious micro-movement pattern (count: %d, sequence: %d, stdDev: %.2f°)", 
            microMovementCount, maxMicroMovementSequence, microMovementStdDev)
        return true, confidence, reason
    end
    
    return false, 0
end

-- Detect flick shot patterns with timing analysis
local function detectFlickPattern(clientNum)
    local player = players[clientNum]
    if not player or #player.angleChanges < 10 then return false, 0 end
    
    local flicks = 0
    local quickHits = 0
    local suspiciousFlicks = 0
    
    -- Analyze angle changes for flick patterns
    for i = 2, #player.angleChanges do
        -- Flicks are large, sudden angle changes
        if player.angleChanges[i] >= config.FLICK_ANGLE_THRESHOLD then
            flicks = flicks + 1
            
            -- Check if this flick was followed by a hit within a short time
            if player.hitTimings[i] and 
               player.hitTimings[i] - player.shotTimings[i] <= config.QUICK_HIT_THRESHOLD then
                quickHits = quickHits + 1
            end
            
            -- Check for suspicious flick patterns (large angle change followed by small adjustment)
            if i < #player.angleChanges and 
               player.angleChanges[i+1] >= config.FLICK_ADJUSTMENT_MIN and 
               player.angleChanges[i+1] <= config.FLICK_ADJUSTMENT_MAX then
                suspiciousFlicks = suspiciousFlicks + 1
            end
        end
    end
    
    debugLog("detectFlickPattern: " .. player.name .. " - flicks=" .. flicks .. 
             ", quickHits=" .. quickHits .. 
             ", suspiciousFlicks=" .. suspiciousFlicks, 2)
    
    -- Calculate confidence score based on flick patterns
    local confidence = 0
    local reason = ""
    
    -- Highly suspicious: Many flicks with quick hits and suspicious adjustments
    if flicks >= 5 and quickHits >= 3 and suspiciousFlicks >= 2 then
        confidence = 0.85
        reason = string.format("Highly suspicious flick pattern (flicks: %d, quickHits: %d, suspiciousFlicks: %d)", 
            flicks, quickHits, suspiciousFlicks)
        return true, confidence, reason
    -- Moderately suspicious: Several flicks with quick hits
    elseif flicks >= 3 and quickHits >= 2 then
        confidence = 0.65
        reason = string.format("Suspicious flick pattern (flicks: %d, quickHits: %d)", 
            flicks, quickHits)
        return true, confidence, reason
    end
    
    return false, 0
end

-- Detect suspicious accuracy
local function detectAccuracy(clientNum)
    if not config.DETECT_ACCURACY then return false, 0 end
    
    local player = players[clientNum]
    if not player or player.shots < config.MIN_SAMPLES_REQUIRED then
        return false, 0
    end
    
    -- Calculate accuracy
    local accuracy = player.hits / player.shots
    
    -- Get weapon-specific threshold
    local accuracyThreshold = getWeaponThreshold(player.lastWeapon, "accuracy")
    
    -- Adjust threshold based on player skill level
    accuracyThreshold = getAdjustedThreshold(player, accuracyThreshold, "accuracy")
    
    debugLog("detectAccuracy: " .. player.name .. " - accuracy=" .. accuracy .. 
             ", threshold=" .. accuracyThreshold, 2)
    
    -- Check if accuracy exceeds threshold
    if accuracy > accuracyThreshold then
        local confidence = (accuracy - accuracyThreshold) / (1 - accuracyThreshold) * 0.8
        local reason = string.format("Suspicious accuracy (%.2f > %.2f threshold)", 
            accuracy, accuracyThreshold)
        return true, confidence, reason
    end
    
    return false, 0
end

-- Detect suspicious headshot ratio
local function detectHeadshotRatio(clientNum)
    if not config.DETECT_HEADSHOT_RATIO then return false, 0 end
    
    local player = players[clientNum]
    if not player or player.kills < config.MIN_SAMPLES_REQUIRED then
        return false, 0
    end
    
    -- Calculate headshot ratio
    local headshotRatio = player.headshots / player.kills
    
    -- Get weapon-specific threshold
    local headshotThreshold = getWeaponThreshold(player.lastWeapon, "headshot")
    
    -- Adjust threshold based on player skill level
    headshotThreshold = getAdjustedThreshold(player, headshotThreshold, "headshot")
    
    debugLog("detectHeadshotRatio: " .. player.name .. " - headshotRatio=" .. headshotRatio .. 
             ", threshold=" .. headshotThreshold, 2)
    
    -- Check if headshot ratio exceeds threshold
    if headshotRatio > headshotThreshold then
        local confidence = (headshotRatio - headshotThreshold) / (1 - headshotThreshold) * 0.8
        local reason = string.format("Suspicious headshot ratio (%.2f > %.2f threshold)", 
            headshotRatio, headshotThreshold)
        return true, confidence, reason
    end
    
    return false, 0
end

-- Detect suspicious angle changes
local function detectAngleChanges(clientNum)
    if not config.DETECT_ANGLE_CHANGES then return false, 0 end
    
    local player = players[clientNum]
    if not player or #player.angleChanges < config.MIN_SAMPLES_REQUIRED then
        return false, 0
    end
    
    -- Calculate average angle change
    local sum = 0
    for _, v in ipairs(player.angleChanges) do
        sum = sum + v
    end
    local avgAngleChange = sum / #player.angleChanges
    
    -- Calculate standard deviation
    local stdDev = calculateStdDev(player.angleChanges, avgAngleChange)
    
    -- Store statistical data
    player.avgAngleChange = avgAngleChange
    player.stdDevAngleChange = stdDev
    
    -- Get weapon-specific threshold
    local angleChangeThreshold = getWeaponThreshold(player.lastWeapon, "angleChange")
    
    debugLog("detectAngleChanges: " .. player.name .. " - avgAngleChange=" .. avgAngleChange .. 
             ", stdDev=" .. stdDev .. 
             ", threshold=" .. angleChangeThreshold, 2)
    
    -- Check for suspicious angle changes
    local suspiciousChanges = 0
    for _, v in ipairs(player.angleChanges) do
        if v > angleChangeThreshold then
            suspiciousChanges = suspiciousChanges + 1
        end
    end
    
    -- Calculate percentage of suspicious angle changes
    local suspiciousPercentage = suspiciousChanges / #player.angleChanges
    
    -- Check if percentage exceeds threshold
    if suspiciousPercentage > 0.3 then
        local confidence = suspiciousPercentage * 0.8
        local reason = string.format("Suspicious angle changes (%.2f%% > 30%% threshold, avg: %.2f°)", 
            suspiciousPercentage * 100, avgAngleChange)
        return true, confidence, reason
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
    
    -- Skip if player is an OMNIBOT and OMNIBOT detection is enabled
    if config.IGNORE_OMNIBOTS and isOmniBot(player.guid) then
        debugLog("calculateAimbotConfidence: Skipping OMNIBOT player " .. player.name, 2)
        return 0, 0, "OMNIBOT", ""
    end
    
    debugLog("calculateAimbotConfidence: Analyzing player " .. player.name .. " (shots: " .. player.shots .. ", hits: " .. player.hits .. ", headshots: " .. player.headshots .. ")", 2)
    
    -- Initialize detection variables
    local totalConfidence = 0
    local detectionCount = 0
    local reasons = {}
    
    -- Check for micro-movements (humanized aimbot detection)
    local isSuspicious, confidence, reason = detectMicroMovements(clientNum)
    if isSuspicious then
        totalConfidence = totalConfidence + confidence
        detectionCount = detectionCount + 1
        table.insert(reasons, reason)
        player.humanizedAimbotConfidence = confidence
    end
    
    -- Check for flick patterns
    isSuspicious, confidence, reason = detectFlickPattern(clientNum)
    if isSuspicious then
        totalConfidence = totalConfidence + confidence
        detectionCount = detectionCount + 1
        table.insert(reasons, reason)
        player.aimbotConfidence = confidence
    end
    
    -- Check for suspicious accuracy
    isSuspicious, confidence, reason = detectAccuracy(clientNum)
    if isSuspicious then
        totalConfidence = totalConfidence + confidence
        detectionCount = detectionCount + 1
        table.insert(reasons, reason)
    end
    
    -- Check for suspicious headshot ratio
    isSuspicious, confidence, reason = detectHeadshotRatio(clientNum)
    if isSuspicious then
        totalConfidence = totalConfidence + confidence
        detectionCount = detectionCount + 1
        table.insert(reasons, reason)
    end
    
    -- Check for suspicious angle changes
    isSuspicious, confidence, reason = detectAngleChanges(clientNum)
    if isSuspicious then
        totalConfidence = totalConfidence + confidence
        detectionCount = detectionCount + 1
        table.insert(reasons, reason)
    end
    
    -- Calculate average confidence
    local avgConfidence = 0
    if detectionCount > 0 then
        avgConfidence = totalConfidence / detectionCount
    end
    
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
        -- Only log this occasionally to avoid spamming the console
        local currentTime = et.trap_Milliseconds()
        if not player.lastInsufficientDataLogTime or currentTime - player.lastInsufficientDataLogTime >= 60000 then -- Log once per minute
            debugLog("runDetection: Skipping " .. player.name .. " - insufficient data (" .. player.shots .. "/" .. config.MIN_SAMPLES_REQUIRED .. " shots)", 2)
            player.lastInsufficientDataLogTime = currentTime
        end
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
        if canWarnPlayer(player) then
            warnPlayer(clientNum, reason)
        end
    else
        debugLog("runDetection: No aimbot detected for " .. player.name .. " - confidence: " .. confidence .. ", detections: " .. detectionCount, 2)
    end
end
-- ET:Legacy callback: InitGame
function et_InitGame(levelTime, randomSeed, restart)
    -- Register the module
    et.RegisterModname("ETAimbotDetector")
    et.G_Print("^3ETAimbotDetector^7 loaded\n")
    et.G_Print("^3ETAimbotDetector^7: Monitoring for suspicious aim patterns\n")
    
    -- Create log directory with error handling
    pcall(ensureLogDirExists)
    
    -- Log initialization
    pcall(logStartup)
end

-- ET:Legacy callback: ClientConnect
function et_ClientConnect(clientNum, firstTime, isBot)
    -- Debug log parameter types before conversion
    debugLog("et_ClientConnect parameters before conversion: clientNum=" .. type(clientNum) .. ":" .. tostring(clientNum) .. 
             ", firstTime=" .. type(firstTime) .. ":" .. tostring(firstTime) .. 
             ", isBot=" .. type(isBot) .. ":" .. tostring(isBot), 3)
    
    -- Convert all parameters to numbers using helper function
    clientNum, firstTime, isBot = convertParams(clientNum, firstTime, isBot)
    
    -- Initialize player data when a client connects
    initPlayerData(clientNum)
    
    return nil -- Allow connection
end

-- ET:Legacy callback: ClientDisconnect
function et_ClientDisconnect(clientNum)
    -- Debug log parameter types before conversion
    debugLog("et_ClientDisconnect parameters before conversion: clientNum=" .. type(clientNum) .. ":" .. tostring(clientNum), 3)
    
    -- Convert parameters to numbers using helper function
    clientNum = convertParams(clientNum)
    
    -- Log player stats before they disconnect
    if players[clientNum] then
        logPlayerStats(players[clientNum])
        players[clientNum] = nil
    end
end

-- ET:Legacy callback: ClientUserinfoChanged
function et_ClientUserinfoChanged(clientNum)
    -- Debug log parameter types before conversion
    debugLog("et_ClientUserinfoChanged parameters before conversion: clientNum=" .. type(clientNum) .. ":" .. tostring(clientNum), 3)
    
    -- Convert parameters to numbers using helper function
    clientNum = convertParams(clientNum)
    
    -- Update player info if they change their name or other userinfo
    if players[clientNum] then
        local userinfo = et.trap_GetUserinfo(clientNum)
        local name = et.Info_ValueForKey(userinfo, "name")
        players[clientNum].name = name
    else
        -- Initialize player if they don't exist yet
        initPlayerData(clientNum)
    end
end

-- ET:Legacy callback: Damage
function et_Damage(target, attacker, damage, dflags, mod)
    -- Debug log parameter types before conversion
    debugLog("et_Damage parameters before conversion: target=" .. type(target) .. ":" .. tostring(target) .. 
             ", attacker=" .. type(attacker) .. ":" .. tostring(attacker) .. 
             ", dflags=" .. type(dflags) .. ":" .. tostring(dflags), 3)
    
    -- Convert all parameters to numbers using helper function
    target, attacker, damage, dflags, mod = convertParams(target, attacker, damage, dflags, mod)
    
    -- Skip if attacker is invalid or not a player
    local maxClients = tonumber(et.trap_Cvar_Get("sv_maxclients")) or 64 -- Convert to number with fallback
    if attacker < 0 or attacker >= maxClients then
        return
    end
    
    -- Skip if target is invalid or not a player
    if target < 0 or target >= maxClients then
        return
    end
    
    -- Skip if attacker is the same as target (self damage)
    if attacker == target then
        return
    end
    
    -- Initialize player data if needed
    if not players[attacker] then
        initPlayerData(attacker)
    end
    
    local player = players[attacker]
    
    -- Update hit count
    player.hits = player.hits + 1
    
    -- Update consecutive hits
    player.consecutiveHits = player.consecutiveHits + 1
    
    -- Check if this was a headshot (bitwise operation on already converted dflags)
    local isHeadshot = (dflags & 32) ~= 0
    if isHeadshot then
        player.headshots = player.headshots + 1
    end
    
    -- Get current weapon
    local weapon = et.gentity_get(attacker, "s.weapon")
    local weapon_num = tonumber(weapon) or 0  -- Convert to number with fallback
    local weaponName = "weapon_" .. weapon_num
    player.lastWeapon = weaponName
    
    -- Debug log weapon information
    debugLog("et_Damage weapon info: raw=" .. tostring(weapon) .. ", converted=" .. weapon_num, 3)
    
    -- Update weapon-specific stats
    updateWeaponStats(player, weaponName, true, isHeadshot, false)
    
    -- Record hit timing
    local currentTime = et.trap_Milliseconds()
    table.insert(player.hitTimings, currentTime)
    
    -- Keep only the last 50 hit timings
    if #player.hitTimings > 50 then
        table.remove(player.hitTimings, 1)
    end
    
    -- Record target switch if different from last target
    -- Ensure lastTarget is a number for comparison
    local lastTarget_num = tonumber(player.lastTarget) or -1
    
    if lastTarget_num ~= target then
        local targetSwitch = {
            from = lastTarget_num,
            to = target,
            time = currentTime
        }
        
        if lastTarget_num ~= -1 then
            table.insert(player.targetSwitches, targetSwitch)
            
            -- Keep only the last 20 target switches
            if #player.targetSwitches > 20 then
                table.remove(player.targetSwitches, 1)
            end
        end
        
        player.lastTarget = target
        player.lastTargetTime = currentTime
    end
end

-- ET:Legacy callback: Obituary
function et_Obituary(victim, killer, mod)
    -- Debug log parameter types before conversion
    debugLog("et_Obituary parameters before conversion: victim=" .. type(victim) .. ":" .. tostring(victim) .. 
             ", killer=" .. type(killer) .. ":" .. tostring(killer) .. 
             ", mod=" .. type(mod) .. ":" .. tostring(mod), 3)
    
    -- Convert all parameters to numbers using helper function
    victim, killer, mod = convertParams(victim, killer, mod)
    
    -- Skip if killer is invalid or not a player
    local maxClients = tonumber(et.trap_Cvar_Get("sv_maxclients")) or 64 -- Convert to number with fallback
    if killer < 0 or killer >= maxClients then
        return
    end
    
    -- Skip if victim is invalid or not a player
    if victim < 0 or victim >= maxClients then
        return
    end
    
    -- Skip if killer is the same as victim (suicide)
    if killer == victim then
        return
    end
    
    -- Initialize player data if needed
    if not players[killer] then
        initPlayerData(killer)
    end
    
    local player = players[killer]
    
    -- Update kill count
    player.kills = player.kills + 1
    
    -- Get current weapon
    local weapon = et.gentity_get(killer, "s.weapon")
    local weapon_num = tonumber(weapon) or 0  -- Convert to number with fallback
    local weaponName = "weapon_" .. weapon_num
    
    -- Update weapon-specific stats
    updateWeaponStats(player, weaponName, false, false, true)
end

-- ET:Legacy callback: FireWeapon
function et_FireWeapon(clientNum, weapon)
    -- Debug log parameter types before conversion
    debugLog("et_FireWeapon parameters before conversion: clientNum=" .. type(clientNum) .. ":" .. tostring(clientNum) .. 
             ", weapon=" .. type(weapon) .. ":" .. tostring(weapon), 3)
    
    -- Convert all parameters to numbers using helper function
    clientNum, weapon = convertParams(clientNum, weapon)
    
    -- Initialize player data if needed
    if not players[clientNum] then
        initPlayerData(clientNum)
    end
    
    local player = players[clientNum]
    
    -- Update shot count
    player.shots = player.shots + 1
    
    -- Reset consecutive hits on new shot
    player.consecutiveHits = 0
    
    -- Get weapon name (convert weapon to number to prevent string comparison errors)
    local weapon_num = tonumber(weapon) or 0  -- Convert to number with fallback
    local weaponName = "weapon_" .. weapon_num
    player.lastWeapon = weaponName
    
    -- Update weapon-specific stats
    updateWeaponStats(player, weaponName, false, false, false)
    
    -- Record shot timing
    local currentTime = et.trap_Milliseconds()
    player.lastShotTime = currentTime
    
    table.insert(player.shotTimings, currentTime)
    
    -- Keep only the last 50 shot timings
    if #player.shotTimings > 50 then
        table.remove(player.shotTimings, 1)
    end
end

-- ET:Legacy callback: RunFrame
function et_RunFrame(levelTime)
    -- Debug log parameter types before conversion
    debugLog("et_RunFrame parameters before conversion: levelTime=" .. type(levelTime) .. ":" .. tostring(levelTime), 3)
    
    -- Convert parameters to numbers using helper function
    levelTime = convertParams(levelTime)
    
    -- Ensure players table exists
    if not players then
        players = {}
        et.G_Print("^3ETAimbotDetector^7: Initialized players table\n")
    end
    
    -- Process each player
    local maxClients = tonumber(et.trap_Cvar_Get("sv_maxclients")) or 64 -- Convert to number with fallback
    for clientNum = 0, maxClients - 1 do
        if et.gentity_get(clientNum, "inuse") then
            -- Initialize player data if needed
            if not players[clientNum] then
                initPlayerData(clientNum)
            end
            
            local player = players[clientNum]
            if not player then
                et.G_Print("^1ETAimbotDetector^7: Error - Failed to initialize player " .. clientNum .. "\n")
                goto continue
            end
            
            -- Skip all detection logic for OMNIBOT players
            if config.IGNORE_OMNIBOTS and isOmniBot(player.guid) then
                -- Only log this occasionally to avoid spamming the console
                local currentTime = et.trap_Milliseconds()
                if not player.lastOmnibotLogTime or currentTime - player.lastOmnibotLogTime >= 60000 then -- Log once per minute
                    debugLog("Skipping all detection for OMNIBOT player: " .. player.name, 1)
                    player.lastOmnibotLogTime = currentTime
                end
                goto continue
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
            
            ::continue::
        end
    end
    
    -- Update player XP periodically
    local currentTime = et.trap_Milliseconds()
    if config.SKILL_ADAPTATION and currentTime - lastXPUpdateTime >= config.SKILL_XP_UPDATE_INTERVAL then
        for clientNum, player in pairs(players) do
            if et.gentity_get(clientNum, "inuse") then
                -- Try to get player XP from ET:Legacy using alternative methods
                -- Since "sess.stats" is not a valid field, we'll use a safer approach
                local xp = 0
                local rank = 0
                
                -- Try to get rank directly
                pcall(function()
                    rank = et.gentity_get(clientNum, "sess.rank") or 0
                end)
                
                -- Set default XP based on rank if available
                if rank > 0 then
                    xp = rank * 1000 -- Estimate XP based on rank
                end
                
                -- Update player data
                player.xp = xp
                player.rank = rank
                
                debugLog("Updated player " .. player.name .. " skill data: rank=" .. rank .. ", xp=" .. xp, 2)
            end
        end
        
        lastXPUpdateTime = currentTime
    end
    
    -- Log stats periodically
    if currentTime - lastStatsLogTime >= config.LOG_STATS_INTERVAL then
        for _, player in pairs(players) do
            logPlayerStats(player)
        end
        
        lastStatsLogTime = currentTime
    end
end
