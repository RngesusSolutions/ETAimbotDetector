using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;
using AimbotDetector.DemoParser;

namespace AimbotDetector.AimAnalyzer
{
    public class AimAnalyzer
    {
        private readonly List<DetectionRule> _rules;

        public AimAnalyzer()
        {
            _rules = new List<DetectionRule>
            {
                new SnapAimDetection(),
                new PrecisionAimDetection(),
                new ReactionTimeDetection(),
                new AimConsistencyDetection(),
                new TargetPriorityDetection(), // Now using the full implementation
                new SmoothnessAnalysisRule(),
                new AimJitterDetection(),
                new AimLockDetection(),
                new VelocityPredictionDetectionRule(), // Add new rule for velocity prediction
                new PingPredictionDetectionRule()      // Add new rule for ping prediction
            };
        }

        public List<DetectionResult> Analyze(PlayerData player)
        {
            var results = new List<DetectionResult>();

            // Skip analysis if not enough data
            if (player.AimData.Count < 10)
            {
                return results;
            }

            // Preprocess data for analysis
            var preprocessedData = PreprocessData(player);

            // Run all detection rules
            foreach (var rule in _rules)
            {
                DetectionResult result = rule.Analyze(preprocessedData);
                results.Add(result);
            }

            return results;
        }

        public float GetOverallCheatingProbability(List<DetectionResult> results)
        {
            if (results.Count == 0)
                return 0;

            // Weight different rules differently
            float weightedSum = 0;
            float totalWeight = 0;

            foreach (var result in results)
            {
                float weight = GetRuleWeight(result.RuleName);
                weightedSum += result.ConfidenceLevel * weight;
                totalWeight += weight;
            }

            return weightedSum / totalWeight;
        }

        private float GetRuleWeight(string ruleName)
        {
            // Assign weights to different detection rules based on reliability
            return ruleName switch
            {
                "Snap Aim Detection" => 1.0f,
                "Precision Aim Detection" => 0.8f,
                "Reaction Time Detection" => 0.9f,
                "Aim Consistency Detection" => 0.7f,
                "Target Priority Detection" => 0.6f,
                "Smoothness Analysis" => 1.0f,
                "Aim Jitter Detection" => 0.8f,
                "Aim Lock Detection" => 1.0f,
                "Velocity Prediction Detection" => 0.9f, // Add weight for new rule
                "Ping Prediction Detection" => 0.8f,     // Add weight for new rule
                _ => 0.5f
            };
        }

        private PlayerData PreprocessData(PlayerData player)
        {
            // Create a copy of the player data for preprocessing
            var preprocessed = new PlayerData
            {
                PlayerID = player.PlayerID,
                Name = player.Name,
                AimData = new List<AimData>(player.AimData)
            };

            // Calculate additional metrics for each aim data point
            for (int i = 1; i < preprocessed.AimData.Count; i++)
            {
                var current = preprocessed.AimData[i];
                var previous = preprocessed.AimData[i - 1];

                // Calculate time delta
                int timeDelta = current.Timestamp - previous.Timestamp;

                // Skip if timestamps are identical or out of order
                if (timeDelta <= 0) continue;

                // Calculate angle deltas
                float pitchDelta = MathF.Abs(current.ViewAngles.X - previous.ViewAngles.X);
                float yawDelta = MathF.Abs(current.ViewAngles.Y - previous.ViewAngles.Y);

                // Normalize angles
                if (pitchDelta > 180) pitchDelta = 360 - pitchDelta;
                if (yawDelta > 180) yawDelta = 360 - yawDelta;

                // Calculate angular velocity (degrees per millisecond)
                float pitchVelocity = pitchDelta / timeDelta;
                float yawVelocity = yawDelta / timeDelta;

                // Store calculated metrics in aim data
                // In a real implementation, we'd extend AimData to include these fields
                // For now, we'll use the Position field to store these metrics
                // X = pitchVelocity, Y = yawVelocity, Z = unused
                current.Position = new Vector3(pitchVelocity, yawVelocity, 0);
            }

            return preprocessed;
        }
    }

    // Base class for detection rules
    public abstract class DetectionRule
    {
        public abstract DetectionResult Analyze(PlayerData player);

