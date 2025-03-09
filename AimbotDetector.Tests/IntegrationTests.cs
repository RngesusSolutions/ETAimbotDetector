using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Numerics;
using AimbotDetector.AimAnalyzer;
using AimbotDetector.DemoParser;
using NUnit.Framework;

namespace AimbotDetector.Tests
{
    [TestFixture]
    public class IntegrationTests
    {
        private string _testDemoPath;
        private string _testOutputDir;

        [SetUp]
        public void Setup()
        {
            // Create test directories
            _testOutputDir = Path.Combine(Path.GetTempPath(), "AimbotDetectorTests", Guid.NewGuid().ToString());
            Directory.CreateDirectory(_testOutputDir);

            // Set up test demo path - this would be a real demo file in actual tests
            _testDemoPath = Path.Combine(_testOutputDir, "test.dm_84");

            // Create a mock demo file with synthetic data for testing
            CreateMockDemoFile(_testDemoPath);
        }

        [TearDown]
        public void TearDown()
        {
            // Clean up test directories
            if (Directory.Exists(_testOutputDir))
            {
                try
                {
                    Directory.Delete(_testOutputDir, true);
                }
                catch
                {
                    // Ignore cleanup failures
                }
            }
        }

        [Test]
        public void TestEndToEndAnalysis()
        {
            // Create command line options
            var options = new EnhancedOptions
            {
                InputFile = _testDemoPath,
                OutputDirectory = Path.Combine(_testOutputDir, "results"),
                Threshold = 0.7f,
                Visualize = true,
                DetailedReport = true,
                AnalyzeAllPlayers = true,
                Verbose = true
            };

            // Run the analysis
            var cli = new EnhancedCommandLine(options);
            int exitCode = cli.Execute();

            // Verify analysis ran successfully
            Assert.AreEqual(0, exitCode, "Analysis should complete successfully");

            // Verify output directories and files were created
            Assert.IsTrue(Directory.Exists(options.OutputDirectory), "Output directory should exist");
            Assert.IsTrue(File.Exists(Path.Combine(options.OutputDirectory, "summary.json")), "Summary JSON should exist");
            Assert.IsTrue(File.Exists(Path.Combine(options.OutputDirectory, "summary.txt")), "Summary text should exist");

            // If we had time, we would verify the content of the output files
        }

        [Test]
        public void TestMultiPlayerAnalyzer()
        {
            // Parse test demo file
            var demoFile = new DemoFile(_testDemoPath);
            bool parseSuccess = demoFile.Parse();

            Assert.IsTrue(parseSuccess, "Demo file should parse successfully");
            Assert.IsTrue(demoFile.Players.Count > 0, "Demo file should contain players");

            // Run multi-player analysis
            var analyzer = new MultiPlayerAnalyzer();
            var results = analyzer.AnalyzeAllPlayers(demoFile.Players);

            // Verify analysis produced results
            Assert.IsNotNull(results, "Analysis should produce results");
            Assert.IsTrue(results.Count > 0, "Analysis should analyze at least one player");

            // Verify that player statistics were calculated
            foreach (var result in results.Values)
            {
                Assert.IsNotNull(result.PlayerStatistics, "Player statistics should be calculated");

                // If we had time, we would verify specific statistics values
            }

            // Verify that comparative analysis was performed
            bool foundComparativeResults = false;
            foreach (var result in results.Values)
            {
                var comparativeResult = result.DetectionResults.FirstOrDefault(r => r.RuleName == "Comparative Analysis");
                if (comparativeResult != null)
                {
                    foundComparativeResults = true;
                    break;
                }
            }

            Assert.IsTrue(foundComparativeResults, "Comparative analysis should be performed");
        }

        [Test]
        public void TestThresholdCalibration()
        {
            // Parse test demo file
            var demoFile = new DemoFile(_testDemoPath);
            bool parseSuccess = demoFile.Parse();

            Assert.IsTrue(parseSuccess, "Demo file should parse successfully");
            Assert.IsTrue(demoFile.Players.Count > 0, "Demo file should contain players");

            // Create calibration system
            var calibratedAnalyzer = new CalibratedAimAnalyzer();

            // Run calibration
            calibratedAnalyzer.CalibrateFromCleanData(demoFile.Players);

            // Verify that the calibration created a profile
            var profiles = calibratedAnalyzer.ListProfiles();
            Assert.IsTrue(profiles.Contains("calibrated"), "Calibration should create a 'calibrated' profile");

            // Verify that the calibrated analyzer can be used for analysis
            foreach (var player in demoFile.Players)
            {
                var detectionResults = calibratedAnalyzer.Analyze(player);
                Assert.IsNotNull(detectionResults, "Calibrated analyzer should produce detection results");
                Assert.IsTrue(detectionResults.Count > 0, "Calibrated analyzer should run multiple detection rules");
            }
        }

