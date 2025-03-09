using System;
using System.IO;
using System.Collections.Generic;
using System.Numerics;
using System.Linq;

namespace AimbotDetector.DemoParser
{
    public class DemoFile
    {
        public string FilePath { get; private set; }
        public List<GameEvent> Events { get; private set; }
        public List<PlayerData> Players { get; private set; }
        public List<EntityData> Entities { get; private set; }
        private int _currentTimestamp = 0;
        private readonly Dictionary<int, PlayerPositionHistory> _playerPositions = new();

        // ET demo constants
        private const string DEMO_MAGIC = "ETLDEMO2";
        private const int MAX_PLAYERS = 64;
        private const int MAX_ENTITIES = 1024;
        private const int CS_PLAYERS_START = 544;
        private const int CS_PLAYERS_END = CS_PLAYERS_START + MAX_PLAYERS;

        // ET team constants
        private const int TEAM_AXIS = 1;
        private const int TEAM_ALLIES = 2;
        private const int TEAM_SPECTATOR = 3;

        public DemoFile(string filePath)
        {
            FilePath = filePath;
            Events = new List<GameEvent>();
            Players = new List<PlayerData>();
            Entities = new List<EntityData>();
        }

        public bool Parse()
        {
            try
            {
                Console.WriteLine($"Parsing demo file: {FilePath}");
                using (FileStream fs = new FileStream(FilePath, FileMode.Open, FileAccess.Read))
                using (BinaryReader reader = new BinaryReader(fs))
                {
                    // Parse demo file header
                    string magic = new string(reader.ReadChars(8));
                    if (magic != DEMO_MAGIC)
                    {
                        Console.WriteLine("Invalid demo file format. Expected ETLDEMO2.");
                        return false;
                    }

                    int protocol = reader.ReadInt32();
                    Console.WriteLine($"Demo protocol: {protocol}");

                    // Parse demo contents
                    while (fs.Position < fs.Length)
                    {
                        try
                        {
                            byte commandByte = reader.ReadByte();
                            DemoCommand command = (DemoCommand)commandByte;

                            switch (command)
                            {
                                case DemoCommand.ServerCommand:
                                    ParseServerCommand(reader);
                                    break;
                                case DemoCommand.ClientCommand:
                                    ParseClientCommand(reader);
                                    break;
                                case DemoCommand.Gamestate:
                                    ParseGamestate(reader);
                                    break;
                                case DemoCommand.Snapshot:
                                    ParseSnapshot(reader);
                                    break;
                                case DemoCommand.EOF:
                                    Console.WriteLine("Reached end of demo file");
                                    return FinalizePlayerData();
                                default:
                                    Console.WriteLine($"Unknown command: {command} at position {fs.Position}");
                                    return false;
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"Error parsing demo at position {fs.Position}: {ex.Message}");
                            Console.WriteLine(ex.StackTrace);
                            return false;
                        }
                    }
                }
                return FinalizePlayerData();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error opening demo file: {ex.Message}");
                return false;
            }
        }

        private bool FinalizePlayerData()
        {
            // Filter out players with insufficient data
            Players = Players.Where(p => p.AimData.Count >= 10).ToList();

            // Process player data to add enemy position information
            ProcessEnemyPositions();

            // Calculate additional metrics
            foreach (var player in Players)
            {
                CalculatePlayerMetrics(player);
            }

            Console.WriteLine($"Parsing complete. Found {Players.Count} players with sufficient data.");
            return true;
        }

        private void ParseServerCommand(BinaryReader reader)
        {
            int sequenceNumber = reader.ReadInt32();
            string commandString = ReadString(reader);

            Events.Add(new GameEvent
            {
                Type = GameEventType.ServerCommand,
                SequenceNumber = sequenceNumber,
                Data = commandString,
                Timestamp = _currentTimestamp
            });

            // Parse server command for game state info (team changes, etc.)
            if (commandString.StartsWith("cs"))
            {
                string[] parts = commandString.Split(' ');
                if (parts.Length >= 3)
                {
                    if (int.TryParse(parts[1], out int configIndex))
                    {
                        ProcessConfigString(configIndex, string.Join(" ", parts.Skip(2)));
                    }
                }
            }
        }