        protected float CalculateAngleDifference(Vector3 angle1, Vector3 angle2)
        {
            // Calculate the difference between two view angles
            float pitchDiff = MathF.Abs(angle1.X - angle2.X);
            float yawDiff = MathF.Abs(angle1.Y - angle2.Y);

            // Normalize differences
            if (pitchDiff > 180) pitchDiff = 360 - pitchDiff;
            if (yawDiff > 180) yawDiff = 360 - yawDiff;

            // Return Euclidean distance
            return MathF.Sqrt(pitchDiff * pitchDiff + yawDiff * yawDiff);
        }
    }

    public class DetectionResult
    {
        public string RuleName { get; set; } = string.Empty;
        public float ConfidenceLevel { get; set; } // 0.0 to 1.0
        public string Description { get; set; } = string.Empty;
        public List<DetectionEvidence> Evidence { get; set; } = new List<DetectionEvidence>();
    }

    public class DetectionEvidence
    {
        public int Timestamp { get; set; }
        public string Description { get; set; } = string.Empty;
        public float Severity { get; set; } // 0.0 to 1.0
        public Vector3 ViewAngles { get; set; }
    }

    // Rule 1: Detect sudden, unnatural aim snaps
    public class SnapAimDetection : DetectionRule
    {
        private const float ANGLE_SPEED_THRESHOLD = 0.5f; // degrees per millisecond

        public override DetectionResult Analyze(PlayerData player)
        {
            DetectionResult result = new DetectionResult
            {
                RuleName = "Snap Aim Detection",
                Description = "Detects sudden, unnatural aim movements typical of aimbots"
            };

            List<AimData> aimData = player.AimData;
            if (aimData.Count < 2)
                return result;

            float totalConfidence = 0;
            int suspiciousEvents = 0;

            for (int i = 1; i < aimData.Count; i++)
            {
                int timeDiff = aimData[i].Timestamp - aimData[i - 1].Timestamp;
                if (timeDiff <= 0) continue;

                float angleDiff = CalculateAngleDifference(aimData[i - 1].ViewAngles, aimData[i].ViewAngles);
                float angleSpeed = angleDiff / timeDiff;

                // Check for extremely fast aim adjustments
                if (angleSpeed > ANGLE_SPEED_THRESHOLD)
                {
                    float severity = Math.Min(angleSpeed / 2.0f, 1.0f);

                    result.Evidence.Add(new DetectionEvidence
                    {
                        Timestamp = aimData[i].Timestamp,
                        Description = $"Suspicious aim snap: {angleDiff:F2}° in {timeDiff}ms ({angleSpeed:F2}°/ms)",
                        Severity = severity,
                        ViewAngles = aimData[i].ViewAngles
                    });

                    totalConfidence += severity;
                    suspiciousEvents++;
                }
            }

            if (suspiciousEvents > 0)
            {
                result.ConfidenceLevel = totalConfidence / suspiciousEvents;
            }

            return result;
        }
    }

    // Rule 2: Detect unnaturally precise aim
    public class PrecisionAimDetection : DetectionRule
    {
        private const float PRECISION_THRESHOLD = 0.05f; // degrees

