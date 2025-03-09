using AimbotDetector.AimAnalyzer;
using System;
using System.Collections.Generic;

namespace AimbotDetector.Visualization
{
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