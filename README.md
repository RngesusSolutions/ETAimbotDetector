# ET Aimbot Detection System

This system analyzes Enemy Territory demo files (.dm_84) to detect potential aimbot usage. It's specifically designed to identify behaviors consistent with the CCHookReloaded aimbot.

## Overview

The ET Aimbot Detection System uses advanced statistical analysis to identify suspicious aiming behaviors in demo recordings. The system:

1. Parses .dm_84 demo files
2. Extracts player movements, view angles, and shooting patterns
3. Applies multiple detection algorithms to identify aimbot signatures
4. Generates detailed reports and visualizations

## Features

- **Multi-layered Detection**: Uses 8 different detection algorithms to identify various aimbot behaviors
- **Statistical Analysis**: Applies mathematical models to differentiate human from computer-assisted aiming
- **Visualization Tools**: Generates interactive HTML visualizations of aim patterns
- **Comprehensive Reporting**: Creates detailed JSON and text reports of analysis results

## Detection Techniques

The system employs the following detection methods:

1. **Snap Aim Detection**: Identifies unnaturally fast aim movements
2. **Precision Aim Detection**: Detects inhuman aiming precision
3. **Reaction Time Detection**: Identifies reactions faster than human capabilities
4. **Aim Consistency Detection**: Detects unnaturally consistent aim patterns
5. **Target Priority Detection**: Analyzes target selection patterns
6. **Smoothness Analysis**: Detects artificial smoothing patterns
7. **Aim Jitter Detection**: Identifies lack of natural micro-movements
8. **Aim Lock Detection**: Detects targeting and tracking behavior consistent with aimbots

## Setup Instructions

### Prerequisites

- Visual Studio 2022
- .NET 6.0 SDK or later
- Knowledge of Enemy Territory demo formats
