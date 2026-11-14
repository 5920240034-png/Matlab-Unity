using System;
using System.Collections.Generic;
using System.Threading;
using CleanMyRoom.Net;
using NUnit.Framework;

namespace CleanMyRoom.Tests
{
    /// <summary>
    /// End-to-end test against a real MATLAB server on 127.0.0.1:55001.
    ///
    /// Marked Explicit because it needs the MATLAB server and the COLOR
    /// fixture activity. Start MATLAB first:
    ///
    ///   server = startServer('DataDirectory', ...
    ///       fullfile(pwd, 'MATLAB', 'Tests', 'fixtures'));
    ///
    /// Then run this test from the Unity Test Runner or with:
    ///   Unity.exe -batchmode -projectPath ... -runTests -testPlatform EditMode
    ///       -testFilter CleanMyRoom.Tests.NetworkIntegrationTests
    ///
    /// It verifies that Unity can connect, exchange PING/PONG, place objects,
    /// receive MATLAB's authoritative result, complete an activity, receive
    /// game progress, survive invalid input, and reconnect.
    /// </summary>
    [Explicit("Requires the MATLAB server on 127.0.0.1:55001 with the test fixture loaded.")]
    [Category("Integration")]
    public sealed class NetworkIntegrationTests
    {
        private const string Host = "127.0.0.1";
        private const int Port = 55001;

        private MatlabClient client;
        private List<WireMessage> inbox;
        private List<string> protocolErrors;
        private ConnectionState state;

        [SetUp]
        public void SetUp()
        {
            inbox = new List<WireMessage>();
            protocolErrors = new List<string>();
            state = ConnectionState.Disconnected;

            client = new MatlabClient(Host, Port, 1f);
            client.MessageReceived += inbox.Add;
            client.ProtocolError += protocolErrors.Add;
            client.ConnectionChanged += (next, detail) => state = next;
        }

        [TearDown]
        public void TearDown()
        {
            if (client != null)
            {
                client.Stop();
                client = null;
            }
        }

