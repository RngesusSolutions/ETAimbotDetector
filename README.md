# ETAimbotDetector

A Lua script for ET:Legacy servers that detects and automatically bans players using aimbots.

## Features

- Multiple detection methods for identifying aimbot users:
  - Suspicious angle changes detection
  - Headshot ratio analysis
  - Accuracy monitoring
  - Consecutive hits tracking
- Configurable warning and ban system
- Detailed logging for server administrators
- Customizable detection thresholds

## Installation

1. Copy the `scripts/aimbot_detector.lua` file to your ET:Legacy server's `etmain/lua` directory.
2. Add the script to your server's `lua_autoload` list in your server config:
   ```
   set lua_autoload "aimbot_detector.lua"
   ```
3. Restart your server or change map to load the script.

## Configuration

The script includes a configuration section at the top of the file that can be modified to adjust detection sensitivity and ban settings:

```lua
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
```

## How It Works

The script monitors player behavior using ET:Legacy's Lua callbacks:

1. **Angle Change Detection**: Monitors rapid changes in view angles before firing, which is common in aimbots that "snap" to targets.
2. **Headshot Ratio Analysis**: Tracks the ratio of headshots to total kills, flagging players with unusually high headshot rates.
3. **Accuracy Monitoring**: Calculates hit-to-shot ratio and flags players with inhuman accuracy.
4. **Consecutive Hits Tracking**: Detects players who consistently hit targets without missing.

When suspicious behavior is detected, the script issues warnings to the player. After a configurable number of warnings, the player is temporarily banned. Multiple temporary bans can lead to a permanent ban.

## Logging

The script logs all detections, warnings, and bans to both the server console and a log file. The log level can be configured to control the amount of information logged.

## Detection Tuning

The default thresholds are set to minimize false positives while still catching obvious cheaters. You may need to adjust these values based on your server's player base and gameplay style.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
