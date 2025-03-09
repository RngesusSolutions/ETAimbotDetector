using System;
using System.Collections.Generic;
using System.Numerics;
using AimbotDetector.DemoParser;

namespace AimbotDetector.AimAnalyzer
{
    public class VelocityPredictionDetectionRule : DetectionRule
    {
        private const float PREDICTION_THRESHOLD = 0.8f;
        private const int MIN_SAMPLES = 10;
        
        public override DetectionResult Analyze(PlayerData player)
        {
            DetectionResult result = new DetectionResult
            {
                RuleName = "Velocity Prediction Detection",
                Description = "Detects aimbot velocity prediction typical of aimbots like CCHookReloaded"
            };
            
            List<AimData> aimData = player.AimData;
            if (aimData == null || aimData.Count < MIN_SAMPLES)
                return result;
            
            float totalConfidence = 0;
            int suspiciousEvents = 0;
            
            // Analyze sequences of aim data where player is tracking moving enemies
            var trackingSequences = ExtractTrackingSequences(aimData);
            
            foreach (var sequence in trackingSequences)
            {
                if (sequence.Count < 5) continue;
                
                // Check for velocity prediction patterns
                float predictionScore = AnalyzePredictionPattern(sequence);
                
                if (predictionScore > PREDICTION_THRESHOLD)
                {
                    result.Evidence.Add(new DetectionEvidence
                    {
                        Timestamp = sequence[0].Timestamp,
                        Description = $"Velocity prediction detected: {predictionScore:F2} correlation with predicted positions",
                        Severity = predictionScore,
                        ViewAngles = sequence[0].ViewAngles
                    });
                    
                    totalConfidence += predictionScore;
                    suspiciousEvents++;
                }
            }
            
            if (suspiciousEvents > 0)
            {
                result.ConfidenceLevel = totalConfidence / suspiciousEvents;
            }
            
            return result;
        }
        
        private List<List<AimData>> ExtractTrackingSequences(List<AimData> aimData)
        {
            var sequences = new List<List<AimData>>();
            var currentSequence = new List<AimData>();
            
            for (int i = 1; i < aimData.Count; i++)
            {
                // Check if player is tracking a moving enemy
                if (aimData[i].HasVisibleEnemy && 
                   aimData[i-1].HasVisibleEnemy &&
                   Vector3.Distance(aimData[i].NearestEnemyPosition, aimData[i-1].NearestEnemyPosition) > 1.0f)
                {
                    if (currentSequence.Count == 0)
                    {
                        currentSequence.Add(aimData[i-1]);
                    }
                    currentSequence.Add(aimData[i]);
                }
                else if (currentSequence.Count > 0)
                {
                    sequences.Add(new List<AimData>(currentSequence));
                    currentSequence.Clear();
                }
            }
            
            // Add the last sequence if it's not empty
            if (currentSequence.Count > 0)
            {
                sequences.Add(currentSequence);
            }
            
            return sequences;
        }
        
        private float AnalyzePredictionPattern(List<AimData> sequence)
        {
            float totalCorrelation = 0;
            int validSamples = 0;
            
            for (int i = 2; i < sequence.Count; i++)
            {
                var prev = sequence[i-2];
                var current = sequence[i-1];
                var next = sequence[i];
                
                // Calculate time deltas
                float timeDelta1 = (current.Timestamp - prev.Timestamp) / 1000.0f;
                float timeDelta2 = (next.Timestamp - current.Timestamp) / 1000.0f;
                
                if (timeDelta1 <= 0 || timeDelta2 <= 0) continue;
                
                // Calculate enemy velocity based on previous positions
                Vector3 enemyVelocity = (current.NearestEnemyPosition - prev.NearestEnemyPosition) / timeDelta1;
                
                // Predict where enemy should be (similar to CCHookReloaded)
                // PredictionFactor = -cg_frametime / 1000.0f
                float predictionFactor = -timeDelta2;
                Vector3 predictedPosition = current.NearestEnemyPosition + enemyVelocity * predictionFactor;
                
                // Calculate aim angles to predicted position
                Vector3 aimDir = predictedPosition - current.Position;
                Vector3 predictedAngles = CalculateViewAngles(aimDir);
                
                // Compare with actual aim angles
                float angleDiff = CalculateAngleDifference(next.ViewAngles, predictedAngles);
                
                // Calculate correlation (inverse of angle difference)
                float correlation = MathF.Max(0, 1.0f - (angleDiff / 10.0f));
                
                totalCorrelation += correlation;
                validSamples++;
            }
            
            return validSamples > 0 ? totalCorrelation / validSamples : 0;
        }
        
        private Vector3 CalculateViewAngles(Vector3 direction)
        {
            // Calculate pitch and yaw angles from a direction vector
            float pitch, yaw;
            
            if (direction == Vector3.Zero)
            {
                return Vector3.Zero;
            }
            
            float horizontalDistance = MathF.Sqrt(direction.X * direction.X + direction.Z * direction.Z);
            
            pitch = MathF.Atan2(-direction.Y, horizontalDistance) * 180.0f / MathF.PI;
            yaw = MathF.Atan2(direction.X, direction.Z) * 180.0f / MathF.PI;
            
            return new Vector3(pitch, yaw, 0);
        }
        
        private new float CalculateAngleDifference(Vector3 angle1, Vector3 angle2)
        {
            // Calculate the difference between two view angles, accounting for angle wrapping
            float pitchDiff = MathF.Abs(NormalizeAngle(angle1.X - angle2.X));
            float yawDiff = MathF.Abs(NormalizeAngle(angle1.Y - angle2.Y));
            
            return MathF.Sqrt(pitchDiff * pitchDiff + yawDiff * yawDiff);
        }
        
        private float NormalizeAngle(float angle)
        {
            // Normalize angle to -180 to 180 range
            while (angle > 180)
                angle -= 360;
            while (angle < -180)
                angle += 360;
            return angle;
        }
    }
}
