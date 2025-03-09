-- Progressive warning system for aimbot detection
-- This module implements a warning and ban system with configurable thresholds

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
    local adminMessage = string.format("^3ANTI-CHEAT^7: Player %s ^7suspected of aimbot (%s)", 
        player.name, reason)
    
    -- Send to all admins (clients with admin flag)
    for i = 0, et.trap_Cvar_Get("sv_maxclients") - 1 do
        if et.gentity_get(i, "inuse") and et.G_shrubbot_permission(i, "a") then
            et.trap_SendServerCommand(i, "chat \"" .. adminMessage .. "\"")
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
        }
    }
}

-- Check if warning cooldown has expired
local function canWarnPlayer(player)
    if not player then return false end
    
    -- Skip cooldown check for first warning
    if player.warnings == 0 then return true end
    
    local currentTime = et.trap_Milliseconds()
    local timeSinceLastWarning = currentTime - player.lastWarningTime
    
    -- Check if cooldown has expired
    return timeSinceLastWarning >= config.WARNING_COOLDOWN
}

-- Reset warnings for a player
local function resetWarnings(clientNum)
    local player = players[clientNum]
    if not player then return end
    
    local oldWarnings = player.warnings
    player.warnings = 0
    
    if oldWarnings > 0 then
        debugLog("resetWarnings: Reset " .. oldWarnings .. " warnings for " .. player.name, 2)
    }
}

-- Check if player should be warned based on detection confidence
local function checkForWarning(clientNum, confidence, detectionCount, reason)
    local player = players[clientNum]
    if not player then return end
    
    -- Skip if confidence is below threshold
    if confidence < config.CONFIDENCE_THRESHOLD then
        debugLog("checkForWarning: Confidence too low for " .. player.name .. " (" .. confidence .. " < " .. config.CONFIDENCE_THRESHOLD .. ")", 3)
        return
    }
    
    -- Skip if not enough detection methods triggered
    if detectionCount < 2 then
        debugLog("checkForWarning: Not enough detection methods triggered for " .. player.name .. " (" .. detectionCount .. " < 2)", 3)
        return
    }
    
    -- Skip if warning cooldown hasn't expired
    if not canWarnPlayer(player) then
        debugLog("checkForWarning: Warning cooldown not expired for " .. player.name, 3)
        return
    }
    
    -- Issue warning
    warnPlayer(clientNum, reason)
}

-- Export functions
return {
    warnPlayer = warnPlayer,
    banPlayer = banPlayer,
    canWarnPlayer = canWarnPlayer,
    resetWarnings = resetWarnings,
    checkForWarning = checkForWarning
}
