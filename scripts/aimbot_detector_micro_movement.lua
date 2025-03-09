-- Micro-movement detection for humanized aimbots
-- This module implements detection for small, precise adjustments that are characteristic of humanized aimbots

-- Check for micro-movements (humanized aimbot detection)
local function detectMicroMovements(clientNum)
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
        local sumSquares = 0
        for _, v in ipairs(microMovements) do
            sumSquares = sumSquares + (v - microMovementAvg)^2
        end
        
        if #microMovements > 1 then
            microMovementStdDev = math.sqrt(sumSquares / (#microMovements - 1))
        end
    end
    
    debugLog("detectMicroMovements: " .. player.name .. " - microMovements=" .. microMovementCount .. 
             ", maxSequence=" .. maxMicroMovementSequence .. 
             ", avg=" .. microMovementAvg .. 
             ", stdDev=" .. microMovementStdDev, 2)
    
    -- Calculate confidence score based on micro-movement patterns
    local confidence = 0
    
    -- Suspicious pattern: Many micro-movements with low standard deviation
    if microMovementCount >= 5 and maxMicroMovementSequence >= 3 and microMovementStdDev < 3 then
        confidence = 0.8
        return true, confidence, string.format("Highly suspicious micro-movement pattern (count: %d, sequence: %d, stdDev: %.2f°)", 
            microMovementCount, maxMicroMovementSequence, microMovementStdDev)
    -- Moderately suspicious: Several micro-movements with moderate standard deviation
    elseif microMovementCount >= 5 and maxMicroMovementSequence >= 3 and microMovementStdDev < 5 then
        confidence = 0.6
        return true, confidence, string.format("Suspicious micro-movement pattern (count: %d, sequence: %d, stdDev: %.2f°)", 
            microMovementCount, maxMicroMovementSequence, microMovementStdDev)
    -- Slightly suspicious: Some micro-movements with higher standard deviation
    elseif microMovementCount >= 4 and maxMicroMovementSequence >= 2 and microMovementStdDev < 8 then
        confidence = 0.4
        return true, confidence, string.format("Slightly suspicious micro-movement pattern (count: %d, sequence: %d, stdDev: %.2f°)", 
            microMovementCount, maxMicroMovementSequence, microMovementStdDev)
    end
    
    return false, 0
end

-- Integrate micro-movement detection into the main detection system
local function enhanceDetectionWithMicroMovements(clientNum, totalConfidence, detectionCount, reasons)
    if not config.MICRO_MOVEMENT_DETECTION then
        return totalConfidence, detectionCount, reasons
    end
    
    local suspicious, confidence, reason = detectMicroMovements(clientNum)
    
    if suspicious then
        totalConfidence = totalConfidence + confidence
        detectionCount = detectionCount + 1
        table.insert(reasons, reason)
        
        debugLog("enhanceDetectionWithMicroMovements: Detected suspicious micro-movements for client " .. clientNum .. " with confidence " .. confidence, 1)
    end
    
    return totalConfidence, detectionCount, reasons
end

-- Export functions
return {
    detectMicroMovements = detectMicroMovements,
    enhanceDetectionWithMicroMovements = enhanceDetectionWithMicroMovements
}
