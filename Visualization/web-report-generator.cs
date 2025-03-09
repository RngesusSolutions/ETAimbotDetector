using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace AimbotDetector.Visualization
{
    public class WebReportGenerator
    {
        private const string TEMPLATE_DIR = "templates";

        public void GenerateInteractiveReport(Dictionary<string, AnalysisResult> results, string demoFile, string outputDirectory)
        {
            // Create necessary directories
            Directory.CreateDirectory(outputDirectory);
            Directory.CreateDirectory(Path.Combine(outputDirectory, "js"));
            Directory.CreateDirectory(Path.Combine(outputDirectory, "css"));
            Directory.CreateDirectory(Path.Combine(outputDirectory, "data"));

            // Generate data files
            GenerateDataFiles(results, Path.Combine(outputDirectory, "data"));

            // Generate HTML files
            GenerateMainPage(results, demoFile, Path.Combine(outputDirectory, "index.html"));

            foreach (var result in results.Values)
            {
                GeneratePlayerPage(result, Path.Combine(outputDirectory, $"{SanitizeFilename(result.PlayerName)}.html"));
            }

            // Generate CSS and JS files
            GenerateStylesheet(Path.Combine(outputDirectory, "css", "style.css"));
            GenerateScripts(Path.Combine(outputDirectory, "js", "main.js"));

            Console.WriteLine($"Interactive web report generated at: {outputDirectory}");
        }

        private void GenerateDataFiles(Dictionary<string, AnalysisResult> results, string dataDirectory)
        {
            // Generate summary data file
            var summaryData = new
            {
                timestamp = DateTime.Now,
                totalPlayers = results.Count,
                suspiciousPlayers = results.Count(r => r.Value.IsCheating),
                players = results.Values.Select(r => new
                {
                    name = r.PlayerName,
                    id = r.PlayerID,
                    probability = r.CheatingProbability,
                    isCheating = r.IsCheating,
                    topRules = r.DetectionResults.OrderByDescending(d => d.ConfidenceLevel)
                               .Take(3)
                               .Select(d => new { rule = d.RuleName, confidence = d.ConfidenceLevel })
                }).OrderByDescending(p => p.probability)
            };

            string summaryJson = Newtonsoft.Json.JsonConvert.SerializeObject(summaryData, Newtonsoft.Json.Formatting.Indented);
            File.WriteAllText(Path.Combine(dataDirectory, "summary.json"), summaryJson);

            // Generate player data files
            foreach (var result in results.Values)
            {
                var playerData = new
                {
                    name = result.PlayerName,
                    id = result.PlayerID,
                    probability = result.CheatingProbability,
                    isCheating = result.IsCheating,
                    detectionResults = result.DetectionResults.Select(d => new
                    {
                        rule = d.RuleName,
                        description = d.Description,
                        confidence = d.ConfidenceLevel,
                        evidence = d.Evidence.Select(e => new
                        {
                            timestamp = e.Timestamp,
                            description = e.Description,
                            severity = e.Severity
                        }).OrderByDescending(e => e.severity).Take(10) // Limit to top 10 evidence items
                    }).OrderByDescending(d => d.confidence),
                    statistics = result.PlayerStatistics != null ? SerializePlayerStats(result.PlayerStatistics) : null,
                    teamAverages = result.PlayerStatistics?.TeamAverages != null ? SerializePlayerStats(result.PlayerStatistics.TeamAverages) : null
                };

                string playerJson = Newtonsoft.Json.JsonConvert.SerializeObject(playerData, Newtonsoft.Json.Formatting.Indented);
                File.WriteAllText(Path.Combine(dataDirectory, $"{SanitizeFilename(result.PlayerName)}.json"), playerJson);

                // Generate aim data file if available
                if (result.PlayerAimData != null && result.PlayerAimData.Count > 0)
                {
                    var aimData = result.PlayerAimData.Select(d => new
                    {
                        timestamp = d.Timestamp,
                        pitch = d.ViewAngles.X,
                        yaw = d.ViewAngles.Y,
                        pitchVelocity = d.PitchVelocity,
                        yawVelocity = d.YawVelocity,
                        totalVelocity = d.TotalAngularVelocity,
                        isFiring = d.IsFiring,
                        hasEnemy = d.HasVisibleEnemy,
                        angleToTarget = d.AngleToTarget
                    });

                    string aimDataJson = Newtonsoft.Json.JsonConvert.SerializeObject(aimData, Newtonsoft.Json.Formatting.Indented);
                    File.WriteAllText(Path.Combine(dataDirectory, $"{SanitizeFilename(result.PlayerName)}_aim.json"), aimDataJson);
                }
            }
        }

        private object SerializePlayerStats(PlayerStatistics stats)
        {
            return new
            {
                averageAngularVelocity = stats.AverageAngularVelocity,
                maxAngularVelocity = stats.MaxAngularVelocity,
                angularVelocityVariability = stats.AngularVelocityVariability,
                averageAngularAcceleration = stats.AverageAngularAcceleration,
                maxAngularAcceleration = stats.MaxAngularAcceleration,
                averageMicroAdjustment = stats.AverageMicroAdjustment,
                firingPercentage = stats.FiringPercentage,
                firingTimePercentage = stats.FiringTimePercentage,
                primaryWeaponId = stats.PrimaryWeaponId,
                primaryWeaponPercentage = stats.PrimaryWeaponPercentage,
                enemyVisibilityPercentage = stats.EnemyVisibilityPercentage,
                averageTargetingAccuracy = stats.AverageTargetingAccuracy,
                averageReactionTime = stats.AverageReactionTime,
                averageTargetSwitchSpeed = stats.AverageTargetSwitchSpeed,
                maxTargetSwitchSpeed = stats.MaxTargetSwitchSpeed
            };
        }

        private void GenerateMainPage(Dictionary<string, AnalysisResult> results, string demoFile, string outputPath)
        {
            var html = new StringBuilder();

            html.AppendLine("<!DOCTYPE html>");
            html.AppendLine("<html lang=\"en\">");
            html.AppendLine("<head>");
            html.AppendLine("  <meta charset=\"UTF-8\">");
            html.AppendLine("  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">");
            html.AppendLine("  <title>ET Aimbot Detector - Analysis Report</title>");
            html.AppendLine("  <link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/css/bootstrap.min.css\">");
            html.AppendLine("  <link rel=\"stylesheet\" href=\"css/style.css\">");
            html.AppendLine("  <script src=\"https://cdn.jsdelivr.net/npm/chart.js\"></script>");
            html.AppendLine("  <script src=\"https://cdn.jsdelivr.net/npm/moment\"></script>");
            html.AppendLine("</head>");
            html.AppendLine("<body>");
            html.AppendLine("  <nav class=\"navbar navbar-expand-lg navbar-dark bg-dark\">");
            html.AppendLine("    <div class=\"container-fluid\">");
            html.AppendLine("      <a class=\"navbar-brand\" href=\"index.html\">ET Aimbot Detector</a>");
            html.AppendLine("      <button class=\"navbar-toggler\" type=\"button\" data-bs-toggle=\"collapse\" data-bs-target=\"#navbarNav\" aria-controls=\"navbarNav\" aria-expanded=\"false\" aria-label=\"Toggle navigation\">");
            html.AppendLine("        <span class=\"navbar-toggler-icon\"></span>");
            html.AppendLine("      </button>");
            html.AppendLine("      <div class=\"collapse navbar-collapse\" id=\"navbarNav\">");
            html.AppendLine("        <ul class=\"navbar-nav\">");
            html.AppendLine("          <li class=\"nav-item\">");
            html.AppendLine("            <a class=\"nav-link active\" aria-current=\"page\" href=\"index.html\">Summary</a>");
            html.AppendLine("          </li>");

            // Add player links
            foreach (var result in results.Values.OrderByDescending(r => r.CheatingProbability))
            {
                string statusClass = result.IsCheating ? "text-danger" : "text-success";
                html.AppendLine($"          <li class=\"nav-item\">");
                html.AppendLine($"            <a class=\"nav-link {statusClass}\" href=\"{SanitizeFilename(result.PlayerName)}.html\">{result.PlayerName}</a>");
                html.AppendLine($"          </li>");
            }

            html.AppendLine("        </ul>");
            html.AppendLine("      </div>");
            html.AppendLine("    </div>");
            html.AppendLine("  </nav>");

            html.AppendLine("  <div class=\"container mt-4\">");
            html.AppendLine("    <div class=\"row\">");
            html.AppendLine("      <div class=\"col-12\">");
            html.AppendLine("        <div class=\"card\">");
            html.AppendLine("          <div class=\"card-header bg-primary text-white\">");
            html.AppendLine("            <h2>Analysis Summary</h2>");
            html.AppendLine("          </div>");
            html.AppendLine("          <div class=\"card-body\">");
            html.AppendLine($"            <h5>Demo File: {Path.GetFileName(demoFile)}</h5>");
            html.AppendLine($"            <p>Analysis Time: <span id=\"analysisTime\"></span></p>");
            html.AppendLine($"            <p>Total Players: {results.Count}</p>");
            html.AppendLine($"            <p>Suspicious Players: {results.Count(r => r.Value.IsCheating)}</p>");
            html.AppendLine("          </div>");
            html.AppendLine("        </div>");
            html.AppendLine("      </div>");
            html.AppendLine("    </div>");

            // Probability distribution chart
            html.AppendLine("    <div class=\"row mt-4\">");
            html.AppendLine("      <div class=\"col-12\">");
            html.AppendLine("        <div class=\"card\">");
            html.AppendLine("          <div class=\"card-header bg-info text-white\">");
            html.AppendLine("            <h3>Cheating Probability Distribution</h3>");
            html.AppendLine("          </div>");
            html.AppendLine("          <div class=\"card-body\">");
            html.AppendLine("            <div style=\"height: 400px;\">");
            html.AppendLine("              <canvas id=\"probabilityChart\"></canvas>");
            html.AppendLine("            </div>");
            html.AppendLine("          </div>");
            html.AppendLine("        </div>");
            html.AppendLine("      </div>");
            html.AppendLine("    </div>");

            // Detection rules effectiveness chart
            html.AppendLine("    <div class=\"row mt-4\">");
            html.AppendLine("      <div class=\"col-12\">");
            html.AppendLine("        <div class=\"card\">");
            html.AppendLine("          <div class=\"card-header bg-info text-white\">");
            html.AppendLine("            <h3>Detection Rules Effectiveness</h3>");
            html.AppendLine("          </div>");
            html.AppendLine("          <div class=\"card-body\">");
            html.AppendLine("            <div style=\"height: 500px;\">");
            html.AppendLine("              <canvas id=\"rulesChart\"></canvas>");
            html.AppendLine("            </div>");
            html.AppendLine("          </div>");
            html.AppendLine("        </div>");
            html.AppendLine("      </div>");
            html.AppendLine("    </div>");

            // Player summary table
            html.AppendLine("    <div class=\"row mt-4 mb-5\">");
            html.AppendLine("      <div class=\"col-12\">");
            html.AppendLine("        <div class=\"card\">");
            html.AppendLine("          <div class=\"card-header bg-secondary text-white\">");
            html.AppendLine("            <h3>Player Results</h3>");
            html.AppendLine("          </div>");
            html.AppendLine("          <div class=\"card-body\">");
            html.AppendLine("            <div class=\"table-responsive\">");
            html.AppendLine("              <table class=\"table table-striped table-hover\">");
            html.AppendLine("                <thead>");
            html.AppendLine("                  <tr>");
            html.AppendLine("                    <th>Player</th>");
            html.AppendLine("                    <th>ID</th>");
            html.AppendLine("                    <th>Probability</th>");
            html.AppendLine("                    <th>Status</th>");
            html.AppendLine("                    <th>Top Detection</th>");
            html.AppendLine("                    <th>Action</th>");
            html.AppendLine("                  </tr>");
            html.AppendLine("                </thead>");
            html.AppendLine("                <tbody>");

            foreach (var result in results.Values.OrderByDescending(r => r.CheatingProbability))
            {
                string probabilityClass = result.CheatingProbability < 0.4 ? "text-success" :
                                        (result.CheatingProbability < 0.7 ? "text-warning" : "text-danger");

                string status = result.IsCheating ? "SUSPICIOUS" : "CLEAN";
                string statusClass = result.IsCheating ? "badge bg-danger" : "badge bg-success";

                var topDetection = result.DetectionResults
                    .OrderByDescending(d => d.ConfidenceLevel)
                    .FirstOrDefault();

                html.AppendLine("                  <tr>");
                html.AppendLine($"                    <td>{result.PlayerName}</td>");
                html.AppendLine($"                    <td>{result.PlayerID}</td>");
                html.AppendLine($"                    <td class=\"{probabilityClass}\">{result.CheatingProbability:P1}</td>");
                html.AppendLine($"                    <td><span class=\"{statusClass}\">{status}</span></td>");
                html.AppendLine($"                    <td>{(topDetection != null ? $"{topDetection.RuleName} ({topDetection.ConfidenceLevel:P1})" : "N/A")}</td>");
                html.AppendLine($"                    <td><a href=\"{SanitizeFilename(result.PlayerName)}.html\" class=\"btn btn-sm btn-primary\">Details</a></td>");
                html.AppendLine("                  </tr>");
            }

            html.AppendLine("                </tbody>");
            html.AppendLine("              </table>");
            html.AppendLine("            </div>");
            html.AppendLine("          </div>");
            html.AppendLine("        </div>");
            html.AppendLine("      </div>");
            html.AppendLine("    </div>");

            html.AppendLine("  </div>");

            // Footer
            html.AppendLine("  <footer class=\"bg-dark text-white text-center py-3\">");
            html.AppendLine("    <div class=\"container\">");
            html.AppendLine("      <p class=\"mb-0\">ET Aimbot Detector - Analysis Report</p>");
            html.AppendLine("      <p class=\"mb-0 small\">Generated on <span id=\"footerDate\"></span></p>");
            html.AppendLine("    </div>");
            html.AppendLine("  </footer>");

            // JavaScript
            html.AppendLine("  <script src=\"https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/js/bootstrap.bundle.min.js\"></script>");
            html.AppendLine("  <script src=\"js/main.js\"></script>");
            html.AppendLine("  <script>");
            html.AppendLine("    document.addEventListener('DOMContentLoaded', function() {");
            html.AppendLine("      // Load summary data and initialize charts");
            html.AppendLine("      fetch('data/summary.json')");
            html.AppendLine("        .then(response => response.json())");
            html.AppendLine("        .then(data => {");
            html.AppendLine("          document.getElementById('analysisTime').textContent = new Date(data.timestamp).toLocaleString();");
            html.AppendLine("          document.getElementById('footerDate').textContent = new Date(data.timestamp).toLocaleString();");
            html.AppendLine("          ");
            html.AppendLine("          // Initialize summary charts");
            html.AppendLine("          initializeSummaryCharts(data);");
            html.AppendLine("        });");
            html.AppendLine("    });");
            html.AppendLine("  </script>");
            html.AppendLine("</body>");
            html.AppendLine("</html>");

            File.WriteAllText(outputPath, html.ToString());
        }

        private void GeneratePlayerPage(AnalysisResult result, string outputPath)
        {
            var html = new StringBuilder();

            html.AppendLine("<!DOCTYPE html>");
            html.AppendLine("<html lang=\"en\">");
            html.AppendLine("<head>");
            html.AppendLine("  <meta charset=\"UTF-8\">");
            html.AppendLine("  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">");
            html.AppendLine($"  <title>ET Aimbot Detector - {result.PlayerName}</title>");
            html.AppendLine("  <link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/css/bootstrap.min.css\">");
            html.AppendLine("  <link rel=\"stylesheet\" href=\"css/style.css\">");
            html.AppendLine("  <script src=\"https://cdn.jsdelivr.net/npm/chart.js\"></script>");
            html.AppendLine("  <script src=\"https://cdn.jsdelivr.net/npm/moment\"></script>");
            html.AppendLine("</head>");
            html.AppendLine("<body>");
            html.AppendLine("  <nav class=\"navbar navbar-expand-lg navbar-dark bg-dark\">");
            html.AppendLine("    <div class=\"container-fluid\">");
            html.AppendLine("      <a class=\"navbar-brand\" href=\"index.html\">ET Aimbot Detector</a>");
            html.AppendLine("      <button class=\"navbar-toggler\" type=\"button\" data-bs-toggle=\"collapse\" data-bs-target=\"#navbarNav\" aria-controls=\"navbarNav\" aria-expanded=\"false\" aria-label=\"Toggle navigation\">");
            html.AppendLine("        <span class=\"navbar-toggler-icon\"></span>");
            html.AppendLine("      </button>");
            html.AppendLine("      <div class=\"collapse navbar-collapse\" id=\"navbarNav\">");
            html.AppendLine("        <ul class=\"navbar-nav\">");
            html.AppendLine("          <li class=\"nav-item\">");
            html.AppendLine("            <a class=\"nav-link\" href=\"index.html\">Summary</a>");
            html.AppendLine("          </li>");
            html.AppendLine("          <li class=\"nav-item\">");
            html.AppendLine($"            <a class=\"nav-link active\" aria-current=\"page\" href=\"{SanitizeFilename(result.PlayerName)}.html\">{result.PlayerName}</a>");
            html.AppendLine("          </li>");
            html.AppendLine("        </ul>");
            html.AppendLine("      </div>");
            html.AppendLine("    </div>");
            html.AppendLine("  </nav>");

            html.AppendLine("  <div class=\"container mt-4\">");
            html.AppendLine("    <div class=\"row\">");
            html.AppendLine("      <div class=\"col-12\">");
            html.AppendLine("        <div class=\"card\">");
            html.AppendLine("          <div class=\"card-header bg-primary text-white\">");
            html.AppendLine($"            <h2>Player Analysis: {result.PlayerName}</h2>");
            html.AppendLine("          </div>");
            html.AppendLine("          <div class=\"card-body\">");

            // Calculate status classes
            string probabilityClass = result.CheatingProbability < 0.4 ? "text-success" :
                                    (result.CheatingProbability < 0.7 ? "text-warning" : "text-danger");
            string statusClass = result.IsCheating ? "badge bg-danger" : "badge bg-success";
            string statusText = result.IsCheating ? "SUSPICIOUS" : "CLEAN";

            html.AppendLine("            <div class=\"row\">");
            html.AppendLine("              <div class=\"col-md-6\">");
            html.AppendLine($"                <p><strong>Player ID:</strong> {result.PlayerID}</p>");
            html.AppendLine($"                <p><strong>Status:</strong> <span class=\"{statusClass}\">{statusText}</span></p>");
            html.AppendLine($"                <p><strong>Cheating Probability:</strong> <span class=\"{probabilityClass}\">{result.CheatingProbability:P1}</span></p>");
            html.AppendLine("              </div>");
            html.AppendLine("              <div class=\"col-md-6\">");
            html.AppendLine("                <div class=\"progress mb-3\" style=\"height: 30px;\">");
            html.AppendLine($"                  <div class=\"progress-bar {GetProgressBarClass(result.CheatingProbability)}\" role=\"progressbar\" style=\"width: {result.CheatingProbability * 100}%;\" aria-valuenow=\"{result.CheatingProbability * 100}\" aria-valuemin=\"0\" aria-valuemax=\"100\">{result.CheatingProbability:P1}</div>");
            html.AppendLine("                </div>");
            html.AppendLine("              </div>");
            html.AppendLine("            </div>");
            html.AppendLine("          </div>");
            html.AppendLine("        </div>");
            html.AppendLine("      </div>");
            html.AppendLine("    </div>");

            // Main charts - aim angles over time
            html.AppendLine("    <div class=\"row mt-4\">");
            html.AppendLine("      <div class=\"col-12\">");
            html.AppendLine("        <div class=\"card\">");
            html.AppendLine("          <div class=\"card-header bg-info text-white\">");
            html.AppendLine("            <h3>View Angles Over Time</h3>");
            html.AppendLine("          </div>");
            html.AppendLine("          <div class=\"card-body\">");
            html.AppendLine("            <div style=\"height: 400px;\">");
            html.AppendLine("              <canvas id=\"angleChart\"></canvas>");
            html.AppendLine("            </div>");
            html.AppendLine("          </div>");
            html.AppendLine("        </div>");
            html.AppendLine("      </div>");
            html.AppendLine("    </div>");

            // Angular velocity chart
            html.AppendLine("    <div class=\"row mt-4\">");
            html.AppendLine("      <div class=\"col-12\">");
            html.AppendLine("        <div class=\"card\">");
            html.AppendLine("          <div class=\"card-header bg-info text-white\">");
            html.AppendLine("            <h3>Angular Velocity Over Time</h3>");
            html.AppendLine("          </div>");
            html.AppendLine("          <div class=\"card-body\">");
            html.AppendLine("            <div style=\"height: 400px;\">");
            html.AppendLine("              <canvas id=\"velocityChart\"></canvas>");
            html.AppendLine("            </div>");
            html.AppendLine("          </div>");
            html.AppendLine("        </div>");
            html.AppendLine("      </div>");
            html.AppendLine("    </div>");

            // Detection metrics visualization
            html.AppendLine("    <div class=\"row mt-4\">");
            html.AppendLine("      <div class=\"col-12\">");
            html.AppendLine("        <div class=\"card\">");
            html.AppendLine("          <div class=\"card-header bg-secondary text-white\">");
            html.AppendLine("            <h3>Detection Metrics</h3>");
            html.AppendLine("          </div>");
            html.AppendLine("          <div class=\"card-body\">");
            html.AppendLine("            <div class=\"table-responsive\">");
            html.AppendLine("              <table class=\"table table-striped table-hover\">");
            html.AppendLine("                <thead>");
            html.AppendLine("                  <tr>");
            html.AppendLine("                    <th>Detection Rule</th>");
            html.AppendLine("                    <th>Confidence</th>");
            html.AppendLine("                    <th>Description</th>");
            html.AppendLine("                    <th>Evidence</th>");
            html.AppendLine("                  </tr>");
            html.AppendLine("                </thead>");
            html.AppendLine("                <tbody>");

            foreach (var detection in result.DetectionResults.OrderByDescending(d => d.ConfidenceLevel))
            {
                string detectionClass = detection.ConfidenceLevel < 0.4 ? "text-success" :
                                      (detection.ConfidenceLevel < 0.7 ? "text-warning" : "text-danger");

                html.AppendLine("                  <tr>");
                html.AppendLine($"                    <td>{detection.RuleName}</td>");
                html.AppendLine($"                    <td class=\"{detectionClass}\">{detection.ConfidenceLevel:P1}</td>");
                html.AppendLine($"                    <td>{detection.Description}</td>");
                html.AppendLine("                    <td>");

                if (detection.Evidence.Count > 0)
                {
                    html.AppendLine($"                      <button class=\"btn btn-sm btn-primary\" data-bs-toggle=\"modal\" data-bs-target=\"#evidenceModal{SanitizeId(detection.RuleName)}\">View Evidence</button>");
                }
                else
                {
                    html.AppendLine("                      <span class=\"text-muted\">No evidence</span>");
                }

                html.AppendLine("                    </td>");
                html.AppendLine("                  </tr>");
            }

            html.AppendLine("                </tbody>");
            html.AppendLine("              </table>");
            html.AppendLine("            </div>");
            html.AppendLine("          </div>");
            html.AppendLine("        </div>");
            html.AppendLine("      </div>");
            html.AppendLine("    </div>");

            // Player statistics
            if (result.PlayerStatistics != null)
            {
                html.AppendLine("    <div class=\"row mt-4 mb-5\">");
                html.AppendLine("      <div class=\"col-12\">");
                html.AppendLine("        <div class=\"card\">");
                html.AppendLine("          <div class=\"card-header bg-success text-white\">");
                html.AppendLine("            <h3>Player Statistics</h3>");
                html.AppendLine("          </div>");
                html.AppendLine("          <div class=\"card-body\">");
                html.AppendLine("            <div class=\"row\">");

                // Left column - aim statistics
                html.AppendLine("              <div class=\"col-md-6\">");
                html.AppendLine("                <h4>Aim Statistics</h4>");
                html.AppendLine("                <table class=\"table table-sm\">");
                html.AppendLine("                  <tbody>");
                html.AppendLine($"                    <tr><td>Average Angular Velocity</td><td>{result.PlayerStatistics.AverageAngularVelocity:F3}°/ms</td></tr>");
                html.AppendLine($"                    <tr><td>Max Angular Velocity</td><td>{result.PlayerStatistics.MaxAngularVelocity:F3}°/ms</td></tr>");
                html.AppendLine($"                    <tr><td>Angular Velocity Variability</td><td>{result.PlayerStatistics.AngularVelocityVariability:F3}</td></tr>");
                html.AppendLine($"                    <tr><td>Average Micro-Adjustment</td><td>{result.PlayerStatistics.AverageMicroAdjustment:F3}°</td></tr>");
                html.AppendLine($"                    <tr><td>Firing Percentage</td><td>{result.PlayerStatistics.FiringPercentage:P1}</td></tr>");
                html.AppendLine("                  </tbody>");
                html.AppendLine("                </table>");
                html.AppendLine("              </div>");

                // Right column - targeting statistics
                html.AppendLine("              <div class=\"col-md-6\">");
                html.AppendLine("                <h4>Targeting Statistics</h4>");
                html.AppendLine("                <table class=\"table table-sm\">");
                html.AppendLine("                  <tbody>");
                html.AppendLine($"                    <tr><td>Enemy Visibility</td><td>{result.PlayerStatistics.EnemyVisibilityPercentage:P1}</td></tr>");
                html.AppendLine($"                    <tr><td>Targeting Accuracy</td><td>{result.PlayerStatistics.AverageTargetingAccuracy:P1}</td></tr>");
                html.AppendLine($"                    <tr><td>Average Reaction Time</td><td>{result.PlayerStatistics.AverageReactionTime:F1}ms</td></tr>");
                html.AppendLine($"                    <tr><td>Target Switch Speed</td><td>{result.PlayerStatistics.AverageTargetSwitchSpeed:F3}°/ms</td></tr>");
                html.AppendLine($"                    <tr><td>Max Target Switch Speed</td><td>{result.PlayerStatistics.MaxTargetSwitchSpeed:F3}°/ms</td></tr>");
                html.AppendLine("                  </tbody>");
                html.AppendLine("                </table>");
                html.AppendLine("              </div>");

                html.AppendLine("            </div>");

                // Team comparison if available
                if (result.PlayerStatistics.TeamAverages != null)
                {
                    html.AppendLine("            <div class=\"row mt-4\">");
                    html.AppendLine("              <div class=\"col-12\">");
                    html.AppendLine("                <h4>Team Comparison</h4>");
                    html.AppendLine("                <div style=\"height: 300px;\">");
                    html.AppendLine("                  <canvas id=\"teamComparisonChart\"></canvas>");
                    html.AppendLine("                </div>");
                    html.AppendLine("              </div>");
                    html.AppendLine("            </div>");
                }

                html.AppendLine("          </div>");
                html.AppendLine("        </div>");
                html.AppendLine("      </div>");
                html.AppendLine("    </div>");
            }

            html.AppendLine("  </div>");

            // Modals for evidence display
            foreach (var detection in result.DetectionResults.Where(d => d.Evidence.Count > 0))
            {
                html.AppendLine($"  <div class=\"modal fade\" id=\"evidenceModal{SanitizeId(detection.RuleName)}\" tabindex=\"-1\" aria-labelledby=\"evidenceModalLabel{SanitizeId(detection.RuleName)}\" aria-hidden=\"true\">");
                html.AppendLine("    <div class=\"modal-dialog modal-lg\">");
                html.AppendLine("      <div class=\"modal-content\">");
                html.AppendLine("        <div class=\"modal-header\">");
                html.AppendLine($"          <h5 class=\"modal-title\" id=\"evidenceModalLabel{SanitizeId(detection.RuleName)}\">Evidence for {detection.RuleName}</h5>");
                html.AppendLine("          <button type=\"button\" class=\"btn-close\" data-bs-dismiss=\"modal\" aria-label=\"Close\"></button>");
                html.AppendLine("        </div>");
                html.AppendLine("        <div class=\"modal-body\">");
                html.AppendLine("          <div class=\"table-responsive\">");
                html.AppendLine("            <table class=\"table table-striped\">");
                html.AppendLine("              <thead>");
                html.AppendLine("                <tr>");
                html.AppendLine("                  <th>Time</th>");
                html.AppendLine("                  <th>Description</th>");
                html.AppendLine("                  <th>Severity</th>");
                html.AppendLine("                </tr>");
                html.AppendLine("              </thead>");
                html.AppendLine("              <tbody>");

                foreach (var evidence in detection.Evidence.OrderByDescending(e => e.Severity))
                {
                    string severityClass = evidence.Severity < 0.4 ? "text-success" :
                                        (evidence.Severity < 0.7 ? "text-warning" : "text-danger");

                    html.AppendLine("                <tr>");
                    html.AppendLine($"                  <td>{FormatTimestamp(evidence.Timestamp)}</td>");
                    html.AppendLine($"                  <td>{evidence.Description}</td>");
                    html.AppendLine($"                  <td class=\"{severityClass}\">{evidence.Severity:P1}</td>");
                    html.AppendLine("                </tr>");
                }

                html.AppendLine("              </tbody>");
                html.AppendLine("            </table>");
                html.AppendLine("          </div>");
                html.AppendLine("        </div>");
                html.AppendLine("        <div class=\"modal-footer\">");
                html.AppendLine("          <button type=\"button\" class=\"btn btn-secondary\" data-bs-dismiss=\"modal\">Close</button>");
                html.AppendLine("        </div>");
                html.AppendLine("      </div>");
                html.AppendLine("    </div>");
                html.AppendLine("  </div>");
            }

            // Footer
            html.AppendLine("  <footer class=\"bg-dark text-white text-center py-3\">");
            html.AppendLine("    <div class=\"container\">");
            html.AppendLine("      <p class=\"mb-0\">ET Aimbot Detector - Player Analysis Report</p>");
            html.AppendLine("      <p class=\"mb-0 small\">Generated on <span id=\"footerDate\"></span></p>");
            html.AppendLine("    </div>");
            html.AppendLine("  </footer>");

            // JavaScript
            html.AppendLine("  <script src=\"https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/js/bootstrap.bundle.min.js\"></script>");
            html.AppendLine("  <script src=\"js/main.js\"></script>");
            html.AppendLine("  <script>");
            html.AppendLine("    document.addEventListener('DOMContentLoaded', function() {");
            html.AppendLine($"      const playerName = '{result.PlayerName}';");
            html.AppendLine("      const hasTeamData = " + (result.PlayerStatistics?.TeamAverages != null ? "true" : "false") + ";");
            html.AppendLine("      ");
            html.AppendLine("      // Load player data");
            html.AppendLine($"      fetch('data/{SanitizeFilename(result.PlayerName)}.json')");
            html.AppendLine("        .then(response => response.json())");
            html.AppendLine("        .then(playerData => {");
            html.AppendLine("          document.getElementById('footerDate').textContent = new Date().toLocaleString();");
            html.AppendLine("          ");
            html.AppendLine("          // Load aim data and initialize charts");
            html.AppendLine($"          return fetch('data/{SanitizeFilename(result.PlayerName)}_aim.json')");
            html.AppendLine("            .then(response => response.json())");
            html.AppendLine("            .then(aimData => {");
            html.AppendLine("              initializePlayerCharts(playerData, aimData, hasTeamData);");
            html.AppendLine("            });");
            html.AppendLine("        });");
            html.AppendLine("    });");
            html.AppendLine("  </script>");
            html.AppendLine("</body>");
            html.AppendLine("</html>");

            File.WriteAllText(outputPath, html.ToString());
        }

        private void GenerateStylesheet(string outputPath)
        {
            var css = new StringBuilder();

            css.AppendLine("/* ET Aimbot Detector - Web Report Styles */");
            css.AppendLine(".evidence-item {");
            css.AppendLine("  border-left: 3px solid #f44336;");
            css.AppendLine("  padding-left: 10px;");
            css.AppendLine("  margin-bottom: 10px;");
            css.AppendLine("}");
            css.AppendLine("");
            css.AppendLine(".stat-card {");
            css.AppendLine("  border-radius: 8px;");
            css.AppendLine("  box-shadow: 0 2px 5px rgba(0,0,0,0.1);");
            css.AppendLine("  margin-bottom: 20px;");
            css.AppendLine("  padding: 15px;");
            css.AppendLine("}");
            css.AppendLine("");
            css.AppendLine(".stat-value {");
            css.AppendLine("  font-size: 24px;");
            css.AppendLine("  font-weight: bold;");
            css.AppendLine("}");
            css.AppendLine("");
            css.AppendLine(".stat-title {");
            css.AppendLine("  font-size: 14px;");
            css.AppendLine("  color: #666;");
            css.AppendLine("}");

            File.WriteAllText(outputPath, css.ToString());
        }

        private void GenerateScripts(string outputPath)
        {
            var js = new StringBuilder();

            js.AppendLine("// ET Aimbot Detector - Web Report Scripts");
            js.AppendLine("");
            js.AppendLine("// Initialize summary page charts");
            js.AppendLine("function initializeSummaryCharts(data) {");
            js.AppendLine("  // Probability distribution chart");
            js.AppendLine("  const probCtx = document.getElementById('probabilityChart').getContext('2d');");
            js.AppendLine("  new Chart(probCtx, {");
            js.AppendLine("    type: 'bar',");
            js.AppendLine("    data: {");
            js.AppendLine("      labels: data.players.map(p => p.name),");
            js.AppendLine("      datasets: [{");
            js.AppendLine("        label: 'Cheating Probability',");
            js.AppendLine("        data: data.players.map(p => p.probability),");
            js.AppendLine("        backgroundColor: data.players.map(p => p.isCheating ? 'rgba(255, 99, 132, 0.8)' : 'rgba(75, 192, 192, 0.8)'),");
            js.AppendLine("        borderColor: data.players.map(p => p.isCheating ? 'rgb(255, 99, 132)' : 'rgb(75, 192, 192)'),");
            js.AppendLine("        borderWidth: 1");
            js.AppendLine("      }]");
            js.AppendLine("    },");
            js.AppendLine("    options: {");
            js.AppendLine("      responsive: true,");
            js.AppendLine("      maintainAspectRatio: false,");
            js.AppendLine("      plugins: {");
            js.AppendLine("        title: {");
            js.AppendLine("          display: true,");
            js.AppendLine("          text: 'Cheating Probability by Player'");
            js.AppendLine("        },");
            js.AppendLine("        legend: {");
            js.AppendLine("          display: false");
            js.AppendLine("        }");
            js.AppendLine("      },");
            js.AppendLine("      scales: {");
            js.AppendLine("        y: {");
            js.AppendLine("          beginAtZero: true,");
            js.AppendLine("          max: 1,");
            js.AppendLine("          title: {");
            js.AppendLine("            display: true,");
            js.AppendLine("            text: 'Cheating Probability'");
            js.AppendLine("          }");
            js.AppendLine("        }");
            js.AppendLine("      }");
            js.AppendLine("    }");
            js.AppendLine("  });");
            js.AppendLine("  ");
            js.AppendLine("  // Prepare data for rules effectiveness chart");
            js.AppendLine("  const ruleEffectiveness = {};");
            js.AppendLine("  ");
            js.AppendLine("  // Process all players and their detection results");
            js.AppendLine("  data.players.forEach(player => {");
            js.AppendLine("    player.topRules.forEach(rule => {");
            js.AppendLine("      if (!ruleEffectiveness[rule.rule]) {");
            js.AppendLine("        ruleEffectiveness[rule.rule] = [];");
            js.AppendLine("      }");
            js.AppendLine("      ruleEffectiveness[rule.rule].push(rule.confidence);");
            js.AppendLine("    });");
            js.AppendLine("  });");
            js.AppendLine("  ");
            js.AppendLine("  // Calculate average effectiveness for each rule");
            js.AppendLine("  const ruleAverages = Object.keys(ruleEffectiveness).map(rule => {");
            js.AppendLine("    const confidences = ruleEffectiveness[rule];");
            js.AppendLine("    const sum = confidences.reduce((a, b) => a + b, 0);");
            js.AppendLine("    const avg = sum / confidences.length;");
            js.AppendLine("    return { rule, average: avg };");
            js.AppendLine("  }).sort((a, b) => b.average - a.average);");
            js.AppendLine("  ");
            js.AppendLine("  // Create rules effectiveness chart");
            js.AppendLine("  const rulesCtx = document.getElementById('rulesChart').getContext('2d');");
            js.AppendLine("  new Chart(rulesCtx, {");
            js.AppendLine("    type: 'bar',");
            js.AppendLine("    data: {");
            js.AppendLine("      labels: ruleAverages.map(r => r.rule),");
            js.AppendLine("      datasets: [{");
            js.AppendLine("        label: 'Average Confidence',");
            js.AppendLine("        data: ruleAverages.map(r => r.average),");
            js.AppendLine("        backgroundColor: 'rgba(153, 102, 255, 0.8)',");
            js.AppendLine("        borderColor: 'rgb(153, 102, 255)',");
            js.AppendLine("        borderWidth: 1");
            js.AppendLine("      }]");
            js.AppendLine("    },");
            js.AppendLine("    options: {");
            js.AppendLine("      indexAxis: 'y',");
            js.AppendLine("      responsive: true,");
            js.AppendLine("      maintainAspectRatio: false,");
            js.AppendLine("      plugins: {");
            js.AppendLine("        title: {");
            js.AppendLine("          display: true,");
            js.AppendLine("          text: 'Detection Rules Effectiveness'");
            js.AppendLine("        }");
            js.AppendLine("      },");
            js.AppendLine("      scales: {");
            js.AppendLine("        x: {");
            js.AppendLine("          beginAtZero: true,");
            js.AppendLine("          max: 1,");
            js.AppendLine("          title: {");
            js.AppendLine("            display: true,");
            js.AppendLine("            text: 'Average Confidence'");
            js.AppendLine("          }");
            js.AppendLine("        }");
            js.AppendLine("      }");
            js.AppendLine("    }");
            js.AppendLine("  });");
            js.AppendLine("}");
            js.AppendLine("");
            js.AppendLine("// Initialize player page charts");
            js.AppendLine("function initializePlayerCharts(playerData, aimData, hasTeamData) {");
            js.AppendLine("  // Extract evidence markers from player data");
            js.AppendLine("  const evidenceMarkers = [];");
            js.AppendLine("  playerData.detectionResults.forEach(result => {");
            js.AppendLine("    result.evidence.forEach(ev => {");
            js.AppendLine("      evidenceMarkers.push({");
            js.AppendLine("        timestamp: ev.timestamp,");
            js.AppendLine("        rule: result.rule,");
            js.AppendLine("        description: ev.description,");
            js.AppendLine("        severity: ev.severity");
            js.AppendLine("      });");
            js.AppendLine("    });");
            js.AppendLine("  });");
            js.AppendLine("  ");
            js.AppendLine("  // Create angle chart");
            js.AppendLine("  const angleCtx = document.getElementById('angleChart').getContext('2d');");
            js.AppendLine("  new Chart(angleCtx, {");
            js.AppendLine("    type: 'line',");
            js.AppendLine("    data: {");
            js.AppendLine("      datasets: [");
            js.AppendLine("        {");
            js.AppendLine("          label: 'Pitch',");
            js.AppendLine("          data: aimData.map(d => ({x: d.timestamp, y: d.pitch})),");
            js.AppendLine("          borderColor: 'rgb(75, 192, 192)',");
            js.AppendLine("          pointRadius: 0,");
            js.AppendLine("          borderWidth: 1,");
            js.AppendLine("          tension: 0.1");
            js.AppendLine("        },");
            js.AppendLine("        {");
            js.AppendLine("          label: 'Yaw',");
            js.AppendLine("          data: aimData.map(d => ({x: d.timestamp, y: d.yaw})),");
            js.AppendLine("          borderColor: 'rgb(153, 102, 255)',");
            js.AppendLine("          pointRadius: 0,");
            js.AppendLine("          borderWidth: 1,");
            js.AppendLine("          tension: 0.1");
            js.AppendLine("        },");
            js.AppendLine("        {");
            js.AppendLine("          label: 'Firing',");
            js.AppendLine("          data: aimData.filter(d => d.isFiring).map(d => ({x: d.timestamp, y: d.pitch})),");
            js.AppendLine("          backgroundColor: 'rgba(255, 99, 132, 0.5)',");
            js.AppendLine("          pointRadius: 3,");
            js.AppendLine("          showLine: false");
            js.AppendLine("        },");
            js.AppendLine("        {");
            js.AppendLine("          label: 'Evidence',");
            js.AppendLine("          data: evidenceMarkers.map(m => {");
            js.AppendLine("            const nearestAim = aimData.reduce((prev, curr) => {");
            js.AppendLine("              return Math.abs(curr.timestamp - m.timestamp) < Math.abs(prev.timestamp - m.timestamp) ? curr : prev;");
            js.AppendLine("            }, aimData[0]);");
            js.AppendLine("            return {x: m.timestamp, y: nearestAim.pitch, rule: m.rule, description: m.description, severity: m.severity};");
            js.AppendLine("          }),");
            js.AppendLine("          backgroundColor: m => {");
            js.AppendLine("            const value = m.raw.severity;");
            js.AppendLine("            return value < 0.4 ? 'rgba(75, 192, 192, 0.8)' : (value < 0.7 ? 'rgba(255, 205, 86, 0.8)' : 'rgba(255, 99, 132, 0.8)');");
            js.AppendLine("          },");
            js.AppendLine("          pointRadius: 6,");
            js.AppendLine("          showLine: false");
            js.AppendLine("        }");
            js.AppendLine("      ]");
            js.AppendLine("    },");
            js.AppendLine("    options: {");
            js.AppendLine("      responsive: true,");
            js.AppendLine("      maintainAspectRatio: false,");
            js.AppendLine("      plugins: {");
            js.AppendLine("        title: {");
            js.AppendLine("          display: true,");
            js.AppendLine("          text: 'View Angles Over Time'");
            js.AppendLine("        },");
            js.AppendLine("        tooltip: {");
            js.AppendLine("          callbacks: {");
            js.AppendLine("            afterBody: function(context) {");
            js.AppendLine("              if (context[0].datasetIndex === 3) { // Evidence dataset");
            js.AppendLine("                return [");
            js.AppendLine("                  `Rule: ${context[0].raw.rule}`,");
            js.AppendLine("                  `Description: ${context[0].raw.description}`,");
            js.AppendLine("                  `Severity: ${(context[0].raw.severity * 100).toFixed(1)}%`");
            js.AppendLine("                ];");
            js.AppendLine("              }");
            js.AppendLine("              return '';");
            js.AppendLine("            }");
            js.AppendLine("          }");
            js.AppendLine("        }");
            js.AppendLine("      },");
            js.AppendLine("      scales: {");
            js.AppendLine("        x: {");
            js.AppendLine("          type: 'linear',");
            js.AppendLine("          title: {");
            js.AppendLine("            display: true,");
            js.AppendLine("            text: 'Time (ms)'");
            js.AppendLine("          }");
            js.AppendLine("        },");
            js.AppendLine("        y: {");
            js.AppendLine("          title: {");
            js.AppendLine("            display: true,");
            js.AppendLine("            text: 'Angle (degrees)'");
            js.AppendLine("          }");
            js.AppendLine("        }");
            js.AppendLine("      }");
            js.AppendLine("    }");
            js.AppendLine("  });");
            js.AppendLine("  ");
            js.AppendLine("  // Create velocity chart");
            js.AppendLine("  const velocityCtx = document.getElementById('velocityChart').getContext('2d');");
            js.AppendLine("  new Chart(velocityCtx, {");
            js.AppendLine("    type: 'line',");
            js.AppendLine("    data: {");
            js.AppendLine("      datasets: [");
            js.AppendLine("        {");
            js.AppendLine("          label: 'Angular Velocity',");
            js.AppendLine("          data: aimData.map(d => ({x: d.timestamp, y: d.totalVelocity * 1000})), // Convert to degrees per second");
            js.AppendLine("          borderColor: 'rgb(255, 159, 64)',");
            js.AppendLine("          backgroundColor: 'rgba(255, 159, 64, 0.2)',");
            js.AppendLine("          fill: true,");
            js.AppendLine("          pointRadius: 0,");
            js.AppendLine("          borderWidth: 1");
            js.AppendLine("        },");
            js.AppendLine("        {");
            js.AppendLine("          label: 'Evidence Markers',");
            js.AppendLine("          data: evidenceMarkers.map(m => {");
            js.AppendLine("            const nearestAim = aimData.reduce((prev, curr) => {");
            js.AppendLine("              return Math.abs(curr.timestamp - m.timestamp) < Math.abs(prev.timestamp - m.timestamp) ? curr : prev;");
            js.AppendLine("            }, aimData[0]);");
            js.AppendLine("            return {x: m.timestamp, y: nearestAim.totalVelocity * 1000, severity: m.severity, rule: m.rule, description: m.description};");
            js.AppendLine("          }),");
            js.AppendLine("          backgroundColor: context => {");
            js.AppendLine("            const value = context.raw.severity;");
            js.AppendLine("            return value < 0.4 ? 'rgba(75, 192, 192, 0.8)' : (value < 0.7 ? 'rgba(255, 205, 86, 0.8)' : 'rgba(255, 99, 132, 0.8)');");
            js.AppendLine("          },");
            js.AppendLine("          pointRadius: 6,");
            js.AppendLine("          showLine: false");
            js.AppendLine("        }");
            js.AppendLine("      ]");
            js.AppendLine("    },");
            js.AppendLine("    options: {");
            js.AppendLine("      responsive: true,");
            js.AppendLine("      maintainAspectRatio: false,");
            js.AppendLine("      plugins: {");
            js.AppendLine("        title: {");
            js.AppendLine("          display: true,");
            js.AppendLine("          text: 'Angular Velocity Over Time'");
            js.AppendLine("        },");
            js.AppendLine("        tooltip: {");
            js.AppendLine("          callbacks: {");
            js.AppendLine("            label: function(context) {");
            js.AppendLine("              if (context.datasetIndex === 1) {");
            js.AppendLine("                return [");
            js.AppendLine("                  `Rule: ${context.raw.rule}`,");
            js.AppendLine("                  `Description: ${context.raw.description}`,");
            js.AppendLine("                  `Severity: ${(context.raw.severity * 100).toFixed(1)}%`");
            js.AppendLine("                ];");
            js.AppendLine("              }");
            js.AppendLine("              return `${context.dataset.label}: ${context.parsed.y.toFixed(2)} deg/s`;");
            js.AppendLine("            }");
            js.AppendLine("          }");
            js.AppendLine("        }");
            js.AppendLine("      },");
            js.AppendLine("      scales: {");
            js.AppendLine("        x: {");
            js.AppendLine("          type: 'linear',");
            js.AppendLine("          title: {");
            js.AppendLine("            display: true,");
            js.AppendLine("            text: 'Time (ms)'");
            js.AppendLine("          }");
            js.AppendLine("        },");
            js.AppendLine("        y: {");
            js.AppendLine("          title: {");
            js.AppendLine("            display: true,");
            js.AppendLine("            text: 'Angular Velocity (deg/s)'");
            js.AppendLine("          }");
            js.AppendLine("        }");
            js.AppendLine("      }");
            js.AppendLine("    }");
            js.AppendLine("  });");
            js.AppendLine("  ");
            js.AppendLine("  // Create team comparison chart if team data is available");
            js.AppendLine("  if (hasTeamData && document.getElementById('teamComparisonChart')) {");
            js.AppendLine("    const teamCtx = document.getElementById('teamComparisonChart').getContext('2d');");
            js.AppendLine("    ");
            js.AppendLine("    // Get metrics to compare");
            js.AppendLine("    const metrics = [");
            js.AppendLine("      { key: 'averageTargetingAccuracy', label: 'Targeting Accuracy', format: 'percent' },");
            js.AppendLine("      { key: 'averageReactionTime', label: 'Reaction Time', format: 'number', inverted: true },");
            js.AppendLine("      { key: 'angularVelocityVariability', label: 'Aim Variability', format: 'number' },");
            js.AppendLine("      { key: 'averageMicroAdjustment', label: 'Micro-Adjustments', format: 'number' },");
            js.AppendLine("      { key: 'maxTargetSwitchSpeed', label: 'Switch Speed', format: 'number' }");
            js.AppendLine("    ];");
            js.AppendLine("    ");
            js.AppendLine("    // Normalize values against team average (1.0 = team average)");
            js.AppendLine("    const normalizedData = metrics.map(metric => {");
            js.AppendLine("      const playerValue = playerData.statistics[metric.key];");
            js.AppendLine("      const teamValue = playerData.teamAverages[metric.key];");
            js.AppendLine("      ");
            js.AppendLine("      // Handle metrics where lower is better (like reaction time)");
            js.AppendLine("      if (metric.inverted && teamValue > 0) {");
            js.AppendLine("        return { metric: metric.label, value: teamValue / playerValue };");
            js.AppendLine("      } else if (teamValue > 0) {");
            js.AppendLine("        return { metric: metric.label, value: playerValue / teamValue };");
            js.AppendLine("      }");
            js.AppendLine("      return { metric: metric.label, value: 1 }; // Default to 1.0 (team average)");
            js.AppendLine("    });");
            js.AppendLine("    ");
            js.AppendLine("    new Chart(teamCtx, {");
            js.AppendLine("      type: 'radar',");
            js.AppendLine("      data: {");
            js.AppendLine("        labels: normalizedData.map(d => d.metric),");
            js.AppendLine("        datasets: [{");
            js.AppendLine("          label: 'Player vs. Team Average',");
            js.AppendLine("          data: normalizedData.map(d => d.value),");
            js.AppendLine("          backgroundColor: 'rgba(54, 162, 235, 0.2)',");
            js.AppendLine("          borderColor: 'rgb(54, 162, 235)',");
            js.AppendLine("          pointBackgroundColor: 'rgb(54, 162, 235)',");
            js.AppendLine("          pointBorderColor: '#fff',");
            js.AppendLine("          pointHoverBackgroundColor: '#fff',");
            js.AppendLine("          pointHoverBorderColor: 'rgb(54, 162, 235)'");
            js.AppendLine("        }, {");
            js.AppendLine("          label: 'Team Average',");
            js.AppendLine("          data: [1, 1, 1, 1, 1], // By definition, team average = 1.0");
            js.AppendLine("          backgroundColor: 'rgba(255, 99, 132, 0.2)',");
            js.AppendLine("          borderColor: 'rgb(255, 99, 132)',");
            js.AppendLine("          borderDash: [5, 5],");
            js.AppendLine("          pointBackgroundColor: 'rgba(255, 99, 132, 0)',");
            js.AppendLine("          pointBorderColor: 'rgba(255, 99, 132, 0)',");
            js.AppendLine("          pointHoverBackgroundColor: 'rgba(255, 99, 132, 0)',");
            js.AppendLine("          pointHoverBorderColor: 'rgba(255, 99, 132, 0)'");
            js.AppendLine("        }]");
            js.AppendLine("      },");
            js.AppendLine("      options: {");
            js.AppendLine("        responsive: true,");
            js.AppendLine("        maintainAspectRatio: false,");
            js.AppendLine("        scales: {");
            js.AppendLine("          r: {");
            js.AppendLine("            beginAtZero: false,");
            js.AppendLine("            min: 0,");
            js.AppendLine("            max: Math.max(2, ...normalizedData.map(d => d.value))");
            js.AppendLine("          }");
            js.AppendLine("        },");
            js.AppendLine("        plugins: {");
            js.AppendLine("          title: {");
            js.AppendLine("            display: true,");
            js.AppendLine("            text: 'Player Performance Relative to Team Average'");
            js.AppendLine("          },");
            js.AppendLine("          tooltip: {");
            js.AppendLine("            callbacks: {");
            js.AppendLine("              label: function(context) {");
            js.AppendLine("                const value = context.raw;");
            js.AppendLine("                const metric = metrics[context.dataIndex];");
            js.AppendLine("                ");
            js.AppendLine("                if (context.datasetIndex === 0) {");
            js.AppendLine("                  const playerValue = playerData.statistics[metric.key];");
            js.AppendLine("                  const teamValue = playerData.teamAverages[metric.key];");
            js.AppendLine("                  ");
            js.AppendLine("                  let formattedPlayer, formattedTeam;");
            js.AppendLine("                  if (metric.format === 'percent') {");
            js.AppendLine("                    formattedPlayer = `${(playerValue * 100).toFixed(1)}%`;");
            js.AppendLine("                    formattedTeam = `${(teamValue * 100).toFixed(1)}%`;");
            js.AppendLine("                  } else {");
            js.AppendLine("                    formattedPlayer = playerValue.toFixed(3);");
            js.AppendLine("                    formattedTeam = teamValue.toFixed(3);");
            js.AppendLine("                  }");
            js.AppendLine("                  ");
            js.AppendLine("                  return [`Player: ${formattedPlayer}`, `Team Avg: ${formattedTeam}`, `Ratio: ${value.toFixed(2)}x`];");
            js.AppendLine("                }");
            js.AppendLine("                return `Team Average: 1.0`;");
            js.AppendLine("              }");
            js.AppendLine("            }");
            js.AppendLine("          }");
            js.AppendLine("        }");
            js.AppendLine("      }");
            js.AppendLine("    });");
            js.AppendLine("  }");
            js.AppendLine("}");
            js.AppendLine("");
            js.AppendLine("// Helper function to format timestamp");
            js.AppendLine("function formatTimestamp(timestamp) {");
            js.AppendLine("  const seconds = Math.floor(timestamp / 1000);");
            js.AppendLine("  const minutes = Math.floor(seconds / 60);");
            js.AppendLine("  const remainingSeconds = seconds % 60;");
            js.AppendLine("  const milliseconds = timestamp % 1000;");
            js.AppendLine("  ");
            js.AppendLine("  return `${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}.${milliseconds.toString().padStart(3, '0')}`;");
            js.AppendLine("}");

            File.WriteAllText(outputPath, js.ToString());
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

        private string SanitizeId(string input)
        {
            // Remove any characters that aren't valid in HTML ids
            return new string(input.Where(c => char.IsLetterOrDigit(c) || c == '-' || c == '_').ToArray());
        }

        private string FormatTimestamp(int timestamp)
        {
            int seconds = timestamp / 1000;
            int minutes = seconds / 60;
            seconds %= 60;
            int milliseconds = timestamp % 1000;

            return $"{minutes:D2}:{seconds:D2}.{milliseconds:D3}";
        }

        private string GetProgressBarClass(float value)
        {
            if (value < 0.4f)
                return "bg-success";
            else if (value < 0.7f)
                return "bg-warning";
            else
                return "bg-danger";
        }
    }
}