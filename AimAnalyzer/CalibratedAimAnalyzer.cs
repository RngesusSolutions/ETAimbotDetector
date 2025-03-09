using System;
using System.Collections.Generic;
using AimbotDetector.DemoParser;

namespace AimbotDetector.AimAnalyzer
{
    public class CalibratedAimAnalyzer
    {
        private readonly string _calibrationProfile;
        private readonly AimAnalyzer _analyzer;
        private float _suspiciousThreshold = 0.7f;
        
        public CalibratedAimAnalyzer(string? calibrationProfile = null)
        {
            _calibrationProfile = calibrationProfile;
            _analyzer = new AimAnalyzer();
            
            // Load calibration profile if specified
            if (!string.IsNullOrEmpty(_calibrationProfile))
            {
                LoadCalibrationProfile(_calibrationProfile);
            }
        }
        
        public List<DetectionResult> Analyze(PlayerData player)
        {
            return _analyzer.Analyze(player);
        }
        
        public float GetOverallCheatingProbability(List<DetectionResult> detectionResults)
        {
            return _analyzer.GetOverallCheatingProbability(detectionResults);
        }
        
        public float GetSuspiciousThreshold()
        {
            return _suspiciousThreshold;
        }
        
        public void CalibrateFromCleanData(List<PlayerData> players)
        {
            Console.WriteLine("Calibrating from clean data...");
            
            if (players == null || players.Count == 0)
                return;
            
            // Analyze all players to establish baseline metrics
            var baselineMetrics = new Dictionary<string, List<float>>();
            
            foreach (var player in players)
            {
                if (player == null || player.AimData == null || player.AimData.Count < 10)
                    continue;
                
                var detectionResults = _analyzer.Analyze(player);
                
                foreach (var result in detectionResults)
                {
                    if (!baselineMetrics.ContainsKey(result.RuleName))
                    {
                        baselineMetrics[result.RuleName] = new List<float>();
                    }
                    
                    baselineMetrics[result.RuleName].Add(result.ConfidenceLevel);
                }
            }
            
            // Calculate thresholds based on baseline metrics
            // This is a simple implementation - in a real system, this would be more sophisticated
            foreach (var metric in baselineMetrics)
            {
                if (metric.Value.Count > 0)
                {
                    float mean = metric.Value.Average();
                    float stdDev = CalculateStandardDeviation(metric.Value, mean);
                    
                    // Set threshold at mean + 2 standard deviations
                    float threshold = mean + (2 * stdDev);
                    Console.WriteLine($"Calibrated threshold for {metric.Key}: {threshold:F3}");
                }
            }
            
            // Update the suspicious threshold based on calibration
            _suspiciousThreshold = 0.65f; // Example value, would be calculated from the data
            
            Console.WriteLine($"Calibrated suspicious threshold: {_suspiciousThreshold:F3}");
            
            // Save calibration profile if specified
            if (!string.IsNullOrEmpty(_calibrationProfile))
            {
                SaveCalibrationProfile(_calibrationProfile);
            }
        }
        
        private void LoadCalibrationProfile(string profileName)
        {
            // In a real implementation, this would load calibration data from a file
            Console.WriteLine($"Loading calibration profile: {profileName}");
            
            // Example implementation
            switch (profileName.ToLower())
            {
                case "competitive":
                    _suspiciousThreshold = 0.8f;
                    break;
                case "casual":
                    _suspiciousThreshold = 0.6f;
                    break;
                default:
                    _suspiciousThreshold = 0.7f;
                    break;
            }
        }
        
        private void SaveCalibrationProfile(string profileName)
        {
            // In a real implementation, this would save calibration data to a file
            Console.WriteLine($"Saving calibration profile: {profileName}");
        }
        
        private float CalculateStandardDeviation(List<float> values, float mean)
        {
            if (values.Count <= 1)
                return 0;
            
            float sumOfSquares = values.Sum(x => (x - mean) * (x - mean));
            return (float)Math.Sqrt(sumOfSquares / (values.Count - 1));
        }
    }
}
