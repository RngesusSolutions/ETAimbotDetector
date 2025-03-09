# ETAimbotDetector Compilation Guide

This guide explains how to compile ETAimbotDetector from source code.

## Prerequisites

- .NET 6.0 SDK or later
- Git

## Getting the Source Code

```bash
git clone https://github.com/RngesusSolutions/ETAimbotDetector.git
cd ETAimbotDetector
```

## Building from Source

### Using .NET CLI

```bash
# Build the project
dotnet build ETAimbotDetector.sln --configuration Release

# Run the application
dotnet run --project AimbotDetector/AimbotDetector.csproj -i path/to/demo.dm_84 -o results
```

### Creating Self-Contained Executables

#### Windows

```bash
dotnet publish AimbotDetector/AimbotDetector.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o build/windows
```

#### Linux

```bash
dotnet publish AimbotDetector/AimbotDetector.csproj -c Release -r linux-x64 --self-contained true -p:PublishSingleFile=true -o build/linux
```

#### macOS

```bash
dotnet publish AimbotDetector/AimbotDetector.csproj -c Release -r osx-x64 --self-contained true -p:PublishSingleFile=true -o build/macos
```

## Running Tests

```bash
dotnet test AimbotDetector.Tests/AimbotDetector.Tests.csproj
```

## Troubleshooting

### Missing .NET SDK

If you encounter errors about missing .NET SDK, download and install it from [https://dotnet.microsoft.com/download](https://dotnet.microsoft.com/download).

### Build Errors

If you encounter build errors:

1. Make sure all project references are correct
2. Restore NuGet packages: `dotnet restore`
3. Clean the solution: `dotnet clean`
4. Try building again: `dotnet build`

### Runtime Errors

If the application builds but crashes at runtime:

1. Check if you're using the correct demo file format (.dm_84)
2. Try running with the `--verbose` flag for more detailed error messages
3. Make sure all dependencies are properly installed

## Getting Help

If you encounter issues not covered in this guide, please open an issue on the GitHub repository.
