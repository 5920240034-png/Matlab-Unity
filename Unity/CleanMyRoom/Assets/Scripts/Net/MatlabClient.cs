using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using UnityEngine;

namespace CleanMyRoom.Net
{
    public enum ConnectionState
    {
        Disconnected,
        Connecting,
        Connected
    }

    /// <summary>
    /// Thread-safe TCP client for the MATLAB server.
    ///
    /// All socket work (connect, receive, send) happens on background threads.
    /// Events are queued and delivered from <see cref="Tick"/>, which the
    /// Unity main thread calls once per frame. No Unity API is touched from a
    /// background thread except <see cref="Debug"/>, which is also posted.
    ///
    /// The client owns no gameplay logic. It cannot decide whether an answer
    /// is correct and it never awards stars.
    /// </summary>
    public sealed class MatlabClient
    {
        private const int ConnectTimeoutMilliseconds = 4000;
        private const int ThreadJoinMilliseconds = 1500;
        private const int MaxQueuedMessages = 512;

        private sealed class SenderState
        {
            public volatile bool Stop;
        }

        private readonly string host;
        private readonly int port;
        private readonly float reconnectSeconds;
        private readonly MessageFramer framer;

        private readonly Queue<byte[]> outgoing = new Queue<byte[]>();
        private readonly Queue<Action> mainThreadActions = new Queue<Action>();
        private readonly object outgoingGate = new object();
        private readonly object mainThreadGate = new object();
        private readonly object connectionGate = new object();

        private readonly ManualResetEventSlim stopSignal = new ManualResetEventSlim(false);
        private readonly AutoResetEvent outgoingSignal = new AutoResetEvent(false);

        private Thread workerThread;
        private Thread senderThread;
        private SenderState senderState;
        private TcpClient tcp;
        private NetworkStream stream;
        private volatile string lastDetail = string.Empty;
        private int stateValue = (int)ConnectionState.Disconnected;

        public event Action<ConnectionState, string> ConnectionChanged;
        public event Action<WireMessage> MessageReceived;
        public event Action<string> ProtocolError;

        public ConnectionState State
        {
            get { return (ConnectionState)Volatile.Read(ref stateValue); }
        }

        public string Host { get { return host; } }

        public int Port { get { return port; } }

        public MatlabClient(string host, int port, float reconnectSeconds)
        {
            if (string.IsNullOrEmpty(host))
            {
                throw new ArgumentException("Host must not be empty.", nameof(host));
            }
            if (port <= 0 || port > 65535)
            {
                throw new ArgumentOutOfRangeException(nameof(port));
            }

            this.host = host;
            this.port = port;
            this.reconnectSeconds = Mathf.Max(0.1f, reconnectSeconds);

            framer = new MessageFramer(ProtocolConstants.MaxMessageBytes);
            framer.MessageReceived += OnFramedLine;
            framer.ProtocolError += OnFramerError;
        }

        /// <summary>Start the background connect/reconnect loop.</summary>
        public void Start()
        {
            if (workerThread != null)
            {
                return;
            }

            stopSignal.Reset();
            workerThread = new Thread(WorkerLoop)
            {
                IsBackground = true,
                Name = "MATLAB Client"
            };
            workerThread.Start();
        }

        /// <summary>Stop all threads and release every socket resource.</summary>
        public void Stop()
        {
            stopSignal.Set();
            CloseConnection();
            outgoingSignal.Set();

            Thread worker = workerThread;
            workerThread = null;
            if (worker != null)
            {
                worker.Join(ThreadJoinMilliseconds);
            }

            StopSender();
            ClearOutgoing();
            framer.Reset();
            SetState(ConnectionState.Disconnected, "Client stopped.");
        }

        /// <summary>
        /// Close the current socket. The worker thread reconnects automatically
        /// after the configured delay.
        /// </summary>
        public void ForceReconnect()
        {
            if (workerThread == null)
            {
                Start();
                return;
            }

            CloseConnection();
            outgoingSignal.Set();
        }

        public bool SendPing(string requestId)
        {
            return SendLine(JsonCodec.EncodePing(requestId));
        }

        public bool SendPlaceRequest(
            string requestId,
            string activityId,
            string objectId,
            string targetId,
            float normalizedX,
            float normalizedY)
        {
            return SendLine(JsonCodec.EncodePlaceRequest(
                requestId, activityId, objectId, targetId, normalizedX, normalizedY));
        }

        /// <summary>Queue one JSON line for the sender thread.</summary>
        public bool SendLine(string json)
        {
            if (string.IsNullOrEmpty(json))
            {
                return false;
            }
            if (State != ConnectionState.Connected)
            {
                return false;
            }

            string line = json.EndsWith("\n", StringComparison.Ordinal) ? json : json + "\n";
            byte[] payload = Encoding.UTF8.GetBytes(line);

            lock (outgoingGate)
            {
                if (outgoing.Count > MaxQueuedMessages)
                {
                    outgoing.Clear();
                }
                outgoing.Enqueue(payload);
            }

            outgoingSignal.Set();
            return true;
        }

        /// <summary>
        /// Deliver queued events on the Unity main thread. Call once per frame.
        /// </summary>
        public void Tick()
        {
            for (int guard = 0; guard < 256; guard++)
            {
                Action action;
                lock (mainThreadGate)
                {
                    if (mainThreadActions.Count == 0)
                    {
                        return;
                    }
                    action = mainThreadActions.Dequeue();
                }

                try
                {
                    action();
                }
                catch (Exception ex)
                {
                    Debug.LogException(ex);
                }
            }
        }

