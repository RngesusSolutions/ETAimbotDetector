-- Time-series analysis for aimbot detection
-- This module implements detection for timing patterns and consistency in player actions

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
    if not player.shotTimings or #player.shotTimings < config.MIN_SHOT_SAMPLES then return 0 end
    
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
    elseif normalizedStdDev < 0.15 and #timings >= 6 then
        -- Low variance is slightly suspicious
        debugLog("calculateTimingConsistency: Low timing variance detected (" .. normalizedStdDev .. "), slightly suspicious", 2)
        return 0.5
    end
    
    -- Return consistency score (1 - normalized standard deviation)
    -- Higher score means more consistent timing (suspicious)
    return math.max(0, math.min(0.4, 1 - normalizedStdDev))
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
            
            if repeats > 1 then 
                patternCount = patternCount + 1
                debugLog("detectRepeatingPatterns: Found repeating pattern of length " .. patternLength .. " with " .. repeats .. " repeats", 3)
            end
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
    if #player.angleChanges < 10 or not player.shotTimings or #player.shotTimings < config.MIN_SHOT_SAMPLES then
        return 0, "Insufficient data"
    end
    
    -- Calculate timing consistency
    local timingConsistency = calculateTimingConsistency(player)
    
    -- Detect repeating patterns in angle changes
    local patternScore = detectRepeatingPatterns(player.angleChanges)
    
    -- Detect repeating patterns in shot timings
    local shotPatternScore = 0
    if #player.shotTimings >= 10 then
        shotPatternScore = detectRepeatingPatterns(player.shotTimings)
    end
    
    -- Calculate combined time-series score
    local timeSeriesScore = (timingConsistency * config.TIMING_CONSISTENCY_WEIGHT) + 
                           (patternScore * config.PATTERN_DETECTION_WEIGHT * 0.6) +
                           (shotPatternScore * config.PATTERN_DETECTION_WEIGHT * 0.4)
    
    local reason = string.format("Time-series analysis (timing: %.2f, angle patterns: %.2f, shot patterns: %.2f)", 
        timingConsistency, patternScore, shotPatternScore)
    
    debugLog("analyzeTimeSeriesData: " .. player.name .. " - timingConsistency=" .. timingConsistency .. 
             ", patternScore=" .. patternScore .. ", shotPatternScore=" .. shotPatternScore .. 
             ", timeSeriesScore=" .. timeSeriesScore, 2)
    
    return timeSeriesScore, reason
end

-- Analyze target switching patterns
local function analyzeTargetSwitching(clientNum)
    local player = players[clientNum]
    if not player or not player.targetSwitches or #player.targetSwitches < 5 then
        return 0, "Insufficient target switch data"
    end
    
    -- Calculate average and standard deviation of target switch times
    local sum = 0
    for _, switchTime in ipairs(player.targetSwitches) do
        sum = sum + switchTime
    end
    local avg = sum / #player.targetSwitches
    local stdDev = calculateStdDev(player.targetSwitches, avg)
    
    -- Calculate coefficient of variation
    local cv = stdDev / avg
    
    debugLog("analyzeTargetSwitching: " .. player.name .. " - switches=" .. #player.targetSwitches .. 
             ", avg=" .. avg .. "ms, stdDev=" .. stdDev .. "ms, cv=" .. cv, 2)
    
    -- Extremely consistent target switching is suspicious
    local confidence = 0
    local reason = ""
    
    if cv < 0.2 and #player.targetSwitches >= 5 then
        confidence = 0.8
        reason = string.format("Highly suspicious target switching pattern (cv: %.2f)", cv)
    elseif cv < 0.3 and #player.targetSwitches >= 5 then
        confidence = 0.6
        reason = string.format("Suspicious target switching pattern (cv: %.2f)", cv)
    end
    
    return confidence, reason
end

-- Integrate time-series analysis into the main detection system
local function enhanceDetectionWithTimeSeriesAnalysis(clientNum, totalConfidence, detectionCount, reasons)
    if not config.TIME_SERIES_ANALYSIS then
        return totalConfidence, detectionCount, reasons
    end
    
    local player = players[clientNum]
    if not player then
        return totalConfidence, detectionCount, reasons
    end
    
    -- Skip if we don't have enough data
    if not player.shotTimings or #player.shotTimings < config.MIN_SHOT_SAMPLES then
        return totalConfidence, detectionCount, reasons
    end
    
    -- Run time-series analysis
    local timeSeriesScore, timeSeriesReason = analyzeTimeSeriesData(clientNum)
    
    if timeSeriesScore > config.TIME_SERIES_THRESHOLD then
        totalConfidence = totalConfidence + timeSeriesScore
        detectionCount = detectionCount + 1
        table.insert(reasons, timeSeriesReason)
        
        debugLog("enhanceDetectionWithTimeSeriesAnalysis: Detected suspicious time-series pattern for client " .. 
                 clientNum .. " with confidence " .. timeSeriesScore, 1)
    end
    
    -- Also analyze target switching patterns
    local targetSwitchConfidence, targetSwitchReason = analyzeTargetSwitching(clientNum)
    
    if targetSwitchConfidence > 0.5 then
        totalConfidence = totalConfidence + targetSwitchConfidence
        detectionCount = detectionCount + 1
        table.insert(reasons, targetSwitchReason)
        
        debugLog("enhanceDetectionWithTimeSeriesAnalysis: Detected suspicious target switching pattern for client " .. 
                 clientNum .. " with confidence " .. targetSwitchConfidence, 1)
    end
    
    return totalConfidence, detectionCount, reasons
end

-- Export functions
return {
    calculateStdDev = calculateStdDev,
    calculateMovingAverage = calculateMovingAverage,
    calculateTimingConsistency = calculateTimingConsistency,
    detectRepeatingPatterns = detectRepeatingPatterns,
    analyzeTimeSeriesData = analyzeTimeSeriesData,
    analyzeTargetSwitching = analyzeTargetSwitching,
    enhanceDetectionWithTimeSeriesAnalysis = enhanceDetectionWithTimeSeriesAnalysis
end