        private void ParseClientCommand(BinaryReader reader)
        {
            int sequenceNumber = reader.ReadInt32();
            string commandString = ReadString(reader);

            Events.Add(new GameEvent
            {
                Type = GameEventType.ClientCommand,
                SequenceNumber = sequenceNumber,
                Data = commandString,
                Timestamp = _currentTimestamp
            });

            // Extract aim data and firing info from client commands
            ExtractAimData(commandString, sequenceNumber);

            // Parse command for weapon selection
            if (commandString.StartsWith("weapon "))
            {
                string[] parts = commandString.Split(' ');
                if (parts.Length > 1 && int.TryParse(parts[1], out int weaponId))
                {
                    UpdatePlayerWeapon(weaponId);
                }
            }
        }

        private void ParseGamestate(BinaryReader reader)
        {
            int sequenceNumber = reader.ReadInt32();

            // Reset game state
            _currentTimestamp = 0;
            Entities.Clear();

            for (int i = 0; i < MAX_ENTITIES; i++)
            {
                Entities.Add(new EntityData { EntityId = i });
            }

            // Parse configstrings
            int numConfigStrings = reader.ReadInt32();
            Console.WriteLine($"Parsing {numConfigStrings} config strings");

            for (int i = 0; i < numConfigStrings; i++)
            {
                int index = reader.ReadInt16();
                string configString = ReadString(reader);
                ProcessConfigString(index, configString);
            }

            // Parse baseline entities
            int numBaselines = reader.ReadInt32();
            Console.WriteLine($"Parsing {numBaselines} entity baselines");

            for (int i = 0; i < numBaselines; i++)
            {
                int entityNum = reader.ReadInt16();
                if (entityNum >= 0 && entityNum < MAX_ENTITIES)
                {
                    // Parse entity state
                    EntityData entityData = ParseEntityData(reader);
                    entityData.EntityId = entityNum;
                    Entities[entityNum] = entityData;
                }
                else
                {
                    // Skip entity state data
                    SkipEntityData(reader);
                }
            }

            Events.Add(new GameEvent
            {
                Type = GameEventType.Gamestate,
                SequenceNumber = sequenceNumber,
                Timestamp = 0
            });
        }

        private void ParseSnapshot(BinaryReader reader)
        {
            int sequenceNumber = reader.ReadInt32();
            int serverTime = reader.ReadInt32();
            _currentTimestamp = serverTime;

            // Parse player state
            PlayerState playerState = ParsePlayerState(reader);

            // Extract the demo recorder's view
            int clientNum = playerState.ClientNum;
            Vector3 position = playerState.Position;
            Vector3 viewAngles = playerState.ViewAngles;

            // Parse delta entities
            int numEntities = reader.ReadInt16();
            for (int i = 0; i < numEntities; i++)
            {
                int entityNum = reader.ReadInt16();
                if (entityNum >= 0 && entityNum < MAX_ENTITIES)
                {
                    EntityData entityData = ParseEntityData(reader);
                    entityData.EntityId = entityNum;
                    entityData.Timestamp = serverTime;

                    // Update entity in our collection
                    Entities[entityNum] = entityData;

                    // Track player positions
                    if (entityData.IsPlayer && entityData.ClientNum != clientNum)
                    {
                        UpdatePlayerPosition(entityData.ClientNum, entityData.Position, entityData.Team, serverTime);
                    }
                }
                else
                {
                    // Skip entity state data
                    SkipEntityData(reader);
                }
            }

            // Create snapshot event
            Events.Add(new GameEvent
            {
                Type = GameEventType.Snapshot,
                SequenceNumber = sequenceNumber,
                Timestamp = serverTime,
                Position = position,
                ViewAngles = viewAngles
            });

            // Add aim data for the client player
            AddPlayerAimData(serverTime, position, viewAngles, playerState);
        }

