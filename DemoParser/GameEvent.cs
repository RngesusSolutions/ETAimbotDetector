using System;
using System.Numerics;

namespace AimbotDetector.DemoParser
{
    public class GameEvent
    {
        public GameEventType Type { get; set; }
        public int SequenceNumber { get; set; }
        public int Timestamp { get; set; }
        public string? Data { get; set; }
        public Vector3 Position { get; set; }
        public Vector3 ViewAngles { get; set; }
    }
    
    public enum GameEventType
    {
        ServerCommand,
        ClientCommand,
        Gamestate,
        Snapshot,
        FireStart,
        FireEnd
    }
}