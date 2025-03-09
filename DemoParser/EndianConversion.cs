using System;

namespace AimbotDetector.DemoParser
{
    public static class EndianConversion
    {
        public static int LittleLong(int value)
        {
            if (BitConverter.IsLittleEndian)
                return value;
            
            return ((value & 0xFF) << 24) | 
                   ((value & 0xFF00) << 8) | 
                   ((value & 0xFF0000) >> 8) | 
                   ((value & 0xFF000000) >> 24);
        }
        
        public static short LittleShort(short value)
        {
            if (BitConverter.IsLittleEndian)
                return value;
            
            return (short)(((value & 0xFF) << 8) | ((value & 0xFF00) >> 8));
        }
        
        public static float LittleFloat(float value)
        {
            if (BitConverter.IsLittleEndian)
                return value;
            
            byte[] bytes = BitConverter.GetBytes(value);
            Array.Reverse(bytes);
            return BitConverter.ToSingle(bytes, 0);
        }
    }
}
