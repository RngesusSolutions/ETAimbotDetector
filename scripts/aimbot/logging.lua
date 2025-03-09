-- Detailed logging system for aimbot detection
-- This module implements a comprehensive logging system with configurable levels

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

-- Standard logging function
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
    log(1, "ETAimbotDetector v1.0 initialized")
    
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

-- Export functions
return {
    ensureLogDirExists = ensureLogDirExists,
    log = log,
    debugLog = debugLog,
    logDetection = logDetection,
    logWarning = logWarning,
    logBan = logBan,
    logPlayerStats = logPlayerStats,
    logStartup = logStartup
}