        private PlayerState ParsePlayerState(BinaryReader reader)
        {
            var state = new PlayerState();

            // Read basic player state data from ET
            state.ClientNum = reader.ReadInt32();
            state.CommandTime = reader.ReadInt32();

            // Read movement state
            state.Position = ReadVector3(reader);
            state.Velocity = ReadVector3(reader);

            // View angles
            state.ViewAngles = ReadVector3(reader);

            // Weapon info
            state.WeaponId = reader.ReadInt32();
            state.WeaponState = reader.ReadInt32();

            // Health, etc.
            state.Health = reader.ReadInt32();
            state.MaxHealth = reader.ReadInt32();

            // Skip additional player state data
            reader.ReadBytes(160); // Simplified - actual size may vary

            return state;
        }

        private EntityData ParseEntityData(BinaryReader reader)
        {
            var entity = new EntityData();

            // Parse entity type
            entity.EntityType = reader.ReadByte();

            // Parse position
            entity.Position = ReadVector3(reader);

            // Parse angles
            entity.Angles = ReadVector3(reader);

            // Additional entity state (simplified)
            int modelIndex = reader.ReadInt16();
            int clientNum = reader.ReadInt16();
            int team = reader.ReadByte();

            entity.ModelIndex = modelIndex;
            entity.ClientNum = clientNum;
            entity.Team = team;

            // Determine if this is a player entity
            entity.IsPlayer = (clientNum >= 0 && clientNum < MAX_PLAYERS && entity.EntityType == 1);

            // Skip additional entity data
            reader.ReadBytes(24); // Simplified - actual size may vary

            return entity;
        }

        private void ExtractAimData(string commandString, int sequenceNumber)
        {
            // Extract firing states
            if (commandString.Contains("+attack"))
            {
                UpdateFiringState(true);

                Events.Add(new GameEvent
                {
                    Type = GameEventType.FireStart,
                    SequenceNumber = sequenceNumber,
                    Timestamp = _currentTimestamp
                });
            }
            else if (commandString.Contains("-attack"))
            {
                UpdateFiringState(false);

                Events.Add(new GameEvent
                {
                    Type = GameEventType.FireEnd,
                    SequenceNumber = sequenceNumber,
                    Timestamp = _currentTimestamp
                });
            }

            // Track aim commands (mouse movement)
            if (commandString.StartsWith("usercmd "))
            {
                string[] parts = commandString.Split(' ');
                if (parts.Length >= 4)
                {
                    if (int.TryParse(parts[2], out int pitchDelta) && int.TryParse(parts[3], out int yawDelta))
                    {
                        // Store user command deltas for later analysis
                        if (Players.Count > 0)
                        {
                            var player = Players[0]; // Demo recorder
                            if (player.AimData != null && player.AimData.Count > 0)
                            {
                                var lastAimData = player.AimData[player.AimData.Count - 1];
                                lastAimData.UserCmdPitchDelta = pitchDelta;
                                lastAimData.UserCmdYawDelta = yawDelta;
                            }
                        }
                    }
                }
            }
        }

        private void UpdateFiringState(bool isFiring)
        {
            // Update firing state for recorder player
            if (Players.Count > 0)
            {
                var player = Players[0]; // Assume first player is the demo recorder
                if (player.AimData != null && player.AimData.Count > 0)
                {
                    player.AimData[player.AimData.Count - 1].IsFiring = isFiring;
                }
            }
        }

        private void UpdatePlayerWeapon(int weaponId)
        {
            // Update weapon for recorder player
            if (Players.Count > 0)
            {
                var player = Players[0]; // Assume first player is the demo recorder
                if (player.AimData != null && player.AimData.Count > 0)
                {
                    player.AimData[player.AimData.Count - 1].WeaponId = weaponId;
                }
            }
        }