        public override DetectionResult Analyze(PlayerData player)
        {
            DetectionResult result = new DetectionResult
            {
                RuleName = "Precision Aim Detection",
                Description = "Detects unnaturally precise aim typical of aimbots"
            };

            List<AimData> aimData = player.AimData;
            if (aimData.Count < 10)
                return result;

            // Only analyze when firing
            var firingSequences = ExtractFiringSequences(aimData);
            if (firingSequences.Count == 0)
                return result;

            float totalConfidence = 0;
            int suspiciousEvents = 0;

            foreach (var sequence in firingSequences)
            {
                if (sequence.Count < 3) continue;

                // Analyze micro-adjustments during firing
                float averageMicroAdjustment = CalculateAverageMicroAdjustment(sequence);

                if (averageMicroAdjustment < PRECISION_THRESHOLD)
                {
                    float severity = 1.0f - (averageMicroAdjustment / PRECISION_THRESHOLD);

                    result.Evidence.Add(new DetectionEvidence
                    {
                        Timestamp = sequence[0].Timestamp,
                        Description = $"Suspiciously precise aim: {averageMicroAdjustment:F4}° average adjustment (human usually >0.1°)",
                        Severity = severity,
                        ViewAngles = sequence[0].ViewAngles
                    });

                    totalConfidence += severity;
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
            List<AimData>? currentSequence = null;

            foreach (var data in aimData)
            {
                if (data.IsFiring)
                {
                    currentSequence ??= new List<AimData>();
                    currentSequence.Add(data);
                }
                else if (currentSequence != null)
                {
                    sequences.Add(currentSequence);
                    currentSequence = null;
                }
            }

            // Add the last sequence if still firing at the end
            if (currentSequence != null && currentSequence.Count > 0)
            {
                sequences.Add(currentSequence);
            }

            return sequences;
        }

        private float CalculateAverageMicroAdjustment(List<AimData> sequence)
        {
            float totalAdjustment = 0;

            for (int i = 1; i < sequence.Count; i++)
            {
                totalAdjustment += CalculateAngleDifference(sequence[i - 1].ViewAngles, sequence[i].ViewAngles);
            }

            return totalAdjustment / (sequence.Count - 1);
        }
    }

    // Rule 3: Detect inhuman reaction times
    public class ReactionTimeDetection : DetectionRule
    {
        private const int MIN_HUMAN_REACTION_TIME = 150; // milliseconds

        public override DetectionResult Analyze(PlayerData player)
        {
            DetectionResult result = new DetectionResult
            {
                RuleName = "Reaction Time Detection",
                Description = "Detects reaction times faster than human capabilities"
            };

            List<AimData> aimData = player.AimData;
            if (aimData.Count < 10)
                return result;

            float totalConfidence = 0;
            int suspiciousEvents = 0;

            // Simplified implementation - in real use, we'd need to detect when enemies appear
            // and measure reaction time to them
            for (int i = 2; i < aimData.Count; i++)
            {
                // Check for significant aim adjustments (potential reactions)
                float angleDiff1 = CalculateAngleDifference(aimData[i - 2].ViewAngles, aimData[i - 1].ViewAngles);
                float angleDiff2 = CalculateAngleDifference(aimData[i - 1].ViewAngles, aimData[i].ViewAngles);

                // If there's a sudden large adjustment followed by firing
                if (angleDiff1 > 10 && angleDiff2 < 2 && aimData[i].IsFiring)
                {
                    int reactionTime = aimData[i].Timestamp - aimData[i - 2].Timestamp;

                    if (reactionTime < MIN_HUMAN_REACTION_TIME)
                    {
                        float severity = 1.0f - (reactionTime / (float)MIN_HUMAN_REACTION_TIME);

                        result.Evidence.Add(new DetectionEvidence
                        {
                            Timestamp = aimData[i].Timestamp,
                            Description = $"Suspiciously fast reaction: {reactionTime}ms (human minimum ~150ms)",
                            Severity = severity,
                            ViewAngles = aimData[i].ViewAngles
                        });

                        totalConfidence += severity;
                        suspiciousEvents++;
                    }
                }
            }

            if (suspiciousEvents > 0)
            {
                result.ConfidenceLevel = totalConfidence / suspiciousEvents;
            }

            return result;
        }
    }

    // Rule 4: Detect unnaturally consistent aim
    public class AimConsistencyDetection : DetectionRule
    {
        public override DetectionResult Analyze(PlayerData player)
        {
            DetectionResult result = new DetectionResult
            {
                RuleName = "Aim Consistency Detection",
                Description = "Detects unnaturally consistent aim typical of aimbots"
            };

            List<AimData> aimData = player.AimData;
            if (aimData.Count < 30)
                return result;

            // Calculate standard deviation of angular velocity
            var angularVelocities = new List<float>();

            for (int i = 1; i < aimData.Count; i++)
            {
                int timeDiff = aimData[i].Timestamp - aimData[i - 1].Timestamp;
                if (timeDiff <= 0) continue;

                float angleDiff = CalculateAngleDifference(aimData[i - 1].ViewAngles, aimData[i].ViewAngles);
                float angleSpeed = angleDiff / timeDiff;

                angularVelocities.Add(angleSpeed);
            }

            if (angularVelocities.Count < 10)
                return result;

            // Calculate mean
            float mean = angularVelocities.Average();

            // Calculate standard deviation
            float variance = angularVelocities.Sum(v => (v - mean) * (v - mean)) / angularVelocities.Count;
            float stdDev = MathF.Sqrt(variance);

            // Coefficient of variation (normalized standard deviation)
            float cv = mean > 0 ? stdDev / mean : 0;

            // Humans typically have higher variability in aim movements
            if (cv < 0.6f)
            {
                float severity = 1.0f - (cv / 0.6f);

                result.Evidence.Add(new DetectionEvidence
                {
                    Timestamp = aimData[aimData.Count / 2].Timestamp,
                    Description = $"Suspiciously consistent aim: CV={cv:F2} (human typically >0.6)",
                    Severity = severity,
                    ViewAngles = aimData[aimData.Count / 2].ViewAngles
                });

                result.ConfidenceLevel = severity;
            }

            return result;
        }
    }

    // Rule 6: Analyze aim smoothness for artificial patterns
    public class SmoothnessAnalysisRule : DetectionRule
    {
        public override DetectionResult Analyze(PlayerData player)
        {
            DetectionResult result = new DetectionResult
            {
                RuleName = "Smoothness Analysis",
                Description = "Detects artificial smoothing typical of aimbots"
            };

            List<AimData> aimData = player.AimData;
            if (aimData.Count < 30)
                return result;

            // Extract sequences of continuous movement
            var sequences = ExtractMovementSequences(aimData);

            float totalConfidence = 0;
            int suspiciousEvents = 0;

            foreach (var sequence in sequences)
            {
                if (sequence.Count < 10) continue;

                // Look for mathematical patterns in aim smoothing
                // Many aimbots use simple mathematical functions to smooth aim
                float smoothnessScore = AnalyzeSmoothnessPattern(sequence);

                if (smoothnessScore > 0.7f)
                {
                    result.Evidence.Add(new DetectionEvidence
                    {
                        Timestamp = sequence[0].Timestamp,
                        Description = $"Artificial smoothing pattern detected: {smoothnessScore:F2} similarity to mathematical curve",
                        Severity = smoothnessScore,
                        ViewAngles = sequence[0].ViewAngles
                    });

                    totalConfidence += smoothnessScore;
                    suspiciousEvents++;
                }
            }

            if (suspiciousEvents > 0)
            {
                result.ConfidenceLevel = totalConfidence / suspiciousEvents;
            }

            return result;
        }

        private List<List<AimData>> ExtractMovementSequences(List<AimData> aimData)
        {
            var sequences = new List<List<AimData>>();
            var currentSequence = new List<AimData>();

            for (int i = 1; i < aimData.Count; i++)
            {
                int timeDiff = aimData[i].Timestamp - aimData[i - 1].Timestamp;
                if (timeDiff <= 0) continue;

                float angleDiff = CalculateAngleDifference(aimData[i - 1].ViewAngles, aimData[i].ViewAngles);

                // If there's significant movement, add to current sequence
                if (angleDiff > 0.1f)
                {
                    if (currentSequence.Count == 0)
                    {
                        currentSequence.Add(aimData[i - 1]);
                    }
                    currentSequence.Add(aimData[i]);
                }
                else if (currentSequence.Count > 0)
                {
                    // End of a movement sequence
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

        private float AnalyzeSmoothnessPattern(List<AimData> sequence)
        {
            // Extract angular velocities
            var velocities = new List<float>();

            for (int i = 1; i < sequence.Count; i++)
            {
                int timeDiff = sequence[i].Timestamp - sequence[i - 1].Timestamp;
                if (timeDiff <= 0) continue;

                float angleDiff = CalculateAngleDifference(sequence[i - 1].ViewAngles, sequence[i].ViewAngles);
                velocities.Add(angleDiff / timeDiff);
            }

            if (velocities.Count < 5) return 0;

            // Check for common aimbot smoothing patterns

            // 1. Linear smoothing
            float linearScore = CheckLinearPattern(velocities);

            // 2. Exponential smoothing
            float exponentialScore = CheckExponentialPattern(velocities);

            // 3. Sinusoidal smoothing
            float sinusoidalScore = CheckSinusoidalPattern(velocities);

            // Return the highest score
            return Math.Max(Math.Max(linearScore, exponentialScore), sinusoidalScore);
        }

        private float CheckLinearPattern(List<float> velocities)
        {
            // Calculate linear regression
            float sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
            int n = velocities.Count;

            for (int i = 0; i < n; i++)
            {
                sumX += i;
                sumY += velocities[i];
                sumXY += i * velocities[i];
                sumX2 += i * i;
            }

            float slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
            float intercept = (sumY - slope * sumX) / n;

            // Calculate R-squared
            float predictedSum = 0;
            float residualSum = 0;
            float mean = sumY / n;

            for (int i = 0; i < n; i++)
            {
                float predicted = intercept + slope * i;
                predictedSum += (predicted - mean) * (predicted - mean);
                residualSum += (velocities[i] - predicted) * (velocities[i] - predicted);
            }

            float totalSum = predictedSum + residualSum;
            return totalSum > 0 ? predictedSum / totalSum : 0;
        }

        private float CheckExponentialPattern(List<float> velocities)
        {
            // Simplified check for exponential pattern
            // In a real implementation, this would fit an exponential curve

            // For now, check if velocities decrease approximately exponentially
            bool isDecreasing = true;
            float ratioSum = 0;
            int ratioCount = 0;

            for (int i = 1; i < velocities.Count; i++)
            {
                if (velocities[i] > velocities[i - 1])
                {
                    isDecreasing = false;
                    break;
                }

                if (velocities[i - 1] > 0)
                {
                    ratioSum += velocities[i] / velocities[i - 1];
                    ratioCount++;
                }
            }

            if (!isDecreasing || ratioCount < 3)
                return 0;

            float avgRatio = ratioSum / ratioCount;

            // Check if ratio is fairly consistent (exponential decay)
            float ratioVariance = 0;
            for (int i = 1; i < velocities.Count; i++)
            {
                if (velocities[i - 1] > 0)
                {
                    float ratio = velocities[i] / velocities[i - 1];
                    ratioVariance += (ratio - avgRatio) * (ratio - avgRatio);
                }
            }

            float ratioStdDev = MathF.Sqrt(ratioVariance / ratioCount);
            float consistencyScore = 1.0f - MathF.Min(ratioStdDev / avgRatio, 1.0f);

            return consistencyScore;
        }

        private float CheckSinusoidalPattern(List<float> velocities)
        {
            // Simplified check for sinusoidal pattern
            // In a real implementation, this would fit a sinusoidal curve

            // For now, check for alternating increases and decreases
            int alternations = 0;
            bool wasIncreasing = velocities[1] > velocities[0];

            for (int i = 2; i < velocities.Count; i++)
            {
                bool isIncreasing = velocities[i] > velocities[i - 1];
                if (isIncreasing != wasIncreasing)
                {
                    alternations++;
                    wasIncreasing = isIncreasing;
                }
            }

            float alternationRatio = (float)alternations / (velocities.Count - 2);

            // Ideal sinusoidal would alternate at regular intervals
            return alternationRatio > 0.3f && alternationRatio < 0.7f ? 0.8f : 0;
        }
    }

    // Rule 7: Detect lack of natural aim jitter
    public class AimJitterDetection : DetectionRule
    {
        private const float MIN_HUMAN_JITTER = 0.02f; // degrees

        public override DetectionResult Analyze(PlayerData player)
        {
            DetectionResult result = new DetectionResult
            {
                RuleName = "Aim Jitter Detection",
                Description = "Detects unnaturally smooth aim lacking human micro-movements"
            };

            List<AimData> aimData = player.AimData;
            if (aimData.Count < 30)
                return result;

            // Extract "holding still" sequences
            var holdingSequences = ExtractHoldingSequences(aimData);

            float totalConfidence = 0;
            int suspiciousEvents = 0;

            foreach (var sequence in holdingSequences)
            {
                if (sequence.Count < 10) continue;

                // Calculate micro-movement jitter
                float jitterAmount = CalculateJitter(sequence);

                if (jitterAmount < MIN_HUMAN_JITTER)
                {
                    float severity = 1.0f - (jitterAmount / MIN_HUMAN_JITTER);

                    result.Evidence.Add(new DetectionEvidence
                    {
                        Timestamp = sequence[0].Timestamp,
                        Description = $"Unnaturally stable aim: {jitterAmount:F4}° jitter (humans typically >0.02°)",
                        Severity = severity,
                        ViewAngles = sequence[0].ViewAngles
                    });

                    totalConfidence += severity;
                    suspiciousEvents++;
                }
            }

            if (suspiciousEvents > 0)
            {
                result.ConfidenceLevel = totalConfidence / suspiciousEvents;
            }

            return result;
        }

        private List<List<AimData>> ExtractHoldingSequences(List<AimData> aimData)
        {
            var sequences = new List<List<AimData>>();
            var currentSequence = new List<AimData>();

            for (int i = 1; i < aimData.Count; i++)
            {
                float angleDiff = CalculateAngleDifference(aimData[i - 1].ViewAngles, aimData[i].ViewAngles);

                // If player is "holding still" (small movements)
                if (angleDiff < 0.5f)
                {
                    if (currentSequence.Count == 0)
                    {
                        currentSequence.Add(aimData[i - 1]);
                    }
                    currentSequence.Add(aimData[i]);
                }
                else if (currentSequence.Count > 0)
                {
                    // End of a holding sequence
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

        private float CalculateJitter(List<AimData> sequence)
        {
            if (sequence.Count < 3)
                return float.MaxValue;

            float totalJitter = 0;

            for (int i = 2; i < sequence.Count; i++)
            {
                // Calculate second derivative of aim movement
                Vector3 diff1 = Vector3.Subtract(sequence[i - 1].ViewAngles, sequence[i - 2].ViewAngles);
                Vector3 diff2 = Vector3.Subtract(sequence[i].ViewAngles, sequence[i - 1].ViewAngles);

                Vector3 jitter = Vector3.Subtract(diff2, diff1);
                totalJitter += MathF.Sqrt(jitter.X * jitter.X + jitter.Y * jitter.Y);
            }

            return totalJitter / (sequence.Count - 2);
        }
    }

    // Rule 8: Detect aim lock behavior
    public class AimLockDetection : DetectionRule
    {
        private const int MIN_LOCK_DURATION = 500; // milliseconds
        private const float MAX_LOCK_VARIATION = 0.5f; // degrees

        public override DetectionResult Analyze(PlayerData player)
        {
            DetectionResult result = new DetectionResult
            {
                RuleName = "Aim Lock Detection",
                Description = "Detects aim lock behavior typical of aimbots"
            };

            List<AimData> aimData = player.AimData;
            if (aimData.Count < 10)
                return result;

            // Find sequences where aim is "locked" (minimal variation)
            var lockSequences = FindAimLockSequences(aimData);

            float totalConfidence = 0;
            int suspiciousEvents = 0;

            foreach (var sequence in lockSequences)
            {
                int duration = sequence[sequence.Count - 1].Timestamp - sequence[0].Timestamp;

                // Calculate lock strength
                float lockStrength = CalculateLockStrength(sequence);

                if (duration > MIN_LOCK_DURATION && lockStrength > 0.7f)
                {
                    result.Evidence.Add(new DetectionEvidence
                    {
                        Timestamp = sequence[0].Timestamp,
                        Description = $"Aim lock detected: {duration}ms duration, {lockStrength:F2} lock strength",
                        Severity = lockStrength,
                        ViewAngles = sequence[0].ViewAngles
                    });

                    totalConfidence += lockStrength;
                    suspiciousEvents++;
                }
            }

            if (suspiciousEvents > 0)
            {
                result.ConfidenceLevel = totalConfidence / suspiciousEvents;
            }

            return result;
        }

        private List<List<AimData>> FindAimLockSequences(List<AimData> aimData)
        {
            var sequences = new List<List<AimData>>();
            var currentSequence = new List<AimData>();
            Vector3 referenceAngle = new Vector3();

            for (int i = 0; i < aimData.Count; i++)
            {
                if (currentSequence.Count == 0)
                {
                    currentSequence.Add(aimData[i]);
                    referenceAngle = aimData[i].ViewAngles;
                    continue;
                }

                float angleDiff = CalculateAngleDifference(referenceAngle, aimData[i].ViewAngles);

                if (angleDiff < MAX_LOCK_VARIATION)
                {
                    currentSequence.Add(aimData[i]);
                }
                else
                {
                    // End of a lock sequence
                    if (currentSequence.Count >= 5)
                    {
                        sequences.Add(new List<AimData>(currentSequence));
                    }

                    currentSequence.Clear();
                    currentSequence.Add(aimData[i]);
                    referenceAngle = aimData[i].ViewAngles;
                }
            }

            // Add the last sequence if it's not empty
            if (currentSequence.Count >= 5)
            {
                sequences.Add(currentSequence);
            }

            return sequences;
        }

        private float CalculateLockStrength(List<AimData> sequence)
        {
            if (sequence.Count < 3)
                return 0;

            // Calculate the center point of the aim
            Vector3 sum = new Vector3();
            foreach (var data in sequence)
            {
                sum = Vector3.Add(sum, data.ViewAngles);
            }

            Vector3 center = Vector3.Divide(sum, sequence.Count);

            // Calculate average distance from center
            float totalDistance = 0;
            foreach (var data in sequence)
            {
                totalDistance += CalculateAngleDifference(center, data.ViewAngles);
            }

            float avgDistance = totalDistance / sequence.Count;

            // Calculate lock strength (inversely proportional to average distance)
            // Prevent division by zero
            if (MAX_LOCK_VARIATION <= 0.0001f)
                return 0;
                
            return MathF.Max(0, 1.0f - (avgDistance / MAX_LOCK_VARIATION));
        }
    }
}
