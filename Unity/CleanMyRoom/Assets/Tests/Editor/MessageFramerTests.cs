using System.Collections.Generic;
using System.Text;
using CleanMyRoom.Net;
using NUnit.Framework;

namespace CleanMyRoom.Tests
{
    /// <summary>
    /// Newline framing tests. These exercise the Unity side of the protocol
    /// without needing a running MATLAB server.
    /// </summary>
    public sealed class MessageFramerTests
    {
        private MessageFramer framer;
        private List<string> received;
        private List<string> errors;

        [SetUp]
        public void SetUp()
        {
            framer = new MessageFramer(1024);
            received = new List<string>();
            errors = new List<string>();
            framer.MessageReceived += received.Add;
            framer.ProtocolError += errors.Add;
        }

        [Test]
        public void EmitsSingleCompleteMessage()
        {
            Append("{\"type\":\"PONG\"}\n");

            Assert.AreEqual(1, received.Count);
            Assert.AreEqual("{\"type\":\"PONG\"}", received[0]);
        }

        [Test]
        public void EmitsMultipleMessagesFromOnePacket()
        {
            Append("first\nsecond\nthird\n");

            CollectionAssert.AreEqual(new[] { "first", "second", "third" }, received);
        }

        [Test]
        public void ReassemblesMessageSplitAcrossManyReads()
        {
            byte[] payload = Encoding.UTF8.GetBytes("alpha\nbeta\n");
            for (int i = 0; i < payload.Length; i++)
            {
                framer.Append(payload, i, 1);
            }

            CollectionAssert.AreEqual(new[] { "alpha", "beta" }, received);
        }

        [Test]
        public void StripsCarriageReturnFromCrLf()
        {
            Append("windows\r\n");

            Assert.AreEqual(1, received.Count);
            Assert.AreEqual("windows", received[0]);
        }

        [Test]
        public void IgnoresBlankKeepAliveLines()
        {
            Append("\n\n   \nreal\n");

            CollectionAssert.AreEqual(new[] { "real" }, received);
        }

        [Test]
        public void ReassemblesUtf8CharacterSplitAcrossReads()
        {
            // U+00E9 ("é") is two bytes in UTF-8. Split between them.
            byte[] payload = Encoding.UTF8.GetBytes("caf\u00e9\n");
            framer.Append(payload, 0, 4);
            framer.Append(payload, 4, payload.Length - 4);

            Assert.AreEqual(1, received.Count);
            Assert.AreEqual("caf\u00e9", received[0]);
        }

        [Test]
        public void DropsOversizedLineAndKeepsFollowingMessages()
        {
            framer = new MessageFramer(8);
            received.Clear();
            errors.Clear();
            framer.MessageReceived += received.Add;
            framer.ProtocolError += errors.Add;

            Append("0123456789ABCDEF\nok\n");

            CollectionAssert.AreEqual(new[] { "ok" }, received);
            Assert.AreEqual(1, errors.Count);
        }

        [Test]
        public void DropsUnboundedBufferAndRecovers()
        {
            framer = new MessageFramer(8);
            received.Clear();
            errors.Clear();
            framer.MessageReceived += received.Add;
            framer.ProtocolError += errors.Add;

            Append("no-newline-yet");
            Assert.AreEqual(1, errors.Count);

            Append("ok\n");
            CollectionAssert.AreEqual(new[] { "ok" }, received);
        }

        [Test]
        public void ResetDiscardsPartialMessage()
        {
            Append("{\"type\":\"PIN");
            framer.Reset();
            Append("{\"type\":\"PONG\"}\n");

            Assert.AreEqual(1, received.Count);
            Assert.AreEqual("{\"type\":\"PONG\"}", received[0]);
        }

        private void Append(string text)
        {
            byte[] payload = Encoding.UTF8.GetBytes(text);
            framer.Append(payload, 0, payload.Length);
        }
    }
}
