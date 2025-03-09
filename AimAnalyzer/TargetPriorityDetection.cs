using AimbotDetector.DemoParser;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;

namespace AimbotDetector.AimAnalyzer
{
    // Implementation of the target priority detection rule that was previously a placeholder
    public class TargetPriorityDetection : DetectionRule
    {
        private const float PERFECT_TRACKING_THRESHOLD = 0.5f; // degrees
        private const float PERFECT_SNAPPING_THRESHOLD = 2.0f; // degrees
        private const float SUSPICIOUS_PRIORITY_THRESHOLD = 0.8f;
        private const int MIN_PRIORITY_SEQUENCE = 5; // Minimum target switches to analyze

        public override DetectionResult Analyze(PlayerData player)
        {
            DetectionResult result = new DetectionResult
            {
                RuleName = "Target Priority Detection",
                Description = "Detects unnatural target selection patterns typical of aimbots"
            };

            List<AimData> aimData = player.AimData;
            if (aimData.Count < 20)
                return result;

            // Find sequences where the player tracks enemies
            var trackingSequences = FindEnemyTrackingSequences(aimData);

            // Find target switching patterns
            var targetSwitches = FindTargetSwitches(aimData);

            float totalConfidence = 0;
            int suspiciousEvents = 0;

            // Analyze perfect enemy tracking (suspiciously accurate following of moving targets)
            foreach (var sequence in trackingSequences)
            {
                if (sequence.Count < 10) continue;

                float averageErrorAngle = CalculateAverageTargetingError(sequence);

                if (averageErrorAngle < PERFECT_TRACKING_THRESHOLD)
                {
                    float severity = 1.0f - (averageErrorAngle / PERFECT_TRACKING_THRESHOLD);

                    result.Evidence.Add(new DetectionEvidence
                    {
                        Timestamp = sequence[0].Timestamp,
                        Description = $"Suspiciously perfect enemy tracking: {averageErrorAngle:F2}° average error (human typically >1°)",
                        Severity = severity,
                        ViewAngles = sequence[0].ViewAngles
                    });

                    totalConfidence += severity;
                    suspiciousEvents++;
                }
            }

            // Analyze target switching (suspicious instant snaps between targets)
            foreach (var switchEvent in targetSwitches)
            {
                // Calculate how close the view snapped to the new target
                float snapAccuracy = switchEvent.Item3;
                float snapSpeed = switchEvent.Item4;

                if (snapAccuracy < PERFECT_SNAPPING_THRESHOLD && snapSpeed > 0.2f)
                {
                    float severity = (1.0f - (snapAccuracy / PERFECT_SNAPPING_THRESHOLD)) * Math.Min(snapSpeed * 2, 1.0f);

                    result.Evidence.Add(new DetectionEvidence
                    {
                        Timestamp = switchEvent.Item1,
                        Description = $"Suspicious target switch: {snapAccuracy:F2}° accuracy at {snapSpeed:F2}°/ms",
                        Severity = severity,
                        ViewAngles = switchEvent.Item2
                    });

                    totalConfidence += severity;
                    suspiciousEvents++;
                }
            }

            // Analyze overall target prioritization
            if (targetSwitches.Count >= MIN_PRIORITY_SEQUENCE)
            {
                float priorityScore = AnalyzeTargetPrioritization(targetSwitches, aimData);

                if (priorityScore > SUSPICIOUS_PRIORITY_THRESHOLD)
                {
                    result.Evidence.Add(new DetectionEvidence
                    {
                        Timestamp = aimData[aimData.Count / 2].Timestamp,
                        Description = $"Suspicious target prioritization pattern: {priorityScore:F2} correlation with distance-based priority",
                        Severity = priorityScore,
                        ViewAngles = aimData[aimData.Count / 2].ViewAngles
                    });

                    totalConfidence += priorityScore;
                    suspiciousEvents++;
                }
            }

            if (suspiciousEvents > 0)
            {
                result.ConfidenceLevel = totalConfidence / suspiciousEvents;
            }

            return result;
        }

        private List<List<AimData>> FindEnemyTrackingSequences(List<AimData> aimData)
        {
            var sequences = new List<List<AimData>>();
            var currentSequence = new List<AimData>();

            for (int i = 0; i < aimData.Count; i++)
            {
                // Check if player has an enemy in view
                if (aimData[i].HasVisibleEnemy && aimData[i].AngleToTarget < 10.0f)
                {
                    // Add to current tracking sequence
                    if (currentSequence.Count == 0 || currentSequence[currentSequence.Count - 1].Timestamp + 100 >= aimData[i].Timestamp)
                    {
                        currentSequence.Add(aimData[i]);
                    }
                    else
                    {
                        // Too much time passed, start a new sequence
                        if (currentSequence.Count >= 5)
                        {
                            sequences.Add(new List<AimData>(currentSequence));
                        }
                        currentSequence.Clear();
                        currentSequence.Add(aimData[i]);
                    }
                }
                else if (currentSequence.Count > 0)
                {
                    // No enemy in view, end the current sequence
                    if (currentSequence.Count >= 5)
                    {
                        sequences.Add(new List<AimData>(currentSequence));
                    }
                    currentSequence.Clear();
                }
            }

            // Add the last sequence if not empty
            if (currentSequence.Count >= 5)
            {
                sequences.Add(currentSequence);
            }

            return sequences;
        }

