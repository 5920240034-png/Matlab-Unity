using CleanMyRoom.Net;
using NUnit.Framework;

namespace CleanMyRoom.Tests
{
    /// <summary>
    /// JSON encoding/decoding tests for the Unity side of the protocol.
    /// The decoder is intentionally permissive about fields Unity does not
    /// need, but it must reject malformed JSON and messages without a type.
    /// </summary>
    public sealed class JsonCodecTests
    {
        private WireMessage message;
        private string error;

        [Test]
        public void EncodesPingRequest()
        {
            string json = JsonCodec.EncodePing("req_001");

            StringAssert.Contains("\"type\":\"PING\"", json);
            StringAssert.Contains("\"requestId\":\"req_001\"", json);
        }

        [Test]
        public void EncodesPlaceRequestWithNestedPosition()
        {
            string json = JsonCodec.EncodePlaceRequest(
                "req_002", "COLOR", "object_01", "basket_01", 0.45f, 0.62f);

            StringAssert.Contains("\"type\":\"PLACE_REQ\"", json);
            StringAssert.Contains("\"activity\":\"COLOR\"", json);
            StringAssert.Contains("\"objectId\":\"object_01\"", json);
            StringAssert.Contains("\"targetId\":\"basket_01\"", json);
            StringAssert.Contains("\"position\":{\"x\":0.45,\"y\":0.62}", json);
        }

        [Test]
        public void EscapesQuotesInRequestFields()
        {
            string json = JsonCodec.EncodePing("req\"with\\slashes");

            StringAssert.Contains("req\\\"with\\\\slashes", json);
        }

        [Test]
        public void DecodesPong()
        {
            bool ok = JsonCodec.TryDecode(
                "{\"type\":\"PONG\",\"requestId\":\"req_001\",\"status\":\"CONNECTED\"}",
                out message, out error);

            Assert.IsTrue(ok, error);
            Assert.AreEqual("PONG", message.type);
            Assert.AreEqual("req_001", message.requestId);
            Assert.AreEqual("CONNECTED", message.status);
        }

        [Test]
        public void DecodesPlaceResponseWithPosition()
        {
            bool ok = JsonCodec.TryDecode(
                "{\"type\":\"PLACE_RES\",\"requestId\":\"r2\",\"activity\":\"COLOR\"," +
                "\"valid\":true,\"correct\":true,\"position\":{\"x\":0.45,\"y\":0.62},\"score\":1}",
                out message, out error);

            Assert.IsTrue(ok, error);
            Assert.IsTrue(message.valid);
            Assert.IsTrue(message.correct);
            Assert.AreEqual(1, message.score);
            Assert.IsNotNull(message.position);
            Assert.AreEqual(0.45f, message.position.x, 0.0001f);
            Assert.AreEqual(0.62f, message.position.y, 0.0001f);
        }

        [Test]
        public void DecodesActivityResultAndProgressArray()
        {
            bool ok = JsonCodec.TryDecode(
                "{\"type\":\"GAME_PROGRESS\",\"stars\":2," +
                "\"completedActivities\":[\"COLOR\",\"TASTE\"],\"gameCompleted\":false}",
                out message, out error);

            Assert.IsTrue(ok, error);
            Assert.AreEqual(2, message.stars);
            Assert.IsFalse(message.gameCompleted);
            CollectionAssert.AreEqual(new[] { "COLOR", "TASTE" }, message.completedActivities);
        }

        [Test]
        public void DecodesError()
        {
            bool ok = JsonCodec.TryDecode(
                "{\"type\":\"ERROR\",\"requestId\":\"r3\",\"code\":\"INVALID_REQUEST\",\"message\":\"bad\"}",
                out message, out error);

            Assert.IsTrue(ok, error);
            Assert.AreEqual("ERROR", message.type);
            Assert.AreEqual("INVALID_REQUEST", message.code);
        }

        [Test]
        public void IgnoresUnknownFields()
        {
            bool ok = JsonCodec.TryDecode(
                "{\"type\":\"PONG\",\"requestId\":\"r1\",\"futureField\":123}",
                out message, out error);

            Assert.IsTrue(ok, error);
            Assert.AreEqual("PONG", message.type);
        }

        [Test]
        public void RejectsMalformedJson()
        {
            bool ok = JsonCodec.TryDecode("{ \"type\": ", out message, out error);

            Assert.IsFalse(ok);
            Assert.IsNull(message);
            Assert.IsNotEmpty(error);
        }

        [Test]
        public void RejectsEmptyMessage()
        {
            bool ok = JsonCodec.TryDecode("   ", out message, out error);

            Assert.IsFalse(ok);
            Assert.IsNotEmpty(error);
        }

        [Test]
        public void RejectsMissingType()
        {
            bool ok = JsonCodec.TryDecode("{\"requestId\":\"r1\"}", out message, out error);

            Assert.IsFalse(ok);
            Assert.IsNotEmpty(error);
        }
    }
}
