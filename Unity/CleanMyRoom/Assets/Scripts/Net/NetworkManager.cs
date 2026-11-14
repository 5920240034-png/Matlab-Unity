using System;
using System.Globalization;
using UnityEngine;

namespace CleanMyRoom.Net
{
    /// <summary>
    /// Owns the single MATLAB connection used by the game.
    ///
    /// Responsibilities:
    ///  - start the background TCP client and drive its main-thread queue;
    ///  - expose connection state so activities can be disabled while offline;
    ///  - send PING / PLACE_REQ requests and forward MATLAB responses;
    ///  - keep a heartbeat so a silently dead server is detected.
    ///
    /// It never interprets an answer as correct or incorrect and never awards
    /// stars. Those decisions belong to MATLAB.
    /// </summary>
    [DefaultExecutionOrder(-100)]
    public sealed class NetworkManager : MonoBehaviour
    {
        [Header("MATLAB server")]
        [SerializeField] private string host = ProtocolConstants.DefaultHost;
        [SerializeField, Min(1)] private int port = ProtocolConstants.DefaultPort;

        [Header("Connection")]
        [SerializeField, Min(0.25f)] private float reconnectSeconds = 2f;
        [SerializeField, Min(1f)] private float heartbeatIntervalSeconds = 5f;
        [SerializeField, Min(1f)] private float heartbeatTimeoutSeconds = 8f;

        public static NetworkManager Instance { get; private set; }

        /// <summary>Raised on the main thread whenever the connection state changes.</summary>
        public event Action<ConnectionState, string> ConnectionChanged;

        /// <summary>Every non-PONG message from MATLAB, delivered on the main thread.</summary>
        public event Action<WireMessage> MessageReceived;

        private MatlabClient client;
        private int requestCounter;
        private string pendingHeartbeatId;
        private float heartbeatSentAt = -1f;
        private float nextHeartbeatAt;

        public ConnectionState State
        {
            get { return client != null ? client.State : ConnectionState.Disconnected; }
        }

        public bool IsConnected
        {
            get { return State == ConnectionState.Connected; }
        }

        /// <summary>
        /// False while MATLAB is unreachable. Activity code must check this and
        /// must never fall back to local validation.
        /// </summary>
        public bool ActivitiesEnabled
        {
            get { return IsConnected; }
        }

        public string Endpoint
        {
            get { return host + ":" + port.ToString(CultureInfo.InvariantCulture); }
        }

        public string LastError { get; private set; } = string.Empty;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void EnsureInstance()
        {
            if (UnityEngine.Object.FindAnyObjectByType<NetworkManager>() != null)
            {
                return;
            }

            GameObject root = new GameObject("MATLAB Network");
            root.AddComponent<NetworkManager>();
        }

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Debug.LogWarning("[MATLAB] Duplicate NetworkManager removed.");
                Destroy(gameObject);
                return;
            }

            Instance = this;
            if (transform.parent == null)
            {
                DontDestroyOnLoad(gameObject);
            }

            client = new MatlabClient(host, port, reconnectSeconds);
            client.ConnectionChanged += HandleConnectionChanged;
            client.MessageReceived += HandleMessage;
            client.ProtocolError += HandleProtocolError;
            client.Start();
        }

        private void Update()
        {
            if (client == null)
            {
                return;
            }

            client.Tick();
            UpdateHeartbeat();
        }

        private void OnDestroy()
        {
            if (Instance == this)
            {
                Instance = null;
            }

            if (client == null)
            {
                return;
            }

            client.ConnectionChanged -= HandleConnectionChanged;
            client.MessageReceived -= HandleMessage;
            client.ProtocolError -= HandleProtocolError;
            client.Stop();
            client = null;
        }

        /// <summary>
        /// Queue a placement for MATLAB validation.
        /// </summary>
        /// <returns>The request id, or null when nothing was sent.</returns>
        public string SendPlaceRequest(
            string activityId,
            string objectId,
            string targetId,
            float normalizedX,
            float normalizedY)
        {
            if (!IsConnected)
            {
                LastError = "Not connected to MATLAB.";
                return null;
            }

            if (string.IsNullOrEmpty(activityId) ||
                string.IsNullOrEmpty(objectId) ||
                string.IsNullOrEmpty(targetId))
            {
                LastError = "A placement request needs activity, object and target identifiers.";
                return null;
            }

            string requestId = NewRequestId();
            if (!client.SendPlaceRequest(
                    requestId, activityId, objectId, targetId, normalizedX, normalizedY))
            {
                LastError = "The placement request could not be sent.";
                return null;
            }

            return requestId;
        }

        /// <summary>Send a manual PING (the heartbeat also uses PING).</summary>
        /// <returns>The request id, or null when disconnected.</returns>
        public string SendPing()
        {
            if (!IsConnected)
            {
                return null;
            }

            string requestId = NewRequestId();
            return client.SendPing(requestId) ? requestId : null;
        }

        private void UpdateHeartbeat()
        {
            if (!IsConnected)
            {
                heartbeatSentAt = -1f;
                pendingHeartbeatId = null;
                return;
            }

            float now = Time.unscaledTime;

            if (heartbeatSentAt >= 0f)
            {
                if (now - heartbeatSentAt > heartbeatTimeoutSeconds)
                {
                    Debug.LogWarning("[MATLAB] Heartbeat timed out; reconnecting.");
                    LastError = "MATLAB stopped responding.";
                    heartbeatSentAt = -1f;
                    pendingHeartbeatId = null;
                    nextHeartbeatAt = now + reconnectSeconds;
                    client.ForceReconnect();
                }
                return;
            }

            if (now < nextHeartbeatAt)
            {
                return;
            }

            pendingHeartbeatId = NewRequestId();
            heartbeatSentAt = now;
            if (!client.SendPing(pendingHeartbeatId))
            {
                heartbeatSentAt = -1f;
                pendingHeartbeatId = null;
            }
            nextHeartbeatAt = now + heartbeatIntervalSeconds;
        }

        private void HandleConnectionChanged(ConnectionState state, string detail)
        {
            LastError = state == ConnectionState.Connected
                ? string.Empty
                : (detail ?? string.Empty);

            heartbeatSentAt = -1f;
            pendingHeartbeatId = null;
            nextHeartbeatAt = Time.unscaledTime + heartbeatIntervalSeconds;

            Action<ConnectionState, string> handler = ConnectionChanged;
            if (handler != null)
            {
                handler(state, detail ?? string.Empty);
            }
        }

        private void HandleMessage(WireMessage message)
        {
            if (message == null)
            {
                return;
            }

            if (message.IsType(ProtocolConstants.TypePong))
            {
                if (string.IsNullOrEmpty(pendingHeartbeatId) ||
                    message.requestId == pendingHeartbeatId)
                {
                    pendingHeartbeatId = null;
                    heartbeatSentAt = -1f;
                }
                return;
            }

            Action<WireMessage> handler = MessageReceived;
            if (handler != null)
            {
                handler(message);
            }
        }

        private void HandleProtocolError(string error)
        {
            LastError = error;
        }

        private string NewRequestId()
        {
            requestCounter++;
            return "req_" + requestCounter.ToString("D6", CultureInfo.InvariantCulture);
        }
    }
}