        private void WorkerLoop()
        {
            while (!stopSignal.IsSet)
            {
                SetState(ConnectionState.Connecting, string.Empty);
                string failure = string.Empty;
                TcpClient candidate = null;

                try
                {
                    candidate = new TcpClient { NoDelay = true };
                    System.Threading.Tasks.Task connectTask = candidate.ConnectAsync(host, port);
                    if (!connectTask.Wait(ConnectTimeoutMilliseconds))
                    {
                        throw new TimeoutException("Connection attempt timed out.");
                    }

                    lock (connectionGate)
                    {
                        tcp = candidate;
                        stream = candidate.GetStream();
                    }

                    framer.Reset();
                    StartSender();
                    SetState(ConnectionState.Connected, string.Empty);
                    ReceiveLoop();
                }
                catch (Exception ex)
                {
                    failure = Describe(ex);
                }
                finally
                {
                    CloseConnection();
                    StopSender();
                    ClearOutgoing();
                    try
                    {
                        if (candidate != null)
                        {
                            candidate.Close();
                        }
                    }
                    catch
                    {
                        // Socket already released.
                    }
                }

                if (stopSignal.IsSet)
                {
                    break;
                }

                SetState(ConnectionState.Disconnected, failure);
                if (stopSignal.Wait(TimeSpan.FromSeconds(reconnectSeconds)))
                {
                    break;
                }
            }

            SetState(ConnectionState.Disconnected, "Client stopped.");
        }

        private void ReceiveLoop()
        {
            byte[] buffer = new byte[8192];
            while (!stopSignal.IsSet)
            {
                NetworkStream current = GetStream();
                if (current == null)
                {
                    throw new IOException("Connection is not available.");
                }

                int read = current.Read(buffer, 0, buffer.Length);
                if (read <= 0)
                {
                    throw new IOException("MATLAB closed the connection.");
                }

                framer.Append(buffer, 0, read);
            }
        }

        private void StartSender()
        {
            SenderState state = new SenderState();
            senderState = state;

            Thread thread = new Thread(() => SendLoop(state))
            {
                IsBackground = true,
                Name = "MATLAB Client Send"
            };
            senderThread = thread;
            thread.Start();
        }

        private void SendLoop(SenderState state)
        {
            while (!state.Stop)
            {
                byte[] payload = null;
                lock (outgoingGate)
                {
                    if (outgoing.Count > 0)
                    {
                        payload = outgoing.Dequeue();
                    }
                }

                if (payload == null)
                {
                    outgoingSignal.WaitOne(200);
                    continue;
                }

                try
                {
                    NetworkStream target = GetStream();
                    if (target == null)
                    {
                        throw new IOException("Connection is not available.");
                    }

                    target.Write(payload, 0, payload.Length);
                    target.Flush();
                }
                catch (Exception ex)
                {
                    if (!state.Stop)
                    {
                        string text = "Send failed: " + ex.Message;
                        Post(() => Debug.LogWarning("[MATLAB] " + text));
                        CloseConnection();
                    }
                    return;
                }
            }
        }

        private void StopSender()
        {
            SenderState state = senderState;
            senderState = null;
            if (state != null)
            {
                state.Stop = true;
            }

            outgoingSignal.Set();

            Thread thread = senderThread;
            senderThread = null;
            if (thread != null)
            {
                thread.Join(ThreadJoinMilliseconds);
            }
        }

        private NetworkStream GetStream()
        {
            lock (connectionGate)
            {
                return stream;
            }
        }

        private void CloseConnection()
        {
            lock (connectionGate)
            {
                if (stream != null)
                {
                    try
                    {
                        stream.Close();
                    }
                    catch
                    {
                        // Closing an already broken stream is harmless.
                    }
                    stream = null;
                }

                if (tcp != null)
                {
                    try
                    {
                        tcp.Close();
                    }
                    catch
                    {
                        // Closing an already broken socket is harmless.
                    }
                    tcp = null;
                }
            }
        }

        private void ClearOutgoing()
        {
            lock (outgoingGate)
            {
                outgoing.Clear();
            }
        }

        private void OnFramedLine(string line)
        {
            Post(() => DecodeAndDispatch(line));
        }

        private void OnFramerError(string error)
        {
            Post(() =>
            {
                Debug.LogWarning("[MATLAB] " + error);
                ProtocolError?.Invoke(error);
            });
        }

        private void DecodeAndDispatch(string line)
        {
            WireMessage message;
            string error;
            if (!JsonCodec.TryDecode(line, out message, out error))
            {
                string text = "Invalid message from MATLAB: " + error;
                Debug.LogWarning("[MATLAB] " + text);
                ProtocolError?.Invoke(text);
                return;
            }

            MessageReceived?.Invoke(message);
        }

        private void SetState(ConnectionState next, string detail)
        {
            if (detail == null)
            {
                detail = string.Empty;
            }

            int previous = Interlocked.Exchange(ref stateValue, (int)next);
            bool unchanged = previous == (int)next &&
                             string.Equals(lastDetail, detail, StringComparison.Ordinal);
            if (unchanged)
            {
                return;
            }

            lastDetail = detail;
            string captured = detail;
            Post(() => ConnectionChanged?.Invoke(next, captured));
        }

        private void Post(Action action)
        {
            if (action == null)
            {
                return;
            }

            lock (mainThreadGate)
            {
                mainThreadActions.Enqueue(action);
            }
        }

        private string Describe(Exception ex)
        {
            AggregateException aggregate = ex as AggregateException;
            if (aggregate != null && aggregate.InnerExceptions.Count > 0)
            {
                ex = aggregate.InnerExceptions[0];
            }

            SocketException socket = ex as SocketException;
            if (socket != null)
            {
                return "Cannot reach MATLAB at " + host + ":" + port +
                       " (" + socket.SocketErrorCode + ").";
            }

            return ex.Message;
        }
    }
}
