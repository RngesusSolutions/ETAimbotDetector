using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using AimbotDetector.AimAnalyzer;
using AimbotDetector.DemoParser;
using AimbotDetector.Visualization;
using CommandLine;
using CommandLine.Text;

namespace AimbotDetector
{
    public class EnhancedOptions
    {
        [Option('i', "input", Required = true, HelpText = "Input demo file path (.dm_84)")]
        public string InputFile { get; set; } = string.Empty;

        [Option('o', "output", Required = false, HelpText = "Output directory for results")]
        public string OutputDirectory { get; set; } = "results";

        [Option('t', "threshold", Required = false, Default = -1.0f, HelpText = "Cheat detection threshold (0.0-1.0). Use -1 for default.")]
        public float Threshold { get; set; }

        [Option('v', "visualize", Required = false, Default = true, HelpText = "Generate visualization of results")]
        public bool Visualize { get; set; }

        [Option('d', "detailed", Required = false, Default = false, HelpText = "Generate detailed report")]
        public bool DetailedReport { get; set; }

        [Option('m', "multi-player", Required = false, Default = true, HelpText = "Analyze all players in demo, not just the recorder")]
        public bool AnalyzeAllPlayers { get; set; }

        [Option('p', "profile", Required = false, HelpText = "Use specific calibration profile")]
        public string CalibrationProfile { get; set; } = string.Empty;

        [Option('c', "calibrate", Required = false, Default = false, HelpText = "Calibrate thresholds using this demo (assuming all players are clean)")]
        public bool CalibrateThresholds { get; set; }

        [Option('b', "batch", Required = false, HelpText = "Process multiple demo files from a directory")]
        public string BatchDirectory { get; set; } = string.Empty;

        [Option("export-stats", Required = false, Default = false, HelpText = "Export player statistics for external analysis")]
        public bool ExportStatistics { get; set; }

        [Option("web-report", Required = false, Default = false, HelpText = "Generate web-based report with interactive visualizations")]
        public bool WebReport { get; set; }

        [Option("verbose", Required = false, Default = false, HelpText = "Enable verbose logging")]
        public bool Verbose { get; set; }

        [Option("compare", Required = false, HelpText = "Compare with previous analysis results")]
        public string CompareWithReport { get; set; } = string.Empty;

        [Option("report-only", Required = false, Default = false, HelpText = "Generate report from existing analysis results (skips analysis)")]
        public bool ReportOnly { get; set; }

        [Usage(ApplicationAlias = "AimbotDetector")]
        public static IEnumerable<Example> Examples
        {
            get
            {
                return new List<Example>()
                {
                    new Example("Analyze a demo file",
                        new EnhancedOptions { InputFile = "match.dm_84" }),

                    new Example("Analyze with custom threshold",
                        new EnhancedOptions { InputFile = "match.dm_84", Threshold = 0.6f }),

                    new Example("Calibrate thresholds using known clean players",
                        new EnhancedOptions { InputFile = "clean_match.dm_84", CalibrateThresholds = true }),

                    new Example("Batch process all demos in a directory",
                        new EnhancedOptions { BatchDirectory = "demos/", OutputDirectory = "reports/" }),

                    new Example("Generate web report from existing results",
                        new EnhancedOptions { InputFile = "match.dm_84", ReportOnly = true, WebReport = true })
                };
            }
        }
    }

    public class EnhancedCommandLine
    {
        private readonly EnhancedOptions _options;

        public EnhancedCommandLine(EnhancedOptions options)
        {
            _options = options;
        }

        public int Execute()
        {
            try
            {
                if (!string.IsNullOrEmpty(_options.BatchDirectory))
                {
                    return ProcessBatchMode();
                }
                else
                {
                    return ProcessSingleFile();
                }
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"Error: {ex.Message}");
                Console.ResetColor();

                if (_options.Verbose)
                {
                    Console.WriteLine(ex.StackTrace);
                }

                return 1;
            }
        }

