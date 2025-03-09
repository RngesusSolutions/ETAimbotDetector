using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using AimbotDetector.AimAnalyzer;
using AimbotDetector.DemoParser;

namespace AimbotDetector.Visualization
{
    public class ResultVisualizer
    {
        // Updated method signature to work with raw AimData instead of requiring full PlayerData object
        // This allows it to work with both original method calls and the enhanced version
        public void GenerateVisualization(List<AimData> aimData, List<DetectionResult> detectionResults, string outputPath)
        {
            // Skip if no aim data or detection results
            if (aimData.Count == 0 || detectionResults.Count == 0)
            {
                Console.WriteLine($"Skipping visualization - insufficient data");
                return;
            }

            try
            {
                var html = new StringBuilder();
                html.AppendLine("<!DOCTYPE html>");
                html.AppendLine("<html lang=\"en\">");
                html.AppendLine("<head>");
                html.AppendLine("  <meta charset=\"UTF-8\">");
                html.AppendLine("  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">");
                html.AppendLine("  <title>Aimbot Detection Analysis</title>");
                html.AppendLine("  <script src=\"https://cdn.jsdelivr.net/npm/chart.js\"></script>");
                html.AppendLine("  <script src=\"https://cdn.jsdelivr.net/npm/moment\"></script>");
                html.AppendLine("  <style>");
                html.AppendLine("    body { font-family: Arial, sans-serif; margin: 20px; }");
                html.AppendLine("    .container { max-width: 1200px; margin: 0 auto; }");
                html.AppendLine("    .header { text-align: center; margin-bottom: 30px; }");
                html.AppendLine("    .chart-container { height: 400px; margin-bottom: 40px; }");
                html.AppendLine("    .metric-card { border: 1px solid #ddd; border-radius: 5px; padding: 15px; margin-bottom: 20px; }");
                html.AppendLine("    .metric-title { font-weight: bold; margin-bottom: 10px; }");
                html.AppendLine("    .metric-value { font-size: 24px; margin-bottom: 10px; }");
                html.AppendLine("    .evidence-list { margin-top: 20px; }");
                html.AppendLine("    .evidence-item { border-left: 3px solid #f44336; padding-left: 10px; margin-bottom: 10px; }");
                html.AppendLine("    .low { color: green; }");
                html.AppendLine("    .medium { color: orange; }");
                html.AppendLine("    .high { color: red; }");
                html.AppendLine("    .flex-container { display: flex; flex-wrap: wrap; }");
                html.AppendLine("    .flex-container > div { flex: 1; min-width: 300px; margin: 10px; }");
                html.AppendLine("    .target-highlight { background-color: rgba(255, 0, 0, 0.1); }");
                html.AppendLine("  </style>");
                html.AppendLine("</head>");
                html.AppendLine("<body>");
                html.AppendLine("  <div class=\"container\">");
                html.AppendLine("    <div class=\"header\">");
                html.AppendLine("      <h1>Aimbot Detection Analysis</h1>");
                html.AppendLine($"      <p>Analysis performed on {DateTime.Now}</p>");
                html.AppendLine("    </div>");

                // Overall cheat probability
                float overallProbability = CalculateOverallProbability(detectionResults);
                string probabilityClass = overallProbability < 0.4 ? "low" : (overallProbability < 0.7 ? "medium" : "high");
                string statusText = overallProbability >= 0.7 ? "SUSPICIOUS" : "CLEAN";

                html.AppendLine("    <div class=\"metric-card\">");
                html.AppendLine("      <div class=\"metric-title\">Overall Cheating Probability</div>");
                html.AppendLine($"      <div class=\"metric-value {probabilityClass}\">{overallProbability:P1}</div>");
                html.AppendLine($"      <div>Verdict: <strong>{statusText}</strong></div>");
                html.AppendLine("    </div>");

                // Main visuals - aim angles over time
                html.AppendLine("    <div class=\"chart-container\">");
                html.AppendLine("      <canvas id=\"angleChart\"></canvas>");
                html.AppendLine("    </div>");

                // Angular velocity chart
                html.AppendLine("    <div class=\"chart-container\">");
                html.AppendLine("      <canvas id=\"velocityChart\"></canvas>");
                html.AppendLine("    </div>");

                // NEW: Add enemy targeting visualization if data is available
                bool hasEnemyData = aimData.Any(d => d.HasVisibleEnemy);
                if (hasEnemyData)
                {
                    html.AppendLine("    <div class=\"chart-container\">");
                    html.AppendLine("      <canvas id=\"targetingChart\"></canvas>");
                    html.AppendLine("    </div>");
                }

                // Detection metrics visualization
                html.AppendLine("    <h2>Detection Metrics</h2>");
                html.AppendLine("    <div class=\"flex-container\">");

                foreach (var result in detectionResults.OrderByDescending(r => r.ConfidenceLevel))
                {
                    string ruleClass = result.ConfidenceLevel < 0.4 ? "low" : (result.ConfidenceLevel < 0.7 ? "medium" : "high");

                    html.AppendLine("      <div class=\"metric-card\">");
                    html.AppendLine($"        <div class=\"metric-title\">{result.RuleName}</div>");
                    html.AppendLine($"        <div class=\"metric-value {ruleClass}\">{result.ConfidenceLevel:P1}</div>");
                    html.AppendLine($"        <div>{result.Description}</div>");

                    // Add evidence if available
                    if (result.Evidence.Count > 0)
                    {
                        html.AppendLine("        <div class=\"evidence-list\">");
                        html.AppendLine("          <h4>Key Evidence:</h4>");

                        foreach (var evidence in result.Evidence.OrderByDescending(e => e.Severity).Take(5))
                        {
                            html.AppendLine("          <div class=\"evidence-item\">");
                            html.AppendLine($"            <div>Timestamp: {FormatTimestamp(evidence.Timestamp)}</div>");
                            html.AppendLine($"            <div>{evidence.Description}</div>");
                            html.AppendLine($"            <div>Severity: {evidence.Severity:P1}</div>");
                            html.AppendLine("          </div>");
                        }

                        if (result.Evidence.Count > 5)
                        {
                            html.AppendLine($"        <div>And {result.Evidence.Count - 5} more evidence points...</div>");
                        }

                        html.AppendLine("        </div>");
                    }

                    html.AppendLine("      </div>");
                }

                html.AppendLine("    </div>");

                // Add JavaScript for charts
                html.AppendLine("    <script>");
                html.AppendLine("      // Prepare aim data");
                html.AppendLine("      const aimData = [");

                // Format aim data for the chart
                foreach (var data in aimData)
                {
                    // Include new enemy tracking data if available
                    html.AppendLine($"        {{x: {data.Timestamp}, pitch: {data.ViewAngles.X}, yaw: {data.ViewAngles.Y}, firing: {data.IsFiring.ToString().ToLower()}, " +
                                    $"hasEnemy: {data.HasVisibleEnemy.ToString().ToLower()}, " +
                                    $"angleToTarget: {(data.HasVisibleEnemy ? data.AngleToTarget.ToString() : "null")}}},");
                }

                html.AppendLine("      ];");

                // Add evidence markers
                html.AppendLine("      const evidenceMarkers = [");

                foreach (var result in detectionResults)
                {
                    foreach (var evidence in result.Evidence)
                    {
                        html.AppendLine($"        {{x: {evidence.Timestamp}, rule: \"{result.RuleName}\", description: \"{evidence.Description.Replace("\"", "\\\"")}\", severity: {evidence.Severity}}},");
                    }
                }

                html.AppendLine("      ];");

                // Calculate angular velocities
                html.AppendLine("      // Calculate angular velocities");
                html.AppendLine("      const velocityData = [];");
                html.AppendLine("      for (let i = 1; i < aimData.length; i++) {");
                html.AppendLine("        const current = aimData[i];");
                html.AppendLine("        const prev = aimData[i-1];");
                html.AppendLine("        const timeDelta = current.x - prev.x;");
                html.AppendLine("        if (timeDelta <= 0) continue;");
                html.AppendLine("        ");
                html.AppendLine("        let pitchDelta = Math.abs(current.pitch - prev.pitch);");
                html.AppendLine("        let yawDelta = Math.abs(current.yaw - prev.yaw);");
                html.AppendLine("        ");
                html.AppendLine("        // Normalize angles");
                html.AppendLine("        if (pitchDelta > 180) pitchDelta = 360 - pitchDelta;");
                html.AppendLine("        if (yawDelta > 180) yawDelta = 360 - yawDelta;");
                html.AppendLine("        ");
                html.AppendLine("        const pitchVelocity = pitchDelta / timeDelta;");
                html.AppendLine("        const yawVelocity = yawDelta / timeDelta;");
                html.AppendLine("        const totalVelocity = Math.sqrt(pitchVelocity * pitchVelocity + yawVelocity * yawVelocity);");
                html.AppendLine("        ");
                html.AppendLine("        velocityData.push({x: current.x, velocity: totalVelocity * 1000}); // Convert to degrees per second");
                html.AppendLine("      }");
                html.AppendLine("      ");

                // Create angle chart
                html.AppendLine("      // Create angle chart");
                html.AppendLine("      const angleCtx = document.getElementById('angleChart').getContext('2d');");
                html.AppendLine("      const angleChart = new Chart(angleCtx, {");
                html.AppendLine("        type: 'line',");
                html.AppendLine("        data: {");
                html.AppendLine("          datasets: [");
                html.AppendLine("            {");
                html.AppendLine("              label: 'Pitch',");
                html.AppendLine("              data: aimData.map(d => ({x: d.x, y: d.pitch})),");
                html.AppendLine("              borderColor: 'rgb(75, 192, 192)',");
                html.AppendLine("              pointRadius: 0,");
                html.AppendLine("              borderWidth: 1,");
                html.AppendLine("              tension: 0.1");
                html.AppendLine("            },");
                html.AppendLine("            {");
                html.AppendLine("              label: 'Yaw',");
                html.AppendLine("              data: aimData.map(d => ({x: d.x, y: d.yaw})),");
                html.AppendLine("              borderColor: 'rgb(153, 102, 255)',");
                html.AppendLine("              pointRadius: 0,");
                html.AppendLine("              borderWidth: 1,");
                html.AppendLine("              tension: 0.1");
                html.AppendLine("            },");
                html.AppendLine("            {");
                html.AppendLine("              label: 'Firing',");
                html.AppendLine("              data: aimData.filter(d => d.firing).map(d => ({x: d.x, y: d.pitch})),");
                html.AppendLine("              backgroundColor: 'rgba(255, 99, 132, 0.5)',");
                html.AppendLine("              pointRadius: 3,");
                html.AppendLine("              showLine: false");
                html.AppendLine("            },");

                // NEW: Add enemy visibility markers
                if (hasEnemyData)
                {
                    html.AppendLine("            {");
                    html.AppendLine("              label: 'Enemy Visible',");
                    html.AppendLine("              data: aimData.filter(d => d.hasEnemy).map(d => ({x: d.x, y: d.pitch, angle: d.angleToTarget})),");
                    html.AppendLine("              backgroundColor: 'rgba(75, 192, 75, 0.5)',");
                    html.AppendLine("              pointRadius: 2,");
                    html.AppendLine("              pointStyle: 'rect',");
                    html.AppendLine("              showLine: false");
                    html.AppendLine("            },");
                }

                html.AppendLine("            {");
                html.AppendLine("              label: 'Evidence',");
                html.AppendLine("              data: evidenceMarkers.map(m => {");
                html.AppendLine("                const nearestAimIndex = aimData.findIndex(d => d.x >= m.x);");
                html.AppendLine("                const nearestAim = nearestAimIndex >= 0 ? aimData[nearestAimIndex] : aimData[aimData.length - 1];");
                html.AppendLine("                return {x: m.x, y: nearestAim.pitch, rule: m.rule, description: m.description, severity: m.severity};");
                html.AppendLine("              }),");
                html.AppendLine("              backgroundColor: 'rgba(255, 0, 0, 0.7)',");
                html.AppendLine("              pointRadius: 4,");
                html.AppendLine("              pointStyle: 'triangle',");
                html.AppendLine("              showLine: false");
                html.AppendLine("            }");
                html.AppendLine("          ]");
                html.AppendLine("        },");
                html.AppendLine("        options: {");
                html.AppendLine("          responsive: true,");
                html.AppendLine("          maintainAspectRatio: false,");
                html.AppendLine("          plugins: {");
                html.AppendLine("            title: {");
                html.AppendLine("              display: true,");
                html.AppendLine("              text: 'View Angles Over Time'");
                html.AppendLine("            },");
                html.AppendLine("            tooltip: {");
                html.AppendLine("              callbacks: {");
                html.AppendLine("                afterBody: function(context) {");

                // Enhanced tooltip with enemy information
                if (hasEnemyData)
                {
                    html.AppendLine("                  if (context[0].datasetIndex === 3) {"); // Enemy data
                    html.AppendLine("                    return `Angle to enemy: ${context[0].raw.angle.toFixed(2)}°`;");
                    html.AppendLine("                  }");
                }

                html.AppendLine("                  if (context[0].datasetIndex === " + (hasEnemyData ? "4" : "3") + ") {"); // Evidence markers
                html.AppendLine("                    const marker = evidenceMarkers.find(m => m.x === context[0].raw.x);");
                html.AppendLine("                    return [");
                html.AppendLine("                      `Rule: ${marker.rule}`,");
                html.AppendLine("                      `Description: ${marker.description}`,");
                html.AppendLine("                      `Severity: ${(marker.severity * 100).toFixed(1)}%`");
                html.AppendLine("                    ];");
                html.AppendLine("                  }");
                html.AppendLine("                  return '';");
                html.AppendLine("                }");
                html.AppendLine("              }");
                html.AppendLine("            }");
                html.AppendLine("          },");
                html.AppendLine("          scales: {");
                html.AppendLine("            x: {");
                html.AppendLine("              type: 'linear',");
                html.AppendLine("              title: {");
                html.AppendLine("                display: true,");
                html.AppendLine("                text: 'Time (ms)'");
                html.AppendLine("              }");
                html.AppendLine("            },");
                html.AppendLine("            y: {");
                html.AppendLine("              title: {");
                html.AppendLine("                display: true,");
                html.AppendLine("                text: 'Angle (degrees)'");
                html.AppendLine("              }");
                html.AppendLine("            }");
                html.AppendLine("          }");
                html.AppendLine("        }");
                html.AppendLine("      });");
                html.AppendLine("      ");

                // Create velocity chart
                html.AppendLine("      // Create velocity chart");
                html.AppendLine("      const velocityCtx = document.getElementById('velocityChart').getContext('2d');");
                html.AppendLine("      const velocityChart = new Chart(velocityCtx, {");
                html.AppendLine("        type: 'line',");
                html.AppendLine("        data: {");
                html.AppendLine("          datasets: [");
                html.AppendLine("            {");
                html.AppendLine("              label: 'Angular Velocity',");
                html.AppendLine("              data: velocityData.map(d => ({x: d.x, y: d.velocity})),");
                html.AppendLine("              borderColor: 'rgb(255, 159, 64)',");
                html.AppendLine("              backgroundColor: 'rgba(255, 159, 64, 0.2)',");
                html.AppendLine("              fill: true,");
                html.AppendLine("              pointRadius: 0,");
                html.AppendLine("              borderWidth: 1");
                html.AppendLine("            },");
                html.AppendLine("            {");
                html.AppendLine("              label: 'Evidence Markers',");
                html.AppendLine("              data: evidenceMarkers.map(m => {");
                html.AppendLine("                const nearestVelocityIndex = velocityData.findIndex(d => d.x >= m.x);");
                html.AppendLine("                const nearestVelocity = nearestVelocityIndex >= 0 ? velocityData[nearestVelocityIndex] : velocityData[velocityData.length - 1];");
                html.AppendLine("                return {x: m.x, y: nearestVelocity.velocity, severity: m.severity, rule: m.rule, description: m.description};");
                html.AppendLine("              }),");
                html.AppendLine("              backgroundColor: context => {");
                html.AppendLine("                const value = context.raw.severity;");
                html.AppendLine("                return value < 0.4 ? 'rgba(75, 192, 192, 0.8)' : (value < 0.7 ? 'rgba(255, 205, 86, 0.8)' : 'rgba(255, 99, 132, 0.8)');");
                html.AppendLine("              },");
                html.AppendLine("              pointRadius: 5,");
                html.AppendLine("              showLine: false");
                html.AppendLine("            }");
                html.AppendLine("          ]");
                html.AppendLine("        },");
                html.AppendLine("        options: {");
                html.AppendLine("          responsive: true,");
                html.AppendLine("          maintainAspectRatio: false,");
                html.AppendLine("          plugins: {");
                html.AppendLine("            title: {");
                html.AppendLine("              display: true,");
                html.AppendLine("              text: 'Angular Velocity Over Time'");
                html.AppendLine("            },");
                html.AppendLine("            tooltip: {");
                html.AppendLine("              callbacks: {");
                html.AppendLine("                label: function(context) {");
                html.AppendLine("                  if (context.datasetIndex === 1) {");
                html.AppendLine("                    return [");
                html.AppendLine("                      `Rule: ${context.raw.rule}`,");
                html.AppendLine("                      `Description: ${context.raw.description}`,");
                html.AppendLine("                      `Severity: ${(context.raw.severity * 100).toFixed(1)}%`");
                html.AppendLine("                    ];");
                html.AppendLine("                  }");
                html.AppendLine("                  return `${context.dataset.label}: ${context.parsed.y.toFixed(2)} deg/s`;");
                html.AppendLine("                }");
                html.AppendLine("              }");
                html.AppendLine("            }");
                html.AppendLine("          },");
                html.AppendLine("          scales: {");
                html.AppendLine("            x: {");
                html.AppendLine("              type: 'linear',");
                html.AppendLine("              title: {");
                html.AppendLine("                display: true,");
                html.AppendLine("                text: 'Time (ms)'");
                html.AppendLine("              }");
                html.AppendLine("            },");
                html.AppendLine("            y: {");
                html.AppendLine("              title: {");
                html.AppendLine("                display: true,");
                html.AppendLine("                text: 'Angular Velocity (deg/s)'");
                html.AppendLine("              }");
                html.AppendLine("            }");
                html.AppendLine("          }");
                html.AppendLine("        }");
                html.AppendLine("      });");

                // NEW: Add targeting accuracy chart if enemy data is available
                if (hasEnemyData)
                {
                    html.AppendLine("      // Create targeting accuracy chart");
                    html.AppendLine("      const targetingCtx = document.getElementById('targetingChart').getContext('2d');");
                    html.AppendLine("      const targetingChart = new Chart(targetingCtx, {");
                    html.AppendLine("        type: 'scatter',");
                    html.AppendLine("        data: {");
                    html.AppendLine("          datasets: [");
                    html.AppendLine("            {");
                    html.AppendLine("              label: 'Angle to Target',");
                    html.AppendLine("              data: aimData.filter(d => d.hasEnemy).map(d => ({x: d.x, y: d.angleToTarget})),");
                    html.AppendLine("              backgroundColor: d => d.raw.y < 3 ? 'rgba(75, 192, 75, 0.7)' : 'rgba(255, 159, 64, 0.7)',");
                    html.AppendLine("              pointRadius: 3,");
                    html.AppendLine("              pointStyle: 'circle'");
                    html.AppendLine("            },");
                    html.AppendLine("            {");
                    html.AppendLine("              label: 'Firing at Enemy',");
                    html.AppendLine("              data: aimData.filter(d => d.hasEnemy && d.firing).map(d => ({x: d.x, y: d.angleToTarget})),");
                    html.AppendLine("              backgroundColor: d => d.raw.y < 3 ? 'rgba(0, 255, 0, 0.7)' : 'rgba(255, 0, 0, 0.7)',");
                    html.AppendLine("              pointRadius: 5,");
                    html.AppendLine("              pointStyle: 'star'");
                    html.AppendLine("            },");
                    html.AppendLine("            {");
                    html.AppendLine("              label: 'Perfect Aim Threshold',");
                    html.AppendLine("              data: [{x: aimData[0].x, y: 3}, {x: aimData[aimData.length-1].x, y: 3}],");
                    html.AppendLine("              borderColor: 'rgba(255, 0, 0, 0.5)',");
                    html.AppendLine("              borderDash: [5, 5],");
                    html.AppendLine("              borderWidth: 2,");
                    html.AppendLine("              pointRadius: 0");
                    html.AppendLine("            }");
                    html.AppendLine("          ]");
                    html.AppendLine("        },");
                    html.AppendLine("        options: {");
                    html.AppendLine("          responsive: true,");
                    html.AppendLine("          maintainAspectRatio: false,");
                    html.AppendLine("          plugins: {");
                    html.AppendLine("            title: {");
                    html.AppendLine("              display: true,");
                    html.AppendLine("              text: 'Targeting Accuracy (Angle to Enemy)'");
                    html.AppendLine("            }");
                    html.AppendLine("          },");
                    html.AppendLine("          scales: {");
                    html.AppendLine("            x: {");
                    html.AppendLine("              type: 'linear',");
                    html.AppendLine("              title: {");
                    html.AppendLine("                display: true,");
                    html.AppendLine("                text: 'Time (ms)'");
                    html.AppendLine("              }");
                    html.AppendLine("            },");
                    html.AppendLine("            y: {");
                    html.AppendLine("              title: {");
                    html.AppendLine("                display: true,");
                    html.AppendLine("                text: 'Angle to Target (degrees)'");
                    html.AppendLine("              },");
                    html.AppendLine("              min: 0,");
                    html.AppendLine("              max: Math.min(20, Math.max(...aimData.filter(d => d.hasEnemy).map(d => d.angleToTarget)) * 1.2)");
                    html.AppendLine("            }");
                    html.AppendLine("          }");
                    html.AppendLine("        }");
                    html.AppendLine("      });");
                }

                html.AppendLine("    </script>");
                html.AppendLine("  </div>");
                html.AppendLine("</body>");
                html.AppendLine("</html>");

                // Write the HTML to the output file
                File.WriteAllText(outputPath, html.ToString());
                Console.WriteLine($"Visualization generated at {outputPath}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error generating visualization: {ex.Message}");
            }
        }