        [Test]
        public void TestTargetPriorityDetection()
        {
            // Create player data with synthetic aim data
            var player = CreatePlayerWithSyntheticData();

            // Run target priority detection
            var targetPriorityDetection = new TargetPriorityDetection();
            var result = targetPriorityDetection.Analyze(player);

            // Verify detection produced a result
            Assert.IsNotNull(result, "Detection should produce a result");
            Assert.AreEqual("Target Priority Detection", result.RuleName, "Result should have correct rule name");

            // In a real test, we would verify the detection accuracy on known cheating behaviors
        }

        [Test]
        public void TestBatchProcessing()
        {
            // Create additional test demo files
            string testDir = Path.Combine(_testOutputDir, "batch");
            Directory.CreateDirectory(testDir);

            for (int i = 1; i <= 3; i++)
            {
                string demoPath = Path.Combine(testDir, $"test{i}.dm_84");
                CreateMockDemoFile(demoPath);
            }

            // Create command line options for batch processing
            var options = new EnhancedOptions
            {
                BatchDirectory = testDir,
                OutputDirectory = Path.Combine(_testOutputDir, "batch_results"),
                Threshold = 0.7f,
                Visualize = false,
                DetailedReport = true,
                AnalyzeAllPlayers = true
            };

            // Run batch processing
            var cli = new EnhancedCommandLine(options);
            int exitCode = cli.Execute();

            // Verify batch processing ran successfully
            Assert.AreEqual(0, exitCode, "Batch processing should complete successfully");

            // Verify output directories were created for each demo
            Assert.IsTrue(Directory.Exists(options.OutputDirectory), "Batch output directory should exist");
            Assert.IsTrue(File.Exists(Path.Combine(options.OutputDirectory, "batch_summary.txt")), "Batch summary should exist");

            // Verify individual demo results
            for (int i = 1; i <= 3; i++)
            {
                string demoResultDir = Path.Combine(options.OutputDirectory, $"test{i}");
                Assert.IsTrue(Directory.Exists(demoResultDir), $"Results for test{i} should exist");
                Assert.IsTrue(File.Exists(Path.Combine(demoResultDir, "summary.json")), $"Summary for test{i} should exist");
            }
        }

        [Test]
        public void TestWebReportGeneration()
        {
            // Parse test demo file
            var demoFile = new DemoFile(_testDemoPath);
            bool parseSuccess = demoFile.Parse();

            Assert.IsTrue(parseSuccess, "Demo file should parse successfully");

            // Run multi-player analysis
            var analyzer = new MultiPlayerAnalyzer();
            var results = analyzer.AnalyzeAllPlayers(demoFile.Players);

            // Generate web report
            string webReportDir = Path.Combine(_testOutputDir, "web_report");
            var webReportGenerator = new Visualization.WebReportGenerator();
            webReportGenerator.GenerateInteractiveReport(results, _testDemoPath, webReportDir);

            // Verify web report files were created
            Assert.IsTrue(Directory.Exists(webReportDir), "Web report directory should exist");
            Assert.IsTrue(File.Exists(Path.Combine(webReportDir, "index.html")), "Web report index should exist");
            Assert.IsTrue(Directory.Exists(Path.Combine(webReportDir, "data")), "Data directory should exist");
            Assert.IsTrue(Directory.Exists(Path.Combine(webReportDir, "js")), "JS directory should exist");
            Assert.IsTrue(Directory.Exists(Path.Combine(webReportDir, "css")), "CSS directory should exist");

            // Verify player pages were created
            foreach (var playerName in results.Keys)
            {
                string playerFile = Path.Combine(webReportDir, SanitizeFilename(playerName) + ".html");
                Assert.IsTrue(File.Exists(playerFile), $"Player page for {playerName} should exist");
            }
        }

        // Helper methods

