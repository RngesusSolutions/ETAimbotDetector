using System;
using System.Collections.Generic;
using System.Numerics;
using AimbotDetector.DemoParser;

namespace AimbotDetector.AimAnalyzer
{
    public class PingPredictionDetectionRule : DetectionRule
    {
        private const float PREDICTION_THRESHOLD = 0.75f;
        private const int MIN_SAMPLES = 10;
        
        public override DetectionResult Analyze(PlayerData player)
        {
            DetectionResult result = new DetectionResult
            {
                RuleName = "Ping Prediction Detection",
                Description = "Detects aimbot ping compensation typical of aimbots like CCHookReloaded"
            };
            
            List<AimData> aimData = player.AimData;
            if (aimData == null || aimData.Count < MIN_SAMPLES)
                return result;
            
            float totalConfidence = 0;
            int suspiciousEvents = 0;
            
            // Analyze sequences of aim data where player is firing at enemies
            var firingSequences = ExtractFiringSequences(aimData);
            
            foreach (var sequence in firingSequences)
            {
                if (sequence.Count < 5) continue;
                
                // Check for ping prediction patterns
                float predictionScore = AnalyzePingPrediction(sequence);
                
                if (predictionScore > PREDICTION_THRESHOLD)
                {
                    result.Evidence.Add(new DetectionEvidence
                    {
                        Timestamp = sequence[0].Timestamp,
                        Description = $"Ping prediction detected: {predictionScore:F2} correlation with ping-compensated positions",
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
        
        private List<List<AimData>> ExtractFiringSequences(List<AimData> aimData)
        {
            var sequences = new List<List<AimData>>();
            var currentSequence = new List<AimData>();
            
            for (int i = 0; i < aimData.Count; i++)
            {
                if (aimData[i].IsFiring && aimData[i].HasVisibleEnemy)
                {
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
        
        private float AnalyzePingPrediction(List<AimData> sequence)
        {
            // Estimate ping based on server timestamps and client reactions
            float estimatedPing = EstimatePing(sequence);
            if (estimatedPing <= 0) return 0;
            
            float totalCorrelation = 0;
            int validSamples = 0;
            
            for (int i = 1; i < sequence.Count; i++)
            {
                var current = sequence[i-1];
                var next = sequence[i];
                
                // Calculate time delta
                float timeDelta = (next.Timestamp - current.Timestamp) / 1000.0f;
                if (timeDelta <= 0) continue;
                
                // Calculate enemy velocity
                Vector3 enemyVelocity = Vector3.Zero;
                if (i > 1)
                {
                    var prev = sequence[i-2];
                    float prevTimeDelta = (current.Timestamp - prev.Timestamp) / 1000.0f;
                    if (prevTimeDelta > 0)
                    {
                        enemyVelocity = (current.NearestEnemyPosition - prev.NearestEnemyPosition) / prevTimeDelta;
                    }
                }
                
                // Calculate ping compensation factor (similar to CCHookReloaded)
                float pingFactor = -(estimatedPing / 2) / 1000.0f;
                
                // Predict enemy position with ping compensation
                Vector3 predictedPosition = current.NearestEnemyPosition + enemyVelocity * pingFactor;
                
                // Calculate aim angles to predicted position
                Vector3 aimDir = predictedPosition - current.Position;
                Vector3 predictedAngles = CalculateViewAngles(aimDir);
                
                // Compare with actual aim angles
                float angleDiff = CalculateAngleDifference(current.ViewAngles, predictedAngles);
                
                // Calculate correlation (inverse of angle difference)
                float correlation = MathF.Max(0, 1.0f - (angleDiff / 5.0f));
                
                totalCorrelation += correlation;
                validSamples++;
            }
            
            return validSamples > 0 ? totalCorrelation / validSamples : 0;
        }
        
        private float EstimatePing(List<AimData> sequence)
        {
            // Simple ping estimation based on reaction times
            // In a real implementation, this would use actual ping data from the demo
            // For now, we'll use a heuristic based on player reactions
            
            float totalReactionTime = 0;
            int reactionSamples = 0;
            
            for (int i = 2; i < sequence.Count; i++)
            {
                if (sequence[i].AngleToTarget < 5.0f && 
                    sequence[i-2].AngleToTarget > 10.0f)
                {
                    // Found a reaction (player turned to target)
                    int reactionTime = sequence[i].Timestamp - sequence[i-2].Timestamp;
                    totalReactionTime += reactionTime;
                    reactionSamples++;
                }
            }
            
            // If we can't estimate ping, use a default value
            return reactionSamples > 0 ? totalReactionTime / reactionSamples : 50.0f;
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
        
        private float CalculateAngleDifference(Vector3 angle1, Vector3 angle2)
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
