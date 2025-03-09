using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using AimbotDetector.AimAnalyzer;
using AimbotDetector.DemoParser;
using AimbotDetector.Visualization;
using CommandLine;
using Newtonsoft.Json;

namespace AimbotDetector
{
    class Program
    {
        public class Options
        {
            [Option('i', "input", Required = true, HelpText = "Input demo file path (.dm_84)")]
            public string InputFile { get; set; } = string.Empty;
            
            [Option('o', "output", Required = false, HelpText = "Output directory for results")]
            public string OutputDirectory { get; set; } = "results";
            
            [Option('t', "threshold", Required = false, Default = 0.7f, HelpText = "Cheat detection threshold (0.0-1.0)")]
            public float Threshold { get; set; }
            
            [Option('v', "visualize", Required = false, Default = true, HelpText = "Generate visualization of results")]
            public bool Visualize { get; set; }
            
            [Option('d', "detailed", Required = false, Default = false, HelpText = "Generate detailed report")]
            public bool DetailedReport { get; set; }
        }
        
        static void Main(string[] args)
        {
            Parser.Default.ParseArguments<Options>(args)
                .WithParsed(RunDetection)
                .WithNotParsed(HandleParseError);
        }
        
        static void RunDetection(Options options)
        {
            Console.WriteLine($"Starting analysis of {options.InputFile}");
            
            // Create output directory if it doesn't exist
            Directory.CreateDirectory(options.OutputDirectory);
            
            // Parse demo file
            var demoFile = new DemoFile(options.InputFile);
            bool parseSuccess = demoFile.Parse();
            
            if (!parseSuccess)
            {
                Console.WriteLine("Failed to parse demo file. Exiting.");
                return;
            }
            
            Console.WriteLine($"Successfully parsed demo file. Found {demoFile.Players.Count} players.");
            
            // Analyze each player
            var analyzer = new AimAnalyzer.AimAnalyzer();
            var results = new Dictionary<string, AnalysisResult>();
            
            foreach (var player in demoFile.Players)
            {
                Console.WriteLine($"Analyzing player: {player.Name}");
                
                var detectionResults = analyzer.Analyze(player);
                float overallProbability = analyzer.GetOverallCheatingProbability(detectionResults);
                
                bool isCheating = overallProbability >= options.Threshold;
                
                var result = new AnalysisResult
                {
                    PlayerName = player.Name,
                    PlayerID = player.PlayerID,
                    CheatingProbability = overallProbability,
                    IsCheating = isCheating,
                    DetectionResults = detectionResults,
                    AnalyzedTimestamp = DateTime.Now
                };
                
                results.Add(player.Name, result);
                
                Console.WriteLine($"Player {player.Name}: Cheating probability {overallProbability:P2} - {(isCheating ? "SUSPICIOUS" : "CLEAN")}");
                
                // Generate per-player detailed results
                if (options.DetailedReport)
                {
                    GenerateDetailedReport(player, detectionResults, options.OutputDirectory);
                }
            }
            
            // Generate summary report
            GenerateSummaryReport(results, options.OutputDirectory);
            
            // Generate visualizations
            if (options.Visualize)
            {
                Console.WriteLine("Generating visualizations...");
                var visualizer = new ResultVisualizer();
                
                foreach (var player in demoFile.Players)
                {
                    if (results.TryGetValue(player.Name, out var result))
                    {
                        string visualizationPath = Path.Combine(options.OutputDirectory, $"{SanitizeFilename(player.Name)}_visualization.html");
                        visualizer.GenerateVisualization(player, result.DetectionResults, visualizationPath);
                    }
                }
                
                // Generate summary visualization
                string summaryVisualizationPath = Path.Combine(options.OutputDirectory, "summary_visualization.html");
                visualizer.GenerateSummaryVisualization(results, summaryVisualizationPath);
            }
            
            Console.WriteLine("Analysis complete. Results saved to output directory.");
        }
        
        static void GenerateSummaryReport(Dictionary<string, AnalysisResult> results, string outputDirectory)
        {
            var summary = new
            {
                AnalysisTime = DateTime.Now,
                TotalPlayers = results.Count,
                SuspiciousPlayers = results.Count(r => r.Value.IsCheating),
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
            
            string summaryJson = JsonConvert.SerializeObject(summary, Formatting.Indented);
            File.WriteAllText(Path.Combine(outputDirectory, "summary.json"), summaryJson);
            
            // Generate a simple text report as well
            using (StreamWriter writer = new StreamWriter(Path.Combine(outputDirectory, "summary.txt")))
            {
                writer.WriteLine("ET Aimbot Detection Report");
                writer.WriteLine("=========================");
                writer.WriteLine($"Analysis Time: {DateTime.Now}");
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
        
        static void GenerateDetailedReport(PlayerData player, List<DetectionResult> detectionResults, string outputDirectory)
        {
            var playerDirectory = Path.Combine(outputDirectory, SanitizeFilename(player.Name));
            Directory.CreateDirectory(playerDirectory);
            
            // Save detailed detection results
            foreach (var result in detectionResults)
            {
                if (result.ConfidenceLevel > 0 && result.Evidence.Count > 0)
                {
                    var detailedResult = new
                    {
                        result.RuleName,
                        result.Description,
                        result.ConfidenceLevel,
                        Evidence = result.Evidence.Select(e => new
                        {
                            e.Timestamp,
                            e.Description,
                            e.Severity,
                            ViewAngles = new { e.ViewAngles.X, e.ViewAngles.Y, e.ViewAngles.Z }
                        })
                    };
                    
                    string resultJson = JsonConvert.SerializeObject(detailedResult, Formatting.Indented);
                    string filename = SanitizeFilename(result.RuleName) + ".json";
                    File.WriteAllText(Path.Combine(playerDirectory, filename), resultJson);
                }
            }
            
            // Save raw aim data
            var rawAimData = player.AimData.Select(data => new
            {
                data.Timestamp,
                Position = new { data.Position.X, data.Position.Y, data.Position.Z },
                ViewAngles = new { data.ViewAngles.X, data.ViewAngles.Y, data.ViewAngles.Z },
                data.IsFiring
            });
            
            string aimDataJson = JsonConvert.SerializeObject(rawAimData, Formatting.Indented);
            File.WriteAllText(Path.Combine(playerDirectory, "raw_aim_data.json"), aimDataJson);
        }
        
        static void HandleParseError(IEnumerable<e> errors)
        {
            Console.WriteLine("Error parsing command line arguments:");
            foreach (var error in errors)
            {
                Console.WriteLine($"  {error}");
            }
        }
        
        static string SanitizeFilename(string input)
        {
            // Replace invalid filename characters
            foreach (char c in Path.GetInvalidFileNameChars())
            {
                input = input.Replace(c, '_');
            }
            return input;
        }
    }
    
    public class AnalysisResult
    {
        public string PlayerName { get; set; } = string.Empty;
        public int PlayerID { get; set; }
        public float CheatingProbability { get; set; }
        public bool IsCheating { get; set; }
        public List<DetectionResult> DetectionResults { get; set; } = new List<DetectionResult>();
        public DateTime AnalyzedTimestamp { get; set; }
    }
}