        private List<Tuple<int, Vector3, float, float>> FindTargetSwitches(List<AimData> aimData)
        {
            var targetSwitches = new List<Tuple<int, Vector3, float, float>>();

            for (int i = 2; i < aimData.Count; i++)
            {
                if (!aimData[i].HasVisibleEnemy || !aimData[i - 2].HasVisibleEnemy) continue;

                // Check if the current enemy is different from two frames ago
                float positionDiff = Vector3.Distance(aimData[i].NearestEnemyPosition, aimData[i - 2].NearestEnemyPosition);

                // If significant position change (target switch)
                if (positionDiff > 50.0f)
                {
                    // Calculate how accurately player snapped to the new target
                    float snapAccuracy = aimData[i].AngleToTarget;

                    // Calculate snap speed
                    int timeDelta = aimData[i].Timestamp - aimData[i - 2].Timestamp;
                    float angleDelta = CalculateAngleDifference(aimData[i - 2].ViewAngles, aimData[i].ViewAngles);
                    float snapSpeed = timeDelta > 0 ? angleDelta / timeDelta : 0;

                    targetSwitches.Add(new Tuple<int, Vector3, float, float>(
                        aimData[i].Timestamp,
                        aimData[i].ViewAngles,
                        snapAccuracy,
                        snapSpeed));
                }
            }

            return targetSwitches;
        }

        private float CalculateAverageTargetingError(List<AimData> sequence)
        {
            float totalError = 0;

            foreach (var data in sequence)
            {
                totalError += data.AngleToTarget;
            }

            return totalError / sequence.Count;
        }

        private float AnalyzeTargetPrioritization(List<Tuple<int, Vector3, float, float>> targetSwitches, List<AimData> aimData)
        {
            // Compare actual target selection with expected selection based on distance
            int correctPrioritization = 0;

            for (int i = 1; i < targetSwitches.Count; i++)
            {
                int currentIndex = FindAimDataIndexByTimestamp(aimData, targetSwitches[i].Item1);
                int prevIndex = FindAimDataIndexByTimestamp(aimData, targetSwitches[i - 1].Item1);

                if (currentIndex < 0 || prevIndex < 0) continue;

                // Find all potential targets at the time of the switch
                var potentialTargets = FindPotentialTargets(aimData, currentIndex, 500);

                if (potentialTargets.Count <= 1) continue;

                // Sort potential targets by distance (aimbots typically prioritize closest targets)
                potentialTargets.Sort((a, b) => a.Item2.CompareTo(b.Item2));

                // Check if the selected target matches the closest target
                float selectedTargetDistance = aimData[currentIndex].NearestEnemyDistance;
                float closestTargetDistance = potentialTargets[0].Item2;

                // If the selected target is the closest or second closest, count as correct prioritization
                if (Math.Abs(selectedTargetDistance - closestTargetDistance) < 50)
                {
                    correctPrioritization++;
                }
            }

            // Calculate what percentage of target selections matched distance-based priority
            return targetSwitches.Count > 0 ? (float)correctPrioritization / targetSwitches.Count : 0;
        }

        private int FindAimDataIndexByTimestamp(List<AimData> aimData, int timestamp)
        {
            // Check for null or empty aimData
            if (aimData == null || aimData.Count == 0)
                return -1;
                
            for (int i = 0; i < aimData.Count; i++)
            {
                if (aimData[i].Timestamp == timestamp)
                {
                    return i;
                }

                // Handle case where exact timestamp might not be found
                // Fix logic error: ensure we're finding the closest timestamp
                if (i > 0 && aimData[i - 1].Timestamp < timestamp && aimData[i].Timestamp > timestamp)
                {
                    // Return the closer timestamp
                    int prevDiff = timestamp - aimData[i - 1].Timestamp;
                    int currDiff = aimData[i].Timestamp - timestamp;
                    return prevDiff < currDiff ? i - 1 : i;
                }
            }

            return -1;
        }

        private List<Tuple<Vector3, float>> FindPotentialTargets(List<AimData> aimData, int currentIndex, int timeWindow)
        {
            var targets = new List<Tuple<Vector3, float>>();
            
            // Check for null or empty aimData or invalid index
            if (aimData == null || aimData.Count == 0 || currentIndex < 0 || currentIndex >= aimData.Count)
                return targets;
                
            int targetTimestamp = aimData[currentIndex].Timestamp;

            // Look at nearby timestamps to find other potential targets
            for (int i = Math.Max(0, currentIndex - 30); i < Math.Min(aimData.Count, currentIndex + 30); i++)
            {
                if (Math.Abs(aimData[i].Timestamp - targetTimestamp) > timeWindow) continue;

                if (aimData[i].HasVisibleEnemy)
                {
                    // Check if this target is already in our list
                    bool duplicate = false;
                    foreach (var target in targets)
                    {
                        if (Vector3.Distance(target.Item1, aimData[i].NearestEnemyPosition) < 50)
                        {
                            duplicate = true;
                            break;
                        }
                    }

                    if (!duplicate)
                    {
                        targets.Add(new Tuple<Vector3, float>(
                            aimData[i].NearestEnemyPosition,
                            aimData[i].NearestEnemyDistance));
                    }
                }
            }

            return targets;
        }
    }
}
