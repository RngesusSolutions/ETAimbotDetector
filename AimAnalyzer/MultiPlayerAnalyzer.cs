using System;
using System.Collections.Generic;
using System.Linq;
using AimbotDetector.DemoParser;

namespace AimbotDetector.AimAnalyzer
{
    public class MultiPlayerAnalyzer
    {
        private readonly string _calibrationProfile;
        private readonly AimAnalyzer _analyzer;
        
        public MultiPlayerAnalyzer(string? calibrationProfile = null)
        {
            _calibrationProfile = calibrationProfile;
            _analyzer = new AimAnalyzer();
        }
        
        public Dictionary<string, AnalysisResult> AnalyzeAllPlayers(List<PlayerData> players, float threshold = -1)
        {
            var results = new Dictionary<string, AnalysisResult>();
            
            if (players == null || players.Count == 0)
                return results;
            
            // Use default threshold if not specified
            if (threshold < 0)
                threshold = 0.7f;
            
            foreach (var player in players)
            {
                if (player == null || player.AimData == null || player.AimData.Count < 10)
                    continue;
                
                var detectionResults = _analyzer.Analyze(player);
                float overallProbability = _analyzer.GetOverallCheatingProbability(detectionResults);
                bool isCheating = overallProbability >= threshold;
                
                var result = new AnalysisResult
                {
                    PlayerName = player.Name ?? string.Empty,
                    PlayerID = player.PlayerID,
                    CheatingProbability = overallProbability,
                    IsCheating = isCheating,
                    DetectionResults = detectionResults,
                    AnalyzedTimestamp = DateTime.Now,
                    PlayerAimData = player.AimData
                };
                
                if (player.Name != null)
                    results[player.Name] = result;
            }
            
            return results;
        }
        
        public void CalibrateFromCleanData(List<PlayerData> players)
        {
            // Implement calibration logic here
            Console.WriteLine("Calibrating from clean data with multiple players...");
            
            // This would typically analyze patterns across multiple players
            // to establish baseline thresholds for detection
        }
    }
}
