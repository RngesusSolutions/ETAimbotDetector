using System;
using AimbotDetector.DemoParser;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace AimbotDetector.Tests
{
    [TestClass]
    public class EndianConversionTests
    {
        [TestMethod]
        public void TestLittleLong()
        {
            int original = 0x12345678;
            int converted = EndianConversion.LittleLong(original);
            
            // On little-endian systems, the value should remain the same
            if (BitConverter.IsLittleEndian)
            {
                Assert.AreEqual(original, converted);
            }
            else
            {
                // On big-endian systems, the bytes should be swapped
                Assert.AreEqual(0x78563412, converted);
            }
        }
        
        [TestMethod]
        public void TestLittleShort()
        {
            short original = 0x1234;
            short converted = EndianConversion.LittleShort(original);
            
            // On little-endian systems, the value should remain the same
            if (BitConverter.IsLittleEndian)
            {
                Assert.AreEqual(original, converted);
            }
            else
            {
                // On big-endian systems, the bytes should be swapped
                Assert.AreEqual((short)0x3412, converted);
            }
        }
        
        [TestMethod]
        public void TestLittleFloat()
        {
            float original = 123.456f;
            float converted = EndianConversion.LittleFloat(original);
            
            // On little-endian systems, the value should remain the same
            if (BitConverter.IsLittleEndian)
            {
                Assert.AreEqual(original, converted);
            }
            else
            {
                // On big-endian systems, the bytes should be swapped
                // This is harder to test directly, so we'll convert back and forth
                float roundTrip = EndianConversion.LittleFloat(converted);
                Assert.AreEqual(original, roundTrip);
            }
        }
    }
}
