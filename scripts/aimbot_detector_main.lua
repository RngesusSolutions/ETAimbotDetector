-- ETAimbotDetector
-- A Lua script for ET:Legacy servers that detects and bans players using aimbots.
-- Enhanced version with improved detection algorithms and configurable thresholds.

-- Module loading system
-- Define the base path for our modules relative to where this script is loaded
local scriptPath = "luascripts/wolfadmin/"

-- Function to load a module using dofile with proper path resolution
function loadModule(moduleName)
    -- Convert dot notation to path notation and append .lua extension
    local modulePath = string.gsub(moduleName, "%.", "/")
    
    -- Try to load the module from the scripts directory first (most common case)
    local success, result = pcall(function() 
        return dofile("scripts/" .. modulePath .. ".lua") 
    end)
    if success then
        et.G_Print("^2ETAimbotDetector^7: Successfully loaded module from scripts/" .. modulePath .. ".lua\n")
        return result
    end
    
    -- If that fails, try to load from the same directory as this script
    success, result = pcall(function() 
        return dofile(scriptPath .. modulePath .. ".lua") 
    end)
    if success then
        et.G_Print("^2ETAimbotDetector^7: Successfully loaded module from " .. scriptPath .. modulePath .. ".lua\n")
        return result
    end
    
    -- If that fails, try to load from the etmain directory
    success, result = pcall(function() 
        return dofile("etmain/scripts/" .. modulePath .. ".lua") 
    end)
    if success then
        et.G_Print("^2ETAimbotDetector^7: Successfully loaded module from etmain/scripts/" .. modulePath .. ".lua\n")
        return result
    end
    
    -- If all attempts fail, log the error and return an empty table to prevent crashes
    et.G_Print("^1ETAimbotDetector^7: ERROR - Failed to load module: " .. moduleName .. "\n")
    return {}
end

-- Load all script modules
local microMovementDetection = loadModule("aimbot.micro_movement")
local flickAnalysis = loadModule("aimbot.flick_analysis")
local timeSeriesAnalysis = loadModule("aimbot.time_series")
local weaponThresholds = loadModule("aimbot.weapon_thresholds")
local skillAdaptation = loadModule("aimbot.skill_adaptation")
local warningSystem = loadModule("aimbot.warning_system")
local logging = loadModule("aimbot.logging")

-- Load base configuration
local config_module = loadModule("aimbot.config")

-- Initialize global variables
players = players or {}
config = config or {}
weaponThresholds = weaponThresholds or {}

-- Initialize global functions
if logging then
    debugLog = logging.debugLog
    log = logging.log
else
    -- Fallback logging functions if module failed to load
    debugLog = function(msg, level) et.G_Print("DEBUG: " .. msg .. "\n") end
    log = function(level, msg) et.G_Print("LOG: " .. msg .. "\n") end
end

-- Load common functions
local common = loadModule("aimbot.common")

-- Initialize global functions
if common then
    initPlayerData = common.initPlayerData
    updatePlayerAngles = common.updatePlayerAngles
else
    -- Fallback initialization functions
    initPlayerData = function(clientNum)
        local userinfo = et.trap_GetUserinfo(clientNum)
        local name = et.Info_ValueForKey(userinfo, "name")
        players[clientNum] = {
            name = name,
            lastStatsLogTime = 0,
            lastAngle = {pitch = 0, yaw = 0},
            shots = 0,
            hits = 0
        }
        et.G_Print("Initialized player: " .. name .. "\n")
    end
    
    updatePlayerAngles = function(clientNum) end
end

-- Initialize the script with error handling
function et_InitGame(levelTime, randomSeed, restart)
    -- Register the module
    et.RegisterModname("ETAimbotDetector v1.0")
    et.G_Print("^3ETAimbotDetector^7 v1.0 loaded\n")
    et.G_Print("^3ETAimbotDetector^7: Monitoring for suspicious aim patterns\n")
    
    -- Create log directory with error handling
    if logging and logging.ensureLogDirExists then
        pcall(logging.ensureLogDirExists)
    else
        et.G_Print("^1ETAimbotDetector^7: Warning - Logging module not loaded correctly\n")
    end
    
    -- Log initialization with error handling
    if logging and logging.logStartup then
        pcall(logging.logStartup)
    else
        et.G_Print("^1ETAimbotDetector^7: Warning - Logging module not loaded correctly\n")
    end
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
        logging.logDetection(player, confidence, detectionCount, aimbotType, reason)
        
        -- Check if player should be warned
        warningSystem.checkForWarning(clientNum, confidence, detectionCount, reason)
    else
        debugLog("runDetection: No aimbot detected for " .. player.name .. " - confidence: " .. confidence .. ", detections: " .. detectionCount, 2)
    end
end

-- ET:Legacy callback: RunFrame
function et_RunFrame(levelTime)
    -- Ensure players table exists
    if not players then
        players = {}
        et.G_Print("^3ETAimbotDetector^7: Initialized players table\n")
    end
    
    -- Process each player
    for clientNum = 0, et.trap_Cvar_Get("sv_maxclients") - 1 do
        if et.gentity_get(clientNum, "inuse") then
            -- Initialize player data if needed
            if not players[clientNum] then
                if initPlayerData then
                    initPlayerData(clientNum)
                else
                    et.G_Print("^1ETAimbotDetector^7: Error - initPlayerData function not available\n")
                    players[clientNum] = { name = "Unknown", lastStatsLogTime = 0 }
                end
            end
            
            local player = players[clientNum]
            if not player then
                et.G_Print("^1ETAimbotDetector^7: Error - Failed to initialize player " .. clientNum .. "\n")
                goto continue
            end
            
            -- Update player angles
            if updatePlayerAngles then
                updatePlayerAngles(clientNum)
            end
            
            -- Run detection if function exists
            if runDetection then
                runDetection(clientNum)
            else
                et.G_Print("^1ETAimbotDetector^7: Error - runDetection function not available\n")
            end
            
            -- Log player stats periodically
            local currentTime = et.trap_Milliseconds()
            if player.lastStatsLogTime and currentTime - player.lastStatsLogTime >= config.LOG_STATS_INTERVAL then
                if logging and logging.logPlayerStats then
                    logging.logPlayerStats(player)
                end
                player.lastStatsLogTime = currentTime
            end
            
            ::continue::
        end
    end
end

-- Script is now loaded and ready
et.G_Print("^3ETAimbotDetector^7: All modules loaded successfully\n")