        private void AddPlayerAimData(int timestamp, Vector3 position, Vector3 viewAngles, PlayerState state)
        {
            // Find or create player data (for demo recorder/player)
            PlayerData player;
            if (Players.Count == 0)
            {
                player = new PlayerData
                {
                    PlayerID = state.ClientNum,
                    Name = "DemoRecorder",
                    AimData = new List<AimData>(),
                    Team = GetPlayerTeam(state.ClientNum)
                };
                Players.Add(player);
            }
            else
            {
                player = Players[0];
            }

            // Ensure AimData is initialized
            if (player.AimData == null)
            {
                player.AimData = new List<AimData>();
            }

            // Find nearest visible enemies at this timestamp
            var nearestEnemy = FindNearestVisibleEnemy(position, viewAngles, player.Team, timestamp);

            // Add aim data
            player.AimData.Add(new AimData
            {
                Timestamp = timestamp,
                Position = position,
                ViewAngles = viewAngles,
                IsFiring = player.AimData.Count > 0 && player.AimData[player.AimData.Count - 1].IsFiring,
                WeaponId = state.WeaponId,
                Health = state.Health,
                NearestEnemyPosition = nearestEnemy?.Position ?? Vector3.Zero,
                NearestEnemyDistance = nearestEnemy != null ? Vector3.Distance(position, nearestEnemy.Position) : float.MaxValue,
                HasVisibleEnemy = nearestEnemy != null
            });

            // Update position history
            UpdatePlayerPosition(state.ClientNum, position, player.Team, timestamp);
        }

        private void UpdatePlayerPosition(int clientNum, Vector3 position, int team, int timestamp)
        {
            if (!_playerPositions.TryGetValue(clientNum, out var history))
            {
                history = new PlayerPositionHistory { ClientNum = clientNum, Team = team };
                _playerPositions[clientNum] = history;
            }

            history.Positions.Add(new TimestampedPosition
            {
                Position = position,
                Timestamp = timestamp
            });

            // Keep only recent positions
            if (history.Positions.Count > 100)
            {
                history.Positions.RemoveAt(0);
            }
        }

        private EnemyData FindNearestVisibleEnemy(Vector3 playerPosition, Vector3 viewAngles, int playerTeam, int timestamp)
        {
            var nearestEnemy = new EnemyData { Distance = float.MaxValue };
            var playerForward = GetForwardVector(viewAngles);

            foreach (var enemy in _playerPositions.Values)
            {
                // Skip if same team or no recent positions
                if (enemy.Team == playerTeam || enemy.Positions.Count == 0) continue;

                // Get most recent position
                var lastPos = enemy.Positions.LastOrDefault(p => p.Timestamp <= timestamp);
                if (lastPos == null) continue;

                // Calculate distance
                float distance = Vector3.Distance(playerPosition, lastPos.Position);

                // Skip if too far
                if (distance > 2000) continue;

                // Check if in field of view (simplified)
                Vector3 toEnemyDir = Vector3.Normalize(lastPos.Position - playerPosition);
                float dotProduct = Vector3.Dot(playerForward, toEnemyDir);

                // Angle is approximately acos(dotProduct)
                // Check if within ~45 degrees of view direction
                if (dotProduct > 0.7f && distance < nearestEnemy.Distance)
                {
                    nearestEnemy.ClientNum = enemy.ClientNum;
                    nearestEnemy.Position = lastPos.Position;
                    nearestEnemy.Distance = distance;
                    nearestEnemy.DotProduct = dotProduct;
                }
            }

            return nearestEnemy.Distance < float.MaxValue ? nearestEnemy : null;
        }

        private Vector3 GetForwardVector(Vector3 viewAngles)
        {
            // Convert from ET's Euler angles to a forward vector
            float pitch = viewAngles.X * (float)Math.PI / 180.0f;
            float yaw = viewAngles.Y * (float)Math.PI / 180.0f;

            return new Vector3(
                MathF.Cos(pitch) * MathF.Sin(yaw),
                MathF.Sin(pitch),
                MathF.Cos(pitch) * MathF.Cos(yaw)
            );
        }

