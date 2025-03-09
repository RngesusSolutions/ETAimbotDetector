using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using AimbotDetector.AimAnalyzer;
using AimbotDetector.DemoParser;
// Comment out or conditionally include Visualization namespace
// using AimbotDetector.Visualization;
using CommandLine;
using Newtonsoft.Json;

namespace AimbotDetector
{
    class Program
    {
        static void Main(string[] args)
        {
            ShowBanner();

            // Parse command line arguments
            Parser.Default.ParseArguments<EnhancedOptions>(args)
                .WithParsed(RunWithOptions)
                .WithNotParsed(HandleParseError);
        }

        static void RunWithOptions(EnhancedOptions options)
        {
            try
            {
                var cli = new EnhancedCommandLine(options);
                int exitCode = cli.Execute();

                if (exitCode != 0)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("Analysis completed with errors.");
                    Console.ResetColor();
                    Environment.Exit(exitCode);
                }
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"An unhandled error occurred: {ex.Message}");
                Console.ResetColor();

                if (options.Verbose)
                {
                    Console.WriteLine(ex.StackTrace);
                }

                Environment.Exit(1);
            }
        }

        static void HandleParseError(IEnumerable<Error> errors)
        {
            Console.WriteLine("Error parsing command line arguments:");
            foreach (var error in errors)
            {
                Console.WriteLine($"  {error}");
            }
        }

        static void ShowBanner()
        {
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine(@"
  ______  _______      _____  __  __ __  ______   ______  ______     
 |  ____||__   __|    / ____||  \/  |\ \|  ____| /  __  \|__   __|
 | |__      | |______| |     | \  / | | | |__   |  |  |  |  | |   
 |  __|     | |______| |     | |\/| | | |  __|  |  |  |  |  | |   
 | |____    | |      | |____ | |  | |_| | |____ |  |__|  |  | |   
 |______|   |_|       \_____||_|  |_|\_\|______| \______/   |_|   
                                                                  
   D E T E C T O R  v2.0  -  Enhanced Cheat Detection System
   (c) 2025 - For ET: Legacy Demo Analysis
   
");
            Console.ResetColor();
        }
    }

    // The original Options and AnalysisResult class are now moved to EnhancedCommandLine.cs
    // They're kept here for backward compatibility but should be considered deprecated

    [Obsolete("Use EnhancedOptions from EnhancedCommandLine.cs instead")]
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

    // The AnalysisResult class has been moved to its own file
    // This comment is kept for documentation purposes
}
