using AimbotDetector.DemoParser;

public class PlayerPositionHistory
{
    public int ClientNum { get; set; }
    public int Team { get; set; }
    public List<TimestampedPosition> Positions { get; set; } = new List<TimestampedPosition>();
}