        // Original method signature for backward compatibility
        public void GenerateVisualization(PlayerData player, List<DetectionResult> detectionResults, string outputPath)
        {
            // Call the enhanced version with the player's aim data
            GenerateVisualization(player.AimData, detectionResults, outputPath);
        }

        public void GenerateSummaryVisualization(Dictionary<string, AnalysisResult> results, string outputPath)
        {
            try
            {
                var html = new StringBuilder();
                html.AppendLine("<!DOCTYPE html>");
                html.AppendLine("<html lang=\"en\">");
                html.AppendLine("<head>");
                html.AppendLine("  <meta charset=\"UTF-8\">");
                html.AppendLine("  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">");
                html.AppendLine("  <title>Aimbot Detection Summary</title>");
                html.AppendLine("  <script src=\"https://cdn.jsdelivr.net/npm/chart.js\"></script>");
                html.AppendLine("  <style>");
                html.AppendLine("    body { font-family: Arial, sans-serif; margin: 20px; }");
                html.AppendLine("    .container { max-width: 1200px; margin: 0 auto; }");
                html.AppendLine("    .header { text-align: center; margin-bottom: 30px; }");
                html.AppendLine("    .chart-container { height: 400px; margin-bottom: 40px; }");
                html.AppendLine("    table { width: 100%; border-collapse: collapse; margin-top: 20px; }");
                html.AppendLine("    th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }");
                html.AppendLine("    th { background-color: #f2f2f2; }");
                html.AppendLine("    tr:hover { background-color: #f5f5f5; }");
                html.AppendLine("    .low { color: green; }");
                html.AppendLine("    .medium { color: orange; }");
                html.AppendLine("    .high { color: red; }");
                html.AppendLine("    .badge { padding: 5px 10px; border-radius: 10px; color: white; font-weight: bold; }");
                html.AppendLine("    .badge-clean { background-color: green; }");
                html.AppendLine("    .badge-suspicious { background-color: red; }");
                html.AppendLine("  </style>");
                html.AppendLine("</head>");
                html.AppendLine("<body>");
                html.AppendLine("  <div class=\"container\">");
                html.AppendLine("    <div class=\"header\">");
                html.AppendLine("      <h1>Aimbot Detection Summary</h1>");
                html.AppendLine($"      <p>Analysis performed on {DateTime.Now}</p>");
                html.AppendLine($"      <p>Total players analyzed: {results.Count}</p>");
                html.AppendLine($"      <p>Suspicious players: {results.Values.Count(r => r.IsCheating)}</p>");
                html.AppendLine("    </div>");

                // Probability distribution chart
                html.AppendLine("    <div class=\"chart-container\">");
                html.AppendLine("      <canvas id=\"distributionChart\"></canvas>");
                html.AppendLine("    </div>");

                // Detection rules effectiveness chart
                html.AppendLine("    <div class=\"chart-container\">");
                html.AppendLine("      <canvas id=\"rulesChart\"></canvas>");
                html.AppendLine("    </div>");

                // NEW: Team comparison chart (if data available)
                bool hasTeamData = results.Values.Any(r => r.PlayerStatistics?.TeamAverages != null);
                if (hasTeamData)
                {
                    html.AppendLine("    <div class=\"chart-container\">");
                    html.AppendLine("      <canvas id=\"teamComparisonChart\"></canvas>");
                    html.AppendLine("    </div>");
                }

                // Player summary table
                html.AppendLine("    <h2>Player Summary</h2>");
                html.AppendLine("    <table>");
                html.AppendLine("      <tr>");
                html.AppendLine("        <th>Player</th>");
                html.AppendLine("        <th>ID</th>");
                html.AppendLine("        <th>Cheating Probability</th>");
                html.AppendLine("        <th>Status</th>");
                html.AppendLine("        <th>Top Detection</th>");

                // Add statistics columns if available
                if (results.Values.Any(r => r.PlayerStatistics != null))
                {
                    html.AppendLine("        <th>Avg Targeting</th>");
                    html.AppendLine("        <th>Reaction Time</th>");
                }

                html.AppendLine("      </tr>");

                foreach (var result in results.Values.OrderByDescending(r => r.CheatingProbability))
                {
                    string probabilityClass = result.CheatingProbability < 0.4 ? "low" : (result.CheatingProbability < 0.7 ? "medium" : "high");
                    string statusBadge = result.IsCheating ? "badge-suspicious" : "badge-clean";
                    var topDetection = result.DetectionResults
                        .OrderByDescending(d => d.ConfidenceLevel)
                        .FirstOrDefault();

                    html.AppendLine("      <tr>");
                    html.AppendLine($"        <td>{result.PlayerName}</td>");
                    html.AppendLine($"        <td>{result.PlayerID}</td>");
                    html.AppendLine($"        <td class=\"{probabilityClass}\">{result.CheatingProbability:P1}</td>");
                    html.AppendLine($"        <td><span class=\"badge {statusBadge}\">{(result.IsCheating ? "SUSPICIOUS" : "CLEAN")}</span></td>");
                    html.AppendLine($"        <td>{(topDetection != null ? $"{topDetection.RuleName} ({topDetection.ConfidenceLevel:P1})" : "N/A")}</td>");

                    // Add statistics data if available
                    if (results.Values.Any(r => r.PlayerStatistics != null))
                    {
                        if (result.PlayerStatistics != null)
                        {
                            string targetingClass = result.PlayerStatistics.AverageTargetingAccuracy > 0.8f ? "high" :
                                                  (result.PlayerStatistics.AverageTargetingAccuracy > 0.6f ? "medium" : "low");

                            string reactionClass = result.PlayerStatistics.AverageReactionTime < 170 ? "high" :
                                                (result.PlayerStatistics.AverageReactionTime < 250 ? "medium" : "low");

                            html.AppendLine($"        <td class=\"{targetingClass}\">{result.PlayerStatistics.AverageTargetingAccuracy:P1}</td>");
                            html.AppendLine($"        <td class=\"{reactionClass}\">{result.PlayerStatistics.AverageReactionTime:F0}ms</td>");
                        }
                        else
                        {
                            html.AppendLine("        <td>N/A</td>");
                            html.AppendLine("        <td>N/A</td>");
                        }
                    }

                    html.AppendLine("      </tr>");
                }

                html.AppendLine("    </table>");

                // JavaScript for charts
                html.AppendLine("    <script>");

                // Prepare data for distribution chart
                html.AppendLine("      // Prepare data for distribution chart");
                html.AppendLine("      const playerData = [");

                foreach (var result in results.Values)
                {
                    html.AppendLine($"        {{name: \"{result.PlayerName}\", probability: {result.CheatingProbability}, isCheating: {result.IsCheating.ToString().ToLower()}}},");
                }

                html.AppendLine("      ];");

                // Prepare data for rules effectiveness chart
                html.AppendLine("      // Prepare data for rules effectiveness chart");
                html.AppendLine("      const ruleNames = new Set();");
                html.AppendLine("      const ruleData = {};");
                html.AppendLine("      ");

                foreach (var result in results.Values)
                {
                    foreach (var detection in result.DetectionResults.Where(d => d.ConfidenceLevel > 0))
                    {
                        html.AppendLine($"      if (!ruleNames.has(\"{detection.RuleName}\")) {{");
                        html.AppendLine($"        ruleNames.add(\"{detection.RuleName}\");");
                        html.AppendLine($"        ruleData[\"{detection.RuleName}\"] = [];");
                        html.AppendLine("      }");
                        html.AppendLine($"      ruleData[\"{detection.RuleName}\"].push({{");
                        html.AppendLine($"        player: \"{result.PlayerName}\",");
                        html.AppendLine($"        confidence: {detection.ConfidenceLevel}");
                        html.AppendLine("      });");
                    }
                }

                html.AppendLine("      ");
                html.AppendLine("      const rulesAverages = Array.from(ruleNames).map(rule => {");
                html.AppendLine("        const confidences = ruleData[rule].map(d => d.confidence);");
                html.AppendLine("        const sum = confidences.reduce((a, b) => a + b, 0);");
                html.AppendLine("        const avg = sum / confidences.length;");
                html.AppendLine("        return {rule, average: avg};");
                html.AppendLine("      }).sort((a, b) => b.average - a.average);");
                html.AppendLine("      ");

                // NEW: Prepare team statistics data if available
                if (hasTeamData)
                {
                    html.AppendLine("      // Prepare team comparison data");
                    html.AppendLine("      const teamCompData = [];");

                    foreach (var result in results.Values.Where(r => r.PlayerStatistics?.TeamAverages != null))
                    {
                        html.AppendLine($"      teamCompData.push({{");
                        html.AppendLine($"        name: \"{result.PlayerName}\",");
                        html.AppendLine($"        isCheating: {result.IsCheating.ToString().ToLower()},");
                        html.AppendLine($"        targetingRatio: {result.PlayerStatistics.AverageTargetingAccuracy / Math.Max(0.01, result.PlayerStatistics.TeamAverages.AverageTargetingAccuracy)},");
                        html.AppendLine($"        reactionRatio: {result.PlayerStatistics.TeamAverages.AverageReactionTime / Math.Max(1, result.PlayerStatistics.AverageReactionTime)},");
                        html.AppendLine($"        consistencyRatio: {result.PlayerStatistics.TeamAverages.AngularVelocityVariability / Math.Max(0.01, result.PlayerStatistics.AngularVelocityVariability)}");
                        html.AppendLine("      });");
                    }
                }

                // Create distribution chart
                html.AppendLine("      // Create distribution chart");
                html.AppendLine("      const distCtx = document.getElementById('distributionChart').getContext('2d');");
                html.AppendLine("      new Chart(distCtx, {");
                html.AppendLine("        type: 'bar',");
                html.AppendLine("        data: {");
                html.AppendLine("          labels: playerData.map(p => p.name),");
                html.AppendLine("          datasets: [{");
                html.AppendLine("            label: 'Cheating Probability',");
                html.AppendLine("            data: playerData.map(p => p.probability),");
                html.AppendLine("            backgroundColor: playerData.map(p => p.isCheating ? 'rgba(255, 99, 132, 0.8)' : 'rgba(75, 192, 192, 0.8)'),");
                html.AppendLine("            borderColor: playerData.map(p => p.isCheating ? 'rgb(255, 99, 132)' : 'rgb(75, 192, 192)'),");
                html.AppendLine("            borderWidth: 1");
                html.AppendLine("          }]");
                html.AppendLine("        },");
                html.AppendLine("        options: {");
                html.AppendLine("          responsive: true,");
                html.AppendLine("          maintainAspectRatio: false,");
                html.AppendLine("          plugins: {");
                html.AppendLine("            title: {");
                html.AppendLine("              display: true,");
                html.AppendLine("              text: 'Cheating Probability by Player'");
                html.AppendLine("            },");
                html.AppendLine("            legend: {");
                html.AppendLine("              display: false");
                html.AppendLine("            }");
                html.AppendLine("          },");
                html.AppendLine("          scales: {");
                html.AppendLine("            y: {");
                html.AppendLine("              beginAtZero: true,");
                html.AppendLine("              max: 1,");
                html.AppendLine("              title: {");
                html.AppendLine("                display: true,");
                html.AppendLine("                text: 'Cheating Probability'");
                html.AppendLine("              }");
                html.AppendLine("            }");
                html.AppendLine("          }");
                html.AppendLine("        }");
                html.AppendLine("      });");
                html.AppendLine("      ");

                // Create rules effectiveness chart
                html.AppendLine("      // Create rules effectiveness chart");
                html.AppendLine("      const rulesCtx = document.getElementById('rulesChart').getContext('2d');");
                html.AppendLine("      new Chart(rulesCtx, {");
                html.AppendLine("        type: 'bar',");
                html.AppendLine("        data: {");
                html.AppendLine("          labels: rulesAverages.map(r => r.rule),");
                html.AppendLine("          datasets: [{");
                html.AppendLine("            label: 'Average Confidence',");
                html.AppendLine("            data: rulesAverages.map(r => r.average),");
                html.AppendLine("            backgroundColor: 'rgba(153, 102, 255, 0.8)',");
                html.AppendLine("            borderColor: 'rgb(153, 102, 255)',");
                html.AppendLine("            borderWidth: 1");
                html.AppendLine("          }]");
                html.AppendLine("        },");
                html.AppendLine("        options: {");
                html.AppendLine("          indexAxis: 'y',");
                html.AppendLine("          responsive: true,");
                html.AppendLine("          maintainAspectRatio: false,");
                html.AppendLine("          plugins: {");
                html.AppendLine("            title: {");
                html.AppendLine("              display: true,");
                html.AppendLine("              text: 'Detection Rules Effectiveness'");
                html.AppendLine("            }");
                html.AppendLine("          },");
                html.AppendLine("          scales: {");
                html.AppendLine("            x: {");
                html.AppendLine("              beginAtZero: true,");
                html.AppendLine("              max: 1,");
                html.AppendLine("              title: {");
                html.AppendLine("                display: true,");
                html.AppendLine("                text: 'Average Confidence'");
                html.AppendLine("              }");
                html.AppendLine("            }");
                html.AppendLine("          }");
                html.AppendLine("        }");
                html.AppendLine("      });");

                // NEW: Create team comparison chart if data available
                if (hasTeamData)
                {
                    html.AppendLine("      // Create team comparison chart");
                    html.AppendLine("      const teamCtx = document.getElementById('teamComparisonChart').getContext('2d');");
                    html.AppendLine("      new Chart(teamCtx, {");
                    html.AppendLine("        type: 'bar',");
                    html.AppendLine("        data: {");
                    html.AppendLine("          labels: teamCompData.map(p => p.name),");
                    html.AppendLine("          datasets: [");
                    html.AppendLine("            {");
                    html.AppendLine("              label: 'Targeting Accuracy vs Team',");
                    html.AppendLine("              data: teamCompData.map(p => p.targetingRatio),");
                    html.AppendLine("              backgroundColor: 'rgba(75, 192, 75, 0.7)',");
                    html.AppendLine("              borderColor: 'rgb(75, 192, 75)',");
                    html.AppendLine("              borderWidth: 1");
                    html.AppendLine("            },");
                    html.AppendLine("            {");
                    html.AppendLine("              label: 'Reaction Time vs Team',");
                    html.AppendLine("              data: teamCompData.map(p => p.reactionRatio),");
                    html.AppendLine("              backgroundColor: 'rgba(75, 75, 192, 0.7)',");
                    html.AppendLine("              borderColor: 'rgb(75, 75, 192)',");
                    html.AppendLine("              borderWidth: 1");
                    html.AppendLine("            },");
                    html.AppendLine("            {");
                    html.AppendLine("              label: 'Consistency vs Team',");
                    html.AppendLine("              data: teamCompData.map(p => p.consistencyRatio),");
                    html.AppendLine("              backgroundColor: 'rgba(192, 75, 75, 0.7)',");
                    html.AppendLine("              borderColor: 'rgb(192, 75, 75)',");
                    html.AppendLine("              borderWidth: 1");
                    html.AppendLine("            }");
                    html.AppendLine("          ]");
                    html.AppendLine("        },");
                    html.AppendLine("        options: {");
                    html.AppendLine("          responsive: true,");
                    html.AppendLine("          maintainAspectRatio: false,");
                    html.AppendLine("          plugins: {");
                    html.AppendLine("            title: {");
                    html.AppendLine("              display: true,");
                    html.AppendLine("              text: 'Player Metrics vs Team Average (Higher = More Suspicious)'");
                    html.AppendLine("            },");
                    html.AppendLine("            tooltip: {");
                    html.AppendLine("              callbacks: {");
                    html.AppendLine("                label: function(context) {");
                    html.AppendLine("                  const value = context.raw;");
                    html.AppendLine("                  const metric = context.dataset.label.split(' ')[0];");
                    html.AppendLine("                  return `${metric}: ${value.toFixed(2)}x team average`;");
                    html.AppendLine("                }");
                    html.AppendLine("              }");
                    html.AppendLine("            }");
                    html.AppendLine("          },");
                    html.AppendLine("          scales: {");
                    html.AppendLine("            y: {");
                    html.AppendLine("              beginAtZero: true,");
                    html.AppendLine("              title: {");
                    html.AppendLine("                display: true,");
                    html.AppendLine("                text: 'Ratio to Team Average'");
                    html.AppendLine("              }");
                    html.AppendLine("            }");
                    html.AppendLine("          }");
                    html.AppendLine("        }");
                    html.AppendLine("      });");
                }

                html.AppendLine("    </script>");
                html.AppendLine("  </div>");
                html.AppendLine("</body>");
                html.AppendLine("</html>");

                // Write the HTML to the output file
                File.WriteAllText(outputPath, html.ToString());
                Console.WriteLine($"Summary visualization generated at {outputPath}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error generating summary visualization: {ex.Message}");
            }
        }

        private float CalculateOverallProbability(List<DetectionResult> detectionResults)
        {
            if (detectionResults.Count == 0)
                return 0;

            // Simple average for now, but could be weighted
            return detectionResults.Average(r => r.ConfidenceLevel);
        }

        private string FormatTimestamp(int timestamp)
        {
            int seconds = timestamp / 1000;
            int minutes = seconds / 60;
            seconds %= 60;
            int milliseconds = timestamp % 1000;

            return $"{minutes:D2}:{seconds:D2}.{milliseconds:D3}";
        }
    }
}