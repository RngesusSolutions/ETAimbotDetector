# ETAimbotDetector

An advanced aimbot detection system for ET:Legacy servers that uses sophisticated statistical analysis to detect and prevent cheating.

## Features

- **Multi-layered Detection**: Combines multiple detection methods for high accuracy
- **Micro-movement Detection**: Identifies humanized aimbots through micro-adjustment patterns
- **Flick Shot Analysis**: Distinguishes between legitimate flicks and aimbot snaps
- **Time-series Analysis**: Detects suspicious timing patterns in player actions
- **Weapon-specific Thresholds**: Adjusts detection sensitivity based on weapon type
- **Skill Level Adaptation**: Adapts thresholds based on player experience
- **Progressive Warning System**: Provides multiple warnings before taking action
- **Detailed Logging**: Comprehensive logging for manual review

## Installation

1. Place all script files in your ET:Legacy `etmain/scripts/` directory
2. Add the following line to your `etl_server.cfg`:
   ```
   lua_modules "aimbot_detector_main"
   ```
3. Restart your server

## Configuration

The script includes extensive configuration options in the `config` table at the top of the main script file. Here are some key settings:

```lua
local config = {
    -- General detection settings
    CONFIDENCE_THRESHOLD = 0.65,        -- Overall confidence threshold for triggering warnings
    MIN_SAMPLES_REQUIRED = 15,          -- Minimum samples needed before detection
    
    -- Warning and ban settings
    WARN_THRESHOLD = 1,                 -- Number of warnings before notifying player
    MAX_WARNINGS = 3,                   -- Number of warnings before ban
    ENABLE_BANS = true,                 -- Enable automatic banning
    
    -- Debug options
    DEBUG_MODE = true,                  -- Enable/disable debug logging to file
    DEBUG_LEVEL = 3,                    -- Debug level: 1=basic, 2=detailed, 3=verbose
    
    -- And many more options...
}
```

## Detection Mechanisms

### Angle Change Analysis
Analyzes player view angle changes to detect suspicious patterns, including:
- Abnormally large angle changes
- Consistent angle changes with low variance
- Suspicious "snapping" behavior

### Micro-movement Detection
Identifies humanized aimbots by detecting:
- Small, precise adjustments between 5-20 degrees
- Sequences of micro-movements with low variance
- Unnatural precision in small adjustments

### Flick Shot Analysis
Distinguishes between legitimate flicks and aimbot snaps by:
- Analyzing post-flick micro-adjustments (human players make small corrections)
- Measuring time between flick and hit registration
- Detecting suspicious flick patterns

### Time-series Analysis
Examines timing patterns in player actions:
- Shot timing consistency
- Repeating patterns in angle changes
- Correlation between angle changes and shots

### Weapon-specific Tracking
Adjusts detection thresholds based on weapon characteristics:
- Different accuracy expectations for different weapons
- Weapon-specific headshot ratio thresholds
- Customizable thresholds for each weapon type

## Skill Level Adaptation
Automatically adjusts thresholds based on player experience:
- Novice: Base thresholds
- Regular: Slightly increased thresholds
- Skilled: Moderately increased thresholds
- Expert: Significantly increased thresholds

## False Positive Mitigation

The system includes several mechanisms to minimize false positives:

1. **Multi-factor Detection**: Multiple detection methods must trigger before action is taken
2. **Confidence Scoring**: Each detection contributes to an overall confidence score
3. **Skill-based Adaptation**: Higher skill players have higher thresholds
4. **Progressive Warnings**: Multiple warnings before any ban action
5. **Weapon-specific Thresholds**: Different weapons have different expected accuracy/headshot ratios
6. **Minimum Sample Requirements**: Sufficient data must be collected before detection

## Logging and Debugging

The system includes comprehensive logging:

1. **Standard Logs**: Records warnings, bans, and significant events
2. **Debug Logs**: Detailed information about detection processes
3. **Console Output**: Optional real-time monitoring via server console
4. **Log Rotation**: Automatic log rotation to manage file sizes

## Testing Results

The detection system has been tested against:

1. **Legitimate Players**: High-skill players with legitimate flick shots and high accuracy
2. **Basic Aimbots**: Simple aimbots with obvious angle snapping
3. **Humanized Aimbots**: Sophisticated aimbots with humanized movements
4. **Trigger Bots**: Automatic firing when crosshair is over target

Results show high detection rates for cheats while maintaining low false positive rates for legitimate players.

## Advanced Configuration

### Weapon-specific Thresholds

```lua
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
    -- More weapon configurations...
}
```

### Skill Level Adjustments

```lua
SKILL_LEVELS = {
    NOVICE = 0,       -- 0-999 XP
    REGULAR = 1000,   -- 1000-4999 XP
    SKILLED = 5000,   -- 5000-9999 XP
    EXPERT = 10000    -- 10000+ XP
}

SKILL_ADJUSTMENTS = {
    NOVICE = { accuracy = 0.0, headshot = 0.0 },
    REGULAR = { accuracy = 0.05, headshot = 0.05 },
    SKILLED = { accuracy = 0.1, headshot = 0.1 },
    EXPERT = { accuracy = 0.15, headshot = 0.15 }
}
```

## License

This script is provided for free use on ET:Legacy servers.