        private void CreateMockDemoFile(string filePath)
        {
            // Create a simple binary file with the ET demo magic header
            using (FileStream fs = new FileStream(filePath, FileMode.Create, FileAccess.Write))
            using (BinaryWriter writer = new BinaryWriter(fs))
            {
                // Write demo magic header
                writer.Write("ETLDEMO2".ToCharArray());

                // Write protocol version
                writer.Write(84);

                // Write a dummy command sequence
                for (int i = 0; i < 10; i++)
                {
                    // Server command
                    writer.Write((byte)1);
                    writer.Write(i);
                    writer.Write("cs 0 test\0".ToCharArray());

                    // Client command
                    writer.Write((byte)2);
                    writer.Write(i);
                    writer.Write("weapon 1\0".ToCharArray());

                    // Snapshot
                    writer.Write((byte)4);
                    writer.Write(i);
                    writer.Write(i * 100); // timestamp

                    // Position
                    writer.Write(100.0f);
                    writer.Write(200.0f);
                    writer.Write(300.0f);

                    // View angles
                    writer.Write(10.0f);
                    writer.Write(20.0f);
                    writer.Write(0.0f);

                    // Skip additional playerstate data
                    for (int j = 0; j < 32; j++)
                    {
                        writer.Write(0);
                    }

                    // Number of entities
                    writer.Write((short)2);

                    // Entity 1
                    writer.Write((short)1);
                    // Skip entity data
                    for (int j = 0; j < 16; j++)
                    {
                        writer.Write(0);
                    }

                    // Entity 2
                    writer.Write((short)2);
                    // Skip entity data
                    for (int j = 0; j < 16; j++)
                    {
                        writer.Write(0);
                    }
                }

                // Write EOF
                writer.Write((byte)5);
            }
        }

        private PlayerData CreatePlayerWithSyntheticData()
        {
            var player = new PlayerData
            {
                PlayerID = 1,
                Name = "TestPlayer",
                Team = 1,
                AimData = new List<AimData>()
            };

            // Create synthetic aim data
            Random random = new Random(42); // Fixed seed for reproducibility

            int baseTime = 0;
            for (int i = 0; i < 100; i++)
            {
                baseTime += 10 + random.Next(5);

                bool hasEnemy = i > 20 && i < 80; // Enemies visible in the middle section
                bool isFiring = hasEnemy && i % 5 == 0; // Fire occasionally when enemy is visible

                float pitchBase = 10.0f;
                float yawBase = 20.0f;

                // Add some random variation
                float pitchRandom = (float)(random.NextDouble() * 2 - 1) * 0.5f;
                float yawRandom = (float)(random.NextDouble() * 2 - 1) * 0.5f;

                var aimData = new AimData
                {
                    Timestamp = baseTime,
                    Position = new Vector3(100, 200, 300),
                    ViewAngles = new Vector3(pitchBase + pitchRandom, yawBase + yawRandom, 0),
                    IsFiring = isFiring,
                    HasVisibleEnemy = hasEnemy
                };

                // Add enemy data if visible
                if (hasEnemy)
                {
                    float enemyDist = 100 + (float)(random.NextDouble() * 50);
                    aimData.NearestEnemyPosition = new Vector3(100 + enemyDist, 200, 300);
                    aimData.NearestEnemyDistance = enemyDist;

                    // Target angles (where the enemy is)
                    aimData.TargetAngles = new Vector3(pitchBase, yawBase, 0);

                    // Angle to target (how far off aim is)
                    aimData.AngleToTarget = (float)(random.NextDouble() * 3);
                    aimData.AngleToTargetPitch = (float)(random.NextDouble() * 1.5f);
                    aimData.AngleToTargetYaw = (float)(random.NextDouble() * 1.5f);
                }

                player.AimData.Add(aimData);
            }

            // Calculate velocities and other metrics
            for (int i = 1; i < player.AimData.Count; i++)
            {
                var current = player.AimData[i];
                var previous = player.AimData[i - 1];

                int timeDelta = current.Timestamp - previous.Timestamp;

                // Calculate angle deltas
                float pitchDelta = Math.Abs(current.ViewAngles.X - previous.ViewAngles.X);
                float yawDelta = Math.Abs(current.ViewAngles.Y - previous.ViewAngles.Y);

                // Normalize angles
                if (pitchDelta > 180) pitchDelta = 360 - pitchDelta;
                if (yawDelta > 180) yawDelta = 360 - yawDelta;

                // Calculate angular velocity (degrees per millisecond)
                float pitchVelocity = pitchDelta / timeDelta;
                float yawVelocity = yawDelta / timeDelta;

                // Store calculated metrics
                current.PitchVelocity = pitchVelocity;
                current.YawVelocity = yawVelocity;
                current.TotalAngularVelocity = (float)Math.Sqrt(pitchVelocity * pitchVelocity + yawVelocity * yawVelocity);
            }

            return player;
        }

        private string SanitizeFilename(string input)
        {
            // Replace invalid filename characters
            foreach (char c in Path.GetInvalidFileNameChars())
            {
                input = input.Replace(c, '_');
            }
            return input;
        }
    }
}