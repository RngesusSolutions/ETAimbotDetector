using System;
using System.Collections.Generic;
using AimbotDetector.DemoParser;
using AimbotDetector.AimAnalyzer;

namespace AimbotDetector
{
    public class AnalysisResult
    {
        public string PlayerName { get; set; } = string.Empty;
        public int PlayerID { get; set; }
        public float CheatingProbability { get; set; }
        public bool IsCheating { get; set; }
        public List<DetectionResult> DetectionResults { get; set; } = new List<DetectionResult>();
        public DateTime AnalyzedTimestamp { get; set; }

        // Added properties to match the AimbotDetector version
        public PlayerStatistics? PlayerStatistics { get; set; }
        public List<AimData>? PlayerAimData { get; set; }

        // Default constructor
        public AnalysisResult() { }
        
        // Constructor to convert from AimAnalyzer.AnalysisResult
        public AnalysisResult(AimAnalyzer.AnalysisResult result)
        {
            if (result == null)
                throw new ArgumentNullException(nameof(result));
                
            PlayerName = result.PlayerName;
            PlayerID = result.PlayerID;
            CheatingProbability = result.CheatingProbability;
            IsCheating = result.IsCheating;
            DetectionResults = result.DetectionResults;
            AnalyzedTimestamp = result.AnalyzedTimestamp;
            PlayerStatistics = result.PlayerStatistics;
            PlayerAimData = result.PlayerAimData;
        }
    }
}
