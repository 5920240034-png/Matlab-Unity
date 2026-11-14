using UnityEngine;

namespace CleanMyRoom.Net
{
    /// <summary>
    /// Lightweight IMGUI overlay that always shows the MATLAB connection state.
    ///
    /// It is intentionally independent from the game's future UI system: the
    /// status must be visible even in an otherwise empty scene, and it must
    /// make clear that activities are disabled while MATLAB is unavailable.
    /// It reads <see cref="NetworkManager"/> every frame and creates no state
    /// of its own, so it cannot get out of sync with the client.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class ConnectionStatusHud : MonoBehaviour
    {
        [SerializeField] private Vector2 offset = new Vector2(16f, 16f);
        [SerializeField] private Vector2 size = new Vector2(380f, 104f);
        [SerializeField] private bool visible = true;

        private Texture2D panelTexture;
        private GUIStyle panelStyle;
        private GUIStyle titleStyle;
        private GUIStyle detailStyle;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void EnsureInstance()
        {
            if (UnityEngine.Object.FindAnyObjectByType<ConnectionStatusHud>() != null)
            {
                return;
            }

            GameObject root = new GameObject("MATLAB Connection Status");
            root.AddComponent<ConnectionStatusHud>();
        }

        private void Awake()
        {
            if (transform.parent == null)
            {
                DontDestroyOnLoad(gameObject);
            }
        }

        private void OnGUI()
        {
            if (!visible)
            {
                return;
            }

            EnsureStyles();

            NetworkManager network = NetworkManager.Instance;
            ConnectionState state = network != null
                ? network.State
                : ConnectionState.Disconnected;
            string endpoint = network != null
                ? network.Endpoint
                : ProtocolConstants.DefaultHost + ":" + ProtocolConstants.DefaultPort;
            string detail = network != null && !string.IsNullOrEmpty(network.LastError)
                ? network.LastError
                : string.Empty;

            Color accent;
            string title;
            switch (state)
            {
                case ConnectionState.Connected:
                    accent = new Color(0.30f, 0.85f, 0.40f);
                    title = "MATLAB: CONNECTED";
                    break;
                case ConnectionState.Connecting:
                    accent = new Color(0.95f, 0.80f, 0.25f);
                    title = "MATLAB: CONNECTING";
                    break;
                default:
                    accent = new Color(0.95f, 0.35f, 0.35f);
                    title = "MATLAB: DISCONNECTED";
                    break;
            }

            Rect rect = new Rect(offset.x, offset.y, size.x, size.y);
            GUI.Box(rect, GUIContent.none, panelStyle);

            Color previous = GUI.color;
            GUI.color = accent;
            GUI.DrawTexture(new Rect(rect.x, rect.y, 5f, rect.height), Texture2D.whiteTexture);
            GUI.color = previous;

            titleStyle.normal.textColor = accent;
            GUI.Label(new Rect(rect.x + 16f, rect.y + 9f, rect.width - 26f, 22f), title, titleStyle);
            GUI.Label(new Rect(rect.x + 16f, rect.y + 34f, rect.width - 26f, 20f),
                "Server: " + endpoint, detailStyle);

            string activities = state == ConnectionState.Connected
                ? "Activities: enabled"
                : "Activities: disabled (waiting for MATLAB)";
            GUI.Label(new Rect(rect.x + 16f, rect.y + 56f, rect.width - 26f, 20f),
                activities, detailStyle);

            if (!string.IsNullOrEmpty(detail) && state != ConnectionState.Connected)
            {
                GUI.Label(new Rect(rect.x + 16f, rect.y + 78f, rect.width - 26f, 20f),
                    detail, detailStyle);
            }
        }

        private void EnsureStyles()
        {
            if (panelStyle != null)
            {
                return;
            }

            panelTexture = new Texture2D(1, 1, TextureFormat.RGBA32, false)
            {
                hideFlags = HideFlags.HideAndDontSave
            };
            panelTexture.SetPixel(0, 0, new Color(0.06f, 0.07f, 0.09f, 0.82f));
            panelTexture.Apply();

            panelStyle = new GUIStyle(GUI.skin.box);
            panelStyle.normal.background = panelTexture;

            titleStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = 15,
                fontStyle = FontStyle.Bold,
                clipping = TextClipping.Clip
            };

            detailStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = 12,
                clipping = TextClipping.Clip
            };
            detailStyle.normal.textColor = new Color(0.86f, 0.88f, 0.92f);
        }

        private void OnDestroy()
        {
            if (panelTexture != null)
            {
                Destroy(panelTexture);
                panelTexture = null;
            }
        }
    }
}
