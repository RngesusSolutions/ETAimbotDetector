# ETAimbotDetector - Server Operator Guide

## Overview

ETAimbotDetector is a Lua script for ET:Legacy servers that helps detect and ban players using aimbots. This guide provides detailed information for server operators on how to install, configure, and monitor the script.

## Installation

1. Copy the `scripts/aimbot_detector.lua` file to your ET:Legacy server's `etmain/lua` directory.
2. Add the script to your server's `lua_autoload` list in your server config:
   ```
   set lua_autoload "aimbot_detector.lua"
   ```
3. Restart your server or change map to load the script.

## Configuration

The script includes a configuration section at the top of the file that can be modified to adjust detection sensitivity and ban settings. Here's a detailed explanation of each setting:

### Detection Thresholds

- `MAX_ANGLE_CHANGE`: Maximum angle change in degrees that's considered valid (to filter out glitches)
- `ANGLE_CHANGE_THRESHOLD`: Angle change threshold for suspicious activity (degrees)
- `HEADSHOT_RATIO_THRESHOLD`: Ratio of headshots to total kills that's considered suspicious (0.0-1.0)
- `ACCURACY_THRESHOLD`: Accuracy threshold that's considered suspicious (0.0-1.0)
- `CONSECUTIVE_HITS_THRESHOLD`: Number of consecutive hits that's considered suspicious

### Advanced Detection Settings

- `DETECTION_INTERVAL`: Minimum time between detections in milliseconds
- `PATTERN_DETECTION`: Enable pattern-based detection
- `STATISTICAL_ANALYSIS`: Enable statistical analysis
- `MIN_SAMPLES_REQUIRED`: Minimum number of samples required for statistical analysis
- `CONFIDENCE_THRESHOLD`: Confidence threshold for aimbot detection

### Weapon-Specific Settings

- `WEAPON_SPECIFIC_THRESHOLDS`: Enable weapon-specific thresholds

The script now includes weapon-specific thresholds that adjust detection sensitivity based on the weapon being used. This helps reduce false positives for weapons that naturally have higher accuracy or headshot rates.

### Warning and Ban Settings

- `WARNINGS_BEFORE_BAN`: Number of warnings before a temporary ban is issued
- `BAN_DURATION`: Temporary ban duration in days
- `PERMANENT_BAN_THRESHOLD`: Number of temporary bans before a permanent ban

### Logging Settings

- `LOG_LEVEL`: Controls the amount of information logged
  - 0: No logging
  - 1: Minimal logging (warnings and bans only)
  - 2: Detailed logging (includes player connections and detections)
  - 3: Debug logging (includes all events and calculations)
- `LOG_FILE`: Name of the log file

### Detection Method Toggles

- `DETECT_ANGLE_CHANGES`: Enable/disable suspicious angle changes detection
- `DETECT_HEADSHOT_RATIO`: Enable/disable suspicious headshot ratio detection
- `DETECT_ACCURACY`: Enable/disable suspicious accuracy detection
- `DETECT_CONSECUTIVE_HITS`: Enable/disable suspicious consecutive hits detection

### Additional Options

- `DEBUG_MODE`: Enable/disable debug logging to server console
- `IGNORE_OMNIBOTS`: Skip detection for OMNIBOT players
- `CHAT_WARNINGS`: Show warnings in player chat

### Aimbot Type Detection

The script can now differentiate between different types of aimbots:

- **Normal Aimbots**: Characterized by sudden, large angle changes and perfect accuracy
- **Humanized Aimbots**: Characterized by smoother movements but still with suspicious patterns

The detection system uses a confidence scoring approach rather than binary detection, which helps reduce false positives while still catching sophisticated cheats.


## Monitoring and Maintenance

### Log Analysis

The script logs all detections, warnings, and bans to both the server console and a log file. Regularly check the log file for patterns of false positives or missed detections.

### Adjusting Thresholds

If you notice false positives (legitimate players being flagged) or false negatives (cheaters not being detected), adjust the thresholds accordingly:

- For false positives: Increase thresholds or increase the number of warnings before ban
- For false negatives: Decrease thresholds or decrease the number of warnings before ban

### Ban Management

The script uses ET:Legacy's built-in ban system. Bans are stored in your server's ban list. You can manage bans using standard ET:Legacy admin commands.

## Troubleshooting

### Script Not Loading

- Check that the script is in the correct directory
- Verify that the script is added to the `lua_autoload` list
- Check the server logs for Lua errors

### Detection Issues

- If legitimate players are being flagged, increase the detection thresholds
- If cheaters are not being detected, decrease the detection thresholds
- Consider disabling specific detection methods that may be causing problems

## Advanced Usage

### Custom Detection Methods

Advanced users can modify the script to add custom detection methods by:

1. Adding a new detection function
2. Adding configuration options for the new method
3. Calling the new detection function from the `runDetection` function

### Integration with Other Scripts

The script can be integrated with other ET:Legacy Lua scripts by:

1. Ensuring that callback functions don't conflict
2. Sharing player data between scripts if needed

## Support

For issues, questions, or contributions, please visit the GitHub repository at https://github.com/RngesusSolutions/ETAimbotDetector