        private int ProcessSingleFile()
        {
            ValidateOptions();

            if (_options.ReportOnly)
            {
                return GenerateReportsOnly();
            }

            Console.WriteLine($"Processing demo file: {_options.InputFile}");

            // Create output directory
            Directory.CreateDirectory(_options.OutputDirectory);

            // Create analyzer with selected profile
            var analyzer = CreateAnalyzer();

            // Run the analysis
            var analysisResults = RunAnalysis(analyzer);

            if (analysisResults == null || !analysisResults.Any())
            {
                Console.WriteLine("No valid analysis results generated. Check your demo file.");
                return 1;
            }

            // Generate reports
            GenerateReports(analysisResults);

            // Compare with previous results if requested
            if (!string.IsNullOrEmpty(_options.CompareWithReport))
            {
                CompareWithPreviousResults(analysisResults);
            }

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("Analysis complete. Results saved to output directory.");
            Console.ResetColor();

            return 0;
        }

        private int ProcessBatchMode()
        {
            if (!Directory.Exists(_options.BatchDirectory))
            {
                Console.WriteLine($"Batch directory not found: {_options.BatchDirectory}");
                return 1;
            }

            var demoFiles = Directory.GetFiles(_options.BatchDirectory, "*.dm_84", SearchOption.AllDirectories);

            if (demoFiles.Length == 0)
            {
                Console.WriteLine($"No demo files found in directory: {_options.BatchDirectory}");
                return 1;
            }

            Console.WriteLine($"Found {demoFiles.Length} demo files to process.");

            // Create analyzer with selected profile (will be reused for all files)
            var analyzer = CreateAnalyzer();

            int successCount = 0;
            int failCount = 0;

            foreach (var demoFile in demoFiles)
            {
                try
                {
                    Console.WriteLine($"\nProcessing: {Path.GetFileName(demoFile)}");

                    // Create subdirectory for this demo's results
                    string demoName = Path.GetFileNameWithoutExtension(demoFile);
                    string outputDir = Path.Combine(_options.OutputDirectory, demoName);
                    Directory.CreateDirectory(outputDir);

                    // Override input and output for this file
                    _options.InputFile = demoFile;
                    string originalOutput = _options.OutputDirectory;
                    _options.OutputDirectory = outputDir;

                    // Run analysis
                    var results = RunAnalysis(analyzer);

                    if (results != null && results.Any())
                    {
                        // Generate reports
                        GenerateReports(results);
                        successCount++;
                    }
                    else
                    {
                        Console.WriteLine($"No valid results for: {demoFile}");
                        failCount++;
                    }

                    // Restore original output directory
                    _options.OutputDirectory = originalOutput;
                }
                catch (Exception ex)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine($"Error processing {demoFile}: {ex.Message}");
                    Console.ResetColor();

                    if (_options.Verbose)
                    {
                        Console.WriteLine(ex.StackTrace);
                    }

                    failCount++;
                }
            }

            // Generate batch summary
            GenerateBatchSummary(demoFiles.Length, successCount, failCount);

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine($"Batch processing complete. Processed {successCount} files successfully, {failCount} failed.");
            Console.ResetColor();

