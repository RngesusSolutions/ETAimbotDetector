-- ETAimbotDetector
-- A Lua script for ET:Legacy servers that detects and bans players using aimbots.

-- Configuration variables
local config = {
    -- Detection thresholds
    MAX_ANGLE_CHANGE = 180,           -- Maximum angle change in degrees that's considered suspicious
    ANGLE_CHANGE_THRESHOLD = 150,     -- Angle change threshold for suspicious activity
    HEADSHOT_RATIO_THRESHOLD = 0.7,   -- Ratio of headshots to total kills that's considered suspicious
    ACCURACY_THRESHOLD = 0.8,         -- Accuracy threshold that's considered suspicious
    CONSECUTIVE_HITS_THRESHOLD = 10,  -- Number of consecutive hits that's considered suspicious
    
    -- Warning and ban settings
    WARNINGS_BEFORE_BAN = 3,          -- Number of warnings before ban
    BAN_DURATION = 7,                 -- Ban duration in days
    PERMANENT_BAN_THRESHOLD = 3,      -- Number of temporary bans before permanent ban
    
    -- Logging settings
    LOG_LEVEL = 2,                    -- 0: None, 1: Minimal, 2: Detailed, 3: Debug
    LOG_FILE = "aimbot_detector.log", -- Log file name
    
    -- Enable/disable specific detection methods
    DETECT_ANGLE_CHANGES = true,      -- Detect suspicious angle changes
    DETECT_HEADSHOT_RATIO = true,     -- Detect suspicious headshot ratio
    DETECT_ACCURACY = true,           -- Detect suspicious accuracy
    DETECT_CONSECUTIVE_HITS = true,   -- Detect suspicious consecutive hits
    
    -- New options
    DEBUG_MODE = false,               -- Enable/disable debug logging to server console
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
        shots = 0,
        hits = 0,
        headshots = 0,
        kills = 0,
        consecutiveHits = 0,
        
        -- Warning system
        warnings = 0,
        lastWarningTime = 0,
        
        -- Ban history
        tempBans = 0,
    }
    
    debugLog("Player initialized: " .. name .. " (GUID: " .. guid .. ")")
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

-- Log function
local function log(level, message)
    if level <= config.LOG_LEVEL then
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        local logMessage = string.format("[%s] %s\n", timestamp, message)
        
        -- Print to console
        et.G_Print(logMessage)
        
        -- Write to log file
        local file = io.open(config.LOG_FILE, "a")
        if file then
            file:write(logMessage)
            file:close()
        end
    end
end

-- Debug logging function
local function debugLog(message)
    if config.DEBUG_MODE then
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        local debugMessage = string.format("[DEBUG %s] %s", timestamp, message)
        et.G_Print(debugMessage .. "\n")
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

-- Check for suspicious angle changes
local function detectAngleChanges(clientNum)
    if not config.DETECT_ANGLE_CHANGES then return false end
    
    local player = players[clientNum]
    if not player or #player.angleChanges < 5 then return false end
    
    -- Calculate average and variance of recent angle changes
    local sum = 0
    for _, change in ipairs(player.angleChanges) do
        sum = sum + change
    end
    local avg = sum / #player.angleChanges
    
    -- Check if average angle change is suspicious
    if avg > config.ANGLE_CHANGE_THRESHOLD then
        return true, string.format("Suspicious angle changes (avg: %.2f°)", avg)
    end
    
    return false
end

-- Check for suspicious headshot ratio
local function detectHeadshotRatio(clientNum)
    if not config.DETECT_HEADSHOT_RATIO then return false end
    
    local player = players[clientNum]
    if not player or player.kills < 10 then return false end
    
    local ratio = player.headshots / player.kills
    
    if ratio > config.HEADSHOT_RATIO_THRESHOLD then
        return true, string.format("Suspicious headshot ratio (%.2f)", ratio)
    end
    
    return false
end

-- Check for suspicious accuracy
local function detectAccuracy(clientNum)
    if not config.DETECT_ACCURACY then return false end
    
    local player = players[clientNum]
    if not player or player.shots < 20 then return false end
    
    local accuracy = player.hits / player.shots
    
    if accuracy > config.ACCURACY_THRESHOLD then
        return true, string.format("Suspicious accuracy (%.2f)", accuracy)
    end
    
    return false
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

