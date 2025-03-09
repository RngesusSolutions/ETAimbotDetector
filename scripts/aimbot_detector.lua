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
}

-- Player data storage
local players = {}

-- Initialize player data
local function initPlayerData(clientNum)
    players[clientNum] = {
        name = et.Info_ValueForKey(et.trap_GetUserinfo(clientNum), "name"),
        guid = et.Info_ValueForKey(et.trap_GetUserinfo(clientNum), "cl_guid"),
        ip = et.Info_ValueForKey(et.trap_GetUserinfo(clientNum), "ip"),
        
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
end

-- Calculate angle difference (accounting for 360 degree wrapping)
local function getAngleDifference(a1, a2)
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
    
    -- Send message to player
    et.trap_SendServerCommand(clientNum, "cp " .. warningMessage)
    
    -- Log warning
    log(1, string.format("Warning issued to %s (%s): %s", 
        player.name, player.guid, reason))
    
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
    
    -- Reset player data on map change
    players = {}
end

-- ET:Legacy callback: ClientConnect
function et_ClientConnect(clientNum, firstTime, isBot)
    if isBot == 1 then return end
    
    initPlayerData(clientNum)
    log(2, string.format("Player connected: %s (%s)", 
        players[clientNum].name, players[clientNum].guid))
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
    player.shots = player.shots + 1
    
    -- Get current view angles
    local angles = et.gentity_get(clientNum, "ps.viewangles")
    
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
    player.hits = player.hits + 1
    player.consecutiveHits = player.consecutiveHits + 1
    
    -- Check if headshot
    if bit.band(dflags, 2) ~= 0 then -- 2 is DAMAGE_HEADSHOT
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
    player.kills = player.kills + 1
    
    -- Run detection after updating stats
    runDetection(attackerNum)
end

-- ET:Legacy callback: MissedShot (custom)
function et_MissedShot(clientNum)
    if not players[clientNum] then return end
    
    players[clientNum].consecutiveHits = 0
end

-- Return 1 if the module loaded successfully
return 1