            return failCount > 0 ? 1 : 0;
        }

        private void ValidateOptions()
        {
            try
            {
                if (!_options.ReportOnly && !File.Exists(_options.InputFile))
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine($"Error: Input demo file not found: {_options.InputFile}");
                    Console.ResetColor();
                    throw new FileNotFoundException($"Input demo file not found: {_options.InputFile}");
                }

                if (!string.IsNullOrEmpty(_options.CompareWithReport) && !File.Exists(_options.CompareWithReport))
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine($"Error: Comparison report file not found: {_options.CompareWithReport}");
                    Console.ResetColor();
                    throw new FileNotFoundException($"Comparison report file not found: {_options.CompareWithReport}");
                }

                if (_options.Threshold > 1.0f || _options.Threshold < -1.0f)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("Error: Threshold must be between 0.0 and 1.0, or -1 for default");
                    Console.ResetColor();
                    throw new ArgumentOutOfRangeException("Threshold must be between 0.0 and 1.0, or -1 for default");
                }
            }
            catch (Exception ex)
            {
                if (_options.Verbose)
                {
                    Console.WriteLine(ex.StackTrace);
                }
                throw; // Rethrow to be handled by the caller
            }
        }

        private object CreateAnalyzer()
        {
            if (_options.AnalyzeAllPlayers)
            {
                return new AimAnalyzer.MultiPlayerAnalyzer(_options.CalibrationProfile);
            }
            else
            {
                return new AimAnalyzer.CalibratedAimAnalyzer(_options.CalibrationProfile);
            }
        }

        private Dictionary<string, AnalysisResult> RunAnalysis(object analyzer)
        {
            // Parse demo file
            var demoFile = new DemoParser.DemoFile(_options.InputFile);
            bool parseSuccess = demoFile.Parse();

            if (!parseSuccess)
            {
                Console.WriteLine("Failed to parse demo file. Exiting.");
                return null;
            }

            Console.WriteLine($"Successfully parsed demo file. Found {demoFile.Players.Count} players.");

            // Check if we should calibrate thresholds
            if (_options.CalibrateThresholds)
            {
                if (demoFile.Players.Count < 2)
                {
                    Console.WriteLine("Not enough players for calibration. Need at least 2 players.");
                }
                else
                {
                    Console.WriteLine("Calibrating detection thresholds using this demo...");

                    if (analyzer is AimAnalyzer.CalibratedAimAnalyzer singleAnalyzer)
                    {
                        singleAnalyzer.CalibrateFromCleanData(demoFile.Players);
                    }
                    else if (analyzer is AimAnalyzer.MultiPlayerAnalyzer multiAnalyzer)
                    {
                        // We're using reflection here since we're passing a generic object
                        var calibrateMethod = multiAnalyzer.GetType().GetMethod("CalibrateFromCleanData");
                        calibrateMethod?.Invoke(multiAnalyzer, new object[] { demoFile.Players });
                    }

                    Console.WriteLine("Calibration complete.");
                }
            }

            // Run analysis
            if (analyzer is AimAnalyzer.CalibratedAimAnalyzer singlePlayerAnalyzer)
            {
                float threshold = _options.Threshold >= 0 ? _options.Threshold : singlePlayerAnalyzer.GetSuspiciousThreshold();

                // Analyze only the demo recorder
                var player = demoFile.Players.FirstOrDefault();
                if (player == null)
                {
                    Console.WriteLine("No player data found in the demo.");
                    return null;
                }

                var detectionResults = singlePlayerAnalyzer.Analyze(player);
                float overallProbability = singlePlayerAnalyzer.GetOverallCheatingProbability(detectionResults);
                bool isCheating = overallProbability >= threshold;

                var result = new AnalysisResult
                {
                    PlayerName = player.Name,
                    PlayerID = player.PlayerID,
                    CheatingProbability = overallProbability,
                    IsCheating = isCheating,
                    DetectionResults = detectionResults,
                    AnalyzedTimestamp = DateTime.Now
                };

                return new Dictionary<string, AnalysisResult> { { player.Name, result } };
            }
            else if (analyzer is AimAnalyzer.MultiPlayerAnalyzer multiPlayerAnalyzer)
            {
                // Analyze all players
                float threshold = _options.Threshold >= 0 ? _options.Threshold : -1; // -1 means use default
                var analyzerResults = multiPlayerAnalyzer.AnalyzeAllPlayers(demoFile.Players, threshold);
                
                // Convert from AimAnalyzer.AnalysisResult to AimbotDetector.AnalysisResult
                var results = new Dictionary<string, AnalysisResult>();
                foreach (var kvp in analyzerResults)
                {
                    results[kvp.Key] = new AnalysisResult(kvp.Value);
                }
                
                return results;
            }

            return null;
        }

        private int GenerateReportsOnly()
        {
            Console.WriteLine("Generating reports from existing analysis results...");

            string resultsFile = Path.Combine(Path.GetDirectoryName(_options.InputFile), "results.json");
            if (!File.Exists(resultsFile))
            {
                Console.WriteLine($"Results file not found: {resultsFile}");
                return 1;
            }

            // Load existing results
            var results = Newtonsoft.Json.JsonConvert.DeserializeObject<Dictionary<string, AnalysisResult>>(
                File.ReadAllText(resultsFile));

            if (results == null || !results.Any())
            {
                Console.WriteLine("No valid results found in the results file.");
                return 1;
            }

            // Generate reports
            GenerateReports(results);

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("Reports generated successfully.");
            Console.ResetColor();

            return 0;
        }

        private void GenerateReports(Dictionary<string, AnalysisResult> results)
        {
            // Generate summary report
            GenerateSummaryReport(results, _options.OutputDirectory);

            // Generate detailed reports if requested
            if (_options.DetailedReport)
            {
                foreach (var result in results.Values)
                {
                    GenerateDetailedReport(result, _options.OutputDirectory);
                }
            }

            // Generate visualizations if requested
            if (_options.Visualize)
            {
                GenerateVisualizations(results, _options.OutputDirectory);
            }

            // Generate web report if requested
            if (_options.WebReport)
            {
                GenerateWebReport(results, _options.OutputDirectory);
            }

            // Export statistics if requested
            if (_options.ExportStatistics)
            {
                ExportPlayerStatistics(results, _options.OutputDirectory);
            }

            // Save the raw analysis results
            string resultsJson = Newtonsoft.Json.JsonConvert.SerializeObject(results, Newtonsoft.Json.Formatting.Indented);
            File.WriteAllText(Path.Combine(_options.OutputDirectory, "results.json"), resultsJson);
        }

        private void GenerateSummaryReport(Dictionary<string, AnalysisResult> results, string outputDirectory)
        {
            Console.WriteLine("Generating summary report...");

            var summary = new
            {
                AnalysisTime = DateTime.Now,
                InputFile = _options.InputFile,
                TotalPlayers = results.Count,
                SuspiciousPlayers = results.Count(r => r.Value.IsCheating),
                CalibrationProfile = GetAnalyzerProfileName(),
                Players = results.Values.OrderByDescending(r => r.CheatingProbability)
                    .Select(r => new
                    {
                        r.PlayerName,
                        r.PlayerID,
                        CheatingProbability = r.CheatingProbability,
                        Status = r.IsCheating ? "SUSPICIOUS" : "CLEAN",
                        TopDetections = r.DetectionResults
                            .OrderByDescending(d => d.ConfidenceLevel)
                            .Take(3)
                            .Select(d => new { d.RuleName, d.ConfidenceLevel })
                    })
            };

            string summaryJson = Newtonsoft.Json.JsonConvert.SerializeObject(summary, Newtonsoft.Json.Formatting.Indented);
            File.WriteAllText(Path.Combine(outputDirectory, "summary.json"), summaryJson);

            // Generate text report
            using (StreamWriter writer = new StreamWriter(Path.Combine(outputDirectory, "summary.txt")))
            {
                writer.WriteLine("ET Aimbot Detection Report");
                writer.WriteLine("=========================");
                writer.WriteLine($"Analysis Time: {DateTime.Now}");
                writer.WriteLine($"Input File: {_options.InputFile}");
                writer.WriteLine($"Calibration Profile: {GetAnalyzerProfileName()}");
                writer.WriteLine($"Total Players: {results.Count}");
                writer.WriteLine($"Suspicious Players: {results.Count(r => r.Value.IsCheating)}");
                writer.WriteLine();
                writer.WriteLine("Player Results:");
                writer.WriteLine("---------------");

                foreach (var result in results.Values.OrderByDescending(r => r.CheatingProbability))
                {
                    writer.WriteLine($"Player: {result.PlayerName} (ID: {result.PlayerID})");
                    writer.WriteLine($"Cheating Probability: {result.CheatingProbability:P2}");
                    writer.WriteLine($"Status: {(result.IsCheating ? "SUSPICIOUS" : "CLEAN")}");

                    var topDetections = result.DetectionResults
                        .OrderByDescending(d => d.ConfidenceLevel)
                        .Take(3);

                    writer.WriteLine("Top Detections:");
                    foreach (var detection in topDetections)
                    {
                        writer.WriteLine($"  - {detection.RuleName}: {detection.ConfidenceLevel:P2}");
                    }

                    writer.WriteLine();
                }
            }
        }

        private void GenerateDetailedReport(AnalysisResult result, string outputDirectory)
        {
            var playerDirectory = Path.Combine(outputDirectory, SanitizeFilename(result.PlayerName));
            Directory.CreateDirectory(playerDirectory);

            // Save detailed detection results
            foreach (var detection in result.DetectionResults)
            {
                if (detection.ConfidenceLevel > 0 && detection.Evidence.Count > 0)
                {
                    var detailedResult = new
                    {
                        detection.RuleName,
                        detection.Description,
                        detection.ConfidenceLevel,
                        Evidence = detection.Evidence.Select(e => new
                        {
                            e.Timestamp,
                            e.Description,
                            e.Severity,
                            ViewAngles = new { e.ViewAngles.X, e.ViewAngles.Y, e.ViewAngles.Z }
                        }).OrderByDescending(e => e.Severity)
                    };

                    string resultJson = Newtonsoft.Json.JsonConvert.SerializeObject(detailedResult, Newtonsoft.Json.Formatting.Indented);
                    string filename = SanitizeFilename(detection.RuleName) + ".json";
                    File.WriteAllText(Path.Combine(playerDirectory, filename), resultJson);
                }
            }

            // Save player statistics if available
            if (result.PlayerStatistics != null)
            {
                string statsJson = Newtonsoft.Json.JsonConvert.SerializeObject(result.PlayerStatistics, Newtonsoft.Json.Formatting.Indented);
                File.WriteAllText(Path.Combine(playerDirectory, "player_statistics.json"), statsJson);
            }
        }

        private void GenerateVisualizations(Dictionary<string, AnalysisResult> results, string outputDirectory)
        {
            Console.WriteLine("Generating visualizations...");

            try
            {
                // Check for null results
                if (results == null || results.Count == 0)
                {
                    Console.WriteLine("Warning: No results to generate visualizations from.");
                    return;
                }

                var visualizer = new Visualization.ResultVisualizer();

                // Generate visualizations for each player
                foreach (var result in results.Values)
                {
                    if (result != null && result.PlayerAimData != null && result.PlayerAimData.Count > 0 && result.DetectionResults != null)
                    {
                        try
                        {
                            string visualizationPath = Path.Combine(outputDirectory, $"{SanitizeFilename(result.PlayerName)}_visualization.html");
                            // Convert to the correct type for visualization
                            visualizer.GenerateVisualization(result.PlayerAimData, result.DetectionResults, visualizationPath);
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"Error generating visualization for player {result.PlayerName}: {ex.Message}");
                            if (_options.Verbose)
                            {
                                Console.WriteLine(ex.StackTrace);
                            }
                            // Continue with other players rather than crashing
                        }
                    }
                }

                // Generate summary visualization
                string summaryVisualizationPath = Path.Combine(outputDirectory, "summary_visualization.html");
                
                // Convert dictionary to the correct type for visualization
                var visualizationResults = ConvertToVisualizationResults(results);
                visualizer.GenerateSummaryVisualization(visualizationResults, summaryVisualizationPath);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error generating visualizations: {ex.Message}");
                if (_options.Verbose)
                {
                    Console.WriteLine(ex.StackTrace);
                }
                // Continue execution rather than crashing the application
            }
        }

        private void GenerateWebReport(Dictionary<string, AnalysisResult> results, string outputDirectory)
        {
            Console.WriteLine("Generating web report...");

            try
            {
                // Check for null results
                if (results == null || results.Count == 0)
                {
                    Console.WriteLine("Warning: No results to generate web report from.");
                    return;
                }

                // Create web report directory
                string webReportDir = Path.Combine(outputDirectory, "web_report");
                Directory.CreateDirectory(webReportDir);

                // Generate interactive HTML report
                var webReportGenerator = new Visualization.WebReportGenerator();
                
                // Convert dictionary to the correct type for visualization
                var visualizationResults = ConvertToVisualizationResults(results);
                webReportGenerator.GenerateInteractiveReport(visualizationResults, _options.InputFile, webReportDir);

                Console.WriteLine($"Web report generated at: {webReportDir}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error generating web report: {ex.Message}");
                if (_options.Verbose)
                {
                    Console.WriteLine(ex.StackTrace);
                }
                // Continue execution rather than crashing the application
            }
        }

        private void ExportPlayerStatistics(Dictionary<string, AnalysisResult> results, string outputDirectory)
        {
            Console.WriteLine("Exporting player statistics...");

            string statsDir = Path.Combine(outputDirectory, "statistics");
            Directory.CreateDirectory(statsDir);

            // Export each player's statistics
            foreach (var result in results.Values)
            {
                if (result.PlayerStatistics != null)
                {
                    string statsJson = Newtonsoft.Json.JsonConvert.SerializeObject(result.PlayerStatistics, Newtonsoft.Json.Formatting.Indented);
                    File.WriteAllText(Path.Combine(statsDir, $"{SanitizeFilename(result.PlayerName)}_stats.json"), statsJson);
                }

                // Export CSV format for easy import into analysis tools
                if (result.PlayerAimData != null && result.PlayerAimData.Count > 0)
                {
                    using (StreamWriter writer = new StreamWriter(Path.Combine(statsDir, $"{SanitizeFilename(result.PlayerName)}_aim_data.csv")))
                    {
                        // Write header
                        writer.WriteLine("Timestamp,PitchAngle,YawAngle,PitchVelocity,YawVelocity,TotalAngularVelocity,IsFiring,HasVisibleEnemy,AngleToTarget");

                        // Write data rows
                        foreach (var data in result.PlayerAimData)
                        {
                            writer.WriteLine($"{data.Timestamp},{data.ViewAngles.X},{data.ViewAngles.Y},{data.PitchVelocity},{data.YawVelocity},{data.TotalAngularVelocity},{(data.IsFiring ? 1 : 0)},{(data.HasVisibleEnemy ? 1 : 0)},{data.AngleToTarget}");
                        }
                    }
                }
            }
        }

        private void CompareWithPreviousResults(Dictionary<string, AnalysisResult> currentResults)
        {
            Console.WriteLine("Comparing with previous analysis results...");

            try
            {
                // Load previous results
                var previousResults = Newtonsoft.Json.JsonConvert.DeserializeObject<Dictionary<string, AnalysisResult>>(
                    File.ReadAllText(_options.CompareWithReport));

                if (previousResults == null || !previousResults.Any())
                {
                    Console.WriteLine("No valid results in the comparison file.");
                    return;
                }

                // Generate comparison report
                using (StreamWriter writer = new StreamWriter(Path.Combine(_options.OutputDirectory, "comparison_report.txt")))
                {
                    writer.WriteLine("ET Aimbot Detection - Comparison Report");
                    writer.WriteLine("========================================");
                    writer.WriteLine($"Current Analysis: {DateTime.Now}");
                    writer.WriteLine($"Previous Analysis: {previousResults.Values.FirstOrDefault()?.AnalyzedTimestamp}");
                    writer.WriteLine();

                    // Find players that appear in both analyses
                    var commonPlayers = currentResults.Keys.Intersect(previousResults.Keys).ToList();

                    writer.WriteLine($"Found {commonPlayers.Count} players present in both analyses.");
                    writer.WriteLine();

                    foreach (var playerName in commonPlayers)
                    {
                        var current = currentResults[playerName];
                        var previous = previousResults[playerName];

                        writer.WriteLine($"Player: {playerName}");
                        writer.WriteLine($"Previous Status: {(previous.IsCheating ? "SUSPICIOUS" : "CLEAN")} ({previous.CheatingProbability:P2})");
                        writer.WriteLine($"Current Status: {(current.IsCheating ? "SUSPICIOUS" : "CLEAN")} ({current.CheatingProbability:P2})");

                        float change = current.CheatingProbability - previous.CheatingProbability;
                        writer.WriteLine($"Change: {change:P2} {(change > 0 ? "increase" : "decrease")}");

                        if (current.IsCheating != previous.IsCheating)
                        {
                            writer.WriteLine($"Status changed from {(previous.IsCheating ? "SUSPICIOUS" : "CLEAN")} to {(current.IsCheating ? "SUSPICIOUS" : "CLEAN")}");
                        }

                        writer.WriteLine();
                    }

                    // New players
                    var newPlayers = currentResults.Keys.Except(previousResults.Keys).ToList();
                    if (newPlayers.Any())
                    {
                        writer.WriteLine("New Players (not in previous analysis):");
                        foreach (var playerName in newPlayers)
                        {
                            var player = currentResults[playerName];
                            writer.WriteLine($"  - {playerName}: {(player.IsCheating ? "SUSPICIOUS" : "CLEAN")} ({player.CheatingProbability:P2})");
                        }
                        writer.WriteLine();
                    }

                    // Missing players
                    var missingPlayers = previousResults.Keys.Except(currentResults.Keys).ToList();
                    if (missingPlayers.Any())
                    {
                        writer.WriteLine("Players from previous analysis not present in current analysis:");
                        foreach (var playerName in missingPlayers)
                        {
                            var player = previousResults[playerName];
                            writer.WriteLine($"  - {playerName}: {(player.IsCheating ? "SUSPICIOUS" : "CLEAN")} ({player.CheatingProbability:P2})");
                        }
                        writer.WriteLine();
                    }
                }

                Console.WriteLine("Comparison report generated.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error generating comparison report: {ex.Message}");
                if (_options.Verbose)
                {
                    Console.WriteLine(ex.StackTrace);
                }
            }
        }

        private void GenerateBatchSummary(int totalFiles, int successCount, int failCount)
        {
            Console.WriteLine("Generating batch processing summary...");

            using (StreamWriter writer = new StreamWriter(Path.Combine(_options.OutputDirectory, "batch_summary.txt")))
            {
                writer.WriteLine("ET Aimbot Detection - Batch Processing Summary");
                writer.WriteLine("=============================================");
                writer.WriteLine($"Batch Directory: {_options.BatchDirectory}");
                writer.WriteLine($"Process Time: {DateTime.Now}");
                writer.WriteLine($"Total Files: {totalFiles}");
                writer.WriteLine($"Successfully Processed: {successCount}");
                writer.WriteLine($"Failed: {failCount}");
                writer.WriteLine($"Success Rate: {(totalFiles > 0 ? (successCount * 100.0 / totalFiles) : 0):F1}%");
                writer.WriteLine();

                // List suspicious players across all demos
                writer.WriteLine("Suspicious Players Summary:");
                writer.WriteLine("---------------------------");

                Dictionary<string, List<string>> suspiciousPlayersDemos = GetSuspiciousPlayersAcrossBatch();

                foreach (var player in suspiciousPlayersDemos.OrderByDescending(p => p.Value.Count))
                {
                    writer.WriteLine($"{player.Key}: Found suspicious in {player.Value.Count} demos");
                    foreach (var demo in player.Value)
                    {
                        writer.WriteLine($"  - {demo}");
                    }
                    writer.WriteLine();
                }
            }
        }

        private Dictionary<string, List<string>> GetSuspiciousPlayersAcrossBatch()
        {
            var result = new Dictionary<string, List<string>>();

            // Look for results.json in each demo subdirectory
            foreach (var dir in Directory.GetDirectories(_options.OutputDirectory))
            {
                string resultsFile = Path.Combine(dir, "results.json");
                if (!File.Exists(resultsFile)) continue;

                try
                {
                    var demoResults = Newtonsoft.Json.JsonConvert.DeserializeObject<Dictionary<string, AnalysisResult>>(
                        File.ReadAllText(resultsFile));

                    if (demoResults == null) continue;

                    string demoName = Path.GetFileName(dir);

                    foreach (var player in demoResults.Values.Where(r => r.IsCheating))
                    {
                        if (!result.ContainsKey(player.PlayerName))
                        {
                            result[player.PlayerName] = new List<string>();
                        }

                        result[player.PlayerName].Add(demoName);
                    }
                }
                catch
                {
                    // Skip files that can't be parsed
                    continue;
                }
            }

            return result;
        }

        private string GetAnalyzerProfileName()
        {
            if (string.IsNullOrEmpty(_options.CalibrationProfile))
            {
                return "default";
            }

            return _options.CalibrationProfile;
        }

        private string SanitizeFilename(string input)
        {
            // Replace invalid filename characters
            foreach (char c in Path.GetInvalidFileNameChars())
            {
                input = input.Replace(c, '_');
            }
            return input;
        }
        
        // Helper method to convert between result types
        private Dictionary<string, Visualization.AnalysisResult> ConvertToVisualizationResults(Dictionary<string, AnalysisResult> results)
        {
            var visualizationResults = new Dictionary<string, Visualization.AnalysisResult>();
            
            foreach (var kvp in results)
            {
                var result = kvp.Value;
                var visualizationResult = new Visualization.AnalysisResult
                {
                    PlayerName = result.PlayerName,
                    PlayerID = result.PlayerID,
                    CheatingProbability = result.CheatingProbability,
                    IsCheating = result.IsCheating,
                    DetectionResults = result.DetectionResults,
                    AnalyzedTimestamp = result.AnalyzedTimestamp,
                    PlayerStatistics = result.PlayerStatistics,
                    PlayerAimData = result.PlayerAimData
                };
                
                visualizationResults[kvp.Key] = visualizationResult;
            }
            
            return visualizationResults;
        }
    }
}
