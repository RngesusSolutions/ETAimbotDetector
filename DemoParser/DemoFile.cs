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
        private int _currentTimestamp = 0;

        // ET demo constants
        private const string DEMO_MAGIC = "ETLDEMO2";
        private const int MAX_PLAYERS = 64;
        private const int CS_PLAYERS_START = 544;

        public DemoFile(string filePath)
        {
            FilePath = filePath;
            Events = new List<GameEvent>();
            Players = new List<PlayerData>();
        }

        public bool Parse()
        {
            try
            {
                using (FileStream fs = new FileStream(FilePath, FileMode.Open, FileAccess.Read))
                using (BinaryReader reader = new BinaryReader(fs))
                {
                    // Parse demo file header
                    string magic = new string(reader.ReadChars(8));
                    if (magic != DEMO_MAGIC)
                    {
                        Console.WriteLine("Invalid demo file format");
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
                                    return true;
                                default:
                                    Console.WriteLine($"Unknown command: {command}");
                                    return false;
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"Error parsing demo: {ex.Message}");
                            return false;
                        }
                    }
                }
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error opening demo file: {ex.Message}");
                return false;
            }
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
            
            // Extract aim data from client commands
            ExtractAimData(commandString, sequenceNumber);
        }

        private void ParseGamestate(BinaryReader reader)
        {
            int sequenceNumber = reader.ReadInt32();
            
            // Parse configstrings
            int numConfigStrings = reader.ReadInt32();
            for (int i = 0; i < numConfigStrings; i++)
            {
                int index = reader.ReadInt16();
                string configString = ReadString(reader);
                ProcessConfigString(index, configString);
            }
            
            // Parse baseline entities
            int numBaselines = reader.ReadInt32();
            for (int i = 0; i < numBaselines; i++)
            {
                int entityNum = reader.ReadInt16();
                // Skip entity state data for now
                SkipEntityData(reader);
            }
            
            Events.Add(new GameEvent
            {
                Type = GameEventType.Gamestate,
                SequenceNumber = sequenceNumber,
                Timestamp = 0 // Reset timestamp for new gamestate
            });

            _currentTimestamp = 0;
        }

        private void ParseSnapshot(BinaryReader reader)
        {
            int sequenceNumber = reader.ReadInt32();
            int serverTime = reader.ReadInt32();
            _currentTimestamp = serverTime;
            
            // Parse player state
            Vector3 position = ReadVector3(reader);
            Vector3 viewAngles = ReadVector3(reader);
            
            // Skip additional playerstate data
            SkipPlayerStateData(reader);
            
            // Parse delta entities
            int numEntities = reader.ReadInt16();
            for (int i = 0; i < numEntities; i++)
            {
                int entityNum = reader.ReadInt16();
                // Skip entity state data for now
                SkipEntityData(reader);
            }
            
            Events.Add(new GameEvent
            {
                Type = GameEventType.Snapshot,
                SequenceNumber = sequenceNumber,
                Timestamp = serverTime,
                Position = position,
                ViewAngles = viewAngles
            });
            
            // Add player aim data
            AddPlayerAimData(serverTime, position, viewAngles);
        }

        private void ExtractAimData(string commandString, int sequenceNumber)
        {
            if (commandString.Contains("+attack") || commandString.Contains("-attack"))
            {
                bool isFiring = commandString.Contains("+attack");
                
                // Update firing state for the current player
                if (Players.Count > 0)
                {
                    var player = Players[0]; // Assume first player is the demo recorder
                    if (player.AimData.Count > 0)
                    {
                        player.AimData[player.AimData.Count - 1].IsFiring = isFiring;
                    }
                }
                
                Events.Add(new GameEvent
                {
                    Type = isFiring ? GameEventType.FireStart : GameEventType.FireEnd,
                    SequenceNumber = sequenceNumber,
                    Timestamp = _currentTimestamp
                });
            }
        }

        private void AddPlayerAimData(int timestamp, Vector3 position, Vector3 viewAngles)
        {
            // Find or create player data (for demo recorder/player)
            PlayerData player;
            if (Players.Count == 0)
            {
                player = new PlayerData { PlayerID = 0, Name = "DemoRecorder", AimData = new List<AimData>() };
                Players.Add(player);
            }
            else
            {
                player = Players[0];
            }
            
            // Add aim data
            player.AimData.Add(new AimData
            {
                Timestamp = timestamp,
                Position = position,
                ViewAngles = viewAngles,
                IsFiring = player.AimData.Count > 0 && player.AimData[player.AimData.Count - 1].IsFiring
            });
        }

        private void ProcessConfigString(int index, string configString)
        {
            // Process player config strings
            if (index >= CS_PLAYERS_START && index < CS_PLAYERS_START + MAX_PLAYERS)
            {
                int playerID = index - CS_PLAYERS_START;
                
                // Extract player name from config string - format: "n\\PlayerName\\t\\1\\c\\0\\..."
                string playerName = null;
                int nameIndex = configString.IndexOf("n\\");
                if (nameIndex >= 0)
                {
                    int nameStart = nameIndex + 2;
                    int nameEnd = configString.IndexOf("\\", nameStart);
                    if (nameEnd > nameStart)
                    {
                        playerName = configString.Substring(nameStart, nameEnd - nameStart);
                    }
                }
                
                // Update player name
                if (!string.IsNullOrEmpty(playerName))
                {
                    var player = Players.FirstOrDefault(p => p.PlayerID == playerID);
                    if (player != null)
                    {
                        player.Name = playerName;
                    }
                    else if (playerID > 0) // Skip demo recorder which is added elsewhere
                    {
                        Players.Add(new PlayerData 
                        { 
                            PlayerID = playerID, 
                            Name = playerName,
                            AimData = new List<AimData>() 
                        });
                    }
                }
            }
        }

        private void SkipEntityData(BinaryReader reader)
        {
            // Skip entity state data blocks - would be more complex in a full implementation
            // This is a simplification for demo purposes
            reader.ReadBytes(64); // Arbitrary skip amount for demo
        }
        
        private void SkipPlayerStateData(BinaryReader reader)
        {
            // Skip additional playerstate data - would be more complex in a full implementation
            // This is a simplification for demo purposes
            reader.ReadBytes(128); // Arbitrary skip amount for demo
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
        public List<AimData> AimData { get; set; } = new List<AimData>();
    }

    public class AimData
    {
        public int Timestamp { get; set; }
        public Vector3 Position { get; set; }
        public Vector3 ViewAngles { get; set; }
        public bool IsFiring { get; set; }
    }
}