        private void ProcessConfigString(int index, string configString)
        {
            // Process player config strings
            if (index >= CS_PLAYERS_START && index < CS_PLAYERS_END)
            {
                int playerID = index - CS_PLAYERS_START;

                // Extract player info from config string - format: "n\\PlayerName\\t\\1\\c\\0\\..."
                Dictionary<string, string> playerInfo = ParseConfigStringInfo(configString);

                if (playerInfo.TryGetValue("n", out string playerName) && !string.IsNullOrEmpty(playerName))
                {
                    int team = 0;
                    if (playerInfo.TryGetValue("t", out string teamStr) && int.TryParse(teamStr, out int t))
                    {
                        team = t;
                    }

                    var player = Players.FirstOrDefault(p => p.PlayerID == playerID);
                    if (player != null)
                    {
                        player.Name = playerName;
                        player.Team = team;
                    }
                    else if (playerID > 0) // Skip duplicate entries for demo recorder
                    {
                        Players.Add(new PlayerData
                        {
                            PlayerID = playerID,
                            Name = playerName,
                            Team = team,
                            AimData = new List<AimData>()
                        });
                    }
                }
            }
        }

        private Dictionary<string, string> ParseConfigStringInfo(string configString)
        {
            var result = new Dictionary<string, string>();
            string[] parts = configString.Split('\\');

            for (int i = 1; i < parts.Length - 1; i += 2)
            {
                if (i + 1 < parts.Length)
                {
                    result[parts[i]] = parts[i + 1];
                }
            }

            return result;
        }

        private int GetPlayerTeam(int clientNum)
        {
            // Check if player exists in our list first
            var player = Players.FirstOrDefault(p => p.PlayerID == clientNum);
            if (player != null)
            {
                return player.Team;
            }

            // Otherwise check entities
            foreach (var entity in Entities)
            {
                if (entity.IsPlayer && entity.ClientNum == clientNum)
                {
                    return entity.Team;
                }
            }

            return 0; // Unknown team
        }

        private void ProcessEnemyPositions()
        {
            // Process enemy positions for each player's aim data
            foreach (var player in Players)
            {
                for (int i = 0; i < player.AimData.Count; i++)
                {
                    var aimData = player.AimData[i];
                    if (!aimData.HasVisibleEnemy) continue;

                    // Calculate angle to enemy
                    Vector3 toEnemy = aimData.NearestEnemyPosition - aimData.Position;
                    Vector3 targetAngles = CalculateViewAngles(toEnemy);

                    // Calculate angle difference
                    float pitchDiff = MathF.Abs(NormalizeAngle(targetAngles.X - aimData.ViewAngles.X));
                    float yawDiff = MathF.Abs(NormalizeAngle(targetAngles.Y - aimData.ViewAngles.Y));

                    // Store in aim data
                    aimData.TargetAngles = targetAngles;
                    aimData.AngleToTargetPitch = pitchDiff;
                    aimData.AngleToTargetYaw = yawDiff;
                    aimData.AngleToTarget = MathF.Sqrt(pitchDiff * pitchDiff + yawDiff * yawDiff);
                }
            }
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

        private float NormalizeAngle(float angle)
        {
            // Normalize angle to -180 to 180 range
            while (angle > 180)
                angle -= 360;
            while (angle < -180)
                angle += 360;
            return angle;
        }

        private void CalculatePlayerMetrics(PlayerData player)
        {
            if (player.AimData.Count < 2) return;

            // Calculate additional metrics for analysis
            for (int i = 1; i < player.AimData.Count; i++)
            {
                var current = player.AimData[i];
                var previous = player.AimData[i - 1];

                // Calculate time delta
                int timeDelta = current.Timestamp - previous.Timestamp;

                // Skip if timestamps are identical or out of order
                if (timeDelta <= 0) continue;

                // Calculate angle deltas
                float pitchDelta = MathF.Abs(NormalizeAngle(current.ViewAngles.X - previous.ViewAngles.X));
                float yawDelta = MathF.Abs(NormalizeAngle(current.ViewAngles.Y - previous.ViewAngles.Y));

                // Calculate angular velocity (degrees per millisecond)
                float pitchVelocity = pitchDelta / timeDelta;
                float yawVelocity = yawDelta / timeDelta;

                // Store calculated metrics
                current.PitchVelocity = pitchVelocity;
                current.YawVelocity = yawVelocity;
                current.TotalAngularVelocity = MathF.Sqrt(pitchVelocity * pitchVelocity + yawVelocity * yawVelocity);

                // Calculate acceleration (change in velocity)
                if (i > 1)
                {
                    var prev2 = player.AimData[i - 2];
                    int prevTimeDelta = previous.Timestamp - prev2.Timestamp;

                    if (prevTimeDelta > 0)
                    {
                        float prevPitchVelocity = previous.PitchVelocity;
                        float prevYawVelocity = previous.YawVelocity;

                        float pitchAccel = (pitchVelocity - prevPitchVelocity) / timeDelta;
                        float yawAccel = (yawVelocity - prevYawVelocity) / timeDelta;

                        current.PitchAcceleration = pitchAccel;
                        current.YawAcceleration = yawAccel;
                    }
                }
            }
        }

        private void SkipEntityData(BinaryReader reader)
        {
            // Skip entity state data
            reader.ReadBytes(64); // Simplified - adjust as needed for ET: Legacy
        }

        private string ReadString(BinaryReader reader)
        {
            List<char> chars = new List<char>();
            char c;
            while ((c = reader.ReadChar()) != '\0')
            {
                chars.Add(c);
            }
            return new string(chars.ToArray());
        }

        private Vector3 ReadVector3(BinaryReader reader)
        {
            float x = reader.ReadSingle();
            float y = reader.ReadSingle();
            float z = reader.ReadSingle();
            return new Vector3(x, y, z);
        }
    }