        [Test]
        public void ConnectsPingsPlacesAndReconnects()
        {
            string runId = Guid.NewGuid().ToString("N").Substring(0, 8);
            string pingId = "it_ping_" + runId;
            string firstPlacementId = "it_place_a_" + runId;
            string secondPlacementId = "it_place_b_" + runId;

            client.Start();

            Assert.IsTrue(WaitFor(() => state == ConnectionState.Connected, 15f),
                "Unity did not connect to MATLAB. Is the server running on " + Host + ":" + Port + "?");

            Assert.IsTrue(client.SendPing(pingId), "PING could not be queued.");
            WireMessage pong = WaitForMessage(m =>
                m.IsType(ProtocolConstants.TypePong) && m.requestId == pingId, 5f);
            Assert.IsNotNull(pong, "No PONG received.");
            Assert.AreEqual("CONNECTED", pong.status);

            Assert.IsTrue(client.SendPlaceRequest(
                firstPlacementId, "COLOR", "object_01", "basket_red", 0.45f, 0.62f));

            WireMessage placement = WaitForMessage(m =>
                m.IsType(ProtocolConstants.TypePlaceResponse) && m.requestId == firstPlacementId, 5f);
            Assert.IsNotNull(placement, "No PLACE_RES received.");
            Assert.IsTrue(placement.valid);
            Assert.IsTrue(placement.correct);
            Assert.AreEqual(1, placement.score);
            Assert.IsNotNull(placement.position);
            Assert.AreEqual(0.45f, placement.position.x, 0.0001f);
            Assert.AreEqual(0.62f, placement.position.y, 0.0001f);

            WireMessage firstResult = WaitForMessage(m =>
                m.IsType(ProtocolConstants.TypeActivityResult) && m.requestId == firstPlacementId, 5f);
            Assert.IsNotNull(firstResult, "No ACTIVITY_RESULT received.");
            Assert.IsTrue(firstResult.correct);
            Assert.IsFalse(firstResult.completed);
            Assert.AreEqual(0, firstResult.stars);

            Assert.IsTrue(client.SendPlaceRequest(
                secondPlacementId, "COLOR", "object_02", "basket_blue", 0.7f, 0.7f));

            WireMessage secondPlacement = WaitForMessage(m =>
                m.IsType(ProtocolConstants.TypePlaceResponse) && m.requestId == secondPlacementId, 5f);
            Assert.IsNotNull(secondPlacement, "No second PLACE_RES received.");
            Assert.AreEqual(2, secondPlacement.score);

            WireMessage secondResult = WaitForMessage(m =>
                m.IsType(ProtocolConstants.TypeActivityResult) && m.requestId == secondPlacementId, 5f);
            Assert.IsNotNull(secondResult, "No second ACTIVITY_RESULT received.");
            Assert.IsTrue(secondResult.completed);
            Assert.AreEqual(1, secondResult.stars);

            WireMessage progress = WaitForMessage(m =>
                m.IsType(ProtocolConstants.TypeGameProgress), 5f);
            Assert.IsNotNull(progress, "No GAME_PROGRESS received.");
            Assert.AreEqual(1, progress.stars);
            CollectionAssert.Contains(progress.completedActivities, "COLOR");
            Assert.IsFalse(progress.gameCompleted);

            Assert.IsTrue(client.SendLine("{not valid json"));
            WireMessage jsonError = WaitForMessage(m =>
                m.IsType(ProtocolConstants.TypeError) && m.code == "INVALID_JSON", 5f);
            Assert.IsNotNull(jsonError, "Invalid JSON did not produce an INVALID_JSON error.");

            Assert.IsTrue(client.SendLine("{\"type\":\"HAND\",\"requestId\":\"it_hand_" + runId + "\"}"));
            WireMessage typeError = WaitForMessage(m =>
                m.IsType(ProtocolConstants.TypeError) &&
                m.requestId == "it_hand_" + runId, 5f);
            Assert.IsNotNull(typeError, "Unsupported type did not produce an ERROR.");
            Assert.AreEqual("UNSUPPORTED_TYPE", typeError.code);

            // Exercise the client's automatic reconnect path by dropping the
            // socket. The worker thread must reconnect without restarting Unity.
            // Wait for the disconnect to be observed before waiting for the new
            // connection; otherwise the mirrored state is still the stale
            // "Connected" value from the first connection and a request sent
            // immediately would be discarded during teardown.
            client.ForceReconnect();
            Assert.IsTrue(WaitFor(() => client.State != ConnectionState.Connected, 10f),
                "Client did not observe the forced disconnect.");
            Assert.IsTrue(WaitFor(() => client.State == ConnectionState.Connected, 20f),
                "Client did not reconnect.");

            bool sent = false;
            for (int attempt = 0; attempt < 100 && !sent; attempt++)
            {
                sent = client.SendPing("it_ping_after_reconnect_" + runId);
                if (!sent)
                {
                    client.Tick();
                    Thread.Sleep(50);
                }
            }
            Assert.IsTrue(sent, "PING after reconnect could not be queued.");

            WireMessage reconnectedPong = WaitForMessage(m =>
                m.IsType(ProtocolConstants.TypePong) &&
                m.requestId == "it_ping_after_reconnect_" + runId, 10f);
            Assert.IsNotNull(reconnectedPong, "No PONG after reconnect.");
            Assert.IsEmpty(protocolErrors, "Unexpected protocol errors: " +
                string.Join(", ", protocolErrors));
        }

        private bool WaitFor(Func<bool> condition, float seconds)
        {
            DateTime deadline = DateTime.UtcNow.AddSeconds(seconds);
            while (DateTime.UtcNow < deadline)
            {
                client.Tick();
                if (condition())
                {
                    return true;
                }
                Thread.Sleep(20);
            }
            return false;
        }

        private WireMessage WaitForMessage(Func<WireMessage, bool> predicate, float seconds)
        {
            DateTime deadline = DateTime.UtcNow.AddSeconds(seconds);
            while (DateTime.UtcNow < deadline)
            {
                client.Tick();
                for (int i = 0; i < inbox.Count; i++)
                {
                    if (predicate(inbox[i]))
                    {
                        WireMessage match = inbox[i];
                        inbox.RemoveAt(i);
                        return match;
                    }
                }
                Thread.Sleep(20);
            }
            return null;
        }
    }
}
