using System;
using System.Collections.Generic;
using AimbotDetector.DemoParser;

namespace AimbotDetector.AimAnalyzer
{
    public class AnalysisResult
    {
        public string PlayerName { get; set; } = string.Empty;
        public int PlayerID { get; set; }
        public float CheatingProbability { get; set; }
        public bool IsCheating { get; set; }
        public List<DetectionResult> DetectionResults { get; set; } = new List<DetectionResult>();
        public DateTime AnalyzedTimestamp { get; set; }

        // Added properties to match the Visualization version
        public PlayerStatistics? PlayerStatistics { get; set; }
        public List<AimData>? PlayerAimData { get; set; }

        // Default constructor
        public AnalysisResult() { }
    }
}
