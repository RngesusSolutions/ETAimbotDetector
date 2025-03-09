using System;
using System.Collections.Generic;

namespace AimbotDetector.AimAnalyzer
{
    /// <summary>
    /// Contains statistical information about a player's aim behavior
    /// </summary>
    public class PlayerStatistics
    {
        // Angular movement statistics
        public float AverageAngularVelocity { get; set; }
        public float MaxAngularVelocity { get; set; }
        public float AngularVelocityVariability { get; set; }
        public float AverageAngularAcceleration { get; set; }
        public float MaxAngularAcceleration { get; set; }

        // Precision statistics
        public float AverageMicroAdjustment { get; set; }

        // Firing statistics
        public float FiringPercentage { get; set; }
        public float FiringTimePercentage { get; set; }

        // Weapon statistics
        public int PrimaryWeaponId { get; set; }
        public float PrimaryWeaponPercentage { get; set; }

        // Targeting statistics
        public float EnemyVisibilityPercentage { get; set; }
        public float AverageTargetingAccuracy { get; set; }
        public float AverageReactionTime { get; set; }
        public float AverageTargetSwitchSpeed { get; set; }
        public float MaxTargetSwitchSpeed { get; set; }

        // Team comparison data
        public PlayerStatistics? TeamAverages { get; set; }
    }
}