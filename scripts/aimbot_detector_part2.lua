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
    
    -- Human players show more variance in their timing
    -- Extremely low variance is suspicious (aimbots have very consistent timing)
    if normalizedStdDev < 0.05 and #timings >= 10 then
        -- Extremely low variance is highly suspicious
        debugLog("calculateTimingConsistency: Extremely low timing variance detected (" .. normalizedStdDev .. "), highly suspicious", 2)
        return 0.9
    elseif normalizedStdDev < 0.1 and #timings >= 8 then
        -- Very low variance is moderately suspicious
        debugLog("calculateTimingConsistency: Very low timing variance detected (" .. normalizedStdDev .. "), moderately suspicious", 2)
        return 0.7
    end
    
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
    local timeSeriesScore = (timingConsistency * config.TIMING_CONSISTENCY_WEIGHT) + 
                           (patternScore * config.PATTERN_DETECTION_WEIGHT)
    
    local reason = string.format("Time-series analysis (timing: %.2f, patterns: %.2f)", 
        timingConsistency, patternScore)
    
    return timeSeriesScore, reason
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

-- Determine aimbot type based on detection patterns
local function determineAimbotType(player)
    if not player then return "Unknown" end
    
    -- Check for humanized aimbot patterns
    if player.stdDevAngleChange < 15 and player.avgAngleChange > 100 then
        return "Humanized"
    elseif player.shotTimings and #player.shotTimings >= 5 then
        local timingConsistency = calculateTimingConsistency(player)
        if timingConsistency > 0.8 then
            return "Humanized"
        else
            return "Normal"
        end
    else
        return "Normal"
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
        reason, player.warnings, config.MAX_WARNINGS)
    
    -- Send center-print message to player if this is beyond the warning threshold
    if player.warnings >= config.WARN_THRESHOLD then
        et.trap_SendServerCommand(clientNum, "cp " .. warningMessage)
        
        -- Send chat message to player if enabled
        if config.CHAT_WARNINGS then
            et.trap_SendServerCommand(clientNum, "chat \"" .. warningMessage .. "\"")
        end
    end
    
    -- Log warning
    log(1, string.format("Warning issued to %s (%s): %s", 
        player.name, player.guid, reason))
    
    debugLog("Warning issued to " .. player.name .. " for " .. reason)
    
    -- Check if player should be banned
    if player.warnings >= config.MAX_WARNINGS and config.ENABLE_BANS then
        banPlayer(clientNum, reason)
    end
end