-- Run all detection methods
local function runDetection(clientNum)
    local player = players[clientNum]
    if not player then return end
    
    -- Skip detection for OMNIBOT players if enabled
    if config.IGNORE_OMNIBOTS and isOmniBot(player.guid) then
        debugLog("Skipping detection for OMNIBOT: " .. player.name)
        return
    end
    
    debugLog("Running detection for player: " .. player.name)
    
    local suspicious, reason
    
    -- Run each detection method
    suspicious, reason = detectAngleChanges(clientNum)
    if suspicious then
        warnPlayer(clientNum, reason)
        return
    end
    
    suspicious, reason = detectHeadshotRatio(clientNum)
    if suspicious then
        warnPlayer(clientNum, reason)
        return
    end
    
    suspicious, reason = detectAccuracy(clientNum)
    if suspicious then
        warnPlayer(clientNum, reason)
        return
    end
    
    suspicious, reason = detectConsecutiveHits(clientNum)
    if suspicious then
        warnPlayer(clientNum, reason)
        return
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
    if not players[clientNum] then return 0 end
    
    local player = players[clientNum]
    
    -- Skip OMNIBOT players if enabled
    if config.IGNORE_OMNIBOTS and isOmniBot(player.guid) then
        debugLog("Skipping WeaponFire for OMNIBOT: " .. player.name)
        return 0
    end
    
    debugLog("WeaponFire: " .. player.name .. " fired weapon " .. weapon)
    player.shots = player.shots + 1
    
    -- Get current view angles
    local angles = et.gentity_get(clientNum, "ps.viewangles")
    
    -- Check if angles are valid
    if angles == nil then return 0 end
    
    -- Calculate angle change
    local pitchChange = getAngleDifference(angles[0], player.lastAngle.pitch)
    local yawChange = getAngleDifference(angles[1], player.lastAngle.yaw)
    local totalChange = math.sqrt(pitchChange^2 + yawChange^2)
    
    -- Store angle change
    if totalChange < config.MAX_ANGLE_CHANGE then
        table.insert(player.angleChanges, totalChange)
        if #player.angleChanges > 10 then
            table.remove(player.angleChanges, 1)
        end
    end
    
    -- Update last angle
    player.lastAngle.pitch = angles[0]
    player.lastAngle.yaw = angles[1]
    
    return 0 -- Pass through to game
end

-- ET:Legacy callback: Damage
function et_Damage(targetNum, attackerNum, damage, dflags, mod)
    if attackerNum < 0 or attackerNum >= 64 or targetNum < 0 or targetNum >= 64 then return end
    if not players[attackerNum] then return end
    
    local player = players[attackerNum]
    
    -- Skip OMNIBOT players if enabled
    if config.IGNORE_OMNIBOTS and isOmniBot(player.guid) then
        debugLog("Skipping Damage for OMNIBOT: " .. player.name)
        return
    end
    
    debugLog("Damage: " .. player.name .. " dealt " .. damage .. " damage to player " .. targetNum)
    player.hits = player.hits + 1
    player.consecutiveHits = player.consecutiveHits + 1
    
    -- Check if headshot (bit 2 is DAMAGE_HEADSHOT in ET:Legacy)
    if et.isBitSet(dflags, 2) then
        player.headshots = player.headshots + 1
    end
    
    -- Run detection after updating stats
    runDetection(attackerNum)
end

-- ET:Legacy callback: Obituary
function et_Obituary(targetNum, attackerNum, meansOfDeath)
    if attackerNum < 0 or attackerNum >= 64 or targetNum < 0 or targetNum >= 64 then return end
    if not players[attackerNum] or attackerNum == targetNum then return end
    
    local player = players[attackerNum]
    
    -- Skip OMNIBOT players if enabled
    if config.IGNORE_OMNIBOTS and isOmniBot(player.guid) then
        debugLog("Skipping Obituary for OMNIBOT: " .. player.name)
        return
    end
    
    player.kills = player.kills + 1
    
    -- Run detection after updating stats
    runDetection(attackerNum)
end

-- ET:Legacy callback: MissedShot (custom)
function et_MissedShot(clientNum)
    if not players[clientNum] then return end
    
    local player = players[clientNum]
    
    -- Skip OMNIBOT players if enabled
    if config.IGNORE_OMNIBOTS and isOmniBot(player.guid) then
        debugLog("Skipping MissedShot for OMNIBOT: " .. player.name)
        return
    end
    
    player.consecutiveHits = 0
end

-- Return 1 if the module loaded successfully
return 1
