-- Flick pattern analysis for aimbot detection
-- This module implements detection for distinguishing between legitimate flicks and aimbot snaps

-- Detect flick shot patterns with timing analysis
local function detectFlickPattern(clientNum)
    local player = players[clientNum]
    if not player or #player.angleChanges < 10 then return false, 0 end
    
    local flicks = 0
    local adjustments = 0
    local suspiciousFlicks = 0
    local quickHitFlicks = 0
    
    -- Analyze angle change patterns
    for i = 2, #player.angleChanges - 1 do
        -- Detect large angle changes (flicks)
        if player.angleChanges[i] > 100 then
            flicks = flicks + 1
            
            -- Check for post-flick adjustments (human behavior)
            if player.angleChanges[i+1] >= 5 and player.angleChanges[i+1] <= 30 then
                adjustments = adjustments + 1
            else
                suspiciousFlicks = suspiciousFlicks + 1
            end
            
            -- Check if this flick resulted in a quick hit
            if player.shotTimings and player.hitTimings and 
               i <= #player.shotTimings and i <= #player.hitTimings then
                -- If time between angle change and hit is very small, it's suspicious
                local timeToHit = player.hitTimings[i] - player.shotTimings[i]
                if timeToHit >= 0 and timeToHit < 100 then -- Less than 100ms is very fast
                    quickHitFlicks = quickHitFlicks + 1
                    debugLog("Flick pattern analysis: Quick hit detected - angle change to hit time: " .. timeToHit .. "ms", 3)
                end
            end
        end
    end
    
    -- Calculate ratio of suspicious flicks to total flicks
    local suspiciousRatio = 0
    local quickHitRatio = 0
    if flicks > 0 then
        suspiciousRatio = suspiciousFlicks / flicks
        quickHitRatio = quickHitFlicks / flicks
    end
    
    debugLog("Flick pattern analysis: " .. player.name .. " - flicks=" .. flicks .. 
        ", adjustments=" .. adjustments .. ", suspicious=" .. suspiciousFlicks .. 
        ", quickHits=" .. quickHitFlicks ..
        ", suspiciousRatio=" .. suspiciousRatio .. 
        ", quickHitRatio=" .. quickHitRatio, 2)
    
    -- Detect suspicious patterns
    local isDetected = false
    local confidence = 0
    local reason = ""
    
    -- Check for quick hit flicks (as requested by user)
    if quickHitRatio > 0.5 and flicks >= 3 then
        confidence = quickHitRatio - 0.5
        reason = string.format("Suspicious quick-hit flicks (%.2f of flicks resulted in immediate hits)", quickHitRatio)
        isDetected = true
    -- Check for suspicious flick patterns
    elseif suspiciousRatio > 0.7 and flicks >= 3 then
        confidence = suspiciousRatio - 0.7
        reason = string.format("Suspicious flick pattern (%.2f of flicks without human-like adjustments)", suspiciousRatio)
        isDetected = true
    end
    
    if isDetected then
        return true, confidence, reason
    end
    
    return false, 0
end

-- Analyze flick timing to detect suspicious patterns
local function analyzeFlickTiming(clientNum)
    local player = players[clientNum]
    if not player or #player.angleChanges < 10 then return false, 0 end
    
    local flickTimings = {}
    local lastFlickTime = 0
    
    -- Collect timings between flicks
    for i = 2, #player.angleChanges do
        if player.angleChanges[i] > 100 then
            local currentTime = et.trap_Milliseconds()
            
            if lastFlickTime > 0 then
                local timeBetweenFlicks = currentTime - lastFlickTime
                table.insert(flickTimings, timeBetweenFlicks)
            end
            
            lastFlickTime = currentTime
        end
    end
    
    -- Need at least 3 flick timings to analyze
    if #flickTimings < 3 then
        return false, 0
    end
    
    -- Calculate average and standard deviation
    local sum = 0
    for _, timing in ipairs(flickTimings) do
        sum = sum + timing
    end
    local avg = sum / #flickTimings
    
    local sumSquares = 0
    for _, timing in ipairs(flickTimings) do
        sumSquares = sumSquares + (timing - avg)^2
    end
    local stdDev = math.sqrt(sumSquares / (#flickTimings - 1))
    
    -- Calculate coefficient of variation (normalized standard deviation)
    local cv = stdDev / avg
    
    debugLog("analyzeFlickTiming: " .. player.name .. " - flick timings=" .. #flickTimings .. 
             ", avg=" .. avg .. "ms, stdDev=" .. stdDev .. "ms, cv=" .. cv, 2)
    
    -- Extremely consistent flick timing is suspicious (low coefficient of variation)
    if cv < 0.2 and #flickTimings >= 5 then
        local confidence = 0.8
        return true, confidence, string.format("Suspicious flick timing consistency (cv: %.2f)", cv)
    elseif cv < 0.3 and #flickTimings >= 4 then
        local confidence = 0.6
        return true, confidence, string.format("Moderately suspicious flick timing (cv: %.2f)", cv)
    end
    
    return false, 0
end

-- Integrate flick pattern analysis into the main detection system
local function enhanceDetectionWithFlickAnalysis(clientNum, totalConfidence, detectionCount, reasons)
    local suspicious, confidence, reason = detectFlickPattern(clientNum)
    
    if suspicious then
        totalConfidence = totalConfidence + confidence
        detectionCount = detectionCount + 1
        table.insert(reasons, reason)
        
        debugLog("enhanceDetectionWithFlickAnalysis: Detected suspicious flick pattern for client " .. clientNum .. " with confidence " .. confidence, 1)
    end
    
    -- Also check flick timing
    suspicious, confidence, reason = analyzeFlickTiming(clientNum)
    
    if suspicious then
        totalConfidence = totalConfidence + confidence
        detectionCount = detectionCount + 1
        table.insert(reasons, reason)
        
        debugLog("enhanceDetectionWithFlickAnalysis: Detected suspicious flick timing for client " .. clientNum .. " with confidence " .. confidence, 1)
    end
    
    return totalConfidence, detectionCount, reasons
end

-- Export functions
return {
    detectFlickPattern = detectFlickPattern,
    analyzeFlickTiming = analyzeFlickTiming,
    enhanceDetectionWithFlickAnalysis = enhanceDetectionWithFlickAnalysis
}