    public enum DemoCommand
    {
        ServerCommand = 1,
        ClientCommand = 2,
        Gamestate = 3,
        Snapshot = 4,
        EOF = 5
    }

    public class PlayerData
    {
        public int PlayerID { get; set; }
        public string? Name { get; set; }
        public int Team { get; set; }
        public List<AimData> AimData { get; set; } = new List<AimData>();
    }

    public class AimData
    {
        public int Timestamp { get; set; }
        public Vector3 Position { get; set; }
        public Vector3 ViewAngles { get; set; }
        public bool IsFiring { get; set; }
        public int WeaponId { get; set; }
        public int Health { get; set; }

        // Calculated metrics
        public float PitchVelocity { get; set; }
        public float YawVelocity { get; set; }
        public float TotalAngularVelocity { get; set; }
        public float PitchAcceleration { get; set; }
        public float YawAcceleration { get; set; }

        // Raw input data
        public int UserCmdPitchDelta { get; set; }
        public int UserCmdYawDelta { get; set; }

        // Enemy targeting data
        public Vector3 NearestEnemyPosition { get; set; }
        public float NearestEnemyDistance { get; set; }
        public bool HasVisibleEnemy { get; set; }
        public Vector3 TargetAngles { get; set; }
        public float AngleToTargetPitch { get; set; }
        public float AngleToTargetYaw { get; set; }
        public float AngleToTarget { get; set; }
    }

    public class EntityData
    {
        public int EntityId { get; set; }
        public byte EntityType { get; set; }
        public int Timestamp { get; set; }
        public Vector3 Position { get; set; }
        public Vector3 Angles { get; set; }
        public int ModelIndex { get; set; }
        public int ClientNum { get; set; }
        public int Team { get; set; }
        public bool IsPlayer { get; set; }
    }

    public class PlayerState
    {
        public int ClientNum { get; set; }
        public int CommandTime { get; set; }
        public Vector3 Position { get; set; }
        public Vector3 Velocity { get; set; }
        public Vector3 ViewAngles { get; set; }
        public int WeaponId { get; set; }
        public int WeaponState { get; set; }
        public int Health { get; set; }
        public int MaxHealth { get; set; }
    }

    public class PlayerPositionHistory
    {
        public int ClientNum { get; set; }
        public int Team { get; set; }
        public List<TimestampedPosition> Positions { get; set; } = new List<TimestampedPosition>();
    }

    public class TimestampedPosition
    {
        public Vector3 Position { get; set; }
        public int Timestamp { get; set; }
    }

    public class EnemyData
    {
        public int ClientNum { get; set; }
        public Vector3 Position { get; set; }
        public float Distance { get; set; }
        public float DotProduct { get; set; }
    }
}
