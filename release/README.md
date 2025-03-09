# ETAimbotDetector Precompiled Binaries

This directory contains precompiled binaries for ETAimbotDetector, a tool for detecting aimbots in Enemy Territory demo files.

## Available Binaries

- **Windows**: ETAimbotDetector-windows.zip
- **Linux**: ETAimbotDetector-linux.zip
- **macOS**: ETAimbotDetector-macos.zip

## Usage Instructions

1. Download the appropriate zip file for your operating system
2. Extract the zip file
3. Run the ETAimbotDetector executable from the command line:

```bash
# Windows
ETAimbotDetector.exe -i path/to/demo.dm_84 -o results

# Linux/macOS
./ETAimbotDetector -i path/to/demo.dm_84 -o results
```

## Command Line Options

- `-i, --input`: Input demo file path (.dm_84) [required]
- `-o, --output`: Output directory for results [default: results]
- `-t, --threshold`: Cheat detection threshold (0.0-1.0) [default: 0.7]
- `-v, --visualize`: Generate visualization of results [default: true]
- `-d, --detailed`: Generate detailed report [default: false]
- `-m, --multi-player`: Analyze all players in demo [default: true]
- `--web-report`: Generate web-based report with interactive visualizations [default: false]
- `--verbose`: Enable verbose logging [default: false]

## Example Commands

```bash
# Basic analysis
ETAimbotDetector -i match.dm_84

# Analysis with custom threshold
ETAimbotDetector -i match.dm_84 -t 0.6

# Generate web report
ETAimbotDetector -i match.dm_84 --web-report
```

For more information, run `ETAimbotDetector --help`
